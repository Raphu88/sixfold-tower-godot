extends "res://scripts/enemy.gd"
## THE BRIAR: the Chimera's thicket lurker (kind "briar"; enemy.gd SUBKINDS
## spawns it with this script). It hides as a bush, often beside brambles;
## come close and it lashes out, grabs you and drags you toward it (a roll
## breaks free), then stands and swipes until it can hide again. Fire
## flushes it out of hiding. Its behaviour, drawing and numbers live in
## towers/creatures.gd (RULES, TEXT), shared with the ashwing.

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
	Creatures.intercept(self, amount, dir, heavy)  # (struck while hiding: it's out)
	super.take_hit(amount, dir, force, heavy, pierce)


## Fire flushes it out of hiding (chimera_floor.gd blast).
func flush() -> void:
	Creatures.flush(self)
