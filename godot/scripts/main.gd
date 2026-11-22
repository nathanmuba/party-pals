extends Node2D
## Party flow: title → (free play) → round intro → mini-game → results → … → bonus awards → podium.

const W := 1280.0
const H := 720.0
const MODES := {
	"ffa": {"label": "FREE-FOR-ALL", "sub": "Every pal for themselves"},
	"2v2": {"label": "2 VS 2", "sub": "Team up with a partner"},
	"1v3": {"label": "1 VS 3", "sub": "One brave pal against the rest"},
	"coop": {"label": "CO-OP", "sub": "Everyone works together for coins"},
}
const MODE_TAG := {"ffa": "1v1v1v1", "2v2": "2 vs 2", "1v3": "1 vs 3", "coop": "Co-op"}
const MODE_COL := {"ffa": Color("#ff9f1c"), "2v2": Color("#c77dff"), "1v3": Color("#ff5a4e"), "coop": Color("#3ccf6e")}
const ROUND_OPTS := [3, 6, 10, 15, 20]
const GOAL_COUNT := 50

var S := "title"
var T := 0.0
var rounds_total := 6
var round_i := 0
var last_mode := ""
var last_game = null
var setup := {}
var game: MiniGame = null
var res := {}
var solo_count := [0, 0, 0, 0]
var ready_flags := [false, false, false, false]
var final_data := {}
var free_play := false
var lib := {"sel": 0, "mode": 0, "cool": 0.0, "scroll": 0}
var click = null
var autotest := false
var at_from := 0
var at_to := 999
var at_runs := 4

func _ready() -> void:
	randomize()
	get_window().min_size = Vector2i(640, 360)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--autotest"):
			autotest = true
			if a.contains("="):
				var r := a.split("=")[1].split(",")
				at_from = int(r[0])
				at_to = int(r[1])
		elif a.begins_with("--shot="):
			_shot_mode(a.substr(7))

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		click = get_global_mouse_position()

func _process(dt: float) -> void:
	if autotest:
		_run_autotest()
		return
	dt = minf(dt, 0.05)
	Art.time += dt
	G.poll()
	_update(dt)
	G.step_parts(dt)
	queue_redraw()
	G.end_frame()
	click = null

# ---------------- party logic ----------------
func inputs() -> Array:
	var out := []
	for p in G.players:
		var i: Dictionary
		if p.dev != "" and G.state.has(p.dev):
			i = G.state[p.dev].duplicate()
		else:
			var b: Dictionary = game.bot(p.id) if game else {}
			var pr: bool = b.get("press", false)
			i = {"x": float(b.get("x", 0.0)), "y": float(b.get("y", 0.0)), "act": pr, "pressed": pr, "btn": b.get("btn", -1)}
		var v := Vector2(i.x, i.y)
		if v.length() > 1.0:
			v = v.normalized()
			i.x = v.x
			i.y = v.y
		out.append(i)
	return out

func _no_input() -> Array:
	var a := []
	for _i in 4:
		a.append({"x": 0.0, "y": 0.0, "act": false, "pressed": false, "btn": -1})
	return a

func make_setup(mode: String, gs) -> Dictionary:
	var team := [0, 0, 0, 0]
	var solo := -1
	if mode == "2v2":
		var ids := [0, 1, 2, 3]
		ids.shuffle()
		team[ids[2]] = 1
		team[ids[3]] = 1
	if mode == "1v3":
		var mn: int = solo_count.min()
		var c := [0, 1, 2, 3].filter(func(i): return solo_count[i] == mn)
		solo = c.pick_random()
		solo_count[solo] += 1
		for i in 4:
			team[i] = 0 if i == solo else 1
	return {"mode": mode, "G": gs, "team": team, "solo": solo}

func pick_round() -> void:
	var avail := {}
	for gs in Games.LIST:
		for m in gs.MODES:
			avail[m] = true
	var opts := avail.keys().filter(func(m): return m != last_mode)
	if opts.is_empty():
		opts = avail.keys()
	var mode: String = opts.pick_random()
	last_mode = mode
	var pool := Games.LIST.filter(func(gs): return gs.MODES.has(mode))
	var pick := pool.filter(func(gs): return gs != last_game)
	if pick.is_empty():
		pick = pool
	var gs = pick.pick_random()
	last_game = gs
	setup = make_setup(mode, gs)

