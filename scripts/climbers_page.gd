extends RefCounted
## The climber picker (the CLIMBERS page, from the title screen), built with
## menu.gd's own helpers so mouse, keyboard, controller and touch all work.
## Six slots (slots.gd), two rows of three: each filled slot is a card with
## the climber drawn in their own look (the climber screen's figure, a dot of
## light on each mark), their name, marks (or first climb, or Unbound), best
## floor, climbs and when they last played; an empty slot offers a new
## climber. Choosing a card plays that climber (main.gd switch_climber);
## Delete under a card asks for a second press, then forgets them for good.
## Every word is here, in TEXT.

const Slots := preload("res://scripts/slots.gd")
const Unbound := preload("res://scripts/unbound.gd")
const UI := preload("res://scripts/ui.gd")

static var TEXT := {
	"title": "Climbers",
	"sub": "Up to six climbers. Choose one to play.",
	"slot": "%d",
	"current": "PLAYING",
	"unnamed": "Unnamed climber",
	"new": "New climber",
	"new_sub": "Begin a new climber here",
	"not_begun": "Still choosing a look",
	"first": "First climb, unmarked",
	"marks": "%d of 6 marks",
	"one_mark": "1 of 6 marks",
	"faint": "%d faint",
	"unbound": "Unbound",
	"stats": "Best floor %d  ·  %d %s",
	"climb": "climb",
	"climbs": "climbs",
	"played_now": "Played today",
	"played_yesterday": "Played yesterday",
	"played_days": "Played %d days ago",
	"played_long": "Played over a month ago",
	"delete": "Delete",
	"delete_again": "{again}: delete forever",
	"delete_ask": "Press Delete again to delete %s for good. This can't be undone.",
	"deleted": "%s is gone, and can't be brought back.",
	"full": "All six slots are full. Delete a climber to make room for a new one.",
	"delete_note": "Delete asks twice. A deleted climber can't be brought back.",
	# The title screen's button, with the current climber.
	"button": "Climbers",
	"button_named": "Climbers  ·  %s",
	"button_slot": "Climbers  ·  slot %d",
	# Start over (title, pause menu, N twice): this climber only.
	"over": "Start over",
	"over_title": "Start over?",
	"over_text": "Start %s over with no marks. Their marks and growth, essence, crystals, train and heirlooms will be lost. Your other climbers are kept.",
	"over_this": "this climber",
	"over_banner": "START OVER?",
	"over_again": "%s within 3 seconds to start this climber over.",
	"over_key": "Press N again",
	"over_tap": "Tap New again",
	"over_lost": "Their marks and all their growth will be lost.",
	"cancel": "Cancel",
}
## How long a Delete stays armed for its second press.
const ARM_MS := 4000
## A card's size (desktop, phone); the Delete button's height.
const CARD := Vector2(0.0, 150.0)
const CARD_SMALL := Vector2(0.0, 86.0)
const DELETE_H := 30.0
const DELETE_H_SMALL := 24.0


## A climber's name, or the word for one without.
static func name_of(prof) -> String:
	var n: String = str(prof.appearance.get("name", "")) if prof != null else ""
	return n if n != "" else TEXT["unnamed"]


## The title screen's button: Climbers, with whoever is current.
static func button_text(prof, slot: int) -> String:
	var n: String = str(prof.appearance.get("name", "")) if prof != null else ""
	if n != "":
		return TEXT["button_named"] % n
	return TEXT["button_slot"] % slot


## The line under a climber's name: marks, the first climb, or the Unbound.
static func status(prof) -> String:
	if not prof.created:
		return TEXT["not_begun"]
	if not prof.regarded:
		return TEXT["first"]
	if Unbound.is_on(prof):
		return TEXT["unbound"]
	var n: int = prof.bonds.size()
	var line: String = TEXT["one_mark"] if n == 1 else TEXT["marks"] % n
	var faint: int = prof.bonds.values().filter(func(b): return bool(b.get("faint", false))).size()
	if faint > 0:
		line += "  ·  " + TEXT["faint"] % faint
	return line


static func stats(prof) -> String:
	return TEXT["stats"] % [prof.best_floor, prof.climbs, TEXT["climb"] if prof.climbs == 1 else TEXT["climbs"]]


## When a climber last played, in days (local time).
static func played_text(unix: int) -> String:
	if unix <= 0:
		return ""
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var today := int(floor((Time.get_unix_time_from_system() + bias) / 86400.0))
	var then := int(floor(float(unix + bias) / 86400.0))
	var days := maxi(0, today - then)
	if days == 0:
		return TEXT["played_now"]
	if days == 1:
		return TEXT["played_yesterday"]
	if days <= 30:
		return TEXT["played_days"] % days
	return TEXT["played_long"]


