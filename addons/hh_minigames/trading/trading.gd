extends "res://addons/hh_minigames/_shared/machine.gd"
## The trading floor terminal: a trading week, live (rules in
## engine/market.gd). Five tabs, one per stock, each with a sparkline; the big
## chart runs from the opening bell (left) to the closing bell (right edge),
## with your entry line, the trade's profit shaded, buy/sell marks and, with
## the CRYSTAL BALL, the next two seconds dotted ahead. BUY / SELL are the
## two big buttons (SELL opens a short once you own the license; BUY covers
## it); the stake row sets how much of your buying power an order uses. Every
## day has a goal bar; the bell closes every trade, then the after-hours shop
## sells perks. Clearing Friday opens the boardroom elevator; the record
## (most days cleared in one run) is the desk's stars. The clock only runs
## while you sit here.

const GREEN := Color(0.4, 1.0, 0.5)
const RED := Color(1.0, 0.42, 0.38)
const GOLD := Color(1.0, 0.85, 0.3)
const DIM := Color(0.35, 1.0, 0.45, 0.6)

var market: Market
var _sel := "PRF"
var _stake := 1
var _tabs := {}
var _sparks := {}
var _desk: Control
var _shop: Control
var _intro: Control
var _status: Label
var _goal_bar: Control
var _chart: Control
var _tip: Label
var _pos: Label
var _perk_line: Label
var _ticker: Label
var _ticker_x := 0.0
var _buy_btn: Button
var _sell_btn: Button
var _stake_btns: Array[Button] = []
var _shop_title: Label
var _shop_report: Label
var _shop_cash: Label
var _shop_list: VBoxContainer
var _reroll_btn: Button
var _next_btn: Button
var _cashout_btn: Button
var _intro_text: Label
var _start_btn: Button
## Floating "+$37" pops: [label, seconds left].
var _pops: Array = []
var _shake := 0.0
var _flash := 0.0
var _flash_color := GREEN
var _last_second := -1
var _time := 0.0


func _ready() -> void:
	super._ready()
	frame("TRADING FLOOR", Color(0.02, 0.05, 0.03), Color(0.35, 1.0, 0.45))
	_build_desk()
	_build_shop()
	_build_intro()
	_show("intro")
	_refresh()


# ---------------------------------------------------------------- build

