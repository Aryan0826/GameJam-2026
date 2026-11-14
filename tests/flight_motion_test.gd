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


func _make_flight(path: String) -> Node2D:
	var flight := load(path).instantiate() as Node2D
	flight.ship_spawn_position = Vector2(-40000, -40000)
	flight.sun_gravity_constant = 0.0
	flight.ship_linear_drag = 0.0
	root.add_child(flight)
	return flight


func _run() -> void:
	root.get_node("Expedition").reset_journey()
	for path in ["res://scenes/solar_system.tscn", "res://scenes/second_system.tscn"]:
		var flight := _make_flight(path)
		flight.set_process(false)
		flight.set_physics_process(false)
		_check(flight.ship_node.is_physics_interpolated_and_enabled(), "Flight body is interpolated between simulation ticks")
		_check(not flight.hud_control.is_physics_interpolated(), "Screen-space UI stays on the render clock")
		flight._ship_velocity = Vector2.RIGHT * flight.ship_boost_speed
		var maximum_drop := 0.0
		var first_speed := 0.0
		var step := 1.0 / 60.0
		for tick in 90:
			var before: float = flight._ship_velocity.length()
			flight._process_free_flight(step)
			var speed: float = flight._ship_velocity.length()
			maximum_drop = maxf(maximum_drop, before - speed)
			if tick == 0:
				first_speed = speed
		_check(first_speed > flight.ship_max_speed, "Releasing boost preserves speed through the first frame")
		_check(maximum_drop <= flight.ship_brake_power * step + 0.01, "Boost release never introduces an abrupt velocity cut")
		_check(is_equal_approx(flight._ship_velocity.length(), flight.ship_max_speed), "Boost release gradually settles at cruise speed")
		flight._ship_velocity = Vector2(600, 80)
		var coasting: Vector2 = flight._ship_velocity
		flight._process_free_flight(step)
		_check(flight._ship_velocity.is_equal_approx(coasting), "Coasting below the speed limit preserves momentum without input")
		flight._state = flight.ShipState.IN_ORBIT
		flight._break_orbit()
		_check(flight._ship_velocity.is_equal_approx(coasting), "Orbit departure carries existing momentum without a velocity kick")
		flight.ship_node.rotation = 0.0
		flight._ship_velocity = Vector2.RIGHT * flight.ship_max_speed
		flight._throttle = 1.0
		Input.action_press("ui_up")
		flight._process_free_flight(step)
		Input.action_release("ui_up")
		_check(flight._ship_velocity.length() <= flight.ship_max_speed + 0.01, "Sustained normal thrust still obeys its speed limit")
		flight._ship_velocity = Vector2.RIGHT * 600.0
		flight.camera.zoom = Vector2.ONE * flight.camera_cruise_zoom
		flight._update_camera(1.0)
		var whole_step: Vector2 = flight.camera.zoom
		_check(whole_step.x >= flight.camera_fast_zoom and whole_step.x <= flight.camera_cruise_zoom, "A long frame cannot overshoot the camera zoom range")
		flight.camera.zoom = Vector2.ONE * flight.camera_cruise_zoom
		flight._update_camera(0.5)
		flight._update_camera(0.5)
		_check(flight.camera.zoom.is_equal_approx(whole_step), "Zoom smoothing agrees across different update intervals")
		flight.queue_free()
		await process_frame
	await _check_rendered_camera()
	print("Flight motion: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)


func _view_center() -> Vector2:
	return root.get_canvas_transform().affine_inverse() * root.get_visible_rect().get_center()


func _check_rendered_camera() -> void:
	var previous_ticks := Engine.physics_ticks_per_second
	var previous_fps := Engine.max_fps
	# Deliberately render much faster than physics to expose frame/tick stepping.
	Engine.physics_ticks_per_second = 20
	Engine.max_fps = 120
	var flight := _make_flight("res://scenes/solar_system.tscn")
	flight.camera_cruise_zoom = 1.0
	flight.camera_fast_zoom = 1.0
	flight.camera.position_smoothing_enabled = false
	flight.camera.zoom = Vector2.ONE
	flight.ship_node.rotation = 0.0
	flight._ship_velocity = Vector2.RIGHT * 1000.0
	flight.get_node("World").reset_physics_interpolation()
	for frame in 15:
		await process_frame
	var last_ship: Vector2 = flight.ship_node.position
	var last_center := _view_center()
	var tick_changes := 0
	var between_tick_changes := 0
	var background_matches := true
	for frame in 75:
		await process_frame
		# SceneTreeTimer runs after nodes, so sample the completed camera/HUD frame.
		await create_timer(0.0).timeout
		var ship: Vector2 = flight.ship_node.position
		var center := _view_center()
		if ship.distance_to(last_ship) > 0.1:
			tick_changes += 1
		elif center.distance_to(last_center) > 0.1:
			between_tick_changes += 1
		var parallax: Vector2 = flight.starfield_rect.material.get_shader_parameter("camera_offset")
		background_matches = background_matches and parallax.distance_to(center) < 0.05
		last_ship = ship
		last_center = center
	_check(tick_changes >= 5, "The camera check samples real fixed-tick ship movement")
	_check(between_tick_changes > tick_changes * 2, "Rendered camera advances smoothly even between ship physics updates")
	_check(background_matches, "Starfield parallax follows the actual rendered camera")
	print("Camera at 20 physics ticks / 120 render FPS: %d tick steps, %d between-tick advances." % [tick_changes, between_tick_changes])
	flight.queue_free()
	await process_frame
	Engine.physics_ticks_per_second = previous_ticks
	Engine.max_fps = previous_fps
