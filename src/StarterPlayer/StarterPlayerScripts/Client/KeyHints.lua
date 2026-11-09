--[[
	KeyHints — แผงปุ่มลัดมุมขวาล่าง (คอมเท่านั้น) สไตล์ 99 Nights: แถวเข้ม "ชื่อการกระทำ ......... [ปุ่ม]"
	  เปลี่ยนตามสถานะทุก 0.2 วิ:
	    โหมดสร้าง  -> วาง (คลิก) · หมุน R · เปลี่ยน Q · ยกเลิก ESC
	    ถือกระสอบ  -> เก็บของ (คลิก) · เอาของออก F
	    ถืออาวุธ/เครื่องมือ -> โจมตี / ตัด / ขุด / ใช้ (คลิก) · ทิ้ง ⌫
	    สกิลคลาส   -> ชื่อสกิล Q / Z
	    ประจำ      -> วิ่ง SHIFT · ปิง G · คราฟต์ C · แผนที่ M
	  ซ่อนเมื่อปิด "คำแนะนำ" ในหน้าตั้งค่า (HUD.ShowHints) · ป๊อปอัปเก็บของมุมขวาล่างถูกดันขึ้นไปเหนือแผงนี้
]]

local Players = game:GetService("Players")

local UIKit = require(script.Parent.UIKit)
local ClassSkill = require(script.Parent.ClassSkill)
local PromptUI = require(script.Parent.PromptUI)

local KeyHints = {}
local player = Players.LocalPlayer
local ROW_W, ROW_H = 196, 30
local MAX_ROWS = 13
-- แถวเสริมจากระบบอื่น (เช่น เก็บเบอร์รี่ที่ต้น): KeyHints.Extra[ชื่อ] = function() return { { "ข้อความ", "ปุ่ม" }, ... } end
KeyHints.Extra = {}

local USE_TEXT = { Axe = "Chop", Pick = "Mine", Torch = "Attack" }

-- รูปเมาส์เล็ก (ปุ่มซ้ายแดง) แทนตัวอักษร
local function mouseIcon(parent)
	local m = Instance.new("Frame")
	m.Name = "Mouse"
	m.Size = UDim2.fromOffset(16, 22)
	m.AnchorPoint = Vector2.new(0.5, 0.5)
	m.Position = UDim2.fromScale(0.5, 0.5)
	m.BackgroundColor3 = Color3.new(1, 1, 1)
	m.BorderSizePixel = 0
	m.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 7)
	c.Parent = m
	local left = Instance.new("Frame")
	left.Size = UDim2.fromOffset(7, 9)
	left.Position = UDim2.fromOffset(1, 1)
	left.BackgroundColor3 = Color3.fromRGB(230, 50, 50)
	left.BorderSizePixel = 0
	left.Parent = m
	local lc = Instance.new("UICorner")
	lc.CornerRadius = UDim.new(0, 5)
	lc.Parent = left
	local line = Instance.new("Frame")
	line.Size = UDim2.fromOffset(1, 9)
	line.Position = UDim2.fromOffset(8, 1)
	line.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	line.BorderSizePixel = 0
	line.Parent = m
	return m
end

