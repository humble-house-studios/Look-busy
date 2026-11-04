extends "res://scenes/ladder/machine.gd"
## FALL GUY: Bernie's stress-relief cabinet, a floor-to-ceiling glass column
## in the arcade (scenes/ladder/cage3d.gd) with a real 3D ragdoll inside: a
## Dale-shaped dummy (glasses, purple tie, legally not Dale) on a trampoline.
## LAUNCH (1 token) throws him up; every time he comes down onto the mat,
## BOUNCE kicks him back up (the lower he is when you hit it, the harder the
## kick). Hold < or > in the air to drift and cartwheel him into the
## bumpers on the glass. Points for the best height, each bumper, each full
## flip (double with Bernie's style perk), hard knocks off the glass, and
## ringing the bell at the top. Tickets = points / 50; 1500 beats the machine.
## A round is ArcadeRules.RAGDOLL_KICKS bounces. PERFECT bounces back to
## back chain a multiplier (x1.25 up to x2.5) on everything he hits; one bumper
## is lit as the TARGET (triple points, then another lights); the bell gives
## a bounce back (twice a round). Missions in engine/arcade_missions.gd.

const SEAT := {"at": Vector3(0, 1.55, 0.85), "size": Vector2(1.4, 2.4889), "tilt": 0.0}
## The column inside, cabinet metres: centred on x = z = 0.
const R_IN := 0.44
const MAT_Y := 0.86
const ROOF := 2.5
const BELL := Vector3(0, 2.4, 0)
const BUMPERS := [[1.22, 0.5], [1.5, 2.6], [1.78, 4.4], [2.06, 1.4], [2.2, 3.6]]
const BUMPER_R := 0.065
## The dummy's size against the old full-size corridor dummy.
const S := 0.5
const KICK_MIN := 2.4
const KICK_MAX := 5.3
## A kick counts this close to the mat, this many seconds from touchdown;
## the nearer the moment he lands, the harder.
const KICK_REACH := 0.3
const KICK_TIME := 0.22
const TOUCH := 0.07
const STEER := 2.2
const ROUND_MAX := 30.0

var _v
var _parts: Array[RigidBody3D] = []
var _joints: Array[Joint3D] = []
var _torso: RigidBody3D
var _playing := false
var _kicks := 0
var _cool := 0.0
var _round_t := 0.0
var _still := 0.0
var _impacts := 0.0
var _spin := 0.0
var _bumps := 0
var _bells := 0
## Points from hits (chain multiplied), PERFECTs in a row, the lit bumper.
var _hits := 0
var _perfects := 0
var _target := 0
var _best_h := 0.0
var _last_v := Vector3.ZERO
var _last_score := 0
var _touching := false
var _land_t := -9.0
var _kick_t := -9.0
var _dir := 0.0
var _stick := 0.0
var _keys := {}
var _pad_told := false
var _bumper_mats: Array[ShaderMaterial] = []
var _bumper_glow: Array[float] = []
var _bumper_cool: Array[float] = []
var _bell: Node3D
var _bell_mat: ShaderMaterial
var _bell_cool := 0.0
var _bell_swing := 0.0
var _mat_mesh: Node3D
var _mat_dip := 0.0
var _tube_mat: ShaderMaterial
var _tube_on := true
var _flicker_t := 0.0
var _rng := RandomNumberGenerator.new()
var _live: Label
var _call: Label
var _call_t := 0.0
var _go: Button
var _left: Button
var _right: Button


