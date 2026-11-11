extends Control
## Look Busy's title screen (docs/look-busy.md, "Title screen"): shown once
## each time the office starts with Look Busy on, before you clock in. Made
## like a 2007 console title:
##   - Behind everything, the real office at sunset filmed live by a slow
##     cinematic camera (its own SubViewport on the office's world): it opens
##     close on the "Golden Hour" picture on the wall (the sunset moves), pulls
##     back, then cuts through the window with Dale against the sun, a crane
##     over the room and a dolly past the main desk, with a white-gold dip
##     between shots, dust in the sunbeam, and title_post.gdshader on top
##     (bloom, warm grade, light leak, grain, vignette). Letterbox bars.
##   - ATTRACT: the polished gold logo (title_logo.gdshader, a glint sweeps
##     through) and PRESS START / TAP TO START. Any press opens the menu.
##   - MENU: the logo moves up, a glossy slanted highlight bar slides between
##     CLOCK IN, HOW TO PLAY and OPTIONS (one line under it says what each
##     does), your records in a card, button prompts along the bottom.
##   - HOW TO PLAY: a glass panel with the live cartoon (BusyDemo, below)
##     and the three rules; BACK returns.
## Nothing past floor 1 is named, so the bosses upstairs, the ladder and
## Dale's secret stay to be found. It pauses the office while it's up and
## runs PROCESS_MODE_ALWAYS. Touch, mouse, keys (arrows / Enter / Esc) and
## the pad (D-pad or stick, A, B, Start) all work; items are 96 px tall.
## Fonts: Inter (scenes/office/fonts, OFL).

signal clocked_in

const FONT := preload("res://addons/hh_minigames/_shared/fonts/press_start_2p.ttf")
const LOGO_FONT := preload("res://scenes/office/fonts/InterDisplay-BlackItalic.otf")
const MENU_FONT := preload("res://scenes/office/fonts/InterDisplay-Bold.otf")
const BODY_FONT := preload("res://scenes/office/fonts/Inter-SemiBold.otf")
const POST := preload("res://scenes/office/title_post.gdshader")
const LOGO_SHADER := preload("res://scenes/office/title_logo.gdshader")
const CLICK := preload("res://addons/hh_minigames/_shared/audio/click.wav")
const CHIME := preload("res://addons/hh_minigames/_shared/audio/chime.wav")
const YELLOW := Color(1.0, 0.86, 0.25)
const GOLD := Color(1.0, 0.72, 0.25)
const INK := Color(0.08, 0.06, 0.1)
## The three rules, with the colour of the HUD bar each one maps to.
const RULES := [
	[Color(0.3, 0.85, 0.35), "PLAY GAMES AT WORK", "Every minute fills your SLACK meter. Hit the day's quota."],
	[Color(0.95, 0.25, 0.2), "DON'T GET CAUGHT", "Boss near? ALT-TAB to a spreadsheet (your game waits). Seen playing = suspicion. 3 strikes = fired."],
	[Color(1.0, 0.45, 0.8), "SHIP YOUR GAME FRIDAY", "Beat desk games for pieces. Good reviews = promoted a floor."],
]
## Seconds per camera shot, and the white-gold dip across each cut.
const SHOT_SECS := 8.5
const DIP := 0.9
## The shots after the opening one on the picture: [from, look at, to, look
## at, fov]. Through the window with Dale against the sun; a crane over the
## room from the door; a dolly past the main desk.
const SHOTS := [
	[Vector3(-1.05, 1.5, 1.0), Vector3(-6.5, 1.5, -1.5), Vector3(-1.25, 1.42, -0.3), Vector3(-6.5, 1.45, -1.0), 50.0],
	[Vector3(2.95, 2.2, 3.55), Vector3(-1.6, 0.75, -1.9), Vector3(2.2, 1.65, 2.45), Vector3(-1.9, 0.9, -1.2), 62.0],
	[Vector3(1.15, 1.18, -0.95), Vector3(0.0, 1.0, -2.6), Vector3(-0.95, 1.1, -1.05), Vector3(0.05, 1.0, -2.6), 46.0],
]
const ITEM_H := 96.0

var office: Node
var busy: Node
## "attract" (logo + PRESS START), "menu", or "how" (the how-to-play page).
var state := "attract"
var _go: Button
var _how: Button
var _options: Button
var _items: Array[Button] = []
var _focus := 0
var _demo: Control
var _records: Label
var _controls: Label
var _sound_hint: Label
var _waiting_menu := false
var _t := 0.0
var _k := 0.0
var _shot := -1
var _shot_t := 0.0
var _world_mode := SubViewport.UPDATE_ALWAYS
var _live := false
var _stick_wait := 0.0

var _cine: SubViewportContainer
var _vp: SubViewport
var _cam: Camera3D
var _post: ShaderMaterial
var _dust: CPUParticles3D
var _bars: Array[ColorRect] = []
var _halo: TextureRect
var _shade: TextureRect
var _logo: Label
var _logo_mat: ShaderMaterial
var _tag: Label
var _press: Label
var _menu: Control
var _blade: Blade
var _hint: Label
var _card: PanelContainer
var _card_name: Label
var _prompts: Label
var _studio: Label
var _page: Control
var _page_panel: PanelContainer
var _page_box: BoxContainer
var _side: VBoxContainer
var _back: Button
var _rule_texts: Array[Label] = []
var _tease: Label
var _sfx: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "Effects"
	add_child(_sfx)
	# The camera picture (filled in by _build_cine once the office exists).
	_cine = SubViewportContainer.new()
	_cine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cine.stretch = true
	_cine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = ShaderMaterial.new()
	_post.shader = POST
	_post.set_shader_parameter("flash", 0.0)
	_cine.material = _post
	add_child(_cine)
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0.0, 0.0, 0.0, 0.92)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		_bars.append(bar)
	# The logo, its halo and the tagline.
	# Shade behind the menu so it reads over the bright room (left sideways,
	# along the bottom upright).
	_shade = TextureRect.new()
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_halo = TextureRect.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.72, 0.35, 0.55), Color(1.0, 0.5, 0.2, 0.18), Color(1.0, 0.4, 0.15, 0.0)])
	var halo_tex := GradientTexture2D.new()
	halo_tex.gradient = grad
	halo_tex.fill = GradientTexture2D.FILL_RADIAL
	halo_tex.fill_from = Vector2(0.5, 0.5)
	halo_tex.fill_to = Vector2(1.0, 0.5)
	halo_tex.width = 128
	halo_tex.height = 64
	_halo.texture = halo_tex
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.stretch_mode = TextureRect.STRETCH_SCALE
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halo.material = add_mat
	add_child(_halo)
	_logo = _text("LOOK BUSY", LOGO_FONT, 120, Color.WHITE, 14, Color(0.28, 0.1, 0.02))
	_logo.add_theme_color_override("font_shadow_color", Color(0.1, 0.02, 0.0, 0.6))
	_logo.add_theme_constant_override("shadow_offset_x", 0)
	_logo.add_theme_constant_override("shadow_offset_y", 8)
	_logo.add_theme_constant_override("shadow_outline_size", 18)
	_logo_mat = ShaderMaterial.new()
	_logo_mat.shader = LOGO_SHADER
	_logo.material = _logo_mat
	add_child(_logo)
	var spaced := FontVariation.new()
	spaced.base_font = BODY_FONT
	spaced.spacing_glyph = 5
	_tag = _text("A GAME ABOUT PLAYING GAMES AT WORK", spaced, 20, Color(1, 0.96, 0.88), 6, Color(0.15, 0.05, 0.05, 0.8))
	add_child(_tag)
	_press = _text("PRESS START", spaced, 26, Color.WHITE, 8, Color(0.2, 0.08, 0.02, 0.9))
	add_child(_press)
	_sound_hint = _text("TAP ANYWHERE FOR MUSIC", BODY_FONT, 16, YELLOW, 5, Color(0, 0, 0, 0.8))
	_sound_hint.visible = false
	add_child(_sound_hint)
	_studio = _text("HUMBLE HOUSE GAMES", spaced, 14, Color(1, 1, 1, 0.55), 0, Color.BLACK)
	add_child(_studio)
	_prompts = _text("", BODY_FONT, 17, Color(1, 1, 1, 0.85), 4, Color(0, 0, 0, 0.6))
	add_child(_prompts)
	_build_menu()
	_build_card()
	_build_page()
	get_viewport().size_changed.connect(_layout)


