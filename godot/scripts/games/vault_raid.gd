extends MiniGame

const NAME := "Vault Raid"
const MODES := ["1v3"]
const HOW := "Trio: touch the vault, then run to the bank · Guard: tag carriers · Action: dash"
const V := Vector2(640, 220)
const VR := 80.0

static func desc(_m: String) -> String:
	return "The trio grabs coins from the vault and runs them to the bank at the bottom. The solo pal is the guard: touch a carrier to knock their coin loose! The trio needs 13 coins within 40 seconds."

var solo := 0
var dur := 40.0
var goal := 13
var bank := 0
var ps: Array = []
var trio: Array = []
var gd: Dictionary

func init(s: Dictionary) -> void:
	super.init(s)
	solo = st.solo
	ps = corners()
	for p in ps:
		p.c = false
	gd = ps[solo]
	gd.x = 640.0
	gd.y = 430.0
	trio = ps.filter(func(p): return p.id != solo)
	for k in trio.size():
		trio[k].x = 300.0 + k * 340
		trio[k].y = 640.0

func update(dt: float, inp: Array) -> void:
	t += dt
	for p in ps:
		step_top(p, inp[p.id], dt, 315.0 if p.id == solo else (250.0 if p.c else 285.0))
	var gv := Vector2(gd.x, gd.y) - V
	if gv.length() < VR + 40:
		gv = gv.normalized() * (VR + 40)
		gd.x = V.x + gv.x
		gd.y = V.y + gv.y
	for p in trio:
		if not p.c and Vector2(p.x, p.y).distance_to(V) < VR + 20:
			p.c = true
			G.beep(900, .05, "sine", .02)
		if p.c and p.y > 610:
			p.c = false
			bank += 1
			G.beep(1200, .08, "sine")
			G.burst(Vector2(p.x, p.y), [Color("#ffd23c"), Color("#fff3a0")], 14, 220)
		var dv := Vector2(p.x - gd.x, p.y - gd.y)
		if dv.length() < 58 and p.stun <= 0:
			if p.c:
				p.c = false
				G.burst(Vector2(p.x, p.y - 30), Color("#ffd23c"), 10, 240)
				G.beep(160, .12, "sawtooth", .04)
			p.stun = .8
			var n := dv.normalized()
			p.vx = n.x * 420
			p.vy = n.y * 420
			G.kick(3)
	push_apart(trio, 46)
	if bank >= goal:
		result = {"kind": "team", "winners": trio.map(func(p): return p.id)}
		done = true
	elif t >= dur:
		result = {"kind": "team", "winners": [solo]}
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.stun > 0:
		return {}
	if id == solo:
		var tg = null
		var bd := 1e9
		for q in trio:
			var d: float = Vector2(q.x - p.x, q.y - p.y).length() - (250.0 if q.c else 0.0) + (600.0 if q.stun > 0 else 0.0)
			if d < bd:
				bd = d
				tg = q
		if tg == null:
			return {}
		if not tg.c and bd > -100:
			var ax := 0.0
			for q in trio:
				ax += q.x
			return seek(p, ax / 3, 450, 20)
		var m := seek(p, tg.x + tg.vx * .3, tg.y + tg.vy * .3)
		m.press = Vector2(tg.x - p.x, tg.y - p.y).length() < 170 and p.cd <= 0 and randf() < .1
		return m
	var tx: float = clampf(p.x, 260, 1020) if p.c else V.x + (id - 1.5) * 30
	var ty: float = 660.0 if p.c else V.y
	var m := seek(p, tx, ty)
	var dv := Vector2(p.x - gd.x, p.y - gd.y)
	var d := maxf(1.0, dv.length())
	if d < 220:
		m.x += dv.x / d * 1.3
		m.y += dv.y / d * .5
	if not p.has("wob") or randf() < .02:
		p.wob = randf_range(-.5, .5)
	m.x += p.wob
	m.press = d < 140 and p.cd <= 0 and randf() < .06
	return m

func draw(ci: CanvasItem) -> void:
	Art.checker(ci, Color("#e8e4f4"), Color("#ddd6ee"))
	ci.draw_rect(Rect2(260, 610, 760, 100), Color(1, .82, .24, .35))
	for kk in 25:
		var x := 260 + kk * 32
		ci.draw_line(Vector2(x, 610), Vector2(x + 16, 610), Color("#b07800"), 4)
	Art.text(ci, "BANK", Vector2(640, 690), 26, Color("#8a5a00"))
	ci.draw_circle(V, VR, Color("#5a5a6a"))
	Art.ellipse_line(ci, V, VR, VR, Art.OUT, 5)
	for kk in 14:
		var c := V + Vector2(-40 + (kk % 5) * 20, -14 + int(kk / 5) * 14)
		Art.ellipse(ci, c, 12, 7, Color("#ffd23c"))
		Art.ellipse_line(ci, c, 12, 7, Art.OUT, 2)
	Art.text(ci, "VAULT", V + Vector2(0, -VR - 18), 20, Color("#2a1650"), 0, false)
	for p in by_y(ps):
		pal_top(ci, p, {"r": 28.0 if p.id == solo else 24.0, "crown": p.id == solo, "ring": null if p.id == solo else Art.TEAMC[1], "mood": "ouch" if p.stun > 0 else ""})
		if p.c:
			ci.draw_circle(Vector2(p.x, p.y - 60), 13, Color("#ffd23c"))
			Art.ellipse_line(ci, Vector2(p.x, p.y - 60), 13, 13, Art.OUT, 3)
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "Banked %d / %d" % [bank, goal])
