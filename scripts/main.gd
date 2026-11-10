extends Node2D
## Prototype room: one fight to test whether bonds feel good.
## Builds the walls, spawns the climber and three kinds of monster.

const Controls := preload("res://scripts/controls.gd")
const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const FxScript := preload("res://scripts/fx.gd")
const HudScript := preload("res://scripts/hud.gd")
const AudioScript := preload("res://scripts/audio.gd")
const RoomScript := preload("res://scripts/room.gd")
const Palette := preload("res://scripts/palette.gd")
const TouchScript := preload("res://scripts/touch.gd")
const PadScript := preload("res://scripts/pad.gd")
const Floors := preload("res://scripts/floors.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const Essence := preload("res://scripts/essence.gd")
const BondScript := preload("res://scripts/bond.gd")
const Towers := preload("res://scripts/towers.gd")
const MenuScript := preload("res://scripts/menu.gd")
const Items := preload("res://scripts/items.gd")
const Gear := preload("res://scripts/gear.gd")
const FogScript := preload("res://scripts/fog.gd")
const PuzzleScript := preload("res://scripts/puzzle.gd")
const CampfireScript := preload("res://scripts/campfire.gd")
const Traps := preload("res://scripts/traps.gd")
const LightingScript := preload("res://scripts/lighting.gd")
const DoorsScript := preload("res://scripts/doors.gd")
const Themes := preload("res://scripts/themes.gd")
const WingsScript := preload("res://scripts/wings.gd")
const GuideScript := preload("res://scripts/guide.gd")
const Slots := preload("res://scripts/slots.gd")
const ClimbersPage := preload("res://scripts/climbers_page.gd")
const Train := preload("res://scripts/train.gd")
const Lost := preload("res://scripts/lost.gd")
const Vessel := preload("res://scripts/vessel.gd")
const ProvingScript := preload("res://scripts/proving.gd")
const Secret := preload("res://scripts/secret.gd")
const Appearance := preload("res://scripts/appearance.gd")
const MakersScript := preload("res://scripts/makers.gd")
const MirrorScript := preload("res://scripts/mirror.gd")
const SecretBonds := preload("res://scripts/secret_bonds.gd")
const SecretToolsScript := preload("res://scripts/secret_tools.gd")
const UnboundRun := preload("res://scripts/unbound_run.gd")
const DataRegistry := preload("res://scripts/data_registry.gd")
## The stair opens once this share of a floor's monsters are down.
const STAIR_OPENS_AT := 0.75

const STAIR_REACH := 26.0

const WALL := 24.0

## The single open room of floor 1 and the beast's floor. Floors of rooms
## and corridors use a bigger area that grows with height (Floors.arena_for).
const OPEN_ROOM := Rect2(80, 100, 1120, 530)
## The owner's changes to the game's words, numbers and colours (the Data
## editor: data_registry.gd), applied first, before anything reads the tables.
var _data_changes := DataRegistry.startup()
var room := OPEN_ROOM
var outer_walls: Array = []
# Rooms and corridors: a tile grid of what's solid, and paths around it.
var layout_on := false
var grid_size := Vector2i.ZERO
var solid := PackedByteArray()
var astar: AStarGrid2D
var layout_bodies: Array = []
var layout_rooms: Array = []
var layout_blocks: Array = []  # cover inside rooms (Rect2, solid tiles)
var side_room := Rect2()  # the room holding the floor's essence cache, if it has one
var cache := {}  # its essence cache: {pos, amount, kind, taken}
var layout_torches: Array = []  # where each room's torch hangs (narrow rects, floors.gd)
# What each room of a floor of rooms is (floors.gd, themes.gd).
var room_info: Array = []  # {rect, role, theme, walk, ambush, ...}
var room_themes: Array = []  # each room's theme id, in step with room_info
var room_entered := {}  # rooms walked into this floor (index -> true)
var room_at := -1  # the room the climber stands in (-1 in a corridor)
var room_tile := Vector2i(-999, -999)  # the tile room_at was worked out on
var room_pending := -1  # a room whose name waits for the banner to clear
var springs: Array = []  # healing springs: {pos, r, left}
var door_view  # the floor's doors (doors.gd)
var wings  # the floor's sealed wings, vaults and secret rooms (wings.gd)
var proving  # floor 6's Proving, and its lingering wound (proving.gd)
var makers  # the Makers: their fragments, glimpses and meetings (makers.gd)
var recall_ask_t := 0.0  # a recall scroll asked to be read: use it again before this runs out
var floor_plan := {}  # this floor's plan, as floors.gd made it (rooms, themes, doorways...)
var player
var fx
var camera: Camera2D
# The climber's position at the last two physics ticks: the camera follows
# the point between them, as the drawing does (physics interpolation), so it
# glides at any screen refresh rate instead of jittering on 90/120 Hz screens.
var cam_prev := Vector2.ZERO
var cam_curr := Vector2.ZERO
var cleared := false
var shake_amount := 0.0
var shake_ms := 0  # when the shake offset last changed
var audio
var hitstop_until := 0  # real-time msec when the freeze ends
var hurt_flash := 0.0
var lighting  # the darkness layer and its lights (lighting.gd)
var touch_active := false  # on-screen controls in use
var pad_active := false  # the last input came from a game controller (pad.gd)
var pad_ps := false  # ...and it's a PlayStation one (for button names)

# The climb
var floor_num := 1
var best_floor := 1
var pillars: Array = []  # {pos, r}
var pillar_bodies: Array = []
var stair_open := false
var stair_pos := Vector2.ZERO
var climbing := false
var fade := 0.0  # black screen between floors, 0..1
var banner := {}  # {title, lines, t}: shown when a floor starts
var room_view
var player_start := Vector2.ZERO

# Marks and essence
var profile  # what carries over between climbs (profile.gd)
var first_climb := false  # bondless, ending in the Regard
var run_essence := {}  # gathered since the last stair (lost if you fall)
var run_soak := {}  # body-part soak since the last stair
var climb_essence := {}  # everything gathered this climb
var climb_soak := {}  # everything soaked this climb
## The secret essences (secret.gd): the path's essence gathered since the
## last stair (the flow, unbanked: lost if you fall), and what rose before
## the path was chosen, waiting on the choice ({kind, amount, pos}).
var run_flow := 0.0
var secret_pending: Array = []
var secret_on := not Engine.has_meta("sixfold_test")  # (tests switch it on when they want great foes to leave it)
var regard := {}  # the Regard, while it plays: {fell, part, id, t}
var regard_pending := false
var victory := {}  # the climb complete screen, after the beast falls: {t, beast, lines}
var tower := "kraken"  # which tower this climb is in (towers.gd)
var choosing_tower := false  # the tower choice is showing
var on_train := false  # between climbs, after the Regard: the train (train.gd) stands in for the tower choice
var floor_total := 0  # monsters this floor started with
var hud
var touch
var pad  # the game controller (pad.gd)
var menu  # title, pause, settings and dev tool (menu.gd)
var entity  # the Entity's bubble in play (guide.gd); main.tip("id") for a new system
var arrange  # Arrange mode (arrange.gd): move and scale what's on screen; F2 or Dev tools
var dev_no_death := false  # dev tool: you can't fall
var secret_tools  # the secret bonds' tool ring and tools (secret_tools.gd)
var unbound  # the Unbound in a climb: strain, techniques, barriers (unbound_run.gd)
var counting_hits := false  # while a spell is cast: count the foes it hits
var cast_hits := 0
var new_climber_t := 0.0
## How the climber looks, worked out from profile.appearance once per change
## (appearance.gd look()): the climber screen's figure draws from it.
var climber_look := {}
## Restart is held (R, or View on a controller) so a stray press doesn't end
## the climb; once fallen, a press is enough.
const RESTART_HOLD := 0.8
const RESTART_ASK := 0.25  # held this long, a banner asks you to keep holding
var restart_t := 0.0
var restart_armed := false  # the press began on this floor (not before a reload)
## Keyboard and controller: the highlighted tower or camp card.
var card_focus := 0
var card_rep = preload("res://scripts/nav.gd").Repeat.new()  # the card screens' held directions
const CARD_KEYS := 6  # number keys 1 to 6 take a card directly (the rest: arrows and Enter)
var overlay_closed_frame := -1  # (so the Start that closed it doesn't also open the menu)

# Items and camps (items.gd)
var item_drops: Array = []  # items lying on the floor: {pos, id, t, hold (wait until you step off)}
var item_drop_chance := Items.DROP_CHANCE
var flasks: Array = []  # Fire Flasks in the air: {from, to, t, total, dmg, r}
var flare_t := 0.0  # Flare Powder: the room is lit and hidden things nearby glint
var flare_pos := Vector2.ZERO
var flare_light := -1
var loot_notice := {}  # a Rare (or better) find, fading in on the HUD: {text, color, t}
var belt_broken := false  # this climb's belt has broken into crystals
# The outfitter's pay for a climb (train.gd CLIMB_PAY), once, however it ends.
var climb_best0 := 0  # this tower's best floor before the climb (set as it starts)
var climb_paid := false
var pay_line := ""  # what he paid, for the end-of-climb screens ("" before)
# Gear (gear.gd): pieces lying on the floor, and the one you stand on.
var gear_drops: Array = []  # {pos, id (its base id), rec (the gear record)}
var gear_drop_chance := Gear.DROP_CHANCE
var gear_cache_chance := Gear.CACHE_CHANCE
var gear_here := {}  # the drop under you that needs Y (or Take) to swap for
var in_camp := false  # resting at a camp between floors (floor_num stays the floor below)
var camps_done: Array = []  # the floors whose camp has been visited this climb
var camp_choosing := false  # the camp's cards are showing
var camp := {}  # {stage: "item", "rune" or "heirloom", choices: [...], lines: [...]}
var heirloom_offered := false  # the heirloom choice has been shown this climb
# Falling and lost things (lost.gd).
var weapon_loss_chance := Lost.WEAPON_CHANCE  # a fall also takes the weapon in hand
var lost_cache_chance := 0.0 if Engine.has_meta("sixfold_test") else Lost.CACHE_CHANCE  # (tests set it when they want one)
var lost_cache := {}  # this floor's lost cache: {pos, entries (profile.lost entries), taken}
var fall_note: Array = []  # what the fall took, for the fall screen
## After the Regard, a fall shows what it took for a moment, then you're back
## on the train: on your own after FALL_WAIT seconds, or at once on a tap, a
## confirm key, R or the controller's View (not in the first FALL_GRACE
## seconds, so a press meant for the fight doesn't skip it).
const FALL_WAIT := 3.0
const FALL_GRACE := 0.6
var fall_t := -1.0  # seconds since falling (after the Regard); -1 while standing
var _fall_us := 0  # (real time: a hit-pause slows the game's own clock at the moment of a fall)
var campfire: Node2D

# Lingering spell effects in the room
var rod := {}  # Lightning Rod: {pos, t, reach}
var walls: Array = []  # Crosswind: {a, b, t, color}
var cyclones: Array = []  # Eye of the Storm: {pos, r, t, color}
var rains: Array = []  # Rain of Arrows: {pos, r, t, tick, damage, color}
var track_t := 0.0  # Track: foes revealed
var waves: Array = []  # Tidecaller's travelling waves: {pos, dir, width, left, dmg, push, carry, hit, color}
var maelstroms: Array = []  # Maelstrom whirlpools: {pos, r, t, damage, tick, color}
var fog  # line-of-sight fog on floors of rooms (fog.gd)
var puzzle  # the floor's puzzle, whose solving lifts the stair's ward (puzzle.gd)
var ward := false  # the stair is warded until the floor's puzzle is solved
var puddles: Array = []  # standing water (the Kraken's tower): {pos, r}
var flames: Array = []  # burning floor (the Wyvern's tower): {pos, r, t}
var meteors: Array = []  # Flame Contractor's Meteors, falling: {pos, r, dmg, t, color}
var grafts := {}  # Grafter: body part -> monster kind, for the rest of the climb
var graft_order: Array = []  # parts, oldest graft first
var graft_drops: Array = []  # grafts lying on the floor: {pos, kind, t}
var chasms: Array = []  # gaps in the floor (Rect2): jump across or fall
var chasm_bodies: Array = []
var traps: Array = []  # this floor's traps (traps.gd): {pos, kind, state, timer, hidden, hit}
var trap_view  # runs and draws them (traps.gd)
var runes: Array = []  # Rune Artist's Rune Traps: {pos, r, blast, damage, linked, color, t}
var wards: Array = []  # Ward Circles foes can't enter: {pos, r, t, color}
var sigils: Array = []  # Grand Sigils, free casting inside: {pos, r, t, color}
var stone_walls: Array = []  # Sandshaper's walls: {pos, r, t, body, fault}
var rubble: Array = []  # Quake rubble that slows foes: {pos, r, t}
var pits: Array = []  # Sinkholes (drawn only): {pos, r, t}
var clouds: Array = []  # Venomist's Toxic Clouds: {pos, r, t, tick, color}
var smokes: Array = []  # Ashwalker's Smoke Veils: {pos, r, t}
var decoys: Array = []  # Ashwalker's Afterimages: {pos, t, aim}
var ashfall_t := 0.0  # Ashfall: foes lose track of you once out of reach
var slowmo := false  # time stops while a ring is open (spells, items, tools)
const RING_TIME := 0.0  # the time scale while a ring is open: stopped
var pick_anchor := Vector2.ZERO  # touch: where the held mark button is on screen  # a first press asks; a second within this time confirms

# The monster lists, remembered for the frame (enemies(), targets()).
var foes_cache: Array = []
var targets_cache: Array = []
var foes_key := Vector2i(-1, -1)
var foes_dirty := true

# Attack turns: only this many monsters may be attacking at once.
const MAX_ATTACKERS := 2
var attackers: Array = []


func _ready() -> void:
	# Run after the bodies have moved, so the shove-apart pass sees this frame.
	process_physics_priority = 10
	randomize()
	Engine.time_scale = 1.0  # in case we restarted mid hit-pause
	Controls.setup()
	preload("res://scripts/ui.gd").setup_fonts()  # (the interface's fonts: ui.gd)
	# Where the HUD and the touch buttons sit (layout.gd): the shared defaults
	# and this player's own arrangement, loaded once.
	preload("res://scripts/layout.gd").ensure_loaded(Engine.has_meta("sixfold_test"))
	audio = AudioScript.new()
	add_child(audio)
	_build_walls()

	# Lighting: one darkness layer over the world (lighting.gd), with soft
	# holes of light around the climber, torches, the stair and flashes.
	RenderingServer.set_default_clear_color(Palette.VOID)
	y_sort_enabled = true  # lower things draw in front of higher things
	room_view = RoomScript.new()
	room_view.setup(room, WALL)
	add_child(room_view)
	trap_view = Traps.new()
	trap_view.main = self
	add_child(trap_view)
	door_view = DoorsScript.new()
	door_view.main = self
	add_child(door_view)
	wings = WingsScript.new()
	wings.main = self
	add_child(wings)
	proving = ProvingScript.new()
	proving.main = self
	add_child(proving)
	makers = MakersScript.new()
	makers.main = self
	add_child(makers)
	puzzle = PuzzleScript.new()
	puzzle.main = self
	add_child(puzzle)
	fog = FogScript.new()
	fog.main = self
	add_child(fog)
	lighting = LightingScript.new()
	lighting.main = self
	add_child(lighting)

	player_start = Vector2(room.get_center().x, room.end.y - 60.0)
	stair_pos = Vector2(room.get_center().x, room.position.y + 34.0)
	room_view.stair_pos = stair_pos
	player = PlayerScript.new()
	player.main = self
	player.position = Vector2(300, 365)  # floor 1 starts on the left, facing the fight
	add_child(player)

	profile = ProfileScript.new()
	if Engine.has_meta("sixfold_test"):
		profile.saving = false  # tests never touch the real save
	else:
		# The climber played last (slots.gd; an old single save moves into slot 1 first).
		profile.save_path = Slots.current_path()
		profile.load_save()
	best_floor = profile.best_floor
	first_climb = not profile.regarded
	unbound = UnboundRun.new()
	unbound.main = self
	add_child(unbound)
	_give_bonds()
	player.use_heirlooms(profile.heirlooms)
	apply_appearance()
	tower = profile.last_tower if Towers.TOWERS.has(profile.last_tower) else "kraken"
	_note_climb_start()
	_apply_tower_look()
	_start_floor(1)
	if Engine.has_meta("sixfold_test"):
		_greet()
	else:
		await_tower()

	fx = FxScript.new()
	fx.main = self
	fx.z_index = 10
	add_child(fx)

	# The camera follows the climber, zoomed in, but never past the walls.
	camera = Camera2D.new()
	camera.zoom = Vector2(1.35, 1.35)
	camera.position = player.position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = int(room.position.x - WALL - 20.0)
	camera.limit_right = int(room.end.x + WALL + 20.0)
	camera.limit_top = int(room.position.y - RoomScript.WALL_FACE - WALL - 20.0)
	camera.limit_bottom = int(room.end.y + WALL + 70.0)  # room for the bond HUD
	cam_prev = player.position
	cam_curr = player.position
	add_child(camera)
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # moved every frame, in _process
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
	hud.main = self
	hud.show_perf = bool(Engine.get_meta("sixfold_perf", false))
	layer.add_child(hud)
	touch = TouchScript.new()
	touch.main = self
	layer.add_child(touch)
	# The Entity's tips, over the touch buttons (so a tap on a bubble is its own).
	entity = GuideScript.new()
	entity.main = self
	layer.add_child(entity)
	pad = PadScript.new()
	pad.main = self
	add_child(pad)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	menu = MenuScript.new()
	menu.main = self
	menu_layer.add_child(menu)
	secret_tools = SecretToolsScript.new()
	secret_tools.main = self
	add_child(secret_tools)
	# Arrange mode, over everything (the menu included).
	var arrange_layer := CanvasLayer.new()
	arrange_layer.layer = 20
	add_child(arrange_layer)
	arrange = preload("res://scripts/arrange.gd").new()
	arrange.main = self
	arrange_layer.add_child(arrange)
	# A fresh start (not a restart or a new floor) opens on the title screen.
	if not Engine.has_meta("sixfold_test") and Engine.has_meta("sixfold_climbers"):
		# Back to the climber picker (after deleting the current climber).
		Engine.remove_meta("sixfold_climbers")
		menu.open_climbers.call_deferred()
	elif not Engine.has_meta("sixfold_test") and not Engine.has_meta("sixfold_title_seen"):
		menu.open.call_deferred("title")
	elif not profile.created and not Engine.has_meta("sixfold_test"):
		# A new climber (a new slot, or Start over) chooses a look first.
		menu.open.call_deferred("create")
	elif on_train:
		menu.open.call_deferred("train")


## A wall body of the last floor: it stops colliding at once (a freed body
## lingers until the frame ends, and would shove the new floor's monsters).
func _drop_body(b) -> void:
	if is_instance_valid(b):
		b.collision_layer = 0
		b.collision_mask = 0
		b.queue_free()


func _build_walls() -> void:
	for b in outer_walls:
		_drop_body(b)
	outer_walls.clear()
	var r := room
	var sides := [
		Rect2(r.position.x - WALL, r.position.y - WALL, r.size.x + WALL * 2.0, WALL),
		Rect2(r.position.x - WALL, r.end.y, r.size.x + WALL * 2.0, WALL),
		Rect2(r.position.x - WALL, r.position.y, WALL, r.size.y),
		Rect2(r.end.x, r.position.y, WALL, r.size.y),
	]
	for s in sides:
		var rect: Rect2 = s
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		outer_walls.append(body)


## Switches between the open room and the bigger area of a rooms floor.
func _set_arena(r: Rect2) -> void:
	if r == room:
		return
	room = r
	_build_walls()
	room_view.reconfigure(room)
	if camera != null:
		camera.limit_left = int(room.position.x - WALL - 20.0)
		camera.limit_right = int(room.end.x + WALL + 20.0)
		camera.limit_top = int(room.position.y - RoomScript.WALL_FACE - WALL - 20.0)
		camera.limit_bottom = int(room.end.y + WALL + 70.0)


## Builds the tile grid of a rooms floor: walkable inside the rooms and
## corridors, solid everywhere else; walls where solid meets walkable; and
## a path grid so monsters can find their way around the walls.
## `blocks` (cover inside rooms) are made solid too, one by one, and any that
## would cut `start` off from one of the `targets` is left out.
func _build_layout(walk: Array, blocks: Array = [], start := Vector2.ZERO, targets: Array = []) -> void:
	for b in layout_bodies:
		_drop_body(b)
	layout_bodies.clear()
	layout_blocks = []
	layout_on = not walk.is_empty()
	if not layout_on:
		solid = PackedByteArray()
		room_view.set_layout(Vector2i.ZERO, solid, [], [])
		return
	var c := Floors.CELL
	grid_size = Vector2i(int(room.size.x / c), int(room.size.y / c))
	solid = PackedByteArray()
	solid.resize(grid_size.x * grid_size.y)
	solid.fill(1)
	for r in walk:
		for t in _tiles_in(r):
			solid[t.y * grid_size.x + t.x] = 0
	astar = AStarGrid2D.new()
	astar.region = Rect2i(Vector2i.ZERO, grid_size)
	astar.cell_size = Vector2(c, c)
	astar.offset = room.position + Vector2(c, c) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in grid_size.y:
		for x in grid_size.x:
			if solid[y * grid_size.x + x] == 1:
				astar.set_point_solid(Vector2i(x, y), true)
	# Cover: keep each block only if everything that matters stays reachable.
	var from := _tile_of(start)
	var goals: Array = []
	if not _is_solid_tile(from.x, from.y):
		for g in targets:
			var t := _tile_of(g)
			if not _is_solid_tile(t.x, t.y):
				goals.append(t)
	for b in blocks:
		var tiles: Array = _tiles_in(b).filter(func(t): return not _is_solid_tile(t.x, t.y))
		for t in tiles:
			solid[t.y * grid_size.x + t.x] = 1
			astar.set_point_solid(t, true)
		var reachable := true
		for g in goals:
			if astar.get_id_path(from, g).is_empty():
				reachable = false
				break
		if reachable:
			layout_blocks.append(b)
		else:
			for t in tiles:
				solid[t.y * grid_size.x + t.x] = 0
				astar.set_point_solid(t, false)
	# Collision: solid tiles next to walkable ones, merged into runs per row.
	for y in grid_size.y:
		var run_start := -1
		for x in grid_size.x + 1:
			var edge := x < grid_size.x and _is_solid_tile(x, y) and _near_walkable(x, y)
			if edge and run_start < 0:
				run_start = x
			elif not edge and run_start >= 0:
				var rect := Rect2(room.position + Vector2(run_start, y) * c, Vector2(x - run_start, 1) * c)
				var body := StaticBody2D.new()
				body.collision_layer = 1
				body.collision_mask = 0
				body.position = rect.get_center()
				var shape := CollisionShape2D.new()
				var box := RectangleShape2D.new()
				box.size = rect.size
				shape.shape = box
				body.add_child(shape)
				add_child(body)
				layout_bodies.append(body)
				run_start = -1
	# One torch per room, over the middle of its north wall (floors.gd picks the spot).
	var lit: Array = layout_torches if not layout_torches.is_empty() else layout_rooms.duplicate()
	room_view.set_layout(grid_size, solid, lit, layout_blocks)


## The grid tiles a rect covers (inside the grid).
func _tiles_in(r: Rect2) -> Array:
	var c := Floors.CELL
	var list: Array = []
	for y in range(int((r.position.y - room.position.y) / c), int(ceil((r.end.y - room.position.y) / c))):
		for x in range(int((r.position.x - room.position.x) / c), int(ceil((r.end.x - room.position.x) / c))):
			if x >= 0 and y >= 0 and x < grid_size.x and y < grid_size.y:
				list.append(Vector2i(x, y))
	return list


func _is_solid_tile(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= grid_size.x or y >= grid_size.y:
		return true
	return solid[y * grid_size.x + x] == 1


func _near_walkable(x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		if not _is_solid_tile(x + d.x, y + d.y):
			return true
	return false


func _tile_of(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor((pos.x - room.position.x) / Floors.CELL)), int(floor((pos.y - room.position.y) / Floors.CELL)))


## A rooms floor's walls (always false on an open floor).
func is_solid(pos: Vector2) -> bool:
	if not layout_on:
		return false
	var t := _tile_of(pos)
	return _is_solid_tile(t.x, t.y)


## Nothing solid between two points.
func clear_line(a: Vector2, b: Vector2) -> bool:
	if not layout_on:
		return true
	var steps := int(a.distance_to(b) / 16.0) + 1
	for i in steps + 1:
		if is_solid(a.lerp(b, float(i) / steps)):
			return false
	return true


## Which way to walk from `from` to reach `to` around the walls.
func path_dir(from: Vector2, to: Vector2) -> Vector2:
	var straight := (to - from).normalized()
	if not layout_on or astar == null:
		return straight
	var a := _tile_of(from)
	var b := _tile_of(to)
	if _is_solid_tile(a.x, a.y) or _is_solid_tile(b.x, b.y):
		return straight
	var pts: PackedVector2Array = astar.get_point_path(a, b)
	if pts.size() < 2:
		return straight
	# Head for the farthest point along the path that can be reached in a
	# straight line with room for a body on either side, so monsters round
	# corners cleanly instead of snagging on them.
	var next: Vector2 = pts[1]
	for i in range(mini(pts.size() - 1, 8), 0, -1):
		if _wide_clear(from, pts[i], 14.0):
			next = pts[i]
			break
	return (next - from).normalized()


## The farthest open floor on the way from `from` to `to` (rooms floors have
## solid ground between rooms with no collision past the wall's first tile,
## so teleports, swaps and spawns must never land there).
func walkable_point(from: Vector2, to: Vector2, margin := 12.0) -> Vector2:
	var inset := room.grow(-margin)
	var steps := int(from.distance_to(to) / 8.0) + 1
	for i in range(steps, -1, -1):
		var p: Vector2 = from.lerp(to, float(i) / steps)
		if not inset.has_point(p):
			continue
		if not layout_on:
			return p
		if not is_solid(p) and not is_solid(p + Vector2(margin, 0)) and not is_solid(p - Vector2(margin, 0)) and not is_solid(p + Vector2(0, margin)) and not is_solid(p - Vector2(0, margin)):
			return p
	return from


## A spot near pos where a body of radius r stands clear of walls and of
## the given spots (bodies placed on a wall's edge, or on top of each other,
## get shoved apart, sometimes into the wall).
func clear_spot(pos: Vector2, r: float, others: Array = []) -> Vector2:
	if not layout_on or _clear_around(pos, r, others):
		return pos
	var inside := is_solid(pos)  # (from inside a wall, any clear spot near will do)
	for ring in range(1, 11):
		var d := ring * 8.0
		for k in 12:
			var q := pos + Vector2.from_angle(k * TAU / 12.0 + ring) * d
			if _clear_around(q, r, others) and (inside or clear_line(pos, q)):
				return q
	return pos


func _clear_around(p: Vector2, r: float, others: Array = []) -> bool:
	if is_solid(p):
		return false
	for o in others:
		if p.distance_to(o) < r * 2.0 + 6.0:
			return false
	for k in 8:
		if is_solid(p + Vector2.from_angle(k * TAU / 8.0) * (r + 2.0)):
			return false
	return true


## A clear line with room on either side (a body's width).
func _wide_clear(a: Vector2, b: Vector2, half: float) -> bool:
	var side := (b - a).normalized().orthogonal() * half
	return clear_line(a, b) and clear_line(a + side, b + side) and clear_line(a - side, b - side)


## The dev readout (menu.gd's dev tools, hud.gd draws it): how fast the game
## runs and what's in the room. Frame time is real time, smoothed.
var frame_ms := 16.7
var _frame_us := 0


func perf_lines() -> Array:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	return [
		"%d fps  ·  frame %.1f ms" % [int(fps), frame_ms],
		"draw calls %d  ·  objects %d" % [int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))],
		"nodes %d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"monsters %d  ·  traps %d" % [enemies().size(), traps.size()],
		"lights %d  (one darkness layer, %s)" % [lighting.on_screen if lighting != null else 0, lighting.quality if lighting != null else ""],
	]