func _build_desk() -> void:
	_desk = Control.new()
	_desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(full(_desk))
	_status = label("", 22, GREEN, HORIZONTAL_ALIGNMENT_LEFT)
	_status.position = Vector2(20, 140)
	_status.size = Vector2(W - 40, 30)
	_desk.add_child(_status)
	_goal_bar = Control.new()
	_goal_bar.position = Vector2(20, 176)
	_goal_bar.size = Vector2(W - 40, 56)
	_goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_bar.draw.connect(_draw_goal)
	_desk.add_child(_goal_bar)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(20, 244)
	tabs.size = Vector2(W - 40, 112)
	tabs.add_theme_constant_override("separation", 8)
	_desk.add_child(tabs)
	for s in Market.STOCKS:
		var b := button("", 16, Color(0.04, 0.14, 0.07), DIM)
		b.custom_minimum_size = Vector2(0, 112)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			_sel = s.sym
			sfx("click", -8.0)
			_refresh())
		tabs.add_child(b)
		_tabs[s.sym] = b
		var spark := Control.new()
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		spark.offset_top = -34
		spark.offset_bottom = -8
		spark.offset_left = 8
		spark.offset_right = -8
		spark.draw.connect(_draw_spark.bind(spark, s.sym))
		b.add_child(spark)
		_sparks[s.sym] = spark
	_chart = Control.new()
	_chart.position = Vector2(20, 368)
	_chart.size = Vector2(W - 40, 400)
	_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chart.draw.connect(_draw_chart)
	_desk.add_child(_chart)
	_tip = label("", 14, Color(0.6, 1.0, 0.65, 0.8))
	_tip.position = Vector2(20, 774)
	_tip.size = Vector2(W - 40, 24)
	_desk.add_child(_tip)
	_pos = label("", 22, Color.WHITE)
	_pos.position = Vector2(20, 804)
	_pos.size = Vector2(W - 40, 36)
	_desk.add_child(_pos)
	var strip := ColorRect.new()
	strip.color = Color(0.0, 0.0, 0.0)
	strip.position = Vector2(0, 846)
	strip.size = Vector2(W, 46)
	strip.clip_contents = true
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desk.add_child(strip)
	_ticker = label("", 22, Color(1.0, 0.75, 0.2), HORIZONTAL_ALIGNMENT_LEFT)
	_ticker.autowrap_mode = TextServer.AUTOWRAP_OFF
	_ticker.position = Vector2(W, 11)
	strip.add_child(_ticker)
	_perk_line = label("", 14, Color(0.45, 1.0, 0.95))
	_perk_line.position = Vector2(20, 900)
	_perk_line.size = Vector2(W - 40, 40)
	_desk.add_child(_perk_line)
	var row := HBoxContainer.new()
	row.position = Vector2(20, 946)
	row.size = Vector2(W - 40, 150)
	row.add_theme_constant_override("separation", 14)
	_desk.add_child(row)
	_buy_btn = button("BUY", 34, Color(0.05, 0.32, 0.1))
	_sell_btn = button("SELL", 34, Color(0.38, 0.08, 0.06))
	for b in [_buy_btn, _sell_btn]:
		b.custom_minimum_size = Vector2(0, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_buy_btn.pressed.connect(_buy)
	_sell_btn.pressed.connect(_sell)
	_buy_btn.set_meta("pad_default", true)
	var stakes := HBoxContainer.new()
	stakes.position = Vector2(20, 1108)
	stakes.size = Vector2(W - 40, 96)
	stakes.add_theme_constant_override("separation", 10)
	_desk.add_child(stakes)
	for i in Market.STAKES.size():
		var pct: float = Market.STAKES[i]
		var b := button("ALL IN" if pct >= 1.0 else "%d%%" % roundi(pct * 100.0), 22, Color(0.06, 0.16, 0.09), DIM)
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			_stake = i
			sfx("click", -8.0)
			_refresh())
		stakes.add_child(b)
		_stake_btns.append(b)


func _build_shop() -> void:
	_shop = Control.new()
	_shop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(full(_shop))
	_shop_title = label("", 30, GOLD)
	_shop_title.position = Vector2(20, 146)
	_shop_title.size = Vector2(W - 40, 100)
	_shop_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shop.add_child(_shop_title)
	_shop_report = label("", 18, Color(0.7, 1.0, 0.75))
	_shop_report.position = Vector2(20, 256)
	_shop_report.size = Vector2(W - 40, 120)
	_shop.add_child(_shop_report)
	_shop_cash = label("", 22, Color(0.45, 1.0, 0.95))
	_shop_cash.position = Vector2(20, 384)
	_shop_cash.size = Vector2(W - 40, 40)
	_shop.add_child(_shop_cash)
	_shop_list = VBoxContainer.new()
	_shop_list.position = Vector2(20, 432)
	_shop_list.size = Vector2(W - 40, 470)
	_shop_list.add_theme_constant_override("separation", 12)
	_shop.add_child(_shop_list)
	var row := HBoxContainer.new()
	row.position = Vector2(20, 910)
	row.size = Vector2(W - 40, 96)
	row.add_theme_constant_override("separation", 12)
	_shop.add_child(row)
	_reroll_btn = button("REROLL", 20, Color(0.12, 0.12, 0.3))
	_reroll_btn.custom_minimum_size = Vector2(0, 96)
	_reroll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reroll_btn.pressed.connect(_reroll)
	row.add_child(_reroll_btn)
	_cashout_btn = button("CASH OUT", 20, Color(0.3, 0.22, 0.05))
	_cashout_btn.custom_minimum_size = Vector2(0, 96)
	_cashout_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cashout_btn.pressed.connect(_cash_out)
	row.add_child(_cashout_btn)
	_next_btn = button("", 26, Color(0.05, 0.32, 0.1))
	_next_btn.position = Vector2(20, 1020)
	_next_btn.size = Vector2(W - 40, 170)
	_next_btn.pressed.connect(_next_day)
	_next_btn.set_meta("pad_default", true)
	_shop.add_child(_next_btn)


