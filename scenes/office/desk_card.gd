extends Control
## Every desk's three stars (engine/desk_goals.gd) in the office:
##   - seated, a card says which game this is, its stars and the ONE next
##     goal ("NEXT: BEAT A BOSS (EVERY 4TH STAGE)  1/3"): under the screen
##     upright, top left sideways;
##   - a star plaque floats over every desk, so you can see from across the
##     room what's left to beat;
##   - earning a star: a big banner over the screen and a fanfare.
## Stars already earned are remembered in user://desk_goals.cfg, so each
## celebration plays once (the first look at an old save just remembers).

const FONT := preload("res://fonts/press_start_2p.ttf")
const SAVE_PATH := "user://desk_goals.cfg"
const GOLD := Color(1.0, 0.82, 0.2)
const CARD_H := 104.0
const CARD_W_WIDE := 440.0
const CHECK_EVERY := 0.5

var office: Node
## Desk id -> its Computer, and the plaque over it.
var _pcs := {}
var _plaques := {}
var _shown := {}
var _stars := {}
var _primed := false
var _check_t := 0.0
var _card: Control
var _banner: Control
var _banner_t := 0.0
var _banner_text := ["", "", ""]
var _queue: Array = []
var _player: AudioStreamPlayer
var _goal: Label


func setup(o: Node) -> void:
	office = o
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.draw.connect(_draw_card)
	_card.visible = false
	add_child(_card)
	_goal = Label.new()
	_goal.add_theme_font_override("font", FONT)
	_goal.add_theme_font_size_override("font_size", 13)
	_goal.add_theme_constant_override("line_spacing", 6)
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal.position = Vector2(14, 46)
	_card.add_child(_goal)
	_banner = Control.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.draw.connect(_draw_banner)
	_banner.visible = false
	add_child(_banner)
	_player = AudioStreamPlayer.new()
	_player.bus = "Effects"
	add_child(_player)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_primed = true
		for id in DeskGoals.DESKS:
			_shown[id] = int(cfg.get_value("stars", id, 0))


## After every desk and machine is built: find their screens, hang plaques.
func add_desk(id: String, pc) -> void:
	if pc == null or not DeskGoals.has(id):
		return
	_pcs[id] = pc
	var l := Label3D.new()
	l.font = FONT
	l.font_size = 32
	l.pixel_size = 0.003
	l.outline_size = 14
	l.outline_modulate = Color(0.05, 0.03, 0.0)
	l.modulate = GOLD
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.position = Vector3(0, pc.size.y * 0.5 + 0.17, 0.02)
	l.text = DeskGoals.star_text(0)
	pc.screen.add_child(l)
	_plaques[id] = l


func desk_of(pc) -> String:
	for id in _pcs:
		if _pcs[id] == pc:
			return id
	return ""


func _process(delta: float) -> void:
	if office == null:
		return
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = CHECK_EVERY
		_check()
	_place_card()
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.queue_redraw()
		if _banner_t <= 0.0:
			_banner.visible = false
	if _banner_t <= 0.0 and not _queue.is_empty():
		_celebrate(_queue.pop_front())


func _numbers() -> Array:
	var st: LadderState = office._ladder.state if office._ladder else null
	return [DaleStory.read_stats(), st.best if st else {}, Array(st.beaten) if st else []]


func _check() -> void:
	var n := _numbers()
	var changed := false
	for id in DeskGoals.DESKS:
		var s := DeskGoals.stars(id, n[0], n[1], n[2])
		_stars[id] = s
		if _plaques.has(id):
			_plaques[id].text = DeskGoals.star_text(s)
		var before := int(_shown.get(id, 0))
		if s > before:
			if _primed:
				for k in range(before, s):
					_queue.append([id, k])
			_shown[id] = s
			changed = true
	if changed or not _primed:
		_primed = true
		var cfg := ConfigFile.new()
		for id in _shown:
			cfg.set_value("stars", id, _shown[id])
		cfg.save(SAVE_PATH)
	_card.queue_redraw()


## The goal card: seated at a desk that has stars.
func _place_card() -> void:
	var id := desk_of(office._seat) if office._seat else ""
	# The plaque over the desk you're at would sit right in your face.
	for d in _plaques:
		_plaques[d].visible = d != id
	_card.visible = id != "" and not office._talking
	if not _card.visible:
		return
	var size: Vector2 = office._hud.size
	var inset: Vector4 = office._inset
	if wide():
		_card.position = Vector2(24 + inset.x, 24 + inset.y)
		_card.size = Vector2(CARD_W_WIDE, CARD_H)
	else:
		_card.position = Vector2(24 + inset.x, size.y - inset.w - 24 - CARD_H)
		_card.size = Vector2(size.x - 48 - inset.x - inset.z, CARD_H)
	_card.set_meta("desk", id)
	_goal.size = Vector2(_card.size.x - 28, CARD_H - 50)


func wide() -> bool:
	var size: Vector2 = office._hud.size
	return size.x > size.y


