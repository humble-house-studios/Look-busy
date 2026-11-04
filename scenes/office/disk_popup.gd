extends Control
## Look Busy's full-screen reward pop-up for your game's pieces, drawn as
## floppy disks (scenes/office/floppy.gd):
##   - NEW DISK!: a piece you just earned, spinning rays behind it, where it
##     came from, whether it's a first find (it goes in the disk binder for
##     good, engine/disk_binder.gd) and the combos it clicks with;
##   - COMBO FOUND!: two disks that just made a combo in your build.
## Pop-ups queue up and wait for any other window (the busy notice, the pause
## menu, the title) to close. While one is up the office pauses, like
## busy_notice.gd; it runs PROCESS_MODE_ALWAYS. One 88 px button, so touch,
## mouse and the pad cursor all work.

const FONT := preload("res://fonts/press_start_2p.ttf")
const Floppy := preload("res://scenes/office/floppy.gd")
const GOLD := Color(1.0, 0.82, 0.35)
const PAPER := Color(0.93, 0.92, 0.96)
const MUTED := Color(0.72, 0.7, 0.8)

var office: Node
var _queue: Array = []
var _entry := {}
var _t := 0.0
var _was_paused := false
var _accent := GOLD

var _rays: Control
var _margin: MarginContainer
var _head: Label
var _sub: Label
var _disks: HBoxContainer
var _floppies: Array = []
var _name: Label
var _info: Label
var _ok: Button
var _cursor: Node
var _player: AudioStreamPlayer
var _player2: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.08, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_rays = Control.new()
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_rays)
	add_child(_rays)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)
	_head = _label(34, GOLD)
	col.add_child(_head)
	_sub = _label(15, MUTED)
	col.add_child(_sub)
	_disks = HBoxContainer.new()
	_disks.alignment = BoxContainer.ALIGNMENT_CENTER
	_disks.add_theme_constant_override("separation", 24)
	_disks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_disks)
	for i in 2:
		var f: Control = Floppy.new()
		_disks.add_child(f)
		_floppies.append(f)
	_name = _label(30, PAPER)
	col.add_child(_name)
	_info = _label(15, PAPER)
	_info.add_theme_constant_override("line_spacing", 12)
	col.add_child(_info)
	_ok = Button.new()
	_ok.text = "NICE!"
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.custom_minimum_size = Vector2(320, 88)
	_ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ok.add_theme_font_override("font", FONT)
	_ok.add_theme_font_size_override("font_size", 22)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_ok.add_theme_color_override(st, Color(0.1, 0.07, 0.03))
	_ok.add_theme_stylebox_override("normal", _box(GOLD))
	_ok.add_theme_stylebox_override("hover", _box(GOLD.lightened(0.15)))
	_ok.add_theme_stylebox_override("focus", _box(GOLD))
	_ok.add_theme_stylebox_override("pressed", _box(GOLD.darkened(0.2)))
	_ok.pressed.connect(_next)
	col.add_child(_ok)
	_player = AudioStreamPlayer.new()
	_player.bus = "Effects"
	add_child(_player)
	_player2 = AudioStreamPlayer.new()
	_player2.bus = "Effects"
	add_child(_player2)
	get_viewport().size_changed.connect(_layout)


## p: {kind, name, from}. first: never found before (it's in the binder now).
func add_disk(p: Dictionary, first: bool) -> void:
	_queue.append({"type": "disk", "kind": p.kind, "name": p.name, "from": p.get("from", ""), "first": first})


## A combo that just lit up in your build.
func add_combo(name: String) -> void:
	_queue.append({"type": "combo", "name": name})


## Anything showing or waiting.
func pending() -> bool:
	return visible or not _queue.is_empty()


func clear() -> void:
	_queue.clear()
	if visible:
		_close()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		var pop := clampf(_t / 0.25, 0.0, 1.0)
		for i in _floppies.size():
			var f: Control = _floppies[i]
			f.pivot_offset = f.size * 0.5
			f.rotation = sin(_t * 2.2 + i * 1.7) * 0.06 + (-0.1 if i == 0 else 0.1) * float(_entry.get("type", "") == "combo")
			f.scale = Vector2.ONE * lerpf(0.55, 1.0, ease(pop, 0.4))
		_rays.queue_redraw()
	elif not _queue.is_empty() and _can_show():
		_show(_queue.pop_front())


func _can_show() -> bool:
	if get_tree().paused or office == null:
		return false
	var busy: Node = office._busy
	if busy == null or not busy.enabled:
		return false
	if busy.notice and busy.notice.visible:
		return false
	if busy.title_screen and (busy.title_screen.visible or busy.title_screen._waiting_menu):
		return false
	return true


