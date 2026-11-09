class_name Workday
extends RefCounted
## Look Busy's run (docs/look-busy.md): a work week, 9 to 5, Monday to Friday,
## on one floor of the building with that floor's boss. The clock runs while
## you play; the boss comes by on a fixed, learnable schedule (walking a route
## or, on the WFH floor, video-calling your screen). Getting watched while you
## play fills the suspicion meter; full means a strike: a warning, then a
## write-up, then you're fired and the run starts over on floor 1.
## Pure rules, no scenes (scenes/office/look_busy.gd drives the office side).
## Saved in user://look_busy.cfg. Bosses and lines: data/busy_lines.gd.
## After hours: if 5 PM rings while you're mid-game, everyone goes home and you
## stay. The clock runs on to 7 PM with no boss, slack counts double, and the
## next morning you start tired (suspicion from the minutes you stayed).

const SAVE_PATH := "user://look_busy.cfg"
## Real seconds in a workday (9:00 to 17:00 = 480 game minutes).
const DAY_SECONDS := 300.0
const DAY_MINUTES := 480.0
const LUNCH := [180.0, 240.0]
const MAX_SUSPICION := 100.0
const STRIKES := ["warning", "writeup", "fired"]
## After a strike the boss can't add more for a moment.
const GRACE := 6.0
## Suspicion per second by what you're doing while the boss watches. Playing a
## game ("slacking") uses the boss's own rate. Talking to a coworker looks
## like a meeting: it holds suspicion where it is (Dale's tutorial talks used
## to strike you when Marge walked past mid-sentence).
const RATE := {"chatting": 0.0, "idle": 4.0, "working": -16.0}
const DECAY_UNSEEN := 3.0
const DECAY_AWAY := 6.0
## The boss stops at your desk and you're nowhere near one.
const EMPTY_DESK := 35.0
## Anyone this close is seen, whichever way the boss faces.
const NEAR := 1.2
## Coworker roles (engine/coworkers.gd role()): a lookout warns this many
## game minutes before the boss comes by and covers one empty desk a day; a
## snitch tips the boss off at these times (an extra visit, plus suspicion).
const LOOKOUT_LEAD := 8.0
const COVERS_PER_DAY := 1
const SNITCH_AT := [150.0, 330.0]
const SNITCH := 15.0
## The slack meter: game minutes spent playing a game while the boss can't see
## you. Each floor sets a daily quota (game minutes). The day starts with a
## coffee break already on it (a head start makes a goal feel reachable).
const QUOTA := [120.0, 150.0, 180.0]
const MORNING_COFFEE := 15.0
## Alt-tab with the boss this close (or a call ringing) and you weren't
## caught: a close call, worth slack minutes. Once per visit.
const CLOSE_CALL := 10.0
const CLOSE_RANGE := 4.0
## After hours: game minutes past 5 PM (to 7 PM), slack multiplier, and the
## suspicion you start the next morning with per minute stayed (capped).
const OVERTIME_MINUTES := 120.0
const OVERTIME_SLACK := 2.0
const TIRED_PER_MINUTE := 0.25
const TIRED_MAX := 30.0

var week := 1
var floor_i := 1
var day := 0
var minutes := 0.0
var suspicion := 0.0
var strikes := 0
var fired := false
## Best floor ever reached, and runs started (fired runs count).
var best_floor := 1
var runs := 1
## Spreadsheet cells filled (all time) and today.
var cells := 0
var cells_today := 0
## Empty desks a lookout covered today.
var covers_today := 0
## Every Friday so far: [{week, floor, title, score, avg, promoted}, ...].
var shipped: Array = []
## Slack (game minutes): today, this week, the best day ever. Close calls today.
var slacked := MORNING_COFFEE
var slacked_week := MORNING_COFFEE
var best_slack := 0.0
var close_calls := 0
## Days this week the quota was met.
var quota_days := 0
var _quota_hit := false
## After hours: on now; slack earned in it today; suspicion owed to tomorrow.
var overtime := false
var overtime_slack := 0.0
var tired := 0.0

var _path: String
var _grace := 0.0


func _init(save_path := SAVE_PATH) -> void:
	_path = save_path
	load_save()


static func boss_for(floor_n: int) -> Dictionary:
	return BusyLines.BOSSES[clampi(floor_n, 1, BusyLines.FLOORS) - 1]


func boss() -> Dictionary:
	return boss_for(floor_i)


## Minutes after 9:00 when today's boss comes by (lunch skipped).
static func visits(b: Dictionary) -> Array:
	var out: Array = []
	var t := float(b.get("at", 0))
	var every := maxf(1.0, float(b.get("every", 60)))
	while t < DAY_MINUTES:
		if t < LUNCH[0] or t >= LUNCH[1]:
			out.append(t)
		t += every
	return out


