extends RefCounted
## Sound fixes from the owner's listening: the music is slowed (a
## time-stretch in tools/build_audio.py, MUSIC "tempo"), so its loop is
## longer by that much and still loops cleanly; fire's sound ("burn", which
## rang like a slot machine when it played many times a second) is a soft
## crackle in several takes, and it plays at most once a quarter second
## (audio.gd GAP_MS) however many things call for it. Run by smoke_test.gd
## (_part_tests).

const Bank := preload("res://scripts/sound_bank.gd")

## The music's loop before it was slowed (seconds), and how much slower it is now.
const MUSIC_WAS := 80.0
const TEMPO := 0.85

var t


func run(smoke) -> void:
	t = smoke
	print("sound fixes: slower music, a fire crackle kept from rattling")
	_music()
	await _fire()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _music() -> void:
	var s = load(String(Bank.MUSIC["music"]))
	var length: float = s.get_length() if s != null else 0.0
	_check(absf(length - MUSIC_WAS / TEMPO) < 0.2, "the music is slowed to %d%%: its loop is %.1f s (was %.1f)" % [int(TEMPO * 100.0), length, MUSIC_WAS])
	_check(s != null and bool(s.get("loop")), "...and it still loops")


func _fire() -> void:
	var A = t.main.audio
	var keep: float = A.sound_level
	A.sound_level = 1.0
	_check(A.streams.has("burn") and A.streams["burn"].size() >= 4, "fire's crackle comes in several takes (%d), so repeats don't match" % A.streams.get("burn", []).size())
	# Called every frame for a second (a Flameblade swinging at full heat in a
	# burning room, say): it plays about four times, not sixty.
	A.last_played.erase("burn")
	var plays := 0
	var calls := 0
	var last := -1
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1000:
		t.main.sfx("burn", 1.3, -8.0)
		calls += 1
		var at := int(A.last_played.get("burn", -1))
		if at != last:
			plays += 1
			last = at
		await t.process_frame
	_check(calls >= 20 and plays >= 3 and plays <= 5, "called %d times in a second, fire's crackle played %d times (at most once a quarter second)" % [calls, plays])
	# Other sounds aren't held back like that.
	A.last_played.erase("hit")
	t.main.sfx("hit")
	var first := int(A.last_played.get("hit", -1))
	await t._wait(0.08)
	t.main.sfx("hit")
	_check(first >= 0 and int(A.last_played.get("hit", -1)) > first, "...while other sounds still play as often as before")
	A.sound_level = keep
