class_name Music
extends Node
## Background music. The songs are written below as note tables and rendered with Synth on a worker
## thread when the game starts. Each song is three looping layers played together (Layer): the band,
## the tune, and a tension layer (a fast arpeggio and a shaker) that fades in on a round's last turns.
## Like Sfx, every call is static and does nothing without a Music node (the headless sim has none).

enum Song { BOARD, BOSS }
enum Layer { BASE, TUNE, TENSION }

## Each song: tempo, swing (how late the off-beat eighths come, as a share of an eighth), the lead's
## wave, one chord per bar, the bass line (semitones above each bar's chord root, -1 a rest), drum
## patterns (x a hit) and the melody, a bar a string. Bars are 8 eighth notes: a note name plays,
## "-" holds the note before, "." rests.
const SONGS := {
	Song.BOARD: {
		"bpm": 104,
		"swing": 0.16,
		"lead": Synth.Wave.PULSE,
		"chords": "Am Am F G Am Am Dm E F G Em Am F G E E",
		"bass": [0, -1, 12, -1, 7, -1, 12, -1],
		"kick": "x...x...",
		"rim": "..x...x.",
		"snare": "........",
		"hat": ".x.x.x.x",
		"melody": [
			"A4 . C5 . E5 . D#5 E5", "C5 - - . A4 . . .", "A4 . C5 . F5 . E5 F5", "D5 - - . B4 . G4 .",
			"A4 . C5 . E5 . A5 .", "G5 . F5 . E5 . C5 .", "D5 . F5 . A5 . G5 F5", "E5 - - - G#4 - B4 .",
			"C6 - A5 . F5 . A5 .", "B5 - G5 . D5 . G5 .", "E5 . G5 . B5 . A5 G5", "A5 - - - E5 - - .",
			"F5 . E5 . D5 . C5 .", "D5 . C5 . B4 . G4 .", "G#4 . B4 . E5 . D5 .", "B4 - - - - - . .",
		],
	},
	Song.BOSS: {
		"bpm": 132,
		"swing": 0.0,
		"lead": Synth.Wave.SQUARE,
		"chords": "Dm Dm Bb C Dm Dm Bb A Gm Gm Dm Dm Bb C A A",
		"bass": [0, 0, 12, 0, 0, 0, 12, 7],
		"kick": "x...x..x",
		"rim": "........",
		"snare": "..x...x.",
		"hat": "xxxxxxxx",
		"melody": [
			"D5 . D5 . F5 . A5 .", "G5 F5 E5 F5 D5 - . .", "D5 . F5 . Bb5 . A5 G5", "A5 - G5 - E5 - C5 .",
			"D5 . D5 . F5 . A5 .", "C6 - A5 - F5 - D5 .", "Bb4 . D5 . F5 . E5 D5", "C#5 - - - E5 - A4 .",
			"G5 - Bb5 - D6 - C6 Bb5", "A5 - G5 - D5 - . .", "F5 - A5 - D6 - C6 A5", "F5 - E5 - D5 - . .",
			"D5 F5 Bb5 F5 D5 F5 Bb5 F5", "E5 G5 C6 G5 E5 G5 C6 G5", "C#5 E5 A5 E5 C#5 E5 A5 E5", "A5 - - - G5 - E5 C#5",
		],
	},
}

## The tension layer comes in once a round has this many turns left, counting the one being played.
const TENSION_TURNS := 2
## Volume of a layer that's faded out.
const SILENT_DB := -60.0
## Seconds to fade between songs, and the tension layer in and out.
const FADE := 0.8
## The Music bus's low-pass cutoff while muffled (behind the win panel and in the shop).
const MUFFLED_HZ := 900.0
## The echo on the tune: eighths late, and how loud.
const ECHO_STEPS := 3
const ECHO_GAIN := 0.28

static var _instance: Music
## Each rendered song's layers, by Song.
static var _songs: Dictionary[Song, Array] = {}
## Songs the worker thread has finished, waiting for _process to take them into _songs.
static var _rendered: Dictionary[Song, Array] = {}
static var _mutex := Mutex.new()

