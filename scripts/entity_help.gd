extends RefCounted
## The Entity's explanations on the train: what a button does or where it
## goes, said in a small bubble beside it when you hover it (mouse), move
## onto it (keys, controller) or press and hold it (touch). entity_helper.gd
## shows them; the words are here, in plain data (and in the Data editor:
## "The Entity's words").
##
## HELP is keyed by a stable id worked out from the button's own tags (its
## "meta": key_for below), never by its words, so a button can be renamed
## and keep its explanation:
##   rail:<item>          a rail entry (rail:engine, rail:store, rail:gym...)
##   slot:<kind>          a slot (slot:pack, slot:chest, slot:worn, slot:outfit,
##                        slot:supply, slot:bench:item...); "slot:pack:empty"
##                        for an empty one
##   buy, buy:chest, sell, equip, move:pack, put_back, brew, depart, tower...
##   bench_tab:<counter>, setting:<setting>, tab:<tab>, pick:<kind>...
##   furnish:<kind>       a piece of the train's furniture (not a button: the
##                        pointer on it, or a finger held on it)
## A key with no entry of its own falls back to the part before its last ":"
## ("bench_tab:vessel" -> "bench_tab"). A button with no entry at all says
## its own words (tests/parts/entity_train.gd lists any train button that
## has none, so none is forgotten).
##
## COMMENTS: under the explanation, a short comment in the Entity's own voice,
## by the kind of thing (the part of the key before ":" or "_", else "any").
## One is picked for each button and stays the same for it.
##
## In the words, {name} is filled in from the game as it is now (facts
## below): {piece} (the piece or item), {desc} (what it does, from its own
## card), {price}, {versus} (better or worse than what you'd wear), {slot},
## {from} (where a worn piece comes from), {tower}, {essence}, {best},
## {beast}, {station}, {count}, {car}, {shelf}, {heard}, {total}, {crafter}
## (on a crafted counter: who crafts it, you or the workshop's Rune
## Artist), {artist} (the Rune Artist's name), {choice}, {words} (the
## button's own words). A blank left unfilled is dropped.
##
## Never the story here: these are plain facts about the buttons.

const Train := preload("res://scripts/train.gd")
const Bench := preload("res://scripts/bench.gd")
const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")
const Shop := preload("res://scripts/shop.gd")
const Essence := preload("res://scripts/essence.gd")
const Towers := preload("res://scripts/towers.gd")
const Stations := preload("res://scripts/stations.gd")
const Renown := preload("res://scripts/renown.gd")
const Titles := preload("res://scripts/titles.gd")
const Contracts := preload("res://scripts/contracts.gd")
const Entity := preload("res://scripts/entity.gd")
const Guide := preload("res://scripts/guide.gd")
const StorageView := preload("res://scripts/storage_view.gd")
const OutfitterName := preload("res://scripts/outfitter_name.gd")
const RuneArtistName := preload("res://scripts/rune_artist_name.gd")

