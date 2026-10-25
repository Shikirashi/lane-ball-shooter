class_name SfxManager
extends Node

const MIX_RATE := 22050
const VOICE_COUNT := 10
const DEFAULT_VOLUME_DB := -15.0
const MAX_PCM_AMPLITUDE := 0.28
const CUE_NAMES: Array[String] = ["shoot", "insert", "swap", "match", "attack", "knockdown", "revive"]

var muted := false
var gameplay_enabled := true
var play_counts := {}
var request_counts := {}
var clips := {}

var _voices: Array[AudioStreamPlayer] = []
var _voice_cursor := 0

func _ready() -> void:
	_build_clips()
	for index in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.name = "SfxVoice%d" % index
		voice.volume_db = DEFAULT_VOLUME_DB
		add_child(voice)
		_voices.append(voice)
	_reset_counts()

func _exit_tree() -> void:
	stop_all()
	clips.clear()

func play_cue(cue: String, variant := 1) -> bool:
	request_counts[cue] = int(request_counts.get(cue, 0)) + 1
	if muted or not gameplay_enabled or not clips.has(_clip_key(cue, variant)):
		return false
	var voice := _find_voice()
	voice.stop()
	voice.stream = clips[_clip_key(cue, variant)]
	# The headless display has no listener/device; counters still exercise routing
	# without creating dummy AudioStreamPlayback objects that survive test teardown.
	if DisplayServer.get_name() != "headless":
		voice.play()
	play_counts[cue] = int(play_counts.get(cue, 0)) + 1
	return true

func toggle_mute() -> bool:
	muted = not muted
	if muted:
		stop_all()
	return muted

func set_gameplay_enabled(value: bool) -> void:
	gameplay_enabled = value
	if not value:
		stop_all()

func reset_run() -> void:
	stop_all()
	gameplay_enabled = true
	_reset_counts()

func stop_all() -> void:
	for voice in _voices:
		voice.stop()
		voice.stream = null

func active_voice_count() -> int:
	var count := 0
	for voice in _voices:
		if voice.playing:
			count += 1
	return count

func clip_duration(cue: String, variant := 1) -> float:
	var stream: AudioStreamWAV = clips.get(_clip_key(cue, variant))
	return 0.0 if stream == null else stream.get_length()

func clip_peak(cue: String, variant := 1) -> float:
	var stream: AudioStreamWAV = clips.get(_clip_key(cue, variant))
	if stream == null:
		return 0.0
	var peak := 0.0
	for offset in range(0, stream.data.size(), 2):
		peak = maxf(peak, absf(float(stream.data.decode_s16(offset))) / 32767.0)
	return peak

func _reset_counts() -> void:
	play_counts.clear()
	request_counts.clear()
	for cue in CUE_NAMES:
		play_counts[cue] = 0
		request_counts[cue] = 0

func _find_voice() -> AudioStreamPlayer:
	for voice in _voices:
		if not voice.playing:
			return voice
	var voice := _voices[_voice_cursor]
	_voice_cursor = (_voice_cursor + 1) % _voices.size()
	return voice

func _clip_key(cue: String, variant: int) -> String:
	if cue == "attack":
		return "attack_%d" % clampi(variant, 1, 3)
	return cue

func _build_clips() -> void:
	clips.shoot = _synthesize(0.09, func(t: float, _duration: float) -> float:
		return _tone(t, lerpf(520.0, 920.0, t / 0.09), 0.62)
	)
	clips.insert = _synthesize(0.07, func(t: float, _duration: float) -> float:
		return _tone(t, 245.0 - t * 420.0, 0.5) + _tone(t, 490.0, 0.16)
	)
	clips.swap = _synthesize(0.15, func(t: float, _duration: float) -> float:
		return _tone(t, 390.0 if t < 0.075 else 520.0, 0.48)
	)
	clips.match = _synthesize(0.23, func(t: float, _duration: float) -> float:
		var note := mini(2, int(t / 0.07))
		return _tone(t, [523.25, 659.25, 783.99][note], 0.48)
	)
	clips.attack_1 = _synthesize(0.13, func(t: float, _duration: float) -> float:
		return _tone(t, lerpf(260.0, 620.0, t / 0.13), 0.55)
	)
	clips.attack_2 = _synthesize(0.17, func(t: float, _duration: float) -> float:
		return _tone(t, lerpf(320.0, 760.0, t / 0.17), 0.5) + _triangle(t, 160.0, 0.12)
	)
	clips.attack_3 = _synthesize(0.22, func(t: float, _duration: float) -> float:
		return _tone(t, lerpf(180.0, 430.0, t / 0.22), 0.5) + _triangle(t, 90.0, 0.18)
	)
	clips.knockdown = _synthesize(0.29, func(t: float, _duration: float) -> float:
		return _triangle(t, lerpf(310.0, 105.0, t / 0.29), 0.55)
	)
	clips.revive = _synthesize(0.32, func(t: float, _duration: float) -> float:
		var note := mini(2, int(t / 0.1))
		return _tone(t, [392.0, 523.25, 659.25][note], 0.5)
	)

func _synthesize(duration: float, generator: Callable) -> AudioStreamWAV:
	var sample_count := maxi(1, int(ceil(duration * MIX_RATE)))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in range(sample_count):
		var time := float(index) / MIX_RATE
		var envelope := _envelope(time, duration)
		var sample := clampf(float(generator.call(time, duration)) * envelope, -MAX_PCM_AMPLITUDE, MAX_PCM_AMPLITUDE)
		bytes.encode_s16(index * 2, int(round(sample * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream

func _envelope(time: float, duration: float) -> float:
	var attack := minf(1.0, time / 0.012)
	var release := clampf((duration - time) / minf(0.08, duration * 0.45), 0.0, 1.0)
	return attack * release

func _tone(time: float, frequency: float, amplitude: float) -> float:
	return sin(TAU * frequency * time) * amplitude

func _triangle(time: float, frequency: float, amplitude: float) -> float:
	return (absf(2.0 * fmod(time * frequency, 1.0) - 1.0) * 2.0 - 1.0) * amplitude
