extends RefCounted
## Bond definitions. Each bond is data; bond.gd reads it and runs its spells.
##
## A bond has:
##   affinity  the essence that forms it (and grows it fastest)
##   home      the body part it is drawn to when its essence takes hold
##   body      how it enhances a basic action (handled in player.gd)
##   passive   an always-on rule (handled where it applies)
##   spells    learned as the bond grows: each spell lists the step it is
##             learned at ("learn"), and its own "steps" table of values.
##             A step only lists what changes; anything left out carries
##             over from the step below. "changes" describes, in words, what
##             a later step does to an existing spell.
##
## Bonds grow across climbs from essence banked at stairs (see profile.gd),
## up to step 5. Designs follow the owner's Magic Redesign pages.
##
## Spell types (the code that runs them lives in bond.gd):
##   chain, overcharge, rod, thunderhead      (Stormcaller)
##   lift, crosswind, downdraft, cyclone      (Windwalker)
##   shot, track, hawkeye, rain               (Hunter)
##   surge, riptide, carry, maelstrom          (Tidecaller)
##   barrier, absorb, challenge, unbreakable   (Warden)
##   drain, anchor, siphon, drink              (Deepcaller)
##   blades                                    (Blade Forger)

const PARTS := ["hand", "legs", "heart", "brow"]
const PART_NAMES := {"hand": "Hand", "legs": "Legs", "heart": "Heart", "brow": "Brow"}
const PART_FILLS := {
	"hand": "fills when you land weapon strikes",
	"legs": "fills when you roll through an attack",
	"heart": "fills when you take a hit and survive",
	"brow": "fills when you parry",
}
const PART_BURN := {
	"hand": "burned: your strikes deal less damage",
	"legs": "burned: rolls cost more and travel less",
	"heart": "burned: your health is capped lower",
	"brow": "burned: your parry window is shorter",
}
## The cast key for each body part.
const PART_KEYS := {"hand": "Q", "legs": "E", "heart": "F", "brow": "C"}

