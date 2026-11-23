extends Node2D
## RIVAL CLIMBERS: other climbers met in the towers. Each is a climber with
## their own marks (one to three bonds from bonds.gd, at steps that suit the
## floor), their own look (appearance.gd, dressed in their gear as the
## climber is: gear_look.gd) and a name from NAMES. They never get a story:
## a name and their marks, nothing more (the owner's to write, if ever).
##
## WHERE: from floor RULES "from", each floor of rooms rolls RULES "chance"
## until RULES "per_climb" have been met this climb (never on the bondless
## first climb, the Proving's floor or the summit). A climber who has never
## met one (the first climb after the Regard, or an older save that never
## did) is sure to by floor RULES "sure_by" (climb_owed). A second one in a
## climb is someone else, at a different meeting where one is left (the
## owner: "rival climbers weren't encountered, so I think more often would
## give the towers more life and variety"). floors.gd fixes a calm
## room for them (themes.gd "rival": no monsters, no piece of the task, no
## traps) and asks wants_room; plan["rivals"] holds {pos, room}. main.gd
## sets each floor up through setup().
##
## THE FOUR MEETINGS (one per encounter, by MEETINGS' weights; walk up to
## them and a short exchange opens on the game's card screen, main.gd
## offer_vault, stage "rival"; "Walk on" always leaves, and you can come back):
##   trade   two or three swaps: a piece of their gear, an item or crystals,
##           each for something you carry of about the same worth (the
##           store's own prices: train.gd gear_price, item_price)
##   duel    a duel for the floor, the room's doors shut (doors.gd lock-in).
##           Win (they yield at RULES "duel_yield" of their health): crystals,
##           sometimes a piece of their gear, renown, and the stair's ward
##           lifts (or a bonus if it already has). Lose: you're knocked down,
##           never killed (main.gd proving_spare asks spare()), left at
##           RULES "duel_left" of your health, and they take a toll: a share
##           of your unbanked essence, or a piece from your pack
##   team    they fight beside you until the stair (an ally: rival.gd). While
##           they do, you keep RULES "team_share" of the essence you gather
##           and finds drop RULES "team_drops" as often (main.gd asks share()
##           and drop_mult()). Their spells leave their bond's state
##           (BOND_STATE) through reactions.gd, so their marks react with
##           yours ("with <name>" under the reaction's word), and a synergy one
##           of whose marks is theirs holds while they're with you (synergies.gd)
##   rescue  (from MEETINGS "rescue" "from") a wounded climber beside a
##           hoard. Help them (a Healing Vial, or some of your health):
##           renown, and they owe you (met again, they bring a gift). Take
##           the hoard: essence and a finer piece, but renown lost (never a
##           rank) and the Makers notice (makers.gd "greed"); they remember
## A met rival is kept with the climber (profile.gd `rivals`; an old save
## has none) and listed on the Renown Board with their marks and your
## history. Met again (RULES "return_chance") they are stronger.
## Every word and number is here (the Data editor: "Rival climbers").

const Bonds := preload("res://scripts/bonds.gd")
const Items := preload("res://scripts/items.gd")
const Gear := preload("res://scripts/gear.gd")
const GearLook := preload("res://scripts/gear_look.gd")
const Appearance := preload("res://scripts/appearance.gd")
const Essence := preload("res://scripts/essence.gd")
const Renown := preload("res://scripts/renown.gd")
const Towers := preload("res://scripts/towers.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")
const UI := preload("res://scripts/ui.gd")
const MirrorScript := preload("res://scripts/mirror.gd")
const BODY := "res://scripts/rival.gd"

## The numbers.
##   chance / from / per_climb   how often a floor holds one, from which
##                               floor, and at most how many a climb
##   sure_by                     a climber who has never met one meets one
##                               by this floor (the next floor that can
##                               hold one, if a floor has no room for them)
##   return_chance               a met rival comes back (stronger: each mark
##                               return_steps higher, maybe a new mark: grow_mark)
##   second_from, second, third_from, third   how many marks: a second from
##                               that floor at that chance, a third likewise
##   step_floors, step_spread    their best mark's step: 1 + floor / step_floors,
##                               plus up to step_spread more
##   reach                       how near you walk to them to talk
##   hp, hp_per_step             their health (times the floor's toughness)
##   armor                       how much their armour takes off your blows
##   pair_bias                   one who offers to team up often carries a
##                               mark whose state reacts with one of yours
##   state_seconds               how long their spells' states last on a foe
##   duel_*                      a duel: when they yield, your health after a
##                               loss, the toll (share of unbanked essence, at
##                               least toll_min or a pack piece instead), the
##                               win's crystals, renown and gear chance, whether
##                               a win lifts the stair's ward (1) and the bonus
##                               (times the crystals) when there's no ward;
##                               duel_time: after this long it's called off
##   team_*                      teaming up: your share of essence, how often
##                               finds drop, renown at the stair; ally_taken
##                               (their share of a blow), ally_leave (they fall
##                               back at this share of their health)
##   rescue_cost, rescue_renown  helping without a draught costs this share of
##                               your health; renown for helping
##   gift_crystals               what an owed rival's gift holds (and an item)
##   greed_*                     the hoard: essence (base, per floor), a piece
##                               greed_row rarity rows finer, renown lost
##   trade_offers, fair_low, fair_high   swaps offered; a swap's two sides are
##                               within these shares of each other's worth
##   trade_crystals, trade_per_floor     crystals they offer in a swap
##   kept                        how many met rivals the climber remembers
static var RULES := {
	"wild_chance": 0.5,  # in a wild tower, a met climber (trading, teaming up, thanking you) speaks of it (wild_towers.gd)
	"rumour_chance": 0.5,  # a met climber (trading, teaming up, thanking you) passes on a rumour of the guardians, once any has fallen
	"entity_chance": 0.06, "rhyme_chance": 0.06,  # rarely, in passing (when no rumour is): their own Entity, or a line of the counting rhyme
	"chance": 0.45, "from": 2, "per_climb": 2, "sure_by": 3, "return_chance": 0.35, "return_steps": 1, "grow_mark": 0.3,
	"second_from": 4, "second": 0.5, "third_from": 8, "third": 0.4, "step_floors": 4.0, "step_spread": 1,
	"reach": 34.0, "hp": 110.0, "hp_per_step": 10.0, "armor": 0.2, "pair_bias": 0.75, "state_seconds": 4.0,
	"duel_yield": 0.12, "duel_left": 0.2, "duel_toll": 0.25, "duel_toll_min": 5.0, "duel_crystals": 10.0, "duel_per_floor": 2.0,
	"duel_renown": 6, "duel_gear": 0.5, "duel_ward": 1, "duel_bonus": 1.5, "duel_time": 120.0,
	"team_share": 0.5, "team_drops": 0.5, "team_renown": 3, "ally_taken": 0.6, "ally_leave": 0.2,
	"rescue_cost": 0.25, "rescue_renown": 8, "gift_crystals": 15.0,
	"greed_essence": 18.0, "greed_per_floor": 4.0, "greed_row": 1, "greed_renown": 5,
	"trade_offers": 3, "fair_low": 0.6, "fair_high": 1.6, "trade_crystals": 12.0, "trade_per_floor": 1.5,
	"kept": 24,
}
## The meetings: how likely each is ("weight") and its first floor ("from").
## A returning rival you robbed always wants a duel; one you helped brings a
## gift ("gift", not rolled).
static var MEETINGS := {
	"trade": {"weight": 3.0, "from": 2},
	"duel": {"weight": 2.0, "from": 2},
	"team": {"weight": 2.0, "from": 2},
	"rescue": {"weight": 2.0, "from": 3},
}
## The state each bond's spell leaves on a foe (reactions.gd STATES; "slam"
## is a moment). The climber's own marks are read the same way to find a
## rival whose mark answers yours (pair_bias).
static var BOND_STATE := {
	"stormcaller": "charged", "windwalker": "airborne", "hunter": "slowed",
	"tidecaller": "soaked", "warden": "slowed", "deepcaller": "soaked",
	"blade_forger": "bleeding", "flameblade": "burning", "rune_artist": "burning",
	"sandshaper": "slam", "venomist": "poisoned", "ashwalker": "unseen",
	"flame_contractor": "burning", "flamewing": "burning", "rekindler": "burning",
	"covenant": "bleeding", "grafter": "poisoned", "surgeon": "bleeding",
}
## The weapons they carry (melee: they fight close, as an ally and in a duel).
static var WEAPONS := ["sword", "axe", "mace", "spear", "dagger", "greatsword", "war_hammer"]
## Their armour by floor: [the floor from which, the armours that may show].
static var ARMORS := [[2, ["", "padded", "leather"]], [5, ["leather", "chain", "padded"]], [9, ["chain", "plate", "leather"]]]
## Their names (the owner may rename or add to them).
static var NAMES := ["Aldo", "Bryn", "Cass", "Dara", "Edrin", "Fenna", "Garrow", "Hale", "Ines", "Jory", "Kesh", "Lio",
	"Mara", "Nell", "Orrin", "Pell", "Quill", "Rhea", "Sorrel", "Tamsin", "Ulla", "Vesk", "Wren", "Yara",
	"Zeph", "Brannoc", "Corra", "Dell", "Eska", "Ilse", "Kerr", "Merrit", "Noor", "Osk", "Tibb", "Rook"]
