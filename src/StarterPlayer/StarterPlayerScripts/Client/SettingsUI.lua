--[[
	SettingsUI — หน้าต่างตั้งค่า (ปุ่ม ⚙ ในล็อบบี้ / ระหว่างเล่น)
	  🔊 เสียง   : เพลง / บรรยากาศ / เอฟเฟกต์
	  🎨 กราฟิก  : ต่ำ / กลาง / สูง (มือถือ-เครื่องช้าแนะนำ "ต่ำ")
	  🎮 การเล่น : จอสั่น, คำแนะนำปุ่ม, ตัวนับ FPS
	  📱 หน้าจอ  : ขนาด UI, ขนาดปุ่มมือถือ
	ใช้ได้ทั้งเมาส์และนิ้ว (ลากแถบเลื่อน/แตะปุ่ม)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent.UIKit)
local ClientSettings = require(script.Parent.ClientSettings)
local Audio = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Audio"))

local SettingsUI = {}
local C = UIKit.Colors
local ui = {}
local controls = {} -- [key] = refresh()

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function section(order, text)
	local t = UIKit.Text(ui.List, { Size = UDim2.new(1, 0, 0, 34), Text = text, Font = UIKit.Fonts.Title, TextSize = 24, TextColor3 = C.Gold, LayoutOrder = order })
	return t
end

local function row(order, label, sub)
	local f = UIKit.Frame(ui.List, { Size = UDim2.new(1, 0, 0, sub and 62 or 52), BackgroundColor3 = rgb(46, 52, 86), BackgroundTransparency = 0, LayoutOrder = order })
	UIKit.Corner(f, 12)
	UIKit.Stroke(f, C.Outline, 2, 0)
	UIKit.Text(f, { Size = UDim2.new(0.45, 0, 0, 26), Position = UDim2.fromOffset(16, sub and 6 or 13), Text = label, Font = UIKit.Fonts.Black, TextSize = 19 })
	if sub then
		UIKit.Text(f, { Size = UDim2.new(0.45, 0, 0, 18), Position = UDim2.fromOffset(16, 34), Text = sub, TextSize = 13, TextColor3 = C.TextDim, Font = UIKit.Fonts.Body })
	end
	return f
end

-- แถบเลื่อน (ลากด้วยเมาส์หรือนิ้ว)
local function slider(order, key, label, minV, maxV, fmt, sub)
	local f = row(order, label, sub)
	local track = UIKit.Frame(f, { Size = UDim2.new(0.42, 0, 0, 14), Position = UDim2.new(0.47, 0, 0.5, -7), BackgroundColor3 = rgb(16, 16, 30), BackgroundTransparency = 0, Active = true })
	UIKit.Corner(track, 6)
	UIKit.Stroke(track, C.Outline, 2, 0)
	local fill = UIKit.Frame(track, { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = C.Cyan, BackgroundTransparency = 0 })
	UIKit.Corner(fill, 6)
	local knob = UIKit.Frame(track, { Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 3 })
	local kc = Instance.new("UICorner")
	kc.CornerRadius = UDim.new(1, 0)
	kc.Parent = knob
	UIKit.Stroke(knob, C.Outline, 2.5, 0)
	local val = UIKit.Text(f, { Size = UDim2.new(0.1, -10, 1, 0), Position = UDim2.new(0.9, 0, 0, 0), Text = "", Font = UIKit.Fonts.Title, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right })
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

local function toggle(order, key, label, sub)
	local f = row(order, label, sub)
	local sw = UIKit.Button(f, { Size = UDim2.fromOffset(92, 36), Position = UDim2.new(1, -108, 0.5, -18), Text = "", TextSize = 16 }, function()
		ClientSettings.Set(key, not ClientSettings.Get(key))
		controls[key]()
	end)
	controls[key] = function()
		local on = ClientSettings.Get(key)
		sw.BackgroundColor3 = on and C.Green or rgb(90, 94, 120)
		sw.Text = on and "เปิด" or "ปิด"
	end
end

local function segmented(order, key, label, options, sub)
	local f = row(order, label, sub)
	local holder = UIKit.Frame(f, { Size = UDim2.new(0.5, 0, 0, 38), Position = UDim2.new(0.5, -12, 0.5, -19), BackgroundTransparency = 1 })
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Right
	l.Padding = UDim.new(0, 6)
	l.Parent = holder
	local buttons = {}
	for i, o in ipairs(options) do
		buttons[o[1]] = UIKit.Button(holder, { Size = UDim2.fromOffset(82, 38), Text = o[2], TextSize = 16, LayoutOrder = i }, function()
			ClientSettings.Set(key, o[1])
			controls[key]()
		end)
	end
	controls[key] = function()
		for id, b in pairs(buttons) do
			b.BackgroundColor3 = (ClientSettings.Get(key) == id) and C.Blue or rgb(58, 66, 104)
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
	local panel = UIKit.Card(gui, {
		Size = UDim2.fromOffset(640, 600), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), BackgroundColor3 = rgb(36, 40, 70), Visible = false,
	})
	ui.Panel = panel
	UIKit.Header(panel, "⚙ ตั้งค่า", C.Blue)
	UIKit.CloseButton(panel, SettingsUI.Close)
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -40, 1, -120)
	list.Position = UDim2.fromOffset(20, 40)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = C.GoldDim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 8)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingRight, pad.PaddingTop, pad.PaddingLeft = UDim.new(0, 10), UDim.new(0, 4), UDim.new(0, 2)
	pad.Parent = list
	ui.List = list

	local pct = function(v)
		return math.floor(v * 100 + 0.5) .. "%"
	end
	section(1, "🔊 เสียง")
	local hasMusic = false
	for _, def in pairs(Audio.Music) do
		if def.Id ~= "" then
			hasMusic = true
		end
	end
	slider(2, "MusicVol", "🎵 เพลง", 0, 1, pct, not hasMusic and "ยังไม่ได้ใส่เพลง (ใส่ ID ใน Audio.lua)" or nil)
	slider(3, "AmbientVol", "🌲 เสียงบรรยากาศ", 0, 1, pct)
	slider(4, "SfxVol", "💥 เอฟเฟกต์", 0, 1, pct)
	section(10, "🎨 กราฟิก")
	segmented(11, "Quality", "คุณภาพภาพ", { { "Low", "ต่ำ" }, { "Medium", "กลาง" }, { "High", "สูง" } }, "มือถือ/เครื่องช้า แนะนำ \"ต่ำ\"")
	section(20, "🎮 การเล่น")
	toggle(21, "Shake", "จอสั่น", "ตอนโดนตี / บอสกระแทก")
	toggle(22, "Hints", "คำแนะนำปุ่ม", "แถบบอกปุ่มด้านล่างจอ")
	toggle(23, "ShowFPS", "แสดง FPS", "ดูความลื่นของเกม")
	section(30, "📱 หน้าจอ")
	slider(31, "UIScale", "ขนาด UI", 0.7, 1.3, pct, "ย่อ/ขยายหน้าต่างทั้งหมด")
	slider(32, "TouchSize", "ขนาดปุ่มมือถือ", 0.8, 1.4, pct, "ปุ่มบนจอสำหรับนิ้ว")

	local bottom = UIKit.Frame(panel, { Size = UDim2.new(1, -40, 0, 48), Position = UDim2.new(0, 20, 1, -64), BackgroundTransparency = 1 })
	local bl = Instance.new("UIListLayout")
	bl.FillDirection = Enum.FillDirection.Horizontal
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bl.Padding = UDim.new(0, 12)
	bl.Parent = bottom
	UIKit.ColorButton(bottom, C.Purple, { Size = UDim2.fromOffset(220, 46), Text = "📖 ดูวิธีเล่น", TextSize = 20, Font = UIKit.Fonts.Title }, function()
		SettingsUI.Close()
		if handlers.Tutorial then
			handlers.Tutorial()
		end
	end)
	UIKit.ColorButton(bottom, C.Orange, { Size = UDim2.fromOffset(220, 46), Text = "↺ ค่าเริ่มต้น", TextSize = 20, Font = UIKit.Fonts.Title }, function()
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
