extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	root.get_node("Expedition").reset_journey()
	for path in ["res://scenes/solar_system.tscn", "res://scenes/second_system.tscn"]:
		var flight := load(path).instantiate() as Node2D
		root.add_child(flight)
		flight.set_process(false)
		flight.set_physics_process(false)
		var ship: CharacterBody2D = flight.ship_node
		var sprite: Sprite2D = flight.ship_sprite
		var thrusters: Node2D = flight.engine_thrusters
		var velocity: Vector2 = flight._ship_velocity
		var mount: Vector2 = flight._thruster_mount
		for angle in [0.0, PI / 4.0, 3.0 * PI / 4.0, PI, -3.0 * PI / 4.0, -PI / 4.0, 0.0]:
			ship.rotation = angle
			flight._update_ship_orientation()
			var forward := Vector2.from_angle(angle)
			var cockpit_up := sprite.global_transform.basis_xform(Vector2.DOWN if sprite.flip_v else Vector2.UP)
			_check(cockpit_up.y < 0.0, "Cockpit stays above the hull through left and right turns")
			_check(sprite.global_transform.x.normalized().is_equal_approx(forward), "Nose follows the heading after mirroring")
			var expected_y := -mount.y if forward.x < 0.0 else mount.y
			_check(is_equal_approx(thrusters.position.y, expected_y)
				and thrusters.scale.y == (-1.0 if forward.x < 0.0 else 1.0), "Both exhausts stay attached to the mirrored engines")
			_check(is_equal_approx(ship.rotation, angle) and flight._ship_velocity == velocity, "Visual correction preserves heading and momentum")
		flight.queue_free()
		await process_frame
	print("Ship orientation: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)
