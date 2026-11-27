-- Computer opponents ("bots").
-- A bot is a Folder that stands in for a Player: it is used as the key in
-- S.stats / S.alive, holds the same attributes (Color, Bombs, ...) and has a
-- leaderstats folder with Wins. Its character model is kept in S.botChars.
--
-- Every BOT_THINK seconds each bot looks at the grid and picks one goal:
--   1. standing in danger  -> walk to the nearest safe cell
--   2. goodie nearby       -> pick it up
--   3. enemy or crate in reach and an escape route exists -> place a bomb
--   4. otherwise           -> walk towards the nearest enemy / crate
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage:WaitForChild("BombConfig"))
local Grid = require(script.Parent.Grid)
local S = require(script.Parent.State)
local Bombs = require(script.Parent.Bombs)

local key = Grid.key
local Bots = {}

local folder = Instance.new("Folder")
folder.Name = "Bots"
folder.Parent = ServerStorage

local botList = {} -- all bot Folders ever made, so their wins are kept between rounds
local brain = {} -- bot -> { nextThink, target = {x, z} }

local BOT_NAMES = { "Bommetje", "Knaller", "Vonk", "Lontje", "Boemboem", "Sissy", "Kaboom" }

----------------------------------------------------------------------
-- Creating bots
----------------------------------------------------------------------
function Bots.get(count)
	while #botList < count do
		local i = #botList + 1
		local bot = Instance.new("Folder")
		bot.Name = "Bot" .. i
		bot:SetAttribute("DisplayName", "🤖 " .. (BOT_NAMES[i] or ("Bot " .. i)))
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local wins = Instance.new("IntValue")
		wins.Name = "Wins"
		wins.Parent = ls
		ls.Parent = bot
		bot.Parent = folder
		botList[i] = bot
	end
	local out = {}
	for i = 1, count do
		out[i] = botList[i]
	end
	return out
end

function Bots.all()
	return botList
end

-- Build a character model for the bot at the given CFrame
function Bots.spawn(bot, cframe)
	local old = S.botChars[bot]
	if old then
		old:Destroy()
	end
	local desc = Instance.new("HumanoidDescription")
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("Roblomberman: could not create bot character", model)
		return nil
	end
	model.Name = bot.Name
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = S.nameOf(bot)
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	model.Parent = workspace
	model:PivotTo(cframe)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		root:SetNetworkOwner(nil) -- the server moves bots
	end
	S.botChars[bot] = model
	brain[bot] = { nextThink = 0 }
	return model
end

function Bots.clearCharacters()
	for bot, model in pairs(S.botChars) do
		model:Destroy()
		S.botChars[bot] = nil
	end
	table.clear(brain)
end

----------------------------------------------------------------------
-- Grid knowledge
----------------------------------------------------------------------
-- Cells a bomb at (x, z) would hit, same rules as Bombs.explode
local function blastCells(x, z, range, pierce, out)
	out[key(x, z)] = true
	for _, d in ipairs(Grid.DIRS) do
		for i = 1, range do
			local cx, cz = x + d[1] * i, z + d[2] * i
			if not Grid.inBounds(cx, cz) then
				break
			end
			local t = S.terrain[key(cx, cz)]
			if t == "wall" then
				break
			end
			out[key(cx, cz)] = true
			if (t == "crate" and not pierce) or S.bombAt[key(cx, cz)] then
				break
			end
		end
	end
	return out
end

-- Every cell that is on fire or will be hit by a bomb that is already ticking
local function dangerMap()
	local danger = {}
	for b in pairs(S.bombs) do
		if not b.exploded then
			blastCells(b.x, b.z, b.range, b.pierce, danger)
		end
	end
	for _, f in ipairs(S.flames) do
		for k in pairs(f.cells) do
			danger[k] = true
		end
	end
	return danger
end

local function fireNow()
	local fire = {}
	for _, f in ipairs(S.flames) do
		for k in pairs(f.cells) do
			fire[k] = true
		end
	end
	return fire
end

local function walkable(x, z, fire)
	if not Grid.inBounds(x, z) then
		return false
	end
	local k = key(x, z)
	return not S.terrain[k] and not S.bombAt[k] and not fire[k]
end

