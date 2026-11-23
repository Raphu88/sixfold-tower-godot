extends RefCounted
## The outfitter's name, in one place. He keeps the Outfitter's Car (the
## store on the train, store_page.gd) and is spoken of as he/him.
##
## Every line that names him writes "{outfitter}" where his name goes (the
## Entity's tips and topics, its hover help, his own tag, the tour...), and
## each of those tables is passed through named() as it's made, so changing
## NAME here renames him everywhere at once.

const NAME := "Joel"
const KEY := "{outfitter}"


## `v` with every "{outfitter}" in its words (in nested dictionaries and
## arrays too) turned into his name. Changes `v` in place and returns it.
static func named(v):
	if v is String:
		return v.replace(KEY, NAME)
	if v is Dictionary:
		for k in v.keys():
			v[k] = named(v[k])
	elif v is Array:
		for i in v.size():
			v[i] = named(v[i])
	return v
