extends RefCounted
## The Entity's explanations on the train: what a button does or where it
## goes, said in a small bubble beside it when you hover it (mouse), move
## onto it (keys, controller) or press and hold it (touch). entity_helper.gd
## shows them; the words are here, in plain data (and in the Data editor:
## "The Entity's words").
##
## HELP is keyed by a stable id worked out from the button's own tags (its
## "meta": key_for below), never by its words, so a button can be renamed
## and keep its explanation:
##   rail:<item>          a rail entry (rail:engine, rail:store, rail:gym...)
##   slot:<kind>          a slot (slot:pack, slot:chest, slot:worn, slot:outfit,
##                        slot:supply, slot:bench:item...); "slot:pack:empty"
##                        for an empty one
##   buy, buy:chest, sell, equip, move:pack, put_back, brew, depart, tower...
##   bench_tab:<counter>, setting:<setting>, tab:<tab>, pick:<kind>...
## A key with no entry of its own falls back to the part before its last ":"
## ("bench_tab:vessel" -> "bench_tab"). A button with no entry at all says
## its own words (tests/parts/entity_train.gd lists any train button that
## has none, so none is forgotten).
##
## In the words, {name} is filled in from the game as it is now (facts
## below): {piece} (the piece or item), {desc} (what it does, from its own
## card), {price}, {versus} (better or worse than what you'd wear), {slot},
## {from} (where a worn piece comes from), {tower}, {essence}, {best},
## {beast}, {station}, {count}, {car}, {shelf}, {heard}, {total}, {locked}
## (" Only a Rune Artist can." or nothing), {choice}, {words} (the
## button's own words). A blank left unfilled is dropped.
##
## Never the story here: these are plain facts about the buttons.

const Train := preload("res://scripts/train.gd")
const Bench := preload("res://scripts/bench.gd")
const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")
const Essence := preload("res://scripts/essence.gd")
const Towers := preload("res://scripts/towers.gd")
const Stations := preload("res://scripts/stations.gd")
const Renown := preload("res://scripts/renown.gd")
const Boons := preload("res://scripts/boons.gd")
const Entity := preload("res://scripts/entity.gd")
const Guide := preload("res://scripts/guide.gd")
const StorageView := preload("res://scripts/storage_view.gd")

