extends "res://scripts/enemy.gd"
## THE ASHWING: the Firebird's own creature (kind "ashwing"; enemy.gd
## SUBKINDS spawns it with this script). An ember-bird that circles, glints
## and dives through where you stood, trailing fire. The first time it falls
## it sinks into a heap of glowing ash and rises again, unless its ash is
## struck or soaked first. Its behaviour, drawing and numbers live in
## towers/creatures.gd (RULES, TEXT), shared with the briar.

const Creatures := preload("res://scripts/towers/creatures.gd")


func setup(k: String, room) -> void:
	super.setup(k, room)
	Creatures.setup(self)


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	Creatures.act(self, delta, dir, dist, p)


func _draw_own(p, t: float, f: Vector2) -> void:
	Creatures.draw(self, p, _glow, t, f)


func _overlay_extra(o) -> void:
	Creatures.overlay(self, o)


func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	Creatures.intercept(self, amount, dir, heavy)  # (a blow on its ash scatters it)
	super.take_hit(amount, dir, force, heavy, pierce)


func _refuse_death() -> bool:
	return Creatures.on_lethal(self)  # (the first fall: it sinks into ash)
