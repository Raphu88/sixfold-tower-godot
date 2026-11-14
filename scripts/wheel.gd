extends RefCounted
## The wheels: the belt wheel (your belt's items) and a mark's spell wheel.
## Hold to choose, tap to use. Choosing is never using.
##
##   Hold the belt button (G, X / Square on a controller, Item on a phone;
##   or the next-item button: T, the d-pad down, the small arrow) and the
##   belt wheel opens while the game slows (RULES "slow"). Point at an item
##   (the mouse, the right stick, or slide your finger onto it) and let go
##   (or click) to make it your current item. A tap of the belt button uses
##   the current item. Number keys 1 to 9 choose an item while it's open.
##   Hold a mark's cast button and the same wheel shows that mark's spells:
##   letting go puts the pointed spell on the button; a tap casts.
##
## player.gd runs them (_update_item_hold, _update_pick), hud.gd draws them
## (the Arrange block "hud.wheel", layout.gd). The numbers and words are
## here, and in the Data editor ("The wheels").

## The numbers.
##   slow  the game's speed while a wheel is open (1 = full speed, 0 = stopped)
##   hold  seconds a button is held before its wheel opens (a shorter press
##         uses the item or casts the spell)
static var RULES := {
	"slow": 0.25,
	"hold": 0.25,
}

## The words. {item}, {item_next} and {cast} become the key, the controller
## button or the touch button in use (entity.gd KEYS); %s is a name.
static var TEXT := {
	# Under the wheel, below the pointed option's name and what it does.
	"item_current": "Your current item: tap {item} to use it",
	"item_choose": "Let go to choose it. Choosing never uses it",
	"spell_current": "On the button now: tap to cast it",
	"spell_choose": "Let go to put it on the button. It isn't cast",
	# Floating over the climber when something is chosen.
	"item_chosen": "Current item: %s",
	"spell_chosen": "On the button: %s",
	# How you point, for the Entity's answer ("How does the belt wheel work?").
	"point_keys": "the mouse",
	"point_pad": "the right stick",
	"point_touch": "your finger, sliding onto it",
}


## The game's speed while a wheel is open.
static func slow() -> float:
	return clampf(float(RULES.get("slow", 0.25)), 0.0, 1.0)


## Seconds a button is held before its wheel opens.
static func hold() -> float:
	return maxf(0.05, float(RULES.get("hold", 0.25)))


## The hint under the wheel: "current" or "choose", for "item" or "spell".
static func hint(kind: String, current: bool) -> String:
	return String(TEXT.get("%s_%s" % [kind, "current" if current else "choose"], ""))
