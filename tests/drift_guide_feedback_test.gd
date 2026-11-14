extends SceneTree

const Main = preload("res://scripts/battle/battle.gd")
const Rules = preload("res://scripts/rules/rules.gd")
const Drift = preload("res://scripts/rules/drift.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _texts(node: Node) -> String:
	var value := ""
	if node is Label or node is Button:
		value += node.text + "\n"
	elif node is RichTextLabel:
		value += node.get_parsed_text() + "\n"
	for child in node.get_children():
		value += _texts(child)
	return value


func _capture_state(drift: bool, attacker: int) -> Dictionary:
	var state := Rules.create_drift_match(7, attacker, Drift.CENTER, 0) if drift else Rules.create_match(7, attacker)
	state.phase = "playing"
	state.active = attacker
	state.dice[attacker] = "infected_trail"
	state.pawns[0].pos = Vector2i(4, 4) if attacker == 1 else Vector2i(3, 3)
	state.pawns[5].pos = Vector2i(3, 5) if attacker == 1 else Vector2i(4, 4)
	return state


func _guide_fits(node: Node) -> void:
	if node is RichTextLabel:
		_check(node.get_content_height() <= node.size.y + 1, "Guide text fits its card without hidden lines")
	for child in node.get_children():
		_guide_fits(child)


func _scoring() -> void:
	var state := Rules.create_drift_match(7, 0, Drift.CENTER, 0)
	_check(Drift.TOTAL_TO_WIN == 10 and state.pawns.size() == 10, "Ten point goal preserves five ships per side")
	_check(Drift.total(state, 0) == 5 and Drift.total(state, 1) == 5, "Opening score counts surviving ships")
	state = Rules.apply_action(state, {"kind": "step", "pawn": 0, "to": Vector2i(3, 2)}).state
	state = Rules.apply_action(state, {"kind": "step", "pawn": 5, "to": Vector2i(3, 8)}).state
	_check(state.phase == "playing" and state.round == 2, "Opening five points never cause an instant win or draw")
	state = _capture_state(true, 1)
	var result := Rules.apply_action(state, {"kind": "capture", "pawn": 5, "to": Vector2i(4, 4)})
	_check(result.ok and Drift.total(result.state, 0) == 4 and Drift.total(result.state, 1) == 5, "Capture subtracts exactly one point from the victim and awards no extra point")
	_check(state.pawns.size() == 10 and result.state.pawns.size() == 9, "Scoring does not mutate the previous state")
	state.drift.scores = [4, 0]
	state.turn = 1
	result = Rules.apply_action(state, {"kind": "step", "pawn": 6, "to": Vector2i(4, 8)})
	_check(result.ok and result.state.phase == "playing", "Nine total points are below the new goal")
	state.drift.scores = [5, 0]
	result = Rules.apply_action(state, {"kind": "step", "pawn": 6, "to": Vector2i(4, 8)})
	_check(result.ok and result.state.winner == 0 and result.state.phase == "finished", "Exactly ten points win after a shift")
	state.drift.scores = [5, 5]
	result = Rules.apply_action(state, {"kind": "step", "pawn": 6, "to": Vector2i(4, 8)})
	_check(result.ok and result.state.winner == -1 and result.state.reason == "drift_tie", "Reaching ten together draws")
	state.drift.scores = [0, 0]
	state.round = Drift.ROUND_LIMIT
	result = Rules.apply_action(state, {"kind": "step", "pawn": 6, "to": Vector2i(4, 8)})
	_check(result.ok and result.state.reason == "drift_limit", "Round twelve still ends an unresolved game in a draw")


func _run() -> void:
	_scoring()
	root.size = Vector2i(1320, 850)
	root.content_scale_size = Vector2i(1320, 850)
	for drift in [false, true]:
		var game := Main.new()
		game.drift_circuit = drift
		root.add_child(game)
		current_scene = game
		game._stop_communication()
		game.generation += 1
		game.local_mode = false
		game.chrome.show()
		game._close_overlay(false)
		if drift:
			game.state = Rules.create_drift_match(7, 1, Drift.CENTER, 0)
			game.legal = Rules.legal_actions(game.state)
			game._refresh()
			var score_text := _texts(game.side_panel)
			_check(score_text.contains("5 POINTS") and score_text.contains("10 points to win.") and not score_text.contains("UNITS"), "Drift scoreboard shows total points without units")
			game._show_drift_guide(1)
			await process_frame
			_guide_fits(game.overlay)
			for name in ["MovementScreenshot", "CaptureScreenshot"]:
				var screenshot: TextureRect = game.overlay.find_child(name, true, false)
				_check(screenshot != null and screenshot.texture != null and screenshot.texture.resource_path.contains("drift-"), "Drift guide shows its own real board screenshot")
			_check(_texts(game.overlay).contains("row 4 moves right") and _texts(game.overlay).contains("Crew move up"), "Movement guide explains lanes and faction capture directions")
			game._show_drift_guide(2)
			await process_frame
			_guide_fits(game.overlay)
			var scoring := _texts(game.overlay)
			_check(scoring.contains("SHIP CAPTURED") and scoring.contains("−1") and scoring.contains("Reach 10 points"), "Scoring guide explains capture penalty and current goal")
			game._show_drift_guide(0)
			await process_frame
			_guide_fits(game.overlay)
			game._close_overlay(false)
			game.state.phase = "finished"
			game.state.reason = "drift_tie"
			game.state.drift.scores = [5, 5]
			game._show_result()
			_check(_texts(game.overlay).contains("Both sides reached 10 points on the same shift."), "Drift result screen uses the current winning score")
			game._close_overlay(false)
		else:
			game._show_kalypso_guide(1)
			var screenshot: TextureRect = game.overlay.find_child("MovementScreenshot", true, false)
			_check(screenshot != null and screenshot.texture.resource_path.contains("kalypso-"), "Shared guide layout preserves Kalypso's own images")
			game._close_overlay(false)
		for attacker in [1, 0]:
			game.generation += 1
			game.busy = false
			game.motion = true
			game.state = _capture_state(drift, attacker)
			game.legal = Rules.legal_actions(game.state)
			game._refresh()
			var rest: Vector2 = game.board.position
			game._commit({"kind": "capture", "pawn": 5 if attacker == 1 else 0, "to": Vector2i(4, 4)})
			if drift:
				_check(_texts(game.side_panel).contains("4 POINTS") and _texts(game.side_panel).contains("5 POINTS"), "Scoreboard immediately reflects exactly one point lost on capture")
			var fx: Control = game.combat_feedback
			fx.set_process(false)
			_check(fx.elapsed == 0.0 and fx.loss == (attacker == 0), "Both games select red for Crew loss and green for Crew capture")
			fx._process(0.20)
			fx._process(0.04)
			_check(fx.strength > 0.0 and fx.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Feedback blinks without intercepting board input")
			_check((not game.board.position.is_equal_approx(rest)) == (attacker == 0), "A loss shakes the board while a capture keeps it stable")
			fx._process(0.5)
			_check(game.board.position.is_equal_approx(rest) and fx.strength == 0.0, "Completed shake restores the exact board position")
			game.generation += 1
		var before := _capture_state(drift, 0)
		var after := Rules.apply_action(before, {"kind": "capture", "pawn": 0, "to": Vector2i(4, 4)})
		game.motion = false
		game._show_combat_feedback(before, after.state, after.events)
		_check(not game.combat_feedback.is_processing() and game.combat_feedback.strength == 0.0, "FX off suppresses blinks, shake and vibration")
		game.motion = true
		game.local_mode = true
		game._show_combat_feedback(before, after.state, after.events)
		_check(not game.combat_feedback.loss, "Local play evaluates captures from the acting side's perspective")
		game.combat_feedback.stop()
		var collapsed := before.duplicate(true)
		collapsed.pawns.erase(5)
		game.local_mode = false
		game._show_combat_feedback(before, collapsed, [{"kind": "collapse"}])
		_check(game.combat_feedback.loss and game.combat_feedback.is_processing(), "Falling tiles also trigger ship loss feedback")
		game.combat_feedback.stop()
		game._show_combat_feedback(before, before, [{"kind": "shield_break"}])
		_check(not game.combat_feedback.is_processing(), "Blocked attacks and nonlethal effects never trigger a loss blink")
		var rest: Vector2 = game.board.position
		game.combat_feedback.play(true)
		game.combat_feedback._process(0.04)
		game._toggle_motion()
		_check(not game.motion and game.board.position.is_equal_approx(rest) and game.combat_feedback.strength == 0.0,
			"Switching FX off during a shake immediately restores the board")
		game.combat_feedback.play(true)
		game.combat_feedback._process(0.04)
		game._modal("rules", "Test")
		_check(game.board.position.is_equal_approx(rest) and not game.combat_feedback.is_processing(),
			"Opening a modal clears feedback and leaves its text stationary")
		game.queue_free()
		await process_frame
	print("Drift guide and combat feedback: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)
