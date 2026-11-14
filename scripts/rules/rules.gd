extends RefCounted
## Deterministic match state and transitions. All coordinates are one-based.

const SPELLS := ["shield", "fracture", "teleport"]
const SPECIALS := ["infected_trail", "spy", "long_capture"]
const BOARD_SIZE := 9
const PAWNS_PER_SIDE := 5
const FLAG_REPLIES := 3
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DIAGONALS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
const SIDE_NAMES := ["Aliens", "Crew"]
const RNG_RANGE := 2147483646
const Drift = preload("res://scripts/rules/drift.gd")


static func create_match(seed_value: int, first_override: int = -1) -> Dictionary:
	var state := {
		"phase": "draft", "seed": seed_value, "rng": posmod(seed_value, RNG_RANGE) + 1,
		"first": 0, "active": 0, "round": 1, "turn": 0, "flag": Vector2i(5, 5),
		"holder": -1, "replies": 0, "holes": {}, "cracks": {}, "infected": {}, "fractures": {},
		"pawns": {}, "dice": ["", ""], "rolls": [0, 0], "turn_move": false,
		"turn_power_used": false, "turn_mark": -1, "winner": -1,
		"reason": "", "_draft": [],
	}
	var random_first := _roll(state, 2)
	state.first = first_override if first_override in [0, 1] else random_first
	for side in 2:
		for index in PAWNS_PER_SIDE:
			var id := side * PAWNS_PER_SIDE + index
			state.pawns[id] = {
				"id": id, "side": side, "owner": side, "pos": Vector2i(3 + index, 2 if side == 0 else 8),
				"ability": "", "charged": false, "shield": false, "spy": 0,
			}
	return state


static func create_drift_match(seed_value: int, first_override: int, layout: int, focus: int) -> Dictionary:
	var state := create_match(seed_value, first_override)
	state.phase = "playing"
	state.active = state.first
	state.flag = Vector2i.ZERO
	for pawn: Dictionary in state.pawns.values():
		pawn.pos.y = 1 if pawn.side == 0 else BOARD_SIZE
	state.drift = {
		"layout": layout, "relays": Drift.relays(layout, posmod(seed_value, 2) == 1),
		"scores": [0, 0], "focus": focus,
	}
	return state


static func legal_actions(state: Dictionary) -> Array[Dictionary]:
	if state.phase == "draft":
		return _draft_actions(state)
	var actions: Array[Dictionary] = []
	if state.phase != "playing":
		return actions
	var side: int = state.active
	var occupancy := _occupancy(state)
	if state.has("drift"):
		actions = _normal_actions(state, occupancy)
		if actions.is_empty():
			actions.append({"kind": "pass"})
		return actions
	if state.dice[side].is_empty():
		actions.append({"kind": "roll"})
	else:
		if not state.turn_move and not state.turn_power_used:
			actions.append_array(_normal_actions(state, occupancy))
			for id in state.pawns:
				var pawn: Dictionary = state.pawns[id]
				if pawn.side != side:
					continue
				actions.append_array(_drafted_actions(state, pawn, occupancy))
		if not state.turn_power_used:
			actions.append_array(_dice_power_actions(state))
	actions.append({"kind": "skip"})
	return actions


static func apply_action(state: Dictionary, action: Dictionary) -> Dictionary:
	if action not in legal_actions(state):
		return {"state": state, "events": [], "ok": false}
	return apply_legal_action(state, action)


## For simulation of an action already enumerated for this exact state.
static func apply_legal_action(state: Dictionary, action: Dictionary, report_events: bool = true) -> Dictionary:
	var next := state.duplicate(true)
	var events: Array[Dictionary] = []
	if next.has("drift"):
		_play_drift_turn(next, action, events, report_events)
	elif next.phase == "draft":
		_lock_draft(next, action, events)
	elif action.kind == "roll":
		var pip := _roll(next, 6) + 1
		var face: String = SPECIALS[(pip - 1) % SPECIALS.size()]
		next.dice[next.active] = face
		next.rolls[next.active] = pip
		_event(events, "roll", "%s rolled %d · %s." % [SIDE_NAMES[next.active], pip, face.capitalize()],
			{"round": next.round, "special": face, "side": next.active, "pip": pip})
	else:
		if action.kind == "skip":
			_play_turn(next, events)
		else:
			_resolve_action(next, action, events)
	return {"state": next, "events": events, "ok": true}


