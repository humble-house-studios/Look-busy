class_name Market
extends RefCounted
## The trading floor: a trading week, played live. Five stocks from your own
## world, each with a personality you learn to read (STEADY climbs, WAVE
## swings, ROCKET climbs then crashes, SPIKY jumps and snaps back, MEME is
## chaos with momentum). Every day has a goal: be worth it by the closing
## bell, or the floor shows you the door. The bell closes every position
## ("flat by the close"), then the after-hours shop sells perks for cash
## (stop-loss, short selling, a crystal ball, margin...), which makes
## tomorrow's goal harder to hit. Clear Friday and you've doubled your money;
## keep going for a record. RUMORS come a few seconds before the NEWS (some
## are fake), the whole market sometimes moves at once, and profitable trades
## in a row build a HOT HAND bonus. Pure rules: the trading terminal
## (scenes/ladder/trading.gd) ticks it and draws it.

const STOCKS := [
	{"sym": "HHG", "name": "HUMBLE HOUSE GAMES", "price": 40.0, "kind": "STEADY", "vol": 0.006},
	{"sym": "PRZ", "name": "PRIZE KING ARCADES", "price": 12.0, "kind": "MEME", "vol": 0.016},
	{"sym": "BRCK", "name": "BRICK WALL COMEDY", "price": 8.0, "kind": "ROCKET", "vol": 0.008},
	{"sym": "LOOT", "name": "LOOT MACHINE INC", "price": 25.0, "kind": "SPIKY", "vol": 0.006},
	{"sym": "PRF", "name": "PROOF HAND LABS", "price": 60.0, "kind": "WAVE", "vol": 0.004},
]
## One line on how each personality moves (shown under the chart).
const KIND_TIPS := {
	"STEADY": "SLOW AND SURE. CREEPS UP ALL DAY.",
	"WAVE": "SWINGS. BUY THE DIP, SELL THE TOP.",
	"ROCKET": "CLIMBS FASTER... THEN CRASHES.",
	"SPIKY": "JUMPS, THEN SNAPS BACK.",
	"MEME": "CHAOS. WHATEVER IT DOES, IT KEEPS DOING.",
}
## Headlines: [rumor, news] per direction. %s = the company name.
const UP_NEWS := [
	["RUMOR: %s IN TALKS FOR A HUGE DEAL", "%s SIGNS HUGE DEAL!"],
	["RUMOR: %s HAS A HIT IN TESTING", "%s'S NEW HIT SELLS OUT!"],
	["RUMOR: BIG STREAMER PLAYING %s", "%s GOES VIRAL!"],
	["RUMOR: %s BUYOUT OFFER INCOMING", "%s GETS A BUYOUT OFFER!"],
]
const DOWN_NEWS := [
	["RUMOR: TROUBLE AT %s", "%s RECALLS ITS PRODUCT"],
	["RUMOR: %s CEO SPOTTED FLEEING", "%s CEO RESIGNS"],
	["RUMOR: %s BOOKS LOOK FUNNY", "%s UNDER INVESTIGATION"],
]
## Whole-market moves: [rumor, news, kind].
const MARKET_NEWS := [
	["RUMOR: THE FED IS ABOUT TO SPEAK", "RATES CUT! BULL RUN!", "bull"],
	["RUMOR: SELL-OFF STARTING OVERSEAS", "FLASH CRASH! EVERYTHING DOWN!", "crash"],
]
const DENIED := "RUMOR DENIED. NOTHING HAPPENS."
const QUIET := ["MARKETS STEADY", "TRADERS BREAK FOR LUNCH", "SMOOTHIE MACHINE STOCK UNLISTED", "ANALYSTS SAY: NUMBERS", "KEV SAYS HI"]
const DAY_NAMES := ["MON", "TUE", "WED", "THU", "FRI"]
## Shown when you're off the floor: what the floor teaches.
const LESSONS := [
	"ROCKETS CRASH. SELL WHILE IT'S STILL CLIMBING.",
	"WAVES COME BACK. BUY LOW ON THE WAVE, SELL HIGH.",
	"A SPIKY STOCK SNAPS BACK. SHORT THE JUMP, BUY THE DROP.",
	"A RUMOR HAS A COUNTDOWN. GET IN BEFORE IT HITS.",
	"ONE IN FOUR RUMORS IS FAKE. DON'T BET IT ALL.",
	"SELL ON THE NEWS. THE POP DOESN'T LAST.",
	"A FLASH CRASH BOUNCES BACK. BUY IT.",
	"PROFITS IN A ROW BUILD THE HOT HAND. SMALL WINS COUNT.",
	"THE BELL SELLS EVERYTHING. DON'T BE HOLDING A LOSER.",
	"25% ORDERS LET YOU TRY A STOCK WITHOUT BETTING IT ALL.",
]