func _build_intro() -> void:
	_intro = Control.new()
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(full(_intro))
	_intro_text = label("", 20, Color(0.7, 1.0, 0.75))
	_intro_text.position = Vector2(30, 150)
	_intro_text.size = Vector2(W - 60, 820)
	_intro_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro.add_child(_intro_text)
	_start_btn = button("OPEN THE MARKET", 32, Color(0.1, 0.4, 0.15))
	_start_btn.position = Vector2(40, 1000)
	_start_btn.size = Vector2(W - 80, 180)
	_start_btn.pressed.connect(_open)
	_start_btn.set_meta("pad_default", true)
	_intro.add_child(_start_btn)


func _show(which: String) -> void:
	_desk.visible = which == "desk"
	_shop.visible = which == "shop"
	_intro.visible = which == "intro"


# ---------------------------------------------------------------- actions

func set_active(on: bool) -> void:
	super.set_active(on)
	_refresh()


func _open() -> void:
	var start: int = hub.state.market_start() if hub else Market.BASE_CASH
	market = Market.new(float(start), -1, hub != null and hub.state.has("insider_tip"))
	if market.tip != "":
		_sel = market.tip
	_stake = Market.STAKES.size() - 1
	_show("desk")
	sfx("ding")
	banner("MONDAY\nGOAL +%d%%" % roundi(market.goal_pct() * 100.0), 1.8, GREEN)
	_refresh()


func _buy() -> void:
	if market == null or market.phase != "trading":
		return
	if market.halted.has(_sel):
		_halted()
		return
	var covering: bool = market.shares[_sel] < 0
	var got := market.buy(_sel, Market.STAKES[_stake])
	if got <= 0:
		sfx("groan", -8.0)
		_pop("NO MONEY LEFT", RED)
	elif covering:
		_closed()
	else:
		sfx("coin", -6.0, 1.2)
		_pop("BOUGHT %d" % got, GREEN)
	_refresh()


func _sell() -> void:
	if market == null or market.phase != "trading":
		return
	if market.halted.has(_sel):
		_halted()
		return
	var closing: bool = market.shares[_sel] > 0
	var got := market.sell(_sel, Market.STAKES[_stake])
	if got <= 0:
		sfx("groan", -8.0)
		if not market.has_perk("short"):
			_pop("NEED A SHORT LICENSE", RED)
	elif closing:
		_closed()
	else:
		sfx("coin", -6.0, 0.85)
		_pop("SHORTED %d" % got, RED)
	_refresh()


func _halted() -> void:
	sfx("thump", -6.0)
	_pop("HALTED!", GOLD)


## A trade just closed: pay it out loud.
func _closed() -> void:
	var c := market.last_close
	if c.is_empty():
		return
	var profit: float = c.profit + c.bonus
	if c.profit > 0.0:
		sfx("chime", -4.0, 1.0 + 0.07 * mini(int(c.streak), 8))
		_pop("+$%d" % roundi(profit), GREEN, 40)
		if c.bonus > 0.0:
			_pop("HOT HAND x%d  +$%d" % [c.streak, roundi(c.bonus)], GOLD, 26, 60.0)
		if profit >= market.base_worth * 0.06:
			sfx("jackpot", -4.0)
			banner("TO THE MOON!", 1.4, GOLD)
		_flash_color = GREEN
	else:
		sfx("groan", -6.0)
		_pop("-$%d" % roundi(-profit), RED, 40)
		_flash_color = RED
	_flash = 0.5


func _next_day() -> void:
	if market == null:
		_open()
		return
	if market.phase == "over":
		_show("intro")
		market = null
		_refresh()
		return
	market.next_day()
	_show("desk")
	sfx("ding")
	banner("%s\nGOAL +%d%%" % [_day_word(), roundi(market.goal_pct() * 100.0)], 1.8, GREEN)
	_refresh()


func _cash_out() -> void:
	if market == null:
		return
	_record()
	sfx("applause", -6.0)
	market = null
	_show("intro")
	_refresh()


func _reroll() -> void:
	if market and market.reroll():
		sfx("card", -4.0)
	else:
		sfx("groan", -8.0)
	_refresh_shop()


