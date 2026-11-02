extends Node
## Every sound is synthesised in code at startup, so there are no audio files.
## Call play("hit") etc. A small pool of players lets sounds overlap.
##
## To keep things easy on the ears: every sound gets a short fade in and out
## (no clicks), a soft limiter, a per-sound level in LEVELS, and the same
## sound can't stack on itself within a few milliseconds.

const RATE := 22050
const MASTER_DB := -5.0
const FADE_IN := 0.004
const FADE_OUT := 0.03
const NO_STACK_MS := 45

## Per-sound loudness (linear). Tweak these to rebalance the mix.
const LEVELS := {
	"swing": 0.7, "swing_heavy": 0.75, "punch": 0.6, "punch_heavy": 0.7,
	"hit": 0.55, "hit_heavy": 0.6, "hit_light": 0.45, "crit": 0.55, "kill": 0.5,
	"parry": 0.45, "hurt": 0.5, "roll": 0.6, "dodge": 0.6, "zap": 0.4,
	"gust": 0.55, "burn": 0.5, "warn": 0.6, "charge": 0.6, "death": 0.5,
	"clear": 0.7, "winded": 0.6, "equip": 0.5, "draw": 0.55, "bow": 0.6,
	"ready": 0.5,
}

var sounds := {}
var players: Array = []
var next_player := 0
var last_played := {}


func _ready() -> void:
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	var made := {
		"swing": _swing(0.14, 0.3),
		"swing_heavy": _swing(0.22, 0.42),
		"punch": _swing(0.08, 0.28),
		"punch_heavy": _swing(0.14, 0.38),
		"hit": _hit(0.14, 150.0, 0.55),
		"hit_heavy": _hit(0.22, 120.0, 0.7),
		"hit_light": _hit(0.1, 210.0, 0.5),
		"crit": _crit(),
		"kill": _kill(),
		"parry": _parry(),
		"hurt": _hurt(),
		"roll": _noise_sweep(0.18, 300.0, 1400.0, 0.22),
		"dodge": _dodge(),
		"zap": _zap(),
		"gust": _noise_sweep(0.45, 200.0, 2200.0, 0.4),
		"burn": _burn(),
		"warn": _warn(),
		"charge": _charge(),
		"death": _death(),
		"clear": _clear(),
		"winded": _tone(0.12, 160.0, 120.0, 0.2, 18.0),
		"equip": _equip(),
		"draw": _draw_creak(),
		"bow": _pluck(),
		"ready": _tone(0.09, 1400.0, 1500.0, 0.25, 30.0),
	}
	for key in made:
		sounds[key] = _wav(_finish(made[key], LEVELS.get(key, 0.6)))


## pitch: base playback speed; a little random variance keeps repeats lively.
func play(sound: String, pitch := 1.0, volume_db := 0.0, variance := 0.06) -> void:
	if not sounds.has(sound):
		return
	# The same sound fired twice in a row at once just gets louder, not better.
	var now := Time.get_ticks_msec()
	if now - int(last_played.get(sound, -1000)) < NO_STACK_MS:
		return
	last_played[sound] = now
	var p: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = sounds[sound]
	p.pitch_scale = maxf(0.1, pitch * (1.0 + randf_range(-variance, variance)))
	p.volume_db = volume_db + MASTER_DB
	p.play()


# --- building blocks -------------------------------------------------------

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


## Level, fade in/out, and a soft limiter so peaks round off instead of clip.
func _finish(s: PackedFloat32Array, level: float) -> PackedFloat32Array:
	var n := s.size()
	var fin := int(FADE_IN * RATE)
	var fout := mini(int(FADE_OUT * RATE), n / 2)
	for i in n:
		var v := s[i] * level
		if i < fin:
			v *= float(i) / fin
		if i > n - fout:
			v *= float(n - i) / fout
		s[i] = tanh(v * 1.3) / 1.3
	return s


