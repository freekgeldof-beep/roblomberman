-- Gedeelde instellingen (server + client)
return {
	TILE = 4, -- grootte van één vakje in studs
	WIDTH = 15, -- aantal vakjes (oneven!)
	HEIGHT = 13, -- aantal vakjes (oneven!)

	CRATE_CHANCE = 0.75, -- kans dat een vrij vakje een kist wordt
	DROP_CHANCE = 0.4, -- kans dat een kapotte kist een goodie laat vallen

	FUSE = 2.6, -- seconden tot een bom ontploft
	FLAME_TIME = 0.6, -- hoe lang het vuur blijft
	THROW_DISTANCE = 3, -- minimale gooi-afstand in vakjes
	THROW_SPEED = 30, -- studs per seconde

	START_BOMBS = 1,
	START_RANGE = 2,
	START_SPEED = 16,
	MAX_BOMBS = 6,
	MAX_RANGE = 8,
	MAX_SPEED = 26,
	SPEED_STEP = 2,

	INTERMISSION = 6, -- seconden tussen rondes
	MAX_PLAYERS = 4,
}
