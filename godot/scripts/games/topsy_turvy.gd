extends MiniGame

const NAME := "Topsy Turvy"
const MODES := ["ffa"]
const HOW := "Move to dodge (check the sign!) · Action: quick roll"
const MAPN := ["NORMAL", "MIRRORED ⇆", "UPSIDE-DOWN ⇅", "ALL REVERSED", "ROTATED ↻"]

static func desc(_m: String) -> String:
	return "Dodge falling meteors and bouncing spike balls, but your controls keep scrambling! Watch the sign at the top: mirrored, upside-down, reversed or rotated. No time limit. Last pal standing wins!"

static func fmap(m: int, x: float, y: float) -> Vector2:
	match m:
		1: return Vector2(-x, y)
		2: return Vector2(x, -y)
		3: return Vector2(-x, -y)
		4: return Vector2(-y, x)
	return Vector2(x, y)

static func finv(m: int, a: float, b: float) -> Vector2:
	match m:
		1: return Vector2(-a, b)
		2: return Vector2(a, -b)
		3: return Vector2(-a, -b)
		4: return Vector2(b, -a)
	return Vector2(a, b)

var ps: Array = []
var elim: Array = []
var mets: Array = []
var spikes: Array = [{"x": 640.0, "y": 420.0, "vx": 200.0, "vy": 150.0}]
var cmap := 0
var nxt := -1
var sw := 5.0
var warn := 0.0
var mt := 1.5
var bmap := [0, 0, 0, 0]
var bdelay := [0.0, 0.0, 0.0, 0.0]

func init(s: Dictionary) -> void:
	super.init(s)
	for xy in [[340, 300], [940, 300], [340, 560], [940, 560]]:
		ps.append(new_pal(ps.size(), xy[0], xy[1]))

func _kill(p: Dictionary) -> void:
	p.out = true
	elim.append(p.id)
	G.beep(220, .35, "sawtooth")
	G.burst(Vector2(p.x, p.y), [Art.COLORS[p.id], Color.WHITE], 16, 260)
	G.kick(6)

