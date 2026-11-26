-- Rooster-hulpfuncties: van vakje naar positie en terug
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("BombConfig"))

local T, W, H = Config.TILE, Config.WIDTH, Config.HEIGHT
local originX = -(W - 1) * T / 2
local originZ = -(H - 1) * T / 2

local Grid = {
	T = T,
	W = W,
	H = H,
	DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } },
	CORNERS = { { 1, 1 }, { W, H }, { W, 1 }, { 1, H } },
}

function Grid.cellPos(x, z)
	return Vector3.new(originX + (x - 1) * T, 0, originZ + (z - 1) * T)
end

function Grid.cellOf(p)
	return math.floor((p.X - originX) / T + 0.5) + 1, math.floor((p.Z - originZ) / T + 0.5) + 1
end

function Grid.key(x, z)
	return x * 100 + z
end

function Grid.inBounds(x, z)
	return x >= 1 and x <= W and z >= 1 and z <= H
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
	local x1, z1, x2, z2 = 1, 1, W, H
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
