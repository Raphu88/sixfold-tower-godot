extends RefCounted
## The vessel (name to come; items.gd ITEMS["vessel"] holds its name): a
## sealed glass vessel bound in brass, a container for RAW essence. In the
## lore the cities' economy runs on essence: essence crystallizes as it
## leaves a tower and has to be processed; a vessel keeps it raw. Core
## essence (Making, Unmaking) never crystallizes at all: a vessel is the only
## way to carry it.
##
## A vessel holds one kind, up to CAPACITY, and is set to catch one of two
## things ("catch", changed only while it's empty: its card in the chest, or
## using it from the belt):
##   core  once the climber has a path (secret.gd), the other core essence
##         rises from great foes and passes through them; a vessel on the
##         belt CAPTURES it instead (main.gd pass_through, capture below)
##   raw   at each stair, a vessel on the belt takes RAW "share" of the
##         essence of its kind you'd bank (an empty one: the kind you bank
##         most there), until it's full (main.gd _arrive, stair_raw below).
##         What it takes is NOT banked: it grows no mark or Node and makes
##         no crystals, so it never speeds growth by itself.
##
## What it holds is unbanked: it sits on the belt like other items (one
## kind of item, never stacked), and a fall loses it with the belt. Survive
## the climb or read a recall scroll and it comes home, filled or not, into
## your chest on the train (profile.gd vessels); it is never broken into
## crystals like the rest of the belt (main.gd break_belt skips it). From the
## chest it can be packed onto your belt for the next climb, to keep filling.
##
## Where one comes from: crafted at the workshop's bench (by a Rune Artist,
## or the workshop's Rune Artist for anyone else: bench.gd) (BREW, a real
## cost), and very rarely a vault offers one (VAULT_CHANCE). It's a
## container: using what it holds empties it and the glass stays yours;
## only giving it away (a Noble's contract, a Maker, the bribe) parts with it.
##
## What it's for (vessel_page.gd and the bench put them on the train):
##   tinctures  raw essence becomes tinctures of its kind at the bench's
##              Tinctures counter: RAW "per_tincture" for one (crafting one
##              from crystals costs essence_flow.gd TINCTURE "craft")
##   contracts  now and then a Noble asks for a full vessel of a kind for
##              the city (contracts.gd ASK): renown and a rare good
##   core work  a full vessel of core essence at the bench's Vessel counter:
##              a core rune on a piece (gear.gd CORE_RUNES, Making's or
##              Unmaking's, for CORE "floors" floors), one rank past +3
##              (gear.gd RANK_CAP), or a deep rune (LASTING_RUNES "deep_*")
##   offering   a full vessel of core essence to a Maker when pleading for a
##              change of path (makers.gd PLEA_ODDS "vessel"), or as the
##              Developer's bribe (secret_bonds.gd BRIBE "vessel")
## The outfitter doesn't buy vessels any more (once 120 crystals: a crystal
## faucet the slow growth couldn't hold); the cities pay instead.
##
## A vessel is {"kind": "" (empty), a core kind or a raw kind, "amount":
## float, "catch": "core" or "raw"}; in the chest it may also carry
## "packed": true (it goes up on your next climb). An old save's vessel has
## no "catch": it catches core essence, as it always did. Every word and
## number is here (or in items.gd's entry, gear.gd CORE_RUNES), so it's easy
## to rename or retune.

const Items := preload("res://scripts/items.gd")
const Secret := preload("res://scripts/secret.gd")
const Essence := preload("res://scripts/essence.gd")
const Gear := preload("res://scripts/gear.gd")
const Bench := preload("res://scripts/bench.gd")
const Flow := preload("res://scripts/essence_flow.gd")
const Draw := preload("res://scripts/draw_util.gd")
const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/icon_art.gd")
const OutfitterName := preload("res://scripts/outfitter_name.gd")

## Its item id on the belt (items.gd ITEMS).
const ID := "vessel"
## What it catches: core essence (from great foes) or raw tower essence (at stairs).
const CATCHES := ["core", "raw"]
## How much one holds, of either (30: a few stairs of raw essence, a climb
## or two of core; kept from the first vessels so old saves' full ones stay full).
static var CAPACITY := 30.0
## Raw essence: the share of a stair's essence of its kind a vessel on your
## belt takes (until full), and how much of it makes one tincture at the
## bench (a full vessel: three). Held to the pace models by tests/parts/vessels.gd.
static var RAW := {"share": 0.5, "per_tincture": 15}
## A core rune (gear.gd CORE_RUNES) lasts this many floors worn (each stair
## counts one down), powered by one full vessel of core essence.
static var CORE := {"floors": 18}
## The chance a full vault prize offers a vessel as its third card.
static var VAULT_CHANCE := 0.04
## Brewing one at the bench: its materials (the workshop's Rune Artist adds
## a premium for anyone without the mark: bench.gd price).
static var BREW := {"iron": 60, "water": 45, "air": 45}
## Tests and dev: >= 0 replaces VAULT_CHANCE.
static var vault_force := -1.0

const BRASS := Color(0.86, 0.64, 0.3)
const GLASS := Color(0.62, 0.66, 0.74)

