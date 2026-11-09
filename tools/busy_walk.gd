extends SceneTree
## Debug walkthrough of Look Busy (docs/look-busy.md), headless or under xvfb.
## Fresh saves, Look Busy on, then:
##  - the title screen and CLOCK IN, the slack meter, the boss countdown,
##    a close call and the all-clear;
##  - the morning card, the clock running, the boss coming in through the
##    door, walking the route and leaving;
##  - sitting at your desk while the boss watches: suspicion climbs to a
##    warning; alt-tab covers the screen with the spreadsheet and cools it;
##  - an empty desk while you're out; strikes up to fired and starting over;
##  - 5 PM, after hours (5 PM mid-game: lights out, x2 slack, tired
##    tomorrow) and the end of the week.
## Prints PASS / FAIL lines and a summary. Wipes the office saves.
##   godot --headless -s res://tools/busy_walk.gd

var office
var busy
var fails := 0


func _init() -> void:
	for f in ["user://dale.cfg", "user://ladder.cfg", "user://coworkers.cfg", "user://look_busy.cfg", "user://office_relics.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	# Real-time pace, so the clock and the boss move like they do in the game.
	Engine.max_fps = 60
	for i in 3: await process_frame
	office = load("res://scenes/office/office.tscn").instantiate()
	root.add_child(office)
	busy = office._busy
	busy.set_enabled(true)
	office._touch = true
	await frames(10)
	var title = busy.title_screen
	check(title.visible and paused and not busy.notice.visible, "the title screen shows first and pauses")
	check(title._go.text == "CLOCK IN", "a fresh start says CLOCK IN")
	title._options.pressed.emit()
	await frames(3)
	check(office._menu.visible and not title.visible, "OPTIONS opens the pause menu")
	office.close_menu(false)
	await frames(3)
	check(title.visible and paused, "closing it comes back to the title")
	title._go.pressed.emit()
	await frames(5)
	check(not title.visible and not paused, "CLOCK IN starts the day")
	check(not busy.notice.visible and office._toast.text.begins_with("MONDAY"), "the morning card shrinks to news (%s)" % office._toast.text.replace("\n", " / "))
	var m0: float = busy.wd.minutes
	await frames(60)
	check(busy.wd.minutes > m0, "the clock runs (%s)" % busy.wd.clock_text())
	check(is_equal_approx(busy.wd.slacked, Workday.MORNING_COFFEE), "walking around isn't slacking (%.1f)" % busy.wd.slacked)
	check(busy.wd.next_visit_in() > 0.0, "the boss countdown runs (%.1f s)" % busy.wd.next_visit_in())
	office._set_seat(office._computers[0])
	await frames(60)
	check(busy.wd.slacked > Workday.MORNING_COFFEE + 1.0, "playing fills the slack meter (%s)" % Workday.hours_text(busy.wd.slacked))
	var stand: Button = office._stand_button
	var hud_top: float = busy._hud.position.y
	check(office._hud.size.x > office._hud.size.y or hud_top >= stand.position.y + stand.size.y, "seated upright, the HUD sits under the buttons (%.0f)" % hud_top)
	office._set_seat(null)
	await frames(5)

	# The boss comes by: through the door, along the route.
	busy.dev_boss_now()
	await frames(5)
	check(busy._boss_node != null and busy._boss_node.visible, "the boss walks in")
	await frames(240)
	var bz: float = busy._boss_node.position.z
	check(bz < 3.5, "the boss is inside the office (z %.1f)" % bz)
	# Sit at your desk, facing the screen, with the boss behind: suspicion climbs.
	var main_pc = office._computers[0]
	office._set_seat(main_pc)
	busy.wd.suspicion = 0.0
	var watched := false
	for i in 400:
		await process_frame
		if busy._seen:
			watched = true
		if busy.notice.visible:
			break
	check(watched, "the boss sees you playing at your desk")
	check(busy.notice.visible and busy.wd.strikes == 1, "caught: a verbal warning (strikes %d)" % busy.wd.strikes)
	press_first()
	await frames(5)
	# Alt-tab: the spreadsheet covers the game and takes the taps.
	busy.alt_tab()
	await frames(5)
	check(busy.is_covered() and main_pc.cover != null, "alt-tab covers the screen")
	check(main_pc.view.get_child(0).process_mode == Node.PROCESS_MODE_DISABLED, "the game waits under the spreadsheet")
	var cells_before: int = busy.wd.cells
	var sheet = busy._sheet
	var todo: int = sheet._todo[0]
	sheet._cells[todo].pressed.emit()
	check(busy.wd.cells == cells_before + 1, "a spreadsheet cell counts")
	busy.wd.suspicion = 50.0
	await frames(60)
	check(busy.wd.suspicion < 50.0, "working cools suspicion (%.0f)" % busy.wd.suspicion)
	office._set_seat(null)
	await frames(5)
	check(not busy.is_covered() and main_pc.cover == null, "standing up uncovers the screen")
	check(main_pc.view.get_child(0).process_mode != Node.PROCESS_MODE_DISABLED, "and the game runs again")
	# Let the visit finish.
	for i in 3000:
		await process_frame
		if busy._visit_t < 0.0:
			break
		if busy.notice.visible:
			press_first()
	check(busy._visit_t < 0.0 and not busy._boss_node.visible, "the boss leaves")

	# Another visit: alt-tab with the boss right there = a close call; then
	# the all-clear when they leave.
	busy.wd.suspicion = 0.0
	busy.wd._grace = 0.0
	office._set_seat(main_pc)
	busy.dev_boss_now()
	var close := false
	for i in 1200:
		await process_frame
		if busy._boss_close():
			close = true
			break
	check(close and busy._danger > 0.0, "the boss closes in (danger %.2f)" % busy._danger)
	var slack0: float = busy.wd.slacked
	busy.alt_tab()
	check(busy.wd.close_calls == 1 and busy.wd.slacked >= slack0 + Workday.CLOSE_CALL, "alt-tab just in time = a close call")
	for i in 3000:
		await process_frame
		if busy._visit_t < 0.0:
			break
		if busy.notice.visible:
			press_first()
	check(office._toast.text.contains("COAST IS CLEAR"), "the all-clear when the boss leaves (%s)" % office._toast.text.replace("\n", " / "))
	office._set_seat(null)
	await frames(5)

	# Coworkers: a lookout coughs and covers an empty desk; a snitch tips off the boss.
	var crew: Coworkers = office._ladder.crew
	Dev.set_role(crew, "kev", "lookout")
	busy._lookout_warns()
	check(office._toast.text.begins_with("KEV"), "the lookout coughs (%s)" % office._toast.text.replace("\n", " / "))
	busy.wd.suspicion = 0.0
	busy._empty_desk()
	check(busy.wd.suspicion == 0.0 and office._toast.text.contains("COVERED"), "the lookout covers an empty desk")
	Dev.set_role(crew, "bernie", "snitch")
	busy._snitch()
	check(busy.wd.suspicion >= Workday.SNITCH - 0.1 and busy._visit_t >= 0.0, "a snitch brings the boss")
	busy._end_visit()
	Dev.set_role(crew, "kev", "")
	Dev.set_role(crew, "bernie", "")
	crew.trust.erase("kev")
	crew.save()

	# Your own game: a desk win becomes a piece; the DEV KIT builds and scores it.
	await frames(70)
	bump("comedy_sets")
	await frames(80)
	check(busy.gm.has("COMEDY"), "a comedy set won = the COMEDY piece")
	check(busy.disks.visible and busy.disks._entry.get("name") == "COMEDY", "it pops up as a NEW DISK!")
	check(busy.binder.has("COMEDY"), "and goes in the disk binder")
	busy.disks._ok.pressed.emit()
	busy.dev_piece("loot")
	check(busy.gm.has("SLOT REELS"), "a Loot Machine piece")
	await frames(5)
	check(busy.disks.visible, "SLOT REELS pops up")
	busy.disks._ok.pressed.emit()
	await frames(2)
	check(busy.disks.visible and busy.disks._entry.get("name") == "LAUGH SLOTS", "then COMBO FOUND! LAUGH SLOTS")
	busy.disks._ok.pressed.emit()
	await frames(2)
	check(not busy.disks.visible and not paused, "NICE! closes it and the office runs again")
	var kit_pc = busy._kit_pc
	check(kit_pc.screen.is_visible_in_tree(), "the DEV KIT desk is there")
	office._set_seat(kit_pc)
	await frames(10)
	var kit = busy._kit
	check(kit._title.text.begins_with("LAUGH SLOTS"), "COMEDY + SLOT REELS = %s" % kit._title.text)
	check(busy.gm.score().score == 40, "scored with the combo (%d)" % busy.gm.score().score)
	kit._rows["mechanic"].pressed.emit()
	check(not busy.gm.build.has("mechanic"), "tapping a row cycles its piece")
	kit._rows["mechanic"].pressed.emit()
	kit.play_trailer()
	await frames(5)
	check(kit._trailer.visible and kit._trailer_label.text == "HUMBLE HOUSE GAMES PRESENTS", "the trailer plays")
	for i in 12:
		kit._next_card()
	check(not kit._trailer.visible, "the trailer ends")
	office._set_seat(null)
	await frames(5)

	# Empty desk: out of the office when the boss checks.
	busy.wd.suspicion = 0.0
	busy.wd.strikes = 1
	busy._empty_desk()
	check(busy.wd.suspicion >= Workday.EMPTY_DESK - 0.1, "empty desk adds suspicion")

	# Fired: strikes run out, the run starts over.
	busy.wd.tick(Workday.GRACE + 1.0)
	busy.wd.add(200.0)
	busy.wd.tick(Workday.GRACE + 1.0)
	var level: String = busy.wd.add(200.0)
	check(level == "fired" and busy.wd.fired, "third strike fires you")
	busy._caught(level)
	await frames(2)
	check(busy.notice.visible, "fired notice shows")
	press_first()
	await frames(5)
	check(not busy.wd.fired and busy.wd.floor_i == 1 and busy.wd.day == 0, "start over: floor 1, Monday")
	await frames(5)
	check(busy.notice.visible, "a new morning card")
	press_first()
	await frames(5)

	# 5 PM, then the next day; Friday ends the week.
	busy.dev_skip_to(Workday.DAY_MINUTES - 1.0)
	await frames(90)
	check(busy.notice.visible and busy.notice._head.text.begins_with("5:00"), "5 PM: clock out")
	press_first()
	await frames(5)
	check(busy.wd.day == 1 and busy.wd.minutes <= 1.0, "the next morning (%s)" % busy.wd.clock_text())
	press_first()
	await frames(5)
	# After hours: 5 PM rings mid-game, so you stay. Lights out, no boss, x2.
	office._set_seat(office._computers[0])
	busy.dev_skip_to(Workday.DAY_MINUTES - 1.0)
	await frames(90)
	check(busy.wd.overtime and not busy.notice.visible, "5 PM mid-game: after hours (%s)" % busy.wd.clock_text())
	await frames(int(Engine.get_frames_per_second() * office.NIGHT_FADE) + 120)
	check(office._night > 0.9, "the lights go out (%.2f)" % office._night)
	var ot: float = busy.wd.overtime_slack
	await frames(30)
	check(busy.wd.overtime_slack > ot, "slack keeps counting after hours (%s)" % Workday.hours_text(busy.wd.overtime_slack))
	busy.wd.minutes = Workday.DAY_MINUTES + Workday.OVERTIME_MINUTES - 1.0
	await frames(90)
	check(busy.notice.visible and busy.notice._body.text.begins_with("STAYED LATE"), "7 PM: clock out, stayed late")
	press_first()
	await frames(5)
	check(busy.wd.day == 2 and busy.wd.suspicion > 0.0, "the next morning you're tired (%.0f)" % busy.wd.suspicion)
	check(busy.notice.visible and busy.notice._body.text.begins_with("You stayed late"), "the morning card says so")
	press_first()
	await frames(5)
	# Friday 5 PM: ship day. A strong build beats Theo and gets you promoted.
	busy.dev_all_pieces()
	busy.gm.build = {"genre": "COMEDY", "mechanic": "SLOT REELS", "art": "CASINO NEON", "sound": "DING DING", "character": "KEV"}
	var tokens_before: int = office._ladder.state.tokens
	busy.dev_friday()
	busy.wd.minutes = Workday.DAY_MINUTES - 1.0
	await frames(90)
	check(busy.notice.visible and busy.notice._head.text.begins_with("YOU SHIPPED"), "Friday 5 PM: you ship (%s)" % busy.notice._head.text.replace("\n", " "))
	var pages: Array = []
	for i in 6:
		if busy.wd.week == 2:
			break
		pages.append(busy.notice._head.text.replace("\n", " "))
		press_first()
		await frames(5)
	check(pages.has("THEO SHIPPED TOO") and pages.has("PROMOTED!"), "reviews, Theo, promotion (%s)" % ", ".join(pages))
	check(office._ladder.state.tokens > tokens_before, "the reviews paid out tokens")
	check(busy.wd.week == 2 and busy.wd.day == 0 and busy.wd.floor_i == 2, "week 2, Monday, floor 2")
	check(busy.gm.pieces.is_empty(), "a new week starts with an empty kit")
	check(busy.notice._body.text.contains("CHAD"), "the morning card names the new boss")
	press_first()
	await frames(5)
	# Floor 2's boss works from home: he video-calls instead of walking in.
	busy.dev_boss_now()
	await frames(5)
	check(busy._call_t >= 0.0 and busy._boss_node == null or not busy._boss_node.visible, "Chad rings instead of walking in")
	office._set_seat(office._computers[0])
	for i in 600:
		await process_frame
		if busy._connected:
			break
	check(busy._connected and busy._seen, "on the call he sees your screen")
	busy.alt_tab()
	await frames(5)
	check(busy._activity() == "working", "alt-tabbed on the call: working")
	office._set_seat(null)
	busy._call_t = -1.0
	press_first()
	await frames(5)

	# Off: no clock, no boss, the office as before.
	busy.set_enabled(false)
	var m1: float = busy.wd.minutes
	await frames(60)
	check(busy.wd.minutes == m1 and not busy._hud.visible, "off: the clock stops and the HUD hides")
	check(not busy._kit_pc.screen.is_visible_in_tree(), "off: no DEV KIT desk")

	print("\n%s: %d failed" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	quit(1 if fails else 0)


## A desk win, the way the games record it (the shared office stats).
func bump(stat: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(DaleStory.RELICS_PATH)
	var st = cfg.get_value("stats", "all", {})
	st[stat] = int(st.get(stat, 0)) + 1
	cfg.set_value("stats", "all", st)
	cfg.save(DaleStory.RELICS_PATH)


func press_first() -> void:
	for b in busy.notice._buttons.get_children():
		if b is Button and not b.is_queued_for_deletion():
			b.pressed.emit()
			return


func frames(n: int) -> void:
	for i in n:
		await process_frame


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print(("PASS  " if ok else "FAIL  ") + what)
