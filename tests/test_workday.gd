extends GutTest
## Look Busy's workday: the clock, the boss's schedule and route, suspicion,
## strikes up to getting fired, and the week.

const PATH := "user://test_look_busy.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_clock_reads_like_an_office_clock() -> void:
	var w := Workday.new(PATH)
	assert_eq(w.clock_text(), "MON 9:00 AM")
	w.minutes = 200.0
	assert_eq(w.clock_text(), "MON 12:20 PM")
	w.day = 4
	w.minutes = 479.0
	assert_eq(w.clock_text(), "FRI 4:59 PM")


func test_a_day_takes_day_seconds_and_ends_at_five() -> void:
	var w := Workday.new(PATH)
	var ended := false
	var visits := 0
	for i in int(Workday.DAY_SECONDS) + 2:
		for ev in w.tick(1.0):
			if ev.type == "day_end":
				ended = true
			elif ev.type == "visit":
				visits += 1
	assert_true(ended)
	assert_true(w.day_over())
	assert_eq(visits, Workday.visits(w.boss()).size(), "every visit fires once")
	assert_eq(w.tick(1.0), [], "the clock waits at 5 PM")


func test_visits_are_fixed_and_skip_lunch() -> void:
	var marge := Workday.boss_for(1)
	assert_eq(Workday.visits(marge), [20.0, 110.0, 290.0, 380.0, 470.0], "9:20, 10:50, 1:50, 3:20, 4:50")
	for b in BusyLines.BOSSES:
		for t in Workday.visits(b):
			assert_false(t >= Workday.LUNCH[0] and t < Workday.LUNCH[1], "%s skips lunch" % b.id)
	assert_eq(Workday.boss_for(2).kind, "call", "floor 2 works from home")
	assert_eq(Workday.boss_for(99).id, Workday.boss_for(BusyLines.FLOORS).id)


func test_patrol_walks_the_route_and_stops_at_your_desk() -> void:
	var route: Array = BusyLines.ROUTE
	var start := Workday.patrol_at(route, 1.0, 0.0)
	assert_eq(start.pos, route[0].p)
	var total := Workday.route_time(route, 1.0)
	assert_true(Workday.patrol_at(route, 1.0, total + 0.1).done)
	var saw_desk := false
	var t := 0.0
	while t < total:
		var pa := Workday.patrol_at(route, 1.0, t)
		if pa.desk:
			saw_desk = true
			assert_almost_eq(pa.pos.distance_to(route[3].p), 0.0, 0.001)
		t += 0.1
	assert_true(saw_desk, "stops at your desk")
	# Halfway down the first leg, facing the way they walk (toward -z).
	var mid := Workday.patrol_at(route, 1.0, route[0].p.distance_to(route[1].p) * 0.5)
	assert_almost_eq(absf(mid.yaw), PI, 0.01)


func test_sight_cone() -> void:
	var at := Vector2.ZERO
	assert_true(Workday.sees(at, 0.0, Vector2(0, 3), 6.0, 55.0), "straight ahead (+z)")
	assert_false(Workday.sees(at, 0.0, Vector2(0, -3), 6.0, 55.0), "behind")
	assert_false(Workday.sees(at, 0.0, Vector2(0, 7), 6.0, 55.0), "too far")
	assert_true(Workday.sees(at, 0.0, Vector2(0, -0.8), 6.0, 55.0), "right next to them")
	assert_true(Workday.sees(at, PI / 2, Vector2(3, 0.5), 6.0, 55.0), "turned to +x")


func test_suspicion_strikes_then_fired() -> void:
	var w := Workday.new(PATH)
	var levels: Array = []
	for i in 2000:
		var level := w.watch(0.1, "slacking", true, true)
		if level != "":
			levels.append(level)
			w.tick(Workday.GRACE + 0.1)  # let the grace run out
		if w.fired:
			break
	assert_eq(levels, ["warning", "writeup", "fired"])
	assert_true(w.fired)
	assert_eq(w.watch(10.0, "slacking", true, true), "", "nothing after fired")


func test_working_cools_and_unseen_decays() -> void:
	var w := Workday.new(PATH)
	w.suspicion = 50.0
	w.watch(1.0, "working", true, true)
	assert_lt(w.suspicion, 50.0, "fake work while watched")
	var s := w.suspicion
	w.watch(1.0, "slacking", false, true)
	assert_lt(w.suspicion, s, "not seen: it fades")
	w.suspicion = 0.0
	w.watch(1.0, "idle", true, true)
	assert_gt(w.suspicion, 0.0, "standing around while watched")