static var HELP: Dictionary = RuneArtistName.named(OutfitterName.named({
	# --- the rail -----------------------------------------------------------------------
	"rail:climber": "Your climber's book: abilities, the tree, marks, essence and your record.",
	"rail:engine": "Opens the Engine: its map of the six towers. Climb the one by your station, or ride to another.",
	"rail:store": "Opens the Outfitter's Car: buy supplies and gear, and sell what you found.",
	"rail:personal": "Opens Your Car: what you'll wear, your pack and your stash.",
	"rail:workshop": "Opens the Workshop: brew supplies, break pieces down, work on gear.",
	"rail:library": "Opens the Library: everything I've told you, kept on shelves.",
	"rail:settings": "Opens the Settings & Controls Car: sound, screen, every key, and Start over.",
	"rail:dining": "Opens the Dining Car: other climbers at its tables. Rumors, wagers, trades and duels.",
	"rail:dev": "Dev Tools: switches for testing. Not part of the game.",
	"rail:exit": "Back to the title screen. Your climber is saved as {they} {are}.",
	"rail:quit": "Closes the game. Your climber is saved as they are.",
	"rail:leave_station": "Back to the train, waiting at this station: your car, {outfitter}, the workshop and the engine.",
	"rail:gym": "Training: short lessons on the basics, with me talking you through, and medal drills.",
	"rail:arena": "The Tournament: brackets of three rounds against other climbers. Nobody dies; a loss costs only the fee.",
	"rail:noble": "The Noble: titles granted by renown (each helps with someone), and contracts for the towers.",
	"rail:board": "The Renown Board: your rank, what the next one opens, every rank, your deeds and the climbers you've met.",
	"rail:resume": "Back to the climb.",
	"rail:inventory": "Your gear, items and heirlooms.",
	"floor_map": "Opens the floor map: the rooms you've seen, where you stand, the stair and the portals.",
	# --- the engine -------------------------------------------------------------------------
	"tower": "{Tower}, by {station}: {essence} essence, and {beast} at the top. {wild_line} {where} {best_line}",
	"depart": "Pull it and the train leaves for {tower}. Your pack and your belt go with you.",
	"board:stations": "Steps off at the station you're at: Training, the tournament, the Noble and the Renown Board.",
	"board:towers": "Turns the board back to the six towers.",
	"station": "{station}: a stop between towers. Choose it, then pull its lever.",
	"go_station": "Steps off at {station}: Training, the tournament, its Noble and the Renown Board. Nothing you carry is at risk there.",
	"ride": "Pays {price} crystals of any kind and rides {count} to {station}. Its tower is then open to you.",
	"tour:next": "On to the next part of my tour.",
	"tour:back": "Back to the last part of my tour.",
	"tour:skip": "Ends my tour here. Ask me to show you around again any time.",
	# --- the outfitter's car ------------------------------------------------------------------
	"store_tab:tree": "Shows {outfitter}'s upgrade tree: your rank is its trunk, and you buy its nodes with crystals.",
	"store_tab:shop": "Back to the goods: consumables, weapons and armour, charms, and selling.",
	"store_upgrades:open": "Opens {outfitter}'s upgrade tree under him: your rank is its trunk, and you buy its nodes with crystals. Press it again to fold the tree away.",
	"store_upgrades:close": "Folds the upgrade tree away to this sign, so there's more room to see {outfitter}. Press it again to open the tree. The car remembers.",
	"slot:tree": "{piece}: {desc} {state}",
	"tree_buy": "Buys {piece} for {price}, for good: {desc}",
	"slot:unique": "{piece}, {price}: a relic he brought out for you, once. {versus}",
	"slot:unique:empty": "Nothing waits here.",
	"slot:supply": "{piece}, {price}: {desc}. It goes on your belt for your next climb.{any}",
	"slot:outfit": "{piece} on his rail, {price}. {versus}",
	"slot:outfit:empty": "Sold. The rail fills again after your next climb.",
	"slot:today": "Today's piece: {piece}, {price}. A new one after every climb. {versus}",
	"slot:today:empty": "Today's piece is sold. A new one after your next climb.",
	"slot:order": "{piece}: {outfitter} is holding it for you.",
	"buy:supply": "Buys {piece} for {price}. It goes on your belt for your next climb.{any}",
	"buy": "Buys {piece} for {price}, into your pack. It goes up the tower with you.",
	"buy:chest": "Buys {piece} for {price}, into your stash. It stays on the train.",
	"buy:wear": "Buys {piece} for {price} and puts it on at once.",
	"buy:hold": "Asks {outfitter} to keep {piece} for you until you come back.",
	"put_back": "Puts one {piece} back on the shelf. What you paid comes back.",
	"sell": "Sells {piece} for {price}. It asks first.",
	# --- your car, the Loadout and the stash ------------------------------------------------------
	"slot:worn": "{slot}: {piece}. What you start the climb wearing there. {from} {pool}",
	"slot:worn:empty": "{slot}: nothing yet. Choose it to see what could go there.",
	"slot:pack": "{piece}, in your pack: it goes up the tower with you. {versus} {pool}",
	"slot:pack:empty": "An empty pocket in your pack. Pieces here go up the tower with you.",
	"slot:chest": "{piece}, in your stash: it stays safe on the train. {versus} {pool}",
	"slot:chest:empty": "An empty space in your stash ({count}).",
	"slot:belt": "{piece}: packed on your belt for your next climb.",
	"slot:vessel": "A vessel: it keeps essence raw on a climb, tower essence at the stairs or core essence from great foes.",
	"open_stash": "Opens the stash: every piece in it ({count}), to sort and filter.",
	"car_page:stash": "Opens the stash: every piece in it ({count}), to sort and filter.",
	"car_page:climber": "Your climber's book: abilities, the tree, marks, essence and your record.",
	"car_page:loadout": "The Loadout: what you'll wear, your pack and your belt, drawn large.",
	"car_page:appearance": "How you look. Looks never change how you play.",
	"equip": "Wear {piece}. What it replaces goes back where this came from.",
	"move:chest": "Moves {piece} into your stash. It stays on the train.",
	"move:pack": "Moves {piece} into your pack. It goes up the tower with you.",
	"unequip:pack": "Takes {piece} off, into your pack.",
	"unequip:chest": "Takes {piece} off, into your stash.",
	"tab:loadout": "The Loadout: what you'll wear, your pack and your belt.",
	"tab:stash": "The stash: every piece you keep on the train.",
	"cycler:sort": "Sorts the stash: newest, rarity, slot, essence or price.",
	"cycler:slot": "Shows only the pieces for one slot.",
	"cycler:kind": "Shows only the pieces of one essence.",
	# --- the workshop ---------------------------------------------------------------------------
	"bench_tab:brew": "Brew: supplies for your belt, a little cheaper than {outfitter}'s.",
	"bench_tab:temper": "Temper: raise a piece's rank, +1 to +3.{crafter}",
	"bench_tab:retrait": "Retrait: swap one of a piece's traits.{crafter}",
	"bench_tab:join": "Join: two Fine pieces for one slot become one Rare.{crafter}",
	"bench_tab:break": "Break down: a piece or a packed item becomes crystals.",
	"bench_tab:inscribe": "Inscribe: a lasting rune on one piece.{crafter}",
	"bench_tab:recall": "Recall scroll: bind one to leave a climb safely.{crafter}",
	"bench_tab:vessel": "Vessel: brew one, or work a full vessel of core essence into a piece: a core rune, +4 or a deep rune.{crafter}",
	"bench_tab:tincture": "Tinctures: craft one from crystals of its kind or from raw essence in a vessel, or drink one you've packed.",
	"bench_tab:exchange": "Exchange: trade crystals of one kind for another. Some is lost in the working.",
	"slot:bench:x": "{piece}: you hold {count}. Choose it to give it at the Exchange; its card picks the kind to get.",
	"exchange_to": "Get {piece} for what you give. You hold {count} {piece} now.",
	"exchange_step": "Steps the amount you give by {count}. Trades go in whole lots.",
	"exchange_step:all": "Gives all the {piece} you can trade: {count}, in whole lots.",
	"exchange_do": "Makes the trade: {price}.",
	"exchange_do:big": "Makes the trade: {price}. A trade this big asks first.",
	"bench_tab:charm": "Charms: refill a charm's spent charge with crystals of its kind, or craft a new charm.{crafter}",
	"bench_tab": "{counter}.{crafter}",
	"rune_artist_npc": "{artist}, the Rune Artist who works the bench. Without the Rune Artist's mark, she crafts for you: the same crystals plus a premium on top. Press to hear her.",
	"slot:bench:item": "{piece}, {price} to brew: {desc}.",
	"slot:bench:supply": "{piece}, packed on your belt. It can be broken down for crystals.",
	"slot:bench": "{piece}: {counter} it here.",
	"slot:bench:empty": "Nothing here to work on.",
	"slot:bench:tincture": "{piece}, {price} to craft. Drink it and you choose where its essence goes.",
	# --- tinctures and crystals (essence_flow.gd, pour_page.gd) ---
	"tincture_craft": "Crafts {piece} from crystals of its kind. It's packed for your next climb.",
	"tincture_drink": "Opens your crystals and tinctures, where you choose the mark or body part {piece} goes into.",
	"pour:open": "Your crystals and tinctures: eat a crystal and it flows the natural way; drink a tincture and you choose where.",
	"pour:eat": "Eats {piece}: your body and your marks share its essence the natural way. You can't steer it.",
	"pour:mark": "Pours {piece} into {part}: it grows. Its own kind counts fully, any other a little.",
	"pour:part": "Pours {piece} into your {part}: it soaks toward a new mark there, and leans that mark toward its kind.",
	"pour:force": "Forces {piece} into {part}, past full: it stretches it a little, at {force} times the essence its use would take, and strains it. Too much strain burns it; past paralyzed a mark burns out and a Node cracks. It asks first, and says where the strain would leave it.",
	"slot:crystal": "{piece}: {count} essence. Choose it to eat some.",
	"slot:crystal:empty": "{piece}: none yet. Stairs condense crystals, and {outfitter} pays for every climb.",
	"slot:tincture": "{piece}: choose it, then choose where it goes.",
	"slot:bench:craft": "{piece}, a charm the bench crafts for {price}: {desc}.",
	"slot:bench:charm": "{piece}: an essence item you own. Choose it to see its own pool, and refill it with crystals of its kind. {pool}",
	"bench_do:refill": "Refills {piece}'s charge with crystals of its kind. It asks first.",
	"bench_do:craft": "Crafts {piece}: it goes into your stash. It asks first.",
	"feed_charm": "Feeds your charm essence you haven't banked yet: its charge is full again.",
	"feed_offhand": "Feeds your off-hand piece's own pool essence you haven't banked yet: its uses are full again.",
	"feed_item": "Filters essence you carry into this weapon's own pool: full again. Not while a monster is after you. What you pour in, you won't bank.",
	"tab:deeds": "Your deeds: thirty-six of them, each paying a little renown; and the Summit Blades you've found and bonded.",
	"deeds_leaf_deeds": "The deeds: six kinds of six, what each asks, how far along you are and the renown it pays.",
	"deeds_leaf_blades": "The Summit Blades: one hidden in each tower. Which you've found and bonded, their powers, and awakening.",
	"deeds_carry": "Carries this Summit Blade at your hip instead: its power is the one that fires in a fight.",
	"deeds_awaken": "Awakens this blade a step, for crystals of its tower's essence: its power grows stronger and rests less. Once between climbs.",
	"brew": "Brews {piece} for {price}. It goes on your belt.",
	"bench_do:temper": "Raises {piece} a rank. It asks first.",
	"bench_do:break": "Breaks {piece} down into crystals. It asks first.",
	"bench_do:vtemper": "Works a full vessel of core essence into {piece}: a rank past +3. The vessel stays, empty. It asks first.",
	"bench_do:vrune": "Works a full vessel of core essence into {piece}: a deep rune. The vessel stays, empty. It asks first.",
	"core_rune": "Works this core rune into {piece}, powered by a full vessel of core essence. It fades after its floors worn; the vessel stays, empty. It asks first.",
	"retrait": "Swaps the chosen trait for one of this essence. It asks first.",
	"retrait_pick": "Chooses which trait to swap.",
	"join": "Joins {piece} with this one into a Rare. It asks first.",
	"inscribe": "Puts this rune on {piece} for good. It asks first.",
	"vessel_pack": "Packs the vessel for your next climb, or leaves it here.",
	"vessel_catch": "Switches what this empty vessel catches: raw essence at the stairs, or the core essence that isn't your path, from great foes.",
	"vessel_tincture": "Makes one tincture from raw essence in a vessel in your stash, packed for your next climb. Far cheaper than crystals.",
	"vessel_brew": "Brews an empty vessel.",
	"tech_slot": "A Node's mark button and the technique it casts (once the Node reaches level 6). Press to see and change it below.",
	"tech_form": "A form: the shape this Node's technique takes. Press to use it; it changes at once. A dark one opens as the Node grows.",
	"tech_fx": "What this essence does in the technique. Press for its next effect that has opened; more open as that essence pools in you.",
	"tech_fitting": "A variation, drawn as a fitting on the globe's spout. Press to put it on (in place of another), again to take it off. Dark ones grow on a part's tree.",
	"tech_name": "Name the technique (optional). Left empty, it keeps the name its form and essence give it.",
	"tech_boost": "On: a cast spends essence you carry unbanked, if it holds the technique's essences, and hits harder. Off: carried essence is never spent.",
	"ub_part": "One of your Nodes: its level, its size (how much it can hold, 120 at most) and the essences it holds. Press it to see what its levels bring and to move essence out of it (below).",
	"ub_part_sealed": "A sealed Node: it takes no essence and gives nothing. Press it to choose it: on the train, Unseal it below (it starts again asleep, at size 0).",
	"sworn": "You carry a Maker's secret bond, so you are one of its Sworn. Now and then, after a climb, it sends you to a floor of another tower for a few crystals of that tower's essence; the errand shows under this. Press it to ask me how the Sworn work.",
	"ub_seal":"Seals this Node: it takes no essence, and what it holds condenses into crystals; its size, technique, gift, minor ability and attributes are gone. Each sealed Node makes your open Nodes grow faster from use and hit harder. It asks first (a pop-up: Confirm or Cancel). On the train only; one Node always stays open.",
	"mark_seal_break": "Breaks the seal on your faint mark: the mark comes away, every mark with it, and you are Unbound, for good. It asks first (a pop-up: Confirm or Cancel). On the train only, and only while the mark is still faint; once it has grown to full strength the seal is gone.",
	"ub_unseal": "Opens this sealed Node again. It starts asleep, at size 0, and soaks up the essence routed to it until it wakes. Your open Nodes lose its share of the sealing bonus. It asks first. On the train only.",
	"ub_part_asleep":"A sleeping Node: it holds nothing and shows no numbers until it wakes. Press it to feed it essence from an awake Node (Move essence, below).",
	"ub_move_from": "The awake Node to move essence out of. Press for the next one, or press a Node's card above.",
	"ub_move_kind": "Which essence in that Node to move. Press for the next one.",
	"ub_move_to": "The Node it goes into. Press for the next one that can take it: an awake Node that's full, already holds three kinds, or whose lead would fall under half is skipped. A sleeping Node is fed: it soaks in.",
	"ub_move": "Moves up to 6 of that essence into the other Node (or feeds a sleeping one); the button shows how much and the price. A quarter is the price: crystals before a path, Making on the Making path, unmade on the Unmaking path. Sizes don't change. Not while a monster is after you.",
	"ub_drain": "Takes up to 6 of that essence out of the Node and condenses it into crystals of its kind (a quarter is still the price). Separate from Move, to empty a Node.",
	"ub_body_open": "Opens the climber screen on its Body tab: your six Nodes, and moving essence from one to another.",
	"ub_route": "Where banked essence of this kind flows from now on. Press to send it to another Node (a sleeping one soaks it in and wakes sooner).",
	# --- the library ------------------------------------------------------------------------------
	"shelf": "{shelf}: {heard} of {total} heard. It opens on the lectern.",
	"shelf:bestiary": "The Bestiary: every monster you've met, and what you've learned of it ({count} met). It opens on the lectern.",
	"tab:archive": "The Archive: everything I've told you, by subject.",
	"tab:bestiary": "The Bestiary: every monster you've met, and what you've learned of it.",
	"bestiary": "{name}: its entry, with all you've learned of it so far.",
	"bestiary_locked": "Not met yet. Its entry starts once you've seen one.",
	"archive": "{archive}: what I said, and a fuller account.",
	"help:replay": "I'll tell you every tip again. The Archive keeps what it has.",
	"help:tips": "My tips on or off. The Archive fills in either way.",
	"setting:tips": "My tips on or off. The Archive fills in either way.",
	# --- settings ------------------------------------------------------------------------------------
	"panel_tab:settings": "Sound, screen, sizes, and my words.",
	"panel_tab:controls": "Every key and every button.",
	"tab:settings": "Sound, screen, sizes, and my words.",
	"tab:controls": "Every key and every button.",
	"setting:ui_size": "Interface size: how big menus and words are. This one: {choice}.",
	"setting:world_zoom": "How close the camera sits in the tower. This one: {choice}.",
	"setting:music": "How loud the music is.",
	"setting:sounds": "How loud everything else is.",
	"setting:shake": "The screen shakes on heavy hits, blasts and a beast's blows. Turn it off and the picture stays still.",
	"setting:help": "Keeps the list of controls on screen while you play (H).",
	"setting:hud_scale": "How big the bars and slots are in play. This one: {choice}.",
	"setting:lighting": "Lighting quality. Lower is kinder to a phone. This one: {choice}.",
	"setting:effects": "Sparks, embers and glints from enchanted weapons and spells. Low keeps the lights, Medium is usual, High adds more. This one: {choice}.",
	"setting:entity_help": "Me, explaining buttons as you point at them, or hold them on a phone.",
	"setting:arrange": "Arrange mode: move and resize what's on this screen yourself. On the train: each car's furniture and what's on it; ‹ Car and Car › move along. Save keeps it.",
	"setting:arrange_train": "Back to the train, in Arrange mode: move and resize each car's furniture and what's on it.",
	"setting:padsetup": "Teach the game your controller's buttons.",
	"setting:data": "Change the game's words, numbers and colours.",
	"over": "Starts this climber over: no marks, the first climb again. It asks first.",
	"pop_confirm": "Does what the question above says.",
	"pop_cancel": "Does nothing: back to where you were. Esc, B or a tap outside do the same.",
	# --- a new climber's start (start_pages.gd) -------------------------------------
	"start:continue": "Plays the climber you played last, where you left them.",
	"start:new": "Begins a new climber in an empty slot: my introduction, a name, a look, three questions. Your other climbers are kept.",
	"start:climbers": "All six slots: choose a climber to play, an empty slot to begin one there, or Delete under a card (it asks first).",
	"start:cleared": "Puts this notice away. The cleared climbers' files were kept as copies on this device.",
	"start:intro_next": "My next line. There are six.",
	"start:intro_back": "My line before this one.",
	"start:intro_skip": "Skips my introduction and goes straight to making your climber. Offered once you've made one before.",
	"start:intro_go": "On to making your climber: a name first.",
	"start:name": "Your climber's name. It's optional.",
	"start:dice": "Offers a name. Press again for another.",
	"start:pronoun": "{desc}",
	"start:name_next": "On to your look: body, face, hair, clothes and cloak.",
	"start:name_back": "Back to my introduction.",
	"start:look_next": "On to three questions that decide how you begin.",
	"start:answer": "{desc}",
	"start:quiz_back": "Back one question (or to your look).",
	"start:begin": "Makes your climber with these answers and takes you to your home station: basic training and a first tournament come before any climb.",
	"start:change": "Back to the first question, to answer again.",
	"start:wheel": "A colour of your own: pick it on the wheel, then its brightness and strength.",
	"start:wheel_done": "Keeps this colour and goes back to the rows.",
	# --- the climber's book --------------------------------------------------------------------------
	"tab:abilities": "Abilities: what you can cast, and how.",
	"tab:tree": "The Tree: where you choose how each mark grows.",
	"tab:marks": "Your marks, and how far each has grown (the Unbound: your six Nodes).",
	"tab:essence": "What you've banked, by essence, and where it settled (the Unbound: your aura, core essence and crystals).",
	"tab:record": "Your record, as I keep it.",
	"tab:techniques": "Your techniques: what each mark button casts, what your Nodes give, and where you change them.",
	"ribbon": "{words}: a page of your book.",
	"ability": "{ability}: {desc}.",
	"map_link": "Shows it on the body map, on the Tree.",
	"try_abilities": "Try your abilities on dummies, here on the train.",
	"steps": "Every mark's steps, on the Marks page of your book.",
	"change_techniques": "Opens the Techniques tab: change each part's technique.",
	"part": "{words}: this mark's own page.",
	"mark_depth": "{words}: this mark's own page. Its bar is how deep its pool feels, never in numbers: cast its spells and each stair refills and deepens it.",
	"mark_depth_bar": "How deep this mark's pool feels, and how near its next step. Cast its spells in a climb: each stair refills what you used and deepens it. A mark you never cast barely grows.",
	"bud": "A choice on the Tree. Choose it to see it.",
	"bud_rank4": "Step 6: this mark's passive grows to rank IV. It comes by itself; nothing to choose.",
	"bud_upgrade": "An upgrade to this mark's spells (step 7, 9 or 11). Choose one of the two, for good; until you do, nothing changes.",
	"bud_apex": "Step 8: the mark's great spell grows stronger. It comes by itself.",
	"bud_transform": "Step 10: a second Transformation of the mark's first spell. Choose one of the two, for good.",
	"bud_zenith": "Step 12, the Zenith: the mark's greatest power. Every spell of this mark does something more.",
	"tree_act:choose": "Chooses this for good.",
	"tree_act:learn": "Learns this.",
	# --- a station ---------------------------------------------------------------------------------------
	"pick:lesson": "{name}: a short lesson. {desc}",
	"pick:drill": "{name}: {desc}",
	"pick:bracket": "{name}: three rounds against climbers. Its card shows them, the fee and the prize.",
	"pick:title": "{name}: {desc}",
	"pick:contract": "{name}: {desc}",
	"pick:rank": "{name}: {desc}",
	"pick:rival": "{name}, a climber you met: {desc}",
	"station_do:begin": "Begins it in the station's arena. A fall here costs nothing but the try.",
	"station_do:skip": "Marks basic training as known without playing it. Open once the Grace is yours, or if you've made a climber before.",
	"station_do:restart": "Starts basic training again from its first step.",
	"pick:basics": "Basic training: one session of {n} steps, every way to move, attack and parry. {desc}",
	"station_do:grant": "Asks the Noble to grant this title. You'll wear it at once; its benefits apply while you do.",
	"station_do:wear": "Wears this title (or takes it off). Only the worn title gives its benefits.",
	"station_do:take": "Takes this contract. It's tracked at the top of the screen while you climb.",
	"station_do:drop": "Gives this contract up. The Noble has others.",
	"station_do:deliver": "Gives the Noble your full vessel for the city: renown and a piece from the city's stores. The vessel is theirs. It asks first.",
	"station_do:decline": "Declines the city's ask. Another may come at a later visit.",
	"pick:ask": "{name}: {desc}",
	# --- training and tournaments (training.gd, tournaments.gd) -----------------------------------------
	"pick:advanced": "{name}: advanced or mark training. {desc}",
	"pick:first": "Your first tournament: three rounds, then the Noble's Grace, win or lose. Each round won adds a reward.",
	"pick:grace": "The Noble's Grace: what lets you into the towers. Its card says how to earn it.",
	"pick:manager": "Where the Tournament Manager is now: {name}. They move on after each climb.",
	"station_do:first": "Enters your first tournament: monsters, then a champion. Nobody dies, and the Grace comes win or lose.",
	"station_do:advanced": "Begins this training. Its small fee is paid in the essence that fits it; the first time pays a little renown.",
	"furnish:grace_lock": "Locked: the towers open once the Noble grants you the Grace. Basic training at the gym, then your first tournament.",
	# --- the Dining car -----------------------------------------------------------------------------------
	"dine:diner": "A climber at the tables. Talk to them: a rumor, a wager, a trade or a duel.",
	"dine:ask_rumor": "Asks for a rumor. What they tell is always true.",
	"dine:ask_bet": "Asks for a wager on your next climb, in the tower on the Engine's board.",
	"dine:ask_trade": "Asks what they'll trade: their goods for your crystals, or a piece of yours for theirs.",
	"dine:ask_duel": "Challenges them to a duel in the Arena car. You choose the stake next.",
	"dine:bye": "Ends the talk.",
	"dine:back": "Back to the other things you can say.",
	"dine:bet": "{words}. Choose it, then a stake. It's settled when your next climb ends.",
	"dine:stake": "Puts that many crystals on it, any kind, your biggest first. Win and it pays the stake times the odds.",
	"dine:trade_give": "{words}. Pays them in crystals; a piece goes to your stash, a tincture on your belt.",
	"dine:trade_buy": "{words}. Your piece leaves your stash; their crystals are yours.",
	"dine:duel_stake": "Fights for this: {words}. Win and you take theirs; lose and they take yours.",
	"dine:duel_go": "Into the Arena car. First to yield loses; nobody dies. Back here after.",
	# --- the train's furniture (not buttons: the pointer resting on it) ---------------------------------
	"furnish:board": "The Engine's map: the six towers on the loop, a station by each. Climb the one by your station, or ride to another.",
	"furnish:map": "The loop: six stations in tower order. The small train is where you are; each other station shows its fare.",
	"furnish:lock": "Locked: travel opens with your first mark, or once you become Unbound.",
	"furnish:rack": "What you'll wear on your next climb, piece by piece. Choose a slot to change it.",
	"furnish:pack": "Your pack: what's in it goes up the tower with you, and can be lost there.",
	"furnish:chest": "Your stash: what's in it stays safe on the train.",
	"furnish:shelf": "{outfitter}'s shelf: supplies for your belt.",
	"furnish:rail": "{outfitter}'s rack: pieces to wear. It fills again after every climb.",
	"furnish:case": "The glass case: today's piece, a new one after every climb.",
	"furnish:drawers": "The bench's drawers: each opens one kind of work.",
	"furnish:bookcase": "The Library's shelves: everything I've told you, by subject, and the Bestiary.",
	"furnish:lectern": "The lectern: the volume you chose, open at the subject you chose.",
	"furnish:signal": "The settings panel: sound, screen, sizes, my words, and every key.",
	"furnish:brake": "The emergency brake: Start over this climber. It asks first.",
	"furnish:tables": "The Dining Car's tables: climbers resting between towers. Choose one to talk.",
	"furnish:placard": "The car's placard: what this car is for.",
	# --- anywhere ----------------------------------------------------------------------------------------
	"back": "Back where you came from.",
	"close": "Closes this page.",
}))

