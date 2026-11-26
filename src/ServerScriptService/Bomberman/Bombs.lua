-- Bommen: leggen, gooien, schoppen, ontploffen en het vuur
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage:WaitForChild("BombConfig"))
local Grid = require(script.Parent.Grid)
local S = require(script.Parent.State)
local Powerups = require(script.Parent.Powerups)
local Arena = require(script.Parent.Arena)
local Sounds = require(script.Parent.Sounds)

local T = Grid.T
local key = Grid.key
local BOMB_Y = Vector3.new(0, 1.6, 0)

local Bombs = {}

----------------------------------------------------------------------
-- Hulpjes
----------------------------------------------------------------------

-- Wordt dit vakje al gebruikt als landingsplek van een gegooide bom?
local function isTargeted(x, z)
	for b in pairs(S.bombs) do
		if b.state == "flying" and b.x == x and b.z == z then
			return true
		end
	end
	return false
end

-- Vrij vakje voor een bom: geen muur/kist, geen andere bom (en eventueel geen speler)
local function cellFree(x, z, checkPlayers)
	if not Grid.inBounds(x, z) then
		return false
	end
	local k = key(x, z)
	if S.terrain[k] or S.bombAt[k] or isTargeted(x, z) then
		return false
	end
	if checkPlayers and S.playerOnCell(Grid.cellOf, x, z) then
		return false
	end
	return true
end

local function newBombPart()
	local p = Instance.new("Part")
	p.Name = "Bomb"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(3.2, 3.2, 3.2)
	p.Material = Enum.Material.Metal
	p.Color = Color3.fromRGB(25, 25, 30)
	p.Anchored = true
	p.CanCollide = false

	-- Alleen de mesh pulseert; de botsingsvorm van het onderdeel blijft gelijk
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	TweenService:Create(mesh, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Scale = Vector3.new(1.16, 1.16, 1.16),
	}):Play()

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

	TweenService:Create(p, TweenInfo.new(Config.FUSE, Enum.EasingStyle.Linear), { Color = Color3.fromRGB(210, 30, 30) }):Play()
	p.Parent = S.arena
	return p
end

local function spawnBomb(player, x, z)
	local s = S.stats[player]
	local part = newBombPart()
	part.Position = Grid.cellPos(x, z) + BOMB_Y
	local bomb = {
		owner = player,
		holder = nil,
		x = x,
		z = z,
		range = s.range,
		pierce = s.pierce,
		explodeAt = os.clock() + Config.FUSE,
		state = "placed", -- placed | held | flying | sliding
		solid = false,
		part = part,
	}
	S.bombAt[key(x, z)] = bomb
	S.bombs[bomb] = true
	s.active += 1
	Sounds.play("Place", part.Position)
end

local function spawnFlame(x, z)
	local f = Instance.new("Part")
	f.Name = "Flame"
	f.Anchored = true
	f.CanCollide = false
	f.CanTouch = false
	f.CanQuery = false
	f.Material = Enum.Material.Neon
	f.Color = Color3.fromRGB(255, 140, 30)
	f.Size = Vector3.new(T - 0.8, 2.4, T - 0.8)
	f.Position = Grid.cellPos(x, z) + Vector3.new(0, 1.2, 0)
	f.Transparency = 0.05
	f.Parent = S.arena
	TweenService:Create(f, TweenInfo.new(Config.FLAME_TIME), { Transparency = 1 }):Play()
	Debris:AddItem(f, Config.FLAME_TIME + 0.1)
end

