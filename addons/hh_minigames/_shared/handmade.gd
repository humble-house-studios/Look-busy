extends RefCounted
## Hand-made shapes: everything in the office and the cages is built from
## these instead of Godot's perfect boxes, tubes and balls, so it reads as
## something somebody cut, glued and painted. Each shape has
##   - bevelled edges (they catch the light, and the shaders paint them a
##     touch lighter on top and darker underneath, like dry-brushed edges),
##   - corners that are never quite square (pulled inward only, so a shape
##     never grows past the size you asked for and never pokes through its
##     neighbours),
##   - vertex colours the shaders read: r = 0 on a bevel (1 elsewhere),
##     g = how high up the shape (0 bottom, 1 top), b = this piece's own paint
##     mix (1 = the plain colour). A mesh without colours reads as all 1s,
##     so Godot's own meshes still draw exactly as before.
## Meshes are cached by size and variant; pick the variant from where the
## piece sits (`variant_at`) so twins side by side don't match.
## No office code in here (the mini games use it too).

const VARIANTS := 5

static var _cache := {}


## A variant number for a piece at `at` (so the same box in two places differs).
static func variant_at(at: Vector3) -> int:
	var h := int(absf(at.x) * 131.0 + absf(at.y) * 517.0 + absf(at.z) * 293.0 + (7.0 if at.x < 0.0 else 0.0) + (3.0 if at.z < 0.0 else 0.0))
	return h % VARIANTS


## Too thin to bevel (screens, stickers, glowing panels): keep those exact.
static func is_thin(dims: Vector3) -> bool:
	return minf(dims.x, minf(dims.y, dims.z)) < 0.012


## A bevelled, slightly crooked box. `cell` = the longest a face square may
## be (faces are cut into a grid so per-vertex light has points to land on).
static func box(dims: Vector3, variant := 0, cell := 0.3, max_cuts := 24) -> ArrayMesh:
	var key := ["b", dims.snapped(Vector3(0.001, 0.001, 0.001)), variant, cell]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var half := dims * 0.5
	var least := minf(dims.x, minf(dims.y, dims.z))
	var bevel := clampf(least * 0.16, 0.003, 0.03)
	# Corners: each pulled in a little on every axis, more on big pieces.
	var corners := {}
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				var pull := Vector3(
					rng.randf() * clampf(dims.x * 0.035, 0.0, 0.02),
					rng.randf() * clampf(dims.y * 0.035, 0.0, 0.02),
					rng.randf() * clampf(dims.z * 0.035, 0.0, 0.02))
				corners[Vector3i(sx, sy, sz)] = Vector3(sx * (half.x - pull.x), sy * (half.y - pull.y), sz * (half.z - pull.z))
	var tint := 0.55 + rng.randf() * 0.45
	var st := _Soup.new()
	st.half_y = half.y
	st.tint = tint
	var cuts := [
		clampi(int(dims.x / cell), 0, max_cuts) + 1,
		clampi(int(dims.y / cell), 0, max_cuts) + 1,
		clampi(int(dims.z / cell), 0, max_cuts) + 1]
	# The point where corner `c` meets the face across `axis`: the corner,
	# pulled in by the bevel along the other two axes.
	var on_face := func(c: Vector3i, axis: int) -> Vector3:
		var p: Vector3 = corners[c]
		for k in 3:
			if k != axis:
				p[k] -= c[k] * bevel
		return p
	# Six faces.
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for s in [-1, 1]:
			var n := Vector3.ZERO
			n[axis] = s
			var quad := []
			for pair in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
				var c := Vector3i.ZERO
				c[axis] = s
				c[u] = pair[0]
				c[v] = pair[1]
				quad.append(on_face.call(c, axis))
			st.patch(quad[0], quad[1], quad[2], quad[3], n, n, cuts[u], cuts[v], 1.0)
	# Twelve bevelled edges.
	for axis in 3:
		var a := (axis + 1) % 3
		var b := (axis + 2) % 3
		for sa in [-1, 1]:
			for sb in [-1, 1]:
				var lo := Vector3i.ZERO
				lo[axis] = -1
				lo[a] = sa
				lo[b] = sb
				var hi := lo
				hi[axis] = 1
				var na := Vector3.ZERO
				na[a] = sa
				var nb := Vector3.ZERO
				nb[b] = sb
				var n := (na + nb).normalized()
				st.patch(on_face.call(lo, a), on_face.call(hi, a), on_face.call(hi, b), on_face.call(lo, b), n, n, cuts[axis], 1, 0.0)
	# Eight corner chips.
	for c in corners:
		var n := Vector3(c).normalized()
		st.tri(on_face.call(c, 0), on_face.call(c, 1), on_face.call(c, 2), n, n, n, 0.0)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## A turned shape standing along y (a mug, a leg, a bin): rims bevelled, the
