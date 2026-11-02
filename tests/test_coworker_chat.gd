extends GutTest
## Talking to coworkers out loud: hidden keys open them up a tier (once per
## visit), warm chats in their favourite style add up to a tier, their hated
## style closes them off, and the AI's brief keeps later secrets hidden.

const PATH := "user://test_coworker_chat.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _crew() -> Coworkers:
	return Coworkers.new(PATH, 1)


func test_every_coworker_has_a_brief_three_keys_and_a_voice() -> void:
	for id in CoworkerLines.ORDER:
		var c: Dictionary = CoworkerLines.CHAT[id]
		assert_gt(str(c.who).length(), 30, id)
		assert_eq(c.keys.size(), Coworkers.MAX_TIER, id)
		for k in c.keys:
			assert_gt(str(k.topic).length(), 10, id)
			assert_gt(str(k.gossip).length(), 10, id)
		assert_true(Coworkers.CHAT_VOICES.has(id), id)


func test_a_key_opens_them_up_once_per_visit() -> void:
	var crew := _crew()
	var out := crew.chat("gloria", {"stance": "ask", "warmth": 1, "key": true}, {"plays": 0})
	assert_true(out.key)
	assert_eq(crew.tier("gloria"), 1)
	assert_has(out.rewards, "tokens:5")
	# Another key the same visit: they'd say more, but later.
	out = crew.chat("gloria", {"stance": "ask", "warmth": 1, "key": true}, {"plays": 0})
	assert_true(out.later)
	assert_eq(crew.tier("gloria"), 1)
	# After playing a machine, the next key works and tells the secret.
	out = crew.chat("gloria", {"stance": "ask", "warmth": 2, "key": true}, {"plays": 1})
	assert_eq(crew.tier("gloria"), 2)
	assert_ne(out.secret, "")
	assert_has(crew.secrets, "gloria")


func test_a_cold_key_does_not_count() -> void:
	var crew := _crew()
	crew.chat("kev", {"stance": "riff", "warmth": -1, "key": true}, {"plays": 0})
	assert_eq(crew.tier("kev"), 0)


func test_their_hated_style_closes_them_off() -> void:
	var crew := _crew()
	var out := crew.chat("theo", {"stance": "yes_and", "warmth": 1, "key": true}, {"plays": 0})
	assert_eq(out.delta, -1)
	assert_true(crew.is_closed("theo", 0))
	assert_false(crew.is_closed("theo", 1))
	# Closed: nothing you say lands.
	out = crew.chat("theo", {"stance": "push", "warmth": 2, "key": true}, {"plays": 0})
	assert_eq(out.delta, 0)


func test_rudeness_closes_anyone() -> void:
	var crew := _crew()
	assert_eq(crew.chat("ray", {"stance": "ask", "warmth": -2}, {"plays": 0}).delta, -1)


func test_warm_chats_in_their_style_add_up_to_a_tier() -> void:
	var crew := _crew()
	for i in Coworkers.RAPPORT_NEED - 1:
		var out := crew.chat("bernie", {"stance": "riff", "warmth": 1}, {"plays": 0})
		assert_true(out.warm)
		assert_eq(crew.tier("bernie"), 0)
	crew.chat("bernie", {"stance": "riff", "warmth": 2}, {"plays": 0})
	assert_eq(crew.tier("bernie"), 1)
	# Lukewarm or off-style chats don't build rapport.
	assert_false(crew.chat("bernie", {"stance": "yes_and", "warmth": 2}, {"plays": 1}).warm)
	assert_false(crew.chat("bernie", {"stance": "riff", "warmth": 0}, {"plays": 1}).warm)


func test_the_brief_hides_later_secrets_and_gossips_about_others() -> void:
	var crew := _crew()
	var p := crew.chat_persona("gloria", {"beaten": 0})
	var secret: String = CoworkerLines.PEOPLE.gloria.rewards[1].secret
	var keep := p.find("Things you keep to yourself")
	assert_gt(keep, -1)
	assert_gt(p.find(secret), keep)
	assert_string_contains(p, CoworkerLines.CHAT.gloria.keys[0].topic)
	assert_string_contains(p, CoworkerLines.CHAT.kev.keys[0].gossip)
	assert_eq(p.find(CoworkerLines.CHAT.gloria.keys[0].gossip), -1)
	# Ray isn't around yet, so nobody gossips about him.
	assert_eq(p.find(CoworkerLines.CHAT.ray.keys[0].gossip), -1)
	# Once she's told you, it moves to what she's shared, and the key moves on.
	crew.chat("gloria", {"stance": "ask", "warmth": 1, "key": true}, {"plays": 0})
	crew.chat("gloria", {"stance": "ask", "warmth": 1, "key": true}, {"plays": 1})
	p = crew.chat_persona("gloria", {"beaten": 0})
	assert_lt(p.find(secret), p.find("Things you keep to yourself"))
	assert_string_contains(p, CoworkerLines.CHAT.gloria.keys[2].topic)


func test_the_judge_gets_the_current_key() -> void:
	var crew := _crew()
	var spec := crew.chat_spec("theo", {}, "That promotion's mine.")
	assert_eq(spec.judge.key, CoworkerLines.CHAT.theo.keys[0].topic)
	assert_eq(spec.judge.line, "That promotion's mine.")
	assert_eq(spec.voice.aura, "arcas")
	crew.trust["theo"] = Coworkers.MAX_TIER
	assert_eq(crew.chat_spec("theo", {}).judge.key, "")


func test_chat_progress_survives_a_reload() -> void:
	var crew := _crew()
	crew.chat("kev", {"stance": "yes_and", "warmth": 1}, {"plays": 3})
	crew.chat("kev", {"stance": "yes_and", "warmth": 1, "key": true}, {"plays": 3})
	var again := _crew()
	assert_eq(again.tier("kev"), 1)
	assert_eq(int(again.leveled_at.kev), 3)
	assert_eq(int(again.rapport.get("kev", 0)), 0)
