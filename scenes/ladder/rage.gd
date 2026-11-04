extends "res://scenes/ladder/machine.gd"
## RAGE CAGE: a glass smash room on the trading floor (scenes/ladder/cage3d.gd).
## An office machine sits on a little desk (a beige CRT, the printer, the
## coffee maker); a sledgehammer hangs over it. One play = three swings:
## tap once to lock the aim (the red line shows where it lands), tap again
## at the top of the power meter to swing.
##
## The breaking is real: every part is a solid, and a hit cuts the parts
## near it into Voronoi pieces (engine/fracture.gd), more and smaller the
## harder and closer the hit. Pieces are convex physics bodies, so the next
## swing breaks them again. Fresh break faces show the machine's guts.
## Every piece knocked off the desk pays a ticket (glass pays double);
## clear the whole desk for CLEAN DESK (ArcadeRules.RAGE_*).
##
## A play costs a token, or one STRESS: bad days on the trading floor bank
## free plays (LadderState.add_stress).

const SEAT := {"at": Vector3(0, 1.3, 0.62), "size": Vector2(0.9, 1.6), "tilt": -0.28}
const FLOOR := 0.82
const HALF_X := 0.47
const BACK := -0.48
const GLASS_Z := 0.42
const TOP := 1.86
## The desk the machine sits on (its top face, half sizes, centre z).
const TABLE_Y := 1.08
const TABLE_HX := 0.2
const TABLE_HZ := 0.17
const TABLE_Z := -0.05
## The hammer comes down and back, away from you, along this.
const DIR := Vector3(0, -0.88, -0.47)
## Where the aim wanders over the desk (x, then z between these).
const AIM_X := 0.17
const AIM_Z0 := -0.14
const AIM_Z1 := 0.04
const HEAD := Vector3(0.075, 0.075, 0.14)
const WEAK_R := 0.075
## Pieces too small to break again, and dust that isn't made at all.
const MIN_VOL := 0.000035
const DUST := 0.0000015
const MAX_BODIES := 90
const DENSITY := 420.0

const SMASH := preload("res://audio/rage_smash.wav")
const SHATTER := preload("res://audio/rage_shatter.wav")

## The machines you smash. Each part: [size, centre (object metres, origin on
## the desk top), colour, guts colour, glass?]. weak: the glowing spot.
const OBJECTS := [
	{"name": "CRT MONITOR", "weak": Vector3(0, 0.17, 0.161), "parts": [
		[Vector3(0.18, 0.03, 0.16), Vector3(0, 0.015, 0.0), Color(0.7, 0.66, 0.55), Color(0.3, 0.28, 0.24), false],
		[Vector3(0.36, 0.27, 0.22), Vector3(0, 0.165, 0.03), Color(0.84, 0.8, 0.68), Color(0.2, 0.19, 0.18), false],
		[Vector3(0.26, 0.2, 0.12), Vector3(0, 0.15, -0.14), Color(0.8, 0.76, 0.64), Color(0.16, 0.2, 0.14), false],
		[Vector3(0.28, 0.2, 0.02), Vector3(0, 0.17, 0.15), Color(0.15, 0.55, 0.3), Color(0.3, 0.7, 0.45), true],
	]},
	{"name": "THE PRINTER", "weak": Vector3(0.13, 0.168, 0.137), "parts": [
		[Vector3(0.4, 0.15, 0.28), Vector3(0, 0.075, 0.0), Color(0.6, 0.6, 0.58), Color(0.16, 0.3, 0.2), false],
		[Vector3(0.34, 0.04, 0.2), Vector3(0, 0.17, -0.02), Color(0.74, 0.74, 0.7), Color(0.2, 0.2, 0.22), false],
		[Vector3(0.28, 0.012, 0.12), Vector3(0, 0.07, 0.2), Color(0.96, 0.96, 0.92), Color(0.85, 0.85, 0.8), false],
		[Vector3(0.1, 0.03, 0.05), Vector3(0.13, 0.165, 0.11), Color(1.0, 0.55, 0.15), Color(0.6, 0.3, 0.1), true],
	]},
	{"name": "COFFEE MAKER", "weak": Vector3(0, 0.11, 0.107), "parts": [
		[Vector3(0.22, 0.04, 0.24), Vector3(0, 0.02, 0.0), Color(0.12, 0.12, 0.13), Color(0.35, 0.33, 0.3), false],
		[Vector3(0.22, 0.3, 0.08), Vector3(0, 0.19, -0.08), Color(0.1, 0.1, 0.11), Color(0.32, 0.3, 0.28), false],
		[Vector3(0.22, 0.05, 0.2), Vector3(0, 0.365, 0.0), Color(0.14, 0.14, 0.15), Color(0.35, 0.33, 0.3), false],
		[Vector3(0.14, 0.13, 0.13), Vector3(0, 0.105, 0.04), Color(0.5, 0.32, 0.16), Color(0.65, 0.45, 0.25), true],
	]},
]

