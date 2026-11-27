-- Goodies: what they do, spawning, picking them up, and the 💀 curses
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage:WaitForChild("BombConfig"))
local Grid = require(script.Parent.Grid)
local S = require(script.Parent.State)
local Net = require(script.Parent.Net)
local Sounds = require(script.Parent.Sounds)
local GoodieModels = require(script.Parent.GoodieModels)

local Powerups = {}

-- Curse kinds; the text shown to players is the Lang key "curse_<kind>"
local CURSE_KINDS = { "slow", "nobombs", "autobomb" }

local DEFS = {
	Range = {
		emoji = "🔥", color = Color3.fromRGB(255, 120, 40), weight = 25,
		apply = function(s) s.range = math.min(s.range + 1, Config.MAX_RANGE) end,
	},
	Bomb = {
		emoji = "💣", color = Color3.fromRGB(90, 90, 110), weight = 25,
		apply = function(s) s.maxBombs = math.min(s.maxBombs + 1, Config.MAX_BOMBS) end,
	},
	Speed = {
		emoji = "👟", color = Color3.fromRGB(80, 200, 255), weight = 15,
		apply = function(s) s.speed = math.min(s.speed + Config.SPEED_STEP, Config.MAX_SPEED) end,
	},
	Pierce = {
		emoji = "⚡", color = Color3.fromRGB(255, 230, 60), weight = 10,
		apply = function(s) s.pierce = true end,
	},
	Throw = {
		emoji = "🧤", color = Color3.fromRGB(120, 255, 120), weight = 12,
		apply = function(s) s.throw = true end,
	},
	Kick = {
		emoji = "🦶", color = Color3.fromRGB(255, 150, 220), weight = 12,
		apply = function(s) s.kick = true end,
	},
	-- Rare ones: hard to find, and they sparkle when they do show up
	Punch = {
		emoji = "🥊", color = Color3.fromRGB(255, 60, 60), weight = 3, rare = true,
		apply = function(s) s.punch = true end,
	},
	MaxFire = {
		emoji = "🌋", color = Color3.fromRGB(255, 200, 0), weight = 2, rare = true,
		apply = function(s) s.range = Config.MAX_RANGE end,
	},
	Skull = {
		emoji = "💀", color = Color3.fromRGB(150, 60, 200), weight = 8,
		apply = function(s)
			s.curse = CURSE_KINDS[math.random(#CURSE_KINDS)]
			s.curseUntil = os.clock() + Config.CURSE_TIME
		end,
	},
}
Powerups.DEFS = DEFS
local ORDER = { "Range", "Bomb", "Speed", "Pierce", "Throw", "Kick", "Punch", "MaxFire", "Skull" }

function Powerups.pick()
	local total = 0
	for _, kind in ipairs(ORDER) do
		total += DEFS[kind].weight
	end
	local r = math.random() * total
	for _, kind in ipairs(ORDER) do
		r -= DEFS[kind].weight
		if r <= 0 then
			return kind
		end
	end
	return "Range"
end

function Powerups.newStats()
	return {
		maxBombs = Config.START_BOMBS,
		range = Config.START_RANGE,
		speed = Config.START_SPEED,
		pierce = false,
		throw = false,
		kick = false,
		punch = false,
		curse = nil,
		curseUntil = 0,
		active = 0,
		held = nil,
		lastAction = 0,
		invulUntil = 0,
	}
end

function Powerups.sync(player)
	local s = S.stats[player]
	if not s then
		return
	end
	player:SetAttribute("Bombs", s.maxBombs)
	player:SetAttribute("Range", s.range)
	player:SetAttribute("Speed", s.speed)
	player:SetAttribute("Pierce", s.pierce)
	player:SetAttribute("Throw", s.throw)
	player:SetAttribute("Kick", s.kick)
	player:SetAttribute("Punch", s.punch)
	player:SetAttribute("Curse", s.curse and ("curse_" .. s.curse) or nil)
	local hum = S.getHum(player)
	if hum then
		hum.WalkSpeed = s.curse == "slow" and Config.CURSE_SLOW_SPEED or s.speed
	end
end

-- burned = true: the goodie was hit by fire, show a little "poof" before it goes
function Powerups.remove(k, burned)
	local pu = S.powerups[k]
	if not pu then
		return
	end
	S.powerups[k] = nil
	pu.model:Destroy()
	if not burned then
		pu.base:Destroy()
		return
	end
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(1, 0, 0) -- the disc is turned on its side: local +X is up
	att.Parent = pu.base
	local poof = Instance.new("ParticleEmitter")
	poof.Rate = 0
	poof.Lifetime = NumberRange.new(0.3, 0.6)
	poof.Speed = NumberRange.new(6, 12)
	poof.SpreadAngle = Vector2.new(180, 180)
	poof.LightEmission = 0.6
	poof.Color = ColorSequence.new(DEFS[pu.kind].color, Color3.fromRGB(60, 60, 60))
	poof.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	poof.Parent = att
	poof:Emit(24)
	pu.base.Transparency = 1
	Debris:AddItem(pu.base, 0.8)
end

-- A goodie is a glowing disc on the floor with a small 3D model floating above it
-- (see GoodieModels). The model is tagged "Goodie3D" so every client spins and
-- bobs it smoothly on its own screen.
function Powerups.spawn(x, z, kind)
	local def = DEFS[kind]
	local cell = Grid.cellPos(x, z)

	local base = Instance.new("Part")
	base.Name = "GoodieBase"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(0.2, Grid.T - 0.8, Grid.T - 0.8)
	base.CFrame = CFrame.new(cell + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	base.Material = Enum.Material.Neon
	base.Color = def.color
	base.Transparency = 0.35
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.Parent = S.arena

	local model = GoodieModels.build(kind)
	local center = cell + Vector3.new(0, 2.1, 0)
	model:PivotTo(CFrame.new(center))
	model:SetAttribute("Base", center)
	CollectionService:AddTag(model, "Goodie3D")
	if def.rare then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = def.color
		sparkles.Parent = base
		base.Color = Color3.fromRGB(255, 215, 70)
	end
	model.Parent = S.arena
	S.powerups[Grid.key(x, z)] = { model = model, base = base, kind = kind }
end

-- When someone dies, the goodies they collected are scattered over free cells
function Powerups.scatter(s)
	local kinds = {}
	local function add(kind, n)
		for _ = 1, n do
			kinds[#kinds + 1] = kind
		end
	end
	add("Bomb", s.maxBombs - Config.START_BOMBS)
	add("Range", s.range - Config.START_RANGE)
	add("Speed", math.floor((s.speed - Config.START_SPEED) / Config.SPEED_STEP))
	add("Pierce", s.pierce and 1 or 0)
	add("Throw", s.throw and 1 or 0)
	add("Kick", s.kick and 1 or 0)
	add("Punch", s.punch and 1 or 0)
	if #kinds == 0 then
		return
	end
	-- shuffle and cap, so a max-fire player doesn't flood the arena
	for i = #kinds, 2, -1 do
		local j = math.random(i)
		kinds[i], kinds[j] = kinds[j], kinds[i]
	end
	local myGen = S.gen
	task.delay(Config.FLAME_TIME + 0.1, function()
		if myGen ~= S.gen then
			return
		end
		local free = {}
		for x = 1, Grid.W do
			for z = 1, Grid.H do
				local k = Grid.key(x, z)
				if not S.terrain[k] and not S.bombAt[k] and not S.powerups[k] and not S.warps[k]
					and not S.playerOnCell(Grid.cellOf, x, z) then
					free[#free + 1] = { x, z }
				end
			end
		end
		for i = 1, math.min(#kinds, Config.DEATH_DROP_MAX, #free) do
			local c = table.remove(free, math.random(#free))
			Powerups.spawn(c[1], c[2], kinds[i])
		end
	end)
end

-- Every frame: pick up goodies and let curses run out
function Powerups.update(now)
	for plr in pairs(S.alive) do
		local root = S.getRoot(plr)
		local s = S.stats[plr]
		if root and s then
			local x, z = Grid.cellOf(root.Position)
			local k = Grid.key(x, z)
			local pu = S.powerups[k]
			if pu then
				local def = DEFS[pu.kind]
				def.apply(s)
				Powerups.remove(k)
				Powerups.sync(plr)
				if pu.kind == "Skull" then
					Net.announce({ k = "curse_" .. s.curse }, 2.5, true, plr)
					Sounds.play("Curse", root.Position)
				else
					Net.announce({ k = "pu_" .. pu.kind }, 1.8, true, plr)
					Sounds.play("Pickup", root.Position)
				end
			end
			if s.curse and now >= s.curseUntil then
				s.curse = nil
				Powerups.sync(plr)
				Net.announce({ k = "curse_over" }, 1.8, true, plr)
			end
		end
	end
end

return Powerups
