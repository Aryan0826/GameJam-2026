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
		"planet_art": "res://art/flight/bodies/system_two_planet.png",
		"star_art": "res://art/flight/bodies/system_two_star.png", "planet_frame_size": 250,
	},
	{
		"name": "Cinder", "planet_name": "CINDER", "star_name": "SOLAR CORE",
		"flight_scene": "res://scenes/solar_system.tscn", "home": false,
		"star_color": Color(1.0, 0.85, 0.2),
		"planet_art": "res://art/flight/bodies/planet3.png", "star_art": "", "planet_frame_size": 100,
	},
]

var current_system: int = 0
var battle_outcomes: Dictionary = {}
var approach_system := -1
var departure_system := -1
var encounters_seen: Dictionary = {}
var planet_standings: Dictionary = {}
var descent_arrival := false
var evil_captain := false


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
		departure_system = -1
	return scene_error


func leave_orbit() -> Error:
	var destination := current_system
	var scene_error := fly_to(destination)
	if scene_error == OK:
		departure_system = destination
	return scene_error


func take_departure() -> int:
	var destination := departure_system
	departure_system = -1
	return destination


func take_approach() -> int:
	var destination := approach_system
	approach_system = -1
	return destination


func record_battle(winner: int) -> void:
	battle_outcomes[current_system] = winner
	if evil_captain:
		# A decisive challenge settles the planet's fate for this expedition.
		# Rematches honor both surrender and the promise to leave a free world in peace.
		if standing(current_system) in ["captured", "free"]:
			return
		if winner == 1:
			planet_standings[current_system] = "captured"
		elif winner == 0:
			planet_standings[current_system] = "free"
		return
	# Friendly rematches cannot revoke an earned alliance. A draw changes nothing.
	if winner == 1:
		planet_standings[current_system] = "allied"
	elif winner == 0 and standing(current_system) != "allied":
		planet_standings[current_system] = "unproven"


func standing(index: int) -> String:
	return str(planet_standings.get(index, "unknown"))


func all_allied() -> bool:
	return standing(0) == "allied" and standing(CINDER) == "allied"


func is_secured(index: int) -> bool:
	return standing(index) == ("captured" if evil_captain else "allied")


func all_secured() -> bool:
	return is_secured(0) and is_secured(CINDER)


func standing_label(index: int) -> String:
	match standing(index):
		"allied": return "Ally"
		"unproven": return "Unproven"
		"captured": return "Captured"
		"free": return "Free"
	return ""


func take_descent_arrival() -> bool:
	var arriving := descent_arrival
	descent_arrival = false
	return arriving


func reset_journey(as_evil_captain: bool = false) -> void:
	evil_captain = as_evil_captain
	current_system = 0
	approach_system = -1
	battle_outcomes.clear()
	departure_system = -1
	encounters_seen.clear()
	planet_standings.clear()
	descent_arrival = false
