extends MiniGame

const NAME := "Strongman Swing"
const MODES := ["ffa", "2v2"]
const HOW := "Action: swing the hammer (stop the needle)"

static func desc(m: String) -> String:
	return "Three swings each at the high striker. Stop the wobbly needle inside the gold zone for a big score. The needle speeds up and slows down on its own, so watch it closely!" + (" Highest team total wins." if m == "2v2" else " Highest total wins.")

var dur := 40.0
var sc := [0, 0, 0, 0]
var P: Array = []

func init(s: Dictionary) -> void:
	super.init(s)
	for _i in 4:
		P.append({"ph": randf() * TAU, "z": randf_range(.6, .9), "left": 3, "last": 0, "show": 0.0, "puck": 0.0, "ae": gauss() * .03, "wait": .6})

func val(p: Dictionary) -> float:
	return .5 + .5 * sin(p.ph)

func update(dt: float, inp: Array) -> void:
	t += dt
	for i in 4:
		var p: Dictionary = P[i]
		if p.show > 0:
			p.show -= dt
			if p.show <= 0 and p.left > 0:
				p.z = randf_range(.55, .92)
				p.ae = gauss() * .03
				p.wait = .4
			continue
		if p.left <= 0:
			continue
		p.wait -= dt
		var sp: float = (2.3 + (3 - p.left) * .55) * (1 + .4 * sin(t * 1.7 + i * 2))
		p.ph += sp * dt
		if inp[i].pressed and p.wait <= 0:
			var v := val(p)
			var s := maxi(0, int(round(100 - absf(v - p.z) * 650)))
			sc[i] += s
			p.last = s
			p.puck = v
			p.left -= 1
			p.show = 1.3
			G.beep(1200 if s > 85 else (700 if s > 50 else 200), .12, "sine" if s > 50 else "sawtooth", .04)
			if s > 85:
				G.burst(Vector2(Art.SEAT[i], 200), [Color("#ffd23c"), Color("#fff3a0")], 18, 260)
				G.kick(3)
	if P.all(func(p): return p.left <= 0 and p.show <= 0) or t >= dur:
		result = score_result(sc)
		done = true

func bot(i: int) -> Dictionary:
	var p: Dictionary = P[i]
	if p.left <= 0 or p.show > 0 or p.wait > 0:
		return {}
	return {"press": true} if absf(val(p) - (p.z + p.ae)) < .02 else {}

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#ff9a6a"), Color("#7a2e6e"))
	for kk in 12:
		Art.poly(ci, [Vector2(640, 720), Vector2(kk * 120, 0), Vector2(kk * 120 + 50, 0)], Color(1, 1, 1, .08))
	for i in 4:
		var x: float = Art.SEAT[i]
		var p: Dictionary = P[i]
		var top := 185.0
		var bot := 545.0
		var hgt := bot - top
		Art.rrect(ci, Rect2(x - 26, top - 10, 52, hgt + 20), 14, Color("#3a2448"), 4)
		ci.draw_polygon(PackedVector2Array([Vector2(x - 16, bot), Vector2(x + 16, bot), Vector2(x + 16, top + hgt * .4), Vector2(x - 16, top + hgt * .4)]), PackedColorArray([Color("#3ccf6e"), Color("#3ccf6e"), Color("#ffd23c"), Color("#ffd23c")]))
		ci.draw_polygon(PackedVector2Array([Vector2(x - 16, top + hgt * .4), Vector2(x + 16, top + hgt * .4), Vector2(x + 16, top), Vector2(x - 16, top)]), PackedColorArray([Color("#ffd23c"), Color("#ffd23c"), Color("#ff5a4e"), Color("#ff5a4e")]))
		if p.left > 0 or p.show > 0:
			var zr := Rect2(x - 24, bot - (p.z + .077) * hgt, 48, .154 * hgt)
			ci.draw_rect(zr, Color(1, 1, 1, .85))
			ci.draw_rect(zr, Color("#b07800"), false, 3)
		var v: float = p.puck if p.show > 0 else val(p)
		var ny := bot - v * hgt
		Art.poly(ci, [Vector2(x - 36, ny), Vector2(x - 22, ny - 9), Vector2(x - 22, ny + 9)], Color("#2a1650"))
		ci.draw_rect(Rect2(x - 22, ny - 3, 44, 6), Color("#2a1650"))
		ci.draw_circle(Vector2(x, top - 30), 22, Color("#ffd23c"))
		Art.ellipse_line(ci, Vector2(x, top - 30), 22, 22, Art.OUT, 3)
		if p.last > 85 and p.show > 0:
			Art.text(ci, "DING!", Vector2(x + 52, top - 34), 24, Color("#fff3a0"))
		Art.pal(ci, x - 46, 600, 30, i, {"tag": tag(i), "cheer": p.show > 0 and p.last > 70, "mood": "ouch" if (p.show > 0 and p.last < 30) else "", "ring": ring(i)})
		ci.draw_set_transform(Vector2(x - 20, 590), .4 if p.show > 0 else -.6)
		ci.draw_rect(Rect2(-3, -50, 6, 50), Color("#8a5a32"))
		Art.rrect(ci, Rect2(-16, -64, 32, 18), 5, Color("#5a5a6a"), 2)
		ci.draw_set_transform(Vector2.ZERO)
		Art.text(ci, str(sc[i]), Vector2(x + 30, 600), 28)
		Art.text(ci, ("+%d" % p.last) if p.show > 0 else "swings left: %d" % p.left, Vector2(x + 10, 650), 17, Color("#ffe066") if p.show > 0 else Color("#e6d6ff"))
	G.draw_parts(ci)
	Art.hud(ci, NAME, dur - t, "")
