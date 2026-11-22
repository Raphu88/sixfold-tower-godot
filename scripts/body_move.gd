extends RefCounted
## MOVING ESSENCE, on the climber screen's Body tab (the Unbound's Nodes:
## menu.gd _climber_marks). It's the body's own doing, so it works wherever
## the climber screen opens (on the train, at a camp, at a stair, in a
## climb), except while a monster is after the climber (hunted).
##
## Under the Node cards (technique_page.gd climber: press a card to choose
## that Node: an awake one to move out of, a sleeping one to feed), one control:
##   From     the awake Node to move out of (a card pressed, or this button)
##   Essence  which of its essences
##   To       the Node it goes into: by default the first other Node that can
##            take it; pressing it skips the Nodes that can't (full, three
##            kinds already, or their lead would fall under half). A sleeping
##            Node always can: what arrives soaks in and brings it closer to
##            waking (unbound.gd feed). Moving never changes a Node's size.
##   Move     MOVE_STEP at a press, the amount and the price on the button
## then a line under it: what Move will do, or why it can't (unbound.gd
## why_not), and the result of the last press; and a separate
## "Drain into crystals" button. Every rule and number is unbound.gd's
## (move, MOVE_STEP, MOVE_COST); the words are here.

const Unbound := preload("res://scripts/unbound.gd")
const Tech := preload("res://scripts/technique.gd")
const UI := preload("res://scripts/ui.gd")

static var TEXT := {
	"title": "Move essence",
	"note": "Press a Node above (or From), then choose the essence and where it goes: another awake Node, or a sleeping one to feed it. Moving doesn't change a Node's size. A quarter of what you move is the price: %s",
	"none_awake": "None of your Nodes is awake yet, so there's nothing to move. Banked essence soaks into each until it wakes.",
	"to_asleep": "To: %s (asleep: feed it)",
	"move_feed": "Feed %s to %s  ·  costs %s",
	"will_feed": "Feeds %s %s from your %s to your sleeping %s: it soaks in. %s of it is the price: %s",
	"cost_path": {"": "it condenses into crystals until you choose a path.", "life": "it turns into Making, your core essence.", "unmaking": "it is unmade."},
	"from": "From: %s",
	"kind": "Essence: %s %s",
	"kind_none": "Essence: none",
	"to": "To: %s",
	"to_none": "To: no part can take it",
	"move": "Move %s to %s  ·  costs %s",
	"move_none": "Move",
	"wait": "Wait: a monster is after you",
	"drain": "Drain %s into crystals",
	"drain_none": "Drain into crystals",
	"will": "Moves %s %s from your %s to your %s. %s of it is the price: %s",
	"price": {"": "it condenses into crystals.", "life": "it turns into Making.", "unmaking": "it is unmade."},
	"empty": "Your %s holds no essence to move.",
	"no_target": "No other Node can take %s now: each awake one is full, already holds three kinds, or its lead would fall under half.",
	"hunted": "A monster is hunting you. Moving essence waits until no monster is after you.",
}
## How long the last press's result stays under the control (ms).
const SAID_MS := 12000


# --- the rules here: hunted, and what the control would do ------------------------------

## True while a monster is after the climber: one in the climb that has
## noticed them (awake and not lost; not a called creature or a practice
## dummy). On the train or at a camp, never.
static func hunted(main) -> bool:
	if main == null or bool(main.get("on_train")) or bool(main.get("in_camp")) or main.get("player") == null:
		return false
	for e in main.enemies():
		if bool(e.get("ally")) or String(e.get("kind")) == "dummy" or bool(e.get("calm")):
			continue
		if e.get("aware") == false:
			continue  # (asleep in its room: it hasn't seen you)
		if e.has_method("unaware") and e.unaware():
			continue  # (still noticing you, or it has lost you)
		return true
	return false


## The Nodes (other than `from`) that can take some of `kind` now: awake
## ones with room for it, and every sleeping one (it soaks in).
static func targets(prof, from: String, kind: String) -> Array:
	var out: Array = []
	if kind == "":
		return out
	for pt in Unbound.PARTS:
		if pt != from and not Unbound.sealed(prof, pt) and (not Unbound.awake(prof, pt) or Unbound.take_limit(prof, pt, kind) > 0.01):
			out.append(pt)
	return out


