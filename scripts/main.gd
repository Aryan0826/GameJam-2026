extends Control

const Rules = preload("res://scripts/rules.gd")
const Bot = preload("res://scripts/bot.gd")
const Drift = preload("res://scripts/drift.gd")
const DriftBot = preload("res://scripts/drift_bot.gd")
const Arena = preload("res://scripts/board.gd")
const Cockpit = preload("res://scripts/cockpit.gd")
const ExpeditionState = preload("res://scripts/expedition.gd")
const SANS = preload("res://art/SpaceGrotesk.ttf")
const MONO = preload("res://art/IBMPlexMono-Regular.ttf")

const INK = Color("#f3f5ff")
const MUTED = Color("#aab8d1")
const GOLD = Color("#f8d587")
const LILAC = Color("#b99dfd")
const NORTH = Color("#ff937e")
const SOUTH = Color("#83e1fa")
const PANEL = Color("#111e29")
const LINE = Color("#3d5b68")
const ALIEN_GREEN = Color("#9cff83")
const ALIEN_DIM = Color("#75ad83")
const ALIEN_PANEL = Color("#0c1c15")
const ALIEN_LINE = Color("#3b7950")
const SIDES = ["Aliens", "Pilots"]
const SPELLS = {
	"shield": ["Shield", "Absorb one capture outside the beacon."],
	"fracture": ["Fracture Tile", "Mark a tile to fall after the next turn, along with any unit on it."],
	"teleport": ["Teleport", "Jump to any open tile outside the beacon."],
	"borrow_tomorrow": ["Borrow Tomorrow", "Move this unit, then a different ally. The first unit owes a return."],
	"infected_trail": ["Infected Trail", "Infect the 3 × 3 area around a selected unit through the enemy turn."],
	"spy": ["Spy", "Take control of a nearby enemy unit for your next three turns. It cannot score the beacon."],
	"long_capture": ["Long Capture", "Capture diagonally in any direction, from one or two squares away."],
}
const DRAFT_SPELLS = Rules.SPELLS
const IMAGE_CREDIT = "NASA, ESA, the Hubble Heritage Team (STScI/AURA), A. Nota (ESA/STScI), and the Westerlund 2 Science Team"
const IMAGE_URL = "https://esahubble.org/images/heic1509a/"
const RULES_TEXT = """[color=#f8d587]WIN THE DUEL[/color]
Hold the center beacon through three enemy turns with the same unit, or remove every enemy unit. The match draws after round 8 if neither side wins.

[color=#f8d587]TAKE YOUR TURN[/color]
Roll first. Then choose one path: Move → Use power; Move → Finish turn; or Use power → Finish turn. A drafted ability counts as your move. Finish / skip turn is available at any time.

Move one tile orthogonally or one or two diagonally in any direction. A two-tile diagonal can jump a unit or hole. Regular captures are one tile diagonally forward: down for Aliens and up for Pilots. Enter the beacon from an adjacent square or by making a capture.

[color=#f8d587]WATCH THE RIM[/color]
Cracks are safe until the round ends. Opposite pairs fall in rounds 2 and 4. Each remaining rim falls in rounds 3 and 5. Any unit on a falling tile is removed.

[color=#f8d587]DRAFT ONE-USE ABILITIES[/color]
Shield absorbs one capture and disappears on beacon entry. Teleport jumps to any empty, intact, uninfected tile outside the beacon. Fracture marks any intact tile outside the beacon to drop after the next turn, removing its occupant.

Borrow Tomorrow moves its assigned unit one orthogonal step, then moves another ally one orthogonal step. The first unit cannot enter or leave the beacon. At the end of your next turn it returns to its echo, or is removed if that tile is blocked, infected or gone.

[color=#f8d587]ROLL FOR AN ABILITY[/color]
Roll once per round before moving or using a drafted ability. After rolling, the die panel shows your special power. To move, select a unit → Move / capture → select a highlighted destination. To use power, click Use power → click a highlighted target. For Infected Trail, the target is one of your units; for Spy or Long Capture, it is an enemy.

Infected Trail blocks entry into the 3 × 3 area around a selected unit through the enemy turn, except the beacon. Spy takes control of an enemy within two orthogonal steps of any ally. It returns after three of your subsequent turns. It may stand on the beacon but cannot score or capture there while stolen. Long Capture lets one of your units take an enemy one or two tiles diagonally in any direction.

[color=#f8d587]CONTROLS[/color]
Click a unit, choose an action, then click its target. Click and drag on the board to rotate and tilt the camera. Arrow keys move the board cursor and Enter selects. Esc clears a selection or closes help. In solo, Take Over Aliens switches to local play on the next alien turn boundary."""

