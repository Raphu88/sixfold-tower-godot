extends RefCounted
## THE BESTIARY: what the climber has learned of every monster, kept in the
## Library (the menu's Library page, its Bestiary tab, and a volume on the
## Library car's bookcase on the train).
##
## Entries fill in as monsters are met, a tier at a time:
##   not met  a dark silhouette and ???
##   seen     (it came on screen near the climber) its name, its picture,
##            and where it was first met (tower and floor)
##   fought   (you struck it, or it struck you) how it fights and what to
##            watch for, whether it flies or swims
##   slain    the first slaying: its health and its blows, and your tallies
##            (times slain, times it felled you); more slayings (TIERS) add
##            what it's weak to, then how it takes states
## Every word is here, in data (BESTIARY, TEXT), and in the Data editor's
## "The Bestiary" sections (data_registry.gd), so names and lines are easy
## to change. Each entry's `lore` is left blank for the owner to write; it
## shows once one has been slain. The numbers shown (health, blows, the
## weakness, flying and swimming, the beast's call for help) are read live
## from the game's own tables (enemy.gd TYPES, WEAKNESS, FLIERS, SWIMMERS,
## FLOCK, CHAMPION; floors.gd CURVE), never copied here.
##
## What each climber has met is kept in their profile (profile.gd
## `bestiary`, per climber, like the record of what they've slain): kind ->
## {"seen", "fought", "slain", "fell", "tower", "floor"}.
##
## The game tells this script what happens (each a single call):
##   attach(main)              main.gd _ready: blows the climber lands (main.on_hit)
##   watch(main, delta)        main.gd _physics_process: monsters coming on screen
##   hurt_by(main, source)     player.gd receive_attack: a monster's blow landed
##   slain(main, foe)          main.gd on_enemy_killed
##   fell(main)                main.gd on_player_died: the last monster to hurt you
## and it says so in play through notify() (the one place a notice is sent:
## the shared event call, main.note_event, into the left feed and the
## Entity's log, at most once per kind per floor).
##
## The picture of each monster is its own drawing: a real monster of that
## kind is made, posed and drawn once into its pen (enemy.gd _draw), and
## those triangles are drawn into the entry (Picture), so the Bestiary
## always looks like the game. Tests: tests/parts/bestiary.gd.

const Enemy := preload("res://scripts/enemy.gd")
const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const Reactions := preload("res://scripts/reactions.gd")
const UI := preload("res://scripts/ui.gd")

## How many slayings reach each tier past the first ("slain": ordinary
## monsters; "beast": a tower's beast): health and tallies, then what it's
## weak to, then how it takes states.
static var TIERS := {"slain": [1, 5, 15], "beast": [1, 2, 3]}

