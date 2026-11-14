extends Node
## Keeps the current destination across flight, cockpit, and battle scenes.

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
		"star_art": "res://art/system_two_star.png",
	},
]

var current_system: int = 0
var battle_outcomes: Dictionary = {}


func enter_system(index: int) -> void:
	current_system = clampi(index, 0, SYSTEMS.size() - 1)


func current_system_data() -> Dictionary:
	return SYSTEMS[current_system]


func has_next_system() -> bool:
	return current_system + 1 < SYSTEMS.size()


func next_system_name() -> String:
	return str(SYSTEMS[current_system + 1].name) if has_next_system() else ""


func next_system_scene() -> String:
	return str(SYSTEMS[current_system + 1].flight_scene) if has_next_system() else ""


func record_battle(winner: int) -> void:
	battle_outcomes[current_system] = winner


func reset_journey() -> void:
	current_system = 0
	battle_outcomes.clear()
