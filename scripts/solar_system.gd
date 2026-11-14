class_name SolarSystem
extends Node2D

## 2D Solar System Exploration Scene
## Features an expanded 5000px solar system, a colossal central Sun with realistic gravity,
## gradual spacecraft momentum accumulation (Newtonian inertia), planetary gravitational pull,
## graceful slow orbital insertion, and transition to the game board after 4 seconds of stable orbit.

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
@export var orbit_dwell_duration: float = 4.0

@export_group("Solar Mechanics")
@export var sun_gravity_constant: float = 120000.0 # gravitational pull across the deep space system
@export var sun_min_dist: float = 340.0 # solar thermal repulsion buffer around the massive star
@export var planet_orbit_radius: float = 5000.0 # vast solar system radius
@export var planet_orbit_speed: float = 0.025 # radians/sec (~250s full orbit)
@export var planet_gravity_influence_radius: float = 650.0 # planetary gravitational well
@export var planet_gravity_strength: float = 28000.0 # planet's own inward gravitational pull
@export var planet_capture_radius: float = 320.0 # dotted proximity boundary
@export var planet_stable_orbit_radius: float = 175.0 # dotted stable orbit boundary
@export var planet_orbit_rot_speed: float = 1.0 # radians/sec (~6.3s per planetary orbit)
@export var orbit_absorption_speed: float = 32.0 # slow, realistic gravitational capture into orbit

@export_group("Ship Handling (Realistic Mechanics)")
@export var ship_thrust_accel: float = 460.0 # gradual acceleration
@export var ship_boost_accel: float = 780.0
@export var ship_turn_speed: float = 3.2 # radians/sec
@export var ship_max_speed: float = 1400.0 # high top speed gradually reached
@export var ship_boost_speed: float = 1850.0
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
@onready var engine_particles: CPUParticles2D = $World/PlayerShip/EngineParticles
@onready var camera: Camera2D = $World/Camera2D
@onready var starfield_rect: ColorRect = $StarfieldLayer/StarfieldBackground
@onready var hud_control: Control = $HUDLayer/HUD
@onready var orbit_hud: Control = $HUDLayer/HUD/OrbitHUD
@onready var orbit_timer_label: Label = $HUDLayer/HUD/OrbitHUD/VBox/TimerLabel
@onready var orbit_progress_bar: ProgressBar = $HUDLayer/HUD/OrbitHUD/VBox/ProgressBar
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
var _ship_orbit_dist: float = 320.0
var _orbit_timer: float = 0.0
var _sun_anim_time: float = 0.0
var _planet_anim_time: float = 0.0


func _ready() -> void:
	_setup_textures()

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
	if engine_particles:
		engine_particles.emitting = false

	# Fade in from black on entry
	if screen_fade:
		screen_fade.visible = true
		screen_fade.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(screen_fade, "modulate:a", 0.0, 0.6)
		tween.tween_callback(func(): screen_fade.visible = false)


