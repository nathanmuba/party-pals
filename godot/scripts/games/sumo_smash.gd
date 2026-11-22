extends MiniGame

const NAME := "Sumo Smash"
const MODES := ["ffa", "1v3"]
const HOW := "Move · Action: charge (big push)"

static func desc(m: String) -> String:
	if m == "1v3":
		return "The solo pal is a GIANT sumo! The trio must team up and push the giant out of the ring within 35 seconds. The giant wins by surviving or pushing everyone out."
	return "Shove everyone out of the sumo ring! The ring shrinks after a while. Last pal in the ring wins!"

const C := Vector2(640, 410)
var R := 280.0
var solo := -1
var dur := 9999.0
var ps: Array = []
var elim: Array = []

func init(s: Dictionary) -> void:
	super.init(s)
	solo = st.solo if st.mode == "1v3" else -1
	dur = 35.0 if solo >= 0 else 9999.0
	for i in 4:
		var a := -PI * .75 + i * PI / 2
		var p := new_pal(i, C.x + cos(a) * 170, C.y + sin(a) * 170)
		p.r = 44.0 if i == solo else 26.0
		p.m = 2.2 if i == solo else 1.0
		ps.append(p)
	if solo >= 0:
		ps[solo].x = C.x
		ps[solo].y = C.y

func update(dt: float, inp: Array) -> void:
	t += dt
	if solo < 0 and t > 15:
		R = maxf(60.0, 280 - (t - 15) * 4)
	for p in ps:
		if p.out:
			p.ot += dt
			continue
		var i: Dictionary = inp[p.id]
		p.cd -= dt
		p.dash -= dt
		if i.x != 0.0 or i.y != 0.0:
			p.fx = i.x
			p.fy = i.y
		var acc := 900.0 if p.id == solo else 1300.0
		p.vx += i.x * acc * dt
		p.vy += i.y * acc * dt
		if i.pressed and p.cd <= 0:
			var d := Vector2(p.fx, p.fy).normalized()
			p.vx += d.x * 480
			p.vy += d.y * 480
			p.cd = 1.1
			p.dash = .3
			G.beep(220, .06)
			G.burst(Vector2(p.x, p.y + 20), Color("#e8d2a0"), 6, 120)
		var f := pow(.15, dt)
		p.vx *= f
		p.vy *= f
		var v := Vector2(p.vx, p.vy)
		var mx := 650.0 if p.dash > 0 else (240.0 if p.id == solo else 320.0)
		if v.length() > mx:
			v = v.normalized() * mx
			p.vx = v.x
			p.vy = v.y
		p.x += p.vx * dt
		p.y += p.vy * dt
	for a in 4:
		for b in range(a + 1, 4):
			var A: Dictionary = ps[a]
			var Bp: Dictionary = ps[b]
			if A.out or Bp.out:
				continue
			var dv := Vector2(Bp.x - A.x, Bp.y - A.y)
			var d := dv.length()
			var rr: float = A.r + Bp.r
			if d >= rr or d == 0:
				continue
			var n := dv / d
			var ov: float = rr - d
			var tm: float = A.m + Bp.m
			A.x -= n.x * ov * Bp.m / tm
			A.y -= n.y * ov * Bp.m / tm
			Bp.x += n.x * ov * A.m / tm
			Bp.y += n.y * ov * A.m / tm
			var rel: float = (A.vx - Bp.vx) * n.x + (A.vy - Bp.vy) * n.y
			if rel > 0:
				var j: float = 1.7 * rel / (1.0 / A.m + 1.0 / Bp.m)
				if A.dash > 0 or Bp.dash > 0:
					j *= 1.5
				A.vx -= j / A.m * n.x
				A.vy -= j / A.m * n.y
				Bp.vx += j / Bp.m * n.x
				Bp.vy += j / Bp.m * n.y
				if rel > 180:
					G.beep(140, .06, "triangle")
					G.burst(Vector2((A.x + Bp.x) / 2, (A.y + Bp.y) / 2), Color("#fff6a0"), 8, 200)
					G.kick(5)
	for p in ps:
		if not p.out and Vector2(p.x, p.y).distance_to(C) > R + 6:
			p.out = true
			elim.append(p.id)
			G.beep(260, .3, "sine")
			G.burst(Vector2(p.x, p.y), [Color("#e8d2a0"), Color.WHITE], 16, 240)
	var al := alive_ids(ps)
	if solo < 0:
		if al.size() <= 1:
			result = standing_result(al, elim)
			done = true
	elif ps[solo].out:
		result = {"kind": "team", "winners": [0, 1, 2, 3].filter(func(i): return i != solo)}
		done = true
	elif al.size() == 1 or t >= dur:
		result = {"kind": "team", "winners": [solo]}
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.out:
		return {}
	var pos := Vector2(p.x, p.y)
	if pos.distance_to(C) > R * .7:
		var to := (C - pos).normalized()
		return {"x": to.x, "y": to.y}
	var tg = null
	var bd := 1e9
	for q in ps:
		if q.id == id or q.out or (solo >= 0 and id != solo and q.id != solo):
			continue
		var d := pos.distance_to(Vector2(q.x, q.y))
		if d < bd:
			bd = d
			tg = q
	if tg == null:
		return {}
	var tv := Vector2(tg.x, tg.y) - C
	var tn := tv.normalized()
	var behind: Vector2 = Vector2(tg.x, tg.y) - tn * (tg.r + p.r + 20)
	var is_behind := behind.distance_to(pos) < 45
	var m := seek(p, tg.x, tg.y) if is_behind else seek(p, behind.x, behind.y)
	m.press = is_behind and p.cd <= 0 and randf() < .1
	if m.press:
		p.fx = tg.x - p.x
		p.fy = tg.y - p.y
	return m

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#3a2a20"), Color("#1e140e"))
	Art.ellipse(ci, C + Vector2(0, 24), R + 40, R + 30, Color("#5a4030"))
	ci.draw_circle(C, R + 30, Color("#d8b878"))
	ci.draw_circle(C - Vector2(30, 30), (R + 30) * .8, Color("#e6c892"))
	ci.draw_circle(C - Vector2(60, 60), (R + 30) * .45, Color("#f4dfb0"))
	Art.ellipse_line(ci, C, R, R, Color("#a07a3a"), 12)
	for kk in 30:
		var a0 := kk * TAU / 30
		ci.draw_arc(C, R, a0, a0 + TAU / 60, 4, Color("#f0d890"), 4)
	for s: int in [-1, 1]:
		ci.draw_line(C + Vector2(s * 40, -30), C + Vector2(s * 40, 30), Color(.47, .31, .12, .6), 6)
	for p in by_y(ps):
		if p.out:
			if p.ot < 1:
				Art.pal(ci, p.x, p.y + p.ot * 30, p.r * (1 - p.ot * .5), p.id, {"alpha": 1 - p.ot, "dizzy": true})
			continue
		Art.pal(ci, p.x, p.y, p.r, p.id, {"fx": p.fx, "fy": p.fy, "move": Vector2(p.vx, p.vy).length() > 40, "squash": .85 if p.dash > 0 else 1.0, "tag": tag(p.id), "crown": p.id == solo, "ring": Art.TEAMC[1] if (solo >= 0 and p.id != solo) else null})
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t if solo >= 0 else null, "%d in the ring" % alive_ids(ps).size())
