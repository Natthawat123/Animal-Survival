--[[
	Cinematics — ฉาก/ตัวอักษรใหญ่แบบภาพยนตร์
	  หน้าโหลด, NIGHT X, BLOOD MOON, เปิดตัวบอส (กล้องหมุน), BEAST VANQUISHED, YOU PERISHED, ฉากจบ
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UIKit = require(script.Parent.UIKit)

local Cinematics = {}
local player = Players.LocalPlayer
local C = UIKit.Colors
local gui

local TIPS = {
	"กองไฟคือชีวิต — ไฟดับเมื่อไร กวางกลวงจะเข้ามาในแคมป์",
	"อัปเกรดกองไฟเพื่อเปิดหมอก และขยายเขตปลอดภัย",
	"ถือคบเพลิงไว้ กวางกลวงจะไม่กล้าเข้าใกล้",
	"น้ำชนะไฟ · ไฟชนะลม · ลมชนะดิน · ดินชนะน้ำ",
	"ลูกสัตว์ธาตุ 4 ตัวถูกขังอยู่ในศาลเจ้า ช่วยครบเพื่อฉากจบที่แท้จริง",
	"ทุก 10 คืนจะเกิดพระจันทร์เลือด ฝูงทุกธาตุบุกพร้อมกัน",
	"เพื่อนล้มลง? ใช้ผ้าพันแผลช่วยให้ทันใน 30 วินาที",
	"หน้าไม้ยักษ์ยิงเองอัตโนมัติ วางไว้รอบกองไฟ",
	"ลมพัดขึ้นในเขตวายุจะส่งคุณขึ้นสู่เกาะลอยฟ้า",
	"รังบอสอยู่ใจกลางแต่ละธาตุ — เตรียมตัวให้พร้อมก่อนเข้าไป",
}

local function bigText(parent)
	return UIKit.Text(parent, {
		Size = UDim2.new(1, 0, 0, 90), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title,
		TextSize = 72, TextStrokeTransparency = 0.4, TextStrokeColor3 = Color3.new(0, 0, 0), TextTransparency = 1,
	})
end

local function fadeTexts(frame, to, time)
	for _, d in ipairs(frame:GetDescendants()) do
		if d:IsA("TextLabel") then
			TweenService:Create(d, TweenInfo.new(time), { TextTransparency = to, TextStrokeTransparency = math.max(to, 0.4) }):Play()
		elseif d:IsA("Frame") and d:GetAttribute("Line") then
			TweenService:Create(d, TweenInfo.new(time), { BackgroundTransparency = to }):Play()
		end
	end
end

-- ข้อความใหญ่กลางจอ (หายเอง)
function Cinematics.Banner(title, subtitle, color, hold, opts)
	opts = opts or {}
	local f = UIKit.Frame(gui, { Size = UDim2.new(1, 0, 0, 170), Position = UDim2.new(0, 0, opts.Y or 0.28, 0), BackgroundTransparency = 1 })
	local t = bigText(f)
	t.Text = title
	t.TextColor3 = color or C.Gold
	t.TextSize = opts.Size or 72
	local line = UIKit.Frame(f, { Size = UDim2.new(0, 520, 0, 2), Position = UDim2.new(0.5, -260, 0, 92), BackgroundColor3 = color or C.Gold, BackgroundTransparency = 1 })
	line:SetAttribute("Line", true)
	local s = UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 100), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Bold,
		TextSize = 24, Text = subtitle or "", TextColor3 = C.Text, TextTransparency = 1, TextStrokeTransparency = 1,
	})
	local _ = s
	fadeTexts(f, 0, 0.8)
	task.delay(hold or 3, function()
		fadeTexts(f, 1, 1.2)
		task.wait(1.3)
		f:Destroy()
	end)
	return f
end

