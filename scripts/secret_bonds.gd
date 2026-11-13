extends RefCounted
## The three secret bonds: the Developer, the Designer and the Manipulator.
## Each is a sliver of a Maker's own craft, a set of DEV TOOLS for its theme
## (the bonds, the tower, the creatures). They go much farther than any tower
## bond and share no feature with any other bond, item or essence.
##
## WHO HOLDS WHICH: the profile's `core_mark` ("", "developer", "designer"
## or "manipulator"; one per climber) and `core_depth` (0 to 5). The Makers
## (makers.gd, built alongside) grant it through a meeting and write those
## two fields; everything here only reads them (and the dev tools set them).
## Two more profile fields belong to the secret bonds: `core_xp` (what has
## been banked toward the next depth since the mark was taken),
## `core_tune` (the Developer's Tune: spell id -> "power", "cost" or "quick")
## and `core_edit` (the Developer's Edit: spell id -> {aspect: points}). The
## Developer's bribes are kept in the Makers' memory (profile.makers["bribe"]).
##
## THE TOOLS: one new tool per depth, from looking (depth 1) to rewriting
## (depth 5): inspect, switch, edit, reroll, build. Every tool costs
## essence, paid like a spell from what the climber carries (see COSTS).
## They're used from the TOOL RING (secret_tools.gd), the same hold gesture
## as the item ring; a tool with a choice ("cards") opens a few cards on the
## camp's card screen and is paid only when a card that does something is taken.
##
## Every word and number is here, so it's easy to rename or retune. Only
## plain mechanical text: nothing that could touch the story.

const Secret := preload("res://scripts/secret.gd")
const Essence := preload("res://scripts/essence.gd")
const Themes := preload("res://scripts/themes.gd")

const ORDER := ["developer", "designer", "manipulator"]
## The deepest depth reachable (every depth is built).
const CAP := 5
const MAX_DEPTH := 5

## The bonds. "color" is its Maker's colour (the same as makers.gd).
## "grows": what feeds it (GROWTH has the numbers).
static var BONDS := {
	"developer": {"name": "Developer", "the": "the Developer", "maker": "marks", "maker_name": "the Maker of Marks",
		"color": Color(0.56, 0.92, 1.0), "what": "tools for the bonds", "grows": "all essence"},
	"designer": {"name": "Designer", "the": "the Designer", "maker": "towers", "maker_name": "the Maker of Towers",
		"color": Color(1.0, 0.7, 0.32), "what": "tools for the tower", "grows": "Unmaking"},
	"manipulator": {"name": "Manipulator", "the": "the Manipulator", "maker": "creatures", "maker_name": "the Maker of Creatures",
		"color": Color(1.0, 0.44, 0.56), "what": "tools for the creatures", "grows": "Life"},
}

## A tool's cost: `flow` units of secret essence (`flow_kind`: "life",
## "unmaking" or "any" = your path's), paid from the flow you carry (unbanked);
## each unit you don't carry costs SUBSTITUTE ordinary essence instead. Plus
## `essence`: ordinary essence you carry (unbanked), taken from every kind you
## hold in proportion. Looking is cheap, rewriting expensive.
const SUBSTITUTE := 3.0

## The tools, by id. "depth": the depth that unlocks it. "where": "ring" (used
## in a climb from the tool ring) or "train" (between climbs, on the climber
## screen's Core tab). "lasts": "floor" (an Inspect: paid once, it stays for
## the floor; using it again on the same floor is free) or "" (paid each use).
## "reach": how far a targeted tool reaches (px). "tip": the Entity's tip id.
static var TOOLS := {
	"dev_inspect": {"bond": "developer", "depth": 1, "name": "Inspect", "where": "ring", "lasts": "floor",
		"cost": {"essence": 6.0, "flow": 1.0, "flow_kind": "any"},
		"short": "Every spell's real numbers",
		"desc": "Shows every spell's real numbers: damage, reach, cost, wind-up, and what each step adds. They show on the spell ring while you aim, and in a panel. Lasts the floor.",
		"tip": "tool_inspect_developer"},
	"dev_tune": {"bond": "developer", "depth": 2, "name": "Tune", "where": "train",
		"short": "Set spells for power, cost or speed",
		"desc": "Between climbs: set each spell you carry for more power, less cost or a quicker wind-up (on the climber screen's Core tab). Each change costs crystal essence.",
		"tip": "tool_tune"},
	"des_inspect": {"bond": "designer", "depth": 1, "name": "Inspect", "where": "ring", "lasts": "floor",
		"cost": {"flow": 2.0, "flow_kind": "unmaking", "essence": 1.0},
		"short": "The floor's whole plan",
		"desc": "Opens the floor's whole plan: rooms, corridors, every trap with its timing, hidden traps and secret walls, and what kind of room lies behind each door (never what it holds). Lasts the floor.",
		"tip": "tool_inspect_designer"},
	"des_switch": {"bond": "designer", "depth": 2, "name": "Switch", "where": "ring", "reach": 380.0,
		"cost": {"flow": 4.0, "flow_kind": "unmaking", "essence": 2.0},
		"short": "A trap off or on, a door open or shut",
		"desc": "At a distance: turns the trap you aim at off (or back on), or opens or shuts an unlocked door. A shut door holds for a while: nobody opens it.",
		"tip": "tool_switch_designer"},
	"man_inspect": {"bond": "manipulator", "depth": 1, "name": "Inspect", "where": "ring", "reach": 360.0,
		"cost": {"flow": 1.0, "flow_kind": "life", "essence": 1.0},
		"short": "A monster's numbers and next attack",
		"desc": "Reads the monster you aim at: its numbers, the essence it carries, and its next attack before it starts. The readout stays over it for the floor.",
		"tip": "tool_inspect_manipulator"},
	"man_calm": {"bond": "manipulator", "depth": 2, "name": "Calm", "where": "ring", "reach": 360.0,
		"cost": {"flow": 3.0, "flow_kind": "life", "essence": 2.0},
		"short": "It ignores you until struck",
		"desc": "Sets the monster you aim at calm: it ignores you until it's struck. Not a great foe.",
		"tip": "tool_calm"},
	"man_feud": {"bond": "manipulator", "depth": 2, "name": "Set against", "where": "ring", "reach": 360.0, "pair": 300.0,
		"cost": {"flow": 5.0, "flow_kind": "life", "essence": 3.0},
		"short": "Two monsters fight each other",
		"desc": "Sets the monster you aim at and the one nearest it against each other: they fight until one falls. Not a great foe.",
		"tip": "tool_feud"},
	# --- depth 3 to 5 ---
	"dev_edit": {"bond": "developer", "depth": 3, "name": "Edit", "where": "train",
		"short": "Move points between a spell's numbers",
		"desc": "Between climbs: move points between a spell's own numbers within a budget: more reach for less power, a longer effect for a slower wind-up, and so on (on the climber screen's Core tab). Each point raised costs crystal essence.",
		"tip": "tool_edit_developer"},
	"dev_splice": {"bond": "developer", "depth": 4, "name": "Splice", "where": "ring", "cards": true,
		"cost": {"essence": 12.0, "flow": 4.0, "flow_kind": "any"},
		"short": "A spell takes a second bond's behaviour",
		"desc": "Gives one of your spells a second bond's behaviour for the floor, picked from your other marks: a Chain Lightning that also pulls, a Barrier that also burns. One splice at a time: a new one replaces it.",
		"tip": "tool_splice"},
	"dev_write": {"bond": "developer", "depth": 5, "name": "Write", "where": "ring", "cards": true, "once": "floor",
		"cost": {"essence": 24.0, "flow": 8.0, "flow_kind": "any"},
		"short": "Cast any bond's spell, once a floor",
		"desc": "Once a floor: cast any bond's spell you don't have, at the step your best bond has reached. Between climbs, Write also moves your marks between body parts (on the Core tab).",
		"tip": "tool_write"},
	"des_edit": {"bond": "designer", "depth": 3, "name": "Edit", "where": "ring", "cards": true, "reach": 380.0,
		"cost": {"flow": 6.0, "flow_kind": "unmaking", "essence": 3.0},
		"short": "Re-time, move a trap, raise or sink a wall",
		"desc": "Re-times the beat of the trap room you aim at (slower, and quiet for a moment), moves the trap you aim at a few tiles, raises a stretch of wall in front of you for a while, or sinks a thin wall in front of you for a while. A trap room always stays crossable by timing.",
		"tip": "tool_edit_designer"},
	"des_reroll": {"bond": "designer", "depth": 4, "name": "Reroll", "where": "ring", "cards": true, "once": "floor",
		"cost": {"flow": 8.0, "flow_kind": "unmaking", "essence": 4.0},
		"short": "Choose the next floor's puzzle and rooms",
		"desc": "At the stair: choose the next floor's puzzle from two, then how its rooms lean from two. Not before the Proving or the summit. Once a floor.",
		"tip": "tool_reroll_designer"},
	"des_build": {"bond": "designer", "depth": 5, "name": "Build", "where": "ring", "cards": true,
		"cost": {"flow": 8.0, "flow_kind": "unmaking", "essence": 6.0},
		"short": "Your own trap, wall or gate; a rift",
		"desc": "Places a trap, wall or gate of your own in front of you, which monsters must respect (a few a floor; each costs its own), and once a climb tears a rift through the floor from where you stand to the stair: through rock, walls, doors, trap rooms and vaults. Anything locked it passes is opened, and what it held is taken, not given.",
		"tip": "tool_build_designer"},
	"man_edit": {"bond": "manipulator", "depth": 3, "name": "Edit", "where": "ring", "cards": true, "reach": 360.0,
		"cost": {"flow": 6.0, "flow_kind": "life", "essence": 3.0},
		"short": "Tune a monster, or turn it into a weaker kind",
		"desc": "Tunes the monster you aim at within a budget (slower, weaker, half its reach, or frail), or turns it into a weaker kind of its tower. Not a great foe.",
		"tip": "tool_edit_manipulator"},
	"man_reroll": {"bond": "manipulator", "depth": 4, "name": "Reroll", "where": "ring", "cards": true, "reach": 560.0,
		"cost": {"flow": 8.0, "flow_kind": "life", "essence": 4.0},
		"short": "Choose what a room holds, before you enter",
		"desc": "Aim at a room you haven't entered: its sleeping monsters become another pack of the tower's monsters, chosen from two.",
		"tip": "tool_reroll_manipulator"},
	"man_build": {"bond": "manipulator", "depth": 5, "name": "Build", "where": "ring", "cards": true, "reach": 300.0,
		"cost": {"flow": 14.0, "flow_kind": "life", "essence": 8.0},
		"short": "Rewrite a monster into your own",
		"desc": "Rewrites the monster you aim at into your own for the floor: it fights for you, and takes an attack from a second kind of its tower (a knight that also fires arrows). One at a time. Not a great foe.",
		"tip": "tool_build_manipulator"},
}

