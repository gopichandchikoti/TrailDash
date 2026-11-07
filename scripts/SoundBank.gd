class_name SoundBank
extends Node

var enabled: bool = true
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var next_voice: int = 0


func _ready() -> void:
	for index in 4:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -12.0
		add_child(voice)
		voices.append(voice)
	sounds = {
		"coin": _tone(880.0, 0.12),
		"jump": _tone(440.0, 0.12),
		"hit": _tone(110.0, 0.25),
		"start": _tone(660.0, 0.16),
		"slide": _tone(220.0, 0.1)
	}


func play(effect: String) -> void:
	if not enabled or not sounds.has(effect):
		return
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = sounds[effect]
	voice.play()


func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	sounds.clear()


static func _tone(frequency: float, duration: float) -> AudioStreamWAV:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var count := int(duration * sound.mix_rate)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for index in count:
		var t := float(index) / sound.mix_rate
		var envelope := sin(PI * float(index) / count) * exp(-t * 12.0)
		var wave := sin(TAU * frequency * t) + 0.2 * sin(TAU * frequency * 2.0 * t)
		samples.encode_s16(index * 2, int(wave * envelope * 14000.0))
	sound.data = samples
	return sound