## The awake Nodes (only they hold essence to move out).
static func awake_nodes(prof) -> Array:
	return Unbound.PARTS.filter(func(pt): return Unbound.awake(prof, pt))


## The Node chosen on the Body tab (its levels show under the cards): the
## last card pressed, else the From Node.
static func picked(menu) -> String:
	var pt := String(menu.get_meta("node_pick", ""))
	if pt in Unbound.PARTS:
		return pt
	return String(plan(menu)["from"])


## Everything the control shows: {from, kinds, kind, targets, to, amount,
## price, drain, reason, hunted, can_move, can_drain}.
static func plan(menu) -> Dictionary:
	var main = menu.main
	var prof = main.profile
	var from := String(menu.get_meta("move_from", ""))
	var woke := awake_nodes(prof)
	if not from in woke:
		from = String(woke[0]) if not woke.is_empty() else Unbound.PARTS[0]
	var kinds := Unbound.mix(prof, from)
	var kind := String(menu.get_meta("move_kind", ""))
	if not kind in kinds:
		kind = String(kinds[0]) if not kinds.is_empty() else ""
	var tg := targets(prof, from, kind)
	var to := String(menu.get_meta("move_to", ""))
	if not to in Unbound.PARTS or to == from or Unbound.sealed(prof, to):
		to = String(tg[0]) if not tg.is_empty() else ""  # (never drain by default)
	var amt := Unbound.move_amount(prof, kind, from, to) if kind != "" and to != "" else 0.0
	var drain := Unbound.move_amount(prof, kind, from, "") if kind != "" else 0.0
	var h := hunted(main)
	var reason := ""
	if h:
		reason = TEXT["hunted"]
	elif kind == "":
		reason = TEXT["empty"] % Unbound.node_name(from)
	elif to == "":
		reason = TEXT["no_target"] % Tech.display(kind)
	elif amt <= 0.01:
		reason = Unbound.why_not(prof, to, kind)
	return {"from": from, "kinds": kinds, "kind": kind, "targets": tg, "to": to, "amount": amt, "price": amt * Unbound.MOVE_COST,
		"drain": drain, "reason": reason, "hunted": h, "can_move": not h and amt > 0.01, "can_drain": not h and drain > 0.01,
		"feed": to != "" and not Unbound.awake(prof, to), "none_awake": woke.is_empty()}


# --- the control ---------------------------------------------------------------------------

