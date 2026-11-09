extends Node2D
## The tower's darkness, as ONE layer over the world (like the web version's
## drawLight): a single rect the size of the screen, drawn with a shader
## that darkens everything in the tower's fog colour and cuts soft holes of
## light around every light on screen. The line-of-sight fog (fog.gd) is
## read from its tiny texture in the same pass, and a vignette is added.
##
## One draw call, whatever the number of lights, and no 2D light nodes at
## all (each of those made every lit thing draw again on a phone).
##
## Lights come from a simple registry: the climber's own glow, the room's
## torches, the stair, the cache, the campfire, puzzle eyes, burning floor,
## and short flashes (main.light_flash). Other code can add its own with
## add_light() / add_spot() / remove_light().
##
## Each light also adds a little coloured glow (additive) where it matters,
## so the eye goes to the open stair, lit eyes, the cache and the ward.
##
## A light with a negative strength DRINKS light instead (Unmaking's shadow,
## secret.gd): darkness gathers in a ring around it, leaving its middle (the
## climber) alone.
##
## Shadows (Settings -> Lighting, Medium and High): light stops at walls,
## closed doors, low cover and pillars, and fades softly around corners.
## Each light's view of the walls is worked out ONCE on the CPU, on a grid of
## half tiles around it, and kept in one small atlas texture (a 48x48 square
## per light, one byte a cell). The darkness shader reads a light's square
## with smooth filtering, which softens the edge for free. Lights that stay
## put (torches, the stair, flashes) are never worked out again; a moving
## light gets a new square only every so often; a door opening redoes only
## the squares around it. The climber's own light casts shadows only on
## High (the fog already hides what's behind walls; this adds pillars).
##
## The visibility is spread outward ring by ring, each cell taking light from
## the one or two cells nearer the light (weighted by angle), so shadows
## start crisp at a wall's edge and widen into a soft penumbra with distance.
##
## Spotlights: a light can shine in a cone (add_spot): light under a door
## fans into the corridor, a vault seal's glow spills out in front of it.
##
## Glow (Medium and High): bright things (torch flames, the open stair, the
## cache, spells, essence motes) get a soft additive halo drawn just above
## the darkness: one more draw call for all of them.

const Palette := preload("res://scripts/palette.gd")
const Essence := preload("res://scripts/essence.gd")
const Secret := preload("res://scripts/secret.gd")

## Most lights sent to the shader in a frame (it loops over them per pixel).
const MAX_LIGHTS := 48
## Flashes alive at once (hits, parries, spells).
const MAX_FLASHES := 16
## Flashes are toned down (owner's request): this much as strong and as wide as asked.
const FLASH_ENERGY := 0.5
const FLASH_SIZE := 0.75
## A light_flash of size 1.0 lights this far (world pixels).
const FLASH_REACH := 128.0
## The climber's own light, and with Keen Eyes or Smokeborn.
const PLAYER_REACH := 330.0
const PLAYER_REACH_KEEN := 480.0
const TORCH_REACH := 230.0

## Settings -> Lighting. shadows: walls stop light; glow: halos on bright
## things; cast_ms: CPU time a frame may spend working out new shadows (at
## least one light a frame is always done); rekey: seconds a moving light
## keeps its shadow before it's worked out again where it is now; soften:
## blur each shadow a little (wider, softer edges); climber: the climber's
## own light casts shadows too (pillars sweep their shadows round as you
## walk; walls are already hidden by the fog), worked out every
## `climber_rekey` seconds while you move.
const QUALITY := {
	"low": {"shadows": false, "glow": false, "cast_ms": 0.0, "rekey": 0.0, "soften": false, "climber": false, "climber_rekey": 0.0},
	"medium": {"shadows": true, "glow": true, "cast_ms": 1.5, "rekey": 0.25, "soften": false, "climber": false, "climber_rekey": 0.0},
	"high": {"shadows": true, "glow": true, "cast_ms": 4.0, "rekey": 0.08, "soften": true, "climber": true, "climber_rekey": 0.05},
}
const QUALITY_ORDER := ["low", "medium", "high"]

## Shadows: world pixels per cell of a light's shadow square (half a tile),
## the square's side in cells, and how the squares sit in the atlas.
const SHADOW_CELL := 20.0
const SLOT := 48
const SLOT_COLS := 8
const SLOT_ROWS := 6
## Lights reaching farther than this use cells twice as big (a campfire).
const SHADOW_FINE_REACH := 400.0
## A light inside rock (a torch's bracket, a door's slit) looks this many
## cells around for open floor to shine from.
const SHADOW_NUDGE := 2
## How much light a cell must pass on for it to count (0..1).
const SHADOW_FLOOR := 0.004

## Spotlights: the share of a cone's half-angle that fades out at its edge.
const SPOT_SOFT := 0.6
## A spotlight's source itself glows a little all round (share of its reach).
const SPOT_CORE := 0.12

## Glow: [radius in px, strength] for each bright thing, drawn additively.
## "flash" and "light" give the radius as a share of the light's reach, and
## a registered light's strength is its glow times this. Lights with less
## glow than BLOOM_MIN_GLOW get no halo.
const BLOOM := {
	"torch": [34.0, 0.45],
	"stair": [56.0, 0.42],
	"ward": [46.0, 0.32],
	"cache": [40.0, 0.5],
	"lost": [26.0, 0.25],
	"campfire": [70.0, 0.45],
	"flash": [0.45, 0.9],
	"mote": [16.0, 0.55],
	"light": [0.32, 1.4],
	"fire": [34.0, 0.3],
}
const BLOOM_MIN_GLOW := 0.12
## A torch's halo is its flame's colour, tinted this much by the tower's torchlight.
const TORCH_FLAME := Color(1.0, 0.62, 0.28)
const TORCH_FLAME_TINT := 0.35
const BLOOM_MAX_R := 64.0
## Most halos drawn in a frame.
const BLOOM_MAX := 64

const OMNI := Color(0.0, 0.0, -2.0, -1.0)  # (a light with no cone)
const NO_SHADOW := Color(0.0, 0.0, -1.0, 1.0)
const WAIT := Color(0.0, 0.0, -2.0, 1.0)  # (its shadow isn't worked out yet)

