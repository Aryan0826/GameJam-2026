extends Control

## Tactical Minimap / Solar System Radar Scanner

@export var world_radius: float = 6500.0
@export var radar_radius: float = 70.0

@onready var solar_system: Node2D = get_tree().current_scene

var _sweep_angle: float = 0.0

func _process(delta: float) -> void:
	_sweep_angle += 1.8 * delta
	if _sweep_angle > TAU:
		_sweep_angle -= TAU
	queue_redraw()

func _draw() -> void:
	var center = size * 0.5

	# 1. Background radar disc
	draw_circle(center, radar_radius, Color(0.03, 0.06, 0.12, 0.75))
	draw_arc(center, radar_radius, 0.0, TAU, 48, Color(0.2, 0.7, 0.95, 0.5), 1.5)
	draw_arc(center, radar_radius * 0.5, 0.0, TAU, 32, Color(0.2, 0.7, 0.95, 0.15), 1.0)

	# 2. Radar sweep line
	var sweep_end = center + Vector2.from_angle(_sweep_angle) * radar_radius
	draw_line(center, sweep_end, Color(0.3, 0.9, 1.0, 0.25), 1.5)

	if not solar_system:
		return

	var sun = solar_system.get_node_or_null("World/Sun")
	var planet = solar_system.get_node_or_null("World/Planet")
	var ship = solar_system.get_node_or_null("World/PlayerShip")

	var scale_factor = radar_radius / world_radius

	# 3. Sun marker
	draw_circle(center, 4.0, Color(1.0, 0.85, 0.2, 0.95))

	# 4. Planetary orbit guideline
	if planet and sun:
		var orbit_r = (planet.position - sun.position).length() * scale_factor
		draw_arc(center, orbit_r, 0.0, TAU, 48, Color(0.2, 0.6, 0.85, 0.25), 1.0)

		# Planet marker
		var planet_pos = center + (planet.position - sun.position) * scale_factor
		draw_circle(planet_pos, 3.5, Color(0.35, 0.9, 1.0, 0.95))

	# 5. Player ship marker
	if ship and sun:
		var ship_offset = (ship.position - sun.position) * scale_factor
		if ship_offset.length() < radar_radius:
			var ship_pt = center + ship_offset
			var heading = ship.rotation
			# Draw small ship chevron
			var p1 = ship_pt + Vector2.from_angle(heading) * 6.0
			var p2 = ship_pt + Vector2.from_angle(heading + 2.5) * 4.5
			var p3 = ship_pt + Vector2.from_angle(heading - 2.5) * 4.5
			draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(1.0, 1.0, 1.0, 0.95))
