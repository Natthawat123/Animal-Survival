--[[
	PromptUI — การ์ดปุ่มกด (แทนปุ่ม ProximityPrompt เดิมของ Roblox) สไตล์ 99 Nights
	  การ์ดเข้มมุมมน: วงกลมปุ่ม (E / F / R / G) ซ้าย · ชื่อสิ่งของ (เล็ก สีเทา) บน · สิ่งที่จะทำ (ใหญ่ ขาว) ล่าง
	  ปุ่มกดค้าง (HoldDuration) = แถบทองวิ่งเต็มใต้การ์ด + วงกลมเปลี่ยนเป็นสีทอง
	  มือถือ: การ์ดใหญ่ แตะการ์ด = กด (วงกลมเป็นรูปนิ้ว) เรียงกลางจอค่อนล่าง
	  คอม: ไม่มีการ์ด — ปุ่มที่กดได้ขึ้นเป็นแถวบนสุดของแผงปุ่มลัดมุมขวาล่าง (KeyHints อ่าน PromptUI.List) · กดคีย์บอร์ดตามปกติ
	  ทุกปุ่มในโลกถูกตั้ง Style = Custom ที่เครื่องนี้เครื่องเดียว (เซิร์ฟเวอร์ไม่ต้องแก้)
]]

local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UIKit = require(script.Parent.UIKit)

local PromptUI = {}
local MAX_CARDS = 4
local GOLD = Color3.fromRGB(255, 208, 70)
local KEY_BG = Color3.fromRGB(58, 58, 64)
local CARD_BG = Color3.fromRGB(24, 24, 28)

local SPECIAL = {
	[Enum.KeyCode.Backspace] = "⌫", [Enum.KeyCode.LeftShift] = "SHIFT", [Enum.KeyCode.Space] = "SPACE",
	[Enum.KeyCode.Tab] = "TAB", [Enum.KeyCode.Return] = "ENTER",
}
local PAD = { ButtonX = "X", ButtonY = "Y", ButtonA = "A", ButtonB = "B", ButtonL1 = "LB", ButtonR1 = "RB" }

local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch or UIKit.IsTouch then
		return "👆"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		local k = prompt.GamepadKeyCode
		return PAD[k.Name] or k.Name
	end
	local k = prompt.KeyboardKeyCode
	if SPECIAL[k] then
		return SPECIAL[k]
	end
	local ok, s = pcall(UserInputService.GetStringForKeyCode, UserInputService, k)
	if not ok or s == nil or s == "" then
		s = k.Name
	end
	return string.upper(s)
end

PromptUI.KeyText = keyText
-- ปุ่มที่ขึ้นอยู่ตอนนี้ (เรียงตามที่โผล่) = { { Prompt, InputType, HoldStart } } · แผงปุ่มลัดของคอมอ่านจากนี่
PromptUI.List = {}

local function makeCustom(p)
	if p:IsA("ProximityPrompt") and p.Style ~= Enum.ProximityPromptStyle.Custom then
		p.Style = Enum.ProximityPromptStyle.Custom
	end
end