## Every monster's entry: its name, a plain account of how it fights and
## what to watch for ("desc"), how it takes states beyond what every monster
## shares ("states", blank if nothing), and its lore (blank: the owner's to
## write). Champions and creatures called to your side are noted on their
## kind's entry (TEXT "champion", "kin").
static var BESTIARY := {
	# --- found in every tower ---
	"slime": {"name": "Slime",
		"desc": "Creeps closer, then hops at you in a short pounce that glints first. After it lands it rests a moment, open to blows. A light hit makes it flinch.",
		"states": "", "lore": ""},
	"archer": {"name": "Archer",
		"desc": "Keeps its distance, backing off when you come close. It draws its bow (a red line shows its aim) and looses an arrow, then takes a while to reload. Parry the arrow to send it back, or roll through it. Get close.",
		"states": "", "lore": ""},
	"knight": {"name": "Knight",
		"desc": "Heavy and armoured. Up close it winds up a slash; from further out it lunges. Both glint first. Light blows don't make it flinch and it barely budges when struck, but it stands open after each attack: parry, then riposte.",
		"states": "", "lore": ""},
	# --- the Gryphon's tower ---
	"bat": {"name": "Bat",
		"desc": "Circles you on the wing, hangs still a moment, then swoops straight through where you stood. The swoop glints first: parry it. After a swoop it circles off to rest.",
		"states": "", "lore": ""},
	"thunderling": {"name": "Thunderling",
		"desc": "Walks up, stops and sparks, then bursts into a ring of lightning around it. The ring can't be parried: step out of it or roll through. It stands still a moment afterwards.",
		"states": "", "lore": ""},
	"harrier": {"name": "Harrier",
		"desc": "Soars high over the halls, where only its shadow shows, then folds its wings and dives at you with a glint. Its strike throws you the way it was flying, over an edge if you stand by one. After a dive it stands on the floor a moment, then climbs back up. Parry the dive near a drop and it tumbles over the edge.",
		"states": "", "lore": ""},
	"gryphon": {"name": "Gryphon",
		"desc": "Rakes with its talons up close, dives on you from range and lands hard, and throws a fan of five feathers. Every attack glints. The landing can't be parried: roll. It stays down a long moment after landing.",
		"states": "", "lore": ""},
	# --- the Kraken's tower ---
	"lurker": {"name": "Lurker",
		"desc": "Swims under the surface, where only ripples show and nothing can strike it. It rises near you, glints and lunges, then stays up a moment before it sinks again. Strike while it's up.",
		"states": "", "lore": ""},
	"shellback": {"name": "Shellback",
		"desc": "Plods toward you, turning slowly. Its shell turns blows from the front (a heavy blow cracks it): strike from behind. Up close it winds up a slow shell-bash.",
		"states": "", "lore": ""},
	"deepfin": {"name": "Deepfin",
		"desc": "Lives in deep water: only a fin shows as it shadows you along the bank, and nothing can touch it there. Come near the water and it rises, glints and leaps at you. Landed on stone it thrashes a moment, then drags itself back; out of the water too long, it dries out and weakens. With no deep water on the floor it keeps to the shallows like a lurker.",
		"states": "Out of the water it is always soaked, so lightning arcs through it, and it takes more from every blow.", "lore": ""},
	"kraken": {"name": "Kraken",
		"desc": "Sweeps a tentacle across a wide arc (parry it), slams three spots, one where you stand (can't be parried: roll), and spits three blobs of ink (parry them). It waits out a recovery after each attack.",
		"states": "", "lore": ""},
	# --- the Wyvern's tower ---
	"cinder": {"name": "Cinder",
		"desc": "A living ember that flits about at range and backs off when you come close. It glints and spits a burning ember: parry it and the ember flies back.",
		"states": "", "lore": ""},
	"smith": {"name": "Smith",
		"desc": "A slow, heavy forge-worker. Its hammer comes down just in front of it and leaves the floor burning. It can be parried, but it hits hard. It stands open after the swing.",
		"states": "", "lore": ""},
	"golem": {"name": "Forge golem",
		"desc": "A walking lump of iron that heats up as it fights: its seams glow from dull red to white. Hot, it shrugs off half of every blow, walks faster, leaves the floor burning where it slams, and now and then flares a ring of heat around it (can't be parried: get out, or roll). When it runs too hot it slumps to cool, and takes double from every blow. Its fist slam can be parried.",
		"states": "Soaked while it's warm, it is quenched: it slumps to cool at once, open to double damage.", "lore": ""},
	"wyvern": {"name": "Wyvern",
		"desc": "Sweeps its tail up close (parry it), breathes fire down a narrow cone that sets the floor alight (can't be parried: roll or step aside), and sprays five embers (parry them). Stay close, out of its breath.",
		"states": "", "lore": ""},
	# --- the Manticore's tower ---
	"scorpling": {"name": "Scorpling",
		"desc": "A small scorpion that scuttles up, glints and stings. A sting that lands poisons you for a few seconds: parry it.",
		"states": "", "lore": ""},
	"ram": {"name": "Ram",
		"desc": "A stone-hided brute that lowers its horns, glints and charges in a straight line. A ram that runs into a wall or pillar is stunned: let it miss.",
		"states": "", "lore": ""},
	"burrower": {"name": "Burrower",
		"desc": "Swims under the sand, seen only as a moving mound, and can't be struck there. Stand on sand near it and a ring marks the spot under you: it erupts out of it a moment later (can't be parried: step or roll off the ring), then stays up a moment. On stone it must come up: it crawls slowly, takes more from every blow and can only bite (parry it). Lure it onto the stone.",
		"states": "", "lore": ""},
	"manticore": {"name": "Manticore",
		"desc": "Swipes a claw up close (parry it), looses a volley of three poisoned tail spikes (parry them), and roars, bursting out all around it (can't be parried: roll through it).",
		"states": "", "lore": ""},
	# --- the Firebird's tower ---
	"wisp": {"name": "Wisp",
		"desc": "A flickering spirit that drifts around you, glints and darts straight through where you stood, leaving a little fire behind. Parry the dart.",
		"states": "", "lore": ""},
	"bloomcap": {"name": "Bloomcap",
		"desc": "A rooted fire-fungus that never moves. It glints, marks where you stand and lobs burning spores that land a moment later (can't be parried: step out of the circle). The ground they hit keeps burning. Get close.",
		"states": "", "lore": ""},
	"ashwing": {"name": "Ashwing",
		"desc": "An ember-bird that circles, glints and dives through where you stood, trailing fire. The first time it falls it sinks into a heap of glowing ash and rises again a few seconds later, unless the ash is struck or soaked first.",
		"states": "Fire doesn't burn it. Soaking its ash (water, or a soaking spell) keeps it from rising.", "lore": ""},
	"firebird": {"name": "Firebird",
		"desc": "Swoops straight through you in a burning line that leaves fire behind (parry it), calls a firestorm of four spots, one where you stand (can't be parried: get out of the circles), and fans out seven embers (parry them). The first time it falls it burns to ashes and rises again: save something for then.",
		"states": "As ashes, blows don't touch it.", "lore": ""},
	# --- the Chimera's tower ---
	"thornhound": {"name": "Thornhound",
		"desc": "A fast pack hound. It circles, glints and leaps at you with a bite. Parry the leap.",
		"states": "", "lore": ""},
	"mongrel": {"name": "Mongrel",
		"desc": "A patchwork beast that takes turns: a bite up close, then a fan of three quills thrown from range. Both glint, and both can be parried.",
		"states": "", "lore": ""},
	"briar": {"name": "Briar",
		"desc": "Hides as a bush, often beside brambles. Come close, or linger near, and it lashes out, grabs you and drags you toward it, squeezing (a roll breaks free). Then it stands and swipes until it can hide again.",
		"states": "Fire flushes it out of hiding: it reels, burning, open to blows.", "lore": ""},
	"chimera": {"name": "Chimera",
		"desc": "Three beasts in one. The lion mauls up close (parry it) and breathes fire down a narrow cone (can't be parried: roll or step aside); the goat charges in a straight line (parry it, or let it hit a wall and it's stunned); the serpent tail spits poisoned spikes (parry them).",
		"states": "", "lore": ""},
}