## Room the card takes at the top / bottom of the screen while seated (px).
func reserve() -> Vector2:
	if not _card.visible:
		return Vector2.ZERO
	if wide():
		return Vector2(_card.position.y + CARD_H + 8.0, 0.0)
	return Vector2(0.0, office._hud.size.y - _card.position.y + 8.0)


func _draw_card() -> void:
	var id: String = _card.get_meta("desk", "")
	if id == "":
		return
	var desk: Dictionary = DeskGoals.DESKS[id]
	var s := int(_stars.get(id, 0))
	var w := _card.size.x
	var r := Rect2(Vector2.ZERO, _card.size)
	_card.draw_rect(r, Color(0.05, 0.04, 0.09, 0.85))
	_card.draw_rect(r, Color(1, 1, 1, 0.55), false, 3.0)
	_card.draw_string(FONT, Vector2(14, 32), desk.name, HORIZONTAL_ALIGNMENT_LEFT, w - 150, 16, Color(1, 1, 1))
	_card.draw_string(FONT, Vector2(0, 34), DeskGoals.star_text(s), HORIZONTAL_ALIGNMENT_RIGHT, w - 14, 26, GOLD)
	var n := _numbers()
	var goal := DeskGoals.next_goal(id, n[0], n[1], n[2])
	var text := "ALL 3 STARS. DESK MASTERED!"
	var col := GOLD
	if not goal.is_empty():
		text = "NEXT: " + str(goal.text)
		if goal.counts:
			text += "  (%d/%d)" % [mini(goal.have, goal.need), goal.need]
		col = Color(0.55, 1.0, 0.6)
	_goal.text = text
	_goal.add_theme_color_override("font_color", col)


func _celebrate(what: Array) -> void:
	var id: String = what[0]
	var k: int = what[1]
	var desk: Dictionary = DeskGoals.DESKS[id]
	var tier: Array = desk.tiers[k]
	_banner_text = [DeskGoals.star_text(k + 1), desk.name, "DONE: " + str(tier[2]).get_slice(":", 0)]
	_banner_t = 3.2
	_banner.visible = true
	_player.stream = preload("res://audio/fanfare.wav") if k == 2 else preload("res://audio/jackpot.wav")
	_player.volume_db = -3.0
	_player.play()
	var tot := DeskGoals.total(_numbers()[0], _numbers()[1], _numbers()[2])
	office._toast.text = "STAR EARNED: %s %s\nOFFICE TOTAL: %d/%d ★" % [desk.name, DeskGoals.star_text(k + 1), tot.x, tot.y]
	office._toast_time = 4.0


func _draw_banner() -> void:
	if _banner_t <= 0.0:
		return
	var size: Vector2 = office._hud.size
	var age := 3.2 - _banner_t
	var pop := clampf(age / 0.25, 0.0, 1.0)
	var k := 1.0 + 0.4 * (1.0 - pop) * (1.0 - pop)
	var a := clampf(_banner_t / 0.4, 0.0, 1.0)
	var bw := minf(size.x - 40.0, 640.0)
	var bh := 230.0
	var c := size * 0.5
	_banner.draw_set_transform(c, sin(age * 3.0) * 0.02, Vector2(k, k))
	var r := Rect2(-bw * 0.5, -bh * 0.5, bw, bh)
	_banner.draw_rect(Rect2(r.position + Vector2(8, 8), r.size), Color(0, 0, 0, 0.5 * a))
	_banner.draw_rect(r, Color(0.12, 0.06, 0.2, 0.95 * a))
	_banner.draw_rect(r, Color(GOLD.r, GOLD.g, GOLD.b, a), false, 6.0)
	_banner.draw_string_outline(FONT, Vector2(r.position.x, -30), _banner_text[0], HORIZONTAL_ALIGNMENT_CENTER, bw, 64, 12, Color(0, 0, 0, a))
	_banner.draw_string(FONT, Vector2(r.position.x, -30), _banner_text[0], HORIZONTAL_ALIGNMENT_CENTER, bw, 64, Color(GOLD.r, GOLD.g, GOLD.b, a))
	_banner.draw_string(FONT, Vector2(r.position.x, 22), _banner_text[1], HORIZONTAL_ALIGNMENT_CENTER, bw, 22, Color(1, 1, 1, a))
	_banner.draw_multiline_string(FONT, Vector2(r.position.x + 16, 62), _banner_text[2], HORIZONTAL_ALIGNMENT_CENTER, bw - 32, 15, 2, Color(0.55, 1.0, 0.6, a))
	# Sparkles flying out.
	for i in 14:
		var ang := TAU * i / 14.0 + age
		var d := 140.0 + age * 260.0
		var p := Vector2(cos(ang), sin(ang)) * Vector2(d * 1.4, d * 0.7)
		_banner.draw_string(FONT, p, "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(GOLD.r, GOLD.g, GOLD.b, a * 0.8))
	_banner.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- dev / tests

## Forget what's been celebrated (New Game).
static func wipe() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