const SHADER := """
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
{DEFINES}
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform bool fog_on = false;
uniform vec4 fog_rect = vec4(0.0, 0.0, 1.0, 1.0);  // world position and size of the fog grid
uniform vec4 dark_color = vec4(0.03, 0.03, 0.06, 0.8);  // the tower's fog colour; a = how dark unlit places are
uniform vec3 fog_color = vec3(0.015, 0.012, 0.03);  // places out of sight
uniform float vignette = 0.4;
uniform int light_count = 0;
uniform vec4 light_pos[48];  // x, y, reach, glow
uniform vec4 light_col[48];  // r, g, b, strength
uniform vec4 light_spot[48];  // a cone: direction x, y; cosines of its outer and inner edge (z < -1.5: no cone)
#ifdef SHADOWS
uniform sampler2D shadow_tex : filter_linear, repeat_disable;
uniform vec2 shadow_px = vec2(384.0, 288.0);
uniform vec4 light_sh[48];  // its shadow square: world corner x, y; slot (-1: none); world px per cell
#endif

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float keep = 1.0;  // how much of the darkness is left here
	float drink = 0.0;  // darkness a drinking light gathers here
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 48; i++) {
		if (i >= light_count) {
			break;
		}
		vec4 lp = light_pos[i];
		vec2 d = world - lp.xy;
		float q = dot(d, d) / (lp.z * lp.z);
		if (q < 1.0 && light_col[i].a < 0.0) {
			drink = max(drink, -light_col[i].a * smoothstep(0.0, 0.3, q) * (1.0 - smoothstep(0.45, 1.0, q)));
		} else if (q < 1.0) {
			// A wide bright middle with a soft edge (1 at the centre, ~0.9
			// halfway, ~0.45 at four fifths, 0 at the rim).
			float f = 1.0 - smoothstep(0.12, 1.0, q);
			vec4 sp = light_spot[i];
			if (sp.z > -1.5) {
				float c = dot(d, sp.xy) * inversesqrt(max(dot(d, d), 1.0));
				f *= max(smoothstep(sp.z, sp.w, c), 1.0 - smoothstep(0.0, {CORE}, q));
			}
#ifdef SHADOWS
			vec4 sh = light_sh[i];
			if (sh.z >= 0.0) {
				vec2 slot = vec2(mod(sh.z, {COLS}), floor(sh.z / {COLS})) * {SLOT};
				vec2 local = clamp((world - sh.xy) / sh.w, vec2(0.5), vec2({SLOT} - 0.5));
				f *= textureLod(shadow_tex, (slot + local) / shadow_px, 0.0).r;
			}
#endif
			vec4 lc = light_col[i];
			keep *= 1.0 - lc.a * f;
			glow += lc.rgb * (lp.w * f * f);
		}
	}
	float fog = 0.0;
	if (fog_on) {
		vec2 uv = (world - fog_rect.xy) / fog_rect.zw;
		if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
			fog = 1.0;
		} else {
			fog = texture(fog_tex, uv).r;
		}
	}
	float dark = mix(dark_color.a * keep, 0.96, drink);
	vec2 v = (SCREEN_UV - 0.5) * 2.0;
	float vig = vignette * smoothstep(0.55, 1.45, length(v));
	float a = 1.0 - (1.0 - dark) * (1.0 - fog) * (1.0 - vig);
	// Out of sight reads as the fog's own near-black; elsewhere the tower's colour.
	vec3 col = mix(dark_color.rgb, fog_color, clamp(fog / max(a, 0.001), 0.0, 1.0));
	COLOR = vec4(col * a + glow * (1.0 - fog), a);
}
"""

var main
var mat: ShaderMaterial
var lights := {}  # id -> {pos, r, color, k, glow, node, offset, spot?, bloom?}: added by other code
var flashes: Array = []  # {pos, r, color, k, t, dur}
var _next_id := 1
var on_screen := 0  # lights sent to the shader last frame (the dev readout shows it)
var dark_color := Color(0.03, 0.03, 0.06, 0.8)
var quality := "high"  # Settings -> Lighting (set_quality)
var _q: Dictionary = QUALITY["high"]
var _half := Vector2.ZERO  # half the drawn rect
var _pos := PackedColorArray()
var _col := PackedColorArray()
var _spot := PackedColorArray()
var _sh := PackedColorArray()
var _shader_plain: Shader
var _shader_shadow: Shader

# Shadows: what blocks light, on a grid of SHADOW_CELL cells over the floor
# with a border of SLOT/2 cells all round (so a square never reads past it).
var _occ := PackedByteArray()  # 1 = blocks light (fine cells)
var _occ2 := PackedByteArray()  # the same on cells twice as big
var _occ_w := 0  # fine grid size, without the border
var _occ_h := 0
var _occ_origin := Vector2.ZERO  # world position of fine cell (0, 0)
var _outside := 0  # beyond the grid: rock (1) on floors of rooms, open (0) on open floors
var _layout := false
var _room := Rect2()
var _grid := Vector2i.ZERO
var _pillars_ref = null
var _solid_copy := PackedByteArray()
# The atlas: one square per light; which light (key) each holds.
var _atlas_img: Image
var _atlas_tex: ImageTexture
var _atlas_dirty := false
var _slot_key: Array = []  # slot -> Vector4i(cell x, cell y, radius, level) or null
var _slot_used := PackedInt32Array()  # slot -> frame last used
var _slot_dirty := PackedByteArray()  # slot -> 1 when the walls around it changed
var _slot_cast := PackedInt32Array()  # slot -> frame its shadow was last worked out
var _key_slot := {}  # Vector4i -> slot
var _pass := PackedFloat32Array()  # light passed on by each cell of the square being worked out
var _soft := PackedFloat32Array()  # (softening, between its two passes)
var _bytes := PackedByteArray()  # light reaching each cell (the square's texels)
var _lit_walls := PackedInt32Array()
var _slot_img: Image
var _frame := 0
var _now := 0.0
var _cast_until := 0  # usec: no more new shadows this frame after this
var _cast_this_frame := 0
var climber_light := {}  # the climber's light's shadow state (High)
var casts := 0  # shadows worked out so far (tests and the dev readout)
var cast_us := 0  # ...and the time they took, in microseconds

