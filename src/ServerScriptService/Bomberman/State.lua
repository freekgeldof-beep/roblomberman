-- Gedeelde toestand van het spel (één tabel die alle modules gebruiken)
local State = {
	arena = nil, -- Folder met alle onderdelen van de huidige arena
	gen = 0, -- telt op bij elke nieuwe arena, zodat oude timers niets meer doen
	terrain = {}, -- key -> "wall" | "crate"
	crateParts = {}, -- key -> Part
	bombs = {}, -- set van bommen
	bombAt = {}, -- key -> bom die op dat vakje ligt
	powerups = {}, -- key -> { part, kind }
	flames = {}, -- lijst van { cells = {key=true}, expires }
	warps = {}, -- key -> { x, z } van de andere warp
	belts = {}, -- key -> { dx, dz }
	toggles = {}, -- key -> { x, z, part, up, closed }
	stats = {}, -- player -> stats
	alive = {}, -- player -> true
	roundPlayers = {}, -- spelers die deze ronde meedoen
	roundState = "lobby", -- lobby | playing | over
}

function State.getRoot(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

function State.getHum(player)
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

-- Staat er een levende speler op dit vakje?
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