## The Entity's comment under an explanation, by the kind of thing (the
## part of its key before ":" or "_"; "any" for everything else). Short,
## dry, in its own voice; never the story.
static var COMMENTS: Dictionary = RuneArtistName.named(OutfitterName.named({
	"rail": ["Every door on this train leads somewhere. Most of them lead back here.", "I've walked this rail more often than you have.", "Choose a car. The train won't mind."],
	"slot": ["A small thing. Small things matter up there.", "I'd keep an eye on that one.", "Everything you carry tells me something about you.", "Weigh it well. The tower will."],
	"buy": ["{outfitter} remembers who pays.", "Crystals spent are crystals that can't be lost. Some comfort.", "A fair price, by his reckoning."],
	"sell": ["What came down the tower can go to someone else.", "He'll find a use for it. He always does.", "Lighter pockets, heavier purse."],
	"put": ["Second thoughts are allowed. Here, at least."],
	"tower": ["Each of them is waiting. Patiently.", "I know every stair in there. You'll learn them.", "Its beast is listening. It usually is."],
	"depart": ["The lever is the easy part.", "Pull it when you're ready. Or a little before.", "Off you go, then. I'll be watching."],
	"station": ["A stop between towers. A breath, nothing more.", "Other climbers wait there. Some of them are worth meeting."],
	"go": ["A stop between towers. A breath, nothing more."],
	"board": ["The board knows where the rails go. I know a little more."],
	"tower_map": ["Six cities, six towers, one track.", "The loop goes both ways. The fare doesn't care.", "Every station has a Noble. They all know your name."],
	"ride": ["Sit by the window. The towers look better from a distance.", "A short ride. Mind the change."],
	"tour": ["I'll keep it short.", "Follow me. I know the way."],
	"store": ["He sorts his goods better than he sorts his thoughts.", "Look twice. He prices things once."],
	"equip": ["It suits you. Mostly.", "Wear it well. The tower notices."],
	"move": ["Up the tower, or safe on the train. Choose what you can lose.", "Sorting is a kind of planning."],
	"unequip": ["Off it comes. It'll keep."],
	"brew": ["Bubbles, steam, a smell I won't describe. Useful, though."],
	"bench": ["The bench has seen worse ideas than yours. Not many.", "Patient work. The tower rewards it, eventually.", "Mind your fingers."],
	"retrait": ["Change one thing and the rest follow. Sometimes."],
	"join": ["Two become one. It's tidier that way."],
	"inscribe": ["A rune is a promise you can't take back."],
	"vessel": ["It holds what the tower would rather keep."],
	"tech": ["Six buttons, six habits. Choose good ones."],
	"shelf": ["I wrote all of it down. You may as well read it.", "Some of these I said more than once. You're welcome."],
	"archive": ["I don't mind repeating myself. Much.", "Every word as I said it. Nothing is lost here."],
	"bestiary": ["Know what bites. It helps.", "They learn you as you learn them. Remember that."],
	"help": ["I could stay quiet. I don't think you'd like it."],
	"panel": ["Adjust what you must. The tower won't."],
	"tab": ["Another page. There's always another page.", "Turn it. I'll wait."],
	"ribbon": ["Your book keeps what you are. I keep what you did."],
	"setting": ["Change what you like. The tower won't.", "Quieter, louder, bigger. I'll wait.", "Your comfort matters. To one of us, anyway."],
	"choice": ["Change what you like. The tower won't."],
	"over": ["Some climbers start over. Not many come back the same.", "Think on it. I'll remember either way."],
	"car": ["Your car, your things. I only look.", "Everything here is yours. For now."],
	"open": ["Everything you keep, in one place. Tidy."],
	"cycler": ["Order helps. A little."],
	"pick": ["Choose. Then live with it, mostly.", "I've seen that go well. And badly."],
	"ability": ["Know what you can do before the tower asks.", "Practice beats hope. Usually."],
	"map": ["Your body keeps score. The map shows it."],
	"try": ["Dummies don't hit back. Enjoy it."],
	"steps": ["Each step costs essence. Each step is worth it, mostly."],
	"change": ["Six buttons, six habits. Choose good ones."],
	"part": ["Every mark is a story your body tells. Read it."],
	"bud": ["Choices on the Tree are for good. Look before you choose.", "One branch closes as another opens."],
	"tree": ["For good, mind. The Tree doesn't forget."],
	"tree_buy": ["He doesn't sell these twice. Neither does he refund them.", "Crystals now, for something every visit after.", "A regular is made, not born. Usually with crystals."],
	"dine": ["They talk more over a meal. Most do.", "Listen closely. Some of them mean it.", "A climber at rest is a climber with stories."],
	"furnish": ["Brass, velvet and old wood. Someone cared, once.", "The train keeps everything in its place. I like that about it.", "Look closer. Everything here has a use."],
	"back": ["Back, then. Nothing's lost.", "Retreat is a kind of plan."],
	"close": ["Done here? I'll keep it as it is."],
	"any": ["I'd press it. Eventually.", "Simple enough. Mostly.", "You'll see. I already have.", "Go on. I'm watching."],
}))

