-- Roblomberman: client (top-down camera, HUD, buttons, corner assist, belts).
-- All text goes through Lang, in the language the player set in Roblox.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local LocalizationService = game:GetService("LocalizationService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("BombConfig"))
local Lang = require(ReplicatedStorage:WaitForChild("Lang"))
local remotes = ReplicatedStorage:WaitForChild("BombRemotes")
local placeRemote = remotes:WaitForChild("PlaceBomb")
local throwRemote = remotes:WaitForChild("ThrowBomb")
local announceRemote = remotes:WaitForChild("Announce")
local resultRemote = remotes:WaitForChild("RoundResult")

local player = Players.LocalPlayer

local okLocale, localeId = pcall(function()
	return LocalizationService.RobloxLocaleId
end)
local lang = Lang.pick(okLocale and localeId or player.LocaleId)
local function tr(msg, args)
	return Lang.t(lang, msg, args)
end
local camera = workspace.CurrentCamera
camera.FieldOfView = 40

local T = Config.TILE

-- The arena changes size every round; the server puts the size on the remotes folder
local arenaW, arenaH = 13, 13
local originX, originZ = 0, 0
local belts = {} -- key -> { dx, dz }
local ice = {} -- key -> true

local function readArena()
	arenaW = remotes:GetAttribute("ArenaW") or arenaW
	arenaH = remotes:GetAttribute("ArenaH") or arenaH
	originX = -(arenaW - 1) * T / 2
	originZ = -(arenaH - 1) * T / 2
	table.clear(belts)
	for entry in string.gmatch(remotes:GetAttribute("Belts") or "", "[^;]+") do
		local x, z, dx, dz = string.match(entry, "(-?%d+),(-?%d+),(-?%d+),(-?%d+)")
		if x then
			belts[tonumber(x) * 100 + tonumber(z)] = { dx = tonumber(dx), dz = tonumber(dz) }
		end
	end
	table.clear(ice)
	for entry in string.gmatch(remotes:GetAttribute("Ice") or "", "[^;]+") do
		local x, z = string.match(entry, "(-?%d+),(-?%d+)")
		if x then
			ice[tonumber(x) * 100 + tonumber(z)] = true
		end
	end
end
for _, name in ipairs({ "ArenaW", "ArenaH", "Belts", "Ice" }) do
	remotes:GetAttributeChangedSignal(name):Connect(readArena)
end
readArena()

local function cellOf(p)
	return math.floor((p.X - originX) / T + 0.5) + 1, math.floor((p.Z - originZ) / T + 0.5) + 1
end

-- Hear sounds from the middle of the arena, not from the high camera
SoundService:SetListener(Enum.ListenerType.CFrame, CFrame.new(0, 20, 0))

----------------------------------------------------------------------
-- Camera: from above. While alive it follows your player; when you are out
-- (or spectating) it shows the whole arena.
----------------------------------------------------------------------
local camFocus = Vector3.zero
local camDist = 100

local function distFor(cellsW, cellsH, margin)
	local vp = camera.ViewportSize
	local aspect = math.max(vp.X, 1) / math.max(vp.Y, 1)
	local t = math.tan(math.rad(camera.FieldOfView / 2))
	local halfH = (cellsH * T) / 2 + margin
	local halfW = (cellsW * T) / 2 + margin
	return math.max(halfH / t, halfW / (t * aspect)) * 1.05, halfW, halfH
end

RunService:BindToRenderStep("BombCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	camera.CameraType = Enum.CameraType.Scriptable
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local following = Config.CAMERA_FOLLOW and player:GetAttribute("Alive") and root and hum and hum.Health > 0

	local targetFocus, targetDist
	if following then
		local viewW = math.min(Config.CAMERA_VIEW_W, arenaW)
		local viewH = math.min(Config.CAMERA_VIEW_H, arenaH)
		local dist, halfW, halfH = distFor(viewW, viewH, 2)
		-- don't move past the edge of the arena
		local maxX = math.max(0, (arenaW * T) / 2 + T - halfW)
		local maxZ = math.max(0, (arenaH * T) / 2 + T - halfH)
		local p = root.Position
		targetFocus = Vector3.new(math.clamp(p.X, -maxX, maxX), 0, math.clamp(p.Z, -maxZ, maxZ))
		targetDist = dist
	else
		targetFocus = Vector3.zero
		targetDist = distFor(arenaW, arenaH, 6)
	end

	local a = 1 - math.exp(-Config.CAMERA_SMOOTH * dt)
	camFocus = camFocus:Lerp(targetFocus, a)
	camDist += (targetDist - camDist) * a
	-- slight tilt so "up" on screen stays north (-Z)
	camera.CFrame = CFrame.lookAt(camFocus + Vector3.new(0, camDist, camDist * 0.22), camFocus)
end)

----------------------------------------------------------------------
-- Conveyor belts: push your own character along
----------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	if next(belts) == nil then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return
	end
	local x, z = cellOf(root.Position)
	local b = belts[x * 100 + z]
	if b then
		root.CFrame += Vector3.new(b.dx, 0, b.dz) * Config.BELT_SPEED * dt
	end
end)

