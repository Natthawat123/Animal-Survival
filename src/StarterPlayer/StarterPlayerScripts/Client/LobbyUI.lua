--[[
	LobbyUI — ปุ่มเมนูล็อบบี้สไตล์เกมยุคใหม่: คลาส / ป้าย / ร้านค้า + แคปซูลเพชรมุมซ้ายบน
	ป้าย = ความสำเร็จที่คำนวณจากสถิติจริงในเซฟ (คืนที่รอด, สัตว์ที่ล่า, คลาสที่มี)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))
local UIKit = require(script.Parent.UIKit)

local LobbyUI = {}

local player = Players.LocalPlayer
local C = Color3.fromRGB
local profile
local ui = {}

-- ความสำเร็จ: { ชื่อ, ค่าปัจจุบัน(profile), เป้า }
local BADGES = {
	{ "🌙 รอดถึงคืนที่ 5", "BestNight", 5 }, { "🌙 รอดถึงคืนที่ 10", "BestNight", 10 }, { "🌕 รอดถึงคืนที่ 25", "BestNight", 25 },
	{ "🌕 รอดถึงคืนที่ 50", "BestNight", 50 }, { "👑 พิชิตคืนสุดท้าย", "BestNight", 99 },
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

-- ปุ่มเมนู: การ์ดกรมท่าเข้ม (ธีมเดียวกับร้านค้า) + วงไอคอนสีอ่อนๆ + ชื่อสีขาว · ชี้แล้วขยายนิดเดียว ไม่เด้งไปมา
local function dockButton(parent, order, icon, name, color, onClick)
	local b = UIKit.Button(parent, { Text = "", Size = UDim2.fromOffset(88, 88), LayoutOrder = order, BackgroundColor3 = C(34, 38, 66) }, onClick)
	b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 18)
	-- พื้นไล่สีกรมท่า (แทนไล่สีขาวของปุ่มทั่วไป)
	local g = b:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(C(255, 255, 255), C(170, 176, 205))
	end
	local border = b:FindFirstChildOfClass("UIStroke")
	if border then
		border.Color = C(10, 10, 22)
	end
	local ring = UIKit.Frame(b, { Size = UDim2.fromOffset(50, 50), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), BackgroundColor3 = color, BackgroundTransparency = 0.72, ZIndex = 2 })
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = ring
	local rs = Instance.new("UIStroke")
	rs.Color = color
	rs.Thickness = 2
	rs.Transparency = 0.35
	rs.Parent = ring
	UIKit.Text(ring, { Size = UDim2.fromScale(1, 1), Text = icon, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	UIKit.Text(b, { Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0, 4, 1, -26), Text = name, Font = UIKit.Fonts.Title, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C(236, 238, 250), ZIndex = 3 })
	local dot = UIKit.Frame(b, { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -16, 0, -8), BackgroundColor3 = UIKit.Colors.Red, BackgroundTransparency = 0, Visible = false, ZIndex = 8 })
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(1, 0)
	dc.Parent = dot
	UIKit.Stroke(dot, UIKit.Colors.Outline, 2, 0)
	local dt = UIKit.Text(dot, { Size = UDim2.fromScale(1, 1), Text = "!", Font = UIKit.Fonts.Title, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
	return b, dot, dt
end

function LobbyUI.Build(gui, handlers)
	local root = Instance.new("Frame")
	root.Name = "LobbyUI"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	ui.Root = root
	-- แถบเมนูซ้าย (แนวตั้ง กลางจอ)
	local side = Instance.new("Frame")
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(0, 0.5)
	side.Position = UDim2.new(0, 22, 0.52, 0)
	side.Size = UDim2.fromOffset(100, 420)
	side.Parent = root
	UIKit.AutoScale(side)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = side
	dockButton(side, 1, "⚔", "คลาส", UIKit.Colors.Orange, handlers.Classes)
	local _, dot, dotText = dockButton(side, 2, "🏅", "ป้าย", UIKit.Colors.Purple, function()
		ui.Badges.Visible = not ui.Badges.Visible
		if ui.Badges.Visible then
			UIKit.Pop(ui.Badges)
		end
		LobbyUI.Refresh()
	end)
	ui.BadgeDot, ui.BadgeDotText = dot, dotText
	dockButton(side, 3, "💎", "ร้านค้า", UIKit.Colors.Green, handlers.Shop)
	dockButton(side, 4, "⚙", "ตั้งค่า", UIKit.Colors.Blue, handlers.Settings)

	-- เพชร: แคปซูลมุมซ้ายบน + ปุ่ม + (เปิดร้านค้า)
	local pill = UIKit.Frame(root, { Size = UDim2.fromOffset(190, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 20), BackgroundColor3 = Color3.fromRGB(26, 30, 54), BackgroundTransparency = 0 })
	UIKit.AutoScale(pill)
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(1, 0)
	pc.Parent = pill
	UIKit.Stroke(pill, UIKit.Colors.Outline, 2, 0)
	UIKit.IconBadge(pill, "💎", UIKit.Colors.Cyan, 54, { Position = UDim2.fromOffset(-26, -4) })
	ui.Gems = UIKit.Text(pill, { Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(34, 0), Text = "0", Font = UIKit.Fonts.Title, TextSize = 28 })
	local plus = UIKit.ColorButton(pill, UIKit.Colors.Green, { Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -41, 0, 5), Text = "+", TextSize = 28 }, handlers.Shop)
	plus:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)

	-- หน้าต่างป้ายความสำเร็จ
	local panel = UIKit.Card(root, { Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(560, 520) })
	UIKit.Header(panel, "🏅 ป้ายความสำเร็จ", UIKit.Colors.Purple)
	UIKit.CloseButton(panel, function()
		panel.Visible = false
	end)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(20, 40)
	scroll.Size = UDim2.new(1, -40, 1, -58)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = UIKit.Colors.Purple
	scroll.Parent = panel
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 10)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = scroll
	local sp = Instance.new("UIPadding")
	sp.PaddingTop, sp.PaddingLeft, sp.PaddingRight, sp.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 12), UDim.new(0, 6)
	sp.Parent = scroll
	ui.BadgeRows = {}
	for i, b in ipairs(BADGES) do
		local row = UIKit.Frame(scroll, { Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = Color3.fromRGB(46, 52, 86), BackgroundTransparency = 0, LayoutOrder = i })
		UIKit.Corner(row, 12)
		UIKit.Stroke(row, UIKit.Colors.Outline, 2, 0)
		local name = UIKit.Text(row, { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(0.68, 0, 0, 28), Text = b[1], Font = UIKit.Fonts.Black, TextSize = 20 })
		local bar = UIKit.Bar(row, { Size = UDim2.new(0.68, 0, 0, 16), Position = UDim2.fromOffset(14, 38), Color = UIKit.Colors.Purple, Label = "" })
		local prog = UIKit.Text(row, { Position = UDim2.new(0.72, 0, 0, 0), Size = UDim2.new(0.28, -14, 1, 0), Text = "", Font = UIKit.Fonts.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right })
		ui.BadgeRows[i] = { Row = row, Name = name, Prog = prog, Bar = bar }
	end
	ui.Badges = panel
end

function LobbyUI.Refresh()
	if not ui.Root then
		return
	end
	ui.Gems.Text = tostring(player:GetAttribute("Diamonds") or (profile and profile.Diamonds) or 0)
	local got = 0
	for i, b in ipairs(BADGES) do
		local v = statOf(b[2])
		local done = v >= b[3]
		got += done and 1 or 0
		if ui.Badges.Visible then
			local r = ui.BadgeRows[i]
			r.Prog.Text = done and "✅" or string.format("%d/%d", math.min(v, b[3]), b[3])
			r.Prog.TextColor3 = done and C(130, 240, 90) or C(235, 235, 255)
			r.Name.TextTransparency = done and 0 or 0.25
			r.Bar.Set(math.min(v / b[3], 1))
			r.Bar.Fill.BackgroundColor3 = done and UIKit.Colors.Green or UIKit.Colors.Purple
			r.Row.BackgroundColor3 = done and C(40, 92, 60) or C(46, 52, 86)
		end
	end
	ui.BadgeDot.Visible = got > 0
	ui.BadgeDotText.Text = tostring(got)
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
