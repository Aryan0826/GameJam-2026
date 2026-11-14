extends RefCounted
## Short, skippable transmissions. Story consequences never alter match rules.

const CINDER := 2


static func line(role: String, text: String, system: int) -> Dictionary:
	var names := {"captain": "CAPTAIN VALERIA", "navigator": "NAVIGATOR SOL", "crew": "HORIZON CREW", "envoy": "CINDER / ENVOY VESPER" if system == CINDER else "KALYPSO / ENVOY LYRA"}
	return {"speaker": names[role], "role": role, "color": "#a6dfff" if role != "envoy" else "#ffc18c" if system == CINDER else "#a0edb4", "text": text}


static func terms(system: int, evil: bool = false, standing: String = "unknown") -> String:
	if evil:
		var objective := "Reach 8 total: relay points + surviving ships." if system == CINDER else "Hold the flag through 3 enemy turns, or eliminate their fleet."
		if standing == "captured":
			return objective + " Rematch only. This planet remains captured, whatever the result."
		if standing == "free":
			return objective + " Peaceful rematch only. This planet remains free, whatever the result."
		return objective + " Win: they surrender; capture the planet. Lose: withdraw and leave them in peace."
	if system == CINDER:
		return "Claim relays as the lanes shift. Reach 8 total: relay points + surviving ships. Win: navigation alliance. Lose: network access denied; marked Unproven."
	return "Hold the flag through 3 enemy turns, or eliminate their fleet. Win: alliance and landing clearance. Lose: landing denied; marked Unproven."


static func encounter(system: int, standing: String, seen: bool, evil: bool = false) -> Array[Dictionary]:
	if evil:
		return _conquest_encounter(system, standing, seen)
	if standing == "allied":
		return [line("envoy", "Horizon, our allies. Welcome back. Care for a friendly rematch? Your alliance is secure, whatever the result.", system)]
	if standing == "unproven":
		return [line("envoy", "The Horizon returns. Will this attempt end differently?", system), line("captain", "Let us find out.", system)]
	if seen:
		return [line("envoy", "Horizon, our invitation stands. Are you ready to accept the challenge?", system)]
	if system == CINDER:
		return [
			line("navigator", "Approaching Cinder. The surface is moving... and we’re receiving a transmission.", system),
			line("envoy", "Horizon. Nothing stands still here. Neither should your plans.", system),
			line("captain", "We seek an alliance.", system),
			line("envoy", "Then enter the Drift Circuit. Claim our relays as the lanes shift. Reach a combined total of eight relay points and surviving ships.", system),
			line("captain", "A test of timing.", system),
			line("envoy", "And foresight. Win, and our navigation network will recognize you as allies. Lose, and access is denied. You leave as you arrived, on your own.", system),
		]
	return [
		line("navigator", "Planetary signal ahead. They’ve detected us.", system),
		line("captain", "Hold position. Open a channel.", system),
		line("envoy", "Unknown vessel. You are approaching Kalypso.", system),
		line("captain", "This is the Horizon. We are explorers seeking peaceful contact.", system),
		line("envoy", "Then show us how you lead when the ground beneath you falls away.", system),
		line("envoy", "Hold our beacon through three opposing turns, or defeat our fleet. Succeed, and Kalypso will welcome your crew as allies.", system),
		line("captain", "And if we lose?", system),
		line("envoy", "You will be denied landing. Your vessel will be marked Unproven, and you must withdraw.", system),
		line("navigator", "Their terms are clear, Captain.", system),
	]


static func departure(system: int, evil: bool = false, standing: String = "unknown") -> Array[Dictionary]:
	if evil:
		if standing == "free":
			return [line("captain", "Our pact stands. Your world remains free. Horizon, withdraw.", system), line("envoy", "Then leave us in peace, Captain.", system)]
		if standing == "captured":
			return [line("captain", "This world is under our command. Horizon, set course for the next system.", system), line("envoy", "Our surrender stands. Your fleet may depart.", system)]
		return [line("captain", "Stand down the weapons. We will decide our next move beyond orbit.", system), line("envoy", "No challenge was fought. Our world remains our own.", system)]
	return [
		line("captain", "We’ll chart our own course for now." if system == CINDER else "We respect your boundary. The Horizon is withdrawing.", system),
		line("envoy", "Then watch the currents, Horizon." if system == CINDER else "Safe travels. Return when your crew is ready.", system),
	]


