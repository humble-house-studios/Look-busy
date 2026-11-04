extends "res://scenes/ladder/machine.gd"
## CLAW KING: a real claw machine in a glass cage in the arcade
## (scenes/ladder/cage3d.gd: you can see the prizes from across the room).
## PLAY (1 token) starts a 15-second clock (ArcadeRules.CLAW_TIMER): steer
## the claw (on-screen arrows, stick, D-pad, arrow keys/WASD) and DROP before
## it runs out (or it drops itself). It lowers until it bumps the pile, closes its three prongs until
## they touch something, lifts, and always carries back to the chute and
## opens. Nothing is faked: the prongs are kinematic bodies and the prize is
## held only by where they closed, so a grab on the edge of a duck tips it out.
## Every fourth grab is full strength (ArcadeRules.CLAW_STRONG_EVERY); on the
## others the claw goes slack partway up (CLAW_WEAK_HOLD) and what it holds
## usually slips. Prizes that drop down the chute pay tickets and roll out
## into the tray in the cabinet's front; the TOP-SHELF STAR beats the machine.
## Each play lights one prize as the BONUS (pays double), mystery capsules
## pay 15-300 at random, two prizes from one drop pay half as much again,
## and the missions (engine/arcade_missions.gd) give you the next thing to go
## for. A prize lost near the chute gets a SO CLOSE.
## Gloria's Eye (her perk) lights the claw head green at full strength.

## The rect (cabinet metres) the seated camera frames and these controls are
## laid over: centre, size (9:16 like the controls), tilt back (looks down in).
const SEAT := {"at": Vector3(0, 1.42, 0.7), "size": Vector2(1.0, 1.7778), "tilt": -0.45}
## The cage inside, cabinet metres: x across, z back (-) to the glass (+).
const X0 := -0.43
const X1 := 0.43
const Z0 := -0.44
const Z1 := 0.31
const FLOOR := 0.9
const TOP := 1.94
## The chute: the front-left corner of the floor is a hole (x, z, w, d).
const CHUTE := Rect2(-0.43, 0.07, 0.23, 0.24)
## Where a won prize rolls out: the tray behind the little door in the base.
const TRAY := Vector3(-0.19, 0.36, 0.33)
const RAIL_Y := 1.88
const HEAD_Y := 1.74
const HEAD_R := 0.036
const HEAD_H := 0.05
const SPEED := 0.3
const ACCEL := 1.6
const DROP_SPEED := 0.42
const RISE_SPEED := 0.3
## Prong angles (radians, + = tips swing in), finger and tip lengths.
const OPEN := -1.0
const SHUT := 0.34
const SLACK := 0.32
const CLOSE_RATE := 1.4
const HINGE_R := 0.03
const FINGER := 0.12
const TIP := 0.06
const CURL := 0.8
## How far the head may ride up on its prongs when they scrape the floor.
const RIDE := 0.08
const KEEP := 14
const STAR_KEEP := 2
const CAPSULE_KEEP := 2

enum S { IDLE, DROP, CLOSE, RISE, CARRY, OPEN_UP }

var _state := S.IDLE
## Where the carriage is (x, z) and how fast it's going.
var _at := Vector2(0.15, -0.05)
var _vel := Vector2.ZERO
var _head_y := HEAD_Y
## The head's swing on its cable (x, z offset from under the carriage).
var _swing := Vector2.ZERO
var _swing_v := Vector2.ZERO
## Each prong's angle: they close separately, each stopping where it meets
## a prize.
var _angles: Array[float] = [OPEN, OPEN, OPEN]
var _ride := 0.0
var _stuck: Array = [[], [], []]
var _slack := false
var _strong := false
var _grabs := 0
var _timer := 0.0
var _rise_from := 0.0
## The prize the claw lifted off the pile (for the IT SLIPPED call), if any.
var _lifted: RigidBody3D
var _dir := Vector2.ZERO
var _stick := Vector2.ZERO
var _dpad := {}
var _keys := {}
var _pad_told := false
var _prizes: Array[RigidBody3D] = []
var _tray: Array = []
var _v
var _head: AnimatableBody3D
var _prongs: Array[AnimatableBody3D] = []
var _prong_shapes: Array = []
var _claw_rids: Array[RID] = []
var _bridge: Node3D
var _carriage: Node3D
var _cable: MeshInstance3D
var _laser: MeshInstance3D
var _shadow: MeshInstance3D
var _head_mat: ShaderMaterial
var _chute_mat: ShaderMaterial
var _bulbs: Array[ShaderMaterial] = []
var _grip: Label
var _drop: Button
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _flash := 0.0
## Paid and steering, with this many seconds left on the clock.
var _credit := false
var _clock := 0.0
var _beep := 0
## This play's glowing bonus prize, and the star that marks it.
var _bonus: RigidBody3D
var _bonus_mark: Label3D
var _bonus_at := Vector3.ZERO
## What this drop landed (tickets each), and drops landed in a row.
var _drop_won: Array[int] = []
var _settle := -1.0
var _win_streak := 0


func _ready() -> void:
	super._ready()
	_rng.randomize()
	machine_id = "claw"
	frame("CLAW KING", Color.TRANSPARENT, Color(1.0, 0.4, 0.75))
	_grip = label("", 20, Color(0.6, 1.0, 0.7))
	_grip.add_theme_color_override("font_outline_color", Color.BLACK)
	_grip.add_theme_constant_override("outline_size", 10)
	_grip.position = Vector2(0, 112)
	_grip.size = Vector2(W, 34)
	add_child(_grip)
	_controls()
	pad.hold = true
	pad.guide = [["L", "Move the claw"], ["DPAD", "Move the claw"], ["A", "Play / drop"]]
	if cage:
		_build()
	_update_grip()