func _buy_perk(id: String) -> void:
	if market and market.buy_perk(id):
		sfx("coin", -2.0)
		_pop("%s!" % Market.PERKS[id].name, Color(0.45, 1.0, 0.95), 26, 300.0)
	else:
		sfx("groan", -8.0)
	_refresh_shop()


## The run's record: most days cleared (the desk's stars).
func _record() -> void:
	if hub and market:
		hub.state.trading_record(market.cleared)


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	super._process(delta)
	_time += delta
	if market and active and market.phase == "trading":
		var evs := market.tick(delta)
		for e in evs:
			match e:
				"rumor":
					sfx("ding", -6.0, 1.3)
				"news":
					sfx("chime", -4.0)
					var ev := _last_hit()
					if ev.get("kind", "") == "crash":
						sfx("thump", 0.0)
						_shake = 0.6
						banner("FLASH CRASH!", 1.2, RED)
						_stress(Market.STRESS_CRASH)
					elif ev.get("kind", "") == "bull":
						sfx("cheer", -6.0)
						banner("BULL RUN!", 1.2, GREEN)
					elif ev.get("move", 1.0) < 1.0:
						_shake = 0.3
				"denied":
					sfx("groan", -10.0, 1.2)
				"halt":
					sfx("thump", -4.0)
				"stop":
					_closed()
				"bell":
					_bell()
				"wiped":
					banner("MARGIN CALL!", 2.0, RED)
		if market.phase == "trading":
			var s := int(ceil(market.seconds_left()))
			if s <= 5 and s != _last_second and s > 0:
				sfx("click", -2.0, 1.4)
			_last_second = s
		_refresh()
	_ticker_x -= delta * 150.0
	if _ticker.size.x > 0 and _ticker_x < -_ticker.size.x:
		_ticker_x = W
	_ticker.position.x = _ticker_x
	_shake = maxf(0.0, _shake - delta)
	_flash = maxf(0.0, _flash - delta)
	_chart.position = Vector2(20, 368) + (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * _shake if _shake > 0.0 else Vector2.ZERO)
	for i in range(_pops.size() - 1, -1, -1):
		var p: Array = _pops[i]
		p[1] -= delta
		var l: Label = p[0]
		l.position.y -= delta * 70.0
		l.modulate.a = clampf(p[1] * 1.5, 0.0, 1.0)
		if p[1] <= 0.0:
			l.queue_free()
			_pops.remove_at(i)
	if _desk.visible:
		for sym in _tabs:
			# A tab with a live rumor blinks.
			if market and not market.rumor_on(sym).is_empty() and market.rumor_on(sym).sym == sym:
				_tabs[sym].modulate = Color(1, 1, 0.6) if fmod(_time, 0.5) < 0.25 else Color.WHITE
			else:
				_tabs[sym].modulate = Color.WHITE


func _last_hit() -> Dictionary:
	var last := {}
	for ev in market.events:
		if ev.hit and ev.kind != "halt":
			last = ev
	return last


func _bell() -> void:
	var r := market.report
	_record()
	if market.won and hub and not hub.state.is_done("market"):
		hub.market_won()
	if r.cleared:
		sfx("applause", -4.0)
		sfx("ding", -2.0, 0.8)
	elif r.saved:
		sfx("chime", -2.0, 0.7)
	else:
		sfx("sad_trombone", -4.0)
	finish(int(r.made), "win" if r.cleared or r.saved else "lose", {"cleared": r.cleared, "won": market.won})
	if not r.cleared and not r.saved:
		_stress(Market.STRESS_FIRED)
	elif float(r.made) < 0.0:
		_stress(Market.STRESS_RED_DAY)
	_show("shop")
	_refresh_shop()


## A bad moment banks STRESS: free plays at the Rage Cage in the corner.
func _stress(n: int) -> void:
	if hub == null or not hub.has_method("add_stress"):
		return
	var got: int = hub.add_stress(n)
	if got > 0:
		_pop("+%d STRESS: FREE SWINGS AT THE RAGE CAGE" % got, Color(1.0, 0.45, 0.35), 20, 70.0)


