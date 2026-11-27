-- Bombs: placing, throwing, kicking, exploding, and the fire
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
-- Helpers
----------------------------------------------------------------------

-- Is this cell already the landing spot of a thrown bomb?
local function isTargeted(x, z)
	for b in pairs(S.bombs) do
		if b.state == "flying" and b.x == x and b.z == z then
			return true
		end
	end
	return false
end

-- Free cell for a bomb: no wall/crate, no other bomb (and optionally no player)
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

	-- Only the mesh pulses; the part's collision shape stays the same
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
-- Exploding
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

	-- Roblox explosion just for looks and sound (does no damage)
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
-- Player actions
----------------------------------------------------------------------
local function rateLimited(s)
	if os.clock() - s.lastAction < 0.15 then
		return true
	end
	s.lastAction = os.clock()
	return false
end

-- force = true: for the "auto bombs" curse and bots (no rate limit)
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

-- Send a bomb flying from cell (sx, sz) in direction (dx, dz), landing at least
-- minDist cells away. Over the outer wall it comes back in on the opposite side.
-- Returns false when there is no free landing cell.
local function launch(bomb, sx, sz, dx, dz, minDist)
	local tx, tz
	local wrapped = false
	local size = dx ~= 0 and Grid.W or Grid.H
	for step = minDist, size - 1 do
		local cx, cz = sx + dx * step, sz + dz * step
		local w = not Grid.inBounds(cx, cz)
		cx = (cx - 1) % Grid.W + 1
		cz = (cz - 1) % Grid.H + 1
		if cellFree(cx, cz, false) then
			tx, tz, wrapped = cx, cz, w
			break
		end
	end
	if not tx then
		for step = minDist - 1, 1, -1 do
			local cx, cz = sx + dx * step, sz + dz * step
			if cellFree(cx, cz, false) then
				tx, tz = cx, cz
				break
			end
		end
	end
	if not tx then
		return false
	end
	bomb.state = "flying"
	bomb.solid = false
	bomb.part.CanCollide = false
	-- Note: while flying the bomb is NOT in bombAt, so fire can't
	-- set it off in mid-air. It lands on (x, z).
	bomb.x, bomb.z = tx, tz
	local from = bomb.part.Position
	local to = Grid.cellPos(tx, tz) + BOMB_Y
	if wrapped then
		-- two pieces: to just past the edge, then from the opposite side to the target
		local exitPos, entryPos
		if dx ~= 0 then
			exitPos = Vector3.new(Grid.cellPos(dx > 0 and Grid.W + 1.5 or -0.5, sz).X, from.Y, from.Z)
			entryPos = Vector3.new(Grid.cellPos(dx > 0 and -0.5 or Grid.W + 1.5, sz).X, to.Y, to.Z)
		else
			exitPos = Vector3.new(from.X, from.Y, Grid.cellPos(sx, dz > 0 and Grid.H + 1.5 or -0.5).Z)
			entryPos = Vector3.new(to.X, to.Y, Grid.cellPos(sx, dz > 0 and -0.5 or Grid.H + 1.5).Z)
		end
		bomb.path = { { from, exitPos, "up" }, { entryPos, to, "down" } }
	else
		bomb.path = { { from, to, "arc" } }
	end
	local len = 0
	for _, seg in ipairs(bomb.path) do
		len += (seg[2] - seg[1]).Magnitude
	end
	bomb.pathLen = len
	bomb.t0 = os.clock()
	bomb.dur = math.max(0.35, len / Config.THROW_SPEED)
	Sounds.play("Throw", from)
	return true
end

-- The action button (E / 🧤). In order of priority:
--   holding a bomb      -> throw it
--   🦶 and your kicked bomb is sliding -> stop it on the next cell
--   🥊 and a bomb in front of you      -> punch it over the walls
--   🧤 and a bomb under / in front of you -> pick it up
function Bombs.throw(player)
	local s = S.stats[player]
	if not s or not S.alive[player] or S.roundState ~= "playing" then
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
		if launch(bomb, sx, sz, dx, dz, Config.THROW_DISTANCE) then
			s.held = nil
			bomb.holder = nil
		end
		return
	end

	if s.kick then
		local stopped = false
		for b in pairs(S.bombs) do
			if b.state == "sliding" and b.kicker == player and not b.oneStep then
				b.stopNext = true
				stopped = true
			end
		end
		if stopped then
			return
		end
	end

	if s.punch then
		local k = key(sx + dx, sz + dz)
		local b = S.bombAt[k]
		if b and b.state == "placed" then
			S.bombAt[k] = nil
			if launch(b, b.x, b.z, dx, dz, Config.PUNCH_DISTANCE) then
				return
			end
			S.bombAt[k] = b -- nowhere to land: leave it
		end
	end

	if s.throw then
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

