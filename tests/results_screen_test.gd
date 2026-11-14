extends SceneTree
const Main = preload("res://scripts/battle/battle.gd")
const Rules = preload("res://scripts/rules/rules.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _texts(node: Node) -> Array[String]:
	var values: Array[String] = []
	if node is Label or node is Button: values.append(node.text)
	for child in node.get_children(): values.append_array(_texts(child))
	return values

func _finished(game: Control, winner: int, reason: String) -> void:
	game.generation += 1
	game.busy = false
	game.local_mode = false
	game.state = Rules.create_match(7, 1)
	game.state.phase = "finished"
	game.state.winner = winner
	game.state.reason = reason
	game.state.round = 4
	game.legal.clear()
	game._show_result()

func _run() -> void:
	var game := Main.new()
	root.add_child(game)
	current_scene = game
	if game._communication_tween: game._communication_tween.kill()
	game.chrome.show()
	for winner in [1, 0, -1]:
		_finished(game, winner, "round_cap" if winner < 0 else "flag")
		var panel: Panel = game.overlay.find_child("ResultPanel", true, false)
		var texts := _texts(panel)
		_check(texts.has("ROUND 04") and not " ".join(texts).contains("SEED"), "Result keeps the round and removes the seed")
		_check(not texts.has("Travel to Cinder") and not texts.has("Withdraw to Cinder") and not texts.has("Copy replay data"), "Result omits Cinder and replay controls")
		_check(texts.has("Return to flight") and texts.has("Rematch") and texts.has("View board"), "Result offers the three intended actions")
		_check(texts.has("CREW") and texts.has("ALIENS"), "Result illustrates both story factions")
		if winner == 1:
			var border: StyleBoxFlat = panel.get_theme_stylebox("panel")
			_check(border.border_color.g > border.border_color.r and border.border_width_left == 3, "Crew victory has a visible green border")
		if winner == 0:
			_check(texts.has("An enemy ship held the flag through 3 of your turns."), "Defeat explains the enemy's flag hold")
	_finished(game, 0, "elimination")
	_check(_texts(game.overlay).has("All of your ships were eliminated."), "Elimination defeat describes the correct side")
	var panel: Panel = game.overlay.find_child("ResultPanel", true, false)
	for child in panel.get_children():
		if child is Button and child.text == "View board": child.pressed.emit()
	_check(game.overlay_kind.is_empty(), "View board closes the result")
	game._show_result()
	panel = game.overlay.find_child("ResultPanel", true, false)
	for child in panel.get_children():
		if child is Button and child.text == "Rematch": child.pressed.emit()
	_check(game.state.winner == -1 and game.state.reason.is_empty(), "Rematch starts a fresh match")
	_finished(game, 1, "flag")
	game.overlay.find_child("ReturnToFlightButton", true, false).pressed.emit()
	var deadline := Time.get_ticks_msec() + 9000
	while (not current_scene or current_scene.scene_file_path != "res://scenes/solar_system.tscn") and Time.get_ticks_msec() < deadline:
		await process_frame
	var returned := current_scene and current_scene.scene_file_path == "res://scenes/solar_system.tscn"
	_check(returned, "Return to flight opens the solar system")
	if returned:
		_check(current_scene._state == 0 and current_scene._ship_velocity.length() > 0, "Return resumes free flight with ship momentum")
		_check(root.get_node("Expedition").current_system == 0, "Return stays near Kalypso instead of travelling to Cinder")
	print("Results screens: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)