## The tool ring's entries for each bond, in order (only those unlocked show).
const RING := {
	"developer": ["dev_inspect", "dev_tune", "dev_edit", "dev_splice", "dev_write"],
	"designer": ["des_inspect", "des_switch", "des_edit", "des_reroll", "des_build"],
	"manipulator": ["man_inspect", "man_calm", "man_feud", "man_edit", "man_reroll", "man_build"],
}

## The Developer's Tune: one setting per spell. Multiplies the spell's
## power (everything it does: damage, shields, durations), its cost, or its
## wind-up. Changing a spell's setting costs TUNE_COST crystal essence (of any
## kinds, the largest stocks first); clearing it is free.
const TUNE := {
	"power": {"name": "Power", "desc": "20% more power", "power": 1.2},
	"cost": {"name": "Thrift", "desc": "25% less cost", "cost": 0.75},
	"quick": {"name": "Quick", "desc": "40% quicker wind-up", "windup": 0.6},
}
const TUNE_ORDER := ["power", "cost", "quick"]
const TUNE_COST := 6.0
## The Developer can change the climber's path (Life or Unmaking) at the
## train, from depth 1: all the path's flow resets and flows out of the
## shadow, and a new path starts from nothing. Costs crystal essence.
const PATH_CHANGE_COST := 20.0
const PATH_CHANGE_DEPTH := 1

## The Developer's Edit (depth 3, on the train): each spell's numbers are
## grouped in ASPECTS; a point raises one by EDIT_POINT (a share) and must be
## paid for by a point lowered in another of the same spell: the points of a
## spell add up to zero or less, each aspect between -EDIT_MAX and +EDIT_MAX.
## Each point raised costs EDIT_COST crystal essence; lowering one, or
## clearing a spell's edit, is free. "keys": the spell's numbers it changes
## ("power": everything its power drives, damage and shields; "windup" and
## "cost": those). "less": a raised point makes the number smaller (a quicker
## wind-up, a cheaper cast).
const EDIT_ASPECTS := {
	"power": {"name": "Power", "keys": ["power"], "desc": "damage, shields and what its power drives"},
	"reach": {"name": "Reach", "keys": ["reach", "range", "radius", "length", "width", "hop", "travel", "arc"], "desc": "reach, range, radius and width"},
	"time": {"name": "Length", "keys": ["duration", "stun", "lift"], "desc": "how long its effect lasts"},
	"speed": {"name": "Wind-up", "keys": ["windup"], "less": true, "desc": "a quicker wind-up"},
	"thrift": {"name": "Thrift", "keys": ["cost"], "less": true, "desc": "a cheaper cast"},
}
const EDIT_ORDER := ["power", "reach", "time", "speed", "thrift"]
const EDIT_POINT := 0.12
const EDIT_MAX := 3
const EDIT_COST := 4.0

## The Developer's Splice (depth 4): the behaviour each bond lends a spell
## spliced with it (by the source mark's bond). The behaviour is added to
## every foe the spliced spell strikes as it's cast; a spell that fires a shot
## passes it to the shot's hit; one that strikes nothing at once (a shield, a
## zone, a trap) releases it on the foes within SPLICE_PULSE of you.
const SPLICE_FROM := {
	"stormcaller": "stun", "windwalker": "knock", "hunter": "bolt", "tidecaller": "pull",
	"warden": "expose", "deepcaller": "heal", "blade_forger": "bolt", "flameblade": "burn",
	"rune_artist": "stun", "sandshaper": "knock", "venomist": "poison", "ashwalker": "blind",
	"flame_contractor": "burn", "flamewing": "burn", "rekindler": "heal", "covenant": "expose",
	"grafter": "burst", "surgeon": "cripple",
}
## The behaviours, with their numbers.
const SPLICE_FX := {
	"pull": {"name": "pulls", "desc": "pulls each foe it strikes toward you", "force": 420.0},
	"knock": {"name": "throws back", "desc": "throws each foe it strikes away from you", "force": 420.0},
	"burn": {"name": "burns", "desc": "sets each foe it strikes burning", "dmg": 3.0, "seconds": 4.0},
	"poison": {"name": "poisons", "desc": "puts poison on each foe it strikes", "stacks": 3},
	"stun": {"name": "stuns", "desc": "stuns each foe it strikes for a moment", "seconds": 0.7},
	"heal": {"name": "heals you", "desc": "heals you for each foe it strikes", "heal": 4.0},
	"bolt": {"name": "fires a bolt", "desc": "fires a bolt from each foe it strikes at the next foe near it", "share": 0.4, "reach": 220.0},
	"expose": {"name": "exposes", "desc": "leaves each foe it strikes exposed: it takes more damage for a while", "seconds": 4.0},
	"cripple": {"name": "cripples", "desc": "cripples each foe it strikes: it can't run or charge", "seconds": 3.0},
	"blind": {"name": "blinds", "desc": "makes each foe it strikes lose track of you", "seconds": 2.5},
	"burst": {"name": "bursts", "desc": "bursts around each foe it strikes, hurting those beside it", "share": 0.35, "radius": 60.0},
}
const SPLICE_PULSE := 120.0

## The Developer's Write (depth 5): spells it can't cast for you (forms and
## toggles that live in a mark, and the pact spells that write to your pact
## book). Moving a mark to another body part on the train costs MARK_MOVE_COST.
const WRITE_SKIP := ["aura", "firebirdform", "chimeraform", "mimic", "shed", "call", "command", "exchange", "grandcall"]
const MARK_MOVE_COST := 12.0

## The Designer's Edit (depth 3). Re-time: a trap room's beat runs RETIME
## times slower and goes quiet for RETIME_QUIET of a beat. Move: a trap (not
## a lane) moves up to MOVE_TILES tiles the way you aim. Raise: a stretch of
## RAISE_LEN tiles across your aim, RAISE_AHEAD tiles ahead, for WALL_TIME
## seconds. Sink: the first wall within SINK_REACH tiles the way you aim, if
## it's at most SINK_THICK tiles thick (never the floor's outer wall, never
## into a sealed wing, a secret room, a vault or the puzzle's sealed room),
## for WALL_TIME seconds.
const RETIME := 1.5
const RETIME_QUIET := 0.5
const MOVE_TILES := 3
const RAISE_LEN := 3
const RAISE_AHEAD := 2
const SINK_REACH := 3
const SINK_THICK := 2
const WALL_TIME := 20.0
const DES_EDIT := {
	"retime": {"name": "Re-time", "desc": "This trap room's beat runs half again slower, and goes quiet for a moment."},
	"move": {"name": "Move", "desc": "This trap moves up to %d tiles the way you aim, to open floor."},
	"raise": {"name": "Raise a wall", "desc": "A stretch of wall rises in front of you for %ds: it blocks bodies, sight and paths."},
	"sink": {"name": "Sink a wall", "desc": "The thin wall in front of you (two tiles at most) sinks for %ds: a way through."},
}

