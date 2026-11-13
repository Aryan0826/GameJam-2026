extends SceneTree

const Rules = preload("../scripts/rules.gd")
const Bot = preload("../scripts/bot.gd")
const PASS = {"kind": "pass"}

var failures: PackedStringArray = []
var assertions := 0


func _initialize() -> void:
	_test_opening_and_draft()
	_test_normal_actions()
	_test_flag()
	_test_collapse_and_outcomes()
	_test_shield_blink_sprint()
	_test_borrow()
	_test_round_effects()
	_test_seeded_replays()
	_test_bot()
	if failures.is_empty():
		print("Rules regression passed (%d assertions)." % assertions)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		printerr("%d of %d rules assertions failed." % [failures.size(), assertions])
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _find(s: Dictionary, fields: Dictionary) -> Dictionary:
	for action in Rules.legal_actions(s):
		var matches := true
		for field in fields:
			if action.get(field) != fields[field]:
				matches = false
				break
		if matches:
			return action
	return {}


func _commit(s: Dictionary, fields: Dictionary) -> Dictionary:
	var action := _find(s, fields)
	_check(not action.is_empty(), "Expected legal action %s in round %s, turn %s" % [fields, s.round, s.turn])
	if action.is_empty():
		return {"state": s, "events": [], "ok": false}
	var snapshot := s.duplicate(true)
	var transition := Rules.apply_action(s, action)
	_check(transition.ok, "Listed action was rejected: %s" % action)
	_check(s == snapshot, "A transition modified its input: %s" % action)
	return transition


func _act(s: Dictionary, kind: String, pawn: int, target: Vector2i, extra := {}) -> Dictionary:
	var fields := {"kind": kind, "pawn": pawn, "to": target}
	fields.merge(extra)
	return _commit(s, fields).state


func _begin(seed_value := 42, first_side := 0) -> Dictionary:
	var s := Rules.create_match(seed_value, first_side)
	s = _commit(s, {"kind": "draft"}).state
	return _commit(s, {"kind": "draft"}).state


func _fixture(positions: Dictionary, round_number := 1, turn_index := 0) -> Dictionary:
	var s := _begin()
	s.flag = Vector2i(5, 4)
	s.portals = [Vector2i(3, 4), Vector2i(7, 4)]
	s.round = round_number
	s.turn = turn_index
	s.active = turn_index
	s.holder = -1
	s.replies = 0
	s.move_die = "forward"
	s.special = ""
	for id in s.pawns.keys():
		if not positions.has(id):
			s.pawns.erase(id)
			continue
		var pawn: Dictionary = s.pawns[id]
		pawn.pos = positions[id]
		pawn.ability = ""
		pawn.charged = false
		pawn.shield = false
		pawn.spy = false
		pawn.borrow = {}
		if pawn.pos == s.flag:
			s.holder = id
	return s


func _spell(s: Dictionary, id: int, spell: String) -> void:
	s.pawns[id].ability = spell
	s.pawns[id].charged = true


func _invalid(s: Dictionary, action: Dictionary, message: String) -> void:
	var snapshot := s.duplicate(true)
	var result := Rules.apply_action(s, action)
	_check(not result.ok and result.state == snapshot and s == snapshot and result.events.is_empty(), message)


