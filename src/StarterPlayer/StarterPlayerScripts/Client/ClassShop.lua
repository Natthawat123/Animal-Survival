--[[
	ClassShop — ร้านคลาสแบบ 99 Nights
	  ซ้าย  : รายการคลาส (รูปวงกลม ดาว ชื่อ ราคา/สต็อก/เลเวล) + รีโรลสต็อค + อัตราต่อรอง + เพชร
	  กลาง  : หุ่นแต่งชุดคลาสบนเวทีในเต็นท์ Classes (กล้องย้ายไปที่เวที) + ข้อกำหนดเลเวลถัดไป + ปุ่มสวมใส่/ซื้อ/ถอด
	  ขวา   : เครื่องมือเริ่มต้น + ทักษะเลเวล 1-3 (ล็อก = ข้ามด้วยเพชร)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared.Classes)
local Items = require(Shared.Items)
local MeshProps = require(Shared.MeshProps)
local Remotes = require(Shared.Remotes)
local ClassAvatars = require(script.Parent.ClassAvatars)

local ClassShop = {}

local player = Players.LocalPlayer
local C = Color3.fromRGB
local profile
local selected = "Survivor"
local ui = {}
local stage = { Model = nil, Conn = nil }

local ITEM_EMOJI = {
	Torch = "🔥", Bandage = "🩹", Medkit = "⛑", Berries = "🍇", Coal = "⚫", LogWall = "🧱", Bow = "🏹",
	OldAxe = "🪓", StoneAxe = "🪓", IronAxe = "🪓", Spear = "🔱", Wood = "🪵", Stone = "🪨",
}

---------------------------------------------------------------- ตัวช่วย UI (ตัวหนังสือหนา ขอบดำ แบบเกมการ์ตูน)
local function stroke(obj, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2
	s.Color = color or C(0, 0, 0)
	s.ApplyStrokeMode = (obj:IsA("TextLabel") or obj:IsA("TextButton")) and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

local function corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 10)
	c.Parent = obj
	return c
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = C(16, 14, 14)
	f.BackgroundTransparency = 0.3
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function text(parent, props, maxSize)
	props = props or {}
	local thickness = props.StrokeThickness or 2
	props.StrokeThickness = nil
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = C(255, 255, 255)
	t.TextScaled = true
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	t.Parent = parent
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = maxSize or 40
	lim.MinTextSize = 8
	lim.Parent = t
	if thickness > 0 then
		stroke(t, thickness)
	end
	return t
end

local function gradient(obj, a, b, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rot or 90
	g.Parent = obj
	return g
end

-- ปุ่มสีสด ขอบดำ ตัวหนังสือขาวขอบดำ
local function button(parent, props, color, onClick, maxSize)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBlack
	b.TextColor3 = C(255, 255, 255)
	b.TextScaled = true
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	b.Parent = parent
	corner(b, 8)
	gradient(b, C(255, 255, 255), C(170, 170, 170), 90)
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Color = color:Lerp(C(0, 0, 0), 0.55)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = b
	local ts = Instance.new("UIStroke")
	ts.Thickness = 2
	ts.Color = C(0, 0, 0)
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ts.Parent = b
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = maxSize or 30
	lim.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.Parent = b
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

local GREEN, RED, BLUE, PURPLE, GRAY = C(70, 200, 60), C(220, 60, 60), C(60, 170, 240), C(170, 70, 230), C(110, 110, 116)

local function data()
	return profile or { Diamonds = player:GetAttribute("Diamonds") or 0, Owned = { Survivor = true }, ClassLevel = {}, ClassStats = {}, StockDay = 0, StockRoll = 0 }
end

local function now()
	return Workspace:GetServerTimeNow()
end

local function stock()
	local d = data()
	local day = Classes.Day(now())
	local roll = (d.StockDay == day) and (d.StockRoll or 0) or 0
	return Classes.Stock(day, roll, player.UserId)
end

local function levelOf(id)
	local d = data()
	return (d.ClassLevel and d.ClassLevel[id]) or 1
end

local function stars(n)
	return string.rep("★", n)
end

---------------------------------------------------------------- เวทีโชว์หุ่น (กล้องในเต็นท์)
local function findStage()
	local lobby = Workspace:FindFirstChild("Lobby")
	return lobby and lobby:FindFirstChild("ClassStage", true)
end

local function showOnStage(id)
	if stage.Model then
		stage.Model:Destroy()
		stage.Model = nil
	end
	local st = findStage()
	if not st then
		ui.CenterView.Visible = true
		ClassAvatars.Viewport(ui.CenterView, id, false)
		return
	end
	ui.CenterView.Visible = false
	local m = ClassAvatars.Build(id)
	m.Parent = Workspace
	stage.Model = m
	stage.Base = st.CFrame * CFrame.new(0, st.Size.Y / 2, 0)
	m:PivotTo(stage.Base) -- หุ่นหัน -Z ของเวที (ฝั่งกล้อง)
	-- เสียงเอฟเฟกต์ประกายตอนเปลี่ยนคลาส
	local fx = Instance.new("Part")
	fx.Anchored, fx.CanCollide, fx.CanQuery, fx.Transparency = true, false, false, 1
	fx.Size = Vector3.new(1, 1, 1)
	fx.CFrame = stage.Base * CFrame.new(0, 3, 0)
	fx.Parent = m
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(4, 9)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.5, 0)
	e.Color = ColorSequence.new(Classes.StarColor[Classes.Data[id].Stars])
	e.Parent = fx
	e:Emit(40)
end

local function cameraToStage()
	local st = findStage()
	local cam = Workspace.CurrentCamera
	if not st then
		return
	end
	stage.PrevType = cam.CameraType
	stage.PrevFov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 40
	local base = st.CFrame * CFrame.new(0, st.Size.Y / 2, 0)
	cam.CFrame = CFrame.lookAt((base * CFrame.new(0, 6, -22)).Position, (base * CFrame.new(0, 1.3, 0)).Position)
	if stage.Conn then
		stage.Conn:Disconnect()
	end
	local t0 = os.clock()
	stage.Conn = RunService.RenderStepped:Connect(function()
		if stage.Model and stage.Base then
			local t = os.clock() - t0
			stage.Model:PivotTo(stage.Base * CFrame.Angles(0, math.sin(t * 0.8) * 0.35, 0) * CFrame.new(0, math.sin(t * 2) * 0.05, 0))
		end
	end)
end

local function restoreCamera()
	if stage.Conn then
		stage.Conn:Disconnect()
		stage.Conn = nil
	end
	if stage.Model then
		stage.Model:Destroy()
		stage.Model = nil
	end
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = stage.PrevFov or 70
end

---------------------------------------------------------------- สร้าง UI
function ClassShop.Build(gui)
	local root = frame(gui, { Name = "ClassShop", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })
	ui.Root = root

	-------------------------------------------------- ซ้าย: รายการคลาส
	local left = frame(root, { Position = UDim2.fromScale(0.015, 0.11), Size = UDim2.fromScale(0.27, 0.83), BackgroundColor3 = C(14, 12, 10), BackgroundTransparency = 0.28 })
	corner(left, 22)
	local ls = Instance.new("UIStroke")
	ls.Color, ls.Thickness, ls.Transparency, ls.Parent = C(70, 60, 48), 2, 0.3, left
	local title = text(root, { Position = UDim2.fromScale(0.015, 0.035), Size = UDim2.fromScale(0.27, 0.095), Text = "คลาส", TextColor3 = C(255, 255, 255), StrokeThickness = 3 }, 80)
	gradient(title, C(255, 244, 150), C(242, 176, 40), 90)
	ui.Restock = text(left, { Position = UDim2.fromScale(0.04, 0.03), Size = UDim2.fromScale(0.92, 0.06), Text = "- อัปเดตใน -" }, 30)
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromScale(0.08, 0.11)
	list.Size = UDim2.fromScale(0.88, 0.74)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = C(90, 80, 70)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = left
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	ui.List = list
	ui.Cards = {}
	for i, id in ipairs(Classes.Order) do
		ClassShop.MakeCard(id, i)
	end
	button(left, { Position = UDim2.fromScale(0.27, 0.87), Size = UDim2.fromScale(0.48, 0.11), Text = "รีโรลสต็อค 💎" .. Classes.RerollPrice }, C(110, 210, 50), function()
		Remotes.Get("RerollStock"):FireServer()
	end, 34)
	button(left, { Position = UDim2.fromScale(0.78, 0.9), Size = UDim2.fromScale(0.17, 0.06), Text = "อัตราต่อรอง" }, C(40, 38, 40), function()
		ui.Odds.Visible = not ui.Odds.Visible
	end, 14)
	-- กล่องอัตราต่อรอง
	local odds = frame(root, { Position = UDim2.fromScale(0.29, 0.6), Size = UDim2.fromScale(0.16, 0.3), BackgroundColor3 = C(14, 12, 10), BackgroundTransparency = 0.1, Visible = false, ZIndex = 5 })
	corner(odds, 12)
	text(odds, { Position = UDim2.fromScale(0.05, 0.02), Size = UDim2.fromScale(0.9, 0.16), Text = "โอกาสมีของในสต็อค", ZIndex = 6 }, 20)
	for s = 1, 5 do
		text(odds, {
			Position = UDim2.fromScale(0.08, 0.04 + s * 0.15), Size = UDim2.fromScale(0.84, 0.13), ZIndex = 6, TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("%s  %d%%", stars(s), math.floor(Classes.StockOdds[s] * 100)), TextColor3 = Classes.StarColor[s],
		}, 20)
	end
	ui.Odds = odds

	-- เพชรมุมซ้ายล่าง
	local gem = text(root, { Position = UDim2.fromScale(0.004, 0.9), Size = UDim2.fromScale(0.07, 0.09), Text = "💎", StrokeThickness = 0 }, 90)
	local _ = gem
	ui.Gems = text(root, { Position = UDim2.fromScale(0.01, 0.925), Size = UDim2.fromScale(0.06, 0.05), Text = "0", Rotation = -8, StrokeThickness = 3 }, 40)

	-------------------------------------------------- กลาง: ชื่อคลาส + ข้อกำหนด + ปุ่ม
	ui.Name = text(root, { Position = UDim2.fromScale(0.33, 0.08), Size = UDim2.fromScale(0.34, 0.08), Text = "", StrokeThickness = 3 }, 70)
	gradient(ui.Name, C(150, 255, 240), C(40, 200, 220), 90)
	ui.Level = text(root, { Position = UDim2.fromScale(0.38, 0.16), Size = UDim2.fromScale(0.24, 0.06), Text = "- เลเวล 1 -" }, 50)
	ui.Stars = text(root, { Position = UDim2.fromScale(0.4, 0.215), Size = UDim2.fromScale(0.2, 0.04), Text = "", TextColor3 = C(255, 200, 40) }, 36)
	ui.CenterView = Instance.new("ViewportFrame")
	ui.CenterView.Position = UDim2.fromScale(0.39, 0.26)
	ui.CenterView.Size = UDim2.fromScale(0.22, 0.34)
	ui.CenterView.BackgroundTransparency = 1
	ui.CenterView.Visible = false
	ui.CenterView.Parent = root
	local req = frame(root, { Position = UDim2.fromScale(0.36, 0.585), Size = UDim2.fromScale(0.28, 0.05), BackgroundColor3 = C(30, 26, 22), BackgroundTransparency = 0.35 })
	corner(req, 8)
	local rs = Instance.new("UIStroke")
	rs.Color, rs.Thickness, rs.Parent = C(220, 220, 220), 1.5, req
	ui.ReqTitle = text(req, { Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = C(110, 220, 255) }, 30)
	ui.Req1 = text(root, { Position = UDim2.fromScale(0.36, 0.64), Size = UDim2.fromScale(0.28, 0.045), Text = "" }, 30)
	ui.Req2 = text(root, { Position = UDim2.fromScale(0.36, 0.688), Size = UDim2.fromScale(0.28, 0.045), Text = "" }, 30)
	ui.Main = button(root, { Position = UDim2.fromScale(0.4, 0.745), Size = UDim2.fromScale(0.2, 0.08), Text = "" }, RED, function()
		ClassShop.MainAction()
	end, 46)
	button(root, { Position = UDim2.fromScale(0.42, 0.84), Size = UDim2.fromScale(0.16, 0.06), Text = "ปิด" }, RED, function()
		ClassShop.Close()
	end, 32)

	-------------------------------------------------- ขวา: เครื่องมือเริ่มต้น + ทักษะ
	local right = frame(root, { Position = UDim2.fromScale(0.715, 0.11), Size = UDim2.fromScale(0.27, 0.83), BackgroundColor3 = C(14, 12, 10), BackgroundTransparency = 0.28 })
	corner(right, 22)
	local rs2 = Instance.new("UIStroke")
	rs2.Color, rs2.Thickness, rs2.Transparency, rs2.Parent = C(70, 60, 48), 2, 0.3, right
	local toolsTitle = text(right, { Position = UDim2.fromScale(0.05, 0.03), Size = UDim2.fromScale(0.9, 0.075), Text = "เครื่องมือเริ่มต้น:" }, 44)
	gradient(toolsTitle, C(255, 244, 150), C(242, 176, 40), 90)
	ui.Tools = frame(right, { Position = UDim2.fromScale(0.05, 0.11), Size = UDim2.fromScale(0.9, 0.15), BackgroundTransparency = 1 })
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tl.Padding = UDim.new(0.03, 0)
	tl.Parent = ui.Tools
	local skillTitle = text(right, { Position = UDim2.fromScale(0.25, 0.265), Size = UDim2.fromScale(0.5, 0.065), Text = "ทักษะ:" }, 44)
	gradient(skillTitle, C(200, 240, 255), C(120, 190, 255), 90)
	ui.Skills = {}
	for lv = 1, 3 do
		local box = frame(right, { Position = UDim2.fromScale(0.04, 0.34 + (lv - 1) * 0.215), Size = UDim2.fromScale(0.92, 0.195), BackgroundColor3 = C(20, 18, 18), BackgroundTransparency = 0.25 })
		corner(box, 12)
		local bs = Instance.new("UIStroke")
		bs.Color, bs.Thickness, bs.Transparency, bs.Parent = C(70, 66, 60), 1.5, 0.2, box
		local t = text(box, { Position = UDim2.fromScale(0.05, 0.08), Size = UDim2.fromScale(0.9, 0.84), Text = "", TextWrapped = true }, 30)
		local lock = text(box, { Position = UDim2.fromScale(0.86, 0.02), Size = UDim2.fromScale(0.12, 0.3), Text = "🔒", StrokeThickness = 0, Visible = false }, 40)
		local lvTag = text(box, { Position = UDim2.fromScale(0.3, 0.02), Size = UDim2.fromScale(0.4, 0.28), Text = "เลเวล " .. lv, TextColor3 = C(255, 90, 100), Visible = false }, 34)
		local skip = button(box, { Position = UDim2.fromScale(0.6, 0.66), Size = UDim2.fromScale(0.38, 0.3), Text = "", Visible = false }, GREEN, function()
			Remotes.Get("SkipClassLevel"):FireServer(selected)
		end, 26)
		local skipLabel = text(box, { Position = UDim2.fromScale(0.38, 0.66), Size = UDim2.fromScale(0.2, 0.3), Text = "ข้าม", Visible = false }, 30)
		ui.Skills[lv] = { Box = box, Text = t, Lock = lock, Tag = lvTag, Skip = skip, SkipLabel = skipLabel }
	end
end

function ClassShop.MakeCard(id, order)
	local c = Classes.Data[id]
	local card = Instance.new("TextButton")
	card.Text = ""
	card.AutoButtonColor = false
	card.BackgroundColor3 = C(10, 10, 12)
	card.BackgroundTransparency = 0.12
	card.Size = UDim2.new(1, -12, 0, 124)
	card.LayoutOrder = order
	card.Parent = ui.List
	corner(card, 6)
	local cs = Instance.new("UIStroke")
	cs.Color, cs.Thickness, cs.ApplyStrokeMode, cs.Parent = C(44, 44, 48), 2, Enum.ApplyStrokeMode.Border, card
	-- รูปวงกลม
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromOffset(112, 112)
	vp.Position = UDim2.fromOffset(6, 6)
	vp.BackgroundColor3 = C(60, 58, 64)
	vp.Parent = card
	corner(vp, UDim.new(0.5, 0))
	local ring = Instance.new("UIStroke")
	ring.Color, ring.Thickness, ring.Parent = Classes.StarColor[c.Stars], 4, vp
	gradient(vp, C(255, 255, 255), C(150, 150, 160), 90)
	task.spawn(ClassAvatars.Viewport, vp, id, true)
	local badge = text(card, { Position = UDim2.fromOffset(4, 82), Size = UDim2.fromOffset(118, 34), Text = "", ZIndex = 3 }, 26)
	text(card, { Position = UDim2.new(0, 126, 0, 8), Size = UDim2.new(0.42, -120, 0, 30), Text = stars(c.Stars), TextColor3 = C(255, 196, 40), TextXAlignment = Enum.TextXAlignment.Left }, 28)
	text(card, { Position = UDim2.new(0.42, 0, 0, 6), Size = UDim2.new(0.56, 0, 0, 40), Text = c.Thai, TextXAlignment = Enum.TextXAlignment.Right }, 32)
	local price = text(card, { Position = UDim2.new(0, 126, 1, -50), Size = UDim2.new(0.3, -60, 0, 40), Text = "", TextXAlignment = Enum.TextXAlignment.Left }, 32)
	local btn = button(card, { Position = UDim2.new(0.56, 0, 1, -54), Size = UDim2.new(0.42, 0, 0, 44), Text = "" }, BLUE, nil, 26)
	local function pick()
		selected = id
		ClassShop.Refresh()
		showOnStage(id)
	end
	card.Activated:Connect(pick)
	btn.Activated:Connect(pick)
	ui.Cards[id] = { Card = card, Stroke = cs, Badge = badge, Price = price, Button = btn }
end

---------------------------------------------------------------- อัปเดตข้อมูล
local function setButton(b, txt, color)
	b.Text = txt
	b.BackgroundColor3 = color
	local s = b:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = color:Lerp(C(0, 0, 0), 0.55)
	end
end

function ClassShop.Refresh()
	if not ui.Root then
		return
	end
	local d = data()
	local st = stock()
	local current = player:GetAttribute("Class") or "Survivor"
	ui.Gems.Text = tostring(player:GetAttribute("Diamonds") or d.Diamonds or 0)
	local s = Classes.SecondsToRestock(now())
	ui.Restock.Text = string.format("- อัปเดตใน %dชั่วโมง %dนาที -", s // 3600, (s % 3600) // 60)
	for id, cd in pairs(ui.Cards) do
		local c = Classes.Data[id]
		local owned = d.Owned and d.Owned[id]
		cd.Stroke.Color = (id == selected) and C(255, 220, 40) or C(44, 44, 48)
		cd.Stroke.Thickness = (id == selected) and 3.5 or 2
		if id == current then
			cd.Badge.Text, cd.Badge.TextColor3 = "สวมใส่แล้ว", C(255, 220, 40)
		elseif owned then
			cd.Badge.Text, cd.Badge.TextColor3 = "มีแล้ว", C(130, 240, 90)
		else
			cd.Badge.Text = ""
		end
		if owned then
			cd.Price.Text = ""
			setButton(cd.Button, "เลเวล " .. levelOf(id), BLUE)
		else
			cd.Price.Text = "💎" .. c.Price
			if st[id] then
				setButton(cd.Button, "มีสินค้าคงคลัง", GREEN)
			else
				setButton(cd.Button, "ไม่มีสต๊อค", RED)
			end
		end
	end
	-- กลาง
	local c = Classes.Data[selected]
	local owned = d.Owned and d.Owned[selected]
	local lv = levelOf(selected)
	ui.Name.Text = c.Thai
	ui.Level.Text = owned and string.format("- เลเวล %d -", lv) or "- ยังไม่ปลดล็อก -"
	ui.Stars.Text = stars(c.Stars)
	local stats = (d.ClassStats and d.ClassStats[selected]) or {}
	local reqLv = math.min(lv + 1, Classes.MaxLevel)
	local req = Classes.Requirement(selected, lv + 1)
	if not owned then
		ui.ReqTitle.Text = "- ซื้อเพื่อเริ่มเก็บเลเวล -"
		ui.Req1.Text = string.format("ราคา: 💎%d   (มี 💎%d)", c.Price, player:GetAttribute("Diamonds") or 0)
		ui.Req2.Text = st[selected] and "✅ มีในสต็อควันนี้" or "❌ ไม่มีสต๊อค — รอรีสต็อกหรือรีโรล"
	elseif req then
		ui.ReqTitle.Text = string.format("- ข้อกำหนดของเลเวล %d -", reqLv)
		local lines = {}
		for _, k in ipairs(Classes.StatOrder) do
			table.insert(lines, string.format("%s: %d/%d", Classes.StatNames[k], math.min(stats[k] or 0, req[k]), req[k]))
		end
		ui.Req1.Text = lines[1] or ""
		ui.Req2.Text = lines[2] or ""
	else
		ui.ReqTitle.Text = "- เลเวลสูงสุดแล้ว -"
		ui.Req1.Text = string.format("ล่าสัตว์: %d  ·  รอดคืน: %d", stats.Kills or 0, stats.Nights or 0)
		ui.Req2.Text = "⭐ ปลดทักษะครบทุกขั้น"
	end
	if selected == current then
		setButton(ui.Main, selected == "Survivor" and "สวมใส่แล้ว" or "ถอดอุปกรณ์", selected == "Survivor" and GRAY or RED)
	elseif owned then
		setButton(ui.Main, "สวมใส่", GREEN)
	elseif st[selected] then
		setButton(ui.Main, "ซื้อ 💎" .. c.Price, GREEN)
	else
		setButton(ui.Main, "ไม่มีสต๊อค", GRAY)
	end
	-- ขวา: เครื่องมือ
	for _, ch in ipairs(ui.Tools:GetChildren()) do
		if ch:IsA("Frame") then
			ch:Destroy()
		end
	end
	local order = 0
	for itemId, n in pairs(c.StartItems) do
		order += 1
		local slot = frame(ui.Tools, { Size = UDim2.fromScale(0.3, 1), BackgroundTransparency = 1, LayoutOrder = order })
		local icon = Instance.new("ViewportFrame")
		icon.Size = UDim2.fromScale(0.7, 0.62)
		icon.BackgroundTransparency = 1
		icon.Parent = slot
		local emoji = text(slot, { Size = UDim2.fromScale(0.7, 0.62), Text = ITEM_EMOJI[itemId] or "📦", StrokeThickness = 0 }, 60)
		text(slot, { Position = UDim2.fromScale(0.62, 0.15), Size = UDim2.fromScale(0.38, 0.4), Text = "x" .. n }, 30)
		text(slot, { Position = UDim2.fromScale(0, 0.66), Size = UDim2.fromScale(1, 0.3), Text = Items.DisplayName(itemId) }, 18)
		if MeshProps.Has(itemId) then
			task.spawn(function()
				local ok, model = pcall(MeshProps.Build, itemId)
				if ok and model and icon.Parent then
					local wm = Instance.new("WorldModel")
					wm.Parent = icon
					model.Parent = wm
					local cf, size = model:GetBoundingBox()
					local cam = Instance.new("Camera")
					cam.FieldOfView = 30
					local dist = size.Magnitude * 1.7
					cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.6, dist * 0.35, dist * 0.7), cf.Position)
					cam.Parent = icon
					icon.CurrentCamera = cam
					emoji.Visible = false
				end
			end)
		end
	end
	-- ทักษะ
	for i, sk in ipairs(ui.Skills) do
		local unlocked = owned and lv >= i
		sk.Text.Text = c.Skills[i].Text
		sk.Text.TextTransparency = unlocked and 0 or 0.55
		sk.Lock.Visible = not unlocked
		sk.Tag.Visible = not unlocked
		sk.Box.BackgroundTransparency = unlocked and 0.25 or 0.45
		local canSkip = owned and i == lv + 1
		sk.Skip.Visible = canSkip
		sk.SkipLabel.Visible = canSkip
		if canSkip then
			sk.Skip.Text = "💎 " .. Classes.SkipPrice(selected, i)
		end
	end
