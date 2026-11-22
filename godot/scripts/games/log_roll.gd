extends MiniGame

const NAME := "Log Roll"
const MODES := ["ffa", "2v2"]
const HOW := "Left / right: run against the spin · Action: jump over knots"

static func desc(m: String) -> String:
	return "Stay on top of your spinning log! It keeps changing direction and spins faster and faster. Run against the spin and jump over the knots." + (" Last team with a pal standing wins!" if m == "2v2" else " Last pal standing wins!")

const R := 92.0
const CY := 430.0
var om := 0.0
var om_t := 1.0
var sw_t := 2.2
var rot := 0.0
var warn := 0.0
var knots: Array = []
var hist: Array = []
var P: Array = []
var elim: Array = []
var dur := 60.0

func cx(i: int) -> float:
	return 176.0 + i * 309

func init(s: Dictionary) -> void:
	super.init(s)
	om_t = 1.0 if randf() < .5 else -1.0
	knots = [randf_range(2, 4)]
	for i in 4:
		P.append({"id": i, "th": randf_range(-.05, .05), "air": 0.0, "cd": 0.0, "stun": 0.0, "out": false, "fall": 0.0, "noise": 0.0, "nt": 0.0, "run": 0.0})

func update(dt: float, inp: Array) -> void:
	t += dt
	sw_t -= dt
	if sw_t <= 0:
		var mag := minf(2.4, 1 + t * .035) * randf_range(.75, 1)
		om_t = (-signf(om_t) if randf() < .7 else signf(om_t)) * mag
		sw_t = randf_range(1.4, 3.2)
		warn = .6
		G.beep(330, .08, "square", .03)
	warn -= dt
	om += clampf(om_t - om, -3 * dt, 3 * dt)
	rot += om * dt
	hist.append(om)
	if hist.size() > 40:
		hist.pop_front()
	if t > 18 and knots.size() < 2:
		knots.append(knots[0] + PI)
	for kk in knots.size():
		knots[kk] += om * dt
	for p in P:
		if p.out:
			p.fall += dt
			continue
		var i: Dictionary = inp[p.id]
		p.cd -= dt
		p.air -= dt
		p.stun -= dt
		if i.pressed and p.cd <= 0 and p.air <= 0:
			p.air = .5
			p.cd = .6
			G.beep(520, .05, "triangle")
		var u: float = 0.0 if p.stun > 0 else i.x
		p.run = u
		if p.air > 0:
			p.th += u * 1.2 * dt
		else:
			p.th += (om + u * 2.6 + sin(p.th) * 1.4) * dt
			for kn in knots:
				if absf(wrap_a(kn - p.th)) < .13 and p.stun <= 0:
					p.stun = .35
					p.th += signf(om if om != 0 else 1.0) * .3
					G.burst(Vector2(cx(p.id) + sin(p.th) * R, CY - cos(p.th) * R), [Color("#8a5a32"), Color("#fff6a0")], 10, 180)
					G.beep(150, .1, "triangle")
					G.kick(4)
		if absf(p.th) > .95:
			p.out = true
			elim.append(p.id)
			G.beep(260, .35, "sine")
			G.burst(Vector2(cx(p.id) + sin(p.th) * 150, 560), [Color("#bfe7ff"), Color.WHITE, Color("#6fb7ff")], 18, 280)
	var al := alive_ids(P)
	if over_for(al) or t >= dur:
		al.sort_custom(func(a, b): return absf(P[a].th) < absf(P[b].th))
		result = standing_result(al, elim)
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = P[id]
	if p.out:
		return {}
	p.nt -= 1.0 / 60.0
	if p.nt <= 0:
		p.noise = randf_range(-.35, .35) * (1 + t / 30)
		p.nt = randf_range(.3, .8)
	var seen: float = hist[hist.size() - 15 - randi() % 5] if hist.size() > 20 else 0.0
	var u := clampf(-(seen + sin(p.th) * 1.4) / 2.6 - p.th * 2 + p.noise, -1, 1)
	var press := false
	for kn in knots:
		var d := wrap_a(kn - p.th)
		if d * om < 0 and absf(d) / maxf(.3, absf(om)) < .22 and randf() < .35:
			press = true
	return {"x": u, "press": press}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#a8e6ff"), Color("#5fb8e8"))
	for i in 10:
		var x := i * 150.0 - 20
		Art.poly(ci, [Vector2(x, 330), Vector2(x + 60, 190 + (i % 3) * 30), Vector2(x + 120, 330)], Color("#5aa86a"))
	ci.draw_rect(Rect2(0, 325, 1280, 30), Color("#4a8f5a"))
	ci.draw_rect(Rect2(0, 480, 1280, 240), Color("#2f86c8"))
	for kk in 5:
		var pts := PackedVector2Array()
		for x in range(0, 1281, 20):
			pts.append(Vector2(x, 505 + kk * 45 + sin(x / 50.0 + t * 3 + kk) * 6))
		ci.draw_polyline(pts, Color(1, 1, 1, .3), 3)
	for i in 4:
		var x := cx(i)
		var p: Dictionary = P[i]
		Art.ellipse(ci, Vector2(x, CY + R - 6), R + 30, 14, Color(1, 1, 1, .4))
		ci.draw_circle(Vector2(x, CY), R, Color("#b07a46"))
		ci.draw_circle(Vector2(x - 12, CY - 12), R * .8, Color("#c8925a"))
		ci.draw_circle(Vector2(x - 24, CY - 24), R * .45, Color("#e0b07a"))
		Art.ellipse_line(ci, Vector2(x, CY), R, R, Art.OUT, 5)
		Art.ellipse_line(ci, Vector2(x, CY), R - 5, R - 5, Color("#8a5a32"), 7)
		for rr2 in [60.0, 38.0, 18.0]:
			Art.ellipse_line(ci, Vector2(x, CY), rr2, rr2, Color(.47, .27, .12, .45), 2.5)
		for kk in 3:
			var an := rot + kk * 2.1
			ci.draw_line(Vector2(x, CY) + Vector2(8, 0).rotated(an), Vector2(x, CY) + Vector2(R - 14, 6).rotated(an), Color(.35, .2, .08, .6), 3)
		for kn in knots:
			var kp := Vector2(x + sin(kn) * R, CY - cos(kn) * R)
			ci.draw_circle(kp, 13, Color("#6a3a1a"))
			Art.ellipse_line(ci, kp, 13, 13, Art.OUT, 3)
			ci.draw_circle(kp, 5, Color("#a06a3a"))
		var aw := absf(om) / 2.4
		var dirv := signf(om)
		var ay := CY - R - 115
		if aw > .05:
			var w := aw * 30
			Art.poly(ci, [Vector2(x - dirv * (20 + w), ay - 7), Vector2(x + dirv * (10 + w), ay - 7), Vector2(x + dirv * (10 + w), ay - 16), Vector2(x + dirv * (32 + w), ay), Vector2(x + dirv * (10 + w), ay + 16), Vector2(x + dirv * (10 + w), ay + 7), Vector2(x - dirv * (20 + w), ay + 7)], Color("#ff6b6b") if warn > 0 else Color(1, 1, 1, .85), 3)
		if p.out:
			if p.fall < 1:
				var fx: float = x + sin(p.th) * (R + 40) + signf(p.th) * p.fall * 60
				var fy: float = CY - cos(p.th) * R + p.fall * p.fall * 300
				if fy < 540:
					Art.pal(ci, fx, fy, 24, i, {"dizzy": true})
			else:
				Art.pal(ci, x + signf(p.th) * 150, 560 + sin(t * 3) * 4, 20, i, {"dizzy": true, "alpha": .8})
			continue
		var lift := sin((1 - p.air / .5) * PI) * 55 if p.air > 0 else 0.0
		var rad := R + 24 + lift
		ci.draw_set_transform(Vector2(x + sin(p.th) * rad, CY - cos(p.th) * rad), p.th * .8)
		Art.pal(ci, 0, 0, 24, i, {"fx": p.run, "move": p.air <= 0 and absf(om) > .3, "dizzy": p.stun > 0, "mood": "ouch" if absf(p.th) > .6 else "", "ring": ring(i)})
		ci.draw_set_transform(Vector2.ZERO)
		Art.text(ci, tag(i), Vector2(x, CY + R + 48), 18, Art.COLORS[i])
		var bal: float = 1.0 - absf(p.th) / .95
		Art.rrect(ci, Rect2(x - 60, CY + R + 64, 120, 12), 6, Color(.06, .03, .13, .5))
		Art.rrect(ci, Rect2(x - 60, CY + R + 64, maxf(6.0, 120 * bal), 12), 6, Color("#7dff9a") if bal > .5 else (Color("#ffe066") if bal > .25 else Color("#ff6b6b")))
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "%d standing" % alive_ids(P).size())
