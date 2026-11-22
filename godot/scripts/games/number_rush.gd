extends MiniGame

const NAME := "Number Rush"
const MODES := ["ffa", "2v2"]
const HOW := "Move · Action: shove · Watch the NEXT number at the top"
const BC := [Color("#ff7ab6"), Color("#4ec3ff"), Color("#7dff9a"), Color("#ffc93c"), Color("#c77dff"), Color("#ff9f1c")]

static func desc(m: String) -> String:
	return "Numbered balls are scattered around. Everyone hunts for the SAME next number. Touch it first to score! Clear 1 to 12 and a new board appears. " + ("Highest team total wins." if m == "2v2" else "Most points wins!")

var dur := 40.0
var sc := [0, 0, 0, 0]
var ps: Array = []
var balls: Array = []
var nxt := 1
var nt := 0.0

func init(s: Dictionary) -> void:
	super.init(s)
	for xy in [[640, 250], [640, 600], [260, 420], [1020, 420]]:
		var p := new_pal(ps.size(), xy[0], xy[1])
		p.react = randf_range(.3, .8)
		ps.append(p)
	_board()

func _board() -> void:
	balls = []
	for n in range(1, 13):
		var b := {}
		for _k in 40:
			b = {"n": n, "x": randf_range(90, 1190), "y": randf_range(170, 670), "vx": randf_range(-30, 30), "vy": randf_range(-30, 30), "t": 0.0}
			if balls.all(func(q): return Vector2(q.x - b.x, q.y - b.y).length() > 110):
				break
		balls.append(b)
	nxt = 1
	nt = 0.0

func update(dt: float, inp: Array) -> void:
	t += dt
	nt += dt
	for b in balls:
		b.t += dt
		b.x += b.vx * dt
		b.y += b.vy * dt
		if b.x < 70 or b.x > 1210: b.vx *= -1
		if b.y < 160 or b.y > 680: b.vy *= -1
	for p in ps:
		step_top(p, inp[p.id], dt, 290)
	push_apart(ps, 46, true)
	for b in balls:
		if b.n != nxt:
			continue
		for p in ps:
			if Vector2(p.x - b.x, p.y - b.y).length() < 46:
				sc[p.id] += 1
				G.burst(Vector2(b.x, b.y), Art.COLORS[p.id], 16, 240)
				G.beep(700 + nxt * 30, .08, "sine")
				balls.erase(b)
				nxt += 1
				nt = 0.0
				for q in ps:
					q.react = randf_range(.25, .8)
				if nxt > 12:
					_board()
					G.beep(1046, .15)
				break
		break
	if t >= dur:
		result = score_result(sc)
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.stun > 0 or nt < p.react:
		return {}
	for b in balls:
		if b.n == nxt:
			var m := seek(p, b.x + b.vx * .3, b.y + b.vy * .3)
			m.press = shove_bot(p, ps, 80, .04)
			return m
	return {}

func draw(ci: CanvasItem) -> void:
	Art.checker(ci, Color("#e6f0ff"), Color("#d8e6ff"))
	for b in balls:
		var s := minf(1.0, b.t * 4)
		var c := Vector2(b.x, b.y)
		Art.ellipse(ci, c + Vector2(0, 28) * s, 30 * s, 9 * s, Color(0, 0, 0, .15))
		ci.draw_circle(c, 32 * s, BC[b.n % 6])
		Art.ellipse_line(ci, c, 32 * s, 32 * s, Art.OUT, 4)
		ci.draw_circle(c, 20 * s, Color.WHITE)
		Art.text(ci, str(b.n), c + Vector2(0, 2), int(26 * s), Color("#2a1650"), 0, false)
	for p in by_y(ps):
		pal_top(ci, p, {"tag": tag(p.id) + " · %d" % sc[p.id]})
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "")
	Art.rrect(ci, Rect2(710, 20, 170, 44), 22, Color("#ffe066"))
	Art.text(ci, "NEXT: %d" % nxt, Vector2(795, 42), 28, Color("#2a1650"), 0, false)
