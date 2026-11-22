extends MiniGame

const NAME := "Order Up"
const MODES := ["coop"]
const HOW := "Touch a crate to grab (carry one at a time) · Touch the plate to add it"
const ING_C := [Color("#ff5a4e"), Color("#6bd17a"), Color("#ffd23c"), Color("#a0663a")]
const ING_N := ["Tomato", "Lettuce", "Cheese", "Patty"]
const BINS := [[110.0, 300.0, 0], [110.0, 560.0, 1], [1170.0, 300.0, 2], [1170.0, 560.0, 3]]
const PLATE := Vector2(640, 210)

static func desc(_m: String) -> String:
	return "Burger rush! Grab ingredients from the crates and drop them on the plate to finish each order. A wrong ingredient gets thrown away. Finish 7 orders together before closing time!"

var dur := 50.0
var goal := 7
var ps: Array = []
var per := [0, 0, 0, 0]
var done_n := 0
var need: Array = []
var have: Array = []
var flash := 0.0

func init(s: Dictionary) -> void:
	super.init(s)
	for xy in [[400, 420], [880, 420], [400, 600], [880, 600]]:
		var p := new_pal(ps.size(), xy[0], xy[1])
		p.c = -1
		ps.append(p)
	_new_order()

func _new_order() -> void:
	need = []
	for _k in (3 if done_n < 3 else 4):
		need.append(randi() % 4)
	have = []

func remaining() -> Array:
	var r := need.duplicate()
	for h in have:
		var k := r.find(h)
		if k >= 0:
			r.remove_at(k)
	return r

static func icon(ci: CanvasItem, c: Vector2, k: int, s := 14.0) -> void:
	var col: Color = ING_C[k]
	match k:
		0:
			ci.draw_circle(c, s, col)
			Art.ellipse_line(ci, c, s, s, Art.OUT, 2.5)
			ci.draw_rect(Rect2(c.x - 3, c.y - s - 4, 6, 6), Color("#3a9a4a"))
		1:
			var pts := []
			for a in 7:
				var rr := s * (.75 if a % 2 else 1.1)
				pts.append(c + Vector2(cos(a * .9), sin(a * .9)) * rr)
			Art.poly(ci, pts, col, 2.5)
		2:
			Art.poly(ci, [c + Vector2(-s, s * .7), c + Vector2(s, s * .7), c + Vector2(0, -s)], col, 2.5)
		_:
			Art.ellipse(ci, c, s * 1.2, s * .6, col)
			Art.ellipse_line(ci, c, s * 1.2, s * .6, Art.OUT, 2.5)

func update(dt: float, inp: Array) -> void:
	t += dt
	flash -= dt
	for p in ps:
		step_top(p, inp[p.id], dt, 270.0 if p.c >= 0 else 295.0, Rect2(50, 130, 1180, 560), false)
		for b in BINS:
			if Vector2(p.x - b[0], p.y - b[1]).length() < 70 and p.c != b[2]:
				p.c = b[2]
				G.beep(520 + b[2] * 60, .05, "triangle", .02)
		if p.c >= 0 and Vector2(p.x, p.y).distance_to(PLATE) < 80:
			if remaining().has(p.c):
				have.append(p.c)
				per[p.id] += 1
				G.beep(800, .06, "sine")
				G.burst(PLATE, ING_C[p.c], 8, 160)
				if remaining().is_empty():
					done_n += 1
					flash = 1.0
					G.beep(1046, .1)
					G.beep(1318, .2)
					G.burst(PLATE + Vector2(0, -20), Art.COLORS, 30, 320)
					G.kick(3)
					_new_order()
			else:
				flash = -.6
				G.beep(120, .2, "sawtooth", .04)
				p.stun = .3
				G.burst(PLATE, Color("#555555"), 8, 160)
			p.c = -1
	push_apart(ps, 46)
	if t >= dur or done_n >= goal:
		result = {"kind": "coop", "collected": done_n, "goal": goal, "per": per, "unit": "orders"}
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.stun > 0:
		return {}
	var r := remaining()
	if p.c >= 0 and r.has(p.c):
		return seek(p, PLATE.x, PLATE.y + 20, 20)
	for q in ps:
		if q.id != id and q.c >= 0:
			var k := r.find(q.c)
			if k >= 0:
				r.remove_at(k)
	if r.is_empty():
		return seek(p, PLATE.x + (120 if id % 2 else -120), PLATE.y + 160, 30)
	for b in BINS:
		if b[2] == r[0]:
			return seek(p, b[0] + (40 if b[0] < 640 else -40), b[1], 10)
	return {}

func draw(ci: CanvasItem) -> void:
	Art.checker(ci, Color("#f5efe6"), Color("#ebe2d4"), 64.0, 100.0)
	Art.rrect(ci, Rect2(440, 140, 400, 130), 20, Color("#8a5a32"))
	Art.rrect(ci, Rect2(450, 148, 380, 112), 16, Color("#b07a46"))
	Art.ellipse(ci, PLATE + Vector2(0, 10), 70, 26, Color.WHITE)
	Art.ellipse_line(ci, PLATE + Vector2(0, 10), 70, 26, Art.OUT, 3)
	Art.ellipse(ci, PLATE + Vector2(0, 4), 40, 12, Color("#e8a850"))
	for j in have.size():
		icon(ci, PLATE + Vector2(-30 + j * 20, -8 - j * 6), have[j], 11)
	if flash > 0:
		Art.text(ci, "ORDER UP!", PLATE + Vector2(0, -60), 30, Color("#3ccf6e"))
	elif flash < 0 and flash > -.6:
		Art.text(ci, "WRONG!", PLATE + Vector2(0, -60), 30, Color("#ff5a4e"))
	Art.rrect(ci, Rect2(870, 150, 250, 90), 14, Color.WHITE, 3)
	Art.text(ci, "Order #%d" % (done_n + 1), Vector2(995, 172), 18, Color("#2a1650"), 0, false)
	var left := remaining()
	var rem := left.duplicate()
	for j in need.size():
		icon(ci, Vector2(910 + j * 52, 212), need[j], 16)
		var k := rem.find(need[j])
		if k >= 0:
			rem.remove_at(k)
		else:
			ci.draw_polyline(PackedVector2Array([Vector2(896 + j * 52, 212), Vector2(906 + j * 52, 224), Vector2(926 + j * 52, 198)]), Color("#3ccf6e"), 5)
	for b in BINS:
		Art.rrect(ci, Rect2(b[0] - 50, b[1] - 40, 100, 80), 12, Color("#a0663a"), 4)
		ci.draw_line(Vector2(b[0] - 50, b[1]), Vector2(b[0] + 50, b[1]), Color("#7a4a20"), 3)
		icon(ci, Vector2(b[0] - 18, b[1] - 14), b[2], 13)
		icon(ci, Vector2(b[0] + 16, b[1] - 10), b[2], 13)
		icon(ci, Vector2(b[0], b[1] + 18), b[2], 13)
		Art.text(ci, ING_N[b[2]], Vector2(b[0], b[1] + 58), 16, Color("#2a1650"), 0, false)
	for p in by_y(ps):
		pal_top(ci, p)
		if p.c >= 0:
			icon(ci, Vector2(p.x, p.y - 62), p.c, 14)
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "Orders %d / %d" % [done_n, goal])