const DRIFT_RULES_TEXT = """[color=#f8d587]RACE TO FIVE[/color]
After both players act, the marked rows shift. Each fixed gold relay occupied after the shift earns one point for its occupant’s side. Reach five points with a lead to win. A tie at five or more goes to another round. If no side wins by the end of round %d, the match draws.

[color=#f8d587]PLAN YOUR LANDING[/color]
Row 4 shifts right and row 6 shifts left. Units at the edge wrap around to the other side. For a relay at E4, aim for D4 so the shift carries you onto it. Hover over a highlighted move on a drift row to preview the landing. A unit on the steady relay can score again if it stays there.

[color=#f8d587]TAKE ONE ACTION[/color]
Move one tile orthogonally or one or two diagonally to an empty square. A two-tile diagonal can jump over a unit. Capture one tile diagonally forward (Aliens down, Pilots up) to disrupt a rival’s setup.

[color=#f8d587]CONTROLS[/color]
Click a unit, then a highlighted destination. Arrow keys move the board cursor and Enter selects. Esc clears a selection or closes help. Rematches swap the opening side and alternate the Center and Split relay layouts."""

@export var drift_circuit := false
@onready var expedition: ExpeditionState = get_node("/root/Expedition")

var state: Dictionary = {}
var legal: Array[Dictionary] = []
var records: Array[Dictionary] = []
var messages: Array[String] = []
var board: Control
var cockpit: Control
var chrome: Control
var side_panel: Control
var overlay: Control
var round_label: Label
var status_label: Label
var mode_button: Button
var takeover_button: Button
var motion_button: Button
var feedback: Label
var signal_text: Label
var beacon_label: Label
var beacon_lamps: Array[Panel] = []
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
var assignments: Dictionary = {}
var overlay_kind := ""
var first_flag_round := 0
var started_at := 0
var finished_at := 0
var bold: FontVariation
var _communication_tween: Tween
var _terminal_screen: RichTextLabel
var _terminal_messages: Array[Dictionary] = []
var _terminal_active_line := 0
var _terminal_characters := 0.0
var _terminal_blink_time := 0.0
var _encounter_options: Control
var _telemetry_credit_label: Label
var _communication_accept: Button
var _communication_local: Button
var _communication_prompt: Label
var _communication_ready := false
var _communication_presented := false
var _leaving_orbit := false


func _ready() -> void:
	if not drift_circuit:
		expedition.enter_system(0)
	elif expedition.current_system == 0:
		expedition.enter_system(ExpeditionState.CINDER)
	bold = FontVariation.new()
	bold.base_font = SANS
	bold.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): 700 }
	_build_frame()
	_show_home()


func _build_frame() -> void:
	cockpit = Cockpit.new()
	cockpit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cockpit)
	chrome = _layer(self)
	_panel(chrome, Rect2(42, 231, 775, 565), Color("#364451"), Color("#657782"), 12)
	_panel(chrome, Rect2(51, 239, 757, 549), Color("#142530"), Color("#588590"), 8)
	_panel(chrome, Rect2(58, 247, 743, 533), Color("#091924"), Color("#237285"), 4)
	_label(chrome, Rect2(71, 253, 305, 23), "TACTICAL PROJECTION", 13, SOUTH, MONO)
	status_label = _label(chrome, Rect2(363, 253, 420, 23), "", 13, GOLD, MONO)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	board = Arena.new()
	_place(chrome, board, Rect2(66, 261, 727, 519))
	board.square_pressed.connect(_square_pressed)
	board.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey:
			_unhandled_key_input(event))
	_label(chrome, Rect2(66, 42, 490, 46), "Drift Circuit" if drift_circuit else "Conqueror’s Chess", 36, INK, bold)
	round_label = _label(chrome, Rect2(69, 91, 440, 23), "", 14, SOUTH, MONO)
	_panel(chrome, Rect2(66, 124, 482, 87), Color(0.035, 0.068, 0.11, 0.95), LINE, 5)
	var head := Cockpit.new()
	head.envoy = true
	head.motion = false
	_place(chrome, head, Rect2(75, 133, 78, 68))
	_label(chrome, Rect2(163, 130, 370, 18), "ALIEN ENVOY  /  LIVE", 11, GOLD, MONO)
	signal_text = _label(chrome, Rect2(163, 151, 367, 45), "", 16, INK, SANS, true)
	beacon_label = _label(chrome, Rect2(850, 208, 111, 17), "BEACON HOLD", 12, GOLD, MONO)
	for i in Rules.FLAG_REPLIES:
		beacon_lamps.append(_panel(chrome, Rect2(965 + 25 * i, 212, 18, 8), Color("#26313b"), LINE, 1))
	_button(chrome, Rect2(1130, 198, 144, 31), "System map", _show_map)
	_button(chrome, Rect2(1130, 159, 144, 31), "Leave orbit", _leave_current_orbit)
	beacon_label.visible = not drift_circuit
	for lamp in beacon_lamps:
		lamp.visible = not drift_circuit
	mode_button = _button(chrome, Rect2(680, 811, 95, 31), "Solo", _show_modes)
	takeover_button = _button(chrome, Rect2(783, 811, 150, 31), "Take Over Aliens", _takeover)
	_button(chrome, Rect2(941, 811, 77, 31), "Rules", _show_rules)
	motion_button = _button(chrome, Rect2(1026, 811, 76, 31), "FX on", _toggle_motion)
	feedback = _label(chrome, Rect2(72, 812, 590, 26), "", 14, GOLD)
	side_panel = _layer(chrome)
	side_panel.position.y = 106
	side_panel.scale.y = 0.86
	_telemetry_credit_label = _label(self, Rect2(48, 831, 590, 16), "SHIP GRAPHS: GODOT PRIMITIVES / IBM PLEX MONO", 10, MUTED)
	feedback.position.y = 808
	feedback.size.y = 19
	_button(self, Rect2(1146, 811, 128, 31), "Asset credits", _show_credits)
	_encounter_options = _layer(self)
	_label(_encounter_options, Rect2(48, 815, 480, 22), "HORIZON / COMMUNICATION TERMINAL", 12, Color("#7ab594"), MONO)
	_communication_local = _button(_encounter_options, Rect2(542, 811, 132, 31), "Local duel", _accept_challenge.bind(true))
	_button(_encounter_options, Rect2(684, 811, 132, 31), "How to play", _show_rules)
	_button(_encounter_options, Rect2(826, 811, 132, 31), "System map", _show_map)
	_button(_encounter_options, Rect2(968, 811, 168, 31), "Replay prologue", _show_story)
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
	if layer == overlay:
		_stop_communication()
		if _encounter_options != null:
			_encounter_options.hide()
	for child in layer.get_children():
		layer.remove_child(child)
		child.queue_free()