static var HELP := {
	# --- the rail -----------------------------------------------------------------------
	"rail:climber": "Your climber's book: abilities, the tree, marks, essence and your record.",
	"rail:engine": "Opens the Engine: choose a tower, then pull the lever to depart.",
	"rail:store": "Opens the Outfitter's Car: buy supplies and gear, and sell what you found.",
	"rail:personal": "Opens Your Car: what you'll wear, your pack and your stash.",
	"rail:workshop": "Opens the Workshop: brew supplies, break pieces down, work on gear.",
	"rail:library": "Opens the Library: everything I've told you, kept on shelves.",
	"rail:settings": "Opens the Settings & Controls Car: sound, screen, every key, and Start over.",
	"rail:dev": "Dev Tools: switches for testing. Not part of the game.",
	"rail:exit": "Back to the title screen. Your climber is saved as they are.",
	"rail:quit": "Closes the game. Your climber is saved as they are.",
	"rail:leave_station": "Back to the train. The station stays where it is.",
	"rail:gym": "The Training Gym: drills with a goal and a medal.",
	"rail:arena": "The Tournament Arena: bouts for renown and crystals. A loss costs only the fee.",
	"rail:challenges": "Challenges: one-off fights with a twist. Each pays the first time you win it.",
	"rail:board": "The Renown Board: your renown, your rank, and titles to wear.",
	"rail:shrine": "The Boon Shrine: boons that go with you on every climb.",
	"rail:resume": "Back to the climb.",
	"rail:inventory": "Your gear, items and heirlooms.",
	# --- the engine -------------------------------------------------------------------------
	"tower": "{Tower}: {essence} essence, and {beast} at the top. {best_line}",
	"depart": "Pull it and the train leaves for {tower}. Your pack and your belt go with you.",
	"board:stations": "Turns the board to the stations: drills, bouts and boons between towers.",
	"board:towers": "Turns the board back to the six towers.",
	"station": "{station}: a stop between towers. Choose it, then pull its lever.",
	"go_station": "Stops the train at {station}.",
	# --- the outfitter's car ------------------------------------------------------------------
	"store_tab:sell": "The outfitter buys what you brought down: pieces from your pack and stash.",
	"store_tab:shop": "Back to the shelves: supplies, the rack and today's piece.",
	"store_filter:rack": "Filters the rack: everything, what beats yours, weapons, armour, cloaks and packs.",
	"store_filter:from": "Where to sell from: pack and stash, only your pack, or only your stash.",
	"store_filter:slot": "Shows only the pieces for one slot.",
	"slot:upgrades": "The outfitter's upgrades: {count} of 5 so far. Renown unlocks the rest.",
	"slot:supply": "{piece}, {price}: {desc}. It goes on your belt for your next climb.",
	"slot:outfit": "{piece} on the rack, {price}. {versus}",
	"slot:outfit:empty": "Sold. The rack fills again after your next climb.",
	"slot:today": "Today's piece: {piece}, {price}. A new one after every climb. {versus}",
	"slot:today:empty": "Today's piece is sold. A new one after your next climb.",
	"slot:order": "{piece}: the outfitter is holding it for you.",
	"buy:supply": "Buys {piece} for {price}. It goes on your belt for your next climb.",
	"buy": "Buys {piece} for {price}, into your pack. It goes up the tower with you.",
	"buy:chest": "Buys {piece} for {price}, into your stash. It stays on the train.",
	"buy:wear": "Buys {piece} for {price} and puts it on at once.",
	"buy:hold": "Asks the outfitter to keep {piece} for you until you come back.",
	"put_back": "Puts one {piece} back on the shelf. What you paid comes back.",
	"sell": "Sells {piece} for {price}. Press it twice.",
	# --- your car, the Loadout and the stash ------------------------------------------------------
	"slot:worn": "{slot}: {piece}. What you start the climb wearing there. {from}",
	"slot:worn:empty": "{slot}: nothing yet. Choose it to see what could go there.",
	"slot:pack": "{piece}, in your pack: it goes up the tower with you. {versus}",
	"slot:pack:empty": "An empty pocket in your pack. Pieces here go up the tower with you.",
	"slot:chest": "{piece}, in your stash: it stays safe on the train. {versus}",
	"slot:chest:empty": "An empty space in your stash ({count}).",
	"slot:belt": "{piece}: packed on your belt for your next climb.",
	"slot:vessel": "A vessel: it catches secret essence on a climb.",
	"open_stash": "Opens the stash: every piece in it ({count}), to sort and filter.",
	"car_page:stash": "Opens the stash: every piece in it ({count}), to sort and filter.",
	"car_page:climber": "Your climber's book: abilities, the tree, marks, essence and your record.",
	"car_page:loadout": "The Loadout: what you'll wear, your pack and your belt, drawn large.",
	"car_page:appearance": "How you look. Looks never change how you play.",
	"car_page:techniques": "Your techniques: what each mark button casts.",
	"equip": "Wear {piece}. What it replaces goes back where this came from.",
	"move:chest": "Moves {piece} into your stash. It stays on the train.",
	"move:pack": "Moves {piece} into your pack. It goes up the tower with you.",
	"unequip:pack": "Takes {piece} off, into your pack.",
	"unequip:chest": "Takes {piece} off, into your stash.",
	"tab:loadout": "The Loadout: what you'll wear, your pack and your belt.",
	"tab:stash": "The stash: every piece you keep on the train.",
	"cycler:sort": "Sorts the stash: newest, rarity, slot, essence or price.",
	"cycler:slot": "Shows only the pieces for one slot.",
	"cycler:kind": "Shows only the pieces of one essence.",
	# --- the workshop ---------------------------------------------------------------------------
	"bench_tab:brew": "Brew: supplies for your belt, a little cheaper than the outfitter's.",
	"bench_tab:temper": "Temper: raise a piece's rank, +1 to +3.{locked}",
	"bench_tab:retrait": "Retrait: swap one of a piece's traits.{locked}",
	"bench_tab:join": "Join: two Fine pieces for one slot become one Rare.{locked}",
	"bench_tab:break": "Break down: a piece or a packed item becomes crystals.",
	"bench_tab:inscribe": "Inscribe: a lasting rune on one piece.{locked}",
	"bench_tab:recall": "Recall scroll: bind one to leave a climb safely.{locked}",
	"bench_tab:vessel": "Vessel: brew one, or work a full one into a piece.{locked}",
	"bench_tab": "{counter}.{locked}",
	"bench_drawer:essence": "The essence bench: build your techniques.{locked}",
	"bench_drawer:brew": "Back to the bench's counters.",
	"slot:bench:item": "{piece}, {price} to brew: {desc}.",
	"slot:bench:supply": "{piece}, packed on your belt. It can be broken down for crystals.",
	"slot:bench": "{piece}: {counter} it here.",
	"slot:bench:empty": "Nothing here to work on.",
	"brew": "Brews {piece} for {price}. It goes on your belt.",
	"bench_do:temper": "Raises {piece} a rank. Press it twice.",
	"bench_do:break": "Breaks {piece} down into crystals. Press it twice.",
	"bench_do:vtemper": "Works a full vessel into {piece}: a rank past +3. Press it twice.",
	"bench_do:vrune": "Works a full vessel into {piece}: a deep rune. Press it twice.",
	"retrait": "Swaps the chosen trait for one of this essence. Press it twice.",
	"retrait_pick": "Chooses which trait to swap.",
	"join": "Joins {piece} with this one into a Rare. Press it twice.",
	"inscribe": "Puts this rune on {piece} for good. Press it twice.",
	"vessel_pack": "Packs the vessel for your next climb, or leaves it here.",
	"vessel_trade": "Trades the vessel's essence. Press it twice.",
	"vessel_brew": "Brews an empty vessel.",
	"bench_vial": "A vial of essence for the technique.",
	"bench_mould": "The technique's shape.",
	"bench_fx": "An effect for the technique.",
	"bench_fitting": "A fitting for the technique.",
	"bench_slot": "A mark button for the technique.",
	"bench_save": "Sets the technique in its slot.",
	"bench_name": "The technique's name.",
	"bench_from": "A technique you already have, to change.",
	"bench_draft": "A technique in the works.",
	"tech_slot": "A mark button and the technique it casts.",
	# --- the library ------------------------------------------------------------------------------
	"shelf": "{shelf}: {heard} of {total} heard. It opens on the lectern.",
	"archive": "{archive}: what I said, and a fuller account.",
	"help:replay": "I'll tell you every tip again. The Archive keeps what it has.",
	"help:tips": "My tips on or off. The Archive fills in either way.",
	"setting:tips": "My tips on or off. The Archive fills in either way.",
	# --- settings ------------------------------------------------------------------------------------
	"panel_tab:settings": "Sound, screen, sizes, and my words.",
	"panel_tab:controls": "Every key and every button.",
	"tab:settings": "Sound, screen, sizes, and my words.",
	"tab:controls": "Every key and every button.",
	"setting:ui_size": "Interface size: how big menus and words are. This one: {choice}.",
	"setting:world_zoom": "How close the camera sits in the tower. This one: {choice}.",
	"setting:music": "How loud the music is.",
	"setting:sounds": "How loud everything else is.",
	"setting:shake": "The screen shakes on heavy hits.",
	"setting:help": "Keeps the list of controls on screen while you play (H).",
	"setting:hud_scale": "How big the bars and slots are in play. This one: {choice}.",
	"setting:lighting": "Lighting quality. Lower is kinder to a phone. This one: {choice}.",
	"setting:condense": "How much of what you bank at a stair becomes crystals: {choice}. More money, slower marks.",
	"setting:entity_help": "Me, explaining buttons as you point at them, or hold them on a phone.",
	"setting:padsetup": "Teach the game your controller's buttons.",
	"setting:data": "Change the game's words, numbers and colours.",
	"over": "Starts this climber over: no marks, the first climb again. It asks first.",
	# --- the climber's book --------------------------------------------------------------------------
	"tab:abilities": "Abilities: what you can cast, and how.",
	"tab:tree": "The Tree: where you choose how each mark grows.",
	"tab:marks": "Your marks, and how far each has grown.",
	"tab:essence": "What you've banked, by essence, and where it settled.",
	"tab:record": "Your record, as I keep it.",
	"ribbon": "{words}: a page of your book.",
	"ability": "{ability}: {desc}.",
	"map_link": "Shows it on the body map, on the Tree.",
	"try_abilities": "Try your abilities on dummies, here on the train.",
	"steps": "Every mark's steps, on the Marks page of your book.",
	"change_techniques": "Change which technique each mark button casts.",
	"part": "{words}: this mark's own page.",
	"bud": "A choice on the Tree. Choose it to see it.",
	"tree_act:choose": "Chooses this for good.",
	"tree_act:learn": "Learns this.",
	# --- a station ---------------------------------------------------------------------------------------
	"pick:drill": "{name}: {desc}",
	"pick:bout": "{name}: a bout. Its card shows the foes, the fee and the pay.",
	"pick:challenge": "{name}: {desc}",
	"pick:title": "{name}: {desc}",
	"pick:boon": "{name}: {desc}",
	"station_do:begin": "Begins it. A fall here costs nothing but the try.",
	"station_do:wear": "Wears this title on your book and the rail.",
	"station_do:buy": "Buys the boon's next level.",
	# --- anywhere ----------------------------------------------------------------------------------------
	"back": "Back where you came from.",
	"close": "Closes this page.",
}