## A week is five trading days; clear Friday and you've doubled your money.
const DAYS := 5
const DAY_SECONDS := 30.0
const TICK := 0.25
const HISTORY := 180
## Each day's goal: grow what you had at the last bell by this much (spending
## in the shop doesn't lower it). Every week after the first adds WEEK_STEP.
const GOALS := [0.08, 0.11, 0.14, 0.17, 0.20]
const WEEK_STEP := 0.08
## A rumor shows this many seconds before its news hits.
const RUMOR_LEAD := 4.0
## Stock news per day, and the chance a rumor is fake.
const EVENTS_PER_DAY := 2
const FAKE_CHANCE := 0.25
## Every trade pays this share of its value (the spread).
const FEE := 0.005
## Profitable closes in a row: each one past the first pays this much of the
## profit again, up to the cap.
const STREAK_BONUS := 0.12
const STREAK_CAP := 6
## Ticks of price generated ahead (the crystal ball shows them).
const LOOKAHEAD := 10
## Order sizes: share of your buying power.
const STAKES := [0.25, 0.5, 1.0]

## The after-hours shop. cost = share of the week's starting cash.
const PERKS := {
	"short": {"name": "SHORT LICENSE", "text": "SELL WHAT YOU DON'T OWN. PROFIT WHEN IT DROPS.", "cost": 0.05},
	"stop": {"name": "STOP-LOSS", "text": "AUTO-SELLS A TRADE THAT FALLS 6%.", "cost": 0.04},
	"take": {"name": "TAKE-PROFIT", "text": "AUTO-SELLS A TRADE UP 15%.", "cost": 0.04},
	"crystal": {"name": "CRYSTAL BALL", "text": "SEE THE NEXT 2 SECONDS OF EVERY CHART.", "cost": 0.12},
	"fact": {"name": "FACT CHECKER", "text": "FAKE RUMORS ARE MARKED FAKE.", "cost": 0.06},
	"margin": {"name": "MARGIN ACCOUNT", "text": "TRADE WITH 2X YOUR MONEY. LOSSES 2X TOO.", "cost": 0.08},
	"hot": {"name": "HOT HANDS", "text": "STREAK BONUSES COUNT DOUBLE.", "cost": 0.06},
	"zero": {"name": "ZERO COMMISSION", "text": "NO FEES ON TRADES.", "cost": 0.04},
	"overtime": {"name": "LONGER DAYS", "text": "+10 SECONDS OF TRADING EVERY DAY.", "cost": 0.05},
	"early": {"name": "RUMOR MILL", "text": "RUMORS ARRIVE 3 SECONDS EARLIER.", "cost": 0.05},
	"bond": {"name": "SAVINGS BOND", "text": "+4% ON YOUR CASH EVERY MORNING.", "cost": 0.07},
	"hedge": {"name": "HEDGE FUND", "text": "YOUR FIRST LOSS EACH DAY DOESN'T BREAK THE STREAK.", "cost": 0.04},
	"insurance": {"name": "BAG INSURANCE", "text": "GET BACK 30% OF EVERY LOSING TRADE.", "cost": 0.07},
	"parachute": {"name": "GOLDEN PARACHUTE", "text": "MISS ONE DAY'S GOAL AND KEEP TRADING.", "cost": 0.09},
	"insider": {"name": "KEV'S HOTLINE", "text": "A STAR ON EACH DAY'S BIGGEST POP.", "cost": 0.08},
}
const SHOP_SIZE := 3
const REROLL_COST := 0.02

