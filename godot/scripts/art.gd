class_name Art
extends RefCounted
## Drawing helpers shared by every screen and mini-game (all art is drawn in code).

const W := 1280.0
const H := 720.0
const OUT := Color("#1c1233")
const COLORS := [Color("#ff5a4e"), Color("#4e8dff"), Color("#3ccf6e"), Color("#ffc93c")]
const NAMES := ["Red", "Blue", "Green", "Yellow"]
const TEAMC := [Color("#ff9f1c"), Color("#c77dff")]
const TEAMN := ["Orange", "Purple"]
const SEAT := [260.0, 513.0, 766.0, 1019.0]

static var time := 0.0
static var A := 1.0
static var _font: Font

static func font() -> Font:
	if _font == null:
		var fv := FontVariation.new()
		fv.base_font = load("res://fonts/Baloo2.ttf")
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
		_font = fv
	return _font

static func k(c: Color) -> Color:
	return Color(c.r, c.g, c.b, c.a * A)

static func ell_points(c: Vector2, rx: float, ry: float, rot := 0.0, n := 28, a0 := 0.0, a1 := TAU, closed := true) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cnt := n if closed else n + 1
	var cr := cos(rot)
	var sr := sin(rot)
	for i in cnt:
		var a := a0 + (a1 - a0) * float(i) / float(n)
		var p := Vector2(cos(a) * rx, sin(a) * ry)
		pts.append(c + Vector2(p.x * cr - p.y * sr, p.x * sr + p.y * cr))
	return pts

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	if rx < 0.5 or ry < 0.5 or col.a <= 0.003:
		return
	ci.draw_colored_polygon(ell_points(c, rx, ry, rot), col)

static func ellipse_line(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w := 3.0, rot := 0.0) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	var p := ell_points(c, rx, ry, rot)
	p.append(p[0])
	ci.draw_polyline(p, col, w, true)

static func rrect(ci: CanvasItem, r: Rect2, rad: float, col: Color, border := 0.0, bcol := OUT, fill := true) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.draw_center = fill
	sb.set_corner_radius_all(int(rad))
	sb.corner_detail = 6
	if border > 0.0:
		sb.set_border_width_all(int(border))
		sb.border_color = bcol
	ci.draw_style_box(sb, r)

static func text_w(s: String, size: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## align: 0 centre, -1 left, 1 right. pos.y is the vertical centre of the text.
static func text(ci: CanvasItem, s: String, pos: Vector2, size: int, col := Color.WHITE, align := 0, outline := true) -> void:
	var f := font()
	var w := text_w(s, size)
	var x := pos.x - (w / 2.0 if align == 0 else (w if align == 1 else 0.0))
	var y := pos.y + (f.get_ascent(size) - f.get_descent(size)) * 0.42
	if outline:
		ci.draw_string_outline(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(3, size / 6), Color(0.08, 0.04, 0.16, 0.85))
	ci.draw_string(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

static func wrap(ci: CanvasItem, s: String, c: Vector2, max_w: float, lh: float, size: int, col: Color) -> float:
	var line := ""
	var y := c.y
	for word in s.split(" "):
		var test := (line + " " + word).strip_edges()
		if text_w(test, size) > max_w and line != "":
			text(ci, line, Vector2(c.x, y), size, col, 0, false)
			line = word
			y += lh
		else:
			line = test
	text(ci, line, Vector2(c.x, y), size, col, 0, false)
	return y

static func vgrad(ci: CanvasItem, top: Color, bot: Color, r := Rect2(0, 0, W, H)) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([top, top, bot, bot]))

static func checker(ci: CanvasItem, c1: Color, c2: Color, s := 80.0, y0 := 100.0) -> void:
	ci.draw_rect(Rect2(0, 0, W, H), c1)
	var i := 0
	var x := 0.0
	while x < W:
		var j := 0
		var y := y0
		while y < H:
			if (i + j) % 2 == 0:
				ci.draw_rect(Rect2(x, y, s, s), c2)
			y += s
			j += 1
		x += s
		i += 1

static func button(ci: CanvasItem, r: Rect2, label: String, col: Color, size := 34) -> void:
	rrect(ci, Rect2(r.position + Vector2(0, 6), r.size), 24, col.darkened(0.35))
	rrect(ci, r, 24, col)
	rrect(ci, Rect2(r.position + Vector2(8, 5), Vector2(r.size.x - 16, r.size.y * 0.36)), 14, Color(1, 1, 1, 0.22))
	text(ci, label, r.get_center() + Vector2(0, 2), size)

static func hud(ci: CanvasItem, name: String, left, extra := "") -> void:
	rrect(ci, Rect2(20, 14, W - 40, 56), 18, Color(0.06, 0.03, 0.13, 0.6))
	text(ci, name, Vector2(44, 42), 28, Color.WHITE, -1)
	if left != null:
		var l: float = left
		rrect(ci, Rect2(W / 2 - 48, 20, 96, 44), 22, Color("#ff6b6b") if l <= 5.0 else Color("#ffe066"))
		text(ci, str(int(ceil(maxf(0.0, l)))), Vector2(W / 2, 42), 32, Color("#2a1650"), 0, false)
	if extra != "":
		text(ci, extra, Vector2(W - 44, 42), 22, Color.WHITE, 1)

static func confetti(ci: CanvasItem, t: float, seed := 1.0) -> void:
	for i in 70:
		var x := fmod(i * 173.0 * seed + t * 60.0 * (1 + i % 3), W)
		var y := fmod(i * 97.0 + t * (120.0 + (i % 5) * 30.0), H)
		ci.draw_set_transform(Vector2(x, y), t * 3.0 + i)
		ci.draw_rect(Rect2(-5, -3, 10, 6), COLORS[i % 4])
	ci.draw_set_transform(Vector2.ZERO, 0.0)

## Arrow pointing by direction index: 0 down, 1 right, 2 left, 3 up.
static func arrow(ci: CanvasItem, c: Vector2, dir: int, s: float, col: Color) -> void:
	var rot: float = [PI, PI / 2, -PI / 2, 0.0][dir]
	var base := [Vector2(0, -s), Vector2(s * .9, 0), Vector2(s * .38, 0), Vector2(s * .38, s * .85), Vector2(-s * .38, s * .85), Vector2(-s * .38, 0), Vector2(-s * .9, 0)]
	var pts := PackedVector2Array()
	for p in base:
		pts.append(c + p.rotated(rot))
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, OUT, maxf(3, s * 0.12), true)

