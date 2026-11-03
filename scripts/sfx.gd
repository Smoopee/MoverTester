class_name Sfx
extends Node
## Sound effects, built in code with Synth on a worker thread when the game starts. Play one with
## Sfx.play(Sfx.Sound.STEP) from anywhere: it does nothing until the sounds are built, and in a
## headless run (the balance sim), which never makes an Sfx. Board movement only plays sounds while
## Board.animate is on, so the preview and the sim stay quiet.
##
## Also owns the Music and Sfx audio buses and the volume settings, saved to SETTINGS_PATH.

enum Sound {
	STEP, BUMP, SLIDE, JUMP, HOLE, BELT, PAD, CRATE, FLOORBOARD, GLUE, TRAP, POUNCE, MEOW, ZAP, FLAME,
	SCAMPER, CRUMB, CHEST, KEY, UNLOCK, CARD_PICK, CARD_PLACE, DEAL, DISCARD, LOCK_IN, FIZZLE, POINTS,
	MULT, SCORE, SKILL, USE, CLICK, BUY, REROLL, DENIED, LAST_TURN, WIN, BOSS_WIN, LOSE,
}

## How far each play's pitch can stray from the sound's own, so repeated sounds don't drone.
const VARY := {
	Sound.STEP: 0.12, Sound.BUMP: 0.08, Sound.SLIDE: 0.08, Sound.JUMP: 0.06, Sound.CRATE: 0.1,
	Sound.MEOW: 0.12, Sound.CARD_PICK: 0.1, Sound.CARD_PLACE: 0.08, Sound.DISCARD: 0.08, Sound.CLICK: 0.05,
	Sound.CRUMB: 0.03, Sound.BELT: 0.05, Sound.SCAMPER: 0.08,
}

const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "Sfx"
## Players that can sound at once. When all are busy, the one that started first is cut off.
const VOICES := 16
## A sound started again within this many seconds is skipped (crumbs a magnet pulls in together).
const REPEAT_GAP := 0.03
## Marks a button that shouldn't click when pressed: it plays its own sound.
const NO_CLICK := &"no_click"

static var _instance: Sfx
static var _streams: Dictionary[Sound, AudioStreamWAV] = {}
## Sounds the worker thread has built, waiting for _process to take them into _streams.
static var _built: Dictionary[Sound, AudioStreamWAV] = {}
static var _mutex := Mutex.new()

## Volumes, 0 to 1, and whether everything's muted. Set them through set_volume and set_muted.
static var music_volume := 0.55
static var sfx_volume := 0.8
static var muted := false

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played: Dictionary[Sound, int] = {}
## Its own, so the pitch variation leaves the game's random numbers alone.
var _rng := RandomNumberGenerator.new()
var _task := -1


func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	_load_settings()
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)
	_task = WorkerThreadPool.add_task(_build_all)
	# Every button clicks, but cards, which play their own sounds when they move.
	get_tree().node_added.connect(_on_node_added)
	_wire_clicks(get_tree().root)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null
	for player in _players:
		player.stop()
	# Every task has to be waited for.
	WorkerThreadPool.wait_for_task_completion(_task)


## Takes in the sounds the worker thread has built.
func _process(_delta: float) -> void:
	_mutex.lock()
	_streams.merge(_built)
	_built.clear()
	_mutex.unlock()
	if _streams.size() == Sound.size():
		set_process(false)


## Plays a sound, pitch times its own (plus a little random variation for some), volume_db louder.
static func play(sound: Sound, pitch := 1.0, volume_db := 0.0) -> void:
	if _instance == null or not _streams.has(sound):
		return
	_instance._play(sound, pitch, volume_db)


## Sets the Music or Sfx bus's volume (0 to 1) and saves it.
static func set_volume(bus: String, volume: float) -> void:
	if bus == MUSIC_BUS:
		music_volume = volume
	else:
		sfx_volume = volume
	_apply_volumes()
	_save_settings()


static func set_muted(on: bool) -> void:
	muted = on
	_apply_volumes()
	_save_settings()