## The control, under the part cards (menu.gd _climber_marks, for an Unbound).
static func build(menu) -> void:
	var main = menu.main
	var prof = main.profile
	var p := plan(menu)
	menu._section(TEXT["title"])
	if bool(p["none_awake"]):
		var nl: Label = menu._small_label(TEXT["none_awake"], menu.DIM)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size.x = 280.0
		nl.set_meta("move_none_awake", true)
		menu.box.add_child(nl)
		return
	if not menu.compact():
		menu._note(TEXT["note"] % String(TEXT["cost_path"].get(String(prof.path), TEXT["cost_path"][""])))
	var row: GridContainer = menu._grid(2 if menu.compact() else 4, 6)
	row.set_meta("body_move", true)
	var from: String = p["from"]
	var kind: String = p["kind"]
	var to: String = p["to"]
	var fb: Button = menu._button(TEXT["from"] % Unbound.node_name(from), _cycle_from.bind(menu), row)
	fb.set_meta("help", "ub_move_from")
	fb.add_theme_color_override("font_color", _part_color(menu, from).lightened(0.25))
	var kb: Button = menu._button(TEXT["kind"] % [Tech.display(kind), Unbound._num(Unbound.amount(prof, from, kind))] if kind != "" else TEXT["kind_none"], _cycle_kind.bind(menu), row)
	kb.set_meta("help", "ub_move_kind")
	if kind != "":
		kb.add_theme_color_override("font_color", Tech.color(kind).lightened(0.2))
	kb.disabled = p["kinds"].size() < 2  # (only one essence there: nothing to choose)
	var tb: Button = menu._button((TEXT["to_asleep"] if p["feed"] else TEXT["to"]) % Unbound.node_name(to) if to != "" else TEXT["to_none"], _cycle_to.bind(menu), row)
	tb.set_meta("help", "ub_move_to")
	if to != "":
		tb.add_theme_color_override("font_color", _part_color(menu, to).lightened(0.25))
	tb.disabled = p["targets"].is_empty() or (p["targets"].size() == 1 and String(p["targets"][0]) == to)
	var move_text: String = TEXT["move_none"]
	if p["hunted"]:
		move_text = TEXT["wait"]
	elif p["can_move"]:
		move_text = (TEXT["move_feed"] if p["feed"] else TEXT["move"]) % [Unbound._num(p["amount"]), Unbound.node_name(to), Unbound._num(p["price"])]
	var mb: Button = menu._button(move_text, _do_move.bind(menu, false), row)
	mb.set_meta("help", "ub_move")
	mb.disabled = not p["can_move"]
	if p["can_move"]:
		menu._primary(mb)
	for b in [fb, kb, tb, mb]:
		UI.keep_text(b)  # (its words whole: smaller, then wrapped, never cut)
	# Right under it: why it can't, or what it will do; then the last result.
	var line := String(p["reason"])
	var bad := line != ""
	if not bad and p["can_move"]:
		line = (TEXT["will_feed"] if p["feed"] else TEXT["will"]) % [Unbound._num(p["amount"]), Tech.display(kind), Unbound.node_name(from), Unbound.node_name(to),
			Unbound._num(p["price"]), String(TEXT["price"].get(String(prof.path), TEXT["price"][""]))]
	if line != "":
		var why: Label = menu._small_label(line, UI.BAD if bad else menu.DIM)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size.x = 280.0
		why.set_meta("move_why" if bad else "move_will", true)
		menu.box.add_child(why)
	var said: Dictionary = menu.get_meta("move_said", {})
	if not bool(menu.get_meta("move_keep", false)):
		said = {}  # (the tab opened afresh: the last result is old news)
		menu.remove_meta("move_said")
	menu.remove_meta("move_keep")
	if not said.is_empty() and Time.get_ticks_msec() - int(said.get("ms", 0)) < SAID_MS:
		var rl: Label = menu._small_label(String(said["line"]), menu.GOLD if bool(said.get("ok", false)) else UI.BAD)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.custom_minimum_size.x = 280.0
		rl.add_theme_font_size_override("font_size", 16)
		rl.set_meta("move_said", true)
		menu.box.add_child(rl)
	# Draining is its own button, apart from Move.
	var dr: HBoxContainer = menu._row()
	var db: Button = menu._button(TEXT["drain"] % ("%s %s" % [Unbound._num(p["drain"]), Tech.display(kind)]) if p["can_drain"] else TEXT["drain_none"], _do_move.bind(menu, true), dr)
	db.set_meta("help", "ub_drain")
	db.disabled = not p["can_drain"]
	db.custom_minimum_size.x = 260.0 if not menu.compact() else 220.0
	UI.keep_text(db)


## A Node card on the Body tab (technique_page.gd climber): pressing it
## chooses that Node (its levels show under the cards): an awake one to move
## out of, a sleeping one to feed. The chosen one has a gold edge.
static func card(menu, b: Button, part: String) -> void:
	var asleep := not Unbound.awake(menu.main.profile, part)
	b.set_meta("help", "ub_part_sealed" if Unbound.sealed(menu.main.profile, part) else ("ub_part_asleep" if asleep else "ub_part"))
	b.pressed.connect(pick_node.bind(menu, part))
	if part == picked(menu):
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.16, 0.1, 0.9)
		sb.border_color = UI.GOLD
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(6)
		b.add_theme_stylebox_override("normal", sb)
		b.set_meta("move_from_card", true)


static func _part_color(menu, part: String) -> Color:
	var run = menu.main.unbound
	return run.part_color(menu.main.profile, part) if run != null else UI.TEXT


# --- pressing ------------------------------------------------------------------------------

