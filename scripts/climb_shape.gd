extends Node2D
## The climb's shape (main.gd owns one: `main.climb_shape`): what makes a
## climb a climb from floor 1 to the summit.
##
## THE FIRST CLIMB is a normal climb. Reaching floor REGARD "floor" (6) on it
##   opens with the Regard: the tower's guardian (its beast) takes notice and
##   the body part you used most takes its first mark, at full strength. The
##   Proving follows on the same floor (later climbs have the Proving alone).
##   After the Regard the guardian offers an exit: leave for the train with
##   your mark, or climb on (EXIT cards).
## A DEATH BEFORE THE REGARD still brings it, but the mark is faint, its
##   strength scaled by the highest floor reached (DEATH_MARK: 50% on floor 1,
##   10% more a floor, 100% on floor 6). A faint mark is weaker and dearer
##   until it has soaked up its debt (profile.gd add_bond), as before.
## FALLS BELOW FLOOR 6 are allowed (the ways down); once the Proving is won
##   on a climb, floor 6 is an ordinary floor again, unless you choose the
##   harder Lethal Proving (LETHAL cards, on arriving there).
## THE STAIR'S BARRIER: on arriving at a floor, a barrier forms across its
##   stair (BARRIER): on floors 1 to 6 an iron GATE that takes "window"
##   seconds to close (roll under it before then and you slip past); on
##   floors 7 to 12 a WARD of light, fully up within its "window", that only
##   the essence of the tower's own marks can break (a spell of that essence,
##   a weapon or an item of it), and it's hard. A gate breaks to weapons, bare
##   fists and spells. Slipping past or breaking a barrier skips the floor's
##   task, and the tower answers with a HORDE ("horde" monsters); the stair
##   opens once it has fallen. A climber with no mark who does it becomes
##   Unbound on the spot (the guardian refuses them); a marked climber who has
##   done it SLIPS "maker_every" times in all (every climb counted) is
##   confronted by a Maker once the horde is beaten (makers.gd, CONFRONT).
##   The floor bot and the tests never roll into a barrier; tests turn
##   barriers on themselves (`barriers_on`, off in tests like the Proving).
## CAMPS: Items.CAMP_AFTER (after floors 3, 6 and 9), three cards each.
## THE STORY'S SCENES (story_scenes.gd): after the third guardian's summit
##   the Makers' plea, after the sixth the final meeting and its choice
##   (story_view.gd, start_story / end_story).
## THE ENDING: once all six guardians have been beaten, the final meeting
##   plays after the summit's victory, then the ending (its pages for the
##   choice: story_scenes.gd ENDINGS; ENDING here only when the scenes are
##   off), then the same climber plays on.
##
## Every word and number is here, in data, easy to rename or retune.

