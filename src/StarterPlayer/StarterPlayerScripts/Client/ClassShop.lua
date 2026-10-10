--[[
	ClassShop — ร้านคลาส (แบบ 99 Nights) เวอร์ชันออกแบบใหม่
	  ซ้าย  : รายการคลาส — รูปตัวละครวงกลม (กรอบสีตามดาว) ชื่อ ดาว สายของคลาส ราคา/สต็อก/เลเวล
	          + เพชรของเรา + เวลารีสต็อก + รีโรลสต็อค + อัตราต่อรอง
	  กลาง  : ตัวละครคลาสจริง (R15 + ของในแคตตาล็อก) ยืนบนเวทีในเต็นท์ Classes + แถบความคืบหน้าเลเวลถัดไป + ปุ่ม
	  ขวา   : เครื่องมือเริ่มต้น + การ์ดทักษะ 3 ขั้น (ชื่อทักษะ + คำอธิบาย / ล็อก = ข้ามด้วยเพชร)
	ทุกอย่างอยู่ในกรอบ 16:9 กลางจอ (UIAspectRatioConstraint) จะได้ไม่เพี้ยนตามขนาดจอ
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
local shownTools -- คลาสที่วาดไอคอนเครื่องมือไว้แล้ว (กันวาดซ้ำทุกครั้งที่รีเฟรช)
local ui = {}
local stage = {}

local GOLD_A, GOLD_B = C(255, 240, 140), C(244, 170, 36)
local GREEN, RED, BLUE, GRAY = C(76, 200, 64), C(222, 64, 64), C(58, 160, 240), C(96, 96, 104)
local LEVEL_COLOR = { C(90, 200, 90), C(70, 150, 245), C(180, 90, 245) }
local ITEM_EMOJI = {
	Torch = "🔥", Bandage = "🩹", Medkit = "⛑", Berries = "🍇", Coal = "⚫", LogWall = "🧱", Bow = "🏹",
	OldAxe = "🪓", StoneAxe = "🪓", IronAxe = "🪓", Spear = "🔱", Wood = "🪵", Stone = "🪨",
}

---------------------------------------------------------------- ตัวช่วย UI
local function corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 10)
	c.Parent = obj
	return c
end

local function border(obj, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color or C(0, 0, 0)
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0
	s.Parent = obj
	return s
end

local function gradient(obj, a, b, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rot or 90
	g.Parent = obj
	return g
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = C(28, 30, 52)
	f.BackgroundTransparency = 0.08
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

-- ตัวหนังสือหนา ขอบดำ ปรับขนาดอัตโนมัติ
local function text(parent, props, maxSize, strokeThickness)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = C(255, 255, 255)
	t.TextScaled = true
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	t.Parent = parent
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = maxSize or 32
	lim.MinTextSize = 7
	lim.Parent = t
	if (strokeThickness or 2) > 0 then
		local s = Instance.new("UIStroke")
		s.Thickness = strokeThickness or 2
		s.Color = C(0, 0, 0)
		s.Parent = t
	end
	return t
end

local function button(parent, props, color, onClick, maxSize)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextColor3 = C(255, 255, 255)
	b.TextScaled = true
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	b.Parent = parent
	corner(b, 10)
	gradient(b, C(255, 255, 255), C(175, 175, 175), 90)
	border(b, C(0, 0, 0), 2.5, 0.1)
	local ts = Instance.new("UIStroke")
	ts.Thickness = 2
	ts.Color = C(0, 0, 0)
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ts.Parent = b
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = maxSize or 30
	lim.MinTextSize = 7
	lim.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.06, 0), UDim.new(0.06, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.16, 0), UDim.new(0.16, 0)
	pad.Parent = b
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

local function setButton(b, txt, color, enabled)
	b.Text = txt
	b.BackgroundColor3 = color
	b.AutoButtonColor = enabled ~= false
end

-- แผงหลัก: พื้นเข้ม ขอบดำหนา ไล่แสงด้านบน + เส้นขอบในบางๆ
local function panel(parent, pos, size)
	local p = frame(parent, { Position = pos, Size = size, BackgroundColor3 = C(34, 38, 66), BackgroundTransparency = 0.06 })
	corner(p, 18)
	border(p, C(0, 0, 0), 3, 0.15)
	gradient(p, C(255, 255, 255), C(185, 185, 195), 90)
	local inner = frame(p, { Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(1, -8, 1, -8), BackgroundTransparency = 1 })
	corner(inner, 15)
	border(inner, C(255, 255, 255), 1.5, 0.88)
	return p
end

local function stars(n)
	return string.rep("★", n)
end

---------------------------------------------------------------- ข้อมูล
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

local function gems()
	return player:GetAttribute("Diamonds") or data().Diamonds or 0
end

---------------------------------------------------------------- เวทีโชว์ตัวละคร (กล้องในเต็นท์)
local function findStage()
	local lobby = Workspace:FindFirstChild("Lobby")
	return lobby and lobby:FindFirstChild("ClassStage", true)
end

local function sparkle(cf, color)
	local fx = Instance.new("Part")
	fx.Anchored, fx.CanCollide, fx.CanQuery, fx.CanTouch, fx.Transparency = true, false, false, false, 1
	fx.Size = Vector3.new(1, 1, 1)
	fx.CFrame = cf
	fx.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(4, 10)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.6, 0)
	e.Color = ColorSequence.new(color)
	e.Parent = fx
	e:Emit(45)
	task.delay(2, function()
		fx:Destroy()
	end)
end

function ClassShop.IsOpen()
	return ui.Root ~= nil and ui.Root.Visible
end

local function showOnStage(id)
	local token = {}
	stage.Token = token
	task.spawn(function()
		local st = findStage()
		local model = ClassAvatars.Build(id, 6)
		if stage.Token ~= token or not ClassShop.IsOpen() then
			model:Destroy()
			return
		end
		if stage.Model then
			stage.Model:Destroy()
			stage.Model = nil
		end
		if not st then
			model:Destroy()
			ui.CenterView.Visible = true
			ClassAvatars.Viewport(ui.CenterView, id, false)
			return
		end
		ui.CenterView.Visible = false
		stage.Model = model
		stage.Base = st.CFrame * CFrame.new(0, st.Size.Y / 2, 0)
		model:PivotTo(stage.Base)
		model.Parent = Workspace
		ClassAvatars.PlayIdle(model)
		sparkle(stage.Base * CFrame.new(0, 3, 0), Classes.StarColor[Classes.Data[id].Stars])
	end)
end

local function cameraToStage()
	local st = findStage()
	if not st then
		return
	end
	local cam = Workspace.CurrentCamera
	stage.PrevFov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 40
	local base = st.CFrame * CFrame.new(0, st.Size.Y / 2, 0)
	cam.CFrame = CFrame.lookAt((base * CFrame.new(0, 3.2, -16)).Position, (base * CFrame.new(0, 1.75, 0)).Position)
	if stage.Conn then
		stage.Conn:Disconnect()
	end
	local t0 = os.clock()
	stage.Conn = RunService.RenderStepped:Connect(function()
		if stage.Model and stage.Base and stage.Model.Parent then
			local t = os.clock() - t0
			stage.Model:PivotTo(stage.Base * CFrame.Angles(0, math.sin(t * 0.6) * 0.4, 0) * CFrame.new(0, math.abs(math.sin(t * 1.6)) * 0.06, 0))
		end
	end)
end

local function restoreCamera()
	stage.Token = nil
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

---------------------------------------------------------------- การ์ดคลาส (ซ้าย)
local function cardHeight()
	return math.clamp(math.floor(Workspace.CurrentCamera.ViewportSize.Y * 0.105), 72, 132)
end

function ClassShop.MakeCard(id, order)
	local c = Classes.Data[id]
	local rare = Classes.StarColor[c.Stars]
	local card = Instance.new("TextButton")
	card.Text = ""
	card.AutoButtonColor = false
	card.BackgroundColor3 = C(52, 58, 98)
	card.Size = UDim2.new(1, -10, 0, cardHeight())
	card.LayoutOrder = order
	card.Parent = ui.List
	corner(card, 12)
	local stroke = border(card, C(0, 0, 0), 2, 0.2)
	gradient(card, C(255, 255, 255), C(200, 200, 210), 90)
	local accent = frame(card, { Size = UDim2.new(0, 6, 1, -16), Position = UDim2.new(0, 6, 0, 8), BackgroundColor3 = rare, BackgroundTransparency = 0 })
	corner(accent, 3)
	-- รูปวงกลม (CanvasGroup ตัดขอบให้กลมจริง)
	local holder = Instance.new("CanvasGroup")
	holder.BackgroundColor3 = C(74, 80, 126)
	holder.Size = UDim2.fromScale(0.84, 0.84)
	holder.Position = UDim2.new(0, 18, 0.08, 0)
	holder.Parent = card
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = holder
	corner(holder, UDim.new(0.5, 0))
	border(holder, rare, 3, 0)
	gradient(holder, rare:Lerp(C(255, 255, 255), 0.4), rare:Lerp(C(0, 0, 0), 0.55), 90)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Parent = holder
	task.spawn(ClassAvatars.Viewport, vp, id, true, 20)
	-- ตัวหนังสือ
	text(card, { Position = UDim2.new(0.31, 0, 0.07, 0), Size = UDim2.new(0.66, 0, 0.32, 0), Text = c.Thai, TextXAlignment = Enum.TextXAlignment.Left }, 30)
	text(card, { Position = UDim2.new(0.31, 0, 0.42, 0), Size = UDim2.new(0.3, 0, 0.22, 0), Text = stars(c.Stars), TextColor3 = C(255, 205, 50), TextXAlignment = Enum.TextXAlignment.Left }, 24)
	text(card, { Position = UDim2.new(0.31, 0, 0.68, 0), Size = UDim2.new(0.3, 0, 0.22, 0), Text = c.Role, TextColor3 = rare:Lerp(C(255, 255, 255), 0.35), TextXAlignment = Enum.TextXAlignment.Left }, 20)
	local tag = text(card, { Position = UDim2.new(0.62, 0, 0.4, 0), Size = UDim2.new(0.35, 0, 0.2, 0), Text = "", TextXAlignment = Enum.TextXAlignment.Right }, 20)
	local btn = button(card, { Position = UDim2.new(0.62, 0, 0.62, 0), Size = UDim2.new(0.35, 0, 0.3, 0), Text = "" }, BLUE, nil, 22)
	local function pick()
		if selected ~= id then
			selected = id
			ClassShop.Refresh()
			showOnStage(id)
		end
	end
	card.Activated:Connect(pick)
	btn.Activated:Connect(pick)
	ui.Cards[id] = { Card = card, Stroke = stroke, Tag = tag, Button = btn }
end

---------------------------------------------------------------- สร้าง UI ทั้งหมด
function ClassShop.Build(gui)
	local root = frame(gui, { Name = "ClassShop", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })
	ui.Root = root
	-- กรอบ 16:9 กลางจอ
	local canvas = frame(root, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 16 / 9
	ar.Parent = canvas

	-------------------------------------------------- ซ้าย
	local left = panel(canvas, UDim2.fromScale(0.012, 0.03), UDim2.fromScale(0.285, 0.94))
	local title = text(left, { Position = UDim2.fromScale(0.06, 0.018), Size = UDim2.fromScale(0.45, 0.085), Text = "คลาส", TextXAlignment = Enum.TextXAlignment.Left }, 72, 3)
	gradient(title, GOLD_A, GOLD_B, 90)
	local gemPill = frame(left, { Position = UDim2.fromScale(0.55, 0.03), Size = UDim2.fromScale(0.4, 0.062), BackgroundColor3 = C(22, 24, 44), BackgroundTransparency = 0.15 })
	corner(gemPill, UDim.new(0.5, 0))
	border(gemPill, C(110, 200, 255), 2, 0.2)
	ui.Gems = text(gemPill, { Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), Text = "💎 0" }, 28)
	local restock = frame(left, { Position = UDim2.fromScale(0.06, 0.108), Size = UDim2.fromScale(0.88, 0.045), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.55 })
	corner(restock, UDim.new(0.5, 0))
	ui.Restock = text(restock, { Size = UDim2.fromScale(0.94, 0.8), Position = UDim2.fromScale(0.03, 0.1), Text = "", TextColor3 = C(210, 214, 225) }, 20, 1.5)
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromScale(0.04, 0.168)
	list.Size = UDim2.fromScale(0.94, 0.7)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = C(150, 150, 160)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = left
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = list
	local lpad = Instance.new("UIPadding")
	lpad.PaddingTop = UDim.new(0, 4)
	lpad.PaddingBottom = UDim.new(0, 4)
	lpad.Parent = list
	ui.List = list
	ui.Cards = {}
	for i, id in ipairs(Classes.Order) do
		ClassShop.MakeCard(id, i)
	end
	button(left, { Position = UDim2.fromScale(0.05, 0.887), Size = UDim2.fromScale(0.58, 0.08), Text = "🎲 รีโรลสต็อค  💎" .. Classes.RerollPrice }, GREEN, function()
		Remotes.Get("RerollStock"):FireServer()
	end, 28)
	button(left, { Position = UDim2.fromScale(0.66, 0.887), Size = UDim2.fromScale(0.29, 0.08), Text = "อัตราต่อรอง" }, GRAY, function()
		ui.Odds.Visible = not ui.Odds.Visible
	end, 20)
	local odds = panel(canvas, UDim2.fromScale(0.305, 0.6), UDim2.fromScale(0.16, 0.32))
	odds.Visible = false
	odds.ZIndex = 5
	text(odds, { Position = UDim2.fromScale(0.06, 0.04), Size = UDim2.fromScale(0.88, 0.14), Text = "โอกาสติดสต็อคต่อวัน" }, 22)
	for s = 1, 5 do
		text(odds, {
			Position = UDim2.fromScale(0.1, 0.06 + s * 0.15), Size = UDim2.fromScale(0.8, 0.12), TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("%s  %d%%", stars(s), math.floor(Classes.StockOdds[s] * 100)), TextColor3 = Classes.StarColor[s],
		}, 22)
	end
	ui.Odds = odds

	-------------------------------------------------- กลาง
	ui.Name = text(canvas, { Position = UDim2.fromScale(0.32, 0.03), Size = UDim2.fromScale(0.36, 0.085), Text = "" }, 80, 3)
	gradient(ui.Name, C(170, 255, 245), C(40, 200, 225), 90)
	ui.Sub = text(canvas, { Position = UDim2.fromScale(0.34, 0.118), Size = UDim2.fromScale(0.32, 0.045), Text = "", RichText = true }, 30)
	ui.CenterView = Instance.new("ViewportFrame")
	ui.CenterView.Position = UDim2.fromScale(0.39, 0.18)
	ui.CenterView.Size = UDim2.fromScale(0.22, 0.46)
	ui.CenterView.BackgroundTransparency = 1
	ui.CenterView.Visible = false
	ui.CenterView.Parent = canvas
	local prog = panel(canvas, UDim2.fromScale(0.345, 0.665), UDim2.fromScale(0.31, 0.165))
	ui.ProgTitle = text(prog, { Position = UDim2.fromScale(0.05, 0.06), Size = UDim2.fromScale(0.9, 0.24), Text = "", TextColor3 = C(130, 225, 255) }, 26)
	ui.Bars = {}
	for i = 1, 2 do
		local y = 0.36 + (i - 1) * 0.3
		local lbl = text(prog, { Position = UDim2.fromScale(0.05, y), Size = UDim2.fromScale(0.3, 0.24), Text = "", TextXAlignment = Enum.TextXAlignment.Left }, 22)
		local track = frame(prog, { Position = UDim2.fromScale(0.36, y + 0.03), Size = UDim2.fromScale(0.59, 0.18), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.35 })
		corner(track, UDim.new(0.5, 0))
		border(track, C(0, 0, 0), 1.5, 0)
		local fill = frame(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C(110, 225, 90), BackgroundTransparency = 0 })
		corner(fill, UDim.new(0.5, 0))
		gradient(fill, C(255, 255, 255), C(170, 170, 170), 90)
		local num = text(track, { Size = UDim2.fromScale(1, 1), Text = "" }, 18, 1.5)
		ui.Bars[i] = { Label = lbl, Track = track, Fill = fill, Num = num }
	end
	ui.Info = text(prog, { Position = UDim2.fromScale(0.05, 0.36), Size = UDim2.fromScale(0.9, 0.56), Text = "", TextWrapped = true, Visible = false }, 24)
	ui.Main = button(canvas, { Position = UDim2.fromScale(0.345, 0.845), Size = UDim2.fromScale(0.215, 0.095), Text = "" }, GREEN, function()
		ClassShop.MainAction()
	end, 40)
	button(canvas, { Position = UDim2.fromScale(0.57, 0.845), Size = UDim2.fromScale(0.085, 0.095), Text = "ปิด" }, RED, function()
		ClassShop.Close()
	end, 32)

	-------------------------------------------------- ขวา
	local right = panel(canvas, UDim2.fromScale(0.703, 0.03), UDim2.fromScale(0.285, 0.94))
	local toolsTitle = text(right, { Position = UDim2.fromScale(0.06, 0.02), Size = UDim2.fromScale(0.88, 0.06), Text = "เครื่องมือเริ่มต้น" }, 40, 3)
	gradient(toolsTitle, GOLD_A, GOLD_B, 90)
	ui.Tools = frame(right, { Position = UDim2.fromScale(0.05, 0.09), Size = UDim2.fromScale(0.9, 0.17), BackgroundTransparency = 1 })
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tl.Padding = UDim.new(0.04, 0)
	tl.Parent = ui.Tools
	local skillTitle = text(right, { Position = UDim2.fromScale(0.06, 0.285), Size = UDim2.fromScale(0.88, 0.06), Text = "ทักษะ" }, 40, 3)
	gradient(skillTitle, C(220, 245, 255), C(110, 185, 255), 90)
	ui.Skills = {}
	for lv = 1, 3 do
		local box = frame(right, { Position = UDim2.fromScale(0.05, 0.36 + (lv - 1) * 0.205), Size = UDim2.fromScale(0.9, 0.19), BackgroundColor3 = C(52, 58, 98), BackgroundTransparency = 0 })
		corner(box, 12)
		local bstroke = border(box, LEVEL_COLOR[lv], 2, 0.3)
		gradient(box, C(255, 255, 255), C(195, 195, 205), 90)
		local chip = frame(box, { Position = UDim2.fromScale(0.03, 0.08), Size = UDim2.fromScale(0.2, 0.28), BackgroundColor3 = LEVEL_COLOR[lv], BackgroundTransparency = 0 })
		corner(chip, UDim.new(0.5, 0))
		border(chip, C(0, 0, 0), 1.5, 0)
		text(chip, { Size = UDim2.fromScale(0.9, 0.86), Position = UDim2.fromScale(0.05, 0.07), Text = "Lv." .. lv }, 22, 1.5)
		local name = text(box, { Position = UDim2.fromScale(0.26, 0.06), Size = UDim2.fromScale(0.62, 0.32), Text = "", TextColor3 = C(255, 214, 90), TextXAlignment = Enum.TextXAlignment.Left }, 28)
		local lock = text(box, { Position = UDim2.fromScale(0.88, 0.06), Size = UDim2.fromScale(0.1, 0.32), Text = "🔒", Visible = false }, 26, 0)
		local desc = text(box, { Position = UDim2.fromScale(0.04, 0.42), Size = UDim2.fromScale(0.92, 0.28), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Font = Enum.Font.GothamBold }, 22, 1.5)
		local foot = text(box, { Position = UDim2.fromScale(0.04, 0.74), Size = UDim2.fromScale(0.52, 0.2), Text = "", TextColor3 = C(255, 120, 120), TextXAlignment = Enum.TextXAlignment.Left, Visible = false }, 18, 1.5)
		local skip = button(box, { Position = UDim2.fromScale(0.6, 0.71), Size = UDim2.fromScale(0.37, 0.25), Text = "", Visible = false }, GREEN, function()
			Remotes.Get("SkipClassLevel"):FireServer(selected)
		end, 20)
		ui.Skills[lv] = { Box = box, Stroke = bstroke, Name = name, Lock = lock, Desc = desc, Foot = foot, Skip = skip }
	end
