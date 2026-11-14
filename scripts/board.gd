extends Control
## A 3D arena rendered into the existing 2D HUD. Input uses camera rays to the tile plane.

signal square_pressed(square: Vector2i)

const Rules = preload("rules.gd")
const MONO = preload("res://art/IBMPlexMono-Regular.ttf")
const NORTH = Color("#ff9479")
const SOUTH = Color("#73d9fa")
const GOLD = Color("#ffda8f")
const LILAC = Color("#bd9dff")
const SPELL_ICON = {"shield": "S", "fracture": "F", "teleport": "P", "borrow_tomorrow": "T"}
const TOP := 0.14

var state: Dictionary = {}
var targets: Dictionary = {}
var selected := -1
var second := -1
var preview_to := Vector2i.ZERO
var keyboard_square := Vector2i.ZERO
var hover := Vector2i.ZERO
var motion := true
var draft_slots: Dictionary = {}
var clock := 0.0
var viewport_3d: SubViewport
var world: Node3D
var camera: Camera3D
var tiles: Dictionary = {}
var pieces: Dictionary = {}
var landings: Dictionary = {}
var palette: Dictionary = {}
var tile_mesh: BoxMesh
var pawn_mesh: ArrayMesh
var flag_node: Node3D
var falling: Array[Node3D] = []


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_exited.connect(func():
		hover = Vector2i.ZERO
		queue_redraw())
	viewport_3d = SubViewport.new()
	viewport_3d.size = Vector2i(size)
	viewport_3d.transparent_bg = true
	viewport_3d.own_world_3d = true
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport_3d)
	world = Node3D.new()
	viewport_3d.add_child(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.45
	camera.position = Vector3(0, 12, 6.2)
	world.add_child(camera)
	camera.look_at(Vector3(0, 0, 0.11))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -32, 0)
	light.light_energy = 0.94
	light.shadow_enabled = true
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#a7b9e8")
	environment.environment.ambient_light_energy = 0.62
	world.add_child(environment)
	palette = {
		"light": _material(Color("#394e70")), "dark": _material(Color("#202f49")),
		"flag": _material(Color("#846739")), "crack": _material(Color("#7b3d4d")),
		"fracture": _material(Color("#743f76")), "infected": _material(Color("#584287")),
		"north": _material(NORTH.darkened(0.12), 0.22), "south": _material(SOUTH.darkened(0.11), 0.22),
		"north_dim": _material(NORTH.darkened(0.62)), "south_dim": _material(SOUTH.darkened(0.60)),
		"gold": _material(GOLD, 0.30)
	}
	tile_mesh = BoxMesh.new()
	tile_mesh.size = Vector3(0.967, 0.28, 0.967)
	pawn_mesh = _lathe()
	_build_flag()


func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.48
	material.metallic = metallic
	return material


