-- Roblomberman: server (arena, bommen, goodies, rondes)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("BombConfig"))
local T, W, H = Config.TILE, Config.WIDTH, Config.HEIGHT

Players.CharacterAutoLoads = false

----------------------------------------------------------------------
-- Remotes
----------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "BombRemotes"
remotes.Parent = ReplicatedStorage

local function newRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local placeRemote = newRemote("PlaceBomb")
local throwRemote = newRemote("ThrowBomb")
local announceRemote = newRemote("Announce") -- (tekst, seconden, klein?)

----------------------------------------------------------------------
-- Grid helpers
----------------------------------------------------------------------
local originX = -(W - 1) * T / 2
local originZ = -(H - 1) * T / 2

local function cellPos(x, z)
	return Vector3.new(originX + (x - 1) * T, 0, originZ + (z - 1) * T)
end
local function cellOf(p)
	return math.floor((p.X - originX) / T + 0.5) + 1, math.floor((p.Z - originZ) / T + 0.5) + 1
end
local function key(x, z)
	return x * 100 + z
end
local function inBounds(x, z)
	return x >= 1 and x <= W and z >= 1 and z <= H
end

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local CORNERS = { { 1, 1 }, { W, H }, { W, 1 }, { 1, H } }

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local arena
local gen = 0
local terrain = {} -- key -> "wall" | "crate"
local crateParts = {}
local bombs = {} -- set
local bombAt = {} -- key -> bomb
local powerups = {} -- key -> {part, kind}
local flames = {} -- {cells = {key=true}, expires}
local stats = {} -- player -> stats
local alive = {} -- player -> true
local roundPlayers = {}
local roundState = "lobby" -- lobby | playing | over

local function getRoot(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum(player)
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function announce(text, seconds, small, player)
	if player then
		announceRemote:FireClient(player, text, seconds or 3, small)
	else
		announceRemote:FireAllClients(text, seconds or 3, small)
	end
end

----------------------------------------------------------------------
-- Goodies
----------------------------------------------------------------------
local POWERUPS = {
	Range = {
		emoji = "🔥", name = "Vuurbereik +1", color = Color3.fromRGB(255, 120, 40), weight = 25,
		apply = function(s) s.range = math.min(s.range + 1, Config.MAX_RANGE) end,
	},
	Bomb = {
		emoji = "💣", name = "Extra bom", color = Color3.fromRGB(90, 90, 110), weight = 25,
		apply = function(s) s.maxBombs = math.min(s.maxBombs + 1, Config.MAX_BOMBS) end,
	},
	Speed = {
		emoji = "👟", name = "Sneller lopen", color = Color3.fromRGB(80, 200, 255), weight = 15,
		apply = function(s) s.speed = math.min(s.speed + Config.SPEED_STEP, Config.MAX_SPEED) end,
	},
	Pierce = {
		emoji = "⚡", name = "Doorboor-bommen (vuur breekt door kisten)", color = Color3.fromRGB(255, 230, 60), weight = 10,
		apply = function(s) s.pierce = true end,
	},
	Throw = {
		emoji = "🧤", name = "Handschoen: bommen gooien (E)", color = Color3.fromRGB(120, 255, 120), weight = 15,
		apply = function(s) s.throw = true end,
	},
}

local function pickPowerup()
	local total = 0
	for _, d in pairs(POWERUPS) do
		total += d.weight
	end
	local r = math.random() * total
	for kind, d in pairs(POWERUPS) do
		r -= d.weight
		if r <= 0 then
			return kind
		end
	end
	return "Range"
end

local function newStats()
	return {
		maxBombs = Config.START_BOMBS,
		range = Config.START_RANGE,
		speed = Config.START_SPEED,
		pierce = false,
		throw = false,
		active = 0,
		held = nil,
		lastAction = 0,
		invulUntil = 0,
	}
end

local function syncStats(player)
	local s = stats[player]
	if not s then
		return
	end
	player:SetAttribute("Bombs", s.maxBombs)
	player:SetAttribute("Range", s.range)
	player:SetAttribute("Speed", s.speed)
	player:SetAttribute("Pierce", s.pierce)
	player:SetAttribute("Throw", s.throw)
	local hum = getHum(player)
	if hum then
		hum.WalkSpeed = s.speed
	end
end

local function removePowerup(k)
	local pu = powerups[k]
	if pu then
		pu.part:Destroy()
		powerups[k] = nil
	end
end

local function spawnPowerup(x, z, kind)
	local def = POWERUPS[kind]
	local p = Instance.new("Part")
	p.Name = "Goodie_" .. kind
	p.Size = Vector3.new(2.4, 2.4, 2.4)
	p.Material = Enum.Material.Neon
	p.Color = def.color
	p.Anchored = true
	p.CanCollide = false
	p.Position = cellPos(x, z) + Vector3.new(0, 2, 0)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(64, 64)
	gui.AlwaysOnTop = false
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = def.emoji
	label.TextScaled = true
	label.Parent = gui

	p.Parent = arena
	TweenService:Create(p, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = cellPos(x, z) + Vector3.new(0, 2.8, 0),
	}):Play()
	powerups[key(x, z)] = { part = p, kind = kind }