func _process(delta: float) -> void:
	var now_us := Time.get_ticks_usec()
	if _frame_us > 0:
		frame_ms = lerpf(frame_ms, (now_us - _frame_us) / 1000.0, 0.1)
	_frame_us = now_us
	if hitstop_until > 0 and Time.get_ticks_msec() >= hitstop_until:
		hitstop_until = 0
		Engine.time_scale = RING_TIME if slowmo else 1.0
	if on_train:
		return  # (the train's menu takes the keys)
	if choosing_tower:
		for i in Towers.ORDER.size():
			if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
				choose_tower(Towers.ORDER[i])
				return
		# (two rows of cards when there are more than four, as hud.gd lays them out)
		var per_row := int(ceil(Towers.ORDER.size() / (2.0 if Towers.ORDER.size() > 4 else 1.0)))
		if _card_keys(Towers.ORDER.size(), per_row):
			choose_tower(Towers.ORDER[card_focus])
		return
	if camp_choosing:
		camp["t"] = float(camp.get("t", 0.0)) + delta / maxf(Engine.time_scale, 0.01)
		for i in mini(camp["choices"].size(), CARD_KEYS):
			if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
				choose_camp(i)
				return
		# (two rows of cards when there are many, as hud.gd lays them out)
		if _card_keys(camp["choices"].size(), hud.camp_per_row() if hud != null else camp["choices"].size()):
			choose_camp(card_focus)
		return
	if not victory.is_empty():
		victory["t"] += delta / maxf(Engine.time_scale, 0.01)
		if overlay_done() and _dismiss_pressed():
			end_regard()
		return
	if not regard.is_empty():
		regard["t"] += delta / maxf(Engine.time_scale, 0.01)
		if regard_done() and _dismiss_pressed():
			end_regard()
		return
	if fallen():
		var now := Time.get_ticks_usec()
		fall_t += minf((now - _fall_us) / 1000000.0, 0.1)  # (not the time a menu was open)
		_fall_us = now
		if fall_t >= FALL_WAIT or _fall_skip_pressed():
			back_to_train()
			return
	elif _restart_held(delta):
		Engine.time_scale = 1.0
		if get_tree().current_scene == self:  # (tests run the room outside a scene)
			get_tree().reload_current_scene()
		return
	recall_ask_t -= delta / maxf(Engine.time_scale, 0.01)
	new_climber_t -= delta / maxf(Engine.time_scale, 0.01)
	if Input.is_action_just_pressed("new_climber"):
		if new_climber_t > 0.0:
			new_climber()
			return
		new_climber_t = 3.0
		var CT: Dictionary = ClimbersPage.TEXT
		banner = {"title": CT["over_banner"], "lines": [CT["over_again"] % (CT["over_tap"] if touch_active else CT["over_key"]), CT["over_lost"]], "t": 3.0}
		sfx("warn_knight", 1.2, -6.0, 0.0)
	if Input.is_action_just_pressed("toggle_music") and audio != null:
		fx_text(player.global_position + Vector2(0, -44), "Music on" if audio.toggle_music() else "Music off", Color(0.85, 0.82, 0.9))
	# The stair opens once most of the floor is down; clearing it all rings the gong.
	var alive := enemies().size()
	# (On floors with a puzzle, only solving it opens the stair: see lift_ward.)
	if not ward and not stair_open and not climbing and float(floor_total - alive) >= ceilf(STAIR_OPENS_AT * floor_total):
		stair_open = true
		room_view.stair_open = true
		tip("stair")
		if alive > 0:
			sfx("glint", 0.7, -2.0, 0.0)
	if not cleared and not climbing and alive == 0:
		cleared = true
		sfx("clear", 1.0, 0.0, 0.0)
	if stair_open and not climbing and not player.dead and player.global_position.distance_to(stair_pos) < STAIR_REACH + player.radius:
		_climb()
	if not cache.is_empty() and not cache["taken"] and not climbing and not player.dead \
			and player.global_position.distance_to(cache["pos"]) < float(Floors.CACHE["reach"]) + player.radius:
		_open_cache()
	if not lost_cache.is_empty() and not lost_cache["taken"] and not climbing and not player.dead \
			and player.global_position.distance_to(lost_cache["pos"]) < Lost.REACH + player.radius:
		_open_lost_cache()
	if not banner.is_empty():
		banner["t"] -= delta
		if banner["t"] <= 0.0:
			banner = {}
	if layout_on and not climbing:
		_check_rooms()
		_update_springs(delta)
	if player != null:
		camera.position = cam_prev.lerp(cam_curr, Engine.get_physics_interpolation_fraction())
	# On phones the whole game is already drawn bigger, so pull the camera back.
	var want := 1.1 if touch_active else 1.35
	camera.zoom = Vector2(want, want)
	# A new shake offset at most 60 times a second, so a 120 Hz screen shakes
	# like a 60 Hz one instead of buzzing.
	var now_ms := Time.get_ticks_msec()
	if now_ms - shake_ms >= 16 or shake_amount <= 0.0:
		shake_ms = now_ms
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amount
	shake_amount = move_toward(shake_amount, 0.0, 30.0 * delta)
	hurt_flash = move_toward(hurt_flash, 0.0, delta)


## Monsters looking for a path around the walls: at most this many per tick.
const PATHS_PER_TICK := 3
var path_turns := 0
var path_turns_tick := -1


## True if a monster may look for a path this tick (enemy.gd).
func take_path_turn() -> bool:
	var tick := Engine.get_physics_frames()
	if tick != path_turns_tick:
		path_turns_tick = tick
		path_turns = 0
	if path_turns >= PATHS_PER_TICK:
		return false
	path_turns += 1
	return true


func _physics_process(delta: float) -> void:
	_separate_bodies()
	_update_spell_fields(delta)
	_track_player()


## Notes where the climber stands this tick, for the camera. A jump too big to
## be a step (a blink, a swap, a fall back out of a chasm) snaps instead of
## sliding across the room for a frame.
func _track_player() -> void:
	if player == null:
		return
	var now: Vector2 = player.global_position
	if now.distance_to(cam_curr) > 64.0:
		player.reset_physics_interpolation()
		cam_curr = now
	cam_prev = cam_curr
	cam_curr = now


