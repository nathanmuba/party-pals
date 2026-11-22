extends MiniGame

const NAME := "Snake Trails"
const MODES := ["ffa", "2v2"]
const HOW := "Directions: turn (you cannot reverse)"

static func desc(m: String) -> String:
	return "You leave a solid trail wherever you go, and you can never stop moving! Steer clear of the walls and every trail. It gets faster as it goes. " + ("Last team still moving wins." if m == "2v2" else "Last pal still moving wins!")

const C := 40
const R := 22
const S := 28.0
var ox := (1280 - C * S) / 2.0
var oy := 98.0
var occ: Array = []
var elim: Array = []
var step_t := .6
var P: Array = []

func init(s: Dictionary) -> void:
	super.init(s)
	occ.resize(C * R)
	occ.fill(-1)
	var starts := [[6, 5, 1], [33, 5, 2], [6, 16, 1], [33, 16, 2]]
	for i in 4:
		var sp: Array = starts[i]
		P.append({"id": i, "c": sp[0], "r": sp[1], "d": sp[2], "nd": sp[2], "out": false, "ot": 0.0, "trail": [Vector2i(sp[0], sp[1])]})
		occ[sp[1] * C + sp[0]] = i

func cell_free(c: int, r: int) -> bool:
	return c >= 0 and c < C and r >= 0 and r < R and occ[r * C + c] < 0

func space(c: int, r: int) -> int:
	if not cell_free(c, r):
		return 0
	var seen := {r * C + c: true}
	var q := [Vector2i(c, r)]
	var n := 0
	while q.size() > 0 and n < 260:
		var a: Vector2i = q.pop_front()
		n += 1
		for dv in DIR_V:
			var x := a.x + int(dv.x)
			var y := a.y + int(dv.y)
			var k := y * C + x
			if cell_free(x, y) and not seen.has(k):
				seen[k] = true
				q.append(Vector2i(x, y))
	return n

func _bot_turn(p: Dictionary) -> int:
	var best: int = p.d
	var bs := -1.0
	for d in 4:
		if d == OPP[p.d]:
			continue
		var nc: int = p.c + int(DIR_V[d].x)
		var nr: int = p.r + int(DIR_V[d].y)
		var s := space(nc, nr) + (3.0 if d == p.d else 0.0) + randf() * 4
		for q in P:
			if q.id != p.id and not q.out and absi(q.c - nc) + absi(q.r - nr) <= 1:
				s -= 30
		if s > bs:
			bs = s
			best = d
	return best

func update(dt: float, inp: Array) -> void:
	t += dt
	for p in P:
		if p.out:
			p.ot += dt
			continue
		if G.players[p.id].dev != "":
			var d := dir_of(inp[p.id])
			if d >= 0 and d != OPP[p.d]:
				p.nd = d
	step_t -= dt
	if step_t > 0:
		return
	step_t = maxf(.06, .13 - t * .0018)
	var moves := []
	for p in P:
		if p.out:
			continue
		if G.players[p.id].dev == "":
			p.nd = _bot_turn(p)
		p.d = p.nd
		moves.append([p, p.c + int(DIR_V[p.d].x), p.r + int(DIR_V[p.d].y)])
	var dead := {}
	for m in moves:
		if not cell_free(m[1], m[2]):
			dead[m[0].id] = true
		for m2 in moves:
			if m2[0].id != m[0].id and m2[1] == m[1] and m2[2] == m[2]:
				dead[m[0].id] = true
	for m in moves:
		var p: Dictionary = m[0]
		if dead.has(p.id):
			p.out = true
			elim.append(p.id)
			G.beep(200, .3, "sawtooth", .05)
			G.burst(Vector2(ox + (p.c + .5) * S, oy + (p.r + .5) * S), [Art.COLORS[p.id], Color.WHITE], 18, 260)
			G.kick(5)
			continue
		p.c = m[1]
		p.r = m[2]
		occ[p.r * C + p.c] = p.id
		p.trail.append(Vector2i(p.c, p.r))
	var al := alive_ids(P)
	if over_for(al):
		result = standing_result(al, elim)
		done = true

func draw(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color("#120a26"))
	ci.draw_rect(Rect2(ox, oy, C * S, R * S), Color("#1d1433"))
	for c in C + 1:
		ci.draw_line(Vector2(ox + c * S, oy), Vector2(ox + c * S, oy + R * S), Color(1, 1, 1, .05), 1)
	for r in R + 1:
		ci.draw_line(Vector2(ox, oy + r * S), Vector2(ox + C * S, oy + r * S), Color(1, 1, 1, .05), 1)
	ci.draw_rect(Rect2(ox, oy, C * S, R * S), Color("#ff5ab4"), false, 4)
	for p in P:
		var col: Color = Art.COLORS[p.id].darkened(.5 if p.out else .15)
		for cell in p.trail:
			Art.rrect(ci, Rect2(ox + cell.x * S + 3, oy + cell.y * S + 3, S - 6, S - 6), 6, col)
	for p in P:
		if p.out and p.ot > 1:
			continue
		Art.pal(ci, ox + (p.c + .5) * S, oy + (p.r + .5) * S - 4, 15, p.id, {"fx": DIR_V[p.d].x, "fy": DIR_V[p.d].y, "dizzy": p.out, "ring": ring(p.id), "tag": "" if p.out else tag(p.id)})
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, "%d moving" % alive_ids(P).size())