end

----------------------------------------------------------------------
-- Arena
----------------------------------------------------------------------
local function isSafe(x, z)
	for _, c in ipairs(CORNERS) do
		local ax, az = math.abs(x - c[1]), math.abs(z - c[2])
		if (az == 0 and ax <= 2) or (ax == 0 and az <= 2) or (ax == 2 and az == 1) or (ax == 1 and az == 2) then
			return true
		end
	end
	return false
end

local function makePart(size, pos, color, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material
	p.Parent = arena
	return p
end

local function buildArena()
	if arena then
		arena:Destroy()
	end
	gen += 1
	table.clear(terrain)
	table.clear(crateParts)
	table.clear(bombs)
	table.clear(bombAt)
	table.clear(powerups)
	table.clear(flames)

	arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = workspace

	local light = Color3.fromRGB(96, 168, 90)
	local dark = Color3.fromRGB(80, 148, 76)
	for x = 1, W do
		for z = 1, H do
			local floor = makePart(Vector3.new(T, 1, T), cellPos(x, z) + Vector3.new(0, -0.5, 0), (x + z) % 2 == 0 and light or dark, Enum.Material.Grass)
			floor.Name = "Floor"
			if x % 2 == 0 and z % 2 == 0 then
				terrain[key(x, z)] = "wall"
				local w = makePart(Vector3.new(T, T, T), cellPos(x, z) + Vector3.new(0, T / 2, 0), Color3.fromRGB(110, 110, 120), Enum.Material.Concrete)
				w.Name = "Wall"
			elseif not isSafe(x, z) and math.random() < Config.CRATE_CHANCE then
				terrain[key(x, z)] = "crate"
				local c = makePart(Vector3.new(T - 0.1, T - 0.1, T - 0.1), cellPos(x, z) + Vector3.new(0, T / 2, 0), Color3.fromRGB(176, 124, 70), Enum.Material.WoodPlanks)
				c.Name = "Crate"
				crateParts[key(x, z)] = c
			end
		end
	end

	-- buitenrand
	local hw, hh = W * T / 2, H * T / 2
	local rim = Color3.fromRGB(60, 60, 72)
	makePart(Vector3.new(W * T + 2 * T, 2 * T, T), Vector3.new(0, T, -hh - T / 2), rim, Enum.Material.Slate)
	makePart(Vector3.new(W * T + 2 * T, 2 * T, T), Vector3.new(0, T, hh + T / 2), rim, Enum.Material.Slate)
	makePart(Vector3.new(T, 2 * T, H * T), Vector3.new(-hw - T / 2, T, 0), rim, Enum.Material.Slate)
	makePart(Vector3.new(T, 2 * T, H * T), Vector3.new(hw + T / 2, T, 0), rim, Enum.Material.Slate)
end

local function destroyCrate(x, z)
	local k = key(x, z)
	terrain[k] = nil
	local part = crateParts[k]
	crateParts[k] = nil
	if part then
		TweenService:Create(part, TweenInfo.new(0.3), { Transparency = 1, Size = part.Size * 0.6 }):Play()
		Debris:AddItem(part, 0.4)
	end
	if math.random() < Config.DROP_CHANCE then
		local kind = pickPowerup()
		local myGen = gen
		task.delay(Config.FLAME_TIME + 0.05, function()
			if myGen == gen and not terrain[k] and not powerups[k] and not bombAt[k] then
				spawnPowerup(x, z, kind)
			end
		end)
	end
end

----------------------------------------------------------------------
-- Bommen
----------------------------------------------------------------------
local function newBombPart()
	local p = Instance.new("Part")
	p.Name = "Bomb"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(3.2, 3.2, 3.2)
	p.Material = Enum.Material.Metal
	p.Color = Color3.fromRGB(25, 25, 30)
	p.Anchored = true
	p.CanCollide = false

	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 1.6, 0)
	att.Parent = p
	local sparks = Instance.new("ParticleEmitter")
	sparks.Rate = 40
	sparks.Lifetime = NumberRange.new(0.2, 0.4)
	sparks.Speed = NumberRange.new(4, 7)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 80, 20))
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	sparks.Parent = att
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(255, 90, 40)
	pl.Range = 8
	pl.Parent = p

	TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Size = Vector3.new(3.7, 3.7, 3.7),
	}):Play()
	TweenService:Create(p, TweenInfo.new(Config.FUSE, Enum.EasingStyle.Linear), { Color = Color3.fromRGB(210, 30, 30) }):Play()
	p.Parent = arena
	return p
