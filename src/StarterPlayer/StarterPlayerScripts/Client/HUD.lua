--[[
	HUD — หน้าจอหลักระหว่างเล่น
	  ซ้ายบน: เลือด / ความหิว / สตามิน่า
	  กลางบน: คืนที่ X + เวลา + ธาตุประจำคืน + เข็มทิศ
	  ซ้าย (ใต้แถบค่า): เพื่อนร่วมทีม — ชื่อ + เลือด + สถานะล้ม/ตาย (เพื่อนบนเข็มทิศพร้อมระยะ)
	  ขวาบน: กองไฟ (วงแหวนเชื้อเพลิง เขียว→เหลือง→แดง + เวลาที่เหลือ) + ลูกสัตว์ธาตุ 4 ดวง + Ruby
	  ล่าง: ทรัพยากรในกระเป๋า + ปุ่มลัด / แถบเลือดบอส
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Animals = require(Shared.Animals)
local Config = require(Shared.Config)
local UIKit = require(script.Parent.UIKit)
local SoundController = require(script.Parent.SoundController)

local HUD = {}
local player = Players.LocalPlayer
local C = UIKit.Colors

local STRIP = { "Wood", "Stone", "Fiber", "Iron", "Coal", "Pelt", "Bone", "Berries", "RawMeat", "CookedMeat", "TerraCore", "TidePearl", "GaleFeather", "EmberShard", "Bandage" }
local ICON = {
	Wood = "🌲", Stone = "🗻", Fiber = "🌾", Iron = "⛓", Coal = "⚫", Pelt = "🟫", Bone = "🦴", Berries = "🍒", RawMeat = "🥩",
	CookedMeat = "🍖", Stew = "🍲", TerraCore = "🟢", TidePearl = "🔵", GaleFeather = "🪶", EmberShard = "🔶", Bandage = "🩹",
	Medkit = "⛑", BeastHeart = "❤‍🔥",
}
HUD.Icon = ICON
HUD.ExtraPOI = {}

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

function HUD.Init(state)
	HUD.State = state
	HUD.Touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local gui = UIKit.Screen("HUD", 5)
	HUD.Gui = gui

	---------------------------------------------------------------- ซ้ายบน: แถบค่า
	-- การ์ดกระจกมุมซ้ายบน: เลือด / หิว / สตามิน่า + คลาส
	-- ไม่มีพื้นการ์ด: แถบหนาลอยบนจอ + ไอคอนวงกลมสีสดหน้าแถบ (แบบเกมยุคใหม่)
	local stats = UIKit.Frame(gui, { Size = UDim2.fromOffset(300, 120), Position = UDim2.fromOffset(20, 66), BackgroundTransparency = 1 })
	UIKit.AutoScale(stats)
	HUD.HealthBar = UIKit.Bar(stats, { Size = UDim2.fromOffset(250, 28), Position = UDim2.fromOffset(30, 6), Color = C.Health, Label = "100" })
	UIKit.IconBadge(stats, "❤", C.Health, 42, { Position = UDim2.fromOffset(0, -1) })
	HUD.HungerBar = UIKit.Bar(stats, { Size = UDim2.fromOffset(210, 20), Position = UDim2.fromOffset(30, 48), Color = C.Hunger, Label = "" })
	UIKit.IconBadge(stats, "🍖", C.Hunger, 34, { Position = UDim2.fromOffset(4, 41) })
	HUD.StaminaBar = UIKit.Bar(stats, { Size = UDim2.fromOffset(180, 14), Position = UDim2.fromOffset(30, 82), Color = C.Stamina, Label = "" })
	UIKit.IconBadge(stats, "⚡", C.Stamina, 28, { Position = UDim2.fromOffset(7, 75) })
	HUD.ClassLabel = UIKit.Text(stats, { Size = UDim2.fromOffset(260, 18), Position = UDim2.fromOffset(6, 104), TextSize = 15, Font = UIKit.Fonts.Black, TextColor3 = C.Gold, Text = "" })
	-- เพื่อนร่วมทีม (อยู่ในกรอบเดียวกับแถบค่า ย่อ/ขยายไปด้วยกัน)
	local team = UIKit.Frame(stats, { Name = "Team", Size = UDim2.fromOffset(240, 0), Position = UDim2.fromOffset(4, 130), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Visible = false })
	local tl = Instance.new("UIListLayout")
	tl.Padding = UDim.new(0, 4)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = team
	HUD.TeamFrame = team
	HUD.TeamRows = {}
	HUD.TeamMarks = {}

	---------------------------------------------------------------- กลางบน: คืน
	local top = UIKit.Frame(gui, { Size = UDim2.fromOffset(440, 84), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), BackgroundTransparency = 1 })
	UIKit.AutoScale(top) -- เข็มทิศ + แถบเลือดบอสอยู่ในกรอบนี้ (ย่อ/ขยายไปด้วยกัน)
	HUD.NightLabel = UIKit.Text(top, {
		Size = UDim2.new(1, 0, 0, 44), Font = UIKit.Fonts.Title, TextSize = 44, TextXAlignment = Enum.TextXAlignment.Center,
		Text = "DAY 1", TextColor3 = C.Gold,
	})
	HUD.NightLabel:FindFirstChildOfClass("UIStroke").Thickness = 4
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
	local right = UIKit.Card(gui, { Size = UDim2.fromOffset(270, 116), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 18), BackgroundTransparency = 0.12 })
	UIKit.AutoScale(right)
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
	HUD.FireLabel = UIKit.Text(right, { Size = UDim2.new(1, -90, 0, 20), Position = UDim2.fromOffset(82, 6), Text = "กองไฟ Lv.1", Font = UIKit.Fonts.Black, TextColor3 = C.Text, TextSize = 15 })
	HUD.FuelText = UIKit.Text(right, { Size = UDim2.new(1, -90, 0, 26), Position = UDim2.fromOffset(82, 26), Text = "", Font = UIKit.Fonts.Title, TextColor3 = C.Good, TextSize = 22 })
	HUD.SafeLabel = UIKit.Text(right, { Size = UDim2.new(1, -90, 0, 18), Position = UDim2.fromOffset(82, 54), Text = "", TextSize = 13, TextColor3 = C.TextDim })
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
	HUD.DiamondLabel = UIKit.Text(right, { Size = UDim2.fromOffset(100, 28), Position = UDim2.new(1, -144, 0, 80), Text = "0", Font = UIKit.Fonts.Title, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 190, 190) })
	UIKit.Icon(right, "Ruby", 32, { Position = UDim2.new(1, -42, 0, 76) })

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
		UIKit.Text(slot, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 0), Text = ICON[id] or "?", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center })
		local count = UIKit.Text(slot, { Size = UDim2.new(1, -4, 0, 14), Position = UDim2.fromOffset(0, 17), Text = "0", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.TextDim })
		slot.Visible = false
		HUD.Slots[id] = { Frame = slot, Count = count }
	end
	HUD.Hint = UIKit.Text(gui, {
		Size = UDim2.new(0, 900, 0, 20), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 15, TextColor3 = C.Text,
		Text = "[คลิก] ตี/ตัด   [Shift] วิ่ง   [C] คราฟต์   [B] สร้าง   [E] เก็บของ (ถือกระสอบ)   [F] เอาของออก   [M] แผนที่   [1-9] เลือกของ",
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
		Size = UDim2.new(0, 680, 0, HUD.Touch and 150 or 220), AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, HUD.Touch and 150 or 198), BackgroundTransparency = 1, -- ใต้แถบวัน/เข็มทิศ/แถบเลือดบอส
	})
	UIKit.AutoScale(feed)
	local fl = Instance.new("UIListLayout")
	fl.Padding = UDim.new(0, 4)
	fl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	fl.SortOrder = Enum.SortOrder.LayoutOrder
	fl.Parent = feed
	HUD.Feed = feed
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

	-- ล้ม
	HUD.DownedFrame = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(80, 0, 0), BackgroundTransparency = 0.7, Visible = false, ZIndex = 20 })
	HUD.DownedText = UIKit.Text(HUD.DownedFrame, {
		Size = UDim2.new(1, 0, 0, 90), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, 0), TextXAlignment = Enum.TextXAlignment.Center,
		Font = UIKit.Fonts.Title, TextSize = 32, Text = "", TextColor3 = Color3.fromRGB(255, 200, 190), ZIndex = 21,
	})
	UIKit.AutoScale(HUD.DownedText)

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
	HUD.UpdateNightLabel()
