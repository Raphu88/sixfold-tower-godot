extends RefCounted
## The climber's pronouns: he, she or they, chosen at character creation
## (the name step; changed later on the Appearance page) and kept with the
## look (profile.appearance["pronouns"]). Everyone who speaks of the climber
## uses them: the Entity, rivals, the Noble, the Makers, notices and logs.
##
## Write a line that speaks of the climber with these tokens, and it is
## filled with the climber's own words when it shows:
##   {they} {them} {their} {theirs} {themself}   he / him / his / his / himself...
##   {They} {Them} {Their} {Theirs} {Themself}   the same, capitalised
##   {are} {were} {have} {do}                   is / was / has / does (they: are / were / have / do)
##   {s} {es}                                   a verb's ending: "{they} climb{s}" is
##                                              "she climbs" or "they climb"; "reach{es}"
##   {they're} {They're} {they've} {They've}    contractions
## fill() is called on every tip, Entity bubble, page text, notice and log
## line (entity.gd fill_keys / fill_words / says, menu.gd _text,
## notices.gd), so a token works anywhere text is shown. `current` is the
## climber being played (main.gd apply_appearance sets it); fill_for() uses
## another climber's (the climber picker).
##
## Every word is here, in FORMS, so the owner can add or change pronouns.

## The choices, in order: [id, name on the button].
static var CHOICES := [["he", "He / him"], ["she", "She / her"], ["they", "They / them"]]

## Each pronoun's words. A new one needs every key.
static var FORMS := {
	"he": {"they": "he", "them": "him", "their": "his", "theirs": "his", "themself": "himself",
		"are": "is", "were": "was", "have": "has", "do": "does", "s": "s", "es": "es", "they're": "he's", "they've": "he's"},
	"she": {"they": "she", "them": "her", "their": "her", "theirs": "hers", "themself": "herself",
		"are": "is", "were": "was", "have": "has", "do": "does", "s": "s", "es": "es", "they're": "she's", "they've": "she's"},
	"they": {"they": "they", "them": "them", "their": "their", "theirs": "theirs", "themself": "themself",
		"are": "are", "were": "were", "have": "have", "do": "do", "s": "", "es": "", "they're": "they're", "they've": "they've"},
}

const DEFAULT := "they"

## The climber being played (main.gd apply_appearance).
static var current := DEFAULT


static func valid(id: String) -> bool:
	return FORMS.has(id)


## The pronouns kept in a look ("they" if none or unknown).
static func of_look(app) -> String:
	if app is Dictionary:
		var id := String(app.get("pronouns", DEFAULT))
		if valid(id):
			return id
	return DEFAULT


## One word: word("their") for the current climber, word("Their") capitalised.
static func word(key: String, id := "") -> String:
	var p: Dictionary = FORMS.get(id if valid(id) else current, FORMS[DEFAULT])
	var low := key.to_lower()
	var w := String(p.get(low, key))
	if key.length() > 0 and key.left(1) != key.left(1).to_lower():
		return w.left(1).to_upper() + w.substr(1)
	return w


## Fills the tokens with the current climber's pronouns.
static func fill(text: String) -> String:
	return fill_for(text, current)


## Fills the tokens with a given climber's pronouns ("he", "she", "they").
static func fill_for(text: String, id: String) -> String:
	if not ("{" in text):
		return text
	var p: Dictionary = FORMS.get(id if valid(id) else DEFAULT, FORMS[DEFAULT])
	for k in p:
		var tag := "{%s}" % k
		if text.contains(tag):
			text = text.replace(tag, String(p[k]))
		var cap := "{%s}" % (String(k).left(1).to_upper() + String(k).substr(1))
		if text.contains(cap):
			var w := String(p[k])
			text = text.replace(cap, w.left(1).to_upper() + w.substr(1))
	return text
