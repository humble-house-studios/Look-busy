extends SceneTree
## Stand anywhere and take a picture: for checking how the models look
## (needs a display). The HUD is hidden, Look Busy is off, every door is open.
##   OUT=/some/dir VIEWS="dale:office:-1.2,-0.6:1.5708:-0.05;arcade:arcade:1.8,5.4:3.14:-0.08" \
##     xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     --resolution 1280x720 -s res://tools/look_shot.gd
## VIEWS: name:room:x,z:yaw:pitch[:fov], separated by ";" (room = a ladder.gd
## SPOTS key; yaw 0 faces -z, PI/2 faces -x). BOSS=marge (or ceo) stands that
## boss in the middle of the office. Prints each view's triangle and draw
## counts and the office's build time. Wipes user://dale.cfg, ladder.cfg,
## coworkers.cfg and look_busy.cfg.
var office

func _init() -> void:
	for f in ["user://dale.cfg", "user://ladder.cfg", "user://coworkers.cfg", "user://look_busy.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var d := DaleStory.new()
	for ch in DaleLines.CHAPTERS:
		d.finish(ch.id, {})
	var l := LadderState.new()
	for m in ["market", "pitch", "memo"]:
		l.mark(m)
	l.items.append("door_key")
	l.items.append("archive_key")
	l.save()
	for i in 3: await process_frame
	var t0 := Time.get_ticks_msec()
	office = load("res://scenes/office/office.tscn").instantiate()
	root.add_child(office)
	print("BUILD_MS ", Time.get_ticks_msec() - t0)
	office._busy.set_enabled(false)
	for i in 20: await process_frame
	office._hud.visible = false
	var show_boss := OS.get_environment("BOSS")
	if show_boss != "":
		var b: Node3D = office._busy._bosses[show_boss]
		b.visible = true
		b.position = Vector3(0.6, 0, 1.2)
		b.rotation.y = 0.0
	for v in OS.get_environment("VIEWS").split(";", false):
		var p := v.split(":")
		office._ladder.dev_teleport(p[1])
		var xz := p[2].split(",")
		office._player.global_position = Vector3(float(xz[0]), 0, float(xz[1]))
		office._yaw = float(p[3])
		office._pitch = float(p[4])
		if p.size() > 5:
			office._camera.fov = float(p[5])
		for i in 40: await process_frame
		print("PRIMS ", p[0], " ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), " draws ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/" + p[0] + ".png")
	quit()
