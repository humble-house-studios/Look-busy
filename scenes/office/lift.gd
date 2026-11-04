extends Node3D
## One elevator on the ladder (scenes/office/ladder.gd). Every floor up the
## ladder is reached by elevator: a car set into the wall between two floors,
## with doors on both faces. Walk in, the doors shut behind you, the motor
## hums and the floor counter ticks, ding, and the doors in front open onto
## the next floor. Walk back in to ride down. The car really sits in the
## wall (no teleport), so walking, touch, the pad and the physics all work as
## before; the ride sells the floors. While you're inside, you're on the
## floor the car is at (`room()`), so a floor only "arrives" with the ding.
##
## A locked lift (its gate, LadderState.door_open(id)) keeps its doors shut
## and lights its button red. A one-sided lift (the top floor) is just the
## doors, for now. Local frame: +z points to the upper floor (rooms[1]),
## -z to the lower (rooms[-1]); the rig sits on the wall's centre line.

const IN_W := 1.3
const OUT_W := 1.9
const HALF := 0.75
const H := 2.35
const SHELL_H := 2.5
const OPEN_W := 0.96
const OPEN_H := 2.1
const DOOR_TIME := 0.55
const CALL_TIME := 1.1
## How far in (from the open doors) before they shut behind you.
const DEEP := 0.55
## Floors, bottom to top: the number on the buttons and displays.
const FLOOR := {"archive": "B", "office": "1", "arcade": "2", "trading": "3", "boardroom": "4", "corner": "5", "top": "6"}
const LEVEL := {"archive": 0, "office": 1, "arcade": 2, "trading": 3, "boardroom": 4, "corner": 5, "top": 6}
const NAME := {"archive": "BASEMENT ARCHIVE", "office": "QA", "arcade": "BREAK ROOM ARCADE", "trading": "TRADING FLOOR",
	"boardroom": "BOARDROOM", "corner": "CORNER OFFICE", "top": "TOP FLOOR"}
const DING := preload("res://audio/lift_ding.wav")
const HUM := preload("res://audio/lift_hum.wav")
const DOORS := preload("res://audio/lift_doors.wav")

var id := ""
var hub: Node
## Floor (room) on each side: -1 below, 1 above ("" = no doors there).
var rooms := {-1: "", 1: ""}
## Unlocked (LadderState.door_open); the ladder keeps it current.
var gate := false
## Which side the car is at.
var at := -1
## idle, call (coming to you), close, ride.
var phase := "idle"
## Look Busy: the boss is using it; keep the lower doors open.
var hold := false

var _t := 0.0
var _armed := true
var _ride_len := 1.0
var _open := {-1: 0.0, 1: 0.0}
var _want := {-1: false, 1: false}
var _panels := {-1: [], 1: []}
var _outer_disp := {}
var _inner_disp: Array[Label3D] = []
var _buttons := {}
var _locks := {}
var _lamps := {}
var _lamp_mats := {}
var _btn_off: Material
var _btn_on: Material
var _sfx: AudioStreamPlayer3D
var _hum: AudioStreamPlayer3D
var _door_sfx: AudioStreamPlayer3D


func two_sided() -> bool:
	return rooms[1] != ""


## The floor you're on while standing inside: the one the car is at.
func room() -> String:
	return rooms[at]


## You (a world position) inside the car?
func inside(p: Vector3) -> bool:
	if not two_sided():
		return false
	var lp := to_local(p)
	return absf(lp.x) < IN_W * 0.5 + 0.05 and absf(lp.z) < HALF + 0.02 and lp.y > -0.5 and lp.y < 2.5


func riding() -> bool:
	return phase == "close" or phase == "ride"


# ---------------------------------------------------------------- building

