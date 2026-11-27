extends RefCounted
## THE HIGH STEPS: what a mark brings at steps 6 to 12 (the tree's last
## seven nodes, tree.gd mark_nodes), every name, line and number in data so
## the owner can change them (the Bonded Marks doc, "Steps 6–12", says the
## same in plain words). The same rhythm as the Unbound's levels 6 to 12:
##
##   6   RANK IV: the mark's passive grows stronger ("rank4": its line, and
##       "boost": {rank: {number: new value}}, the numbers of ranks II and
##       III it raises; bonds.gd passive_num reads them once the mark is at
##       step 6).
##   7, 9, 11  FORKS: one of two upgrades to the mark's spells, for good.
##   8   APEX+: the great spell grows stronger (one upgrade, no choice).
##   10  TRANSFORMATION II: a second change to the mark's first spell, one
##       of two, for good.
##   12  THE ZENITH: the mark's ultimate power (the Unbound's capstone's
##       counterpart): every spell of the mark also does something more.
##
## An upgrade is {"id", "name", "says", "mods", "fx"}:
##   "mods"  {spell id: {number: [op, value]}}: "+" adds, "*" multiplies,
##           "=" sets; spell id "*" is every spell of the mark. A fork's
##           upgrade lists both sides of the earlier fork it improves, so it
##           works whichever the climber took (bond.gd spell_stat applies them).
##   "fx"    [{"kind", "of", numbers...}]: something more a cast does (run by
##           scripts/spells/ascent.gd on_cast). "of": "any" (every spell of
##           the mark), "first", "second", "fourth", "great" (the spell
##           learned at step 1, 2, 4 or 5, whichever side), or a spell id.
##           Kinds: echo (the spell repeats: delay, power), nova (a burst
##           around you), strike (hits the nearest foes), aim_burst (a burst
##           where you aim, after a warning ring), orbit (blades circling
##           you), wave (a wave of fire along your aim), field (a circle on
##           the floor), surge (the mark's spells hit harder a while), shield,
##           heal, kin (calls a spirit creature). "every": at most once in
##           that many seconds. Damage is times the spell's power (a faint
##           mark, Intellect, gear) like the spell's own.
## Twelve steps in all (by sixes); each high step brings one thing, and
## each choice is between two.

const ZENITH_STEP := 12
const RANK4_STEP := 6
## The steps that are a choice of two (Transformation II is step 10).
const FORKS := [7, 9, 10, 11]
const APEX_STEP := 8
const TRANSFORM_STEP := 10

## Words the tree and the step notes use.
static var TEXT := {
	"rank4": "%s IV",
	"rank4_says": "%s grows to rank IV: %s",
	"fork": "a choice of two upgrades waits on your tree: %s or %s",
	"transform": "a second Transformation to choose on your tree: %s or %s",
	"apex": "%s: %s",
	"zenith": "the Zenith, %s: %s",
}

## Seconds a mark's surge (fx "surge") is shown over the climber, and the
## words over a foe or the climber.
static var WORDS := {"surge": "Surge", "kin": "Kin", "zenith": "Zenith"}

