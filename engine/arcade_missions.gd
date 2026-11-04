class_name ArcadeMissions
## Missions on the arcade machines (claw, pusher, ragdoll): one at a time per
## machine, each a plain goal the machine reports as it happens
## (event(machine, key, value): done when value reaches the mission's need).
## Finishing one pays its tickets and lights the next, so there's always
## something to go for. Saved in user://arcade.cfg (office NEW GAME wipes it).

const SAVE_PATH := "user://arcade.cfg"
const LIST := {
	"claw": [
		{"key": "won", "need": 1, "text": "LAND ANY PRIZE", "tickets": 20},
		{"key": "bonus", "need": 1, "text": "LAND THE GLOWING PRIZE", "tickets": 30},
		{"key": "capsule", "need": 1, "text": "OPEN A MYSTERY CAPSULE", "tickets": 40},
		{"key": "streak", "need": 2, "text": "LAND 2 DROPS IN A ROW", "tickets": 60},
		{"key": "double", "need": 1, "text": "2 PRIZES IN ONE GRAB", "tickets": 100},
	],
	"pusher": [
		{"key": "bonus_drop", "need": 1, "text": "DROP IN THE LIT ZONE", "tickets": 20},
		{"key": "coins_token", "need": 6, "text": "6 COINS OFF FROM 1 TOKEN", "tickets": 30},
		{"key": "streak", "need": 5, "text": "A 5-COIN STREAK", "tickets": 40},
		{"key": "bundle", "need": 1, "text": "PUSH OFF A GREEN BUNDLE", "tickets": 60},
		{"key": "streak", "need": 10, "text": "A 10-COIN STREAK", "tickets": 100},
	],
	"ragdoll": [
		{"key": "perfects", "need": 1, "text": "A PERFECT BOUNCE", "tickets": 20},
		{"key": "target", "need": 1, "text": "HIT THE LIT BUMPER", "tickets": 30},
		{"key": "bell", "need": 1, "text": "RING THE BELL", "tickets": 40},
		{"key": "perfects", "need": 3, "text": "3 PERFECTS IN A ROW (x1.5)", "tickets": 60},
		{"key": "bell", "need": 3, "text": "RING THE BELL 3 TIMES IN A ROUND", "tickets": 100},
	],
}

## machine -> how many missions it has finished.
var done := {}
var _path: String


func _init(save_path := SAVE_PATH) -> void:
	_path = save_path
	var cfg := ConfigFile.new()
	if cfg.load(_path) == OK:
		for m in LIST:
			done[m] = int(cfg.get_value("missions", m, 0))


func save() -> void:
	var cfg := ConfigFile.new()
	for m in done:
		cfg.set_value("missions", m, done[m])
	cfg.save(_path)


## The mission a machine is on, or {} when they're all done.
func current(machine: String) -> Dictionary:
	var list: Array = LIST.get(machine, [])
	var i: int = done.get(machine, 0)
	return list[i] if i < list.size() else {}


## The line the machine shows: "MISSION 2/5: ...".
func text(machine: String) -> String:
	var m := current(machine)
	if m.is_empty():
		return "ALL MISSIONS DONE!"
	return "MISSION %d/%d: %s" % [done.get(machine, 0) + 1, LIST[machine].size(), m.text]


## Something happened on a machine. Returns the mission it finished (with
## its tickets to pay), or {}.
func event(machine: String, key: String, value := 1) -> Dictionary:
	var m := current(machine)
	if m.is_empty() or m.key != key or value < int(m.need):
		return {}
	done[machine] = done.get(machine, 0) + 1
	save()
	return m
