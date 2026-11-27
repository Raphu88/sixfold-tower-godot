extends RefCounted
## Talking with the Entity: pick a question, and it answers from the game's
## own facts, in its voice. No typing, no outside service: everything it can
## say is here, in plain data (and in the Data editor: "The Entity's words").
##
## On the train, click or tap its sphere (or press L, or the right stick);
## in a climb, open its panel and press Talk (or hold L / the right stick).
## menu.gd's "talk" page shows it: the Entity's line, then its choices as
## buttons (mouse, keys, controller and touch, as every page), Esc or B to
## leave.
##
## DIALOGUE is a small tree of nodes, by id. Each node:
##   ask      what you say to get here: the choice's words (blanks allowed)
##   lines    what the Entity says here: one is picked each time. {name}
##            blanks are filled from `fact` (below), and from the words of
##            the moment ({floor}, {tower}...)
##   fact     a fact to fill the blanks with (the game as it is now):
##            tower, hazards, marks, soak, money, next, next_more, climb
##            (the functions _fact_<name> below; facts() lists them)
##   choices  where you can go next: node ids. "start" goes back to the
##            first question; a choice is shown only when its node's `if`
##            holds and it has something to say
##   if       when the choice shows: on_train, in_play, marked, unbound,
##            sworn_known (one of the Sworn, a Maker met, or saved by one),
##            climbed (on the train after a climb), logged (events to tell),
##            grown (marked, or Unbound: forcing works on either),
##            story_plea (the Makers' plea seen or due), story_final (all
##            six guardians beaten, or the final meeting seen)
##   leave    choosing it ends the talk
##   act      ...and then does this: "tour:station" or "tour:train" (the
##            Entity's tour, tour.gd)
## At most MAX_CHOICES show at once; more go under "Something else".
##
## STORY SLOTS (the owner's to write): a node whose every line starts with
## STORY_TAG is hidden from players. Write the Entity's answer over that
## line (here, or in the Data editor, which shows the line) and the choice
## appears. Never invent the story here: who the Entity is, and what the
## towers are for, are the owner's.