static var ASCENT := {
	# --- the Gryphon's tower (Air) -------------------------------------------
	"stormcaller": {
		"rank4": {"says": "charged foes take 25% more from everything (was 20%)", "boost": {2: {"more": 0.25}}},
		7: [{"id": "long_arc", "name": "Long Arc", "says": "Chain Lightning leaps to 2 more foes; Ball Lightning's sparks leap to 1 more foe",
				"mods": {"chain_lightning": {"leaps": ["+", 2]}, "ball_lightning": {"leaps": ["+", 1]}}},
			{"id": "high_voltage", "name": "High Voltage", "says": "Chain Lightning or Ball Lightning hits 25% harder and costs 2 less",
				"mods": {"chain_lightning": {"damage": ["*", 1.25], "cost": ["+", -2.0]}, "ball_lightning": {"damage": ["*", 1.25], "cost": ["+", -2.0]}}}],
		8: {"id": "thunderhead_plus", "name": "Thunderhead, Rising", "says": "Thunderhead lasts 12 seconds (was 8) and its bolts hit for 11 (was 8)",
			"mods": {"thunderhead": {"duration": ["=", 12.0], "bolt": ["=", 11.0]}}},
		9: [{"id": "iron_rod", "name": "Iron Rod", "says": "Lightning Rod stands 9 seconds (was 6) and strikes 3 foes each beat; Thunderclap reaches 25% farther",
				"mods": {"lightning_rod": {"duration": ["=", 9.0], "targets": ["+", 1]}, "thunderclap": {"radius": ["*", 1.25]}}},
			{"id": "overcharge", "name": "Overcharge", "says": "Lightning Rod's closing burst hits 60% harder and reaches a fifth farther; Thunderclap stuns half a second longer and hits 4 harder",
				"mods": {"lightning_rod": {"burst": ["*", 1.6], "burst_radius": ["*", 1.2]}, "thunderclap": {"stun": ["+", 0.5], "damage": ["+", 4.0]}}}],
		10: [{"id": "stormcrown", "name": "Stormcrown", "says": "Call Lightning strikes twice: a second bolt follows 0.6 seconds later, 60% as strong, on the foe you aim at then",
				"fx": [{"kind": "echo", "of": "first", "delay": 0.6, "power": 0.6}]},
			{"id": "static_field", "name": "Static Field", "says": "casting Call Lightning also charges every foe within 150 of you for 4 seconds and stings each for 5",
				"fx": [{"kind": "nova", "of": "first", "radius": 150.0, "damage": 5.0, "state": "charged", "seconds": 4.0}]}],
		11: [{"id": "storm_battery", "name": "Storm Battery", "says": "every Stormcaller spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}},
			{"id": "forked_sky", "name": "Forked Sky", "says": "Call Lightning's bolt, and the burst when its foe dies, hit 20% harder",
				"mods": {"call_lightning": {"strike": ["*", 1.2], "damage": ["*", 1.2]}}}],
		12: {"id": "zenith_stormcaller", "name": "Crown of Storms", "says": "every Stormcaller spell also calls a bolt down on up to 2 foes within 300 of you: 8 each, and they're left charged (at most once every 1.5 seconds)",
			"fx": [{"kind": "strike", "of": "any", "count": 2, "range": 300.0, "damage": 8.0, "state": "charged", "seconds": 4.0, "look": "bolt", "every": 1.5}]},
	},
	"windwalker": {
		"rank4": {"says": "your strikes keep airborne foes aloft longer, and your rolls' gust reaches farther and lifts heavier foes", "boost": {2: {"juggle": 0.6, "most": 2.5}, 3: {"radius": 85.0, "weight": 2.2}}},
		7: [{"id": "gale_wall", "name": "Gale Wall", "says": "Crosswind lasts 3 seconds longer and is a third longer; Updraft stands 2 seconds longer",
				"mods": {"crosswind": {"duration": ["+", 3.0], "length": ["*", 1.33]}, "updraft": {"duration": ["+", 2.0]}}},
			{"id": "strong_gust", "name": "Strong Gust", "says": "Updraft is a third wider and throws foes higher; Crosswind costs 3 less",
				"mods": {"updraft": {"radius": ["*", 1.33], "lift": ["+", 0.5]}, "crosswind": {"cost": ["+", -3.0]}}}],
		8: {"id": "eye_plus", "name": "Eye of the Storm, Widened", "says": "the cyclone lasts 7 seconds (was 5) and is a quarter wider",
			"mods": {"eye_of_the_storm": {"duration": ["=", 7.0], "radius": ["*", 1.25]}}},
		9: [{"id": "hammerfall", "name": "Hammerfall", "says": "Downdraft or Hurl hits 30% harder, and so does its splash",
				"mods": {"downdraft": {"damage": ["*", 1.3], "splash": ["*", 1.3]}, "hurl": {"damage": ["*", 1.3], "splash": ["*", 1.3]}}},
			{"id": "wide_slam", "name": "Wide Slam", "says": "Downdraft's landing splash is twice as wide; Hurl flings foes a third farther",
				"mods": {"downdraft": {"radius": ["*", 2.0]}, "hurl": {"reach": ["*", 1.33], "force": ["*", 1.2]}}}],
		10: [{"id": "second_gust", "name": "Second Gust", "says": "Gale Lift blows twice: a second gust 0.5 seconds later, 70% as strong",
				"fx": [{"kind": "echo", "of": "first", "delay": 0.5, "power": 0.7}]},
			{"id": "cyclone_step", "name": "Cyclone Step", "says": "casting Gale Lift also throws every foe within 90 of you into the air for a second and strikes it for 4",
				"fx": [{"kind": "nova", "of": "first", "radius": 90.0, "damage": 4.0, "state": "airborne", "seconds": 1.0}]}],
		11: [{"id": "rising_winds", "name": "Rising Winds", "says": "Gale Lift reaches a quarter farther, in a quarter wider arc",
				"mods": {"gale_lift": {"reach": ["*", 1.25], "arc": ["*", 1.25]}}},
			{"id": "thin_air", "name": "Thin Air", "says": "every Windwalker spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}}],
		12: {"id": "zenith_windwalker", "name": "Sky Throne", "says": "every Windwalker spell also throws every foe within 140 of you into the air for 1.2 seconds and strikes it for 8 (at most once every 1.5 seconds)",
			"fx": [{"kind": "nova", "of": "any", "radius": 140.0, "damage": 8.0, "state": "airborne", "seconds": 1.2, "every": 1.5}]},
	},
	"hunter": {
		"rank4": {"says": "your Quarry takes 35% more from you (was 25%), and felling it marks a foe up to 560 away (was 400)", "boost": {2: {"more": 0.35}, 3: {"reach": 560.0}}},
		7: [{"id": "long_sight", "name": "Long Sight", "says": "Track lasts 16 seconds (was 10); Snare holds a foe 1.5 seconds longer and you can lay 3",
				"mods": {"track": {"duration": ["=", 16.0]}, "snare": {"hold": ["+", 1.5], "count": ["+", 1]}}},
			{"id": "light_kit", "name": "Light Kit", "says": "Track and Snare cost half as much; Snare's bite hits 6 harder",
				"mods": {"track": {"cost": ["*", 0.5]}, "snare": {"cost": ["*", 0.5], "damage": ["+", 6.0]}}}],
		8: {"id": "rain_plus", "name": "Rain of Arrows, Storm", "says": "the rain falls 6 seconds (was 4) and each arrow hits for 4 (was 3)",
			"mods": {"rain_of_arrows": {"duration": ["=", 6.0], "damage": ["=", 4.0]}}},
		9: [{"id": "deadeye", "name": "Deadeye", "says": "Hawk's Eye lasts 8 seconds (was 5); Pinning Shot pins a second longer",
				"mods": {"hawks_eye": {"duration": ["=", 8.0]}, "pinning_shot": {"pin": ["+", 1.0]}}},
			{"id": "heavy_draw", "name": "Heavy Draw", "says": "Pinning Shot hits 35% harder; Hawk's Eye costs 4 less",
				"mods": {"pinning_shot": {"damage": ["*", 1.35]}, "hawks_eye": {"cost": ["+", -4.0]}}}],
		10: [{"id": "twin_shot", "name": "Twin Shot", "says": "Piercing Shot looses a second arrow 0.3 seconds later, 70% as strong",
				"fx": [{"kind": "echo", "of": "first", "delay": 0.3, "power": 0.7}]},
			{"id": "barbed_volley", "name": "Barbed Volley", "says": "Piercing Shot also looses a small arrow at each of the 2 nearest foes: 6 each, and they bleed for 3 seconds",
				"fx": [{"kind": "strike", "of": "first", "count": 2, "range": 360.0, "damage": 6.0, "state": "bleeding", "seconds": 3.0, "look": "arrow"}]}],
		11: [{"id": "fletcher", "name": "Fletcher", "says": "Piercing Shot costs 2 less and hits 15% harder",
				"mods": {"piercing_shot": {"cost": ["+", -2.0], "damage": ["*", 1.15]}}},
			{"id": "patient_hunter", "name": "Patient Hunter", "says": "every Hunter spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}}],
		12: {"id": "zenith_hunter", "name": "Apex Predator", "says": "every Hunter spell also looses an arrow of essence at up to 2 foes within 420 of you, your Quarry first: 12 each (at most once a second)",
			"fx": [{"kind": "strike", "of": "any", "count": 2, "range": 420.0, "damage": 12.0, "prefer": "quarry", "look": "arrow", "every": 1.0}]},
	},
	# --- the Kraken's tower (Water) --------------------------------------------
	"tidecaller": {
		"rank4": {"says": "foes knocked into each other are stunned 1.1 seconds (was 0.7)", "boost": {2: {"stun": 1.1}}},
		7: [{"id": "deep_pull", "name": "Deep Pull", "says": "Riptide reaches a third farther and hits 4 harder; Flood is a quarter wider",
				"mods": {"riptide": {"length": ["*", 1.33], "damage": ["+", 4.0]}, "flood": {"radius": ["*", 1.25]}}},
			{"id": "drowned_floor", "name": "Drowned Floor", "says": "Flood lasts 3 seconds longer and hurts twice as much; Riptide costs 3 less",
				"mods": {"flood": {"duration": ["+", 3.0], "damage": ["*", 2.0]}, "riptide": {"cost": ["+", -3.0]}}}],
		8: {"id": "maelstrom_plus", "name": "Maelstrom, Abyssal", "says": "the whirlpool lasts 7 seconds (was 5) and is a fifth wider",
			"mods": {"maelstrom": {"duration": ["=", 7.0], "radius": ["*", 1.2]}}},
		9: [{"id": "crashing_carry", "name": "Crashing Carry", "says": "Carry or Geysers hits 30% harder (Carry's crashes too)",
				"mods": {"carry": {"damage": ["*", 1.3], "crash": ["*", 1.3], "collide": ["*", 1.3]}, "geysers": {"damage": ["*", 1.3]}}},
			{"id": "great_waters", "name": "Great Waters", "says": "Carry's wave is a third wider; Geysers bursts 5 times (was 3)",
				"mods": {"carry": {"width": ["*", 1.33]}, "geysers": {"count": ["+", 2]}}}],
		10: [{"id": "tsunami", "name": "Tsunami", "says": "Tidal Surge rolls out again 0.6 seconds later, 70% as strong",
				"fx": [{"kind": "echo", "of": "first", "delay": 0.6, "power": 0.7}]},
			{"id": "soaking_spray", "name": "Soaking Spray", "says": "casting Tidal Surge also soaks every foe within 160 of you for 5 seconds and strikes it for 4",
				"fx": [{"kind": "nova", "of": "first", "radius": 160.0, "damage": 4.0, "state": "soaked", "seconds": 5.0}]}],
		11: [{"id": "heavy_water", "name": "Heavy Water", "says": "Tidal Surge hits 20% harder and pushes 20% farther",
				"mods": {"tidal_surge": {"damage": ["*", 1.2], "push": ["*", 1.2]}}},
			{"id": "tidewise", "name": "Tidewise", "says": "every Tidecaller spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}}],
		12: {"id": "zenith_tidecaller", "name": "Leviathan Tide", "says": "every Tidecaller spell also sends a ring of water out from you: foes within 170 take 10, are soaked for 4 seconds and shoved back (at most once every 1.5 seconds)",
			"fx": [{"kind": "nova", "of": "any", "radius": 170.0, "damage": 10.0, "state": "soaked", "seconds": 4.0, "push": 260.0, "every": 1.5}]},
	},
	"warden": {
		"rank4": {"says": "a parry while shielded restores half your barrier (was 35%), and a broken barrier refunds three quarters of its cost (was half)", "boost": {2: {"restore": 0.5}, 3: {"refund": 0.75}}},
		7: [{"id": "long_hold", "name": "Long Hold", "says": "Absorb lasts a second longer; Bulwark stands 2 seconds longer and a third wider",
				"mods": {"absorb": {"duration": ["+", 1.0]}, "bulwark": {"duration": ["+", 2.0], "arc": ["*", 1.33]}}},
			{"id": "cheap_guard", "name": "Cheap Guard", "says": "Absorb and Bulwark cost 3 less",
				"mods": {"absorb": {"cost": ["+", -3.0]}, "bulwark": {"cost": ["+", -3.0]}}}],
		8: {"id": "unbreakable_plus", "name": "Unbreakable, Ironclad", "says": "Unbreakable lasts 6 seconds (was 4) and its closing burst reaches a quarter farther",
			"mods": {"unbreakable": {"duration": ["=", 6.0], "radius": ["*", 1.25]}}},
		9: [{"id": "taunt", "name": "Taunt", "says": "Challenge lasts 6 seconds (was 4) and reaches a quarter farther; Tidebreak's waves hit 30% harder",
				"mods": {"challenge": {"duration": ["=", 6.0], "radius": ["*", 1.25]}, "tidebreak": {"damage": ["*", 1.3]}}},
			{"id": "bulwark_wave", "name": "Bulwark Wave", "says": "Tidebreak lasts 12 seconds (was 8) and raises a barrier 8 thicker; Challenge costs 4 less",
				"mods": {"tidebreak": {"duration": ["=", 12.0], "shield": ["+", 8.0]}, "challenge": {"cost": ["+", -4.0]}}}],
		10: [{"id": "thorned_shell", "name": "Thorned Shell", "says": "raising your Barrier strikes every foe within 110 of you for 10 and shoves it away",
				"fx": [{"kind": "nova", "of": "first", "radius": 110.0, "damage": 10.0, "push": 240.0}]},
			{"id": "deep_shell", "name": "Deep Shell", "says": "Barrier holds 40% more and lasts 3 seconds longer",
				"mods": {"barrier": {"shield": ["*", 1.4], "duration": ["+", 3.0]}}}],
		11: [{"id": "fortress", "name": "Fortress", "says": "every Warden spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}},
			{"id": "guardians_grace", "name": "Guardian's Grace", "says": "every Warden spell heals you 4 (at most once a second)",
				"fx": [{"kind": "heal", "of": "any", "amount": 4.0, "every": 1.0}]}],
		12: {"id": "zenith_warden", "name": "Aegis Eternal", "says": "every Warden spell also raises a shell of 18 around you for 5 seconds, and its edge strikes foes within 90 for 6 and shoves them away (at most once a second)",
			"fx": [{"kind": "shield", "of": "any", "amount": 18.0, "seconds": 5.0, "every": 1.0},
				{"kind": "nova", "of": "any", "radius": 90.0, "damage": 6.0, "push": 260.0, "every": 1.0}]},
	},
	"deepcaller": {
		"rank4": {"says": "hurt foes near you hit 35% softer (was 25%), and a kill near you heals 10 (was 6)", "boost": {2: {"softer": 0.35}, 3: {"heal": 10.0}}},
		7: [{"id": "iron_chain", "name": "Iron Chain", "says": "Anchor holds 9 seconds (was 6); Leech clings 9 seconds (was 6)",
				"mods": {"anchor": {"duration": ["=", 9.0]}, "leech": {"duration": ["=", 9.0]}}},
			{"id": "thirsty_leech", "name": "Thirsty Leech", "says": "Leech drinks 2 more each second; Anchor costs 3 less",
				"mods": {"leech": {"damage": ["+", 2.0]}, "anchor": {"cost": ["+", -3.0]}}}],
		8: {"id": "drink_plus", "name": "Drink Deep, Bottomless", "says": "the drain holds 6 seconds (was 4) and drinks 4 a beat (was 3)",
			"mods": {"drink_deep": {"duration": ["=", 6.0], "damage": ["=", 4.0]}}},
		9: [{"id": "deep_siphon", "name": "Deep Siphon", "says": "Siphon refills 12 essence (was 8); Drown pulls 30% harder",
				"mods": {"siphon": {"refill": ["=", 12.0]}, "drown": {"damage": ["*", 1.3]}}},
			{"id": "long_reach", "name": "Long Reach", "says": "Siphon and Drown reach a third farther, and Siphon catches 5 foes (was 3)",
				"mods": {"siphon": {"reach": ["*", 1.33], "targets": ["+", 2]}, "drown": {"reach": ["*", 1.33]}}}],
		10: [{"id": "second_draw", "name": "Second Draw", "says": "Undertow drains again 0.7 seconds later, 60% as strong",
				"fx": [{"kind": "echo", "of": "first", "delay": 0.7, "power": 0.6}]},
			{"id": "riptide_draw", "name": "Riptide Draw", "says": "casting Undertow also drags every foe within 180 a little toward you and slows it for 2 seconds",
				"fx": [{"kind": "nova", "of": "first", "radius": 180.0, "damage": 0.0, "state": "slowed", "seconds": 2.0, "pull": 200.0}]}],
		11: [{"id": "greedy_drain", "name": "Greedy Drain", "says": "Undertow drains 20% more, and you drink back a tenth more of it",
				"mods": {"undertow": {"damage": ["*", 1.2], "heal": ["+", 0.1]}}},
			{"id": "deep_well", "name": "Deep Well", "says": "every Deepcaller spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}}],
		12: {"id": "zenith_deepcaller", "name": "The Abyss Answers", "says": "every Deepcaller spell also drains up to 3 foes within 260 of you: 8 each, and you drink back 40% of it (at most once a second)",
			"fx": [{"kind": "strike", "of": "any", "count": 3, "range": 260.0, "damage": 8.0, "state": "drained", "drain": 0.4, "look": "drain", "every": 1.0}]},
	},
	# --- the Wyvern's tower (Iron) -----------------------------------------------
	"blade_forger": {
		"rank4": {"says": "every 4th strike that lands throws a free blade (was every 5th)", "boost": {3: {"every": 4}}},
		7: [{"id": "returning_edge", "name": "Returning Edge", "says": "Recall throws 5 blades (was 3); Tethered Blade reaches a third farther",
				"mods": {"recall": {"count": ["+", 2]}, "tethered_blade": {"range": ["*", 1.33]}}},
			{"id": "honed_steel", "name": "Honed Steel", "says": "Recall or Tethered Blade hits 25% harder",
				"mods": {"recall": {"damage": ["*", 1.25]}, "tethered_blade": {"damage": ["*", 1.25]}}}],
		8: {"id": "edges_plus", "name": "Thousand Edges, Unending", "says": "the storm throws 20 blades (was 14), and the edges they leave stay 6 seconds (was 4)",
			"mods": {"thousand_edges": {"count": ["=", 20], "edge_time": ["=", 6.0]}}},
		9: [{"id": "whirling_ward", "name": "Whirling Ward", "says": "Bladeward lasts 9 seconds (was 6) and circles a third wider; Falling Swords drops 5 swords (was 3)",
				"mods": {"bladeward": {"duration": ["=", 9.0], "radius": ["*", 1.33]}, "falling_swords": {"count": ["+", 2]}}},
			{"id": "keen_ward", "name": "Keen Ward", "says": "Bladeward or Falling Swords hits 30% harder",
				"mods": {"bladeward": {"damage": ["*", 1.3]}, "falling_swords": {"damage": ["*", 1.3]}}}],
		10: [{"id": "second_volley", "name": "Second Volley", "says": "Conjured Blades throws again 0.4 seconds later, 70% as strong",
				"fx": [{"kind": "echo", "of": "first", "delay": 0.4, "power": 0.7}]},
			{"id": "blade_fan", "name": "Blade Fan", "says": "Conjured Blades throws 2 more blades in a wider fan",
				"mods": {"conjured_blades": {"count": ["+", 2], "spread": ["*", 1.4]}}}],
		11: [{"id": "forge_light", "name": "Forge-Light", "says": "every Blade Forger spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}},
			{"id": "sharpened_memory", "name": "Sharpened Memory", "says": "Conjured Blades hit 20% harder",
				"mods": {"conjured_blades": {"damage": ["*", 1.2]}}}],
		12: {"id": "zenith_blade_forger", "name": "Armory Unbound", "says": "every Blade Forger spell also sets 3 conjured blades circling you for 4 seconds: they cut each foe they pass for 4, every half second (at most once every 1.5 seconds)",
			"fx": [{"kind": "orbit", "of": "any", "count": 3, "radius": 58.0, "damage": 4.0, "seconds": 4.0, "tick": 0.5, "every": 1.5}]},
	},
	"flameblade": {
		"rank4": {"says": "the fire your full-heat swings throw hits 9 (was 6) and flies farther, and parries add more heat (35, or 60 for a perfect one)", "boost": {2: {"fire_damage": 9.0, "fire_travel": 170.0}, 3: {"parry_heat": 35.0, "perfect_heat": 60.0}}},
		7: [{"id": "long_lash", "name": "Long Lash", "says": "Flame Lash reaches a third farther; Flame Wheel is a quarter wider",
				"mods": {"flame_lash": {"travel": ["*", 1.33]}, "flame_wheel": {"radius": ["*", 1.25]}}},
			{"id": "white_flame", "name": "White Flame", "says": "Flame Lash or Flame Wheel hits 25% harder",
				"mods": {"flame_lash": {"damage": ["*", 1.25]}, "flame_wheel": {"damage": ["*", 1.25]}}}],
		8: {"id": "overheat_plus", "name": "Overheat, Meltdown", "says": "the blow hits 22 (was 16), and the ring of fire at full heat hits 22 and reaches a quarter farther",
			"mods": {"overheat": {"damage": ["=", 22.0], "ring": ["*", 1.25], "ring_damage": ["=", 22.0]}}},
		9: [{"id": "burning_riposte", "name": "Burning Riposte", "says": "Searing Parry's blast or Blazing Lunge hits 30% harder",
				"mods": {"searing_parry": {"damage": ["*", 1.3]}, "blazing_lunge": {"damage": ["*", 1.3]}}},
			{"id": "long_burn", "name": "Long Burn", "says": "Searing Parry burns 9 seconds (was 6); Blazing Lunge carries a third farther and heats your weapon 15 more",
				"mods": {"searing_parry": {"duration": ["=", 9.0]}, "blazing_lunge": {"distance": ["*", 1.33], "heat": ["+", 15.0]}}}],
		10: [{"id": "flare", "name": "Flare", "says": "lighting Kindle Blade bursts in a ring of fire: foes within 100 take 10 and catch fire",
				"fx": [{"kind": "nova", "of": "first", "radius": 100.0, "damage": 10.0, "state": "burning", "seconds": 3.0}]},
			{"id": "long_kindling", "name": "Long Kindling", "says": "Kindle Blade burns 4 seconds longer and its burning strikes hit 2 harder",
				"mods": {"kindle_blade": {"duration": ["+", 4.0], "damage": ["+", 2.0]}}}],
		11: [{"id": "hot_hands", "name": "Hot Hands", "says": "every Flameblade spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}},
			{"id": "afterglow_surge", "name": "Afterglow", "says": "after Overheat, your Flameblade spells hit 25% harder for 6 seconds",
				"fx": [{"kind": "surge", "of": "great", "seconds": 6.0, "power": 0.25}]}],
		12: {"id": "zenith_flameblade", "name": "Sunforged", "says": "every Flameblade spell also sends a wave of fire from your weapon along your aim: 14 to each foe it meets, and they catch fire (at most once a second)",
			"fx": [{"kind": "wave", "of": "any", "damage": 14.0, "width": 70.0, "travel": 240.0, "state": "burning", "seconds": 3.0, "every": 1.0}]},
	},
	"rune_artist": {
		"rank4": {"says": "spells you cast inside your circles cost 55% less (was 40%)", "boost": {3: {"thrift": 0.55}}},
		7: [{"id": "deep_brand", "name": "Deep Brand", "says": "Rune Brand bursts 30% harder and a quarter wider; Inscribe costs 4 less",
				"mods": {"rune_brand": {"damage": ["*", 1.3], "blast": ["*", 1.25]}, "inscribe": {"cost": ["+", -4.0]}}},
			{"id": "quick_script", "name": "Quick Script", "says": "Inscribe and Rune Brand wind up twice as fast and cost 2 less",
				"mods": {"inscribe": {"windup": ["*", 0.5], "cost": ["+", -2.0]}, "rune_brand": {"windup": ["*", 0.5], "cost": ["+", -2.0]}}}],
		8: {"id": "sigil_plus", "name": "Grand Sigil, Unending", "says": "the great circle lasts 9 seconds (was 6) and sears 8 a second (was 6)",
			"mods": {"grand_sigil": {"duration": ["=", 9.0], "pulse": ["=", 8.0]}}},
		9: [{"id": "wide_circle", "name": "Wide Circle", "says": "Ward Circle or Binding Circle is a third wider",
				"mods": {"ward_circle": {"radius": ["*", 1.33]}, "binding_circle": {"radius": ["*", 1.33]}}},
			{"id": "long_circle", "name": "Long Circle", "says": "Ward Circle or Binding Circle lasts 2 seconds longer",
				"mods": {"ward_circle": {"duration": ["+", 2.0]}, "binding_circle": {"duration": ["+", 2.0]}}}],
		10: [{"id": "glyph_burst", "name": "Glyph Burst", "says": "laying a Rune Trap also sets a rune burst where you aim: a ring warns for half a second, then foes within 66 take 16",
				"fx": [{"kind": "aim_burst", "of": "first", "range": 120.0, "radius": 66.0, "damage": 16.0, "delay": 0.5}]},
			{"id": "greater_runes", "name": "Greater Runes", "says": "Rune Traps burst 25% harder and a quarter wider",
				"mods": {"rune_trap": {"damage": ["*", 1.25], "blast": ["*", 1.25]}}}],
		11: [{"id": "thrifty_ink", "name": "Thrifty Ink", "says": "every Rune Artist spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}},
			{"id": "runes_of_power", "name": "Runes of Power", "says": "after Grand Sigil, your Rune Artist spells hit 25% harder for 8 seconds",
				"fx": [{"kind": "surge", "of": "great", "seconds": 8.0, "power": 0.25}]}],
		12: {"id": "zenith_rune_artist", "name": "The Living Script", "says": "every Rune Artist spell also draws a rune circle where you stand for 4 seconds: foes inside it (within 84) take 6 every half second (at most once every 1.5 seconds)",
			"fx": [{"kind": "field", "of": "any", "radius": 84.0, "seconds": 4.0, "tick": 0.5, "damage": 6.0, "every": 1.5}]},
	},
	# --- the Manticore's tower (Stone) -------------------------------------------
	"sandshaper": {
		"rank4": {"says": "your skin hardens after 0.6 seconds standing still (was 1), and then you take 40% less damage (was 30%)", "boost": {3: {"still": 0.6, "harden": 0.4}}},
		7: [{"id": "great_wall", "name": "Great Wall", "says": "Sand Wall stands 8 seconds (was 5) and is a third longer; Sandblast blinds 1.5 seconds longer",
				"mods": {"sand_wall": {"duration": ["=", 8.0], "length": ["*", 1.33]}, "sandblast": {"blind": ["+", 1.5]}}},
			{"id": "scouring_sand", "name": "Scouring Sand", "says": "Sandblast hits 30% harder in a quarter wider cone; Sand Wall costs 3 less",
				"mods": {"sandblast": {"damage": ["*", 1.3], "arc": ["*", 1.25]}, "sand_wall": {"cost": ["+", -3.0]}}}],
		8: {"id": "fault_plus", "name": "Fault Line, Chasm", "says": "the fault holds 11 seconds (was 8), buries foes 3 seconds (was 2) and crushes them for 36 (was 28)",
			"mods": {"fault_line": {"duration": ["=", 11.0], "bury": ["=", 3.0], "damage": ["=", 36.0]}}},
		9: [{"id": "deep_pit", "name": "Deep Pit", "says": "Sinkhole traps 1.5 seconds longer; Quicksand lasts 9 seconds (was 6)",
				"mods": {"sinkhole": {"trap": ["+", 1.5]}, "quicksand": {"duration": ["=", 9.0]}}},
			{"id": "grinding_sand", "name": "Grinding Sand", "says": "Quicksand is a third wider and grinds twice as hard; Sinkhole costs 4 less",
				"mods": {"quicksand": {"radius": ["*", 1.33], "damage": ["*", 2.0]}, "sinkhole": {"cost": ["+", -4.0]}}}],
		10: [{"id": "second_tremor", "name": "Second Tremor", "says": "the quake strikes again 0.6 seconds later, 70% as strong",
				"fx": [{"kind": "echo", "of": "first", "delay": 0.6, "power": 0.7}]},
			{"id": "wide_quake", "name": "Wide Quake", "says": "the quake is a third wider and hits 15% harder",
				"mods": {"quake": {"radius": ["*", 1.33], "damage": ["*", 1.15]}}}],
		11: [{"id": "bedrock", "name": "Bedrock", "says": "every Sandshaper spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}},
			{"id": "stone_skin", "name": "Stone Skin", "says": "every Sandshaper spell raises a stone shell of 10 around you for 3 seconds (at most once every 2 seconds)",
				"fx": [{"kind": "shield", "of": "any", "amount": 10.0, "seconds": 3.0, "every": 2.0}]}],
		12: {"id": "zenith_sandshaper", "name": "Living Mountain", "says": "every Sandshaper spell also cracks the ground around you: foes within 150 take 10, stagger, and are slowed for 2 seconds (at most once every 1.5 seconds)",
			"fx": [{"kind": "nova", "of": "any", "radius": 150.0, "damage": 10.0, "state": "slowed", "seconds": 2.0, "stagger": 0.4, "every": 1.5}]},
	},
	"venomist": {
		"rank4": {"says": "a poisoned foe that dies passes three quarters of its stacks (was half), and a foe at 6 stacks or more is staggered (was 8)", "boost": {2: {"pass": 0.75}, 3: {"stagger_at": 6}}},
		7: [{"id": "thick_cloud", "name": "Thick Cloud", "says": "Toxic Cloud lingers 9 seconds (was 6) and is a quarter wider; Contagion spreads for 9 seconds (was 6)",
				"mods": {"toxic_cloud": {"duration": ["=", 9.0], "radius": ["*", 1.25]}, "contagion": {"duration": ["=", 9.0]}}},
			{"id": "virulent_strain", "name": "Virulent Strain", "says": "Contagion infects with 4 stacks (was 2) and spreads a quarter farther; Toxic Cloud costs 3 less",
				"mods": {"contagion": {"stacks": ["+", 2], "radius": ["*", 1.25]}, "toxic_cloud": {"cost": ["+", -3.0]}}}],
		8: {"id": "virulence_plus", "name": "Virulence, Pandemic", "says": "Virulence reaches a quarter farther, bursts harder for each stack (5.5 a stack, was 4) and passes on three quarters of the venom (was half)",
			"mods": {"virulence": {"radius": ["*", 1.25], "damage": ["=", 5.5], "spread": ["=", 0.75]}}},
		9: [{"id": "lasting_paralysis", "name": "Lasting Paralysis", "says": "Neurotoxin paralyzes a second longer; Enfeeble lasts 9 seconds (was 6)",
				"mods": {"neurotoxin": {"paralyze": ["+", 1.0]}, "enfeeble": {"duration": ["=", 9.0]}}},
			{"id": "deep_toxin", "name": "Deep Toxin", "says": "Enfeeble weakens foes 55% (was 40%) and reaches a fifth farther; Neurotoxin costs 3 less",
				"mods": {"enfeeble": {"weaken": ["=", 0.55], "radius": ["*", 1.2]}, "neurotoxin": {"cost": ["+", -3.0]}}}],
		10: [{"id": "venom_rain", "name": "Venom Rain", "says": "Venom Spit also spits at the 2 nearest other foes: 2 stacks of poison each",
				"fx": [{"kind": "strike", "of": "first", "count": 2, "range": 260.0, "damage": 0.0, "state": "poisoned", "amount": 2, "look": "spit", "skip_aim": true}]},
			{"id": "potent_spit", "name": "Potent Spit", "says": "Venom Spit lays 3 more stacks",
				"mods": {"venom_spit": {"stacks": ["+", 3]}}}],
		11: [{"id": "lean_glands", "name": "Lean Glands", "says": "every Venomist spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}},
			{"id": "lingering_venom", "name": "Lingering Venom", "says": "every Venomist spell also poisons every foe within 100 of you with 1 stack (at most once a second)",
				"fx": [{"kind": "nova", "of": "any", "radius": 100.0, "damage": 0.0, "state": "poisoned", "amount": 1, "every": 1.0}]}],
		12: {"id": "zenith_venomist", "name": "Mother of Venoms", "says": "every Venomist spell also bursts a cloud of venom around you: every foe within 130 takes 3 stacks, and one already at 6 stacks or more takes 10 (at most once every 1.2 seconds)",
			"fx": [{"kind": "nova", "of": "any", "radius": 130.0, "damage": 0.0, "state": "poisoned", "amount": 3, "rich_at": 6, "rich_damage": 10.0, "every": 1.2}]},
	},
	"ashwalker": {
		"rank4": {"says": "unseen strikes stagger 0.9 seconds (was 0.6), and a kill while unseen hides you 2.5 seconds (was 1.5)", "boost": {2: {"stagger": 0.9}, 3: {"hide": 2.5}}},
		7: [{"id": "lasting_ghost", "name": "Lasting Ghost", "says": "Afterimage lasts 8 seconds (was 5); Ash Step's cloud of ash lasts 4 seconds (was 2.5)",
				"mods": {"afterimage": {"duration": ["=", 8.0]}, "ash_step": {"duration": ["=", 4.0]}}},
			{"id": "long_step", "name": "Long Step", "says": "Ash Step carries you a third farther; Afterimage costs 3 less",
				"mods": {"ash_step": {"distance": ["*", 1.33]}, "afterimage": {"cost": ["+", -3.0]}}}],
		8: {"id": "ashfall_plus", "name": "Ashfall, Long Night", "says": "the ash falls 14 seconds (was 10), and an unseen strike leaps to a second foe at full strength (was three quarters)",
			"mods": {"ashfall": {"duration": ["=", 14.0], "leap_share": ["=", 1.0]}}},
		9: [{"id": "deep_vanish", "name": "Deep Vanish", "says": "Vanish lasts 6 seconds (was 4); Cinder Trail burns 8 seconds (was 5)",
				"mods": {"vanish": {"duration": ["=", 6.0]}, "cinder_trail": {"duration": ["=", 8.0]}}},
			{"id": "hot_cinders", "name": "Hot Cinders", "says": "Cinder Trail burns 60% harder; Vanish costs 4 less",
				"mods": {"cinder_trail": {"embers": ["*", 1.6]}, "vanish": {"cost": ["+", -4.0]}}}],
		10: [{"id": "thick_smoke", "name": "Thick Smoke", "says": "Smoke Veil is a third wider and lasts 3 seconds longer",
				"mods": {"smoke_veil": {"radius": ["*", 1.33], "duration": ["+", 3.0]}}},
			{"id": "smoke_bomb", "name": "Smoke Bomb", "says": "casting Smoke Veil also makes every foe within 120 lose track of you for 3 seconds and slows it",
				"fx": [{"kind": "nova", "of": "first", "radius": 120.0, "damage": 0.0, "state": "unseen", "seconds": 3.0, "also": "slowed"}]}],
		11: [{"id": "light_feet", "name": "Light Feet", "says": "every Ashwalker spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}},
			{"id": "ember_heart", "name": "Ember Heart", "says": "every Ashwalker spell heals you 4 (at most once a second)",
				"fx": [{"kind": "heal", "of": "any", "amount": 4.0, "every": 1.0}]}],
		12: {"id": "zenith_ashwalker", "name": "Ghost of Cinders", "says": "every Ashwalker spell also throws out burning ash: every foe within 160 loses track of you for 2 seconds, takes 4 and catches fire (at most once every 1.5 seconds)",
			"fx": [{"kind": "nova", "of": "any", "radius": 160.0, "damage": 4.0, "state": "unseen", "seconds": 2.0, "also": "burning", "every": 1.5}]},
	},
	# --- the Firebird's tower (Fire) ----------------------------------------------
	"flame_contractor": {
		"rank4": {"says": "each foe your fire kills gives this mark back 3 essence (was 2), and your burning ground spreads faster and wider", "boost": {2: {"spread": 6.0, "spread_most": 2.0}, 3: {"refund": 3.0}}},
		7: [{"id": "long_wall", "name": "Long Wall", "says": "Fire Wall burns 8 seconds (was 5) and is a third longer; Blazing Trail lasts 2 seconds longer",
				"mods": {"fire_wall": {"duration": ["=", 8.0], "length": ["*", 1.33]}, "blazing_trail": {"duration": ["+", 2.0]}}},
			{"id": "hot_ground", "name": "Hot Ground", "says": "Blazing Trail burns 60% harder; Fire Wall costs 3 less",
				"mods": {"blazing_trail": {"burns": ["*", 1.6]}, "fire_wall": {"cost": ["+", -3.0]}}}],
		8: {"id": "meteor_plus", "name": "Meteor, Starfall", "says": "the meteor hits 60 (was 45), lands a fifth wider, and its crater burns 6 seconds (was 4)",
			"mods": {"meteor": {"damage": ["=", 60.0], "radius": ["*", 1.2], "crater": ["=", 6.0]}}},
		9: [{"id": "bigger_bang", "name": "Bigger Bang", "says": "Cluster Blast or Detonate hits 30% harder",
				"mods": {"cluster_blast": {"damage": ["*", 1.3]}, "detonate": {"damage": ["*", 1.3]}}},
			{"id": "wide_blast", "name": "Wide Blast", "says": "Cluster Blast's or Detonate's bursts are a third wider",
				"mods": {"cluster_blast": {"radius": ["*", 1.33]}, "detonate": {"radius": ["*", 1.33]}}}],
		10: [{"id": "twin_flame", "name": "Twin Flame", "says": "Fireball throws a second fireball 0.4 seconds later, 70% as strong",
				"fx": [{"kind": "echo", "of": "first", "delay": 0.4, "power": 0.7}]},
			{"id": "inferno_shell", "name": "Inferno Shell", "says": "Fireball's explosion is a third wider and hits 10% harder",
				"mods": {"fireball": {"radius": ["*", 1.33], "damage": ["*", 1.1]}}}],
		11: [{"id": "cheap_contract", "name": "Cheap Contract", "says": "every Flame Contractor spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}},
			{"id": "firestorm", "name": "Firestorm", "says": "after Meteor, your Flame Contractor spells hit 25% harder for 8 seconds",
				"fx": [{"kind": "surge", "of": "great", "seconds": 8.0, "power": 0.25}]}],
		12: {"id": "zenith_flame_contractor", "name": "Heart of the Sun", "says": "every Flame Contractor spell also drops a small meteor where you aim: a burning ring warns for 0.8 seconds, then foes within 70 take 16 and catch fire (at most once every 1.2 seconds)",
			"fx": [{"kind": "aim_burst", "of": "any", "range": 190.0, "radius": 70.0, "damage": 16.0, "delay": 0.8, "state": "burning", "seconds": 3.0, "every": 1.2}]},
	},
	"flamewing": {
		"rank4": {"says": "standing in fire heals you more (2.5, was 1.5), and fire that would hurt you feeds the aura more", "boost": {2: {"fire_heal": 2.5}, 3: {"feed_heat": 12.0, "feed_essence": 2.5}}},
		7: [{"id": "great_wings", "name": "Great Wings", "says": "Wingburst is a quarter wider; Cinder Dive carries you a third farther",
				"mods": {"wingburst": {"radius": ["*", 1.25]}, "cinder_dive": {"dist": ["*", 1.33]}}},
			{"id": "blazing_wings", "name": "Blazing Wings", "says": "Wingburst or Cinder Dive hits 25% harder",
				"mods": {"wingburst": {"damage": ["*", 1.25]}, "cinder_dive": {"damage": ["*", 1.25]}}}],
		8: {"id": "firebird_plus", "name": "Firebird Form, Blazing", "says": "the form lasts 12 seconds (was 8), and your aura reaches 1.8 times as far in it (was 1.5)",
			"mods": {"firebird_form": {"duration": ["=", 12.0], "aura": ["=", 1.8]}}},
		9: [{"id": "hearth", "name": "Hearth", "says": "Warmth heals 3.5 a second (was 2.5); Heat Haze lasts 12 seconds (was 8)",
				"mods": {"warmth": {"heal": ["=", 3.5]}, "heat_haze": {"duration": ["=", 12.0]}}},
			{"id": "long_warmth", "name": "Long Warmth", "says": "Warmth lasts 15 seconds (was 10); Heat Haze burns 50% harder",
				"mods": {"warmth": {"duration": ["=", 15.0]}, "heat_haze": {"burn": ["*", 1.5]}}}],
		10: [{"id": "wide_aura", "name": "Wide Aura", "says": "Heat Aura reaches a third farther and burns 1 harder",
				"mods": {"heat_aura": {"radius": ["*", 1.33], "damage": ["+", 1.0]}}},
			{"id": "thrifty_flame", "name": "Thrifty Flame", "says": "Heat Aura drains 40% less essence while it burns",
				"mods": {"heat_aura": {"drain": ["*", 0.6]}}}],
		11: [{"id": "ember_heart_wing", "name": "Ember Heart", "says": "every Flamewing spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}},
			{"id": "rising_heat", "name": "Rising Heat", "says": "every Flamewing spell heals you 3 (at most once a second)",
				"fx": [{"kind": "heal", "of": "any", "amount": 3.0, "every": 1.0}]}],
		12: {"id": "zenith_flamewing", "name": "Wings of the Sun", "says": "every Flamewing spell also beats a pair of burning wings around you: foes within 120 take 12 and catch fire (at most once every 1.2 seconds)",
			"fx": [{"kind": "nova", "of": "any", "radius": 120.0, "damage": 12.0, "state": "burning", "seconds": 3.0, "look": "wings", "every": 1.2}]},
	},
	"rekindler": {
		"rank4": {"says": "Last Ember works three times a floor (was twice), and surviving it erupts harder (42, was 30) and wider", "boost": {2: {"uses": 3}, 3: {"erupt": 42.0, "erupt_radius": 130.0}}},
		7: [{"id": "fury", "name": "Fury", "says": "Desperation lasts 12 seconds (was 8); Flashpoint's burst is a quarter wider",
				"mods": {"desperation": {"duration": ["=", 12.0]}, "flashpoint": {"radius": ["*", 1.25]}}},
			{"id": "burning_will", "name": "Burning Will", "says": "Desperation's top strength grows to three times as hard (was two and a half); Flashpoint hits 30% harder",
				"mods": {"desperation": {"power_low": ["=", 2.0]}, "flashpoint": {"damage": ["*", 1.3]}}}],
		8: {"id": "phoenix_plus", "name": "Phoenix Heart, Undying", "says": "when you rise, nothing can hurt you for 9 seconds (was 6), and the burst hits 36 (was 24) and reaches a quarter farther",
			"mods": {"phoenix_heart": {"duration": ["=", 9.0], "damage": ["=", 36.0], "radius": ["*", 1.25]}}},
		9: [{"id": "oathfire", "name": "Oathfire", "says": "Pyre Oath or Backdraft lasts 14 seconds (was 10)",
				"mods": {"pyre_oath": {"duration": ["=", 14.0]}, "backdraft": {"duration": ["=", 14.0]}}},
			{"id": "hot_oath", "name": "Hot Oath", "says": "Pyre Oath's or Backdraft's bursts hit 30% harder",
				"mods": {"pyre_oath": {"burst": ["*", 1.3], "damage": ["*", 1.3]}, "backdraft": {"damage": ["*", 1.3]}}}],
		10: [{"id": "wildfire_ring", "name": "Wildfire Ring", "says": "Rekindle's ring of fire is a third wider and burns 1 harder",
				"mods": {"rekindle": {"radius": ["*", 1.33], "burn": ["+", 1.0]}}},
			{"id": "kindling_heart", "name": "Kindling Heart", "says": "lighting Rekindle heals you 8 at once",
				"fx": [{"kind": "heal", "of": "first", "amount": 8.0}]}],
		11: [{"id": "stubborn_flame", "name": "Stubborn Flame", "says": "every Rekindler spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}},
			{"id": "second_wind", "name": "Second Wind", "says": "a Rekindler spell cast below a third of your health heals you 6 (at most once a second)",
				"fx": [{"kind": "heal", "of": "any", "amount": 6.0, "below": 0.34, "every": 1.0}]}],
		12: {"id": "zenith_rekindler", "name": "Undying Flame", "says": "every Rekindler spell also bursts into flame around you: foes within 120 take 12 and catch fire, and you heal 3 for each foe it catches, up to 5 (at most once every 1.5 seconds)",
			"fx": [{"kind": "nova", "of": "any", "radius": 120.0, "damage": 12.0, "state": "burning", "seconds": 3.0, "heal_per": 3.0, "heal_most": 5, "every": 1.5}]},
	},
	# --- the Chimera's tower (Blade) ------------------------------------------------
	"covenant": {
		"rank4": {"says": "your creatures stay half again as long (was a third), and one that falls heals you 35% of its health (was 25%)", "boost": {2: {"stay": 1.5}, 3: {"fall_heal": 0.35}}},
		7: [{"id": "commanding_voice", "name": "Commanding Voice", "says": "Command also staggers every foe within 120 of you; Rally heals your creatures by half (was a third)",
				"mods": {"rally": {"heal": ["=", 0.5]}}, "fx": [{"kind": "nova", "of": "command", "radius": 120.0, "damage": 0.0, "stagger": 0.5}]},
			{"id": "bloodlust", "name": "Bloodlust", "says": "Rally makes your creatures hit half again as hard (was a third) and move 40% faster; Command costs 1 (was 3)",
				"mods": {"rally": {"might": ["=", 1.5], "haste": ["=", 1.4]}, "command": {"cost": ["=", 1.0]}}}],
		8: {"id": "grand_call_plus", "name": "Grand Call, Host", "says": "the host stays 18 seconds (was 12) and arrives 1.8 times as mighty (was 1.5)",
			"mods": {"grand_call": {"duration": ["=", 18.0], "might": ["=", 1.8]}}},
		9: [{"id": "close_kin", "name": "Close Kin", "says": "Exchange costs 4 less; Release is a third wider and heals you 40% (was 30%)",
				"mods": {"exchange": {"cost": ["+", -4.0]}, "release": {"radius": ["*", 1.33], "heal": ["=", 0.4]}}},
			{"id": "violent_release", "name": "Violent Release", "says": "Release hits 40% harder; Exchange also shoves every foe within 90 of where you land and strikes it for 8",
				"mods": {"release": {"damage": ["*", 1.4]}}, "fx": [{"kind": "nova", "of": "exchange", "radius": 90.0, "damage": 8.0, "push": 220.0}]}],
		10: [{"id": "great_retinue", "name": "Great Retinue", "says": "the creatures you Call stay 15 seconds longer",
				"mods": {"bind_and_call": {"duration": ["+", 15.0]}}},
			{"id": "calling_howl", "name": "Calling Howl", "says": "casting Bind and Call lets out a howl: every foe within 130 of you takes 6 and staggers",
				"fx": [{"kind": "nova", "of": "first", "radius": 130.0, "damage": 6.0, "stagger": 0.6}]}],
		11: [{"id": "bond_of_plenty", "name": "Bond of Plenty", "says": "every Covenant spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}},
			{"id": "kin_ward", "name": "Kin Ward", "says": "every Covenant spell raises a shell of 10 around you for 3 seconds (at most once every 2 seconds)",
				"fx": [{"kind": "shield", "of": "any", "amount": 10.0, "seconds": 3.0, "every": 2.0}]}],
		12: {"id": "zenith_covenant", "name": "Kinlord", "says": "every Covenant spell also calls a spirit to fight beside you for 10 seconds; if three creatures are out already, they're healed by a sixth instead (at most once every 2 seconds)",
			"fx": [{"kind": "kin", "of": "any", "creature": "familiar", "seconds": 10.0, "heal": 0.17, "every": 2.0}]},
	},
	"grafter": {
		"rank4": {"says": "each graft you carry gives you 8 more health (was 5)", "boost": {2: {"graft_health": 8.0}}},
		7: [{"id": "deep_mimic", "name": "Deep Mimic", "says": "Mimic hits 30% harder; Harvest slays foes below 40% of their health (was a third)",
				"mods": {"mimic": {"damage": ["*", 1.3]}, "harvest": {"below": ["=", 0.4]}}},
			{"id": "long_reach_graft", "name": "Long Reach", "says": "Mimic or Harvest reaches a third farther and costs 3 less",
				"mods": {"mimic": {"reach": ["*", 1.33], "cost": ["+", -3.0]}, "harvest": {"reach": ["*", 1.33], "cost": ["+", -3.0]}}}],
		8: {"id": "chimera_plus", "name": "Chimera Form, Apex Beast", "says": "the form lasts 15 seconds (was 10), and its strikes hit 18 (was 14)",
			"mods": {"chimera_form": {"duration": ["=", 15.0], "damage": ["=", 18.0]}}},
		9: [{"id": "violent_shedding", "name": "Violent Shedding", "says": "Shed bursts 30% harder and a fifth wider; Bud's creature stays 22 seconds (was 15)",
				"mods": {"shed": {"damage": ["*", 1.3], "radius": ["*", 1.2]}, "graft_bud": {"duration": ["=", 22.0]}}},
			{"id": "thrifty_flesh", "name": "Thrifty Flesh", "says": "Shed or Bud costs 3 less",
				"mods": {"shed": {"cost": ["+", -3.0]}, "graft_bud": {"cost": ["+", -3.0]}}}],
		10: [{"id": "second_lash", "name": "Second Lash", "says": "Graft Burst lashes out again 0.5 seconds later, 60% as strong",
				"fx": [{"kind": "echo", "of": "first", "delay": 0.5, "power": 0.6}]},
			{"id": "great_lash", "name": "Great Lash", "says": "Graft Burst is a quarter wider and hits 2 harder for each graft you carry",
				"mods": {"graft_burst": {"radius": ["*", 1.25], "per_graft": ["+", 2.0]}}}],
		11: [{"id": "lean_flesh", "name": "Lean Flesh", "says": "every Grafter spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}},
			{"id": "mending_flesh", "name": "Mending Flesh", "says": "every Grafter spell heals you 2 for each graft you carry (at most once a second)",
				"fx": [{"kind": "heal", "of": "any", "amount": 0.0, "per_graft": 2.0, "every": 1.0}]}],
		12: {"id": "zenith_grafter", "name": "The Many-Formed", "says": "every Grafter spell also lashes out with every graft: foes within 140 take 8, and 3 more for each graft you carry, and stagger (at most once every 1.2 seconds)",
			"fx": [{"kind": "nova", "of": "any", "radius": 140.0, "damage": 8.0, "per_graft": 3.0, "stagger": 0.3, "every": 1.2}]},
	},
	"surgeon": {
		"rank4": {"says": "striking where a foe is weak staggers it longer (0.7 seconds) and as often as every 2 seconds, and Mend heals 30% more for every bleeding foe near you (was 20%)", "boost": {2: {"weak_stagger": 0.7, "weak_every": 2.0}, 3: {"mend_per": 0.3}}},
		7: [{"id": "field_medic", "name": "Field Medic", "says": "Mend heals 30% more; Bloodletting gives you back half of what it drains (was 40%)",
				"mods": {"mend": {"heal": ["*", 1.3]}, "bloodletting": {"share": ["=", 0.5]}}},
			{"id": "quick_hands", "name": "Quick Hands", "says": "Mend or Bloodletting costs 3 less and winds up faster",
				"mods": {"mend": {"cost": ["+", -3.0], "windup": ["*", 0.6]}, "bloodletting": {"cost": ["+", -3.0], "windup": ["*", 0.6]}}}],
		8: {"id": "amputate_plus", "name": "Amputate, Master's Cut", "says": "the cut deals 36 (was 26) and costs 2 less",
			"mods": {"amputate": {"damage": ["=", 36.0], "cost": ["+", -2.0]}}},
		9: [{"id": "deep_transfer", "name": "Deep Transfer", "says": "Transfer moves up to 45 more of your wounds (was 30); Anesthetize puts a foe to sleep 2 seconds longer",
				"mods": {"transfer": {"most": ["=", 45.0]}, "anesthetize": {"sleep": ["+", 2.0]}}},
			{"id": "precise_hands", "name": "Precise Hands", "says": "Transfer or Anesthetize costs 3 less, and Anesthetize reaches a third farther",
				"mods": {"transfer": {"cost": ["+", -3.0]}, "anesthetize": {"cost": ["+", -3.0], "reach": ["*", 1.33]}}}],
		10: [{"id": "twin_cut", "name": "Twin Cut", "says": "Sever cuts again 0.3 seconds later, 60% as strong",
				"fx": [{"kind": "echo", "of": "first", "delay": 0.3, "power": 0.6}]},
			{"id": "opening_cut", "name": "Opening Cut", "says": "Sever's flick of the blade opens a bleed on every foe within 110 of you for 4 seconds",
				"fx": [{"kind": "nova", "of": "first", "radius": 110.0, "damage": 3.0, "state": "bleeding", "seconds": 4.0}]}],
		11: [{"id": "lean_practice", "name": "Lean Practice", "says": "every Surgeon spell costs 15% less",
				"mods": {"*": {"cost": ["*", 0.85]}}},
			{"id": "keen_blade", "name": "Keen Blade", "says": "Sever cuts 25% harder",
				"mods": {"sever": {"damage": ["*", 1.25]}}}],
		12: {"id": "zenith_surgeon", "name": "The Last Physician", "says": "every Surgeon spell also opens a bleed on up to 3 foes within 240 of you for 5 seconds, and heals you 2 for each (at most once a second)",
			"fx": [{"kind": "strike", "of": "any", "count": 3, "range": 240.0, "damage": 4.0, "state": "bleeding", "seconds": 5.0, "heal_per": 2.0, "look": "cut", "every": 1.0}]},
	},
}


# --- reading it --------------------------------------------------------------------------

static func of(bond_id: String) -> Dictionary:
	return ASCENT.get(bond_id, {})


## The two sides of a fork step (7, 9, 10, 11), or [].
static func sides(bond_id: String, step: int) -> Array:
	var s = of(bond_id).get(step, [])
	return s if s is Array else []


## The single upgrade of step 8 or 12 ({}).
static func single(bond_id: String, step: int) -> Dictionary:
	var s = of(bond_id).get(step, {})
	return s if s is Dictionary else {}


static func zenith(bond_id: String) -> Dictionary:
	return single(bond_id, ZENITH_STEP)


static func rank4(bond_id: String) -> Dictionary:
	var r = of(bond_id).get("rank4", {})
	return r if r is Dictionary else {}


## Every upgrade in force for a mark at `step` with these tree choices
## ({step: option id}), in step order.
static func in_force(bond_id: String, step: int, choices: Dictionary) -> Array:
	var out: Array = []
	if step < 7 or not ASCENT.has(bond_id):
		return out
	for s in range(7, mini(step, ZENITH_STEP) + 1):
		if s in FORKS:
			var c := String(choices.get(s, choices.get(str(s), "")))
			if c == "":
				continue
			for o in sides(bond_id, s):
				if String(o["id"]) == c:
					out.append(o)
		else:
			var o := single(bond_id, s)
			if not o.is_empty():
				out.append(o)
	return out


## A spell's number with the upgrades in force (`ups`, from in_force).
static func mod_value(ups: Array, spell_id: String, key: String, value):
	for o in ups:
		var mods: Dictionary = o.get("mods", {})
		for target in [spell_id, "*"]:
			var m = mods.get(target, {})
			if not (m is Dictionary) or not m.has(key):
				continue
			var op: Array = m[key]
			var v = op[1]
			match String(op[0]):
				"=":
					value = v
				"+":
					if value is int and v is int:
						value = int(value) + int(v)
					else:
						value = float(value if value != null else 0.0) + float(v)
				"*":
					if value != null:
						value = float(value) * float(v)
	return value


## A spell's place on the tree: "first", "second", "fourth" or "great" (by
## the step it's learned at).
static func slot_of(sp: Dictionary) -> String:
	match int(sp.get("learn", 0)):
		1:
			return "first"
		2:
			return "second"
		4:
			return "fourth"
		5:
			return "great"
	return ""


## True if an fx's "of" covers this spell.
static func covers(fx: Dictionary, sp: Dictionary) -> bool:
	var of_ := String(fx.get("of", "any"))
	return of_ == "any" or of_ == slot_of(sp) or of_ == String(sp.get("id", ""))


## What reaching a step from 6 to 12 brings a mark, in a few words ("" for others).
static func step_note(bond_id: String, step: int) -> String:
	if not ASCENT.has(bond_id) or step < RANK4_STEP or step > ZENITH_STEP:
		return ""
	if step == RANK4_STEP:
		var B = load("res://scripts/bonds.gd")
		return TEXT["rank4_says"] % [String(B.BONDS[bond_id]["passive"]["name"]), String(rank4(bond_id).get("says", ""))]
	if step in FORKS:
		var s := sides(bond_id, step)
		if s.size() < 2:
			return ""
		return (TEXT["transform"] if step == TRANSFORM_STEP else TEXT["fork"]) % [s[0]["name"], s[1]["name"]]
	var o := single(bond_id, step)
	if o.is_empty():
		return ""
	return (TEXT["zenith"] if step == ZENITH_STEP else TEXT["apex"]) % [o["name"], o["says"]]