func _test_opening_and_draft() -> void:
	var flags := {}
	var starters := {}
	for seed_value in range(1, 81):
		var s := Rules.create_match(seed_value)
		flags[s.flag] = true
		starters[s.first] = true
		_check(s == Rules.create_match(seed_value), "Seed %d produced different initial state" % seed_value)
		_check(s.phase == "draft" and s.tokens == [2, 2] and s.pawns.size() == 8, "Opening inventory is incorrect")
		for side in [0, 1]:
			var direction := -1 if side == 0 else 1
			for slot in range(4):
				var offset := Vector2i(0, direction * 3) if slot == 3 else Vector2i(slot - 1, direction * 2)
				var pawn: Dictionary = s.pawns[4 * side + slot]
				_check(pawn.side == side and pawn.pos == s.flag + offset, "Pawn formation differs from brief")
	_check(flags.size() == 6, "Opening should cover all six flag coordinates")
	for pos: Vector2i in flags:
		_check(pos.x in [4, 5, 6] and pos.y in [4, 5], "Flag outside the six permitted positions")
	_check(starters.size() == 2, "Random starts should include both sides")
	var s := Rules.create_match(427, 1)
	var ids := [s.active * 4, s.active * 4 + 1]
	_invalid(s, {"kind": "draft", "pawns": ids, "spells": ["shield", "shield"]}, "Duplicate drafted spell was accepted")
	_invalid(s, {"kind": "draft", "pawns": [ids[0], ids[0]], "spells": ["shield", "blink"]}, "Duplicate drafted pawn was accepted")
	var first_lock := _commit(s, {"kind": "draft", "pawns": ids, "spells": ["shield", "blink"]})
	s = first_lock.state
	_check(s.phase == "draft", "Draft should wait for both sides")
	for p: Dictionary in s.pawns.values():
		_check(p.ability == "" and not p.charged, "First draft lock exposed a pawn assignment")
	ids = [s.active * 4, s.active * 4 + 1]
	s = _commit(s, {"kind": "draft", "pawns": ids, "spells": ["sprint", "borrow_tomorrow"]}).state
	_check(s.phase == "playing" and s.active == 1 and s.first == 1, "Override should start play with South")
	var charges := 0
	for p: Dictionary in s.pawns.values():
		if p.charged:
			charges += 1
	_check(charges == 4, "Both draft locks must reveal four pawn-bound charges")


func _test_normal_actions() -> void:
	var s := _fixture({0: Vector2i(4, 3), 4: Vector2i(3, 4)})
	s.move_die = "left"
	var first_roll: String = s.move_die
	_check(not _find(s, {"kind": "step", "pawn": 0, "to": Vector2i(5, 3), "token": false}).is_empty(), "North left increases column")
	_check(_find(s, {"kind": "step", "pawn": 0, "to": Vector2i(3, 3), "token": false}).is_empty(), "North left offered opposite step")
	s = _act(s, "step", 0, Vector2i(5, 3))
	_check(s.round == 1 and s.active == 1 and s.move_die == first_roll, "Round die must be shared by both sides")
	_check(not _find(s, {"kind": "step", "pawn": 4, "to": Vector2i(2, 4), "token": false}).is_empty(), "South left decreases column")
	s.move_die = "right"
	_check(not _find(s, {"kind": "step", "pawn": 4, "to": Vector2i(4, 4), "token": false}).is_empty(), "South right increases column")
	s = _fixture({0: Vector2i(4, 3), 1: Vector2i(7, 3), 4: Vector2i(3, 4), 5: Vector2i(5, 3)})
	s.move_die = "left"
	_check(_find(s, {"kind": "step", "pawn": 0, "to": Vector2i(3, 3), "token": false}).is_empty(), "One pawn's blocked die step does not grant fallback")
	_spell(s, 4, "shield")
	s = _act(s, "capture", 0, Vector2i(3, 4))
	_check(not s.pawns.has(4) and s.tokens == [2, 2], "Sideways roll should allow capture without a token and remove drafted pawn")
	_invalid(s, {"kind": "capture", "pawn": 0, "to": Vector2i(3, 4), "token": false}, "Replaying a stale action must not spend an enemy turn")
	s = _fixture({0: Vector2i(9, 3), 4: Vector2i(7, 6)})
	s.move_die = "left"
	var fallback := _find(s, {"kind": "step", "pawn": 0, "to": Vector2i(8, 3), "token": false})
	_check(not fallback.is_empty(), "Fallback should exist when all rolled steps are blocked")
	_invalid(s, {"kind": "step", "pawn": 0, "to": Vector2i(10, 3), "token": false}, "Out-of-bounds step should spend nothing")
	_invalid(s, PASS, "Pass must be rejected when any action is available")
	s.move_die = "wild"
	_check(not _find(s, {"kind": "step", "pawn": 0, "to": Vector2i(9, 2)}).is_empty(), "Wild allows backward movement")
	s.move_die = "right"
	s = _act(s, "step", 0, Vector2i(9, 4), {"token": true})
	_check(s.tokens == [1, 2], "A forward token must be spent only by the active side")
	s = _fixture({0: Vector2i(1, 1), 4: Vector2i(9, 8)})
	for y in range(1, 9):
		for x in range(1, 10):
			var pos := Vector2i(x, y)
			if pos not in [s.pawns[0].pos, s.pawns[4].pos]:
				s.holes[pos] = true
	_check(Rules.legal_actions(s) == [PASS], "No available action should produce exactly one pass")
	s = _commit(s, PASS).state
	_check(s.active == 1 and s.turn == 1, "A forced pass must finish the turn")