## What they say (short; one is picked). In quotes when spoken.
static var LINES := {
	"trade": ["\"Got anything worth a swap?\"", "\"Trade? I've carried this far enough.\"", "\"Fair swaps only. Have a look.\""],
	"duel": ["\"This floor's mine. Unless you take it.\"", "\"First to yield gives up the floor.\"", "\"Let's settle who climbs on.\""],
	"team": ["\"Two blades to the stair beat one.\"", "\"Climb with me to the stair? We split what falls.\"", "\"Watch my back, I'll watch yours.\""],
	"rescue": ["Hurt, slumped against a hoard they can't carry.", "Wounded, and sitting on more than they can carry."],
	"gift": ["\"You helped me once. Here.\"", "\"I owe you. Take this.\""],
	"again": ["\"You again.\"", "\"Still climbing, then.\""],
	"robbed": ["\"I remember you. And my hoard.\""],
	# Rarely, in passing (RULES entity_chance): their own Entity. Nobody knows
	# if there is one Entity or many.
	"entity": ["\"Mine went quiet just before you showed up.\"", "\"Yours tell you about the Makers too?\"", "\"Mine never stops talking on the stairs. Yours?\"",
		"\"Do you think they're all the same one? The Entities, I mean. Mine won't say.\"", "\"Mine says I climb too fast. Don't tell it I told you.\"", "\"Mine laughed when it saw you. It doesn't laugh much.\""],
	# Now and then (RULES rhyme_chance): a line of the children's counting
	# rhyme ({rhyme}: dining.gd RHYME).
	"rhyme": ["\"My little brother sang it all the way to the station: '{rhyme}'\"", "\"Every child in the cities knows it: '{rhyme}'\""],
}
## Words.
static var TEXT := {
	"title": "%s",
	"marks": "Marks: %s",
	"mark": "%s (%s %d)",
	"no_marks": "No marks",
	"walk_name": "Walk on",
	"walk_desc": "Leave them be. You can come back.",
	"duel_name": "Duel for the floor",
	"duel_desc": "First to yield. Win: crystals, renown and the stair's ward lifts. Lose: knocked down, never killed, and they take a toll.",
	"team_name": "Team up",
	"team_desc": "They fight beside you to the stair. Essence and finds are shared: you keep half.",
	"trade_name": "Their %s",
	"trade_desc": "For your %s",
	"trade_what": "%s.  Theirs: %s",
	"trade_crystal": "%d %s crystal",
	"trade_essence": "%d unbanked essence",
	"trade_short": "You don't carry that",
	"help_name": "Help them",
	"help_draught": "Give them a Healing Vial. They'll remember.",
	"help_blood": "Bind their wounds: it costs you %d health. They'll remember.",
	"greed_name": "Take the hoard",
	"greed_desc": "Essence and a finer piece of gear. They'll remember. So will others.",
	"gift_name": "Their thanks",
	"gift_desc": "%d %s crystal and a %s",
	"met": "Met %s, a climber",
	"met_again": "Met %s again",
	"duel_title": "A DUEL",
	"duel_line": "%s: the first to yield gives up the floor",
	"duel_won_title": "THEY YIELD",
	"duel_won": "%s yields the floor",
	"duel_bonus": "No ward to lift: a bigger prize",
	"duel_lost_title": "KNOCKED DOWN",
	"duel_lost": "%s takes %s and leaves you standing",
	"duel_off": "%s calls the duel off",
	"toll_essence": "%d unbanked essence",
	"toll_piece": "your %s",
	"toll_none": "nothing",
	"team_title": "TEAMED UP",
	"team_line": "%s fights beside you to the stair. You keep half of what you gather.",
	"team_end": "%s heads on alone at the stair",
	"team_spent": "%s falls back, hurt",
	"rescued_title": "HELPED UP",
	"rescued": "%s is back on their feet. \"I won't forget this.\"",
	"greed_title": "THE HOARD",
	"greed": "You leave %s where they lie",
	"greed_noticed": "The Makers took note",
	"gift_taken": "A gift from %s",
	"traded": "Traded with %s: %s",
	"shared_synergy": "Shared synergy: %s, with %s",
	"chip_duel": "Duel: %s",
	"chip_team": "%s beside you",
	"deed_duel": "Won a duel with %s",
	"deed_rescue": "Helped %s back to their feet",
	"deed_team": "Climbed to a stair with %s",
	"deed_greed": "Took a wounded climber's hoard (%d renown)",
	# The Renown Board.
	"board": "Climbers met",
	"board_none": "No other climbers yet. Some climb the same towers.",
	"board_line": "%s  ·  %s",
	"history_met": "Met %d %s",
	"history_duels": "duels won %d, lost %d",
	"history_teamed": "teamed up %d",
	"history_rescued": "helped %d",
	"history_robbed": "robbed %d",
	"history_traded": "traded %d",
	"history_shared": "reactions together %d",
	"last": "Last met in %s, floor %d",
	"owed": "They owe you a favour.",
	"grudge": "They hold a grudge.",
	"time": "time",
	"times": "times",
}

## The encounters this climb has had (main.gd counts each as a floor sets
## it up); false on the bondless first climb; true while the climber has
## never met one (main.gd, as a climb starts: RULES "sure_by"); who and
## which meetings this climb has had ({climb, names, kinds}: a second rival
## is someone else, at another meeting); the dev tool's and tests'
## switches: the next floor of rooms holds one, and which meeting.
static var climb_met := 0
static var climb_ok := true
static var climb_owed := false
static var climb_seen := {}
static var force := false
## Test runs leave rivals out of floors unless a test asks for them
## (tests/parts/rivals.gd sets this): a climber who has never met one is
## owed one by floor 3, which would otherwise put a rival's room into the
## floors that other checks build and read.
static var in_tests := false
static var force_kind := ""
## Tests: a met rival always returns (1), never (0), or as RULES says (-1).
static var force_return := -1

var main
var list: Array = []  # this floor's encounters: {pos, room, kind, rival, state, face, offers, fade, hoard...}
var duel = null  # the rival's body in a duel
var duel_enc := {}
var duel_t := 0.0
var team = null  # the rival's body fighting beside you
var team_enc := {}
var team_floor := 0  # the floor you teamed up on (a stair above it, or a camp, ends it with renown)
var redraw_t := 0.0
var results: Array = []  # what happened this floor (tests): "duel_won", "duel_lost", "rescued"...


func _ready() -> void:
	z_index = -1


# --- where they appear (floors.gd) ---------------------------------------------------

## Whether a floor of rooms holds a rival (rolled once a plan).
static func wants_room(floor_num: int) -> bool:
	if floor_num < 2 or floor_num == int(Towers.PROVING["floor"]) or floor_num >= int(Towers.SUMMIT):
		return false
	if force:
		return true
	if Engine.has_meta("sixfold_test") and not in_tests:
		return false
	if not climb_ok or floor_num < int(RULES["from"]) or climb_met >= int(RULES["per_climb"]):
		return false
	return sure(floor_num) or randf() < float(RULES["chance"])


