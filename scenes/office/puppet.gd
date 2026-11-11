extends RefCounted
## The people of Humble House: Dale, the coworkers, the bosses, the board and
## the stand-in you. Each body is ONE smooth mesh (one MeshInstance3D, one
## surface per colour): the torso is lofted from rings (hips, waist, belly,
## chest, shoulders, neck), and each arm and leg is a single tube swept along
## a smooth curve from inside the torso through the elbow or knee to a
## mitten hand or a shoe, so shoulders, elbows, wrists and ankles all flow
## with no seams or gaps. Collars, ties, belts and badges are baked into the
## same mesh. The head is one mesh too (it turns on its own node), with the
## eyes and mouth as separate little pieces because they blink and talk.
## Everything keeps the hand-made wobble and paint (handmade.gd colours).
##
## build() fills `body` and returns the bits the office animates:
##   {head, mouth, eyes}  (head turns, mouth.scale.y opens, eyes blink by scale.y)
## look (all optional): skin, shirt, pants, hair, hair_style (short, bob,
##   curls, slick, cap_back, flat_cap, horseshoe), cap, glasses, moustache,
##   beard, tie, strap, lanyard, collar, wide (1 = average), belly (true = a
##   big round one), brows (tilt, + = stern), sleeves ("short" = bare forearms).
## pose: "stand", "sit" (hands in the lap) or "desk" (seated, forearms on a
##   desk in front). drop = how far a seated body sinks.

const Handmade := preload("res://addons/hh_minigames/_shared/handmade.gd")
const SIT_DROP := 0.32


## A material from the room's own maker (office._mat's arguments).
static func _m(mat: Callable, c: Color, pattern := 0, c2 := Color.BLACK, texel := 24.0, glow := Color.BLACK) -> Material:
	return mat.call(c, pattern, c2, texel, glow)