end

local function spawnBomb(player, x, z)
	local s = stats[player]
	local part = newBombPart()
	part.Position = cellPos(x, z) + Vector3.new(0, 1.6, 0)
	local bomb = {
		owner = player,
		holder = nil,
		x = x,
		z = z,
		range = s.range,
		pierce = s.pierce,
		explodeAt = os.clock() + Config.FUSE,
		state = "placed", -- placed | held | flying
		solid = false,
		part = part,
	}
	bombAt[key(x, z)] = bomb
	bombs[bomb] = true
	s.active += 1
end

local function spawnFlame(x, z)
	local f = Instance.new("Part")
	f.Name = "Flame"
	f.Anchored = true
	f.CanCollide = false
	f.CanTouch = false
	f.Material = Enum.Material.Neon
	f.Color = Color3.fromRGB(255, 140, 30)
	f.Size = Vector3.new(T - 0.8, 2.4, T - 0.8)
	f.Position = cellPos(x, z) + Vector3.new(0, 1.2, 0)
	f.Transparency = 0.05
	f.Parent = arena
	TweenService:Create(f, TweenInfo.new(Config.FLAME_TIME), { Transparency = 1 }):Play()
	Debris:AddItem(f, Config.FLAME_TIME + 0.1)
end

local function explode(bomb)
	if bomb.exploded then
		return
	end
	bomb.exploded = true
	bombs[bomb] = nil
	local k = key(bomb.x, bomb.z)
	if bombAt[k] == bomb then
		bombAt[k] = nil
	end
	local os_ = stats[bomb.owner]
	if os_ then
		os_.active = math.max(0, os_.active - 1)
	end
	if bomb.holder then
		local hs = stats[bomb.holder]
		if hs and hs.held == bomb then
			hs.held = nil
		end
	end
	bomb.part:Destroy()

	local cells = { { bomb.x, bomb.z } }
	local chain = {}
	for _, d in ipairs(DIRS) do
		for i = 1, bomb.range do
			local cx, cz = bomb.x + d[1] * i, bomb.z + d[2] * i
			if not inBounds(cx, cz) then
				break
			end
			local ck = key(cx, cz)
			local t = terrain[ck]
			if t == "wall" then
				break
			elseif t == "crate" then
				destroyCrate(cx, cz)
				cells[#cells + 1] = { cx, cz }
				if not bomb.pierce then
					break
				end
			else
				cells[#cells + 1] = { cx, cz }
				if powerups[ck] then
					removePowerup(ck)
				end
				local ob = bombAt[ck]
				if ob then
					chain[#chain + 1] = ob
					break
				end
			end
		end
	end

	local set = {}
	for _, c in ipairs(cells) do
		set[key(c[1], c[2])] = true
		spawnFlame(c[1], c[2])
	end
	flames[#flames + 1] = { cells = set, expires = os.clock() + Config.FLAME_TIME }

	for _, ob in ipairs(chain) do
		explode(ob)
	end
end

local function placeBomb(player)
	local s = stats[player]
	if not s or not alive[player] or roundState ~= "playing" then
		return
	end
	if os.clock() - s.lastAction < 0.15 then
		return
	end
	s.lastAction = os.clock()
	if s.active >= s.maxBombs then
		return
	end
	local root = getRoot(player)
	if not root then
		return
	end
	local x, z = cellOf(root.Position)
	if not inBounds(x, z) or terrain[key(x, z)] or bombAt[key(x, z)] then
		return
	end
	spawnBomb(player, x, z)
end

local function throwAction(player)
	local s = stats[player]
	if not s or not alive[player] or not s.throw or roundState ~= "playing" then
		return
	end
	if os.clock() - s.lastAction < 0.15 then
		return
	end
	s.lastAction = os.clock()
	local root = getRoot(player)
	if not root then
		return
	end

	local look = root.CFrame.LookVector
	local dx, dz = 0, 0
	if math.abs(look.X) > math.abs(look.Z) then
		dx = look.X > 0 and 1 or -1
	else
		dz = look.Z > 0 and 1 or -1
	end
	local sx, sz = cellOf(root.Position)

	if s.held then
		local bomb = s.held
		local tx, tz
		local function free(cx, cz)
			return inBounds(cx, cz) and not terrain[key(cx, cz)] and not bombAt[key(cx, cz)]
		end
		for step = Config.THROW_DISTANCE, 14 do
			local cx, cz = sx + dx * step, sz + dz * step
			if not inBounds(cx, cz) then
				break
			end
			if free(cx, cz) then
				tx, tz = cx, cz
				break
			end
		end
		if not tx then
			for step = Config.THROW_DISTANCE - 1, 0, -1 do
				local cx, cz = sx + dx * step, sz + dz * step
				if free(cx, cz) then
					tx, tz = cx, cz
					break
				end
			end
		end
		if not tx then
			return
		end
		s.held = nil
		bomb.holder = nil
		bomb.state = "flying"
		bomb.solid = false
		bomb.x, bomb.z = tx, tz
		bombAt[key(tx, tz)] = bomb
		bomb.from = bomb.part.Position
		bomb.to = cellPos(tx, tz) + Vector3.new(0, 1.6, 0)
		bomb.t0 = os.clock()
		bomb.dur = math.max(0.35, (bomb.to - bomb.from).Magnitude / Config.THROW_SPEED)
	else
		for _, c in ipairs({ { sx, sz }, { sx + dx, sz + dz } }) do
			local k = key(c[1], c[2])
			local b = bombAt[k]
			if b and b.state == "placed" then
				bombAt[k] = nil
				b.state = "held"
				b.holder = player
				b.solid = false
				b.part.CanCollide = false
				s.held = b
				return
			end
		end
	end
end

placeRemote.OnServerEvent:Connect(placeBomb)
throwRemote.OnServerEvent:Connect(throwAction)

----------------------------------------------------------------------
-- Rondes
----------------------------------------------------------------------
local function endRound(winner)
	if roundState ~= "playing" then
		return
	end
	roundState = "over"
	if winner then
		local ls = winner:FindFirstChild("leaderstats")
		if ls and ls:FindFirstChild("Wins") then
			ls.Wins.Value += 1
		end
		announce("🏆 " .. winner.DisplayName .. " wint de ronde!", 5)
	else
		announce("Gelijkspel! Volgende ronde komt eraan…", 5)
	end
end

local function checkRound()
	if roundState ~= "playing" then
		return
	end
	local count, last = 0, nil
	for plr in pairs(alive) do
		count += 1
		last = plr
	end
	if #roundPlayers >= 2 then
		if count <= 1 then
			endRound(last)
		end
	elseif count == 0 then
		endRound(nil)
	end
end

local function onDeath(player)
	if not alive[player] then
		return
	end
	alive[player] = nil
	local s = stats[player]
	if s and s.held then
		explode(s.held)
	end
	checkRound()
end

local function startRound()
	buildArena()
	table.clear(alive)
	table.clear(stats)
	roundPlayers = {}

	local list = Players:GetPlayers()
	for i = 1, math.min(#list, Config.MAX_PLAYERS) do
		roundPlayers[i] = list[i]
	end
	for i = Config.MAX_PLAYERS + 1, #list do
		announce("De arena is vol – je doet mee in een volgende ronde.", 4, true, list[i])
	end

	for i, plr in ipairs(roundPlayers) do
		stats[plr] = newStats()
		local ok = pcall(function()
			plr:LoadCharacter()
		end)
		local char = ok and plr.Character
		if char then
			local root = char:WaitForChild("HumanoidRootPart", 5)
			local hum = char:WaitForChild("Humanoid", 5)
			if root and hum then
				local c = CORNERS[i]
				char:PivotTo(CFrame.new(cellPos(c[1], c[2]) + Vector3.new(0, 3, 0)))
				hum.UseJumpPower = true
				hum.JumpPower = 0
				alive[plr] = true
				stats[plr].invulUntil = os.clock() + 2
				local ff = Instance.new("ForceField")
				ff.Parent = char
				Debris:AddItem(ff, 2)
				hum.Died:Connect(function()
					onDeath(plr)
				end)
				syncStats(plr)
			end
		end
	end

	roundState = "playing"
	announce("GO! 💣", 1.5)
	checkRound()
end

task.spawn(function()
	while true do
		while #Players:GetPlayers() == 0 do
			task.wait(1)
		end
		roundState = "lobby"
		for i = 3, 1, -1 do
			announce("Ronde begint over " .. i .. "…", 1)
			task.wait(1)
		end
		startRound()
		while roundState == "playing" do
			task.wait(0.25)
		end
		task.wait(Config.INTERMISSION)
	end
end)

Players.PlayerAdded:Connect(function(plr)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = ls
	ls.Parent = plr
	task.delay(3, function()
		if plr.Parent and roundState == "playing" and not alive[plr] then
			announce("Er is een ronde bezig – je doet mee in de volgende!", 4, true, plr)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	alive[plr] = nil
	local s = stats[plr]
	if s and s.held then
		explode(s.held)
	end
	stats[plr] = nil
	checkRound()
end)

----------------------------------------------------------------------
-- Hoofdlus
----------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	local now = os.clock()

	-- bommen
	local list = {}
	for b in pairs(bombs) do
		list[#list + 1] = b
	end
	for _, bomb in ipairs(list) do
		if not bomb.exploded then
			if bomb.state == "held" then
				local root = bomb.holder and getRoot(bomb.holder)
				if not root or not alive[bomb.holder] then
					explode(bomb)
				else
					bomb.part.Position = root.Position + Vector3.new(0, 3.6, 0)
					local x, z = cellOf(root.Position)
					bomb.x, bomb.z = math.clamp(x, 1, W), math.clamp(z, 1, H)
				end
			elseif bomb.state == "flying" then
				local a = math.clamp((now - bomb.t0) / bomb.dur, 0, 1)
				local pos = bomb.from:Lerp(bomb.to, a) + Vector3.new(0, math.sin(math.pi * a) * 6, 0)
				bomb.part.Position = pos
				if a >= 1 then
					bomb.state = "placed"
				end
			elseif bomb.state == "placed" and not bomb.solid then
				local clear = true
				for plr in pairs(alive) do
					local root = getRoot(plr)
					if root then
						local d = Vector3.new(root.Position.X - bomb.part.Position.X, 0, root.Position.Z - bomb.part.Position.Z)
						if d.Magnitude < 3 then
							clear = false
							break
						end
					end
				end
				if clear then
					bomb.solid = true
					bomb.part.CanCollide = true
				end
			end
			if not bomb.exploded and now >= bomb.explodeAt then
				explode(bomb)
			end
		end
	end

	-- vuur
	for i = #flames, 1, -1 do
		local f = flames[i]
		if now >= f.expires then
			table.remove(flames, i)
		else
			for plr in pairs(alive) do
				local s = stats[plr]
				local root = getRoot(plr)
				if root and s and now >= s.invulUntil then
					local x, z = cellOf(root.Position)
					if f.cells[key(x, z)] then
						local hum = getHum(plr)
						if hum then
							hum.Health = 0
						end
					end
				end
			end
		end
	end

	-- goodies oppakken
	for plr in pairs(alive) do
		local root = getRoot(plr)
		local s = stats[plr]
		if root and s then
			local x, z = cellOf(root.Position)
			local k = key(x, z)
			local pu = powerups[k]
			if pu then
				local def = POWERUPS[pu.kind]
				def.apply(s)
				removePowerup(k)
				syncStats(plr)
				announce(def.emoji .. " " .. def.name, 1.8, true, plr)
			end
		end
	end
end)