## Ticks the spells that linger in the room: rods, wind walls, cyclones, rain.
func _update_spell_fields(delta: float) -> void:
	_update_grafts(delta)
	_update_item_drops(delta)
	_update_gear_drops()
	_update_flasks(delta)
	_update_ground(delta)
	_update_runes(delta)
	_update_flames(delta)
	if trap_view != null:
		trap_view.tick(delta)
	track_t -= delta
	if not rod.is_empty():
		rod["t"] -= delta
		if rod["t"] <= 0.0:
			rod = {}
	for w in walls:
		w["t"] -= delta
	walls = walls.filter(func(w): return w["t"] > 0.0)
	for c in cyclones:
		c["t"] -= delta
		for e in enemies():
			var to: Vector2 = c["pos"] - e.global_position
			if to.length() < c["r"] + e.radius:
				e.airborne = maxf(e.airborne, 0.3)
				e.knock = to.normalized() * minf(to.length() * 3.0, 120.0)
	cyclones = cyclones.filter(func(c): return c["t"] > 0.0)
	_update_waves(delta)
	for m in maelstroms:
		m["t"] -= delta
		m["tick"] -= delta
		var hurt: bool = m["tick"] <= 0.0
		if hurt:
			m["tick"] = 0.5
		for e in enemies():
			var to: Vector2 = m["pos"] - e.global_position
			if to.length() < m["r"] + e.radius:
				e.knock = to.normalized() * minf(to.length() * 4.0, 260.0)
				if hurt:
					e.take_hit(m["damage"], Vector2.ZERO, 0.0)
	maelstroms = maelstroms.filter(func(m): return m["t"] > 0.0)
	for r in rains:
		r["t"] -= delta
		r["tick"] -= delta
		if r["tick"] <= 0.0:
			r["tick"] = 0.12
			# Each volley: one arrow at random, one at a foe caught in the area.
			var spots: Array = [r["pos"] + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * r["r"]]
			var inside: Array = enemies().filter(func(e): return e.global_position.distance_to(r["pos"]) < r["r"] + e.radius)
			if not inside.is_empty():
				spots.append(inside[randi() % inside.size()].global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8)))
			for at in spots:
				if fx != null:
					fx.falling_arrow(at, r["color"])
				for e in enemies():
					if e.global_position.distance_to(at) < e.radius + 16.0:
						e.take_hit(r["damage"], Vector2.ZERO, 0.0)
	rains = rains.filter(func(r): return r["t"] > 0.0)


## Bodies can't share space: overlapping ones are pushed apart, and the
## lighter one gives way more. Foes lifted into the air pass over everyone.
func _separate_bodies() -> void:
	var bodies: Array = enemies().filter(func(e): return e.airborne <= 0.0 and not e.submerged)
	if player != null and not player.dead:
		bodies.append(player)
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a = bodies[i]
			var b = bodies[j]
			var d: Vector2 = b.global_position - a.global_position
			var min_d: float = a.radius + b.radius
			var dist := d.length()
			if dist >= min_d:
				continue
			var n := d / dist if dist > 0.01 else Vector2.from_angle(randf() * TAU)
			var overlap := min_d - dist
			var share: float = b.weight / (a.weight + b.weight)  # a's part of the push
			# (Never into a wall: walls built this frame don't stop a body yet.)
			var da: Vector2 = -n * overlap * share
			var db: Vector2 = n * overlap * (1.0 - share)
			if not is_solid(a.global_position + da + da.normalized() * a.radius * 0.5):
				a.move_and_collide(da)
			if not is_solid(b.global_position + db + db.normalized() * b.radius * 0.5):
				b.move_and_collide(db)


# --- the climb -------------------------------------------------------------

func _start_floor(n: int) -> void:
	floor_num = n
	cleared = false
	stair_open = false
	room_view.stair_open = false
	# Clear out the last floor: monsters, arrows, pillars.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
		e.remove_from_group("enemies")
	foes_changed()
	for a in get_tree().get_nodes_in_group("allies"):  # calls end on every new floor
		a.queue_free()
		a.remove_from_group("allies")
	for c in get_children():
		if "reflected" in c:
			c.queue_free()
	attackers.clear()
	rod = {}
	walls.clear()
	cyclones.clear()
	waves.clear()
	maelstroms.clear()
	rains.clear()
	flames.clear()
	meteors.clear()
	graft_drops.clear()
	runes.clear()
	wards.clear()
	sigils.clear()
	for w in stone_walls:
		if is_instance_valid(w["body"]):
			w["body"].queue_free()
	stone_walls.clear()
	rubble.clear()
	pits.clear()
	clouds.clear()
	smokes.clear()
	decoys.clear()
	ashfall_t = 0.0
	if player != null:
		player.rune_gear = player.camp_rune  # runes on gear last one floor (a camp's, the rest of the climb)
		player.ember_used = false  # Last Ember: once per floor
		player.ember_t = 0.0  # (and a Last Ember never follows you up the stair)
	track_t = 0.0
	for b in pillar_bodies:
		_drop_body(b)
	pillar_bodies.clear()
	item_drops.clear()
	gear_drops.clear()
	gear_here = {}
	flasks.clear()
	flare_t = 0.0
	if flare_light >= 0 and lighting != null:
		lighting.remove_light(flare_light)
	flare_light = -1
	if not in_camp:
		camp_choosing = false
	if campfire != null:
		campfire.queue_free()
		campfire = null

	var open_start := Vector2(OPEN_ROOM.get_center().x, OPEN_ROOM.end.y - 60.0)
	var start: Vector2 = open_start
	if n == 1:
		start = player.position if room == OPEN_ROOM else Vector2(300, 365)
	var plan: Dictionary = _camp_plan() if in_camp else (proving.make_plan() if proving.due(n) else {})  # (floor 6: the Proving's own layout)
	if plan.is_empty():
		MirrorScript.climb_ok = not first_climb  # (no mirror rooms on the bondless first climb)
		if secret_tools != null:
			secret_tools.before_build(n)  # (the Designer's Reroll: the puzzle and rooms chosen for this floor)
		plan = Floors.build(n, OPEN_ROOM, start, Towers.TOWERS[tower])
		if secret_tools != null:
			secret_tools.after_build(plan)
		if MirrorScript.THEME in plan.get("themes", []):
			MirrorScript.force = false  # (the dev tool's forced mirror room is here)
	floor_plan = plan
	_set_arena(plan.get("arena", OPEN_ROOM))
	layout_rooms = plan.get("rooms", [])
	layout_torches = plan.get("torches", [])
	start = plan.get("start", start)
	player_start = start if plan.has("start") else open_start
	stair_pos = plan.get("stair", Vector2(OPEN_ROOM.get_center().x, OPEN_ROOM.position.y + 34.0))
	room_view.stair_pos = stair_pos
	# A good room's essence cache, if this floor has one.
	side_room = plan.get("cache_room", Rect2())
	cache = {}
	if plan.has("cache"):
		cache = plan["cache"].duplicate()
		cache["kind"] = tower_data()["essence"]
		cache["taken"] = false
		# Sometimes the cache also holds a piece of gear.
		if randf() < gear_cache_chance:
			cache["gear"] = find_gear("", 1)  # (a cache rolls one rarity row higher)
	room_view.cache = cache
	_place_lost_cache(plan, n)
	var targets: Array = [stair_pos]
	for m in plan["monsters"]:
		targets.append(m[1])
	if not cache.is_empty():
		targets.append(cache["pos"])
	if not lost_cache.is_empty():
		targets.append(lost_cache["pos"])
	_build_layout(plan.get("walk", []), plan.get("blocks", []), start, targets)
	# Door frames, only where the wall beside an opening is really there.
	room_view.set_doors(plan.get("posts", []).filter(func(r): return is_solid(r.get_center())))
	# The rooms' themes, and the doors (closed doors are solid: hung before
	# the traps, so no trap lands in a doorway).
	room_info = plan.get("room_info", [])
	room_themes = plan.get("themes", []).duplicate()
	room_entered = {}
	room_at = -1
	room_tile = Vector2i(-999, -999)
	room_pending = -1
	door_view.build(plan.get("doors", []), room_themes)
	# Sealed wings, their vaults, and secret rooms (wings.gd): after the doors,
	# before the fog and the first drawing (their closed tiles are solid).
	wings.setup(plan)
	makers.setup_floor()  # (maybe a Maker's fragment in a secret room or a vault)
	# The traps (traps.gd): laid before the pillars and chasms are made, since
	# placing them may add shelter pillars, move monsters off trap tiles and
	# clear chasms from under what matters.
	traps = [] if plan.get("proving", false) else Traps.place(plan, tower_data(), n, self)  # (the Proving lays its gauntlet when a door is chosen)
	trap_view.floor_marks = plan.get("trap_floor", {})
	trap_view.reset()
	springs = plan.get("springs", [])
	# A fallen climber's camp: what they left behind.
	for cp in plan.get("camps", []):
		item_drops.append({"pos": cp["item"], "id": Items.random_item(player != null and not player.bonds.is_empty()), "t": 1e9})
	floor_total = plan["monsters"].size()
	if plan.get("summit", false):
		banner = {"title": "%s AWAITS" % beast_name().to_upper(), "lines": [tower_data().get("beast_hint", "Watch for the glint.")], "t": 3.0}
		tip("beast")
		sfx("warn_knight", 0.5, 0.0, 0.0)
	pillars = plan["pillars"]
	for p in pillars:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = p["pos"]
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = p["r"]
		shape.shape = circle
		body.add_child(shape)
		add_child(body)
		pillar_bodies.append(body)
	room_view.set_pillars(pillars)
	puddles = []
	if tower_data().get("puddles", false) and not in_camp:
		if layout_rooms.is_empty():
			puddles = Floors.puddles(room, pillars, start)
		else:
			# Keep pools off the cover too (each block counted as a round pillar).
			var avoid: Array = pillars.duplicate()
			for b in layout_blocks:
				avoid.append({"pos": b.get_center(), "r": b.size.length() * 0.5})
			# Rooms with pools drawn in (rooms.gd) bring their own; others get a
			# few in the rooms where danger waits (not the good rooms or the puzzle).
			puddles.append_array(plan.get("pools", []))
			if puddles.is_empty():
				for r in plan.get("wet_rooms", []):
					puddles.append_array(Floors.puddles(r.grow(-40.0), avoid, start).slice(0, 2))
	room_view.set_puddles(puddles)
	set_chasms(plan.get("chasms", []))
	# A trap room whose traps wouldn't fit is just a quiet hall.
	for i in plan.get("hazard_rooms", []):
		if not traps.any(func(tr): return int(tr.get("room", -1)) == i):
			room_themes[i] = "quiet"
	door_view.restyle(room_themes)
	_update_room_looks(plan.get("camps", []))
	if puzzle != null:
		puzzle.setup(plan.get("puzzle", {}) if not in_camp else {})
		ward = puzzle.active()

	var tough := Floors.toughness(n)
	var spawned: Array = []
	for m in plan["monsters"]:
		var e = EnemyScript.new()
		e.setup(m[0], self)
		e.max_hp *= tough.x
		e.hp = e.max_hp
		e.dmg *= tough.y
		e.position = clear_spot(m[1], e.radius, spawned.map(func(o): return o.position))
		e.aware = not layout_on  # in rooms, monsters wait until they see you
		add_child(e)
		spawned.append(e)
	# A locked door's key may be carried by one of them.
	door_view.tag_carriers(plan.get("doors", []) + plan.get("wings", []), spawned)
	proving.setup(plan)
	player.position = start
	player.last_safe = start
	player.reset_physics_interpolation()
	if fog != null:
		fog.reset()
	cam_prev = start
	cam_curr = start
	if camera != null:
		camera.position = start
		camera.reset_smoothing()


## The rooms' tints and marks on the floor (themes.gd), springs and camps.
func _update_room_looks(camps: Array) -> void:
	var looks: Array = []
	for i in room_info.size():
		var th: Dictionary = Themes.get_theme(room_themes[i])
		looks.append({"walk": room_info[i]["walk"], "rect": room_info[i]["rect"], "rows": room_info[i]["rows"], "tint": th["tint"], "decor": th.get("decor", "")})
	room_view.set_looks(looks, springs, camps)


## The room the climber stands in, worked out when they reach a new tile.
## The first time they walk into a themed room, its name and rule show.
func _check_rooms() -> void:
	if room_info.is_empty() or player == null:
		return
	var t := _tile_of(player.global_position)
	if t != room_tile:
		room_tile = t
		room_at = -1
		for i in room_info.size():
			if room_info[i]["rect"].has_point(player.global_position):
				room_at = i
				break
		if room_at >= 0 and not room_entered.has(room_at):
			room_entered[room_at] = true
			_enter_room(room_at)
	# A name that waited for another banner to clear shows once it has, if
	# the climber is still in that room.
	if room_pending >= 0 and banner.is_empty():
		if room_pending == room_at:
			_room_banner(room_pending)
		room_pending = -1


func _enter_room(i: int) -> void:
	var id: String = room_themes[i]
	var th: Dictionary = Themes.get_theme(id)
	tip(GuideScript.Entity.ROOM_TIPS.get(th["feature"], ""))
	var pk = puzzle.get("kind") if puzzle != null else null
	if room_info[i].get("role", "") == "gallery" and pk is String and pk != "":
		tip("puzzle_" + pk)  # (a kind with no tip of its own gets the general one)
	if th["feature"] == "ambush":
		_ambush(i)
	if th["feature"] == "mirror":
		MirrorScript.enter_room(self, i)  # its image steps out of the glass
	door_view.room_entered(i)  # (a lock-in room shuts once you're well inside)
	if th["sub"] == "" or id == "quiet":
		return  # (the arrival hall and quiet halls say nothing)
	if banner.is_empty() or banner.get("room", false):
		_room_banner(i)
	else:
		room_pending = i


func _room_banner(i: int) -> void:
	var th: Dictionary = Themes.get_theme(room_themes[i])
	tip("rooms")
	banner = {"title": String(th["name"]).to_upper(), "lines": [th["sub"]], "t": 2.8, "room": true, "inscribed": true}
	sfx("glint", 0.6 if th["kind"] == "bad" else 1.1, -12.0, 0.0)


## A restless crypt: its dead rise as you walk in.
func _ambush(i: int) -> void:
	var spots: Array = room_info[i].get("ambush", [])
	var n := mini(spots.size(), 2 if floor_num < 6 else 3)
	for k in n:
		var kind := Floors._pick(floor_num, 3.0, 99, tower_data().get("weights", {}))
		if kind == "":
			kind = "slime"
		var e = spawn_enemy(kind, spots[k])
		e.wake()
		floor_total += 1
		fx_burst(spots[k], Vector2.UP, Color(0.6, 0.5, 0.85), 14, 140.0)
		fx_ring(spots[k], Color(0.6, 0.5, 0.85), 50.0, 0.4, 3.0)
	if n > 0:
		shake(6.0)
		sfx("slam", 0.6, -4.0, 0.0)


## Standing in a healing spring heals you until it runs dry.
func _update_springs(delta: float) -> void:
	if springs.is_empty() or player == null or player.dead:
		return
	for sp in springs:
		if sp["left"] <= 0.0 or player.global_position.distance_to(sp["pos"]) > sp["r"]:
			continue
		# (Life's flow heals you more from the same water.)
		var heal := minf(minf(float(Floors.SPRING["rate"]) * delta, sp["left"]) * player.heal_mult(), player.max_health() - player.hp)
		if heal <= 0.0:
			continue
		player.hp += heal
		sp["left"] -= heal / player.heal_mult()
		if sp["left"] <= 0.01:
			sp["left"] = 0.0
			room_view.refresh_features()
			fx_text(sp["pos"] + Vector2(0, -40), "The spring runs dry", Color(0.6, 0.85, 0.8))
		elif randf() < 4.0 * delta:
			fx_burst(player.global_position, Vector2.UP, Color(0.5, 0.95, 0.85), 2, 60.0)


## Opens every door on the floor (the dev tool, and tests).
func open_all_doors() -> void:
	door_view.open_all()


## Walking onto a good room's essence cache: a burst of the tower's essence.
func _open_cache() -> void:
	cache["taken"] = true
	var pos: Vector2 = cache["pos"]
	var amount: float = cache["amount"]
	gather_essence(cache["kind"], amount, pos)
	var col: Color = Essence.color(cache["kind"])
	fx_text(pos + Vector2(0, -36), "%s: +%d essence" % [Floors.CACHE["name"], int(amount)], col)
	if cache.has("gear"):
		drop_gear(pos, cache["gear"], true)
		fx_text(pos + Vector2(0, -54), Gear.TEXT["cache"] % Gear.display(cache["gear"]), Gear.color(cache["gear"]))
	fx_ring(pos, col, 70.0, 0.5, 4.0)
	fx_burst(pos, Vector2.ZERO, col, 18, 220.0)
	light_flash(pos, col, 1.8, 1.8, 0.4)
	sfx("glint", 1.3, -2.0, 0.0)


## A lost cache (lost.gd): on a floor of rooms of a tower where you lost
## things in a fall, near the floor where they fell, sometimes your fallen
## pack lies in an ordinary room (traps keep clear of it).
func _place_lost_cache(plan: Dictionary, n: int) -> void:
	lost_cache = {}
	if not in_camp and not first_climb and profile != null and plan.has("room_info"):
		var here := Lost.for_floor(profile, tower, n)
		if not here.is_empty() and randf() < lost_cache_chance:
			var at := Lost.spot(plan)
			if at != Vector2.INF:
				lost_cache = {"pos": at, "entries": here, "taken": false}
				var half := Vector2(Floors.CELL, Floors.CELL) * 1.5
				plan["safe_rooms"] = plan.get("safe_rooms", []) + [Rect2(at - half, half * 2.0)]
	room_view.lost_cache = lost_cache


