class_name DiskBinder
extends RefCounted
## Look Busy's disk binder: every piece you've ever found, kept as a floppy
## disk. Your weekly kit (engine/game_maker.gd) starts empty every Monday and
## when you're fired; the binder never does. That's the collection layer that
## carries between runs (docs/look-busy.md, "Pieces are floppy disks").
## Pure rules; saved in user://disk_binder.cfg.

const SAVE_PATH := "user://disk_binder.cfg"

## Piece names in the order you first found them.
var found: Array = []

var _path: String


func _init(save_path := SAVE_PATH) -> void:
	_path = save_path
	load_save()


## Every piece in the game, one entry per name: [{kind, name, from}], grouped
## by kind (GameMaker.KINDS order), desks first, then coworkers' side projects.
static func all_pieces() -> Array:
	var out: Array = []
	var seen := {}
	for kind in GameMaker.KINDS:
		for src in GameMaker.SOURCES:
			for p in GameMaker.SOURCES[src]:
				if p[0] == kind and not seen.has(p[1]):
					seen[p[1]] = true
					out.append({"kind": kind, "name": p[1], "from": src})
		for id in CoworkerLines.BUSY:
			for p in CoworkerLines.BUSY[id].side.pieces:
				if p[0] == kind and not seen.has(p[1]):
					seen[p[1]] = true
					out.append({"kind": kind, "name": p[1], "from": id})
	return out


static func total() -> int:
	return all_pieces().size()


func has(name: String) -> bool:
	return found.has(name)


func count() -> int:
	return found.size()


## A piece turned up. True the first time ever (and it's saved).
func record(name: String) -> bool:
	if name == "" or found.has(name):
		return false
	found.append(name)
	save()
	return true


## The combos a piece is part of: [{name, text, others: [piece names]}].
static func combos_with(name: String) -> Array:
	var out: Array = []
	for c in GameMaker.COMBOS:
		if not c.needs.has(name):
			continue
		var others: Array = []
		for n in c.needs:
			if n != name:
				others.append(n)
		out.append({"name": c.name, "text": combo_text(c), "others": others})
	return out


## "+40" or "x2" for one combo.
static func combo_text(c: Dictionary) -> String:
	if c.has("mult"):
		return "x" + String.num(float(c.mult))
	return "+%d" % int(c.get("add", 0))


## A combo by name ({} if there isn't one).
static func combo(name: String) -> Dictionary:
	for c in GameMaker.COMBOS:
		if c.name == name:
			return c
	return {}


func load_save() -> void:
	found = []
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	found = Array(cfg.get_value("binder", "found", []))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("binder", "found", found)
	cfg.save(_path)


## Wipe it (NEW GAME and the dev panel do this through the save file).
func reset() -> void:
	found = []
	save()
