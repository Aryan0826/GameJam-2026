extends Node
## Shared music and short cues. The flight engine stays with its scene.

const OBSERVING = preload("res://art/audio/observing-the-star.ogg")
const DEAD_SHIP = preload("res://art/audio/my-very-own-dead-ship.ogg")
const ENGINE = preload("res://art/audio/rocket-thrust.ogg")
const SETTINGS := "user://audio.cfg"
const CUES := {
	"click": [preload("res://art/audio/click.ogg"), -19.0],
	"select": [preload("res://art/audio/select.ogg"), -19.0],
	"confirm": [preload("res://art/audio/confirm.ogg"), -16.0],
	"transmission": [preload("res://art/audio/transmission.ogg"), -23.0],
	"infection": [preload("res://art/audio/infected-trail.ogg"), -12.0],
	"descent": [preload("res://art/audio/descent.ogg"), -17.0],
	"move": [preload("res://art/audio/move.ogg"), -17.0],
	"capture": [preload("res://art/audio/capture.ogg"), -14.0],
	"collapse": [preload("res://art/audio/collapse.ogg"), -17.0],
	"lane_shift": [preload("res://art/audio/lane-shift.ogg"), -16.0],
	"shield": [preload("res://art/audio/shield.ogg"), -19.0],
	"teleport": [preload("res://art/audio/teleport.ogg"), -18.0],
	"spy": [preload("res://art/audio/spy.ogg"), -17.0],
	"relay": [preload("res://art/audio/relay.ogg"), -13.0],
	"shuffle": [preload("res://art/audio/shuffle.ogg"), -16.0],
	"card_reveal": [preload("res://art/audio/card-reveal.ogg"), -15.0],
	"victory": [preload("res://art/audio/victory.ogg"), -14.0],
	"defeat": [preload("res://art/audio/defeat.ogg"), -14.0],
}

var _music: Array[AudioStreamPlayer] = []
var _music_index := -1
var _music_fade: Tween
var _music_stream: AudioStream
var _effects: Dictionary = {}
var _settings := ConfigFile.new()
var _muted := false
var _save_timer: Timer


func _ready() -> void:
	_settings.load(SETTINGS)
	for bus in ["Music", "Effects"]:
		_apply_volume(bus, volume(bus))
	_muted = bool(_settings.get_value("audio", "muted", false))
	AudioServer.set_bus_mute(0, _muted)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.25
	_save_timer.timeout.connect(save_volumes)
	add_child(_save_timer)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		add_child(player)
		_music.append(player)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_M and event.pressed and not event.echo:
		_muted = not _muted
		_settings.set_value("audio", "muted", _muted)
		AudioServer.set_bus_mute(0, _muted)
		save_volumes()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	stop_music()
	for player: AudioStreamPlayer in _effects.values():
		player.stop()


func volume(bus: String) -> float:
	return clampf(float(_settings.get_value("audio", bus, 0.8)), 0.0, 1.0)


func set_volume(bus: String, value: float) -> void:
	_settings.set_value("audio", bus, value)
	_apply_volume(bus, value)
	_save_timer.start()


func save_volumes() -> void:
	_save_timer.stop()
	_settings.save(SETTINGS)


func _apply_volume(bus: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, is_zero_approx(value))
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))


func music(context: String) -> void:
	var stream: AudioStreamOggVorbis = DEAD_SHIP if context == "arena" else OBSERVING
	var target := -19.0 if context == "arena" else -16.0
	if _music_fade:
		_music_fade.kill()
	_music_fade = create_tween().set_parallel()
	if stream == _music_stream:
		if not _music[_music_index].playing:
			_music[_music_index].play()
		_music_fade.tween_property(_music[_music_index], "volume_db", target, 0.35)
		_fade_out(_music[1 - _music_index])
		return
	var previous := _music_index
	_music_index = 0 if previous < 0 else 1 - previous
	_music_stream = stream
	var current := _music[_music_index]
	stream.loop = true
	current.stream = stream
	current.volume_db = -48.0
	current.play()
	_music_fade.tween_property(current, "volume_db", target, 0.65)
	if previous >= 0:
		_fade_out(_music[previous])


func stop_music() -> void:
	if _music_fade:
		_music_fade.kill()
	_music_stream = null
	for player in _music:
		player.stop()


func _fade_out(player: AudioStreamPlayer) -> void:
	if player.playing:
		_music_fade.tween_property(player, "volume_db", -48.0, 0.65)
		_music_fade.chain().tween_callback(player.stop)


func cue(name: String) -> void:
	if name not in _effects:
		var clip: Array = CUES[name]
		var player := AudioStreamPlayer.new()
		player.bus = &"Effects"
		player.stream = clip[0]
		player.volume_db = clip[1]
		add_child(player)
		_effects[name] = player
	_effects[name].play()


func stop_cue(name: String) -> void:
	if name in _effects:
		_effects[name].stop()


func flight_engine(scene: Node) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"Effects"
	var loop := ENGINE.duplicate() as AudioStreamOggVorbis
	loop.loop = true
	player.stream = loop
	player.volume_db = -60.0
	scene.add_child(player)
	return player
