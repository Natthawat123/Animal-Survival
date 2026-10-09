--[[
	HUD — หน้าจอหลักระหว่างเล่น
	  ซ้ายบน: เลือด / ความหิว / สตามิน่า
	  กลางบน: คืนที่ X/99 + เวลา + ธาตุประจำคืน + เข็มทิศ
	  ขวาบน: กองไฟ + ลูกสัตว์ธาตุ 4 ดวง + เพชร
	  ล่าง: ทรัพยากรในกระเป๋า + ปุ่มลัด / แถบเลือดบอส
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Animals = require(Shared.Animals)
local Config = require(Shared.Config)
local UIKit = require(script.Parent.UIKit)

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

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

function HUD.Init(state)
	HUD.State = state
	local gui = UIKit.Screen("HUD", 5)
	HUD.Gui = gui

	---------------------------------------------------------------- ซ้ายบน: แถบค่า
	local stats = UIKit.Frame(gui, { Size = UDim2.fromOffset(250, 78), Position = UDim2.fromOffset(16, 66), BackgroundTransparency = 1 })
	HUD.HealthBar = UIKit.Bar(stats, { Size = UDim2.fromOffset(250, 20), Position = UDim2.fromOffset(0, 0), Color = C.Health, Label = "❤ 100" })
	HUD.HungerBar = UIKit.Bar(stats, { Size = UDim2.fromOffset(210, 14), Position = UDim2.fromOffset(0, 26), Color = C.Hunger, Label = "🍖" })
	HUD.StaminaBar = UIKit.Bar(stats, { Size = UDim2.fromOffset(190, 10), Position = UDim2.fromOffset(0, 46), Color = C.Stamina, Label = "" })
	HUD.ClassLabel = UIKit.Text(stats, { Size = UDim2.fromOffset(250, 16), Position = UDim2.fromOffset(0, 60), TextSize = 13, TextColor3 = C.TextDim, Text = "" })

	---------------------------------------------------------------- กลางบน: คืน
	local top = UIKit.Frame(gui, { Size = UDim2.fromOffset(360, 74), Position = UDim2.new(0.5, -180, 0, 10), BackgroundTransparency = 1 })
	HUD.NightLabel = UIKit.Text(top, {
		Size = UDim2.new(1, 0, 0, 36), Font = UIKit.Fonts.Title, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center,
		Text = "DAY 1", TextColor3 = C.Gold, TextStrokeTransparency = 0.6,
	})
	HUD.PhaseLabel = UIKit.Text(top, {
		Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 36), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center,
		Text = "", TextColor3 = C.Text, TextStrokeTransparency = 0.6,
	})
	-- เส้นเวลา
	local track = UIKit.Frame(top, { Size = UDim2.new(1, -60, 0, 4), Position = UDim2.new(0, 30, 0, 58), BackgroundColor3 = Color3.fromRGB(40, 38, 44), BackgroundTransparency = 0.2 })
	UIKit.Corner(track, 2)
	HUD.TimeFill = UIKit.Frame(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, BackgroundTransparency = 0 })
	UIKit.Corner(HUD.TimeFill, 2)
	HUD.TimeIcon = UIKit.Text(track, { Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0, -10, 0.5, -10), Text = "☀", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center })

	-- เข็มทิศ
	local compass = UIKit.Frame(gui, { Size = UDim2.fromOffset(520, 26), Position = UDim2.new(0.5, -260, 0, 88), BackgroundColor3 = Color3.fromRGB(10, 10, 12), BackgroundTransparency = 0.55, ClipsDescendants = true })
	UIKit.Corner(compass, 6)
	UIKit.Stroke(compass, C.GoldDim, 1, 0.6)
	HUD.Compass = compass
	HUD.CompassMarks = {}
	for _, d in ipairs({ { "N", 0 }, { "E", 90 }, { "S", 180 }, { "W", 270 } }) do
		local t = UIKit.Text(compass, { Size = UDim2.fromOffset(20, 26), Text = d[1], TextSize = 14, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center })
		table.insert(HUD.CompassMarks, { Label = t, Angle = math.rad(d[2]) })
	end
	HUD.CompassPOI = {}

	---------------------------------------------------------------- ขวาบน: กองไฟ / วิญญาณ / เพชร
	local right = UIKit.Frame(gui, { Size = UDim2.fromOffset(250, 104), Position = UDim2.new(1, -266, 0, 16) })
	UIKit.Corner(right, 10)
	UIKit.Stroke(right, C.GoldDim, 1, 0.5)
	HUD.FireLabel = UIKit.Text(right, { Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(10, 6), Text = "🔥 กองไฟ Lv.1", TextColor3 = C.Fire, TextSize = 15 })
	HUD.FireBar = UIKit.Bar(right, { Size = UDim2.new(1, -20, 0, 12), Position = UDim2.fromOffset(10, 30), Color = C.Fire, Label = "" })
	HUD.SafeLabel = UIKit.Text(right, { Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(10, 46), Text = "", TextSize = 12, TextColor3 = C.TextDim })
	HUD.SpiritOrbs = {}
	for i, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		local orb = UIKit.Frame(right, { Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(10 + (i - 1) * 28, 70), BackgroundColor3 = Color3.fromRGB(50, 50, 56), BackgroundTransparency = 0 })
		UIKit.Corner(orb, 11)
		UIKit.Stroke(orb, C.Element[el], 2, 0.3)
		local t = UIKit.Text(orb, { Size = UDim2.fromScale(1, 1), Text = UIKit.ElementIcon[el], TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 0.6 })
		HUD.SpiritOrbs[el] = { Frame = orb, Icon = t }
	end
	HUD.DiamondLabel = UIKit.Text(right, { Size = UDim2.fromOffset(110, 22), Position = UDim2.new(1, -120, 0, 70), Text = "💎 0", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(150, 220, 255) })

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
		Size = UDim2.new(0, 760, 0, 18), Position = UDim2.new(0.5, -380, 1, -128), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 13, TextColor3 = C.TextDim,
		Text = "[คลิก] ตี/ตัด   [Shift] วิ่ง   [C] คราฟต์   [B] สร้าง   [E] เก็บของ   [Tab] กระสอบ   [M] แผนที่   [1-9] เลือกของ",
		TextStrokeTransparency = 0.7,
	})

	---------------------------------------------------------------- แถบเลือดบอส (สไตล์ Souls)
	local boss = UIKit.Frame(gui, { Size = UDim2.new(0, 720, 0, 46), Position = UDim2.new(0.5, -360, 1, -236), BackgroundTransparency = 1, Visible = false })
	HUD.BossName = UIKit.Text(boss, { Size = UDim2.new(1, 0, 0, 24), Font = UIKit.Fonts.Title, TextSize = 24, Text = "", TextColor3 = C.Text, TextStrokeTransparency = 0.5 })
	HUD.BossBar = UIKit.Bar(boss, { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.fromOffset(0, 28), Color = Color3.fromRGB(170, 24, 30), Label = "" })
	HUD.BossFrame = boss

	---------------------------------------------------------------- แจ้งเตือน
	local feed = UIKit.Frame(gui, { Size = UDim2.new(0, 380, 0, 300), Position = UDim2.new(1, -396, 0, 132), BackgroundTransparency = 1 })
	local fl = Instance.new("UIListLayout")
	fl.Padding = UDim.new(0, 6)
	fl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	fl.SortOrder = Enum.SortOrder.LayoutOrder
	fl.Parent = feed
	HUD.Feed = feed
	HUD.FeedOrder = 0

	-- ป๊อปอัปเก็บของ
	local pick = UIKit.Frame(gui, { Size = UDim2.new(0, 220, 0, 200), Position = UDim2.new(1, -236, 1, -330), BackgroundTransparency = 1 })
	local pl = Instance.new("UIListLayout")
	pl.Padding = UDim.new(0, 4)
	pl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	pl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	pl.Parent = pick
	HUD.PickFeed = pick

	-- ล้ม
	HUD.DownedFrame = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(80, 0, 0), BackgroundTransparency = 0.7, Visible = false, ZIndex = 20 })
	HUD.DownedText = UIKit.Text(HUD.DownedFrame, {
		Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.62, 0), TextXAlignment = Enum.TextXAlignment.Center,
		Font = UIKit.Fonts.Title, TextSize = 34, Text = "", TextColor3 = Color3.fromRGB(255, 200, 190), ZIndex = 21,
	})

	RunService.RenderStepped:Connect(HUD.Update)
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
		HUD.HealthBar.Set(hum.Health / math.max(hum.MaxHealth, 1), string.format("❤ %d", math.ceil(hum.Health)))
	end
	local hunger = player:GetAttribute("Hunger") or 100
	HUD.HungerBar.Set(hunger / Config.HungerMax, hunger < 25 and "🍖 หิวมาก!" or "🍖")
	HUD.StaminaBar.Set((HUD.Stamina or 100) / 100)
	local cls = player:GetAttribute("Class")
	HUD.ClassLabel.Text = cls and ("คลาส: " .. cls) or ""

	-- เวลา
	local now = Workspace:GetServerTimeNow()
	local phase = s:GetAttribute("Phase") or "Day"
	local pStart, pEnd = s:GetAttribute("PhaseStart") or now, s:GetAttribute("PhaseEnd") or now
	local frac = math.clamp((now - pStart) / math.max(pEnd - pStart, 0.01), 0, 1)
	local remain = pEnd - now
	local total = s:GetAttribute("TotalNights") or 99
	local inLobby = not player:GetAttribute("InRun")
	if HUD.FireLabel then
		HUD.FireLabel.Parent.Visible = not inLobby
	end
	-- ล็อบบี้: หน้าจอโล่งแบบ 99 Nights (ซ่อนแถบเลือด/เข็มทิศ/กระเป๋า)
	HUD.HealthBar.Holder.Parent.Visible = not inLobby
	HUD.Compass.Visible = not inLobby
	HUD.TimeFill.Parent.Visible = not inLobby
	HUD.Strip.Visible = false -- ไม่มีแถบนับของ: ของทั้งหมดอยู่ในกระสอบ (แบบ 99 Nights)
	HUD.Hint.Visible = inLobby
	if inLobby then
		HUD.NightLabel.Text = "WILDHEART CAMP"
		HUD.NightLabel.TextColor3 = C.Gold
		local cd = s:GetAttribute("PortalCountdown") or -1
		if not s:GetAttribute("Ready") then
			HUD.PhaseLabel.Text = string.format("⏳ กำลังสร้างโลก %d%% · ระหว่างนี้แวะร้านค้าได้", math.floor((s:GetAttribute("LoadProgress") or 0) * 100))
		elseif cd >= 0 then
			HUD.PhaseLabel.Text = string.format("🧭 ทีม %d คน · ออกเดินทางใน %d วินาที", s:GetAttribute("PortalCount") or 0, cd)
		elseif phase == "Lobby" then
			HUD.PhaseLabel.Text = "🌲 เดินขึ้นแท่น \"เริ่มเกม\" ทางขวามือเพื่อเริ่ม 99 คืน"
		else
			HUD.PhaseLabel.Text = string.format("⚔ ทีมกำลังเอาชีวิตรอดคืนที่ %d — ขึ้นแท่นเริ่มเกมเพื่อร่วมทีม", s:GetAttribute("Night") or 1)
		end
		HUD.Hint.Text = "เต็นท์ Classes ตรงหน้า = ร้านคลาส [K]   ·   หม้อเขียวซ้ายมือ = รางวัลประจำวัน   ·   แท่นเริ่มเกม: [F] = ขนาดทีม 1-5"
		HUD.TimeFill.Size = UDim2.fromScale(0, 1)
	elseif phase == "Day" then
		HUD.PhaseLabel.Text = string.format("กลางวัน · ค่ำในอีก %s · %d/%d", fmtTime(remain), s:GetAttribute("Night") or 1, total)
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
		HUD.Hint.Text = "[คลิก] ตี/ตัด   [Shift] วิ่ง   [C] คราฟต์   [B] สร้าง   [E] เก็บของ   [Tab] กระสอบ   [M] แผนที่   [1-9] เลือกของ"
	end
	HUD.TimeIcon.Position = UDim2.new(frac, -10, 0.5, -10)

	-- กองไฟ
	local lvl = s:GetAttribute("CampLevel") or 1
	local fuel, maxFuel = s:GetAttribute("CampFuel") or 0, s:GetAttribute("CampMaxFuel") or 1
	HUD.FireLabel.Text = string.format("🔥 กองไฟ Lv.%d   🔨 โต๊ะ Lv.%d", lvl, s:GetAttribute("BenchLevel") or 1)
	HUD.FireBar.Set(fuel / maxFuel, string.format("%d / %d", fuel, maxFuel))
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
	HUD.DiamondLabel.Text = "💎 " .. tostring(player:GetAttribute("Diamonds") or 0)

	-- บอส
	local bossId = s:GetAttribute("BossId")
	if bossId and bossId ~= "" and Animals.Data[bossId] then
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
		HUD.DownedText.Text = string.format("คุณล้มลงแล้ว — รอเพื่อนช่วย %d", math.max(0, math.ceil(left)))
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
	end
	local _ = width
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
	for key, poi in pairs(HUD.CompassPOI) do
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
	Info = Color3.fromRGB(230, 226, 214), Good = Color3.fromRGB(140, 235, 150), Reward = Color3.fromRGB(255, 214, 110),
	Warn = Color3.fromRGB(255, 180, 80), Danger = Color3.fromRGB(255, 100, 90), Error = Color3.fromRGB(255, 130, 120),
}

