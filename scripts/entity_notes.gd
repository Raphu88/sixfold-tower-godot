extends RefCounted
## The Entity's small talk in play: one short line when something relevant
## happens (guide.gd remark), and the words of its log panel.
##
## TIDBITS are practical, true-to-the-mechanics facts in the Entity's light
## voice: about a tower and its own systems, a creature, a floor's task, a
## scenario, a room, a puzzle, a reaction, a lock. NEVER lore or story here:
## that is the owner's to write. LORE has an empty list for each tower; a
## line added there is said on arriving in that tower and shown in the panel.
## QUIPS are what it says when you open its panel.
##
## Keys ("kind:id"): tower:<tower>, system:<a tower's own system>,
## creature:<monster kind>, task:<objectives.gd kind>, scenario:<scenarios.gd
## kind>, theme:<themes.gd id>, puzzle:<kind>, lock:<kind>, and a few by
## name (doors, wing, crack, low_health, belt_full, pact, stair, proving).
## A reaction with no entry of its own says what reactions.gd says it does.
##
## One line is picked that hasn't been said this climb; a key waits
## COOLDOWN seconds before it speaks again, and tidbits keep GAP seconds
## apart, so the Entity never chatters. Everything here is in the Data
## editor ("The Entity's words").

## Seconds: between two tidbits, before the same key speaks again, how long
## a one-line bubble stays (plus PER_CHAR for each letter), and how long one
## may wait for its turn before it's dropped as stale.
const GAP := 7.0
const COOLDOWN := 45.0
const LIFE := 3.6
const LIFE_PER_CHAR := 0.035
const STALE := 9.0

## Each tower's own systems (their "system:" keys): one of these, or one of
## the tower's own lines, is said on arriving at a floor there.
const SYSTEMS := {
	"gryphon": ["drops", "wind"],
	"kraken": ["tides", "deep_water", "sunken"],
	"wyvern": ["molten", "heat", "barrels"],
	"manticore": ["sun", "shade", "sand"],
	"firebird": ["updrafts", "burning_bridges", "ember_storms"],
	"chimera": ["thorns", "brambles", "spores"],
}