## The picker page.
static func build(menu) -> void:
	var main = menu.main
	var small: bool = menu.compact()
	menu._header(TEXT["title"], TEXT["sub"])
	# The Entity: its tip the first time (kept in the Archive), then a line.
	var told: String = main.tip_now("climbers")
	if told != "" and menu.toast == "":
		menu.box.add_child(menu.Entity.says(told, 34.0 if small else 44.0))
		menu._gap(0 if small else 2)
	elif not small:
		menu._entity_says("climbers")
	var current := Slots.current()
	var armed := _armed(menu)
	var grid: GridContainer = menu._grid(3, 8 if small else 10, 6 if small else 10)
	var full := true
	for slot in range(1, Slots.MAX + 1):
		var prof = Slots.peek(slot)
		full = full and prof != null
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 3 if small else 5)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		var card := Card.new()
		card.slot = slot
		card.prof = prof
		card.current = slot == current and prof != null
		card.small = small
		card.slot_text = TEXT["slot"] % slot
		if prof != null:
			card.lines = [name_of(prof), status(prof), stats(prof), played_text(Slots.played(slot))]
			card.tag = TEXT["current"]
		else:
			card.lines = [TEXT["new"], TEXT["new_sub"]]
		card.figure = Callable(menu, "figure_into")
		card.custom_minimum_size = CARD_SMALL if small else CARD
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.set_meta("climber_slot", slot)
		card.pressed.connect(_choose.bind(menu, slot))
		cell.add_child(card)
		if prof != null:
			var del: Button = menu._button(menu.Nav.fill(TEXT["delete_again"], main) if armed == slot else TEXT["delete"], _delete.bind(menu, slot), cell)
			del.custom_minimum_size = Vector2(0, DELETE_H_SMALL if small else DELETE_H)
			del.add_theme_font_size_override("font_size", 13 if small else 15)
			for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
				del.add_theme_color_override(c, UI.BAD if armed == slot else (UI.DIM if c == "font_color" else UI.TEXT))
			del.set_meta("climber_delete", slot)
		else:
			var gap := Control.new()
			gap.custom_minimum_size.y = DELETE_H_SMALL if small else DELETE_H
			cell.add_child(gap)
	# Under the cards: what Delete does (a warning while one is armed).
	var note := ""
	if armed > 0:
		note = TEXT["delete_ask"] % name_of(Slots.peek(armed))
	elif full:
		note = TEXT["full"]
	elif not small:
		note = TEXT["delete_note"]
	if note != "":
		if not small:
			menu._gap(2)
		menu._note(note)
		var l: Label = menu.box.get_child(menu.box.get_child_count() - 1)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if armed > 0:
			l.add_theme_color_override("font_color", UI.BAD)
	menu._footer()


## The slot whose Delete is armed (0 if none, or if it has run out).
static func _armed(menu) -> int:
	if Time.get_ticks_msec() - int(menu.get_meta("climber_delete_t", -ARM_MS - 1)) > ARM_MS:
		return 0
	return int(menu.get_meta("climber_delete", 0))


## A card: play that climber (or begin a new one in an empty slot).
static func _choose(menu, slot: int) -> void:
	var main = menu.main
	menu.set_meta("climber_delete", 0)
	if slot == Slots.current() and (Slots.exists(slot) or not main.profile.created):
		menu._leave_title()  # (the climber already loaded: on as Continue)
		return
	main.sfx("ui_confirm")
	main.switch_climber(slot)


## Delete: the first press arms it, a second (within ARM_MS) deletes.
static func _delete(menu, slot: int) -> void:
	var main = menu.main
	if _armed(menu) != slot:
		menu.set_meta("climber_delete", slot)
		menu.set_meta("climber_delete_t", Time.get_ticks_msec())
		main.sfx("warn_knight", 1.2, -8.0, 0.0)
		menu.open("climbers")
		return
	menu.set_meta("climber_delete", 0)
	var gone := name_of(Slots.peek(slot))
	var was_current: bool = slot == Slots.current()
	main.delete_climber(slot)
	if not was_current:
		menu.toast = TEXT["deleted"] % gone
		menu.toast_t = 3.0
		menu.open("climbers")


