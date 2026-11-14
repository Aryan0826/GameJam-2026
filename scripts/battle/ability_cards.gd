extends Control
## Existing Pixelarticons 1.8.1 artwork by Gerrit Halfmann (MIT).
## Only icon fill colors are adapted; see art/cards/icons/SOURCE.md.

const MONO = preload("res://art/fonts/IBMPlexMono-Regular.ttf")
const BACK_ICON = preload("res://art/cards/icons/shield.svg")
const POWERS = {
	"infected_trail": {
		"icon": preload("res://art/cards/icons/bug.svg"),
		"color": Color("#8ae0a4"), "serial": "BIO / 01",
		"title": ["INFECTED", "TRAIL"],
		"description": ["Infect the tiles", "around your unit."],
		"footer": "AREA CONTROL / 3x3",
	},
	"spy": {
		"icon": preload("res://art/cards/icons/eye.svg"),
		"color": Color("#c4a2ff"), "serial": "INTEL / 02",
		"title": ["SPY"],
		"description": ["Control an enemy", "for three turns."],
		"footer": "CONTROL / 3 TURNS",
	},
	"long_capture": {
		"icon": preload("res://art/cards/icons/bullseye-arrow.svg"),
		"color": Color("#ffb47b"), "serial": "STRIKE / 03",
		"title": ["LONG", "CAPTURE"],
		"description": ["Capture diagonally", "up to 2 tiles away."],
		"footer": "DIAGONAL / RANGE 2",
	},
}
const SHUFFLE_TIME := 1.25
const FLIP_TIME := 0.24
const REVEAL_HOLD := 3.6
const CYAN := Color("#83e1fa")
const INK := Color("#e9f2fb")
const MUTED := Color("#9cb1c4")
const CARD_FILL := Color("#132431")

var docked := false
var action_label := "Use power"
var compact := false
var shuffling := false
var face := ""
var elapsed := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE if compact or docked else Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if not docked and is_visible_in_tree() and (shuffling or (not compact and elapsed < SHUFFLE_TIME + FLIP_TIME)):
		elapsed += delta
		queue_redraw()


func start_shuffle() -> void:
	face = ""
	elapsed = 0.0
	shuffling = true
	show()


func reveal(power: String) -> void:
	face = power
	shuffling = false
	queue_redraw()


func _pixel_frame(rect: Rect2, edge: Color, fill: Color) -> void:
	# Stepped corners use solid rectangles aligned to whole pixels.
	var notch := 2.0 if compact else 4.0
	var border := 1.0 if compact else 2.0
	draw_rect(Rect2(rect.position + Vector2(notch, 0), rect.size - Vector2(notch * 2, 0)), edge)
	draw_rect(Rect2(rect.position + Vector2(0, notch), rect.size - Vector2(0, notch * 2)), edge)
	draw_rect(Rect2(rect.position + Vector2(notch, border), rect.size - Vector2(notch * 2, border * 2)), fill)
	draw_rect(Rect2(rect.position + Vector2(border, notch), rect.size - Vector2(border * 2, notch * 2)), fill)


