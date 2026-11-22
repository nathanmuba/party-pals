extends MiniGame

const NAME := "Freeze Tag"
const MODES := ["1v3"]
const HOW := "Move · Action: dash · Trio: touch a frozen friend to thaw them"

static func desc(_m: String) -> String:
	return "The solo pal is IT! Tagged pals freeze solid. Teammates can thaw them with a touch, and the ice melts by itself after 5 seconds. The solo pal must have all three frozen at once. The trio must last 35 seconds."

var solo := 0
var dur := 35.0
var ps: Array = []
var trio: Array = []
var it: Dictionary

func init(s: Dictionary) -> void:
	super.init(s)
	solo = st.solo
	ps = corners()
	for p in ps:
		p.fr = false
		p.rcd = 0.0
		p.imm = 0.0
		p.ft = 0.0
	it = ps[solo]
	it.x = 640.0
	it.y = 410.0
	trio = ps.filter(func(p): return p.id != solo)

func update(dt: float, inp: Array) -> void:
	t += dt
	for p in ps:
		p.rcd -= dt
		p.imm -= dt
		if p.fr:
			p.vx = 0.0
			p.vy = 0.0
			p.ft += dt
			if p.ft > 5:
				p.fr = false
				p.ft = 0.0
				p.imm = 1.2
				G.burst(Vector2(p.x, p.y), [Color("#bfe7ff"), Color.WHITE], 12, 180)
				G.beep(700, .1, "sine", .03)
			continue
		p.ft = 0.0
		var pc: float = p.cd
		step_top(p, inp[p.id], dt, 280.0 if p.id == solo else 315.0)
		if p.id == solo and p.cd > pc:
			p.cd = 1.8
	for p in trio:
		if p.fr or p.imm > 0:
			continue
		if Vector2(p.x - it.x, p.y - it.y).length() < 50:
			p.fr = true
			it.stun = .7
			G.beep(1200, .15, "sine")
			G.burst(Vector2(p.x, p.y), [Color("#bfe7ff"), Color.WHITE], 16, 220)
			G.kick(4)
	for p in trio:
		if p.fr or p.rcd > 0:
			continue
		for q in trio:
			if q.fr and Vector2(p.x - q.x, p.y - q.y).length() < 48:
				q.fr = false
				q.imm = 1.2
				p.rcd = 2.5
				G.beep(600, .12, "triangle")
				G.burst(Vector2(q.x, q.y), [Color("#ffe066"), Color.WHITE], 14, 200)
				break
	push_apart(ps.filter(func(p): return not p.fr), 46)
	if trio.all(func(p): return p.fr):
		result = {"kind": "team", "winners": [solo]}
		done = true
	elif t >= dur:
		result = {"kind": "team", "winners": trio.map(func(p): return p.id)}
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.fr or p.stun > 0:
		return {}
	if id == solo:
		var best = null
		var bd := 1e9
		for q in trio:
			if q.fr:
				continue
			var d: float = Vector2(q.x - p.x, q.y - p.y).length() + (300.0 if q.imm > 0 else 0.0)
			if d < bd:
				bd = d
				best = q
		if best == null:
			return {}
		var m := seek(p, best.x + best.vx * .35, best.y + best.vy * .35)
		m.press = bd < 170 and p.cd <= 0 and randf() < .1
		return m
	var dv := Vector2(p.x - it.x, p.y - it.y)
	var d := maxf(1.0, dv.length())
	if p.rcd <= 0:
		for q in trio:
			if q.fr and Vector2(q.x - it.x, q.y - it.y).length() > 260 and d > 220:
				return seek(p, q.x, q.y)
	var v := dv / d
	if p.x < 170: v.x += 1.4
	if p.x > 1110: v.x -= 1.4
	if p.y < 230: v.y += 1.4
	if p.y > 600: v.y -= 1.4
	if not p.has("wob") or randf() < .02:
		p.wob = randf_range(-1, 1)
	v += Vector2(-v.y, v.x) * p.wob * .5
	return {"x": v.x, "y": v.y, "press": d < 110 and p.cd <= 0 and randf() < .12}

func draw(ci: CanvasItem) -> void:
	Art.checker(ci, Color("#d8f0ff"), Color("#c8e6fb"))
	for p in by_y(ps):
		pal_top(ci, p, {"r": 28.0 if p.id == solo else 24.0, "crown": p.id == solo, "ring": null if p.id == solo else Art.TEAMC[1], "dizzy": false, "mood": "ouch" if p.fr else "", "alpha": .5 if (p.imm > 0 and sin(t * 30) > 0) else 1.0})
		if p.fr:
			Art.rrect(ci, Rect2(p.x - 32, p.y - 38, 64, 66), 12, Color(.67, .88, 1, .6), 3, Color.WHITE)
			ci.draw_rect(Rect2(p.x - 24, p.y - 32, 10, 30), Color(1, 1, 1, .6))
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "%d / 3 frozen" % trio.filter(func(p): return p.fr).size())