## Small words the explanations are made with (and the Settings switch).
static var TEXT: Dictionary = RuneArtistName.named({
	"setting": "The Entity explains buttons",
	"better": "It beats what you'd wear.",
	"worse": "What you'd wear is better.",
	"even": "About as good as what you'd wear.",
	"crafter_you": " You craft it yourself.",
	"crafter_artist": " {rune_artist}, the Rune Artist here, crafts it for you: materials + premium.",
	"any_kind": " Any kind of essence pays for it: your fullest crystals first.",
	"counted": "%d of %d",
	"best": "Your best there: floor %d.",
	"best_none": "You haven't climbed it yet.",
})

## Which of a button's tags names its explanation, in order: [tag, how the
## key is made]. "raw": the tag's value is the key; "v": tag:value; "":
## the tag alone; the rest are worked out in key_for.
const TAGS := [
	["help", "raw"], ["rail", "v"], ["slot", "slot"], ["buy", "buy"], ["tower", ""], ["depart", ""], ["go_station", ""], ["station", ""],
	["board", "v"], ["store_tab", "v"], ["tree_buy", ""], ["put_back", ""], ["sell", ""],
	["equip", ""], ["move", "move"], ["unequip", "tail"], ["brew", ""], ["bench_tab", "v"],
	["bench_do", "v"], ["retrait", ""], ["retrait_pick", ""], ["join", ""], ["inscribe", ""],
	["vessel_pack", ""], ["vessel_brew", ""],
	["tech_slot", ""],
	["shelf", "shelf"], ["archive", ""], ["bestiary", ""], ["bestiary_locked", ""], ["panel_tab", "v"], ["ribbon", "tabbed"], ["tab", "v"], ["choice_key", "setting"], ["setting", "setting"],
	["over", ""], ["car_page", "v"], ["open_stash", ""], ["cycler", "v"], ["pick", "head"], ["station_do", "v"],
	["map_link", ""], ["ability", ""], ["try_abilities", ""], ["change_techniques", ""], ["part", ""], ["bud", ""], ["tree_act", "v"], ["back", ""], ["close", ""],
	["furnish", "v"],
]