func _ready() -> void:
	super._ready()
	_rng.randomize()
	machine_id = "ragdoll"
	frame("FALL GUY", Color.TRANSPARENT, Color(1.0, 0.7, 0.35))
	_live = label("", 22, Color(1.0, 0.9, 0.6))
	_live.add_theme_color_override("font_outline_color", Color.BLACK)
	_live.add_theme_constant_override("outline_size", 10)
	_live.position = Vector2(0, 112)
	_live.size = Vector2(W, 40)
	add_child(_live)
	_call = label("", 34, Color(0.6, 1.0, 0.6))
	_call.add_theme_color_override("font_outline_color", Color.BLACK)
	_call.add_theme_constant_override("outline_size", 12)
	_call.position = Vector2(0, 880)
	_call.size = Vector2(W, 60)
	add_child(_call)
	var row := HBoxContainer.new()
	row.position = Vector2(24, 1060)
	row.size = Vector2(W - 48, 190)
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	_left = button("<", 48, Color(0.16, 0.12, 0.08, 0.85), Color(0.9, 0.8, 0.5))
	_go = button("LAUNCH", 38, Color(0.5, 0.16, 0.06, 0.9), Color(1.0, 0.85, 0.5))
	_right = button(">", 48, Color(0.16, 0.12, 0.08, 0.85), Color(0.9, 0.8, 0.5))
	for b in [_left, _go, _right]:
		b.custom_minimum_size = Vector2(0, 180)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_go.size_flags_stretch_ratio = 2.2
	_left.button_down.connect(func(): _dir = -1.0)
	_left.button_up.connect(func(): _dir = 0.0)
	_right.button_down.connect(func(): _dir = 1.0)
	_right.button_up.connect(func(): _dir = 0.0)
	# BOUNCE fires on press, not release: timing is everything.
	_go.button_down.connect(_on_go)
	_go.set_meta("pad_default", true)
	_go.set_meta("pad_button", JOY_BUTTON_A)
	pad.guide = [["L", "Lean"], ["A", "Launch / bounce"]]
	if cage:
		_build()
		_reset_dummy()
	_live.text = "TIME YOUR BOUNCES. RING THE BELL."


# ---------------------------------------------------------------- the column

