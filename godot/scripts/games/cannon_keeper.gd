extends MiniGame

const NAME := "Cannon Keeper"
const MODES := ["1v3"]
const HOW := "Solo: move the target, Action fires · Trio: run, Action is a quick roll"

static func desc(_m: String) -> String:
	return "The solo pal aims the cannon and drops bombs. The trio must dodge for 30 seconds. Hit all three to win!"

var solo := 0
var dur := 30.0
var cr := {"x": 640.0, "y": 420.0, "cd": 0.0}
var run: Array = []
var bombs: Array = []
var booms: Array = []

func init(s: Dictionary) -> void:
	super.init(s)
	solo = st.solo
	var k := 0
	for i in 4:
		if i == solo:
			continue
		var p := new_pal(i, 360 + k * 280, 560)
		p.fy = -1.0
		p.roll = 0.0
		p.wx = 640.0
		p.wy = 450.0
		p.wt = 0.0
		p.aim = Vector2.ZERO
		run.append(p)
		k += 1

func update(dt: float, inp: Array) -> void:
	t += dt
	var s: Dictionary = inp[solo]
	cr.x = clampf(cr.x + s.x * 500 * dt, 60, 1220)
	cr.y = clampf(cr.y + s.y * 500 * dt, 170, 680)
	cr.cd -= dt
	if s.pressed and cr.cd <= 0:
		bombs.append({"x": cr.x, "y": cr.y, "t": 0.0})
		cr.cd = .5
		G.beep(180, .08, "square")
		G.burst(Vector2(cr.x, 140), Color.WHITE, 6, 120)
	for r in run:
		if r.out:
			r.ot += dt
			continue
		var i: Dictionary = inp[r.id]
		r.cd -= dt
		r.roll -= dt
		if i.x != 0.0 or i.y != 0.0:
			r.fx = i.x
			r.fy = i.y
		if i.pressed and r.cd <= 0:
			var d := Vector2(r.fx, r.fy).normalized()
			r.vx = d.x * 620
			r.vy = d.y * 620
			r.roll = .25
			r.cd = 1.4
			G.beep(330, .05, "triangle")
			G.burst(Vector2(r.x, r.y + 20), Color("#d9b27a"), 6, 120)
		if r.roll <= 0:
			var kk := minf(1.0, dt * 10)
			r.vx += (i.x * 280 - r.vx) * kk
			r.vy += (i.y * 280 - r.vy) * kk
		r.x = clampf(r.x + r.vx * dt, 50, 1230)
		r.y = clampf(r.y + r.vy * dt, 175, 690)
	for b in bombs.duplicate():
		b.t += dt
		if b.t >= .8:
			bombs.erase(b)
			booms.append({"x": b.x, "y": b.y, "t": 0.0})
			G.beep(90, .25, "sawtooth", .06)
			G.kick(7)
			G.burst(Vector2(b.x, b.y), [Color("#ff8c3c"), Color("#ffd23c"), Color("#5a4030")], 16, 320)
			for r in run:
				if not r.out and Vector2(r.x - b.x, r.y - b.y).length() < 90:
					r.out = true
					G.beep(220, .3, "sine")
	for bm in booms.duplicate():
		bm.t += dt
		if bm.t > .4:
			booms.erase(bm)
	var alive := run.filter(func(r): return not r.out)
	if alive.is_empty():
		result = {"kind": "team", "winners": [solo]}
		done = true
	elif t >= dur:
		result = {"kind": "team", "winners": run.map(func(r): return r.id)}
		done = true