## The stable id of a button's explanation ("" if none of its tags says).
static func key_for(b: Control) -> String:
	if b == null or not is_instance_valid(b):
		return ""
	for t in TAGS:
		var tag: String = t[0]
		if not b.has_meta(tag):
			continue
		var v = b.get_meta(tag)
		var s := str(v)
		match t[1]:
			"raw":
				return s
			"v":
				return "%s:%s" % [tag, s]
			"":
				return tag
			"setting":
				return "setting:" + s
			"head":
				return "%s:%s" % [tag, s.get_slice(":", 0)]
			"tail":
				return "%s:%s" % [tag, s.get_slice(":", s.get_slice_count(":") - 1)]
			"tabbed":
				return "tab:" + s if HELP.has("tab:" + s) else "ribbon"
			"move":
				return "move:chest" if s.begins_with("pack") else "move:pack"
			"shelf":
				return "shelf:bestiary" if s == "bestiary" else "shelf"
			"buy":
				var bits := s.split(":")
				if bits.size() == 1 and Items.ITEMS.has(Items.old_id(s)):
					return "buy:supply"
				var last: String = bits[bits.size() - 1]
				return "buy:" + last if last in ["chest", "wear", "hold"] else "buy"
			"slot":
				var head := s.get_slice(":", 0)
				var key := "slot:" + head
				if head == "bench":
					var sub := s.get_slice(":", 1)
					key = "slot:bench:" + sub if sub in ["item", "supply", "tincture", "craft", "x"] else "slot:bench"
				if b.get("empty") == true and HELP.has(key + ":empty"):
					key += ":empty"
				return key
	return ""