## The Pal character. idx = player index (0-3) for colour & accessory; -1 for a plain critter (pass "color").
static func pal(ci: CanvasItem, x: float, y: float, r: float, idx: int, o := {}) -> void:
	A = o.get("alpha", 1.0)
	var col: Color = o.get("color", COLORS[idx] if idx >= 0 else Color.WHITE)
	var seed := (idx + 1) * 1.7
	ellipse(ci, Vector2(x, y + r * .98), r * .95, r * .3, k(Color(0, 0, 0, .25)))
	if o.has("ring") and o.ring != null:
		ellipse_line(ci, Vector2(x, y + r * .98), r * 1.15, r * .42, k(o.ring), 5)
	var by: float = y - o.get("bob", 0.0)
	var sq: float = o.get("squash", 1.0)
	var bw := r * (2.0 - sq) * .92
	var bh := r * sq * 1.08
	var mv: bool = o.get("move", false)
	var cheer: bool = o.get("cheer", false)
	var ph := time * 15.0 + seed
	var lw := maxf(2.0, r * .09)
	for s: int in [-1, 1]:
		var lift := maxf(0.0, sin(ph + (PI if s > 0 else 0.0))) * r * .2 if mv else 0.0
		var fc := Vector2(x + s * r * .4, by + bh * .88 - lift)
		ellipse(ci, fc, r * .27, r * .17, k(col.darkened(.35)))
		ellipse_line(ci, fc, r * .27, r * .17, k(OUT), lw)
	for s: int in [-1, 1]:
		var sw := sin(ph + (0.0 if s > 0 else PI)) * r * .14 if mv else (-r * .5 if cheer else 0.0)
		var ac := Vector2(x + s * bw * .97, by + r * .12 + sw)
		ellipse(ci, ac, r * .17, r * .24, k(col.darkened(.1)), s * .5)
		ellipse_line(ci, ac, r * .17, r * .24, k(OUT), lw, s * .5)
	ellipse(ci, Vector2(x, by), bw, bh, k(col.darkened(.3)))
	ellipse(ci, Vector2(x - bw * .05, by - bh * .06), bw * .93, bh * .9, k(col))
	ellipse(ci, Vector2(x - bw * .28, by - bh * .32), bw * .5, bh * .42, k(col.lightened(.22)))
	ellipse(ci, Vector2(x, by + bh * .45), bw * .55, bh * .32, k(Color(1, 1, 1, .18)))
	ellipse_line(ci, Vector2(x, by), bw, bh, k(OUT), lw)
	ellipse(ci, Vector2(x - bw * .42, by - bh * .5), r * .18, r * .1, k(Color(1, 1, 1, .6)), -.6)
	var fx: float = o.get("fx", 0.0) * r * .1
	var fy: float = o.get("fy", 0.0) * r * .08
	var ey := by - bh * .18
	var ex := r * .3
	if o.get("dizzy", false):
		for s: int in [-1, 1]:
			var cx := x + s * ex + fx
			ci.draw_line(Vector2(cx - r * .13, ey - r * .13), Vector2(cx + r * .13, ey + r * .13), k(OUT), maxf(2, r * .1))
			ci.draw_line(Vector2(cx + r * .13, ey - r * .13), Vector2(cx - r * .13, ey + r * .13), k(OUT), maxf(2, r * .1))
		var wv := PackedVector2Array()
		for i in 7:
			wv.append(Vector2(x - r * .2 + i * r * .067, by + bh * .25 + (3.0 if i % 2 else -1.0)))
		ci.draw_polyline(wv, k(OUT), maxf(2, r * .07))
	else:
		var blink := fmod(time + seed * 2.3, 4.2) < .12
		for s: int in [-1, 1]:
			var cx := x + s * ex + fx * .4
			if blink:
				ci.draw_line(Vector2(cx - r * .15, ey), Vector2(cx + r * .15, ey), k(OUT), maxf(2, r * .08))
				continue
			ellipse(ci, Vector2(cx, ey), r * .19, r * .25, k(Color.WHITE))
			ellipse_line(ci, Vector2(cx, ey), r * .19, r * .25, k(OUT), maxf(1.5, r * .06))
			ellipse(ci, Vector2(cx + fx * .7, ey + fy + r * .03), r * .11, r * .14, k(OUT))
			ci.draw_circle(Vector2(cx + fx * .7 + r * .04, ey + fy - r * .04), r * .04, k(Color.WHITE))
		for s: int in [-1, 1]:
			ellipse(ci, Vector2(x + s * r * .52, by + bh * .12), r * .12, r * .07, k(Color(1, .47, .59, .45)))
		var mood: String = o.get("mood", "")
		if mood == "ouch":
			ellipse(ci, Vector2(x + fx * .5, by + bh * .28), r * .09, r * .12, k(OUT))
		elif cheer or mood == "happy":
			var mp := ell_points(Vector2(x + fx * .5, by + bh * .16), r * .17, r * .17, 0.0, 12, 0.0, PI, false)
			ci.draw_colored_polygon(mp, k(Color("#7a1f3a")))
			mp.append(mp[0])
			ci.draw_polyline(mp, k(OUT), maxf(1.5, r * .07))
		else:
			ci.draw_arc(Vector2(x + fx * .5, by + bh * .12), r * .12, .25, PI - .25, 10, k(OUT), maxf(1.5, r * .07))
	var ty := by - bh
	var ol := maxf(1.5, r * .07)
	match idx:
		0:
			var band := ell_points(Vector2(x, by), bw * .99, bh * .74, 0.0, 16, PI * 1.12, PI * 1.88, false)
			ci.draw_polyline(band, k(OUT), r * .3)
			ci.draw_polyline(band, k(Color.WHITE), r * .2)
			var tx := x + bw * .9
			var tw := sin(time * 8 + seed) * r * .08
			var tail := PackedVector2Array([Vector2(tx, ty + bh * .4), Vector2(tx + r * .38, ty + bh * .25 + tw), Vector2(tx + r * .3, ty + bh * .5 + tw)])
			ci.draw_colored_polygon(tail, k(Color.WHITE))
			tail.append(tail[0])
			ci.draw_polyline(tail, k(OUT), ol)
		1:
			var cap := ell_points(Vector2(x, ty + r * .32), bw * .82, r * .45, 0.0, 16, PI, TAU, false)
			ci.draw_colored_polygon(cap, k(Color("#ffe066")))
			cap.append(cap[0])
			ci.draw_polyline(cap, k(OUT), ol)
			ellipse(ci, Vector2(x + bw * .45, ty + r * .32), bw * .5, r * .11, k(Color("#ffe066")))
			ellipse_line(ci, Vector2(x + bw * .45, ty + r * .32), bw * .5, r * .11, k(OUT), ol)
			ci.draw_circle(Vector2(x, ty - r * .12), r * .08, k(Color("#ff5a4e")))
		2:
			var sw2 := sin(time * 3 + seed) * .15
			ci.draw_line(Vector2(x, ty + 2), Vector2(x + r * .02, ty - r * .38), k(Color("#2a7a3a")), maxf(2, r * .08))
			for s: int in [-1, 1]:
				var lc := Vector2(x + r * .02, ty - r * .36) + Vector2(s * r * .2, 0).rotated(s * (.7 + sw2))
				ellipse(ci, lc, r * .22, r * .1, k(Color("#8be36b")), s * (.7 + sw2))
				ellipse_line(ci, lc, r * .22, r * .1, k(OUT), ol, s * (.7 + sw2))
		3:
			var bc := Vector2(x + bw * .45, ty + bh * .12)
			for s: int in [-1, 1]:
				var tri := PackedVector2Array([bc, bc + Vector2(s * r * .38, -r * .2).rotated(.3), bc + Vector2(s * r * .38, r * .2).rotated(.3)])
				ci.draw_colored_polygon(tri, k(Color("#ff7ab6")))
				tri.append(tri[0])
				ci.draw_polyline(tri, k(OUT), ol)
			ci.draw_circle(bc, r * .1, k(Color("#ff7ab6")))
	if o.get("crown", false):
		var cy := ty - (r * .35 if idx == 2 else 2.0)
		var cr := PackedVector2Array([Vector2(x - r * .45, cy), Vector2(x - r * .45, cy - r * .35), Vector2(x - r * .22, cy - r * .15), Vector2(x, cy - r * .42), Vector2(x + r * .22, cy - r * .15), Vector2(x + r * .45, cy - r * .35), Vector2(x + r * .45, cy)])
		ci.draw_colored_polygon(cr, k(Color("#ffd23c")))
		cr.append(cr[0])
		ci.draw_polyline(cr, k(Color("#8a5a00")), 2)
	var tag: String = o.get("tag", "")
	if tag != "" and A > 0.4:
		text(ci, tag, Vector2(x, by - bh - r * (.95 if o.get("crown", false) else .6) - (r * .35 if idx == 2 else 0.0)), 15, col)
	A = 1.0

