extends MiniGame

const NAME := "Rocket Lander"
const MODES := ["ffa"]
const HOW := "Hold Action: thrust up · Left / right: steer · Land slowly on the pad"
const LW := 320.0
const GY := 640.0

static func desc(_m: String) -> String:
	return "Land your rocket gently on the pad! Hold the button to fire your thruster and steer left and right. Too fast and you crash and start again. Watch the wind and your fuel. Land safely 3 times, and the first to do it wins!"

var dur := 70.0
var pads: Array = []
var R: Array = []
var order: Array = []
var wind := 0.0
var wind_t := 0.0
var wt := 2.0

func init(s: Dictionary) -> void:
	super.init(s)
	pads = [randf_range(70, 250), randf_range(70, 250), randf_range(70, 250)]
	for _i in 4:
		R.append({"x": 160.0, "y": 140.0, "vx": 0.0, "vy": 0.0, "fuel": 100.0, "st": "fly", "bt": 0.0, "crash": 0, "thr": false, "n": 0, "noise": 0.0})

func update(dt: float, inp: Array) -> void:
	t += dt
	wt -= dt
	if wt <= 0:
		wt = randf_range(1.5, 3.5)
		wind_t = randf_range(-70, 70)
	wind += clampf(wind_t - wind, -60 * dt, 60 * dt)
	for i in 4:
		var r: Dictionary = R[i]
		var ip: Dictionary = inp[i]
		if r.st == "boom" or r.st == "hop":
			r.bt -= dt
			if r.bt <= 0:
				r.x = 160.0
				r.y = 140.0
				r.vx = 0.0
				r.vy = 0.0
				r.fuel = 100.0
				r.st = "fly"
			continue
		if r.st == "land":
			continue
		var pad: float = pads[r.n]
		r.thr = ip.act and r.fuel > 0
		r.vy += 170 * dt
		if r.thr:
			r.vy -= 430 * dt
			r.fuel -= 17 * dt
		if ip.x != 0.0 and r.fuel > 0:
			r.vx += ip.x * 170 * dt
			r.fuel -= 5 * dt * absf(ip.x)
		r.vx += wind * .6 * dt
		r.vx *= pow(.9, dt)
		r.x += r.vx * dt
		r.y += r.vy * dt
		if r.x < 24 or r.x > LW - 24:
			r.x = clampf(r.x, 24, LW - 24)
			r.vx = 0.0
		if r.y < 110:
			r.y = 110.0
			r.vy = maxf(0.0, r.vy)
		if r.y >= GY - 26:
			if absf(r.vy) < 110 and absf(r.vx) < 70 and absf(r.x - pad) < 48:
				r.n += 1
				r.y = GY - 26
				G.beep(880, .1)
				G.beep(1320, .2)
				G.burst(Vector2(i * LW + r.x, GY - 30), Art.COLORS, 24, 300)
				if r.n >= 3:
					r.st = "land"
					order.append(i)
				else:
					r.st = "hop"
					r.bt = .9
			else:
				r.st = "boom"
				r.bt = 1.6
				r.crash += 1
				G.beep(80, .4, "sawtooth", .07)
				G.burst(Vector2(i * LW + r.x, GY - 26), [Color("#ff8c3c"), Color("#ffd23c"), Color("#555555")], 26, 360)
				G.kick(6)
	if order.size() == 4 or t >= dur:
		var rest := [0, 1, 2, 3].filter(func(i): return not order.has(i))
		rest.sort_custom(func(a, b): return R[a].n > R[b].n or (R[a].n == R[b].n and R[a].crash < R[b].crash))
		result = {"kind": "rank", "order": order + rest}
		done = true

func bot(i: int) -> Dictionary:
	var r: Dictionary = R[i]
	if r.st != "fly":
		return {}
	var pad: float = pads[r.n]
	var h: float = GY - 26 - r.y
	var vdes := minf(240.0, 45 + h * .42)
	var vxd := clampf((pad - r.x) * 1.1, -110, 110) - wind * .35
	if randf() < .02:
		r.noise = gauss() * 12
	return {"x": signf(vxd - r.vx) if absf(vxd - r.vx) > 14 else 0.0, "press": r.vy > vdes + r.noise}