var start_cash := 0.0
var cash := 0.0
var prices := {}
## Shares held per stock: positive = long, negative = short.
var shares := {}
## Average price of the open position per stock.
var entry := {}
var history := {}
## Prices still to come per stock (the crystal ball).
var future := {}
## Where you opened and closed trades this day: {sym: [[tick, "buy"/"sell"]]}.
var marks := {}
var day := 1
var week := 1
var clock := 0.0
var headline := ""
## "trading", "shop" (between days), "over".
var phase := "trading"
var over := false
## Cleared Friday this run (the trading floor's milestone).
var won := false
## Days cleared this run.
var cleared := 0
var perks: Array[String] = []
var shop: Array[String] = []
var streak := 0
var best_streak := 0
var best_trade := 0.0
var trades := 0
## The stock with today's biggest pop (Kev's hotline), or "".
var tip := ""
## Halted stocks: sym -> seconds left.
var halted := {}
## Scheduled moves for the day: {at, sym ("ALL" = everyone), move, kind,
## rumor, news, fake, teased, hit}.
var events: Array = []
## What the last close paid: {sym, profit, bonus, streak}.
var last_close := {}
## Net worth when the day opened.
var day_open_worth := 0.0
## Worth at the last bell, before the shop: today's goal grows from it.
var base_worth := 0.0
## The bell's report: {day, worth, goal, cleared, saved}.
var report := {}
var parachute_used := false

var _rng := RandomNumberGenerator.new()
var _acc := 0.0
var _tick := 0
var _gen_tick := 0
var _st := {}
var _hedge_used := false


func _init(start: float, rng_seed := -1, insider := false) -> void:
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	start_cash = start
	cash = start
	base_worth = start
	if insider:
		perks.append("insider")
	for s in STOCKS:
		prices[s.sym] = s.price
		shares[s.sym] = 0
		entry[s.sym] = 0.0
		history[s.sym] = [s.price]
		_st[s.sym] = {"p": s.price, "anchor": s.price, "ret": 0.0, "mode": "climb", "mode_t": _rng.randi_range(12, 24),
			"climb": 0.006, "wave_at": _rng.randf() * TAU, "wave_len": _rng.randf_range(32.0, 48.0), "spike": 0.0, "bull": 0, "recover": 0.0}
	_open_day()


static func stock(sym: String) -> Dictionary:
	for s in STOCKS:
		if s.sym == sym:
			return s
	return {}


func has_perk(id: String) -> bool:
	return perks.has(id)


func day_name() -> String:
	return DAY_NAMES[(day - 1) % DAY_NAMES.size()]


func day_seconds() -> float:
	return DAY_SECONDS + (10.0 if has_perk("overtime") else 0.0)


## Today's goal as a share (0.1 = +10%).
func goal_pct() -> float:
	return GOALS[(day - 1) % DAYS] + WEEK_STEP * (week - 1)


## Today's goal in dollars: be worth this at the bell.
func goal() -> float:
	return base_worth * (1.0 + goal_pct())


## Ticks in a trading day (the chart's width).
func day_ticks() -> int:
	return int(round(day_seconds() / TICK))


## The pending rumor on a stock (teased, not hit yet), or {}.
func rumor_on(sym: String) -> Dictionary:
	for ev in events:
		if ev.teased and not ev.hit and ev.kind != "halt" and (ev.sym == sym or ev.sym == "ALL"):
			return ev
	return {}


func seconds_left() -> float:
	return maxf(0.0, day_seconds() - clock)


# ---------------------------------------------------------------- the day

func _open_day() -> void:
	phase = "trading"
	clock = 0.0
	_acc = 0.0
	_tick = 0
	_gen_tick = 0
	_hedge_used = false
	halted.clear()
	if has_perk("bond") and cash > 0.0:
		cash *= 1.04
	for s in STOCKS:
		history[s.sym] = [prices[s.sym]]
		future[s.sym] = []
		marks[s.sym] = []
		_st[s.sym].p = prices[s.sym]
		_st[s.sym].bull = 0
		_st[s.sym].recover = 0.0
	_schedule()
	for i in LOOKAHEAD:
		_generate()
	day_open_worth = net_worth()
	headline = "%s OPENING BELL. GOAL: $%d" % [day_name(), int(goal())]