func _day_word() -> String:
	var names := {"MON": "MONDAY", "TUE": "TUESDAY", "WED": "WEDNESDAY", "THU": "THURSDAY", "FRI": "FRIDAY"}
	return names.get(market.day_name(), market.day_name())


# ---------------------------------------------------------------- draw

func _pop(text: String, color: Color, font_size := 30, dy := 0.0) -> void:
	var l := label(text, font_size, color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	l.position = Vector2(0, 520 + dy)
	l.size = Vector2(W, 60)
	l.z_index = 40
	add_child(l)
	_pops.append([l, 1.3])


func _refresh_shop() -> void:
	if market == null:
		return
	var r := market.report
	if market.phase == "over":
		_shop_title.text = "MARGIN CALL!" if r.worth <= 0.0 else "CLOSING BELL.\nYOU'RE OFF THE FLOOR."
		var lesson := label("FLOOR LESSON:\n%s" % Market.LESSONS[randi() % Market.LESSONS.size()], 20, GOLD)
		lesson.custom_minimum_size = Vector2(0, 200)
		lesson.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_shop_title.add_theme_color_override("font_color", RED)
		_shop_report.text = "%s GOAL WAS $%d. YOU HAD $%d.\nDAYS CLEARED: %d   BEST TRADE: +$%d\nBEST STREAK: %d   TRADES: %d" % [
			r.day, int(r.goal), int(r.worth), market.cleared, int(market.best_trade), market.best_streak, market.trades]
		_shop_cash.text = _record_text()
		for c in _shop_list.get_children():
			c.queue_free()
		_shop_list.add_child(lesson)
		_reroll_btn.visible = false
		_cashout_btn.visible = false
		_next_btn.text = "BACK TO THE LOBBY"
		return
	var friday: bool = market.day % Market.DAYS == 0
	if r.cleared:
		_shop_title.text = ("FRIDAY CLEARED!\nYOU SURVIVED THE WEEK" if friday else "%s CLEARED!" % r.day)
		_shop_title.add_theme_color_override("font_color", GOLD if friday else GREEN)
	else:
		_shop_title.text = "GOLDEN PARACHUTE!\nYOU KEEP YOUR DESK"
		_shop_title.add_theme_color_override("font_color", GOLD)
	var made: float = r.made
	_shop_report.text = "MADE %s$%d TODAY\nWORTH $%d (GOAL $%d)\n%sBEST TRADE +$%d" % [
			"+" if made >= 0.0 else "-", absi(roundi(made)), int(r.worth), int(r.goal),
			"HOT HAND x%d   " % market.streak if market.streak >= 2 else "", int(market.best_trade)]
	_shop_cash.text = "AFTER HOURS SHOP   CASH $%d" % int(market.cash)
	for c in _shop_list.get_children():
		c.queue_free()
	for id in market.shop:
		var cost := market.perk_cost(id)
		var b := button("%s  $%d\n%s" % [Market.PERKS[id].name, cost, Market.PERKS[id].text], 18, Color(0.1, 0.2, 0.3), Color(0.45, 1.0, 0.95, 0.8))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 146)
		b.disabled = market.cash < cost
		b.pressed.connect(_buy_perk.bind(id))
		_shop_list.add_child(b)
	if market.shop.is_empty():
		_shop_list.add_child(label("SOLD OUT", 22, DIM))
	_reroll_btn.visible = true
	_reroll_btn.text = "REROLL $%d" % market.reroll_cost()
	_reroll_btn.disabled = market.cash < market.reroll_cost()
	_cashout_btn.visible = market.won
	var next_day := market.day % Market.DAYS + 1
	var week := market.week + (1 if friday else 0)
	var pct: float = Market.GOALS[next_day - 1] + Market.WEEK_STEP * (week - 1)
	_next_btn.text = "OPEN %s%s\nGOAL +%d%% = $%d" % [Market.DAY_NAMES[next_day - 1], " (WEEK %d)" % week if week > 1 else "",
		roundi(pct * 100.0), int(market.base_worth * (1.0 + pct))]


func _record_text() -> String:
	var best := int(hub.state.best.get("trading", 0)) if hub else 0
	return "RECORD: %d DAY%s" % [best, "" if best == 1 else "S"] if best > 0 else ""