## True when this floor must hold one: the climber has never met a rival,
## none has been met this climb, and it's floor RULES "sure_by" or later.
static func sure(floor_num: int) -> bool:
	return climb_ok and climb_owed and climb_met == 0 and floor_num >= maxi(int(RULES["sure_by"]), int(RULES["from"])) \
		and floor_num != int(Towers.PROVING["floor"]) and floor_num < int(Towers.SUMMIT)


## A new climb (main.gd, floor 1): none met yet; `prof` (the climber) is
## owed a meeting if they have never met one.
static func new_climb(prof, first_climb: bool) -> void:
	climb_met = 0
	climb_seen = {}
	climb_ok = not first_climb
	climb_owed = not first_climb and met_list(prof).is_empty()


# --- the climber's record of them (profile.gd `rivals`) -------------------------------

## Every rival this climber has met: id -> record (an old save: none).
static func state(prof) -> Dictionary:
	if prof == null:
		return {}
	var r = prof.get("rivals")
	if not (r is Dictionary):
		prof.set("rivals", {})
		r = prof.get("rivals")
	return r


## The met rivals, the most recently met first.
static func met_list(prof) -> Array:
	var out: Array = state(prof).values().filter(func(r): return r is Dictionary and r.has("name"))
	out.sort_custom(func(a, b): return int(a.get("seen", 0)) > int(b.get("seen", 0)))
	return out


## A count over every met rival ("duels_won", "rescued", "teamed"...).
static func count(prof, key: String) -> int:
	var n := 0
	for r in state(prof).values():
		if r is Dictionary:
			n += int(r.get(key, 0))
	return n


## "Stormcaller (Hand 2), Tidecaller (Brow 1)".
static func marks_text(rec: Dictionary) -> String:
	var bits: Array = []
	for b in rec.get("bonds", []):
		var id := String(b[0])
		bits.append(TEXT["mark"] % [String(Bonds.BONDS.get(id, {}).get("name", id)), String(Bonds.PART_NAMES.get(String(b[1]), String(b[1]))), int(b[2])])
	return ", ".join(bits) if not bits.is_empty() else String(TEXT["no_marks"])


## Your history with them, in a line.
static func history_text(rec: Dictionary) -> String:
	var n := int(rec.get("met", 0))
	var bits: Array = [TEXT["history_met"] % [n, TEXT["time"] if n == 1 else TEXT["times"]]]
	if int(rec.get("duels_won", 0)) + int(rec.get("duels_lost", 0)) > 0:
		bits.append(TEXT["history_duels"] % [int(rec.get("duels_won", 0)), int(rec.get("duels_lost", 0))])
	for k in ["teamed", "rescued", "robbed", "traded", "shared"]:
		if int(rec.get(k, 0)) > 0:
			bits.append(TEXT["history_" + k] % int(rec.get(k, 0)))
	return ",  ".join(bits)


static func bond_color(id: String) -> Color:
	return Bonds.BONDS.get(id, {}).get("color", Color(0.85, 0.8, 0.7))


## The colour they show in (their strongest mark's).
static func color_of(rec: Dictionary) -> Color:
	var bl: Array = rec.get("bonds", [])
	return bond_color(String(bl[0][0])) if not bl.is_empty() else Color(0.9, 0.82, 0.65)


## The gear they wear: slot -> record.
static func gear_of(rec: Dictionary) -> Dictionary:
	var g := {}
	for c in rec.get("gear", []):
		var r := Gear.rec(c)
		if not r.is_empty():
			g[Gear.slot_of(r)] = r
	return g


## Their look: their appearance, dressed in their gear as the climber is (gear_look.gd).
static func look_of(rec: Dictionary) -> Dictionary:
	var lk := Appearance.look(rec.get("app", Appearance.DEFAULTS))
	lk["hood"] = lk["cloak"].darkened(0.22)
	lk["head"] = Appearance.head_kind(lk)
	var gear := gear_of(rec)
	GearLook.before_armor(lk, gear)
	GearLook.armor_look(lk, gear)
	GearLook.after_armor(lk, gear)
	GearLook.extras(lk, gear, String(rec.get("weapon", "sword")))
	return lk


static func armor_id(rec: Dictionary) -> String:
	return Gear.base_id(gear_of(rec).get("armor", {}))


## Losing renown for a deed: never below the rank you hold. Returns what was lost.
static func renown_cost(prof, amount: int, reason: String) -> int:
	var r := Renown.state(prof)
	var keep := Renown.needed(Renown.rank(prof))
	var take := clampi(amount, 0, maxi(0, int(r["points"]) - keep))
	r["points"] = int(r["points"]) - take
	Renown._deed(r, reason, 0)
	prof.save()
	return take


# --- a floor ---------------------------------------------------------------------------

## A new floor (main.gd _start_floor): the one who fought beside you heads on
## alone at the stair; this floor's rivals stand where the plan put them.
func setup(plan: Dictionary) -> void:
	results.clear()
	_end_team(true)
	if duel != null and is_instance_valid(duel):
		duel.queue_free()
	duel = null
	duel_enc = {}
	list.clear()
	for r in plan.get("rivals", []):
		add(r["pos"], int(r.get("room", -1)))
	queue_redraw()


## A rival at `pos` (in room `room`, -1 for none): the plan's, the dev tool's
## or a test's. `kind` picks the meeting ("" rolls it).
func add(pos: Vector2, room := -1, kind := "") -> Dictionary:
	climb_met += 1
	var rec := _choose_rival()
	var k := kind if kind != "" else (force_kind if force_kind != "" else _meeting(rec))
	var seen := _seen()
	seen["names"].append(String(rec.get("name", "")))
	seen["kinds"].append(k)
	if k == "team":
		_pair_with_climber(rec)
	var enc := {"pos": pos, "room": room, "kind": k, "rival": rec, "state": "wait", "face": Vector2.DOWN, "offers": [], "fade": 1.0,
		"hoard": pos + Vector2(34, 8), "lying": k == "rescue", "said": _line(k, rec)}
	list.append(enc)
	queue_redraw()
	return enc


func _line(k: String, rec: Dictionary) -> String:
	var pool: Array = LINES.get(k, [])
	var said: String = String(pool[randi() % pool.size()]) if not pool.is_empty() else ""
	var prof = main.profile if main != null else null
	if k in ["trade", "team", "duel"] and prof != null:
		var Lore = load("res://scripts/city_lore.gd")
		var aura: String = Lore.aura_line(prof, "rival")  # (the aura changes how people speak: city_lore.gd AURA)
		if aura != "":
			said = aura + " " + said
		var w: String = Lore.passing_word(prof)  # (an Unbound is taken for marked; a rumour of one found out)
		if w != "":
			said += " " + w
	if rec.get("returning", false) and int(rec.get("robbed", 0)) > 0:
		said = String(LINES["robbed"][0])
	elif rec.get("returning", false) and k != "rescue" and k != "gift":
		said = String(LINES["again"][randi() % LINES["again"].size()]) + " " + said
	# Now and then they pass on what the guardians have learned (guardian_lessons.gd).
	if k in ["trade", "team", "gift"] and main != null and main.profile != null and randf() < float(RULES.get("rumour_chance", 0.5)):
		var r: String = load("res://scripts/guardian_lessons.gd").rumour(main.profile)
		if r != "":
			said += " " + r
			return said
	# Rarely, something else in passing: their own Entity, or the counting rhyme.
	if k in ["trade", "team", "gift", "duel"]:
		var roll := randf()
		if roll < float(RULES.get("entity_chance", 0.0)):
			said += " " + String(LINES["entity"][randi() % LINES["entity"].size()])
		elif roll < float(RULES.get("entity_chance", 0.0)) + float(RULES.get("rhyme_chance", 0.0)):
			var rhyme: Array = load("res://scripts/dining.gd").RHYME
			if not rhyme.is_empty():
				said += " " + String(LINES["rhyme"][randi() % LINES["rhyme"].size()]).replace("{rhyme}", String(rhyme[randi() % rhyme.size()]))
	# In a wild tower they speak of it now and then (wild_towers.gd RUMOURS "rival").
	if k in ["trade", "team", "gift"] and main != null and main.profile != null and randf() < float(RULES.get("wild_chance", 0.5)):
		var Wild = load("res://scripts/wild_towers.gd")
		if Wild.floor_wild(main):
			said += " " + Wild.rumour(main.profile, "rival", String(main.tower))
	return said