end

function ClassShop.MainAction()
	local d = data()
	local current = player:GetAttribute("Class") or "Survivor"
	local owned = d.Owned and d.Owned[selected]
	if selected == current then
		if selected ~= "Survivor" then
			Remotes.Get("ChooseClass"):FireServer("Survivor") -- ถอด = กลับเป็นผู้รอดชีวิต
		end
	elseif owned then
		Remotes.Get("ChooseClass"):FireServer(selected)
	elseif stock()[selected] then
		Remotes.Get("BuyClass"):FireServer(selected)
	end
end

function ClassShop.SetProfile(p)
	profile = p
	if ui.Root and ui.Root.Visible then
		ClassShop.Refresh()
	end
end

function ClassShop.IsOpen()
	return ui.Root and ui.Root.Visible
end

function ClassShop.Open()
	if not ui.Root then
		return
	end
	selected = player:GetAttribute("Class") or "Survivor"
	ui.Root.Visible = true
	ui.Odds.Visible = false
	cameraToStage()
	showOnStage(selected)
	ClassShop.Refresh()
	if ClassShop.OnVisibility then
		ClassShop.OnVisibility(true)
	end
end

function ClassShop.Close()
	if not (ui.Root and ui.Root.Visible) then
		return
	end
	ui.Root.Visible = false
	restoreCamera()
	if ClassShop.OnVisibility then
		ClassShop.OnVisibility(false)
	end
end

function ClassShop.Init(gui)
	ClassShop.Build(gui)
	player:GetAttributeChangedSignal("Diamonds"):Connect(function()
		if ClassShop.IsOpen() then
			ClassShop.Refresh()
		end
	end)
	player:GetAttributeChangedSignal("Class"):Connect(function()
		if ClassShop.IsOpen() then
			ClassShop.Refresh()
		end
	end)
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		if player:GetAttribute("InRun") then
			ClassShop.Close()
		end
	end)
	-- นาฬิการีสต็อก
	task.spawn(function()
		while true do
			task.wait(20)
			if ClassShop.IsOpen() then
				ClassShop.Refresh()
			end
		end
	end)
end

return ClassShop