static var TIDBITS := {
	# --- the towers ---------------------------------------------------------------
	"tower:gryphon": [
		"Open drops everywhere here. Step off one and you land on the floor below.",
		"Harriers and bats cross the drops. Walking things keep off them.",
	],
	"tower:kraken": [
		"Deep water can't be waded. You stop at its edge, and so do walking monsters.",
		"A deepfin stranded on stone takes half again from every blow.",
		"Shallow water soaks whatever wades in it. Soaked foes carry lightning.",
	],
	"tower:wyvern": [
		"Nothing walks across molten metal. Every channel has a bridge somewhere.",
		"A forge golem that overheats must vent. It takes double while it slumps.",
	],
	"tower:manticore": [
		"In the sun they see you from farther off. In shade, from under half as far.",
		"A burrower can only swim in sand. Stand on stone and it must come up.",
	],
	"tower:firebird": [
		"The rooms are islands. Miss a jump and you land on the floor below.",
		"An ashwing rises from its ash once. Scatter the ash, or soak it.",
	],
	"tower:chimera": [
		"Any blow cuts a thorn wall. Fire burns it at once. It grows back.",
		"A briar hides as a bush. Fire flushes it out, and a roll breaks its grip.",
	],
	# --- each tower's own systems -----------------------------------------------------
	"system:drops": ["Knocked off an edge, you fall one floor. So does a foe tossed up beside one."],
	"system:wind": [
		"Streaks in the air show a gust coming. Walk against it to keep your feet.",
		"A gust shoves whoever stands near a drop. That includes them.",
	],
	"system:tides": ["The water rises and drains on a cycle. Shallow water only slows you."],
	"system:deep_water": ["Pools stay deep. A second way round may flood at high tide and sweep you out."],
	"system:sunken": ["A sunken room has a sluice wheel next door. Stand at the wheel until it turns."],
	"system:molten": ["You see across molten metal, and arrows fly over it. Only feet are stopped."],
	"system:heat": ["A furnace glows before its hot spell. Linger in the ring and it burns you."],
	"system:barrels": ["Strike a water barrel: nearby heat dies for ten seconds. The splash soaks foes."],
	"system:sun": ["Sunlight drifts across each court. A small sun at your feet: you're in it."],
	"system:shade": ["In shade, a foe a few steps off loses track of you. Useful for a blow from behind."],
	"system:sand": [
		"A sand pit pulls you to its middle, swallows you, then spits you out. It hurts.",
		"Cracked flagstones crumble into sand once you've crossed them.",
	],
	"system:updrafts": ["Too wide to jump? Step on the vent beside the gap. The air carries you over."],
	"system:burning_bridges": ["Some bridges burn away behind you. They grow back from embers in a few seconds."],
	"system:ember_storms": ["A haze on one side means an ember storm. Stand behind rock and it passes over you."],
	"system:thorns": ["Some thickets stand open, then close behind you. Cut your way back."],
	"system:brambles": ["Brambles slow whoever walks them. A foe knocked into them bleeds."],
	"system:spores": ["Green pods poison everyone in the cloud. Blue ones calm the foes in it for a while."],
	# --- creatures (the first time each notices you in a climb) ------------------------------
	"creature:slime": ["A slime hops straight at you. Step aside, or parry the hop."],
	"creature:archer": ["An archer locks its aim before it looses: a red line. Parry the arrow and it goes back."],
	"creature:knight": ["A knight winds up its lunge: a filling red bar. Parry it and the knight staggers."],
	"creature:bat": ["Bats circle, then swoop through where you stood. Move as they glint."],
	"creature:thunderling": ["A thunderling sparks before it bursts. The ring can't be parried: step out or roll."],
	"creature:lurker": ["A lurker can't be struck under the water. Hit it while it's up."],
	"creature:shellback": ["A shellback's shell turns blows from the front. Get behind it, or hit it hard."],
	"creature:deepfin": ["A deepfin leaps from deep water. Parry the leap, then hit it while it's stranded."],
	"creature:cinder": ["A cinder spits a burning ember. Parry it and the ember turns back."],
	"creature:smith": ["A smith's hammer can be parried, but it hits hard. The floor burns where it lands."],
	"creature:golem": ["A hot golem takes half from your blows. Soak it, or wait for it to vent."],
	"creature:scorpling": ["A scorpling's sting poisons you for a few seconds. It can be parried."],
	"creature:ram": ["A ram charges in a straight line. Let it hit a wall or a pillar and it's stunned."],
	"creature:burrower": ["A burrower marks the sand under you before it erupts. Step off the ring."],
	"creature:wisp": ["A wisp darts through where you stood and leaves fire behind. It can be parried."],
	"creature:bloomcap": ["A bloomcap's spores can't be parried. Step out of the circle before they land."],
	"creature:ashwing": ["An ashwing dives through where you stood. When it falls, strike the ash before it rises."],
	"creature:thornhound": ["Thornhounds circle, glint, then leap. The bite can be parried."],
	"creature:mongrel": ["A mongrel takes turns: a bite up close, then a fan of quills. Both can be parried."],
	"creature:briar": ["That bush has eyes. If it grabs you, roll to break free."],
	"creature:harrier": ["A harrier's dive throws you the way it flew. Parry it on a ledge and it falls instead."],
	# --- the floor's task -------------------------------------------------------------
	"task:braziers": ["A blow puts out the brazier you're lighting. Clear the room first."],
	"task:runes": ["A wrong rune resets the path and brings guards. The tablet has the order."],
	"task:levers": ["Each lever falls back after a while. Plan a short route between them."],
	"task:orb": ["A blow knocks the orb from your hands. It lands near you: pick it up again."],
	"task:keeper": ["The Keeper carries the stair's key. It drops when the Keeper falls."],
	"task:wardstone": ["The wardstone charges only while its creatures are kept off it."],
	"task:shards": ["The key shards lie in guarded rooms. The arrow points at the nearest."],
	"task:motes": ["Motes drift away from you. Walls and corners stop them."],
	"task:sluices": ["Each sluice wheel lowers the water a step. A blow sets the wheel back."],
	"task:vanes": ["Each vane needs two blows. With the last, the wind carries you over the gap."],
	"task:rekindle": ["The flame gutters as you go. Braziers and lit beacons renew it."],
	"task:heartroots": ["Only the pulsing heart-root can be cut. Strike a sleeping one and its thorns lash you."],
	"task:furnaces": ["A cold furnace takes four blows on its bellows, and cools if you dawdle."],
	"task:sunstones": ["A sun stone turns an eighth a blow. It lights its seal as the sunlight crosses it."],
	"task:puzzle": ["Solving the puzzle lifts the ward on the stair."],
	# --- scenarios ---------------------------------------------------------------------
	"scenario:defend": ["The camp drains while a foe stands by it. Thirty seconds."],
	"scenario:collapse": ["Rocks mark the floor before they land. Fewer hits, better grade."],
	"scenario:duel": ["The duel is graded on the hits you take. None is gold."],
	"scenario:unseen": ["Stay out of the lantern beams. Seen three times and it's over."],
	"scenario:rescue": ["Three blows open the cage. Then the cub follows you to the door."],
	"scenario:gauntlet": ["Three waves, graded on your time. The doors open when it's done."],
	"scenario:flood": ["A blow knocks your hands off the drain wheel. Deal with what's close first."],
	"scenario:burning_bridge": ["The bridge burns behind you. If the fire catches you, you drop a floor."],
	"scenario:thicket": ["The thorns close ring by ring. It withers when it's over: you're never shut in."],
	"scenario:bridge": ["Gusts blow across the bridge toward the drop. Walk against them."],
	"scenario:forge": ["Strike a furnace's bellows to stoke it. A foe beside it puts it out faster."],
	"scenario:sinking": ["Only the old stones hold. Quicksand slows you, then swallows you."],
	# --- rooms (by theme) ------------------------------------------------------------------
	"theme:den": ["A den often shuts behind you, and its hoard stays shut while its monsters stand."],
	"theme:crypt": ["A crypt's dead rise as you walk in, and its doors usually shut."],
	"theme:pillars": ["Pillars stop arrows. Theirs and yours."],
	"theme:chasm": ["A jump clears a chasm. A fall costs you one floor, and nothing else."],
	"theme:spikes": ["Spikes click before they rise. Count the rhythm, then walk."],
	"theme:landing": ["From floor six, the stair landing may shut its doors until its guards fall."],
	"theme:rest": ["No creature comes into a Still Chamber. Standing here heals you."],
	"theme:trader": ["The trader takes unbanked essence: the kind you'd lose if you fell."],
	"theme:strongroom": ["A strongroom's lock is never on the way to the stair. Its key, lever or ward is."],
	"theme:post": ["A guard post's strongbox stays shut while its guards stand. Then walk up to it."],
	"theme:spring": ["A spring heals while you stand in it, until it runs dry."],
	"theme:tidepool": ["A tidepool heals while you stand in it, until it runs dry."],
	"theme:oasis": ["An oasis heals while you stand in it, until it runs dry."],
	"theme:cache": ["Walk up to the urn to take its essence. Spikes may guard it."],
	"theme:aerie": ["Walk up to the nest to take its essence. Spikes may guard it."],
	"theme:nest": ["Walk up to the nest to take its essence. Spikes may guard it."],
	"theme:camp": ["A fallen climber's pack usually holds an item. Walk over it."],
	"theme:forge": ["Something was left on the anvil. Walk over it."],
	"theme:pyre": ["Someone left a pack by the embers. Walk over it."],
	"theme:mirror": ["What steps out of the glass swings your weapon. Its guard turns light blows."],
	# --- puzzles ---------------------------------------------------------------------------
	"puzzle": ["The rule stays on the small ? in the room. Stand by it to read it again."],
	"puzzle:eyes": ["An arrow wakes an eye as well as a blow does."],
	"puzzle:plates": ["A monster is heavy enough for a plate. Lure one on."],
	"puzzle:statues": ["Stand by a statue to hear it. Only the plate behind the true way is safe."],
	"puzzle:mirrors": ["Strike or shoot a mirror to turn it. A grey one will not turn."],
	"puzzle:crumble": ["Each stone holds once. Find a path that uses them all."],
	"puzzle:ice": ["On the ice you slide until a rock stops you. Plan from the edge."],
	"puzzle:lock": ["A glowing foe drops a spark of its essence. A spell or weapon of that essence works too."],
	"puzzle:memory": ["The murals hang in other rooms, numbered. The pedestals want that order."],
	# --- locks, doors and walls ------------------------------------------------------------
	"lock:key": ["The key lies in another room, on the main way. A small gold glint."],
	"lock:carried": ["One of this floor's monsters carries that key. It drops when it falls."],
	"lock:lever": ["A lever in another room lifts those bars. Strike it."],
	"lock:puzzle": ["That ward opens when the stair's ward lifts."],
	"lock:oneway": ["Barred from the far side. Come round and it opens."],
	"lock": ["What's behind a lock is never needed for the stair. It is worth having."],
	"doors": [
		"The doors open again when everything that was in the room is dead.",
		"Shut doors never hold for good. Two and a half minutes at most.",
	],
	"wing": ["Keep the room's rule and its vault opens. Break it and the prize is smaller."],
	"crack": ["Dust falls from a cracked wall. A finishing blow breaks it."],
	"stair": ["Banked essence is safe. What you carry unbanked is lost if you fall."],
	"proving": ["The Proving is halfway up. A wound from it heals a stair at a time."],
	# --- you -------------------------------------------------------------------------------
	"low_health": [
		"You're low. The stair restores about a third of your health.",
		"Low. A healing item, a spring, or the stair.",
	],
	"belt_full": ["The belt is full. Walk off the item and back on to swap one out."],
	"pact": ["A pact holds while you carry both of its marks."],
}