func _build() -> void:
	_v = cage
	_v.setup({"ambient": Color(0.3, 0.22, 0.38), "fog_col": Color(0.12, 0.06, 0.18)})
	_v.set_light(0, Vector3(-0.3, TOP - 0.05, -0.1), Color(1.0, 0.35, 0.75), 1.3, 1.1)
	_v.set_light(1, Vector3(0.32, TOP - 0.05, -0.15), Color(0.3, 0.9, 1.0), 1.3, 1.0)
	_v.set_light(2, Vector3(0.0, TOP - 0.02, 0.25), Color(1.0, 0.95, 0.85), 1.4, 0.8)
	_v.set_light(3, Vector3(CHUTE.get_center().x, FLOOR - 0.02, CHUTE.get_center().y), Color(1.0, 0.8, 0.2), 0.45, 0.9)
	_v.set_light(4, TRAY + Vector3(0, 0.12, 0.05), Color(1.0, 0.8, 0.4), 0.35, 0.8)
	_build_box()
	_build_claw()
	_bonus_mark = _v.text("BONUS", Vector3.ZERO, 22, Color(1.0, 0.9, 0.3), null, Vector3.ZERO, 0.0018)
	_bonus_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bonus_mark.outline_size = 6
	_bonus_mark.outline_modulate = Color(0.4, 0.1, 0.0)
	_bonus_mark.no_depth_test = true
	_bonus_mark.visible = false
	for i in KEEP:
		_spawn(_kind_for(i), _random_spot(FLOOR + 0.12 + i * 0.07))


func _kind_for(i: int) -> String:
	if i < STAR_KEEP:
		return "star"
	if i < STAR_KEEP + CAPSULE_KEEP:
		return "capsule"
	return "bear" if i % 3 == 0 else "duck"


func _random_spot(y: float) -> Vector3:
	for i in 20:
		var p := Vector3(_rng.randf_range(X0 + 0.09, X1 - 0.09), y, _rng.randf_range(Z0 + 0.09, Z1 - 0.09))
		if p.x > CHUTE.end.x + 0.1 or p.z < CHUTE.position.y - 0.1:
			return p
	return Vector3(0.2, y, -0.2)


# ---------------------------------------------------------------- building