## The words for a key: its own, else the part before its last ":" ("" if none).
static func entry(key: String) -> String:
	var at := key
	while at != "":
		if HELP.has(at):
			return String(HELP[at])
		var cut := at.rfind(":")
		if cut <= 0:
			return ""
		at = at.left(cut)
	return ""


## True if a button has no explanation of its own (only its words).
static func missing(b: Control) -> bool:
	return entry(key_for(b)) == ""


## What the Entity says about a button: its entry, filled in from the game
## as it is now; else the button's own words; "" for nothing to say.
static func explain(m, b: Control) -> String:
	if b == null or not is_instance_valid(b):
		return ""
	var key := key_for(b)
	var text := entry(key)
	var f := facts(m, b, key)
	if text == "":
		text = String(f.get("words", ""))
		if text == "" and f.has("piece"):
			text = "{piece}"
	if f.has("pool") and text != "" and not text.contains("{pool}"):
		text += " {pool}"  # (an essence item's own pool, the bar along its top: item_pool.gd)
	return tidy(Entity.fill_words(text, f))


## The Entity's comment on a button (COMMENTS, by its kind): the same one for
## the same button each time; "" for none.
static func comment(b: Control) -> String:
	if b == null or not is_instance_valid(b):
		return ""
	var key := key_for(b)
	var list: Array = COMMENTS.get(comment_kind(key), COMMENTS.get("any", []))
	if list.is_empty():
		return ""
	return String(list[posmod(hash(key + "|" + words(b)), list.size())])


## The COMMENTS kind for a key: the part before ":" ("slot:pack" -> "slot"),
## else before "_" ("bench_tab:brew" -> "bench"), else "any".
static func comment_kind(key: String) -> String:
	var head := key.get_slice(":", 0)
	if COMMENTS.has(head):
		return head
	head = head.get_slice("_", 0)
	return head if COMMENTS.has(head) and head != "" else "any"


## Drops any blank left unfilled and the spaces around it.
static func tidy(text: String) -> String:
	var re := RegEx.create_from_string("\\{[a-z_]+\\}")
	text = re.sub(text, "", true)
	while text.contains("  "):
		text = text.replace("  ", " ")
	text = text.replace(" .", ".").replace(": .", ".").replace(" ,", ",")
	return text.strip_edges()


# --- the facts: what fills the blanks -------------------------------------------------------

## A button's words without the arrows and markers round them ("<  Show:
## Everything  >" -> "Show: Everything").
static func words(b: Control) -> String:
	var s := String(b.get("text")) if b.get("text") != null else ""
	s = s.replace("\n", " ").strip_edges()
	for mark in ["<", ">", "v "]:
		s = s.trim_prefix(mark).trim_suffix(mark).strip_edges()
	return s


static func _sentence(s: String) -> String:
	s = s.strip_edges()
	if s == "":
		return ""
	s = s.left(1).to_upper() + s.substr(1)
	return s if s.ends_with(".") or s.ends_with("!") or s.ends_with("?") else s + "."


static func _versus(m, g) -> String:
	if not Gear.is_gear(g) or m == null or m.main == null:
		return ""
	var vs := Train.versus(m.main.profile, m.main.player, g)
	return String(TEXT["better"] if vs > 0 else (TEXT["worse"] if vs < 0 else TEXT["even"]))


## "The Kraken's Tower" -> "the Kraken's Tower" (said in the middle of a
## sentence; {Tower} puts the capital back at the start of one).
static func lower_the(name: String) -> String:
	return "the" + name.substr(3) if name.begins_with("The ") else name


static func _piece_facts(m, g, f: Dictionary) -> void:
	if not Gear.is_gear(g):
		return
	f["piece"] = Gear.display(g)
	f["desc"] = Gear.desc(g)
	f["slot"] = String(Gear.SLOT_NAMES.get(Gear.slot_of(g), ""))
	f["versus"] = _versus(m, g)
	var Pools = load("res://scripts/item_pool.gd")
	if Pools.has_pool(g):
		f["pool"] = String(Pools.TEXT["hover"]) % String(Pools.TEXT["pool"] % [Pools.left(g), Pools.cap(g)])


static func _item_facts(id: String, f: Dictionary) -> void:
	var d: Dictionary = Items.ITEMS.get(id, {})
	if d.is_empty():
		return
	f["piece"] = String(d.get("name", id))
	f["desc"] = String(d.get("desc", ""))


static func _tower_facts(m, id: String, f: Dictionary) -> void:
	var t: Dictionary = Towers.TOWERS.get(id, {})
	if t.is_empty():
		return
	f["tower"] = lower_the(String(t.get("name", id)))
	f["essence"] = Essence.display(String(t.get("essence", "")))
	f["beast"] = String(t.get("beast", ""))
	var best := 0
	if m != null and m.main != null and m.main.profile != null:
		best = int(m.main.profile.record.get("best", {}).get(id, 0))
	f["best"] = str(best)
	f["best_line"] = String(TEXT["best"]) % best if best > 0 else String(TEXT["best_none"])
	f["wild_line"] = load("res://scripts/wild_towers.gd").help_line(m.main.profile if m != null and m.main != null else null, id)  # (its well runs wild: wild_towers.gd)