## The next visit at or after `from`, or -1.
func next_visit(from := -1.0) -> float:
	var at := minutes if from < 0.0 else from
	for t in visits(boss()):
		if t >= at:
			return t
	return -1.0


## Run the clock. Returns events in order: {"type": "soon"} LOOKOUT_LEAD
## before a visit (a lookout's cue), {"type": "visit"} when the boss is due,
## {"type": "snitch"} at SNITCH_AT (a snitch's cue), {"type": "day_end"} at
## 5 PM (the clock then waits for next_day(), or start_overtime()). After
## hours it runs on to 7 PM: {"type": "overtime_end"}.
func tick(delta: float) -> Array:
	var out: Array = []
	_grace = maxf(0.0, _grace - delta)
	if fired:
		return out
	if overtime:
		var end := DAY_MINUTES + OVERTIME_MINUTES
		if minutes < end:
			minutes = minf(end, minutes + delta * DAY_MINUTES / DAY_SECONDS)
			if minutes >= end:
				out.append({"type": "overtime_end"})
		return out
	if minutes >= DAY_MINUTES:
		return out
	var before := minutes
	minutes = minf(DAY_MINUTES, minutes + delta * DAY_MINUTES / DAY_SECONDS)
	for t in visits(boss()):
		var cue: float = t - LOOKOUT_LEAD
		if cue > before and cue <= minutes:
			out.append({"type": "soon"})
		if t > before and t <= minutes:
			out.append({"type": "visit"})
	for t in SNITCH_AT:
		if t > before and t <= minutes:
			out.append({"type": "snitch"})
	if minutes >= DAY_MINUTES:
		out.append({"type": "day_end"})
	return out


## Suspicion for one frame. activity: "slacking" (playing a game), "working"
## (alt-tabbed to the spreadsheet), "chatting", "idle". seen: the boss can see
## you. here: the boss is on the floor (or on a call). Returns the strike it
## caused ("warning" / "writeup" / "fired") or "".
func watch(delta: float, activity: String, seen: bool, here: bool, rate_scale := 1.0) -> String:
	if fired:
		return ""
	if seen:
		var rate: float = float(boss().get("rate", 40.0)) if activity == "slacking" else float(RATE.get(activity, 0.0))
		if rate > 0.0:
			rate *= rate_scale
			if _grace > 0.0:
				rate = 0.0
		suspicion += rate * delta
	else:
		suspicion -= (DECAY_UNSEEN if here else DECAY_AWAY) * delta
	suspicion = clampf(suspicion, 0.0, MAX_SUSPICION)
	if suspicion >= MAX_SUSPICION:
		return strike()
	return ""


## A lump of suspicion (an empty desk, a snitch). Returns the strike or "".
func add(amount: float) -> String:
	if fired or (amount > 0.0 and _grace > 0.0):
		return ""
	suspicion = clampf(suspicion + amount, 0.0, MAX_SUSPICION)
	if suspicion >= MAX_SUSPICION:
		return strike()
	return ""


func strike() -> String:
	strikes = mini(strikes + 1, STRIKES.size())
	suspicion = 0.0
	_grace = GRACE
	var level: String = STRIKES[strikes - 1]
	if level == "fired":
		fired = true
	save()
	return level


## Playing a game unseen fills the slack meter. True the moment today's
## quota is met.
## After hours it counts OVERTIME_SLACK times over.
func slack(delta: float, activity: String, seen: bool) -> bool:
	if fired or activity != "slacking" or seen:
		return false
	if overtime:
		if minutes >= DAY_MINUTES + OVERTIME_MINUTES:
			return false
		var m := delta * DAY_MINUTES / DAY_SECONDS * OVERTIME_SLACK
		overtime_slack += m
		return _add_slack(m)
	if minutes >= DAY_MINUTES:
		return false
	return _add_slack(delta * DAY_MINUTES / DAY_SECONDS)


## A close call: slack minutes on top. True if that met the quota.
func close_call() -> bool:
	close_calls += 1
	return _add_slack(CLOSE_CALL)


func _add_slack(m: float) -> bool:
	slacked += m
	slacked_week += m
	best_slack = maxf(best_slack, slacked)
	if not _quota_hit and slacked >= quota():
		_quota_hit = true
		quota_days += 1
		return true
	return false


func quota() -> float:
	return QUOTA[clampi(floor_i, 1, QUOTA.size()) - 1]


func quota_met() -> bool:
	return slacked >= quota()