func _build_menu() -> void:
	_menu = Control.new()
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu)
	_blade = Blade.new()
	_blade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(_blade)
	_go = _item("CLOCK IN", _clock_in)
	_how = _item("HOW TO PLAY", _open_how)
	_options = _item("OPTIONS", _open_options)
	_hint = _text("", BODY_FONT, 19, Color(1, 0.95, 0.85), 5, Color(0, 0, 0, 0.7))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu.add_child(_hint)


func _item(words: String, act: Callable) -> Button:
	var b := Button.new()
	b.text = words
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", MENU_FONT)
	b.add_theme_font_size_override("font_size", 44)
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var e := StyleBoxEmpty.new()
		e.content_margin_left = 34
		b.add_theme_stylebox_override(st, e)
	var i := _items.size()
	b.pressed.connect(func() -> void:
		_set_focus(i, false)
		_play(CHIME, -8.0)
		act.call())
	b.mouse_entered.connect(func() -> void:
		if state == "menu":
			_set_focus(i))
	_menu.add_child(b)
	_items.append(b)
	return b


## Your records, like a profile card in the corner.
func _build_card() -> void:
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", _glass(Color(0.06, 0.04, 0.1, 0.62), Color(1.0, 0.75, 0.35, 0.55), 10))
	add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_card.add_child(row)
	var badge := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = GOLD
	bs.set_corner_radius_all(8)
	bs.border_color = Color(1, 0.95, 0.8)
	bs.set_border_width_all(2)
	badge.add_theme_stylebox_override("panel", bs)
	badge.custom_minimum_size = Vector2(64, 64)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var star := _text("★", BODY_FONT, 34, INK, 0, Color.BLACK)
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(star)
	row.add_child(badge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	_card_name = _text("NEW HIRE", MENU_FONT, 22, GOLD, 0, Color.BLACK)
	col.add_child(_card_name)
	_records = _text("", BODY_FONT, 16, Color(1, 1, 1, 0.9), 0, Color.BLACK)
	col.add_child(_records)


## HOW TO PLAY: the cartoon and the three rules on a glass panel.
func _build_page() -> void:
	_page = Control.new()
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_page.visible = false
	add_child(_page)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(dim)
	_page_panel = PanelContainer.new()
	_page_panel.add_theme_stylebox_override("panel", _glass(Color(0.05, 0.04, 0.09, 0.86), Color(1.0, 0.75, 0.35, 0.7), 14))
	_page.add_child(_page_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_page_panel.add_child(col)
	var head := _text("HOW TO PLAY", MENU_FONT, 34, GOLD, 6, Color(0, 0, 0, 0.6))
	col.add_child(head)
	_page_box = BoxContainer.new()
	_page_box.add_theme_constant_override("separation", 20)
	_page_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_page_box)
	_demo = BusyDemo.new()
	_demo.office = office
	_demo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_demo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(_demo)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 14)
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.alignment = BoxContainer.ALIGNMENT_CENTER
	_page_box.add_child(_side)
	for i in RULES.size():
		_side.add_child(_rule(i))
	_tease = _text("Get promoted, go up a floor. Nobody has seen the top one.", BODY_FONT, 16, Color(1, 1, 1, 0.65), 0, Color.BLACK)
	_tease.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_side.add_child(_tease)
	_controls = _text("", BODY_FONT, 15, Color(1, 0.9, 0.7, 0.85), 0, Color.BLACK)
	_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_side.add_child(_controls)
	_back = Button.new()
	_back.text = "BACK"
	_back.focus_mode = Control.FOCUS_NONE
	_back.custom_minimum_size = Vector2(220, 88)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_END
	_back.add_theme_font_override("font", MENU_FONT)
	_back.add_theme_font_size_override("font_size", 28)
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		_back.add_theme_color_override(st, INK)
	_back.add_theme_stylebox_override("normal", _glass(GOLD, Color(1, 0.95, 0.8), 10))
	_back.add_theme_stylebox_override("hover", _glass(GOLD.lightened(0.15), Color(1, 0.95, 0.8), 10))
	_back.add_theme_stylebox_override("pressed", _glass(GOLD.darkened(0.2), Color(1, 0.95, 0.8), 10))
	_back.pressed.connect(_close_how)
	col.add_child(_back)


func open() -> void:
	_build_cine()
	_refresh()
	visible = true
	get_tree().paused = true
	if office:
		office.release_for_overlay()
	_go_live(true)
	if state == "how":
		_page.visible = true
		_demo.go_live(true)
		_pause_cine(true)
	_layout()


func close() -> void:
	visible = false
	_page.visible = false
	if state == "how":
		state = "menu"
	_demo.go_live(false)
	_go_live(false)
	_waiting_menu = false
	get_tree().paused = false


func _clock_in() -> void:
	close()
	_flash_out()
	clocked_in.emit()


## A white-gold flash over the office as you clock in, fading on its own.
func _flash_out() -> void:
	if get_parent() == null:
		return
	var f := ColorRect.new()
	f.color = Color(1.0, 0.9, 0.72, 0.85)
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_callback(f.queue_free)


## OPTIONS: the office's pause menu; back here when it closes.
func _open_options() -> void:
	if office == null:
		return
	visible = false
	_go_live(false)
	get_tree().paused = false
	_waiting_menu = true
	office._open_menu(office._pad)


func _open_how() -> void:
	state = "how"
	_demo.office = office
	_demo.reset()
	_page.visible = true
	_page.modulate.a = 0.0
	create_tween().tween_property(_page, "modulate:a", 1.0, 0.25)
	_demo.go_live(true)
	_pause_cine(true)
	_layout()


func _close_how() -> void:
	if state != "how":
		return
	_play(CLICK, -6.0)
	_demo.go_live(false)
	_pause_cine(false)
	_page.visible = false
	state = "menu"
	_set_focus(1, false)


func _to_menu() -> void:
	if state != "attract":
		return
	state = "menu"
	_play(CHIME, -6.0)
	_post.set_shader_parameter("flash", 0.6)
	_set_focus(0, false)


func _process(delta: float) -> void:
	if _waiting_menu:
		if busy and not busy.enabled:
			_waiting_menu = false
		elif office and office._menu and not office._menu.visible:
			_waiting_menu = false
			open()
		return
	if not visible:
		return
	_t += delta
	_stick_wait = maxf(0.0, _stick_wait - delta)
	_k = move_toward(_k, 0.0 if state == "attract" else 1.0, delta / 0.55)
	_tick_camera(delta)
	_place()
	var music: Node = office.get("_hub_music") if office else null
	_sound_hint.visible = OS.has_feature("web") and music != null and not music.started and state == "attract"
	# The logo eases in, then breathes; the glint crosses every few seconds.
	var reveal := clampf((_t - 0.5) / 1.2, 0.0, 1.0)
	reveal = 1.0 - pow(1.0 - reveal, 3.0)
	_logo.modulate.a = reveal
	_tag.modulate.a = clampf((_t - 1.3) / 0.8, 0.0, 1.0)
	_halo.modulate.a = reveal * (0.75 + 0.25 * sin(_t * 1.4))
	var sweep := fmod(_t - 1.2, 4.5) / 1.1
	_logo_mat.set_shader_parameter("glint", lerpf(-0.3, 1.3, sweep) if sweep >= 0.0 and sweep <= 1.0 else -1.0)
	_logo.pivot_offset = _logo.size * 0.5
	var s := lerpf(1.18, 1.0, reveal) * (1.0 + sin(_t * 1.1) * 0.008)
	_logo.scale = Vector2(s, s) * lerpf(1.0, _menu_scale(), _k)
	_press.modulate.a = clampf((_t - 2.0) / 0.6, 0.0, 1.0) * (0.55 + 0.45 * sin(_t * 3.2)) * (1.0 - _k)
	_menu.modulate.a = _k
	_shade.modulate.a = _k
	_menu.visible = _k > 0.0
	_card.modulate.a = _k
	_card.visible = _k > 0.0
	_blade.tick(delta)
	var fl: float = _post.get_shader_parameter("flash")
	_post.set_shader_parameter("flash", move_toward(fl, _dip(), delta * 2.5) if fl > _dip() else _dip())
	_prompts.text = _prompt_text()