func _build() -> void:
	_v = cage
	var v = _v
	v.setup({"ambient": Color(0.3, 0.27, 0.24), "fog_col": Color(0.12, 0.06, 0.18)})
	# More solver passes: joints stay tighter on big hits.
	PhysicsServer3D.space_set_param(v.get_world_3d().space, PhysicsServer3D.SPACE_PARAM_SOLVER_ITERATIONS, 24)
	v.set_light(0, Vector3(0, ROOF - 0.05, 0.1), Color(1.0, 0.95, 0.75), 1.9, 1.2)
	v.set_light(1, Vector3(0, MAT_Y + 0.15, 0.3), Color(1.0, 0.55, 0.25), 0.9, 0.9)
	v.set_light(2, Vector3(-0.3, 1.5, 0.0), Color(1.0, 0.3, 0.2), 0.8, 0.5)
	v.set_light(3, Vector3(0.3, 1.9, 0.0), Color(1.0, 0.85, 0.2), 0.8, 0.5)
	v.set_light(4, BELL, Color(1.0, 0.85, 0.3), 0.5, 0.6)
	var glass: ShaderMaterial = v.glass_mat(Color(0.85, 0.9, 1.0), 0.05)
	var metal: ShaderMaterial = v.mat(Color(0.45, 0.46, 0.48), {"shine": 0.8})
	# The glass: a round tube drawn, sixteen thick walls to bounce off.
	var h := ROOF - MAT_Y + 0.1
	v.cyl(R_IN + 0.01, R_IN + 0.01, h, Vector3(0, MAT_Y - 0.05 + h * 0.5, 0), glass, null, Vector3.ZERO, 24)
	for i in 16:
		var a := i * TAU / 16.0
		var wall: StaticBody3D = v.solid(Vector3(0.2, h + 0.4, 0.3), Vector3(sin(a), 0, cos(a)) * (R_IN + 0.15) + Vector3(0, MAT_Y + h * 0.5, 0), null, null, Vector3(0, a, 0), 0.45, 0.4)
		wall.rotation.y = a
	v.solid(Vector3(1.2, 0.3, 1.2), Vector3(0, ROOF + 0.15, 0), null, null, Vector3.ZERO, 0.4)
	v.cyl(R_IN + 0.01, R_IN + 0.01, 0.01, Vector3(0, ROOF + 0.005, 0), v.mat(Color(0.08, 0.07, 0.07)), null, Vector3.ZERO, 24)
	# The trampoline: a springy mat on a ring of springs.
	var mat_body: StaticBody3D = v.solid(Vector3(1.0, 0.3, 1.0), Vector3(0, MAT_Y - 0.15, 0), null, null, Vector3.ZERO, 0.72, 0.9)
	mat_body.name = "Trampoline"
	_mat_mesh = Node3D.new()
	_mat_mesh.position.y = MAT_Y
	v.add_child(_mat_mesh)
	v.cyl(R_IN - 0.06, R_IN - 0.06, 0.012, Vector3(0, -0.006, 0), v.mat(Color(0.06, 0.06, 0.07), {"pattern": 4, "col2": Color(0.18, 0.18, 0.2), "texel": 20.0}), _mat_mesh, Vector3.ZERO, 20)
	v.cyl(R_IN, R_IN, 0.04, Vector3(0, MAT_Y - 0.03, 0), v.mat(Color(0.2, 0.3, 0.75), {"shine": 0.6}), null, Vector3.ZERO, 20)
	for i in 14:
		var a := i * TAU / 14.0
		v.box(Vector3(0.012, 0.012, 0.06), Vector3(sin(a), 0, cos(a)) * (R_IN - 0.03) + Vector3(0, MAT_Y - 0.004, 0), metal, null, Vector3(0, a, 0))
	# Height marks up the back of the glass.
	for k in 6:
		var y := MAT_Y + 0.25 + k * 0.25
		v.box(Vector3(0.08, 0.006, 0.006), Vector3(0, y, -R_IN + 0.015), v.glow(Color(1.0, 0.8, 0.4) * 0.6))
		v.text("%d" % ((k + 1) * 25), Vector3(0.07, y, -R_IN + 0.02), 14, Color(1.0, 0.85, 0.5, 0.8), null, Vector3.ZERO, 0.0015)
	v.text("HEIGHT", Vector3(0, MAT_Y + 0.12, -R_IN + 0.02), 14, Color(1.0, 0.85, 0.5, 0.7), null, Vector3.ZERO, 0.0015)
	# Bumpers on the glass: bouncy, lit, worth points.
	for i in BUMPERS.size():
		var spec: Array = BUMPERS[i]
		var a: float = spec[1]
		var at := Vector3(sin(a) * R_IN, spec[0], cos(a) * R_IN)
		var m: ShaderMaterial = v.mat(Color(0.8, 0.12, 0.1) if i % 2 == 0 else Color(0.9, 0.7, 0.1), {"shine": 1.4})
		_bumper_mats.append(m)
		_bumper_glow.append(0.0)
		_bumper_cool.append(0.0)
		var body := StaticBody3D.new()
		v._layers(body)
		var sh := SphereShape3D.new()
		sh.radius = BUMPER_R
		v.shape(body, sh)
		var pm := PhysicsMaterial.new()
		pm.bounce = 1.0
		pm.friction = 0.2
		body.physics_material_override = pm
		body.position = at
		v.ball(BUMPER_R, Vector3.ZERO, m, body, 10)
		v.cyl(BUMPER_R * 1.3, BUMPER_R * 1.3, 0.01, Vector3.ZERO, metal, body, Vector3(PI / 2, 0, -a), 12).rotation = Vector3(PI / 2, a, 0)
		v.add_child(body)
		var area := Area3D.new()
		area.collision_layer = 0
		area.collision_mask = v.LAYER
		var ash := SphereShape3D.new()
		ash.radius = BUMPER_R + 0.03
		v.shape(area, ash)
		area.position = at
		v.add_child(area)
		area.body_entered.connect(_on_bumper.bind(i))
	# The bell, hanging from the top.
	_bell = Node3D.new()
	_bell.position = Vector3(0, ROOF, 0)
	v.add_child(_bell)
	_bell_mat = v.mat(Color(1.0, 0.78, 0.2), {"shine": 2.0, "glow": Color(0.2, 0.14, 0.0)})
	v.cyl(0.006, 0.006, ROOF - BELL.y - 0.05, Vector3(0, -(ROOF - BELL.y - 0.05) * 0.5, 0), metal, _bell)
	v.cyl(0.03, 0.1, 0.1, Vector3(0, BELL.y - ROOF, 0), _bell_mat, _bell, Vector3.ZERO, 14)
	v.ball(0.025, Vector3(0, BELL.y - ROOF - 0.06, 0), metal, _bell, 6)
	var bell_area := Area3D.new()
	bell_area.collision_layer = 0
	bell_area.collision_mask = v.LAYER
	var bsh := SphereShape3D.new()
	bsh.radius = 0.1
	v.shape(bell_area, bsh)
	bell_area.position = BELL
	v.add_child(bell_area)
	bell_area.body_entered.connect(_on_bell)
	v.text("RING IT", Vector3(0, ROOF - 0.04, -R_IN + 0.02), 16, Color(1.0, 0.85, 0.3), null, Vector3.ZERO, 0.0018)
	# A buzzing fluorescent ring under the roof.
	_tube_mat = v.glow(Color(0.95, 0.95, 0.75))
	for i in 12:
		var a := i * TAU / 12.0
		v.box(Vector3(0.2, 0.014, 0.014), Vector3(sin(a), 0, cos(a)) * (R_IN - 0.04) + Vector3(0, ROOF - 0.02, 0), _tube_mat, null, Vector3(0, a, 0))


