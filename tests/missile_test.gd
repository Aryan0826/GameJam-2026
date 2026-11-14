extends SceneTree

const Rules = preload("res://scripts/rules/rules.gd")
const Main = preload("res://scripts/battle/battle.gd")
const Arena = preload("res://scripts/battle/board.gd")
var checks := 0
var failures := 0
var capture_dir := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--capture":
		capture_dir = args[1]
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _position(side: int = 1) -> Dictionary:
	var state := Rules.create_match(7, side)
	state = Rules.apply_action(state, {"kind": "draft", "pawns": [0, 1], "spells": ["missile", "teleport"]}).state
	state = Rules.apply_action(state, {"kind": "draft", "pawns": [5, 6], "spells": ["missile", "shield"]}).state
	state.dice = ["infected_trail", "infected_trail"]
	state.pawns[0].pos = Vector2i(4, 3)
	state.pawns[5].pos = Vector2i(5, 7)
	return state


func _shot(side: int, target: Vector2i) -> Dictionary:
	return {"kind": "missile", "pawn": 0 if side == 0 else 5, "to": target}


func _rules() -> void:
	var state := _position()
	var before := state.duplicate(true)
	var target: Vector2i = state.pawns[0].pos
	state.pawns[0].shield = true
	state.cracks[target] = 1
	state.fractures[target] = 1
	state.infected[target] = 1
	before = state.duplicate(true)
	var result := Rules.apply_action(state, _shot(1, target))
	_check(result.ok and state == before, "Missile is legal without mutating its input state")
	_check(0 not in result.state.pawns and target in result.state.holes, "Impact kills even a shielded enemy and destroys its tile immediately")
	_check(target not in result.state.cracks and target not in result.state.fractures and target not in result.state.infected,
		"Impact clears pending collapse and infection on the destroyed tile")
	_check(result.state.pawns[5].pos == before.pawns[5].pos and not result.state.pawns[5].charged,
		"Launcher stays in place and spends exactly one drafted charge")
	_check(result.state.turn_move and not result.state.turn_power_used and result.state.active == 1,
		"Missile replaces the move and preserves the optional drawn power")
	var followups := Rules.legal_actions(result.state)
	_check(followups.any(func(action: Dictionary): return action.kind == "infected_trail")
		and not followups.any(func(action: Dictionary): return action.kind in ["step", "capture", "shield", "teleport", "fracture", "missile"]),
		"After a missile, the player can use the drawn power or finish, without taking a second move")
	_check(result.events.any(func(event: Dictionary): return event.kind == "missile" and event.victim == 0 and event.from == before.pawns[5].pos and event.to == target),
		"Deterministic impact event identifies the launcher, target and victim")
	_check(Rules.apply_action(before, _shot(1, target)) == result, "Missile state and events replay deterministically")
	_check(not Rules.apply_action(result.state, _shot(1, Vector2i(1, 1))).ok, "Cannot fire twice in one turn")
	var next: Dictionary = Rules.apply_action(result.state, {"kind": "skip"}).state
	next = Rules.apply_action(next, {"kind": "skip"}).state
	if next.dice[next.active].is_empty():
		next = Rules.apply_action(next, {"kind": "roll"}).state
	_check(not Rules.apply_action(next, _shot(1, Vector2i(1, 1))).ok, "Spent missile cannot recharge on a later turn")

	state = _position()
	target = Vector2i(8, 5)
	result = Rules.apply_action(state, _shot(1, target))
	_check(result.ok and result.state.pawns.size() == state.pawns.size() and target in result.state.holes,
		"Firing at an empty tile removes just that tile")
	_check(result.state.holes.size() == 1 and result.state.pawns[0] == state.pawns[0], "Missile has no splash damage to adjacent tiles or ships")
	var blocker: Dictionary = result.state.duplicate(true)
	blocker.turn_move = false
	blocker.pawns[5].charged = true
	_check(not Rules.apply_action(blocker, _shot(1, target)).ok, "Already destroyed tiles cannot be targeted")
	for invalid in [state.flag, state.pawns[5].pos, state.pawns[6].pos, Vector2i(0, 5), Vector2i(10, 5)]:
		_check(not Rules.apply_action(state, _shot(1, invalid)).ok, "Missile excludes the flag, allies, launcher and off-board targets: %s" % invalid)
	state.dice[1] = ""
	_check(not Rules.apply_action(state, _shot(1, target)).ok, "Must shuffle before using the drafted missile")
	state = _position()
	state.turn_move = true
	_check(not Rules.apply_action(state, _shot(1, target)).ok, "Missile cannot follow an ordinary move")
	state.turn_move = false
	state.turn_power_used = true
	_check(not Rules.apply_action(state, _shot(1, target)).ok, "Missile cannot follow a standalone power")
	state = _position()
	state.pawns[5].spy = 2
	_check(not Rules.apply_action(state, _shot(1, target)).ok, "Stolen ships cannot spend their original missile charge")

	for side in [0, 1]:
		state = _position(side)
		var enemy_id := 5 if side == 0 else 0
		var launcher_id := 0 if side == 0 else 5
		state.pawns[enemy_id].pos = state.flag
		state.holder = enemy_id
		before = state.duplicate(true)
		_check(not Rules.legal_actions(state).any(func(action: Dictionary): return action.kind == "missile"), "Enemy on flag locks every missile target for side %d" % side)
		_check(not Rules.apply_action(state, _shot(side, target)).ok and state == before, "Blocked launch preserves charge, tiles and turn for side %d" % side)
		_check(Rules.ability_reason(state, state.pawns[launcher_id]).contains("enemy is on the flag"), "Flag lock has a visible explanation")
		state.holder = -1
		state.pawns[enemy_id].spy = 2
		_check(not Rules.apply_action(state, _shot(side, target)).ok, "Enemy flag occupant locks missiles even without a scoring holder")
		state.pawns[enemy_id].pos = Vector2i(3, 4)
		state.pawns[launcher_id].pos = state.flag
		_check(Rules.apply_action(state, _shot(side, target)).ok, "Friendly flag occupation permits launch for side %d" % side)

	state = _position()
	for id in range(1, 5):
		state.pawns.erase(id)
	result = Rules.apply_action(state, _shot(1, state.pawns[0].pos))
	_check(result.ok and result.state.phase == "finished" and result.state.winner == 1 and result.state.reason == "elimination",
		"Missile removing the final enemy finishes the duel immediately")
	_check(result.events.back().kind == "result", "Final missile emits the existing victory event")
	state = Rules.create_drift_match(7, 1, 0, 0)
	state.pawns[5].ability = "missile"
	state.pawns[5].charged = true
	_check(not Rules.legal_actions(state).any(func(action: Dictionary): return action.kind == "missile"), "Cinder keeps its existing moves without missiles")