const UI := preload("res://scripts/ui.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const Essence := preload("res://scripts/essence.gd")
const Items := preload("res://scripts/items.gd")
const Gear := preload("res://scripts/gear.gd")
const Controls := preload("res://scripts/controls.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Story := preload("res://scripts/story_scenes.gd")

## The first Regard opens this floor of the first climb.
static var REGARD := {"floor": 6}
## A mark from a death before the Regard: "base" strength on floor 1, then
## "per_floor" more for each floor higher (the highest reached this climb),
## at most 1.0 (a full mark).
static var DEATH_MARK := {"base": 0.5, "per_floor": 0.1}
## The stair's barrier on each range of floors (inclusive). "window": seconds
## until it's fully up (a gate can be rolled under until then; a ward
## slipped through). "hp": how much breaking it takes (STRIKE). "horde":
## monsters the tower sends when it's slipped past or broken.
static var BARRIER := {
	"gate": {"from": 1, "to": 6, "window": 30.0, "hp": 12.0, "horde": 6, "name": "The gate"},
	"ward": {"from": 7, "to": 12, "window": 15.0, "hp": 12.0, "horde": 12, "name": "The ward"},
}
## What each blow is worth against a barrier. A gate: a melee strike (bare
## fists too) "blow", a finisher "heavy", a spell "spell". A ward: only the
## tower's own essence: a spell of it "ward_spell", a weapon of it "ward_blow"
## ("ward_heavy" a finisher), an item of it "ward_item". A blow counts only
## when it struck no foe (a swing at the barrier itself). "reach": how close
## a strike must be (px past the climber's own reach); "spell_reach": a cast.
static var STRIKE := {"blow": 1.0, "heavy": 2.0, "spell": 2.0, "ward_spell": 3.0, "ward_blow": 1.0, "ward_heavy": 2.0, "ward_item": 4.0,
	"reach": 30.0, "spell_reach": 240.0}
## Slips (slipped past or broken) that bring a Maker to a climber (marked or Unbound),
## counted over every climb; which Maker comes.
static var SLIPS := {"maker_every": 3, "maker": "towers"}
## The Maker's confrontation (makers.gd start_meeting, maker_view.gd):
## PLACEHOLDER words for the owner. "toll": the share of your unbanked
## essence it takes if you defy it.
static var CONFRONT := {
	"speech": ["Three times now you have gone under my stairs instead of up them.", "I built the barriers to be earned, climber. Not avoided.", "Tell me why I should not close every stair to you."],
	"speech_unbound": ["Three times now you have broken my stairs, and no guardian holds your leash.", "You take the wells raw, as we once did. I came to see what you are becoming.", "Tell me why I should not close every stair to you."],
	"answers": [
		{"id": "keep", "text": "I will keep the tower's rules.", "placeholder": false},
		{"id": "defy", "text": "The stair is mine to take.", "placeholder": false},
	],
	"keep_reply": ["Then keep them. I will be watching the stairs."],
	"defy_reply": ["Then pay for each one, as you have paid today."],
	"keep_line": "It lets you go. It will remember.",
	"defy_line": "It takes %d of the essence you carry.",
	"defy_none": "It finds nothing to take, and lets you go.",
	"toll": 0.5,
}
## The ending's plain page, shown only when there is no choice to tell
## (the story's scenes off: story_scenes.gd has the real pages), and the
## words under the last page and its prompt.
static var ENDING := {
	"title": "The Six Guardians",
	"lines": [
		"All six guardians have been beaten.",
		"All six wells run wild.",
		"The climber's story goes on.",
	],
	"after": "You keep climbing. The towers still stand.",
	"go_on": "to keep climbing",
}
## Everything else the climb's shape says.
static var TEXT := {
	"first_title": "YOUR FIRST CLIMB",
	"first_lines": ["You bear no mark.", "Reach floor %d: %s is watching."],
	"regard_lines_top": ["You reached floor %d. %s has watched you climb.", "Essence takes hold in your %s.", "You bear the %s mark.", "%s: %s."],
	"regard_lines_fell": ["You fell on floor %d, but %s was watching.", "Essence takes hold in your %s, faintly: %d%% strength.", "You bear a faint %s mark.", "It grows to full strength once it has soaked up more essence."],
	"regard_lines_fell_full": ["You fell on floor %d, but %s was watching.", "Essence takes hold in your %s.", "You bear the %s mark.", "%s: %s."],
	"prompt_next": "to begin your next climb",
	"prompt_on": "to go on",
	"exit_title": "THE GUARDIAN WAITS",
	"exit_lines": ["%s offers you a way out. Leave now with your mark, or climb on.", "The Proving is next, on this floor."],
	"leave_name": "Leave with the mark",
	"leave_desc": "Down to the train with your %s. What you carry comes home with you.",
	"leave_desc_none": "Down to the train. What you carry comes home with you.",
	"leave_note": "the climb ends here",
	"climb_name": "Climb on",
	"climb_desc": "Face the Proving on this floor, then the floors above, to the summit.",
	"climb_note": "a fall from here on is a fall",
	"climbed_on_title": "CLIMB ON",
	"lethal_title": "FLOOR 6 AGAIN",
	"lethal_lines": ["You have already won the Proving on this climb.", "Pass by, or take the Lethal Proving: harder, for a greater prize."],
	"pass_name": "Pass by",
	"pass_desc": "An ordinary floor. The Proving won't ask again this climb.",
	"lethal_name": "The Lethal Proving",
	"lethal_desc": "Only the Lethal door opens. Die beyond it and the climb ends.",
	"lethal_note": "for a greater prize",
	"gate_forming": "The stair's gate closes in %d seconds.",
	"ward_forming": "A ward rises over the stair: up in %d seconds.",
	"gate_label": "Closing: roll under",
	"ward_label": "Rising: roll through",
	"gate_up": "The gate is shut",
	"ward_up": "The ward holds",
	"caught": "The gate catches you. Roll again to slip past.",
	"caught_ward": "The ward throws you back. Roll again to slip through.",
	"holds": "It holds",
	"drinks": "It drinks the blow: only %s essence breaks this ward",
	"crack": "It cracks",
	"slipped_title": "YOU SLIPPED PAST",
	"broke_title": "THE BARRIER BREAKS",
	"horde_line": "The tower sends a horde: %d of its creatures.",
	"horde_stair": "The stair opens when the horde has fallen.",
	"horde_left": "Horde: %d left",
	"horde_done_title": "THE HORDE HAS FALLEN",
	"horde_done": "The stair opens. The floor's task is skipped.",
	"refused_lines": ["You slipped past the tower's barrier with no mark.", "%s will not mark you.", "You are Unbound.", "Banked essence fills your six body parts raw."],
	"maker_soon": "Something has noticed how often you go around the stairs.",
}

var main
## The stair's barrier on this floor ({} if none): kind, t, window, hp, dmg,
## state (forming, up, open, slipped, broken), rect, shudder.
var bar := {}
var horde: Array = []
var horde_total := 0
var maker_due := false  # the horde of a third slip: a Maker once it falls
var refusing := false  # a slip with no mark: the refusal shows, the horde waits
var top_floor := 0  # the highest floor reached this climb (the death mark's scale)
var barriers_on := not Engine.has_meta("sixfold_test")  # (off in tests unless a test turns them on)
var ending_view: Control = null
var story_view: Control = null  # the Makers' plea or the final meeting (story_view.gd)
var final_deferred := false  # "Not yet" at the final meeting: it waits for another summit
var _ending_frame := -1
var _light := -1
var over: Node2D  # drawn over the darkness: the barrier and its timer
var drawn := Rect2()  # where the barrier was last drawn (empty: nothing on screen; tests check it sits on the stair)


func _ready() -> void:
	z_index = -2  # (the gate's shadow on the floor; the rest is drawn over the darkness)
	over = Node2D.new()
	over.z_as_relative = false
	over.z_index = 44
	over.draw.connect(_draw_over)
	add_child(over)


# --- the first Regard and the death mark -------------------------------------------------

static func regard_floor() -> int:
	return int(REGARD["floor"])


## The strength of a first mark taken in a death on floor `n` (0.5 to 1.0).
static func death_strength(n: int) -> float:
	return clampf(float(DEATH_MARK["base"]) + float(DEATH_MARK["per_floor"]) * float(maxi(n, 1) - 1), 0.0, 1.0)


## The floor the death mark is scaled by: the highest reached this climb.
func reached() -> int:
	return maxi(top_floor, main.floor_num)


## The Regard's words (hud.gd draws them): reached, or fallen with its strength.
func regard_lines(rg: Dictionary, info: Dictionary, part_name: String) -> Array:
	var beast: String = main.beast_name()
	var on_floor := int(rg.get("floor", main.floor_num))
	if rg.get("fell", false):
		var s := float(rg.get("strength", 0.75))
		if s >= 1.0:
			var full: Array = TEXT["regard_lines_fell_full"]
			return [full[0] % [on_floor, beast], full[1] % part_name, full[2] % info["name"], full[3] % [info["spells"][0]["name"], main.BondScript.PART_FILLS[rg["part"]]]]
		var fell: Array = TEXT["regard_lines_fell"]
		return [fell[0] % [on_floor, beast], fell[1] % [part_name, int(round(s * 100.0))], fell[2] % info["name"], fell[3]]
	var top: Array = TEXT["regard_lines_top"]
	var said: Array = [top[0] % [on_floor, beast.capitalize()], top[1] % part_name, top[2] % info["name"], top[3] % [info["spells"][0]["name"], main.BondScript.PART_FILLS[rg["part"]]]]
	if rg.has("glimpse"):
		said.append_array(load("res://scripts/fracture.gd").charge(beast.capitalize()))  # (after the glimpse: the guardian's charge)
	return said


## Under the Regard: what dismissing it leads to.
func regard_prompt(rg: Dictionary) -> String:
	return String(TEXT["prompt_on"] if rg.get("exit", false) or rg.get("mid", false) else TEXT["prompt_next"])


## A stair has brought you to a new floor (main.gd _arrive, after its banner):
## floor 6 of the first climb opens with the Regard; floor 6 again after a
## won Proving offers the Lethal one.
func after_arrive() -> void:
	if main.first_climb and main.floor_num == regard_floor() and main.regard.is_empty() and not main.in_camp:
		main._begin_regard(false)
		return
	if Story.enabled() and Story.plea_due(main.profile) and not main.first_climb and not main.in_camp and main.regard.is_empty():
		start_story("plea")  # (the third guardian's summit was missed: the plea comes at this stair)
		return
	if maker_owed():
		main.profile.record["maker_owed"] = 0.0
		main.profile.save()
		confront()  # (a burned-out mark brought the third slip: mark_use.gd burn_out)
		return
	_offer_lethal()


## True when a Maker is owed a visit at this stair: a burned-out mark counted
## as the third slip (mark_use.gd burn_out), and nothing else is under way.
func maker_owed() -> bool:
	var prof = main.profile
	return prof != null and prof.count("maker_owed") > 0 and not main.first_climb and not Unbound.is_on(prof) and not main.in_camp and main.regard.is_empty()


## main.gd end_regard asks first: true if this handled it (the guardian's
## exit, a slip's refusal ending, the ending), so the climb doesn't end yet.
func before_leaving() -> bool:
	if Engine.get_process_frames() == _ending_frame:
		return true  # (the press that closed the ending: once is enough)
	if ending_view != null or story_view != null:
		return true
	var rg: Dictionary = main.regard
	if not rg.is_empty() and rg.get("mid", false):
		_resume_after_refusal()
		return true
	if not rg.is_empty() and rg.get("exit", false) and not rg.get("exit_chosen", false) and not main.camp_choosing:
		_offer_exit()
		return true
	if not main.victory.is_empty() and Story.enabled() and Story.plea_due(main.profile):
		start_story("plea")  # (the third guardian beaten: the Makers ask the climber to stop)
		return true
	if not main.victory.is_empty() and ending_due() and not final_deferred:
		if Story.enabled():
			start_story("final")  # (the final meeting and its choice, then the ending)
		else:
			show_ending()
		return true
	return false


func _offer_exit() -> void:
	var lines: Array = TEXT["exit_lines"].duplicate()
	lines[0] = lines[0] % main.beast_name().capitalize()
	main.camp = {"stage": "exit", "choices": ["exit:leave", "exit:climb"], "title": TEXT["exit_title"], "lines": lines, "t": 0.0}
	main.camp_choosing = true
	main.card_focus = 1
	main.tip("regard_exit")
	main.sfx("ready", 0.6, -2.0, 0.0)


func _offer_lethal() -> void:
	var pv = main.proving
	if pv == null or not pv.enabled or not pv.won_climb or main.floor_num != int(Towers.PROVING["floor"]) or pv.on or main.in_camp or not pv.lethal_open():
		return
	main.camp = {"stage": "lethal_again", "choices": ["lethal:pass", "lethal:take"], "title": TEXT["lethal_title"], "lines": TEXT["lethal_lines"], "t": 0.0}
	main.camp_choosing = true
	main.card_focus = 0
	main.player.set_physics_process(false)
	main.tip("lethal_again")
	main.sfx("ready", 0.6, -2.0, 0.0)


## A card on the exit or Lethal choice (main.gd camp_card).
func card(pick: String) -> Dictionary:
	match pick:
		"exit:leave":
			var id := String(main.regard.get("id", ""))
			var bonds = main.BondScript.Bonds
			var desc: String = TEXT["leave_desc"] % (String(bonds.BONDS[id]["name"]) + " mark") if bonds.BONDS.has(id) else String(TEXT["leave_desc_none"])
			return {"name": TEXT["leave_name"], "desc": desc, "color": UI.GOLD, "item": "", "note": TEXT["leave_note"]}
		"exit:climb":
			return {"name": TEXT["climb_name"], "desc": TEXT["climb_desc"], "color": Color(0.62, 0.52, 0.95), "item": "", "note": TEXT["climb_note"]}
		"lethal:pass":
			return {"name": TEXT["pass_name"], "desc": TEXT["pass_desc"], "color": UI.GOLD, "item": ""}
		"lethal:take":
			return {"name": TEXT["lethal_name"], "desc": TEXT["lethal_desc"], "color": Color(0.95, 0.22, 0.18), "item": "", "note": TEXT["lethal_note"]}
	return {"name": "?", "desc": "", "color": Color.WHITE, "item": ""}


## A card taken (main.gd choose_camp).
func choose(i: int) -> void:
	var pick: String = main.camp["choices"][i]
	main.camp_choosing = false
	main.camp = {}
	match pick:
		"exit:leave":
			leave_at_regard()
		"exit:climb":
			climb_on()
		"lethal:pass":
			main.player.set_physics_process(true)
		"lethal:take":
			main.proving.lethal_only = true
			main._start_floor(main.floor_num)
			main.banner = main.proving.arrival_banner([])
			main.player.set_physics_process(true)
			main.sfx("warn_knight", 0.5, 0.0, 0.0)


## Leaving at the floor-6 Regard: the climb ends as a survived one (paid,
## the belt into crystals, the pack and what you wear come home), then the
## heirloom and the train (main.gd end_regard).
func leave_at_regard() -> void:
	main.regard["exit_chosen"] = true
	main.pay_climb()
	main.profile.climbs += 1
	main.break_belt()
	main.bring_pack_home()
	main.Vessel.bring_home(main)
	main.profile.save()
	main.end_regard()


## Climbing on past the Regard: the climb goes on as a marked one.
func climb_on() -> void:
	main.regard = {}
	main.first_climb = false
	main.banner = {}
	main._give_bonds()  # (the new mark on its button, or the Unbound's techniques)
	main.player.set_physics_process(true)
	for e in main.enemies():
		e.set_physics_process(true)
	if main.proving != null and main.proving.on:
		main.banner = main.proving.arrival_banner([])
		main.GuideScript.moment("proving", "proving")
	else:
		main.banner = {"title": TEXT["climbed_on_title"], "lines": [String(TEXT["climb_desc"])], "t": 3.0}
	main.tip("regard_climb_on")
	if Unbound.is_on(main.profile):
		main.tip("unbound_cast")
	else:
		main.tip("casting")  # (the first mark's button: how to cast, as a climb with marks begins)
		main.tip("abilities")
	main.sfx("equip_sword", 0.8, -2.0, 0.0)


# --- every floor: the barrier ------------------------------------------------------------

## The barrier's kind on floor `n` ("" for none).
static func kind_for(n: int) -> String:
	for k in BARRIER:
		if n >= int(BARRIER[k]["from"]) and n <= int(BARRIER[k]["to"]):
			return k
	return ""


## A new floor has been built (main.gd _start_floor, at its end).
func setup_floor(plan: Dictionary) -> void:
	if not main.in_camp:
		top_floor = maxi(top_floor, main.floor_num)
	_clear()
	if not barriers_on or main.in_camp or plan.is_empty() or plan.get("proving", false) or plan.get("summit", false) or plan.has("try_room") \
			or main.practice_or_arena() or main.stair_open:
		return
	var k := kind_for(main.floor_num)
	if k == "":
		return
	var d: Dictionary = BARRIER[k]
	var sp: Vector2 = main.stair_pos
	bar = {"kind": k, "t": 0.0, "window": float(d["window"]), "hp": float(d["hp"]), "dmg": 0.0, "state": "forming",
		"rect": Rect2(sp + Vector2(-40.0, -30.0), Vector2(80.0, 52.0)), "shudder": 0.0, "said": false}
	if main.lighting != null:
		_light = main.lighting.add_light(sp + Vector2(0, 10), 120.0, color(), 0.5, 0.25)
	queue_redraw()
	over.queue_redraw()


## A new climb (main.gd _note_climb_start): the death mark's floor starts over.
func new_climb() -> void:
	top_floor = 0
	maker_due = false
	refusing = false


func _clear() -> void:
	bar = {}
	horde.clear()
	horde_total = 0
	refusing = false
	if _light >= 0 and main.lighting != null:
		main.lighting.remove_light(_light)
	_light = -1
	# Wipe the last floor's gate or ward off the screen at once. (It's only
	# redrawn while a barrier stands, so on a floor with none, a camp, the
	# practice room, the arena, the Proving or the summit, the old picture
	# used to linger where the last floor's stair had been.)
	queue_redraw()
	if over != null:
		over.queue_redraw()


## The barrier's colour: iron for a gate, the tower's essence for a ward.
func color() -> Color:
	if bar.get("kind", "gate") == "ward":
		return Essence.color(String(main.tower_data().get("essence", "air"))).lightened(0.15)
	return Color(0.62, 0.6, 0.66)


## The words to show as the floor's banner comes up (main.gd _arrive).
func arrival_line() -> String:
	if bar.is_empty():
		return ""
	return String(TEXT["gate_forming" if bar["kind"] == "gate" else "ward_forming"]) % int(ceil(float(bar["window"])))


## True while the horde stands: the stair waits for it (main.gd's stair check).
func horde_live() -> bool:
	for e in horde:
		if is_instance_valid(e) and not e.dead:
			return true
	return false


func lets_climb() -> bool:
	return not horde_live() and not refusing


func horde_left() -> int:
	return horde.filter(func(e): return is_instance_valid(e) and not e.dead).size()


func _physics_process(delta: float) -> void:
	if main == null or main.player == null:
		return
	if bar.is_empty():
		return
	var p = main.player
	var st: String = bar["state"]
	if bar["shudder"] > 0.0:
		bar["shudder"] = maxf(0.0, float(bar["shudder"]) - delta)
	over.queue_redraw()
	if st in ["slipped", "broken"]:
		if not refusing and horde_total > 0 and not horde_live():
			_horde_fell()
		return
	if st == "open":
		return
	if main.stair_open:
		_open()
		return
	if main.climbing or main.camp_choosing or main.overlay_showing() or p.dead:
		return
	if st == "forming":
		bar["t"] = float(bar["t"]) + delta
		if not bar["said"]:
			bar["said"] = true
			main.tip("barrier_" + String(bar["kind"]))
		if float(bar["t"]) >= float(bar["window"]):
			bar["state"] = "up"
			main.sfx("slam", 0.8 if bar["kind"] == "gate" else 1.3, -2.0, 0.0)
			main.shake(2.0)
			main.fx_text(main.stair_pos + Vector2(0, 54), String(TEXT["gate_up" if bar["kind"] == "gate" else "ward_up"]), color())
			return
	if _touching(p):
		if p.roll_t > 0.0 and bar["state"] == "forming":
			try_slip()
		else:
			_push_back(p)


func _touching(p) -> bool:
	return Rect2(bar["rect"]).grow(p.radius).has_point(p.global_position)


## Walking into the barrier: it holds you back (only a roll goes under).
func _push_back(p) -> void:
	var r: Rect2 = bar["rect"]
	p.global_position.y = maxf(p.global_position.y, r.end.y + p.radius + 1.0)
	p.reset_physics_interpolation()


## A roll into the forming barrier. The very first time ever, it only throws
## you back with a warning; after that you slip past. Returns true on a slip.
func try_slip() -> bool:
	if bar.is_empty() or bar["state"] != "forming" or main.stair_open:
		return false
	var prof = main.profile
	if prof.count("slip_warned") <= 0:
		prof.note("slip_warned")
		prof.save()
		_push_back(main.player)
		bar["shudder"] = 0.6
		main.fx_text(main.stair_pos + Vector2(0, 54), String(TEXT["caught" if bar["kind"] == "gate" else "caught_ward"]), color().lightened(0.3))
		main.sfx("hit_armor", 0.6, -2.0, 0.0)
		main.shake(3.0)
		main.tip("barrier_slip_warn")
		return false
	bar["state"] = "slipped"
	main.player.global_position = main.stair_pos
	main.player.reset_physics_interpolation()
	main.sfx("slam", 0.6, 0.0, 0.0)
	main.shake(6.0)
	main.fx_burst(main.stair_pos + Vector2(0, 20), Vector2.UP, color(), 16, 160.0)
	_breached("slipped")
	return true


## A melee swing (player.gd _melee): against the barrier if it's in reach and
## the swing struck no foe.
func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float, heavy: bool, hits: int) -> void:
	if bar.is_empty() or hits > 0 or not bar["state"] in ["forming", "up"] or main.stair_open:
		return
	var kinds := weapon_kinds(main.player)
	var r: Rect2 = bar["rect"]
	var near := Vector2(clampf(from.x, r.position.x, r.end.x), clampf(from.y, r.position.y, r.end.y))
	var to := near - from
	if to.length() > reach + float(STRIKE["reach"]):
		return
	if to.length() > 4.0 and absf(dir.angle_to(to)) > deg_to_rad(maxf(arc_deg, 45.0)):
		return
	if bar["kind"] == "gate":
		_hurt(float(STRIKE["heavy" if heavy else "blow"]), near)
	elif String(main.tower_data().get("essence", "")) in kinds:
		_hurt(float(STRIKE["ward_heavy" if heavy else "ward_blow"]), near)
	else:
		_drinks(near)


## A spell cast or an item used (player.gd): `kind` its essence, from `pos`
## aimed along `aim` ("bond" or "item").
func offer(kind: String, pos: Vector2, aim: Vector2, how: String) -> void:
	if bar.is_empty() or not bar["state"] in ["forming", "up"] or main.stair_open:
		return
	var c: Vector2 = Rect2(bar["rect"]).get_center()
	var to := c - pos
	if to.length() > float(STRIKE["spell_reach"]):
		return
	if how == "bond" and to.length() > 40.0 and aim.dot(to.normalized()) < 0.6:
		return
	if bar["kind"] == "gate":
		if how == "bond":
			_hurt(float(STRIKE["spell"]), c)
		return
	if kind == String(main.tower_data().get("essence", "")):
		_hurt(float(STRIKE["ward_item" if how == "item" else "ward_spell"]), c)
	else:
		_drinks(c)


## The essences of the weapon in hand: a named piece's own, and its traits'.
static func weapon_kinds(p) -> Array:
	var out: Array = []
	if p == null:
		return out
	var g = p.weapon_rec()
	var n := Gear.named_id(g)
	if Gear.NAMED.has(n):
		out.append(String(Gear.NAMED[n].get("kind", "")))
	for tr in Gear.rec(g).get("traits", []):
		if Gear.TRAITS.has(tr):
			out.append(String(Gear.TRAITS[tr].get("kind", "")))
	return out


func _drinks(at: Vector2) -> void:
	bar["shudder"] = 0.25
	main.fx_text(at + Vector2(0, -30), String(TEXT["drinks"]) % Essence.display(String(main.tower_data().get("essence", "air"))), color())
	main.sfx("hit_armor", 1.3, -8.0, 0.0)
	main.tip("barrier_ward")


func _hurt(amount: float, at: Vector2) -> void:
	bar["dmg"] = float(bar["dmg"]) + amount
	bar["shudder"] = 0.35
	main.fx_burst(at, Vector2.UP, color(), 8, 160.0)
	main.shake(3.0)
	main.sfx("hit_heavy", 0.7 if bar["kind"] == "gate" else 1.4, -4.0)
	if float(bar["dmg"]) >= float(bar["hp"]):
		bar["state"] = "broken"
		main.fx_burst(Rect2(bar["rect"]).get_center(), Vector2.ZERO, color(), 28, 260.0)
		main.light_flash(Rect2(bar["rect"]).get_center(), color(), 1.8, 1.6, 0.4)
		main.shake(7.0)
		main.sfx("slam", 0.5, 0.0, 0.0)
		_breached("broken")
		return
	main.fx_text(at + Vector2(0, -30), String(TEXT["crack"]), color())
	main.tip("barrier_break")


## Slipped past or broken: the horde, and what it means for the climber.
func _breached(how: String) -> void:
	var prof = main.profile
	prof.note("slips")
	prof.save()
	var n := int(BARRIER[bar["kind"]]["horde"])
	var unmarked: bool = prof.bonds.is_empty() and not Unbound.is_on(prof)
	main.banner = {"title": String(TEXT["slipped_title" if how == "slipped" else "broke_title"]), "lines": [String(TEXT["horde_line"]) % n, String(TEXT["horde_stair"])], "t": 3.5, "pri": 2}
	main.note_event("task", String(TEXT["horde_line"]) % n)
	if unmarked:
		refuse_now()
		return
	if prof.count("slips") % int(SLIPS["maker_every"]) == 0:  # (marked and Unbound alike: the Makers watch rule-breakers)
		maker_due = true
		main.tip("barrier_maker_soon")
	spawn_horde(n)
	main.tip("barrier_horde")


## The tower's horde: `n` of the floor's creatures, awake, around the stair.
func spawn_horde(n: int) -> void:
	var weights: Dictionary = main.tower_data().get("weights", {})
	var centre: Vector2 = main.stair_pos + Vector2(0, 120)
	for i in n:
		var kind := Floors._pick(main.floor_num, 3.0, 99, weights)
		if kind == "":
			kind = "slime"
		var ring := 70.0 + 30.0 * float(i / 6)
		var at := centre + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / float(maxi(n, 1)) + 0.3 * float(i / 6)) * ring
		var e = main.spawn_enemy(kind, at)
		e.set_meta("add", "horde")  # (the tower's answer, not its spoils: a share of the essence, essence.gd ADDS)
		e.wake()
		horde.append(e)
		main.fx_burst(e.global_position, Vector2.UP, Color(0.75, 0.3, 0.3), 10, 140.0)
	horde_total += n
	main.foes_changed()
	main.sfx("warn_knight", 0.7, 0.0, 0.0)
	main.shake(5.0)


