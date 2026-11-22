extends MiniGame

const NAME := "Arrow Rush"
const MODES := ["ffa"]
const HOW := "Press the direction as the arrow hits the outline · Red = opposite!"

static func desc(_m: String) -> String:
	return "Arrows fly up your lane. Press the matching direction as each one reaches the outline. RED arrows are reversed, so press the OPPOSITE way! Three slips and you are out. It keeps speeding up. Last pal standing wins!"

const TY := 180.0
const COL := [1, 3, 0, 2]   # direction -> column (left, down, up, right)
const NCOL := [Color("#ffd23c"), Color("#4ec3ff"), Color("#7dff9a"), Color("#ff9f1c")]
var notes: Array = []
var next_t := 2.4
var lives := [3, 3, 3, 3]
var out := [false, false, false, false]
var elim: Array = []
var fb: Array = [{"t": 0.0, "s": ""}, {"t": 0.0, "s": ""}, {"t": 0.0, "s": ""}, {"t": 0.0, "s": ""}]

func _hurt(i: int, why: String) -> void:
	lives[i] -= 1
	fb[i] = {"t": .5, "s": why}
	G.beep(130, .15, "sawtooth", .03)
	if lives[i] <= 0:
		out[i] = true
		elim.append(i)
		G.burst(Vector2(160 + i * 320, 500), Art.COLORS[i], 16, 220)
		G.kick(5)

func update(dt: float, inp: Array) -> void:
	t += dt
	while next_t < t + 5:
		var gap := maxf(.3, .78 - next_t * .011)
		var inv := next_t > 10 and randf() < minf(.38, .1 + next_t * .006)
		var plan := []
		var off := []
		for _i in 4:
			var pp := .985 - (.07 if inv else 0.0) - next_t * .0011
			var r := randf()
			plan.append("hit" if r < pp else ("wrong" if r < pp + (1 - pp) / 2 else "miss"))
			off.append(randf_range(-.07, .07))
		notes.append({"t": next_t, "d": randi() % 4, "inv": inv, "res": [0, 0, 0, 0], "plan": plan, "off": off})
		next_t += gap * .55 if (randf() < .18 and next_t > 8) else gap
	for i in 4:
		if out[i]:
			continue
		fb[i].t -= dt
		var e := dir_edge(inp[i], i)
		if e >= 0:
			for n in notes:
				if n.res[i] == 0 and absf(n.t - t) < .16:
					var want: int = OPP[n.d] if n.inv else n.d
					if e == want:
						n.res[i] = 1
						fb[i] = {"t": .35, "s": "PERFECT" if absf(n.t - t) < .06 else "GOOD"}
						G.beep(500 + n.d * 80, .04, "triangle", .02)
					else:
						n.res[i] = 2
						_hurt(i, "WRONG!")
					break
		for n in notes:
			if n.res[i] == 0 and t - n.t > .16 and not out[i]:
				n.res[i] = 2
				_hurt(i, "MISS")
	while notes.size() > 0 and notes[0].t < t - 1:
		notes.pop_front()
	var al := [0, 1, 2, 3].filter(func(i): return not out[i])
	if al.size() <= 1:
		result = standing_result(al, elim)
		done = true

func bot(id: int) -> Dictionary:
	if out[id]:
		return {}
	for n in notes:
		if n.res[id] == 0 and t >= n.t + n.off[id]:
			if n.plan[id] == "miss":
				return {}
			var want: int = OPP[n.d] if n.inv else n.d
			var d: int = want if n.plan[id] == "hit" else (want + 1 + randi() % 3) % 4
			return {"x": DIR_V[d].x, "y": DIR_V[d].y}
	return {}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#2a1650"), Color("#120a26"))
	var sp := minf(560.0, 300 + t * 3.2)
	for i in 4:
		var lx := 160.0 + i * 320
		Art.rrect(ci, Rect2(lx - 140, 80, 280, 630), 24, Color(1, 1, 1, .03 if out[i] else .07))
		for c in 4:
			Art.arrow(ci, Vector2(lx - 97 + c * 65, TY), [2, 0, 3, 1][c], 24, Color(1, 1, 1, .12))
		for n in notes:
			var y: float = TY + (n.t - t) * sp
			if y < TY - 60 or y > 760 or n.res[i] == 1:
				continue
			var cx: float = lx - 97 + COL[n.d] * 65
			var col: Color = Color(.33, .33, .33, .4) if n.res[i] == 2 else (Color("#ff3b5c") if n.inv else NCOL[n.d])
			Art.arrow(ci, Vector2(cx, y), n.d, 24, col)
			if n.inv and n.res[i] == 0:
				Art.ellipse_line(ci, Vector2(cx, y), 32, 32, Color("#ff3b5c"), 3)
		Art.pal(ci, lx, 650, 30, i, {"tag": tag(i), "dizzy": out[i] or (fb[i].t > 0 and (fb[i].s == "MISS" or fb[i].s == "WRONG!")), "alpha": .4 if out[i] else 1.0, "fy": -1, "cheer": fb[i].t > 0 and fb[i].s == "PERFECT"})
		for kk in 3:
			Art.heart(ci, Vector2(lx - 30 + kk * 30, 580), Color("#ff5a7a") if kk < lives[i] else Color(1, 1, 1, .15))
		if out[i]:
			Art.text(ci, "OUT", Vector2(lx, 400), 40, Color("#ff6b6b"))
		elif fb[i].t > 0:
			Art.text(ci, fb[i].s, Vector2(lx, TY + 60), 24, Color("#7dff9a") if fb[i].s == "PERFECT" else (Color("#ffe066") if fb[i].s == "GOOD" else Color("#ff6b6b")))
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, "Speed %d%%" % int(sp / 3))
