extends Control
## Fixed camera layers for the windshield and the rover's dashboard.

const PHOTO = preload("res://art/westerlund-2.jpg")
const ExpeditionState = preload("res://scripts/expedition.gd")
const PLANET = preload("res://art/cockpit/planet.png")
const MOON = preload("res://art/cockpit/moon.png")
const GIANT = preload("res://art/cockpit/giant.png")
const STAR = preload("res://art/cockpit/star.png")
const OUTER = preload("res://art/cockpit/outer.png")
const DECK = preload("res://art/cockpit/deck.png")
const GRILLE = preload("res://art/cockpit/grille.png")
const MONO = preload("res://art/IBMPlexMono-Regular.ttf")
const STEEL = Color("#354658")
const AQUA = Color("#81eada")
const AMBER = Color("#f0b17b")
const EDGE = Color("#677684")

@onready var expedition: ExpeditionState = get_node("/root/Expedition")

var mode := "approach"
var clearance := ""
var motion := true
var time := 0.0
var alert := 0.0
var stars: PackedVector2Array
var map_only := false
var envoy := false
var _planet_art: Texture2D = PLANET
var _star_art: Texture2D = STAR
var _planet_color: Color = Color("#eedcfa")
var _star_color: Color = Color("#ffcfac")
var _star_line_color: Color = Color(1.0, 0.66, 0.39, 0.30)
var _planet_name: String = "KALYPSO"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not envoy:
		_configure_system_art()
	var random := RandomNumberGenerator.new()
	random.seed = 3016
	for i in 100:
		stars.append(Vector2(random.randi_range(34, 1280), random.randi_range(24, 490)))


func _configure_system_art() -> void:
	var system_data: Dictionary = expedition.current_system_data()
	_planet_name = system_data.planet_name
	if str(system_data.planet_art).is_empty():
		return
	var planet_frame := AtlasTexture.new()
	planet_frame.atlas = load(str(system_data.planet_art)) as Texture2D
	planet_frame.region = Rect2(Vector2.ZERO, Vector2.ONE * float(system_data.planet_frame_size))
	_planet_art = planet_frame
	_planet_color = Color.WHITE
	if str(system_data.star_art).is_empty():
		return
	var star_frame := AtlasTexture.new()
	star_frame.atlas = load(str(system_data.star_art)) as Texture2D
	star_frame.region = Rect2(0, 0, 500, 500)
	_star_art = star_frame
	_star_color = Color.WHITE
	_star_line_color = Color(system_data.star_color, 0.3)


func _process(delta: float) -> void:
	if motion:
		time += delta
		alert = maxf(0, alert - delta)
	queue_redraw()


func _draw() -> void:
	if map_only:
		_draw_map()
		return
	if envoy:
		_draw_envoy()
		return
	var active := mode == "trial"
	var horizon := 241.0 if active else 595.0
	var window := Rect2(35, 18, 1250, horizon)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#101622"))
	draw_texture_rect(PHOTO, window, false, Color("#453b70"))
	draw_rect(window, Color(0.025, 0.018, 0.075, 0.42))
	for i in stars.size():
		var point := stars[i]
		point.x += floorf(sin(time * 0.14) * 6.0)
		if point.y < horizon:
			draw_rect(Rect2(point, Vector2.ONE * (2 if i % 8 == 0 else 1)), Color(0.72, 0.83, 1.0, 0.52))

	var drift := Vector2(roundf(sin(time * 0.23) * 10), roundf(cos(time * 0.19) * 6))
	var star_pos := Vector2(696, 89) if active else Vector2(631, 130)
	_body(_star_art, star_pos + drift * 0.3, 37 if active else 60, _star_color)
	draw_line(star_pos + Vector2(-29, 0), star_pos + Vector2(29, 0), _star_line_color, 1)
	_ringed(Vector2(1130, 96 if active else 143) + drift * 0.45, 52 if active else 89)
	_body(OUTER, Vector2(842, 64 if active else 102) - drift * 0.15, 19 if active else 34, Color("#b4c7ff"))

	var center := Vector2(937, 226) if active else Vector2(964, 337)
	center += drift
	var diameter := 270.0 if active else 440.0
	for i in range(4, 0, -1):
		draw_arc(center, diameter * 0.493 + 4 * i, -PI, 0.17, 90, Color(0.76, 0.37, 0.92, 0.055 * (5 - i)), 2)
	_body(_planet_art, center, diameter, _planet_color)
	draw_arc(center, diameter * 0.493, -2.8, -0.34, 90, Color(1.0, 0.54, 0.86, 0.52), 2)
	_body(MOON, center + Vector2(-193, -74) if not active else center + Vector2(-157, -59), 68 if not active else 43, Color("#bccbe5"))
	_windshield(horizon)
	_dashboard(horizon)

	if clearance == "land":
		_route(center, diameter, horizon)
	elif clearance == "detained":
		_patrol(Vector2(1136 + sin(time * 0.7) * 9.0, minf(333, horizon - 86)))
	elif alert > 0 and motion:
		var amount := 0.38 * alert
		draw_rect(Rect2(38, horizon - 8, 1244, 3), Color(1, 0.39, 0.26, amount))


