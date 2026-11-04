class_name Fracture
extends RefCounted
## Breaks a convex solid into convex pieces: a Voronoi fracture, the same
## idea mesh-smashing tools use, done with plain plane maths so it runs on
## every platform (web included) with no addon.
##
## A solid is the space inside a set of planes (normals pointing out, the
## way Geometry3D.build_box_planes makes them). Each plane carries a material
## id: the face it came from keeps its look, and the fresh break surfaces get
## INNER. Scatter seed points inside (more of them near the hit), and every
## seed's cell is the solid cut by the half-way planes to every other seed.
## Pieces are convex too, so a piece can be broken again the same way.
## Pure rules: points and planes in, cells out (no nodes).
##
## A cell is {points, planes, ids, center, volume}; faces() turns one into
## polygons for a mesh.

## The material id of a fresh break surface.
const INNER := -1
## Points closer than this are the same corner.
const MERGE := 0.00002
## A corner lies on a face when it's this close to the face's plane.
const ON_FACE := 0.0002


## A box's planes (outward), centred on `center`.
static func box_planes(size: Vector3, center := Vector3.ZERO) -> Array[Plane]:
	var out: Array[Plane] = []
	for p in Geometry3D.build_box_planes(size * 0.5):
		out.append(Plane(p.normal, p.d + p.normal.dot(center)))
	return out


## The same planes moved by a transform.
static func moved(planes: Array, xf: Transform3D) -> Array[Plane]:
	var out: Array[Plane] = []
	for p in planes:
		out.append(xf * p)
	return out


## Is the point inside every plane (by at least `margin`)?
static func inside(planes: Array[Plane], p: Vector3, margin := 0.0) -> bool:
	for pl in planes:
		if pl.distance_to(p) > -margin:
			return false
	return true


## The corners of the solid inside these planes (duplicates merged).
static func corners(planes: Array[Plane]) -> PackedVector3Array:
	var raw := Geometry3D.compute_convex_mesh_points(planes)
	var out := PackedVector3Array()
	for p in raw:
		var dup := false
		for q in out:
			if p.distance_squared_to(q) < MERGE * MERGE:
				dup = true
				break
		if not dup:
			out.append(p)
	return out


## Seed points inside the solid: `count` of them, `near` of that share
## clustered within `radius` of `at` (the hit), the rest anywhere. Points
## too close to the surface are skipped so no cell comes out paper-thin.
static func seeds(planes: Array[Plane], pts: PackedVector3Array, count: int, at: Vector3, radius: float, near: float, rng: RandomNumberGenerator) -> PackedVector3Array:
	var box := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		box = box.expand(p)
	var margin := minf(box.size[box.get_shortest_axis_index()] * 0.12, 0.01)
	var out := PackedVector3Array()
	var want_near := int(round(count * clampf(near, 0.0, 1.0)))
	var tries := 0
	while out.size() < count and tries < count * 60:
		tries += 1
		var p: Vector3
		if out.size() < want_near:
			p = at + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * radius
		else:
			p = box.position + Vector3(rng.randf() * box.size.x, rng.randf() * box.size.y, rng.randf() * box.size.z)
		if not inside(planes, p, margin):
			continue
		var crowded := false
		for q in out:
			if p.distance_squared_to(q) < margin * margin * 4.0:
				crowded = true
				break
		if not crowded:
			out.append(p)
	return out


## Break the solid at the seeds. ids[i] is planes[i]'s material id. Cells
## smaller than min_volume are dropped (dust).
static func cells(planes: Array[Plane], ids: PackedInt32Array, sites: PackedVector3Array, min_volume := 0.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in sites.size():
		var cut: Array[Plane] = planes.duplicate()
		var cut_ids := ids.duplicate()
		for j in sites.size():
			if i == j:
				continue
			var n := (sites[j] - sites[i]).normalized()
			var mid := (sites[i] + sites[j]) * 0.5
			cut.append(Plane(n, n.dot(mid)))
			cut_ids.append(INNER)
		var c := cell(cut, cut_ids)
		if not c.is_empty() and float(c.volume) > min_volume:
			out.append(c)
	return out


## One convex solid: its corners, only the planes that really make a face
## (with their ids), its centre and volume. {} if it's empty.
static func cell(planes: Array[Plane], ids: PackedInt32Array) -> Dictionary:
	var pts := corners(planes)
	if pts.size() < 4:
		return {}
	var keep: Array[Plane] = []
	var keep_ids := PackedInt32Array()
	for k in planes.size():
		var on := 0
		for p in pts:
			if absf(planes[k].distance_to(p)) < ON_FACE:
				on += 1
		if on < 3:
			continue
		# Two cuts can land on the same plane; keep one.
		var same := false
		for q in keep:
			if q.normal.dot(planes[k].normal) > 0.9999 and absf(q.d - planes[k].d) < ON_FACE:
				same = true
				break
		if not same:
			keep.append(planes[k])
			keep_ids.append(ids[k])
	var center := Vector3.ZERO
	for p in pts:
		center += p
	center /= pts.size()
	var c := {"points": pts, "planes": keep, "ids": keep_ids, "center": center, "volume": 0.0}
	c.volume = volume(c)
	if keep.size() < 4:
		return {}
	return c


## Each face as a polygon: [{id, normal, poly}], corners in order going
## counter-clockwise seen from outside.
static func faces(c: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pts: PackedVector3Array = c.points
	var planes: Array = c.planes
	var ids: PackedInt32Array = c.ids
	for k in planes.size():
		var pl: Plane = planes[k]
		var on := PackedVector3Array()
		for p in pts:
			if absf(pl.distance_to(p)) < ON_FACE:
				on.append(p)
		if on.size() < 3:
			continue
		var mid := Vector3.ZERO
		for p in on:
			mid += p
		mid /= on.size()
		var u := (on[0] - mid).normalized()
		if u.length_squared() < 0.5:
			u = pl.normal.cross(Vector3.UP if absf(pl.normal.y) < 0.9 else Vector3.RIGHT).normalized()
		var v := pl.normal.cross(u)
		var order := []
		for p in on:
			order.append([atan2((p - mid).dot(v), (p - mid).dot(u)), p])
		order.sort_custom(func(a, b): return a[0] < b[0])
		var poly := PackedVector3Array()
		for o in order:
			poly.append(o[1])
		out.append({"id": ids[k], "normal": pl.normal, "poly": poly})
	return out


## Volume, from the faces (a fan of tetrahedra from the centre).
static func volume(c: Dictionary) -> float:
	var total := 0.0
	var o: Vector3 = c.center
	for f in faces(c):
		var poly: PackedVector3Array = f.poly
		for i in range(1, poly.size() - 1):
			total += absf((poly[0] - o).dot((poly[i] - o).cross(poly[i + 1] - o))) / 6.0
	return total


## The same cell with every point, plane and the centre moved by `-at`
## (so a body can sit at `at` and hold it in its own frame).
static func local(c: Dictionary, at: Vector3) -> Dictionary:
	var pts := PackedVector3Array()
	for p in c.points:
		pts.append(p - at)
	var pl: Array[Plane] = []
	for p in c.planes:
		pl.append(Plane(p.normal, p.d - p.normal.dot(at)))
	return {"points": pts, "planes": pl, "ids": c.ids, "center": c.center - at, "volume": c.volume}
