extends GutTest
## Every desk's three stars: what beating it means, one goal at a time.


func test_stars_count_tiers_in_order() -> void:
	assert_eq(DeskGoals.stars("pong", {}), 0)
	assert_eq(DeskGoals.stars("pong", {"pong_stages": 3}), 1)
	assert_eq(DeskGoals.stars("pong", {"pong_stages": 9, "pong_bosses": 3}), 3)
	assert_eq(DeskGoals.stars("comedy", {"comedy_shows": 1}), 0, "a later tier alone doesn't count")
	assert_eq(DeskGoals.star_text(2), "★★☆")


func test_next_goal_shows_progress_on_counting_goals() -> void:
	var g := DeskGoals.next_goal("comedy", {"comedy_sets": 2})
	assert_eq(g.need, 3)
	assert_eq(g.have, 2)
	assert_true(g.counts)
	assert_false(DeskGoals.next_goal("claw", {}, {"claw": 30}).counts, "ticket thresholds just name the goal")
	assert_eq(DeskGoals.next_goal("cube", {"cube_solves": 5, "cube_records": 1}), {}, "mastered")


func test_arcade_stars_from_best_wins_and_beaten() -> void:
	assert_eq(DeskGoals.stars("claw", {}, {"claw": 60}, []), 2)
	assert_eq(DeskGoals.stars("claw", {}, {"claw": 150}, ["claw"]), 3)
	assert_eq(DeskGoals.stars("ragdoll", {}, {"ragdoll": ArcadeRules.ragdoll_tickets(450)}, []), 2, "450 points is the second star")
	assert_eq(DeskGoals.stars("pusher", {}, {"pusher": ArcadeRules.PUSHER_BUNDLE}, []), 2)


func test_every_desk_has_three_tiers_and_is_in_the_order() -> void:
	for id in DeskGoals.DESKS:
		assert_eq(DeskGoals.DESKS[id].tiers.size(), 3, id)
		assert_has(DeskGoals.ORDER, id)
	assert_eq(DeskGoals.total({}).y, DeskGoals.DESKS.size() * 3)


func test_ladder_remembers_each_machines_best_win() -> void:
	var path := "user://test_desk_best.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var l := LadderState.new(path)
	l.win_tickets(30, "claw")
	l.win_tickets(5, "claw")
	l.win_tickets(60, "")
	assert_eq(l.best, {"claw": 30})
	assert_eq(LadderState.new(path).best, {"claw": 30}, "saved")