func _test_flag() -> void:
	var s := _fixture({0: Vector2i(5, 3), 1: Vector2i(3, 3), 4: Vector2i(7, 6)})
	s = _act(s, "step", 0, s.flag)
	_check(s.holder == 0 and s.replies == 0, "Flag entry should start at zero replies")
	s = _act(s, "step", 4, Vector2i(7, 5))
	_check(s.holder == 0 and s.replies == 1, "First enemy reply should tick the same holder")
	s.move_die = "forward"
	s = _act(s, "step", 1, Vector2i(3, 4))
	_check(s.holder == 0 and s.replies == 1, "Friendly turn must not tick the holder")
	s = _act(s, "step", 4, Vector2i(7, 4))
	_check(s.winner == 0 and s.reason == "flag" and s.replies == 2 and s.phase == "finished", "Second reply should win by flag")
	_check(Rules.legal_actions(s).is_empty(), "Finished game still permits actions")

	s = _fixture({0: Vector2i(5, 4), 1: Vector2i(6, 3), 4: Vector2i(6, 5)}, 2, 1)
	s.replies = 1
	s.move_die = "right"
	s = _act(s, "capture", 4, s.flag)
	_check(s.holder == 4 and s.replies == 0, "Capture onto the flag starts a new hold at zero")
	s = _act(s, "capture", 1, s.flag)
	_check(s.holder == 1 and s.replies == 0, "Replacement by a different pawn must not inherit progress")

	s = _fixture({0: Vector2i(5, 4), 4: Vector2i(7, 6)})
	s.replies = 1
	s = _act(s, "step", 0, Vector2i(5, 5))
	_check(s.holder == -1 and s.replies == 0, "Leaving the flag clears hold progress")
	s = _act(s, "step", 4, Vector2i(7, 5))
	s.move_die = "wild"
	s = _act(s, "step", 0, s.flag)
	_check(s.holder == 0 and s.replies == 0, "The same pawn reentering starts from zero")

	s = _fixture({0: Vector2i(5, 4), 4: Vector2i(9, 8)}, 2, 1)
	s.replies = 1
	s.holes[Vector2i(8, 8)] = true
	s.holes[Vector2i(9, 7)] = true
	s = _commit(s, PASS).state
	_check(s.phase == "finished" and s.reason == "flag", "Enemy pass should count toward the flag win")


func _opposite(pos: Vector2i) -> Vector2i:
	return Vector2i(10 - pos.x, 9 - pos.y)