func build(ladder: Node, lift_id: String, low: String, high: String) -> void:
	hub = ladder
	id = lift_id
	rooms = {-1: low, 1: high}
	var c := global_position + Vector3(0, 2.15, 0)
	hub._lights_cache["lift_" + id] = {"amb": Vector3(0.36, 0.33, 0.28), "fog": Vector3(0.08, 0.06, 0.05), "range": 2.6,
		"pos": PackedVector3Array([c, global_position + Vector3(0, 0.6, 0), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]),
		"col": PackedVector3Array([Vector3(0.95, 0.85, 0.62), Vector3(0.2, 0.17, 0.12), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])}
	var car := "lift_" + id
	_btn_off = hub._mat(car, Color(0.55, 0.52, 0.46))
	_btn_on = hub._mat(car, Color(0.3, 0.25, 0.1), 0, Color.BLACK, 24.0, Color(1.0, 0.8, 0.3))
	if two_sided():
		_build_car(car)
	for s in [-1, 1]:
		if rooms[s] != "":
			_build_face(s, car)
	_sfx = AudioStreamPlayer3D.new()
	_sfx.bus = "Effects"
	_sfx.unit_size = 3.0
	_sfx.position = Vector3(0, 1.8, 0)
	add_child(_sfx)
	_door_sfx = AudioStreamPlayer3D.new()
	_door_sfx.bus = "Effects"
	_door_sfx.stream = DOORS
	_door_sfx.volume_db = -6.0
	_door_sfx.unit_size = 2.5
	_door_sfx.position = Vector3(0, 1.2, 0)
	add_child(_door_sfx)
	_hum = AudioStreamPlayer3D.new()
	_hum.bus = "Effects"
	_hum.stream = HUM
	_hum.unit_size = 2.0
	_hum.position = Vector3(0, 2.0, 0)
	add_child(_hum)
	_update_lamps()
	_show_floor(rooms[at])


func _build_car(car: String) -> void:
	var wood: Material = hub._mat(car, Color(0.5, 0.33, 0.2), 3, Color(0.42, 0.27, 0.16), 40.0)
	var carpet: Material = hub._mat(car, Color(0.32, 0.2, 0.16), 1, Color(0.27, 0.16, 0.13), 30.0)
	var steel: Material = hub._mat(car, Color(0.6, 0.6, 0.62), 6, Color(0.5, 0.5, 0.53), 70.0)
	var brass: Material = hub._mat(car, Color(0.85, 0.68, 0.3))
	var dark: Material = hub._mat(car, Color(0.04, 0.03, 0.03))
	var deep := HALF * 2.0 - 0.14
	# Floor (just over the rooms' floors, which carry you), ceiling and light.
	hub._box(Vector3(IN_W, 0.02, deep), Vector3(0, 0.0, 0), carpet, false, Vector3.ZERO, self)
	hub._box(Vector3(IN_W + 0.1, 0.04, HALF * 2.0), Vector3(0, H + 0.02, 0), steel, false, Vector3.ZERO, self)
	hub._box(Vector3(0.7, 0.02, 0.9), Vector3(0, H - 0.01, 0), hub._glow(car, Color(1.0, 0.92, 0.72)), false, Vector3.ZERO, self)
	# Wood-panelled walls with a brass handrail.
	for side in [-1.0, 1.0]:
		hub._box(Vector3(0.04, H, deep), Vector3(side * (IN_W * 0.5 + 0.02), H * 0.5, 0), wood, true, Vector3.ZERO, self)
		hub._box(Vector3(0.03, 0.04, deep - 0.3), Vector3(side * (IN_W * 0.5 - 0.03), 0.95, 0), brass, false, Vector3.ZERO, self)
		hub._box(Vector3(0.01, 0.12, deep), Vector3(side * (IN_W * 0.5 - 0.005), 0.06, 0), steel, false, Vector3.ZERO, self)
	# The button panel on the right wall: every floor, the one you're riding
	# to lights up.
	hub._box(Vector3(0.012, 0.7, 0.2), Vector3(IN_W * 0.5 - 0.006, 1.22, 0), steel, false, Vector3.ZERO, self)
	var floors := ["top", "corner", "boardroom", "trading", "arcade", "office", "archive"]
	for i in floors.size():
		var y := 1.5 - i * 0.085
		var b: MeshInstance3D = hub._box(Vector3(0.014, 0.05, 0.05), Vector3(IN_W * 0.5 - 0.014, y, 0.04), _btn_off, false, Vector3.ZERO, self)
		_buttons[floors[i]] = b
		hub._label(FLOOR[floors[i]], Vector3(IN_W * 0.5 - 0.022, y, -0.04), 18, Color(0.15, 0.13, 0.1), self, Vector3(0, -PI / 2, 0))
	hub._label("ROTH-OTIS\nCAPACITY 8", Vector3(IN_W * 0.5 - 0.022, 0.86, 0), 6, Color(0.2, 0.18, 0.15), self, Vector3(0, -PI / 2, 0))
	# Inner door frames and the floor display over each.
	for s in [-1, 1]:
		var z: float = s * (HALF - 0.07)
		var jamb := (IN_W - OPEN_W) * 0.5
		for side in [-1.0, 1.0]:
			hub._box(Vector3(jamb, H, 0.02), Vector3(side * (OPEN_W * 0.5 + jamb * 0.5), H * 0.5, z), steel, true, Vector3.ZERO, self)
		hub._box(Vector3(OPEN_W, H - OPEN_H, 0.02), Vector3(0, OPEN_H + (H - OPEN_H) * 0.5, z), steel, false, Vector3.ZERO, self)
		hub._box(Vector3(0.42, 0.16, 0.01), Vector3(0, OPEN_H + 0.12, z - s * 0.012), dark, false, Vector3.ZERO, self)
		var l: Label3D = hub._label(FLOOR[rooms[-1]], Vector3(0, OPEN_H + 0.12, z - s * 0.03), 48, Color(1.0, 0.25, 0.15), self, Vector3(0, 0.0 if s < 0 else PI, 0))
		_inner_disp.append(l)


