extends Control
## A 3D arena rendered into the existing 2D HUD. Input uses camera rays to the tile plane.

signal square_pressed(square: Vector2i)

const Rules = preload("rules.gd")
const MONO = preload("res://art/IBMPlexMono-Regular.ttf")
const ROVER = preload("res://art/fleet/rover.glb")
const INTERCEPTOR = preload("res://art/fleet/craft-speederd.glb")
const DISH = preload("res://art/fleet/satellitedish-detailed.glb")
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
var power := 1.0
var viewport_3d: SubViewport
var world: Node3D
var camera: Camera3D
var tiles: Dictionary = {}
var pieces: Dictionary = {}
var landings: Dictionary = {}
var palette: Dictionary = {}
var tile_mesh: ArrayMesh
var rover_mesh: Mesh
var interceptor_mesh: Mesh
var unit_materials: Dictionary = {}
var flag_node: Node3D
var falling: Array[Node3D] = []


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_exited.connect(func():
		hover = Vector2i.ZERO
		queue_redraw())
	viewport_3d = SubViewport.new()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport_3d.size = Vector2i(size / 2.0)
	viewport_3d.transparent_bg = true
	viewport_3d.own_world_3d = true
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport_3d)
	world = Node3D.new()
	viewport_3d.add_child(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 35.0
	camera.position = Vector3(1.6, 8.0, 12.6)
	world.add_child(camera)
	camera.look_at(Vector3(0, -0.38, 0.28))
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
		"light": _material(Color("#204256"), 0.15), "dark": _material(Color("#183548"), 0.15),
		"flag": _material(Color("#85673b")), "crack": _material(Color("#7b3d4d")),
		"fracture": _material(Color("#743f76")), "infected": _material(Color("#584287")),
		"gold": _material(GOLD, 0.30)
	}
	tile_mesh = _platform_mesh()
	rover_mesh = _imported_mesh(ROVER)
	interceptor_mesh = _imported_mesh(INTERCEPTOR)
	_build_flag()


func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.48
	material.metallic = metallic
	return material