## No mark yet, and the tower's barrier slipped: the guardian refuses you on
## the spot, and you are Unbound (unbound.gd become). The refusal shows
## first; the horde comes when it's dismissed.
func refuse_now() -> void:
	var prof = main.profile
	Unbound.become(prof)
	prof.regarded = true
	prof.save()
	main.first_climb = false
	main._give_bonds()
	refusing = true
	main.regard = {"fell": false, "part": "", "id": "", "refused": true, "mid": true, "t": 0.0, "dark": main.fade > 0.5, "lines": TEXT["refused_lines"]}
	Story.start_regard(main.regard, prof)  # (a climber's first Regard: the Makers watch the refusal)
	main.banner = {}
	main.player.set_physics_process(false)
	for e in main.enemies():
		e.set_physics_process(false)
	main.sfx("regard", 0.8, 0.0, 0.0)
	main.tip("barrier_unbound")


func _resume_after_refusal() -> void:
	main.regard = {}
	refusing = false
	main.player.set_physics_process(true)
	for e in main.enemies():
		e.set_physics_process(true)
	main.tip("unbound")
	spawn_horde(int(BARRIER[bar.get("kind", "gate")]["horde"]) if not bar.is_empty() else int(BARRIER["gate"]["horde"]))


## The horde is down: the stair opens (the floor's task skipped), and on a
## third slip a Maker comes.
func _horde_fell() -> void:
	horde_total = 0
	horde.clear()
	main.ward = false
	main.stair_open = true
	main.room_view.stair_open = true
	bar["state"] = "open"
	main.banner = {"title": TEXT["horde_done_title"], "lines": [TEXT["horde_done"]], "t": 3.0}
	main.sfx("clear", 0.9, -2.0, 0.0)
	main.fx_ring(main.stair_pos, color(), 80.0, 0.6, 4.0)
	if maker_due:
		maker_due = false
		confront()


