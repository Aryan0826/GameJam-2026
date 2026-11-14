extends Control
## Interface drawn with Godot primitives; no generated images or changes to ship artwork.
signal action_chosen(group: String)

const MONO = preload("res://art/IBMPlexMono-Regular.ttf")
const SANS = preload("res://art/SpaceGrotesk.ttf")
const CYAN := Color("#83e1fa")
const LILAC := Color("#bd9dff")
var board: Control
var square := Vector2i.ZERO
var motion := true
var card: Control
var heading: Label
var status: Label
var description: Label
var normal_button: Button
var ability_button: Button
var age := 0.0
var anchor := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(_on_visibility_changed)
	card = Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)
	heading = _label(Vector2(14, 9), Vector2(276, 28), 18, MONO, CYAN)
	status = _label(Vector2(14, 39), Vector2(276, 18), 11, MONO, LILAC)
	description = _label(Vector2(14, 64), Vector2(276, 53), 15, SANS, Color("#e0eff6"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	normal_button = _button("Move normally", "standard", Vector2(14, 140))
	ability_button = _button("Use ability", "ability", Vector2(160, 140))
	hide()

func _label(at: Vector2, extent: Vector2, px: int, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = extent
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0.025, 0.04, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(label)
	return label

func _style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.content_margin_left = 6
	style.content_margin_right = 6
	return style

func _button(text: String, group: String, at: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(130, 32)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", SANS)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color("#f3f5ff"))
	button.add_theme_stylebox_override("hover", _style(Color("#224957"), CYAN))
	button.add_theme_stylebox_override("pressed", _style(Color("#32596b"), CYAN))
	button.add_theme_stylebox_override("disabled", _style(Color("#112731"), Color("#3d5b68")))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, CYAN))
	card.add_child(button)
	button.pressed.connect(func(): action_chosen.emit(group))
	return button

func configure(data: Dictionary) -> void:
	if square != data.square or not visible:
		age = 0.0
	board = data.board
	square = data.square
	motion = data.motion
	heading.text = data.title.to_upper()
	status.text = data.status
	description.text = data.hint if data.targeting else data.description
	var text_height := maxf(40, SANS.get_multiline_string_size(data.description, HORIZONTAL_ALIGNMENT_LEFT, 276, 15).y)
	description.size.y = 20 if data.targeting else text_height
	var buttons_y := 86.0 if data.targeting else 64.0 + text_height + 8.0
	card.size = Vector2(304, 124 if data.targeting else buttons_y + 42)
	normal_button.position.y = buttons_y
	ability_button.position.y = buttons_y
	normal_button.disabled = not data.can_move
	ability_button.disabled = not data.can_use
	ability_button.text = data.button
	for pair in [[normal_button, "standard"], [ability_button, "ability"]]:
		var active: bool = data.group == pair[1]
		pair[0].add_theme_stylebox_override("normal", _style(Color("#21424f") if active else Color("#102530"), CYAN if active else LILAC))
	show()
	_update_anchor()
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(board):
		return
	age += delta
	_update_anchor()
	queue_redraw()

func _update_anchor() -> void:
	anchor = board._project(square, 0.55)
	# Float in the clear space above the tiles instead of over the fleet.
	# The root does not clip, so the panel can rise above the board's top edge.
	var target := Vector2(clampf(anchor.x - card.size.x / 2, 8, size.x - card.size.x - 8), -40)

	if motion:
		target.y += 10 * (1.0 - clampf(age / 0.2, 0, 1))
	card.position = target.round()
	if is_visible_in_tree():
		board.set_coordinate_mask(card.get_rect())

func _on_visibility_changed() -> void:
	if not is_visible_in_tree() and is_instance_valid(board):
		board.set_coordinate_mask(Rect2())

func _exit_tree() -> void:
	if is_instance_valid(board):
		board.set_coordinate_mask(Rect2())

func _draw() -> void:
	if not is_instance_valid(card): return
	var rect := card.get_rect()
	var contact := anchor.clamp(rect.position, rect.end)
	var perpendicular := (contact - anchor).normalized().orthogonal() * 9
	draw_colored_polygon(PackedVector2Array([anchor, contact + perpendicular, contact - perpendicular]), Color(0.32, 0.85, 1.0, 0.10))
	draw_line(anchor, contact, Color(0.51, 0.88, 0.98, 0.7), 1)
	draw_circle(anchor, 4, CYAN, false, 1)
	draw_style_box(_style(Color(0.035, 0.12, 0.16, 1.0), Color(0.51, 0.88, 0.98, 0.85)), rect)
	for y in range(int(rect.position.y) + 4, int(rect.end.y), 5):
		draw_line(Vector2(rect.position.x + 1, y), Vector2(rect.end.x - 1, y), Color(0.51, 0.88, 0.98, 0.025), 1)
	# A brief appearance, not a continuously flashing panel. FX off keeps it static.
	modulate.a = 1.0