# Glow.
var glow_layer: Node2D
var blooms: Array = []  # this frame's halos: [pos, radius, colour (a = strength)]
var _bloom_tex: Texture2D


func _ready() -> void:
	z_index = 40  # over the floor, the monsters and the climber; world text and the HUD go above
	z_as_relative = false
	process_priority = 100  # after main has moved the camera this frame
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # moved every frame, with the camera
	_shader_plain = Shader.new()
	_shader_plain.code = _shader_code(false)
	_shader_shadow = Shader.new()
	_shader_shadow.code = _shader_code(true)
	mat = ShaderMaterial.new()
	mat.shader = _shader_shadow
	material = mat
	for a in [_pos, _col, _spot, _sh]:
		a.resize(MAX_LIGHTS)
	# The shadow atlas.
	_atlas_img = Image.create(SLOT * SLOT_COLS, SLOT * SLOT_ROWS, false, Image.FORMAT_L8)
	_atlas_tex = ImageTexture.create_from_image(_atlas_img)
	_slot_img = Image.create(SLOT, SLOT, false, Image.FORMAT_L8)
	_slot_key.resize(SLOT_COLS * SLOT_ROWS)
	_slot_used.resize(SLOT_COLS * SLOT_ROWS)
	_slot_used.fill(-1)
	_slot_dirty.resize(SLOT_COLS * SLOT_ROWS)
	_slot_cast.resize(SLOT_COLS * SLOT_ROWS)
	_pass.resize(SLOT * SLOT)
	_soft.resize(SLOT * SLOT)
	_bytes.resize(SLOT * SLOT)
	mat.set_shader_parameter("shadow_tex", _atlas_tex)
	mat.set_shader_parameter("shadow_px", Vector2(SLOT * SLOT_COLS, SLOT * SLOT_ROWS))
	# The glow: one canvas item, drawn additively just above the darkness.
	glow_layer = Node2D.new()
	glow_layer.top_level = true
	glow_layer.z_index = 41
	glow_layer.z_as_relative = false
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = add
	glow_layer.draw.connect(_draw_glow)
	add_child(glow_layer)
	_bloom_tex = _make_bloom_texture()
	set_tower_look("kraken")
	set_quality(quality)


func _shader_code(shadows: bool) -> String:
	return SHADER.replace("{DEFINES}", "#define SHADOWS" if shadows else "").replace("{SLOT}", "%d.0" % SLOT) \
		.replace("{COLS}", "%d.0" % SLOT_COLS).replace("{CORE}", str(SPOT_CORE * SPOT_CORE))


## The tower's darkness colour (palette.gd) and how dark its unlit places are.
func set_tower_look(tower: String) -> void:
	dark_color = Palette.TOWER_FOG.get(tower, Palette.TOWER_FOG["kraken"])
	_apply_look()


func _apply_look() -> void:
	mat.set_shader_parameter("dark_color", dark_color)
	var fc: Color = Palette.FOG_UNSEEN
	mat.set_shader_parameter("fog_color", Vector3(fc.r, fc.g, fc.b))
	mat.set_shader_parameter("vignette", Palette.VIGNETTE)


## The lighting quality a device starts on: Medium in a browser or on a
## touchscreen (a phone), High on a computer.
static func default_quality() -> String:
	if OS.has_feature("web") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		return "medium"
	return "high"


## Settings -> Lighting: "low" (no shadows, no glow: the plain look),
## "medium" (shadows, worked out a little more slowly, and glow) or "high".
func set_quality(q: String) -> void:
	if not QUALITY.has(q):
		q = default_quality()
	quality = q
	_q = QUALITY[q]
	var sh: Shader = _shader_shadow if _q["shadows"] else _shader_plain
	if mat.shader != sh:
		mat.shader = sh
		mat.set_shader_parameter("shadow_tex", _atlas_tex)
		mat.set_shader_parameter("shadow_px", Vector2(SLOT * SLOT_COLS, SLOT * SLOT_ROWS))
		_apply_look()
	if glow_layer != null:
		glow_layer.visible = _q["glow"]
	blooms.clear()


func shadows_on() -> bool:
	return _q["shadows"]


# --- the registry ------------------------------------------------------------

## Adds a lasting light; returns its id (for move_light and remove_light).
## With `node` set, the light follows that node (plus `offset`) until it's freed.
func add_light(pos: Vector2, reach: float, color: Color, strength := 0.8, glow := 0.0, node: Node2D = null, offset := Vector2.ZERO) -> int:
	var id := _next_id
	_next_id += 1
	lights[id] = {"pos": pos, "r": reach, "color": color, "k": strength, "glow": glow, "node": node, "follows": node != null, "offset": offset}
	return id


## A spotlight: like add_light, but it shines only in a cone `cone_deg`
## wide around `dir`, its edge fading softly (and its source glowing a little
## all round). Returns its id.
func add_spot(pos: Vector2, dir: Vector2, cone_deg: float, reach: float, color: Color, strength := 0.8, glow := 0.0, node: Node2D = null, offset := Vector2.ZERO) -> int:
	var id := add_light(pos, reach, color, strength, glow, node, offset)
	set_spot(id, dir, cone_deg)
	return id


## Turns a light into a spotlight (or turns its cone): see add_spot.
func set_spot(id: int, dir: Vector2, cone_deg: float, soft := SPOT_SOFT) -> void:
	if lights.has(id):
		lights[id]["spot"] = spot_cone(dir, cone_deg, soft)


## A cone for the shader: direction, and the cosines of its outer and inner edge.
static func spot_cone(dir: Vector2, cone_deg: float, soft := SPOT_SOFT) -> Color:
	var half := deg_to_rad(clampf(cone_deg, 1.0, 359.0) * 0.5)
	var d := dir.normalized() if dir.length_squared() > 0.0001 else Vector2.DOWN
	return Color(d.x, d.y, cos(half), cos(half * (1.0 - clampf(soft, 0.01, 1.0))))


## A light's own halo, instead of the one its glow gives: radius and strength.
func set_bloom(id: int, radius: float, strength: float) -> void:
	if lights.has(id):
		lights[id]["bloom"] = [radius, strength]


func move_light(id: int, pos: Vector2) -> void:
	if lights.has(id):
		lights[id]["pos"] = pos