----------------------------------------------------------------------
-- Ice: you keep your momentum. We remember a "slide velocity" that only
-- slowly follows how you actually move, and push you by the difference.
----------------------------------------------------------------------
local slideVel = Vector3.zero
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

RunService.Heartbeat:Connect(function(dt)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		slideVel = Vector3.zero
		return
	end
	local x, z = cellOf(root.Position)
	if not ice[x * 100 + z] then
		slideVel = Vector3.zero
		return
	end
	local v = root.AssemblyLinearVelocity
	local hv = Vector3.new(v.X, 0, v.Z)
	slideVel += (hv - slideVel) * math.min(1, Config.ICE_GRIP * dt)
	local drift = (slideVel - hv) * dt
	if drift.Magnitude > 0.001 then
		rayParams.FilterDescendantsInstances = { char }
		local hit = workspace:Raycast(root.Position, drift.Unit * (drift.Magnitude + 1.2), rayParams)
		if hit and hit.Instance.CanCollide then
			slideVel = hv -- bumped into something: stop sliding
		else
			root.CFrame += drift
		end
	end
end)

----------------------------------------------------------------------
-- Corner assist: slide into the corridor when you are just next to an opening.
-- Fixed walls sit on cells with even x AND even z, so walking horizontally is only
-- possible in rows with an odd z, and vertically in columns with an odd x.
----------------------------------------------------------------------
local function laneOffset(p, origin)
	local idx = (p - origin) / T + 1 -- cell index (fractional)
	local lane = math.floor((idx - 1) / 2 + 0.5) * 2 + 1 -- nearest odd cell
	return origin + (lane - 1) * T - p
end

RunService.Heartbeat:Connect(function(dt)
	if not Config.CORNER_ASSIST then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return
	end
	local md = hum.MoveDirection
	if md.Magnitude < 0.5 then
		return
	end
	local maxStep = hum.WalkSpeed * dt
	local tol = T * Config.CORNER_TOLERANCE
	local pos = root.Position
	if math.abs(md.X) > math.abs(md.Z) * 1.5 then
		local off = laneOffset(pos.Z, originZ)
		if math.abs(off) > 0.05 and math.abs(off) < tol then
			root.CFrame += Vector3.new(0, 0, math.clamp(off, -maxStep, maxStep))
		end
	elseif math.abs(md.Z) > math.abs(md.X) * 1.5 then
		local off = laneOffset(pos.X, originX)
		if math.abs(off) > 0.05 and math.abs(off) < tol then
			root.CFrame += Vector3.new(math.clamp(off, -maxStep, maxStep), 0, 0)
		end
	end
end)

----------------------------------------------------------------------
-- Goodies: spin and bob the 3D goodie models (smooth, because it runs locally)
----------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, model in ipairs(CollectionService:GetTagged("Goodie3D")) do
		local base = model:GetAttribute("Base")
		if base and model.Parent then
			local phase = (base.X + base.Z) * 0.37
			local bob = math.sin(t * 3 + phase) * 0.35
			model:PivotTo(CFrame.new(base + Vector3.new(0, bob, 0)) * CFrame.Angles(math.rad(12), t * 1.8 + phase, 0))
		end
	end
end)

----------------------------------------------------------------------
-- Buttons
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

-- Scale everything with the screen size (phone = smaller)
local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function rescale()
	local vp = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(vp.X / 900, vp.Y / 600), 0.5, 1)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 18
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- Bottom bar with your goodies
local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -14)
bar.Size = UDim2.fromOffset(820, 52)
bar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
bar.BackgroundTransparency = 0.25
bar.Parent = gui
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Transparency = 1
stroke.Parent = bar
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = bar

local function statLabel(order)
	return label(bar, { LayoutOrder = order, Size = UDim2.fromOffset(96, 36) })
end
local lColor = statLabel(0)
local lBombs, lRange, lSpeed = statLabel(1), statLabel(2), statLabel(3)
local lPierce, lThrow, lKick, lPunch = statLabel(4), statLabel(5), statLabel(6), statLabel(7)
lColor.Size = UDim2.fromOffset(70, 36)

local curseLabel = label(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -72),
	Size = UDim2.fromOffset(520, 28),
	TextColor3 = Color3.fromRGB(220, 160, 255),
	TextStrokeTransparency = 0.3,
	Visible = false,
})

local function toggle(l, on, emoji)
	l.Text = emoji .. " " .. tr(on and "on" or "off")
	l.TextTransparency = on and 0 or 0.55
end

