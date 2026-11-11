extends RefCounted
## Bond definitions. Each bond is data; bond.gd reads it and runs its spells.
##
## A bond has:
##   affinity  the essence that forms it (and grows it fastest)
##   style     the body parts whose actions suit it: when two bonds share
##             an essence, the way you fought this climb decides between them.
##             A bond has no home part: it settles on whichever part you used most.
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
##   blades, recall, bladeward, edges          (Blade Forger)
##   kindle, lash, searing, overheat           (Flameblade)
##   trap, inscribe, ward, sigil               (Rune Artist)
##   quake, sandwall, sinkhole, fault          (Sandshaper)
##   spit, cloud, neuro, virulence             (Venomist)
##   veil, decoy, vanish, ashfall              (Ashwalker)
##   fireball, firewall, cluster, meteor       (Flame Contractor)
##   aura, wingburst, warmth, firebirdform     (Flamewing)
##   rekindle, desperation, pyre, phoenix      (Rekindler)
##   call, command, exchange, grandcall        (Covenant)
##   graftburst, mimic, shed, chimeraform      (Grafter)
##   sever, mend, transfer, amputate           (Surgeon)

## Six body parts, one for each of the six towers; each holds one bond.
const PARTS := ["hand", "legs", "heart", "brow", "throat", "back"]
static var PART_NAMES := {"hand": "Hand", "legs": "Legs", "heart": "Heart", "brow": "Brow", "throat": "Throat", "back": "Back"}
const PART_FILLS := {
	"hand": "fills when you land weapon strikes",
	"legs": "fills when you roll through an attack",
	"heart": "fills when you take a hit and survive",
	"brow": "fills when you parry",
	"throat": "fills when one action hits several foes",
	"back": "fills when you land backstabs and finishing blows",
}
const PART_BURN := {
	"hand": "burned: your strikes deal less damage",
	"legs": "burned: rolls cost more and travel less",
	"heart": "burned: your health is capped lower",
	"brow": "burned: your parry window is shorter",
	"throat": "burned: your stamina recovers more slowly",
	"back": "burned: backstabs lose their bonus damage",
}
## The cast key for each body part.
const PART_KEYS := {"hand": "Q", "legs": "E", "heart": "F", "brow": "C", "throat": "X", "back": "V"}

