extends GutTest
## Arcade payouts shared by the glass-cage machines.


func test_arcade_payouts() -> void:
	assert_false(ArcadeRules.claw_strong(0))
	assert_true(ArcadeRules.claw_strong(3))
	assert_true(ArcadeRules.claw_strong(7))
	assert_true(ArcadeRules.claw_beats("star"))
	assert_false(ArcadeRules.claw_beats("duck"))
	assert_eq(ArcadeRules.pusher_tickets("jackpot"), ArcadeRules.PUSHER_JACKPOT)
	assert_eq(ArcadeRules.ragdoll_score(1.0, 0.0, 2, true), 100 + 2 * 60 * 2, "height, flips doubled with style")
	assert_eq(ArcadeRules.ragdoll_score(0.0, 0.0, 0, false, 70), 70, "hits add on")
	assert_eq(ArcadeRules.ragdoll_tickets(1000), 1000 / ArcadeRules.RAGDOLL_POINTS_PER_TICKET)