## The Bestiary's words. (%s and %d are filled in by the game.)
static var TEXT := {
	"tab": "Bestiary",
	"archive_tab": "Archive",
	"shelf": "Bestiary",
	"count": "Met %d of %d  ·  slain %d",
	"every": "Found in every tower",
	"locked": "???",
	"new": "New in the Bestiary: %s",
	"rise_fought": "Bestiary · %s: how it fights",
	"rise_slain": "Bestiary · %s: its health",
	"rise_weak": "Bestiary · %s: what it's weak to",
	"rise_states": "Bestiary · %s: how it takes states",
	"tier_seen": "Seen",
	"tier_fought": "Fought",
	"tier_slain": "Slain",
	"first": "First met: %s, floor %d",
	"flies": "Flies: it crosses chasms and drops.",
	"swims": "Swims: it moves through deep water.",
	"health": "Health %d  ·  its blows %d on the first floor (each floor up adds %d%% health, %d%% damage)",
	"health_beast": "Health %d  ·  its blows %d on the summit",
	"tally": "Slain %d  ·  felled you %d",
	"weak": "Weak to: %s",
	"states": "States: %s",
	"lifts": "It can be thrown into the air and can lose track of you.",
	"beast_states": "Too heavy to throw into the air (that only staggers it); it never loses track of you, and never flinches.",
	"under": "While it's under, blows miss it and burning or bleeding don't hurt it.",
	"gives": "Its blows would leave you %s.",
	"calls": "At half health it calls two %s for help.",
	"champion": "Champions: a larger one ringed in gold, with %s times the health and %s times the damage. Every few seconds near you it slams the ground around it: roll out of the ring.",
	"kin": "Bound in your kin book: your Covenant can call it to fight beside you.",
	"learn_fight": "Fight one to learn how it fights.",
	"learn_slay": "Slay one to learn its health.",
	"learn_weak": "Slay %d to learn what it's weak to (%d so far).",
	"learn_states": "Slay %d to learn how it takes states (%d so far).",
	"unmet": "Not met yet.",
}

## Kinds that hide under water, sand or leaves (they can't be struck there).
const HIDERS := ["lurker", "deepfin", "burrower", "briar"]
## A monster this near the climber, and on screen, has been seen (px).
const NEAR := 460.0
## How a monster stands for its picture (the state it's drawn in), and
## which way it faces: toward you, a little to the side.
const POSE := {"lurker": "up", "deepfin": "stranded", "burrower": "up", "briar": "rooted", "ashwing": "rest", "harrier": "perch", "bat": "hover"}
const FACE := Vector2(0.42, 0.91)
## How a level reads (0 not met .. 5 the last tier).
const LEVEL_NAMES := ["", "tier_seen", "tier_fought", "tier_slain", "tier_slain", "tier_slain"]
const RISE := {2: "rise_fought", 3: "rise_slain", 4: "rise_weak", 5: "rise_states"}


# --- the entries --------------------------------------------------------------------

