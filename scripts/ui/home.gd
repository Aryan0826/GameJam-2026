extends Control

const ExpeditionState = preload("res://scripts/core/expedition.gd")
const STORY_SCENE := "res://scenes/opening_crawl.tscn"

@onready var soundtrack: Node = get_node("/root/Soundtrack")
@onready var expedition: ExpeditionState = get_node("/root/Expedition")
@onready var explore_button: Button = $Menu/Content/Actions/Explore
@onready var exit_button: Button = $Menu/Content/Actions/Exit
@onready var status_label: Label = $Menu/Content/Status
@onready var music_slider: HSlider = $Menu/Content/Audio/Music
@onready var effects_slider: HSlider = $Menu/Content/Audio/Effects
@onready var captain_choice: CenterContainer = $CaptainChoice
@onready var good_button: Button = $CaptainChoice/Panel/Margin/Content/Good
@onready var evil_button: Button = $CaptainChoice/Panel/Margin/Content/Evil
@onready var back_button: Button = $CaptainChoice/Panel/Margin/Content/Back

var _starting := false
var _choosing := false


func _ready() -> void:
	explore_button.grab_focus()
	_connect_volume(music_slider, "Music")
	_connect_volume(effects_slider, "Effects")
	if not OS.has_feature("web"):
		soundtrack.music("flight")


func _connect_volume(slider: HSlider, bus: String) -> void:
	slider.set_value_no_signal(soundtrack.volume(bus))
	slider.value_changed.connect(func(value: float): soundtrack.set_volume(bus, value))


func _explore() -> void:
	if _starting or _choosing:
		return
	soundtrack.music("flight")
	soundtrack.cue("click")
	soundtrack.save_volumes()
	_choosing = true
	$Menu.hide()
	$Controls.hide()
	captain_choice.show()
	good_button.grab_focus()


func _choose_captain(evil: bool) -> void:
	if _starting or not _choosing:
		return
	soundtrack.cue("confirm")
	_starting = true
	good_button.disabled = true
	evil_button.disabled = true
	back_button.disabled = true
	expedition.reset_journey(evil)
	var scene_error := get_tree().change_scene_to_file(STORY_SCENE)
	if scene_error != OK:
		_starting = false
		good_button.disabled = false
		evil_button.disabled = false
		back_button.disabled = false
		_cancel_choice()
		status_label.text = "Unable to start the expedition. Please try again."


func _cancel_choice() -> void:
	if _starting or not _choosing:
		return
	soundtrack.cue("click")
	_choosing = false
	captain_choice.hide()
	$Menu.show()
	$Controls.show()
	explore_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _choosing and not _starting and event.is_action_pressed("ui_cancel"):
		_cancel_choice()
		get_viewport().set_input_as_handled()


func _exit() -> void:
	soundtrack.save_volumes()
	get_tree().quit()