func reset_scores() -> void:
	for p in G.players:
		p.coins = 0
		p.wins = 0
		p.coop = 0
	solo_count = [0, 0, 0, 0]

func start_party() -> void:
	free_play = false
	reset_scores()
	round_i = 0
	last_mode = ""
	last_game = null
	next_round()
	G.beep(523, .1)
	G.beep(784, .15)

func next_round() -> void:
	round_i += 1
	pick_round()
	_to("intro")

func lib_start() -> void:
	var gs = Games.LIST[lib.sel]
	var mode: String = gs.MODES[lib.mode % gs.MODES.size()]
	free_play = true
	round_i = 1
	setup = make_setup(mode, gs)
	_to("intro")
	G.beep(660, .08)

func start_game() -> void:
	G.parts.clear()
	game = setup.G.new()
	game.init(setup)
	_to("play")

func _to(s: String) -> void:
	S = s
	T = 0.0
	ready_flags = [false, false, false, false]

func apply_awards(r: Dictionary) -> Dictionary:
	var d := [0, 0, 0, 0]
	var head := ""
	var winners := []
	if r.kind == "rank":
		var pts := [10, 5, 3, 0]
		for k in 4:
			d[r.order[k]] = pts[k]
		winners = [r.order[0]]
		head = Art.NAMES[r.order[0]] + " wins!"
	elif r.kind == "team":
		if setup.mode == "1v3":
			var s: int = setup.solo
			if r.winners.has(s):
				d[s] = 15
				head = Art.NAMES[s] + " beat the trio!"
				winners = [s]
			else:
				for i in 4:
					if i != s:
						d[i] = 5
				head = "The trio wins!"
				winners = [0, 1, 2, 3].filter(func(i): return i != s)
		elif r.winners.is_empty():
			d = [3, 3, 3, 3]
			head = "It's a draw!"
		else:
			for i in r.winners:
				d[i] = 8
			head = "Team " + Art.TEAMN[setup.team[r.winners[0]]] + " wins!"
			winners = r.winners
	else:
		var ok: bool = r.collected >= r.goal
		var each := int(round(10.0 * minf(1.0, float(r.collected) / float(r.goal)))) + (3 if ok else 0)
		d = [each, each, each, each]
		for i in 4:
			G.players[i].coop += r.per[i]
		head = ("Goal reached! " if ok else "So close! ") + "%d / %d %s" % [r.collected, r.goal, r.get("unit", "")]
		if ok:
			winners = [0, 1, 2, 3]
	if r.has("bonus"):
		for i in 4:
			d[i] += r.bonus[i]
	for i in winners:
		G.players[i].wins += 1
	for i in 4:
		G.players[i].coins += d[i]
	return {"d": d, "head": head, "winners": winners}

func build_final() -> void:
	var bonus := []
	for a in [["Mini-Game Star", "Most mini-games won", "wins"], ["Team Player", "Most collected in co-op games", "coop"]]:
		var mx: int = G.players.map(func(p): return p[a[2]]).max()
		if mx <= 0:
			continue
		var ids := G.players.filter(func(p): return p[a[2]] == mx).map(func(p): return p.id)
		for i in ids:
			G.players[i].coins += 10
		bonus.append({"title": a[0], "why": a[1], "ids": ids})
	var rank := G.players.duplicate()
	rank.sort_custom(func(x, y): return x.coins > y.coins or (x.coins == y.coins and x.wins > y.wins))
	final_data = {"bonus": bonus, "rank": rank.map(func(p): return p.id)}

