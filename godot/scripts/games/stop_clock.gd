extends MiniGame

const NAME := "Stop the Clock"
const MODES := ["ffa", "2v2"]
const HOW := "Action: stop your clock · Count in your head!"

static func desc(m: String) -> String:
	if m == "2v2":
		return "Stop your clock exactly on the target time, but the numbers vanish after a few seconds! Three rounds. The team with the smallest total error wins."
	return "Stop your clock exactly on the target time, but the numbers vanish after a few seconds! The pal furthest off each round is out. Last pal standing wins!"

var team := false
var elim: Array = []
var rnd_i := 0
var phase := "ready"
var pt := 0.0
var target := 0.0
var vis := 3.0
var stop: Array = [null, null, null, null]
var tot := [0.0, 0.0, 0.0, 0.0]
var out := [false, false, false, false]
var lose: Array = []
var bstop := [0.0, 0.0, 0.0, 0.0]

func init(s: Dictionary) -> void:
	super.init(s)
	team = st.mode == "2v2"
	_new_round()

func _new_round() -> void:
	phase = "ready"
	pt = 0.0
	target = round(randf_range(5, 10) * 100) / 100.0
	vis = maxf(1.2, 3.0 - rnd_i * .35)
	stop = [null, null, null, null]
	for i in 4:
		if out[i]:
			stop[i] = -1.0
	lose = []
	for i in 4:
		bstop[i] = target + gauss() * .28 * (1 + rnd_i * .12)

func alive() -> Array:
	return [0, 1, 2, 3].filter(func(i): return not out[i])

func update(dt: float, inp: Array) -> void:
	t += dt
	pt += dt
	if phase == "ready" and pt > 2.2:
		phase = "run"
		pt = 0.0
		G.beep(880, .12)
	elif phase == "run":
		for i in alive():
			if stop[i] == null and (inp[i].pressed or pt > target + 3):
				stop[i] = minf(pt, target + 3)
				G.beep(600, .05)
		if alive().all(func(i): return stop[i] != null):
			phase = "reveal"
			pt = 0.0
			var al := alive()
			var d := al.map(func(i): return absf(stop[i] - target))
			for kk in al.size():
				tot[al[kk]] += d[kk]
			if not team:
				var mx: float = d.max()
				var mn: float = d.min()
				if mx - mn > .0001:
					for kk in al.size():
						if d[kk] == mx:
							lose.append(al[kk])
							out[al[kk]] = true
							elim.append(al[kk])
					G.beep(150, .3, "sawtooth")
	elif phase == "reveal" and pt > 3.4:
		rnd_i += 1
		if team:
			if rnd_i >= 3:
				result = score_result(tot, false)
				done = true
			else:
				_new_round()
		else:
			var al := alive()
			if al.size() <= 1 or rnd_i >= 10:
				al.sort_custom(func(a, b): return tot[a] < tot[b])
				result = standing_result(al, elim)
				done = true
			else:
				_new_round()

func bot(id: int) -> Dictionary:
	if phase != "run" or out[id] or stop[id] != null:
		return {}
	return {"press": true} if pt >= bstop[id] else {}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#1f3a5a"), Color("#0d1a2e"))
	var c := Vector2(640, 300)
	Art.rrect(ci, Rect2(c.x - 26, c.y - 190, 52, 36), 10, Color("#b8c4d0"), 6)
	ci.draw_circle(c, 150, Color("#d9e2ec"))
	Art.ellipse_line(ci, c, 150, 150, Art.OUT, 6)
	ci.draw_circle(c, 128, Color.WHITE)
	for kk in 60:
		var a := kk / 60.0 * TAU
		var r0 := 115.0 if kk % 5 else 105.0
		ci.draw_line(c + Vector2(sin(a), -cos(a)) * r0, c + Vector2(sin(a), -cos(a)) * 124, Color("#b8c4d0") if kk % 5 else Color("#2a1650"), 2 if kk % 5 else 4)
	var shown := pt if phase == "run" else (target if phase == "reveal" else 0.0)
	var hide := phase == "run" and pt > vis
	if not hide:
		var a := shown / 60.0 * TAU * 6
		ci.draw_line(c, c + Vector2(sin(a), -cos(a)) * 100, Color("#ff5a4e"), 5)
		Art.text(ci, "0.00" if phase == "ready" else "%.2f" % shown, c + Vector2(0, 60), 34, Color("#2a1650"), 0, false)
	else:
		ci.draw_circle(c, 128, Color(.12, .08, .24, .9))
		Art.text(ci, "???", c + Vector2(0, -10), 56, Color("#cdbdff"))
		Art.text(ci, "keep counting…", c + Vector2(0, 40), 20, Color("#cdbdff"), 0, false)
	Art.rrect(ci, Rect2(c.x - 170, 470, 340, 56), 24, Color("#ffe066"))
	Art.text(ci, "TARGET  %.2fs" % target, Vector2(c.x, 499), 32, Color("#2a1650"), 0, false)
	if phase == "ready":
		Art.text(ci, "Get ready… the numbers vanish after %.1fs" % vis, Vector2(640, 92), 24)
	for i in 4:
		var x: float = 140.0 + i * 170 if i < 2 else 970.0 + (i - 2) * 170
		var was_out: bool = out[i] and not lose.has(i)
		Art.pal(ci, x, 620, 32, i, {"tag": tag(i), "alpha": .35 if was_out else 1.0, "dizzy": lose.has(i), "cheer": phase == "reveal" and not out[i] and not team, "ring": ring(i), "squash": .88 if stop[i] != null and phase == "run" else 1.0})
		if was_out:
			Art.text(ci, "OUT", Vector2(x, 672), 20, Color("#ff6b6b"))
			continue
		var s = stop[i]
		if phase == "reveal" and s != null:
			Art.text(ci, "%.2fs" % s, Vector2(x, 550), 22)
			Art.text(ci, ("+" if s >= target else "−") + "%.2f" % absf(s - target), Vector2(x, 672), 20, Color("#ff6b6b") if lose.has(i) else Color("#7dff9a"))
		elif s != null and phase == "run":
			Art.text(ci, "STOPPED", Vector2(x, 550), 22)
		elif team:
			Art.text(ci, "total %.2f" % tot[i], Vector2(x, 672), 16, Color("#cdbdff"))
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, ("Round %d / 3" % mini(3, rnd_i + 1)) if team else "%d left" % alive().size())