enum S { IDLE, AIM, POWER, STRIKE, RECOVER, TALLY }

var _v
var _rng := RandomNumberGenerator.new()
var _state := S.IDLE
var _t := 0.0
var _state_t := 0.0
## The machine on the desk while it's still in one piece (null once hit).
var _whole: RigidBody3D
var _obj_i := -1
var _obj_vol := 0.0
var _weak_mat: ShaderMaterial
## Materials for the current machine: [outside, guts] per part.
var _mats: Array = []
## Every loose piece (and the whole machine), oldest first.
var _bodies: Array[RigidBody3D] = []
var _hammer: Node3D
var _laser: MeshInstance3D
var _dot: MeshInstance3D
var _laser_mat: ShaderMaterial
var _hit := Vector3.ZERO
var _hit_n := Vector3.UP
var _aim := Vector2.ZERO
var _power := 0.0
var _swings := 0
var _flash := 0.0
## This play: pieces and glass off the desk.
var _pieces := 0
var _glass := 0
var _crit := false
var _bulbs: Array[ShaderMaterial] = []
var _info: Label
var _go: Button
var _meter: Control
var _meter_fill: ColorRect
var _pop: Label
var _pop_t := 0.0
var _rage_player: AudioStreamPlayer
## How long the last hit's breaking took (ms; tools/cage_check.gd reports it).
var impact_ms := 0.0


func _ready() -> void:
	super._ready()
	_rng.randomize()
	machine_id = "rage"
	frame("RAGE CAGE", Color.TRANSPARENT, Color(1.0, 0.35, 0.25))
	_rage_player = AudioStreamPlayer.new()
	add_child(_rage_player)
	_build_ui()
	if cage:
		_build()
	_update_ui()


# ---------------------------------------------------------------- controls