## The pad, the arrows, Enter and Esc. Taps and clicks go through the buttons.
func _input(event: InputEvent) -> void:
	if not visible or _waiting_menu:
		return
	var dir := 0
	var ok := false
	var back := false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_UP, KEY_W:
				dir = -1
			KEY_DOWN, KEY_S:
				dir = 1
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				ok = true
			KEY_ESCAPE, KEY_BACKSPACE:
				back = true
			_:
				ok = state == "attract"
	elif event is InputEventJoypadButton and event.pressed:
		if office:
			office._pad = true
		match event.button_index:
			JOY_BUTTON_DPAD_UP:
				dir = -1
			JOY_BUTTON_DPAD_DOWN:
				dir = 1
			JOY_BUTTON_A, JOY_BUTTON_START:
				ok = true
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				back = true
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		if absf(event.axis_value) > 0.6 and _stick_wait <= 0.0:
			dir = signi(int(signf(event.axis_value)))
			_stick_wait = 0.28
		elif absf(event.axis_value) < 0.3:
			_stick_wait = 0.0
	if dir == 0 and not ok and not back:
		return
	get_viewport().set_input_as_handled()
	match state:
		"attract":
			if ok:
				_to_menu()
		"menu":
			if dir != 0:
				_set_focus(wrapi(_focus + dir, 0, _items.size()))
			elif ok:
				_items[_focus].pressed.emit()
		"how":
			if ok or back:
				_close_how()


func _gui_input(event: InputEvent) -> void:
	# In attract mode a tap or click anywhere opens the menu.
	if state == "attract" and visible and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)):
		accept_event()
		_to_menu()


func _set_focus(i: int, sound := true) -> void:
	if sound and i != _focus:
		_play(CLICK, -10.0)
	_focus = i
	for k in _items.size():
		var on := k == _focus
		var c := INK if on else Color(1, 1, 1, 0.92)
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_items[k].add_theme_color_override(st, c)
		_items[k].add_theme_color_override("font_outline_color", Color(1, 0.95, 0.8, 0.0) if on else Color(0, 0, 0, 0.45))
	_hint.text = _hint_for(i)


func _hint_for(i: int) -> String:
	match i:
		0:
			if _go.text == "CLOCK IN":
				return "Monday, 9:00 AM. Play games at work. Don't get caught."
			var wd: Workday = busy.wd if busy else null
			return "Pick up where you left off: %s, floor %d." % [BusyLines.DAYS[clampi(wd.day, 0, 4)].capitalize(), wd.floor_i] if wd else "Pick up where you left off."
		1:
			return "Three rules and a cartoon. Thirty seconds."
		_:
			return "Volume, look speed, screens and controls."


func _prompt_text() -> String:
	var pad: bool = office != null and office._pad
	var touch: bool = office != null and (office._touch or DisplayServer.is_touchscreen_available()) and not pad
	match state:
		"attract":
			return ""
		"how":
			return "B  BACK" if pad else ("" if touch else "ESC  BACK")
		_:
			if pad:
				return "A  SELECT      ↑↓  MOVE"
			return "" if touch else "↑↓  MOVE      ENTER  SELECT"


## The camera: the opening shot on the picture, then the others in turn.
func _tick_camera(delta: float) -> void:
	if _cam == null or not _live or state == "how":
		return
	_shot_t += delta
	if _shot < 0 or _shot_t >= SHOT_SECS:
		_shot = (_shot + 1) % (SHOTS.size() + 1) if _shot >= 0 else 0
		_shot_t = 0.0
	var k := smoothstep(0.0, 1.0, _shot_t / SHOT_SECS)
	var spec := _shot_spec(_shot)
	var from: Vector3 = spec[0]
	var to: Vector3 = spec[2]
	var at: Vector3 = (spec[1] as Vector3).lerp(spec[3], k)
	var pos := from.lerp(to, k) + Vector3(sin(_t * 0.37), sin(_t * 0.53) * 0.6, 0.0) * 0.012
	_cam.fov = spec[4]
	_cam.look_at_from_position(pos, at)


## Shot i: 0 = the picture (framed to fill the screen, then pulling back).
func _shot_spec(i: int) -> Array:
	if i > 0:
		return SHOTS[i - 1]
	var at: Vector3 = office.SUNSET_PICTURE if office else Vector3.ZERO
	var canvas: Vector2 = office.SUNSET_CANVAS if office else Vector2.ONE
	var view := size if size.x > 0.0 else Vector2(1280, 720)
	var fov := 42.0
	var tv := tan(deg_to_rad(fov) * 0.5)
	var fill := maxf(canvas.y * 0.5 / tv, canvas.x * 0.5 / (tv * view.x / view.y)) * 0.88
	return [at + Vector3(0.02, 0.0, -fill), at, at + Vector3(-0.18, -0.06, -fill * 2.6 - 0.3), at + Vector3(-0.1, -0.08, 0), fov]


## The white-gold dip around each cut.
func _dip() -> float:
	if _shot < 0:
		return 0.0
	var to_end := SHOT_SECS - _shot_t
	var since := _shot_t
	var d := 0.0
	if to_end < DIP * 0.5:
		d = 1.0 - to_end / (DIP * 0.5)
	elif since < DIP * 0.5:
		d = 1.0 - since / (DIP * 0.5)
	return smoothstep(0.0, 1.0, d) * 0.85 if _t > 1.0 or _shot > 0 else 0.0


func _build_cine() -> bool:
	if _vp:
		return true
	if office == null or office._world_vp == null:
		return false
	_vp = SubViewport.new()
	_vp.world_3d = office._world_vp.world_3d
	_vp.gui_disable_input = true
	_vp.audio_listener_enable_3d = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_cine.add_child(_vp)
	_cam = Camera3D.new()
	_cam.cull_mask = office.LAYER_WORLD
	_cam.near = 0.04
	_cam.far = 40.0
	_cam.current = true
	_vp.add_child(_cam)
	# Dust turning in the sunbeam.
	_dust = CPUParticles3D.new()
	_dust.process_mode = Node.PROCESS_MODE_ALWAYS
	_dust.amount = 70
	_dust.lifetime = 7.0
	_dust.preprocess = 7.0
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(1.3, 0.7, 1.2)
	_dust.position = Vector3(-2.2, 1.35, -0.5)
	_dust.direction = Vector3(0.3, 0.2, 0.1)
	_dust.spread = 180.0
	_dust.gravity = Vector3(0, -0.01, 0)
	_dust.initial_velocity_min = 0.01
	_dust.initial_velocity_max = 0.05
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.2
	var mote := QuadMesh.new()
	mote.size = Vector2(0.01, 0.01)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mm.albedo_color = Color(1.0, 0.88, 0.6, 0.75)
	mote.material = mm
	_dust.mesh = mote
	_dust.layers = office.LAYER_WORLD
	_dust.emitting = false
	_dust.visible = false
	_vp.add_child(_dust)
	return true


## Start (or stop) filming the office. The office's own view is hidden under
## the title, so it stops drawing while this one runs.
func _go_live(on: bool) -> void:
	if on == _live or _vp == null:
		return
	_live = on
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	_dust.emitting = on
	_dust.visible = on
	var wv: SubViewport = office._world_vp
	if on:
		_world_mode = wv.render_target_update_mode
		wv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		wv.render_target_update_mode = _world_mode


## Freeze the camera picture under the how-to page (the cartoon films instead).
func _pause_cine(on: bool) -> void:
	if _vp and _live:
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if on else SubViewport.UPDATE_ALWAYS