## Real seconds until the boss's next visit (or -1: none left today).
func next_visit_in() -> float:
	var t := next_visit()
	if t < 0.0:
		return -1.0
	return (t - minutes) * DAY_SECONDS / DAY_MINUTES


## "1:05" for game minutes.
static func hours_text(m: float) -> String:
	var total := int(m)
	return "%d:%02d" % [total / 60, total % 60]


func in_grace() -> bool:
	return _grace > 0.0


func is_friday() -> bool:
	return day >= BusyLines.DAYS.size() - 1


## 5 PM has rung and you've gone home (after hours isn't over yet).
func day_over() -> bool:
	return minutes >= DAY_MINUTES and not overtime


## 5 PM rang mid-game: stay after hours. False if it's not 5 yet (or you're
## already staying, or fired).
func start_overtime() -> bool:
	if fired or overtime or minutes < DAY_MINUTES:
		return false
	overtime = true
	overtime_slack = 0.0
	_grace = 0.0
	suspicion = 0.0
	save()
	return true


## Clock out of after hours (7 PM, or you left): tomorrow's tiredness comes
## from the minutes you stayed.
func end_overtime() -> void:
	if not overtime:
		return
	overtime = false
	tired = minf(TIRED_MAX, stayed() * TIRED_PER_MINUTE)
	save()


## Game minutes stayed past 5 PM (0 if you went home on time).
func stayed() -> float:
	return maxf(0.0, minutes - DAY_MINUTES)


## After hours lighting: on while staying late and until you go home.
func after_hours() -> bool:
	return overtime or minutes > DAY_MINUTES


## The next morning. False on Friday (the week ends instead: new_week()).
func next_day() -> bool:
	if is_friday():
		return false
	day += 1
	_morning()
	save()
	return true


## A new week; promote moves you up a floor (to a new boss).
func new_week(promote: bool) -> void:
	week += 1
	if promote:
		floor_i = mini(floor_i + 1, BusyLines.FLOORS)
		best_floor = maxi(best_floor, floor_i)
	day = 0
	strikes = 0
	slacked_week = 0.0
	quota_days = 0
	tired = 0.0
	_morning()
	save()


## Fired: the run is over. Back to floor 1, week 1, Monday.
func start_over() -> void:
	runs += 1
	week = 1
	floor_i = 1
	day = 0
	strikes = 0
	fired = false
	slacked_week = 0.0
	quota_days = 0
	tired = 0.0
	_morning()
	save()


## Friday's result (engine/ship_day.gd review()), remembered.
func record_ship(r: Dictionary) -> void:
	shipped.append({"week": week, "floor": floor_i, "title": r.title, "score": r.score,
		"avg": r.press_avg, "promoted": r.promoted})
	save()


## A lookout covers your empty desk (once a day). True if they did.
func cover() -> bool:
	if covers_today >= COVERS_PER_DAY:
		return false
	covers_today += 1
	save()
	return true


func _morning() -> void:
	covers_today = 0
	minutes = 0.0
	# Stayed late last night: you come in tired, and it shows.
	suspicion = tired
	tired = 0.0
	overtime = false
	overtime_slack = 0.0
	cells_today = 0
	_grace = 0.0
	close_calls = 0
	slacked = 0.0
	_quota_hit = false
	_add_slack(MORNING_COFFEE)


func fill_cell() -> void:
	cells += 1
	cells_today += 1


## "MON 9:20 AM"
func clock_text() -> String:
	return "%s %s" % [BusyLines.DAYS[clampi(day, 0, 4)].left(3), time_text(minutes)]


static func time_text(m: float) -> String:
	var total := 9 * 60 + int(m)
	var h := total / 60
	var mm := total % 60
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, mm, "AM" if h < 12 else "PM"]


## Hours and minutes on the clock (for the office's wall clock).
func hour_minute() -> Vector2:
	var total := 9 * 60 + minutes
	return Vector2(floorf(total / 60.0), fmod(total, 60.0))


# ---------------------------------------------------------------- the patrol

## Seconds a walk along the route takes.
static func route_time(route: Array, speed: float) -> float:
	var t := 0.0
	for i in route.size():
		if i > 0:
			t += (route[i].p as Vector2).distance_to(route[i - 1].p) / maxf(speed, 0.01)
		t += float(route[i].get("wait", 0.0))
	return t