## Walking onto a lost cache: your lost pieces come back, into your pack
## while there's room, else at your feet; they're no longer lost.
func _open_lost_cache() -> void:
	lost_cache["taken"] = true
	var pos: Vector2 = lost_cache["pos"]
	var names: Array = []
	var left: Array = []
	for e in lost_cache["entries"]:
		var r := Gear.rec(e["rec"])
		if r.is_empty():
			continue
		names.append(Gear.display(r))
		if player.pack_room():
			player.pack.append(r)
		else:
			drop_gear(pos, r)
			left.append(Gear.display(r))
	Lost.forget(profile, lost_cache["entries"])
	profile.save()
	tip("lost_cache")
	fx_text(pos + Vector2(0, -40), Lost.TEXT["found"] % ", ".join(names), Lost.LIGHT_COLOR)
	if not left.is_empty():
		fx_text(pos + Vector2(0, -58), Lost.TEXT["at_feet"] % ", ".join(left), Color(0.85, 0.82, 0.9))
	fx_ring(pos, Lost.LIGHT_COLOR, 60.0, 0.5, 3.0)
	light_flash(pos, Lost.LIGHT_COLOR, 1.4, 1.2, 0.4)
	sfx("heirloom", 0.9, -4.0, 0.0)


## Falling into a chasm: no harm done, but you drop to the floor below (never
## below floor 1) and keep climbing from there. Unbanked essence stays with you.
static var FALL_TEXT := {"title": "YOU FELL", "line": "Down to floor %d. The beast watches you climb again."}

func fall_through() -> void:
	if climbing or player.dead:
		return
	climbing = true
	player.set_physics_process(false)
	player.iframes = maxf(player.iframes, 2.0)
	var to := maxi(1, floor_num - 1)
	profile.note("falls")
	tip("chasm_fall")
	fx_text(player.global_position + Vector2(0, -40), "Falling!", Color(0.85, 0.7, 0.6))
	sfx("roll", 0.5, -2.0, 0.0)
	shake(5.0)
	var tw := create_tween()
	tw.tween_property(self, "fade", 1.0, 0.4)
	tw.tween_callback(_land_below.bind(to))
	tw.tween_interval(0.2)
	tw.tween_property(self, "fade", 0.0, 0.5)
	tw.tween_callback(func(): climbing = false)


func _land_below(to: int) -> void:
	_start_floor(to)
	banner = {"title": FALL_TEXT["title"], "lines": [FALL_TEXT["line"] % to], "t": 3.0}
	player.set_physics_process(true)
	sfx("hurt", 0.7, -6.0, 0.0)


## The floor's puzzle is solved: the ward lifts and the stair opens.
func lift_ward() -> void:
	ward = false
	stair_open = true
	room_view.stair_open = true
	profile.note("puzzles")
	MakersScript.feed(self, "puzzle")
	tip("stair")
	banner = {"title": PuzzleScript.TEXT["lifted_title"], "lines": [PuzzleScript.TEXT["lifted"]], "t": 2.5}
	if door_view.unlock_puzzle():  # (warded doors open with it)
		banner["lines"].append(door_view.LOCK_TEXT["puzzle_line"])
	sfx("clear", 0.9, -2.0, 0.0)
	fx_ring(stair_pos, Color(0.75, 0.55, 1.0), 80.0, 0.6, 4.0)


## Walking onto the open stair: fade out, rest, grow, fade into the next floor.
func _climb() -> void:
	climbing = true
	player.set_physics_process(false)
	player.iframes = maxf(player.iframes, 2.0)  # nothing can hit you on the stair
	sfx("step", 0.8, 0.0, 0.0)
	var tw := create_tween()
	tw.tween_property(self, "fade", 1.0, 0.45)
	tw.tween_callback(_arrive)
	tw.tween_interval(0.25)
	tw.tween_property(self, "fade", 0.0, 0.5)
	tw.tween_callback(func(): climbing = false)


func _arrive() -> void:
	if player.dead:
		return  # (can't happen with the stair's grace, but never wake up dead)
	var lines: Array = []
	# Rest at the stair: burns heal, some health and all stamina return.
	var burned := false
	for b in player.bonds.values():
		burned = burned or b.burned
		b.burned = false
	player.poison_t = 0.0  # the rest at the stair cures poison too
	lines.append_array(proving.on_stair())  # (the Proving's wound heals a stair at a time)
	var healed := minf(player.max_health() - player.hp, player.max_hp * (0.45 if player.has_bond("surgeon") else 0.35))  # Steady Hands
	player.hp += healed
	player.sta = player.max_sta
	if burned:
		lines.append("Your burns heal")
	if healed >= 1.0:
		lines.append("Rested: +%d health" % int(healed))
	# Bank the essence gathered on this floor: it strengthens your marks. A
	# share of it condenses into crystals first (train.gd CONDENSE_*, the
	# setting): only the rest is banked, and only that grows anything.
	var cond: Dictionary = profile.condense(run_essence, Train.condense_share(MenuScript.settings))
	var keep: Dictionary = cond["keep"]
	var banked := 0.0
	var condensed := 0.0
	for k in keep:
		banked += float(keep[k])
	for k in cond["made"]:
		condensed += float(cond["made"][k])
	if banked + condensed > 0.0:
		var said: String = Train.TEXT["banked"] % int(round(banked))
		if condensed >= 1.0:
			said += "  ·  " + Train.TEXT["condensed"] % int(condensed)
		lines.append(said)
		profile.note("essence", banked)
		tip("bank")
	lines.append_array(SecretBonds.on_bank(profile, keep, run_flow, profile.path))  # (a secret bond grows from what's banked)
	lines.append_array(profile.bank(keep, run_soak))
	run_essence = {}
	run_soak = {}
	lines.append_array(_bank_flow())
	# (New marks come only at a summit now: summit_mark below.)
	_give_bonds()
	profile.save()
	var leaving_camp := in_camp
	in_camp = false
	# The top of the first climb: the Regard.
	if first_climb and floor_num >= ProfileScript.FIRST_CLIMB_FLOORS:
		_begin_regard(false)
		return
	# The summit: the beast has fallen and the climb is complete.
	if floor_num == int(tower_data().get("summit", 0)):
		profile.climbs += 1
		var choice: String = unbound.summit_choice() if unbound != null else ""  # (the Unbound condense; or the refusal offered)
		if choice == "":
			lines.append_array(summit_mark())
		var broke := break_belt()
		if broke != "":
			lines.append(broke)
		var paid := pay_climb()
		if paid != "":
			lines.append(paid)
		var home := bring_pack_home()
		if home != "":
			lines.append(home)
		home = Vessel.bring_home(self)  # (into your chest, filled or not)
		if home != "":
			lines.append(home)
		profile.save()
		if choice != "":
			unbound.offer_summit(choice, lines)
			return
		show_victory(lines)
		return
	# Halfway up a long climb, the stair leads to a camp first.
	if not leaving_camp and _camp_due():
		_enter_camp(lines)
		return
	_start_floor(floor_num + 1)
	profile.note_floor(tower, floor_num)
	if floor_num > best_floor:
		best_floor = floor_num
		profile.best_floor = best_floor
		profile.save()
	if banner.get("title", "").ends_with("AWAITS"):
		banner["lines"] = lines + banner["lines"]
	elif proving.on:
		banner = proving.arrival_banner(lines)  # halfway up: the Proving
		GuideScript.moment("proving", "proving")
	elif floor_num == int(Towers.PROVING["floor"]) and not first_climb:
		# (the Proving switched off, as in most tests: a floor with its banner)
		banner = {"title": String(Towers.PROVING["name"]).to_upper(), "lines": ["Floor %d" % floor_num, Towers.PROVING["line"]] + lines, "t": 3.5}
		GuideScript.moment("proving", "proving")
	else:
		banner = {"title": _floor_title(), "lines": lines, "t": 3.0}
	if ward and not proving.on:
		banner["lines"] = banner.get("lines", []) + [PuzzleScript.TEXT["warded"]]
		banner["t"] = maxf(float(banner.get("t", 0.0)), 3.5)
		tip("ward")
	if layout_on:
		tip("fog")
	player.set_physics_process(true)
	sfx("clear", 0.8, -8.0, 0.0)
	makers.on_arrive()  # (in the quiet after the stair, a Maker may show itself)


# --- camps and items ---------------------------------------------------------------

## A camp after each floor in Items.CAMP_AFTER (once each), on climbs long
## enough to have one. Camps aren't floors: the floor count goes on after.
func _camp_due() -> bool:
	return not first_climb and floor_num in Items.CAMP_AFTER and not (floor_num in camps_done) \
		and int(tower_data().get("summit", 0)) >= Items.CAMP_MIN_FLOORS


## The camp's room: the open room with a campfire, no monsters.
func _camp_plan() -> Dictionary:
	var fire := OPEN_ROOM.get_center() + Vector2(0, 30)
	campfire = CampfireScript.new()
	campfire.position = fire
	add_child(campfire)
	return {"monsters": [], "pillars": [], "start": fire + Vector2(0, 80)}


## Keyboard and controller on the card screens: left and right (arrows,
## d-pad or stick; up and down between rows) move the highlight, Enter,
## Space or A takes the card. True when a card is taken.
func _card_keys(count: int, per_row: int) -> bool:
	if count <= 0:
		return false
	card_focus = clampi(card_focus, 0, count - 1)
	var was := card_focus
	card_rep.update()  # (holding a direction repeats, the same for keys, the d-pad and the stick: nav.gd)
	if card_rep.pulse("ui_left"):
		card_focus = posmod(card_focus - 1, count)
	elif card_rep.pulse("ui_right"):
		card_focus = posmod(card_focus + 1, count)
	elif card_rep.pulse("ui_up") and card_focus - per_row >= 0:
		card_focus -= per_row
	elif card_rep.pulse("ui_down") and card_focus / per_row < (count - 1) / per_row:
		card_focus = mini(card_focus + per_row, count - 1)
	if card_focus != was:
		sfx("ui_move")
	return Input.is_action_just_pressed("ui_accept")


## The Regard and the victory screen: any of these moves on once they've played.
func _dismiss_pressed() -> bool:
	for a in ["attack", "roll", "restart", "jump", "ui_accept", "pause"]:
		if Input.is_action_just_pressed(a):
			overlay_closed_frame = Engine.get_process_frames()
			return true
	return false


## Fallen after the Regard (the first climb's fall goes to the Regard instead).
func fallen() -> bool:
	if player == null or not player.dead or first_climb or not regard.is_empty() or not victory.is_empty():
		fall_t = -1.0
		return false
	if fall_t < 0.0:
		fall_t = 0.0
		_fall_us = Time.get_ticks_usec()
	return true


## A tap, a confirm key, R or View: back to the train now (once the fall
## screen has shown for a moment).
func _fall_skip_pressed() -> bool:
	if fall_t < FALL_GRACE:
		return false
	for a in ["ui_accept", "restart", "attack", "roll", "jump"]:
		if Input.is_action_just_pressed(a):
			return true
	return false


## A tap on the fall screen (touch.gd).
func fall_tapped() -> void:
	if fallen() and fall_t >= FALL_GRACE:
		back_to_train()


## After a fall: a new climb's scene, which opens on the train (on your
## own car), as a restart does. The fall has already taken the pack and
## the belt (on_player_died).
func back_to_train() -> void:
	fall_t = -1.0
	Engine.time_scale = 1.0
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()
		return
	# (Tests run the room outside a scene: stand up, and open the train here.)
	player.dead = false
	player.hp = player.max_hp
	await_tower()
	open_train()


## True once restart has been held long enough (or pressed, once fallen).
## While it's held, a banner says to keep holding.
func _restart_held(delta: float) -> bool:
	if Input.is_action_just_pressed("restart"):
		restart_armed = true
		restart_t = 0.0
		if player.dead:
			return true
	if not restart_armed or not Input.is_action_pressed("restart"):
		restart_armed = false
		return false
	restart_t += delta / maxf(Engine.time_scale, 0.01)
	if restart_t >= RESTART_HOLD:
		restart_armed = false
		return true
	# (Only once it's clearly held: a short press of View opens the climber screen.)
	if restart_t >= RESTART_ASK:
		var key := "Keep holding %s" % (Controls.pad_name("back", pad_ps) if pad_active else "R")
		banner = {"title": "RESTART?", "lines": ["%s to start this climb again." % key], "t": 0.6}
	return false


## Arrives at a camp: a full rest by the fire, then an item to choose.
func _enter_camp(lines: Array) -> void:
	camps_done.append(floor_num)
	in_camp = true
	_start_floor(floor_num)
	cleared = true  # (no gong: there was nothing to fight)
	player.hp = player.max_health()
	player.sta = player.max_sta
	player.poison_t = 0.0
	for b in player.bonds.values():
		b.burned = false
	var said: Array = [Items.CAMP["sub"]]
	said.append_array(lines.filter(func(l): return not String(l).begins_with("Rested")))
	var choices: Array = Items.camp_choices(not player.bonds.is_empty())
	# And a piece of gear, one rarity row higher (the floor 9 camp's is Rare).
	choices.append("gear:" + Gear.code(find_gear("", 1, "rare" if floor_num >= 9 else "common")))
	camp = {"stage": "item", "choices": choices, "lines": said}
	_note_new_slots(choices)
	camp_choosing = true
	tip("camp")
	card_focus = 0
	banner = {}
	player.set_physics_process(false)
	sfx("ready", 0.7, -4.0, 0.0)


## What a camp card shows: {name, desc, color, item} (item is "" for a rune).
func camp_card(i: int) -> Dictionary:
	var pick: String = camp["choices"][i]
	if pick.begins_with("unbind:") or pick.begins_with("condense:"):
		return unbound.card(pick)
	if pick.begins_with("sb:"):
		return secret_tools.card(pick)  # a secret bond tool's choice (secret_tools.gd)
	if pick.begins_with("path:"):
		var k := pick.substr(5)
		return {"name": Secret.display(k), "desc": Secret.KINDS[k]["motto"], "color": Secret.color(k), "item": "", "secret": k,
			"steps": Secret.STEP_TEXT[k], "note": Secret.TEXT["card_sub"]}
	if pick.begins_with("heir:"):
		var h := pick.substr(5)
		if h == "":
			return {"name": Gear.HEIRLOOM_TEXT["none_name"], "desc": Gear.HEIRLOOM_TEXT["none_desc"], "color": Color(0.6, 0.58, 0.66), "item": ""}
		var hs := "rings" if h == "rings" else Gear.heirloom_slot(h)
		var kept: Array = Gear.heirloom_pieces(profile.heirlooms, hs)
		var slot_name := Gear.heirloom_slot_name(hs).to_lower()
		var note: String = Gear.HEIRLOOM_TEXT["replaces"] % " and ".join(kept.map(func(k): return Gear.display(k))) if not kept.is_empty() else Gear.HEIRLOOM_TEXT["empty_slot"] % slot_name
		if h == "rings":
			var rings := worn_rings()
			var names: String = " and ".join(rings.map(func(r): return Gear.display(r)))
			return {"name": Gear.HEIRLOOM_TEXT["rings_name"], "desc": Gear.HEIRLOOM_TEXT["rings_desc"] % names, "color": Gear.color(rings[0]),
				"item": "", "gear": rings[0], "note": note}
		var g := Gear.rec(h)
		return {"name": Gear.display(g), "desc": gear_card_desc(g), "color": Gear.color(g), "item": "", "gear": g, "note": note, "rim": Gear.rarity_color(g)}
	if pick.begins_with("gear:"):
		var g := Gear.rec(pick.substr(5))
		var gs := Gear.slot_of(g)
		var held = player.gear.get(player.slot_for(g), {})
		var desc: String = gear_card_desc(g)
		var none: String = Gear.TEXT["none"] if gs == "armor" else Gear.TEXT["empty"]
		return {"name": Gear.display(g), "desc": desc, "color": Gear.color(g), "item": "", "gear": g, "rim": Gear.rarity_color(g),
			"note": "%s  ·  %s" % [Gear.SLOT_NAMES.get(gs, gs), Gear.TEXT["carrying"] % (Gear.display(held) if Gear.is_gear(held) else none)]}
	if pick.begins_with("belt:"):
		var out := pick.substr(5)
		var newid: String = camp.get("drop", {}).get("id", "")
		var new_name: String = String(Items.ITEMS.get(newid, {}).get("name", "item")).to_lower()
		if out == "":
			return {"name": Items.BELT["leave_name"], "desc": Items.BELT["leave_desc"] % new_name, "color": Color(0.6, 0.58, 0.66), "item": newid, "belt": true}
		var od := Items.info(out)
		return {"name": Items.BELT["drop_name"] % od["short"], "desc": Items.BELT["drop_desc"] % [String(od["name"]).to_lower(), new_name],
			"color": od["color"], "item": out, "belt": true, "note": "you carry %d" % player.item_count(out)}
	if pick.begins_with("rune:"):
		var r: Dictionary = Items.CAMP_RUNES[pick.substr(5)]
		return {"name": r["name"], "desc": r["desc"], "color": r["color"], "item": ""}
	if pick.begins_with("crystal:"):
		var kind := pick.get_slice(":", 1)
		var amount := int(pick.get_slice(":", 2))
		var held := int(profile.crystal_total(kind))
		return {"name": Items.CRYSTAL["name"] % Essence.display(kind), "desc": Items.CRYSTAL["desc"] % [amount, Essence.display(kind).to_lower()],
			"color": Essence.color(kind), "item": "", "crystal": kind, "note": "you hold %d %s" % [held, Essence.display(kind)]}
	var crafted := pick.begins_with("craft:")
	var id := pick.substr(6) if crafted else pick
	var d := Items.info(id)
	if crafted:
		return {"name": Items.CRAFT["name"] % d["short"], "desc": Items.CRAFT["desc"] % String(d["name"]).to_lower(), "color": d["color"], "item": id}
	return {"name": d["name"], "desc": d["desc"], "color": d["color"], "item": id}


## A gear card's text: what it does, then its traits.
func gear_card_desc(g) -> String:
	var bits: Array = [Gear.desc(g)]
	for t in Gear.trait_lines(g):
		bits.append(String(t[0]))
	return ";  ".join(bits)