## Records, the button's words and the controls line for this run and device.
func _refresh() -> void:
	if busy == null:
		return
	var wd: Workday = busy.wd
	var fresh: bool = wd.runs <= 1 and wd.week <= 1 and wd.day == 0 and wd.minutes <= 0.0
	_go.text = "CLOCK IN" if fresh else "CLOCK BACK IN"
	var rec: Array[String] = []
	if office and office._ladder:
		var st: LadderState = office._ladder.state
		var tot := DeskGoals.total(DaleStory.read_stats(), st.best, Array(st.beaten))
		if tot.x > 0:
			rec.append("DESK STARS  %d/%d ★" % [tot.x, tot.y])
	if wd.best_slack > Workday.MORNING_COFFEE:
		rec.append("BEST DAY  %s slacked" % Workday.hours_text(wd.best_slack))
	if wd.best_floor > 1:
		rec.append("BEST FLOOR  %d" % wd.best_floor)
	if wd.runs > 1:
		rec.append("FIRED  %d time%s" % [wd.runs - 1, "" if wd.runs == 2 else "s"])
	_card_name.text = "NEW HIRE" if fresh and rec.is_empty() else "EMPLOYEE FILE"
	_records.text = "\n".join(rec) if not rec.is_empty() else "First day on the job."
	var pad: bool = office != null and office._pad
	var touch: bool = office != null and (office._touch or DisplayServer.is_touchscreen_available()) and not pad
	if pad:
		_controls.text = "STICKS: walk + look.  A: sit at a screen.  Y: alt-tab."
		_press.text = "PRESS START"
	elif touch:
		_controls.text = "Stick: walk.  Tap a screen to sit.  Alt-tab: top right."
		_press.text = "TAP TO START"
	else:
		_controls.text = "WASD + mouse: walk.  Click a screen to sit.  Tab: alt-tab."
		_press.text = "PRESS ENTER"
	_set_focus(_focus, false)


func _wide() -> bool:
	var v := get_viewport_rect().size
	return v.x > v.y


func _menu_scale() -> float:
	return 0.58 if _wide() else 0.72


## Sizes that only change with the screen.
func _layout() -> void:
	var view := get_viewport_rect().size
	var wide := view.x > view.y
	var inset: Vector4 = office._inset if office else Vector4.ZERO
	_logo.add_theme_font_size_override("font_size", 128 if wide else 104)
	_logo.size = _logo.get_minimum_size()
	_logo_mat.set_shader_parameter("height", _logo.size.y)
	_logo_mat.set_shader_parameter("width", _logo.size.x)
	_tag.add_theme_font_size_override("font_size", 20 if wide else 17)
	_tag.size = _tag.get_minimum_size()
	var mw := clampf(view.x * (0.42 if wide else 0.86), 420.0, 620.0)
	for b in _items:
		b.size = Vector2(mw, ITEM_H)
		b.add_theme_font_size_override("font_size", 44 if wide else 42)
	_hint.size = Vector2(mw, 0)
	_hint.custom_minimum_size.x = mw
	_card.reset_size()
	var sg := Gradient.new()
	sg.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	sg.colors = PackedColorArray([Color(0.04, 0.02, 0.06, 0.72), Color(0.04, 0.02, 0.06, 0.4), Color(0.04, 0.02, 0.06, 0.0)])
	var st := GradientTexture2D.new()
	st.gradient = sg
	st.width = 64
	st.height = 64
	st.fill_from = Vector2(0, 0) if wide else Vector2(0, 1)
	st.fill_to = Vector2(1, 0) if wide else Vector2(0, 0)
	_shade.texture = st
	_shade.position = Vector2.ZERO if wide else Vector2(0, view.y * 0.42)
	_shade.size = Vector2(view.x * 0.62, view.y) if wide else Vector2(view.x, view.y * 0.58)
	# The how-to page: side by side sideways, stacked upright.
	_page_box.vertical = not wide
	_page_panel.position = Vector2(24.0 + inset.x, 24.0 + inset.y)
	var room := view - _page_panel.position - Vector2(24.0 + inset.z, 24.0 + inset.w)
	# Wrapped text needs a width to know its height.
	var side_w := room.x * 0.4 if wide else room.x - 40.0
	_side.custom_minimum_size.x = side_w
	for l in _rule_texts:
		l.custom_minimum_size.x = side_w - 64.0
	for l in [_tease, _controls]:
		l.custom_minimum_size.x = side_w
	_demo.custom_minimum_size = Vector2(room.x * 0.5, room.y - 200.0) if wide else Vector2(0, 330)
	_page_panel.reset_size()
	_page_panel.size = room
	for l in _rule_texts:
		l.add_theme_font_size_override("font_size", 16 if wide else 17)
	_place()


## Everything that moves between the attract screen and the menu (_k 0..1).
func _place() -> void:
	var view := get_viewport_rect().size
	var wide := view.x > view.y
	var inset: Vector4 = office._inset if office else Vector4.ZERO
	var k := smoothstep(0.0, 1.0, _k)
	# Letterbox: deep for the attract loop, thinner with the menu up.
	var bar_h := lerpf(view.y * (0.1 if wide else 0.07), view.y * (0.065 if wide else 0.05), k)
	_bars[0].position = Vector2.ZERO
	_bars[0].size = Vector2(view.x, bar_h + inset.y * 0.5)
	_bars[1].position = Vector2(0, view.y - bar_h - inset.w * 0.5)
	_bars[1].size = Vector2(view.x, bar_h + inset.w * 0.5)
	# The logo: centred, then up and to the left (top centre upright).
	var left_edge := view.x * 0.07 + inset.x
	var a := Vector2(view.x * 0.5, view.y * (0.4 if wide else 0.33))
	var b := Vector2(left_edge + _logo.size.x * _menu_scale() * 0.5, view.y * 0.22) if wide else Vector2(view.x * 0.5, view.y * 0.15 + inset.y)
	var c := a.lerp(b, k)
	_logo.position = c - _logo.size * 0.5
	_halo.size = Vector2(_logo.size.x * 1.7, _logo.size.y * 2.4) * _logo.scale.x
	_halo.position = c - _halo.size * 0.5
	# The tagline under it, shrinking with it (lined up on the left sideways).
	var ts := lerpf(1.0, 0.78, k)
	_tag.scale = Vector2(ts, ts)
	var tag_y := c.y + _logo.size.y * 0.42 * _logo.scale.y
	var tag_x := c.x - _tag.size.x * ts * 0.5
	if wide:
		tag_x = lerpf(tag_x, left_edge + 14.0, k)
	_tag.position = Vector2(tag_x, tag_y)
	_press.size = _press.get_minimum_size()
	_press.position = Vector2(view.x * 0.5 - _press.size.x * 0.5, view.y * (0.74 if wide else 0.72))
	_sound_hint.size = _sound_hint.get_minimum_size()
	_sound_hint.position = Vector2(view.x * 0.5 - _sound_hint.size.x * 0.5, _press.position.y + 52)
	# The menu slides in from the left.
	var mw: float = _items[0].size.x
	var top := view.y * 0.44 if wide else view.y * 0.6
	var left := view.x * 0.07 + inset.x
	if not wide:
		left = (view.x - mw) * 0.5
	var slide := (1.0 - k) * -80.0
	for i in _items.size():
		_items[i].position = Vector2(left + slide * (1.0 + i * 0.4), top + i * (ITEM_H + 6.0))
	_blade.target = Rect2(_items[_focus].position, _items[_focus].size)
	_hint.position = Vector2(left + 34.0 + slide, top + _items.size() * (ITEM_H + 6.0) + 10.0)
	_hint.size.x = mw - 34.0
	# The records card: top right sideways, under the tagline upright.
	_card.reset_size()
	if wide:
		_card.position = Vector2(view.x - _card.size.x - view.x * 0.05 - inset.z, bar_h + 26.0 + inset.y * 0.5)
	else:
		_card.position = Vector2((view.x - _card.size.x) * 0.5, tag_y + 56.0)
	_studio.size = _studio.get_minimum_size()
	_studio.position = Vector2(view.x * 0.05 + inset.x, view.y - bar_h * 0.5 - _studio.size.y * 0.5 - inset.w * 0.5)
	_prompts.size = _prompts.get_minimum_size()
	_prompts.position = Vector2(view.x - _prompts.size.x - view.x * 0.05 - inset.z, view.y - bar_h * 0.5 - _prompts.size.y * 0.5 - inset.w * 0.5)
	_studio.visible = wide or _prompts.text == ""