func remove_light(id: int) -> void:
	lights.erase(id)


func clear_lights() -> void:
	lights.clear()
	flashes.clear()


## A brief burst of light: lightning, parries, crits, burns. It fades out over `dur`.
func flash(pos: Vector2, color: Color, size := 1.5, energy := 1.6, dur := 0.25) -> void:
	if flashes.size() >= MAX_FLASHES:
		flashes.pop_front()  # the oldest gives way
	flashes.append({"pos": pos, "r": FLASH_REACH * size * FLASH_SIZE, "color": color,
		"k": clampf(energy * FLASH_ENERGY, 0.0, 1.0), "t": dur, "dur": maxf(dur, 0.01)})


## How far the climber's own light reaches (Keen Eyes and Smokeborn see
## farther; a Cloth Hood a little farther too).
func player_reach() -> float:
	var p = main.player if main != null else null
	if p == null:
		return PLAYER_REACH
	var r := PLAYER_REACH_KEEN if p.has_bond("hunter") or p.has_bond("ashwalker") else PLAYER_REACH
	return r * (1.0 + p.gfx("light"))


# --- each frame ----------------------------------------------------------------

func _process(delta: float) -> void:
	for f in flashes:
		f["t"] -= delta
	if not flashes.is_empty():
		flashes = flashes.filter(func(f): return f["t"] > 0.0)
	if main == null or main.camera == null:
		return
	_frame += 1
	_now = Time.get_ticks_msec() * 0.001
	_cast_until = Time.get_ticks_usec() + int(float(_q["cast_ms"]) * 1000.0)
	_cast_this_frame = 0
	if _q["shadows"]:
		_check_walls()
	# Cover the screen (with room to spare for shake and the camera's glide).
	var cam: Camera2D = main.camera
	var view: Vector2 = get_viewport_rect().size / cam.zoom
	var half := view * 0.5 * 1.15 + Vector2(64, 64)
	if not half.is_equal_approx(_half):
		_half = half
		queue_redraw()
	var center := cam.get_screen_center_position() + cam.offset
	position = center
	blooms.clear()
	_gather(Rect2(center - view * 0.5, view))
	_fog_params()
	if _atlas_dirty:
		_atlas_dirty = false
		_atlas_tex.update(_atlas_img)
	if _q["glow"]:
		_gather_motes(Rect2(center - view * 0.5, view))
		glow_layer.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-_half, _half * 2.0), Color.WHITE)


func _fog_params() -> void:
	var fog = main.fog
	var on: bool = fog != null and fog.visible and fog.tex != null and fog.grid != Vector2i.ZERO
	mat.set_shader_parameter("fog_on", on)
	if on:
		mat.set_shader_parameter("fog_tex", fog.tex)
		var c: float = main.Floors.CELL
		mat.set_shader_parameter("fog_rect", Color(main.room.position.x, main.room.position.y, fog.grid.x * c, fog.grid.y * c))


## Every light that reaches the screen this frame, most important first.
func _gather(view: Rect2) -> void:
	var n := 0
	var t := Time.get_ticks_msec() * 0.001
	# The climber's own light (where the climber is drawn, between physics ticks).
	# Its shadow only on High: the fog already hides what's behind walls.
	if main.player != null:
		var pp: Vector2 = main.cam_prev.lerp(main.cam_curr, Engine.get_physics_interpolation_fraction())
		var k := 0.5 if main.player.dead else 0.94
		var before := n
		n = _put(n, view, pp, player_reach(), Palette.PLAYER_LIGHT, k, 0.03, OMNI, _q["climber"], climber_light)
		if n == before:  # (its shadow isn't ready: never leave the climber in the dark)
			n = _put(n, view, pp, player_reach(), Palette.PLAYER_LIGHT, k, 0.03, OMNI, false)
		n = _flow_lights(n, view, pp, t)
	for f in flashes:
		var e: float = f["t"] / f["dur"]
		var before := n
		n = _put(n, view, f["pos"], f["r"], f["color"], f["k"] * e, 0.35 * f["k"] * e * e)
		if n > before:
			var fb: Array = BLOOM["flash"]
			_bloom(f["pos"], minf(f["r"] * fb[0], BLOOM_MAX_R), f["color"], fb[1] * f["k"] * e)
	# The stair: dim while sealed, bright and glowing once open; the ward glows violet.
	var rv = main.room_view
	if main.stair_open:
		n = _put(n, view, main.stair_pos, 190.0 + 10.0 * sin(t * 3.0), Palette.STAIR_LIGHT, 0.85, 0.22 + 0.06 * sin(t * 3.0))
		_bloom_kind(main.stair_pos, "stair", Palette.STAIR_LIGHT, 0.9 + 0.1 * sin(t * 3.0))
	elif main.ward and main.layout_on:
		n = _put(n, view, main.stair_pos, 140.0, Palette.WARD_LIGHT, 0.6, 0.2 + 0.05 * sin(t * 2.0))
		_bloom_kind(main.stair_pos, "ward", Palette.WARD_LIGHT, 0.85 + 0.15 * sin(t * 2.0))
	else:
		n = _put(n, view, main.stair_pos, 120.0, Palette.STAIR_LIGHT, 0.45, 0.0)
	if not main.cache.is_empty() and not main.cache.get("taken", true):
		var cc: Color = Essence.color(main.cache["kind"])
		n = _put(n, view, main.cache["pos"], 150.0, cc, 0.8, 0.25 + 0.06 * sin(t * 2.4))
		_bloom_kind(main.cache["pos"], "cache", cc, 0.85 + 0.15 * sin(t * 2.4))
	if not main.lost_cache.is_empty() and not main.lost_cache["taken"]:
		var lc: Array = main.Lost.LIGHT
		n = _put(n, view, main.lost_cache["pos"], lc[0], main.Lost.LIGHT_COLOR, lc[1], lc[2] + 0.03 * sin(t * 1.6))
		_bloom_kind(main.lost_cache["pos"], "lost", main.Lost.LIGHT_COLOR, 1.0)
	if main.campfire != null and is_instance_valid(main.campfire) and main.campfire.is_inside_tree():
		var cf: Vector2 = main.campfire.global_position + Vector2(0, -10)
		n = _put(n, view, cf, 420.0 + 12.0 * sin(t * 4.0), Palette.TORCH, 1.0, 0.16 + 0.02 * sin(t * 6.0))
		_bloom_kind(cf, "campfire", Palette.TORCH, 0.9 + 0.1 * sin(t * 6.0))
	# The puzzle's own lights: eyes, the mirrors' beam, lit stones (puzzles/).
	var pz = main.puzzle
	if pz != null:
		for l in pz.light_list():
			n = _put(n, view, l[0], l[1], l[2], l[3], l[4])
			_bloom_glow(l[0], l[1], l[2], l[4])
	# Torches: a slow, soft flicker (a fast one lights the floor like a failing screen).
	if rv != null:
		for torch in rv.torches:
			var ph: float = torch["phase"]
			var flick := 0.88 + 0.08 * sin(t * 7.0 + ph) + 0.04 * sin(t * 12.0 + ph * 2.0)
			var before := n
			n = _put(n, view, torch["pos"] + Vector2(0, torch.get("below", 20.0)), TORCH_REACH * (0.97 + 0.03 * sin(t * 5.0 + ph)), rv.torch_color, 0.85 * flick, 0.09 * flick)
			if n > before:
				_bloom_kind(torch["pos"] + Vector2(0, -6), "torch", TORCH_FLAME.lerp(rv.torch_color, TORCH_FLAME_TINT), flick)
	# Burning floor.
	for fl in main.flames:
		var fk := clampf(fl["t"] / 0.5, 0.0, 1.0)
		n = _put(n, view, fl["pos"], fl["r"] * 2.4, Palette.FIRE_LIGHT, 0.6 * fk, 0.12)
		_bloom_kind(fl["pos"], "fire", Palette.FIRE_LIGHT, fk)
	# Traps warning or firing glow in their colour, so the warning reads in the dark.
	# (traps.gd says where each kind glows: a dart slot's red eye, a lane's
	# middle, a cloud's centre; one light per patch of floor.)
	var tv = main.trap_view
	if tv != null:
		for l in tv.glow_list():
			n = _put(n, view, l[0], l[1], l[2], l[3], l[4])
	# Anything else that registered a light.
	for id in lights.keys():
		var l: Dictionary = lights[id]
		var node = l["node"]
		if l["follows"]:
			if not is_instance_valid(node):
				lights.erase(id)
				continue
			l["pos"] = node.global_position + l["offset"]
		var before := n
		n = _put(n, view, l["pos"], l["r"], l["color"], l["k"], l["glow"], l.get("spot", OMNI), true, l)
		if n > before:
			if l.has("bloom"):
				_bloom(l["pos"], l["bloom"][0], l["color"], l["bloom"][1])
			else:
				_bloom_glow(l["pos"], l["r"], l["color"], l["glow"])
	on_screen = n
	mat.set_shader_parameter("light_count", n)
	mat.set_shader_parameter("light_pos", _pos)
	mat.set_shader_parameter("light_col", _col)
	mat.set_shader_parameter("light_spot", _spot)
	if _q["shadows"]:
		mat.set_shader_parameter("light_sh", _sh)