func _build_ui() -> void:
	_info = label("", 22, Color(1.0, 0.92, 0.55))
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 10)
	_info.position = Vector2(0, 1000)
	_info.size = Vector2(W, 76)
	add_child(_info)
	_go = button("PLAY", 40, Color(0.5, 0.08, 0.06, 0.9))
	_go.position = Vector2(60, 1090)
	_go.size = Vector2(W - 120, 150)
	_go.custom_minimum_size = Vector2(0, 150)
	_go.pressed.connect(_on_go)
	_go.set_meta("pad_default", true)
	add_child(_go)
	# The power meter up the right side: a dark slot, the fill, the PERFECT band.
	_meter = Control.new()
	_meter.position = Vector2(624, 380)
	_meter.size = Vector2(64, 560)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_meter)
	var slot := Panel.new()
	slot.add_theme_stylebox_override("panel", box(Color(0.03, 0.02, 0.02, 0.8), Color(1, 1, 1, 0.7), 4, 6))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(full(slot))
	var band := ColorRect.new()
	band.color = Color(1.0, 0.85, 0.2, 0.35)
	band.position = Vector2(6, 6)
	band.size = Vector2(52, (1.0 - ArcadeRules.RAGE_PERFECT) * 548.0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(band)
	_meter_fill = ColorRect.new()
	_meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(_meter_fill)
	var cap := label("POW", 16, Color(1, 1, 1, 0.85))
	cap.position = Vector2(-8, -34)
	cap.size = Vector2(80, 30)
	_meter.add_child(cap)
	_pop = label("", 34, Color(1.0, 0.9, 0.3))
	_pop.add_theme_color_override("font_outline_color", Color.BLACK)
	_pop.add_theme_constant_override("outline_size", 12)
	_pop.position = Vector2(20, 880)
	_pop.size = Vector2(W - 40, 60)
	_pop.modulate.a = 0.0
	add_child(_pop)


func refresh_top() -> void:
	super.refresh_top()
	if _top and hub:
		_top.text += "  STRESS %d" % hub.state.stress


func _update_ui() -> void:
	if _go == null:
		return
	match _state:
		S.IDLE:
			var free: bool = hub != null and hub.state.stress > 0
			_go.text = "PLAY: FREE\n(1 STRESS)" if free else "PLAY: 1 TOKEN"
			_go.disabled = false
			_info.text = "%d SWINGS A PLAY. KNOCK IT OFF THE DESK.\nBAD TRADING DAYS = FREE PLAYS" % ArcadeRules.RAGE_SWINGS
		S.AIM:
			_go.text = "LOCK AIM"
			_go.disabled = false
		S.POWER:
			_go.text = "SWING!"
			_go.disabled = false
		S.TALLY:
			_go.text = "..."
			_go.disabled = true
		_:
			_go.text = "SWING!"
			_go.disabled = true
	if _state != S.IDLE:
		_info.text = "SWINGS LEFT %d/%d   OFF THE DESK %d\n+%d TICKETS" % [
			_swings, ArcadeRules.RAGE_SWINGS, _pieces + _glass, ArcadeRules.rage_tickets(_pieces, _glass, false)]
	_meter.visible = _state in [S.POWER, S.STRIKE]
	refresh_top()


func _on_go() -> void:
	if cage == null:
		return
	match _state:
		S.IDLE:
			if not _pay():
				return
			_swings = ArcadeRules.RAGE_SWINGS
			_pieces = 0
			_glass = 0
			_to(S.AIM)
			sfx("click", -4.0)
		S.AIM:
			_to(S.POWER)
			sfx("click", -4.0, 1.2)
		S.POWER:
			_to(S.STRIKE)
	_update_ui()


## One play: a STRESS if you've banked one, else a token.
func _pay() -> bool:
	if hub == null:
		return true
	var how: String = hub.pay_rage() if hub.has_method("pay_rage") else ("token" if hub.spend_token() else "")
	if how == "":
		banner("OUT OF TOKENS\nLOSE A TRADING DAY\nFOR A FREE PLAY", 2.6, Color(1.0, 0.5, 0.4))
		sfx("groan", -6.0)
		return false
	sfx("coin", -4.0)
	if how == "stress":
		banner("FREE PLAY\nLET IT OUT", 1.4, Color(1.0, 0.5, 0.35))
	return true


func _to(s: int) -> void:
	_state = s
	_state_t = 0.0
	_update_ui()


# ---------------------------------------------------------------- the cage

func _build() -> void:
	_v = cage
	_v.setup({"ambient": Color(0.3, 0.26, 0.25), "fog_col": Color(0.12, 0.04, 0.04), "levels": 28.0})
	_v.set_light(0, Vector3(0, TOP - 0.06, -0.05), Color(1.0, 0.92, 0.8), 1.3, 1.0)
	_v.set_light(1, Vector3(-HALF_X + 0.04, TOP - 0.2, BACK + 0.1), Color(1.0, 0.15, 0.1), 0.9, 1.0)
	_v.set_light(2, Vector3(HALF_X - 0.04, TOP - 0.2, BACK + 0.1), Color(1.0, 0.15, 0.1), 0.9, 1.0)
	_v.set_light(3, Vector3(0, TABLE_Y + 0.25, GLASS_Z - 0.04), Color(0.9, 0.85, 0.75), 0.8, 0.7)
	_v.set_light(4, Vector3(0, TABLE_Y + 0.2, 0), Color(1.0, 0.95, 0.85), 0.01, 0.0)
	_build_room()
	_build_hammer()
	_new_object()


func _build_room() -> void:
	var v = _v
	var mid := (GLASS_Z + BACK) * 0.5
	var depth := GLASS_Z - BACK
	var h := TOP - FLOOR
	var rubber: ShaderMaterial = v.mat(Color(0.14, 0.14, 0.15), {"pattern": 1, "col2": Color(0.1, 0.1, 0.11), "texel": 14.0})
	var padding: ShaderMaterial = v.mat(Color(0.45, 0.06, 0.06), {"pattern": 4, "col2": Color(0.25, 0.02, 0.02), "texel": 9.0})
	var glass: ShaderMaterial = v.glass_mat()
	# Floor, walls (glass at the sides), padded back wall, front glass, lid.
	# The floor runs on under the walls, and is thick, so nothing slips
	# through a seam; the walls reach down into it. Nothing solid reaches out
	# past the front glass: taps on the controls (laid over the glass, just
	# in front of it) would hit it first (office.gd _occluded()).
	var z0 := BACK - 0.3
	var z1 := GLASS_Z + 0.08
	var zm := (z0 + z1) * 0.5
	v.solid(Vector3(HALF_X * 2 + 0.6, 0.4, z1 - z0), Vector3(0, FLOOR - 0.2, zm), null, null, Vector3.ZERO, 0.15, 0.8)
	v.box(Vector3(HALF_X * 2, 0.02, depth), Vector3(0, FLOOR - 0.01, mid), rubber)
	for s in [-1.0, 1.0]:
		v.solid(Vector3(0.3, h + 0.6, z1 - z0), Vector3(s * (HALF_X + 0.15), FLOOR + h * 0.5, zm), null)
		v.box(Vector3(0.006, h, depth), Vector3(s * (HALF_X + 0.003), FLOOR + h * 0.5, mid), glass)
	v.solid(Vector3(HALF_X * 2 + 0.6, h + 0.6, 0.3), Vector3(0, FLOOR + h * 0.5, BACK - 0.15), null)
	v.box(Vector3(HALF_X * 2, h, 0.02), Vector3(0, FLOOR + h * 0.5, BACK - 0.01), padding)
	v.solid(Vector3(HALF_X * 2 + 0.6, h + 0.2, z1 - GLASS_Z), Vector3(0, FLOOR - 0.2 + (h + 0.2) * 0.5, (GLASS_Z + z1) * 0.5), null)
	v.box(Vector3(HALF_X * 2, h, 0.006), Vector3(0, FLOOR + h * 0.5, GLASS_Z), glass)
	v.solid(Vector3(HALF_X * 2 + 0.6, 0.2, GLASS_Z - z0), Vector3(0, TOP + 0.1, (z0 + GLASS_Z) * 0.5), null)
	var grate: ShaderMaterial = v.mat(Color(0.2, 0.2, 0.22), {"pattern": 4, "col2": Color(0.5, 0.5, 0.52), "texel": 20.0})
	v.box(Vector3(HALF_X * 2, 0.01, depth), Vector3(0, TOP, mid), grate)
	var wall_sign: Label3D = v.text("SMASH ZONE", Vector3(0, TOP - 0.14, BACK + 0.002), 30, Color(1.0, 0.85, 0.3))
	wall_sign.outline_size = 8
	wall_sign.outline_modulate = Color(0.3, 0.0, 0.0)
	v.text("NO REFUNDS. NO FEELINGS.", Vector3(0, TOP - 0.21, BACK + 0.002), 14, Color(1.0, 0.7, 0.6))
	# Red neon strips up the back corners.
	for s in [-1.0, 1.0]:
		v.box(Vector3(0.012, h - 0.1, 0.012), Vector3(s * (HALF_X - 0.012), FLOOR + h * 0.5, BACK + 0.012), v.glow(Color(1.0, 0.15, 0.1)))
	# The little desk: a hazard-striped edge, steel legs, all solid.
	var top: ShaderMaterial = v.mat(Color(0.5, 0.36, 0.22), {"pattern": 3, "col2": Color(0.44, 0.31, 0.19), "texel": 30.0})
	var stripes: ShaderMaterial = v.mat(Color(0.95, 0.78, 0.1), {"pattern": 2, "col2": Color(0.08, 0.08, 0.08), "texel": 60.0})
	var steel: ShaderMaterial = v.mat(Color(0.5, 0.5, 0.54), {"shine": 1.2})
	v.solid(Vector3(TABLE_HX * 2, 0.04, TABLE_HZ * 2), Vector3(0, TABLE_Y - 0.02, TABLE_Z), top, null, Vector3.ZERO, 0.05, 0.7)
	v.box(Vector3(TABLE_HX * 2 + 0.004, 0.03, 0.006), Vector3(0, TABLE_Y - 0.02, TABLE_Z + TABLE_HZ + 0.002), stripes, null, Vector3(0, 0, 0.0))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			v.solid(Vector3(0.025, TABLE_Y - FLOOR - 0.04, 0.025), Vector3(x * (TABLE_HX - 0.03), (TABLE_Y - 0.04 + FLOOR) * 0.5, TABLE_Z + z * (TABLE_HZ - 0.03)), steel)
	# Chaser bulbs along the lid's front edge.
	for i in 9:
		var b: ShaderMaterial = v.glow(Color(1.0, 0.8, 0.4))
		_bulbs.append(b)
		v.ball(0.011, Vector3(-HALF_X + 0.06 + i * (HALF_X * 2 - 0.12) / 8.0, TOP - 0.02, GLASS_Z - 0.02), b, null, 6)


## The sledgehammer: a steel head (its striking face is local -z), a wooden
## handle off to the right, a red grip. It never collides: what it does is
## the hit maths in _impact().
func _build_hammer() -> void:
	var v = _v
	_hammer = Node3D.new()
	v.add_child(_hammer)
	var steel: ShaderMaterial = v.mat(Color(0.3, 0.31, 0.34), {"shine": 1.6})
	var wood: ShaderMaterial = v.mat(Color(0.62, 0.42, 0.22), {"pattern": 2, "col2": Color(0.5, 0.33, 0.17), "texel": 90.0})
	v.box(HEAD, Vector3.ZERO, steel, _hammer)
	v.box(Vector3(HEAD.x + 0.01, HEAD.y + 0.01, 0.012), Vector3(0, 0, -HEAD.z * 0.5 + 0.004), v.mat(Color(0.55, 0.56, 0.6), {"shine": 2.0}), _hammer)
	v.cyl(0.012, 0.012, 0.3, Vector3(0.17, 0, 0), wood, _hammer, Vector3(0, 0, PI / 2), 8)
	v.cyl(0.016, 0.016, 0.08, Vector3(0.29, 0, 0), v.mat(Color(0.7, 0.08, 0.06)), _hammer, Vector3(0, 0, PI / 2), 8)
	_laser_mat = v.glow(Color(1.0, 0.1, 0.05))
	var bm := BoxMesh.new()
	bm.size = Vector3(0.004, 0.004, 1.0)
	_laser = MeshInstance3D.new()
	_laser.mesh = bm
	_laser.material_override = _laser_mat
	v.add_child(_laser)
	_dot = v.box(Vector3(0.03, 0.03, 0.006), Vector3.ZERO, _laser_mat)


## A fresh machine on the desk (the last play's pieces are swept away).
func _new_object() -> void:
	for b in _bodies:
		b.queue_free()
	_bodies.clear()
	var v = _v
	var i := _rng.randi() % OBJECTS.size()
	if i == _obj_i:
		i = (i + 1) % OBJECTS.size()
	_obj_i = i
	var obj: Dictionary = OBJECTS[i]
	_mats.clear()
	_whole = v.rigid(Vector3(0, TABLE_Y + 0.12, TABLE_Z + 0.03), 3.0, 0.8, 0.05)
	_whole.can_sleep = true
	_whole.set_meta("whole", true)
	_obj_vol = 0.0
	for p in obj.parts:
		var outside: ShaderMaterial = v.glow(p[2] * 0.85) if p[4] else v.mat(p[2], {"shine": 0.6, "pattern": 3, "col2": p[2].darkened(0.08), "texel": 40.0})
		var guts: ShaderMaterial = v.glow(p[3] * 0.7) if p[4] else v.mat(p[3], {"pattern": 3, "col2": p[3].lightened(0.25), "texel": 70.0})
		_mats.append([outside, guts])
		var bs := BoxShape3D.new()
		bs.size = p[0]
		v.shape(_whole, bs, p[1])
		v.box(p[0], p[1], outside, _whole)
		_obj_vol += p[0].x * p[0].y * p[0].z
	# The weak spot: a pulsing red X stuck on the front.
	_weak_mat = v.glow(Color(1.0, 0.15, 0.1))
	for r in [PI / 4, -PI / 4]:
		v.box(Vector3(0.07, 0.012, 0.004), obj.weak, _weak_mat, _whole, Vector3(0, 0, r))
	v.add_child(_whole)
	_bodies.append(_whole)
	_crit = false


# ---------------------------------------------------------------- the swing

## Where the hammer lands if you swing now: the first thing under the aim
## along DIR (cage metres), and what it hit.
func _aim_ray() -> Dictionary:
	var t := Vector3(_aim.x, TABLE_Y, _aim.y)
	var k := (TOP - 0.08 - TABLE_Y) / -DIR.normalized().y
	var from := t - DIR.normalized() * k
	var hit: Dictionary = _v.ray(from, from + DIR.normalized() * 1.4)
	if hit.is_empty():
		return {"position": t, "normal": Vector3.UP}
	return hit


func _physics_process(delta: float) -> void:
	if cage == null:
		return
	_t += delta
	_state_t += delta
	var d := DIR.normalized()
	match _state:
		S.IDLE:
			_aim = Vector2(sin(_t * 0.7) * 0.06, TABLE_Z)
		S.AIM:
			_aim = Vector2(sin(_t * 1.7) * AIM_X, lerpf(AIM_Z0, AIM_Z1, 0.5 + 0.5 * sin(_t * 1.13)))
		S.POWER:
			# A triangle wave, bottom to top and back, about once a second.
			var ph := fmod(_state_t / 1.05, 1.0)
			_power = 1.0 - absf(ph * 2.0 - 1.0)
		S.STRIKE:
			if _state_t >= 0.07:
				_impact(_power)
				_to(S.RECOVER)
		S.RECOVER:
			if _state_t >= 0.65:
				_swings -= 1
				_to(S.AIM if _swings > 0 else S.TALLY)
		S.TALLY:
			if _state_t >= 1.8:
				_tally()
	if _state != S.STRIKE and _state != S.RECOVER:
		var ray := _aim_ray()
		_hit = ray.position
		_hit_n = ray.normal
	_count_off()
	# The hammer: raised above the aim, cocked back by the power, slams in.
	var rest := _hit - d * (0.3 + HEAD.z * 0.5)
	var cocked := rest - d * 0.1 * _power + Vector3(0, 0.05 * _power, 0)
	var strike := _hit - d * HEAD.z * 0.5
	var at := rest
	var tilt := 0.0
	match _state:
		S.POWER:
			at = cocked
			tilt = -0.5 * _power
		S.STRIKE:
			var k := clampf(_state_t / 0.07, 0.0, 1.0)
			at = cocked.lerp(strike, k * k)
			tilt = lerpf(-0.5 * _power, 0.0, k)
		S.RECOVER:
			var k := clampf(_state_t / 0.4, 0.0, 1.0)
			at = strike.lerp(rest, 1.0 - (1.0 - k) * (1.0 - k))
		S.IDLE, S.TALLY:
			at = rest + Vector3(0, 0.03 * sin(_t * 1.4), 0)
	var basis := Basis.looking_at(d, Vector3.UP)
	_hammer.transform = Transform3D(basis.rotated(basis.x, tilt), at)
	# The red line from the head to where it lands.
	var aiming := _state in [S.AIM, S.POWER]
	_laser.visible = aiming
	_dot.visible = aiming
	if aiming:
		var span := maxf(0.01, rest.distance_to(_hit))
		_laser.transform = Transform3D(Basis.looking_at(d, Vector3.UP) * Basis.from_scale(Vector3(1, 1, span)), (rest + _hit) * 0.5)
		var n := _hit_n if _hit_n.length_squared() > 0.5 else Vector3.UP
		_dot.transform = Transform3D(Basis.looking_at(-n, Vector3.FORWARD if absf(n.y) > 0.9 else Vector3.UP), _hit + n * 0.004)


## The hammer lands at _hit with `power` (0-1). Breaks what's near: the whole
## machine into its parts (and the parts near the hit into pieces), loose
## pieces into smaller ones, and throws everything near away from the hit.
func _impact(power: float) -> void:
	var us := Time.get_ticks_usec()
	var p := power
	var perfect := power >= ArcadeRules.RAGE_PERFECT
	var crit := false
	if _whole and is_instance_valid(_whole):
		var weak: Vector3 = _whole.transform * OBJECTS[_obj_i].weak
		if weak.distance_to(_hit) < WEAK_R:
			crit = true
	if crit:
		p *= ArcadeRules.RAGE_WEAK_X
		_crit = true
	var reach := 0.08 + 0.12 * minf(p, 1.2)
	var broke := 0
	var glass_hit := false
	# The loose pieces from before this swing (the whole machine's new
	# pieces have just been thrown; they don't break twice in one hit).
	var loose := _bodies.duplicate()
	if _whole and is_instance_valid(_whole) and _near(_whole, _hit) < reach:
		var r := _break_whole(p, reach)
		broke += r.x
		glass_hit = r.y > 0
	for b in loose:
		if not is_instance_valid(b) or b.is_queued_for_deletion() or b.get_meta("whole", false):
			continue
		var dist := _near(b, _hit)
		if dist > reach:
			continue
		var near := 1.0 - dist / reach
		var n := ArcadeRules.rage_cells(p, near)
		if n > 1 and float(b.get_meta("volume")) > MIN_VOL and _bodies.size() + n < MAX_BODIES:
			var made := _shatter(b, n, p, near)
			broke += made.size()
			if b.get_meta("glass"):
				glass_hit = true
			for nb in made:
				_throw(nb, p, reach)
		else:
			_throw(b, p, reach)
	_trim()
	# Feedback: the flash, the crunch, the glass, the call-outs.
	_flash = 1.0
	_v.set_light(4, _hit + Vector3(0, 0.1, 0.05), Color(1.0, 0.95, 0.85), 0.5 + 0.4 * p, 2.0)
	_rage_player.stream = SMASH
	_rage_player.volume_db = -2.0 + 3.0 * minf(p, 1.0)
	_rage_player.pitch_scale = 1.15 - 0.3 * minf(p, 1.0)
	_rage_player.play()
	if glass_hit:
		sfx("thump", -6.0, 0.8)
		var g := AudioStreamPlayer.new()
		g.stream = SHATTER
		g.volume_db = -3.0
		add_child(g)
		g.play()
		g.finished.connect(g.queue_free)
	if crit:
		banner("WEAK SPOT!", 1.2, Color(1.0, 0.4, 0.3))
		mission_event("weak")
	elif perfect:
		banner("PERFECT!", 1.1)
	if perfect:
		mission_event("perfect")
	if broke == 0:
		sfx("thump", -4.0, 1.2)
	impact_ms = (Time.get_ticks_usec() - us) / 1000.0
	if OS.has_environment("RAGE_DEBUG"):
		print("      [rage] swing p %.2f crit %s: %d pieces in %.1f ms" % [power, crit, broke, (Time.get_ticks_usec() - us) / 1000.0])


## How far the hit is from a body's surface (roughly: centre minus size).
func _near(b: RigidBody3D, at: Vector3) -> float:
	if b == _whole:
		var best := 99.0
		var local := b.transform.affine_inverse() * at
		for part in OBJECTS[_obj_i].parts:
			var half: Vector3 = part[0] * 0.5
			var q: Vector3 = local - part[1]
			var c := Vector3(clampf(q.x, -half.x, half.x), clampf(q.y, -half.y, half.y), clampf(q.z, -half.z, half.z))
			best = minf(best, q.distance_to(c))
		return best
	return maxf(0.0, b.position.distance_to(at) - float(b.get_meta("radius", 0.02)))


## The first hit on the machine: every part comes loose, and the parts near
## the hit break into pieces. Returns (pieces made, glass pieces made).
func _break_whole(p: float, reach: float) -> Vector2i:
	var obj: Dictionary = OBJECTS[_obj_i]
	var xf := _whole.transform
	var lin := _whole.linear_velocity
	var made := 0
	var glass := 0
	var room := MAX_BODIES - _bodies.size()
	for k in obj.parts.size():
		var part: Array = obj.parts[k]
		var planes := Fracture.moved(Fracture.box_planes(part[0], part[1]), xf)
		var ids := PackedInt32Array([k, k, k, k, k, k])
		var local: Vector3 = xf.affine_inverse() * _hit - part[1]
		var half: Vector3 = part[0] * 0.5
		var close := Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y), clampf(local.z, -half.z, half.z))
		var dist := local.distance_to(close)
		var near := clampf(1.0 - dist / reach, 0.0, 1.0)
		var n := mini(ArcadeRules.rage_cells(p, near), maxi(1, room - (obj.parts.size() - k)))
		var pieces: Array[Dictionary] = []
		if n > 1:
			var corners := Fracture.corners(planes)
			var seeds := Fracture.seeds(planes, corners, n, xf * (close + part[1]), 0.04 + 0.05 * minf(p, 1.2), 0.65, _rng)
			if seeds.size() > 1:
				pieces = Fracture.cells(planes, ids, seeds, DUST)
		if pieces.is_empty():
			var whole := Fracture.cell(planes, ids)
			if not whole.is_empty():
				pieces.append(whole)
		for c in pieces:
			var b := _spawn(c, k, part[4])
			b.linear_velocity = lin
			_throw(b, p, reach)
			made += 1
			room -= 1
			if part[4]:
				glass += 1
	_bodies.erase(_whole)
	_whole.queue_free()
	_whole = null
	return Vector2i(made, glass)