## Who and which meetings this climb has had: {climb, names, kinds} (a
## new climb, or a profile's next climb, starts it afresh).
func _seen() -> Dictionary:
	if climb_seen.is_empty() or int(climb_seen.get("climb", -1)) != _climb_id():
		climb_seen = {"climb": _climb_id(), "names": [], "kinds": []}
	return climb_seen


## A met rival returns (stronger), or a new one is made; never one already
## met this climb.
func _choose_rival() -> Dictionary:
	var prof = main.profile if main != null else null
	var pool: Array = []
	var met_now: Array = _seen()["names"]
	for r in state(prof).values():
		if r is Dictionary and r.has("name") and int(r.get("climb", -1)) != _climb_id() and not String(r["name"]) in met_now:
			pool.append(r)
	var back := randf() < float(RULES["return_chance"]) if force_return < 0 else force_return == 1
	if not pool.is_empty() and back:
		var r: Dictionary = (pool[randi() % pool.size()] as Dictionary).duplicate(true)
		_grow(r)
		r["returning"] = true
		return r
	return new_rival(main.floor_num if main != null else 2, String(main.tower) if main != null else "")


## Stronger each time they return: every mark a step higher, maybe a new one.
func _grow(r: Dictionary) -> void:
	var bl: Array = r.get("bonds", [])
	for b in bl:
		b[2] = clampi(int(b[2]) + int(RULES["return_steps"]), 1, 5)
	if bl.size() < 3 and randf() < float(RULES["grow_mark"]):
		var have: Array = bl.map(func(b): return String(b[0]))
		var parts: Array = Bonds.PARTS.filter(func(pt): return not bl.any(func(b): return String(b[1]) == pt))
		var ids: Array = Bonds.BONDS.keys().filter(func(id): return not id in have)
		if not parts.is_empty() and not ids.is_empty():
			bl.append([ids[randi() % ids.size()], parts[randi() % parts.size()], 1])
	r["bonds"] = bl


func _climb_id() -> int:
	return int(main.profile.climbs) if main != null and main.profile != null else 0


## A new rival for a floor of a tower: a name, a look, gear and marks.
func new_rival(floor_num: int, tid: String) -> Dictionary:
	var used: Array = state(main.profile if main != null else null).values().map(func(r): return String(r.get("name", "")) if r is Dictionary else "")
	used.append_array(_seen()["names"] if main != null else [])
	var names: Array = NAMES.filter(func(n): return not n in used)
	if names.is_empty():
		names = NAMES
	var nm := String(names[randi() % names.size()])
	var gear: Array = []
	var armors: Array = ARMORS[0][1]
	for a in ARMORS:
		if floor_num >= int(a[0]):
			armors = a[1]
	var arm := String(armors[randi() % armors.size()])
	if arm != "":
		gear.append(Gear.code(Gear.make(arm, Gear.roll_rarity(floor_num))))
	var piece := Gear.roll_gear("", [], true, floor_num, tid)
	if Gear.is_piece(piece):
		gear.append(Gear.code(piece))
	return {"id": "%s_%d" % [nm.to_lower(), randi() % 100000], "name": nm, "app": Appearance.random({}),
		"weapon": String(WEAPONS[randi() % WEAPONS.size()]), "gear": gear, "bonds": roll_bonds(floor_num, tid),
		"met": 0, "duels_won": 0, "duels_lost": 0, "teamed": 0, "rescued": 0, "robbed": 0, "traded": 0, "shared": 0, "owed": false}


## Marks for a rival on a floor: [[bond, part, step], ...], the strongest first
## (the tower's own bonds a little likelier for the first).
static func roll_bonds(floor_num: int, tid: String) -> Array:
	var n := 1
	if floor_num >= int(RULES["second_from"]) and randf() < float(RULES["second"]):
		n += 1
	if floor_num >= int(RULES["third_from"]) and randf() < float(RULES["third"]):
		n += 1
	var ids: Array = Bonds.BONDS.keys()
	ids.shuffle()
	var own: Array = ids.filter(func(id): return String(Bonds.BONDS[id].get("tower", "")) == tid)
	if not own.is_empty() and randf() < 0.5:
		ids.erase(own[0])
		ids.push_front(own[0])
	var parts: Array = Bonds.PARTS.duplicate()
	parts.shuffle()
	var top := clampi(1 + int(float(floor_num) / float(RULES["step_floors"])) + randi_range(0, int(RULES["step_spread"])), 1, 5)
	var out: Array = []
	for k in n:
		out.append([ids[k], parts[k], clampi(top - k, 1, 5)])
	return out


## The meeting: a grudge wants a duel, a debt brings a gift, else the
## weights, among the meetings this climb hasn't had yet (where one is left).
func _meeting(rec: Dictionary) -> String:
	if rec.get("returning", false) and int(rec.get("robbed", 0)) > 0:
		return "duel"
	if rec.get("returning", false) and rec.get("owed", false):
		return "gift"
	var fl: int = main.floor_num if main != null else 2
	var open: Array = MEETINGS.keys().filter(func(k): return fl >= int(MEETINGS[k].get("from", 1)))
	var had: Array = _seen()["kinds"] if main != null else []
	var fresh: Array = open.filter(func(k): return not k in had)
	if not fresh.is_empty():
		open = fresh
	var total := 0.0
	for k in open:
		total += _weight(k)
	var roll := randf() * total
	for k in open:
		roll -= _weight(k)
		if roll <= 0.0:
			return k
	return String(open[-1]) if not open.is_empty() else "trade"


## A meeting's weight: MEETINGS', and a worn title may make teaming up likelier.
func _weight(k: String) -> float:
	var w := float(MEETINGS[k].get("weight", 1.0))
	return w * float(terms()["team"]) if k == "team" else w


## How climbers treat you, from the title you wear (titles.gd rival_terms:
## friendlier trades, more offers to team up, a smaller toll, bets).
func terms() -> Dictionary:
	return load("res://scripts/titles.gd").rival_terms(main.profile if main != null else null)


## One who offers to team up often carries a mark whose state reacts with a
## state your marks leave (pair_bias), so two marks meet even if you carry one.
func _pair_with_climber(rec: Dictionary) -> void:
	if main == null or main.player == null or randf() >= float(RULES["pair_bias"]):
		return
	var mine: Array = []
	for b in main.player.bonds.values():
		mine.append(String(BOND_STATE.get(String(b.id), "")))
	var theirs: Array = rec.get("bonds", [])
	for b in theirs:
		if _reacts_with(String(BOND_STATE.get(String(b[0]), "")), mine):
			return
	var fits: Array = []
	for id in BOND_STATE:
		if _reacts_with(String(BOND_STATE[id]), mine) and not main.player.has_bond(id):
			fits.append(id)
	if fits.is_empty() or theirs.is_empty():
		return
	theirs[0][0] = fits[randi() % fits.size()]


static func _reacts_with(st: String, states: Array) -> bool:
	if st == "":
		return false
	var R = load("res://scripts/reactions.gd")
	for id in R.REACTIONS:
		var pair: Array = R.REACTIONS[id]["states"]
		if st in pair:
			var other: String = pair[1] if pair[0] == st else pair[0]
			if other in states and other != st:
				return true
	return false


# --- each frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if main == null or main.player == null:
		return
	var p = main.player
	var pos: Vector2 = p.global_position
	var reach: float = float(RULES["reach"]) + p.radius
	var busy: bool = p.dead or main.climbing or main.camp_choosing
	for enc in list.duplicate():
		var d: float = pos.distance_to(enc["pos"])
		match String(enc["state"]):
			"wait":
				if d < 220.0:
					enc["face"] = (pos - enc["pos"]).normalized() if d > 1.0 else enc["face"]
				if not busy and d < reach + (10.0 if enc["lying"] else 0.0):
					open(enc)
			"rearm":
				if d > reach + 60.0:
					enc["state"] = "wait"
			"leave":
				enc["fade"] = float(enc["fade"]) - delta * 0.5
				if float(enc["fade"]) <= 0.0:
					list.erase(enc)
	_watch_duel(delta)
	_watch_team()
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 15.0
		queue_redraw()


# --- the exchange -----------------------------------------------------------------------

