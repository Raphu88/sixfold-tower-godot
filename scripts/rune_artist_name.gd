extends RefCounted
## The Rune Artist's name, in one place. She works the workshop's bench on
## the train (bench.gd ARTIST: she crafts for climbers without the Rune
## Artist's mark) and is spoken of as she/her. "the Rune Artist" stays her
## role ("Rayne, the Rune Artist"); a climber who carries that mark is "a
## Rune Artist" too, so only lines about her use her name.
##
## Every line that names her writes "{rune_artist}" where her name goes (the
## bench's words, the Entity's tips and topics, its hover help, the Exchange,
## what Joel says of her...), and each of those tables is passed through
## named() as it's made, so changing NAME here renames her everywhere at
## once (bench.gd ARTIST "name" is this too, which the Entity's "{artist}"
## fills from).

const NAME := "Rayne"
const KEY := "{rune_artist}"
## Her role, written after her name where it reads better.
const ROLE := "the Rune Artist"


## `v` with every "{rune_artist}" in its words (in nested dictionaries and
## arrays too) turned into her name. Changes `v` in place and returns it.
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
