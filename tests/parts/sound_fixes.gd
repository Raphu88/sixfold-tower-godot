extends RefCounted
## Sound fixes from the owner's listening: fire's sound ("burn", which
## rang like a slot machine when it played many times a second) is a soft
## crackle in several takes, and it plays at most once a quarter second
## (audio.gd GAP_MS) however many things call for it. (The music, once
## slowed here, was replaced: tests/parts/music.gd.) Run by smoke_test.gd
## (_part_tests).

var t


func run(smoke) -> void:
	t = smoke
	print("sound fixes: a fire crackle kept from rattling")
	await _fire()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


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
	_check(calls >= 6 and plays >= 3 and plays <= 5,  # (a busy machine draws fewer frames in the second: the cap is what counts)
		 "called %d times in a second, fire's crackle played %d times (at most once a quarter second)" % [calls, plays])
	# Other sounds aren't held back like that.
	A.last_played.erase("hit")
	t.main.sfx("hit")
	var first := int(A.last_played.get("hit", -1))
	await t._wait(0.08)
	t.main.sfx("hit")
	_check(first >= 0 and int(A.last_played.get("hit", -1)) > first, "...while other sounds still play as often as before")
	A.sound_level = keep