local function refresh()
	lBombs.Text = "💣 " .. (player:GetAttribute("Bombs") or Config.START_BOMBS)
	lRange.Text = "🔥 " .. (player:GetAttribute("Range") or Config.START_RANGE)
	lSpeed.Text = "👟 " .. (player:GetAttribute("Speed") or Config.START_SPEED)
	toggle(lPierce, player:GetAttribute("Pierce"), "⚡")
	toggle(lThrow, player:GetAttribute("Throw"), "🧤")
	toggle(lKick, player:GetAttribute("Kick"), "🦶")
	toggle(lPunch, player:GetAttribute("Punch"), "🥊")
	local color = player:GetAttribute("Color")
	local colorKey = player:GetAttribute("ColorName")
	lColor.Text = colorKey and tr(colorKey) or ""
	lColor.TextColor3 = color or Color3.new(1, 1, 1)
	stroke.Color = color or Color3.new(1, 1, 1)
	stroke.Transparency = color and 0 or 1
	local curse = player:GetAttribute("Curse")
	curseLabel.Text = curse and tr(curse) or ""
	curseLabel.Visible = curse ~= nil
end
for _, name in ipairs({ "Bombs", "Range", "Speed", "Pierce", "Throw", "Kick", "Punch", "Color", "ColorName", "Curse" }) do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()

-- Help text: different on phone/tablet than with a keyboard
local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
label(gui, {
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 14, 0, 60),
	Size = UDim2.fromOffset(300, 44),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextStrokeTransparency = 0.5,
	Font = Enum.Font.Gotham,
	TextSize = 14,
	Text = tr(touchOnly and "help_touch" or "help_keys"),
})

-- Timer top right
local timerLabel = label(gui, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 56),
	Size = UDim2.fromOffset(260, 40),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextStrokeTransparency = 0.3,
	Font = Enum.Font.GothamBlack,
	TextSize = 28,
	Text = "",
})

-- Spectator message
local spectateLabel = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 96),
	Size = UDim2.fromOffset(620, 30),
	TextStrokeTransparency = 0.3,
	TextSize = 20,
	Visible = false,
})

RunService.RenderStepped:Connect(function()
	local state = remotes:GetAttribute("State")
	if state == "playing" then
		if remotes:GetAttribute("SuddenDeath") then
			timerLabel.Text = tr("sudden_hud")
			timerLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
		else
			local left = math.max(0, (remotes:GetAttribute("RoundEndsAt") or 0) - workspace:GetServerTimeNow())
			timerLabel.Text = string.format("⏱️ %d:%02d", math.floor(left / 60), math.floor(left % 60))
			timerLabel.TextColor3 = left <= 15 and Color3.fromRGB(255, 200, 80) or Color3.new(1, 1, 1)
		end
	else
		timerLabel.Text = ""
	end

	if state == "playing" and not player:GetAttribute("Alive") then
		local n = remotes:GetAttribute("AliveCount") or 0
		if player:GetAttribute("InRound") then
			spectateLabel.Text = tr("spectate_out", { n = n })
		else
			spectateLabel.Text = tr("spectate_wait")
		end
		spectateLabel.Visible = true
		bar.Visible = false
	else
		spectateLabel.Visible = false
		bar.Visible = true
	end
end)

-- Big / small announcements
local banner = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 24),
	Size = UDim2.fromOffset(640, 56),
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextTransparency = 1,
	TextStrokeTransparency = 1,
})

local shown = 0
announceRemote.OnClientEvent:Connect(function(message, seconds, small)
	shown += 1
	local mine = shown
	banner.Text = tr(message)
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

----------------------------------------------------------------------
-- Scoreboard after every round
----------------------------------------------------------------------
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(440, 120)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
local panelPad = Instance.new("UIPadding")
panelPad.PaddingTop = UDim.new(0, 14)
panelPad.PaddingBottom = UDim.new(0, 14)
panelPad.PaddingLeft = UDim.new(0, 18)
panelPad.PaddingRight = UDim.new(0, 18)
panelPad.Parent = panel
local panelList = Instance.new("UIListLayout")
panelList.Padding = UDim.new(0, 6)
panelList.SortOrder = Enum.SortOrder.LayoutOrder
panelList.Parent = panel

local resultShown = 0
resultRemote.OnClientEvent:Connect(function(title, rows, seconds, header)
	resultShown += 1
	local mine = resultShown
	for _, c in ipairs(panel:GetChildren()) do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	label(panel, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 40),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		Text = tr(title),
	})
	label(panel, {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextTransparency = 0.3,
		Text = tr(header or "wins"),
	})
	for i, row in ipairs(rows) do
		local l = label(panel, {
			LayoutOrder = 1 + i,
			Size = UDim2.new(1, 0, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 20,
			Text = string.format("%s%d.  %s  –  %d", row.winner and "🏆 " or "", i, row.name, row.wins),
		})
		if row.color then
			l.TextColor3 = row.color
		end
	end
	panel.Size = UDim2.fromOffset(440, 28 + 46 + 26 + #rows * 32)
	panel.Visible = true
	task.delay(math.max(2, (seconds or 6) - 0.5), function()
		if mine == resultShown then
			panel.Visible = false
		end
	end)
end)

remotes:GetAttributeChangedSignal("State"):Connect(function()
	if remotes:GetAttribute("State") == "lobby" then
		panel.Visible = false
	end
end)
