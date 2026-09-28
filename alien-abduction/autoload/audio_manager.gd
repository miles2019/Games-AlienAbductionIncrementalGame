extends Node
## Prozedurale Soundeffekte + dynamische Chiptune-Musik.
## Combo erhöht die Tonhöhe der Einsaug-Sounds und blendet die "Hype"-Musikspur ein.
## Eigene Sounds: einfach AudioStream in `streams[&"name"]` eintragen.

const MIX_RATE := 22050
const POOL_SIZE := 16
const BPM := 128.0

var streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music_calm: AudioStreamPlayer
var _music_hype: AudioStreamPlayer
var _hype: float = 0.0
var _hype_target: float = 0.0
var _last_play: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_build_sounds()
	_build_music()
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.settings_changed.connect(apply_volumes)
	apply_volumes()


func _setup_buses() -> void:
	for bus_name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")


func apply_volumes() -> void:
	var s: Dictionary = GameManager.settings
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(s.get("master_volume", 0.8)))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, float(s.get("sfx_volume", 1.0)))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, float(s.get("music_volume", 0.5)))))


func play(sound: StringName, pitch: float = 1.0, volume_db: float = 0.0, min_interval: float = 0.03) -> void:
	if not streams.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(sound, -1.0)) < min_interval:
		return
	_last_play[sound] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = streams[sound]
	p.pitch_scale = clampf(pitch, 0.2, 4.0)
	p.volume_db = volume_db
	p.play()


## Einsaug-Sound mit Pitch-Shift je nach Combo
func play_abduct(data: TargetData, combo: int) -> void:
	var pitch := 1.0 + minf(combo, 60) * 0.012
	var snd := data.sound if streams.has(data.sound) else &"slurp"
	play(snd, pitch * randf_range(0.93, 1.07), -3.0, 0.02)
	if combo > 0 and combo % 10 == 0:
		play(&"combo", 1.0 + combo * 0.004)


func _on_combo_changed(combo: int, _mult: float) -> void:
	_hype_target = clampf((combo - 8) / 25.0, 0.0, 1.0)


func _process(delta: float) -> void:
	_hype = move_toward(_hype, _hype_target, delta * (0.8 if _hype_target > _hype else 0.25))
	if _music_hype:
		_music_hype.volume_db = linear_to_db(maxf(0.0001, _hype)) - 2.0
		_music_calm.volume_db = linear_to_db(maxf(0.0001, 1.0 - _hype * 0.6)) - 4.0


# ---------------------------------------------------------------- Soundeffekte

