extends Node3D
## Entry scene for a glass-cage machine (claw, pusher, Fall Guy, Rage Cage)
## played on its own: the cage in its own little 3D world, the camera where a
## seated player's would be (the machine's SEAT), and the machine's controls
## laid over it, full screen. The office builds its own cabinet round the
## cage instead and uses the machine script directly (HHMinigames.script_for).
##
## Same interface as every mini game: start(config) before adding it to the
## tree ("host": the economy, else a pretend one), `finished` per play.

signal finished(result: Dictionary)

@export var game := "claw"

var config := {}
var machine: Control
var _cam: Camera3D
var _screen: Node3D
var _box: SubViewportContainer


func start(cfg: Dictionary = {}) -> void:
	config = cfg


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.06, 0.16)
	add_child(env)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true
	var cage := preload("res://addons/hh_minigames/_shared/cage3d.gd").new()
	add_child(cage)
	var scr: Script = load(HHMinigames.script_for(game))
	var seat: Dictionary = scr.SEAT
	_screen = Node3D.new()
	_screen.position = seat.at
	_screen.rotation.x = seat.tilt
	add_child(_screen)
	var host: Node = config.get("host")
	if host == null:
		host = preload("res://addons/hh_minigames/_shared/house.gd").new()
		add_child(host)
	var layer := CanvasLayer.new()
	add_child(layer)
	_box = SubViewportContainer.new()
	_box.size = Vector2(720, 1280)
	layer.add_child(_box)
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1280)
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.handle_input_locally = false
	_box.add_child(vp)
	machine = scr.new()
	var cfg := config.duplicate()
	cfg["host"] = host
	cfg["cage"] = cage
	machine.start(cfg)
	machine.finished.connect(finished.emit)
	vp.add_child(machine)
	machine.set_active(true)
	get_viewport().size_changed.connect(_fit)
	_fit()


## The seat camera and the controls, fitted to the window like the office's
## seated view: the machine's 9:16 rect fills the height (or the width).
func _fit() -> void:
	var seat: Dictionary = machine.get_script().SEAT
	var size := get_viewport().get_visible_rect().size
	var half := tan(deg_to_rad(_cam.fov) * 0.5)
	var d: float = seat.size.y * 0.5 / 0.94 / half
	if size.x / maxf(size.y, 1.0) < 9.0 / 16.0:
		d *= (9.0 / 16.0) / (size.x / size.y)
	var xf := _screen.global_transform
	_cam.global_transform = Transform3D(xf.basis, xf.origin + xf.basis.z * d)
	var px: float = size.y / (2.0 * d * half) * float(seat.size.y)
	_box.scale = Vector2.ONE * (px / 1280.0)
	_box.position = (size - Vector2(720, 1280) * _box.scale) * 0.5
