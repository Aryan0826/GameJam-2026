class_name SolarSystem
extends Node2D

## 2D Solar System Exploration Scene
## Features four orbiting planets, a colossal central Sun with realistic gravity,
## gradual spacecraft momentum accumulation (Newtonian inertia), planetary gravitational pull,
## graceful slow orbital insertion, and transition to the game board after 2 seconds of stable orbit.

signal orbit_entered
signal scene_transition_started

const OrbitingPlanetBody = preload("res://scripts/orbiting_planet.gd")
const ExpeditionState = preload("res://scripts/expedition.gd")

enum ShipState {
	FREE_FLIGHT,
	PULLING_TO_ORBIT,
	IN_ORBIT,
	TRANSITIONING
}

@export_group("Scene Navigation")
@export_file("*.tscn") var next_scene_path: String = "res://main.tscn"
@export var orbit_dwell_duration: float = 2.0

@export_group("Planetary System")
@export var system_index: int = 0
@export var system_star_texture: Texture2D
@export var system_planet_texture: Texture2D
@export var system_planet_frame_grid: Vector2i = Vector2i(10, 6)

@export_group("Flight Entry")
@export var ship_spawn_position: Vector2 = Vector2(-5200.0, 3800.0)

@export_group("Flight Camera")
@export_range(0.1, 2.0, 0.01) var camera_cruise_zoom: float = 0.65
@export_range(0.1, 2.0, 0.01) var camera_fast_zoom: float = 0.45

@export_group("Solar Mechanics")
@export var sun_gravity_constant: float = 120000.0 # gravitational pull across the deep space system
@export var sun_min_dist: float = 760.0 # solar thermal repulsion buffer outside the enlarged star
@export var planet_orbit_radius: float = 5600.0 # home occupies the second solar orbit
@export var planet_orbit_speed: float = 0.022 # radians/sec (~286s full orbit)
@export var planet_gravity_influence_radius: float = 1000.0 # planetary gravitational well
@export var planet_gravity_strength: float = 28000.0 # planet's own inward gravitational pull
@export var planet_capture_radius: float = 650.0 # dotted proximity boundary
@export var planet_stable_orbit_radius: float = 420.0 # orbit stays outside the 255px planet radius
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
@onready var expedition: ExpeditionState = get_node("/root/Expedition")
@onready var sun_node: Node2D = $World/Sun
@onready var sun_sprite: Sprite2D = $World/Sun/SunSprite
@onready var sun_glow: Node2D = $World/Sun/SunGlow
@onready var planet_node: Node2D = $World/Planet
@onready var planet_sprite: Sprite2D = $World/Planet/PlanetSprite
@onready var planet_zone: Node2D = $World/Planet/OrbitZone
@onready var additional_planets: Node2D = $World/AdditionalPlanets
@onready var cinder: OrbitingPlanetBody = $World/AdditionalPlanets/Cinder
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
@onready var gravity_status_label: Label = $HUDLayer/HUD/FlightInfo/GravityLabel
@onready var screen_fade: ColorRect = $HUDLayer/ScreenFade
@onready var sun_pointer: Control = $HUDLayer/HUD/Radar/SunPointer
@onready var planet_pointer: Control = $HUDLayer/HUD/Radar/PlanetPointer
@onready var minimap: Control = $HUDLayer/HUD/Minimap
@onready var destinations: PanelContainer = $HUDLayer/HUD/Destinations

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
var _planet_name: String = "KALYPSO"
var _star_name: String = "SOLAR CORE"
var _star_color: Color = Color(1.0, 0.85, 0.2)
var _course_target: Node2D
var _orbit_target: Node2D


