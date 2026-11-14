extends Node2D

## Clean dotted circular guides for proximity radius and planetary orbit

@export var capture_radius: float = 320.0
@export var stable_orbit_radius: float = 175.0
@export var proximity_color: Color = Color(0.3, 0.75, 1.0, 0.28)
@export var orbit_color: Color = Color(0.25, 0.9, 0.7, 0.32)

func _draw() -> void:
	# 1. Dotted line for the radius proximity
	_draw_dotted_circle(capture_radius, proximity_color, 48)

	# 2. Dotted line for the stable orbit around the planet
	_draw_dotted_circle(stable_orbit_radius, orbit_color, 36)


func _draw_dotted_circle(radius: float, col: Color, segments: int) -> void:
	var step: float = TAU / float(segments)
	for i in range(segments):
		if i % 2 == 0:
			var a1 = float(i) * step
			var a2 = float(i) * step + (step * 0.45)
			var p1 = Vector2.from_angle(a1) * radius
			var p2 = Vector2.from_angle(a2) * radius
			draw_line(p1, p2, col, 1.0)
