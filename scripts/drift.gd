extends RefCounted
## Board geometry for Drift Circuit. Relays are fixed in board coordinates.

const POINTS_TO_WIN := 5
const ROUND_LIMIT := 12
const CENTER := 0
const SPLIT := 1
const LAYOUT_NAMES := ["Center relay", "Split relays"]


static func relays(layout: int, mirrored: bool) -> Array[Vector2i]:
	if layout == CENTER:
		return [Vector2i(2, 4), Vector2i(5, 5), Vector2i(8, 6)]
	if mirrored:
		return [Vector2i(5, 4), Vector2i(3, 6), Vector2i(7, 6)]
	return [Vector2i(3, 4), Vector2i(7, 4), Vector2i(5, 6)]


static func direction(row: int) -> int:
	match row:
		4: return 1
		6: return -1
	return 0


static func landing(square: Vector2i, width: int) -> Vector2i:
	return Vector2i(1 + posmod(square.x - 1 + direction(square.y), width), square.y)


static func feeder(relay: Vector2i, width: int) -> Vector2i:
	return Vector2i(1 + posmod(relay.x - 1 - direction(relay.y), width), relay.y)