func _play(sound: Sound, pitch: float, volume_db: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_played.get(sound, -1000) < REPEAT_GAP * 1000:
		return
	_last_played[sound] = now
	var player := _players[_next]
	for i in VOICES:
		var free := _players[(_next + i) % VOICES]
		if not free.playing:
			player = free
			break
	_next = (_players.find(player) + 1) % VOICES
	var vary: float = VARY.get(sound, 0.0)
	player.stream = _streams[sound]
	player.pitch_scale = pitch * _rng.randf_range(1.0 - vary, 1.0 + vary)
	player.volume_db = volume_db
	player.play()


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	# A button moved to a new parent is added again.
	if button and not button is Card and not button.pressed.is_connected(_click.bind(button)):
		button.pressed.connect(_click.bind(button))


func _wire_clicks(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_wire_clicks(child)


func _click(button: BaseButton) -> void:
	if not button.has_meta(NO_CLICK):
		play(Sound.CLICK)


static func _make_buses() -> void:
	for bus in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, "Master")
	_apply_volumes()


static func _apply_volumes() -> void:
	for bus in [MUSIC_BUS, SFX_BUS]:
		var index := AudioServer.get_bus_index(bus)
		var volume := music_volume if bus == MUSIC_BUS else sfx_volume
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
		AudioServer.set_bus_mute(index, muted or volume <= 0.0)


static func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	music_volume = config.get_value("audio", "music", music_volume)
	sfx_volume = config.get_value("audio", "sfx", sfx_volume)
	muted = config.get_value("audio", "muted", muted)
	_apply_volumes()


static func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "muted", muted)
	config.save(SETTINGS_PATH)


## Builds every sound, on a worker thread. Each one is handed over in _built as it's ready.
static func _build_all() -> void:
	for sound: Sound in Sound.values():
		var wav := Synth.to_wav(build(sound))
		_mutex.lock()
		_built[sound] = wav
		_mutex.unlock()


