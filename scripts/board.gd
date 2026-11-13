extends Control

signal square_pressed(square: Vector2i)
signal square_hovered(square: Vector2i)

const MONO = preload("res://art/IBMPlexMono-Regular.ttf")
const PAWN = preload("res://art/pawn.svg")
const CELL = 70.0
const ORIGIN = Vector2(76, 58)
const NORTH = Color("#ff937e")
const SOUTH = Color("#83e1fa")
const FLAG = Color("#f8d587")
const LILAC = Color("#b99dfd")
const SPELL_ICON = {"shield": "S", "blink": "B", "sprint": "R", "borrow_tomorrow": "T"}

var state: Dictionary = {}
var targets: Dictionary = {}
var selected := -1
var second := -1
var preview_to := Vector2i.ZERO
var marked := -1
var keyboard_square := Vector2i.ZERO
var hover := Vector2i.ZERO
var effects: Array[Dictionary] = []
var motion := true
var clock := 0.0
var draft_slots: Dictionary = {}


func _ready() -> void:
	mouse_exited.connect(func(): hover = Vector2i.ZERO)
	focus_mode = Control.FOCUS_ALL


func _process(delta: float) -> void:
	if motion:
		clock += delta
		while not effects.is_empty() and clock - effects.front().start > 0.63:
			effects.pop_front()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p := _square_at(event.position)
		if p != hover:
			hover = p
			square_hovered.emit(p)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := _square_at(event.position)
		if p != Vector2i.ZERO:
			grab_focus()
			keyboard_square = Vector2i.ZERO
			square_pressed.emit(p)
			accept_event()


func show_events(events: Array) -> void:
	if not motion:
		return
	for event: Dictionary in events:
		if event.kind in ["step", "capture", "returned", "return_failed", "shield_break", "collapse", "infection", "spy", "ability", "flag"]:
			var visual := event.duplicate()
			visual.start = clock
			effects.append(visual)


func _square_at(local_pos: Vector2) -> Vector2i:
	var p := Vector2i((local_pos - ORIGIN).floor() / CELL).clamp(Vector2i.ZERO, Vector2i(8, 7)) + Vector2i.ONE
	if Rect2(ORIGIN, Vector2(9, 8) * CELL).has_point(local_pos):
		return p
	return Vector2i.ZERO


func center(p: Vector2i) -> Vector2:
	return ORIGIN + Vector2(p - Vector2i.ONE) * CELL + Vector2.ONE * CELL / 2.0