func _schedule() -> void:
	events.clear()
	var span := day_seconds()
	var syms: Array = []
	for s in STOCKS:
		syms.append(s.sym)
	var n := EVENTS_PER_DAY + (1 if day >= 2 or week > 1 else 0)
	var biggest := -1.0
	tip = ""
	var market_i := _rng.randi_range(0, n - 1) if n > EVENTS_PER_DAY else -1
	for i in n:
		var at := span * (0.15 + 0.75 * (i + _rng.randf_range(0.1, 0.9)) / n)
		var ev := {"at": at, "teased": false, "hit": false, "fake": false}
		if i == market_i:
			# The day's whole-market move.
			var mk: Array = MARKET_NEWS[_rng.randi_range(0, MARKET_NEWS.size() - 1)]
			ev.merge({"sym": "ALL", "kind": mk[2], "move": 1.0, "rumor": mk[0], "news": mk[1]})
		else:
			var up := _rng.randf() < 0.6
			var sym: String = syms[_rng.randi_range(0, syms.size() - 1)]
			var pool: Array = UP_NEWS if up else DOWN_NEWS
			var lines: Array = pool[_rng.randi_range(0, pool.size() - 1)]
			var move := _rng.randf_range(1.12, 1.26) if up else _rng.randf_range(0.76, 0.88)
			ev.merge({"sym": sym, "kind": "news", "move": move, "rumor": lines[0] % stock(sym).name,
				"news": lines[1] % stock(sym).name, "fake": _rng.randf() < FAKE_CHANCE})
			if up and not ev.fake and move > biggest:
				biggest = move
				if has_perk("insider"):
					tip = sym
		events.append(ev)
	# A trading halt on a random stock, some days.
	if _rng.randf() < 0.35:
		events.append({"at": span * _rng.randf_range(0.3, 0.8), "sym": syms[_rng.randi_range(0, syms.size() - 1)], "kind": "halt",
			"move": 1.0, "rumor": "", "news": "", "fake": false, "teased": true, "hit": false})
	events.sort_custom(func(a, b): return a.at < b.at)
	for ev in events:
		ev.tick = int(round(ev.at / TICK))
		var halt_name: String = stock(ev.sym).get("name", "")
		if ev.kind == "halt":
			ev.news = "TRADING HALTED: %s" % halt_name


func rumor_lead() -> float:
	return RUMOR_LEAD + (3.0 if has_perk("early") else 0.0)


## Advance the clock. Returns what happened: "rumor", "news", "denied",
## "halt", "stop" (stop-loss / take-profit fired), "bell" (the day closed;
## see report), "won" (cleared Friday), "fired" (missed the goal: run over),
## "wiped" (lost everything).
func tick(dt: float) -> Array[String]:
	var out: Array[String] = []
	if phase != "trading":
		return out
	_acc += dt
	while _acc >= TICK and phase == "trading":
		_acc -= TICK
		_tick += 1
		clock += TICK
		for sym in halted.keys():
			halted[sym] -= TICK
			if halted[sym] <= 0.0:
				halted.erase(sym)
		for ev in events:
			if not ev.teased and clock >= ev.at - rumor_lead():
				ev.teased = true
				headline = ev.rumor + ("  (FAKE)" if ev.fake and has_perk("fact") else "")
				out.append("rumor")
			if not ev.hit and _tick >= ev.tick:
				ev.hit = true
				if ev.kind == "halt":
					halted[ev.sym] = 3.0
					headline = ev.news
					out.append("halt")
				elif ev.fake:
					headline = DENIED
					out.append("denied")
				else:
					headline = ev.news
					if ev.sym != "ALL":
						headline += "  %s %+d%%" % [ev.sym, roundi((ev.move - 1.0) * 100.0)]
					out.append("news")
		_generate()
		for s in STOCKS:
			var h: Array = history[s.sym]
			var f: Array = future[s.sym]
			prices[s.sym] = f.pop_front()
			h.append(prices[s.sym])
			if h.size() > HISTORY:
				h.pop_front()
		if _auto_close():
			out.append("stop")
		if net_worth() <= 0.0:
			_end_day(out)
			out.append("wiped")
			break
		if clock >= day_seconds():
			_end_day(out)
			break
	return out


## Stop-loss and take-profit, checked every tick.
func _auto_close() -> bool:
	var fired := false
	for s in STOCKS:
		var n: int = shares[s.sym]
		if n == 0 or halted.has(s.sym):
			continue
		var gain := position_gain(s.sym)
		if (has_perk("stop") and gain <= -0.06) or (has_perk("take") and gain >= 0.15):
			close(s.sym)
			fired = true
	return fired


func _end_day(out: Array[String]) -> void:
	for s in STOCKS:
		if shares[s.sym] != 0:
			_close(s.sym, true)
	var worth := net_worth()
	var made := worth >= goal()
	var saved := false
	if not made and worth > 0.0 and has_perk("parachute") and not parachute_used:
		parachute_used = true
		saved = true
	report = {"day": day_name(), "worth": worth, "goal": goal(), "cleared": made, "saved": saved, "made": worth - day_open_worth}
	if made:
		cleared += 1
	if made or saved:
		base_worth = worth
		var friday := day % DAYS == 0
		if friday and made and not won:
			won = true
			out.append("won")
		phase = "shop"
		out.append("bell")
		_roll_shop()
	else:
		phase = "over"
		over = true
		out.append("bell")
		out.append("fired")


