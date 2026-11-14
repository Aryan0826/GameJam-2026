extends Node
## Keeps the current destination across flight, cockpit, and battle scenes.

const VERDANT_SYSTEM := 1
const CINDER := 2
const SYSTEMS: Array[Dictionary] = [
	{
		"name": "Kalypso", "planet_name": "KALYPSO", "star_name": "SOLAR CORE",
		"flight_scene": "res://scenes/solar_system.tscn", "home": true,
		"star_color": Color(1.0, 0.85, 0.2),
		"planet_art": "", "star_art": "",
	},
	{
		"name": "Azure Reach", "planet_name": "VERDANT", "star_name": "AZURE STAR",
		"flight_scene": "res://scenes/second_system.tscn", "home": false,
		"star_color": Color(0.45, 0.95, 1.0),
		"planet_art": "res://art/system_two_planet.png",
		"star_art": "res://art/system_two_star.png", "planet_frame_size": 250,
	},
	{
		"name": "Cinder", "planet_name": "CINDER", "star_name": "SOLAR CORE",
		"flight_scene": "res://scenes/solar_system.tscn", "home": false,
		"star_color": Color(1.0, 0.85, 0.2),
		"planet_art": "res://art/planet3.png", "star_art": "", "planet_frame_size": 100,
	},
]

var current_system: int = 0
var battle_outcomes: Dictionary = {}
var approach_system := -1


func enter_system(index: int) -> void:
	current_system = clampi(index, 0, SYSTEMS.size() - 1)


func current_system_data() -> Dictionary:
	return SYSTEMS[current_system]


func has_next_system() -> bool:
	return current_system == 0


func next_system_name() -> String:
	return str(SYSTEMS[CINDER].name) if has_next_system() else ""


func fly_to(index: int, close_approach: bool = false) -> Error:
	var scene_error := get_tree().change_scene_to_file(SYSTEMS[index].flight_scene)
	if scene_error == OK:
		approach_system = index if close_approach else -1
	return scene_error


func take_approach() -> int:
	var destination := approach_system
	approach_system = -1
	return destination


func record_battle(winner: int) -> void:
	battle_outcomes[current_system] = winner


func reset_journey() -> void:
	current_system = 0
	approach_system = -1
	battle_outcomes.clear()