const BONDS := {
	# --- the Gryphon's tower (Air) -------------------------------------------
	"stormcaller": {
		"name": "Stormcaller",
		"color": Color(0.95, 0.89, 0.42),
		"affinity": "air",
		"home": "hand",
		"tower": "gryphon",
		"body": {"name": "Quick Nerves", "desc": "your strikes and rolls recover faster"},
		"passive": {"name": "Static", "desc": "foes your lightning hits stay charged; striking a charged foe arcs to another"},
		"spells": [
			{"id": "chain_lightning", "name": "Chain Lightning", "type": "chain", "learn": 1,
				"desc": "lightning leaps between up to 4 foes",
				"changes": {3: "leaps 2 more times and stuns"},
				"steps": {
					1: {"cost": 12.0, "windup": 0.45, "leaps": 4, "damage": 10.0, "stun": 0.0, "reach": 280.0, "hop": 170.0},
					2: {"damage": 12.0},
					3: {"leaps": 6, "stun": 0.4},
					4: {"damage": 14.0},
					5: {"damage": 16.0},
				}},
			{"id": "overcharge", "name": "Overcharge", "type": "overcharge", "learn": 2,
				"desc": "charge one foe; when it dies, lightning leaps from it to every foe nearby",
				"steps": {2: {"cost": 9.0, "windup": 0.3, "duration": 8.0, "damage": 14.0, "radius": 170.0}, 4: {"damage": 18.0}}},
			{"id": "lightning_rod", "name": "Lightning Rod", "type": "rod", "learn": 4,
				"desc": "plant a rod; your chains bend through it, striking around corners",
				"steps": {4: {"cost": 8.0, "windup": 0.3, "duration": 10.0, "reach": 220.0}}},
			{"id": "thunderhead", "name": "Thunderhead", "type": "thunderhead", "learn": 5,
				"desc": "for 8 seconds every chain leaps twice as many times",
				"steps": {5: {"cost": 16.0, "windup": 0.4, "duration": 8.0}}},
		],
	},
	"windwalker": {
		"name": "Windwalker",
		"color": Color(0.75, 0.9, 1.0),
		"affinity": "air",
		"home": "legs",
		"tower": "gryphon",
		"body": {"name": "Wind Dash", "desc": "your roll becomes a long wind dash that carries you through foes"},
		"passive": {"name": "Featherweight", "desc": "airborne foes take extra damage from you"},
		"spells": [
			{"id": "gale_lift", "name": "Gale Lift", "type": "lift", "learn": 1,
				"desc": "a gust launches foes in front of you into the air, helpless",
				"changes": {3: "lifts every foe in a wide cone"},
				"steps": {
					1: {"cost": 10.0, "windup": 0.3, "arc": 35.0, "reach": 140.0, "lift": 1.5, "damage": 0.0},
					2: {"lift": 1.7},
					3: {"arc": 70.0, "reach": 175.0, "lift": 1.8},
					5: {"lift": 2.1},
				}},
			{"id": "crosswind", "name": "Crosswind", "type": "crosswind", "learn": 2,
				"desc": "a wall of wind that turns enemy arrows back at their shooter",
				"steps": {2: {"cost": 8.0, "windup": 0.25, "duration": 4.0, "length": 130.0}, 4: {"duration": 6.0, "length": 160.0}}},
			{"id": "downdraft", "name": "Downdraft", "type": "downdraft", "learn": 4,
				"desc": "slam every airborne foe into the ground, hurting foes where they land",
				"steps": {4: {"cost": 10.0, "windup": 0.3, "damage": 14.0, "splash": 7.0, "radius": 60.0}}},
			{"id": "eye_of_the_storm", "name": "Eye of the Storm", "type": "cyclone", "learn": 5,
				"desc": "a cyclone holds every foe in an area aloft for 5 seconds",
				"steps": {5: {"cost": 18.0, "windup": 0.5, "duration": 5.0, "radius": 110.0, "range": 150.0}}},
		],
	},
	"hunter": {
		"name": "Hunter",
		"color": Color(0.85, 0.63, 0.42),
		"affinity": "air",
		"home": "brow",
		"tower": "gryphon",
		"body": {"name": "Keen Eyes", "desc": "you see farther in the dark"},
		"passive": {"name": "Quarry", "desc": "you always know where the last foe you struck is"},
		"spells": [
			{"id": "piercing_shot", "name": "Piercing Shot", "type": "shot", "learn": 1,
				"desc": "a long-range arrow of essence that pierces a whole line of foes",
				"changes": {3: "a longer wind-up charges it for triple damage"},
				"steps": {
					1: {"cost": 9.0, "windup": 0.3, "damage": 12.0, "speed": 900.0, "charged": false},
					2: {"damage": 14.0},
					3: {"windup": 0.75, "charged": true},
					4: {"damage": 16.0},
				}},
			{"id": "track", "name": "Track", "type": "track", "learn": 2,
				"desc": "reveal every foe, and where it is heading, for 10 seconds",
				"steps": {2: {"cost": 6.0, "windup": 0.2, "duration": 10.0}}},
			{"id": "hawks_eye", "name": "Hawk's Eye", "type": "hawkeye", "learn": 4,
				"desc": "for 5 seconds every arrow strikes a weak point for double damage",
				"steps": {4: {"cost": 12.0, "windup": 0.25, "duration": 5.0}}},
			{"id": "rain_of_arrows", "name": "Rain of Arrows", "type": "rain", "learn": 5,
				"desc": "arrows fall on a marked area for 4 seconds",
				"steps": {5: {"cost": 16.0, "windup": 0.45, "duration": 4.0, "radius": 85.0, "range": 190.0, "damage": 5.0}}},
		],
	},
	# --- the Kraken's tower (Water) -------------------------------------------
	"tidecaller": {
		"name": "Tidecaller",
		"color": Color(0.37, 0.72, 0.79),
		"affinity": "water",
		"home": "legs",
		"tower": "kraken",
		"body": {"name": "Waterborn", "desc": "you move at full speed through water"},
		"passive": {"name": "Undercurrent", "desc": "foes you drive into a wall are stunned"},
		"spells": [
			{"id": "tidal_surge", "name": "Tidal Surge", "type": "surge", "learn": 1,
				"desc": "a wave bursts outward, hurling foes away from you",
				"changes": {3: "becomes an aimed wave that travels forward"},
				"steps": {
					1: {"cost": 12.0, "windup": 0.4, "radius": 115.0, "damage": 6.0, "push": 300.0, "aimed": false},
					2: {"damage": 8.0},
					3: {"aimed": true, "width": 150.0, "travel": 360.0},
					4: {"damage": 10.0},
					5: {"damage": 12.0, "width": 190.0},
				}},
			{"id": "riptide", "name": "Riptide", "type": "riptide", "learn": 2,
				"desc": "pull every foe in a line toward you",
				"steps": {2: {"cost": 9.0, "windup": 0.3, "length": 320.0, "width": 60.0, "damage": 4.0}}},
			{"id": "carry", "name": "Carry", "type": "carry", "learn": 4,
				"desc": "a wave carries every foe in front of you along with it until it breaks against a wall",
				"steps": {4: {"cost": 14.0, "windup": 0.45, "width": 160.0, "damage": 12.0}}},
			{"id": "maelstrom", "name": "Maelstrom", "type": "maelstrom", "learn": 5,
				"desc": "a whirlpool drags every foe in a wide area to its centre for 5 seconds",
				"steps": {5: {"cost": 18.0, "windup": 0.5, "duration": 5.0, "radius": 150.0, "range": 160.0, "damage": 3.0}}},
		],
	},
	"warden": {
		"name": "Warden",
		"color": Color(0.85, 0.71, 0.42),
		"affinity": "water",
		"home": "brow",
		"tower": "kraken",
		"body": {"name": "Heavy Frame", "desc": "keep holding parry to block: blocked hits deal far less and cost stamina"},
		"passive": {"name": "Steadfast", "desc": "while your barrier holds, you cannot be knocked back or interrupted"},
		"spells": [
			{"id": "barrier", "name": "Barrier", "type": "barrier", "learn": 1,
				"desc": "a shell that absorbs damage for 6 seconds",
				"changes": {3: "when it breaks, it releases everything it absorbed as a burst"},
				"steps": {
					1: {"cost": 12.0, "windup": 0.25, "duration": 6.0, "shield": 25.0, "burst": false},
					2: {"shield": 30.0},
					3: {"burst": true},
					4: {"shield": 36.0},
					5: {"shield": 44.0},
				}},
			{"id": "absorb", "name": "Absorb", "type": "absorb", "learn": 2,
				"desc": "for 2 seconds every hit you take is stored in your barrier instead",
				"steps": {2: {"cost": 8.0, "windup": 0.1, "duration": 2.0}}},
			{"id": "challenge", "name": "Challenge", "type": "challenge", "learn": 4,
				"desc": "every foe nearby must attack you for 4 seconds, and takes more damage from you",
				"steps": {4: {"cost": 10.0, "windup": 0.3, "duration": 4.0, "radius": 230.0}}},
			{"id": "unbreakable", "name": "Unbreakable", "type": "unbreakable", "learn": 5,
				"desc": "for 4 seconds you take no damage, but cannot attack",
				"steps": {5: {"cost": 16.0, "windup": 0.2, "duration": 4.0}}},
		],
	},
	"deepcaller": {
		"name": "Deepcaller",
		"color": Color(0.31, 0.5, 0.84),
		"affinity": "water",
		"home": "heart",
		"tower": "kraken",
		"body": {"name": "Deep Lungs", "desc": "your stamina refills faster"},
		"passive": {"name": "Pressure", "desc": "foes below half health move slower near you"},
		"spells": [
			{"id": "undertow", "name": "Undertow", "type": "drain", "learn": 1,
				"desc": "drag life from up to 3 foes and drink some of it back",
				"changes": {3: "drains up to 5 foes"},
				"steps": {
					1: {"cost": 12.0, "windup": 0.35, "targets": 3, "damage": 7.0, "reach": 210.0, "heal": 0.5},
					2: {"damage": 8.0},
					3: {"targets": 5},
					4: {"damage": 10.0},
					5: {"damage": 12.0},
				}},
			{"id": "anchor", "name": "Anchor", "type": "anchor", "learn": 2,
				"desc": "tether a foe so it cannot move away from you",
				"steps": {2: {"cost": 8.0, "windup": 0.25, "duration": 6.0, "length": 110.0, "reach": 300.0}}},
			{"id": "siphon", "name": "Siphon", "type": "siphon", "learn": 4,
				"desc": "drain essence instead of health, refilling your bonds",
				"steps": {4: {"cost": 4.0, "windup": 0.35, "targets": 3, "damage": 5.0, "reach": 200.0, "refill": 8.0}}},
			{"id": "drink_deep", "name": "Drink Deep", "type": "drink", "learn": 5,
				"desc": "channel a drain on one foe; it grows stronger every second it holds",
				"steps": {5: {"cost": 14.0, "windup": 0.3, "duration": 4.0, "reach": 260.0, "damage": 3.0}}},
		],
	},
	# --- the Wyvern's tower (Iron) ---------------------------------------------
	"blade_forger": {
		"name": "Blade Forger",
		"color": Color(0.65, 0.89, 0.71),
		"affinity": "iron",
		"home": "hand",
		"tower": "wyvern",
		"body": {"name": "", "desc": ""},
		"passive": {"name": "", "desc": ""},
		"spells": [
			{"id": "conjured_blades", "name": "Conjured Blades", "type": "blades", "learn": 1,
				"desc": "a fan of conjured blades that pierce through foes",
				"changes": {3: "five blades", 5: "seven blades"},
				"steps": {
					1: {"cost": 10.0, "windup": 0.35, "count": 3, "damage": 7.0, "spread": 18.0},
					2: {"damage": 9.0},
					3: {"count": 5, "spread": 14.0},
					4: {"damage": 11.0, "cost": 8.0},
					5: {"count": 7, "damage": 13.0},
				}},
		],
	},
}


## What reaching `step` brings a bond, in a few words: new spells learned and
## spells that change. Empty if nothing.
static func step_note(id: String, step: int) -> String:
	var bits: Array = []
	for sp in BONDS[id]["spells"]:
		if int(sp["learn"]) == step:
			bits.append("learns %s" % sp["name"])
		elif sp.get("changes", {}).has(step):
			bits.append("%s: %s" % [sp["name"], sp["changes"][step]])
	return ", ".join(bits)
