extends RefCounted
## The solo opponent uses the same legal actions and turn resolution as local play.

const Rules = preload("res://scripts/rules/rules.gd")
const WIN_SCORE = 100000.0
const DRAW_SCORE = -30.0


static func choose(state: Dictionary, actions: Array[Dictionary]) -> Dictionary:
	if actions.is_empty():
		return {}
	if state.phase == "draft":
		var side: int = state.active
		for action in actions:
			if action.pawns == [side * 5 + 1, side * 5 + 2] and action.spells == ["fracture", "teleport"]:
				return action
		return actions.front()
	if {"kind": "roll"} in actions:
		return {"kind": "roll"}

	var side: int = state.active
	var best_action: Dictionary = actions.front()
	var best_score := -INF
	for action in actions:
		var next: Dictionary = Rules.apply_legal_action(state, action).state
		if next.phase == "finished" and next.winner == side:
			return action

		var score := _score(next, side, state.round)
		# Newly sampled warnings and unrolled ability dice are private to the future.
		if next.phase == "playing" and next.round == state.round:
			score = _score_with_reply(next, side, score, best_score)
		if score > best_score:
			best_score = score
			best_action = action
	return best_action


static func _score_with_reply(state: Dictionary, side: int, current_score: float, best_score: float) -> float:
	var worst_reply := INF
	for reply in Rules.legal_actions(state):
		if reply.kind == "roll":
			continue
		var next: Dictionary = Rules.apply_legal_action(state, reply).state
		if next.phase == "finished" and next.winner == 1 - side:
			return -WIN_SCORE / 2.0 + current_score / 100.0
		worst_reply = minf(worst_reply, _score(next, side, state.round))
		if worst_reply != WIN_SCORE and current_score * 0.45 + worst_reply * 0.55 <= best_score:
			return current_score * 0.45 + worst_reply * 0.55
	if worst_reply == INF:
		return current_score
	if worst_reply == WIN_SCORE:
		return WIN_SCORE / 2.0
	return current_score * 0.45 + worst_reply * 0.55


static func _score(state: Dictionary, side: int, public_round: int) -> float:
	if state.phase == "finished":
		if state.winner == -1:
			return DRAW_SCORE
		return WIN_SCORE if state.winner == side else -WIN_SCORE

	var score := 0.0
	var nearest: Array[int] = [12, 12]
	var flag: Vector2i = state.flag
	for pawn in state.pawns.values():
		var pawn_side: int = pawn.side
		var pos: Vector2i = pawn.pos
		var distance := absi(pos.x - flag.x) + absi(pos.y - flag.y)
		var value := 75.0 + 20.0 / (1.0 + distance)
		nearest[pawn_side] = mini(nearest[pawn_side], distance)
		if pawn.charged:
			value += 6.0
			if pawn.spy > 0:
				value -= 3.0
		if pawn.spy > 0:
			value *= 0.35 + 0.16 * pawn.spy
		if pawn.shield:
			value += 12.0
		if state.round == public_round and state.cracks.has(pos):
			value -= 36.0
		if state.fractures.has(pos):
			value -= 48.0
		if pawn.id == state.holder:
			var flag_value := 260.0 + 250.0 * int(state.replies)
			if _can_be_captured(state, pawn):
				# The holder may retreat on its own turn, but can no longer
				# count on surviving the remaining replies from this square.
				flag_value *= 0.2 if state.active == pawn_side else 0.0
			value += flag_value
		elif state.active != pawn_side and not pawn.shield and _can_be_captured(state, pawn):
			value -= 30.0
		score += value if pawn_side == side else -value
	return score + 17.0 * (nearest[1 - side] - nearest[side])


static func _can_be_captured(state: Dictionary, target: Dictionary) -> bool:
	var target_pos: Vector2i = target.pos
	var enemy_side := 1 - int(target.side)
	var enemy_forward := 1 if enemy_side == 0 else -1
	if target_pos in state.infected:
		return false
	for attacker in state.pawns.values():
		if attacker.side != enemy_side:
			continue
		if attacker.spy > 0 and target_pos == state.flag:
			continue
		var delta: Vector2i = target_pos - attacker.pos
		if absi(delta.x) == 1 and delta.y == enemy_forward:
			return true
	return false
