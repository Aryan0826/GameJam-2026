extends Control
## Brief screen feedback drawn with Godot primitives; no image assets.

const LOSS := Color("#ff554f")
const CAPTURE := Color("#79efa0")
const DURATION := 0.46
const SHAKE := 4.0

var board: Control
var elapsed := DURATION
var delay := 0.0
var tone := LOSS
var strength := 0.0
var loss := false
var _board_rest := Vector2.ZERO
var _active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func play(is_loss: bool, wait: float = 0.0) -> void:
	stop()
	loss = is_loss
	tone = LOSS if loss else CAPTURE
	delay = wait
	elapsed = 0.0
	if board:
		_board_rest = board.position
	_active = true
	if delay <= 0.0 and loss:
		_rumble()
	set_process(true)


func respond(before: Dictionary, after: Dictionary, events: Array, view_side: int, enabled: bool) -> void:
	if not enabled:
		stop()
		return
	var removed := false
	var friendly_lost := false
	for id in before.pawns:
		if id not in after.pawns:
			removed = true
			friendly_lost = friendly_lost or before.pawns[id].side == view_side
	if not removed:
		return
	var friendly_capture := false
	var capture := false
	for event: Dictionary in events:
		if event.kind == "capture":
			capture = true
			friendly_capture = friendly_capture or before.pawns[event.pawn].side == view_side
	play(friendly_lost or not friendly_capture, 0.20 if capture else 0.08)


func _rumble() -> void:
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, 0.25, 0.4, 0.16)


func stop() -> void:
	if is_instance_valid(board) and _active:
		board.position = _board_rest
	_active = false
	elapsed = DURATION
	strength = 0.0
	for device in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)
	set_process(false)
	queue_redraw()


func _exit_tree() -> void:
	stop()


func _process(delta: float) -> void:
	if delay > 0.0:
		delay = maxf(0.0, delay - delta)
		if delay == 0.0 and loss:
			_rumble()
		return
	elapsed += delta
	if elapsed >= DURATION:
		stop()
		return
	# One quick blink with a smooth fade, rather than repeated flashes.
	strength = sin(minf(elapsed / 0.07, 1.0) * PI / 2.0) * pow(1.0 - elapsed / DURATION, 1.6)
	if board and loss:
		var decay := pow(1.0 - elapsed / DURATION, 2.0)
		board.position = _board_rest + Vector2(sin(elapsed * 105.0), sin(elapsed * 139.0)) * SHAKE * decay
	queue_redraw()


func _draw() -> void:
	if strength <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(tone, 0.06 * strength))
	for inset in range(0, 24, 3):
		var alpha := (1.0 - float(inset) / 24.0) * 0.32 * strength
		draw_rect(Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2), Color(tone, alpha), false, 3.0)
