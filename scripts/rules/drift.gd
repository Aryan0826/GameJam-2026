extends RefCounted
## Board geometry for Drift Circuit. Relays move after a claim.

const TOTAL_TO_WIN := 8
const ROUND_LIMIT := 12
const CENTER := 0
const SPLIT := 1


static func relays(layout: int, mirrored: bool) -> Array[Vector2i]:
	if layout == CENTER:
		return [Vector2i(2, 4), Vector2i(5, 5), Vector2i(8, 6)]
	if mirrored:
		return [Vector2i(7, 4), Vector2i(2, 5), Vector2i(3, 6)]
	return [Vector2i(3, 4), Vector2i(8, 5), Vector2i(7, 6)]


static func direction(row: int) -> int:
	match row:
		4: return 1
		6: return -1
	return 0


static func landing(square: Vector2i, width: int) -> Vector2i:
	return Vector2i(1 + posmod(square.x - 1 + direction(square.y), width), square.y)


static func feeder(relay: Vector2i, width: int) -> Vector2i:
	return Vector2i(1 + posmod(relay.x - 1 - direction(relay.y), width), relay.y)


static func relocate(relay: Vector2i, width: int, occupied: Dictionary) -> Vector2i:
	# Start across the ring. Prefer a clear relay and approach square.
	var fallback := Vector2i.ZERO
	var half := floori(width * 0.5)
	var across := Vector2i(1 + posmod(relay.x - 1 + half, width), relay.y)
	for distance in range(half, 0, -1):
		for sign_x in [1, -1]:
			var candidate := Vector2i(1 + posmod(relay.x - 1 + distance * sign_x, width), relay.y)
			if candidate in occupied:
				continue
			if feeder(candidate, width) not in occupied:
				return candidate
			if fallback == Vector2i.ZERO:
				fallback = candidate
	# Crowded rows can have a blocked approach, or every square occupied.
	return across if fallback == Vector2i.ZERO else fallback