## Takes a camp card (keys 1 to 4, a click or a tap). A Rune Artist then
## also gets Runesmith's cards: a rune on gear, or a crafted item.
func choose_camp(i: int) -> void:
	if not camp_choosing or i < 0 or i >= camp["choices"].size():
		return
	var pick: String = camp["choices"][i]
	if camp["stage"] == "path":
		_take_path_pick(i)
		return
	if camp["stage"] in ["unbind", "condense"]:
		unbound.choose(i)
		return
	if camp["stage"] == "heirloom":
		keep_heirloom(pick.substr(5))
		return
	if camp["stage"] == "vault":
		_take_vault_pick(pick)
		return
	if camp["stage"] == "belt":
		_take_belt_pick(pick)
		return
	if camp["stage"] == "secret":
		secret_tools.take_card(i)
		return
	var taken: Array = camp.get("taken", [])
	if camp["stage"] == "item":
		if pick.begins_with("gear:"):
			taken.append(_take_gear(pick.substr(5)))
		else:
			taken.append(_take_item(pick, "Took"))
		if player.has_bond("rune_artist"):
			var choices: Array = Items.CAMP_RUNES.keys().map(func(r): return "rune:" + r)
			choices.append("craft:" + Items.random_item(true))
			camp = {"stage": "rune", "choices": choices, "lines": [Items.CAMP["rune_sub"]], "taken": taken}
			card_focus = 0
			sfx("equip_sword", 1.1, -4.0, 0.0)
			return
	elif pick.begins_with("rune:"):
		var r := pick.substr(5)
		player.camp_rune = r
		player.rune_gear = r
		taken.append("%s inscribed on your gear" % Items.CAMP_RUNES[r]["name"])
		fx_ring(player.global_position, Items.CAMP_RUNES[r]["color"], 30.0, 0.35, 3.0)
	else:
		taken.append(_take_item(pick.substr(6), "Crafted"))
	camp_choosing = false
	player.set_physics_process(true)
	taken.append(Items.CAMP["leave"])
	banner = {"title": Items.CAMP["title"], "lines": taken, "t": 3.0}
	sfx("pickup", 0.95, -2.0, 0.0)


# --- vaults, essence crystals and the recall scroll -------------------------------

## A vault's pedestal (wings.gd): its cards, on the camp's card screen. The
## monsters wait while you choose.
func offer_vault(choices: Array, title: String, lines: Array) -> void:
	camp = {"stage": "vault", "choices": choices, "lines": lines, "title": title}
	_note_new_slots(choices)
	camp_choosing = true
	card_focus = 0
	player.set_physics_process(false)
	if wings != null:
		wings.freeze()
	sfx("ready", 0.9, -4.0, 0.0)


func _take_vault_pick(pick: String) -> void:
	var said := ""
	var col := Color(0.95, 0.8, 0.5)
	if pick.begins_with("crystal:"):
		var kind := pick.get_slice(":", 1)
		profile.add_crystal(kind, float(pick.get_slice(":", 2)))
		profile.save()
		said = "+ " + Items.CRYSTAL["name"] % Essence.display(kind)
		col = Essence.color(kind)
	elif pick.begins_with("gear:"):
		said = _take_gear(Gear.rec(pick.substr(5)))
		col = Gear.color(pick.substr(5))
	else:
		said = _take_item(pick, "Took")
		col = Items.color(pick)
	camp_choosing = false
	camp = {}
	player.set_physics_process(true)
	if wings != null:
		wings.unfreeze()
	fx_text(player.global_position + Vector2(0, -44), said, col)
	sfx("pickup", 0.95, -2.0, 0.0)


## Consumes some of your essence crystal of a kind (up to Items.CRYSTAL
## "step"): that essence is banked into you, as at a stair (none of it
## condenses). Returns what changed (empty if you hold none).
func consume_crystal(kind: String) -> Array:
	var amount: float = profile.take_crystal(kind, float(Items.CRYSTAL["step"]))
	if amount <= 0.0:
		return []
	var lines: Array = [Items.CRYSTAL["consumed"] % [int(amount), Essence.display(kind).to_lower()]]
	lines.append_array(profile.bank({kind: amount}, {}))
	_give_bonds()
	profile.save()
	if player != null:
		var col: Color = Essence.color(kind)
		fx_ring(player.global_position, col, 40.0, 0.4, 3.0)
		light_flash(player.global_position, col, 1.2, 1.4, 0.3)
	sfx("glint", 1.2, -4.0, 0.0)
	return lines


## The recall scroll's item use (items.gd): the first use asks, a second
## within a moment reads it. True once it's read (and used up).
func recall_pressed() -> bool:
	if first_climb:
		fx_text(player.global_position + Vector2(0, -44), Items.RECALL["first_climb"], Color(0.8, 0.78, 0.85))
		return false
	if recall_ask_t > 0.0:
		recall_ask_t = 0.0
		read_recall()
		return true
	recall_ask_t = float(Items.RECALL["confirm"])
	banner = {"title": Items.RECALL["ask_title"], "lines": [Items.RECALL["ask"]], "t": float(Items.RECALL["confirm"])}
	sfx("warn_knight", 1.3, -8.0, 0.0)
	return false


## Reads a recall scroll: you leave the tower safely, keeping everything.
## Unbanked essence settles into essence crystals (one per kind) and this
## floor's soak is banked; there's no heirloom choice (the climb wasn't won).
## Then on to the next climb's tower choice.
func read_recall() -> void:
	var made: Array = []
	for k in run_essence:
		var amount := float(run_essence[k])
		if amount >= 1.0:
			profile.add_crystal(k, amount)
			made.append("%d %s" % [int(round(amount)), Essence.display(k).to_lower()])
	profile.bank({}, run_soak)
	run_essence = {}
	run_soak = {}
	# The flow you carried is lost (the owner's call): a scroll keeps crystals, not the flow.
	var flow_lines: Array = []
	if run_flow >= 1.0 and profile.path != "":
		flow_lines.append(Secret.TEXT["lost"] % Secret.display(profile.path))
	run_flow = 0.0
	profile.save()
	var lines: Array = [Items.RECALL["crystals"] % ", ".join(made) if not made.is_empty() else Items.RECALL["none"]]
	lines.append_array(flow_lines)
	var broke := break_belt(["scroll"])  # (the scroll itself is being read)
	if broke != "":
		lines.append(broke)
	var paid := pay_climb()
	if paid != "":
		lines.append(paid)
	var home := bring_pack_home()
	if home != "":
		lines.append(home)
	home = Vessel.bring_home(self)  # (into your chest, filled or not)
	if home != "":
		lines.append(home)
	if menu != null and menu.is_open():
		menu.close()
	banner = {}
	victory = {"t": 0.0, "beast": beast_name(), "lines": lines, "dark": fade > 0.5, "recall": true}
	player.set_physics_process(false)
	for e in enemies():
		e.set_physics_process(false)
	sfx("clear", 1.1, -2.0, 0.0)
	light_flash(player.global_position, Color(0.95, 0.82, 0.5), 2.0, 1.8, 0.6)


func _take_item(id: String, verb: String) -> String:
	var name: String = Items.ITEMS[id]["name"]
	if player.item_room(id) == "belt":
		# A full belt: it waits at your feet (walk off and back on to swap).
		item_drops.append({"pos": player.global_position + Vector2(18, 10), "id": id, "t": 1e9, "hold": true})
		tip("belt")
		return Items.BELT["left"] % name
	if player.add_item(id):
		_note_belt()
		return "%s: %s" % [verb, name]
	return "No room for another %s" % name


## The Entity explains the belt once it's full, and the item ring once
## there's more than one kind to choose from.
func _note_belt() -> void:
	if player == null:
		return
	if player.carried().size() >= player.belt_kinds():
		tip("belt")
	if player.carried().size() >= 2:
		tip("item_ring")


## Takes a piece of gear (a record or an id) into its slot (`into` picks a
## ring slot); what you carried there is dropped where you stand.
func _take_gear(g, into := "") -> String:
	var old: Dictionary = player.take_gear(g, into)
	if not old.is_empty():
		# Your old piece goes in your pack if there's room, else at your feet.
		if player.pack_room():
			player.pack.append(old)
			return (Gear.TEXT["took"] % Gear.display(g)) + "  ·  " + Gear.TEXT["packed"] % Gear.display(old)
		drop_gear(player.global_position, old)
	return Gear.TEXT["took"] % Gear.display(g)


## The gear you stand on goes straight into your pack (the inventory's
## "Into your pack"). False if there's no room or nothing there.
func pack_gear_here() -> bool:
	if gear_here.is_empty() or player == null or player.dead or not player.pack_room():
		return false
	var d: Dictionary = gear_here
	gear_drops.erase(d)
	gear_here = {}
	player.pack.append(d["rec"])
	fx_text(player.global_position + Vector2(0, -44), Gear.TEXT["packed"] % Gear.display(d["rec"]), Gear.color(d["rec"]))
	sfx("pickup", 1.1, -6.0)
	return true


## Wears the piece in pack space `i`; what you wore there takes its place in
## the pack (a ring swaps with ring slot `into`, or the first free one).
func wear_from_pack(i: int, into := "") -> bool:
	if player == null or player.dead or i < 0 or i >= player.pack.size():
		return false
	var g: Dictionary = player.pack[i]
	player.pack.remove_at(i)
	var old: Dictionary = player.take_gear(g, into)
	if not old.is_empty():
		player.pack.insert(i, old)
	return true


## Leaves the piece in pack space `i` on the floor where you stand.
func drop_from_pack(i: int) -> bool:
	if player == null or player.dead or i < 0 or i >= player.pack.size():
		return false
	var g: Dictionary = player.pack[i]
	player.pack.remove_at(i)
	drop_gear(player.global_position, g)
	return true


## A climb begins in `tower`: remember its best floor so far (the
## outfitter pays more for floors past it) and that nothing is paid yet.
func _note_climb_start() -> void:
	climb_best0 = int(profile.record.get("best", {}).get(tower, 0))
	climb_paid = false
	pay_line = ""


## The end of a climb, however it ends (a fall, the summit, a recall scroll,
## the first climb's Regard): the outfitter pays crystals of the tower's kind
## for the floors reached (train.gd CLIMB_PAY), once. Returns the line to show.
func pay_climb() -> String:
	if climb_paid:
		return pay_line
	climb_paid = true
	var kind: String = tower_data()["essence"]
	var amount: int = Train.climb_pay(floor_num, climb_best0)
	if amount < 1:
		return ""
	profile.add_crystal(kind, float(amount))
	profile.last_pay = {"kind": kind, "amount": float(amount)}
	profile.save()
	pay_line = Train.TEXT["pay"] % Train.price_text(kind, amount)
	return pay_line


## The end of a survived climb (or a recall scroll): your pack comes down
## to the train, to sell or keep in your chest. Returns the line to show.
func bring_pack_home() -> String:
	if player == null or player.pack.is_empty():
		return ""
	var n: int = player.pack.size()
	for g in player.pack:
		profile.pack.append(Gear.rec(g))
	player.pack = []
	profile.save()
	return Train.TEXT["home"] % [n, "piece" if n == 1 else "pieces"]


## Leaves a piece of gear (a record or an id) on the floor. A `fresh` find
## (not your old piece) of Rare or better fades in a notice on the HUD.
func drop_gear(pos: Vector2, g, fresh := false) -> void:
	var r := Gear.rec(g)
	if r.is_empty():
		return
	gear_drops.append({"pos": pos, "id": r["base"], "rec": r})
	if Gear.is_new_slot(r):
		tip("gear_slots")
	if fresh and Gear.rarity(r) != "common":
		tip("rarity")
	if fresh and Gear.noticed(r):
		var name := Gear.display(r).trim_prefix(Gear.rarity_name(r) + " ")  # ("RARE: Axe of the Riposte")
		loot_notice = {"text": Gear.TEXT["notice"] % [Gear.rarity_name(r).to_upper(), name], "color": Gear.rarity_color(r), "t": 3.5}
		sfx("glint", 1.4, -4.0, 0.0)


## A fresh find for this floor and tower (gear.gd roll_gear): rarity by
## floor (`higher` rows up for caches, camps and vaults), never a piece you
## already carry, no rings or amulets on the bondless first climb.
func find_gear(kind := "", higher := 0, at_least := "common") -> Dictionary:
	return Gear.roll_gear(kind, player.carried_gear() if player != null else [], not first_climb, floor_num, tower, higher, at_least)


## A card screen offering gear for one of the newer slots (helm, gloves, a
## ring...): the Entity explains them, the first time.
func _note_new_slots(choices: Array) -> void:
	for c in choices:
		if String(c).begins_with("gear:") and Gear.is_new_slot(String(c).substr(5)):
			tip("gear_slots")
			return


## The rings you wear (0 to 2 records).
func worn_rings() -> Array:
	var out: Array = []
	for s in ["ring1", "ring2"]:
		if Gear.is_gear(player.gear.get(s, {})):
			out.append(player.gear[s])
	return out


## Gear on the floor: walk over it with an empty slot and you take it;
## otherwise it waits for Y (or the phone's Take button), comparing it with
## what you carry.
func _update_gear_drops() -> void:
	gear_here = {}
	if player == null or player.dead or climbing:
		return
	var best_d := Gear.REACH
	for d in gear_drops:
		var dist: float = player.global_position.distance_to(d["pos"])
		if dist <= best_d:
			best_d = dist
			gear_here = d
	if gear_here.is_empty():
		return
	tip("gear")
	var g: Dictionary = gear_here["rec"]
	if player.gear_id(player.slot_for(g)) == "":
		gear_drops.erase(gear_here)
		gear_here = {}
		player.take_gear(g)
		fx_text(player.global_position + Vector2(0, -44), "+ " + Gear.display(g), Gear.color(g))


## Y or the Take button: swap what you carry for the gear you stand on (your
## old piece is dropped where you stand).
func take_gear_here(into := "") -> bool:
	if gear_here.is_empty() or player == null or player.dead:
		return false
	var d: Dictionary = gear_here
	gear_drops.erase(d)
	gear_here = {}
	var msg := _take_gear(d["rec"], into)
	fx_text(player.global_position + Vector2(0, -44), msg, Gear.color(d["rec"]))
	return true


## Dev tools: give yourself a piece of gear ("" takes armor off, "-helm"
## and the like empties a slot).
func dev_give_gear(id: String) -> void:
	if id == "" or id.begins_with("-"):
		var slot := "armor" if id == "" else id.substr(1)
		for s in Gear.carry_slots(slot):
			player.gear[s] = {}
		player.refresh_gear()
		return
	player.take_gear(id)


## Dev tools: jumping to another floor from a camp leaves it.
func _leave_camp_now() -> void:
	if camp_choosing:
		player.set_physics_process(true)
	in_camp = false
	camp_choosing = false


## Items on the floor: walk over one to pick it up.
func _update_item_drops(delta: float) -> void:
	for d in item_drops:
		d["t"] -= delta
		if player == null or player.dead or camp_choosing or d["t"] <= 0.0:
			continue
		var dist: float = player.global_position.distance_to(d["pos"])
		if dist > 40.0:
			d.erase("hold")  # stepped off: it can be picked up again
		if dist > 26.0 or d.get("hold", false):
			continue
		var name: String = Items.ITEMS[d["id"]]["name"]
		var room: String = player.item_room(d["id"])
		if room == "belt":
			offer_belt_swap(d)
			return
		if player.add_item(d["id"]):
			d["t"] = 0.0
			fx_text(player.global_position + Vector2(0, -44), "+ " + name, Items.color(d["id"]))
			sfx("pickup")
			tip("items")
			tip("inventory")
			_note_belt()
		elif not d.get("told", false):
			d["told"] = true
			fx_text(player.global_position + Vector2(0, -44), "No room for another " + name, Color(0.8, 0.78, 0.85))
	item_drops = item_drops.filter(func(d): return d["t"] > 0.0)


## Stepping on a new kind of item with a full belt: the take card. Swap one
## stack out (it's left where you stand) or leave the new item where it is.
## The monsters wait while you choose.
func offer_belt_swap(d: Dictionary) -> void:
	var name: String = Items.ITEMS[d["id"]]["name"]
	var choices: Array = player.carried().filter(func(id): return id != Vessel.ID).map(func(id): return "belt:" + id)  # (a vessel isn't swapped out: what it holds would spill)
	choices.append("belt:")
	camp = {"stage": "belt", "choices": choices, "lines": [Items.BELT["full_sub"] % name], "title": Items.BELT["full_title"], "drop": d}
	camp_choosing = true
	card_focus = 0
	tip("belt")
	player.set_physics_process(false)
	if wings != null:
		wings.freeze()
	sfx("ready", 1.1, -6.0, 0.0)


## Takes a card of the belt's take card: "belt:" leaves it, "belt:<id>"
## drops that stack where you stand and takes the new item.
func _take_belt_pick(pick: String) -> void:
	var d: Dictionary = camp.get("drop", {})
	var out := pick.substr(5)
	var said := ""
	var col := Color(0.8, 0.78, 0.85)
	if out == "" or d.is_empty():
		if not d.is_empty():
			d["hold"] = true
		said = Items.BELT["leave_name"]
	else:
		var n: int = player.item_count(out)
		player.items.erase(out)
		for i in n:
			item_drops.append({"pos": player.global_position + Vector2(-10 + 7 * i, 12), "id": out, "t": Items.DROP_LIFE, "hold": true})
		player.add_item(d["id"])
		d["t"] = 0.0
		said = "+ " + String(Items.ITEMS[d["id"]]["name"])
		col = Items.color(d["id"])
		if player.item_sel == out or player.item_count(player.item_sel) <= 0:
			player.item_sel = d["id"]
		sfx("pickup")
		_note_belt()
	camp_choosing = false
	camp = {}
	player.set_physics_process(true)
	if wings != null:
		wings.unfreeze()
	fx_text(player.global_position + Vector2(0, -44), said, col)


