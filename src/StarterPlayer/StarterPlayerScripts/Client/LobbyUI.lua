--[[
	LobbyUI — ปุ่มด้านซ้ายในล็อบบี้แบบ 99 Nights: คลาส / ป้าย / ร้านค้า + ตัวนับเพชรมุมซ้ายล่าง
	ป้าย = ความสำเร็จที่คำนวณจากสถิติจริงในเซฟ (คืนที่รอด, สัตว์ที่ล่า, คลาสที่มี)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))

local LobbyUI = {}

local player = Players.LocalPlayer
local C = Color3.fromRGB
local profile
local ui = {}

local function stroke(obj, thickness, color, mode)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or C(0, 0, 0)
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual
	s.Parent = obj
	return s
end

local function label(parent, props, maxSize)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = C(255, 255, 255)
	t.TextScaled = true
	for k, v in pairs(props) do
		t[k] = v
	end
	t.Parent = parent
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = maxSize or 36
	lim.Parent = t
	return t
end

-- ความสำเร็จ: { ชื่อ, ค่าปัจจุบัน(profile), เป้า }
local BADGES = {
	{ "🌙 รอดถึงคืนที่ 5", "BestNight", 5 }, { "🌙 รอดถึงคืนที่ 10", "BestNight", 10 }, { "🌕 รอดถึงคืนที่ 25", "BestNight", 25 },
	{ "🌕 รอดถึงคืนที่ 50", "BestNight", 50 }, { "👑 ครบ 99 คืน", "BestNight", 99 },
	{ "🐾 ล่าสัตว์ 50 ตัว", "Kills", 50 }, { "🐾 ล่าสัตว์ 250 ตัว", "Kills", 250 }, { "🐺 ล่าสัตว์ 1000 ตัว", "Kills", 1000 },
	{ "🔥 รอดรวม 20 คืน", "NightsTotal", 20 }, { "🔥 รอดรวม 100 คืน", "NightsTotal", 100 },
	{ "🎒 มีคลาส 3 คลาส", "OwnedCount", 3 }, { "🎒 มีคลาส 6 คลาส", "OwnedCount", 6 }, { "🏆 สะสมครบทุกคลาส", "OwnedCount", #Classes.Order },
	{ "⭐ คลาสเลเวล 3", "MaxClassLevel", 3 },
}

local function statOf(key)
	local p = profile or {}
	if key == "OwnedCount" then
		local n = 0
		for _ in pairs(p.Owned or {}) do
			n += 1
		end
		return n
	elseif key == "MaxClassLevel" then
		local best = 1
		for _, lv in pairs(p.ClassLevel or {}) do
			best = math.max(best, lv)
		end
		return best
	end
	return p[key] or 0
end

local function sideButton(parent, order, icon, name, onClick)
	local b = Instance.new("TextButton")
	b.Text = ""
	b.AutoButtonColor = true
	b.BackgroundColor3 = C(24, 26, 30)
	b.BackgroundTransparency = 0.3
	b.Size = UDim2.fromScale(1, 0.31)
	b.LayoutOrder = order
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = b
	stroke(b, 2.5, C(210, 214, 224), Enum.ApplyStrokeMode.Border).Transparency = 0.35
	label(b, { Size = UDim2.fromScale(1, 0.62), Position = UDim2.fromScale(0, 0.04), Text = icon }, 70)
	local t = label(b, { Size = UDim2.fromScale(0.96, 0.36), Position = UDim2.fromScale(0.02, 0.62), Text = name }, 40)
	stroke(t, 2.5)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(C(220, 240, 255), C(140, 190, 255))
	g.Rotation = 90
	g.Parent = t
	b.Activated:Connect(onClick)
	return b
end

function LobbyUI.Build(gui, handlers)
	local root = Instance.new("Frame")
	root.Name = "LobbyUI"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	ui.Root = root
	-- ปุ่มด้านซ้าย (สี่เหลี่ยมจัตุรัสตามความสูงจอ)
	local side = Instance.new("Frame")
	side.BackgroundTransparency = 1
	side.Position = UDim2.fromScale(0.012, 0.36)
	side.Size = UDim2.fromScale(0.11, 0.44)
	side.Parent = root
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 0.36
	ar.Parent = side
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.035, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = side
	sideButton(side, 1, "⚔", "คลาส", handlers.Classes)
	sideButton(side, 2, "🏅", "ป้าย", function()
		ui.Badges.Visible = not ui.Badges.Visible
		LobbyUI.Refresh()
	end)
	sideButton(side, 3, "💎", "ร้านค้า", handlers.Shop)
	-- เพชรมุมซ้ายล่าง
	local gem = label(root, { Position = UDim2.fromScale(0.005, 0.885), Size = UDim2.fromScale(0.075, 0.11), Text = "💎" }, 100)
	local _ = gem
	ui.Gems = label(root, { Position = UDim2.fromScale(0.012, 0.915), Size = UDim2.fromScale(0.06, 0.055), Text = "0", Rotation = -8 }, 44)
	stroke(ui.Gems, 3)

	-- หน้าต่างป้ายความสำเร็จ
	local panel = Instance.new("Frame")
	panel.Visible = false
	panel.BackgroundColor3 = C(14, 12, 10)
	panel.BackgroundTransparency = 0.15
	panel.Position = UDim2.fromScale(0.3, 0.12)
	panel.Size = UDim2.fromScale(0.4, 0.76)
	panel.Parent = root
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 20)
	pc.Parent = panel
	stroke(panel, 2, C(70, 60, 48), Enum.ApplyStrokeMode.Border)
	local title = label(panel, { Position = UDim2.fromScale(0.05, 0.02), Size = UDim2.fromScale(0.9, 0.1), Text = "ป้าย" }, 60)
	stroke(title, 3)
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new(C(255, 244, 150), C(242, 176, 40))
	tg.Rotation = 90
	tg.Parent = title
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromScale(0.05, 0.13)
	scroll.Size = UDim2.fromScale(0.9, 0.74)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.Parent = panel
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 6)
	ll.Parent = scroll
	ui.BadgeRows = {}
	for i, b in ipairs(BADGES) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 52)
		row.BackgroundColor3 = C(24, 22, 22)
		row.BackgroundTransparency = 0.2
		row.LayoutOrder = i
		row.Parent = scroll
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 8)
		rc.Parent = row
		local name = label(row, { Position = UDim2.fromScale(0.03, 0.1), Size = UDim2.fromScale(0.62, 0.8), Text = b[1], TextXAlignment = Enum.TextXAlignment.Left }, 26)
		stroke(name, 2)
		local prog = label(row, { Position = UDim2.fromScale(0.66, 0.15), Size = UDim2.fromScale(0.31, 0.7), Text = "", TextXAlignment = Enum.TextXAlignment.Right }, 24)
		stroke(prog, 2)
		ui.BadgeRows[i] = { Row = row, Name = name, Prog = prog }
	end
	local close = Instance.new("TextButton")
	close.Text = "ปิด"
	close.Font = Enum.Font.GothamBlack
	close.TextScaled = true
	close.TextColor3 = C(255, 255, 255)
	close.BackgroundColor3 = C(220, 60, 60)
	close.Position = UDim2.fromScale(0.35, 0.89)
	close.Size = UDim2.fromScale(0.3, 0.08)
	close.Parent = panel
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 8)
	cc.Parent = close
	stroke(close, 2)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	ui.Badges = panel
