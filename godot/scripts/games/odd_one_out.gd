extends MiniGame

const NAME := "Odd One Out"
const MODES := ["ffa"]
const HOW := "Move the cursor a square at a time · Action: pick"
const SZ := [[5, 3], [6, 3], [6, 4], [7, 4], [7, 4], [8, 5], [8, 5]]
const PAL := [Color("#ff7ab6"), Color("#4ec3ff"), Color("#7dff9a"), Color("#ffc93c"), Color("#c77dff")]

static func desc(_m: String) -> String:
	return "One shape in the grid is different. Move your cursor to it and grab it first! Pick the wrong one and you are locked out for that round. The differences get sneakier every round."

var sc := [0, 0, 0, 0]
var rnd_i := -1
var phase := "play"
var pt := 0.0
var C := 5
var R := 3
var S := 120.0
var ox := 0.0
var oy := 0.0
var base := 0
var col := Color.WHITE
var odd := 0
var odd_kind := 0
var cur: Array = []
var lock: Array = []
var win := -1
var bt: Array = []

func init(s: Dictionary) -> void:
	super.init(s)
	_new_round()

func _new_round() -> void:
	rnd_i += 1
	phase = "play"
	pt = 0.0
	C = SZ[rnd_i][0]
	R = SZ[rnd_i][1]
	S = minf(130.0, minf(1000.0 / C, 500.0 / R))
	ox = (1280 - C * S) / 2
	oy = 150 + (500 - R * S) / 2
	base = randi() % 4
	col = PAL.pick_random()
	odd = randi() % (C * R)
	odd_kind = 0 if rnd_i < 2 else (1 if rnd_i < 4 else 2)
	cur = [[0, 0], [C - 1, 0], [0, R - 1], [C - 1, R - 1]]
	lock = [false, false, false, false]
	win = -1
	bt = []
	for _i in 4:
		bt.append({"at": randf_range(1.6, 3.5) + rnd_i * .45, "step": 0.0, "tgt": -1})

func _pick(i: int) -> void:
	var k: int = cur[i][1] * C + cur[i][0]
	if k == odd:
		win = i
		sc[i] += 1
		phase = "reveal"
		pt = 0.0
		G.beep(880, .1)
		G.beep(1320, .15)
		G.burst(Vector2(ox + (cur[i][0] + .5) * S, oy + (cur[i][1] + .5) * S), Art.COLORS[i], 20, 260)
	else:
		lock[i] = true
		G.beep(120, .25, "sawtooth", .04)

func update(dt: float, inp: Array) -> void:
	t += dt
	pt += dt
	if phase == "play":
		for i in 4:
			if lock[i]:
				continue
			var e := dir_edge(inp[i], i)
			if e >= 0:
				cur[i][0] = clampi(cur[i][0] + int(DIR_V[e].x), 0, C - 1)
				cur[i][1] = clampi(cur[i][1] + int(DIR_V[e].y), 0, R - 1)
				G.beep(400, .02, "triangle", .01)
			if inp[i].pressed:
				_pick(i)
				if phase != "play":
					break
		if phase == "play" and (lock.all(func(x): return x) or pt > 14):
			phase = "reveal"
			pt = 0.0
	elif pt > 1.8:
		if rnd_i >= SZ.size() - 1:
			result = score_result(sc)
			done = true
		else:
			_new_round()

func bot(i: int) -> Dictionary:
	if phase != "play" or lock[i] or pt < bt[i].at:
		return {}
	var b: Dictionary = bt[i]
	b.step -= 1.0 / 60.0
	if b.step > 0:
		return {}
	b.step = randf_range(.1, .18)
	if b.tgt < 0:
		b.tgt = odd if randf() < .85 else randi() % (C * R)
	var tc: int = b.tgt % C
	var tr: int = b.tgt / C
	var cx: int = cur[i][0]
	var cy: int = cur[i][1]
	if cx < tc: return {"x": 1.0}
	if cx > tc: return {"x": -1.0}
	if cy < tr: return {"y": 1.0}
	if cy > tr: return {"y": -1.0}
	return {"press": true}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#2b1b55"), Color("#140d26"))
	Art.rrect(ci, Rect2(ox - 20, oy - 20, C * S + 40, R * S + 40), 24, Color(1, 1, 1, .06))
	for r in R:
		for c in C:
			var k := r * C + c
			var p := Vector2(ox + (c + .5) * S, oy + (r + .5) * S)
			var s := S * .32
			var kind := base
			var cc := col
			var rot := 0.0
			var sz := s
			if k == odd:
				if odd_kind == 0:
					kind = (base + 1 + rnd_i % 3) % 4
				elif odd_kind == 1:
					cc = col.darkened(.22) if rnd_i % 2 else col.lightened(.3)
				elif base == 0 or base == 2:
					sz = s * .82
				else:
					rot = .32
				if phase == "reveal":
					Art.rrect(ci, Rect2(p.x - S / 2 + 4, p.y - S / 2 + 4, S - 8, S - 8), 14, Color(1, .88, .4, .35))
			Art.shape(ci, p, sz, kind, cc, rot)
	for i in 4:
		var ins := 4.0 + i * 5
		Art.rrect(ci, Rect2(ox + cur[i][0] * S + ins, oy + cur[i][1] * S + ins, S - ins * 2, S - ins * 2), 12, Color(0, 0, 0, 0), 4, Color(1, 1, 1, .2) if lock[i] else Art.COLORS[i], false)
	for i in 4:
		var x := 180.0 + i * 307
		Art.pal(ci, x, 660, 24, i, {"dizzy": lock[i], "cheer": win == i, "alpha": .5 if lock[i] else 1.0})
		Art.text(ci, tag(i) + " · %d" % sc[i] + ("  LOCKED" if lock[i] else ""), Vector2(x + 40, 660), 18, Art.COLORS[i], -1)
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, "Round %d / %d" % [rnd_i + 1, SZ.size()])
