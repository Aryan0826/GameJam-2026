extends SceneTree

const Rules = preload("res://scripts/rules/rules.gd")
const Bot = preload("res://scripts/rules/bot.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_setup_and_roll()
	_standalone_power_and_skip()
	_movement_and_flag()
	_drafted_abilities()
	_die_abilities()
	_rims()
	_replay()
	print("Rules revision: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _opening(seed_value: int = 7) -> Dictionary:
	var s := Rules.create_match(seed_value, 0)
	s = Rules.apply_action(s, {"kind": "draft", "pawns": [0, 1], "spells": ["teleport", "fracture"]}).state
	s = Rules.apply_action(s, {"kind": "draft", "pawns": [5, 6], "spells": ["shield", "teleport"]}).state
	return s


func _position(positions: Dictionary) -> Dictionary:
	var s := _opening()
	s.dice = ["infected_trail", "infected_trail"]
	s.rolls = [1, 1]
	for id in s.pawns.keys():
		if id in positions:
			s.pawns[id].pos = positions[id]
			s.pawns[id].ability = ""
			s.pawns[id].charged = false
		else:
			s.pawns.erase(id)
	return s


func _grant(s: Dictionary, id: int, spell: String) -> void:
	s.pawns[id].ability = spell
	s.pawns[id].charged = true


func _has(s: Dictionary, kind: String, id: int, p: Vector2i) -> bool:
	return {"kind": kind, "pawn": id, "to": p} in Rules.legal_actions(s)


func _action(s: Dictionary, kind: String, details: Dictionary = {}) -> Dictionary:
	for action: Dictionary in Rules.legal_actions(s):
		if action.kind != kind:
			continue
		var matches := true
		for key in details:
			if action.get(key) != details[key]:
				matches = false
				break
		if matches:
			return action
	return {}


func _play_action(s: Dictionary, action: Dictionary) -> Dictionary:
	var result := Rules.apply_action(s, action)
	_check(result.ok, "Expected legal action %s" % action)
	return result.state


func _play(s: Dictionary, kind: String, id: int, p: Vector2i) -> Dictionary:
	if s.dice[s.active].is_empty():
		s = _play_action(s, {"kind": "roll"})
	var action := _action(s, kind, {"pawn": id, "to": p})
	_check(not action.is_empty(), "Expected legal %s from pawn %d to %s" % [kind, id, p])
	s = _play_action(s, action)
	return _play_action(s, {"kind": "skip"})


func _setup_and_roll() -> void:
	var draft := Rules.create_match(7, 0)
	var choices := Rules.legal_actions(draft)
	_check(Rules.SPELLS == ["shield", "fracture", "teleport"] and choices.size() == 60,
		"Draft offers exactly the three remaining abilities on two different ships")
	_check(not Rules.apply_action(draft, {"kind": "draft", "pawns": [0, 1], "spells": ["shield", "borrow_tomorrow"]}).ok,
		"Removed ability cannot be drafted")
	var obsolete := _position({0: Vector2i(4, 4), 1: Vector2i(7, 5), 5: Vector2i(8, 8)})
	_grant(obsolete, 1, "borrow_tomorrow")
	_check(not Rules.apply_action(obsolete, {"kind": "borrow_tomorrow", "pawn": 1, "to": Vector2i(6, 5), "second": 0, "second_to": Vector2i(4, 5)}).ok,
		"Removed ability cannot be played even if a stale charge is supplied")
	var faces := {}
	for seed_value in range(1, 33):
		var setup := Rules.create_match(seed_value, 0)
		_check(setup.flag == Vector2i(5, 5) and setup.pawns.size() == 10, "Fixed center and ten pawns")
		for i in 5:
			_check(setup.pawns[i].pos == Vector2i(i + 3, 2) and setup.pawns[i + 5].pos == Vector2i(i + 3, 8), "Mirrored straight lines")
		var first := {"kind": "draft", "pawns": [0, 1], "spells": ["shield", "teleport"]}
		var locked: Dictionary = Rules.apply_action(setup, first).state
		_check(locked.pawns[0].ability == "" and locked.active == 1, "First lock stays private")
		var s := _opening(seed_value)
		var before := s.duplicate(true)
		_check(not _has(s, "step", 2, Vector2i(4, 3)), "Cannot move before rolling")
		var result := Rules.apply_action(s, {"kind": "roll"})
		var rolled: Dictionary = result.state
		_check(s == before and rolled.active == s.active and rolled.turn == s.turn, "Roll is immutable and does not end turn")
		_check(rolled.rolls[0] in range(1, 7) and rolled.dice[1].is_empty(), "Six-sided and personal")
		faces[rolled.dice[0]] = true
		_check(not Rules.apply_action(rolled, {"kind": "roll"}).ok, "Cannot reroll")
		_check(_has(rolled, "step", 2, Vector2i(4, 3)), "Moves become available after rolling")
		s = _play(rolled, "step", 2, Vector2i(4, 3))
		_check(s.dice[1].is_empty(), "Opponent does not inherit the roll")
		s = _play(s, "step", 7, Vector2i(4, 7))
		_check(s.dice == ["", ""] and s.round == 2, "Round resets both dice")
	_check(faces.size() == 3, "All die powers occur")


func _movement_and_flag() -> void:
	var s := _position({0: Vector2i(3, 3), 1: Vector2i(4, 4), 5: Vector2i(2, 4), 6: Vector2i(2, 2)})
	_check(_has(s, "step", 0, Vector2i(1, 5)), "Two diagonal steps can jump an opposing pawn")
	_check(_has(s, "step", 0, Vector2i(3, 2)), "Orthogonal backward is legal")
	_check(not _has(s, "step", 0, Vector2i(3, 5)), "Two orthogonal steps are illegal")
	_check(not _has(s, "step", 0, Vector2i(5, 5)), "No distant empty flag entry")
	_check(_has(s, "step", 1, Vector2i(5, 5)), "Adjacent diagonal flag entry")
	_check(_has(s, "capture", 0, Vector2i(2, 4)), "Forward one diagonal capture")
	_check(not _has(s, "capture", 0, Vector2i(2, 2)), "Ordinary backward capture is illegal")
	s = _play(s, "step", 1, Vector2i(5, 5))
	_check(s.holder == 1 and s.replies == 0, "Flag starts at zero")
	s = _play(s, "step", 6, Vector2i(3, 2))
	_check(s.replies == 1, "First opposing reply")
	s = _play(s, "step", 0, Vector2i(4, 3))
	s = _play(s, "step", 6, Vector2i(2, 2))
	_check(s.replies == 2 and s.phase == "playing", "Two replies do not win")
	s = _play(s, "step", 0, Vector2i(3, 3))
	s = _play(s, "step", 6, Vector2i(3, 2))
	_check(s.replies == 3 and s.reason == "flag" and s.winner == 0, "Third opposing reply wins")


func _drafted_abilities() -> void:
	var s := _position({0: Vector2i(3, 3), 1: Vector2i(4, 4), 5: Vector2i(8, 8), 6: Vector2i(7, 7)})
	_grant(s, 0, "teleport")
	s.infected[Vector2i(9, 9)] = 1
	s.holes[Vector2i(1, 1)] = true
	_check(not _has(s, "teleport", 0, s.flag) and not _has(s, "teleport", 0, s.pawns[5].pos), "Teleport excludes flag and occupied tiles")
	_check(not _has(s, "teleport", 0, Vector2i(1, 1)) and not _has(s, "teleport", 0, Vector2i(9, 9)), "Teleport excludes holes and infection")
	s = _play(s, "teleport", 0, Vector2i(9, 8))
	_check(s.pawns[0].pos == Vector2i(9, 8) and not s.pawns[0].charged, "Teleport crosses board and spends charge")
	s = _position({0: Vector2i(3, 3), 5: Vector2i(8, 8), 6: Vector2i(7, 7)})
	_grant(s, 0, "fracture")
	_check(not _has(s, "fracture", 0, s.flag), "Flag cannot be fractured")
	s = _play(s, "fracture", 0, Vector2i(8, 8))
	_check(5 in s.pawns and Vector2i(8, 8) in s.fractures, "Fracture gives the other side one turn")
	s = _play(s, "step", 6, Vector2i(6, 7))
	_check(5 not in s.pawns and Vector2i(8, 8) in s.holes, "Fracture drops occupant")
	s = _position({0: Vector2i(3, 3), 5: Vector2i(4, 4)})
	_grant(s, 0, "shield")
	s = _play(s, "shield", 0, Vector2i(3, 3))
	s = _play(s, "capture", 5, Vector2i(3, 3))
	_check(0 in s.pawns and not s.pawns[0].shield and s.pawns[5].pos == Vector2i(4, 4), "Shield intercepts capture")


func _die_abilities() -> void:
	var s := _position({0: Vector2i(4, 4), 5: Vector2i(7, 7), 6: Vector2i(6, 8)})
	s.dice[0] = "infected_trail"
	_check(_has(s, "step", 0, Vector2i(6, 6)), "Normal moves remain available after rolling")
	var movement := _action(s, "step", {"pawn": 0, "to": Vector2i(6, 6)})
	s = _play_action(s, movement)
	var infection := _action(s, "infected_trail", {"pawn": 0, "to": Vector2i(6, 6)})
	_check(not infection.is_empty(), "Can use Infected Trail after moving")
	s = _play_action(s, infection)
	_check(s.infected.size() == 8 and s.flag not in s.infected, "Centered infection affects 3 × 3 except the flag")
	_check(s.turn_move and s.turn_power_used and s.active == 0, "Move and power are separate actions in one turn")
	s = _play_action(s, {"kind": "skip"})
	_check(not _has(s, "step", 6, Vector2i(6, 7)), "Infection blocks entry")
	s = _play(s, "step", 5, Vector2i(8, 7))
	_check(s.infected.is_empty(), "Infection expires after enemy turn")
	s = _position({0: Vector2i(2, 4), 1: Vector2i(7, 7), 5: Vector2i(4, 5), 6: Vector2i(7, 8)})
	_grant(s, 5, "teleport")
	s.dice[0] = "spy"
	s = _play_action(s, _action(s, "step", {"pawn": 0, "to": Vector2i(3, 4)}))
	var spy := _action(s, "spy", {"mark": 5})
	_check(not spy.is_empty(), "Spy is available after a normal move")
	s = _play_action(s, spy)
	_check(s.pawns[0].pos == Vector2i(3, 4) and s.pawns[5].side == 0 and s.pawns[5].spy == 3,
		"Separate Spy use grants three turns of control")
	s = _play_action(s, {"kind": "skip"})
	s = _play(s, "step", 6, Vector2i(6, 8))
	_check(not _has(s, "teleport", 5, Vector2i(1, 1)), "Stolen pawn cannot spend its original charge")
	s = _play(s, "step", 5, s.flag)
	_check(s.holder == -1 and s.pawns[5].spy == 2, "Stolen pawn occupies the flag without scoring")
	s = _play(s, "step", 6, Vector2i(7, 8))
	s = _play(s, "step", 1, Vector2i(7, 6))
	s = _play(s, "step", 6, Vector2i(6, 8))
	s = _play(s, "step", 1, Vector2i(7, 7))
	_check(s.pawns[5].side == 1 and s.pawns[5].spy == 0 and s.holder == 5 and s.replies == 0, "After three turns control returns and scoring can start")
	s = _position({0: Vector2i(3, 3), 1: Vector2i(4, 4), 5: Vector2i(5, 5), 6: Vector2i(7, 7)})
	s.holder = 5
	s.dice[0] = "long_capture"
	_check(not _has(s, "capture", 0, s.flag), "Normal capture cannot reach two diagonals")
	s = _play_action(s, _action(s, "step", {"pawn": 0, "to": Vector2i(3, 4)}))
	var long_capture := _action(s, "long_capture", {"pawn": 1, "to": s.flag})
	_check(not long_capture.is_empty(), "Long Capture remains available after moving")
	s = _play_action(s, long_capture)
	s = _play_action(s, {"kind": "skip"})
	_check(5 not in s.pawns and s.pawns[0].pos == Vector2i(3, 4) and s.holder == 1 and s.replies == 0,
		"Long Capture can claim the flag with another pawn after a separate move")
	s = _position({0: Vector2i(4, 4), 1: Vector2i(3, 3), 5: Vector2i(5, 5)})
	s.pawns[0].spy = 3
	s.dice[0] = "long_capture"
	_check(_action(s, "long_capture", {"pawn": 0, "to": s.flag}).is_empty(),
		"Stolen pawn cannot use Long Capture against a flag holder")


func _standalone_power_and_skip() -> void:
	var unrolled := _opening()
	var skipped := Rules.apply_action(unrolled, {"kind": "skip"})
	_check(skipped.ok and skipped.state.active != unrolled.active,
		"Can skip without rolling first")
	var s := _position({0: Vector2i(4, 4), 5: Vector2i(8, 8)})
	s.dice[0] = "infected_trail"
	var infection := _action(s, "infected_trail", {"pawn": 0, "to": Vector2i(4, 4)})
	_check(not infection.is_empty(), "Rolled power can be used without moving")
	_check(_has(s, "step", 0, Vector2i(6, 6)), "Move is available before standalone power")
	s = _play_action(s, infection)
	_check(not s.turn_move and s.turn_power_used and s.pawns[0].pos == Vector2i(4, 4),
		"Standalone power does not move a pawn")
	_check(not _has(s, "step", 0, Vector2i(6, 6)), "Cannot move after using a standalone power")
	s = _play_action(s, {"kind": "skip"})
	_check(s.active == 1 and s.turn_move == false and s.turn_power_used == false,
		"Skip ends the turn and resets its action state")


func _rims() -> void:
	var s := _position({0: Vector2i(4, 4), 5: Vector2i(7, 7)})
	for round_number in range(1, 6):
		_check(s.round == round_number, "Round increments")
		if round_number in [2, 4]:
			var pair: Array = s.cracks.keys()
			_check(pair.size() == 2 and pair[0] + pair[1] == Vector2i(10, 10), "Warning tiles are opposite on the 9 × 9 board")
		var north := Vector2i(4, 5) if s.pawns[0].pos.y == 4 else Vector2i(4, 4)
		var south := Vector2i(7, 6) if s.pawns[5].pos.y == 7 else Vector2i(7, 7)
		s = _play(s, "step", 0, north)
		s = _play(s, "step", 5, south)
	_check(s.holes.size() == 56 and s.flag not in s.holes, "Both rims leave a 5 × 5 board")


func _replay() -> void:
	for seed_value in range(1, 9):
		var s := Rules.create_match(seed_value)
		var replay: Array[Dictionary] = []
		# Two drafts, then up to roll, move, power and finish for each turn.
		while s.phase != "finished" and replay.size() < 2 + 8 * 2 * 4:
			var before := s.duplicate(true)
			var legal := Rules.legal_actions(s)
			var choice := Bot.choose(s, legal)
			_check(choice in legal and s == before, "Bot picks a legal action without mutating the state")
			replay.append(choice)
			s = Rules.apply_action(s, choice).state
		_check(s.phase == "finished", "Automated match ends")
		var again := Rules.create_match(seed_value)
		for choice in replay:
			again = Rules.apply_action(again, choice).state
		_check(s == again, "Rolls, moves, and results replay deterministically")