func _platform_mesh() -> ArrayMesh:
	var corners := PackedVector2Array([
		Vector2(-0.31, -0.47), Vector2(0.31, -0.47), Vector2(0.47, -0.31), Vector2(0.47, 0.31),
		Vector2(0.31, 0.47), Vector2(-0.31, 0.47), Vector2(-0.47, 0.31), Vector2(-0.47, -0.31)
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for i in corners.size():
		var a := corners[i]
		var b := corners[(i + 1) % corners.size()]
		var top_a := Vector3(a.x, TOP, a.y)
		var top_b := Vector3(b.x, TOP, b.y)
		var side_a := Vector3(a.x * 1.035, 0.05, a.y * 1.035)
		var side_b := Vector3(b.x * 1.035, 0.05, b.y * 1.035)
		var base_a := Vector3(a.x * 0.80, -0.21, a.y * 0.80)
		var base_b := Vector3(b.x * 0.80, -0.21, b.y * 0.80)
		for vertex: Vector3 in [Vector3.UP * TOP, top_a, top_b, top_b, top_a, side_a, top_b, side_a, side_b,
				side_b, side_a, base_a, side_b, base_a, base_b, Vector3.DOWN * 0.21, base_b, base_a]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()


func _imported_mesh(source: PackedScene) -> Mesh:
	var instance := source.instantiate()
	var model: MeshInstance3D = instance.find_children("*", "MeshInstance3D", true, false).front()
	var result := model.mesh
	instance.free()
	return result


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
	var receiver := _mesh(flag_node, _imported_mesh(DISH), palette.gold, Vector3.ZERO)
	receiver.scale = Vector3(0.9, 0.70, 0.9)
	receiver.rotation.y = PI * 0.24


func _new_unit(owner: int, at: Vector3) -> Node3D:
	var unit := Node3D.new()
	unit.position = at
	world.add_child(unit)
	var vehicle := _mesh(unit, interceptor_mesh if owner == 0 else rover_mesh, null, Vector3.ZERO)
	vehicle.scale = Vector3(0.258, 0.36, 0.258) if owner == 0 else Vector3(1.9, 1.05, 1.9)
	vehicle.position.y = 0.10 if owner == 0 else 0.0
	unit.rotation.y = PI if owner == 0 else 0.0
	return unit


func _paint_unit(unit: Node3D, side: int, dimmed: bool) -> void:
	var model: MeshInstance3D = unit.get_child(0)
	var key := "%s/%d/%s" % [model.mesh.resource_path, side, str(dimmed)]
	if key not in unit_materials:
		var paints: Array[StandardMaterial3D] = []
		for index in model.mesh.get_surface_count():
			var original: StandardMaterial3D = model.mesh.surface_get_material(index)
			var faction := NORTH if side == 0 else SOUTH
			var tint := original.albedo_color
			if tint.r - tint.b > 0.25:
				var livery := _material(faction.darkened(0.55) if dimmed else faction, 0.18)
				livery.emission_enabled = true
				livery.emission = faction
				livery.emission_energy_multiplier = 0.08 if dimmed else 0.34
				paints.append(livery)
			else:
				var hull := tint.lerp(faction.darkened(0.42), 0.29).darkened(0.12)
				paints.append(_material(hull.darkened(0.42) if dimmed else hull, 0.18))
		unit_materials[key] = paints
	for index in model.mesh.get_surface_count():
		model.set_surface_override_material(index, unit_materials[key][index])


func reset_visuals() -> void:
	landings.clear()
	for node in pieces.values() + tiles.values() + falling:
		if is_instance_valid(node):
			node.queue_free()
	falling.clear()
	tiles.clear()
	pieces.clear()


func power_on() -> void:
	power = 1.0
	if motion:
		power = 0.0
		create_tween().tween_property(self, "power", 1.0, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
		var destination := _world_at(pawn.pos)
		var model: Node3D
		if pawn.id in pieces:
			model = pieces[pawn.id]
		else:
			model = _new_unit(pawn.owner, destination)
			pieces[pawn.id] = model
		_paint_unit(model, pawn.side, state.phase == "draft" and pawn.side != state.active)
		if pawn.pos == state.flag:
			flag_node.visible = false
		if pawn.id not in landings:
			if model.get_meta("destination", Vector3.INF) != destination:
				model.position = destination
				model.set_meta("destination", destination)
			continue
		var path: Array = landings[pawn.id]
		landings.erase(pawn.id)
		model.position = _world_at(path[0].from)
		model.set_meta("destination", destination)
		var tween := create_tween().bind_node(model)
		for landing: Dictionary in path:
			_hop(tween, model, _world_at(landing.from), _world_at(landing.to),
				landing.kind == "capture", landing.teleport, path.size())
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
			var landing := event.duplicate()
			landing.teleport = event.pawn in teleported
			if event.pawn not in landings:
				landings[event.pawn] = []
			landings[event.pawn].append(landing)


func _hop(tween: Tween, model: Node3D, origin: Vector3, destination: Vector3, impact: bool, teleport: bool, segments: int) -> void:
	if teleport:
		tween.tween_property(model, "scale", Vector3.ONE * 0.09, 0.10)
		tween.tween_callback(func(): model.position = destination)
		tween.tween_property(model, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	var apex := origin.lerp(destination, 0.5) + Vector3.UP * (0.42 if impact else 0.23)
	var travel := destination - origin
	var bank := signf(travel.x) * -0.18
	var lift := 0.14 if segments == 1 else 0.11
	var settle := 0.19 if segments == 1 else 0.15
	tween.tween_property(model, "position", apex, lift).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(model, "rotation:z", bank, lift)
	tween.tween_property(model, "position", destination, settle).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(model, "rotation:z", 0.0, settle)


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
	return _project_world(_world_at(square, height))


func _project_world(point: Vector3) -> Vector2:
	return camera.unproject_position(point) * size / Vector2(viewport_3d.size)


func _square_at(local_pos: Vector2) -> Vector2i:
	var viewport_pos := local_pos * Vector2(viewport_3d.size) / size
	var ground = Plane(Vector3.UP, TOP).intersects_ray(camera.project_ray_origin(viewport_pos), camera.project_ray_normal(viewport_pos))
	if ground == null:
		return Vector2i.ZERO
	var square := Vector2i(floori(ground.x + 5.5), floori(ground.z + 5.5))
	if square.x < 1 or square.y < 1 or square.x > Rules.BOARD_SIZE or square.y > Rules.BOARD_SIZE:
		return Vector2i.ZERO
	return square


func _pick_square(local_pos: Vector2) -> Vector2i:
	var ground := _square_at(local_pos)
	if ground in targets or state.is_empty():
		return ground
	var closest := 13.0
	var picked := ground
	for pawn: Dictionary in state.pawns.values():
		var height := 0.31 if pawn.owner == 0 else 0.22
		var center := _project(pawn.pos, TOP + height)
		var distance := local_pos.distance_to(center)
		if distance < closest:
			picked = pawn.pos
			closest = distance
	return picked


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = _pick_square(event.position)
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var square := _pick_square(event.position)
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
	draw_texture_rect(viewport_3d.get_texture(), Rect2(Vector2.ZERO, size), false, Color(0.83, 1.0, 0.98, power))
	for y in range(38, int(size.y) - 28, 5):
		draw_line(Vector2(85, y), Vector2(size.x - 85, y), Color(0.025, 0.12, 0.17, 0.21))
	if power < 0.99:
		draw_line(Vector2(67, size.y * power), Vector2(size.x - 67, size.y * power), Color(0.40, 1.0, 0.93, (1.0 - power) * 0.8), 3)
	for i in range(1, Rules.BOARD_SIZE + 1):
		_text(_project_world(_world_at(Vector2i(i, 1)) + Vector3(0, 0, -0.76)) + Vector2(-4, 1), char(64 + i), 12)
		_text(_project_world(_world_at(Vector2i(1, i)) + Vector3(-0.90, 0, 0)) + Vector2(-4, 4), str(i), 12)
	for square: Vector2i in tiles:
		_pad_lights(square)
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
	var at := _world_at(pawn.pos)
	draw_line(_project_world(at + Vector3(-0.24, 0, 0.40)), _project_world(at + Vector3(0.24, 0, 0.40)),
		team.darkened(0.32) if state.phase == "draft" and pawn.side != state.active else team, 1.7, true)
	if pawn.id in [selected, second]:
		_outline(pawn.pos, team)
	var marker := _project_world(_world_at(pawn.pos) + Vector3(0.36, 0.12, -0.32))
	if pawn.id in draft_slots:
		_badge(marker, draft_slots[pawn.id], LILAC)
	if state.phase == "draft":
		return
	if pawn.charged:
		_badge(marker, SPELL_ICON[pawn.ability], LILAC)
	if pawn.shield:
		draw_arc(foot + Vector2(0, -13), 23, 0, TAU, 35, SOUTH, 2, true)
	if pawn.spy > 0:
		_badge(_project_world(_world_at(pawn.pos) + Vector3(-0.36, 0.12, -0.32)), str(pawn.spy), GOLD)
	if not pawn.borrow.is_empty():
		var origin := _project(pawn.borrow.origin)
		draw_dashed_line(origin, foot, LILAC, 1.8, 5)
		draw_arc(origin, 15, 0, TAU, 25, LILAC, 1.5, true)
		_text(origin + Vector2(-12, 4), "ECHO", 10, LILAC)


func _outline(square: Vector2i, color: Color) -> void:
	var points := PackedVector2Array()
	for corner: Vector3 in [Vector3(-0.46, 0, -0.46), Vector3(0.46, 0, -0.46), Vector3(0.46, 0, 0.46), Vector3(-0.46, 0, 0.46), Vector3(-0.46, 0, -0.46)]:
		points.append(_project_world(_world_at(square) + corner))
	draw_polyline(points, color, 1.6, true)


func _hazard(square: Vector2i, color: Color) -> void:
	var at := _world_at(square)
	var line := PackedVector2Array()
	for offset: Vector3 in [Vector3(-0.44, 0, -0.31), Vector3(-0.22, 0, -0.19), Vector3(-0.13, 0, 0.09),
			Vector3(0.07, 0, 0.02), Vector3(0.22, 0, 0.25), Vector3(0.43, 0, 0.39)]:
		line.append(_project_world(at + offset))
	draw_polyline(line, color, 1.5, true)
	draw_line(line[3], _project_world(at + Vector3(0.28, 0, -0.16)), color, 1.5, true)


func _pad_lights(square: Vector2i) -> void:
	var at := _world_at(square)
	var tint := Color("#4d9eab")
	if square == state.flag:
		tint = GOLD
	elif square in state.fractures:
		tint = LILAC
	elif square in state.cracks:
		tint = NORTH
	for direction in [-1.0, 1.0]:
		var start := _project_world(at + Vector3(0.14 * direction, 0, 0.40))
		var end := _project_world(at + Vector3(0.32 * direction, 0, 0.40))
		draw_line(start, end, tint, 1.4, true)


func _badge(point: Vector2, title: String, color: Color) -> void:
	draw_rect(Rect2(point - Vector2.ONE * 7, Vector2.ONE * 15), Color("#16192a"))
	draw_rect(Rect2(point - Vector2.ONE * 7, Vector2.ONE * 15), color, false, 1)
	_text(point + Vector2(-3, 4), title, 10, color)


func _text(point: Vector2, title: String, px: int, color: Color = Color("#b7c6e3")) -> void:
	draw_string(MONO, point, title, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
