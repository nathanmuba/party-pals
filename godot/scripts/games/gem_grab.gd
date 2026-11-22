extends MiniGame

const NAME := "Gem Grab"
const MODES := ["2v2", "coop"]
const HOW := "Move to run · Action: dash (stuns rivals in 2 vs 2)"

static func desc(m: String) -> String:
	return ("Grab gems together! Reach the team goal before time runs out. Gold gems are worth 3." if m == "coop" else "Grab more gems than the other team. Gold gems are worth 3. Dash into rivals to stun them!") + " Watch out for the bouncy bumpers!"

var coop := false
var goal := 90
var dur := 30.0
var ps: Array = []
var gems: Array = []
var per := [0, 0, 0, 0]
var spawn_t := 0.0
var bumps: Array = []

func init(s: Dictionary) -> void:
	super.init(s)
	coop = st.mode == "coop"
	for xy in [[200, 280], [1080, 280], [200, 560], [1080, 560]]:
		var p := new_pal(ps.size(), xy[0], xy[1])
		p.glad = 0.0
		ps.append(p)
	for xy in [[640, 410], [400, 250], [880, 250], [400, 580], [880, 580], [180, 420], [1100, 420]]:
		bumps.append({"x": float(xy[0]), "y": float(xy[1]), "r": 34.0, "hit": 0.0})
	for _k in 5:
		_spawn()

func _spawn() -> void:
	var q := {}
	for _k in 20:
		q = {"x": randf_range(110, 1170), "y": randf_range(150, 670), "gold": randf() < .12, "t": 0.0}
		if bumps.all(func(b): return Vector2(b.x - q.x, b.y - q.y).length() > b.r + 40):
			break
	gems.append(q)

func update(dt: float, inp: Array) -> void:
	t += dt
	spawn_t -= dt
	if gems.size() < 5 and spawn_t <= 0:
		_spawn()
		spawn_t = .35
	for gm in gems:
		gm.t += dt
	for b in bumps:
		b.hit -= dt
	for p in ps:
		var i: Dictionary = inp[p.id]
		p.glad -= dt
		dash_ctl(p, i, dt, 680)
		if p.stun <= 0:
			top_move(p, i, 300, dt)
		else:
			p.vx *= pow(.05, dt)
			p.vy *= pow(.05, dt)
		p.x = clampf(p.x + p.vx * dt, 50, 1230)
		p.y = clampf(p.y + p.vy * dt, 130, 690)
		for b in bumps:
			var dv := Vector2(p.x - b.x, p.y - b.y)
			var d := dv.length()
			if d < b.r + 24 and d > 0:
				var n := dv / d
				p.x = b.x + n.x * (b.r + 24)
				p.y = b.y + n.y * (b.r + 24)
				p.vx = n.x * 620
				p.vy = n.y * 620
				p.stun = maxf(p.stun, .3)
				p.dash = 0.0
				b.hit = .2
				G.beep(400, .06, "square", .03)
				G.burst(Vector2(p.x, p.y) - n * 20, [Color("#ffd23c"), Color("#ff7a3c")], 8, 200)
				G.kick(3)
		for gm in gems.duplicate():
			if Vector2(gm.x - p.x, gm.y - p.y).length() < 44:
				per[p.id] += 3 if gm.gold else 1
				gems.erase(gm)
				p.glad = .4
				G.beep(1046 if gm.gold else 784, .07, "sine")
				G.burst(Vector2(gm.x, gm.y), [Color("#ffd23c"), Color("#fff3a0")] if gm.gold else [Color("#59e3ff"), Color("#c6f6ff")], 10, 200)
	for a in 4:
		for b in range(a + 1, 4):
			var A: Dictionary = ps[a]
			var B: Dictionary = ps[b]
			var dv := Vector2(B.x - A.x, B.y - A.y)
			var l := dv.length()
			if l >= 50 or l == 0:
				continue
			var n := dv / l
			var ov := (50 - l) / 2
			A.x -= n.x * ov
			A.y -= n.y * ov
			B.x += n.x * ov
			B.y += n.y * ov
			if not coop and st.team[A.id] != st.team[B.id]:
				if A.dash > 0 and B.stun <= 0:
					_stun(B, n)
				if B.dash > 0 and A.stun <= 0:
					_stun(A, -n)
	if t >= dur:
		if coop:
			result = {"kind": "coop", "collected": int(sum(per)), "goal": goal, "per": per.duplicate(), "unit": "gems"}
		else:
			result = score_result(per)
		done = true

