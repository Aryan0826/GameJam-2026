extends CanvasLayer
## Shared pause screen. Uses the project's licensed fonts and Godot controls.

const SANS = preload("res://art/fonts/SpaceGrotesk.ttf")
const MONO = preload("res://art/fonts/IBMPlexMono-Regular.ttf")
var screen: Control
var resume_button: Button
var orbit_button: Button
var mute_button: Button
var sliders: Dictionary = {}
var _scene: Node
var _return_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(screen)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.045, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 480
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111e29")
	style.border_color = Color("#83e1fa")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	_label(stack, "UNCHARTED WILDS", 14, MONO, Color("#83e1fa"))
	_label(stack, "Paused", 38)
	resume_button = _button(stack, "Resume", resume)
	orbit_button = _button(stack, "Return to orbit", _return_to_orbit)
	orbit_button.tooltip_text = "Leave this match and fly again."
	_button(stack, "Main menu", _main_menu)
	for bus in ["Music", "Effects"]:
		var row := HBoxContainer.new()
		stack.add_child(row)
		var caption := _label(row, bus, 16)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := _label(row, "", 14, MONO)
		var slider := HSlider.new()
		slider.name = bus + "Volume"
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size = Vector2(0, 24)
		stack.add_child(slider)
		sliders[bus] = {"slider": slider, "label": value}
		slider.value_changed.connect(func(amount: float):
			get_node("/root/Soundtrack").set_volume(bus, amount / 100.0)
			value.text = "%d%%" % roundi(amount))
	mute_button = _button(stack, "Sound on")
	mute_button.toggle_mode = true
	mute_button.tooltip_text = "Turn all sound on or off."
	mute_button.toggled.connect(func(value: bool):
		get_node("/root/Soundtrack").set_muted(value)
		mute_button.text = "Sound muted" if value else "Sound on")
	if not OS.has_feature("web"):
		_button(stack, "Quit game", _quit)
	_label(stack, "Esc to resume", 14, MONO, Color("#aab8d1"))
	screen.hide()


func _label(parent: Node, text: String, size: int, font: Font = SANS, tint: Color = Color("#f3f5ff")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable = Callable()) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#273c51") if state in ["hover", "pressed"] else Color("#1b293f")
		style.border_color = Color("#83e1fa") if state in ["hover", "focus"] else Color("#3d5b68")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(7)
		button.add_theme_stylebox_override(state, style)
	if callback.is_valid():
		button.pressed.connect(callback)
	parent.add_child(button)
	return button


func is_open() -> bool:
	return screen != null and screen.visible


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if is_open() and event.keycode == KEY_M:
		var audio := get_node("/root/Soundtrack")
		audio.set_muted(not audio.muted())
		mute_button.set_pressed_no_signal(audio.muted())
		mute_button.text = "Sound muted" if audio.muted() else "Sound on"
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		if is_open():
			resume()
		else:
			var scene := get_tree().current_scene
			if scene == null or scene.scene_file_path in ["res://scenes/home.tscn", "res://scenes/opening_crawl.tscn"]:
				return
			# Help closes first. A second Esc opens the pause screen.
			if scene.get("overlay_kind") != null and scene.get("overlay_kind") not in ["", "home", "handoff"]:
				return
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open():
		return
	_scene = get_tree().current_scene
	if _scene == null:
		return
	_return_focus = get_viewport().gui_get_focus_owner()
	var audio := get_node("/root/Soundtrack")
	for bus in sliders:
		var amount: float = audio.volume(bus) * 100.0
		sliders[bus].slider.set_value_no_signal(amount)
		sliders[bus].label.text = "%d%%" % roundi(amount)
	mute_button.set_pressed_no_signal(audio.muted())
	mute_button.text = "Sound muted" if audio.muted() else "Sound on"
	orbit_button.visible = _scene.has_method("_leave_current_orbit")
	if _scene.get("combat_feedback") != null:
		_scene.combat_feedback.stop()
	if _scene.get("_engine_sound") != null:
		_scene._engine_sound.stream_paused = true
	audio.pause_effects(true)
	get_tree().paused = true
	screen.show()
	resume_button.grab_focus()


func resume() -> void:
	if not is_open():
		return
	screen.hide()
	get_tree().paused = false
	var audio := get_node("/root/Soundtrack")
	audio.pause_effects(false)
	audio.save_volumes()
	if is_instance_valid(_scene) and _scene.get("_engine_sound") != null:
		_scene._engine_sound.stream_paused = false
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus()


func _return_to_orbit() -> void:
	var scene := _scene
	resume()
	if is_instance_valid(scene) and scene.has_method("_leave_current_orbit"):
		scene._leave_current_orbit()


func _main_menu() -> void:
	resume()
	get_tree().change_scene_to_file("res://scenes/home.tscn")


func _quit() -> void:
	resume()
	get_tree().quit()
