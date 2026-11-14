extends Control

const ExpeditionState = preload("res://scripts/expedition.gd")
const STORY_SCENE := "res://scenes/opening_crawl.tscn"

@onready var expedition: ExpeditionState = get_node("/root/Expedition")
@onready var explore_button: Button = $Menu/Content/Actions/Explore
@onready var exit_button: Button = $Menu/Content/Actions/Exit
@onready var status_label: Label = $Menu/Content/Status

var _starting := false


func _ready() -> void:
	explore_button.grab_focus()


func _explore() -> void:
	if _starting:
		return
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
	get_tree().quit()