## Break a loose piece into n smaller ones where it lies. Returns them.
func _shatter(b: RigidBody3D, n: int, p: float, near: float) -> Array[RigidBody3D]:
	var xf := b.transform
	var planes := Fracture.moved(b.get_meta("planes"), xf)
	var ids: PackedInt32Array = b.get_meta("ids")
	var corners := Fracture.corners(planes)
	var out: Array[RigidBody3D] = []
	if corners.size() < 4:
		return out
	var seeds := Fracture.seeds(planes, corners, n, _hit, 0.03 + 0.04 * minf(p, 1.2) * near, 0.5, _rng)
	if seeds.size() < 2:
		return out
	var cells := Fracture.cells(planes, ids, seeds, DUST)
	if cells.size() < 2:
		return out
	var lin := b.linear_velocity
	var part: int = b.get_meta("part")
	var glass: bool = b.get_meta("glass")
	var counted: bool = b.get_meta("counted", false)
	for c in cells:
		var nb := _spawn(c, part, glass)
		nb.linear_velocity = lin
		# Pieces of a piece that already scored don't score again.
		nb.set_meta("counted", counted)
		out.append(nb)
	_bodies.erase(b)
	b.queue_free()
	return out


## A piece as a physics body: its convex hull for collision and a mesh with
## the part's outside on old faces and its guts on fresh break faces.
func _spawn(c: Dictionary, part: int, glass: bool) -> RigidBody3D:
	var center: Vector3 = c.center
	var lc := Fracture.local(c, center)
	var vol: float = c.volume
	var b: RigidBody3D = _v.rigid(center, clampf(vol * DENSITY, 0.03, 3.0), 0.7 if not glass else 0.4, 0.12)
	b.continuous_cd = true
	b.can_sleep = true
	b.linear_damp = 0.15
	b.angular_damp = 0.6
	var hull := ConvexPolygonShape3D.new()
	hull.points = lc.points
	_v.shape(b, hull)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(lc, part)
	b.add_child(mi)
	var radius := 0.0
	for q in lc.points:
		radius = maxf(radius, q.length())
	b.set_meta("planes", lc.planes)
	b.set_meta("ids", lc.ids)
	b.set_meta("volume", vol)
	b.set_meta("radius", radius)
	b.set_meta("part", part)
	b.set_meta("glass", glass)
	b.set_meta("counted", false)
	_v.add_child(b)
	_bodies.append(b)
	return b


