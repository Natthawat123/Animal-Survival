--[[
	Tutorial — หน้าสอนเล่นแบบช่องการ์ตูน (โชว์ครั้งแรกหลังโหลดเข้าล็อบบี้ / เปิดซ้ำได้จากหน้าตั้งค่า "ดูวิธีเล่น")
	  หน้าเดียว 4 × 2 ช่อง: ภาพในช่องเป็นโมเดลจริงในเกม (ViewportFrame) + คำบรรยายตัวโต
	  หน้าสุดท้ายมีปุ่ม "เล่น" สีเขียว · ดูจบแล้วเซิร์ฟเวอร์จำไว้ (TutorialSeen) ไม่โชว์ซ้ำ
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local StructureModels = require(Shared.StructureModels)
local UIKit = require(script.Parent.UIKit)
local TutorialArt = require(Shared.TutorialArt)
local ClassAvatars = require(script.Parent.ClassAvatars)

local Tutorial = {}
local C = UIKit.Colors
local ui = {}
local currentWorld -- WorldModel ของช่องที่กำลังสร้าง (ของในฉากถูกใส่ที่นี่)

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

---------------------------------------------------------------- ฉากในช่อง (โมเดลจริง)
local function asset(folder, name)
	local a = ReplicatedStorage:FindFirstChild("Assets")
	local f = a and a:FindFirstChild(folder)
	local src = f and f:FindFirstChild(name)
	if not src then
		return nil
	end
	local m = src:Clone()
	if m:IsA("BasePart") then
		local wrap = Instance.new("Model")
		m.Parent = wrap
		wrap.PrimaryPart = m
		m = wrap
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	return m
end

-- ย่อ/ขยายให้สูงตามต้องการ แล้ววางเท้าที่ cf
local function place(m, height, cf)
	if not m then
		return nil
	end
	m.Parent = currentWorld
	local _, size = m:GetBoundingBox()
	if size.Y > 0.05 and height then
		pcall(function()
			m:ScaleTo(m:GetScale() * height / size.Y)
		end)
	end
	local bcf, bsize = m:GetBoundingBox()
	local pivot = m:GetPivot()
	local footOffset = pivot.Position.Y - (bcf.Position.Y - bsize.Y / 2)
	local centerOffset = pivot.Position - bcf.Position
	m:PivotTo(cf * CF(centerOffset.X, footOffset, centerOffset.Z) * (pivot - pivot.Position))
	return m
end

local function character(classId, cf)
	local ok, m = pcall(ClassAvatars.Build, classId)
	if ok and m then
		m.Parent = currentWorld
		m:PivotTo(cf)
		return m
	end
	return nil
end

local function structure(kind, cf)
	local ok, m = pcall(StructureModels.Build, kind)
	if ok and m then
		m.Parent = currentWorld
		m:PivotTo(cf)
		return m
	end
	return nil
end

-- กล้องมองทั้งฉากจากมุมที่กำหนด
local function frameCamera(vpf, world, yaw, pitch, zoom)
	local cf, size = world:GetBoundingBox()
	local radius = size.Magnitude / 2
	local dist = radius / math.tan(math.rad(18)) * (zoom or 1)
	local dir = (ANG(0, yaw or 0.6, 0) * ANG(-(pitch or 0.25), 0, 0)).LookVector
	local cam = Instance.new("Camera")
	cam.FieldOfView = 36
	cam.CFrame = CFrame.lookAt(cf.Position - dir * dist, cf.Position)
	cam.Parent = vpf
	vpf.CurrentCamera = cam
end

local PUPS = { "TerraPup", "TidePup", "GalePup", "EmberPup" }

local SCENES = {
	function(world) -- 1 เข้าสู่โลกอดีต: ประตูมิติ + นักสำรวจ
		place(asset("Props", "GateStargate"), 12, CF(0, 0, -6))
		character("Scout", CF(-3.5, 0, 3) * ANG(0, math.pi - 0.5, 0))
		return { Yaw = 0.35, Pitch = 0.08, Zoom = 0.72, Sky = { rgb(70, 40, 140), rgb(18, 12, 46) }, Light = rgb(200, 170, 255) }
	end,
	function(world) -- 2 รวบรวมทรัพยากร
		place(asset("Props", "Fir1"), 14, CF(4, 0, -3))
		place(asset("Props", "RockLP"), 3.2, CF(-5, 0, -1))
		character("Lumberjack", CF(0, 0, 2) * ANG(0, math.pi / 2 + 0.6, 0))
		return { Yaw = -0.3, Pitch = 0.16, Zoom = 0.78, Sky = { rgb(110, 170, 220), rgb(60, 120, 70) } }
	end,
	function(world) -- 3 สร้างแคมป์ให้แข็งแรง
		place(asset("Props", "CampfireLogs"), 3.5, CF(-1, 0, 2))
		structure("LogWall", CF(0, 0, -5) * ANG(0, math.pi / 2, 0))
		structure("SpikeTrap", CF(5, 0, 3))
		character("Builder", CF(-5, 0, 0) * ANG(0, -math.pi / 2 - 0.5, 0))
		return { Yaw = 0.25, Pitch = 0.28, Zoom = 0.8, Sky = { rgb(90, 60, 30), rgb(26, 18, 12) }, Light = rgb(255, 190, 120) }
	end,
	function(world) -- 4 เอาชีวิตรอดในแต่ละคืน: จิ้งจอกเงา
		place(asset("Animals", "Moonfang"), 8, CF(0, 0, -2) * ANG(0, math.pi + 0.4, 0))
		place(asset("Props", "CampfireLogs"), 2.6, CF(-6, 0, 4))
		return { Yaw = -0.2, Pitch = 0.1, Zoom = 0.72, Sky = { rgb(30, 26, 80), rgb(6, 6, 18) }, Light = rgb(170, 160, 255) }
	end,
	function(world) -- 5 ระวังบอสธาตุ
		place(asset("Animals", "Terragon"), 13, CF(0, 0, -2) * ANG(0, math.pi + 0.5, 0))
		character("Hunter", CF(4, 0, 8) * ANG(0, 0.4, 0))
		return { Yaw = 0.5, Pitch = 0.1, Zoom = 0.7, Sky = { rgb(110, 30, 24), rgb(24, 6, 6) }, Light = rgb(255, 150, 120) }
	end,
	function(world) -- 6 ผจญภัย 4 ไบโอม: คริสตัล 4 ธาตุ
		local crystals = { "CrystalGreen", "CrystalBlue", "CrystalWhite", "CrystalRed" }
		for i, g in ipairs(crystals) do
			place(asset("Props", g), 5, CF((i - 2.5) * 5, 0, 0))
		end
		return { Yaw = 0, Pitch = 0.12, Zoom = 0.62, Sky = { rgb(70, 150, 200), rgb(150, 60, 30) } }
	end,
	function(world) -- 7 ช่วยเหลือสัตว์ทั้ง 4 ตัว: กรง + ลูกสัตว์
		place(asset("Props", "CageLP"), 6, CF(0, 0, -4))
		for i, p in ipairs(PUPS) do
			place(asset("Animals", p), 2.6, CF((i - 2.5) * 3, 0, 2) * ANG(0, math.pi, 0))
		end
		return { Yaw = 0, Pitch = 0.2, Zoom = 0.72, Sky = { rgb(80, 60, 40), rgb(24, 16, 10) }, Light = rgb(255, 220, 170) }
	end,
	function(world) -- 8 รอดครบ 99 คืน และกลับบ้าน
		place(asset("Props", "GateStargate"), 12, CF(0, 0, -7))
		for i, p in ipairs(PUPS) do
			place(asset("Animals", p), 2.4, CF((i - 2.5) * 3, 0, 2) * ANG(0, math.pi, 0))
		end
		return { Yaw = 0, Pitch = 0.1, Zoom = 0.7, Sky = { rgb(120, 80, 200), rgb(30, 16, 60) }, Light = rgb(255, 225, 160) }
	end,
}

-- ข้อความตามภาพต้นแบบที่ผู้ใช้ส่งมา (หน้าเดียว 8 ช่อง)
local PANELS = {
	{ Title = "Into the past", Text = "An experiment went wrong\nand everyone was pulled through the portal\ninto the ancient world" },
	{ Title = "Gather resources", Text = "Chop trees, mine rocks, collect materials\nto craft tools, weapons\nand upgrade your camp" },
	{ Title = "Build a strong camp", Text = "Build shelter, walls and defenses\nto get ready for the attacks at night" },
	{ Title = "Survive every night", Text = "Defend the camp from wild beasts\nand the shadow wolf-fox that keeps attacking" },
	{ Title = "Beware the mysterious tribe", Text = "Fight off attacks, set traps\nand stop the tribe\nthat gets in the way of your mission" },
	{ Title = "Explore the 4 biomes", Text = "Explore 4 lands: the primeval forest,\nthe forgotten desert, the ice kingdom and the volcano lands\nand face the boss of each biome" },
	{ Title = "Rescue all 4 animals", Text = "Find where the captured animals are held,\ndefeat the enemies and free them\nback to camp — all 4 of them" },
	{ Title = "Survive 99 nights & go home", Text = "Survive all 99 nights,\nrescue all 4 animals\nand activate the portal\nto travel back to the present!" },
}

---------------------------------------------------------------- ช่องภาพ
local function comicPanel(parent, index)
	local info = PANELS[index]
	local holder = UIKit.Frame(parent, { BackgroundColor3 = rgb(40, 42, 58), BackgroundTransparency = 0, LayoutOrder = index })
	UIKit.Corner(holder, 12)
	local hs = Instance.new("UIStroke")
	hs.Thickness = 3
	hs.Color = rgb(225, 200, 150)
	hs.Parent = holder
	local frame = UIKit.Frame(holder, { Size = UDim2.new(1, -12, 0.52, 0), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = rgb(14, 14, 20), BackgroundTransparency = 0, ClipsDescendants = true })
	UIKit.Corner(frame, 8)
	-- ฉากหลังไล่สี (อยู่ใต้ ViewportFrame — ถ้าใส่ UIGradient ที่ ViewportFrame โมเดลจะมืดตาม)
	local skyBg = UIKit.Frame(frame, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0 })
	UIKit.Corner(skyBg, 8)
	local vpf = Instance.new("ViewportFrame")
	vpf.Size = UDim2.fromScale(1, 1)
	vpf.BackgroundTransparency = 1
	vpf.BorderSizePixel = 0
	vpf.Parent = frame
	local world = Instance.new("WorldModel")
	world.Parent = vpf
	-- ภาพวาดตามแบบ (Shared/TutorialArt จาก tools/tutorial_art.py) · วาดไม่ได้ -> ใช้ฉากโมเดล 3D แทน
	local okArt, editable = pcall(TutorialArt.Image, "Tut" .. index)
	local art = okArt and editable or nil
	if art then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.ImageContent = Content.fromObject(art)
		img.ScaleType = Enum.ScaleType.Crop
		img.ZIndex = 2
		img.Parent = frame
		UIKit.Corner(img, 8)
	end
	currentWorld = world
	local ok, opts = true, {}
	if not art then
		ok, opts = pcall(SCENES[index], world)
	end
	currentWorld = nil
	opts = ok and opts or {}
	if not ok then
		warn("[AS] tutorial scene", index, opts)
	end
	local sky = opts.Sky or { rgb(30, 30, 50), rgb(10, 10, 20) }
	UIKit.Gradient(skyBg, sky[1], sky[2], 90)
	vpf.Ambient = rgb(150, 150, 165)
	vpf.LightColor = opts.Light or rgb(255, 245, 230)
	vpf.LightDirection = V(-0.5, -1, -0.4)
	-- เลขช่อง
	UIKit.IconBadge(holder, tostring(index), C.Gold, 50, { Position = UDim2.fromOffset(-6, -6), ZIndex = 6 }) -- ทับเลขที่วาดติดมากับภาพ
	-- หัวข้อ + คำอธิบายสั้น
	UIKit.Text(holder, {
		Size = UDim2.new(1, -12, 0, 30), Position = UDim2.new(0, 6, 0.52, -12), Text = info.Title, Font = UIKit.Fonts.Title, TextSize = 25, TextScaled = false,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.new(1, 1, 1), TextWrapped = true, ZIndex = 5,
		TextStrokeTransparency = 0, TextStrokeColor3 = rgb(20, 14, 10),
	})
	UIKit.Text(holder, {
		Size = UDim2.new(1, -12, 0.48, -28), Position = UDim2.new(0, 6, 0.52, 22), Text = info.Text, Font = UIKit.Fonts.Black, TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
	})
	return holder, vpf, world, opts
end

local function buildPage()
	for _, c in ipairs(ui.Grid:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for index = 1, #PANELS do
		local holder, vpf, world, opts = comicPanel(ui.Grid, index)
		pcall(frameCamera, vpf, world, opts.Yaw, opts.Pitch, opts.Zoom)
		-- เด้งเข้าทีละช่อง
		local sc = Instance.new("UIScale")
		sc.Scale = 0.6
		sc.Parent = holder
		TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (index - 1) * 0.06), { Scale = 1 }):Play()
	end
