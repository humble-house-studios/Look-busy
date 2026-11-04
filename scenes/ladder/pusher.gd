extends "res://scenes/ladder/machine.gd"
## PUSH YOUR LUCK: a real coin pusher in a glass case in the arcade
## (scenes/ladder/cage3d.gd). The shelf at the back slides in and out; the
## drop chute swings left and right under the glass, DROP lets a coin fall in
## front of the shelf, and its next stroke shoves it into the pile. Whatever
## falls off the front edge pays tickets: coins, green bundles and the gold
## JACKPOT chip, which beats the machine. One token = 5 coins.

const SEAT := {"at": Vector3(0, 1.3, 0.68), "size": Vector2(0.86, 1.5289), "tilt": -0.62}
const HALF_X := 0.43
const FIELD := 0.97
const FRONT := 0.3
const BACK := -0.5
const CASE_TOP := 1.42
const GLASS_Z := 0.4
const SHELF_D := 0.36
## The shelf's front face moves between these (z, metres).
const SHELF_IN := -0.14
const SHELF_REACH := 0.12
const SHELF_H := 0.07
const SHELF_PERIOD := 2.6
const COIN_R := 0.034
const COIN_H := 0.014
const KEEP := 60

var _v
var _shelf: AnimatableBody3D
var _t := 0.0
var _hand := 0
var _chute_x := 0.0
var _chute: Node3D
var _bodies: Array[RigidBody3D] = []
var _coin_mat: ShaderMaterial
var _edge_mat: ShaderMaterial
var _bulbs: Array[ShaderMaterial] = []
var _info: Label
var _drop: Button
var _rng := RandomNumberGenerator.new()
var _streak := 0
var _streak_time := 0.0
var _flash := 0.0


func _ready() -> void:
	super._ready()
	_rng.randomize()
	frame("PUSH YOUR LUCK", Color.TRANSPARENT, Color(0.35, 0.95, 0.85))
	_info = label("", 24, Color(1.0, 0.92, 0.55))
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 10)
	_info.position = Vector2(0, 112)
	_info.size = Vector2(W, 40)
	add_child(_info)
	_drop = button("DROP COIN", 40, Color(0.05, 0.4, 0.38, 0.88))
	_drop.position = Vector2(60, 1090)
	_drop.size = Vector2(W - 120, 150)
	_drop.custom_minimum_size = Vector2(0, 150)
	_drop.pressed.connect(_on_drop)
	_drop.set_meta("pad_default", true)
	add_child(_drop)
	if cage:
		_build()
	_update_info()


func _build() -> void:
	_v = cage
	_v.setup({"ambient": Color(0.2, 0.28, 0.3), "fog_col": Color(0.12, 0.06, 0.18)})
	_v.set_light(0, Vector3(0, CASE_TOP - 0.05, -0.2), Color(0.4, 1.0, 0.9), 1.1, 0.9)
	_v.set_light(1, Vector3(0, CASE_TOP - 0.05, 0.3), Color(1.0, 0.85, 0.5), 1.0, 0.9)
	_v.set_light(2, Vector3(-HALF_X + 0.05, FIELD + 0.2, 0.0), Color(1.0, 0.3, 0.8), 0.7, 0.8)
	_v.set_light(3, Vector3(HALF_X - 0.05, FIELD + 0.2, 0.0), Color(0.3, 0.6, 1.0), 0.7, 0.8)
	_v.set_light(4, Vector3(0, FIELD - 0.05, FRONT + 0.05), Color(1.0, 0.75, 0.2), 0.35, 0.9)
	_coin_mat = _v.mat(Color(0.95, 0.75, 0.25), {"shine": 1.8})
	_edge_mat = _v.glow(Color(1.0, 0.75, 0.2))
	_build_case()
	# A packed table from the shelf to the edge, so every push carries through
	# the pile, with two bundles and the jackpot buried in it.
	var specials := {Vector2i(2, 3): "bundle", Vector2i(8, 2): "bundle", Vector2i(5, 2): "jackpot"}
	for row in 6:
		for col in 12:
			var x := -HALF_X + 0.04 + col * 0.073 + (row % 2) * 0.036
			if x > HALF_X - 0.035:
				continue
			_spawn(specials.get(Vector2i(col, row), "coin"), Vector3(x, FIELD + 0.01, SHELF_IN + 0.06 + row * 0.064))
	for i in 8:
		_spawn("coin", Vector3(_rng.randf_range(-0.35, 0.35), FIELD + 0.05 + i * 0.02, _rng.randf_range(0.0, 0.2)))