func _test_collapse_and_outcomes() -> void:
	var s := _fixture({0: Vector2i(3, 3), 4: Vector2i(7, 6)})
	var crack_counts := [0, 0, 2, 28, 2, 20, 0]
	var hole_counts := [0, 0, 0, 2, 30, 32, 52]
	for round_number in range(1, 7):
		_check(s.round == round_number and s.cracks.size() == crack_counts[round_number], "Incorrect warning count in round %d" % round_number)
		_check(s.holes.size() == hole_counts[round_number], "Incorrect hole count in round %d" % round_number)
		_check((s.special != "") == (round_number in [2, 4, 6]), "Special roll scheduled on wrong round")
		if round_number in [2, 4] and s.cracks.size() == 2:
			var pair: Array = s.cracks.keys()
			_check(_opposite(pair[0]) == pair[1], "Pair collapse must warn opposite tiles")
		if round_number == 6:
			break
		for side in [0, 1]:
			var id: int = 4 * side
			var origin := Vector2i(3, 3) if side == 0 else Vector2i(7, 6)
			var dest := Vector2i(3, 4) if side == 0 else Vector2i(7, 5)
			s.pawns[id].pos = origin
			s.move_die = "forward"
			s = _act(s, "step", id, dest)
			if side == 0:
				_check(s.holes.size() == hole_counts[round_number], "Tiles dropped after just one turn")
	for y in range(1, 9):
		for x in range(1, 10):
			var central := x >= 3 and x <= 7 and y >= 3 and y <= 6
			_check(s.holes.has(Vector2i(x, y)) != central, "Final arena should be exactly 5 by 4")
	for portal: Vector2i in s.portals:
		_check(not s.holes.has(portal), "Portal fell during a scheduled collapse")

	s = _fixture({0: Vector2i(1, 3), 4: Vector2i(9, 6)}, 3, 1)
	s.cracks = {Vector2i(1, 3): 3, Vector2i(9, 5): 3}
	s.pawns[0].shield = true
	s.infected[Vector2i(9, 4)] = 5
	s.cracks[Vector2i(9, 4)] = 3
	s = _act(s, "step", 4, Vector2i(9, 5))
	_check(s.phase == "finished" and s.winner == -1 and s.reason == "mutual_elimination", "Simultaneous elimination must draw, even with a shield")
	_check(s.infected.is_empty(), "Falling tiles clear infection")

	s = _fixture({0: Vector2i(5, 4), 4: Vector2i(9, 6)}, 3, 1)
	s.replies = 1
	s.cracks = {Vector2i(9, 5): 3}
	s = _act(s, "step", 4, Vector2i(9, 5))
	_check(s.winner == 0 and s.reason == "elimination", "Elimination should win before a simultaneous second flag tick")

	s = _fixture({0: Vector2i(5, 4), 4: Vector2i(9, 6), 5: Vector2i(7, 5)}, 3, 1)
	s.replies = 1
	s.cracks = {Vector2i(9, 5): 3}
	s = _act(s, "step", 4, Vector2i(9, 5))
	_check(s.winner == 0 and s.reason == "flag" and not s.pawns.has(4), "Surviving holder should score after a collapse with survivors on both sides")

	s = _fixture({0: Vector2i(3, 4), 4: Vector2i(7, 6)}, 8, 1)
	s = _act(s, "step", 4, Vector2i(7, 5))
	_check(s.phase == "finished" and s.winner == -1 and s.reason == "round_cap", "Eight-round cap should draw after the second turn")