static var TEXT: Dictionary = OutfitterName.named({
	"captured": "+%d %s into the vessel  (%d / %d)",
	"raw_caught": "+%d %s into the vessel, kept raw  (%d / %d)",
	"full": "The vessel is full",
	"use_empty": "The vessel waits, empty: it catches %s",
	"use": "The vessel holds %d / %d %s",
	"empty_core": "empty, for core essence",
	"empty_raw": "empty, for raw essence",
	"raw_name": "raw %s",
	"part": "%d of %d %s",
	"full_of": "full of %s",
	"home": "Your vessel comes home to your stash: %s",
	"lost": "Lost with your belt: your vessel (%s)",
	"hud": "Vessel: %s",
	"hud_core": "It catches the core essence that isn't your path, from great foes, up to %d.",
	"hud_raw": "It catches %d%% of what you'd bank of its kind at each stair, kept raw (not banked), up to %d.",
	"hud_home": "Survive or recall and it comes home to your stash; fall and it's lost.",
	"desc_state": "It holds: %s",
	# What it catches (changed only while empty).
	"catch_core": "Catch core essence",
	"catch_raw": "Catch raw essence",
	"catches_core": "It catches core essence: the one that isn't your path, from great foes. Core essence never crystallizes: only a vessel can carry it.",
	"catches_raw": "It catches raw essence: %d%% of what you'd bank of its kind at each stair (empty, the kind you bank most), until it's full. What it takes isn't banked: no growth, no crystals.",
	"catch_locked": "Empty it before it catches the other.",
	"switched": "The vessel now catches %s",
	"core_word": "core essence",
	"raw_word": "raw essence",
	# The train (vessel_page.gd)
	"shelf": "Vessels  ·  %d",
	"in_chest": "In your stash: safe between climbs.",
	"packed": "Packed for your next climb: it goes on your belt (one kind of item) and keeps filling. Fall, and it's lost with your belt.",
	"packed_tag": "packed",
	"going": "a vessel (%s)",
	"take": "Take it on your next climb",
	"leave": "Leave it in the stash",
	"took": "Packed for your next climb: the vessel",
	"left": "Back in the stash: the vessel",
	"belt_full": "your belt can't hold another kind",
	"lore": "Essence crystallizes as it leaves the tower; a vessel keeps it raw. The cities run on raw essence.",
	"uses_raw": "Raw essence makes tinctures at the workshop's bench (Tinctures: %d raw for one), and a Noble may ask for a full vessel of it for the city.",
	"uses_core": "Core essence, full: a core rune on a piece or work past the bench's limits (the Vessel counter), a Noble's contract, or an offering to a Maker or the Maker of Marks.",
	"no_trade": "{outfitter} doesn't buy vessels. The cities do: now and then a Noble asks for one (a contract).",
	# The bench
	"brew_title": "Brew a vessel",
	"brew_desc": "A sealed glass vessel bound in brass. It goes in your stash, empty. Packed for a climb, it catches raw essence at the stairs, or the core essence that isn't your path: set it on its card in your stash.",
	"brew": "Brew a vessel",
	"brewed": "Brewed: a vessel, in your stash",
	"full_count": "Full vessels of core essence in your stash: %d",
	"no_full": "no full vessel of core essence in your stash",
	"deep_temper_head": "Past the limit: one rank more (uses a full vessel of core essence; the vessel stays, empty).",
	"deep_temper": "Temper to +%d",
	"deep_temper_ask": "Temper this piece to +%d? It uses the core essence in a full vessel (the vessel stays, empty).",
	"deep_only": "Only a piece tempered to +%d can go further",
	"deep_top": "Tempered past the limit already",
	"deep_rune_head": "A deep rune, twice a lasting rune's strength (uses a full vessel of core essence):",
	"deep_rune": "%s: %s",
	"deep_rune_ask": "Work %s into this piece? It uses the core essence in a full vessel (the vessel stays, empty).",
	"deep_has": "it already carries that deep rune",
	"deep_tempered": "Tempered past the limit: %s",
	"deep_inscribed": "Inscribed: %s on %s",
	"deep_note": "With a full vessel of core essence the bench can power a core rune on a piece, or go past its limits: one rank past +%d, or a deep rune at the Inscribe spell's full strength. Raw essence in a vessel makes tinctures at the Tinctures counter.",
	"core_head": "A core rune, powered by a full vessel of %s (lasts %d floors worn):",
	"core_rune": "%s: %s",
	"core_rune_ask": "Work the %s into this piece? It uses the full vessel of %s (the vessel stays, empty), and fades after %d floors worn.",
	"core_has": "it already carries that core rune",
	"core_none": "no full vessel of Making or Unmaking in your stash",
	"core_inscribed": "Core rune: %s on %s",
	"core_faded": "The %s fades from your %s",
	"core_left": "%s  ·  %d floors left",
	"core_replaces": "A new core rune replaces the one on it.",
	# Tinctures from raw essence (the Tinctures counter: train_page.gd)
	"tinct_from": "Make from raw essence (%d raw %s)",
	"tinct_have": "Raw %s in your vessels: %d (enough for %d)",
	"tinct_made": "Made: %s, from raw essence, packed for your next climb",
	"tinct_none": "no vessel in your stash holds %d raw %s",
	"tinct_note": "From raw essence a tincture takes %d (from crystals, %d): crystals must be broken down again, and most is lost.",
	# Dev tools
	"dev": "Vessel",
	"dev_empty": "Give an empty vessel",
	"dev_full": "Give a full vessel",
	"dev_raw": "Give a full raw vessel",
	"dev_given": "A vessel: %s",
})


# --- records -------------------------------------------------------------------------

static func is_raw_kind(kind: String) -> bool:
	return Essence.KINDS.has(kind)


static func valid_kind(kind: String) -> bool:
	return Secret.is_kind(kind) or is_raw_kind(kind)


## A vessel record. A filled one catches what it holds; an empty one catches
## `catch` ("core" if none is given, as the first vessels did).
static func make(kind := "", amount := 0.0, catch := "") -> Dictionary:
	if not valid_kind(kind) or amount <= 0.0:
		return {"kind": "", "amount": 0.0, "catch": catch if catch in CATCHES else "core"}
	return {"kind": kind, "amount": clampf(amount, 0.0, CAPACITY), "catch": "raw" if is_raw_kind(kind) else "core"}