func _update(dt: float) -> void:
	T += dt
	match S:
		"title":
			for id in G.dev_ids():
				if G.state[id].pressed and not G.players.any(func(p): return p.dev == id):
					for p in G.players:
						if p.dev == "":
							p.dev = id
							G.beep(600 + p.id * 100, .08)
							break
			if G.key(KEY_BACKSPACE):
				for p in G.players:
					p.dev = ""
			if G.key(KEY_R) or G.pad_hit(JOY_BUTTON_BACK):
				_cycle_rounds()
			var go := G.key(KEY_SPACE) or G.pad_hit(JOY_BUTTON_START)
			var fp := G.key(KEY_F) or G.pad_hit(JOY_BUTTON_LEFT_SHOULDER) or G.pad_hit(JOY_BUTTON_RIGHT_SHOULDER)
			if click != null:
				if Rect2(350, 575, 340, 70).has_point(click): go = true
				elif Rect2(710, 575, 220, 70).has_point(click): fp = true
				elif Rect2(500, 520, 280, 40).has_point(click): _cycle_rounds()
			if G.key(KEY_ESCAPE) and T > .3:
				get_tree().quit()
			if go:
				start_party()
			elif fp:
				reset_scores()
				_to("library")
				G.beep(500, .06)
		"library":
			var n := Vector2.ZERO
			for id in G.dev_ids():
				n += Vector2(G.state[id].x, G.state[id].y)
			var gs = Games.LIST[lib.sel]
			if absf(n.x) < .3 and absf(n.y) < .3:
				lib.cool = 0.0
			else:
				lib.cool -= dt
				if lib.cool <= 0:
					if n.y < -.5:
						lib.sel = (lib.sel + Games.LIST.size() - 1) % Games.LIST.size()
						lib.mode = 0
					elif n.y > .5:
						lib.sel = (lib.sel + 1) % Games.LIST.size()
						lib.mode = 0
					elif n.x > .5:
						lib.mode = (lib.mode + 1) % gs.MODES.size()
					elif n.x < -.5:
						lib.mode = (lib.mode + gs.MODES.size() - 1) % gs.MODES.size()
					lib.cool = .12 if lib.cool < -1 else .22
					G.beep(420, .03)
			lib.scroll = clampi(lib.scroll, maxi(0, lib.sel - 8), lib.sel)
			if click != null:
				for k in 9:
					var i: int = lib.scroll + k
					if i < Games.LIST.size() and Rect2(70, 140 + k * 58, 520, 50).has_point(click):
						if lib.sel == i:
							lib_start()
							return
						lib.sel = i
						lib.mode = 0
				gs = Games.LIST[lib.sel]
				for k in gs.MODES.size():
					if Rect2(680 + k * 140, 250, 128, 44).has_point(click):
						lib.mode = k
				if Rect2(760, 560, 300, 70).has_point(click):
					lib_start()
					return
				if Rect2(70, 660, 160, 44).has_point(click):
					_to("title")
					return
			if T > .3:
				for id in G.dev_ids():
					if G.state[id].pressed:
						if not G.players.any(func(p): return p.dev == id):
							for p in G.players:
								if p.dev == "":
									p.dev = id
									break
						lib_start()
						return
			if G.key(KEY_ESCAPE) or G.key(KEY_BACKSPACE) or G.pad_hit(JOY_BUTTON_BACK):
				_to("title")
		"intro":
			for p in G.players:
				if p.dev != "" and G.state.has(p.dev) and G.state[p.dev].pressed and T > .8 and not ready_flags[p.id]:
					ready_flags[p.id] = true
					G.beep(700, .05)
			var hs := G.humans()
			if T > 9 or (hs.size() > 0 and T > 1 and hs.all(func(p): return ready_flags[p.id])) or (hs.is_empty() and T > 3.5):
				start_game()
		"play":
			if T < 2.4:
				var n2 := int(T / .8)
				var pn := int((T - dt) / .8)
				if n2 != pn or T == dt:
					G.beep(880 if n2 == 2 else 440, .1)
				game.update(0.0, _no_input())
			else:
				if T - dt < 2.4:
					G.beep(1046, .15)
				game.update(dt, inputs())
			if game.done:
				res = apply_awards(game.result)
				_to("finish")
				G.beep(784, .1)
				G.beep(523, .2)
		"finish":
			if T > 1.3:
				_to("results")
		"results":
			if (T > 1.2 and (G.any_human_pressed() or G.key(KEY_SPACE) or click != null)) or T > (12.0 if free_play else 7.0):
				if free_play:
					_to("library")
				elif round_i < rounds_total:
					next_round()
				else:
					build_final()
					_to("final")
		"final":
			if T > 6.5 and (G.any_human_pressed() or G.key(KEY_SPACE) or click != null):
				_to("title")

