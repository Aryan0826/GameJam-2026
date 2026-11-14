extends Control

const Rules = preload("res://scripts/rules/rules.gd")
const Bot = preload("res://scripts/rules/bot.gd")
const Drift = preload("res://scripts/rules/drift.gd")
const DriftBot = preload("res://scripts/rules/drift_bot.gd")
const Arena = preload("res://scripts/battle/board.gd")
const Cockpit = preload("res://scripts/battle/cockpit.gd")
const AbilityCards = preload("res://scripts/battle/ability_cards.gd")
const AbilityHologram = preload("res://scripts/battle/ability_hologram.gd")
const KalypsoGuide = preload("res://scripts/battle/kalypso_guide.gd")
const Story = preload("res://scripts/core/expedition_story.gd")
const StoryArt = preload("res://scripts/battle/story_art.gd")
const ExpeditionState = preload("res://scripts/core/expedition.gd")
const SANS = preload("res://art/fonts/SpaceGrotesk.ttf")
const MONO = preload("res://art/fonts/IBMPlexMono-Regular.ttf")

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
const SIDES = ["Aliens", "Crew"]
const SPELLS = {
	"shield": ["Shield", "Absorb one capture outside the beacon."],
	"fracture": ["Fracture Tile", "Mark a tile to fall after the next turn, along with any unit on it."],
	"teleport": ["Teleport", "Jump to any open tile outside the beacon."],
	"missile": ["Missile Strike", "Destroy a tile and its enemy. Locked while an enemy is on the flag."],
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
Shuffle first. Then choose one path: Move → Use power; Move → Finish turn; or Use power → Finish turn. A drafted ability counts as your move. Finish / skip turn is available at any time.

Move one tile orthogonally or one or two diagonally in any direction. A two tile diagonal can jump a unit or hole. Regular captures are one tile diagonally forward: down for Aliens and up for Crew. Enter the beacon from an adjacent square or by making a capture.

[color=#f8d587]WATCH THE RIM[/color]
Cracks are safe until the round ends. Opposite pairs fall in rounds 2 and 4. Each remaining rim falls in rounds 3 and 5. Any unit on a falling tile is removed.

[color=#f8d587]DRAFT ONE-USE ABILITIES[/color]
Shield absorbs one capture and disappears on beacon entry. Teleport jumps to any empty, intact, uninfected tile outside the beacon. Fracture marks any intact tile outside the beacon to drop after the next turn, removing its occupant. Missile Strike destroys one empty or enemy tile immediately, including a shielded enemy. It cannot target allies or the beacon, and cannot launch while an enemy occupies the beacon.

[color=#f8d587]SHUFFLE FOR AN ABILITY[/color]
Shuffle once per round before moving or using a drafted ability. The cards shuffle, then flip to reveal your special power. Each of the three powers has an equal chance. To move, select a unit → Move / capture → select a highlighted destination. To use power, click Use power → click a highlighted target. For Infected Trail, the target is one of your units; for Spy or Long Capture, it is an enemy.

Infected Trail blocks entry into the 3 × 3 area around a selected unit through the enemy turn, except the beacon. Spy takes control of an enemy within two orthogonal steps of any ally. It returns after three of your subsequent turns. It may stand on the beacon but cannot score or capture there while stolen. Long Capture lets one of your units take an enemy one or two tiles diagonally in any direction.

[color=#f8d587]CONTROLS[/color]
Click a unit, choose an action, then click its target. Click and drag on the board to rotate and tilt the camera. Arrow keys move the board cursor and Enter selects. Esc clears a selection or closes help. In solo, Multiplayer switches alien control to Player 2; Computer returns control to the AI. Changes take effect on the next alien turn boundary."""

const DRIFT_QUICK_START = """[color=#f8d587]TAKE YOUR TURN[/color]
Move or capture one unit. Turns alternate.

[color=#f8d587]SHIFTING LANES[/color]
After both turns, row 4 shifts right; row 6 shifts left. Row 5 stays put.

[color=#f8d587]SCORE AND WIN[/color]
Occupied relays score +1, then move. Relays + surviving units = your score. Reach the goal to win.

[color=#f8d587]CONTROLS[/color]
Click a unit, then a destination. Drag to rotate; arrows + Enter to select. Esc closes help."""

const DRIFT_MOVEMENT = """[color=#f8d587]MOVE[/color]
Move 1 tile orthogonally or 1 or 2 tiles diagonally. A 2-tile diagonal can jump a unit or hole.

[color=#f8d587]CAPTURE[/color]
Capture an enemy one diagonal step forward (Aliens ↓, Crew ↑).

[color=#83e1fa]LANE SHIFT[/color]
Units on rows 4 and 6 move with the lane."""

const DRIFT_SCORING = """[color=#f8d587]AFTER BOTH SIDES ACT[/color]
Rows 4 and 6 shift. Relays score after the shift.

[color=#f8d587]POINTS[/color]
+1 per occupied relay. Each relay scores once per round, then moves.

[color=#f8d587]WIN OR DRAW[/color]
Reach %d combined relay points and units to win. A tie or no winner by round %d is a draw."""

@export var drift_circuit := false
@onready var soundtrack: Node = get_node("/root/Soundtrack")
@onready var expedition: ExpeditionState = get_node("/root/Expedition")

var state: Dictionary = {}
var legal: Array[Dictionary] = []
var records: Array[Dictionary] = []
var messages: Array[String] = []
var ability_hologram: Control
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
var assignments: Dictionary = {}
var overlay_kind := ""
var first_flag_round := 0
var started_at := 0
var finished_at := 0
var card_reveal: Control
var shuffling := false
var bold: FontVariation
var _communication_tween: Tween
var _terminal_screen: RichTextLabel
var _terminal_messages: Array[Dictionary] = []
var _terminal_active_line := 0
var _terminal_characters := 0.0
var _encounter_options: Control
var _telemetry_credit_label: Label
var _communication_accept: Button
var _communication_local: Button
var _communication_prompt: Label
var _communication_ready := false
var _communication_presented := false
var _leaving_orbit := false
var _communication_departing := false
var _communication_skip: Button
var _contact_art: Control
var _contact_name: Label
var _contact_progress: Label
var _result_story: Array[Dictionary] = []
var _result_line := 0
var _result_recorded_state: Dictionary = {}
var _result_was_allied := false
var _result_quote: Label
var _result_speaker: Label
var _result_portrait: Control
var _result_next: Button


func _ready() -> void:
	soundtrack.music("arena")
	if not drift_circuit:
		expedition.enter_system(0)
	elif expedition.current_system == 0:
		expedition.enter_system(ExpeditionState.CINDER)
	bold = FontVariation.new()
	bold.base_font = SANS
	bold.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): 700 }
	_build_frame()
	_show_home()
	if expedition.take_descent_arrival():
		var arrival := ColorRect.new()
		arrival.name = "DescentArrivalHologram"
		arrival.color = Color(0.015, 0.065, 0.085)
		_place(self, arrival, Rect2(0, 0, 1320, 850))
		var reveal := create_tween()
		reveal.tween_property(arrival, "modulate:a", 0.0, 0.55)
		reveal.tween_callback(arrival.queue_free)


func _build_frame() -> void:
	cockpit = Cockpit.new()
	cockpit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cockpit)
	chrome = _layer(self)
	_panel(chrome, Rect2(42, 231, 775, 565), Color("#364451"), Color("#657782"), 12)
	_panel(chrome, Rect2(51, 239, 757, 549), Color("#142530"), Color("#588590"), 8)
	_panel(chrome, Rect2(58, 247, 743, 533), Color("#091924"), Color("#237285"), 4)
	status_label = _label(chrome, Rect2(363, 253, 420, 23), "", 13, GOLD, MONO)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	board = Arena.new()
	_place(chrome, board, Rect2(66, 261, 727, 519))
	board.square_pressed.connect(_square_pressed)
	board.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey:
			_unhandled_key_input(event))
	_label(chrome, Rect2(66, 42, 490, 46), "Drift Circuit" if drift_circuit else "The Fractured Flag", 36, INK, bold)
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
	takeover_button = _button(chrome, Rect2(783, 811, 150, 31), "Multiplayer", _takeover)
	_button(chrome, Rect2(941, 811, 104, 31), "How to play", _show_rules)
	motion_button = _button(chrome, Rect2(1051, 811, 76, 31), "FX on", _toggle_motion)
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
	card_reveal = AbilityCards.new()
	_place(chrome, card_reveal, Rect2(178, 328, 500, 344))
	card_reveal.hide()
	ability_hologram = AbilityHologram.new()
	_place(chrome, ability_hologram, Rect2(board.position, board.size))
	ability_hologram.action_chosen.connect(_choose_hologram_action)
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
	button.pressed.connect(soundtrack.cue.bind("click"))
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
	_communication_departing = false
	_encounter_options.show()
	_telemetry_credit_label.hide()
	var system_data: Dictionary = expedition.current_system_data()
	var system: int = expedition.current_system
	var game_name := "Drift Circuit" if drift_circuit else "The Fractured Flag"
	_label(overlay, Rect2(128, 58, 720, 24), "HORIZON // SHIP COMMUNICATIONS", 14, Color("#8effb2"), MONO)
	var standing: String = expedition.standing(system)
	var status := standing.to_upper() if standing != "unknown" else "INVITATION OPEN" if expedition.encounters_seen.has(system) else "FIRST CONTACT"
	var orbit_status := _label(overlay, Rect2(810, 58, 382, 24), "%s / %s" % [system_data.planet_name, status], 13, Color("#75ad83"), MONO)
	orbit_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(overlay, Rect2(128, 90, 850, 28), game_name.to_upper() + " / OPEN CHANNEL", 19, Color("#a6efc2"), MONO)
	_communication_skip = _terminal_action(Rect2(1020, 90, 172, 30), "Skip story »", _finish_communication)
	_contact_art = StoryArt.new()
	_contact_art.cinder = drift_circuit
	_contact_art.motion = motion
	_contact_art.name = "ContactPortrait"
	_place(overlay, _contact_art, Rect2(128, 148, 224, 240))
	_contact_name = _label(overlay, Rect2(128, 401, 240, 24), "HOLOGRAPHIC LINK", 12, SOUTH, MONO)
	_contact_progress = _label(overlay, Rect2(128, 431, 240, 20), "", 12, MUTED, MONO)
	_terminal_screen = RichTextLabel.new()
	_terminal_screen.bbcode_enabled = true
	_terminal_screen.scroll_active = false
	_terminal_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terminal_screen.add_theme_font_override("normal_font", SANS)
	_terminal_screen.add_theme_font_size_override("normal_font_size", 27)
	_terminal_screen.add_theme_color_override("default_color", INK)
	_terminal_screen.add_theme_constant_override("line_separation", 7)
	_terminal_screen.clip_contents = true
	_terminal_screen.finished.connect(_place_communication_action)
	_place(overlay, _terminal_screen, Rect2(400, 155, 792, 225))
	_terminal_messages = Story.encounter(system, expedition.standing(system), expedition.encounters_seen.has(system))
	expedition.encounters_seen[system] = true
	_terminal_active_line = 0
	_terminal_characters = 0.0
	_communication_prompt = _label(overlay, Rect2(128, 467, 1064, 22), "Read at your pace. Enter reveals the line, then continues.", 13, Color("#75ad83"), MONO)
	_communication_accept = _terminal_action(Rect2(400, 400, 420, 42), "[ENTER] CONTINUE", _advance_communication)
	_communication_accept.name = "ContinueTransmission"
	_communication_accept.flat = false
	_communication_accept.add_theme_font_size_override("font_size", 18)
	_communication_accept.add_theme_stylebox_override("normal", _style(Color("#123326"), Color("#47795b"), 4))
	_communication_accept.add_theme_stylebox_override("hover", _style(Color("#1d4b36"), Color("#8effb2"), 4))
	_communication_accept.add_theme_stylebox_override("pressed", _style(Color("#285d44"), Color("#c7ffdc"), 4))
	_terminal_action(Rect2(790, 506, 402, 32), "[Q] LEAVE ORBIT", _leave_planet_orbit)
	_label(overlay, Rect2(128, 554, 1064, 18), "HORIZON / PEACEFUL CONTACT / NO LANDING WITHOUT CLEARANCE", 11, Color("#518368"), MONO)
	_communication_local.disabled = true
	if _communication_presented:
		_finish_communication()
	else:
		_communication_presented = true
		_begin_terminal_message(0)
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
	_stop_communication()
	_terminal_active_line = index
	_terminal_characters = 0.0
	var message: Dictionary = _terminal_messages[index]
	_contact_art.role = message.role
	_contact_art.queue_redraw()
	_contact_name.text = "TRANSMITTING / " + ("CINDER" if drift_circuit else "KALYPSO") if message.role == "envoy" else "HORIZON / CREW LINK"
	_contact_progress.text = "%02d / %02d" % [index + 1, _terminal_messages.size()]
	soundtrack.cue("transmission")
	_communication_tween = create_tween()
	_communication_tween.tween_property(self, "_terminal_characters", float(message.text.length()), clampf(message.text.length() / 45.0, 0.5, 3.5)).from(0.0)
	_communication_tween.tween_callback(_stop_typing_audio)


func _process(_delta: float) -> void:
	if is_instance_valid(ability_hologram) and not _can_show_ability_hologram():
		ability_hologram.hide()
	if overlay_kind == "home":
		_render_terminal()


func _render_terminal() -> void:
	if _terminal_messages.is_empty() or not is_instance_valid(_terminal_screen):
		return
	var message: Dictionary = _terminal_messages[_terminal_active_line]
	var full_text: String = message.text
	var visible_text := full_text
	var heading: String = message.speaker
	if _communication_ready:
		heading = "DEPARTURE CONFIRMED" if _communication_departing else "CHALLENGE BRIEFING"
		visible_text = "Return to flight. You can come back whenever your crew is ready." if _communication_departing else Story.terms(expedition.current_system)
		if not _communication_departing and expedition.standing(expedition.current_system) == "allied":
			visible_text = "Friendly rematch. Your alliance is secure, whatever the result.\n\n" + ("Reach 8 total: relay points + surviving ships." if drift_circuit else "Hold the flag through 3 enemy turns, or eliminate their fleet.")
	var transcript := "[font_size=15][color=%s]%s[/color][/font_size]\n\n%s" % [message.color, heading, visible_text]
	if _terminal_screen.text != transcript:
		_terminal_screen.text = transcript
	_terminal_screen.visible_characters = -1 if _communication_ready else heading.length() + 2 + int(_terminal_characters)


func _place_communication_action() -> void:
	if overlay_kind != "home" or not is_instance_valid(_communication_accept):
		return
	# Hidden letters retain their layout, so typing cannot move the Continue button.
	var content_height := minf(225, _terminal_screen.get_content_height())
	_communication_accept.position = Vector2(400, _terminal_screen.position.y + content_height + 16)


func _stop_communication() -> void:
	_stop_typing_audio()
	if _communication_tween != null:
		_communication_tween.kill()
		_communication_tween = null
	_communication_ready = false


func _stop_typing_audio() -> void:
	soundtrack.stop_cue("transmission")


func _exit_tree() -> void:
	_stop_typing_audio()
	soundtrack.stop_cue("shuffle")


func _finish_communication() -> void:
	if overlay_kind != "home":
		return
	_stop_communication()
	_communication_ready = true
	_communication_accept.text = "[ENTER] RETURN TO FLIGHT" if _communication_departing else "[ENTER] ACCEPT CHALLENGE"
	_communication_accept.disabled = false
	_communication_local.disabled = _communication_departing
	_communication_skip.hide()
	_communication_prompt.text = "No penalty for declining. The invitation remains open." if _communication_departing else "Your choice, Captain."
	_contact_progress.text = "CHANNEL / STANDBY"
	_render_terminal()


func _accept_challenge(local: bool = false) -> void:
	if overlay_kind != "home" or not _communication_ready or busy or _communication_departing:
		return
	soundtrack.cue("confirm")
	_start(local)


func _leave_planet_orbit() -> void:
	if overlay_kind != "home" or busy:
		return
	if _communication_departing:
		_leave_current_orbit()
		return
	_communication_departing = true
	_terminal_messages = Story.departure(expedition.current_system)
	_communication_skip.show()
	_communication_skip.text = "Skip farewell »"
	_communication_accept.text = "[ENTER] CONTINUE"
	_communication_local.disabled = true
	_communication_prompt.text = "Channel closing. Press Q again to return directly to flight."
	_begin_terminal_message(0)


func _advance_communication() -> void:
	if overlay_kind != "home" or busy:
		return
	if _communication_ready:
		if _communication_departing:
			_leave_current_orbit()
		else:
			_accept_challenge()
	elif _terminal_characters < _terminal_messages[_terminal_active_line].text.length():
		_stop_communication()
		_terminal_characters = float(_terminal_messages[_terminal_active_line].text.length())
		_render_terminal()
	elif _terminal_active_line + 1 < _terminal_messages.size():
		_begin_terminal_message(_terminal_active_line + 1)
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
	soundtrack.stop_cue("shuffle")
	shuffling = false
	card_reveal.hide()
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
		local_mode = not local_mode
		takeover_queued = false
		_note("Aliens are now controlled by Player 2." if local_mode else "Aliens are now controlled by the computer.")
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
	var stamp := generation
	if action.kind == "roll":
		busy = true
		shuffling = motion
		if motion:
			soundtrack.cue("shuffle")
			card_reveal.start_shuffle()
		_refresh()
		if motion:
			await get_tree().create_timer(AbilityCards.SHUFFLE_TIME + AbilityCards.FLIP_TIME / 2).timeout
			if stamp != generation:
				return
			soundtrack.stop_cue("shuffle")
	var result := Rules.apply_action(state, action)
	if not result.ok:
		busy = false
		shuffling = false
		card_reveal.hide()
		_note("That action is no longer available.")
		_refresh()
		return
	var was_draft: bool = state.phase == "draft"
	var played_round: int = state.round
	var shifting: bool = result.events.any(func(event: Dictionary): return event.kind == "drift_score")
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
	_play_action_audio(result.events)
	for event: Dictionary in result.events:
		if event.kind in ["collapse", "missile"]:
			cockpit.alert = 0.7
		if first_flag_round == 0 and event.kind == "flag" and event.get("pawn", -1) >= 0:
			first_flag_round = played_round
		if event.kind not in ["turn", "draft_lock", "drift_move"]:
			var event_text: String = "%s drew %s." % [SIDES[event.side], SPELLS[event.special][0]] if event.kind == "roll" else event.text
			messages.push_front(event_text.replace("Pawns", "Units").replace("pawns", "units").replace("Pawn", "Unit").replace("pawn", "unit").replace("flag", "beacon"))
			if messages.size() > 12:
				messages.pop_back()
	legal = Rules.legal_actions(state)
	if rolled:
		shuffling = false
		soundtrack.cue("card_reveal")
		card_reveal.reveal(state.dice[state.active])
		_refresh()
		if card_reveal.visible:
			await get_tree().create_timer(AbilityCards.FLIP_TIME / 2 + AbilityCards.REVEAL_HOLD).timeout
			if stamp != generation:
				return
		card_reveal.hide()
		busy = false
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
	var turn_delay := 0.65 if motion else 0.10
	if motion and shifting:
		turn_delay = Arena.DRIFT_DELAY + Arena.DRIFT_DURATION + 0.15
	if motion and action.kind == "missile":
		turn_delay = Arena.MISSILE_FLIGHT + Arena.MISSILE_BLAST + 0.08
	await get_tree().create_timer(turn_delay).timeout
	if stamp != generation:
		return
	busy = false
	_enter_turn()


func _play_action_audio(events: Array) -> void:
	var cues := {}
	for event: Dictionary in events:
		match event.kind:
			"step":
				cues["move"] = 0.26 if motion else 0.0
			"capture":
				cues["capture"] = 0.20 if motion else 0.0
			"shield_break":
				cues["shield"] = 0.0
			"warning", "draft_reveal":
				cues["confirm"] = 0.0
			"collapse":
				cues["collapse"] = 0.0
			"missile":
				cues["teleport"] = 0.0
				cues["collapse"] = Arena.MISSILE_FLIGHT if motion else 0.0
			"spy":
				cues["spy"] = 0.0
			"infection":
				cues["infection"] = 0.0
			"ability":
				if event.ability in ["teleport", "shield"]:
					cues[event.ability] = 0.0
				elif event.ability == "fracture":
					cues["confirm"] = 0.0
			"flag":
				if event.pawn >= 0:
					cues["relay"] = 0.25 if motion else 0.0
			"drift_score":
				cues["lane_shift"] = Arena.DRIFT_DELAY if motion else 0.0
			"relay_relocated":
				cues["relay"] = Arena.DRIFT_DELAY + Arena.DRIFT_DURATION if motion else 0.0
			"result":
				var result_cue := "confirm" if event.side < 0 else ("victory" if event.side == 1 else "defeat")
				cues[result_cue] = 0.98 if drift_circuit and motion else 0.0
				if motion and events.any(func(item: Dictionary): return item.kind == "missile"):
					cues[result_cue] = Arena.MISSILE_FLIGHT + Arena.MISSILE_BLAST
	if "teleport" in cues:
		cues.erase("move")
	for cue: String in cues:
		var delay: float = cues[cue]
		if delay > 0.0:
			var stamp := generation
			var tween := create_tween()
			tween.tween_interval(delay)
			tween.tween_callback(func():
				if stamp == generation:
					soundtrack.cue(cue))
		else:
			soundtrack.cue(cue)


func _takeover() -> void:
	if state.phase != "playing" or takeover_queued:
		return
	takeover_queued = true
	_note("Computer control will resume on the next Alien turn." if local_mode else "Multiplayer will begin on the next Alien turn.")
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
		status_label.text = "LANES SHIFTING" if board.shift_tween else "RELAYS   " + "  /  ".join(coords)
	else:
		var flag_status := "%d/%d HELD" % [state.replies, Rules.FLAG_REPLIES] if state.holder >= 0 else "UNCLAIMED"
		if state.holder < 0 and _pawn_at(state.flag) >= 0:
			flag_status = "STOLEN UNIT  /  NO SCORE"
		status_label.text = "BEACON  %s     /     %s" % [_coord(state.flag), flag_status]
	mode_button.text = "Local" if local_mode else "Solo"
	takeover_button.disabled = draft or takeover_queued or state.phase != "playing"
	if takeover_queued:
		takeover_button.text = "Bot queued" if local_mode else "MP queued"
	else:
		takeover_button.text = "Computer" if local_mode else "Multiplayer"
	_clear(side_panel)
	if draft:
		_draw_draft()
	elif drift_circuit:
		_draw_drift_play()
	else:
		_draw_play()
	_sync_ability_hologram()


func _can_show_ability_hologram() -> bool:
	if drift_circuit or state.is_empty() or state.phase != "playing" or selected not in state.pawns:
		return false
	if busy or handoff or overlay_kind != "" or not board.is_visible_in_tree() or (not local_mode and state.active == 0):
		return false
	var pawn: Dictionary = state.pawns[selected]
	return pawn.side == state.active and pawn.ability in DRAFT_SPELLS and pawn.charged and pawn.spy == 0


func _sync_ability_hologram() -> void:
	if not _can_show_ability_hologram():
		ability_hologram.hide()
		return
	var pawn: Dictionary = state.pawns[selected]
	var reason := Rules.ability_reason(state, pawn)
	var status := "READY / ONE USE / REPLACES MOVE"
	if state.dice[state.active].is_empty():
		reason = "Shuffle first to unlock your move and this ability."
		status = "SHUFFLE FIRST"
	elif state.turn_power_used:
		reason = "Your actions are complete. Finish your turn."
		status = "FINISH YOUR TURN"
	elif state.turn_move:
		reason = "You already used your move this turn."
		status = "MOVE ALREADY PLAYED"
	elif not reason.is_empty():
		status = "UNAVAILABLE"
	var title: String = SPELLS[pawn.ability][0]
	var caption := "Use " + title
	if pawn.ability == "fracture": caption = "Use Fracture"
	elif pawn.ability == "missile": caption = "Launch missile"
	var hint := "Choose a landing tile"
	if pawn.ability == "shield": hint = "Click this ship to raise its shield"
	elif pawn.ability == "fracture": hint = "Choose a tile to fracture"
	elif pawn.ability == "missile": hint = "Choose an enemy or empty tile"
	ability_hologram.configure({
		"board": board, "square": pawn.pos, "title": title, "motion": motion,
		"status": status, "description": reason if not reason.is_empty() else SPELLS[pawn.ability][1],
		"hint": hint, "targeting": action_group == "ability" and reason.is_empty(),
		"can_move": not _group_actions("standard").is_empty(), "can_use": not _group_actions("ability").is_empty(),
		"group": action_group, "button": caption,
	})


func _choose_hologram_action(group: String) -> void:
	if not _can_show_ability_hologram() or group not in ["standard", "ability"] or _group_actions(group).is_empty():
		return
	_set_group(group)


func _update_transmission() -> void:
	if drift_circuit:
		signal_text.text = "The relay race has ended." if state.phase == "finished" else "Gold relays score after the shift, then move along their rows."
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
	var face: String = state.dice[state.active]
	var deck := AbilityCards.new()
	deck.compact = true
	deck.face = face
	deck.shuffling = shuffling
	_place(side_panel, deck, Rect2(851, 242, 80, 69))
	_label(side_panel, Rect2(936, 246, 175, 20), "ABILITY DECK", 12, MUTED, MONO)
	var special_name: String = SPELLS[face][0] if not face.is_empty() else ("Shuffling…" if shuffling else "Ready to shuffle")
	_label(side_panel, Rect2(936, 271, 190, 29), special_name, 18, AbilityCards.POWERS[face].color if face in AbilityCards.POWERS else LILAC, MONO)
	var shuffle := _button(side_panel, Rect2(1130, 258, 128, 38), "Card drawn" if not face.is_empty() else ("Shuffling…" if shuffling else "Shuffle"), _shuffle_ability, face.is_empty())
	shuffle.tooltip_text = SPELLS[face][1] if not face.is_empty() else "Shuffle once to draw your ability card."
	shuffle.disabled = busy or state.phase != "playing" or not face.is_empty() or (not local_mode and state.active == 0)
	var drops := "Purple cracks fall after this turn." if not state.fractures.is_empty() else "Rim cracks fall after both turns."
	if state.fractures.is_empty() and state.cracks.is_empty():
		drops = "Shuffle before moving. Skip turn is always available." if face.is_empty() else "Card ready. Move, use power, or finish your turn."
	_label(side_panel, Rect2(864, 310, 390, 25), drops, 14, GOLD if not state.cracks.is_empty() or not state.fractures.is_empty() else MUTED)
	_panel(side_panel, Rect2(846, 359, 430, 225))
	_label(side_panel, Rect2(864, 369, 396, 25), "TURN CHOICES", 12, MUTED, MONO)
	_label(side_panel, Rect2(864, 396, 218, 80), _action_hint(), 14, INK, SANS, true)
	if selected >= 0 and selected in state.pawns:
		var p: Dictionary = state.pawns[selected]
		_action_button(Rect2(864, 480, 189, 38), "Move / capture", "standard")
		if p.ability != "":
			_action_button(Rect2(864, 524, 189, 36), SPELLS[p.ability][0], "ability")
		var details := Rules.ability_reason(state, p) if p.ability != "" else ""
		if p.spy > 0:
			details = "Stolen unit · %d turns left. Cannot score or capture at the beacon." % p.spy
		elif details.is_empty() and action_group == "ability":
			details = SPELLS[p.ability][1]
		elif details.is_empty() and action_group == "power" and not face.is_empty():
			details = SPELLS[face][1]
		if not details.is_empty():
			var detail_label := _label(side_panel, Rect2(864, 562, 218, 20), details, 12, MUTED)
			detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			detail_label.tooltip_text = details
			detail_label.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		_label(side_panel, Rect2(864, 510, 188, 70), "Select a unit to move. Click your card for power targets.", 15, MUTED, SANS, true)
	if not face.is_empty():
		_draw_power_card(face)
	_draw_flight_log()
	var skip := _button(side_panel, Rect2(846, 744, 430, 42), "Finish / skip turn", _skip_turn)
	skip.name = "FinishTurnButton"
	skip.disabled = busy or state.phase != "playing" or (not local_mode and state.active == 0)


func _draw_power_card(face: String) -> void:
	var available := not _group_actions("power").is_empty()
	var card := _button(side_panel, Rect2(1100, 386, 156, 194), "Use power", _select_power_card)
	card.name = "PowerCardButton"
	card.disabled = busy or not available or state.phase != "playing" or (not local_mode and state.active == 0)
	card.tooltip_text = SPELLS[face][0] + " · " + SPELLS[face][1]
	var tone: Color = AbilityCards.POWERS[face].color
	for appearance in ["normal", "disabled", "pressed", "hover"]:
		var highlighted: bool = appearance == "hover" or appearance == "pressed" or (action_group == "power" and appearance == "normal")
		var fill := Color(tone, 0.08) if highlighted else Color.TRANSPARENT
		card.add_theme_stylebox_override(appearance, _style(fill, tone if highlighted else Color.TRANSPARENT, 0))
	for appearance in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
		card.add_theme_color_override(appearance, Color.TRANSPARENT)
	card.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, SOUTH, 0))
	var view := AbilityCards.new()
	view.docked = true
	view.face = face
	view.action_label = "Choose target" if action_group == "power" else "Use power"
	if state.turn_power_used:
		view.action_label = "Power used"
	elif busy:
		view.action_label = "Revealing…" if card_reveal.visible else "Please wait…"
	elif not local_mode and state.active == 0:
		view.action_label = "Opponent's card"
	elif not available:
		view.action_label = "No legal targets"
	_place(card, view, Rect2(Vector2.ZERO, card.size))


func _select_power_card() -> void:
	if busy or state.phase != "playing" or _group_actions("power").is_empty() or (not local_mode and state.active == 0):
		return
	_set_group("power")


func _draw_drift_play() -> void:
	_team_card(846, 148, 0)
	_team_card(1067, 148, 1)
	_panel(side_panel, Rect2(846, 238, 430, 108))
	_label(side_panel, Rect2(864, 249, 394, 22), "WIN CONDITION", 12, LILAC, MONO)
	_label(side_panel, Rect2(864, 273, 394, 32), "Points + units = 8 to win.", 21, GOLD, bold)
	_panel(side_panel, Rect2(846, 359, 430, 225))
	_label(side_panel, Rect2(864, 371, 394, 56), _action_hint(), 16, INK, SANS, true)
	_label(side_panel, Rect2(864, 488, 390, 70), "Claimed relays jump to a new square on the same row. Hover over a highlighted move to preview its landing.", 16, MUTED, SANS, true)
	_draw_flight_log()


func _draw_flight_log() -> void:
	var panel := _panel(side_panel, Rect2(846, 592, 430, 140), ALIEN_PANEL, ALIEN_LINE, 12)
	panel.name = "FlightLogPanel"
	panel.clip_contents = true
	_label(panel, Rect2(18, 8, 270, 22), "FLIGHT LOG", 12, ALIEN_GREEN, MONO)
	var log_button := _button(panel, Rect2(316, 6, 97, 27), "View log", _show_log)
	log_button.add_theme_stylebox_override("normal", _style(Color("#14281a"), ALIEN_LINE, 8))
	log_button.add_theme_stylebox_override("hover", _style(Color("#1e3925"), ALIEN_GREEN, 8))
	log_button.add_theme_stylebox_override("pressed", _style(Color("#284b30"), ALIEN_GREEN, 8))
	log_button.add_theme_color_override("font_color", ALIEN_GREEN)
	log_button.add_theme_color_override("font_hover_color", Color("#d0ffc4"))
	var scroll := ScrollContainer.new()
	scroll.name = "FlightLogScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	_place(panel, scroll, Rect2(18, 38, 389, 88))
	var entries := VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 6)
	scroll.add_child(entries)
	var latest := messages.slice(0, 3)
	for i in range(latest.size()):
		var entry := _label(entries, Rect2(0, 0, 367, 0), latest[i], 13, ALIEN_GREEN if i == 0 else ALIEN_DIM, MONO, true)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL


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


func _drift_total(side: int) -> int:
	var total: int = state.drift.scores[side]
	for pawn: Dictionary in state.pawns.values():
		if pawn.side == side:
			total += 1
	return total


func _shuffle_ability() -> void:
	if busy or {"kind": "roll"} not in legal or (not local_mode and state.active == 0):
		return
	board.grab_focus()
	_commit({"kind": "roll"})


func _skip_turn() -> void:
	if busy or {"kind": "skip"} not in legal or (not local_mode and state.active == 0):
		return
	_commit({"kind": "skip"})


func _action_hint() -> String:
	if state.phase == "finished":
		return "Duel complete."
	if busy:
		if drift_circuit and board.shift_tween:
			return "Rows 4 and 6 are shifting."
		if shuffling:
			return "Shuffling the ability cards…"
		if card_reveal.visible:
			return "Your ability card is ready."
		if not local_mode and state.active == 0:
			return "Aliens are taking their turn."
		return "Resolving the turn."
	if drift_circuit:
		return "Select a highlighted move or capture." if selected >= 0 else "Select one of your units to see its legal moves."
	if state.dice[state.active].is_empty():
		return "Step 1: Shuffle the ability cards. Or finish / skip to pass without acting."
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
	if action_group == "ability" and p.ability == "shield":
		return "Select the highlighted unit again to raise its shield."
	if action_group == "ability" and p.ability == "fracture":
		return "Select a tile to drop after the next turn."
	if action_group == "ability" and p.ability == "missile":
		return "Select a highlighted enemy or empty tile to destroy with one missile."
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
		else:
			highlighted[action.to] = "capture" if action.kind in ["capture", "long_capture"] else "move"
			if action.kind == "fracture":
				highlighted[action.to] = "fracture"
			elif action.kind == "missile":
				highlighted[action.to] = "missile"
	return highlighted


func _square_pressed(square: Vector2i) -> void:
	if busy or handoff or overlay_kind != "" or state.phase == "finished" or (not local_mode and state.active == 0):
		return
	var id := _pawn_at(square)
	if state.phase == "draft":
		if id >= 0 and state.pawns[id].side == state.active:
			soundtrack.cue("select")
			selected = id
			_refresh()
		return
	for action in _group_actions(action_group):
		if _select_target(action, square):
			return
	if id >= 0 and state.pawns[id].side == state.active:
		soundtrack.cue("select")
		_clear_selection()
		selected = id
		if _group_actions("standard").is_empty():
			for group: String in ["ability", "power"]:
				if not _group_actions(group).is_empty():
					action_group = group
					break
		_refresh()


func _select_target(action: Dictionary, square: Vector2i) -> bool:
	if action.kind == "spy":
		if state.pawns[action.mark].pos == square:
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
	if drift_circuit:
		_show_drift_guide(0)
		return
	_show_kalypso_guide(0)


func _show_drift_guide(page: int) -> void:
	var box := _modal("rules", "Drift Circuit · How to play", 740)
	_panel(box, Rect2(31, 89, 620, 83), Color("#192a32"), LINE, 4)
	_label(box, Rect2(45, 94, 590, 20), "GOAL", 12, GOLD, MONO)
	_label(box, Rect2(45, 116, 590, 50), "Score %d points: relays + surviving units." % Drift.TOTAL_TO_WIN, 19, INK, SANS, true)
	var tabs := ["Quick start", "Movement", "Scoring"]
	for index in tabs.size():
		var tab := _button(box, Rect2(31 + index * 210, 185, 200, 36), tabs[index], _show_drift_guide.bind(index), page == index)
		tab.name = "GuideTab%d" % index
	if page == 0:
		_rich(box, Rect2(31, 238, 620, 418), DRIFT_QUICK_START, 18)
	elif page == 1:
		_rich(box, Rect2(31, 235, 620, 418), DRIFT_MOVEMENT, 17)
	else:
		_rich(box, Rect2(31, 238, 620, 298), DRIFT_SCORING % [Drift.TOTAL_TO_WIN, Drift.ROUND_LIMIT], 17)
		var titles: Array[String] = ["RELAY", "FLEET", "LIMIT"]
		var values: Array[String] = ["+1", "+1", "%d / %d" % [Drift.TOTAL_TO_WIN, Drift.ROUND_LIMIT]]
		var details: Array[String] = ["per occupied relay", "per surviving unit", "goal / round cap"]
		for index in titles.size():
			var x := 31 + index * 210
			_panel(box, Rect2(x, 550, 200, 106), Color("#192a32"), LINE, 5)
			_label(box, Rect2(x + 12, 558, 176, 18), titles[index], 11, GOLD, MONO)
			_label(box, Rect2(x + 12, 577, 176, 34), values[index], 25, INK, bold)
			_label(box, Rect2(x + 12, 614, 176, 31), details[index], 13, MUTED, SANS, true)
	_button(box, Rect2(31, 680, 620, 41), "Back to game" if not state.is_empty() else "Back", _close_overlay)


func _show_kalypso_guide(page: int) -> void:
	var box := _modal("rules", "The Fractured Flag · How to play", 740)
	_panel(box, Rect2(31, 89, 620, 83), Color("#192a32"), LINE, 4)
	_label(box, Rect2(45, 94, 590, 20), "GOAL", 12, GOLD, MONO)
	_label(box, Rect2(45, 116, 590, 50), KalypsoGuide.OBJECTIVE, 19, INK, SANS, true)
	var tabs := ["Quick start", "Moves", "Abilities"]
	for index in tabs.size():
		var tab := _button(box, Rect2(31 + index * 210, 185, 200, 36), tabs[index], _show_kalypso_guide.bind(index), page == index)
		tab.name = "GuideTab%d" % index
	if page == 0:
		_rich(box, Rect2(31, 238, 620, 418), KalypsoGuide.QUICK_START, 18)
	elif page == 1:
		var examples := [
			["MOVE", "res://art/guides/kalypso-movement-guide.png", KalypsoGuide.MOVEMENT],
			["CAPTURE", "res://art/guides/kalypso-capture-guide.png", KalypsoGuide.CAPTURES],
		]
		for index in examples.size():
			var x := 31 + index * 320
			_label(box, Rect2(x, 235, 300, 24), examples[index][0], 15, SOUTH if index == 0 else NORTH, MONO)
			var screenshot := TextureRect.new()
			screenshot.name = "MovementScreenshot" if index == 0 else "CaptureScreenshot"
			screenshot.texture = load(examples[index][1])
			screenshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			screenshot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			screenshot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_place(box, screenshot, Rect2(x, 266, 300, 259))
			_rich(box, Rect2(x, 535, 300, 91), examples[index][2], 16)
		_rich(box, Rect2(31, 632, 620, 38), "Enter the flag from an adjacent tile or by capture. Click a ship to see legal targets; drag the board to rotate.", 14)
	else:
		_rich(box, Rect2(31, 238, 620, 425), KalypsoGuide.ABILITIES, 17)
	_button(box, Rect2(31, 680, 620, 41), "Back to game" if not state.is_empty() else "Back", _close_overlay)


func _show_credits() -> void:
	var box := _modal("credits", "Asset credits", 495)
	var audio_list := _rich(box, Rect2(31, 92, 620, 317), "[color=#f8d587]COCKPIT AND SYSTEM[/color]\n[url=https://kenney.nl/assets/space-kit]Space Kit · Kenney · CC0[/url]\n[url=https://opengameart.org/content/spaceship-interior-0]Spaceship Interior · cheerful sprite · CC0[/url]\n[url=https://screamingbrainstudios.itch.io/tiny-planet-pack]Tiny Planet Pack · Screaming Brain Studios · CC0[/url]\n[url=https://opengameart.org/content/sideview-sci-fi-patreon-collection]Horizon sprite · Luis Zuno (Ansimuz) · CC0[/url]\n[url=https://klenchandrei.itch.io/exhaust-free]Rocket exhaust · KlenchAndrei · CC0[/url]\n[url=https://opengameart.org/content/sci-fi-roguelike-pixel-art]Result portraits · Emcee Flesher · CC0[/url]\n[url=https://github.com/halfmage/pixelarticons/tree/v1.8.1]Ability icons · Gerrit Halfmann · MIT[/url]\n\n[color=#f8d587]WESTERLUND 2[/color]\n[url=" + IMAGE_URL + "]" + IMAGE_CREDIT + "[/url]\nHubble observation. CC BY 4.0. Cropped and tinted.\n\n[color=#f8d587]TYPE[/color]\n[url=https://github.com/floriankarsten/space-grotesk]Space Grotesk · Florian Karsten[/url]\n[url=https://github.com/IBM/plex]IBM Plex Mono · IBM Corp.[/url]\nBoth SIL Open Font License 1.1.")
	_button(box, Rect2(31, 427, 620, 41), "Back", _close_overlay)
	audio_list.append_text("\n\n[color=#f8d587]AUDIO[/color]\n[url=https://opengameart.org/content/another-space-background-track]Observing the Star · yd · CC0[/url]\n[url=https://opengameart.org/content/background-space-track]My Very Own Dead Ship · yd · CC0[/url]\n[url=https://kenney.nl/assets/sci-fi-sounds]Sci-fi Sounds[/url], [url=https://kenney.nl/assets/interface-sounds]Interface Sounds[/url], [url=https://kenney.nl/assets/casino-audio]Casino Audio[/url] and [url=https://kenney.nl/assets/music-jingles]Music Jingles[/url] · Kenney · CC0.")
	audio_list.append_text("\n[url=https://opengameart.org/content/bubbling-acid]Bubbling Acid · spookymodem · CC BY 3.0[/url] (trimmed and faded)\nRocket thrust · supplied MP3 · trimmed and looped")
	audio_list.append_text("\n\n[color=#f8d587]CREW & ENVOYS[/color]\n[url=https://opengameart.org/content/sci-fi-roguelike-pixel-art]Sci-Fi RogueLike Pixel Art · Emcee Flesher · CC0[/url]\nOriginal pixel characters, scaled with nearest-neighbor filtering. Hologram scanlines and result spotlights use Godot primitives. No AI-generated artwork.")

	audio_list.append_text("\n\n[color=#f8d587]DESCENT SEQUENCE[/color]\n[url=https://commons.wikimedia.org/wiki/File:StarfieldSimulation.gif]Starfield Simulation · Jahobr · CC0 · 2017[/url]\nOriginal star animation looped and converted to video.\n[url=https://commons.wikimedia.org/wiki/File:Space_Shuttle_Atlantis_OV-104_main_flight_deck.png]Atlantis flight deck · DMolybdenum · Public domain[/url]\nPanorama reprojected to a centered forward view, darkened, and windows masked. No AI generated assets.")
	audio_list.append_text("\n\n[color=#f8d587]MISSILE STRIKE[/color]\nRocket · supplied PixelProjectiles v1.0 · game-use license included. The pack describes AI-assisted, programmatically generated pixel art.\nExplosion Pack 1 · Luis Zuno (Ansimuz) · CC0.\nOriginal sprite strips animated and rotated in Godot. Full notices in art/effects/missile.")


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
		replay["rules_version"] = 5
		replay["layout"] = state.drift.layout
		replay["bot_focus"] = state.drift.focus
	DisplayServer.clipboard_set(JSON.stringify(replay))
	_note("Replay copied.")
	_close_overlay()


func _show_result() -> void:
	if state.is_empty() or state.phase != "finished":
		return
	if not is_same(state, _result_recorded_state):
		_result_was_allied = expedition.standing(expedition.current_system) == "allied"
		_result_recorded_state = state
		expedition.record_battle(int(state.winner))
	_show_story_result(_result_was_allied)


func _show_story_result(already_allied: bool) -> void:
	var won: bool = state.winner == 1
	var lost: bool = state.winner == 0
	var tone := Color("#8ae0a4") if won else (NORTH if lost else GOLD)
	var planet: String = expedition.current_system_data().planet_name
	var title := "Crew victory!" if won else ("Challenge lost" if lost else "Challenge drawn")
	if local_mode and state.winner >= 0:
		title = "%s win!" % SIDES[state.winner]
	var outcome := "ALLIANCE SECURED / " + ("NAVIGATION NETWORK OPEN" if drift_circuit else "LANDING CLEARANCE GRANTED") if won else "UNPROVEN / " + ("NETWORK ACCESS DENIED" if drift_circuit else "LANDING CLEARANCE DENIED") if lost else "INVITATION OPEN / TRY AGAIN ANYTIME"
	if already_allied:
		outcome = "FRIENDLY REMATCH / YOUR ALLIANCE STANDS"
	var description := "The challenge is complete."
	match state.reason:
		"flag":
			description = "Your ship held the flag through 3 enemy turns." if won else "An enemy ship held the flag through 3 of your turns."
		"elimination":
			description = "All enemy ships were eliminated." if won else "All of your ships were eliminated."
		"mutual_elimination":
			description = "Both sides lost their last ship."
		"round_cap":
			description = "Neither side won within 8 rounds."
		"relays":
			description = "Relay points + surviving ships reached 8 after the shift."
		"drift_tie":
			description = "Both sides reached 8 on the same shift."
		"drift_limit":
			description = "Neither side won within 12 rounds."
	if local_mode and state.winner >= 0 and not drift_circuit:
		description = "%s held the flag through 3 enemy turns." % SIDES[state.winner] if state.reason == "flag" else "%s eliminated the opposing fleet." % SIDES[state.winner]
	cockpit.clearance = "land" if expedition.standing(expedition.current_system) == "allied" else ""
	_clear(overlay)
	overlay_kind = "result"
	var dim := ColorRect.new()
	dim.color = Color(0.018, 0.028, 0.05, 0.92)
	_place(overlay, dim, Rect2(0, 0, 1320, 807))
	var box := _panel(overlay, Rect2(250, 38, 820, 750), Color("#101c2a"), tone, 8)
	box.name = "ResultPanel"
	var border := _style(Color("#101c2a"), tone, 8)
	border.set_border_width_all(3)
	box.add_theme_stylebox_override("panel", border)
	_label(box, Rect2(32, 20, 470, 22), planet + " / HORIZON MISSION REPORT", 12, tone, MONO)
	if drift_circuit:
		_label(box, Rect2(520, 20, 268, 22), "ALIENS %d / CREW %d" % [_drift_total(0), _drift_total(1)], 12, MUTED, MONO).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(box, Rect2(32, 48, 756, 52), title, 44, tone, bold)
	_label(box, Rect2(32, 108, 756, 24), outcome, 13, tone, MONO)
	var cast := StoryArt.new()
	cast.name = "ResultCast"
	cast.lineup = true
	cast.cinder = drift_circuit
	cast.outcome = state.winner
	cast.motion = motion
	_place(box, cast, Rect2(24, 143, 772, 202))
	if state.winner < 0:
		_label(box, Rect2(150, 336, 164, 18), "CREW", 12, SOUTH, MONO).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label(box, Rect2(506, 336, 164, 18), "ALIENS", 12, NORTH, MONO).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		_label(box, Rect2(302, 336, 216, 18), "ALIENS" if lost else "CREW", 12, tone, MONO).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label(box, Rect2(32, 336, 140, 18), "CREW" if lost else "ALIENS", 11, MUTED, MONO).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label(box, Rect2(648, 336, 140, 18), "CINDER" if drift_circuit else "KALYPSO", 11, MUTED, MONO).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel(box, Rect2(32, 359, 756, 119), Color("#0a1621"), LINE, 4)
	_result_portrait = StoryArt.new()
	_result_portrait.cinder = drift_circuit
	_result_portrait.motion = motion
	_place(box, _result_portrait, Rect2(42, 369, 88, 98))
	_result_speaker = _label(box, Rect2(148, 370, 550, 22), "", 12, tone, MONO)
	_result_quote = _label(box, Rect2(148, 400, 540, 70), "", 19, INK, SANS, true)
	_result_next = _button(box, Rect2(705, 395, 70, 50), "Next ›", _advance_result_story)
	_result_story = Story.result(expedition.current_system, int(state.winner), already_allied)
	if expedition.all_allied() and won:
		_result_story.append_array(Story.epilogue(expedition.current_system))
	_result_line = 0
	_render_result_story()
	_label(box, Rect2(32, 491, 756, 20), "HOW IT ENDED", 11, MUTED, MONO)
	_label(box, Rect2(32, 517, 756, 27), description, 18, INK, SANS, true)
	var round_text := _label(box, Rect2(32, 555, 132, 22), "ROUND %02d" % state.round, 13, GOLD, MONO)
	round_text.name = "ResultRound"
	var progress := "2 ALLIANCES / THE EXPEDITION CONTINUES" if expedition.all_allied() else "Trust earned. Fly on, or play again." if won or already_allied else "Withdraw and retry. Your journey continues." if lost else "No standing lost. Your journey continues."
	_label(box, Rect2(183, 555, 605, 25), progress, 13, tone if expedition.all_allied() else MUTED, MONO).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var flight := _button(box, Rect2(32, 604, 756, 44), "Return to flight", _leave_current_orbit)
	flight.name = "ReturnToFlightButton"
	flight.tooltip_text = "Resume flying near " + planet.capitalize() + "."
	var fill := Color("#1d3a32") if won else Color("#203042")
	flight.add_theme_stylebox_override("normal", _style(fill, tone, 4))
	flight.add_theme_stylebox_override("hover", _style(fill.lightened(0.16), tone, 4))
	flight.add_theme_stylebox_override("pressed", _style(fill.lightened(0.24), tone, 4))
	_button(box, Rect2(32, 664, 370, 42), "Rematch", func(): _start(local_mode, true))
	_button(box, Rect2(418, 664, 370, 42), "View board", func(): _close_overlay(false))
	_label(box, Rect2(32, 722, 756, 18), "HORIZON / EXPLORATION LOG / " + planet, 11, MUTED, MONO)


func _advance_result_story() -> void:
	_result_line = (_result_line + 1) % _result_story.size()
	_render_result_story()


func _render_result_story() -> void:
	var message: Dictionary = _result_story[_result_line]
	_result_speaker.text = "%s  /  %d OF %d" % [message.speaker, _result_line + 1, _result_story.size()]
	_result_quote.text = message.text
	_result_portrait.role = message.role
	_result_portrait.queue_redraw()
	_result_next.text = "↺" if _result_line == _result_story.size() - 1 else "Next ›"


func _travel_to_next_system() -> void:
	if busy or state.is_empty() or state.phase != "finished" or not expedition.has_next_system():
		return
	busy = true
	generation += 1
	var scene_error := expedition.fly_to(ExpeditionState.CINDER, true)
	if scene_error != OK:
		busy = false
		_note("Could not set course for Cinder.")


func _rich(parent: Node, rect: Rect2, value: String, px: int = 18) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.text = value
	rich.add_theme_font_override("normal_font", SANS)
	rich.add_theme_font_size_override("normal_font_size", px)
	rich.add_theme_color_override("default_color", INK)
	rich.meta_clicked.connect(func(url): OS.shell_open(str(url)))
	_place(parent, rich, rect)
	return rich


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