func _body(sprite: Texture2D, center: Vector2, diameter: float, tint: Color = Color.WHITE) -> void:
	var side := Vector2.ONE * diameter
	draw_texture_rect(sprite, Rect2((center - side / 2.0).round(), side), false, tint)


func _ringed(center: Vector2, diameter: float) -> void:
	var arc := PackedVector2Array()
	for i in 49:
		var angle := i * TAU / 48
		var offset := Vector2(cos(angle) * diameter * 0.87, sin(angle) * diameter * 0.18).rotated(-0.27)
		arc.append((center + offset).round())
	draw_polyline(arc, Color("#c18b74"), 2)
	_body(GIANT, center, diameter, Color("#eec8ab"))
	draw_polyline(arc.slice(0, 25), Color("#d2a78e"), 2)


func _windshield(horizon: float) -> void:
	_poly([Vector2(0, 0), Vector2(1320, 0), Vector2(1320, 22), Vector2(1139, 22),
		Vector2(1098, 33), Vector2(231, 33), Vector2(185, 22), Vector2(0, 22)], Color("#273549"))
	draw_line(Vector2(230, 34), Vector2(1090, 34), EDGE, 2)
	_poly([Vector2(0, 0), Vector2(51, 0), Vector2(108, 34), Vector2(37, horizon), Vector2(0, horizon + 36)], Color("#1d293a"))
	_poly([Vector2(1320, 0), Vector2(1269, 0), Vector2(1212, 34), Vector2(1283, horizon), Vector2(1320, horizon + 36)], Color("#1d293a"))
	draw_line(Vector2(106, 34), Vector2(36, horizon), EDGE, 3)
	draw_line(Vector2(1213, 34), Vector2(1283, horizon), EDGE, 3)
	draw_line(Vector2(109, 31), Vector2(1212, 31), Color("#415467"), 1)
	for x in [19, 1284]:
		for y in [48, 78, 108]:
			draw_rect(Rect2(x, y, 14, 3), Color("#384858"))
	draw_line(Vector2(38, horizon - 2), Vector2(1282, horizon - 2), Color("#9d665d"), 2)


func _dashboard(horizon: float) -> void:
	var dash := Rect2(0, horizon + 6, 1320, maxf(0.0, 850.0 - horizon))
	draw_rect(dash, Color("#182231"))
	draw_texture_rect(DECK, dash, false, Color(0.40, 0.48, 0.65, 0.26))
	_poly([Vector2(0, horizon + 5), Vector2(1320, horizon + 5), Vector2(1320, horizon + 32),
		Vector2(1284, horizon + 37), Vector2(52, horizon + 37), Vector2(0, horizon + 28)], Color("#253546"))
	draw_line(Vector2(0, horizon + 7), Vector2(1320, horizon + 7), STEEL.lightened(0.15), 2)
	draw_line(Vector2(47, horizon + 32), Vector2(1272, horizon + 32), Color("#0b141f"), 2)
	for x in [18, 1248]:
		draw_texture_rect(GRILLE, Rect2(x, 781, 55, 42), false, Color("#4c5a70"))
	for x in [65, 120, 1140, 1210]:
		draw_rect(Rect2(x, horizon + 16, 22, 4), Color("#091320"))
		draw_rect(Rect2(x + 2, horizon + 17, 11, 2), Color("#7cafa8") if clearance != "detained" else AMBER)
	if mode != "trial":
		_draw_instruments()
	draw_rect(Rect2(0, 807, 1320, 43), Color("#121c2a"))
	draw_line(Vector2(0, 807), Vector2(1320, 807), STEEL, 2)


