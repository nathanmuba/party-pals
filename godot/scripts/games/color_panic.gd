extends MiniGame

const NAME := "Color Panic"
const MODES := ["ffa", "2v2"]
const HOW := "Move to run · Action: shove · Read the rule carefully!"
const CC := [Color("#ff4d6d"), Color("#4dabf7"), Color("#51cf66"), Color("#fcc419")]
const CN := ["RED", "BLUE", "GREEN", "YELLOW"]

static func desc(m: String) -> String:
	return "A color word flashes up. When the bar runs out, every tile that is not the right color drops away! Read the rule: sometimes it is the WORD, sometimes the INK it is written in. It gets faster every round. No time limit. " + ("Last team standing wins!" if m == "2v2" else "Last pal standing wins!")

const C := 10
const R := 6
const S := 94.0
var ox := (1280.0 - C * S) / 2
var oy := 150.0
var elim: Array = []
var tiles: Array = []
var ps: Array = []
var phase := "call"
var pt := 0.0
var rnd_i := 0
var word := 0
var ink := 0
var rule := "WORD"
var target := 0
var cd_len := 3.2
var bp: Array = []

func init(s: Dictionary) -> void:
	super.init(s)
	for xy in [[1.5, 1.5], [8.5, 1.5], [1.5, 4.5], [8.5, 4.5]]:
		ps.append(new_pal(ps.size(), ox + S * xy[0], oy + S * xy[1]))
	_new_call()

func _deal() -> void:
	tiles = []
	for kk in C * R:
		tiles.append(kk % 4)
	tiles.shuffle()

func _new_call() -> void:
	phase = "call"
	pt = 0.0
	_deal()
	word = randi() % 4
	if rnd_i < 2:
		ink = word
		rule = "WORD"
	else:
		ink = (word + 1 + randi() % 3) % 4
		rule = "WORD" if randf() < .5 else "INK"
	target = word if rule == "WORD" else ink
	cd_len = maxf(1.4, 3.2 - rnd_i * .17)
	bp = []
	for _i in 4:
		bp.append({"at": randf_range(.45, 1.1), "col": target if randf() < (.97 if rnd_i < 2 else .86) else (ink if rule == "WORD" else word)})
	G.beep(520, .08)

func tile_at(x: float, y: float) -> int:
	var c := int(floor((x - ox) / S))
	var r := int(floor((y - oy) / S))
	if c >= 0 and c < C and r >= 0 and r < R:
		return tiles[r * C + c]
	return -1

func update(dt: float, inp: Array) -> void:
	t += dt
	pt += dt
	for p in ps:
		if p.out:
			p.ot += dt
			continue
		step_top(p, inp[p.id], dt, 290.0, Rect2(ox + 16, oy + 16, C * S - 32, R * S - 32))
	push_apart(ps, 48, true)
	if phase == "call" and pt >= cd_len:
		phase = "drop"
		pt = 0.0
		G.beep(160, .3, "sawtooth", .05)
		G.kick(6)
		for p in ps:
			if not p.out and tile_at(p.x, p.y) != target:
				p.out = true
				elim.append(p.id)
				G.beep(260, .35, "sine")
	elif phase == "drop" and pt > 1.6:
		var al := alive_ids(ps)
		if over_for(al):
			result = standing_result(al, elim)
			done = true
		else:
			rnd_i += 1
			_new_call()

func bot(id: int) -> Dictionary:
	var p: Dictionary = ps[id]
	if p.out or p.stun > 0 or phase != "call":
		return {}
	var b: Dictionary = bp[id]
	if pt < b.at:
		return {}
	var best := Vector2(-1, -1)
	var bd := 1e9
	for r in R:
		for c in C:
			if tiles[r * C + c] != b.col:
				continue
			var cpos := Vector2(ox + (c + .5) * S, oy + (r + .5) * S)
			var d := cpos.distance_to(Vector2(p.x, p.y))
			for q in ps:
				if q.id != id and not q.out and cpos.distance_to(Vector2(q.x, q.y)) < 40:
					d += 90
			if d < bd:
				bd = d
				best = cpos
	if best.x < 0:
		return {}
	var m := seek(p, best.x, best.y, 10)
	m.press = pt > cd_len - .6 and shove_bot(p, ps, 90, .04)
	return m

func draw(ci: CanvasItem) -> void:
	Art.vgrad(ci, Color("#241a46"), Color("#0e0820"))
	for r in R:
		for c in C:
			var col: int = tiles[r * C + c]
			var x := ox + c * S
			var y := oy + r * S
			if phase == "drop" and col != target:
				var kk := minf(1.0, pt / .6)
				if kk >= 1:
					continue
				var sz := (S - 10) * (1 - kk * .4)
				var cc: Color = CC[col]
				cc.a = 1 - kk
				Art.rrect(ci, Rect2(x + S / 2 - sz / 2, y + S / 2 - sz / 2 + kk * kk * 120, sz, sz), 14, cc)
				continue
			Art.rrect(ci, Rect2(x + 5, y + 10, S - 10, S - 10), 14, CC[col].darkened(.4))
			Art.rrect(ci, Rect2(x + 5, y + 4, S - 10, S - 12), 14, CC[col])
			Art.rrect(ci, Rect2(x + 12, y + 9, S - 24, 12), 6, Color(1, 1, 1, .25))
	for p in by_y(ps):
		if p.out:
			if p.ot < .8:
				var kk: float = 1.0 - p.ot / .8
				Art.pal(ci, p.x, p.y - 16 + (1 - kk) * 50, 24 * kk, p.id, {"alpha": kk, "dizzy": true})
			continue
		pal_top(ci, p, {"mood": "ouch" if phase == "call" and pt > cd_len - .8 else ""})
	G.draw_parts(ci)
	Art.hud(ci, NAME, null, "Round %d · %d standing" % [rnd_i + 1, alive_ids(ps).size()])
	Art.rrect(ci, Rect2(340, 74, 600, 70), 20, Color(.06, .03, .13, .85))
	Art.text(ci, "Stand on the " + rule, Vector2(480, 108), 22, Color("#ffb3d9") if rule == "INK" else Color("#cdbdff"))
	Art.text(ci, CN[word], Vector2(760, 106), 52, CC[ink])
	if phase == "call":
		var f := 1.0 - pt / cd_len
		Art.rrect(ci, Rect2(350, 134, 580, 8), 4, Color(1, 1, 1, .15))
		Art.rrect(ci, Rect2(350, 134, maxf(4.0, 580 * f), 8), 4, Color("#ff6b6b") if f < .3 else Color("#ffe066"))
