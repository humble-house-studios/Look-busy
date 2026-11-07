extends GutTest
## The open mic: five picks, 100 laughs, secrets make killer bits.


func test_final_set_plain_material_can_win() -> void:
	var f := FinalSet.new()
	for id in ["opener", "punch_a", "tag_a", "tag_b", "punch_b"]:
		f.play(id)
	assert_true(f.won(), "a well-built plain set lands (%d)" % f.laughs)


func test_final_set_badly_built_loses() -> void:
	var f := FinalSet.new()
	for id in ["tag_a", "tag_b", "crowd", "opener", "punch_a"]:
		f.play(id)
	assert_true(f.lost())


func test_final_set_secrets_and_memo_add_bits() -> void:
	var f := FinalSet.new(["kev", "ray"], true)
	var ids: Array = []
	for c in f.hand:
		ids.append(c.id)
	assert_has(ids, "kev")
	assert_has(ids, "ray")
	assert_has(ids, "memo")
	f.play("ray")
	assert_eq(f.play("memo"), 100.0, "setup doubles BIG DEAL")
	assert_true(f.won())