## Walked up to them: the exchange opens on the card screen (main.gd camp
## screen, stage "rival"). The first time, the Entity explains.
func open(enc: Dictionary) -> void:
	main.tip("rivals")
	if not enc.get("noted", false):
		enc["noted"] = true
		_remember(enc)
		var rec: Dictionary = enc["rival"]
		main.note_event("rival", String(TEXT["met_again"] if rec.get("returning", false) else TEXT["met"]) % rec["name"], color_of(rec))
	var choices: Array = []
	match String(enc["kind"]):
		"trade":
			if enc["offers"].is_empty() and not enc.get("offered", false):
				enc["offers"] = make_offers()
				enc["offered"] = true
			for i in enc["offers"].size():
				if not enc["offers"][i].get("done", false):
					choices.append("rv:trade:%d" % i)
		"duel":
			choices.append("rv:duel")
		"team":
			choices.append("rv:team")
		"rescue":
			choices.append_array(["rv:help", "rv:greed"])
		"gift":
			choices.append_array(["rv:gift", "rv:team"])
	choices.append("rv:walk")
	var rec2: Dictionary = enc["rival"]
	main.offer_vault(choices, TEXT["title"] % rec2["name"], [String(enc.get("said", "")), TEXT["marks"] % marks_text(rec2)])
	main.camp["stage"] = "rival"
	main.camp["rival"] = enc
	enc["state"] = "open"
	main.tip("rival_" + String(enc["kind"]))


## Writes them into the climber's record (met once more, where and when).
func _remember(enc: Dictionary) -> void:
	var prof = main.profile
	if prof == null:
		return
	var rec: Dictionary = enc["rival"]
	var st := state(prof)
	var keep: Dictionary = st.get(rec["id"], {})
	for k in ["met", "duels_won", "duels_lost", "teamed", "rescued", "robbed", "traded", "shared"]:
		rec[k] = maxi(int(rec.get(k, 0)), int(keep.get(k, 0)))
	rec["met"] = int(rec.get("met", 0)) + 1
	rec["climb"] = _climb_id()
	rec["seen"] = int(Time.get_unix_time_from_system()) * 10 + (int(rec.get("met", 0)) % 10)
	rec["tower"] = String(main.tower)
	rec["floor"] = int(main.floor_num)
	_save(rec)


## Keeps a rival's record (without this climb's flags), oldest forgotten first.
func _save(rec: Dictionary) -> void:
	var prof = main.profile
	if prof == null:
		return
	var st := state(prof)
	var keep := rec.duplicate(true)
	keep.erase("returning")
	st[rec["id"]] = keep
	while st.size() > int(RULES["kept"]):
		var oldest := ""
		for id in st:
			if oldest == "" or int(st[id].get("seen", 0)) < int(st[oldest].get("seen", 0)):
				oldest = id
		st.erase(oldest)
	prof.save()


func _bump(enc: Dictionary, key: String, by := 1) -> void:
	var rec: Dictionary = enc["rival"]
	rec[key] = int(rec.get(key, 0)) + by
	_save(rec)


## A card of the exchange (main.gd camp_card).
func card(pick: String) -> Dictionary:
	var enc: Dictionary = main.camp.get("rival", {})
	var rec: Dictionary = enc.get("rival", {})
	var col := color_of(rec)
	var op := pick.get_slice(":", 1)
	match op:
		"walk":
			return {"name": TEXT["walk_name"], "desc": TEXT["walk_desc"], "color": Color(0.6, 0.58, 0.66), "item": ""}
		"duel":
			return {"name": TEXT["duel_name"], "desc": TEXT["duel_desc"], "color": Color(0.95, 0.55, 0.42), "item": ""}
		"team":
			return {"name": TEXT["team_name"], "desc": TEXT["team_desc"], "color": Color(0.6, 1.0, 0.75), "item": ""}
		"help":
			var has_draught: bool = main.player.item_count("draught") > 0
			return {"name": TEXT["help_name"], "desc": TEXT["help_draught"] if has_draught else TEXT["help_blood"] % int(_help_cost()),
				"color": Color(0.6, 1.0, 0.7), "item": "draught" if has_draught else ""}
		"greed":
			return {"name": TEXT["greed_name"], "desc": TEXT["greed_desc"], "color": Color(1.0, 0.8, 0.4), "item": ""}
		"gift":
			var g := _gift_of(enc)
			return {"name": TEXT["gift_name"], "desc": TEXT["gift_desc"] % [int(g["amount"]), Essence.display(String(g["kind"])), Items.info(String(g["item"]))["name"]],
				"color": col, "item": "", "crystal": String(g["kind"])}
		"trade":
			var i := int(pick.get_slice(":", 2))
			var offers: Array = enc.get("offers", [])
			if i < 0 or i >= offers.size():
				return {"name": "", "desc": "", "color": col, "item": ""}
			var o: Dictionary = offers[i]
			var give: Dictionary = o["give"]
			var c := {"name": TEXT["trade_name"] % thing_name(give), "desc": TEXT["trade_desc"] % thing_name(o["want"]), "color": col, "item": ""}
			var what := ""
			match String(give["type"]):
				"item":
					c["item"] = String(give["id"])
					c["color"] = Items.color(String(give["id"]))
					what = String(Items.info(String(give["id"])).get("desc", ""))
				"gear":
					c["gear"] = give["rec"]
					c["color"] = Gear.color(give["rec"])
					c["rim"] = Gear.rarity_color(give["rec"])
					what = Gear.desc(give["rec"])
				"crystal":
					c["crystal"] = String(give["kind"])
					c["color"] = Essence.color(String(give["kind"]))
			if what != "":
				c["desc"] = String(TEXT["trade_what"]) % [String(c["desc"]), what]
			if not can_pay(o["want"]):
				c["note"] = TEXT["trade_short"]
			return c
	return {"name": pick, "desc": "", "color": col, "item": ""}


## A card taken (main.gd choose_camp).
func choose(i: int) -> void:
	var enc: Dictionary = main.camp.get("rival", {})
	var choices: Array = main.camp.get("choices", [])
	if enc.is_empty() or i < 0 or i >= choices.size():
		return
	var pick := String(choices[i])
	var op := pick.get_slice(":", 1)
	match op:
		"walk":
			_close()
			enc["state"] = "rearm"
		"trade":
			var said := trade(enc, int(pick.get_slice(":", 2)))
			_close()
			enc["state"] = "rearm" if enc["offers"].any(func(o): return not o.get("done", false)) else "leave"
			if said != "":
				main.note_event("rival", said, color_of(enc["rival"]))
		"duel":
			_close()
			start_duel(enc)
		"team":
			_close()
			start_team(enc)
		"help":
			_close()
			help(enc)
		"greed":
			_close()
			greed(enc)
		"gift":
			_close()
			take_gift(enc)
			enc["kind"] = "team"
			enc["state"] = "rearm"


func _close() -> void:
	main.camp_choosing = false
	main.camp = {}
	if main.player != null:
		main.player.set_physics_process(true)
	if main.wings != null:
		main.wings.unfreeze()
	main.sfx("pickup", 0.95, -4.0, 0.0)


# --- trading ----------------------------------------------------------------------------

## A thing in words: "Healing Vial", "Chain Shirt", "12 Air crystal".
func thing_name(t: Dictionary) -> String:
	match String(t.get("type", "")):
		"item":
			return Items.item_name(String(t["id"]))
		"gear":
			return Gear.display(t["rec"])
		"crystal":
			return TEXT["trade_crystal"] % [int(t["amount"]), Essence.display(String(t["kind"]))]
		"essence":
			return TEXT["trade_essence"] % int(t["amount"])
	return "?"


## What a thing is worth, by the store's own prices (crystals and essence at face value).
static func worth(t: Dictionary) -> float:
	var Train = load("res://scripts/train.gd")
	match String(t.get("type", "")):
		"item":
			var pr: Array = Train.item_price(String(t["id"]))
			return maxf(4.0, float(pr[1]))
		"gear":
			return float(Train.gear_price(t["rec"]))
		"crystal", "essence":
			return float(t["amount"])
	return 0.0


