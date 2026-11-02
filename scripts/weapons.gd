extends RefCounted
## Weapon definitions. Each weapon is plain data; player.gd reads it.
## Melee weapons are a combo chain of swings. The bow is held to draw.
##
## Swing fields:
##   dmg      multiplier on the base strike damage (8)
##   range    reach in pixels, arc: half-angle in degrees
##   sta      stamina cost, recover: seconds before you can act again
##   lunge    forward step speed, knock: knockback given to the target
##   heavy    a finisher: bigger hit-pause, heavier sound
##   side     which way the swing sweeps (sword) or which fist punches (fists)

const ORDER := ["fists", "sword", "bow"]

const WEAPONS := {
	"fists": {
		"name": "Fists",
		"kind": "melee",
		"style": "jab",
		"swing_time": 0.1,
		"sound": "punch",
		"hit_sound": "hit_light",
		"combo": [
			{"dmg": 0.55, "range": 30.0, "arc": 40.0, "sta": 6.0, "recover": 0.2, "lunge": 140.0, "knock": 70.0, "heavy": false, "side": 1.0},
			{"dmg": 0.6, "range": 30.0, "arc": 40.0, "sta": 6.0, "recover": 0.22, "lunge": 140.0, "knock": 80.0, "heavy": false, "side": -1.0},
			{"dmg": 0.6, "range": 30.0, "arc": 40.0, "sta": 6.0, "recover": 0.22, "lunge": 140.0, "knock": 80.0, "heavy": false, "side": 1.0},
			{"dmg": 1.3, "range": 36.0, "arc": 55.0, "sta": 14.0, "recover": 0.48, "lunge": 260.0, "knock": 240.0, "heavy": true, "side": -1.0},
		],
	},
	"sword": {
		"name": "Sword",
		"kind": "melee",
		"style": "arc",
		"swing_time": 0.15,
		"sound": "swing",
		"hit_sound": "hit",
		"combo": [
			{"dmg": 1.0, "range": 46.0, "arc": 55.0, "sta": 12.0, "recover": 0.4, "lunge": 190.0, "knock": 150.0, "heavy": false, "side": 1.0},
			{"dmg": 1.1, "range": 46.0, "arc": 55.0, "sta": 12.0, "recover": 0.42, "lunge": 190.0, "knock": 160.0, "heavy": false, "side": -1.0},
			{"dmg": 1.8, "range": 56.0, "arc": 75.0, "sta": 20.0, "recover": 0.66, "lunge": 300.0, "knock": 300.0, "heavy": true, "side": 1.0},
		],
	},
	"bow": {
		"name": "Bow",
		"kind": "bow",
		# Hold to draw; release to loose. A full draw pierces through foes.
		"draw_time": 0.75,
		"min_draw": 0.12,  # a quick tap still fires a weak shot after this
		"dmg_min": 5.0,
		"dmg_max": 20.0,
		"speed_min": 380.0,
		"speed_max": 760.0,
		"knock_min": 50.0,
		"knock_max": 220.0,
		"sta": 10.0,
		"recover": 0.3,
		"move_mult": 0.45,  # you walk slowly while drawing
	},
}
