extends MiniGame

const NAME := "Fire Brigade"
const MODES := ["coop"]
const HOW := "Move to a fire · Hold Action: spray water"
const ROOFS := [Color("#c0504d"), Color("#4f81bd"), Color("#9bbb59"), Color("#8064a2")]

static func desc(_m: String) -> String:
	return "Fires keep breaking out across town and spreading to the houses next door! Stand on a burning house and HOLD the button to hose it down. Put out 32 fires together, and do not let 14 burn at once!"

const C := 10
const R := 5
const S := 110.0
var ox := (1280 - C * S) / 2.0
var oy := 150.0
var dur := 45.0
var goal := 32
var cells: Array = []
var ps: Array = []
var per := [0, 0, 0, 0]
var outn := 0
var ig := 1.0

func init(s: Dictionary) -> void:
	super.init(s)
	for _k in C * R:
		cells.append({"f": 0.0, "w": 0.0, "sp": randf_range(2, 4), "roof": randi() % 4})
	for cr in [[2, 1.5], [8, 1.5], [2, 3.5], [8, 3.5]]:
		var p := new_pal(ps.size(), ox + S * cr[0], oy + S * cr[1])
		p.spray = false
		p.tk = -1
		ps.append(p)

func cell_of(p: Dictionary) -> int:
	var c := int(floor((p.x - ox) / S))
	var r := int(floor((p.y - oy) / S))
	return r * C + c if (c >= 0 and c < C and r >= 0 and r < R) else -1

func burning() -> int:
	return cells.filter(func(c): return c.f > 0).size()

func update(dt: float, inp: Array) -> void:
	t += dt
	ig -= dt
	if ig <= 0:
		ig = maxf(.7, 2 - t * .03)
		var free := cells.filter(func(c): return c.f <= 0)
		if free.size() > 0:
			var fc: Dictionary = free.pick_random()
			fc.f = .01
	for k in cells.size():
		var c: Dictionary = cells[k]
		if c.f <= 0:
			continue
		c.f += dt
		c.sp -= dt
		if c.f > 3 and c.sp <= 0:
			c.sp = randf_range(2.5, 4)
			var r := k / C
			var cc := k % C
			var nb := []
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var x: int = cc + d[0]
				var y: int = r + d[1]
				if x >= 0 and x < C and y >= 0 and y < R and cells[y * C + x].f <= 0:
					nb.append(cells[y * C + x])
			if nb.size() > 0:
				var nc: Dictionary = nb.pick_random()
				nc.f = .01
	for p in ps:
		var i: Dictionary = inp[p.id]
		step_top(p, i, dt, 150.0 if i.act else 290.0, Rect2(ox + 12, oy + 12, C * S - 24, R * S - 24), false)
		p.spray = i.act
		var k := cell_of(p)
		if i.act and k >= 0 and cells[k].f > 0:
			cells[k].w += dt
			if cells[k].w >= 1.2:
				cells[k].f = 0.0
				cells[k].w = 0.0
				outn += 1
				per[p.id] += 1
				G.beep(900, .08, "sine")
				G.burst(Vector2(p.x, p.y - 30), [Color("#7fd6ff"), Color.WHITE], 16, 220)
	for c in cells:
		if c.f > 0:
			c.w = maxf(0.0, c.w - dt * .3)
	push_apart(ps, 44)
	if burning() >= 14 or t >= dur:
		result = {"kind": "coop", "collected": outn, "goal": goal, "per": per, "unit": "fires out"}
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	var best := -1
	var bd := 1e9
	for k in cells.size():
		var c: Dictionary = cells[k]
		if c.f <= 0:
			continue
		var pos := Vector2(ox + (k % C + .5) * S, oy + (k / C + .5) * S)
		var d: float = pos.distance_to(Vector2(p.x, p.y)) - c.f * 15
		for q in ps:
			if q.id != id and q.tk == k:
				d += 400
		if d < bd:
			bd = d
			best = k
	p.tk = best
	if best < 0:
		return {}
	if cell_of(p) == best:
		return {"press": true}
	return seek(p, ox + (best % C + .5) * S, oy + (best / C + .5) * S)

func draw(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color("#7a8a6a"))
	ci.draw_rect(Rect2(ox - 10, oy - 10, C * S + 20, R * S + 20), Color("#9aa88a"))
	for k in cells.size():
		var c: Dictionary = cells[k]
		var x := ox + (k % C) * S
		var y := oy + (k / C) * S
		ci.draw_rect(Rect2(x + 14, y + 40, S - 28, S - 50), Color("#d8d0c0"))
		var roof: Color = ROOFS[c.roof].darkened(.4) if c.f > 0 else ROOFS[c.roof]
		Art.poly(ci, [Vector2(x + 6, y + 44), Vector2(x + S / 2, y + 10), Vector2(x + S - 6, y + 44)], roof)
		var win := Color("#ffb84a") if c.f > 0 else Color("#7fb8e0")
		ci.draw_rect(Rect2(x + 26, y + 56, 18, 16), win)
		ci.draw_rect(Rect2(x + S - 44, y + 56, 18, 16), win)
		ci.draw_rect(Rect2(x + S / 2 - 10, y + 70, 20, 30), Color("#8a5a32"))
		if c.f > 0:
			var sz := minf(1.0, .4 + c.f * .15)
			for j in 4:
				var fx := x + 20 + j * 22
				var fh := (30 + sin(t * 12 + j + k) * 10) * sz
				Art.poly(ci, [Vector2(fx - 12, y + 60), Vector2(fx, y + 60 - fh * 1.4), Vector2(fx + 12, y + 60)], Color("#ff8c3c") if j % 2 else Color("#ffd23c"))
			if c.w > 0:
				Art.rrect(ci, Rect2(x + 15, y + S - 16, S - 30, 8), 4, Color(0, 0, 0, .5))
				Art.rrect(ci, Rect2(x + 15, y + S - 16, maxf(4.0, (S - 30) * c.w / 1.2), 8), 4, Color("#7fd6ff"))
	for p in by_y(ps):
		pal_top(ci, p, {"tag": tag(p.id) + " · %d" % per[p.id]})
		if p.spray:
			for j in 4:
				ci.draw_line(Vector2(p.x + 10, p.y - 20), Vector2(p.x + randf_range(-20, 30), p.y - randf_range(30, 60)), Color(.5, .84, 1, .8), 4)
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "Out: %d / %d · Burning: %d / 14" % [outn, goal, burning()])