## The face on side s: the frame in the room's own light, the call button,
## a sign saying where it goes, the floor display and the sliding doors.
func _build_face(s: int, car: String) -> void:
	var r: String = rooms[s]
	var frame: Material = hub._mat(r, Color(0.55, 0.5, 0.42), 6, Color(0.45, 0.4, 0.33), 60.0)
	var shell: Material = hub._mat(r, Color(0.38, 0.34, 0.3), 6, Color.BLACK, 30.0)
	var steel_out: Material = hub._mat(r, Color(0.68, 0.68, 0.7), 6, Color(0.56, 0.56, 0.6), 70.0)
	var steel_in: Material = hub._mat(car, Color(0.66, 0.66, 0.68), 6, Color(0.55, 0.55, 0.58), 70.0)
	var dark: Material = hub._mat(r, Color(0.04, 0.03, 0.03))
	var face: float = s * HALF
	var rot := Vector3(0, 0.0 if s > 0 else PI, 0)
	# Frame round the doorway.
	var jamb := (OUT_W - OPEN_W) * 0.5
	for side in [-1.0, 1.0]:
		hub._box(Vector3(jamb, SHELL_H, 0.04), Vector3(side * (OPEN_W * 0.5 + jamb * 0.5), SHELL_H * 0.5, face), frame, true, Vector3.ZERO, self)
	hub._box(Vector3(OPEN_W, SHELL_H - OPEN_H, 0.04), Vector3(0, OPEN_H + (SHELL_H - OPEN_H) * 0.5, face), frame, false, Vector3.ZERO, self)
	# The box between the frame and the wall it's set into.
	var d := HALF - 0.1
	for side in [-1.0, 1.0]:
		hub._box(Vector3(0.04, SHELL_H, d), Vector3(side * (OUT_W * 0.5 - 0.02), SHELL_H * 0.5, s * (0.1 + d * 0.5)), shell, true, Vector3.ZERO, self)
	hub._box(Vector3(OUT_W, 0.04, d), Vector3(0, SHELL_H - 0.02, s * (0.1 + d * 0.5)), shell, false, Vector3.ZERO, self)
	if not two_sided():
		# Nothing behind the doors yet: a dark shaft.
		hub._box(Vector3(OPEN_W + 0.1, OPEN_H + 0.1, 0.04), Vector3(0, OPEN_H * 0.5, s * (HALF - 0.12)), dark, false, Vector3.ZERO, self)
	# Floor display over the doors.
	var out := face + s * 0.025
	hub._box(Vector3(0.5, 0.24, 0.02), Vector3(0, OPEN_H + 0.2, face + s * 0.02), dark, false, Vector3.ZERO, self)
	_outer_disp[s] = hub._label(FLOOR[rooms[at]], Vector3(0, OPEN_H + 0.2, face + s * 0.045), 64, Color(1.0, 0.25, 0.15), self, rot)
	# Call button on your right as you face it; where it goes on your left.
	var x_r: float = s * (OPEN_W * 0.5 + jamb * 0.5)
	hub._box(Vector3(0.12, 0.2, 0.02), Vector3(x_r, 1.1, out), steel_out, false, Vector3.ZERO, self)
	_lamp_mats[s] = {
		"off": hub._mat(r, Color(0.5, 0.48, 0.44)),
		"on": hub._mat(r, Color(0.3, 0.2, 0.05), 0, Color.BLACK, 24.0, Color(1.0, 0.75, 0.25)),
		"locked": hub._mat(r, Color(0.3, 0.05, 0.05), 0, Color.BLACK, 24.0, Color(0.9, 0.12, 0.1)),
	}
	_lamps[s] = hub._box(Vector3(0.06, 0.06, 0.02), Vector3(x_r, 1.1, out + s * 0.012), _lamp_mats[s].off, false, Vector3.ZERO, self)
	var other: String = rooms[-s]
	var where := ""
	if other != "":
		where = ("UP TO " if LEVEL[other] > LEVEL[r] else "DOWN TO ") + FLOOR[other] + "\n" + NAME[other]
	elif id == "top":
		where = "UP TO 6\nTOP FLOOR"
	hub._label("ELEVATOR", Vector3(-x_r, 1.8, out + s * 0.005), 26, Color(0.95, 0.9, 0.75), self, rot)
	hub._label(where, Vector3(-x_r, 1.5, out + s * 0.005), 20, Color(1.0, 0.85, 0.45), self, rot, 225.0)
	# The doors: two steel panels that slide apart. Room-lit outside,
	# car-lit inside; they block you while shut.
	var dz: float = s * (HALF - 0.04)
	for side in [-1.0, 1.0]:
		var p := Node3D.new()
		p.position = Vector3(side * OPEN_W * 0.25, 0, dz)
		add_child(p)
		hub._box(Vector3(OPEN_W * 0.5 + 0.01, OPEN_H, 0.014), Vector3(0, OPEN_H * 0.5, s * 0.008), steel_out, true, Vector3.ZERO, p)
		hub._box(Vector3(OPEN_W * 0.5 + 0.01, OPEN_H, 0.014), Vector3(0, OPEN_H * 0.5, -s * 0.008), steel_in, false, Vector3.ZERO, p)
		hub._box(Vector3(0.01, OPEN_H, 0.032), Vector3(-side * (OPEN_W * 0.25), OPEN_H * 0.5, 0), dark, false, Vector3.ZERO, p)
		_panels[s].append(p)
	_locks[s] = hub._label("LOCKED", Vector3(0, 1.45, dz + s * 0.02), 24, Color(1.0, 0.4, 0.35), self, rot)


