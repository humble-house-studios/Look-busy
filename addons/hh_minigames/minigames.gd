class_name HHMinigames
extends RefCounted
## Every mini game in this addon: its folder, entry scene and main script.
## Hosts (the office, the comedy app, tools) look games up here instead of
## hard-coding paths. See README.md for the start(config) / finished(result)
## interface every entry scene follows.

const ROOT := "res://addons/hh_minigames/"
const GAMES := {
	"standup": {"title": "KILLIN' IN COMEDY", "script": "standup/main.gd"},
	"claw": {"title": "CLAW KING", "script": "claw/claw.gd", "cage": true},
	"pusher": {"title": "PUSH YOUR LUCK", "script": "pusher/pusher.gd", "cage": true},
	"fall_guy": {"title": "FALL GUY", "script": "fall_guy/ragdoll.gd", "cage": true},
	"rage_cage": {"title": "RAGE CAGE", "script": "rage_cage/rage.gd", "cage": true},
	"trading": {"title": "TRADING FLOOR", "script": "trading/trading.gd"},
	"golf": {"title": "CORNER LINKS", "script": "golf/putt.gd"},
	"pitch": {"title": "THE PITCH", "script": "pitch/pitch_screen.gd"},
	"open_mic": {"title": "OPEN MIC", "script": "open_mic/open_mic.gd"},
}
## Machine ids the office saves under (bests, missions) -> folder.
const ALIASES := {"ragdoll": "fall_guy", "rage": "rage_cage", "putt": "golf", "final_set": "open_mic"}


static func id_of(name: String) -> String:
	return ALIASES.get(name, name)


## The game's entry scene (every folder has a main.tscn).
static func scene_for(name: String) -> String:
	return ROOT + id_of(name) + "/main.tscn"


## The game's main script (for hosts that build their own cabinet round it).
static func script_for(name: String) -> String:
	return ROOT + GAMES[id_of(name)].script


static func is_cage(name: String) -> bool:
	return GAMES[id_of(name)].get("cage", false)
