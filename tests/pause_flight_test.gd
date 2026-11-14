extends SceneTree
const Main = preload("res://scripts/battle/battle.gd")
const Rules = preload("res://scripts/rules/rules.gd")
const Drift = preload("res://scripts/rules/drift.gd")
const StoryArt = preload("res://scripts/battle/story_art.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _esc() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key, true)

func _texts(node: Node) -> String:
	var result := ""
	if node is Label or node is Button: result += node.text + "\n"
	for child in node.get_children(): result += _texts(child)
	return result

func _run() -> void:
	var menu: Node = root.get_node("PauseMenu")
	var audio: Node = root.get_node("Soundtrack")
	var saved := [audio.volume("Music"), audio.volume("Effects"), audio.muted()]
	_check(ProjectSettings.get_setting("application/config/name") == "Uncharted Wilds", "Window and app use the new name")
	_check(ProjectSettings.get_setting("gui/theme/custom") == "res://art/fonts/game_theme.tres", "All default controls use the licensed game font")
	for drift in [false, true]:
		var game := Main.new()
		game.drift_circuit = drift
		root.add_child(game)
		current_scene = game
		game._stop_communication()
		game.generation += 1
		game.motion = false
		game.board.motion = false
		game.local_mode = true
		game.state = Rules.create_drift_match(7, 0, Drift.CENTER, 0) if drift else Rules.create_match(7, 0)
		game.state.phase = "playing"
		game.legal = Rules.legal_actions(game.state)
		game._close_overlay(false)
		game.chrome.show()
		game._refresh()
		var portrait = game.chrome.find_child("LiveEnvoyPortrait", true, false)
		_check(portrait != null and portrait.get_script() == StoryArt and portrait.cinder == drift, "Each challenge uses its own credited story alien")
		_esc()
		_check(paused and menu.is_open() and menu.orbit_button.visible, "Esc pauses either challenge and offers Return to orbit")
		_check(_texts(menu.screen).contains("Uncharted") or _texts(menu.screen).contains("UNCHARTED WILDS"), "Pause screen carries the game name")
		var before := game.state.duplicate(true)
		await create_timer(0.25).timeout
		_check(game.state == before, "No match actions run while paused")
		menu.sliders.Music.slider.value = 23
		menu.sliders.Effects.slider.value = 66
		menu.mute_button.button_pressed = true
		_check(is_equal_approx(audio.volume("Music"), 0.23) and is_equal_approx(audio.volume("Effects"), 0.66) and audio.muted(), "Music, effects and mute controls work while paused")
		_esc()
		_check(not paused and not menu.is_open(), "Esc resumes the same match")
		game._show_rules()
		_esc()
		_check(not paused and game.overlay_kind == "", "Esc closes help before opening pause")
		game.local_mode = false
		game.records.clear()
		game._schedule_action({}, 0.15)
		menu.open()
		await create_timer(0.3).timeout
		_check(game.records.is_empty(), "A queued computer turn stays paused past its original deadline")
		menu.resume()
		await create_timer(0.35).timeout
		_check(not game.records.is_empty(), "Computer turn continues after Resume")
		game.generation += 1
		if not drift:
			game.local_mode = true
			game.busy = false
			game.motion = true
			game.state = Rules.create_match(7, 1)
			game.state.phase = "playing"
			game.state.active = 1
			game.legal = Rules.legal_actions(game.state)
			game._commit({"kind": "roll"})
			await create_timer(0.05).timeout
			menu.open()
			var card_time: float = game.card_reveal.elapsed
			var records: int = game.records.size()
			await create_timer(1.5).timeout
			_check(game.card_reveal.elapsed == card_time and game.records.size() == records and game.shuffling,
				"Pausing a shuffle freezes both the card animation and its pending result")
			menu.resume()
			game.generation += 1
		if drift:
			menu.open()
			menu._return_to_orbit()
			await process_frame
			await process_frame
			_check(not paused and current_scene != game and current_scene.scene_file_path == "res://scenes/solar_system.tscn", "Return to orbit leaves the match and unpauses flight")
		else:
			game.queue_free()
			await process_frame
	var flight: Node = current_scene
	_check(ProjectSettings.get_setting("physics/common/physics_interpolation") and not flight.camera.position_smoothing_enabled
		and flight.camera.process_callback == Camera2D.CAMERA2D_PROCESS_PHYSICS, "Flight camera follows on the physics clock with interpolation and no chase delay")
	for body in flight.additional_planets.get_children():
		_check((body.get_node_or_null("ComingSoon") != null) == (body.display_name != "CINDER"), "Only planets without games display Coming soon")
	_esc()
	var position: Vector2 = flight.ship_node.position
	var angle: float = flight._planet_orbit_angle
	_check(paused and menu.is_open() and not menu.orbit_button.visible, "Flight has the same pause menu without a redundant orbit button")
	await create_timer(0.2).timeout
	_check(flight.ship_node.position == position and flight._planet_orbit_angle == angle, "Pause freezes ship motion and planet orbits")
	menu.resume()
	await create_timer(0.1).timeout
	_check(flight.ship_node.position != position, "Resume restores flight motion")
	menu.open()
	menu._main_menu()
	await process_frame
	await process_frame
	_check(not paused and current_scene.scene_file_path == "res://scenes/home.tscn", "Main menu leaves no paused scene behind")
	_check(_texts(current_scene).contains("Uncharted Wilds") and not _texts(current_scene).contains("The Fractured Flag\n& Drift Circuit"), "Title screen shows only the new overall game title")
	audio.set_volume("Music", saved[0])
	audio.set_volume("Effects", saved[1])
	audio.set_muted(saved[2])
	audio.save_volumes()
	print("Pause and flight: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)
