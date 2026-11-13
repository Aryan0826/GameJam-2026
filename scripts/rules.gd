extends RefCounted
## Deterministic match state and transitions. All coordinates are one-based.

const SPELLS := ["shield", "blink", "sprint", "borrow_tomorrow"]
const SPECIALS := ["infected_trail", "spy", "wormhole"]
const MOVEMENT := ["forward", "forward", "forward", "left", "right", "wild"]
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const SIDE_NAMES := ["Aliens", "Pilots"]
const RNG_RANGE := 2147483646


static func create_match(seed_value: int, first_override: int = -1) -> Dictionary:
	var state := {
		"phase": "draft", "seed": seed_value, "rng": posmod(seed_value, RNG_RANGE) + 1,
		"first": 0, "active": 0, "round": 1, "turn": 0, "flag": Vector2i.ZERO,
		"holder": -1, "replies": 0, "portals": [], "holes": {}, "cracks": {}, "infected": {},
		"pawns": {}, "tokens": [2, 2], "move_die": "", "special": "", "winner": -1,
		"reason": "", "_draft": [],
	}
	var flag_index := _roll(state, 6)
	var flag := Vector2i(4 + flag_index % 3, 4 if flag_index < 3 else 5)
	state.flag = flag
	state.portals = [Vector2i(3, flag.y), Vector2i(7, flag.y)]
	var random_first := _roll(state, 2)
	state.first = first_override if first_override in [0, 1] else random_first
	for side in 2:
		var toward_rear := -_forward(side)
		for index in 4:
			var id := side * 4 + index
			var offset := Vector2i(index - 1, 2 * toward_rear)
			if index == 3:
				offset = Vector2i(0, 3 * toward_rear)
			state.pawns[id] = {
				"id": id, "side": side, "pos": flag + offset, "ability": "", "charged": false,
				"shield": false, "spy": false, "borrow": {},
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
	var move_actions := _normal_actions(state, occupancy)
	actions.append_array(move_actions)
	for id in state.pawns:
		var pawn: Dictionary = state.pawns[id]
		if pawn.side != side or not pawn.borrow.is_empty():
			continue
		actions.append_array(_drafted_actions(state, pawn, occupancy))
	actions.append_array(_special_actions(state, occupancy, move_actions))
	if actions.is_empty():
		actions.append({"kind": "pass"})
	return actions


static func apply_action(state: Dictionary, action: Dictionary) -> Dictionary:
	if action not in legal_actions(state):
		return {"state": state, "events": [], "ok": false}
	return apply_legal_action(state, action)


## For simulation of an action already enumerated for this exact state.
static func apply_legal_action(state: Dictionary, action: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	var events: Array[Dictionary] = []
	if next.phase == "draft":
		_lock_draft(next, action, events)
	else:
		_play_turn(next, action, events)
	return {"state": next, "events": events, "ok": true}


static func ability_reason(state: Dictionary, pawn: Dictionary) -> String:
	if pawn.ability.is_empty():
		return "No drafted ability"
	if not pawn.charged:
		return "Charge spent"
	if pawn.spy:
		return "Spy disables this ability through this turn"
	if not pawn.borrow.is_empty():
		return "This pawn owes a return"
	if not _drafted_actions(state, pawn, _occupancy(state)).is_empty():
		return ""
	match pawn.ability:
		"shield": return "Shield cannot activate on the flag"
		"blink": return "No open landing tile within two steps"
		"sprint": return "Sprint needs two open forward tiles"
		"borrow_tomorrow":
			if pawn.pos == state.flag:
				return "The borrowed pawn cannot start on the flag"
			return "Borrow Tomorrow needs two legal steps by different pawns"
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
	return (target.x >= 1 and target.x <= 9 and target.y >= 1 and target.y <= 8
		and not state.holes.has(target) and not state.infected.has(target))


static func _empty(state: Dictionary, occupancy: Dictionary, target: Vector2i) -> bool:
	return _enterable(state, target) and not occupancy.has(target)


static func _move(kind: String, id: int, target: Vector2i, token: bool = false) -> Dictionary:
	return {"kind": kind, "pawn": id, "to": target, "token": token}


static func _normal_actions(state: Dictionary, occupancy: Dictionary) -> Array[Dictionary]:
	var rolled_steps: Array[Dictionary] = []
	var fallback_steps: Array[Dictionary] = []
	var extras: Array[Dictionary] = []
	var side: int = state.active
	var forward := _forward(side)
	for id in state.pawns:
		var pawn: Dictionary = state.pawns[id]
		if pawn.side != side or not pawn.borrow.is_empty():
			continue
		var origin: Vector2i = pawn.pos
		for offset: Vector2i in DIRECTIONS:
			var target := origin + offset
			if not _empty(state, occupancy, target):
				continue
			var step := _move("step", id, target)
			fallback_steps.append(step)
			if _fits_die(state.move_die, offset, forward):
				rolled_steps.append(step)
			if offset == Vector2i(0, forward) and state.tokens[side] > 0:
				extras.append(_move("step", id, target, true))
		for dx in [-1, 1]:
			var target := origin + Vector2i(dx, forward)
			if (_enterable(state, target) and occupancy.has(target)
					and state.pawns[occupancy[target]].side != side):
				extras.append(_move("capture", id, target))
	if rolled_steps.is_empty():
		rolled_steps = fallback_steps
	rolled_steps.append_array(extras)
	return rolled_steps


static func _fits_die(face: String, offset: Vector2i, forward: int) -> bool:
	match face:
		"wild": return true
		"forward": return offset == Vector2i(0, forward)
		"left": return offset == Vector2i(forward, 0)
		"right": return offset == Vector2i(-forward, 0)
	return false


static func _draft_actions(state: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var start: int = state.active * 4
	for id in range(start, start + 4):
		for second in range(id + 1, start + 4):
			for spell: String in SPELLS:
				for other: String in SPELLS:
					if spell != other:
						actions.append({"kind": "draft", "pawns": [id, second], "spells": [spell, other]})
	return actions


static func _drafted_actions(state: Dictionary, pawn: Dictionary, occupancy: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not pawn.charged or pawn.spy or not pawn.borrow.is_empty():
		return actions
	var origin: Vector2i = pawn.pos
	match pawn.ability:
		"shield":
			if origin != state.flag:
				actions.append(_move("shield", pawn.id, origin))
		"blink":
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var distance := absi(dx) + absi(dy)
					var target := origin + Vector2i(dx, dy)
					if distance > 0 and distance <= 2 and target != state.flag and _empty(state, occupancy, target):
						actions.append(_move("blink", pawn.id, target))
		"sprint":
			var forward := Vector2i(0, _forward(pawn.side))
			var target := origin + 2 * forward
			if _empty(state, occupancy, origin + forward) and _empty(state, occupancy, target):
				actions.append(_move("sprint", pawn.id, target))
		"borrow_tomorrow":
			if origin != state.flag:
				return _borrow_actions(state, pawn, occupancy)
	return actions


static func _borrow_actions(state: Dictionary, pawn: Dictionary, occupancy: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var origin: Vector2i = pawn.pos
	for offset: Vector2i in DIRECTIONS:
		var target := origin + offset
		if target == state.flag or not _empty(state, occupancy, target):
			continue
		var updated := occupancy.duplicate()
		updated.erase(origin)
		updated[target] = pawn.id
		for id in state.pawns:
			var ally: Dictionary = state.pawns[id]
			if id == pawn.id or ally.side != pawn.side or not ally.borrow.is_empty():
				continue
			for second_offset: Vector2i in DIRECTIONS:
				var second_target: Vector2i = ally.pos + second_offset
				if _empty(state, updated, second_target):
					var action := _move("borrow_tomorrow", pawn.id, target)
					action.second = id
					action.second_to = second_target
					actions.append(action)
	return actions


static func _special_actions(state: Dictionary, occupancy: Dictionary, normal: Array[Dictionary]) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	match state.special:
		"infected_trail":
			for base in normal:
				if base.kind == "step":
					actions.append(_move("infected_trail", base.pawn, base.to, base.token))
		"spy":
			for id in _spy_targets(state):
				for base in normal:
					var action := _move("spy", base.pawn, base.to, base.token)
					action.mark = id
					action.base = base.kind
					actions.append(action)
		"wormhole":
			for portal: Vector2i in state.portals:
				if not occupancy.has(portal):
					continue
				var pawn: Dictionary = state.pawns[occupancy[portal]]
				var destination: Vector2i = state.portals[1] if portal == state.portals[0] else state.portals[0]
				if pawn.side == state.active and pawn.borrow.is_empty() and _empty(state, occupancy, destination):
					actions.append(_move("wormhole", pawn.id, destination))
	return actions


static func _spy_targets(state: Dictionary) -> Array[int]:
	var targets: Array[int] = []
	for id in state.pawns:
		var enemy: Dictionary = state.pawns[id]
		if enemy.side == state.active:
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
	state.move_die = MOVEMENT[_roll(state, MOVEMENT.size())]
	state.special = SPECIALS[_roll(state, SPECIALS.size())] if state.round in [2, 4, 6] else ""
	var special_text := " + %s" % String(state.special).capitalize() if not state.special.is_empty() else ""
	_event(events, "roll", "Round %d rolled %s%s." % [state.round, String(state.move_die).capitalize(), special_text],
		{"round": state.round, "move_die": state.move_die, "special": state.special})
	_warn_rim(state, events)
	_turn_event(state, events)


static func _warn_rim(state: Dictionary, events: Array[Dictionary]) -> void:
	if state.round < 2 or state.round > 5:
		return
	var inset := 0 if state.round <= 3 else 1
	var candidates: Array[Vector2i] = []
	var pair_only: bool = state.round % 2 == 0
	for y in range(1 + inset, 9 - inset):
		for x in range(1 + inset, 10 - inset):
			var pos := Vector2i(x, y)
			var on_rim := x in [1 + inset, 9 - inset] or y in [1 + inset, 8 - inset]
			if on_rim and not state.holes.has(pos) and (not pair_only or y <= 4):
				candidates.append(pos)
	var warned: Array[Vector2i] = candidates
	if pair_only:
		var picked := candidates[_roll(state, candidates.size())]
		warned = [picked, Vector2i(10, 9) - picked]
	for pos in warned:
		state.cracks[pos] = state.round
	_event(events, "warning", "%d cracked tiles will fall after both turns." % warned.size(), {"tiles": warned})


static func _turn_event(state: Dictionary, events: Array[Dictionary]) -> void:
	_event(events, "turn", "%s to move." % SIDE_NAMES[state.active], {"side": state.active})


static func _play_turn(state: Dictionary, action: Dictionary, events: Array[Dictionary]) -> void:
	var side: int = state.active
	_resolve_action(state, action, events)
	_resolve_return(state, events)
	if state.turn == 1:
		_collapse(state, events)
	_check_elimination(state)
	if state.phase == "playing" and state.holder != -1 and state.pawns[state.holder].side != side:
		state.replies += 1
		_flag_event(state, events)
		if state.replies == 2:
			_finish(state, state.pawns[state.holder].side, "flag")
	_expire_effects(state, events)
	if state.phase == "playing" and state.round == 8 and state.turn == 1:
		_finish(state, -1, "round_cap")
	if state.phase == "finished":
		_result_event(state, events)
		return
	state.active = 1 - side
	if state.turn == 0:
		state.turn = 1
		_turn_event(state, events)
	else:
		state.turn = 0
		state.round += 1
		_start_round(state, events)


static func _resolve_action(state: Dictionary, action: Dictionary, events: Array[Dictionary]) -> void:
	var kind: String = action.kind
	if kind == "pass":
		_event(events, "pass", "%s had no legal action." % SIDE_NAMES[state.active], {"side": state.active})
		return
	var pawn: Dictionary = state.pawns[action.pawn]
	var origin: Vector2i = pawn.pos
	var target: Vector2i = action.to
	if action.token:
		state.tokens[state.active] -= 1
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
		"borrow_tomorrow":
			_shift(state, pawn, target, "step", events)
			_shift(state, state.pawns[action.second], action.second_to, "step", events)
			pawn.borrow = {"origin": origin, "due": _serial(state) + 2}
			_event(events, "return_pending", "Pawn owes a return to %s after its side's next turn." % _tile(origin),
				{"pawn": pawn.id, "from": target, "to": origin, "due": pawn.borrow.due})
		"infected_trail":
			_shift(state, pawn, target, "step", events)
			if origin != state.flag:
				state.infected[origin] = _serial(state) + 1
				_event(events, "infection", "%s is infected through the next enemy turn." % _tile(origin), {"tiles": [origin]})
		"spy":
			var marked: Dictionary = state.pawns[action.mark]
			marked.spy = true
			_event(events, "spy", "Drafted ability at %s disabled for one turn." % _tile(marked.pos),
				{"pawn": marked.id, "to": marked.pos})
			if action.base == "capture":
				_capture(state, pawn, target, events)
			else:
				_shift(state, pawn, target, "step", events)
		_:
			_shift(state, pawn, target, "step", events)


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
		"returned": message = "Borrowed pawn returned to %s." % _tile(target)
	var fields := {"pawn": pawn.id, "from": origin, "to": target, "side": pawn.side}
	fields.merge(extra)
	_event(events, kind, message, fields)
	if origin == state.flag or target == state.flag:
		var holder: int = pawn.id if target == state.flag else -1
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
		message = "%s flag hold: %d/2 replies." % [SIDE_NAMES[side], state.replies]
	_event(events, "flag", message, {"pawn": state.holder, "to": state.flag, "side": side, "replies": state.replies})


static func _resolve_return(state: Dictionary, events: Array[Dictionary]) -> void:
	for id in state.pawns.keys():
		var pawn: Dictionary = state.pawns[id]
		if pawn.side != state.active or pawn.borrow.is_empty() or pawn.borrow.due > _serial(state):
			continue
		var origin: Vector2i = pawn.borrow.origin
		pawn.borrow = {}
		if _empty(state, _occupancy(state), origin):
			_shift(state, pawn, origin, "returned", events)
		else:
			state.pawns.erase(id)
			var reason := "occupied"
			if state.holes.has(origin):
				reason = "destroyed"
			elif state.infected.has(origin):
				reason = "infected"
			_event(events, "return_failed", "Borrowed pawn lost. Its echo at %s was %s." % [_tile(origin), reason],
				{"pawn": id, "from": pawn.pos, "to": origin, "reason": reason})


static func _collapse(state: Dictionary, events: Array[Dictionary]) -> void:
	var dropped: Array[Vector2i] = []
	for tile: Vector2i in state.cracks.keys():
		if state.cracks[tile] == state.round:
			dropped.append(tile)
			state.holes[tile] = true
			state.cracks.erase(tile)
			state.infected.erase(tile)
	if dropped.is_empty():
		return
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
		alive[pawn.side] = true
	if not alive[0] and not alive[1]:
		_finish(state, -1, "mutual_elimination")
	elif not alive[0] or not alive[1]:
		_finish(state, 0 if alive[0] else 1, "elimination")


static func _expire_effects(state: Dictionary, events: Array[Dictionary]) -> void:
	for tile: Vector2i in state.infected.keys():
		if state.infected[tile] <= _serial(state):
			state.infected.erase(tile)
			_event(events, "infection_expired", "Infection cleared at %s." % _tile(tile), {"tiles": [tile]})
	for pawn: Dictionary in state.pawns.values():
		if pawn.side == state.active and pawn.spy:
			pawn.spy = false
			_event(events, "spy_expired", "Spy mark cleared at %s." % _tile(pawn.pos), {"pawn": pawn.id, "to": pawn.pos})


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
