extends SceneTree
## Plays the trading floor with bots of three skill levels and prints how far
## a week gets (days cleared) and how often Friday is cleared.
##   godot --headless -s res://addons/hh_minigames/trading/tools/market_tune.gd
## idle   = never trades (should miss Monday)
## rumor  = trades every rumor blind (fakes included), buys nothing
## good   = reads rumors, swings the WAVE, rides ROCKET climbs, buys perks;
##          reacts half a second late like a person
## Aim: idle 0%, rumor ~10-30% Friday, good ~55-80%.

var RUNS := int(OS.get_environment("RUNS")) if OS.get_environment("RUNS") != "" else 300


func _init() -> void:
	for kind in ["idle", "rumor", "good"]:
		var days := {}
		var fridays := 0
		var week2 := 0
		for i in RUNS:
			var m := Market.new(1000.0, 1000 + i)
			var done := _play(m, kind)
			days[done] = days.get(done, 0) + 1
			if m.won:
				fridays += 1
			if done >= 6:
				week2 += 1
		var keys := days.keys()
		keys.sort()
		var parts: Array[String] = []
		for k in keys:
			parts.append("%d:%d" % [k, days[k]])
		print("%-6s friday %3d%%  into week 2 %3d%%  days cleared {%s}" % [kind, 100 * fridays / RUNS, 100 * week2 / RUNS, ", ".join(parts)])
	quit()


func _play(m: Market, kind: String) -> int:
	var hold := {}
	var guard := 0
	while not m.over and m.cleared < 8 and guard < 100000:
		guard += 1
		if m.phase == "shop":
			if kind == "good":
				_shop(m)
			m.next_day()
			continue
		m.tick(Market.TICK)
		if kind == "idle" or m.phase != "trading":
			continue
		for ev in m.events:
			if ev.kind != "news" or not ev.teased or ev.hit:
				continue
			var lead: float = ev.at - m.clock
			var late := kind == "good" and lead > m.rumor_lead() - 0.5
			if late:
				continue
			if ev.fake and kind == "good" and m.has_perk("fact"):
				continue
			if ev.move > 1.0 and m.shares[ev.sym] == 0:
				m.buy(ev.sym, 1.0 if kind == "rumor" else 0.6)
				hold[ev.sym] = ev
			elif ev.move < 1.0 and m.shares[ev.sym] > 0:
				m.close(ev.sym)
			elif ev.move < 1.0 and m.has_perk("short") and m.shares[ev.sym] == 0:
				m.sell(ev.sym, 0.6)
				hold[ev.sym] = ev
		for sym in hold.keys():
			if hold[sym].hit:
				m.close(sym)
				hold.erase(sym)
		if kind == "good":
			_patterns(m, hold)
	return m.cleared


## Swing the WAVE and ride ROCKET climbs, a little late.
func _patterns(m: Market, hold: Dictionary) -> void:
	for sym in ["PRF", "BRCK"]:
		if hold.has(sym):
			continue
		var h: Array = m.history[sym]
		if h.size() < 6:
			continue
		var a: float = h[h.size() - 6]
		var b: float = h[h.size() - 3]
		var c: float = h[h.size() - 1]
		var n: int = m.shares[sym]
		if sym == "PRF":
			# Turned up after a fall: buy. Turned down after a rise: sell.
			if n == 0 and b < a * 0.98 and c > b * 1.01:
				m.buy(sym, 0.4)
			elif n > 0 and (m.position_gain(sym) > 0.08 or (c < b and m.position_gain(sym) > 0.02)):
				m.close(sym)
		else:
			if n == 0 and c > b * 1.02 and b > a * 1.01:
				m.buy(sym, 0.3)
			elif n > 0 and (c < b or m.position_gain(sym) > 0.15):
				m.close(sym)


func _shop(m: Market) -> void:
	var margin := m.cash - m.goal()
	for want in ["short", "stop", "fact", "early", "hot", "zero", "bond"]:
		if m.shop.has(want) and margin > m.perk_cost(want) * 1.5:
			if m.buy_perk(want):
				margin -= m.perk_cost(want)