func _ready() -> void:
	expedition.enter_system(system_index)
	var system_data: Dictionary = expedition.current_system_data()
	_planet_name = system_data.planet_name
	_star_name = system_data.star_name
	_star_color = system_data.star_color
	if system_star_texture:
		sun_sprite.texture = system_star_texture
		sun_glow.set("glow_color", Color(_star_color, 0.2))
		sun_glow.set("inner_color", Color(_star_color.lightened(0.3), 0.38))
		sun_glow.set("flare_color", Color(_star_color, 0.2))
	if system_planet_texture:
		planet_sprite.texture = system_planet_texture
		planet_sprite.hframes = system_planet_frame_grid.x
		planet_sprite.vframes = system_planet_frame_grid.y
	$World/Sun/SunLabel.text = _star_name
	$World/Sun/SunLabel.add_theme_color_override("font_color", Color(_star_color, 0.75))
	dist_sun_label.add_theme_color_override("font_color", Color(_star_color, 0.85))
	$World/Planet/PlanetLabel.text = _planet_name + (" · HOME" if system_data.home else "")
	$World/Planet/GravityLabel.text = "%s GRAVITY" % _planet_name
	$HUDLayer/HUD/Radar/PlanetPointer/TagLabel.text = _planet_name
	$HUDLayer/HUD/Radar/SunPointer/TagLabel.text = "SUN" if system_data.home else "STAR"
	$HUDLayer/HUD/SystemLabel.text = "SYSTEM %02d / %s" % [system_index + 1, str(system_data.name).to_upper()]
	for body: Sprite2D in [sun_sprite, planet_sprite]:
		var rotation_material := body.material as ShaderMaterial
		rotation_material = rotation_material.duplicate() as ShaderMaterial
		body.material = rotation_material
		rotation_material.set_shader_parameter("frame_grid", Vector2(body.hframes, body.vframes))
	planet_zone.set("capture_radius", planet_capture_radius)
	planet_zone.set("stable_orbit_radius", planet_stable_orbit_radius)
	planet_zone.set("gravity_radius", planet_gravity_influence_radius)
	$World/Planet/GravityLabel.position.y = -planet_gravity_influence_radius - 28.0
	$World/OrbitLine.set("orbit_radius", planet_orbit_radius)

	# Initial positions in expanded solar system
	sun_node.position = Vector2.ZERO
	_update_planet_position(0.0)

	# Begin in open space, well outside every planet's gravity boundary.
	ship_node.position = ship_spawn_position
	ship_node.rotation = (planet_node.position - ship_node.position).angle()
	_ship_velocity = Vector2.from_angle(ship_node.rotation) * 180.0
	var arrival := expedition.take_approach()
	var departure := expedition.take_departure()
	_track_course(cinder if arrival == ExpeditionState.CINDER else planet_node)
	if departure >= 0:
		var body: Node2D = cinder if departure == ExpeditionState.CINDER else planet_node
		_track_course(body)
		var gravity_radius: float = cinder.gravity_influence_radius if body == cinder else planet_gravity_influence_radius
		var capture_radius: float = cinder.capture_radius if body == cinder else planet_capture_radius
		var outward := (body.position - sun_node.position).normalized()
		ship_node.position = body.position + outward * (maxf(gravity_radius, capture_radius) + 280.0)
		ship_node.rotation = outward.angle()
		_ship_velocity = _destination_velocity(body) + outward * 180.0
	elif arrival == system_index or (system_index == 0 and arrival == ExpeditionState.CINDER):
		var radius := _stable_radius(_course_target)
		ship_node.position = _course_target.position + Vector2.LEFT * (radius + 32.0)
		ship_node.rotation = Vector2.UP.angle()
		_ship_velocity = _destination_velocity(_course_target) + Vector2.UP * radius * planet_orbit_rot_speed
	ship_node.velocity = _ship_velocity
	$HUDLayer/HUD/Destinations/Routes/Kalypso.pressed.connect(_set_course.bind(0))
	$HUDLayer/HUD/Destinations/Routes/Cinder.pressed.connect(_set_course.bind(ExpeditionState.CINDER))
	if system_index != 0:
		cinder.gravity_boundary.set("capture_radius", 0.0)
		cinder.gravity_boundary.set("stable_orbit_radius", 0.0)
	camera.position = ship_node.position
	var initial_zoom := lerpf(camera_cruise_zoom, camera_fast_zoom, clampf(_ship_velocity.length() / ship_max_speed, 0.0, 1.0))
	camera.zoom = Vector2.ONE * initial_zoom
	camera.reset_smoothing()

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
		var target_zoom = lerpf(camera_cruise_zoom, camera_fast_zoom, speed_ratio)
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
	for child in additional_planets.get_children():
		var body := child as OrbitingPlanetBody
		body.advance_orbit(delta)

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


func _destination_velocity(body: Node2D) -> Vector2:
	return cinder.orbital_velocity() if body == cinder else _get_planet_velocity()


func _stable_radius(body: Node2D) -> float:
	return cinder.stable_orbit_radius if body == cinder else planet_stable_orbit_radius


func _destination_name(body: Node2D) -> String:
	return cinder.display_name if body == cinder else _planet_name


func get_system_star_color() -> Color:
	return _star_color