----------------------------------------------------------------------
-- Ontploffen
----------------------------------------------------------------------
function Bombs.explode(bomb)
	if bomb.exploded then
		return
	end
	bomb.exploded = true
	S.bombs[bomb] = nil
	local k = key(bomb.x, bomb.z)
	if S.bombAt[k] == bomb then
		S.bombAt[k] = nil
	end
	local os_ = S.stats[bomb.owner]
	if os_ then
		os_.active = math.max(0, os_.active - 1)
	end
	if bomb.holder then
		local hs = S.stats[bomb.holder]
		if hs and hs.held == bomb then
			hs.held = nil
		end
	end
	local center = bomb.part.Position
	bomb.part:Destroy()

	-- Roblox-ontploffing alleen voor beeld en geluid (doet geen schade)
	local e = Instance.new("Explosion")
	e.Position = center
	e.BlastRadius = 3
	e.BlastPressure = 0
	e.DestroyJointRadiusPercent = 0
	e.ExplosionType = Enum.ExplosionType.NoCraters
	e.Parent = S.arena
	Sounds.play("Explosion", center)

	local cells = { { bomb.x, bomb.z } }
	local chain = {}
	for _, d in ipairs(Grid.DIRS) do
		for i = 1, bomb.range do
			local cx, cz = bomb.x + d[1] * i, bomb.z + d[2] * i
			if not Grid.inBounds(cx, cz) then
				break
			end
			local ck = key(cx, cz)
			local t = S.terrain[ck]
			if t == "wall" then
				break
			elseif t == "crate" then
				Arena.destroyCrate(cx, cz)
				cells[#cells + 1] = { cx, cz }
				if not bomb.pierce then
					break
				end
			else
				cells[#cells + 1] = { cx, cz }
				if S.powerups[ck] then
					Powerups.remove(ck)
				end
				local ob = S.bombAt[ck]
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
	S.flames[#S.flames + 1] = { cells = set, expires = os.clock() + Config.FLAME_TIME }

	for _, ob in ipairs(chain) do
		Bombs.explode(ob)
	end
end

----------------------------------------------------------------------
-- Acties van spelers
----------------------------------------------------------------------
local function rateLimited(s)
	if os.clock() - s.lastAction < 0.15 then
		return true
	end
	s.lastAction = os.clock()
	return false
end

-- force = true: voor de "vanzelf bommen"-vloek (geen limiet op tempo)
function Bombs.place(player, force)
	local s = S.stats[player]
	if not s or not S.alive[player] or S.roundState ~= "playing" then
		return
	end
	if s.curse == "nobombs" then
		return
	end
	if not force and rateLimited(s) then
		return
	end
	if s.active >= s.maxBombs then
		return
	end
	local root = S.getRoot(player)
	if not root then
		return
	end
	local x, z = Grid.cellOf(root.Position)
	if not cellFree(x, z, false) then
		return
	end
	spawnBomb(player, x, z)
end

function Bombs.throw(player)
	local s = S.stats[player]
	if not s or not S.alive[player] or not s.throw or S.roundState ~= "playing" then
		return
	end
	if rateLimited(s) then
		return
	end
	local root = S.getRoot(player)
	if not root then
		return
	end

	local dx, dz = Grid.axisDir(root.CFrame.LookVector)
	local sx, sz = Grid.cellOf(root.Position)

	if s.held then
		local bomb = s.held
		local tx, tz
		for step = Config.THROW_DISTANCE, math.max(Grid.W, Grid.H) do
			local cx, cz = sx + dx * step, sz + dz * step
			if not Grid.inBounds(cx, cz) then
				break
			end
			if cellFree(cx, cz, false) then
				tx, tz = cx, cz
				break
			end
		end
		if not tx then
			for step = Config.THROW_DISTANCE - 1, 0, -1 do
				local cx, cz = sx + dx * step, sz + dz * step
				if cellFree(cx, cz, false) then
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
		-- Let op: tijdens de vlucht staat de bom NIET in bombAt, zodat vuur hem
		-- niet in de lucht laat ontploffen. Hij landt op (x, z).
		bomb.x, bomb.z = tx, tz
		bomb.from = bomb.part.Position
		bomb.to = Grid.cellPos(tx, tz) + BOMB_Y
		bomb.t0 = os.clock()
		bomb.dur = math.max(0.35, (bomb.to - bomb.from).Magnitude / Config.THROW_SPEED)
		Sounds.play("Throw", bomb.from)
	else
		for _, c in ipairs({ { sx, sz }, { sx + dx, sz + dz } }) do
			local k = key(c[1], c[2])
			local b = S.bombAt[k]
			if b and b.state == "placed" then
				S.bombAt[k] = nil
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

local function kick(bomb, dx, dz)
	if not cellFree(bomb.x + dx, bomb.z + dz, true) then
		return
	end
	bomb.state = "sliding"
	bomb.dx, bomb.dz = dx, dz
	bomb.slide = 0
	bomb.solid = false
	bomb.part.CanCollide = false
	Sounds.play("Kick", bomb.part.Position)
end

-- Spelers met de schopschoen die tegen een bom aan lopen, schoppen hem weg
local function checkKicks()
	for plr in pairs(S.alive) do
		local s = S.stats[plr]
		local root = S.getRoot(plr)
		local hum = S.getHum(plr)
		if s and s.kick and root and hum and hum.MoveDirection.Magnitude > 0.5 then
			local dx, dz = Grid.axisDir(hum.MoveDirection)
			local px, pz = Grid.cellOf(root.Position)
			local b = S.bombAt[key(px + dx, pz + dz)]
			if b and b.state == "placed" and b.solid then
				local center = Grid.cellPos(b.x, b.z)
				local along = math.abs(dx ~= 0 and (center.X - root.Position.X) or (center.Z - root.Position.Z))
				local side = math.abs(dx ~= 0 and (center.Z - root.Position.Z) or (center.X - root.Position.X))
				if along < T * 0.85 and side < T * 0.45 then
					kick(b, dx, dz)
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Elke frame
----------------------------------------------------------------------
function Bombs.update(now, dt)
	checkKicks()

	local list = {}
	for b in pairs(S.bombs) do
		list[#list + 1] = b
	end
	for _, bomb in ipairs(list) do
		if not bomb.exploded then
			if bomb.state == "held" then
				local root = bomb.holder and S.getRoot(bomb.holder)
				if not root or not S.alive[bomb.holder] then
					Bombs.explode(bomb)
				else
					bomb.part.Position = root.Position + Vector3.new(0, 3.6, 0)
					local x, z = Grid.cellOf(root.Position)
					bomb.x, bomb.z = math.clamp(x, 1, Grid.W), math.clamp(z, 1, Grid.H)
				end
			elseif bomb.state == "flying" then
				local a = math.clamp((now - bomb.t0) / bomb.dur, 0, 1)
				bomb.part.Position = bomb.from:Lerp(bomb.to, a) + Vector3.new(0, math.sin(math.pi * a) * 6, 0)
				if a >= 1 then
					local k = key(bomb.x, bomb.z)
					if S.terrain[k] or S.bombAt[k] then
						-- er is intussen een muur of bom op de landingsplek gekomen
						Bombs.explode(bomb)
					else
						S.bombAt[k] = bomb
						bomb.state = "placed"
					end
				end
			elseif bomb.state == "sliding" then
				bomb.slide += Config.KICK_SPEED * dt
				while bomb.slide >= 1 and bomb.state == "sliding" do
					bomb.slide -= 1
					local k = key(bomb.x, bomb.z)
					if S.bombAt[k] == bomb then
						S.bombAt[k] = nil
					end
					bomb.x, bomb.z = bomb.x + bomb.dx, bomb.z + bomb.dz
					S.bombAt[key(bomb.x, bomb.z)] = bomb
					if not cellFree(bomb.x + bomb.dx, bomb.z + bomb.dz, true) then
						bomb.state = "placed"
						bomb.slide = 0
					end
				end
				local here = Grid.cellPos(bomb.x, bomb.z)
				if bomb.state == "sliding" then
					local nextPos = Grid.cellPos(bomb.x + bomb.dx, bomb.z + bomb.dz)
					bomb.part.Position = here:Lerp(nextPos, bomb.slide) + BOMB_Y
				else
					bomb.part.Position = here + BOMB_Y
				end
			elseif bomb.state == "placed" and not bomb.solid then
				-- pas massief als niemand er meer op staat (zo kun je van je eigen bom af lopen)
				local clear = true
				for plr in pairs(S.alive) do
					local root = S.getRoot(plr)
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
				Bombs.explode(bomb)
			end
		end
	end
end

-- Vuur doodt spelers die erin staan
function Bombs.updateFlames(now)
	for i = #S.flames, 1, -1 do
		local f = S.flames[i]
		if now >= f.expires then
			table.remove(S.flames, i)
		else
			for plr in pairs(S.alive) do
				local s = S.stats[plr]
				local root = S.getRoot(plr)
				if root and s and now >= s.invulUntil then
					local x, z = Grid.cellOf(root.Position)
					if f.cells[key(x, z)] then
						local hum = S.getHum(plr)
						if hum then
							hum.Health = 0
						end
					end
				end
			end
		end
	end
end

return Bombs
