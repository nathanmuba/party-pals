extends MiniGame

const NAME := "River Rush"
const MODES := ["ffa"]
const HOW := "Tap Action quickly to row · Left / right to steer · Crashing knocks you back"

static func desc(_m: String) -> String:
	return "Row upstream through rocks, drifting logs and snapping crocs. Everyone gets the same river. Tap fast to row, steer to stay safe. First boat to the lake wins!"

const LEN := 4000.0
const LW := 320.0
const BY := 590.0
var obs: Array = []
var P: Array = []
var order: Array = []
var dur := 75.0

func init(s: Dictionary) -> void:
	super.init(s)
	var d := 520.0
	while d < LEN - 250:
		var r := randf()
		if r < .38:
			obs.append({"type": "rock", "x": randf_range(60, 260), "d": d, "r": randf_range(20, 30)})
		elif r < .66:
			obs.append({"type": "log", "x": randf_range(80, 240), "d": d + 300, "w": randf_range(90, 130), "drift": randf_range(50, 90)})
		elif r < .84:
			obs.append({"type": "croc", "x0": randf_range(110, 210), "d": d, "amp": randf_range(50, 80), "spd": randf_range(1.4, 2.4), "ph": randf() * 6})
		else:
			obs.append({"type": "rock", "x": randf_range(55, 120), "d": d, "r": 24.0})
			obs.append({"type": "rock", "x": randf_range(200, 265), "d": d + randf_range(-30, 30), "r": 24.0})
		d += randf_range(150, 230)
	for i in 4:
		P.append({"id": i, "x": 160.0, "dist": 0.0, "v": 0.0, "stun": 0.0, "oar": 0.0, "fin": false, "bcd": randf() * .2, "tx": 160.0, "tt": 0.0})

func od(ob: Dictionary) -> float:
	return ob.d - ob.get("drift", 0.0) * t

func ox(ob: Dictionary) -> float:
	return ob.x0 + sin(t * ob.spd + ob.ph) * ob.amp if ob.type == "croc" else ob.x

func hit_test(p: Dictionary, ob: Dictionary) -> bool:
	var dd: float = od(ob) - p.dist
	var dx: float = ox(ob) - p.x
	if absf(dd) > 90:
		return false
	if ob.type == "log":
		return absf(dx) < ob.w / 2 + 14 and absf(dd) < 38
	var r: float = 30.0 if ob.type == "croc" else ob.r
	return Vector2(dx, dd * .8).length() < r + 18

func update(dt: float, inp: Array) -> void:
	t += dt
	for p in P:
		if p.fin:
			continue
		var i: Dictionary = inp[p.id]
		p.stun -= dt
		p.oar -= dt
		if p.stun <= 0:
			if i.pressed:
				p.v = minf(430.0, p.v + 70)
				p.oar = .22
				G.beep(260 + randi() % 80, .03, "triangle", .02)
			p.x = clampf(p.x + i.x * 240 * dt, 40, LW - 40)
		p.v -= p.v * .9 * dt
		p.dist = maxf(0.0, p.dist + (p.v - 35) * dt)
		if p.stun <= 0:
			for ob in obs:
				if hit_test(p, ob):
					p.v = 0.0
					p.dist = maxf(0.0, p.dist - 45)
					p.stun = .8
					G.beep(120, .15, "triangle")
					G.burst(Vector2(p.id * LW + p.x, BY - 20), [Color.WHITE, Color("#bfe7ff")], 12, 200)
					G.kick(3)
					break
		if p.dist >= LEN:
			p.fin = true
			order.append(p.id)
			G.beep(880, .1)
			G.beep(1175, .2)
			G.burst(Vector2(p.id * LW + p.x, BY - 30), Art.COLORS, 24, 300)
			if order.size() == 1:
				dur = minf(dur, t + 10)
	if P.all(func(p): return p.fin) or t >= dur:
		var rest := P.filter(func(p): return not p.fin)
		rest.sort_custom(func(a, b): return a.dist > b.dist)
		result = {"kind": "rank", "order": order + rest.map(func(p): return p.id)}
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = P[id]
	if p.fin:
		return {}
	p.bcd -= 1.0 / 60.0
	var press := false
	if p.bcd <= 0:
		press = true
		p.bcd = randf_range(.13, .21)
	p.tt -= 1.0 / 60.0
	if p.tt <= 0:
		p.tt = .12
		var block = null
		var bd := 1e9
		for ob in obs:
			var dd: float = od(ob) - p.dist
			if dd < -20 or dd > 300:
				continue
			var half: float = ob.w / 2 if ob.type == "log" else (ob.amp + 30 if ob.type == "croc" else ob.r)
			var cx: float = ob.x0 if ob.type == "croc" else ox(ob)
			if absf(cx - p.x) < half + 30 and dd < bd:
				bd = dd
				block = [cx, half]
		if block != null and randf() > .12:
			var l: float = block[0] - block[1] - 36
			var r: float = block[0] + block[1] + 36
			p.tx = l if (l >= 40 and (absf(l - p.x) < absf(r - p.x) or r > LW - 40)) else (r if r <= LW - 40 else l)
		elif block == null:
			p.tx = p.x
	var dx: float = p.tx - p.x
	return {"x": clampf(dx / 20, -1, 1) if absf(dx) > 6 else 0.0, "press": press}

