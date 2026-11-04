class_name ArcadeRules
## The arcade machines' numbers and payouts, in one place for tuning. The
## physics lives in the machine scenes (scenes/ladder/); what a result is worth
## lives here and is tested headless.

## Claw machine: every Nth grab is full strength (Gloria's Eye shows it).
## A weak grab slips a prize before the chute.
const CLAW_STRONG_EVERY := 4
const CLAW_WEAK_HOLD := 0.45
const CLAW_PRIZES := {
	"duck": {"name": "RUBBER DUCK", "tickets": 30},
	"bear": {"name": "BEAR", "tickets": 60},
	"star": {"name": "TOP-SHELF STAR", "tickets": 150, "beats": true},
}

## Coin pusher: one token = this many coins to drop. What falls off the front.
const PUSHER_COINS_PER_TOKEN := 5
const PUSHER_COIN := 3
const PUSHER_BUNDLE := 25
const PUSHER_JACKPOT := 150

## Ragdoll column (bounce the Dale dummy up the glass): tickets per point,
## and the score that beats it. Style (flips) counts double with Bernie's
## perk. A round is RAGDOLL_KICKS bounces; points per metre of the best
## height, per bumper hit and per ring of the bell at the top.
const RAGDOLL_POINTS_PER_TICKET := 20
const RAGDOLL_BEAT := 900
const RAGDOLL_STYLE_X := 2.0
const RAGDOLL_KICKS := 8
const RAGDOLL_HEIGHT := 100.0
const RAGDOLL_FLIP := 60.0
const RAGDOLL_BUMPER := 40
const RAGDOLL_BELL := 150


## Is the next grab (0-based count of grabs so far) a full-strength one?
static func claw_strong(grabs: int) -> bool:
	return grabs % CLAW_STRONG_EVERY == CLAW_STRONG_EVERY - 1


static func claw_tickets(prize: String) -> int:
	return int(CLAW_PRIZES.get(prize, {}).get("tickets", 0))


static func claw_beats(prize: String) -> bool:
	return bool(CLAW_PRIZES.get(prize, {}).get("beats", false))


## What a coin-pusher drop is worth: "coin", "bundle" or "jackpot".
static func pusher_tickets(kind: String) -> int:
	match kind:
		"bundle":
			return PUSHER_BUNDLE
		"jackpot":
			return PUSHER_JACKPOT
	return PUSHER_COIN


## Ragdoll score from a round: best height (metres over the mat) + knocks off
## the glass + spins (full turns) + bumpers hit + bell rings.
static func ragdoll_score(height: float, impacts: float, spins: int, style := false, bumpers := 0, bells := 0) -> int:
	var spin_pts := spins * RAGDOLL_FLIP * (RAGDOLL_STYLE_X if style else 1.0)
	return int(height * RAGDOLL_HEIGHT + impacts + spin_pts + bumpers * RAGDOLL_BUMPER + bells * RAGDOLL_BELL)


static func ragdoll_tickets(score: int) -> int:
	return score / RAGDOLL_POINTS_PER_TICKET