## The piece a card's button acts on: from its tag ("pack:2", "outfit:0",
## "today:chest", "helm:pack") or the slot whose card shows.
static func _subject(m, b: Control, key: String):
	if m == null or m.main == null or m.main.profile == null:
		return null
	var prof = m.main.profile
	for tag in ["sell", "equip", "move"]:
		if b.has_meta(tag):
			return _from_ref(prof, str(b.get_meta(tag)))
	if b.has_meta("unequip"):
		var slot := str(b.get_meta("unequip")).get_slice(":", 0)
		return Train.setoff(prof, m.main.player).get(slot, {}).get("rec", null)
	if b.has_meta("buy"):
		var v := str(b.get_meta("buy"))
		var head := v.get_slice(":", 0)
		match head:
			"outfit":
				var i := int(v.get_slice(":", 1))
				var o: Array = Train.outfit(prof)
				return o[i] if i >= 0 and i < o.size() else null
			"today":
				return Train.today(prof)
			"order":
				return Train.order(prof)
		return null
	var sel := String(m.inv_sel)
	if sel.begins_with("bench:"):
		var ref := sel.substr(6)
		if ref.begins_with("craft:"):
			return Gear.make(ref.substr(6))  # (a charm a Rune Artist could craft)
		if not ref.begins_with("item:") and not ref.begins_with("supply:"):
			return Bench.piece(prof, ref)
	return _from_ref(prof, sel)


static func _from_ref(prof, ref: String):
	var where := ref.get_slice(":", 0)
	var i := int(ref.get_slice(":", 1))
	var list: Array = prof.pack if where == "pack" else (prof.chest if where == "chest" else [])
	return list[i] if i >= 0 and i < list.size() else null


## Everything that may fill a button's blanks (cheap: only what its key needs).
static func facts(m, b: Control, key: String) -> Dictionary:
	var f := {"words": words(b)}
	if b.has_meta("help_facts"):
		f.merge(b.get_meta("help_facts"), true)  # (a button that brings its own facts: the engine's map)
	if b.has_meta("help_desc"):
		f["desc"] = str(b.get_meta("help_desc"))  # (a button that carries its own explanation: start_pages.gd's answers)
	var prof = m.main.profile if m != null and m.main != null else null
	var player = m.main.player if m != null and m.main != null else null
	var head := key.get_slice(":", 0)
	# A slot: the piece or item in it.
	if b.has_meta("slot"):
		var s := str(b.get_meta("slot"))
		var kind := String(b.get("kind")) if b.get("kind") != null else ""
		if b.get("rec") != null and Gear.is_gear(b.get("rec")):
			_piece_facts(m, b.get("rec"), f)
		elif kind == "item" and String(b.get("id")) != "":
			_item_facts(String(b.get("id")), f)
		if s.begins_with("worn:") and prof != null:
			var slot := s.get_slice(":", 1)
			f["slot"] = String(Gear.SLOT_NAMES.get(slot, slot.capitalize()))
			var e: Dictionary = Train.setoff(prof, player).get(slot, {})
			var from := String(e.get("from", ""))
			var LT: Dictionary = m.loadout_page.TEXT if m.get("loadout_page") != null else {}
			if LT.has("from_" + from):
				f["from"] = _sentence(String(LT["from_" + from]))
			if e.get("rec", null) != null:
				f["piece"] = Gear.display(e["rec"])
		if s.begins_with("supply:") and prof != null:
			var sk := s.get_slice(":", 1)
			var p: Array = Train.supply_price(prof, Items.old_id(sk))
			f["piece"] = Items.item_name(sk)
			f["price"] = Train.price_text(p[0], int(p[1]))
			if p[0] == Train.ANY:
				f["any"] = String(TEXT["any_kind"])  # (an everyday good: train.gd ANY_GOODS)
		if s.begins_with("bench:item:") and prof != null:
			f["price"] = Train.paid_text(Bench.brew_cost(prof, s.get_slice(":", 2)))
		if s.begins_with("bench:craft:"):
			f["price"] = Train.paid_text(Bench.craft_cost(s.get_slice(":", 2), prof))
		if (s.begins_with("outfit:") or s == "today" or s == "order" or s == "unique") and prof != null and Gear.is_gear(b.get("rec")):
			f["price"] = Train.price_text(Train.gear_kind(b.get("rec")), Train.buy_price(prof, b.get("rec")))
		if s.begins_with("tree:") and prof != null:
			_tree_facts(prof, s.substr(5), f)
		if s.begins_with("chest:") and prof != null:
			f["count"] = String(TEXT["counted"]) % [prof.chest.size(), Train.CHEST_SIZE]
		if s.begins_with("bench:"):
			f["counter"] = _counter_name(String(m.train_bench)).to_lower()
	# A card's button: the piece or item it acts on.
	if head in ["sell", "equip", "move", "unequip", "buy", "bench_do", "join", "inscribe", "retrait"]:
		var g = _subject(m, b, key)
		if Gear.is_gear(g):
			_piece_facts(m, g, f)
			if head == "sell":
				f["price"] = Train.price_text(Train.gear_kind(g), Train.gear_sell(g, prof))
			elif head == "buy" and prof != null:
				f["price"] = Train.price_text(Train.gear_kind(g), Train.buy_price(prof, g))
		elif head == "bench_do" and String(m.inv_sel).begins_with("bench:supply:"):
			_item_facts(String(m.inv_sel).get_slice(":", 2), f)
	if head == "tree_buy" and prof != null:
		_tree_facts(prof, str(b.get_meta("tree_buy")), f)
	if key == "buy:supply" and prof != null:
		var bk := str(b.get_meta("buy"))
		var id := Items.old_id(bk)
		_item_facts(id, f)
		f["piece"] = Items.item_name(id)
		var p: Array = Train.supply_price(prof, id)
		f["price"] = Train.price_text(p[0], int(p[1]))
		if p[0] == Train.ANY:
			f["any"] = String(TEXT["any_kind"])
	# Tinctures and crystals (pour_page.gd, the Workshop's tincture counter).
	if head in ["tincture_craft", "tincture_drink", "pour"] or (b.has_meta("slot") and String(b.get_meta("slot")).begins_with("bench:tincture:")):
		var sel := String(m.inv_sel) if m != null else ""
		var tid := sel.substr(sel.find("tincture_")) if sel.contains("tincture_") else ""
		if tid != "":
			_item_facts(tid, f)
		elif sel.begins_with("crystal:"):
			f["piece"] = String(Items.CRYSTAL["name"]) % Essence.display(sel.get_slice(":", 1))
		if b.has_meta("force_part") and prof != null:  # (Force it: forcing.gd)
			var fpart := str(b.get_meta("force_part"))
			f["force"] = str(int(round(float(load("res://scripts/forcing.gd").FORCE["cost"]))))
			var U = load("res://scripts/unbound.gd")
			if U.is_on(prof):
				f["part"] = "your " + U.node_name(fpart)
			else:
				var finfo: Dictionary = prof.bonds.get(fpart, {})
				f["part"] = "your %s mark" % String(load("res://scripts/bonds.gd").BONDS.get(String(finfo.get("id", "")), {}).get("name", fpart))
		if b.has_meta("pour_part") and prof != null:
			var part := str(b.get_meta("pour_part"))
			var info: Dictionary = prof.bonds.get(part, {})
			var B = load("res://scripts/bonds.gd")
			f["part"] = String(B.BONDS.get(String(info.get("id", "")), {}).get("name", "")) if not info.is_empty() else String(B.PART_NAMES.get(part, part)).to_lower()
		if b.has_meta("slot") and String(b.get_meta("slot")).begins_with("bench:tincture:") and prof != null:
			f["price"] = Train.paid_text(Bench.tincture_cost(prof, String(b.get_meta("slot")).get_slice(":", 2)))
	if b.has_meta("slot") and String(b.get_meta("slot")).begins_with("crystal:") and prof != null:
		var ck := String(b.get_meta("slot")).get_slice(":", 1)
		f["piece"] = String(Items.CRYSTAL["name"]) % Essence.display(ck)
		f["count"] = str(int(prof.crystal_total(ck)))
	if head in ["brew", "put_back"] and prof != null:
		var id := str(b.get_meta(head))
		_item_facts(id, f)
		if head == "brew":
			f["price"] = Train.paid_text(Bench.brew_cost(prof, id))
	# The engine.
	if head == "tower":
		_tower_facts(m, str(b.get_meta("tower")), f)
	if head == "depart":
		_tower_facts(m, str(b.get_meta("depart")), f)
	if head in ["station", "go_station"]:
		var st := Stations.station(str(b.get_meta(head)))
		f["station"] = String(st.get("name", "the station"))
	# The rail and the stash button.
	if head in ["open_stash"] or key == "car_page:stash":
		if prof != null:
			f["count"] = String(TEXT["counted"]) % [prof.chest.size(), Train.CHEST_SIZE]
	# The workshop's drawers.
	if head == "bench_tab":
		var c := str(b.get_meta(head))
		f["counter"] = _counter_name(c)
		if c in Bench.CRAFTED and prof != null:
			f["crafter"] = String(TEXT["crafter_artist"] if Bench.artist_crafts(prof) else TEXT["crafter_you"])
	if key == "rune_artist_npc":
		f["artist"] = String(Bench.ARTIST["name"])
	# The library.
	if head == "shelf":
		var gid := str(b.get_meta("shelf"))
		var ids: Array = Entity.ordered(gid)
		f["shelf"] = words(b)
		f["heard"] = str(ids.filter(func(k): return Guide.known(k)).size())
		f["total"] = str(ids.size())
	if head == "bestiary" or key == "shelf:bestiary":
		var Best = load("res://scripts/bestiary.gd")
		if head == "bestiary":
			f["name"] = Best.name_of(str(b.get_meta("bestiary")))
		var c: Array = Best.counts(prof)
		f["count"] = String(TEXT["counted"]) % [int(c[0]), int(c[1])]
	if head == "archive":
		f["archive"] = String(Entity.TIPS.get(str(b.get_meta("archive")), {}).get("name", words(b)))
	# Settings: the choice under the pointer.
	if b.has_meta("choice"):
		f["choice"] = words(b)
	# The book.
	if head == "ability":
		_ability_facts(str(b.get_meta("ability")), f)
	# A station's tiles.
	if head == "pick":
		_pick_facts(m, str(b.get_meta("pick")), f)
	return f


