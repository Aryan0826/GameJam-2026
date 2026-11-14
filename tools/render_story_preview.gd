extends SceneTree
## Capture the real in-game story screens. Optional first argument: output folder.
const Main = preload("res://scripts/battle/battle.gd")
const Drift = preload("res://scripts/rules/drift.gd")
const Rules = preload("res://scripts/rules/rules.gd")
var destination := "user://story-previews"


func _initialize() -> void:
	_run.call_deferred()


func _capture(filename: String) -> void:
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination.path_join(filename + ".png"))
	print("Captured " + filename)


func _run() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		destination = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	root.size = Vector2i(1320, 850)
	var expedition: Node = root.get_node("Expedition")
	for system in [0, 2]:
		expedition.reset_journey()
		expedition.enter_system(system)
		var game := Main.new()
		game.drift_circuit = system == 2
		root.add_child(game)
		current_scene = game
		game.motion = false
		game.cockpit.motion = false
		game._contact_art.motion = false
		game._begin_terminal_message(3 if system == 2 else 5)
		game._advance_communication()
		var planet := "cinder" if system == 2 else "kalypso"
		await _capture(planet + "-contact")
		game._begin_terminal_message(2 if system == 2 else 3)
		game._advance_communication()
		await _capture(planet + "-captain")
		game._finish_communication()
		await _capture(planet + "-briefing")
		for winner in [1, 0, -1]:
			expedition.planet_standings.clear()
			game.state = Rules.create_drift_match(7, 1, Drift.CENTER, 0) if system == 2 else Rules.create_match(7, 1)
			game.state.phase = "finished"
			game.state.winner = winner
			game.state.reason = ("drift_tie" if system == 2 else "round_cap") if winner < 0 else "relays" if system == 2 else "flag"
			if system == 2:
				game.state.drift.scores = [3, 3] if winner < 0 else [1, 3] if winner == 1 else [3, 1]
			game.state.round = 4
			game._show_result()
			await _capture(planet + ("-victory" if winner == 1 else "-defeat" if winner == 0 else "-draw"))
		if system == 2:
			expedition.enter_system(0)
			expedition.record_battle(1)
			expedition.enter_system(2)
			game.state = game.state.duplicate(true)
			game.state.winner = 1
			game.state.reason = "relays"
			game.state.drift.scores = [1, 3]
			game._show_result()
			game._result_line = game._result_story.size() - 1
			game._render_result_story()
			await _capture("expedition-epilogue")
		game.free()
		await process_frame
	quit()
