extends SceneTree

const Main = preload("res://scripts/battle/battle.gd")
const Rules = preload("res://scripts/rules/rules.gd")
const Drift = preload("res://scripts/rules/drift.gd")
const HOME := "res://scenes/home.tscn"
const PROLOGUE := "res://scenes/opening_crawl.tscn"
const FLIGHT := "res://scenes/solar_system.tscn"
var checks := 0
var failures := 0
var destination := ""


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _await_scene(path: String) -> bool:
	var deadline := Time.get_ticks_msec() + 9000
	while (not current_scene or current_scene.scene_file_path != path) and Time.get_ticks_msec() < deadline:
		await process_frame
	var arrived := current_scene and current_scene.scene_file_path == path
	_check(arrived, "Reached " + path)
	return arrived


func _capture(filename: String) -> void:
	if destination.is_empty():
		return
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination.path_join(filename + ".png"))


func _texts(node: Node) -> String:
	var text: String = node.text if node is Label or node is Button or node is RichTextLabel else ""
	for child in node.get_children():
		text += " " + _texts(child)
	return text


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
	if not OS.get_cmdline_user_args().is_empty():
		destination = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	root.size = Vector2i(1320, 850)
	await _check_selection()
	await _check_conquest()
	root.get_node("Expedition").reset_journey()
	_check(not root.get_node("Expedition").evil_captain, "A fresh default expedition uses the ally captain")
	await process_frame
	print("Captain paths: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)


func _check_selection() -> void:
	var expedition: Node = root.get_node("Expedition")
	for evil in [false, true]:
		change_scene_to_file(HOME)
		if not await _await_scene(HOME):
			return
		var home: Control = current_scene
		_check(not home.captain_choice.visible, "The captain choice waits for Explore")
		home.explore_button.pressed.emit()
		_check(current_scene == home and home.captain_choice.visible and not home._starting, "Explore prompts before starting the story")
		_check(root.gui_get_focus_owner() == home.good_button, "The choice opens with keyboard focus on Good")
		home.back_button.pressed.emit()
		_check(not home.captain_choice.visible and root.gui_get_focus_owner() == home.explore_button, "Back restores the title menu and focus")
		home.explore_button.pressed.emit()
		var cancel := InputEventAction.new()
		cancel.action = "ui_cancel"
		cancel.pressed = true
		home._unhandled_input(cancel)
		_check(not home.captain_choice.visible, "Escape can cancel the choice")
		home.explore_button.pressed.emit()
		await process_frame
		var panel: Control = home.captain_choice.get_node("Panel")
		_check(Rect2(Vector2.ZERO, home.size).encloses(panel.get_global_rect()), "The captain choice fits the viewport")
		if evil:
			await _capture("captain-choice")
		var choice: Button = home.evil_button if evil else home.good_button
		choice.pressed.emit()
		if not await _await_scene(PROLOGUE):
			return
		var crawl: Control = current_scene
		_check(expedition.evil_captain == evil, "The chosen captain reaches the prologue")
		_check(crawl.body_label.text == crawl.body_text and crawl.title_label.text == crawl.title_text, "The visible crawl uses the selected story")
		if evil:
			_check(crawl.body_text.contains("conquer the planets of other solar systems") and crawl.body_text.contains("KNEEL, OR BE ANNIHILATED"), "The evil prologue launches the captains' conquest")
			_check(crawl.body_text.contains("leave them in peace"), "The conquest prologue explains the peace pact")
		else:
			_check(crawl.title_text == "FIRST CONTACT" and crawl.body_text.contains("ALLIES"), "Good retains the original ally story")
		if not destination.is_empty():
			crawl.set_process(false)
			crawl.intro_container.hide()
			crawl.crawl_viewport_container.show()
			crawl.crawl_viewport_container.modulate.a = 1.0
			crawl.text_content.position.y = -0.5
			await _capture("evil-prologue" if evil else "good-prologue")
		crawl._finish_crawl()
		if await _await_scene(FLIGHT):
			_check(expedition.evil_captain == evil, "Skipping the crawl preserves the captain in flight")
			current_scene.free()


func _check_conquest() -> void:
	var expedition: Node = root.get_node("Expedition")
	for system in [0, 2]:
		var planet := "cinder" if system == 2 else "kalypso"
		expedition.reset_journey(true)
		var game := _make_game(system)
		var dialogue := str(game._terminal_messages).to_lower()
		_check(dialogue.contains("kneel") and dialogue.contains("annihilated"), "The captain demands surrender before each game")
		_check(dialogue.contains("if you lose") and dialogue.contains("peace") and dialogue.contains("if you win") and dialogue.contains("surrender"), "Both envoys propose the surrender-or-peace wager")
		for index in game._terminal_messages.size():
			game._begin_terminal_message(index)
			game._advance_communication()
			await process_frame
			await process_frame
			_check(game._terminal_screen.get_content_height() <= game._terminal_screen.size.y, "Every conquest transmission fits the existing terminal")
			_check(game._communication_accept.position.y + game._communication_accept.size.y < game._communication_prompt.position.y, "Continue stays above the terminal footer")
		game._begin_terminal_message(1)
		game._advance_communication()
		await _capture(planet + "-evil-captain")
		game._begin_terminal_message(4)
		game._advance_communication()
		await _capture(planet + "-evil-envoy")
		game._finish_communication()
		_check(game._terminal_screen.text.contains("capture the planet") and not game._terminal_screen.text.contains("alliance"), "The conquest briefing presents the right stakes")
		await _capture(planet + "-evil-briefing")
		game._leave_planet_orbit()
		game._finish_communication()
		game._accept_challenge()
		_check(game.state.is_empty() and expedition.standing(system) == "unknown", "Declining the wager does not capture or free the planet")
		game.free()

		for winner in [1, 0, -1]:
			expedition.reset_journey(true)
			game = _make_game(system)
			game._finish_communication()
			game._accept_challenge(true)
			_check(not game.state.is_empty() and game.local_mode, "The conquest story starts the existing local game")
			_finish(game, winner)
			var expected := "captured" if winner == 1 else "free" if winner == 0 else "unknown"
			_check(expedition.standing(system) == expected, "Conquest outcomes capture, free, or leave a world undecided")
			var result_text := _texts(game.overlay)
			_check(not result_text.to_lower().contains("alliance") and not result_text.contains("UNPROVEN"), "Conquest results contain no ally-story outcome")
			_check(result_text.contains("PLANET CAPTURED" if winner == 1 else "LEAVE IN PEACE" if winner == 0 else "CHALLENGE UNDECIDED"), "The result reports the wager's outcome")
			var first_quote: String = game._result_quote.text
			game._show_result()
			_check(game._result_quote.text == first_quote, "Reopening a result preserves the original surrender or peace exchange")
			for index in game._result_story.size():
				await process_frame
				_check(game._result_quote.get_minimum_size().y <= 70, "Each conquest result line fits the existing dialogue box")
				game._advance_result_story()
			await _capture(planet + ("-evil-victory" if winner == 1 else "-evil-defeat" if winner == 0 else "-evil-draw"))
			if winner >= 0:
				_finish(game, 1 - winner)
				_check(expedition.standing(system) == expected, "Rematches honor surrender and permanent peace")
				game._show_home()
				game._finish_communication()
				_check(game._terminal_screen.text.contains("remains " + expected), "Return briefings preserve the settled planet's fate")
				_check(not str(game._terminal_messages).to_lower().contains("annihilated"), "Settled worlds receive no new annihilation threat")
				game._show_result()
			game.overlay.find_child("ReturnToFlightButton", true, false).pressed.emit()
			if await _await_scene(FLIGHT):
				var flight: Node = current_scene
				flight._update_hud(0.0)
				var route: Button = flight.get_node("HUDLayer/HUD/Destinations/Routes/" + planet.capitalize())
				_check(route.text.contains("Captured" if winner == 1 else "Free" if winner == 0 else planet.capitalize()), "Flight shows the conquest standing on the same route button")
				_check(expedition.current_system == system and expedition.evil_captain, "Returning to flight preserves the planet and captain")
				flight.free()

	expedition.reset_journey(true)
	expedition.record_battle(1)
	var finale := _make_game(2)
	_finish(finale, 1)
	_check(expedition.all_secured() and not expedition.all_allied(), "Capturing both worlds completes the conquest without granting alliances")
	_check(finale._result_story.back().text == "The conquest continues.", "The second capture unlocks the conquest epilogue")
	for index in finale._result_story.size():
		await process_frame
		_check(finale._result_quote.get_minimum_size().y <= 70, "The conquest epilogue fits the existing dialogue box")
		finale._advance_result_story()
	finale._result_line = finale._result_story.size() - 1
	finale._render_result_story()
	await _capture("evil-epilogue")
	finale._show_story()
	if await _await_scene(PROLOGUE):
		_check(expedition.evil_captain and expedition.planet_standings.is_empty(), "Replay prologue resets standings and retains the evil captain")
		_check(current_scene.title_text == "WORLDS WILL KNEEL", "Replay uses the chosen captain's prologue")
		current_scene.free()