## The Designer's Reroll (depth 4): the next floor's puzzle from two kinds,
## then a LEAN for its rooms from two. A lean changes how themes.gd hands out
## rooms on that one floor: "good"/"quiet" are added to the chances of a good
## or quiet room, "max_good" to the cap, "feature_w" multiplies the weight of
## themes by feature. Used within STAIR_NEAR of the stair.
const LEANS := {
	"kind": {"name": "Kinder rooms", "desc": "More good rooms: springs, caches, camps.", "good": 0.35, "max_good": 1},
	"traps": {"name": "Trap halls", "desc": "Its bad rooms lean to traps.", "feature_w": {"trap": 5.0}},
	"lairs": {"name": "Lairs", "desc": "Its bad rooms lean to dens, pillared halls and crypts.", "feature_w": {"den": 4.0, "pillars": 4.0, "ambush": 4.0}},
	"hush": {"name": "Hushed halls", "desc": "More quiet halls, where nothing stirs.", "quiet": 0.35},
}
const STAIR_NEAR := 240.0

## The Designer's Build (depth 5): the palette, each with its own cost. At
## most BUILD_MAX a floor (the rift aside: once a climb). Built
## BUILD_AHEAD tiles in front of you. A trap is the tower's own plate, set off
## only by monsters; a wall lasts the floor; a gate lets you through but no
## monster (they go around); the rift (rift.gd) is a corridor two tiles wide
## torn from your spot to the stair, through anything in the way; anything
## locked it passes is opened and emptied. The dearest tool of all.
const BUILD := {
	"trap": {"name": "A trap", "desc": "The tower's own plate, ahead of you: only monsters set it off.", "cost": {"flow": 8.0, "flow_kind": "unmaking", "essence": 6.0}},
	"wall": {"name": "A wall", "desc": "A stretch of wall across your aim, for the floor. It never shuts the stair away.", "cost": {"flow": 10.0, "flow_kind": "unmaking", "essence": 6.0}},
	"gate": {"name": "A gate", "desc": "A gate across the way ahead: you pass, monsters don't (they go around).", "cost": {"flow": 10.0, "flow_kind": "unmaking", "essence": 8.0}},
	"rift": {"name": "A rift", "desc": "Once a climb: tear a corridor through the floor from here to the stair. Anything locked it passes opens, and what it held is lost.", "cost": {"flow": 28.0, "flow_kind": "unmaking", "essence": 30.0}},
}
const BUILD_ORDER := ["trap", "wall", "gate", "rift"]
const BUILD_MAX := 3
const BUILD_AHEAD := 2
## The rift's look: a faint light every `light_every` steps along it (reach, strength, glow).
const RIFT := {"light_every": 4, "light_reach": 80.0, "light": 0.3, "glow": 0.12}

## The Manipulator's Edit (depth 3): each a change to one monster; a monster
## takes at most MEDIT_MAX ("its budget"). Turning it into a weaker kind of
## its tower (a lower cost in floors.gd MONSTERS) uses up the budget; at most
## TURN_CHOICES kinds are offered.
const MEDIT := {
	"slow": {"name": "Slower", "desc": "It moves 40% slower.", "speed": 0.6, "tag": "slowed"},
	"weak": {"name": "Weaker", "desc": "Its blows deal 40% less.", "dmg": 0.6, "tag": "weakened"},
	"short": {"name": "Half its reach", "desc": "It only attacks from half as far.", "reach": 0.5, "tag": "short reach"},
	"frail": {"name": "Frail", "desc": "40% less health.", "hp": 0.6, "tag": "frail"},
}
const MEDIT_ORDER := ["slow", "weak", "short", "frail"]
const MEDIT_MAX := 2
const TURN_CHOICES := 2

## The Manipulator's Reroll (depth 4): two packs of the tower's monsters for
## a room, each about as strong as what was there (floors.gd costs).
const PACK_TRIES := 12

## The Manipulator's Build (depth 5): the second kind's attack it can take,
## by that kind: "shot" a bolt at its foe, "ring" a burst around itself,
## "blast" a burst on its foe, "dash" a leap that strikes, "venom" poison on
## its foe. "dmg" is a share of its own damage, "every" seconds between,
## "reach" px. At most SECOND_CHOICES kinds are offered.
const SECOND := {
	"slime": {"kind": "dash", "name": "Pounce"}, "archer": {"kind": "shot", "name": "Arrows"},
	"knight": {"kind": "dash", "name": "Lunge"}, "bat": {"kind": "dash", "name": "Swoop"},
	"thunderling": {"kind": "ring", "name": "Spark ring"}, "lurker": {"kind": "dash", "name": "Lunge"},
	"shellback": {"kind": "ring", "name": "Shell bash"}, "cinder": {"kind": "shot", "name": "Ember spit"},
	"smith": {"kind": "blast", "name": "Hammer"}, "scorpling": {"kind": "venom", "name": "Sting"},
	"ram": {"kind": "dash", "name": "Charge"}, "wisp": {"kind": "shot", "name": "Dart"},
	"bloomcap": {"kind": "blast", "name": "Spores"}, "thornhound": {"kind": "dash", "name": "Leap"},
	"mongrel": {"kind": "shot", "name": "Quills"},
}
const SECOND_FX := {
	"shot": {"dmg": 0.8, "every": 2.2, "reach": 360.0, "desc": "fires a bolt at its foe"},
	"ring": {"dmg": 0.9, "every": 3.0, "reach": 90.0, "desc": "bursts around itself"},
	"blast": {"dmg": 1.0, "every": 3.2, "reach": 260.0, "radius": 50.0, "desc": "bursts on its foe"},
	"dash": {"dmg": 1.2, "every": 2.6, "reach": 200.0, "desc": "leaps at its foe and strikes"},
	"venom": {"dmg": 0.5, "every": 2.4, "reach": 80.0, "stacks": 3, "desc": "poisons its foe"},
}
const SECOND_CHOICES := 3

## The Developer's bribe (one of its extra needs), offered on the train: a
## Regarded piece of gear (from your chest or pack), `crystals` crystal
## essence, or a full vessel from your chest (vessel.gd). The Maker of Marks
## may refuse (then nothing is taken): it agrees with `agree`, less `each`
## for every bribe offered before (it remembers), never below `least`; a
## full vessel adds `vessel` to that (at most `vessel_most`). An accepted
## bribe counts for the next depth only.
static var BRIBE := {"crystals": 120.0, "agree": 0.6, "each": 0.12, "least": 0.15, "vessel": 0.25, "vessel_most": 0.9}
## Tests: 1 it always agrees, 0 always refuses, -1 by chance.
static var bribe_force := -1

## Depth growth. "feed": what banked at a stair counts toward it ("essence"
## the six kinds, "life", "unmaking"). "need": banked since the mark for each
## depth (index = depth). The Developer's depths also each ask for ONE of ALSO.
const GROWTH := {
	"developer": {"feed": ["essence", "life", "unmaking"], "need": [0.0, 0.0, 400.0, 900.0, 1600.0, 2600.0], "also": true},
	"designer": {"feed": ["unmaking"], "need": [0.0, 0.0, 60.0, 150.0, 280.0, 450.0], "also": false},
	"manipulator": {"feed": ["life"], "need": [0.0, 0.0, 60.0, 150.0, 280.0, 450.0], "also": false},
}
## The Developer's extra need for each depth, any one of these:
##   mastery    `bonds` of your tower bonds at step `step`
##   knowledge  this many of the Makers' traces (fragments) found (index = depth)
##   favour     a task done for a tower beast (not in the game yet)
##   bribe      an offering the Maker of Marks accepts (see BRIBE)
const ALSO := {
	"mastery": {"bonds": 3, "step": 5},
	"knowledge": [0, 0, 8, 10, 12, 14],
}