func update(dt: float, inp: Array) -> void:
	t += dt
	sw -= dt
	if sw <= 0 and nxt < 0:
		nxt = (cmap + 1 + randi() % 4) % 5
		warn = 1.1
		G.beep(500, .1, "square", .03)
	if nxt >= 0:
		warn -= dt
		if warn <= 0:
			cmap = nxt
			nxt = -1
			sw = randf_range(3.5, 6.5)
			G.kick(4)
			G.beep(300, .2, "square", .04)
			for i in 4:
				bdelay[i] = randf_range(.35, .9)
	for i in 4:
		bdelay[i] -= dt
		if bdelay[i] <= 0:
			bmap[i] = cmap
	mt -= dt
	if mt <= 0:
		mt = maxf(.3, 1.1 - t * .014)
		var al := ps.filter(func(p): return not p.out)
		if randf() < .5 and al.size() > 0:
			var tg: Dictionary = al.pick_random()
			mets.append({"x": tg.x + randf_range(-40, 40), "y": tg.y + randf_range(-40, 40), "t": 0.0})
		else:
			mets.append({"x": randf_range(80, 1200), "y": randf_range(160, 670), "t": 0.0})
	if spikes.size() < mini(5, 1 + int(t / 12)):
		spikes.append({"x": randf_range(100, 1180), "y": 150.0, "vx": 210.0 if randf() < .5 else -210.0, "vy": 190.0})
	for s in spikes:
		s.x += s.vx * dt
		s.y += s.vy * dt
		if s.x < 40 or s.x > 1240: s.vx *= -1
		if s.y < 130 or s.y > 690: s.vy *= -1
		s.x = clampf(s.x, 40, 1240)
		s.y = clampf(s.y, 130, 690)
	for p in ps:
		if p.out:
			p.ot += dt
			continue
		var i: Dictionary = inp[p.id]
		var m := fmap(cmap, i.x, i.y)
		var mi := {"x": m.x, "y": m.y, "pressed": i.pressed}
		dash_ctl(p, mi, dt, 560)
		if p.stun <= 0:
			top_move(p, mi, 280, dt)
		p.x = clampf(p.x + p.vx * dt, 40, 1240)
		p.y = clampf(p.y + p.vy * dt, 130, 690)
		for s in spikes:
			if Vector2(s.x - p.x, s.y - p.y).length() < 44:
				_kill(p)
				break
	for m in mets.duplicate():
		m.t += dt
		if m.t >= .9:
			mets.erase(m)
			G.burst(Vector2(m.x, m.y), [Color("#ff8c3c"), Color("#ffd23c"), Color("#5a4030")], 16, 300)
			G.beep(90, .2, "sawtooth", .05)
			G.kick(5)
			for p in ps:
				if not p.out and Vector2(p.x - m.x, p.y - m.y).length() < 62:
					_kill(p)
	push_apart(ps, 48)
	var al := alive_ids(ps)
	if al.size() <= 1:
		result = standing_result(al, elim)
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.out:
		return {}
	var v := Vector2.ZERO
	var danger := false
	for m in mets:
		var d := Vector2(p.x - m.x, p.y - m.y)
		var l := maxf(1.0, d.length())
		if l < 130:
			v += d / l * 2.2
			if l < 70 and m.t > .55:
				danger = true
	for s in spikes:
		var d := Vector2(p.x - s.x, p.y - s.y)
		var l := maxf(1.0, d.length())
		if l < 170 and (s.vx * d.x + s.vy * d.y) / l < 60:
			v += d / l * 1.8
	v += Vector2((640 - p.x) / 900.0, (410 - p.y) / 500.0)
	if not p.has("wob") or randf() < .02:
		p.wob = Vector2(randf_range(-.6, .6), randf_range(-.6, .6))
	v += p.wob
	var u := finv(bmap[id], v.x, v.y)
	return {"x": u.x, "y": u.y, "press": danger and p.cd <= 0 and randf() < .4}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#3a2a6e"), Color("#1a1038"))
	for x in range(0, 1280, 80):
		for y in range(110, 720, 80):
			if ((x + y - 110) / 80) % 2 == 0:
				ci.draw_rect(Rect2(x, y, 80, 80), Color(1, 1, 1, .05))
	for m in mets:
		var kk: float = m.t / .9
		Art.ellipse(ci, Vector2(m.x, m.y), 62 * kk + 8, (62 * kk + 8) * .55, Color(.08, 0, 0, .15 + .4 * kk))
		Art.ellipse_line(ci, Vector2(m.x, m.y), 62, 34, Color(1, .31, .31, .3 + .6 * kk), 3)
		var my: float = m.y - (1 - kk) * 520
		ci.draw_circle(Vector2(m.x + (1 - kk) * 80, my), 16, Color("#ff8c3c"))
		ci.draw_circle(Vector2(m.x + (1 - kk) * 80 + 10, my - 14), 10, Color(1, .78, .31, .5))
	for s in spikes:
		var pts := []
		for kk in 16:
			var r := 18.0 if kk % 2 else 30.0
			var an := kk / 16.0 * TAU + t * 4
			pts.append(Vector2(s.x + cos(an) * r, s.y + sin(an) * r))
		Art.poly(ci, pts, Color("#8a8fa8"), 3)
		ci.draw_circle(Vector2(s.x - 4, s.y - 4), 7, Color("#c9cee0"))
	for p in by_y(ps):
		if p.out:
			if p.ot < 1:
				Art.pal(ci, p.x, p.y, 24, p.id, {"alpha": 1 - p.ot, "dizzy": true})
			continue
		pal_top(ci, p, {"mood": "ouch" if warn > 0 and nxt >= 0 else "", "dizzy": false})
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, "%d standing" % alive_ids(ps).size())
	var flash := nxt >= 0 and sin(t * 30) > 0
	Art.rrect(ci, Rect2(410, 76, 460, 52), 20, Color("#ff5a4e") if flash else Color(.06, .03, .13, .85))
	Art.text(ci, ("CHANGING TO: " + MAPN[nxt]) if nxt >= 0 else ("CONTROLS: " + MAPN[cmap]), Vector2(640, 103), 26, Color("#7dff9a") if (cmap == 0 and nxt < 0) else Color("#ffe066"))