## Small words the explanations are made with (and the Settings switch).
static var TEXT := {
	"setting": "The Entity explains buttons",
	"better": "It beats what you'd wear.",
	"worse": "What you'd wear is better.",
	"even": "About as good as what you'd wear.",
	"locked": " Only a Rune Artist can.",
	"counted": "%d of %d",
	"best": "Your best there: floor %d.",
	"best_none": "You haven't climbed it yet.",
}

## Which of a button's tags names its explanation, in order: [tag, how the
## key is made]. "raw": the tag's value is the key; "v": tag:value; "":
## the tag alone; the rest are worked out in key_for.
const TAGS := [
	["help", "raw"], ["rail", "v"], ["slot", "slot"], ["buy", "buy"], ["tower", ""], ["depart", ""], ["go_station", ""], ["station", ""],
	["board", "v"], ["store_tab", "v"], ["store_filter", "v"], ["put_back", ""], ["sell", ""],
	["equip", ""], ["move", "move"], ["unequip", "tail"], ["brew", ""], ["bench_tab", "v"], ["bench_drawer", "v"],
	["bench_do", "v"], ["retrait", ""], ["retrait_pick", ""], ["join", ""], ["inscribe", ""],
	["vessel_pack", ""], ["vessel_trade", ""], ["vessel_brew", ""],
	["bench_vial", ""], ["bench_mould", ""], ["bench_fx", ""], ["bench_fitting", ""], ["bench_slot", ""], ["bench_save", ""],
	["bench_name", ""], ["bench_from", ""], ["bench_draft", ""], ["tech_slot", ""],
	["shelf", ""], ["archive", ""], ["panel_tab", "v"], ["ribbon", "tabbed"], ["tab", "v"], ["choice_key", "setting"], ["setting", "setting"],
	["over", ""], ["car_page", "v"], ["open_stash", ""], ["cycler", "v"], ["pick", "head"], ["station_do", "v"],
	["map_link", ""], ["ability", ""], ["try_abilities", ""], ["change_techniques", ""], ["part", ""], ["bud", ""], ["tree_act", "v"], ["back", ""], ["close", ""],
]