## Every kind the Bestiary covers, in its groups: [[id, name, kinds]], the
## monsters found in every tower first, then each tower's (its own kinds by
## the floor they start on, its beast last). Read from the towers' and
## floors' own tables, so a new monster lands in its tower's group.
static func groups() -> Array:
	var every: Array = []
	var by := {}
	for t in Towers.ORDER:
		by[t] = []
	for kind in BESTIARY:
		if kind in Enemy.BOSSES:
			continue
		var m: Dictionary = Floors.MONSTERS.get(kind, {})
		var home := ""
		if bool(m.get("only", false)):
			for t in Towers.ORDER:
				if Towers.TOWERS[t].get("weights", {}).has(kind):
					home = t
					break
		if home == "":
			every.append(kind)
		else:
			by[home].append(kind)
	var from := func(a, b): return int(Floors.MONSTERS.get(a, {}).get("from", 1)) < int(Floors.MONSTERS.get(b, {}).get("from", 1))
	every.sort_custom(from)
	var out: Array = [["every", TEXT["every"], every]]
	for t in Towers.ORDER:
		var kinds: Array = by[t]
		kinds.sort_custom(from)
		var beast: String = Towers.TOWERS[t].get("beast_kind", "")
		if BESTIARY.has(beast):
			kinds.append(beast)
		out.append([t, Towers.TOWERS[t]["name"], kinds])
	return out


## Every kind, in the Bestiary's order.
static func kinds() -> Array:
	var out: Array = []
	for g in groups():
		out.append_array(g[2])
	return out


static func entry(kind: String) -> Dictionary:
	return BESTIARY.get(kind, {})


static func name_of(kind: String) -> String:
	return String(entry(kind).get("name", kind.capitalize()))


## What a climber has met of a kind ({} if nothing yet).
static func record(prof, kind: String) -> Dictionary:
	if prof == null or not ("bestiary" in prof):
		return {}
	var r = prof.bestiary.get(kind, {})
	return r if r is Dictionary else {}


## The slayings each tier past "fought" needs (TIERS).
static func thresholds(kind: String) -> Array:
	return TIERS["beast" if kind in Enemy.BOSSES else "slain"]


## How much of an entry shows: 0 not met, 1 seen, 2 fought, 3.. slain tiers.
static func level(prof, kind: String) -> int:
	var r := record(prof, kind)
	if r.is_empty():
		return 0
	var lv := 0
	if bool(r.get("seen", false)):
		lv = 1
	if bool(r.get("fought", false)):
		lv = 2
	var steps := thresholds(kind)
	var slain := int(r.get("slain", 0))
	for i in steps.size():
		if slain >= maxi(1, int(steps[i])):
			lv = maxi(lv, 3 + i)
	return lv


## The highest level an entry can reach.
static func top_level(kind: String) -> int:
	return 2 + thresholds(kind).size()


## [met, total, slain] over every kind.
static func counts(prof) -> Array:
	var all := kinds()
	var met := 0
	var slain := 0
	for k in all:
		if level(prof, k) > 0:
			met += 1
		slain += int(record(prof, k).get("slain", 0))
	return [met, all.size(), slain]


## A profile's records from a save (anything broken is dropped).
static func load_records(raw) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for k in raw:
		var r = raw[k]
		if not (r is Dictionary):
			continue
		out[String(k)] = {"seen": bool(r.get("seen", false)), "fought": bool(r.get("fought", false)),
			"slain": maxi(0, int(r.get("slain", 0))), "fell": maxi(0, int(r.get("fell", 0))),
			"tower": String(r.get("tower", "")), "floor": maxi(0, int(r.get("floor", 0)))}
	return out


# --- meeting monsters (the game's calls) ----------------------------------------------

## main.gd _ready: every blow that lands on a monster (yours, your
## creatures', your spells') means you're fighting it.
static func attach(main) -> void:
	if main.has_signal("on_hit"):
		main.on_hit.connect(func(foe, _dmg, _source): meet_foe(main, foe, "fought"))


## Is this a monster the Bestiary keeps (not a creature on your side, the
## Proving's shade of a beast or a mirror image), somewhere it counts (not
## the station's arena, not the train)?
static func counts_here(main, foe) -> bool:
	if main == null or main.profile == null or foe == null or not is_instance_valid(foe):
		return false
	if not ("kind" in foe) or not BESTIARY.has(String(foe.kind)):
		return false
	if foe.get("ally") or foe.get("shade") or foe.get("mirror"):
		return false
	if main.get("on_train"):
		return false
	var arena = main.get("arena")
	return arena == null or not arena.on


static func meet_foe(main, foe, how: String) -> void:
	if counts_here(main, foe):
		meet(main, String(foe.kind), how)