## A Node card pressed: chosen (its levels show), and an awake one is the
## Node to move out of, a sleeping one the Node to feed.
static func pick_node(menu, part: String) -> void:
	menu.set_meta("node_pick", part)
	if Unbound.awake(menu.main.profile, part):
		pick_from(menu, part)
		return
	if Unbound.sealed(menu.main.profile, part):
		menu.remove_meta("move_said")
		menu.main.sfx("ui_confirm", 1.0, -6.0, 0.0)
		_redraw(menu, "ub_part_sealed")  # (chosen: its seal under the cards; it takes no essence)
		return
	menu.set_meta("move_to", part)
	menu.remove_meta("move_said")
	menu.main.sfx("ui_confirm", 1.0, -6.0, 0.0)
	_redraw(menu, "ub_move_to")


static func pick_from(menu, part: String) -> void:
	menu.set_meta("move_from", part)
	menu.set_meta("node_pick", part)
	menu.remove_meta("move_kind")
	menu.remove_meta("move_to")
	menu.remove_meta("move_said")
	menu.main.sfx("ui_confirm", 1.0, -6.0, 0.0)
	_redraw(menu, "ub_move_from")  # (the focus goes to the control: on a phone it scrolls into view)


## The next awake Node to move out of.
static func _cycle_from(menu) -> void:
	var woke := awake_nodes(menu.main.profile)
	if woke.is_empty():
		return
	var at := woke.find(String(plan(menu)["from"]))
	pick_from(menu, woke[(at + 1) % woke.size()])


static func _cycle_kind(menu) -> void:
	var p := plan(menu)
	var kinds: Array = p["kinds"]
	if kinds.is_empty():
		return
	menu.set_meta("move_kind", kinds[(kinds.find(p["kind"]) + 1) % kinds.size()])
	menu.remove_meta("move_to")
	menu.remove_meta("move_said")
	_redraw(menu, "ub_move_kind")


## The next part that can take it (the ones that can't are skipped).
static func _cycle_to(menu) -> void:
	var p := plan(menu)
	var tg: Array = p["targets"]
	if tg.is_empty():
		menu.main.sfx("ui_back", 1.0, -6.0, 0.0)
		return
	menu.set_meta("move_to", tg[(tg.find(p["to"]) + 1) % tg.size()])
	menu.set_meta("node_pick", String(menu.get_meta("move_to")))
	menu.remove_meta("move_said")
	_redraw(menu, "ub_move_to")


## Move (or, with `drain`, drain into crystals) one press's worth.
static func _do_move(menu, drain: bool) -> void:
	var main = menu.main
	var prof = main.profile
	var p := plan(menu)
	var line := ""
	var ok := false
	if p["hunted"]:
		line = TEXT["hunted"]
	elif String(p["kind"]) == "":
		line = String(p["reason"])
	elif not drain and String(p["to"]) == "":
		line = String(p["reason"])
	else:
		var got: Dictionary = Unbound.move(prof, String(p["kind"]), String(p["from"]), "" if drain else String(p["to"]))
		line = String(got["line"])
		ok = bool(got["ok"])
	if ok:
		main.sfx("pour", 1.0, -4.0, 0.0)
		main.tip("unbound_move")
		prof.save()
		main._give_bonds()
	else:
		main.sfx("ui_back", 1.0, -6.0, 0.0)
	menu.set_meta("move_said", {"line": line, "ok": ok, "ms": Time.get_ticks_msec()})
	_redraw(menu, "ub_drain" if drain else "ub_move")


## The tab built again where it was (no fade, no scroll back to the top),
## the focus on `help`'s button (keys and controller).
static func _redraw(menu, help: String) -> void:
	var sv: int = menu.scroll.scroll_vertical
	menu._want_focus = {"meta": "help", "value": help}
	menu.set_meta("move_keep", true)
	menu._quiet = true
	menu.open("climber", menu.opened_direct)
	menu._quiet = false
	# (the new page is laid out over the next frames: put the scroll back once it is)
	for i in 3:
		menu.scroll.scroll_vertical = sv
		await menu.get_tree().process_frame
		if not is_instance_valid(menu) or menu.page != "climber":
			return
	menu.scroll.scroll_vertical = sv


## From the Techniques tab: the climber screen, on the Body tab (the Nodes).
static func open_body(menu) -> void:
	menu._set_climber_tab("marks")
