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

var _starting := false


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
	if _starting:
		return
	soundtrack.music("flight")
	soundtrack.cue("click")
	soundtrack.save_volumes()
	_starting = true
	explore_button.disabled = true
	exit_button.disabled = true
	expedition.reset_journey()
	var scene_error := get_tree().change_scene_to_file(STORY_SCENE)
	if scene_error != OK:
		_starting = false
		explore_button.disabled = false
		exit_button.disabled = false
		status_label.text = "Unable to start the expedition. Please try again."
		explore_button.grab_focus()


func _exit() -> void:
	soundtrack.save_volumes()
	get_tree().quit()