-- Breadth-first search from (sx, sz). goal(x, z, k) returns true for a target cell.
-- avoid[k] = true marks cells we do not want to walk through.
-- Returns the first step {x, z} and the path length, or nil.
local function bfs(sx, sz, goal, fire, avoid, maxLen)
	local start = key(sx, sz)
	local prev = { [start] = false }
	local dist = { [start] = 0 }
	local queue = { { sx, sz } }
	local head = 1
	while head <= #queue do
		local c = queue[head]
		head += 1
		local k = key(c[1], c[2])
		if goal(c[1], c[2], k) then
			if k == start then
				return { sx, sz }, 0
			end
			-- walk back along the path to find the first step
			local cur = k
			while prev[cur].k ~= start do
				cur = prev[cur].k
			end
			return prev[cur].c, dist[k]
		end
		if dist[k] < (maxLen or 99) then
			for _, d in ipairs(Grid.DIRS) do
				local nx, nz = c[1] + d[1], c[2] + d[2]
				local nk = key(nx, nz)
				if prev[nk] == nil and walkable(nx, nz, fire) and not (avoid and avoid[nk]) then
					prev[nk] = { k = k, c = { nx, nz } }
					dist[nk] = dist[k] + 1
					queue[#queue + 1] = { nx, nz }
				end
			end
		end
	end
	return nil
end

local function enemiesInLine(bot, x, z, range)
	for _, d in ipairs(Grid.DIRS) do
		for i = 1, range do
			local cx, cz = x + d[1] * i, z + d[2] * i
			if not Grid.inBounds(cx, cz) or S.terrain[key(cx, cz)] then
				break
			end
			local p = S.playerOnCell(Grid.cellOf, cx, cz)
			if p and p ~= bot then
				return true
			end
		end
	end
	return false
end

local function crateNext(x, z)
	for _, d in ipairs(Grid.DIRS) do
		if S.terrain[key(x + d[1], z + d[2])] == "crate" then
			return true
		end
	end
	return false
end

-- Would the bot still be able to run to safety after dropping a bomb here?
local function canEscape(x, z, s, fire)
	local danger = dangerMap()
	blastCells(x, z, s.range, s.pierce, danger)
	local steps = math.floor(Config.FUSE * s.speed / Grid.T) - 1
	return bfs(x, z, function(_, _, k)
		return not danger[k]
	end, fire, nil, steps) ~= nil
end

----------------------------------------------------------------------
-- Thinking and moving
----------------------------------------------------------------------
local function think(bot, s, root, hum)
	local x, z = Grid.cellOf(root.Position)
	local fire = fireNow()
	local danger = dangerMap()
	local mem = brain[bot]
	mem.target = nil

	-- 1. get out of danger
	if danger[key(x, z)] then
		local step = bfs(x, z, function(_, _, k)
			return not danger[k]
		end, fire, nil, 20)
		mem.target = step
		return
	end

	-- 2. goodies close by (skip the skull if we can help it)
	local step = bfs(x, z, function(_, _, k)
		local pu = S.powerups[k]
		return pu ~= nil and pu.kind ~= "Skull"
	end, fire, danger, 6)
	if step then
		mem.target = step
		return
	end

	-- 3. drop a bomb next to a crate or an enemy, if we can get away
	if s.active < s.maxBombs and s.curse ~= "nobombs" and math.random() < Config.BOT_AGGRESSION then
		if (enemiesInLine(bot, x, z, s.range) or crateNext(x, z)) and canEscape(x, z, s, fire) then
			Bombs.place(bot, true)
			return -- next think will see the danger and run
		end
	end

	-- 4. walk towards an enemy, or else towards a crate
	step = bfs(x, z, function(cx, cz)
		local p = S.playerOnCell(Grid.cellOf, cx, cz)
		return (p ~= nil and p ~= bot) or (crateNext(cx, cz) and (cx ~= x or cz ~= z))
	end, fire, danger, 40)
	if step then
		mem.target = step
		return
	end

	-- 5. nothing to do: wander to a random safe neighbour
	local options = {}
	for _, d in ipairs(Grid.DIRS) do
		local nx, nz = x + d[1], z + d[2]
		if walkable(nx, nz, fire) and not danger[key(nx, nz)] then
			options[#options + 1] = { nx, nz }
		end
	end
	if #options > 0 then
		mem.target = options[math.random(#options)]
	end
end

function Bots.update(now, dt)
	for bot, model in pairs(S.botChars) do
		local s = S.stats[bot]
		local hum = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		local mem = brain[bot]
		if S.alive[bot] and s and hum and root and mem and hum.Health > 0 and S.roundState == "playing" then
			hum.WalkSpeed = s.curse == "slow" and Config.CURSE_SLOW_SPEED or s.speed
			if now >= mem.nextThink then
				mem.nextThink = now + Config.BOT_THINK * (0.8 + math.random() * 0.4)
				think(bot, s, root, hum)
			end
			local t = mem.target
			if t then
				local goal = Grid.cellPos(t[1], t[2])
				local flat = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
				if flat.Magnitude < 0.5 then
					mem.target = nil
					mem.nextThink = math.min(mem.nextThink, now) -- reached it: think again right away
					hum:Move(Vector3.zero)
				else
					hum:Move(flat.Unit)
				end
			else
				hum:Move(Vector3.zero)
			end

			-- conveyor belts push bots too (players are pushed by their own client)
			local cx, cz = Grid.cellOf(root.Position)
			local belt = S.belts[key(cx, cz)]
			if belt then
				root.CFrame += Vector3.new(belt.dx, 0, belt.dz) * Config.BELT_SPEED * dt
			end
		elseif hum then
			hum:Move(Vector3.zero)
		end
	end
end

return Bots
