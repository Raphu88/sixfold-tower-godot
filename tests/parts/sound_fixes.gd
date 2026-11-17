extends RefCounted
## Sound fixes from the owner's listening: the music is slowed (a
## time-stretch in tools/build_audio.py, MUSIC "tempo"), so its loop is
## longer by that much and still loops cleanly. Run by smoke_test.gd
## (_part_tests).

const Bank := preload("res://scripts/sound_bank.gd")

## The music's loop before it was slowed (seconds), and how much slower it is now.
const MUSIC_WAS := 80.0
const TEMPO := 0.85

var t


func run(smoke) -> void:
	t = smoke
	print("sound fixes: slower music")
	_music()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _music() -> void:
	var s = load(String(Bank.MUSIC["music"]))
	var length: float = s.get_length() if s != null else 0.0
	_check(absf(length - MUSIC_WAS / TEMPO) < 0.2, "the music is slowed to %d%%: its loop is %.1f s (was %.1f)" % [int(TEMPO * 100.0), length, MUSIC_WAS])
	_check(s != null and bool(s.get("loop")), "...and it still loops")
