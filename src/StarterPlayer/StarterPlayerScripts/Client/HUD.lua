--[[
	HUD — หน้าจอหลักระหว่างเล่น
	  ซ้ายบน: เลือด / ความหิว / สตามิน่า
	  กลางบน: คืนที่ X + เวลา + ธาตุประจำคืน + เข็มทิศ
	  ซ้าย (ใต้แถบค่า): เพื่อนร่วมทีม — ชื่อ + เลือด + สถานะล้ม/ตาย (เพื่อนบนเข็มทิศพร้อมระยะ)
	  ขวาบน: กองไฟ (วงแหวนเชื้อเพลิง เขียว→เหลือง→แดง + เวลาที่เหลือ) + ลูกสัตว์ธาตุ 4 ดวง + Ruby
	  ล่าง: ทรัพยากรในกระเป๋า + ปุ่มลัด / แถบเลือดบอส
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Animals = require(Shared.Animals)
local Config = require(Shared.Config)
local Classes = require(Shared.Classes)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local SoundController = require(script.Parent.SoundController)
local ItemIcon = require(script.Parent.ItemIcon)

local HUD = {}
local player = Players.LocalPlayer
local C = UIKit.Colors

local STRIP = { "Wood", "Stone", "Fiber", "Iron", "Coal", "Pelt", "Bone", "Berries", "RawMeat", "CookedMeat", "TerraCore", "TidePearl", "GaleFeather", "EmberShard" }
local ICON = {
	Wood = "🌲", Stone = "🗻", Fiber = "🌾", Iron = "⛓", Coal = "⚫", Pelt = "🟫", Bone = "🦴", Berries = "🍒", RawMeat = "🥩",
	CookedMeat = "🍖", Stew = "🍲", BerryJuice = "🧃", BerryPie = "🥧", HerbSalve = "🌿", TerraCore = "🟢", TidePearl = "🔵", GaleFeather = "🪶", EmberShard = "🔶", Bandage = "🩹",
	Medkit = "⛑", TerraHeart = "💚", TideHeart = "💙", FrostHeart = "🤍", EmberHeart = "🧡",
}
HUD.Icon = ICON
HUD.ExtraPOI = {}

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

function HUD.Init(state)
	HUD.State = state
	HUD.Touch = UIKit.IsTouch
	local gui = UIKit.Screen("HUD", 5)
	HUD.Gui = gui

	---------------------------------------------------------------- ซ้ายบน: แถบค่า
	-- การ์ดกระจกมุมซ้ายบน: หัวการ์ด = คลาส · 3 แถว เลือด / หิว / สตามิน่า (ไอคอนช่องเหลี่ยมมน + แถบยาวเท่ากัน ตัวเลขชิดขวา)
	local stats = UIKit.Frame(gui, { Size = UDim2.fromOffset(310, 160), Position = UDim2.fromOffset(16, 74), BackgroundTransparency = 1 })
	UIKit.AutoScale(stats, { maxW = 0.3, maxH = 0.45 })
	local card = UIKit.Frame(stats, { Size = UDim2.fromOffset(294, 150), BackgroundColor3 = Color3.fromRGB(16, 14, 26), BackgroundTransparency = 0.22 })
	UIKit.Corner(card, 12)
	local cs = UIKit.Stroke(card, C.Gold, 1, 0.2)
	cs.Thickness = 1.2
	cs.Transparency = 0.45
	UIKit.Gradient(card, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 170), 90)
	-- หัวการ์ด: โล่ + ชื่อคลาส + เส้นทองบางๆ
	pcall(UIKit.Icon, card, "Shield", 20, { Position = UDim2.fromOffset(14, 10) })
	HUD.ClassLabel = UIKit.Text(card, { Size = UDim2.fromOffset(240, 20), Position = UDim2.fromOffset(42, 10), TextSize = 16, Font = UIKit.Fonts.Black, TextColor3 = C.Gold, Text = "" })
	local line = UIKit.Frame(card, { Size = UDim2.new(1, -28, 0, 1), Position = UDim2.fromOffset(14, 38), BackgroundColor3 = C.Gold, BackgroundTransparency = 0.3 })
	local lg = Instance.new("UIGradient")
	lg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) })
	lg.Parent = line
	local function row(y, icon, color, h)
		local badge = UIKit.Frame(card, { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(14, y), BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.55), ZIndex = 4 })
		UIKit.Corner(badge, 7)
		local bs = UIKit.Stroke(badge, color, 1, 0.1)
		bs.Thickness = 1.5
		UIKit.Text(badge, { Size = UDim2.fromScale(1, 1), Text = icon, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
		local bar = UIKit.Bar(card, { Size = UDim2.fromOffset(222, h), Position = UDim2.fromOffset(54, y + (28 - h) / 2), Color = color, Label = "" })
		local st = bar.Holder:FindFirstChildOfClass("UIStroke")
		if st then
			st.Thickness = 1.5
			st.Transparency = 0.15
		end
		bar.Label.TextXAlignment = Enum.TextXAlignment.Right
		bar.Label.Size = UDim2.new(1, -16, 1, 0)
		bar.Label.Position = UDim2.fromOffset(8, 0)
		bar.Badge, bar.BadgeStroke = badge, bs
		return bar
	end
	HUD.HealthBar = row(48, "❤", C.Health, 22)
	HUD.HungerBar = row(82, "🍖", C.Hunger, 18)
	HUD.StaminaBar = row(114, "⚡", C.Stamina, 14)
	-- ปุ่ม "กิน" ท้ายแถบหิว: มีอาหารในกระสอบ = แตะกินชิ้นที่ดีที่สุดได้เลย (ไม่ต้องเปิดกระสอบ · มือถือก็กดได้)
	HUD.EatBtn = UIKit.ColorButton(card, Color3.fromRGB(196, 92, 40), {
		Size = UDim2.fromOffset(58, 26), Position = UDim2.fromOffset(222, 83), Text = "🍖 Eat", TextSize = 14, Visible = false, ZIndex = 6,
	}, function()
		if HUD.EatId then
			Remotes.Get("UseItem"):FireServer(HUD.EatId)
		end
	end)
	HUD.EatBtn:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 8)
	-- เพื่อนร่วมทีม (อยู่ในกรอบเดียวกับแถบค่า ย่อ/ขยายไปด้วยกัน)
	local team = UIKit.Frame(stats, { Name = "Team", Size = UDim2.fromOffset(240, 0), Position = UDim2.fromOffset(4, 158), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Visible = false })
	local tl = Instance.new("UIListLayout")
	tl.Padding = UDim.new(0, 4)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = team
	HUD.TeamFrame = team
	HUD.TeamRows = {}
	HUD.TeamMarks = {}

	-- หลอดลมหายใจ (โผล่ใต้เป้ากลางจอเฉพาะตอนดำน้ำ)
	HUD.AirBar = UIKit.Bar(gui, { Size = UDim2.fromOffset(200, 16), Position = UDim2.new(0.5, -100, 0.5, 70), Color = Color3.fromRGB(90, 200, 255), Label = "" })
	HUD.AirBar.Holder.Visible = false

	---------------------------------------------------------------- กลางบน: คืน
	local top = UIKit.Frame(gui, { Size = UDim2.fromOffset(440, 84), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), BackgroundTransparency = 1 })
	-- กว้างจริง = เข็มทิศ 520 · มือถือบีบแคบลงไม่ให้ชนการ์ดซ้าย/ขวา
	local topOpts = { w = 520, h = 120, maxW = 0.44, phoneMaxW = 0.36, maxH = 0.3 }
	UIKit.AutoScale(top, topOpts) -- เข็มทิศ + แถบเลือดบอสอยู่ในกรอบนี้ (ย่อ/ขยายไปด้วยกัน)
	HUD.NightLabel = UIKit.Text(top, {
		Size = UDim2.new(1, 0, 0, 44), Font = UIKit.Fonts.Title, TextSize = 44, TextXAlignment = Enum.TextXAlignment.Center,
		Text = "DAY 1", TextColor3 = C.Gold,
	})
	HUD.NightLabel:FindFirstChildOfClass("UIStroke").Thickness = 4
	HUD.NightLabel.RichText = true -- วันโบนัสต่อท้ายในบรรทัดเดียวกัน ("DAY 12 +3") ไม่ทับเลข
	HUD.NightPop = Instance.new("UIScale")
	HUD.NightPop.Parent = HUD.NightLabel
	HUD.PhaseLabel = UIKit.Text(top, {
		Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 44), TextSize = 17, Font = UIKit.Fonts.Black, TextXAlignment = Enum.TextXAlignment.Center,
		Text = "", TextColor3 = C.Text,
	})
	-- เส้นเวลา (หลอดหนา + ไอคอนดวงอาทิตย์/จันทร์วิ่งตาม)
	local track = UIKit.Frame(top, { Size = UDim2.new(1, -90, 0, 10), Position = UDim2.new(0, 45, 0, 70), BackgroundColor3 = Color3.fromRGB(14, 14, 26), BackgroundTransparency = 0.05 })
	UIKit.Corner(track, 3)
	UIKit.Stroke(track, C.Outline, 2, 0)
	HUD.TimeFill = UIKit.Frame(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, BackgroundTransparency = 0 })
	UIKit.Corner(HUD.TimeFill, 3)
	HUD.TimeIcon = UIKit.Text(track, { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0, -13, 0.5, -13), Text = "☀", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })

	-- เข็มทิศ
	local compass = UIKit.Frame(top, { Size = UDim2.fromOffset(520, 28), Position = UDim2.new(0.5, -260, 0, 90), BackgroundColor3 = Color3.fromRGB(20, 22, 40), BackgroundTransparency = 0.35, ClipsDescendants = true })
	UIKit.Corner(compass, 12)
	UIKit.Stroke(compass, C.Outline, 2, 0.2)
	HUD.Compass = compass
	HUD.CompassMarks = {}
	for _, d in ipairs({ { "N", 0 }, { "E", 90 }, { "S", 180 }, { "W", 270 } }) do
		local t = UIKit.Text(compass, { Size = UDim2.fromOffset(20, 28), Text = d[1], Font = UIKit.Fonts.Title, TextSize = 18, TextColor3 = d[1] == "N" and C.Red or C.Text, TextXAlignment = Enum.TextXAlignment.Center })
		table.insert(HUD.CompassMarks, { Label = t, Angle = math.rad(d[2]) })
	end
	HUD.CompassPOI = {}

	---------------------------------------------------------------- ขวาบน: กองไฟ / วิญญาณ / Ruby
	-- ใต้แถวปุ่มบนสุด (ปุ่มกระเป๋ามุมขวาบนอยู่แถวเดียวกับเมนู Roblox) -> ไม่ซ้อนกัน
	local right = UIKit.Card(gui, { Size = UDim2.fromOffset(270, 116), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12), BackgroundTransparency = 0.12 })
	UIKit.AutoScale(right, { w = 330, h = 170, maxW = 0.32, maxH = 0.45 }) -- รวมปุ่มกลมทางซ้ายการ์ด (ตั้งค่า/แผนที่/ปักหมุด)
	HUD.RightCard = right
	-- วงแหวนเชื้อเพลิงรอบไอคอนกองไฟ (ขีดเรียงเป็นวง: เต็ม = เขียว · ครึ่ง = เหลือง · ใกล้หมด = แดงกะพริบ)
	local ring = UIKit.Frame(right, { Name = "FuelRing", Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(6, 4), BackgroundTransparency = 1, ZIndex = 3 })
	HUD.FuelSegs = {}
	local SEGS, R = 24, 30
	for i = 1, SEGS do
		local a = (i - 0.5) / SEGS * math.pi * 2 -- เริ่มที่ 12 นาฬิกา วนตามเข็ม
		local seg = UIKit.Frame(ring, {
			Size = UDim2.fromOffset(5, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(35 + math.sin(a) * R, 35 - math.cos(a) * R),
			Rotation = math.deg(a), BackgroundColor3 = Color3.fromRGB(60, 60, 70), BackgroundTransparency = 0, ZIndex = 3,
		})
		UIKit.Corner(seg, 1)
		HUD.FuelSegs[i] = seg
	end
	HUD.FireIcon = UIKit.IconBadge(right, "🔥", C.Fire, 40, { Position = UDim2.fromOffset(21, 19) })
	HUD.FireIconScale = Instance.new("UIScale")
	HUD.FireIconScale.Parent = HUD.FireIcon
	HUD.FireLabel = UIKit.Text(right, { Size = UDim2.new(1, -90, 0, 20), Position = UDim2.fromOffset(82, 6), Text = "Campfire Lv.1", Font = UIKit.Fonts.Black, TextColor3 = C.Text, TextSize = 15 })
	HUD.FuelText = UIKit.Text(right, { Size = UDim2.new(1, -90, 0, 26), Position = UDim2.fromOffset(82, 26), Text = "", Font = UIKit.Fonts.Title, TextColor3 = C.Good, TextSize = 22 })
	HUD.SafeLabel = UIKit.Text(right, { Size = UDim2.new(1, -90, 0, 22), Position = UDim2.fromOffset(82, 52), Text = "", TextSize = 15, TextColor3 = C.TextDim })
	HUD.FuelLowArmed = true
	HUD.SpiritOrbs = {}
	for i, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		local orb = UIKit.Frame(right, { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(12 + (i - 1) * 34, 80), BackgroundColor3 = Color3.fromRGB(50, 50, 56), BackgroundTransparency = 0 })
		local oc = Instance.new("UICorner")
		oc.CornerRadius = UDim.new(1, 0)
		oc.Parent = orb
		UIKit.Stroke(orb, C.Outline, 2, 0)
		local t = UIKit.Text(orb, { Size = UDim2.fromScale(1, 1), Text = UIKit.ElementIcon[el], TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 0.6 })
		HUD.SpiritOrbs[el] = { Frame = orb, Icon = t }
	end
	-- มือถือในแมพ: แถบวัน/เข็มทิศแคบลง + อยู่กลางช่องว่างระหว่างการ์ดซ้าย (และปุ่มกระเป๋า) กับการ์ดกองไฟ
	local function layoutTop()
		-- (จอสัมผัสมีปุ่มแผนที่/ปักหมุดเรียงลงมาระดับเดียวกับเข็มทิศ)
		local vpX = UIKit.Viewport().X
		local narrow = player:GetAttribute("InRun") == true and (vpX < 1000 or (UIKit.IsTouch and vpX < 1250))
		top.Size = UDim2.fromOffset(narrow and 320 or 440, 84)
		local cw = narrow and 320 or 520
		compass.Size = UDim2.fromOffset(cw, 28)
		compass.Position = UDim2.new(0.5, -cw / 2, 0, 90)
		if narrow then
			local vp = UIKit.Viewport()
			local inset = GuiService.TopbarInset
			local bagRight = (inset.Min.X > 0 and inset.Min.X or 104) + 52
			local statsRight = 16 + 310 * UIKit.GetScale(stats)
			local rightLeft = vp.X - 16 - 330 * UIKit.GetScale(right)
			local cx = math.max((statsRight + rightLeft) / 2, bagRight + 50) -- ชื่อวัน (กว้าง ~100) ไม่ทับปุ่มกระเป๋า
			local half = math.max(math.min(cx - statsRight, rightLeft - cx) - 4, 75)
			topOpts.w, topOpts.maxW, topOpts.phoneMaxW = cw, half * 2 / vp.X, nil
			top.Position = UDim2.new(0, cx, 0, 10)
		else
			topOpts.w, topOpts.maxW, topOpts.phoneMaxW = 520, 0.44, 0.6
			top.Position = UDim2.new(0.5, 0, 0, 10)
		end
		UIKit.AutoScale(top, topOpts)
		if HUD.Feed then
			-- มือถือ: กรอบบนถูกย่อ -> แจ้งเตือนเริ่มใต้แถบเลือดบอสพอดี (เดิม 178 px ตายตัว = กลางจอเตี้ย ชนการ์ดกด E/ฟีดเก็บของ)
			HUD.Feed.Position = UIKit.IsPhone() and UDim2.new(0.5, 0, 0, math.floor(16 + 196 * UIKit.GetScale(top)))
				or UDim2.new(0.5, 0, 0, (HUD.Touch and 178 or 198) * UIKit.BigScale())
		end
	end
	layoutTop()
	UIKit.OnResize(layoutTop)
	player:GetAttributeChangedSignal("InRun"):Connect(layoutTop)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layoutTop)
	HUD.DiamondLabel = UIKit.Text(right, { Size = UDim2.fromOffset(100, 28), Position = UDim2.new(1, -144, 0, 80), Text = "0", Font = UIKit.Fonts.Title, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 190, 190) })
	UIKit.Icon(right, "Ruby", 32, { Position = UDim2.new(1, -42, 0, 76) })
	-- คลังแคมป์ (ของที่ย่อยแล้ว ใช้ร่วมกันทั้งทีม): รูปไอเทม + จำนวน ใต้การ์ดกองไฟ
	local stock = UIKit.Frame(right, { Name = "CampStock", Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 124), BackgroundColor3 = Color3.fromRGB(16, 14, 26), BackgroundTransparency = 0.22 })
	UIKit.Corner(stock, 10)
	local ss = UIKit.Stroke(stock, C.Gold, 1, 0.2)
	ss.Thickness = 1.2
	ss.Transparency = 0.45
	UIKit.Text(stock, { Size = UDim2.fromOffset(60, 44), Position = UDim2.fromOffset(12, 0), Text = "Camp Storage", TextSize = 13, Font = UIKit.Fonts.Black, TextColor3 = C.Gold })
	HUD.StockLabels = {}
	for i, id in ipairs({ "Wood", "Stone", "Iron" }) do
		local x = 78 + (i - 1) * 62
		ItemIcon.Make(stock, id, { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(x, 7), ZIndex = 3 })
		HUD.StockLabels[id] = UIKit.Text(stock, { Size = UDim2.fromOffset(30, 44), Position = UDim2.fromOffset(x + 31, 0), Text = "0", TextSize = 17, Font = UIKit.Fonts.Black, TextColor3 = C.Text })
	end

	-- ป้าย "ลูกสัตว์ในแคมป์ x/4" (ป้ายเรืองแสงสีฟ้าแบบเกมต้นแบบ) ใต้คลังแคมป์
	local pups = UIKit.Frame(right, { Name = "PupCounter", Size = UDim2.fromOffset(160, 58), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 174), BackgroundColor3 = Color3.fromRGB(20, 40, 120), BackgroundTransparency = 0.05 })
	UIKit.Corner(pups, 10)
	local pg = Instance.new("UIGradient")
	pg.Color = ColorSequence.new(Color3.fromRGB(90, 170, 255), Color3.fromRGB(30, 60, 190))
	pg.Rotation = 90
	pg.Parent = pups
	local pst = UIKit.Stroke(pups, Color3.fromRGB(130, 220, 255), 2, 0)
	pst.Thickness = 2
	HUD.PupCount = UIKit.Text(pups, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 2), Text = "0/4", Font = UIKit.Fonts.Title, TextSize = 30, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	local pcs = Instance.new("UIStroke")
	pcs.Color, pcs.Thickness, pcs.Parent = Color3.fromRGB(20, 60, 170), 2, HUD.PupCount
	UIKit.Text(pups, { Size = UDim2.new(1, -8, 0, 19), Position = UDim2.fromOffset(4, 36), Text = "Spirit Pups in camp", Font = UIKit.Fonts.Black, TextSize = 15, TextColor3 = Color3.fromRGB(215, 240, 255), TextXAlignment = Enum.TextXAlignment.Center })
	HUD.PupScale = Instance.new("UIScale")
	HUD.PupScale.Parent = pups
	HUD.PupLast = 0

	---------------------------------------------------------------- ล่าง: ทรัพยากร
	local strip = UIKit.Frame(gui, { Size = UDim2.new(0, 760, 0, 40), Position = UDim2.new(0.5, -380, 1, -172), BackgroundTransparency = 0.45 })
	UIKit.Corner(strip, 10)
	UIKit.Stroke(strip, C.GoldDim, 1, 0.6)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = strip
	HUD.Strip = strip
	local sackSlot = UIKit.Frame(strip, { Size = UDim2.fromOffset(84, 32), BackgroundColor3 = Color3.fromRGB(50, 40, 30), BackgroundTransparency = 0.2, LayoutOrder = -1 })
	UIKit.Corner(sackSlot, 6)
	HUD.SackLabel = UIKit.Text(sackSlot, { Size = UDim2.fromScale(1, 1), Text = "🎒 0/0", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center })
	HUD.Slots = {}
	for i, id in ipairs(STRIP) do
		local slot = UIKit.Frame(strip, { Size = UDim2.fromOffset(44, 32), BackgroundColor3 = Color3.fromRGB(30, 28, 32), BackgroundTransparency = 0.3, LayoutOrder = i })
		UIKit.Corner(slot, 6)
		ItemIcon.Make(slot, id, { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(2, 4) })
		local count = UIKit.Text(slot, { Size = UDim2.new(1, -4, 0, 14), Position = UDim2.fromOffset(0, 17), Text = "0", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.TextDim })
		slot.Visible = false
		HUD.Slots[id] = { Frame = slot, Count = count }
	end
	HUD.Hint = UIKit.Text(gui, {
		Size = UDim2.new(0.7, 0, 0, 20), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 15, -- กว้างตามจอ: ตัวหนังสือย่อเองไม่ล้น TextColor3 = C.Text,
		Text = "[Click] Hit/Chop   [Shift] Sprint   [Ctrl] Lock camera   [C] Craft   [B] Build   [E] Pick up (hold sack)   [F] Take out   [M] Map   [1-9] Select item",
		TextStrokeTransparency = 0.7,
	})

	---------------------------------------------------------------- แถบเลือดบอส (สไตล์ Souls)
	local boss = UIKit.Frame(top, { Size = UDim2.new(0, 720, 0, 62), Position = UDim2.new(0.5, -360, 0, 128), BackgroundTransparency = 1, Visible = false })
	HUD.BossName = UIKit.Text(boss, { Size = UDim2.new(1, 0, 0, 30), Font = UIKit.Fonts.Title, TextSize = 30, Text = "", TextColor3 = Color3.fromRGB(255, 120, 110), TextXAlignment = Enum.TextXAlignment.Center })
	HUD.BossBar = UIKit.Bar(boss, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 34), Color = Color3.fromRGB(230, 40, 56), Label = "" })
	HUD.BossFrame = boss

	---------------------------------------------------------------- แจ้งเตือน
	-- มือถือ: กล่องแจ้งเตือนเตี้ยลง/ขึ้นใกล้การ์ดกองไฟ ไม่ลงไปทับปุ่มมือถือมุมขวาล่าง
	local feed = UIKit.Frame(gui, {
		Size = UDim2.new(0, 540, 0, HUD.Touch and 150 or 220), AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, HUD.Touch and 178 or 198), BackgroundTransparency = 1, -- ใต้แถบวัน/เข็มทิศ/แถบเลือดบอส · กว้างไม่ชนการ์ดซ้าย
	})
	UIKit.AutoScale(feed, { maxW = 0.46, phoneMaxW = 0.54 })
	local fl = Instance.new("UIListLayout")
	fl.Padding = UDim.new(0, 4)
	fl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	fl.SortOrder = Enum.SortOrder.LayoutOrder
	fl.Parent = feed
	HUD.Feed = feed
	layoutTop() -- วางตำแหน่งแจ้งเตือนตามจอทันที (ไม่ต้องรอจอเปลี่ยนขนาด)
	-- มีป้ายใหญ่กลางจอ (Cinematics.Banner) = ซ่อนแถบข้อความชั่วคราว ไม่ให้ทับกัน
	player:GetAttributeChangedSignal("BannerUp"):Connect(function()
		feed.Visible = not player:GetAttribute("BannerUp")
		if not player:GetAttribute("BannerUp") and HUD.Pending then
			local pending = HUD.Pending
			HUD.Pending = nil
			for i = math.max(1, #pending - 1), #pending do -- ขึ้นแค่ 2 อันล่าสุด
				HUD.Notify(pending[i][1], pending[i][2])
			end
		end
	end)
	HUD.FeedOrder = 0

	-- ป๊อปอัปเก็บของ
	local touch = HUD.Touch
	local pick = UIKit.Frame(gui, {
		Size = UDim2.new(0, 220, 0, 200), AnchorPoint = touch and Vector2.new(0.5, 1) or Vector2.new(1, 1),
		Position = touch and UDim2.new(0.5, 0, 1, -110) or UDim2.new(1, -16, 1, -130), BackgroundTransparency = 1,
	})
	UIKit.AutoScale(pick)
	local pl = Instance.new("UIListLayout")
	pl.Padding = UDim.new(0, 4)
	pl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	pl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	pl.Parent = pick
	HUD.PickFeed = pick
	-- มือถือจอเตี้ย: ฟีดเก็บของโชว์ 2 แถวล่างสุด + ต่ำลงชิดแถบไอเทม -> ไม่ชนแจ้งเตือนกลางจอ
	local function layoutPick()
		local phone = UIKit.IsPhone()
		pick.ClipsDescendants = phone
		pick.Size = UDim2.new(0, 220, 0, phone and 64 or 200)
		if touch then
			pick.Position = UDim2.new(0.5, 0, 1, phone and -78 or -110)
		end
		UIKit.AutoScale(pick)
	end
	layoutPick()
	UIKit.OnResize(layoutPick)

	-- ล้ม
	HUD.DownedFrame = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(80, 0, 0), BackgroundTransparency = 0.7, Visible = false, ZIndex = 20 })
	HUD.DownedText = UIKit.Text(HUD.DownedFrame, {
		Size = UDim2.new(1, 0, 0, 90), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, 0), TextXAlignment = Enum.TextXAlignment.Center,
		Font = UIKit.Fonts.Title, TextSize = 32, Text = "", TextColor3 = Color3.fromRGB(255, 200, 190), ZIndex = 21,
	})
	UIKit.AutoScale(HUD.DownedText)
	-- คืนชีพ: มีตั๋ว = ใช้ตั๋ว · ไม่มี = ซื้อด้วย Robux (Config.ReviveProductId)
	HUD.ReviveBtn = UIKit.Button(HUD.DownedFrame, {
		Size = UDim2.fromOffset(300, 56), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, 100), Text = "",
		TextSize = 24, BackgroundColor3 = Color3.fromRGB(46, 160, 80), TextColor3 = Color3.new(1, 1, 1), ZIndex = 22, Visible = false,
	}, function()
		if (player:GetAttribute("ReviveTokens") or 0) > 0 then
			Remotes.Get("UseReviveToken"):FireServer()
		elseif (Config.ReviveProductId or 0) > 0 then
			game:GetService("MarketplaceService"):PromptProductPurchase(player, Config.ReviveProductId)
		end
	end)
	UIKit.AutoScale(HUD.ReviveBtn)
	HUD.RevivePrice = nil
	if (Config.ReviveAllProductId or 0) > 0 then
		task.spawn(function()
			local ok, info = pcall(game:GetService("MarketplaceService").GetProductInfo, game:GetService("MarketplaceService"), Config.ReviveAllProductId, Enum.InfoType.Product)
			HUD.ReviveAllPrice = ok and info and info.PriceInRobux or nil
		end)
	end
	if (Config.ReviveProductId or 0) > 0 then
		task.spawn(function()
			local ok, info = pcall(game:GetService("MarketplaceService").GetProductInfo, game:GetService("MarketplaceService"), Config.ReviveProductId, Enum.InfoType.Product)
			HUD.RevivePrice = ok and info and info.PriceInRobux or nil
		end)
	end

	-- ทีมล้มหมด (ทุกโหมด): หน้าต่างชุบ 30 วิ · ชุบตัวเอง = 1 ครั้ง · ชุบทั้งทีม = ราคา × จำนวนคนที่ล้ม/ตาย
	--   ซื้อแต่ละครั้งเซิร์ฟเวอร์ชุบคนถัดไป (MonetizationService reviveReceipt + attribute ReviveAll)
	local MPS = game:GetService("MarketplaceService")
	local function fallenCount()
		local n = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("InRun") and (p:GetAttribute("Downed") or p:GetAttribute("Dead")) then
				n += 1
			end
		end
		return n
	end
	HUD.FallenCount = fallenCount
	local wp = UIKit.Frame(gui, { Size = UDim2.fromOffset(560, 250), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.2, 0), BackgroundColor3 = Color3.fromRGB(40, 12, 12),
		BackgroundTransparency = 0.15, Visible = false, ZIndex = 40 })
	UIKit.Corner(wp, 14)
	UIKit.Stroke(wp, Color3.fromRGB(255, 120, 100), 3, 0)
	UIKit.AutoScale(wp, { maxW = 0.9 })
	HUD.WipePanel = wp
	HUD.WipeText = UIKit.Text(wp, { Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 10), Text = "", Font = UIKit.Fonts.Title, TextSize = 28, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(255, 210, 200), ZIndex = 41 })
	HUD.WipeMe = UIKit.Button(wp, { Size = UDim2.fromOffset(250, 60), Position = UDim2.new(0.5, -260, 0, 100), Text = "", TextSize = 21,
		BackgroundColor3 = Color3.fromRGB(46, 160, 80), TextColor3 = Color3.new(1, 1, 1), ZIndex = 42 }, function()
		if (player:GetAttribute("ReviveTokens") or 0) > 0 and player:GetAttribute("Downed") then
			Remotes.Get("UseReviveToken"):FireServer()
		elseif (Config.ReviveProductId or 0) > 0 then
			HUD.ReviveAllActive = false
			Remotes.Get("ReviveAllMode"):FireServer(false)
			MPS:PromptProductPurchase(player, Config.ReviveProductId)
		end
	end)
	HUD.WipeAll = UIKit.Button(wp, { Size = UDim2.fromOffset(250, 60), Position = UDim2.new(0.5, 10, 0, 100), Text = "", TextSize = 21,
		BackgroundColor3 = Color3.fromRGB(214, 150, 40), TextColor3 = Color3.new(1, 1, 1), ZIndex = 42 }, function()
		local n = fallenCount()
		if n > 0 and (Config.ReviveAllProductId or 0) > 0 then
			-- จ่ายทีเดียว (ราคาเดียว) ชุบทุกคน
			HUD.ReviveAllActive = false
			MPS:PromptProductPurchase(player, Config.ReviveAllProductId)
		elseif (Config.ReviveProductId or 0) > 0 and n > 0 then
			-- ยังไม่ได้ตั้งสินค้า: ซื้อทีละคนจนครบ
			HUD.ReviveAllActive = true
			Remotes.Get("ReviveAllMode"):FireServer(true)
			MPS:PromptProductPurchase(player, Config.ReviveProductId)
		end
	end)
	-- ไม่ชุบ กลับล็อบบี้ (ทั้งทีมกดครบ = จบทันที)
	HUD.WipeSkip = UIKit.Button(wp, { Size = UDim2.fromOffset(300, 48), Position = UDim2.new(0.5, -150, 0, 178), Text = "Back to Lobby", TextSize = 20,
		BackgroundColor3 = Color3.fromRGB(150, 50, 50), TextColor3 = Color3.new(1, 1, 1), ZIndex = 42 }, function()
		HUD.Skipped = true
		Remotes.Get("WipeSkip"):FireServer()
	end)
	-- ชุบทั้งทีม: ซื้อสำเร็จแล้วยังมีคนล้มอยู่ -> เด้งซื้อครั้งถัดไปเอง จนครบทุกคน (ยกเลิก = หยุด)
	MPS.PromptProductPurchaseFinished:Connect(function(_, productId, bought)
		if productId ~= Config.ReviveProductId or not HUD.ReviveAllActive then
			return
		end
		if bought then
			task.wait(1.5) -- รอเซิร์ฟเวอร์ชุบคนที่เพิ่งจ่าย
			if fallenCount() > 0 and HUD.ReviveAllActive then
				MPS:PromptProductPurchase(player, Config.ReviveProductId)
				return
			end
		end
		HUD.ReviveAllActive = false
		Remotes.Get("ReviveAllMode"):FireServer(false)
	end)

	-- อัปเดต HUD 30 ครั้ง/วินาที พอ (ไม่ต้องทุกเฟรม ลดภาระเครื่องอ่อน/มือถือ)
	local hudAcc = 0
	RunService.RenderStepped:Connect(function(dt)
		hudAcc += dt
		if hudAcc >= 1 / 30 then
			hudAcc = 0
			HUD.Update()
		end
	end)
	state:GetAttributeChangedSignal("Phase"):Connect(HUD.UpdateNightLabel)
	state:GetAttributeChangedSignal("Night"):Connect(HUD.UpdateNightLabel)
	-- วันโบนัสเพิ่ม: "xN" เด้งข้างเลขวัน แล้วพุ่งเข้าไปบวก · ได้ตอนกลางคืนก็บวกที่ตัวนับ xN ทันที
	-- (เลขวันจริงขยับตอนเช้า หลังบ้านนับเอง) · ตอนเช้าที่ของค้างถูกนับ (BonusSource = "Pending") ไม่เด้งซ้ำ
	local lastBonus = state:GetAttribute("BonusDays") or 0
	state:GetAttributeChangedSignal("BonusDays"):Connect(function()
		local now = state:GetAttribute("BonusDays") or 0
		local add = now - lastBonus
		lastBonus = now
		if add > 0 and player:GetAttribute("InRun") and state:GetAttribute("BonusSource") ~= "Pending" then
			HUD.HoldNight = state:GetAttribute("BonusFrom") or HUD.ShownNight -- ค้างเลขเดิมไว้จนเอฟเฟกต์บินถึง
			HUD.HoldTotal = HUD.ShownTotal
			HUD.BonusFly(add, state:GetAttribute("BonusSource"))
		elseif add > 0 and player:GetAttribute("InRun") then
			-- เช้า: วันที่ได้ตอนกลางคืนถูกนับเข้าเลขวันแล้ว -> เลขวันเด้ง (ไม่มีตัวเลขบินซ้ำ)
			HUD.NightPop.Scale = 1.4
			game:GetService("TweenService"):Create(HUD.NightPop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		HUD.UpdateNightLabel()
	end)
	local lastPending = state:GetAttribute("PendingDays") or 0
	state:GetAttributeChangedSignal("PendingDays"):Connect(function()
		lastPending = state:GetAttribute("PendingDays") or 0 -- (เตียงตอนกลางคืน: ข้ามตอนเช้า ไม่เกี่ยวกับตัวคูณ)
		HUD.UpdateNightLabel()
	end)
	HUD.UpdateNightLabel()
end

-- "xN" ตัวใหญ่ + ชื่อที่มา (เตียง/ลูกสัตว์) -> พุ่งเข้าเลขวัน แล้วปล่อยตัวเลขที่ค้างไว้ให้บวก
function HUD.BonusFly(n, source)
	local apply = true
	local gui = HUD.Gui
	-- โผล่ข้างขวาของ DAY XX (บนจอว่าง ไม่ทับป้ายแจ้งเตือนกลางจอ) แล้วพุ่งเข้าเลขวัน
	local nl = HUD.NightLabel
	local mid = nl.AbsolutePosition + nl.AbsoluteSize / 2 - gui.AbsolutePosition -- พิกัดในกรอบ HUD เอง (ไม่ต้องคิดแถบบนของ Roblox)
	local right = mid.X + nl.TextBounds.X / 2
	local holder = UIKit.Frame(gui, {
		Size = UDim2.fromOffset(150, 84), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(right + 40, mid.Y + 14),
		BackgroundTransparency = 1, ZIndex = 50,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = holder
	local big = UIKit.Text(holder, {
		Size = UDim2.new(1, 0, 0, 60), Font = UIKit.Fonts.Title, TextSize = 60, TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format("x%d", n), TextColor3 = apply and Color3.fromRGB(110, 255, 140) or C.Gold, ZIndex = 51,
	})
	big:SetAttribute("NoTranslate", true)
	local sub = UIKit.Text(holder, {
		Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 60), Font = UIKit.Fonts.Black, TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left, Text = (source and source ~= "") and source or "Bed", TextColor3 = C.Text, ZIndex = 51,
	})
	local TweenService = game:GetService("TweenService")
	pcall(SoundController.Play, "Reward")
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.1, function()
		-- พุ่งเข้าท้ายข้อความ DAY XX
		local ti = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(holder, ti, { Position = UDim2.fromOffset(right - 30, mid.Y) }):Play()
		TweenService:Create(big, ti, { TextTransparency = 0.6 }):Play()
		TweenService:Create(scale, ti, { Scale = 0.3 }):Play()
		TweenService:Create(sub, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		holder:Destroy()
		if apply then
			HUD.HoldNight = nil
			HUD.HoldTotal = nil
			HUD.UpdateNightLabel()
			-- เลขวันเด้ง = บวกแล้ว
			HUD.NightPop.Scale = 1.4
			TweenService:Create(HUD.NightPop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)
	-- กันค้าง: ถ้าเอฟเฟกต์พัง เลขวันต้องกลับมาตรง
	task.delay(3, function()
		if HUD.HoldNight or HUD.HoldTotal then
			HUD.HoldNight = nil
			HUD.HoldTotal = nil
			HUD.UpdateNightLabel()
		end
	end)
end

local Loc -- Localizer (โหลดตอนใช้ครั้งแรก) · ข้อความ DAY แปลเองก่อนต่อวันโบนัส
function HUD.UpdateNightLabel()
	if not player:GetAttribute("InRun") then
		return
	end
	if Loc == nil then
		local ok, m = pcall(require, script.Parent.Localizer)
		Loc = ok and m or false
		if Loc then
			Loc.OnChanged(HUD.UpdateNightLabel)
		end
	end
	local s = HUD.State
	local night = HUD.HoldNight or s:GetAttribute("Night") or 1
	HUD.ShownNight = night
	local phase = s:GetAttribute("Phase") or "Day"
	local base
	if phase == "Night" then
		base = string.format("NIGHT %d", night)
		HUD.NightLabel.TextColor3 = s:GetAttribute("BloodMoon") and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(170, 190, 255)
	else
		base = string.format("DAY %d", night)
		HUD.NightLabel.TextColor3 = C.Gold
	end
	if Loc then
		base = Loc.Translate(base)
	end
	-- วันโบนัสรวมของรอบนี้ = นับแล้ว + ที่รอเลขวันขยับตอนเช้า (ผู้เล่นเห็นตัวเดียว ไม่มีวงเล็บ)
	-- ระหว่างตัวเลขกำลังบิน ค้างยอดเดิมไว้ก่อน
	local total = HUD.HoldTotal or (s:GetAttribute("BonusDays") or 0)
	HUD.ShownTotal = total
	if total > 0 then
		base ..= string.format(' <font color="#6EFF8C" size="32">(x%d)</font>', total) -- ตัวคูณวัน: ทุกเช้าเลขวันเดิน xN
	end
	HUD.NightLabel.Text = base
end

local lastPOI = 0
function HUD.Update()
	local s = HUD.State
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local hf = hum.Health / math.max(hum.MaxHealth, 1)
		HUD.HealthBar.Set(hf, string.format("%d / %d", math.ceil(hum.Health), math.ceil(hum.MaxHealth)))
		-- เลือดต่ำ: ไอคอนกระพริบแดง
		local pulse = hf < 0.3 and (0.5 + 0.5 * math.sin(os.clock() * 8)) or 0
		HUD.HealthBar.BadgeStroke.Thickness = 1.5 + pulse * 2
		HUD.HealthBar.Badge.BackgroundColor3 = C.Health:Lerp(Color3.new(0, 0, 0), 0.55 - pulse * 0.4)
	end
	local hunger = player:GetAttribute("Hunger") or 100
	HUD.HungerBar.Set(hunger / Config.HungerMax, hunger < 25 and "Starving!" or string.format("%d%%", math.floor(hunger / Config.HungerMax * 100 + 0.5)))
	HUD.StaminaBar.Set((HUD.Stamina or 100) / 100)
	local air, airMax = player:GetAttribute("Air"), player:GetAttribute("AirMax") or Config.BreathMax
	local diving = air ~= nil and air < airMax - 0.01 and player:GetAttribute("InRun") == true
	HUD.AirBar.Holder.Visible = diving
	if diving then
		HUD.AirBar.Set(air / airMax, air <= 0 and "🫧 Drowning!" or string.format("🫧 %ds", math.ceil(air)))
		local st = HUD.AirBar.Holder:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = air < 5 and Color3.fromRGB(255, 70, 70):Lerp(Color3.new(), 0.5 - 0.5 * math.sin(os.clock() * 10)) or UIKit.Colors.Outline
		end
	end
	local cls = player:GetAttribute("Class")
	local lv = player:GetAttribute("ClassLevel")
	local cdef = cls and Classes.Data[cls]
	local cname = cdef and cdef.Name or cls -- ชื่อที่แสดง (รหัส "Sage" = พงไพร)
	HUD.ClassLabel.Text = cname and (string.upper(cname) .. (lv and ("  ·  Lv." .. lv) or "")) or "SURVIVOR"

	-- เวลา
	local now = Workspace:GetServerTimeNow()
	local phase = s:GetAttribute("Phase") or "Day"
	local pStart, pEnd = s:GetAttribute("PhaseStart") or now, s:GetAttribute("PhaseEnd") or now
	local frac = math.clamp((now - pStart) / math.max(pEnd - pStart, 0.01), 0, 1)
	local remain = pEnd - now
	local inLobby = not player:GetAttribute("InRun")
	if HUD.FireLabel then
		HUD.FireLabel.Parent.Visible = not inLobby
	end
	-- ล็อบบี้: หน้าจอโล่ง (ซ่อนแถบเลือด/เข็มทิศ/กระเป๋า)
	HUD.HealthBar.Holder.Parent.Visible = not inLobby
	HUD.Compass.Visible = not inLobby
	HUD.TimeFill.Parent.Visible = not inLobby
	HUD.Strip.Visible = false -- ไม่มีแถบนับของ: ของทั้งหมดอยู่ในกระสอบ
	-- คำแนะนำด้านล่าง: ในแมพโชว์แค่ 60 วิแรก แล้วซ่อน (ล็อบบี้โชว์ตลอด)
	if inLobby then
		HUD.HintSince = nil
	elseif not HUD.HintSince then
		HUD.HintSince = os.clock()
	end
	-- คอมในแมพ: ใช้แผงปุ่มลัดมุมขวาล่าง (KeyHints) แทนบรรทัดนี้
	HUD.Hint.Visible = HUD.ShowHints ~= false and (inLobby or (HUD.Touch and os.clock() - HUD.HintSince < 60))
		and not (UIKit.IsPhone() and HUD.PickFeed and #HUD.PickFeed:GetChildren() > 1) -- มือถือ: มีป๊อปอัปเก็บของอยู่ = หลบให้
	local big = UIKit.BigScale()
	HUD.Hint.Position = UDim2.new(0.5, 0, 1, inLobby and -16 or -86 * big) -- ในแมพ: อยู่เหนือแถบไอเทมของ Roblox
	-- มือถือ: แคบพอให้อยู่ระหว่างจอยสติ๊ก (ซ้าย ~210) กับปุ่ม Lock/Sprint/กระโดด (ขวา ~220) · ตัดเป็น 2 บรรทัด
	local phone = UIKit.IsPhone()
	HUD.Hint.Size = phone and UDim2.new(0, math.max(170, UIKit.Viewport().X - 440), 0, 34 * big) or UDim2.new(0.7, 0, 0, 20 * big)
	HUD.Hint.TextWrapped = phone
	HUD.Hint.TextSize = (phone and 13 or 15) * big
	if inLobby then
		HUD.NightLabel.Text = "WILDHEART CAMP"
		HUD.NightLabel.TextColor3 = C.Gold
		local cd = s:GetAttribute("PortalCountdown") or -1
		if not s:GetAttribute("Ready") then
			HUD.PhaseLabel.Text = UIKit.StripIcons(string.format("Generating world %d%%", math.floor((s:GetAttribute("LoadProgress") or 0) * 100)))
		elseif cd >= 0 then
			HUD.PhaseLabel.Text = UIKit.StripIcons(string.format("Team of %d · Departing in %ds", s:GetAttribute("PortalCount") or 0, cd))
		elseif phase == "Lobby" then
			HUD.PhaseLabel.Text = UIKit.StripIcons("Step on a start pad on your right")
		else
			HUD.PhaseLabel.Text = UIKit.StripIcons(string.format("Team is on night %d · Step on a pad to join", s:GetAttribute("Night") or 1))
		end
		HUD.Hint.Text = HUD.Touch and "Tent = Classes · Green cauldron = Daily reward"
			or "[K] Class Shop   ·   Green cauldron = Daily reward   ·   Step on a pad to start"
		HUD.TimeFill.Size = UDim2.fromScale(0, 1)
	elseif phase == "Day" then
		HUD.PhaseLabel.Text = UIKit.StripIcons(string.format("Day · Dusk in %s", fmtTime(remain)))
		HUD.TimeIcon.Text = "☀"
		HUD.TimeFill.BackgroundColor3 = C.Gold
	elseif phase == "Dusk" then
		HUD.PhaseLabel.Text = UIKit.StripIcons(string.format("Dusk · Animals coming in %s", fmtTime(remain)))
		HUD.TimeIcon.Text = "🌅"
		HUD.TimeFill.BackgroundColor3 = C.Fire
	elseif phase == "Night" then
		local el = s:GetAttribute("NightElement") or "Earth"
		local bossHold = (s:GetAttribute("BossHoldEnd") or 0) - now
		if bossHold > 0 then
			HUD.PhaseLabel.Text = UIKit.StripIcons(string.format("Boss still alive · Dawn in %s", fmtTime(bossHold)))
		else
			HUD.PhaseLabel.Text = UIKit.StripIcons(string.format("Night of %s · Dawn in %s", UIKit.ElementThai[el] or "", fmtTime(remain)))
		end
		HUD.TimeIcon.Text = s:GetAttribute("BloodMoon") and "🔴" or "🌙"
		HUD.TimeFill.BackgroundColor3 = UIKit.Colors.Element[el] or C.Gold
	elseif phase == "Loading" then
		HUD.PhaseLabel.Text = UIKit.StripIcons("Generating world...")
	else
		HUD.PhaseLabel.Text = UIKit.StripIcons("")
	end
	if not inLobby then
		HUD.TimeFill.Size = UDim2.fromScale(frac, 1)
		HUD.Hint.Text = HUD.Touch and "Tap screen = hit · Bag is in the top-left corner"
			or "[Click] Hit   [Shift] Sprint   [C] Craft   [E] Pick up   [Tab] Sack   [M] Map"
	end
	HUD.TimeIcon.Position = UDim2.new(frac, -10, 0.5, -10)

	-- กองไฟ
	local lvl = s:GetAttribute("CampLevel") or 1
	local fuel, maxFuel = s:GetAttribute("CampFuel") or 0, s:GetAttribute("CampMaxFuel") or 1
	HUD.FireLabel.Text = string.format("Campfire Lv.%d  ·  Bench Lv.%d", lvl, s:GetAttribute("BenchLevel") or 1)
	HUD.UpdateFuel(fuel, maxFuel, inLobby, phase)
	for id, l in pairs(HUD.StockLabels or {}) do
		local n = s:GetAttribute("Stock" .. id) or 0
		l.Text = n >= 1000 and string.format("%.1fk", n / 1000) or tostring(n)
		l.TextColor3 = n > 0 and C.Text or C.TextDim
	end
	local campPos = s:GetAttribute("CampPos")
	local safe = s:GetAttribute("CampSafeRadius") or 0
	if campPos and char then
		local d = ((char:GetPivot().Position - campPos) * Vector3.new(1, 0, 1)).Magnitude
		if fuel <= 0 then
			HUD.SafeLabel.Text = UIKit.StripIcons("Fire is out! Not safe")
			HUD.SafeLabel.TextColor3 = C.Bad
		elseif d < safe then
			HUD.SafeLabel.Text = "In the firelight"
			HUD.SafeLabel.TextColor3 = C.Good
		else
			HUD.SafeLabel.Text = UIKit.StripIcons(string.format("%d m from the campfire", math.floor(d * 0.28)))
			HUD.SafeLabel.TextColor3 = C.TextDim
		end
	end
	local pupCount = 0
	for el, orb in pairs(HUD.SpiritOrbs) do
		local rescued = s:GetAttribute("Spirit" .. el)
		pupCount += rescued and 1 or 0
		orb.Frame.BackgroundColor3 = rescued and C.Element[el] or Color3.fromRGB(50, 50, 56)
		orb.Icon.TextTransparency = rescued and 0 or 0.6
	end
	HUD.PupCount.Text = pupCount .. "/4"
	if pupCount > HUD.PupLast then
		-- ได้ลูกสัตว์เพิ่ม: ป้ายเด้ง
		HUD.PupScale.Scale = 1.25
		TweenService:Create(HUD.PupScale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	HUD.PupLast = pupCount
	HUD.DiamondLabel.Text = tostring(player:GetAttribute("Diamonds") or 0)

	-- บอส
	-- หลอดเลือดบอส = บอสตัวที่ใกล้เราที่สุด (ระยะ 350) อ่านเลือดจากตัวบอสเอง
	--   (เดิมใช้ค่า BossHP ตัวเดียวทั้งเซิร์ฟ -> บอสหลายตัว/บอสตื่นใหม่/บอสฟื้นเลือด เขียนทับกัน หลอดเลยกระโดดเต็ม-ลด)
	local boss, bestD = nil, 350
	if player:GetAttribute("InRun") then
		local animals = Workspace:FindFirstChild("Animals")
		local myPos = player.Character and player.Character:GetPivot().Position
		for _, m in ipairs(myPos and animals and animals:GetChildren() or {}) do
			if m:GetAttribute("IsBoss") and not m:GetAttribute("Dead") and (m:GetAttribute("Health") or 0) > 0 and Animals.Data[m.Name] then
				local d = (m:GetPivot().Position - myPos).Magnitude
				if d < bestD then
					boss, bestD = m, d
				end
			end
		end
	end
	if boss then
		local frac = (boss:GetAttribute("Health") or 0) / math.max(boss:GetAttribute("MaxHealth") or 1, 1)
		if boss ~= HUD.BossTarget or not HUD.BossFrame.Visible then
			HUD.BossTarget = boss
			HUD.BossBar.Snap(frac) -- เปลี่ยนตัว/เพิ่งโผล่ = ตั้งหลอดทันที ไม่ไล่จากค่าของตัวก่อน
		else
			HUD.BossBar.Set(frac)
		end
		HUD.BossFrame.Visible = true
		HUD.BossName.Text = Animals.Data[boss.Name].Name
	else
		HUD.BossTarget = nil
		HUD.BossFrame.Visible = false
	end

	-- ล้ม
	local downed = player:GetAttribute("Downed")
	HUD.DownedFrame.Visible = downed == true
	if downed then
		local text = "Down — wait for a teammate to help"
		local wipeAt = s:GetAttribute("WipeAt")
		if wipeAt then
			text = string.format("Whole team is down — game over in %ds", math.max(0, math.ceil(wipeAt - Workspace:GetServerTimeNow())))
		end
		HUD.DownedText.Text = text
		local tokens = player:GetAttribute("ReviveTokens") or 0
		local canBuy = (Config.ReviveProductId or 0) > 0
		HUD.ReviveBtn.Visible = (tokens > 0 or canBuy) and not wipeAt -- ทีมล้มหมด = ใช้หน้าต่างชุบด้านบนแทน
		HUD.ReviveBtn.Text = tokens > 0 and string.format("Use Revive Ticket (%d)", tokens)
			or ("Revive Now  " .. utf8.char(0xE002) .. " " .. tostring(HUD.RevivePrice or 79))
	end
	-- หน้าต่างชุบตอนทีมล้มหมด (เห็นทั้งคนล้มและคนที่ตายไปแล้วในรอบ)
	local wipeAt2 = s:GetAttribute("WipeAt")
	local showWipe = wipeAt2 ~= nil and player:GetAttribute("InRun") == true and (Config.ReviveProductId or 0) > 0
	HUD.WipePanel.Visible = showWipe
	if showWipe then
		local left = math.max(0, math.ceil(wipeAt2 - Workspace:GetServerTimeNow()))
		local n = HUD.FallenCount()
		local price = HUD.RevivePrice or 79
		local R = utf8.char(0xE002)
		HUD.WipeText.Text = string.format("💀 The whole team is down — %ds to revive", left)
		local fallen = player:GetAttribute("Downed") or player:GetAttribute("Dead")
		local tokens = player:GetAttribute("ReviveTokens") or 0
		HUD.WipeMe.Visible = fallen == true
		HUD.WipeMe.Text = (tokens > 0 and player:GetAttribute("Downed")) and string.format("Revive Me (Ticket %d)", tokens) or ("Revive Me  " .. R .. " " .. price)
		local allPrice = (Config.ReviveAllProductId or 0) > 0 and (HUD.ReviveAllPrice or Config.ReviveAllRobux or 129) or price * n
		HUD.WipeAll.Text = string.format("Revive All (%d)  %s %d", n, R, allPrice)
		local team = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("InRun") then
				team += 1
			end
		end
		HUD.WipeSkip.Text = HUD.Skipped and team > 1 and string.format("Waiting for team (%d/%d)", s:GetAttribute("WipeSkips") or 0, team) or "Back to Lobby"
	elseif HUD.Skipped then
		HUD.Skipped = nil
	end

	-- เข็มทิศ
	local cam = Workspace.CurrentCamera
	local look = cam.CFrame.LookVector
	local heading = math.atan2(look.X, -look.Z)
	local width = HUD.Compass.AbsoluteSize.X
	local function place(label, angle)
		local diff = (angle - heading + math.pi) % (2 * math.pi) - math.pi
		local x = 0.5 + diff / math.rad(150)
		label.Visible = x > -0.05 and x < 1.05
		label.Position = UDim2.new(x, -label.AbsoluteSize.X / 2, 0, 0)
	end
	for _, m in ipairs(HUD.CompassMarks) do
		place(m.Label, m.Angle)
	end
	if os.clock() - lastPOI > 0.5 then
		lastPOI = os.clock()
		HUD.RefreshPOI()
	end
	if char then
		local pos = char:GetPivot().Position
		for _, poi in pairs(HUD.CompassPOI) do
			local d = poi.Position - pos
			place(poi.Label, math.atan2(d.X, -d.Z))
			local dist = (d * Vector3.new(1, 0, 1)).Magnitude
			poi.Label.Text = poi.Icon .. (dist > 60 and string.format(" %dm", math.floor(dist * 0.28)) or "")
		end
		for p, mark in pairs(HUD.TeamMarks) do
			local tp = HUD.TeammatePos(p)
			if tp and not p:GetAttribute("Dead") then
				local d = tp - pos
				place(mark.Label, math.atan2(d.X, -d.Z))
				mark.Label.Text = string.format("● %s %dm", mark.Short, math.floor((d * Vector3.new(1, 0, 1)).Magnitude * 0.28))
			else
				mark.Label.Visible = false
			end
		end
	end
	if os.clock() - (HUD.LastTeam or 0) > 0.25 then
		HUD.LastTeam = os.clock()
		HUD.UpdateTeam(inLobby, now)
	end
	local _ = width
end

---------------------------------------------------------------- กองไฟ: วงแหวนเชื้อเพลิง + เวลาที่เหลือ + เตือนเชื้อเพลิงต่ำ
local GREEN, YELLOW, RED = Color3.fromRGB(96, 230, 110), Color3.fromRGB(255, 214, 60), Color3.fromRGB(255, 70, 60)
local function fuelColor(frac)
	if frac >= 0.5 then
		return YELLOW:Lerp(GREEN, (frac - 0.5) / 0.5)
	end
	return RED:Lerp(YELLOW, math.max(frac, 0) / 0.5)
end
HUD.FuelColor = fuelColor

function HUD.UpdateFuel(fuel, maxFuel, inLobby, phase)
	local frac = math.clamp(fuel / math.max(maxFuel, 1), 0, 1)
	local col = fuelColor(frac)
	local low = frac < 0.2 and fuel > 0
	local pulse = low and (0.5 + 0.5 * math.sin(os.clock() * 7)) or 0
	local lit = math.ceil(frac * #HUD.FuelSegs - 0.001)
	for i, seg in ipairs(HUD.FuelSegs) do
		if i <= lit then
			seg.BackgroundColor3 = col
			seg.BackgroundTransparency = low and 0.35 * pulse or 0
		else
			seg.BackgroundColor3 = Color3.fromRGB(46, 46, 58)
			seg.BackgroundTransparency = 0.25
		end
	end
	HUD.FireIconScale.Scale = 1 + 0.14 * pulse
	-- เวลาที่เหลือโดยประมาณ (จากอัตรากินเชื้อเพลิงจริงที่เซิร์ฟเวอร์ส่งมา)
	local drain = HUD.State:GetAttribute("CampDrain") or 0
	local est = ""
	if fuel > 0 and drain > 0 then
		est = "  ⏱ ~" .. fmtTime(fuel / drain)
	end
	HUD.FuelText.Text = fuel <= 0 and "Fire's out!" or (string.format("%d%%", math.floor(frac * 100 + 0.5)) .. est)
	HUD.FuelText.TextColor3 = fuel <= 0 and C.Bad or col
	-- เตือนครั้งเดียวต่อการลดลงต่ำกว่า 20% (เติมกลับถึง 25% ค่อยเตือนใหม่ได้)
	local active = not inLobby and (phase == "Day" or phase == "Dusk" or phase == "Night")
	if low and active and HUD.FuelLowArmed then
		HUD.FuelLowArmed = false
		SoundController.Play("FireLow")
		HUD.Notify(string.format("🔥 The fire is dying! About %s left — throw wood/coal in, quick", drain > 0 and fmtTime(fuel / drain) or "a few minutes"), "Warn")
	elseif frac >= 0.25 or not active then
		HUD.FuelLowArmed = true
	end
end

---------------------------------------------------------------- เพื่อนร่วมทีม
local TEAM_COLORS = {
	Color3.fromRGB(120, 210, 255), Color3.fromRGB(255, 170, 90), Color3.fromRGB(170, 255, 120), Color3.fromRGB(255, 130, 200),
	Color3.fromRGB(200, 160, 255), Color3.fromRGB(255, 230, 110), Color3.fromRGB(120, 255, 220),
}
local MAX_TEAM_ROWS = 7

-- ตำแหน่งเพื่อน: ตัวละครที่โหลดถึงเครื่องเรา หรือพิกัดคร่าวๆ ที่เซิร์ฟเวอร์ส่งมา (เพื่อนอยู่ไกล)
function HUD.TeammatePos(p)
	local c = p.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position
	end
	return p:GetAttribute("RunPos")
end

local function shortName(name)
	local len = utf8.len(name)
	if len and len > 10 then
		local cut = utf8.offset(name, 10)
		return cut and (name:sub(1, cut - 1) .. "…") or name
	end
	return name
end

local function makeTeamRow(p, color)
	local row = UIKit.Frame(HUD.TeamFrame, { Size = UDim2.fromOffset(236, 30), BackgroundColor3 = Color3.fromRGB(20, 22, 40), BackgroundTransparency = 0.3 })
	UIKit.Corner(row, 8)
	UIKit.Stroke(row, C.Outline, 2, 0.2)
	local icon = UIKit.Text(row, { Size = UDim2.fromOffset(24, 30), Position = UDim2.fromOffset(4, 0), Text = "❤", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center })
	local name = UIKit.Text(row, { Size = UDim2.fromOffset(104, 30), Position = UDim2.fromOffset(30, 0), Text = shortName(p.DisplayName), TextSize = 14, Font = UIKit.Fonts.Black, TextColor3 = color })
	local bar = UIKit.Bar(row, { Size = UDim2.fromOffset(92, 12), Position = UDim2.fromOffset(138, 9), Color = C.Health, Label = "" })
	local status = UIKit.Text(row, {
		Size = UDim2.fromOffset(92, 30), Position = UDim2.fromOffset(138, 0), Text = "", TextSize = 13, Font = UIKit.Fonts.Black, TextXAlignment = Enum.TextXAlignment.Center, Visible = false, ZIndex = 4,
	})
	local mark = UIKit.Text(HUD.Compass, { Size = UDim2.fromOffset(96, 26), TextSize = 12, Font = UIKit.Fonts.Black, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, Text = "" })
	return { Row = row, Icon = icon, Name = name, Bar = bar, Status = status, Mark = mark, Health = 1 }
end

function HUD.UpdateTeam(inLobby, now)
	local mates = {}
	if not inLobby then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and p:GetAttribute("InRun") then
				table.insert(mates, p)
			end
		end
	end
	table.sort(mates, function(a, b)
		return a.DisplayName:lower() < b.DisplayName:lower()
	end)
	local keep = {}
	for i, p in ipairs(mates) do
		if i > MAX_TEAM_ROWS then
			break
		end
		keep[p] = true
		local r = HUD.TeamRows[p]
		if not r then
			r = makeTeamRow(p, TEAM_COLORS[(p.UserId % #TEAM_COLORS) + 1])
			HUD.TeamRows[p] = r
			HUD.TeamMarks[p] = { Label = r.Mark, Short = shortName(p.DisplayName) }
		end
		r.Row.LayoutOrder = i
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			r.Health = hum.Health / math.max(hum.MaxHealth, 1)
		end
		local dead, downed = p:GetAttribute("Dead") == true, p:GetAttribute("Downed") == true
		if dead then
			r.Icon.Text = "💀"
			r.Status.Text = "Dead"
			r.Status.TextColor3 = C.TextDim
		elseif downed then
			r.Icon.Text = "🩸"
			r.Status.Text = "Down! Waiting for help"
			r.Status.TextColor3 = (math.floor(os.clock() * 3) % 2 == 0) and C.Bad or Color3.fromRGB(255, 220, 200)
		else
			r.Icon.Text = "❤"
			r.Bar.Set(r.Health)
		end
		r.Status.Visible = dead or downed
		r.Bar.Holder.Visible = not (dead or downed)
		r.Row.BackgroundColor3 = downed and Color3.fromRGB(90, 20, 26) or Color3.fromRGB(20, 22, 40)
		r.Name.TextTransparency = dead and 0.45 or 0
	end
	for p, r in pairs(HUD.TeamRows) do
		if not keep[p] then
			r.Row:Destroy()
			r.Mark:Destroy()
			HUD.TeamRows[p] = nil
			HUD.TeamMarks[p] = nil
		end
	end
	HUD.TeamFrame.Visible = next(HUD.TeamRows) ~= nil
end

-- จุดสำคัญบนเข็มทิศ
function HUD.RefreshPOI()
	local s = HUD.State
	local wanted = {}
	local camp = s:GetAttribute("CampPos")
	if camp then
		wanted.Camp = { Position = camp, Icon = "🔥", Color = C.Fire }
	end
	for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		local shrine = s:GetAttribute("Shrine_" .. el)
		if shrine and not s:GetAttribute("Spirit" .. el) and (HUD.Discovered and HUD.Discovered["Shrine_" .. el]) then
			wanted["Shrine_" .. el] = { Position = shrine, Icon = "⛩" .. UIKit.ElementIcon[el], Color = C.Element[el] }
		end
		local lair = s:GetAttribute("Lair_" .. el)
		if lair and not s:GetAttribute("Lair" .. el .. "Cleared") and (HUD.Discovered and HUD.Discovered["Lair_" .. el]) then
			wanted["Lair_" .. el] = { Position = lair, Icon = "💀", Color = C.Element[el] }
		end
	end
	-- จุดชั่วคราวจากระบบอื่น (เช่น ปิงของเพื่อน): HUD.ExtraPOI[key] = { Position, Icon, Color, Expire = os.clock() }
	for key, w in pairs(HUD.ExtraPOI) do
		if w.Expire and w.Expire < os.clock() then
			HUD.ExtraPOI[key] = nil
		else
			wanted[key] = w
		end
	end
	for key, poi in pairs(HUD.CompassPOI) do
		if wanted[key] then
			poi.Position = wanted[key].Position
		end
		if not wanted[key] then
			poi.Label:Destroy()
			HUD.CompassPOI[key] = nil
		end
	end
	for key, w in pairs(wanted) do
		if not HUD.CompassPOI[key] then
			local label = UIKit.Text(HUD.Compass, { Size = UDim2.fromOffset(64, 26), TextSize = 13, TextColor3 = w.Color, TextXAlignment = Enum.TextXAlignment.Center, Text = w.Icon })
			HUD.CompassPOI[key] = { Label = label, Position = w.Position, Icon = w.Icon }
		end
	end
end

-- กระสอบ: ใช้ไป/ความจุ (แดงเมื่อเต็ม)
function HUD.SetSack(used, cap)
	if not HUD.SackLabel then
		return
	end
	HUD.SackLabel.Text = cap > 0 and string.format("🎒 %d/%d", used, cap) or "🎒 No sack"
	HUD.SackLabel.TextColor3 = (cap > 0 and used >= cap) and Color3.fromRGB(255, 110, 100) or Color3.fromRGB(240, 226, 190)
end

-- อาหารที่ควรกินก่อน: อิ่มมากสุด (เนื้อดิบไว้ท้ายสุด เพราะเสียเลือด)
local function bestFood(inv)
	local best, bestScore
	for id, n in pairs(inv) do
		local item = Items.Data[id]
		if n > 0 and item and item.Category == "Food" then
			local score = (item.Food or 0) + ((item.Heal or 0) < 0 and -1000 or 0)
			if not bestScore or score > bestScore then
				best, bestScore = id, score
			end
		end
	end
	return best
end

function HUD.SetInventory(inv)
	HUD.Inventory = inv
	HUD.EatId = bestFood(inv)
	if HUD.EatBtn then
		HUD.EatBtn.Visible = HUD.EatId ~= nil
		HUD.EatBtn.Text = HUD.EatId and "🍖 Eat" or ""
		HUD.HungerBar.Holder.Size = UDim2.fromOffset(HUD.EatId and 160 or 222, 18)
	end
	for id, slot in pairs(HUD.Slots) do
		local n = inv[id] or 0
		slot.Count.Text = tostring(n)
		slot.Frame.Visible = n > 0 or id == "Wood" or id == "Stone"
	end
end

local KIND_COLOR = {
	Info = Color3.fromRGB(240, 236, 224), Good = Color3.fromRGB(150, 245, 165), Reward = Color3.fromRGB(255, 220, 120),
	Warn = Color3.fromRGB(255, 190, 95), Danger = Color3.fromRGB(255, 104, 92), Error = Color3.fromRGB(255, 136, 124),
}
local GOLD = Color3.fromRGB(236, 196, 112)
-- แถบจางหัวท้าย (ตรงกลางเข้ม -> ขอบใส)

-- แจ้งเตือนกลางจอ (สไตล์เกมเอาชีวิตรอด): ตัวหนังสือใหญ่ขอบเข้ม สีตามประเภท ไม่มีไอคอน/แถบ/เส้น · ขึ้นแล้วค่อยจางหาย
function HUD.Notify(text, kind)
	if not HUD.Feed then
		return
	end
	kind = KIND_COLOR[kind] and kind or "Info"
	-- มีป้ายใหญ่อยู่ = เก็บไว้ก่อน แล้วค่อยขึ้นตอนป้ายหาย (ไม่ทับป้าย และไม่หมดเวลาไปตอนถูกซ่อน)
	if player:GetAttribute("BannerUp") then
		HUD.Pending = HUD.Pending or {}
		table.insert(HUD.Pending, { text, kind })
		return
	end
	-- ข้อความเดิมซ้ำภายใน 4 วิ = ไม่ขึ้นซ้ำ
	HUD.LastNotify = HUD.LastNotify or {}
	if HUD.LastNotify[text] and os.clock() - HUD.LastNotify[text] < 4 then
		return
	end
	HUD.LastNotify[text] = os.clock()
	local col = KIND_COLOR[kind]
	local big = kind == "Danger" or kind == "Reward"
	HUD.FeedOrder += 1
	local slot = UIKit.Frame(HUD.Feed, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = HUD.FeedOrder })
	local band = UIKit.Frame(slot, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 60)
	pad.PaddingRight = UDim.new(0, 60)
	pad.Parent = band
	local label = UIKit.Text(band, {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = big and 25 or 21, Font = UIKit.Fonts.Black, Text = UIKit.StripIcons(text), TextColor3 = col, TextTransparency = 1,
	})
	UIKit.TextStroke(label, 2.4, 0.05)
	local sc = Instance.new("UIScale")
	sc.Scale = 1.25
	sc.Parent = slot
	UIKit.Tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	UIKit.Tween(label, 0.25, { TextTransparency = 0 })
	-- เก็บไว้แค่ไม่กี่อันล่าสุด
	local children = {}
	for _, c in ipairs(HUD.Feed:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(children, c)
		end
	end
	if #children > (HUD.Touch and 2 or 3) then
		table.sort(children, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		children[1]:Destroy()
	end
	task.delay(big and 4.5 or 3.5, function()
		if slot.Parent then
			UIKit.Tween(label, 0.6, { TextTransparency = 1 })
			UIKit.Tween(band, 0.6, { BackgroundTransparency = 1 })
			for _, d in ipairs(band:GetDescendants()) do
				if d:IsA("Frame") then
					UIKit.Tween(d, 0.6, { BackgroundTransparency = 1 })
				elseif d:IsA("UIStroke") then
					UIKit.Tween(d, 0.6, { Transparency = 1 })
				end
			end
			task.wait(0.65)
			slot:Destroy()
		end
	end)
end

function HUD.Pickup(id, n, stored)
	if not HUD.PickFeed then
		return
	end
	-- ไม่มีกรอบ/พื้นหลัง: ตัวหนังสือลอยพร้อมขอบดำให้อ่านออกบนทุกฉาก
	local f = UIKit.Frame(HUD.PickFeed, { Size = UDim2.fromOffset(210, 28), BackgroundTransparency = 1 })
	local sc = Instance.new("UIScale")
	sc.Scale = 0.5
	sc.Parent = f
	UIKit.Tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	local item = Items.Data[id]
	UIKit.Text(f, {
		Size = UDim2.new(1, -36, 1, 0), TextSize = 19, Font = UIKit.Fonts.Black, TextXAlignment = Enum.TextXAlignment.Right,
		Text = string.format(stored and "%d %s → Camp" or "+%d %s", n, Items.DisplayName(id)), TextColor3 = item and item.Color or C.Text,
	})
	-- รูปไอเทมจริงทางขวา (แทนอีโมจิ)
	ItemIcon.Make(f, id, { Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -2, 0.5, 0) })
	task.delay(2.5, function()
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("ViewportFrame") then
				UIKit.Tween(d, 0.4, { ImageTransparency = 1 })
			elseif d:IsA("TextLabel") then
				UIKit.Tween(d, 0.4, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then
				UIKit.Tween(d, 0.4, { Transparency = 1 })
			end
		end
		task.wait(0.45)
		f:Destroy()
	end)
end

return HUD
