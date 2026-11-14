extends SceneTree

const Board = preload("../scripts/board.gd")
var failures := 0
var checks := 0
var clicks: Array[Vector2i] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _button(board: Control, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
	board._gui_input(event)


func _drag(board: Control, at: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.relative = relative
	board._gui_input(event)


func _run() -> void:
	var board := Board.new()
	board.size = Vector2(727, 519)
	root.add_child(board)
	board.square_pressed.connect(func(square: Vector2i): clicks.append(square))
	var center := board._project(Vector2i(5, 5))
	var original := board.camera.position
	_button(board, center, true)
	_check(clicks.is_empty(), "Press waits for release before selecting")
	_drag(board, center + Vector2(2, 1), Vector2(2, 1))
	_button(board, center + Vector2(2, 1), false)
	_check(clicks == [Vector2i(5, 5)], "Small pointer movement still selects the square")
	_check(board.camera.position.is_equal_approx(original), "Small pointer movement does not rotate")
	_button(board, center, true)
	_drag(board, center + Vector2(100, 40), Vector2(100, 40))
	_button(board, center + Vector2(100, 40), false)
	_check(clicks.size() == 1, "Dragging never selects a square")
	_check(not board.camera.position.is_equal_approx(original), "Dragging changes the camera angle")
	_check(is_equal_approx(board.camera.position.distance_to(board.CAMERA_TARGET), board.camera_distance), "Orbit preserves camera distance")
	for square in [Vector2i(1, 1), Vector2i(5, 5), Vector2i(9, 9)]:
		_check(board._square_at(board._project(square)) == square, "Ray picking matches projected square after rotation")
	center = board._project(Vector2i(5, 5))
	_button(board, center, true)
	_button(board, center, false)
	_check(clicks.size() == 2 and clicks.back() == Vector2i(5, 5), "Click selects correctly after rotation")
	_button(board, center, true)
	_drag(board, center + Vector2(0, 10000), Vector2(0, 10000))
	_check(is_equal_approx(board.camera_pitch, deg_to_rad(75)), "Upward tilt is limited")
	_drag(board, center - Vector2(0, 10000), Vector2(0, -20000))
	_check(is_equal_approx(board.camera_pitch, deg_to_rad(25)), "Downward tilt stays above the board")
	_button(board, Vector2(-20, -20), false)
	_check(not board.pointer_down and not board.orbiting and clicks.size() == 2, "Release outside ends orbit without selecting")
	_button(board, center, true)
	board._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_button(board, center, false)
	_check(not board.pointer_down and clicks.size() == 2, "Losing window focus cancels the pending click")
	board.queue_free()
	print("Board camera: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)