func get_system_map_data() -> Array[Dictionary]:
	var bodies: Array[Dictionary] = [{
		"name": _planet_name, "position": planet_node.global_position,
		"orbit_radius": planet_orbit_radius, "gravity_radius": planet_gravity_influence_radius,
		"color": Color(0.35, 0.9, 1.0), "is_target": _course_target == planet_node,
	}]
	for child in additional_planets.get_children():
		var body := child as OrbitingPlanetBody
		bodies.append({
			"name": body.display_name, "position": body.global_position,
			"orbit_radius": body.orbit_radius, "gravity_radius": body.gravity_influence_radius,
			"color": body.marker_color, "is_target": _course_target == body,
		})
	return bodies


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
	for child in additional_planets.get_children():
		var body := child as OrbitingPlanetBody
		_ship_velocity += body.gravity_at(ship_node.global_position) * delta

	# Apply velocity
	ship_node.velocity = _ship_velocity
	ship_node.move_and_slide()
	_ship_velocity = ship_node.velocity

	# Complete the free-flight step before handing its position and momentum to orbit.
	if not _is_accelerating():
		if _can_capture_orbit(planet_node):
			_begin_orbital_capture(planet_node)
		elif system_index == 0 and _can_capture_orbit(cinder):
			_begin_orbital_capture(cinder)


func _can_capture_orbit(body: Node2D) -> bool:
	var offset := ship_node.position - body.position
	var distance := offset.length()
	var capture_radius := cinder.capture_radius if body == cinder else planet_capture_radius
	if distance > capture_radius or distance < 1.0:
		return false
	var relative_velocity := _ship_velocity - _destination_velocity(body)
	var radial_speed := relative_velocity.dot(offset / distance)
	# Fast flybys and ships already departing remain under the player's control.
	if relative_velocity.length() > 340.0 or radial_speed > orbit_absorption_speed:
		return false

	var sprite := cinder.sprite if body == cinder else planet_sprite
	var planet_size := sprite.get_rect().size * sprite.scale.abs()
	var ship_size := ship_sprite.get_rect().size * ship_sprite.global_scale.abs()
	var clearance_radius := maxf(planet_size.x, planet_size.y) * 0.5 + ship_size.length() * 0.5 + 20.0
	var inward_speed := maxf(0.0, -radial_speed)
	var stopping_distance := inward_speed * inward_speed / (2.0 * orbit_capture_accel)
	return distance > clearance_radius + stopping_distance


func _begin_orbital_capture(body: Node2D) -> void:
	_orbit_target = body
	_track_course(body)
	_state = ShipState.PULLING_TO_ORBIT
	_throttle = 0.0
	_update_thrusters(0.0)

	var rel := ship_node.position - body.position
	_ship_planet_angle = rel.angle()
	_ship_orbit_dist = rel.length()
	var radial := rel.normalized()
	var tangent := Vector2(-radial.y, radial.x)
	var relative_velocity := _ship_velocity - _destination_velocity(body)
	_orbit_radial_speed = relative_velocity.dot(radial)
	_orbit_tangential_speed = relative_velocity.dot(tangent)
	# Follow the incoming angular momentum, including counterclockwise approaches.
	if absf(_orbit_tangential_speed) > 5.0:
		_orbit_direction = signf(_orbit_tangential_speed)
	else:
		_orbit_direction = -1.0 if Vector2.from_angle(ship_node.rotation).dot(tangent) < 0.0 else 1.0
	_orbit_timer = 0.0

	orbit_title_label.text = "ENTERING %s ORBIT" % _destination_name(body)
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
	var radius := _stable_radius(_orbit_target)
	var target_speed := _orbit_direction * radius * planet_orbit_rot_speed
	var radius_settled := absf(_ship_orbit_dist - radius) < 3.0
	var speed_settled := absf(_orbit_radial_speed) < 3.0 and absf(_orbit_tangential_speed - target_speed) < 3.0
	if radius_settled and speed_settled:
		_state = ShipState.IN_ORBIT
		_update_thrusters(0.0)
		_orbit_timer = 0.0
		orbit_title_label.text = "%s ORBIT ESTABLISHED" % _destination_name(_orbit_target)
		orbit_timer_label.text = "DESCENT IN: %.1fs" % orbit_dwell_duration
		orbit_hint_label.text = "[SPACE / ENTER] Land Now  •  [W / UP] Resume flight"
		orbit_entered.emit()


func _advance_orbit(delta: float) -> void:
	var previous_radius := _ship_orbit_dist
	var previous_radial_speed := _orbit_radial_speed
	var previous_tangential_speed := _orbit_tangential_speed
	var radius := _stable_radius(_orbit_target)
	var target_radial_speed := clampf((radius - _ship_orbit_dist) * 1.2, -orbit_absorption_speed, orbit_absorption_speed)
	var target_tangential_speed := _orbit_direction * radius * planet_orbit_rot_speed
	_orbit_radial_speed = move_toward(_orbit_radial_speed, target_radial_speed, orbit_capture_accel * delta)
	_orbit_tangential_speed = move_toward(_orbit_tangential_speed, target_tangential_speed, orbit_capture_accel * delta)

	# Integrate the existing motion while gradually circularizing the trajectory.
	_ship_orbit_dist += (previous_radial_speed + _orbit_radial_speed) * 0.5 * delta
	var mean_radius := maxf(1.0, (previous_radius + _ship_orbit_dist) * 0.5)
	_ship_planet_angle = wrapf(_ship_planet_angle + (previous_tangential_speed + _orbit_tangential_speed) * 0.5 / mean_radius * delta, -PI, PI)
	var radial := Vector2.from_angle(_ship_planet_angle)
	var tangent := Vector2(-radial.y, radial.x)
	var relative_velocity := radial * _orbit_radial_speed + tangent * _orbit_tangential_speed
	ship_node.position = _orbit_target.position + radial * _ship_orbit_dist
	_ship_velocity = _destination_velocity(_orbit_target) + relative_velocity
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


