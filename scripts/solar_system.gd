class_name SolarSystem
extends Node2D

## 2D Solar System Exploration Scene
## Features an expanded 5000px solar system, a colossal central Sun with realistic gravity,
## gradual spacecraft momentum accumulation (Newtonian inertia), planetary gravitational pull,
## graceful slow orbital insertion, and transition to the game board after 2 seconds of stable orbit.

signal orbit_entered
signal scene_transition_started

enum ShipState {
	FREE_FLIGHT,
	PULLING_TO_ORBIT,
	IN_ORBIT,
	TRANSITIONING
}

@export_group("Scene Navigation")
@export_file("*.tscn") var next_scene_path: String = "res://main.tscn"
@export var orbit_dwell_duration: float = 2.0

@export_group("Solar Mechanics")
@export var sun_gravity_constant: float = 120000.0 # gravitational pull across the deep space system
@export var sun_min_dist: float = 760.0 # solar thermal repulsion buffer outside the enlarged star
@export var planet_orbit_radius: float = 5000.0 # vast solar system radius
@export var planet_orbit_speed: float = 0.025 # radians/sec (~250s full orbit)
@export var planet_gravity_influence_radius: float = 1000.0 # planetary gravitational well
@export var planet_gravity_strength: float = 28000.0 # planet's own inward gravitational pull
@export var planet_capture_radius: float = 650.0 # dotted proximity boundary
@export var planet_stable_orbit_radius: float = 420.0 # orbit stays outside the 300px planet radius
@export var planet_orbit_rot_speed: float = 0.45 # radians/sec (~14s per planetary orbit)
@export var orbit_absorption_speed: float = 38.0 # slightly quicker insertion while preserving the smooth curve
@export_range(1.0, 1000.0, 1.0) var orbit_capture_accel: float = 260.0 # gradual change in orbital velocity

@export_group("Body Rotation")
@export_range(1.0, 120.0, 0.5) var sun_rotation_duration: float = 48.0
@export_range(1.0, 120.0, 0.5) var planet_rotation_duration: float = 32.0

@export_group("Ship Handling (Realistic Mechanics)")
@export var ship_thrust_accel: float = 300.0 # reduced acceleration with the original throttle response
@export var ship_boost_accel: float = 520.0
@export var ship_turn_speed: float = 3.2 # radians/sec
@export var ship_max_speed: float = 1000.0
@export var ship_boost_speed: float = 1400.0
@export var ship_linear_drag: float = 0.015 # near-zero space friction: true Newtonian coasting
@export var ship_brake_power: float = 320.0 # retro-thrusters

# Node references
@onready var sun_node: Node2D = $World/Sun
@onready var sun_sprite: Sprite2D = $World/Sun/SunSprite
@onready var sun_glow: Node2D = $World/Sun/SunGlow
@onready var planet_node: Node2D = $World/Planet
@onready var planet_sprite: Sprite2D = $World/Planet/PlanetSprite
@onready var planet_zone: Node2D = $World/Planet/OrbitZone
@onready var ship_node: CharacterBody2D = $World/PlayerShip
@onready var ship_sprite: Sprite2D = $World/PlayerShip/ShipSprite
@onready var engine_thrusters: Node2D = $World/PlayerShip/EngineThrusters
@onready var camera: Camera2D = $World/Camera2D
@onready var starfield_rect: ColorRect = $StarfieldLayer/StarfieldBackground
@onready var hud_control: Control = $HUDLayer/HUD
@onready var orbit_hud: Control = $HUDLayer/HUD/OrbitHUD
@onready var orbit_title_label: Label = $HUDLayer/HUD/OrbitHUD/VBox/TitleLabel
@onready var orbit_timer_label: Label = $HUDLayer/HUD/OrbitHUD/VBox/TimerLabel
@onready var orbit_progress_bar: ProgressBar = $HUDLayer/HUD/OrbitHUD/VBox/ProgressBar
@onready var orbit_hint_label: Label = $HUDLayer/HUD/OrbitHUD/VBox/SubHint
@onready var speed_label: Label = $HUDLayer/HUD/FlightInfo/SpeedLabel
@onready var dist_sun_label: Label = $HUDLayer/HUD/FlightInfo/DistSunLabel
@onready var dist_planet_label: Label = $HUDLayer/HUD/FlightInfo/DistPlanetLabel
@onready var screen_fade: ColorRect = $HUDLayer/ScreenFade
@onready var sun_pointer: Control = $HUDLayer/HUD/Radar/SunPointer
@onready var planet_pointer: Control = $HUDLayer/HUD/Radar/PlanetPointer
@onready var minimap: Control = $HUDLayer/HUD/Minimap

