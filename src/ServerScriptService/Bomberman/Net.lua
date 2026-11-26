-- RemoteEvents en ronde-informatie voor de clients
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
Net.Announce = newRemote("Announce") -- (tekst, seconden, klein?)
Net.RoundResult = newRemote("RoundResult") -- (titel, rijen)

-- Ronde-info als attributen op de map: State, RoundEndsAt, SuddenDeath, AliveCount, Round
folder:SetAttribute("State", "lobby")
folder.Parent = ReplicatedStorage

function Net.announce(text, seconds, small, player)
	if player then
		Net.Announce:FireClient(player, text, seconds or 3, small)
	else
		Net.Announce:FireAllClients(text, seconds or 3, small)
	end
end

function Net.set(name, value)
	folder:SetAttribute(name, value)
end

return Net
