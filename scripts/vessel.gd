extends RefCounted
## The vessel (name to come; items.gd ITEMS["vessel"] holds its name): a
## sealed glass vessel bound in brass. Once the climber has a path (secret.gd),
## the other secret essence rises from great foes and passes through them;
## a vessel on the belt CAPTURES it instead (main.gd pass_through), up to
## CAPACITY. It holds one kind: the first it took.
##
## What it holds is unbanked: it sits on the belt like other items (one
## kind of item, never stacked), and a fall loses it with the belt. Survive
## the climb or read a recall scroll and it comes home, filled or not, into
## your chest on the train (profile.gd vessels); it is never broken into
## crystals like the rest of the belt (main.gd break_belt skips it). From the
## chest it can be packed onto your belt for the next climb, to keep filling.
##
## Where one comes from: a Rune Artist brews it at the workshop's bench
## (BREW, expensive), and very rarely a vault offers one (VAULT_CHANCE).
##
## What a FULL vessel is for (the owner hasn't chosen, so all three are
## choices the player makes; vessel_page.gd puts them on the train):
##   trade     the outfitter buys it (TRADE): a crystal of one kind of your
##             choice, or a smaller amount of every kind (more in all)
##   bench     a Rune Artist works it into a piece: tempered one rank past
##             the limit (+3 to +4, gear.gd RANK_CAP), or a deep rune, a
##             lasting rune at the Inscribe spell's full strength (gear.gd
##             LASTING_RUNES "deep_*")
##   offering  to a Maker when pleading for a change of path (makers.gd
##             PLEA_ODDS "vessel": carried up on the belt), or as the
##             Developer's bribe (secret_bonds.gd BRIBE "vessel")
##
## A vessel is {"kind": "" (empty) or a secret kind, "amount": float}; in the
## chest it may also carry "packed": true (it goes up on your next climb).
## Every word and number is here (or in items.gd's entry), so it's easy to
## rename or retune.