-- Make a bomb slide. oneStep = true: only one cell (conveyor belt)
local function startSlide(bomb, dx, dz, speed, oneStep)
	if not cellFree(bomb.x + dx, bomb.z + dz, true) then
		return false
	end
	bomb.state = "sliding"
	bomb.dx, bomb.dz = dx, dz
	bomb.slide = 0
	bomb.slideSpeed = speed
	bomb.oneStep = oneStep
	bomb.solid = false
	bomb.part.CanCollide = false
	return true
end

local function kick(bomb, dx, dz, player)
	if startSlide(bomb, dx, dz, Config.KICK_SPEED, false) then
		bomb.kicker = player
		bomb.stopNext = false
		Sounds.play("Kick", bomb.part.Position)
	end
end

-- A sliding bomb that reaches a warp comes out at the other warp
local function warpBomb(bomb)
	local w = S.warps[key(bomb.x, bomb.z)]
	if w and not S.terrain[key(w.x, w.z)] and cellFree(w.x, w.z, false) then
		if S.bombAt[key(bomb.x, bomb.z)] == bomb then
			S.bombAt[key(bomb.x, bomb.z)] = nil
		end
		bomb.x, bomb.z = w.x, w.z
		S.bombAt[key(w.x, w.z)] = bomb
		Sounds.play("Warp", Grid.cellPos(w.x, w.z))
	end
end

-- Players with the kick shoe who walk into a bomb kick it away
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
					kick(b, dx, dz, plr)
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Every frame
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
				-- find which piece of the path the bomb is on
				local dist = a * bomb.pathLen
				for _, seg in ipairs(bomb.path) do
					local segLen = math.max((seg[2] - seg[1]).Magnitude, 0.001)
					if dist <= segLen or seg == bomb.path[#bomb.path] then
						local f = math.clamp(dist / segLen, 0, 1)
						local h
						if seg[3] == "up" then
							h = math.sin(math.pi / 2 * f) * 12 -- high over the outer wall
						elseif seg[3] == "down" then
							h = math.cos(math.pi / 2 * f) * 12
						else
							h = math.sin(math.pi * f) * 6
						end
						bomb.part.Position = seg[1]:Lerp(seg[2], f) + Vector3.new(0, h, 0)
						break
					end
					dist -= segLen
				end
				if a >= 1 then
					local k = key(bomb.x, bomb.z)
					if S.terrain[k] or S.bombAt[k] then
						-- a wall or bomb appeared on the landing spot in the meantime
						Bombs.explode(bomb)
					else
						S.bombAt[k] = bomb
						bomb.state = "placed"
					end
				end
			elseif bomb.state == "sliding" then
				bomb.slide += bomb.slideSpeed * dt
				while bomb.slide >= 1 and bomb.state == "sliding" do
					bomb.slide -= 1
					local k = key(bomb.x, bomb.z)
					if S.bombAt[k] == bomb then
						S.bombAt[k] = nil
					end
					bomb.x, bomb.z = bomb.x + bomb.dx, bomb.z + bomb.dz
					S.bombAt[key(bomb.x, bomb.z)] = bomb
					warpBomb(bomb)
					if bomb.oneStep or bomb.stopNext or not cellFree(bomb.x + bomb.dx, bomb.z + bomb.dz, true) then
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
			elseif bomb.state == "placed" and S.belts[key(bomb.x, bomb.z)] then
				-- a bomb on a conveyor belt moves along one cell at a time
				local b = S.belts[key(bomb.x, bomb.z)]
				startSlide(bomb, b.dx, b.dz, Config.BELT_BOMB_SPEED, true)
			elseif bomb.state == "placed" and not bomb.solid then
				-- only solid once nobody stands on it (so you can walk off your own bomb)
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

-- Fire kills players standing in it
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
