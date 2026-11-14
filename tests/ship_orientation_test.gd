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
		for angle in [0.0, PI / 4.0, PI / 2.0, 3.0 * PI / 4.0, PI, -3.0 * PI / 4.0, -PI / 2.0, -PI / 4.0, 0.0]:
			ship.rotation = angle
			flight._process(0.0)
			var forward := Vector2.from_angle(angle)
			var nose := sprite.global_transform.basis_xform(Vector2.UP).normalized()
			_check(nose.is_equal_approx(forward), "Top-down ship nose follows the heading, including vertical flight")
			_check(not sprite.flip_h and not sprite.flip_v, "Top-down hull rotates continuously without mirroring")
			for flame: Sprite2D in thrusters.get_children():
				var exhaust := flame.global_transform.basis_xform(Vector2.DOWN).normalized()
				var mount_offset := flame.global_position - ship.global_position
				_check(exhaust.is_equal_approx(-forward) and mount_offset.dot(forward) < 0.0,
					"Each exhaust stays behind the ship and points opposite thrust")
			_check(is_equal_approx(ship.rotation, angle) and flight._ship_velocity == velocity, "Presentation preserves heading and momentum")
		flight.queue_free()
		await process_frame
	print("Ship orientation: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)
