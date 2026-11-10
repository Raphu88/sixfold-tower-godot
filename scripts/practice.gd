extends Node
## The practice room (main.gd owns one: `main.practice`): from the train's
## Abilities page, "Try your abilities" drops the climber into a quiet room
## with a few training dummies (dummy.gd) that take hits and show damage but
## never attack. Marks and techniques stay full (a cast refills them in a
## moment); strain still builds, so the Unbound can feel it, but nothing
## here can fell you. Nothing done here is kept: the climber's save is left
## alone (profile.saving is off), and leaving goes back to the train by
## starting the scene afresh, as a fall does (main.gd back_to_train). The
## pause menu offers "Back to the train"; so does a restart.
## Words and numbers are here.

const Dummy := preload("res://scripts/dummy.gd")
const Towers := preload("res://scripts/towers.gd")

const TEXT := {
	"title": "PRACTICE",
	"lines": ["Training dummies take your hits and never strike back.", "Your abilities refill as you go. Nothing here is kept."],
	"leave": "Back to the train",
	"paused": "Practice",
	"sub": "Training dummies  ·  nothing kept",
	"hint": "Practice  ·  {menu}, then Back to the train",
	"pause_note": "Nothing done here is kept.",
}
## Where the dummies stand, from the room's centre.
const SPOTS := [Vector2(-170, -40), Vector2(0, -110), Vector2(170, -40)]
## Each ability refills to full this fast (a share of its capacity a second),
## starting this long after it was last cast or spent.
const REFILL := 0.8
const REFILL_WAIT := 0.6

## Leaving: the train opens on this page (menu.gd) once the scene starts afresh.
static var reopen := ""

var main
var on := false
var dummies: Array = []
var _was_saving := true
var _was_no_death := false
var _wait := {}  # part -> seconds until it refills


## Into the practice room, from the train (the Abilities page's button).
func start() -> void:
	if on or main == null or main.player == null:
		return
	on = true
	_was_saving = main.profile.saving
	main.profile.saving = false  # (nothing done here is kept)
	_was_no_death = main.dev_no_death
	main.dev_no_death = true
	var m = main.menu
	main.on_train = false
	main.choosing_tower = false
	main.in_camp = false
	if m != null and m.is_open():
		m.close()
	if not Towers.TOWERS.has(main.tower):
		main.tower = Towers.ORDER[0]
	main._apply_tower_look()
	main._start_floor(1)  # (with this room's plan: plan())
	var p = main.player
	p.dead = false
	p.hp = p.max_hp
	p.sta = p.max_sta
	p.poison_t = 0.0
	p.set_physics_process(true)
	_spawn_dummies()
	_fill_all()
	main.banner = {"title": TEXT["title"], "lines": TEXT["lines"], "t": 4.0}
	main.sfx("ready", 0.9, -4.0, 0.0)


## This room's plan for main.gd _start_floor: open floor, no monsters, the
## stair out of reach (the way out is the pause menu).
func plan() -> Dictionary:
	var room: Rect2 = main.OPEN_ROOM
	return {"monsters": [], "pillars": [], "start": room.get_center() + Vector2(0, 110),
		"stair": Vector2(room.get_center().x, room.position.y - 4000.0), "practice": true}


func _spawn_dummies() -> void:
	dummies.clear()
	var c: Vector2 = main.OPEN_ROOM.get_center()
	for spot in SPOTS:
		var d = Dummy.new()
		d.setup_dummy(main)
		d.position = c + spot
		main.add_child(d)
		dummies.append(d)
	main.floor_total = dummies.size()


func _fill_all() -> void:
	var p = main.player
	for b in p.bonds.values():
		b.essence = b.capacity()
		b.burned = false
	_wait.clear()


## Back to the train: the scene starts afresh (the save was never touched).
func leave() -> void:
	if not on:
		return
	reopen = "abilities"
	main.profile.saving = _was_saving
	main.dev_no_death = _was_no_death
	if main.get_tree().current_scene == main:
		on = false
		main.get_tree().paused = false
		main.get_tree().reload_current_scene()
		return
	# (Tests run the room outside a scene: clear up and open the train here.)
	on = false
	for d in dummies:
		if is_instance_valid(d):
			d.queue_free()
	dummies.clear()
	if main.menu != null and main.menu.is_open():
		main.menu.close()
	main.await_tower()
	main.open_train()
	after_train(main)


## The train has opened (main.gd): back on the page practice was started from.
static func after_train(m) -> void:
	if reopen == "" or m == null or m.menu == null:
		return
	var page := reopen
	reopen = ""
	m.menu.open(page)


func _physics_process(delta: float) -> void:
	if not on or main == null or main.player == null:
		return
	var p = main.player
	# Every ability refills a moment after it was spent.
	for part in p.bonds:
		var b = p.bonds[part]
		if b.essence >= b.capacity() - 0.01:
			_wait.erase(part)
			continue
		var w: float = float(_wait.get(part, REFILL_WAIT)) - delta
		_wait[part] = w
		if w <= 0.0:
			b.essence = minf(b.capacity(), b.essence + b.capacity() * REFILL * delta)
		b.burned = false
	p.sta = minf(p.max_sta, p.sta + 30.0 * delta)
	if p.hp < p.max_hp:
		p.hp = minf(p.max_hp, p.hp + 20.0 * delta)
	p.poison_t = 0.0