func _build_box() -> void:
	var v = _v
	var plush: ShaderMaterial = v.mat(Color(0.55, 0.15, 0.45), {"pattern": 3, "col2": Color(0.8, 0.3, 0.65), "texel": 60.0})
	var wall: ShaderMaterial = v.mat(Color(0.12, 0.05, 0.2), {"pattern": 4, "col2": Color(0.9, 0.3, 0.8), "texel": 10.0})
	var chrome: ShaderMaterial = v.mat(Color(0.7, 0.7, 0.78), {"shine": 1.4})
	var hazard: ShaderMaterial = v.mat(Color(1.0, 0.8, 0.1), {"pattern": 1, "col2": Color(0.08, 0.06, 0.04), "texel": 28.0})
	var glass: ShaderMaterial = v.glass_mat()
	var w := X1 - X0
	var d := Z1 - Z0
	# The floor (thick, so nothing falls through), with the chute cut out.
	var right_w := X1 - CHUTE.end.x
	v.solid(Vector3(right_w, 0.2, d), Vector3(CHUTE.end.x + right_w * 0.5, FLOOR - 0.1, (Z0 + Z1) * 0.5), plush, null, Vector3.ZERO, 0.05, 0.9)
	var back_d := CHUTE.position.y - Z0
	v.solid(Vector3(CHUTE.size.x, 0.2, back_d), Vector3(CHUTE.get_center().x, FLOOR - 0.1, Z0 + back_d * 0.5), plush, null, Vector3.ZERO, 0.05, 0.9)
	# The chute: a hazard-striped lip, a glowing well under it.
	v.solid(Vector3(0.02, 0.05, CHUTE.size.y), Vector3(CHUTE.end.x + 0.01, FLOOR + 0.025, CHUTE.get_center().y), hazard)
	v.solid(Vector3(CHUTE.size.x + 0.02, 0.05, 0.02), Vector3(CHUTE.get_center().x + 0.01, FLOOR + 0.025, CHUTE.position.y - 0.01), hazard)
	_chute_mat = v.glow(Color(0.9, 0.6, 0.1))
	v.box(Vector3(CHUTE.size.x, 0.004, CHUTE.size.y), Vector3(CHUTE.get_center().x, FLOOR - 0.035, CHUTE.get_center().y), _chute_mat)
	v.text("PRIZE", Vector3(CHUTE.get_center().x, FLOOR + 0.026, CHUTE.end.y + 0.001), 14, Color(1.0, 0.85, 0.3))
	# Back wall (art), ceiling, and the glass: sides and front. Colliders are
	# thick (outward), the panes you see are thin.
	v.solid(Vector3(w + 0.1, TOP - FLOOR + 0.1, 0.2), Vector3(0, (FLOOR + TOP) * 0.5, Z0 - 0.1), wall)
	v.solid(Vector3(w + 0.1, 0.2, d + 0.1), Vector3(0, TOP + 0.1, (Z0 + Z1) * 0.5), v.mat(Color(0.08, 0.04, 0.12)))
	for s in [-1.0, 1.0]:
		var x: float = X1 if s > 0 else X0
		v.solid(Vector3(0.2, TOP - FLOOR, d), Vector3(x + s * 0.11, (FLOOR + TOP) * 0.5, (Z0 + Z1) * 0.5), null)
		v.box(Vector3(0.006, TOP - FLOOR, d + 0.01), Vector3(x + s * 0.012, (FLOOR + TOP) * 0.5, (Z0 + Z1) * 0.5), glass)
	v.solid(Vector3(w + 0.1, TOP - FLOOR, 0.2), Vector3(0, (FLOOR + TOP) * 0.5, Z1 + 0.11), null)
	v.box(Vector3(w + 0.03, TOP - FLOOR, 0.006), Vector3(0, (FLOOR + TOP) * 0.5, Z1 + 0.012), glass)
	# Back wall art: the marquee in neon, a slogan.
	v.text("CLAW KING", Vector3(0.0, 1.62, Z0 + 0.003), 40, Color(1.0, 0.45, 0.85))
	v.text("EVERY GRAB IS A GAMBLE", Vector3(0.0, 1.53, Z0 + 0.003), 12, Color(0.4, 1.0, 0.95))
	var pink: ShaderMaterial = v.glow(Color(1.0, 0.35, 0.75))
	var cyan: ShaderMaterial = v.glow(Color(0.3, 0.95, 1.0))
	v.box(Vector3(w - 0.04, 0.012, 0.012), Vector3(0, 1.72, Z0 + 0.01), pink)
	v.box(Vector3(w - 0.04, 0.012, 0.012), Vector3(0, 1.46, Z0 + 0.01), cyan)
	# Light strips in the ceiling, chaser bulbs along the top of the glass.
	v.box(Vector3(w - 0.1, 0.01, 0.03), Vector3(0, TOP - 0.004, 0.22), v.glow(Color(1.0, 0.95, 0.85)))
	for x in [X0 + 0.06, X1 - 0.06]:
		v.box(Vector3(0.03, 0.01, d - 0.1), Vector3(x, TOP - 0.004, (Z0 + Z1) * 0.5), pink if x < 0 else cyan)
	for i in 11:
		var b: ShaderMaterial = v.glow(Color(1.0, 0.9, 0.4))
		_bulbs.append(b)
		v.ball(0.012, Vector3(X0 + 0.04 + i * (w - 0.08) / 10.0, TOP - 0.03, Z1 - 0.005), b, null, 6)
	# Gantry rails along the top.
	for z in [Z0 + 0.03, Z1 - 0.03]:
		v.box(Vector3(w, 0.022, 0.022), Vector3(0, RAIL_Y, z), chrome)
	# The prize tray in the base: a floor, walls and a little glass door.
	var tray_mat: ShaderMaterial = v.mat(Color(0.25, 0.08, 0.22), {"pattern": 3, "col2": Color(0.4, 0.12, 0.35), "texel": 40.0})
	v.solid(Vector3(0.26, 0.04, 0.23), Vector3(TRAY.x, 0.16, 0.315), tray_mat)
	v.solid(Vector3(0.26, 0.3, 0.04), Vector3(TRAY.x, 0.32, 0.185), null)
	for s in [-1.0, 1.0]:
		v.solid(Vector3(0.04, 0.3, 0.23), Vector3(TRAY.x + s * 0.15, 0.32, 0.315), null)
	v.solid(Vector3(0.26, 0.3, 0.04), Vector3(TRAY.x, 0.32, 0.452), null)
	v.box(Vector3(0.26, 0.27, 0.004), Vector3(TRAY.x, 0.32, 0.433), glass)


## The claw: a bridge across the rails, a carriage riding it, a cable, and
## the head with three prongs. The head and prongs are kinematic bodies: they
## shove prizes, and whatever they close around is carried by contact alone.
func _build_claw() -> void:
	var v = _v
	var chrome: ShaderMaterial = v.mat(Color(0.75, 0.75, 0.82), {"shine": 1.6})
	var dark: ShaderMaterial = v.mat(Color(0.2, 0.2, 0.25), {"shine": 0.6})
	_head_mat = v.mat(Color(0.8, 0.8, 0.86), {"shine": 1.6})
	_bridge = Node3D.new()
	v.add_child(_bridge)
	v.box(Vector3(0.026, 0.026, Z1 - Z0), Vector3(0, RAIL_Y, (Z0 + Z1) * 0.5), chrome, _bridge)
	_carriage = Node3D.new()
	_bridge.add_child(_carriage)
	v.box(Vector3(0.07, 0.04, 0.07), Vector3(0, RAIL_Y - 0.02, 0), dark, _carriage)
	_cable = v.box(Vector3(0.005, 1.0, 0.005), Vector3.ZERO, chrome)
	_head = AnimatableBody3D.new()
	_head.sync_to_physics = false
	v._layers(_head)
	var hs := CylinderShape3D.new()
	hs.radius = HEAD_R
	hs.height = HEAD_H
	v.shape(_head, hs)
	v.cyl(HEAD_R * 0.8, HEAD_R, HEAD_H, Vector3.ZERO, _head_mat, _head, Vector3.ZERO, 12)
	v.cyl(0.012, 0.012, 0.02, Vector3(0, HEAD_H * 0.5 + 0.01, 0), dark, _head)
	v.add_child(_head)
	_claw_rids.append(_head.get_rid())
	for i in 3:
		var p := AnimatableBody3D.new()
		p.sync_to_physics = false
		v._layers(p)
		var pm := PhysicsMaterial.new()
		pm.friction = 1.0
		p.physics_material_override = pm
		var finger := BoxShape3D.new()
		finger.size = Vector3(0.014, FINGER, 0.016)
		var tip := BoxShape3D.new()
		tip.size = Vector3(0.016, TIP, 0.016)
		var f_at := Transform3D(Basis(), Vector3(0, -FINGER * 0.5, 0))
		var t_basis := Basis(Vector3.RIGHT, CURL)
		var t_at := Transform3D(t_basis, Vector3(0, -FINGER, 0) + t_basis * Vector3(0, -TIP * 0.5, 0))
		var fcs: CollisionShape3D = v.shape(p, finger)
		fcs.transform = f_at
		var tcs: CollisionShape3D = v.shape(p, tip)
		tcs.transform = t_at
		v.box(finger.size, Vector3.ZERO, chrome, p).transform = f_at
		v.box(tip.size, Vector3.ZERO, chrome, p).transform = t_at
		v.ball(0.011, Vector3.ZERO, dark, p, 6)
		v.add_child(p)
		_prongs.append(p)
		_prong_shapes.append([[finger, f_at], [tip, t_at]])
		_claw_rids.append(p.get_rid())
	_laser = v.box(Vector3(0.003, 1.0, 0.003), Vector3.ZERO, v.glow(Color(1.0, 0.1, 0.15)))
	_shadow = v.cyl(0.045, 0.045, 0.002, Vector3.ZERO, v.mat(Color(0.03, 0.0, 0.05)), null, Vector3.ZERO, 12)
	_place_claw()