func _set_course(index: int) -> void:
	if _state == ShipState.TRANSITIONING:
		return
	if system_index == 0:
		var body: Node2D = cinder if index == ExpeditionState.CINDER else planet_node
		if _state != ShipState.FREE_FLIGHT and _orbit_target != body:
			_break_orbit()
		_track_course(body)
	elif expedition.fly_to(index, true) == OK:
		destinations.hide()


func _track_course(body: Node2D) -> void:
	_course_target = body
	var name := _destination_name(body)
	$HUDLayer/HUD/Radar/PlanetPointer/TagLabel.text = name
	$HUDLayer/HUD/Destinations/Routes/Label.text = "COURSE / " + name


func _trigger_game_transition() -> void:
	if _state == ShipState.TRANSITIONING:
		return
	_state = ShipState.TRANSITIONING
	var destination := ExpeditionState.CINDER if _orbit_target == cinder else system_index
	var duel_scene := "res://scenes/drift_circuit.tscn" if _orbit_target == cinder else next_scene_path
	destinations.hide()
	engine_thrusters.visible = false
	scene_transition_started.emit()

	if orbit_timer_label:
		orbit_timer_label.text = "DESCENT INITIATED • ENTERING ARENA"

	if screen_fade:
		screen_fade.visible = true
		screen_fade.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(screen_fade, "modulate:a", 1.0, 0.6)
		tween.tween_callback(_land.bind(destination, duel_scene))
	else:
		_land(destination, duel_scene)


func _land(destination: int, duel_scene: String) -> void:
	if not duel_scene.is_empty() and get_tree().change_scene_to_file(duel_scene) == OK:
		expedition.enter_system(destination)


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
	var dist_planet := ship_node.position.distance_to(_course_target.position)
	var speed_val = _ship_velocity.length()

	if speed_label:
		speed_label.text = "VELOCITY: %d KM/S   THROTTLE: %d%%" % [int(speed_val), int(_throttle * 100.0)]
	if dist_sun_label:
		dist_sun_label.text = "%s: %d KM" % [_star_name, int(dist_sun)]
	if dist_planet_label:
		dist_planet_label.text = "%s: %d KM" % [_destination_name(_course_target), int(dist_planet)]
	var local_gravity := "SOLAR"
	var nearest_ratio := 1.0
	for body_data in get_system_map_data():
		var body_position: Vector2 = body_data.position
		var ratio: float = ship_node.global_position.distance_to(body_position) / float(body_data.gravity_radius)
		if ratio < nearest_ratio:
			nearest_ratio = ratio
			local_gravity = body_data.name
	gravity_status_label.text = "GRAVITY: %s" % local_gravity

	_update_tracking_marker(sun_pointer, sun_node.global_position, _star_color)
	var tracking_cinder := _course_target == cinder
	var tint := cinder.marker_color if tracking_cinder else Color(0.3, 0.85, 1.0)
	_update_tracking_marker(planet_pointer, _course_target.global_position, tint, tracking_cinder)


func _update_tracking_marker(marker: Control, target_pos: Vector2, tint_col: Color, mark_visible_body: bool = false) -> void:
	if not marker or not camera:
		return

	var vp_size := get_viewport_rect().size
	# Project through the camera so markers match the actual zoom and smoothing.
	var to_target: Vector2 = get_viewport().get_canvas_transform() * target_pos - vp_size * 0.5

	var margin = 48.0
	var half_w = (vp_size.x * 0.5) - margin
	var half_h = (vp_size.y * 0.5) - margin

	if absf(to_target.x) < half_w and absf(to_target.y) < half_h:
		marker.visible = mark_visible_body
		if mark_visible_body:
			marker.modulate = tint_col
			var target_screen := vp_size * 0.5 + to_target
			var vert := 1.0 if target_screen.y < 160.0 else -1.0
			var position_y := target_screen.y + vert * (cinder.surface_radius * camera.zoom.y + 30.0)
			marker.position = Vector2(target_screen.x, clampf(position_y, margin, vp_size.y - margin))
			marker.get_node("Chevron").rotation = -vert * PI / 2.0
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
