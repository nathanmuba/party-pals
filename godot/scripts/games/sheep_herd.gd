extends MiniGame

const NAME := "Sheep Herd"
const MODES := ["coop", "2v2"]
const HOW := "Move to herd (sheep flee from you) · Action: dash"

static func desc(m: String) -> String:
	if m == "coop":
		return "Sheep run away from you, so sneak round behind them and herd them into the pen at the top. Pen 16 sheep together before time runs out!"
	return "Sheep run away from you, so get behind them and herd them into YOUR team's pen. Most sheep penned wins!"

var coop := false
var dur := 40.0
var goal := 16
var ps: Array = []
var per := [0, 0, 0, 0]
var tsc := [0, 0]
var pens: Array = []
var sheep: Array = []
var queue: Array = []

func init(s: Dictionary) -> void:
	super.init(s)
	coop = st.mode == "coop"
	ps = corners()
	if coop:
		pens = [{"r": Rect2(530, 110, 220, 90), "team": 0}]
	else:
		pens = [{"r": Rect2(50, 320, 110, 190), "team": 0}, {"r": Rect2(1120, 320, 110, 190), "team": 1}]
	for _k in 7:
		_add()

func _add() -> void:
	sheep.append({"x": randf_range(460, 820), "y": randf_range(330, 500), "vx": 0.0, "vy": 0.0, "wt": 0.0, "w": Vector2.ZERO, "fx": 1.0})

func update(dt: float, inp: Array) -> void:
	t += dt
	for p in ps:
		step_top(p, inp[p.id], dt, 280)
	push_apart(ps, 46)
	for s in sheep.duplicate():
		var acc := Vector2.ZERO
		for p in ps:
			var dv := Vector2(s.x - p.x, s.y - p.y)
			var d := maxf(1.0, dv.length())
			if d < 170:
				acc += dv / d * (170 - d) / 170 * 900
		s.wt -= dt
		if s.wt <= 0:
			s.wt = randf_range(1, 2.5)
			s.w = Vector2.from_angle(randf() * TAU) * 60
		acc += s.w
		for q in sheep:
			if q != s:
				var dv := Vector2(s.x - q.x, s.y - q.y)
				var d := maxf(1.0, dv.length())
				if d < 40:
					acc += dv / d * 300
		s.vx += acc.x * dt
		s.vy += acc.y * dt
		var v := Vector2(s.vx, s.vy)
		if v.length() > 250:
			v = v.normalized() * 250
		v *= pow(.25, dt)
		s.vx = v.x
		s.vy = v.y
		if absf(s.vx) > 5:
			s.fx = signf(s.vx)
		s.x += s.vx * dt
		s.y += s.vy * dt
		if s.x < 40 or s.x > 1240: s.vx *= -1
		if s.y < 110 or s.y > 695: s.vy *= -1
		s.x = clampf(s.x, 40, 1240)
		s.y = clampf(s.y, 110, 695)
		for pn in pens:
			if pn.r.has_point(Vector2(s.x, s.y)):
				tsc[pn.team] += 1
				var best = null
				var bd := 1e9
				for p in ps:
					if not coop and st.team[p.id] != pn.team:
						continue
					var d := Vector2(p.x - s.x, p.y - s.y).length()
					if d < bd:
						bd = d
						best = p
				if best != null:
					per[best.id] += 1
				G.burst(Vector2(s.x, s.y), [Color.WHITE, Color("#ffe066")], 14, 200)
				G.beep(880, .08, "sine")
				sheep.erase(s)
				queue.append(1.2)
				break
	for k in queue.size():
		queue[k] -= dt
	while queue.size() > 0 and queue[0] <= 0:
		queue.pop_front()
		_add()
	if t >= dur:
		if coop:
			result = {"kind": "coop", "collected": tsc[0], "goal": goal, "per": per, "unit": "sheep"}
		else:
			result = {"kind": "team", "winners": [] if tsc[0] == tsc[1] else [0, 1, 2, 3].filter(func(i): return st.team[i] == (0 if tsc[0] > tsc[1] else 1))}
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.stun > 0:
		return {}
	var pen: Rect2 = pens[0].r if coop else pens[st.team[id]].r
	var pc := pen.get_center()
	var best = null
	var bd := 1e9
	for s in sheep:
		var d := Vector2(s.x - p.x, s.y - p.y).length()
		for q in ps:
			if q.id != id and (coop or st.team[q.id] == st.team[id]) and Vector2(s.x - q.x, s.y - q.y).length() < d - 30:
				d += 250
		if d < bd:
			bd = d
			best = s
	if best == null:
		return seek(p, 640, 420, 30)
	var u := Vector2(best.x, best.y) - pc
	u = u.normalized()
	var b := Vector2(best.x, best.y) + u * 80
	var db := b.distance_to(Vector2(p.x, p.y))
	var ds := Vector2(best.x - p.x, best.y - p.y).length()
	if db > 45:
		var m := seek(p, b.x, b.y)
		if ds < 120:
			var sv := Vector2(p.x - best.x, p.y - best.y).normalized()
			m.x += sv.x * .9
			m.y += sv.y * .9
		return m
	return seek(p, best.x, best.y)

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#9be36b"), Color("#6cc24a"))
	for i in 30:
		Art.ellipse(ci, Vector2(fmod(i * 211.0, 1280), 130 + fmod(i * 137.0, 560)), 26, 7, Color(1, 1, 1, .12))
	for pn in pens:
		var r: Rect2 = pn.r
		ci.draw_rect(r, Color(1, .94, .7, .6) if coop else Art.TEAMC[pn.team].lightened(.5))
		ci.draw_rect(r, Color("#8a5a32"), false, 8)
		for kk in 5:
			var x := r.position.x + r.size.x * kk / 4.0
			ci.draw_rect(Rect2(x - 5, r.position.y - 6, 10, 12), Color("#8a5a32"))
			ci.draw_rect(Rect2(x - 5, r.end.y - 6, 10, 12), Color("#8a5a32"))
		Art.text(ci, "PEN" if coop else Art.TEAMN[pn.team], r.get_center(), 22)
	var ss := sheep.duplicate()
	ss.sort_custom(func(a, b): return a.y < b.y)
	for s in ss:
		Art.ellipse(ci, Vector2(s.x, s.y + 18), 24, 7, Color(0, 0, 0, .2))
		for kk in 6:
			var c := Vector2(s.x - 14 + (kk % 3) * 14, s.y - 8 + int(kk / 3) * 12)
			ci.draw_circle(c, 11, Color.WHITE)
			Art.ellipse_line(ci, c, 11, 11, Art.OUT, 2.5)
		Art.ellipse(ci, Vector2(s.x + s.fx * 22, s.y - 4), 9, 11, Color("#2a2238"))
		ci.draw_circle(Vector2(s.x + s.fx * 24, s.y - 7), 2.5, Color.WHITE)
	for p in by_y(ps):
		pal_top(ci, p)
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, ("Penned %d / %d" % [tsc[0], goal]) if coop else ("%s %d – %d %s" % [Art.TEAMN[0], tsc[0], tsc[1], Art.TEAMN[1]]))