## The climber's shadow holding the flow (secret.gd, player.gd): Life's
## grass-light flickers green at the feet; Unmaking's, from step 3, drinks
## the light around it.
func _flow_lights(n: int, view: Rect2, pp: Vector2, t: float) -> int:
	var p = main.player
	if p.flow_path == "" or p.flow_step < 1 or p.dead:
		return n
	var feet: Vector2 = pp + Vector2(0, p.radius * 0.75)
	var st := float(p.flow_step)
	if p.flow_path == "life":
		var fl := 0.8 + 0.2 * sin(t * 6.3) * sin(t * 2.3 + 1.0)
		var beat := Secret.heartbeat(t)
		return _put(n, view, feet, 44.0 + 10.0 * st, Secret.color("life"), (0.12 + 0.03 * st) * fl, (0.05 + 0.03 * st) * fl * (0.8 + 0.4 * beat), OMNI, false)
	if p.flow_step >= 3 and n < MAX_LIGHTS:
		_pos[n] = Color(feet.x, feet.y, 92.0 + 28.0 * (st - 3.0), 0.0)
		_col[n] = Color(0, 0, 0, -(0.42 + 0.14 * (st - 3.0)))
		_spot[n] = OMNI
		_sh[n] = NO_SHADOW
		return n + 1
	return n


## Adds one light to this frame's list if it reaches the screen and there's
## room (and, with shadows on, once its shadow is worked out). `state` is a
## registered light's own dictionary (it remembers its shadow while it moves).
func _put(n: int, view: Rect2, pos: Vector2, reach: float, color: Color, strength: float, glow: float, spot := OMNI, shadow := true, state = null) -> int:
	if n >= MAX_LIGHTS or strength <= 0.01 or reach <= 1.0:
		return n
	if pos.x < view.position.x - reach or pos.y < view.position.y - reach or pos.x > view.end.x + reach or pos.y > view.end.y + reach:
		return n
	var sh := NO_SHADOW
	if shadow and _q["shadows"]:
		sh = _shadow_for(pos, reach, state)
		if sh.b < -1.5:
			return n  # (waits a frame or two for its shadow, rather than shine through walls)
	_pos[n] = Color(pos.x, pos.y, reach, glow)
	_col[n] = Color(color.r, color.g, color.b, clampf(strength, 0.0, 1.0))
	_spot[n] = spot
	_sh[n] = sh
	return n + 1


## Every light reaching the screen right now, as [pos, reach] pairs (tests).
func live_lights() -> Array:
	var out: Array = []
	for i in on_screen:
		out.append([Vector2(_pos[i].r, _pos[i].g), _pos[i].b])
	return out


# --- shadows -------------------------------------------------------------------

## The walls: a new floor builds the grid again; a door opening or closing
## (main.solid changing) redoes only the shadows around it.
func _check_walls() -> void:
	var lay: bool = main.layout_on and not main.solid.is_empty()
	if lay != _layout or main.room != _room or main.grid_size != _grid or not is_same(main.pillars, _pillars_ref):
		_build_grid()
		return
	if lay and main.solid != _solid_copy:
		_walls_changed()