func _setup_textures() -> void:
	var sun_tex = _load_texture_safe("res://art/sun_sheet.png")
	if sun_tex and sun_sprite:
		sun_sprite.texture = sun_tex
		sun_sprite.hframes = 44
		sun_sprite.vframes = 1
		sun_sprite.frame = 0
		sun_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var planet_tex = _load_texture_safe("res://art/planet_sheet.png")
	if planet_tex and planet_sprite:
		planet_sprite.texture = planet_tex
		planet_sprite.hframes = 44
		planet_sprite.vframes = 1
		planet_sprite.frame = 0
		planet_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var ship_tex = _load_texture_safe("res://art/ship.png")
	if ship_tex and ship_sprite:
		ship_sprite.texture = ship_tex
		ship_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _load_texture_safe(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res = load(res_path)
		if res is Texture2D:
			return res
	var global_path = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(global_path):
		var img = Image.load_from_file(global_path)
		if img:
			return ImageTexture.create_from_image(img)
	return null


func _process(delta: float) -> void:
	_sun_anim_time += delta
	_planet_anim_time += delta

	# Fluid 20 FPS rotation across the 44-frame seamless loop
	if sun_sprite and sun_sprite.hframes == 44:
		sun_sprite.frame = int(_sun_anim_time * 20.0) % 44
	if planet_sprite and planet_sprite.hframes == 44:
		planet_sprite.frame = int(_planet_anim_time * 20.0) % 44

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
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		thrust_target = 1.0

	# Retro brake thrusters
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		brake_input = 1.0

	# Warp / Boost modifier (holding SHIFT or SPACE)
	var is_boosting: bool = Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SPACE)
	if is_boosting and thrust_target == 0.0 and abs(turn_input) < 0.1:
		thrust_target = 1.0

	var cur_accel = ship_boost_accel if is_boosting else ship_thrust_accel
	var cur_max_speed = ship_boost_speed if is_boosting else ship_max_speed

	# Alternative: direct WASD vector aiming if not using Asteroids rotation
	var direct_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direct_dir.length_squared() > 0.1 and abs(turn_input) < 0.1 and thrust_target < 0.1:
		var target_rot = direct_dir.angle()
		ship_node.rotation = rotate_toward(ship_node.rotation, target_rot, ship_turn_speed * delta)
		thrust_target = 1.0

	# Apply rotation
	ship_node.rotation += turn_input * ship_turn_speed * delta

	# Facing vector
	var forward: Vector2 = Vector2.from_angle(ship_node.rotation)

	# Real mechanics: Gradual throttle build-up & velocity accumulation
	_throttle = move_toward(_throttle, thrust_target, 1.4 * delta)
	if _throttle > 0.01:
		_ship_velocity += forward * cur_accel * _throttle * delta

	if engine_particles:
		engine_particles.emitting = (_throttle > 0.05)
		engine_particles.amount = int(lerpf(16.0, 48.0, _throttle))
		engine_particles.initial_velocity_max = lerpf(80.0, 220.0, _throttle)

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
	var rel_vel: Vector2 = _ship_velocity - _get_planet_velocity()

	if dist_planet < planet_gravity_influence_radius:
		var planet_pull: float = planet_gravity_strength / maxf(dist_planet, 120.0)
		_ship_velocity += to_planet.normalized() * planet_pull * delta

	# --- 3. Planetary Orbital Capture Check ---
	# Inside dotted proximity radius, and ship is not firing full forward thrusters
	if dist_planet <= planet_capture_radius:
		if _throttle < 0.2 and (rel_vel.length() < 340.0 or brake_input > 0.0):
			_begin_orbital_capture()
			return

	# Apply velocity
	ship_node.velocity = _ship_velocity
	ship_node.move_and_slide()
	_ship_velocity = ship_node.velocity


func _begin_orbital_capture() -> void:
	_state = ShipState.PULLING_TO_ORBIT
	_throttle = 0.0
	if engine_particles:
		engine_particles.emitting = false

	var rel: Vector2 = ship_node.position - planet_node.position
	_ship_planet_angle = rel.angle()
	_ship_orbit_dist = rel.length()

	_show_orbit_hud(true)
	orbit_entered.emit()


func _process_pulling_to_orbit(delta: float) -> void:
	# Break orbit if player engages thrusters
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SHIFT):
		_break_orbit()
		return

	# Slower, realistic orbital insertion: gently spiral toward stable orbit radius
	_ship_orbit_dist = move_toward(_ship_orbit_dist, planet_stable_orbit_radius, orbit_absorption_speed * delta)
	_ship_planet_angle += planet_orbit_rot_speed * delta

	# Position relative to moving planet
	ship_node.position = planet_node.position + Vector2.from_angle(_ship_planet_angle) * _ship_orbit_dist

	# Smoothly align ship orientation along orbital tangent
	var target_rot = _ship_planet_angle + (PI * 0.5)
	ship_node.rotation = rotate_toward(ship_node.rotation, target_rot, 1.6 * delta)

	# Once reached stable orbit altitude, switch to locked IN_ORBIT
	if absf(_ship_orbit_dist - planet_stable_orbit_radius) < 3.0:
		_state = ShipState.IN_ORBIT
		_orbit_timer = 0.0


func _process_in_orbit(delta: float) -> void:
	# Break orbit if player thrusts out
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SHIFT):
		_break_orbit()
		return

	# Instant land / skip shortcut
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_ENTER):
		_trigger_game_transition()
		return

	# Orbit the moving planet smoothly
	_ship_planet_angle += planet_orbit_rot_speed * delta
	ship_node.position = planet_node.position + Vector2.from_angle(_ship_planet_angle) * planet_stable_orbit_radius
	ship_node.rotation = _ship_planet_angle + (PI * 0.5)

	# Advance 4-second countdown
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

	# Impart orbital tangent velocity + outward boost
	var tangent_vel = Vector2.from_angle(_ship_planet_angle + PI * 0.5) * (planet_stable_orbit_radius * planet_orbit_rot_speed)
	_ship_velocity = _get_planet_velocity() + tangent_vel + Vector2.from_angle(ship_node.rotation) * 260.0


func _trigger_game_transition() -> void:
	if _state == ShipState.TRANSITIONING:
		return
	_state = ShipState.TRANSITIONING
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
	_ship_planet_angle += planet_orbit_rot_speed * delta
	ship_node.position = planet_node.position + Vector2.from_angle(_ship_planet_angle) * planet_stable_orbit_radius
	ship_node.rotation = _ship_planet_angle + (PI * 0.5)


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