func bot(id: int) -> Dictionary:
	if id == solo:
		var tgt = null
		var bd := 1e9
		for r in run:
			if not r.out:
				var d := Vector2(r.x - cr.x, r.y - cr.y).length()
				if d < bd:
					bd = d
					tgt = r
		if tgt == null:
			return {}
		if tgt.aim == Vector2.ZERO or randf() < .02:
			tgt.aim = Vector2(randf_range(-60, 60), randf_range(-60, 60))
		var a := Vector2(tgt.x + tgt.vx * .6 + tgt.aim.x * .5 - cr.x, tgt.y + tgt.vy * .6 + tgt.aim.y * .5 - cr.y)
		var d := a.length()
		var n := a / maxf(1.0, d)
		return {"x": n.x if d > 12 else 0.0, "y": n.y if d > 12 else 0.0, "press": d < 40 and cr.cd <= 0 and randf() < .25}
	var r = null
	for q in run:
		if q.id == id:
			r = q
	if r == null or r.out:
		return {}
	var v := Vector2.ZERO
	var danger := false
	for b in bombs:
		var dv := Vector2(r.x - b.x, r.y - b.y)
		var d := maxf(1.0, dv.length())
		if d < 140:
			v += dv / d * 2
			if d < 95 and b.t > .5:
				danger = true
	var cv := Vector2(r.x - cr.x, r.y - cr.y)
	if cv.length() < 170:
		v += cv.normalized() * .8
	r.wt -= 1.0 / 60.0
	if r.wt <= 0 or Vector2(r.wx - r.x, r.wy - r.y).length() < 30:
		r.wx = randf_range(100, 1180)
		r.wy = randf_range(200, 660)
		r.wt = randf_range(1, 2.5)
	v += Vector2(r.wx - r.x, r.wy - r.y).normalized() * .6
	if randf() < .04:
		v += Vector2(randf_range(-1, 1), randf_range(-1, 1))
	return {"x": v.x, "y": v.y, "press": danger and r.cd <= 0 and randf() < .5}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#f0cd8a"), Color("#b9874a"))
	for i in 40:
		ci.draw_circle(Vector2(fmod(i * 331.0, 1280), 170 + fmod(i * 197.0, 520)), 6 + (i % 4) * 3, Color(.47, .27, .08, .15))
	ci.draw_rect(Rect2(0, 80, 1280, 70), Color("#5a3a6e"))
	ci.draw_rect(Rect2(0, 140, 1280, 10), Color("#46295a"))
	for x in range(0, 1280, 64):
		Art.rrect(ci, Rect2(x + 4, 84, 56, 18), 6, Color("#3a2448"))
	Art.rrect(ci, Rect2(cr.x - 26, 112, 52, 34), 10, Color("#2b2238"))
	ci.draw_circle(Vector2(cr.x, 146), 14, Color("#4a3a60"))
	Art.pal(ci, cr.x, 92, 24, solo, {"crown": true, "tag": tag(solo), "fx": (cr.x - 640) / 640, "fy": 1})
	for b in bombs:
		var kk: float = b.t / .8
		Art.ellipse(ci, Vector2(b.x, b.y), 70 * kk + 10, (70 * kk + 10) * .55, Color(.12, .04, .04, .15 + .35 * kk))
		Art.ellipse_line(ci, Vector2(b.x, b.y), 80, 44, Color(1, .24, .24, .3 + .5 * kk), 3)
		var by: float = b.y - (1 - kk) * 480
		ci.draw_circle(Vector2(b.x, by), 16, Color("#1a1424"))
		ci.draw_circle(Vector2(b.x - 5, by - 5), 5, Color(1, 1, 1, .3))
		ci.draw_rect(Rect2(b.x - 2, by - 24, 4, 9), Color("#ff6b3c"))
	for r in by_y(run):
		if r.out:
			if r.ot < 1.2:
				Art.pal(ci, r.x, r.y - r.ot * 40, 24, r.id, {"alpha": 1 - r.ot / 1.2, "dizzy": true})
			continue
		var near := bombs.any(func(b): return Vector2(b.x - r.x, b.y - r.y).length() < 110)
		Art.pal(ci, r.x, r.y, 24, r.id, {"fx": r.fx, "fy": r.fy, "tag": tag(r.id), "ring": Art.TEAMC[1], "squash": .8 if r.roll > 0 else 1.0, "move": Vector2(r.vx, r.vy).length() > 40, "mood": "ouch" if near else ""})
	for bm in booms:
		var kk: float = bm.t / .4
		ci.draw_circle(Vector2(bm.x, bm.y), 30 + 60 * kk, Color(1, (200 - kk * 120) / 255.0, .24, 1 - kk))
	var c := Vector2(cr.x, cr.y)
	var col: Color = Art.COLORS[solo]
	Art.ellipse_line(ci, c, 26, 26, col, 4)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		ci.draw_line(c + d * 14, c + d * 38, col, 4)
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "%d / 3 dodging" % run.filter(func(r): return not r.out).size())