func _test_shield_blink_sprint() -> void:
	var s := _fixture({0: Vector2i(4, 3), 4: Vector2i(5, 4)})
	_spell(s, 0, "shield")
	s = _act(s, "shield", 0, Vector2i(4, 3))
	_check(s.pawns[0].shield and not s.pawns[0].charged, "Shield activation should spend its charge")
	s = _act(s, "capture", 4, Vector2i(4, 3))
	_check(not s.pawns[0].shield and s.pawns[0].pos == Vector2i(4, 3) and s.pawns[4].pos == Vector2i(5, 4) and s.active == 0, "Shielded capture breaks the shield and spends the turn without moving")
	s = _fixture({0: Vector2i(5, 3), 4: Vector2i(7, 6)})
	_spell(s, 0, "shield")
	s.pawns[0].shield = true
	s = _act(s, "step", 0, s.flag)
	_check(not s.pawns[0].shield, "Entering the flag should remove an active shield")
	s.active = 0
	_check(_find(s, {"kind": "shield", "pawn": 0}).is_empty(), "Shield cannot activate on the flag")

	s = _fixture({0: Vector2i(4, 3), 4: Vector2i(7, 6)})
	_spell(s, 0, "blink")
	s.holes[Vector2i(4, 2)] = true
	s.infected[Vector2i(3, 3)] = 1
	_check(_find(s, {"kind": "blink", "to": s.flag}).is_empty(), "Blink cannot land on the flag")
	_check(_find(s, {"kind": "blink", "to": Vector2i(3, 3)}).is_empty(), "Blink cannot land on infection")
	_check(not _find(s, {"kind": "blink", "to": Vector2i(2, 3)}).is_empty(), "Blink can jump over infection")
	_check(not _find(s, {"kind": "blink", "to": Vector2i(5, 2)}).is_empty(), "Blink must allow a Manhattan-distance-two diagonal")
	s = _act(s, "blink", 0, Vector2i(4, 1))
	_check(s.pawns[0].pos == Vector2i(4, 1) and not s.pawns[0].charged, "Blink can jump over a hole and spends its charge")

	s = _fixture({0: Vector2i(5, 2), 4: Vector2i(5, 3)})
	_spell(s, 0, "sprint")
	_check(_find(s, {"kind": "sprint"}).is_empty(), "Sprint cannot cross an occupied tile")
	s.pawns[4].pos = Vector2i(7, 6)
	s.infected[Vector2i(5, 3)] = 1
	_check(_find(s, {"kind": "sprint"}).is_empty(), "Sprint cannot cross infection")
	s.infected.clear()
	s.holes[Vector2i(5, 3)] = true
	_check(_find(s, {"kind": "sprint"}).is_empty(), "Sprint cannot cross a hole")
	s.holes.clear()
	s = _act(s, "sprint", 0, s.flag)
	_check(s.holder == 0 and not s.pawns[0].charged, "Sprint can claim the flag")
	s = _fixture({0: Vector2i(5, 3), 4: Vector2i(7, 6)})
	_spell(s, 0, "sprint")
	s = _act(s, "sprint", 0, Vector2i(5, 5))
	_check(s.holder == -1, "Crossing the flag without stopping does not claim it")


func _borrow_fixture() -> Dictionary:
	var s := _fixture({0: Vector2i(3, 3), 1: Vector2i(5, 3), 2: Vector2i(4, 2), 4: Vector2i(6, 5)})
	_spell(s, 0, "borrow_tomorrow")
	_check(_find(s, {"kind": "borrow_tomorrow", "to": s.flag}).is_empty(), "Borrowed pawn cannot end on the flag")
	return s


