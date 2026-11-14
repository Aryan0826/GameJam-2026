extends SceneTree
## Rebuild the How to play screenshots from actual board rendering and legal actions.
## Run in graphical mode: godot --path . --script tools/render_movement_guides.gd
const Board = preload("res://scripts/battle/board.gd")
const Rules = preload("res://scripts/rules/rules.gd")
const Drift = preload("res://scripts/rules/drift.gd")

class Arrows extends Control:
	var board: Control
	var actions: Array[Dictionary] = []
	const FONT = preload("res://art/fonts/IBMPlexMono-Regular.ttf")
	func _draw() -> void:
		var origin := Vector2i(5, 5)
		var start: Vector2 = board._project(origin)
		for action in actions:
			var end: Vector2 = board._project(action.to)
			var direction := (end - start).normalized()
			var color := Color("#ff937e") if action.kind == "capture" else Color("#83e1fa")
			var distance: int = maxi(absi(action.to.x - origin.x), absi(action.to.y - origin.y))
			# One arrow per direction; diagonal distance markers show both landing choices.
			if action.kind == "capture" or distance == 2 or action.to.x == origin.x or action.to.y == origin.y:
				var tip := end - direction * 19
				draw_line(start + direction * 22, tip, Color("#091924"), 7)
				draw_line(start + direction * 22, tip, color, 3)
				draw_colored_polygon(PackedVector2Array([tip + direction * 6, tip - direction * 5 + direction.orthogonal() * 6, tip - direction * 5 - direction.orthogonal() * 6]), color)
		# Draw markers after every arrow so diagonal lines cannot cross their numbers.
		for action in actions:
			var at: Vector2 = board._project(action.to)
			var capture: bool = action.kind == "capture"
			var color := Color("#ff937e") if capture else Color("#83e1fa")
			var distance: int = maxi(absi(action.to.x - origin.x), absi(action.to.y - origin.y))
			# Offset capture markers to keep enemy models visible.
			if capture: at += Vector2(0, -24)
			draw_circle(at, 13, Color("#091924"))
			draw_arc(at, 13, 0, TAU, 24, color, 2)
			draw_string(FONT, at + Vector2(-5, 6), "X" if capture else str(distance), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	root.size = Vector2i(1000, 700)
	root.content_scale_size = Vector2i(1000, 700)
	var background := ColorRect.new()
	background.color = Color("#091924")
	background.size = Vector2(1000, 700)
	root.add_child(background)
	var drift := "drift" in OS.get_cmdline_user_args()
	for capture in [false, true]:
		var board := Board.new()
		board.size = Vector2(1000, 700)
		board.motion = false
		root.add_child(board)
		board.camera_pitch = deg_to_rad(68)
		board.camera_yaw = 0
		board._update_camera()
		var state := Rules.create_drift_match(7, 1, Drift.CENTER, 0) if drift else Rules.create_match(7, 1)
		state.phase = "playing"
		state.active = 1
		state.dice[1] = "infected_trail"
		for id in state.pawns.keys():
			if id != 5 and (not capture or id not in [0, 1]): state.pawns.erase(id)
		state.pawns[5].pos = Vector2i(5, 5)
		if capture:
			state.pawns[0].pos = Vector2i(4, 4)
			state.pawns[1].pos = Vector2i(6, 4)
		board.state = state
		board.selected = 5
		var arrows := Arrows.new()
		arrows.board = board
		arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for action in Rules.legal_actions(state):
			if action.get("pawn", -1) == 5 and action.kind == ("capture" if capture else "step"):
				arrows.actions.append(action)
				board.targets[action.to] = action.kind
		assert(arrows.actions.size() == (2 if capture else 12), "The guide must show every legal move or both forward captures")
		board.sync()
		root.add_child(arrows)
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		var area := Rect2(board._project(Vector2i(3, 3)), Vector2.ZERO)
		for square in [Vector2i(3, 7), Vector2i(7, 3), Vector2i(7, 7)]:
			area = area.expand(board._project(square))
		area = area.grow(42)
		var planet := "drift" if drift else "kalypso"
		var filename := planet + ("-capture-guide.png" if capture else "-movement-guide.png")
		root.get_texture().get_image().get_region(Rect2i(area)).save_png("res://art/guides/" + filename)
		print("Captured %s with %d legal destinations." % [filename, arrows.actions.size()])
		board.queue_free()
		arrows.queue_free()
		await process_frame
	quit()
