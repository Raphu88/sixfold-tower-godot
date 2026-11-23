extends RefCounted
## THE NOBLE: someone of standing at each station, in their estate (the
## station's "noble" stop, station_page.gd). Each of the six stations has
## its own Noble (stations.gd STATIONS "noble": placeholder names); the
## titles they grant are shared by every Noble. Two things:
##   TITLES     the Noble grants titles by renown (renown.gd TITLES: each
##              has a rank and a deed). The stop lists every title: what it
##              needs (its rank, its deed: done or not), what it gives (its
##              social benefits, titles.gd SOCIAL) and, once both are done,
##              "Be named ..." grants it and wears it. Wear one at a time.
##   CONTRACTS  tasks for the towers (contracts.gd): a few on offer each
##              visit, one or two held at once, tracked in play, paid when done.
## No lore: the name and lines are placeholders in data (the owner's to
## write), and the Data editor can change every word ("The Noble").

static var NOBLE := {"name": "Lady Placeholder", "short": "Noble", "style": "the Noble"}

## What the Noble says (one line is picked): arriving, a title granted, a
## contract taken, a contract given up, nothing on offer.
static var LINES := {
	"greet": ["\"Ah. The climber they mention. Sit.\"", "\"Renown opens doors. Some of them are mine.\"", "\"I have work, if you have nerve.\""],
	"granted": ["\"Wear it well. People will notice.\"", "\"A name is a door. Walk through it.\""],
	"taken": ["\"Good. Bring me word when it's done.\"", "\"I'll know when it's done. I always do.\""],
	"dropped": ["\"Another time, then.\"", "\"Pity. Someone else will take it.\""],
	"empty": ["\"Nothing for you today. Climb, and come back.\""],
	"rumour": ["\"A word from the towers, since you climb them:\"", "\"My people bring me news of the guardians:\""],
}
## How often the Noble's greeting carries a rumour of what the guardians
## have learned (guardian_lessons.gd), once any guardian has fallen.
static var RUMOUR_CHANCE := 0.6
## How often a Noble whose own tower isn't wild speaks of one that is.
static var WILD_CHANCE := 0.4

static var TEXT := {
	"titles": "Titles",
	"titles_note": "Titles are granted by renown. Each needs a rank and a deed, and gives something with the people around the towers. Wear one at a time.",
	"contracts": "Contracts",
	"contracts_note": "Tasks for the towers. You can hold %d at a time; each is tracked in play and pays when done.",
	"held": "Contracts you hold",
	"on_offer": "On offer",
	"none_offered": "Nothing on offer. New contracts come with your next visit.",
	"requires": "Needs",
	"req_rank": "The rank of %s",
	"req_deed": "%s",
	"done": "done",
	"not_done": "not yet",
	"tile_worn": "Wearing it",
	"tile_have": "Yours: choose to wear it",
	"tile_ready": "Ready: the Noble will grant it",
	"tile_needs": "Needs %s",
	"tile_deed": "Deed to do",
	"grant": "Be named %s",
	"wear": "Wear this title",
	"unwear": "Take it off",
	"worn_now": "Now wearing: %s",
	"unworn_now": "No title worn",
	"granted_now": "Granted: %s",
	"not_ready": "Not yet: %s",
	"take": "Take this contract",
	"drop": "Give it up",
	"taken_now": "Taken: %s",
	"dropped_now": "Given up: %s",
	"progress": "So far: %s",
	"title_shows": "A worn title shows under your name on the rail and in your book.",
}


static func line(key: String) -> String:
	var pool: Array = LINES.get(key, [])
	return String(pool[randi() % pool.size()]) if not pool.is_empty() else ""


## The Noble's greeting: a line, and now and then (RUMOUR_CHANCE; `chance`
## for tests) a rumour of what the guardians have learned. At a `station`
## whose tower runs wild the Noble always speaks of it (it's their city);
## elsewhere, now and then (WILD_CHANCE), of a wild tower (wild_towers.gd).
static func greet(prof, chance := -1.0, station := "") -> String:
	var said := line("greet")
	var r: String = load("res://scripts/guardian_lessons.gd").rumour(prof)
	if r != "" and randf() < (RUMOUR_CHANCE if chance < 0.0 else chance):
		said += " " + line("rumour") + " " + r
	var Wild = load("res://scripts/wild_towers.gd")
	var own: String = load("res://scripts/travel.gd").tower_of(station) if station != "" else ""
	if (own != "" and Wild.is_wild(prof, own)) or randf() < (WILD_CHANCE if chance < 0.0 else chance):
		var w: String = Wild.noble_word(prof, station)
		if w != "":
			said += " " + w
	return said


## The Noble's name: the station's own Noble (stations.gd STATIONS "noble"),
## else NOBLE's. Every station has its own; the titles they grant are shared.
static func name_of(station := "") -> String:
	if station != "":
		var own := String(load("res://scripts/stations.gd").station(station).get("noble", ""))
		if own != "":
			return own
	return String(NOBLE.get("name", "the Noble"))