## Monsters the Manipulator can't calm or set against another: great foes.
const RESIST := ["beast", "shadow", "mirror", "champion"]
## A Designer's shut door holds this long (seconds) before anyone may open it again.
const DOOR_HOLD := 30.0
## How long a feud lasts at most (seconds), then both go back to you.
const FEUD_TIME := 40.0

## The kind of room behind a door, by the room theme's feature (else its
## kind). Never what it holds: every good room is just "a good room".
const ROOM_KIND := {
	"start": "the way in", "stair": "the stair", "puzzle": "a puzzle", "trap": "traps", "den": "monsters",
	"ambush": "monsters", "pillars": "monsters", "chasm": "a chasm", "spring": "a good room", "cache": "a good room",
	"camp": "a good room", "proving": "the Proving",
}
const ROOM_KIND_BY := {"good": "a good room", "bad": "danger", "calm": "a quiet room", "mixed": "a room", "proving": "the Proving"}

## What each monster does and when: [wind-up state, attack, within (px, 0 =
## any), beyond (px), wind-up (s), damage (x its own), "or" (it may pick the
## next one instead), "odd" (only on its odd turns)]. The Manipulator's
## Inspect reads its next attack from these before it starts (enemy.gd).
const ATTACKS := {
	"slime": [["wind", "Pounce", 110.0, 0.0, 0.6, 1.0]],
	"archer": [["aim", "Arrow", 430.0, 0.0, 0.5, 1.0]],
	"knight": [["wind_slash", "Slash", 75.0, 0.0, 0.6, 1.0], ["wind_lunge", "Lunge", 200.0, 120.0, 0.7, 1.0]],
	"bat": [["wind", "Swoop", 170.0, 0.0, 0.45, 1.0]],
	"thunderling": [["wind_spark", "Spark ring", 75.0, 0.0, 0.9, 1.0]],
	"gryphon": [["wind_rake", "Rake", 95.0, 0.0, 0.55, 1.0], ["wind_dive", "Dive", 0.0, 140.0, 0.75, 1.0, "or"], ["wind_gale", "Gale", 0.0, 0.0, 0.6, 0.5]],
	"lurker": [["wind", "Lunge", 0.0, 70.0, 0.45, 1.0]],
	"shellback": [["wind_bash", "Shell bash", 60.0, 0.0, 0.7, 1.0]],
	"kraken": [["wind_sweep", "Sweep", 200.0, 0.0, 0.7, 1.0, "or"], ["wind_slam", "Slam", 0.0, 0.0, 0.9, 1.0, "or"], ["wind_ink", "Ink", 0.0, 0.0, 0.55, 0.5]],
	"cinder": [["wind_spit", "Ember spit", 210.0, 0.0, 0.6, 1.0]],
	"smith": [["wind_hammer", "Hammer", 75.0, 0.0, 0.85, 1.0]],
	"wyvern": [["wind_tail", "Tail", 105.0, 0.0, 0.6, 1.0], ["wind_breath", "Breath", 210.0, 0.0, 0.8, 1.0, "or"], ["wind_embers", "Embers", 0.0, 0.0, 0.6, 0.5]],
	"scorpling": [["wind_sting", "Sting", 60.0, 0.0, 0.5, 1.0]],
	"ram": [["wind_charge", "Charge", 210.0, 70.0, 0.8, 1.0]],
	"manticore": [["wind_claw", "Claw", 100.0, 0.0, 0.55, 1.0, "or"], ["wind_roar", "Roar", 130.0, 0.0, 0.9, 1.0], ["wind_spikes", "Tail spikes", 0.0, 0.0, 0.6, 0.5]],
	"wisp": [["wind", "Dart", 170.0, 0.0, 0.45, 1.0]],
	"bloomcap": [["wind_lob", "Spores", 340.0, 0.0, 0.9, 1.0]],
	"firebird": [["wind_swoop", "Swoop", 230.0, 0.0, 0.6, 1.0, "or"], ["wind_storm", "Firestorm", 0.0, 0.0, 0.9, 1.0, "or"], ["wind_embers", "Embers", 0.0, 0.0, 0.6, 0.5]],
	"thornhound": [["wind", "Leap", 120.0, 0.0, 0.45, 1.0]],
	"mongrel": [["wind_bite", "Bite", 75.0, 0.0, 0.6, 1.0], ["wind_quills", "Quills", 260.0, 0.0, 0.6, 0.6, "", "odd"]],
	"chimera": [["wind_maul", "Maul", 100.0, 0.0, 0.55, 1.0], ["wind_charge", "Goat charge", 210.0, 0.0, 0.8, 1.0, "or"],
		["wind_breath", "Breath", 210.0, 0.0, 0.8, 1.0, "or"], ["wind_spikes", "Tail spikes", 0.0, 0.0, 0.6, 0.5]],
}
## States that follow a wind-up (the blow itself on its way).
const STRIKING := ["pounce", "lunge", "swoop", "dive", "charge"]

## Every other word.
static var TEXT := {
	"ring_title": "TOOLS",
	"train_only": "between climbs",
	"no_tools": "No tools yet",
	"short": "Needs %s",
	"you_carry": "you carry %s",
	"paid": "-%s",
	"no_target": "Nothing to aim at",
	"resists": "A great foe: it won't answer",
	"no_pair": "No other monster near it",
	"calm": "Calm",
	"feud": "Set against each other",
	"off": "Trap off",
	"on": "Trap on",
	"door_open": "Door open",
	"door_shut": "Door shut",
	"door_blocked": "Something stands in the doorway",
	"locked": "Locked: the tool can't open it",
	"inspected": "%s: inspected",
	"panel_close": "%s again to close",
	"plan_title": "THE FLOOR'S PLAN",
	"spells_title": "YOUR SPELLS' REAL NUMBERS",
	"no_spells": "You carry no spells.",
	"secret_wall": "secret wall",
	"hidden": "hidden",
	"wing": "a sealed wing",
	"hidden_room": "a hidden room",
	"trap_timed": "%s  ·  every %ss: warns %ss, fires %ss",
	"trap_plate": "%s  ·  plate: warns %ss, fires %ss, rests %ss",
	"trap_next": "fires in %ss",
	"trap_off": "%s  ·  OFF",
	"door_to": "→ %s",
	"held": "held shut %ds",
	"next": "Next: %s",
	"next_or": "Next: %s or %s",
	"now": "Now: %s  ·  %ss",
	"striking": "Striking: %s",
	"calm_tag": "calm",
	"feud_tag": "fighting",
	"grow_line": "%s deepens to depth %d: %s",
	"depth": "%s  ·  depth %d",
	"need_feed": "%d of %d banked %s since the mark",
	"need_also": "and one of:",
	"capped": "Deeper tools come later",
	"full": "Every depth reached",
	"tune_title": "TUNE",
	"tune_none": "untuned",
	"tune_cost": "Each change costs %d crystal essence (yours: %d).",
	"tune_short": "Needs %d crystal essence (you hold %d)",
	"tune_only_train": "Tune spells between climbs, on the train.",
	"path_title": "CHANGE YOUR PATH",
	"path_line": "Resets your path: all its flow (%d banked) flows out of your shadow, and a new path starts from nothing at the next great foe. Costs %d crystal essence.",
	"path_none": "You have no path yet: the first great foe offers the choice.",
	"path_confirm": "{again} to let it go",
	"path_done": "Your %s flows out of your shadow",
	"path_only_train": "On the train, between climbs.",
	# --- depth 3 to 5 ---
	"leave": "Leave it",
	"leave_desc": "Nothing is paid.",
	"once_floor": "Once a floor: used",
	"once_climb": "Once a climb: used",
	"edit_title": "EDIT",
	"edit_line": "Points: %s  ·  budget: raise one only by lowering another (%d to %d each). Each point raised costs %d crystal essence (yours: %d).",
	"edit_none": "unedited",
	"edit_lower_first": "Lower another of its numbers first",
	"edit_most": "As far as it goes",
	"edit_least": "As low as it goes",
	"edit_short": "Needs %d crystal essence (you hold %d)",
	"edit_only_train": "Edit spells between climbs, on the train.",
	"edit_clear": "Clear",
	"splice_title": "SPLICE: WHICH SPELL?",
	"splice_title2": "SPLICE: WHOSE BEHAVIOUR?",
	"splice_need": "Splice needs two marks",
	"splice_line": "%s %s",
	"splice_tag": "spliced: %s",
	"splice_done": "%s now %s",
	"write_title": "WRITE: WHICH ESSENCE?",
	"write_title2": "WRITE: WHICH BOND?",
	"write_title3": "WRITE: WHICH SPELL?",
	"write_none": "No bond left to write from",
	"write_sub": "Cast at step %d, your best bond's.",
	"write_done": "Written: %s",
	"move_title": "MOVE YOUR MARKS",
	"move_line": "Write moves a mark to another body part (a marked part swaps). Each move costs %d crystal essence (yours: %d).",
	"move_short": "Needs %d crystal essence (you hold %d)",
	"move_only_train": "Move marks between climbs, on the train.",
	"move_done": "The %s mark moves to your %s",
	"des_edit_title": "EDIT THE TOWER",
	"retimed": "Re-timed",
	"moved": "Moved",
	"raised": "A wall rises",
	"sunk": "The wall sinks",
	"no_edit": "Nothing to edit here: aim at a trap or a wall",
	"no_move": "No open floor that way",
	"lane": "A slot in the wall: it can't move",
	"retime_none": "Not a timed trap room",
	"retimed_already": "Already re-timed",
	"would_block": "It would leave no way past by timing",
	"would_shut": "It would shut the way to the stair",
	"no_room_wall": "No room for a wall there",
	"reroll_title": "THE NEXT FLOOR: ITS PUZZLE",
	"reroll_title2": "THE NEXT FLOOR: ITS ROOMS",
	"reroll_far": "Go to the stair to reroll the next floor",
	"reroll_not": "The next floor can't be rerolled",
	"reroll_done": "The next floor: %s, %s",
	"build_title": "BUILD",
	"build_max": "As much as a floor allows",
	"build_here": "No open floor ahead",
	"built": "Built: %s",
	"build_trap_tag": "yours",
	"rift_title": "THE RIFT",
	"rift_done": "The floor tears open to the stair.",
	"rift_vault": "The rift tears through the vault. What it held is gone.",
	"rift_door": "The rift tears through a locked door. What lay behind it is gone.",
	"rift_secret": "The rift tears through a hidden room. What it held is gone.",
	"rift_traps": "Traps destroyed: %d.",
	"rift_nothing": "Nothing to tear: the way to the stair is open.",
	"not_here": "Not on this floor",
	"medit_title": "EDIT: %s",
	"medit_max": "Its budget is spent",
	"turn": "Turn into: %s",
	"turn_desc": "A weaker kind of its tower. Uses up its budget.",
	"bound": "Bound to this floor's test: it won't change",
	"key": "It carries a key: it won't change sides",
	"reroll_room_title": "REROLL THE ROOM: %s",
	"no_room": "Aim at a room you haven't entered, with monsters asleep in it",
	"pack": "Pack %s",
	"rerolled": "The room holds something else now",
	"mbuild_title": "BUILD: %s, AND ITS SECOND ATTACK",
	"mbuild_one": "One at a time: yours still stands",
	"mbuild_desc": "It fights for you this floor, and %s.",
	"yours": "yours",
	"mbuilt": "Rewritten: yours",
	"proving": "Not in the Proving",
	"bribe_title": "A BRIBE (the Maker of Marks)",
	"bribe_line": "An offering may stand in for the next depth's extra need. It may refuse (nothing is taken), and it remembers every bribe (%d offered).",
	"bribe_crystals": "Offer %d crystal essence",
	"bribe_gear": "Offer %s",
	"bribe_vessel": "Offer a full vessel (%s)",
	"bribe_vessel_none": "A full vessel (none in your stash)",
	"bribe_yes": "It accepts the offering: it counts for depth %d.",
	"bribe_no": "It refuses.",
	"bribe_done": "Accepted for depth %d.",
	"bribe_only_train": "On the train, between climbs.",
	"bribe_full": "Every depth reached: nothing to offer for.",
}


