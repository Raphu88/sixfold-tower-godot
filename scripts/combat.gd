extends RefCounted
## The climber's core numbers, and the rules every monster's attack keeps.
## player.gd and enemy.gd read them from here, so they can be tuned in the
## Data editor (Numbers -> "The climber's core numbers") without code.
## They're `static var`s, read each time they're used, so a change shows at once.

## The climber (player.gd).
static var CLIMBER := {
	"health": 140.0,  # max health before Vitality and gear
	"stamina": 100.0,  # max stamina before gear
	"stamina_regen": 34.0,  # stamina back a second, once the short wait after acting is over
	"walk": 165.0,  # walking speed (there's no sprint)
	"strike_damage": 8.0,  # the base every weapon swing's "dmg" multiplies
	"backstab": 1.5,  # times the damage of a strike on a foe's back
	"combo_window": 0.35,  # seconds after a swing recovers to carry on the chain
	"buffer": 0.2,  # a press this early still counts when you recover
	"strike_wait": 0.9,  # seconds stamina waits to come back after a strike or a shot
	"parry_window": 0.32,  # seconds a parry is up after the press
	"perfect_parry": 0.14,  # a blow this soon after the press is a perfect parry
	"parry_cooldown": 0.45,  # seconds before you can parry again (a clean parry resets it)
	"roll_cost": 24.0,  # stamina a roll costs
	"roll_time": 0.22,  # how long a roll lasts
	"roll_speed": 320.0,  # how fast a roll carries you
	"roll_iframes": 0.85,  # the share of a roll you can't be hit
	"roll_cooldown": 0.25,  # seconds after a roll ends before the next
	"roll_wait": 0.7,  # seconds stamina waits to come back after a roll
	"dash_cost": 16.0,  # a Windwalker's wind dash, in place of the roll: stamina
	"dash_time": 0.26,  # ...how long it lasts
	"dash_speed": 500.0,  # ...how fast it carries you
	"jump_cost": 10.0,  # stamina a jump costs
	"jump_time": 0.42,  # how long a jump keeps you in the air
	"jump_wait": 0.5,  # seconds stamina waits to come back after a jump
	"grace": 0.7,  # seconds after a hit before another can hurt you
	"knockback": 240.0,  # how hard a blow shoves you
}

## Every monster's attack (enemy.gd).
static var FOES := {
	"glint_lead": 0.25,  # seconds from a monster's glint to its blow landing
	"opening": 1.6,  # times the damage of a hit on a monster recovering from its attack
	"flinch_time": 0.3,  # seconds a monster flinches from a hit
	"flinch_cooldown": 1.2,  # seconds before light hits can flinch it again
}
