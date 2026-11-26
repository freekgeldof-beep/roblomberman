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
	KICK_SPEED = 9, -- vakjes per seconde voor een geschopte bom

	START_BOMBS = 1,
	START_RANGE = 2,
	START_SPEED = 16,
	MAX_BOMBS = 6,
	MAX_RANGE = 8,
	MAX_SPEED = 26,
	SPEED_STEP = 2,

	CURSE_TIME = 10, -- seconden dat een 💀-vloek duurt
	CURSE_SLOW_SPEED = 8, -- loopsnelheid met de "traag"-vloek

	ROUND_TIME = 150, -- seconden tot sudden death begint
	SUDDEN_DEATH_STEP = 0.35, -- seconden tussen twee vallende muurblokken

	CORNER_ASSIST = true, -- automatisch de gang in schuiven bij hoeken
	CORNER_TOLERANCE = 0.7, -- hoe ver (in vakjes) je naast een gang mag staan

	INTERMISSION = 7, -- seconden tussen rondes (eindscherm)
	MAX_PLAYERS = 4,

	PLAYER_COLORS = {
		{ name = "Rood", color = Color3.fromRGB(235, 70, 70) },
		{ name = "Blauw", color = Color3.fromRGB(70, 140, 255) },
		{ name = "Geel", color = Color3.fromRGB(255, 210, 60) },
		{ name = "Groen", color = Color3.fromRGB(80, 210, 100) },
	},

	-- Geluiden. Vervang een id door een eigen geluid uit de Creator Store
	-- ("rbxassetid://123..."), of zet hem op "" om dat geluid uit te zetten.
	-- De ontploffing zelf komt van Roblox' eigen Explosion-effect.
	SOUNDS = {
		Place = { id = "rbxasset://sounds/button.wav", volume = 0.6 },
		Throw = { id = "rbxasset://sounds/swoosh.wav", volume = 0.7 },
		Kick = { id = "rbxasset://sounds/swoosh.wav", volume = 0.7, speed = 1.4 },
		Pickup = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, speed = 1.2 },
		Curse = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, speed = 0.55 },
		Wall = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.8 },
		Death = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.7 },
		Beep = { id = "rbxasset://sounds/button.wav", volume = 0.8, speed = 0.8 },
		Go = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.9 },
		Win = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.9, speed = 1.5 },
		Explosion = { id = "", volume = 0.8 }, -- optioneel: extra ontploffingsgeluid
	},
}
