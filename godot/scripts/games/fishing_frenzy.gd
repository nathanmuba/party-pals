extends MiniGame

const NAME := "Fishing Frenzy"
const MODES := ["ffa"]
const HOW := "Up / down: move the hook · Action: reel in (short cooldown)"

static func desc(_m: String) -> String:
	return "Everyone gets the same pond. Move your hook up and down and reel in when a fish swims right over it! Big fish are worth 3. Old boots cost you 2. Most points wins!"

const LW := 320.0
const HX := 160.0
var dur := 30.0
var sc := [0, 0, 0, 0]
var fish: Array = []
var caught: Array = [{}, {}, {}, {}]
var hk: Array = []
var ft := 0.0
var fid := 0

func init(s: Dictionary) -> void:
	super.init(s)
	for _i in 4:
		hk.append({"y": 400.0, "cd": 0.0, "reel": 0.0})

func fx(f: Dictionary) -> float:
	return -40 + f.v * (t - f.t0) if f.dir > 0 else LW + 40 - f.v * (t - f.t0)

func update(dt: float, inp: Array) -> void:
	t += dt
	ft -= dt
	if ft <= 0:
		ft = randf_range(.45, .9)
		var r := randf()
		var ty := 1 if r < .15 else (2 if r < .32 else 0)
		fish.append({"id": fid, "y": randf_range(220, 640), "dir": 1 if randf() < .5 else -1, "v": randf_range(230, 300) if ty == 1 else randf_range(110, 220), "ty": ty, "t0": t})
		fid += 1
	for i in 4:
		var h: Dictionary = hk[i]
		var ip: Dictionary = inp[i]
		h.cd -= dt
		h.reel -= dt
		h.y = clampf(h.y + ip.y * 300 * dt, 200, 660)
		if ip.pressed and h.cd <= 0:
			h.cd = .4
			h.reel = .3
			var got = null
			for f in fish:
				if caught[i].has(f.id):
					continue
				if absf(fx(f) - HX) < 34 and absf(f.y - h.y) < 26:
					got = f
					break
			if got != null:
				caught[i][got.id] = true
				var v := 3 if got.ty == 1 else (-2 if got.ty == 2 else 1)
				sc[i] += v
				G.beep(900 + v * 100 if v > 0 else 120, .08, "sine" if v > 0 else "sawtooth", .03)
				G.burst(Vector2(i * LW + HX, h.y), [Color("#7fd6ff"), Color.WHITE] if v > 0 else [Color("#8a5a32"), Color("#555555")], 12, 200)
			else:
				G.beep(250, .03, "triangle", .015)
	while fish.size() > 0 and t - fish[0].t0 > 8:
		fish.pop_front()
	if t >= dur:
		result = score_result(sc)
		done = true

func bot(i: int) -> Dictionary:
	var h: Dictionary = hk[i]
	var best = null
	var bt := 1e9
	for f in fish:
		if caught[i].has(f.id) or f.ty == 2:
			continue
		var tt: float = (HX - fx(f)) * f.dir / f.v
		if tt < -.05 or tt > 1.4:
			continue
		var s := tt - (.4 if f.ty == 1 else 0.0)
		if s < bt:
			bt = s
			best = f
	if best == null:
		return {}
	var dy: float = best.y - h.y
	var near: bool = absf(fx(best) - HX) < 26 and absf(dy) < 18
	var boot := false
	for f in fish:
		if f.ty == 2 and not caught[i].has(f.id) and absf(fx(f) - HX) < 36 and absf(f.y - h.y) < 28:
			boot = true
	return {"y": clampf(dy / 30, -1, 1) if absf(dy) > 6 else 0.0, "press": near and not boot and h.cd <= 0 and randf() < .4}

func draw(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color("#1d1433"))
	for i in 4:
		var L0 := i * LW
		ci.draw_set_transform(Vector2(L0, 0))
		ci.draw_rect(Rect2(0, 0, LW, 170), Color("#bfe9ff"))
		Art.vgrad(ci, Color("#5ab8f0"), Color("#1c5fa0"), Rect2(0, 170, LW, 550))
		var wv := PackedVector2Array()
		for x in range(0, int(LW) + 1, 16):
			wv.append(Vector2(x, 172 + sin(x / 30.0 + t * 3) * 4))
		ci.draw_polyline(wv, Color(1, 1, 1, .4), 3)
		ci.draw_rect(Rect2(90, 120, 140, 22), Color("#a0663a"))
		ci.draw_rect(Rect2(100, 142, 12, 40), Color("#7a4a20"))
		ci.draw_rect(Rect2(208, 142, 12, 40), Color("#7a4a20"))
		for f in fish:
			if caught[i].has(f.id):
				continue
			var x := fx(f)
			if x < -60 or x > LW + 60:
				continue
			if f.ty == 2:
				Art.poly(ci, [Vector2(x - 16, f.y - 14), Vector2(x + 2, f.y - 14), Vector2(x + 2, f.y + 2), Vector2(x + 18, f.y + 4), Vector2(x + 18, f.y + 14), Vector2(x - 16, f.y + 14)], Color("#6a4a2a"), 2.5)
				continue
			var s := 1.6 if f.ty == 1 else 1.0
			var c := Color("#ff9f1c") if f.ty == 1 else Color("#ffd23c")
			var d: float = f.dir
			Art.ellipse(ci, Vector2(x, f.y), 18 * s, 10 * s, c)
			Art.ellipse_line(ci, Vector2(x, f.y), 18 * s, 10 * s, Art.OUT, 2.5)
			Art.poly(ci, [Vector2(x - 16 * s * d, f.y), Vector2(x - 28 * s * d, f.y - 9 * s), Vector2(x - 28 * s * d, f.y + 9 * s)], c, 2.5)
			ci.draw_circle(Vector2(x + 9 * s * d, f.y - 2 * s), 2.4 * s, Art.OUT)
		var h: Dictionary = hk[i]
		var hy: float = h.y - (sin(h.reel / .3 * PI) * 30 if h.reel > 0 else 0.0)
		ci.draw_line(Vector2(HX + 40, 108), Vector2(HX, hy - 14), Color(1, 1, 1, .8), 2)
		ci.draw_arc(Vector2(HX, hy), 10, 0, PI, 10, Color("#d0d6e0"), 4)
		ci.draw_line(Vector2(HX + 10, hy), Vector2(HX + 10, hy - 14), Color("#d0d6e0"), 4)
		ci.draw_circle(Vector2(HX, hy - 18), 6, Color("#ff5a4e"))
		ci.draw_line(Vector2(HX + 10, 112), Vector2(HX + 46, 100), Color("#7a4a20"), 5)
		Art.pal(ci, HX - 6, 96, 20, i, {"tag": tag(i) + " · %d" % sc[i], "fy": 1})
		ci.draw_set_transform(Vector2.ZERO)
		if i > 0:
			ci.draw_rect(Rect2(L0 - 3, 0, 6, 720), Art.OUT)
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "")