## Each tower's story lines, for the owner to write. Empty: nothing is said.
## A line added here is said on arriving in that tower (once a climb) and
## shown in the Entity's panel.
static var LORE := {
	"gryphon": [],
	"kraken": [],
	"wyvern": [],
	"manticore": [],
	"firebird": [],
	"chimera": [],
}

## What the Entity says when you open its panel.
static var QUIPS := [
	"Yes? I was counting.",
	"You rang.",
	"I keep the list. You make it longer.",
	"Still here. So are you. Good.",
	"Ask. I wrote it all down.",
	"Poke me again and I'll add it to the log.",
	"Floor {floor}. I noticed too.",
	"Reading over my shoulder? Go on.",
	"Everything so far. In order, more or less.",
	"I was watching the other thing. Go ahead.",
]

## The panel's and the bubble's words.
static var TEXT := {
	"now": "Just now",
	"lore": "Of this tower",
	"log": "This climb",
	"log_empty": "Nothing yet. Do something.",
	"floor": "F%d",  # a log line's floor
	"open_key": "L",  # the key that opens the panel (controls.gd "entity")
	"open": "%s: the Entity's log",
	"close": "%s to close",
	"close_tap": "tap to close",
	"reaction": "%s: %s.",  # a reaction with no tidbit of its own: its name, what it does
	"idle": "Nothing to add. For now.",
}


## The lines for a key: its own; a reaction's falls back to what
## reactions.gd says it does; "a:b" falls back to "a".
static func lines(key: String) -> Array:
	if TIDBITS.has(key):
		return TIDBITS[key]
	if key.begins_with("reaction:"):
		var R = load("res://scripts/reactions.gd")
		var r: Dictionary = R.REACTIONS.get(key.trim_prefix("reaction:"), {})
		if not r.is_empty():
			return [String(TEXT["reaction"]) % [r["name"], r["says"]]]
		return []
	var cut := key.rfind(":")
	if cut > 0 and TIDBITS.has(key.left(cut)):
		return TIDBITS[key.left(cut)]
	return []


## The keys to choose from on arriving at a floor of `tower`.
static func arrival_keys(tower: String) -> Array:
	var out: Array = ["tower:" + tower]
	for s in SYSTEMS.get(tower, []):
		out.append("system:" + String(s))
	return out