## A kind met: "seen", "fought", "slain" or "fell" (it felled you). The
## record only grows; a first meeting or a higher tier is told in play.
static func meet(main, kind: String, how: String) -> void:
	if main == null or main.profile == null or not BESTIARY.has(kind):
		return
	var prof = main.profile
	var before := level(prof, kind)
	var r := record(prof, kind).duplicate()
	if r.is_empty():
		r = {"seen": true, "fought": false, "slain": 0, "fell": 0, "tower": String(main.get("tower") if main.get("tower") != null else ""), "floor": int(main.get("floor_num") if main.get("floor_num") != null else 0)}
	r["seen"] = true
	match how:
		"fought":
			r["fought"] = true
		"slain":
			r["fought"] = true
			r["slain"] = int(r.get("slain", 0)) + 1
		"fell":
			r["fought"] = true
			r["fell"] = int(r.get("fell", 0)) + 1
	prof.bestiary[kind] = r
	var after := level(prof, kind)
	if after > before:
		_tell(main, kind, before, after)


## main.gd _physics_process: a monster on screen near the climber has been
## seen (a few times a second; hidden ones, under water, sand or leaves, and
## those the fog hides don't count).
static func watch(main, delta: float) -> void:
	var t: float = float(main.get_meta("bestiary_watch", 0.0)) - delta
	main.set_meta("bestiary_watch", t)
	if t > 0.0:
		return
	main.set_meta("bestiary_watch", 0.25)
	var p = main.player
	if p == null or p.dead or main.profile == null or main.get("on_train"):
		return
	var vp: Viewport = main.get_viewport()
	if vp == null:
		return
	var view := vp.get_visible_rect()
	var xf := vp.get_canvas_transform()
	for e in main.enemies():
		if e.dead or not e.visible or e.submerged or main.profile.bestiary.has(e.kind):
			continue
		if e.global_position.distance_to(p.global_position) > NEAR or not view.has_point(xf * e.global_position):
			continue
		meet_foe(main, e, "seen")


## player.gd receive_attack: a monster's blow (or its arrow, ember or
## spike) landed on the climber. Remembered too, for fell().
static func hurt_by(main, source) -> void:
	var foe = _foe_of(main, source)
	if foe == null or not counts_here(main, foe):
		return
	main.set_meta("bestiary_last", [String(foe.kind), Time.get_ticks_msec()])
	meet(main, String(foe.kind), "fought")


## main.gd on_enemy_killed.
static func slain(main, foe) -> void:
	meet_foe(main, foe, "slain")


## main.gd on_player_died: the monster that last hurt you (within a few
## seconds: poison and burns count) felled you.
static func fell(main) -> void:
	var last = main.get_meta("bestiary_last", [])
	main.set_meta("bestiary_last", [])
	if last is Array and last.size() == 2 and Time.get_ticks_msec() - int(last[1]) < 10000:
		meet(main, String(last[0]), "fell")


## The monster behind a blow: itself, or for a shot, the monster it came from
## (the nearest one behind it, along its flight).
static func _foe_of(main, source):
	if source == null or not is_instance_valid(source) or main == null:
		return null
	if "kind" in source and "ally" in source:
		return source
	if not ("vel" in source) or source.get("friendly"):
		return null
	var back: Vector2 = -Vector2(source.vel).normalized()
	var at: Vector2 = source.global_position
	var best = null
	var best_d := INF
	for e in main.enemies():
		var to: Vector2 = e.global_position - at
		var along := to.dot(back)
		if along <= 0.0:
			continue
		var off := absf(to.cross(back))
		var d := off * 3.0 + along * 0.2
		if off < 60.0 + float(e.radius) and d < best_d:
			best_d = d
			best = e
	return best


## Says in play that the Bestiary learned something: once per kind per floor.
static func _tell(main, kind: String, before: int, after: int) -> void:
	var text: String = TEXT["new"] % name_of(kind) if before == 0 else TEXT[RISE.get(after, "rise_fought")] % name_of(kind)
	notify(main, kind, text)


## THE notice: the one place the Bestiary speaks in play. The game's shared
## event call (main.note_event, notices.gd): a line in the left feed, kept in
## the Entity's "This climb" log; its `once` key keeps it to one line per
## kind per floor.
static func notify(main, kind: String, text: String) -> void:
	if main.has_method("note_event"):
		main.note_event("news", text, UI.GILT_HI, true, "bestiary " + kind)


# --- what an entry says -----------------------------------------------------------------