func _spawn(kind: String, at: Vector3) -> void:
	var v = _v
	var r: float = {"duck": 0.068, "bear": 0.075, "capsule": 0.064}.get(kind, 0.07)
	var b: RigidBody3D = v.rigid(at, 0.18, 1.0, 0.05)
	b.rotation = Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf() * TAU, _rng.randf_range(-0.4, 0.4))
	b.set_meta("kind", kind)
	b.set_meta("r", r)
	b.physics_material_override.rough = true
	b.angular_damp = 2.0
	b.linear_damp = 0.3
	b.continuous_cd = true
	var body := SphereShape3D.new()
	body.radius = r
	v.shape(b, body)
	match kind:
		"duck":
			var head := SphereShape3D.new()
			head.radius = r * 0.62
			v.shape(b, head, Vector3(0, r * 0.8, r * 0.3))
			var yellow: ShaderMaterial = v.mat(Color(1.0, 0.85, 0.15), {"shine": 0.5})
			v.ball(r, Vector3.ZERO, yellow, b)
			v.ball(r * 0.62, Vector3(0, r * 0.8, r * 0.3), yellow, b)
			v.box(Vector3(r * 0.5, r * 0.18, r * 0.45), Vector3(0, r * 0.72, r * 0.95), v.mat(Color(1.0, 0.45, 0.05)), b)
			v.box(Vector3(r * 0.5, r * 0.25, r * 0.6), Vector3(0, r * 0.2, -r * 0.95), yellow, b, Vector3(-0.5, 0, 0))
			for s in [-1.0, 1.0]:
				v.ball(r * 0.1, Vector3(s * r * 0.3, r * 0.98, r * 0.72), v.mat(Color(0.02, 0.02, 0.02)), b, 4)
		"bear":
			var head := SphereShape3D.new()
			head.radius = r * 0.66
			v.shape(b, head, Vector3(0, r * 0.95, 0))
			var fur: ShaderMaterial = v.mat(Color(0.6, 0.38, 0.2), {"pattern": 3, "col2": Color(0.5, 0.3, 0.15), "texel": 120.0})
			v.ball(r, Vector3.ZERO, fur, b)
			v.ball(r * 0.66, Vector3(0, r * 0.95, 0), fur, b)
			for s in [-1.0, 1.0]:
				v.ball(r * 0.26, Vector3(s * r * 0.5, r * 1.45, 0), fur, b, 6)
				v.ball(r * 0.08, Vector3(s * r * 0.24, r * 1.05, r * 0.6), v.mat(Color(0.02, 0.02, 0.02)), b, 4)
				v.ball(r * 0.3, Vector3(s * r * 0.7, -r * 0.55, r * 0.35), fur, b, 6)
			v.ball(r * 0.25, Vector3(0, r * 0.85, r * 0.6), v.mat(Color(0.9, 0.75, 0.55)), b, 6)
			v.box(Vector3(r * 0.9, r * 0.25, 0.01), Vector3(0, r * 0.35, r * 0.95), v.mat(Color(0.9, 0.15, 0.3)), b)
		"capsule":
			var shell: ShaderMaterial = v.mat(Color(0.3, 0.85, 1.0), {"shine": 2.2, "glow": Color(0.04, 0.12, 0.18)})
			var cap: ShaderMaterial = v.mat(Color(1.0, 0.35, 0.7), {"shine": 2.2})
			v.ball(r, Vector3.ZERO, shell, b, 10)
			v.ball(r * 1.01, Vector3(0, r * 0.45, 0), cap, b, 10).scale = Vector3(1, 0.6, 1)
			v.cyl(r * 1.04, r * 1.04, r * 0.18, Vector3.ZERO, v.mat(Color(0.95, 0.95, 1.0), {"shine": 1.0}), b, Vector3.ZERO, 12)
			v.text("?", Vector3(0, -r * 0.2, r + 0.002), 34, Color(1, 1, 1), b, Vector3.ZERO, 0.0016)
		_:
			var gold: ShaderMaterial = v.mat(Color(1.0, 0.8, 0.1), {"shine": 2.0, "glow": Color(0.35, 0.25, 0.0)})
			v.ball(r, Vector3.ZERO, gold, b, 6)
			for k in 5:
				var a := k * TAU / 5.0
				v.cyl(0.0, r * 0.38, r * 0.6, Vector3(sin(a), cos(a), 0) * r * 1.05, gold, b, Vector3(0, 0, -a), 5)
			v.text("*", Vector3(0, 0, r + 0.002), 30, Color(1, 1, 0.8), b, Vector3.ZERO, 0.0015)
	v.add_child(b)
	_prizes.append(b)