# ---------------------------------------------------------------- every frame

## me: where you are. Returns true the moment a ride ends (you've arrived).
func tick(delta: float, me: Vector3) -> bool:
	var arrived := false
	var lp := to_local(me)
	var in_car := inside(me)
	var my_side := -1 if lp.z < 0.0 else 1
	if not in_car:
		_armed = true
	_t += delta
	match phase:
		"idle":
			_want[-at] = false
			if hold:
				if at != -1 and not in_car:
					at = -1
					_show_floor(rooms[at])
				_want[-1] = true
			elif not gate:
				_want[at] = false
			elif in_car:
				_want[at] = true
				var depth := HALF - lp.z * at
				if _armed and two_sided() and depth > DEEP:
					_start("close")
			else:
				var gap := absf(lp.z) - HALF
				var near: bool = gap > -0.05 and gap < 2.0 and absf(lp.x) < 1.5 and rooms[my_side] != ""
				if near and my_side == at:
					_want[at] = true
				elif near and two_sided():
					_want[at] = false
					_start("call")
				else:
					_want[at] = false
		"call":
			if _t >= CALL_TIME:
				_hum.stop()
				at = -at
				_show_floor(rooms[at])
				_ding()
				phase = "idle"
				_update_lamps()
		"close":
			_want[at] = false
			# Still in the doorway: open back up.
			if not in_car or HALF - lp.z * at < 0.3:
				_want[at] = true
				phase = "idle"
				_update_lamps()
			elif (_open[at] <= 0.001 and _t >= DOOR_TIME) or _t >= DOOR_TIME * 3.0:
				var a: String = rooms[at]
				var b: String = rooms[-at]
				_ride_len = 0.9 + 0.55 * absi(LEVEL[b] - LEVEL[a])
				phase = "ride"
				_t = 0.0
				_light_button(b)
				_hum.play()
		"ride":
			var a: String = rooms[at]
			var b: String = rooms[-at]
			var k := clampf(_t / _ride_len, 0.0, 1.0)
			var la: int = LEVEL[a]
			var lb: int = LEVEL[b]
			var lvl := roundi(lerpf(la, lb, k))
			_show_text(_floor_of(lvl) + (" ^" if lb > la else " v"))
			if _t >= _ride_len:
				at = -at
				phase = "idle"
				_armed = false
				_hum.stop()
				_ding()
				_light_button("")
				_show_floor(rooms[at])
				_want[at] = true
				_update_lamps()
				arrived = true
	_slide(delta)
	return arrived


