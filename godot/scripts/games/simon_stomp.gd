extends MiniGame

const NAME := "Simon Stomp"
const MODES := ["ffa", "coop"]
const HOW := "Controllers: face buttons · Keyboard: direction keys · Wait until the pattern finishes!"

static func desc(m: String) -> String:
	if m == "coop":
		return "Watch the buttons light up, then repeat the whole pattern. It grows by one every round. The team shares 3 lives. Reach a pattern of 6!"
	return "Watch the buttons light up, then repeat the whole pattern. It grows by one every round and plays faster. One wrong press and you are out. No time limit. Last pal standing wins!"

var coop := false
var goal := 6
var elim: Array = []
var seq: Array = []
var phase := "show"
var pt := -0.8
var lives := 3
var best := 0
var good := [0, 0, 0, 0]
var pos := [0, 0, 0, 0]
var ok := [false, false, false, false]
var out := [false, false, false, false]
var wait := [0.0, 0.0, 0.0, 0.0]
var flash := [-1, -1, -1, -1]
var ft := [0.0, 0.0, 0.0, 0.0]
var slip := [false, false, false, false]
var bt := [0.0, 0.0, 0.0, 0.0]

func init(s: Dictionary) -> void:
	super.init(s)
	coop = st.mode == "coop"
	seq = [randi() % 4, randi() % 4]

func on_t() -> float:
	return maxf(.22, .55 - seq.size() * .025)

func step_t() -> float:
	return on_t() + .16

func alive() -> Array:
	return [0, 1, 2, 3].filter(func(i): return not out[i])

func _start_input() -> void:
	phase = "input"
	pt = 0.0
	pos = [0, 0, 0, 0]
	ok = out.duplicate()
	slip = [false, false, false, false]
	wait = [0.0, 0.0, 0.0, 0.0]
	bt = [randf_range(.4, .9), randf_range(.4, .9), randf_range(.4, .9), randf_range(.4, .9)]

func _fail(i: int) -> void:
	G.beep(110, .25, "sawtooth")
	G.kick(5)
	ok[i] = true
	slip[i] = true
	if coop:
		lives -= 1
	else:
		out[i] = true
		elim.append(i)
		G.burst(Vector2(Art.SEAT[i], 560), Art.COLORS[i], 14, 220)

func _finish() -> void:
	done = true
	if coop:
		result = {"kind": "coop", "collected": best, "goal": goal, "per": good, "unit": "pattern length"}
	else:
		result = standing_result(alive(), elim)

func _end_round() -> void:
	phase = "next"
	pt = 0.0
	if coop:
		if lives > 0:
			best = seq.size()
			for i in 4:
				if not slip[i]:
					good[i] += 1
		if lives <= 0 or best >= goal:
			_finish()
	else:
		for i in alive():
			good[i] += 1
		if over_for(alive()) or seq.size() >= 30:
			_finish()

func update(dt: float, inp: Array) -> void:
	t += dt
	pt += dt
	for i in 4:
		ft[i] -= dt
	if phase == "show":
		if pt >= seq.size() * step_t() + .25:
			_start_input()
	elif phase == "input":
		for i in alive():
			if ok[i]:
				continue
			wait[i] += dt
			var b: int = inp[i].btn
			if b >= 0:
				wait[i] = 0.0
				flash[i] = b
				ft[i] = .2
				if b == seq[pos[i]]:
					pos[i] += 1
					G.beep(330 + b * 110, .06, "triangle")
					if pos[i] >= seq.size():
						ok[i] = true
						G.burst(Vector2(Art.SEAT[i], 520), Art.COLORS[i], 10, 180)
				else:
					_fail(i)
			elif wait[i] > 4:
				_fail(i)
		if alive().all(func(i): return ok[i]):
			_end_round()
	elif phase == "next" and pt > 1.3 and not done:
		seq.append(randi() % 4)
		phase = "show"
		pt = -0.3

func bot(id: int) -> Dictionary:
	if phase != "input" or out[id] or ok[id]:
		return {}
	bt[id] -= 1.0 / 60.0
	if bt[id] > 0:
		return {}
	bt[id] = randf_range(.22, .5)
	var want: int = seq[pos[id]]
	var err := .006 + seq.size() * .011
	return {"btn": (want + 1 + randi() % 3) % 4 if randf() < err else want}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#3b2a7a"), Color("#1a1038"))
	for kk in 12:
		ci.draw_circle(Vector2(640, 300), 60 + kk * 55, Color(1, 1, 1, .05 / (1 + kk * .2)))
	var hi := -1
	if phase == "show" and pt >= 0:
		var kk := int(pt / step_t())
		if kk < seq.size() and pt - kk * step_t() < on_t():
			hi = seq[kk]
	Art.rrect(ci, Rect2(490, 110, 300, 300), 40, Color("#f4e1c1"), 5)
	Art.pad(ci, Vector2(640, 250), 78, hi)
	var msg := "WATCH!" if phase == "show" else ("YOUR TURN!" if phase == "input" else ("" if done else "Nice! One more…"))
	Art.text(ci, msg, Vector2(640, 385), 26, Color("#d6336c") if phase == "input" else Color("#2a1650"), 0, false)
	for i in 4:
		var x: float = Art.SEAT[i]
		Art.pad(ci, Vector2(x, 450), 20, flash[i] if ft[i] > 0 else -1, .3 if out[i] else 1.0)
		Art.pal(ci, x, 575, 36, i, {"tag": tag(i), "dizzy": out[i] or (slip[i] and phase != "show"), "cheer": ok[i] and not slip[i] and phase != "show", "alpha": .45 if out[i] else 1.0, "fy": -1})
		if out[i]:
			Art.text(ci, "OUT", Vector2(x, 637), 24, Color("#ff6b6b"))
		elif phase == "input":
			var n := seq.size()
			if n <= 12:
				for kk in n:
					ci.draw_circle(Vector2(x - (n - 1) * 8 + kk * 16, 637), 6, Art.COLORS[i] if kk < pos[i] else Color(1, 1, 1, .2))
			else:
				Art.text(ci, "%d / %d" % [pos[i], n], Vector2(x, 637), 20)
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, ("Lives %d · " % lives if coop else "") + "Pattern length %d" % seq.size())