# Runtime state
var _state: ShipState = ShipState.FREE_FLIGHT
var _ship_velocity: Vector2 = Vector2.ZERO
var _throttle: float = 0.0 # smooth throttle spool-up for gradual acceleration
var _planet_orbit_angle: float = 0.60
var _ship_planet_angle: float = 0.0
var _ship_orbit_dist: float = 650.0
var _orbit_radial_speed: float = 0.0
var _orbit_tangential_speed: float = 0.0
var _orbit_direction: float = 1.0
var _orbit_timer: float = 0.0
var _sun_anim_time: float = 0.0
var _planet_anim_time: float = 0.0
var _thruster_anim_time: float = 0.0


func _ready() -> void:
	for body: Sprite2D in [sun_sprite, planet_sprite]:
		var rotation_material := body.material as ShaderMaterial
		rotation_material.set_shader_parameter("frame_grid", Vector2(body.hframes, body.vframes))
	planet_zone.set("capture_radius", planet_capture_radius)
	planet_zone.set("stable_orbit_radius", planet_stable_orbit_radius)

	# Initial positions in expanded solar system
	sun_node.position = Vector2.ZERO
	_update_planet_position(0.0)

	# Place ship in outer quadrant heading inward
	ship_node.position = Vector2(3400.0, 3100.0)
	ship_node.rotation = (planet_node.position - ship_node.position).angle()
	_ship_velocity = Vector2.from_angle(ship_node.rotation) * 180.0

	# Initial UI states
	if orbit_hud:
		orbit_hud.visible = false
		orbit_hud.modulate.a = 0.0
	engine_thrusters.visible = false

	# Fade in from black on entry
	if screen_fade:
		screen_fade.visible = true
		screen_fade.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(screen_fade, "modulate:a", 0.0, 0.6)
		tween.tween_callback(func(): screen_fade.visible = false)


func _process(delta: float) -> void:
	_update_thrusters(delta)
	_sun_anim_time = fposmod(_sun_anim_time + delta, sun_rotation_duration)
	_planet_anim_time = fposmod(_planet_anim_time + delta, planet_rotation_duration)
	_update_body_rotation(sun_sprite, _sun_anim_time / sun_rotation_duration)
	_update_body_rotation(planet_sprite, _planet_anim_time / planet_rotation_duration)

	# Smooth camera follow and dynamic velocity-based zoom
	if camera and ship_node:
		camera.position = ship_node.position
		var speed_ratio = clampf(_ship_velocity.length() / ship_max_speed, 0.0, 1.0)
		var target_zoom = lerpf(0.95, 0.60, speed_ratio)
		camera.zoom = camera.zoom.lerp(Vector2(target_zoom, target_zoom), 2.2 * delta)

	# Starfield parallax
	if starfield_rect and starfield_rect.material is ShaderMaterial:
		starfield_rect.material.set_shader_parameter("camera_offset", ship_node.position)

	# Redraw custom visual components
	if sun_glow:
		sun_glow.queue_redraw()
	if planet_zone:
		planet_zone.queue_redraw()
	if minimap:
		minimap.queue_redraw()

	_update_hud(delta)


func _update_body_rotation(sprite: Sprite2D, progress: float) -> void:
	var frame_position := progress * sprite.hframes * sprite.vframes
	sprite.frame = floori(frame_position)
	var rotation_material := sprite.material as ShaderMaterial
	rotation_material.set_shader_parameter("frame_index", float(sprite.frame))
	rotation_material.set_shader_parameter("frame_blend", frame_position - sprite.frame)


func _physics_process(delta: float) -> void:
	# 1. Update Planet's orbit around the Sun
	_update_planet_position(delta)

	# 2. Handle Ship state machine
	match _state:
		ShipState.FREE_FLIGHT:
			_process_free_flight(delta)
		ShipState.PULLING_TO_ORBIT:
			_process_pulling_to_orbit(delta)
		ShipState.IN_ORBIT:
			_process_in_orbit(delta)
		ShipState.TRANSITIONING:
			_process_transitioning(delta)


func _update_planet_position(delta: float) -> void:
	_planet_orbit_angle += planet_orbit_speed * delta
	if _planet_orbit_angle > TAU:
		_planet_orbit_angle -= TAU
	planet_node.position = sun_node.position + Vector2(
		cos(_planet_orbit_angle),
		sin(_planet_orbit_angle)
	) * planet_orbit_radius


