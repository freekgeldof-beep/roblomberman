-- Small 3D models for the goodies, built from plain parts (no uploaded assets needed).
-- GoodieModels.build(kind) returns a Model centred on the origin, about 2.5 studs tall.
-- The client spins and bobs every model tagged "Goodie3D" (see BombermanClient).
local GoodieModels = {}

local NEON = Enum.Material.Neon
local PLASTIC = Enum.Material.SmoothPlastic

local function add(model, size, cf, color, material, meshType)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or PLASTIC
	if meshType then
		-- a SpecialMesh stretches to the part size, so this gives ellipsoids / cylinders
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = meshType
		mesh.Parent = p
	end
	p.Parent = model
	return p
end

local function ball(model, size, pos, color, material)
	return add(model, size, CFrame.new(pos), color, material, Enum.MeshType.Sphere)
end

-- vertical cylinder (Roblox cylinders lie along X, so turn it upright)
local function cyl(model, height, diameter, pos, color, material)
	return add(model, Vector3.new(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.MeshType.Cylinder)
end

local function block(model, size, cf, color, material)
	return add(model, size, cf, color, material)
end

local ORANGE = Color3.fromRGB(255, 110, 20)
local AMBER = Color3.fromRGB(255, 170, 30)
local YELLOW = Color3.fromRGB(255, 235, 90)
local WHITE = Color3.fromRGB(245, 245, 245)
local DARK = Color3.fromRGB(30, 30, 38)

local function flame(m, scale, y)
	local s = scale or 1
	y = y or 0
	ball(m, Vector3.new(1.6, 1.5, 1.6) * s, Vector3.new(0, y - 0.3 * s, 0), ORANGE, NEON)
	ball(m, Vector3.new(1.2, 1.3, 1.2) * s, Vector3.new(0, y + 0.35 * s, 0), AMBER, NEON)
	ball(m, Vector3.new(0.75, 1.0, 0.75) * s, Vector3.new(0, y + 0.95 * s, 0), YELLOW, NEON)
	ball(m, Vector3.new(0.35, 0.6, 0.35) * s, Vector3.new(0.1 * s, y + 1.45 * s, 0), YELLOW, NEON)
	ball(m, Vector3.new(0.7, 0.7, 0.7) * s, Vector3.new(0, y - 0.35 * s, 0), Color3.fromRGB(255, 250, 200), NEON)
end

local function speedLines(m, x)
	for i, y in ipairs({ 0.3, -0.1, -0.5 }) do
		block(m, Vector3.new(0.5 + i * 0.12, 0.08, 0.08), CFrame.new(x - i * 0.06, y, 0), WHITE, NEON)
	end
end

local BUILDERS = {}

-- 🔥 fire range +1: a flame with a plus sign
BUILDERS.Range = function(m)
	flame(m, 1, 0)
	block(m, Vector3.new(0.6, 0.16, 0.16), CFrame.new(0.95, 0.9, 0), WHITE, NEON)
	block(m, Vector3.new(0.16, 0.6, 0.16), CFrame.new(0.95, 0.9, 0), WHITE, NEON)
end

-- 💣 extra bomb: black ball, cap, fuse and a glowing spark
BUILDERS.Bomb = function(m)
	ball(m, Vector3.new(1.9, 1.9, 1.9), Vector3.new(0, -0.1, 0), DARK, Enum.Material.Metal)
	ball(m, Vector3.new(0.45, 0.45, 0.45), Vector3.new(-0.45, 0.35, 0.6), Color3.fromRGB(150, 150, 170), PLASTIC)
	cyl(m, 0.3, 0.65, Vector3.new(0, 0.9, 0), Color3.fromRGB(110, 110, 125), Enum.Material.Metal)
	block(m, Vector3.new(0.12, 0.55, 0.12), CFrame.new(0.12, 1.25, 0) * CFrame.Angles(0, 0, math.rad(-25)), Color3.fromRGB(200, 170, 120))
	local spark = ball(m, Vector3.new(0.4, 0.4, 0.4), Vector3.new(0.27, 1.55, 0), YELLOW, NEON)
	local light = Instance.new("PointLight")
	light.Color = AMBER
	light.Range = 6
	light.Parent = spark
end

-- 👟 run faster: a sneaker with speed lines
BUILDERS.Speed = function(m)
	local blue = Color3.fromRGB(60, 150, 255)
	block(m, Vector3.new(2.0, 0.3, 0.9), CFrame.new(0.1, -0.65, 0), WHITE)
	block(m, Vector3.new(1.1, 0.8, 0.85), CFrame.new(-0.35, -0.1, 0), blue)
	ball(m, Vector3.new(1.2, 0.65, 0.85), Vector3.new(0.45, -0.3, 0), blue)
	block(m, Vector3.new(0.16, 0.7, 0.9), CFrame.new(-0.2, -0.1, 0), Color3.fromRGB(255, 80, 80), NEON)
	block(m, Vector3.new(0.7, 0.25, 0.7), CFrame.new(-0.45, 0.4, 0), WHITE)
	speedLines(m, -1.35)
end

-- ⚡ pierce bombs: a zig-zag lightning bolt
BUILDERS.Pierce = function(m)
	local c = YELLOW
	block(m, Vector3.new(0.4, 1.1, 0.4), CFrame.new(0.25, 0.75, 0) * CFrame.Angles(0, 0, math.rad(-28)), c, NEON)
	block(m, Vector3.new(1.0, 0.35, 0.4), CFrame.new(0.05, 0.15, 0) * CFrame.Angles(0, 0, math.rad(15)), c, NEON)
	block(m, Vector3.new(0.4, 1.2, 0.4), CFrame.new(-0.15, -0.5, 0) * CFrame.Angles(0, 0, math.rad(-28)), c, NEON)
	ball(m, Vector3.new(0.35, 0.35, 0.35), Vector3.new(-0.45, -1.05, 0), WHITE, NEON)
end

-- 🧤 glove: an open hand to grab bombs with
BUILDERS.Throw = function(m)
	local green = Color3.fromRGB(110, 220, 110)
	ball(m, Vector3.new(1.3, 1.2, 0.55), Vector3.new(0, 0, 0), green)
	for i = 0, 3 do
		local x = -0.45 + i * 0.3
		cyl(m, 0.75 - math.abs(i - 1.5) * 0.12, 0.26, Vector3.new(x, 0.8, 0), green)
	end
	add(m, Vector3.new(0.3, 0.7, 0.3), CFrame.new(0.75, 0.1, 0) * CFrame.Angles(0, 0, math.rad(-45)), green, PLASTIC, Enum.MeshType.Sphere)
	cyl(m, 0.4, 1.0, Vector3.new(0, -0.75, 0), Color3.fromRGB(40, 120, 50))
end

-- 🦶 kick shoe: a boot with speed lines
BUILDERS.Kick = function(m)
	local pink = Color3.fromRGB(255, 120, 200)
	block(m, Vector3.new(0.8, 1.2, 0.8), CFrame.new(-0.35, 0.35, 0), pink)
	ball(m, Vector3.new(1.7, 0.75, 0.85), Vector3.new(0.2, -0.4, 0), pink)
	block(m, Vector3.new(1.8, 0.18, 0.9), CFrame.new(0.2, -0.8, 0), DARK)
	block(m, Vector3.new(0.85, 0.15, 0.85), CFrame.new(-0.35, 0.85, 0), WHITE)
	speedLines(m, -1.3)
end

-- 🥊 boxing glove (rare)
BUILDERS.Punch = function(m)
	local red = Color3.fromRGB(230, 30, 40)
	ball(m, Vector3.new(1.6, 1.4, 1.3), Vector3.new(0, 0.35, 0), red)
	ball(m, Vector3.new(0.55, 0.8, 0.5), Vector3.new(-0.2, 0.2, 0.7), red)
	ball(m, Vector3.new(0.5, 0.35, 0.3), Vector3.new(-0.3, 0.75, -0.45), Color3.fromRGB(255, 120, 120), NEON)
	cyl(m, 0.6, 1.0, Vector3.new(0, -0.6, 0), WHITE)
	block(m, Vector3.new(0.9, 0.08, 1.02), CFrame.new(0, -0.45, 0), Color3.fromRGB(255, 215, 70), NEON)
end

-- 🌋 max fire (very rare): a big flame on a golden disc
BUILDERS.MaxFire = function(m)
	flame(m, 1.3, 0.1)
	cyl(m, 0.15, 2.3, Vector3.new(0, -0.95, 0), Color3.fromRGB(255, 205, 60), NEON)
	for i = 0, 3 do
		local a = i * math.pi / 2
		ball(m, Vector3.new(0.3, 0.3, 0.3), Vector3.new(math.cos(a) * 1.15, -0.8, math.sin(a) * 1.15), WHITE, NEON)
	end
end

-- 💀 curse: a skull
BUILDERS.Skull = function(m)
	ball(m, Vector3.new(1.5, 1.35, 1.45), Vector3.new(0, 0.3, 0), WHITE)
	block(m, Vector3.new(0.95, 0.5, 0.9), CFrame.new(0, -0.5, 0.1), WHITE)
	for _, side in ipairs({ 1, -1 }) do
		-- eyes on the front and the back, so you see a face while it spins
		ball(m, Vector3.new(0.42, 0.45, 0.2), Vector3.new(-0.32, 0.2, 0.68 * side), DARK)
		ball(m, Vector3.new(0.42, 0.45, 0.2), Vector3.new(0.32, 0.2, 0.68 * side), DARK)
		ball(m, Vector3.new(0.12, 0.12, 0.08), Vector3.new(-0.32, 0.22, 0.75 * side), Color3.fromRGB(255, 50, 50), NEON)
		ball(m, Vector3.new(0.12, 0.12, 0.08), Vector3.new(0.32, 0.22, 0.75 * side), Color3.fromRGB(255, 50, 50), NEON)
		block(m, Vector3.new(0.6, 0.06, 0.05), CFrame.new(0, -0.5, 0.56 * side), DARK)
	end
end

function GoodieModels.build(kind)
	local m = Instance.new("Model")
	m.Name = "Goodie_" .. kind
	local builder = BUILDERS[kind] or BUILDERS.Bomb
	builder(m)
	m:ScaleTo(1.25) -- readable from the top-down camera
	return m
end

return GoodieModels
