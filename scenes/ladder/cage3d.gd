extends Node3D
## The inside of an arcade cabinet, built straight into the office's 3D world:
## a glass cage you can walk up to and see into from anywhere in the room
## (claw machine, coin pusher, the Fall Guy column). The machine script
## (scenes/ladder/machine.gd) builds into this node in its own local metres
## (x across, y up, +z out of the glass toward you) with mat(), glass(),
## box(), ball(), cyl(), capsule(), solid(), rigid() and set_light().
##
## Everything physical in here lives on its own collision layer (LAYER), so
## prizes, coins and the ragdoll only ever touch the cage (its floor, walls and
## glass) and never the player or the office. Surfaces use retro3d.gdshader
## (per-vertex light from this cage's own lights, fog, dither) so each cabinet
## is lit by its own neon; glass uses glass.gdshader. The ladder pauses the
## cage with its machine when the room is out of reach (physics stops too).

const SHADER := preload("res://scenes/ladder/retro3d.gdshader")
const GLASS := preload("res://scenes/ladder/glass.gdshader")
const FONT := preload("res://fonts/press_start_2p.ttf")
const LIGHTS := 6
## Physics layer 4: the cages' own little world inside the office's.
const LAYER := 1 << 3

var mats: Array[ShaderMaterial] = []
var _look := {}
var _l_pos := PackedVector3Array()
var _l_col := PackedVector3Array()
var _l_range := PackedFloat32Array()
var _dirty := true


## look: ambient, sun_dir, sun_col, fog_col, fog_near, fog_far, levels.
func setup(look: Dictionary) -> void:
	_look = look
	for i in LIGHTS:
		_l_pos.append(Vector3.ZERO)
		_l_col.append(Vector3.ZERO)
		_l_range.append(0.0)


func _ready() -> void:
	_dirty = true


## A light inside the cage, at a point in cage metres.
func set_light(i: int, at: Vector3, color: Color, reach: float, energy := 1.0) -> void:
	_l_pos[i] = at
	_l_col[i] = Vector3(color.r, color.g, color.b) * energy
	_l_range[i] = reach
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty and is_inside_tree():
		_dirty = false
		var world := _world_lights()
		for m in mats:
			_apply(m, world)


func _world_lights() -> PackedVector3Array:
	var out := PackedVector3Array()
	var xf := global_transform
	for p in _l_pos:
		out.append(xf * p)
	return out


func _apply(m: ShaderMaterial, world: PackedVector3Array) -> void:
	var amb: Color = _look.get("ambient", Color(0.3, 0.3, 0.3))
	var sun: Color = _look.get("sun_col", Color.BLACK)
	var fog: Color = _look.get("fog_col", Color.BLACK)
	m.set_shader_parameter("ambient", Vector3(amb.r, amb.g, amb.b))
	m.set_shader_parameter("sun_dir", global_transform.basis * _look.get("sun_dir", Vector3(0.3, 1, 0.4)) if is_inside_tree() else _look.get("sun_dir", Vector3(0.3, 1, 0.4)))
	m.set_shader_parameter("sun_col", Vector3(sun.r, sun.g, sun.b))
	m.set_shader_parameter("fog_col", Vector3(fog.r, fog.g, fog.b))
	m.set_shader_parameter("fog_near", _look.get("fog_near", 4.0))
	m.set_shader_parameter("fog_far", _look.get("fog_far", 40.0))
	m.set_shader_parameter("levels", _look.get("levels", 31.0))
	# Snap to the office's own pixel grid (the world viewport's size).
	m.set_shader_parameter("snap", Vector2(-1, -1))
	m.set_shader_parameter("l_pos", world)
	m.set_shader_parameter("l_col", _l_col)
	m.set_shader_parameter("l_range", _l_range)