end

function LobbyUI.Refresh()
	if not ui.Root then
		return
	end
	ui.Gems.Text = tostring(player:GetAttribute("Diamonds") or (profile and profile.Diamonds) or 0)
	if ui.Badges.Visible then
		for i, b in ipairs(BADGES) do
			local v = statOf(b[2])
			local done = v >= b[3]
			local r = ui.BadgeRows[i]
			r.Prog.Text = done and "✅ ได้แล้ว" or string.format("%d/%d", v, b[3])
			r.Prog.TextColor3 = done and C(130, 240, 90) or C(220, 220, 220)
			r.Name.TextTransparency = done and 0 or 0.35
			r.Row.BackgroundColor3 = done and C(40, 60, 30) or C(24, 22, 22)
		end
	end
end

function LobbyUI.SetProfile(p)
	profile = p
	LobbyUI.Refresh()
end

-- ซ่อนตอนอยู่ในแมพ หรือเปิดร้านคลาสอยู่
function LobbyUI.SetVisible(v)
	if ui.Root then
		ui.Root.Visible = v
		if not v then
			ui.Badges.Visible = false
		end
	end
end

function LobbyUI.Init(gui, handlers)
	LobbyUI.Build(gui, handlers)
	player:GetAttributeChangedSignal("Diamonds"):Connect(LobbyUI.Refresh)
	LobbyUI.Refresh()
end

return LobbyUI