end

---------------------------------------------------------------- เติมข้อมูล
local function drawTools(c)
	for _, ch in ipairs(ui.Tools:GetChildren()) do
		if ch:IsA("Frame") then
			ch:Destroy()
		end
	end
	local order = 0
	for itemId, n in pairs(c.StartItems) do
		order += 1
		local tile = frame(ui.Tools, { Size = UDim2.fromScale(0.3, 1), BackgroundColor3 = C(56, 62, 104), BackgroundTransparency = 0, LayoutOrder = order })
		corner(tile, 12)
		border(tile, C(0, 0, 0), 2, 0.2)
		gradient(tile, C(255, 255, 255), C(185, 185, 195), 90)
		local icon = Instance.new("ViewportFrame")
		icon.Size = UDim2.fromScale(0.8, 0.6)
		icon.Position = UDim2.fromScale(0.1, 0.05)
		icon.BackgroundTransparency = 1
		icon.Parent = tile
		local emoji = text(tile, { Size = UDim2.fromScale(0.8, 0.6), Position = UDim2.fromScale(0.1, 0.05), Text = ITEM_EMOJI[itemId] or "📦" }, 54, 0)
		text(tile, { Position = UDim2.fromScale(0.55, 0.02), Size = UDim2.fromScale(0.42, 0.26), Text = "x" .. n, TextXAlignment = Enum.TextXAlignment.Right }, 24)
		text(tile, { Position = UDim2.fromScale(0.04, 0.68), Size = UDim2.fromScale(0.92, 0.26), Text = Items.DisplayName(itemId) }, 18, 1.5)
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
end

