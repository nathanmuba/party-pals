extends MiniGame

const NAME := "Stack Attack"
const MODES := ["ffa", "coop"]
const HOW := "Action: drop the block (perfect drops keep the full size)"
const LW := 320.0
const BH := 26.0

static func desc(m: String) -> String:
	if m == "coop":
		return "Each pal stacks a tower. Drop the sliding block right on top: any overhang gets sliced off, so your block shrinks! Miss completely and your tower is done. Build 48 floors as a team."
	return "Drop the sliding block right on top of your tower. Any overhang gets sliced off, so your block shrinks! It speeds up as you go. Miss completely and you are out. Last builder standing wins!"

var coop := false
var goal := 48
var dur := 45.0
var T: Array = []
var elim: Array = []

func init(s: Dictionary) -> void:
	super.init(s)
	coop = st.mode == "coop"
	for _i in 4:
		T.append({"tw": [{"x": 160.0, "w": 150.0}], "x": 30.0, "dir": 1.0, "w": 150.0, "out": false, "err": gauss() * 8, "fall": null, "perf": 0.0, "lt": 0.0})

func total() -> int:
	var s := 0
	for tw in T:
		s += tw.tw.size() - 1
	return s

func update(dt: float, inp: Array) -> void:
	t += dt
	for i in 4:
		var tw: Dictionary = T[i]
		if tw.fall != null:
			tw.fall.y += tw.fall.v * dt
			tw.fall.v += 1500 * dt
		if tw.out:
			continue
		tw.perf -= dt
		var lv: int = tw.tw.size()
		var sp := 170.0 + lv * 13
		tw.x += tw.dir * sp * dt
		if tw.x > LW - 20:
			tw.x = LW - 20
			tw.dir = -1.0
		if tw.x < 20:
			tw.x = 20.0
			tw.dir = 1.0
		if inp[i].pressed:
			var top: Dictionary = tw.tw[lv - 1]
			var l := maxf(tw.x - tw.w / 2, top.x - top.w / 2)
			var r := minf(tw.x + tw.w / 2, top.x + top.w / 2)
			var ov := r - l
			if absf(tw.x - top.x) < 5:
				tw.tw.append({"x": top.x, "w": tw.w})
				tw.perf = .6
				G.beep(1320, .08, "sine", .03)
				G.burst(Vector2(i * LW + top.x, 200), [Color.WHITE, Color("#ffe066")], 10, 180)
			elif ov <= 2:
				tw.out = true
				elim.append(i)
				tw.fall = {"x": tw.x, "w": tw.w, "y": 0.0, "v": 0.0}
				G.beep(150, .3, "sawtooth", .05)
				G.kick(5)
			else:
				var cut: float = tw.w - ov
				tw.fall = {"x": l - cut / 2 if tw.x < top.x else r + cut / 2, "w": cut, "y": 0.0, "v": 0.0}
				tw.w = ov
				tw.tw.append({"x": (l + r) / 2, "w": ov})
				G.beep(600 + lv * 15, .05, "triangle", .03)
			tw.x = 20.0 if tw.dir > 0 else LW - 20
			tw.err = gauss() * (8 + tw.tw.size() * 1.2)
			tw.lt = t
	var al := [0, 1, 2, 3].filter(func(i): return not T[i].out)
	if coop:
		if al.is_empty() or t >= dur or total() >= goal:
			result = {"kind": "coop", "collected": total(), "goal": goal, "per": T.map(func(tw): return tw.tw.size() - 1), "unit": "floors"}
			done = true
	elif al.size() <= 1:
		result = standing_result(al, elim)
		done = true

func bot(i: int) -> Dictionary:
	var tw: Dictionary = T[i]
	if tw.out or t - tw.lt < .5:
		return {}
	var top: Dictionary = tw.tw[tw.tw.size() - 1]
	var sp: float = 170.0 + tw.tw.size() * 13
	return {"press": true} if absf(tw.x - (top.x + tw.err)) < sp / 60.0 * .7 else {}

func draw(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color("#1d1433"))
	for i in 4:
		var L0 := i * LW
		var tw: Dictionary = T[i]
		var lv: int = tw.tw.size()
		var cam := maxi(0, lv - 14)
		ci.draw_set_transform(Vector2(L0, 0))
		Art.vgrad(ci, Color("#4e8dff").darkened(.5 - minf(.4, lv * .015)), Color("#bfe7ff"), Rect2(0, 0, LW, 720))
		for k in range(maxi(0, cam - 1), lv):
			var b: Dictionary = tw.tw[k]
			var y := 650.0 - (k - cam) * BH
			var col: Color = Color("#5a4a6a") if k == 0 else Art.COLORS[i].lightened(((k % 6) - 3) * .05)
			ci.draw_rect(Rect2(b.x - b.w / 2, y - BH, b.w, BH), col)
			ci.draw_rect(Rect2(b.x - b.w / 2, y - BH, b.w, BH), Art.OUT, false, 2)
			ci.draw_rect(Rect2(b.x - b.w / 2, y - BH, b.w, 5), Color(1, 1, 1, .25))
		var top_y := 650.0 - (lv - cam) * BH
		if tw.fall != null:
			var fc: Color = Art.COLORS[i].darkened(.2)
			fc.a = maxf(0.0, 1 - tw.fall.y / 400)
			ci.draw_rect(Rect2(tw.fall.x - tw.fall.w / 2, top_y - BH + tw.fall.y, tw.fall.w, BH), fc)
		if not tw.out:
			var y := top_y - 30
			ci.draw_rect(Rect2(tw.x - tw.w / 2, y - BH, tw.w, BH), Art.COLORS[i])
			ci.draw_rect(Rect2(tw.x - tw.w / 2, y - BH, tw.w, BH), Art.OUT, false, 3)
			var dy := y
			while dy < top_y:
				ci.draw_line(Vector2(tw.x, dy), Vector2(tw.x, dy + 5), Color(1, 1, 1, .5), 2)
				dy += 10
		if tw.perf > 0:
			Art.text(ci, "PERFECT!", Vector2(LW / 2, 140), 26, Color("#ffe066"))
		Art.pal(ci, LW / 2, 690, 18, i, {"dizzy": tw.out, "cheer": tw.perf > 0})
		Art.text(ci, tag(i) + " · %d floors" % (lv - 1) + (" · OUT" if tw.out else ""), Vector2(LW / 2, 660), 17)
		ci.draw_set_transform(Vector2.ZERO)
		if i > 0:
			ci.draw_rect(Rect2(L0 - 3, 0, 6, 720), Art.OUT)
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t if coop else null, ("Team floors %d / %d" % [total(), goal]) if coop else "%d building" % T.filter(func(tw): return not tw.out).size())
