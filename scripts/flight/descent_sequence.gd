extends Control
## CC0 forward star flight viewed from a centered public domain cockpit panorama.
signal finished

const VIDEO = preload("res://art/descent/star-flight.ogv")
const FRAME = preload("res://art/descent/cockpit-frame.png")
const FONT = preload("res://art/fonts/IBMPlexMono-Regular.ttf")
const StoryArt = preload("res://scripts/battle/story_art.gd")
const DURATION := 8.067
const HOLOGRAM_DURATION := 1.38

var player: VideoStreamPlayer
var hologram: Panel
var _link_cover: ColorRect
var _planet := ""
var _content: Control
var _watchdog: Tween
var _ending := false
var _completed := false


func _ready() -> void:
	name = "DescentSequence"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_content = Control.new()
	_content.size = Vector2(1320, 850)
	add_child(_content)
	player = VideoStreamPlayer.new()
	player.name = "ForwardStarVideo"
	player.stream = VIDEO
	player.expand = true
	player.position = Vector2(0, -198)
	player.size = Vector2(1320, 1056)
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.finished.connect(_begin_hologram)
	_content.add_child(player)
	var cockpit := TextureRect.new()
	cockpit.texture = FRAME
	cockpit.size = Vector2(1320, 850)
	cockpit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cockpit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(cockpit)
	var caption_background := ColorRect.new()
	caption_background.color = Color(0.02, 0.035, 0.05, 0.86)
	caption_background.position = Vector2(40, 740)
	caption_background.size = Vector2(600, 69)
	_content.add_child(caption_background)
	_caption("HORIZON / AUTOMATED DESCENT", Vector2(55, 750), 13, Color("#b7dfed"))
	_caption("FORWARD FLIGHT", Vector2(55, 778), 16, Color.WHITE).name = "Destination"
	var skip := Button.new()
	skip.name = "SkipDescent"
	skip.text = "Skip descent  [Esc]"
	skip.position = Vector2(1045, 32)
	skip.size = Vector2(235, 38)
	skip.add_theme_font_override("font", FONT)
	skip.add_theme_font_size_override("font_size", 13)
	skip.pressed.connect(_begin_hologram)
	_content.add_child(skip)
	resized.connect(_layout)
	_layout()


func _caption(text: String, at: Vector2, px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	_content.add_child(label)
	return label


func _layout() -> void:
	var ratio := minf(size.x / 1320.0, size.y / 850.0)
	_content.scale = Vector2.ONE * ratio
	_content.position = (size - Vector2(1320, 850) * ratio) / 2


func start(planet: String) -> void:
	_planet = planet
	_content.get_node("Destination").text = planet.to_upper() + " / FORWARD FLIGHT"
	player.play()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	# A failed decoder must never trap the crew in the transition screen.
	_watchdog = create_tween()
	_watchdog.tween_interval(DURATION + 2.0)
	_watchdog.tween_callback(_begin_hologram)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_begin_hologram()


func _begin_hologram() -> void:
	if _ending:
		return
	_ending = true
	if _watchdog:
		_watchdog.kill()
	player.paused = true
	_content.get_node("SkipDescent").hide()
	var dim := ColorRect.new()
	dim.color = Color(0, 0.025, 0.04, 0.48)
	dim.size = Vector2(1320, 850)
	dim.modulate.a = 0.0
	_content.add_child(dim)
	hologram = Panel.new()
	hologram.name = "IncomingHologram"
	hologram.size = Vector2(520, 390)
	hologram.position = Vector2(400, 160)
	hologram.pivot_offset = Vector2(260, 390)
	hologram.scale = Vector2(0.08, 0.02)
	hologram.modulate.a = 0.0
	hologram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.015, 0.065, 0.085, 0.94)
	frame.border_color = Color("#83e1fa")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(6)
	frame.shadow_color = Color(0.2, 0.7, 0.85, 0.18)
	frame.shadow_size = 18
	hologram.add_theme_stylebox_override("panel", frame)
	_content.add_child(hologram)
	_link_label("INCOMING HOLOGRAM", Vector2(30, 22), 14, Color("#83e1fa"))
	var portrait := StoryArt.new()
	portrait.role = "envoy"
	portrait.cinder = _planet.to_upper() == "CINDER"
	portrait.position = Vector2(180, 62)
	portrait.size = Vector2(160, 180)
	hologram.add_child(portrait)
	_link_label("ENVOY VESPER" if portrait.cinder else "ENVOY LYRA", Vector2(30, 258), 20, Color("#ffc18c") if portrait.cinder else Color("#a0edb4"))
	var link := _link_label("Opening a channel to " + _planet.capitalize() + "...", Vector2(30, 295), 14, Color("#c9e6ed"))
	_link_label("HORIZON / COMMUNICATION LINK", Vector2(30, 347), 11, Color("#83e1fa"))
	_link_cover = ColorRect.new()
	_link_cover.name = "HologramTransition"
	_link_cover.color = Color(0.015, 0.065, 0.085)
	_link_cover.size = Vector2(1320, 850)
	_link_cover.modulate.a = 0.0
	_link_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_link_cover)
	var transition := create_tween()
	transition.tween_property(hologram, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	transition.parallel().tween_property(hologram, "modulate:a", 1.0, 0.28)
	transition.parallel().tween_property(dim, "modulate:a", 1.0, 0.38)
	transition.tween_callback(func(): link.text = "Link established. Receiving transmission.")
	transition.tween_interval(0.5)
	transition.tween_property(hologram, "scale", Vector2(2.8, 2.8), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	transition.parallel().tween_property(_link_cover, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	transition.tween_callback(_complete)


func _link_label(text: String, at: Vector2, px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(460, 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	hologram.add_child(label)
	return label


func _complete() -> void:
	if _completed:
		return
	_completed = true
	finished.emit()
