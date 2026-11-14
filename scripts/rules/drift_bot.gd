extends RefCounted
## Searches one opposing reply. A seeded relay preference breaks close decisions.

const Rules = preload("res://scripts/rules/rules.gd")
const Drift = preload("res://scripts/rules/drift.gd")
const WIN := 10000.0
const CHOICE_MARGIN := 4.0


static func choose(state: Dictionary, actions: Array[Dictionary]) -> Dictionary:
	if actions.is_empty():
		return {}
	var side: int = state.active
	var best := -INF
	var candidates: Array[Dictionary] = []
	for action in actions:
		var next: Dictionary = Rules.apply_legal_action(state, action, false).state
		if next.phase == "finished" and next.winner == side:
			return action
		var score := _after_reply(next, side, best)
		best = maxf(best, score)
		candidates.append({"action": action, "score": score})

	var close: Array[Dictionary] = []
	for candidate in candidates:
		if candidate.score >= best - CHOICE_MARGIN:
			close.append(candidate.action)
	var random := RandomNumberGenerator.new()
	random.seed = int(state.seed) + int(state.round) * 521 + side
	return close[random.randi_range(0, close.size() - 1)]


static func _after_reply(state: Dictionary, side: int, best: float) -> float:
	if state.phase == "finished":
		return _score(state, side)
	var worst := INF
	for reply in Rules.legal_actions(state):
		var next: Dictionary = Rules.apply_legal_action(state, reply, false).state
		worst = minf(worst, _score(next, side))
		if worst < best - CHOICE_MARGIN:
			break
	return worst


static func _score(state: Dictionary, side: int) -> float:
	var enemy := 1 - side
	if state.phase == "finished":
		if state.winner == -1:
			return 0.0
		return WIN if state.winner == side else -WIN
	var total: Array = state.drift.scores
	var score := 32.0 * (int(total[side]) - int(total[enemy]))
	var proximity := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	var relays: Array = state.drift.relays
	var focus: int = state.drift.focus
	for pawn: Dictionary in state.pawns.values():
		var friendly: bool = pawn.side == side
		score += 32.0 if friendly else -32.0
		for i in relays.size():
			var staging := Drift.feeder(relays[i], Rules.BOARD_SIZE)
			var delta: Vector2i = (staging - pawn.pos).abs()
			var distance := maxi(delta.x, delta.y)
			var pressure := 20.0 / (1.0 + distance)
			if distance == 0 and _threatened(state, pawn):
				pressure *= 0.25
			proximity[pawn.side][i] = maxf(proximity[pawn.side][i], pressure)
	for i in relays.size():
		var bias := 1.6 if i == focus else 1.0
		score += proximity[side][i] * bias - proximity[enemy][i]
	return score


static func _threatened(state: Dictionary, target: Dictionary) -> bool:
	if state.active == target.side:
		return false
	var forward := 1 if state.active == 0 else -1
	for pawn: Dictionary in state.pawns.values():
		if pawn.side == state.active:
			var delta: Vector2i = target.pos - pawn.pos
			if absi(delta.x) == 1 and delta.y == forward:
				return true
	return false