func _controls() -> void:
	# Arrow keys on the left (back on top, then left / front / right),
	# DROP on the right. Translucent, over the cabinet's base.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(26, 1012)
	grid.size = Vector2(390, 250)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	var dirs := [null, ["^", Vector2(0, -1)], null, ["<", Vector2(-1, 0)], ["v", Vector2(0, 1)], [">", Vector2(1, 0)]]
	for d in dirs:
		if d == null:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(120, 116)
			grid.add_child(gap)
			continue
		var b := button(d[0], 44, Color(0.2, 0.12, 0.3, 0.82))
		b.custom_minimum_size = Vector2(120, 116)
		grid.add_child(b)
		var dir: Vector2 = d[1]
		b.button_down.connect(func(): _dir = dir)
		b.button_up.connect(func(): _dir = Vector2.ZERO)
	_drop = button("PLAY\n1 TOKEN", 36, Color(0.55, 0.1, 0.3, 0.88))
	_drop.position = Vector2(436, 1012)
	_drop.size = Vector2(258, 242)
	_drop.custom_minimum_size = Vector2(258, 242)
	_drop.pressed.connect(_on_drop)
	_drop.set_meta("pad_default", true)
	_drop.set_meta("pad_button", JOY_BUTTON_A)
	add_child(_drop)


# ---------------------------------------------------------------- input

const PAD_DEAD := 0.25
const DPAD := {
	JOY_BUTTON_DPAD_LEFT: Vector2(-1, 0), JOY_BUTTON_DPAD_RIGHT: Vector2(1, 0),
	JOY_BUTTON_DPAD_UP: Vector2(0, -1), JOY_BUTTON_DPAD_DOWN: Vector2(0, 1),
}
const KEYS := {
	KEY_LEFT: Vector2(-1, 0), KEY_RIGHT: Vector2(1, 0), KEY_UP: Vector2(0, -1), KEY_DOWN: Vector2(0, 1),
	KEY_A: Vector2(-1, 0), KEY_D: Vector2(1, 0), KEY_W: Vector2(0, -1), KEY_S: Vector2(0, 1),
}


## The controller (pushed in by the office while you sit here) and the
## keyboard steer the claw directly. Events only, never Input polling.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y:
			var v: float = event.axis_value if absf(event.axis_value) > PAD_DEAD else 0.0
			if event.axis == JOY_AXIS_LEFT_X:
				_stick.x = v
			else:
				_stick.y = v
			_tell_pad()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and DPAD.has(event.button_index):
		_dpad[event.button_index] = event.pressed
		_tell_pad()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and not event.echo:
		if KEYS.has(event.keycode):
			_keys[event.keycode] = event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			_on_drop()
			get_viewport().set_input_as_handled()


func _tell_pad() -> void:
	if pad:
		pad.active = true
	if not _pad_told and pad:
		_pad_told = true
		pad.show_guide()


## Standing up: let go of everything (the release won't reach us any more).
func set_active(on: bool) -> void:
	super.set_active(on)
	if not on:
		_dir = Vector2.ZERO
		_stick = Vector2.ZERO
		_dpad.clear()
		_keys.clear()


## Where the controls are pushing: on-screen arrows, stick, D-pad, keys.
func _steer() -> Vector2:
	var v := _dir + _stick
	for b in _dpad:
		if _dpad[b]:
			v += DPAD[b]
	for k in _keys:
		if _keys[k]:
			v += KEYS[k]
	return v.limit_length(1.0)


## Nudge the claw while it's waiting (tools and tests).
func _nudge(dx: float, dz := 0.0) -> void:
	if _state == S.IDLE:
		_at += Vector2(dx, dz)
		_at = _clamped(_at)


## The open claw (0.14 m round) can't go into the corners.
func _clamped(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, X0 + 0.11, X1 - 0.11), clampf(p.y, Z0 + 0.11, Z1 - 0.11))


## The big button: PLAY (a token, starts the clock), then DROP.
func _on_drop() -> void:
	if _state != S.IDLE or cage == null or _settle > 0.0:
		return
	if not _credit:
		if not pay_token():
			return
		_credit = true
		_clock = ArcadeRules.CLAW_TIMER
		_beep = 5
		_pick_bonus()
		sfx("chime", -6.0)
		return
	_credit = false
	_drop_won.clear()
	_strong = ArcadeRules.claw_strong(_grabs)
	_grabs += 1
	_state = S.DROP
	_slack = false
	_ride = 0.0
	_lifted = null
	_dir = Vector2.ZERO
	sfx("click")


# ---------------------------------------------------------------- the claw

## The head, hanging under the carriage (plus its swing), in cage metres.
func _head_pos() -> Vector3:
	return Vector3(_at.x + _swing.x, _head_y, _at.y + _swing.y)


## Prong i's transform (cage metres) with its prongs at `angle`.
func _prong_xf(i: int, head: Vector3, angle: float) -> Transform3D:
	var a := i * TAU / 3.0 + sin(_t * 0.6) * 0.1
	var hinge := Vector3(sin(a) * HINGE_R, -HEAD_H * 0.5 - 0.004, cos(a) * HINGE_R)
	return Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, angle), head + hinge)


