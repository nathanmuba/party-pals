class_name MiniGame
extends RefCounted
## Base class for every mini-game. Each game sets NAME / MODES / HOW constants and a static desc(mode).
## The host calls update(dt, inputs) every frame, draw(canvas) to render, and bot(id) for CPU players.
## When finished, set done = true and result to one of:
##   {"kind": "rank", "order": [ids best → worst], "bonus": [coins per player] (optional)}
##   {"kind": "team", "winners": [ids]}   (empty = draw)
##   {"kind": "coop", "collected": n, "goal": n, "per": [per-player], "unit": "..."}

var st := {}        # {"mode": "ffa"|"2v2"|"1v3"|"coop", "team": [..], "solo": id}
var t := 0.0
var done := false
var result := {}

func init(setup: Dictionary) -> void:
	st = setup

func update(_dt: float, _inp: Array) -> void:
	pass

func bot(_id: int) -> Dictionary:
	return {}

func draw(_ci: CanvasItem) -> void:
	pass

# ---------- shared helpers ----------
func tag(id: int) -> String:
	return G.tag_of(id)

func ring(id: int):
	return Art.TEAMC[st.team[id]] if st.mode == "2v2" else null

func over_for(alive: Array) -> bool:
	if st.mode == "2v2":
		var teams := {}
		for i in alive:
			teams[st.team[i]] = true
		return teams.size() <= 1
	return alive.size() <= 1

func standing_result(alive: Array, elim: Array) -> Dictionary:
	var order: Array = alive.duplicate()
	var rev: Array = elim.duplicate()
	rev.reverse()
	order.append_array(rev)
	if st.mode == "ffa":
		return {"kind": "rank", "order": order}
	var c := [0, 0]
	for i in alive:
		c[st.team[i]] += 1
	var w := -1 if c[0] == c[1] else (0 if c[0] > c[1] else 1)
	if w < 0 and alive.is_empty() and not elim.is_empty():
		w = st.team[elim[elim.size() - 1]]
	return {"kind": "team", "winners": [] if w < 0 else [0, 1, 2, 3].filter(func(i): return st.team[i] == w)}

func score_result(sc: Array, higher := true) -> Dictionary:
	if st.mode == "2v2":
		var s := [0.0, 0.0]
		for i in 4:
			s[st.team[i]] += sc[i]
		if absf(s[0] - s[1]) < 0.000001:
			return {"kind": "team", "winners": []}
		var w := 0 if ((s[0] > s[1]) == higher) else 1
		return {"kind": "team", "winners": [0, 1, 2, 3].filter(func(i): return st.team[i] == w)}
	var ids := [0, 1, 2, 3]
	ids.sort_custom(func(a, b): return sc[a] > sc[b] if higher else sc[a] < sc[b])
	return {"kind": "rank", "order": ids}

## Top-down movement with optional dash (Action). p is a Dictionary with x,y,vx,vy,fx,fy,cd,dash,stun.
func dash_ctl(p: Dictionary, i: Dictionary, dt: float, sp := 620.0) -> void:
	p.cd -= dt
	p.dash -= dt
	p.stun -= dt
	if i.x != 0.0 or i.y != 0.0:
		p.fx = i.x
		p.fy = i.y
	if p.stun <= 0 and i.pressed and p.cd <= 0:
		var d := Vector2(p.fx, p.fy).normalized()
		if d == Vector2.ZERO:
			d = Vector2.DOWN
		p.vx = d.x * sp
		p.vy = d.y * sp
		p.dash = 0.22
		p.cd = 1.1
		G.beep(260, .05)

func top_move(p: Dictionary, i: Dictionary, sp: float, dt: float) -> void:
	if p.dash > 0:
		return
	var kk := minf(1.0, dt * 10.0)
	p.vx += (i.x * sp - p.vx) * kk
	p.vy += (i.y * sp - p.vy) * kk

func push_apart(ps: Array, rad: float, shove := false) -> void:
	for a in ps.size():
		for b in range(a + 1, ps.size()):
			var A: Dictionary = ps[a]
			var B: Dictionary = ps[b]
			if A.get("out", false) or B.get("out", false):
				continue
			var d := Vector2(B.x - A.x, B.y - A.y)
			var l := d.length()
			if l >= rad or l == 0.0:
				continue
			var n := d / l
			var ov := (rad - l) / 2.0
			A.x -= n.x * ov
			A.y -= n.y * ov
			B.x += n.x * ov
			B.y += n.y * ov
			if shove:
				if A.dash > 0 and B.stun <= 0:
					_shoved(B, n)
				if B.dash > 0 and A.stun <= 0:
					_shoved(A, -n)