func _buf(dur: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(dur * RATE))
	return s


func _lp_coef(cutoff: float) -> float:
	return 1.0 - exp(-TAU * cutoff / RATE)


## Plain decaying sine glide (from -> to Hz).
func _tone(dur: float, from: float, to: float, vol: float, decay: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := lerpf(from, to, t / dur)
		phase += TAU * f / RATE
		s[i] = sin(phase) * exp(-t * decay) * vol
	return s


# --- the sounds --------------------------------------------------------------

func _swing(dur: float, vol: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var y := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var k := t / dur
		var cutoff := 400.0 + 2600.0 * sin(PI * k)
		y += _lp_coef(cutoff) * (randf_range(-1.0, 1.0) - y)
		s[i] = y * sin(PI * k) * vol * 2.2
	return s


func _hit(dur: float, base: float, vol: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var phase := 0.0
	var y := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := base * exp(-t * 14.0) + 45.0
		phase += TAU * f / RATE
		y += _lp_coef(1500.0) * (randf_range(-1.0, 1.0) - y)
		s[i] = (sin(phase) * exp(-t * 20.0) + y * 1.0 * exp(-t * 45.0)) * vol
	return s


func _crit() -> PackedFloat32Array:
	var s := _hit(0.32, 110.0, 0.8)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		phase += TAU * 1320.0 / RATE
		s[i] += sin(phase) * exp(-t * 11.0) * 0.12 + sin(phase * 1.51) * exp(-t * 15.0) * 0.06
	return s


func _kill() -> PackedFloat32Array:
	var s := _buf(0.45)
	var phase := 0.0
	var y := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := 320.0 * exp(-t * 6.0) + 50.0
		phase += TAU * f / RATE
		y += _lp_coef(700.0) * (randf_range(-1.0, 1.0) - y)
		s[i] = (sin(phase) * exp(-t * 7.0) * 0.6 + y * exp(-t * 9.0) * 0.7) * 0.7
	return s


func _parry() -> PackedFloat32Array:
	# Inharmonic partials ring like struck metal.
	var s := _buf(0.6)
	var partials := [[1250.0, 0.35, 7.0], [1870.0, 0.22, 9.0], [2630.0, 0.16, 12.0], [3410.0, 0.1, 16.0]]
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for p in partials:
			v += sin(TAU * p[0] * t) * p[1] * exp(-t * p[2])
		v += randf_range(-1.0, 1.0) * 0.12 * exp(-t * 90.0)
		s[i] = v * 0.7
	return s


func _hurt() -> PackedFloat32Array:
	var s := _buf(0.24)
	var phase := 0.0
	var y := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := lerpf(230.0, 95.0, t / 0.24)
		phase += TAU * f / RATE
		var sq := 1.0 if fmod(phase, TAU) < PI else -1.0
		y += _lp_coef(700.0) * (sq - y)
		s[i] = (y * 0.4 + randf_range(-1.0, 1.0) * 0.12 * exp(-t * 40.0)) * exp(-t * 9.0)
	return s


func _noise_sweep(dur: float, lo: float, hi: float, vol: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var y := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var k := t / dur
		y += _lp_coef(lerpf(lo, hi, sin(PI * k))) * (randf_range(-1.0, 1.0) - y)
		s[i] = y * sin(PI * k) * vol * 2.5
	return s


func _dodge() -> PackedFloat32Array:
	var s := _buf(0.28)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := lerpf(900.0, 1500.0, t / 0.28)
		phase += TAU * f / RATE
		s[i] = (sin(phase) + 0.4 * sin(phase * 2.0)) * exp(-t * 12.0) * 0.22
	return s


func _zap() -> PackedFloat32Array:
	var s := _buf(0.32)
	var y := 0.0
	var gate := 1.0
	for i in s.size():
		var t := float(i) / RATE
		if i % 180 == 0:
			gate = 1.0 if randf() < 0.65 else 0.15
		var n := randf_range(-1.0, 1.0)
		y += _lp_coef(1500.0) * (n - y)
		var buzz := 1.0 if fmod(t * 95.0, 1.0) < 0.5 else -1.0
		s[i] = ((n - y) * gate * 0.45 + buzz * 0.06) * exp(-t * 7.0)
	return s


func _burn() -> PackedFloat32Array:
	var s := _buf(0.4)
	var y := 0.0
	for i in s.size():
		var t := float(i) / RATE
		y += _lp_coef(300.0) * (randf_range(-1.0, 1.0) - y)
		var saw := fmod(t * 82.0, 1.0) * 2.0 - 1.0
		s[i] = (y * 2.2 + saw * 0.18) * exp(-t * 5.0) * 0.6
	return s


func _warn() -> PackedFloat32Array:
	var s := _buf(0.14)
	for i in s.size():
		var t := float(i) / RATE
		var env := minf(1.0, t * 200.0) * exp(-t * 18.0)
		s[i] = sin(TAU * 520.0 * t) * env * 0.3
	return s


func _charge() -> PackedFloat32Array:
	var s := _buf(0.3)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(200.0, 520.0, t / 0.3) / RATE
		s[i] = sin(phase) * minf(1.0, t * 30.0) * (1.0 - t / 0.3) * 0.18
	return s


func _death() -> PackedFloat32Array:
	var s := _buf(1.0)
	var phase := 0.0
	var y := 0.0
	for i in s.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(210.0, 45.0, t) / RATE
		var sq := 1.0 if fmod(phase, TAU) < PI else -1.0
		y += _lp_coef(500.0) * (sq - y)
		s[i] = y * exp(-t * 2.5) * 0.4
	return s


func _clear() -> PackedFloat32Array:
	var s := _buf(0.9)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for n in notes.size():
			var start := n * 0.11
			if t >= start:
				var lt := t - start
				v += sin(TAU * notes[n] * lt) * exp(-lt * 4.0) * 0.16
		s[i] = v
	return s


func _equip() -> PackedFloat32Array:
	# Two quick soft clicks, like a strap being tightened.
	var s := _buf(0.12)
	for i in s.size():
		var t := float(i) / RATE
		var v := sin(TAU * 900.0 * t) * exp(-t * 60.0)
		if t > 0.05:
			var lt := t - 0.05
			v += sin(TAU * 1250.0 * lt) * exp(-lt * 60.0) * 0.8
		s[i] = v * 0.3
	return s


func _draw_creak() -> PackedFloat32Array:
	# A rising, wooden creak as the string comes back.
	var s := _buf(0.6)
	var y := 0.0
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var k := t / 0.6
		phase += TAU * lerpf(90.0, 170.0, k) / RATE
		y += _lp_coef(lerpf(400.0, 1200.0, k)) * (randf_range(-1.0, 1.0) - y)
		var grain := 0.6 + 0.4 * sin(TAU * 30.0 * t)
		s[i] = (y * 0.9 * grain + sin(phase) * 0.12) * minf(1.0, t * 12.0) * (1.0 - k * 0.5) * 0.5
	return s


func _pluck() -> PackedFloat32Array:
	# Karplus-Strong plucked string: the bow's twang, plus a swish of air.
	var s := _buf(0.4)
	var period := int(RATE / 150.0)
	var ring := PackedFloat32Array()
	ring.resize(period)
	for i in period:
		ring[i] = randf_range(-1.0, 1.0)
	var air := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var idx := i % period
		var nxt := (i + 1) % period
		var v := ring[idx]
		ring[idx] = (ring[idx] + ring[nxt]) * 0.5 * 0.985
		air += _lp_coef(2500.0) * (randf_range(-1.0, 1.0) - air)
		s[i] = v * 0.4 + air * 0.5 * exp(-t * 25.0)
	return s
