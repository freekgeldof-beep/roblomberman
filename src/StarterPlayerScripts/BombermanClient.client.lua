-- Roblomberman: client (bovenaanzicht-camera, HUD, knoppen)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("BombConfig"))
local remotes = ReplicatedStorage:WaitForChild("BombRemotes")
local placeRemote = remotes:WaitForChild("PlaceBomb")
local throwRemote = remotes:WaitForChild("ThrowBomb")
local announceRemote = remotes:WaitForChild("Announce")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
camera.FieldOfView = 40

----------------------------------------------------------------------
-- Camera: vast bovenaanzicht, past zich aan het scherm aan
----------------------------------------------------------------------
RunService:BindToRenderStep("BombCamera", Enum.RenderPriority.Camera.Value + 1, function()
	camera.CameraType = Enum.CameraType.Scriptable
	local vp = camera.ViewportSize
	local aspect = math.max(vp.X, 1) / math.max(vp.Y, 1)
	local t = math.tan(math.rad(camera.FieldOfView / 2))
	local halfH = (Config.HEIGHT * Config.TILE) / 2 + 8
	local halfW = (Config.WIDTH * Config.TILE) / 2 + 5
	local dist = math.max(halfH / t, halfW / (t * aspect)) * 1.05
	-- kleine kanteling zodat "omhoog" op het scherm = noord (-Z) blijft
	camera.CFrame = CFrame.lookAt(Vector3.new(0, dist, dist * 0.22), Vector3.new(0, 0, 0))
end)

----------------------------------------------------------------------
-- Knoppen
----------------------------------------------------------------------
ContextActionService:BindAction("PlaceBomb", function(_, state)
	if state == Enum.UserInputState.Begin then
		placeRemote:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
ContextActionService:SetTitle("PlaceBomb", "💣")

ContextActionService:BindAction("ThrowBomb", function(_, state)
	if state == Enum.UserInputState.Begin then
		throwRemote:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle("ThrowBomb", "🧤")

----------------------------------------------------------------------
-- HUD
----------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "BombHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -14)
bar.Size = UDim2.fromOffset(520, 52)
bar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
bar.BackgroundTransparency = 0.25
bar.Parent = gui
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 12)
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = bar

local function statLabel(order)
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.Size = UDim2.fromOffset(96, 36)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 18
	l.Parent = bar
	return l
end
local lBombs, lRange, lSpeed, lPierce, lThrow = statLabel(1), statLabel(2), statLabel(3), statLabel(4), statLabel(5)

local function refresh()
	lBombs.Text = "💣 " .. (player:GetAttribute("Bombs") or 1)
	lRange.Text = "🔥 " .. (player:GetAttribute("Range") or 2)
	lSpeed.Text = "👟 " .. (player:GetAttribute("Speed") or 16)
	lPierce.Text = player:GetAttribute("Pierce") and "⚡ aan" or "⚡ uit"
	lThrow.Text = player:GetAttribute("Throw") and "🧤 aan" or "🧤 uit"
	lPierce.TextTransparency = player:GetAttribute("Pierce") and 0 or 0.55
	lThrow.TextTransparency = player:GetAttribute("Throw") and 0 or 0.55
end
for _, name in ipairs({ "Bombs", "Range", "Speed", "Pierce", "Throw" }) do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()

local help = Instance.new("TextLabel")
help.AnchorPoint = Vector2.new(0, 1)
help.Position = UDim2.new(0, 14, 1, -14)
help.Size = UDim2.fromOffset(260, 44)
help.BackgroundTransparency = 1
help.TextXAlignment = Enum.TextXAlignment.Left
help.TextColor3 = Color3.new(1, 1, 1)
help.TextStrokeTransparency = 0.5
help.Font = Enum.Font.Gotham
help.TextSize = 14
help.Text = "Spatie: bom leggen\nE: bom oppakken / gooien (met 🧤)"
help.Parent = gui

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 24)
banner.Size = UDim2.fromOffset(640, 56)
banner.BackgroundTransparency = 1
banner.TextColor3 = Color3.new(1, 1, 1)
banner.TextStrokeTransparency = 0
banner.Font = Enum.Font.GothamBlack
banner.TextScaled = true
banner.TextTransparency = 1
banner.TextStrokeTransparency = 1
banner.Parent = gui

local shown = 0
announceRemote.OnClientEvent:Connect(function(text, seconds, small)
	shown += 1
	local mine = shown
	banner.Text = text
	banner.Size = small and UDim2.fromOffset(520, 34) or UDim2.fromOffset(640, 56)
	banner.Position = small and UDim2.new(0.5, 0, 1, -112) or UDim2.new(0.5, 0, 0, 24)
	banner.AnchorPoint = small and Vector2.new(0.5, 1) or Vector2.new(0.5, 0)
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0
	task.delay(seconds or 3, function()
		if mine == shown then
			TweenService:Create(banner, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end)