var _players: Array[AudioStreamPlayer] = []
## The song playing, and the one asked for (which may still be rendering), or -1 for none.
var _song := -1
var _wanted := -1
var _tension := false
var _filter := AudioEffectLowPassFilter.new()
var _fade: Tween
var _muffle: Tween
var _task := -1


func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sfx._make_buses()
	for layer in Layer.size():
		var player := AudioStreamPlayer.new()
		player.bus = Sfx.MUSIC_BUS
		add_child(player)
		_players.append(player)
	var bus := AudioServer.get_bus_index(Sfx.MUSIC_BUS)
	_filter.cutoff_hz = MUFFLED_HZ
	AudioServer.add_bus_effect(bus, _filter)
	AudioServer.set_bus_effect_enabled(bus, AudioServer.get_bus_effect_count(bus) - 1, false)
	_task = WorkerThreadPool.add_task(_render_all)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null
	_halt()
	# Every task has to be waited for.
	WorkerThreadPool.wait_for_task_completion(_task)


## Takes in the songs the worker thread has rendered, starting the one asked for.
func _process(_delta: float) -> void:
	_mutex.lock()
	_songs.merge(_rendered)
	_rendered.clear()
	_mutex.unlock()
	if _wanted != -1 and _song != _wanted and _songs.has(_wanted) and not (_fade and _fade.is_running()):
		_fade_out(_start)
	if _songs.size() == Song.size():
		set_process(false)


## Plays a song from the top, fading out the one playing, unless it's already playing.
static func play(song: Song) -> void:
	if _instance:
		_instance._play(song)


## Fades the music out.
static func stop() -> void:
	if _instance:
		_instance._wanted = -1
		_instance._fade_out(_instance._halt)


## Fades the tension layer in or out.
static func set_tension(on: bool) -> void:
	if _instance and _instance._tension != on:
		_instance._tension = on
		if _instance._song != -1:
			_instance.create_tween().tween_property(_instance._players[Layer.TENSION], "volume_db",
				0.0 if on else SILENT_DB, FADE)


## Muffles the music, as if through a wall, or brings it back.
static func set_muffled(on: bool) -> void:
	if _instance:
		_instance._set_muffled(on)


## The song asked for, or -1: for the dev menu.
static func current() -> int:
	return _instance._wanted if _instance else -1


func _play(song: Song) -> void:
	if song == _wanted and _song == song:
		return
	_wanted = song
	if _songs.has(song):
		_fade_out(_start)


func _start() -> void:
	if _wanted == -1 or not _songs.has(_wanted):
		return
	_song = _wanted
	var layers: Array = _songs[_song]
	for layer in Layer.size():
		var player := _players[layer]
		player.stream = layers[layer]
		player.volume_db = SILENT_DB if layer == Layer.TENSION and not _tension else 0.0
		player.play()


func _halt() -> void:
	_song = -1
	for player in _players:
		player.stop()


## Fades every layer out, then calls then.
func _fade_out(then: Callable) -> void:
	if _fade:
		_fade.kill()
	if _song == -1:
		then.call()
		return
	_fade = create_tween().set_parallel()
	for player in _players:
		_fade.tween_property(player, "volume_db", SILENT_DB, FADE / 2)
	_fade.chain().tween_callback(then)


func _set_muffled(on: bool) -> void:
	var bus := AudioServer.get_bus_index(Sfx.MUSIC_BUS)
	var effect := AudioServer.get_bus_effect_count(bus) - 1
	if _muffle:
		_muffle.kill()
	_muffle = create_tween()
	if on:
		AudioServer.set_bus_effect_enabled(bus, effect, true)
		_muffle.tween_property(_filter, "cutoff_hz", MUFFLED_HZ, 0.4).from(8000.0)
	else:
		_muffle.tween_property(_filter, "cutoff_hz", 8000.0, 0.4)
		_muffle.tween_callback(AudioServer.set_bus_effect_enabled.bind(bus, effect, false))


