class_name OpeningCrawl
extends Control

## Star Wars Opening Crawl Controller
## Manages timing, 3D text progression, intro sequence, and transition to the game board.

signal intro_finished
signal crawl_finished

@export_group("Story Content")
@export var intro_text: String = "Beyond the last human star charts, a new signal waits."
@export var episode_text: String = "THE HORIZON EXPEDITION"
@export var title_text: String = "FIRST CONTACT"
@export_multiline var body_text: String = (
	"We are the crew of the HORIZON, exploring beyond the last human star charts. " +
	"Our mission is simple: discover new worlds, make contact, and find a safe passage home.\n\n" +
	"As we approach each planet, its inhabitants detect our signal. An envoy appears on our flight screen: " +
	"accept their challenge, or leave orbit in peace.\n\n" +
	"Win, and a new world welcomes us as ALLIES. Lose, and access is denied. " +
	"We must withdraw, marked UNPROVEN until we earn their trust.\n\n" +
	"Captain Valeria and Navigator Sol stand ready. The first transmission is coming through..."
)

@export_group("Timing & Speed")
## Duration in seconds for the yellow text crawl itself.
@export var crawl_duration: float = 45.0
## Duration for the cyan intro text before disappearing. Set to 0 to skip intro.
@export var intro_duration: float = 2.5

@export_group("Movement Bounds")
## Starting position along the tilted plane (placed right at the lower screen edge so reading starts immediately).
@export var start_local_y: float = -3.5
## Ending position along the tilted plane where the final lines dissolve into space.
@export var end_local_y: float = 8.5

@export_group("Scene Navigation")
## Path to the next scene to load upon crawl completion (transitions to solar_system.tscn).
@export_file("*.tscn") var next_scene_path: String = "res://scenes/solar_system.tscn"
@export var allow_skip: bool = true
@export var allow_speedup: bool = true
@export var speedup_multiplier: float = 8.0

@export_group("Audio")
@export var music_stream: AudioStream

# Node references
@onready var soundtrack: Node = get_node("/root/Soundtrack")
@onready var intro_label: Label = $IntroContainer/IntroLabel
@onready var intro_container: Control = $IntroContainer
@onready var crawl_viewport_container: SubViewportContainer = $CrawlViewportContainer
@onready var text_content: Node3D = $CrawlViewportContainer/SubViewport/CrawlWorld/CrawlTilt/TextContent
@onready var episode_label: Label3D = $CrawlViewportContainer/SubViewport/CrawlWorld/CrawlTilt/TextContent/EpisodeLabel
@onready var title_label: Label3D = $CrawlViewportContainer/SubViewport/CrawlWorld/CrawlTilt/TextContent/TitleLabel
@onready var body_label: Label3D = $CrawlViewportContainer/SubViewport/CrawlWorld/CrawlTilt/TextContent/BodyLabel
@onready var skip_hint: Label = $SkipHint
@onready var music_player: AudioStreamPlayer = $MusicPlayer

var _elapsed_time: float = 0.0
var _is_crawl_active: bool = false
var _is_completed: bool = false


func _ready() -> void:
	# Populate text fields
	if intro_label:
		intro_label.text = intro_text
	if episode_label:
		episode_label.text = episode_text
	if title_label:
		title_label.text = title_text
	if body_label:
		body_label.text = body_text

	# Ensure crawl starts at the exact initial position
	if text_content:
		text_content.position.y = start_local_y

	# Yellow crawl text is completely hidden while blue intro text is showing
	if crawl_viewport_container:
		if intro_duration > 0.0:
			crawl_viewport_container.visible = false
			crawl_viewport_container.modulate.a = 0.0
		else:
			crawl_viewport_container.visible = true
			crawl_viewport_container.modulate.a = 1.0

	# Play audio if provided
	if music_stream and music_player:
		soundtrack.stop_music()
		music_player.stream = music_stream
		music_player.bus = &"Music"
		music_player.play()
	else:
		soundtrack.music("flight")

	if intro_duration > 0.0:
		_start_intro_sequence()
	else:
		_start_crawl()


func _start_intro_sequence() -> void:
	if intro_container:
		intro_container.modulate.a = 0.0
		intro_container.visible = true

	var tween: Tween = create_tween()
	var fade_time: float = minf(0.6, intro_duration * 0.25)
	var hold_time: float = maxf(0.2, intro_duration - (fade_time * 2.0))

	# 1. Fade in cyan intro text
	tween.tween_property(intro_container, "modulate:a", 1.0, fade_time)
	# 2. Hold visible
	tween.tween_interval(hold_time)
	# 3. Fade out cyan intro text completely
	tween.tween_property(intro_container, "modulate:a", 0.0, fade_time)

	# 4. Brief dramatic pause (0.4s) after blue text is gone, then bring in yellow crawl
	tween.tween_interval(0.4)
	tween.tween_callback(func():
		if intro_container:
			intro_container.visible = false
		_start_crawl()
	)


func _start_crawl() -> void:
	_elapsed_time = 0.0
	_is_crawl_active = true

	# Ensure position is at start
	if text_content:
		text_content.position.y = start_local_y

	# Reveal the yellow crawl now that blue text has fully disappeared
	if crawl_viewport_container:
		crawl_viewport_container.visible = true
		var tween: Tween = create_tween()
		tween.tween_property(crawl_viewport_container, "modulate:a", 1.0, 0.4)

	intro_finished.emit()


func _process(delta: float) -> void:
	if _is_completed:
		return

	# Hold Space or Up to speed up the text; release to return to normal speed.
	var current_speed: float = 1.0
	if allow_speedup and (
		Input.is_action_pressed("ui_select") or
		Input.is_action_pressed("ui_up") or
		Input.is_key_pressed(KEY_SPACE)
	):
		current_speed = speedup_multiplier

	# Advance the crawl over its configured duration.
	if _is_crawl_active:
		_elapsed_time += delta * current_speed
		var progress: float = clampf(_elapsed_time / maxf(1.0, crawl_duration), 0.0, 1.0)

		# Linear movement along the tilted plane into the starfield
		if text_content:
			text_content.position.y = lerpf(start_local_y, end_local_y, progress)

		if progress >= 1.0:
			_finish_crawl()


func _unhandled_input(event: InputEvent) -> void:
	if _is_completed:
		return
	if allow_skip and event is InputEventKey and event.is_pressed() and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER:
			_finish_crawl()


func _finish_crawl() -> void:
	if _is_completed:
		return
	_is_completed = true
	_is_crawl_active = false
	crawl_finished.emit()

	# Smoothly transition to the game board / main scene
	if not next_scene_path.is_empty():
		var tween: Tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.4)
		tween.tween_callback(func():
			get_tree().change_scene_to_file(next_scene_path)
		)