## The car rocks a little while it moves; the office adds this to the camera.
func sway() -> float:
	if phase != "ride":
		return 0.0
	var k := clampf(_t / _ride_len, 0.0, 1.0)
	var jolt := 0.012 * (exp(-_t * 9.0) - exp(-(_ride_len - _t) * 9.0))
	return sin(_t * 31.0) * 0.0035 * sin(k * PI) + jolt


func _start(p: String) -> void:
	phase = p
	_t = 0.0
	_update_lamps()
	if p == "call":
		_hum.play()


func _slide(delta: float) -> void:
	for s in [-1, 1]:
		if rooms[s] == "":
			continue
		var target := 1.0 if _want[s] else 0.0
		if _open[s] == target:
			continue
		if (_open[s] == 0.0 or _open[s] == 1.0) and _door_sfx and is_inside_tree():
			_door_sfx.play()
		_open[s] = move_toward(_open[s], target, delta / DOOR_TIME)
		# Land exactly on shut / open: a sliver left over would hold a ride
		# (or a call) forever.
		if absf(_open[s] - target) < 0.001:
			_open[s] = target
		var e := ease(_open[s], -1.8)
		var i := 0
		for p in _panels[s]:
			var side := -1.0 if i == 0 else 1.0
			p.position.x = side * (OPEN_W * 0.25 + e * (OPEN_W * 0.5 - 0.03))
			i += 1
	_show_locks()


## LOCKED across the doors while they're shut and locked.
func _show_locks() -> void:
	for s in _locks:
		_locks[s].visible = not gate and _open[s] <= 0.01


## Jump the doors to where they should be (on load and after dev skips).
func snap() -> void:
	for s in [-1, 1]:
		_open[s] = 1.0 if _want[s] else 0.0
		var i := 0
		for p in _panels[s]:
			var side := -1.0 if i == 0 else 1.0
			p.position.x = side * (OPEN_W * 0.25 + _open[s] * (OPEN_W * 0.5 - 0.03))
			i += 1


func set_gate(on: bool) -> void:
	gate = on
	_update_lamps()
	_show_locks()


## Look Busy: the boss rides it down to the office. Opens the lower doors
## (with a ding unless they're the silent type) or lets them shut.
func set_hold(on: bool, ding := true) -> void:
	if on == hold:
		return
	hold = on
	if on and ding:
		_ding()


func open_amount(s: int) -> float:
	return _open[s]


func _ding() -> void:
	if _sfx and is_inside_tree():
		_sfx.stream = DING
		_sfx.volume_db = -3.0
		_sfx.play()


func _update_lamps() -> void:
	for s in _lamps:
		var m: Dictionary = _lamp_mats[s]
		var lit: bool = phase == "call" or (phase == "idle" and gate and at == s)
		_lamps[s].material_override = m.locked if not gate else (m.on if lit else m.off)


func _light_button(room_id: String) -> void:
	for f in _buttons:
		_buttons[f].material_override = _btn_on if f == room_id else _btn_off


func _floor_of(level: int) -> String:
	for k in LEVEL:
		if LEVEL[k] == level:
			return FLOOR[k]
	return str(level)


func _show_floor(room_id: String) -> void:
	_show_text(FLOOR.get(room_id, ""))


func _show_text(t: String) -> void:
	for s in _outer_disp:
		_outer_disp[s].text = t
	for l in _inner_disp:
		l.text = t
