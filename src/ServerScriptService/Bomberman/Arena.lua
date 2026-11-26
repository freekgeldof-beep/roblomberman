-- Arena: vloer, muren, kisten, en muren die vallen tijdens sudden death
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage:WaitForChild("BombConfig"))
local Grid = require(script.Parent.Grid)
local S = require(script.Parent.State)
local Powerups = require(script.Parent.Powerups)
local Sounds = require(script.Parent.Sounds)

local T, W, H = Grid.T, Grid.W, Grid.H
local Arena = {}

local WALL_COLOR = Color3.fromRGB(110, 110, 120)

-- Vakjes rond de startplekken blijven leeg, zodat je niet vast zit
local function isSafe(x, z)
	for _, c in ipairs(Grid.CORNERS) do
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
	p.Parent = S.arena
	return p
end

function Arena.build()
	if S.arena then
		S.arena:Destroy()
	end
	S.gen += 1
	table.clear(S.terrain)
	table.clear(S.crateParts)
	table.clear(S.bombs)
	table.clear(S.bombAt)
	table.clear(S.powerups)
	table.clear(S.flames)

	S.arena = Instance.new("Folder")
	S.arena.Name = "Arena"
	S.arena.Parent = workspace

	local light = Color3.fromRGB(96, 168, 90)
	local dark = Color3.fromRGB(80, 148, 76)
	for x = 1, W do
		for z = 1, H do
			local floor = makePart(Vector3.new(T, 1, T), Grid.cellPos(x, z) + Vector3.new(0, -0.5, 0), (x + z) % 2 == 0 and light or dark, Enum.Material.Grass)
			floor.Name = "Floor"
			if x % 2 == 0 and z % 2 == 0 then
				S.terrain[Grid.key(x, z)] = "wall"
				local w = makePart(Vector3.new(T, T, T), Grid.cellPos(x, z) + Vector3.new(0, T / 2, 0), WALL_COLOR, Enum.Material.Concrete)
				w.Name = "Wall"
			elseif not isSafe(x, z) and math.random() < Config.CRATE_CHANCE then
				S.terrain[Grid.key(x, z)] = "crate"
				local c = makePart(Vector3.new(T - 0.1, T - 0.1, T - 0.1), Grid.cellPos(x, z) + Vector3.new(0, T / 2, 0), Color3.fromRGB(176, 124, 70), Enum.Material.WoodPlanks)
				c.Name = "Crate"
				S.crateParts[Grid.key(x, z)] = c
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

local function removeCratePart(k)
	local part = S.crateParts[k]
	S.crateParts[k] = nil
	if part then
		TweenService:Create(part, TweenInfo.new(0.3), { Transparency = 1, Size = part.Size * 0.6 }):Play()
		Debris:AddItem(part, 0.4)
	end
end

function Arena.destroyCrate(x, z)
	local k = Grid.key(x, z)
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

-- Sudden death: er valt een muurblok op dit vakje. Geeft false als er al een muur stond.
function Arena.closeCell(x, z)
	local k = Grid.key(x, z)
	if S.terrain[k] == "wall" then
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
