extends MiniGame

const NAME := "Tile Panic"
const MODES := ["ffa", "2v2"]
const HOW := "Move · Action: hop (hopping does not crack tiles, and crosses holes)"
const ROWC := [Color("#ff8fab"), Color("#ffa07a"), Color("#ffb86b"), Color("#ffe36b"), Color("#9be36b"), Color("#6be3c9"), Color("#6bb5ff"), Color("#b18cff")]

static func desc(m: String) -> String:
	return "Each tile wobbles and then falls away a moment after someone steps on it. Keep moving and plan your path!" + (" Last team with a pal on the board wins." if m == "2v2" else " Last pal on the board wins.")

const C := 16
const R := 8
const S := 68.0
var ox := (1280 - C * S) / 2.0
var oy := 132.0
var tiles: Array = []
var ps: Array = []
var elim: Array = []
var dur := 240.0

func init(s: Dictionary) -> void:
	super.init(s)
	for _k in C * R:
		tiles.append({"s": 0, "t": 0.0})
	for cr in [[3, 2], [12, 2], [3, 5], [12, 5]]:
		var p := new_pal(ps.size(), ox + (cr[0] + .5) * S, oy + (cr[1] + .5) * S)
		p.hop = 0.0
		p.coy = 0.0
		p.tgt = null
		p.tt = 0.0
		ps.append(p)

func cell(x: float, y: float):
	var c := int(floor((x - ox) / S))
	var r := int(floor((y - oy) / S))
	if c >= 0 and c < C and r >= 0 and r < R:
		return {"c": c, "r": r, "t": tiles[r * C + c]}
	return null

func intact(c: int, r: int) -> bool:
	return c >= 0 and c < C and r >= 0 and r < R and tiles[r * C + c].s == 0