func _refresh() -> void:
	if _intro_text == null:
		return
	refresh_top()
	if market == null:
		var start: int = hub.state.market_start() if hub else Market.BASE_CASH
		var lines := [
			"THE TRADING WEEK", "",
			"STARTING CASH: $%d" % start, "",
			"5 DAYS. EVERY DAY HAS A GOAL.",
			"MISS IT AT THE BELL: YOU'RE OUT.", "",
			"EVERY STOCK MOVES ITS OWN WAY.",
			"LEARN THEM.", "",
			"RUMORS COME BEFORE THE NEWS.",
			"SOME ARE FAKE.", "",
			"WIN TRADES IN A ROW: HOT HAND.", "",
			"SPEND WINNINGS ON PERKS",
			"AFTER HOURS.",
		]
		if hub and hub.state.has("insider_tip"):
			lines += ["", "KEV'S TIP: A STAR ON THE BIG POP."]
		if _record_text() != "":
			lines += ["", _record_text()]
		_intro_text.text = "\n".join(lines)
		return
	var m := market
	for s in Market.STOCKS:
		var b: Button = _tabs[s.sym]
		var ch := m.change(s.sym)
		var star := "*" if m.tip == s.sym else ""
		b.text = "%s%s\n%+d%%" % [star, s.sym, roundi(ch * 100.0)]
		if m.halted.has(s.sym):
			b.text = "%s\nHALT" % s.sym
		b.add_theme_color_override("font_color", GREEN if ch >= 0.0 else RED)
		var n: int = m.shares[s.sym]
		var border := DIM
		if n > 0:
			border = GREEN
		elif n < 0:
			border = RED
		var sel: bool = s.sym == _sel
		var st := box(Color(0.1, 0.32, 0.14) if sel else Color(0.04, 0.14, 0.07), border, 6 if n != 0 or sel else 3, 6)
		st.content_margin_top = 8
		st.content_margin_bottom = 36
		for k in ["normal", "hover", "focus", "pressed"]:
			b.add_theme_stylebox_override(k, st)
		_sparks[s.sym].queue_redraw()
	var left := m.seconds_left()
	_status.text = "%s  DAY %d/%d%s   0:%02d" % [m.day_name(), m.day, Market.DAYS, "  WK %d" % m.week if m.week > 1 else "", int(ceil(left))]
	_status.add_theme_color_override("font_color", RED if left <= 5.0 and fmod(_time, 0.5) < 0.25 else GREEN)
	if not active and m.phase == "trading":
		_status.text = "PAUSED. SIT DOWN TO TRADE."
	var st: Dictionary = Market.stock(_sel)
	_tip.text = Market.KIND_TIPS[st.kind]
	var n: int = m.shares[_sel]
	if n != 0:
		var profit := m.position_profit(_sel)
		_pos.text = "%s %d @ $%.2f   %s$%d (%+d%%)" % ["LONG" if n > 0 else "SHORT", absi(n), m.entry[_sel],
			"+" if profit >= 0.0 else "-", absi(roundi(profit)), roundi(m.position_gain(_sel) * 100.0)]
		_pos.add_theme_color_override("font_color", GREEN if profit >= 0.0 else RED)
	else:
		_pos.text = "CASH $%d   CAN SPEND $%d" % [int(m.cash), int(m.buying_power())]
		_pos.add_theme_color_override("font_color", Color.WHITE)
	_ticker.text = "%s     %s $%.2f     " % [m.headline, _sel, m.prices[_sel]]
	var names: Array[String] = []
	for id in m.perks:
		names.append(Market.PERKS[id].name)
	_perk_line.text = ("HOT HAND x%d   " % m.streak if m.streak >= 2 else "") + ("  ".join(names) if not names.is_empty() else "NO PERKS YET")
	var trading: bool = m.phase == "trading" and not m.halted.has(_sel)
	_buy_btn.text = "COVER" if n < 0 else "BUY"
	_sell_btn.text = "SELL" if n > 0 else ("SHORT" if m.has_perk("short") else "SELL")
	_buy_btn.disabled = not trading
	_sell_btn.disabled = not trading or (n == 0 and not m.has_perk("short"))
	for i in _stake_btns.size():
		var on := i == _stake
		var sb := box(Color(0.12, 0.4, 0.18) if on else Color(0.06, 0.16, 0.09), Color(GREEN, 1.0 if on else 0.4), 4, 6)
		for k in ["normal", "hover", "focus"]:
			_stake_btns[i].add_theme_stylebox_override(k, sb)
	_goal_bar.queue_redraw()
	_chart.queue_redraw()