## The end of a survived climb (or a recall scroll): unused belt items
## break into essence crystals at half their worth, one crystal per kind.
## Returns the line to show ("" if nothing was carried). `skip` leaves out
## items (the recall scroll being read).
func break_belt(skip: Array = []) -> String:
	if belt_broken or player == null:
		return ""
	belt_broken = true
	var carried := {}
	for id in player.items:
		if not (id in skip) and id != Vessel.ID and int(player.items[id]) > 0:  # (a vessel comes home whole: Vessel.bring_home)
			carried[id] = int(player.items[id])
	var worth: Dictionary = Items.break_value(carried)
	var made: Array = []
	for k in Essence.KINDS:
		var amount := float(worth.get(k, 0.0))
		if amount >= 1.0:
			profile.add_crystal(k, amount)
			made.append("%d %s" % [int(round(amount)), Essence.display(k).to_lower()])
	for id in carried:
		player.items.erase(id)
	if made.is_empty():
		return ""
	profile.save()
	return Items.BELT["broke"] % ", ".join(made)


## Throws a Fire Flask where you aim (short of a wall): it bursts a moment later.
func throw_flask(p) -> void:
	var data: Dictionary = Items.ITEMS["fire_flask"]
	var from: Vector2 = p.global_position
	var to := from
	var step := 8.0
	var dist := 0.0
	while dist < float(data["range"]):
		var next: Vector2 = from + p.aim * (dist + step)
		if is_solid(next):
			break
		to = next
		dist += step
	var r: float = float(data["radius"]) * (Items.CONTRACTOR_FLASK if p.has_bond("flame_contractor") else 1.0)
	var dmg: float = float(data["dmg"]) * (1.0 + float(data["per_floor"]) * maxf(0.0, floor_num - 1))
	flasks.append({"from": from, "to": to, "t": 0.0, "total": float(data["flight"]), "dmg": dmg, "r": r})
	sfx("swing", 0.7, -4.0)


func _update_flasks(delta: float) -> void:
	for f in flasks:
		f["t"] += delta
		if f["t"] >= f["total"]:
			_burst_flask(f)
	flasks = flasks.filter(func(f): return f["t"] < f["total"])
	if flare_t > 0.0:
		flare_t -= delta
		if flare_t <= 0.0 and flare_light >= 0:
			lighting.remove_light(flare_light)
			flare_light = -1


func _burst_flask(f: Dictionary) -> void:
	var col: Color = Items.color("fire_flask")
	var pos: Vector2 = f["to"]
	for e in targets():
		var to: Vector2 = e.global_position - pos
		if to.length() < f["r"] + e.radius:
			e.take_hit(f["dmg"], to.normalized() if to.length() > 0.1 else Vector2.ZERO, 180.0, true)
			_kindled(e)
	add_flame(pos, f["r"] * 0.8, float(Items.ITEMS["fire_flask"]["burn"]), true)
	fx_ring(pos, col, f["r"], 0.35, 6.0)
	fx_burst(pos, Vector2.ZERO, col, 22, 300.0)
	fx_burst(pos, Vector2.ZERO, Color(1.0, 0.9, 0.5), 10, 180.0)
	light_flash(pos, col, 1.2 + f["r"] / 60.0, 2.0, 0.45)
	sfx("burn", 0.9, 0.0)
	sfx("hit_heavy", 0.6, -4.0)
	shake(4.0)


## Flare Powder: the room is lit for a while, and hidden traps and secret
## walls near where it burst glint (flare_reveals).
func light_flare(pos: Vector2, seconds: float) -> void:
	flare_t = seconds
	flare_pos = pos
	if flare_light >= 0:
		lighting.remove_light(flare_light)
	var data: Dictionary = Items.ITEMS["flare"]
	flare_light = lighting.add_light(pos, float(data["radius"]), Color(1.0, 0.88, 0.62), 0.9, 0.25) if lighting != null else -1
	light_flash(pos, Items.color("flare"), 2.4, 2.0, 0.6)
	sfx("glint", 0.8, -2.0, 0.0)


## Is this spot lit by a Flare (hidden traps and secret walls there glint)?
func flare_reveals(pos: Vector2) -> bool:
	return flare_t > 0.0 and pos.distance_to(flare_pos) < float(Items.ITEMS["flare"]["reveal"])


# --- towers ---------------------------------------------------------------------

func tower_data() -> Dictionary:
	return Towers.TOWERS[tower]


func beast_name() -> String:
	return tower_data()["beast"]


## Each climb begins by choosing a tower; after the Regard, on the train
## (its menu opens once the title has gone: _ready, menu.gd close).
func await_tower() -> void:
	choosing_tower = true
	on_train = profile.regarded
	if on_train:
		Train.stock(profile)
		profile.save()
	card_focus = maxi(Towers.ORDER.find(tower), 0)
	player.set_physics_process(false)
	for e in enemies():
		e.set_physics_process(false)


## Opens the train (between climbs, after the Regard): its menu stands in
## for the tower choice. (A new climb's _ready does this; tests call it.)
func open_train() -> void:
	on_train = true
	choosing_tower = true
	player.set_physics_process(false)
	for e in enemies():
		e.set_physics_process(false)
	Train.stock(profile)
	profile.save()
	menu.train_car = Train.HOME  # (it opens on your own car)
	menu.open("train")


## Leaves the train for a tower: your pack and packed supplies come with
## you (train.gd pack_up), then the climb starts.
func depart(id: String) -> void:
	if not on_train or not Towers.TOWERS.has(id):
		return
	choose_tower(id)  # (packs up and leaves the train)
	if menu != null and menu.is_open():
		menu.close()


## Picks this climb's tower and starts on its first floor.
func choose_tower(id: String) -> void:
	if not choosing_tower or not Towers.TOWERS.has(id):
		return
	if on_train:
		# Leaving the train (Depart, or the dev tools): your pack and supplies come too.
		Train.pack_up(profile, player)
		on_train = false
	choosing_tower = false
	tower = id
	profile.last_tower = id
	profile.save()
	_note_climb_start()
	_apply_tower_look()
	_start_floor(1)
	player.set_physics_process(true)
	sfx("equip_sword", 0.8, -2.0, 0.0)
	_greet()


func _greet() -> void:
	tip("entity")
	tip("move")
	if not first_climb:
		tip("casting")
		tip("climber")
	if first_climb:
		banner = {"title": "YOUR FIRST CLIMB", "lines": ["You bear no mark.", "Climb %d floors. %s is watching." % [ProfileScript.FIRST_CLIMB_FLOORS, beast_name().capitalize()]], "t": 4.0}
	else:
		banner = {"title": tower_data()["name"].to_upper(), "lines": [], "t": 2.5}


## Each tower's stone, light and torches.
func _apply_tower_look() -> void:
	var t := tower_data()
	lighting.set_tower_look(tower)
	room_view.self_modulate = t["stone"] * Palette.TOWER_TINT.get(tower, Color.WHITE)
	room_view.set_torch_color(t["torch"])


func _floor_title() -> String:
	if in_camp:
		return Items.CAMP["title"]
	if first_climb:
		return "FLOOR %d OF %d" % [floor_num, ProfileScript.FIRST_CLIMB_FLOORS]
	return "FLOOR %d" % floor_num


## Rebuilds the climber's bonds from the saved marks, keeping charge and burns.
func _give_bonds() -> void:
	if player == null:
		return
	if unbound != null:
		unbound._sync()  # (an Unbound's techniques keep their fill)
	var old: Dictionary = player.bonds.duplicate()
	player.bonds.clear()
	for part in profile.bonds:
		var info: Dictionary = profile.bonds[part]
		var b = BondScript.new(info["id"], part)
		b.step = ProfileScript.step_for_xp(float(info["xp"]))
		b.faint = bool(info["faint"])
		if old.has(part) and old[part].id == b.id:
			b.essence = minf(old[part].essence, b.capacity())
			b.burned = old[part].burned
			b.selected = old[part].selected
		b.tunes = SecretBonds.active_tunes(profile)  # the Developer's Tune (secret_bonds.gd)
		b.edits = SecretBonds.active_edits(profile)  # ...and its Edit
		b.attr_power = 1.0 + profile.attribute("fire")
		b.attr_fill = 1.0 + profile.attribute("water")
		player.bonds[part] = b
	# Hunter's Keen Eyes (and Smokeborn): you see farther in the dark (lighting.player_reach).
	# Essence density: small passive bonuses, one per attribute.
	player.attr_speed = 1.0 + profile.attribute("air")
	player.attr_strength = 1.0 + profile.attribute("blade")
	player.attr_will = 1.0 + profile.attribute("iron")
	# The flow (secret.gd): what your path's banked essence does.
	player.set_flow(profile.path, profile.flow_step())
	# Health: Vitality, then whatever your gear adds (refresh_gear), then Unmaking's cost.
	player.base_hp = player.MAX_HP * (1.0 + profile.attribute("stone"))
	player.refresh_gear()
	if unbound != null:
		unbound.give()  # (the Unbound carry techniques in the marks' places)


# --- essence and the Regard ----------------------------------------------------

## A body part did its thing (called by the climber).
func add_soak(part: String, amount: float) -> void:
	run_soak[part] = float(run_soak.get(part, 0.0)) + amount
	climb_soak[part] = float(climb_soak.get(part, 0.0)) + amount


## A summit: the tower's beast takes notice, and a full body part takes a
## new mark (at most one a climb). Returns the lines to show.
var marked_this_climb := false


func summit_mark() -> Array:
	if first_climb or marked_this_climb:
		return []
	var part: String = profile.ready_for_mark()
	if part == "":
		return []
	var id: String = profile.choose_bond(profile.tally, climb_soak)
	if id == "":
		return []
	profile.add_bond(part, id, false)
	marked_this_climb = true
	GuideScript.moment("new_mark", "new_mark", {"mark": BondScript.Bonds.BONDS[id]["name"]})
	sfx("crit", 0.7, -4.0)
	_give_bonds()
	profile.save()
	return ["The beast takes notice. Essence takes hold in your %s: the %s mark" % [BondScript.PART_NAMES[part], BondScript.Bonds.BONDS[id]["name"]]]


## The summit's victory screen, with the stair's lines.
func show_victory(lines: Array) -> void:
	victory = {"t": 0.0, "beast": beast_name(), "lines": lines, "dark": fade > 0.5}
	player.set_physics_process(false)
	sfx("clear", 0.7, 0.0, 0.0)


## Winning the Proving (proving.gd): one of your marks grows a step, the
## one whose body part you used most this climb (not past step 5). Returns a line.
func proving_raise() -> String:
	var best := ""
	var most := -1.0
	for part in profile.bonds:
		if ProfileScript.step_for_xp(float(profile.bonds[part]["xp"])) >= ProfileScript.STEP_XP.size():
			continue
		var used := float(climb_soak.get(part, 0.0))
		if used > most:
			most = used
			best = part
	if best == "":
		return ""
	var step: int = profile.raise_step(best)
	if step <= 0:
		return ""
	_give_bonds()
	profile.save()
	return "The tower has taken your measure: %s grows to step %d" % [BondScript.Bonds.BONDS[profile.bonds[best]["id"]]["name"], step]


## How close an unmarked body part is to taking a mark, 0..1 (for drawing).
func soak_fraction(part: String) -> float:
	if first_climb:
		# Relative to the leading part: the brightest glow is where it will form.
		var most := 15.0
		for pt in climb_soak:
			most = maxf(most, float(climb_soak[pt]))
		return clampf(float(climb_soak.get(part, 0.0)) / most, 0.0, 1.0)
	var need: float = ProfileScript.NEW_MARK_SOAK * ProfileScript.MARK_FULL
	var have := float(profile.soak.get(part, 0.0))
	var fill := clampf(have / ProfileScript.NEW_MARK_SOAK, 0.0, 1.0)
	var coming: float = float(run_soak.get(part, 0.0)) * ProfileScript.SOAK_RATE * (1.0 - fill) * profile.body_drag()
	return clampf((have + coming) / need, 0.0, 1.0)


## How much each unmarked body part has soaked: this climb on the first
## climb, else everything banked plus this floor's.
func part_soak(part: String) -> float:
	if first_climb:
		return float(climb_soak.get(part, 0.0))
	return float(profile.soak.get(part, 0.0)) + float(run_soak.get(part, 0.0))


## The unmarked body part that would take the next mark ("" if none has soaked).
func leading_part() -> String:
	var best := ""
	var most := 0.0
	for pt in BondScript.Bonds.PARTS:
		if profile.bonds.has(pt):
			continue
		var v := part_soak(pt)
		if v > most:
			most = v
			best = pt
	return best


## The bond the next mark would be, if it formed now.
func predicted_bond() -> String:
	var part := leading_part()
	if part == "":
		return ""
	var essence: Dictionary = climb_essence
	if not first_climb:
		essence = profile.tally.duplicate()
		for k in run_essence:
			essence[k] = float(essence.get(k, 0.0)) + float(run_essence[k])
	return profile.choose_bond(essence, climb_soak)


func gather_essence(kind: String, amount: float, from: Vector2) -> void:
	run_essence[kind] = float(run_essence.get(kind, 0.0)) + amount
	climb_essence[kind] = float(climb_essence.get(kind, 0.0)) + amount
	tip("essence")
	if fx != null:
		fx.motes(from, Essence.color(kind), int(ceil(amount)), player)


func on_player_died() -> void:
	profile.note("deaths")
	if run_flow > 0.0 and profile.path != "":
		run_flow = 0.0  # the flow you carried is lost (what's banked stays)
	if not first_climb:
		# Your pack and belt are lost, maybe your weapon too (lost.gd); the
		# pieces are remembered, and may turn up again on a later climb.
		var loss := Lost.fall(profile, player, tower, floor_num, weapon_loss_chance)
		fall_note = loss["lines"]
		fall_note.append_array(Vessel.on_fall(self))  # (a vessel and what it held go with the belt)
		if not fall_note.is_empty():
			tip("fall_loss")
		pay_climb()  # (the outfitter pays for the floors all the same: shown on the fall screen)
	profile.save()
	GuideScript.moment("death", "death", {"floor": floor_num, "beast": beast_name()})
	if first_climb and regard.is_empty() and not regard_pending:
		# Even fallen, you are regarded: the faint mark is granted (and saved)
		# now, and shown after a moment (a restart before then keeps it).
		regard_pending = true
		_grant_regard(true)
		get_tree().create_timer(1.6, true, false, true).timeout.connect(_begin_regard.bind(true))


## The beast takes notice and your most-used body part takes its first mark.
## Reaching the top earns a full mark; falling earns a faint one. A barrier
## broken on the first climb, and the beast refuses: no mark, Unbound.
var regard_mark := {}  # the Regard's mark once granted: {fell, part, id}


## Grants (and saves) the Regard's mark, once.
func _grant_regard(fell: bool) -> void:
	if not regard_mark.is_empty():
		return
	pay_climb()  # (the first climb is paid for too, fallen or not: money for the first train)
	if unbound != null and unbound.broke_rules:
		# A barrier broken on this climb: the beast refuses to mark you (unbound_run.gd).
		UnboundRun.Unbound.become(profile)
		profile.regarded = true
		profile.climbs += 1
		profile.save()
		regard_mark = {"fell": fell, "part": "", "id": "", "refused": true}
		_give_bonds()
		tip("unbound")
		return
	var part := leading_part()
	if part == "":
		part = "hand"
	var id: String = profile.choose_bond(climb_essence, climb_soak)
	profile.add_bond(part, id, fell)
	profile.regarded = true
	profile.climbs += 1
	profile.save()
	regard_mark = {"fell": fell, "part": part, "id": id}


func _begin_regard(fell: bool) -> void:
	if not regard.is_empty():
		return
	_grant_regard(fell)
	if not fell:
		break_belt()  # (survived: what's left on the belt becomes crystals)
		bring_pack_home()  # (and the pack comes down to the train, which appears now)
		Vessel.bring_home(self)
	regard = {"fell": regard_mark["fell"], "part": regard_mark["part"], "id": regard_mark["id"], "refused": regard_mark.get("refused", false), "t": 0.0, "dark": fade > 0.5}
	GuideScript.moment("regard", "regard")
	banner = {}
	regard_pending = false
	player.set_physics_process(false)
	for e in enemies():
		e.set_physics_process(false)
	for c in get_children():
		if "reflected" in c:
			c.queue_free()
	sfx("clear", 0.55, 0.0, 0.0)
	sfx("glint", 0.6, -2.0, 0.0)


## True once the Regard has played long enough to be dismissed.
## True once the Regard or the victory screen can be dismissed.
func overlay_done() -> bool:
	return regard_done() or (not victory.is_empty() and victory["t"] > 2.5)


func overlay_showing() -> bool:
	return not regard.is_empty() or not victory.is_empty()


func regard_done() -> bool:
	return not regard.is_empty() and regard["t"] > 3.0


func end_regard() -> void:
	if unbound != null and unbound.ask_at_regard():
		return  # (first: accept the mark, or refuse it)
	# Survived (the beast fell, or the Regard without a fall): first keep an heirloom.
	var survived: bool = not victory.is_empty() or (not regard.is_empty() and not regard.get("fell", false))
	if survived and not victory.get("recall", false) and not heirloom_offered and _offer_heirloom():
		return
	Engine.time_scale = 1.0
	if get_tree().current_scene == self:  # (tests run the room outside a scene)
		get_tree().reload_current_scene()