## Leave the shop: the next day opens.
func next_day() -> void:
	if phase != "shop":
		return
	day += 1
	if day > DAYS:
		day = 1
		week += 1
	# Overnight, prices gap a little.
	for s in STOCKS:
		var gap := _rng.randf_range(0.95, 1.05)
		prices[s.sym] = maxf(0.5, prices[s.sym] * gap)
		_st[s.sym].anchor *= gap
	_open_day()


# ---------------------------------------------------------------- prices

## One more tick of prices, LOOKAHEAD ahead of the clock.
func _generate() -> void:
	_gen_tick += 1
	var k := _gen_tick
	for s in STOCKS:
		var st: Dictionary = _st[s.sym]
		var r := 0.0
		var vol: float = s.vol
		var frozen := false
		# News jumps move the stock and the level it swings around.
		var shock := 1.0
		for ev in events:
			if ev.tick == k and not ev.fake:
				if ev.kind == "news" and ev.sym == s.sym:
					shock *= ev.move
				elif ev.kind == "bull" and ev.sym == "ALL":
					st.bull = 16
				elif ev.kind == "crash" and ev.sym == "ALL":
					shock *= _rng.randf_range(0.72, 0.8)
					st.recover = 0.15
			if ev.kind == "halt" and ev.sym == s.sym and k >= ev.tick and k < ev.tick + int(3.0 / TICK):
				frozen = true
		var p: float = st.p * shock
		st.anchor *= shock
		if frozen:
			st.p = p
			future[s.sym].append(p)
			continue
		match s.kind:
			"STEADY":
				r = 0.0005 + _rng.randfn(0.0, vol)
			"WAVE":
				# The price swings around an anchor that wanders slowly.
				st.anchor *= 1.0 + _rng.randfn(0.0004, 0.002)
				var t: float = float(k) / st.wave_len * TAU + st.wave_at
				var want: float = st.anchor * (1.0 + 0.09 * sin(t))
				r = log(maxf(0.01, want) / p) * 0.5 + _rng.randfn(0.0, vol)
			"ROCKET":
				st.mode_t -= 1
				if st.mode == "climb":
					st.climb *= 1.07
					r = st.climb + _rng.randfn(0.0, vol)
					if st.mode_t <= 0:
						st.mode = "crash"
						st.mode_t = _rng.randi_range(4, 7)
				elif st.mode == "crash":
					r = -0.055 + _rng.randfn(0.0, vol)
					if st.mode_t <= 0:
						st.mode = "flat"
						st.mode_t = _rng.randi_range(8, 16)
				else:
					r = _rng.randfn(0.0, vol)
					if st.mode_t <= 0:
						st.mode = "climb"
						st.climb = _rng.randf_range(0.004, 0.008)
						st.mode_t = _rng.randi_range(14, 26)
			"SPIKY":
				# Snaps back toward its anchor; now and then it jumps.
				r = log(st.anchor / p) * 0.09 + _rng.randfn(0.0, vol)
				if _rng.randf() < 0.035:
					r += (1.0 if _rng.randf() < 0.55 else -1.0) * _rng.randf_range(0.14, 0.24)
				st.anchor *= 1.0 + _rng.randfn(0.0006, 0.002)
			"MEME":
				r = st.ret * 0.55 + _rng.randfn(0.0004, vol)
		var push := 0.0
		if st.bull > 0:
			st.bull -= 1
			push += 0.012
		if st.recover > 0.0:
			push += 0.015
			st.recover -= 0.015
		r = clampf(r + push, -0.3, 0.3)
		st.ret = r
		st.anchor *= exp(push)
		p = clampf(p * exp(r), 0.5, 99999.0)
		st.p = p
		future[s.sym].append(p)


# ---------------------------------------------------------------- trading

func net_worth() -> float:
	var w := cash
	for sym in shares:
		w += shares[sym] * prices[sym]
	return w


## Value of every open position, long or short.
func exposure() -> float:
	var e := 0.0
	for sym in shares:
		e += absf(shares[sym]) * prices[sym]
	return e


func leverage() -> float:
	return 2.0 if has_perk("margin") else 1.0


## Dollars you can still put into new trades.
func buying_power() -> float:
	return maxf(0.0, net_worth() * leverage() - exposure())


func fee_rate() -> float:
	return 0.0 if has_perk("zero") else FEE


