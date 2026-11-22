extends MiniGame

const NAME := "Treasure Dig"
const MODES := ["ffa"]
const HOW := "Move · Action: dig (you stop for a moment, so choose carefully)"

static func desc(_m: String) -> String:
	return "Treasure is buried somewhere in the sand. Your radar ring glows red when you are close and blue when you are cold. Dig in the right spot to grab it! Most treasure wins."

var dur := 40.0
var sc := [0, 0, 0, 0]
var ps: Array = []
var holes: Array = []
var tr := Vector2(640, 410)

func init(s: Dictionary) -> void:
	super.init(s)
	ps = corners()
	for p in ps:
		p.dig = 0.0
		p.err = randf_range(-1, 1)
		p.et = 0.0
	_place()

func _place() -> void:
	tr = Vector2(randf_range(90, 1190), randf_range(160, 670))

func heat(p: Dictionary) -> float:
	return clampf(1 - Vector2(p.x, p.y).distance_to(tr) / 650, 0, 1)

func update(dt: float, inp: Array) -> void:
	t += dt
	for p in ps:
		var i: Dictionary = inp[p.id]
		if p.dig > 0:
			p.dig -= dt
			p.vx = 0.0
			p.vy = 0.0
			if p.dig <= 0:
				holes.append(Vector2(p.x, p.y + 14))
				if Vector2(p.x, p.y).distance_to(tr) < 48:
					sc[p.id] += 1
					G.burst(Vector2(p.x, p.y), [Color("#ffd23c"), Color("#fff3a0"), Color("#ff9f1c")], 30, 340)
					G.beep(880, .1)
					G.beep(1320, .2)
					G.kick(4)
					_place()
				else:
					G.burst(Vector2(p.x, p.y + 10), [Color("#d9b27a"), Color("#b8905a")], 8, 150)
			continue
		step_top(p, i, dt, 280, Rect2(50, 130, 1180, 560), false)
		if i.pressed and p.cd <= 0:
			p.dig = .45
			p.cd = .6
			G.beep(200, .08, "triangle", .03)
	push_apart(ps, 44)
	if holes.size() > 60:
		holes.pop_front()
	if t >= dur:
		result = score_result(sc)
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.dig > 0:
		return {}
	p.et -= 1.0 / 60.0
	var h := heat(p)
	if p.et <= 0:
		p.et = randf_range(.6, 1.2)
		p.err = randf_range(-1, 1) * (1.6 - h * 1.3)
	var d := Vector2(p.x, p.y).distance_to(tr)
	if d < 40 and randf() < .2:
		return {"press": true}
	var a: float = (tr - Vector2(p.x, p.y)).angle() + p.err
	return {"x": cos(a), "y": sin(a)}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#f5d79a"), Color("#e0b06a"))
	for i in 12:
		Art.ellipse(ci, Vector2(fmod(i * 331.0, 1280), 140 + fmod(i * 157.0, 560)), 160, 30, Color(.7, .5, .24, .18))
	for h in holes:
		Art.ellipse(ci, h, 22, 9, Color(.43, .27, .12, .5))
	for p in by_y(ps):
		var ht := heat(p)
		var pulse := (sin(t * (3 + ht * 14)) + 1) / 2
		var col := Color((80 + 175 * ht) / 255, (140 - 80 * ht) / 255, (255 - 200 * ht) / 255, .4 + .6 * pulse)
		Art.ellipse_line(ci, Vector2(p.x, p.y + 22), 40 + pulse * 6, 15 + pulse * 3, col, 5)
		pal_top(ci, p, {"tag": tag(p.id) + " · %d" % sc[p.id], "squash": .8 if p.dig > 0 else 1.0, "mood": "happy" if ht > .85 else ""})
		if p.dig > 0:
			var hnd := Vector2(p.x + 22, p.y)
			var d := Vector2(0, -30).rotated(sin(t * 30) * .5)
			ci.draw_line(hnd, hnd + d, Color("#8a5a32"), 6)
			Art.ellipse(ci, hnd + Vector2(0, 4), 9, 12, Color("#b8c4d0"))
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "Treasure found: %d" % int(sum(sc)))