## The piece's mesh: one surface per material, flat-shaded faces.
func _mesh(c: Dictionary, part: int) -> ArrayMesh:
	var verts := [PackedVector3Array(), PackedVector3Array()]
	var norms := [PackedVector3Array(), PackedVector3Array()]
	for f in Fracture.faces(c):
		var key: int = 1 if int(f.id) == Fracture.INNER else 0
		var vs: PackedVector3Array = verts[key]
		var ns: PackedVector3Array = norms[key]
		var poly: PackedVector3Array = f.poly
		var n: Vector3 = f.normal
		for i in range(1, poly.size() - 1):
			# Godot's front faces wind clockwise as you look at them.
			vs.append_array(PackedVector3Array([poly[0], poly[i + 1], poly[i]]))
			ns.append_array(PackedVector3Array([n, n, n]))
		verts[key] = vs
		norms[key] = ns
	var mesh := ArrayMesh.new()
	for key in 2:
		if verts[key].is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts[key]
		arr[Mesh.ARRAY_NORMAL] = norms[key]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mats[part][key])
	return mesh


## Fling a body away from the hit: along the swing, out from the hit, up.
func _throw(b: RigidBody3D, p: float, reach: float) -> void:
	var off := b.position - _hit
	var dist := off.length()
	var fall := clampf(1.0 - dist / (reach * 1.6), 0.15, 1.0)
	var out := Vector3(off.x, 0, off.z)
	if out.length() < 0.01:
		out = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
	var speed := (0.35 + 1.5 * minf(p, 1.3)) * fall
	var v := DIR.normalized() * speed * 0.3 + out.normalized() * speed * 0.85 + Vector3.UP * speed * 0.4
	v += Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0, 0.2), _rng.randf_range(-0.2, 0.2)) * speed
	b.linear_velocity += v
	b.angular_velocity += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * (3.0 + 9.0 * p) * fall
	b.sleeping = false