func _build_sounds() -> void:
	streams[&"zap"] = _synth(0.12, func(t: float, p: float) -> float:
		return _sq(t * lerpf(1400.0, 500.0, p)) * 0.22 * (1.0 - p))
	streams[&"slurp"] = _synth(0.28, func(t: float, p: float) -> float:
		var f := lerpf(220.0, 1100.0, p * p) + sin(t * 40.0) * 30.0
		return sin(TAU * t * f) * 0.45 * sin(PI * p))
	streams[&"moo"] = _synth(0.55, func(t: float, p: float) -> float:
		var f := lerpf(140.0, 95.0, p) + sin(t * 30.0) * 4.0
		return (fmod(t * f, 1.0) * 2.0 - 1.0) * 0.3 * sin(PI * p))
	streams[&"scream"] = _synth(0.35, func(t: float, p: float) -> float:
		var f := 700.0 + sin(t * 70.0) * 120.0 + p * 200.0
		return sin(TAU * t * f) * 0.2 * sin(PI * p))
	streams[&"bark"] = _synth(0.16, func(t: float, p: float) -> float:
		var f := lerpf(500.0, 300.0, p)
		return (_sq(t * f) * 0.2 + (randf() - 0.5) * 0.1) * (1.0 - p))
	streams[&"meow"] = _synth(0.32, func(t: float, p: float) -> float:
		var f := 600.0 + sin(p * PI) * 300.0
		return sin(TAU * t * f) * 0.25 * sin(PI * p))
	streams[&"tweet"] = _synth(0.12, func(t: float, p: float) -> float:
		return sin(TAU * t * (2200.0 + sin(t * 90.0) * 400.0)) * 0.15 * (1.0 - p))
	streams[&"honk"] = _synth(0.3, func(t: float, p: float) -> float:
		return (_sq(t * 370.0) + _sq(t * 466.0)) * 0.12 * (1.0 if p < 0.9 else (1.0 - p) * 10.0))
	streams[&"clank"] = _synth(0.2, func(t: float, p: float) -> float:
		return (sin(TAU * t * 1250.0) * 0.3 + sin(TAU * t * 1870.0) * 0.2) * pow(1.0 - p, 3.0))
	streams[&"coin"] = _synth(0.13, func(t: float, p: float) -> float:
		return _sq(t * (988.0 if p < 0.35 else 1319.0)) * 0.14 * (1.0 - p))
	streams[&"gold"] = _synth(0.55, func(t: float, p: float) -> float:
		var notes := [784.0, 988.0, 1175.0, 1568.0]
		var f: float = notes[mini(int(p * 4.0), 3)]
		return (sin(TAU * t * f) * 0.35 + _sq(t * f * 2.0) * 0.05) * (1.0 - p * 0.7))
	streams[&"buy"] = _synth(0.18, func(t: float, p: float) -> float:
		return _sq(t * lerpf(500.0, 1500.0, p)) * 0.18 * (1.0 - p))
	streams[&"deny"] = _synth(0.16, func(t: float, p: float) -> float:
		return _sq(t * 110.0) * 0.2 * (1.0 - p))
	streams[&"miss"] = _synth(0.1, func(_t: float, p: float) -> float:
		return (randf() * 2.0 - 1.0) * 0.1 * (1.0 - p))
	streams[&"boing"] = _synth(0.35, func(t: float, p: float) -> float:
		return sin(TAU * t * (300.0 + sin(p * 30.0) * 120.0 * (1.0 - p))) * 0.3 * (1.0 - p))
	streams[&"rumble"] = _synth(2.2, func(t: float, p: float) -> float:
		return (sin(TAU * t * (45.0 + p * 20.0)) * 0.45 + (randf() * 2.0 - 1.0) * 0.12) * sin(PI * p))
	streams[&"event"] = _synth(1.4, func(t: float, p: float) -> float:
		var f := lerpf(120.0, 900.0, p) + sin(t * 18.0) * 25.0
		return (sin(TAU * t * f) * 0.35 + _sq(t * f * 0.5) * 0.07) * sin(PI * p))
	streams[&"ready"] = _synth(0.5, func(t: float, p: float) -> float:
		return sin(TAU * t * (660.0 if p < 0.5 else 880.0)) * 0.3 * (1.0 - fmod(p * 2.0, 1.0)))
	streams[&"levelup"] = _synth(0.6, func(t: float, p: float) -> float:
		var notes := [523.0, 659.0, 784.0, 1047.0, 1319.0]
		var f: float = notes[mini(int(p * 5.0), 4)]
		return _sq(t * f) * 0.12 * (1.0 - p * 0.5))
	streams[&"achievement"] = _synth(0.7, func(t: float, p: float) -> float:
		var f := 880.0 if p < 0.25 else (1109.0 if p < 0.5 else 1319.0)
		return (sin(TAU * t * f) * 0.3 + sin(TAU * t * f * 2.0) * 0.1) * (1.0 - p * 0.8))
	streams[&"laser"] = _synth(0.5, func(t: float, p: float) -> float:
		return (_sq(t * (180.0 + sin(t * 60.0) * 40.0)) * 0.12 + sin(TAU * t * 2400.0) * 0.05) * sin(PI * p))
	streams[&"pop"] = _synth(0.07, func(t: float, p: float) -> float:
		return sin(TAU * t * lerpf(900.0, 400.0, p)) * 0.3 * (1.0 - p))
	streams[&"click"] = _synth(0.04, func(t: float, p: float) -> float:
		return _sq(t * 1800.0) * 0.1 * (1.0 - p))
	streams[&"whoosh"] = _synth(0.3, func(_t: float, p: float) -> float:
		return (randf() * 2.0 - 1.0) * 0.18 * sin(PI * p))
	streams[&"combo"] = _synth(0.25, func(t: float, p: float) -> float:
		return (_sq(t * 1047.0) * 0.08 + sin(TAU * t * 2093.0) * 0.12) * (1.0 - p))
	streams[&"news"] = _synth(0.9, func(t: float, p: float) -> float:
		var notes := [659.0, 659.0, 784.0, 988.0]
		var f: float = notes[mini(int(p * 4.0), 3)]
		return _sq(t * f) * 0.1 * (1.0 - fmod(p * 4.0, 1.0) * 0.6))
	streams[&"stomp"] = _synth(0.4, func(t: float, p: float) -> float:
		return (sin(TAU * t * lerpf(90.0, 40.0, p)) * 0.6 + (randf() - 0.5) * 0.2 * (1.0 - p)) * pow(1.0 - p, 2.0))