-- แถบดำบน-ล่าง
local bars
local function letterbox(on)
	if not bars then
		bars = {
			UIKit.Frame(gui, { Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromScale(0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 50 }),
			UIKit.Frame(gui, { Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 50 }),
		}
	end
	for _, b in ipairs(bars) do
		UIKit.Tween(b, 0.6, { Size = UDim2.new(1, 0, on and 0.12 or 0, 0) })
	end
end

---------------------------------------------------------------- หน้าโหลด
function Cinematics.Loading(state)
	local f = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 5, 7), BackgroundTransparency = 0, ZIndex = 100 })
	UIKit.Gradient(f, Color3.fromRGB(30, 14, 10), Color3.fromRGB(4, 4, 6), 90)
	local title = UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 110), Position = UDim2.new(0, 0, 0.3, 0), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title,
		TextSize = 96, Text = Config.GameName, TextColor3 = C.Gold, ZIndex = 101, TextStrokeTransparency = 0.5,
	})
	UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.3, 112), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title,
		TextSize = 32, Text = Config.Subtitle, TextColor3 = Color3.fromRGB(220, 200, 170), ZIndex = 101,
	})
	local line = UIKit.Frame(f, { Size = UDim2.new(0, 600, 0, 2), Position = UDim2.new(0.5, -300, 0.3, 160), BackgroundColor3 = C.GoldDim, BackgroundTransparency = 0, ZIndex = 101 })
	local _ = line
	-- สัญลักษณ์ 4 ธาตุ
	for i, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		local orb = UIKit.Text(f, {
			Size = UDim2.fromOffset(60, 60), Position = UDim2.new(0.5, -150 + (i - 1) * 80, 0.3, 180), TextSize = 40, TextXAlignment = Enum.TextXAlignment.Center,
			Text = UIKit.ElementIcon[el], ZIndex = 101,
		})
		task.spawn(function()
			while orb.Parent do
				UIKit.Tween(orb, 1.2, { TextTransparency = 0.6 })
				task.wait(1.2 + i * 0.1)
				UIKit.Tween(orb, 1.2, { TextTransparency = 0 })
				task.wait(1.2)
			end
		end)
	end
	local track = UIKit.Frame(f, { Size = UDim2.new(0, 520, 0, 6), Position = UDim2.new(0.5, -260, 0.78, 0), BackgroundColor3 = Color3.fromRGB(40, 36, 36), BackgroundTransparency = 0, ZIndex = 101 })
	UIKit.Corner(track, 3)
	local fill = UIKit.Frame(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Fire, BackgroundTransparency = 0, ZIndex = 102 })
	UIKit.Corner(fill, 3)
	local status = UIKit.Text(f, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0.78, 14), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, ZIndex = 101, TextColor3 = C.TextDim, Text = "กำลังสร้างโลก..." })
	local tip = UIKit.Text(f, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0.9, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, ZIndex = 101, TextColor3 = Color3.fromRGB(200, 186, 160), Text = "💡 " .. TIPS[math.random(#TIPS)] })
	task.spawn(function()
		while f.Parent do
			task.wait(5)
			tip.Text = "💡 " .. TIPS[math.random(#TIPS)]
		end
	end)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local p = state:GetAttribute("LoadProgress") or 0
		fill.Size = UDim2.fromScale(p, 1)
		if p < 0.8 then
			status.Text = string.format("กำลังปั้นแผ่นดินทั้ง 4 ธาตุ... %d%%", math.floor(p * 100))
		elseif p < 1 then
			status.Text = "กำลังปลูกป่า วางหินผา และปลุกสรรพสัตว์..."
		else
			status.Text = "กำลังจุดกองไฟ..."
		end
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			conn:Disconnect()
			task.wait(1.5)
			UIKit.Tween(f, 1.5, { BackgroundTransparency = 1 })
			for _, d in ipairs(f:GetDescendants()) do
				if d:IsA("TextLabel") then
					UIKit.Tween(d, 1.2, { TextTransparency = 1, TextStrokeTransparency = 1 })
				elseif d:IsA("Frame") then
					UIKit.Tween(d, 1.2, { BackgroundTransparency = 1 })
				end
			end
			task.wait(1.6)
			f:Destroy()
			if Cinematics.OnLoaded then
				Cinematics.OnLoaded()
			end
		end
	end)
	local _ = title
end

---------------------------------------------------------------- เปิดตัวบอส
function Cinematics.BossIntro(d)
	local model = d.Model
	local cam = Workspace.CurrentCamera
	if not (model and model.Parent) then
		model = nil
	end
	letterbox(true)
	local color = C.Element[d.Element] or C.Gold
	local f = UIKit.Frame(gui, { Size = UDim2.new(1, 0, 0, 160), Position = UDim2.new(0, 0, 0.62, 0), BackgroundTransparency = 1, ZIndex = 60 })
	local name = UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 70), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title, TextSize = 56,
		Text = d.Name, TextColor3 = Color3.fromRGB(245, 236, 220), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 61,
	})
	local line = UIKit.Frame(f, { Size = UDim2.new(0, 700, 0, 2), Position = UDim2.new(0.5, -350, 0, 72), BackgroundColor3 = color, BackgroundTransparency = 1, ZIndex = 61 })
	line:SetAttribute("Line", true)
	UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 80), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 24,
		Text = d.Thai, TextColor3 = color, TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 61,
	})
	local _ = name
	fadeTexts(f, 0, 1)
	if model then
		local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if not root then
			model = nil
		end
	end
	if model then
		local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		local size = model:GetExtentsSize()
		local prevType = cam.CameraType
		cam.CameraType = Enum.CameraType.Scriptable
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			if t > 3.6 or not root.Parent or not model.Parent then
				conn:Disconnect()
				cam.CameraType = prevType
				return
			end
			local ang = t * 0.35 + 0.6
			local dist = math.max(size.Magnitude * 1.1, 30) * (1.15 - t * 0.06)
			local center = root.Position + Vector3.new(0, size.Y * 0.35, 0)
			local pos = center + Vector3.new(math.cos(ang) * dist, size.Y * 0.25 + 4, math.sin(ang) * dist)
			cam.CFrame = CFrame.lookAt(pos, center)
		end)
	end
	task.delay(4.2, function()
		letterbox(false)
		fadeTexts(f, 1, 1)
		task.wait(1.1)
		f:Destroy()
	end)