func _get_planet_velocity() -> Vector2:
	return Vector2(
		-sin(_planet_orbit_angle),
		cos(_planet_orbit_angle)
	) * (planet_orbit_radius * planet_orbit_speed)


func _is_accelerating() -> bool:
	return Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W)


func _update_thrusters(delta: float) -> void:
	var entering_orbit := _state == ShipState.PULLING_TO_ORBIT
	engine_thrusters.visible = entering_orbit or (_state == ShipState.FREE_FLIGHT and _is_accelerating())
	if not engine_thrusters.visible:
		_thruster_anim_time = 0.0
		return

	_thruster_anim_time += delta
	var boosting := not entering_orbit and (Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SPACE))
	var boost_scale := 1.3 if boosting else 1.0
	for i in engine_thrusters.get_child_count():
		var flame := engine_thrusters.get_child(i) as Sprite2D
		var flicker := 1.0 + sin(_thruster_anim_time * 45.0 + i * 1.7) * 0.12
		# Stretch around the flame's right edge to keep it attached to the nozzle.
		flame.scale.x = flame.scale.y * 1.4 * flicker * boost_scale


func _process_free_flight(delta: float) -> void:
	var turn_input: float = 0.0
	var thrust_target: float = 0.0
	var brake_input: float = 0.0

	# Steer left/right
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		turn_input -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		turn_input += 1.0

	# Forward thruster
	if _is_accelerating():
		thrust_target = 1.0

	# Retro brake thrusters
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		brake_input = 1.0

	# Warp / Boost modifies acceleration while W / Up is held.
	var is_boosting: bool = Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SPACE)

	var cur_accel = ship_boost_accel if is_boosting else ship_thrust_accel
	var cur_max_speed = ship_boost_speed if is_boosting else ship_max_speed

	# Apply rotation
	ship_node.rotation += turn_input * ship_turn_speed * delta

	# Facing vector
	var forward: Vector2 = Vector2.from_angle(ship_node.rotation)

	# Real mechanics: Gradual throttle build-up & velocity accumulation
	_throttle = move_toward(_throttle, thrust_target, 1.4 * delta) if thrust_target > 0.0 else 0.0
	if _throttle > 0.01:
		_ship_velocity += forward * cur_accel * _throttle * delta

	# Retro brake: gradual deceleration
	if brake_input > 0.0:
		_ship_velocity = _ship_velocity.move_toward(Vector2.ZERO, ship_brake_power * brake_input * delta)

	# Near-zero space friction: authentic Newtonian coasting
	_ship_velocity = _ship_velocity.move_toward(Vector2.ZERO, ship_linear_drag * _ship_velocity.length() * delta)

	# Speed cap
	if _ship_velocity.length() > cur_max_speed:
		_ship_velocity = _ship_velocity.normalized() * cur_max_speed

	# --- 1. Sun Gravity: continuous cosmic attraction to massive star ---
	var to_sun: Vector2 = sun_node.position - ship_node.position
	var dist_sun: float = to_sun.length()
	if dist_sun > 10.0:
		var sun_pull: float = sun_gravity_constant / maxf(dist_sun, 450.0)
		_ship_velocity += to_sun.normalized() * sun_pull * delta

		# Sun core repulsion buffer: safely pushes ship away if too close to surface
		if dist_sun < sun_min_dist:
			_ship_velocity += (-to_sun.normalized()) * (sun_min_dist - dist_sun) * 14.0 * delta

	# --- 2. Planet Gravitational Well: planet exerts its own pull when close ---
	var to_planet: Vector2 = planet_node.position - ship_node.position
	var dist_planet: float = to_planet.length()

	if dist_planet < planet_gravity_influence_radius:
		var planet_pull: float = planet_gravity_strength / maxf(dist_planet, 120.0)
		_ship_velocity += to_planet.normalized() * planet_pull * delta

	# Apply velocity
	ship_node.velocity = _ship_velocity
	ship_node.move_and_slide()
	_ship_velocity = ship_node.velocity

	# Complete the free-flight step before handing its position and momentum to orbit.
	if not _is_accelerating() and _can_capture_orbit():
		_begin_orbital_capture()


func _can_capture_orbit() -> bool:
	var offset := ship_node.position - planet_node.position
	var distance := offset.length()
	if distance > planet_capture_radius or distance < 1.0:
		return false
	var relative_velocity := _ship_velocity - _get_planet_velocity()
	var radial_speed := relative_velocity.dot(offset / distance)
	# Fast flybys and ships already departing remain under the player's control.
	if relative_velocity.length() > 340.0 or radial_speed > orbit_absorption_speed:
		return false

	var planet_size := planet_sprite.get_rect().size * planet_sprite.scale.abs()
	var ship_size := ship_sprite.get_rect().size * ship_sprite.global_scale.abs()
	var clearance_radius := maxf(planet_size.x, planet_size.y) * 0.5 + ship_size.length() * 0.5 + 20.0
	var inward_speed := maxf(0.0, -radial_speed)
	var stopping_distance := inward_speed * inward_speed / (2.0 * orbit_capture_accel)
	return distance > clearance_radius + stopping_distance


