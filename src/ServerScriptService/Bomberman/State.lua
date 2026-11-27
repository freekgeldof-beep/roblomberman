-- Shared game state (one table all modules use)
local State = {
	arena = nil, -- Folder with all parts of the current arena
	gen = 0, -- goes up with every new arena, so old timers stop doing anything
	terrain = {}, -- key -> "wall" | "crate"
	crateParts = {}, -- key -> Part
	bombs = {}, -- set of bombs
	bombAt = {}, -- key -> bomb lying on that cell
	powerups = {}, -- key -> { part, kind }
	flames = {}, -- list of { cells = {key=true}, expires }
	warps = {}, -- key -> { x, z } of the other warp
	belts = {}, -- key -> { dx, dz }
	toggles = {}, -- key -> { x, z, part, up, closed }
	ice = {}, -- key -> true
	stats = {}, -- player -> stats
	alive = {}, -- player -> true
	roundPlayers = {}, -- players (and bots) in this round
	roundState = "lobby", -- lobby | playing | over
}

-- Bots are Folder instances (not Players); their character models live here
State.botChars = {} -- bot Folder -> Model

function State.isBot(p)
	return not p:IsA("Player")
end

function State.charOf(p)
	if p:IsA("Player") then
		return p.Character
	end
	return State.botChars[p]
end

function State.nameOf(p)
	if p:IsA("Player") then
		return p.DisplayName
	end
	return p:GetAttribute("DisplayName") or p.Name
end

function State.getRoot(player)
	local c = State.charOf(player)
	return c and c:FindFirstChild("HumanoidRootPart")
end

function State.getHum(player)
	local c = State.charOf(player)
	return c and c:FindFirstChildOfClass("Humanoid")
end

-- Is a living player on this cell?
function State.playerOnCell(cellOf, x, z)
	for plr in pairs(State.alive) do
		local root = State.getRoot(plr)
		if root then
			local px, pz = cellOf(root.Position)
			if px == x and pz == z then
				return plr
			end
		end
	end
	return nil
end

return State
