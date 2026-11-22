extends MiniGame

const NAME := "Bowling Blast"
const MODES := ["1v3"]
const HOW := "Bowler: left/right to aim, Action to roll, steer while it rolls · Pins: move to dodge"
const L0 := 340.0
const L1 := 940.0

static func desc(_m: String) -> String:
	return "The solo pal is the bowler and the trio are the pins! The bowler gets 6 rolls and can curve the ball while it rolls. Knock down 3 pins to win. The trio must dodge!"

var solo := 0
var trio: Array = []
var ps: Array = []
var rolls := 6
var hits := 0
var ball = null
var wait := 1.0

func init(s: Dictionary) -> void:
	super.init(s)
	solo = st.solo
	trio = [0, 1, 2, 3].filter(func(i): return i != solo)
	for i in 4:
		var p := new_pal(i, 640, 640)
		p.wt = 0.0
		p.wx = 640.0
		p.wy = 230.0
		ps.append(p)
	for k in trio.size():
		ps[trio[k]].x = 480.0 + k * 160
		ps[trio[k]].y = 230.0

func update(dt: float, inp: Array) -> void:
	t += dt
	wait -= dt
	var bw: Dictionary = ps[solo]
	var si: Dictionary = inp[solo]
	if ball == null:
		bw.x = clampf(bw.x + si.x * 300 * dt, L0 + 30, L1 - 30)
		if si.pressed and wait <= 0 and rolls > 0:
			ball = {"x": bw.x, "y": 600.0, "vx": 0.0, "vy": -820.0, "rot": 0.0, "hit": {}}
			rolls -= 1
			G.beep(150, .2, "triangle", .05)
	else:
		ball.vx = clampf(ball.vx + si.x * 520 * dt, -260, 260)
		ball.x += ball.vx * dt
		ball.y += ball.vy * dt
		ball.rot += dt * 8
		if ball.x < L0 + 24 or ball.x > L1 - 24:
			ball.vx *= -.5
			ball.x = clampf(ball.x, L0 + 24, L1 - 24)
		for id in trio:
			var p: Dictionary = ps[id]
			if ball.hit.has(id):
				continue
			if Vector2(p.x - ball.x, p.y - ball.y).length() < 62:
				ball.hit[id] = true
				hits += 1
				p.stun = 1.4
				p.vx = (p.x - ball.x) * 6
				p.vy = -200.0
				G.beep(300, .15, "square", .05)
				G.burst(Vector2(p.x, p.y), [Color.WHITE, Color("#ff5a4e")], 18, 280)
				G.kick(7)
		if ball.y < 90:
			ball = null
			wait = .8
			if hits >= 3 or rolls <= 0:
				result = {"kind": "team", "winners": [solo] if hits >= 3 else trio}
				done = true
	for id in trio:
		step_top(ps[id], inp[id], dt, 198, Rect2(L0 + 24, 150, L1 - L0 - 48, 180), false)
	push_apart(trio.map(func(i): return ps[i]), 46)

func bot(id: int) -> Dictionary:
	var bw: Dictionary = ps[solo]
	if id == solo:
		var tg = null
		var bd := 1e9
		for i in trio:
			var q: Dictionary = ps[i]
			var d: float = absf(q.x - (ball.x if ball != null else bw.x)) + (500.0 if q.stun > 0 else 0.0)
			if d < bd:
				bd = d
				tg = q
		if tg == null:
			return {}
		if ball != null:
			return {"x": clampf((tg.x - ball.x) / 60.0, -1, 1) * (1.0 if ball.y - tg.y > 120 else 0.0)}
		var dx: float = tg.x - bw.x
		return {"x": signf(dx) if absf(dx) > 14 else 0.0, "press": absf(dx) < 20 and randf() < .05}
	var p: Dictionary = ps[id]
	if p.stun > 0:
		return {}
	if ball != null and ball.y - p.y < 420 and ball.y > p.y:
		var side := -1.0 if p.x < ball.x + ball.vx * .3 else 1.0
		var room: float = p.x - L0 if side < 0 else L1 - p.x
		return {"x": -side if room < 70 else side}
	if p.wt < t:
		p.wt = t + randf_range(.8, 2)
		p.wx = randf_range(L0 + 40, L1 - 40)
		p.wy = randf_range(170, 310)
	return seek(p, p.wx, p.wy, 15)

func draw(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color("#2a1f4a"))
	ci.draw_polygon(PackedVector2Array([Vector2(L0, 80), Vector2(640, 80), Vector2(640, 720), Vector2(L0, 720)]), PackedColorArray([Color("#c8925a"), Color("#e6b87a"), Color("#e6b87a"), Color("#c8925a")]))
	ci.draw_polygon(PackedVector2Array([Vector2(640, 80), Vector2(L1, 80), Vector2(L1, 720), Vector2(640, 720)]), PackedColorArray([Color("#e6b87a"), Color("#c8925a"), Color("#c8925a"), Color("#e6b87a")]))
	ci.draw_rect(Rect2(L0 - 30, 80, 30, 640), Color("#3a2448"))
	ci.draw_rect(Rect2(L1, 80, 30, 640), Color("#3a2448"))
	for x in range(int(L0), int(L1), 40):
		ci.draw_line(Vector2(x, 80), Vector2(x, 720), Color(.47, .27, .12, .4), 2)
	for k in range(-2, 3):
		Art.poly(ci, [Vector2(640 + k * 60, 470), Vector2(630 + k * 60, 500), Vector2(650 + k * 60, 500)], Color("#8a4a2a"))
	ci.draw_rect(Rect2(L0, 140, L1 - L0, 200), Color(1, 1, 1, .25))
	for id in trio:
		var p: Dictionary = ps[id]
		pal_top(ci, p, {"ring": Art.TEAMC[1], "mood": "ouch" if p.stun > 0 else "", "dizzy": p.stun > 0})
		Art.ellipse(ci, Vector2(p.x, p.y - 34), 10, 6, Color.WHITE)
		Art.ellipse_line(ci, Vector2(p.x, p.y - 34), 10, 6, Color("#ff5a4e"), 4)
	if ball != null:
		var c := Vector2(ball.x, ball.y)
		ci.draw_circle(c, 30, Color("#1a1424"))
		Art.ellipse_line(ci, c, 30, 30, Art.OUT, 3)
		for hp in [Vector2(-6, -8), Vector2(6, -8), Vector2(0, 4)]:
			ci.draw_circle(c + hp.rotated(ball.rot), 3.5, Color("#555555"))
	var bw: Dictionary = ps[solo]
	Art.pal(ci, bw.x, 650, 30, solo, {"crown": true, "tag": tag(solo) + " · bowler", "fy": -1, "cheer": ball != null})
	if ball == null and rolls > 0:
		ci.draw_circle(Vector2(bw.x, 600), 20, Color("#1a1424"))
		var y := 580.0
		while y > 160:
			ci.draw_line(Vector2(bw.x, y), Vector2(bw.x, y - 8), Color(1, 1, 1, .5), 2)
			y -= 16
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, "Rolls left %d · Pins down %d / 3" % [rolls, hits])