func _rule(i: int) -> Control:
	var spec: Array = RULES[i]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var chip := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = spec[0]
	st.set_corner_radius_all(24)
	chip.add_theme_stylebox_override("panel", st)
	chip.custom_minimum_size = Vector2(48, 48)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n := _text(str(i + 1), MENU_FONT, 26, INK, 0, Color.BLACK)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(n)
	row.add_child(chip)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_text(spec[1], MENU_FONT, 22, spec[0], 0, Color.BLACK))
	var t := _text(spec[2], BODY_FONT, 16, Color(1, 1, 1, 0.9), 0, Color.BLACK)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	_rule_texts.append(t)
	row.add_child(col)
	return row


func _text(words: String, font: Font, size: int, color: Color, outline: int, outline_color: Color) -> Label:
	var l := Label.new()
	l.text = words
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", outline_color)
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Dark glass with a thin bright rim and a soft drop shadow.
func _glass(fill: Color, rim: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = rim
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 12
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


func _play(stream: AudioStream, db: float) -> void:
	_sfx.stream = stream
	_sfx.volume_db = db
	_sfx.play()


## The highlight behind the chosen menu item: a slanted bar of polished
## gold (bright sheen on top, deeper underneath) with a soft glow round it,
## gliding to whichever item you're on; a glint runs along it now and then.
class Blade:
	extends Control

	var target := Rect2()
	var _at := Rect2()
	var _t := 0.0

	func tick(delta: float) -> void:
		_t += delta
		if _at.size == Vector2.ZERO:
			_at = target
		var k := minf(1.0, delta * 14.0)
		_at = Rect2(_at.position.lerp(target.position, k), _at.size.lerp(target.size, k))
		queue_redraw()

	func _draw() -> void:
		if _at.size == Vector2.ZERO:
			return
		var r := _at.grow_individual(0, -6, 0, -6)
		var slant := r.size.y * 0.35
		var p := r.position
		var w := r.size.x
		var h := r.size.y
		# Glow.
		for g in [[14.0, 0.1], [7.0, 0.18]]:
			var e: float = g[0]
			draw_colored_polygon(PackedVector2Array([p + Vector2(slant - e, -e), p + Vector2(w + e, -e), p + Vector2(w - slant + e, h + e), p + Vector2(-e, h + e)]),
				Color(1.0, 0.6, 0.2, g[1]))
		# The bar: top light, bottom deep, a hard sheen across the upper half.
		var pts := PackedVector2Array([p + Vector2(slant, 0), p + Vector2(w, 0), p + Vector2(w - slant, h), p + Vector2(0, h)])
		draw_polygon(pts, PackedColorArray([Color(1.0, 0.93, 0.66), Color(1.0, 0.86, 0.5), Color(0.96, 0.52, 0.12), Color(0.98, 0.6, 0.16)]))
		var mid := h * 0.48
		draw_polygon(PackedVector2Array([p + Vector2(slant, 0), p + Vector2(w, 0), p + Vector2(w - slant * mid / h, mid), p + Vector2(slant - slant * mid / h, mid)]),
			PackedColorArray([Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.12)]))
		draw_polyline(PackedVector2Array([p + Vector2(slant, 0), p + Vector2(w, 0)]), Color(1, 1, 0.95, 0.9), 2.0)
		# The glint.
		var gx := fmod(_t * 0.6, 2.4) / 1.4
		var x := lerpf(slant, w - slant - 26.0, gx)
		if gx <= 1.0:
			draw_colored_polygon(PackedVector2Array([p + Vector2(x + slant, 0), p + Vector2(x + slant + 26, 0), p + Vector2(x + 26, h), p + Vector2(x, h)]),
				Color(1, 1, 1, 0.35))