end

function HUD.UpdateNightLabel()
	if not player:GetAttribute("InRun") then
		return
	end
	local s = HUD.State
	local night = s:GetAttribute("Night") or 1
	local phase = s:GetAttribute("Phase") or "Day"
	if phase == "Night" then
		HUD.NightLabel.Text = string.format("NIGHT %d", night)
		HUD.NightLabel.TextColor3 = s:GetAttribute("BloodMoon") and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(170, 190, 255)
	else
		HUD.NightLabel.Text = string.format("DAY %d", night)
		HUD.NightLabel.TextColor3 = C.Gold
	end
end

local lastPOI = 0
function HUD.Update()
	local s = HUD.State
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		HUD.HealthBar.Set(hum.Health / math.max(hum.MaxHealth, 1), string.format("%d / %d", math.ceil(hum.Health), math.ceil(hum.MaxHealth)))
	end
	local hunger = player:GetAttribute("Hunger") or 100
	HUD.HungerBar.Set(hunger / Config.HungerMax, hunger < 25 and "หิวมาก!" or "")
	HUD.StaminaBar.Set((HUD.Stamina or 100) / 100)
	local cls = player:GetAttribute("Class")
	HUD.ClassLabel.Text = cls and ("คลาส: " .. cls) or ""

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
	HUD.Hint.Visible = HUD.ShowHints ~= false
	HUD.Hint.Position = UDim2.new(0.5, 0, 1, inLobby and -16 or -86) -- ในแมพ: อยู่เหนือแถบไอเทมของ Roblox
	if inLobby then
		HUD.NightLabel.Text = "WILDHEART CAMP"
		HUD.NightLabel.TextColor3 = C.Gold
		local cd = s:GetAttribute("PortalCountdown") or -1
		if not s:GetAttribute("Ready") then
			HUD.PhaseLabel.Text = string.format("⏳ กำลังสร้างโลก %d%% · ระหว่างนี้แวะร้านค้าได้", math.floor((s:GetAttribute("LoadProgress") or 0) * 100))
		elseif cd >= 0 then
			HUD.PhaseLabel.Text = string.format("🧭 ทีม %d คน · ออกเดินทางใน %d วินาที", s:GetAttribute("PortalCount") or 0, cd)
		elseif phase == "Lobby" then
			HUD.PhaseLabel.Text = "🌲 เดินขึ้นแท่น \"เริ่มเกม\" ทางขวามือเพื่อออกผจญภัย"
		else
			HUD.PhaseLabel.Text = string.format("⚔ ทีมกำลังเอาชีวิตรอดคืนที่ %d — ขึ้นแท่นเริ่มเกมเพื่อร่วมทีม", s:GetAttribute("Night") or 1)
		end
		HUD.Hint.Text = HUD.Touch and "เต็นท์ Classes = ร้านคลาส · หม้อเขียว = รางวัลรายวัน · เดินขึ้นแท่นเริ่มเกมเพื่อออกผจญภัย"
			or "เต็นท์ Classes ตรงหน้า = ร้านคลาส [K]   ·   หม้อเขียวซ้ายมือ = รางวัลประจำวัน   ·   แท่นเริ่มเกม: เดินขึ้นแท่นแล้วเลือกจำนวนคน (1-8)"
		HUD.TimeFill.Size = UDim2.fromScale(0, 1)
	elseif phase == "Day" then
		HUD.PhaseLabel.Text = string.format("☀ กลางวัน · ค่ำในอีก %s", fmtTime(remain))
		HUD.TimeIcon.Text = "☀"
		HUD.TimeFill.BackgroundColor3 = C.Gold
	elseif phase == "Dusk" then
		HUD.PhaseLabel.Text = string.format("⚠ พลบค่ำ · ฝูงสัตว์จะมาในอีก %s", fmtTime(remain))
		HUD.TimeIcon.Text = "🌅"
		HUD.TimeFill.BackgroundColor3 = C.Fire
	elseif phase == "Night" then
		local el = s:GetAttribute("NightElement") or "Earth"
		HUD.PhaseLabel.Text = string.format("%s คืนแห่ง%s · รุ่งเช้าในอีก %s", UIKit.ElementIcon[el] or "", UIKit.ElementThai[el] or "", fmtTime(remain))
		HUD.TimeIcon.Text = s:GetAttribute("BloodMoon") and "🔴" or "🌙"
		HUD.TimeFill.BackgroundColor3 = UIKit.Colors.Element[el] or C.Gold
	elseif phase == "Loading" then
		HUD.PhaseLabel.Text = "กำลังสร้างโลก..."
	else
		HUD.PhaseLabel.Text = ""
	end
	if not inLobby then
		HUD.TimeFill.Size = UDim2.fromScale(frac, 1)
		HUD.Hint.Text = HUD.Touch and "แตะจอ = ตี/ตัด · ปุ่มขวาล่าง = คราฟต์/สร้าง/กระสอบ/แผนที่ · แตะปุ่มบนของ = เก็บ"
			or "[คลิก] ตี/ตัด   [Shift] วิ่ง   [C] คราฟต์   [B] สร้าง   [E] เก็บของ   [F] เอาของออก   [Tab] กระสอบ   [M] แผนที่   [1-9] เลือกของ"
	end
	HUD.TimeIcon.Position = UDim2.new(frac, -10, 0.5, -10)

	-- กองไฟ
	local lvl = s:GetAttribute("CampLevel") or 1
	local fuel, maxFuel = s:GetAttribute("CampFuel") or 0, s:GetAttribute("CampMaxFuel") or 1
	HUD.FireLabel.Text = string.format("กองไฟ Lv.%d  ·  โต๊ะ Lv.%d", lvl, s:GetAttribute("BenchLevel") or 1)
	HUD.UpdateFuel(fuel, maxFuel, inLobby, phase)
	local campPos = s:GetAttribute("CampPos")
	local safe = s:GetAttribute("CampSafeRadius") or 0
	if campPos and char then
		local d = ((char:GetPivot().Position - campPos) * Vector3.new(1, 0, 1)).Magnitude
		if fuel <= 0 then
			HUD.SafeLabel.Text = "⚠ ไฟดับ! ไม่มีที่ปลอดภัย"
			HUD.SafeLabel.TextColor3 = C.Bad
		elseif d < safe then
			HUD.SafeLabel.Text = "🔥 อยู่ในแสงกองไฟ (ปลอดภัยจากกวางกลวง)"
			HUD.SafeLabel.TextColor3 = C.Good
		else
			HUD.SafeLabel.Text = string.format("ห่างกองไฟ %d m", math.floor(d * 0.28))
			HUD.SafeLabel.TextColor3 = C.TextDim
		end
	end
	for el, orb in pairs(HUD.SpiritOrbs) do
		local rescued = s:GetAttribute("Spirit" .. el)
		orb.Frame.BackgroundColor3 = rescued and C.Element[el] or Color3.fromRGB(50, 50, 56)
		orb.Icon.TextTransparency = rescued and 0 or 0.6
	end
	HUD.DiamondLabel.Text = tostring(player:GetAttribute("Diamonds") or 0)

	-- บอส
	local bossId = s:GetAttribute("BossId")
	local bossNear = false
	if bossId and bossId ~= "" and player:GetAttribute("InRun") then
		local animals = Workspace:FindFirstChild("Animals")
		local myPos = player.Character and player.Character:GetPivot().Position
		for _, m in ipairs(animals and animals:GetChildren() or {}) do
			if m:GetAttribute("IsBoss") and myPos and (m:GetPivot().Position - myPos).Magnitude < 350 then
				bossNear = true
				break
			end
		end
	end
	if bossNear and Animals.Data[bossId] then
		HUD.BossFrame.Visible = true
		HUD.BossName.Text = Animals.Data[bossId].Name
		HUD.BossBar.Set((s:GetAttribute("BossHP") or 0) / math.max(s:GetAttribute("BossMaxHP") or 1, 1))
	else
		HUD.BossFrame.Visible = false
	end

	-- ล้ม
	local downed = player:GetAttribute("Downed")
	HUD.DownedFrame.Visible = downed == true
	if downed then
		local left = (player:GetAttribute("DownedUntil") or now) - now
		HUD.DownedText.Text = string.format("🩸 คุณล้มลงแล้ว — รอเพื่อนช่วย %d วินาที\nไม่มีใครช่วยทัน = ตาย (ไม่เกิดใหม่ในรอบนี้)", math.max(0, math.ceil(left)))
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
	HUD.FuelText.Text = fuel <= 0 and "ไฟดับ!" or (string.format("%d%%", math.floor(frac * 100 + 0.5)) .. est)
	HUD.FuelText.TextColor3 = fuel <= 0 and C.Bad or col
	-- เตือนครั้งเดียวต่อการลดลงต่ำกว่า 20% (เติมกลับถึง 25% ค่อยเตือนใหม่ได้)
	local active = not inLobby and (phase == "Day" or phase == "Dusk" or phase == "Night")
	if low and active and HUD.FuelLowArmed then
		HUD.FuelLowArmed = false
		SoundController.Play("FireLow")
		HUD.Notify(string.format("🔥 ไฟใกล้มอด! เหลือราว %s — โยนไม้/ถ่านเข้ากองไฟด่วน", drain > 0 and fmtTime(fuel / drain) or "ไม่กี่นาที"), "Warn")
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
			r.Status.Text = "ตายแล้ว"
			r.Status.TextColor3 = C.TextDim
		elseif downed then
			local left = math.max(0, math.ceil((p:GetAttribute("DownedUntil") or now) - now))
			r.Icon.Text = "🩸"
			r.Status.Text = string.format("ล้ม! %ds", left)
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
	HUD.SackLabel.Text = cap > 0 and string.format("🎒 %d/%d", used, cap) or "🎒 ไม่มีกระสอบ"
	HUD.SackLabel.TextColor3 = (cap > 0 and used >= cap) and Color3.fromRGB(255, 110, 100) or Color3.fromRGB(240, 226, 190)
