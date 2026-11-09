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
	"capsule": {"name": "MYSTERY CAPSULE", "tickets": 0},
	"star": {"name": "TOP-SHELF STAR", "tickets": 150, "beats": true},
}
## Seconds to steer before the claw drops by itself (like a real one).
const CLAW_TIMER := 15.0
## The glowing bonus prize (a new one each drop) pays this many times over.
const CLAW_BONUS_X := 2
## Two prizes down the chute from one drop: the lot pays this much more.
const CLAW_DOUBLE_X := 1.5
## What a mystery capsule holds: [tickets, weight].
const CLAW_CAPSULE := [[15, 40], [40, 30], [80, 20], [150, 8], [300, 2]]

## Coin pusher: one token = this many coins to drop. What falls off the front.
const PUSHER_COINS_PER_TOKEN := 5
const PUSHER_COIN := 3
const PUSHER_BUNDLE := 25
const PUSHER_JACKPOT := 150
## The blue token chip: a few tickets and a play back.
const PUSHER_TOKEN_CHIP := 5
const PUSHER_GOLD := 15
## Coins falling off in one shove: a streak that big multiplies them.
const PUSHER_STREAK_2X := 5
const PUSHER_STREAK_3X := 8
## Drop a coin while the chute is in the lit zone: one of these ([kind,
## weight]); the zone then goes dark to recharge for this many seconds.
const PUSHER_BONUSES := [["shower", 40], ["gold", 30], ["mega", 20], ["token", 10]]
const PUSHER_ZONE_RECHARGE := 9.0

## Ragdoll column (bounce the Dale dummy up the glass): tickets per point,
## and the score that beats it. Style (flips) counts double with Bernie's
## perk. A round is RAGDOLL_KICKS bounces; points per metre of the best
## height, per bumper hit and per ring of the bell at the top.
const RAGDOLL_POINTS_PER_TICKET := 80
const RAGDOLL_BEAT := 1500
const RAGDOLL_STYLE_X := 2.0
const RAGDOLL_KICKS := 8
const RAGDOLL_HEIGHT := 100.0
const RAGDOLL_FLIP := 60.0
## Back-to-back PERFECT bounces chain a multiplier for bumpers and the bell.
const RAGDOLL_CHAIN := [1.0, 1.25, 1.5, 2.0, 2.5]
## The lit target bumper pays this many bumpers; the bell gives a bounce back.
const RAGDOLL_TARGET_X := 3
const RAGDOLL_BUMPER := 25
const RAGDOLL_BELL := 100
## The bell gives a bounce back, up to this many times a round.
const RAGDOLL_BELL_KICKS := 2

## Rage Cage (trading floor): a sledgehammer, an office machine, a glass
## box. A play is RAGE_SWINGS swings; it costs a token, or one STRESS (free,
## earned by bad days on the trading floor, LadderState.add_stress). Every
## piece knocked off the table pays; glass pays double. Clear the whole
## table (CLEAN DESK) for the bonus and to beat the machine.
const RAGE_SWINGS := 3
const RAGE_PIECE := 1
const RAGE_GLASS := 2
const RAGE_CLEAN := 25
## The table counts as clean when less than this share of the machine's
## volume is still on it.
const RAGE_CLEAN_LEFT := 0.12
## Power at or above this is a PERFECT swing (the meter's top band).
const RAGE_PERFECT := 0.88
## Hitting the glowing weak spot multiplies the swing's power.
const RAGE_WEAK_X := 1.5
## Pieces one swing breaks a part into: from a tap to a perfect crit.
const RAGE_CELLS_MIN := 2
const RAGE_CELLS_MAX := 7


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
		"token":
			return PUSHER_TOKEN_CHIP
		"gold":
			return PUSHER_GOLD
	return PUSHER_COIN


## Ragdoll score from a round: best height (metres over the mat) + knocks off
## the glass + spins (full turns) + the points from hits (ragdoll_hit()).
static func ragdoll_score(height: float, impacts: float, spins: int, style := false, hits := 0) -> int:
	var spin_pts := spins * RAGDOLL_FLIP * (RAGDOLL_STYLE_X if style else 1.0)
	return int(height * RAGDOLL_HEIGHT + impacts + spin_pts + hits)


## Points for one hit ("bumper", "target" or "bell") with `perfects`
## PERFECT bounces in a row behind it.
static func ragdoll_hit(kind: String, perfects: int) -> int:
	var base: float = RAGDOLL_BELL if kind == "bell" else RAGDOLL_BUMPER * (RAGDOLL_TARGET_X if kind == "target" else 1)
	return int(base * ragdoll_chain_x(perfects))


static func ragdoll_chain_x(perfects: int) -> float:
	return RAGDOLL_CHAIN[clampi(perfects, 0, RAGDOLL_CHAIN.size() - 1)]


## A mystery capsule's tickets for a roll in 0..1.
static func claw_capsule(roll: float) -> int:
	var total := 0
	for c in CLAW_CAPSULE:
		total += c[1]
	var at := roll * total
	for c in CLAW_CAPSULE:
		at -= c[1]
		if at < 0.0:
			return c[0]
	return CLAW_CAPSULE[-1][0]


## A lit-zone bonus for a roll in 0..1.
static func pusher_bonus(roll: float) -> String:
	var total := 0
	for b in PUSHER_BONUSES:
		total += b[1]
	var at := roll * total
	for b in PUSHER_BONUSES:
		at -= b[1]
		if at < 0.0:
			return b[0]
	return PUSHER_BONUSES[-1][0]


## Tickets for a coin in a streak of `streak` coins.
static func pusher_streak_x(streak: int) -> int:
	return 3 if streak >= PUSHER_STREAK_3X else (2 if streak >= PUSHER_STREAK_2X else 1)


static func ragdoll_tickets(score: int) -> int:
	return score / RAGDOLL_POINTS_PER_TICKET


## How many pieces a swing of `power` (0-1, after the weak-spot boost)
## breaks a part into, by how close the part is to the hit (`near` 0-1).
static func rage_cells(power: float, near: float) -> int:
	var p := clampf(power, 0.0, 1.5) * clampf(near, 0.0, 1.0)
	if p < 0.12:
		return 1
	return clampi(int(round(lerpf(RAGE_CELLS_MIN, RAGE_CELLS_MAX, minf(p, 1.0)) + maxf(0.0, p - 1.0) * 6.0)), RAGE_CELLS_MIN, RAGE_CELLS_MAX + 3)


## One play's tickets: pieces off the table, glass pieces, CLEAN DESK.
static func rage_tickets(pieces: int, glass: int, clean: bool) -> int:
	return pieces * RAGE_PIECE + glass * RAGE_GLASS + (RAGE_CLEAN if clean else 0)