## The cartoon, shot live in the real office: a camera up in the corner by
## the door films a stand-in you at your desk (Pong on the screen) while a
## stand-in Marge walks in behind you. The tree is paused while the title is
## up, so this class moves everything itself. The HUD bars, captions, the
## STRIKE stamp and the shipped game are drawn on top in a 600x360 design box,
## scaled to fit. Every other loop you're too slow and get a strike, so both
## outcomes are shown. Without an office (or before go_live) it falls back to
## the flat drawn side view.
class BusyDemo:
	extends Control

	const W := 600.0
	const H := 360.0
	const LOOP := 13.0
	const DOOR_X := 75.0
	const STOP_X := 262.0
	const FONT := preload("res://addons/hh_minigames/_shared/fonts/press_start_2p.ttf")
	const SKIN := Color(0.92, 0.74, 0.6)
	const BOSS_SHIRT := Color(0.62, 0.18, 0.24)
	const MY_SHIRT := Color(0.2, 0.42, 0.75)
	## The shot: up in the corner by the door, looking past you at the screen.
	const CAM_POS := Vector3(1.0, 1.8, 0.3)
	const CAM_AT := Vector3(-0.35, 1.0, -2.2)
	const SHRINK := 2
	## You, seated a little left of the screen so the camera sees past you.
	const YOU_AT := Vector3(-0.3, 0.0, -1.6)
	const YOU_LOOK := {"skin": Color(0.92, 0.74, 0.6), "shirt": Color(0.2, 0.42, 0.75),
		"pants": Color(0.2, 0.22, 0.3), "hair": Color(0.25, 0.18, 0.12)}
	## The boss's walk in: doorway, across the carpet, stop just behind you.
	const WALK := [Vector2(1.8, 4.4), Vector2(0.3, 1.2), Vector2(-0.85, -0.75)]

	var t := 0.0
	var office: Node
	var _live := false
	var _box3d: SubViewportContainer
	var _vp: SubViewport
	var _cam: Camera3D
	var _you: Node3D
	var _you_head: Node3D
	var _boss3d: Node3D
	var _pc
	var _old_cover: Viewport
	var _screen_vp: SubViewport
	var _art: ScreenArt
	var _world_mode := SubViewport.UPDATE_ALWAYS
	var _k := 1.0
	var _off := Vector2.ZERO

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func reset() -> void:
		t = 0.0

	## Start (or stop) filming the office. Safe to call without an office.
	func go_live(on: bool) -> void:
		if on == _live:
			return
		if on and not _build():
			return
		_live = on
		_box3d.visible = on
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		_screen_vp.render_target_update_mode = _vp.render_target_update_mode
		_you.visible = on
		_boss3d.visible = false
		# The office's own view is hidden under the title: stop drawing it.
		var wv: SubViewport = office._world_vp
		if on:
			_world_mode = wv.render_target_update_mode
			wv.render_target_update_mode = SubViewport.UPDATE_DISABLED
		else:
			wv.render_target_update_mode = _world_mode
		if _pc:
			if on:
				_old_cover = _pc.cover
				_pc.set_cover(_screen_vp)
			elif _pc.cover == _screen_vp:
				_pc.set_cover(_old_cover)
		queue_redraw()

	func _build() -> bool:
		if _vp:
			return true
		if office == null or office._ladder == null or office._world_vp == null:
			return false
		_box3d = SubViewportContainer.new()
		_box3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_box3d.stretch = true
		_box3d.stretch_shrink = SHRINK
		_box3d.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_box3d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Under this control's own drawing, so the HUD sits on the picture.
		_box3d.show_behind_parent = true
		add_child(_box3d)
		_vp = SubViewport.new()
		_vp.world_3d = office._world_vp.world_3d
		_vp.gui_disable_input = true
		_vp.audio_listener_enable_3d = false
		_box3d.add_child(_vp)
		_cam = Camera3D.new()
		_cam.cull_mask = office.LAYER_WORLD
		_cam.fov = 52.0
		_cam.near = 0.05
		_cam.far = 30.0
		_vp.add_child(_cam)
		_cam.current = true
		_cam.position = CAM_POS
		_cam.look_at_from_position(CAM_POS, CAM_AT)
		# The main screen shows our Pong / spreadsheet instead of the paused game.
		_screen_vp = SubViewport.new()
		_screen_vp.size = Vector2i(640, 360)
		_screen_vp.disable_3d = true
		_screen_vp.gui_disable_input = true
		add_child(_screen_vp)
		_art = ScreenArt.new()
		_art.demo = self
		_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_screen_vp.add_child(_art)
		for pc in office._computers:
			if pc.view == office._game_vp:
				_pc = pc
		# Stand-ins ("boss_" ids keep them out of the talk list).
		var ladder: Node = office._ladder
		_you = ladder._person("office", "boss_title_you", YOU_AT, PI, YOU_LOOK, true)
		_you_head = ladder._people["boss_title_you"].head
		var fabric: Material = office._mat(Color(0.2, 0.22, 0.3))
		office._chair(_you, fabric)
		var b: Dictionary = BusyLines.BOSSES[0]
		_boss3d = ladder._person("office", "boss_title_boss", Vector3(WALK[0].x, 0, WALK[0].y), PI, b.look_body)
		_you.visible = false
		_boss3d.visible = false
		return true

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			t += delta
			if _live:
				_pose(fmod(t, LOOP), int(t / LOOP) % 2 == 1)
			queue_redraw()

	func _draw() -> void:
		_k = minf(size.x / W, size.y / H)
		_off = (size - Vector2(W, H) * _k) * 0.5
		draw_set_transform(_off, 0.0, Vector2(_k, _k))
		var lt := fmod(t, LOOP)
		var caught := int(t / LOOP) % 2 == 1
		_scene(lt, caught)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ------------------------------------------------------------ the 3D shot

	## Boss on the carpet at loop time lt: {pos (x, z), yaw, walking}, or {} when out.
	func _boss_at(lt: float) -> Dictionary:
		if lt < 3.6 or lt > 10.6:
			return {}
		var k := 0.0
		var walking := true
		if lt < 6.4:
			k = (lt - 3.6) / 2.8
		elif lt < 8.6:
			k = 1.0
			walking = false
		else:
			k = 1.0 - (lt - 8.6) / 2.0
		var a: Vector2 = WALK[0]
		var m: Vector2 = WALK[1]
		var e: Vector2 = WALK[2]
		var l1 := a.distance_to(m)
		var d := k * (l1 + m.distance_to(e))
		var pos := a.lerp(m, d / l1) if d < l1 else m.lerp(e, (d - l1) / m.distance_to(e))
		var dir := (m - a) if d < l1 else (e - m)
		if lt >= 8.6:
			dir = -dir
		var yaw := atan2(dir.x, dir.y)
		if not walking:
			# Stopped: she looks over your shoulder at the screen.
			var to := Vector2(0.0, -2.4) - e
			yaw = atan2(to.x, to.y)
		return {"pos": pos, "yaw": yaw, "walking": walking}

	func _pose(lt: float, caught: bool) -> void:
		var tabbed := _alt_tabbed(lt, caught)
		var strike := caught and lt >= 7.3 and lt < 10.0
		# A slow drift, like a camera on a shoulder; a jolt on the strike.
		var drift := Vector3(sin(t * 0.23) * 0.18, sin(t * 0.31) * 0.06, cos(t * 0.19) * 0.1)
		if strike:
			drift += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.02 * clampf(8.0 - lt, 0.0, 1.0)
		_cam.look_at_from_position(CAM_POS + drift, CAM_AT)
		# You: bopping along while you play; still and stiff once you alt-tab.
		var body: Node3D = _you.get_child(0)
		body.position.y = -office.Puppet.SIT_DROP + (absf(sin(lt * 6.0)) * 0.015 if not tabbed else 0.0)
		var bx := _boss_at(lt)
		var glance := 0.0
		if not bx.is_empty() and lt >= 4.2 and lt < 5.4:
			glance = -1.0
		_you_head.rotation.y = lerp_angle(_you_head.rotation.y, glance, 0.15)
		_boss3d.visible = not bx.is_empty()
		if _boss3d.visible:
			_boss3d.position = Vector3(bx.pos.x, 0.0, bx.pos.y)
			_boss3d.rotation.y = bx.yaw
			var bb: Node3D = _boss3d.get_child(0)
			bb.position.y = absf(sin(lt * 9.0)) * 0.04 if bx.walking else 0.0
			bb.rotation.z = sin(lt * 9.0) * 0.04 if bx.walking else 0.0
		_art.tabbed = tabbed
		_art.lt = lt
		_art.queue_redraw()

	## A world point in design-box coordinates (or null behind the camera).
	func _to_box(w: Vector3):
		if _cam.is_position_behind(w):
			return null
		var p := _cam.unproject_position(w) * float(SHRINK)
		return (p - _off) / _k

	## The marks the 3D can't draw: "!", speech, the ALT-TAB key, slack ticks.
	func _marks(lt: float, caught: bool, tabbed: bool) -> void:
		var bx := _boss_at(lt)
		if not bx.is_empty() and lt < 9.0 and (not caught or lt < 7.3):
			var at = _to_box(YOU_AT + Vector3(0, 1.62, 0))
			if at != null:
				var pop := 1.0 + 0.2 * maxf(0.0, sin(lt * 10.0))
				draw_string_outline(FONT, at - Vector2(10, 0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * pop), 8, Color.BLACK)
				draw_string(FONT, at - Vector2(10, 0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * pop), Color(1.0, 0.85, 0.2))
		if not bx.is_empty() and lt >= 6.4 and lt < 8.6:
			var at = _to_box(Vector3(bx.pos.x, 2.0, bx.pos.y))
			if at != null:
				at.x = clampf(at.x, 90.0, W - 90.0)
				at.y = maxf(at.y - 44.0, 70.0)
				_bubble(at, "A GAME?!" if caught else "...CARRY ON.", Color(1.0, 0.9, 0.9) if caught else Color(1, 1, 1))
		if _pc and (lt < 5.5 or lt > 10.6):
			var top = _to_box(_pc.screen.global_position + Vector3(0, 0.3, 0))
			if top != null:
				var f := fmod(lt, 1.2) / 1.2
				var p: Vector2 = top - Vector2(30, f * 34)
				draw_string_outline(FONT, p, "+" + Workday.hours_text(Workday.CLOSE_CALL), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 5, Color(0, 0, 0, 1.0 - f))
				draw_string(FONT, p, "+" + Workday.hours_text(Workday.CLOSE_CALL), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 1.0, 0.45, 1.0 - f))
		_key(lt, caught, Vector2(W - 150, 236))

	## The key you press: ALT-TAB.
	func _key(lt: float, caught: bool, at: Vector2) -> void:
		if caught or lt < 5.2 or lt >= 6.6:
			return
		var press := lt >= 5.5 and lt < 5.8
		var kr := Rect2(at + Vector2(0, 6 if press else 0), Vector2(120, 38))
		draw_rect(Rect2(kr.position + Vector2(4, 4), kr.size), Color(0, 0, 0, 0.5))
		draw_rect(kr, Color(1, 1, 1) if not press else Color(1.0, 0.86, 0.25))
		draw_rect(kr, Color(0.1, 0.1, 0.1), false, 3.0)
		draw_string(FONT, kr.position + Vector2(10, 26), "ALT-TAB", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.08, 0.08, 0.1))

	## What's on your monitor in the shot: Pong, or the spreadsheet.
	class ScreenArt:
		extends Control
		var demo
		var tabbed := false
		var lt := 0.0

		func _draw() -> void:
			var r := Rect2(Vector2.ZERO, size)
			draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(116, 80))
			var box := Rect2(0, 0, 116, 80)
			if tabbed:
				demo._sheet_on(self, box)
			else:
				demo._pong_on(self, box, lt)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if not tabbed:
				return
			# A title bar so it reads as a spreadsheet even small.
			draw_rect(Rect2(0, 0, r.size.x, 40), Color(0.06, 0.14, 0.6))
			draw_string(FONT, Vector2(12, 30), "Q3_TPS_FINAL.XLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1))

	# ------------------------------------------------------------ timeline

	## Boss x along the floor (or -1: not in the room).
	func _boss_x(lt: float) -> float:
		if lt < 3.6 or lt > 10.6:
			return -1.0
		if lt < 6.4:
			return lerpf(DOOR_X, STOP_X, (lt - 3.6) / 2.8)
		if lt < 8.6:
			return STOP_X
		return lerpf(STOP_X, DOOR_X, (lt - 8.6) / 2.0)

	func _door_open(lt: float) -> float:
		if lt < 3.3 or lt > 11.0:
			return 0.0
		if lt < 3.7:
			return (lt - 3.3) / 0.4
		if lt > 10.6:
			return 1.0 - (lt - 10.6) / 0.4
		return 1.0

	func _alt_tabbed(lt: float, caught: bool) -> bool:
		return not caught and lt >= 5.5 and lt < 10.4

	func _scene(lt: float, caught: bool) -> void:
		var bx := _boss_x(lt)
		var tabbed := _alt_tabbed(lt, caught)
		var strike := caught and lt >= 7.3 and lt < 10.0
		if _live:
			_marks(lt, caught, tabbed)
		else:
			_flat(lt, caught, tabbed, bx)
		_hud(lt, caught, tabbed, bx, strike)

	## The flat side view (no office to film).
	func _flat(lt: float, caught: bool, tabbed: bool, bx: float) -> void:
		# Room: wall, floor, clock (racing through the day), window.
		draw_rect(Rect2(0, 0, W, 292), Color(0.86, 0.79, 0.6))
		draw_rect(Rect2(0, 292, W, 68), Color(0.33, 0.4, 0.36))
		draw_rect(Rect2(0, 286, W, 6), Color(0.5, 0.38, 0.25))
		draw_rect(Rect2(420, 28, 130, 70), Color(0.62, 0.84, 0.98))
		draw_rect(Rect2(420, 28, 130, 70), Color(1, 1, 1), false, 4.0)
		draw_line(Vector2(485, 28), Vector2(485, 98), Color(1, 1, 1), 3.0)
		_clock(Vector2(320, 62), lt)
		# The door, swinging open toward you.
		var open := _door_open(lt)
		draw_rect(Rect2(DOOR_X - 48, 120, 96, 170), Color(0.25, 0.2, 0.16))
		draw_rect(Rect2(DOOR_X - 44, 124, 88 * (1.0 - 0.8 * open), 166), Color(0.58, 0.4, 0.24))
		draw_circle(Vector2(DOOR_X - 44 + 88 * (1.0 - 0.8 * open) - 10, 210), 4, Color(0.95, 0.8, 0.3))
		# The boss, behind you.
		if bx >= 0.0:
			_boss(bx, lt, caught)
		# Your desk: chair, you, the CRT.
		_desk(lt, tabbed, caught)

	func _hud(lt: float, caught: bool, tabbed: bool, bx: float, strike: bool) -> void:
		# Meters, top left (the same two bars as the real HUD).
		var slack := clampf(0.12 + minf(lt, 5.5) / 5.5 * 0.5 + (0.0 if lt < 10.6 else (lt - 10.6) * 0.1), 0.0, 1.0)
		var sus := 0.0
		if caught and lt >= 6.2:
			sus = clampf((lt - 6.2) / 1.1, 0.0, 1.0)
		if strike or (caught and lt >= 10.0):
			sus = 0.0
		_bar(Vector2(14, 14), "SLACKED", slack, Color(0.3, 0.85, 0.35))
		_bar(Vector2(14, 44), "SUSPICION", sus, Color(0.95, 0.25, 0.2))
		for i in 3:
			var r := Rect2(232 + i * 22, 46, 16, 16)
			draw_rect(r, Color(0.85, 0.15, 0.1) if caught and lt >= 7.3 and i == 0 else Color(0, 0, 0, 0.25))
			draw_rect(r, Color(0, 0, 0, 0.6), false, 2.0)
		# Danger at the edges while the boss is in the room and you're playing.
		if bx >= 0.0 and not tabbed and lt < 9.0:
			var a := 0.25 + 0.2 * sin(lt * 12.0)
			for e in 4:
				_edge(e, Color(1, 0.1, 0.05, a))
		if strike:
			draw_rect(Rect2(0, 0, W, H), Color(0.9, 0.05, 0.05, 0.25 if fmod(lt, 0.3) < 0.15 else 0.12))
			_stamp("STRIKE 1/3", Vector2(W * 0.5, 150), Color(0.95, 0.1, 0.08))
		# Your game ships: five pieces snap into a box.
		if lt >= 10.6:
			_ship(lt - 10.6)
		_caption(lt, caught)

	# ------------------------------------------------------------ pieces

	func _clock(c: Vector2, lt: float) -> void:
		draw_circle(c, 26, Color(0.98, 0.97, 0.92))
		draw_arc(c, 26, 0, TAU, 32, Color(0.2, 0.2, 0.2), 3.0)
		var m := lt / LOOP * TAU * 3.0
		draw_line(c, c + Vector2(sin(m), -cos(m)) * 20, Color(0.1, 0.1, 0.1), 2.0)
		draw_line(c, c + Vector2(sin(m / 12.0 + 0.3), -cos(m / 12.0 + 0.3)) * 13, Color(0.1, 0.1, 0.1), 3.0)

	func _boss(x: float, lt: float, caught: bool) -> void:
		var walking := (lt < 6.4 or lt > 8.6)
		var bob := absf(sin(lt * 9.0)) * 4.0 if walking else 0.0
		var y := 290.0 - bob
		var step := sin(lt * 9.0) * 8.0 if walking else 0.0
		draw_rect(Rect2(x - 14 + step, y - 52, 12, 52), Color(0.2, 0.18, 0.22))
		draw_rect(Rect2(x + 2 - step, y - 52, 12, 52), Color(0.2, 0.18, 0.22))
		draw_rect(Rect2(x - 20, y - 128, 40, 80), BOSS_SHIRT)
		draw_rect(Rect2(x - 3, y - 126, 6, 40), Color(0.2, 0.5, 0.9))
		draw_circle(Vector2(x, y - 146), 20, SKIN)
		draw_rect(Rect2(x - 22, y - 168, 44, 20), Color(0.55, 0.32, 0.16))
		draw_rect(Rect2(x - 22, y - 150, 8, 22), Color(0.55, 0.32, 0.16))
		var face := 1.0 if lt < 8.6 else -1.0
		draw_rect(Rect2(x + 2 * face - (0 if face > 0 else 14), y - 150, 14, 7), Color(0.1, 0.1, 0.1), false, 2.0)
		# She stops and looks.
		if lt >= 6.4 and lt < 8.6:
			if caught:
				_bubble(Vector2(x - 10, y - 200), "A GAME?!", Color(1.0, 0.9, 0.9))
			else:
				_bubble(Vector2(x - 10, y - 200), "...CARRY ON.", Color(1, 1, 1))

	func _desk(lt: float, tabbed: bool, caught: bool) -> void:
		# Chair and you, facing the screen (your back to the door).
		draw_rect(Rect2(318, 232, 50, 10), Color(0.15, 0.15, 0.18))
		draw_rect(Rect2(310, 176, 10, 64), Color(0.15, 0.15, 0.18))
		draw_rect(Rect2(338, 242, 8, 44), Color(0.15, 0.15, 0.18))
		var bob := sin(lt * 6.0) * 2.0 if not tabbed else 0.0
		draw_rect(Rect2(324, 178 + bob, 36, 58), MY_SHIRT)
		draw_rect(Rect2(352, 196 + bob, 40, 10), MY_SHIRT)
		draw_circle(Vector2(344, 160 + bob), 17, SKIN)
		draw_rect(Rect2(326, 142 + bob, 34, 10), Color(0.25, 0.18, 0.12))
		draw_rect(Rect2(330, 236, 36, 50), Color(0.2, 0.22, 0.3))
		# "!" over your head: you heard the door.
		var bx := _boss_x(lt)
		if bx >= 0.0 and lt < 9.0 and (not caught or lt < 7.3):
			var pop := 1.0 + 0.2 * maxf(0.0, sin(lt * 10.0))
			draw_string_outline(FONT, Vector2(338, 130), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * pop), 8, Color.BLACK)
			draw_string(FONT, Vector2(338, 130), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * pop), Color(1.0, 0.85, 0.2))
		# Desk and CRT.
		draw_rect(Rect2(372, 214, 200, 12), Color(0.55, 0.4, 0.26))
		draw_rect(Rect2(382, 226, 10, 62), Color(0.45, 0.32, 0.2))
		draw_rect(Rect2(552, 226, 10, 62), Color(0.45, 0.32, 0.2))
		draw_rect(Rect2(400, 112, 140, 100), Color(0.8, 0.76, 0.66))
		draw_rect(Rect2(400, 112, 140, 100), Color(0.4, 0.38, 0.33), false, 3.0)
		var scr := Rect2(412, 122, 116, 80)
		if tabbed:
			_sheet(scr)
		else:
			_pong(scr, lt)
		_key(lt, caught, Vector2(400, 240))

	func _pong(r: Rect2, lt: float) -> void:
		_pong_on(self, r, lt)
		# Slack ticking up.
		var f := fmod(lt, 1.2) / 1.2
		if lt < 5.5 or lt > 10.6:
			var p := r.position + Vector2(r.size.x * 0.5, -6 - f * 34)
			draw_string_outline(FONT, p - Vector2(30, 0), "+" + Workday.hours_text(Workday.CLOSE_CALL), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 5, Color(0, 0, 0, 1.0 - f))
			draw_string(FONT, p - Vector2(30, 0), "+" + Workday.hours_text(Workday.CLOSE_CALL), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 1.0, 0.45, 1.0 - f))

	func _sheet(r: Rect2) -> void:
		_sheet_on(self, r)

	func _pong_on(c: CanvasItem, r: Rect2, lt: float) -> void:
		c.draw_rect(r, Color(0.04, 0.05, 0.1))
		var px := fposmod(lt * 90.0, 2.0 * (r.size.x - 20))
		if px > r.size.x - 20:
			px = 2.0 * (r.size.x - 20) - px
		var py := fposmod(lt * 70.0, 2.0 * (r.size.y - 10))
		if py > r.size.y - 10:
			py = 2.0 * (r.size.y - 10) - py
		var ball := r.position + Vector2(10 + px, 5 + py)
		c.draw_rect(Rect2(ball - Vector2(3, 3), Vector2(6, 6)), Color(1, 1, 1))
		c.draw_rect(Rect2(r.position + Vector2(4, clampf(ball.y - r.position.y - 12, 0, r.size.y - 24)), Vector2(4, 24)), Color(0.4, 1.0, 0.6))
		c.draw_rect(Rect2(r.position + Vector2(r.size.x - 8, clampf(ball.y - r.position.y - 12, 0, r.size.y - 24)), Vector2(4, 24)), Color(1.0, 0.5, 0.8))

	func _sheet_on(c: CanvasItem, r: Rect2) -> void:
		c.draw_rect(r, Color(0.98, 0.98, 0.96))
		c.draw_rect(Rect2(r.position, Vector2(r.size.x, 10)), Color(0.06, 0.14, 0.6))
		for i in 6:
			var y := r.position.y + 14 + i * 11
			c.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.6, 0.7, 0.7), 1.0)
		for i in 4:
			var x := r.position.x + 4 + i * 28
			c.draw_line(Vector2(x, r.position.y + 10), Vector2(x, r.end.y), Color(0.6, 0.7, 0.7), 1.0)
		c.draw_rect(Rect2(r.position + Vector2(33, 26), Vector2(26, 10)), Color(1.0, 0.9, 0.3))
		c.draw_rect(Rect2(r.position + Vector2(61, 48), Vector2(26, 10)), Color(1.0, 0.9, 0.3))

	func _ship(st: float) -> void:
		var box := Rect2(150, 110, 300, 120)
		draw_rect(Rect2(box.position + Vector2(6, 6), box.size), Color(0, 0, 0, 0.5))
		draw_rect(box, Color(0.18, 0.08, 0.22))
		draw_rect(box, Color(1.0, 0.45, 0.8), false, 4.0)
		draw_string(FONT, box.position + Vector2(0, 28), "YOUR GAME", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 16, Color(1.0, 0.45, 0.8))
		var cols := [Color(0.95, 0.4, 0.4), Color(1.0, 0.8, 0.3), Color(0.4, 0.85, 0.5), Color(0.4, 0.7, 1.0), Color(0.8, 0.5, 1.0)]
		for i in 5:
			var r := Rect2(box.position + Vector2(24 + i * 52, 44), Vector2(44, 34))
			draw_rect(r, Color(1, 1, 1, 0.12), false, 2.0)
			var at := 0.15 + i * 0.25
			if st >= at:
				var drop := clampf((st - at) / 0.15, 0.0, 1.0)
				draw_rect(Rect2(r.position - Vector2(0, (1.0 - drop) * 30), r.size), cols[i])
		if st >= 1.6:
			draw_string(FONT, box.position + Vector2(0, 104), "PRESS: 8.5/10", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 14, Color(1.0, 0.86, 0.25))

	func _bar(p: Vector2, label: String, k: float, col: Color) -> void:
		var r := Rect2(p, Vector2(210, 22))
		draw_rect(r, Color(0.08, 0.08, 0.1, 0.85))
		draw_rect(Rect2(p, Vector2(210 * k, 22)), col)
		draw_rect(r, Color(1, 1, 1, 0.8), false, 2.0)
		draw_string(FONT, p + Vector2(6, 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1))

	func _edge(e: int, col: Color) -> void:
		var clear := Color(col.r, col.g, col.b, 0.0)
		var d := 36.0
		var pts: PackedVector2Array
		match e:
			0: pts = PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W - d, d), Vector2(d, d)])
			1: pts = PackedVector2Array([Vector2(W, 0), Vector2(W, H), Vector2(W - d, H - d), Vector2(W - d, d)])
			2: pts = PackedVector2Array([Vector2(W, H), Vector2(0, H), Vector2(d, H - d), Vector2(W - d, H - d)])
			_: pts = PackedVector2Array([Vector2(0, H), Vector2(0, 0), Vector2(d, d), Vector2(d, H - d)])
		draw_polygon(pts, PackedColorArray([col, col, clear, clear]))

	func _bubble(p: Vector2, text: String, fill: Color) -> void:
		var w := text.length() * 13.0 + 20.0
		var r := Rect2(p - Vector2(w * 0.5, 0), Vector2(w, 32))
		draw_rect(r, fill)
		draw_rect(r, Color(0.1, 0.1, 0.1), false, 3.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 31), p + Vector2(8, 31), p + Vector2(0, 44)]), fill)
		draw_string(FONT, r.position + Vector2(0, 22), text, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.08, 0.08, 0.1))

	func _stamp(text: String, c: Vector2, col: Color) -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var k := minf(size.x / W, size.y / H)
		var off := (size - Vector2(W, H) * k) * 0.5
		draw_set_transform(off + c * k, -0.12, Vector2(k, k))
		var r := Rect2(-170, -34, 340, 60)
		draw_rect(r, Color(1, 1, 1, 0.92))
		draw_rect(r, col, false, 6.0)
		draw_string(FONT, Vector2(-170, 10), text, HORIZONTAL_ALIGNMENT_CENTER, 340, 26, col)
		draw_set_transform(off, 0.0, Vector2(k, k))

	func _caption(lt: float, caught: bool) -> void:
		var text := "1. PLAY GAMES AT WORK"
		if lt >= 10.6:
			text = "3. SHIP YOUR OWN GAME FRIDAY"
		elif caught and lt >= 7.3:
			text = "3 STRIKES = FIRED"
		elif caught and lt >= 5.5:
			text = "TOO SLOW..."
		elif lt >= 5.5:
			text = "2. ALT-TAB. LOOK BUSY."
		elif lt >= 3.6:
			text = "...THE BOSS IS COMING"
		draw_rect(Rect2(0, H - 50, W, 50), Color(0, 0, 0, 0.7))
		draw_string_outline(FONT, Vector2(0, H - 17), text, HORIZONTAL_ALIGNMENT_CENTER, W, 20, 8, Color.BLACK)
		draw_string(FONT, Vector2(0, H - 17), text, HORIZONTAL_ALIGNMENT_CENTER, W, 20, Color(1, 1, 1))
