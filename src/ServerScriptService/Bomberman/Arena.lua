-- Arena: floor, walls, crates, special cells (warps, belts, switch walls),
-- the random theme of each round and the walls that drop during sudden death
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage:WaitForChild("BombConfig"))
local Grid = require(script.Parent.Grid)
local S = require(script.Parent.State)
local Net = require(script.Parent.Net)
local Powerups = require(script.Parent.Powerups)
local Sounds = require(script.Parent.Sounds)

local T = Grid.T
local key = Grid.key
local Arena = {}

local Lighting = game:GetService("Lighting")

-- Themes: each round picks one at random so the arena doesn't always look the same
local THEMES = {
	{
		name = "Grass",
		floor = { Color3.fromRGB(96, 168, 90), Color3.fromRGB(80, 148, 76) }, floorMat = Enum.Material.Grass,
		wall = Color3.fromRGB(110, 110, 120), wallMat = Enum.Material.Concrete,
		crate = Color3.fromRGB(176, 124, 70), crateMat = Enum.Material.WoodPlanks,
		rim = Color3.fromRGB(60, 60, 72), rimMat = Enum.Material.Slate,
		clock = 14, ambient = Color3.fromRGB(110, 110, 110),
	},
	{
		name = "Desert",
		floor = { Color3.fromRGB(226, 196, 132), Color3.fromRGB(212, 180, 116) }, floorMat = Enum.Material.Sand,
		wall = Color3.fromRGB(176, 120, 80), wallMat = Enum.Material.Sandstone,
		crate = Color3.fromRGB(120, 160, 80), crateMat = Enum.Material.Grass, -- cactus-coloured bushes
		rim = Color3.fromRGB(150, 100, 64), rimMat = Enum.Material.Sandstone,
		clock = 16.5, ambient = Color3.fromRGB(140, 120, 100),
	},
	{
		name = "Snow",
		floor = { Color3.fromRGB(235, 242, 250), Color3.fromRGB(215, 228, 242) }, floorMat = Enum.Material.Snow,
		wall = Color3.fromRGB(140, 190, 230), wallMat = Enum.Material.Ice,
		crate = Color3.fromRGB(190, 120, 80), crateMat = Enum.Material.WoodPlanks,
		rim = Color3.fromRGB(110, 150, 190), rimMat = Enum.Material.Glacier,
		clock = 12, ambient = Color3.fromRGB(150, 160, 180),
	},
	{
		name = "Lava",
		floor = { Color3.fromRGB(70, 60, 60), Color3.fromRGB(58, 50, 50) }, floorMat = Enum.Material.Basalt,
		wall = Color3.fromRGB(40, 36, 40), wallMat = Enum.Material.Basalt,
		crate = Color3.fromRGB(200, 80, 30), crateMat = Enum.Material.CrackedLava,
		rim = Color3.fromRGB(255, 90, 20), rimMat = Enum.Material.Neon,
		clock = 19, ambient = Color3.fromRGB(120, 70, 60),
	},
	{
		name = "Space",
		floor = { Color3.fromRGB(40, 36, 70), Color3.fromRGB(32, 28, 58) }, floorMat = Enum.Material.SmoothPlastic,
		wall = Color3.fromRGB(120, 110, 200), wallMat = Enum.Material.Metal,
		crate = Color3.fromRGB(80, 200, 220), crateMat = Enum.Material.Glass,
		rim = Color3.fromRGB(170, 80, 255), rimMat = Enum.Material.Neon,
		clock = 0, ambient = Color3.fromRGB(110, 100, 150),
	},
}
local theme = THEMES[1]
local WARP_COLORS = { Color3.fromRGB(170, 80, 255), Color3.fromRGB(40, 220, 255) }
local TOGGLE_COLOR = Color3.fromRGB(230, 90, 60)

-- Cells around the spawn points stay empty so nobody starts boxed in
local function isSafe(x, z, spawns)
	for _, c in ipairs(spawns) do
		local ax, az = math.abs(x - c[1]), math.abs(z - c[2])
		if (az == 0 and ax <= 2) or (ax == 0 and az <= 2) or (ax == 2 and az == 1) or (ax == 1 and az == 2) then
			return true
		end
	end
	return false
end

local function isFixedWall(x, z)
	return x % 2 == 0 and z % 2 == 0
