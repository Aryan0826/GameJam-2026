extends Node2D
## An independently orbiting planet with its own rotating artwork and gravity well.

const ROTATION_SHADER = preload("res://shaders/body_rotation.gdshader")

@export var challenge_available := false
@export var display_name: String = "Planet"
@export var orbit_radius: float = 2600.0
@export var orbit_speed: float = 0.031
@export var initial_orbit_angle: float = -0.9
@export var rotation_duration: float = 40.0
@export var gravity_influence_radius: float = 550.0
@export var gravity_strength: float = 18000.0
@export var surface_radius: float = 153.0
@export var capture_radius := 0.0
@export var stable_orbit_radius := 0.0
@export var marker_color: Color = Color("#edb96a")

@onready var sun: Node2D = get_node("../../Sun")
@onready var sprite: Sprite2D = $PlanetSprite
@onready var gravity_boundary: Node2D = $GravityBoundary
@onready var planet_label: Label = $PlanetLabel
@onready var gravity_label: Label = $GravityLabel

var _orbit_angle: float = 0.0
var _rotation_time: float = 0.0


func _ready() -> void:
	_orbit_angle = initial_orbit_angle
	var rotation_material := ShaderMaterial.new()
	rotation_material.shader = ROTATION_SHADER
	rotation_material.set_shader_parameter("frame_grid", Vector2(sprite.hframes, sprite.vframes))
	sprite.material = rotation_material
	gravity_boundary.set("gravity_radius", gravity_influence_radius)
	gravity_boundary.set("gravity_color", Color(marker_color, 0.35))
	gravity_boundary.set("capture_radius", capture_radius)
	gravity_boundary.set("stable_orbit_radius", stable_orbit_radius)
	gravity_boundary.set("proximity_color", Color(marker_color, 0.68))
	gravity_boundary.set("orbit_color", Color(marker_color, 0.44))
	planet_label.text = display_name
	planet_label.add_theme_color_override("font_color", marker_color)
	gravity_label.position.y = -gravity_influence_radius - 28.0
	gravity_label.text = "%s GRAVITY" % display_name
	gravity_label.add_theme_color_override("font_color", Color(marker_color, 0.7))
	if not challenge_available:
		var coming := Label.new()
		coming.name = "ComingSoon"
		coming.text = "Coming soon"
		coming.position = Vector2(-110, -surface_radius - 40)
		coming.size = Vector2(220, 28)
		coming.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coming.add_theme_font_override("font", preload("res://art/fonts/IBMPlexMono-Regular.ttf"))
		coming.add_theme_font_size_override("font_size", 20)
		coming.add_theme_color_override("font_color", Color("#f8d587"))
		add_child(coming)
	advance_orbit(0.0)


func _process(delta: float) -> void:
	_rotation_time = fposmod(_rotation_time + delta, rotation_duration)
	var frame_position := _rotation_time / rotation_duration * sprite.hframes * sprite.vframes
	sprite.frame = floori(frame_position)
	var rotation_material := sprite.material as ShaderMaterial
	rotation_material.set_shader_parameter("frame_index", float(sprite.frame))
	rotation_material.set_shader_parameter("frame_blend", frame_position - sprite.frame)


func advance_orbit(delta: float) -> void:
	_orbit_angle = wrapf(_orbit_angle + orbit_speed * delta, -PI, PI)
	global_position = sun.global_position + Vector2.from_angle(_orbit_angle) * orbit_radius


func orbital_velocity() -> Vector2:
	return Vector2.from_angle(_orbit_angle).orthogonal() * (-orbit_radius * orbit_speed)


func gravity_at(point: Vector2) -> Vector2:
	var offset := global_position - point
	var distance := offset.length()
	if distance < 1.0 or distance >= gravity_influence_radius:
		return Vector2.ZERO
	# The pull fades at the visible boundary rather than switching on abruptly.
	var influence := 1.0 - smoothstep(gravity_influence_radius * 0.65, gravity_influence_radius, distance)
	var acceleration := offset / distance * gravity_strength / maxf(distance, surface_radius) * influence
	var surface_buffer := surface_radius + 48.0
	if distance < surface_buffer:
		acceleration -= offset / distance * (surface_buffer - distance) * 14.0
	return acceleration
