extends GutTest
## Look Busy's disk binder: every piece ever found, kept across weeks and runs.

const PATH := "user://test_disk_binder.cfg"
const GM_PATH := "user://test_disk_binder_gm.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GM_PATH))


func test_first_find_counts_once() -> void:
	var b := DiskBinder.new(PATH)
	assert_eq(b.count(), 0)
	assert_true(b.record("COMEDY"), "a first find")
	assert_false(b.record("COMEDY"), "already in the binder")
	assert_eq(b.count(), 1)


func test_the_binder_is_saved() -> void:
	var b := DiskBinder.new(PATH)
	b.record("SLOT REELS")
	b.record("GLORIA")
	var again := DiskBinder.new(PATH)
	assert_eq(again.found, ["SLOT REELS", "GLORIA"], "found order kept")


func test_it_outlives_the_weekly_kit() -> void:
	var b := DiskBinder.new(PATH)
	var g := GameMaker.new(GM_PATH, 1)
	var p := g.earn("comedy")
	b.record(p.name)
	g.new_week()
	assert_true(g.pieces.is_empty(), "the kit starts the week empty")
	g.reset()
	assert_true(DiskBinder.new(PATH).has("COMEDY"), "but the binder keeps it, even when fired")


func test_every_piece_is_listed_once_with_a_kind() -> void:
	var all := DiskBinder.all_pieces()
	var names := {}
	for p in all:
		assert_false(names.has(p.name), "listed once: " + p.name)
		names[p.name] = true
		assert_has(GameMaker.KINDS, p.kind)
		assert_eq(GameMaker.kind_of(p.name), p.kind, p.name)
	assert_eq(DiskBinder.total(), all.size())
	assert_true(names.has("COMEDY") and names.has("GLORIA") and names.has("MOP BEATS"), "desks and coworkers both")
	# Grouped by kind, in the kit's order.
	var last := -1
	for p in all:
		var k := GameMaker.KINDS.find(p.kind)
		assert_true(k >= last, "grouped by kind")
		last = k


func test_combos_with_a_piece() -> void:
	var list := DiskBinder.combos_with("COMEDY")
	var by_name := {}
	for c in list:
		by_name[c.name] = c
	assert_true(by_name.has("LAUGH SLOTS"))
	assert_eq(by_name["LAUGH SLOTS"].others, ["SLOT REELS"])
	assert_eq(by_name["LAUGH SLOTS"].text, "x2")
	assert_eq(by_name["PRATFALL"].text, "+40")
	assert_eq(DiskBinder.combos_with("NOT A PIECE"), [])
	assert_eq(DiskBinder.combo("SITCOM").get("add"), 25)
