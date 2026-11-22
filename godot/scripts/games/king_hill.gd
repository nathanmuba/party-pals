extends MiniGame

const NAME := "King of the Hill"
const MODES := ["ffa", "2v2"]
const HOW := "Move · Action: shove · The dotted ring shows where the zone goes next"

static func desc(m: String) -> String:
	return "Stand in the glowing zone to score, but ONLY when " + ("your team is the only one" if m == "2v2" else "you are the only one") + " inside! The zone jumps somewhere new every few seconds. Shove rivals out!"

var ps: Array = []
var sc := [0.0, 0.0, 0.0, 0.0]
var dur := 35.0
var Z := {"x": 640.0, "y": 420.0, "r": 110.0, "nx": 0.0, "ny": 0.0, "t": 6.0}
var cont := false

func init(s: Dictionary) -> void:
	super.init(s)
	ps = corners()
	_pick()

func _pick() -> void:
	Z.nx = randf_range(180, 1100)
	Z.ny = randf_range(220, 620)

func update(dt: float, inp: Array) -> void:
	t += dt
	Z.t -= dt
	if Z.t <= 0:
		Z.x = Z.nx
		Z.y = Z.ny
		Z.t = randf_range(4.5, 6.5)
		_pick()
		G.beep(600, .08)
		G.burst(Vector2(Z.x, Z.y), Color("#fff6a0"), 16, 240)
	for p in ps:
		step_top(p, inp[p.id], dt, 290)
	push_apart(ps, 48, true)
	var inside := ps.filter(func(p): return Vector2(p.x - Z.x, p.y - Z.y).length() < Z.r)
	cont = false
	if inside.size() > 0:
		var tm := {}
		for p in inside:
			tm[st.team[p.id] if st.mode == "2v2" else p.id] = true
		if tm.size() == 1:
			for p in inside:
				sc[p.id] += dt
		else:
			cont = true
	if t >= dur:
		result = score_result(sc)
		done = true

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.stun > 0:
		return {}
	var nxt: bool = Z.t < 1.2
	var m := seek(p, (Z.nx if nxt else Z.x) + (30 if id % 2 else -30), (Z.ny if nxt else Z.y) + (-25 if id < 2 else 25), 14)
	if Vector2(p.x - Z.x, p.y - Z.y).length() < Z.r + 60:
		m.press = shove_bot(p, ps, 95, .06)
	return m

func draw(ci: CanvasItem) -> void:
	Art.checker(ci, Color("#ffe8a8"), Color("#ffdd90"))
	if Z.t < 2.5:
		for kk in 24:
			var a0 := kk * TAU / 24
			ci.draw_arc(Vector2(Z.nx, Z.ny), Z.r, a0, a0 + TAU / 48, 4, Color("#ff6b3c") if sin(t * 20) > 0 else Color(1, .42, .24, .4), 5)
	var zc := Color(1, .35, .35) if cont else Color(1, .86, .35)
	for kk in 5:
		ci.draw_circle(Vector2(Z.x, Z.y), Z.r * (1 - kk * .18), Color(zc, .22 + kk * .1))
	Art.ellipse_line(ci, Vector2(Z.x, Z.y), Z.r, Z.r, Color("#ff3b3b") if cont else Color("#ffb000"), 5)
	for p in by_y(ps):
		pal_top(ci, p, {"tag": tag(p.id) + " · %.1f" % sc[p.id]})
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "CONTESTED!" if cont else "")