func can_trade(sym: String) -> bool:
	return phase == "trading" and not halted.has(sym)


## Shares a stake (share of buying power) buys or shorts right now.
func order_size(sym: String, stake: float) -> int:
	return int(floor(buying_power() * clampf(stake, 0.0, 1.0) / (prices[sym] * (1.0 + fee_rate()))))


## Open (or add to) a long position. Covers a short first.
func buy(sym: String, stake := 1.0) -> int:
	if not can_trade(sym):
		return 0
	if shares[sym] < 0:
		return close(sym)
	var n := order_size(sym, stake)
	if n <= 0:
		return 0
	_fill(sym, n)
	return n


## Sell a long position; with the license, a flat stock opens a short.
func sell(sym: String, stake := 1.0) -> int:
	if not can_trade(sym):
		return 0
	if shares[sym] > 0:
		return close(sym)
	if not has_perk("short"):
		return 0
	var n := order_size(sym, stake)
	if n <= 0:
		return 0
	_fill(sym, -n)
	return n


func _fill(sym: String, n: int) -> void:
	var p: float = prices[sym]
	var held: int = shares[sym]
	entry[sym] = (entry[sym] * absf(held) + p * absf(n)) / absf(held + n)
	shares[sym] = held + n
	cash -= n * p + absf(n) * p * fee_rate()
	trades += 1
	marks[sym].append([_tick, "buy" if n > 0 else "short"])


## Close the whole position on a stock. Returns the shares closed.
func close(sym: String) -> int:
	if not can_trade(sym) or shares[sym] == 0:
		return 0
	return _close(sym, false)


func _close(sym: String, at_bell: bool) -> int:
	var n: int = shares[sym]
	var p: float = prices[sym]
	cash += n * p - absf(n) * p * fee_rate()
	var profit: float = (p - entry[sym]) * n - absf(n) * (p + entry[sym]) * fee_rate()
	shares[sym] = 0
	entry[sym] = 0.0
	marks[sym].append([_tick, "sell"])
	var bonus := 0.0
	if profit > 0.0:
		streak += 1
		best_streak = maxi(best_streak, streak)
		bonus = profit * STREAK_BONUS * mini(streak - 1, STREAK_CAP - 1) * (2.0 if has_perk("hot") else 1.0)
		cash += bonus
		best_trade = maxf(best_trade, profit + bonus)
	else:
		if has_perk("insurance"):
			cash += -profit * 0.3
		if has_perk("hedge") and not _hedge_used:
			_hedge_used = true
		else:
			streak = 0
	last_close = {"sym": sym, "profit": profit, "bonus": bonus, "streak": streak, "bell": at_bell}
	return absi(n)


## Gain on the open position as a share (0.1 = +10%), shorts included.
func position_gain(sym: String) -> float:
	var n: int = shares[sym]
	if n == 0 or entry[sym] <= 0.0:
		return 0.0
	var g: float = prices[sym] / entry[sym] - 1.0
	return g if n > 0 else -g


## The tick the clock is on (marks are stamped with it); the last history
## entry is this tick.
func now_tick() -> int:
	return _tick


func position_profit(sym: String) -> float:
	return (prices[sym] - entry[sym]) * shares[sym]


## Change since the start of the visible chart, as a share (0.1 = +10%).
func change(sym: String) -> float:
	var h: Array = history[sym]
	return prices[sym] / maxf(0.01, h[0]) - 1.0


# ---------------------------------------------------------------- shop

func perk_cost(id: String) -> int:
	return int(round(base_worth * PERKS[id].cost))


func reroll_cost() -> int:
	return int(round(base_worth * REROLL_COST))


func _roll_shop() -> void:
	var pool: Array = []
	for id in PERKS:
		if not perks.has(id) and not (id == "parachute" and parachute_used):
			pool.append(id)
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	# Shorting is the big one: it shows up on the first night.
	if day == 1 and week == 1 and pool.has("short"):
		pool.erase("short")
		pool.push_front("short")
	shop.clear()
	for id in pool.slice(0, SHOP_SIZE):
		shop.append(id)


func buy_perk(id: String) -> bool:
	if phase != "shop" or not shop.has(id) or cash < perk_cost(id):
		return false
	cash -= perk_cost(id)
	perks.append(id)
	shop.erase(id)
	return true


func reroll() -> bool:
	if phase != "shop" or cash < reroll_cost():
		return false
	cash -= reroll_cost()
	_roll_shop()
	return true
