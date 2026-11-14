extends SceneTree
## Capture the real orbit, cinematic, and following conversation.
const Rules = preload("res://scripts/rules/rules.gd")
var destination := "user://descent-previews"


func _initialize() -> void:
	_run.call_deferred()


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination.path_join(filename + ".png"))
	print("Captured " + filename)


func _run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		destination = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	root.size = Vector2i(1320, 850)
	root.get_node("Expedition").reset_journey()
	change_scene_to_file("res://scenes/solar_system.tscn")
	await process_frame
	await process_frame
	await create_timer(0.7).timeout
	current_scene._orbit_target = current_scene.planet_node
	current_scene._trigger_game_transition()
	await create_timer(1.0).timeout
	await _capture("descent-space")
	await create_timer(3.0).timeout
	await _capture("descent-approach")
	await create_timer(3.3).timeout
	await _capture("descent-reentry")
	await create_timer(1.1).timeout
	await _capture("incoming-hologram")
	await create_timer(1.8).timeout
	current_scene._begin_terminal_message(5)
	current_scene._advance_communication()
	await process_frame
	await _capture("descent-conversation")
	var game: Control = current_scene
	game.generation += 1
	game.state = Rules.create_match(7, 1)
	game.state.phase = "playing"
	game.state.round = 2
	game.local_mode = true
	game.cockpit.mode = "trial"
	game.chrome.show()
	game._clear(game.overlay)
	game.overlay_kind = ""
	game.messages.assign(["The area around E4 is infected through the next enemy turn. Ships cannot enter these tiles until the infection expires.", "Crew used Infected Trail.", "Aliens ended the turn."])
	game.legal = Rules.legal_actions(game.state)
	game._refresh()
	for frame in 8:
		await process_frame
	await _capture("wrapped-flight-log")
	quit()