## The Maker's confrontation (makers.gd start_meeting with `confront`).
func confront() -> void:
	if main.makers == null:
		return
	main.tip("barrier_maker")
	main.makers.start_meeting(String(SLIPS["maker"]), true)


## The confrontation's answer (makers.gd confront_answer): what happens.
func confront_answer(id: String) -> Dictionary:
	var out := {"good": id == "keep", "granted": "", "lines": [], "reply": "", "gains": {}}
	if id == "keep":
		out["reply"] = String(CONFRONT["keep_reply"][0])
		out["lines"].append(CONFRONT["keep_line"])
		return out
	out["reply"] = String(CONFRONT["defy_reply"][0])
	var carried := 0.0
	for k in main.run_essence:
		carried += float(main.run_essence[k])
	var take := floorf(carried * float(CONFRONT["toll"]))
	if take >= 1.0:
		main.SecretBonds.take_essence(main.run_essence, take)
		out["lines"].append(String(CONFRONT["defy_line"]) % int(take))
	else:
		out["lines"].append(CONFRONT["defy_none"])
	return out


## The stair opened the ordinary way (its task done): the barrier lifts.
func _open() -> void:
	bar["state"] = "open"
	main.sfx("glint", 1.0, -6.0, 0.0)


# --- the ending --------------------------------------------------------------------------