func _mono(at: Vector2, value: String, size_px: int, color: Color) -> void:
	draw_string(MONO, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _draw() -> void:
	if state.is_empty():
		return
	var draft: bool = state.phase == "draft"
	var frame := Rect2(ORIGIN - Vector2(6, 6), Vector2(9, 8) * CELL + Vector2(12, 12))
	draw_rect(frame, Color("#101624"))
	draw_rect(frame, Color("#52607a"), false, 1)
	for x in range(1, 10):
		_mono(center(Vector2i(x, 1)) + Vector2(-4, -44), char(64 + x), 12, Color("#a9b4ce"))
	for y in range(1, 9):
		_mono(center(Vector2i(1, y)) + Vector2(-54, 5), str(y), 12, Color("#a9b4ce"))
		for x in range(1, 10):
			_draw_tile(Vector2i(x, y))

	if not draft:
		for pawn: Dictionary in state.pawns.values():
			if not pawn.borrow.is_empty():
				var origin: Vector2 = center(pawn.borrow.origin)
				draw_dashed_line(origin, center(pawn.pos), LILAC, 2, 6)
				draw_arc(origin, 23, 0.0, TAU, 32, LILAC, 2, true)
				_mono(origin + Vector2(-14, 5), "ECHO", 10, LILAC)

	for p: Vector2i in targets:
		var c := center(p)
		if targets[p] == "capture" or targets[p] == "mark":
			draw_arc(c, 25, 0.0, TAU, 36, Color("#ffad97") if targets[p] == "capture" else LILAC, 2.5, true)
			for angle in [0.0, PI / 2.0, PI, PI * 1.5]:
				var spoke := Vector2.from_angle(angle)
				draw_line(c + spoke * 23, c + spoke * 30, Color("#ffad97") if targets[p] == "capture" else LILAC, 2, true)
		else:
			draw_circle(c, 10, Color("#aaf5ff"), false, 1.8, true)
			draw_circle(c, 4, Color("#aaf5ff"), true, -1, true)

	if preview_to != Vector2i.ZERO and selected in state.pawns:
		var pawn: Dictionary = state.pawns[selected]
		draw_dashed_line(center(pawn.pos), center(preview_to), LILAC, 2, 5)
		_draw_piece(pawn, center(preview_to), 0.45, false)

	for pawn: Dictionary in state.pawns.values():
		var tint := 1.0
		if draft and pawn.side != state.active:
			tint = 0.43
		_draw_piece(pawn, _animated_center(pawn), tint, not draft)

	if state.holder in state.pawns:
		var holder: Dictionary = state.pawns[state.holder]
		var point := center(holder.pos)
		for i in range(2):
			var start := -PI + i * PI + 0.15
			var end := start + PI - 0.3
			draw_arc(point, 30, start, end, 28, FLAG if i < state.replies else Color("#866e49"), 3, true)
		_mono(point + Vector2(-9, 30), "%d/2" % state.replies, 11, FLAG)

	for fx in effects:
		_draw_effect(fx)


func _draw_tile(p: Vector2i) -> void:
	var c := center(p)
	var tile := Rect2(c - Vector2.ONE * 34, Vector2.ONE * 68)
	if p in state.holes:
		draw_rect(tile, Color("#0a0e18"))
		draw_rect(tile.grow(-1), Color("#242d42"), false, 1)
		draw_line(c - Vector2.ONE * 6, c + Vector2.ONE * 6, Color("#384156"), 1, true)
		draw_line(c + Vector2(-6, 6), c + Vector2(6, -6), Color("#384156"), 1, true)
		return
	var base := Color("#273953") if (p.x + p.y) % 2 == 0 else Color("#1e2d44")
	var edge := Color("#3c4b64")
	if p.x >= 3 and p.x <= 7 and p.y >= 3 and p.y <= 6:
		base = base.lightened(0.055)
	if p in state.cracks:
		base = Color("#402b39")
		edge = Color("#99606a")
	if p in state.infected:
		base = Color("#493763")
		edge = LILAC
	if p == state.flag:
		base = Color("#514434")
		edge = FLAG
	if p in state.portals:
		base = Color("#382e52")
		edge = Color("#7b68a6")
	draw_rect(tile, base)
	draw_rect(tile, edge, false, 1)
	draw_line(tile.position + Vector2(4, 3), tile.position + Vector2(18, 3), edge.lightened(0.15), 1)
	if p in state.cracks:
		var path := PackedVector2Array([c + Vector2(-32, -16), c + Vector2(-18, -8), c + Vector2(-8, 9), c + Vector2(5, 6), c + Vector2(14, 23), c + Vector2(31, 28)])
		draw_polyline(path, Color("#f19583"), 1.4, true)
		draw_line(c + Vector2(5, 6), c + Vector2(14, -8), Color("#f19583"), 1.4, true)
	if p in state.infected:
		for i in range(6):
			var spot := c + Vector2.from_angle(i * TAU / 6.0) * 19
			draw_circle(spot, 2.8, LILAC, true, -1, true)
			draw_line(spot, c, Color("#947bb7"), 1, true)
	if p in state.portals:
		draw_arc(c, 20, clock * 0.8, clock * 0.8 + TAU - 0.5, 40, LILAC, 1.4, true)
		draw_arc(c, 13, -clock - 0.8, -clock + TAU - 1.4, 32, Color("#8b78c4"), 1.3, true)
		draw_circle(c, 3, LILAC, true, -1, true)
	if p == state.flag and state.holder == -1:
		draw_line(c + Vector2(-8, 15), c + Vector2(-8, -16), FLAG, 2.3, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -15), c + Vector2(15, -15), c + Vector2(8, -8), c + Vector2(15, 0), c + Vector2(-7, 0)]), FLAG)
		draw_line(c + Vector2(-14, 15), c + Vector2(-2, 15), FLAG, 2.0, true)
	if p == hover or p == keyboard_square:
		draw_rect(tile.grow(-2), Color("#c8d7eb"), false, 1.5)


