extends MiniGame

const NAME := "Tug of War"
const MODES := ["2v2"]
const HOW := "Press Action on the beat (watch the pulsing drum) · Mashing is weak"
const BEAT := .55
const WIN := 230.0

static func desc(_m: String) -> String:
	return "Pull together! Every press tugs the rope, but presses ON THE BEAT pull far harder than wild mashing. Drag the other team into the mud, or be ahead when time runs out!"

var dur := 30.0
var r := 0.0
var last_beat := 0
var pops: Array = []
var last_p := [0.0, 0.0, 0.0, 0.0]

func update(dt: float, inp: Array) -> void:
	t += dt
	var ph := fmod(t, BEAT)
	if int(t / BEAT) != last_beat:
		last_beat = int(t / BEAT)
		G.beep(180, .06, "square", .03)
	for i in 4:
		if not inp[i].pressed or t - last_p[i] < .09:
			continue
		last_p[i] = t
		var off := minf(ph, BEAT - ph)
		var strong := off < .09
		r += (-1.0 if st.team[i] == 0 else 1.0) * (9.0 if strong else 1.2)
		pops.append({"i": i, "t": 0.0, "s": strong})
		if strong:
			G.beep(500, .04, "triangle", .02)
	for q in pops:
		q.t += dt
	pops = pops.filter(func(q): return q.t < .5)
	if absf(r) >= WIN or t >= dur:
		var w := 0 if r < 0 else (1 if r > 0 else -1)
		result = {"kind": "team", "winners": [] if w < 0 else [0, 1, 2, 3].filter(func(i): return st.team[i] == w)}
		G.burst(Vector2(640 + r, 470), [Color("#8a5a32"), Color("#5a3a1e")], 30, 300)
		done = true

func bot(_i: int) -> Dictionary:
	var ph := fmod(t, BEAT)
	if minf(ph, BEAT - ph) < .03 + absf(gauss()) * .02 and randf() < .5:
		return {"press": true}
	if randf() < .025:
		return {"press": true}
	return {}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#9fe0ff"), Color("#e6f8ff"))
	ci.draw_rect(Rect2(0, 500, 1280, 220), Color("#7ac25a"))
	Art.ellipse(ci, Vector2(640, 520), 140, 30, Color("#6a4a2a"))
	Art.ellipse(ci, Vector2(640, 516), 120, 22, Color("#8a6a3a"))
	for x in [640 - WIN, 640 + WIN]:
		var y := 480.0
		while y < 560:
			ci.draw_line(Vector2(x, y), Vector2(x, y + 10), Color.WHITE, 4)
			y += 20
	var ry := 470.0
	ci.draw_line(Vector2(80 + r, ry), Vector2(1200 + r, ry), Color("#c99a5a"), 10)
	var x := 90.0
	while x < 1200:
		ci.draw_line(Vector2(x + r, ry - 5), Vector2(x + r + 8, ry + 5), Color("#a07a3a"), 2)
		x += 18
	Art.poly(ci, [Vector2(640 + r, ry), Vector2(625 + r, ry + 40), Vector2(655 + r, ry + 40)], Color("#ff5a4e"))
	for tm in 2:
		var ids := [0, 1, 2, 3].filter(func(i): return st.team[i] == tm)
		for k in ids.size():
			var i: int = ids[k]
			var px: float = (320.0 - k * 130 if tm == 0 else 960.0 + k * 130) + r
			var lean := (-1.0 if tm == 0 else 1.0) * (.15 + .1 * sin(t * 8 + i))
			ci.draw_set_transform(Vector2(px, ry + 10), lean)
			Art.pal(ci, 0, -10, 32, i, {"tag": tag(i), "ring": Art.TEAMC[tm], "mood": "happy" if pops.any(func(q): return q.i == i and q.s) else ""})
			ci.draw_set_transform(Vector2.ZERO)
			for q in pops:
				if q.i == i:
					Art.text(ci, "STRONG!" if q.s else "+", Vector2(px, ry - 80 - q.t * 60), 20 if q.s else 16, Color("#ffe066") if q.s else Color.WHITE)
	var ph := fmod(t, BEAT) / BEAT
	var pul := 1 + maxf(0.0, 1 - minf(ph, 1 - ph) * 8) * .35
	ci.draw_circle(Vector2(640, 200), 50 * pul, Color("#ff5a4e"))
	Art.ellipse_line(ci, Vector2(640, 200), 50 * pul, 50 * pul, Art.OUT, 5)
	ci.draw_circle(Vector2(640, 200), 34 * pul, Color("#fff3e0"))
	Art.text(ci, "BEAT", Vector2(640, 202), 18, Color("#2a1650"), 0, false)
	Art.text(ci, "Team " + Art.TEAMN[0] + " ◀", Vector2(300, 140), 26, Art.TEAMC[0])
	Art.text(ci, "▶ Team " + Art.TEAMN[1], Vector2(980, 140), 26, Art.TEAMC[1])
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "")
