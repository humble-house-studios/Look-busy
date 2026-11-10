extends GutTest
## The hand-made shapes (handmade.gd) everything is modelled from: they stay
## inside the size asked for, carry the paint colours the shaders read, and
## are shared between pieces of the same size.

const Handmade := preload("res://addons/hh_minigames/_shared/handmade.gd")


func _verts(mesh: ArrayMesh) -> PackedVector3Array:
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func test_a_box_never_grows_past_its_size() -> void:
	for dims in [Vector3(1.8, 0.05, 0.8), Vector3(0.07, 0.07, 0.07), Vector3(0.5, 1.3, 0.6)]:
		for variant in Handmade.VARIANTS:
			var half: Vector3 = dims * 0.5 + Vector3.ONE * 0.0001
			for v in _verts(Handmade.box(dims, variant)):
				assert_true(absf(v.x) <= half.x and absf(v.y) <= half.y and absf(v.z) <= half.z, "%s inside %s" % [v, dims])


func test_a_box_faces_outward() -> void:
	var mesh := Handmade.box(Vector3(0.4, 0.3, 0.2))
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	assert_eq(verts.size() % 3, 0)
	for i in range(0, verts.size(), 3):
		# Godot's front faces wind clockwise: the cross product points inward.
		var n := (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i])
		assert_true(n.dot(norms[i]) <= 0.0001, "triangle %d faces its normal" % (i / 3))
		assert_true(norms[i].dot(verts[i] + verts[i + 1] + verts[i + 2]) > 0.0, "normal %d points out" % (i / 3))


func test_shapes_carry_paint_colours() -> void:
	for mesh in [Handmade.box(Vector3(0.3, 0.3, 0.3)), Handmade.tube(0.05, 0.1), Handmade.blob(Vector3(0.2, 0.3, 0.2), 0.6)]:
		var cols: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		assert_eq(cols.size(), _verts(mesh).size())
		var bevel := 0
		for c in cols:
			assert_between(c.g, 0.0, 1.0)
			assert_between(c.b, 0.5, 1.0)
			if c.r < 0.5:
				bevel += 1
		if mesh != Handmade.blob(Vector3(0.2, 0.3, 0.2), 0.6):
			assert_gt(bevel, 0, "edges are marked for dry-brushing")


func test_same_size_shares_a_mesh_and_variants_differ() -> void:
	var dims := Vector3(0.6, 0.4, 0.5)
	assert_same(Handmade.box(dims, 1), Handmade.box(dims, 1))
	assert_ne(_verts(Handmade.box(dims, 1))[0], _verts(Handmade.box(dims, 2))[0])
	assert_true(Handmade.is_thin(Vector3(0.5, 0.004, 0.5)))
	assert_false(Handmade.is_thin(Vector3(0.5, 0.05, 0.5)))


func test_a_tube_and_a_blob_stay_in_bounds() -> void:
	for v in _verts(Handmade.tube(0.1, 0.4, 8, 0.06)):
		assert_true(Vector2(v.x, v.z).length() <= 0.1 + 0.01 and absf(v.y) <= 0.2001)
	for v in _verts(Handmade.blob(Vector3(0.3, 0.2, 0.4), 0.7, 10, 0, 0.05)):
		assert_true(absf(v.x) <= 0.15 * 1.11 and absf(v.y) <= 0.1 * 1.11 and absf(v.z) <= 0.2 * 1.11)
