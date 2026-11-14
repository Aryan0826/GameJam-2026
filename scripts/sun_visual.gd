extends Node2D

## Visual radiant corona and atmospheric glow for the colossal central Star

@export var glow_radius: float = 260.0
@export var glow_color: Color = Color(1.0, 0.72, 0.15, 0.20)
@export var inner_color: Color = Color(1.0, 0.88, 0.35, 0.38)
@export var flare_color: Color = Color(1.0, 0.82, 0.25, 0.20)

var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var pulse: float = sin(_time * 2.0) * 0.05 + 1.0
	var r: float = glow_radius * pulse

	# Outer soft stellar corona
	draw_circle(Vector2.ZERO, r * 1.35, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.4))
	draw_circle(Vector2.ZERO, r, glow_color)
	draw_circle(Vector2.ZERO, r * 0.7, inner_color)

	# Faint radiating solar flare rays
	var spike_count: int = 16
	var angle_step: float = TAU / float(spike_count)
	for i in range(spike_count):
		var angle: float = (float(i) * angle_step) + (_time * 0.1)
		var flare_len: float = r * (1.12 + 0.16 * sin(_time * 3.5 + float(i) * 1.5))
		var pt1 = Vector2.from_angle(angle) * (r * 0.6)
		var pt2 = Vector2.from_angle(angle) * flare_len
		draw_line(pt1, pt2, flare_color, 3.0)