func _draw_instruments() -> void:
	var bezel := Rect2(803, 644, 409, 128)
	draw_rect(bezel, Color("#3c4756"))
	var display := bezel.grow(-10)
	draw_rect(display, Color("#0b1724"))
	_caption(Vector2(831, 676), "ORBIT HOLD", AQUA)
	_caption(Vector2(1052, 676), "COMM LINK", AQUA)
	for i in 9:
		draw_rect(Rect2(831 + 16 * i, 706, 12, 19), Color("#355762") if i > 5 else Color("#6eaea7"))
	var points := PackedVector2Array()
	for i in 37:
		points.append(Vector2(1053 + i * 3.45, 715 + roundf(sin(i * 0.54 + time * 2.0) * (3 + i % 7))))
	draw_polyline(points, AQUA, 1.5)
	for x in [810, 1203]:
		draw_rect(Rect2(x, 650, 3, 3), EDGE)
		draw_rect(Rect2(x, 763, 3, 3), EDGE)


func _route(center: Vector2, diameter: float, horizon: float) -> void:
	var target := center + Vector2(-24, -diameter * 0.32)
	var start := Vector2(1139, horizon - 27)
	var guide := PackedVector2Array([start, start + Vector2(-69, -37), target])
	draw_polyline(guide, Color(0.38, 0.96, 0.77, 0.25), 10)
	draw_dashed_line(guide[0], guide[1], AQUA, 2, 8)
	draw_dashed_line(guide[1], target, AQUA, 2, 8)
	draw_arc(target, 12 + fposmod(time * 12, 9), 0, TAU, 24, AQUA, 2)
	_caption(target + Vector2(23, -15), "LANDING CORRIDOR", AQUA)


func _patrol(at: Vector2) -> void:
	_poly([at + Vector2(-34, -12), at + Vector2(-10, -7), at + Vector2(0, -16),
		at + Vector2(10, -7), at + Vector2(34, -12), at + Vector2(24, 8),
		at + Vector2(0, 13), at + Vector2(-24, 8)], Color("#1a1528"))
	draw_rect(Rect2(at + Vector2(-15, 1), Vector2(30, 4)), Color("#ff785d"))
	_caption(at + Vector2(-66, 32), "PATROL INBOUND", AMBER)


func _draw_map() -> void:
	var origin := Vector2(296, 132)
	for i in [65.0, 114.0, 176.0, 235.0]:
		var orbit := PackedVector2Array()
		for step in 97:
			var angle := step * TAU / 96
			orbit.append(origin + Vector2(cos(angle), sin(angle) * 0.38) * i)
		draw_polyline(orbit, Color("#40556d"), 1, true)
	_body(_star_art, origin, 49)
	_body(_planet_art, origin + Vector2(-91, -25), 42)
	_body(MOON, origin + Vector2(-123, -43), 15)
	_ringed(origin + Vector2(110, -52), 31)
	_body(OUTER, origin + Vector2(219, 33), 26)
	var rover := origin + Vector2(-57, -50)
	_poly([rover + Vector2(-5, 4), rover + Vector2(0, -6), rover + Vector2(5, 4)], AQUA)
	draw_dashed_line(rover + Vector2(8, 0), rover + Vector2(62, 0), AQUA, 1, 3)
	_caption(rover + Vector2(68, 4), "HORIZON", AQUA)
	_caption(origin + Vector2(-193, -46), _planet_name, AMBER)
	_caption(origin + Vector2(-11, 40), "LOCAL STAR", AMBER)


func _draw_envoy() -> void:
	draw_rect(Rect2(0, 0, 78, 68), Color("#181f33"))
	var portrait: Array[String] = [
		"     112211     ", "   1123333211   ", "  123334433321  ",
		" 1233444443321 ", " 1232344432321 ", " 1232544452321 ",
		"  12344443321  ", "  12324423321  ", "   123223321   ",
		"    1223321    ", "    1122211    ", " 1111122211111 ",
	]
	var colors := [Color("#1d253c"), Color("#585174"), Color("#956c8b"), Color("#c593a5"), AMBER]
	for y in portrait.size():
		for x in portrait[y].length():
			var symbol := portrait[y].substr(x, 1)
			if symbol != " ":
				draw_rect(Rect2(8 + x * 4, 6 + y * 4, 4, 4), colors[int(symbol) - 1])
	for y in range(5, 68, 5):
		draw_line(Vector2(0, y), Vector2(78, y), Color(0.1, 0.07, 0.2, 0.3))
	draw_rect(Rect2(0, 0, 78, 68), Color("#58617a"), false, 1)


func _caption(at: Vector2, caption: String, color: Color) -> void:
	draw_string(MONO, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)