end

---------------------------------------------------------------- จอดำตาย
local deathFrame
function Cinematics.Died()
	if deathFrame then
		deathFrame:Destroy()
	end
	deathFrame = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 70 })
	local band = UIKit.Frame(deathFrame, { Size = UDim2.new(1, 0, 0, 170), Position = UDim2.new(0, 0, 0.5, -85), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 71 })
	UIKit.Gradient(band, Color3.new(0, 0, 0), Color3.new(0, 0, 0), 90).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1),
	})
	local t = UIKit.Text(band, {
		Size = UDim2.new(1, 0, 0, 110), Position = UDim2.fromOffset(0, 20), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title,
		TextSize = 96, Text = "YOU PERISHED", TextColor3 = Color3.fromRGB(150, 16, 20), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 72,
	})
	local s = UIKit.Text(band, {
		Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 124), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 20,
		Text = "สิ้นชีพ... จะได้เกิดใหม่ตอนรุ่งเช้า (หรือที่เตียง)", TextColor3 = Color3.fromRGB(200, 170, 160), TextTransparency = 1, ZIndex = 72,
	})
	UIKit.Tween(band, 1.5, { BackgroundTransparency = 0 })
	UIKit.Tween(t, 2.2, { TextTransparency = 0, TextSize = 104 })
	task.delay(1.4, function()
		UIKit.Tween(s, 1, { TextTransparency = 0 })
	end)
	player.CharacterAdded:Once(function()
		if deathFrame then
			UIKit.Tween(t, 0.8, { TextTransparency = 1 })
			UIKit.Tween(s, 0.8, { TextTransparency = 1 })
			UIKit.Tween(band, 0.8, { BackgroundTransparency = 1 })
			local df = deathFrame
			deathFrame = nil
			task.delay(1, function()
				df:Destroy()
			end)
		end
	end)
end