## A node of the outfitter's upgrade tree (outfitter.gd): its name, what it
## does, its price, and whether it's yours, open or what it still needs.
static func _tree_facts(prof, id: String, f: Dictionary) -> void:
	var O = load("res://scripts/outfitter.gd")
	if not O.exists(id):
		return
	f["piece"] = O.node_name(id)
	f["desc"] = O.node_desc(id)
	f["price"] = Train.price_text(Train.ANY, O.cost(id))
	var st: String = O.status(prof, id)
	if O.is_trunk(id):
		f["state"] = String(O.TEXT["reached"] if st == "bought" else O.TEXT["to_reach"] % [Renown.rank_name(O.trunk_rank(id)), Renown.needed(O.trunk_rank(id))])
	elif st == "locked":
		f["state"] = String(O.TEXT["needs"]) % ", ".join(O.locks(prof, id))
	else:
		f["state"] = String(O.TEXT["bought"] if st == "bought" else O.TEXT["ready"])


static func _counter_name(id: String) -> String:
	for c in Bench.COUNTERS:
		if c[0] == id:
			return String(c[1])
	return id.capitalize()


static func _ability_facts(id: String, f: Dictionary) -> void:
	var B = load("res://scripts/bonds.gd")
	for bid in B.BONDS:
		for sp in B.BONDS[bid].get("spells", []):
			if String(sp.get("id", "")) == id:
				f["ability"] = String(sp.get("name", id))
				f["desc"] = String(sp.get("desc", ""))
				return


static func _pick_facts(m, pick: String, f: Dictionary) -> void:
	var kind := pick.get_slice(":", 0)
	var id := pick.get_slice(":", 1)
	match kind:
		"drill":
			f["name"] = String(Stations.DRILLS.get(id, {}).get("name", id))
			f["desc"] = Stations.drill_goal(id)
		"lesson":
			f["name"] = String(Stations.LESSONS.get(id, {}).get("name", id))
			f["desc"] = Stations.lesson_goal(id)
		"basics":
			var Tu = load("res://scripts/tutorial.gd")
			f["n"] = str(Tu.count())
			f["desc"] = Tu.tile_line(m.main.profile if m != null and m.main != null else null) + "."
		"bracket":
			f["name"] = String(Stations.bracket(id).get("name", id))
		"title":
			var t: Dictionary = Renown.TITLES.get(id, {})
			f["name"] = _sentence(String(t.get("name", id))).trim_suffix(".")
			var gives: Array = Titles.lines(id)
			f["desc"] = String(t.get("deed", "")) + (" Gives: " + String(gives[0]) + "." if not gives.is_empty() else "")
		"contract":
			var o: Dictionary = Contracts.find(m.main.profile, id) if m != null and m.main != null else {}
			f["name"] = Contracts.name_of(o) if not o.is_empty() else id
			f["desc"] = Contracts.goal_of(o) if not o.is_empty() else ""
		"ask":
			var a: Dictionary = Contracts.ask(m.main.profile) if m != null and m.main != null else {}
			f["name"] = Contracts.ask_name(a) if not a.is_empty() else ""
			f["desc"] = Contracts.ask_goal(a) if not a.is_empty() else ""
		"rank":
			f["name"] = Renown.rank_name(int(id))
			f["desc"] = "it opens " + ", ".join(Renown.opens(int(id))) + "."
		"rival":
			var Rv = load("res://scripts/rivals.gd")
			var rec: Dictionary = Rv.state(m.main.profile if m != null and m.main != null else null).get(id, {})
			f["name"] = String(rec.get("name", id))
			f["desc"] = Rv.marks_text(rec) + ". " + Rv.history_text(rec) + "."
		"advanced":
			var Tr = load("res://scripts/training.gd")
			f["name"] = String(Tr.lesson(id).get("name", id))
			f["desc"] = Tr.lesson_goal(id)
		"manager":
			var Tm = load("res://scripts/tournaments.gd")
			f["name"] = Tm.station_name(Tm.here(m.main.profile)) if m != null and m.main != null else ""