## An entry's lines at the level the climber has reached: [[key, text]],
## each key naming the line (tests read them): "first", "desc", "moves",
## "calls", "champion", "kin", "health", "tally", "lore", "weak", "states",
## and "learn" for what the next tier tells.
static func lines(prof, kind: String) -> Array:
	var out: Array = []
	var lv := level(prof, kind)
	var e := entry(kind)
	var r := record(prof, kind)
	if lv <= 0:
		out.append(["learn", TEXT["unmet"]])
		return out
	var tw: String = String(r.get("tower", ""))
	if Towers.TOWERS.has(tw) and int(r.get("floor", 0)) > 0:
		out.append(["first", TEXT["first"] % [Towers.TOWERS[tw]["name"], int(r["floor"])]])
	if lv < 2:
		out.append(["learn", TEXT["learn_fight"]])
		return out
	out.append(["desc", String(e.get("desc", ""))])
	if kind in Enemy.FLIERS:
		out.append(["moves", TEXT["flies"]])
	elif kind in Enemy.SWIMMERS:
		out.append(["moves", TEXT["swims"]])
	if kind in Enemy.BOSSES and Enemy.FLOCK.has(kind):
		var flock: String = Enemy.FLOCK[kind]
		out.append(["calls", TEXT["calls"] % (name_of(flock) + "s" if level(prof, flock) > 0 else TEXT["locked"])])
	if not kind in Enemy.BOSSES:
		out.append(["champion", TEXT["champion"] % [_num(float(Enemy.CHAMPION["hp"])), _num(float(Enemy.CHAMPION["dmg"]))]])
	if prof != null and "pacts" in prof and kind in prof.pacts:
		out.append(["kin", TEXT["kin"]])
	var steps := thresholds(kind)
	var slain := int(r.get("slain", 0))
	if lv < 3:
		out.append(["learn", TEXT["learn_slay"]])
		return out
	var t: Dictionary = Enemy.TYPES.get(kind, {})
	if kind in Enemy.BOSSES:
		var k := Floors.toughness(int(Towers.SUMMIT))
		out.append(["health", TEXT["health_beast"] % [int(round(float(t.get("hp", 0.0)) * k.x)), int(round(float(t.get("dmg", 0.0)) * k.y))]])
	else:
		out.append(["health", TEXT["health"] % [int(round(float(t.get("hp", 0.0)))), int(round(float(t.get("dmg", 0.0)))),
			int(round(float(Floors.CURVE["health"]) * 100.0)), int(round(float(Floors.CURVE["damage"]) * 100.0))]])
	out.append(["tally", TEXT["tally"] % [slain, int(r.get("fell", 0))]])
	if String(e.get("lore", "")).strip_edges() != "":
		out.append(["lore", String(e["lore"])])
	if lv < 4:
		if steps.size() > 1:
			out.append(["learn", TEXT["learn_weak"] % [int(steps[1]), slain]])
		return out
	if Enemy.WEAKNESS.has(kind):
		out.append(["weak", TEXT["weak"] % String(Enemy.WEAKNESS[kind])])
	if lv < 5:
		if steps.size() > 2:
			out.append(["learn", TEXT["learn_states"] % [int(steps[2]), slain]])
		return out
	out.append(["states", TEXT["states"] % " ".join(state_lines(kind))])
	return out


## How a kind takes states: what every monster (or every beast) shares,
## then its own (BESTIARY "states"), then what its blows would leave on you
## if the owner switches that on (reactions.gd CLIMBER).
static func state_lines(kind: String) -> Array:
	var out: Array = [TEXT["beast_states"] if kind in Enemy.BOSSES else TEXT["lifts"]]
	if kind in HIDERS:
		out.append(TEXT["under"])
	var own := String(entry(kind).get("states", "")).strip_edges()
	if own != "":
		out.append(own)
	var gives = Reactions.CLIMBER.get("from", {}).get(kind, "")
	if bool(Reactions.CLIMBER.get("enabled", false)) and Reactions.STATES.has(gives):
		out.append(TEXT["gives"] % String(Reactions.STATES[gives]["name"]).to_lower())
	return out


static func _num(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, round(x)) else ("%.1f" % x)


# --- the page (the Library's Bestiary tab and the Library car's lectern) ------------

## Builds the Bestiary into the menu's box (m.box): how many are met, then
## each group's tiles (met ones as pictures, the rest as silhouettes and
## ???), the open entry's card under its group. `width`: the room it has.
static func shelf(m, width: float, small: bool) -> void:
	var prof = m.main.profile if m.main != null else null
	var c := counts(prof)
	var head := m._label(TEXT["count"] % c, 0.0, UI.DIM)
	head.set_meta("bestiary_count", c)
	m.box.add_child(head)
	var tile := Tile.size_for(small)
	var gap := 6
	var cols := maxi(2, int((width + gap) / (tile.x + gap)))
	for g in groups():
		m._section(g[1])
		var grid: GridContainer = m._grid(cols, gap, gap)
		grid.set_meta("bestiary_group", g[0])
		for kind in g[2]:
			var b := Tile.new()
			b.kind = kind
			b.level = level(prof, kind)
			b.small = small
			b.on = m.bestiary_open == kind
			b.custom_minimum_size = tile
			if b.level > 0:
				b.set_meta("bestiary", kind)
				b.pressed.connect(m._bestiary_toggle.bind(kind))
			else:
				b.set_meta("bestiary_locked", kind)
				b.pressed.connect(func(): pass)
			grid.add_child(b)
		if m.bestiary_open in g[2] and level(prof, m.bestiary_open) > 0:
			m.box.add_child(card(prof, m.bestiary_open, width, small))


