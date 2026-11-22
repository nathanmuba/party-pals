extends MiniGame

const NAME := "Beanstalk Scramble"
const MODES := ["ffa", "2v2"]
const HOW := "Left / right to move · Action: jump · Fall off the bottom of the screen and you are out"

static func desc(m: String) -> String:
	return ("Team climb! Best combined finish wins. " if m == "2v2" else "") + "Race up the giant beanstalk. The screen keeps rising faster, so move quickly! Brown wilted leaves collapse under you. Only trust the green ones."

const GAP := 118.0
const N := 34
var TOP := -(N + 1) * GAP
var leaves: Array = []
var plats: Array = []
var ps: Array = []
var order: Array = []
var cam := -720.0 + 90
var dur := 75.0

func vine(y: float) -> float:
	return 640 + sin(y / 260) * 150

func init(s: Dictionary) -> void:
	super.init(s)
	var px := 640.0
	for i in range(1, N + 1):
		var y := -i * GAP
		px = clampf(px + (-1 if randf() < .5 else 1) * randf_range(90, 240), 190, 1090)
		var row := [{"x": px, "y": y, "w": 130.0, "fake": false, "cr": -1.0, "gone": false, "fy": 0.0, "wob": randf() * 6}]
		var extra := 1 + randi() % 2
		for _k in extra:
			var x := 0.0
			var ok := false
			for _tr in 25:
				x = randf_range(170, 1110)
				ok = row.all(func(l): return absf(l.x - x) > 200)
				if ok:
					break
			if ok:
				row.append({"x": x, "y": y, "w": 130.0, "fake": randf() < .65, "cr": -1.0, "gone": false, "fy": 0.0, "wob": randf() * 6})
		leaves.append_array(row)
	plats = [{"x": 640.0, "y": 0.0, "w": 1400.0, "floor": true, "gone": false, "fake": false}]
	plats.append_array(leaves)
	plats.append({"x": 640.0, "y": TOP, "w": 1180.0, "goal": true, "gone": false, "fake": false})
	for i in 4:
		var p := new_pal(i, 400 + i * 160, 0)
		p.gnd = null
		p.fin = false
		p.best = 0.0
		p.tgt = null
		p.tt = 0.0
		ps.append(p)

