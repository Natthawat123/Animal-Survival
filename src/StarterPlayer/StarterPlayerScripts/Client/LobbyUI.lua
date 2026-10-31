--[[
	LobbyUI — ปุ่มเมนูล็อบบี้ (ภาพวาดเหรียญไม้+ป้ายไม้ จาก Shared/MenuArt): คลาส / ภารกิจ / ป้าย / ร้านค้า / ตั้งค่า + แคปซูล Ruby มุมขวาบน
	ป้าย = ความสำเร็จที่คำนวณจากสถิติจริงในเซฟ (Shared/Quests.lua Achievements) — ทำครบแล้วกดรับ Ruby ได้ครั้งเดียว (หน้าต่างธีมไม้ WoodKit)
	ภารกิจ = หน้าต่าง QuestUI (LobbyUI.OnQuests) · จุดแดง = มีรางวัลให้รับ (LobbyUI.SetQuestDot)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))
local Quests = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quests"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UIKit = require(script.Parent.UIKit)
local WoodKit = require(script.Parent.WoodKit)
local MenuArt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuArt"))

local LobbyUI = {}

local player = Players.LocalPlayer
local C = Color3.fromRGB
local profile
local ui = {}

-- ความสำเร็จ: Quests.Achievements { Id, Text, Stat, Need, Ruby } (server ตรวจซ้ำตอนกดรับ)
local BADGES = Quests.Achievements

-- ปุ่มเมนูซ้ายเปิดได้ทีละหน้า: กดเมนูใหม่ = ปิดหน้าอื่นก่อน
-- แต่ละหน้าลงทะเบียนตัวปิดไว้ที่ LobbyUI.Closers[ชื่อปุ่ม] (Classes / Quests / Badges / Shop / Settings)
LobbyUI.Closers = {}

function LobbyUI.CloseMenus(except)
	for name, fn in pairs(LobbyUI.Closers) do
		if name ~= except then
			local ok, err = pcall(fn)
			if not ok then
				warn("[AS] close menu", name, err)
			end
		end
	end
end

local function statOf(key)
	return Quests.StatOf(profile, key)
end