func _animated_center(pawn: Dictionary) -> Vector2:
	for i in range(effects.size() - 1, -1, -1):
		var fx := effects[i]
		if fx.get("pawn", -1) == pawn.id and fx.kind in ["step", "capture", "returned"] and fx.has("from") and fx.has("to") and fx.to == pawn.pos:
			var t := clampf((clock - fx.start) / 0.27, 0.0, 1.0)
			return center(fx.from).lerp(center(fx.to), 1.0 - pow(1.0 - t, 3.0))
	return center(pawn.pos)


func _draw_piece(pawn: Dictionary, c: Vector2, alpha: float, show_status: bool) -> void:
	var color := NORTH if pawn.side == 0 else SOUTH
	color.a = alpha
	var focused: bool = pawn.id in [selected, second, marked]
	if focused:
		draw_circle(c, 29, Color(color, 0.17), true, -1, true)
		draw_arc(c, 29, 0.0, TAU, 40, color, 2, true)
	draw_circle(c + Vector2(1, 3), 22, Color(0.025, 0.04, 0.08, alpha * 0.9), true, -1, true)
	draw_circle(c, 22, Color(color.darkened(0.77), alpha), true, -1, true)
	draw_arc(c, 22, 0.0, TAU, 38, Color(color, alpha * 0.64), 1, true)
	var pawn_image := Rect2(c - Vector2(15, 17), Vector2(30, 30))
	draw_texture_rect(PAWN, pawn_image, false, color)
	var direction := 1.0 if pawn.side == 0 else -1.0
	var tip := c + Vector2(0, 17 * direction)
	draw_line(tip + Vector2(-3, -2 * direction), tip + Vector2(0, direction), color, 1, true)
	draw_line(tip + Vector2(3, -2 * direction), tip + Vector2(0, direction), color, 1, true)
	if pawn.id in draft_slots:
		_badge(c + Vector2(19, -16), draft_slots[pawn.id], LILAC)
	if not show_status:
		return
	if pawn.charged:
		_badge(c + Vector2(19, -16), SPELL_ICON.get(pawn.ability, "?"), LILAC if not pawn.spy else Color("#9ca4b7"))
	if pawn.shield:
		draw_arc(c, 26, 0.0, TAU, 36, SOUTH, 2, true)
		_badge(c + Vector2(-19, -16), "S", SOUTH)
	if pawn.spy:
		_badge(c + Vector2(-19, 16), "X", NORTH)
	if not pawn.borrow.is_empty():
		_badge(c + Vector2(19, 16), "T", LILAC)


func _badge(at: Vector2, letter: String, color: Color) -> void:
	draw_rect(Rect2(at - Vector2.ONE * 7, Vector2.ONE * 15), Color("#16192a"))
	draw_rect(Rect2(at - Vector2.ONE * 7, Vector2.ONE * 15), color, false, 1)
	_mono(at + Vector2(-3, 4), letter, 10, color)


func _draw_effect(fx: Dictionary) -> void:
	var t := clampf((clock - fx.start) / 0.62, 0.0, 1.0)
	if fx.kind == "collapse":
		for p: Vector2i in fx.get("tiles", []):
			var c := center(p)
			draw_rect(Rect2(c - Vector2.ONE * 34, Vector2.ONE * 68), Color(NORTH, (1.0 - t) * 0.49))
			for i in range(5):
				var direction := Vector2.from_angle(i * TAU / 5.0)
				draw_circle(c + direction * (10 + 29 * t), 3 * (1.0 - t), Color(NORTH, 1.0 - t), true, -1, true)
	elif fx.has("to"):
		var color := NORTH if fx.kind in ["capture", "shield_break"] else LILAC
		draw_arc(center(fx.to), 15 + 27 * t, 0, TAU, 36, Color(color, (1.0 - t) * 0.9), 2.5, true)