func _synth(duration: float, gen: Callable) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var s: float = gen.call(float(i) / MIX_RATE, float(i) / count)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return _wav(data)


func _wav(data: PackedByteArray, loop: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(data.size() / 2.0)
	return wav


static func _sq(phase: float) -> float:
	return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0


# ---------------------------------------------------------------- Musik

func _build_music() -> void:
	var beat := 60.0 / BPM
	var bars := 4
	var count := int(beat * 4.0 * bars * MIX_RATE)
	var roots := [110.0, 87.31, 98.0, 82.41]   # A F G E
	var arp := [1.0, 1.5, 2.0, 1.5, 1.189, 1.5, 2.0, 2.378]
	var calm := PackedByteArray()
	var hype := PackedByteArray()
	calm.resize(count * 2)
	hype.resize(count * 2)
	var step_len := beat / 2.0
	for i in count:
		var t := float(i) / MIX_RATE
		var bar := int(t / (beat * 4.0)) % bars
		var root: float = roots[bar]
		var step := int(t / step_len)
		var st := fmod(t, step_len) / step_len
		var bass := _sq(t * root * 0.5) * 0.10 * (1.0 - st * 0.6)
		var a: float = arp[step % 8]
		var lead := sin(TAU * t * root * 2.0 * a) * 0.07 * (1.0 - st)
		calm.encode_s16(i * 2, int(clampf(bass + lead, -1.0, 1.0) * 30000.0))
		# Hype: schnelleres Arpeggio, Kick & Hi-Hat
		var fst := fmod(t, step_len * 0.5) / (step_len * 0.5)
		var fa: float = arp[int(t / (step_len * 0.5)) % 8]
		var lead2 := _sq(t * root * 4.0 * fa) * 0.05 * (1.0 - fst)
		var bt := fmod(t, beat) / beat
		var kick := sin(TAU * t * lerpf(120.0, 40.0, bt)) * 0.35 * pow(1.0 - bt, 6.0)
		var hat := (randf() * 2.0 - 1.0) * 0.06 * pow(1.0 - fmod(t + beat * 0.5, beat) / beat, 12.0)
		hype.encode_s16(i * 2, int(clampf(bass * 1.1 + lead2 + kick + hat, -1.0, 1.0) * 30000.0))
	_music_calm = AudioStreamPlayer.new()
	_music_calm.stream = _wav(calm, true)
	_music_calm.bus = &"Music"
	add_child(_music_calm)
	_music_hype = AudioStreamPlayer.new()
	_music_hype.stream = _wav(hype, true)
	_music_hype.bus = &"Music"
	_music_hype.volume_db = -80.0
	add_child(_music_hype)
	_music_calm.play()
	_music_hype.play()