func _begin_orbital_capture() -> void:
	_state = ShipState.PULLING_TO_ORBIT
	_throttle = 0.0
	_update_thrusters(0.0)

	var rel: Vector2 = ship_node.position - planet_node.position
	_ship_planet_angle = rel.angle()
	_ship_orbit_dist = rel.length()
	var radial := rel.normalized()
	var tangent := Vector2(-radial.y, radial.x)
	var relative_velocity := _ship_velocity - _get_planet_velocity()
	_orbit_radial_speed = relative_velocity.dot(radial)
	_orbit_tangential_speed = relative_velocity.dot(tangent)
	# Follow the incoming angular momentum, including counterclockwise approaches.
	if absf(_orbit_tangential_speed) > 5.0:
		_orbit_direction = signf(_orbit_tangential_speed)
	else:
		_orbit_direction = -1.0 if Vector2.from_angle(ship_node.rotation).dot(tangent) < 0.0 else 1.0
	_orbit_timer = 0.0

	orbit_title_label.text = "ENTERING PLANETARY ORBIT"
	orbit_timer_label.text = "SETTLING INTO ORBIT"
	orbit_hint_label.text = "[W / UP] Resume flight"
	orbit_progress_bar.value = 0.0
	_show_orbit_hud(true)


func _process_pulling_to_orbit(delta: float) -> void:
	# Break orbit if player engages thrusters
	if _is_accelerating():
		_break_orbit()
		_process_free_flight(delta)
		return

	_advance_orbit(delta)

	# Arrival requires a settled trajectory, not merely crossing the orbit line.
	var target_speed := _orbit_direction * planet_stable_orbit_radius * planet_orbit_rot_speed
	var radius_settled := absf(_ship_orbit_dist - planet_stable_orbit_radius) < 3.0
	var speed_settled := absf(_orbit_radial_speed) < 3.0 and absf(_orbit_tangential_speed - target_speed) < 3.0
	if radius_settled and speed_settled:
		_state = ShipState.IN_ORBIT
		_update_thrusters(0.0)
		_orbit_timer = 0.0
		orbit_title_label.text = "PLANETARY ORBIT ESTABLISHED"
		orbit_timer_label.text = "DESCENT IN: %.1fs" % orbit_dwell_duration
		orbit_hint_label.text = "[SPACE / ENTER] Land Now  •  [W / UP] Resume flight"
		orbit_entered.emit()


func _advance_orbit(delta: float) -> void:
	var previous_radius := _ship_orbit_dist
	var previous_radial_speed := _orbit_radial_speed
	var previous_tangential_speed := _orbit_tangential_speed
	var target_radial_speed := clampf((planet_stable_orbit_radius - _ship_orbit_dist) * 1.2, -orbit_absorption_speed, orbit_absorption_speed)
	var target_tangential_speed := _orbit_direction * planet_stable_orbit_radius * planet_orbit_rot_speed
	_orbit_radial_speed = move_toward(_orbit_radial_speed, target_radial_speed, orbit_capture_accel * delta)
	_orbit_tangential_speed = move_toward(_orbit_tangential_speed, target_tangential_speed, orbit_capture_accel * delta)

	# Integrate the existing motion while gradually circularizing the trajectory.
	_ship_orbit_dist += (previous_radial_speed + _orbit_radial_speed) * 0.5 * delta
	var mean_radius := maxf(1.0, (previous_radius + _ship_orbit_dist) * 0.5)
	_ship_planet_angle = wrapf(_ship_planet_angle + (previous_tangential_speed + _orbit_tangential_speed) * 0.5 / mean_radius * delta, -PI, PI)
	var radial := Vector2.from_angle(_ship_planet_angle)
	var tangent := Vector2(-radial.y, radial.x)
	var relative_velocity := radial * _orbit_radial_speed + tangent * _orbit_tangential_speed
	ship_node.position = planet_node.position + radial * _ship_orbit_dist
	_ship_velocity = _get_planet_velocity() + relative_velocity
	ship_node.velocity = _ship_velocity

	if relative_velocity.length_squared() > 1.0:
		ship_node.rotation = rotate_toward(ship_node.rotation, relative_velocity.angle(), minf(ship_turn_speed, 1.6) * delta)


