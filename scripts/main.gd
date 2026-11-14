extends Control

const Rules = preload("res://scripts/rules.gd")
const Bot = preload("res://scripts/bot.gd")
const Arena = preload("res://scripts/board.gd")
const PHOTO = preload("res://art/westerlund-2.jpg")
const SANS = preload("res://art/SpaceGrotesk.ttf")
const MONO = preload("res://art/IBMPlexMono-Regular.ttf")

const INK = Color("#f3f5ff")
const MUTED = Color("#aab8d1")
const GOLD = Color("#f8d587")
const LILAC = Color("#b99dfd")
const NORTH = Color("#ff937e")
const SOUTH = Color("#83e1fa")
const PANEL = Color("#11192a")
const LINE = Color("#34445f")
const SIDES = ["Aliens", "Pilots"]
const SPELLS = {
	"shield": ["Shield", "Absorb one capture outside the flag."],
	"fracture": ["Fracture Tile", "Mark a tile to fall after the next turn, along with any pawn on it."],
	"teleport": ["Teleport", "Jump to any open tile outside the flag."],
	"borrow_tomorrow": ["Borrow Tomorrow", "Move this pawn, then a different ally. The first pawn owes a return."],
	"infected_trail": ["Infected Trail", "Infect the 3 × 3 area around your move’s starting tile through the enemy turn."],
	"spy": ["Spy", "Take control of a nearby enemy pawn for your next three turns. It cannot score the flag."],
	"long_capture": ["Long Capture", "Capture diagonally in any direction, from one or two squares away."],
}
const DRAFT_SPELLS = Rules.SPELLS
const IMAGE_CREDIT = "NASA, ESA, the Hubble Heritage Team (STScI/AURA), A. Nota (ESA/STScI), and the Westerlund 2 Science Team"
const IMAGE_URL = "https://esahubble.org/images/heic1509a/"
const RULES_TEXT = """[color=#f8d587]WIN THE DUEL[/color]
Hold the center flag through three enemy turns with the same pawn, or remove every enemy pawn. The match draws after round 8 if neither side wins.

[color=#f8d587]TAKE ONE ACTION[/color]
Move one tile orthogonally or one or two diagonally in any direction. A two-tile diagonal can jump a pawn or hole. Regular captures are one tile diagonally forward: down for Aliens and up for Pilots. Enter the flag from an adjacent square or by making a capture.

[color=#f8d587]WATCH THE RIM[/color]
Cracks are safe until the round ends. Opposite pairs fall in rounds 2 and 4. Each remaining rim falls in rounds 3 and 5. Any pawn on a falling tile is removed.

[color=#f8d587]DRAFT ONE-USE ABILITIES[/color]
Shield absorbs one capture and disappears on flag entry. Teleport jumps to any empty, intact, uninfected non-flag tile. Fracture marks any intact non-flag tile to drop after the next turn, removing its occupant.

Borrow Tomorrow moves its assigned pawn one orthogonal step, then moves another ally one orthogonal step. The first pawn cannot enter or leave the flag. At the end of your next turn it returns to its echo, or is removed if that tile is blocked, infected or gone.

[color=#f8d587]ROLL FOR AN ABILITY[/color]
Each player can roll once per round before acting. Rolling is optional and does not spend the turn. After rolling, take a normal move and optionally use the rolled power as part of that turn, or take a normal move alone.

Infected Trail infects the 3 × 3 area around the normal move’s starting tile through the enemy turn, except the flag. Spy takes control of an enemy within two orthogonal steps of any ally after the move. It returns after three of your subsequent turns. It may stand on the flag but cannot score or capture there while stolen. Long Capture lets one of your pawns capture an enemy one or two tiles diagonally in any direction after your normal move.

[color=#f8d587]CONTROLS[/color]
Click a pawn, choose an action, then click its target. Arrow keys move the board cursor and Enter selects. Esc clears a selection or closes help. In solo, Take Over Aliens switches to local play on the next alien turn boundary."""