func _build_grid() -> void:
	_forget_all()
	_layout = main.layout_on and not main.solid.is_empty()
	_room = main.room
	_grid = main.grid_size
	_pillars_ref = main.pillars
	_occ_origin = _room.position
	var per := int(round(main.Floors.CELL / SHADOW_CELL))  # fine cells per tile
	if _layout:
		_occ_w = _grid.x * per
		_occ_h = _grid.y * per
		_outside = 1
	else:
		_occ_w = int(ceil(_room.size.x / SHADOW_CELL))
		_occ_h = int(ceil(_room.size.y / SHADOW_CELL))
		_outside = 0
	var b := SLOT / 2
	var pw := _occ_w + b * 2
	_occ.resize(pw * (_occ_h + b * 2))
	_occ.fill(_outside)
	for y in _occ_h:
		var row := (y + b) * pw + b
		for x in _occ_w:
			_occ[row + x] = main.solid[(y / per) * _grid.x + x / per] if _layout else 0
	# Pillars stop light too (they don't block sight, but they cast shadows).
	for p in main.pillars:
		var pc: Vector2 = (p["pos"] - _occ_origin) / SHADOW_CELL
		var r: float = float(p["r"]) / SHADOW_CELL
		for y in range(int(floor(pc.y - r)), int(ceil(pc.y + r)) + 1):
			for x in range(int(floor(pc.x - r)), int(ceil(pc.x + r)) + 1):
				if x < 0 or y < 0 or x >= _occ_w or y >= _occ_h:
					continue
				if Vector2(x + 0.5, y + 0.5).distance_to(pc) <= maxf(r * 0.9, 0.71):
					_occ[(y + b) * pw + x + b] = 1
	_build_coarse()
	_solid_copy = main.solid.duplicate()


## The grid again on cells twice as big (a cell blocks if any of its four does).
func _build_coarse(area := Rect2i()) -> void:
	var b := SLOT / 2
	var pw := _occ_w + b * 2
	var cw := (_occ_w + 1) / 2
	var ch := (_occ_h + 1) / 2
	var cpw := cw + b * 2
	if area == Rect2i():
		_occ2.resize(cpw * (ch + b * 2))
		_occ2.fill(_outside)
		area = Rect2i(0, 0, cw, ch)
	for y in range(area.position.y, mini(area.end.y, ch)):
		for x in range(area.position.x, mini(area.end.x, cw)):
			var i := (y * 2 + b) * pw + x * 2 + b
			_occ2[(y + b) * cpw + x + b] = 1 if (_occ[i] | _occ[i + 1] | _occ[i + pw] | _occ[i + pw + 1]) != 0 else 0


func _walls_changed() -> void:
	if main.solid.size() != _solid_copy.size():
		_build_grid()
		return
	var per := int(round(main.Floors.CELL / SHADOW_CELL))
	var b := SLOT / 2
	var pw := _occ_w + b * 2
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-1, -1)
	var count := 0
	for i in main.solid.size():
		if main.solid[i] == _solid_copy[i]:
			continue
		count += 1
		var tx: int = i % _grid.x
		var ty: int = i / _grid.x
		lo = Vector2i(mini(lo.x, tx), mini(lo.y, ty))
		hi = Vector2i(maxi(hi.x, tx), maxi(hi.y, ty))
		for sy in per:
			for sx in per:
				_occ[(ty * per + sy + b) * pw + tx * per + sx + b] = main.solid[i]
	_solid_copy = main.solid.duplicate()
	if count > main.solid.size() / 4:
		_build_grid()  # (a whole new floor)
		return
	var area := Rect2i(lo * per, (hi - lo + Vector2i.ONE) * per)
	_build_coarse(Rect2i(area.position / 2, area.size / 2 + Vector2i(2, 2)))
	# Every square that covers the change is worked out again.
	for s in _slot_key.size():
		var key = _slot_key[s]
		if key == null:
			continue
		var k: Vector4i = key
		var lvl: int = k.w
		var sq := Rect2i(Vector2i(k.x, k.y) * lvl - Vector2i(k.z, k.z) * lvl, Vector2i(k.z * 2 + 1, k.z * 2 + 1) * lvl)
		if sq.grow(1).intersects(area):
			_slot_dirty[s] = 1


func _forget_all() -> void:
	_key_slot.clear()
	for s in _slot_key.size():
		_slot_key[s] = null
		_slot_used[s] = -1
		_slot_dirty[s] = 0


## This frame's shadow square for a light: Color(world corner x, y, slot,
## cell size); NO_SHADOW where shadows can't be had (no grid, deep in rock);
## WAIT when it isn't worked out yet and this frame's time is spent.
func _shadow_for(pos: Vector2, reach: float, state) -> Color:
	if _occ_w == 0:
		return NO_SHADOW
	var lvl := 1 if reach <= SHADOW_FINE_REACH else 2
	var cell := SHADOW_CELL * lvl
	var rad := mini(SLOT / 2 - 2, 2 * int(ceil((reach / cell + 1.0) * 0.5)))
	var c := Vector2i(int(floor((pos.x - _occ_origin.x) / cell)), int(floor((pos.y - _occ_origin.y) / cell)))
	var gw := _occ_w if lvl == 1 else (_occ_w + 1) / 2
	var gh := _occ_h if lvl == 1 else (_occ_h + 1) / 2
	if c.x < 0 or c.y < 0 or c.x >= gw or c.y >= gh:
		return NO_SHADOW
	c = _open_cell(c, lvl, pos)
	if c.x < 0:
		return NO_SHADOW
	var key := Vector4i(c.x, c.y, rad, lvl)
	var last = state.get("sh_key") if state != null else null
	# A moving light keeps its last square for a moment.
	if last != null and last != key and _key_slot.has(last) and _now < float(state.get("sh_t", 0.0)):
		return _use(_key_slot[last], last)
	var slot: int = _key_slot.get(key, -1)
	if slot < 0 or _slot_dirty[slot] == 1:
		if not _may_cast():
			if slot >= 0:
				return _use(slot, key)  # (a door just moved: the old shadow for one more frame)
			if last != null and _key_slot.has(last):
				return _use(_key_slot[last], last)
			return WAIT
		if slot < 0:
			slot = _claim(key)
		_cast(slot, key)
	if state != null and last != key:
		state["sh_key"] = key
		state["sh_t"] = _now + float(_q["climber_rekey"] if is_same(state, climber_light) else _q["rekey"])
	return _use(slot, key)