## Too many bodies for a phone: drop the oldest pieces lying on the floor.
func _trim() -> void:
	var i := 0
	while _bodies.size() > MAX_BODIES and i < _bodies.size():
		var b := _bodies[i]
		if b.get_meta("counted", false) and b.position.y < TABLE_Y - 0.1:
			_bodies.remove_at(i)
			b.queue_free()
		else:
			i += 1


## Pieces off the desk: counted once each, while a play is on.
func _count_off() -> void:
	if _state == S.IDLE:
		return
	for b in _bodies:
		if b.get_meta("counted", false) or b.get_meta("whole", false):
			continue
		var at := b.position
		var off := absf(at.x) > TABLE_HX + 0.01 or absf(at.z - TABLE_Z) > TABLE_HZ + 0.01
		if at.y < TABLE_Y - 0.05 and off:
			b.set_meta("counted", true)
			if b.get_meta("glass"):
				_glass += 1
			else:
				_pieces += 1
			sfx("coin", -14.0, 1.4 + minf(_pieces + _glass, 20) * 0.03)
			_pop.text = "+%d" % ArcadeRules.rage_tickets(_pieces, _glass, false)
			_pop_t = 0.6
			_update_ui()
		# Anything that escaped the cage somehow just goes.
		if at.y < FLOOR - 0.3 or absf(at.x) > HALF_X + 0.2:
			b.set_meta("counted", true)


