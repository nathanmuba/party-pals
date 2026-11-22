extends MiniGame

const NAME := "Spotlight"
const MODES := ["ffa", "2v2"]
const HOW := "Move · Action: shove · Keep your meter out of the red!"

static func desc(m: String) -> String:
	return "The stage goes dark! Stay inside the moving spotlights to keep your glow meter up. Outside, it drains fast. Lights wander, shrink, blink and vanish. Shove rivals into the dark! " + ("Last team glowing wins." if m == "2v2" else "Last pal glowing wins.")

var ps: Array = []
var elim: Array = []
var spots: Array = []

func init(s: Dictionary) -> void:
	super.init(s)
	for xy in [[340, 300], [940, 300], [340, 560], [940, 560]]:
		var p := new_pal(ps.size(), xy[0], xy[1])
		p.m = 1.0
		ps.append(p)
	spots = [{"x": 400.0, "y": 420.0, "vx": 0.0, "vy": 0.0, "r": 150.0, "blink": 0.0, "ct": 0.0}, {"x": 880.0, "y": 420.0, "vx": 0.0, "vy": 0.0, "r": 150.0, "blink": 0.0, "ct": 0.0}]

func lit(p: Dictionary) -> bool:
	for s in spots:
		if s.blink <= 0 and Vector2(p.x - s.x, p.y - s.y).length() < s.r:
			return true
	return false

func update(dt: float, inp: Array) -> void:
	t += dt
	if t > 32 and spots.size() > 1:
		var s: Dictionary = spots.pop_back()
		G.burst(Vector2(s.x, s.y), Color("#fff6a0"), 20, 250)
		G.beep(200, .3, "sine")
	for s in spots:
		s.ct -= dt
		if s.ct <= 0:
			var an := randf() * TAU
			var sp := minf(260.0, 110 + t * 3)
			s.vx = cos(an) * sp
			s.vy = sin(an) * sp
			s.ct = randf_range(.8, 2.2)
		s.x += s.vx * dt
		s.y += s.vy * dt
		if s.x < s.r * .6 + 40 or s.x > 1280 - s.r * .6 - 40:
			s.vx *= -1
		if s.y < 170 or s.y > 650:
			s.vy *= -1
		s.x = clampf(s.x, 60, 1220)
		s.y = clampf(s.y, 160, 660)
		s.r = maxf(72.0 if spots.size() > 1 else 95.0, 150 - t * 1.6)
		s.blink -= dt
		if t > 6 and s.blink < -1 and randf() < dt * .18:
			s.blink = .55
			G.beep(140, .1, "square", .02)
	for p in ps:
		if p.out:
			p.ot += dt
			continue
		step_top(p, inp[p.id], dt, 280.0, Rect2(40, 130, 1200, 560))
		p.m = clampf(p.m + (.18 if lit(p) else -.36) * dt, 0, 1)
		if p.m <= 0:
			p.out = true
			elim.append(p.id)
			G.beep(220, .35, "sine")
			G.burst(Vector2(p.x, p.y), [Color("#555555"), Color("#888888")], 14, 160)
	push_apart(ps, 48, true)
	var al := alive_ids(ps)
	if over_for(al):
		al.sort_custom(func(a, b): return ps[a].m > ps[b].m)
		result = standing_result(al, elim)
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.out or p.stun > 0:
		return {}
	var best: Dictionary = spots[0]
	var bd := 1e9
	for s in spots:
		var d := Vector2(s.x + s.vx * .4 - p.x, s.y + s.vy * .4 - p.y).length() + (200.0 if s.blink > 0 else 0.0)
		if d < bd:
			bd = d
			best = s
	if not p.has("off") or randf() < .01:
		p.off = Vector2(randf_range(-.5, .5), randf_range(-.5, .5))
	var m := seek(p, best.x + best.vx * .4 + p.off.x * best.r, best.y + best.vy * .4 + p.off.y * best.r, 12)
	m.press = shove_bot(p, ps, 100, .03)
	return m

func draw(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color("#0b0716"))
	for x in range(0, 1280, 64):
		ci.draw_rect(Rect2(x, 110, 2, 610), Color("#1a1230"))
	for s in spots:
		if s.blink > 0:
			Art.ellipse_line(ci, Vector2(s.x, s.y), s.r, s.r, Color(1, .94, .67, .4), 3)
			continue
		for kk in 6:
			var f := 1.0 - kk / 6.0
			ci.draw_circle(Vector2(s.x, s.y), s.r * f, Color(1, .93, .62, .16 + .05 * kk))
		Art.ellipse_line(ci, Vector2(s.x, s.y), s.r, s.r, Color(1, .94, .67, .5), 2)
	for p in by_y(ps):
		if p.out:
			if p.ot < 1:
				Art.pal(ci, p.x, p.y, 24, -1, {"color": Color("#444444"), "alpha": 1 - p.ot, "dizzy": true})
			continue
		var l := lit(p)
		pal_top(ci, p, {"alpha": 1.0 if l else .55, "mood": "" if l else "ouch"})
		Art.rrect(ci, Rect2(p.x - 28, p.y + 30, 56, 9), 4, Color(0, 0, 0, .6))
		Art.rrect(ci, Rect2(p.x - 28, p.y + 30, maxf(4.0, 56 * p.m), 9), 4, Color("#7dff9a") if p.m > .5 else (Color("#ffe066") if p.m > .25 else Color("#ff6b6b")))
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, ("" if spots.size() > 1 else "One light left! · ") + "%d glowing" % alive_ids(ps).size())