## The prizes prong i would cut into at transform xf (walls and floor are
## left to _below_floor: a prong scraping them never stops it closing).
func _prong_hits(i: int, xf: Transform3D, exclude: Array[RID]) -> Array:
	var out := []
	# The curled tips do the gripping (the fingers above just ride along).
	for s in [_prong_shapes[i][1]]:
		for c in _v.hits(s[0], xf * s[1], exclude):
			if c is RigidBody3D and not c in out:
				out.append(c)
	return out


## How far prong i's tip would be under the floor (0 if it's above it).
func _below_floor(xf: Transform3D) -> float:
	var knuckle := xf * Vector3(0, -FINGER, 0)
	var tip := knuckle + xf.basis * (Basis(Vector3.RIGHT, CURL) * Vector3(0, -TIP, 0))
	return maxf(0.0, FLOOR + 0.006 - minf(knuckle.y, tip.y))


## Swing the prongs toward `target`. Closing, each prong stops as soon as it
## would cut into a prize, so it grips, never crushes (prizes it was already
## shoved into when it came down don't count: it closes through them and the
## physics pushes them aside). A prong scraping the floor lifts the head a
## little instead (`ride`), so it scoops underneath.
func _move_prongs(target: float, rate: float, delta: float, ride := false) -> void:
	var head := _head_pos()
	var scrape := false
	for i in 3:
		if target <= _angles[i]:
			_angles[i] = maxf(target, _angles[i] - rate * delta)
			continue
		var next := minf(target, _angles[i] + rate * delta)
		var xf := _prong_xf(i, head, next)
		if _below_floor(xf) > 0.0:
			scrape = true
			continue
		var ex: Array[RID] = _claw_rids.duplicate()
		ex.append_array(_stuck[i])
		if _prong_hits(i, xf, ex).is_empty():
			_angles[i] = next
	if scrape and ride and _ride < RIDE:
		_ride += 0.004
		_head_y += 0.004


## Coming down: note what each prong is already pushed into.
func _note_stuck() -> void:
	var head := _head_pos()
	for i in 3:
		_stuck[i].clear()
		for c in _prong_hits(i, _prong_xf(i, head, _angles[i]), _claw_rids):
			_stuck[i].append(c.get_rid())


## Lowering: stop when the head sits on something, or the open prongs would
## dig into the floor or a wall (prizes in their way just get shoved aside).
func _blocked_below(next_y: float) -> bool:
	if next_y <= FLOOR + HEAD_H * 0.5 + 0.02:
		return true
	var head := _head_pos()
	var hit: Dictionary = _v.ray(head, head - Vector3(0, HEAD_H * 0.5 + 0.008, 0), _claw_rids)
	if hit:
		return true
	var low := Vector3(head.x, next_y, head.z)
	for i in 3:
		if _below_floor(_prong_xf(i, low, _angles[i])) > 0.0:
			return true
	return false


func _physics_process(delta: float) -> void:
	if cage == null:
		return
	_t += delta
	var want := Vector2.ZERO
	match _state:
		S.IDLE:
			_move_prongs(OPEN, 2.0, delta)
			if _credit:
				want = _steer() * SPEED
				_clock -= delta
				if _clock <= _beep and _beep > 0:
					sfx("click", -4.0, 1.6)
					_beep -= 1
				if _clock <= 0.0:
					_on_drop()
			elif _settle > 0.0:
				_settle -= delta
				if _settle <= 0.0:
					_end_drop()
		S.DROP:
			var next := _head_y - DROP_SPEED * delta
			if _blocked_below(next):
				_state = S.CLOSE
				_timer = 0.0
				_note_stuck()
				sfx("click", -8.0, 0.7)
			else:
				_head_y = next
		S.CLOSE:
			_timer += delta
			_move_prongs(SHUT, CLOSE_RATE, delta, true)
			if _timer > 1.0:
				_state = S.RISE
				_rise_from = _head_y
				_timer = 0.0
				sfx("thump", -10.0, 1.3)
		S.RISE:
			_timer += delta
			_head_y = minf(HEAD_Y, _head_y + RISE_SPEED * delta)
			var up := (_head_y - _rise_from) / maxf(0.01, HEAD_Y - _rise_from)
			if not _strong and up > ArcadeRules.CLAW_WEAK_HOLD and not _slack:
				# The weak grab: power drops and the prongs go slack.
				_slack = true
				for i in 3:
					_angles[i] -= SLACK
				sfx("click", -6.0, 0.6)
			if not _slack:
				_move_prongs(SHUT, CLOSE_RATE * 0.5, delta)
			if _timer > 0.35 and _lifted == null:
				_lifted = _in_claw()
			if _head_y >= HEAD_Y:
				_state = S.CARRY
		S.CARRY:
			var home := Vector2(CHUTE.get_center().x + 0.01, CHUTE.get_center().y)
			want = (home - _at).limit_length(SPEED)
			if _at.distance_to(home) < 0.01 and _vel.length() < 0.05:
				_state = S.OPEN_UP
				_timer = 0.0
				sfx("click", -6.0, 0.8)
			elif not _slack:
				_move_prongs(SHUT, CLOSE_RATE * 0.5, delta)
		S.OPEN_UP:
			_timer += delta
			_move_prongs(OPEN, 2.5, delta)
			if _timer > 0.9:
				_state = S.IDLE
				_settle = 0.8
				_update_grip()
	# The carriage speeds up and slows down; the head swings on its cable.
	var was := _vel
	_vel = _vel.move_toward(want, ACCEL * delta)
	if _state == S.CARRY and _at.distance_to(Vector2(CHUTE.get_center().x + 0.01, CHUTE.get_center().y)) < 0.04:
		_vel = _vel.limit_length(_at.distance_to(Vector2(CHUTE.get_center().x + 0.01, CHUTE.get_center().y)) * 4.0)
	_at = _clamped(_at + _vel * delta)
	var acc := (_vel - was) / maxf(delta, 0.001)
	var cable := maxf(0.08, RAIL_Y - _head_y)
	_swing_v += (-_swing * (9.8 / cable) - acc - _swing_v * 2.2) * delta
	_swing = (_swing + _swing_v * delta).limit_length(0.035)
	_place_claw()
	if _state != S.IDLE and _state != S.DROP:
		_wake_near()
	_check_slip()
	_collect()