## The heirloom choice: a card for each piece you carry that isn't already
## the heirloom in its slot, and one to keep nothing new. Returns false if
## there's nothing to offer.
func heirloom_choices() -> Array:
	var choices: Array = []
	for hs in Gear.HEIRLOOM_SLOTS:
		var gs: String = hs.get("gear", "")
		if gs == "":
			continue  # (a slot for later)
		var kept: Array = Gear.heirloom_pieces(profile.heirlooms, hs["id"])
		if gs == "ring":
			# Rings: one card keeps both rings you wear.
			var rings := worn_rings()
			if not rings.is_empty() and not _same_set(rings, kept):
				choices.append("heir:rings")
			continue
		var g = player.gear.get(gs, {})
		if not Gear.is_gear(g):
			continue
		if kept.size() == 1 and Gear.same(kept[0], g):
			continue
		choices.append("heir:" + Gear.code(g))
	if not choices.is_empty():
		choices.append("heir:")
	return choices


## Two lists of pieces hold the same pieces (in any order).
func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var left := b.duplicate()
	for g in a:
		var hit := -1
		for i in left.size():
			if Gear.same(left[i], g):
				hit = i
				break
		if hit < 0:
			return false
		left.remove_at(hit)
	return true


func _offer_heirloom() -> bool:
	heirloom_offered = true
	var choices := heirloom_choices()
	if choices.is_empty():
		return false
	victory = {}
	regard = {}
	banner = {}
	Engine.time_scale = 1.0
	camp = {"stage": "heirloom", "choices": choices, "lines": [Gear.HEIRLOOM_TEXT["sub"]]}
	tip("heirloom")
	camp_choosing = true
	card_focus = 0
	player.set_physics_process(false)
	sfx("ready", 0.7, -4.0, 0.0)
	return true


## Keeps a piece as an heirloom ("" keeps nothing new, "rings" keeps both
## rings you wear), in full repair, then the next climb.
func keep_heirloom(id: String) -> void:
	var kept := false
	if id == "rings":
		var rings := worn_rings()
		if not rings.is_empty():
			profile.heirlooms["rings"] = rings.map(func(r): return Gear.heirloom_copy(r))
			kept = true
	elif id != "" and Gear.is_gear(id):
		profile.heirlooms[Gear.heirloom_slot(id)] = Gear.heirloom_copy(id)
		kept = true
	if kept:
		profile.note("heirlooms")
		profile.save()
		sfx("heirloom", 1.0, 0.0, 0.0)
	camp_choosing = false
	end_regard()


## Plays another climber slot (slots.gd), from the climber picker: the
## climber played now never saves again, the slot becomes current, and the
## game starts again with its climber (on the train after the Regard, the
## first climb, or, in an empty slot, the appearance page for a new
## climber). False for a slot that doesn't exist (there's no seventh).
func switch_climber(slot: int) -> bool:
	if not Slots.valid(slot):
		return false
	profile.saving = false  # (nothing of this climber can land in another's file)
	Slots.clear(slot)  # (an empty slot starts clean)
	Slots.set_current(slot)
	GuideScript.unload()
	Engine.set_meta("sixfold_title_seen", true)  # (straight in, not via the title)
	if get_tree().current_scene == self:  # (tests run the room outside a scene)
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
	else:
		_load_climber()
		if menu != null:
			if not profile.created:
				menu.open("create")
			else:
				menu.close()
	return true


## Deletes a climber for good (the picker asks twice). If it was the climber
## being played, the game starts again on the picker with whoever is current now.
func delete_climber(slot: int) -> void:
	if not Slots.valid(slot):
		return
	var was_current := slot == Slots.current()
	if was_current:
		profile.saving = false  # (the deleted climber must never write itself back)
	Slots.delete(slot)
	if not was_current:
		return
	GuideScript.unload()
	if get_tree().current_scene == self:
		Engine.set_meta("sixfold_climbers", true)
		get_tree().reload_current_scene()
	else:
		_load_climber()
		if menu != null:
			menu.open_climbers()


## Tests: the current slot's climber, loaded in place of a scene restart.
func _load_climber() -> void:
	profile = ProfileScript.new()
	profile.save_path = Slots.current_path()
	profile.load_save()
	profile.saving = not Engine.has_meta("sixfold_test")
	best_floor = profile.best_floor
	first_climb = not profile.regarded
	_give_bonds()
	player.use_heirlooms(profile.heirlooms)
	apply_appearance()


## Starts over as a new climber in this slot: no marks, back to the bondless
## first climb (the other slots are untouched).
func new_climber() -> void:
	profile.reset()
	Engine.time_scale = 1.0
	apply_appearance()
	# The new climber chooses a look before the first climb (straight away,
	# not via the title: _ready opens the creation page).
	if get_tree().current_scene == self:  # (tests run the room outside a scene)
		Engine.set_meta("sixfold_title_seen", true)
		get_tree().reload_current_scene()
	elif menu != null:
		menu.open("create")


## The climber wears profile.appearance: in the tower, and on the climber screen.
func apply_appearance() -> void:
	climber_look = Appearance.look(profile.appearance)
	if player != null:
		player.set_appearance(profile.appearance)


## A new look chosen (the creation page, or Appearance later): kept and shown.
func set_appearance(app: Dictionary) -> void:
	profile.appearance = Appearance.normalized(app)
	profile.save()
	apply_appearance()


## Tests: start with two marks instead of a bondless first climb.
func grant_test_bonds() -> void:
	profile.add_bond("hand", "stormcaller", false)
	profile.add_bond("legs", "windwalker", false)
	profile.regarded = true
	first_climb = false
	_give_bonds()


# --- attack turns ------------------------------------------------------------

func _tidy_attackers() -> void:
	attackers = attackers.filter(func(e): return is_instance_valid(e) and not e.dead)


func can_attack() -> bool:
	_tidy_attackers()
	return attackers.size() < MAX_ATTACKERS


func holds_attack(e) -> bool:
	return e in attackers


## A monster asks for a turn to attack. True if it may go ahead.
func request_attack(e) -> bool:
	if e.disarm_t > 0.0:
		return false  # Surgeon: a disarmed foe can't start an attack
	if e in attackers or e.challenged_t > 0.0 or e.feud != null:  # Challenged foes come at you regardless (and a feud needs no turn)
		return true
	if not can_attack():
		return false
	attackers.append(e)
	return true


func release_attack(e) -> void:
	attackers.erase(e)


## The first time the climber meets a system: the Entity's tip for it (once
## per save; the words are in entity.gd's TIPS). Safe to call every frame.
func tip(id: String) -> bool:
	return GuideScript.tip(id)


## The same, inside a menu (the train): the tip's line to show there and
## then the first time, else "" (guide.gd tell).
func tip_now(id: String) -> String:
	return GuideScript.tell(id)


func menu_open() -> bool:
	return menu != null and menu.is_open()


## True while the title screen (or a page opened from it) covers the game.
func title_showing() -> bool:
	return menu != null and menu.backdrop_showing()


# --- the secret essences (secret.gd) -------------------------------------------

## A great foe fell (on_enemy_killed): its secret essence rises. The first
## time, with no path chosen, the game stops on the choice (offer_path); the
## essence waits for it. Ordinary monsters leave none.
func secret_drop(e) -> void:
	if not secret_on or first_climb:
		return
	var drop: Dictionary = Secret.drop(Secret.great_foe(e), tower, floor_num)
	if drop.is_empty():
		return
	tip("secret")
	var at: Vector2 = e.global_position
	if profile.path == "":
		if player == null or player.dead:
			return  # (no choice over a fall)
		for k in drop:
			secret_pending.append({"kind": k, "amount": float(drop[k]), "pos": at})
		if not (camp_choosing and camp.get("stage", "") == "path"):
			offer_path()
		return
	for k in drop:
		rise_secret(k, float(drop[k]), at)


## Secret essence of `kind` rising at `from`: your path's soaks in (the
## flow, unbanked until the stair); the other passes through you.
func rise_secret(kind: String, amount: float, from: Vector2) -> void:
	if amount <= 0.0 or profile.path == "":
		return
	if kind == profile.path:
		run_flow += amount
		if fx != null:
			fx.secret_motes(from, Secret.color(kind), int(ceil(amount)), player, false)
		fx_text(from + Vector2(0, -64), Secret.TEXT["gather"] % [int(round(amount)), Secret.display(kind)], Secret.KINDS[kind]["light"])
		light_flash(from, Secret.color(kind), 1.6, 1.6, 0.6)
		sfx("glint", 0.8, -4.0, 0.0)
	else:
		pass_through(kind, amount, from)


## The other secret essence: it rises, streaks through you and out, unbanked
## (a vessel on the belt holds what it can: vessel.gd capture).
func pass_through(kind: String, amount: float, from: Vector2) -> void:
	amount = Vessel.capture(self, kind, amount, from)
	if amount <= 0.001:
		return
	if fx != null:
		fx.secret_motes(from, Secret.color(kind), int(ceil(amount)), player, true)
	if player != null:
		fx_text(player.global_position + Vector2(0, -58), Secret.TEXT["passes"] % Secret.display(kind), Color(Secret.color(kind), 0.9))
	tip("secret_pass")


## The path's essence carried up a stair settles in the flow (profile.gd
## bank_flow); a step reached is said and the climber feels it at once.
## Returns lines for the stair's banner.
func _bank_flow() -> Array:
	if run_flow <= 0.0 or profile.path == "":
		run_flow = 0.0
		return []
	var before: int = profile.flow_step()
	var lines: Array = profile.bank_flow(run_flow)
	run_flow = 0.0
	var after: int = profile.flow_step()
	for st in range(before + 1, after + 1):
		tip("flow_%d" % st)
	if after > before and player != null:
		var col := Secret.color(profile.path)
		fx_ring(player.global_position, col, 70.0, 0.6, 4.0)
		light_flash(player.global_position, col, 2.0, 1.8, 0.6)
	return lines


## True once your path's gem shows on the HUD: banked flow at its first step.
func flow_shown() -> bool:
	return profile != null and profile.flow_step() >= 1


## The path choice, on the card screen: Life or Unmaking. The monsters wait.
## It's for good, so a card is taken with a second press (and not in the
## first moment, so a press meant for the fight can't take it).
func offer_path() -> void:
	camp = {"stage": "path", "choices": Secret.ORDER.map(func(k): return "path:" + k), "lines": Secret.TEXT["choose_lines"],
		"title": Secret.TEXT["choose_title"], "t": 0.0, "armed": -1}
	camp_choosing = true
	card_focus = 0
	if player != null:
		player.set_physics_process(false)
		player.iframes = maxf(player.iframes, 9999.0)  # (nothing still in flight can hurt you while you choose)
	if wings != null:
		wings.freeze()
	sfx("ready", 0.6, -2.0, 0.0)


## Seconds the path choice ignores presses after it opens.
const PATH_GRACE := 0.8


func _take_path_pick(i: int) -> void:
	if float(camp.get("t", 0.0)) < PATH_GRACE:
		return
	if int(camp.get("armed", -1)) != i:
		camp["armed"] = i
		card_focus = i
		sfx("ui_move")
		return
	choose_path(String(camp["choices"][i]).substr(5))


## The path is chosen (saved, for good): what waited rises at once.
func choose_path(kind: String) -> void:
	if not Secret.is_kind(kind):
		return
	profile.path = kind
	profile.flow = 0.0
	profile.save()
	if camp.get("stage", "") == "path":
		camp_choosing = false
		camp = {}
		if player != null and not player.dead:
			player.set_physics_process(true)
			player.iframes = 1.0
		if wings != null:
			wings.unfreeze()
	_give_bonds()
	if banner.is_empty():
		banner = {"title": Secret.TEXT["chosen_title"] % Secret.display(kind).to_upper(), "lines": [Secret.TEXT["chosen"]], "t": 3.5}
	else:  # (a banner waiting, like the Proving's "PROVEN": the choice joins it)
		banner["lines"] = [Secret.TEXT["chosen_line"] % [Secret.display(kind), Secret.TEXT["chosen"]]] + banner.get("lines", [])
		banner["t"] = maxf(float(banner.get("t", 0.0)), 4.0)
	tip("secret_path")
	sfx("crit", 0.6, -2.0, 0.0)
	if player != null:
		light_flash(player.global_position, Secret.color(kind), 2.4, 2.0, 0.8)
		fx_ring(player.global_position, Secret.color(kind), 90.0, 0.7, 5.0)
	var waiting := secret_pending
	secret_pending = []
	for w in waiting:
		rise_secret(w["kind"], w["amount"], w["pos"])


## Clears the path and all its flow: the shadow is an ordinary shadow again
## and a path can be chosen anew. Hook for later (the Developer mark, or a
## Maker who grants a change of path); the dev tools use it now.
func reset_path() -> void:
	var was: String = profile.path
	profile.path = ""
	profile.flow = 0.0
	run_flow = 0.0
	secret_pending = []
	profile.save()
	_give_bonds()
	if was != "" and player != null:
		fx_burst(player.global_position + Vector2(0, 10), Vector2.UP, Secret.color(was), 22, 120.0)
		fx_text(player.global_position + Vector2(0, -50), Secret.TEXT["reset"], Secret.color(was))


## Dev tools: take a path at once (keeping the flow), or bank flow.
func dev_set_path(kind: String) -> void:
	if not Secret.is_kind(kind):
		return
	profile.path = kind
	profile.save()
	_give_bonds()


func dev_add_flow(amount: float) -> void:
	if profile.path == "":
		return
	profile.bank_flow(amount)
	profile.save()
	_give_bonds()


# --- dev tool ----------------------------------------------------------------

## Puts a bond on a body part at a step ("" removes the mark). Saved.
func dev_set_mark(part: String, id: String, step: int) -> void:
	if id == "":
		profile.bonds.erase(part)
	else:
		profile.bonds[part] = {"id": id, "xp": ProfileScript.STEP_XP[clampi(step, 1, 5) - 1], "faint": false, "debt": 0.0}
		profile.soak.erase(part)
		profile.regarded = true
		first_climb = false
	profile.save()
	_give_bonds()
	if player.bonds.has(part):
		player.bonds[part].essence = player.bonds[part].capacity()


## Moves the climb to another tower's floor 1.
func dev_tower(id: String) -> void:
	if choosing_tower:
		choose_tower(id)
		return
	_leave_camp_now()
	tower = id
	profile.last_tower = id
	profile.save()
	_note_climb_start()
	_apply_tower_look()
	_start_floor(1)
	_greet()


## Straight to a tower's beast, at full health with full marks.
func dev_beast(id: String) -> void:
	dev_tower(id)
	profile.regarded = true
	first_climb = false
	_start_floor(int(tower_data().get("summit", Towers.SUMMIT)))
	player.dead = false
	player.set_physics_process(true)
	player.hp = player.max_hp
	player.sta = player.max_sta
	player.poison_t = 0.0
	for b in player.bonds.values():
		b.essence = b.capacity()
		b.burned = false


func dev_floor(n: int) -> void:
	if choosing_tower:
		choose_tower(tower)
	_leave_camp_now()
	if n == int(Towers.PROVING["floor"]) and first_climb and proving.enabled:
		profile.regarded = true  # (the Proving is never on the bondless first climb)
		first_climb = false
	_start_floor(n)


## Something would kill the climber (player.gd): true if the ordinary
## Proving casts them down instead (proving.gd).
func proving_spare() -> bool:
	return proving != null and proving.spare()


## Every floor of rooms gets this kind of puzzle ("" for the usual mix);
## goes to a floor of rooms at once to try it.
func dev_puzzle(kind: String) -> void:
	PuzzleScript.Catalog.forced = kind
	var n := floor_num
	if n < 2 or n >= int(tower_data().get("summit", Towers.SUMMIT)):
		n = 2
	if kind != "":
		dev_floor(n)


## A monster near the climber, inside the room.
func dev_spawn(kind: String):
	var pos: Vector2 = player.global_position + Vector2.from_angle(randf() * TAU) * 200.0
	pos = walkable_point(player.global_position, pos, 20.0)
	if kind == MirrorScript.THEME:
		return MirrorScript.spawn(self, pos)  # a mirror image of you (mirror.gd)
	return spawn_enemy(kind, pos)


## The monsters alive in the room. Asked for dozens of times a frame, so the
## list is built once per frame (physics or drawing) and again only when a
## monster is spawned, dies, dives or surfaces, or is removed (foes_changed).
## Don't change the returned array: it's shared until the next rebuild.
func enemies() -> Array:
	var key := Vector2i(Engine.get_process_frames(), Engine.get_physics_frames())
	if foes_dirty or key != foes_key:
		foes_dirty = false
		foes_key = key
		foes_cache = get_tree().get_nodes_in_group("enemies").filter(
			func(e): return is_instance_valid(e) and not e.dead and not e.is_queued_for_deletion())
		targets_cache = foes_cache.filter(func(e): return not e.submerged)
	return foes_cache


## A monster was added, died, dived or surfaced, or left: rebuild the lists.
func foes_changed() -> void:
	foes_dirty = true


## Covenant's called creatures.
func allies() -> Array:
	return get_tree().get_nodes_in_group("allies").filter(
		func(e): return is_instance_valid(e) and not e.dead)


func spawn_ally(kind: String, pos: Vector2, step: int, seconds: float):
	var e = EnemyScript.new()
	e.setup_ally(kind, self, step, seconds)
	e.position = walkable_point(player.global_position, pos, 14.0)
	add_child(e)
	fx_ring(e.position, Color(0.6, 1.0, 0.75), 30.0, 0.35, 3.0)
	return e


