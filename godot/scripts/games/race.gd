extends MiniGame
## Shared engine for the scrolling obstacle-course races. Subclasses override cfg().

const X0 := 250.0
const X1 := 1030.0
const MID := 640.0

func cfg() -> Dictionary:
	return {}

var c: Dictionary
var L := 3000.0
var obs: Array = []
var cps: Array = []
var ps: Array = []
var boulders: Array = []
var order: Array = []
var coop := false
var bt := 1.0
var cam := 60.0 - 560.0
var dur := 80.0

# ---- course segments ----
func seg_pits(y: float, rows := 2) -> void:
	for kk in rows:
		var ry := y - 60 - kk * 170
		var gw := randf_range(120, 150)
		var n := 1 + randi() % 2 + (1 if rows < 2 else 0)
		var gaps := []
		for _j in n:
			var a := 0.0
			var ok := false
			for _tries in 20:
				a = randf_range(X0 + 30, X1 - 30 - gw)
				ok = gaps.all(func(g): return a > g[1] + 80 or a + gw < g[0] - 80)
				if ok:
					break
			if ok:
				gaps.append([a, a + gw])
		obs.append({"type": "pit", "y": ry - 80, "h": 80.0, "gaps": gaps})

func seg_sweep(y: float) -> void:
	obs.append({"type": "sweep", "x": X0 + 210, "y": y - 90, "len": 175.0, "a0": randf() * TAU, "spd": randf_range(1.6, 2.2)})
	obs.append({"type": "sweep", "x": X1 - 210, "y": y - 250, "len": 175.0, "a0": randf() * TAU, "spd": -randf_range(1.6, 2.2)})

func seg_slide(y: float) -> void:
	for kk in 3:
		obs.append({"type": "slide", "y": y - 40 - kk * 110, "w": 210.0, "h": 44.0, "amp": 260.0, "spd": randf_range(1.4, 2.2), "ph": randf() * TAU})

func seg_bump(y: float, n := 7) -> void:
	var placed := []
	for _k in n * 4:
		if placed.size() >= n:
			break
		var b := {"type": "bump", "x": randf_range(X0 + 50, X1 - 50), "y": randf_range(y - 300, y - 30), "r": 30.0, "hit": 0.0}
		if placed.all(func(q): return Vector2(q.x - b.x, q.y - b.y).length() > 120):
			placed.append(b)
			obs.append(b)

func seg_belt(y: float) -> void:
	obs.append({"type": "belt", "y0": y - 320, "y1": y - 20, "v": 120.0})
	seg_bump(y, 3)

func build_seg(name: String, y: float) -> void:
	match name:
		"pits": seg_pits(y)
		"pits1": seg_pits(y, 1)
		"sweep": seg_sweep(y)
		"slide": seg_slide(y)
		"bump": seg_bump(y)
		"bump5": seg_bump(y, 5)
		"bump9": seg_bump(y, 9)
		"bump2": seg_bump(y, 2)
		"belt": seg_belt(y)
		"beltslide":
			seg_belt(y)
			seg_slide(y - 10)
		"pitbump":
			seg_pits(y, 1)
			seg_bump(y - 200, 2)

func init(s: Dictionary) -> void:
	super.init(s)
	c = cfg()
	L = c.length
	coop = st.mode == "coop"
	dur = c.get("coop_dur", c.dur) if coop else c.dur
	var y := -280.0
	while y > -L + 300:
		build_seg(c.segs.pick_random(), y)
		y -= 420
	var cpy := -420.0
	while cpy > -L:
		cps.append(cpy)
		cpy -= 420
	for i in 4:
		var p := new_pal(i, MID - 240 + i * 160, 60)
		p.fall = 0.0
		p.cp = 60.0
		p.cpx = p.x
		p.fin = false
		p.off = 0.0
		p.tt = 0.0
		ps.append(p)

func pit_at(x: float, y: float) -> bool:
	for ob in obs:
		if ob.type == "pit" and y > ob.y and y < ob.y + ob.h:
			if not ob.gaps.any(func(g): return x > g[0] + 4 and x < g[1] - 4):
				return true
	return false

func safe_x(y: float, pref: float) -> float:
	var cand := [pref]
	for kk in 16:
		cand.append(X0 + 40 + kk * (X1 - X0 - 80) / 15.0)
	cand.sort_custom(func(a, b): return absf(a - pref) < absf(b - pref))
	for x in cand:
		if not pit_at(x, y) and not pit_at(x, y - 30) and not pit_at(x, y + 30):
			return x
	return MID