func update(dt: float, inp: Array) -> void:
	t += dt
	var act := ps.filter(func(p): return not p.out and not p.fin)
	if act.size() > 0:
		cam -= minf(175.0, 50 + t * 3.4) * dt
		var lead: float = act.map(func(p): return p.y).min()
		if lead - cam < 230:
			cam += (lead - 230 - cam) * minf(1.0, dt * 6)
	cam = maxf(cam, TOP - 150)
	for l in leaves:
		if l.cr >= 0 and not l.gone:
			l.cr += dt
			if l.cr > .2:
				l.gone = true
				G.burst(Vector2(l.x, l.y), [Color("#b08a3a"), Color("#7a5a20")], 8, 140)
		elif l.gone:
			l.fy += dt * 400
	for p in act:
		var i: Dictionary = inp[p.id]
		p.vx += (i.x * 330 - p.vx) * minf(1.0, dt * 14)
		if i.x != 0.0:
			p.fx = i.x
		if i.pressed and p.gnd != null:
			p.vy = -800.0
			p.gnd = null
			G.beep(560, .05, "triangle")
		p.vy = minf(1100.0, p.vy + 2000 * dt)
		p.x = clampf(p.x + p.vx * dt, 24, 1256)
		var py: float = p.y
		p.y += p.vy * dt
		p.gnd = null
		if p.vy >= 0:
			for pl in plats:
				if pl.gone:
					continue
				if py <= pl.y + 1 and p.y >= pl.y and absf(p.x - pl.x) < pl.w / 2 + 8:
					p.y = pl.y
					p.vy = 0.0
					p.gnd = pl
					if pl.fake and pl.cr < 0:
						pl.cr = 0.0
						G.beep(180, .12, "sawtooth", .03)
					if pl.get("goal", false):
						p.fin = true
						order.append(p.id)
						G.beep(880, .1)
						G.beep(1175, .2)
						G.burst(Vector2(p.x, p.y - 20), Art.COLORS, 30, 360)
						if order.size() == 1:
							dur = minf(dur, t + 8)
					break
		p.best = minf(p.best, p.y)
		if p.y > cam + 720 + 40:
			p.out = true
			G.beep(220, .35, "sine")
			G.kick(4)
	if not ps.any(func(p): return not p.out and not p.fin) or t >= dur:
		var rest := ps.filter(func(p): return not p.fin)
		rest.sort_custom(func(a, b): return a.best < b.best)
		var full: Array = order + rest.map(func(p): return p.id)
		if st.mode == "ffa":
			result = {"kind": "rank", "order": full}
		else:
			var sc := [0, 0]
			for kk in 4:
				sc[st.team[full[kk]]] += kk
			var w: int = st.team[full[0]] if sc[0] == sc[1] else (0 if sc[0] < sc[1] else 1)
			result = {"kind": "team", "winners": [0, 1, 2, 3].filter(func(i): return st.team[i] == w)}
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.out or p.fin:
		return {}
	p.tt -= 1.0 / 60.0
	if p.gnd != null and (p.tgt == null or p.tgt.gone or p.tgt.y >= p.y - 20 or p.tt <= 0):
		var best = null
		var bs := 1e9
		for l in plats:
			if l.gone or l.get("floor", false):
				continue
			var dy: float = p.y - l.y
			if dy < 60 or dy > 170:
				continue
			if l.fake and randf() > .1:
				continue
			var sc: float = absf(l.x - p.x) - (500.0 if l.get("goal", false) else 0.0)
			if sc < bs:
				bs = sc
				best = l
		p.tgt = best
		p.tt = randf_range(.4, .8)
	if p.tgt == null:
		return {"x": clampf((640 - p.x) / 100, -1, 1)}
	var tx: float = clampf(p.x, 200, 1080) if p.tgt.get("goal", false) else p.tgt.x
	var dx: float = tx - p.x
	var on_fake: bool = p.gnd != null and p.gnd.fake
	var edge: bool = p.gnd != null and not p.gnd.get("floor", false) and absf(p.x - p.gnd.x) > p.gnd.w / 2 - 14 and signf(p.x - p.gnd.x) == signf(dx)
	return {"x": clampf(dx / 30, -1, 1), "press": p.gnd != null and (absf(dx) < 150 or on_fake or edge) and (edge or randf() < .5)}

