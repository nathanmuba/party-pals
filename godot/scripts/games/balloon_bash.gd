extends MiniGame

const NAME := "Balloon Bash"
const MODES := ["ffa", "2v2"]
const HOW := "Move · Action: dash-bump to pop a balloon"
const B := Rect2(70, 140, 1140, 540)

static func desc(m: String) -> String:
	return "Everyone has 4 balloons. Dash into rivals to pop one, but the walls are spiky and pop YOUR balloons too! " + ("Last team with balloons wins." if m == "2v2" else "Last pal with balloons wins!")

var ps: Array = []
var elim: Array = []

func init(s: Dictionary) -> void:
	super.init(s)
	ps = corners()
	for p in ps:
		p.b = 4
		p.inv = 0.0

func _pop(p: Dictionary, n: Vector2) -> void:
	p.b -= 1
	p.inv = 1.5
	p.stun = .35
	p.vx = n.x * 520
	p.vy = n.y * 520
	G.burst(Vector2(p.x, p.y - 50), [Art.COLORS[p.id].lightened(.4), Color.WHITE], 14, 260)
	G.beep(1000, .06, "square", .04)
	G.kick(4)
	if p.b <= 0:
		p.out = true
		elim.append(p.id)
		G.beep(220, .3, "sine")

func update(dt: float, inp: Array) -> void:
	t += dt
	for p in ps:
		if p.out:
			p.ot += dt
			continue
		var i: Dictionary = inp[p.id]
		p.inv -= dt
		dash_ctl(p, i, dt, 640)
		if p.stun <= 0:
			top_move(p, i, 285, dt)
		else:
			p.vx *= pow(.08, dt)
			p.vy *= pow(.08, dt)
		p.x += p.vx * dt
		p.y += p.vy * dt
		var hw := Vector2.ZERO
		if p.x < B.position.x + 22: hw = Vector2(1, 0)
		elif p.x > B.end.x - 22: hw = Vector2(-1, 0)
		elif p.y < B.position.y + 22: hw = Vector2(0, 1)
		elif p.y > B.end.y - 22: hw = Vector2(0, -1)
		var hard := hw != Vector2.ZERO and Vector2(p.vx, p.vy).length() > 330
		p.x = clampf(p.x, B.position.x + 22, B.end.x - 22)
		p.y = clampf(p.y, B.position.y + 22, B.end.y - 22)
		if hw != Vector2.ZERO:
			if hard and p.inv <= 0:
				_pop(p, hw)
			else:
				if hw.x != 0: p.vx = 0.0
				if hw.y != 0: p.vy = 0.0
	for a in 4:
		for b in range(a + 1, 4):
			var A: Dictionary = ps[a]
			var C2: Dictionary = ps[b]
			if A.out or C2.out:
				continue
			var dv := Vector2(C2.x - A.x, C2.y - A.y)
			var d := dv.length()
			if d >= 48 or d == 0:
				continue
			var n := dv / d
			var ov := (48 - d) / 2
			A.x -= n.x * ov
			A.y -= n.y * ov
			C2.x += n.x * ov
			C2.y += n.y * ov
			if A.dash > 0 and C2.inv <= 0 and foe(A, C2):
				_pop(C2, n * .75)
			elif C2.dash > 0 and A.inv <= 0 and foe(A, C2):
				_pop(A, -n * .75)
	var al := alive_ids(ps)
	if over_for(al):
		al.sort_custom(func(a, b): return ps[a].b > ps[b].b)
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
			var d: float = Vector2(q.x - p.x, q.y - p.y).length() + (200.0 if q.inv > 0 else 0.0)
			if d < bd:
				bd = d
				tg = q
	if tg == null:
		return {}
	var m := seek(p, tg.x, tg.y)
	if p.x < B.position.x + 120: m.x += 1.6
	if p.x > B.end.x - 120: m.x -= 1.6
	if p.y < B.position.y + 110: m.y += 1.2
	if p.y > B.end.y - 110: m.y -= 1.2
	if p.cd > .3:
		m.x *= -.6
		m.y *= -.6
	m.press = bd < 150 and p.cd <= 0 and tg.inv <= 0 and randf() < .05
	if m.press:
		p.fx = tg.x - p.x
		p.fy = tg.y - p.y
	return m

func draw(ci: CanvasItem) -> void:
	Art.checker(ci, Color("#bfe3ff"), Color("#acd7fb"))
	var x := B.position.x + 12
	while x < B.end.x:
		Art.poly(ci, [Vector2(x - 12, B.position.y), Vector2(x, B.position.y + 20), Vector2(x + 12, B.position.y)], Color("#8a8fa8"), 2)
		Art.poly(ci, [Vector2(x - 12, B.end.y), Vector2(x, B.end.y - 20), Vector2(x + 12, B.end.y)], Color("#8a8fa8"), 2)
		x += 24
	var y := B.position.y + 12
	while y < B.end.y:
		Art.poly(ci, [Vector2(B.position.x, y - 12), Vector2(B.position.x + 20, y), Vector2(B.position.x, y + 12)], Color("#8a8fa8"), 2)
		Art.poly(ci, [Vector2(B.end.x, y - 12), Vector2(B.end.x - 20, y), Vector2(B.end.x, y + 12)], Color("#8a8fa8"), 2)
		y += 24
	for p in by_y(ps):
		if p.out:
			if p.ot < 1:
				Art.pal(ci, p.x, p.y, 24, p.id, {"alpha": 1 - p.ot, "dizzy": true})
			continue
		for kk in p.b:
			var bx: float = p.x - 27 + kk * 18 + sin(t * 3 + kk) * 4
			var by: float = p.y - 70 - (kk % 2) * 10
			ci.draw_line(Vector2(p.x, p.y - 20), Vector2(bx, by + 16), Color(.16, .12, .24, .6), 1.5)
			Art.ellipse(ci, Vector2(bx, by), 12, 16, Art.COLORS[p.id].lightened(.35))
			Art.ellipse_line(ci, Vector2(bx, by), 12, 16, Art.OUT, 2)
			ci.draw_circle(Vector2(bx - 4, by - 6), 3, Color(1, 1, 1, .6))
		pal_top(ci, p, {"alpha": .5 if (p.inv > 0 and sin(t * 30) > 0) else 1.0})
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, "%d still floating" % alive_ids(ps).size())