func _cycle_rounds() -> void:
	rounds_total = ROUND_OPTS[(ROUND_OPTS.find(rounds_total) + 1) % ROUND_OPTS.size()]
	G.beep(400, .05)

# ---------------- drawing ----------------
func _draw() -> void:
	match S:
		"title": _draw_title()
		"library": _draw_library()
		"intro": _draw_intro()
		"play", "finish":
			if G.shake > 0:
				draw_set_transform(Vector2(randf_range(-G.shake, G.shake), randf_range(-G.shake, G.shake)))
			game.draw(self)
			draw_set_transform(Vector2.ZERO)
			_vignette()
			if S == "play":
				_countdown()
			else:
				draw_rect(Rect2(0, 0, W, H), Color(.04, .02, .1, .35))
				Art.text(self, "FINISH!", Vector2(W / 2, H / 2), 130, Color("#ffe066"))
		"results": _draw_results()
		"final": _draw_final()

func _vignette() -> void:
	var c0 := Color(.04, 0, .12, 0)
	var c1 := Color(.04, 0, .12, .35)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, 60), Vector2(0, 60)]), PackedColorArray([c1, c1, c0, c0]))
	draw_polygon(PackedVector2Array([Vector2(0, H - 60), Vector2(W, H - 60), Vector2(W, H), Vector2(0, H)]), PackedColorArray([c0, c0, c1, c1]))

func _countdown() -> void:
	if T < 2.4:
		var n := 3 - int(T / .8)
		draw_rect(Rect2(0, 0, W, H), Color(.04, .02, .1, .35))
		Art.text(self, str(n), Vector2(W / 2, H / 2), int(140 * (1.0 + (1.0 - fmod(T, .8) / .8) * .4)), Color("#ffe066"))
	elif T < 3.1:
		Art.text(self, "GO!", Vector2(W / 2, H / 2), 150, Color("#7dff9a"))

func _press_hint(y := H - 40) -> void:
	if not G.humans().is_empty():
		Art.text(self, "Press your action button to continue", Vector2(W / 2, y), 22, Color("#cdbdff"))

func _draw_title() -> void:
	Art.vgrad(self, Color("#3a2470"), Color("#1d1433"))
	Art.confetti(self, T, 1.0)
	Art.text(self, "PARTY PALS", Vector2(W / 2, 118), 112, Color("#ffe066"))
	Art.text(self, "Mini-games, races and chaos for 4 · free-for-all, 2 vs 2, 1 vs 3 and co-op", Vector2(W / 2, 192), 24, Color("#e6d6ff"))
	for i in 4:
		var x := 220.0 + i * 280
		var p: Dictionary = G.players[i]
		Art.rrect(self, Rect2(x - 115, 240, 230, 250), 22, Color(1, 1, 1, .08), 4, Art.COLORS[i] if p.dev != "" else Color(1, 1, 1, .2))
		Art.pal(self, x, 360, 46, i, {"bob": absf(sin(T * 4 + i)) * 8, "fx": sin(T + i), "fy": .3, "cheer": p.dev != ""})
		Art.text(self, "P%d · %s" % [i + 1, Art.NAMES[i]], Vector2(x, 440), 24, Art.COLORS[i])
		Art.text(self, G.dev_name(p.dev) if p.dev != "" else "CPU: press action to join", Vector2(x, 470), 16 if p.dev != "" else 14, Color.WHITE if p.dev != "" else Color("#bba9e6"), 0, false)
	Art.rrect(self, Rect2(500, 520, 280, 40), 14, Color(1, 1, 1, .1))
	Art.text(self, "Rounds: %d   (R / Back to change)" % rounds_total, Vector2(W / 2, 540), 19)
	Art.button(self, Rect2(350, 575, 340, 70), "START PARTY", Color("#ff5a4e"))
	Art.button(self, Rect2(710, 575, 220, 70), "FREE PLAY", Color("#7a52d6"), 28)
	Art.text(self, "Space / Start to begin · F / L / R for free play · Backspace clears players · F11 fullscreen · Esc quits", Vector2(W / 2, 682), 16, Color("#cdbdff"), 0, false)