func draw(ci: CanvasItem) -> void:
	var h := clampf(-cam / -TOP, 0, 1)
	Art.vgrad(ci, Color("#5aa9ff") if h > .7 else Color("#8fd8ff"), Color("#e6f8ff"))
	for i in 8:
		var y := fposmod(i * 170.0 - cam * .35, 920) - 100
		var x := fmod(i * 317.0, 1280)
		for cc in [[0, 0, 34], [38, -10, 44], [80, 0, 30]]:
			ci.draw_circle(Vector2(x + cc[0], y + cc[1]), cc[2], Color(1, 1, 1, .75))
	ci.draw_set_transform(Vector2(0, -cam))
	var vp := PackedVector2Array()
	var y := cam - 40
	while y < cam + 760:
		var yy := maxf(y, TOP)
		vp.append(Vector2(vine(yy), yy))
		y += 20
	ci.draw_polyline(vp, Color("#2f8a3a"), 58)
	ci.draw_polyline(vp, Color("#4fb84f"), 40)
	if cam + 720 > -10:
		ci.draw_rect(Rect2(0, 0, 1280, 140), Color("#8a5a32"))
		ci.draw_rect(Rect2(0, 0, 1280, 16), Color("#5ab45a"))
	for l in leaves:
		if l.y < cam - 40 or l.y > cam + 760:
			continue
		if l.gone and l.fy > 600:
			continue
		var ly: float = l.y + (l.fy if l.gone else 0.0)
		var sway: float = (sin(Art.time * 6 + l.wob) * .08 if l.fake else 0.0) + (sin(Art.time * 60) * .06 if l.cr >= 0 else 0.0)
		ci.draw_line(Vector2(vine(l.y), l.y + 10), Vector2(l.x, l.y + 8), Color("#8a6a2a") if l.fake else Color("#2f8a3a"), 6)
		var col := Color("#c9a24a") if l.fake else Color("#5fd35a")
		if l.gone:
			col.a = .6
		Art.ellipse(ci, Vector2(l.x, ly + 8), l.w / 2, 17, col, sway)
		Art.ellipse_line(ci, Vector2(l.x, ly + 8), l.w / 2, 17, Art.OUT, 3, sway)
		var vc := Color("#8a6a2a") if l.fake else Color("#2f8a3a")
		ci.draw_line(Vector2(l.x - l.w / 2 + 10, ly + 8), Vector2(l.x + l.w / 2 - 10, ly + 8), vc, 2.5)
		for kk in [-2, -1, 0, 1, 2]:
			ci.draw_line(Vector2(l.x + kk * 20, ly + 8), Vector2(l.x + kk * 20 + 12, ly - 1), vc, 2)
			ci.draw_line(Vector2(l.x + kk * 20, ly + 8), Vector2(l.x + kk * 20 + 12, ly + 17), vc, 2)
		if l.fake:
			for kk in 3:
				ci.draw_circle(Vector2(l.x - 30 + kk * 28, ly + 8 + (5 if kk % 2 else -4)), 5, Color(.35, .24, .08, .45))
	if TOP > cam - 200 and TOP < cam + 720:
		for kk in 12:
			ci.draw_circle(Vector2(70 + kk * 103, TOP + 20 + (kk % 2) * 8), 52, Color.WHITE)
		ci.draw_rect(Rect2(50, TOP + 10, 1180, 70), Color.WHITE)
		ci.draw_rect(Rect2(636, TOP - 110, 8, 110), Color("#ff5ab4"))
		Art.poly(ci, [Vector2(644, TOP - 110), Vector2(714, TOP - 90), Vector2(644, TOP - 70)], Color("#ff5ab4"), 3)
		Art.text(ci, "TOP!", Vector2(640, TOP + 50), 40, Color("#ffb000"))
	for p in ps:
		if p.out:
			continue
		Art.pal(ci, p.x, p.y - 21, 22, p.id, {"fx": p.fx, "fy": 0.0 if p.gnd != null else -1.0, "tag": ("#%d" % (order.find(p.id) + 1)) if p.fin else tag(p.id), "ring": ring(p.id),
			"move": p.gnd != null and absf(p.vx) > 40, "squash": 1.0 if p.gnd != null else (1.12 if p.vy < 0 else .92), "cheer": p.fin, "mood": "ouch" if p.gnd != null and p.gnd.fake else ""})
	G.draw_parts(ci)
	ci.draw_set_transform(Vector2.ZERO)
	ci.draw_polygon(PackedVector2Array([Vector2(0, 670), Vector2(1280, 670), Vector2(1280, 720), Vector2(0, 720)]), PackedColorArray([Color(1, .16, .31, 0), Color(1, .16, .31, 0), Color(1, .16, .31, .45), Color(1, .16, .31, .45)]))
	Art.rrect(ci, Rect2(1240, 100, 22, 580), 11, Color(.06, .03, .13, .55))
	for p in ps:
		if p.out:
			continue
		var f := clampf(p.y / TOP, 0, 1)
		ci.draw_circle(Vector2(1251, 670 - f * 560), 9, Art.COLORS[p.id])
		Art.ellipse_line(ci, Vector2(1251, 670 - f * 560), 9, 9, Art.OUT, 3)
	Art.hud(ci, NAME, dur - t, ("%d at the top" % order.size()) if order.size() else "%d climbing" % alive_ids(ps).size())
