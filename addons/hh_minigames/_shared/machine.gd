extends Control
## Base for every screen past the office door (arcade cabinets, the trading
## terminal, the boardroom projector, the putting green, the stage, the
## archive). Each one runs in its own SubViewport (720x1280) on a screen in
## the office's 3D world, so sitting down, taps, mouse and the controller all
## arrive the same way as the office's other games.
##
## `hub` is the office's ladder controller (scenes/office/ladder.gd): it holds
## LadderState (tokens, tickets, items) and Coworkers, and hears about wins.
## `active` is true while you sit at this screen (time-based games pause
## otherwise). Controls are Buttons, so the pad cursor works on all of them.

const W := 720.0
const H := 1280.0
const FONT := preload("res://addons/hh_minigames/_shared/fonts/press_start_2p.ttf")
const SFX := {
	"coin": preload("res://addons/hh_minigames/_shared/audio/coin.wav"), "ding": preload("res://addons/hh_minigames/_shared/audio/ding.wav"),
	"jackpot": preload("res://addons/hh_minigames/_shared/audio/jackpot.wav"), "click": preload("res://addons/hh_minigames/_shared/audio/click.wav"),
	"chime": preload("res://addons/hh_minigames/_shared/audio/chime.wav"), "cheer": preload("res://addons/hh_minigames/_shared/audio/cheer.wav"),
	"thump": preload("res://addons/hh_minigames/_shared/audio/thump.wav"), "groan": preload("res://addons/hh_minigames/_shared/audio/groan.wav"),
	"fanfare": preload("res://addons/hh_minigames/_shared/audio/fanfare.wav"), "laugh_big": preload("res://addons/hh_minigames/_shared/audio/laugh_big.wav"),
	"laugh_small": preload("res://addons/hh_minigames/_shared/audio/laugh_small.wav"), "laugh_huge": preload("res://addons/hh_minigames/_shared/audio/laugh_huge.wav"),
	"rimshot": preload("res://addons/hh_minigames/_shared/audio/rimshot.wav"), "applause": preload("res://addons/hh_minigames/_shared/audio/applause.wav"),
	"sad_trombone": preload("res://addons/hh_minigames/_shared/audio/sad_trombone.wav"), "card": preload("res://addons/hh_minigames/_shared/audio/card.wav"),
}

## Mini game interface (addons/hh_minigames/README.md): start(config) sets
## things up, `finished` reports each play's result. `hub` is the optional
## host (config "host"): the office's economy, used by duck typing only.
signal finished(result: Dictionary)

var config := {}
var hub: Node
## The glass-cage machines (claw, coin pusher, Fall Guy): the cabinet's
## inside in the office's own 3D world (scenes/ladder/cage3d.gd), set by the
## ladder before this is added. This Control is then only the controls, drawn
## over the glass while you sit there (transparent everywhere else).
var cage: Node3D
var active := false
## The controller frame for this screen (scenes/pad_cursor.gd).
var pad: Node
var accent := Color(1.0, 0.35, 0.7)
var _players: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _top: Label
var _banner: Label
var _banner_time := 0.0
## Glass-cage machines: which one (for missions and bests), the mission
## line, the NEW BEST! flash.
var machine_id := ""
var _mission: Label
var _best_lbl: Label
var _best_t := 0.0
var _own_missions: ArcadeMissions


## config: "host" (tokens/tickets owner, see README), "cage" (the Node3D the
## glass-cage machines build into). Call before adding to the tree.
func start(cfg: Dictionary = {}) -> void:
	config = cfg
	if cfg.has("host"):
		hub = cfg.host
	if cfg.has("cage"):
		cage = cfg.cage


## One play is over: tell whoever is listening.
func finish(score: int, outcome: String, extra := {}) -> void:
	var r := {"game": get_script().resource_path.get_base_dir().get_file(), "score": score, "outcome": outcome}
	r.merge(extra)
	finished.emit(r)


func _init() -> void:
	size = Vector2(W, H)
	custom_minimum_size = size
	clip_contents = true


func _ready() -> void:
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	pad = preload("res://addons/hh_minigames/_shared/pad_cursor.gd").new()
	add_child(pad)
	# Opened on its own (its main.tscn as the scene): a pretend host, and live.
	if hub == null and get_parent() == get_tree().root:
		var house := preload("res://addons/hh_minigames/_shared/house.gd").new()
		add_child(house)
		hub = house
		set_active.call_deferred(true)


# ---------------------------------------------------------------- kit

