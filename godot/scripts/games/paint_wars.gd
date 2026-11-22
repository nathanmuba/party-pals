extends MiniGame

const NAME := "Paint Wars"
const MODES := ["ffa", "2v2"]
const HOW := "Move to paint · Action: dash"

static func desc(m: String) -> String:
	return "Run around to paint the floor your " + ("team " if m == "2v2" else "") + "color, and paint over your rivals! Grab paint buckets for a big splash. Most floor painted when time runs out wins!"

const C := 20
const R := 11
const S := 56.0
var ox := (1280 - C * S) / 2.0
var oy := 98.0
var cells: Array = []
var ps: Array = []
var dur := 30.0
var bk: Array = []
var bt := 3.0

func init(s: Dictionary) -> void:
	super.init(s)
	cells.resize(C * R)
	cells.fill(-1)
	for cr in [[2, 2], [18, 2], [2, 9], [18, 9]]:
		var p := new_pal(ps.size(), ox + S * cr[0], oy + S * cr[1])
		p.tt = 0.0
		p.tg = Vector2(640, 410)
		ps.append(p)

func col_of(id: int) -> Color:
	return Art.TEAMC[st.team[id]] if st.mode == "2v2" else Art.COLORS[id]

func own(v: int) -> int:
	return -1 if v < 0 else (st.team[v] if st.mode == "2v2" else v)

func paint_at(x: float, y: float, id: int, rad := 0) -> void:
	var c0 := int(floor((x - ox) / S))
	var r0 := int(floor((y - oy) / S))
	for dr in range(-rad, rad + 1):
		for dc in range(-rad, rad + 1):
			var c := c0 + dc
			var r := r0 + dr
			if c >= 0 and c < C and r >= 0 and r < R:
				cells[r * C + c] = id

func scores() -> Array:
	var s := [0, 0, 0, 0]
	for v in cells:
		if v >= 0:
			s[v] += 1
	return s

func update(dt: float, inp: Array) -> void:
	t += dt
	bt -= dt
	if bt <= 0 and bk.size() < 2:
		bk.append({"x": randf_range(ox + 40, ox + C * S - 40), "y": randf_range(oy + 40, oy + R * S - 40), "t": 0.0})
		bt = randf_range(3, 5)
	for b in bk:
		b.t += dt
	for p in ps:
		step_top(p, inp[p.id], dt, 280, Rect2(ox + 14, oy + 14, C * S - 28, R * S - 28))
		paint_at(p.x, p.y, p.id)
		for b in bk.duplicate():
			if Vector2(b.x - p.x, b.y - p.y).length() < 40:
				paint_at(b.x, b.y, p.id, 2)
				G.burst(Vector2(b.x, b.y), col_of(p.id), 24, 300)
				G.beep(700, .1, "sine")
				G.kick(3)
				bk.erase(b)
	push_apart(ps, 46, true)
	if t >= dur:
		result = score_result(scores())
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.stun > 0:
		return {}
	p.tt -= 1.0 / 60.0
	if p.tt <= 0:
		p.tt = randf_range(.3, .6)
		var best = null
		var bs := 1e9
		for b in bk:
			var d := Vector2(b.x - p.x, b.y - p.y).length()
			if d < 260 and d - 200 < bs:
				bs = d - 200
				best = Vector2(b.x, b.y)
		if best == null:
			for _k in 14:
				var c := randi() % C
				var r := randi() % R
				var pos := Vector2(ox + (c + .5) * S, oy + (r + .5) * S)
				var d := pos.distance_to(Vector2(p.x, p.y))
				if d > 320:
					continue
				var v := own(cells[r * C + c])
				var sc := d + (400.0 if v == own(id) else (-80.0 if v >= 0 else 0.0)) + randf() * 60
				if sc < bs:
					bs = sc
					best = pos
		p.tg = best if best != null else Vector2(640, 410)
	var m := seek(p, p.tg.x, p.tg.y, 8)
	m.press = shove_bot(p, ps, 80, .03)
	return m

func draw(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color("#2a1f4a"))
	for r in R:
		for c in C:
			var v: int = cells[r * C + c]
			var col := (Color("#f4f0ff") if (r + c) % 2 else Color("#ebe4ff")) if v < 0 else col_of(v).lightened(.15 if (r + c) % 2 else .05)
			ci.draw_rect(Rect2(ox + c * S, oy + r * S, S, S), col)
	for b in bk:
		var s := minf(1.0, b.t * 4)
		var c := Vector2(b.x, b.y - absf(sin(t * 4)) * 6)
		Art.poly(ci, [c + Vector2(-18, -16) * s, c + Vector2(18, -16) * s, c + Vector2(14, 18) * s, c + Vector2(-14, 18) * s], Color("#d0d6e0"), 3)
		for kk in 4:
			ci.draw_circle(c + Vector2(-9 + kk * 6, -16) * s, 5 * s, Art.COLORS[kk])
	for p in by_y(ps):
		pal_top(ci, p)
	G.draw_parts(ci)
	var s := scores()
	var tot := float(C * R)
	var extra := ""
	if st.mode == "2v2":
		var tm := [0, 0]
		for i in 4:
			tm[st.team[i]] += s[i]
		extra = "%s %d%%  –  %d%% %s" % [Art.TEAMN[0], int(100 * tm[0] / tot), int(100 * tm[1] / tot), Art.TEAMN[1]]
	else:
		for i in 4:
			extra += "%s %d%%  " % [Art.NAMES[i][0], int(100 * s[i] / tot)]
	Art.hud(ci, NAME, dur - t, extra.strip_edges())
