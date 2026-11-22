extends MiniGame
## A bomb with a secret fuse. Touch someone to pass it on, no passing straight back. Last pal standing.

const NAME := "Hot Potato"
const MODES := ["ffa"]
const HOW := "Move to run · Action: dash · Touch a pal to pass the bomb"

static func desc(_m: String) -> String:
	return "One pal holds a bomb with a SECRET fuse. Touch a pal to pass it on, but you cannot pass it straight back. When it blows, whoever holds it is out. No time limit. Last pal standing wins!"

var ps: Array = []
var elim: Array = []
var holder := 0
var fuse := 10.0
var pause := 0.0
var from := -1
var from_t := 0.0
var pass_cd := 0.0
var tick := 0.0

func init(s: Dictionary) -> void:
	super.init(s)
	for xy in [[260, 260], [1020, 260], [260, 600], [1020, 600]]:
		ps.append(new_pal(ps.size(), xy[0], xy[1]))
	holder = randi() % 4
	fuse = randf_range(8, 14)

func _alive() -> Array:
	return ps.filter(func(p): return not p.out)

func update(dt: float, inp: Array) -> void:
	t += dt
	pass_cd -= dt
	if pause > 0:
		pause -= dt
		if pause <= 0:
			var al := _alive()
			holder = al[randi() % al.size()].id
			fuse = randf_range(5, 12)
			from = -1
			G.beep(600, .1)
	elif holder >= 0:
		fuse -= dt
		tick -= dt
		if tick <= 0:
			tick = randf_range(.25, .6)
			G.beep(900, .02, "square", .015)
		if fuse <= 0:
			var h: Dictionary = ps[holder]
			h.out = true
			elim.append(h.id)
			G.burst(Vector2(h.x, h.y - 30), [Color("#ff8c3c"), Color("#ffd23c"), Color("#333333"), Color.WHITE], 40, 420)
			G.beep(70, .5, "sawtooth", .08)
			G.kick(14)
			holder = -1
			pause = 1.8
			var ids := _alive().map(func(p): return p.id)
			if ids.size() <= 1:
				result = standing_result(ids, elim)
				done = true
	for p in ps:
		if p.out:
			continue
		var i: Dictionary = inp[p.id]
		dash_ctl(p, i, dt)
		if p.stun <= 0:
			top_move(p, i, 315.0 if p.id == holder else 290.0, dt)
		else:
			p.vx *= pow(.05, dt)
			p.vy *= pow(.05, dt)
		p.x = clampf(p.x + p.vx * dt, 50, 1230)
		p.y = clampf(p.y + p.vy * dt, 130, 690)
	if holder >= 0 and pass_cd <= 0:
		var h: Dictionary = ps[holder]
		for q in ps:
			if q.out or q == h or (q.id == from and t - from_t < 1.0):
				continue
			if Vector2(q.x - h.x, q.y - h.y).length() < 54:
				from = h.id
				from_t = t
				holder = q.id
				pass_cd = .3
				G.beep(700, .06)
				G.burst(Vector2(q.x, q.y - 40), [Color("#ffd23c"), Color("#ff8c3c")], 10, 200)
				break
	push_apart(ps, 48)

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.out:
		return {}
	var pos := Vector2(p.x, p.y)
	if p.stun > 0 or holder < 0:
		var c := (Vector2(640, 410) - pos) / 400.0
		return {"x": c.x, "y": c.y}
	if id == holder:
		var best = null
		var bd := 1e9
		for q in ps:
			if q.out or q == p or (q.id == from and t - from_t < 1.0):
				continue
			var d := pos.distance_to(Vector2(q.x, q.y))
			if d < bd:
				bd = d
				best = q
		if best == null:
			return {}
		var to: Vector2 = Vector2(best.x + best.vx * .2, best.y + best.vy * .2) - pos
		var n := to.normalized()
		return {"x": n.x, "y": n.y, "press": to.length() < 160 and p.cd <= 0 and randf() < .08}
	var h: Dictionary = ps[holder]
	var away := pos - Vector2(h.x, h.y)
	var d := away.length()
	var v := away.normalized()
	v += Vector2((640 - p.x) / 700.0, (410 - p.y) / 450.0)
	if p.x < 140: v.x += 1
	if p.x > 1140: v.x -= 1
	if p.y < 200: v.y += 1
	if p.y > 620: v.y -= 1
	if not p.has("wob") or randf() < .02:
		p.wob = randf_range(-1, 1)
	v += Vector2(-v.y, v.x) * p.wob * .6
	return {"x": v.x, "y": v.y, "press": d < 120 and p.cd <= 0 and randf() < .06}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#ffd2a8"), Color("#f08a6a"))
	var x := 0
	while x < 1280:
		var y := 110
		while y < 720:
			if ((x + y) / 80) % 2 == 0:
				ci.draw_rect(Rect2(x, y, 80, 80), Color(1, 1, 1, .15))
			y += 80
		x += 80
	var sorted := ps.duplicate()
	sorted.sort_custom(func(a, b): return a.y < b.y)
	for p in sorted:
		if p.out:
			Art.pal(ci, p.x, p.y, 24, -1, {"color": Color("#555555"), "alpha": .35, "dizzy": true})
			continue
		var is_h: bool = p.id == holder
		Art.pal(ci, p.x, p.y, 26, p.id, {"fx": p.fx, "fy": p.fy, "move": Vector2(p.vx, p.vy).length() > 40, "dizzy": p.stun > 0,
			"squash": .85 if p.dash > 0 else 1.0, "tag": tag(p.id), "mood": "ouch" if is_h else ""})
		if is_h:
			var b := Vector2(p.x + (sin(t * 50) * 2 if fuse < 2 else 0.0), p.y - 70 + sin(t * 10) * 3)
			ci.draw_circle(b, 20, Color("#1d1626"))
			Art.ellipse_line(ci, b, 20, 20, Art.OUT, 3)
			ci.draw_circle(b + Vector2(-6, -6), 6, Color(1, 1, 1, .3))
			ci.draw_polyline(PackedVector2Array([b + Vector2(0, -20), b + Vector2(10, -32), b + Vector2(16, -36)]), Color("#c99a5a"), 4)
			ci.draw_circle(b + Vector2(16, -37), 5 + randf() * 4, Color("#ffd23c") if randf() < .5 else Color("#ff6b3c"))
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, ("Bomb: %s · fuse: ???" % Art.NAMES[holder]) if holder >= 0 else "Boom!")
