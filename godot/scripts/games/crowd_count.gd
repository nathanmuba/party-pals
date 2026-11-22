extends MiniGame

const NAME := "Crowd Count"
const MODES := ["ffa"]
const HOW := "Up / down: change guess by 1 · Left / right: by 5 · Action: lock it in"
const CCOL := [Color("#ff7ab6"), Color("#4ec3ff"), Color("#a3e05a")]
const CN := ["PINK", "BLUE", "GREEN"]

static func desc(_m: String) -> String:
	return "A crowd of critters stampedes past. Count them! The pal furthest from the right answer is out each round. Later on you only find out WHICH critters to count AFTER they have run past. Last pal standing wins!"

var elim: Array = []
var rnd_i := 0
var phase := "ask"
var pt := 0.0
var crit: Array = []
var truth := 0
var ctype := 0
var after := false
var guess := [10, 10, 10, 10]
var lock := [false, false, false, false]
var out := [false, false, false, false]
var lose: Array = []
var bot_at := [0.0, 0.0, 0.0, 0.0]

func init(s: Dictionary) -> void:
	super.init(s)
	_new_round()

func _new_round() -> void:
	phase = "ask"
	pt = 0.0
	crit = []
	ctype = randi() % 3
	after = rnd_i >= 1 and randf() < .6
	var n := []
	for _k in 3:
		n.append(randi() % 7 + 5 + mini(8, rnd_i * 2))
	truth = n[ctype]
	for ty in 3:
		for _k in n[ty]:
			var dir := -1 if (rnd_i >= 2 and randf() < .3) else 1
			crit.append({"ty": ty, "at": randf_range(0, 4.6), "y": randf_range(170, 650), "v": randf_range(220, 460) * dir, "x": -40.0 if dir > 0 else 1320.0, "hop": randf() * 6})
	guess = [10, 10, 10, 10]
	lock = out.duplicate()
	lose = []
	bot_at = [randf_range(1.5, 4.5), randf_range(1.5, 4.5), randf_range(1.5, 4.5), randf_range(1.5, 4.5)]

func alive() -> Array:
	return [0, 1, 2, 3].filter(func(i): return not out[i])

func update(dt: float, inp: Array) -> void:
	t += dt
	pt += dt
	if phase == "ask" and pt > 2.2:
		phase = "run"
		pt = 0.0
	elif phase == "run":
		for c in crit:
			if pt >= c.at:
				c.x += c.v * dt
		if pt > 6.6:
			phase = "guess"
			pt = 0.0
			G.beep(600, .1)
	elif phase == "guess":
		for i in alive():
			if lock[i]:
				continue
			var e := dir_edge(inp[i], i)
			if e == 3: guess[i] += 1
			if e == 0: guess[i] -= 1
			if e == 1: guess[i] += 5
			if e == 2: guess[i] -= 5
			guess[i] = clampi(guess[i], 0, 60)
			if e >= 0:
				G.beep(500, .02, "triangle", .02)
			if inp[i].pressed:
				lock[i] = true
				G.beep(800, .06)
		if alive().all(func(i): return lock[i]) or pt > 10:
			lock = [true, true, true, true]
			phase = "reveal"
			pt = 0.0
			var al := alive()
			var diff := al.map(func(i): return absi(guess[i] - truth))
			var mx: int = diff.max()
			var mn: int = diff.min()
			if mx > mn:
				for kk in al.size():
					if diff[kk] == mx:
						lose.append(al[kk])
						out[al[kk]] = true
						elim.append(al[kk])
				G.beep(150, .3, "sawtooth")
			else:
				G.beep(700, .1)
	elif phase == "reveal" and pt > 3.2:
		var al := alive()
		if al.size() <= 1 or rnd_i >= 9:
			al.sort_custom(func(a, b): return absi(guess[a] - truth) < absi(guess[b] - truth))
			result = standing_result(al, elim)
			done = true
		else:
			rnd_i += 1
			_new_round()

func bot(id: int) -> Dictionary:
	if phase != "guess" or lock[id] or out[id] or pt < bot_at[id]:
		return {}
	guess[id] = clampi(int(round(truth + gauss() * (1 + truth * .08) * (1.5 if after else 1.0))), 0, 60)
	lock[id] = true
	G.beep(800, .06)
	return {}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#9be36b"), Color("#5aa84a"))
	for i in 30:
		Art.ellipse(ci, Vector2(fmod(i * 211.0, 1280), 140 + fmod(i * 137.0, 560)), 30, 8, Color(1, 1, 1, .12))
	if phase == "run":
		var cs := crit.duplicate()
		cs.sort_custom(func(a, b): return a.y < b.y)
		for c in cs:
			if pt >= c.at and c.x > -60 and c.x < 1340:
				Art.pal(ci, c.x, c.y - absf(sin(t * 12 + c.hop)) * 10, 18, -1, {"color": CCOL[c.ty], "fx": signf(c.v), "move": true})
	var q := "How many %s critters?" % CN[ctype]
	if phase == "ask":
		Art.rrect(ci, Rect2(240, 250, 800, 200), 30, Color(.06, .03, .13, .75))
		Art.text(ci, "Round %d" % (rnd_i + 1), Vector2(640, 300), 28, Color("#cdbdff"))
		if after:
			Art.text(ci, "Count EVERY color. You will find out which one later!", Vector2(640, 370), 30, Color("#ffe066"))
		else:
			Art.text(ci, q, Vector2(640, 370), 40, CCOL[ctype])
		for kk in 3:
			Art.pal(ci, 520 + kk * 120, 520, 26, -1, {"color": CCOL[kk]})
	if phase == "run" and not after:
		Art.rrect(ci, Rect2(380, 80, 520, 46), 20, Color(.06, .03, .13, .6))
		Art.text(ci, "Count the %s ones!" % CN[ctype], Vector2(640, 103), 26, CCOL[ctype])
	if phase == "guess" or phase == "reveal":
		ci.draw_rect(Rect2(0, 0, 1280, 720), Color(.06, .03, .13, .82))
		Art.text(ci, q, Vector2(640, 140), 44, CCOL[ctype])
		if phase == "reveal":
			Art.text(ci, "Answer: %d" % truth, Vector2(640, 210), 40, Color("#ffe066"))
		else:
			Art.text(ci, "Lock in your guess!  (%d)" % maxi(0, int(ceil(10 - pt))), Vector2(640, 210), 24, Color("#cdbdff"))
		for i in 4:
			var x: float = Art.SEAT[i]
			var was_out: bool = out[i] and not lose.has(i)
			Art.pal(ci, x, 520, 36, i, {"tag": tag(i), "alpha": .35 if was_out else 1.0, "dizzy": lose.has(i), "cheer": phase == "reveal" and not out[i]})
			if was_out:
				Art.text(ci, "OUT", Vector2(x, 600), 22, Color("#ff6b6b"))
				continue
			Art.rrect(ci, Rect2(x - 60, 330, 120, 90), 20, Art.COLORS[i] if lock[i] else Color(1, 1, 1, .12))
			Art.text(ci, str(guess[i]), Vector2(x, 377), 48)
			var s := ""
			if phase == "reveal":
				s = ("OUT! off by %d" if lose.has(i) else "off by %d") % absi(guess[i] - truth)
			else:
				s = "LOCKED" if lock[i] else "picking…"
			Art.text(ci, s, Vector2(x, 600), 20, Color("#ff6b6b") if lose.has(i) else Color.WHITE)
	Art.hud(ci, NAME, null, "%d still counting" % alive().size())
