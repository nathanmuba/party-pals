extends MiniGame
## Bump rivals off a shrinking ice floe. Grab coins that pop up on the ice.

const NAME := "Melting Floe"
const MODES := ["ffa", "2v2"]
const HOW := "Move to slide on the ice · Action: dash-bump"

static func desc(m: String) -> String:
	return ("Bump the other team into the sea. Last team with anyone on the ice wins!" if m == "2v2" else "Bump everyone into the sea before the ice melts. Last pal standing wins!") + " Grab the coins that pop up on the ice. You keep every one!"

const C := Vector2(640, 405)
var R := 290.0
var dur := 45.0
var ps: Array = []
var elim: Array = []
var coins: Array = []
var got := [0, 0, 0, 0]
var coin_t := 1.0

func init(s: Dictionary) -> void:
	super.init(s)
	for i in 4:
		var a := -PI * 0.75 + i * PI / 2
		var p := new_pal(i, C.x + cos(a) * 165, C.y + sin(a) * 165)
		p.hurt = 0.0
		p.glad = 0.0
		ps.append(p)

func update(dt: float, inp: Array) -> void:
	t += dt
	R = maxf(95.0, 290.0 - t * 5.5)
	coin_t -= dt
	if coin_t <= 0 and coins.size() < 4:
		coin_t = randf_range(.8, 1.6)
		var a := randf() * TAU
		var d := sqrt(randf()) * (R - 30)
		coins.append({"p": C + Vector2(cos(a), sin(a)) * d, "t": 0.0, "big": randf() < .15})
	for c in coins.duplicate():
		c.t += dt
		if c.p.distance_to(C) > R - 6:
			coins.erase(c)
			continue
		for p in ps:
			if not p.out and c.p.distance_to(Vector2(p.x, p.y)) < 40:
				got[p.id] += 3 if c.big else 1
				p.glad = .35
				coins.erase(c)
				G.beep(1200 if c.big else 900, .06, "sine")
				G.burst(c.p, [Color("#ffcf33"), Color("#fff3a0")], 10, 180)
				break
	for p in ps:
		if p.out:
			p.ot += dt
			continue
		var i: Dictionary = inp[p.id]
		p.vx += i.x * 900 * dt
		p.vy += i.y * 900 * dt
		if i.x != 0.0 or i.y != 0.0:
			p.fx = i.x
			p.fy = i.y
		p.cd -= dt
		p.dash -= dt
		p.hurt -= dt
		p.glad -= dt
		if i.pressed and p.cd <= 0:
			var d := Vector2(p.fx, p.fy).normalized()
			p.vx += d.x * 520
			p.vy += d.y * 520
			p.cd = 1.1
			p.dash = .3
			G.beep(240, .06)
			G.burst(Vector2(p.x, p.y + 20), Color.WHITE, 6, 120)
		var f := pow(.35, dt)
		p.vx *= f
		p.vy *= f
		var v := Vector2(p.vx, p.vy)
		var mx := 720.0 if p.dash > 0 else 330.0
		if v.length() > mx:
			v = v.normalized() * mx
			p.vx = v.x
			p.vy = v.y
		p.x += p.vx * dt
		p.y += p.vy * dt
	for a in 4:
		for b in range(a + 1, 4):
			var A: Dictionary = ps[a]
			var B: Dictionary = ps[b]
			if A.out or B.out:
				continue
			var dv := Vector2(B.x - A.x, B.y - A.y)
			var l := dv.length()
			if l >= 52 or l == 0:
				continue
			var n := dv / l
			var ov := (52 - l) / 2
			A.x -= n.x * ov
			A.y -= n.y * ov
			B.x += n.x * ov
			B.y += n.y * ov
			var rel: float = (A.vx - B.vx) * n.x + (A.vy - B.vy) * n.y
			if rel > 0:
				var j := rel * .9
				var ka := 1.8 if B.dash > 0 else 1.0
				var kb := 1.8 if A.dash > 0 else 1.0
				A.vx -= n.x * j * ka
				A.vy -= n.y * j * ka
				B.vx += n.x * j * kb
				B.vy += n.y * j * kb
				if rel > 200:
					G.beep(150, .05, "triangle")
					G.burst(Vector2((A.x + B.x) / 2, (A.y + B.y) / 2), Color("#fff6a0"), 8, 200)
					G.kick(5)
					A.hurt = .3
					B.hurt = .3
	for p in ps:
		if not p.out and Vector2(p.x, p.y).distance_to(C) > R + 12:
			p.out = true
			elim.append(p.id)
			G.beep(300, .25, "sine")
			G.burst(Vector2(p.x, p.y + 10), [Color("#bfe7ff"), Color.WHITE, Color("#6fb7ff")], 16, 260)
	var alive := ps.filter(func(p): return not p.out)
	var ids := alive.map(func(p): return p.id)
	if over_for(ids) or t >= dur:
		alive.sort_custom(func(a, b): return Vector2(a.x, a.y).distance_to(C) < Vector2(b.x, b.y).distance_to(C))
		result = standing_result(alive.map(func(p): return p.id), elim)
		result.bonus = got.duplicate()
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.out:
		return {}
	var pos := Vector2(p.x, p.y)
	var d := pos.distance_to(C)
	for c in coins:
		if c.p.distance_to(pos) < 160 and c.p.distance_to(C) < R * .75:
			var to: Vector2 = (c.p - pos).normalized()
			return {"x": to.x, "y": to.y}
	if d > R * .55:
		var to := (C - pos).normalized()
		return {"x": to.x, "y": to.y}
	var best = null
	var bd := 1e9
	for q in ps:
		if q == p or q.out or (st.mode == "2v2" and st.team[q.id] == st.team[id]):
			continue
		var dd := pos.distance_to(Vector2(q.x, q.y))
		if dd < bd:
			bd = dd
			best = q
	if best == null:
		return {}
	var dir := (Vector2(best.x, best.y) - pos).normalized()
	return {"x": dir.x, "y": dir.y, "press": bd < 140 and p.cd <= 0 and randf() < .07}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#2a8fd6"), Color("#0b3a6e"))
	for i in 9:
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= Art.W:
			pts.append(Vector2(x, 90 + i * 75 + sin(x / 60 + t * 2 + i) * 8))
			x += 20
		ci.draw_polyline(pts, Color(1, 1, 1, .13), 3)
	Art.ellipse(ci, C + Vector2(0, 22), R + 4, R, Color("#7fc4ec"))
	Art.ellipse(ci, C + Vector2(0, 12), R, R, Color("#a8dcf7"))
	ci.draw_circle(C, R, Color("#d4f0ff"))
	ci.draw_circle(C - Vector2(R, R) * .12, R * .8, Color("#e6f7ff"))
	ci.draw_circle(C - Vector2(R, R) * .25, R * .45, Color("#f4fbff"))
	for i in 6:
		var a := i * 1.05 + .3
		ci.draw_line(C + Vector2(cos(a), sin(a)) * R * .3, C + Vector2(cos(a + .15), sin(a + .15)) * R * .95, Color(.47, .7, .86, .6), 2)
	for c in coins:
		var sc := minf(1.0, c.t * 5)
		var r := (20.0 if c.big else 14.0) * sc
		var w := maxf(.25, absf(cos(t * 5 + c.p.x)))
		var by: float = c.p.y - 10 - absf(sin(t * 4 + c.p.y)) * 6
		Art.ellipse(ci, c.p + Vector2(0, 6), r, r * .35, Color(0, 0, 0, .15))
		Art.ellipse(ci, Vector2(c.p.x, by), r * w, r, Color("#ffcf33"))
		Art.ellipse_line(ci, Vector2(c.p.x, by), r * w, r, Color("#b07800"), 3)
	var sorted := ps.duplicate()
	sorted.sort_custom(func(a, b): return a.y < b.y)
	for p in sorted:
		if p.out:
			if p.ot < .7:
				var s: float = 1.0 - p.ot / .7
				Art.pal(ci, p.x, p.y + p.ot * 40, 26 * s, p.id, {"alpha": s, "dizzy": true})
			continue
		Art.pal(ci, p.x, p.y, 26, p.id, {"fx": p.fx, "fy": p.fy, "tag": tag(p.id) + " · " + str(got[p.id]), "ring": ring(p.id),
			"squash": .85 if p.dash > 0 else 1.0, "move": Vector2(p.vx, p.vy).length() > 60,
			"mood": "ouch" if p.hurt > 0 else ("happy" if p.glad > 0 else "")})
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "%d left" % ps.filter(func(p): return not p.out).size())
