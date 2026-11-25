extends RefCounted
## The music director: which track plays where (audio.gd plays it, fading
## one into the next). It looks at the game a few times a second and picks
## a MOOD:
##   menu     the title and its pages, a new climber's start, the train and
##            the stations: "Fantasy: Rising Moon"
##   story    the introduction's screens, the Regard (and its glimpse of the
##            fracture and the Makers in it), a Maker's meeting, the Makers'
##            plea and the final meeting (story_scenes.gd), the ending: "Frost in the
##            Northern Winter", from its six tolls each time; when it's
##            over, what was playing before comes back where it left off
##   calm     a climb's quiet: Rising Moon again, softer, under the tower's
##            ambience
##   intense  a climb's danger: "Great Labyrinth". In a dangerous room
##            (DANGER themes: a den, a crypt, a guard post, a scenario...)
##            while anything there still lives, behind a lock-in's bars,
##            while a horde stands, or with monsters awake and close
##   boss     the guardian awake or close: the same track, louder
## Danger comes in quickly (RULES "enter_after") but leaves only once it has
## been gone a while ("leave_after") and the track has played a little
## ("min_hold"), so a monster stepping in and out of reach doesn't make the
## music flicker. Every number here can be changed in the Data editor.

## Each mood: the track (sound_bank.gd MUSIC) and its level in dB (before
## the Music slider). Calm and menu share a track: moving between them only
## changes its level.
static var MOODS := {
	"menu": {"track": "menu", "db": -12.0},
	"calm": {"track": "menu", "db": -17.0},
	"intense": {"track": "climb_intense", "db": -14.0},
	"boss": {"track": "climb_intense", "db": -11.0},
	"story": {"track": "story", "db": -10.0},
}

## Tracks that start from the top each time they come in (the story's six
## tolls); the others carry on where they were left.
const RESTART := ["story"]

## Seconds and distances:
##   check_every    how often the director looks (seconds)
##   fade           a crossfade, unless one below says otherwise
##   fade_danger    calm -> intense or boss (quick: the fight is on)
##   fade_calm      intense -> calm (slow: it settles)
##   fade_story     into and out of a story moment
##   enter_after    danger this long before the music turns
##   leave_after    no danger this long before it settles again
##   min_hold       the intense track plays at least this long
##   awake_reach    a monster awake within this many pixels counts as near
##   awake_count    this many awake and near make a fight
static var RULES := {
	"check_every": 0.25,
	"fade": 3.0,
	"fade_danger": 2.0,
	"fade_calm": 4.0,
	"fade_story": 2.5,
	"enter_after": 0.4,
	"leave_after": 6.0,
	"min_hold": 12.0,
	"awake_reach": 340.0,
	"awake_count": 2,
}

## Which rooms are dangerous while something there lives: room themes
## (themes.gd) of these kinds, and these themes by name.
static var DANGER := {
	"kinds": ["bad", "scenario"],
	"themes": ["post", "proving_sentinel", "proving_shadow"],
}

## A monster in one of these states hasn't noticed anyone yet.
const ASLEEP := ["idle", "rest", "sub", "ally"]

var mood := ""  # what the director picked last
var danger_t := 0.0  # how long danger has lasted (seconds)
var clear_t := 0.0  # how long it's been gone
var held_t := 0.0  # how long the intense track has played


## The mood now, `dt` real seconds after the last look.
func update(main, dt: float) -> String:
	var place := place_of(main)
	if place != "climb":
		danger_t = 0.0
		clear_t = 0.0
		held_t = 0.0
		mood = place
		return mood
	var d := danger_of(main)
	var tense := mood == "intense" or mood == "boss"
	if tense:
		held_t += dt
	if d != "":
		danger_t += dt
		clear_t = 0.0
		if d == "boss" or danger_t >= float(RULES["enter_after"]):
			if not tense:
				held_t = 0.0
			mood = d
			return mood
		# (not long enough yet: as before)
	else:
		danger_t = 0.0
		clear_t += dt
	if tense and (clear_t < float(RULES["leave_after"]) or held_t < float(RULES["min_hold"])):
		return mood
	mood = "calm"
	return mood