## A surface. opts: col2, pattern (0 flat, 1 checker, 2 stripes, 3 speckle,
## 4 tiles), texel (pattern cells per metre), glow (emission colour), shine.
func mat(color: Color, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("albedo2", opts.get("col2", color.darkened(0.3)))
	m.set_shader_parameter("pattern", opts.get("pattern", 0))
	m.set_shader_parameter("texel", opts.get("texel", 8.0))
	m.set_shader_parameter("emission", opts.get("glow", Color.BLACK))
	m.set_shader_parameter("shine", opts.get("shine", 0.0))
	_apply(m, _world_lights() if is_inside_tree() else _l_pos)
	mats.append(m)
	_dirty = true
	return m


func glow(color: Color) -> ShaderMaterial:
	return mat(Color.BLACK, {"glow": color})


## Clear glass: a faint tint, brighter at grazing angles, a slow sheen.
func glass_mat(tint := Color(0.75, 0.9, 1.0), alpha := 0.07) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLASS
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("base_alpha", alpha)
	return m


func _place(n: Node3D, at: Vector3, parent: Node, rot: Vector3) -> void:
	n.position = at
	n.rotation = rot
	(parent if parent else self).add_child(n)


## A box, subdivided so the per-vertex light has points to land on.
func box(dims: Vector3, at: Vector3, m: Material, parent: Node = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dims
	mesh.subdivide_width = clampi(int(dims.x / 0.12), 0, 24)
	mesh.subdivide_height = clampi(int(dims.y / 0.12), 0, 24)
	mesh.subdivide_depth = clampi(int(dims.z / 0.12), 0, 24)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	_place(mi, at, parent, rot)
	return mi


func ball(r: float, at: Vector3, m: Material, parent: Node = null, segs := 8) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = segs
	mesh.rings = maxi(3, segs / 2)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	_place(mi, at, parent, Vector3.ZERO)
	return mi


func cyl(r_top: float, r_bottom: float, h: float, at: Vector3, m: Material, parent: Node = null, rot := Vector3.ZERO, segs := 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bottom
	mesh.height = h
	mesh.radial_segments = segs
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	_place(mi, at, parent, rot)
	return mi


## A capsule standing along y (total height h, caps included).
func capsule(r: float, h: float, at: Vector3, m: Material, parent: Node = null, rot := Vector3.ZERO, segs := 8) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = r
	mesh.height = maxf(h, r * 2.0)
	mesh.radial_segments = segs
	mesh.rings = 2
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	_place(mi, at, parent, rot)
	return mi


func _layers(body: CollisionObject3D) -> void:
	body.collision_layer = LAYER
	body.collision_mask = LAYER


## A box things bump into (StaticBody3D on the cage layer). m = null: unseen.
func solid(dims: Vector3, at: Vector3, m: Material, parent: Node = null, rot := Vector3.ZERO, bounce := 0.1, friction := 0.7) -> StaticBody3D:
	var body := StaticBody3D.new()
	_layers(body)
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = dims
	shape.shape = b
	body.add_child(shape)
	var pm := PhysicsMaterial.new()
	pm.bounce = bounce
	pm.friction = friction
	body.physics_material_override = pm
	_place(body, at, parent, rot)
	if m:
		box(dims, Vector3.ZERO, m, body)
	return body


## A pane of glass: solid on the cage layer, drawn see-through. The collider
## can be thicker than the pane you see (thick = how far it reaches outward
## along `out`), so fast things can't tunnel through it.
func glass(dims: Vector3, at: Vector3, m: Material, parent: Node = null, rot := Vector3.ZERO, bounce := 0.2) -> StaticBody3D:
	var body := solid(dims, at, null, parent, rot, bounce, 0.3)
	box(dims, Vector3.ZERO, m, body)
	return body


## A loose physics object on the cage layer. Add its shapes and meshes, then
## add_child() it (or pass it to add()).
func rigid(at: Vector3, mass := 0.2, friction := 0.7, bounce := 0.1) -> RigidBody3D:
	var b := RigidBody3D.new()
	_layers(b)
	b.position = at
	b.mass = mass
	var pm := PhysicsMaterial.new()
	pm.friction = friction
	pm.bounce = bounce
	b.physics_material_override = pm
	return b


func shape(body: CollisionObject3D, s: Shape3D, at := Vector3.ZERO, rot := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.position = at
	cs.rotation = rot
	body.add_child(cs)
	return cs


func text(t: String, at: Vector3, px: int, color: Color, parent: Node = null, rot := Vector3.ZERO, pixel := 0.002) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font = FONT
	l.font_size = px
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_place(l, at, parent, rot)
	return l


## A ray through the cage, in cage metres; the hit (if any) comes back in
## cage metres too: {position, normal, collider}.
func ray(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var xf := global_transform
	var q := PhysicsRayQueryParameters3D.create(xf * from, xf * to, LAYER)
	q.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		hit.position = xf.affine_inverse() * hit.position
		hit.normal = xf.basis.inverse() * hit.normal
	return hit


## What this shape, placed at `local` (cage metres), would overlap in the
## cage (other than `exclude`): the bodies, nearest first not guaranteed.
func hits(s: Shape3D, local: Transform3D, exclude: Array[RID] = []) -> Array:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = s
	q.transform = global_transform * local
	q.collision_mask = LAYER
	q.exclude = exclude
	q.margin = 0.001
	var out := []
	for r in get_world_3d().direct_space_state.intersect_shape(q, 6):
		out.append(r.collider)
	return out