## Renders every song, on a worker thread, the normal rounds' first.
static func _render_all() -> void:
	for song: Song in [Song.BOARD, Song.BOSS]:
		var layers := render(song)
		var wavs: Array[AudioStreamWAV] = []
		for samples in layers:
			wavs.append(Synth.to_wav(samples, true))
		_mutex.lock()
		_rendered[song] = wavs
		_mutex.unlock()


## The samples of each Layer of a song, a loop of its bars.
static func render(song: Song) -> Array[PackedFloat32Array]:
	var info: Dictionary = SONGS[song]
	var step: float = 60.0 / info.bpm / 2.0
	var swing: float = info.swing
	var chords := (info.chords as String).split(" ")
	var length := int(chords.size() * 8 * step * Synth.RATE)
	var layers: Array[PackedFloat32Array] = []
	for layer in Layer.size():
		var samples := PackedFloat32Array()
		samples.resize(length)
		layers.append(samples)
	var W := Synth.Wave
	var kick := Synth.tone(0.16, [150, 45], W.SINE, 0.5, 0.001, 2.0)
	Synth.add(kick, Synth.noise(0.012, [4000], 0.1, 0.001, 2.0))
	var snare := Synth.noise(0.15, [6000, 3000], 0.2, 0.001, 2.0, 800)
	Synth.add(snare, Synth.tone(0.1, [200, 170], W.TRIANGLE, 0.15, 0.001, 2.0))
	var rim := Synth.noise(0.04, [5000], 0.13, 0.001, 3.0, 1500)
	Synth.add(rim, Synth.tone(0.04, [820], W.SQUARE, 0.05, 0.001, 3.0))
	var hat := Synth.noise(0.035, [11000], 0.06 if song == Song.BOARD else 0.045, 0.001, 3.0, 6000)
	var shaker := Synth.noise(0.06, [9000], 0.07, 0.015, 2.0, 4000)
	var bass_notes := {}
	var arp_notes := {}
	var pads := {}
	var tune := PackedFloat32Array()
	tune.resize(length)

	for bar in chords.size():
		var chord := _chord(chords[bar])
		var root: int = chord[0]
		for i in 8:
			var at := _step_time(bar * 8 + i, step, swing)
			if info.kick[i] == "x":
				_put(layers[Layer.BASE], kick, at)
			if info.snare[i] == "x":
				_put(layers[Layer.BASE], snare, at)
			if info.rim[i] == "x":
				_put(layers[Layer.BASE], rim, at)
			if info.hat[i] == "x":
				_put(layers[Layer.BASE], hat, at)
			var offset: int = info.bass[i]
			if offset >= 0:
				var note := _in_range(root, 40) + offset
				if not bass_notes.has(note):
					bass_notes[note] = _bass(note, step, song)
				_put(layers[Layer.BASE], bass_notes[note], at)
		# The chord, held through the bar, under the tune.
		if not pads.has(chords[bar]):
			var pad := PackedFloat32Array()
			for interval: int in chord[1]:
				var hz := Synth.hz(_in_range(root, 55) + interval)
				Synth.add(pad, Synth.tone(step * 8, [hz], W.TRIANGLE, 0.035, 0.25, 1.5, 0.5))
				Synth.add(pad, Synth.tone(step * 8, [hz * 1.004], W.TRIANGLE, 0.025, 0.25, 1.5, 0.5))
			pads[chords[bar]] = pad
		_put(tune, pads[chords[bar]], _step_time(bar * 8, step, 0.0))
		# Tension: the chord's notes up and down in sixteenths, and a shaker.
		var tones: Array[int] = []
		for interval: int in chord[1]:
			tones.append(_in_range(root, 69) + interval)
		tones.append(_in_range(root, 69) + 12)
		for i in 16:
			var note: int = tones[[0, 1, 2, 3, 2, 1, 2, 3][i % 8]]
			if not arp_notes.has(note):
				arp_notes[note] = Synth.tone(step * 0.42, [Synth.hz(note)], W.THIN, 0.08, 0.002, 2.0)
			var at := bar * 8 * step + i * step / 2
			_put(layers[Layer.TENSION], arp_notes[note], at)
			_put(layers[Layer.TENSION], shaker, at, 1.0 if i % 2 == 1 else 0.5)

	# The melody: each note lasts until the next note or rest.
	var tokens := PackedStringArray()
	for bar_notes: String in info.melody:
		tokens.append_array(bar_notes.split(" "))
	var lead_notes := {}
	for i in tokens.size():
		if tokens[i] == "." or tokens[i] == "-":
			continue
		var steps := 1
		while i + steps < tokens.size() and tokens[i + steps] == "-":
			steps += 1
		var key := "%s %d" % [tokens[i], steps]
		if not lead_notes.has(key):
			lead_notes[key] = _lead(Synth.midi(tokens[i]), steps, step, info.lead)
		_put(tune, lead_notes[key], _step_time(i, step, swing))
	var tune_layer := layers[Layer.TUNE]
	var echo := int(ECHO_STEPS * step * Synth.RATE)
	# A negative index counts from the end, so the echo wraps round from the end of the loop.
	for i in length:
		tune_layer[i] = tune[i] + tune[i - echo] * ECHO_GAIN
	return layers