func _setup(game: Control, motion: bool) -> void:
	game.generation += 1
	game.board.reset_visuals()
	game.state = _position()
	game.busy = false
	game.handoff = false
	game.local_mode = true
	game.motion = motion
	game.board.motion = motion
	game.records.clear()
	game.messages.clear()
	game.assignments.clear()
	game._clear_selection()
	game.legal = Rules.legal_actions(game.state)
	game._close_overlay(false)
	game.chrome.show()
	game._refresh()


func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))


func _run() -> void:
	_rules()
	root.size = Vector2i(1320, 850)
	root.content_scale_size = Vector2i(1320, 850)
	var game := Main.new()
	root.add_child(game)
	current_scene = game
	if game._communication_tween:
		game._communication_tween.kill()
	_setup(game, false)
	game._square_pressed(game.state.pawns[5].pos)
	_check(game.ability_hologram.visible and game.ability_hologram.heading.text == "MISSILE STRIKE", "Drafted missile appears in the existing ship hologram")
	game._choose_hologram_action("ability")
	_check(game.ability_hologram.description.text == "Choose an enemy or empty tile", "Missile targeting prompt explains valid targets")
	_check(game.board.targets.get(game.state.pawns[0].pos) == "missile" and game.state.flag not in game.board.targets,
		"Targeting highlights enemy and empty tiles while excluding the flag")
	await _capture("targeting")
	var target: Vector2i = game.state.pawns[0].pos
	game._square_pressed(target)
	_check(game.busy and game.state.turn_move and not game.state.pawns[5].charged, "Target click commits one missile and locks input")
	_check(target not in game.board.tiles and 0 not in game.board.pieces and game.board.missiles.is_empty(), "FX off applies impact immediately without animation")
	await create_timer(0.15).timeout
	_check(not game.busy and game.records.size() == 1, "FX off promptly unlocks the existing turn flow")

	_setup(game, false)
	game.state.pawns[0].pos = game.state.flag
	game.state.holder = 0
	game.legal = Rules.legal_actions(game.state)
	game._square_pressed(game.state.pawns[5].pos)
	_check(game.ability_hologram.ability_button.disabled and not game.ability_hologram.normal_button.disabled,
		"Enemy flag occupation disables the launch button while keeping normal moves")
	_check(game.ability_hologram.description.text.contains("enemy is on the flag"), "Blocked hologram explains flag lock")
	await _capture("flag-locked")

	_setup(game, true)
	game._square_pressed(game.state.pawns[5].pos)
	game._choose_hologram_action("ability")
	target = game.state.pawns[0].pos
	game._square_pressed(target)
	_check(game.board.missiles.size() == 1 and target in game.board.tiles and 0 in game.board.pieces, "Tile and enemy stay visible during missile flight")
	await create_timer(0.25).timeout
	_check(game.busy and target in game.board.tiles and 0 in game.board.pieces, "Flight holds game input and victim until impact")
	await _capture("in-flight")
	await create_timer(0.48).timeout
	_check(target not in game.board.tiles and 0 not in game.board.pieces and game.board.missiles[0].impacted,
		"Tile and enemy disappear at the animated impact")
	await _capture("explosion")
	await create_timer(0.18).timeout
	await _capture("blast")
	await create_timer(Arena.MISSILE_BLAST + 0.15).timeout
	_check(not game.busy and game.board.missiles.is_empty(), "Explosion completes before the turn unlocks and cleans up")
	await _capture("after-impact")

	_setup(game, true)
	game._commit(_shot(1, Vector2i(8, 5)))
	game._start(true)
	var rematch: Dictionary = game.state.duplicate(true)
	_check(game.board.missiles.is_empty(), "Reset cancels missile visuals from the old match")
	await create_timer(Arena.MISSILE_FLIGHT + Arena.MISSILE_BLAST + 0.15).timeout
	_check(game.board.missiles.is_empty() and game.state == rematch and game.records.is_empty(), "Canceled flight cannot affect the rematch")
	for button in game.overlay.find_children("*", "Button", true, false):
		if button.text == "Ready to draft":
			button.pressed.emit()
			break
	game._square_pressed(game.state.pawns[0].pos)
	game._assign("missile")
	_check(game.assignments.get(0) == "missile" and game.board.draft_slots.get(0) == "M", "Missile can be selected in the actual private draft")
	await _capture("draft")
	game._show_kalypso_guide(2)
	await _capture("abilities-guide")
	game._close_overlay(false)

	_setup(game, true)
	for id in range(1, 5):
		game.state.pawns.erase(id)
	game.legal = Rules.legal_actions(game.state)
	game._refresh()
	game._commit(_shot(1, game.state.pawns[0].pos))
	_check(game.state.phase == "finished" and game.busy and game.overlay_kind.is_empty(), "Winning missile keeps the board visible for its animation")
	await create_timer(Arena.MISSILE_FLIGHT + Arena.MISSILE_BLAST + 0.15).timeout
	_check(not game.busy and not game.overlay_kind.is_empty() and game.board.missiles.is_empty(), "Victory screen opens after the winning explosion completes")
	game.queue_free()
	await process_frame
	print("Missile: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)
