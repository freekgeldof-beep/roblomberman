-- Geluiden afspelen (ids staan in BombConfig.SOUNDS)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage:WaitForChild("BombConfig"))

local Sounds = {}

local holder = Instance.new("Folder")
holder.Name = "BombSounds"
holder.Parent = workspace

-- position = nil speelt het geluid overal even hard af
function Sounds.play(name, position)
	local def = Config.SOUNDS[name]
	if not def or def.id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = def.id
	s.Volume = def.volume or 0.6
	s.PlaybackSpeed = def.speed or 1
	s.RollOffMaxDistance = 300
	s.RollOffMinDistance = 40
	if position then
		local att = Instance.new("Attachment")
		att.WorldPosition = position
		att.Parent = workspace.Terrain
		s.Parent = att
		Debris:AddItem(att, 6)
	else
		s.Parent = holder
		Debris:AddItem(s, 6)
	end
	s:Play()
end

return Sounds