func _center_text(text: String, x: float, y: float, px: int, color: Color) -> void:
	var width := MONO.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(MONO, Vector2(roundf(x - width / 2), roundf(y)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


func _card(center: Vector2, power: String = "", tint: Color = Color.WHITE, width: float = 1.0) -> void:
	var dimensions := Vector2(42, 60) if compact else Vector2(160, 240)
	# Transform the entire front together, including its icon and lettering, during the flip.
	draw_set_transform((center - Vector2(dimensions.x * width, dimensions.y) / 2).round(), 0, Vector2(width, 1))
	var data: Dictionary = POWERS.get(power, {})
	var tone: Color = data.get("color", CYAN)
	_pixel_frame(Rect2(Vector2(3, 4), dimensions), Color("#08131c") * tint, Color("#08131c") * tint)
	_pixel_frame(Rect2(Vector2.ZERO, dimensions), tone * tint, CARD_FILL * tint)
	if compact:
		var icon: Texture2D = data.get("icon", BACK_ICON)
		draw_texture_rect(icon, Rect2(Vector2(9, 18), Vector2(24, 24)), false, tone * tint)
		draw_line(Vector2(9, 8), Vector2(33, 8), tone * tint, 1)
		draw_line(Vector2(9, 51), Vector2(33, 51), tone * tint, 1)
	elif data.is_empty():
		for stripe in range(14, 232, 12):
			draw_line(Vector2(12, stripe), Vector2(148, stripe), Color("#1c3848") * tint, 2)
		draw_texture_rect(BACK_ICON, Rect2(Vector2(44, 55), Vector2(72, 72)), false, CYAN * tint)
		_center_text("HORIZON", 80, 159, 16, CYAN * tint)
		_center_text("ABILITY DECK", 80, 184, 11, MUTED * tint)
		_center_text("TACTICAL SYSTEMS", 80, 225, 9, MUTED * tint)
	else:
		draw_string(MONO, Vector2(12, 18), data.serial, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tone * tint)
		draw_line(Vector2(12, 26), Vector2(148, 26), Color("#344c5a") * tint, 1)
		for grid in range(0, 129, 16):
			draw_line(Vector2(16 + grid, 35), Vector2(16 + grid, 115), Color("#1e3443") * tint, 1)
		for grid in range(35, 116, 16):
			draw_line(Vector2(16, grid), Vector2(144, grid), Color("#1e3443") * tint, 1)
		draw_texture_rect(data.icon, Rect2(Vector2(44, 39), Vector2(72, 72)), false, tone * tint)
		var lines: Array = data.title
		for index in lines.size():
			_center_text(lines[index], 80, 140 + index * 18 + (9 if lines.size() == 1 else 0), 15, tone * tint)
		for index in data.description.size():
			_center_text(data.description[index], 80, 183 + index * 16, 11, INK * tint)
		draw_line(Vector2(12, 214), Vector2(148, 214), Color("#344c5a") * tint, 1)
		_center_text(data.footer, 80, 230, 9, MUTED * tint)
	draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	var center := (size / 2).round()
	if docked:
		var data: Dictionary = POWERS.get(face, {})
		var tone: Color = data.get("color", CYAN)
		_pixel_frame(Rect2(Vector2(4, 3), size - Vector2(8, 7)), tone, CARD_FILL)
		draw_string(MONO, Vector2(14, 20), data.get("serial", "ABILITY"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tone)
		draw_line(Vector2(14, 28), Vector2(size.x - 14, 28), Color("#344c5a"), 1)
		draw_texture_rect(data.get("icon", BACK_ICON), Rect2(Vector2(center.x - 24, 36), Vector2(48, 48)), false, tone)
		var titles: Array = data.get("title", [])
		for index in titles.size():
			_center_text(titles[index], center.x, 104 + index * 16 + (8 if titles.size() == 1 else 0), 13, tone)
		var description: Array = data.get("description", [])
		for index in description.size():
			_center_text(description[index], center.x, 141 + index * 14, 10, INK)
		draw_line(Vector2(14, 167), Vector2(size.x - 14, 167), Color("#344c5a"), 1)
		_center_text(action_label, center.x, 183, 11, CYAN if action_label in ["Use power", "Choose target"] else MUTED)
		return
	if not compact:
		draw_rect(Rect2(Vector2(6, 6), size), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(Vector2.ZERO, size), Color("#101f2d"))
		draw_rect(Rect2(Vector2.ZERO, size), CYAN, false, 2)
		for y in range(6, int(size.y), 6):
			draw_line(Vector2(2, y), Vector2(size.x - 2, y), Color(0.3, 0.7, 0.8, 0.045))
		_center_text("ABILITY DECK / SHUFFLING" if face.is_empty() else "ABILITY CARD / DRAWN", center.x, 30, 14, CYAN)
	if shuffling and (compact or elapsed < SHUFFLE_TIME):
		# Three matching backs trade places; animation never affects the gameplay RNG.
		var cycle := elapsed * 4.5
		for index in 3:
			var phase := cycle * TAU + index * TAU / 3
			var radius := 10.0 if compact else 57.0
			var offset := Vector2(roundf(sin(phase) * radius / 2) * 2, roundf(cos(phase) * radius / 6) * 2)
			_card(center + offset, "", Color(0.65, 0.85, 1.0) if index < 2 else Color.WHITE)
	else:
		var flip := clampf((elapsed - SHUFFLE_TIME) / FLIP_TIME, 0.0, 1.0)
		var width := 1.0 if compact else maxf(0.04, absf(cos(flip * PI)))
		for index in range(2, 0, -1):
			_card(center + Vector2(index * 3, index * 3), "", Color("#7d9aa8"))
		_card(center, face, Color.WHITE, width)
	if not compact:
		_center_text("SHUFFLING" + ".".repeat(int(elapsed * 5) % 4) if face.is_empty() else "YOUR POWER IS READY", center.x, size.y - 19, 13, MUTED)
