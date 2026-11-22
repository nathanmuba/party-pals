extends MiniGame

const NAME := "Juggle Jam"
const MODES := ["coop"]
const HOW := "Left / right to move · Action: jump · Touch a ball to bump it up"
const FL := 640.0

static func desc(_m: String) -> String:
	return "Keep the beach balls in the air! Jump and bump them back up, and do not let any touch the sand. More balls join every few seconds. The team has 3 lives. Last 40 seconds together!"

var dur := 40.0
var per := [0, 0, 0, 0]
var P: Array = []
var balls: Array = []
var lives := 3

func init(s: Dictionary) -> void:
	super.init(s)
	for i in 4:
		P.append({"id": i, "x": 220.0 + i * 280, "y": FL, "vx": 0.0, "vy": 0.0, "fx": 0.0, "gnd": true, "claim": null})
	_add_ball()

func _add_ball() -> void:
	balls.append({"x": randf_range(200, 1080), "y": 140.0, "vx": randf_range(-80, 80), "vy": 0.0, "r": 30.0, "cd": 0.0, "rot": 0.0, "hue": randi() % 4})

func update(dt: float, inp: Array) -> void:
	t += dt
	if balls.size() < mini(4, 1 + int(t / 9)):
		_add_ball()
	for p in P:
		var i: Dictionary = inp[p.id]
		p.vx += (i.x * 360 - p.vx) * minf(1.0, dt * 12)
		if i.x != 0.0:
			p.fx = i.x
		if i.pressed and p.gnd:
			p.vy = -780.0
			p.gnd = false
			G.beep(500, .04, "triangle", .02)
		p.vy += 2000 * dt
		p.x = clampf(p.x + p.vx * dt, 30, 1250)
		p.y += p.vy * dt
		if p.y >= FL:
			p.y = FL
			p.vy = 0.0
			p.gnd = true
	for b in balls.duplicate():
		b.cd -= dt
		b.vy += 360 * dt
		b.x += b.vx * dt
		b.y += b.vy * dt
		b.rot += b.vx * dt / 30
		if b.x < b.r or b.x > 1280 - b.r:
			b.vx *= -1
			b.x = clampf(b.x, b.r, 1280 - b.r)
		if b.y < 100:
			b.y = 100.0
			b.vy = absf(b.vy) * .5
		for p in P:
			if b.cd > 0:
				break
			var h := Vector2(p.x, p.y - 26)
			if Vector2(b.x, b.y).distance_to(h) < b.r + 26:
				b.vy = -randf_range(540, 620)
				b.vx = clampf(b.vx * .4 + (b.x - h.x) * 5 + p.vx * .25, -260, 260)
				b.cd = .18
				per[p.id] += 1
				G.beep(600 + b.hue * 80, .05, "sine", .03)
				G.burst(Vector2(b.x, b.y + b.r), [Color.WHITE, Color("#ffe066")], 6, 140)
		if b.y + b.r >= FL + 20:
			lives -= 1
			G.burst(Vector2(b.x, FL), [Color("#f5d79a"), Color("#e0b06a")], 16, 220)
			G.beep(150, .3, "sawtooth", .05)
			G.kick(5)
			balls.erase(b)
			_add_ball()
	if lives <= 0 or t >= dur:
		result = {"kind": "coop", "collected": int(minf(t, dur)), "goal": int(dur), "per": per, "unit": "seconds"}
		done = true

func _land_x(b: Dictionary) -> Array:
	var a := 180.0
	var c: float = (FL - 80) - b.y
	var tt: float = (-b.vy + sqrt(maxf(0.0, b.vy * b.vy + 4 * a * c))) / (2 * a)
	var x: float = b.x + b.vx * tt
	if x < 0: x = -x
	if x > 1280: x = 2560 - x
	return [tt, x]

func bot(id: int) -> Dictionary:
	var p: Dictionary = P[id]
	var urg := []
	for b in balls:
		var lx := _land_x(b)
		urg.append({"b": b, "t": lx[0], "x": lx[1]})
	urg.sort_custom(func(a, b): return a.t < b.t)
	var mine = null
	for u in urg:
		var closer := false
		for q in P:
			if q.id != id and absf(q.x - u.x) < absf(p.x - u.x) - 40:
				closer = true
		if not closer:
			mine = u
			break
	if mine == null:
		return {"x": clampf((180 + id * 307 - p.x) / 60.0, -1, 1)}
	var dx: float = mine.x - p.x
	var b: Dictionary = mine.b
	return {"x": clampf(dx / 40, -1, 1) if absf(dx) > 14 else 0.0, "press": p.gnd and b.vy > -50 and b.y > p.y - 260 and b.y < p.y - 60 and absf(b.x - p.x) < 70 and randf() < .35}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#7fd0ff"), Color("#bfeaff"))
	ci.draw_circle(Vector2(1120, 170), 50, Color("#ffd23c"))
	ci.draw_rect(Rect2(0, FL - 30, 1280, 30), Color("#3aa0d8"))
	ci.draw_rect(Rect2(0, FL + 20, 1280, 720 - FL), Color("#f5d79a"))
	ci.draw_rect(Rect2(0, FL + 20, 1280, 8), Color("#e8c780"))
	var cs := [Color("#ff5a4e"), Color.WHITE, Color("#4e8dff"), Color.WHITE, Color("#ffd23c"), Color.WHITE]
	for b in balls:
		var sh := clampf((FL - b.y) / 500, 0, 1)
		Art.ellipse(ci, Vector2(b.x, FL + 28), b.r * (1 - sh * .5), 8, Color(0, 0, 0, .25 - .18 * sh))
		for kk in 6:
			var pts := [Vector2(b.x, b.y)]
			pts.append_array(Art.ell_points(Vector2(b.x, b.y), b.r, b.r, 0.0, 6, b.rot + kk * PI / 3, b.rot + (kk + 1) * PI / 3, false))
			Art.poly(ci, pts, cs[(kk + b.hue) % 6])
		Art.ellipse_line(ci, Vector2(b.x, b.y), b.r, b.r, Art.OUT, 3)
	for p in P:
		Art.pal(ci, p.x, p.y - 24, 24, p.id, {"fx": p.fx, "fy": -1, "move": p.gnd and absf(p.vx) > 40, "tag": tag(p.id) + " · %d" % per[p.id], "mood": "" if p.gnd else "happy"})
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "Lives " + "♥".repeat(maxi(0, lives)))