## True when every tower's guardian has been beaten and the ending hasn't played.
func ending_due() -> bool:
	var prof = main.profile
	if prof == null or prof.count("ending") > 0:
		return false
	var by: Dictionary = prof.record.get("beasts_by", {})
	for tid in Towers.ORDER:
		if int(by.get(tid, 0)) <= 0:
			return false
	return true


## The Makers' council (story_view.gd): "plea" or "final". The game pauses.
func start_story(kind: String) -> void:
	if story_view != null or ending_view != null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 9  # over the HUD and the touch buttons, under the menu (10)
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(layer)
	story_view = load("res://scripts/story_view.gd").new()
	story_view.main = main
	story_view.shape = self
	story_view.kind = kind
	layer.add_child(story_view)
	if main.player != null:
		main.player.velocity = Vector2.ZERO
	get_tree().paused = true
	main.sfx("maker_meeting", 1.0, 0.0, 0.0)
	main.sfx("glint", 0.3, -4.0, 0.0)


## The council over (story_view.gd finish): the Entity's word on the plea's
## answer; the final meeting's choice goes on to the ending ("Not yet":
## the summit's flow goes on, and the meeting waits for another summit).
func end_story(kind: String, id: String) -> void:
	if story_view == null:
		return
	var layer = story_view.get_parent()
	story_view.queue_free()
	if layer != null:
		layer.queue_free()
	story_view = null
	get_tree().paused = false
	main.tip("story_" + kind)  # (the Entity explains it, the first time)
	if kind == "plea" and id != "":
		main.story("plea_" + id)  # (its next line follows the answer: entity.gd STORY)
	if kind == "final" and id in ["ascend", "fight"]:
		show_ending()
		return
	if kind == "final":
		final_deferred = true
	if not main.victory.is_empty():
		main.end_regard()  # (the summit's flow goes on: the heirloom, the train)
		_ending_frame = Engine.get_process_frames()


