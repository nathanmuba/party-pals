extends MiniGame

const NAME := "Coin Shower"
const MODES := ["coop"]
const HOW := "Left / right to move · Run into a pal to shove them · Action: jump (land on a pal to bonk them)"

static func desc(_m: String) -> String:
	return "Coins are raining down! Catch as many as you can together and dodge the bombs. Reach the goal for bonus coins. Careful: pals can shove each other into the bombs!"

const FLOOR := 640.0
var goal := 100
var dur := 30.0
var P: Array = []
var drops: Array = []
var per := [0, 0, 0, 0]
var pops: Array = []
var ct := 0.0
var bt := 1.5

func init(s: Dictionary) -> void:
	super.init(s)
	for i in 4:
		P.append({"id": i, "x": 200.0 + i * 290, "y": FLOOR, "vx": 0.0, "vy": 0.0, "fx": 0.0, "stun": 0.0, "kb": 0.0, "glad": 0.0, "home": 180.0 + i * 307, "mv": false})

func update(dt: float, inp: Array) -> void:
	t += dt
	ct -= dt
	bt -= dt
	if ct <= 0:
		ct = randf_range(.14, .3)
		drops.append({"x": randf_range(40, 1240), "y": -20.0, "v": randf_range(200, 320), "bomb": false, "big": randf() < .08})
	if bt <= 0:
		bt = randf_range(.6, 1.1)
		drops.append({"x": randf_range(40, 1240), "y": -20.0, "v": randf_range(240, 340), "bomb": true, "big": false})
	for p in P:
		var i: Dictionary = inp[p.id]
		p.stun -= dt
		p.glad -= dt
		p.kb -= dt
		if p.stun <= 0 and p.kb <= 0:
			p.vx += (i.x * 400 - p.vx) * minf(1.0, dt * 12)
			if i.x != 0.0:
				p.fx = i.x
			if i.pressed and p.y >= FLOOR:
				p.vy = -640.0
				G.beep(500, .05, "triangle")
		else:
			p.vx *= pow(.25 if p.kb > 0 else .02, dt)
		p.x += p.vx * dt
		if p.x < 30 or p.x > 1250:
			p.x = clampf(p.x, 30, 1250)
			p.vx *= -.4
		p.mv = absf(p.vx) > 40 and p.kb <= 0 and p.stun <= 0
		p.vy += 1700 * dt
		p.y += p.vy * dt
		if p.y >= FLOOR:
			p.y = FLOOR
			p.vy = 0.0
	for a in 4:
		for b in range(a + 1, 4):
			var A: Dictionary = P[a]
			var B: Dictionary = P[b]
			if A.x > B.x:
				var tmp := A
				A = B
				B = tmp
			var dx: float = B.x - A.x
			var dy: float = B.y - A.y
			if absf(dy) > 30 and dx < 36:
				var top: Dictionary = B if dy < 0 else A
				var bot2: Dictionary = A if dy < 0 else B
				if top.vy > 0 and absf(top.y - (bot2.y - 48)) < 16:
					top.vy = -560.0
					if bot2.stun <= 0:
						bot2.stun = .7
						G.beep(700, .08, "square", .03)
						G.burst(Vector2(bot2.x, bot2.y - 50), [Color("#fff6a0"), Color.WHITE], 10, 180)
						G.kick(3)
				continue
			if dx >= 46 or absf(dy) > 30:
				continue
			var ov := (46 - dx) / 2
			A.x -= ov
			B.x += ov
			var rel: float = A.vx - B.vx
			if rel > 230:
				if A.vx > -B.vx:
					B.vx = maxf(B.vx, 0) + 560
					B.kb = .45
					A.vx *= .3
				else:
					A.vx = minf(A.vx, 0) - 560
					A.kb = .45
					B.vx *= .3
				G.beep(180, .07, "triangle")
				G.burst(Vector2((A.x + B.x) / 2, A.y - 26), [Color("#fff6a0"), Color.WHITE], 8, 200)
				G.kick(3)
	for d in drops.duplicate():
		d.y += d.v * dt
		var gone := false
		for p in P:
			if Vector2(d.x - p.x, d.y - (p.y - 26)).length() < (46 if d.big else 38):
				if d.bomb:
					if p.stun <= 0:
						p.stun = 1.3
						G.beep(90, .3, "sawtooth", .06)
						G.kick(6)
						G.burst(Vector2(d.x, d.y), [Color("#ff8c3c"), Color("#ffd23c"), Color("#333333")], 14, 260)
				else:
					per[p.id] += 5 if d.big else 1
					p.glad = .35
					G.beep(1200 if d.big else 880, .05, "sine")
					pops.append({"x": d.x, "y": d.y, "t": 0.0, "txt": "+5" if d.big else "+1"})
					G.burst(Vector2(d.x, d.y), [Color("#ffcf33"), Color("#fff3a0")], 6, 150)
				gone = true
				break
		if not gone and d.y > FLOOR + 30:
			gone = true
			if d.bomb:
				G.burst(Vector2(d.x, FLOOR + 20), [Color("#ff8c3c"), Color("#ffd23c")], 8, 180)
		if gone:
			drops.erase(d)
	for q in pops:
		q.t += dt
	pops = pops.filter(func(q): return q.t < .6)
	if t >= dur:
		result = {"kind": "coop", "collected": int(sum(per)), "goal": goal, "per": per.duplicate(), "unit": "coins"}
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = P[id]
	if p.stun > 0 or p.kb > 0:
		return {}
	var best = null
	var bs := 1e9
	for d in drops:
		if d.bomb:
			continue
		var tl: float = (p.y - d.y) / d.v
		if tl < 0:
			continue
		if absf(d.x - p.x) / 400.0 > tl + .05:
			continue
		var sc: float = tl + absf(d.x - p.home) / 600.0 - (1.0 if d.big else 0.0)
		if sc < bs:
			bs = sc
			best = d
	var x: float = clampf((best.x - p.x) / 25.0, -1, 1) if best != null else clampf((p.home - p.x) / 60.0, -1, 1)
	for d in drops:
		if d.bomb and d.y > 330 and d.y < p.y and absf(d.x - p.x) < 70:
			x = -1.0 if d.x > p.x else 1.0
	var press: bool = best != null and best.y < p.y - 90 and absf(best.x - p.x) < 30 and (p.y - best.y) / best.v < .25 and randf() < .2
	return {"x": x, "press": press}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#8edcff"), Color("#ffd6f0"))
	for i in 5:
		var x := fmod(i * 290.0 + t * 20, 1480) - 100
		var y := 180.0 + (i % 2) * 80
		for cc in [[0, 0, 40], [40, -10, 50], [85, 2, 36]]:
			ci.draw_circle(Vector2(x + cc[0], y + cc[1]), cc[2], Color(1, 1, 1, .8))
	for i in 6:
		Art.ellipse(ci, Vector2(i * 260 + 80, FLOOR + 40), 200, 90, Color("#a6e08a"))
	ci.draw_rect(Rect2(0, FLOOR + 24, 1280, 720 - FLOOR), Color("#5ab45a"))
	ci.draw_rect(Rect2(0, FLOOR + 24, 1280, 10), Color("#3e8f44"))
	for d in drops:
		if d.bomb:
			ci.draw_circle(Vector2(d.x, d.y), 17, Color("#231a30"))
			ci.draw_circle(Vector2(d.x - 5, d.y - 5), 5, Color(1, 1, 1, .3))
			ci.draw_rect(Rect2(d.x - 2, d.y - 26, 4, 10), Color("#ff6b3c"))
			ci.draw_circle(Vector2(d.x, d.y - 28), 4 + sin(t * 30) * 2, Color("#ffe066"))
		else:
			var r := 22.0 if d.big else 14.0
			var w := maxf(.25, absf(cos(t * 6 + d.x)))
			Art.ellipse(ci, Vector2(d.x, d.y), r * w, r, Color("#ffcf33"))
			Art.ellipse_line(ci, Vector2(d.x, d.y), r * w, r, Color("#b07800"), 3)
	for p in P:
		Art.pal(ci, p.x, p.y - 26, 26, p.id, {"fx": p.fx, "fy": -1, "dizzy": p.stun > 0, "move": p.mv and p.y >= FLOOR, "squash": .85 if p.kb > 0 else 1.0, "mood": "ouch" if p.kb > 0 else ("happy" if p.glad > 0 else ""), "tag": tag(p.id) + " · %d" % per[p.id]})
	for q in pops:
		Art.text(ci, q.txt, Vector2(q.x, q.y - q.t * 60), 22, Color("#fff6a0"))
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "Team: %d / %d" % [int(sum(per)), goal])