# ---------------------------------------------------------------- the dummy

## Dummy materials, made once (every round rebuilds the body, not these).
var _dm := {}
## Joint anchors, parent before child: {a, b, la, lb} (local on each body).
var _links: Array[Dictionary] = []
## The dummy faces you: its own +x (forward when built) turned to +z.
const FACE := Basis(Vector3.UP, -PI / 2)


func _dummy_mats() -> void:
	var v = _v
	_dm = {
		"shirt": v.mat(Color(0.82, 0.8, 0.62), {"shine": 0.2}),
		"skin": v.mat(Color(0.86, 0.66, 0.52), {"shine": 0.3}),
		"pants": v.mat(Color(0.22, 0.24, 0.3)),
		"shoe": v.mat(Color(0.12, 0.08, 0.06), {"shine": 0.6}),
		"dark": v.mat(Color(0.04, 0.04, 0.04)),
		"hair": v.mat(Color(0.32, 0.22, 0.13)),
		"tie": v.mat(Color(0.5, 0.1, 0.36), {"shine": 0.5}),
		"belt": v.mat(Color(0.15, 0.1, 0.07), {"shine": 0.8}),
		"buckle": v.glow(Color(0.6, 0.5, 0.2)),
		"lens": v.glow(Color(0.5, 0.55, 0.5)),
	}


## Where the dummy stands: feet on the mat, in the middle.
func _origin() -> Vector3:
	return Vector3(0, MAT_Y + 1.06 * S, 0)


## A body part at `off` (full-size dummy metres from the torso, built facing
## +x); its meshes go on the returned skin, drawn at full size and scaled.
func _body(off: Vector3, shape: Shape3D, mass: float) -> Array:
	var b: RigidBody3D = _v.rigid(_origin() + FACE * (off * S), mass, 0.6, 0.3)
	b.basis = FACE
	b.angular_damp = 0.3
	b.linear_damp = 0.05
	b.continuous_cd = true
	_v.shape(b, shape)
	var skin := Node3D.new()
	skin.scale = Vector3.ONE * S
	b.add_child(skin)
	_v.add_child(b)
	_parts.append(b)
	return [b, skin]


## A limb segment: a capsule, with a ball at its top joint to hide the seam.
func _limb(off: Vector3, r: float, h: float, m: ShaderMaterial, mass: float) -> RigidBody3D:
	var c := CapsuleShape3D.new()
	c.radius = r * S
	c.height = h * S
	var parts := _body(off, c, mass)
	_v.capsule(r, h, Vector3.ZERO, m, parts[1])
	_v.ball(r * 1.08, Vector3(0, h * 0.5 - r, 0), m, parts[1], 8)
	return parts[0]


func _pin(a: RigidBody3D, b: RigidBody3D, off: Vector3, swing := 70.0, twist := 40.0) -> void:
	var at := _origin() + FACE * (off * S)
	var j := ConeTwistJoint3D.new()
	# The cone's axis (joint x) points from the socket down the child part,
	# so a limb hanging at rest sits in the middle of its cone.
	var axis := (b.position - at).normalized()
	var side := FACE * Vector3(0, 0, 1)
	j.transform = Transform3D(Basis(axis, side.cross(axis).normalized(), side), at)
	j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(swing))
	j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(twist))
	_v.add_child(j)
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)
	_joints.append(j)
	_links.append({"a": a, "b": b, "la": a.transform.affine_inverse() * at, "lb": b.transform.affine_inverse() * at})