func _build_case() -> void:
	var v = _v
	var felt: ShaderMaterial = v.mat(Color(0.05, 0.3, 0.32), {"pattern": 4, "col2": Color(0.1, 0.5, 0.5), "texel": 12.0})
	var chrome: ShaderMaterial = v.mat(Color(0.7, 0.75, 0.8), {"pattern": 2, "col2": Color(0.5, 0.55, 0.6), "texel": 80.0, "shine": 1.5})
	var mirror: ShaderMaterial = v.mat(Color(0.05, 0.08, 0.12), {"pattern": 1, "col2": Color(0.08, 0.14, 0.2), "texel": 8.0, "shine": 0.8})
	var glass: ShaderMaterial = v.glass_mat()
	var depth := FRONT - BACK
	var mid := (FRONT + BACK) * 0.5
	var h := CASE_TOP - FIELD
	# Playfield (thick), the side walls (glass), the trough past the edge.
	v.solid(Vector3(HALF_X * 2, 0.2, depth), Vector3(0, FIELD - 0.1, mid), felt, null, Vector3.ZERO, 0.0, 0.35)
	for s in [-1.0, 1.0]:
		v.solid(Vector3(0.2, h + 0.1, GLASS_Z - BACK), Vector3(s * (HALF_X + 0.1), FIELD + h * 0.5, (GLASS_Z + BACK) * 0.5), null)
		v.box(Vector3(0.006, h + 0.05, GLASS_Z - BACK), Vector3(s * (HALF_X + 0.01), FIELD - 0.025 + (h + 0.05) * 0.5, (GLASS_Z + BACK) * 0.5), glass)
		v.box(Vector3(0.012, 0.012, depth), Vector3(s * (HALF_X - 0.004), FIELD + 0.006, mid), v.glow(Color(1.0, 0.3, 0.8) if s < 0 else Color(0.3, 0.6, 1.0)))
		for i in 6:
			var b: ShaderMaterial = v.glow(Color(1.0, 0.9, 0.4))
			_bulbs.append(b)
			v.ball(0.01, Vector3(s * (HALF_X - 0.012), FIELD + 0.03, FRONT - 0.04 - i * 0.12), b, null, 6)
	# Front glass and the glass lid; the trough under the edge.
	v.solid(Vector3(HALF_X * 2 + 0.2, h + 0.3, 0.2), Vector3(0, FIELD - 0.15 + (h + 0.3) * 0.5, GLASS_Z + 0.1), null)
	v.box(Vector3(HALF_X * 2 + 0.02, h + 0.12, 0.006), Vector3(0, FIELD - 0.12 + (h + 0.12) * 0.5, GLASS_Z), glass)
	v.solid(Vector3(HALF_X * 2 + 0.2, 0.2, GLASS_Z - BACK), Vector3(0, CASE_TOP + 0.1, (GLASS_Z + BACK) * 0.5), null)
	v.box(Vector3(HALF_X * 2 + 0.02, 0.006, GLASS_Z - BACK), Vector3(0, CASE_TOP, (GLASS_Z + BACK) * 0.5), glass)
	v.solid(Vector3(HALF_X * 2, 0.04, GLASS_Z - FRONT), Vector3(0, FIELD - 0.2, (FRONT + GLASS_Z) * 0.5), v.mat(Color(0.02, 0.04, 0.05)))
	# The gold lip at the front edge.
	v.box(Vector3(HALF_X * 2, 0.008, 0.016), Vector3(0, FIELD + 0.002, FRONT - 0.008), _edge_mat)
	# Back: a mirrored wall with the marquee (behind the shelf's travel).
	v.solid(Vector3(HALF_X * 2 + 0.1, h, 0.04), Vector3(0, FIELD + h * 0.5, BACK - 0.02), mirror)
	v.text("PUSH YOUR LUCK", Vector3(0, CASE_TOP - 0.17, SHELF_IN - SHELF_D + 0.025), 28, Color(0.4, 1.0, 0.9))
	v.text("JACKPOT  150", Vector3(0, CASE_TOP - 0.23, SHELF_IN - SHELF_D + 0.025), 16, Color(1.0, 0.8, 0.2))
	# The shelf: moves in and out on its own clock (_physics_process).
	_shelf = AnimatableBody3D.new()
	_shelf.sync_to_physics = true
	v._layers(_shelf)
	var b := BoxShape3D.new()
	b.size = Vector3(HALF_X * 2 - 0.006, SHELF_H, SHELF_D)
	v.shape(_shelf, b)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.3
	_shelf.physics_material_override = pm
	v.box(b.size, Vector3.ZERO, chrome, _shelf)
	v.box(Vector3(HALF_X * 2 - 0.006, 0.008, 0.01), Vector3(0, SHELF_H * 0.5, SHELF_D * 0.5), v.glow(Color(0.4, 1.0, 0.9)), _shelf)
	_shelf.position = Vector3(0, FIELD + SHELF_H * 0.5, SHELF_IN - SHELF_D * 0.5)
	v.add_child(_shelf)
	# Coins on the shelf can't ride back past this.
	v.solid(Vector3(HALF_X * 2, CASE_TOP - FIELD - SHELF_H, 0.03), Vector3(0, (CASE_TOP + FIELD + SHELF_H) * 0.5 + 0.005, SHELF_IN - SHELF_D + 0.01), mirror)
	# The drop chute on a rail under the lid.
	v.box(Vector3(HALF_X * 2, 0.014, 0.014), Vector3(0, CASE_TOP - 0.03, SHELF_IN + 0.05), chrome)
	_chute = Node3D.new()
	v.add_child(_chute)
	v.cyl(0.042, 0.042, 0.1, Vector3(0, CASE_TOP - 0.09, 0), v.mat(Color(0.2, 0.25, 0.3), {"shine": 1.2}), _chute)
	v.cyl(0.034, 0.034, 0.004, Vector3(0, CASE_TOP - 0.142, 0), v.glow(Color(1.0, 0.85, 0.3)), _chute)


