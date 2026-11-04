extends SceneTree
## Screenshots of Look Busy's floppy disks (scenes/office/disk_popup.gd,
## floppy.gd, the Dev Kit's drives and binder), saved as PNGs to $OUT
## (needs a display):
##   OUT=/some/dir LAYOUT=portrait xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 --resolution 720x1280 -s res://tools/disk_shot.gd
## Shots: new_disk (COMEDY, a first find), slot_reels, combo (LAUGH SLOTS),
## kit (seated at the Dev Kit), binder (disks tab), stars (star cards tab).
## Prints PASS/FAIL. Wipes user://look_busy.cfg and user://disk_binder.cfg.

var office
var busy
var ok := true


func _init() -> void:
	for f in ["user://look_busy.cfg", "user://disk_binder.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Engine.max_fps = 60
	for i in 3: await process_frame
	office = load("res://scenes/office/office.tscn").instantiate()
	root.add_child(office)
	busy = office._busy
	busy.set_enabled(true)
	office._touch = true
	await _frames(30)
	busy.title_screen._go.pressed.emit()
	await _frames(20)
	busy._morning()
	await _frames(5)
	_press_notice()
	await _frames(10)
	busy.dev_piece("comedy")
	await _frames(40)
	_check(busy.disks.visible, "the new-disk pop-up opens")
	_check(paused, "it pauses the office")
	_check(busy.binder.has("COMEDY"), "COMEDY is in the binder")
	_shot("new_disk")
	busy.disks._ok.pressed.emit()
	await _frames(5)
	_check(not busy.disks.visible and not paused, "NICE! closes it")
	busy.dev_piece("loot")
	await _frames(40)
	_shot("slot_reels")
	busy.disks._ok.pressed.emit()
	await _frames(30)
	_check(busy.disks.visible and busy.disks._entry.get("type") == "combo", "the combo pops up next")
	_check(busy.disks._entry.get("name") == "LAUGH SLOTS", "it's LAUGH SLOTS")
	_shot("combo")
	busy.disks._ok.pressed.emit()
	await _frames(5)
	_check(not busy.disks.pending(), "queue empty")
	for src in ["pong", "comedy", "cube"]:
		busy.gm.earn(src)
	busy.disks.clear()
	busy.gm.collaborate(["gloria"])
	for p in busy.gm.pieces:
		busy.binder.record(p.name)
	office._set_seat(busy._kit_pc)
	await _frames(90)
	busy._kit.refresh()
	await _frames(5)
	busy.disks.clear()
	await _frames(2)
	_shot("kit")
	busy._kit.open_binder()
	await _frames(10)
	_check(busy._kit._binder.visible, "the binder opens")
	_shot("binder")
	busy._kit._set_tab("stars")
	await _frames(10)
	_shot("stars")
	print("PASS" if ok else "FAIL")
	quit()


func _check(cond: bool, what: String) -> void:
	if not cond:
		ok = false
		print("FAIL: " + what)


func _press_notice() -> void:
	for b in busy.notice._buttons.get_children():
		b.pressed.emit()
		return


func _frames(n: int) -> void:
	for i in n: await process_frame


func _shot(name: String) -> void:
	var out := OS.get_environment("OUT")
	if out == "":
		return
	root.get_texture().get_image().save_png(out + "/disk_%s_%s.png" % [OS.get_environment("LAYOUT"), name])
