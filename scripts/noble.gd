extends RefCounted
## THE NOBLE: someone of standing who keeps rooms at the stations (the
## station's "noble" stop, station_page.gd). Two things:
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
}

static var TEXT := {
	"titles": "Titles",
	"titles_note": "Titles are granted by renown. Each needs a rank and a deed, and gives something with the people around the towers. Wear one at a time.",
	"contracts": "Contracts",
	"contracts_note": "Tasks for the towers. Hold up to %d at once; each is tracked in play and pays when done.",
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


static func name_of() -> String:
	return String(NOBLE.get("name", "the Noble"))