---------------------------------------------------------------- จบเกม
function Cinematics.FullScreen(title, lines, color, time)
	local f = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 90 })
	UIKit.Tween(f, 2, { BackgroundTransparency = 0.15 })
	local t = UIKit.Text(f, {
		Size = UDim2.new(1, 0, 0, 100), Position = UDim2.new(0, 0, 0.3, 0), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title,
		TextSize = 80, Text = title, TextColor3 = color, TextTransparency = 1, ZIndex = 91,
	})
	UIKit.Tween(t, 2.5, { TextTransparency = 0 })
	for i, line in ipairs(lines) do
		local l = UIKit.Text(f, {
			Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0.3, 110 + i * 34), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 22,
			Text = line, TextColor3 = C.Text, TextTransparency = 1, ZIndex = 91,
		})
		task.delay(1.5 + i * 0.8, function()
			UIKit.Tween(l, 1, { TextTransparency = 0 })
		end)
	end
	task.delay(time or 12, function()
		UIKit.Tween(f, 1.5, { BackgroundTransparency = 1 })
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("TextLabel") then
				UIKit.Tween(d, 1.2, { TextTransparency = 1 })
			end
		end
		task.wait(1.6)
		f:Destroy()
	end)
end

---------------------------------------------------------------- ตัวจัดการ
local ELEMENT_NIGHT_TEXT = {
	Earth = "ป่าทั้งผืนตื่นขึ้น... ฝูงสัตว์แห่งปฐพีกำลังมา",
	Water = "เสียงคลื่นคำราม... สัตว์แห่งวารีขึ้นจากน้ำ",
	Air = "ลมหวีดหวิว... ผู้ล่าแห่งท้องฟ้าโฉบลงมา",
	Fire = "ภูเขาไฟปะทุ... อสูรเพลิงลุกลาม",
	All = "ทุกธาตุโกรธเกรี้ยว...",
}