func _process_in_orbit(delta: float) -> void:
	# Break orbit if player thrusts out
	if _is_accelerating():
		_break_orbit()
		_process_free_flight(delta)
		return

	# Use the same motion through insertion, stable orbit, and descent.
	_advance_orbit(delta)

	# Instant land / skip shortcut
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_ENTER):
		_trigger_game_transition()
		return

	# Advance the descent countdown once the orbit has settled.
	_orbit_timer += delta
	var progress = clampf(_orbit_timer / orbit_dwell_duration, 0.0, 1.0)
	if orbit_progress_bar:
		orbit_progress_bar.value = progress * 100.0

	var time_left = maxf(0.0, orbit_dwell_duration - _orbit_timer)
	if orbit_timer_label:
		orbit_timer_label.text = "DESCENT IN: %.1fs" % time_left

	if _orbit_timer >= orbit_dwell_duration:
		_trigger_game_transition()


func _break_orbit() -> void:
	_state = ShipState.FREE_FLIGHT
	_orbit_timer = 0.0
	_throttle = 0.5
	_show_orbit_hud(false)

	# Preserve the actual orbital momentum and the existing forward departure boost.
	_ship_velocity += Vector2.from_angle(ship_node.rotation) * 260.0
	ship_node.velocity = _ship_velocity


func _trigger_game_transition() -> void:
	if _state == ShipState.TRANSITIONING:
		return
	_state = ShipState.TRANSITIONING
	engine_thrusters.visible = false
	scene_transition_started.emit()

	if orbit_timer_label:
		orbit_timer_label.text = "DESCENT INITIATED • ENTERING ARENA"

	if screen_fade:
		screen_fade.visible = true
		screen_fade.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(screen_fade, "modulate:a", 1.0, 0.6)
		tween.tween_callback(func():
			if not next_scene_path.is_empty():
				get_tree().change_scene_to_file(next_scene_path)
		)
	else:
		if not next_scene_path.is_empty():
			get_tree().change_scene_to_file(next_scene_path)


func _process_transitioning(delta: float) -> void:
	_advance_orbit(delta)


func _show_orbit_hud(visible_state: bool) -> void:
	if not orbit_hud:
		return
	orbit_hud.visible = true
	var tween = create_tween()
	var target_alpha = 1.0 if visible_state else 0.0
	tween.tween_property(orbit_hud, "modulate:a", target_alpha, 0.3)
	if not visible_state:
		tween.tween_callback(func(): orbit_hud.visible = false)


func _update_hud(_delta: float) -> void:
	if not ship_node:
		return

	var dist_sun = ship_node.position.distance_to(sun_node.position)
	var dist_planet = ship_node.position.distance_to(planet_node.position)
	var speed_val = _ship_velocity.length()

	if speed_label:
		speed_label.text = "VELOCITY: %d KM/S   THROTTLE: %d%%" % [int(speed_val), int(_throttle * 100.0)]
	if dist_sun_label:
		dist_sun_label.text = "SOLAR CORE: %d KM" % int(dist_sun)
	if dist_planet_label:
		dist_planet_label.text = "KALYPSO: %d KM" % int(dist_planet)

	_update_tracking_marker(sun_pointer, sun_node.position, Color(1.0, 0.85, 0.2))
	_update_tracking_marker(planet_pointer, planet_node.position, Color(0.3, 0.85, 1.0))


func _update_tracking_marker(marker: Control, target_pos: Vector2, tint_col: Color) -> void:
	if not marker or not camera:
		return

	var vp_size = get_viewport_rect().size
	var cam_pos = camera.position
	var to_target = target_pos - cam_pos

	var margin = 48.0
	var half_w = (vp_size.x * 0.5) - margin
	var half_h = (vp_size.y * 0.5) - margin

	if absf(to_target.x) < half_w and absf(to_target.y) < half_h:
		marker.visible = false
		return

	marker.visible = true
	marker.modulate = tint_col

	var screen_dir = to_target.normalized()
	var scale_factor = minf(
		half_w / maxf(absf(screen_dir.x), 0.0001),
		half_h / maxf(absf(screen_dir.y), 0.0001)
	)
	var edge_offset = screen_dir * scale_factor
	marker.position = (vp_size * 0.5) + edge_offset

	var chevron = marker.get_node_or_null("Chevron")
	if chevron:
		chevron.rotation = screen_dir.angle()
	else:
		marker.rotation = screen_dir.angle()