## The Dale-shaped dummy: rounded torso, a head with glasses, moustache and a
## horseshoe of hair, arms and legs in two pieces each, hands and shoes.
## Built standing on the mat, facing out of the glass, frozen till LAUNCH.
func _reset_dummy() -> void:
	for j in _joints:
		j.queue_free()
	for p in _parts:
		p.queue_free()
	_joints.clear()
	_parts.clear()
	_links.clear()
	if _dm.is_empty():
		_dummy_mats()
	var v = _v
	var tb := BoxShape3D.new()
	tb.size = Vector3(0.24, 0.56, 0.36) * S
	var t := _body(Vector3.ZERO, tb, 1.2)
	_torso = t[0]
	var sk: Node3D = t[1]
	v.capsule(0.18, 0.6, Vector3(0, 0.02, 0), _dm.shirt, sk).scale = Vector3(0.7, 1, 1)
	v.cyl(0.175, 0.175, 0.2, Vector3(0, -0.2, 0), _dm.pants, sk).scale = Vector3(0.72, 1, 1)
	v.cyl(0.18, 0.18, 0.045, Vector3(0, -0.1, 0), _dm.belt, sk).scale = Vector3(0.74, 1, 1)
	v.box(Vector3(0.03, 0.05, 0.05), Vector3(0.13, -0.1, 0), _dm.buckle, sk)
	v.box(Vector3(0.02, 0.26, 0.055), Vector3(0.128, 0.08, 0), _dm.tie, sk)
	v.box(Vector3(0.03, 0.05, 0.08), Vector3(0.122, 0.22, 0), _dm.tie, sk)
	v.box(Vector3(0.06, 0.04, 0.2), Vector3(0.08, 0.26, 0), _dm.shirt, sk, Vector3(0, 0, -0.3))
	v.cyl(0.055, 0.055, 0.12, Vector3(0, 0.3, 0), _dm.skin, sk)
	for s in [-1.0, 1.0]:
		v.ball(0.075, Vector3(0, 0.2, s * 0.19), _dm.shirt, sk, 8)
		v.ball(0.08, Vector3(0, -0.25, s * 0.09), _dm.pants, sk, 8)
	var hs := SphereShape3D.new()
	hs.radius = 0.12 * S
	var hp := _body(Vector3(0, 0.43, 0), hs, 0.4)
	var head: RigidBody3D = hp[0]
	var hk: Node3D = hp[1]
	v.ball(0.12, Vector3.ZERO, _dm.skin, hk, 10)
	v.ball(0.122, Vector3(-0.025, 0.02, 0), _dm.hair, hk, 10).scale = Vector3(0.9, 0.75, 1.02)
	v.ball(0.105, Vector3(0.012, 0.035, 0), _dm.skin, hk, 10)
	for s in [-1.0, 1.0]:
		v.box(Vector3(0.012, 0.042, 0.055), Vector3(0.112, 0.015, s * 0.042), _dm.dark, hk)
		v.box(Vector3(0.006, 0.03, 0.04), Vector3(0.118, 0.015, s * 0.042), _dm.lens, hk)
		v.ball(0.03, Vector3(-0.005, 0.0, s * 0.12), _dm.skin, hk, 6)
	v.box(Vector3(0.012, 0.01, 0.03), Vector3(0.118, 0.015, 0), _dm.dark, hk)
	v.box(Vector3(0.05, 0.03, 0.03), Vector3(0.125, -0.025, 0), _dm.skin, hk)
	v.box(Vector3(0.02, 0.022, 0.085), Vector3(0.118, -0.058, 0), _dm.hair, hk)
	_pin(_torso, head, Vector3(0, 0.3, 0), 40.0, 40.0)
	for s in [-1.0, 1.0]:
		var upper := _limb(Vector3(0, 0.08, s * 0.25), 0.052, 0.32, _dm.shirt, 0.3)
		_pin(_torso, upper, Vector3(0, 0.21, s * 0.24), 80.0, 50.0)
		var fore := _limb(Vector3(0, -0.2, s * 0.25), 0.046, 0.3, _dm.shirt, 0.25)
		v.ball(0.05, Vector3(0, -0.17, 0), _dm.skin, fore.get_child(fore.get_child_count() - 1), 6)
		_pin(upper, fore, Vector3(0, -0.06, s * 0.25), 65.0, 20.0)
		var thigh := _limb(Vector3(0, -0.45, s * 0.09), 0.072, 0.4, _dm.pants, 0.4)
		_pin(_torso, thigh, Vector3(0, -0.27, s * 0.09), 60.0, 25.0)
		var shin := _limb(Vector3(0, -0.82, s * 0.09), 0.06, 0.38, _dm.pants, 0.3)
		v.box(Vector3(0.22, 0.07, 0.1), Vector3(0.05, -0.19, 0), _dm.shoe, shin.get_child(shin.get_child_count() - 1))
		_pin(thigh, shin, Vector3(0, -0.64, s * 0.09), 60.0, 15.0)
	for a in _parts:
		for b in _parts:
			if a != b:
				a.add_collision_exception_with(b)
		a.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		a.freeze = true
	_playing = false


