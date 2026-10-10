--[[
	Tutorial — หน้าสอนเล่นแบบช่องการ์ตูน (โชว์ครั้งแรกหลังโหลดเข้าล็อบบี้ / เปิดซ้ำได้จากหน้าตั้งค่า "ดูวิธีเล่น")
	  2 หน้า × 4 ช่อง: ภาพในช่องเป็นโมเดลจริงในเกม (ViewportFrame) + คำบรรยายตัวโต
	  หน้าสุดท้ายมีปุ่ม "เล่น" สีเขียว · ดูจบแล้วเซิร์ฟเวอร์จำไว้ (TutorialSeen) ไม่โชว์ซ้ำ
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local StructureModels = require(Shared.StructureModels)
local UIKit = require(script.Parent.UIKit)
local ClassAvatars = require(script.Parent.ClassAvatars)

local Tutorial = {}
local C = UIKit.Colors
local ui = {}
local page = 1
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

local SCENES = {
	function(world) -- ป่าสี่ธาตุ
		place(asset("Props", "Fir1"), 16, CF(-7, 0, -4))
		place(asset("Props", "OakPack"), 13, CF(7, 0, -6))
		place(asset("Props", "SnowPine"), 12, CF(0, 0, -12))
		character("Survivor", CF(0, 0, 3) * ANG(0, math.pi + 0.3, 0))
		return { Yaw = 0, Pitch = 0.12, Zoom = 0.75, Sky = { rgb(20, 24, 60), rgb(70, 40, 90) } }
	end,
	function(world) -- กองไฟ
		place(asset("Props", "CampfireLogs"), 4, CF(0, 0, 0))
		place(asset("Props", "LogPileStore"), 3, CF(6, 0, -3))
		character("Firekeeper", CF(-4.5, 0, 2) * ANG(0, -math.pi / 2 - 0.8, 0))
		return { Yaw = 0.4, Pitch = 0.3, Zoom = 0.85, Sky = { rgb(60, 26, 14), rgb(20, 10, 10) }, Light = rgb(255, 170, 90) }
	end,
	function(world) -- เก็บของ
		place(asset("Props", "Fir1"), 15, CF(4, 0, -3))
		place(asset("Props", "RockLP"), 3.5, CF(-5, 0, -2))
		character("Lumberjack", CF(0, 0, 2) * ANG(0, math.pi / 2 + 0.6, 0))
		return { Yaw = -0.3, Pitch = 0.18, Zoom = 0.78, Sky = { rgb(40, 90, 60), rgb(16, 36, 26) } }
	end,
	function(world) -- คราฟต์ & สร้าง
		place(asset("Props", "Crafter"), 6, CF(-4, 0, -2))
		structure("LogWall", CF(5, 0, -1) * ANG(0, 0.4, 0))
		structure("SpikeTrap", CF(3, 0, 4))
		character("Builder", CF(0.5, 0, 2) * ANG(0, math.pi + 0.5, 0))
		return { Yaw = 0.2, Pitch = 0.25, Zoom = 0.8, Sky = { rgb(70, 60, 30), rgb(26, 22, 14) } }
	end,
	function(world) -- กลางคืนฝูงบุก
		place(asset("Props", "CampfireLogs"), 3.5, CF(-6, 0, 2))
		structure("LogWall", CF(0, 0, 0) * ANG(0, math.pi / 2, 0))
		structure("Ballista", CF(-3, 0, -4))
		character("Hunter", CF(-3, 0, 4) * ANG(0, -math.pi / 2, 0))
		return { Yaw = -0.9, Pitch = 0.22, Zoom = 0.8, Sky = { rgb(12, 14, 40), rgb(6, 6, 14) }, Light = rgb(150, 170, 255) }
	end,
	function(world) -- บอส
		place(asset("Animals", "Terragon"), 14, CF(0, 0, -2) * ANG(0, math.pi + 0.5, 0))
		character("Survivor", CF(4, 0, 8) * ANG(0, 0.4, 0))
		return { Yaw = 0.5, Pitch = 0.1, Zoom = 0.7, Sky = { rgb(90, 20, 20), rgb(20, 6, 6) }, Light = rgb(255, 140, 120) }
	end,
	function(world) -- ช่วยเพื่อน
		local downed = character("Survivor", CF(2, 1, 0) * ANG(0, 0.3, 0) * ANG(math.rad(-90), 0, 0))
		local _ = downed
		character("Medic", CF(-2, 0, 0.5) * ANG(0, -math.pi / 2, 0))
		return { Yaw = 0.25, Pitch = 0.35, Zoom = 0.9, Sky = { rgb(70, 20, 30), rgb(20, 8, 12) } }
	end,
	function(world) -- 99 คืน
		place(asset("Props", "CampfireLogs"), 3.5, CF(0, 0, 0))
		character("Elementalist", CF(-3.5, 0, 1) * ANG(0, math.pi + 0.6, 0))
		character("Beastwarden", CF(3.5, 0, 1) * ANG(0, math.pi - 0.6, 0))
		character("Scout", CF(0, 0, -3.5) * ANG(0, 0, 0))
		return { Yaw = 0, Pitch = 0.3, Zoom = 0.85, Sky = { rgb(90, 70, 20), rgb(30, 16, 6) }, Light = rgb(255, 210, 140) }
	end,
}

local PANELS = {
	{ Title = "ผืนป่าสี่ธาตุตื่นขึ้นแล้ว", Text = "เอาชีวิตรอดในป่าแห่ง ดิน น้ำ ลม ไฟ ให้ได้ 99 คืน" },
	{ Title = "กองไฟคือชีวิต", Text = "โยนไม้/ถ่านเข้ากองไฟ — ไฟดับ = เขตปลอดภัยหาย!" },
	{ Title = "ออกหาของตอนกลางวัน", Text = "ตัดไม้ ทุบหิน ล่าสัตว์ ถือกระสอบแล้วเก็บของ" },
	{ Title = "คราฟต์ & สร้างฐาน", Text = "โยนวัตถุดิบลงเครื่องคราฟต์ แล้วสร้างกำแพง กับดัก หน้าไม้" },
	{ Title = "กลางคืน ฝูงสัตว์บุก!", Text = "ฝูงธาตุบุกกองไฟทุกคืน — ป้องกันให้ถึงเช้า" },
	{ Title = "บอสธาตุ", Text = "คืน 25 · 50 · 75 · 99 บอสบุก — หลบวงเตือนบนพื้น!" },
	{ Title = "ช่วยเพื่อนที่ล้ม", Text = "ใช้ผ้าพันแผลช่วยเพื่อน — ไม่เหลือใครยืนอยู่ = แพ้ทั้งทีม" },
	{ Title = "99 คืน... และไกลกว่านั้น", Text = "รอดครบ 99 คืน = พิชิต! เล่นต่อเพื่อขึ้นกระดานอันดับ" },
}

---------------------------------------------------------------- ช่องการ์ตูน
local function comicPanel(parent, index)
	local info = PANELS[index]
	local holder = UIKit.Frame(parent, { BackgroundTransparency = 1, LayoutOrder = index })
	local frame = UIKit.Frame(holder, { Size = UDim2.new(1, 0, 0.62, 0), BackgroundColor3 = rgb(14, 14, 20), BackgroundTransparency = 0, Rotation = (index % 2 == 0) and 1.2 or -1.2 })
	UIKit.Corner(frame, 6)
	local st = Instance.new("UIStroke")
	st.Thickness = 5
	st.Color = rgb(240, 236, 226)
	st.Parent = frame
	-- ฉากหลังไล่สี (อยู่ใต้ ViewportFrame — ถ้าใส่ UIGradient ที่ ViewportFrame โมเดลจะมืดตาม)
	local skyBg = UIKit.Frame(frame, { Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0 })
	UIKit.Corner(skyBg, 4)
	local vpf = Instance.new("ViewportFrame")
	vpf.Size = UDim2.new(1, -10, 1, -10)
	vpf.Position = UDim2.fromOffset(5, 5)
	vpf.BackgroundTransparency = 1
	vpf.BorderSizePixel = 0
	vpf.Parent = frame
	local world = Instance.new("WorldModel")
	world.Parent = vpf
	currentWorld = world
	local ok, opts = pcall(SCENES[index], world)
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
	local num = UIKit.IconBadge(frame, tostring(index), C.Gold, 40, { Position = UDim2.fromOffset(-12, -12), ZIndex = 6 })
	local _ = num
	-- คำบรรยาย
	UIKit.Text(holder, {
		Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0.64, 4), Text = info.Title, Font = UIKit.Fonts.Title, TextSize = 26, TextScaled = false,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Gold, TextWrapped = true,
	})
	UIKit.Text(holder, {
		Size = UDim2.new(1, 0, 0.3, -40), Position = UDim2.new(0, 0, 0.64, 40), Text = info.Text, Font = UIKit.Fonts.Black, TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
	})
	return holder, vpf, world, opts
end

local function buildPage(p)
	for _, c in ipairs(ui.Row:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i = 1, 4 do
		local index = (p - 1) * 4 + i
		local holder, vpf, world, opts = comicPanel(ui.Row, index)
		pcall(frameCamera, vpf, world, opts.Yaw, opts.Pitch, opts.Zoom)
		-- เด้งเข้าทีละช่อง
		local sc = Instance.new("UIScale")
		sc.Scale = 0.6
		sc.Parent = holder
		TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (i - 1) * 0.12), { Scale = 1 }):Play()
	end
	ui.PageLabel.Text = string.format("หน้า %d / %d", p, #PANELS // 4)
	ui.Prev.Visible = p > 1
	ui.Next.Text = p < #PANELS // 4 and "ถัดไป ▶" or "เล่น!"
	ui.Next.BackgroundColor3 = p < #PANELS // 4 and C.Blue or C.Green
end

function Tutorial.Open()
	page = 1
	ui.Root.Visible = true
	UIKit.Pop(ui.Card)
	local ok, err = pcall(buildPage, page)
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
		Size = UDim2.fromOffset(1220, 560), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = rgb(26, 26, 34),
	})
	ui.Card = card
	UIKit.Header(card, "📖 วิธีเอาชีวิตรอด", C.Orange)
	local row = UIKit.Frame(card, { Size = UDim2.new(1, -60, 1, -150), Position = UDim2.fromOffset(30, 44), BackgroundTransparency = 1 })
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.25, -18, 1, 0)
	grid.CellPadding = UDim2.fromOffset(24, 0)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = row
	ui.Row = row
	ui.PageLabel = UIKit.Text(card, { Size = UDim2.fromOffset(200, 24), Position = UDim2.new(0, 30, 1, -66), Text = "", TextSize = 18, TextColor3 = C.TextDim })
	ui.Prev = UIKit.ColorButton(card, rgb(90, 96, 140), { Size = UDim2.fromOffset(180, 56), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, -200, 1, -84), Text = "◀ ก่อนหน้า", TextSize = 24, Font = UIKit.Fonts.Title }, function()
		page = math.max(1, page - 1)
		buildPage(page)
	end)
	ui.Next = UIKit.ColorButton(card, C.Green, { Size = UDim2.fromOffset(340, 64), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 80, 1, -90), Text = "ถัดไป ▶", TextSize = 34, Font = UIKit.Fonts.Title }, function()
		if page < #PANELS // 4 then
			page += 1
			buildPage(page)
		else
			Tutorial.Close()
		end
	end)
	local skip = UIKit.Button(card, { Size = UDim2.fromOffset(120, 34), Position = UDim2.new(1, -150, 1, -62), Text = "ข้าม", TextSize = 16 }, Tutorial.Close)
	local _ = skip
end

return Tutorial