-- ปุ่มเมนู: ไม่มีกล่องครอบ · วงกลมสีนุ่มๆ ไล่เงา + ขอบขาวบาง + ไอคอนใหญ่ + ชื่อตัวขาวขอบดำใต้วง
-- ชี้แล้วขยายนิดเดียว กดแล้วยุบนิดเดียว (ไม่เด้งไปมาเอง)
local function dockButton(parent, order, icon, name, color, onClick)
	local b = Instance.new("TextButton")
	b.Name = "Dock_" .. name
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(84, 98)
	b.LayoutOrder = order
	b.Parent = parent
	local circle = UIKit.Frame(b, { Size = UDim2.fromOffset(68, 68), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), BackgroundColor3 = color, BackgroundTransparency = 0, ZIndex = 2 })
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = circle
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(C(255, 255, 255), C(150, 150, 160))
	grad.Rotation = 90
	grad.Parent = circle
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Color = C(255, 255, 255)
	rim.Thickness = 2.5
	rim.Transparency = 0.25
	rim.Parent = circle
	-- เงาวาวครึ่งบน
	local gloss = UIKit.Frame(circle, { Size = UDim2.new(0.72, 0, 0.36, 0), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.07, 0), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.82, ZIndex = 3 })
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(1, 0)
	gc.Parent = gloss
	if icon == "Ruby" or icon == "Shield" or icon == "Trophy" or icon == "Scroll" then
		UIKit.Icon(circle, icon, 50, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4 })
	else
		UIKit.Text(circle, { Size = UDim2.fromScale(1, 1), Text = icon, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
	end
	local label = UIKit.Text(b, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 72), Text = name, Font = UIKit.Fonts.Title, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C(255, 255, 255), ZIndex = 3 })
	label:FindFirstChildOfClass("UIStroke").Thickness = 2.2
	local sc = Instance.new("UIScale")
	sc.Parent = circle
	b.MouseEnter:Connect(function()
		UIKit.Tween(sc, 0.15, { Scale = 1.08 })
	end)
	b.MouseLeave:Connect(function()
		UIKit.Tween(sc, 0.15, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		UIKit.Tween(sc, 0.08, { Scale = 0.94 })
	end)
	b.Activated:Connect(function()
		UIKit.Tween(sc, 0.12, { Scale = 1 })
		if onClick then
			onClick()
		end
	end)
	local dot = UIKit.Frame(circle, { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -16, 0, -4), BackgroundColor3 = UIKit.Colors.Red, BackgroundTransparency = 0, Visible = false, ZIndex = 8 })
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(1, 0)
	dc.Parent = dot
	UIKit.Stroke(dot, C(255, 255, 255), 2, 0)
	if onClick then
		UIKit.EnsureTouchSize(b, 44, onClick) -- แถบเมนูถูกย่อตามจอ: พื้นที่แตะไม่เล็กกว่า 44px
	end
	local dt = UIKit.Text(dot, { Size = UDim2.fromScale(1, 1), Text = "!", Font = UIKit.Fonts.Title, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
	return b, dot, dt
end

-- ปุ่มเมนูแบบภาพวาด (เหรียญไม้ + ป้ายไม้ + ธง) จาก Shared/MenuArt — โหลดรูปไม่ได้คืน nil (ใช้ปุ่มแบบเดิมแทน)
local ART_W = 270
local function artButton(parent, order, art, onClick)
	local ok, img = pcall(MenuArt.Image, art)
	local size = MenuArt.Size[art]
	if not ok or not img or not size then
		return nil
	end
	local b = Instance.new("ImageButton")
	b.Name = "Dock_" .. art
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	b.ImageContent = Content.fromObject(img)
	b.Size = UDim2.fromOffset(ART_W, math.floor(ART_W * size.Y / size.X))
	b.LayoutOrder = order
	b.Parent = parent
	local sc = Instance.new("UIScale")
	sc.Parent = b
	b.MouseEnter:Connect(function()
		UIKit.Tween(sc, 0.15, { Scale = 1.05 })
		UIKit.Tween(b, 0.15, { ImageColor3 = C(255, 255, 255) })
	end)
	b.MouseLeave:Connect(function()
		UIKit.Tween(sc, 0.15, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		UIKit.Tween(sc, 0.08, { Scale = 0.95 })
		b.ImageColor3 = C(225, 225, 225)
	end)
	b.Activated:Connect(function()
		UIKit.Tween(sc, 0.12, { Scale = 1 })
		b.ImageColor3 = C(255, 255, 255)
		if onClick then
			onClick()
		end
	end)
	-- จุดแจ้งเตือนบนขอบเหรียญ (มุมขวาบนของวงกลมด้านซ้าย)
	local dot = UIKit.Frame(b, { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0.3, -4, 0, 0), BackgroundColor3 = UIKit.Colors.Red, BackgroundTransparency = 0, Visible = false, ZIndex = 8 })
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(1, 0)
	dc.Parent = dot
	UIKit.Stroke(dot, C(255, 255, 255), 2, 0)
	local dt = UIKit.Text(dot, { Size = UDim2.fromScale(1, 1), Text = "!", Font = UIKit.Fonts.Title, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
	if onClick then
		UIKit.EnsureTouchSize(b, 44, onClick)
	end
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
	side.Position = UDim2.new(0, 22, 0.56, 0)
	local useArt = MenuArt.Image("Classes") ~= nil
	side.Size = useArt and UDim2.fromOffset(ART_W + 10, 600) or UDim2.fromOffset(90, 510)
	side.Parent = root
	UIKit.AutoScale(side, { maxW = 0.3, maxH = 0.74 })
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = side
	-- ปุ่มภาพวาดก่อน ไม่ได้ค่อยใช้ปุ่มวงกลมแบบเดิม
	local function menuButton(order, art, icon, name, color, handler)
		local function onClick()
			LobbyUI.CloseMenus(art)
			if handler then
				handler()
			end
		end
		if useArt then
			local b, d, t = artButton(side, order, art, onClick)
			if b then
				return b, d, t
			end
		end
		return dockButton(side, order, icon, name, color, onClick)
	end
	menuButton(1, "Classes", "Shield", "คลาส", C(230, 132, 64), handlers.Classes)
	local _, qdot, qdotText = menuButton(2, "Quests", "Scroll", "ภารกิจ", C(236, 178, 52), function()
		if LobbyUI.OnQuests then
			LobbyUI.OnQuests()
		end
	end)
	ui.QuestDot, ui.QuestDotText = qdot, qdotText
	local _, dot, dotText = menuButton(3, "Badges", "Trophy", "ป้าย", C(146, 104, 222), function()
		ui.Badges.Visible = not ui.Badges.Visible
		if ui.Badges.Visible then
			UIKit.Pop(ui.Badges)
		end
		LobbyUI.Refresh()
	end)
	ui.BadgeDot, ui.BadgeDotText = dot, dotText
	menuButton(4, "Shop", "Ruby", "ร้านค้า", C(64, 182, 120), handlers.Shop)
	menuButton(5, "Settings", "⚙", "ตั้งค่า", C(74, 132, 220), handlers.Settings)

	-- Ruby: แคปซูลมุมซ้ายบน + ปุ่ม + (เปิดร้านค้า)
	-- (ธีมไม้เดียวกับหน้าต่างร้านค้า: ไม้เข้มขอบทอง + ปุ่ม + แดง)
	local pill = WoodKit.Frame(root, { Size = UDim2.fromOffset(190, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 20), BackgroundColor3 = Color3.fromRGB(42, 28, 18) })
	UIKit.AutoScale(pill, { w = 230, maxW = 0.25 })
	WoodKit.Corner(pill, "round")
	WoodKit.Stroke(pill, WoodKit.Colors.GoldDark, 3, 0)
	UIKit.Icon(pill, "Ruby", 60, { Position = UDim2.fromOffset(-30, -9), ZIndex = 3 })
	ui.Gems = UIKit.Text(pill, { Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(34, 0), Text = "0", Font = UIKit.Fonts.Title, TextSize = 28 })
	local plus = WoodKit.Button(pill, "Red", { Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -41, 0, 5), Text = "+", TextSize = 28 }, handlers.Shop)
	plus:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	UIKit.EnsureTouchSize(plus, 44, handlers.Shop)

	-- หน้าต่างป้ายความสำเร็จ (ธีมกรอบไม้)
	local win = WoodKit.Window(root, { Name = "BadgeWindow", Size = Vector2.new(760, 600), Title = "🏅 ป้ายความสำเร็จ", OnClose = function()
		ui.Badges.Visible = false
	end })
	local panel = win.Frame
	UIKit.RegisterWindow(panel)
	LobbyUI.Closers.Badges = function()
		panel.Visible = false
	end
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(30, 50)
	scroll.Size = UDim2.new(1, -60, 1, -78)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = WoodKit.Colors.Gold
	scroll.Parent = win.Body
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 10)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = scroll
	local sp = Instance.new("UIPadding")
	sp.PaddingTop, sp.PaddingLeft, sp.PaddingRight, sp.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 12), UDim.new(0, 6)
	sp.Parent = scroll
	ui.BadgeRows = {}
	for i, b in ipairs(BADGES) do
		local row = WoodKit.Parchment(scroll, { Size = UDim2.new(1, 0, 0, 76), LayoutOrder = i })
		WoodKit.Medallion(row, "Trophy", 56, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 2 }, C(96, 40, 22))
		local name = WoodKit.Ink(row, { Position = UDim2.fromOffset(80, 8), Size = UDim2.new(1, -300, 0, 28), Text = b.Text, TextSize = 20 })
		local bar = UIKit.Bar(row, { Size = UDim2.new(1, -300, 0, 18), Position = UDim2.fromOffset(80, 44), Color = WoodKit.Colors.Gold, Label = "" })
		local prog = WoodKit.Ink(row, { Position = UDim2.new(1, -214, 0, 0), Size = UDim2.fromOffset(84, 76), Text = "", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center })
		local claim = WoodKit.Button(row, "Off", { Size = UDim2.fromOffset(120, 44), Position = UDim2.new(1, -130, 0.5, -22), Text = "♦️ " .. b.Ruby, TextSize = 18, ZIndex = 4 }, function()
			local r = ui.BadgeRows[i]
			if r and r.Ready then
				r.Ready = false
				Remotes.Get("ClaimAchievement"):FireServer(b.Id)
			end
		end)
		ui.BadgeRows[i] = { Row = row, Name = name, Prog = prog, Bar = bar, Claim = claim }
	end
	ui.Badges = panel