## How much of the machine is still on the desk (share of its volume).
func _left_on_desk() -> float:
	var vol := 0.0
	for b in _bodies:
		if not is_instance_valid(b):
			continue
		var at := b.position
		if at.y > TABLE_Y - 0.03 and absf(at.x) <= TABLE_HX + 0.01 and absf(at.z - TABLE_Z) <= TABLE_HZ + 0.01:
			vol += _obj_vol if b == _whole else float(b.get_meta("volume", 0.0))
	return vol / maxf(_obj_vol, 0.0001)


## The play's over: pay for what came off, maybe CLEAN DESK, a new machine.
func _tally() -> void:
	var clean := _left_on_desk() < ArcadeRules.RAGE_CLEAN_LEFT
	var t := ArcadeRules.rage_tickets(_pieces, _glass, clean)
	if OS.has_environment("RAGE_DEBUG"):
		print("      [rage] %s: pieces %d glass %d left %.2f clean %s -> %d tickets, %d bodies" % [OBJECTS[_obj_i].name, _pieces, _glass, _left_on_desk(), clean, t, _bodies.size()])
	mission_event("pieces", _pieces + _glass)
	mission_event("glass", _glass)
	if clean:
		mission_event("clean")
	if t > 0:
		win(t, "rage", clean)
	if clean:
		sfx("jackpot")
		banner("CLEAN DESK!\n+%d TICKETS" % t, 2.6)
	elif t > 0:
		sfx("ding")
		banner("%d PIECES\n+%d TICKETS" % [_pieces + _glass, t], 2.2)
	else:
		sfx("groan", -6.0)
		banner("IT'S STILL\nTHERE", 1.8, Color(1.0, 0.6, 0.5))
	_new_object()
	_to(S.IDLE)