func _lathe() -> ArrayMesh:
	var rings := PackedVector2Array([
		Vector2(0, 0), Vector2(0.29, 0), Vector2(0.32, 0.055), Vector2(0.32, 0.12),
		Vector2(0.29, 0.17), Vector2(0.23, 0.19), Vector2(0.19, 0.22),
		Vector2(0.125, 0.40), Vector2(0.13, 0.47), Vector2(0.21, 0.48),
		Vector2(0.21, 0.54), Vector2(0.13, 0.57), Vector2(0.14, 0.60),
		Vector2(0.179, 0.67), Vector2(0.175, 0.73), Vector2(0.13, 0.80), Vector2(0, 0.85)
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(rings.size() - 1):
		for i in 24:
			var a := i * TAU / 24.0
			var b := (i + 1) * TAU / 24.0
			var low_a := _vertex(rings[ring], a)
			var low_b := _vertex(rings[ring], b)
			var high_a := _vertex(rings[ring + 1], a)
			var high_b := _vertex(rings[ring + 1], b)
			for vertex in [low_a, low_b, high_a, high_a, low_b, high_b]:
				surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()


func _vertex(profile: Vector2, angle: float) -> Vector3:
	return Vector3(cos(angle) * profile.x, profile.y, sin(angle) * profile.x)


func _mesh(parent: Node3D, geometry: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	model.mesh = geometry
	model.material_override = material
	model.position = at
	parent.add_child(model)
	return model


func _build_flag() -> void:
	flag_node = Node3D.new()
	world.add_child(flag_node)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.035
	pole.bottom_radius = 0.045
	pole.height = 0.56
	_mesh(flag_node, pole, palette.gold, Vector3(-0.15, 0.29, 0))
	var pennant := PrismMesh.new()
	pennant.size = Vector3(0.30, 0.26, 0.055)
	var marker := _mesh(flag_node, pennant, palette.gold, Vector3(0.0, 0.44, 0))
	marker.rotation.z = -PI / 2.0
	var stand := CylinderMesh.new()
	stand.top_radius = 0.12
	stand.bottom_radius = 0.17
	stand.height = 0.06
	_mesh(flag_node, stand, palette.gold, Vector3(-0.15, 0.03, 0))


func reset_visuals() -> void:
	landings.clear()
	for node in pieces.values() + tiles.values() + falling:
		if is_instance_valid(node):
			node.queue_free()
	falling.clear()
	tiles.clear()
	pieces.clear()


func sync() -> void:
	if state.is_empty():
		return
	for y in range(1, Rules.BOARD_SIZE + 1):
		for x in range(1, Rules.BOARD_SIZE + 1):
			var square := Vector2i(x, y)
			if square in state.holes:
				if square in tiles:
					_remove_model(tiles[square], true)
					tiles.erase(square)
				continue
			if square not in tiles:
				tiles[square] = _mesh(world, tile_mesh, palette.dark, _world_at(square, 0.0))
			var key := "light" if (x + y) % 2 == 0 else "dark"
			if square == state.flag:
				key = "flag"
			elif square in state.fractures:
				key = "fracture"
			elif square in state.cracks:
				key = "crack"
			elif square in state.infected:
				key = "infected"
			tiles[square].material_override = palette[key]
	flag_node.position = _world_at(state.flag)
	flag_node.visible = true
	for id in pieces.keys():
		if id not in state.pawns:
			_remove_model(pieces[id], false)
			pieces.erase(id)
	for pawn: Dictionary in state.pawns.values():
		var key := "north" if pawn.side == 0 else "south"
		if state.phase == "draft" and pawn.side != state.active:
			key += "_dim"
		var destination := _world_at(pawn.pos)
		var model: MeshInstance3D
		if pawn.id in pieces:
			model = pieces[pawn.id]
		else:
			model = _mesh(world, pawn_mesh, palette[key], destination)
			pieces[pawn.id] = model
		model.material_override = palette[key]
		if pawn.pos == state.flag:
			flag_node.visible = false
		if pawn.id not in landings:
			if model.get_meta("destination", Vector3.INF) != destination:
				model.position = destination
				model.set_meta("destination", destination)
			continue
		var landing: Dictionary = landings[pawn.id]
		landings.erase(pawn.id)
		model.position = _world_at(landing.from)
		model.set_meta("destination", destination)
		_hop(model, destination, landing.kind == "capture", landing.get("teleport", false))
	queue_redraw()


func show_events(events: Array) -> void:
	landings.clear()
	if not motion:
		return
	var teleported := {}
	for event: Dictionary in events:
		if event.kind == "ability" and event.ability == "teleport":
			teleported[event.pawn] = true
		elif event.kind in ["step", "capture", "returned"]:
			landings[event.pawn] = event.duplicate()
			landings[event.pawn].teleport = event.pawn in teleported


func _hop(model: MeshInstance3D, destination: Vector3, impact: bool, teleport: bool) -> void:
	var tween := create_tween().bind_node(model)
	if teleport:
		tween.tween_property(model, "scale", Vector3.ONE * 0.09, 0.10)
		tween.tween_callback(func(): model.position = destination)
		tween.tween_property(model, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	var apex := model.position.lerp(destination, 0.5) + Vector3.UP * (0.55 if impact else 0.35)
	tween.tween_property(model, "position", apex, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "position", destination, 0.19).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _remove_model(model: Node3D, tile: bool) -> void:
	if not motion:
		model.queue_free()
		return
	falling.append(model)
	var tween := create_tween().bind_node(model).set_parallel()
	tween.tween_property(model, "position", model.position - Vector3.UP * 1.7, 0.46).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(model, "rotation", Vector3(0.38, 0.12, -0.35), 0.46)
	tween.tween_property(model, "scale", Vector3.ONE * (0.22 if tile else 0.02), 0.46)
	tween.chain().tween_callback(func():
		falling.erase(model)
		model.queue_free())


func _world_at(square: Vector2i, height: float = TOP) -> Vector3:
	return Vector3(square.x - 5, height, square.y - 5)


func _project(square: Vector2i, height: float = TOP) -> Vector2:
	return camera.unproject_position(_world_at(square, height))


func _square_at(local_pos: Vector2) -> Vector2i:
	var ground = Plane(Vector3.UP, TOP).intersects_ray(camera.project_ray_origin(local_pos), camera.project_ray_normal(local_pos))
	if ground == null:
		return Vector2i.ZERO
	var square := Vector2i(floori(ground.x + 5.5), floori(ground.z + 5.5))
	if square.x < 1 or square.y < 1 or square.x > Rules.BOARD_SIZE or square.y > Rules.BOARD_SIZE:
		return Vector2i.ZERO
	return square


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = _square_at(event.position)
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var square := _square_at(event.position)
		if square != Vector2i.ZERO:
			grab_focus()
			keyboard_square = Vector2i.ZERO
			square_pressed.emit(square)
			accept_event()


func _process(delta: float) -> void:
	if visible and not state.is_empty():
		clock += delta if motion else 0.0
		queue_redraw()


func _draw() -> void:
	if state.is_empty() or not is_instance_valid(camera):
		return
	draw_texture_rect(viewport_3d.get_texture(), Rect2(Vector2.ZERO, size), false)
	for i in range(1, Rules.BOARD_SIZE + 1):
		_text(_project(Vector2i(i, 1)) + Vector2(-4, -37), char(64 + i), 13)
		_text(_project(Vector2i(1, i)) + Vector2(-54, 3), str(i), 13)
	for square: Vector2i in state.cracks:
		_hazard(square, NORTH)
	for square: Vector2i in state.fractures:
		_hazard(square, LILAC)
	for square: Vector2i in state.infected:
		var point := _project(square)
		draw_arc(point, 14, 0, TAU, 24, LILAC, 1.3, true)
		draw_line(point + Vector2(-7, -7), point + Vector2(7, 7), LILAC, 1.5, true)
		draw_line(point + Vector2(-7, 7), point + Vector2(7, -7), LILAC, 1.5, true)
	for square: Vector2i in [hover, keyboard_square]:
		if square != Vector2i.ZERO:
			_outline(square, Color("#bfcee7"))
	for square: Vector2i in targets:
		var point := _project(square)
		match targets[square]:
			"capture", "mark", "fracture":
				_outline(square, NORTH if targets[square] == "capture" else LILAC)
				draw_arc(point, 19, clock, clock + TAU - 0.35, 30, NORTH if targets[square] == "capture" else LILAC, 2, true)
			_:
				draw_circle(point, 7, SOUTH, false, 2, true)
				draw_circle(point, 3, SOUTH, true, -1, true)
	if preview_to != Vector2i.ZERO and selected in state.pawns:
		draw_dashed_line(_project(state.pawns[selected].pos), _project(preview_to), LILAC, 2, 5)
		draw_circle(_project(preview_to), 15, LILAC, false, 2, true)
	for pawn: Dictionary in state.pawns.values():
		_pawn_status(pawn)
	if state.holder in state.pawns:
		var point := _project(state.flag) + Vector2(0, 7)
		for i in Rules.FLAG_REPLIES:
			var start := -PI + i * TAU / Rules.FLAG_REPLIES
			draw_arc(point, 23, start, start + TAU / Rules.FLAG_REPLIES - 0.16, 22, GOLD if i < state.replies else Color("#a5844a"), 2.2, true)
		_text(point + Vector2(-10, 25), "%d/%d" % [state.replies, Rules.FLAG_REPLIES], 11, GOLD)


func _pawn_status(pawn: Dictionary) -> void:
	var foot := _project(pawn.pos)
	var team := NORTH if pawn.side == 0 else SOUTH
	if pawn.id in [selected, second]:
		_outline(pawn.pos, team)
	if pawn.id in draft_slots:
		_badge(foot + Vector2(18, -23), draft_slots[pawn.id], LILAC)
	if state.phase == "draft":
		return
	if pawn.charged:
		_badge(foot + Vector2(18, -23), SPELL_ICON[pawn.ability], LILAC)
	if pawn.shield:
		draw_arc(foot + Vector2(0, -13), 23, 0, TAU, 35, SOUTH, 2, true)
	if pawn.spy > 0:
		_badge(foot + Vector2(-18, -23), str(pawn.spy), GOLD)
	if not pawn.borrow.is_empty():
		var origin := _project(pawn.borrow.origin)
		draw_dashed_line(origin, foot, LILAC, 1.8, 5)
		draw_arc(origin, 15, 0, TAU, 25, LILAC, 1.5, true)
		_text(origin + Vector2(-12, 4), "ECHO", 10, LILAC)


func _outline(square: Vector2i, color: Color) -> void:
	var points := PackedVector2Array()
	for corner: Vector3 in [Vector3(-0.46, 0, -0.46), Vector3(0.46, 0, -0.46), Vector3(0.46, 0, 0.46), Vector3(-0.46, 0, 0.46), Vector3(-0.46, 0, -0.46)]:
		points.append(camera.unproject_position(_world_at(square) + corner))
	draw_polyline(points, color, 1.6, true)


func _hazard(square: Vector2i, color: Color) -> void:
	var point := _project(square)
	var line := PackedVector2Array([point + Vector2(-26, -15), point + Vector2(-11, -8), point + Vector2(-6, 4),
		point + Vector2(5, 1), point + Vector2(13, 15), point + Vector2(25, 19)])
	draw_polyline(line, color, 1.5, true)
	draw_line(point + Vector2(5, 1), point + Vector2(16, -9), color, 1.5, true)


func _badge(point: Vector2, title: String, color: Color) -> void:
	draw_rect(Rect2(point - Vector2.ONE * 7, Vector2.ONE * 15), Color("#16192a"))
	draw_rect(Rect2(point - Vector2.ONE * 7, Vector2.ONE * 15), color, false, 1)
	_text(point + Vector2(-3, 4), title, 10, color)


func _text(point: Vector2, title: String, px: int, color: Color = Color("#b7c6e3")) -> void:
	draw_string(MONO, point, title, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