end

local function makePart(size, pos, color, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material
	p.Parent = S.arena
	return p
end

----------------------------------------------------------------------
-- Planning the special cells (they scale with the arena size)
----------------------------------------------------------------------
local function planWarps(reserved)
	local W, H = Grid.W, Grid.H
	local xq, zq = Grid.odd(W / 4), Grid.odd(H / 4)
	local pairs_ = {
		{ { xq, zq }, { W + 1 - xq, H + 1 - zq } },
		{ { W + 1 - xq, zq }, { xq, H + 1 - zq } },
	}
	for i, pr in ipairs(pairs_) do
		local a, b = pr[1], pr[2]
		S.warps[key(a[1], a[2])] = { x = b[1], z = b[2], pair = i }
		S.warps[key(b[1], b[2])] = { x = a[1], z = a[2], pair = i }
		reserved[key(a[1], a[2])] = true
		reserved[key(b[1], b[2])] = true
	end
end

local function planBelts(reserved)
	local W, H, XM, ZM = Grid.W, Grid.H, Grid.XM, Grid.ZM
	-- one belt through the middle row, and in big arenas one through the middle column too
	local dx = math.random() < 0.5 and 1 or -1
	for x = 3, W - 2 do
		local k = key(x, ZM)
		if not reserved[k] then
			S.belts[k] = { dx = dx, dz = 0 }
			reserved[k] = true
		end
	end
	if W >= 21 then
		local dz = math.random() < 0.5 and 1 or -1
		for z = 3, H - 2 do
			local k = key(XM, z)
			if not reserved[k] then
				S.belts[k] = { dx = 0, dz = dz }
				reserved[k] = true
			end
		end
	end
end

local function planToggles(reserved)
	local XM, ZM = Grid.XM, Grid.ZM
	local cells = { { XM - 2, ZM - 2 }, { XM + 2, ZM - 2 }, { XM - 2, ZM + 2 }, { XM + 2, ZM + 2 } }
	if Grid.W >= 21 then
		for _, c in ipairs({ { XM - 4, ZM - 2 }, { XM + 4, ZM - 2 }, { XM - 4, ZM + 2 }, { XM + 4, ZM + 2 } }) do
			cells[#cells + 1] = c
		end
	end
	for _, c in ipairs(cells) do
		local k = key(c[1], c[2])
		if Grid.inBounds(c[1], c[2]) and not isFixedWall(c[1], c[2]) and not reserved[k] then
			S.toggles[k] = { x = c[1], z = c[2], up = false, closed = false }
			reserved[k] = true
		end
	end
end

----------------------------------------------------------------------
-- Building the parts
----------------------------------------------------------------------
local function buildWarp(x, z, pair)
	local color = WARP_COLORS[pair] or WARP_COLORS[1]
	local pad = makePart(Vector3.new(0.3, T - 0.6, T - 0.6), Grid.cellPos(x, z) + Vector3.new(0, 0.15, 0), color, Enum.Material.Neon)
	pad.Name = "Warp"
	pad.Shape = Enum.PartType.Cylinder
	pad.Orientation = Vector3.new(0, 0, 90)
	pad.CanCollide = false
	pad.CanQuery = false
	local att = Instance.new("Attachment")
	att.Parent = pad
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 18
	pe.Lifetime = NumberRange.new(0.6, 1)
	pe.Speed = NumberRange.new(4, 6)
	pe.EmissionDirection = Enum.NormalId.Right -- because of the rotation this is "up"
	pe.SpreadAngle = Vector2.new(15, 15)
	pe.LightEmission = 1
	pe.Color = ColorSequence.new(color)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.Parent = att
end

local function buildBelt(x, z, b)
	local pos = Grid.cellPos(x, z)
	local base = makePart(Vector3.new(T, 0.2, T), pos + Vector3.new(0, 0.1, 0), Color3.fromRGB(45, 45, 55), Enum.Material.DiamondPlate)
	base.Name = "Belt"
	base.CanCollide = false
	base.CanQuery = false
	-- glowing stripes that slide over the belt in its direction
	local dir = Vector3.new(b.dx, 0, b.dz)
	local across = b.dx ~= 0 and Vector3.new(0.4, 0.06, T - 0.6) or Vector3.new(T - 0.6, 0.06, 0.4)
	for i = 0, 1 do
		local stripe = makePart(across, pos + Vector3.new(0, 0.23, 0) - dir * (T / 2 - 0.3), Color3.fromRGB(255, 210, 60), Enum.Material.Neon)
		stripe.Name = "BeltStripe"
		stripe.CanCollide = false
		stripe.CanQuery = false
		local tween = TweenService:Create(stripe, TweenInfo.new(T / Config.BELT_SPEED, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {
			Position = pos + Vector3.new(0, 0.23, 0) + dir * (T / 2 - 0.3),
		})
		task.delay(i * (T / Config.BELT_SPEED) / 2, function()
			if stripe.Parent then
				tween:Play()
			end
		end)
	end
end

local function toggleDownPos(x, z)
	return Grid.cellPos(x, z) + Vector3.new(0, -T / 2 + 0.15, 0)
end

local function buildToggle(tg)
	local p = makePart(Vector3.new(T - 0.1, T, T - 0.1), toggleDownPos(tg.x, tg.z), TOGGLE_COLOR, Enum.Material.Metal)
	p.Name = "ToggleWall"
	p.CanCollide = false
	tg.part = p
end

function Arena.build(playerCount)
	if S.arena then
		S.arena:Destroy()
	end
	S.gen += 1
	for _, t in ipairs({ S.terrain, S.crateParts, S.bombs, S.bombAt, S.powerups, S.flames, S.warps, S.belts, S.toggles }) do
		table.clear(t)
	end

	local W, H = Grid.sizeFor(playerCount)
	Grid.setSize(W, H)

	theme = THEMES[math.random(#THEMES)]
	Lighting.ClockTime = theme.clock
	Lighting.Ambient = theme.ambient
	Lighting.OutdoorAmbient = theme.ambient

	S.arena = Instance.new("Folder")
	S.arena.Name = "Arena"
	S.arena.Parent = workspace

	-- pick a theme and the special cells for this round
	local reserved = {}
	local features = {}
	for name, chance in pairs(Config.FEATURE_CHANCE) do
		features[name] = math.random() < chance
	end
	if features.Warps then
		planWarps(reserved)
	end
	if features.Belts then
		planBelts(reserved)
	end
	if features.Toggles then
		planToggles(reserved)
	end

	local spawns = Grid.spawns()
	local light, dark = theme.floor[1], theme.floor[2]
	for x = 1, W do
		for z = 1, H do
			local k = key(x, z)
			local floor = makePart(Vector3.new(T, 1, T), Grid.cellPos(x, z) + Vector3.new(0, -0.5, 0), (x + z) % 2 == 0 and light or dark, theme.floorMat)
			floor.Name = "Floor"
			if isFixedWall(x, z) then
				S.terrain[k] = "wall"
				local w = makePart(Vector3.new(T, T, T), Grid.cellPos(x, z) + Vector3.new(0, T / 2, 0), theme.wall, theme.wallMat)
				w.Name = "Wall"
			elseif not reserved[k] and not isSafe(x, z, spawns) and math.random() < Config.CRATE_CHANCE then
				S.terrain[k] = "crate"
				local c = makePart(Vector3.new(T - 0.1, T - 0.1, T - 0.1), Grid.cellPos(x, z) + Vector3.new(0, T / 2, 0), theme.crate, theme.crateMat)
				c.Name = "Crate"
				S.crateParts[k] = c
			end
		end
	end

	for k, w in pairs(S.warps) do
		local x, z = Grid.unkey(k)
		buildWarp(x, z, w.pair)
	end
	local beltList = {}
	for k, b in pairs(S.belts) do
		local x, z = Grid.unkey(k)
		buildBelt(x, z, b)
		beltList[#beltList + 1] = string.format("%d,%d,%d,%d", x, z, b.dx, b.dz)
	end
	for _, tg in pairs(S.toggles) do
		buildToggle(tg)
	end

	-- outer rim
	local hw, hh = W * T / 2, H * T / 2
	local rim, rimMat = theme.rim, theme.rimMat
	makePart(Vector3.new(W * T + 2 * T, 2 * T, T), Vector3.new(0, T, -hh - T / 2), rim, rimMat)
	makePart(Vector3.new(W * T + 2 * T, 2 * T, T), Vector3.new(0, T, hh + T / 2), rim, rimMat)
	makePart(Vector3.new(T, 2 * T, H * T), Vector3.new(-hw - T / 2, T, 0), rim, rimMat)
	makePart(Vector3.new(T, 2 * T, H * T), Vector3.new(hw + T / 2, T, 0), rim, rimMat)

	-- clients need the size and the belts (camera, corner assist, being pushed)
	Net.set("ArenaW", W)
	Net.set("ArenaH", H)
	Net.set("Belts", table.concat(beltList, ";"))

	local names = {}
	if features.Warps then
		names[#names + 1] = { k = "feat_warps" }
	end
	if features.Belts then
		names[#names + 1] = { k = "feat_belts" }
	end
	if features.Toggles then
		names[#names + 1] = { k = "feat_toggles" }
	end
	return names
end

local function removeCratePart(k)
	local part = S.crateParts[k]
	S.crateParts[k] = nil
	if part then
		TweenService:Create(part, TweenInfo.new(0.3), { Transparency = 1, Size = part.Size * 0.6 }):Play()
		Debris:AddItem(part, 0.4)
	end
end

function Arena.destroyCrate(x, z)
	local k = key(x, z)
	S.terrain[k] = nil
	removeCratePart(k)
	if math.random() < Config.DROP_CHANCE then
		local kind = Powerups.pick()
		local myGen = S.gen
		task.delay(Config.FLAME_TIME + 0.05, function()
			if myGen == S.gen and not S.terrain[k] and not S.powerups[k] and not S.bombAt[k] then
				Powerups.spawn(x, z, kind)
			end
		end)
	end
end

----------------------------------------------------------------------
-- Switch walls: every TOGGLE_INTERVAL seconds they all go up or down.
-- A wall only rises when nobody (and no bomb) is on its cell.
----------------------------------------------------------------------
local togglePhaseUp, nextToggle = false, 0

function Arena.resetToggles(now)
	togglePhaseUp = false
	nextToggle = now + Config.TOGGLE_INTERVAL
end

function Arena.updateToggles(now)
	if next(S.toggles) == nil then
		return
	end
	if now >= nextToggle then
		togglePhaseUp = not togglePhaseUp
		nextToggle = now + Config.TOGGLE_INTERVAL
		for _, tg in pairs(S.toggles) do
			tg.pending = true
		end
	end
	for k, tg in pairs(S.toggles) do
		if tg.pending and not tg.closed then
			if togglePhaseUp then
				-- wait until the cell is empty
				if not S.bombAt[k] and not S.playerOnCell(Grid.cellOf, tg.x, tg.z) then
					tg.pending = false
					tg.up = true
					S.terrain[k] = "wall"
					Powerups.remove(k)
					tg.part.CanCollide = true
					TweenService:Create(tg.part, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
						Position = Grid.cellPos(tg.x, tg.z) + Vector3.new(0, T / 2, 0),
					}):Play()
					Sounds.play("Toggle", tg.part.Position)
				end
			else
				tg.pending = false
				if tg.up then
					tg.up = false
					S.terrain[k] = nil
					tg.part.CanCollide = false
					TweenService:Create(tg.part, TweenInfo.new(0.3), { Position = toggleDownPos(tg.x, tg.z) }):Play()
				end
			end
		end
	end
end

-- Sudden death: drop a wall block on this cell. Returns false if a fixed wall was already there.
function Arena.closeCell(x, z)
	local k = key(x, z)
	local tg = S.toggles[k]
	if tg then
		tg.closed = true
		if tg.part then
			tg.part:Destroy()
		end
	elseif S.terrain[k] == "wall" then
		return false
	end
	if S.terrain[k] == "crate" then
		removeCratePart(k)
	end
	S.terrain[k] = "wall"
	Powerups.remove(k)

	local target = Grid.cellPos(x, z) + Vector3.new(0, T / 2, 0)
	local w = makePart(Vector3.new(T, T, T), target + Vector3.new(0, 24, 0), Color3.fromRGB(150, 60, 60), Enum.Material.Concrete)
	w.Name = "DeathWall"
	w.CanCollide = false
	TweenService:Create(w, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = target }):Play()
	task.delay(0.25, function()
		if w.Parent then
			w.CanCollide = true
		end
	end)
	Sounds.play("Wall", target)
	return true
end

return Arena
