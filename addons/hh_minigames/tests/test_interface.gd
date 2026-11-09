extends GutTest
## Every mini game keeps the shared interface (README.md) and stays in the
## addon: its entry scene has start(config) and finished(result), and no
## script in here names a path or a class from outside it (the office's, the
## comedy app's), so the folder can be copied into any project as is.

const ROOT := "res://addons/hh_minigames/"


func test_every_game_has_an_entry_scene_with_the_interface() -> void:
	for id in HHMinigames.GAMES:
		var path := HHMinigames.scene_for(id)
		assert_true(ResourceLoader.exists(path), "%s has %s" % [id, path])
		var node: Node = load(path).instantiate()
		assert_true(node.has_method("start"), "%s: start(config)" % id)
		assert_true(node.has_signal("finished"), "%s: finished(result)" % id)
		assert_true(FileAccess.file_exists(ROOT + id + "/README.md"), "%s has a README" % id)
		node.free()


func test_aliases_reach_the_same_game() -> void:
	assert_eq(HHMinigames.scene_for("ragdoll"), HHMinigames.scene_for("fall_guy"))
	assert_eq(HHMinigames.script_for("rage"), ROOT + "rage_cage/rage.gd")
	assert_true(HHMinigames.is_cage("claw"))
	assert_false(HHMinigames.is_cage("trading"))


func test_nothing_reaches_outside_the_addon() -> void:
	var outside: Array[String] = []
	for c in ProjectSettings.get_global_class_list():
		var p: String = c.path
		if not p.begins_with(ROOT) and not p.begins_with("res://addons/gut/"):
			outside.append(c["class"])
	var paths := RegEx.create_from_string("res://[A-Za-z0-9_./%-]+")
	# Class names count in code, not inside text ("Deck: %d cards").
	var strings := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"")
	for file in _scripts(ROOT):
		var text := FileAccess.get_file_as_string(file)
		var code := _strip_comments(text)
		for m in paths.search_all(code):
			var p := m.get_string()
			assert_true(p.begins_with(ROOT) or p.begins_with("res://addons/gut/"), "%s names %s" % [file, p])
		var bare := strings.sub(code, "\"\"", true)
		for name in outside:
			var word := RegEx.create_from_string("\\b%s\\b" % name)
			assert_null(word.search(bare), "%s uses %s (not part of the addon)" % [file, name])


func _strip_comments(text: String) -> String:
	var out := PackedStringArray()
	for line in text.split("\n"):
		var t := line.strip_edges()
		if not t.begins_with("#"):
			out.append(line)
	return "\n".join(out)


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd") and not dir.ends_with("/tests/"):
			out.append(dir + f)
	for sub in d.get_directories():
		out.append_array(_scripts(dir + sub + "/"))
	return out