func _show_home() -> void:
	chrome.hide()
	cockpit.mode = "terminal"
	cockpit.clearance = ""
	_clear(overlay)
	overlay_kind = "home"
	_encounter_options.show()
	_telemetry_credit_label.hide()
	var system_data: Dictionary = expedition.current_system_data()
	var planet_name := str(system_data.planet_name).capitalize()
	var game_name := "Drift Circuit" if drift_circuit else "Conqueror’s Chess"
	_label(overlay, Rect2(128, 58, 720, 24), "HORIZON // SHIP COMMUNICATIONS", 14, Color("#8effb2"), MONO)
	var orbit_status := _label(overlay, Rect2(848, 58, 344, 24), "ORBIT / %s" % system_data.planet_name, 13, Color("#75ad83"), MONO)
	orbit_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(overlay, Rect2(128, 90, 1064, 28), "%s / INCOMING TRANSMISSION" % game_name.to_upper(), 19, Color("#a6efc2"), MONO)
	_terminal_screen = RichTextLabel.new()
	_terminal_screen.bbcode_enabled = true
	_terminal_screen.scroll_active = false
	_terminal_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terminal_screen.add_theme_font_override("normal_font", MONO)
	_terminal_screen.add_theme_font_size_override("normal_font_size", 18)
	_terminal_screen.add_theme_color_override("default_color", Color("#b3f4c7"))
	_terminal_screen.add_theme_constant_override("line_separation", 2)
	_place(overlay, _terminal_screen, Rect2(128, 142, 1064, 312))
	_terminal_messages = [
		{"speaker": "ALIEN ENVOY", "color": "#a0edb4", "text": "Horizon, you have entered %s's orbit. Why have you come here?" % planet_name},
		{"speaker": "HORIZON / VALERIA", "color": "#a6dfff", "text": "We are looking for friends away from home. We come in peace."},
		{"speaker": "ALIEN ENVOY", "color": "#a0edb4", "text": "Then face us in %s. Win, and we will welcome you as friends. Lose, and you must leave our orbit in peace." % game_name},
	]
	_terminal_active_line = 0
	_terminal_characters = 0.0
	_terminal_blink_time = 0.0
	_communication_prompt = _label(overlay, Rect2(128, 467, 1064, 22), "", 14, Color("#75ad83"), MONO)
	_communication_accept = _terminal_action(Rect2(128, 506, 512, 32), "[ENTER] REVEAL TRANSMISSION", _advance_communication)
	_terminal_action(Rect2(680, 506, 512, 32), "[Q] LEAVE ORBIT", _leave_planet_orbit)
	_label(overlay, Rect2(128, 554, 1064, 18), "HORIZON / ORBIT LINK OPEN", 11, Color("#518368"), MONO)
	_communication_accept.disabled = false
	_communication_local.disabled = true
	if _communication_presented:
		_finish_communication()
	else:
		_communication_presented = true
		_communication_tween = create_tween()
		_communication_tween.tween_interval(0.2)
		for i in _terminal_messages.size():
			var message: String = _terminal_messages[i].text
			_communication_tween.tween_callback(_begin_terminal_message.bind(i))
			_communication_tween.tween_property(self, "_terminal_characters", float(message.length()), clampf(message.length() / 50.0, 0.75, 3.2)).from(0.0)
			_communication_tween.tween_interval(0.25)
		_communication_tween.tween_callback(_finish_communication)
	_render_terminal()