end

function HUD.SetInventory(inv)
	HUD.Inventory = inv
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
local KIND_GLYPH = { Info = "✦", Good = "✔", Reward = "★", Warn = "⚠", Danger = "☠", Error = "✖" }
local GOLD = Color3.fromRGB(236, 196, 112)
-- แถบจางหัวท้าย (ตรงกลางเข้ม -> ขอบใส)
local function ribbonFade(alpha)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.18, alpha), NumberSequenceKeypoint.new(0.82, alpha), NumberSequenceKeypoint.new(1, 1),
	})
end

-- แจ้งเตือนกลางจอ (สไตล์เกมเอาชีวิตรอด): ตัวหนังสือใหญ่ขอบเข้ม บนแถบสีจางตามประเภท + เส้นทองบน/ล่าง · ขึ้นแล้วค่อยจางหายขึ้นด้านบน
function HUD.Notify(text, kind)
	if not HUD.Feed then
		return
	end
	kind = KIND_COLOR[kind] and kind or "Info"
	local col = KIND_COLOR[kind]
	local big = kind == "Danger" or kind == "Reward"
	HUD.FeedOrder += 1
	local slot = UIKit.Frame(HUD.Feed, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = HUD.FeedOrder })
	local band = UIKit.Frame(slot, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = col:Lerp(Color3.new(0, 0, 0), 0.72), BackgroundTransparency = 0 })
	local bg = Instance.new("UIGradient")
	bg.Transparency = ribbonFade(0.25)
	bg.Parent = band
	for _, y in ipairs({ 0, 1 }) do
		local line = UIKit.Frame(band, { Size = UDim2.new(1, 0, 0, 2), AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), BackgroundColor3 = kind == "Info" and GOLD or col, BackgroundTransparency = 0 })
		local lg = Instance.new("UIGradient")
		lg.Transparency = ribbonFade(0)
		lg.Parent = line
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 60)
	pad.PaddingRight = UDim.new(0, 60)
	pad.Parent = band
	local g = KIND_GLYPH[kind]
	local label = UIKit.Text(band, {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = big and 25 or 21, Font = UIKit.Fonts.Black, Text = g .. "  " .. text .. "  " .. g, TextColor3 = col, TextTransparency = 1,
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
	if #children > (HUD.Touch and 3 or 4) then
		table.sort(children, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		children[1]:Destroy()
	end
	task.delay(big and 6 or 4.5, function()
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

function HUD.Pickup(id, n)
	if not HUD.PickFeed then
		return
	end
	local f = UIKit.Frame(HUD.PickFeed, { Size = UDim2.fromOffset(210, 32), BackgroundColor3 = Color3.fromRGB(26, 28, 50), BackgroundTransparency = 0.1 })
	UIKit.Corner(f, 14)
	UIKit.Stroke(f, C.Outline, 2, 0)
	local sc = Instance.new("UIScale")
	sc.Scale = 0.5
	sc.Parent = f
	UIKit.Tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	local item = Items.Data[id]
	UIKit.Text(f, {
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 17, Font = UIKit.Fonts.Black, TextXAlignment = Enum.TextXAlignment.Right,
		Text = string.format("+%d %s %s", n, item and item.Thai or id, ICON[id] or ""), TextColor3 = item and item.Color or C.Text,
	})
	task.delay(2.5, function()
		UIKit.Tween(f, 0.4, { BackgroundTransparency = 1 })
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("TextLabel") then
				UIKit.Tween(d, 0.4, { TextTransparency = 1 })
			end
		end
		task.wait(0.45)
		f:Destroy()
	end)
end

return HUD