## One slot, drawn in code.
class Card extends Button:
	const Bonds := preload("res://scripts/bonds.gd")
	const Appearance := preload("res://scripts/appearance.gd")
	const UI := preload("res://scripts/ui.gd")

	var slot := 1
	var prof = null  # the climber (profile.gd, loaded to look at), or null: empty
	var current := false
	var small := false
	var slot_text := ""
	var lines: Array = []  # name, status, stats, last played (empty: "New climber" and its line)
	var tag := ""  # over the current climber's card
	var figure: Callable  # menu.gd figure_into(b, look, bonds)
	var _look := {}

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_contents = true
		if prof != null:
			_look = Appearance.look(prof.appearance)
		# A card in the new look: violet stone, edged in gilt for the one
		# being played; an empty slot is fainter.
		var normal := UI.card(UI.GOLD if current else Color(0, 0, 0, 0))
		if prof == null:
			normal.top = Color(0.08, 0.07, 0.1, 0.7)
			normal.bottom = Color(0.06, 0.052, 0.078, 0.7)
			normal.edge = Color(UI.LINE, 0.8)
		var hover := UI.card(UI.GOLD)
		hover.top = Color(0.17, 0.15, 0.21, 0.97)
		add_theme_stylebox_override("normal", normal)
		add_theme_stylebox_override("hover", hover)
		add_theme_stylebox_override("pressed", hover)
		add_theme_stylebox_override("disabled", normal)
		var f := UI.focus_box()
		f.set_expand_margin_all(0)  # (the card clips what it draws)
		add_theme_stylebox_override("focus", f)

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var fs_num := 12 if small else 14  # (a small gothic label: the slot, and "current")
		UI.draw_eyebrow(self, Vector2(8, 6 + fs_num), slot_text, Color(UI.DIM, 0.8), fs_num)
		if prof == null:
			_draw_empty(font)
			return
		# The climber, as the climber screen draws them, a light on each mark.
		var fig_w := size.y * 0.62
		var k := (size.y - (10.0 if small else 18.0)) / 292.0
		var c := Vector2(fig_w * 0.5 + (8.0 if small else 14.0), size.y * 0.5 + 6.0 * k)
		draw_set_transform(c, 0.0, Vector2(k, k))
		var b := UI.Draw.Batch.new()
		for i in 3:
			b.dot(Vector2(0, -10), 120.0 - i * 30.0, Color(0.55, 0.5, 0.7, 0.03))
		b.polygon(UI._oval(Vector2(0, 126), Vector2(60, 10), 20), Color(0, 0, 0, 0.32))
		if figure.is_valid():
			figure.call(b, _look, prof.bonds if prof.regarded else {})
		b.flush(self)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# The words, right of the figure.
		var x := c.x + fig_w * 0.5 + (2.0 if small else 8.0)
		var w := size.x - x - (6.0 if small else 10.0)
		var sizes := [17, 12, 12, 10] if small else [26, 15, 14, 13]
		var y := (22.0 if small else 38.0)
		var cols := [UI.GOLD if current else UI.TEXT, UI.TEXT, UI.DIM, UI.FAINT]
		var gaps := [4.0, 3.0, 3.0] if small else [8.0, 6.0, 6.0]
		for i in mini(lines.size(), 4):
			if i > 0:
				y += sizes[i - 1] + gaps[i - 1]
			if String(lines[i]) != "":
				var f: Font = UI.font("display") if i == 0 else font  # (the name in the display face)
				UI.draw_text(self, f, Vector2(x, y), _fit(f, lines[i], w, sizes[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, sizes[i], cols[i])
		# Their marks as small medallions along the bottom (a computer's card).
		if not small and prof.regarded and not prof.bonds.is_empty():
			var mb := UI.Draw.Batch.new()
			var r := 8.0
			var mx := x + r
			for part in Bonds.PARTS:
				if not prof.bonds.has(part):
					continue
				var info: Dictionary = prof.bonds[part]
				var data: Dictionary = Bonds.BONDS.get(info["id"], {})
				if data.is_empty():
					continue
				UI.medallion_into(mb, Vector2(mx, size.y - r - 12.0), r, data["color"], data["affinity"], 1.0, 0, 0.0, bool(info.get("faint", false)))
				mx += r * 2.0 + 5.0
				if mx > size.x - r:
					break
			mb.flush(self)
		if current:
			UI.draw_eyebrow(self, Vector2(0, 6 + fs_num), tag, Color(UI.GOLD, 0.9), fs_num, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 9.0)

	func _draw_empty(font: Font) -> void:
		var c := size * 0.5 + Vector2(0, -8.0 if small else -12.0)
		var r := 11.0 if small else 18.0
		var b := UI.Draw.Batch.new()
		b.dot(c, r + 1.5, Color(UI.GOLD, 0.25))
		b.dot(c, r, Color(0.06, 0.055, 0.08, 0.9))
		b.rect(Rect2(c - Vector2(r * 0.5, r * 0.09), Vector2(r, r * 0.18)), Color(UI.GOLD, 0.7))
		b.rect(Rect2(c - Vector2(r * 0.09, r * 0.5), Vector2(r * 0.18, r)), Color(UI.GOLD, 0.7))
		b.flush(self)
		var fs := 14 if small else 17
		var t: String = lines[0] if lines.size() > 0 else ""
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		UI.draw_text(self, font, Vector2((size.x - tw) * 0.5, c.y + r + fs + 4.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.DIM)
		if not small:
			var s: String = lines[1] if lines.size() > 1 else ""
			var sw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			UI.draw_text(self, font, Vector2((size.x - sw) * 0.5, c.y + r + fs + 20.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.FAINT)

	static func _fit(font: Font, t: String, w: float, fs: int) -> String:
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
			return t
		while t.length() > 3 and font.get_string_size(t + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			t = t.left(t.length() - 1)
		return t + "..."