func sfx(name: String, db := 0.0, pitch := 1.0) -> void:
	if not SFX.has(name) or _players.is_empty():
		return
	var p := _players[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _players.size()
	p.stream = SFX[name]
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


func label(text: String, font_size: int, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 8)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func box(color: Color, border := Color(0, 0, 0, 0), width := 0, radius := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(14)
	return s


func button(text: String, font_size := 30, color := Color(0.2, 0.12, 0.3), border := Color(1, 1, 1, 0.85)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 110)
	var normal := box(color, border, 4, 6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("focus", normal)
	var down := box(color.lightened(0.3), border, 4, 6)
	b.add_theme_stylebox_override("pressed", down)
	var off := box(color.darkened(0.5), Color(1, 1, 1, 0.25), 4, 6)
	b.add_theme_stylebox_override("disabled", off)
	return b


func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## A plain background with a title bar: the machine's name and, below it, a
## line for tokens / tickets (refresh_top()). A glass-cage machine passes a
## clear bg: no background (the real cabinet shows through), just a dark
## strip behind the title so it reads over the marquee.
func frame(title: String, bg: Color, title_color: Color) -> void:
	accent = title_color
	if bg.a > 0.0:
		var back := ColorRect.new()
		back.color = bg
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Behind this Control's own _draw(), so machines can draw over it.
		back.show_behind_parent = true
		add_child(full(back))
	else:
		var strip := Panel.new()
		strip.add_theme_stylebox_override("panel", box(Color(0.02, 0.01, 0.04, 0.72), Color(title_color, 0.6), 3, 10))
		strip.position = Vector2(236, 26)
		strip.size = Vector2(W - 256, 96)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)
	# Right of the office's STAND UP button, which sits over the top-left
	# corner of the screen while you're seated on a phone.
	var t := label(title, 30, title_color, HORIZONTAL_ALIGNMENT_RIGHT)
	t.position = Vector2(250, 40)
	t.size = Vector2(W - 270, 50)
	add_child(t)
	_top = label("", 20, Color(1.0, 0.92, 0.55), HORIZONTAL_ALIGNMENT_RIGHT)
	_top.position = Vector2(250, 100)
	if bg.a <= 0.0:
		# The cabinet's own marquee shows the name: just the tokens, your
		# best win and the current mission here.
		t.visible = false
		_top.add_theme_font_size_override("font_size", 16)
		_top.position = Vector2(250, 40)
		_top.size.y = 76
		_mission = label("", 16, Color(0.45, 1.0, 0.95))
		_mission.add_theme_color_override("font_outline_color", Color.BLACK)
		_mission.add_theme_constant_override("outline_size", 8)
		_mission.position = Vector2(20, 168)
		_mission.size = Vector2(W - 40, 50)
		add_child(_mission)
		_best_lbl = label("NEW BEST!", 46, Color(1.0, 0.85, 0.2))
		_best_lbl.add_theme_color_override("font_outline_color", Color(0.4, 0.1, 0.0))
		_best_lbl.add_theme_constant_override("outline_size", 14)
		_best_lbl.position = Vector2(0, 250)
		_best_lbl.size = Vector2(W, 70)
		_best_lbl.pivot_offset = Vector2(W * 0.5, 35)
		_best_lbl.modulate.a = 0.0
		_best_lbl.z_index = 51
		add_child(_best_lbl)
	_top.size = Vector2(W - 270, 40)
	add_child(_top)
	_banner = label("", 40, Color(1.0, 0.9, 0.3))
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 14)
	_banner.position = Vector2(20, 470 if bg.a > 0.0 else 330)
	_banner.size = Vector2(W - 40, 240)
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_banner.z_index = 50
	add_child(_banner)
	refresh_top()


func refresh_top() -> void:
	if _top and hub:
		_top.text = "TOKENS %d  TICKETS %d" % [hub.state.tokens, hub.state.tickets]
		if machine_id != "":
			var best := int(hub.state.best.get(machine_id, 0))
			_top.text += "\nBEST WIN %d" % best if best > 0 else "\nNO WINS YET"
	if _mission and machine_id != "":
		_mission.text = missions().text(machine_id)


## The arcade's missions (the ladder's, or a scratch copy without one).
func missions() -> ArcadeMissions:
	if hub and "missions" in hub and hub.missions:
		return hub.missions
	if _own_missions == null:
		_own_missions = ArcadeMissions.new("user://arcade_scratch.cfg")
	return _own_missions


## Something mission-worthy happened; pays and cheers if it finished one.
func mission_event(key: String, value := 1) -> void:
	if machine_id == "":
		return
	var m := missions().event(machine_id, key, value)
	if m.is_empty():
		return
	if hub:
		hub.win_tickets(int(m.tickets), "", false)
	sfx("fanfare", -4.0)
	banner("MISSION DONE!\n%s\n+%d TICKETS" % [m.text, m.tickets], 2.8, Color(0.45, 1.0, 0.95))
	refresh_top()


## A big message across the middle that fades.
func banner(text: String, seconds := 2.2, color := Color(1.0, 0.9, 0.3)) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_time = seconds
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(1.15, 1.15)
	_banner.pivot_offset = _banner.size * 0.5


func _process(delta: float) -> void:
	if _banner and _banner_time > 0.0:
		_banner_time -= delta
		_banner.modulate.a = clampf(_banner_time * 2.0, 0.0, 1.0)
		_banner.scale = _banner.scale.lerp(Vector2.ONE, minf(1.0, delta * 10.0))
	if _best_lbl and _best_t > 0.0:
		_best_t -= delta
		_best_lbl.modulate.a = clampf(_best_t * 2.0, 0.0, 1.0)
		_best_lbl.scale = Vector2.ONE * (1.0 + 0.08 * sin(_best_t * 18.0))


## Pay one token for a play. Shows the petty-cash hint when you're out.
func pay_token() -> bool:
	if hub == null:
		return true
	if not hub.spend_token():
		banner("OUT OF TOKENS\nPETTY CASH AT\nTHE PRIZE COUNTER", 2.6, Color(1.0, 0.5, 0.4))
		sfx("groan", -6.0)
		return false
	sfx("coin", -4.0)
	refresh_top()
	return true


func win(tickets: int, machine: String, beats := false) -> void:
	if hub:
		var old := int(hub.state.best.get(machine, 0))
		hub.win_tickets(tickets, machine, beats)
		# Beat your own biggest win on this machine: say so.
		if old > 0 and tickets > old and _best_lbl:
			_best_t = 2.2
			sfx("cheer", -6.0)
	refresh_top()


func set_active(on: bool) -> void:
	active = on
	if on:
		refresh_top()