## The stable id of a button's explanation ("" if none of its tags says).
static func key_for(b: Control) -> String:
	if b == null or not is_instance_valid(b):
		return ""
	for t in TAGS:
		var tag: String = t[0]
		if not b.has_meta(tag):
			continue
		var v = b.get_meta(tag)
		var s := str(v)
		match t[1]:
			"raw":
				return s
			"v":
				return "%s:%s" % [tag, s]
			"":
				return tag
			"setting":
				return "setting:" + s
			"head":
				return "%s:%s" % [tag, s.get_slice(":", 0)]
			"tail":
				return "%s:%s" % [tag, s.get_slice(":", s.get_slice_count(":") - 1)]
			"tabbed":
				return "tab:" + s if HELP.has("tab:" + s) else "ribbon"
			"move":
				return "move:chest" if s.begins_with("pack") else "move:pack"
			"buy":
				var bits := s.split(":")
				if bits.size() == 1 and Items.ITEMS.has(s):
					return "buy:supply"
				var last: String = bits[bits.size() - 1]
				return "buy:" + last if last in ["chest", "wear", "hold"] else "buy"
			"slot":
				var head := s.get_slice(":", 0)
				var key := "slot:" + head
				if head == "bench":
					var sub := s.get_slice(":", 1)
					key = "slot:bench:" + sub if sub in ["item", "supply"] else "slot:bench"
				if b.get("empty") == true and HELP.has(key + ":empty"):
					key += ":empty"
				return key
	return ""