var state: Dictionary = {}
var legal: Array[Dictionary] = []
var records: Array[Dictionary] = []
var messages: Array[String] = []
var board: Control
var chrome: Control
var side_panel: Control
var overlay: Control
var round_label: Label
var status_label: Label
var mode_button: Button
var takeover_button: Button
var motion_button: Button
var feedback: Label
var local_mode := false
var takeover_queued := false
var handoff := false
var motion := true
var busy := false
var generation := 0
var selected := -1
var action_group := "standard"
var first_destination := Vector2i.ZERO
var second_pawn := -1
var pending_move: Dictionary = {}
var assignments: Dictionary = {}
var overlay_kind := ""
var first_flag_round := 0
var started_at := 0
var finished_at := 0
var bold: FontVariation


func _ready() -> void:
	bold = FontVariation.new()
	bold.base_font = SANS
	bold.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): 700 }
	_build_frame()
	_show_home()


func _build_frame() -> void:
	var photo := TextureRect.new()
	photo.texture = PHOTO
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(photo)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.085, 0.70)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	chrome = _layer(self)
	_panel(chrome, Rect2(44, 148, 776, 651), Color("#141c2f"), LINE, 17)
	_label(chrome, Rect2(66, 158, 300, 23), "ARENA  /  THE FRACTURED FLAG", 13, MUTED, MONO)
	status_label = _label(chrome, Rect2(350, 158, 446, 23), "", 13, GOLD, MONO)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	board = Arena.new()
	_place(chrome, board, Rect2(66, 153, 730, 642))
	board.square_pressed.connect(_square_pressed)
	board.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey:
			_unhandled_key_input(event))
	_label(chrome, Rect2(44, 21, 560, 24), "THE FRACTURED FLAG", 13, GOLD, MONO)
	_label(chrome, Rect2(42, 44, 600, 61), "Conqueror’s Chess", 47, INK, bold)
	round_label = _label(chrome, Rect2(46, 105, 780, 24), "", 15, MUTED, MONO)
	mode_button = _button(chrome, Rect2(818, 52, 104, 36), "Solo", _show_modes)
	takeover_button = _button(chrome, Rect2(930, 52, 154, 36), "Take Over Aliens", _takeover)
	_button(chrome, Rect2(1092, 52, 82, 36), "Rules", _show_rules)
	motion_button = _button(chrome, Rect2(1182, 52, 94, 36), "FX on", _toggle_motion)
	feedback = _label(chrome, Rect2(846, 105, 430, 31), "", 15, GOLD)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	side_panel = _layer(chrome)
	var credit := _label(self, Rect2(46, 810, 1050, 26), "Westerlund 2  /  " + IMAGE_CREDIT, 12, INK)
	credit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button(self, Rect2(1160, 807, 116, 30), "Asset credits", _show_credits)
	overlay = _layer(self)


func _layer(parent: Node) -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	return layer


func _place(parent: Node, item: Control, rect: Rect2) -> Control:
	item.position = rect.position
	item.size = rect.size
	parent.add_child(item)
	return item


