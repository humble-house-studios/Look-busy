extends SceneTree
## Plays the glass-cage arcade machines (claw, coin pusher, Fall Guy) on
## their own, no office, and prints PASS/FAIL: does the physics actually
## work? Real claw grabs (strong ones should land prizes, weak ones mostly
## slip), coins pushed off the edge pay out, the ragdoll bounces, stays in
## its column and in one piece.
##   godot --headless --fixed-fps 60 -s res://tools/cage_check.gd
##   MACHINE=claw ...       one machine only
## With a display and OUT=/some/dir it also saves screenshots from the seat
## (the controls laid over the 3D cage, like the office shows them):
##   OUT=/tmp/shots xvfb-run -a -s "-screen 0 720x1280x24" godot \
##     --rendering-driver opengl3 --resolution 720x1280 --fixed-fps 60 -s res://tools/cage_check.gd

const SAVE := "user://cage_check.cfg"

class FakeHub extends Node:
	var state: LadderState
	var wins: Array = []

	func spend_token() -> bool:
		return state.spend_token()

	func win_tickets(n: int, machine: String, beats: bool) -> void:
		wins.append([n, machine, beats])
		state.win_tickets(n, machine)


var fails := 0
var out := ""
var shot_n := 0
var hub: FakeHub
var cam: Camera3D


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	# Let the window come up first (its size, and nodes really in the tree).
	await process_frame
	await process_frame
	out = OS.get_environment("OUT")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	hub = FakeHub.new()
	hub.state = LadderState.new(SAVE)
	hub.state.tokens = 999
	root.add_child(hub)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.06, 0.16)
	root.add_child(env)
	cam = Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.current = true
	var only := OS.get_environment("MACHINE")
	for id in ["claw", "pusher", "ragdoll"]:
		if only == "" or only == id:
			await call("_" + id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("%s: %d failed" % ["FAIL" if fails else "PASS", fails])
	quit(1 if fails else 0)


## A machine in a 2D overlay over its cage, the camera where the office's
## seat would put it.
func _machine(id: String) -> Array:
	var rig := Node3D.new()
	root.add_child(rig)
	var cage := preload("res://scenes/ladder/cage3d.gd").new()
	rig.add_child(cage)
	var scr = load("res://scenes/ladder/%s.gd" % id)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1280)
	vp.disable_3d = true
	vp.transparent_bg = true
	layer.add_child(vp)
	var show := TextureRect.new()
	show.texture = vp.get_texture()
	layer.add_child(show)
	var m: Control = scr.new()
	m.hub = hub
	m.cage = cage
	vp.add_child(m)
	m.set_active(true)
	var seat: Dictionary = scr.SEAT
	var screen := Node3D.new()
	screen.position = seat.at
	screen.rotation.x = seat.tilt
	rig.add_child(screen)
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	var d: float = seat.size.y * 0.5 / 0.94 / half
	var size := Vector2(root.size)
	# Fit the 9:16 rect in the window, like the seated camera does.
	if size.x / maxf(size.y, 1.0) < 9.0 / 16.0:
		d *= (9.0 / 16.0) / (size.x / size.y)
	var xf := screen.global_transform
	cam.global_transform = Transform3D(xf.basis, xf.origin + xf.basis.z * d)
	print("      seat camera at %s, window %s" % [cam.global_position, size])
	# How many window pixels the rect's height covers.
	var px: float = size.y / (2.0 * d * half) * float(seat.size.y)
	show.size = Vector2(720, 1280)
	show.scale = Vector2.ONE * (px / 1280.0)
	show.position = (size - Vector2(720, 1280) * show.scale) * 0.5
	return [m, rig, layer]


func _done(parts: Array) -> void:
	for p in parts:
		p.queue_free()
	await frames(2)


func _shot(name: String) -> void:
	if out == "":
		return
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out, shot_n, name])
	shot_n += 1


# ---------------------------------------------------------------- claw

