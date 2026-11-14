extends SceneTree
const Main = preload("res://scripts/battle/battle.gd")
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


func _await_scene(scene: String) -> bool:
	var deadline := Time.get_ticks_msec() + 13000
	while (not current_scene or current_scene.scene_file_path != scene) and Time.get_ticks_msec() < deadline:
		await process_frame
	return current_scene and current_scene.scene_file_path == scene


func _texts(node: Node) -> String:
	var value: String = node.text if node is Label or node is Button or node is RichTextLabel else ""
	for child in node.get_children():
		value += " " + _texts(child)
	return value


func _run() -> void:
	var expedition: Node = root.get_node("Expedition")
	for system in [0, 2]:
		expedition.reset_journey()
		expedition.enter_system(system)
		var game := Main.new()
		game.drift_circuit = system == 2
		root.add_child(game)
		current_scene = game
		game._finish_communication()
		await process_frame
		await process_frame
		var text := _texts(game)
		_check(text.contains("DRIFT CIRCUIT" if system == 2 else "THE FRACTURED FLAG") and not text.contains("Conqueror"), "The planet uses its README game name")
		_check(not text.contains("Pilot"), "Crew replaces Pilots throughout the UI")
		for line in Story.encounter(system, "unknown", false) + Story.result(system, 0, false):
			_check(not line.text.contains("—") and not line.text.contains("–"), "Story statements contain no dash punctuation")
		for index in game._terminal_messages.size():
			game._begin_terminal_message(index)
			game._advance_communication()
			await process_frame
			await process_frame
			var bottom: float = game._terminal_screen.position.y + game._terminal_screen.get_content_height()
			_check(game._communication_accept.position.x == game._terminal_screen.position.x and game._communication_accept.position.y >= bottom and game._communication_accept.position.y <= bottom + 24, "Continue sits directly below the complete wrapped message")
		game.messages.assign(["The area around E4 is infected through the next enemy turn. Ships cannot enter that area until the infection expires. Choose another ship or an unaffected tile to continue the turn. The flag remains safe and units already inside the infected area are not removed.", "Crew used Infected Trail.", "Aliens ended the turn."])
		game.chrome.show()
		game._draw_flight_log()
		await process_frame
		await process_frame
		var panel: Control = game.side_panel.find_child("FlightLogPanel", true, false)
		var scroll: ScrollContainer = panel.get_node("FlightLogScroll")
		_check(panel.clip_contents and scroll.clip_contents and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "The log clips to its own panel and cannot scroll sideways")
		var entries := scroll.get_child(0)
		_check(entries.get_child(0).get_line_count() > 1, "Long log messages wrap over multiple lines")
		for entry: Label in entries.get_children():
			_check(entry.size.x <= scroll.size.x and entry.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Every log entry stays within the panel width")
		_check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "Overflowing log entries remain accessible by scrolling")
		game.free()

	for system in [0, 2]:
		expedition.reset_journey()
		change_scene_to_file("res://scenes/solar_system.tscn")
		_check(await _await_scene("res://scenes/solar_system.tscn"), "Flight scene opens")
		var flight: Node = current_scene
		flight._orbit_target = flight.cinder if system == 2 else flight.planet_node
		flight._trigger_game_transition()
		var sequence: Control = flight.get_node("HUDLayer/DescentSequence")
		_check(sequence.player.is_playing() and sequence.player.stream is VideoStreamTheora, "Descent starts the local star flight video")
		_check(sequence.player.name == "ForwardStarVideo" and sequence.player.stream.resource_path.ends_with("star-flight.ogv"), "The forward view uses stars instead of Earth reentry footage")
		_check(sequence.player.position + sequence.player.size / 2 == Vector2(660, 330), "Star motion shares the centered forward cockpit sightline")
		_check(sequence.player.modulate == Color.WHITE, "Space stays black and the stars stay neutral for both planets")
		_check(flight._state == 3, "Flight input stays locked during descent")
		if system == 2:
			sequence._begin_hologram()
			sequence._begin_hologram()
			_check(sequence._ending and sequence.hologram != null, "Repeated skip requests begin only one hologram transition")
			_check(sequence.hologram.find_children("*", "Label", true, false).any(func(label): return label.text == "ENVOY VESPER"), "The incoming hologram identifies the correct planet envoy")
		var target := "res://scenes/drift_circuit.tscn" if system == 2 else "res://scenes/fractured_flag.tscn"
		_check(await _await_scene(target), "Natural playback and skip both reach the correct planet conversation")
		if current_scene and current_scene.scene_file_path == target:
			_check(current_scene.overlay_kind == "home" and current_scene.state.is_empty(), "The conversation still precedes the board")
			_check(expedition.current_system == system and not expedition.descent_arrival, "The correct destination consumes its hologram arrival marker")
			_check(current_scene.has_node("DescentArrivalHologram"), "The hologram reveal continues across the scene boundary")
			current_scene.free()
	await process_frame
	print("UI and descent: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)