## Adds a monster to the room (bosses calling help, tests).
## Monsters that can be aimed at (not a lurker under the water).
func targets() -> Array:
	enemies()  # (rebuilds both lists if needed)
	return targets_cache


func spawn_enemy(kind: String, pos: Vector2):
	var e = EnemyScript.new()
	e.setup(kind, self)
	var tough := Floors.toughness(floor_num)
	e.max_hp *= tough.x
	e.hp = e.max_hp
	e.dmg *= tough.y
	e.position = clear_spot(pos, e.radius, enemies().map(func(o): return o.global_position))
	e.state_t = 0.4
	add_child(e)
	return e


# --- Tidecaller's waves and standing water ----------------------------------------

func add_wave(origin: Vector2, dir: Vector2, width: float, travel: float, dmg: float, push: float, carry: bool, color: Color) -> void:
	waves.append({"pos": origin + dir * 16.0, "dir": dir, "width": width, "left": travel, "dmg": dmg, "push": push, "carry": carry, "hit": [], "color": color})


## Waves roll forward. An aimed surge shoves each foe it meets once; Carry
## sweeps foes along with it until they break against a wall or pillar.
func _update_waves(delta: float) -> void:
	for w in waves:
		var step := 520.0 * delta
		w["left"] -= step
		var dir: Vector2 = w["dir"]
		var side := dir.orthogonal()
		w["pos"] += dir * step
		for e in enemies():
			var rel: Vector2 = e.global_position - w["pos"]
			if absf(rel.dot(side)) > w["width"] * 0.5 + e.radius:
				continue
			var along := rel.dot(dir)
			if along < -e.radius - step or along > e.radius + 10.0:
				continue
			if w["carry"]:
				if not (e in w["hit"]):
					w["hit"].append(e)
				var col = e.move_and_collide(dir * step)
				if col != null:
					_break_against_wall(e, w)
			elif not (e in w["hit"]):
				w["hit"].append(e)
				e.tide_push(dir * w["push"])
				e.take_hit(w["dmg"], dir, w["push"])
		if not room.grow(-10.0).has_point(w["pos"]) or w["left"] <= 0.0:
			if w["carry"]:
				for e in w["hit"]:
					if is_instance_valid(e) and not e.dead and e.global_position.distance_to(w["pos"]) < w["width"]:
						_break_against_wall(e, w)
			w["left"] = -1.0
	waves = waves.filter(func(w): return w["left"] > 0.0)


func _break_against_wall(e, w: Dictionary) -> void:
	if e in w.get("broken", []):
		return
	if not w.has("broken"):
		w["broken"] = []
	w["broken"].append(e)
	fx_burst(e.global_position, -w["dir"], w["color"], 10, 220.0)
	sfx("hit_heavy", 0.8, -2.0)
	e.take_hit(w["dmg"], Vector2.ZERO, 0.0, true)
	if player.has_bond("tidecaller"):
		e.stagger(1.2)  # Undercurrent: driven into a wall, stunned


## Rune Artist's fields: traps that go off under foes, circles foes can't enter.
func _update_runes(delta: float) -> void:
	for w in wards:
		w["t"] -= delta
	wards = wards.filter(func(w): return w["t"] > 0.0)
	for s in sigils:
		s["t"] -= delta
	sigils = sigils.filter(func(s): return s["t"] > 0.0)
	for w in wards:
		for e in enemies():
			var to: Vector2 = e.global_position - w["pos"]
			var edge: float = w["r"] + e.radius
			if to.length() < edge:
				var out := to.normalized() if to.length() > 0.1 else Vector2.RIGHT
				var dest: Vector2 = w["pos"] + out * edge
				if not is_solid(dest):  # never through a wall
					e.global_position = dest
				e.knock = out * 140.0
	for r in runes:
		r["t"] -= delta
	runes = runes.filter(func(r): return r["t"] > 0.0)
	var fired := false
	for r in runes:
		for e in targets():
			if e.global_position.distance_to(r["pos"]) < r["r"] + e.radius:
				fired = true
				r["fire"] = true
				if r["linked"]:
					for other in runes:
						other["fire"] = true
				break
	if fired:
		for r in runes.filter(func(x): return x.get("fire", false)):
			_detonate_rune(r)
		runes = runes.filter(func(x): return not x.get("fire", false))


func _detonate_rune(r: Dictionary) -> void:
	for e in targets():
		var to: Vector2 = e.global_position - r["pos"]
		if to.length() < r["blast"] + e.radius:
			e.take_hit(r["damage"], to.normalized(), 180.0, true)
			if not e.dead:
				e.stagger(0.6)
	fx_ring(r["pos"], r["color"], r["blast"], 0.35, 5.0)
	fx_burst(r["pos"], Vector2.ZERO, r["color"], 14, 260.0)
	light_flash(r["pos"], r["color"], 1.3, 1.4, 0.3)
	sfx("zap", 0.8)
	shake(4.0)


## Sandshaper's walls: a row of stones that blocks foes (not you) and their shots.
func add_stone_wall(points: Array, r: float, t: float, fault := false) -> void:
	for pt in points:
		var pos: Vector2 = pt
		if not room.has_point(pos):
			continue
		var body := StaticBody2D.new()
		body.collision_layer = 8  # only monsters collide with these
		body.collision_mask = 0
		body.position = pos
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = r
		shape.shape = circle
		body.add_child(shape)
		add_child(body)
		stone_walls.append({"pos": pos, "r": r, "t": t, "body": body, "fault": fault})


func blocks_shot(pos: Vector2) -> bool:
	for w in stone_walls:
		if pos.distance_to(w["pos"]) < w["r"] + 3.0:
			return true
	return false


func _update_ground(delta: float) -> void:
	for w in stone_walls:
		w["t"] -= delta
		if w["t"] <= 0.0 and is_instance_valid(w["body"]):
			w["body"].queue_free()
	stone_walls = stone_walls.filter(func(w): return w["t"] > 0.0)
	for list in [rubble, pits, smokes, decoys]:
		for x in list:
			x["t"] -= delta
	rubble = rubble.filter(func(x): return x["t"] > 0.0)
	pits = pits.filter(func(x): return x["t"] > 0.0)
	smokes = smokes.filter(func(x): return x["t"] > 0.0)
	decoys = decoys.filter(func(x): return x["t"] > 0.0)
	ashfall_t -= delta
	# Toxic Clouds poison foes inside them, a stack every half second.
	for c in clouds:
		c["t"] -= delta
		c["tick"] -= delta
		if c["tick"] <= 0.0:
			c["tick"] = 0.5
			for e in targets():
				if e.global_position.distance_to(c["pos"]) < c["r"] + e.radius:
					e.add_venom(1)
	clouds = clouds.filter(func(c): return c["t"] > 0.0)
	# Smoke and decoys: foes lose track of you.
	for e in enemies():
		if e.is_boss():
			continue
		for sm in smokes:
			if e.global_position.distance_to(sm["pos"]) < sm["r"] + e.radius:
				e.lose_track(0.6, null)
		for d in decoys:
			if e.global_position.distance_to(d["pos"]) < 320.0:
				e.lose_track(0.4, d)
				if e.global_position.distance_to(d["pos"]) < e.radius + 14.0 and d["t"] > 0.8:
					d["t"] = 0.8  # struck: the ash copy crumbles
					fx_burst(d["pos"], Vector2.ZERO, Color(0.6, 0.55, 0.55), 12, 180.0)


## How much rubble slows a foe here (1 is not at all).
func rubble_slow(pos: Vector2) -> float:
	for r in rubble:
		if pos.distance_to(r["pos"]) < r["r"]:
			return 0.5
	return 1.0


## Which body part a monster's graft binds to.
const GRAFT_PART := {
	"slime": "heart", "archer": "brow", "knight": "hand", "bat": "legs", "thunderling": "throat",
	"lurker": "back", "shellback": "heart", "cinder": "throat", "smith": "hand", "scorpling": "back",
	"ram": "legs", "wisp": "legs", "bloomcap": "throat", "thornhound": "legs", "mongrel": "hand",
}


static func graft_part(kind: String) -> String:
	return GRAFT_PART.get(kind, "hand")


## Binds a graft to its body part, if that part is still free.
func add_graft(kind: String) -> bool:
	var part := graft_part(kind)
	if grafts.has(part):
		return false
	grafts[part] = kind
	graft_order.append(part)
	fx_text(player.global_position + Vector2(0, -44), "Grafted: %s to your %s" % [kind, part], Color(0.75, 0.55, 0.7))
	sfx("hit_slime", 0.8)
	return true


func _update_grafts(delta: float) -> void:
	for g in graft_drops:
		g["t"] -= delta
		if player != null and player.global_position.distance_to(g["pos"]) < 24.0 and add_graft(g["kind"]):
			g["t"] = 0.0
	graft_drops = graft_drops.filter(func(g): return g["t"] > 0.0)


func in_sigil(pos: Vector2) -> bool:
	for s in sigils:
		if pos.distance_to(s["pos"]) < s["r"]:
			return true
	return false


## Burning floor: hurts the climber standing in it, a little at a time.
## `friendly` fire (the climber's own) burns monsters instead.
func add_flame(pos: Vector2, r: float, t: float, friendly := false) -> void:
	flames.append({"pos": pos, "r": r, "t": t, "max": t, "friendly": friendly, "tick": 0.0})


func _update_flames(delta: float) -> void:
	for f in flames:
		f["t"] -= delta
		if f.get("friendly", false):
			f["tick"] -= delta
			if f["tick"] <= 0.0:
				f["tick"] = 0.5
				for e in targets():
					if e.global_position.distance_to(f["pos"]) < f["r"] + e.radius:
						e.take_hit(3.0, Vector2.ZERO, 0.0)
						_kindled(e)
	flames = flames.filter(func(f): return f["t"] > 0.0)
	# Meteors land.
	for m in meteors:
		m["t"] -= delta
		if m["t"] <= 0.0:
			explode(m["pos"], m["r"], m["dmg"], m["color"])
			shake(10.0)
	meteors = meteors.filter(func(m): return m["t"] > 0.0)
	if player == null or player.dead:
		return
	for f in flames:
		if f.get("friendly", false):
			continue
		if player.global_position.distance_to(f["pos"]) < f["r"] + player.radius * 0.5:
			player.stand_in_fire(delta)
			break


## Gaps in the floor. Walking monsters can't enter them (they collide with
## them on layer 16); fliers cross; the climber falls in unless jumping.
func set_chasms(list: Array) -> void:
	for b in chasm_bodies:
		_drop_body(b)
	chasm_bodies.clear()
	chasms = list
	for r in chasms:
		var rect: Rect2 = r
		var body := StaticBody2D.new()
		body.collision_layer = 16
		body.collision_mask = 0
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		chasm_bodies.append(body)
	room_view.set_chasms(chasms)


func in_chasm(pos: Vector2) -> bool:
	for r in chasms:
		if r.has_point(pos):
			return true
	return false


## The climber's fire explodes: hurts every foe in the circle.
func explode(pos: Vector2, r: float, dmg: float, color: Color) -> void:
	for e in targets():
		var to: Vector2 = e.global_position - pos
		if to.length() < r + e.radius:
			e.take_hit(dmg, to.normalized() if to.length() > 0.1 else Vector2.ZERO, 200.0, true)
			_kindled(e)
	fx_ring(pos, color, r, 0.35, 6.0)
	fx_burst(pos, Vector2.ZERO, color, 18, 300.0)
	light_flash(pos, color, 1.0 + r / 60.0, 2.0, 0.35)
	sfx("hit_heavy", 0.7)
	shake(4.0)


## Flame Contractor's Kindled: a foe your fire kills leaves burning ground.
func _kindled(e) -> void:
	if e.dead and player != null and player.has_bond("flame_contractor"):
		add_flame(e.global_position, 26.0, 3.0, true)


func in_water(pos: Vector2) -> bool:
	for pd in puddles:
		if pos.distance_to(pd["pos"]) < pd["r"]:
			return true
	return false


## Water slows you (unless you're Waterborn).
func water_slow(pos: Vector2, waterborn := false) -> float:
	return 1.0 if waterborn or not in_water(pos) else 0.6


func spawn_projectile(pos: Vector2, vel: Vector2, dmg: float) -> Node2D:
	var p = ProjectileScript.new()
	p.main = self
	p.position = pos
	p.vel = vel
	p.dmg = dmg
	add_child(p)
	return p


func spawn_player_arrow(pos: Vector2, vel: Vector2, dmg: float, force: float, pierce: bool) -> Node2D:
	var p = spawn_projectile(pos, vel, dmg)
	p.friendly = true
	p.force = force
	p.pierce = pierce
	p.life = 1.6
	return p


func on_enemy_killed(e) -> void:
	profile.note("slain")
	MakersScript.feed(self, "beast" if e.is_boss() and not e.shade else ("champion" if e.champion else "kill"))
	if e.is_boss() and not e.shade:  # (the Proving's shadow of a beast isn't the beast)
		profile.note_beast(tower)
		GuideScript.say("beast_slain", {"beast": beast_name()})
	# Overcharge: a charged foe's death throws lightning to everything near it.
	if e.overcharge_t > 0.0:
		var pts: Array = []
		for o in enemies():
			if o != e and o.global_position.distance_to(e.global_position) < e.overcharge_r:
				fx_bolt([e.global_position, o.global_position], Color(0.95, 0.89, 0.42))
				pts.append(o)
		for o in pts:
			o.take_hit(e.overcharge_dmg, Vector2.ZERO)
		light_flash(e.global_position, Color(0.95, 0.89, 0.42), 1.6, 1.8, 0.35)
		sfx("zap", 0.9)
	# Grafter's Grafting: slain monsters sometimes leave a graft.
	if player != null and player.has_bond("grafter") and not e.is_boss() and randf() < 0.3:
		graft_drops.append({"pos": e.global_position, "kind": e.kind, "t": 20.0})
	# Rarely a slain monster leaves a piece of gear, likelier one that suits it.
	if not e.is_boss() and randf() < gear_drop_chance:
		drop_gear(e.global_position + Vector2(0, 10), find_gear(e.kind), true)
	# Now and then a slain monster leaves an item.
	if not e.is_boss() and randf() < item_drop_chance:
		item_drops.append({"pos": e.global_position, "id": Items.random_item(player != null and not player.bonds.is_empty(), [], true), "t": Items.DROP_LIFE})
	if wings != null:
		wings.on_enemy_killed(e)
	if proving != null:
		proving.on_enemy_killed(e)
	if door_view != null:
		door_view.on_enemy_killed(e)
	var drop: Array = Essence.drop_for(e.kind, floor_num)
	gather_essence(drop[0], drop[1], e.global_position)
	# Every kill also yields a little of the tower's own essence.
	gather_essence(tower_data()["essence"], Towers.ESSENCE_BONUS, e.global_position)
	if player != null:
		player.on_flow_kill(e)  # Life mends; Unmaking's slain foe comes apart
	secret_drop(e)  # a great foe: its secret essence rises
	fx_text(e.global_position + Vector2(0, -30), "slain", Color(0.89, 0.71, 0.35))
	fx_ring(e.global_position, e.color, 46.0, 0.4, 4.0)
	fx_burst(e.global_position, Vector2.ZERO, e.color, 16, 300.0)
	if fx != null:
		fx.debris(e.global_position, e.color, int(e.radius * 0.8))
	var kill_sound: String = "kill_" + e.kind
	sfx(kill_sound if audio != null and audio.has_sound(kill_sound) else "kill")
	hitstop(0.09)
	shake(6.0)


## Hit-pause: freeze the action for a moment so impacts land.
## Overlapping calls keep the longest freeze.
func hitstop(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	if until > hitstop_until:
		hitstop_until = until
	Engine.time_scale = 0.02


## Time stops while a ring is open (a mark's spells, the belt's items, a
## secret bond's tools, the Unbound's techniques), and runs again when it closes.
func set_slowmo(on: bool) -> void:
	slowmo = on
	if hitstop_until == 0:
		Engine.time_scale = RING_TIME if on else 1.0


func sfx(sound: String, pitch := 1.0, volume_db := 0.0, variance := 0.06) -> void:
	if audio != null:
		audio.play(sound, pitch, volume_db, variance)


## Fades out a sound that's still playing.
func sfx_fade(sound: String) -> void:
	if audio != null:
		audio.fade(sound)


func fx_ring(pos: Vector2, color: Color, reach: float, dur := 0.3, width := 3.0) -> void:
	if fx != null:
		fx.ring(pos, color, reach, dur, width)


func fx_burst(pos: Vector2, dir: Vector2, color: Color, count: int, speed := 260.0) -> void:
	if fx != null:
		fx.burst(pos, dir, color, count, speed)


func fx_ghost(pos: Vector2, radius: float, color: Color) -> void:
	if fx != null:
		fx.ghost(pos, radius, color)


func fx_text(pos: Vector2, s: String, color: Color) -> void:
	if fx != null:
		fx.text(pos, s, color)


func fx_bolt(points: Array, color: Color) -> void:
	if fx != null:
		fx.bolt(points, color)


func fx_cone(origin: Vector2, dir: Vector2, reach: float, half: float, color: Color) -> void:
	if fx != null:
		fx.cone(origin, dir, reach, half, color)


func shake(amount: float) -> void:
	if not MenuScript.settings["shake"]:
		return
	shake_amount = maxf(shake_amount, amount)


## A brief burst of light: lightning, parries, crits, burns. It feeds the
## darkness layer (lighting.gd), so it costs nothing however many there are.
func light_flash(pos: Vector2, color: Color, size := 1.5, energy := 1.6, dur := 0.25) -> void:
	if lighting != null:
		lighting.flash(pos, color, size, energy, dur)