## The words for a key: its own, else the part before its last ":" ("" if none).
static func entry(key: String) -> String:
	var at := key
	while at != "":
		if HELP.has(at):
			return String(HELP[at])
		var cut := at.rfind(":")
		if cut <= 0:
			return ""
		at = at.left(cut)
	return ""


## True if a button has no explanation of its own (only its words).
static func missing(b: Control) -> bool:
	return entry(key_for(b)) == ""


## What the Entity says about a button: its entry, filled in from the game
## as it is now; else the button's own words; "" for nothing to say.
static func explain(m, b: Control) -> String:
	if b == null or not is_instance_valid(b):
		return ""
	var key := key_for(b)
	var text := entry(key)
	var f := facts(m, b, key)
	if text == "":
		text = String(f.get("words", ""))
		if text == "" and f.has("piece"):
			text = "{piece}"
	return tidy(Entity.fill_words(text, f))


## Drops any blank left unfilled and the spaces around it.
static func tidy(text: String) -> String:
	var re := RegEx.create_from_string("\\{[a-z_]+\\}")
	text = re.sub(text, "", true)
	while text.contains("  "):
		text = text.replace("  ", " ")
	text = text.replace(" .", ".").replace(": .", ".").replace(" ,", ",")
	return text.strip_edges()


# --- the facts: what fills the blanks -------------------------------------------------------

## A button's words without the arrows and markers round them ("<  Show:
## Everything  >" -> "Show: Everything").
static func words(b: Control) -> String:
	var s := String(b.get("text")) if b.get("text") != null else ""
	s = s.replace("\n", " ").strip_edges()
	for mark in ["<", ">", "v "]:
		s = s.trim_prefix(mark).trim_suffix(mark).strip_edges()
	return s


static func _sentence(s: String) -> String:
	s = s.strip_edges()
	if s == "":
		return ""
	s = s.left(1).to_upper() + s.substr(1)
	return s if s.ends_with(".") or s.ends_with("!") or s.ends_with("?") else s + "."


static func _versus(m, g) -> String:
	if not Gear.is_gear(g) or m == null or m.main == null:
		return ""
	var vs := Train.versus(m.main.profile, m.main.player, g)
	return String(TEXT["better"] if vs > 0 else (TEXT["worse"] if vs < 0 else TEXT["even"]))


## "The Kraken's Tower" -> "the Kraken's Tower" (said in the middle of a
## sentence; {Tower} puts the capital back at the start of one).
static func lower_the(name: String) -> String:
	return "the" + name.substr(3) if name.begins_with("The ") else name


static func _piece_facts(m, g, f: Dictionary) -> void:
	if not Gear.is_gear(g):
		return
	f["piece"] = Gear.display(g)
	f["desc"] = Gear.desc(g)
	f["slot"] = String(Gear.SLOT_NAMES.get(Gear.slot_of(g), ""))
	f["versus"] = _versus(m, g)


static func _item_facts(id: String, f: Dictionary) -> void:
	var d: Dictionary = Items.ITEMS.get(id, {})
	if d.is_empty():
		return
	f["piece"] = String(d.get("name", id))
	f["desc"] = String(d.get("desc", ""))


static func _tower_facts(m, id: String, f: Dictionary) -> void:
	var t: Dictionary = Towers.TOWERS.get(id, {})
	if t.is_empty():
		return
	f["tower"] = lower_the(String(t.get("name", id)))
	f["essence"] = Essence.display(String(t.get("essence", "")))
	f["beast"] = String(t.get("beast", ""))
	var best := 0
	if m != null and m.main != null and m.main.profile != null:
		best = int(m.main.profile.record.get("best", {}).get(id, 0))
	f["best"] = str(best)
	f["best_line"] = String(TEXT["best"]) % best if best > 0 else String(TEXT["best_none"])


