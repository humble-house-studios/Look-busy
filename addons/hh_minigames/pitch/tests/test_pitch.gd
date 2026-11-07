extends GutTest
## The boardroom pitch: match the objections to get greenlit.


func test_pitch_wins_with_matching_answers() -> void:
	var p := Pitch.new(2)
	while not p.done():
		var pick := 0
		for i in p.hand.size():
			if p.hand[i].kind == p.member().kind or p.hand[i].kind == Pitch.WILD:
				pick = i
		p.answer(pick)
	assert_true(p.won() or p.lost())


func test_pitch_wrong_answers_lose() -> void:
	var p := Pitch.new(2)
	while not p.done():
		var pick := -1
		for i in p.hand.size():
			if p.hand[i].kind != p.member().kind and p.hand[i].kind != Pitch.WILD:
				pick = i
		if pick < 0:
			break
		p.answer(pick)
	if p.done():
		assert_true(p.lost())
