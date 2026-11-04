extends GutTest
## engine/fracture.gd: the Voronoi breaking the Rage Cage runs on.

const BOX := Vector3(0.36, 0.27, 0.22)


func _rng(s := 7) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _box_ids() -> PackedInt32Array:
	return PackedInt32Array([0, 0, 0, 0, 0, 0])


func test_a_box_is_one_cell_with_its_own_volume() -> void:
	var planes := Fracture.box_planes(BOX, Vector3(0.1, 1.2, -0.3))
	var c := Fracture.cell(planes, _box_ids())
	assert_eq(c.points.size(), 8)
	assert_eq(c.planes.size(), 6)
	assert_almost_eq(float(c.volume), BOX.x * BOX.y * BOX.z, 0.00001)
	assert_almost_eq(c.center, Vector3(0.1, 1.2, -0.3), Vector3.ONE * 0.0001)
	assert_eq(Fracture.faces(c).size(), 6)


func test_breaking_keeps_every_bit_of_the_solid() -> void:
	var planes := Fracture.box_planes(BOX)
	var pts := Fracture.corners(planes)
	var seeds := Fracture.seeds(planes, pts, 9, Vector3(0, 0.1, 0.1), 0.05, 0.6, _rng())
	assert_eq(seeds.size(), 9, "every seed found a spot inside")
	for s in seeds:
		assert_true(Fracture.inside(planes, s), "seeds are inside")
	var cells := Fracture.cells(planes, _box_ids(), seeds)
	assert_eq(cells.size(), 9, "one piece per seed")
	var total := 0.0
	for c in cells:
		total += float(c.volume)
	assert_almost_eq(total, BOX.x * BOX.y * BOX.z, 0.00001, "the pieces add back up to the box")


func test_fresh_break_faces_are_inner_and_old_faces_keep_their_id() -> void:
	var planes := Fracture.box_planes(BOX)
	var ids := PackedInt32Array([3, 3, 3, 3, 3, 3])
	var seeds := PackedVector3Array([Vector3(-0.1, 0, 0), Vector3(0.1, 0, 0)])
	var cells := Fracture.cells(planes, ids, seeds)
	assert_eq(cells.size(), 2)
	for c in cells:
		var inner := 0
		var outer := 0
		for f in Fracture.faces(c):
			if int(f.id) == Fracture.INNER:
				inner += 1
			else:
				assert_eq(int(f.id), 3)
				outer += 1
		assert_eq(inner, 1, "split once: one break face")
		assert_eq(outer, 5)
		assert_almost_eq(float(c.volume), BOX.x * BOX.y * BOX.z * 0.5, 0.00001)


func test_a_piece_breaks_again_wherever_it_lies() -> void:
	var planes := Fracture.box_planes(BOX)
	var first := Fracture.cells(planes, _box_ids(), PackedVector3Array([Vector3(-0.1, 0, 0), Vector3(0.1, 0, 0)]))
	var piece: Dictionary = first[0]
	# The piece as a body would hold it (its own frame), then tumbled away.
	var lc := Fracture.local(piece, piece.center)
	var xf := Transform3D(Basis(Vector3(1, 1, 0).normalized(), 1.1), Vector3(0.4, 1.5, -0.2))
	var moved := Fracture.moved(lc.planes, xf)
	assert_almost_eq(float(Fracture.cell(moved, lc.ids).volume), float(piece.volume), 0.00001, "moving it changes nothing")
	var pts := Fracture.corners(moved)
	var seeds := Fracture.seeds(moved, pts, 5, xf.origin, 0.04, 0.5, _rng(3))
	var again := Fracture.cells(moved, lc.ids, seeds)
	assert_gt(again.size(), 1)
	var total := 0.0
	for c in again:
		total += float(c.volume)
	assert_almost_eq(total, float(piece.volume), 0.00001)


func test_faces_wind_the_same_way_round() -> void:
	# Each face's corners go round its outward normal one way, so a mesh
	# built from them faces outward everywhere.
	var planes := Fracture.box_planes(BOX)
	var seeds := Fracture.seeds(planes, Fracture.corners(planes), 6, Vector3.ZERO, 0.08, 0.5, _rng(11))
	for c in Fracture.cells(planes, _box_ids(), seeds):
		for f in Fracture.faces(c):
			var poly: PackedVector3Array = f.poly
			var n := Vector3.ZERO
			for i in range(1, poly.size() - 1):
				n += (poly[i] - poly[0]).cross(poly[i + 1] - poly[0])
			assert_gt(n.dot(f.normal), 0.0, "counter-clockwise seen from outside")
