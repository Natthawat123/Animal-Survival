--[[
	SettingsUI — หน้าต่างตั้งค่า (ปุ่ม ⚙ ในล็อบบี้ / ระหว่างเล่น) · ธีมกรอบไม้ (WoodKit)
	  🔊 เสียง   : เพลง / บรรยากาศ / เอฟเฟกต์
	  🎨 กราฟิก  : ต่ำ / กลาง / สูง (มือถือ-เครื่องช้าแนะนำ "ต่ำ")
	  🎮 การเล่น : จอสั่น, คำแนะนำปุ่ม, ตัวนับ FPS, สลับเครื่องมืออัตโนมัติ
	  📱 หน้าจอ  : ขนาด UI, ขนาดปุ่มมือถือ
	ใช้ได้ทั้งเมาส์และนิ้ว (ลากแถบเลื่อน/แตะปุ่ม)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent.UIKit)
local WoodKit = require(script.Parent.WoodKit)
local ClientSettings = require(script.Parent.ClientSettings)
local Audio = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Audio"))

local SettingsUI = {}
local C = UIKit.Colors
local W = WoodKit.Colors
local ui = {}
local controls = {} -- [key] = refresh()

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- หัวข้อหมวด: ป้ายกระดาษ + เส้นไม้ยาว
local function section(order, icon, text)
	local f = UIKit.Frame(ui.List, { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = order })
	WoodKit.Frame(f, { Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 0.5, 2), BackgroundColor3 = W.WoodDark, BackgroundTransparency = 0.3 })
	local tag = WoodKit.Parchment(f, { Size = UDim2.fromOffset(170, 38), Position = UDim2.fromOffset(0, 1), ZIndex = 2 })
	WoodKit.Ink(tag, { Size = UDim2.new(1, -14, 1, 0), Position = UDim2.fromOffset(12, 0), Text = icon .. "  " .. text, TextSize = 22, ZIndex = 3 })
	return f
end

-- แถวกระดาษ: เหรียญไอคอน + ชื่อ (+ คำอธิบาย)
local function row(order, icon, label, sub)
	local f = WoodKit.Parchment(ui.List, { Size = UDim2.new(1, 0, 0, sub and 68 or 58), LayoutOrder = order })
	local m = sub and 52 or 44
	WoodKit.Medallion(f, icon, m, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 2 }, rgb(44, 40, 70))
	WoodKit.Ink(f, { Size = UDim2.new(0.44, -40, 0, 28), Position = UDim2.fromOffset(m + 22, sub and 8 or 15), Text = label, TextSize = 21 })
	if sub then
		WoodKit.Ink(f, { Size = UDim2.new(0.44, -40, 0, 20), Position = UDim2.fromOffset(m + 22, 38), Text = sub, TextSize = 14, Font = UIKit.Fonts.Bold, TextColor3 = W.InkDim })
	end
	return f
end

-- แถบเลื่อน (ลากด้วยเมาส์หรือนิ้ว): ร่องไม้เข้ม + แถบแดง + ปุ่มทองกลม + กล่องตัวเลข
local function slider(order, key, icon, label, minV, maxV, fmt, sub)
	local f = row(order, icon, label, sub)
	local track = WoodKit.Frame(f, { Size = UDim2.new(0.4, 0, 0, 16), Position = UDim2.new(0.46, 0, 0.5, -8), BackgroundColor3 = rgb(40, 26, 18), Active = true })
	WoodKit.Corner(track, "round")
	WoodKit.Stroke(track, W.WoodDark, 2, 0)
	local fill = WoodKit.Frame(track, { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = rgb(196, 42, 40) })
	WoodKit.Corner(fill, "round")
	UIKit.Gradient(fill, rgb(255, 255, 255), rgb(170, 150, 150), 90)
	local knob = WoodKit.Frame(track, { Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = W.Gold, ZIndex = 3 })
	WoodKit.Corner(knob, "round")
	WoodKit.Stroke(knob, rgb(110, 70, 24), 2.5, 0)
	UIKit.Gradient(knob, rgb(255, 255, 255), rgb(180, 150, 110), 90)
	local box = WoodKit.Board(f, { Size = UDim2.fromOffset(76, 36), Position = UDim2.new(1, -88, 0.5, -18) }, rgb(36, 24, 16))
	local val = UIKit.Text(box, { Size = UDim2.fromScale(1, 1), Text = "", Font = UIKit.Fonts.Title, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center })
	local function show(v)
		local k = math.clamp((v - minV) / (maxV - minV), 0, 1)
		fill.Size = UDim2.fromScale(k, 1)
		knob.Position = UDim2.fromScale(k, 0.5)
		val.Text = fmt(v)
	end
	local dragging = false
	local function setFromX(x, save)
		local k = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local v = minV + (maxV - minV) * k
		v = math.floor(v * 100 + 0.5) / 100
		show(v)
		ClientSettings.Set(key, v, not save)
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X, false)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X, false)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			setFromX(input.Position.X, true)
		end
	end)
	controls[key] = function()
		show(ClientSettings.Get(key))
	end
