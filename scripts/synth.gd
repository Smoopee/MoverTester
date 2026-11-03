class_name Synth
## Builds sounds out of waves in code, for Sfx and Music (there are no audio files): tones that glide
## through pitches, filtered noise, mixing them together and packing the result into an AudioStreamWAV.

## Samples a second. Low, to keep the GDScript that builds the sounds quick, and fine for chiptune.
const RATE := 22050

enum Wave { SINE, TRIANGLE, SQUARE, PULSE, THIN, SAW }

const NOTE_NAMES := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


## A tone length seconds long whose pitch glides evenly through pitches (Hz; one for a steady note).
## It rises over attack seconds, holds for the hold share of its length, then falls to 0 at the end
## along the curve power (1 a straight line, higher falls off faster). vibrato is a depth in semitones,
## at 5.5 Hz, that comes in after a tenth of a second.
static func tone(length: float, pitches: PackedFloat32Array, wave := Wave.SQUARE, gain := 0.5, attack := 0.004,
		power := 1.0, hold := 0.0, vibrato := 0.0) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rise := maxf(attack * RATE, 1.0)
	var last := pitches.size() - 1
	var wobble := vibrato * 0.0578
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var hz := pitches[0]
		if last > 0:
			var at := t * last
			var k := mini(int(at), last - 1)
			hz = lerpf(pitches[k], pitches[k + 1], at - k)
		if wobble > 0.0 and i > RATE / 10:
			hz *= 1.0 + wobble * sin(TAU * 5.5 * i / RATE)
		phase = fmod(phase + hz / RATE, 1.0)
		out[i] = wave_at(wave, phase) * gain * minf(i / rise, 1.0) * _fall(t, hold, power)
	return out


## White noise length seconds long through a low-pass filter whose cutoff glides through cutoffs (Hz),
## and a high-pass at high_pass Hz when above 0, shaped like tone and peaking at gain. chop above 0
## gates it on and off that many times a second, for crackle and rattle.
static func noise(length: float, cutoffs: PackedFloat32Array, gain := 0.5, attack := 0.002, power := 1.0,
		high_pass := 0.0, hold := 0.0, chop := 0.0) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rise := maxf(attack * RATE, 1.0)
	var last := cutoffs.size() - 1
	var high := 1.0 - exp(-TAU * high_pass / RATE)
	var low_a := 0.0
	var low_b := 0.0
	var below := 0.0
	var gate := 1.0
	var peak := 0.0
	# Its own generator: sounds are built on worker threads, and the global one is the game's.
	var rng := RandomNumberGenerator.new()
	for i in n:
		var t := float(i) / n
		var cut := cutoffs[0]
		if last > 0:
			var at := t * last
			var k := mini(int(at), last - 1)
			cut = lerpf(cutoffs[k], cutoffs[k + 1], at - k)
		var k_low := 1.0 - exp(-TAU * minf(cut, RATE * 0.45) / RATE)
		# Two one-pole filters in a row, for a steeper slope.
		low_a += k_low * (rng.randf_range(-1.0, 1.0) - low_a)
		low_b += k_low * (low_a - low_b)
		var sample := low_b
		if high_pass > 0.0:
			below += high * (sample - below)
			sample -= below
		if chop > 0.0 and i % maxi(int(RATE / chop), 1) == 0:
			gate = 1.0 if rng.randf() < 0.6 else 0.15
		peak = maxf(peak, absf(sample))
		out[i] = sample * gate * minf(i / rise, 1.0) * _fall(t, hold, power)
	# Filtering takes the level down, more the lower the cutoff, so it's scaled back up to gain.
	var scale := gain / maxf(peak, 0.0001)
	for i in n:
		out[i] *= scale
	return out


## Adds sound into mix, at seconds in and scaled by gain, growing mix to fit.
static func add(mix: PackedFloat32Array, sound: PackedFloat32Array, at := 0.0, gain := 1.0) -> void:
	var start := int(at * RATE)
	if mix.size() < start + sound.size():
		mix.resize(start + sound.size())
	for i in sound.size():
		mix[start + i] += sound[i] * gain


## Packs samples (about -1 to 1) into a 16-bit stream, looping the whole of it when loop is set.
## Scales the samples down when they'd clip.
static func to_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, absf(sample))
	var scale := 32767.0 / maxf(peak / 0.95, 1.0)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(samples[i] * scale))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav


## The wave's value (-1 to 1) at phase (0 to 1) through a cycle.
static func wave_at(wave: Wave, phase: float) -> float:
	match wave:
		Wave.SINE:
			return sin(TAU * phase)
		Wave.TRIANGLE:
			return 1.0 - 4.0 * absf(phase - 0.5)
		Wave.SQUARE:
			return 1.0 if phase < 0.5 else -1.0
		Wave.PULSE:
			return 1.0 if phase < 0.25 else -1.0
		Wave.THIN:
			return 1.0 if phase < 0.125 else -1.0
	return 2.0 * phase - 1.0


## The MIDI note number of a note name like "A4", "C#5" or "Bb3".
static func midi(note: String) -> int:
	var semitone: int = NOTE_NAMES[note[0]]
	var octave_at := 1
	if note[1] == "#":
		semitone += 1
		octave_at = 2
	elif note[1] == "b":
		semitone -= 1
		octave_at = 2
	return 12 * (int(note.substr(octave_at)) + 1) + semitone


## The pitch in Hz of a MIDI note number.
static func hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


## The level at t (0 to 1) through a sound that holds for the hold share of its length, then falls.
static func _fall(t: float, hold: float, power: float) -> float:
	if t < hold:
		return 1.0
	return pow(1.0 - (t - hold) / (1.0 - hold), power)