func _place_claw() -> void:
	var head := _head_pos()
	_head.transform = Transform3D(Basis(Vector3.UP, sin(_t * 0.6) * 0.1), head)
	for i in 3:
		_prongs[i].transform = _prong_xf(i, head, _angles[i])


## Physics lets resting bodies sleep, and a sleeping prize wouldn't notice
## the prongs opening under it: keep the ones by the claw awake.
func _wake_near() -> void:
	var head := _head_pos()
	for p in _prizes:
		if p.sleeping and p.position.distance_to(head) < 0.3:
			p.sleeping = false


## The prize sitting in the prongs right now, if any.
func _in_claw() -> RigidBody3D:
	var head := _head_pos()
	for p in _prizes:
		var off := p.position - head
		if off.y < 0.0 and off.y > -0.2 and Vector2(off.x, off.z).length() < 0.06:
			return p
	return null


func _check_slip() -> void:
	if _lifted == null or _state not in [S.RISE, S.CARRY]:
		return
	if not is_instance_valid(_lifted) or _lifted.position.y < _head_y - 0.3:
		_lifted = null
		var up := (_head_y - _rise_from) / maxf(0.01, HEAD_Y - _rise_from)
		if _state == S.CARRY or up > 0.75:
			banner("SO CLOSE!", 1.6, Color(1.0, 0.5, 0.4))
			sfx("sad_trombone", -8.0)
		else:
			banner("IT SLIPPED!", 1.2, Color(1.0, 0.6, 0.5))
			sfx("groan", -10.0)


## Prizes that fell down the chute pay out and roll into the tray; the cage
## refills from the top. Anything that escapes the cage comes back in.
func _collect() -> void:
	for p in _prizes.duplicate():
		var at: Vector3 = p.position
		if at.y < FLOOR - 0.12 and at.x < CHUTE.end.x and at.z > CHUTE.position.y:
			_prizes.erase(p)
			if p == _lifted:
				_lifted = null
			_won(p)
		elif at.y < 0.0 or at.y > 3.0 or absf(at.x) > 1.0 or absf(at.z) > 1.0:
			p.position = _random_spot(TOP - 0.15)
			p.linear_velocity = Vector3.ZERO
	for e in _tray.duplicate():
		e.t -= get_physics_process_delta_time()
		if e.t <= 0.0:
			_tray.erase(e)
			e.body.queue_free()


func _won(p: RigidBody3D) -> void:
	var kind: String = p.get_meta("kind")
	var t := ArcadeRules.claw_tickets(kind)
	var beats := ArcadeRules.claw_beats(kind)
	var line := "%s!" % ArcadeRules.CLAW_PRIZES[kind].name
	if kind == "capsule":
		t = ArcadeRules.claw_capsule(_rng.randf())
		line = "MYSTERY CAPSULE:\n%s" % ("JACKPOT!" if t >= 150 else ("NICE!" if t >= 80 else "OPENED"))
	var bonus := p == _bonus
	if bonus:
		t *= ArcadeRules.CLAW_BONUS_X
		line = "BONUS PRIZE x%d!\n%s" % [ArcadeRules.CLAW_BONUS_X, ArcadeRules.CLAW_PRIZES[kind].name]
		_bonus = null
		_bonus_mark.visible = false
	win(t, "claw", beats)
	_drop_won.append(t)
	sfx("jackpot" if beats or bonus or t >= 80 else "ding")
	banner("%s\n+%d TICKETS" % [line, t], 2.4)
	_flash = 1.0
	mission_event("won")
	if bonus:
		mission_event("bonus")
	if kind == "capsule":
		mission_event("capsule")
	# Out into the tray behind the little door, to look at for a bit.
	for e in _tray:
		e.t = minf(e.t, 0.5)
	p.position = TRAY
	p.linear_velocity = Vector3(0, -0.2, 0.25)
	_tray.append({"body": p, "t": 6.0})
	var stars := 0
	for q in _prizes:
		if q.get_meta("kind") == "star":
			stars += 1
	var caps := 0
	for q in _prizes:
		if q.get_meta("kind") == "capsule":
			caps += 1
	var kind_new := "star" if stars < STAR_KEEP else ("capsule" if caps < CAPSULE_KEEP else ("bear" if _rng.randf() < 0.35 else "duck"))
	_spawn(kind_new, _random_spot(TOP - 0.15))