static func build(o: Node, body: Node3D, look: Dictionary, mat: Callable, pose := "stand", drop := SIT_DROP) -> Dictionary:
	var skin_c: Color = look.get("skin", Color(0.9, 0.7, 0.55))
	var shirt_c: Color = look.get("shirt", Color(0.5, 0.5, 0.6))
	var hair_c: Color = look.get("hair", Color(0.25, 0.18, 0.12))
	var skin: Material = _m(mat, skin_c)
	var blush: Material = _m(mat, skin_c.lerp(Color(0.95, 0.35, 0.3), 0.2))
	var shade: Material = _m(mat, skin_c.darkened(0.08))
	var shirt: Material = _m(mat, shirt_c, 6, Color.BLACK, 40.0)
	var trim: Material = _m(mat, shirt_c.lightened(0.25))
	var pants: Material = _m(mat, look.get("pants", Color(0.2, 0.2, 0.25)), 6, Color.BLACK, 40.0)
	var hair: Material = _m(mat, hair_c, 6, Color.BLACK, 50.0)
	var dark: Material = _m(mat, Color(0.08, 0.08, 0.1))
	var shoe: Material = _m(mat, Color(0.16, 0.11, 0.09))
	var white: Material = _m(mat, Color(0.96, 0.95, 0.9))
	var w: float = look.get("wide", 1.0)
	var belly: bool = look.get("belly", false)
	var seated := pose != "stand"
	body.position.y = -drop if seated else 0.0
	var b := Shape.new()
	b.seed = hash(look)

	# ---- the torso: one loft from the crotch to the top of the neck.
	# Rings: [y, half width, front depth, back depth, material of the band above].
	var rings := [
		[0.8, 0.13 * w, 0.09 * w, 0.1 * w, pants],
		[0.85, 0.19 * w, 0.125 * w, 0.14 * w, pants],
		[0.93, 0.2 * w, 0.13 * w, 0.13 * w, shirt],
		[1.02, 0.205 * w, 0.135 * w, 0.13 * w, shirt],
		[1.14, 0.215 * w, 0.145 * w, 0.135 * w, shirt],
		[1.26, 0.235 * w, 0.15 * w, 0.14 * w, shirt],
		[1.33, 0.235 * w, 0.135 * w, 0.13 * w, shirt],
		[1.39, 0.19 * w, 0.11 * w, 0.1 * w, shirt],
		[1.43, 0.11 * w, 0.075 * w, 0.075 * w, shirt],
		[1.455, 0.062, 0.06, 0.058, shade],
		[1.54, 0.055, 0.052, 0.05, shade],
	]
	if belly:
		# A big round one: the front swells out from the belt to the chest.
		for r in rings:
			var y: float = r[0]
			var k := clampf(1.0 - absf(y - 1.06) / 0.2, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			r[2] = lerpf(r[2], 0.33 * w, k)
			r[1] = lerpf(r[1], 0.26 * w, k * 0.9)
	b.loft(rings, 14)
	var front := func(y: float) -> float:
		# The front of the torso at height y (for things worn on the chest).
		for i in rings.size() - 1:
			if y >= rings[i][0] and y <= rings[i + 1][0]:
				return lerpf(rings[i][2], rings[i + 1][2], (y - rings[i][0]) / (rings[i + 1][0] - rings[i][0]))
		return 0.15 * w

	# ---- legs and shoes: one tube each, hip to toe.
	for side in [-1.0, 1.0]:
		var x: float = side * 0.1 * w
		var pts: Array
		if seated:
			var floor_y := drop
			pts = [
				[Vector3(x * 0.8, 0.9, -0.03), 0.07, pants],
				[Vector3(x, 0.86, 0.06), 0.088, pants],
				[Vector3(x * 1.05, 0.85, 0.4), 0.074, pants],
				[Vector3(x * 1.08, 0.62, 0.45), 0.064, pants],
				[Vector3(x * 1.08, floor_y + 0.12, 0.44), 0.058, shoe],
				[Vector3(x * 1.08, floor_y + 0.06, 0.5), Vector2(0.05, 0.06), shoe],
				[Vector3(x * 1.1, floor_y + 0.045, 0.6), Vector2(0.038, 0.052), shoe],
			]
			b.lump(Vector3(0.1, 0.09, 0.1), Vector3(x * 1.08, floor_y + 0.05, 0.42), shoe)
		else:
			pts = [
				[Vector3(x * 0.8, 0.95, 0.0), 0.07, pants],
				[Vector3(x, 0.84, 0.0), 0.088, pants],
				[Vector3(x * 1.05, 0.47, 0.015), 0.07, pants],
				[Vector3(x * 1.08, 0.13, 0.0), 0.06, shoe],
				[Vector3(x * 1.08, 0.055, 0.06), Vector2(0.05, 0.062), shoe],
				[Vector3(x * 1.1, 0.045, 0.16), Vector2(0.038, 0.054), shoe],
			]
			b.lump(Vector3(0.11, 0.09, 0.11), Vector3(x * 1.08, 0.05, -0.015), shoe)
		# The tube's first axis leans along these (thighs on a seat run
		# forward, so theirs leans up; the shoes lie flat).
		var z := Vector3(0, 0, 1)
		var refs := [Vector3.UP, Vector3.UP, Vector3.UP, z, z, Vector3.UP, Vector3.UP] if seated else [z, z, z, z, Vector3.UP, Vector3.UP]
		b.sweep(pts, refs, 9)

	# ---- arms and hands: one tube each, from inside the shoulder to the
	# fingertips, bending smoothly at the elbow and wrist.
	var bare: bool = look.get("sleeves", "") == "short"
	var sleeve: Material = skin if bare else shirt
	var out := 1.0 + (0.12 if belly else 0.0)
	for side in [-1.0, 1.0]:
		var s: float = side * w
		var arm: Array
		var refs: Array
		match pose:
			"desk":
				# Upper arm down and a little forward, forearm resting on the desk.
				arm = [
					[Vector3(s * 0.12, 1.36, 0.0), 0.05, shirt],
					[Vector3(s * 0.235, 1.34, 0.0), 0.068, shirt],
					[Vector3(s * 0.27 * out, 1.25, 0.03), 0.062, sleeve],
					[Vector3(s * 0.285 * out, 1.14, 0.1), 0.055, sleeve],
					[Vector3(s * 0.25 * out, 1.115, 0.3), 0.048, sleeve],
					[Vector3(s * 0.21, 1.11, 0.43), 0.042, skin],
					[Vector3(s * 0.17, 1.105, 0.52), Vector2(0.024, 0.046), skin],
					[Vector3(s * 0.15, 1.1, 0.585), Vector2(0.018, 0.036), skin],
				]
				refs = [Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
			"sit":
				arm = [
					[Vector3(s * 0.12, 1.36, 0.0), 0.05, shirt],
					[Vector3(s * 0.235, 1.34, 0.0), 0.068, shirt],
					[Vector3(s * 0.265 * out, 1.24, 0.01), 0.062, sleeve],
					[Vector3(s * 0.275 * out, 1.1, 0.06), 0.055, sleeve],
					[Vector3(s * 0.22 * out, 1.0, 0.22), 0.048, sleeve],
					[Vector3(s * 0.17, 0.965, 0.32), 0.042, skin],
					[Vector3(s * 0.13, 0.955, 0.4), Vector2(0.024, 0.046), skin],
					[Vector3(s * 0.11, 0.95, 0.46), Vector2(0.018, 0.036), skin],
				]
				refs = [Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
			_:
				# Hanging, a slight bend at the elbow, palms toward the legs.
				arm = [
					[Vector3(s * 0.12, 1.36, 0.0), 0.05, shirt],
					[Vector3(s * 0.235, 1.34, 0.0), 0.068, shirt],
					[Vector3(s * 0.27 * out, 1.24, 0.0), 0.062, sleeve],
					[Vector3(s * 0.29 * out, 1.07, -0.005), 0.055, sleeve],
					[Vector3(s * 0.3 * out, 0.93, 0.03), 0.048, sleeve],
					[Vector3(s * 0.305 * out, 0.84, 0.05), 0.042, skin],
					[Vector3(s * 0.305 * out, 0.77, 0.055), Vector2(0.046, 0.024), skin],
					[Vector3(s * 0.3 * out, 0.715, 0.05), Vector2(0.036, 0.018), skin],
				]
				refs = [Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK]
		if bare:
			# Short sleeves stop just above the elbow, with a hem.
			arm[3][2] = skin
			b.ring(arm[2][0], arm[3][0] - arm[1][0], 0.068, 0.02, shirt)
		else:
			# A cuff where the sleeve meets the hand.
			b.ring(arm[5][0], arm[6][0] - arm[4][0], 0.05, 0.03, trim)
		b.sweep(arm, refs, 8)
		# The thumb, tucked along the inside of the hand.
		var hand: Vector3 = arm[6][0]
		var wrist: Vector3 = arm[5][0]
		var along := (hand - wrist).normalized()
		var inward := Vector3(-side, 0, 0)
		if pose == "stand":
			b.sweep([[wrist + inward * 0.02, 0.022, skin], [hand + inward * 0.03 + Vector3(0, 0, 0.02) - along * 0.02, 0.018, skin],
				[hand + inward * 0.02 + Vector3(0, 0, 0.035), 0.014, skin]], [Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1)], 6)
		else:
			b.sweep([[wrist + inward * 0.02 + Vector3(0, 0.005, 0), 0.022, skin], [hand + inward * 0.04 - along * 0.015, 0.018, skin],
				[hand + inward * 0.045 + along * 0.02, 0.014, skin]], [Vector3.UP, Vector3.UP, Vector3.UP], 6)

	# ---- what they wear, baked into the same mesh
	if look.has("tie") and not belly:
		b.ring(Vector3(0, 0.92, 0.005), Vector3.UP, 0.0, 0.035, dark, Vector2(0.205 * w, 0.137 * w))
	if look.has("tie"):
		var tie: Material = _m(mat, look.tie, 4, (look.tie as Color).darkened(0.2), 40.0)
		b.lump(Vector3(0.07, 0.06, 0.045), Vector3(0, 1.405, front.call(1.405) + 0.012), tie, 0.8)
		# One flat strip down the shirt front (over the belly if there is
		# one), widening to a point at the bottom.
		var tip_y := 1.0 if belly else 1.05
		var strip := []
		for k in 6:
			var y: float = lerpf(1.39, tip_y, k / 5.0)
			strip.append([Vector3(0, y, front.call(y) + 0.01), Vector2(0.006, lerpf(0.026, 0.04, k / 5.0)), tie])
		strip.append([Vector3(0, tip_y - 0.035, front.call(tip_y - 0.035) + 0.012), Vector2(0.006, 0.012), tie])
		b.sweep(strip, _same(Vector3.BACK, strip.size()), 6)
	if look.has("tie") or look.get("collar", false):
		for side in [-1.0, 1.0]:
			b.box(Vector3(0.09, 0.05, 0.02), Vector3(side * 0.055, 1.425, front.call(1.425) + 0.005), trim, Vector3(-0.3, 0, side * 0.5))
	if look.has("strap"):
		# Overall straps over each shoulder down to the bib.
		var strap: Material = _m(mat, look.strap)
		for side in [-1.0, 1.0]:
			var band := []
			for y in [1.4, 1.32, 1.2, 1.08, 1.0]:
				band.append([Vector3(side * 0.12 * w, y, front.call(y) + 0.008), Vector2(0.006, 0.03), strap])
			b.sweep(band, _same(Vector3.BACK, band.size()), 6)
			b.lump(Vector3(0.04, 0.04, 0.02), Vector3(side * 0.12 * w, 1.0, front.call(1.0) + 0.02), _m(mat, Color(0.78, 0.66, 0.3)))
		b.box(Vector3(0.34 * w, 0.14, 0.02), Vector3(0, 0.94, front.call(0.94) + 0.006), strap)
	if look.get("lanyard", false):
		var cord: Material = _m(mat, Color(0.85, 0.25, 0.3))
		var loop := []
		for k in 7:
			var a := lerpf(-1.0, 1.0, k / 6.0)
			var y: float = 1.43 - (1.0 - a * a) * 0.29
			loop.append([Vector3(a * 0.075, y, front.call(y) + 0.01), 0.007, cord])
		b.sweep(loop, _same(Vector3.BACK, loop.size()), 5)
		b.box(Vector3(0.1, 0.13, 0.014), Vector3(0, 1.08, front.call(1.08) + 0.014), white, Vector3(0, 0, 0.06))
		b.box(Vector3(0.1, 0.03, 0.014), Vector3(0.002, 1.125, front.call(1.125) + 0.016), cord, Vector3(0, 0, 0.06))
	b.commit(o, body)

	# ---- the head: one mesh on its own node (it turns to look at you).
	var head := Node3D.new()
	head.position = Vector3(0, 1.48, 0)
	body.add_child(head)
	var h := Shape.new()
	h.seed = hash(look) + 7
	# A soft block of a head, a little narrower at the jaw.
	h.lump(Vector3(0.26, 0.27, 0.25), Vector3(0, 0.16, 0), skin, 0.62)
	h.lump(Vector3(0.21, 0.14, 0.21), Vector3(0, 0.07, 0.012), skin, 0.75)
	for side in [-1.0, 1.0]:
		h.lump(Vector3(0.04, 0.075, 0.05), Vector3(side * 0.13, 0.145, -0.005), shade)
		h.lump(Vector3(0.058, 0.042, 0.014), Vector3(side * 0.076, 0.095, 0.11), blush, 1.0, Vector3(0, side * 0.35, 0))
	h.lump(Vector3(0.044, 0.06, 0.055), Vector3(0, 0.122, 0.124), blush)
	var tilt: float = look.get("brows", 0.0)
	for side in [-1.0, 1.0]:
		h.box(Vector3(0.07, 0.016, 0.014), Vector3(side * 0.058, 0.222 - tilt * 0.01, 0.126), hair, Vector3(0, 0, side * (-0.14 - tilt)))
		# The corners of the mouth, turned up a touch (down if they're stern).
		h.box(Vector3(0.022, 0.012, 0.012), Vector3(side * 0.045, 0.062 - tilt * 0.02, 0.117), shade, Vector3(0, 0, side * (0.5 - tilt * 3.0)))
	if look.get("glasses", false):
		var gz := 0.139
		var lens: Material = _m(mat, Color(0.75, 0.85, 0.9), 0, Color.BLACK, 24.0, Color(0.1, 0.12, 0.15))
		for side in [-1.0, 1.0]:
			h.box(Vector3(0.068, 0.05, 0.004), Vector3(side * 0.058, 0.172, gz - 0.003), lens)
			for bar in [[Vector3(0.082, 0.012, 0.012), Vector3(0, 0.03, 0)], [Vector3(0.082, 0.012, 0.012), Vector3(0, -0.03, 0)],
					[Vector3(0.012, 0.062, 0.012), Vector3(0.038, 0, 0)], [Vector3(0.012, 0.062, 0.012), Vector3(-0.038, 0, 0)]]:
				h.box(bar[0], Vector3(side * 0.058, 0.172, gz) + bar[1], dark)
			h.box(Vector3(0.012, 0.012, 0.13), Vector3(side * 0.128, 0.18, 0.07), dark)
		h.box(Vector3(0.036, 0.012, 0.012), Vector3(0, 0.178, 0.139), dark)
	_hair(h, look, hair, mat)
	if look.get("beard", false):
		var grey: Material = _m(mat, Color(0.72, 0.72, 0.7), 6, Color.BLACK, 50.0)
		h.lump(Vector3(0.24, 0.13, 0.12), Vector3(0, 0.03, 0.07), grey, 0.75)
		for side in [-1.0, 1.0]:
			h.lump(Vector3(0.05, 0.14, 0.1), Vector3(side * 0.115, 0.08, 0.03), grey, 0.8)
	if look.get("moustache", false):
		for side in [-1.0, 1.0]:
			h.lump(Vector3(0.075, 0.035, 0.03), Vector3(side * 0.032, 0.086, 0.13), hair, 0.9, Vector3(0, 0, -side * 0.25))
	h.commit(o, head)

	# Eyes (they blink) and the mouth (it talks) stay their own pieces.
	var eyes: Array = []
	for side in [-1.0, 1.0]:
		var e := Node3D.new()
		e.position = Vector3(side * 0.056, 0.175, 0.117)
		head.add_child(e)
		var es := Shape.new()
		es.lump(Vector3(0.056, 0.05, 0.026), Vector3.ZERO, white)
		es.lump(Vector3(0.026, 0.032, 0.02), Vector3(-side * 0.004, -0.003, 0.009), dark)
		es.commit(o, e)
		eyes.append(e)
	var mouth := Node3D.new()
	mouth.position = Vector3(0, 0.058, 0.118)
	head.add_child(mouth)
	var ms := Shape.new()
	ms.box(Vector3(0.075, 0.032, 0.012), Vector3.ZERO, _m(mat, Color(0.35, 0.1, 0.1)))
	ms.commit(o, mouth)
	mouth.scale.y = 0.25
	return {"head": head, "mouth": mouth, "eyes": eyes}


static func _same(v: Vector3, n: int) -> Array:
	var a := []
	a.resize(n)
	a.fill(v)
	return a


static func _hair(h: Shape, look: Dictionary, hair: Material, mat: Callable) -> void:
	match look.get("hair_style", "short"):
		"short":
			h.lump(Vector3(0.275, 0.14, 0.27), Vector3(0, 0.265, -0.012), hair, 0.7)
			h.lump(Vector3(0.26, 0.16, 0.1), Vector3(0, 0.19, -0.095), hair, 0.75)
			# A fringe, combed to one side.
			h.lump(Vector3(0.2, 0.05, 0.06), Vector3(0.02, 0.268, 0.105), hair, 0.8, Vector3(0, 0, -0.12))
			for side in [-1.0, 1.0]:
				h.lump(Vector3(0.03, 0.09, 0.1), Vector3(side * 0.13, 0.22, -0.02), hair)
		"bob":
			h.lump(Vector3(0.3, 0.16, 0.29), Vector3(0, 0.265, -0.012), hair, 0.72)
			for side in [-1.0, 1.0]:
				h.lump(Vector3(0.07, 0.26, 0.24), Vector3(side * 0.135, 0.14, -0.02), hair, 0.75)
			h.lump(Vector3(0.28, 0.27, 0.09), Vector3(0, 0.145, -0.115), hair, 0.75)
			h.lump(Vector3(0.22, 0.055, 0.06), Vector3(0, 0.262, 0.105), hair, 0.8)
		"curls":
			for i in 9:
				var a := -PI * 0.15 + i * PI * 1.3 / 8.0
				h.lump(Vector3.ONE * 0.15, Vector3(cos(a) * 0.14, 0.24 + sin(a) * 0.09, -0.015 - absf(cos(a)) * 0.02), hair)
			for i in 5:
				var a := -PI * 0.1 + i * PI * 1.2 / 4.0
				h.lump(Vector3.ONE * 0.14, Vector3(cos(a) * 0.1, 0.2 + sin(a) * 0.07, -0.1), hair)
			h.lump(Vector3(0.31, 0.19, 0.29), Vector3(0, 0.3, -0.04), hair)
		"slick":
			h.lump(Vector3(0.275, 0.11, 0.28), Vector3(0, 0.28, -0.02), hair, 0.75, Vector3(-0.15, 0, 0))
			h.lump(Vector3(0.26, 0.15, 0.09), Vector3(0, 0.2, -0.1), hair, 0.75)
			# The quiff he spends ten minutes on.
			h.lump(Vector3(0.16, 0.07, 0.08), Vector3(0.01, 0.305, 0.085), hair, 0.85, Vector3(-0.3, 0, 0))
		"cap_back":
			var cap_c: Color = look.get("cap", Color(0.8, 0.15, 0.15))
			var cap: Material = _m(mat, cap_c, 6, Color.BLACK, 40.0)
			h.lump(Vector3(0.29, 0.15, 0.28), Vector3(0, 0.27, -0.005), cap, 0.8)
			h.lump(Vector3(0.21, 0.03, 0.15), Vector3(0, 0.245, -0.18), cap, 0.6, Vector3(0.2, 0, 0))
			h.lump(Vector3(0.14, 0.05, 0.04), Vector3(0, 0.235, 0.115), hair)
			h.lump(Vector3(0.04, 0.04, 0.03), Vector3(0, 0.345, 0), _m(mat, cap_c.darkened(0.3)))
		"flat_cap":
			var cap_c: Color = look.get("cap", Color(0.3, 0.3, 0.32))
			var cap: Material = _m(mat, cap_c, 3, cap_c.darkened(0.18), 60.0)
			h.lump(Vector3(0.31, 0.1, 0.32), Vector3(0, 0.3, 0.015), cap, 0.7, Vector3(0.12, 0, 0))
			h.lump(Vector3(0.24, 0.03, 0.12), Vector3(0, 0.262, 0.165), cap, 0.6, Vector3(0.25, 0, 0))
			h.lump(Vector3(0.27, 0.1, 0.1), Vector3(0, 0.2, -0.09), hair, 0.75)
		"horseshoe":
			# Bald and shiny on top, a horseshoe of hair round the sides and back.
			h.lump(Vector3(0.275, 0.12, 0.11), Vector3(0, 0.2, -0.085), hair, 0.75)
			for side in [-1.0, 1.0]:
				h.lump(Vector3(0.05, 0.11, 0.17), Vector3(side * 0.123, 0.2, -0.01), hair, 0.8)
			h.lump(Vector3(0.09, 0.02, 0.07), Vector3(-0.03, 0.296, 0.03), _m(mat, (look.get("skin", Color(0.9, 0.7, 0.55)) as Color).lightened(0.3)))


## Builds one mesh, one surface per material: lofts, swept tubes, and
## hand-made pieces (handmade.gd) moved into place. Everything is triangle
## soup with the paint colours the shaders read.
class Shape:
	var seed := 0
	var _parts := {}  # Material -> [verts, normals, colours]
	var _order: Array = []

	func _part(m: Material) -> Array:
		if not _parts.has(m):
			_parts[m] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
			_order.append(m)
		return _parts[m]

	## Copy a hand-made mesh in, turned by rot, scaled by scale, moved to at.
	func add(mesh: ArrayMesh, at: Vector3, m: Material, rot := Vector3.ZERO, scale := Vector3.ONE) -> void:
		var arr := mesh.surface_get_arrays(0)
		var basis := Basis.from_euler(rot) * Basis.from_scale(scale)
		var p := _part(m)
		p[0].append_array(Transform3D(basis, at) * (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array))
		var nb := basis.inverse().transposed()
		var ns := PackedVector3Array(arr[Mesh.ARRAY_NORMAL])
		for i in ns.size():
			ns[i] = (nb * ns[i]).normalized()
		p[1].append_array(ns)
		p[2].append_array(arr[Mesh.ARRAY_COLOR])

	func lump(dims: Vector3, at: Vector3, m: Material, soft := 1.0, rot := Vector3.ZERO) -> void:
		add(Handmade.blob(dims, soft, 10, Handmade.variant_at(at + dims)), at, m, rot)

	func box(dims: Vector3, at: Vector3, m: Material, rot := Vector3.ZERO) -> void:
		var mesh: ArrayMesh
		if Handmade.is_thin(dims):
			mesh = Handmade.box(dims.max(Vector3.ONE * 0.012), 0)
			add(mesh, at, m, rot, dims / dims.max(Vector3.ONE * 0.012))
			return
		add(Handmade.box(dims, Handmade.variant_at(at + dims)), at, m, rot)

	## A band round a limb or the waist: centred at `at`, its axis along
	## `axis`; radius r (or an ellipse `oval` across), `height` tall.
	func ring(at: Vector3, axis: Vector3, r: float, height: float, m: Material, oval := Vector2.ZERO) -> void:
		var y := axis.normalized()
		var x := y.cross(Vector3.FORWARD).normalized() if absf(y.dot(Vector3.FORWARD)) < 0.9 else y.cross(Vector3.RIGHT).normalized()
		var z := x.cross(y)
		var size := Vector3(oval.x, 1.0, oval.y) if oval != Vector2.ZERO else Vector3(r, 1.0, r)
		var basis := Basis(x * size.x, y, z * size.z)
		var mesh := Handmade.tube(1.0, height, 12)
		var arr := mesh.surface_get_arrays(0)
		var p := _part(m)
		p[0].append_array(Transform3D(basis, at) * (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array))
		var nb := basis.inverse().transposed()
		var ns := PackedVector3Array(arr[Mesh.ARRAY_NORMAL])
		for i in ns.size():
			ns[i] = (nb * ns[i]).normalized()
		p[1].append_array(ns)
		p[2].append_array(arr[Mesh.ARRAY_COLOR])

	## A loft round the vertical: rings [y, half width, front, back, material
	## of the band above], capped top and bottom.
	func loft(rings: Array, sides: int) -> void:
		var pts: Array = []
		var nrm: Array = []
		var top: float = rings[-1][0]
		for r in rings:
			var row := []
			var nrow := []
			for i in sides:
				var a := TAU * float(i) / sides
				var depth: float = r[2] if cos(a) >= 0.0 else r[3]
				var k := 1.0 + _wob(r[0] * 31.0 + i) * 0.025
				row.append(Vector3(sin(a) * r[1] * k, r[0], cos(a) * depth * k))
				nrow.append(Vector3(sin(a) / maxf(r[1], 0.01), 0.0, cos(a) / maxf(depth, 0.01)).normalized())
			pts.append(row)
			nrm.append(nrow)
		# Bands, with the slope of the profile folded into the normals.
		for j in rings.size() - 1:
			var m: Material = rings[j][4]
			for i in sides:
				var i2 := (i + 1) % sides
				var n00 := _slope(nrm[j][i], pts, j, i)
				var n01 := _slope(nrm[j][i2], pts, j, i2)
				var n10 := _slope(nrm[j + 1][i], pts, j + 1, i)
				var n11 := _slope(nrm[j + 1][i2], pts, j + 1, i2)
				_quad(m, pts[j][i], pts[j][i2], pts[j + 1][i2], pts[j + 1][i], n00, n01, n11, n10, top)
		# Caps.
		var bottom: Vector3 = Vector3(0, rings[0][0] - 0.03, 0)
		var lid: Vector3 = Vector3(0, top, 0)
		for i in sides:
			var i2 := (i + 1) % sides
			_tri(rings[0][4], bottom, pts[0][i2], pts[0][i], Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, top)
			_tri(rings[-2][4], lid, pts[-1][i], pts[-1][i2], Vector3.UP, Vector3.UP, Vector3.UP, top)

	func _slope(n: Vector3, pts: Array, j: int, i: int) -> Vector3:
		var lo: Vector3 = pts[maxi(j - 1, 0)][i]
		var hi: Vector3 = pts[mini(j + 1, pts.size() - 1)][i]
		var d := hi - lo
		var flat := Vector2(n.x, n.z).length()
		var run := Vector2(d.x, d.z).dot(Vector2(n.x, n.z).normalized()) if flat > 0.0 else 0.0
		# Tilt the outward normal up where the profile narrows going up.
		var up := -run / maxf(absf(d.y), 0.005)
		return (n + Vector3.UP * clampf(up, -3.0, 3.0)).normalized()

	## A tube swept through points [[position, radius (float or Vector2
	## across), material of the stretch after it]], smoothed through every
	## point; `refs` = one direction per point that the tube's first
	## cross-section axis leans toward (a flat hand lies along it). Both ends
	## are rounded off.
	func sweep(points: Array, refs: Array, sides: int) -> void:
		var n := points.size()
		var samples: Array = []  # [pos, radius Vector2, material, ref]
		for j in n - 1:
			var p0: Vector3 = points[maxi(j - 1, 0)][0]
			var p1: Vector3 = points[j][0]
			var p2: Vector3 = points[j + 1][0]
			var p3: Vector3 = points[mini(j + 2, n - 1)][0]
			var steps := clampi(int(p1.distance_to(p2) / 0.035), 2, 8)
			for s in steps:
				var t := float(s) / steps
				samples.append([_catmull(p0, p1, p2, p3, t), _rad(points[j][1]).lerp(_rad(points[j + 1][1]), t),
					points[j][2], (refs[j] as Vector3).lerp(refs[mini(j + 1, refs.size() - 1)], t)])
		samples.append([points[n - 1][0], _rad(points[n - 1][1]), points[n - 2][2], refs[mini(n - 1, refs.size() - 1)]])
		# Frames along the curve.
		var rows: Array = []
		var nrows: Array = []
		var count := samples.size()
		for k in count:
			var at: Vector3 = samples[k][0]
			var tan: Vector3 = (samples[mini(k + 1, count - 1)][0] - samples[maxi(k - 1, 0)][0]).normalized()
			var ref: Vector3 = samples[k][3]
			var nx := (ref - tan * ref.dot(tan))
			if nx.length() < 0.05:
				nx = Vector3.RIGHT - tan * tan.x
			nx = nx.normalized()
			var ny := tan.cross(nx)
			var r: Vector2 = samples[k][1]
			var row := []
			var nrow := []
			for i in sides:
				var a := TAU * float(i) / sides
				var k2 := 1.0 + _wob(float(k) * 13.0 + i + at.x * 40.0) * 0.03
				row.append(at + (nx * cos(a) * r.x + ny * sin(a) * r.y) * k2)
				nrow.append((nx * cos(a) * r.y + ny * sin(a) * r.x).normalized())
			rows.append(row)
			nrows.append(nrow)
		for k in count - 1:
			var m: Material = samples[k][2]
			for i in sides:
				var i2 := (i + 1) % sides
				_quad(m, rows[k][i], rows[k][i2], rows[k + 1][i2], rows[k + 1][i], nrows[k][i], nrows[k][i2], nrows[k + 1][i2], nrows[k + 1][i], 1.8)
		# Round both ends off: two shrinking rings and a tip.
		for e in [[0, -1.0, samples[0][2]], [count - 1, 1.0, samples[count - 2][2]]]:
			var k: int = e[0]
			var dir: float = e[1]
			var at: Vector3 = samples[k][0]
			var tan: Vector3 = (samples[mini(k + 1, count - 1)][0] - samples[maxi(k - 1, 0)][0]).normalized() * dir
			var r: Vector2 = samples[k][1]
			var reach := minf(r.x, r.y) * 0.9
			var prev: Array = rows[k]
			var pn: Array = nrows[k]
			for step in [0.6, 0.92]:
				var shrink := sqrt(1.0 - step * step)
				var row := []
				var nrow := []
				for i in sides:
					row.append(at + (rows[k][i] - at) * shrink + tan * reach * step)
					nrow.append(((nrows[k][i] as Vector3) * shrink + tan * step).normalized())
				for i in sides:
					var i2 := (i + 1) % sides
					_quad(e[2], prev[i], prev[i2], row[i2], row[i], pn[i], pn[i2], nrow[i2], nrow[i], 1.8)
				prev = row
				pn = nrow
			var tip := at + tan * reach
			for i in sides:
				_tri(e[2], tip, prev[i], prev[(i + 1) % sides], tan, pn[i], pn[(i + 1) % sides], 1.8)

	func _rad(r) -> Vector2:
		return r if r is Vector2 else Vector2(r, r)

	func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
		var t2 := t * t
		var t3 := t2 * t
		return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)

	func _wob(x: float) -> float:
		return sin(x * 12.9898 + seed * 0.001) * 0.5 + sin(x * 4.1414 + seed * 0.0007) * 0.5

	func _quad(m: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, top: float) -> void:
		_tri(m, a, b, c, na, nb, nc, top)
		_tri(m, a, c, d, na, nc, nd, top)

	## Wound so the front faces along the normals.
	func _tri(m: Material, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, top: float) -> void:
		if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
			var t := b
			b = c
			c = t
			var tn := nb
			nb = nc
			nc = tn
		var p := _part(m)
		p[0].append_array([a, b, c])
		p[1].append_array([na, nb, nc])
		for v in [a, b, c]:
			p[2].append(Color(1.0, clampf(v.y / top, 0.0, 1.0), 0.94, 1.0))

	## One MeshInstance3D holding every part, on the office's world layer.
	func commit(o: Node, parent: Node3D) -> MeshInstance3D:
		var mesh := ArrayMesh.new()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		for i in _order.size():
			var p: Array = _parts[_order[i]]
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = p[0]
			arr[Mesh.ARRAY_NORMAL] = p[1]
			arr[Mesh.ARRAY_COLOR] = p[2]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mi.set_surface_override_material(i, _order[i])
		mi.layers = o.LAYER_WORLD
		parent.add_child(mi)
		return mi
