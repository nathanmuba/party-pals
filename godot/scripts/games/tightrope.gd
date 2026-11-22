extends MiniGame

const NAME := "Tightrope"
const MODES := ["ffa"]
const HOW := "Hold Up to walk · Left / right: lean to balance (watch the wind!)"
const L := 470.0
const BASE := 650.0

static func desc(_m: String) -> String:
	return "Walk the tightrope across the canyon while gusts of wind try to tip you off. Lean against the wind to stay balanced. Fall and you restart from the last flag. First across wins!"

var dur := 70.0
var order: Array = []
var hist: Array = []
var w := 0.0
var w_t := 0.0
var wt := 1.5
var P: Array = []

func lx(i: int) -> float:
	return 160.0 + i * 320

func init(s: Dictionary) -> void:
	super.init(s)
	for _i in 4:
		P.append({"s": 0.0, "th": 0.0, "fall": 0.0, "cp": 0.0, "fin": false, "noise": 0.0, "nt": 0.0})

func update(dt: float, inp: Array) -> void:
	t += dt
	wt -= dt
	if wt <= 0:
		wt = randf_range(1, 2.6)
		w_t = randf_range(-1, 1) * minf(1.2, .6 + t * .015)
	w += clampf(w_t - w, -1.4 * dt, 1.4 * dt)
	hist.append(w)
	if hist.size() > 30:
		hist.pop_front()
	for i in 4:
		var p: Dictionary = P[i]
		var ip: Dictionary = inp[i]
		if p.fin:
			continue
		if p.fall > 0:
			p.fall -= dt
			if p.fall <= 0:
				p.s = p.cp
				p.th = 0.0
			continue
		if ip.y < -.3:
			p.s += 40 * dt * maxf(.2, 1 - absf(p.th) * 1.3)
			p.th += randf_range(-1, 1) * 1.1 * dt
		p.th += (w * .85 + sin(p.th) * 1.5 + ip.x * 2.1) * dt
		if absf(p.th) > 1:
			p.fall = 1.4
			G.beep(220, .35, "sine")
			G.burst(Vector2(lx(i) + signf(p.th) * 30, BASE - p.s), [Art.COLORS[i], Color.WHITE], 14, 220)
			G.kick(3)
		if p.s >= L / 2 and p.cp < L / 2:
			p.cp = L / 2
			G.beep(880, .08)
		if p.s >= L:
			p.fin = true
			order.append(i)
			G.beep(880, .1)
			G.beep(1320, .2)
			G.burst(Vector2(lx(i), BASE - L), Art.COLORS, 24, 300)
	if order.size() == 4 or t >= dur:
		var rest := [0, 1, 2, 3].filter(func(i): return not P[i].fin)
		rest.sort_custom(func(a, b): return P[a].s > P[b].s)
		result = {"kind": "rank", "order": order + rest}
		done = true

func bot(i: int) -> Dictionary:
	var p: Dictionary = P[i]
	if p.fin or p.fall > 0:
		return {}
	p.nt -= 1.0 / 60.0
	if p.nt <= 0:
		p.noise = randf_range(-.3, .3)
		p.nt = randf_range(.3, .7)
	var wd: float = hist[maxi(0, hist.size() - 16)] if hist.size() > 0 else 0.0
	var u := clampf(-(wd * .85 + sin(p.th) * 1.5) / 2.1 - p.th * 1.8 + p.noise, -1, 1)
	return {"x": u, "y": -1.0 if absf(p.th) < .32 else 0.0}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#ffb86b"), Color("#ff7ab6"))
	var hills := [Vector2(0, 720)]
	for x in range(0, 1281, 80):
		hills.append(Vector2(x, 690 - absf(sin(x * .01)) * 40))
	hills.append(Vector2(1280, 720))
	Art.poly(ci, hills, Color("#8a4a5a"))
	for kk in 10:
		var y := 140.0 + kk * 55
		var off := fposmod(t * w * 300 + kk * 137, 1280)
		ci.draw_line(Vector2(off, y), Vector2(off + signf(w if w != 0 else 1.0) * 60 * minf(1.0, absf(w) + .2), y), Color(1, 1, 1, .5), 3)
	for i in 4:
		var x := lx(i)
		var p: Dictionary = P[i]
		ci.draw_line(Vector2(x, BASE + 10), Vector2(x, BASE - L - 10), Color("#5a3a2a"), 3)
		ci.draw_rect(Rect2(x - 40, BASE + 8, 80, 14), Color("#7a4a20"))
		ci.draw_rect(Rect2(x - 40, BASE - L - 24, 80, 14), Color("#7a4a20"))
		ci.draw_rect(Rect2(x, BASE - L / 2 - 32, 4, 32), Color("#5a3a2a"))
		Art.poly(ci, [Vector2(x + 4, BASE - L / 2 - 30), Vector2(x + 30, BASE - L / 2 - 22), Vector2(x + 4, BASE - L / 2 - 14)], Color("#7dff9a") if p.cp > 0 else Color.WHITE)
		var y: float = BASE - p.s
		var al := 1.0
		var dx := 0.0
		if p.fall > 0:
			var kk: float = 1.0 - p.fall / 1.4
			y += kk * kk * 300
			al = 1.0 - kk
			dx = signf(p.th) * 40 * kk
		ci.draw_set_transform(Vector2(x + dx, y), p.th)
		ci.draw_line(Vector2(-60, -10), Vector2(60, -10), Color(.35, .23, .16, al), 4)
		Art.pal(ci, 0, -28, 22, i, {"alpha": al, "dizzy": p.fall > 0, "mood": "ouch" if absf(p.th) > .6 else "", "cheer": p.fin, "fx": -p.th})
		ci.draw_set_transform(Vector2.ZERO)
		Art.text(ci, (tag(i) + " #%d" % (order.find(i) + 1)) if p.fin else tag(i), Vector2(x, BASE + 46), 18, Art.COLORS[i])
	Art.text(ci, "WIND " + ("◀◀" if w < -.15 else ("▶▶" if w > .15 else "—")), Vector2(640, 96), 22, Color("#ff3b5c") if absf(w) > .7 else Color.WHITE)
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "%d across" % order.size())