func _draw_goal() -> void:
	var r := Rect2(Vector2.ZERO, _goal_bar.size)
	_goal_bar.draw_rect(r, Color(0.0, 0.1, 0.04))
	if market == null:
		return
	var worth := market.net_worth()
	var base := market.base_worth
	var g := market.goal()
	var t := clampf((worth - base) / maxf(1.0, g - base), 0.0, 1.0)
	var made := worth >= g
	var col := GOLD if made else (GREEN if worth >= base else RED)
	_goal_bar.draw_rect(Rect2(0, 0, r.size.x * t, r.size.y), Color(col, 0.45))
	if worth < base:
		var down := clampf((base - worth) / maxf(1.0, base * 0.2), 0.0, 1.0)
		_goal_bar.draw_rect(Rect2(0, 0, r.size.x * down * 0.2, r.size.y), Color(RED, 0.5))
	_goal_bar.draw_rect(r, Color(col, 0.9), false, 3.0)
	var text := "$%d / GOAL $%d%s" % [int(worth), int(g), "  MADE IT!" if made else ""]
	_goal_bar.draw_string(FONT, Vector2(0, 37), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color.WHITE)


func _draw_spark(c: Control, sym: String) -> void:
	if market == null:
		return
	var h: Array = market.history[sym]
	var n := mini(h.size(), 40)
	if n < 2:
		return
	var tail := h.slice(h.size() - n)
	var lo: float = tail.min()
	var hi: float = maxf(tail.max(), lo + 0.01)
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2(c.size.x * i / 39.0, c.size.y - c.size.y * (tail[i] - lo) / (hi - lo)))
	c.draw_polyline(pts, GREEN if tail.back() >= tail[0] else RED, 2.0)