static func _play_drift_turn(state: Dictionary, action: Dictionary, events: Array[Dictionary], report: bool) -> void:
	if action.kind != "pass":
		_resolve_action(state, action, events)
	if state.turn == 0:
		state.active = 1 - state.active
		state.turn = 1
		if report:
			_turn_event(state, events)
		return

	var points := [0, 0]
	for pawn: Dictionary in state.pawns.values():
		var origin: Vector2i = pawn.pos
		pawn.pos = Drift.landing(origin, BOARD_SIZE)
		if report and origin != pawn.pos:
			events.append({"kind": "drift_move", "pawn": pawn.id, "from": origin, "to": pawn.pos})
	var occupied := _occupancy(state)
	var relocations := PackedStringArray()
	for i in state.drift.relays.size():
		var relay: Vector2i = state.drift.relays[i]
		if relay not in occupied:
			continue
		var side: int = state.pawns[occupied[relay]].side
		points[side] += 1
		var destination := Drift.relocate(relay, BOARD_SIZE, occupied)
		state.drift.relays[i] = destination
		if report:
			relocations.append("%s → %s" % [_tile(relay), _tile(destination)])
	for side in 2:
		state.drift.scores[side] += points[side]
	if report:
		if not relocations.is_empty():
			_event(events, "relay_relocated", "Relays moved · %s." % " / ".join(relocations))
		_event(events, "drift_score", "Rows shifted · Aliens +%d / Crew +%d." % points)

	var totals := [Drift.total(state, 0), Drift.total(state, 1)]
	var reached_goal := [totals[0] >= Drift.TOTAL_TO_WIN, totals[1] >= Drift.TOTAL_TO_WIN]
	if reached_goal[0] and reached_goal[1]:
		_finish(state, -1, "drift_tie")
	elif reached_goal[0]:
		_finish(state, 0, "relays")
	elif reached_goal[1]:
		_finish(state, 1, "relays")
	elif state.round == Drift.ROUND_LIMIT:
		_finish(state, -1, "drift_limit")
	if state.phase == "finished":
		if report:
			var message := "The circuit ended in a draw." if state.winner == -1 else "%s won the relay race." % SIDE_NAMES[state.winner]
			_event(events, "result", message, {"side": state.winner, "reason": state.reason})
		return
	state.active = state.first
	state.turn = 0
	state.round += 1
	if report:
		_turn_event(state, events)


static func ability_reason(state: Dictionary, pawn: Dictionary) -> String:
	if pawn.ability.is_empty():
		return "No drafted ability"
	if not pawn.charged:
		return "Charge spent"
	if pawn.spy:
		return "A stolen pawn keeps its charge for its original side."
	if not _drafted_actions(state, pawn, _occupancy(state)).is_empty():
		return ""
	match pawn.ability:
		"shield": return "Shield cannot activate on the flag"
		"fracture": return "No intact tile available to fracture"
		"teleport": return "No open landing tile available"
	return "Ability unavailable"


static func _roll(state: Dictionary, faces: int) -> int:
	# Park-Miller generator with rejection sampling to avoid modulo bias.
	var limit := RNG_RANGE - RNG_RANGE % faces
	while true:
		state.rng = (int(state.rng) * 48271) % (RNG_RANGE + 1)
		var sample: int = state.rng - 1
		if sample < limit:
			return sample % faces
	return 0


static func _forward(side: int) -> int:
	return 1 if side == 0 else -1


static func _serial(state: Dictionary) -> int:
	return (int(state.round) - 1) * 2 + int(state.turn)