func show_ending() -> void:
	if ending_view != null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 9
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(layer)
	ending_view = EndingView.new()
	ending_view.shape = self
	layer.add_child(ending_view)
	get_tree().paused = true
	main.tip("ending")
	main.sfx("summit_win", 0.7, 0.0, 0.0)


## The ending dismissed: kept as seen, and the summit's flow goes on (the heirloom, the train).
func end_ending() -> void:
	if ending_view == null:
		return
	main.profile.note("ending")
	main.profile.save()
	var chose := Story.choice(main.profile)
	if chose != "":
		main.story("after_" + chose)  # (the Entity's word on it, once: entity.gd STORY)
		main.tip("story_" + chose)
	var layer = ending_view.get_parent()
	ending_view.queue_free()
	if layer != null:
		layer.queue_free()
	ending_view = null
	get_tree().paused = false
	main.end_regard()
	_ending_frame = Engine.get_process_frames()


class EndingView extends Control:
	## The ending, page by page (story_scenes.gd ending_pages: the choice, the
	## Entity's truth, what comes after), each a picture over its words; the
	## plain ENDING page when there's no choice. Enter, A, a click or a tap
	## turns the page once its words are in; Skip (the corner, or Esc) ends it.
	var shape
	var t := 0.0
	var clock := 0.0
	var page := 0
	var pages: Array = []
	var _us := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_us = Time.get_ticks_usec()
		pages = shape.Story.ending_pages(shape.main.profile)
		if pages.is_empty():
			pages = [{"title": String(shape.ENDING["title"]), "lines": shape.ENDING["lines"], "scene": "ring", "key": "plain"}]

	func lines() -> Array:
		return pages[page]["lines"]

	func last() -> bool:
		return page >= pages.size() - 1

	func ready_to_go() -> bool:
		return t > 1.2 + float(lines().size()) * 0.6

	## Turns the page, or ends the ending on the last one.
	func next() -> void:
		if not ready_to_go():
			return
		if last():
			shape.end_ending()
			return
		page += 1
		t = 0.0
		shape.main.sfx("ui_move", 0.6, -4.0, 0.0)

	func _process(_d: float) -> void:
		var now := Time.get_ticks_usec()
		var dt := minf((now - _us) / 1000000.0, 0.1)
		t += dt
		clock += dt
		_us = now
		queue_redraw()
		if shape.main.menu_open():
			return
		if Input.is_action_just_pressed("ui_cancel"):
			shape.end_ending()
		elif Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("attack"):
			next()

	func _gui_input(event: InputEvent) -> void:
		var tap: bool = (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		if not tap:
			return
		accept_event()
		if pages.size() > 1 and skip_rect().has_point(event.position):
			shape.end_ending()
		else:
			next()

	func skip_rect() -> Rect2:
		var vs := get_viewport_rect().size
		var sm := vs.y < 520.0
		var w := 74.0 if not sm else 60.0
		return Rect2(Vector2(vs.x - w - 12.0, 10.0), Vector2(w, 30.0 if not sm else 26.0))

	## Where the words of a page end (tests: it must fit above the prompt).
	func words_bottom(vs: Vector2, pg := -1) -> float:
		var p: Dictionary = pages[page if pg < 0 else pg]
		var font := ThemeDB.fallback_font
		var sm := vs.y < 520.0
		var rr := minf(vs.y * 0.15, 90.0)
		var y := vs.y * 0.3 + rr + (46.0 if not sm else 34.0)
		var fs := 17 if not sm else 15
		for l in p["lines"]:
			y += UI.text_height(font, String(l), vs.x - 48.0, fs) + (8.0 if not sm else 5.0)
		return y + (30.0 if not sm else 24.0)

	func _draw() -> void:
		var vs := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		var sm := vs.y < 520.0
		var a := clampf(clock / 1.0, 0.0, 1.0)
		var pa := clampf(t / 0.6, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.01, 0.008, 0.02, a))  # (opaque once in: nothing of the summit behind the words)
		var c := Vector2(vs.x * 0.5, vs.y * 0.3)
		var rr := minf(vs.y * 0.15, 90.0)
		var p: Dictionary = pages[page]
		var scene := String(p.get("scene", "ring"))
		if scene == "ring":
			# Six guardians' sigils in a ring: each tower's colour, lit one by one.
			var order: Array = shape.Towers.ORDER
			for i in order.size():
				var tw: Dictionary = shape.Towers.TOWERS[order[i]]
				var col: Color = shape.Essence.color(String(tw.get("essence", "air")))
				var lit := clampf((t - 0.3 - i * 0.15) / 0.4, 0.0, 1.0)
				var at := c + Vector2.from_angle(-PI * 0.5 + TAU * i / float(order.size())) * rr
				draw_circle(at, 13.0, Color(col, 0.18 * lit))
				draw_circle(at, 7.0, Color(col.lightened(0.2), 0.85 * lit))
				draw_arc(at, 13.0, 0.0, TAU, 24, Color(col, 0.6 * lit), 1.5, true)
				draw_line(c, at, Color(col, 0.25 * lit), 1.0, true)
			draw_circle(c, 5.0, Color(UI.GOLD, a))
		else:
			shape.Story.draw_scene(self, scene, c, rr, t, pa, shape.main.profile)
		var ty := c.y - rr - (40.0 if not sm else 30.0)
		UI.draw_label(self, Vector2(0, maxf(ty, 40.0 if not sm else 32.0)), String(p.get("title", "")), 34 if not sm else 26, Color(UI.GOLD, pa), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 6)
		var ly := c.y + rr + (46.0 if not sm else 34.0)
		var fs := 17 if not sm else 15
		var ls: Array = p["lines"]
		for i in ls.size():
			var la := clampf((t - 1.0 - i * 0.6) / 0.5, 0.0, 1.0)
			var h := UI.text_height(font, String(ls[i]), vs.x - 48.0, fs)
			UI.draw_text_lines(self, font, Vector2(24, ly), String(ls[i]), HORIZONTAL_ALIGNMENT_CENTER, vs.x - 48.0, fs, -1, Color(UI.TEXT, la))
			ly += h + (8.0 if not sm else 5.0)
		if last():
			var after := String(shape.ENDING["after"])
			draw_string(font, Vector2(24, ly + 8.0), after, HORIZONTAL_ALIGNMENT_CENTER, vs.x - 48.0, 15 if not sm else 13, Color(UI.DIM, clampf((t - 1.0 - ls.size() * 0.6) / 0.5, 0.0, 1.0)))
		# Page dots, and Skip.
		if pages.size() > 1:
			for i in pages.size():
				draw_circle(Vector2(24.0 + i * 14.0, vs.y - (27.0 if not sm else 19.0)), 3.0, Color(UI.GOLD, 0.9 if i == page else 0.3))
			var sr := skip_rect()
			draw_style_box(UI.panel(), sr)
			var mm = shape.main
			var label: String = String(shape.Story.TEXT["ending_skip"]) + ("" if mm.touch_active or mm.pad_active else " (Esc)")
			UI.draw_text(self, font, Vector2(sr.position.x, sr.position.y + sr.size.y * 0.5 + 5.0), label, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 13 if not sm else 12, UI.DIM)
		if ready_to_go():
			var m = shape.main
			var pulse := 0.5 + 0.5 * sin(clock * 4.0)
			var how: String = "Tap" if m.touch_active else (shape.Controls.pad_text("Press {a}", m.pad_ps) if m.pad_active else "Press Enter or click")
			var what := String(shape.ENDING["go_on"]) if last() else String(shape.Story.TEXT["ending_go_on"])
			draw_string(font, Vector2(0, vs.y - (22.0 if not sm else 14.0)), how + " " + what, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 15 if not sm else 13, Color(UI.DIM, 0.5 + 0.5 * pulse))