func _terminal_action(rect: Rect2, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", MONO)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("#8effb2"))
	button.add_theme_color_override("font_hover_color", Color("#e1ffeb"))
	button.add_theme_color_override("font_disabled_color", Color("#3d6a50"))
	for style_name in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	_place(overlay, button, rect)
	button.pressed.connect(callback)
	return button


func _begin_terminal_message(index: int) -> void:
	_terminal_active_line = index
	_terminal_characters = 0.0


func _process(delta: float) -> void:
	if overlay_kind == "home":
		_terminal_blink_time = fposmod(_terminal_blink_time + delta, 1.0)
		_render_terminal()


func _render_terminal() -> void:
	var cursor := "_" if _terminal_blink_time < 0.55 else " "
	var transcript := ""
	for i in _terminal_messages.size():
		if not _communication_ready and i > _terminal_active_line:
			break
		var message: Dictionary = _terminal_messages[i]
		var full_text: String = message.text
		var visible_text := full_text
		if not _communication_ready and i == _terminal_active_line:
			visible_text = full_text.substr(0, int(_terminal_characters)) + cursor
		transcript += "[color=%s]%s >\n%s[/color]\n\n" % [message.color, message.speaker, visible_text]
	if _communication_ready:
		transcript += "[color=#8effb2]AWAITING COMMAND > %s[/color]" % cursor
	if _terminal_screen.text != transcript:
		_terminal_screen.text = transcript


func _stop_communication() -> void:
	if _communication_tween != null:
		_communication_tween.kill()
		_communication_tween = null
	_communication_ready = false


func _finish_communication() -> void:
	if overlay_kind != "home":
		return
	_stop_communication()
	_communication_ready = true
	_communication_accept.text = "[ENTER] ACCEPT CHALLENGE"
	_communication_accept.disabled = false
	_communication_local.disabled = false
	_communication_prompt.text = ""
	_render_terminal()


func _accept_challenge(local: bool = false) -> void:
	if overlay_kind != "home" or not _communication_ready or busy:
		return
	_start(local)


func _leave_planet_orbit() -> void:
	if overlay_kind != "home" or busy:
		return
	_leave_current_orbit()


func _advance_communication() -> void:
	if overlay_kind != "home" or busy:
		return
	if _communication_ready:
		_accept_challenge()
	else:
		_finish_communication()


func _input(event: InputEvent) -> void:
	if overlay_kind != "home" or busy or not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_Q:
		get_viewport().set_input_as_handled()
		_leave_planet_orbit()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_advance_communication()


func _show_story() -> void:
	expedition.reset_journey()
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
	if drift_circuit:
		var layout := Drift.CENTER if not rematch else 1 - int(state.drift.layout)
		var focus := randi_range(0, 2) if not rematch else (int(state.drift.focus) + randi_range(1, 2)) % 3
		state = Rules.create_drift_match(seed_value, first, layout, focus)
	else:
		state = Rules.create_match(seed_value, first)
	records.clear()
	messages.clear()
	assignments.clear()
	first_flag_round = 0
	started_at = Time.get_ticks_msec() if drift_circuit else 0
	finished_at = 0
	feedback.text = ""
	cockpit.mode = "trial"
	_telemetry_credit_label.show()
	cockpit.clearance = ""
	cockpit.alert = 0.0
	board.reset_visuals()
	board.power_on()
	board.keyboard_square = Vector2i.ZERO
	_clear_selection()
	_close_overlay(false)
	chrome.show()
	if local_mode and state.phase == "draft":
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
	elif drift_circuit and legal.size() == 1 and legal[0].kind == "pass":
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
	var choice := action
	if choice.is_empty():
		choice = DriftBot.choose(state, legal) if drift_circuit else Bot.choose(state, legal)
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
		if event.kind == "collapse":
			cockpit.alert = 0.7
		if first_flag_round == 0 and event.kind == "flag" and event.get("pawn", -1) >= 0:
			first_flag_round = played_round
		if event.kind not in ["turn", "draft_lock", "drift_move"]:
			messages.push_front(event.text.replace("Pawns", "Units").replace("pawns", "units").replace("Pawn", "Unit").replace("pawn", "unit").replace("flag", "beacon"))
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
	cockpit.motion = motion
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
	_update_transmission()
	var draft: bool = state.phase == "draft"
	var turn_text: String = "DUEL COMPLETE" if state.phase == "finished" else SIDES[state.active].to_upper() + " TO ACT"
	round_label.text = "PRIVATE DRAFT" if draft else "ROUND %02d / %02d     ·     %s" % [state.round, Drift.ROUND_LIMIT if drift_circuit else 8, turn_text]
	if drift_circuit:
		var coords := PackedStringArray()
		for relay: Vector2i in state.drift.relays:
			coords.append(_coord(relay))
		status_label.text = "RELAYS   " + "  /  ".join(coords)
	else:
		var flag_status := "%d/%d HELD" % [state.replies, Rules.FLAG_REPLIES] if state.holder >= 0 else "UNCLAIMED"
		if state.holder < 0 and _pawn_at(state.flag) >= 0:
			flag_status = "STOLEN UNIT  /  NO SCORE"
		status_label.text = "BEACON  %s     /     %s" % [_coord(state.flag), flag_status]
	mode_button.text = "Local" if local_mode else "Solo"
	takeover_button.disabled = draft or local_mode or takeover_queued or state.phase != "playing"
	takeover_button.text = "Takeover queued" if takeover_queued else "Take Over Aliens"
	_clear(side_panel)
	if draft:
		_draw_draft()
	elif drift_circuit:
		_draw_drift_play()
	else:
		_draw_play()


func _update_transmission() -> void:
	if drift_circuit:
		signal_text.text = "The relay race has ended." if state.phase == "finished" else "Watch the marked lanes. Each relay scores after the shift."
		return
	var line := "Configure your units. The trial begins when both sides lock their choices."
	var lamp_color := SOUTH
	if state.holder >= 0 and state.pawns[state.holder].side == 0:
		lamp_color = NORTH
	if state.phase == "playing":
		line = "The beacon is open. Hold it through three opposing turns."
		if not state.cracks.is_empty() or not state.fractures.is_empty():
			line = "The arena is breaking. Watch the cracked platforms."
		if state.holder >= 0:
			line = "We see your signal, Horizon. Keep it alive." if lamp_color == SOUTH else "Our beacon is locked. Show us how you break a hold."
			if state.replies == 2:
				line = "One more reply. The fleet is watching." if lamp_color == SOUTH else "One more reply and the trial is ours."
	elif state.phase == "finished":
		line = "Landing permission granted, ally." if state.winner == 1 else "The trial has ended. Await instructions."
	signal_text.text = line
	for i in beacon_lamps.size():
		beacon_lamps[i].add_theme_stylebox_override("panel", _style(lamp_color if state.holder >= 0 and i < state.replies else Color("#26313b"), LINE, 1))


func _draw_draft() -> void:
	var color := NORTH if state.active == 0 else SOUTH
	_panel(side_panel, Rect2(846, 148, 430, 651))
	_label(side_panel, Rect2(868, 166, 380, 28), "%s  /  PRIVATE DRAFT" % SIDES[state.active].to_upper(), 14, color, MONO)
	_label(side_panel, Rect2(868, 200, 380, 46), "Configure landing team", 30, INK, bold)
	_label(side_panel, Rect2(869, 254, 376, 53), "Select a unit on the grid, then an ability. Assign a different ability to a second unit.", 17, MUTED, SANS, true)
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
	var caption := "Click an interceptor to begin." if state.active == 0 else "Click a survey rover to begin."
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
		drops = "Roll before moving. Skip turn is always available."
	_label(side_panel, Rect2(864, 310, 390, 25), drops, 14, GOLD if not state.cracks.is_empty() or not state.fractures.is_empty() else MUTED)
	_panel(side_panel, Rect2(846, 359, 430, 225))
	_label(side_panel, Rect2(864, 369, 396, 25), "TURN CHOICES", 12, MUTED, MONO)
	_label(side_panel, Rect2(864, 396, 394, 55), _action_hint(), 15, INK, SANS, true)
	if selected >= 0 and selected in state.pawns:
		var p: Dictionary = state.pawns[selected]
		_action_button(Rect2(864, 462, 189, 38), "Move / capture", "standard")
		if p.ability != "":
			_action_button(Rect2(864, 507, 189, 36), SPELLS[p.ability][0], "ability")
		var details := Rules.ability_reason(state, p) if p.ability != "" else ""
		if not p.borrow.is_empty():
			details = "Returns to %s at the end of this turn." % _coord(p.borrow.origin)
		elif p.spy > 0:
			details = "Stolen unit · %d turns left. Cannot score or capture at the beacon." % p.spy
		elif details.is_empty() and action_group == "ability":
			details = SPELLS[p.ability][1]
		elif details.is_empty() and action_group == "power" and not face.is_empty():
			details = SPELLS[face][1]
		if not details.is_empty():
			_label(side_panel, Rect2(864, 546, 394, 35), details, 13, MUTED, SANS, true)
	else:
		_label(side_panel, Rect2(864, 510, 394, 70), "For a move, select a unit first. For power, click Use power, then choose a highlighted target.", 15, MUTED, SANS, true)
	if not face.is_empty():
		_action_button(Rect2(1062, 462, 196, 38), "Use power", "power")
	_draw_flight_log()
	var skip := _button(side_panel, Rect2(846, 744, 430, 42), "Finish / skip turn", _skip_turn)
	skip.disabled = busy or state.phase != "playing" or (not local_mode and state.active == 0)


func _draw_drift_play() -> void:
	_team_card(846, 148, 0)
	_team_card(1067, 148, 1)
	_panel(side_panel, Rect2(846, 238, 430, 108))
	_label(side_panel, Rect2(864, 249, 230, 22), "RELAY LAYOUT", 12, LILAC, MONO)
	_label(side_panel, Rect2(864, 273, 390, 32), Drift.LAYOUT_NAMES[state.drift.layout], 23, INK, bold)
	_label(side_panel, Rect2(864, 310, 390, 25), "ROW 4 →   /   ROW 6 ←   AFTER BOTH TURNS", 13, LILAC, MONO)
	_panel(side_panel, Rect2(846, 359, 430, 225))
	_label(side_panel, Rect2(864, 371, 394, 37), "Reach five points with the lead.", 21, GOLD, bold)
	_label(side_panel, Rect2(864, 419, 394, 56), _action_hint(), 16, INK, SANS, true)
	_label(side_panel, Rect2(864, 488, 390, 70), "Each occupied gold relay scores after the shift. Point at a highlighted drift move to preview its landing.", 16, MUTED, SANS, true)
	_draw_flight_log()


func _draw_flight_log() -> void:
	_panel(side_panel, Rect2(846, 592, 430, 140), ALIEN_PANEL, ALIEN_LINE, 12)
	_label(side_panel, Rect2(864, 600, 270, 22), "ALIEN FLIGHT LOG", 12, ALIEN_GREEN, MONO)
	var log_button := _button(side_panel, Rect2(1162, 598, 97, 27), "View log", _show_log)
	log_button.add_theme_stylebox_override("normal", _style(Color("#14281a"), ALIEN_LINE, 8))
	log_button.add_theme_stylebox_override("hover", _style(Color("#1e3925"), ALIEN_GREEN, 8))
	log_button.add_theme_stylebox_override("pressed", _style(Color("#284b30"), ALIEN_GREEN, 8))
	log_button.add_theme_color_override("font_color", ALIEN_GREEN)
	log_button.add_theme_color_override("font_hover_color", Color("#d0ffc4"))
	var latest := messages.slice(0, 3)
	for i in range(latest.size()):
		var line := _label(side_panel, Rect2(864, 630 + i * 25, 389, 24), latest[i], 13, ALIEN_GREEN if i == 0 else ALIEN_DIM, MONO)
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
	var summary := "%d PTS  /  %d UNITS" % [state.drift.scores[side], count] if drift_circuit else "%d UNITS IN PLAY" % count
	_label(side_panel, Rect2(x + 16, y + 42, 179, 24), summary, 13, MUTED, MONO)


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


func _skip_turn() -> void:
	if busy or {"kind": "skip"} not in legal or (not local_mode and state.active == 0):
		return
	_commit({"kind": "skip"})


func _action_hint() -> String:
	if state.phase == "finished":
		return "Duel complete."
	if busy:
		if not local_mode and state.active == 0:
			return "Aliens are taking their turn."
		return "Resolving the turn."
	if drift_circuit:
		return "Select a highlighted move or capture." if selected >= 0 else "Select one of your units to see its legal moves."
	if state.dice[state.active].is_empty():
		return "Step 1: Roll the die. Or finish / skip to pass without acting."
	if state.turn_power_used:
		return "Move + power complete. Finish your turn." if state.turn_move else "Power-only path complete. Finish your turn."
	if action_group == "power":
		if _group_actions("power").is_empty():
			return "No legal target for this power. Choose Move / capture, or finish / skip."
		match state.dice[state.active]:
			"infected_trail":
				return "Click the highlighted unit to infect its surrounding tiles."
			"spy":
				return "Click a highlighted enemy to use Spy, then finish your turn."
			"long_capture":
				return "Click a highlighted enemy to use Long Capture."
	if state.turn_move:
		if _group_actions("power").is_empty():
			return "No legal target for this power. Finish now for Move only."
		return "Move complete. Use power for Move + power, or finish now for Move only."
	if selected < 0:
		if _group_actions("power").is_empty():
			return "No legal target for this power. Choose Move / capture, or finish / skip."
		return "Choose: Move → Power, Move → Finish (move only), or Power → Finish (power only)."
	var p: Dictionary = state.pawns[selected]
	if not p.borrow.is_empty():
		return "This unit is waiting to return to its echo."
	if action_group == "ability" and p.ability == "borrow_tomorrow":
		if first_destination == Vector2i.ZERO:
			return "Choose where the borrowed unit steps."
		if second_pawn < 0:
			return "Choose the second unit."
		return "Choose where the second unit steps to commit both moves."
	if action_group == "ability" and p.ability == "shield":
		return "Select the highlighted unit again to raise its shield."
	if action_group == "ability" and p.ability == "fracture":
		return "Select a tile to drop after the next turn."
	if _group_actions(action_group).is_empty():
		return "This unit has no legal target for the selected action."
	if action_group == "standard":
		return "Choose a highlighted destination. Finish after moving for Move only, or use power for both."
	return "Select a highlighted destination for %s." % _coord(p.pos)


func _action_button(rect: Rect2, title: String, group: String) -> void:
	var control := _button(side_panel, rect, title, _set_group.bind(group), action_group == group)
	control.disabled = busy or _group_actions(group).is_empty()


func _set_group(group: String) -> void:
	action_group = group
	first_destination = Vector2i.ZERO
	second_pawn = -1
	board.grab_focus()
	_refresh()


func _group_actions(group: String) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if group == "power":
		for action in legal:
			if action.kind != state.dice[state.active]:
				continue
			choices.append(action)
		return choices
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
	return choices


func _targets() -> Dictionary:
	var highlighted := {}
	if busy or state.phase != "playing":
		return highlighted
	if selected < 0 and action_group != "power":
		return highlighted
	for action in _group_actions(action_group):
		if action.kind == "spy":
			highlighted[state.pawns[action.mark].pos] = "mark"
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
		if _select_target(action, square, id):
			return
	if id >= 0 and state.pawns[id].side == state.active:
		_clear_selection()
		selected = id
		if _group_actions("standard").is_empty():
			for group: String in ["ability", "power"]:
				if not _group_actions(group).is_empty():
					action_group = group
					break
		_refresh()


func _select_target(action: Dictionary, square: Vector2i, id: int) -> bool:
	if action.kind == "spy":
		if state.pawns[action.mark].pos == square:
			_commit(action)
			return true
		return false
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
			_note("Select an assigned unit to change its ability.")
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
	var box := _modal("handoff", "Pass to the %s player" % SIDES[state.active], 319)
	_label(box, Rect2(31, 98, 610, 57), "Your draft is private until both players lock their choices.", 21, MUTED, SANS, true)
	_button(box, Rect2(31, 186, 620, 45), "Ready to draft", func():
		handoff = false
		chrome.show()
		_close_overlay(), true)
	_button(box, Rect2(31, 247, 620, 41), "Leave orbit", _leave_current_orbit)


func _show_rules() -> void:
	var box := _modal("rules", "Drift Circuit rules" if drift_circuit else "How to play", 702)
	_rich(box, Rect2(31, 94, 621, 516), DRIFT_RULES_TEXT % Drift.ROUND_LIMIT if drift_circuit else RULES_TEXT)
	_button(box, Rect2(31, 634, 620, 41), "Back", _close_overlay)


func _show_credits() -> void:
	var box := _modal("credits", "Asset credits", 495)
	var graph_credits := "[color=#f8d587]SHIP TELEMETRY GRAPHS[/color]\nReactor output, thermal load, and reserve gauges are drawn with Godot primitives in scripts/cockpit.gd. No imported graph images. Labels use IBM Plex Mono (SIL OFL 1.1).\n\n"
	_rich(box, Rect2(31, 92, 620, 317), graph_credits + "[color=#f8d587]COCKPIT AND SYSTEM[/color]\n[url=https://kenney.nl/assets/space-kit]Space Kit · Kenney · CC0[/url]\n[url=https://opengameart.org/content/spaceship-interior-0]Spaceship Interior · cheerful sprite · CC0[/url]\n[url=https://screamingbrainstudios.itch.io/tiny-planet-pack]Tiny Planet Pack · Screaming Brain Studios · CC0[/url]\n\n[color=#f8d587]WESTERLUND 2[/color]\n[url=" + IMAGE_URL + "]" + IMAGE_CREDIT + "[/url]\nHubble observation. CC BY 4.0. Cropped and tinted.\n\n[color=#f8d587]TYPE[/color]\n[url=https://github.com/floriankarsten/space-grotesk]Space Grotesk · Florian Karsten[/url]\n[url=https://github.com/IBM/plex]IBM Plex Mono · IBM Corp.[/url]\nBoth SIL Open Font License 1.1.")
	_button(box, Rect2(31, 427, 620, 41), "Back", _close_overlay)


func _show_map() -> void:
	var box := _modal("map", "%s chart" % expedition.current_system_data().name, 438)
	var chart := Cockpit.new()
	chart.map_only = true
	chart.motion = false
	_place(box, chart, Rect2(27, 79, 620, 250))
	_label(box, Rect2(31, 317, 620, 25), "Horizon holding position above the arena. Orbital chart is schematic.", 15, MUTED)
	_button(box, Rect2(31, 365, 620, 41), "Back to cockpit", _close_overlay)


func _leave_current_orbit() -> void:
	if _leaving_orbit:
		return
	_leaving_orbit = true
	if expedition.leave_orbit() == OK:
		generation += 1
		busy = true
		_stop_communication()
	else:
		_leaving_orbit = false
		if overlay_kind == "home":
			_communication_prompt.text = "Unable to return to flight. Please try again."
		else:
			_note("Could not leave the current planet's orbit.")


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


func _replay_action(record: Dictionary) -> Dictionary:
	var action := record.duplicate()
	for key in ["to", "second_to"]:
		if key in action:
			var point: Vector2i = action[key]
			action[key] = [point.x, point.y]
	for key in ["move", "power"]:
		if key in action:
			action[key] = _replay_action(action[key])
	return action


func _copy_replay() -> void:
	var actions: Array[Dictionary] = []
	for record in records:
		actions.append(_replay_action(record))
	var end := finished_at if finished_at > 0 else Time.get_ticks_msec()
	var replay := {
		"rules_version": 4, "seed": state.seed, "first": state.first, "actions": actions,
		"first_flag_round": first_flag_round, "result": state.reason, "winner": state.winner,
		"elapsed_ms": end - started_at if started_at > 0 else 0,
	}
	if drift_circuit:
		replay["mode"] = "drift"
		replay["layout"] = state.drift.layout
		replay["bot_focus"] = state.drift.focus
	DisplayServer.clipboard_set(JSON.stringify(replay))
	_note("Replay copied.")
	_close_overlay()


func _show_result() -> void:
	if state.is_empty() or state.phase != "finished":
		return
	expedition.record_battle(int(state.winner))
	var next_available := expedition.has_next_system()
	var title := "Trial unresolved"
	var outcome := "The trial ends in a draw. You may try again or return to exploration."
	cockpit.clearance = ""
	match state.winner:
		1:
			title = "Alliance secured"
			outcome = "The people of %s welcome the Horizon as friends. A landing corridor is open." % str(expedition.current_system_data().planet_name).capitalize()
			cockpit.clearance = "land"
		0:
			title = "Challenge lost"
			outcome = "The envoy asks the Horizon to leave orbit in peace. You can explore another planet or try again."
	if drift_circuit:
		title = "Circuit drawn" if state.winner < 0 else "%s win the circuit" % SIDES[state.winner]
	_clear(overlay)
	overlay_kind = "result"
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.032, 0.07, 0.84)
	_place(overlay, dim, Rect2(0, 237, 1320, 570))
	var box := _panel(overlay, Rect2(319, 262 if next_available else 292, 682, 491 if next_available else 432), PANEL, LINE, 12)
	_label(box, Rect2(29, 19, 622, 59), title, 39, INK, bold)
	var description: String = {
		"flag": "The beacon held through three opposing turns.",
		"elimination": "The opposing side lost its final unit.",
		"mutual_elimination": "Both sides lost their final units.",
		"round_cap": "Eight rounds elapsed without a winner.",
		"relays": "The winning score was reached after the final shift.",
		"drift_limit": "Twelve rounds elapsed without a winner."
	}.get(state.reason, "")
	if drift_circuit:
		description = "Aliens %d / Pilots %d. " % state.drift.scores + description
	_label(box, Rect2(31, 86, 620, 62), outcome, 21, INK, SANS, true)
	_label(box, Rect2(31, 146, 620, 53), description, 17, MUTED, SANS, true)
	_label(box, Rect2(31, 209, 620, 25), "ROUND %02d   /   SEED %d" % [state.round, state.seed], 14, GOLD, MONO)
	var rematch_y := 311 if next_available else 252
	var footer_y := rematch_y + 59
	if next_available:
		var travel_title := "%s to %s" % ["Withdraw" if state.winner == 0 else "Travel", expedition.next_system_name()]
		_button(box, Rect2(31, 252, 620, 46), travel_title, _travel_to_next_system, true)
	_button(box, Rect2(31, rematch_y, 620, 46), "Rematch", func(): _start(local_mode, true), not next_available)
	_button(box, Rect2(31, footer_y, 302, 41), "View board", func(): _close_overlay(false))
	_button(box, Rect2(348, footer_y, 303, 41), "Copy replay data", _copy_replay)
	_button(box, Rect2(31, footer_y + 57, 620, 41), "Leave orbit", _leave_current_orbit)


func _travel_to_next_system() -> void:
	if busy or state.is_empty() or state.phase != "finished" or not expedition.has_next_system():
		return
	busy = true
	generation += 1
	var scene_error := expedition.fly_to(ExpeditionState.CINDER, true)
	if scene_error != OK:
		busy = false
		_note("Could not set course for Cinder.")


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
		elif overlay_kind in ["", "handoff"]:
			_leave_current_orbit()
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
			cursor = state.pawns[selected].pos if selected in state.pawns else Vector2i(5, 5)
		board.keyboard_square = (cursor + direction).clamp(Vector2i.ONE, Vector2i.ONE * Rules.BOARD_SIZE)
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and board.keyboard_square != Vector2i.ZERO:
		_square_pressed(board.keyboard_square)
		get_viewport().set_input_as_handled()