## A play's bonus prize: one on the pile the claw can reach (not the stars).
func _pick_bonus() -> void:
	var options: Array[RigidBody3D] = []
	for p in _prizes:
		var at := p.position
		if p.get_meta("kind") != "star" and at.y < FLOOR + 0.25 and absf(at.x) < X1 - 0.1 \
				and at.z > Z0 + 0.1 and at.z < Z1 - 0.1 and (at.x > CHUTE.end.x + 0.08 or at.z < CHUTE.position.y - 0.08):
			options.append(p)
	_bonus = options[_rng.randi() % options.size()] if not options.is_empty() else null
	_bonus_mark.visible = _bonus != null


## A drop is over (and whatever it knocked loose has landed): doubles,
## streaks, the bonus moves on.
func _end_drop() -> void:
	if _drop_won.size() >= 2:
		var sum := 0
		for t in _drop_won:
			sum += t
		var extra := int(sum * (ArcadeRules.CLAW_DOUBLE_X - 1.0))
		win(extra, "", false)
		banner("DOUBLE GRAB!\n+%d MORE" % extra, 2.6, Color(1.0, 0.6, 1.0))
		sfx("laugh_big", -6.0)
		mission_event("double", _drop_won.size())
	if _drop_won.is_empty():
		_win_streak = 0
	else:
		_win_streak += 1
		mission_event("streak", _win_streak)
	_drop_won.clear()
	_bonus = null
	_bonus_mark.visible = false
	_update_grip()


# ---------------------------------------------------------------- drawing

func _process(delta: float) -> void:
	super._process(delta)
	if cage == null:
		return
	var head := _head_pos()
	_bridge.position.x = _at.x
	_carriage.position.z = _at.y
	var top := RAIL_Y - 0.03
	var len := maxf(0.01, top - (head.y + HEAD_H * 0.5 + 0.02))
	_cable.position = Vector3((_at.x + head.x) * 0.5, top - len * 0.5, (_at.y + head.z) * 0.5)
	_cable.scale = Vector3(1, len, 1)
	_cable.rotation = Vector3(-(_swing.y) / maxf(len, 0.1), 0, _swing.x / maxf(len, 0.1))
	# The aiming laser and the claw's shadow on whatever is below.
	var hit: Dictionary = _v.ray(head - Vector3(0, HEAD_H * 0.5, 0), Vector3(head.x, FLOOR - 0.2, head.z), _claw_rids)
	var ground: float = hit.position.y if hit else FLOOR - 0.035
	_laser.visible = _state == S.IDLE and _credit
	# The bonus prize: a pulsing tag over it, and a gold light on it.
	if _bonus and is_instance_valid(_bonus):
		_bonus_mark.position = _bonus.position + Vector3(0, 0.13, 0)
		_bonus_mark.scale = Vector3.ONE * (1.0 + 0.15 * sin(_t * 8.0))
		if _bonus.position.distance_to(_bonus_at) > 0.01:
			_bonus_at = _bonus.position
			_v.set_light(5, _bonus_at + Vector3(0, 0.1, 0.05), Color(1.0, 0.85, 0.3), 0.22, 1.4)
	elif _bonus_at != Vector3.ZERO:
		_bonus_at = Vector3.ZERO
		_v.set_light(5, Vector3.ZERO, Color.BLACK, 0.0)
	# The big button and the clock.
	if _credit:
		_drop.text = "DROP!\n%d" % ceili(maxf(_clock, 0.0))
		_drop.modulate = Color(1.4, 1.0, 1.0) if _clock < 5.0 and int(_clock * 4.0) % 2 == 0 else Color.WHITE
	elif _state == S.IDLE and _settle <= 0.0:
		_drop.text = "PLAY\n1 TOKEN"
		_drop.modulate = Color.WHITE
	else:
		_drop.text = "..."
		_drop.modulate = Color(0.7, 0.7, 0.7)
	var drop := maxf(0.01, head.y - HEAD_H * 0.5 - ground)
	_laser.position = Vector3(head.x, ground + drop * 0.5, head.z)
	_laser.scale = Vector3(1, drop, 1)
	_shadow.position = Vector3(head.x, ground + 0.002, head.z)
	var s := clampf(1.4 - (head.y - ground) * 0.6, 0.5, 1.4)
	_shadow.scale = Vector3(s, 1, s)
	var lit: bool = hub != null and hub.state.has("gloria_eye") and ArcadeRules.claw_strong(_grabs) and _state == S.IDLE
	_head_mat.set_shader_parameter("emission", Color(0.1, 0.8, 0.3) if lit else Color.BLACK)
	_flash = maxf(0.0, _flash - delta)
	_chute_mat.set_shader_parameter("emission", Color(0.9, 0.6, 0.1).lerp(Color(1, 1, 0.8), _flash))
	var step := int(_t * (14.0 if _flash > 0.0 else 6.0))
	for i in _bulbs.size():
		_bulbs[i].set_shader_parameter("emission", Color(1.0, 0.85, 0.35) if (step + i) % 3 == 0 else Color(0.3, 0.12, 0.08))


func _update_grip() -> void:
	if hub == null or not hub.state.has("gloria_eye"):
		_grip.text = "WIN STREAK x%d!" % _win_streak if _win_streak >= 2 else "PLAY, STEER, DROP"
		_grip.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3) if _win_streak >= 2 else Color(1, 1, 1, 0.85))
		return
	var strong := ArcadeRules.claw_strong(_grabs)
	var left := (ArcadeRules.CLAW_STRONG_EVERY - 1 - _grabs % ArcadeRules.CLAW_STRONG_EVERY)
	_grip.text = "GLORIA'S EYE: FULL STRENGTH!" if strong else "GLORIA'S EYE: WEAK (%d TO GO)" % left
	_grip.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if strong else Color(1.0, 0.7, 0.5))