## An open entry: its picture beside its name, how far it's known, and the
## lines its level shows.
static func card(prof, kind: String, width: float, small: bool) -> PanelContainer:
	var lv := level(prof, kind)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(Color(UI.VOID, 0.6), Color(UI.GILT, 0.45), 6, 1, 10.0 if not small else 8.0))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.set_meta("bestiary_card", kind)
	pc.set_meta("bestiary_level", lv)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10 if small else 14)
	pc.add_child(row)
	var pic := Picture.new()
	pic.kind = kind
	pic.known = true
	var ps := 72.0 if small else 104.0
	pic.custom_minimum_size = Vector2(ps, ps)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2 if small else 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var wrap_w := maxf(120.0, width - ps - 50.0)
	var title := Label.new()
	title.text = name_of(kind)
	UI.style_label(title, "display", 19 if small else 22, UI.GOLD)
	UI.keep_text(title)
	col.add_child(title)
	var tier := String(TEXT[LEVEL_NAMES[clampi(lv, 0, LEVEL_NAMES.size() - 1)]])
	var tl := Label.new()
	tl.text = tier + ("  ·  %d / %d" % [lv - 1, top_level(kind) - 1] if lv > 0 else "")
	UI.style_label(tl, "eyebrow", UI.SIZE_EYEBROW, Color(UI.GOLD, 0.7))
	tl.set_meta("bestiary_tier", lv)
	col.add_child(tl)
	for ln in lines(prof, kind):
		var l := Label.new()
		l.text = String(ln[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = minf(wrap_w, 220.0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var colr := UI.TEXT
		var fs := UI.SIZE_BODY if not small else UI.SIZE_SMALL + 1
		match String(ln[0]):
			"first", "tally", "moves", "calls", "champion", "kin":
				colr = UI.DIM
			"learn":
				colr = UI.FAINT
			"lore":
				colr = Color(UI.GOLD, 0.85)
				UI.style_label(l, "inscription", UI.SIZE_INSCRIPTION if not small else UI.SIZE_BODY, colr)
			"weak":
				colr = UI.GILT_HI
		if String(ln[0]) != "lore":
			l.add_theme_color_override("font_color", colr)
			l.add_theme_font_size_override("font_size", fs)
		l.set_meta("bestiary_line", String(ln[0]))
		col.add_child(l)
	return pc


## A tile on the shelf: the monster's picture (or its silhouette) and its
## name (or ???). A button: mouse, keys, controller and taps open it.
class Tile extends Button:
	const UI := preload("res://scripts/ui.gd")
	const B := preload("res://scripts/bestiary.gd")
	var kind := ""
	var level := 0
	var on := false
	var small := false

	static func size_for(is_small: bool) -> Vector2:
		return Vector2(78, 84) if is_small else Vector2(92, 98)

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		text = ""
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		tooltip_text = ""
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var met := level > 0
		var hot := met and (is_hovered() or has_focus())
		var bg := Color(UI.VOID, 0.55) if met else Color(UI.VOID, 0.4)
		var edge := Color(UI.GILT, 0.95) if on else (Color(UI.GILT, 0.55) if hot else Color(UI.LINE, 0.75 if met else 0.5))
		draw_style_box(UI.box(bg, edge, 6, 2 if on else 1), r)
		var name_h := 18.0 if small else 20.0
		var pic := Rect2(r.position + Vector2(4, 3), Vector2(r.size.x - 8.0, r.size.y - name_h - 5.0))
		B.paint(self, kind, pic, met)
		var label: String = B.name_of(kind) if met else String(B.TEXT["locked"])
		var fs := 12 if small else 13
		var col := (UI.GOLD if (on or hot) else UI.TEXT) if met else UI.FAINT
		UI.draw_text(self, UI.font("body"), Vector2(r.position.x + 3.0, r.end.y - 6.0), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 6.0, fs, col)
		if met and level >= B.top_level(kind):
			draw_circle(r.position + Vector2(r.size.x - 8.0, 8.0), 3.0, UI.GILT_HI)  # (everything known)
		if has_focus() and not _touching():
			draw_style_box(UI.focus_box(), r.grow(2.0))

	func _touching() -> bool:
		var n := get_parent()
		while n != null:
			if n.has_method("rail_showing"):
				return n.main != null and n.main.touch_active
			n = n.get_parent()
		return false


## A monster's picture, as big as fits.
class Picture extends Control:
	const B := preload("res://scripts/bestiary.gd")
	var kind := ""
	var known := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		B.paint(self, kind, Rect2(Vector2.ZERO, size), known)


## Each kind's drawing, once: [pts, cols, glow pts, glow cols, body bounds,
## the number of leading shadow points], made from a real monster of the
## kind (its colour in the key, so a colour changed in the Data editor shows).
static var _shapes := {}


static func shape(kind: String) -> Dictionary:
	var t: Dictionary = Enemy.TYPES.get(kind, {})
	var key := "%s %s" % [kind, Color(t.get("color", Color.WHITE)).to_html()]
	if _shapes.has(key):
		return _shapes[key]
	var out := {"pts": PackedVector2Array(), "cols": PackedColorArray(), "glow": PackedVector2Array(), "glow_cols": PackedColorArray(), "bounds": Rect2(-10, -10, 20, 20), "shadow": 0}
	if t.is_empty():
		return out
	var e = Enemy.make(kind)
	e.setup(kind, null)
	e.submerged = false
	e.state = String(POSE.get(kind, "idle"))
	e.state_t = 1.0
	e.face = FACE
	e.set_meta("h", 0.0)  # (a harrier on the floor, not up in the sky)
	e._draw()
	RenderingServer.canvas_item_clear(e.get_canvas_item())
	out["pts"] = e._pen.pts.duplicate()
	out["cols"] = e._pen.cols.duplicate()
	out["glow"] = e._glow.pts.duplicate()
	out["glow_cols"] = e._glow.cols.duplicate()
	e.free()
	# The shadow on the floor comes first (pure black, faint): left out of the
	# bounds and the silhouette.
	var cols: PackedColorArray = out["cols"]
	var n := 0
	while n < cols.size() and cols[n].r == 0.0 and cols[n].g == 0.0 and cols[n].b == 0.0 and cols[n].a < 0.3:
		n += 1
	n -= n % 3
	out["shadow"] = n
	var pts: PackedVector2Array = out["pts"]
	if pts.size() > n:
		var b := Rect2(pts[n], Vector2.ZERO)
		for i in range(n, pts.size()):
			b = b.expand(pts[i])
		for p in out["glow"]:
			b = b.expand(p)
		out["bounds"] = b
	_shapes[key] = out
	return out


## Draws a kind's picture into `rect` of a control: in its colours, or as a
## dark silhouette (not met). Small monsters are drawn a little smaller than
## the beasts, so a bat doesn't loom like a gryphon.
static func paint(ci: CanvasItem, kind: String, rect: Rect2, known: bool) -> void:
	var s := shape(kind)
	var pts: PackedVector2Array = s["pts"]
	if pts.is_empty() or rect.size.x < 4.0 or rect.size.y < 4.0:
		return
	var b: Rect2 = s["bounds"]
	var fit := minf(rect.size.x / maxf(b.size.x, 1.0), rect.size.y / maxf(b.size.y, 1.0))
	var r := float(Enemy.TYPES.get(kind, {}).get("radius", 12.0))
	fit *= lerpf(0.72, 0.95, clampf((r - 9.0) / 17.0, 0.0, 1.0))
	var at := rect.get_center() - b.get_center() * fit
	var item := ci.get_canvas_item()
	var n: int = s["shadow"]
	if known:
		ci.draw_set_transform(at, 0.0, Vector2(fit, fit))
		RenderingServer.canvas_item_add_triangle_array(item, PackedInt32Array(), pts, s["cols"])
		var glow: PackedVector2Array = s["glow"]
		if not glow.is_empty():
			RenderingServer.canvas_item_add_triangle_array(item, PackedInt32Array(), glow, s["glow_cols"])
	else:
		var body := pts.slice(n)
		if body.is_empty():
			return
		var rim := PackedColorArray()
		rim.resize(body.size())
		rim.fill(Color(UI.LINE_HI, 0.35))
		var dark := PackedColorArray()
		dark.resize(body.size())
		dark.fill(Color(0.015, 0.012, 0.025, 0.96))
		var grow := 1.0 + 3.0 / maxf(b.size.x * fit, 1.0)
		ci.draw_set_transform(rect.get_center() - b.get_center() * fit * grow, 0.0, Vector2(fit * grow, fit * grow))
		RenderingServer.canvas_item_add_triangle_array(item, PackedInt32Array(), body, rim)
		ci.draw_set_transform(at, 0.0, Vector2(fit, fit))
		RenderingServer.canvas_item_add_triangle_array(item, PackedInt32Array(), body, dark)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