func _test_borrow() -> void:
	var adjacent := _fixture({0: Vector2i(4, 4), 1: Vector2i(4, 3), 4: Vector2i(7, 6)})
	_spell(adjacent, 0, "borrow_tomorrow")
	_invalid(adjacent, {"kind": "borrow_tomorrow", "pawn": 0, "to": Vector2i(3, 4), "token": false, "second": 1, "second_to": Vector2i(3, 4)}, "Invalid compound step must preserve the full match and charge")
	adjacent = _act(adjacent, "borrow_tomorrow", 0, Vector2i(3, 4), {"second": 1, "second_to": Vector2i(4, 4)})
	_check(adjacent.pawns[1].pos == Vector2i(4, 4) and adjacent.pawns[0].borrow.get("origin") == Vector2i(4, 4), "Borrow's second step must use the updated occupancy and may enter the echo")

	var s := _borrow_fixture()
	var origin := Vector2i(3, 3)
	var move := {"second": 1, "second_to": s.flag}
	s = _act(s, "borrow_tomorrow", 0, Vector2i(3, 4), move)
	_check(s.pawns[0].pos == Vector2i(3, 4) and s.pawns[0].borrow.get("origin") == origin and not s.pawns[0].charged, "Borrow should move its assigned pawn and store the echo")
	_check(s.holder == 1 and s.replies == 0, "Second pawn may claim the flag with Borrow")
	s = _act(s, "step", 4, Vector2i(6, 4))
	_check(s.pawns[0].pos == Vector2i(3, 4) and s.replies == 1, "Borrow must survive the intervening enemy turn")
	_check(_find(s, {"pawn": 0}).is_empty(), "A borrowed pawn must be unavailable on its owner's next turn")
	s.move_die = "forward"
	var occupied := s.duplicate(true)
	occupied.pawns[2].pos = origin
	var clearing := occupied.duplicate(true)
	clearing.move_die = "wild"
	var cleared := _act(clearing, "step", 2, Vector2i(3, 2), {"token": false})
	_check(cleared.pawns.has(0) and cleared.pawns[0].pos == origin and cleared.pawns[0].borrow.is_empty(), "Moving a blocker away before the return clears the echo")
	var blocked := _act(occupied, "step", 1, Vector2i(5, 5))
	_check(not blocked.pawns.has(0), "Occupied echo should remove the returning pawn")
	var infected := s.duplicate(true)
	infected.infected[origin] = 2
	infected = _act(infected, "step", 2, Vector2i(4, 3))
	_check(not infected.pawns.has(0), "Infected echo should remove the returning pawn")
	s = _act(s, "step", 2, Vector2i(4, 3))
	_check(s.pawns[0].pos == origin and s.pawns[0].borrow.is_empty(), "Clear echo should return the borrowed pawn at the due turn's end")

	s = _borrow_fixture()
	s.pawns[4].pos = Vector2i(4, 5)
	s = _act(s, "borrow_tomorrow", 0, Vector2i(3, 4), move)
	s = _act(s, "capture", 4, Vector2i(3, 4))
	_check(not s.pawns.has(0), "Borrowed pawn can be captured during the intervening turn")
	s.move_die = "forward"
	s = _act(s, "step", 2, Vector2i(4, 3))
	_check(not s.pawns.has(0), "Capturing a borrower cancels its return")

	s = _fixture({0: Vector2i(7, 3), 4: Vector2i(1, 5), 5: Vector2i(4, 5)}, 2, 1)
	_spell(s, 4, "borrow_tomorrow")
	s = _act(s, "borrow_tomorrow", 4, Vector2i(2, 5), {"second": 5, "second_to": Vector2i(4, 4)})
	_check(s.cracks.has(Vector2i(1, 5)) and not s.holes.has(Vector2i(1, 5)), "Borrow origin must remain playable through the warned round")
	s.move_die = "forward"
	s = _act(s, "step", 0, Vector2i(7, 4))
	var transition := _commit(s, {"kind": "step", "pawn": 5, "to": Vector2i(4, 3), "token": false})
	_check(not transition.state.pawns.has(4) and transition.state.holes.has(Vector2i(1, 5)), "Return happens before the origin drops and removes the borrower")
	var return_index := -1
	var collapse_index := -1
	for i in range(transition.events.size()):
		var event: Dictionary = transition.events[i]
		if event.get("pawn") == 4 and event.get("to") == Vector2i(1, 5):
			return_index = i
		if Vector2i(1, 5) in event.get("tiles", []):
			collapse_index = i
	_check(return_index >= 0 and collapse_index > return_index, "Return should animate before the simultaneous collapse")

	s = _fixture({0: Vector2i(1, 4), 1: Vector2i(4, 3), 4: Vector2i(7, 6)}, 3)
	_spell(s, 0, "borrow_tomorrow")
	s.cracks = {Vector2i(1, 4): 3}
	s = _act(s, "borrow_tomorrow", 0, Vector2i(2, 4), {"second": 1, "second_to": Vector2i(4, 4)})
	s = _act(s, "step", 4, Vector2i(7, 5))
	s.move_die = "forward"
	s = _act(s, "step", 1, Vector2i(4, 5))
	_check(not s.pawns.has(0), "A previously fallen echo should remove the returning pawn")