func _spawn(kind: String, at: Vector3) -> void:
	var v = _v
	var b: RigidBody3D = v.rigid(at, 0.05 if kind == "coin" else 0.1, 0.45, 0.05)
	b.rotation.y = _rng.randf() * TAU
	b.set_meta("kind", kind)
	b.linear_damp = 0.8
	b.angular_damp = 2.5
	b.can_sleep = true
	if kind == "coin":
		var c := CylinderShape3D.new()
		c.radius = COIN_R
		c.height = COIN_H
		v.shape(b, c)
		v.cyl(COIN_R, COIN_R, COIN_H, Vector3.ZERO, _coin_mat, b, Vector3.ZERO, 10)
	else:
		var dims := Vector3(0.11, 0.028, 0.07) if kind == "bundle" else Vector3(0.12, 0.036, 0.08)
		var r := BoxShape3D.new()
		r.size = dims
		v.shape(b, r)
		if kind == "bundle":
			v.box(dims, Vector3.ZERO, v.mat(Color(0.3, 0.8, 0.4), {"pattern": 2, "col2": Color(0.2, 0.6, 0.3), "texel": 160.0}), b)
			v.text("25", Vector3(0, dims.y * 0.5 + 0.001, 0), 24, Color(0.05, 0.25, 0.1), b, Vector3(-PI / 2, 0, 0))
		else:
			v.box(dims, Vector3.ZERO, v.mat(Color(1.0, 0.75, 0.1), {"shine": 2.0, "glow": Color(0.4, 0.25, 0.0)}), b)
			v.text("JP!", Vector3(0, dims.y * 0.5 + 0.001, 0), 26, Color(0.5, 0.1, 0.0), b, Vector3(-PI / 2, 0, 0))
	v.add_child(b)
	_bodies.append(b)