## Physics joints stretch when something hits hard enough; this keeps every
## joint shut so the dummy never comes apart: each child part is moved back
## onto its socket (parents first) and takes on some of the parent's speed.
func _hold_together() -> void:
	for l in _links:
		var a: RigidBody3D = l.a
		var b: RigidBody3D = l.b
		var wa: Vector3 = a.global_transform * l.la
		var wb: Vector3 = b.global_transform * l.lb
		var gap := wa - wb
		if gap.length() < 0.006:
			continue
		var t := b.global_transform
		t.origin += gap
		b.global_transform = t
		PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)
		var va := a.linear_velocity + a.angular_velocity.cross(wa - a.global_position)
		b.linear_velocity = b.linear_velocity.lerp(va, 0.5)


# ---------------------------------------------------------------- playing

## The big button: LAUNCH (a token) when he's waiting, BOUNCE mid-round.
func _on_go() -> void:
	if _playing:
		_on_bounce()
	else:
		_on_launch()


func _on_launch() -> void:
	if _playing or cage == null or _torso == null or not _torso.freeze:
		return
	if not pay_token():
		return
	for p in _parts:
		p.freeze = false
		p.linear_velocity = Vector3(_rng.randf_range(-0.3, 0.3), 3.2, _rng.randf_range(-0.2, 0.2))
		p.angular_velocity = Vector3.ZERO
	_torso.angular_velocity = Vector3(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-4.0, 4.0))
	_playing = true
	_kicks = ArcadeRules.RAGDOLL_KICKS
	_round_t = 0.0
	_still = 0.0
	_impacts = 0.0
	_spin = 0.0
	_bumps = 0
	_bells = 0
	_hits = 0
	_perfects = 0
	_best_h = 0.0
	_cool = 0.0
	_touching = false
	_land_t = -9.0
	_kick_t = 0.0
	_last_v = _torso.linear_velocity
	_go.text = "BOUNCE!"
	_mat_dip = 1.0
	sfx("thump")


## The lowest part of him above the mat.
func _low() -> float:
	var low := 9.0
	for p in _parts:
		low = minf(low, p.position.y - MAT_Y)
	return low


## How far (seconds) from the moment he touches down: before it, the time
## still to fall; after it, the time since. Big when he's nowhere near.
func _timing() -> float:
	var low := _low()
	if low > KICK_REACH:
		return 9.0
	if _touching:
		# Lying there: you can always get him going again (a weak kick).
		if _still > 0.4:
			return KICK_TIME * 0.95
		return _round_t - _land_t
	return (low - TOUCH) / maxf(-_torso.linear_velocity.y, 0.4)


## Would a kick count right now?
func _kick_window() -> bool:
	return _playing and _kicks > 0 and _cool <= 0.0 and _timing() < KICK_TIME


## Kick him off the mat: the nearer the moment he lands, the harder.
## Returns whether it counted.
func _on_bounce() -> bool:
	if not _playing or _kicks <= 0 or _cool > 0.0:
		return false
	var err := _timing()
	_cool = 0.3
	if err >= KICK_TIME:
		var early := _low() > TOUCH
		_say("TOO EARLY!" if early else "TOO LATE!", Color(1.0, 0.6, 0.4))
		sfx("click", -6.0, 0.6)
		return false
	_kicks -= 1
	_kick_t = _round_t
	var q := clampf(1.0 - err / KICK_TIME, 0.0, 1.0)
	var speed := lerpf(KICK_MIN, KICK_MAX, q)
	var lean := _steer()
	var drift := Vector2(_rng.randf_range(-0.4, 0.4) + lean * 1.1, _rng.randf_range(-0.3, 0.3))
	for p in _parts:
		var v := p.linear_velocity
		# Kicks pull back toward the middle of the column (a little).
		var to_mid := -Vector2(p.position.x, p.position.z) * 1.2
		p.linear_velocity = Vector3(v.x * 0.3 + to_mid.x + drift.x, speed, v.z * 0.3 + to_mid.y + drift.y)
	_torso.angular_velocity += Vector3(_rng.randf_range(-2.5, 2.5), 0, _rng.randf_range(-2.5, 2.5) - lean * 6.0)
	_mat_dip = 1.0
	if q > 0.75:
		_perfects += 1
		var x := ArcadeRules.ragdoll_chain_x(_perfects)
		_say("PERFECT!" if _perfects < 2 else "PERFECT x%s!" % _chain_text(x), Color(0.5, 1.0, 0.5))
		sfx("laugh_small", -8.0, 1.0 + _perfects * 0.05)
		mission_event("perfects", _perfects)
		sfx("thump", -2.0, 1.2)
		return true
	if _perfects >= 2:
		sfx("groan", -10.0)
	_perfects = 0
	if q > 0.4:
		_say("GOOD", Color(0.9, 1.0, 0.6))
	else:
		_say("EARLY" if _low() > TOUCH else "LATE", Color(1.0, 0.8, 0.5))
	sfx("thump", -2.0, 0.8 + q * 0.4)
	return true


