-- Rooster-hulpfuncties: van vakje naar positie en terug.
-- De grootte kan per ronde veranderen (Grid.setSize), afhankelijk van het aantal spelers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("BombConfig"))

local T = Config.TILE

local Grid = {
	T = T,
	W = 13,
	H = 13,
	DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } },
}

local originX, originZ = 0, 0

-- Dichtstbijzijnde oneven getal (in oneven rijen/kolommen staan nooit vaste muren)
function Grid.odd(v)
	return math.floor((v - 1) / 2 + 0.5) * 2 + 1
end

function Grid.setSize(w, h)
	Grid.W, Grid.H = w, h
	originX = -(w - 1) * T / 2
	originZ = -(h - 1) * T / 2
	Grid.XM, Grid.ZM = Grid.odd((w + 1) / 2), Grid.odd((h + 1) / 2) -- midden
end
Grid.setSize(Grid.W, Grid.H)

-- Kies de arenagrootte bij het aantal spelers
function Grid.sizeFor(playerCount)
	for _, row in ipairs(Config.ARENA_SIZES) do
		if playerCount <= row.players then
			return row.w, row.h
		end
	end
	local last = Config.ARENA_SIZES[#Config.ARENA_SIZES]
	return last.w, last.h
end

-- Startplekken: eerst de vier hoeken, daarna het midden van elke rand
function Grid.spawns()
	local W, H, XM, ZM = Grid.W, Grid.H, Grid.XM, Grid.ZM
	return {
		{ 1, 1 }, { W, H }, { W, 1 }, { 1, H },
		{ XM, 1 }, { XM, H }, { 1, ZM }, { W, ZM },
	}
end

function Grid.cellPos(x, z)
	return Vector3.new(originX + (x - 1) * T, 0, originZ + (z - 1) * T)
end

function Grid.cellOf(p)
	return math.floor((p.X - originX) / T + 0.5) + 1, math.floor((p.Z - originZ) / T + 0.5) + 1
end

function Grid.key(x, z)
	return x * 100 + z
end

function Grid.unkey(k)
	return k // 100, k % 100
end

function Grid.inBounds(x, z)
	return x >= 1 and x <= Grid.W and z >= 1 and z <= Grid.H
end

-- Hoofdrichting (één as) van een vector, bijv. kijk- of looprichting
function Grid.axisDir(v)
	if math.abs(v.X) > math.abs(v.Z) then
		return v.X > 0 and 1 or -1, 0
	end
	return 0, v.Z > 0 and 1 or -1
end

-- Alle vakjes in een spiraal van buiten naar binnen (voor sudden death)
function Grid.spiral()
	local out = {}
	local x1, z1, x2, z2 = 1, 1, Grid.W, Grid.H
	while x1 <= x2 and z1 <= z2 do
		for x = x1, x2 do
			out[#out + 1] = { x, z1 }
		end
		for z = z1 + 1, z2 do
			out[#out + 1] = { x2, z }
		end
		if z1 < z2 then
			for x = x2 - 1, x1, -1 do
				out[#out + 1] = { x, z2 }
			end
		end
		if x1 < x2 then
			for z = z2 - 1, z1 + 1, -1 do
				out[#out + 1] = { x1, z }
			end
		end
		x1, z1, x2, z2 = x1 + 1, z1 + 1, x2 - 1, z2 - 1
	end
	return out
end

return Grid
