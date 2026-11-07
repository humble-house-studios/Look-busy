extends GutTest
## The trading floor: rumors, the bell, the shop, a week you can clear.


func _run_day(m: Market) -> Array[String]:
	var all: Array[String] = []
	while m.phase == "trading":
		all.append_array(m.tick(Market.TICK))
	return all


func test_market_rumor_comes_before_its_news() -> void:
	var m := Market.new(1000.0, 7)
	m.cash = 1e9  # never fired: trade every day
	var teased := {}
	var order_ok := true
	var saw := 0
	for d in 4:
		for i in 400:
			for e in m.tick(Market.TICK):
				if e == "rumor":
					saw += 1
			for ev in m.events:
				if ev.teased:
					teased[ev] = true
				if ev.hit and ev.kind != "halt" and not teased.has(ev):
					order_ok = false
			if m.phase != "trading":
				break
		m.next_day()
	assert_gt(saw, 4)
	assert_true(order_ok, "every news item was teased first")


func test_market_holding_cash_misses_monday() -> void:
	var m := Market.new(1000.0, 3)
	var evs := _run_day(m)
	assert_has(evs, "bell")
	assert_has(evs, "fired")
	assert_true(m.over)
	assert_false(m.won)


func test_market_bell_closes_every_trade() -> void:
	var m := Market.new(1000.0, 4)
	m.buy("HHG", 0.5)
	assert_gt(m.shares["HHG"], 0)
	_run_day(m)
	for sym in m.shares:
		assert_eq(m.shares[sym], 0, sym)
	assert_almost_eq(m.net_worth(), m.cash, 0.001)


func test_market_buy_and_sell_pay_the_fee() -> void:
	var m := Market.new(1000.0, 1)
	var n := m.buy("HHG", 1.0)
	assert_gt(n, 0)
	var p: float = m.prices["HHG"]
	assert_almost_eq(m.cash, 1000.0 - n * p * (1.0 + Market.FEE), 0.01)
	assert_eq(m.sell("HHG"), n)
	assert_almost_eq(m.cash, 1000.0 - n * p * Market.FEE * 2.0, 0.01, "round trip costs two fees")
	assert_eq(m.sell("HHG"), 0, "no shorting without the license")


func test_market_short_profits_when_it_drops() -> void:
	var m := Market.new(1000.0, 1)
	m.perks.append("short")
	var n := m.sell("PRZ", 0.5)
	assert_gt(n, 0)
	assert_lt(m.shares["PRZ"], 0)
	m.prices["PRZ"] *= 0.8
	assert_gt(m.position_profit("PRZ"), 0.0)
	var before := m.net_worth()
	assert_eq(m.buy("PRZ"), n, "BUY covers the short")
	assert_eq(m.shares["PRZ"], 0)
	assert_gt(m.cash, 1000.0)
	assert_almost_eq(m.cash, before - n * m.prices["PRZ"] * Market.FEE, 0.01)


func test_market_margin_doubles_buying_power() -> void:
	var m := Market.new(1000.0, 1)
	assert_almost_eq(m.buying_power(), 1000.0, 0.01)
	m.perks.append("margin")
	assert_almost_eq(m.buying_power(), 2000.0, 0.01)


func test_market_stop_loss_sells_a_falling_trade() -> void:
	var m := Market.new(1000.0, 2)
	m.perks.append("stop")
	m.buy("PRZ", 1.0)
	for sym in m.future:
		pass
	var f: Array = m.future["PRZ"]
	for i in f.size():
		f[i] = m.prices["PRZ"] * 0.8
	var evs := m.tick(Market.TICK)
	assert_has(evs, "stop")
	assert_eq(m.shares["PRZ"], 0)


func test_market_hot_hand_pays_a_streak_bonus() -> void:
	var m := Market.new(1000.0, 2)
	for i in 3:
		m.buy("HHG", 0.5)
		m.prices["HHG"] *= 1.1
		m.close("HHG")
	assert_eq(m.streak, 3)
	assert_gt(m.last_close.bonus, 0.0)
	m.buy("HHG", 0.5)
	m.prices["HHG"] *= 0.9
	m.close("HHG")
	assert_eq(m.streak, 0, "a losing trade ends the streak")


func test_market_shop_costs_cash_not_the_goal() -> void:
	var m := Market.new(1000.0, 5)
	m.cash = 2000.0
	_run_day(m)
	assert_eq(m.phase, "shop")
	assert_eq(m.shop.size(), Market.SHOP_SIZE)
	assert_has(m.shop, "short", "the short license shows up on the first night")
	var goal_before := m.base_worth * (1.0 + Market.GOALS[1])
	var cost := m.perk_cost("short")
	assert_true(m.buy_perk("short"))
	assert_almost_eq(m.cash, 2000.0 - cost, 0.01)
	m.next_day()
	assert_eq(m.day, 2)
	assert_almost_eq(m.goal(), goal_before, 0.01, "spending doesn't lower the goal")


func test_market_crystal_ball_shows_the_real_future() -> void:
	var m := Market.new(1000.0, 9)
	var ahead: Array = m.future["LOOT"].duplicate()
	for i in 4:
		m.tick(Market.TICK)
		assert_almost_eq(float(m.prices["LOOT"]), float(ahead[i]), 0.0001)


func test_market_clearing_friday_wins() -> void:
	var m := Market.new(1000.0, 6)
	for d in Market.DAYS:
		m.cash = m.goal() * 1.01
		var evs := _run_day(m)
		assert_has(evs, "bell")
		if d == Market.DAYS - 1:
			assert_has(evs, "won")
		m.next_day()
	assert_true(m.won)
	assert_eq(m.cleared, Market.DAYS)
	assert_eq(m.week, 2)
	assert_almost_eq(m.goal_pct(), Market.GOALS[0] + Market.WEEK_STEP, 0.0001, "week 2 is harder")


func test_market_golden_parachute_saves_one_day() -> void:
	var m := Market.new(1000.0, 3)
	m.perks.append("parachute")
	var evs := _run_day(m)
	assert_does_not_have(evs, "fired")
	assert_eq(m.phase, "shop")
	m.next_day()
	evs = _run_day(m)
	assert_has(evs, "fired", "only once")


func test_insider_tip_stars_the_biggest_pop() -> void:
	for s in 10:
		var m := Market.new(1000.0, s, true)
		var best := ""
		var big := 1.0
		for ev in m.events:
			if ev.kind == "news" and not ev.fake and ev.move > big:
				big = ev.move
				best = ev.sym
		assert_eq(m.tip, best)


func test_market_rumor_traders_clear_monday_often() -> void:
	var wins := 0
	for s in 40:
		var m := Market.new(1000.0, 100 + s)
		var hold := ""
		while m.phase == "trading":
			m.tick(Market.TICK)
			for ev in m.events:
				if ev.kind == "news" and ev.teased and not ev.hit and ev.move > 1.0 and hold == "":
					m.buy(ev.sym, 1.0)
					hold = ev.sym
				if hold == ev.sym and ev.hit:
					m.close(hold)
					hold = ""
		if m.phase == "shop":
			wins += 1
	assert_between(wins, 10, 36, "trading rumors clears Monday often, not always (%d/40)" % wins)