func draw(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color("#1d1433"))
	for i in 4:
		var L0 := i * LW
		var r: Dictionary = R[i]
		ci.draw_set_transform(Vector2(L0, 0))
		Art.vgrad(ci, Color("#0b0a2a"), Color("#3a2a6e"), Rect2(0, 0, LW, 720))
		for kk in 25:
			ci.draw_rect(Rect2(fmod(kk * 97.0, LW), fmod(kk * 61.0, 560) + 80, 2, 2), Color(1, 1, 1, .6))
		ci.draw_rect(Rect2(0, GY, LW, 720 - GY), Color("#6a5a8a"))
		for kk in 6:
			ci.draw_circle(Vector2(30 + kk * 55, GY + 20), 10 + (kk % 2) * 6, Color("#8a7aaa"))
		var pad: float = pads[mini(2, r.n)]
		Art.rrect(ci, Rect2(pad - 48, GY - 6, 96, 12), 4, Color("#d0d6e0"), 3)
		var lc := Color("#7dff9a") if sin(t * 6) > 0 else Color("#3ccf6e")
		ci.draw_circle(Vector2(pad - 40, GY - 10), 4, lc)
		ci.draw_circle(Vector2(pad + 40, GY - 10), 4, lc)
		if r.st != "boom":
			ci.draw_set_transform(Vector2(L0 + r.x, r.y), clampf(r.vx / 400.0, -.4, .4))
			if r.thr:
				Art.poly(ci, [Vector2(-10, 26), Vector2(10, 26), Vector2(0, 46 + randf() * 16)], Color("#ffd23c") if randf() < .5 else Color("#ff8c3c"))
			var col: Color = Art.COLORS[i]
			Art.poly(ci, [Vector2(0, -34), Vector2(14, -20), Vector2(18, 26), Vector2(-18, 26), Vector2(-14, -20)], col, 3)
			for s: int in [-1, 1]:
				Art.poly(ci, [Vector2(s * 16, 8), Vector2(s * 28, 30), Vector2(s * 14, 26)], col.darkened(.3), 3)
			ci.draw_circle(Vector2(0, -6), 9, Color("#bfe7ff"))
			Art.ellipse_line(ci, Vector2(0, -6), 9, 9, Art.OUT, 3)
			ci.draw_circle(Vector2(-3, -7), 1.8, Art.OUT)
			ci.draw_circle(Vector2(3, -7), 1.8, Art.OUT)
			ci.draw_set_transform(Vector2(L0, 0))
		Art.rrect(ci, Rect2(12, 90, 16, 120), 6, Color(0, 0, 0, .5))
		Art.rrect(ci, Rect2(12, 90 + 120 * (1 - r.fuel / 100.0), 16, maxf(2.0, 120 * r.fuel / 100.0)), 6, Color("#7dff9a") if r.fuel > 30 else Color("#ff6b6b"))
		var lbl := ""
		var lcol := Color.WHITE
		if r.st == "land":
			lbl = tag(i) + " · #%d DONE!" % (order.find(i) + 1)
			lcol = Color("#7dff9a")
		elif r.st == "hop":
			lbl = "LANDED %d / 3" % r.n
			lcol = Color("#7dff9a")
		elif r.st == "boom":
			lbl = "CRASH!"
			lcol = Color("#ff6b6b")
		else:
			lbl = tag(i) + " · %d/3  ↓%d" % [r.n, int(maxf(0, r.vy))]
		Art.text(ci, lbl, Vector2(LW / 2, 680), 18, lcol)
		ci.draw_set_transform(Vector2.ZERO)
		if i > 0:
			ci.draw_rect(Rect2(L0 - 3, 0, 6, 720), Art.OUT)
	Art.text(ci, "WIND " + ("◀" if wind < -8 else ("▶" if wind > 8 else "·")) + " %d" % int(absf(wind)), Vector2(640, 95), 20, Color("#cdbdff"))
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "%d done" % order.size())