## Where the climber is: "story", "menu" or "climb" (a tower, the practice
## room or the station's arena, where calm and danger take over).
static func place_of(main) -> String:
	if main == null or not is_instance_valid(main):
		return "menu"
	if story_showing(main):
		return "story"
	var menu = main.get("menu")
	if menu != null and is_instance_valid(menu):
		if String(menu.page) == "intro":
			return "story"
		if menu.backdrop_showing() or (menu.is_open() and bool(menu.opened_from_title)):
			return "menu"
	if bool(main.get("on_train")) or bool(main.get("choosing_tower")):
		return "menu"
	return "climb"


## A story moment is playing: the Regard (with its glimpse of the
## fracture), a Maker's meeting, the ending. (The introduction is a menu
## page: place_of.)
static func story_showing(main) -> bool:
	var rg = main.get("regard")
	if rg is Dictionary and not rg.is_empty():
		return true
	var mk = main.get("makers")
	if mk != null and is_instance_valid(mk) and mk.meeting_live():
		return true
	var cs = main.get("climb_shape")
	if cs != null and is_instance_valid(cs) and cs.ending_view != null and is_instance_valid(cs.ending_view):
		return true
	if cs != null and is_instance_valid(cs) and cs.story_view != null and is_instance_valid(cs.story_view):
		return true  # (the Makers' plea, the final meeting: story_view.gd)
	return false


## The danger now: "boss" (the guardian awake or close), "intense" or "".
static func danger_of(main) -> String:
	var p = main.get("player")
	if p == null or not is_instance_valid(p) or p.dead:
		return ""
	var reach := float(RULES["awake_reach"])
	var room_rect = null
	var at := int(main.get("room_at")) if main.get("room_at") != null else -1
	var themes = main.get("room_themes")
	var info = main.get("room_info")
	if at >= 0 and themes is Array and info is Array and at < themes.size() and at < info.size() and danger_room(String(themes[at])):
		room_rect = info[at].get("rect")
	var awake := 0
	var in_room := false
	var guardian := false
	for e in main.enemies():
		if not is_instance_valid(e) or e.dead or e.ally:
			continue
		var near: bool = e.global_position.distance_to(p.global_position) < reach
		var up := not (String(e.state) in ASLEEP)
		if e.is_boss() and not e.shade and (up or near):
			guardian = true
		if room_rect is Rect2 and room_rect.has_point(e.global_position):
			in_room = true
		if up and near:
			awake += 1
	if guardian:
		return "boss"
	if in_room or awake >= int(RULES["awake_count"]):
		return "intense"
	var doors = main.get("door_view")
	if doors != null and is_instance_valid(doors):
		for i in doors.lock_rooms:
			if String(doors.lock_rooms[i].get("state", "")) == "shut":
				return "intense"
	var cs = main.get("climb_shape")
	if cs != null and is_instance_valid(cs) and cs.horde_live():
		return "intense"
	return ""


## A room theme (themes.gd) that's dangerous while something there lives.
static func danger_room(theme_id: String) -> bool:
	if theme_id in DANGER["themes"]:
		return true
	var th: Dictionary = preload("res://scripts/themes.gd").THEMES.get(theme_id, {})
	return String(th.get("kind", "")) in DANGER["kinds"]


## How long the fade into `to` from `from` takes (RULES).
static func fade_time(from: String, to: String) -> float:
	if from == "story" or to == "story":
		return float(RULES["fade_story"])
	if to == "intense" or to == "boss":
		return float(RULES["fade_danger"])
	if (from == "intense" or from == "boss") and to == "calm":
		return float(RULES["fade_calm"])
	return float(RULES["fade"])