func test_grace_after_a_strike() -> void:
	var w := Workday.new(PATH)
	assert_eq(w.add(150.0), "warning")
	assert_true(w.in_grace())
	assert_eq(w.add(150.0), "", "no second strike right away")
	w.watch(1.0, "slacking", true, true)
	assert_eq(w.suspicion, 0.0)


func test_week_and_start_over() -> void:
	var w := Workday.new(PATH)
	for d in 4:
		assert_true(w.next_day())
	assert_true(w.is_friday())
	assert_false(w.next_day(), "Friday ends the week")
	w.strike()
	w.new_week(true)
	assert_eq(w.floor_i, 2)
	assert_eq(w.day, 0)
	assert_eq(w.strikes, 0)
	assert_eq(w.best_floor, 2)
	w.fired = true
	w.start_over()
	assert_eq(w.floor_i, 1)
	assert_eq(w.week, 1)
	assert_false(w.fired)
	assert_eq(w.best_floor, 2, "best floor stays")
	assert_eq(w.runs, 2)


func test_saves() -> void:
	var w := Workday.new(PATH)
	w.minutes = 123.0
	w.strike()
	w.next_day()
	w.minutes = 77.0
	w.save()
	var again := Workday.new(PATH)
	assert_eq(again.day, 1)
	assert_eq(again.strikes, 1)
	assert_almost_eq(again.minutes, 77.0, 0.01)


func test_slack_fills_only_while_playing_unseen() -> void:
	var w := Workday.new(PATH)
	assert_eq(w.slacked, Workday.MORNING_COFFEE, "the day starts with a coffee break on the meter")
	w.slack(10.0, "idle", false)
	w.slack(10.0, "working", false)
	w.slack(10.0, "slacking", true)
	assert_eq(w.slacked, Workday.MORNING_COFFEE, "walking, working or being watched isn't slacking")
	w.slack(10.0, "slacking", false)
	assert_almost_eq(w.slacked, Workday.MORNING_COFFEE + 10.0 * Workday.DAY_MINUTES / Workday.DAY_SECONDS, 0.01)
	assert_eq(w.best_slack, w.slacked)


func test_quota_met_once_and_counts_for_the_week() -> void:
	var w := Workday.new(PATH)
	var need := (w.quota() - w.slacked) * Workday.DAY_SECONDS / Workday.DAY_MINUTES
	assert_false(w.slack(need - 1.0, "slacking", false))
	assert_true(w.slack(2.0, "slacking", false), "true the moment the quota is met")
	assert_false(w.slack(2.0, "slacking", false), "only once a day")
	assert_true(w.quota_met())
	assert_eq(w.quota_days, 1)
	w.next_day()
	assert_eq(w.slacked, Workday.MORNING_COFFEE, "a new day, a fresh meter")
	assert_false(w.quota_met())
	assert_gt(w.slacked_week, w.quota(), "the week keeps it")
	w.floor_i = 3
	assert_gt(w.quota(), Workday.QUOTA[0], "higher floors want more")


func test_close_call_adds_slack() -> void:
	var w := Workday.new(PATH)
	w.close_call()
	assert_eq(w.close_calls, 1)
	assert_eq(w.slacked, Workday.MORNING_COFFEE + Workday.CLOSE_CALL)


func test_next_visit_countdown_in_real_seconds() -> void:
	var w := Workday.new(PATH)
	var first := float(Workday.boss_for(1).at)
	assert_almost_eq(w.next_visit_in(), first * Workday.DAY_SECONDS / Workday.DAY_MINUTES, 0.01)
	w.minutes = Workday.DAY_MINUTES - 1.0
	assert_eq(w.next_visit_in(), -1.0, "none left today")
	assert_eq(Workday.hours_text(135.0), "2:15")


func test_slack_saves_and_resets_with_the_week() -> void:
	var w := Workday.new(PATH)
	w.slack(30.0, "slacking", false)
	w.close_call()
	w.save()
	var again := Workday.new(PATH)
	assert_almost_eq(again.slacked, w.slacked, 0.01)
	assert_eq(again.close_calls, 1)
	assert_almost_eq(again.best_slack, w.best_slack, 0.01)
	again.new_week(false)
	assert_eq(again.slacked_week, Workday.MORNING_COFFEE)
	assert_eq(again.quota_days, 0)
	assert_almost_eq(again.best_slack, w.best_slack, 0.01, "the best day is forever")