static func result(system: int, winner: int, previous_standing: String, evil: bool = false) -> Array[Dictionary]:
	if evil:
		return _conquest_result(system, winner, previous_standing)
	if previous_standing == "allied":
		return [line("envoy", "A fine match, Horizon. Our alliance stands. You will always find friends here.", system), line("captain", "Until our next visit. Safe skies.", system)]
	if winner < 0:
		return [line("envoy", "Neither fleet has prevailed. Our invitation stands.", system), line("captain", "Then we’ll meet again. Horizon, stand by for departure.", system)]
	if system == CINDER:
		if winner == 1:
			return [line("envoy", "You learned to move with the world instead of against it.", system), line("navigator", "Their navigation network is recognizing our signal.", system), line("captain", "Another world. Another ally.", system)]
		return [line("envoy", "The circuit has spoken. Network access is denied.", system), line("navigator", "Our signal is marked Unproven here.", system), line("captain", "Plot a withdrawal. We’re still explorers. We keep going.", system)]
	if winner == 1:
		return [line("envoy", "The arena broke. Your resolve did not.", system), line("captain", "Then we have earned your trust?", system), line("envoy", "You have. Kalypso stands with the Horizon.", system)]
	return [line("envoy", "The challenge is over. Landing clearance is denied.", system), line("navigator", "They’ve marked our transponder: Unproven.", system), line("captain", "Bring us back to flight. We’ll earn their trust another day.", system)]


static func epilogue(system: int, evil: bool = false) -> Array[Dictionary]:
	if evil:
		return [line("navigator", "Kalypso and Cinder have surrendered. Both worlds are under our command.", system), line("captain", "Two worlds captured. Signal the other captains. We sail for the next solar system.", system), line("crew", "The conquest continues.", system)]
	return [line("navigator", "Kalypso and Cinder both recognize our signal.", system), line("captain", "We came looking for new worlds.", system), line("crew", "And found people willing to stand beside us.", system), line("navigator", "Two worlds charted. Two alliances earned. Beyond them, another signal waits. The expedition continues.", system)]


static func _conquest_encounter(system: int, standing: String, seen: bool) -> Array[Dictionary]:
	if standing == "captured":
		return [line("envoy", "Horizon, our surrender stands. Our world is under your command. A rematch will not change that.", system)]
	if standing == "free":
		return [line("envoy", "You lost, Captain. You promised to leave us in peace. Any rematch is a game only; our world stays free.", system), line("captain", "Our pact stands. We make no claim on your world.", system)]
	if seen:
		return [line("captain", "Our demand stands. Kneel, or be annihilated.", system), line("envoy", "Then play our game. Lose, and leave us in peace. Win, and we surrender our world to your fleet.", system)]
	if system == CINDER:
		return [
			line("navigator", "Cinder ahead, Captain. Their navigation network has detected our fleet.", system),
			line("captain", "People of Cinder, kneel before the Horizon or be annihilated. Your world will join our conquest.", system),
			line("envoy", "Stay your weapons. Our people settle such demands in the Drift Circuit. Play our game.", system),
			line("captain", "Name your terms.", system),
			line("envoy", "If you lose, you withdraw and leave us in peace. If you win, we surrender. Our people and our world will be under your command.", system),
			line("captain", "Agreed. Your victory buys peace. Mine captures Cinder.", system),
			line("envoy", "Claim our relays as the lanes shift. Reach eight total: relay points plus surviving ships. Let the circuit decide our fate.", system),
		]
	return [
		line("navigator", "Kalypso has detected the fleet. Their envoy is opening a channel.", system),
		line("captain", "People of Kalypso, this is Captain Valeria of the Horizon. Kneel before our fleet or be annihilated.", system),
		line("envoy", "We will not bow to a threat. Before you fire, play our game: the Fractured Flag.", system),
		line("captain", "And what does your game offer a conqueror?", system),
		line("envoy", "If you lose, you leave our people in peace. If you win, we surrender. You may capture our world and command our people.", system),
		line("captain", "I accept. Win your freedom, or kneel when the game is over.", system),
		line("envoy", "Hold our beacon through three opposing turns, or defeat our fleet. Our world's fate rests on this challenge.", system),
	]


static func _conquest_result(system: int, winner: int, previous_standing: String) -> Array[Dictionary]:
	if previous_standing == "free":
		return [line("envoy", "The rematch is over. Our world remains free, as you promised.", system), line("captain", "A pact is a pact. We leave you in peace.", system)]
	if previous_standing == "captured":
		return [line("envoy", "The rematch is over. Our surrender stands.", system), line("captain", "This world remains under our command. Prepare the fleet to depart.", system)]
	if winner < 0:
		return [line("envoy", "Neither side prevailed. We have not surrendered. Our challenge still stands.", system), line("captain", "Stand down the weapons. This contest is unfinished.", system)]
	if winner == 1:
		return [line("envoy", "You have won. As agreed, we surrender our world and our people.", system), line("captain", "Your surrender is accepted. This planet is captured. You answer to the Horizon now.", system), line("navigator", "World secured. The fleet awaits your next course, Captain.", system)]
	return [line("envoy", "You lost, Captain. Honor our pact. Leave our people in peace.", system), line("captain", "We gave our word. This world stays free. Horizon, withdraw.", system), line("navigator", "Weapons offline. Mark this world free and plot a course away.", system)]