function ClassShop.Refresh()
	if not ui.Root then
		return
	end
	local d = data()
	local st = stock()
	local current = player:GetAttribute("Class") or "Survivor"
	ui.Gems.Text = "💎 " .. tostring(gems())
	local s = Classes.SecondsToRestock(now())
	ui.Restock.Text = string.format("สต็อกใหม่ใน %d ชม. %d นาที", s // 3600, (s % 3600) // 60)
	local h = cardHeight()
	for id, cd in pairs(ui.Cards) do
		local c = Classes.Data[id]
		local owned = d.Owned and d.Owned[id]
		cd.Card.Size = UDim2.new(1, -10, 0, h)
		cd.Stroke.Color = (id == selected) and C(255, 214, 60) or C(0, 0, 0)
		cd.Stroke.Thickness = (id == selected) and 3.5 or 2
		cd.Stroke.Transparency = (id == selected) and 0 or 0.2
		if id == current then
			cd.Tag.Text, cd.Tag.TextColor3 = "✔ สวมใส่อยู่", C(255, 220, 60)
		elseif owned then
			cd.Tag.Text, cd.Tag.TextColor3 = "มีแล้ว", C(140, 240, 100)
		else
			cd.Tag.Text, cd.Tag.TextColor3 = "💎 " .. c.Price, C(150, 225, 255)
		end
		if owned then
			setButton(cd.Button, "เลเวล " .. levelOf(id), BLUE)
		elseif st[id] then
			setButton(cd.Button, "มีในสต็อค", GREEN)
		else
			setButton(cd.Button, "ไม่มีสต๊อค", RED)
		end
	end
	-- กลาง
	local c = Classes.Data[selected]
	local owned = d.Owned and d.Owned[selected]
	local lv = levelOf(selected)
	ui.Name.Text = c.Thai
	ui.Sub.Text = string.format('<font color="#FFCD32">%s</font>  ·  %s  ·  %s', stars(c.Stars), c.Role, owned and ("เลเวล " .. lv .. "/" .. Classes.MaxLevel) or "ยังไม่ปลดล็อก")
	local stats = (d.ClassStats and d.ClassStats[selected]) or {}
	local req = Classes.Requirement(selected, lv + 1)
	local showBars = owned and req ~= nil
	for _, b in ipairs(ui.Bars) do
		b.Label.Visible, b.Track.Visible = showBars, showBars
	end
	ui.Info.Visible = not showBars
	if not owned then
		ui.ProgTitle.Text = "ปลดล็อกคลาสนี้"
		ui.Info.Text = st[selected] and string.format("ราคา 💎%d — มีในสต็อควันนี้", c.Price) or "ไม่มีสต๊อควันนี้ — รอรีสต็อกหรือกดรีโรล"
		ui.Info.TextColor3 = st[selected] and C(140, 240, 100) or C(255, 130, 120)
	elseif req then
		ui.ProgTitle.Text = string.format("ความคืบหน้า → เลเวล %d", lv + 1)
		for i, k in ipairs(Classes.StatOrder) do
			local b = ui.Bars[i]
			local have, need = stats[k] or 0, req[k]
			b.Label.Text = Classes.StatNames[k]
			b.Fill.Size = UDim2.fromScale(math.clamp(have / need, 0, 1), 1)
			b.Num.Text = string.format("%d / %d", math.min(have, need), need)
		end
	else
		ui.ProgTitle.Text = "⭐ เลเวลสูงสุดแล้ว"
		ui.Info.Text = string.format("ล่าสัตว์ %d ตัว · รอด %d คืน กับคลาสนี้", stats.Kills or 0, stats.Nights or 0)
		ui.Info.TextColor3 = C(255, 220, 120)
	end
	if selected == current then
		if selected == "Survivor" then
			setButton(ui.Main, "สวมใส่อยู่", GRAY, false)
		else
			setButton(ui.Main, "ถอดออก", RED)
		end
	elseif owned then
		setButton(ui.Main, "สวมใส่", GREEN)
	elseif not st[selected] then
		setButton(ui.Main, "ไม่มีสต๊อค", GRAY, false)
	elseif gems() < c.Price then
		setButton(ui.Main, "💎 ไม่พอ (" .. c.Price .. ")", GRAY, false)
	else
		setButton(ui.Main, "ซื้อ  💎" .. c.Price, GREEN)
	end
	-- ขวา
	if shownTools ~= selected then
		shownTools = selected
		drawTools(c)
	end
	for i, sk in ipairs(ui.Skills) do
		local skill = c.Skills[i]
		local unlocked = owned and lv >= i
		sk.Name.Text = skill.Name
		sk.Desc.Text = skill.Text
		sk.Name.TextTransparency = unlocked and 0 or 0.35
		sk.Desc.TextTransparency = unlocked and 0 or 0.4
		sk.Box.BackgroundColor3 = unlocked and C(52, 58, 98) or C(30, 32, 54)
		sk.Stroke.Transparency = unlocked and 0.1 or 0.6
		sk.Lock.Visible = not unlocked
		local canSkip = owned and i == lv + 1
		sk.Foot.Visible = not unlocked
		sk.Foot.Text = owned and ("ปลดที่เลเวล " .. i) or "ซื้อคลาสก่อน"
		sk.Skip.Visible = canSkip
		if canSkip then
			sk.Skip.Text = "ข้าม 💎" .. Classes.SkipPrice(selected, i)
		end
	end
end

-- เลือกคลาสจากภายนอก (เทสต์/ทางลัด)
function ClassShop.Select(id)
	if Classes.Data[id] and ClassShop.IsOpen() then
		selected = id
		ClassShop.Refresh()
		showOnStage(id)
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
	elseif stock()[selected] and gems() >= Classes.Data[selected].Price then
		Remotes.Get("BuyClass"):FireServer(selected)
	end
end

function ClassShop.SetProfile(p)
	profile = p
	if ClassShop.IsOpen() then
		ClassShop.Refresh()
	end
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
	if not ClassShop.IsOpen() then
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
	local function refreshIfOpen()
		if ClassShop.IsOpen() then
			ClassShop.Refresh()
		end
	end
	player:GetAttributeChangedSignal("Diamonds"):Connect(refreshIfOpen)
	player:GetAttributeChangedSignal("Class"):Connect(refreshIfOpen)
	player:GetAttributeChangedSignal("ClassLevel"):Connect(refreshIfOpen)
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		if player:GetAttribute("InRun") then
			ClassShop.Close()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(30)
			refreshIfOpen()
		end
	end)
end

return ClassShop