func _process(delta: float) -> void:
	super._process(delta)
	if cage == null:
		return
	_flash = maxf(0.0, _flash - delta * 4.0)
	_v.set_light(4, _hit + Vector3(0, 0.1, 0.05), Color(1.0, 0.95, 0.85), 0.5, 2.0 * _flash)
	if _weak_mat:
		_weak_mat.set_shader_parameter("emission", Color(1.0, 0.15, 0.1) * (0.6 + 0.4 * sin(_t * 7.0)))
	_laser_mat.set_shader_parameter("emission", Color(1.0, 0.1, 0.05) * (0.7 + 0.3 * sin(_t * 20.0)))
	if _meter.visible:
		var h := 548.0 * _power
		_meter_fill.position = Vector2(6, 6 + 548.0 - h)
		_meter_fill.size = Vector2(52, h)
		_meter_fill.color = Color(1.0, 0.85, 0.2) if _power >= ArcadeRules.RAGE_PERFECT else Color(1.0, 0.25 + 0.5 * _power, 0.15)
	_pop_t = maxf(0.0, _pop_t - delta)
	_pop.modulate.a = clampf(_pop_t * 3.0, 0.0, 1.0)
	var step := int(_t * (9.0 if _state != S.IDLE else 4.0))
	for i in _bulbs.size():
		_bulbs[i].set_shader_parameter("emission", Color(1.0, 0.35, 0.2) if (step + i) % 3 == 0 else Color(0.25, 0.06, 0.04))
