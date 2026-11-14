extends Node2D

## Dotted orbit guideline for the planet's trajectory around the Sun

@export var orbit_radius: float = 5000.0
@export var orbit_color: Color = Color(0.35, 0.65, 0.95, 0.25)

func _draw() -> void:
	# Subtle, clean dotted circular trajectory
	var segments: int = 720
	var step: float = TAU / float(segments)
	for i in range(segments):
		if i % 2 == 0:
			var a1 = float(i) * step
			var a2 = float(i) * step + (step * 0.45)
			var p1 = Vector2.from_angle(a1) * orbit_radius
			var p2 = Vector2.from_angle(a2) * orbit_radius
			draw_line(p1, p2, orbit_color, 1.0)