## A bass note: a plucked triangle with a little bite.
static func _bass(note: int, step: float, song: Song) -> PackedFloat32Array:
	var hz := Synth.hz(note)
	var length := step * (0.9 if song == Song.BOARD else 0.8)
	var sound := Synth.tone(length, [hz], Synth.Wave.TRIANGLE, 0.32, 0.003, 1.6)
	Synth.add(sound, Synth.tone(length, [hz], Synth.Wave.PULSE, 0.05 if song == Song.BOARD else 0.08, 0.003, 2.0))
	return sound


## A lead note steps eighths long: short ones plucked, held ones sustained with vibrato.
static func _lead(note: int, steps: int, step: float, wave: Synth.Wave) -> PackedFloat32Array:
	var hz := Synth.hz(note)
	if steps == 1:
		var short := Synth.tone(step * 0.85, [hz], wave, 0.13, 0.006, 1.5, 0.15)
		Synth.add(short, Synth.tone(step * 0.85, [hz / 2], Synth.Wave.TRIANGLE, 0.06, 0.006, 1.5, 0.15))
		return short
	var length := step * steps * 0.95
	var vibrato := 0.2 if steps >= 3 else 0.0
	var held := Synth.tone(length, [hz], wave, 0.13, 0.008, 1.2, 0.55, vibrato)
	Synth.add(held, Synth.tone(length, [hz / 2], Synth.Wave.TRIANGLE, 0.06, 0.008, 1.2, 0.55, vibrato))
	return held


## A chord name ("Am", "Bb", "C#m") as [its root's MIDI note class (0-11), its intervals].
static func _chord(name: String) -> Array:
	var minor := name.ends_with("m")
	var root := Synth.midi(name.trim_suffix("m") + "0") % 12
	return [root, [0, 3, 7] if minor else [0, 4, 7]]


## The note of a pitch class (0-11) in the octave starting at low.
static func _in_range(pitch_class: int, low: int) -> int:
	return low + posmod(pitch_class - low, 12)


## When an eighth-note step starts, in seconds, with the off-beats swung late.
static func _step_time(index: int, step: float, swing: float) -> float:
	return (index + (swing if index % 2 == 1 else 0.0)) * step


## Adds sound into a loop at seconds in, wrapping round the loop's end.
static func _put(loop: PackedFloat32Array, sound: PackedFloat32Array, at: float, gain := 1.0) -> void:
	var start := int(at * Synth.RATE) % loop.size()
	var length := loop.size()
	if start + sound.size() <= length:
		for i in sound.size():
			loop[start + i] += sound[i] * gain
		return
	for i in sound.size():
		loop[(start + i) % length] += sound[i] * gain
