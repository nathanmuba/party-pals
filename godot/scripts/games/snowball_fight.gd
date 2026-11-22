extends MiniGame

const NAME := "Snowball Fight"
const MODES := ["ffa", "2v2"]
const HOW := "Move · Action: throw a snowball the way you are facing"
const FORTS := [[640.0, 410.0, 48.0], [420.0, 270.0, 38.0], [860.0, 270.0, 38.0], [420.0, 560.0, 38.0], [860.0, 560.0, 38.0]]

static func desc(m: String) -> String:
	return "Pelt your rivals with snowballs! Three hits and you are out. Hide behind the snow forts. " + ("Last team standing wins!" if m == "2v2" else "Last pal standing wins!")

var ps: Array = []
var elim: Array = []
var balls: Array = []

func init(s: Dictionary) -> void:
	super.init(s)
	ps = corners()
	for p in ps:
		p.hp = 3
		p.fx = -1.0 if p.id % 2 else 1.0
		p.fy = 0.0
		p.str = 1.0

func update(dt: float, inp: Array) -> void:
	t += dt
	for p in ps:
		if p.out:
			p.ot += dt
			continue
		var i: Dictionary = inp[p.id]
		step_top(p, i, dt, 260, Rect2(50, 130, 1180, 560), false)
		if i.pressed and p.cd <= 0:
			var d := Vector2(p.fx, p.fy).normalized()
			balls.append({"x": p.x + d.x * 30, "y": p.y + d.y * 30 - 10, "vx": d.x * 660, "vy": d.y * 660, "own": p.id, "life": 1.1})
			p.cd = .55
			G.beep(400, .04, "triangle", .02)
		for f in FORTS:
			var dv := Vector2(p.x - f[0], p.y - f[1])
			var d := maxf(1.0, dv.length())
			if d < f[2] + 22:
				p.x = f[0] + dv.x / d * (f[2] + 22)
				p.y = f[1] + dv.y / d * (f[2] + 22)
	push_apart(ps, 46)
	for b in balls.duplicate():
		b.x += b.vx * dt
		b.y += b.vy * dt
		b.life -= dt
		var gone: bool = b.life <= 0 or b.x < 0 or b.x > 1280 or b.y < 110 or b.y > 720
		if not gone:
			for f in FORTS:
				if Vector2(b.x - f[0], b.y - f[1]).length() < f[2]:
					gone = true
					G.burst(Vector2(b.x, b.y), Color.WHITE, 6, 120)
					break
		if not gone:
			for p in ps:
				if not p.out and foe(p, ps[b.own]) and Vector2(p.x - b.x, p.y - b.y).length() < 30:
					gone = true
					p.hp -= 1
					p.stun = .35
					var n := Vector2(b.vx, b.vy).normalized()
					p.vx = n.x * 300
					p.vy = n.y * 300
					G.burst(Vector2(p.x, p.y - 10), [Color.WHITE, Color("#cfefff")], 14, 240)
					G.beep(180, .08, "triangle")
					G.kick(3)
					if p.hp <= 0:
						p.out = true
						elim.append(p.id)
						G.beep(220, .3, "sine")
					break
		if gone:
			balls.erase(b)
	var al := alive_ids(ps)
	if over_for(al) or t >= 90:
		al.sort_custom(func(a, b): return ps[a].hp > ps[b].hp)
		result = standing_result(al, elim)
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.out or p.stun > 0:
		return {}
	var tg = null
	var bd := 1e9
	for q in ps:
		if not q.out and foe(p, q):
			var d := Vector2(q.x - p.x, q.y - p.y).length()
			if d < bd:
				bd = d
				tg = q
	if tg == null:
		return {}
	for b in balls:
		if foe(p, ps[b.own]):
			var dv := Vector2(p.x - b.x, p.y - b.y)
			var d := dv.length()
			if d < 200 and d > 0 and dv.dot(Vector2(b.vx, b.vy)) / (d * 660) > .8:
				var n := Vector2(b.vx, b.vy).normalized()
				var sd := 1.0 if id % 2 else -1.0
				return {"x": -n.y * sd, "y": n.x * sd}
	if p.cd <= 0 and randf() < .05:
		var l := Vector2(tg.x + tg.vx * bd / 660 - p.x, tg.y + tg.vy * bd / 660 - p.y).normalized()
		return {"x": l.x, "y": l.y, "press": true}
	if randf() < .01:
		p.str = -p.str
	var want := 1.0 if bd > 340 else (-1.0 if bd < 240 else 0.0)
	var dv := Vector2(tg.x - p.x, tg.y - p.y) / maxf(1.0, bd)
	return {"x": dv.x * want - dv.y * p.str * .8, "y": dv.y * want + dv.x * p.str * .8}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#eaf6ff"), Color("#c9e6fa"))
	for i in 40:
		ci.draw_circle(Vector2(fmod(i * 211.0, 1280), 120 + fmod(i * 137.0, 580)), 4 + (i % 3) * 3, Color(1, 1, 1, .7))
	for f in FORTS:
		Art.ellipse(ci, Vector2(f[0], f[1] + f[2] * .6), f[2] * 1.1, f[2] * .4, Color(0, .16, .31, .15))
		var pts := Art.ell_points(Vector2(f[0], f[1]), f[2], f[2], 0.0, 16, PI, TAU, false)
		pts.append(Vector2(f[0] + f[2], f[1] + f[2] * .5))
		pts.append(Vector2(f[0] - f[2], f[1] + f[2] * .5))
		ci.draw_colored_polygon(pts, Color.WHITE)
		pts.append(pts[0])
		ci.draw_polyline(pts, Color("#9cc3e0"), 4)
	for b in balls:
		ci.draw_circle(Vector2(b.x, b.y), 9, Color.WHITE)
		Art.ellipse_line(ci, Vector2(b.x, b.y), 9, 9, Color("#9cc3e0"), 2)
	for p in by_y(ps):
		if p.out:
			if p.ot < 1:
				Art.pal(ci, p.x, p.y, 24, p.id, {"alpha": 1 - p.ot, "dizzy": true})
			continue
		pal_top(ci, p, {"mood": "ouch" if p.stun > 0 else ""})
		for kk in 3:
			ci.draw_circle(Vector2(p.x - 14 + kk * 14, p.y + 36), 5, Color("#ff5a7a") if kk < p.hp else Color(0, 0, 0, .15))
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, "%d standing" % alive_ids(ps).size())