## wall never quite round. r_top < 0 = same as the bottom.
static func tube(r_bottom: float, height: float, sides := 8, r_top := -1.0, variant := 0) -> ArrayMesh:
	if r_top < 0.0:
		r_top = r_bottom
	var key := ["t", snappedf(r_bottom, 0.001), snappedf(r_top, 0.001), snappedf(height, 0.001), sides, variant]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var h := height * 0.5
	var bevel := clampf(minf(maxf(r_bottom, r_top), height) * 0.18, 0.0015, 0.02)
	var bb := minf(bevel, r_bottom * 0.5)
	var bt := minf(bevel, r_top * 0.5)
	# Rings from the bottom up: [radius, y].
	var rings := [[r_bottom - bb, -h], [r_bottom, -h + bevel], [r_top, h - bevel], [r_top - bt, h]]
	var wob := PackedFloat32Array()
	for i in sides:
		wob.append(1.0 - rng.randf() * 0.05)
	var lean := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * minf(r_top, 0.2) * 0.04
	var st := _Soup.new()
	st.half_y = h
	st.tint = 0.55 + rng.randf() * 0.45
	var slope := (r_bottom - r_top) / maxf(height, 0.001)
	var point := func(ring: int, i: int) -> Vector3:
		var a := TAU * float(i % sides) / float(sides)
		var r: float = rings[ring][0] * wob[i % sides]
		var y: float = rings[ring][1]
		var t := (y + h) / maxf(height, 0.001)
		return Vector3(sin(a) * r + lean.x * t, y, cos(a) * r + lean.y * t)
	var out := func(i: int, up: float) -> Vector3:
		var a := TAU * float(i % sides) / float(sides)
		return Vector3(sin(a), up, cos(a)).normalized()
	for i in sides:
		var j := i + 1
		# Bottom bevel, wall, top bevel.
		st.quad(point.call(0, i), point.call(0, j), point.call(1, j), point.call(1, i), out.call(i, -1.0), out.call(j, -1.0), out.call(j, -1.0), out.call(i, -1.0), 0.0)
		st.quad(point.call(1, i), point.call(1, j), point.call(2, j), point.call(2, i), out.call(i, slope), out.call(j, slope), out.call(j, slope), out.call(i, slope), 1.0)
		st.quad(point.call(2, i), point.call(2, j), point.call(3, j), point.call(3, i), out.call(i, 1.0), out.call(j, 1.0), out.call(j, 1.0), out.call(i, 1.0), 0.0)
		# Caps.
		st.tri(Vector3(0, -h, 0), point.call(0, i), point.call(0, j), Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, 1.0)
		st.tri(Vector3(lean.x, h, lean.y), point.call(3, i), point.call(3, j), Vector3.UP, Vector3.UP, Vector3.UP, 1.0)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## A lump of clay: `dims` across, round = 1 a ball, toward 0.4 a pillow with