# --- drawing -----------------------------------------------------------------------------

## On the floor: the gate's shadow, or the ward's glow on the ground.
func _draw() -> void:
	pass


## Over the darkness: the gate or the ward as it forms, its timer, cracks.
func _draw_over() -> void:
	drawn = Rect2()
	if bar.is_empty() or main == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	var r: Rect2 = bar["rect"]
	drawn = r
	var st: String = bar["state"]
	var col := color()
	var b := Draw.Batch.new()
	var c := r.get_center()
	if float(bar["shudder"]) > 0.0:
		var s := float(bar["shudder"])
		r.position += Vector2(sin(t * 70.0), cos(t * 53.0)) * 2.5 * s
	var k := clampf(float(bar["t"]) / maxf(float(bar["window"]), 0.01), 0.0, 1.0)
	if st in ["up", "slipped"]:
		k = 1.0
	if st == "open":
		k = 0.0
	if bar["kind"] == "gate":
		_gate_into(b, r, k, st, t)
	else:
		_ward_into(b, r, k, st, t, col)
	# Cracks, by how much it has taken.
	var dmg := float(bar["dmg"])
	if dmg > 0.0 and st in ["forming", "up"]:
		var dk := clampf(dmg / float(bar["hp"]), 0.0, 1.0)
		var n := 3 + int(dk * 8.0)
		for i in n:
			var ang := float(i) * 2.399
			var p1 := c + Vector2.from_angle(ang) * (8.0 + 16.0 * dk) + Vector2.from_angle(ang + 1.6) * 3.0
			var p2 := c + Vector2.from_angle(ang + 0.2) * (14.0 + 26.0 * dk)
			b.line(c, p1, Color(0.04, 0.03, 0.05, 0.85), 2.4)
			b.line(p1, p2, Color(0.04, 0.03, 0.05, 0.85), 1.8)
			b.line(c, p1, Color(col.lightened(0.4), 0.5 + 0.4 * dk), 1.0)
	b.flush(over)
	# The timer: a ring over the barrier counting down, gold to red, and its seconds.
	var font := UI.font("display")
	if st == "forming":
		var left := maxf(0.0, float(bar["window"]) - float(bar["t"]))
		var at := Vector2(c.x, r.position.y - 26.0)
		var urgent := clampf(1.0 - left / 10.0, 0.0, 1.0)
		var rc := UI.GOLD.lerp(Color(1.0, 0.3, 0.25), urgent)
		over.draw_circle(at, 15.0, Color(0.03, 0.025, 0.05, 0.85))
		over.draw_arc(at, 15.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - k), 32, rc, 3.0, true)
		over.draw_string(font, at + Vector2(-20, 6), str(int(ceil(left))), HORIZONTAL_ALIGNMENT_CENTER, 40, 16, rc.lightened(0.2))
		# What to do about it, beside the ring.
		var label := String(TEXT["gate_label" if bar["kind"] == "gate" else "ward_label"])
		UI.draw_label(over, at + Vector2(21.0, 5.0), label, 13, Color(rc, 0.95), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)
	elif st in ["slipped", "broken"] and horde_total > 0 and not refusing:
		var label2 := String(TEXT["horde_left"]) % horde_left()
		UI.draw_label(over, Vector2(c.x - 90.0, r.position.y - 20.0), label2, 14, Color(1.0, 0.5, 0.42), HORIZONTAL_ALIGNMENT_CENTER, 180.0, 4)


