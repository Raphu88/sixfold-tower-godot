extends Node
## Every sound is synthesised in code at startup, so there are no audio files.
## Call play("hit") etc. A small pool of players lets sounds overlap.

const RATE := 22050

var sounds := {}
var players: Array = []
var next_player := 0


func _ready() -> void:
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	sounds["swing"] = _wav(_swing(0.14, 0.3))
	sounds["swing_heavy"] = _wav(_swing(0.22, 0.42))
	sounds["hit"] = _wav(_hit(0.13, 150.0, 0.55))
	sounds["hit_heavy"] = _wav(_hit(0.2, 120.0, 0.75))
	sounds["crit"] = _wav(_crit())
	sounds["kill"] = _wav(_kill())
	sounds["parry"] = _wav(_parry())
	sounds["hurt"] = _wav(_hurt())
	sounds["roll"] = _wav(_noise_sweep(0.18, 300.0, 1400.0, 0.22))
	sounds["dodge"] = _wav(_dodge())
	sounds["zap"] = _wav(_zap())
	sounds["gust"] = _wav(_noise_sweep(0.45, 200.0, 2600.0, 0.4))
	sounds["burn"] = _wav(_burn())
	sounds["warn"] = _wav(_warn())
	sounds["charge"] = _wav(_charge())
	sounds["death"] = _wav(_death())
	sounds["clear"] = _wav(_clear())
	sounds["winded"] = _wav(_tone(0.1, 160.0, 120.0, 0.2, 18.0))


## pitch: base playback speed; a little random variance keeps repeats lively.
func play(sound: String, pitch := 1.0, volume_db := 0.0, variance := 0.06) -> void:
	if not sounds.has(sound):
		return
	var p: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = sounds[sound]
	p.pitch_scale = maxf(0.1, pitch * (1.0 + randf_range(-variance, variance)))
	p.volume_db = volume_db
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
		y += _lp_coef(2200.0) * (randf_range(-1.0, 1.0) - y)
		s[i] = (sin(phase) * exp(-t * 22.0) + y * 1.6 * exp(-t * 55.0)) * vol
	return s


func _crit() -> PackedFloat32Array:
	var s := _hit(0.32, 110.0, 0.8)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		phase += TAU * 1320.0 / RATE
		s[i] += sin(phase) * exp(-t * 11.0) * 0.22 + sin(phase * 1.51) * exp(-t * 15.0) * 0.12
	return s


func _kill() -> PackedFloat32Array:
	var s := _buf(0.45)
	var phase := 0.0
	var y := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := 320.0 * exp(-t * 6.0) + 50.0
		phase += TAU * f / RATE
		y += _lp_coef(900.0) * (randf_range(-1.0, 1.0) - y)
		s[i] = (sin(phase) * exp(-t * 7.0) * 0.6 + y * exp(-t * 9.0) * 1.2) * 0.7
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
		v += randf_range(-1.0, 1.0) * 0.5 * exp(-t * 120.0)
		s[i] = v * 0.85
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
		y += _lp_coef(1200.0) * (sq - y)
		s[i] = (y * 0.45 + randf_range(-1.0, 1.0) * 0.3 * exp(-t * 40.0)) * exp(-t * 9.0)
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
		s[i] = ((n - y) * gate * 0.8 + buzz * 0.12) * exp(-t * 7.0)
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
		y += _lp_coef(700.0) * (sq - y)
		s[i] = y * exp(-t * 2.5) * 0.5
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
