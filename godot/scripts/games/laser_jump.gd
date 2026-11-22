extends MiniGame

const NAME := "Laser Jump"
const MODES := ["ffa", "1v3"]
const HOW := "Action: jump over the beam · Move to reposition · Solo (1 vs 3): left/right = speed, Action = flip"

static func desc(m: String) -> String:
	if m == "1v3":
		return "The solo pal controls the spinning laser: speed it up, slow it down and flip its direction to trip up the trio! The trio must survive 22 seconds."
	return "A laser sweeps round the platform, speeding up and suddenly flipping direction. Jump over it! More beams join later. No time limit. Last pal standing wins!"

const C := Vector2(640, 420)
const RR := 270.0
var solo := -1
var elim: Array = []
var a := 0.0
var dir := 1.0
var mag := 1.3
var warn := 0.0
var flip_t := 4.0
var beams := 1
var s_cd := 0.0
var ps: Array = []
var dur := 9999.0

func init(s: Dictionary) -> void:
	super.init(s)
	solo = st.solo if st.mode == "1v3" else -1
	dur = 22.0 if solo >= 0 else 9999.0
	a = randf() * TAU
	dir = 1.0 if randf() < .5 else -1.0
	flip_t = randf_range(3, 6)
	for i in 4:
		var an := a + PI * (.5 + i * .4)
		var p := new_pal(i, C.x + cos(an) * 170, C.y + sin(an) * 170)
		p.air = 0.0
		p.wt = 0.0
		p.wx = 0.0
		p.wy = 0.0
		ps.append(p)

func live() -> Array:
	return ps.filter(func(p): return not p.out and p.id != solo)

func update(dt: float, inp: Array) -> void:
	t += dt
	if solo < 0:
		mag = minf(3.3, 1.3 + t * .045)
		flip_t -= dt
		if flip_t <= 0 and warn <= 0:
			warn = .45
			flip_t = randf_range(2.2, 6)
			G.beep(420, .08, "square", .03)
	else:
		var i: Dictionary = inp[solo]
		mag = clampf(mag + i.x * 1.4 * dt, 1.0, 1.7 + t * .015)
		s_cd -= dt
		if i.pressed and s_cd <= 0 and warn <= 0:
			warn = .4
			s_cd = 1.8
			G.beep(420, .08, "square", .03)
	if warn > 0:
		warn -= dt
		if warn <= 0:
			dir = -dir
			G.burst(C, [Color("#ff4d4d"), Color.WHITE], 10, 200)
	beams = (2 if t > 18 else 1) if solo >= 0 else (3 if t > 45 else (2 if t > 20 else 1))
	a += dir * mag * dt
	for p in ps:
		if p.id == solo:
			continue
		if p.out:
			p.ot += dt
			continue
		var i: Dictionary = inp[p.id]
		p.air -= dt
		p.cd -= dt
		if i.pressed and p.air <= 0 and p.cd <= 0:
			p.air = .5
			p.cd = .55
			G.beep(520, .05, "triangle")
		var kk := minf(1.0, dt * 10)
		p.vx += (i.x * 210 - p.vx) * kk
		p.vy += (i.y * 210 - p.vy) * kk
		if i.x != 0.0 or i.y != 0.0:
			p.fx = i.x
			p.fy = i.y
		p.x += p.vx * dt
		p.y += p.vy * dt
		var dv := Vector2(p.x, p.y) - C
		var d := dv.length()
		if d > RR - 24:
			dv = dv.normalized() * (RR - 24)
		elif d < 62:
			dv = dv.normalized() * 62
		p.x = C.x + dv.x
		p.y = C.y + dv.y
		if p.air <= 0:
			d = dv.length()
			var ph := dv.angle()
			for b in beams:
				if absf(wrap_a(a + b * TAU / beams - ph)) < 34.0 / d:
					p.out = true
					elim.append(p.id)
					G.beep(200, .35, "sawtooth")
					G.burst(Vector2(p.x, p.y), [Color("#ff4d4d"), Color("#ffd23c"), Art.COLORS[p.id]], 18, 300)
					G.kick(6)
					break
	var lv := live()
	if solo < 0:
		if lv.size() <= 1:
			result = standing_result(lv.map(func(p): return p.id), elim)
			done = true
	elif lv.is_empty():
		result = {"kind": "team", "winners": [solo]}
		done = true
	elif t >= dur:
		result = {"kind": "team", "winners": [0, 1, 2, 3].filter(func(i): return i != solo)}
		done = true