## Their offers: two or three swaps, each for something you carry of about
## the same worth (else crystals, else unbanked essence).
func make_offers() -> Array:
	var gives: Array = []
	var fl: int = main.floor_num
	var g := Gear.roll_gear("", [], true, fl, String(main.tower))
	if Gear.is_gear(g):
		gives.append({"type": "gear", "rec": g})
	var id := Items.random_item(main.player != null and not main.player.bonds.is_empty(), ["scroll", "vessel"], false, String(main.tower))
	gives.append({"type": "item", "id": id})
	var kind := String(color_kind(enc_tower()))
	gives.append({"type": "crystal", "kind": kind, "amount": roundf(float(RULES["trade_crystals"]) + float(RULES["trade_per_floor"]) * fl)})
	gives.shuffle()
	var out: Array = []
	var asked: Array = []
	for give in gives.slice(0, clampi(int(RULES["trade_offers"]), 1, 3)):
		var want := _want_for(give, asked)
		asked.append(want)
		out.append({"give": give, "want": want})
	return out


func enc_tower() -> String:
	return String(main.tower)


static func color_kind(tid: String) -> String:
	return String(Towers.TOWERS.get(tid, {}).get("essence", "air"))


## What they ask for a thing: the thing you carry nearest its worth (within
## fair_low and fair_high of it), else that worth in crystals of a kind you
## hold, else in unbanked essence.
func _want_for(give: Dictionary, asked: Array) -> Dictionary:
	var v := worth(give) * float(terms()["trade_ask"])  # (a worn title can make them ask less: titles.gd rival_terms)
	var p = main.player
	var best := {}
	var best_d := INF
	var cands: Array = []
	if p != null:
		for id in p.carried():
			if id in ["scroll", "vessel"]:
				continue
			cands.append({"type": "item", "id": id})
		for r in p.pack:
			if Gear.is_gear(r):
				cands.append({"type": "gear", "rec": r})
	for c in cands:
		if asked.any(func(a): return _same_thing(a, c)) or (String(give["type"]) == "item" and String(c["type"]) == "item" and String(c["id"]) == String(give["id"])):
			continue
		var w := worth(c)
		if w < v * float(RULES["fair_low"]) or w > v * float(RULES["fair_high"]):
			continue
		var dd := absf(w - v)
		if dd < best_d:
			best_d = dd
			best = c
	if not best.is_empty():
		return best
	var amount := maxf(1.0, roundf(v))
	if String(give["type"]) != "crystal" and main.profile != null:
		var top := ""
		for c in main.profile.crystals:
			if top == "" or float(c["amount"]) > main.profile.crystal_total(top):
				top = String(c["kind"])
		if top != "" and main.profile.crystal_total(top) >= amount:
			return {"type": "crystal", "kind": top, "amount": amount}
	return {"type": "essence", "amount": amount}


static func _same_thing(a: Dictionary, b: Dictionary) -> bool:
	if String(a.get("type", "")) != String(b.get("type", "")):
		return false
	match String(a["type"]):
		"item":
			return String(a["id"]) == String(b["id"])
		"gear":
			return Gear.same(a["rec"], b["rec"])
	return false


func purse() -> float:
	var held := 0.0
	for k in main.run_essence:
		held += float(main.run_essence[k])
	return held


## True if you can give it now.
func can_pay(want: Dictionary) -> bool:
	var p = main.player
	match String(want.get("type", "")):
		"item":
			return p != null and p.item_count(String(want["id"])) > 0
		"gear":
			return p != null and p.pack.any(func(r): return Gear.same(r, want["rec"]))
		"crystal":
			return main.profile != null and main.profile.crystal_total(String(want["kind"])) >= float(want["amount"])
		"essence":
			return purse() + 0.001 >= float(want["amount"])
	return false


## Gives it up. False if you can't.
func pay(want: Dictionary) -> bool:
	if not can_pay(want):
		return false
	var p = main.player
	match String(want["type"]):
		"item":
			take_item(p, String(want["id"]))
		"gear":
			for i in p.pack.size():
				if Gear.same(p.pack[i], want["rec"]):
					p.pack.remove_at(i)
					break
		"crystal":
			main.profile.spend(String(want["kind"]), float(want["amount"]))
			main.profile.save()
		"essence":
			take_essence(float(want["amount"]))
	return true


## Takes one of an item from the belt.
static func take_item(p, id: String) -> void:
	p.take_one(id)


## Takes unbanked essence, spread over its kinds; what was taken.
func take_essence(amount: float) -> float:
	var held := purse()
	if held <= 0.0:
		return 0.0
	var take := minf(amount, held)
	for k in main.run_essence.keys():
		main.run_essence[k] = maxf(0.0, float(main.run_essence[k]) - take * float(main.run_essence[k]) / held)
	return take


## Gives you a thing; what to say.
func give(t: Dictionary) -> String:
	match String(t["type"]):
		"item":
			return main._take_item(String(t["id"]), "Traded")
		"gear":
			return main._take_gear(t["rec"])
		"crystal":
			main.profile.add_crystal(String(t["kind"]), float(t["amount"]))
			main.profile.save()
			return "+ " + Items.CRYSTAL["name"] % Essence.display(String(t["kind"]))
	return ""


## A swap taken: you give what they asked, they give their side. What to say ("" if you couldn't).
func trade(enc: Dictionary, i: int) -> String:
	var offers: Array = enc.get("offers", [])
	if i < 0 or i >= offers.size() or offers[i].get("done", false):
		return ""
	var o: Dictionary = offers[i]
	if not pay(o["want"]):
		return ""
	o["done"] = true
	var got := give(o["give"])
	_bump(enc, "traded")
	results.append("traded")
	return TEXT["traded"] % [enc["rival"]["name"], got]


# --- a duel -------------------------------------------------------------------------------

## The rival's body for a duel or for teaming up (rival.gd), where they stand.
func spawn_body(enc: Dictionary, as_ally: bool):
	var e = load(BODY).new()
	e.setup_rival(main, body_data(enc["rival"]), as_ally, self)
	var at: Vector2 = enc["pos"]
	e.position = main.clear_spot(at, e.radius, main.enemies().map(func(o): return o.global_position)) if main.has_method("clear_spot") else at
	if main.player != null:
		e.face = (main.player.global_position - e.position).normalized()
	main.add_child(e)
	return e


## What the body is built from.
func body_data(rec: Dictionary) -> Dictionary:
	var steps := 0
	var enchant := ""  # (a weapon piece of theirs that is enchanted shows its essence: particles.gd)
	for slot in ["melee", "ranged"]:
		var wp = gear_of(rec).get(slot)
		if wp != null and Gear.base_id(wp) == String(rec.get("weapon", "sword")):
			enchant = Gear.enchant_kind(wp)
	for b in rec.get("bonds", []):
		steps += int(b[2])
	return {"name": String(rec.get("name", "")), "look": look_of(rec), "weapon": String(rec.get("weapon", "sword")), "enchant": enchant, "armor": armor_id(rec),
		"bonds": rec.get("bonds", []).duplicate(true), "hp": float(RULES["hp"]) + float(RULES["hp_per_step"]) * steps,
		"armor_k": float(RULES["armor"]), "states": BOND_STATE, "state_seconds": float(RULES["state_seconds"]),
		"yield": float(RULES["duel_yield"]), "taken": float(RULES["ally_taken"]), "leave": float(RULES["ally_leave"])}


## The duel begins: the room's doors shut behind you (doors.gd lock-in:
## they open again once it's over), and they come at you.
func start_duel(enc: Dictionary) -> void:
	enc["state"] = "duel"
	duel = spawn_body(enc, false)
	duel_enc = enc
	duel_t = 0.0
	var rm := int(enc.get("room", -1))
	if rm >= 0 and main.door_view != null and rm < main.room_info.size():
		var gates: Array = main.room_info[rm].get("gates", [])
		var lr: Dictionary = main.door_view.lock_rooms.get(rm, {})
		if not gates.is_empty() and (lr.is_empty() or String(lr.get("state", "")) in ["armed", "done"]):
			main.door_view.lock_rooms[rm] = {"state": "pending", "gates": gates, "bodies": [], "mobs": [], "t": 0.0}
	main.banner = {"title": TEXT["duel_title"], "lines": [TEXT["duel_line"] % enc["rival"]["name"]], "t": 2.6}
	main.sfx("warn_knight", 1.1, -2.0, 0.0)