## The piece a card's button acts on: from its tag ("pack:2", "outfit:0",
## "today:chest", "helm:pack") or the slot whose card shows.
static func _subject(m, b: Control, key: String):
	if m == null or m.main == null or m.main.profile == null:
		return null
	var prof = m.main.profile
	for tag in ["sell", "equip", "move"]:
		if b.has_meta(tag):
			return _from_ref(prof, str(b.get_meta(tag)))
	if b.has_meta("unequip"):
		var slot := str(b.get_meta("unequip")).get_slice(":", 0)
		return Train.setoff(prof, m.main.player).get(slot, {}).get("rec", null)
	if b.has_meta("buy"):
		var v := str(b.get_meta("buy"))
		var head := v.get_slice(":", 0)
		match head:
			"outfit":
				var i := int(v.get_slice(":", 1))
				var o: Array = Train.outfit(prof)
				return o[i] if i >= 0 and i < o.size() else null
			"today":
				return Train.today(prof)
			"order":
				return Train.order(prof)
		return null
	var sel := String(m.inv_sel)
	if sel.begins_with("bench:"):
		var ref := sel.substr(6)
		if not ref.begins_with("item:") and not ref.begins_with("supply:"):
			return Bench.piece(prof, ref)
	return _from_ref(prof, sel)


static func _from_ref(prof, ref: String):
	var where := ref.get_slice(":", 0)
	var i := int(ref.get_slice(":", 1))
	var list: Array = prof.pack if where == "pack" else (prof.chest if where == "chest" else [])
	return list[i] if i >= 0 and i < list.size() else null