func _test_round_effects() -> void:
	var s := _fixture({0: Vector2i(4, 3), 4: Vector2i(5, 3)}, 2)
	s.special = "infected_trail"
	s.move_die = "right"
	s = _act(s, "infected_trail", 0, Vector2i(4, 4), {"token": true})
	_check(s.infected.has(Vector2i(4, 3)) and s.tokens[0] == 1, "Infected Trail should spend a selected Forward token")
	_check(_find(s, {"to": Vector2i(4, 3)}).is_empty(), "Both sides must avoid an infected tile during the enemy reply")
	s = _act(s, "step", 4, Vector2i(6, 3))
	_check(s.infected.is_empty(), "Infection should expire after the next enemy turn")

	s = _fixture({0: Vector2i(5, 4), 4: Vector2i(7, 6)}, 2)
	s.special = "infected_trail"
	s.replies = 1
	s = _act(s, "infected_trail", 0, Vector2i(5, 5), {"token": false})
	_check(s.infected.is_empty() and s.holder == -1 and s.replies == 0, "Trail cannot infect the flag when its holder leaves")

	s = _fixture({0: Vector2i(3, 3), 4: Vector2i(5, 3), 5: Vector2i(6, 3)}, 4)
	_spell(s, 4, "shield")
	s.special = "spy"
	s.move_die = "left"
	_check(_find(s, {"kind": "spy", "mark": 5}).is_empty(), "Spy range is checked before movement")
	s = _act(s, "spy", 0, Vector2i(3, 4), {"mark": 4, "base": "step", "token": true})
	_check(s.pawns[4].spy and s.tokens[0] == 1, "Spy token step applies its mark and spends the shared token")
	_check(_find(s, {"kind": "shield", "pawn": 4}).is_empty() and s.pawns[4].charged, "Spy suppresses activation without spending the draft charge")
	s = _act(s, "step", 4, Vector2i(4, 3))
	_check(not s.pawns[4].spy and s.pawns[4].charged, "Spy should expire after the marked side's next turn")

	s = _fixture({0: Vector2i(3, 4), 4: Vector2i(4, 3)}, 4)
	s.special = "spy"
	s.move_die = "wild"
	_spell(s, 4, "shield")
	s.pawns[4].borrow = {"origin": Vector2i(6, 3), "due": 7}
	s = _act(s, "spy", 0, Vector2i(4, 4), {"mark": 4, "base": "step", "token": false})
	s = _commit(s, PASS).state
	_check(s.pawns[4].pos == Vector2i(6, 3) and not s.pawns[4].spy and s.pawns[4].charged, "Spy should expire on pass and leave a scheduled Borrow return intact")

	s = _fixture({0: Vector2i(3, 3), 4: Vector2i(4, 4)}, 4)
	s.special = "spy"
	s.pawns[4].shield = true
	s = _act(s, "spy", 0, Vector2i(4, 4), {"mark": 4, "base": "capture", "token": false})
	_check(s.pawns[4].spy and not s.pawns[4].shield and s.pawns[0].pos == Vector2i(3, 3), "Spy capture should mark and be intercepted by a preexisting Shield")

	s = _fixture({0: Vector2i(3, 4), 4: Vector2i(7, 4)}, 6)
	s.special = "wormhole"
	_check(_find(s, {"kind": "wormhole"}).is_empty(), "Occupied Wormhole exit should prevent jump")
	s.pawns[4].pos = Vector2i(6, 5)
	s.infected[Vector2i(7, 4)] = 11
	_check(_find(s, {"kind": "wormhole"}).is_empty(), "Infected Wormhole exit should prevent jump")
	s.infected.clear()
	s = _act(s, "wormhole", 0, Vector2i(7, 4))
	_check(s.pawns[0].pos == Vector2i(7, 4) and s.tokens == [2, 2], "Wormhole should jump between portals without a token")
	s = _act(s, "capture", 4, Vector2i(7, 4))
	_check(s.phase == "finished" and s.winner == 1 and s.reason == "elimination", "Opponent can capture a pawn at a portal normally")


