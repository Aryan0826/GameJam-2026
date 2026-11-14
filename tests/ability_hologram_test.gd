extends SceneTree
const Main = preload("res://scripts/battle/battle.gd")
const Rules = preload("res://scripts/rules/rules.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _setup(game: Control, shuffled: bool = true) -> void:
	game.generation += 1
	var state := Rules.create_match(7, 1)
	state = Rules.apply_action(state, {"kind": "draft", "pawns": [0, 1], "spells": ["teleport", "fracture"]}).state
	state = Rules.apply_action(state, {"kind": "draft", "pawns": [5, 6], "spells": ["teleport", "shield"]}).state
	if shuffled: state = Rules.apply_action(state, {"kind": "roll"}).state
	game.state = state
	game.busy = false
	game.handoff = false
	game.local_mode = true
	game.motion = false
	game.board.motion = false
	game.records.clear()
	game._clear_selection()
	game.legal = Rules.legal_actions(state)
	game._close_overlay(false)
	game.chrome.show()
	game._refresh()

func _click(button: Button) -> void:
	var at := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _run() -> void:
	root.size = Vector2i(1320, 850)
	root.content_scale_size = Vector2i(1320, 850)
	var game := Main.new()
	root.add_child(game)
	current_scene = game
	if game._communication_tween: game._communication_tween.kill()
	_setup(game)
	game._square_pressed(game.state.pawns[5].pos)
	await process_frame
	var holo: Control = game.ability_hologram
	_check(holo.visible and holo.heading.text == "TELEPORT", "Selecting a charged ship shows its ability hologram")
	_check(game.board.coordinate_mask == holo.card.get_rect(), "Only coordinate labels behind the hologram are masked")
	_check(not holo.normal_button.disabled and not holo.ability_button.disabled, "Hologram offers both a normal move and the drafted ability")
	_check(not holo.card.get_rect().has_point(holo.anchor), "Hologram leaves the selected ship unobstructed")
	_click(holo.ability_button)
	await process_frame
	_check(game.action_group == "ability" and not game.board.targets.is_empty(), "Clicking the hologram's ability choice highlights legal targets")
	_check(game.records.is_empty() and game.state.pawns[5].charged, "Choosing the ability never spends it before a target is selected")
	_check(holo.card.size.y == 124 and holo.description.text == "Choose a landing tile", "Targeting compacts the hologram into a landing prompt")
	_click(holo.normal_button)
	await process_frame
	_check(game.action_group == "standard" and game.state.pawns[5].charged, "Player can switch back to normal movement without spending the ability")
	var step: Dictionary = game._group_actions("standard")[0]
	game._square_pressed(step.to)
	await create_timer(0.2).timeout
	_check(game.records.size() == 1 and game.state.pawns[5].charged, "Playing a normal move keeps the drafted charge")
	_check(not holo.visible, "Hologram closes after the move")
	_check(not game.board.coordinate_mask.has_area(), "Board coordinates return when the hologram closes")
	_setup(game)
	game._square_pressed(game.state.pawns[5].pos)
	game._choose_hologram_action("ability")
	var teleport: Dictionary = game._group_actions("ability")[0]
	game._square_pressed(teleport.to)
	await create_timer(0.2).timeout
	_check(game.records.size() == 1 and not game.state.pawns[5].charged and game.state.pawns[5].pos == teleport.to, "Choosing a valid target spends exactly one Teleport charge")
	_check(not holo.visible, "Used ability cannot leave a stale hologram")
	_setup(game, false)
	game._square_pressed(game.state.pawns[5].pos)
	_check(holo.visible and holo.status.text == "SHUFFLE FIRST" and holo.ability_button.disabled and holo.normal_button.disabled, "Before shuffling the ability remains discoverable and explains the lock")
	_setup(game)
	game._square_pressed(game.state.pawns[7].pos)
	_check(not holo.visible, "Ships without abilities show no hologram")
	game._square_pressed(game.state.pawns[6].pos)
	_check(holo.heading.text == "SHIELD", "Selecting a different assigned ship updates the hologram")
	game._choose_hologram_action("ability")
	game._square_pressed(game.state.pawns[6].pos)
	await create_timer(0.2).timeout
	_check(game.state.pawns[6].shield and not game.state.pawns[6].charged, "Shield still activates by targeting the selected ship")
	_setup(game)
	game.state.pawns[6].pos = game.state.flag
	game.legal = Rules.legal_actions(game.state)
	game._square_pressed(game.state.flag)
	_check(holo.visible and holo.ability_button.disabled and not holo.normal_button.disabled and holo.description.text.contains("flag"), "Shield on the flag explains why only normal movement is available")
	_setup(game)
	game.state.active = 0
	game.state = Rules.apply_action(game.state, {"kind": "roll"}).state
	game.legal = Rules.legal_actions(game.state)
	game._square_pressed(game.state.pawns[1].pos)
	game._choose_hologram_action("ability")
	_check(holo.heading.text == "FRACTURE TILE" and holo.description.text == "Choose a tile to fracture", "Fracture uses its own hologram and target prompt")
	var fracture: Dictionary = game._group_actions("ability")[0]
	game._square_pressed(fracture.to)
	await create_timer(0.2).timeout
	_check(game.state.fractures.has(fracture.to) and not game.state.pawns[1].charged, "Hologram-driven Fracture marks the tile and spends its charge")
	_setup(game)
	game._square_pressed(game.state.pawns[5].pos)
	var before: Vector2 = holo.anchor
	game.board.camera_yaw += 0.8
	game.board._update_camera()
	await process_frame
	await process_frame
	_check(not holo.anchor.is_equal_approx(before) and holo.card.position.x >= 8 and holo.card.get_rect().end.x <= game.board.size.x - 8, "Hologram follows camera rotation and stays inside the board")
	game._modal("rules", "Test overlay")
	await process_frame
	_check(not holo.visible, "A modal hides the hologram and its controls")
	_check(not game.board.coordinate_mask.has_area(), "Opening a modal removes the coordinate mask")
	game._close_overlay(false)
	game.busy = true
	game._refresh()
	_check(not holo.visible, "Resolving a turn hides the controls")
	_setup(game)
	game.state.active = 0
	game.local_mode = false
	game.selected = 0
	game.legal = Rules.legal_actions(game.state)
	game._refresh()
	_check(not holo.visible, "Opponent's ships cannot expose clickable ability controls in solo")
	_setup(game)
	game.state.active = 0
	game.legal = Rules.legal_actions(game.state)
	game._square_pressed(game.state.pawns[0].pos)
	await process_frame
	_check(holo.visible and not holo.card.get_rect().has_point(holo.anchor), "Raised hologram leaves top-row ships unobstructed")
	game.queue_free()
	await process_frame
	print("Ability hologram: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)
