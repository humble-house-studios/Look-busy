extends Node
## A pretend host for playing a mini game on its own (its entry scene opened
## straight, F6 in the editor, or a host that has no economy of its own).
## It answers everything a real host may be asked (README.md, "The host"),
## keeps nothing, and the tokens never run out.

const START_TOKENS := 20


class State:
	extends RefCounted
	var tokens := 20
	var tickets := 0
	var best := {}
	var stress := 0
	var items: Array[String] = []

	func has(id: String) -> bool:
		return id in items

	func is_done(_id: String) -> bool:
		return false

	func give_token(n := 1) -> void:
		tokens += n

	func market_start() -> int:
		return 1000

	func trading_record(days: int) -> void:
		best["trading"] = maxi(int(best.get("trading", 0)), days)


var state := State.new()
var missions = null
var crew := {"secrets": []}


func spend_token() -> bool:
	if state.tokens <= 0:
		state.tokens = START_TOKENS
	state.tokens -= 1
	return true


func win_tickets(n: int, machine := "", _beats := false) -> void:
	state.tickets += n
	if machine != "":
		state.best[machine] = maxi(int(state.best.get(machine, 0)), n)


func pay_rage() -> String:
	if state.stress > 0:
		state.stress -= 1
		return "stress"
	return "token" if spend_token() else ""


func add_stress(n: int) -> int:
	state.stress = clampi(state.stress + n, 0, 9)
	return n


func market_won() -> void:
	pass


func pitch_won() -> void:
	pass


func stage_won() -> void:
	pass