func _test_seeded_replays() -> void:
	for seed_value in [90, 137, 4021, 46109, 131001]:
		var initial := Rules.create_match(seed_value)
		var s := initial
		var actions: Array[Dictionary] = []
		var event_log: Array = []
		for i in range(18):
			if s.phase == "finished":
				break
			var legal := Rules.legal_actions(s)
			_check(legal == Rules.legal_actions(s) and not legal.is_empty(), "Legal-action order must be stable and nonempty before a result")
			if legal.is_empty():
				break
			var action: Dictionary = legal[(seed_value + 17 * i) % legal.size()]
			actions.append(action)
			var transition := Rules.apply_action(s, action)
			_check(transition.ok, "Replay fixture produced an invalid listed action")
			event_log.append(transition.events)
			s = transition.state
		_check(s.phase == "finished", "A complete match must end within eighteen draft/turn actions")
		var replay := Rules.create_match(seed_value)
		for i in range(actions.size()):
			var transition := Rules.apply_action(replay, actions[i])
			_check(transition.ok and transition.events == event_log[i], "Replay event stream diverged")
			replay = transition.state
		_check(replay == s and initial == Rules.create_match(seed_value), "Replay state or RNG diverged")


func _test_bot() -> void:
	var s := Rules.create_match(721)
	var draft := Bot.choose(s, Rules.legal_actions(s))
	_check(draft.pawns == [1, 3] and draft.spells == ["sprint", "borrow_tomorrow"], "Bot draft should assign Sprint to middle front and Borrow to rear")

	s = _fixture({0: Vector2i(4, 3), 1: Vector2i(3, 3), 4: Vector2i(5, 4), 5: Vector2i(7, 6)})
	s.replies = 1
	var choice := Bot.choose(s, Rules.legal_actions(s))
	_check(choice.kind == "capture" and choice.pawn == 0 and choice.to == s.flag, "Bot should immediately contest a flag that would otherwise win")

	s = _fixture({0: Vector2i(1, 3), 4: Vector2i(7, 6)}, 3)
	s.move_die = "left"
	s.cracks[Vector2i(1, 3)] = 3
	choice = Bot.choose(s, Rules.legal_actions(s))
	_check(choice.kind == "step" and choice.to == Vector2i(2, 3), "Bot should save its final pawn from a scheduled drop")

	var result_counts := {}
	var effect_counts := {}
	var first_flag_rounds: Array[int] = []
	var total_turns := 0
	var max_decision_usec := 0
	for seed_value in [581, 1237, 14863, 18441, 59186, 89881, 123001, 191203]:
		s = Rules.create_match(seed_value)
		var first_flag := 0
		for i in range(18):
			if s.phase == "finished":
				break
			var options := Rules.legal_actions(s)
			var snapshot := s.duplicate(true)
			var decision_started := Time.get_ticks_usec()
			choice = Bot.choose(s, options)
			max_decision_usec = maxi(max_decision_usec, Time.get_ticks_usec() - decision_started)
			_check(choice in options and s == snapshot, "Bot must select a listed action without mutating its input or RNG")
			if s.phase == "playing":
				total_turns += 1
				effect_counts[choice.kind] = int(effect_counts.get(choice.kind, 0)) + 1
				if s.turn == 1:
					var alternate := s.duplicate(true)
					alternate.rng = 9001
					_check(Bot.choose(alternate, options) == choice, "Bot on the second turn should not use hidden future rolls")
			var acted_round: int = s.round
			var result := Rules.apply_action(s, choice)
			s = result.state
			if first_flag == 0 and s.holder != -1:
				first_flag = acted_round
		_check(s.phase == "finished", "Bot-vs-bot match exceeded turn cap")
		first_flag_rounds.append(first_flag)
		result_counts[s.reason] = int(result_counts.get(s.reason, 0)) + 1
	print("Automated bot matches: 8 | outcomes: %s | total turns: %d | first flag rounds (0 = none): %s" % [result_counts, total_turns, first_flag_rounds])
	print("Bot action counts: %s | longest decision: %.2f ms" % [effect_counts, max_decision_usec / 1000.0])