func _shoved(p: Dictionary, n: Vector2) -> void:
	p.vx = n.x * 480
	p.vy = n.y * 480
	p.stun = 0.4
	G.burst(Vector2(p.x, p.y - 20), Color("#fff6a0"), 8, 200)
	G.beep(150, .08, "triangle")
	G.kick(4)

static func new_pal(i: int, x: float, y: float) -> Dictionary:
	return {"id": i, "x": x, "y": y, "vx": 0.0, "vy": 0.0, "fx": 0.0, "fy": 1.0, "cd": 0.0, "dash": 0.0, "stun": 0.0, "out": false, "ot": 0.0}

# ---------- more helpers used by most games ----------
var _prev_dir := [-1, -1, -1, -1]

static func dir_of(i: Dictionary) -> int:
	if absf(i.x) > .6 or absf(i.y) > .6:
		if absf(i.x) > absf(i.y):
			return 1 if i.x > 0 else 2
		return 0 if i.y > 0 else 3
	return -1

## Returns a direction only on the frame it is first pushed (0 down, 1 right, 2 left, 3 up), else -1.
func dir_edge(i: Dictionary, id: int) -> int:
	var d := dir_of(i)
	var e := d if (d >= 0 and d != _prev_dir[id]) else -1
	_prev_dir[id] = d
	return e

const DIR_V := [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]
const OPP := [3, 2, 1, 0]

func step_top(p: Dictionary, i: Dictionary, dt: float, sp := 290.0, b := Rect2(50, 130, 1180, 560), dash_on := true) -> void:
	if dash_on:
		dash_ctl(p, i, dt)
	else:
		p.stun -= dt
		p.cd -= dt
		if i.x != 0.0 or i.y != 0.0:
			p.fx = i.x
			p.fy = i.y
	if p.stun <= 0:
		top_move(p, i, sp, dt)
	else:
		p.vx *= pow(.05, dt)
		p.vy *= pow(.05, dt)
	p.x = clampf(p.x + p.vx * dt, b.position.x, b.end.x)
	p.y = clampf(p.y + p.vy * dt, b.position.y, b.end.y)

func pal_top(ci: CanvasItem, p: Dictionary, extra := {}) -> void:
	var o := {"fx": p.fx, "fy": p.fy, "move": Vector2(p.vx, p.vy).length() > 40, "dizzy": p.stun > 0,
		"squash": .85 if p.dash > 0 else 1.0, "tag": tag(p.id), "ring": ring(p.id)}
	o.merge(extra, true)
	Art.pal(ci, p.x, p.y, extra.get("r", 24.0), p.id, o)

func seek(p: Dictionary, x: float, y: float, s := 10.0) -> Dictionary:
	var d := Vector2(x - p.x, y - p.y)
	if d.length() < s:
		return {"x": 0.0, "y": 0.0}
	d = d.normalized()
	return {"x": d.x, "y": d.y}

func foe(a: Dictionary, b: Dictionary) -> bool:
	return a.id != b.id and (st.mode != "2v2" or st.team[a.id] != st.team[b.id])

func shove_bot(p: Dictionary, ps: Array, rad := 100.0, chance := .05) -> bool:
	if p.cd > 0:
		return false
	for q in ps:
		if foe(p, q) and not q.out and Vector2(q.x - p.x, q.y - p.y).length() < rad and randf() < chance:
			p.fx = q.x - p.x
			p.fy = q.y - p.y
			return true
	return false

func corners() -> Array:
	return [new_pal(0, 220, 260), new_pal(1, 1060, 260), new_pal(2, 220, 580), new_pal(3, 1060, 580)]

static func by_y(ps: Array) -> Array:
	var a := ps.duplicate()
	a.sort_custom(func(p, q): return p.y < q.y)
	return a

static func alive_ids(ps: Array) -> Array:
	return ps.filter(func(p): return not p.out).map(func(p): return p.id)

static func gauss() -> float:
	var s := 0.0
	for _k in 6:
		s += randf()
	return (s - 3.0) * 1.41

static func wrap_a(a: float) -> float:
	return fposmod(a + PI, TAU) - PI

func sum(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s