# --- who holds what (profile fields) ----------------------------------------

## The climber's secret bond ("" for none).
static func bond_of(prof) -> String:
	if prof == null:
		return ""
	var b = prof.get("core_mark")
	return b if b is String and BONDS.has(b) else ""


## Its depth (0 without a bond; at least 1 with one).
static func depth_of(prof) -> int:
	if bond_of(prof) == "":
		return 0
	return clampi(int(prof.get("core_depth")), 1, MAX_DEPTH)


static func has_bond(prof) -> bool:
	return bond_of(prof) != ""


## Gives the climber a secret bond at a depth (the dev tools; the Makers write
## the same two fields). A new bond starts its growth again.
static func grant(prof, bond: String, depth: int) -> void:
	if not BONDS.has(bond):
		return
	if bond_of(prof) != bond:
		prof.set("core_xp", {})
		prof.set("core_tune", {})
		prof.set("core_edit", {})
	prof.set("core_mark", bond)
	prof.set("core_depth", clampi(depth, 1, MAX_DEPTH))


## Takes the secret bond away (the dev tools).
static func clear(prof) -> void:
	prof.set("core_mark", "")
	prof.set("core_depth", 0)
	prof.set("core_xp", {})
	prof.set("core_tune", {})
	prof.set("core_edit", {})


static func color(bond: String) -> Color:
	return BONDS.get(bond, BONDS["developer"])["color"]


static func display(bond: String) -> String:
	return BONDS.get(bond, {}).get("name", "")


## The tools unlocked, in ring order (train tools included).
static func tools_for(prof) -> Array:
	var bond := bond_of(prof)
	if bond == "":
		return []
	var d := depth_of(prof)
	return RING[bond].filter(func(id): return int(TOOLS[id]["depth"]) <= d)


## The ring's entries: the unlocked tools (a train tool shows, greyed).
static func ring_tools(prof) -> Array:
	return tools_for(prof)


static func usable_in_climb(id: String) -> bool:
	return TOOLS.get(id, {}).get("where", "") == "ring"


static func has_tool(prof, id: String) -> bool:
	return id in tools_for(prof)


# --- costs ------------------------------------------------------------------

## What a tool will take from what you carry: {ok, flow (from the flow
## carried), essence (ordinary essence, the substitute included), short (what's
## missing, in words, or "")}. `run_essence` kind -> amount, `run_flow` the
## path's flow carried, `path` the climber's path.
static func quote(cost: Dictionary, run_essence: Dictionary, run_flow: float, path: String) -> Dictionary:
	var f_need := float(cost.get("flow", 0.0))
	var kind := String(cost.get("flow_kind", "any"))
	var e_need := float(cost.get("essence", 0.0))
	var flow_ok := path != "" and (kind == "any" or kind == path)
	var from_flow := minf(f_need, run_flow) if flow_ok else 0.0
	var essence := e_need + (f_need - from_flow) * SUBSTITUTE
	var carried := 0.0
	for k in run_essence:
		carried += float(run_essence[k])
	var ok := carried + 0.001 >= essence
	var short := ""
	if not ok:
		short = TEXT["short"] % ("%d more essence" % int(ceil(essence - carried)))
		if f_need > 0.0:
			var fk := Secret.display(path if kind == "any" and path != "" else kind) if kind != "any" or path != "" else "flow"
			short += " (or %d %s)" % [int(ceil(f_need - from_flow)), fk]
	return {"ok": ok, "flow": from_flow, "essence": essence, "short": short}


## Takes a quote's essence from `run_essence` (in proportion to each kind
## held). Returns the essence taken by kind.
static func take_essence(run_essence: Dictionary, amount: float) -> Dictionary:
	var total := 0.0
	for k in run_essence:
		total += float(run_essence[k])
	var taken := {}
	if amount <= 0.0 or total <= 0.0:
		return taken
	var share := minf(1.0, amount / total)
	for k in run_essence.keys():
		var t := float(run_essence[k]) * share
		run_essence[k] = float(run_essence[k]) - t
		taken[k] = t
		if float(run_essence[k]) <= 0.001:
			run_essence.erase(k)
	return taken


## A cost in words: "2 Unmaking + 1 essence" ("any" flow: your path's).
static func cost_text(cost: Dictionary, path: String) -> String:
	var bits: Array = []
	var f := float(cost.get("flow", 0.0))
	if f > 0.0:
		var kind := String(cost.get("flow_kind", "any"))
		var name := Secret.display(kind) if kind != "any" else (Secret.display(path) if path != "" else "flow")
		bits.append("%d %s" % [int(f), name])
	var e := float(cost.get("essence", 0.0))
	if e > 0.0:
		bits.append("%d essence" % int(e))
	var line := " + ".join(bits)
	if f > 0.0:
		line += "  (each %s you don't carry: %d essence)" % ["unit" if String(cost.get("flow_kind", "any")) == "any" else Secret.display(String(cost["flow_kind"])), int(SUBSTITUTE)]
	return line