static var BONDS := {
	# --- the Gryphon's tower (Air) -------------------------------------------
	"stormcaller": {
		"name": "Stormcaller",
		"color": Color(0.95, 0.89, 0.42),
		"affinity": "air",
		"style": ["hand", "throat"],
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
		"style": ["legs", "throat"],
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
				"steps": {4: {"cost": 10.0, "windup": 0.3, "damage": 14.0, "splash": 5.0, "radius": 48.0}}},
			{"id": "eye_of_the_storm", "name": "Eye of the Storm", "type": "cyclone", "learn": 5,
				"desc": "a cyclone holds every foe in an area aloft for 5 seconds",
				"steps": {5: {"cost": 18.0, "windup": 0.5, "duration": 5.0, "radius": 110.0, "range": 150.0}}},
		],
	},
	"hunter": {
		"name": "Hunter",
		"color": Color(0.85, 0.63, 0.42),
		"affinity": "air",
		"style": ["brow", "back"],
		"tower": "gryphon",
		"body": {"name": "Keen Eyes", "desc": "you see farther in the dark and spot hidden traps"},
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
		"style": ["legs", "throat"],
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
		"style": ["heart", "brow"],
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
		"style": ["heart"],
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
		"style": ["hand", "back"],
		"tower": "wyvern",
		"body": {"name": "Long Edge", "desc": "your melee strikes reach farther"},
		"passive": {"name": "Weapon Memory", "desc": "your conjured blades copy the weapon you hold: more, quicker little knives with fists or a dagger, fewer and harder blades with a greatsword or hammer, swift piercing darts with a bow or crossbow"},
		"spells": [
			{"id": "conjured_blades", "name": "Conjured Blades", "type": "blades", "learn": 1,
				"desc": "a fan of conjured blades that pierce through foes",
				"changes": {3: "five blades"},
				"steps": {
					1: {"cost": 10.0, "windup": 0.35, "count": 3, "damage": 7.0, "spread": 18.0},
					2: {"damage": 9.0},
					3: {"count": 5, "spread": 14.0},
					4: {"damage": 11.0, "cost": 8.0},
					5: {"damage": 13.0},
				}},
			{"id": "recall", "name": "Recall", "type": "recall", "learn": 2,
				"desc": "blades that fly out, then return to you, striking again on the way back",
				"steps": {2: {"cost": 10.0, "windup": 0.3, "count": 3, "damage": 8.0, "spread": 22.0}, 4: {"damage": 10.0}, 5: {"damage": 12.0}}},
			{"id": "bladeward", "name": "Bladeward", "type": "bladeward", "learn": 4,
				"desc": "blades orbit you for 6 seconds, cutting foes that come close",
				"steps": {4: {"cost": 14.0, "windup": 0.3, "duration": 6.0, "damage": 3.0, "radius": 48.0}, 5: {"damage": 4.0}}},
			{"id": "thousand_edges", "name": "Thousand Edges", "type": "edges", "learn": 5,
				"desc": "a storm of conjured blades fans out toward your aim",
				"steps": {5: {"cost": 20.0, "windup": 0.45, "count": 14, "damage": 9.0, "spread": 70.0}}},
		],
	},
	"flameblade": {
		"name": "Flameblade",
		"color": Color(1.0, 0.5, 0.24),
		"affinity": "fire",
		"style": ["hand", "heart"],
		"tower": "wyvern",
		"body": {"name": "Hot Blood", "desc": "your strike chains never slow down: even the finisher recovers fast"},
		"passive": {"name": "Heat", "desc": "each strike in a row heats your weapon and hits harder; heat fades if you stop striking"},
		"spells": [
			{"id": "kindle_blade", "name": "Kindle Blade", "type": "kindle", "learn": 1,
				"desc": "your weapon is wreathed in fire for 6 seconds: strikes burn and build heat much faster",
				"changes": {3: "it lasts as long as you keep landing strikes"},
				"steps": {
					1: {"cost": 10.0, "windup": 0.25, "duration": 6.0, "damage": 3.0, "sustain": false},
					2: {"damage": 4.0},
					3: {"sustain": true},
					4: {"damage": 5.0},
					5: {"damage": 6.0},
				}},
			{"id": "flame_lash", "name": "Flame Lash", "type": "lash", "learn": 2,
				"desc": "a swing that throws a wave of fire forward",
				"steps": {2: {"cost": 9.0, "windup": 0.3, "damage": 12.0, "travel": 230.0, "width": 70.0}, 4: {"damage": 15.0}, 5: {"damage": 18.0}}},
			{"id": "searing_parry", "name": "Searing Parry", "type": "searing", "learn": 4,
				"desc": "kindles your weapon; while it burns, a parry explodes against the attacker",
				"steps": {4: {"cost": 10.0, "windup": 0.2, "duration": 6.0, "damage": 18.0}, 5: {"damage": 22.0}}},
			{"id": "overheat", "name": "Overheat", "type": "overheat", "learn": 5,
				"desc": "release all your heat in one strike: the more heat, the bigger the blow",
				"steps": {5: {"cost": 12.0, "windup": 0.3, "damage": 10.0, "reach": 90.0}}},
		],
	},
	"rune_artist": {
		"name": "Rune Artist",
		"color": Color(0.62, 0.66, 1.0),
		"affinity": "iron",
		"style": ["brow", "legs"],
		"tower": "wyvern",
		"body": {"name": "Steady Mind", "desc": "every spell you cast, from any bond, has a shorter wind-up"},
		"passive": {"name": "Runesmith", "desc": "at a camp, also inscribe a rune on your gear that lasts the rest of the climb (sharpness, warding or swiftness), or craft one more item"},
		"spells": [
			{"id": "rune_trap", "name": "Rune Trap", "type": "trap", "learn": 1,
				"desc": "inscribe a rune on the floor that detonates when a foe steps on it (up to 3)",
				"changes": {3: "Linked Runes: setting off one of your runes sets off every rune you have laid"},
				"steps": {
					1: {"cost": 8.0, "windup": 0.35, "damage": 16.0, "blast": 60.0, "linked": false},
					2: {"damage": 18.0},
					3: {"linked": true},
					4: {"damage": 22.0},
					5: {"damage": 26.0},
				}},
			{"id": "inscribe", "name": "Inscribe", "type": "inscribe", "learn": 2,
				"desc": "write a rune on your gear for the rest of the floor; each cast changes it: sharpness, warding, swiftness",
				"steps": {2: {"cost": 8.0, "windup": 0.4}}},
			{"id": "ward_circle", "name": "Ward Circle", "type": "ward", "learn": 4,
				"desc": "a rune circle around you that foes cannot enter for 5 seconds",
				"steps": {4: {"cost": 14.0, "windup": 0.35, "duration": 5.0, "radius": 75.0}}},
			{"id": "grand_sigil", "name": "Grand Sigil", "type": "sigil", "learn": 5,
				"desc": "a great rune circle; inside it your spells cost nothing for 6 seconds",
				"steps": {5: {"cost": 18.0, "windup": 0.5, "duration": 6.0, "radius": 120.0}}},
		],
	},
	# --- the Manticore's tower (Stone) -----------------------------------------
	"sandshaper": {
		"name": "Sandshaper",
		"color": Color(0.85, 0.7, 0.42),
		"affinity": "stone",
		"style": ["heart", "throat"],
		"tower": "manticore",
		"body": {"name": "Rooted Stance", "desc": "you cannot be knocked back or slowed"},
		"passive": {"name": "Shifting Sands", "desc": "foes walking up to you slow in their last few steps"},
		"spells": [
			{"id": "quake", "name": "Quake", "type": "quake", "learn": 1,
				"desc": "shatter the ground around you, leaving rubble that slows foes",
				"changes": {3: "it also throws up a ring of low walls around you"},
				"steps": {
					1: {"cost": 11.0, "windup": 0.35, "damage": 10.0, "radius": 95.0, "ring": false},
					2: {"damage": 12.0},
					3: {"ring": true},
					4: {"damage": 15.0},
					5: {"damage": 18.0},
				}},
			{"id": "sand_wall", "name": "Sand Wall", "type": "sandwall", "learn": 2,
				"desc": "raise a wall across your aim that blocks foes and their shots for 5 seconds",
				"steps": {2: {"cost": 9.0, "windup": 0.3, "duration": 5.0, "length": 150.0}}},
			{"id": "sinkhole", "name": "Sinkhole", "type": "sinkhole", "learn": 4,
				"desc": "a pit at your aim swallows a small foe, or traps a large one",
				"steps": {4: {"cost": 14.0, "windup": 0.4, "trap": 2.5}}},
			{"id": "fault_line", "name": "Fault Line", "type": "fault", "learn": 5,
				"desc": "split the floor in a line across your aim; foes cannot cross it for 8 seconds",
				"steps": {5: {"cost": 16.0, "windup": 0.45, "duration": 8.0, "length": 320.0}}},
		],
	},
	"venomist": {
		"name": "Venomist",
		"color": Color(0.55, 0.85, 0.35),
		"affinity": "stone",
		"style": ["hand", "back"],
		"tower": "manticore",
		"body": {"name": "Venom Glands", "desc": "your weapon strikes add a weak poison"},
		"passive": {"name": "Toxin Build", "desc": "poison stacks, and each new stack makes it last longer"},
		"spells": [
			{"id": "venom_spit", "name": "Venom Spit", "type": "spit", "learn": 1,
				"desc": "spit venom that poisons a foe (3 stacks)",
				"changes": {3: "the spit pierces through foes"},
				"steps": {
					1: {"cost": 7.0, "windup": 0.25, "damage": 4.0, "stacks": 3, "pierce": false},
					2: {"stacks": 4},
					3: {"pierce": true},
					4: {"stacks": 5},
					5: {"stacks": 6},
				}},
			{"id": "toxic_cloud", "name": "Toxic Cloud", "type": "cloud", "learn": 2,
				"desc": "a lingering cloud at your aim that poisons foes inside it",
				"steps": {2: {"cost": 10.0, "windup": 0.35, "duration": 6.0, "radius": 75.0}}},
			{"id": "neurotoxin", "name": "Neurotoxin", "type": "neuro", "learn": 4,
				"desc": "your next hit on a poisoned foe paralyzes it for 2 seconds",
				"steps": {4: {"cost": 8.0, "windup": 0.15, "duration": 8.0, "paralyze": 2.0}}},
			{"id": "virulence", "name": "Virulence", "type": "virulence", "learn": 5,
				"desc": "every poisoned foe in the room takes all its remaining poison at once",
				"steps": {5: {"cost": 14.0, "windup": 0.4}}},
		],
	},
	"ashwalker": {
		"name": "Ashwalker",
		"color": Color(0.78, 0.5, 0.42),
		"affinity": "fire",
		"style": ["back", "legs"],
		"tower": "manticore",
		"body": {"name": "Smokeborn", "desc": "you see through smoke and darkness: your light reaches farther"},
		"passive": {"name": "Unseen Strike", "desc": "striking a foe that hasn't noticed you, or has lost you, deals triple damage"},
		"spells": [
			{"id": "smoke_veil", "name": "Smoke Veil", "type": "veil", "learn": 1,
				"desc": "a cloud of smoke around you; foes inside it lose track of you",
				"changes": {3: "cast again while a cloud stands to ignite it, burning every foe inside"},
				"steps": {
					1: {"cost": 9.0, "windup": 0.25, "duration": 6.0, "radius": 85.0, "ignite": false, "damage": 0.0},
					3: {"ignite": true, "damage": 20.0},
					4: {"damage": 24.0},
					5: {"damage": 28.0},
				}},
			{"id": "afterimage", "name": "Afterimage", "type": "decoy", "learn": 2,
				"desc": "leave an ash copy of yourself; nearby foes go after it instead",
				"steps": {2: {"cost": 9.0, "windup": 0.2, "duration": 5.0}}},
			{"id": "vanish", "name": "Vanish", "type": "vanish", "learn": 4,
				"desc": "become unseen until you strike or 4 seconds pass",
				"steps": {4: {"cost": 12.0, "windup": 0.2, "duration": 4.0}}},
			{"id": "ashfall", "name": "Ashfall", "type": "ashfall", "learn": 5,
				"desc": "ash blankets the room for 10 seconds; foes lose track of you once you're out of reach",
				"steps": {5: {"cost": 16.0, "windup": 0.5, "duration": 10.0}}},
		],
	},
	# --- the Firebird's tower (Fire) ---------------------------------------------
	"flame_contractor": {
		"name": "Flame Contractor",
		"color": Color(1.0, 0.42, 0.18),
		"affinity": "fire",
		"style": ["throat", "back"],
		"tower": "firebird",
		"body": {"name": "Casting Stride", "desc": "you can walk while a spell winds up"},
		"passive": {"name": "Kindled", "desc": "foes your fire kills leave burning ground behind (it burns foes, not you)"},
		"spells": [
			{"id": "fireball", "name": "Fireball", "type": "fireball", "learn": 1,
				"desc": "a fireball that explodes on impact",
				"changes": {3: "a charged fireball: a longer wind-up and a much larger explosion"},
				"steps": {
					1: {"cost": 10.0, "windup": 0.35, "damage": 14.0, "radius": 55.0},
					2: {"damage": 16.0},
					3: {"windup": 0.6, "radius": 85.0, "damage": 20.0},
					4: {"damage": 23.0},
					5: {"damage": 26.0},
				}},
			{"id": "fire_wall", "name": "Fire Wall", "type": "firewall", "learn": 2,
				"desc": "a line of burning ground across your aim that burns foes crossing it",
				"steps": {2: {"cost": 10.0, "windup": 0.3, "duration": 5.0, "length": 170.0}}},
			{"id": "cluster_blast", "name": "Cluster Blast", "type": "cluster", "learn": 4,
				"desc": "a fireball that splits into three explosions on impact",
				"steps": {4: {"cost": 14.0, "windup": 0.4, "damage": 14.0, "radius": 50.0}, 5: {"damage": 17.0}}},
			{"id": "meteor", "name": "Meteor", "type": "meteor", "learn": 5,
				"desc": "a very long wind-up, then a great explosion over an area at your aim",
				"steps": {5: {"cost": 20.0, "windup": 1.0, "damage": 45.0, "radius": 130.0}}},
		],
	},
	"flamewing": {
		"name": "Flamewing",
		"color": Color(1.0, 0.68, 0.28),
		"affinity": "fire",
		"style": ["heart", "throat"],
		"tower": "firebird",
		"body": {"name": "Phoenix Glide", "desc": "hold jump to glide over gaps"},
		"passive": {"name": "Fireproof", "desc": "burning ground and fire hazards don't harm you"},
		"spells": [
			{"id": "heat_aura", "name": "Heat Aura", "type": "aura", "learn": 1,
				"desc": "turn on an aura that burns foes near you; it drains this mark's essence while on (cast again to turn it off)",
				"changes": {3: "the aura grows hotter the longer it stays on in a fight"},
				"steps": {
					1: {"cost": 6.0, "windup": 0.2, "damage": 3.0, "radius": 62.0, "drain": 2.5, "grows": false},
					2: {"damage": 3.5},
					3: {"grows": true},
					4: {"damage": 4.0},
					5: {"damage": 5.0},
				}},
			{"id": "wingburst", "name": "Wingburst", "type": "wingburst", "learn": 2, "free_in_form": true,
				"desc": "release the aura's built-up heat as burning wings around you",
				"steps": {2: {"cost": 10.0, "windup": 0.25, "damage": 12.0, "radius": 115.0}, 4: {"damage": 15.0}, 5: {"damage": 18.0}}},
			{"id": "warmth", "name": "Warmth", "type": "warmth", "learn": 4,
				"desc": "for 10 seconds your aura warms you too, restoring health (it will strengthen your creatures and allies once those exist)",
				"steps": {4: {"cost": 10.0, "windup": 0.2, "duration": 10.0, "heal": 2.5}}},
			{"id": "firebird_form", "name": "Firebird Form", "type": "firebirdform", "learn": 5,
				"desc": "for 8 seconds your aura doubles in size and Wingburst costs nothing",
				"steps": {5: {"cost": 16.0, "windup": 0.4, "duration": 8.0}}},
		],
	},
	"rekindler": {
		"name": "Rekindler",
		"color": Color(1.0, 0.36, 0.3),
		"affinity": "fire",
		"style": ["heart", "back"],
		"tower": "firebird",
		"body": {"name": "Stubborn Heart", "desc": "below a third of your health, you move and recover faster"},
		"passive": {"name": "Last Ember", "desc": "once per floor, a killing blow leaves you burning at 1 health for 3 seconds; land a hit in that time to stay standing"},
		"spells": [
			{"id": "rekindle", "name": "Rekindle", "type": "rekindle", "learn": 1,
				"desc": "set yourself alight: lose health over 5 seconds, then regain twice that if you kept fighting",
				"changes": {3: "while you burn, foes near you burn too"},
				"steps": {
					1: {"cost": 8.0, "windup": 0.2, "duration": 5.0, "loss": 0.15, "spread": false},
					3: {"spread": true},
					4: {"loss": 0.18},
					5: {"loss": 0.2},
				}},
			{"id": "desperation", "name": "Desperation", "type": "desperation", "learn": 2,
				"desc": "for 6 seconds, the lower your health, the harder and faster you strike",
				"steps": {2: {"cost": 9.0, "windup": 0.15, "duration": 6.0}}},
			{"id": "pyre_oath", "name": "Pyre Oath", "type": "pyre", "learn": 4,
				"desc": "for 10 seconds, a killing blow makes you explode instead, leaving you standing at 1 health",
				"steps": {4: {"cost": 12.0, "windup": 0.2, "duration": 10.0, "damage": 30.0}}},
			{"id": "phoenix_heart", "name": "Phoenix Heart", "type": "phoenix", "learn": 5,
				"desc": "for 10 seconds you cannot drop below 1 health",
				"steps": {5: {"cost": 16.0, "windup": 0.2, "duration": 10.0}}},
		],
	},
	# --- the Chimera's tower (Blade) -------------------------------------------------
	"covenant": {
		"name": "Covenant",
		"color": Color(0.9, 0.5, 0.55),
		"affinity": "blade",
		"style": ["hand", "throat"],
		"tower": "chimera",
		"body": {"name": "Pack Stride", "desc": "you move faster with one of your creatures nearby"},
		"passive": {"name": "Kinship", "desc": "monsters of a kind in your pact book are slower to notice you"},
		"spells": [
			{"id": "bind_and_call", "name": "Bind and Call", "type": "call", "learn": 1,
				"desc": "aimed at a monster below a quarter of its health: binds its kind into your pact book. Otherwise: calls the next creature of your retinue to fight beside you for 30 seconds",
				"changes": {3: "each Call brings two creatures (never more than three out at once)"},
				"steps": {
					1: {"cost": 14.0, "windup": 0.6, "duration": 30.0, "count": 1},
					3: {"count": 2},
				}},
			{"id": "command", "name": "Command", "type": "command", "learn": 2,
				"desc": "aimed at a foe: every creature attacks it. Aimed at no one: they fall back and guard you",
				"steps": {2: {"cost": 3.0, "windup": 0.05}}},
			{"id": "exchange", "name": "Exchange", "type": "exchange", "learn": 4,
				"desc": "swap places with your nearest creature",
				"steps": {4: {"cost": 8.0, "windup": 0.05}}},
			{"id": "grand_call", "name": "Grand Call", "type": "grandcall", "learn": 5,
				"desc": "every creature in your pact book appears at once for 12 seconds; drains the whole mark",
				"steps": {5: {"cost": 30.0, "windup": 1.0, "duration": 12.0}}},
		],
	},
	"grafter": {
		"name": "Grafter",
		"color": Color(0.75, 0.55, 0.7),
		"affinity": "blade",
		"style": ["hand", "heart"],
		"tower": "chimera",
		"body": {"name": "Adaptive Flesh", "desc": "each graft strengthens its body part's basic action: hand strikes, legs rolls, heart toughness, brow parries, throat stamina, back backstabs"},
		"passive": {"name": "Grafting", "desc": "slain monsters sometimes leave a graft; walk over it to bind it to its body part (one per part) for the rest of the climb"},
		"spells": [
			{"id": "graft_burst", "name": "Graft Burst", "type": "graftburst", "learn": 1,
				"desc": "strike every foe around you, harder for every graft you carry",
				"changes": {3: "each graft adds its own effect to the burst"},
				"steps": {
					1: {"cost": 10.0, "windup": 0.3, "damage": 9.0, "radius": 90.0, "effects": false},
					2: {"damage": 10.0},
					3: {"effects": true},
					4: {"damage": 12.0},
					5: {"damage": 14.0},
				}},
			{"id": "mimic", "name": "Mimic", "type": "mimic", "learn": 2,
				"desc": "use the power of your newest graft once",
				"steps": {2: {"cost": 9.0, "windup": 0.2, "damage": 16.0}, 4: {"damage": 20.0}}},
			{"id": "shed", "name": "Shed", "type": "shed", "learn": 4,
				"desc": "cast off your newest graft to heal its body part's burn and release a burst",
				"steps": {4: {"cost": 6.0, "windup": 0.2, "damage": 18.0}}},
			{"id": "chimera_form", "name": "Chimera Form", "type": "chimeraform", "learn": 5,
				"desc": "for 10 seconds every graft's power is doubled",
				"steps": {5: {"cost": 16.0, "windup": 0.4, "duration": 10.0}}},
		],
	},
	"surgeon": {
		"name": "Surgeon",
		"color": Color(0.85, 0.9, 0.95),
		"affinity": "blade",
		"style": ["brow", "back"],
		"tower": "chimera",
		"body": {"name": "Steady Hands", "desc": "healing works faster and heals more: Mend, the stair's rest, and healing items (30% more, in less time)"},
		"passive": {"name": "Diagnosis", "desc": "you see every foe's health, and what it is weak to"},
		"spells": [
			{"id": "sever", "name": "Sever", "type": "sever", "learn": 1,
				"desc": "a precise cut that cripples a foe: it can't run or charge for 6 seconds",
				"changes": {3: "a foe already crippled is disarmed instead: it can't attack for 6 seconds"},
				"steps": {
					1: {"cost": 8.0, "windup": 0.2, "damage": 8.0, "duration": 6.0, "disarm": false},
					2: {"damage": 10.0},
					3: {"disarm": true},
					4: {"damage": 12.0},
					5: {"damage": 14.0},
				}},
			{"id": "mend", "name": "Mend", "type": "mend", "learn": 2,
				"desc": "heal yourself and your creatures nearby, and cure poison",
				"steps": {2: {"cost": 12.0, "windup": 0.35, "heal": 25.0}, 4: {"heal": 32.0}, 5: {"heal": 40.0}}},
			{"id": "transfer", "name": "Transfer", "type": "transfer", "learn": 4,
				"desc": "move your poison and your burned body parts onto the foe you aim at",
				"steps": {4: {"cost": 10.0, "windup": 0.25}}},
			{"id": "amputate", "name": "Amputate", "type": "amputate", "learn": 5,
				"desc": "cripple and disarm a foe below half health for the rest of the fight",
				"steps": {5: {"cost": 16.0, "windup": 0.3}}},
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
	# A fork whose other side is written (tree.gd): the choice waits in the book.
	var alt: Dictionary = load("res://scripts/tree.gd").fork_alt(id, step)
	if step in [2, 3, 4] and not alt.is_empty() and not bool(alt.get("placeholder", false)):
		bits.append(FORK_NOTE % String(alt.get("name", "")))
	return ", ".join(bits)


## A step-note's words for a fork that's ready (the other side's name).
static var FORK_NOTE := "or %s: choose in your book"
