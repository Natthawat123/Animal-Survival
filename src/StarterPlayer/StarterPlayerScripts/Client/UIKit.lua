--[[
	UIKit — ตัวช่วยสร้าง UI โทนดำ-ทอง (สไตล์ Souls) ใช้ทั้งเกม
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.Colors = {
	Panel = Color3.fromRGB(14, 13, 16),
	Panel2 = Color3.fromRGB(26, 24, 28),
	Gold = Color3.fromRGB(226, 190, 120),
	GoldDim = Color3.fromRGB(150, 122, 78),
	Text = Color3.fromRGB(238, 232, 220),
	TextDim = Color3.fromRGB(170, 162, 150),
	Red = Color3.fromRGB(196, 40, 40),
	Blood = Color3.fromRGB(150, 18, 24),
	Health = Color3.fromRGB(196, 52, 52),
	Hunger = Color3.fromRGB(226, 150, 60),
	Stamina = Color3.fromRGB(110, 190, 90),
	Fire = Color3.fromRGB(255, 140, 50),
	Good = Color3.fromRGB(120, 230, 140),
	Bad = Color3.fromRGB(255, 90, 80),
	Element = {
		Earth = Color3.fromRGB(130, 230, 90),
		Water = Color3.fromRGB(80, 200, 255),
		Air = Color3.fromRGB(220, 232, 255),
		Fire = Color3.fromRGB(255, 110, 40),
		All = Color3.fromRGB(255, 70, 90),
	},
}
UIKit.ElementThai = { Earth = "ปฐพี", Water = "วารี", Air = "วายุ", Fire = "อัคคี", All = "ทุกธาตุ" }
UIKit.ElementIcon = { Earth = "🌿", Water = "🌊", Air = "🌪", Fire = "🔥", All = "🩸" }

UIKit.Fonts = {
	Title = Enum.Font.Garamond,
	Bold = Enum.Font.GothamBold,
	Black = Enum.Font.GothamBlack,
	Body = Enum.Font.Gotham,
}

function UIKit.Screen(name, order)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = order or 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function UIKit.Frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = UIKit.Colors.Panel
	f.BackgroundTransparency = 0.25
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

function UIKit.Corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = parent
	return c
end

function UIKit.Stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or UIKit.Colors.GoldDim
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UIKit.Gradient(parent, c0, c1, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

function UIKit.Text(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextColor3 = UIKit.Colors.Text
	t.Font = UIKit.Fonts.Bold
	t.TextSize = 16
	t.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in pairs(props or {}) do
		t[k] = v
	end
	t.Parent = parent
	return t
end

function UIKit.Button(parent, props, onClick)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.BackgroundColor3 = UIKit.Colors.Panel2
	b.TextColor3 = UIKit.Colors.Gold
	b.Font = UIKit.Fonts.Bold
	b.TextSize = 16
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	b.Parent = parent
	UIKit.Corner(b, 8)
	local stroke = UIKit.Stroke(b, UIKit.Colors.GoldDim, 1, 0.3)
	b.MouseEnter:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0, Color = UIKit.Colors.Gold }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0.3, Color = UIKit.Colors.GoldDim }):Play()
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- แถบค่า (เลือด/หิว/สตามิน่า)
function UIKit.Bar(parent, props)
	local holder = UIKit.Frame(parent, {
		Size = props.Size, Position = props.Position, BackgroundColor3 = Color3.fromRGB(8, 8, 10), BackgroundTransparency = 0.2,
	})
	UIKit.Stroke(holder, UIKit.Colors.GoldDim, 1, 0.45)
	local lag = UIKit.Frame(holder, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(230, 220, 200), BackgroundTransparency = 0.3 })
	local fill = UIKit.Frame(holder, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = props.Color, BackgroundTransparency = 0 })
	UIKit.Gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150), 90)
	local label = UIKit.Text(holder, {
		Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(6, 0), TextSize = 12, Font = UIKit.Fonts.Bold,
		Text = props.Label or "", TextColor3 = Color3.new(1, 1, 1), ZIndex = 3, TextStrokeTransparency = 0.5,
	})
	local api = { Holder = holder, Fill = fill, Label = label, Value = 1 }
	function api.Set(frac, text)
		frac = math.clamp(frac, 0, 1)
		if math.abs(frac - api.Value) > 0.001 then
			fill.Size = UDim2.fromScale(frac, 1)
			if frac < api.Value then
				TweenService:Create(lag, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.25), { Size = UDim2.fromScale(frac, 1) }):Play()
			else
				lag.Size = UDim2.fromScale(frac, 1)
			end
			api.Value = frac
		end
		if text then
			label.Text = text
		end
	end
	return api
end

function UIKit.Tween(obj, time, props, style)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

return UIKit