## Face-button diamond (bottom, right, left, top). hi = lit button.
const XBOX := ["A", "B", "X", "Y"]
const NIN := ["B", "A", "Y", "X"]
const KEYS := ["↓", "→", "←", "↑"]
const BCOL := [Color("#ffc93c"), Color("#ff5a4e"), Color("#3ccf6e"), Color("#4e8dff")]
static func pad(ci: CanvasItem, c: Vector2, sz: float, hi: int, alpha := 1.0) -> void:
	var pos := [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]
	for kk in 4:
		var on := kk == hi
		var r := sz * (.62 if on else .4)
		var col: Color = BCOL[kk] if on else Color(.24, .16, .35, .25)
		col.a *= alpha
		ci.draw_circle(c + pos[kk] * sz, r, col)
		ellipse_line(ci, c + pos[kk] * sz, r, r, Color(OUT, alpha), 6 if on else 3)
		if on:
			text(ci, XBOX[kk], c + pos[kk] * sz + Vector2(0, 3), int(sz * .8))

## kind: 0 circle, 1 triangle, 2 square, 3 star
static func shape(ci: CanvasItem, c: Vector2, s: float, kind: int, col: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	match kind:
		0:
			pts = ell_points(c, s, s, 0.0, 28)
		1:
			for p in [Vector2(0, -s), Vector2(s * .95, s * .8), Vector2(-s * .95, s * .8)]:
				pts.append(c + p.rotated(rot))
		2:
			for p in [Vector2(-s * .85, -s * .85), Vector2(s * .85, -s * .85), Vector2(s * .85, s * .85), Vector2(-s * .85, s * .85)]:
				pts.append(c + p.rotated(rot))
		_:
			for a in 10:
				var r := s * .45 if a % 2 else s
				pts.append(c + Vector2(cos(a * PI / 5 - PI / 2 + rot) * r, sin(a * PI / 5 - PI / 2 + rot) * r))
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, OUT, 3, true)

static func poly(ci: CanvasItem, pts: Array, col: Color, outline := 0.0) -> void:
	var pv := PackedVector2Array(pts)
	ci.draw_colored_polygon(pv, col)
	if outline > 0:
		pv.append(pv[0])
		ci.draw_polyline(pv, OUT, outline, true)

static func heart(ci: CanvasItem, c: Vector2, col: Color) -> void:
	ci.draw_circle(c + Vector2(-5, 0), 6, col)
	ci.draw_circle(c + Vector2(5, 0), 6, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-11, 2), c + Vector2(11, 2), c + Vector2(0, 13)]), col)
