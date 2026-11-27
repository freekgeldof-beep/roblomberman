-- RemoteEvents and round info for the clients
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder = Instance.new("Folder")
folder.Name = "BombRemotes"
Net.folder = folder

local function newRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	return r
end

Net.PlaceBomb = newRemote("PlaceBomb")
Net.ThrowBomb = newRemote("ThrowBomb")
Net.Announce = newRemote("Announce") -- (message, seconds, small?) – message is a Lang key table
Net.RoundResult = newRemote("RoundResult") -- (title message, rows, seconds)

-- Round info as attributes on the folder: State, RoundEndsAt, SuddenDeath, AliveCount,
-- Round, ArenaW, ArenaH, Belts
folder:SetAttribute("State", "lobby")
folder.Parent = ReplicatedStorage

function Net.announce(text, seconds, small, player)
	if player then
		if player:IsA("Player") then -- bots have no screen
			Net.Announce:FireClient(player, text, seconds or 3, small)
		end
	else
		Net.Announce:FireAllClients(text, seconds or 3, small)
	end
end

function Net.set(name, value)
	folder:SetAttribute(name, value)
end

return Net