func bot(id: int) -> Dictionary:
	if id == solo:
		var press := false
		for p in live():
			var ph := (Vector2(p.x, p.y) - C).angle()
			for b in beams:
				var d := wrap_a(a + b * TAU / beams - ph)
				if absf(d) < .5 and d * dir < 0 and p.air > .1 and randf() < .03:
					press = true
		return {"x": 1.0 if sin(t * .7 + 1) > 0 else -.3, "press": press}
	var p: Dictionary = ps[id]
	if p.out:
		return {}
	var dv := Vector2(p.x, p.y) - C
	var ph := dv.angle()
	var rd := maxf(1.0, dv.length())
	var press := false
	for b in beams:
		var d := wrap_a(a + b * TAU / beams - ph)
		var tt := (absf(d) - 34.0 / rd) / mag
		var app := d * dir < 0 or (warn > 0 and warn < .25 and d * dir > 0)
		if app and tt < .06 + randf() * .06 and tt > -.05 and randf() < .8:
			press = true
	p.wt -= 1.0 / 60.0
	if p.wt <= 0:
		var an := randf() * TAU
		var r2 := randf_range(150, 235)
		p.wx = C.x + cos(an) * r2
		p.wy = C.y + sin(an) * r2
		p.wt = randf_range(1.5, 3)
	var m := seek(p, p.wx, p.wy, 15)
	m.x *= .6
	m.y *= .6
	m.press = press
	return m

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#22163f"), Color("#090514"))
	for i in 50:
		ci.draw_rect(Rect2(fmod(i * 211.0, 1280), fmod(i * 137.0, 720), 2, 2), Color(1, 1, 1, .5))
	Art.ellipse(ci, C + Vector2(0, 18), RR + 6, RR, Color("#3a3360"))
	ci.draw_circle(C, RR, Color("#5a5290"))
	ci.draw_circle(C - Vector2(40, 40), RR * .8, Color("#6e66a8"))
	ci.draw_circle(C - Vector2(70, 70), RR * .45, Color("#8f86c8"))
	for r in [100.0, 180.0, 250.0]:
		Art.ellipse_line(ci, C, r, r, Color(1, 1, 1, .15), 3)
	for b in beams:
		var ba := a + b * TAU / beams
		var e := C + Vector2(cos(ba), sin(ba)) * RR
		var fl := warn > 0 and sin(t * 60) > 0
		ci.draw_line(C, e, Color(1, 1, 1, .5) if fl else Color(1, .24, .24, .35), 26)
		ci.draw_line(C, e, Color.WHITE if fl else Color("#ff3b3b"), 10)
		ci.draw_line(C, e, Color("#ffd0d0"), 3)
	ci.draw_circle(C, 46, Color("#2a2448"))
	Art.ellipse_line(ci, C, 46, 46, Art.OUT, 5)
	ci.draw_circle(C, 18, Color.WHITE if warn > 0 else Color("#ff3b3b"))
	for p in by_y(ps):
		if p.id == solo:
			continue
		if p.out:
			if p.ot < .8:
				Art.pal(ci, p.x, p.y - 20 - p.ot * 60, 22, p.id, {"alpha": 1 - p.ot / .8, "dizzy": true})
			continue
		var lift := sin((1 - p.air / .5) * PI) * 36 if p.air > 0 else 0.0
		Art.pal(ci, p.x, p.y - 20, 22, p.id, {"bob": lift, "fx": p.fx, "fy": p.fy, "move": p.air <= 0 and Vector2(p.vx, p.vy).length() > 40, "tag": tag(p.id), "mood": "happy" if lift > 0 else "", "ring": Art.TEAMC[1] if solo >= 0 else null})
	if solo >= 0:
		Art.pal(ci, 110, 640, 30, solo, {"crown": true, "tag": tag(solo) + " · laser boss", "fy": -1})
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t if solo >= 0 else null, ("%d beams · " % beams if beams > 1 else "") + "%d jumping" % live().size())
