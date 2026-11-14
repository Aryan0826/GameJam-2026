extends RefCounted
## Short, skippable transmissions. Story consequences never alter match rules.

const CINDER := 2


static func line(role: String, text: String, system: int) -> Dictionary:
	var names := {"captain": "CAPTAIN VALERIA", "navigator": "NAVIGATOR SOL", "crew": "HORIZON CREW", "envoy": "CINDER / ENVOY VESPER" if system == CINDER else "KALYPSO / ENVOY LYRA"}
	return {"speaker": names[role], "role": role, "color": "#a6dfff" if role != "envoy" else "#ffc18c" if system == CINDER else "#a0edb4", "text": text}


static func terms(system: int) -> String:
	if system == CINDER:
		return "Claim relays as the lanes shift. Reach 8 total: relay points + surviving ships. Win: navigation alliance. Lose: network access denied; marked Unproven."
	return "Hold the flag through 3 enemy turns, or eliminate their fleet. Win: alliance and landing clearance. Lose: landing denied; marked Unproven."


static func encounter(system: int, standing: String, seen: bool) -> Array[Dictionary]:
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


static func departure(system: int) -> Array[Dictionary]:
	return [
		line("captain", "We’ll chart our own course for now." if system == CINDER else "We respect your boundary. The Horizon is withdrawing.", system),
		line("envoy", "Then watch the currents, Horizon." if system == CINDER else "Safe travels. Return when your crew is ready.", system),
	]


static func result(system: int, winner: int, already_allied: bool) -> Array[Dictionary]:
	if already_allied:
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


static func epilogue(system: int) -> Array[Dictionary]:
	return [line("navigator", "Kalypso and Cinder both recognize our signal.", system), line("captain", "We came looking for new worlds.", system), line("crew", "And found people willing to stand beside us.", system), line("navigator", "Two worlds charted. Two alliances earned. Beyond them, another signal waits. The expedition continues.", system)]