## The gem colour of a cost's flow part (your path's for "any").
static func flow_color(cost: Dictionary, path: String) -> Color:
	var kind := String(cost.get("flow_kind", "any"))
	if kind == "any":
		kind = path if path != "" else "life"
	return Secret.color(kind)


## Crystal essence held in all (the train's costs are paid from crystals).
static func crystals_held(prof) -> float:
	var t := 0.0
	for c in prof.crystals:
		t += float(c["amount"])
	return t


## Pays `amount` crystal essence from any kinds, the largest stocks first.
## False (nothing taken) if too little is held.
static func spend_crystals(prof, amount: float) -> bool:
	amount = ceilf(amount)
	if crystals_held(prof) + 0.001 < amount:
		return false
	var kinds := {}
	for c in prof.crystals:
		kinds[c["kind"]] = true
	var order: Array = kinds.keys()
	order.sort_custom(func(a, b): return prof.crystal_total(a) > prof.crystal_total(b))
	var need := amount
	for k in order:
		if need <= 0.0:
			break
		var take := minf(need, prof.crystal_total(k))
		if take > 0.0 and prof.spend(k, take):
			need -= ceilf(take)
	return true


# --- growth -----------------------------------------------------------------

## What a stair banks feeds the secret bond (core_xp), and it deepens when
## it has enough (up to CAP). `essence` kind -> amount banked,
## `flow` the path's flow banked, `path` its kind. Returns lines for the banner.
static func on_bank(prof, essence: Dictionary, flow: float, path: String) -> Array:
	var bond := bond_of(prof)
	if bond == "":
		return []
	var xp: Dictionary = _xp(prof)
	var six := 0.0
	for k in essence:
		six += float(essence[k])
	xp["essence"] = float(xp.get("essence", 0.0)) + six
	if path != "" and flow > 0.0:
		xp[path] = float(xp.get(path, 0.0)) + flow
	prof.set("core_xp", xp)
	return grow(prof)


## Deepens the bond while every need of the next depth is met. Lines for a banner.
static func grow(prof) -> Array:
	var lines: Array = []
	var bond := bond_of(prof)
	while bond != "" and depth_of(prof) < CAP and needs_met(prof):
		var d := depth_of(prof) + 1
		prof.set("core_depth", d)
		var names: Array = RING[bond].filter(func(id): return int(TOOLS[id]["depth"]) == d).map(func(id): return TOOLS[id]["name"])
		lines.append(TEXT["grow_line"] % [display(bond), d, ", ".join(names)])
	return lines


static func _xp(prof) -> Dictionary:
	var xp = prof.get("core_xp")
	return xp if xp is Dictionary else {}


## Banked since the mark that counts toward the next depth.
static func fed(prof) -> float:
	var bond := bond_of(prof)
	if bond == "":
		return 0.0
	var xp := _xp(prof)
	var t := 0.0
	for k in GROWTH[bond]["feed"]:
		t += float(xp.get(k, 0.0))
	return t


## The banked amount the next depth needs (-1 at the deepest).
static func next_feed(prof) -> float:
	var bond := bond_of(prof)
	var d := depth_of(prof)
	if bond == "" or d >= MAX_DEPTH:
		return -1.0
	return float(GROWTH[bond]["need"][d + 1])


## The Developer's extra needs: id -> [met, words].
static func also_status(prof) -> Dictionary:
	var d := mini(depth_of(prof) + 1, MAX_DEPTH)
	var m: Dictionary = ALSO["mastery"]
	var full := 0
	for part in prof.bonds:
		if prof.step_for_xp(float(prof.bonds[part]["xp"])) >= int(m["step"]):
			full += 1
	var need_frag: int = ALSO["knowledge"][d]
	var frags := fragments(prof)
	return {
		"mastery": [full >= int(m["bonds"]), "Mastery: %d of your tower bonds at step %d (%d now)" % [int(m["bonds"]), int(m["step"]), full]],
		"knowledge": [frags >= need_frag, "Knowledge: %d of the Makers' traces found (%d now)" % [need_frag, frags]],
		"favour": [false, "A favour: a task done for a tower beast (not in the game yet)"],
		"bribe": [int(bribe_state(prof).get("for", 0)) == d, "A bribe: an offering the Maker of Marks accepts (on the train)"],
	}


## The Makers' traces found (makers.gd keeps them in profile.makers["fragments"]; 0 without).
static func fragments(prof) -> int:
	var mk = prof.get("makers")
	if mk is Dictionary and mk.get("fragments") is Array:
		return mk["fragments"].size()
	return 0


static func needs_met(prof) -> bool:
	var need := next_feed(prof)
	if need < 0.0 or fed(prof) + 0.001 < need:
		return false
	if GROWTH[bond_of(prof)]["also"]:
		return also_status(prof).values().any(func(v): return v[0])
	return true


## What the next depth needs, in lines (the climber screen).
static func next_lines(prof) -> Array:
	var bond := bond_of(prof)
	if bond == "":
		return []
	var d := depth_of(prof)
	if d >= MAX_DEPTH:
		return [TEXT["full"]]
	var feed_name: String = "essence of every kind" if bond == "developer" else String(BONDS[bond]["grows"])
	var out: Array = ["%s %d needs: %s" % ["Depth" if d < CAP else "Later, depth", d + 1, TEXT["need_feed"] % [int(fed(prof)), int(next_feed(prof)), feed_name]]]
	if GROWTH[bond]["also"]:
		out.append(TEXT["need_also"])
		for k in ["mastery", "knowledge", "favour", "bribe"]:
			var st: Array = also_status(prof)[k]
			out.append(("  [x] " if st[0] else "  [ ] ") + String(st[1]))
	if d >= CAP:
		out.append(TEXT["capped"])
	return out


# --- the Developer: spells' real numbers, and Tune ----------------------------

## A spell's real numbers on a bond (bond.gd), with every multiplier that
## applies (faint, density, gear, flow, Tune): [[label, value text], ...].
## `windup_mult` is the climber's own (Steady Mind).
static func spell_numbers(b, sp: Dictionary, windup_mult := 1.0) -> Array:
	var rows: Array = []
	rows.append(["Cost", "%s essence" % _num(b.spell_cost(sp))])
	rows.append(["Wind-up", "%s s" % _num(b.spell_windup(sp) * windup_mult)])
	var dmg = b.spell_stat(sp, "damage")
	if dmg != null and float(dmg) > 0.0:
		rows.append(["Damage", _num(b.spell_damage(sp))])
	for key in ["reach", "range", "radius", "length", "hop", "leaps", "duration", "shield", "splash", "stun", "lift", "arc"]:
		var v = b.spell_stat(sp, key)
		if v != null and (v is float or v is int) and float(v) > 0.0:
			var val := float(v)
			if key in ["duration", "shield", "splash"]:
				val *= b.spell_power(sp)
			rows.append([key.capitalize(), _num(val) + (" s" if key in ["duration", "stun", "lift"] else ("°" if key == "arc" else ""))])
	return rows


## What each step adds to a spell, from the step that teaches it: ["Step 2: damage 12", ...].
static func step_adds(sp: Dictionary) -> Array:
	var out: Array = []
	var steps: Dictionary = sp["steps"]
	var keys: Array = steps.keys()
	keys.sort()
	for s in keys:
		var bits: Array = []
		for k in steps[s]:
			var v = steps[s][k]
			if v is bool:
				if v:
					bits.append(String(k))
			elif v is float or v is int:
				bits.append("%s %s" % [String(k), _num(float(v))])
		out.append("Step %d: %s" % [int(s), ", ".join(bits)])
	return out


## The Tune multiplier for one of a spell's numbers ("power", "cost", "windup").
static func tune_mult(tunes: Dictionary, spell_id: String, key: String) -> float:
	var mode := String(tunes.get(spell_id, ""))
	if mode == "" or not TUNE.has(mode):
		return 1.0
	return float(TUNE[mode].get(key, 1.0))


## The Tune settings the climber's bonds use ({} unless the Developer at depth 2+).
static func active_tunes(prof) -> Dictionary:
	if bond_of(prof) != "developer" or depth_of(prof) < int(TOOLS["dev_tune"]["depth"]):
		return {}
	var t = prof.get("core_tune")
	return t if t is Dictionary else {}


## Sets a spell's Tune (paid from crystals; "" clears it for free). "" if done, else why not.
static func set_tune(prof, spell_id: String, mode: String) -> String:
	if bond_of(prof) != "developer" or depth_of(prof) < int(TOOLS["dev_tune"]["depth"]):
		return "Tune needs the Developer at depth 2"
	var tunes: Dictionary = active_tunes(prof).duplicate()
	if String(tunes.get(spell_id, "")) == mode:
		return ""
	if mode != "":
		if not TUNE.has(mode):
			return "No such setting"
		if not spend_crystals(prof, TUNE_COST):
			return TEXT["tune_short"] % [int(TUNE_COST), int(crystals_held(prof))]
		tunes[spell_id] = mode
	else:
		tunes.erase(spell_id)
	prof.set("core_tune", tunes)
	return ""


