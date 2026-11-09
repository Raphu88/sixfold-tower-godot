extends "res://scripts/bond.gd"
## One of the Unbound's six carried techniques, standing in a mark's place
## on the climber (player.bonds, keyed by the button that casts it), so the
## same buttons, rings, HUD medallions and touch buttons cast it. Its
## "essence" is the headroom its body part has before it erupts
## (100 - strain), so the gauge empties as the part strains and a technique
## that would erupt shows unready. It never burns or goes faint: strain
## (unbound_run.gd) takes their place.

const Tech := preload("res://scripts/technique.gd")
const UnboundData := preload("res://scripts/unbound.gd")

var tech: Dictionary
var slot := 0
var run  # unbound_run.gd
var _data := {}


func _init(t: Dictionary, slot_part: String, slot_index: int, the_run) -> void:
	super("technique", slot_part)
	tech = t
	slot = slot_index
	run = the_run
	var sp := {"id": "tech_%d" % slot_index, "name": Tech.title(t), "desc": Tech.describe(t), "type": "technique", "learn": 1,
		"steps": {1: {"cost": Tech.strain(t), "windup": Tech.windup(t), "damage": float(Tech.SHAPES[t["shape"]].get("damage", 0.0))}}}
	var lead := Tech.lead(t)
	_data = {"name": Tech.title(t), "color": Tech.color(lead), "affinity": lead if lead in UnboundData.NATURAL else "",
		"spells": [sp], "body": {"name": UnboundData.TEXT["name"]}, "passive": {"name": UnboundData.TEXT["name"]},
		"style": [], "technique": true}
	essence = 100.0


func data() -> Dictionary:
	return _data


## The body part it strains (not the button it's on).
func tech_part() -> String:
	return String(tech["part"])


func capacity() -> float:
	return 100.0


## What a cast adds to its part's strain.
func cost() -> float:
	return Tech.strain(tech)


func spells() -> Array:
	return _data["spells"]


func color() -> Color:
	var col: Color = _data["color"]
	if run != null:
		var s: float = run.strain_of(tech_part())
		if s > run.HOT:
			col = col.lerp(Color(1.0, 0.3, 0.2), clampf((s - run.HOT) / (100.0 - run.HOT), 0.0, 1.0) * 0.7)
	return col


func fill(_amount: float) -> void:
	pass  # (strain, not essence, is what a technique answers to)


## True while its part is dark (an eruption): it can't be cast.
func blocked() -> bool:
	return run != null and run.is_dark(tech_part())


func pay(_free := false) -> String:
	overdraw_mult = 1.0
	missing = 0.0
	return "paid"


func cast(p) -> void:
	if run != null:
		run.cast(self, p)


## The HUD draws its part's strain under the medallion.
func hud_into(b, c: Vector2, r: float) -> void:
	if run != null:
		run.strain_hud_into(b, c, r, tech_part())


## The HUD's tooltip: what it does, its part's strain, its cost.
func tip_lines(key: String, touch: bool) -> Array:
	var part := tech_part()
	var s: float = run.strain_of(part) if run != null else 0.0
	return [Tech.describe(tech),
		"%s strain %d / 100  ·  +%d a cast  ·  costs %s" % [UnboundData.PART_NAMES[part], int(s), int(Tech.strain(tech)), Tech.cost_text(tech, run.main.profile if run != null else null)],
		"Its button is on the right" if touch else "Press %s to cast" % key]