function Cinematics.Handle(kind, d, menus, combat)
	if kind == "NightStart" then
		local color = d.BloodMoon and Color3.fromRGB(220, 40, 40) or (C.Element[d.Element] or C.Gold)
		local title = d.BloodMoon and "BLOOD MOON" or ("NIGHT " .. d.Night)
		local sub = (d.BloodMoon and ("คืนที่ " .. d.Night .. " · ") or "") .. (d.Title or "") .. " — " .. (ELEMENT_NIGHT_TEXT[d.Element] or "")
		if d.Boss then
			sub = "คืนที่ " .. d.Night .. " · " .. (d.Title or "") .. " — บอสธาตุกำลังมาถึง!"
		end
		letterbox(true)
		Cinematics.Banner(title, sub, color, 4)
		task.delay(4.5, function()
			letterbox(false)
		end)
		combat.Shake(0.3, 1)
	elseif kind == "DayStart" then
		if d.Day > 1 then
			Cinematics.Banner("DAY " .. d.Day, "สำรวจ เก็บของ และเตรียมรับมือก่อนค่ำ", C.Gold, 2.5, { Size = 54, Y = 0.22 })
		else
			Cinematics.Banner("DAY 1", "จุดไฟไว้ให้ลุกโชน... ป่านี้ไม่เคยหลับใหล", C.Gold, 4, { Size = 60, Y = 0.22 })
		end
	elseif kind == "Dusk" then
		Cinematics.Banner("DUSK", "พระอาทิตย์กำลังตก — กลับไปที่กองไฟ!", C.Fire, 2.5, { Size = 50, Y = 0.22 })
	elseif kind == "Dawn" then
		Cinematics.Banner("DAWN", string.format("รอดชีวิตผ่านคืนที่ %d แล้ว", d.Night), Color3.fromRGB(255, 220, 160), 3, { Size = 60 })
	elseif kind == "WaveIncoming" then
		combat.Shake(0.15, 0.6)
	elseif kind == "BossIntro" then
		Cinematics.BossIntro(d)
	elseif kind == "BossFelled" then
		Cinematics.Banner("BEAST VANQUISHED", "ปราบ " .. (d.Thai or "") .. " สำเร็จ! · ได้หัวใจอสูร", Color3.fromRGB(255, 214, 120), 4.5, { Size = 76 })
	elseif kind == "Died" then
		Cinematics.Died()
	elseif kind == "Downed" then
		combat.Shake(0.5, 0.4)
	elseif kind == "Revived" then
		Cinematics.Banner("", "✨ ได้รับการช่วยชีวิต!", C.Good, 1.5, { Size = 10, Y = 0.5 })
	elseif kind == "GameOver" then
		if deathFrame then
			deathFrame:Destroy()
			deathFrame = nil
		end
		Cinematics.FullScreen("ALL HAVE PERISHED", { "ทุกคนสิ้นชีพในคืนที่ " .. tostring(d.Night), "กองไฟมอดดับลง... ป่ากลืนกินทุกสิ่ง", "เริ่มการเอาชีวิตรอดใหม่ในอีกครู่..." }, Color3.fromRGB(170, 20, 24), 11)
	elseif kind == "Ending" then
		if d.Kind == "True" then
			Cinematics.FullScreen("THE FOUR SPIRITS REUNITE", {
				"ลูกสัตว์ทั้ง 4 ธาตุกลับมาพร้อมหน้า", "ความโกรธของผืนป่าสงบลง... สัตว์ทั้งหลายกลับคืนสู่ป่า",
				"คุณรอดชีวิตครบ 99 คืน — จบแบบสมบูรณ์", "💎 +300 เพชร",
			}, Color3.fromRGB(255, 226, 150), 28)
		else
			Cinematics.FullScreen("99 NIGHTS SURVIVED", {
				"คุณรอดชีวิตครบ 99 คืน", string.format("แต่ลูกสัตว์ธาตุกลับมาเพียง %d/4 ตัว...", d.Spirits or 0),
				"ผืนป่ายังคงโกรธเกรี้ยว — ลองใหม่เพื่อฉากจบที่แท้จริง", "💎 +100 เพชร",
			}, C.Gold, 28)
		end
	elseif kind == "SpiritFreed" then
		Cinematics.Banner("SPIRIT UNSEALED", (d.Player or "") .. " ปลดปล่อย " .. (d.Name or "") .. " — พากลับกองไฟ!", C.Element[d.Element] or C.Gold, 3.5, { Size = 56 })
	elseif kind == "SpiritRescued" then
		Cinematics.Banner("SPIRIT RETURNED", string.format("%s กลับบ้านแล้ว (%d/4) · บัฟ: %s", d.Name or "", d.Count or 0, d.Buff or ""), C.Element[d.Element] or C.Gold, 4.5, { Size = 60 })
	elseif kind == "CampUpgrade" then
		Cinematics.Banner("BONFIRE LV." .. d.Level, "เขตปลอดภัยขยาย · หมอกจางลง · ทางใหม่เปิดออก", C.Fire, 3, { Size = 54, Y = 0.22 })
	elseif kind == "FireOut" then
		Cinematics.Banner("THE FIRE IS OUT", "กองไฟดับ! เติมไม้ด่วน", Color3.fromRGB(255, 80, 60), 3, { Size = 56 })
		combat.Shake(0.3, 0.5)
	elseif kind == "OpenCraft" then
		menus.OpenCraft()
	elseif kind == "OpenShop" then
		menus.OpenShop("Kits")
	elseif kind == "OpenClasses" then
		menus.OpenShop("Classes")
	elseif kind == "OpenTrader" then
		menus.OpenTrader()
	elseif kind == "Teleporting" then
		Cinematics.Banner("DEPARTING", "กำลังพาทีมไปยังผืนป่าของพวกคุณ...", C.Gold, 6, { Size = 60 })
	elseif kind == "Depart" then
		letterbox(true)
		Cinematics.Banner("INTO THE WILDS", "ลงสู่ผืนป่า... จุดไฟให้ลุกโชน แล้วเอาชีวิตรอดให้ได้ 99 คืน", C.Gold, 3.5, { Size = 64 })
		task.delay(4, function()
			letterbox(false)
		end)
	elseif kind == "Shake" then
		combat.Shake(d.Power or 0.5, d.Time or 0.5)
	end
end

function Cinematics.Init(state)
	gui = UIKit.Screen("Cinematics", 40)
	Cinematics.Gui = gui
	if not player.Character then
		Cinematics.Loading(state)
	end
end

return Cinematics
