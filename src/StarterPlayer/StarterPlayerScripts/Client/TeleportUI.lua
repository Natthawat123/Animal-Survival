--[[
	TeleportUI — หน้าต่างเลือกหินวาร์ปปลายทาง (เปิดจากปุ่ม E บนหินวาร์ป · TeleporterService ส่ง "Menu", fromId)
	  รายการหินทุกอันในเซิร์ฟ (ReplicatedStorage.TeleporterPins) เรียงตามเลข · บอกไบโอม + ระยะ · กดปุ่ม = วาร์ป
	  แผนที่ใหญ่ (M): หมุด 🌀 + เลขหิน ทุกอัน
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Biomes = require(Shared.Biomes)
local UIKit = require(script.Parent.UIKit)

local TeleportUI = {}
local player = Players.LocalPlayer
local C = UIKit.Colors
local TP_COLOR = Color3.fromRGB(110, 220, 255)

local function pins()
	local f = ReplicatedStorage:FindFirstChild("TeleporterPins")
	local list = {}
	for _, p in ipairs(f and f:GetChildren() or {}) do
		if p:IsA("Vector3Value") then
			table.insert(list, { Id = tonumber(p.Name), Num = p:GetAttribute("Num") or 0, Biome = p:GetAttribute("Biome"), Position = p.Value })
		end
	end
	table.sort(list, function(a, b)
		return a.Num < b.Num
	end)
	return list
end
TeleportUI.Pins = pins

local function biomeName(id)
	local b = id and Biomes.Data[id]
	return b and b.Name or "Wilds"
end

function TeleportUI.Init(state, hud, mapUI)
	local remote = Remotes.Get("Teleporter")
	local gui = UIKit.Screen("TeleportUI", 26)
	local panel = UIKit.Frame(gui, { Size = UDim2.fromOffset(440, 470), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0.05, Visible = false })
	UIKit.AutoScale(panel)
	UIKit.Corner(panel, 14)
	UIKit.Stroke(panel, TP_COLOR, 3, 0)
	UIKit.Text(panel, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 8), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title, TextSize = 28, TextColor3 = TP_COLOR, Text = "🌀 Waystones" })
	local sub = UIKit.Text(panel, { Size = UDim2.new(1, -30, 0, 22), Position = UDim2.fromOffset(15, 46), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 15, TextColor3 = C.TextDim, Text = "Pick where to warp" })
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -30, 1, -90)
	list.Position = UDim2.fromOffset(15, 76)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 8)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = list

	local fromId
	local function close()
		panel.Visible = false
		fromId = nil
	end
	UIKit.CloseButton(panel, close)
	UIKit.RegisterWindow(panel, close)

	local function fill()
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local char = player.Character
		local me = char and char:GetPivot().Position
		local touch = UIKit.IsTouch
		local here
		for _, p in ipairs(pins()) do
			if p.Id == fromId then
				here = p
			end
		end
		sub.Text = here and string.format("You are at Waystone %d", here.Num) or "Pick where to warp"
		for i, p in ipairs(pins()) do
			if p.Id ~= fromId then
				local row = UIKit.Frame(list, { Size = UDim2.new(1, -8, 0, touch and 70 or 58), BackgroundColor3 = Color3.fromRGB(26, 34, 46), LayoutOrder = i })
				UIKit.Corner(row, 10)
				UIKit.Stroke(row, TP_COLOR, 1.5, 0.5)
				UIKit.Text(row, { Size = UDim2.new(1, -150, 0, 26), Position = UDim2.fromOffset(14, 6), TextSize = touch and 20 or 18, Font = UIKit.Fonts.Black, TextColor3 = C.Text, Text = string.format("🌀 Waystone %d", p.Num) })
				local dist = me and math.floor(((p.Position - me) * Vector3.new(1, 0, 1)).Magnitude * 0.28) or 0
				UIKit.Text(row, { Size = UDim2.new(1, -150, 0, 20), Position = UDim2.fromOffset(14, touch and 36 or 32), TextSize = touch and 16 or 14, TextColor3 = C.TextDim, Text = biomeName(p.Biome) .. " · " .. string.format("%dm", dist) })
				local b = UIKit.ColorButton(row, Color3.fromRGB(40, 150, 210), {
					Size = UDim2.fromOffset(touch and 128 or 116, touch and 52 or 42), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
					Text = "Warp", TextSize = touch and 22 or 19,
				}, function()
					if fromId then
						remote:FireServer("Go", fromId, p.Id)
					end
					close()
				end)
			end
		end
	end

	remote.OnClientEvent:Connect(function(kind, id)
		if kind == "Menu" then
			fromId = id
			fill()
			panel.Visible = true
		end
	end)
	-- ตายตอนเปิดหน้าต่าง/ออกจากรอบ = ปิด
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		if not player:GetAttribute("InRun") then
			close()
		end
	end)

	-- หมุดหินวาร์ปบนแผนที่ใหญ่
	if mapUI and mapUI.ExtraMarkers then
		table.insert(mapUI.ExtraMarkers, function(marker, place)
			local seenIds = {}
			for _, p in ipairs(pins()) do
				seenIds["tp_" .. p.Id] = true
				local m = marker("tp_" .. p.Id, "🌀", TP_COLOR, 18)
				m:SetAttribute("NoTranslate", true)
				m.Visible = true
				place(m, p.Position)
				local num = m:FindFirstChild("Num")
				if not num then
					num = UIKit.Text(m, { Name = "Num", Size = UDim2.fromOffset(20, 14), AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(1, -4, 1, -8), TextSize = 12, Font = UIKit.Fonts.Black, TextColor3 = TP_COLOR, ZIndex = m.ZIndex + 1 })
				end
				num.Text = tostring(p.Num)
			end
			-- หินที่ถูกรื้อ: ซ่อนหมุด
			for _, gui2 in ipairs(mapUI.MapFrame and mapUI.MapFrame:GetChildren() or {}) do
				local key = gui2:GetAttribute("Key")
				if key and key:sub(1, 3) == "tp_" and not seenIds[key] then
					gui2.Visible = false
				end
			end
		end)
	end
end

return TeleportUI
