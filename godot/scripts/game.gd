extends Node
## Global game state: players, input from 4 keyboards + controllers, sound and particles.

const KEYSETS := [
	{"name": "Keyboard WASD + Q", "up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D, "act": KEY_Q},
	{"name": "Keyboard IJKL + U", "up": KEY_I, "down": KEY_K, "left": KEY_J, "right": KEY_L, "act": KEY_U},
	{"name": "Keyboard Arrows + Enter", "up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "act": KEY_ENTER},
	{"name": "Keyboard Numpad + 0", "up": KEY_KP_8, "down": KEY_KP_5, "left": KEY_KP_4, "right": KEY_KP_6, "act": KEY_KP_0},
]
## Face buttons by position: 0 bottom, 1 right, 2 left, 3 top.
const FACE := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]

var players: Array = []
var state := {}          # device id -> {x, y, act, pressed, btn}
var key_hit := {}        # physical keycodes pressed this frame
var joy_hit := {}        # "device:button" pressed this frame
var parts: Array = []
var shake := 0.0

# --- tiny synth for beeps ---
var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _tones: Array = []
const RATE := 22050.0

func _ready() -> void:
	for i in 4:
		players.append({"id": i, "dev": "", "coins": 0, "wins": 0, "coop": 0})
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.08
	_player.stream = gen
	_player.volume_db = -4.0
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback()

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		key_hit[e.physical_keycode] = true
		if e.physical_keycode == KEY_F11 or (e.physical_keycode == KEY_ENTER and e.alt_pressed):
			toggle_fullscreen()
	elif e is InputEventJoypadButton and e.pressed:
		joy_hit["%d:%d" % [e.device, e.button_index]] = true

func toggle_fullscreen() -> void:
	var w := get_window()
	w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func _process(_dt: float) -> void:
	_fill_audio()

# ---------------- input ----------------
func dev_ids() -> Array:
	var ids := ["k0", "k1", "k2", "k3"]
	for d in Input.get_connected_joypads():
		ids.append("j%d" % d)
	return ids

func dev_name(id: String) -> String:
	if id.begins_with("k"):
		return KEYSETS[int(id.substr(1))].name
	var n := Input.get_joy_name(int(id.substr(1)))
	return n if n != "" else "Controller"

func is_nintendo(id: String) -> bool:
	if not id.begins_with("j"):
		return false
	var n := Input.get_joy_name(int(id.substr(1))).to_lower()
	return n.contains("nintendo") or n.contains("pro controller") or n.contains("joy-con") or n.contains("switch")

func read_dev(id: String) -> Dictionary:
	var r := {"x": 0.0, "y": 0.0, "act": false, "pressed": false, "btn": -1}
	if id.begins_with("k"):
		var m: Dictionary = KEYSETS[int(id.substr(1))]
		r.x = float(Input.is_physical_key_pressed(m.right)) - float(Input.is_physical_key_pressed(m.left))
		r.y = float(Input.is_physical_key_pressed(m.down)) - float(Input.is_physical_key_pressed(m.up))
		r.pressed = key_hit.has(m.act)
		r.act = Input.is_physical_key_pressed(m.act) or r.pressed
		var dirs := [m.down, m.right, m.left, m.up]
		for i in 4:
			if key_hit.has(dirs[i]):
				r.btn = i
				break
	else:
		var d := int(id.substr(1))
		var v := Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		if v.length() < 0.3:
			v = Vector2.ZERO
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_LEFT): v.x = -1
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_RIGHT): v.x = 1
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP): v.y = -1
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_DOWN): v.y = 1
		r.x = v.x
		r.y = v.y
		for i in 4:
			if Input.is_joy_button_pressed(d, FACE[i]):
				r.act = true
			if joy_hit.has("%d:%d" % [d, FACE[i]]):
				r.pressed = true
				r.act = true
				if r.btn < 0:
					r.btn = i
	var vv := Vector2(r.x, r.y)
	if vv.length() > 1.0:
		vv = vv.normalized()
		r.x = vv.x
		r.y = vv.y
	return r

func poll() -> void:
	for id in dev_ids():
		state[id] = read_dev(id)

func end_frame() -> void:
	key_hit.clear()
	joy_hit.clear()

func key(k: int) -> bool:
	return key_hit.has(k)

func pad_hit(button: int) -> bool:
	for k in joy_hit.keys():
		if k.ends_with(":%d" % button):
			return true
	return false

func any_human_pressed() -> bool:
	for p in players:
		if p.dev != "" and state.has(p.dev) and state[p.dev].pressed:
			return true
	return false

func humans() -> Array:
	return players.filter(func(p): return p.dev != "")

func tag_of(id: int) -> String:
	return ("P%d" % (id + 1)) if players[id].dev != "" else "CPU"

# ---------------- sound ----------------
func beep(f: float, d := 0.08, type := "square", v := 0.04) -> void:
	if _tones.size() < 24:
		_tones.append({"f": f, "t": 0.0, "d": d, "type": type, "v": v * 2.2, "ph": 0.0})

func _fill_audio() -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	if n <= 0:
		return
	var dt := 1.0 / RATE
	for _i in n:
		var s := 0.0
		for tn in _tones:
			if tn.t >= tn.d:
				continue
			tn.ph = fmod(tn.ph + tn.f * dt, 1.0)
			var w := 0.0
			match tn.type:
				"square": w = 1.0 if tn.ph < 0.5 else -1.0
				"sine": w = sin(tn.ph * TAU)
				"triangle": w = 1.0 - 4.0 * abs(tn.ph - 0.5)
				_: w = 2.0 * tn.ph - 1.0
			s += w * tn.v * exp(-tn.t / tn.d * 5.0)
			tn.t += dt
		s = clampf(s, -0.9, 0.9)
		_pb.push_frame(Vector2(s, s))
	_tones = _tones.filter(func(tn): return tn.t < tn.d)

# ---------------- particles & shake ----------------
func burst(pos: Vector2, cols, n := 10, sp := 220.0) -> void:
	for i in n:
		var a := randf() * TAU
		var v := randf_range(0.3, 1.0) * sp
		var c: Color = cols[i % cols.size()] if cols is Array else cols
		parts.append({"p": pos, "v": Vector2(cos(a), sin(a)) * v + Vector2(0, -60), "t": 0.0, "life": randf_range(0.35, 0.7), "c": c, "r": randf_range(3, 7)})

func step_parts(dt: float) -> void:
	shake = maxf(0.0, shake - dt * 30.0)
	for p in parts:
		p.t += dt
		p.p += p.v * dt
		p.v.y += 500 * dt
		p.v.x *= 0.98
	parts = parts.filter(func(p): return p.t < p.life)

func draw_parts(ci: CanvasItem) -> void:
	for p in parts:
		var k: float = 1.0 - p.t / p.life
		var c: Color = p.c
		c.a *= k
		ci.draw_circle(p.p, p.r * (0.5 + 0.5 * k), c)

func kick(s: float) -> void:
	shake = maxf(shake, s)