func _stun(p: Dictionary, n: Vector2) -> void:
	p.stun = 1.0
	p.vx = n.x * 400
	p.vy = n.y * 400
	G.beep(140, .12, "triangle")
	G.burst(Vector2(p.x, p.y - 20), Color("#fff6a0"), 10, 220)
	G.kick(5)

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.stun > 0:
		return {}
	var best = null
	var bd := 1e9
	for gm in gems:
		var d: float = Vector2(gm.x - p.x, gm.y - p.y).length() - (120.0 if gm.gold else 0.0)
		var mate_closer := false
		for m in ps:
			if m.id != id and (coop or st.team[m.id] == st.team[id]) and Vector2(gm.x - m.x, gm.y - m.y).length() < d - 20:
				mate_closer = true
		var sc := d + (260.0 if mate_closer else 0.0)
		if sc < bd:
			bd = sc
			best = gm
	if not coop and p.cd <= 0:
		for q in ps:
			if st.team[q.id] != st.team[id] and q.stun <= 0 and Vector2(q.x - p.x, q.y - p.y).length() < 110 and randf() < .05:
				p.fx = q.x - p.x
				p.fy = q.y - p.y
				return {"x": (q.x - p.x) / 100.0, "y": (q.y - p.y) / 100.0, "press": true}
	if best == null:
		return {}
	var v := Vector2(best.x - p.x, best.y - p.y).normalized()
	for b in bumps:
		var bv := Vector2(p.x - b.x, p.y - b.y)
		var bd2 := maxf(1.0, bv.length())
		if bd2 < b.r + 70 and v.dot(-bv / bd2) > .3:
			var side := 1.0 if (bv.x * v.y - bv.y * v.x) > 0 else -1.0
			v += Vector2(-bv.y, bv.x) / bd2 * side * 1.2
	return {"x": v.x, "y": v.y}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#7ad98a"), Color("#2f8f55"))
	for x in range(0, 1280, 80):
		for y in range(110, 720, 80):
			if ((x + y - 110) / 80) % 2 == 0:
				ci.draw_rect(Rect2(x, y, 80, 80), Color(1, 1, 1, .07))
	for b in bumps:
		var sc := 1.18 if b.hit > 0 else 1.0
		Art.ellipse(ci, Vector2(b.x, b.y + 16), b.r, b.r * .45, Color(0, 0, 0, .25))
		ci.draw_circle(Vector2(b.x, b.y), b.r * sc, Color("#ff7a3c"))
		Art.ellipse_line(ci, Vector2(b.x, b.y), b.r * sc, b.r * sc, Art.OUT, 4)
		ci.draw_circle(Vector2(b.x, b.y), b.r * .55 * sc, Color("#ffd23c"))
		ci.draw_circle(Vector2(b.x - 9, b.y - 10), 6, Color(1, 1, 1, .5))
	for gm in gems:
		var s := minf(1.0, gm.t * 4)
		var by := sin(gm.t * 4 + gm.x) * 4
		var c := Vector2(gm.x, gm.y + by)
		Art.ellipse(ci, Vector2(gm.x, gm.y + 22), 14 * s, 5 * s, Color(0, 0, 0, .2))
		Art.poly(ci, [c + Vector2(0, -20) * s, c + Vector2(16, -4) * s, c + Vector2(0, 18) * s, c + Vector2(-16, -4) * s], Color("#ffd23c") if gm.gold else Color("#59e3ff"), 3)
		Art.poly(ci, [c + Vector2(0, -14) * s, c + Vector2(7, -4) * s, c + Vector2(0, -2) * s], Color(1, 1, 1, .6))
	for p in by_y(ps):
		pal_top(ci, p, {"r": 25.0, "mood": "happy" if p.glad > 0 else "", "tag": tag(p.id) + " · %d" % per[p.id], "ring": null if coop else Art.TEAMC[st.team[p.id]]})
	G.draw_parts(ci)
	var extra := ""
	if coop:
		extra = "Team: %d / %d" % [int(sum(per)), goal]
	else:
		var s := [0, 0]
		for i in 4:
			s[st.team[i]] += per[i]
		extra = "%s %d  –  %d %s" % [Art.TEAMN[0], s[0], s[1], Art.TEAMN[1]]
	Art.hud(ci, NAME, dur - t, extra)