## soft corners (heads, bellies, cushions). Never quite even.
static func blob(dims: Vector3, roundness := 1.0, segs := 10, variant := 0, lumps := 0.05) -> ArrayMesh:
	var key := ["o", dims.snapped(Vector3(0.001, 0.001, 0.001)), snappedf(roundness, 0.01), segs, variant, snappedf(lumps, 0.001)]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var half := dims * 0.5
	var rows := maxi(4, segs * 3 / 5)
	# A few random bumps, the same wherever the surface points the same way.
	var bumps := []
	for i in 4:
		bumps.append([Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf_range(1.5, 3.2), rng.randf() * TAU])
	var st := _Soup.new()
	st.half_y = half.y
	st.tint = 0.6 + rng.randf() * 0.4
	var grid := []
	var norms := []
	for r in rows + 1:
		var lat := -PI * 0.5 + PI * float(r) / float(rows)
		var row := []
		var nrow := []
		for i in segs:
			var lon := TAU * float(i) / float(segs)
			var cl := _pw(cos(lat), roundness)
			var d := Vector3(cl * _pw(sin(lon), roundness), _pw(sin(lat), roundness), cl * _pw(cos(lon), roundness))
			var plain := Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
			var k := 1.0
			for b in bumps:
				k += lumps * 0.5 * sin(plain.dot(b[0]) * b[1] + b[2])
			row.append(d * half * k)
			var cn := _pw(cos(lat), 2.0 - roundness)
			nrow.append((Vector3(cn * _pw(sin(lon), 2.0 - roundness), _pw(sin(lat), 2.0 - roundness), cn * _pw(cos(lon), 2.0 - roundness)) / half.clamp(Vector3.ONE * 0.001, Vector3.ONE * 1000.0)).normalized())
		grid.append(row)
		norms.append(nrow)
	for r in rows:
		for i in segs:
			var j := (i + 1) % segs
			if r == 0:
				st.tri(grid[0][0], grid[1][j], grid[1][i], Vector3.DOWN, norms[1][j], norms[1][i], 1.0)
			elif r == rows - 1:
				st.tri(grid[r][i], grid[r][j], grid[rows][0], norms[r][i], norms[r][j], Vector3.UP, 1.0)
			else:
				st.quad(grid[r][i], grid[r][j], grid[r + 1][j], grid[r + 1][i], norms[r][i], norms[r][j], norms[r + 1][j], norms[r + 1][i], 1.0)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func _pw(x: float, e: float) -> float:
	return signf(x) * pow(absf(x), e)


## Triangle soup with normals and the colours the shaders read.
class _Soup:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var half_y := 1.0
	var tint := 1.0

	func _col(p: Vector3, flat: float) -> Color:
		return Color(flat, clampf(p.y / maxf(half_y, 0.0001) * 0.5 + 0.5, 0.0, 1.0), tint, 1.0)

	## Wound so the front faces along the normals, whichever way a, b, c run.
	func tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, flat: float) -> void:
		if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
			var t := b
			b = c
			c = t
			var tn := nb
			nb = nc
			nc = tn
		verts.append_array([a, b, c])
		norms.append_array([na, nb, nc])
		cols.append_array([_col(a, flat), _col(b, flat), _col(c, flat)])

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, flat: float) -> void:
		tri(a, b, c, na, nb, nc, flat)
		tri(a, c, d, na, nc, nd, flat)

	## A four-cornered patch cut into nu x nv squares (corners a, b, c, d in
	## order round the edge; normal n0 along a-b, n1 along d-c).
	func patch(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n0: Vector3, n1: Vector3, nu: int, nv: int, flat: float) -> void:
		for iu in nu:
			var u0 := float(iu) / nu
			var u1 := float(iu + 1) / nu
			for iv in nv:
				var v0 := float(iv) / nv
				var v1 := float(iv + 1) / nv
				var p00 := a.lerp(b, u0).lerp(d.lerp(c, u0), v0)
				var p10 := a.lerp(b, u1).lerp(d.lerp(c, u1), v0)
				var p11 := a.lerp(b, u1).lerp(d.lerp(c, u1), v1)
				var p01 := a.lerp(b, u0).lerp(d.lerp(c, u0), v1)
				quad(p00, p10, p11, p01, n0, n0, n1, n1, flat)

	func commit() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_COLOR] = cols
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return mesh
