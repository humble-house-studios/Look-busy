extends SceneTree
## Plays the glass-cage arcade machines like players of three skill levels
## and prints tickets per token (and Fall Guy scores), for tuning
## engine/arcade_rules.gd. The paycheck is 15+ tokens and the DOOR KEY 300
## tickets: aim for ~10-15 tickets a token for a new player, ~25-40 for a
## good one.
##   godot --headless --fixed-fps 60 -s res://tools/arcade_tune.gd
##   MACHINE=ragdoll ...   one machine only

const SAVE := "user://arcade_tune.cfg"

class FakeHub extends Node:
	var state: LadderState
	var missions := ArcadeMissions.new("user://arcade_tune_missions.cfg")

	func spend_token() -> bool:
		return state.spend_token()

	func win_tickets(n: int, machine: String, beats: bool) -> void:
		state.win_tickets(n, machine)


var hub: FakeHub


func _init() -> void:
	await process_frame
	var only := OS.get_environment("MACHINE")
	for id in ["claw", "pusher", "ragdoll"]:
		if only == "" or only == id:
			for skill in ["new", "okay", "good"]:
				await call("_" + id, skill)
	quit()


func _fresh(id: String) -> Array:
	for f in [SAVE, "user://arcade_tune_missions.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	hub = FakeHub.new()
	hub.state = LadderState.new(SAVE)
	hub.state.tokens = 999
	root.add_child(hub)
	var cage := preload("res://scenes/ladder/cage3d.gd").new()
	root.add_child(cage)
	var m = load("res://scenes/ladder/%s.gd" % id).new()
	m.hub = hub
	m.cage = cage
	root.add_child(m)
	m.set_active(true)
	return [m, cage]


func _report(id: String, skill: String, parts: Array, extra := "") -> void:
	var spent: int = 999 - hub.state.tokens
	print("%-8s %-5s %3d tokens  %4d tickets  %5.1f a token  missions %d%s" % [id, skill, spent, hub.state.tickets,
		hub.state.tickets / maxf(1.0, spent), hub.missions.done.get(id, 0), extra])
	for p in parts:
		p.queue_free()
	hub.queue_free()
	for i in 3:
		await physics_frame


func _claw(skill: String) -> void:
	var parts := _fresh("claw")
	var m = parts[0]
	for i in 240:
		await physics_frame
	var aim: float = {"new": 0.06, "okay": 0.035, "good": 0.015}[skill]
	for play in 16:
		m._on_drop()
		# Go for the bonus prize if there is one, else whatever's handy.
		var target: RigidBody3D = m._bonus
		if target == null or (skill == "new" and randf() < 0.5):
			target = m._prizes[randi() % m._prizes.size()]
		var to := Vector2(target.position.x, target.position.z) + Vector2(randfn(0, aim), randfn(0, aim))
		var t := 0
		while m._at.distance_to(m._clamped(to)) > 0.01 and t < 600:
			m._stick = (m._clamped(to) - m._at).normalized() * clampf(m._at.distance_to(to) * 8.0, 0.2, 1.0)
			await physics_frame
			t += 1
		m._stick = Vector2.ZERO
		for k in 30:
			await physics_frame
		m._on_drop()
		t = 0
		while (m._state != m.S.IDLE or m._settle > 0.0) and t < 1500:
			await physics_frame
			t += 1
	await _report("claw", skill, parts)


func _pusher(skill: String) -> void:
	var parts := _fresh("pusher")
	var m = parts[0]
	for i in 120:
		await physics_frame
	for drop in 50:
		# Better players wait for the chute to pass through the lit zone.
		var wait := 0
		var patience: int = {"new": 0, "okay": 40, "good": 160}[skill]
		while wait < patience and absf(m._chute_x - m._zone_x) >= m.ZONE_HALF:
			await physics_frame
			wait += 1
		m._on_drop()
		for k in 50:
			await physics_frame
	for i in 300:
		await physics_frame
	await _report("pusher", skill, parts)


func _ragdoll(skill: String) -> void:
	var parts := _fresh("ragdoll")
	var m = parts[0]
	var err: float = {"new": 0.16, "okay": 0.09, "good": 0.04}[skill]
	var scores := []
	for round in 6:
		for i in 40:
			await physics_frame
		m._on_launch()
		var wait := randf() * err * 2.0
		var lean := 0.0
		var t := 0
		while m._playing and t < 2400:
			await physics_frame
			t += 1
			# A good player leans toward the lit bumper.
			if skill != "new" and m._low() > 0.3:
				var b: Array = m.BUMPERS[m._target]
				lean = signf(sin(b[1])) if randf() < 0.9 else 0.0
				m._stick = lean
			else:
				m._stick = 0.0
			if m._touching and m._round_t - m._land_t >= wait and m._round_t - m._land_t < wait + 0.02:
				if m._on_bounce():
					wait = randf() * err * 2.0
			elif m._still > 0.5 and m._kicks > 0 and randf() < 0.05:
				m._on_bounce()
		scores.append(m._last_score)
		for i in 150:
			await physics_frame
	await _report("ragdoll", skill, parts, "  scores %s" % str(scores))
