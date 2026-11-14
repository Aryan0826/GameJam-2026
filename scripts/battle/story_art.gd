extends Control
## Original CC0 sprites by Emcee Flesher, staged with Godot shapes. No generated art.
const SHEET = preload("res://art/results/characters.png")

var role := "envoy"
var cinder := false
var outcome := -1
var lineup := false
var motion := true
var elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	if motion:
		elapsed += delta
		queue_redraw()


func _cell(character: String) -> Vector2:
	match character:
		"captain": return Vector2(0, 0)
		"navigator", "crew": return Vector2(0, 16)
		_: return Vector2(32 if cinder else 16, 0)


func _sprite(character: String, center: Vector2, side: float, tint: Color = Color.WHITE) -> void:
	draw_texture_rect_region(SHEET, Rect2((center - Vector2.ONE * side / 2).round(), Vector2.ONE * side), Rect2(_cell(character), Vector2(16, 16)), tint)


func _draw() -> void:
	if lineup:
		_draw_lineup()
		return
	var tint := Color("#ffc18c") if cinder and role == "envoy" else Color("#a0edb4") if role == "envoy" else Color("#83e1fa")
	var center := size * Vector2(0.5, 0.47)
	var side := floorf(minf(size.x * 0.78, size.y * 0.70) / 16) * 16
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0a1b22"))
	draw_rect(Rect2(Vector2.ZERO, size), Color(tint, 0.35), false, 1)
	for i in 5:
		var offset := float(i) * 6
		draw_ellipse_platform(Vector2(size.x * 0.5, size.y * 0.83 + offset), size.x * 0.40, Color(tint, 0.16 - float(i) * 0.025))
	var bob := sin(elapsed * 1.8) * 3 if motion else 0.0
	_sprite(role, center + Vector2(0, bob), maxf(16, side), Color(0.85, 1, 1, 0.95))
	for y in range(0, int(size.y), 4):
		draw_line(Vector2(1, y), Vector2(size.x - 1, y), Color(0.02, 0.09, 0.11, 0.18))
	for corner in [Vector2(7, 7), Vector2(size.x - 7, 7), Vector2(7, size.y - 7), size - Vector2(7, 7)]:
		var direction := Vector2(1 if corner.x < size.x / 2 else -1, 1 if corner.y < size.y / 2 else -1)
		draw_line(corner, corner + Vector2(12 * direction.x, 0), tint, 2)
		draw_line(corner, corner + Vector2(0, 12 * direction.y), tint, 2)


func draw_ellipse_platform(center: Vector2, radius: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for i in 49:
		var angle := float(i) * TAU / 48
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.12))
	draw_polyline(points, tint, 1.0, true)


func _draw_lineup() -> void:
	var tint := Color("#8ae0a4") if outcome == 1 else Color("#ff937e") if outcome == 0 else Color("#f8d587")
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("#070f1b"))
	for i in 50:
		var star := Vector2(fposmod(i * 113.0 + 37, w), fposmod(i * 47.0 + 13, h))
		draw_rect(Rect2(star, Vector2.ONE * (2 if i % 5 == 0 else 1)), Color("#c2dbef", 0.12 + float(i % 4) * 0.12))
	# Layered spotlights frame the winning crew.
	for i in range(7, 0, -1):
		var radius := 48.0 + float(i) * 24
		var cone := PackedVector2Array([Vector2(w * 0.5 - 25, 0), Vector2(w * 0.5 + 25, 0), Vector2(w * 0.5 + radius, h - 8), Vector2(w * 0.5 - radius, h - 8)])
		draw_colored_polygon(cone, Color(tint, 0.018))
	draw_ellipse_platform(Vector2(w * 0.5, h - 22), 210, Color(tint, 0.5))
	var hero := "captain" if outcome != 0 else "envoy"
	var friend := "navigator" if outcome != 0 else "envoy"
	var rise := minf(1.0, elapsed / 0.5) if motion else 1.0
	var lift := (1 - rise) * 22
	if outcome < 0:
		for team in 2:
			var center_x := w * (0.27 if team == 0 else 0.73)
			var character := "navigator" if team == 0 else "envoy"
			_sprite(character, Vector2(center_x - 70, h - 72 + lift), 96, Color(0.72, 0.81, 0.9))
			_sprite(character, Vector2(center_x + 70, h - 72 + lift), 96, Color(0.72, 0.81, 0.9))
			_sprite("captain" if team == 0 else "envoy", Vector2(center_x, h - 88 + lift), 144)
		return
	_sprite(friend, Vector2(w * 0.5 - 102, h - 78 + lift), 112, Color(0.72, 0.81, 0.9))
	_sprite(friend, Vector2(w * 0.5 + 102, h - 78 + lift), 112, Color(0.72, 0.81, 0.9))
	_sprite(hero, Vector2(w * 0.5, h - 99 + lift), 176)
	var other := "envoy" if outcome != 0 else "captain"
	_sprite(other, Vector2(66, h - 50), 64, Color(0.6, 0.67, 0.8, 0.65))
	_sprite(other, Vector2(w - 66, h - 50), 64, Color(0.6, 0.67, 0.8, 0.65))
