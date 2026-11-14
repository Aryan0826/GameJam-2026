extends SceneTree

const Rules = preload("../scripts/rules.gd")
const Drift = preload("../scripts/drift.gd")
const DriftBot = preload("../scripts/drift_bot.gd")
const FIRST_FLIGHT = "res://scenes/solar_system.tscn"
const FIRST_DUEL = "res://main.tscn"
const SECOND_DUEL = "res://scenes/drift_circuit.tscn"

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _press(node: Node, text: String) -> bool:
	if node is Button and node.text == text and node.is_visible_in_tree() and not node.disabled:
		node.pressed.emit()
		return true
	for child in node.get_children():
		if _press(child, text):
			return true
	return false


func _await_scene(path: String, timeout_ms: int = 9000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if current_scene and current_scene.scene_file_path == path:
			return true
		await process_frame
	var snapshot := "" if not current_scene else " (still on %s: %s)" % [current_scene.scene_file_path, current_scene.get("_state")]
	_check(false, "Reached " + path + snapshot)
	return false


func _run() -> void:
	_check_rules()
	await _check_travel()
	print("Planet travel: %d checks, %d failures." % [checks, failures])
	quit(1 if failures or checks < 45 else 0)


func _check_rules() -> void:
	var state := Rules.create_drift_match(32, 0, Drift.CENTER, 0)
	_check(state.phase == "playing" and {"kind": "roll"} not in Rules.legal_actions(state), "Cinder uses Drift Circuit without draft or dice.")
	for id in state.pawns.keys():
		if id not in [0, 1, 5]:
			state.pawns.erase(id)
	state.pawns[0].pos = Vector2i(1, 3)
	state.pawns[1].pos = Vector2i(9, 4)
	state.pawns[5].pos = Vector2i(8, 7)
	state.drift.scores = [4, 2]
	var first := {"kind": "step", "pawn": 0, "to": Vector2i(1, 4)}
	var reply := {"kind": "step", "pawn": 5, "to": Vector2i(9, 6)}
	state = Rules.apply_action(state, first).state
	_check(state.active == 1 and state.drift.scores == [4, 2], "The opening move does not trigger the shift.")
	state = Rules.apply_action(state, reply).state
	_check(state.pawns[1].pos == Vector2i(1, 4) and state.pawns[5].pos == Vector2i(8, 6), "Pieces on the drift lanes move in opposite directions and wrap.")
	_check(state.phase == "finished" and state.winner == 0 and state.drift.scores == [5, 3], "The second move shifts both lanes and scores each claimed relay once.")
	_check(state.drift.relays == [Vector2i(6, 4), Vector2i(5, 5), Vector2i(3, 6)], "Claimed relays jump across their own rows. The unclaimed relay stays put.")

	state = Rules.create_drift_match(32, 0, Drift.CENTER, 0)
	state.pawns[0].pos = Vector2i(1, 3)
	state = Rules.apply_action(state, first).state
	state = Rules.apply_action(state, {"kind": "step", "pawn": 5, "to": Vector2i(3, 8)}).state
	var points_after_claim: Array = state.drift.scores.duplicate()
	state = Rules.apply_action(state, first).state
	state = Rules.apply_action(state, {"kind": "step", "pawn": 5, "to": Vector2i(3, 9)}).state
	_check(points_after_claim == [1, 0] and state.drift.scores == points_after_claim and state.pawns[0].pos == Vector2i(2, 4),
		"Repeating the same drift back onto B4 no longer scores again.")

	state = Rules.create_drift_match(32, 0, Drift.CENTER, 0)
	for id in state.pawns.keys():
		if id not in [0, 1, 2, 5]:
			state.pawns.erase(id)
	state.pawns[0].pos = Vector2i(5, 5)
	state.pawns[1].pos = Vector2i(9, 5)
	state.pawns[5].pos = Vector2i(4, 6)
	var opponent := {"kind": "step", "pawn": 5, "to": Vector2i(4, 7)}
	state = Rules.apply_action(state, {"kind": "step", "pawn": 2, "to": Vector2i(5, 2)}).state
	var result := Rules.apply_action(state, opponent)
	var simulated := Rules.apply_legal_action(state, opponent, false)
	_check(result.state == simulated.state, "The AI sees the same relay relocations as the player.")
	state = result.state
	_check(state.drift.scores == [1, 0] and state.drift.relays[1] == Vector2i(1, 5), "The steady relay skips occupied squares after scoring.")
	state = Rules.apply_action(state, {"kind": "step", "pawn": 2, "to": Vector2i(5, 1)}).state
	state = Rules.apply_action(state, {"kind": "step", "pawn": 5, "to": Vector2i(4, 8)}).state
	_check(state.drift.scores == [1, 0], "Camping on the old relay earns zero additional points.")
	for layout in [Drift.CENTER, Drift.SPLIT]:
		for mirrored in [false, true]:
			var rows := Drift.relays(layout, mirrored).map(func(relay: Vector2i): return relay.y)
			_check(rows == [4, 5, 6], "Every opening layout has one relay on each scoring row.")
	var openings := {}
	for focus in 3:
		for seed_value in [44, 48, 52]:
			state = Rules.create_drift_match(seed_value, 0, Drift.CENTER, focus)
			var legal := Rules.legal_actions(state)
			var action := DriftBot.choose(state, legal)
			_check(action in legal, "The Drift Circuit bot chooses a legal action.")
			openings[action] = true
	_check(openings.size() >= 3, "The same board permits varied AI openings.")


func _check_travel() -> void:
	change_scene_to_file(FIRST_FLIGHT)
	if not await _await_scene(FIRST_FLIGHT):
		return
	var flight = current_scene
	var start: Vector2 = flight.ship_node.position
	_check(_press(flight, "Cinder") and flight.ship_node.position == start, "Setting course tracks Cinder within the same flight scene.")
	flight._update_hud(0.0)
	var pointer: Control = flight.planet_pointer
	_check(pointer.visible and pointer.get_node("TagLabel").text == "CINDER", "The off-screen pointer guides the player to Cinder.")
	var targeted: Array = flight.get_system_map_data().filter(func(body): return body.is_target)
	_check(targeted.size() == 1 and targeted[0].name == "CINDER", "The minimap highlights Cinder alone.")
	var body: Node2D = flight.cinder
	flight.ship_node.position = body.position + Vector2.LEFT * (flight.cinder.stable_orbit_radius + 32.0)
	flight.ship_node.rotation = Vector2.UP.angle()
	flight._ship_velocity = flight.cinder.orbital_velocity() + Vector2.UP * flight.cinder.stable_orbit_radius * flight.planet_orbit_rot_speed
	flight.camera.position = body.position
	flight.camera.reset_smoothing()
	flight.camera.force_update_scroll()
	flight._update_hud(0.0)
	_check(pointer.visible and pointer.get_node("TagLabel").text == "CINDER", "The pointer stays visible when Cinder is on screen.")
	_check(flight._can_capture_orbit(body), "The red planet accepts a normal orbital approach.")
	if not await _await_scene(SECOND_DUEL):
		return
	var duel = current_scene
	_check(duel.drift_circuit and duel.expedition.current_system_data().planet_name == "CINDER", "Cinder descent opens Drift Circuit with Cinder as the destination.")
	_check(_press(duel, "Local duel"), "Cinder offers local play.")
	_check(duel.state.has("drift") and duel.board.relay_nodes.size() == 3, "The local match has the relay board.")
	await _check_lift_and_shift(duel)
	duel._start(true)
	duel._commit(duel.legal[0])
	_check(_press(duel, "Return to planets"), "Departure is available while resolving a move.")
	_check(_press(duel, "Keep playing") and duel.records.size() == 1, "Cancel keeps the same match and move.")
	_check(_press(duel, "Return to planets") and _press(duel, "Kalypso · Fractured Flag"), "An active Cinder match can be left for Kalypso.")
	if not await _await_scene(FIRST_DUEL):
		return
	duel = current_scene
	_check(not duel.drift_circuit and duel.expedition.current_system == 0, "Kalypso descent opens the original challenge.")
	_check(_press(duel, "Local duel") and duel.handoff, "Kalypso still uses its private local draft.")
	_check(_press(duel, "Return to planets") and _press(duel, "Cinder · Drift Circuit"), "Kalypso can be left before the draft is complete.")
	if not await _await_scene(SECOND_DUEL):
		return
	duel = current_scene
	_check(_press(duel, "Accept challenge") and not duel.local_mode, "Cinder can be replayed in solo mode after leaving Kalypso.")
	if duel.state.active == 1:
		duel._commit(duel.legal[0])
	var deadline := Time.get_ticks_msec() + 2500
	while not duel.records.any(func(action): return action.get("pawn", 5) < 5) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(duel.records.any(func(action): return action.get("pawn", 5) < 5), "The live solo scene completes an Alien move.")


func _check_lift_and_shift(duel: Control) -> void:
	duel.state = Rules.create_drift_match(32, 0, Drift.CENTER, 0)
	duel.state.active = 1
	duel.state.turn = 1
	duel.state.pawns[0].pos = Vector2i(1, 4)
	duel.state.pawns[5].pos = Vector2i(9, 7)
	duel._enter_turn()
	var pad: MeshInstance3D = duel.board.tiles[Vector2i(1, 4)]
	var steady: MeshInstance3D = duel.board.tiles[Vector2i(5, 5)]
	var mover: Node3D = duel.board.pieces[5]
	duel._commit({"kind": "step", "pawn": 5, "to": Vector2i(9, 6)})
	_check(duel.board.shift_tween != null and duel.busy, "Completing both turns starts the lane animation and gates input.")
	_check(duel.board.displayed_relays[0] == Vector2i(2, 4), "The old relay remains visible during the shift.")
	await create_timer(0.45).timeout
	_check(pad.position.y > 0.25 and steady.position.y == 0.0, "Drift tiles visibly lift while row five stays grounded.")
	_check(mover.position.y > 0.39, "A unit that moved onto a lane rides the lifting tile.")
	await create_timer(0.7).timeout
	_check(duel.board.tiles[Vector2i(2, 4)] == pad and pad.position.is_equal_approx(Vector3(-3, 0, -1)), "The same tile slides to the next column and settles.")
	_check(duel.board.shift_tween == null and duel.board.displayed_relays == duel.state.drift.relays, "The board shows the relocated relays after the animation.")
