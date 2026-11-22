extends MiniGame
## Three rounds of reaction: press exactly the button that lights up. Decoys and early presses cost 1.5s.

const NAME := "Quick Draw"
const MODES := ["ffa", "2v2"]
const HOW := "Controllers: the face button that lights up · Keyboard: the matching direction key · Early or wrong = +1.5s"

static func desc(m: String) -> String:
	return "Three rounds. A button lights up on the sign. Press exactly that button as fast as you can!" + (" Fastest team total wins." if m == "2v2" else " Fastest total time wins.")

## Labels by button position (bottom, right, left, top).
const XBOX := ["A", "B", "X", "Y"]
const NIN := ["B", "A", "Y", "X"]
const KEYS := ["↓", "→", "←", "↑"]
const BCOL := [Color("#ffc93c"), Color("#ff5a4e"), Color("#3ccf6e"), Color("#4e8dff")]

var rounds := 3
var ri := 0
var phase := "wait"
var pt := 0.0
var times := [0.0, 0.0, 0.0, 0.0]
var rt: Array = []
var fs: Array = []
var why: Array = []
var bot_rt: Array = []
var bot_fs: Array = []
var next_sig := 0.0
var decoy_at := -1.0
var target := 0
var decoy_btn := 0

func init(s: Dictionary) -> void:
	super.init(s)
	_new_round()

func _new_round() -> void:
	phase = "wait"
	pt = 0.0
	next_sig = randf_range(2.0, 4.5)
	decoy_at = randf_range(.8, next_sig - .7) if randf() < .6 else -1.0
	target = randi() % 4
	decoy_btn = randi() % 4
	rt = [null, null, null, null]
	fs = [false, false, false, false]
	why = ["", "", "", ""]
	bot_rt = [randf_range(.28, .55), randf_range(.28, .55), randf_range(.28, .55), randf_range(.28, .55)]
	bot_fs = [0, 1, 2, 3].map(func(_i): return decoy_at >= 0 and randf() < .12)

func decoy_on() -> bool:
	return phase == "wait" and decoy_at >= 0 and pt >= decoy_at and pt < decoy_at + .55

func _fail(i: int, w: String) -> void:
	rt[i] = 1.5
	fs[i] = true
	why[i] = w
	G.beep(110, .2, "sawtooth")

func update(dt: float, inp: Array) -> void:
	t += dt
	pt += dt
	if phase == "wait":
		for i in 4:
			if inp[i].btn >= 0 and rt[i] == null:
				_fail(i, "DECOY!" if decoy_on() else "TOO EARLY!")
		if pt >= next_sig:
			phase = "go"
			pt = 0.0
			G.beep(880, .15)
			G.kick(6)
	elif phase == "go":
		for i in 4:
			if inp[i].btn >= 0 and rt[i] == null:
				if inp[i].btn == target:
					rt[i] = pt
					G.beep(660, .05)
					G.burst(Vector2(Art.SEAT[i], 500), Art.COLORS[i], 10, 200)
				else:
					_fail(i, "WRONG BUTTON!")
		if not rt.has(null) or pt > 1.8:
			for i in 4:
				if rt[i] == null:
					rt[i] = 1.5
				times[i] += rt[i]
			phase = "show"
			pt = 0.0
			ri += 1
	elif pt > 1.8:
		if ri < rounds:
			_new_round()
		else:
			result = score_result(times, false)
			done = true

func bot(id: int) -> Dictionary:
	if rt[id] != null:
		return {}
	if phase == "go" and pt >= bot_rt[id]:
		return {"btn": (target + 1) % 4 if randf() < .06 else target}
	if bot_fs[id] and decoy_on() and pt > decoy_at + .25:
		return {"btn": decoy_btn}
	return {}

func _pad(ci: CanvasItem, c: Vector2, sz: float, hi: int, alpha := 1.0) -> void:
	var pos := [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]
	for k in 4:
		var on := k == hi
		var r := sz * (.62 if on else .4)
		var col: Color = BCOL[k] if on else Color(.24, .16, .35, .25)
		col.a *= alpha
		ci.draw_circle(c + pos[k] * sz, r, col)
		Art.ellipse_line(ci, c + pos[k] * sz, r, r, Color(Art.OUT, alpha), 6 if on else 3)
		if on:
			Art.text(ci, XBOX[k], c + pos[k] * sz + Vector2(0, 3), int(sz * .8))

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#ff9a5a"), Color("#7a2e6e"))
	ci.draw_circle(Vector2(640, 470), 170, Color("#ffd27a"))
	for i in 7:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(i * 220 - 60, 470), Vector2(i * 220 + 60, 390 - (i % 3) * 30), Vector2(i * 220 + 180, 470)]), Color("#8a3d6a"))
	ci.draw_rect(Rect2(0, 470, Art.W, 250), Color("#4a1f4f"))
	var s := Vector2(640, 240)
	ci.draw_rect(Rect2(s.x - 8, s.y + 110, 16, 130), Color("#7a4a2a"))
	Art.rrect(ci, Rect2(s.x - 190, s.y - 135, 380, 265), 26, Color("#f4e1c1"), 5)
	var live := phase == "go" or (phase == "show" and pt < .8)
	if live:
		_pad(ci, s + Vector2(0, -15), 62, target)
		Art.text(ci, "Xbox %s  ·  Switch %s  ·  Keys %s" % [XBOX[target], NIN[target], KEYS[target]], s + Vector2(0, 105), 20, Color("#2a1650"), 0, false)
	elif decoy_on():
		_pad(ci, s + Vector2(0, -15), 62, decoy_btn, .4)
		ci.draw_line(s + Vector2(-95, -105), s + Vector2(95, 70), Color("#4e8dff"), 10)
		Art.text(ci, "DECOY: DON'T PRESS!", s + Vector2(0, 105), 20, Color("#2f6fd6"), 0, false)
	elif phase == "wait":
		_pad(ci, s + Vector2(0, -15), 62, -1)
		Art.text(ci, "Wait for it…", s + Vector2(0, 105), 24, Color("#2a1650"), 0, false)
	else:
		_pad(ci, s + Vector2(0, -15), 62, target, .5)
	for i in 4:
		var x: float = Art.SEAT[i]
		var good: bool = rt[i] != null and not fs[i]
		var sh := sin(t * 30 + i) * 1.2 if phase == "wait" else 0.0
		Art.pal(ci, x + sh, 575, 38, i, {"tag": tag(i), "ring": ring(i), "dizzy": fs[i], "squash": .88 if good else 1.0, "cheer": good and phase != "wait", "fy": -1})
		if fs[i]:
			Art.text(ci, why[i] + " +1.5", Vector2(x, 645), 20, Color("#ff6b6b"))
		elif rt[i] != null and phase != "wait":
			Art.text(ci, "too slow" if rt[i] >= 1.5 else "%.3fs" % rt[i], Vector2(x, 645), 26)
		Art.text(ci, "Total %.2fs" % times[i], Vector2(x, 680), 18, Color("#e6d6ff"))
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, "Round %d / %d" % [mini(ri + 1, rounds), rounds])
