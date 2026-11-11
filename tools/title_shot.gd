extends SceneTree
## Screenshots of the title screen (scenes/office/busy_title.gd) to $OUT
## (needs a display): a0 / a1 = the attract loop, shot0..3 = each camera
## shot, shot0_start = the opening close-up on the picture, menu / menu2 =
## the menu (CLOCK IN, then HOW TO PLAY chosen), how = the how-to page,
## after = just after CLOCK IN. Prints CLOSED true PAUSED false when CLOCK IN
## worked. TOUCH=1 for the phone's words.
##   OUT=/some/dir xvfb-run -a -s "-screen 0 720x1280x24" godot \
##     --rendering-driver opengl3 --resolution 720x1280 -s res://tools/title_shot.gd
## Wipes user://look_busy.cfg.
var office
func _init() -> void:
	for f in ["user://look_busy.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	for i in 3: await process_frame
	office = load("res://scenes/office/office.tscn").instantiate()
	root.add_child(office)
	var busy = office._busy
	busy.set_enabled(true)
	office._touch = OS.get_environment("TOUCH") == "1"
	for i in 10: await process_frame
	var t = busy.title_screen
	var out := OS.get_environment("OUT")
	for i in 30: await process_frame
	_shot(out + "/a0.png")
	for i in 90: await process_frame
	_shot(out + "/a1.png")
	for s in [0, 1, 2, 3]:
		t._shot = s
		t._shot_t = 4.0
		for i in 4: await process_frame
		_shot(out + "/shot%d.png" % s)
	t._shot = 0
	t._shot_t = 0.6
	for i in 3: await process_frame
	_shot(out + "/shot0_start.png")
	t._to_menu()
	for i in 60: await process_frame
	_shot(out + "/menu.png")
	t._set_focus(1)
	for i in 20: await process_frame
	_shot(out + "/menu2.png")
	t._open_how()
	for i in 30: await process_frame
	_shot(out + "/how.png")
	t._close_how()
	t._go.pressed.emit()
	for i in 5: await process_frame
	print("CLOSED ", not t.visible, " PAUSED ", paused)
	_shot(out + "/after.png")
	quit()

func _shot(p: String) -> void:
	root.get_texture().get_image().save_png(p)