func duel_on() -> bool:
	return duel != null and is_instance_valid(duel) and not duel.dead


func _watch_duel(delta: float) -> void:
	if duel_enc.is_empty():
		return
	if not is_instance_valid(duel):
		duel = null
		duel_enc = {}
		return
	duel_t += delta
	var p = main.player
	# Gone too far, or too long: it's called off (no winner).
	if duel_t > float(RULES["duel_time"]) or (p != null and p.global_position.distance_to(duel.global_position) > 900.0):
		var enc := duel_enc
		enc["pos"] = duel.global_position
		duel.stand_down()
		duel = null
		duel_enc = {}
		enc["state"] = "leave"
		main.note_event("rival", TEXT["duel_off"] % enc["rival"]["name"], color_of(enc["rival"]))


## The rival yielded (rival.gd): you won the duel.
func on_yield(body) -> void:
	if body != duel or duel_enc.is_empty():
		return
	var enc := duel_enc
	var rec: Dictionary = enc["rival"]
	duel = null
	duel_enc = {}
	enc["pos"] = body.global_position
	enc["state"] = "leave"
	enc["fade"] = 2.0
	var lines: Array = [TEXT["duel_won"] % rec["name"]]
	var kind := color_kind(String(main.tower))
	var amt: float = float(RULES["duel_crystals"]) + float(RULES["duel_per_floor"]) * main.floor_num
	if main.ward and int(RULES["duel_ward"]) > 0:
		main.lift_ward()
	else:
		amt *= float(RULES["duel_bonus"])
		lines.append(TEXT["duel_bonus"])
	if main.profile != null:
		main.profile.add_crystal(kind, amt)
		lines.append("+ %d %s" % [int(round(amt)), Items.CRYSTAL["name"] % Essence.display(kind)])
		main.note_event("crystal", lines[-1], Essence.color(kind))
		var won: Dictionary = Renown.earn(main.profile, int(RULES["duel_renown"]), TEXT["deed_duel"] % rec["name"])
		lines.append(Renown.TEXT["earned"] % int(won["amount"]))
		_titles(won)
	var gear: Array = rec.get("gear", [])
	if not gear.is_empty() and randf() < float(RULES["duel_gear"]):
		main.drop_gear(body.global_position + Vector2(0, 14), Gear.rec(gear[randi() % gear.size()]), true)
	_bump(enc, "duels_won")
	results.append("duel_won")
	main.banner = {"title": TEXT["duel_won_title"], "lines": lines, "t": 3.2}
	main.note_event("rival", lines[0], color_of(rec))
	main.sfx("clear", 1.1, -2.0, 0.0)


## main.gd proving_spare: a blow that would fell you during a duel knocks
## you down instead. True if it did.
func spare() -> bool:
	if not duel_on():
		return false
	var p = main.player
	var enc := duel_enc
	var rec: Dictionary = enc["rival"]
	p.hp = maxf(1.0, p.max_health() * float(RULES["duel_left"]))
	p.iframes = maxf(p.iframes, 2.0)
	# The toll: a share of your unbanked essence, else a piece from your pack.
	var toll: String = TEXT["toll_none"]
	var share := roundf(purse() * float(RULES["duel_toll"]) * float(terms()["toll"]))  # (a worn title may halve it: titles.gd)
	if share >= float(RULES["duel_toll_min"]):
		toll = TEXT["toll_essence"] % int(take_essence(share))
	elif not p.pack.is_empty():
		var i: int = randi() % p.pack.size()
		toll = TEXT["toll_piece"] % Gear.display(p.pack[i])
		p.pack.remove_at(i)
	elif purse() > 0.0:
		toll = TEXT["toll_essence"] % int(take_essence(share if share > 0.0 else purse()))
	enc["pos"] = duel.global_position
	enc["state"] = "leave"
	enc["fade"] = 2.0
	duel.stand_down()
	duel = null
	duel_enc = {}
	_bump(enc, "duels_lost")
	results.append("duel_lost")
	var line: String = TEXT["duel_lost"] % [rec["name"], toll]
	main.banner = {"title": TEXT["duel_lost_title"], "lines": [line], "t": 3.2}
	main.note_event("rival", line, color_of(rec))
	main.shake(6.0)
	return true


# --- teaming up -----------------------------------------------------------------------------

## They fight beside you until the stair.
func start_team(enc: Dictionary) -> void:
	_end_team(false)
	enc["state"] = "team"
	team = spawn_body(enc, true)
	team_enc = enc
	team_floor = int(main.floor_num)
	_bump(enc, "teamed")
	results.append("teamed")
	var rec: Dictionary = enc["rival"]
	main.banner = {"title": TEXT["team_title"], "lines": [TEXT["team_line"] % rec["name"]], "t": 3.0}
	main.note_event("rival", TEXT["team_line"] % rec["name"], color_of(rec), false)
	_shared_synergies(rec)
	main.sfx("ready", 1.1, -3.0, 0.0)


## Synergies one of whose marks is theirs hold while they're beside you (synergies.gd): said once.
func _shared_synergies(rec: Dictionary) -> void:
	if main.player == null:
		return
	var Synergies = load("res://scripts/synergies.gd")
	var theirs: Array = rec.get("bonds", []).map(func(b): return String(b[0]))
	for id in Synergies.SYNERGIES:
		var pair: Array = Synergies.SYNERGIES[id]["bonds"]
		var mine := pair.filter(func(b): return main.player.has_bond(String(b))).size()
		var got := pair.filter(func(b): return not main.player.has_bond(String(b)) and String(b) in theirs).size()
		if mine >= 1 and mine + got == pair.size() and got >= 1:
			main.note_event("synergy", TEXT["shared_synergy"] % [Synergies.SYNERGIES[id]["name"], rec["name"]], Synergies.SYNERGIES[id]["color"])
			main.tip("synergies")


func team_on() -> bool:
	return team != null and is_instance_valid(team) and not team.dead


## The bonds of the rival beside you ([] for none): synergies.gd counts them.
func ally_bonds() -> Array:
	if not team_on():
		return []
	return team.bond_ids()


## The share of essence you keep (main.gd gather_essence).
func share() -> float:
	return float(RULES["team_share"]) if team_on() else 1.0


## How often finds drop (main.gd on_enemy_killed).
func drop_mult() -> float:
	return float(RULES["team_drops"]) if team_on() else 1.0


func _watch_team() -> void:
	if team_enc.is_empty():
		return
	if team == null or not is_instance_valid(team):
		team = null
		team_enc = {}


## The rival beside you fell back, hurt (rival.gd): the team is over.
func on_spent(body) -> void:
	if body != team or team_enc.is_empty():
		return
	var enc := team_enc
	team = null
	team_enc = {}
	enc["pos"] = body.global_position
	enc["state"] = "leave"
	enc["fade"] = 1.5
	results.append("team_spent")
	main.note_event("rival", TEXT["team_spent"] % enc["rival"]["name"], color_of(enc["rival"]))


## The team ends: at a stair (`stair`: renown for climbing it together) or
## when another takes their place.
func _end_team(stair: bool) -> void:
	if team_enc.is_empty():
		team = null
		return
	var rec: Dictionary = team_enc["rival"]
	if team != null and is_instance_valid(team):
		team.stand_down()
	team = null
	team_enc = {}
	# (a fall, a restart or a drop through a chasm ends it with nothing)
	stair = stair and main != null and (main.in_camp or int(main.floor_num) > team_floor) and main.player != null and not main.player.dead
	if stair and main != null and main.profile != null:
		var got: Dictionary = Renown.earn(main.profile, int(RULES["team_renown"]), TEXT["deed_team"] % rec["name"])
		_titles(got)
		main.note_event("rival", TEXT["team_end"] % rec["name"], color_of(rec))
		results.append("team_stair")


## A reaction set off by their state and yours together (reactions.gd).
func on_shared_reaction(id: String, rname: String) -> void:
	var enc := team_enc if not team_enc.is_empty() else duel_enc
	if enc.is_empty() or String(enc["rival"]["name"]) != rname:
		return
	_bump(enc, "shared")
	results.append("shared:" + id)
	main.tip("rival_reaction")


# --- the wounded climber and the hoard --------------------------------------------------------