# --- the Developer: Edit (depth 3) ----------------------------------------------

## The Edit points the climber's bonds use ({} unless the Developer at depth 3+).
static func active_edits(prof) -> Dictionary:
	if bond_of(prof) != "developer" or depth_of(prof) < int(TOOLS["dev_edit"]["depth"]):
		return {}
	var e = prof.get("core_edit")
	return e if e is Dictionary else {}


## The aspect a spell's number belongs to ("" for none): "power", "windup",
## "cost", or a stat key such as "reach".
static func edit_aspect(key: String) -> String:
	for a in EDIT_ASPECTS:
		if key in EDIT_ASPECTS[a]["keys"]:
			return a
	return ""


## The Edit multiplier for one of a spell's numbers (1 when unedited).
static func edit_mult(edits: Dictionary, spell_id: String, key: String) -> float:
	if edits.is_empty() or not edits.has(spell_id):
		return 1.0
	var a := edit_aspect(key)
	if a == "":
		return 1.0
	var n := int(edits[spell_id].get(a, 0))
	if n == 0:
		return 1.0
	var sign := -1.0 if EDIT_ASPECTS[a].get("less", false) else 1.0
	return maxf(0.2, 1.0 + sign * EDIT_POINT * n)


## A spell's stat with its Edit applied (keeps whole numbers whole).
static func edit_stat(edits: Dictionary, spell_id: String, key: String, value):
	if not (value is float or value is int):
		return value
	var m := edit_mult(edits, spell_id, key)
	if m == 1.0:
		return value
	if value is int:
		return int(round(float(value) * m))
	return float(value) * m


## The aspects a spell can move points between (those it has numbers for).
static func edit_aspects_for(b, sp: Dictionary) -> Array:
	var out: Array = []
	for a in EDIT_ORDER:
		match a:
			"power":
				var d = b.spell_stat(sp, "damage")
				if (d != null and float(d) > 0.0) or b.spell_stat(sp, "shield") != null or b.spell_stat(sp, "duration") != null:
					out.append(a)
			"speed", "thrift":
				out.append(a)
			_:
				for k in EDIT_ASPECTS[a]["keys"]:
					var v = b.spell_stat(sp, k)
					if v != null and (v is float or v is int) and float(v) > 0.0:
						out.append(a)
						break
	return out


## A spell's points in words: "+2 Reach, -2 Power" ("" when unedited).
static func edit_text(points: Dictionary) -> String:
	var bits: Array = []
	for a in EDIT_ORDER:
		var n := int(points.get(a, 0))
		if n != 0:
			bits.append("%s%d %s" % ["+" if n > 0 else "", n, EDIT_ASPECTS[a]["name"]])
	return ", ".join(bits)


## Moves one point of a spell's aspect up (+1, paid in crystals) or down (-1,
## free). "" if done, else why not.
static func set_edit(prof, spell_id: String, aspect: String, delta: int) -> String:
	if bond_of(prof) != "developer" or depth_of(prof) < int(TOOLS["dev_edit"]["depth"]):
		return "Edit needs the Developer at depth 3"
	if not EDIT_ASPECTS.has(aspect) or delta == 0:
		return "No such number"
	var all: Dictionary = active_edits(prof).duplicate(true)
	var pts: Dictionary = all.get(spell_id, {}).duplicate()
	var n := int(pts.get(aspect, 0)) + signi(delta)
	if n > EDIT_MAX:
		return TEXT["edit_most"]
	if n < -EDIT_MAX:
		return TEXT["edit_least"]
	if delta > 0:
		var sum := 0
		for a in pts:
			sum += int(pts[a])
		if sum + 1 > 0:
			return TEXT["edit_lower_first"]
		if not spend_crystals(prof, EDIT_COST):
			return TEXT["edit_short"] % [int(EDIT_COST), int(crystals_held(prof))]
	if n == 0:
		pts.erase(aspect)
	else:
		pts[aspect] = n
	if pts.is_empty():
		all.erase(spell_id)
	else:
		all[spell_id] = pts
	prof.set("core_edit", all)
	return ""


## Clears a spell's edit (free).
static func clear_edit(prof, spell_id: String) -> void:
	var all: Dictionary = active_edits(prof).duplicate(true)
	all.erase(spell_id)
	prof.set("core_edit", all)


# --- the Developer: Splice (4) and Write (5) -----------------------------------

## The behaviour a bond lends a spliced spell.
static func splice_effect(bond_id: String) -> String:
	return String(SPLICE_FROM.get(bond_id, "knock"))


## The bonds the Developer could Write from, by essence kind: {kind: [bond ids]}
## (bonds the climber doesn't hold, with a spell Write can cast at `step`).
static func write_bonds(held: Array, step: int, bonds_data: Dictionary) -> Dictionary:
	var out := {}
	for id in bonds_data:
		if id in held:
			continue
		if write_spells(bonds_data[id], step).is_empty():
			continue
		var kind := String(bonds_data[id].get("affinity", ""))
		if not out.has(kind):
			out[kind] = []
		out[kind].append(id)
	return out


## A bond's spells that Write can cast at `step` (learned by then, not a form or a pact spell).
static func write_spells(bond_data: Dictionary, step: int) -> Array:
	return bond_data["spells"].filter(func(sp): return int(sp["learn"]) <= step and not String(sp["type"]) in WRITE_SKIP)


## Moves a mark from one body part to another on the train (a marked part
## swaps), paid in crystals. "" if done, else why not.
static func move_mark(prof, from: String, to: String) -> String:
	if bond_of(prof) != "developer" or depth_of(prof) < int(TOOLS["dev_write"]["depth"]):
		return "Moving marks needs the Developer at depth 5"
	if from == to or not prof.bonds.has(from):
		return "No mark there"
	if not spend_crystals(prof, MARK_MOVE_COST):
		return TEXT["move_short"] % [int(MARK_MOVE_COST), int(crystals_held(prof))]
	var a: Dictionary = prof.bonds[from]
	if prof.bonds.has(to):
		prof.bonds[from] = prof.bonds[to]
	else:
		prof.bonds.erase(from)
	prof.bonds[to] = a
	return ""


# --- the Developer's bribe ---------------------------------------------------

## The Maker of Marks' memory of bribes, in the Makers' saved state:
## {offered, refused, accepted, for (the depth an accepted bribe counts for)}.
static func bribe_state(prof) -> Dictionary:
	if prof == null:
		return {}
	var mk = prof.get("makers")
	if not (mk is Dictionary):
		return {}
	var b = mk.get("bribe")
	return b if b is Dictionary else {}


## What the climber could offer: [{id, text, ok}] ("crystals", "gear:<i>"
## for a Regarded piece in the chest, "pack:<i>" in the pack, "vessel:<i>"
## a full vessel in the chest; "vessel" greyed when there's none).
static func bribe_offers(prof, gear_script) -> Array:
	var out: Array = []
	var need := float(BRIBE["crystals"])
	out.append({"id": "crystals", "text": TEXT["bribe_crystals"] % int(need), "ok": crystals_held(prof) + 0.001 >= need})
	for where in ["chest", "pack"]:
		var list: Array = prof.get(where)
		for i in list.size():
			var g = list[i]
			if gear_script.is_gear(g) and gear_script.rarity(g) == "regarded":
				out.append({"id": "%s:%d" % [where, i], "text": TEXT["bribe_gear"] % gear_script.display(g), "ok": true})
	var V = load("res://scripts/vessel.gd")
	var full: Array = V.full_list(prof)
	for i in full:
		out.append({"id": "vessel:%d" % i, "text": TEXT["bribe_vessel"] % V.state_text(prof.vessels[i]), "ok": true})
	if full.is_empty():
		out.append({"id": "vessel", "text": TEXT["bribe_vessel_none"], "ok": false})
	return out


## The chance the Maker of Marks takes a bribe now (`vessel`: a full vessel offered).
static func bribe_odds(prof, vessel := false) -> float:
	var st := bribe_state(prof)
	var odds := maxf(float(BRIBE["least"]), float(BRIBE["agree"]) - float(BRIBE["each"]) * int(st.get("offered", 0)))
	return minf(odds + float(BRIBE["vessel"]), maxf(odds, float(BRIBE["vessel_most"]))) if vessel else odds


