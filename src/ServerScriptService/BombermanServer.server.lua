-- Roblomberman: server (rondes en spelers)
-- De rest van de spelregels staat in de modules in de map "Bomberman":
--   Grid      rooster-hulpfuncties
--   State     gedeelde toestand
--   Net       RemoteEvents en ronde-info voor de clients
--   Sounds    geluiden
--   Powerups  goodies en vloeken
--   Arena     arena bouwen, kisten, sudden-death-muren
--   Bombs     bommen leggen/gooien/schoppen/ontploffen en vuur
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

Players.CharacterAutoLoads = false

Net.PlaceBomb.OnServerEvent:Connect(function(player)
	Bombs.place(player)
end)
Net.ThrowBomb.OnServerEvent:Connect(function(player)
	Bombs.throw(player)
end)

local roundNumber = 0

----------------------------------------------------------------------
-- Rondes
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
	local w = ls and ls:FindFirstChild("Wins")
	return w
end

local function sendResult(winner, title)
	local rows = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local w = getWins(plr)
		rows[#rows + 1] = {
			name = plr.DisplayName,
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
		title = "🏆 " .. winner.DisplayName .. " wint ronde " .. roundNumber .. "!"
		Sounds.play("Win")
	else
		title = reason or "Gelijkspel!"
	end
	sendResult(winner, title)
end

local function checkRound()
	if S.roundState ~= "playing" then
		return
	end
	local count, last = 0, nil
	for plr in pairs(S.alive) do
		count += 1
		last = plr
	end
	if #S.roundPlayers >= 2 then
		if count <= 1 then
			endRound(last)
		end
	elseif count == 0 then
		endRound(nil, "Oef, je bent af!")
	elseif #Players:GetPlayers() >= 2 then
		-- Iemand speelde alleen en er is een tweede speler bij gekomen:
		-- stop de oefenronde zodat iedereen samen kan beginnen.
		endRound(nil, "Er doet iemand mee! Nieuwe ronde…")
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
	Net.announce("💀 Je bent af – kijk mee!", 3, false, player)
	checkRound()
end

local function killOnCell(x, z)
	local plr = S.playerOnCell(Grid.cellOf, x, z)
	while plr do
		local hum = S.getHum(plr)
		if hum then
			hum.Health = 0
		end
		onDeath(plr) -- direct, zodat playerOnCell hem niet nog eens vindt
		plr = S.playerOnCell(Grid.cellOf, x, z)
	end
end

-- Na de rondetijd valt de arena van buiten naar binnen dicht
local function suddenDeath()
	local myGen = S.gen
	Net.set("SuddenDeath", true)
	Net.announce("☠️ SUDDEN DEATH! De muren komen eraan!", 3)
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
			task.wait(0.2) -- het blok valt nog
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
	Arena.build()
	table.clear(S.alive)
	table.clear(S.stats)
	S.roundPlayers = {}
	roundNumber += 1
	Net.set("Round", roundNumber)

	local list = Players:GetPlayers()
	for _, plr in ipairs(list) do
		plr:SetAttribute("InRound", false)
		plr:SetAttribute("Alive", false)
		plr:SetAttribute("Color", nil)
		plr:SetAttribute("ColorName", nil)
		plr:SetAttribute("Curse", nil)
	end
	for i = 1, math.min(#list, Config.MAX_PLAYERS) do
		S.roundPlayers[i] = list[i]
	end
	for i = Config.MAX_PLAYERS + 1, #list do
		Net.announce("De arena is vol – je doet mee in een volgende ronde.", 4, true, list[i])
	end

	for i, plr in ipairs(S.roundPlayers) do
		S.stats[plr] = Powerups.newStats()
		local ok = pcall(function()
			plr:LoadCharacter()
		end)
		local char = ok and plr.Character
		if char then
			local root = char:WaitForChild("HumanoidRootPart", 5)
			local hum = char:WaitForChild("Humanoid", 5)
			if root and hum then
				local c = Grid.CORNERS[i]
				local pc = Config.PLAYER_COLORS[i]
				char:PivotTo(CFrame.new(Grid.cellPos(c[1], c[2]) + Vector3.new(0, 3, 0)))
				hum.UseJumpPower = true
				hum.JumpPower = 0
				colorCharacter(char, pc.color)
				plr:SetAttribute("Color", pc.color)
				plr:SetAttribute("ColorName", pc.name)
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
	Net.announce("GO! 💣", 1.5)
	Sounds.play("Go")
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
			Net.announce("Ronde begint over " .. i .. "…", 1)
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
-- Spelers
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
	-- (de speler blijft in roundPlayers staan, zodat de laatste overblijver wint)
	updateAliveCount()
	checkRound()
end)

----------------------------------------------------------------------
-- Hoofdlus
----------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	Bombs.update(now, dt)
	Bombs.updateFlames(now)
	Powerups.update(now)

	-- 💩-vloek: legt vanzelf bommen
	for plr in pairs(S.alive) do
		local s = S.stats[plr]
		if s and s.curse == "autobomb" then
			Bombs.place(plr, true)
		end
	end
end)