## The samples of a sound. Each is a few tones and noises mixed together (see Synth).
static func build(sound: Sound) -> PackedFloat32Array:
	var W := Synth.Wave
	var mix := PackedFloat32Array()
	match sound:
		Sound.STEP:
			# A soft patter of feet.
			Synth.add(mix, Synth.noise(0.045, [3200, 900], 0.22, 0.002, 2.0, 400))
			Synth.add(mix, Synth.tone(0.04, [420, 260], W.SINE, 0.18, 0.002, 2.0))
		Sound.BUMP:
			# A thud into the wall and a squeak.
			Synth.add(mix, Synth.tone(0.14, [140, 55], W.SINE, 0.42, 0.002, 2.0))
			Synth.add(mix, Synth.noise(0.06, [700, 200], 0.25, 0.001, 2.0))
			Synth.add(mix, Synth.tone(0.07, [1500, 1900, 1300], W.TRIANGLE, 0.12, 0.01, 1.5), 0.03)
		Sound.SLIDE:
			# A whoosh across the floor.
			Synth.add(mix, Synth.noise(0.38, [500, 2600, 900], 0.5, 0.06, 1.5, 250))
			Synth.add(mix, Synth.tone(0.3, [700, 350], W.TRIANGLE, 0.05, 0.03, 2.0))
		Sound.JUMP:
			# A springy hop up.
			Synth.add(mix, Synth.tone(0.2, [260, 520, 760], W.PULSE, 0.16, 0.004, 1.5))
			Synth.add(mix, Synth.tone(0.2, [260, 520, 760], W.TRIANGLE, 0.2, 0.004, 1.5))
		Sound.HOLE:
			# Down the hole, and pop out of the other one.
			Synth.add(mix, Synth.tone(0.16, [700, 140], W.TRIANGLE, 0.35, 0.004, 1.5))
			Synth.add(mix, Synth.tone(0.09, [180, 950], W.SINE, 0.4, 0.002, 1.0), 0.26)
			Synth.add(mix, Synth.noise(0.04, [4000, 1500], 0.15, 0.001, 2.0, 600), 0.26)
		Sound.BELT:
			# A rattle of rollers.
			Synth.add(mix, Synth.noise(0.18, [1400], 0.2, 0.01, 1.0, 200, 0.3, 60))
			Synth.add(mix, Synth.tone(0.18, [95, 90], W.SQUARE, 0.08, 0.01, 1.0, 0.4))
		Sound.PAD:
			# A spring that throws the mouse: a boing that wobbles out.
			var boing := PackedFloat32Array()
			for i in 24:
				boing.append((240 + i * 28) * (1.0 + 0.18 * sin(i * 1.9) * exp(-i * 0.12)))
			Synth.add(mix, Synth.tone(0.42, boing, W.TRIANGLE, 0.38, 0.003, 1.6))
			Synth.add(mix, Synth.tone(0.06, [120, 60], W.SINE, 0.4, 0.001, 2.0))
		Sound.CRATE:
			# A wooden crate scraping a cell over.
			Synth.add(mix, Synth.noise(0.24, [900, 600], 0.3, 0.02, 1.2, 120, 0.2, 90))
			Synth.add(mix, Synth.tone(0.2, [75, 68], W.TRIANGLE, 0.3, 0.01, 1.5))
		Sound.FLOORBOARD:
			# A creak, a crack and the plank falling in.
			Synth.add(mix, Synth.tone(0.16, [260, 330, 210], W.SAW, 0.07, 0.02, 1.0, 0.4, 0.8))
			Synth.add(mix, Synth.noise(0.05, [9000], 0.45, 0.001, 3.0, 800), 0.14)
			Synth.add(mix, Synth.tone(0.14, [110, 50], W.SINE, 0.45, 0.002, 2.0), 0.16)
		Sound.GLUE:
			# A squelch.
			var squish := PackedFloat32Array()
			for i in 16:
				squish.append(300 - i * 12 + 60 * sin(i * 1.4))
			Synth.add(mix, Synth.tone(0.28, squish, W.SINE, 0.4, 0.01, 1.5))
			Synth.add(mix, Synth.noise(0.24, [500, 250], 0.2, 0.02, 1.5))
		Sound.TRAP:
			# The trap's bar snapping shut, and the spring ringing.
			Synth.add(mix, Synth.noise(0.035, [10000], 0.7, 0.0005, 2.0, 300))
			Synth.add(mix, Synth.tone(0.1, [180, 60], W.SINE, 0.6, 0.001, 2.0))
			for partial: float in [1760.0, 2710.0, 4150.0]:
				Synth.add(mix, Synth.tone(0.5, [partial], W.SINE, 0.07, 0.001, 3.0), 0.01)
		Sound.POUNCE:
			# A hiss and a yowl.
			Synth.add(mix, Synth.noise(0.32, [9000, 6000], 0.25, 0.02, 1.5, 2500))
			Synth.add(mix, Synth.tone(0.5, [430, 820, 900, 420], W.SAW, 0.16, 0.04, 1.2, 0.3, 0.6), 0.12)
			Synth.add(mix, Synth.tone(0.5, [430, 820, 900, 420], W.TRIANGLE, 0.2, 0.04, 1.2, 0.3, 0.6), 0.12)
		Sound.MEOW:
			# The cats prowl: a low, lazy meow.
			Synth.add(mix, Synth.tone(0.45, [360, 620, 640, 330], W.TRIANGLE, 0.18, 0.05, 1.3, 0.25, 0.5))
			Synth.add(mix, Synth.tone(0.45, [360, 620, 640, 330], W.PULSE, 0.04, 0.05, 1.3, 0.25, 0.5))
		Sound.ZAP:
			# A shock pylon's crackle over a buzz.
			Synth.add(mix, Synth.noise(0.5, [7000, 4000], 0.45, 0.002, 1.2, 900, 0.1, 90))
			Synth.add(mix, Synth.tone(0.5, [110, 104], W.SAW, 0.22, 0.002, 1.2, 0.2))
			Synth.add(mix, Synth.tone(0.5, [1760, 1500], W.SQUARE, 0.04, 0.002, 2.0))
		Sound.FLAME:
			# A flamethrower's roar.
			Synth.add(mix, Synth.noise(0.65, [500, 1700, 700], 0.55, 0.06, 1.2, 60, 0.2))
			Synth.add(mix, Synth.tone(0.6, [62, 48], W.SINE, 0.3, 0.05, 1.5))
		Sound.SCAMPER:
			# The runaway cheese's little feet.
			for i in 5:
				Synth.add(mix, Synth.noise(0.035, [4000, 1200], 0.3, 0.001, 2.0, 600), i * 0.055)
				Synth.add(mix, Synth.tone(0.03, [600 + i * 60, 420], W.SINE, 0.2, 0.001, 2.0), i * 0.055)
		Sound.CRUMB:
			# A bright two-note blip.
			Synth.add(mix, Synth.tone(0.05, [Synth.hz(88)], W.PULSE, 0.13, 0.002, 0.8))
			Synth.add(mix, Synth.tone(0.12, [Synth.hz(95)], W.PULSE, 0.13, 0.002, 1.8), 0.05)
		Sound.CHEST:
			# The lid, then a run of coins.
			Synth.add(mix, Synth.noise(0.06, [1500, 600], 0.3, 0.002, 2.0))
			Synth.add(mix, Synth.tone(0.08, [150, 90], W.SINE, 0.4, 0.002, 2.0))
			for i in 5:
				var note: int = [79, 84, 88, 91, 96][i]
				Synth.add(mix, Synth.tone(0.22, [Synth.hz(note)], W.PULSE, 0.09, 0.002, 2.0), 0.08 + i * 0.06)
				Synth.add(mix, Synth.tone(0.3, [Synth.hz(note + 12)], W.SINE, 0.05, 0.002, 3.0), 0.08 + i * 0.06)
		Sound.KEY:
			# A jingle of keys.
			for i in 4:
				Synth.add(mix, Synth.tone(0.18, [2093.0 + i * 140], W.SINE, 0.14, 0.001, 3.0), i * 0.045)
				Synth.add(mix, Synth.tone(0.12, [3136.0 - i * 90], W.TRIANGLE, 0.06, 0.001, 3.0), i * 0.045 + 0.02)
		Sound.UNLOCK:
			# The key turns, and the door swings open.
			Synth.add(mix, Synth.noise(0.03, [6000], 0.45, 0.001, 2.0, 1500))
			Synth.add(mix, Synth.tone(0.1, [200, 100], W.SQUARE, 0.25, 0.002, 2.0), 0.05)
			Synth.add(mix, Synth.noise(0.03, [5000], 0.3, 0.001, 2.0, 1500), 0.12)
			Synth.add(mix, Synth.tone(0.35, [280, 340, 300], W.SAW, 0.08, 0.05, 1.0, 0.5, 0.6), 0.16)
		Sound.CARD_PICK:
			Synth.add(mix, Synth.noise(0.03, [7000, 3000], 0.16, 0.002, 2.0, 1200))
		Sound.CARD_PLACE:
			# A card snapping down.
			Synth.add(mix, Synth.noise(0.04, [6500, 2000], 0.3, 0.001, 2.0, 900))
			Synth.add(mix, Synth.tone(0.03, [900, 600], W.TRIANGLE, 0.12, 0.001, 2.0))
		Sound.DEAL:
			# A hand of cards flicked out.
			for i in 5:
				Synth.add(mix, Synth.noise(0.03, [6500, 2500], 0.22, 0.001, 2.0, 1200), i * 0.045)
		Sound.DISCARD:
			# A card crumpled and tossed.
			Synth.add(mix, Synth.noise(0.2, [3500, 900], 0.3, 0.005, 1.2, 300, 0.1, 140))
			Synth.add(mix, Synth.noise(0.12, [5000, 1500], 0.18, 0.02, 1.5, 800), 0.14)
		Sound.LOCK_IN:
			# Ka-chunk.
			Synth.add(mix, Synth.tone(0.07, [Synth.hz(67)], W.SQUARE, 0.12, 0.002, 1.0))
			Synth.add(mix, Synth.tone(0.16, [Synth.hz(74)], W.SQUARE, 0.12, 0.002, 2.0), 0.07)
			Synth.add(mix, Synth.tone(0.12, [130, 60], W.SINE, 0.5, 0.001, 2.0), 0.07)
		Sound.FIZZLE:
			# A dud.
			Synth.add(mix, Synth.tone(0.3, [240, 110], W.SQUARE, 0.1, 0.005, 1.5))
			Synth.add(mix, Synth.noise(0.2, [2500, 600], 0.15, 0.01, 1.5, 400))
		Sound.POINTS:
			Synth.add(mix, Synth.tone(0.06, [Synth.hz(84)], W.THIN, 0.07, 0.001, 1.5))
		Sound.MULT:
			# A chime, up a fifth.
			Synth.add(mix, Synth.tone(0.18, [Synth.hz(84)], W.TRIANGLE, 0.22, 0.002, 2.0))
			Synth.add(mix, Synth.tone(0.3, [Synth.hz(91)], W.TRIANGLE, 0.22, 0.002, 2.0), 0.07)
			Synth.add(mix, Synth.tone(0.3, [Synth.hz(91)], W.PULSE, 0.05, 0.002, 2.5), 0.07)
		Sound.SCORE:
			# A bell for the banked turn.
			for partial: Array in [[1.0, 0.3], [2.0, 0.12], [3.01, 0.08], [4.2, 0.04]]:
				Synth.add(mix, Synth.tone(0.8, [880.0 * partial[0]], W.SINE, partial[1], 0.002, 2.5))
		Sound.SKILL:
			# A rising shimmer.
			for i in 5:
				Synth.add(mix, Synth.tone(0.2, [Synth.hz(79 + [0, 4, 7, 12, 16][i])], W.TRIANGLE, 0.13, 0.002, 2.0),
					i * 0.04)
			Synth.add(mix, Synth.noise(0.35, [11000], 0.06, 0.05, 2.0, 5000))
		Sound.USE:
			# A cork popping out of the pouch.
			Synth.add(mix, Synth.tone(0.09, [280, 1100], W.SINE, 0.4, 0.002, 1.5))
			Synth.add(mix, Synth.noise(0.04, [5000], 0.2, 0.001, 2.0, 1000))
			Synth.add(mix, Synth.tone(0.25, [Synth.hz(84), Synth.hz(91)], W.TRIANGLE, 0.12, 0.01, 2.0), 0.08)
		Sound.CLICK:
			Synth.add(mix, Synth.tone(0.02, [1200, 800], W.SQUARE, 0.06, 0.001, 2.0))
			Synth.add(mix, Synth.noise(0.015, [8000], 0.08, 0.001, 2.0, 2000))
		Sound.BUY:
			# Cha-ching.
			Synth.add(mix, Synth.noise(0.05, [9000], 0.3, 0.001, 2.0, 2500))
			Synth.add(mix, Synth.noise(0.06, [9000], 0.25, 0.001, 2.0, 2500), 0.09)
			Synth.add(mix, Synth.tone(0.12, [Synth.hz(83)], W.PULSE, 0.12, 0.002, 1.0), 0.09)
			Synth.add(mix, Synth.tone(0.5, [Synth.hz(88)], W.PULSE, 0.12, 0.002, 2.5), 0.17)
			Synth.add(mix, Synth.tone(0.6, [Synth.hz(100)], W.SINE, 0.06, 0.002, 3.0), 0.17)
		Sound.REROLL:
			# A shuffle.
			for i in 7:
				Synth.add(mix, Synth.noise(0.03, [6000, 2500], 0.14 + i * 0.015, 0.001, 2.0, 1000), i * 0.03)
		Sound.DENIED:
			Synth.add(mix, Synth.tone(0.09, [150], W.SQUARE, 0.12, 0.002, 0.5))
			Synth.add(mix, Synth.tone(0.14, [140], W.SQUARE, 0.12, 0.002, 1.0), 0.11)
		Sound.LAST_TURN:
			# A warning: two high beeps.
			for i in 2:
				Synth.add(mix, Synth.tone(0.11, [Synth.hz(88)], W.PULSE, 0.1, 0.002, 0.6, 0.6), i * 0.16)
				Synth.add(mix, Synth.tone(0.11, [Synth.hz(76)], W.SQUARE, 0.06, 0.002, 0.6, 0.6), i * 0.16)
		Sound.WIN:
			# Found the cheese: a quick arpeggio up to a held chord.
			var notes := [72, 76, 79, 84]
			for i in notes.size():
				Synth.add(mix, Synth.tone(0.14, [Synth.hz(notes[i])], W.PULSE, 0.12, 0.003, 1.0, 0.5), i * 0.08)
			for note: int in [72, 76, 79, 84]:
				Synth.add(mix, Synth.tone(0.8, [Synth.hz(note)], W.TRIANGLE, 0.12, 0.005, 1.5, 0.3, 0.2), 0.32)
			Synth.add(mix, Synth.tone(0.8, [Synth.hz(91)], W.PULSE, 0.07, 0.005, 1.8, 0.3, 0.25), 0.32)
		Sound.BOSS_WIN:
			# A fanfare.
			var notes := [[67, 0.0, 0.12], [72, 0.12, 0.12], [76, 0.24, 0.12], [79, 0.36, 0.3], [76, 0.66, 0.12],
				[79, 0.78, 0.12], [84, 0.9, 0.9]]
			for note: Array in notes:
				Synth.add(mix, Synth.tone(note[2], [Synth.hz(note[0])], W.PULSE, 0.12, 0.004, 1.0, 0.6, 0.25), note[1])
				Synth.add(mix, Synth.tone(note[2], [Synth.hz(note[0] - 12)], W.SQUARE, 0.06, 0.004, 1.0, 0.6), note[1])
			for note: int in [60, 64, 67, 72]:
				Synth.add(mix, Synth.tone(1.0, [Synth.hz(note)], W.TRIANGLE, 0.1, 0.01, 1.5, 0.4), 0.9)
			Synth.add(mix, Synth.tone(0.12, [130, 55], W.SINE, 0.5, 0.001, 2.0), 0.9)
		Sound.LOSE:
			# A sad slide down, wobbling on the last note.
			var notes := [[67, 0.0, 0.3], [66, 0.32, 0.3], [65, 0.64, 0.3], [64, 0.96, 0.9]]
			for note: Array in notes:
				var vibrato := 0.5 if note[1] > 0.9 else 0.0
				Synth.add(mix, Synth.tone(note[2], [Synth.hz(note[0])], W.SAW, 0.12, 0.02, 1.0, 0.6, vibrato), note[1])
				Synth.add(mix, Synth.tone(note[2], [Synth.hz(note[0] - 12)], W.TRIANGLE, 0.2, 0.02, 1.0, 0.6, vibrato),
					note[1])
	return mix
