extends "res://scripts/puzzles/base.gd"
## HALL OF EYES: stone eyes behind low rails (a hand-made room, rooms.gd).
## Hit every eye with a strike or an arrow (arrows fly over the rails).
## Tier 2: an eye only stays lit for EYE_WINDOW seconds, so all must be lit
## together; tier 3: a shorter window still.

const NAME := "Hall of Eyes"
const TEXT := {
	"rule": ["Wake every eye. Strike them, or shoot over the rails."],
	"rule_timed": ["Wake every eye together: each one sleeps again soon after."],
	"quiet": "The eyes stay shut while blood is spilled. Deal with the guards first.",
	"arc": "The spark leaps to another eye",
}
const BREAKS := {"stormcaller": "Static: an eye you wake throws a spark to the nearest sleeping eye."}
const SEAL_FROM := 99
const MODES := ["quiet", "pressure"]
## Harder eyes: an eye stays lit this long after it's hit (tier 2, tier 3).
const EYE_WINDOW := 2.5
const EYE_WINDOW_HARD := 1.8
## How far Static's spark leaps.
const ARC_REACH := 280.0

var eyes: Array = []  # {pos, lit}  lit: seconds left lit (INF once lit, on easy floors)


static func make(_rect: Rect2, _floor_num: int, _tier: int, ctx: Dictionary) -> Dictionary:
	var f: Dictionary = ctx.get("features", {})
	if f.get("eyes", []).is_empty():
		return {}
	return {"eyes": f["eyes"], "rails": f.get("rails", []), "gates": f.get("gates", []), "rewards": f.get("rewards", [])}


func _build() -> void:
	for p in spec.get("eyes", []):
		eyes.append({"pos": p, "lit": 0.0})


func window() -> float:
	return EYE_WINDOW_HARD if tier >= 3 else EYE_WINDOW


func tick(delta: float) -> void:
	if tier >= 2:
		for e in eyes:
			if e["lit"] > 0.0 and e["lit"] < INF:
				e["lit"] = maxf(0.0, e["lit"] - delta)
	_check()


func _check() -> void:
	if eyes.is_empty():
		return
	for e in eyes:
		if e["lit"] <= 0.0:
			return
	host.solve()


func reset() -> void:
	for e in eyes:
		e["lit"] = 0.0


func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> int:
	var hits := 0
	for e in eyes:
		if in_swing(from, dir, e["pos"], reach, arc_deg):
			_light(e)
			hits += 1
	return hits


func shot(pos: Vector2) -> bool:
	for e in eyes:
		if pos.distance_to(e["pos"]) < 17.0:
			_light(e)
			return true
	return false


func _light(e: Dictionary, spark := true) -> void:
	if host.solved or not host.awake:
		return
	var was: float = e["lit"]
	e["lit"] = window() if tier >= 2 else INF
	if was <= 0.0:
		main.sfx("glint", 1.1, -2.0, 0.0)
		main.fx_ring(e["pos"], Color(1.0, 0.85, 0.45), 30.0, 0.3, 2.5)
		main.light_flash(e["pos"], Color(1.0, 0.8, 0.4), 0.8, 1.2, 0.3)
		# Stormcaller's Static: the spark leaps to the nearest sleeping eye.
		if spark and has_bond("stormcaller"):
			var best = null
			var best_d := ARC_REACH
			for o in eyes:
				var d: float = o["pos"].distance_to(e["pos"])
				if o != e and o["lit"] <= 0.0 and d < best_d:
					best_d = d
					best = o
			if best != null:
				main.fx_bolt([e["pos"], best["pos"]], Color(0.95, 0.89, 0.42))
				main.fx_text(best["pos"] + Vector2(0, -26), TEXT["arc"], Color(0.95, 0.89, 0.42))
				_light(best, false)
	_check()  # (at once, not on the next tick)


func aim_points() -> Array:
	var out: Array = []
	for e in eyes:
		if e["lit"] <= 0.0:
			out.append(e["pos"])
	return out


func panels() -> Array:
	if not player_in_room(20.0) or eyes.is_empty():
		return []
	return [{"pos": Vector2(room.get_center().x, room.end.y + 6.0), "below": true, "title": host.display_name().to_upper(), "lines": TEXT["rule_timed"] if tier >= 2 else TEXT["rule"]}]


func lights() -> Array:
	var out: Array = []
	for e in eyes:
		var lit: bool = e["lit"] > 0.0 or host.solved
		out.append([e["pos"], 130.0 if lit else 70.0, Color(1.0, 0.82, 0.42), 0.75 if lit else 0.35, 0.35 if lit else 0.08])
	return out


## The eyes: a stone socket; dull while shut, gold while lit.
func draw_glow(ci: CanvasItem, t: float) -> void:
	var stone := Color(0.5, 0.47, 0.52)
	var dark := Color(0.12, 0.11, 0.14)
	for e in eyes:
		var c: Vector2 = e["pos"]
		var lit: bool = e["lit"] > 0.0 or host.solved
		ci.draw_circle(c, 15.0, dark)
		ci.draw_circle(c, 13.0, stone)
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			pts.append(c + Vector2(cos(a) * 11.0, sin(a) * (7.0 if lit else 2.5)))
		ci.draw_colored_polygon(pts, Color(1.0, 0.85, 0.45) if lit else Color(0.25, 0.2, 0.3))
		if lit:
			ci.draw_circle(c, 3.5, Color(0.25, 0.1, 0.05))
		elif not host.solved and host.awake:
			# A faint pulse so it reads as something to hit.
			var pulse := 0.45 + 0.3 * sin(t * 3.0)
			ci.draw_arc(c, 18.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.5, pulse), 1.5)
		# Harder floors: a ring that runs down while the eye stays lit.
		if tier >= 2 and not host.solved and e["lit"] > 0.0 and e["lit"] < INF:
			ci.draw_arc(c, 19.0, -PI / 2.0, -PI / 2.0 + TAU * e["lit"] / window(), 24, Color(1.0, 0.85, 0.45, 0.9), 2.0)
