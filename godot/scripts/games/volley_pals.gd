extends MiniGame

const NAME := "Volley Pals"
const MODES := ["2v2"]
const HOW := "Left / right to move · Action: jump · Touch the ball to bump it"
const FL := 640.0
const NX := 640.0
const NT := 450.0

static func desc(_m: String) -> String:
	return "Beach volleyball, 2 vs 2! Bump the ball over the net and do not let it land on your side. First team to 5 points wins, or whoever leads when time runs out."

var dur := 75.0
var score := [0, 0]
var pause := 1.2
var serve_to := 0
var rally := 0
var P: Array = []
var ball := {"x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "r": 26.0, "rot": 0.0}

func init(s: Dictionary) -> void:
	super.init(s)
	serve_to = randi() % 2
	for i in 4:
		var tm: int = st.team[i]
		var mates := [0, 1, 2, 3].filter(func(j): return st.team[j] == tm)
		var k := mates.find(i)
		P.append({"id": i, "tm": tm, "x": (200.0 + k * 240) if tm == 0 else (840.0 + k * 240), "y": FL, "vx": 0.0, "vy": 0.0, "fx": 1.0 if tm == 0 else -1.0, "gnd": true, "cd": 0.0, "pred": 640.0, "pt": 0.0, "ne": 0.0, "k": k})
	_serve()

func _serve() -> void:
	ball.x = 300.0 if serve_to == 0 else 980.0
	ball.y = 220.0
	ball.vx = 0.0
	ball.vy = -100.0

func _sim_land() -> float:
	var x: float = ball.x
	var y: float = ball.y
	var vx: float = ball.vx
	var vy: float = ball.vy
	for _k in 180:
		vy += 820 / 60.0
		x += vx / 60.0
		y += vy / 60.0
		if x < 26 or x > 1254:
			vx *= -1
		if absf(x - NX) < 32 and y > NT - 26:
			vx *= -1
		if y > FL - 70 and vy > 0:
			return x
	return x

func update(dt: float, inp: Array) -> void:
	t += dt
	for p in P:
		var i: Dictionary = inp[p.id]
		p.cd -= dt
		p.vx += (i.x * 360 - p.vx) * minf(1.0, dt * 12)
		if i.x != 0.0:
			p.fx = i.x
		if i.pressed and p.gnd:
			p.vy = -780.0
			p.gnd = false
			G.beep(480, .04, "triangle", .02)
		p.vy += 2000 * dt
		p.x += p.vx * dt
		p.y += p.vy * dt
		if p.y >= FL:
			p.y = FL
			p.vy = 0.0
			p.gnd = true
		p.x = clampf(p.x, 30, NX - 34) if p.tm == 0 else clampf(p.x, NX + 34, 1250)
	if pause > 0:
		pause -= dt
		return
	ball.vy += 820 * dt
	ball.x += ball.vx * dt
	ball.y += ball.vy * dt
	ball.rot += ball.vx * dt / 26
	if ball.x < ball.r or ball.x > 1280 - ball.r:
		ball.vx *= -1
		ball.x = clampf(ball.x, ball.r, 1280 - ball.r)
	if ball.y < 60:
		ball.y = 60.0
		ball.vy = absf(ball.vy)
	if absf(ball.x - NX) < 6 + ball.r and ball.y > NT - ball.r:
		if ball.y < NT:
			ball.vy = -absf(ball.vy) * .6
			ball.y = NT - ball.r
		else:
			ball.vx = -ball.vx * .7
			ball.x = NX + signf(ball.x - NX if ball.x != NX else 1.0) * (6 + ball.r)
	for p in P:
		if p.cd > 0:
			continue
		var h := Vector2(p.x, p.y - 30)
		var bv := Vector2(ball.x, ball.y) - h
		var d := bv.length()
		if d < ball.r + 30:
			var n := bv / d
			ball.x = h.x + n.x * (ball.r + 31)
			ball.y = h.y + n.y * (ball.r + 31)
			rally += 1
			var boost := 1 + minf(.6, rally * .05)
			ball.vx = clampf((n.x * 380 + p.vx * .35 + (170 if p.tm == 0 else -170)) * boost, -640, 640)
			ball.vy = minf(-460.0, n.y * 500 - 380)
			p.cd = .25
			G.beep(700, .05, "sine", .03)
			G.burst(Vector2(ball.x, ball.y), [Color.WHITE, Color("#ffe066")], 6, 140)
	if ball.y + ball.r >= FL + 18:
		rally = 0
		var side := 0 if ball.x < NX else 1
		var win := 1 - side
		score[win] += 1
		serve_to = side
		G.burst(Vector2(ball.x, FL), [Color("#f5d79a"), Color.WHITE], 20, 240)
		G.beep(880 if win == 0 else 660, .15)
		G.kick(4)
		pause = 1.3
		_serve()
		if score[win] >= 5:
			result = {"kind": "team", "winners": [0, 1, 2, 3].filter(func(i): return st.team[i] == win)}
			done = true
	if t >= dur and not done:
		var w := -1 if score[0] == score[1] else (0 if score[0] > score[1] else 1)
		result = {"kind": "team", "winners": [] if w < 0 else [0, 1, 2, 3].filter(func(i): return st.team[i] == w)}
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = P[id]
	p.pt -= 1.0 / 60.0
	if p.pt <= 0:
		p.pt = .1
		if randf() < .15:
			p.ne = gauss() * 30 * (1 + rally * .1)
		p.pred = _sim_land() + p.ne
	var lx: float = p.pred
	var mine: bool = lx < NX if p.tm == 0 else lx > NX
	var other: Dictionary = P.filter(func(q): return q.tm == p.tm and q.id != id)[0]
	var i_go: bool = mine and absf(p.x - lx) <= absf(other.x - lx) + 1
	var home: float = ([200.0, 450.0] if p.tm == 0 else [830.0, 1080.0])[p.k]
	var tx: float = lx + (-22 if p.tm == 0 else 22) if i_go else home
	var dx: float = tx - p.x
	var press: bool = i_go and p.gnd and ball.y < p.y - 60 and ball.y > p.y - 260 and absf(ball.x - p.x) < 70 and ball.vy > -120 and randf() < .4
	return {"x": clampf(dx / 40, -1, 1) if absf(dx) > 10 else 0.0, "press": press}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#6ec8ff"), Color("#d8f2ff"))
	ci.draw_rect(Rect2(0, 560, 1280, 60), Color("#3aa0d8"))
	ci.draw_rect(Rect2(0, FL + 20, 1280, 720 - FL), Color("#f5d79a"))
	ci.draw_rect(Rect2(0, FL + 20, 1280, 6), Color(1, 1, 1, .4))
	ci.draw_rect(Rect2(NX - 4, NT, 8, FL + 20 - NT), Color("#e8e8e8"))
	var y := NT + 6
	while y < FL:
		ci.draw_line(Vector2(NX - 10, y), Vector2(NX + 10, y), Color.WHITE, 2)
		y += 14
	ci.draw_rect(Rect2(NX - 12, NT - 6, 24, 10), Color("#ff5a4e"))
	var sh := clampf((FL - ball.y) / 500, 0, 1)
	Art.ellipse(ci, Vector2(ball.x, FL + 26), ball.r * (1 - sh * .4), 7, Color(0, 0, 0, .25 - .15 * sh))
	var bc := Vector2(ball.x, ball.y)
	ci.draw_circle(bc, ball.r, Color.WHITE)
	Art.ellipse_line(ci, bc, ball.r, ball.r, Art.OUT, 3)
	ci.draw_arc(bc, ball.r - 8, ball.rot, ball.rot + 2, 10, Color("#ffc93c"), 5)
	ci.draw_arc(bc, ball.r - 8, ball.rot + 2.1, ball.rot + 4.1, 10, Color("#4e8dff"), 5)
	for p in P:
		Art.pal(ci, p.x, p.y - 26, 26, p.id, {"fx": p.fx, "fy": -1, "move": p.gnd and absf(p.vx) > 40, "tag": tag(p.id), "ring": Art.TEAMC[p.tm], "mood": "" if p.gnd else "happy"})
	Art.text(ci, str(score[0]), Vector2(NX - 120, 150), 72, Art.TEAMC[0])
	Art.text(ci, str(score[1]), Vector2(NX + 120, 150), 72, Art.TEAMC[1])
	Art.text(ci, "first to 5", Vector2(NX, 150), 20, Color("#2a1650"), 0, false)
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "")