end

-- สวิตช์: เปิด = แดงขอบทอง ปุ่มทองชิดขวา · ปิด = ไม้เข้ม ปุ่มทองชิดซ้าย
local function toggle(order, key, icon, label, sub)
	local f = row(order, icon, label, sub)
	local sw = WoodKit.Button(f, "Red", { Size = UDim2.fromOffset(112, 40), Position = UDim2.new(1, -124, 0.5, -20), Text = "", TextSize = 18 }, function()
		ClientSettings.Set(key, not ClientSettings.Get(key))
		controls[key]()
	end)
	sw:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	local word = UIKit.Text(sw, { Size = UDim2.new(1, -44, 1, 0), Text = "", Font = UIKit.Fonts.Title, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center })
	local knob = WoodKit.Frame(sw, { Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = W.Gold })
	WoodKit.Corner(knob, "round")
	WoodKit.Stroke(knob, rgb(110, 70, 24), 2.5, 0)
	UIKit.Gradient(knob, rgb(255, 255, 255), rgb(180, 150, 110), 90)
	controls[key] = function()
		local on = ClientSettings.Get(key)
		WoodKit.Style(sw, on and "Red" or "Dark")
		word.Text = on and "เปิด" or "ปิด"
		word.Position = on and UDim2.fromOffset(4, 0) or UDim2.fromOffset(40, 0)
		knob.Position = on and UDim2.new(1, -22, 0.5, 0) or UDim2.new(0, 22, 0.5, 0)
	end
end

local function segmented(order, key, icon, label, options, sub)
	local f = row(order, icon, label, sub)
	local holder = UIKit.Frame(f, { Size = UDim2.new(0.55, 0, 0, 42), Position = UDim2.new(0.45, -14, 0.5, -21), BackgroundTransparency = 1 })
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Right
	l.Padding = UDim.new(0, 8)
	l.Parent = holder
	local buttons = {}
	for i, o in ipairs(options) do
		buttons[o[1]] = WoodKit.Button(holder, "Dark", { Size = UDim2.fromOffset(100, 42), Text = o[2], TextSize = 19, LayoutOrder = i }, function()
			ClientSettings.Set(key, o[1])
			controls[key]()
		end)
	end
	controls[key] = function()
		for id, b in pairs(buttons) do
			WoodKit.Style(b, ClientSettings.Get(key) == id and "Red" or "Dark")
		end
	end
end

function SettingsUI.Refresh()
	for _, fn in pairs(controls) do
		fn()
	end
end

function SettingsUI.Open()
	SettingsUI.Refresh()
	ui.Panel.Visible = true
	UIKit.Pop(ui.Panel)
end

function SettingsUI.Close()
	ui.Panel.Visible = false
end

function SettingsUI.Toggle()
	if ui.Panel.Visible then
		SettingsUI.Close()
	else
		SettingsUI.Open()
	end
end

function SettingsUI.IsOpen()
	return ui.Panel ~= nil and ui.Panel.Visible
end

-- ปุ่มเฟือง ⚙ ระหว่างเล่น (ในล็อบบี้มีปุ่มในแถบเมนูซ้ายอยู่แล้ว)
-- parent = การ์ดกองไฟมุมขวาบนของ HUD (โชว์เฉพาะในแมพ) -> ปุ่มติดอยู่ซ้ายการ์ด ย่อ/ขยายไปด้วยกัน
local function gearButton(gui, parent)
	local b = UIKit.ColorButton(parent or gui, rgb(70, 76, 120), {
		Size = UDim2.fromOffset(48, 48), AnchorPoint = Vector2.new(1, 0), Position = parent and UDim2.new(0, -12, 0, 4) or UDim2.new(1, -310, 0, 22), Text = "⚙", TextSize = 28,
	}, SettingsUI.Toggle)
	b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	UIKit.EnsureTouchSize(b, 44, SettingsUI.Toggle)
	if not parent then
		UIKit.AutoScale(b)
		local function upd()
			b.Visible = Players.LocalPlayer:GetAttribute("InRun") == true
		end
		Players.LocalPlayer:GetAttributeChangedSignal("InRun"):Connect(upd)
		upd()
	end
end