const Towers := preload("res://scripts/towers.gd")
const Bonds := preload("res://scripts/bonds.gd")
const Essence := preload("res://scripts/essence.gd")
const Entity := preload("res://scripts/entity.gd")
const Notes := preload("res://scripts/entity_notes.gd")
const Train := preload("res://scripts/train.gd")
const Gear := preload("res://scripts/gear.gd")
const Unbound := preload("res://scripts/unbound.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const MarkUse := preload("res://scripts/mark_use.gd")  # (marks grow by use, and burns)
const Notices := preload("res://scripts/notices.gd")
const Flow := preload("res://scripts/essence_flow.gd")
const Combat := preload("res://scripts/combat.gd")
const OutfitterName := preload("res://scripts/outfitter_name.gd")
const RuneArtistName := preload("res://scripts/rune_artist_name.gd")

## A line that starts with this is a story slot not written yet (hidden).
const STORY_TAG := "[Yours to write]"
## At most this many choices show at once (Goodbye among them).
const MAX_CHOICES := 5

static var DIALOGUE: Dictionary = RuneArtistName.named(OutfitterName.named({
	"start": {"ask": "Something else.",
		"lines": [
			"Yes? I was counting.",
			"Ask. I keep the answers as well as the list.",
			"You want something. Go on.",
			"Questions. Good. I have a few answers.",
		],
		"choices": ["next", "how", "tower", "marks", "body", "climb", "this_climb", "train", "tour", "who", "why", "bye"]},
	# --- what to do ---------------------------------------------------------------------
	"next": {"ask": "What should I do next?", "fact": "next",
		"lines": ["{hint}"],
		"choices": ["next_more", "start", "bye"]},
	"next_more": {"ask": "Anything else?", "fact": "next_more",
		"lines": ["{hint}"],
		"choices": ["start", "bye"]},
	# --- how things work (the game's own rules; numbers from its tables) --------------------
	# A new topic: add a node here with "fact": "rules" (or none), and its id
	# to "how"'s choices.
	"how": {"ask": "How do things work here?",
		"lines": ["Which part? I'll keep it short.", "Ask. The rules are simpler than they look. Mostly."],
		"choices": ["how_controls", "how_start", "how_grace", "how_training", "how_stamina", "how_essence", "how_marks", "how_burns", "how_new_mark", "how_part_fills", "how_dodge", "how_synergies", "how_renown", "how_travel", "how_titles", "how_contracts", "how_tourney", "how_manager", "how_climb", "how_first_mark", "how_mark_seal", "how_barrier", "how_fall", "how_belt", "how_wheel", "how_states", "how_handy", "how_charms", "how_workshop", "how_offhand", "how_item_pool", "how_gear", "how_summit", "how_deeds", "how_bags", "how_shop", "how_exchange", "how_ward", "how_secret", "how_portals", "how_aura", "how_vessel", "how_unbound", "how_passing", "how_nodes", "how_sealing", "how_drain", "how_sworn", "how_unbound_words", "how_unbound_techniques", "how_bestiary", "how_guardians", "how_wild", "how_rivals", "how_dining", "how_bets", "how_duels", "how_glows", "how_ways_down", "how_foes", "how_plea", "how_final", "start", "bye"]},
	"how_controls": {"ask": "What are the controls?", "fact": "controls",
		"lines": ["{controls_how}", "{controls_list}", "Press H any time to show or hide this list in the corner of the screen. Settings & Controls lets you change any key."],
		"choices": ["how", "bye"]},
	"how_start": {"ask": "How did my start work?", "fact": "start",
		"lines": ["Three questions made your start. What you did before gave your weapon and armour: Soldier a sword and chain, Hunter a shortbow, a dagger and leather, Labourer a war hammer and padding, Beggar a dagger and nothing, Scholar a sword cane and padding, Sailor a flintlock and leather. They're heirlooms, so every climb begins with them; a plain sword and shortbow filled the weapon slots they left empty. Where you grew up chose your first tower and your home station. Why you climb set how hard it was: born into it, fine gear, {born_crystals} crystals and a family title; hired, common gear, {hired_crystals} crystals, a title and a contract; self made, worn gear and nothing else, but renown a quarter faster until a first title. {start_line}"],
		"choices": ["how_titles", "how_renown", "how", "bye"]},
	"how_stamina": {"ask": "Stamina, and why my bar shrinks?", "fact": "rules",
		"lines": ["Rolls, strikes, shots and jumps cost stamina, and it refills fast, {sta_regen} a second once you stop for a breath. Act with too little and it still happens, but the missing part comes off your max stamina: fatigue. The bar's lost end goes dark, and it fills only to what's left, never below {sta_floor} of it. A Stamina Vial shakes it all off and fills you up. So does a camp's rest, and every climb starts fresh. The stair's rest doesn't touch it."],
		"choices": ["how_belt", "how", "bye"]},
	"how_essence": {"ask": "Essence, banking it, and tinctures?", "fact": "rules",
		"lines": ["Monsters, caches and finished tasks give essence. You carry it until a stair banks it, and a fall loses what you carry. At a stair it splits three ways: {body} to your body, {marks} to your marks, {condense} into crystals, the train's money."],
		"choices": ["how_flow", "how_tinctures", "how_marks", "how", "bye"]},
	"how_flow": {"ask": "How does essence flow?", "fact": "rules",
		"lines": ["Divided, never copied. Of what you bank at a stair, {body} soaks into your body, spread by what each part did: unmarked parts fill toward a new mark. {marks} goes to your marks: it refills what each one's spells used and deepens it; of what they can't take, a little condenses into crystals and the rest goes back to the well. {condense} becomes crystals, always, and body and marks share the rest. Eat a crystal and it flows the same way, without the crystals' share. Only a tincture lets you steer."],
		"choices": ["how_tinctures", "how_forcing", "how_marks", "how", "bye"]},
	"how_forcing": {"ask": "Forcing a Node or mark?", "if": "grown", "fact": "rules",
		"lines": ["A full mark or Node takes nothing more from a crystal: a mark lets it soak into your body instead, and a Node leaves it a crystal. Force it, the button beside Eat, pushes the essence in anyway. The part stretches a little, a mark deepening or a Node growing, but it costs {force_cost} times the essence its use would take, so using your power stays the way to grow. It's for a part you've neglected. Each crystal forced strains it {force_per}, and it asks first, saying where the strain would leave it. Strained, the part refills a little slower. At {force_burned} strain it burns, as overdrawing burns a mark; at {force_paralyzed} it's paralyzed and can't be used. Push it to {force_break} and a mark burns out, dark for this climb and the next {dark}, counted as a slip toward a Maker; a Node cracks and loses {force_crack} of its size. Strain fades {force_fade_stair} at each stair and {force_fade_climb} as a climb starts. In a climb it strikes at once, mid-fight. The guardians frown on a damaged mark. As for the Unbound who push and push... ask the Husks. If they still answer."],
		"choices": ["how_burns", "how_flow", "how", "bye"]},
	"how_tinctures": {"ask": "What are tinctures?", "fact": "rules",
		"lines": ["A vial of {tincture} essence of one kind. Drink it and you choose where it goes: one mark, where its own kind counts {own}x and any other {other}x, and it's concentrated, {boost}x what banked essence gives, or one unmarked part, toward a new mark there. Vaults and secret rooms hold them, now and then a monster drops one, {outfitter} stocks {store_kinds} each visit, and the Workshop crafts one from {craft} crystals of its kind, or from {vessel_per} raw essence carried home in a vessel."],
		"choices": ["how_flow", "how_vessel", "how_new_mark", "how", "bye"]},
	"how_marks": {"ask": "How do marks grow?", "fact": "rules",
		"lines": ["By use. Each mark holds a pool of essence, and its depth carries it up its steps. Cast its spells in a climb, and at each stair your marks' share of what you bank, {marks} of it, refills what each one used, then deepens its pool by {deepen} of that use, using up banked essence too. Its own kind pays fully; another kind pays {use_other}. A mark you never cast takes in only a trickle; of what your marks can't take, a little condenses into crystals and the rest goes back to the well. Cast more than you bank and the extra adds nothing. The more marks you carry, the slower each grows. Each has {steps} steps. Steps 1 to 5 bring its spells and their first changes. Step 6 raises its passive to rank IV; steps 7, 9 and 11 each let you choose one of two upgrades to its spells; step 8 strengthens its great spell; step 10 is a second Transformation of your first spell, one of two; and step 12 is its Zenith, its greatest power, when every one of its spells does something more. Your tree shows every step. It's slow on purpose: a mark keeps you company for many climbs, about as long as the towers do. A tincture steers essence into one mark, {boost}x as strong as banked essence, and winning the Proving, on floor six, grows the mark you used most by {proving}."],
		"choices": ["how_burns", "how_new_mark", "how_synergies", "how", "bye"]},
	"how_burns": {"ask": "What if I overdraw a mark?", "fact": "rules",
		"lines": ["Cast with too little essence and the spell still fires, weaker, but the mark burns and its body part is weaker. Overdraw it again while it's burned and it tears health from you and seizes: paralyzed, it can't be cast. Each stair heals one rung, paralyzed to burned to healed. Hold a paralyzed mark's button to force it and it fires, but it burns out: dark for this climb and the next {dark}, a little shallower (never more than a step back), never erased. The guardians frown on it, and the Makers count it as a slip past a barrier."],
		"choices": ["how_marks", "how_forcing", "how", "bye"]},
	"how_synergies": {"ask": "How do synergies work?",
		"lines": ["Marks you carry together answer each other. Any two lend each other one trait, about a quarter as strong as the real thing: Stormcaller lends a little charge, Tidecaller a little soak, Warden a thin barrier when you cast, and so on. So every mark's spells pick up a touch of the others'. Twelve pairs go further and make a named synergy instead, like Tempest or Scald. A teammate's marks count while they fight beside you. Your book's Marks section lists them all."],
		"choices": ["how_marks", "how_states", "how", "bye"]},
	"how_new_mark": {"ask": "How do I earn a new mark?", "fact": "rules",
		"lines": ["Your body's share of what you bank soaks into your unmarked parts, by what each does (ask me what fills each part), slower the more marks you carry. Only the fullest fills all the way; the rest stop just short of ready until it's marked. A part {full} full is ready. Reach a summit and the beast marks it. Or prove yourself sooner: break into a sealed wing on floor {early} or below, keep its rule and beat it, and the Maker of Marks may mark you there. Fall with a full part and there's a {fall_chance} chance it takes a faint mark anyway. One new mark a climb, at most. The first comes at the Regard; fall on that first climb and it's faint: {faint} more banked essence before it grows."],
		"choices": ["how_part_fills", "how_marks", "how_tinctures", "how", "bye"]},
	"how_part_fills": {"ask": "What fills each body part?",
		"lines": ["Each part fills from what it does. The hand: your weapon's strikes and shots that land. The legs: a roll or a jump that carries you clear of a blow that was coming, a roll through an attack, a leap over a gap, burning floor, a trap or a low blow. The heart: hits you take and survive. The brow: parries, perfect ones more. The throat: one swing or spell catching several foes. The back: backstabs, and the blow that fells a foe. Some follow how you fight, some what you struggle with, so the mark helps either way. The same thing again and again on one floor counts a little less each time, until the stair. Variety fills you fastest."],
		"choices": ["how_new_mark", "how_dodge", "how", "bye"]},
	"how_dodge": {"ask": "Jumping, rolling, and low blows?",
		"lines": ["A roll makes you untouchable for a moment; a jump lifts you over chasms, burning floor and low blows: warnings with small red chevrons pointing up, like a knight's leg sweep, a shellback's slam, the Kraken's tentacle and the Wyvern's tail. Anything else still reaches you in the air. Roll or jump clear of a blow that was coming, roll through one, or leap a gap or a low blow, and your legs fill toward a mark. Rolling at nothing fills nothing."],
		"choices": ["how_part_fills", "how_controls", "how", "bye"]},
	"how_renown": {"ask": "What is renown for?", "fact": "rules",
		"lines": ["Renown comes from climbs ({per_floor} a floor reached, {per_best} more for each floor past your best, {beast} a beast), and from tournaments, the Noble's contracts, Training and deeds with other climbers. Every gain says what it was for. Ranks: {ranks}. Each opens something to do: a higher bracket, a medal drill, more contracts, new titles, a charm recipe, cheaper refills. A station's Renown Board says what your next rank opens."],
		"choices": ["how_titles", "how_contracts", "how_tourney", "how", "bye"]},
	"how_travel": {"ask": "Stations and travel?", "fact": "travel",
		"lines": ["There are {stations} stations on a loop, each in a city near its tower, each with Training, a tournament and its own Noble. Titles are shared by every Noble. You're at {station}; your home is {home}. You climb the tower by the station you're at, so to climb another, ride there first: the Engine's map. A stop costs {fare} crystals of any kind, the shorter way round, so {max_fare} at most. {title_cut} {lock}"],
		"choices": ["tour", "how_titles", "how", "bye"]},
	"how_titles": {"ask": "How do titles work?", "fact": "titles",
		"lines": ["The Noble at a station grants them. Each needs a rank and a deed; when both are done, ask to be named. Wear one at a time: only the worn one counts. Each helps with someone: other climbers trade kinder or team up more, Training costs less, tournament masters open brackets sooner, {outfitter} takes some off. {title_line}"],
		"choices": ["how_contracts", "how_renown", "how", "bye"]},
	"how_contracts": {"ask": "What are contracts?", "fact": "titles",
		"lines": ["Tasks the Noble gives: reach a floor of a named tower, slay so many of one monster, or retrieve a thing from a floor and take the stair with it. Hold {contracts_most} at once. The line at the top of the screen tracks each while you climb; I note them too. Done, they pay renown, crystals, and sometimes a charm recipe. They never hold up a floor. Now and then a Noble also asks for a full vessel for the city, raw or core essence: deliver it from your stash at any Noble. {contract_line}"],
		"choices": ["how_titles", "how_vessel", "how_tourney", "how", "bye"]},
	"how_tourney": {"ask": "How do tournaments work?", "fact": "titles",
		"lines": ["Brackets of three rounds against other climbers, at a station. Nobody dies: knocked down, you yield. Health and marks are made whole between rounds. A fee to enter; renown for each round past your best; winning pays renown, crystals, a title from the Noble, and in the higher brackets a relic. Brackets open with rank: {brackets}."],
		"choices": ["how_manager", "how_titles", "how_renown", "how", "bye"]},
	"how_climb": {"ask": "How does a climb go, floor by floor?",
		"lines": ["Twelve floors to the guardian at the summit. Camps after floors 3, 6 and 9: a full rest and one of three cards. Floor 6 is the Proving. On your first climb the Regard opens floor 6: the guardian shows you the last fracture, marks you, then offers a way out. Leave with the mark, or climb on. Fall below floor 6 later and the Proving won't ask again, unless you take its lethal door. Beat all six guardians and you'll see an ending. Then you keep climbing."],
		"choices": ["how_first_mark", "how_barrier", "how", "bye"]},
	"how_first_mark": {"ask": "What if I fall before my first mark?",
		"lines": ["The guardian marks you anyway, but faintly: as strong as the floor you reached. Half strength on floor 1, a tenth more each floor up, full on floor 6. A faint mark hits softer and costs more until it has soaked up its debt of essence. The weaker it is, the bigger the debt. Until it's paid, the mark carries the guardian's seal."],
		"choices": ["how_mark_seal", "how_climb", "how_marks", "how", "bye"]},
	"how_mark_seal": {"ask": "The seal on a faint mark?",
		"lines": ["A first mark taken in a fall is faint, and it carries the guardian's seal. While it's still faint, you can break the seal on the train, on your climber screen's Marks tab: it asks first, and once you confirm, it's done. The mark comes away, every mark with it, and you are Unbound, the same as refusing the mark at the Regard. Let the mark soak up its debt and grow to full strength, and the seal is gone, and the choice with it. Nobody will know which you chose. Unless they look closely."],
		"choices": ["how_first_mark", "how_unbound", "how", "bye"]},
	"how_barrier": {"ask": "The gate and the ward on the stair?",
		"lines": ["Every floor, a barrier forms on the stair as you arrive. Floors 1 to 6: an iron gate, shut in 30 seconds; roll under it before then. Floors 7 to 12: a ward of light, up in 15, broken only by this tower's own essence. Slip past or break one and you skip the floor, and the tower sends a horde: 6 for a gate, 12 for a ward. The stair opens when it's down. With no mark, you'd be Unbound for it. Marked, three times in all and a Maker comes to talk."],
		"choices": ["how_climb", "how_ward", "how", "bye"]},
	# Training and tournaments (training.gd, tournaments.gd).
	"how_grace": {"ask": "The Noble's Grace and my first tournament?", "fact": "training",
		"lines": ["Every climber needs the Noble's Grace before a tower will have them. A new climber earns it at home: basic training at the gym, one session of {steps} short steps, then one tournament of {rounds} rounds, monsters and then a champion fighter. The Grace comes win or lose. Each round won adds a reward: a Healing Vial, a recall scroll, then a Fine piece of the kind you fought with most; no damage at all, and a tincture of each essence too. {grace_line}"],
		"choices": ["how_training", "how_manager", "how", "bye"]},
	"how_training": {"ask": "Basic, advanced and mark training?", "fact": "training",
		"lines": ["Basic training: one session of {steps} steps, every move in a row: walking, jumping, rolling, then your weapons in order: your melee weapon and its finisher, your fists, your ranged weapon (a bow's full draw, a pistol's or crossbow's shot), then the off-hand and its power, with a one-handed weapon out (bows and two-handed weapons need both hands), parrying on the glint, blocking, the belt and its wheel. Each step waits for you; I hint if you're stuck, and if you leave, your place is kept. Any time, free. Its essence, and your first tournament's, goes into your body only, {quarter} of the usual: it shows which part you use most, so where your first mark will be. Advanced training opens in {tiers} tiers with the titles the Noble grants you; mark training with your first mark, against dummies, summoned creatures and human rivals. Each try costs a few crystals of the essence that fits it, and pays {half} of the usual essence."],
		"choices": ["how_grace", "how_manager", "how", "bye"]},
	"how_manager": {"ask": "Who is the Tournament Manager?", "fact": "training",
		"lines": ["After your first, tournaments belong to {manager}, who moves round the six stations, a stop after each of your climbs. Each place has its own arena: pillars, hazards, the creatures of the first round, and rivals whose marks lean to its tower. Entry costs a fee. A win pays renown, crystals, essence ({half} of the usual), a Healing Vial anywhere, and the first win of a higher bracket at each place, a prize found only there. {manager_line}"],
		"choices": ["how_tourney", "how_grace", "how", "bye"]},
	"how_fall": {"ask": "What comes home: a fall, a recall, a summit?", "fact": "rules",
		"lines": ["A fall: your pack, what you wear and your belt are lost, unbanked essence too (a Keeper's Purse keeps itself and one piece), and {weapon} of the time the weapon in your hand. Never an heirloom, and the plain sword and bow aren't remembered for a cache: come back with no weapon for a slot and {outfitter} gives you one. A recall scroll: you leave safe with what you wear and your pack, and unbanked essence becomes crystals. A summit: you may keep one piece as an heirloom, and what's left on your belt becomes crystals."],
		"choices": ["how_gift", "how_belt", "how", "bye"]},
	"how_gift": {"ask": "The plain sword and bow?", "fact": "rules",
		"lines": ["You started with a plain sword and shortbow where your past gave no weapon. They're yours like anything else, and nothing puts them back by itself. Fall and come back with no melee weapon, and {outfitter} gives you a plain sword; no ranged weapon, a plain shortbow. One in your stash goes on instead, so they never pile up. Gifts aren't for sale: he never stocks them, and nobody buys them back."],
		"choices": ["how_fall", "how", "bye"]},
	"how_belt": {"ask": "The belt?", "fact": "rules",
		"lines": ["Your belt holds {kinds} kinds of item, {stack} of each (a few stack otherwise; a Belt Pouch, a Climber's Pack or a Belt Hook charm adds a kind). Pick up a new kind with a full belt and you choose a stack to swap out. The staples are the Healing Vial, the Stamina Vial and the Essence Vial: cheap, and common from monsters. Everything else is rare in the tower, a few in a whole climb, so keep it for when it counts; {outfitter} sells them if you want one on purpose. What you buy or brew on the train goes on it."],
		"choices": ["how_wheel", "how_states", "how_fall", "how", "bye"]},
	"how_wheel": {"ask": "How does the belt wheel work?", "fact": "wheel",
		"lines": ["Tap {item} and you use your current item, the one beside your weapon. Hold {item} and the wheel opens, and the world slows to {slow} of its speed. Point at an item with {point} and let go: it becomes your current item. Nothing is used until you tap {item} again. A mark's button works the same way: hold it to choose a spell, tap it to cast. Choosing never uses anything. I find that restful."],
		"choices": ["how_belt", "how", "bye"]},
	"how_states": {"ask": "What are states, and how do I cure them?", "fact": "states",
		"lines": ["Some monsters' blows leave a state on you when they land: {states}. Each lasts a few seconds, and none of them stuns. The line at the top counts it down and names its cure. A Cleansing Tonic takes off any of them; {wards} keep one off for a while. The stair's rest clears them all."],
		"choices": ["how_handy", "how_belt", "how", "bye"]},
	"how_handy": {"ask": "What's handy in this tower?", "fact": "handy",
		"lines": ["{handy} They turn up more often there, though like every item but the staples they're still a rare find; {outfitter}'s shelf says where each is handy, if you'd rather bring one."],
		"choices": ["how_states", "tower", "how", "bye"]},
	"how_charms": {"ask": "How do charms work?", "fact": "rules",
		"lines": ["You wear one charm, in its slot under the others. It's never used up: its gift is on while you wear it. Some hold a charge that fires by itself when its moment comes. Spent, it stays spent until you feed it essence: at the workshop bench with crystals of its kind, or in the tower from the inventory with essence you haven't banked. The Workshop crafts them (with the Rune Artist's mark you craft them yourself; without it, {artist} does it for you); {outfitter} sells {charm_shop}; vaults and secret rooms sometimes hold one."],
		"choices": ["how_workshop", "how_bags", "how", "bye"]},
	"how_workshop": {"ask": "The Workshop and {rune_artist}, its Rune Artist?", "fact": "rules",
		"lines": ["The Workshop's bench has a counter for each kind of work. Brewing, breaking down, tinctures and refilling charms are anyone's. The rest is crafting: tempering, swapping a trait, joining two pieces, a lasting rune, a recall scroll, a vessel, a new charm. With the Rune Artist's mark you craft it yourself with your own essence, and brew for less. Without the mark, {artist} at the bench crafts it for you. You bring the same crystals a Rune Artist would use, plus {artist_premium} on top for the craft, and {artist_work} when a full vessel does the work. Every card says who crafts and what the price is made of."],
		"choices": ["how_charms", "how_exchange", "how", "bye"]},
	"how_offhand": {"ask": "How does the off-hand work?",
		"lines": ["Your off-hand holds a second one-handed weapon, a shield or a wand. A second blade puts its own strike into your chains, just before the finisher. A shield blocks while you keep holding parry after the parry's moment: blows from in front hurt less, and each costs stamina; run dry and the guard breaks. A clean parry still beats a block. A wand casts a small power with the off-hand button. Enchanted ones have their own pool of uses, fed with essence like a charm. Two-handed weapons and bows need both hands: the off-hand waits."],
		"choices": ["how_charms", "how", "bye"]},
	"how_item_pool": {"ask": "Items and their essence?",
		"lines": ["Wands, charms and enchanted weapons each carry a pool of their own essence: the little bar along the top of the slot. A use draws on three sources, in order. First its own pool: a finisher's edge, a bow's full draw, a bolt, a pistol's essence shot, a wand's cast, a charm's charge. Dry, it draws on the essence you carry, what you'd bank at the stair. With neither, the tower seeps a use back into it, slowly. Half a minute or so in a tower of its own essence, twice that elsewhere. One use, then it waits. Until then its essence stays quiet, and a weapon still works plainly.", "You can filter your essence into it. To refill: the inventory, when no monster is after you, or the workshop bench with crystals. To power: hold the off-hand button, and its next use hits harder. A wand casts at once. Beyond the tower's trickle, nothing refills a pool, not even a new climb. What you pour in, you don't bank. Choose."],
		"choices": ["how_charms", "how_offhand", "how", "bye"]},
	"how_gear": {"ask": "How do weapons and rarities work?",
		"lines": ["Every weapon has its own way. A dagger bites deeper from behind, a sword gives breath back on a finisher, maces and hammers rock what they hit, a cane lengthens your parry. A rapier makes ripostes and backstabs bite deeper; a flail's chain goes through guards and shells; a sling's full whirl rocks a foe, though its stone never pierces. Finer pieces carry traits: Fine one, Rare two, Masterwork three. Masterwork only turns up from the tenth floor, and seldom. Storied pieces and the beasts' Regarded ones keep their own names and rules."],
		"choices": ["how_offhand", "how", "bye"]},
	"how_summit": {"ask": "What are Summit Blades?",
		"lines": ["One blade hides in each tower, on one floor. Look closely, or follow a lead from a vault: then its glint shows from afar. Take it up and carry it to the summit, and it's bonded to you for good; fall and it goes back to its hiding place. You carry one at your hip, and its power fires by itself, on a finisher or a perfect parry. Awaken it on the train with crystals of its tower, one step between climbs. Six steps. Slowly."],
		"choices": ["how_deeds", "how", "bye"]},
	"how_deeds": {"ask": "What are deeds?",
		"lines": ["Thirty-six things worth doing, six of each kind: battle, climbing, marks and essence, stations, collecting, daring. Each pays a little renown, 1 to 6, about 120 for the lot. Your book's Deeds ribbon lists them, and how far along you are. You don't claim them: I notice."],
		"choices": ["how_renown", "how", "bye"]},
	"how_bags": {"ask": "How do bags work?", "fact": "rules",
		"lines": ["Your bag sets how many spare pieces your pack holds: {bag_none} with none, {bag_sizes}. Small bags never slow you. A big one does once it's nearly full, {heavy_at} of its spaces or more, and the pack's heading says \"heavy\". Lighten it and you're quick again."],
		"choices": ["how_shop", "how_charms", "how", "bye"]},
	"how_shop": {"ask": "How does the shop change?", "fact": "rules",
		"lines": ["His stock follows your rank: that's the trunk of his upgrade tree. Higher up: more on his rail (up to {rail_most}, all shown at once), more kinds on the shelf (up to {kinds_most}), more Fine and Rare pieces, pistols and crossbows from {gun_rank}, now and then a named piece or a relic. It's new every visit. The title you wear tilts his rail, and some titles take a little off. The rest you buy on his tree. Never a plain sword or shortbow: he gives those to climbers who come back from a fall without one, and won't buy them back. Everyday goods, everything on his shelf but tinctures, take crystals of any kind, your fullest first; gear and charms want their own kind."],
		"choices": ["how_shop_tree", "how_exchange", "how_renown", "how_gift", "how", "bye"]},
	"how_exchange": {"ask": "Crystals I can't use, and the Exchange?", "fact": "rules",
		"lines": ["First, spend them: everyday goods on {outfitter}'s shelf, the vials, tonics, bombs and scrolls, take crystals of any kind, the kinds you hold most of first. Gear, charms and the bench's work want their own kind. For those there's the Workshop's Exchange: choose a crystal to give, then on its card the kind to get and how much, {x_steps} at a time or All. {rune_artist}, the Rune Artist, recasts every {x_give} you give into {x_get} of the kind you chose, whole lots only: {x_lost} is lost in the working, so the kinds keep their worth. A trade of {x_big} or more asks first. Nothing bought with any kind sells back for more than it cost, so don't look for a way round it. I did."],
		"choices": ["how_shop", "how_workshop", "how", "bye"]},
	"how_shop_tree": {"ask": "How does his upgrade tree work?", "fact": "rules",
		"lines": ["Your rank is the trunk; four branches grow from it: Prices, Stock, Gifts, Info. A node opens at its rank once the one below it is yours; {tree_titled} also need a title from the Noble. Buy it with crystals of any kind and it's yours for good; there are {tree_total} in all. Discounts from the tree and your worn title stop at {tree_cap} off. Choose a node and its card says what it does. On a wide screen the Upgrades sign under {outfitter} folds the tree away, to give him room, or opens it again; the car remembers which."],
		"choices": ["how_shop", "how_renown", "how", "bye"]},
	"how_ward": {"ask": "Why won't the stair open?",
		"lines": ["Most floors have one task, and the stair is warded until it's done: braziers, levers, runes, an orb, marked creatures, rifts, urns, a lost wisp, a puzzle. The banner names it, a line under it counts it, and an arrow points at what's left. Done, the stair opens, and a reliquary beside it offers one of three."],
		"choices": ["how_secret", "how", "bye"]},
	"how_secret": {"ask": "Cracked walls and secret rooms?",
		"lines": ["Dust falls from a cracked wall. A finishing blow breaks it: a way through, hidden essence, sometimes a vault. A secret room hides behind plain wall: lean into it, or break it with a finishing blow, and a portal opens to a pocket dimension, a room outside the floor with a vault of three chests. Flare Powder and the Scroll of Seeing make secret walls glint."],
		"choices": ["how_portals", "how_ward", "how", "bye"]},
	"how_portals": {"ask": "Portals, pockets and the floor map?",
		"lines": ["A floor's portals sleep until you finish a challenge there (its task, a sealed wing, the gallery's puzzle) or slay everything on it; then they all wake. Step onto one and the map opens: choose another and you step out of it. Same floor only, and none on floor 6, where the tower takes your measure. A pocket dimension is a room outside the floor, through a hidden wall's portal: three chests, one with better gear, some chained until you pay a Tithe Stone, step its runes in order or beat its Keeper. The floor waits while you're there. The map is O, or Floor map in the pause menu, or Map on a phone."],
		"choices": ["how_secret", "how", "bye"]},
	"how_vessel": {"ask": "What's a vessel for?", "fact": "rules",
		"lines": ["Essence crystallizes the moment it leaves a tower, and crystals must be broken down again before they're any use. Most is lost. A vessel keeps essence raw: {vessel_cap} of one kind. Empty, set it to catch raw essence, and at each stair it takes {vessel_share} of what you'd bank of its kind, until it's full. That isn't banked: it won't grow you or make crystals. Or set it to catch core essence, the one that isn't your path, from great foes. Core essence never crystallizes at all: a vessel is the only way to carry it. Fall and it's lost; get out alive and it comes home to your stash. Raw essence makes tinctures at the bench, {vessel_per} for one against {craft} crystals. A full vessel of core essence powers a core rune for {core_floors} floors, or work past the bench's limits, or an offering to a Maker. And the cities run on raw essence: now and then a Noble asks for a full vessel, and pays in renown and a piece from the city's stores. {outfitter} doesn't buy them."],
		"choices": ["how_tinctures", "how_aura", "how_contracts", "how", "bye"]},
	"how_aura": {"ask": "Core essence, and my aura?", "fact": "rules",
		"lines": ["Making and Unmaking are the core essences, the Makers' own. Choose one and, banked at a stair, half of what you carried settles in your body as core essence: slowly, evenly over your six parts, {core_cap} a part at most. It can't be moved. Your aura is that core essence made visible, and it grows in six steps, at {aura_steps}. Marked or Unbound, each step gives you more. Once every part is full your body is saturated, and nothing more settles. What comes after that, I'll tell you when it's time. It changes you, too, and people notice: with each step, Nobles, the climbers in the Dining car and the rivals in the towers speak to you differently. Making draws them near. Unmaking makes them give way."],
		"choices": ["how_unbound", "how", "bye"]},
	"how_passing": {"ask": "Passing as marked in the cities?", "if": "unbound",
		"lines": ["In the cities the Unbound are a rumour, outlaws where they're known, so you pass as marked. Each visit to a station, between two climbs, someone might look closer: a small chance, growing with your biggest Node's level and your aura's step. Found out, the station turns on you for that visit. The Noble grants no titles or contracts, the fees there cost more, and a rumour spreads that rivals repeat for a few climbs. That's all. Next climb, you pass again."],
		"choices": ["how_unbound", "how_aura", "how", "bye"]},
	"how_unbound": {"ask": "How do the Unbound grow?", "if": "unbound", "fact": "rules",
		"lines": ["Your six body parts are Nodes. Each starts asleep. The essence you bank flows to its natural Node and soaks in, and when enough has soaked in, the Node wakes. Your first wakes after about a climb; the others take a few each, sooner if you route essence to them. Awake, a Node grows by use. What its techniques spend comes back at the stair from the essence you bank into it, and that stretches it a little: slower the bigger it is. Casting more than you bank adds nothing: what you bank, and the strain of pushing your techniques, set the pace. A Node refills best from its own kinds, its natural essence and the essence that leads it; any other kind, routed there or flowing on from a sealed Node, refills only a third as much, the same rule as for marks. A Node wakes at level {ub_minor}, with a minor ability, and grows to level 12 at size {core_cap}: level {ub_tech} brings a young technique (one form, its lead essence only, weaker), {ub_gift} a gift, {ub_full} the full technique, 12 the capstone. One Node to the top takes many climbs; all six, far more."],
		"choices": ["how_nodes", "how_sealing", "how_drain", "how_forcing", "how_unbound_words", "how_aura", "how", "bye"]},
	"how_sealing": {"ask": "Sealing a Node?", "if": "unbound",
		"lines": ["On the train, on your climber screen's Body tab, you can seal a Node. A sealed Node takes no essence: what would pool there flows on to your biggest open Node, where it refills only a third as much as the Node's own kind would. Sealing gives the Node up: what it holds becomes crystals, and its size, technique, gift, minor ability and attributes are gone. In return each sealed Node makes your open Nodes grow faster from use and hit harder. One Node always stays open, and Seal asks first (Confirm or Cancel). You can unseal a Node later, on the train, but it starts again asleep, at size 0. The marked can't do this: it's the Unbound's choice. Focus trades breadth for depth, not speed."],
		"choices": ["how_nodes", "how_unbound", "how", "bye"]},
	"how_drain": {"ask": "What happens when I fall?", "if": "unbound", "fact": "rules",
		"lines": ["The guardians hunt the Unbound. Fall, after your first climb, and you're caught: {drain_share} of what each Node holds drains back into the well. Lost, not crystals. Each Node keeps a trace of the essence that leads it, so your techniques stay yours, and the sizes, the levels and your core essence aren't touched. The next stairs fill your Nodes again before they refill your use, so you grow a little slower for a climb. The fall screen says how much went. And now and then, {rescue_odds} falls, once a climb at most, one of the Sworn steps in first. Climbers say the husks on the stairs were Unbound once, drained until nothing came back."],
		"choices": ["how_sworn", "how_unbound", "how", "bye"]},
	"how_sworn": {"ask": "Who are the Sworn?", "if": "sworn_known", "fact": "rules",
		"lines": ["Climbers who took a Maker's secret bond: a good answer when one shows itself, and its core mark. That makes you one of its Sworn, and your climber screen says whose. Now and then, {send_odds} climbs, it sends you somewhere: a floor of a tower it names. Reach it in any climb and it pays {send_reward} crystals of that tower's essence. One errand at a time. The Makers fear the Unbound and admire them, so they send their Sworn to stop the guardians catching them: {rescue_odds} falls, once a climb at most, one steps in before the drain."],
		"choices": ["how_drain", "how", "bye"]},
	"how_nodes": {"ask": "What are Nodes?", "if": "unbound", "fact": "rules",
		"lines": ["A Node is one of your six body parts, the Unbound's way: the Hand, Legs, Heart, Brow, Throat and Back Nodes. An awake Node has two numbers. What it holds: the essence that powers its techniques; the first essence in it leads, two more at most add their touch, and you can move it between Nodes on your climber screen's Body tab, for a quarter. And its size, its density: how much it can hold, {core_cap} at most. Moving never changes a size; only use does. Your Nodes' sizes give your attributes, each Node counting for the essences it holds. A sleeping Node holds nothing and shows no numbers."],
		"choices": ["how_unbound", "how_unbound_words", "how", "bye"]},
	"how_unbound_words": {"ask": "Forms, effects, techniques?", "if": "unbound",
		"lines": ["A form is the shape a part gives: the hand strikes or throws a bolt, the legs dash or leap. An effect is what an essence does to what it hits: Fire burns, Stone staggers. A technique is the two together: a strike and a burn, Flame Fist. A variation is a small change on top: Wide, Quick, Chain. Your Node's essence chooses the effects. You choose the form, each essence's effect and the variation, on your climber screen's Techniques tab."],
		"choices": ["how_unbound_techniques", "how_unbound", "how", "bye"]},
	"how_unbound_techniques": {"ask": "The Techniques tab?", "if": "unbound",
		"lines": ["Your climber screen's Techniques tab holds all six. Choose a Node along the top. Its card says what its technique does, in plain words, and draws it in a glass globe: the form inside, the Node's essences poured in, the variation on its spout, and a dial for the strain one cast adds. Under it: Form, an Effect for each essence, a Variation, its name, Boost, and where each kind of banked essence flows. Every press changes the technique at once, so nothing is ever lost. You can look anywhere, but you change techniques only on the train, between climbs. The essences themselves are the Node's own: move them on the Body tab. Under them, what each Node's minor ability and gift do."],
		"choices": ["how_unbound_words", "how_unbound", "how", "bye"]},
	"how_bestiary": {"ask": "What is the Bestiary?", "fact": "rules",
		"lines": ["My notes on every monster, in the Library. An entry starts when you see one and grows when you fight it. Slay it {bestiary_slain} times and it adds its health, then what it's weak to, then how it takes states. A beast takes {bestiary_beast}."],
		"choices": ["how_secret", "how", "bye"]},
	"how_rivals": {"ask": "Who are the other climbers?", "fact": "rivals",
		"lines": ["Climbers like you, with marks of their own. From floor {rival_from}, about {rival_chance} of floors hold one, up to {rival_per} a climb, never the same one twice in a climb; if you've never met one, you will by floor {rival_sure}. Each wants one thing: a trade, a duel for the floor, company to the stair. Some lie hurt beside a hoard. {rival_met}"],
		"choices": ["how_rivals_more", "how", "bye"]},
	"how_rivals_more": {"ask": "What do I get from them?", "fact": "rivals",
		"lines": ["A duel can't kill you: lose and they take a toll, win and the stair's ward lifts. Teamed up, you keep {rival_share} of what you gather, but their marks react with yours. Help the hurt and they remember; rob them and so do they. The Renown Board keeps them all."],
		"choices": ["how_rivals", "how", "bye"]},
	"how_dining": {"ask": "What's the Dining car?", "fact": "dining",
		"lines": ["A car of other climbers, {dine_seats} a visit: mostly ones you've met, a new face or two. Tap one and pick a line: a rumor (always true), a wager, a trade, a duel. They remember what you did up there. Robbed them? They're cold. Helped them? A small gift, better odds. {dine_met}"],
		"choices": ["how_bets", "how_duels", "how_rivals", "how", "bye"]},
	"how_bets": {"ask": "How do bets work?", "fact": "dining",
		"lines": ["A climber offers two wagers on your next climb, in the tower on the Engine's board. Stake {dine_stakes} crystals, your biggest first; up to {dine_bets} at once. When the climb ends, however it ends, a win pays the stake times the odds, {dine_odds}, in the tower's essence. Climb somewhere else and it's off: your stake comes back. {dine_open}"],
		"choices": ["how_duels", "how_dining", "how", "bye"]},
	"how_duels": {"ask": "How do duels work?", "fact": "dining",
		"lines": ["Challenge a climber in the Dining car and name the stake: {dine_crystals} crystals, a piece of gear against one of theirs, or {dine_renown} renown. It's fought in the Arena car, the only way in. First to yield loses; nobody dies. Win and you take their stake and {dine_win} renown, and it counts for the Duelist. Lose and they take yours. Then back to your table."],
		"choices": ["how_bets", "how_dining", "how", "bye"]},
	"how_ways_down": {"ask": "Holes, whirlpools and other ways down?",
		"lines": ["Every hole takes you down a floor, unhurt: your unbanked essence comes too, and never below the first floor. Each tower has its own. The Firebird's chasms and the Gryphon's drops; the Kraken's whirlpools, which spin up over a floor drain as the water runs out and pull you in; the Manticore's sinkholes, sand that sags when you stand on it, then opens; the Wyvern's slag chutes, slopes you slide down; the Chimera's root hollows. A hole is a dark pit with a lit rim, never a doorway. Walk onto an edge and you wobble: step back quickly. Roll in, or get thrown, and down you go. A jump carries you over."],
		"choices": ["how_fall", "how", "bye"]},
	"how_guardians": {"ask": "Do the guardians know each other?",
		"lines": ["They do. Six towers, six guardians, and they talk when one of them falls. I can't tell you what they say; I don't hear it all. If the next one seems to know you before you've met, ask around. Climbers on the train and on the stairs hear more than I do, and the Noble hears everything."],
		"choices": ["how_bestiary", "how", "bye"]},
	"how_plea": {"ask": "The Makers' plea?", "if": "story_plea",
		"lines": ["When the third guardian falls, three wells run wild, and the Makers meet you together after that summit. They ask you to stop. Three cards: I'll stop, I'll go on, or Tell me what you were; they tell it, and that card becomes Say nothing. Hover a card, or tap it once, and I'll tell you what I think of it. Stopping locks nothing: you can still climb, and they'll remember you said it. Each answer moves how each Maker sees you: the Maker of Marks likes order, the Maker of Creatures likes you going on, the Maker of Towers is torn."],
		"choices": ["how_final", "how_sworn", "how", "bye"]},
	"how_final": {"ask": "The last choice?", "if": "story_final",
		"lines": ["When all six guardians have fallen, the Makers meet you after that summit, and for the first time they see me. Ascend: become a Maker, holding Making and Unmaking together; if you carry a Maker's secret bond, you take that Maker's place. Fight: my war, with the Summit Blades, and the wells stay wild. Or Not yet: they wait for your next summit. Ascend and Fight ask for a second press. Then the ending, a title, and you go on climbing as you are."],
		"choices": ["how_plea", "how_wild", "how", "bye"]},
	"how_wild": {"ask": "Wild towers?", "fact": "wild",
		"lines": ["When a tower's guardian falls, its well runs wild. The tower stays open, but stranger. Every {storm_gap} seconds or so a storm gathers: rings light up on the floor, one under you, and strike {storm_warn} seconds later. Roll or step out; they strike monsters too, so lure them in. Its monsters have {wild_hp} and {wild_dmg}; its finds are a little richer, about {wild_essence} more essence from a kill and likelier gear. {wild_you} The engine's map marks every wild tower. {wild_count} Each one that runs wild loosens something in the world. Others will tell you more than I can."],
		"choices": ["how_guardians", "how_burns", "how", "bye"]},
	"how_foes": {"ask": "Monsters that work together?",
		"lines": ["Some help the rest. A bellringer's bell quickens every monster it reaches: catch it first. A rookery hatches bats until it's broken. A stormstone strikes whoever stands nearest, so let them stand nearer. A stoker feeds the fires; slay it and they die down. And a husk reads your rhythm: three blows on one beat and it parries the next. Wait a beat. The Bestiary keeps the rest."],
		"choices": ["how_bestiary", "how", "bye"]},
	"how_glows": {"ask": "What are the glows and sparks?",
		"lines": ["A Fine or Rare weapon is enchanted: it glows in its essence, carries a small light, and throws specks that suit it. Embers for fire, drips for water, wisps for air; sparks on a blow for iron, grit for stone, a shimmer on a swing for blade. A Common one stays plain. Spells flash a light where you cast and carry some as they fly. Foes that burn, bleed or crackle show it. Settings has Effects: Low keeps the lights and little else."],
		"choices": ["how_wheel", "how", "bye"]},
	# --- the tower ----------------------------------------------------------------------
	"tower": {"ask": "What is {tower} like?", "fact": "tower",
		"lines": ["{blurb} Its essence is {essence}. {best_line}"],
		"choices": ["tower_beast", "tower_hazards", "how_handy", "start", "bye"]},
	"tower_beast": {"ask": "And its beast?", "fact": "tower",
		"lines": ["{Beast} waits at the top. {beast_hint} {slain_line}"],
		"choices": ["tower_hazards", "start", "bye"]},
	"tower_hazards": {"ask": "What should I watch for there?", "fact": "hazards",
		"lines": ["{hazards}"],
		"choices": ["tower_beast", "start", "bye"]},
	# --- marks ----------------------------------------------------------------------------
	"marks": {"ask": "What do my marks do?", "if": "marked", "fact": "marks",
		"lines": ["As I have them. {marks}"],
		"choices": ["marks_grow", "marks_new", "start", "bye"]},
	"marks_grow": {"ask": "How do marks grow?", "fact": "money",
		"lines": ["By use, refilled from essence you bank at a stair: {marks} of it goes to your marks, refilling what each one's spells used and deepening it. A mark you never cast barely grows. {condense} becomes crystals. A tincture puts its essence into the one mark you choose."],
		"choices": ["marks_new", "start", "bye"]},
	"marks_new": {"ask": "Will I get another mark?", "fact": "soak",
		"lines": ["{soak}"],
		"choices": ["marks_grow", "start", "bye"]},
	"body": {"ask": "What about my body?", "if": "unbound",
		"lines": ["You carry no marks. You refused them. Your parts fill like cups instead, and a part half full carries a technique on its mark button. Your climber screen's Body tab shows each part and moves essence between them."],
		"choices": ["how_unbound", "how_unbound_words", "start", "bye"]},
	# --- the climb ------------------------------------------------------------------------
	"climb": {"ask": "How did my last climb go?", "if": "climbed", "fact": "climb",
		"lines": ["{summary}"],
		"choices": ["climb_log", "start", "bye"]},
	"this_climb": {"ask": "How is this climb going?", "if": "in_play", "fact": "climb",
		"lines": ["{summary}"],
		"choices": ["climb_log", "start", "bye"]},
	"climb_log": {"ask": "What happened last?", "if": "logged", "fact": "climb",
		"lines": ["Newest first. {events}"],
		"choices": ["start", "bye"]},
	# --- the train ------------------------------------------------------------------------
	"train": {"ask": "Tell me about the train.", "if": "on_train",
		"lines": ["Six cars. The Engine takes you to a tower. {outfitter} buys and sells. Your car holds what you'll wear, your pack and your stash. The Workshop works on gear, the Library keeps my words, and the last car holds the settings."],
		"choices": ["train_money", "train_carry", "start", "bye"]},
	"train_money": {"ask": "How do I pay for things?", "fact": "money",
		"lines": ["Crystals. You hold {crystals} essence in them. {condense} of what you bank at a stair condenses into them, and {outfitter} pays for every climb, fall or not. Spend them, craft tinctures from them, or eat them: your book's Crystals and tinctures."],
		"choices": ["train_carry", "start", "bye"]},
	"tour": {"ask": "Show me around again.", "if": "on_train",
		"lines": ["Which part? Skip the tour whenever you like.", "The station, or the train? I don't mind repeating myself."],
		"choices": ["tour_station", "tour_train", "how_travel", "start", "bye"]},
	"tour_station": {"ask": "The station.", "leave": true, "act": "tour:station"},
	"tour_train": {"ask": "The train.", "leave": true, "act": "tour:train"},
	"train_carry": {"ask": "What goes up the tower with me?",
		"lines": ["What you wear, your pack and your belt. The stash never leaves the train. A fall takes your pack and your belt, and sometimes the weapon in your hand. Never an heirloom."],
		"choices": ["train_money", "start", "bye"]},
	# --- story slots: the owner's to write (hidden while they say STORY_TAG) ----------------
	"who": {"ask": "Who are you?",
		"lines": ["[Yours to write] The Entity's answer to \"Who are you?\". Write it over this line, here or in the Data editor."],
		"choices": ["start", "bye"]},
	"why": {"ask": "What are the towers for?",
		"lines": ["[Yours to write] The Entity's answer to \"What are the towers for?\". Write it over this line, here or in the Data editor."],
		"choices": ["start", "bye"]},
	# --- leaving --------------------------------------------------------------------------
	"bye": {"ask": "Goodbye.", "leave": true},
}))

## Hints for "What should I do next?", in the order they're thought of: the
## first that applies is said, the next one if you ask again. {blanks} as
## the hint needs.
static var HINTS: Dictionary = OutfitterName.named({
	"unbanked": "You carry {amount} unbanked essence. Find the stair before something finds you.",
	"low_health": "You're low. A Healing Vial, a spring, or the stair.",
	"faint": "Your mark is faint. It needs {amount} more banked essence before it grows.",
	"mark_ready": "Your {part} is full of essence. Reach a summit and it takes a mark, or win a sealed wing early keeping its rule.",
	"better_stash": "Something you keep beats what you'd wear: {piece}. The Loadout puts it on.",
	"belt_empty": "Your belt is empty. {outfitter} sells vials. The Workshop brews them cheaper.",
	"afford_rack": "You can afford {piece} on {outfitter}'s rack, and it beats yours.",
	"stash_full": "Your stash is full. Sell to {outfitter}, or break pieces down at the Workshop.",
	"title_ready": "The Noble at a station would grant you a title: {title}. Read what it gives.",
	"lessons": "A station's Training has basic training, one session you haven't finished: {n} short steps left, and I talk you through each.",
	"mark_close": "{mark} feels nearly deep enough for step {step}. Cast it, and bank at a stair.",
	"climb": "Choose a tower at the Engine and pull the lever. Your best: floor {best}, in {tower}.",
	"climb_play": "Up. The stair is somewhere on this floor.",
	"none": "Nothing else. Climb.",
})

## The rest of its words in a talk.
static var TEXT: Dictionary = OutfitterName.named({
	"more": "Something else...",
	"rivals_none": "You haven't met one yet.",
	"dining_met": "You've met {n} so far.",
	"dining_open": "You have {n} open now.",
	"dining_none": "You have none open.",
	"rivals_met": "You've met %d. The last was %s.",
	"leave_key": "%s to leave",
	"more_line": "There's more. Pick one.",
	"back": "Back.",
	"best": "Your best there: floor %d.",
	"best_none": "You haven't climbed it yet.",
	"slain": "You've felled it %s.",
	"slain_none": "You haven't felled it yet.",
	"once": "once",
	"times": "%d times",
	"mark": "{mark} on your {part}, step {step}: {body}.",
	"mark_next": "It feels {feel} for step {next}{brings}.",
	"mark_brings": ", which brings {spell}",
	"mark_top": "It has grown as far as it goes.",
	"mark_faint": "It's faint: it must take in more essence before it grows.",
	"mark_dark": "It burned out and is dark: {dark}.",
	"soak_part": "Your {part} is {pct}% full. When a part is full, a summit can mark it, or a sealed wing won early. One new mark a climb, at most.",
	"soak_ready": "Your {part} is full. Reach a summit and it takes a mark, or win a sealed wing early keeping its rule.",
	"soak_none": "Every part already carries a mark.",
	"soak_empty": "Not yet. Your body's share of what you bank soaks into your unmarked parts. A full one can be marked at a summit.",
	"summary": "{Tower}: you reached floor {floor}. {gathered}{finds}{banked}{pay}",
	"gathered": "{n} essence gathered. ",
	"finds": "{n} finds. ",
	"banked": "Banked at {n} stairs. ",
	"pay": "{outfitter} paid {pay}.",
	"summary_none": "Your last climb was in {tower}. I kept the count, not the details. {best_line}",
	"summary_empty": "Nothing yet. Do something.",
	"events_none": "Nothing worth writing down.",
	"hazards_none": "Nothing I'd warn you about.",
})


# --- a conversation ---------------------------------------------------------------------

var node := "start"
var line := ""  # what the Entity is saying (kept while the page rebuilds)
var offset := 0  # how far down the choices we've paged ("Something else")
var said := 0  # lines said (tests)
var act := ""  # what the last choice asked for as it ended the talk ("tour:station"...: menu.gd does it)


## Starts again at the first question.
func begin(main) -> void:
	node = "start"
	offset = 0
	act = ""
	say(main)


## Picks the Entity's line for the node it's at.
func say(main) -> void:
	line = line_for(main, node)
	said += 1


## The Entity's line for a node, filled in.
static func line_for(main, id: String) -> String:
	var n: Dictionary = DIALOGUE.get(id, {})
	var lines: Array = spoken(n)
	if lines.is_empty():
		return ""
	var text := String(lines[randi() % lines.size()])
	return fill(text, facts(main, n))


## A node's lines a player may hear (story slots not written yet are left out).
static func spoken(n: Dictionary) -> Array:
	return Array(n.get("lines", [])).filter(func(l): return String(l).strip_edges() != "" and not String(l).begins_with(STORY_TAG))


## The fills for a node: its fact, and the words of the moment.
static func facts(main, n: Dictionary) -> Dictionary:
	var f := {}
	var fact := String(n.get("fact", ""))
	match fact:
		"tower":
			f = _fact_tower(main)
		"hazards":
			f = _fact_hazards(main)
		"marks":
			f = _fact_marks(main)
		"soak":
			f = _fact_soak(main)
		"money":
			f = _fact_money(main)
		"next":
			f = _fact_next(main)
		"next_more":
			f = _fact_next_more(main)
		"climb":
			f = _fact_climb(main)
		"rules":
			f = _fact_rules()
		"wheel":
			f = _fact_wheel(main)
		"states":
			f = _fact_states()
		"handy":
			f = _fact_handy(main)
		"rivals":
			f = _fact_rivals(main)
		"titles":
			f = _fact_titles(main)
		"dining":
			f = _fact_dining(main)
		"travel":
			f = load("res://scripts/travel.gd").talk_facts(main.profile if main != null else null)
		"controls":
			f = _fact_controls(main)
		"start":
			f = _fact_start(main)
		"training":
			f = load("res://scripts/training.gd").talk_facts(main.profile if main != null else null)
		"wild":
			f = load("res://scripts/wild_towers.gd").talk_facts(main.profile if main != null else null)
	if main != null:
		f["floor"] = f.get("floor", main.get("floor_num"))
	return f


static func fill(text: String, f: Dictionary) -> String:
	text = Entity.fill_words(text, f)
	var re := RegEx.create_from_string("\\{[A-Za-z_]+\\}")
	text = re.sub(text, "", true)
	while text.contains("  "):
		text = text.replace("  ", " ")
	return text.replace(" .", ".").strip_edges()


## True if a choice to this node shows now: its condition holds and it has
## something to say (or it leaves).
static func shows(main, id: String) -> bool:
	var n: Dictionary = DIALOGUE.get(id, {})
	if n.is_empty():
		return false
	var cond := String(n.get("if", ""))
	if cond != "" and not check(main, cond):
		return false
	return bool(n.get("leave", false)) or not spoken(n).is_empty()


## The choices showing now: [{id, ask}], paged (at most MAX_CHOICES).
func choices(main) -> Array:
	var n: Dictionary = DIALOGUE.get(node, {})
	var topics: Array = []
	var leaves: Array = []
	for id in n.get("choices", []):
		id = String(id)
		if id == node or not shows(main, id):
			continue
		var c := {"id": id, "ask": fill(String(DIALOGUE[id].get("ask", id)), facts(main, DIALOGUE[id]) if String(DIALOGUE[id].get("ask", "")).contains("{") else {})}
		(leaves if bool(DIALOGUE[id].get("leave", false)) else topics).append(c)
	var room := MAX_CHOICES - leaves.size()
	var out: Array = []
	if offset > 0:
		room -= 1
	if topics.size() - offset > room:
		out = topics.slice(offset, offset + room - 1)
		out.append({"id": "+more", "ask": String(TEXT["more"])})
	else:
		out = topics.slice(offset)
	if offset > 0:
		out.append({"id": "+back", "ask": String(TEXT["back"])})
	return out + leaves


## Chooses one of the choices showing. False if it ends the talk.
func choose(main, i: int) -> bool:
	var list := choices(main)
	if i < 0 or i >= list.size():
		return true
	var id := String(list[i]["id"])
	match id:
		"+more":
			offset += list.filter(func(c): return not String(c["id"]).begins_with("+") and not bool(DIALOGUE.get(c["id"], {}).get("leave", false))).size()
			line = String(TEXT["more_line"])
			return true
		"+back":
			offset = 0
			say(main)
			return true
	if bool(DIALOGUE.get(id, {}).get("leave", false)):
		act = String(DIALOGUE[id].get("act", ""))
		return false
	node = id
	offset = 0
	say(main)
	return true


# --- conditions ---------------------------------------------------------------------------

static func check(main, cond: String) -> bool:
	if main == null:
		return false
	var prof = main.profile
	match cond:
		"on_train":
			return bool(main.on_train)
		"in_play":
			return not bool(main.on_train)
		"marked":
			return prof != null and not prof.bonds.is_empty() and not Unbound.is_on(prof)
		"unbound":
			return prof != null and Unbound.is_on(prof)
		"grown":
			# (a mark or an Unbound's Nodes: what forcing works on, forcing.gd)
			return prof != null and (not prof.bonds.is_empty() or Unbound.is_on(prof))
		"sworn_known":
			# (the Sworn: one of them, a Maker met, or an Unbound one of them has saved)
			var Sworn = load("res://scripts/sworn.gd")
			return prof != null and (Sworn.is_sworn(prof) or load("res://scripts/makers.gd").has_met(prof) or (Unbound.is_on(prof) and int(Sworn.state(prof).get("rescued", 0)) > 0))
		"climbed":
			return bool(main.on_train) and prof != null and prof.climbs > 0
		"story_plea":
			# (the Makers' plea seen or due: story_scenes.gd)
			var S = load("res://scripts/story_scenes.gd")
			return prof != null and (S.state(prof).has("plea") or S.plea_due(prof))
		"story_final":
			# (all six guardians beaten, or the final meeting's choice made)
			var S2 = load("res://scripts/story_scenes.gd")
			return prof != null and (S2.choice(prof) != "" or prof.count("ending") > 0 or (main.has_method("guardians_beaten") and main.guardians_beaten() >= Towers.ORDER.size()))
		"logged":
			return not _log(main).is_empty()
	return true


# --- facts: the game as it is now -----------------------------------------------------------

## A chance as words: "about 1 in 6".
static func _odds(p: float) -> String:
	if p <= 0.0:
		return "never"
	return "about 1 in %d" % maxi(1, int(round(1.0 / p)))

## The tower talked about: the one you're in, or on the train the one chosen
## at the engine (else the last one climbed).
static func tower_id(main) -> String:
	if main == null:
		return Towers.ORDER[0]
	if not bool(main.on_train) and Towers.TOWERS.has(String(main.tower)):
		return String(main.tower)
	var m = main.get("menu")
	if m != null and Towers.TOWERS.has(String(m.train_tower)):
		return String(m.train_tower)
	var prof = main.profile
	return String(prof.last_tower) if prof != null and Towers.TOWERS.has(String(prof.last_tower)) else Towers.ORDER[0]


## "The Kraken's Tower" said mid-sentence: "the Kraken's Tower" ({Tower}
## puts the capital back).
static func _the(name: String) -> String:
	return "the" + name.substr(3) if name.begins_with("The ") else name


static func _best(main, id: String) -> int:
	var prof = main.profile if main != null else null
	return int(prof.record.get("best", {}).get(id, 0)) if prof != null else 0


static func _fact_tower(main) -> Dictionary:
	var id := tower_id(main)
	var t: Dictionary = Towers.TOWERS.get(id, {})
	var best := _best(main, id)
	var prof = main.profile if main != null else null
	var slain := int(prof.record.get("beasts_by", {}).get(id, 0)) if prof != null else 0
	return {
		"tower": _the(String(t.get("name", id))),
		"blurb": String(t.get("blurb", "")),
		"essence": Essence.display(String(t.get("essence", ""))),
		"beast": String(t.get("beast", "")),
		"beast_hint": String(t.get("beast_hint", "")),
		"best_line": String(TEXT["best"]) % best if best > 0 else String(TEXT["best_none"]),
		"slain_line": String(TEXT["slain_none"]) if slain <= 0 else String(TEXT["slain"]) % (String(TEXT["once"]) if slain == 1 else String(TEXT["times"]) % slain),
	}


## What to watch for in the tower: its own tidbits (entity_notes.gd), the
## tower's line and one of each of its systems, at most three.
static func _fact_hazards(main) -> Dictionary:
	var id := tower_id(main)
	var f := _fact_tower(main)
	var said: Array = []
	for k in Notes.arrival_keys(id):
		var lines: Array = Notes.lines(String(k))
		if not lines.is_empty():
			said.append(String(lines[0]))
		if said.size() >= 3:
			break
	f["hazards"] = " ".join(said) if not said.is_empty() else String(TEXT["hazards_none"])
	return f


## Your marks: each one's name, part, step, its body gift, and its next step.
static func _fact_marks(main) -> Dictionary:
	var prof = main.profile if main != null else null
	if prof == null:
		return {}
	var parts: Array = []
	for part in Bonds.PART_NAMES:
		if not prof.bonds.has(part):
			continue
		var info: Dictionary = prof.bonds[part]
		var bd: Dictionary = Bonds.BONDS.get(String(info.get("id", "")), {})
		if bd.is_empty():
			continue
		var xp := float(info.get("xp", 0.0))
		var step := ProfileScript.step_for_xp(xp)
		var body: Dictionary = bd.get("body", {})
		var s := fill(String(TEXT["mark"]), {"mark": bd.get("name", ""), "part": String(Bonds.PART_NAMES[part]).to_lower(), "step": step,
			"body": "%s, %s" % [body.get("name", ""), body.get("desc", "")] if not body.is_empty() else ""})
		if MarkUse.dark(prof, part):
			s += " " + fill(String(TEXT["mark_dark"]), {"dark": MarkUse.dark_words(prof, part)})
		elif bool(info.get("faint", false)) and float(info.get("debt", 0.0)) > 0.0:
			s += " " + String(TEXT["mark_faint"])
		elif step >= ProfileScript.STEP_XP.size():
			s += " " + String(TEXT["mark_top"])
		else:
			var words: Array = MarkUse.TEXT["depth"]
			var feel := String(words[clampi(int(MarkUse.step_fraction(ProfileScript.STEP_XP, xp) * words.size()), 0, words.size() - 1)])
			var spell := ""
			for sp in bd.get("spells", []):
				if int(sp.get("learn", 0)) == step + 1:
					spell = String(sp.get("name", ""))
			var brings := fill(String(TEXT["mark_brings"]), {"spell": spell}) if spell != "" else ""
			s += " " + fill(String(TEXT["mark_next"]), {"next": step + 1, "feel": feel, "brings": brings})
		parts.append(s)
	return {"marks": " ".join(parts)}


## How near an unmarked part is to taking a mark.
static func _fact_soak(main) -> Dictionary:
	var prof = main.profile if main != null else null
	if prof == null:
		return {}
	if prof.bonds.size() >= Bonds.PART_NAMES.size():
		return {"soak": String(TEXT["soak_none"])}
	var ready: String = prof.ready_for_mark()
	if ready != "":
		return {"soak": fill(String(TEXT["soak_ready"]), {"part": String(Bonds.PART_NAMES.get(ready, ready)).to_lower()})}
	var best := ""
	var most := 0.0
	for part in prof.soak:
		if prof.bonds.has(part):
			continue
		if float(prof.soak[part]) > most:
			most = float(prof.soak[part])
			best = String(part)
	if best == "":
		return {"soak": String(TEXT["soak_empty"])}
	var need: float = ProfileScript.NEW_MARK_SOAK * ProfileScript.MARK_FULL
	return {"soak": fill(String(TEXT["soak_part"]), {"part": String(Bonds.PART_NAMES.get(best, best)).to_lower(), "pct": clampi(int(most / maxf(need, 1.0) * 100.0), 0, 99)})}


## Money: your crystals and the share that condenses at a stair.
static func _fact_money(main) -> Dictionary:
	var prof = main.profile if main != null else null
	var share := Train.condense_share()
	var sh: Dictionary = Flow.shares(share)
	return {"crystals": int(prof.crystals_held()) if prof != null else 0, "condense": "%d%%" % int(round(share * 100.0)),
		"body": "%d%%" % int(round(float(sh["body"]) * 100.0)), "marks": "%d%%" % int(round(float(sh["marks"]) * 100.0))}


## The climber's states (reactions.gd CLIMBER) and their cures (items.gd
## "cures", "ward"), read from the tables: "poison from scorplings and the
## Manticore (Antivenom or Cleansing Tonic)".
static func _fact_states() -> Dictionary:
	var R = load("res://scripts/reactions.gd")
	var Items = load("res://scripts/items.gd")
	var Enemy = load("res://scripts/enemy.gd")
	var by := {}
	for kind in R.CLIMBER.get("from", {}):
		var st := String(R.CLIMBER["from"][kind])
		if not by.has(st):
			by[st] = []
		by[st].append(_foe_name(Enemy, String(kind)))
	var parts: Array = []
	for st in R.STATES:
		if not by.has(st):
			continue
		var cure: String = R.cure_names(st)
		parts.append("%s from %s (%s)" % [String(R.STATES[st]["name"]).to_lower(), _and_words(by[st]), cure])
	var wards: Array = []
	for id in Items.ORDER:
		if not Array(Items.ITEMS[id].get("ward", [])).is_empty():
			wards.append(String(Items.ITEMS[id]["name"]))
	return {"states": "; ".join(parts), "wards": _and_words(wards)}


## A monster's name for a sentence: "scorplings", "the Manticore".
static func _foe_name(Enemy, kind: String) -> String:
	if kind in Enemy.BOSSES:
		return "the " + kind.capitalize()
	return kind + "s"


static func _and_words(list: Array) -> String:
	var s: Array = list.map(func(x): return String(x))
	if s.size() < 2:
		return "".join(s)
	return ", ".join(s.slice(0, s.size() - 1)) + " and " + String(s[-1])


## What's handy in the tower talked about (tower_needs.gd), with why.
static func _fact_handy(main) -> Dictionary:
	var Needs = load("res://scripts/tower_needs.gd")
	var Items = load("res://scripts/items.gd")
	var id := tower_id(main)
	var f := _fact_tower(main)
	var bits: Array = []
	for item in Needs.handy(id):
		if Items.ITEMS.has(item):
			bits.append("%s: %s" % [String(Items.ITEMS[item]["name"]), Needs.why(id, item)])
	f["handy"] = String(Needs.TEXT["talk"]) % [f["tower"], "; ".join(bits)] if not bits.is_empty() else String(Needs.TEXT["none"])
	return f


## The game's rules in numbers, read from its own tables (for "How do things work here?").
static func _fact_rules() -> Dictionary:
	var R = load("res://scripts/renown.gd")
	var Lost = load("res://scripts/lost.gd")
	var Items = load("res://scripts/items.gd")
	var ranks: Array = []
	for r in R.RANKS:
		if int(r[2]) > 0:
			ranks.append("%s at %d" % [r[1], int(r[2])])
	var f := _fact_money(null)
	f.merge({
		"deepen": _num(float(MarkUse.USE["deepen"])) + "x", "use_other": "a third" if is_equal_approx(float(MarkUse.USE["other"]), 1.0 / 3.0) else _num(float(MarkUse.USE["other"])) + "x", "dark": int(MarkUse.BURN["dark_climbs"]),
		"own": _num(ProfileScript.AFFINITY_WEIGHT), "other": _num(ProfileScript.OTHER_WEIGHT), "boost": _num(float(Flow.TINCTURE.get("mark_boost", 1.0))), "proving": int(ProfileScript.PROVING_GROWTH), "steps": ProfileScript.STEP_XP.size(),
		"full": "%d%%" % int(round(ProfileScript.MARK_FULL * 100.0)), "faint": int(ProfileScript.FAINT_DEBT),
		"per_floor": int(R.CLIMB.get("floor", 0)), "per_best": int(R.CLIMB.get("best", 0)), "beast": int(R.CLIMB.get("beast", 0)),
		"ranks": ", ".join(ranks), "weapon": "%d%%" % int(round(float(Lost.WEAPON_CHANCE) * 100.0)),
		"kinds": Items.BELT_KINDS, "stack": Items.MAX_STACK,
		"sta_regen": int(round(float(Combat.CLIMBER["stamina_regen"]))), "sta_floor": "%d%%" % int(round(float(Combat.CLIMBER["fatigue_floor"]) * 100.0)),
		"tincture": int(Flow.TINCTURE["essence"]), "craft": int(Flow.TINCTURE["craft"]), "store_kinds": "one kind" if int(Flow.TINCTURE["store_kinds"]) == 1 else "%d kinds" % int(Flow.TINCTURE["store_kinds"]),
		"early": int(Flow.EARNED["last_floor"]), "fall_chance": "%d%%" % int(round(float(Flow.FALL_MARK["chance"]) * 100.0)),
		"core_cap": int(Unbound.Core.CAP), "aura_steps": ", ".join(load("res://scripts/secret.gd").STEPS.map(func(v): return str(int(v)))),
		"ub_level": int(Unbound.LEVEL_SIZE), "ub_minor": Unbound.MINOR_LEVEL, "ub_gift": Unbound.GIFT_LEVEL, "ub_tech": Unbound.TECH_LEVEL, "ub_full": Unbound.FULL_TECH_LEVEL,
		"drain_share": "%d%%" % int(round(float(Unbound.DRAIN["share"]) * 100.0)),
		"rescue_odds": _odds(float(load("res://scripts/sworn.gd").RESCUE["chance"])),
		"send_odds": _odds(float(load("res://scripts/sworn.gd").SENDS["chance"])),
		"send_reward": int(load("res://scripts/sworn.gd").SENDS["reward"]),
	})
	# The vessel (vessel.gd CAPACITY, RAW, CORE).
	var Vessel = load("res://scripts/vessel.gd")
	f["vessel_cap"] = int(Vessel.CAPACITY)
	var vshare := float(Vessel.RAW["share"])
	f["vessel_share"] = "half" if is_equal_approx(vshare, 0.5) else "%d%%" % int(round(vshare * 100.0))
	f["vessel_per"] = int(Vessel.RAW["per_tincture"])
	f["core_floors"] = int(Vessel.CORE["floors"])
	# Forcing past full (forcing.gd FORCE, LADDER).
	var Forcing = load("res://scripts/forcing.gd")
	f["force_cost"] = _num(float(Forcing.FORCE["cost"]))
	f["force_per"] = _num(float(Forcing.FORCE["strain"]) * float(Items.CRYSTAL["step"]))
	f["force_burned"] = int(Forcing.LADDER["burned"])
	f["force_paralyzed"] = int(Forcing.LADDER["paralyzed"])
	f["force_break"] = int(Forcing.LADDER["break"])
	f["force_crack"] = _num(float(Forcing.FORCE["crack"]))
	f["force_fade_stair"] = _num(float(Forcing.FORCE["fade_stair"]))
	f["force_fade_climb"] = _num(float(Forcing.FORCE["fade_climb"]))
	# The workshop's Rune Artist (bench.gd ARTIST, PREMIUM).
	var Bench = load("res://scripts/bench.gd")
	f["artist"] = String(Bench.ARTIST["name"])
	var share := float(Bench.PREMIUM["share"])
	f["artist_premium"] = "half the materials again" if is_equal_approx(share, 0.5) else "%d%% of the materials" % int(round(share * 100.0))
	f["artist_work"] = "a fee of %d crystals of the piece's kind" % int(Bench.PREMIUM["work"])
	# The Exchange (bench.gd EXCHANGE).
	f["x_give"] = int(Bench.EXCHANGE["give"])
	f["x_get"] = int(Bench.EXCHANGE["get"])
	f["x_big"] = int(Bench.EXCHANGE["big"])
	var lost := 1.0 - float(Bench.EXCHANGE["get"]) / maxf(1.0, float(Bench.EXCHANGE["give"]))
	f["x_lost"] = "a third" if is_equal_approx(lost, 1.0 / 3.0) else "%d%%" % int(round(lost * 100.0))
	f["x_steps"] = " or ".join(Bench.EXCHANGE_STEPS.map(func(n): return str(int(n))))
	# Charms and bags (charms.gd, gear.gd BAG): from their tables.
	var Shop = load("res://scripts/shop.gd")
	var last: Dictionary = Shop.RANK_STOCK[-1]
	var Out = load("res://scripts/outfitter.gd")
	f["rail_most"] = Train.RACK_SIZE + int(Out.FX["rack_extra"]) + int(last["rail"])
	var titled: int = Out.ORDER.filter(func(id): return String(Out.NODES[id].get("title", "")) != "").size()
	f["tree_titled"] = "%d of them" % titled
	f["tree_total"] = Out.ORDER.size()
	f["tree_cap"] = "%d%%" % int(round(float(Out.FX["discount_cap"]) * 100.0))
	f["kinds_most"] = int(last["kinds"])
	f["gun_rank"] = R.rank_name(int(Shop.WEAPON_RANK.get("flintlock", 0)))
	var Charms = load("res://scripts/charms.gd")
	var n := int(Charms.SHOP["rack"])
	f["charm_shop"] = ("one on his rail" if n == 1 else "%d on his rail" % n)
	f["bag_none"] = int(Gear.BAG["none"])
	var sizes: Array = []
	for id in ["satchel", "pack", "great_pack"]:
		if Gear.PIECES.has(id):
			sizes.append("a %s %d" % [Gear.PIECES[id]["name"], int(Gear.PIECES[id].get("bag", 0))])
	f["bag_sizes"] = ", ".join(sizes)
	f["heavy_at"] = "%d%%" % int(round(float(Gear.BAG["heavy_at"]) * 100.0))
	var Best = load("res://scripts/bestiary.gd")
	f["bestiary_slain"] = _and(Best.TIERS.get("slain", []))
	f["bestiary_beast"] = _and(Best.TIERS.get("beast", []))
	return f


## Titles, contracts and brackets: what the climber has now, and what's open.
static func _fact_titles(main) -> Dictionary:
	var R = load("res://scripts/renown.gd")
	var S = load("res://scripts/stations.gd")
	var C = load("res://scripts/contracts.gd")
	var prof = main.profile if main != null else null
	var f := {"contracts_most": "one" if prof == null or C.most(prof) <= 1 else str(C.most(prof))}
	var bits: Array = []
	for b in S.BRACKETS:
		bits.append("%s at %s" % [b["name"], R.rank_name(int(b.get("rank", 0)))])
	f["brackets"] = ", ".join(bits)
	f["title_line"] = ""
	f["contract_line"] = ""
	if prof != null:
		var worn: String = R.worn_title(prof)
		var offer: Array = R.on_offer(prof)
		if not offer.is_empty():
			f["title_line"] = "The Noble would grant you %s now." % R.title_name(String(offer[0]))
		elif worn != "":
			f["title_line"] = "You wear %s." % worn
		var held: Array = C.active(prof)
		if not held.is_empty():
			f["contract_line"] = "You hold: %s." % C.name_of(held[0])
	return f


## A new climber's start (new_start.gd): what each answer gives, and yours.
## The controls for whatever you're playing with (controls.gd HELP).
static func _fact_controls(main) -> Dictionary:
	var C = load("res://scripts/controls.gd")
	var pad: bool = main != null and main.pad_active
	var touch: bool = main != null and main.touch_active
	var bits: Array = []
	for row in C.HELP:
		var k: String = C.pad_text(row[2], main.pad_ps) if pad else row[1]
		if k == "-":
			continue
		bits.append("%s: %s" % [k, row[0]])
	var how := "On a phone, the buttons on screen are labelled: hold one and I'll say what it does." if touch \
		else ("With a controller:" if pad else "On a keyboard and mouse:")
	return {"controls_how": how, "controls_list": "; ".join(bits) + "."}


static func _fact_start(main) -> Dictionary:
	var NS = load("res://scripts/new_start.gd")
	var f := {"born_crystals": str(NS.WHY["born"]["crystals"]), "hired_crystals": str(NS.WHY["hired"]["crystals"]), "start_line": ""}
	var prof = main.profile if main != null else null
	if prof != null and prof.origin is Dictionary and not prof.origin.is_empty():
		var lines: Array = NS.summary(prof.origin)
		if not lines.is_empty():
			f["start_line"] = "Yours: " + "; ".join(lines.map(func(l): return String(l).left(1).to_lower() + String(l).substr(1))) + "."
	return f


## The other climbers: how often, and who you've met.
static func _fact_rivals(main) -> Dictionary:
	var Rv = load("res://scripts/rivals.gd")
	var met: Array = Rv.met_list(main.profile) if main != null and main.profile != null else []
	var per := int(Rv.RULES["per_climb"])
	var f := {"rival_from": int(Rv.RULES["from"]), "rival_chance": "%d%%" % int(round(float(Rv.RULES["chance"]) * 100.0)),
		"rival_per": "once" if per == 1 else ("twice" if per == 2 else "%d times" % per), "rival_sure": int(Rv.RULES.get("sure_by", 3)), "rival_share": "%d%%" % int(round(float(Rv.RULES["team_share"]) * 100.0))}
	f["rival_met"] = String(TEXT.get("rivals_none", "")) if met.is_empty() else String(TEXT.get("rivals_met", "")) % [met.size(), String(met[0].get("name", ""))]
	return f


## The Dining car (dining.gd): its numbers, and your wagers and acquaintances.
static func _fact_dining(main) -> Dictionary:
	var D = load("res://scripts/dining.gd")
	var R: Dictionary = D.RULES
	var prof = main.profile if main != null else null
	var lo: float = minf(float(R["odds_slay_low"]), float(R["odds_floor_1"]))
	var hi: float = maxf(float(R["odds_beast"]), float(R["odds_floor_3"]))
	var open: int = (D.state(prof).get("bets", []) as Array).size() if prof != null else 0
	var met: int = load("res://scripts/rivals.gd").met_list(prof).size() if prof != null else 0
	return {"dine_seats": "%d to %d" % [int(R["seats_min"]), int(R["seats_max"])], "dine_stakes": "/".join(D.stakes().map(func(x): return str(x))),
		"dine_bets": int(R["max_bets"]), "dine_odds": "%sx to %sx" % [_num(lo), _num(hi)], "dine_crystals": int(R["duel_crystals"]),
		"dine_renown": int(R["duel_renown"]), "dine_win": int(R["duel_win_renown"]),
		"dine_open": String(TEXT["dining_open"]).replace("{n}", str(open)) if open > 0 else String(TEXT["dining_none"]),
		"dine_met": String(TEXT["dining_met"]).replace("{n}", str(met))}


## The wheels (wheel.gd): how slow the world goes, and the buttons in use.
static func _fact_wheel(main) -> Dictionary:
	var Wheel = load("res://scripts/wheel.gd")
	var mode := "keys"
	if main != null and bool(main.get("touch_active")):
		mode = "touch"
	elif main != null and bool(main.get("pad_active")):
		mode = "pad"
	var ps: bool = main != null and bool(main.get("pad_ps"))
	var point: String = String(Wheel.TEXT.get("point_" + mode, ""))
	return {"slow": "%d%%" % int(round(Wheel.slow() * 100.0)), "item": Entity.fill_keys("{item}", mode, ps), "point": point}


## [1, 5, 15] -> "1, 5 and 15".
static func _and(list: Array) -> String:
	var s: Array = list.map(func(x): return str(int(x)))
	if s.size() < 2:
		return "".join(s)
	return ", ".join(s.slice(0, s.size() - 1)) + " and " + String(s[-1])


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, round(v)) else str(snappedf(v, 0.01))


