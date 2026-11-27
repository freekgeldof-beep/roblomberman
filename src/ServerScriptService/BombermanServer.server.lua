-- Roblomberman: server entry point (rounds and players).
-- The game rules live in the modules in the "Bomberman" folder:
--   Grid      grid helpers (cell <-> position, arena size)
--   State     shared game state
--   Net       RemoteEvents and round info for the clients
--   Sounds    sound effects
--   Powerups  goodies and curses
--   Arena     building the arena, crates, warps, belts, switch walls, sudden death
--   Bombs     placing / throwing / kicking / exploding bombs and fire
--   Bots      computer opponents
-- Player-facing text is never built here: we send message keys (see
-- ReplicatedStorage.Lang) and each client translates them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("BombConfig"))
local Modules = script.Parent:WaitForChild("Bomberman")
local Grid = require(Modules:WaitForChild("Grid"))
local S = require(Modules:WaitForChild("State"))
local Net = require(Modules:WaitForChild("Net"))
local Sounds = require(Modules:WaitForChild("Sounds"))
local Powerups = require(Modules:WaitForChild("Powerups"))
local Arena = require(Modules:WaitForChild("Arena"))
local Bombs = require(Modules:WaitForChild("Bombs"))
local Bots = require(Modules:WaitForChild("Bots"))

Players.CharacterAutoLoads = false

Net.PlaceBomb.OnServerEvent:Connect(function(player)
	Bombs.place(player)
end)
Net.ThrowBomb.OnServerEvent:Connect(function(player)
	Bombs.throw(player)
end)

local roundNumber = 0

local function msg(k, a)
	return { k = k, a = a }
end

----------------------------------------------------------------------
-- Rounds
----------------------------------------------------------------------
local function updateAliveCount()
	local n = 0
	for _ in pairs(S.alive) do
		n += 1
	end
	Net.set("AliveCount", n)
end

local function setAlive(plr, value)
	S.alive[plr] = value and true or nil
	plr:SetAttribute("Alive", value and true or false)
	updateAliveCount()
end

local function getWins(plr)
	local ls = plr:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("Wins")
end