func _may_cast() -> bool:
	return _cast_this_frame == 0 or Time.get_ticks_usec() < _cast_until


func _use(slot: int, key: Vector4i) -> Color:
	_slot_used[slot] = _frame
	var cell := SHADOW_CELL * key.w
	var corner := _occ_origin + Vector2(key.x - SLOT / 2, key.y - SLOT / 2) * cell
	return Color(corner.x, corner.y, slot, cell)


## A free square, or the one unused longest.
func _claim(key: Vector4i) -> int:
	var best := 0
	var best_t := 1 << 30
	for s in _slot_key.size():
		if _slot_key[s] == null:
			best = s
			break
		if _slot_used[s] < best_t and _slot_used[s] != _frame:
			best_t = _slot_used[s]
			best = s
	if _slot_key[best] != null:
		_key_slot.erase(_slot_key[best])
	_slot_key[best] = key
	_key_slot[key] = best
	return best


func _blocks(lvl: int, x: int, y: int) -> bool:
	var b := SLOT / 2
	if lvl == 1:
		return _occ[(y + b) * (_occ_w + b * 2) + x + b] == 1
	return _occ2[(y + b) * ((_occ_w + 1) / 2 + b * 2) + x + b] == 1


## The cell a light shines from: its own, or the nearest open one close by
## (a torch hangs on the wall; a door's light comes from under it).
func _open_cell(c: Vector2i, lvl: int, pos: Vector2) -> Vector2i:
	if not _blocks(lvl, c.x, c.y):
		return c
	var cell := SHADOW_CELL * lvl
	for r in range(1, SHADOW_NUDGE + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r or _blocks(lvl, c.x + dx, c.y + dy):
					continue
				var mid := _occ_origin + (Vector2(c.x + dx, c.y + dy) + Vector2(0.5, 0.5)) * cell
				var d := mid.distance_squared_to(pos)
				if d < best_d:
					best_d = d
					best = Vector2i(c.x + dx, c.y + dy)
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## Works out one light's square: how much light reaches each cell around it.
## Ring by ring outward along each of the four directions, a cell takes the
## light passed on by the cell straight behind it (toward the light) and the
## one diagonally behind, weighted by its angle; walls take light (their
## faces show) but pass none on. Then a wall's brick face, seen from the
## floor below, is lit to its top.
func _cast(slot: int, key: Vector4i) -> void:
	var t0 := Time.get_ticks_usec()
	_cast_this_frame += 1
	casts += 1
	_slot_dirty[slot] = 0
	_slot_cast[slot] = _frame
	var lvl: int = key.w
	var occ: PackedByteArray = _occ if lvl == 1 else _occ2
	var b := SLOT / 2
	var pw := (_occ_w if lvl == 1 else (_occ_w + 1) / 2) + b * 2
	var rad: int = key.z
	var r2 := (rad + 1) * (rad + 1)
	var ci := b * SLOT + b  # the light's cell in the square
	var gc := (key.y + b) * pw + key.x + b  # ...and in the grid
	_pass.fill(0.0)
	_bytes.fill(0)
	_lit_walls.clear()
	_pass[ci] = 1.0
	_bytes[ci] = 255
	for axis in 4:
		var mx := 1 if axis == 0 else (-1 if axis == 1 else 0)
		var my := 1 if axis == 2 else (-1 if axis == 3 else 0)
		var a := my * SLOT + mx  # one step out, in the square
		var bb := mx * SLOT + my  # one step to the side (absolute; sign by j)
		if bb < 0:
			bb = -bb
		var ga := my * pw + mx
		var gb := pw if mx != 0 else 1
		for i in range(1, rad + 1):
			var jm := mini(i, int(sqrt(float(r2 - i * i))))
			var row := ci + i * a
			var grow := gc + i * ga
			var inv := 1.0 / i
			for j in range(-jm, jm + 1):
				var li := row + j * bb
				var p := li - a
				var v: float
				if j == 0:
					v = _pass[p]
				else:
					var w := absi(j) * inv
					v = _pass[p - bb if j > 0 else p + bb] * w
					if j != i and j != -i:
						v += _pass[p] * (1.0 - w)
				if v < SHADOW_FLOOR:
					continue
				_bytes[li] = int(v * 255.0)
				if occ[grow + j * gb] == 0:
					_pass[li] = v
				elif lvl == 1 and _layout:
					_lit_walls.append(li)
	# Brick faces: a lit wall cell in the lower half of its tile, with rock
	# above the tile, lights the upper half too (the face is most of a tile).
	if lvl == 1 and _layout:
		for li in _lit_walls:
			var ly: int = li / SLOT
			var gy: int = key.y - b + ly
			if gy % 2 == 0 or ly < 1:
				continue
			var g: int = gc + (li % SLOT - b) + (ly - b) * pw
			if occ[g - pw] == 1 and occ[g - pw * 2] == 1 and _bytes[li - SLOT] < _bytes[li]:
				_bytes[li - SLOT] = _bytes[li]
	# Softer edges (High): a light 1-2-1 blur, one cell each way. A wall a
	# tile thick still stops it (the blur reaches one cell, half a tile).
	if _q["soften"]:
		var lo := maxi(1, b - rad - 1)
		var hi := mini(SLOT - 2, b + rad + 1)
		_soft.fill(0.0)
		for y in range(lo, hi + 1):
			var row := y * SLOT
			for x in range(lo, hi + 1):
				var i := row + x
				_soft[i] = (_bytes[i - 1] + 2 * _bytes[i] + _bytes[i + 1]) * 0.25
		for y in range(lo, hi + 1):
			var row := y * SLOT
			for x in range(lo, hi + 1):
				var i := row + x
				_bytes[i] = int((_soft[i - SLOT] + 2.0 * _soft[i] + _soft[i + SLOT]) * 0.25)
	_slot_img.set_data(SLOT, SLOT, false, Image.FORMAT_L8, _bytes)
	_atlas_img.blit_rect(_slot_img, Rect2i(0, 0, SLOT, SLOT), Vector2i((slot % SLOT_COLS) * SLOT, (slot / SLOT_COLS) * SLOT))
	_atlas_dirty = true
	cast_us += Time.get_ticks_usec() - t0


## The atlas slot holding registered light `id`'s shadow (-1: none). Tests.
func slot_of(id: int) -> int:
	if not lights.has(id) or not lights[id].has("sh_key"):
		return -1
	return _key_slot.get(lights[id]["sh_key"], -1)


## The frame a slot's shadow was last worked out. Tests.
func slot_cast_frame(slot: int) -> int:
	return _slot_cast[slot] if slot >= 0 else -1


## How much of a light at `pos` (shadows only) reaches `at`, 0..1, as the
## shader sees it (1 with shadows off). Tests and debugging.
func shadow_at(pos: Vector2, reach: float, at: Vector2) -> float:
	if not _q["shadows"] or _occ_w == 0:
		return 1.0
	var lvl := 1 if reach <= SHADOW_FINE_REACH else 2
	var cell := SHADOW_CELL * lvl
	var rad := mini(SLOT / 2 - 2, 2 * int(ceil((reach / cell + 1.0) * 0.5)))
	var c := _open_cell(Vector2i(int(floor((pos.x - _occ_origin.x) / cell)), int(floor((pos.y - _occ_origin.y) / cell))), lvl, pos)
	var key := Vector4i(c.x, c.y, rad, lvl)
	if not _key_slot.has(key):
		return -1.0  # (not worked out yet)
	return _sample(_use(_key_slot[key], key), at)


## Reads a shadow square like the shader does (smooth between cells).
func _sample(sh: Color, at: Vector2) -> float:
	var slot := int(sh.b)
	var local := ((at - Vector2(sh.r, sh.g)) / sh.a).clamp(Vector2(0.5, 0.5), Vector2(SLOT - 0.5, SLOT - 0.5)) - Vector2(0.5, 0.5)
	var base := Vector2i((slot % SLOT_COLS) * SLOT, (slot / SLOT_COLS) * SLOT)
	var x0 := int(floor(local.x))
	var y0 := int(floor(local.y))
	var fx := local.x - x0
	var fy := local.y - y0
	var x1 := mini(x0 + 1, SLOT - 1)
	var y1 := mini(y0 + 1, SLOT - 1)
	var top := lerpf(_atlas_img.get_pixel(base.x + x0, base.y + y0).r, _atlas_img.get_pixel(base.x + x1, base.y + y0).r, fx)
	var bot := lerpf(_atlas_img.get_pixel(base.x + x0, base.y + y1).r, _atlas_img.get_pixel(base.x + x1, base.y + y1).r, fx)
	return lerpf(top, bot, fy)


## How strongly registered light `id` lights `at` (0..1), cone and shadow
## included, as the shader works it out. Tests.
func light_at(id: int, at: Vector2) -> float:
	if not lights.has(id):
		return 0.0
	var l: Dictionary = lights[id]
	var d: Vector2 = at - l["pos"]
	var q: float = d.length_squared() / (l["r"] * l["r"])
	if q >= 1.0:
		return 0.0
	var f := 1.0 - smoothstep(0.12, 1.0, q)
	var sp: Color = l.get("spot", OMNI)
	if sp.b > -1.5:
		var c := d.dot(Vector2(sp.r, sp.g)) / maxf(d.length(), 1.0)
		f *= maxf(smoothstep(sp.b, sp.a, c), 1.0 - smoothstep(0.0, SPOT_CORE * SPOT_CORE, q))
	if _q["shadows"] and l.has("sh_key") and _key_slot.has(l["sh_key"]):
		f *= _sample(_use(_key_slot[l["sh_key"]], l["sh_key"]), at)
	return f * float(l["k"])


# --- glow ------------------------------------------------------------------------

## A soft round halo texture (drawn in code): a bright core in a wide falloff.
func _make_bloom_texture() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := 0.0
			if d < 1.0:
				var e := 1.0 - d * d
				a = 0.55 * exp(-d * d * 12.0) + 0.45 * e * e * e
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _bloom(pos: Vector2, radius: float, color: Color, strength: float) -> void:
	if not _q["glow"] or strength <= 0.01 or radius < 2.0 or blooms.size() >= BLOOM_MAX:
		return
	var seen := 1.0 - _fog_at(pos)
	if seen <= 0.02:
		return
	blooms.append([pos, radius, Color(color.r, color.g, color.b, clampf(strength * seen, 0.0, 1.0))])


func _bloom_kind(pos: Vector2, kind: String, color: Color, k: float) -> void:
	var bl: Array = BLOOM[kind]
	_bloom(pos, bl[0], color, bl[1] * k)


## A halo for a light that glows enough (its glow sets how bright).
func _bloom_glow(pos: Vector2, reach: float, color: Color, glow: float) -> void:
	if glow < BLOOM_MIN_GLOW:
		return
	var bl: Array = BLOOM["light"]
	_bloom(pos, clampf(reach * bl[0], 8.0, BLOOM_MAX_R), color, glow * bl[1])


## Essence flying into the climber glows as it goes.
func _gather_motes(view: Rect2) -> void:
	var fx = main.fx
	if fx == null:
		return
	var bl: Array = BLOOM["mote"]
	for m in fx.motes_list:
		if blooms.size() >= BLOOM_MAX:
			return
		var p: Vector2 = m["pos"]
		if view.grow(bl[0]).has_point(p):
			_bloom(p, bl[0], m["color"], bl[1] * (clampf(m["out"] * 2.0, 0.0, 1.0) if m.has("out") else 1.0))


## How fogged a point is (0 in sight, 1 never seen), as the darkness draws it.
func _fog_at(pos: Vector2) -> float:
	var fog = main.fog
	if fog == null or not fog.visible or fog.grid == Vector2i.ZERO:
		return 0.0
	var t: Vector2i = main._tile_of(pos)
	if t.x < 0 or t.y < 0 or t.x >= fog.grid.x or t.y >= fog.grid.y:
		return 1.0
	return fog.shade[t.y * fog.grid.x + t.x]


func _draw_glow() -> void:
	for b in blooms:
		var r: float = b[1]
		glow_layer.draw_texture_rect(_bloom_tex, Rect2(b[0] - Vector2(r, r), Vector2(r, r) * 2.0), false, b[2])