## What to do next: every hint that applies now, best first.
static func hints(main) -> Array:
	var out: Array = []
	if main == null or main.profile == null:
		return out
	var prof = main.profile
	var p = main.player
	var grace: String = load("res://scripts/training.gd").hint(prof)  # (the towers closed until the Noble's Grace: what comes first)
	if grace != "":
		out.append(grace)
	if not bool(main.on_train):
		var carried := 0.0
		for k in main.run_essence:
			carried += float(main.run_essence[k])
		if carried >= 1.0:
			out.append(fill(String(HINTS["unbanked"]), {"amount": int(carried)}))
		if p != null and p.hp < p.max_hp * 0.35:
			out.append(String(HINTS["low_health"]))
	for part in prof.bonds:
		var info: Dictionary = prof.bonds[part]
		if bool(info.get("faint", false)) and float(info.get("debt", 0.0)) > 0.0:
			out.append(fill(String(HINTS["faint"]), {"amount": int(ceil(float(info["debt"])))}))
			break
	var ready: String = prof.ready_for_mark()
	if ready != "":
		out.append(fill(String(HINTS["mark_ready"]), {"part": String(Bonds.PART_NAMES.get(ready, ready)).to_lower()}))
	if bool(main.on_train):
		# Something kept that beats what you'd wear.
		var best_g = null
		var best_v := 0
		for list in [prof.pack, prof.chest]:
			for g in list:
				var vs := Train.versus(prof, p, g)
				if vs > best_v:
					best_v = vs
					best_g = g
		if best_g != null:
			out.append(fill(String(HINTS["better_stash"]), {"piece": Gear.display(best_g)}))
		if prof.supplies.is_empty():
			out.append(String(HINTS["belt_empty"]))
		for g in Train.outfit(prof) + [Train.today(prof)]:
			if Gear.is_gear(g) and Train.versus(prof, p, g) > 0 and Train.short_of(prof, Train.gear_kind(g), Train.buy_price(prof, g)) == "":
				out.append(fill(String(HINTS["afford_rack"]), {"piece": Gear.display(g)}))
				break
		if prof.chest.size() >= Train.CHEST_SIZE:
			out.append(String(HINTS["stash_full"]))
		var R = load("res://scripts/renown.gd")
		var offer: Array = R.on_offer(prof)
		if not offer.is_empty():
			out.append(fill(String(HINTS["title_ready"]), {"title": R.title_name(String(offer[0]))}))
		var left: int = load("res://scripts/tutorial.gd").steps_left(prof)  # (basic training, one session)
		if left > 0 and int(prof.climbs) >= 1:
			out.append(fill(String(HINTS["lessons"]), {"n": left}))
	# The mark nearest its next step.
	var close := {}
	for part in prof.bonds:
		var info: Dictionary = prof.bonds[part]
		var xp := float(info.get("xp", 0.0))
		var step := ProfileScript.step_for_xp(xp)
		if step >= ProfileScript.STEP_XP.size():
			continue
		var pct := int(floor(MarkUse.step_fraction(ProfileScript.STEP_XP, xp) * 100.0))
		if pct >= 75 and pct > int(close.get("pct", -1)) and not MarkUse.dark(prof, part):
			close = {"mark": Bonds.BONDS.get(String(info.get("id", "")), {}).get("name", ""), "pct": pct, "step": step + 1}
	if not close.is_empty():
		out.append(fill(String(HINTS["mark_close"]), close))
	if bool(main.on_train):
		var id := tower_id(main)
		var best := _best(main, id)
		out.append(fill(String(HINTS["climb"]), {"best": maxi(best, 1), "tower": _the(String(Towers.TOWERS.get(id, {}).get("name", id)))}))
	else:
		out.append(String(HINTS["climb_play"]))
	return out