func draw(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color("#1d1433"))
	for p in P:
		var L0: float = p.id * LW
		ci.draw_set_transform(Vector2(L0, 0))
		Art.vgrad(ci, Color("#2a7fd0"), Color("#3fa6e8"), Rect2(0, 0, LW, 720))
		var sy := func(d: float) -> float: return BY - (d - p.dist)
		for kk in 14:
			var y := fposmod(BY - (kk * 110.0 - fmod(p.dist, 1540.0)) + t * 35, 1540.0) - 200
			var x := 40.0 + fmod(kk * 73.0, 240)
			ci.draw_polyline(PackedVector2Array([Vector2(x, y), Vector2(x + 12, y + 8), Vector2(x + 24, y)]), Color(1, 1, 1, .22), 2)
		for side in [0.0, LW - 26]:
			ci.draw_rect(Rect2(side, 0, 26, 720), Color("#5ab45a"))
			for kk in range(-1, 9):
				var y := fposmod(sy.call(kk * 120.0), 960.0) - 120
				ci.draw_circle(Vector2(side + 13, y), 18, Color("#3e8f44"))
		var fy: float = sy.call(LEN)
		if fy > -40 and fy < 760:
			var x := 26.0
			var cc := 0
			while x < LW - 26:
				for r2 in 2:
					ci.draw_rect(Rect2(x, fy - 20 + r2 * 10, 20, 10), Color.WHITE if (cc + r2) % 2 else Art.OUT)
				x += 20
				cc += 1
			Art.text(ci, "LAKE!", Vector2(LW / 2, fy - 50), 30, Color("#ffe066"))
		for ob in obs:
			var y: float = sy.call(od(ob))
			var x := ox(ob)
			if y < -60 or y > 780:
				continue
			match ob.type:
				"rock":
					Art.ellipse_line(ci, Vector2(x, y + 6), ob.r + 8, ob.r * .7 + 6, Color(1, 1, 1, .6), 3)
					ci.draw_circle(Vector2(x, y), ob.r, Color("#8a8fa8"))
					Art.ellipse_line(ci, Vector2(x, y), ob.r, ob.r, Art.OUT, 3)
					ci.draw_circle(Vector2(x - ob.r * .3, y - ob.r * .3), ob.r * .3, Color(1, 1, 1, .35))
				"log":
					Art.rrect(ci, Rect2(x - ob.w / 2, y - 13, ob.w, 26), 12, Color("#9a6a3a"), 3)
					Art.ellipse(ci, Vector2(x + ob.w / 2 - 9, y), 8, 11, Color("#c99a5a"))
					ci.draw_line(Vector2(x - ob.w / 2 + 10, y - 4), Vector2(x + ob.w / 2 - 24, y - 4), Color(.24, .12, .04, .5), 3)
				"croc":
					var open := sin(t * 8 + ob.ph) > .3
					var hx := 42.0 if cos(t * ob.spd + ob.ph) > 0 else -42.0
					Art.ellipse(ci, Vector2(x, y), 40, 17, Color("#3e9a4a"))
					Art.ellipse_line(ci, Vector2(x, y), 40, 17, Art.OUT, 3)
					Art.ellipse(ci, Vector2(x + hx, y - (4 if open else 0)), 18, 11 if open else 8, Color("#3e9a4a"))
					Art.ellipse_line(ci, Vector2(x + hx, y - (4 if open else 0)), 18, 11 if open else 8, Art.OUT, 3)
					for s: int in [-1, 1]:
						ci.draw_circle(Vector2(x + s * 8, y - 12), 6, Color.WHITE)
						ci.draw_circle(Vector2(x + s * 8, y - 12), 2.5, Art.OUT)
		var bx: float = p.x + (sin(t * 40) * 4 if p.stun > 0 else 0.0)
		for kk in range(1, 4):
			ci.draw_line(Vector2(bx - 14 - kk * 4, BY + 30 + kk * 14), Vector2(bx - 20 - kk * 8, BY + 40 + kk * 14), Color(1, 1, 1, .5), 3)
			ci.draw_line(Vector2(bx + 14 + kk * 4, BY + 30 + kk * 14), Vector2(bx + 20 + kk * 8, BY + 40 + kk * 14), Color(1, 1, 1, .5), 3)
		var oa := sin((1 - p.oar / .22) * PI) * .8 if p.oar > 0 else 0.0
		for s: int in [-1, 1]:
			ci.draw_line(Vector2(bx + s * 12, BY - 4), Vector2(bx + s * 46, BY + 6 - oa * 26), Color("#7a5a30"), 5)
			Art.ellipse(ci, Vector2(bx + s * 48, BY + 8 - oa * 26), 6, 12, Color("#c99a5a"))
		Art.poly(ci, [Vector2(bx, BY - 34), Vector2(bx + 16, BY - 14), Vector2(bx + 16, BY + 20), Vector2(bx + 12, BY + 32), Vector2(bx - 12, BY + 32), Vector2(bx - 16, BY + 20), Vector2(bx - 16, BY - 14)], Color("#d9884a"), 3)
		Art.ellipse(ci, Vector2(bx, BY + 4), 11, 20, Color("#a8602e"))
		Art.pal(ci, bx, BY - 2, 17, p.id, {"fy": -1, "dizzy": p.stun > 0, "cheer": p.fin, "mood": "happy" if p.oar > 0 else ""})
		ci.draw_set_transform(Vector2.ZERO)
		Art.rrect(ci, Rect2(L0 + 16, 676, LW - 32, 30), 15, Color(.06, .03, .13, .6))
		Art.rrect(ci, Rect2(L0 + 16, 676, maxf(30.0, (LW - 32) * minf(1.0, p.dist / LEN)), 30), 15, Art.COLORS[p.id])
		Art.text(ci, (tag(p.id) + " · #%d" % (order.find(p.id) + 1)) if p.fin else (tag(p.id) + " · %d%%" % int(100 * p.dist / LEN)), Vector2(L0 + LW / 2, 691), 18)
		if p.id > 0:
			ci.draw_rect(Rect2(L0 - 3, 0, 6, 720), Art.OUT)
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, ("%d at the lake" % order.size()) if order.size() else "Row, row, row!")