func _say(text: String, color: Color) -> void:
	_call.text = text
	_call.add_theme_color_override("font_color", color)
	_call_t = 0.8


func _chain_text(x: float) -> String:
	return ("%d" % x) if is_equal_approx(x, roundf(x)) else ("%.1f" % x)


func _on_bumper(body: Node, i: int) -> void:
	if not _playing or not body in _parts or _bumper_cool[i] > 0.0:
		return
	_bumper_cool[i] = 0.35
	_bumper_glow[i] = 1.0
	_bumps += 1
	if i == _target:
		var pts := ArcadeRules.ragdoll_hit("target", _perfects)
		_hits += pts
		banner("TARGET!\n+%d" % pts, 1.2, Color(1.0, 0.5, 0.3))
		sfx("jackpot", -8.0, 1.2)
		mission_event("target")
		var next := _target
		while next == _target:
			next = _rng.randi() % BUMPERS.size()
		_target = next
	else:
		_hits += ArcadeRules.ragdoll_hit("bumper", _perfects)
		sfx("ding", -6.0, 1.0 + 0.1 * i)


func _on_bell(body: Node) -> void:
	if not _playing or not body in _parts or _bell_cool > 0.0:
		return
	_bell_cool = 0.8
	_bell_swing = 1.0
	_bells += 1
	var pts := ArcadeRules.ragdoll_hit("bell", _perfects)
	_hits += pts
	var more := _bells <= ArcadeRules.RAGDOLL_BELL_KICKS
	if more:
		_kicks += 1
	sfx("jackpot", -4.0)
	banner("DING DING DING!\n+%d%s" % [pts, "  +1 BOUNCE" if more else ""], 1.4)
	mission_event("bell", _bells)


# ---------------------------------------------------------------- input

const PAD_DEAD := 0.25
const KEYS := {KEY_LEFT: -1.0, KEY_A: -1.0, KEY_RIGHT: 1.0, KEY_D: 1.0}


## Stick / D-pad / keys lean him; Space or Enter is the big button. Events
## only, never Input polling.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X:
		_stick = event.axis_value if absf(event.axis_value) > PAD_DEAD else 0.0
		_tell_pad()
	elif event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		_keys[-event.button_index] = (-1.0 if event.button_index == JOY_BUTTON_DPAD_LEFT else 1.0) if event.pressed else 0.0
		_tell_pad()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and not event.echo:
		if KEYS.has(event.keycode):
			_keys[event.keycode] = KEYS[event.keycode] if event.pressed else 0.0
			get_viewport().set_input_as_handled()
		elif event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER, KEY_UP, KEY_W]:
			_on_go()
			get_viewport().set_input_as_handled()


func _tell_pad() -> void:
	if pad:
		pad.active = true
	if not _pad_told and pad:
		_pad_told = true
		pad.show_guide()


func set_active(on: bool) -> void:
	super.set_active(on)
	if not on:
		_dir = 0.0
		_stick = 0.0
		_keys.clear()


func _steer() -> float:
	var v := _dir + _stick
	for k in _keys:
		v += _keys[k]
	return clampf(v, -1.0, 1.0)


func _physics_process(delta: float) -> void:
	if not _playing:
		return
	_hold_together()
	_round_t += delta
	_cool = maxf(0.0, _cool - delta)
	var lean := _steer()
	if lean != 0.0 and _low() > 0.1:
		# Drift sideways and cartwheel (as you see him through the glass).
		_torso.apply_central_force(Vector3(lean * STEER * _torso.mass * 2.0, 0, 0))
		_torso.apply_torque(Vector3(0, 0, -lean * 0.06))
	var touching := _low() < TOUCH
	if touching and not _touching:
		_land_t = _round_t
	_touching = touching
	var v := _torso.linear_velocity
	var dv := (v - _last_v).length()
	# Knocks off the glass and roof count; landing and kicks don't.
	if dv > 2.5 and _low() > 0.15 and _round_t - _kick_t > 0.12:
		_impacts += (dv - 2.5) * 6.0
		sfx("thump", -14.0 + minf(dv, 10.0), _rng.randf_range(0.9, 1.2))
	_last_v = v
	_spin += _torso.angular_velocity.length() * delta
	var head_h := 0.0
	for p in _parts:
		head_h = maxf(head_h, p.position.y - MAT_Y)
	_best_h = maxf(_best_h, head_h)
	_still = _still + delta if v.length() < 0.3 and _low() < 0.15 else 0.0
	var out_of_kicks := _kicks <= 0 and _still > 0.8
	if out_of_kicks or _round_t > ROUND_MAX or _still > 6.0:
		_land()


