extends SceneTree

const Main = preload("res://scripts/battle/battle.gd")
const Drift = preload("res://scripts/rules/drift.gd")
const Rules = preload("res://scripts/rules/rules.gd")
const Story = preload("res://scripts/core/expedition_story.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _make_game(system: int) -> Control:
	root.get_node("Expedition").enter_system(system)
	var game := Main.new()
	game.drift_circuit = system == 2
	root.add_child(game)
	current_scene = game
	return game


func _finish(game: Control, winner: int) -> void:
	game.generation += 1
	game.busy = false
	game.state = Rules.create_drift_match(7, 1, Drift.CENTER, 0) if game.drift_circuit else Rules.create_match(7, 1)
	game.state.phase = "finished"
	game.state.winner = winner
	game.state.reason = "drift_tie" if game.drift_circuit and winner < 0 else "relays" if game.drift_circuit else "round_cap" if winner < 0 else "flag"
	game.state.round = 4
	game.legal.clear()
	game._show_result()


func _run() -> void:
	var expedition: Node = root.get_node("Expedition")
	expedition.reset_journey()
	expedition.record_battle(-1)
	_check(expedition.standing(0) == "unknown", "A first draw does not mark the crew Unproven")
	expedition.record_battle(0)
	expedition.record_battle(-1)
	_check(expedition.standing(0) == "unproven", "A draw after a loss preserves Unproven status")
	expedition.record_battle(1)
	expedition.record_battle(0)
	_check(expedition.standing(0) == "allied", "A friendly loss cannot revoke an earned alliance")
	expedition.enter_system(2)
	_check(expedition.standing(2) == "unknown" and not expedition.all_allied(), "Each planet has its own standing")
	expedition.record_battle(1)
	_check(expedition.all_allied(), "Winning both planets completes the expedition")
	expedition.reset_journey()
	_check(expedition.planet_standings.is_empty() and expedition.encounters_seen.is_empty(), "A new expedition resets the story")

	for system in [0, 2]:
		expedition.reset_journey()
		var game := _make_game(system)
		_check(game._terminal_messages.size() >= 6, "First contact has the full planet conversation")
		_check(game._contact_art.cinder == (system == 2), "Each planet uses its own envoy portrait")
		_check(game._communication_local.disabled, "Local play waits for the briefing")
		game._advance_communication()
		_check(game._terminal_active_line == 0 and game._terminal_characters == game._terminal_messages[0].text.length(), "First Enter reveals the current line without skipping it")
		game._advance_communication()
		_check(game._terminal_active_line == 1, "Second Enter advances the conversation")
		var steps := 0
		while not game._communication_ready and steps < 30:
			game._advance_communication()
			steps += 1
		_check(game._communication_ready and not game._communication_local.disabled, "Every first-contact line can be read before accepting")
		_check(game._terminal_screen.text.contains("Unproven") and game._terminal_screen.text.contains("8 total" if system == 2 else "3 enemy turns"), "The briefing gives the current win condition and loss consequence")
		game._show_rules()
		game._close_overlay()
		_check(game._communication_ready, "Returning from How to play preserves a completed briefing")
		game._leave_planet_orbit()
		_check(game._communication_departing and game._terminal_messages.size() == 2, "Declining opens the captain and envoy farewell")
		game._finish_communication()
		game._accept_challenge()
		_check(game.state.is_empty() and expedition.standing(system) == "unknown", "Declining neither starts a match nor applies a loss penalty")
		game.free()
		game = _make_game(system)
		_check(game._terminal_messages.size() == 1, "A return visit has a short invitation")
		game._finish_communication()
		game._accept_challenge(true)
		_check(not game.state.is_empty() and game.local_mode, "Accepting the briefing starts the existing local game")
		game.free()

		for winner in [1, 0, -1]:
			expedition.reset_journey()
			game = _make_game(system)
			_finish(game, winner)
			var expected := "allied" if winner == 1 else "unproven" if winner == 0 else "unknown"
			_check(expedition.standing(system) == expected, "The result records the correct planetary standing")
			var cast: Control = game.overlay.find_child("ResultCast", true, false)
			_check(cast != null and cast.outcome == winner and cast.cinder == (system == 2), "Win, loss, and draw show the matching planet lineup")
			var first_quote: String = game._result_quote.text
			game._show_result()
			_check(game._result_quote.text == first_quote, "Reopening a result preserves its original story exchange")
			for index in game._result_story.size():
				_check(not game._result_quote.text.is_empty(), "Every outcome line is readable through Next")
				game._advance_result_story()
			_check(game._result_line == 0, "Outcome dialogue can be replayed")
			game.overlay.find_child("ReturnToFlightButton", true, false).pressed.emit()
			var deadline := Time.get_ticks_msec() + 9000
			while (not current_scene or current_scene.scene_file_path != "res://scenes/solar_system.tscn") and Time.get_ticks_msec() < deadline:
				await process_frame
			var returned := current_scene and current_scene.scene_file_path == "res://scenes/solar_system.tscn"
			_check(returned and expedition.current_system == system, "Every outcome returns to flight near the same planet")
			if returned:
				_check(current_scene._state == 0 and current_scene._ship_velocity.length() > 0, "The crew resumes actual free flight")
				var route: Button = current_scene.get_node("HUDLayer/HUD/Destinations/Routes/" + ("Cinder" if system == 2 else "Kalypso"))
				_check(route.text.contains("Ally" if winner == 1 else "Unproven" if winner == 0 else route.name), "Flight shows the planet's updated standing")
				current_scene.free()
			if winner == 0:
				_check(Story.encounter(system, expedition.standing(system), true)[0].text.contains("returns"), "A loss changes the next encounter")

		expedition.reset_journey()
		game = _make_game(system)
		_finish(game, 1)
		_finish(game, 0)
		_check(expedition.standing(system) == "allied" and game._result_story[0].text.contains("Our alliance stands"), "Friendly rematch defeat explicitly preserves the alliance")
		game.free()

	expedition.reset_journey()
	expedition.record_battle(1)
	var finale := _make_game(2)
	_finish(finale, 1)
	_check(expedition.all_allied() and finale._result_story.back().text.contains("Two alliances earned"), "The second alliance unlocks the expedition epilogue")
	finale.free()
	await process_frame
	print("Expedition story: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)