end

function Tutorial.Open()
	ui.Root.Visible = true
	UIKit.Pop(ui.Card)
	local ok, err = pcall(buildPage)
	if not ok then
		-- สร้างหน้าไม่สำเร็จ: ปิดไปเลย ไม่ปล่อยให้พื้นหลังมืดบังจอ
		warn("[AS] tutorial", err)
		ui.Root.Visible = false
	end
end

function Tutorial.Close()
	ui.Root.Visible = false
	Remotes.Get("TutorialDone"):FireServer()
	if Tutorial.OnClosed then
		Tutorial.OnClosed()
	end
end

function Tutorial.IsOpen()
	return ui.Root ~= nil and ui.Root.Visible
end

function Tutorial.Init(gui)
	local root = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Visible = false, Active = true })
	ui.Root = root
	local card = UIKit.Card(root, {
		Size = UDim2.fromOffset(1240, 620), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = rgb(30, 32, 44),
	})
	ui.Card = card
	UIKit.AutoScale(card)
	UIKit.Header(card, "📖 Survival Guide", C.Orange)
	-- 4 x 2 ช่อง
	local grid = UIKit.Frame(card, { Size = UDim2.new(1, -56, 1, -136), Position = UDim2.fromOffset(28, 42), BackgroundTransparency = 1 })
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.25, -15, 0.5, -9)
	layout.CellPadding = UDim2.fromOffset(20, 18)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	ui.Grid = grid
	UIKit.Text(card, { Size = UDim2.fromOffset(200, 24), Position = UDim2.new(0, 30, 1, -58), Text = string.format("Page %d / %d", 1, 1), TextSize = 18, TextColor3 = C.TextDim })
	UIKit.ColorButton(card, C.Green, { Size = UDim2.fromOffset(380, 66), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -84), Text = "Start the adventure! ▶", TextSize = 32, Font = UIKit.Fonts.Title }, Tutorial.Close)
	local close = UIKit.ColorButton(card, rgb(70, 74, 110), { Size = UDim2.fromOffset(150, 48), Position = UDim2.new(1, -180, 1, -74), Text = "Close", TextSize = 22, Font = UIKit.Fonts.Title }, Tutorial.Close)
	UIKit.EnsureTouchSize(close, 44, Tutorial.Close)
	-- Esc = ปิด (ไม่ปิดเมื่อแตะนอกการ์ด กันกดพลาดตอนอ่าน)
	UIKit.RegisterWindow(root, Tutorial.Close, { Backdrop = false })
end

return Tutorial