func slide_x(ob: Dictionary) -> float:
	return MID + sin(t * ob.spd + ob.ph) * ob.amp

func _hit(p: Dictionary, v: Vector2, stun: float) -> void:
	p.vx = v.x
	p.vy = v.y
	p.stun = stun
	G.beep(150, .08, "triangle")
	G.burst(Vector2(p.x, p.y - 10), Color("#fff6a0"), 8, 200)
	G.kick(4)

func update(dt: float, inp: Array) -> void:
	t += dt
	for ob in obs:
		if ob.type == "bump":
			ob.hit -= dt
	for p in ps:
		if p.fin:
			continue
		if p.fall > 0:
			p.fall -= dt
			if p.fall <= 0:
				p.y = minf(p.cp, cam + 720 - 110)
				p.x = safe_x(p.y, p.cpx)
				p.vx = 0.0
				p.vy = 0.0
				p.stun = 0.0
				G.burst(Vector2(p.x, p.y), Art.COLORS[p.id], 10, 160)
			continue
		var i: Dictionary = inp[p.id]
		p.cd -= dt
		p.dash -= dt
		p.stun -= dt
		if p.stun <= 0:
			if i.x != 0.0 or i.y != 0.0:
				p.fx = i.x
				p.fy = i.y
			if p.dash <= 0:
				var kk := minf(1.0, dt * 9)
				p.vx += (i.x * 285 - p.vx) * kk
				p.vy += (i.y * 285 - p.vy) * kk
			if i.pressed and p.cd <= 0:
				var d := Vector2(p.fx, p.fy).normalized()
				if d == Vector2.ZERO:
					d = Vector2.UP
				p.vx = d.x * 560
				p.vy = d.y * 560
				p.dash = .3
				p.cd = 1.2
				G.beep(300, .05, "triangle")
		else:
			p.vx *= pow(.12, dt)
			p.vy *= pow(.12, dt)
		for ob in obs:
			if ob.type == "belt" and p.y > ob.y0 and p.y < ob.y1:
				p.y += ob.v * dt
		p.x = clampf(p.x + p.vx * dt, X0 + 22, X1 - 22)
		p.y = minf(120.0, p.y + p.vy * dt)
		var pos := Vector2(p.x, p.y)
		for ob in obs:
			match ob.type:
				"sweep":
					if absf(ob.y - p.y) > ob.len + 40:
						continue
					var a: float = ob.a0 + t * ob.spd
					var arm: Vector2 = Vector2(cos(a), sin(a)) * ob.len
					var o := Vector2(ob.x, ob.y)
					var tt := clampf((pos - o).dot(arm) / (ob.len * ob.len), -1, 1)
					var q: Vector2 = o + arm * tt
					var d := pos.distance_to(q)
					if d < 34:
						var n: Vector2 = (pos - q) / d if d > 0 else Vector2(-sin(a), cos(a))
						p.x = q.x + n.x * 34
						p.y = q.y + n.y * 34
						if p.stun <= 0:
							var bv: Vector2 = Vector2(-sin(a), cos(a)) * ob.spd * ob.len * tt
							_hit(p, n * 320 + bv * 1.2, .5)
				"slide":
					if absf(ob.y - p.y) > 60:
						continue
					var bx := slide_x(ob)
					var q := Vector2(clampf(p.x, bx - ob.w / 2, bx + ob.w / 2), clampf(p.y, ob.y - ob.h / 2, ob.y + ob.h / 2))
					var dv := Vector2(p.x, p.y) - q
					var d := dv.length()
					if d < 22:
						if d > 0:
							p.x += dv.x / d * (22 - d)
							p.y += dv.y / d * (22 - d)
						else:
							p.y = ob.y - ob.h / 2 - 22 if p.y < ob.y else ob.y + ob.h / 2 + 22
						if absf(dv.x) > absf(dv.y):
							var bv: float = cos(t * ob.spd + ob.ph) * ob.spd * ob.amp
							p.vx = bv * 1.3
							if p.stun <= 0 and absf(bv) > 150:
								p.stun = .3
				"bump":
					var dv := Vector2(p.x - ob.x, p.y - ob.y)
					var d := dv.length()
					if d < ob.r + 22 and d > 0:
						var n := dv / d
						p.x = ob.x + n.x * (ob.r + 22)
						p.y = ob.y + n.y * (ob.r + 22)
						ob.hit = .2
						_hit(p, n * 520, .25)
		if p.dash <= 0 and pit_at(p.x, p.y):
			p.fall = .9
			G.beep(260, .3, "sine")
			G.burst(Vector2(p.x, p.y), [Color("#2a1650"), Color("#5a3a9a")], 12, 160)
		for cy in cps:
			if p.y < cy and cy < p.cp:
				p.cp = cy
				p.cpx = p.x
		if p.y < -L:
			p.fin = true
			order.append(p.id)
			G.beep(880, .1)
			G.beep(1175, .2)
			G.burst(Vector2(p.x, p.y), Art.COLORS, 30, 360)
			if order.size() == 1 and not coop:
				dur = minf(dur, t + 15)
	for a in 4:
		for b in range(a + 1, 4):
			var A: Dictionary = ps[a]
			var B: Dictionary = ps[b]
			if A.fin or B.fin or A.fall > 0 or B.fall > 0:
				continue
			var dv := Vector2(B.x - A.x, B.y - A.y)
			var l := dv.length()
			if l >= 44 or l == 0:
				continue
			var n := dv / l
			var ov := (44 - l) / 2
			A.x -= n.x * ov
			A.y -= n.y * ov
			B.x += n.x * ov
			B.y += n.y * ov
	if c.boulders:
		bt -= dt
		if bt <= 0 and cam > -L + 150:
			bt = randf_range(.3, .6)
			boulders.append({"x": randf_range(X0 + 40, X1 - 40), "y": cam - 60, "r": randf_range(28, 44), "v": randf_range(230, 330), "rot": 0.0})
		for b in boulders.duplicate():
			b.y += b.v * dt
			b.rot += b.v * dt / b.r
			for p in ps:
				if not p.fin and p.fall <= 0 and p.stun <= 0 and Vector2(p.x - b.x, p.y - b.y).length() < b.r + 20:
					_hit(p, Vector2(-200 if p.x < b.x else 200, 520), .6)
					G.kick(6)
			if b.y > cam + 720 + 80:
				boulders.erase(b)
	var live := ps.filter(func(p): return not p.fin)
	if live.size() > 0:
		var lead: float = live.map(func(p): return p.cp if p.fall > 0 else p.y).min()
		var target := maxf(-L - 300, lead - 300)
		if target < cam:
			cam += (target - cam) * minf(1.0, dt * 3)
	for p in live:
		if p.fall <= 0 and p.y > cam + 720 - 50:
			p.y = cam + 720 - 50
			if p.vy > 0:
				p.vy = 0.0
	if live.is_empty() or t >= dur:
		live.sort_custom(func(a, b): return a.y < b.y)
		var full: Array = order + live.map(func(p): return p.id)
		if coop:
			result = {"kind": "coop", "collected": order.size(), "goal": 4, "per": ps.map(func(p): return 1 if p.fin else 0), "unit": "pals at the top"}
		elif st.mode == "ffa":
			result = {"kind": "rank", "order": full}
		elif st.mode == "1v3":
			result = {"kind": "team", "winners": [st.solo] if full.find(st.solo) <= 1 else [0, 1, 2, 3].filter(func(i): return i != st.solo)}
		else:
			var sc := [0, 0]
			for kk in 4:
				sc[st.team[full[kk]]] += kk
			var w: int = st.team[full[0]] if sc[0] == sc[1] else (0 if sc[0] < sc[1] else 1)
			result = {"kind": "team", "winners": [0, 1, 2, 3].filter(func(i): return st.team[i] == w)}
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.fin or p.fall > 0 or p.stun > 0:
		return {}
	p.tt -= 1.0 / 60.0
	if p.tt <= 0:
		p.off = randf_range(-70, 70)
		p.tt = randf_range(.8, 2)
	var tx: float = p.x + p.off
	var yv := -1.0
	var pit = null
	var best_b := -1e9
	for ob in obs:
		if ob.type == "pit":
			var bot_y: float = ob.y + ob.h
			if bot_y < p.y + 40 and bot_y > p.y - 260 and bot_y > best_b:
				best_b = bot_y
				pit = ob
	if pit != null:
		var gx := MID
		var gd := 1e9
		for g in pit.gaps:
			var cx: float = (g[0] + g[1]) / 2
			if absf(cx - p.x) < gd:
				gd = absf(cx - p.x)
				gx = cx
		tx = gx
		if gd > 22 and p.y > pit.y + pit.h and p.y - (pit.y + pit.h) < 70:
			yv = .15
	for ob in obs:
		if ob.type == "bump" and ob.y < p.y and p.y - ob.y < 140 and absf(ob.x - p.x) < ob.r + 30:
			tx = p.x + (-90 if p.x < ob.x else 90)
	for b in boulders:
		if b.y < p.y and p.y - b.y < 260 and absf(b.x - p.x) < b.r + 40:
			tx = p.x + (-130 if p.x < b.x else 130)
	var dx: float = tx - p.x
	return {"x": clampf(dx / 40, -1, 1), "y": yv, "press": p.cd <= 0 and (pit == null or absf(dx) < 15) and randf() < .015}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, c.sky[0], c.sky[1])
	for i in 14:
		var yy := fposmod(i * 97.0 - cam * .3, 720)
		ci.draw_circle(Vector2(fmod(i * 331.0, 1280), yy), 30 + (i % 3) * 20, Color(1, 1, 1, .08))
	ci.draw_set_transform(Vector2(0, -cam))
	var top := cam
	var bot := cam + 720
	var t0 := maxf(top, -L - 400)
	ci.draw_rect(Rect2(X0 - 34, t0, X1 - X0 + 68, bot - t0), c.edge)
	var yy := floorf(top / 80) * 80
	while yy < bot:
		if yy >= -L - 400 and yy <= 200:
			var x := X0
			var cc := 0
			while x < X1:
				ci.draw_rect(Rect2(x, yy, minf(78.0, X1 - x), 80), c.floor[0] if (int(yy / 80) + cc) % 2 else c.floor[1])
				x += 78
				cc += 1
		yy += 80
	for ob in obs:
		if ob.type == "belt" and ob.y1 > top and ob.y0 < bot:
			ci.draw_rect(Rect2(X0, ob.y0, X1 - X0, ob.y1 - ob.y0), Color("#4a4f6e"))
			var off := fmod(t * ob.v, 60.0)
			var by: float = ob.y0 + off - 60
			while by < ob.y1:
				if by >= ob.y0:
					var x := X0 + 40
					while x < X1:
						Art.poly(ci, [Vector2(x - 18, by), Vector2(x + 18, by), Vector2(x, by + 16)], Color(1, 1, 1, .18))
						x += 110
				by += 60
	for ob in obs:
		match ob.type:
			"pit":
				if ob.y + ob.h < top or ob.y > bot:
					continue
				ci.draw_rect(Rect2(X0, ob.y, X1 - X0, ob.h), Color("#1e1038"))
				ci.draw_rect(Rect2(X0, ob.y + ob.h - 20, X1 - X0, 20), Color("#3a2266"))
				for g in ob.gaps:
					ci.draw_rect(Rect2(g[0], ob.y, g[1] - g[0], ob.h), c.bridge)
					var ly: float = ob.y + 12
					while ly < ob.y + ob.h:
						ci.draw_line(Vector2(g[0], ly), Vector2(g[1], ly), Color(0, 0, 0, .2), 2)
						ly += 16
			"sweep":
				if absf(ob.y - (top + 360)) > 360 + ob.len:
					continue
				var a: float = ob.a0 + t * ob.spd
				var arm: Vector2 = Vector2(cos(a), sin(a)) * ob.len
				var o := Vector2(ob.x, ob.y)
				ci.draw_line(o - arm + Vector2(0, 10), o + arm + Vector2(0, 10), Color(0, 0, 0, .25), 24)
				ci.draw_line(o - arm, o + arm, Art.OUT, 24)
				ci.draw_line(o - arm, o + arm, Color("#ff5ab4"), 17)
				for kk in 8:
					var f := -1.0 + kk / 4.0
					ci.draw_line(o + arm * f, o + arm * (f + .12), Color("#ffd23c"), 17)
				ci.draw_circle(o, 22, Color("#ffd23c"))
				Art.ellipse_line(ci, o, 22, 22, Art.OUT, 4)
			"slide":
				if absf(ob.y - (top + 360)) > 420:
					continue
				var bx := slide_x(ob)
				Art.rrect(ci, Rect2(bx - ob.w / 2, ob.y - ob.h / 2 + 10, ob.w, ob.h), 12, Color(0, 0, 0, .25))
				Art.rrect(ci, Rect2(bx - ob.w / 2, ob.y - ob.h / 2, ob.w, ob.h), 12, Color("#4ec3ff"), 4)
				Art.rrect(ci, Rect2(bx - ob.w / 2 + 8, ob.y - ob.h / 2 + 5, ob.w - 16, 12), 6, Color(1, 1, 1, .35))
				for kk in [-1, 0, 1]:
					ci.draw_circle(Vector2(bx + kk * 60, ob.y + 4), 7, Color("#ff5ab4"))
			"bump":
				if absf(ob.y - (top + 360)) > 420:
					continue
				var s := 1.18 if ob.hit > 0 else 1.0
				Art.ellipse(ci, Vector2(ob.x, ob.y + 14), ob.r, ob.r * .5, Color(0, 0, 0, .25))
				ci.draw_circle(Vector2(ob.x, ob.y), ob.r * s, Color("#ff7a3c"))
				Art.ellipse_line(ci, Vector2(ob.x, ob.y), ob.r * s, ob.r * s, Art.OUT, 4)
				ci.draw_circle(Vector2(ob.x, ob.y), ob.r * .55 * s, Color("#ffd23c"))
				ci.draw_circle(Vector2(ob.x - 8, ob.y - 9), 6, Color(1, 1, 1, .5))
	for ln in [[0.0, false], [-L, true]]:
		var ly: float = ln[0]
		if ly < top - 60 or ly > bot + 160:
			continue
		var x := X0
		var cc := 0
		while x < X1:
			for r2 in 2:
				ci.draw_rect(Rect2(x, ly - 26 + r2 * 13, 26, 13), Color.WHITE if (cc + r2) % 2 else Art.OUT)
			x += 26
			cc += 1
		if ln[1]:
			Art.rrect(ci, Rect2(X0 - 40, ly - 120, 30, 110), 8, Color("#ff5ab4"), 4)
			Art.rrect(ci, Rect2(X1 + 10, ly - 120, 30, 110), 8, Color("#ff5ab4"), 4)
			Art.rrect(ci, Rect2(X0 - 40, ly - 150, X1 - X0 + 80, 46), 16, Color("#ff5ab4"), 4)
			Art.text(ci, "FINISH", Vector2(MID, ly - 127), 34)
	for b in boulders:
		Art.ellipse(ci, Vector2(b.x, b.y + b.r * .8), b.r, b.r * .35, Color(0, 0, 0, .25))
		ci.draw_circle(Vector2(b.x, b.y), b.r, Color("#9a6a46"))
		ci.draw_circle(Vector2(b.x - b.r * .2, b.y - b.r * .2), b.r * .7, Color("#b8875a"))
		Art.ellipse_line(ci, Vector2(b.x, b.y), b.r, b.r, Art.OUT, 4)
		ci.draw_arc(Vector2(b.x, b.y), b.r * .55, b.rot, b.rot + 1.7, 8, Color(.24, .12, .04, .5), 3)
		ci.draw_arc(Vector2(b.x, b.y), b.r * .3, b.rot + 3, b.rot + 4.5, 8, Color(.24, .12, .04, .5), 3)
	for p in by_y(ps):
		if p.fall > 0:
			var s: float = maxf(0.0, (p.fall - .4) / .5)
			if s > 0:
				Art.pal(ci, p.x, p.y + (1 - s) * 20, 22 * s, p.id, {"alpha": s, "dizzy": true})
			continue
		Art.pal(ci, p.x, p.y, 22, p.id, {"fx": p.fx, "fy": p.fy, "tag": ("#%d" % (order.find(p.id) + 1)) if p.fin else tag(p.id), "ring": ring(p.id),
			"crown": st.mode == "1v3" and p.id == st.solo, "dizzy": p.stun > .15, "squash": .8 if p.dash > 0 else 1.0,
			"move": not p.fin and Vector2(p.vx, p.vy).length() > 50, "cheer": p.fin, "bob": absf(sin(t * 8 + p.id)) * 10 if p.fin else 0.0})
	G.draw_parts(ci)
	ci.draw_set_transform(Vector2.ZERO)
	Art.rrect(ci, Rect2(1222, 100, 26, 580), 13, Color(.06, .03, .13, .55))
	for p in ps:
		var f := clampf((60 - p.y) / (60 + L), 0, 1)
		var py := 670 - f * 560
		ci.draw_circle(Vector2(1235, py), 10, Art.COLORS[p.id])
		Art.ellipse_line(ci, Vector2(1235, py), 10, 10, Art.OUT, 3)
	var extra := ("%d / 4 at the top" % order.size()) if coop else (("%d finished" % order.size()) if order.size() else "Race to the top!")
	Art.hud(ci, c.name, dur - t, extra)