function PromptUI.Init()
	local touch = UIKit.IsTouch
	local W, H = touch and 280 or 250, touch and 64 or 54
	pcall(function()
		PPS.MaxPromptsVisible = MAX_CARDS
	end)

	local gui = UIKit.Screen("ASPrompts", 17)
	local holder = UIKit.Frame(gui, {
		Name = "Cards", BackgroundTransparency = 1,
		Size = UDim2.fromOffset(W, (H + 8) * MAX_CARDS),
		-- คอม: ซ้ายของตัวละคร (ตัวละครอยู่กลางจอ) · มือถือ: กลางจอค่อนล่าง นิ้วโป้งเอื้อมถึง
		AnchorPoint = touch and Vector2.new(0.5, 0.5) or Vector2.new(1, 0.5),
		Position = touch and UDim2.new(0.5, 0, 0.6, 0) or UDim2.new(0.5, -70, 0.55, 0),
	})
	UIKit.AutoScale(holder)
	-- มือถือจอเตี้ย: ต่ำลงอีกนิด ไม่ชนแจ้งเตือนกลางจอ
	local function placeCards()
		if touch then
			holder.Position = UDim2.new(0.5, 0, 0.6, 0)
		end
	end
	placeCards()
	UIKit.OnResize(placeCards)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.HorizontalAlignment = touch and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Right
	list.Parent = holder

	local cards = {} -- [prompt] = { Card, Key, KeyLbl, Bar, Tween, Conns }
	local order = 0
	local heldInput, heldPrompt

	local function resetHold(c)
		if c.Tween then
			c.Tween:Cancel()
			c.Tween = nil
		end
		c.Bar.Size = UDim2.new(0, 0, 0, 3)
		c.Key.BackgroundColor3 = KEY_BG
		c.KeyLbl.TextColor3 = Color3.new(1, 1, 1)
	end

	local function remove(prompt)
		local c = cards[prompt]
		if not c then
			return
		end
		cards[prompt] = nil
		for _, cn in ipairs(c.Conns) do
			cn:Disconnect()
		end
		if heldPrompt == prompt then
			heldPrompt, heldInput = nil, nil
		end
		c.Card:Destroy()
	end

	local function build(prompt, inputType)
		remove(prompt)
		order += 1
		local card = Instance.new("TextButton")
		card.Name = "Prompt"
		card.AutoButtonColor = false
		card.Text = ""
		card.Size = UDim2.fromOffset(W, H)
		card.BackgroundColor3 = CARD_BG
		card.BackgroundTransparency = 0.15
		card.BorderSizePixel = 0
		card.LayoutOrder = order
		card.Parent = holder
		UIKit.Corner(card, 8)
		local st = Instance.new("UIStroke")
		st.Color = Color3.new(1, 1, 1)
		st.Transparency = 0.86
		st.Thickness = 1
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = card

		-- วงกลมปุ่ม
		local d = H - 16
		local key = Instance.new("Frame")
		key.Name = "Key"
		key.Size = UDim2.fromOffset(d, d)
		key.Position = UDim2.fromOffset(8, 8)
		key.BackgroundColor3 = KEY_BG
		key.BorderSizePixel = 0
		key.Parent = card
		local kc = Instance.new("UICorner")
		kc.CornerRadius = UDim.new(1, 0)
		kc.Parent = key
		local ks = Instance.new("UIStroke")
		ks.Color = Color3.new(1, 1, 1)
		ks.Transparency = 0.3
		ks.Thickness = 2
		ks.Parent = key
		local txt = keyText(prompt, inputType)
		local keyLbl = UIKit.Text(key, {
			Size = UDim2.fromScale(0.8, 0.8), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Text = txt, TextScaled = true, Font = UIKit.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Center,
		})
		keyLbl:SetAttribute("NoTranslate", true)
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = #txt > 2 and 12 or (touch and 26 or 22)
		cap.Parent = keyLbl

		-- ข้อความ: ชื่อสิ่งของ (เล็ก) + สิ่งที่จะทำ (ใหญ่)
		local x = d + 18
		local obj = UIKit.Text(card, {
			Size = UDim2.new(1, -x - 10, 0, touch and 17 or 15), Position = UDim2.fromOffset(x, touch and 8 or 7),
			Text = "", TextSize = touch and 15 or 13, Font = UIKit.Fonts.Body, TextColor3 = Color3.fromRGB(176, 176, 184),
		})
		local act = UIKit.Text(card, {
			Size = UDim2.new(1, -x - 10, 0, touch and 26 or 23), Position = UDim2.fromOffset(x, touch and 27 or 23),
			Text = "", TextSize = touch and 21 or 18, Font = UIKit.Fonts.Bold,
		})
		obj:SetAttribute("NoTranslate", true)
		act:SetAttribute("NoTranslate", true)
		local function sync()
			local o = prompt.ObjectText or ""
			obj.Text = o
			obj.Visible = o ~= ""
			act.Text = prompt.ActionText or ""
			-- ไม่มีชื่อสิ่งของ -> ตัวหนังสือหลักอยู่กลางการ์ด
			act.Position = o ~= "" and UDim2.fromOffset(x, touch and 27 or 23) or UDim2.new(0, x, 0.5, -(touch and 13 or 11))
		end
		sync()

		-- แถบกดค้าง
		local bar = Instance.new("Frame")
		bar.Name = "Hold"
		bar.Size = UDim2.new(0, 0, 0, 3)
		bar.Position = UDim2.new(0, 8, 1, -5)
		bar.BackgroundColor3 = GOLD
		bar.BorderSizePixel = 0
		bar.Parent = card
		UIKit.Corner(bar, 0)

		local c = { Card = card, Key = key, KeyLbl = keyLbl, Bar = bar, Conns = {} }
		cards[prompt] = c
		table.insert(c.Conns, prompt:GetPropertyChangedSignal("ActionText"):Connect(sync))
		table.insert(c.Conns, prompt:GetPropertyChangedSignal("ObjectText"):Connect(sync))
		-- แตะ/คลิกการ์ด = กดปุ่ม (ปล่อยนิ้วที่ไหนก็ได้ = ปล่อยปุ่ม)
		table.insert(c.Conns, card.InputBegan:Connect(function(input)
			local t = input.UserInputType
			if (t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1) and not heldInput then
				heldInput, heldPrompt = input, prompt
				prompt:InputHoldBegin()
			end
		end))

		-- โผล่แบบเด้ง
		local sc = Instance.new("UIScale")
		sc.Scale = 0.85
		sc.Parent = card
		TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	UserInputService.InputEnded:Connect(function(input)
		if heldInput and input == heldInput then
			local p = heldPrompt
			heldInput, heldPrompt = nil, nil
			if p and p.Parent then
				p:InputHoldEnd()
			end
		end
	end)

	local function entryOf(prompt)
		for i, e in ipairs(PromptUI.List) do
			if e.Prompt == prompt then
				return e, i
			end
		end
	end

	---------------------------------------------------------------- วงกลมโหลดตรงของ (แบบ 99 Nights)
	-- คอม: วงกลมปุ่ม (E/R/F) ลอยตรงของทุกอันที่กดได้ · กดค้าง = วงทองวิ่งรอบจนเต็ม
	-- มือถือ: โผล่เฉพาะตอนกดค้าง (ปุ่มกดอยู่ที่การ์ดกลางจอแล้ว)
	-- วงทอง = ครึ่งซ้าย/ครึ่งขวา (กรอบตัดขอบ) + UIGradient ขอบคมบน UIStroke หมุนตามความคืบหน้า
	local RING = 54
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function half(parent, left)
		local clip = Instance.new("Frame")
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Size = UDim2.fromScale(0.5, 1)
		clip.Position = UDim2.fromScale(left and 0 or 0.5, 0)
		clip.ZIndex = 3
		clip.Parent = parent
		local ring = Instance.new("Frame")
		ring.BackgroundTransparency = 1
		ring.Size = UDim2.new(2, -10, 1, -10)
		ring.Position = left and UDim2.fromOffset(5, 5) or UDim2.new(-1, 5, 0, 5)
		ring.ZIndex = 3
		ring.Parent = clip
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = ring
		local st = Instance.new("UIStroke")
		st.Color = GOLD
		st.Thickness = 4
		st.Parent = ring
		local g = Instance.new("UIGradient")
		-- ซ้าย: ทึบครึ่งขวาของวง · ขวา: ทึบครึ่งซ้าย -> หมุน 0..180 = ค่อยๆ เผยทีละครึ่ง (ตามเข็มนาฬิกาจากบนสุด)
		g.Transparency = left and NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(0.501, 0), NumberSequenceKeypoint.new(1, 0) })
			or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = st
		return g
	end
	local function setRing(e, frac)
		if not e.Ring then
			return
		end
		local deg = math.clamp(frac, 0, 1) * 360
		e.Ring.R.Rotation = math.min(deg, 180)
		e.Ring.L.Rotation = math.clamp(deg - 180, 0, 180)
		e.Ring.Key.BackgroundColor3 = frac > 0 and GOLD or KEY_BG
		e.Ring.Txt.TextColor3 = frac > 0 and Color3.fromRGB(30, 26, 18) or Color3.new(1, 1, 1)
	end
	local function dropRing(e)
		if e.Ring then
			e.Ring.Gui:Destroy()
			e.Ring = nil
		end
	end
	local function ringFor(e)
		if e.Ring then
			return e.Ring
		end
		local prompt = e.Prompt
		local ad = prompt.Parent
		if not ad or not (ad:IsA("BasePart") or ad:IsA("Attachment") or ad:IsA("Model")) then
			return nil
		end
		-- ของชิ้นเดียวมีหลายปุ่ม (กองไฟ R/E) -> วางวงเรียงข้างกัน
		local same = 0
		for _, o in ipairs(PromptUI.List) do
			if o ~= e and o.Ring and o.Prompt.Parent == ad then
				same += 1
			end
		end
		local bb = Instance.new("BillboardGui")
		bb.Name = "ASPromptRing"
		bb.Size = UDim2.fromOffset(RING, RING)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.ResetOnSpawn = false
		bb.MaxDistance = 80
		bb.Adornee = ad
		bb.StudsOffset = Vector3.new(same * 2.6, ad:IsA("BasePart") and 1.2 or 0.6, 0)
		local back = Instance.new("Frame")
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = CARD_BG
		back.BackgroundTransparency = 0.35
		back.BorderSizePixel = 0
		back.Parent = bb
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(1, 0)
		bc.Parent = back
		-- รางวงสีเทา
		local track = Instance.new("Frame")
		track.BackgroundTransparency = 1
		track.Size = UDim2.new(1, -10, 1, -10)
		track.Position = UDim2.fromOffset(5, 5)
		track.ZIndex = 2
		track.Parent = bb
		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(1, 0)
		tc.Parent = track
		local ts = Instance.new("UIStroke")
		ts.Color = Color3.new(1, 1, 1)
		ts.Transparency = 0.6
		ts.Thickness = 4
		ts.Parent = track
		local L, R = half(bb, true), half(bb, false)
		-- ปุ่มกลางวง
		local key = Instance.new("Frame")
		key.AnchorPoint = Vector2.new(0.5, 0.5)
		key.Position = UDim2.fromScale(0.5, 0.5)
		key.Size = UDim2.fromOffset(RING - 22, RING - 22)
		key.BackgroundColor3 = KEY_BG
		key.BorderSizePixel = 0
		key.ZIndex = 4
		key.Parent = bb
		local kc = Instance.new("UICorner")
		kc.CornerRadius = UDim.new(1, 0)
		kc.Parent = key
		local txt = Instance.new("TextLabel")
		txt.BackgroundTransparency = 1
		txt.Size = UDim2.fromScale(1, 1)
		txt.Font = UIKit.Fonts.Title
		txt.TextScaled = true
		txt.TextColor3 = Color3.new(1, 1, 1)
		txt.Text = keyText(prompt, touch and Enum.ProximityPromptInputType.Touch or e.InputType)
		txt.ZIndex = 5
		txt:SetAttribute("NoTranslate", true)
		txt.Parent = key
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0.18, 0), UDim.new(0.18, 0)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0.12, 0), UDim.new(0.12, 0)
		pad.Parent = key
		bb.Parent = playerGui
		e.Ring = { Gui = bb, L = L, R = R, Key = key, Txt = txt }
		setRing(e, 0)
		return e.Ring
	end
	RunService.RenderStepped:Connect(function()
		for _, e in ipairs(PromptUI.List) do
			if e.HoldStart and e.Ring then
				local d = e.Prompt.HoldDuration
				setRing(e, d > 0 and (os.clock() - e.HoldStart) / d or 1)
			end
		end
	end)

	PPS.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			makeCustom(prompt)
		end
		local e = entryOf(prompt)
		if not e then
			e = { Prompt = prompt, InputType = inputType }
			table.insert(PromptUI.List, e)
		end
		if touch then
			build(prompt, inputType) -- มือถือ: การ์ดกลางจอให้แตะ · คอม: ขึ้นในแผงปุ่มลัดขวาล่าง (KeyHints)
		else
			ringFor(e) -- คอม: วงกลมปุ่มตรงของ
		end
	end)
	PPS.PromptHidden:Connect(function(prompt)
		local e, i = entryOf(prompt)
		if i then
			dropRing(e)
			table.remove(PromptUI.List, i)
		end
		remove(prompt)
	end)
	PPS.PromptButtonHoldBegan:Connect(function(prompt)
		local e = entryOf(prompt)
		if e then
			e.HoldStart = os.clock()
			ringFor(e) -- มือถือ: โผล่ตอนกดค้าง
		end
	end)
	PPS.PromptButtonHoldEnded:Connect(function(prompt)
		local e = entryOf(prompt)
		if e then
			e.HoldStart = nil
			if touch then
				dropRing(e)
			else
				setRing(e, 0)
			end
		end
	end)
	PPS.PromptTriggered:Connect(function(prompt)
		local e = entryOf(prompt)
		if e and e.Ring then
			setRing(e, 1)
			task.delay(0.2, function()
				if e.Ring and not e.HoldStart then
					if touch then
						dropRing(e)
					else
						setRing(e, 0)
					end
				end
			end)
		end
	end)
	PPS.PromptButtonHoldBegan:Connect(function(prompt)
		local c = cards[prompt]
		if not c then
			return
		end
		resetHold(c)
		c.Key.BackgroundColor3 = GOLD
		c.KeyLbl.TextColor3 = Color3.fromRGB(30, 26, 18)
		if prompt.HoldDuration > 0 then
			c.Tween = TweenService:Create(c.Bar, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.new(1, -16, 0, 3) })
			c.Tween:Play()
		end
	end)
	PPS.PromptButtonHoldEnded:Connect(function(prompt)
		local c = cards[prompt]
		if c then
			resetHold(c)
		end
	end)
	PPS.PromptTriggered:Connect(function(prompt)
		local c = cards[prompt]
		if not c then
			return
		end
		c.Card.BackgroundColor3 = Color3.fromRGB(70, 62, 30)
		TweenService:Create(c.Card, TweenInfo.new(0.25), { BackgroundColor3 = CARD_BG }):Play()
		task.delay(0.05, function()
			if cards[prompt] == c then
				resetHold(c)
			end
		end)
	end)

	-- เปลี่ยนทุกปุ่มในโลกเป็นแบบกำหนดเอง (ของที่มีอยู่แล้ว + ของที่เกิดใหม่)
	Workspace.DescendantAdded:Connect(makeCustom)
	task.spawn(function()
		for i, d in ipairs(Workspace:GetDescendants()) do
			makeCustom(d)
			if i % 4000 == 0 then
				task.wait()
			end
		end
	end)
end

return PromptUI