## A vessel from a save (anything broken reads as an empty vessel; an old
## one with no "catch" catches core essence).
static func norm(v) -> Dictionary:
	if not (v is Dictionary):
		return make()
	var out := make(String(v.get("kind", "")), float(v.get("amount", 0.0)), String(v.get("catch", "")))
	if bool(v.get("packed", false)):
		out["packed"] = true
	return out


static func load_list(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for v in raw:
			if v is Dictionary:
				out.append(norm(v))
	return out


## What a new empty vessel catches for this climber: core essence once they
## have a path (what passes through them), else raw essence.
static func default_catch(profile) -> String:
	return "core" if profile != null and String(profile.get("path")) != "" else "raw"


static func catch_of(v) -> String:
	var c := String(v.get("catch", "core")) if v is Dictionary else "core"
	return c if c in CATCHES else "core"


static func is_core(v) -> bool:
	return catch_of(v) == "core"


static func is_raw(v) -> bool:
	return catch_of(v) == "raw"


## Sets what an EMPTY vessel catches. False if it holds something (or `c` isn't one).
static func set_catch(v: Dictionary, c: String) -> bool:
	if not (c in CATCHES) or v.is_empty() or fill(v) > 0.0:
		return false
	v["catch"] = c
	v["kind"] = ""
	v["amount"] = 0.0
	return true


static func is_full(v) -> bool:
	return v is Dictionary and float(v.get("amount", 0.0)) >= CAPACITY - 0.001


## A full vessel of core essence (what the bench's core work and the offerings take).
static func full_core(v) -> bool:
	return is_full(v) and is_core(v) and Secret.is_kind(String(v.get("kind", "")))


static func fill(v) -> float:
	return clampf(float(v.get("amount", 0.0)) / CAPACITY, 0.0, 1.0) if v is Dictionary else 0.0


## The colour of what it holds (the glass's own when empty).
static func color(v) -> Color:
	var k := String(v.get("kind", "")) if v is Dictionary else ""
	if fill(v) <= 0.0:
		return GLASS
	if Secret.is_kind(k):
		return Secret.color(k)
	return Essence.color(k) if is_raw_kind(k) else GLASS


## A kind's name as a vessel holds it: "raw Fire", "Making".
static func kind_name(kind: String) -> String:
	if is_raw_kind(kind):
		return TEXT["raw_name"] % Essence.display(kind)
	return Secret.display(kind)


static func title() -> String:
	return String(Items.ITEMS[ID]["name"])


## "empty, for raw essence", "12 of 30 Unmaking", "full of raw Fire".
static func state_text(v) -> String:
	if fill(v) <= 0.0:
		return TEXT["empty_raw"] if is_raw(v) else TEXT["empty_core"]
	if is_full(v):
		return TEXT["full_of"] % kind_name(v["kind"])
	return TEXT["part"] % [int(floor(float(v["amount"]))), int(CAPACITY), kind_name(v["kind"])]


## What it catches, in a few words ("core essence", "raw essence").
static func catch_word(v) -> String:
	return TEXT["raw_word"] if is_raw(v) else TEXT["core_word"]


## Its card's line on what it catches.
static func catch_line(v) -> String:
	return TEXT["catches_raw"] % int(round(float(RAW["share"]) * 100.0)) if is_raw(v) else TEXT["catches_core"]


## A vessel as a short text (for a slot's id): "kind:amount:catch".
static func code(v) -> String:
	return "%s:%s:%s" % [String(v.get("kind", "")), str(snappedf(float(v.get("amount", 0.0)), 0.01)), catch_of(v)]


static func decode(c: String) -> Dictionary:
	return make(c.get_slice(":", 0), float(c.get_slice(":", 1)) if c.get_slice_count(":") > 1 else 0.0, c.get_slice(":", 2) if c.get_slice_count(":") > 2 else "")


# --- on the belt ---------------------------------------------------------------------

## The climber whose belt the item icon shows (set whenever one is touched).
static var _watched: WeakRef = null


static func watch(p) -> void:
	if p != null:
		_watched = weakref(p)


## The vessel on a climber's belt ({} if none). Edit it in place.
static func carried(p) -> Dictionary:
	if p == null or not ("vessel" in p) or p.item_count(ID) <= 0:
		return {}
	if not (p.vessel is Dictionary) or p.vessel.is_empty():
		p.vessel = make()
	return p.vessel


## A full vessel of core essence on the belt (what a Maker's offering takes).
static func full_on_belt(p) -> bool:
	return full_core(carried(p))


## Puts a vessel (`v`, empty if none) on the belt. False if the belt has no
## room. An empty one with nothing said catches what suits the climber
## (default_catch).
static func give(main, v := {}) -> bool:
	var p = main.player
	if p == null or p.item_room(ID) != "":
		return false
	p.add_item(ID)
	p.vessel = norm(v)
	if not v.has("catch") and fill(p.vessel) <= 0.0:
		p.vessel["catch"] = default_catch(main.profile)
	p.vessel.erase("packed")
	watch(p)
	main.tip("vessel")
	if is_full(p.vessel):
		main.tip("vessel_full")
	return true


## Takes the vessel off the belt; returns it ({} if there was none).
static func take(p) -> Dictionary:
	var v := carried(p)
	if v.is_empty():
		return {}
	p.items.erase(ID)
	p.vessel = {}
	if p.item_sel == ID:
		p.item_sel = p.selected_item()
	return v


## The other core essence passing through the climber (main.gd
## pass_through): a vessel on the belt set to catch core essence holds what
## it can. Returns what's left to pass through (all of it without a vessel,
## without a path, for the path's own kind, a vessel catching raw essence, a
## full one or one holding the other kind).
static func capture(main, kind: String, amount: float, from: Vector2) -> float:
	var p = main.player
	if p == null or p.dead or amount <= 0.0:
		return amount
	var path: String = main.profile.path
	if path == "" or kind == path or not Secret.is_kind(kind):
		return amount
	var v := carried(p)
	if v.is_empty() or not is_core(v) or (v["kind"] != "" and v["kind"] != kind):
		return amount
	var took := minf(CAPACITY - float(v["amount"]), amount)
	if took <= 0.001:
		return amount
	watch(p)
	v["kind"] = kind
	v["amount"] = minf(CAPACITY, float(v["amount"]) + took)
	var col := Secret.color(kind)
	var curl := Curl.new()
	curl.target = p
	curl.col = col
	curl.z_index = 10
	main.add_child(curl)
	curl.rise(from, clampi(int(ceil(took)), 5, 14))
	main.notices.feed(TEXT["captured"] % [int(round(took)), Secret.display(kind), int(floor(float(v["amount"]))), int(CAPACITY)], Color(col, 0.95), "essence")
	main.notices.note_essence("vessel:" + kind, took, Secret.display(kind), Color(col, 0.95))
	main.sfx("vessel_fill", 1.0, 0.0, 0.0)
	main.tip("vessel_capture")
	if is_full(v):
		curl.full = true
		main.tip("vessel_full")
	return amount - took


## Raw essence at a stair (pure: the game and tests/progression_model.gd
## both use it): a vessel set to catch raw essence takes RAW "share" of
## `essence`'s amount of its kind (an empty one: the kind there's most of),
## up to full, taking it OUT of `essence` (so it isn't banked). Returns how
## much it took.
static func take_raw(v: Dictionary, essence: Dictionary) -> float:
	if v.is_empty() or not is_raw(v) or is_full(v):
		return 0.0
	var kind := String(v.get("kind", ""))
	if kind == "" or float(v.get("amount", 0.0)) <= 0.0:
		kind = ""
		var most := 0.0
		for k in essence:
			if is_raw_kind(String(k)) and float(essence[k]) > most:
				most = float(essence[k])
				kind = String(k)
	if kind == "" or float(essence.get(kind, 0.0)) <= 0.0:
		return 0.0
	var took := minf(CAPACITY - float(v.get("amount", 0.0)), float(essence[kind]) * clampf(float(RAW["share"]), 0.0, 1.0))
	if took < 0.01:
		return 0.0
	essence[kind] = float(essence[kind]) - took
	v["kind"] = kind
	v["amount"] = minf(CAPACITY, float(v.get("amount", 0.0)) + took)
	return took


## The stair (main.gd _arrive, before the essence is banked): the vessel on
## the belt, set to catch raw essence, takes its share. Returns the lines to show.
static func stair_raw(main) -> Array:
	var p = main.player
	var v := carried(p)
	if v.is_empty() or not is_raw(v):
		return []
	var took := take_raw(v, main.run_essence)
	if took < 0.5:
		return []
	watch(p)
	main.sfx("vessel_fill", 1.1, -2.0, 0.0)
	main.tip("vessel_raw")
	if is_full(v):
		main.tip("vessel_full")
	return [TEXT["raw_caught"] % [int(round(took)), Essence.display(v["kind"]), int(floor(float(v["amount"]))), int(CAPACITY)]]


## Where the vessel hangs on the climber, from its centre: at the hip on
## its off-hand side, a little behind (the sword hand is player.gd's +side).
static func hip(p) -> Vector2:
	var a: Vector2 = p.aim if "aim" in p and p.aim != Vector2.ZERO else Vector2.RIGHT
	return -a * 2.5 - a.orthogonal() * 12.5 + Vector2(0, 2)


## The climber's drawing (player.gd _draw): the vessel at the hip, glowing
## with what it holds.
static func draw_on_climber(p, t: float) -> void:
	watch(p)
	var v := carried(p)
	if v.is_empty() or p.dead:
		return
	if not p.has_meta("vessel_told") and p.main != null:
		p.set_meta("vessel_told", true)  # (however it came: the Entity's first word on it)
		p.main.tip("vessel")
	var at := hip(p)
	var b := Draw.Batch.new()
	var k := fill(v)
	if k > 0.0:
		var col := color(v)
		var pulse := 0.85 + 0.15 * sin(t * (5.0 if is_full(v) else 2.5))
		UI.glow_into(b, at, 8.0 + 4.0 * k, col, (0.5 + 0.7 * k) * pulse)
	icon_into(b, at, 5.2, v)
	b.flush(p)


## The hover lines for a vessel: what it catches, and that it comes home.
static func hud_lines(v) -> Array:
	var first: String = TEXT["hud_raw"] % [int(round(float(RAW["share"]) * 100.0)), int(CAPACITY)] if is_raw(v) else TEXT["hud_core"] % int(CAPACITY)
	return [first, TEXT["hud_home"]]


## The vessel by the health bar while you carry one (hud.gd): its icon and
## a thin gauge. Adds its tooltip to `tips`; returns the rect it covers.
static func hud_into(b, p, at: Vector2, tips: Array) -> Rect2:
	var v := carried(p)
	if v.is_empty():
		return Rect2()
	var col := color(v)
	if fill(v) > 0.0:
		UI.glow_into(b, at, 12.0, col, 0.5 + 0.6 * fill(v))
	icon_into(b, at + Vector2(0, -1), 8.5, v)
	# Its gauge: a slim gilt-framed bar under it.
	UI.gauge_into(b, Rect2(at + Vector2(-9, 13), Vector2(18, 3)), fill(v), col.lightened(0.2), -1.0, Color(), 0)
	var r := Rect2(at - Vector2(11, 11), Vector2(22, 27))
	tips.append([r, TEXT["hud"] % state_text(v), hud_lines(v)])
	return r


## Using it from the belt says what it holds; an empty one switches what it
## catches (core essence or raw), and says so. It's never used up.
static func use(p) -> bool:
	var v := carried(p)
	var said: String
	if fill(v) <= 0.0:
		set_catch(v, "core" if is_raw(v) else "raw")
		said = TEXT["switched"] % catch_word(v)
		if p.main != null:
			p.main.tip("vessel_raw" if is_raw(v) else "vessel")
	else:
		said = TEXT["use"] % [int(floor(float(v["amount"]))), int(CAPACITY), kind_name(v["kind"])]
	p.main.fx_text(p.global_position + Vector2(0, -44), said, color(v).lightened(0.2))
	return false


## The end of a survived climb or a recall (main.gd): the vessel comes home
## to the chest. Returns the line to show ("" without one).
static func bring_home(main) -> String:
	var v := take(main.player)
	if v.is_empty():
		return ""
	main.profile.vessels.append(norm(v))
	main.profile.save()
	return TEXT["home"] % state_text(v)


## A fall (main.gd on_player_died): it's lost with the belt. Lines to show.
static func on_fall(main) -> Array:
	var v := take(main.player)
	if v.is_empty():
		return []
	return [TEXT["lost"] % state_text(v)]


## A vault's full prize (wings.gd vault_choices): very rarely its third card
## is a vessel (never on the first climb, nor if you carry one already).
static func vault_card(main, cards: Array) -> void:
	if main.first_climb or main.player == null or main.player.item_count(ID) > 0 or cards.size() < 3:
		return
	var chance: float = vault_force if vault_force >= 0.0 else VAULT_CHANCE
	if randf() < chance:
		cards[2] = ID


# --- in the chest ----------------------------------------------------------------------

## The index of the vessel packed for the next climb (-1 for none).
static func packed_index(profile) -> int:
	for i in profile.vessels.size():
		if bool(profile.vessels[i].get("packed", false)):
			return i
	return -1


## Packs vessel `i` for the next climb (only one goes up). "" if packed, else why not.
static func pack(profile, player, i: int) -> String:
	if i < 0 or i >= profile.vessels.size():
		return ""
	if packed_index(profile) < 0:
		var kinds := {}
		for k in player.carried():
			kinds[k] = true
		for k in profile.supplies:
			if int(profile.supplies[k]) > 0:
				kinds[k] = true
		if not kinds.has(ID) and kinds.size() >= player.belt_kinds():
			return TEXT["belt_full"]
	for v in profile.vessels:
		v.erase("packed")
	profile.vessels[i]["packed"] = true
	profile.save()
	return ""


static func unpack(profile, i: int) -> void:
	if i >= 0 and i < profile.vessels.size():
		profile.vessels[i].erase("packed")
		profile.save()


## Sets what vessel `i` in the chest catches (only while it's empty). True if set.
static func set_chest_catch(profile, i: int, c: String) -> bool:
	if i < 0 or i >= profile.vessels.size():
		return false
	if not set_catch(profile.vessels[i], c):
		return false
	profile.save()
	return true


## Leaving the train (train.gd pack_up): the packed vessel goes on the belt.
static func pack_up(profile, player) -> void:
	watch(player)
	var i := packed_index(profile)
	if i < 0 or player.item_room(ID) != "":
		return
	var v: Dictionary = profile.vessels[i]
	profile.vessels.remove_at(i)
	player.add_item(ID)
	player.vessel = norm(v)
	player.vessel.erase("packed")


## The indices of the full vessels in the chest: of core essence (`want`
## "core", what the bench's core work and the offerings take), any (""), or
## of one kind (a kind's id: a Noble's contract).
static func full_list(profile, want := "core") -> Array:
	var out: Array = []
	var list = profile.get("vessels") if profile != null else null
	if list is Array:
		for i in list.size():
			var v = list[i]
			if not is_full(v):
				continue
			if want == "core" and not full_core(v):
				continue
			if want != "core" and want != "" and String(v.get("kind", "")) != want:
				continue
			out.append(i)
	return out


static func full_index(profile, want := "core") -> int:
	var l := full_list(profile, want)
	return l[0] if not l.is_empty() else -1


## Gives a full vessel away (the first of core essence, or `i`): an offering,
## the bribe, a Noble's contract. True if one was there.
static func use_full(profile, i := -1) -> bool:
	if i < 0:
		i = full_index(profile)
	if i < 0 or i >= profile.vessels.size() or not is_full(profile.vessels[i]):
		return false
	profile.vessels.remove_at(i)
	return true


## Uses what a full vessel holds (the first of core essence, or `i`): it's
## empty again, catching the same as before, and stays in the chest. True if one was there.
static func spend_full(profile, i := -1) -> bool:
	if i < 0:
		i = full_index(profile)
	if i < 0 or i >= profile.vessels.size() or not is_full(profile.vessels[i]):
		return false
	var v: Dictionary = profile.vessels[i]
	var c := catch_of(v)
	v["kind"] = ""
	v["amount"] = 0.0
	v["catch"] = c
	return true


# --- tinctures from raw essence (the bench's Tinctures counter) --------------------------

## How much raw essence of a kind your vessels in the chest hold.
static func raw_total(profile, kind: String) -> float:
	var n := 0.0
	var list = profile.get("vessels") if profile != null else null
	if list is Array:
		for v in list:
			if is_raw(v) and String(v.get("kind", "")) == kind:
				n += float(v.get("amount", 0.0))
	return n


## How many tinctures of a kind the raw essence in your vessels makes (each
## vessel on its own: what's left in one doesn't join another's).
static func tinctures_in(profile, kind: String) -> int:
	var n := 0
	var per := maxf(1.0, float(RAW["per_tincture"]))
	var list = profile.get("vessels") if profile != null else null
	if list is Array:
		for v in list:
			if is_raw(v) and String(v.get("kind", "")) == kind:
				n += int(floor((float(v.get("amount", 0.0)) + 0.001) / per))
	return n


static func tincture_why(profile, player, id: String) -> String:
	var kind := Flow.tincture_kind(id)
	if kind == "" or not Items.ITEMS.has(id):
		return Bench.TEXT["nothing"]
	if tinctures_in(profile, kind) <= 0:
		return TEXT["tinct_none"] % [int(RAW["per_tincture"]), Essence.display(kind)]
	if player != null and load("res://scripts/train.gd").supply_room(profile, player, id) <= 0:
		return Bench.TEXT["belt_full"]
	return ""


## Makes one tincture of `id`'s kind from raw essence in a vessel in the
## chest (the fullest of that kind), packed for your next climb. A vessel
## left empty stays in the chest, still catching raw essence. "" if made, else why not.
static func make_tincture(profile, player, id: String) -> String:
	var why := tincture_why(profile, player, id)
	if why != "":
		return why
	var kind := Flow.tincture_kind(id)
	var per := maxf(1.0, float(RAW["per_tincture"]))
	var best := -1
	for i in profile.vessels.size():
		var v: Dictionary = profile.vessels[i]
		if is_raw(v) and String(v.get("kind", "")) == kind and float(v["amount"]) + 0.001 >= per:
			if best < 0 or float(v["amount"]) > float(profile.vessels[best]["amount"]):
				best = i
	if best < 0:
		return TEXT["tinct_none"] % [int(per), Essence.display(kind)]
	var v: Dictionary = profile.vessels[best]
	v["amount"] = maxf(0.0, float(v["amount"]) - per)
	if float(v["amount"]) < 0.01:
		v["amount"] = 0.0
		v["kind"] = ""
	load("res://scripts/train.gd").pack_supply(profile, id, {kind: 0})  # (put back, it returns nothing: raw essence can't go back in)
	profile.save()
	return ""


# --- the bench (crafted: by a Rune Artist, or the workshop's for you) -------------------------

## What brewing one costs you: its materials, plus the Rune Artist's premium
## for anyone without the mark.
static func brew_cost(profile) -> Dictionary:
	return Bench.price(profile, BREW)


static func brew_why(profile) -> String:
	return Bench.short_of(profile, brew_cost(profile))


## Brews an empty vessel into the chest. "" if brewed, else why not.
static func brew(profile) -> String:
	var why := brew_why(profile)
	if why != "":
		return why
	Bench.pay(profile, brew_cost(profile))
	profile.vessels.append(make("", 0.0, default_catch(profile)))
	profile.save()
	return ""


## The workshop's Rune Artist's fee for working a full vessel into a piece
## (a Rune Artist works it for nothing more than the vessel's essence).
static func work_fee(profile, ref: String) -> Dictionary:
	var g := Bench.piece(profile, ref)
	return Bench.work_fee(profile, Bench.Train.gear_kind(g)) if not g.is_empty() else {}


static func deep_temper_why(profile, ref: String) -> String:
	var g := Bench.piece(profile, ref)
	if g.is_empty() or not Bench.temperable(g):
		return Bench.TEXT["no_temper"]
	if int(g["rank"]) >= Gear.RANK_CAP:
		return TEXT["deep_top"]
	if int(g["rank"]) < Gear.MAX_RANK:
		return TEXT["deep_only"] % Gear.MAX_RANK
	if full_index(profile) < 0:
		return TEXT["no_full"]
	return Bench.short_of(profile, work_fee(profile, ref))


## Tempers a +3 piece one rank past the limit, using the core essence in a
## full vessel (the vessel stays, empty). "" if done.
static func deep_temper(profile, ref: String) -> String:
	var why := deep_temper_why(profile, ref)
	if why != "":
		return why
	Bench.pay(profile, work_fee(profile, ref))
	var g := Bench.piece(profile, ref)
	g["rank"] = Gear.RANK_CAP
	Bench.put(profile, ref, g)
	spend_full(profile)
	profile.save()
	return ""


## The deep rune for a lasting rune's id ("sharpness" -> "deep_sharpness").
static func deep_id(rune: String) -> String:
	return "deep_" + rune


## The lasting runes that have a deep form (in order).
static func deep_runes() -> Array:
	return Gear.LASTING_RUNES.keys().filter(func(r): return not Gear.LASTING_RUNES[r].get("deep", false) and Gear.LASTING_RUNES.has(deep_id(r)))


static func deep_rune_why(profile, ref: String, rune: String) -> String:
	var g := Bench.piece(profile, ref)
	if g.is_empty() or not Gear.LASTING_RUNES.has(deep_id(rune)):
		return Bench.TEXT["nothing"]
	if String(g.get("rune", "")) == deep_id(rune):
		return TEXT["deep_has"]
	if full_index(profile) < 0:
		return TEXT["no_full"]
	return Bench.short_of(profile, work_fee(profile, ref))


## Inscribes a deep rune (replacing any rune there), using the core essence
## in a full vessel (the vessel stays, empty). "" if done.
static func deep_rune(profile, ref: String, rune: String) -> String:
	var why := deep_rune_why(profile, ref, rune)
	if why != "":
		return why
	Bench.pay(profile, work_fee(profile, ref))
	var g := Bench.piece(profile, ref)
	g["rune"] = deep_id(rune)
	Bench.put(profile, ref, g)
	spend_full(profile)
	profile.save()
	return ""


# --- core runes (gear.gd CORE_RUNES): powered by a full vessel of core essence ----------------

## The core runes a core kind powers ("life": Making's, "unmaking": Unmaking's), in order.
static func core_runes(kind: String) -> Array:
	return Gear.CORE_RUNES.keys().filter(func(r): return String(Gear.CORE_RUNES[r]["core"]) == kind)


## The index of the first full vessel of a core kind in the chest (-1 for none).
static func full_of_kind(profile, kind: String) -> int:
	return full_index(profile, kind) if Secret.is_kind(kind) else -1


static func core_rune_why(profile, ref: String, rune: String) -> String:
	var g := Bench.piece(profile, ref)
	var d: Dictionary = Gear.CORE_RUNES.get(rune, {})
	if g.is_empty() or d.is_empty():
		return Bench.TEXT["nothing"]
	if String(g.get("core", {}).get("id", "")) == rune:
		return TEXT["core_has"]
	if full_of_kind(profile, String(d["core"])) < 0:
		return TEXT["core_none"]
	return Bench.short_of(profile, work_fee(profile, ref))


## Works a core rune into a piece (replacing any core rune there), using the
## full vessel of its core kind (the vessel stays, empty). It lasts CORE
## "floors" floors worn. "" if done.
static func core_rune(profile, ref: String, rune: String) -> String:
	var why := core_rune_why(profile, ref, rune)
	if why != "":
		return why
	Bench.pay(profile, work_fee(profile, ref))
	var g := Bench.piece(profile, ref)
	g["core"] = {"id": rune, "left": int(CORE["floors"])}
	Bench.put(profile, ref, g)
	spend_full(profile, full_of_kind(profile, String(Gear.CORE_RUNES[rune]["core"])))
	profile.save()
	return ""


## A stair (main.gd _arrive): every worn piece's core rune counts a floor
## down; one that reaches 0 fades. An heirloom's own record follows its worn
## copy (its count carries over to the next climb). Returns the lines to show.
static func wear_core_runes(main) -> Array:
	var p = main.player
	if p == null or not ("gear" in p):
		return []
	var lines: Array = []
	var changed := false
	for slot in p.gear.keys():
		var g = p.gear[slot]
		if not (g is Dictionary) or not (g.get("core") is Dictionary):
			continue
		var before: Dictionary = g.duplicate(true)
		var c: Dictionary = g["core"]
		c["left"] = int(c.get("left", 0)) - 1
		var rune := String(c.get("id", ""))
		if int(c["left"]) <= 0:
			g.erase("core")
			changed = true
			lines.append(TEXT["core_faded"] % [String(Gear.CORE_RUNES.get(rune, {}).get("name", rune)), Gear.display(g).to_lower()])
		_sync_heirloom(main.profile, String(slot), before, g)
	if changed:
		p.refresh_gear()
	return lines


## Writes a worn heirloom copy's core rune back to the heirloom it came from.
static func _sync_heirloom(profile, slot: String, before: Dictionary, now: Dictionary) -> void:
	if profile == null:
		return
	var hs: String = Gear.heirloom_slot_for_carry(slot)
	if hs == "" or not profile.heirlooms.has(hs):
		return
	var list := Gear.heirloom_pieces(profile.heirlooms, hs)
	for i in list.size():
		var h: Dictionary = list[i]
		if Gear.same(h, before) and String(h.get("core", {}).get("id", "")) == String(before.get("core", {}).get("id", "")) and int(h.get("core", {}).get("left", 0)) == int(before.get("core", {}).get("left", 0)):
			if now.has("core"):
				h["core"] = now["core"].duplicate()
			else:
				h.erase("core")
			if hs == "rings":
				profile.heirlooms[hs] = list
			else:
				profile.heirlooms[hs] = h
			return


# --- drawing -------------------------------------------------------------------------------

## The vessel's icon, drawn in code, centred on `c` (about 2*s across): a
## round glass belly bound in brass bands, a brass collar and a sealed domed
## cap. What it holds fills the belly in its colour (Making green, Unmaking
## violet, raw essence its kind's); a full one glows and glints.
static func draw_icon(ci: CanvasItem, c: Vector2, s: float, v, alpha := 1.0) -> void:
	var b := Draw.Batch.new()
	icon_into(b, c, s, v)
	if alpha < 0.999:
		for i in b.cols.size():
			b.cols[i].a *= alpha
	b.flush(ci)


## The belt's vessel (items.gd icon_into hands "vessel" here): the watched
## climber's, else an empty one.
static func belt_into(b, c: Vector2, s: float) -> void:
	var p = _watched.get_ref() if _watched != null else null
	icon_into(b, c, s, carried(p) if p != null and is_instance_valid(p) else make())


static func icon_into(b, c: Vector2, s: float, v) -> void:
	s = Art.size_step(s)
	var k := snappedf(fill(v), 0.02)
	var key := "vessel|%s|%.2f|%.2f|%s" % [String(v.get("kind", "")) if v is Dictionary else "", k, s, is_full(v)]
	Art.cached(b, key, c, func(nb): _icon_art(nb, s, v, k))


## The vessel's icon around (0, 0) (icon_art.gd's style).
static func _icon_art(b, s: float, v, k: float) -> void:
	var u := Art.unit(s)
	var col := color(v)
	var full := is_full(v)
	var bc := Vector2(0, 2.6) * u
	var r := 6.4 * u
	if full:
		Art.soft(b, bc, r * 1.9, Color(col, 0.5))
	# The glass belly, filled to `k` (from the bottom).
	var belly := Art.oval(bc, Vector2(r, r), 0.0, 32)
	Art.glass(b, belly, s, col, bc.y + r - 2.0 * r * k if k > 0.0 else INF, 0.8 if full else 0.0)
	# Brass bands: two straps over the belly and one round it.
	for sx in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 13:
			var a := lerpf(-PI * 0.42, PI * 0.42, i / 12.0)
			pts.append(bc + Vector2(sx * r * 0.5 * cos(a), r * 0.98 * sin(a)))
		for i in 12:
			b.line(pts[i], pts[i + 1], Art.INK, maxf(1.4 * u, 1.1) + Art.ol(s))
		for i in 12:
			b.line(pts[i], pts[i + 1], BRASS.darkened(0.1), maxf(0.8 * u, 0.7))
	Art.rod(b, bc + Vector2(-r + 0.2 * u, 0.6 * u), bc + Vector2(r - 0.2 * u, 0.6 * u), 1.2 * u, BRASS, s, "gold")
	b.circle(bc + Vector2(0, 0.6) * u, 1.0 * u, BRASS.lightened(0.35), 12)
	Art.shine(b, bc + Vector2(-3.1, -2.7) * u, 0.9 * u, 1.9 * u, -0.6, 0.55)
	# The brass collar and the sealed, domed cap with its knob.
	Art.shape(b, Art.rrect(Rect2(Vector2(-2.4, -6.2) * u, Vector2(4.8, 2.8) * u), 0.6 * u, 3), BRASS, s, "gold", Art.NO_RIM)
	var dome := PackedVector2Array()
	for i in 13:
		dome.append(Vector2(0, -6.2) * u + Vector2.from_angle(lerpf(PI, TAU, i / 12.0)) * Vector2(3.3, 2.4) * u)
	Art.shape(b, dome, BRASS, s, "gold")
	Art.orb(b, Vector2(0, -9.0) * u, 1.15 * u, BRASS.lightened(0.1), s, "gold")
	if full:
		Art.spark(b, bc + Vector2(2.4, -1.6) * u, 2.4 * u, Color(1, 1, 1, 0.9))


# --- the capture: the passing streak curls into the vessel ----------------------------------

## The other essence rising from a great foe, streaking at the climber as it
## would to pass through, then curling round the vessel at the hip and
## sinking into it. Frees itself when done.
class Curl extends Node2D:
	const Draw := preload("res://scripts/draw_util.gd")
	const RADIUS := 22.0  # where the streak starts to curl
	const TIME := 0.5  # seconds to spiral in
	var target  # the climber
	var col := Color.WHITE
	var full := false  # the vessel filled: a bright ring when it lands
	var motes: Array = []
	var flash := 0.0
	var landed := false

	func rise(from: Vector2, n: int) -> void:
		for i in n:
			var d := (Vector2.UP + Vector2.from_angle(randf() * TAU) * 0.6).normalized()
			motes.append({"pos": from + Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0)), "vel": d * randf_range(90.0, 170.0),
				"age": 0.0, "delay": randf_range(0.35, 0.7), "curl": -1.0, "ang": 0.0, "trail": [], "spin": 1.0 if randf() < 0.5 else -1.0})

	func _hip() -> Vector2:
		if target == null or not is_instance_valid(target):
			return global_position
		return target.global_position + load("res://scripts/vessel.gd").hip(target)

	func _process(delta: float) -> void:
		var hip := _hip()
		var live := 0
		for m in motes:
			if m.get("done", false):
				continue
			live += 1
			m["age"] += delta
			if m["curl"] < 0.0:
				if m["age"] > m["delay"]:
					var to: Vector2 = hip - m["pos"]
					if to.length() < RADIUS:
						m["curl"] = 0.0
						m["ang"] = (m["pos"] - hip).angle()
					else:
						m["vel"] = m["vel"].lerp(to.normalized() * 520.0, minf(1.0, 6.5 * delta))
				else:
					m["vel"] *= 0.9
				m["pos"] += m["vel"] * delta
				if m["age"] > 3.0:
					m["done"] = true
			else:
				m["curl"] += delta
				var k: float = clampf(m["curl"] / TIME, 0.0, 1.0)
				m["ang"] += delta * (10.0 + 10.0 * k) * m["spin"]
				m["pos"] = hip + Vector2.from_angle(m["ang"]) * RADIUS * (1.0 - k) * (1.0 - 0.25 * k)
				if k >= 1.0:
					m["done"] = true
					flash = 0.35 if not full else 0.6
					landed = true
			var tr: Array = m["trail"]
			tr.append(m["pos"])
			if tr.size() > 7:
				tr.pop_front()
		flash = maxf(0.0, flash - delta)
		if live == 0 and flash <= 0.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var b := Draw.Batch.new()
		for m in motes:
			if m.get("done", false):
				continue
			var tr: Array = m["trail"]
			for i in range(1, tr.size()):
				var a := float(i) / tr.size()
				b.line(tr[i - 1], tr[i], Color(col, 0.4 * a), 3.5 * a + 0.5)
			b.circle(m["pos"], 6.5, Color(col, 0.18), 14)
			b.circle(m["pos"], 2.8, Color(col.lightened(0.5), 1.0), 10)
		if flash > 0.0:
			var hip := _hip()
			var k := flash / (0.6 if full else 0.35)
			b.circle(hip, 5.0 + (1.0 - k) * (16.0 if full else 8.0), Color(col.lightened(0.3), 0.35 * k), 18)
			b.circle(hip, 3.0, Color(1, 1, 1, 0.8 * k), 10)
		b.flush(self)
