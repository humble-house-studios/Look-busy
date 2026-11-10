extends RefCounted
## The people of Humble House: Dale, the coworkers, the bosses, the board and
## the stand-in you. Hand-made puppets, modelled from lumps of clay
## (Handmade.blob) and turned sticks (Handmade.tube) instead of boxes: a soft
## rounded head with ears, a nose, cheeks, brows and eyes with whites; a
## collar, hands with thumbs, shoes; hair built up in pieces.
##
## build() fills `body` and returns the bits the office animates:
##   {head, mouth, eyes}  (head turns, mouth.scale.y opens, eyes blink by scale.y)
## look (all optional): skin, shirt, pants, hair, hair_style (short, bob,
##   curls, slick, cap_back, flat_cap, horseshoe), cap, glasses, moustache,
##   beard, tie, strap, lanyard, wide (1 = average), belly (true = a big
##   round one), brows (tilt, + = stern), sleeves ("short" = bare forearms).
## pose: "stand", "sit" (hands in the lap) or "desk" (seated, forearms on a
##   desk in front). drop = how far a seated body sinks.

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
	var shade: Material = _m(mat, skin_c.darkened(0.12))
	var shirt: Material = _m(mat, shirt_c, 6, Color.BLACK, 40.0)
	var trim: Material = _m(mat, shirt_c.lightened(0.25))
	var pants: Material = _m(mat, look.get("pants", Color(0.2, 0.2, 0.25)), 6, Color.BLACK, 40.0)
	var hair: Material = _m(mat, hair_c, 6, Color.BLACK, 50.0)
	var dark: Material = _m(mat, Color(0.08, 0.08, 0.1))
	var shoe: Material = _m(mat, Color(0.16, 0.11, 0.09))
	var white: Material = _m(mat, Color(0.96, 0.95, 0.9))
	var wide: float = look.get("wide", 1.0)
	var seated := pose != "stand"
	body.position.y = -drop if seated else 0.0

	# ---- legs and shoes
	for side in [-1.0, 1.0]:
		var x: float = side * 0.1 * wide
		if seated:
			# Thighs forward along the seat, shins down to the floor.
			o._cyl(0.085, 0.42, Vector3(x, 0.84, 0.2), pants, Vector3(PI / 2, 0, 0), 7, 0.075, body)
			var shin := 0.84 - drop - 0.05
			o._cyl(0.062, shin, Vector3(x, 0.84 - shin * 0.5, 0.4), pants, Vector3.ZERO, 7, 0.072, body)
			o._lump(Vector3(0.12, 0.09, 0.25), Vector3(x, drop + 0.045, 0.45), shoe, body, 0.65)
		else:
			o._cyl(0.066, 0.8, Vector3(x, 0.44, 0), pants, Vector3(0, 0, -side * 0.03), 7, 0.088, body)
			o._lump(Vector3(0.13, 0.09, 0.27), Vector3(x * 1.08, 0.045, 0.045), shoe, body, 0.65)

	# ---- hips, torso, belly
	o._lump(Vector3(0.4 * wide, 0.24, 0.27 * wide), Vector3(0, 0.88, 0), pants, body, 0.7)
	o._lump(Vector3(0.47 * wide, 0.6, 0.3 * wide), Vector3(0, 1.14, 0), shirt, body, 0.72)
	var front: float = 0.15 * wide
	if look.get("belly", false):
		o._lump(Vector3(0.5 * wide, 0.44, 0.44 * wide), Vector3(0, 1.02, 0.07), shirt, body, 0.9)
		front = 0.07 + 0.22 * wide
	# A belt where the shirt tucks in.
	if look.has("tie") and not look.get("belly", false):
		o._box(Vector3(0.38 * wide, 0.035, 0.26 * wide), Vector3(0, 0.9, 0.005), dark, false, Vector3.ZERO, body)

	# ---- arms and hands
	var bare: bool = look.get("sleeves", "") == "short"
	var sleeve: Material = skin if bare else shirt
	for side in [-1.0, 1.0]:
		var sx: float = side * 0.265 * wide
		o._lump(Vector3(0.14, 0.14, 0.16), Vector3(sx * 0.94, 1.365, 0), shirt, body)
		var hand := Vector3.ZERO
		if pose == "desk":
			# Upper arm forward and down, forearm flat on the desk.
			o._cyl(0.058, 0.3, Vector3(sx + side * 0.02, 1.24, 0.09), shirt, Vector3(0.7, 0, side * 0.1), 7, 0.07, body)
			o._cyl(0.05, 0.3, Vector3(sx - side * 0.02, 1.115, 0.33), sleeve, Vector3(PI / 2, -side * 0.35, 0), 7, 0.058, body)
			hand = Vector3(sx - side * 0.08, 1.11, 0.5)
		elif pose == "sit":
			o._cyl(0.058, 0.3, Vector3(sx + side * 0.02, 1.22, 0.03), shirt, Vector3(0.25, 0, side * 0.1), 7, 0.07, body)
			o._cyl(0.05, 0.28, Vector3(sx, 1.0, 0.16), sleeve, Vector3(1.05, -side * 0.3, 0), 7, 0.058, body)
			hand = Vector3(sx - side * 0.045, 0.94, 0.3)
		else:
			o._cyl(0.058, 0.3, Vector3(sx + side * 0.025, 1.22, 0), shirt, Vector3(0, 0, side * 0.12), 7, 0.07, body)
			o._cyl(0.05, 0.28, Vector3(sx + side * 0.05, 0.96, 0.03), sleeve, Vector3(0.2, 0, side * 0.06), 7, 0.058, body)
			hand = Vector3(sx + side * 0.06, 0.79, 0.06)
		if not bare:
			o._cyl(0.06, 0.035, hand + Vector3(0, 0.06, -0.012) if pose == "stand" else hand + Vector3(0, 0.0, -0.06), trim,
				Vector3.ZERO if pose == "stand" else Vector3(PI / 2, 0, 0), 7, -1.0, body)
		o._lump(Vector3(0.085, 0.1, 0.075) if pose == "stand" else Vector3(0.09, 0.06, 0.11), hand, skin, body, 0.8)
		# Thumb.
		o._lump(Vector3(0.035, 0.05, 0.035), hand + Vector3(-side * 0.04, 0.01, 0.025), skin, body)

	# ---- what they wear over the shirt
	var chest_z := front + 0.006
	if look.has("tie"):
		var tie: Material = _m(mat, look.tie, 4, (look.tie as Color).darkened(0.2), 40.0)
		o._lump(Vector3(0.07, 0.06, 0.04), Vector3(0, 1.385, 0.13 * wide + 0.012), tie, body, 0.8)
		if look.get("belly", false):
			o._box(Vector3(0.065, 0.2, 0.018), Vector3(0, 1.26, front - 0.065), tie, false, Vector3(-0.42, 0, 0), body)
			o._box(Vector3(0.075, 0.2, 0.018), Vector3(0, 1.09, chest_z + 0.005), tie, false, Vector3(0.1, 0, 0), body)
		else:
			o._box(Vector3(0.065, 0.3, 0.018), Vector3(0, 1.22, chest_z), tie, false, Vector3.ZERO, body)
			o._box(Vector3(0.05, 0.05, 0.018), Vector3(0, 1.055, chest_z), tie, false, Vector3(0, 0, PI / 4), body)
	if look.has("tie") or look.get("collar", false):
		# Collar points, either side of the knot.
		for side in [-1.0, 1.0]:
			o._box(Vector3(0.09, 0.05, 0.02), Vector3(side * 0.06, 1.4, 0.125 * wide), trim, false, Vector3(-0.2, 0, side * 0.5), body)
	if look.has("strap"):
		var strap: Material = _m(mat, look.strap)
		for side in [-1.0, 1.0]:
			o._box(Vector3(0.06, 0.5, 0.02), Vector3(side * 0.12, 1.17, chest_z), strap, false, Vector3.ZERO, body)
			o._lump(Vector3(0.04, 0.04, 0.02), Vector3(side * 0.12, 0.98, chest_z + 0.012), _m(mat, Color(0.78, 0.66, 0.3)), body)
		o._box(Vector3(0.34 * wide, 0.16, 0.02), Vector3(0, 0.93, chest_z), strap, false, Vector3.ZERO, body)
	if look.get("lanyard", false):
		var cord: Material = _m(mat, Color(0.85, 0.25, 0.3))
		for side in [-1.0, 1.0]:
			o._box(Vector3(0.016, 0.26, 0.012), Vector3(side * 0.05, 1.27, chest_z), cord, false, Vector3(0, 0, side * 0.36), body)
		o._box(Vector3(0.1, 0.13, 0.014), Vector3(0, 1.09, chest_z + 0.004), white, false, Vector3(0, 0, 0.06), body)
		o._box(Vector3(0.1, 0.03, 0.014), Vector3(0.002, 1.135, chest_z + 0.006), cord, false, Vector3(0, 0, 0.06), body)

	# ---- neck and head
	o._cyl(0.055, 0.12, Vector3(0, 1.45, 0), shade, Vector3.ZERO, 7, 0.05, body)
	var head := Node3D.new()
	head.position = Vector3(0, 1.48, 0)
	body.add_child(head)
	# A soft block of a head, a little narrower at the jaw.
	o._lump(Vector3(0.26, 0.27, 0.25), Vector3(0, 0.16, 0), skin, head, 0.62)
	o._lump(Vector3(0.21, 0.14, 0.21), Vector3(0, 0.07, 0.012), skin, head, 0.75)
	for side in [-1.0, 1.0]:
		o._lump(Vector3(0.04, 0.075, 0.05), Vector3(side * 0.13, 0.145, -0.005), shade, head)
		# Cheeks: a dab of blush.
		o._lump(Vector3(0.058, 0.042, 0.014), Vector3(side * 0.076, 0.095, 0.11), blush, head, 1.0, Vector3(0, side * 0.35, 0))
	o._lump(Vector3(0.044, 0.06, 0.055), Vector3(0, 0.122, 0.124), blush, head)

	var eyes: Array = []
	var tilt: float = look.get("brows", 0.0)
	for side in [-1.0, 1.0]:
		var e := Node3D.new()
		e.position = Vector3(side * 0.056, 0.175, 0.117)
		head.add_child(e)
		o._lump(Vector3(0.056, 0.05, 0.026), Vector3.ZERO, white, e)
		o._lump(Vector3(0.026, 0.032, 0.02), Vector3(-side * 0.004, -0.003, 0.009), dark, e)
		eyes.append(e)
		o._box(Vector3(0.07, 0.016, 0.014), Vector3(side * 0.058, 0.222 - tilt * 0.01, 0.126), hair, false, Vector3(0, 0, side * (-0.14 - tilt)), head)
		if look.get("glasses", false):
			# Wire frames: four thin rails round each lens, an arm back to the ear.
			var gz := 0.139
			var lens: Material = _m(mat, Color(0.75, 0.85, 0.9), 0, Color.BLACK, 24.0, Color(0.1, 0.12, 0.15))
			o._box(Vector3(0.068, 0.05, 0.004), Vector3(side * 0.058, 0.172, gz - 0.003), lens, false, Vector3.ZERO, head)
			for bar in [[Vector3(0.082, 0.012, 0.012), Vector3(0, 0.03, 0)], [Vector3(0.082, 0.012, 0.012), Vector3(0, -0.03, 0)],
					[Vector3(0.012, 0.062, 0.012), Vector3(0.038, 0, 0)], [Vector3(0.012, 0.062, 0.012), Vector3(-0.038, 0, 0)]]:
				o._box(bar[0], Vector3(side * 0.058, 0.172, gz) + bar[1], dark, false, Vector3.ZERO, head)
			o._box(Vector3(0.012, 0.012, 0.13), Vector3(side * 0.128, 0.18, 0.07), dark, false, Vector3.ZERO, head)
	if look.get("glasses", false):
		o._box(Vector3(0.036, 0.012, 0.012), Vector3(0, 0.178, 0.139), dark, false, Vector3.ZERO, head)

	var mouth := Node3D.new()
	mouth.position = Vector3(0, 0.058, 0.118)
	head.add_child(mouth)
	o._box(Vector3(0.075, 0.032, 0.012), Vector3.ZERO, _m(mat, Color(0.35, 0.1, 0.1)), false, Vector3.ZERO, mouth)
	mouth.scale.y = 0.25
	# The corners of the mouth, turned up a touch (down if they're stern).
	for side in [-1.0, 1.0]:
		o._box(Vector3(0.022, 0.012, 0.012), Vector3(side * 0.045, 0.062 - tilt * 0.02, 0.117), shade, false, Vector3(0, 0, side * (0.5 - tilt * 3.0)), head)

	_hair(o, head, look, hair, mat)
	if look.get("beard", false):
		var grey: Material = _m(mat, Color(0.72, 0.72, 0.7), 6, Color.BLACK, 50.0)
		o._lump(Vector3(0.24, 0.13, 0.12), Vector3(0, 0.03, 0.07), grey, head, 0.75)
		for side in [-1.0, 1.0]:
			o._lump(Vector3(0.05, 0.14, 0.1), Vector3(side * 0.115, 0.08, 0.03), grey, head, 0.8)
	if look.get("moustache", false):
		for side in [-1.0, 1.0]:
			o._lump(Vector3(0.075, 0.035, 0.03), Vector3(side * 0.032, 0.086, 0.13), hair, head, 0.9, Vector3(0, 0, -side * 0.25))
	return {"head": head, "mouth": mouth, "eyes": eyes}


