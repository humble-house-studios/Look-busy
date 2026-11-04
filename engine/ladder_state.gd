class_name LadderState
extends RefCounted
## Progress up the ladder, one elevator ride per floor: the arcade (tokens
## in, tickets out, the prize counter sells the Elevator Key), the trading floor
## (tickets cash out as your portfolio; survive a trading week), the boardroom (Dale is
## waiting there: he's the founder; then win the pitch), the corner office
## (his memo) and the locked TOP FLOOR elevator (the final room; not built yet).
## Hidden extras for players who dig: the archive in the arcade basement, and
## behind a bookcase in the corner office the old comedy club stage (opens
## once you've found the archive and Ray told you the building was a club).
## Each room pays out what the next one spends. Pure rules; saved in
## user://ladder.cfg. Design: docs/narrative.md (The Ladder).

const SAVE_PATH := "user://ladder.cfg"

## First paycheck when you walk into the arcade: base + a bonus per office
## milestone (capped), so playing the office desks pays off up here.
const PAYCHECK_BASE := 15
const PAYCHECK_PER_MILESTONE := 2
const PAYCHECK_MILESTONE_CAP := 10
const MILESTONE_STATS := ["pong_bosses", "cube_records", "comedy_sets", "loot_runs", "proof_wins"]
## Out of tokens? The prize counter's petty-cash jar refills you, so you can
## never get stuck.
const PETTY_CASH := 5
const DOOR_KEY := "door_key"
const DOOR_KEY_COST := 300
## The prize counter. `for` = the coworker who wants it as a gift.
const PRIZES := [
	{"id": "door_key", "name": "ELEVATOR KEY", "cost": DOOR_KEY_COST, "note": "Takes the elevator up to the next floor"},
	{"id": "plush", "name": "TOP-SHELF PLUSH", "cost": 80, "note": "Gloria has wanted this for eleven years", "for": "gloria"},
	{"id": "tie", "name": "STOCK-TICKER TIE", "cost": 60, "note": "Kev would wear this to his wedding", "for": "kev"},
	{"id": "stress_ball", "name": "STRESS BALL", "cost": 40, "note": "For Bernie's desk. Spare Dale.", "for": "bernie"},
	{"id": "coffee", "name": "HOT COFFEE", "cost": 20, "note": "Nobody brings the janitor coffee", "for": "ray"},
]
## Trading floor: you start with this plus your leftover tickets, then survive
## a trading week (engine/market.gd: a goal every day). MARKET_GOAL is the
## old "double it" target, kept for what it shows.
const MARKET_BASE_CASH := 1000
const MARKET_PER_TICKET := 5
const MARKET_GOAL := 2.0
## Bad moments on the trading floor bank STRESS: a free play of the Rage
## Cage each (a flash crash, a red day, getting fired). Capped.
const STRESS_CRASH := 1
const STRESS_RED_DAY := 1
const STRESS_FIRED := 2
const STRESS_MAX := 9
const SECRETS_TOTAL := 5

var tokens := 0
var tickets := 0
var paid := false
## Things you own: prizes and coworker perks (gloria_eye, insider_tip,
## hr_badge, style, theo_vote, archive_key).
var items: Array[String] = []
## Machines whose big prize you've won: claw, pusher, ragdoll.
var beaten: Array[String] = []
## The most tickets one win paid, per machine (engine/desk_goals.gd stars).
var best := {}
## Machine rounds played (a closed-off coworker opens up after one more).
var plays := 0
## Milestones: entered, market, reveal, pitch, memo, archive, stage.
var done: Array[String] = []
var market_cash := 0
## Free Rage Cage plays, banked by bad trading days.
var stress := 0

var _path: String


func _init(save_path := SAVE_PATH) -> void:
	_path = save_path
	load_save()


static func milestones(stats: Dictionary) -> int:
	var n := 0
	for key in MILESTONE_STATS:
		n += int(stats.get(key, 0))
	return mini(n, PAYCHECK_MILESTONE_CAP)


## Walking into the arcade the first time pays you. Returns tokens paid (0 if
## already paid).
func collect_paycheck(stats: Dictionary) -> int:
	if paid:
		return 0
	paid = true
	var pay := PAYCHECK_BASE + PAYCHECK_PER_MILESTONE * milestones(stats)
	tokens += pay
	mark("entered")
	save()
	return pay


## One play of a machine. False if you're out of tokens.
func spend_token() -> bool:
	if tokens <= 0:
		return false
	tokens -= 1
	plays += 1
	save()
	return true


## Bank STRESS (capped). Returns how much actually went in.
func add_stress(n: int) -> int:
	var before := stress
	stress = clampi(stress + n, 0, STRESS_MAX)
	save()
	return stress - before


## One Rage Cage play: free with STRESS, else a token. "" if you can't.
func pay_rage() -> String:
	if stress > 0:
		stress -= 1
		plays += 1
		save()
		return "stress"
	return "token" if spend_token() else ""


## A play back (the coin pusher's token chip).
func give_token(n := 1) -> void:
	tokens += n
	save()


func petty_cash() -> int:
	if tokens > 0:
		return 0
	tokens += PETTY_CASH
	save()
	return PETTY_CASH


