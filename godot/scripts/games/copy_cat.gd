extends MiniGame

const NAME := "Copy Cat"
const MODES := ["1v3"]
const HOW := "Solo: press directions to make the dance · Trio: repeat it with directions"
const AC := [Color("#ffd23c"), Color("#4ec3ff"), Color("#7dff9a"), Color("#ff9f1c")]

static func desc(_m: String) -> String:
	return "The solo pal makes up a dance of arrows, which flash up one at a time. The trio must copy it exactly! The solo pal wins a round if 2 or more of the trio slip up. First to 3 rounds wins."

var solo := 0
var trio: Array = []
var rnd_i := 0
var phase := "make"
var pt := 0.0
var seq: Array = []
var shown: Array = []
var pos := [0, 0, 0, 0]
var fail := [false, false, false, false]
var ok := [false, false, false, false]
var sw := 0
var tw := 0
var last_win := ""
var bt := [0.0, 0.0, 0.0, 0.0]

func init(s: Dictionary) -> void:
	super.init(s)
	solo = st.solo
	trio = [0, 1, 2, 3].filter(func(i): return i != solo)
	_start()

func length() -> int:
	return 3 + rnd_i

func _start() -> void:
	phase = "make"
	pt = 0.0
	seq = []
	shown = []
	for i in 4:
		bt[i] = randf_range(.35, .6)

func _add(d: int) -> void:
	seq.append(d)
	shown.append(t)
	G.beep(300 + d * 120, .08, "triangle", .03)

func update(dt: float, inp: Array) -> void:
	t += dt
	pt += dt
	var es := []
	for i in 4:
		es.append(dir_edge(inp[i], i))
	if phase == "make":
		if es[solo] >= 0:
			_add(es[solo])
		if pt > 7:
			while seq.size() < length():
				_add(randi() % 4)
		if seq.size() >= length():
			phase = "gap"
			pt = 0.0
	elif phase == "gap" and pt > 1:
		phase = "copy"
		pt = 0.0
		pos = [0, 0, 0, 0]
		fail = [false, false, false, false]
		ok = [false, false, false, false]
	elif phase == "copy":
		for i in trio:
			if ok[i] or fail[i]:
				continue
			var e: int = es[i]
			if e < 0:
				continue
			if e == seq[pos[i]]:
				pos[i] += 1
				G.beep(400 + e * 100, .04, "triangle", .02)
				if pos[i] >= seq.size():
					ok[i] = true
					G.burst(Vector2(Art.SEAT[trio.find(i) + 1] - 130, 560), Art.COLORS[i], 10, 160)
			else:
				fail[i] = true
				G.beep(120, .25, "sawtooth", .04)
		if trio.all(func(i): return ok[i] or fail[i]) or pt > 9:
			for i in trio:
				if not ok[i]:
					fail[i] = true
			var f := trio.filter(func(i): return fail[i]).size()
			if f >= 2:
				sw += 1
				last_win = "solo"
			else:
				tw += 1
				last_win = "trio"
			phase = "score"
			pt = 0.0
			G.beep(300 if last_win == "solo" else 900, .2)
	elif phase == "score" and pt > 2:
		if sw >= 3 or tw >= 3:
			result = {"kind": "team", "winners": [solo] if sw >= 3 else trio}
			done = true
		else:
			rnd_i += 1
			_start()

func bot(id: int) -> Dictionary:
	bt[id] -= 1.0 / 60.0
	if bt[id] > 0:
		return {}
	if id == solo:
		if phase != "make":
			return {}
		bt[id] = randf_range(.3, .5)
		var d := randi() % 4
		return {"x": DIR_V[d].x, "y": DIR_V[d].y}
	if phase != "copy" or ok[id] or fail[id]:
		return {}
	bt[id] = randf_range(.22, .4)
	if randf() < .5:
		return {}
	var want: int = seq[pos[id]]
	var d: int = (want + 1 + randi() % 3) % 4 if randf() < .025 + seq.size() * .022 else want
	return {"x": DIR_V[d].x, "y": DIR_V[d].y}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#3a1f5a"), Color("#140d26"))
	for kk in 8:
		Art.poly(ci, [Vector2(640, 0), Vector2(kk * 180 - 100, 720), Vector2(kk * 180, 720)], Color(1, .35, .7, .12))
	Art.rrect(ci, Rect2(380, 90, 520, 260), 30, Color("#5a3a8a"))
	var last_ago: float = (t - shown[shown.size() - 1]) if shown.size() > 0 else 9.0
	Art.pal(ci, 470, 300, 40, solo, {"crown": true, "tag": tag(solo) + " · dance leader", "cheer": phase == "make" and last_ago < .3})
	if (phase == "make" or phase == "gap") and last_ago < .55 and seq.size() > 0:
		var d: int = seq[seq.size() - 1]
		Art.arrow(ci, Vector2(680, 210), d, 70, AC[d])
	if phase == "make":
		Art.text(ci, "Make a dance of %d moves! (%d/%d)" % [length(), seq.size(), length()], Vector2(680, 320), 22)
	if phase == "copy":
		Art.text(ci, "COPY IT!", Vector2(680, 210), 48, Color("#ffe066"))
	if phase == "gap":
		Art.text(ci, "Remember it…", Vector2(680, 320), 22, Color("#cdbdff"))
	if phase == "score":
		Art.text(ci, (Art.NAMES[solo] + " wins the round!") if last_win == "solo" else "The trio copied it!", Vector2(680, 200), 34, Color("#ffe066"))
		Art.rrect(ci, Rect2(540, 250, 280, 60), 14, Color(0, 0, 0, .25))
		for kk in seq.size():
			Art.arrow(ci, Vector2(680 - (seq.size() - 1) * 18 + kk * 36, 280), seq[kk], 14, Color.WHITE)
	for k in trio.size():
		var i: int = trio[k]
		var x: float = Art.SEAT[k + 1] - 130
		Art.pal(ci, x, 560, 34, i, {"tag": tag(i), "ring": Art.TEAMC[1], "dizzy": fail[i] and phase != "make", "cheer": ok[i] and phase != "make"})
		if phase == "copy":
			var n := seq.size()
			for j in n:
				ci.draw_circle(Vector2(x - (n - 1) * 9 + j * 18, 620), 7, Art.COLORS[i] if j < pos[i] else Color(1, 1, 1, .2))
		if fail[i] and phase != "make":
			Art.text(ci, "SLIP!", Vector2(x, 500), 22, Color("#ff6b6b"))
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, "%s %d – %d Trio" % [Art.NAMES[solo], sw, tw])
