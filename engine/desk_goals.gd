class_name DeskGoals
extends RefCounted
## Three stars per desk: what "beating" each desk game means, one clear goal
## at a time. The office shows the next goal while you sit at a desk, stars
## above each desk, and a celebration when one is earned
## (scenes/office/desk_card.gd). Pure rules, no scenes.
##
## A tier is [key, amount, goal text]. Keys:
##   a shared office stat (DaleStory.read_stats(): comedy_sets, pong_bosses...)
##   "best:<machine>": the most tickets one arcade win paid (LadderState.best)
##   "beat:<machine>": 1 once the machine's big prize is won (LadderState.beaten)
## Stars count the tiers met, in order: the next goal is the first one not met.

const DESKS := {
	"comedy": {"name": "KILLIN' IN COMEDY", "tiers": [
		["comedy_sets", 1, "WIN A SET: HIT THE LAUGH TARGET BEFORE THE LIGHT"],
		["comedy_sets", 3, "WIN 3 SETS"],
		["comedy_shows", 1, "KILL AT THE HEADLINE SHOW"]]},
	"pong": {"name": "PHONE PONG", "tiers": [
		["pong_stages", 1, "CLEAR A STAGE"],
		["pong_bosses", 1, "BEAT A BOSS (EVERY 4TH STAGE)"],
		["pong_bosses", 3, "BEAT 3 BOSSES"]]},
	"proof": {"name": "PROOF HAND", "tiers": [
		["proof_wins", 1, "PROVE A BLIND: BEAT ITS TARGET IN 4 PLAYS"],
		["proof_wins", 3, "PROVE 3 BLINDS (ANTE 1'S BOSS IS THE THIRD)"],
		["proof_runs_won", 1, "WIN A RUN: PROVE ALL 3 BOSSES"]]},
	"cube": {"name": "CUBE DESK", "tiers": [
		["cube_solves", 1, "SOLVE A LEVEL"],
		["cube_solves", 5, "SOLVE 5 LEVELS"],
		["cube_records", 1, "BEAT THE 2.51 WORLD RECORD"]]},
	"loot": {"name": "LOOT MACHINE", "tiers": [
		["loot_runs", 1, "PLAY A RUN"],
		["loot_wins", 1, "WIN A RUN: HIT EVERY QUOTA"],
		["loot_wins", 3, "WIN 3 RUNS"]]},
	"claw": {"name": "CLAW KING", "tiers": [
		["best:claw", 30, "GRAB ANY PRIZE INTO THE CHUTE"],
		["best:claw", 60, "GRAB A BEAR"],
		["beat:claw", 1, "GRAB THE TOP-SHELF STAR"]]},
	"pusher": {"name": "PUSH YOUR LUCK", "tiers": [
		["best:pusher", 1, "PUSH A COIN OFF THE EDGE"],
		["best:pusher", 25, "PUSH OFF A GREEN BUNDLE"],
		["beat:pusher", 1, "PUSH OFF THE GOLD JACKPOT CHIP"]]},
	"ragdoll": {"name": "FALL GUY", "tiers": [
		["best:ragdoll", 1, "SCORE ANY POINTS"],
		["best:ragdoll", 22, "SCORE 450 IN ONE ROUND"],
		["beat:ragdoll", 1, "SCORE 900 IN ONE ROUND"]]},
}

## The desks in the order they're met.
const ORDER := ["pong", "comedy", "cube", "loot", "proof", "claw", "pusher", "ragdoll"]


static func has(id: String) -> bool:
	return DESKS.has(id)


static func value(key: String, stats: Dictionary, best: Dictionary, beaten: Array) -> int:
	if key.begins_with("best:"):
		return int(best.get(key.substr(5), 0))
	if key.begins_with("beat:"):
		return 1 if beaten.has(key.substr(5)) else 0
	return int(stats.get(key, 0))


## Stars earned (0-3): tiers met, in order.
static func stars(id: String, stats: Dictionary, best := {}, beaten := []) -> int:
	var n := 0
	for t in DESKS.get(id, {}).get("tiers", []):
		if value(t[0], stats, best, beaten) < int(t[1]):
			break
		n += 1
	return n


## {text, have, need} for the next goal, or {} when all three stars are in.
static func next_goal(id: String, stats: Dictionary, best := {}, beaten := []) -> Dictionary:
	var tiers: Array = DESKS.get(id, {}).get("tiers", [])
	var i := stars(id, stats, best, beaten)
	if i >= tiers.size():
		return {}
	var t: Array = tiers[i]
	var have := value(t[0], stats, best, beaten)
	# Counting goals show progress ("2/3"); thresholds just show the goal.
	var counts: bool = int(t[1]) > 1 and not str(t[0]).begins_with("best:")
	return {"text": t[2], "have": have, "need": int(t[1]), "counts": counts}


## "★★☆"
static func star_text(n: int) -> String:
	return "★".repeat(clampi(n, 0, 3)) + "☆".repeat(3 - clampi(n, 0, 3))


## Stars across every desk, and the most there are.
static func total(stats: Dictionary, best := {}, beaten := []) -> Vector2i:
	var n := 0
	for id in DESKS:
		n += stars(id, stats, best, beaten)
	return Vector2i(n, DESKS.size() * 3)