func _draw_chart() -> void:
	var r := Rect2(Vector2.ZERO, _chart.size)
	_chart.draw_rect(r, Color(0.0, 0.08, 0.03))
	for i in 5:
		var y := r.size.y * i / 4.0
		_chart.draw_line(Vector2(0, y), Vector2(r.size.x, y), Color(0.2, 0.5, 0.25, 0.3), 1.0)
	if _flash > 0.0:
		_chart.draw_rect(r, Color(_flash_color, _flash * 0.35))
	_chart.draw_rect(r, Color(0.35, 1.0, 0.45, 0.6), false, 3.0)
	if market == null:
		return
	var m := market
	var h: Array = m.history[_sel]
	var fut: Array = m.future[_sel].slice(0, 8) if m.has_perk("crystal") else []
	var top := 70.0
	var bottom := r.size.y - 16.0
	var lo: float = h.min()
	var hi: float = h.max()
	for p in fut:
		lo = minf(lo, p)
		hi = maxf(hi, p)
	var n: int = m.shares[_sel]
	if n != 0:
		lo = minf(lo, m.entry[_sel])
		hi = maxf(hi, m.entry[_sel])
	var pad := (hi - lo) * 0.08 + 0.01
	lo -= pad
	hi += pad
	var slots := float(maxi(m.day_ticks(), h.size() - 1))
	var plot_w := r.size.x - 110.0
	var first_tick := m.now_tick() - (h.size() - 1)
	var x_of := func(tick: int) -> float: return plot_w * float(tick - first_tick) / slots
	var y_of := func(p: float) -> float: return bottom - (bottom - top) * (p - lo) / (hi - lo)
	# The closing bell: the right edge of the plot.
	var bell_x: float = x_of.call(first_tick + int(slots))
	_chart.draw_dashed_line(Vector2(bell_x, top - 10), Vector2(bell_x, bottom), Color(GOLD, 0.5), 2.0, 8.0)
	# The trade's profit, shaded from the entry line.
	if n != 0:
		var ey: float = y_of.call(m.entry[_sel])
		# Shade from where the open trade began.
		var since := -1
		for mk in m.marks[_sel]:
			if mk[1] == "sell":
				since = -1
			elif since < 0:
				since = int(mk[0])
		since = maxi(since, first_tick)
		var dx := plot_w / slots
		for i in range(maxi(0, since - first_tick), h.size()):
			var x: float = x_of.call(first_tick + i)
			var y: float = y_of.call(h[i])
			var good: bool = (h[i] >= m.entry[_sel]) == (n > 0)
			_chart.draw_line(Vector2(x, y), Vector2(x, ey), Color(GREEN if good else RED, 0.22), dx + 1.0)
		_chart.draw_dashed_line(Vector2(0, ey), Vector2(plot_w, ey), Color(1, 1, 1, 0.7), 2.0, 10.0)
		_chart.draw_string(FONT, Vector2(0, ey - 8), "IN $%.2f" % m.entry[_sel], HORIZONTAL_ALIGNMENT_RIGHT, plot_w - 6, 14, Color(1, 1, 1, 0.8))
	var pts := PackedVector2Array()
	for i in h.size():
		pts.append(Vector2(x_of.call(first_tick + i), y_of.call(h[i])))
	var up: bool = h.back() >= h[0]
	if pts.size() >= 2:
		_chart.draw_polyline(pts, GREEN if up else RED, 4.0)
	var now := pts[pts.size() - 1]
	# Crystal ball: the next two seconds, dotted.
	if not fut.is_empty():
		var prev := now
		for i in fut.size():
			var q := Vector2(x_of.call(m.now_tick() + i + 1), y_of.call(fut[i]))
			_chart.draw_dashed_line(prev, q, Color(0.8, 0.6, 1.0, 0.9), 3.0, 6.0)
			prev = q
	# Your trades.
	for mk in m.marks[_sel]:
		var t := int(mk[0])
		if t < first_tick:
			continue
		var i := t - first_tick
		if i >= h.size():
			continue
		var p := Vector2(x_of.call(t), y_of.call(h[i]))
		match mk[1]:
			"buy":
				_chart.draw_colored_polygon(PackedVector2Array([p + Vector2(0, 6), p + Vector2(-10, 24), p + Vector2(10, 24)]), GREEN)
			"short":
				_chart.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(-10, -24), p + Vector2(10, -24)]), RED)
			_:
				_chart.draw_circle(p, 7.0, Color.WHITE)
	_chart.draw_circle(now, 7.0, Color.WHITE)
	# Price tag on the right.
	var tag := Rect2(r.size.x - 104, now.y - 18, 100, 36)
	_chart.draw_rect(tag, GREEN if up else RED)
	_chart.draw_string(FONT, tag.position + Vector2(0, 26), "%.2f" % h.back(), HORIZONTAL_ALIGNMENT_CENTER, 100, 16, Color.BLACK)
	# Header: the stock, its personality, a live rumor's countdown.
	var st: Dictionary = Market.stock(_sel)
	_chart.draw_string(FONT, Vector2(12, 32), "%s  %s" % [_sel, st.name], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	_chart.draw_string(FONT, Vector2(12, 58), st.kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)
	var ev := m.rumor_on(_sel)
	if not ev.is_empty():
		var secs := maxi(0, int(ceil(ev.at - m.clock)))
		var fake: bool = ev.fake and m.has_perk("fact")
		var txt := "FAKE RUMOR" if fake else "NEWS IN %ds!" % secs
		if fmod(_time, 0.6) < 0.4 or fake:
			_chart.draw_string(FONT, Vector2(0, 58), txt, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 12, 18, Color(0.7, 0.7, 0.7) if fake else GOLD)
	if m.halted.has(_sel):
		_chart.draw_rect(Rect2(0, r.size.y * 0.5 - 40, r.size.x, 80), Color(0, 0, 0, 0.7))
		_chart.draw_string(FONT, Vector2(0, r.size.y * 0.5 + 14), "TRADING HALTED", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, GOLD)
