extends MiniGame

const NAME := "Mole Mallet"
const MODES := ["ffa", "coop"]
const HOW := "Move to a hole · Action: swing the mallet"

static func desc(m: String) -> String:
	if m == "coop":
		return "Moles pop out of the holes. Run over and bonk them! Gold moles are worth 3. Do NOT bonk the bomb moles. Bonk 50 together!"
	return "Moles pop out of the holes. Run over and bonk them! Gold moles are worth 3. Bonk a bomb mole and you lose 2 and get dazed. Most bonks wins!"

var coop := false
var dur := 30.0
var goal := 50
var sc := [0, 0, 0, 0]
var ps: Array = []
var holes: Array = []
var st2 := .5

func init(s: Dictionary) -> void:
	super.init(s)
	coop = st.mode == "coop"
	ps = corners()
	for p in ps:
		p.sw = 0.0
	for r in 3:
		for c in 4:
			holes.append({"x": 290.0 + c * 233, "y": 240.0 + r * 175, "up": 0.0, "ty": 0, "t": 0.0})

func update(dt: float, inp: Array) -> void:
	t += dt
	st2 -= dt
	if st2 <= 0:
		st2 = randf_range(.3, .6)
		var free := holes.filter(func(h): return h.up <= 0)
		if free.size() > 0:
			var h: Dictionary = free.pick_random()
			var r := randf()
			h.ty = 1 if r < .12 else (2 if r < .28 else 0)
			h.up = randf_range(1, 1.6)
			h.t = 0.0
	for h in holes:
		h.up -= dt
		h.t += dt
	for p in ps:
		var i: Dictionary = inp[p.id]
		step_top(p, i, dt, 310, Rect2(50, 130, 1180, 560), false)
		p.sw -= dt
		if i.pressed and p.cd <= 0 and p.stun <= 0:
			p.cd = .3
			p.sw = .2
			for h in holes:
				if h.up > 0 and Vector2(h.x - p.x, h.y - p.y).length() < 55:
					h.up = 0.0
					if h.ty == 2:
						if not coop:
							sc[p.id] -= 2
						p.stun = 1.0
						G.beep(90, .3, "sawtooth", .06)
						G.burst(Vector2(h.x, h.y), [Color("#ff8c3c"), Color("#333333")], 16, 260)
						G.kick(6)
					else:
						sc[p.id] += 3 if h.ty == 1 else 1
						G.beep(1200 if h.ty else 800, .07, "square", .03)
						G.burst(Vector2(h.x, h.y - 20), [Color("#ffd23c"), Color("#fff3a0")] if h.ty else [Color("#b07a46"), Color("#fff6a0")], 12, 220)
					break
	push_apart(ps, 44)
	if t >= dur:
		if coop:
			result = {"kind": "coop", "collected": maxi(0, int(sum(sc))), "goal": goal, "per": sc.map(func(v): return maxi(0, v)), "unit": "bonks"}
		else:
			result = score_result(sc)
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.stun > 0:
		return {}
	var best = null
	var bs := 1e9
	for h in holes:
		if h.up <= 0 or h.ty == 2:
			continue
		var d := Vector2(h.x - p.x, h.y - p.y).length()
		if d / 310 + .1 > h.up:
			continue
		var s := d - (150.0 if h.ty == 1 else 0.0)
		for q in ps:
			if q.id != id and Vector2(h.x - q.x, h.y - q.y).length() < d - 40:
				s += 300
		if s < bs:
			bs = s
			best = h
	if best == null:
		return seek(p, 640, 415, 60)
	var m := seek(p, best.x, best.y, 20)
	m.press = Vector2(best.x - p.x, best.y - p.y).length() < 45 and randf() < .35
	return m

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#8fd86a"), Color("#5aa84a"))
	for i in 30:
		Art.ellipse(ci, Vector2(fmod(i * 211.0, 1280), 130 + fmod(i * 137.0, 560)), 24, 6, Color(1, 1, 1, .1))
	for h in holes:
		Art.ellipse(ci, Vector2(h.x, h.y + 14), 52, 20, Color("#5a3a1e"))
		Art.ellipse(ci, Vector2(h.x, h.y + 14), 40, 14, Color("#2a1a0e"))
		if h.up > 0:
			var kk := minf(1.0, minf(h.t * 6, h.up * 6))
			var my: float = h.y + 14 - kk * 40
			var col := Color("#ffd23c") if h.ty == 1 else (Color("#2a2238") if h.ty == 2 else Color("#b07a46"))
			Art.ellipse(ci, Vector2(h.x, my), 28, 34 * kk, col)
			Art.ellipse_line(ci, Vector2(h.x, my), 28, 34 * kk, Art.OUT, 3)
			if kk > .5:
				for s: int in [-1, 1]:
					ci.draw_circle(Vector2(h.x + s * 9, my - 10), 6, Color.WHITE)
					ci.draw_circle(Vector2(h.x + s * 9, my - 9), 3, Art.OUT)
				Art.ellipse(ci, Vector2(h.x, my + 4), 8, 6, Color("#ff5a4e") if h.ty == 2 else Color("#ff9ab0"))
				if h.ty == 2:
					ci.draw_line(Vector2(h.x, my - 34), Vector2(h.x + 8, my - 46), Color("#c99a5a"), 3)
					ci.draw_circle(Vector2(h.x + 8, my - 47), 4 + randf() * 3, Color("#ffd23c"))
			Art.ellipse(ci, Vector2(h.x, h.y + 22), 52, 10, Color("#5a3a1e"))
	for p in by_y(ps):
		pal_top(ci, p, {"tag": tag(p.id) + " · %d" % sc[p.id]})
		var sw: float = (1 - p.sw / .2) * 1.6 if p.sw > 0 else 0.0
		var hand := Vector2(p.x + 18, p.y - 10)
		var dir := Vector2(0, -36).rotated(-1 + sw)
		ci.draw_line(hand, hand + dir, Color("#8a5a32"), 6)
		var head := hand + dir
		Art.rrect(ci, Rect2(head.x - 14, head.y - 9, 28, 16), 5, Color("#ff5a4e"), 2)
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, ("Team: %d / %d" % [maxi(0, int(sum(sc))), goal]) if coop else "")