## Where a walking boss is `t` seconds into the route: {pos (x, z), yaw,
## stop (index of the spot they're waiting at, or -1), desk (waiting at your
## desk), done}. yaw faces +z at 0, like the office's people.
static func patrol_at(route: Array, speed: float, t: float) -> Dictionary:
	var pos: Vector2 = route[0].p
	var yaw := 0.0
	var left := maxf(t, 0.0)
	for i in route.size():
		var spot: Dictionary = route[i]
		var p: Vector2 = spot.p
		if i > 0:
			var from: Vector2 = route[i - 1].p
			var seg := from.distance_to(p) / maxf(speed, 0.01)
			var dir := p - from
			if dir.length() > 0.001:
				yaw = atan2(dir.x, dir.y)
			if left < seg:
				return {"pos": from.lerp(p, left / seg), "yaw": yaw, "stop": -1, "desk": false, "done": false}
			left -= seg
		var wait := float(spot.get("wait", 0.0))
		if left < wait:
			var look_yaw := yaw
			if spot.has("look"):
				var d: Vector2 = spot.look - p
				look_yaw = atan2(d.x, d.y)
			# Turn to look over the first half second.
			var turn := clampf(left / 0.5, 0.0, 1.0)
			return {"pos": p, "yaw": lerp_angle(yaw, look_yaw, turn), "stop": i, "desk": bool(spot.get("desk", false)), "done": false}
		left -= wait
		pos = p
	return {"pos": pos, "yaw": yaw, "stop": -1, "desk": false, "done": true}


## Can someone at boss (x, z) facing yaw see me? (Walls are the office's job.)
static func sees(boss_at: Vector2, yaw: float, me: Vector2, range_m: float, cone_deg: float) -> bool:
	var d := me - boss_at
	var dist := d.length()
	if dist > range_m:
		return false
	if dist < NEAR:
		return true
	var fwd := Vector2(sin(yaw), cos(yaw))
	return absf(rad_to_deg(fwd.angle_to(d.normalized()))) <= cone_deg


# ---------------------------------------------------------------- save

func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	week = int(cfg.get_value("run", "week", 1))
	floor_i = clampi(int(cfg.get_value("run", "floor", 1)), 1, BusyLines.FLOORS)
	day = clampi(int(cfg.get_value("run", "day", 0)), 0, 4)
	minutes = clampf(float(cfg.get_value("run", "minutes", 0.0)), 0.0, DAY_MINUTES + OVERTIME_MINUTES)
	suspicion = clampf(float(cfg.get_value("run", "suspicion", 0.0)), 0.0, MAX_SUSPICION)
	strikes = clampi(int(cfg.get_value("run", "strikes", 0)), 0, STRIKES.size())
	fired = bool(cfg.get_value("run", "fired", false))
	best_floor = int(cfg.get_value("run", "best_floor", 1))
	runs = int(cfg.get_value("run", "runs", 1))
	cells = int(cfg.get_value("run", "cells", 0))
	cells_today = int(cfg.get_value("run", "cells_today", 0))
	covers_today = int(cfg.get_value("run", "covers_today", 0))
	slacked = float(cfg.get_value("run", "slacked", MORNING_COFFEE))
	slacked_week = float(cfg.get_value("run", "slacked_week", slacked))
	best_slack = float(cfg.get_value("run", "best_slack", slacked))
	close_calls = int(cfg.get_value("run", "close_calls", 0))
	quota_days = int(cfg.get_value("run", "quota_days", 0))
	overtime = bool(cfg.get_value("run", "overtime", false))
	overtime_slack = float(cfg.get_value("run", "overtime_slack", 0.0))
	tired = clampf(float(cfg.get_value("run", "tired", 0.0)), 0.0, TIRED_MAX)
	_quota_hit = slacked >= quota()
	var sh = cfg.get_value("run", "shipped", [])
	shipped = sh if sh is Array else []


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_path)
	cfg.set_value("run", "week", week)
	cfg.set_value("run", "floor", floor_i)
	cfg.set_value("run", "day", day)
	cfg.set_value("run", "minutes", minutes)
	cfg.set_value("run", "suspicion", suspicion)
	cfg.set_value("run", "strikes", strikes)
	cfg.set_value("run", "fired", fired)
	cfg.set_value("run", "best_floor", best_floor)
	cfg.set_value("run", "runs", runs)
	cfg.set_value("run", "cells", cells)
	cfg.set_value("run", "cells_today", cells_today)
	cfg.set_value("run", "covers_today", covers_today)
	cfg.set_value("run", "shipped", shipped)
	cfg.set_value("run", "slacked", slacked)
	cfg.set_value("run", "slacked_week", slacked_week)
	cfg.set_value("run", "best_slack", best_slack)
	cfg.set_value("run", "close_calls", close_calls)
	cfg.set_value("run", "quota_days", quota_days)
	cfg.set_value("run", "overtime", overtime)
	cfg.set_value("run", "overtime_slack", overtime_slack)
	cfg.set_value("run", "tired", tired)
	cfg.save(_path)