func _draw_library() -> void:
	Art.vgrad(self, Color("#2b1b55"), Color("#140d26"))
	Art.text(self, "FREE PLAY", Vector2(70, 76), 44, Color("#ffe066"), -1)
	Art.text(self, "%d mini-games" % Games.LIST.size(), Vector2(590, 82), 18, Color("#cdbdff"), 1, false)
	for k in 9:
		var i: int = lib.scroll + k
		if i >= Games.LIST.size():
			break
		var gs = Games.LIST[i]
		var y := 140.0 + k * 58
		var sel: bool = i == lib.sel
		Art.rrect(self, Rect2(70, y, 520, 50), 16, Color("#ffe066") if sel else Color(1, 1, 1, .07))
		Art.text(self, gs.NAME, Vector2(92, y + 26), 24, Color("#2a1650") if sel else Color.WHITE, -1, not sel)
		var x := 580.0
		var ms: Array = gs.MODES.duplicate()
		ms.reverse()
		for m in ms:
			var w := Art.text_w(MODE_TAG[m], 14) + 18
			x -= w + 6
			Art.rrect(self, Rect2(x, y + 13, w, 26), 13, MODE_COL[m])
			Art.text(self, MODE_TAG[m], Vector2(x + w / 2, y + 27), 14, Color.WHITE, 0, false)
	var g2 = Games.LIST[lib.sel]
	var mode: String = g2.MODES[lib.mode % g2.MODES.size()]
	Art.rrect(self, Rect2(650, 140, 560, 500), 26, Color(1, 1, 1, .06))
	Art.text(self, g2.NAME, Vector2(930, 200), 46, Color("#ffe066"))
	for k in g2.MODES.size():
		var m: String = g2.MODES[k]
		Art.rrect(self, Rect2(680 + k * 140, 250, 128, 44), 22, MODE_COL[m] if m == mode else Color(1, 1, 1, .1))
		Art.text(self, MODE_TAG[m], Vector2(744 + k * 140, 272), 18, Color.WHITE, 0, false)
	var ly := Art.wrap(self, g2.desc(mode), Vector2(930, 330), 490, 28, 20, Color.WHITE)
	Art.wrap(self, g2.HOW, Vector2(930, ly + 40), 490, 24, 16, Color("#cdbdff"))
	Art.button(self, Rect2(760, 560, 300, 70), "PLAY", Color("#3ccf6e"))
	Art.rrect(self, Rect2(70, 660, 160, 44), 16, Color(1, 1, 1, .1))
	Art.text(self, "◀ Back", Vector2(150, 683), 20, Color.WHITE, 0, false)
	Art.text(self, "Up / down: pick a game · Left / right: pick a mode · Action: play · Esc: back", Vector2(740, 683), 16, Color("#cdbdff"), 0, false)