func _style(fill: Color, edge: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style


func _panel(parent: Node, rect: Rect2, fill: Color = PANEL, edge: Color = LINE, radius: int = 12) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _style(fill, edge, radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(parent, p, rect)
	return p


func _label(parent: Node, rect: Rect2, value: String, px: int, color: Color = INK, font: Font = SANS, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(parent, label, rect)
	return label


func _button(parent: Node, rect: Rect2, title: String, callback: Callable, accent: bool = false) -> Button:
	var button := Button.new()
	button.text = title
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", bold)
	button.add_theme_font_size_override("font_size", 15)
	var fill := Color("#2a2850") if accent else Color("#1b263c")
	var edge := LILAC if accent else LINE
	button.add_theme_stylebox_override("normal", _style(fill, edge, 8))
	button.add_theme_stylebox_override("hover", _style(fill.lightened(0.18), SOUTH, 8))
	button.add_theme_stylebox_override("pressed", _style(fill.lightened(0.26), GOLD, 8))
	button.add_theme_stylebox_override("disabled", _style(Color("#141d2e"), Color("#29374c"), 8))
	var focus := _style(Color.TRANSPARENT, SOUTH, 8)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("#78869f"))
	_place(parent, button, rect)
	button.pressed.connect(callback)
	return button


func _clear(layer: Node) -> void:
	for child in layer.get_children():
		layer.remove_child(child)
		child.queue_free()


func _show_home() -> void:
	chrome.hide()
	_clear(overlay)
	overlay_kind = "home"
	_panel(overlay, Rect2(55, 126, 575, 560), Color(0.055, 0.078, 0.14, 0.96), LINE, 18)
	_label(overlay, Rect2(93, 170, 497, 26), "THE FRACTURED FLAG", 15, GOLD, MONO)
	_label(overlay, Rect2(88, 204, 521, 154), "Conqueror’s\nChess", 68, INK, bold)
	_label(overlay, Rect2(93, 390, 465, 63), "Hold the flag through three enemy turns or eliminate the opposing pawns before the arena breaks apart.", 22, MUTED, SANS, true)
	_button(overlay, Rect2(93, 494, 461, 49), "Play solo", func(): _start(false), true)
	_button(overlay, Rect2(93, 555, 220, 43), "Play local duel", func(): _start(true))
	_button(overlay, Rect2(327, 555, 227, 43), "How to play", _show_rules)
	_button(overlay, Rect2(93, 608, 461, 38), "Prologue / Story", _show_story)


func _show_story() -> void:
	get_tree().change_scene_to_file("res://scenes/opening_crawl.tscn")


func _start(local: bool, rematch: bool = false) -> void:
	generation += 1
	busy = false
	local_mode = local
	takeover_queued = false
	handoff = false
	var first: int = 1 - int(state.first) if rematch else -1
	var seed_value := randi()
	while not state.is_empty() and seed_value == state.seed:
		seed_value = randi()
	state = Rules.create_match(seed_value, first)
	records.clear()
	messages.clear()
	assignments.clear()
	first_flag_round = 0
	started_at = 0
	finished_at = 0
	feedback.text = ""
	board.reset_visuals()
	board.keyboard_square = Vector2i.ZERO
	_clear_selection()
	_close_overlay(false)
	chrome.show()
	if local_mode:
		_show_handoff()
	_enter_turn()


func _enter_turn() -> void:
	legal = Rules.legal_actions(state)
	if state.phase == "playing" and state.active == 0 and takeover_queued:
		local_mode = true
		takeover_queued = false
		_note("Aliens are now controlled by Player 2.")
	_refresh()
	if overlay_kind != "" or busy or handoff:
		return
	if state.phase == "finished":
		_show_result()
	elif state.phase == "playing" and legal.size() == 1 and legal[0].kind == "pass":
		_schedule_action(legal[0], 0.32)
	elif not local_mode and state.active == 0:
		if state.phase == "draft":
			_commit(Bot.choose(state, legal))
		else:
			_schedule_action({}, 0.45)


func _schedule_action(action: Dictionary, delay: float) -> void:
	busy = true
	var stamp := generation
	_refresh()
	await get_tree().create_timer(delay).timeout
	if stamp != generation:
		return
	busy = false
	if overlay_kind != "":
		return
	var choice := Bot.choose(state, legal) if action.is_empty() else action
	_commit(choice)


func _commit(action: Dictionary) -> void:
	if busy or action.is_empty():
		return
	var result := Rules.apply_action(state, action)
	if not result.ok:
		_note("That action is no longer available.")
		_refresh()
		return
	var was_draft: bool = state.phase == "draft"
	var played_round: int = state.round
	state = result.state
	records.append(action.duplicate(true))
	var rolled: bool = action.kind == "roll"
	if not rolled:
		_clear_selection()
	if was_draft:
		assignments.clear()
		if state.phase == "draft" and local_mode:
			_show_handoff()
		elif state.phase == "playing":
			started_at = Time.get_ticks_msec()
	elif state.phase == "finished":
		finished_at = Time.get_ticks_msec()
	board.show_events(result.events)
	for event: Dictionary in result.events:
		if first_flag_round == 0 and event.kind == "flag" and event.get("pawn", -1) >= 0:
			first_flag_round = played_round
		if event.kind not in ["turn", "draft_lock"]:
			messages.push_front(event.text)
			if messages.size() > 12:
				messages.pop_back()
	legal = Rules.legal_actions(state)
	if rolled:
		if not local_mode and state.active == 0:
			_schedule_action({}, 0.24 if motion else 0.10)
		else:
			_refresh()
		return
	if was_draft:
		_enter_turn()
		return
	busy = true
	_refresh()
	var stamp := generation
	await get_tree().create_timer(0.65 if motion else 0.10).timeout
	if stamp != generation:
		return
	busy = false
	_enter_turn()


func _takeover() -> void:
	if state.phase != "playing" or local_mode or takeover_queued:
		return
	takeover_queued = true
	_note("Takeover queued for the next Alien turn.")
	_refresh()


func _toggle_motion() -> void:
	motion = not motion
	board.motion = motion
	motion_button.text = "FX on" if motion else "FX off"


func _note(value: String) -> void:
	feedback.text = value
	var msg := value
	get_tree().create_timer(4.0).timeout.connect(func():
		if feedback.text == msg:
			feedback.text = "")


func _refresh() -> void:
	if state.is_empty():
		return
	board.state = state
	board.selected = selected
	board.second = second_pawn
	board.preview_to = first_destination
	board.draft_slots = {}
	for pawn: int in assignments:
		board.draft_slots[pawn] = Arena.SPELL_ICON[assignments[pawn]]
	board.targets = _targets()
	board.sync()
	var draft: bool = state.phase == "draft"
	round_label.text = "PRIVATE DRAFT" if draft else "ROUND %02d / 08     ·     %s" % [state.round, "DUEL COMPLETE" if state.phase == "finished" else SIDES[state.active].to_upper() + " TO ACT"]
	var flag_status := "%d/%d HELD" % [state.replies, Rules.FLAG_REPLIES] if state.holder >= 0 else "UNCLAIMED"
	var occupant := _pawn_at(state.flag)
	if state.holder < 0 and occupant >= 0:
		flag_status = "STOLEN PAWN  /  NO SCORE"
	status_label.text = "FLAG  %s     /     %s" % [_coord(state.flag), flag_status]
	mode_button.text = "Local" if local_mode else "Solo"
	takeover_button.disabled = draft or local_mode or takeover_queued or state.phase != "playing"
	takeover_button.text = "Takeover queued" if takeover_queued else "Take Over Aliens"
	_clear(side_panel)
	if draft:
		_draw_draft()
	else:
		_draw_play()


func _draw_draft() -> void:
	var color := NORTH if state.active == 0 else SOUTH
	_panel(side_panel, Rect2(846, 148, 430, 651))
	_label(side_panel, Rect2(868, 166, 380, 28), "%s  /  PRIVATE DRAFT" % SIDES[state.active].to_upper(), 14, color, MONO)
	_label(side_panel, Rect2(868, 200, 380, 46), "Assign two abilities", 33, INK, bold)
	_label(side_panel, Rect2(869, 254, 376, 53), "Select a pawn on the board, then an ability. Assign a different ability to a second pawn.", 17, MUTED, SANS, true)
	var y := 326
	for spell: String in DRAFT_SPELLS:
		var title: String = SPELLS[spell][0]
		var assigned = assignments.find_key(spell)
		if assigned != null:
			title += "  ·  " + _coord(state.pawns[assigned].pos)
		var control := _button(side_panel, Rect2(869, y, 382, 32), title, _assign.bind(spell), assigned != null)
		control.disabled = selected < 0 or handoff
		_label(side_panel, Rect2(870, y + 36, 376, 33), SPELLS[spell][1], 14, MUTED, SANS, true)
		y += 82
	var lock := _button(side_panel, Rect2(869, 697, 382, 48), "Lock draft  ·  %d / 2" % assignments.size(), _lock_draft, true)
	lock.disabled = assignments.size() != 2 or handoff
	var caption := "Click an Alien pawn to begin." if state.active == 0 else "Click a Pilot pawn to begin."
	if selected >= 0:
		caption = "Selected " + _coord(state.pawns[selected].pos)
		if selected in assignments:
			caption += "  ·  " + SPELLS[assignments[selected]][0]
	_label(side_panel, Rect2(870, 755, 379, 28), caption, 14, color, MONO)


func _draw_play() -> void:
	_team_card(846, 148, 0)
	_team_card(1067, 148, 1)
	_panel(side_panel, Rect2(846, 238, 430, 108))
	_label(side_panel, Rect2(864, 249, 180, 22), "ABILITY DIE", 12, MUTED, MONO)
	var face: String = state.dice[state.active]
	var special_name: String = SPELLS[face][0] if not face.is_empty() else "Ready to roll"
	_label(side_panel, Rect2(864, 273, 209, 32), special_name, 23, LILAC, bold)
	var roll := _button(side_panel, Rect2(1073, 268, 185, 36), "Roll ability" if face.is_empty() else "Roll: %d" % state.rolls[state.active], _roll_ability, face.is_empty())
	roll.disabled = busy or state.phase != "playing" or not face.is_empty() or (not local_mode and state.active == 0)
	var drops := "Purple cracks fall after this turn." if not state.fractures.is_empty() else "Rim cracks fall after both turns."
	if state.fractures.is_empty() and state.cracks.is_empty():
		drops = "Optional roll. Your move is always available."
	_label(side_panel, Rect2(864, 310, 390, 25), drops, 14, GOLD if not state.cracks.is_empty() or not state.fractures.is_empty() else MUTED)
	_panel(side_panel, Rect2(846, 359, 430, 282))
	_label(side_panel, Rect2(864, 369, 396, 25), "ACTION", 12, MUTED, MONO)
	_label(side_panel, Rect2(864, 396, 394, 55), _action_hint(), 16, INK, SANS, true)
	if selected >= 0 and selected in state.pawns:
		var p: Dictionary = state.pawns[selected]
		_action_button(Rect2(864, 462, 189, 38), "Move / capture", "standard")
		if p.ability != "":
			_action_button(Rect2(864, 509, 189, 38), SPELLS[p.ability][0], "ability")
		if not face.is_empty():
			_action_button(Rect2(1062, 462, 196, 38), "Move + " + SPELLS[face][0], "combo")
		var details := Rules.ability_reason(state, p) if p.ability != "" else ""
		if not p.borrow.is_empty():
			details = "Returns to %s at the end of this turn." % _coord(p.borrow.origin)
		elif p.spy > 0:
			details = "Stolen pawn · %d turns left. Cannot score or capture on the flag." % p.spy
		elif details.is_empty() and action_group == "ability":
			details = SPELLS[p.ability][1]
		elif details.is_empty() and action_group == "combo":
			details = SPELLS[face][1]
		if not details.is_empty():
			_label(side_panel, Rect2(865, 595, 387, 36), details, 13, MUTED, SANS, true)
	else:
		_label(side_panel, Rect2(864, 473, 394, 40), "Hold the flag through three enemy turns.", 19, GOLD, bold, true)
		_label(side_panel, Rect2(864, 518, 390, 67), "Choose a pawn to see its moves. Red cracks mark the rim and purple cracks mark a fractured tile.", 15, MUTED, SANS, true)
	_panel(side_panel, Rect2(846, 654, 430, 145))
	_label(side_panel, Rect2(864, 665, 270, 22), "FLIGHT LOG", 12, MUTED, MONO)
	_button(side_panel, Rect2(1162, 663, 97, 27), "View log", _show_log)
	var latest := messages.slice(0, 3)
	for i in range(latest.size()):
		var line := _label(side_panel, Rect2(864, 695 + i * 30, 389, 27), latest[i], 14, INK if i == 0 else MUTED)
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _team_card(x: float, y: float, side: int) -> void:
	var color := NORTH if side == 0 else SOUTH
	var active: bool = state.active == side and state.phase == "playing"
	_panel(side_panel, Rect2(x, y, 209, 78), PANEL, color if active else LINE)
	_label(side_panel, Rect2(x + 15, y + 8, 179, 31), SIDES[side] + ("  ↓" if side == 0 else "  ↑"), 24, color, bold)
	var count := 0
	for pawn: Dictionary in state.pawns.values():
		if pawn.side == side:
			count += 1
	_label(side_panel, Rect2(x + 16, y + 42, 179, 24), "%d PAWNS IN PLAY" % count, 13, MUTED, MONO)


func _roll_ability() -> void:
	if busy or {"kind": "roll"} not in legal or (not local_mode and state.active == 0):
		return
	board.grab_focus()
	if motion:
		busy = true
		var stamp := generation
		_refresh()
		_note("Rolling the ability die…")
		await get_tree().create_timer(0.28).timeout
		if stamp != generation:
			return
		busy = false
		feedback.text = ""
	_commit({"kind": "roll"})


func _action_hint() -> String:
	if state.phase == "finished":
		return "Duel complete."
	if busy:
		if not local_mode and state.active == 0:
			return "Aliens are taking their turn."
		return "Resolving the turn."
	if selected < 0:
		return "Select one of your pawns to see its legal actions."
	var p: Dictionary = state.pawns[selected]
	if not p.borrow.is_empty():
		return "This pawn is waiting to return to its echo."
	if action_group == "combo":
		if pending_move.is_empty():
			return "Choose a normal move to use the rolled power."
		match state.dice[state.active]:
			"spy":
				return "Select a highlighted enemy pawn to take control."
			"long_capture":
				return "Choose a pawn, then a highlighted capture target." if second_pawn < 0 else "Select a highlighted long-capture target."
	if action_group == "ability" and p.ability == "borrow_tomorrow":
		if first_destination == Vector2i.ZERO:
			return "Choose where the borrowed pawn steps."
		if second_pawn < 0:
			return "Choose the second pawn."
		return "Choose where the second pawn steps to commit both moves."
	if action_group == "ability" and p.ability == "shield":
		return "Select the highlighted pawn again to raise its shield."
	if action_group == "ability" and p.ability == "fracture":
		return "Select a tile to drop after the next turn."
	if _group_actions(action_group).is_empty():
		return "This pawn has no legal target for the selected action."
	return "Select a highlighted destination for %s." % _coord(p.pos)


func _action_button(rect: Rect2, title: String, group: String) -> void:
	var control := _button(side_panel, rect, title, _set_group.bind(group), action_group == group)
	control.disabled = busy or _group_actions(group).is_empty()


func _set_group(group: String) -> void:
	action_group = group
	first_destination = Vector2i.ZERO
	second_pawn = -1
	pending_move = {}
	board.grab_focus()
	_refresh()


func _group_actions(group: String) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if selected < 0 or selected not in state.pawns:
		return choices
	for a in legal:
		match group:
			"standard":
				if a.get("pawn", -1) == selected and a.kind in ["step", "capture"]:
					choices.append(a)
			"ability":
				if a.get("pawn", -1) == selected and a.kind == state.pawns[selected].ability:
					choices.append(a)
			"combo":
				if a.kind == "combined" and a.move.pawn == selected:
					if not pending_move.is_empty() and a.move != pending_move:
						continue
					if second_pawn >= 0 and a.power.kind == "long_capture" and a.power.pawn != second_pawn:
						continue
					choices.append(a)
	return choices


func _targets() -> Dictionary:
	var highlighted := {}
	if busy or state.phase != "playing" or selected < 0:
		return highlighted
	for action in _group_actions(action_group):
		if action.kind == "combined" and action_group == "combo":
			if pending_move.is_empty():
				highlighted[action.move.to] = "capture" if action.move.kind == "capture" else "move"
			elif action.power.kind == "spy":
				highlighted[state.pawns[action.power.mark].pos] = "mark"
			elif action.power.kind == "long_capture" and second_pawn < 0:
				highlighted[state.pawns[action.power.pawn].pos] = "mark"
			elif action.power.kind == "long_capture":
				highlighted[action.power.to] = "capture"
		elif action.kind == "borrow_tomorrow" and first_destination != Vector2i.ZERO:
			if action.to == first_destination:
				if second_pawn < 0:
					highlighted[state.pawns[action.second].pos] = "mark"
				elif action.second == second_pawn:
					highlighted[action.second_to] = "move"
		else:
			highlighted[action.to] = "capture" if action.kind in ["capture", "long_capture"] else "move"
			if action.kind == "fracture":
				highlighted[action.to] = "fracture"
	return highlighted


func _square_pressed(square: Vector2i) -> void:
	if busy or handoff or overlay_kind != "" or state.phase == "finished" or (not local_mode and state.active == 0):
		return
	var id := _pawn_at(square)
	if state.phase == "draft":
		if id >= 0 and state.pawns[id].side == state.active:
			selected = id
			_refresh()
		return
	for action in _group_actions(action_group):
		if action.kind == "combined" and action_group == "combo":
			if pending_move.is_empty() and action.move.to == square:
				if action.power.kind == "infected_trail":
					_commit(action)
				else:
					pending_move = action.move.duplicate(true)
					second_pawn = -1
					_refresh()
				return
			if not pending_move.is_empty():
				if action.power.kind == "spy" and state.pawns[action.power.mark].pos == square:
					_commit(action)
					return
				if action.power.kind == "long_capture":
					if second_pawn < 0 and id == action.power.pawn:
						second_pawn = id
						_refresh()
						return
					if second_pawn >= 0 and action.power.pawn == second_pawn and action.power.to == square:
						_commit(action)
						return
			continue
		if _select_target(action, square, id):
			return
	if not pending_move.is_empty():
		return
	if id >= 0 and state.pawns[id].side == state.active:
		_clear_selection()
		selected = id
		if _group_actions("standard").is_empty():
			for group: String in ["ability", "combo"]:
				if not _group_actions(group).is_empty():
					action_group = group
					break
		_refresh()


func _select_target(action: Dictionary, square: Vector2i, id: int) -> bool:
	if action.kind == "borrow_tomorrow":
		if first_destination == Vector2i.ZERO and action.to == square:
			first_destination = square
			_refresh()
			return true
		if action.to != first_destination:
			return false
		if second_pawn < 0 and id == action.second:
			second_pawn = id
			_refresh()
			return true
		if second_pawn >= 0 and action.second == second_pawn and action.second_to == square:
			_commit(action)
			return true
		return false
	if action.to == square:
		_commit(action)
		return true
	return false


func _pawn_at(square: Vector2i) -> int:
	for p: Dictionary in state.pawns.values():
		if p.pos == square:
			return p.id
	return -1


func _assign(spell: String) -> void:
	if selected < 0 or handoff:
		return
	if assignments.get(selected, "") == spell:
		assignments.erase(selected)
	else:
		var old = assignments.find_key(spell)
		if old != null:
			assignments.erase(old)
		if assignments.size() == 2 and selected not in assignments:
			_note("Select an assigned pawn to change its ability.")
			return
		assignments[selected] = spell
	_refresh()


func _lock_draft() -> void:
	if assignments.size() != 2:
		return
	var pawns := assignments.keys()
	pawns.sort()
	_commit({"kind": "draft", "pawns": pawns, "spells": [assignments[pawns[0]], assignments[pawns[1]]]})


func _clear_selection() -> void:
	selected = -1
	action_group = "standard"
	first_destination = Vector2i.ZERO
	second_pawn = -1
	pending_move = {}


func _coord(p: Vector2i) -> String:
	return char(64 + p.x) + str(p.y)


func _modal(kind: String, title: String, height: float = 520) -> Panel:
	_clear(overlay)
	overlay_kind = kind
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.032, 0.07, 0.86)
	_place(overlay, dim, Rect2(0, 0, 1320, 807))
	var box := _panel(overlay, Rect2(319, (807 - height) / 2, 682, height), PANEL, LINE, 18)
	_label(box, Rect2(29, 19, 622, 59), title, 39, INK, bold)
	return box


func _show_handoff() -> void:
	handoff = true
	chrome.hide()
	var box := _modal("handoff", "Pass to the %s player" % SIDES[state.active], 274)
	_label(box, Rect2(31, 98, 610, 57), "Your draft is private until both players lock their choices.", 21, MUTED, SANS, true)
	_button(box, Rect2(31, 186, 620, 45), "Ready to draft", func():
		handoff = false
		chrome.show()
		_close_overlay(), true)


func _show_rules() -> void:
	var box := _modal("rules", "How to play", 702)
	_rich(box, Rect2(31, 94, 621, 516), RULES_TEXT)
	_button(box, Rect2(31, 634, 620, 41), "Back", _close_overlay)


func _show_credits() -> void:
	var box := _modal("credits", "Asset credits", 495)
	_rich(box, Rect2(31, 92, 620, 317), "[color=#f8d587]WESTERLUND 2[/color]\n[url=" + IMAGE_URL + "]" + IMAGE_CREDIT + "[/url]\nHubble observation. CC BY 4.0. Cropped on screen with a dark overlay.\n\n[color=#f8d587]3D ARENA AND PAWNS[/color]\nGodot primitives and a revolved mesh profile built into the project.\n\n[color=#f8d587]TYPE[/color]\n[url=https://github.com/floriankarsten/space-grotesk]Space Grotesk · Florian Karsten[/url]\n[url=https://github.com/IBM/plex]IBM Plex Mono · IBM Corp.[/url]\nBoth SIL Open Font License 1.1.")
	_button(box, Rect2(31, 427, 620, 41), "Back", _close_overlay)


func _show_modes() -> void:
	if state.is_empty():
		return
	var box := _modal("modes", "Start a new duel", 335)
	_label(box, Rect2(31, 92, 622, 45), "Starting a new duel replaces the current match.", 20, MUTED, SANS, true)
	_button(box, Rect2(31, 156, 620, 41), "Play solo", func(): _start(false), true)
	_button(box, Rect2(31, 209, 620, 41), "Play local duel", func(): _start(true))
	_button(box, Rect2(31, 262, 620, 41), "Resume", _close_overlay)


func _show_log() -> void:
	var box := _modal("log", "Flight log", 588)
	var history := "Seed %d  ·  %d committed actions\n\n" % [state.seed, records.size()]
	for line in messages:
		history += line + "\n\n"
	_rich(box, Rect2(31, 91, 620, 395), history)
	_button(box, Rect2(31, 511, 302, 43), "Copy replay data", _copy_replay)
	_button(box, Rect2(348, 511, 303, 43), "Back", _close_overlay)


func _copy_replay() -> void:
	var actions: Array[Dictionary] = []
	for record in records:
		var action := record.duplicate()
		for key in ["to", "second_to"]:
			if key in action:
				var p: Vector2i = action[key]
				action[key] = [p.x, p.y]
		actions.append(action)
	var end := finished_at if finished_at > 0 else Time.get_ticks_msec()
	var replay := {
		"rules_version": 2, "seed": state.seed, "first": state.first, "actions": actions,
		"first_flag_round": first_flag_round, "result": state.reason, "winner": state.winner,
		"elapsed_ms": end - started_at if started_at > 0 else 0,
	}
	DisplayServer.clipboard_set(JSON.stringify(replay))
	_note("Replay copied.")
	_close_overlay()


func _show_result() -> void:
	var title := "Draw" if state.winner < 0 else "%s win" % SIDES[state.winner]
	var box := _modal("result", title, 342)
	var description: String = {
		"flag": "The flag held through three opposing turns.",
		"elimination": "The opposing side lost its final pawn.",
		"mutual_elimination": "Both sides lost their final pawns.",
		"round_cap": "Eight rounds elapsed without a winner."
	}.get(state.reason, "")
	_label(box, Rect2(31, 92, 620, 58), description, 21, MUTED, SANS, true)
	_label(box, Rect2(31, 158, 620, 26), "ROUND %02d   /   SEED %d" % [state.round, state.seed], 14, GOLD, MONO)
	_button(box, Rect2(31, 208, 620, 46), "Rematch", func(): _start(local_mode, true), true)
	_button(box, Rect2(31, 266, 302, 41), "View board", func(): _close_overlay(false))
	_button(box, Rect2(348, 266, 303, 41), "Copy replay data", _copy_replay)


func _rich(parent: Node, rect: Rect2, value: String) -> void:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.text = value
	rich.add_theme_font_override("normal_font", SANS)
	rich.add_theme_font_size_override("normal_font_size", 18)
	rich.add_theme_color_override("default_color", INK)
	rich.meta_clicked.connect(func(url): OS.shell_open(str(url)))
	_place(parent, rich, rect)


func _close_overlay(resume: bool = true) -> void:
	_clear(overlay)
	overlay_kind = ""
	if state.is_empty():
		_show_home()
	elif handoff:
		_show_handoff()
	elif resume:
		_enter_turn()
	elif state.phase == "finished":
		_button(side_panel, Rect2(865, 589, 391, 36), "Match result / rematch", _show_result, true)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if overlay_kind not in ["", "home", "handoff"]:
			_close_overlay(overlay_kind != "result")
		elif overlay_kind == "" and selected >= 0:
			_clear_selection()
			_refresh()
		return
	if overlay_kind != "" or state.is_empty():
		return
	var direction: Vector2i = {
		KEY_LEFT: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT,
		KEY_UP: Vector2i.UP, KEY_DOWN: Vector2i.DOWN,
	}.get(event.keycode, Vector2i.ZERO)
	if direction != Vector2i.ZERO:
		var cursor: Vector2i = board.keyboard_square
		if cursor == Vector2i.ZERO:
			cursor = state.pawns[selected].pos if selected in state.pawns else state.flag
		board.keyboard_square = (cursor + direction).clamp(Vector2i.ONE, Vector2i.ONE * Rules.BOARD_SIZE)
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and board.keyboard_square != Vector2i.ZERO:
		_square_pressed(board.keyboard_square)
		get_viewport().set_input_as_handled()
