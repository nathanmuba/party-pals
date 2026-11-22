extends MiniGame

const NAME := "Memory Bridge"
const MODES := ["ffa"]
const HOW := "Left / right: hop onto the left or right tile of the next row"

static func desc(_m: String) -> String:
	return "Each row of the glass bridge has one safe tile. The safe tiles light up for a few seconds at the start, so memorise them! Then hop left or right row by row. Pick wrong and you fall back to the start. First across wins!"

const N := 10
var safe: Array = []
var order: Array = []
var P: Array = []
var dur := 90.0
var memo := 4.0

func lx(i: int) -> float:
	return 165.0 + i * 317

func ry(r: int) -> float:
	return 612.0 - r * 46

func init(s: Dictionary) -> void:
	super.init(s)
	for _r in N:
		safe.append(randi() % 2)
	for i in 4:
		P.append({"row": -1, "side": 0, "fall": 0.0, "cd": 0.0, "best": -1, "broken": {}, "fin": false, "mem": safe.map(func(v): return v if randf() < .8 else 1 - v), "bt": randf_range(.3, .7)})

func update(dt: float, inp: Array) -> void:
	t += dt
	if t < memo:
		return
	for i in 4:
		var p: Dictionary = P[i]
		if p.fin:
			continue
		p.cd -= dt
		if p.fall > 0:
			p.fall -= dt
			if p.fall <= 0:
				p.row = -1
			continue
		var e := dir_edge(inp[i], i)
		if (e == 1 or e == 2) and p.cd <= 0:
			var side := 0 if e == 2 else 1
			var r: int = p.row + 1
			p.cd = .15
			p.side = side
			if safe[r] == side:
				p.row = r
				p.best = maxi(p.best, r)
				G.beep(500 + r * 40, .05, "triangle")
				if r == N - 1:
					p.fin = true
					order.append(i)
					G.beep(880, .1)
					G.beep(1175, .2)
					G.burst(Vector2(lx(i), ry(r) - 40), Art.COLORS, 26, 300)
					if order.size() == 1:
						dur = minf(dur, t + 12)
			else:
				p.broken[r * 2 + side] = true
				p.row = r
				p.fall = 1.2
				p.mem[r] = 1 - side
				G.beep(200, .3, "sawtooth")
				G.burst(Vector2(lx(i) + (52 if side else -52), ry(r)), [Color("#bff3ff"), Color.WHITE, Color("#7fd6ff")], 18, 260)
				G.kick(5)
	if P.all(func(p): return p.fin) or t >= dur:
		var rest := [0, 1, 2, 3].filter(func(i): return not P[i].fin)
		rest.sort_custom(func(a, b): return P[a].best > P[b].best)
		result = {"kind": "rank", "order": order + rest}
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = P[id]
	if t < memo or p.fin or p.fall > 0:
		return {}
	p.bt -= 1.0 / 60.0
	if p.bt > 0:
		return {}
	p.bt = randf_range(.3, .75)
	return {"x": -1.0 if p.mem[p.row + 1] == 0 else 1.0}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#1a1240"), Color("#06030f"))
	for i in 50:
		ci.draw_rect(Rect2(fmod(i * 211.0, 1280), fmod(i * 137.0, 720), 2, 2), Color(1, 1, 1, .5))
	var memo_on := t < memo
	for i in 4:
		var p: Dictionary = P[i]
		var x := lx(i)
		Art.rrect(ci, Rect2(x - 110, ry(-1) - 22, 220, 60), 14, Color("#5a4a7a"))
		Art.rrect(ci, Rect2(x - 110, ry(N) - 30, 220, 50), 14, Color("#5a4a7a"))
		Art.text(ci, "GOAL", Vector2(x, ry(N) - 6), 20, Color("#ffe066"))
		ci.draw_line(Vector2(x - 104, ry(-1)), Vector2(x - 104, ry(N)), Color(.7, .63, 1, .35), 4)
		ci.draw_line(Vector2(x + 104, ry(-1)), Vector2(x + 104, ry(N)), Color(.7, .63, 1, .35), 4)
		for r in N:
			for sd in 2:
				if p.broken.has(r * 2 + sd):
					continue
				var tx := x + (52.0 if sd else -52.0)
				var ty := ry(r)
				var lit: bool = memo_on and safe[r] == sd and sin(t * 6) > -0.6
				var pas: bool = p.row >= r and safe[r] == sd and not (p.fall > 0 and p.row == r)
				var col := Color(.49, 1, .6, .85) if lit else (Color(.49, 1, .6, .35) if pas else Color(.67, .9, 1, .28))
				Art.rrect(ci, Rect2(tx - 42, ty - 16, 84, 32), 8, col, 2, Color(.86, .96, 1, .8))
				ci.draw_rect(Rect2(tx - 34, ty - 11, 30, 4), Color(1, 1, 1, .35))
		var py := ry(p.row)
		var px := x if p.row < 0 else x + (52.0 if p.side else -52.0)
		var al := 1.0
		var sc := 1.0
		if p.fall > 0:
			var kk: float = 1.0 - p.fall / 1.2
			py += kk * kk * 260
			al = 1.0 - kk
			sc = 1.0 - kk * .5
		if p.fin:
			py = ry(N) - 10
			px = x
		Art.pal(ci, px, py - 20, 20 * sc, i, {"alpha": al, "dizzy": p.fall > 0, "cheer": p.fin, "tag": tag(i) if al > .5 else "", "fy": -1})
	if memo_on:
		Art.rrect(ci, Rect2(380, 78, 520, 46), 20, Color(.06, .03, .13, .75))
		Art.text(ci, "MEMORISE THE SAFE TILES!  %d" % int(ceil(memo - t)), Vector2(640, 101), 26, Color("#7dff9a"))
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, ("%d across" % order.size()) if order.size() else "Hop carefully…")