func win_tickets(n: int, machine := "") -> void:
	tickets += maxi(0, n)
	if machine != "" and n > int(best.get(machine, 0)):
		best[machine] = n
	save()


## The trading floor's record: most days cleared in one run (kept in best,
## read by the desk's stars). Pays no tickets.
func trading_record(days: int) -> void:
	if days > int(best.get("trading", 0)):
		best["trading"] = days
		save()


## A machine's big prize. True the first time.
func beat(machine: String) -> bool:
	if beaten.has(machine):
		return false
	beaten.append(machine)
	save()
	return true


func has(item: String) -> bool:
	return items.has(item)


static func prize(id: String) -> Dictionary:
	for p in PRIZES:
		if p.id == id:
			return p
	return {}


## Can you buy it right now? Gifts already given can't be bought twice.
func can_buy(id: String, given: Array = []) -> bool:
	var p := prize(id)
	if p.is_empty() or items.has(id) or tickets < int(p.cost):
		return false
	return not (p.has("for") and given.has(p["for"]))


func buy(id: String, given: Array = []) -> bool:
	if not can_buy(id, given):
		return false
	tickets -= int(prize(id).cost)
	items.append(id)
	save()
	return true


## Apply a coworker reward: "tokens:5", "tickets:25", "item:x", "consume:x".
func apply_reward(reward: String) -> void:
	var parts := reward.split(":")
	if parts.size() != 2:
		return
	match parts[0]:
		"tokens":
			tokens += int(parts[1])
		"tickets":
			tickets += int(parts[1])
		"item":
			if not items.has(parts[1]):
				items.append(parts[1])
		"consume":
			items.erase(parts[1])
	save()


func mark(milestone: String) -> void:
	if not done.has(milestone):
		done.append(milestone)
		save()


func is_done(milestone: String) -> bool:
	return done.has(milestone)


## The trading floor's starting cash: tickets cash out the first time you walk in.
func market_start() -> int:
	if market_cash <= 0:
		market_cash = MARKET_BASE_CASH + MARKET_PER_TICKET * tickets
		tickets = 0
		save()
	return market_cash


func market_target() -> int:
	return int(market_start() * MARKET_GOAL)


## Which doors are open. office_done: Dale's story is finished (he sends you
## through the office door). club_known: Ray told you the building was a
## comedy club (with the archive found, the bookcase opens onto the stage).
## The top floor stays locked: the final room isn't built yet.
func door_open(door: String, office_done: bool, club_known := false) -> bool:
	match door:
		"office":
			return office_done
		"trading":
			return has(DOOR_KEY)
		"archive":
			return has("archive_key")
		"boardroom":
			return is_done("market")
		"corner":
			return is_done("pitch")
		"stage":
			return is_done("archive") and club_known
		"top":
			return false
	return false


## The on-screen to-do once Dale's story is done.
func objective(secret_count: int) -> String:
	if not is_done("entered"):
		return "TAKE THE ELEVATOR BEHIND YOU"
	if not has(DOOR_KEY):
		return "WIN %d TICKETS, BUY THE ELEVATOR KEY (%d/%d)" % [DOOR_KEY_COST, mini(tickets, DOOR_KEY_COST), DOOR_KEY_COST]
	if not is_done("market"):
		return "TRADING FLOOR: DOUBLE YOUR MONEY"
	if not is_done("reveal"):
		return "BOARDROOM: ...IS THAT DALE?"
	if not is_done("pitch"):
		return "BOARDROOM: WIN THE PITCH (3 OF 5 VOTES)"
	if not is_done("memo"):
		return "CORNER OFFICE: CHECK THE DESK"
	return "THE TOP FLOOR: LOCKED. NOT YET."


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	tokens = int(cfg.get_value("ladder", "tokens", 0))
	tickets = int(cfg.get_value("ladder", "tickets", 0))
	paid = bool(cfg.get_value("ladder", "paid", false))
	plays = int(cfg.get_value("ladder", "plays", 0))
	market_cash = int(cfg.get_value("ladder", "market_cash", 0))
	stress = int(cfg.get_value("ladder", "stress", 0))
	items.clear()
	for s in cfg.get_value("ladder", "items", []):
		items.append(str(s))
	var b = cfg.get_value("ladder", "best", {})
	best = b if b is Dictionary else {}
	beaten.clear()
	for s in cfg.get_value("ladder", "beaten", []):
		beaten.append(str(s))
	done.clear()
	for s in cfg.get_value("ladder", "done", []):
		done.append(str(s))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ladder", "tokens", tokens)
	cfg.set_value("ladder", "tickets", tickets)
	cfg.set_value("ladder", "paid", paid)
	cfg.set_value("ladder", "plays", plays)
	cfg.set_value("ladder", "market_cash", market_cash)
	cfg.set_value("ladder", "stress", stress)
	cfg.set_value("ladder", "items", Array(items))
	cfg.set_value("ladder", "beaten", Array(beaten))
	cfg.set_value("ladder", "best", best)
	cfg.set_value("ladder", "done", Array(done))
	cfg.save(_path)