function HUD.Notify(text, kind)
	if not HUD.Feed then
		return
	end
	HUD.FeedOrder += 1
	local f = UIKit.Frame(HUD.Feed, { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 0.25, LayoutOrder = -HUD.FeedOrder, AutomaticSize = Enum.AutomaticSize.Y })
	UIKit.Corner(f, 6)
	UIKit.Stroke(f, KIND_COLOR[kind] or KIND_COLOR.Info, 1, 0.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.Parent = f
	UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 14,
		Text = text, TextColor3 = KIND_COLOR[kind] or KIND_COLOR.Info,
	})
	local children = {}
	for _, c in ipairs(HUD.Feed:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(children, c)
		end
	end
	if #children > 6 then
		table.sort(children, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		children[1]:Destroy()
	end
	task.delay(7, function()
		if f.Parent then
			UIKit.Tween(f, 0.5, { BackgroundTransparency = 1 })
			for _, d in ipairs(f:GetDescendants()) do
				if d:IsA("TextLabel") then
					UIKit.Tween(d, 0.5, { TextTransparency = 1 })
				elseif d:IsA("UIStroke") then
					UIKit.Tween(d, 0.5, { Transparency = 1 })
				end
			end
			task.wait(0.55)
			f:Destroy()
		end
	end)
end

function HUD.Pickup(id, n)
	if not HUD.PickFeed then
		return
	end
	local f = UIKit.Frame(HUD.PickFeed, { Size = UDim2.fromOffset(200, 26), BackgroundTransparency = 0.35 })
	UIKit.Corner(f, 6)
	local item = Items.Data[id]
	UIKit.Text(f, {
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right,
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