static func _hair(o: Node, head: Node3D, look: Dictionary, hair: Material, mat: Callable) -> void:
	match look.get("hair_style", "short"):
		"short":
			o._lump(Vector3(0.275, 0.14, 0.27), Vector3(0, 0.265, -0.012), hair, head, 0.7)
			o._lump(Vector3(0.26, 0.16, 0.1), Vector3(0, 0.19, -0.095), hair, head, 0.75)
			# A fringe, combed to one side.
			o._lump(Vector3(0.2, 0.05, 0.06), Vector3(0.02, 0.268, 0.105), hair, head, 0.8, Vector3(0, 0, -0.12))
			for side in [-1.0, 1.0]:
				o._lump(Vector3(0.03, 0.09, 0.1), Vector3(side * 0.13, 0.22, -0.02), hair, head)
		"bob":
			o._lump(Vector3(0.3, 0.16, 0.29), Vector3(0, 0.265, -0.012), hair, head, 0.72)
			for side in [-1.0, 1.0]:
				o._lump(Vector3(0.07, 0.26, 0.24), Vector3(side * 0.135, 0.14, -0.02), hair, head, 0.75)
			o._lump(Vector3(0.28, 0.27, 0.09), Vector3(0, 0.145, -0.115), hair, head, 0.75)
			o._lump(Vector3(0.22, 0.055, 0.06), Vector3(0, 0.262, 0.105), hair, head, 0.8)
		"curls":
			for i in 9:
				var a := -PI * 0.15 + i * PI * 1.3 / 8.0
				o._ball(0.075, Vector3(cos(a) * 0.14, 0.24 + sin(a) * 0.09, -0.015 - absf(cos(a)) * 0.02), hair, head)
			for i in 5:
				var a := -PI * 0.1 + i * PI * 1.2 / 4.0
				o._ball(0.07, Vector3(cos(a) * 0.1, 0.2 + sin(a) * 0.07, -0.1), hair, head)
			o._ball(0.12, Vector3(0, 0.3, -0.04), hair, head, Vector3(1.3, 0.8, 1.2))
		"slick":
			o._lump(Vector3(0.275, 0.11, 0.28), Vector3(0, 0.28, -0.02), hair, head, 0.75, Vector3(-0.15, 0, 0))
			o._lump(Vector3(0.26, 0.15, 0.09), Vector3(0, 0.2, -0.1), hair, head, 0.75)
			# The quiff he spends ten minutes on.
			o._lump(Vector3(0.16, 0.07, 0.08), Vector3(0.01, 0.305, 0.085), hair, head, 0.85, Vector3(-0.3, 0, 0))
		"cap_back":
			var cap: Material = _m(mat, look.get("cap", Color(0.8, 0.15, 0.15)), 6, Color.BLACK, 40.0)
			o._lump(Vector3(0.29, 0.15, 0.28), Vector3(0, 0.27, -0.005), cap, head, 0.8)
			o._lump(Vector3(0.21, 0.03, 0.15), Vector3(0, 0.245, -0.18), cap, head, 0.6, Vector3(0.2, 0, 0))
			o._lump(Vector3(0.14, 0.05, 0.04), Vector3(0, 0.235, 0.115), hair, head)
			o._lump(Vector3(0.04, 0.04, 0.03), Vector3(0, 0.345, 0), _m(mat, (look.get("cap", Color(0.8, 0.15, 0.15)) as Color).darkened(0.3)), head)
		"flat_cap":
			var cap: Material = _m(mat, look.get("cap", Color(0.3, 0.3, 0.32)), 3, (look.get("cap", Color(0.3, 0.3, 0.32)) as Color).darkened(0.18), 60.0)
			o._lump(Vector3(0.31, 0.1, 0.32), Vector3(0, 0.3, 0.015), cap, head, 0.7, Vector3(0.12, 0, 0))
			o._lump(Vector3(0.24, 0.03, 0.12), Vector3(0, 0.262, 0.165), cap, head, 0.6, Vector3(0.25, 0, 0))
			o._lump(Vector3(0.27, 0.1, 0.1), Vector3(0, 0.2, -0.09), hair, head, 0.75)
		"horseshoe":
			# Bald and shiny on top, a horseshoe of hair round the sides and back.
			o._lump(Vector3(0.275, 0.12, 0.11), Vector3(0, 0.2, -0.085), hair, head, 0.75)
			for side in [-1.0, 1.0]:
				o._lump(Vector3(0.05, 0.11, 0.17), Vector3(side * 0.123, 0.2, -0.01), hair, head, 0.8)
			o._lump(Vector3(0.09, 0.02, 0.07), Vector3(-0.03, 0.296, 0.03), _m(mat, (look.get("skin", Color(0.9, 0.7, 0.55)) as Color).lightened(0.3)), head)