func _claw() -> void:
	var parts := await _machine("claw")
	var m = parts[0]
	await frames(240)
	await _shot("claw_idle")
	var bounds_ok := true
	var results := {"strong": 0, "weak": 0}
	var tries := 8
	for kind in ["strong", "weak"]:
		for i in tries:
			# Aim straight over a prize resting on the pile.
			var target: RigidBody3D
			for p in m._prizes:
				if p.position.y < m.FLOOR + 0.2 and (p.position.x > m.CHUTE.end.x + 0.08 or p.position.z < m.CHUTE.position.y - 0.08) \
						and absf(p.position.x) < 0.33 and p.position.z > m.Z0 + 0.1 and p.position.z < m.Z1 - 0.1:
					target = p
					if randf() < 0.3:
						break
			if target == null:
				continue
			m._at = Vector2(target.position.x, target.position.z)
			m._swing = Vector2.ZERO
			m._swing_v = Vector2.ZERO
			m._vel = Vector2.ZERO
			m._grabs = 3 if kind == "strong" else 0
			var before: int = hub.wins.size()
			m._on_drop()
			var t := 0
			while m._state != m.S.IDLE and t < 1500:
				await physics_frame
				t += 1
				if i == 0 and kind == "strong" and t == 150:
					await _shot("claw_drop")
				if i == 0 and kind == "strong" and t == 330:
					await _shot("claw_lift")
			await frames(60)
			if hub.wins.size() > before:
				results[kind] += 1
			for p in m._prizes:
				if p.position.y < m.FLOOR - 0.3 or absf(p.position.x) > 0.5:
					bounds_ok = false
	print("      claw: strong %d/%d, weak %d/%d" % [results.strong, tries, results.weak, tries])
	check(results.strong >= tries / 3, "strong grabs land prizes (%d/%d)" % [results.strong, tries])
	check(results.weak < results.strong or results.strong == 0, "weak grabs slip more than strong ones (%d vs %d)" % [results.weak, results.strong])
	check(bounds_ok, "prizes stay in the cage")
	check(m._prizes.size() == m.KEEP, "the cage refills (%d prizes)" % m._prizes.size())
	await _shot("claw_end")
	await _done(parts)


# ---------------------------------------------------------------- pusher

func _pusher() -> void:
	var parts := await _machine("pusher")
	var m = parts[0]
	await frames(180)
	await _shot("pusher_idle")
	var before: int = hub.wins.size()
	for i in 40:
		m._on_drop()
		await frames(45)
		if i == 6:
			await _shot("pusher_drops")
	await frames(240)
	var won: int = hub.wins.size() - before
	print("      pusher: %d payouts from 40 coins" % won)
	check(won >= 5, "coins pushed off the edge pay out (%d)" % won)
	var stray := 0
	for b in m._bodies:
		if b.position.y > 1.6 or absf(b.position.x) > 0.5:
			stray += 1
	check(stray == 0, "coins stay on the table (%d stray)" % stray)
	await _shot("pusher_end")
	await _done(parts)


# ---------------------------------------------------------------- ragdoll

func _ragdoll() -> void:
	var parts := await _machine("ragdoll")
	var m = parts[0]
	await frames(120)
	await _shot("ragdoll_idle")
	var before: int = hub.wins.size()
	m._on_launch()
	var top := 0.0
	var apart := 0.0
	var outside := 0
	var t := 0
	var kicks := 0
	while m._playing and t < 60 * 30:
		await physics_frame
		t += 1
		# Press BOUNCE the moment he touches down on the trampoline.
		if m._touching and m._round_t - m._land_t < 0.03 and m._kick_window():
			if m._on_bounce():
				kicks += 1
		# What you see: joints pulled shut before every draw.
		m._hold_together()
		var p: Vector3 = m._torso.position
		top = maxf(top, p.y)
		if Vector2(p.x, p.z).length() > m.R_IN + 0.02 or p.y < m.MAT_Y - 0.1 or p.y > m.ROOF:
			outside += 1
		for l in m._links:
			var gap: float = (l.a.global_transform * l.la).distance_to(l.b.global_transform * l.lb)
			apart = maxf(apart, gap)
		if t == 90:
			await _shot("ragdoll_up")
		if t == 400:
			await _shot("ragdoll_mid")
	print("      ragdoll: %d kicks, top %.2f m, score %d (height %.2f, knocks %d, flips %d, bumps %d, bells %d), worst joint gap %.3f" % [kicks, top, m._last_score, m._best_h, m._impacts, m._spins(), m._bumps, m._bells, apart])
	check(not m._playing, "the round ends")
	check(hub.wins.size() > before, "the round pays out")
	check(top > m.MAT_Y + 0.9, "timed bounces send him up the column (%.2f m)" % top)
	check(outside == 0, "he stays inside the glass (%d frames out)" % outside)
	check(apart < 0.03, "he stays in one piece (gap %.3f)" % apart)
	check(m._last_score >= ArcadeRules.RAGDOLL_BEAT, "perfect timing beats the machine (%d)" % m._last_score)
	await _shot("ragdoll_end")
	await _done(parts)