func _spins() -> int:
	return int(absf(_spin) / TAU)


func _score() -> int:
	var style: bool = hub != null and hub.state.has("style")
	return ArcadeRules.ragdoll_score(_best_h, _impacts, _spins(), style, _hits)


func _land() -> void:
	_playing = false
	var score := _score()
	_last_score = score
	var tickets := ArcadeRules.ragdoll_tickets(score)
	var beats := score >= ArcadeRules.RAGDOLL_BEAT
	win(tickets, "ragdoll", beats)
	sfx("jackpot" if beats else ("ding" if tickets > 20 else "groan"))
	banner("%d POINTS\n+%d TICKETS%s" % [score, tickets, "\nMACHINE BEATEN!" if beats else ""], 3.0)
	var style: bool = hub != null and hub.state.has("style")
	_live.text = "%dcm  BUMPS %d  FLIPS %d%s  BELL %d" % [roundi(_best_h * 100), _bumps, _spins(), "x2" if style else "", _bells]
	_go.text = "..."
	var t := create_tween()
	t.tween_interval(2.2)
	t.tween_callback(func():
		_reset_dummy()
		_go.text = "LAUNCH")


func _process(delta: float) -> void:
	super._process(delta)
	if cage == null:
		return
	if _playing and _torso:
		# Again just before drawing, so a hard hit never shows a gap.
		_hold_together()
		var x := ArcadeRules.ragdoll_chain_x(_perfects)
		_live.text = "BOUNCES %d   %d PTS%s" % [_kicks, _score(), "   x%s" % _chain_text(x) if x > 1.0 else ""]
		# The button lights up while a kick would count.
		_go.modulate = Color(1.3, 1.3, 0.9) if _kick_window() else Color.WHITE
	else:
		_go.modulate = Color.WHITE
	_call_t = maxf(0.0, _call_t - delta)
	_call.modulate.a = clampf(_call_t * 3.0, 0.0, 1.0)
	_mat_dip = move_toward(_mat_dip, 0.0, delta * 4.0)
	_mat_mesh.position.y = MAT_Y - 0.03 * sin(_mat_dip * PI)
	for i in _bumper_mats.size():
		_bumper_cool[i] = maxf(0.0, _bumper_cool[i] - delta)
		_bumper_glow[i] = maxf(0.0, _bumper_glow[i] - delta * 3.0)
		var lit := Color(0.9, 0.9, 1.0) * (0.45 + 0.35 * sin(Time.get_ticks_msec() * 0.012)) if i == _target else Color.BLACK
		_bumper_mats[i].set_shader_parameter("emission", lit + Color(1.0, 0.9, 0.5) * _bumper_glow[i])
	_bell_cool = maxf(0.0, _bell_cool - delta)
	_bell_swing = maxf(0.0, _bell_swing - delta * 0.7)
	_bell.rotation.z = sin(Time.get_ticks_msec() * 0.02) * 0.35 * _bell_swing
	_bell_mat.set_shader_parameter("emission", Color(0.2, 0.14, 0.0).lerp(Color(1.0, 0.9, 0.5), _bell_swing))
	_flicker(delta)


## The tube buzzes: now and then it stutters off and back on.
func _flicker(delta: float) -> void:
	_flicker_t -= delta
	if _flicker_t > 0.0:
		return
	_flicker_t = _rng.randf_range(0.05, 0.5)
	var on := _rng.randf() > 0.12
	if on == _tube_on:
		return
	_tube_on = on
	_tube_mat.set_shader_parameter("emission", Color(0.95, 0.95, 0.75) if on else Color(0.15, 0.15, 0.12))
	_v.set_light(0, Vector3(0, ROOF - 0.05, 0.1), Color(1.0, 0.95, 0.75), 1.9, 1.2 if on else 0.35)