function SettingsUI.Init(gui, handlers)
	handlers = handlers or {}
	local win = WoodKit.Window(gui, { Name = "SettingsWindow", Size = Vector2.new(860, 680), Title = "⚙ ตั้งค่า", TitleWidth = 290, OnClose = SettingsUI.Close })
	ui.Panel = win.Frame
	local body = win.Body
	UIKit.RegisterWindow(ui.Panel, SettingsUI.Close, { Dim = 0.55 })
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -60, 1, -150)
	list.Position = UDim2.fromOffset(30, 50)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = W.Gold
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = body
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 8)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingRight, pad.PaddingTop, pad.PaddingLeft = UDim.new(0, 12), UDim.new(0, 4), UDim.new(0, 2)
	pad.Parent = list
	ui.List = list

	local pct = function(v)
		return math.floor(v * 100 + 0.5) .. "%"
	end
	section(1, "🔊", "เสียง")
	local hasMusic = false
	for _, def in pairs(Audio.Music) do
		if def.Id ~= "" then
			hasMusic = true
		end
	end
	slider(2, "MusicVol", "🎵", "เพลง", 0, 1, pct, not hasMusic and "ยังไม่ได้ใส่เพลง (ใส่ ID ใน Audio.lua)" or nil)
	slider(3, "AmbientVol", "🌲", "เสียงบรรยากาศ", 0, 1, pct)
	slider(4, "SfxVol", "💥", "เอฟเฟกต์", 0, 1, pct)
	section(10, "🎨", "กราฟิก")
	segmented(11, "Quality", "🖥", "คุณภาพภาพ", { { "Low", "ต่ำ" }, { "Medium", "กลาง" }, { "High", "สูง" } }, "มือถือ/เครื่องช้า แนะนำ \"ต่ำ\"")
	section(20, "🎮", "การเล่น")
	toggle(21, "Shake", "⚔", "จอสั่น", "ตอนโดนตี / บอสกระแทก")
	toggle(22, "Hints", "🏃", "คำแนะนำปุ่ม", "แถบบอกปุ่มด้านล่างจอ")
	toggle(23, "ShowFPS", "📈", "แสดง FPS", "ดูความลื่นของเกม")
	toggle(24, "AutoTool", "🪓", "สลับเครื่องมืออัตโนมัติ", "ตีต้นไม้/หิน/สัตว์ = หยิบขวาน/อีเต้อ/อาวุธที่ดีที่สุดเอง")
	section(30, "📱", "หน้าจอ")
	slider(31, "UIScale", "🔍", "ขนาด UI", 0.7, 1.3, pct, "ย่อ/ขยายหน้าต่างทั้งหมด")
	slider(32, "TouchSize", "👆", "ขนาดปุ่มมือถือ", 0.8, 1.4, pct, "ปุ่มบนจอสำหรับนิ้ว")

	local bottom = UIKit.Frame(body, { Size = UDim2.new(1, -40, 0, 54), Position = UDim2.new(0, 20, 1, -84), BackgroundTransparency = 1 })
	local bl = Instance.new("UIListLayout")
	bl.FillDirection = Enum.FillDirection.Horizontal
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bl.Padding = UDim.new(0, 16)
	bl.Parent = bottom
	WoodKit.Button(bottom, "Red", { Size = UDim2.fromOffset(240, 52), Text = "📖 ดูวิธีเล่น", TextSize = 21 }, function()
		SettingsUI.Close()
		if handlers.Tutorial then
			handlers.Tutorial()
		end
	end)
	WoodKit.Button(bottom, "Dark", { Size = UDim2.fromOffset(240, 52), Text = "🔄 ค่าเริ่มต้น", TextSize = 21 }, function()
		for k, v in pairs(ClientSettings.Defaults) do
			ClientSettings.Set(k, v)
		end
		SettingsUI.Refresh()
	end)

	gearButton(gui, handlers.GearParent)

	-- ตัวนับ FPS
	local fps = UIKit.Text(gui, { Size = UDim2.fromOffset(120, 22), Position = UDim2.new(0, 12, 1, -28), Text = "", TextSize = 16, Font = UIKit.Fonts.Title, TextColor3 = C.Good, Visible = false })
	local frames, acc = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		if not fps.Visible then
			return
		end
		frames += 1
		acc += dt
		if acc >= 0.5 then
			local v = math.floor(frames / acc + 0.5)
			fps.Text = "FPS " .. v
			fps.TextColor3 = v >= 50 and C.Good or (v >= 30 and C.Gold or C.Bad)
			frames, acc = 0, 0
		end
	end)
	local function apply(key, v)
		if key == "ShowFPS" then
			fps.Visible = v == true
		elseif key == "UIScale" then
			UIKit.UserScale = v
			UIKit.RefreshScale()
		end
		if controls[key] and ui.Panel.Visible then
			controls[key]()
		end
	end
	ClientSettings.OnChanged(apply)
	apply("ShowFPS", ClientSettings.Get("ShowFPS"))
	apply("UIScale", ClientSettings.Get("UIScale"))
end

return SettingsUI
