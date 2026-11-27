-- Goodies: what they do, spawning, picking them up, and the 💀 curses
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("BombConfig"))
local Grid = require(script.Parent.Grid)
local S = require(script.Parent.State)
local Net = require(script.Parent.Net)
local Sounds = require(script.Parent.Sounds)

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
	Skull = {
		emoji = "💀", color = Color3.fromRGB(150, 60, 200), weight = 8,
		apply = function(s)
			s.curse = CURSE_KINDS[math.random(#CURSE_KINDS)]
			s.curseUntil = os.clock() + Config.CURSE_TIME
		end,
	},
}
Powerups.DEFS = DEFS
local ORDER = { "Range", "Bomb", "Speed", "Pierce", "Throw", "Kick", "Skull" }

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
	player:SetAttribute("Curse", s.curse and ("curse_" .. s.curse) or nil)
	local hum = S.getHum(player)
	if hum then
		hum.WalkSpeed = s.curse == "slow" and Config.CURSE_SLOW_SPEED or s.speed
	end
end

function Powerups.remove(k)
	local pu = S.powerups[k]
	if pu then
		pu.part:Destroy()
		S.powerups[k] = nil
	end
end

function Powerups.spawn(x, z, kind)
	local def = DEFS[kind]
	local p = Instance.new("Part")
	p.Name = "Goodie_" .. kind
	p.Size = Vector3.new(2.4, 2.4, 2.4)
	p.Material = Enum.Material.Neon
	p.Color = def.color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Position = Grid.cellPos(x, z) + Vector3.new(0, 2, 0)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(64, 64)
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = def.emoji
	label.TextScaled = true
	label.Parent = gui

	p.Parent = S.arena
	TweenService:Create(p, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = Grid.cellPos(x, z) + Vector3.new(0, 2.8, 0),
	}):Play()
	S.powerups[Grid.key(x, z)] = { part = p, kind = kind }
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
