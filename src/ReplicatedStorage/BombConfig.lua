-- Shared settings (server + client)
return {
	TILE = 4, -- size of one cell in studs

	-- The arena grows with the number of players (width/height in cells, always odd).
	-- With 1 + a multiple of 4 (13, 17, 21, 25) the middle is nicely symmetrical.
	ARENA_SIZES = {
		{ players = 2, w = 13, h = 13 },
		{ players = 4, w = 17, h = 13 },
		{ players = 6, w = 21, h = 17 },
		{ players = 8, w = 25, h = 17 },
	},

	CRATE_CHANCE = 0.75, -- chance that a free cell becomes a crate
	DROP_CHANCE = 0.4, -- chance that a broken crate drops a goodie

	FUSE = 2.6, -- seconds until a bomb explodes
	FLAME_TIME = 0.6, -- how long the fire stays
	THROW_DISTANCE = 3, -- minimum throw distance in cells
	THROW_SPEED = 30, -- studs per second
	PUNCH_DISTANCE = 3, -- cells a 🥊 punch sends a bomb
	KICK_SPEED = 9, -- cells per second for a kicked bomb

	START_BOMBS = 1,
	START_RANGE = 2,
	START_SPEED = 16,
	MAX_BOMBS = 6,
	MAX_RANGE = 8,
	MAX_SPEED = 26,
	SPEED_STEP = 2,

	CURSE_TIME = 10, -- seconds a 💀 curse lasts
	CURSE_SLOW_SPEED = 8, -- walk speed with the "slow" curse

	ROUND_TIME = 150, -- seconds until sudden death starts
	SUDDEN_DEATH_STEP = 0.35, -- seconds between two falling wall blocks

	CORNER_ASSIST = true, -- slide into the corridor automatically at corners
	CORNER_TOLERANCE = 0.7, -- how far (in cells) you may be off a corridor

	INTERMISSION = 7, -- seconds between rounds (scoreboard)
	MATCH_WINS = 3, -- a match is "first to this many round wins" (0 = no matches, just rounds)
	MAX_PLAYERS = 8,

	-- Computer opponents: bots fill the round up to this many players (0 = no bots)
	BOT_FILL = 4,
	BOT_THINK = 0.25, -- seconds between bot decisions (lower = faster, harder)
	BOT_AGGRESSION = 0.6, -- chance a bot drops a bomb when it has a good spot (0..1)

	-- Camera: follows your own player from above. Roughly this many cells are visible.
	CAMERA_FOLLOW = true,
	CAMERA_VIEW_W = 15,
	CAMERA_VIEW_H = 11,
	CAMERA_SMOOTH = 6, -- how fast the camera catches up (higher = tighter)

	-- Special cells. Every round each kind is rolled separately,
	-- so every round is different. Set a chance to 1 to always have it, or 0 to turn it off.
	FEATURE_CHANCE = {
		Warps = 0.75, -- warp zones: step on one and come out at the other
		Belts = 0.75, -- conveyor belts: push players and bombs along
		Toggles = 0.6, -- switch walls: go up and down every few seconds
		Ice = 0.5, -- ice patches: you keep sliding when you let go
	},
	WARP_COOLDOWN = 0.6, -- seconds before a warp can send you again
	BELT_SPEED = 7, -- studs per second a belt carries you
	BELT_BOMB_SPEED = 3, -- cells per second for a bomb on a belt
	TOGGLE_INTERVAL = 6, -- seconds between switch walls going up and down
	ICE_SHARE = 0.18, -- share of open cells that turn to ice
	ICE_GRIP = 1.2, -- how fast you stop sliding on ice (lower = more slippery)

	PLAYER_COLORS = {
		{ name = "color_1", color = Color3.fromRGB(235, 70, 70) },
		{ name = "color_2", color = Color3.fromRGB(70, 140, 255) },
		{ name = "color_3", color = Color3.fromRGB(255, 210, 60) },
		{ name = "color_4", color = Color3.fromRGB(80, 210, 100) },
		{ name = "color_5", color = Color3.fromRGB(170, 90, 240) },
		{ name = "color_6", color = Color3.fromRGB(255, 140, 40) },
		{ name = "color_7", color = Color3.fromRGB(255, 120, 200) },
		{ name = "color_8", color = Color3.fromRGB(60, 220, 230) },
	},

	-- Sounds. Replace an id with your own sound from the Creator Store
	-- ("rbxassetid://123..."), or set it to "" to turn that sound off.
	-- The explosion itself uses Roblox's own Explosion effect.
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
		Warp = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, speed = 0.8 },
		Toggle = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.4, speed = 1.3 },
		Explosion = { id = "", volume = 0.8 }, -- optional: extra explosion sound
	},
}