func _show(e: Dictionary) -> void:
	_entry = e
	_t = 0.0
	var gm: GameMaker = office._busy.gm
	if e.type == "disk":
		_accent = Floppy.kind_color(e.kind)
		_head.text = "NEW DISK!"
		_sub.text = "FROM " + source_name(e.from)
		_floppies[0].set_piece(e.kind, e.name)
		_floppies[1].visible = false
		_name.text = e.name
		var lines: Array[String] = []
		lines.append("FIRST FIND! IT'S IN YOUR BINDER FOR GOOD." if e.first else "BACK IN THIS WEEK'S KIT.")
		var kind_name: String = GameMaker.KIND_NAMES[e.kind]
		if gm.build.get(e.kind, "") == e.name:
			lines.append("IN YOUR %s DRIVE." % kind_name)
		else:
			lines.append("SWAP IT INTO THE %s DRIVE AT THE DEV KIT." % kind_name)
		var combos := DiskBinder.combos_with(e.name)
		if not combos.is_empty():
			lines.append("")
			lines.append("CLICKS WITH:")
			for c in combos.slice(0, 3):
				var have := true
				for n in c.others:
					have = have and gm.has(n)
				lines.append("+ %s = %s %s%s" % [" + ".join(c.others), c.name, c.text, "  (GOT IT!)" if have else ""])
		_info.text = "\n".join(lines)
		_play(preload("res://audio/coin.wav"), -2.0)
		if e.first:
			_player2.stream = preload("res://audio/fanfare.wav")
			_player2.volume_db = -6.0
			_player2.play()
	else:
		var c := DiskBinder.combo(e.name)
		var needs: Array = c.get("needs", [])
		_accent = GOLD
		_head.text = "COMBO FOUND!"
		_sub.text = "%s + %s" % [needs[0] if needs.size() > 0 else "", needs[1] if needs.size() > 1 else ""]
		for i in 2:
			var n: String = needs[i] if i < needs.size() else ""
			_floppies[i].visible = n != ""
			_floppies[i].set_piece(GameMaker.kind_of(n), n)
		_name.text = e.name
		_info.text = "SCORE %s\nYOUR GAME: %s\nBUILD SCORE: %d" % [DiskBinder.combo_text(c), gm.title(), int(gm.score().score)]
		_play(preload("res://audio/jackpot.wav"), -4.0)
	_name.add_theme_color_override("font_color", GOLD if e.type == "combo" else PAPER)
	if not visible:
		_was_paused = get_tree().paused
	visible = true
	get_tree().paused = true
	office.release_for_overlay()
	_layout()
	if _cursor == null:
		_cursor = preload("res://scenes/pad_cursor.gd").new()
		add_child(_cursor)
	_cursor.focus.call_deferred(_ok)
	_cursor.active = office._pad


func _next() -> void:
	if not _queue.is_empty():
		_show(_queue.pop_front())
		return
	_close()


func _close() -> void:
	visible = false
	get_tree().paused = _was_paused
	if _cursor:
		_cursor.queue_free()
		_cursor = null
	if office and office._busy and office._busy._kit:
		office._busy._kit.refresh()


## Where a piece came from, in words.
static func source_name(from: String) -> String:
	if from == "spreadsheet":
		return "FAKE WORK (THE SPREADSHEET)"
	if DeskGoals.has(from):
		return str(DeskGoals.DESKS[from].name)
	if CoworkerLines.BUSY.has(from):
		return "%s'S SIDE PROJECT" % from.to_upper()
	return from.to_upper() if from != "" else "THE OFFICE"


func _layout() -> void:
	var view := get_viewport_rect().size
	var inset: Vector4 = office._inset if office else Vector4.ZERO
	_margin.add_theme_constant_override("margin_left", int(20 + inset.x))
	_margin.add_theme_constant_override("margin_top", int(20 + inset.y))
	_margin.add_theme_constant_override("margin_right", int(20 + inset.z))
	_margin.add_theme_constant_override("margin_bottom", int(20 + inset.w))
	var tall := view.y >= 800.0
	var w := minf(view.x - 40.0 - inset.x - inset.z, 680.0)
	var two: bool = _entry.get("type", "") == "combo"
	var d := minf(w * (0.4 if two else 0.56), view.y * (0.26 if tall else 0.3))
	for f in _floppies:
		f.custom_minimum_size = Vector2(d, d)
	_info.custom_minimum_size.x = w
	_sub.custom_minimum_size.x = w
	_name.custom_minimum_size.x = w
	_head.add_theme_font_size_override("font_size", 34 if tall else 26)
	_name.add_theme_font_size_override("font_size", (34 if two else 28) if tall else 22)
	_info.add_theme_font_size_override("font_size", 14 if tall else 11)
	_sub.add_theme_font_size_override("font_size", 14 if tall else 11)


## Slow-turning rays behind the disks, in the piece's colour.
func _draw_rays() -> void:
	var c := _disks.get_global_rect().get_center() - _rays.global_position
	var r := maxf(size.x, size.y)
	var n := 18
	for i in n:
		var a := TAU * i / n + _t * 0.25
		var b := a + TAU / n * 0.45
		_rays.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a) * r, c + Vector2.from_angle(b) * r]),
			Color(_accent.r, _accent.g, _accent.b, 0.1))
	_rays.draw_circle(c, minf(size.x, size.y) * 0.32, Color(_accent.r, _accent.g, _accent.b, 0.08))


func _play(stream: AudioStream, db := 0.0) -> void:
	_player.stream = stream
	_player.volume_db = db
	_player.play()


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(fill: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = fill.darkened(0.45)
	s.set_border_width_all(4)
	s.border_width_bottom = 8
	s.set_corner_radius_all(10)
	s.set_content_margin_all(12)
	return s