func _draw_intro() -> void:
	var m: Dictionary = MODES[setup.mode]
	var gs = setup.G
	Art.vgrad(self, Color("#2b1b55"), Color("#140d26"))
	var slide := minf(1.0, T * 3)
	Art.text(self, "FREE PLAY" if free_play else "ROUND %d / %d" % [round_i, rounds_total], Vector2(W / 2, 70), 30, Color("#cdbdff"))
	draw_set_transform(Vector2((1.0 - slide) * -W, 0))
	Art.rrect(self, Rect2(240, 100, 800, 110), 30, MODE_COL[setup.mode])
	Art.rrect(self, Rect2(250, 106, 780, 36), 18, Color(1, 1, 1, .18))
	Art.text(self, m.label, Vector2(W / 2, 145), 64)
	Art.text(self, m.sub, Vector2(W / 2, 190), 22)
	draw_set_transform(Vector2.ZERO)
	Art.text(self, gs.NAME, Vector2(W / 2, 265), 52, Color("#ffe066"))
	var ly := Art.wrap(self, gs.desc(setup.mode), Vector2(W / 2, 315), 820, 30, 22, Color.WHITE)
	Art.wrap(self, gs.HOW, Vector2(W / 2, ly + 42), 900, 24, 18, Color("#cdbdff"))
	var pos := []
	if setup.mode == "2v2":
		var a := [0, 1, 2, 3].filter(func(i): return setup.team[i] == 0)
		var b := [0, 1, 2, 3].filter(func(i): return setup.team[i] == 1)
		pos = [[a[0], 300], [a[1], 440], [b[0], 840], [b[1], 980]]
		Art.text(self, "VS", Vector2(W / 2, 560), 48)
		Art.text(self, "Team " + Art.TEAMN[0], Vector2(370, 658), 22, Art.TEAMC[0])
		Art.text(self, "Team " + Art.TEAMN[1], Vector2(910, 658), 22, Art.TEAMC[1])
	elif setup.mode == "1v3":
		pos = [[setup.solo, 300]]
		var k := 0
		for i in 4:
			if i != setup.solo:
				pos.append([i, 760 + k * 140])
				k += 1
		Art.text(self, "VS", Vector2(530, 560), 48)
	else:
		for i in 4:
			pos.append([i, 320 + i * 213])
	for pr in pos:
		var id: int = pr[0]
		Art.pal(self, pr[1], 555, 40, id, {"crown": setup.mode == "1v3" and id == setup.solo, "ring": Art.TEAMC[setup.team[id]] if setup.mode == "2v2" else null,
			"bob": absf(sin(T * 8)) * 10 if ready_flags[id] else 0.0, "cheer": ready_flags[id], "tag": G.tag_of(id)})
		if G.players[id].dev != "":
			Art.text(self, "READY!" if ready_flags[id] else "press action", Vector2(pr[1], 622), 18, Color("#7dff9a") if ready_flags[id] else Color("#bba9e6"))
	var hs := G.humans()
	Art.text(self, ("Starts when everyone is ready (%d)" % maxi(0, int(ceil(9 - T)))) if hs.size() > 0 else "CPU pals getting ready…", Vector2(W / 2, 692), 18, Color("#cdbdff"), 0, false)

func _draw_standings(y0: float) -> void:
	var mx: int = maxi(1, G.players.map(func(p): return p.coins).max())
	var order := G.players.duplicate()
	order.sort_custom(func(a, b): return a.coins > b.coins)
	for k in 4:
		var p: Dictionary = order[k]
		var y := y0 + k * 66
		Art.pal(self, 250, y - 2, 22, p.id, {"cheer": S == "results" and res.winners.has(p.id)})
		Art.text(self, Art.NAMES[p.id], Vector2(300, y), 24, Art.COLORS[p.id], -1)
		Art.rrect(self, Rect2(420, y - 16, 560, 32), 14, Color(1, 1, 1, .1))
		Art.rrect(self, Rect2(420, y - 16, maxf(28, 560.0 * p.coins / mx), 32), 14, Art.COLORS[p.id])
		Art.text(self, "%d coins" % p.coins, Vector2(1000, y), 24, Color("#ffe066"), -1)
		if S == "results" and res.d[p.id] != 0:
			Art.text(self, "+%d" % res.d[p.id], Vector2(1150, y), 24, Color("#7dff9a"), -1)

func _draw_results() -> void:
	Art.vgrad(self, Color("#2b1b55"), Color("#140d26"))
	if not res.winners.is_empty():
		Art.confetti(self, T, 2.0)
	Art.text(self, res.head, Vector2(W / 2, 90), 60, Color("#ffe066"))
	Art.text(self, setup.G.NAME + " · " + MODES[setup.mode].label, Vector2(W / 2, 150), 22, Color("#cdbdff"))
	_draw_standings(250)
	Art.text(self, "Back to Free Play next" if free_play else ("Next: round %d of %d" % [round_i + 1, rounds_total] if round_i < rounds_total else "Final round done. Time for bonus awards!"), Vector2(W / 2, 560), 22)
	_press_hint(640)