end

function LobbyUI.Refresh()
	if not ui.Root then
		return
	end
	ui.Gems.Text = tostring(player:GetAttribute("Diamonds") or (profile and profile.Diamonds) or 0)
	local ready = 0
	local claimed = (profile and profile.AchClaimed) or {}
	for i, b in ipairs(BADGES) do
		local need = Quests.NeedOf(b, #Classes.Order)
		local v = statOf(b.Stat)
		local done = v >= need
		local got = claimed[b.Id] == true
		local canClaim = done and not got and profile ~= nil
		ready += canClaim and 1 or 0
		local r = ui.BadgeRows[i]
		r.Ready = canClaim
		-- รับได้ขึ้นบนสุด · ยังไม่ครบตรงกลาง · รับแล้วไว้ล่างสุด
		r.Row.LayoutOrder = (canClaim and 0 or (got and 2000 or 1000)) + i
		if ui.Badges.Visible then
			r.Prog.Text = done and "✅ สำเร็จ" or string.format("%d/%d", math.min(v, need), need)
			r.Prog.TextColor3 = done and WoodKit.Colors.Good or WoodKit.Colors.Ink
			r.Name.TextTransparency = done and 0 or 0.2
			r.Bar.Set(math.min(v / need, 1))
			r.Bar.Fill.BackgroundColor3 = done and C(110, 200, 80) or WoodKit.Colors.Gold
			-- กระดาษ: รับได้ = ทองสว่าง · สำเร็จแล้ว = เขียวอ่อน · ยังไม่ครบ = กระดาษปกติ
			r.Row.BackgroundColor3 = canClaim and C(255, 228, 150) or (done and C(206, 216, 168) or WoodKit.Colors.Parch)
			if got then
				r.Claim.Text = "✔ รับแล้ว"
				WoodKit.Style(r.Claim, "Green")
			elseif canClaim then
				r.Claim.Text = "รับ ♦️ " .. b.Ruby
				WoodKit.Style(r.Claim, "Red")
			else
				r.Claim.Text = "♦️ " .. b.Ruby
				WoodKit.Style(r.Claim, "Off")
			end
		end
	end
	ui.BadgeDot.Visible = ready > 0
	ui.BadgeDotText.Text = tostring(ready)
end

function LobbyUI.SetProfile(p)
	profile = p
	LobbyUI.Refresh()
end

-- จุดแดงบนปุ่ม "ภารกิจ" (QuestUI นับรางวัลที่รับได้)
function LobbyUI.SetQuestDot(n)
	if ui.QuestDot then
		ui.QuestDot.Visible = (n or 0) > 0
		ui.QuestDotText.Text = tostring(math.min(n or 0, 99))
	end
end

-- ซ่อนตอนอยู่ในแมพ หรือเปิดร้านคลาสอยู่
function LobbyUI.SetVisible(v)
	if ui.Root then
		ui.Root.Visible = v
		if not v then
			ui.Badges.Visible = false
			if LobbyUI.OnHidden then
				LobbyUI.OnHidden()
			end
		end
	end
end

function LobbyUI.Init(gui, handlers)
	LobbyUI.Build(gui, handlers)
	player:GetAttributeChangedSignal("Diamonds"):Connect(LobbyUI.Refresh)
	LobbyUI.Refresh()
end

return LobbyUI
