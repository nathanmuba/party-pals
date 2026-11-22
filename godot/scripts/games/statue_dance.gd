extends MiniGame

const NAME := "Statue Dance"
const MODES := ["ffa"]
const HOW := "Move while the music plays · Let go of everything when it stops!"
const NOTES := [523.0, 587.0, 659.0, 698.0, 784.0, 880.0, 988.0, 1046.0]
const TILE := [Color("#ff5ab4"), Color("#4ec3ff"), Color("#ffe066"), Color("#7dff9a")]

static func desc(_m: String) -> String:
	return "Dance around and collect stars while the music plays. The moment the music stops, FREEZE! Anyone still moving is out. Watch out for sneaky fake-out wobbles in the music. Last pal standing wins!"

var ps: Array = []
var stars: Array = []
var elim: Array = []
var sc := [0, 0, 0, 0]
var phase := "music"
var pt := 0.0
var length := 4.0
var note := 0.0
var fake := -1.0

func init(s: Dictionary) -> void:
	super.init(s)
	ps = corners()
	for p in ps:
		p.rd = 0.3
	length = randf_range(3, 5)

func faking() -> bool:
	return phase == "music" and fake >= 0 and pt > fake and pt < fake + .45

func update(dt: float, inp: Array) -> void:
	t += dt
	pt += dt
	if phase == "music":
		note -= dt
		if note <= 0:
			note = .22
			G.beep(NOTES.pick_random() / (2.2 if faking() else 1.0), .12, "sawtooth" if faking() else "triangle", .03)
		if stars.size() < 5 and randf() < dt * 2:
			stars.append({"x": randf_range(100, 1180), "y": randf_range(170, 660), "t": 0.0})
		if pt >= length:
			phase = "freeze"
			pt = 0.0
			length = randf_range(1.6, 3.2)
			for p in ps:
				p.rd = randf_range(.12, .5)
			G.kick(5)
			G.beep(90, .2, "square", .05)
	elif pt >= length:
		phase = "music"
		pt = 0.0
		length = maxf(1.6, randf_range(2.5, 5.5) - t * .02)
		fake = randf_range(.6, length - .6) if randf() < .45 else -1.0
	for s in stars:
		s.t += dt
	for p in ps:
		if p.out:
			p.ot += dt
			continue
		var i: Dictionary = inp[p.id]
		if phase == "freeze":
			p.vx *= pow(.0005, dt)
			p.vy *= pow(.0005, dt)
			p.x += p.vx * dt
			p.y += p.vy * dt
			if pt > .35 and (absf(i.x) + absf(i.y) > .2 or i.pressed):
				p.out = true
				elim.append(p.id)
				G.beep(150, .3, "sawtooth", .05)
				G.burst(Vector2(p.x, p.y), [Art.COLORS[p.id], Color.WHITE], 16, 240)
			continue
		step_top(p, i, dt, 300, Rect2(50, 130, 1180, 560), false)
		for s in stars.duplicate():
			if Vector2(s.x - p.x, s.y - p.y).length() < 36:
				sc[p.id] += 1
				G.burst(Vector2(s.x, s.y), [Color("#ffe066"), Color.WHITE], 10, 180)
				G.beep(1200, .05, "sine", .02)
				stars.erase(s)
	push_apart(ps, 44)
	var al := alive_ids(ps)
	if al.size() <= 1 or t >= 120:
		al.sort_custom(func(a, b): return sc[a] > sc[b])
		result = standing_result(al, elim)
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.out:
		return {}
	if phase == "freeze":
		return {"x": p.fx, "y": p.fy} if pt < p.rd else {}
	if faking() and randf() < .5:
		return {}
	var best = null
	var bd := 1e9
	for s in stars:
		var d := Vector2(s.x - p.x, s.y - p.y).length()
		if d < bd:
			bd = d
			best = s
	return seek(p, best.x, best.y) if best != null else seek(p, 640, 415, 40)

func draw(ci: CanvasItem) -> void:
	var on := phase == "music"
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color("#2a1650") if on else Color("#0b0716"))
	for i in 16:
		for j in 8:
			var lit := on and (i + j + int(t * 4)) % 3 == 0
			ci.draw_rect(Rect2(i * 80 + 2, 100 + j * 80 + 2, 76, 76), TILE[(i * 3 + j) % 4] if lit else (Color("#3a2470") if on else Color("#1a1030")))
	if faking():
		ci.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, .15))
	for s in stars:
		var sz := minf(1.0, s.t * 4) * 16
		Art.shape(ci, Vector2(s.x, s.y), sz, 3, Color("#ffe066"), t * 2)
	for p in by_y(ps):
		if p.out:
			if p.ot < 1:
				Art.pal(ci, p.x, p.y, 24, p.id, {"alpha": 1 - p.ot, "dizzy": true})
			continue
		pal_top(ci, p, {"tag": tag(p.id) + " · %d" % sc[p.id], "bob": absf(sin(t * 10 + p.id)) * 6 if on else 0.0, "mood": "happy" if on else "", "move": on and Vector2(p.vx, p.vy).length() > 40})
	if not on:
		Art.text(ci, "FREEZE!", Vector2(640, 360), 120, Color("#7fd6ff"))
	else:
		for k in 3:
			Art.text(ci, "♪", Vector2(200 + k * 440 + sin(t * 3 + k) * 40, 140 + sin(t * 2 + k) * 20), 40, Color("#ffe066"), 0, false)
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, "%d dancing" % alive_ids(ps).size())