static func _occupancy(state: Dictionary) -> Dictionary:
	var occupancy := {}
	for id in state.pawns:
		occupancy[state.pawns[id].pos] = id
	return occupancy


static func _enterable(state: Dictionary, target: Vector2i) -> bool:
	return (target.x >= 1 and target.x <= BOARD_SIZE and target.y >= 1 and target.y <= BOARD_SIZE
		and not state.holes.has(target) and not state.infected.has(target))


static func _empty(state: Dictionary, occupancy: Dictionary, target: Vector2i) -> bool:
	return _enterable(state, target) and not occupancy.has(target)


static func _move(kind: String, id: int, target: Vector2i) -> Dictionary:
	return {"kind": kind, "pawn": id, "to": target}


static func _normal_actions(state: Dictionary, occupancy: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var side: int = state.active
	var forward := _forward(side)
	for id in state.pawns:
		var pawn: Dictionary = state.pawns[id]
		if pawn.side != side:
			continue
		var origin: Vector2i = pawn.pos
		for offset: Vector2i in DIRECTIONS + DIAGONALS:
			var target := origin + offset
			if _empty(state, occupancy, target):
				actions.append(_move("step", id, target))
			if offset.x != 0 and offset.y != 0:
				target = origin + 2 * offset
				if target != state.flag and _empty(state, occupancy, target):
					actions.append(_move("step", id, target))
		for dx in [-1, 1]:
			var target := origin + Vector2i(dx, forward)
			if _enemy_at(state, occupancy, pawn, target):
				actions.append(_move("capture", id, target))
	return actions


static func _enemy_at(state: Dictionary, occupancy: Dictionary, pawn: Dictionary, target: Vector2i) -> bool:
	return (_enterable(state, target) and occupancy.has(target)
		and state.pawns[occupancy[target]].side != pawn.side
		and (target != state.flag or pawn.spy == 0))


static func _draft_actions(state: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var start: int = state.active * PAWNS_PER_SIDE
	for id in range(start, start + PAWNS_PER_SIDE):
		for second in range(id + 1, start + PAWNS_PER_SIDE):
			for spell: String in SPELLS:
				for other: String in SPELLS:
					if spell != other:
						actions.append({"kind": "draft", "pawns": [id, second], "spells": [spell, other]})
	return actions


static func _drafted_actions(state: Dictionary, pawn: Dictionary, occupancy: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not pawn.charged or pawn.spy:
		return actions
	var origin: Vector2i = pawn.pos
	match pawn.ability:
		"shield":
			if origin != state.flag:
				actions.append(_move("shield", pawn.id, origin))
		"teleport", "fracture":
			for y in range(1, BOARD_SIZE + 1):
				for x in range(1, BOARD_SIZE + 1):
					var target := Vector2i(x, y)
					if target == state.flag or target in state.holes:
						continue
					if pawn.ability == "teleport" and not _empty(state, occupancy, target):
						continue
					if pawn.ability == "fracture" and target in state.fractures:
						continue
					actions.append(_move(pawn.ability, pawn.id, target))
	return actions


static func _dice_power_actions(state: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var occupancy := _occupancy(state)
	match state.dice[state.active]:
		"infected_trail":
			for pawn: Dictionary in state.pawns.values():
				if pawn.side == state.active:
					actions.append({"kind": "infected_trail", "pawn": pawn.id, "to": pawn.pos})
		"spy":
			for id in _spy_targets(state):
				actions.append({"kind": "spy", "mark": id})
		"long_capture":
			for pawn: Dictionary in state.pawns.values():
				if pawn.side != state.active:
					continue
				for offset: Vector2i in DIAGONALS:
					for distance in [1, 2]:
						var target: Vector2i = pawn.pos + offset * distance
						if _enemy_at(state, occupancy, pawn, target):
							actions.append({"kind": "long_capture", "pawn": pawn.id, "to": target})
	return actions


static func _spy_targets(state: Dictionary) -> Array[int]:
	var targets: Array[int] = []
	for id in state.pawns:
		var enemy: Dictionary = state.pawns[id]
		if enemy.side == state.active or enemy.spy > 0:
			continue
		for friendly: Dictionary in state.pawns.values():
			var offset: Vector2i = enemy.pos - friendly.pos
			if friendly.side == state.active and absi(offset.x) + absi(offset.y) <= 2:
				targets.append(id)
				break
	return targets


static func _event(events: Array[Dictionary], kind: String, message: String, fields: Dictionary = {}) -> void:
	var event := {"kind": kind, "text": message}
	event.merge(fields)
	events.append(event)


static func _lock_draft(state: Dictionary, action: Dictionary, events: Array[Dictionary]) -> void:
	var side: int = state.active
	state._draft.append(action.duplicate(true))
	_event(events, "draft_lock", "%s locked their draft." % SIDE_NAMES[side], {"side": side})
	if state._draft.size() < 2:
		state.active = 1
		return
	for draft: Dictionary in state._draft:
		for index in 2:
			var pawn: Dictionary = state.pawns[draft.pawns[index]]
			pawn.ability = draft.spells[index]
			pawn.charged = true
	state._draft.clear()
	state.phase = "playing"
	state.active = state.first
	_event(events, "draft_reveal", "Both drafts revealed.")
	_start_round(state, events)


static func _start_round(state: Dictionary, events: Array[Dictionary]) -> void:
	state.dice = ["", ""]
	state.rolls = [0, 0]
	state.turn_move = false
	state.turn_power_used = false
	state.turn_mark = -1
	_warn_rim(state, events)
	_turn_event(state, events)


static func _warn_rim(state: Dictionary, events: Array[Dictionary]) -> void:
	if state.round < 2 or state.round > 5:
		return
	var inset := 0 if state.round <= 3 else 1
	var candidates: Array[Vector2i] = []
	var pair_only: bool = state.round % 2 == 0
	for y in range(1 + inset, BOARD_SIZE + 1 - inset):
		for x in range(1 + inset, BOARD_SIZE + 1 - inset):
			var pos := Vector2i(x, y)
			var on_rim := x in [1 + inset, BOARD_SIZE - inset] or y in [1 + inset, BOARD_SIZE - inset]
			if on_rim and not state.holes.has(pos) and (not pair_only or y < 5 or (y == 5 and x < 5)):
				candidates.append(pos)
	var warned: Array[Vector2i] = candidates
	if pair_only:
		var picked := candidates[_roll(state, candidates.size())]
		warned = [picked, Vector2i(10, 10) - picked]
	for pos in warned:
		state.cracks[pos] = state.round
	_event(events, "warning", "%d cracked tiles will fall after both turns." % warned.size(), {"tiles": warned})


static func _turn_event(state: Dictionary, events: Array[Dictionary]) -> void:
	_event(events, "turn", "%s to move." % SIDE_NAMES[state.active], {"side": state.active})


static func _play_turn(state: Dictionary, events: Array[Dictionary]) -> void:
	var side: int = state.active
	_event(events, "skip", "%s ended the turn." % SIDE_NAMES[side], {"side": side})
	_collapse(state, events)
	_check_elimination(state)
	if state.phase == "playing" and state.holder != -1 and state.pawns[state.holder].side != side:
		state.replies += 1
		_flag_event(state, events)
		if state.replies == FLAG_REPLIES:
			_finish(state, state.pawns[state.holder].side, "flag")
	_expire_effects(state, events)
	if state.phase == "playing" and state.round == 8 and state.turn == 1:
		_finish(state, -1, "round_cap")
	if state.phase == "finished":
		_result_event(state, events)
		return
	state.active = 1 - side
	state.turn_move = false
	state.turn_power_used = false
	state.turn_mark = -1
	if state.turn == 0:
		state.turn = 1
		_turn_event(state, events)
	else:
		state.turn = 0
		state.round += 1
		_start_round(state, events)


static func _resolve_action(state: Dictionary, action: Dictionary, events: Array[Dictionary]) -> void:
	var kind: String = action.kind
	if kind in SPECIALS:
		_resolve_dice_power(state, action, events)
		state.turn_power_used = true
		if kind == "spy":
			state.turn_mark = action.mark
		return
	var pawn: Dictionary = state.pawns[action.pawn]
	var origin: Vector2i = pawn.pos
	var target: Vector2i = action.to
	if kind in SPELLS:
		pawn.charged = false
	if kind in SPELLS or kind in SPECIALS:
		_event(events, "ability", "%s used %s." % [SIDE_NAMES[state.active], kind.capitalize()],
			{"pawn": pawn.id, "from": origin, "to": target, "ability": kind, "side": pawn.side})
	match kind:
		"shield":
			pawn.shield = true
		"capture":
			_capture(state, pawn, target, events)
		"fracture":
			state.fractures[target] = _serial(state) + 1
			_event(events, "fracture", "%s will fall after the next turn." % _tile(target), {"tiles": [target], "to": target})
		_:
			_shift(state, pawn, target, "step", events)
	state.turn_move = true


static func _resolve_dice_power(state: Dictionary, power: Dictionary, events: Array[Dictionary]) -> void:
	var kind: String = power.kind
	var pawn: Dictionary = state.pawns[power.pawn] if kind in ["infected_trail", "long_capture"] else {}
	_event(events, "ability", "%s used %s." % [SIDE_NAMES[state.active], kind.replace("_", " ").capitalize()],
		{"pawn": pawn.get("id", -1), "from": pawn.get("pos", Vector2i.ZERO), "ability": kind, "side": state.active})
	match kind:
		"infected_trail":
			var origin: Vector2i = pawn.pos
			var infected: Array[Vector2i] = []
			for y in range(origin.y - 1, origin.y + 2):
				for x in range(origin.x - 1, origin.x + 2):
					var tile := Vector2i(x, y)
					if tile != state.flag and tile.x in range(1, BOARD_SIZE + 1) and tile.y in range(1, BOARD_SIZE + 1) and tile not in state.holes:
						state.infected[tile] = _serial(state) + 1
						infected.append(tile)
			_event(events, "infection", "The area around %s is infected through the next enemy turn." % _tile(origin), {"tiles": infected})
		"spy":
			var marked: Dictionary = state.pawns[power.mark]
			marked.side = state.active
			marked.spy = 3
			if state.holder == marked.id:
				_set_holder(state, -1, events)
			_event(events, "spy", "%s took control of the pawn at %s for three turns." % [SIDE_NAMES[state.active], _tile(marked.pos)],
				{"pawn": marked.id, "to": marked.pos, "side": marked.side})
		"long_capture":
			_capture(state, pawn, power.to, events)


static func _capture(state: Dictionary, pawn: Dictionary, target: Vector2i, events: Array[Dictionary]) -> void:
	var victim_id: int = _occupancy(state)[target]
	var victim: Dictionary = state.pawns[victim_id]
	if victim.shield:
		victim.shield = false
		_event(events, "shield_break", "Shield at %s broke. Both pawns stayed in place." % _tile(target),
			{"pawn": pawn.id, "from": pawn.pos, "to": target, "victim": victim_id})
		return
	state.pawns.erase(victim_id)
	_shift(state, pawn, target, "capture", events, {"victim": victim_id})


static func _shift(state: Dictionary, pawn: Dictionary, target: Vector2i, kind: String, events: Array[Dictionary], extra: Dictionary = {}) -> void:
	var origin: Vector2i = pawn.pos
	pawn.pos = target
	var message := "%s moved to %s." % [SIDE_NAMES[pawn.side], _tile(target)]
	match kind:
		"capture": message = "%s captured on %s." % [SIDE_NAMES[pawn.side], _tile(target)]
	var fields := {"pawn": pawn.id, "from": origin, "to": target, "side": pawn.side}
	fields.merge(extra)
	_event(events, kind, message, fields)
	if origin == state.flag or target == state.flag:
		var holder: int = pawn.id if target == state.flag and pawn.spy == 0 else -1
		if target == state.flag:
			pawn.shield = false
		_set_holder(state, holder, events)


static func _set_holder(state: Dictionary, holder: int, events: Array[Dictionary]) -> void:
	if state.holder == holder:
		return
	state.holder = holder
	state.replies = 0
	_flag_event(state, events)


static func _flag_event(state: Dictionary, events: Array[Dictionary]) -> void:
	var side := -1
	var message := "The flag is unclaimed."
	if state.holder != -1:
		side = state.pawns[state.holder].side
		message = "%s flag hold: %d/%d replies." % [SIDE_NAMES[side], state.replies, FLAG_REPLIES]
	_event(events, "flag", message, {"pawn": state.holder, "to": state.flag, "side": side, "replies": state.replies})


static func _collapse(state: Dictionary, events: Array[Dictionary]) -> void:
	var dropped: Array[Vector2i] = []
	if state.turn == 1:
		for tile: Vector2i in state.cracks:
			if state.cracks[tile] == state.round:
				dropped.append(tile)
	for tile: Vector2i in state.fractures:
		if state.fractures[tile] <= _serial(state) and tile not in dropped:
			dropped.append(tile)
	if dropped.is_empty():
		return
	for tile in dropped:
		state.holes[tile] = true
		state.cracks.erase(tile)
		state.fractures.erase(tile)
		state.infected.erase(tile)
	var removed: Array[int] = []
	for id in state.pawns.keys():
		if state.pawns[id].pos in dropped:
			state.pawns.erase(id)
			removed.append(id)
	_event(events, "collapse", "%d tiles fell. Pawns lost: %d." % [dropped.size(), removed.size()],
		{"tiles": dropped, "removed": removed})
	if state.holder in removed:
		_set_holder(state, -1, events)


static func _check_elimination(state: Dictionary) -> void:
	var alive := [false, false]
	for pawn: Dictionary in state.pawns.values():
		alive[pawn.owner] = true
	if not alive[0] and not alive[1]:
		_finish(state, -1, "mutual_elimination")
	elif not alive[0] or not alive[1]:
		_finish(state, 0 if alive[0] else 1, "elimination")


static func _expire_effects(state: Dictionary, events: Array[Dictionary]) -> void:
	for tile: Vector2i in state.infected.keys():
		if state.infected[tile] <= _serial(state):
			state.infected.erase(tile)
			_event(events, "infection_expired", "Infection cleared at %s." % _tile(tile), {"tiles": [tile]})
	var marked_id: int = state.turn_mark
	for pawn: Dictionary in state.pawns.values():
		if pawn.side != state.active or pawn.spy == 0 or pawn.id == marked_id:
			continue
		pawn.spy -= 1
		if pawn.spy == 0:
			pawn.side = pawn.owner
			_event(events, "spy_expired", "The pawn at %s returned to %s." % [_tile(pawn.pos), SIDE_NAMES[pawn.side]],
				{"pawn": pawn.id, "to": pawn.pos, "side": pawn.side})
			if pawn.pos == state.flag:
				_set_holder(state, pawn.id, events)


static func _finish(state: Dictionary, winner: int, reason: String) -> void:
	state.phase = "finished"
	state.winner = winner
	state.reason = reason


static func _result_event(state: Dictionary, events: Array[Dictionary]) -> void:
	var winner: int = state.winner
	var reason: String = state.reason
	var message: String
	match reason:
		"flag": message = "%s win by holding the flag." % SIDE_NAMES[winner]
		"elimination": message = "%s win by elimination." % SIDE_NAMES[winner]
		"mutual_elimination": message = "Draw. Both sides lost their final pawn."
		_: message = "Draw. The eighth round ended."
	_event(events, "result", message, {"side": winner, "reason": reason})


static func _tile(pos: Vector2i) -> String:
	return "%s%d" % [String.chr(64 + pos.x), pos.y]