## Everything that may fill a button's blanks (cheap: only what its key needs).
static func facts(m, b: Control, key: String) -> Dictionary:
	var f := {"words": words(b)}
	var prof = m.main.profile if m != null and m.main != null else null
	var player = m.main.player if m != null and m.main != null else null
	var head := key.get_slice(":", 0)
	# A slot: the piece or item in it.
	if b.has_meta("slot"):
		var s := str(b.get_meta("slot"))
		var kind := String(b.get("kind")) if b.get("kind") != null else ""
		if b.get("rec") != null and Gear.is_gear(b.get("rec")):
			_piece_facts(m, b.get("rec"), f)
		elif kind == "item" and String(b.get("id")) != "":
			_item_facts(String(b.get("id")), f)
		if s.begins_with("worn:") and prof != null:
			var slot := s.get_slice(":", 1)
			f["slot"] = String(Gear.SLOT_NAMES.get(slot, slot.capitalize()))
			var e: Dictionary = Train.setoff(prof, player).get(slot, {})
			var from := String(e.get("from", ""))
			var LT: Dictionary = m.loadout_page.TEXT if m.get("loadout_page") != null else {}
			if LT.has("from_" + from):
				f["from"] = _sentence(String(LT["from_" + from]))
			if e.get("rec", null) != null:
				f["piece"] = Gear.display(e["rec"])
		if s.begins_with("supply:") and prof != null:
			var p: Array = Train.supply_price(prof, s.get_slice(":", 1))
			f["price"] = Train.price_text(p[0], int(p[1]))
		if s.begins_with("bench:item:") and prof != null:
			f["price"] = Train.paid_text(Bench.brew_cost(prof, s.get_slice(":", 2)))
		if (s.begins_with("outfit:") or s == "today" or s == "order") and prof != null and Gear.is_gear(b.get("rec")):
			f["price"] = Train.price_text(Train.gear_kind(b.get("rec")), Train.buy_price(prof, b.get("rec")))
		if s == "upgrades" and prof != null:
			f["count"] = str(Train.upgrades_done(prof))
		if s.begins_with("chest:") and prof != null:
			f["count"] = String(TEXT["counted"]) % [prof.chest.size(), Train.CHEST_SIZE]
		if s.begins_with("bench:"):
			f["counter"] = _counter_name(String(m.train_bench)).to_lower()
	# A card's button: the piece or item it acts on.
	if head in ["sell", "equip", "move", "unequip", "buy", "bench_do", "join", "inscribe", "retrait"]:
		var g = _subject(m, b, key)
		if Gear.is_gear(g):
			_piece_facts(m, g, f)
			if head == "sell":
				f["price"] = Train.price_text(Train.gear_kind(g), Train.gear_sell(g))
			elif head == "buy" and prof != null:
				f["price"] = Train.price_text(Train.gear_kind(g), Train.buy_price(prof, g))
		elif head == "bench_do" and String(m.inv_sel).begins_with("bench:supply:"):
			_item_facts(String(m.inv_sel).get_slice(":", 2), f)
	if key == "buy:supply" and prof != null:
		var id := str(b.get_meta("buy"))
		_item_facts(id, f)
		var p: Array = Train.supply_price(prof, id)
		f["price"] = Train.price_text(p[0], int(p[1]))
	if head in ["brew", "put_back"] and prof != null:
		var id := str(b.get_meta(head))
		_item_facts(id, f)
		if head == "brew":
			f["price"] = Train.paid_text(Bench.brew_cost(prof, id))
	# The engine.
	if head == "tower":
		_tower_facts(m, str(b.get_meta("tower")), f)
	if head == "depart":
		_tower_facts(m, str(b.get_meta("depart")), f)
	if head in ["station", "go_station"]:
		var st := Stations.station(str(b.get_meta(head)))
		f["station"] = String(st.get("name", "the station"))
	# The rail and the stash button.
	if head in ["open_stash"] or key == "car_page:stash":
		if prof != null:
			f["count"] = String(TEXT["counted"]) % [prof.chest.size(), Train.CHEST_SIZE]
	# The workshop's drawers.
	if head == "bench_tab" or head == "bench_drawer":
		var c := str(b.get_meta(head))
		f["counter"] = _counter_name(c) if head == "bench_tab" else words(b)
		f["locked"] = String(TEXT["locked"]) if bool(b.get_meta("greyed", false)) else ""
	# The library.
	if head == "shelf":
		var gid := str(b.get_meta("shelf"))
		var ids: Array = Entity.ordered(gid)
		f["shelf"] = words(b)
		f["heard"] = str(ids.filter(func(k): return Guide.known(k)).size())
		f["total"] = str(ids.size())
	if head == "archive":
		f["archive"] = String(Entity.TIPS.get(str(b.get_meta("archive")), {}).get("name", words(b)))
	# Settings: the choice under the pointer.
	if b.has_meta("choice"):
		f["choice"] = words(b)
	# The book.
	if head == "ability":
		_ability_facts(str(b.get_meta("ability")), f)
	# A station's tiles.
	if head == "pick":
		_pick_facts(m, str(b.get_meta("pick")), f)
	return f


static func _counter_name(id: String) -> String:
	for c in Bench.COUNTERS:
		if c[0] == id:
			return String(c[1])
	return id.capitalize()


static func _ability_facts(id: String, f: Dictionary) -> void:
	var B = load("res://scripts/bonds.gd")
	for bid in B.BONDS:
		for sp in B.BONDS[bid].get("spells", []):
			if String(sp.get("id", "")) == id:
				f["ability"] = String(sp.get("name", id))
				f["desc"] = String(sp.get("desc", ""))
				return


static func _pick_facts(m, pick: String, f: Dictionary) -> void:
	var kind := pick.get_slice(":", 0)
	var id := pick.get_slice(":", 1)
	match kind:
		"drill":
			f["name"] = String(Stations.DRILLS.get(id, {}).get("name", id))
			f["desc"] = Stations.drill_goal(id)
		"bout":
			f["name"] = String(Stations.bout(id).get("name", id))
		"challenge":
			var c: Dictionary = Stations.CHALLENGES.get(id, {})
			f["name"] = String(c.get("name", id))
			f["desc"] = String(c.get("twist", ""))
		"title":
			var t: Dictionary = Renown.TITLES.get(id, {})
			f["name"] = _sentence(String(t.get("name", id))).trim_suffix(".")
			f["desc"] = String(t.get("deed", ""))
		"boon":
			var bn: Dictionary = Boons.BOONS.get(id, {})
			f["name"] = String(bn.get("name", id))
			f["desc"] = String(bn.get("desc", ""))
