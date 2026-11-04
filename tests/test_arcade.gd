extends GutTest
## The arcade machines' rules: missions, capsules, streaks and chains.

const SAVE := "user://test_arcade.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func test_missions_go_one_at_a_time_and_save() -> void:
	var a := ArcadeMissions.new(SAVE)
	assert_eq(a.current("claw").key, "won")
	assert_eq(a.event("claw", "bonus"), {}, "only the current mission counts")
	var m := a.event("claw", "won")
	assert_eq(m.tickets, 20)
	assert_eq(a.current("claw").key, "bonus")
	assert_string_starts_with(a.text("claw"), "MISSION 2/5")
	assert_eq(ArcadeMissions.new(SAVE).current("claw").key, "bonus", "saved")
	assert_eq(a.current("pusher").key, "bonus_drop", "each machine has its own")


func test_missions_need_their_count_and_end() -> void:
	var a := ArcadeMissions.new(SAVE)
	a.event("pusher", "bonus_drop")
	assert_eq(a.event("pusher", "coins_token", 5), {})
	assert_false(a.event("pusher", "coins_token", 9).is_empty())
	for i in 3:
		var m: Dictionary = a.current("pusher")
		a.event("pusher", m.key, m.need)
	assert_true(a.current("pusher").is_empty())
	assert_eq(a.text("pusher"), "ALL MISSIONS DONE!")
	assert_eq(a.event("pusher", "streak", 99), {})


func test_capsule_rolls_cover_every_prize() -> void:
	assert_eq(ArcadeRules.claw_capsule(0.0), ArcadeRules.CLAW_CAPSULE[0][0])
	assert_eq(ArcadeRules.claw_capsule(0.999), ArcadeRules.CLAW_CAPSULE[-1][0])
	var seen := {}
	for i in 100:
		seen[ArcadeRules.claw_capsule(i / 100.0)] = true
	assert_eq(seen.size(), ArcadeRules.CLAW_CAPSULE.size())


func test_pusher_streak_and_chips() -> void:
	assert_eq(ArcadeRules.pusher_streak_x(1), 1)
	assert_eq(ArcadeRules.pusher_streak_x(ArcadeRules.PUSHER_STREAK_2X), 2)
	assert_eq(ArcadeRules.pusher_streak_x(30), 3)
	assert_eq(ArcadeRules.pusher_tickets("token"), ArcadeRules.PUSHER_TOKEN_CHIP)


func test_pusher_bonus_rolls() -> void:
	assert_eq(ArcadeRules.pusher_bonus(0.0), ArcadeRules.PUSHER_BONUSES[0][0])
	assert_eq(ArcadeRules.pusher_bonus(0.999), ArcadeRules.PUSHER_BONUSES[-1][0])


func test_ragdoll_chain_multiplies_hits() -> void:
	assert_eq(ArcadeRules.ragdoll_hit("bumper", 0), ArcadeRules.RAGDOLL_BUMPER)
	assert_eq(ArcadeRules.ragdoll_hit("target", 0), ArcadeRules.RAGDOLL_BUMPER * 3)
	assert_eq(ArcadeRules.ragdoll_hit("bell", 2), int(ArcadeRules.RAGDOLL_BELL * ArcadeRules.RAGDOLL_CHAIN[2]))
	assert_eq(ArcadeRules.ragdoll_chain_x(99), ArcadeRules.RAGDOLL_CHAIN[-1], "the chain tops out")


func test_token_chip_gives_a_play_back() -> void:
	var l := LadderState.new("user://test_arcade_ladder.cfg")
	l.give_token()
	assert_eq(l.tokens, 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_arcade_ladder.cfg"))