-- Scoreboard for everyone: real players plus the bots that have played
local function sendResult(winner, title)
	local everyone = Players:GetPlayers()
	for _, bot in ipairs(Bots.all()) do
		everyone[#everyone + 1] = bot
	end
	local rows = {}
	for _, plr in ipairs(everyone) do
		local w = getWins(plr)
		rows[#rows + 1] = {
			name = S.nameOf(plr),
			wins = w and w.Value or 0,
			color = plr:GetAttribute("Color"),
			winner = plr == winner,
		}
	end
	table.sort(rows, function(a, b)
		if a.wins ~= b.wins then
			return a.wins > b.wins
		end
		return a.name < b.name
	end)
	Net.RoundResult:FireAllClients(title, rows, Config.INTERMISSION)
end

local function endRound(winner, reason)
	if S.roundState ~= "playing" then
		return
	end
	S.roundState = "over"
	Net.set("State", "over")
	Net.set("SuddenDeath", false)
	local title
	if winner then
		local w = getWins(winner)
		if w then
			w.Value += 1
		end
		title = msg("win_round", { name = S.nameOf(winner), n = roundNumber })
		Sounds.play("Win")
	else
		title = reason or msg("draw")
	end
	sendResult(winner, title)
end

local function checkRound()
	if S.roundState ~= "playing" then
		return
	end
	local count, last = 0, nil
	local humansInRound, humansAlive = 0, 0
	for plr in pairs(S.alive) do
		count += 1
		last = plr
		if not S.isBot(plr) then
			humansAlive += 1
		end
	end
	for _, plr in ipairs(S.roundPlayers) do
		if not S.isBot(plr) then
			humansInRound += 1
		end
	end

	if #S.roundPlayers >= 2 then
		if count <= 1 then
			endRound(last)
		elseif humansInRound > 0 and humansAlive == 0 then
			-- all real players are out: don't make them watch the bots for ages
			endRound(nil, msg("bots_win"))
		end
	elseif count == 0 then
		endRound(nil, msg("solo_out"))
	elseif #Players:GetPlayers() >= 2 then
		-- someone was practising alone and a second player joined:
		-- stop the practice round so everyone can start together
		endRound(nil, msg("new_player"))
	end
end

local function onDeath(player)
	if not S.alive[player] then
		return
	end
	setAlive(player, false)
	local root = S.getRoot(player)
	Sounds.play("Death", root and root.Position)
	local s = S.stats[player]
	if s and s.held then
		Bombs.explode(s.held)
	end
	Net.announce(msg("you_out"), 3, false, player)
	checkRound()
end

local function killOnCell(x, z)
	local plr = S.playerOnCell(Grid.cellOf, x, z)
	while plr do
		local hum = S.getHum(plr)
		if hum then
			hum.Health = 0
		end
		onDeath(plr) -- right away, so playerOnCell won't find them again
		plr = S.playerOnCell(Grid.cellOf, x, z)
	end
end

-- After the round time the arena closes in from the outside
local function suddenDeath()
	local myGen = S.gen
	Net.set("SuddenDeath", true)
	Net.announce(msg("sudden_death"), 3)
	for _, c in ipairs(Grid.spiral()) do
		if S.roundState ~= "playing" or S.gen ~= myGen then
			return
		end
		local x, z = c[1], c[2]
		if Arena.closeCell(x, z) then
			local b = S.bombAt[Grid.key(x, z)]
			if b then
				Bombs.explode(b)
			end
			task.wait(0.2) -- the block is still falling
			if S.roundState ~= "playing" or S.gen ~= myGen then
				return
			end
			killOnCell(x, z)
			task.wait(math.max(0, Config.SUDDEN_DEATH_STEP - 0.2))
		end
	end
end

local function colorCharacter(char, color)
	local hl = Instance.new("Highlight")
	hl.FillColor = color
	hl.FillTransparency = 0.45
	hl.OutlineColor = Color3.new(1, 1, 1)
	hl.OutlineTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = char
end

local function startRound()
	-- who plays: real players first, then bots to fill up to BOT_FILL
	local humans = Players:GetPlayers()
	local participants = {}
	for i = 1, math.min(#humans, Config.MAX_PLAYERS) do
		participants[i] = humans[i]
	end
	for i = Config.MAX_PLAYERS + 1, #humans do
		Net.announce(msg("arena_full"), 4, true, humans[i])
	end
	local botCount = math.max(0, math.min(Config.BOT_FILL, Config.MAX_PLAYERS) - #participants)
	for _, bot in ipairs(Bots.get(botCount)) do
		participants[#participants + 1] = bot
	end

	local features = Arena.build(#participants)
	Arena.resetToggles(os.clock())
	Bots.clearCharacters()
	table.clear(S.alive)
	table.clear(S.stats)
	S.roundPlayers = participants
	roundNumber += 1
	Net.set("Round", roundNumber)

	for _, plr in ipairs(humans) do
		plr:SetAttribute("InRound", false)
		plr:SetAttribute("Alive", false)
	end
	for _, plr in ipairs(participants) do
		for _, attr in ipairs({ "Color", "ColorName", "Curse" }) do
			plr:SetAttribute(attr, nil)
		end
	end

	local spawns = Grid.spawns()
	for i, plr in ipairs(participants) do
		S.stats[plr] = Powerups.newStats()
		local c = spawns[i]
		local spawnCf = CFrame.new(Grid.cellPos(c[1], c[2]) + Vector3.new(0, 3, 0))
		local char
		if S.isBot(plr) then
			char = Bots.spawn(plr, spawnCf)
		else
			local ok = pcall(function()
				plr:LoadCharacter()
			end)
			char = ok and plr.Character
		end
		if char then
			local root = char:WaitForChild("HumanoidRootPart", 5)
			local hum = char:WaitForChild("Humanoid", 5)
			if root and hum then
				local pc = Config.PLAYER_COLORS[i]
				char:PivotTo(spawnCf)
				hum.UseJumpPower = true
				hum.JumpPower = 0
				colorCharacter(char, pc.color)
				plr:SetAttribute("Color", pc.color)
				plr:SetAttribute("ColorName", pc.name) -- a Lang key, e.g. "color_1"
				plr:SetAttribute("InRound", true)
				setAlive(plr, true)
				S.stats[plr].invulUntil = os.clock() + 2
				local ff = Instance.new("ForceField")
				ff.Parent = char
				Debris:AddItem(ff, 2)
				hum.Died:Connect(function()
					onDeath(plr)
				end)
				Powerups.sync(plr)
			end
		end
	end

	S.roundState = "playing"
	Net.set("RoundEndsAt", workspace:GetServerTimeNow() + Config.ROUND_TIME)
	Net.set("SuddenDeath", false)
	Net.set("State", "playing")
	Net.announce(msg("go"), 1.5)
	Sounds.play("Go")
	if #features > 0 then
		task.delay(1.6, function()
			Net.announce(msg("this_round", { list = features }), 3, true)
		end)
	end
	checkRound()
end

task.spawn(function()
	while true do
		while #Players:GetPlayers() == 0 do
			task.wait(1)
		end
		S.roundState = "lobby"
		Net.set("State", "lobby")
		for i = 3, 1, -1 do
			Net.announce(msg("countdown", { n = i }), 1)
			Sounds.play("Beep")
			task.wait(1)
		end
		startRound()
		local deadline = os.clock() + Config.ROUND_TIME
		local sudden = false
		while S.roundState == "playing" do
			if not sudden and os.clock() >= deadline then
				sudden = true
				task.spawn(suddenDeath)
			end
			checkRound()
			task.wait(0.25)
		end
		task.wait(Config.INTERMISSION)
	end
end)

----------------------------------------------------------------------
-- Players
----------------------------------------------------------------------
Players.PlayerAdded:Connect(function(plr)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = ls
	ls.Parent = plr
	plr:SetAttribute("Alive", false)
	plr:SetAttribute("InRound", false)
end)

Players.PlayerRemoving:Connect(function(plr)
	local s = S.stats[plr]
	if s and s.held then
		Bombs.explode(s.held)
	end
	S.alive[plr] = nil
	S.stats[plr] = nil
	-- (the player stays in roundPlayers, so the last one standing still wins)
	updateAliveCount()
	checkRound()
end)

----------------------------------------------------------------------
-- Main loop
----------------------------------------------------------------------
-- Warp zones: whoever stands (almost) in the middle of a warp comes out at the other one
local function updateWarps(now)
	if next(S.warps) == nil then
		return
	end
	for plr in pairs(S.alive) do
		local s = S.stats[plr]
		local root = S.getRoot(plr)
		local char = S.charOf(plr)
		if s and root and char then
			local x, z = Grid.cellOf(root.Position)
			local k = Grid.key(x, z)
			if s.warpCell and s.warpCell ~= k then
				s.warpCell = nil -- stepped off the warp: it works again
			end
			local w = S.warps[k]
			if w and not s.warpCell and now >= (s.warpReady or 0) and not S.terrain[k] and not S.terrain[Grid.key(w.x, w.z)] then
				local c = Grid.cellPos(x, z)
				local off = Vector3.new(root.Position.X - c.X, 0, root.Position.Z - c.Z)
				if off.Magnitude < Grid.T * 0.3 then
					local look = root.CFrame.LookVector
					local dest = Grid.cellPos(w.x, w.z) + Vector3.new(0, root.Position.Y, 0)
					char:PivotTo(CFrame.lookAt(dest, dest + Vector3.new(look.X, 0, look.Z)))
					s.warpCell = Grid.key(w.x, w.z)
					s.warpReady = now + Config.WARP_COOLDOWN
					Sounds.play("Warp", dest)
				end
			end
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	Bombs.update(now, dt)
	Bombs.updateFlames(now)
	Powerups.update(now)
	Arena.updateToggles(now)
	updateWarps(now)
	Bots.update(now, dt)

	-- 💩 curse: drops bombs by itself
	for plr in pairs(S.alive) do
		local s = S.stats[plr]
		if s and s.curse == "autobomb" then
			Bombs.place(plr, true)
		end
	end
end)