func update(dt: float, inp: Array) -> void:
	t += dt
	for tl in tiles:
		if tl.s == 1:
			tl.t += dt
			if tl.t > 2:
				tl.s = 2
				tl.t = 0.0
				G.beep(200 + randi() % 80, .05, "sine", .015)
		elif tl.s == 2:
			tl.t += dt
	for p in ps:
		if p.out:
			p.ot += dt
			continue
		var i: Dictionary = inp[p.id]
		p.cd -= dt
		p.hop -= dt
		if i.x != 0.0 or i.y != 0.0:
			p.fx = i.x
			p.fy = i.y
		var kk := minf(1.0, dt * 10)
		p.vx += (i.x * 220 - p.vx) * kk
		p.vy += (i.y * 220 - p.vy) * kk
		if i.pressed and p.cd <= 0 and p.hop <= 0:
			p.hop = .55
			p.cd = .75
			G.beep(520, .06, "triangle")
		p.x += p.vx * dt
		p.y += p.vy * dt
		if p.hop <= 0:
			var c = cell(p.x, p.y)
			if c == null or c.t.s == 2:
				p.coy += dt
			else:
				p.coy = 0.0
				if c.t.s == 0:
					c.t.s = 1
					c.t.t = 0.0
			if p.coy > .12:
				p.out = true
				elim.append(p.id)
				G.beep(260, .3, "sine")
				G.burst(Vector2(p.x, p.y), Art.COLORS[p.id], 12, 160)
	push_apart(ps, 42)
	var al := alive_ids(ps)
	if over_for(al) or t >= dur:
		al.shuffle()
		result = standing_result(al, elim)
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.out:
		return {}
	var here = cell(p.x, p.y)
	if here == null:
		return {}
	p.tt -= 1.0 / 60.0
	var tc = null if p.tgt == null else tiles[p.tgt.r * C + p.tgt.c]
	if p.tt <= 0 or tc == null or tc.s != 0 or (p.tgt.c == here.c and p.tgt.r == here.r):
		var best = null
		var bs := -1e9
		for rad in [1, 2]:
			if best != null:
				break
			for dr in range(-rad, rad + 1):
				for dc in range(-rad, rad + 1):
					if maxi(absi(dc), absi(dr)) != rad:
						continue
					var c: int = here.c + dc
					var r: int = here.r + dr
					if not intact(c, r):
						continue
					if rad == 1 and dc != 0 and dr != 0 and not intact(here.c + dc, here.r) and not intact(here.c, here.r + dr):
						continue
					var sc := randf() * .6 - Vector2(c - C / 2.0 + .5, (r - R / 2.0 + .5) * 1.5).length() * .35
					for a in range(-2, 3):
						for b in range(-2, 3):
							if intact(c + a, r + b):
								sc += .6 if (absi(a) <= 1 and absi(b) <= 1) else .2
					for q in ps:
						if q.id != id and not q.out and Vector2(q.x - (ox + (c + .5) * S), q.y - (oy + (r + .5) * S)).length() < S * 1.2:
							sc -= 2
					if sc > bs:
						bs = sc
						best = {"c": c, "r": r, "hop": rad == 2}
		p.tgt = best
		p.tt = randf_range(.25, .45)
	if p.tgt == null:
		return {"x": (640 - p.x) / 300.0, "y": (oy + R * S / 2 - p.y) / 300.0, "press": p.cd <= 0 and p.hop <= 0}
	var tx: float = ox + (p.tgt.c + .5) * S
	var ty: float = oy + (p.tgt.r + .5) * S
	var dv := Vector2(tx - p.x, ty - p.y)
	var d := maxf(1.0, dv.length())
	var ah = cell(p.x + dv.x / d * 30, p.y + dv.y / d * 30)
	var press: bool = p.cd <= 0 and p.hop <= 0 and ((p.tgt.hop and d < 88 and (ah == null or ah.t.s == 2)) or ah == null or (ah.t.s != 0 and not (ah.c == here.c and ah.r == here.r)) or (here.t.s == 1 and here.t.t > 1.6))
	return {"x": dv.x / d, "y": dv.y / d, "press": press}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#2a1650"), Color("#0d0820"))
	for i in 60:
		ci.draw_rect(Rect2(fmod(i * 211.0, 1280), fmod(i * 137.0, 720), 2, 2), Color(1, 1, 1, .3 + .7 * absf(sin(t * 2 + i))))
	for r in R:
		for c in C:
			var tl: Dictionary = tiles[r * C + c]
			var x := ox + c * S
			var y := oy + r * S
			var col: Color = ROWC[r]
			if tl.s == 2:
				if tl.t < .6:
					var kk: float = tl.t / .6
					var sz := (S - 8) * (1 - kk * .5)
					var cc := col
					cc.a = 1 - kk
					Art.rrect(ci, Rect2(x + S / 2 - sz / 2, y + S / 2 - sz / 2 + kk * kk * 140, sz, sz), 10, cc)
				continue
			var sh: float = sin(t * 60 + c + r) * 2.5 * (tl.t / 2.0) if tl.s == 1 else 0.0
			var top := Color("#ff6b6b") if (tl.s == 1 and tl.t > 1.4) else (col.darkened(.1) if tl.s == 1 else col)
			Art.rrect(ci, Rect2(x + 4 + sh, y + 8, S - 8, S - 8), 10, col.darkened(.45))
			Art.rrect(ci, Rect2(x + 4 + sh, y + 2, S - 8, S - 10), 10, top)
			Art.rrect(ci, Rect2(x + 10 + sh, y + 7, S - 20, 10), 5, Color(1, 1, 1, .3))
			if tl.s == 1:
				var cc := Color(.16, .04, .12, .55)
				ci.draw_polyline(PackedVector2Array([Vector2(x + S * .3 + sh, y + S * .2), Vector2(x + S * .5 + sh, y + S * .5), Vector2(x + S * .35 + sh, y + S * .8)]), cc, 2.5)
				ci.draw_line(Vector2(x + S * .5 + sh, y + S * .5), Vector2(x + S * .75 + sh, y + S * .4), cc, 2.5)
	for p in by_y(ps):
		if p.out:
			if p.ot < .6:
				var s: float = 1.0 - p.ot / .6
				Art.pal(ci, p.x, p.y - 18 + p.ot * 60, 22 * s, p.id, {"alpha": s, "dizzy": true})
			continue
		var hb := sin((1 - p.hop / .55) * PI) * 30 if p.hop > 0 else 0.0
		Art.pal(ci, p.x, p.y - 18, 22, p.id, {"fx": p.fx, "fy": p.fy, "bob": hb, "tag": tag(p.id), "ring": ring(p.id), "move": p.hop <= 0 and Vector2(p.vx, p.vy).length() > 40, "mood": "happy" if p.hop > 0 else ""})
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, "%d tiles left · %d standing" % [tiles.filter(func(tl): return tl.s != 2).size(), alive_ids(ps).size()])