const Items := preload("res://scripts/items.gd")
const Secret := preload("res://scripts/secret.gd")
const Essence := preload("res://scripts/essence.gd")
const Gear := preload("res://scripts/gear.gd")
const Bench := preload("res://scripts/bench.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Palette := preload("res://scripts/palette.gd")
const UI := preload("res://scripts/ui.gd")

## Its item id on the belt (items.gd ITEMS).
const ID := "vessel"
## How much secret essence one holds.
const CAPACITY := 30.0
## The chance a full vault prize offers a vessel as its third card.
const VAULT_CHANCE := 0.04
## Brewing one at the bench (a Rune Artist only).
const BREW := {"iron": 60, "water": 45, "air": 45}
## The outfitter's trade for a full vessel: `one` of a single kind you
## choose, or `each` of every kind.
const TRADE := {"one": 120, "each": 30}
## Tests and dev: >= 0 replaces VAULT_CHANCE.
static var vault_force := -1.0

const BRASS := Color(0.86, 0.64, 0.3)
const GLASS := Color(0.62, 0.66, 0.74)

const TEXT := {
	"captured": "+%d %s into the vessel  (%d / %d)",
	"full": "The vessel is full",
	"use_empty": "The vessel waits, empty",
	"use": "The vessel holds %d / %d %s",
	"empty": "empty",
	"part": "%d of %d %s",
	"full_of": "full of %s",
	"home": "Your vessel comes home to your chest: %s",
	"lost": "Lost with your belt: your vessel (%s)",
	"hud": "Vessel: %s",
	"hud_lines": ["It holds the secret essence that isn't your path, up to %d.", "Survive or recall and it comes home to your chest; fall and it's lost."],
	"desc_state": "It holds: %s",
	# The train (vessel_page.gd)
	"shelf": "Vessels  ·  %d",
	"in_chest": "In your chest: safe between climbs.",
	"packed": "Packed for your next climb: it goes on your belt (one kind of item) and keeps filling. Fall, and it's lost with your belt.",
	"packed_tag": "packed",
	"going": "a vessel (%s)",
	"take": "Take it on your next climb",
	"leave": "Leave it in the chest",
	"took": "Packed for your next climb: the vessel",
	"left": "Back in the chest: the vessel",
	"belt_full": "your belt can't hold another kind",
	"uses": "A full vessel can be traded to the outfitter (the store's Sell), worked into a piece by a Rune Artist (the bench's Vessel counter), offered to the Maker of Marks as the Developer's bribe, or carried up and offered to a Maker when you plead for a change of path.",
	"trade_title": "The outfitter will trade for it",
	"trade_one": "%d %s",
	"trade_mixed": "%d of every kind (%d in all)",
	"trade_ask": "{again}: %s",
	"trade_full_only": "The outfitter only trades for a full vessel.",
	"traded": "Traded: your vessel for %s",
	# The bench
	"brew_title": "Brew a vessel",
	"brew_desc": "A sealed glass vessel bound in brass. It goes in your chest, empty: pack it for a climb and it fills with the secret essence that isn't your path.",
	"brew": "Brew a vessel",
	"brewed": "Brewed: a vessel, in your chest",
	"full_count": "Full vessels in your chest: %d",
	"no_full": "no full vessel in your chest",
	"deep_temper_head": "Past the limit: one rank more (uses up a full vessel).",
	"deep_temper": "Temper to +%d",
	"deep_temper_ask": "{again}: temper to +%d",
	"deep_only": "Only a piece tempered to +%d can go further",
	"deep_top": "Tempered past the limit already",
	"deep_rune_head": "A deep rune, twice a lasting rune's strength (uses up a full vessel):",
	"deep_rune": "%s: %s",
	"deep_rune_ask": "{again}: %s",
	"deep_has": "it already carries that deep rune",
	"deep_tempered": "Tempered past the limit: %s",
	"deep_inscribed": "Inscribed: %s on %s",
	"deep_note": "With a full vessel a Rune Artist can go past the bench's limits: one rank past +%d, or a deep rune at the Inscribe spell's full strength (twice a lasting rune's).",
	# Dev tools
	"dev": "Vessel",
	"dev_empty": "Give an empty vessel",
	"dev_full": "Give a full vessel",
	"dev_given": "A vessel: %s",
}


# --- records -------------------------------------------------------------------------

static func make(kind := "", amount := 0.0) -> Dictionary:
	if not Secret.is_kind(kind) or amount <= 0.0:
		return {"kind": "", "amount": 0.0}
	return {"kind": kind, "amount": clampf(amount, 0.0, CAPACITY)}


## A vessel from a save (anything broken reads as an empty vessel).
static func norm(v) -> Dictionary:
	if not (v is Dictionary):
		return make()
	var out := make(String(v.get("kind", "")), float(v.get("amount", 0.0)))
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


static func is_full(v) -> bool:
	return v is Dictionary and float(v.get("amount", 0.0)) >= CAPACITY - 0.001


static func fill(v) -> float:
	return clampf(float(v.get("amount", 0.0)) / CAPACITY, 0.0, 1.0) if v is Dictionary else 0.0


## The colour of what it holds (the glass's own when empty).
static func color(v) -> Color:
	var k := String(v.get("kind", "")) if v is Dictionary else ""
	return Secret.color(k) if Secret.is_kind(k) and float(v.get("amount", 0.0)) > 0.0 else GLASS


static func title() -> String:
	return String(Items.ITEMS[ID]["name"])


## "empty", "12 of 30 Unmaking", "full of Life".
static func state_text(v) -> String:
	if fill(v) <= 0.0:
		return TEXT["empty"]
	if is_full(v):
		return TEXT["full_of"] % Secret.display(v["kind"])
	return TEXT["part"] % [int(floor(float(v["amount"]))), int(CAPACITY), Secret.display(v["kind"])]


## A vessel as a short text (for a slot's id): "kind:amount".
static func code(v) -> String:
	return "%s:%s" % [String(v.get("kind", "")), str(snappedf(float(v.get("amount", 0.0)), 0.01))]


static func decode(c: String) -> Dictionary:
	return make(c.get_slice(":", 0), float(c.get_slice(":", 1)) if c.get_slice_count(":") > 1 else 0.0)


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


static func full_on_belt(p) -> bool:
	return is_full(carried(p))


## Puts a vessel (`v`, empty if none) on the belt. False if the belt has no room.
static func give(main, v := {}) -> bool:
	var p = main.player
	if p == null or p.item_room(ID) != "":
		return false
	p.add_item(ID)
	p.vessel = norm(v)
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


## The other secret essence passing through the climber (main.gd
## pass_through): the vessel on the belt holds what it can. Returns what's
## left to pass through (all of it without a vessel, without a path, for the
## path's own kind, a full vessel or one holding the other kind).
static func capture(main, kind: String, amount: float, from: Vector2) -> float:
	var p = main.player
	if p == null or p.dead or amount <= 0.0:
		return amount
	var path: String = main.profile.path
	if path == "" or kind == path or not Secret.is_kind(kind):
		return amount
	var v := carried(p)
	if v.is_empty() or (v["kind"] != "" and v["kind"] != kind):
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
	main.fx_text(p.global_position + Vector2(0, -58), TEXT["captured"] % [int(round(took)), Secret.display(kind), int(floor(float(v["amount"]))), int(CAPACITY)], Color(col, 0.95))
	main.sfx("glint", 1.25, -6.0, 0.0)
	main.tip("vessel_capture")
	if is_full(v):
		curl.full = true
		main.tip("vessel_full")
	return amount - took


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
	var bar := Rect2(at + Vector2(-8, 12), Vector2(16, 3))
	b.rect(bar.grow(1.0), UI.OUTLINE)
	b.rect(Rect2(bar.position, Vector2(bar.size.x * fill(v), bar.size.y)), col.lightened(0.2))
	var r := Rect2(at - Vector2(11, 11), Vector2(22, 27))
	var lines: Array = TEXT["hud_lines"].duplicate()
	lines[0] = String(lines[0]) % int(CAPACITY)
	tips.append([r, TEXT["hud"] % state_text(v), lines])
	return r


## Using it from the belt does nothing but say what it holds (it isn't used up).
static func use(p) -> bool:
	var v := carried(p)
	var said: String = TEXT["use_empty"] if fill(v) <= 0.0 else TEXT["use"] % [int(floor(float(v["amount"]))), int(CAPACITY), Secret.display(v["kind"])]
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


## The indices of the full vessels in the chest.
static func full_list(profile) -> Array:
	var out: Array = []
	var list = profile.get("vessels") if profile != null else null
	if list is Array:
		for i in list.size():
			if is_full(list[i]):
				out.append(i)
	return out


static func full_index(profile) -> int:
	var l := full_list(profile)
	return l[0] if not l.is_empty() else -1


## Uses up a full vessel from the chest (the first, or `i`). True if one was there.
static func use_full(profile, i := -1) -> bool:
	if i < 0:
		i = full_index(profile)
	if i < 0 or i >= profile.vessels.size() or not is_full(profile.vessels[i]):
		return false
	profile.vessels.remove_at(i)
	return true


# --- the store's trade ---------------------------------------------------------------------

## What trading a full vessel gives: {kind: amount} for `choice` (an essence
## kind, or "mixed" for every kind).
static func trade_value(choice: String) -> Dictionary:
	if choice == "mixed":
		var out := {}
		for k in Essence.KINDS:
			out[k] = int(TRADE["each"])
		return out
	if Essence.KINDS.has(choice):
		return {choice: int(TRADE["one"])}
	return {}


## Trades full vessel `i` to the outfitter. Returns what it gave ("120 Fire"),
## or "" if it couldn't.
static func trade(profile, i: int, choice: String) -> String:
	var got := trade_value(choice)
	if got.is_empty() or i < 0 or i >= profile.vessels.size() or not is_full(profile.vessels[i]):
		return ""
	profile.vessels.remove_at(i)
	var bits: Array = []
	for k in got:
		profile.add_crystal(k, float(got[k]))
		bits.append("%d %s" % [int(got[k]), Essence.display(k)])
	profile.save()
	return ", ".join(bits) if choice != "mixed" else TEXT["trade_mixed"] % [int(TRADE["each"]), int(TRADE["each"]) * Essence.KINDS.size()]


# --- the bench (a Rune Artist) ---------------------------------------------------------------

static func brew_why(profile) -> String:
	var lock := Bench.locked(profile, "vessel")
	if lock != "":
		return lock
	return Bench.short_of(profile, BREW)


## Brews an empty vessel into the chest. "" if brewed, else why not.
static func brew(profile) -> String:
	var why := brew_why(profile)
	if why != "":
		return why
	Bench.pay(profile, BREW)
	profile.vessels.append(make())
	profile.save()
	return ""


static func deep_temper_why(profile, ref: String) -> String:
	var lock := Bench.locked(profile, "vessel")
	if lock != "":
		return lock
	var g := Bench.piece(profile, ref)
	if g.is_empty() or not Bench.temperable(g):
		return Bench.TEXT["no_temper"]
	if int(g["rank"]) >= Gear.RANK_CAP:
		return TEXT["deep_top"]
	if int(g["rank"]) < Gear.MAX_RANK:
		return TEXT["deep_only"] % Gear.MAX_RANK
	if full_index(profile) < 0:
		return TEXT["no_full"]
	return ""


## Tempers a +3 piece one rank past the limit, using up a full vessel. "" if done.
static func deep_temper(profile, ref: String) -> String:
	var why := deep_temper_why(profile, ref)
	if why != "":
		return why
	var g := Bench.piece(profile, ref)
	g["rank"] = Gear.RANK_CAP
	Bench.put(profile, ref, g)
	use_full(profile)
	profile.save()
	return ""


## The deep rune for a lasting rune's id ("sharpness" -> "deep_sharpness").
static func deep_id(rune: String) -> String:
	return "deep_" + rune


## The lasting runes that have a deep form (in order).
static func deep_runes() -> Array:
	return Gear.LASTING_RUNES.keys().filter(func(r): return not Gear.LASTING_RUNES[r].get("deep", false) and Gear.LASTING_RUNES.has(deep_id(r)))


static func deep_rune_why(profile, ref: String, rune: String) -> String:
	var lock := Bench.locked(profile, "vessel")
	if lock != "":
		return lock
	var g := Bench.piece(profile, ref)
	if g.is_empty() or not Gear.LASTING_RUNES.has(deep_id(rune)):
		return Bench.TEXT["nothing"]
	if String(g.get("rune", "")) == deep_id(rune):
		return TEXT["deep_has"]
	if full_index(profile) < 0:
		return TEXT["no_full"]
	return ""


## Inscribes a deep rune (replacing any rune there), using up a full vessel. "" if done.
static func deep_rune(profile, ref: String, rune: String) -> String:
	var why := deep_rune_why(profile, ref, rune)
	if why != "":
		return why
	var g := Bench.piece(profile, ref)
	g["rune"] = deep_id(rune)
	Bench.put(profile, ref, g)
	use_full(profile)
	profile.save()
	return ""


# --- drawing -------------------------------------------------------------------------------

## The vessel's icon, drawn in code, centred on `c` (about 2*s across): a
## round glass belly bound in brass bands, a brass collar and a sealed domed
## cap. What it holds fills the belly in its colour (Life green, Unmaking
## violet); a full one glows and glints.
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
	var u := s / 10.0
	var ol := clampf(u * 1.1, 0.8, 1.6)
	var k := fill(v)
	var col := color(v)
	var bc := c + Vector2(0, 2.4) * u
	var r := 6.6 * u
	if is_full(v):
		for i in 3:
			b.dot(bc, r + (4.0 - i * 1.2) * u, Color(col, 0.08))
	# The glass belly.
	b.dot(bc, r + ol + 0.8, Color(Palette.OUTLINE, Draw.FEATHER_ALPHA))
	b.dot(bc, r + ol, Palette.OUTLINE)
	b.dot(bc, r, GLASS.darkened(0.5))
	b.dot(bc + Vector2(0.6, 0.8) * u, r * 0.8, GLASS.darkened(0.62))  # (the far side of the glass, darker)
	if k > 0.0:
		var h := r * (1.0 - 2.0 * k)  # the surface, from the centre (down is +)
		var inner := r - 0.6 * u
		if k >= 0.999:
			b.dot(bc, inner, col.darkened(0.15))
			b.dot(bc + Vector2(-0.8, -0.6) * u, inner * 0.7, col)
		else:
			var a0 := asin(clampf(h / inner, -1.0, 1.0))
			var liquid := PackedVector2Array()
			for i in 17:
				liquid.append(bc + Vector2.from_angle(lerpf(a0, PI - a0, i / 16.0)) * inner)
			b.polygon(liquid, col.darkened(0.15))
			if k > 0.25:
				var lit := PackedVector2Array()
				for i in 13:
					lit.append(bc + Vector2(-0.8, 0.2) * u + Vector2.from_angle(lerpf(a0 + 0.3, PI - a0 - 0.5, i / 12.0)) * (inner - 1.8 * u))
				b.polygon(lit, col)
			b.line(liquid[0], liquid[16], col.lightened(0.5), maxf(0.7, 0.7 * u))
	# Brass bands: one round the belly, two straps over it.
	var band := Color(BRASS.darkened(0.15))
	for sx in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 9:
			var a := lerpf(-PI * 0.42, PI * 0.42, i / 8.0)
			pts.append(bc + Vector2(sx * r * 0.5 * cos(a), r * 0.98 * sin(a)))
		b.path(pts, Palette.OUTLINE, maxf(1.8 * u, 1.2))
		b.path(pts, band, maxf(0.9 * u, 0.7))
	b.line(bc + Vector2(-r - 0.2 * u, 0.6 * u), bc + Vector2(r + 0.2 * u, 0.6 * u), Palette.OUTLINE, 2.6 * u)
	b.line(bc + Vector2(-r + 0.4 * u, 0.6 * u), bc + Vector2(r - 0.4 * u, 0.6 * u), BRASS, 1.4 * u)
	b.dot(bc + Vector2(0, 0.6) * u, 1.1 * u, BRASS.lightened(0.35))
	# The glass's shine.
	b.polygon(Items.UIShape.oval(bc + Vector2(-3.2, -2.8) * u, Vector2(1.0, 2.0) * u, -0.6), Color(1, 1, 1, 0.55))
	# The brass collar and the sealed, domed cap with its knob.
	var collar := Rect2(c + Vector2(-2.6, -6.4) * u, Vector2(5.2, 3.0) * u)
	b.rect(collar.grow(ol), Palette.OUTLINE)
	b.rect(collar, BRASS.darkened(0.2))
	b.rect(Rect2(collar.position, Vector2(collar.size.x, 1.0 * u)), BRASS.lightened(0.25))
	var dome := PackedVector2Array()
	for i in 9:
		dome.append(c + Vector2(0, -6.4) * u + Vector2.from_angle(lerpf(PI, TAU, i / 8.0)) * Vector2(3.6, 2.6) * u)
	b.poly(dome, BRASS, ol)
	b.dot(c + Vector2(-1.0, -7.6) * u, 0.8 * u, BRASS.lightened(0.45))
	b.dot(c + Vector2(0, -9.4) * u, 1.3 * u + ol, Palette.OUTLINE)
	b.dot(c + Vector2(0, -9.4) * u, 1.3 * u, BRASS.lightened(0.1))
	if is_full(v):
		Items._spark(b, bc + Vector2(2.4, -1.6) * u, 2.6 * u, Color(1, 1, 1, 0.9))


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