function KeyHints.Init(deps)
	if UIKit.IsTouch then
		return
	end
	local menus, hud = deps.Menus, deps.HUD
	local gui = UIKit.Screen("ASKeyHints", 16)
	local panel = UIKit.Frame(gui, {
		Name = "Panel", BackgroundTransparency = 1,
		Size = UDim2.fromOffset(ROW_W, (ROW_H + 4) * MAX_ROWS),
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14),
	})
	UIKit.AutoScale(panel)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Parent = panel

	-- แถวสร้างครั้งเดียว แล้วเปลี่ยนข้อความ/ซ่อนตามสถานะ
	local rows = {}
	for i = 1, MAX_ROWS do
		local row = UIKit.Frame(panel, {
			Size = UDim2.fromOffset(ROW_W, ROW_H), BackgroundColor3 = Color3.fromRGB(22, 22, 26), BackgroundTransparency = 0.22,
			LayoutOrder = i, Visible = false,
		})
		UIKit.Corner(row, 3)
		local label = UIKit.Text(row, {
			Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(10, 0), Text = "", TextSize = 16, Font = UIKit.Fonts.Bold,
		})
		local cap = Instance.new("Frame")
		cap.Name = "Key"
		cap.AnchorPoint = Vector2.new(1, 0.5)
		cap.Position = UDim2.new(1, -5, 0.5, 0)
		cap.Size = UDim2.fromOffset(22, 22)
		cap.BackgroundColor3 = Color3.new(1, 1, 1)
		cap.BorderSizePixel = 0
		cap.Parent = row
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 4)
		cc.Parent = cap
		local keyLbl = Instance.new("TextLabel")
		keyLbl.BackgroundTransparency = 1
		keyLbl.Size = UDim2.fromScale(1, 1)
		keyLbl.Font = UIKit.Fonts.Title
		keyLbl.TextSize = 15 -- (จอเล็ก 900x560 ถูกย่อ -> 13 เหลือ ~9 px)
		keyLbl.TextColor3 = Color3.fromRGB(20, 20, 24)
		keyLbl.Text = ""
		keyLbl:SetAttribute("NoTranslate", true)
		keyLbl.Parent = cap
		local mouse = mouseIcon(row)
		mouse.AnchorPoint = Vector2.new(1, 0.5)
		mouse.Position = UDim2.new(1, -8, 0.5, 0)
		local hold = Instance.new("Frame")
		hold.Name = "Hold"
		hold.AnchorPoint = Vector2.new(0, 1)
		hold.Position = UDim2.fromScale(0, 1)
		hold.Size = UDim2.new(0, 0, 0, 3)
		hold.BackgroundColor3 = UIKit.Colors.Gold
		hold.BorderSizePixel = 0
		hold.Parent = row
		local accent = Instance.new("UIStroke")
		accent.Color = UIKit.Colors.Gold
		accent.Thickness = 1.5
		accent.Transparency = 0.35
		accent.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		accent.Enabled = false
		accent.Parent = row
		rows[i] = { Row = row, Label = label, Cap = cap, Key = keyLbl, Mouse = mouse, Hold = hold, Accent = accent, Shown = nil }
	end

	local function setRows(spec)
		for i, r in ipairs(rows) do
			local s = spec[i]
			r.Row.Visible = s ~= nil
			if s then
				r.Hold.Size = UDim2.new(math.clamp(s.Frac or 0, 0, 1), 0, 0, 3)
				r.Accent.Enabled = s.Prompt == true
				local id = s[1] .. "|" .. s[2]
				if r.Shown ~= id then
					r.Shown = id
					r.Label.Text = s[1]
					local isMouse = s[2] == "LMB"
					r.Mouse.Visible = isMouse
					r.Cap.Visible = not isMouse
					r.Key.Text = isMouse and "" or s[2]
					r.Cap.Size = UDim2.fromOffset(math.max(22, #s[2] * 8 + 8), 22)
				end
			end
		end
	end

	local function heldTool()
		local c = player.Character
		return c and c:FindFirstChildOfClass("Tool")
	end

	local function refresh()
		local inRun = player:GetAttribute("InRun") == true
		local out = player:GetAttribute("Downed") or player:GetAttribute("Dead")
		local show = inRun and not out and hud.ShowHints ~= false
		panel.Visible = show
		if not show then
			return
		end
		local spec = {}
		if menus.IsBuilding() then
			spec = { { "Place", "LMB" }, { "Rotate", "R" }, { "Switch", "Q" }, { "Cancel", "ESC" } }
		else
			-- ปุ่มของที่อยู่ใกล้ตัว (ProximityPrompt: กองไฟ/โต๊ะ/ของตก/กล่อง ...) = แถวบนสุด ขอบทอง · กดค้างมีแถบทองวิ่ง
			for _, e in ipairs(PromptUI.List) do
				local p = e.Prompt
				if p.Parent and p.Enabled and p.ActionText ~= "" then
					local frac = e.HoldStart and p.HoldDuration > 0 and (os.clock() - e.HoldStart) / p.HoldDuration or 0
					table.insert(spec, { p.ActionText, PromptUI.KeyText(p, Enum.ProximityPromptInputType.Keyboard), Frac = frac, Prompt = true })
				end
			end
			for _, fn in pairs(KeyHints.Extra) do
				local ok, extra = pcall(fn)
				for _, x in ipairs(ok and extra or {}) do
					x.Prompt = true
					table.insert(spec, x)
				end
			end
			local tool = heldTool()
			if tool then
				local kind = tool:GetAttribute("Kind")
				if kind == "Sack" then
					table.insert(spec, { "Pick Up", "LMB" })
					table.insert(spec, { "Take Out", "F" })
				else
					table.insert(spec, { kind and (USE_TEXT[kind] or "Attack") or "Use", "LMB" })
					table.insert(spec, { "Drop", "⌫" })
				end
			end
			for i, k in ipairs({ "Q", "Z" }) do
				local sk = ClassSkill.Info(i)
				if sk then
					table.insert(spec, { ClassSkill.NameOf(sk), k })
				end
			end
			table.insert(spec, { "Sprint", "SHIFT" })
			table.insert(spec, { "Ping", "G" })
			table.insert(spec, { "Craft", "C" })
			table.insert(spec, { "Map", "M" })
		end
		setRows(spec)
		-- ป๊อปอัปเก็บของ (มุมขวาล่างเหมือนกัน) -> อยู่เหนือแผงปุ่ม
		if hud.PickFeed then
			hud.PickFeed.Position = UDim2.new(1, -16, 1, -(14 + list.AbsoluteContentSize.Y + 10))
		end
	end

	task.spawn(function()
		while gui.Parent do
			pcall(refresh)
			task.wait(0.05)
		end
	end)
end

return KeyHints