func _on_drop() -> void:
	if cage == null:
		return
	if _hand <= 0:
		if not pay_token():
			return
		_hand += ArcadeRules.PUSHER_COINS_PER_TOKEN
	_hand -= 1
	# Lands in the strip the shelf sweeps, so its next stroke shoves it in.
	_spawn("coin", Vector3(_chute_x, CASE_TOP - 0.16, _shelf_front() + COIN_R + 0.012))
	_bodies[-1].rotation = Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
	sfx("click", -4.0, _rng.randf_range(0.9, 1.1))
	_update_info()


func _shelf_front() -> float:
	return _shelf.position.z + SHELF_D * 0.5


func _physics_process(delta: float) -> void:
	if cage == null:
		return
	_t += delta
	var reach := (0.5 - 0.5 * cos(_t * TAU / SHELF_PERIOD)) * SHELF_REACH
	_shelf.position.z = SHELF_IN - SHELF_D * 0.5 + reach


func _process(delta: float) -> void:
	super._process(delta)
	if cage == null:
		return
	_chute_x = sin(_t * 1.3) * (HALF_X - 0.06)
	_chute.position = Vector3(_chute_x, 0, _shelf_front() + COIN_R + 0.012)
	_streak_time = maxf(0.0, _streak_time - delta)
	if _streak_time <= 0.0:
		_streak = 0
	for b in _bodies.duplicate():
		var at: Vector3 = b.position
		if at.y < FIELD - 0.06 and at.z > FRONT - 0.03:
			_bodies.erase(b)
			var kind: String = b.get_meta("kind")
			b.queue_free()
			var t := ArcadeRules.pusher_tickets(kind)
			win(t, "pusher", kind == "jackpot")
			_flash = 0.35
			if kind == "coin":
				_streak += 1
				_streak_time = 1.2
				sfx("coin", -6.0, 1.0 + minf(_streak, 12) * 0.05)
				if _streak >= 5:
					banner("x%d COINS!\n+%d" % [_streak, _streak * t], 1.0)
			else:
				sfx("jackpot" if kind == "jackpot" else "ding")
				banner("JACKPOT!\n+%d TICKETS" % t if kind == "jackpot" else "BUNDLE!\n+%d TICKETS" % t, 2.4)
				# Bury a fresh one at the back so there's always something to chase.
				_spawn(kind, Vector3(_rng.randf_range(-0.25, 0.25), FIELD + 0.15, _shelf_front() + 0.07))
		elif at.y < FIELD - 0.3 or absf(at.x) > HALF_X + 0.1 or at.y > CASE_TOP + 0.1:
			_bodies.erase(b)
			b.queue_free()
	# Keep the table stocked: a coin rains in at the back if it runs thin.
	if _bodies.size() < KEEP and Engine.get_process_frames() % 10 == 0:
		_spawn("coin", Vector3(_rng.randf_range(-0.35, 0.35), FIELD + 0.2, _shelf_front() + COIN_R + 0.012))
	_flash = maxf(0.0, _flash - delta)
	_edge_mat.set_shader_parameter("emission", Color(1.0, 0.75, 0.2).lerp(Color(1, 1, 0.9), _flash * 2.5))
	var step := int(_t * 5.0)
	for i in _bulbs.size():
		_bulbs[i].set_shader_parameter("emission", Color(1.0, 0.85, 0.35) if (step + i) % 4 == 0 else Color(0.25, 0.12, 0.05))


func _update_info() -> void:
	_info.text = "COINS IN HAND: %d" % _hand if _hand > 0 else "1 TOKEN = %d COINS" % ArcadeRules.PUSHER_COINS_PER_TOKEN
	refresh_top()
