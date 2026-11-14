extends SceneTree

const Main = preload("../scripts/main.gd")
const Rules = preload("../scripts/rules.gd")
const Cards = preload("../scripts/ability_cards.gd")
var checks := 0
var failures := 0
var capture := false


func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _opening() -> Dictionary:
	var state := Rules.create_match(7, 1)
	state = Rules.apply_action(state, {"kind": "draft", "pawns": [0, 1], "spells": ["teleport", "fracture"]}).state
	return Rules.apply_action(state, {"kind": "draft", "pawns": [5, 6], "spells": ["shield", "borrow_tomorrow"]}).state


func _setup(game: Control) -> void:
	game.state = _opening()
	game.local_mode = true
	game.busy = false
	game.handoff = false
	game._clear_selection()
	game.records.clear()
	game.legal = Rules.legal_actions(game.state)
	game._close_overlay(false)
	game.chrome.show()
	game._refresh()


func _screenshot(name: String) -> void:
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/gamejam-cards-" + name + ".png")


func _run() -> void:
	root.size = Vector2i(1320, 850)
	var game := Main.new()
	root.add_child(game)
	_setup(game)
	var expected: Dictionary = Rules.apply_action(game.state, {"kind": "roll"}).state
	game._shuffle_ability()
	_check(game.busy and game.shuffling and game.card_reveal.visible, "Shuffle shows animation and locks game actions")
	_check(game.records.is_empty() and game.state.dice[game.state.active].is_empty(), "No ability is exposed before the reveal")
	game._shuffle_ability()
	game._skip_turn()
	_check(game.records.is_empty(), "Repeated shuffle and skip are blocked during animation")
	await create_timer(0.45).timeout
	await _screenshot("shuffle")
	await create_timer(1.05).timeout
	_check(game.state == expected and game.records.size() == 1, "Reveal commits exactly one original deterministic draw")
	_check(game.card_reveal.face == expected.dice[expected.active] and not game.shuffling, "Revealed card matches the gameplay power")
	_check(game.busy, "Game remains locked while the revealed card is shown")
	await _screenshot("reveal")
	await create_timer(Cards.REVEAL_HOLD + 0.1).timeout
	_check(not game.busy and not game.card_reveal.visible, "Reveal completes and unlocks the game")
	game._shuffle_ability()
	_check(game.records.size() == 1, "Cannot draw again after the card is drawn")
	var card_button: Button = game.side_panel.get_node("PowerCardButton")
	var skip_button: Button = game.side_panel.get_node("FinishTurnButton")
	_check(card_button.visible and card_button.get_rect().end.y < skip_button.position.y, "Revealed card remains above the finish button")
	_check(card_button.disabled, "A card without legal targets cannot activate")
	await _screenshot("panel")
	if capture:
		for power in Cards.POWERS:
			game.state.dice[game.state.active] = power
			game.card_reveal.reveal(power)
			game.card_reveal.elapsed = Cards.SHUFFLE_TIME + Cards.FLIP_TIME
			game.card_reveal.show()
			game._refresh()
			await _screenshot(power)
		game.card_reveal.hide()
	_setup(game)
	game.state.dice[game.state.active] = "infected_trail"
	game.legal = Rules.legal_actions(game.state)
	game._refresh()
	await process_frame
	card_button = game.side_panel.get_node("PowerCardButton")
	_check(not card_button.disabled, "A card with legal targets is clickable")
	var at := card_button.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = at
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)
	await process_frame
	_check(game.action_group == "power" and not game.board.targets.is_empty(), "Clicking the actual card highlights power targets")
	_check(game.records.is_empty(), "Clicking the card selects the power without spending it")
	await _screenshot("card_selected")
	game.motion = false
	var target: Vector2i = game.board.targets.keys()[0]
	game._square_pressed(target)
	await create_timer(0.2).timeout
	card_button = game.side_panel.get_node("PowerCardButton")
	_check(game.state.turn_power_used and card_button.disabled, "Selecting a board target spends and disables the card")
	_check(card_button.get_child(0).action_label == "Power used", "Spent card remains visible and is marked used")
	await _screenshot("card_used")
	_setup(game)
	game.motion = false
	game._shuffle_ability()
	_check(not game.busy and not game.card_reveal.visible and game.records.size() == 1, "FX off draws immediately without an animation lock")
	_setup(game)
	game.motion = true
	game._shuffle_ability()
	game._start(true)
	var new_state: Dictionary = game.state.duplicate(true)
	await create_timer(2.6).timeout
	_check(game.state == new_state and game.records.is_empty() and not game.card_reveal.visible, "New match cancels a pending shuffle without changing the new match")
	_setup(game)
	game.local_mode = false
	game.state.active = 0
	game.legal = Rules.legal_actions(game.state)
	game._commit({"kind": "roll"})
	_check(game.shuffling and game.card_reveal.visible, "Solo opponent uses the same shuffle animation")
	game.generation += 1
	game.card_reveal.hide()
	await create_timer(1.5).timeout
	game.queue_free()
	print("Card shuffle: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)
