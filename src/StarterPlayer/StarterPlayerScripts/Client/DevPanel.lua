--[[
	DevPanel — หน้าต่างเครื่องมือนักพัฒนา  [F8] หรือปุ่ม DEV มุมขวาบน (เฉพาะคนที่ server บอกว่า IsDev)
	แท็บ: ผู้เล่น · ไอเทม · บอส · เวลา · แคมป์ · วาร์ป · โปรไฟล์
	บินได้/ทะลุกำแพง ทำฝั่ง client (ตัวละครเป็นของเครื่องเราอยู่แล้ว) — คำสั่งอื่นส่งไป DevService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Animals = require(Shared.Animals)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local DevPanel = {}

local player = Players.LocalPlayer
local C = Color3.fromRGB
local ui = {}
local fly = { On = false }
local noclip = false

---------------------------------------------------------------- ตัวช่วย UI
local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = o
end

local function stroke(o, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color or C(0, 0, 0)
	s.Thickness = t or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
	return s
end

local function label(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = C(235, 235, 240)
	t.TextSize = 14
	t.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in pairs(props) do
		t[k] = v
	end
	t.Parent = parent
	return t
end

local function btn(parent, text, color, onClick, order)
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextWrapped = true
	b.TextColor3 = C(255, 255, 255)
	b.BackgroundColor3 = color or C(52, 56, 70)
	b.AutoButtonColor = true
	b.LayoutOrder = order or 0
	b.Parent = parent
	corner(b, 6)
	stroke(b, C(0, 0, 0), 1)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

local function box(parent, placeholder, text)
	local t = Instance.new("TextBox")
	t.PlaceholderText = placeholder
	t.Text = text or ""
	t.ClearTextOnFocus = false
	t.Font = Enum.Font.GothamBold
	t.TextSize = 13
	t.TextColor3 = C(255, 255, 255)
	t.PlaceholderColor3 = C(150, 150, 160)
	t.BackgroundColor3 = C(28, 30, 38)
	t.Parent = parent
	corner(t, 6)
	stroke(t, C(90, 95, 110), 1)
	return t
end

local function status(text, bad)
	if ui.Status then
		ui.Status.Text = text or ""
		ui.Status.TextColor3 = bad and C(255, 120, 110) or C(150, 240, 150)
	end
end

local function run(action, a, b)
	status("…")
	task.spawn(function()
		local ok, res = pcall(function()
			return Remotes.Get("DevCmd"):InvokeServer(action, a, b)
		end)
		status(ok and tostring(res) or ("❌ " .. tostring(res)), not ok or (type(res) == "string" and (res:find("⛔") or res:find("❌"))))
	end)
end

---------------------------------------------------------------- บิน / ทะลุกำแพง (ฝั่ง client)
local function charParts()
	local c = player.Character
	return c, c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

local function setFly(on)
	fly.On = on
	local _, root, hum = charParts()
	if fly.BV then
		fly.BV:Destroy()
		fly.BV = nil
	end
	if fly.BG then
		fly.BG:Destroy()
		fly.BG = nil
	end
	if hum then
		hum.PlatformStand = on
	end
	if on and root then
		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(1e7, 1e7, 1e7)
		bv.Velocity = Vector3.zero
		bv.Parent = root
		local bg = Instance.new("BodyGyro")
		bg.MaxTorque = Vector3.new(1e7, 1e7, 1e7)
		bg.P = 2e4
		bg.CFrame = root.CFrame
		bg.Parent = root
		fly.BV, fly.BG = bv, bg
	end
	status(on and "🕊 Fly: WASD + Space up / Ctrl down · Shift fast" or "Fly: OFF")
end

RunService.RenderStepped:Connect(function()
	if fly.On then
		local _, root = charParts()
		if not (root and fly.BV) then
			fly.On = false
			return
		end
		local cam = Workspace.CurrentCamera.CFrame
		local dir = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			dir += cam.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			dir -= cam.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			dir += cam.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			dir -= cam.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			dir += Vector3.yAxis
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			dir -= Vector3.yAxis
		end
		local speed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 260 or 90
		fly.BV.Velocity = dir.Magnitude > 0 and dir.Unit * speed or Vector3.zero
		fly.BG.CFrame = CFrame.lookAt(Vector3.zero, cam.LookVector * Vector3.new(1, 0, 1) + Vector3.new(0, 0, 0.0001))
	end
end)

RunService.Stepped:Connect(function()
	if noclip then
		local c = player.Character
		if c then
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide = false
				end
			end
		end
	end
end)

player.CharacterAdded:Connect(function()
	fly.On = false
end)

---------------------------------------------------------------- เนื้อหาแต่ละแท็บ
local ELEMENT_TH = { Earth = "Earth", Water = "Water", Air = "Frost", Fire = "Fire" }
local CAT = { { "Resource", "Materials", 100 }, { "Food", "Food", 20 }, { "Essence", "Element Essence", 20 }, { "Medical", "Medicine", 10 },
	{ "Relic", "Rare Items", 3 }, { "Tool", "Tools", 1 }, { "Structure", "Buildings", 10 } }

local TABS = {
	{ "Player", function(page)
		btn(page, "🛡 God mode (on/off)", C(60, 110, 70), function() run("god") end)
		btn(page, "❤ Refill HP + hunger", C(150, 60, 70), function() run("heal") end)
		btn(page, "🕊 Fly (on/off)", C(60, 90, 150), function() setFly(not fly.On) end)
		btn(page, "👻 Noclip", C(90, 70, 140), function()
			noclip = not noclip
			if not noclip then
				local c = player.Character
				for _, d in ipairs(c and c:GetDescendants() or {}) do
					if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
						d.CanCollide = true
					end
				end
			end
			status(noclip and "👻 Noclip: ON" or "Noclip: OFF")
		end)
		btn(page, "🏃 Speed x1", nil, function() run("speed", 1) end)
		btn(page, "🏃 Speed x2", nil, function() run("speed", 2) end)
		btn(page, "🏃 Speed x4", nil, function() run("speed", 4) end)
		btn(page, "🔄 Respawn", nil, function() run("respawn") end)
		btn(page, "🧭 Enter map (from lobby)", C(70, 130, 70), function() run("depart") end)
		btn(page, "🏕 Back to lobby", nil, function() run("lobby") end)
		btn(page, "🖥 Hide/show HUD", nil, function()
			local hud = player.PlayerGui:FindFirstChild("HUD")
			if hud then
				hud.Enabled = not hud.Enabled
			end
		end)
		btn(page, "ℹ Game status", nil, function() run("info") end)
	end },
	{ "Items", function(page)
		for _, c in ipairs(CAT) do
			btn(page, string.format("🎁 All %s x%d", c[2], c[3]), C(70, 100, 60), function() run("giveCategory", c[1], c[3]) end)
		end
		btn(page, "🗑 Clear bag", C(140, 60, 60), function() run("clearInv") end)
		local ids = {}
		for id in pairs(Items.Data) do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			local ca, cb = Items.Data[a].Category, Items.Data[b].Category
			if ca ~= cb then
				return ca < cb
			end
			return a < b
		end)
		for _, id in ipairs(ids) do
			local d = Items.Data[id]
			local n = d.Category == "Tool" and 1 or (d.Category == "Resource" and 50 or 5)
			btn(page, Items.DisplayName(id) .. " x" .. n, nil, function() run("give", id, n) end)
		end
	end },
	{ "Boss", function(page)
		-- เฉพาะตัวที่มีโมเดลแล้ว (ReplicatedStorage.Assets.Animals)
		local folder = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Animals")
		for _, m in ipairs(folder and folder:GetChildren() or {}) do
			local info = Animals.Data[m.Name]
			if info then
				btn(page, "👑 " .. info.Thai, C(150, 50, 90), function() run("spawnBoss", m.Name) end)
			end
		end
		btn(page, "🧹 Remove all bosses/animals", C(100, 60, 60), function() run("clearAnimals") end)
	end },
	{ "Time", function(page)
		btn(page, "⏭ Skip phase", C(70, 100, 150), function() run("skip") end)
		btn(page, "🌙 Go to night now", C(50, 50, 120), function() run("nightNow") end)
		btn(page, "⏸ Pause/resume time", nil, function() run("pause") end)
		btn(page, "🔴 Blood Moon", C(130, 40, 40), function() run("bloodMoon") end)
		for _, n in ipairs({ 1, 5, 10, 24, 25, 49, 50, 74, 75, 98, 99 }) do
			btn(page, "Set night " .. n .. (({ [25] = " 👑Earth", [50] = " 👑Water", [75] = " 👑Frost", [99] = " 👑Fire" })[n] or ""), nil, function() run("setNight", n) end)
		end
	end },
	{ "Camp", function(page)
		btn(page, "🔥 Fuel filled", C(150, 90, 40), function() run("fuel") end)
		btn(page, "💨 Campfire put out", C(80, 80, 90), function() run("extinguish") end)
		btn(page, "🔥 Campfire +1 level", C(150, 90, 40), function() run("fireLevel", 1) end)
		btn(page, "🔥 Campfire -1 level", nil, function() run("fireLevel", -1) end)
		btn(page, "🌫 Pass through fog wall on/off", nil, function() run("fogPass") end)
		btn(page, "🔨 Crafting bench +1", C(110, 80, 50), function() run("benchLevel", 1) end)
		btn(page, "🔨 Crafting bench -1", nil, function() run("benchLevel", -1) end)
	end },
	{ "Teleport", function(page)
		btn(page, "🏕 Camp", C(150, 90, 40), function() run("tp", "camp") end)
		btn(page, "➡ Forward 120", nil, function() run("tp", "front") end)
		for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
			btn(page, "🗺 Biome " .. ELEMENT_TH[el], nil, function() run("tp", "Site_" .. el) end)
			btn(page, "⛩ Shrine " .. ELEMENT_TH[el], nil, function() run("tp", "Shrine_" .. el) end)
			btn(page, "👑 Boss Lair " .. ELEMENT_TH[el], C(130, 50, 80), function() run("tp", "Lair_" .. el) end)
			btn(page, "🏚 Ruins " .. ELEMENT_TH[el], nil, function() run("tp", "Ruins_" .. el) end)
			btn(page, "🏛 Sanctum " .. ELEMENT_TH[el], C(110, 90, 50), function() run("tp", "Sanctum_" .. el) end)
		end
	end },
	{ "Profile", function(page)
		btn(page, "♦️ +1000 Ruby", C(50, 110, 160), function() run("diamonds", 1000) end)
		-- ส่ง Ruby ให้ tester: ชื่อผู้ใช้ / UserId · อยู่เซิร์ฟอื่นหรือออฟไลน์ก็ได้ (ได้ตอนเข้าเกม)
		local who = box(page, "Username or UserId")
		local amount = box(page, "Ruby amount", "1000")
		btn(page, "🎁 Send Ruby to this player", C(150, 100, 40), function() run("giftDiamonds", who.Text, amount.Text) end)
		btn(page, "🎁 Send to everyone in the server", C(150, 100, 40), function() run("giftDiamonds", "*", amount.Text) end)
		btn(page, "🔓 Unlocked all classes", C(70, 120, 70), function() run("unlockAll") end)
		btn(page, "⭐ Current class to level 3", C(150, 120, 40), function() run("maxClass") end)
		btn(page, "🔄 Reset daily reward + stock", nil, function() run("resetDaily") end)
		btn(page, "♻ Reset profile", C(140, 60, 60), function() run("resetProfile") end)
	end },
}

---------------------------------------------------------------- สร้างหน้าต่าง
function DevPanel.Build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DevPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	ui.Gui = gui
	local toggle = btn(gui, "DEV", C(200, 60, 60), function()
		ui.Panel.Visible = not ui.Panel.Visible
	end)
	toggle.Size = UDim2.fromOffset(52, 30)
	toggle.Position = UDim2.new(0, 14, 1, -46)
	toggle.TextSize = 15

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(560, 520)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 18)
	-- จอเล็ก (มือถือ): ย่อทั้งหน้าต่างให้พอดีจอ ไม่ล้นใต้แถบบนของ Roblox
	local fit = Instance.new("UIScale")
	fit.Parent = panel
	local function refit()
		local vp = workspace.CurrentCamera.ViewportSize
		fit.Scale = math.clamp(math.min((vp.Y - 90) / 520, (vp.X - 24) / 560), 0.45, 1)
	end
	refit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
	panel.BackgroundColor3 = C(20, 22, 28)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Active = true
	panel.Parent = gui
	corner(panel, 12)
	stroke(panel, C(200, 60, 60), 2)
	ui.Panel = panel
	local title = label(panel, { Text = "🛠 DEV TOOLS   [F8]  · Drag here to move", Size = UDim2.new(1, -60, 0, 32), Position = UDim2.fromOffset(14, 6), TextSize = 18, TextColor3 = C(255, 140, 120) })
	-- ลากหน้าต่าง
	local dragging, dragStart, startPos
	title.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, dragStart, startPos = true, i.Position, panel.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - dragStart
			panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	title.Active = true
	local close = btn(panel, "X", C(150, 50, 50), function()
		panel.Visible = false
	end)
	close.Size = UDim2.fromOffset(30, 26)
	close.Position = UDim2.new(1, -40, 0, 8)

	-- แท็บ
	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Size = UDim2.new(1, -20, 0, 30)
	tabBar.Position = UDim2.fromOffset(10, 42)
	tabBar.Parent = panel
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 4)
	tl.Parent = tabBar
	local pages, tabButtons = {}, {}
	local function show(i)
		for k, pg in ipairs(pages) do
			pg.Visible = k == i
			tabButtons[k].BackgroundColor3 = k == i and C(200, 70, 60) or C(52, 56, 70)
		end
	end
	for i, t in ipairs(TABS) do
		local tb = btn(tabBar, t[1], nil, function()
			show(i)
		end, i)
		tb.Size = UDim2.fromOffset(74, 28)
		tabButtons[i] = tb
		local page = Instance.new("ScrollingFrame")
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.Size = UDim2.new(1, -20, 1, -118)
		page.Position = UDim2.fromOffset(10, 78)
		page.ScrollBarThickness = 6
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.CanvasSize = UDim2.new()
		page.Visible = false
		page.Parent = panel
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(170, 36)
		grid.CellPadding = UDim2.fromOffset(6, 6)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = page
		t[2](page)
		pages[i] = page
	end
	show(1)
	ui.Status = label(panel, { Text = "Ready", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 1, -36), TextColor3 = C(150, 240, 150), TextWrapped = true, TextSize = 13 })
end

function DevPanel.Init()
	local function setup()
		if ui.Gui or not player:GetAttribute("IsDev") then
			return
		end
		DevPanel.Build()
	end
	player:GetAttributeChangedSignal("IsDev"):Connect(setup)
	setup()
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.F8 and ui.Panel then
			ui.Panel.Visible = not ui.Panel.Visible
		end
		local _ = processed
	end)
end

return DevPanel