## Offers a bribe for the next depth: {ok (accepted), said}. Refused: nothing
## is taken, but it's remembered. `roll` in 0..1 (randf by default).
static func offer_bribe(prof, offer_id: String, gear_script, roll := -1.0) -> Dictionary:
	var d := depth_of(prof)
	if bond_of(prof) != "developer":
		return {"ok": false, "said": ""}
	if d >= MAX_DEPTH:
		return {"ok": false, "said": TEXT["bribe_full"]}
	var st := bribe_state(prof).duplicate()
	if int(st.get("for", 0)) == d + 1:
		return {"ok": false, "said": TEXT["bribe_done"] % (d + 1)}
	var offer := {}
	for o in bribe_offers(prof, gear_script):
		if o["id"] == offer_id:
			offer = o
	if offer.is_empty() or not offer["ok"]:
		return {"ok": false, "said": "Nothing to offer"}
	var agree := bribe_odds(prof, offer_id.begins_with("vessel:"))
	if roll < 0.0:
		roll = randf()
	var yes := roll < agree
	if bribe_force >= 0:
		yes = bribe_force == 1
	st["offered"] = int(st.get("offered", 0)) + 1
	if yes:
		if offer_id == "crystals":
			spend_crystals(prof, float(BRIBE["crystals"]))
		elif offer_id.begins_with("vessel:"):
			load("res://scripts/vessel.gd").use_full(prof, int(offer_id.get_slice(":", 1)))
		else:
			var where := offer_id.get_slice(":", 0)
			var list: Array = prof.get(where)
			list.remove_at(int(offer_id.get_slice(":", 1)))
		st["accepted"] = int(st.get("accepted", 0)) + 1
		st["for"] = d + 1
	else:
		st["refused"] = int(st.get("refused", 0)) + 1
	var mk = prof.get("makers")
	if not (mk is Dictionary):
		mk = {}
	mk["bribe"] = st
	prof.set("makers", mk)
	return {"ok": yes, "said": TEXT["bribe_yes"] % (d + 1) if yes else TEXT["bribe_no"]}


# --- the Designer: the next floor's lean ------------------------------------------

## Two different ids from a list (fewer if it's short).
static func two_of(list: Array) -> Array:
	var l := list.duplicate()
	l.shuffle()
	return l.slice(0, 2)


static func _num(f: float) -> String:
	if absf(f - roundf(f)) < 0.001:
		return "%d" % int(roundf(f))
	return ("%.2f" % f).rstrip("0").rstrip(".")


# --- the Designer: the floor's plan -------------------------------------------

## The kind of room a theme makes (never what it holds).
static func room_kind(theme_id: String) -> String:
	var th: Dictionary = Themes.get_theme(theme_id)
	var f := String(th.get("feature", ""))
	if ROOM_KIND.has(f):
		return ROOM_KIND[f]
	return ROOM_KIND_BY.get(String(th.get("kind", "")), "a room")


## A trap's timing as a readout line.
static func trap_line(tr: Dictionary, traps_script) -> String:
	var k: Dictionary = traps_script.KINDS[tr["kind"]]
	var name := String(k["name"]).capitalize()
	if tr.get("off", false):
		return TEXT["trap_off"] % name
	if String(tr.get("trigger", k["trigger"])) == "timed":
		return TEXT["trap_timed"] % [name, _num(traps_script.val(tr, "cycle")), _num(traps_script.val(tr, "warn")), _num(snappedf(traps_script.val(tr, "fire"), 0.01))]
	return TEXT["trap_plate"] % [name, _num(traps_script.val(tr, "warn")), _num(snappedf(traps_script.val(tr, "fire"), 0.01)), _num(traps_script.val(tr, "rest"))]


## Everything the Designer's Inspect shows on a floor, as entries
## {type: "room"/"door"/"trap"/"secret"/"wing"/"stair", pos, text, ...}.
## Never a reward: a good room is "a good room", a hidden one "a hidden room".
static func plan_entries(main) -> Array:
	var out: Array = []
	var infos: Array = main.room_info
	for i in infos.size():
		var th: String = main.room_themes[i] if i < main.room_themes.size() else "quiet"
		out.append({"type": "room", "pos": infos[i]["rect"].get_center(), "rect": infos[i]["rect"], "text": room_kind(th), "index": i})
	if main.door_view != null:
		for d in main.door_view.list:
			var kind := ""
			if String(d.get("fixed", "")) == "sealed":
				kind = TEXT["wing"]
			elif int(d["room"]) >= 0 and int(d["room"]) < main.room_themes.size():
				kind = room_kind(main.room_themes[int(d["room"])])
			else:
				kind = "a room"
			out.append({"type": "door", "pos": d["rect"].get_center(), "rect": d["rect"], "text": TEXT["door_to"] % kind,
				"locked": String(d["lock"]) != "", "open": bool(d["open"]), "door": d})
	for tr in main.traps:
		out.append({"type": "trap", "pos": tr["pos"], "text": trap_line(tr, main.Traps), "hidden": bool(tr.get("hidden", false)), "trap": tr})
	if main.wings != null:
		for s in main.wings.secrets:
			out.append({"type": "secret", "pos": main.wings._tile_center(s["mouth"][0]), "text": TEXT["secret_wall"], "rect": s["rect"],
				"open": bool(s["open"]), "room_text": TEXT["hidden_room"]})
		for w in main.wings.wings:
			out.append({"type": "wing", "pos": w["rect"].get_center(), "rect": w["rect"], "text": TEXT["wing"]})
	if main.layout_on:
		out.append({"type": "stair", "pos": main.stair_pos, "text": "the stair"})
	return out


# --- the Manipulator: monsters --------------------------------------------------

## Which kind of great foe a monster is ("" for an ordinary one).
static func resists(e) -> bool:
	return Secret.great_foe(e) in RESIST


## The monster's next attack: {name, state, wind, now (winding up or striking),
## left (seconds of wind-up left), or (the other it may pick)}.
static func predict(e, dist: float) -> Dictionary:
	var rules: Array = ATTACKS.get(e.kind, [])
	if rules.is_empty():
		return {}
	var st: String = e.state
	for r in rules:
		if r[0] == st:
			return {"name": r[1], "state": r[0], "wind": r[4], "now": true, "left": maxf(0.0, float(e.state_t)), "dmg": float(r[5]) * e.dmg}
	if st in STRIKING:
		return {"name": rules[0][1] if rules.size() == 1 else st.capitalize(), "state": st, "now": true, "striking": true, "left": 0.0, "dmg": e.dmg}
	for i in rules.size():
		var r: Array = rules[i]
		if float(r[2]) > 0.0 and dist >= float(r[2]):
			continue
		if dist <= float(r[3]):
			continue
		if r.size() > 7 and r[7] == "odd" and int(e.turn) % 2 == 0:
			continue
		var out := {"name": r[1], "state": r[0], "wind": r[4], "now": false, "dmg": float(r[5]) * e.dmg}
		if r.size() > 6 and r[6] == "or" and i + 1 < rules.size():
			out["or"] = rules[i + 1][1]
		return out
	var r0: Array = rules[0]
	return {"name": r0[1], "state": r0[0], "wind": r0[4], "now": false, "dmg": float(r0[5]) * e.dmg}


## The readout over an inspected monster: a few short lines.
static func monster_lines(e, dist: float, floor_num: int, tower: String) -> Array:
	var lines: Array = []
	lines.append("%s  %d/%d" % [String(e.kind).capitalize(), int(ceil(e.hp)), int(ceil(e.max_hp))])
	lines.append("dmg %s  ·  speed %d" % [_num(snappedf(e.dmg, 0.1)), int(e.speed)])
	var d: Array = Essence.drop_for(e.kind, floor_num)
	var ess := "%d %s" % [int(round(float(d[1]))), Essence.display(d[0])]
	var sec: Dictionary = Secret.drop(Secret.great_foe(e), tower, floor_num)
	for k in sec:
		ess += ", %d %s" % [int(round(float(sec[k]))), Secret.display(k)]
	lines.append("carries " + ess)
	var nx := predict(e, dist)
	if not nx.is_empty():
		if nx.get("striking", false):
			lines.append(TEXT["striking"] % nx["name"])
		elif nx["now"]:
			lines.append(TEXT["now"] % [nx["name"], _num(snappedf(nx["left"], 0.1))])
		elif nx.has("or"):
			lines.append(TEXT["next_or"] % [nx["name"], nx["or"]])
		else:
			lines.append(TEXT["next"] % nx["name"])
	return lines