func _draw_final() -> void:
	Art.vgrad(self, Color("#3a2470"), Color("#140d26"))
	var fd := final_data
	if T < 4.5 and not fd.bonus.is_empty():
		var b: Dictionary = fd.bonus[mini(fd.bonus.size() - 1, int(T / 2.25))]
		Art.text(self, "BONUS AWARD", Vector2(W / 2, 140), 30, Color("#cdbdff"))
		Art.text(self, b.title, Vector2(W / 2, 220), 72, Color("#ffe066"))
		Art.text(self, b.why + " · +10 coins", Vector2(W / 2, 290), 26)
		for j in b.ids.size():
			Art.pal(self, W / 2 + (j - (b.ids.size() - 1) / 2.0) * 160, 470, 56, b.ids[j], {"bob": absf(sin(T * 6 + j)) * 16, "crown": true, "cheer": true, "tag": Art.NAMES[b.ids[j]]})
		return
	Art.confetti(self, T, 3.0)
	var w: int = fd.rank[0]
	Art.text(self, Art.NAMES[w] + " is the Party Champion!", Vector2(W / 2, 90), 58, Art.COLORS[w])
	for pod in [[1, 380.0, 170.0], [0, 640.0, 240.0], [2, 900.0, 120.0]]:
		var pl: int = pod[0]
		var x: float = pod[1]
		var h: float = pod[2]
		var id: int = fd.rank[pl]
		Art.rrect(self, Rect2(x - 110, 600 - h, 220, h), 16, [Color("#ffd23c"), Color("#d9e2ec"), Color("#e0a060")][pl])
		Art.text(self, str(pl + 1), Vector2(x, 600 - h / 2), 60, Color("#3a2470"), 0, false)
		Art.pal(self, x, 600 - h - 50, 54.0 if pl == 0 else 44.0, id, {"crown": pl == 0, "cheer": pl == 0, "bob": absf(sin(T * 5 + pl)) * (14.0 if pl == 0 else 6.0), "tag": "%s · %d" % [Art.NAMES[id], G.players[id].coins]})
	var f4: int = fd.rank[3]
	Art.text(self, "4th: %s · %d coins" % [Art.NAMES[f4], G.players[f4].coins], Vector2(W / 2, 640), 22, Color("#cdbdff"))
	if T > 6.5:
		Art.text(self, "Press action, Space or click to return to the title", Vector2(W / 2, 690), 20, Color("#cdbdff"), 0, false)

# ---------------- testing helpers ----------------
## godot --headless -- --autotest : plays every game/mode with CPU pals and prints the results.
func _run_autotest() -> void:
	autotest = false
	var dt := 1.0 / 60.0
	for gi in range(at_from, mini(at_to, Games.LIST.size())):
		var gs = Games.LIST[gi]
		for mode in gs.MODES:
			var wins := [0, 0, 0, 0]
			var total_t := 0.0
			var runs := at_runs
			for _r in runs:
				setup = make_setup(mode, gs)
				game = gs.new()
				game.init(setup)
				var tt := 0.0
				while not game.done and tt < 150.0:
					G.state.clear()
					game.update(dt, inputs())
					G.step_parts(dt)
					tt += dt
				total_t += tt
				if not game.done:
					print("UNFINISHED ", gs.NAME, "/", mode)
					continue
				var r := game.result
				if r.kind == "rank":
					wins[r.order[0]] += 1
				elif r.kind == "team":
					for i in r.winners:
						wins[i] += 1
			print("%s/%s  avg %.1fs  wins %s" % [gs.NAME, mode, total_t / runs, str(wins)])
	print("AUTOTEST DONE")
	get_tree().quit()

## --shot=index,modeIndex,seconds,path : jump into a game, wait, save a screenshot, quit.
func _shot_mode(arg: String) -> void:
	var a := arg.split(",")
	var idx := int(a[0])
	await get_tree().process_frame
	if idx >= 0:
		lib.sel = idx
		lib.mode = int(a[1])
		lib_start()
	await get_tree().create_timer(float(a[2])).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(a[3])
	get_tree().quit()