func _help_cost() -> float:
	return roundf(main.player.max_health() * float(RULES["rescue_cost"])) if main.player != null else 0.0


## Helped up: a draught (or your health), renown, and they owe you.
func help(enc: Dictionary) -> void:
	var p = main.player
	var rec: Dictionary = enc["rival"]
	if p.item_count("draught") > 0:
		take_item(p, "draught")
	else:
		p.hp = maxf(1.0, p.hp - _help_cost())
	enc["lying"] = false
	enc["state"] = "leave"
	enc["fade"] = 2.5
	rec["owed"] = true
	_bump(enc, "rescued")
	results.append("rescued")
	var lines: Array = [TEXT["rescued"] % rec["name"]]
	if main.profile != null:
		var got: Dictionary = Renown.earn(main.profile, int(RULES["rescue_renown"]), TEXT["deed_rescue"] % rec["name"])
		lines.append(Renown.TEXT["earned"] % int(got["amount"]))
		_titles(got)
	main.MakersScript.feed(main, "spared")
	main.banner = {"title": TEXT["rescued_title"], "lines": lines, "t": 3.0}
	main.note_event("rival", lines[0], color_of(rec))
	main.fx_ring(enc["pos"], Color(0.6, 1.0, 0.7), 40.0, 0.5, 3.0)


## The hoard taken: essence and a finer piece; renown lost, and the Makers notice.
func greed(enc: Dictionary) -> void:
	var rec: Dictionary = enc["rival"]
	var at: Vector2 = enc["hoard"]
	var kind := color_kind(String(main.tower))
	var amt: float = float(RULES["greed_essence"]) + float(RULES["greed_per_floor"]) * main.floor_num
	main.gather_essence(kind, amt, at)
	var g = main.find_gear("", int(RULES["greed_row"]))
	if not g.is_empty():
		main.drop_gear(at + Vector2(0, 16), g, true)
	enc["hoard_taken"] = true
	enc["state"] = "done"
	_bump(enc, "robbed")
	rec["owed"] = false
	_save(rec)
	results.append("robbed")
	var lost := 0
	if main.profile != null:
		lost = renown_cost(main.profile, int(RULES["greed_renown"]), TEXT["deed_greed"] % -int(RULES["greed_renown"]))
	main.MakersScript.feed(main, "greed")
	var lines: Array = [TEXT["greed"] % rec["name"], TEXT["greed_noticed"]]
	if lost > 0:
		lines.append("-%d renown" % lost)
	main.banner = {"title": TEXT["greed_title"], "lines": lines, "t": 3.0}
	main.note_event("rival", lines[0], color_of(rec))
	main.sfx("glint", 0.8, -3.0)


## What an owed rival's gift holds.
func _gift_of(enc: Dictionary) -> Dictionary:
	if not enc.has("gift"):
		enc["gift"] = {"kind": color_kind(String(main.tower)), "amount": float(RULES["gift_crystals"]) + main.floor_num,
			"item": Items.random_item(main.player != null and not main.player.bonds.is_empty(), ["scroll", "vessel"], false, String(main.tower))}
	return enc["gift"]


## The gift taken: crystals and an item; the debt is paid.
func take_gift(enc: Dictionary) -> void:
	var g := _gift_of(enc)
	var rec: Dictionary = enc["rival"]
	main.profile.add_crystal(String(g["kind"]), float(g["amount"]))
	main.profile.save()
	var got := String(main._take_item(String(g["item"]), "Took"))
	rec["owed"] = false
	_save(rec)
	results.append("gift")
	main.note_event("rival", TEXT["gift_taken"] % rec["name"] + ": " + got, color_of(rec))


## (A title a deed made ready is said by main.gd on_renown, as every gain is.)
func _titles(_got: Dictionary) -> void:
	pass


# --- the HUD ----------------------------------------------------------------------------------

## The status chips (hud.gd status_chips): a duel's foe, the one beside you.
func chips() -> Array:
	var out: Array = []
	if duel_on():
		out.append({"id": "rival", "text": TEXT["chip_duel"] % duel.rival_name, "gauge": clampf(duel.hp / duel.max_hp, 0.0, 1.0),
			"gauge_color": Color(0.95, 0.55, 0.42), "color": UI.GILT_HI, "edge": UI.GILT})
	if team_on():
		out.append({"id": "rival", "text": TEXT["chip_team"] % team.rival_name, "gauge": clampf(team.hp / team.max_hp, 0.0, 1.0),
			"gauge_color": Color(0.5, 0.95, 0.65), "color": Color(0.75, 1.0, 0.82), "edge": Color(0.5, 0.95, 0.65)})
	return out


# --- drawing ------------------------------------------------------------------------------------

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	for enc in list:
		if String(enc["state"]) in ["duel", "team"]:
			continue
		var a := clampf(float(enc["fade"]), 0.0, 1.0)
		var rec: Dictionary = enc["rival"]
		if not enc.has("look"):
			enc["look"] = look_of(rec)
		var at: Vector2 = enc["pos"]
		if enc["kind"] == "rescue" and not enc.get("hoard_taken", false):
			_draw_hoard(enc["hoard"], pulse)
		var b := Draw.Batch.new()
		var f: Vector2 = enc["face"]
		if enc["lying"]:
			Appearance.draw_fallen_body(b, Vector2.LEFT, Vector2.DOWN, Draw.LIGHT_DIR, enc["look"])
		else:
			var w := Weapons.info(String(rec.get("weapon", "sword")))
			MirrorScript.draw_climber(b, enc["look"], {"f": f, "sd": f.orthogonal(), "light": Draw.LIGHT_DIR, "s": 0.0, "t": t,
				"weapon": String(rec.get("weapon", "sword")), "w": w, "armor": armor_id(rec), "radius": 14.0})
			for m in rec.get("bonds", []):
				var mp := mark_at(String(m[1]), f, f.orthogonal(), 14.0)
				b.dot(mp, 3.2, Color(Palette.OUTLINE, 0.8))
				b.dot(mp, 2.3, bond_color(String(m[0])))
		if a < 1.0:
			for i in b.cols.size():
				b.cols[i] = Color(b.cols[i], b.cols[i].a * a)
		draw_set_transform(at)
		draw_circle(Vector2(0, 11), 13.0, Color(0, 0, 0, 0.3 * a))
		b.flush(self)
		draw_set_transform(Vector2.ZERO)
		var col := color_of(rec)
		if enc["state"] == "wait":
			draw_arc(at, 26.0, 0.0, TAU, 28, Color(col, (0.25 + 0.3 * pulse) * a), 2.0)
		UI.draw_label(self, at + Vector2(-60, -30), String(rec["name"]), 13, Color(col.lightened(0.3), a), HORIZONTAL_ALIGNMENT_CENTER, 120.0, 3)


## Where a mark sits on a climber facing `f` (as mirror.gd places them).
static func mark_at(part: String, f: Vector2, sd: Vector2, r: float) -> Vector2:
	match part:
		"throat":
			return f * (r * 0.25) + sd * 2.0
		"back":
			return -f * (r * 0.7) + sd * 2.0
		"hand":
			return sd * r * 0.95 + f * 3.0
		"brow":
			return f * (r * 0.55)
		"heart":
			return -sd * r * 0.3 - f * 3.0
	return Vector2(0, r * 0.55)


## The hoard: a pile of chests and coin, glinting.
func _draw_hoard(at: Vector2, pulse: float) -> void:
	for k in 2:
		var o := at + Vector2(k * 12.0 - 6.0, -k * 6.0)
		draw_rect(Rect2(o + Vector2(-10, -4), Vector2(20, 13)), Palette.OUTLINE)
		draw_rect(Rect2(o + Vector2(-8, -2), Vector2(16, 9)), Color(0.5, 0.34, 0.2))
		draw_line(o + Vector2(-8, 1), o + Vector2(8, 1), Color(0.75, 0.62, 0.38), 1.5)
	for i in 6:
		draw_circle(at + Vector2(-14 + i * 5.0, 10 + (i % 2) * 2.0), 2.6, Color(1.0, 0.82, 0.38))
	draw_circle(at + Vector2(4, -10), 2.0 + pulse * 1.5, Color(1.0, 0.95, 0.7, 0.8))