static func _fact_next(main) -> Dictionary:
	var h := hints(main)
	return {"hint": String(h[0]) if not h.is_empty() else String(HINTS["none"])}


static func _fact_next_more(main) -> Dictionary:
	var h := hints(main)
	return {"hint": String(h[1]) if h.size() > 1 else String(HINTS["none"])}


## The climb's events (notices.gd): this climb's in play; on the train the
## last climb's, kept after it ended.
static func _log(main) -> Array:
	if main == null:
		return []
	if not bool(main.on_train) and main.get("notices") != null:
		return main.notices.log
	return Array(Notices.climb_log.get("log", []))


static func _fact_climb(main) -> Dictionary:
	var prof = main.profile if main != null else null
	var log := _log(main)
	var in_play := main != null and not bool(main.on_train)
	var id := String(main.tower) if in_play else String(Notices.climb_log.get("tower", ""))
	if id == "" and prof != null:
		id = String(prof.last_tower)
	var t: Dictionary = Towers.TOWERS.get(id, {})
	var f := {"tower": _the(String(t.get("name", id)))}
	var best := _best(main, id)
	f["best_line"] = String(TEXT["best"]) % best if best > 0 else ""
	# The newest few, for "What happened last?".
	var recent: Array = []
	for i in range(log.size() - 1, maxi(-1, log.size() - 5), -1):
		recent.append(Notices.log_text(log[i]))
	f["events"] = ". ".join(recent) + "." if not recent.is_empty() else String(TEXT["events_none"])
	if log.is_empty():
		f["summary"] = fill(String(TEXT["summary_empty"] if in_play else TEXT["summary_none"]), f)
		return f
	var floor_n := 0
	var gathered := 0
	var finds := 0
	var banked := 0
	var num := RegEx.create_from_string("\\d+")
	for e in log:
		floor_n = maxi(floor_n, int(e.get("floor", 0)))
		match String(e.get("kind", "")):
			"essence":
				var mm := num.search(String(e.get("text", "")))
				if mm != null:
					gathered += int(mm.get_string())
			"gear", "item", "crystal", "key":
				finds += int(e.get("n", 1))
			"banked":
				banked += int(e.get("n", 1))
	if in_play:
		floor_n = maxi(floor_n, int(main.floor_num))
	var pay := ""
	if not in_play and prof != null and not prof.last_pay.is_empty():
		pay = Train.price_text(String(prof.last_pay.get("kind", "")), int(prof.last_pay.get("amount", 0)))
	f["floor"] = floor_n
	f["summary"] = fill(String(TEXT["summary"]), {"tower": f["tower"], "floor": floor_n,
		"gathered": fill(String(TEXT["gathered"]), {"n": gathered}) + " " if gathered > 0 else "",
		"finds": fill(String(TEXT["finds"]), {"n": finds}) + " " if finds > 0 else "",
		"banked": fill(String(TEXT["banked"]), {"n": banked}) + " " if banked > 0 else "",
		"pay": fill(String(TEXT["pay"]), {"pay": pay}) if pay != "" else ""})
	return f