## The iron gate: two posts and a lintel; its bars come down as it forms
## (`k` 0..1), slammed shut behind a slip, bent and scattered once broken.
func _gate_into(b, r: Rect2, k: float, st: String, t: float) -> void:
	var post := Color(0.32, 0.3, 0.35)
	var iron := Color(0.5, 0.48, 0.54)
	var dark := Color(0.06, 0.05, 0.07)
	# Posts and lintel.
	for x in [r.position.x, r.end.x - 8.0]:
		b.rect(Rect2(Vector2(x, r.position.y - 6.0), Vector2(8.0, r.size.y + 6.0)), dark)
		b.rect(Rect2(Vector2(x + 1.0, r.position.y - 5.0), Vector2(6.0, r.size.y + 4.0)), post)
	b.rect(Rect2(Vector2(r.position.x - 4.0, r.position.y - 12.0), Vector2(r.size.x + 8.0, 9.0)), dark)
	b.rect(Rect2(Vector2(r.position.x - 3.0, r.position.y - 11.0), Vector2(r.size.x + 6.0, 7.0)), post.lightened(0.1))
	if st == "broken":
		# Bent bars on the ground before the stair.
		for i in 6:
			var x0 := r.position.x + 12.0 + i * 11.0
			var y0 := r.end.y + 4.0 + float(i % 3) * 4.0
			b.line(Vector2(x0, y0), Vector2(x0 + 14.0, y0 - 3.0 + float(i % 2) * 6.0), dark, 4.0)
			b.line(Vector2(x0, y0), Vector2(x0 + 14.0, y0 - 3.0 + float(i % 2) * 6.0), iron, 2.0)
		return
	var bottom := r.position.y - 4.0 + (r.size.y + 2.0) * k
	if st == "open":
		bottom = r.position.y + 2.0
	var bars := 7
	for i in bars:
		var x := r.position.x + 12.0 + float(i) * (r.size.x - 24.0) / float(bars - 1)
		b.line(Vector2(x, r.position.y - 4.0), Vector2(x, bottom), dark, 6.0)
		b.line(Vector2(x, r.position.y - 4.0), Vector2(x, bottom), iron, 3.4)
		b.line(Vector2(x - 0.8, r.position.y - 4.0), Vector2(x - 0.8, bottom), iron.lightened(0.3), 1.0)
		# Spiked feet.
		if bottom > r.position.y + 4.0:
			b.line(Vector2(x - 3.0, bottom - 3.0), Vector2(x, bottom + 4.0), dark, 3.0)
			b.line(Vector2(x + 3.0, bottom - 3.0), Vector2(x, bottom + 4.0), dark, 3.0)
			b.line(Vector2(x - 2.5, bottom - 3.0), Vector2(x, bottom + 3.5), iron.lightened(0.25), 1.6)
			b.line(Vector2(x + 2.5, bottom - 3.0), Vector2(x, bottom + 3.5), iron.lightened(0.25), 1.6)
	for yy in [0.3, 0.7]:
		var y: float = r.position.y - 4.0 + (bottom - r.position.y + 4.0) * float(yy)
		if bottom - r.position.y > 10.0:
			b.line(Vector2(r.position.x + 8.0, y), Vector2(r.end.x - 8.0, y), dark, 6.0)
			b.line(Vector2(r.position.x + 8.0, y), Vector2(r.end.x - 8.0, y), iron.darkened(0.1), 3.0)
	if st == "forming":
		# The gap under it: where a roll goes. A glint along its lowest edge.
		var glint := 0.5 + 0.5 * sin(t * 6.0)
		b.line(Vector2(r.position.x + 8.0, bottom + 3.0), Vector2(r.end.x - 8.0, bottom + 3.0), Color(1.0, 0.85, 0.5, 0.35 + 0.4 * glint), 1.5)
	if st == "slipped":
		b.line(Vector2(r.position.x + 8.0, r.end.y), Vector2(r.end.x - 8.0, r.end.y), Color(1.0, 0.4, 0.3, 0.6 + 0.3 * sin(t * 5.0)), 2.0)


## The ward: a pane of the tower's essence rising from the floor (`k`),
## lattice-lit, pulsing once up; shards on the floor once broken.
func _ward_into(b, r: Rect2, k: float, st: String, t: float, col: Color) -> void:
	if st == "broken":
		for i in 9:
			var at := Vector2(r.position.x + 8.0 + fmod(i * 23.7, r.size.x - 16.0), r.end.y + 4.0 + fmod(i * 7.3, 12.0))
			var fade := 0.6
			b.line(at, at + Vector2(5.0, -3.0).rotated(i * 0.9), Color(col, fade), 2.0)
		return
	if st == "open":
		return
	var h := r.size.y * k
	var top := r.end.y - h
	var pulse := 0.5 + 0.5 * sin(t * (3.0 if st == "forming" else 1.6))
	b.rect(Rect2(Vector2(r.position.x - 4.0, top), Vector2(r.size.x + 8.0, h)), Color(col, 0.26 + 0.12 * pulse))
	b.rect(Rect2(Vector2(r.position.x - 4.0, top), Vector2(3.0, h)), Color(col.lightened(0.4), 0.8))
	b.rect(Rect2(Vector2(r.end.x + 1.0, top), Vector2(3.0, h)), Color(col.lightened(0.4), 0.8))
	# A lattice of light.
	var step := 10.0
	var x := r.position.x
	while x <= r.end.x + 0.1:
		b.line(Vector2(x, maxf(top, r.position.y)), Vector2(x, r.end.y), Color(col.lightened(0.3), 0.25 + 0.2 * pulse), 1.0)
		x += step
	var y := r.end.y
	while y >= top:
		b.line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(col.lightened(0.3), 0.2 + 0.15 * pulse), 1.0)
		y -= step
	# Its rising edge, bright, and runes at its feet.
	b.line(Vector2(r.position.x, top), Vector2(r.end.x, top), Color(col.lightened(0.5), 0.7 + 0.3 * pulse), 2.0)
	for i in 5:
		var rx := r.position.x + 8.0 + i * (r.size.x - 16.0) / 4.0
		b.dot(Vector2(rx, r.end.y + 3.0), 2.2, Color(col.lightened(0.4), 0.6 + 0.4 * sin(t * 4.0 + i)))
	if st == "slipped":
		b.line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Color(1.0, 0.4, 0.3, 0.6 + 0.3 * sin(t * 5.0)), 2.0)
