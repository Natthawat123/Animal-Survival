--[[
	Backpack — แถบเครื่องมือ + กระเป๋า หน้าตาแบบของ Roblox (แทน CoreGui Backpack)
	  ต่างจากของ Roblox: ปุ่มกระเป๋าโชว์ตลอด (ไม่ต้องรอของเกินช่อง) · ลากจัดลำดับ/สลับช่องได้ทั้งเมาส์และนิ้ว
	  ช่อง = Tool ทั้งหมดใน Backpack/ตัวละคร (อาวุธ เครื่องมือ กระสอบ สิ่งก่อสร้าง)
	  กดเลข 1-9,0 / แตะช่อง = ถือ-เก็บ · ` หรือปุ่มกระเป๋า = เปิดกระเป๋า
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local ItemIcon = require(script.Parent.ItemIcon)
local UIKit = require(script.Parent.UIKit)

local Backpack = {}
local player = Players.LocalPlayer
local N = 10
local SLOT = 60
local KEYS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6, [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9, [Enum.KeyCode.Zero] = 10,
}
local slots = {} -- [i] = Tool
local ui = { Slots = {} }
local shown = true
local picked -- Tool ที่แตะเลือกไว้ (มือถือ: แตะของ -> แตะช่อง)
local drag -- { Tool, From = slotIndex|nil, Ghost, Start, Moved }

-- สีแบบแถบเครื่องมือของ Roblox
local BG = Color3.fromRGB(25, 27, 29)
local BG_T = 0.3
local SEL = Color3.fromRGB(255, 255, 255)

-- Tool ทั้งหมด (ตัวละครก่อน = อันที่ถือ) · ไอเทมเดียวกันโชว์ช่องเดียว (กันช่องซ้ำตอน server ยังลบ Tool ซ้ำไม่ทัน)
local function tools()
	local list, seen = {}, {}
	local holders = { player.Character }
	for _, c in ipairs(player:GetChildren()) do
		if c:IsA("Backpack") then
			table.insert(holders, c)
		end
	end
	for _, holder in ipairs(holders) do
		for _, t in ipairs(holder:GetChildren()) do
			if t:IsA("Tool") then
				local key = t:GetAttribute("StructureKind") or t:GetAttribute("ItemId") or t
				if not seen[key] then
					seen[key] = true
					table.insert(list, t)
				end
			end
		end
	end
	return list
end

-- ช่องที่ Tool นี้อยู่ (ไล่ครบทุกช่อง 1..N)
--   ห้ามใช้ table.find กับ slots: slots มีช่องว่าง (nil) -> table.find หยุดที่ช่องว่างแรก หาไม่เจอ
--   -> เคยใส่ Tool เดิมซ้ำลงช่องว่างทุกครั้งที่ Refresh (ไอเทมงอกเป็นแถวยาว ขวาน/กระสอบหลายช่อง)
local function slotOf(t)
	for i = 1, N do
		if slots[i] == t then
			return i
		end
	end
	return nil
end

local function equipped(t)
	return t and player.Character and t.Parent == player.Character
end

local function toggle(t)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (t and hum) then
		return
	end
	if equipped(t) then
		hum:UnequipTools()
	else
		hum:EquipTool(t)
	end
end

-- รูปในช่อง: TextureId ของ Tool -> โมเดลจริง -> ชื่อ
local function fillIcon(holder, t)
	holder:ClearAllChildren()
	if not t then
		return
	end
	if t.TextureId ~= "" then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = t.TextureId
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = holder
		return
	end
	local id = t:GetAttribute("StructureKind") or t:GetAttribute("ItemId")
	if id then
		local vp = ItemIcon.Make(holder, id, { Size = UDim2.fromScale(1, 1) })
		if vp:FindFirstChildOfClass("Camera") then
			return
		end
		vp:Destroy()
	end
	local txt = Instance.new("TextLabel")
	txt.BackgroundTransparency = 1
	txt.Size = UDim2.fromScale(1, 1)
	txt.Font = Enum.Font.BuilderSansBold
	txt.TextScaled = true
	txt.TextWrapped = true
	txt.TextColor3 = Color3.new(1, 1, 1)
	txt.Text = t.Name
	txt.Parent = holder
end

local function countText(t)
	local n = t:GetAttribute("Count")
	if n and n > 1 then
		return "x" .. n
	end
	return t:GetAttribute("Fill") or ""
end

local function slotAt(pos)
	for i, s in pairs(ui.Slots) do
		local a, z = s.Button.AbsolutePosition, s.Button.AbsoluteSize
		if pos.X >= a.X and pos.X <= a.X + z.X and pos.Y >= a.Y and pos.Y <= a.Y + z.Y then
			return i
		end
	end
end

-- ใส่ Tool ลงช่อง i (ของเดิมในช่องสลับไปช่องเก่าของ Tool นี้)
local function assign(t, i)
	local from = slotOf(t)
	local old = slots[i]
	slots[i] = t
	if from and from ~= i then
		slots[from] = old
	end
	Backpack.Refresh()
end

-- ลบรูปลากที่ค้างทั้งหมด (มือถือ: นิ้วหลุดจอ/ถูกขัดจังหวะ InputEnded ไม่มา -> กล่องดำค้างบนแถบ)
local function clearGhosts(keep)
	for _, c in ipairs(ui.Gui and ui.Gui:GetChildren() or {}) do
		if c.Name == "DragGhost" and c ~= keep then
			c:Destroy()
		end
	end
end

-- มือถือ: ลากตามนิ้วที่กดช่องเท่านั้น (Input เดียวกัน) — เดิมนิ้วที่จับจอยเดินนับเป็นการลากด้วย + แตะรัวๆ ทับ drag เก่า
--   -> รูปของ (Ghost) ค้างจอ งอกเพิ่มทุกครั้งที่แตะ เห็นเป็นอาวุธ/กระสอบเต็มจอ
local function startPress(t, fromSlot, input)
	if drag and drag.Ghost then
		drag.Ghost:Destroy()
	end
	clearGhosts()
	drag = { Tool = t, From = fromSlot, Start = Vector2.new(input.Position.X, input.Position.Y), Moved = false,
		Input = input.UserInputType == Enum.UserInputType.Touch and input or nil }
end
local function sameFinger(input)
	return not (drag and drag.Input) or input == drag.Input
end

local function makeGhost(t)
	clearGhosts()
	local g = Instance.new("Frame")
	g.Name = "DragGhost"
	local k = ui.Scale and ui.Scale.Scale or 1 -- ขนาดเท่าช่องจริง (แถบถูกย่อตามจอ)
	g.Size = UDim2.fromOffset(SLOT * k, SLOT * k)
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.BackgroundColor3 = BG
	g.BackgroundTransparency = 0.15
	g.ZIndex = 50
	g.Parent = ui.Gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = g
	local h = Instance.new("Frame")
	h.BackgroundTransparency = 1
	h.Size = UDim2.new(1, -8, 1, -8)
	h.Position = UDim2.fromOffset(4, 4)
	h.ZIndex = 51
	h.Parent = g
	fillIcon(h, t)
	return g
end

local function buildSlot(i)
	local b = Instance.new("TextButton")
	b.Name = "Slot" .. i
	b.Text = ""
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(SLOT, SLOT)
	b.BackgroundColor3 = BG
	b.BackgroundTransparency = BG_T
	b.LayoutOrder = i
	b.Parent = ui.Bar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = SEL
	stroke.Thickness = 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, -10, 1, -10)
	holder.Position = UDim2.fromOffset(5, 5)
	holder.Parent = b
	local key = Instance.new("TextLabel")
	key.BackgroundTransparency = 1
	key.Size = UDim2.fromOffset(16, 16)
	key.Position = UDim2.fromOffset(3, 1)
	key.Font = Enum.Font.BuilderSansBold
	key.TextSize = 13
	key.TextColor3 = Color3.new(1, 1, 1)
	key.Text = tostring(i % 10)
	key.Visible = not UIKit.IsTouch -- เลขปุ่มลัดคีย์บอร์ด: จอสัมผัสไม่ต้องใช้
	key.ZIndex = 2
	key.Parent = b
	local count = Instance.new("TextLabel")
	count.BackgroundTransparency = 1
	count.Size = UDim2.new(1, -6, 0, UIKit.IsTouch and 17 or 14)
	count.AnchorPoint = Vector2.new(0, 1)
	count.Position = UDim2.new(0, 3, 1, -1)
	count.Font = Enum.Font.BuilderSansBold
	count.TextSize = UIKit.IsTouch and 15 or 12
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.TextColor3 = Color3.new(1, 1, 1)
	count.TextStrokeTransparency = 0.4
	count.ZIndex = 2
	count.Parent = b
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if slots[i] then
				startPress(slots[i], i, input)
			elseif picked then
				assign(picked, i)
				picked = nil
			end
		end
	end)
	ui.Slots[i] = { Button = b, Stroke = stroke, Holder = holder, Count = count, Key = key }
end

function Backpack.Build()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	task.spawn(function()
		for _ = 1, 10 do
			task.wait(1)
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
		end
	end)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ASBackpack"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6 -- เหนือ HUD: กระเป๋าไม่โดนการ์ดเลือดบัง
	gui.Parent = player:WaitForChild("PlayerGui")
	ui.Gui = gui
	local scale = Instance.new("UIScale")
	-- สเกลแถบคิดจาก "จำนวนช่องที่โชว์อยู่" (โชว์เฉพาะช่องที่มีของ) -> มือถือของน้อยช่องก็ใหญ่กดง่าย
	-- กระเป๋า (โชว์ครบ 10 ช่อง) ใช้สเกลของแถบเต็มแยกกัน
	local invScale
	local function fitFor(n)
		local vp = UIKit.Viewport()
		local w = (SLOT + 5) * n + SLOT
		local s = math.min((vp.X - 80) / w, 1)
		if UIKit.IsTouch then
			-- จอสัมผัส: เว้นจอยสติ๊ก (ซ้ายล่าง) + ปุ่มกระโดด/ปุ่มกลม (ขวาล่าง) · แถบสูงไม่เกิน ~15% ของจอ
			local side = (ui.Inv and ui.Inv.Visible) and 20 or (UIKit.IsPhone() and 175 or 270) -- เปิดกระเป๋า: ไม่ต้องเว้นจอยสติ๊ก ช่องใหญ่กดง่าย
			s = math.min(s, (vp.X - 2 * side) / w, vp.Y * 0.15 / SLOT)
		end
		return math.clamp(s, 0.45, 1) * UIKit.BigScale()
	end
	local function rescale()
		scale.Scale = fitFor(math.max(ui.Shown or N, 3))
		if invScale then
			invScale.Scale = fitFor(N)
			ui.Inv.Position = UDim2.new(0.5, 0, 1, -(SLOT * scale.Scale + 16))
		end
	end
	ui.Rescale = rescale
	-- แถบช่อง (ล่างกลาง) + ปุ่มกระเป๋าท้ายแถบ
	local bar = Instance.new("Frame")
	bar.Name = "Hotbar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -6)
	bar.Size = UDim2.fromOffset((SLOT + 5) * N + SLOT, SLOT)
	bar.Parent = gui
	scale.Parent = bar
	ui.Scale = scale
	rescale()
	UIKit.OnResize(rescale)
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Padding = UDim.new(0, 5)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = bar
	ui.Bar = bar
	for i = 1, N do
		buildSlot(i)
	end
	-- ปุ่มกระเป๋า: วงกลมเข้ม + ไอคอนกระเป๋าของ Roblox เอง (ตัวเดียวกับแถบบน) · เปิดอยู่ = ไอคอนทึบ
	-- อยู่มุมซ้ายบน ต่อจากปุ่มเมนู/แชทของ Roblox (TopbarInset.Min.X) ในแถวเดียวกัน (ScreenGui แยก ไม่เว้นที่แถบบน)
	local topGui = Instance.new("ScreenGui")
	topGui.Name = "ASBackpackButton"
	topGui.ResetOnSpawn = false
	topGui.IgnoreGuiInset = true
	topGui.DisplayOrder = 7
	topGui.Parent = gui.Parent
	ui.TopGui = topGui
	local bagBtn = Instance.new("ImageButton")
	bagBtn.Name = "InventoryButton"
	bagBtn.Size = UDim2.fromOffset(44, 44)
	local function placeBag()
		local inset = GuiService.TopbarInset
		local x = (inset.Min.X > 0 and inset.Min.X or 104) + 8
		local h = inset.Height > 0 and inset.Height or 58
		bagBtn.Position = UDim2.fromOffset(x, inset.Min.Y + math.max(0, (h - 44) / 2))
	end
	placeBag()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeBag)
	bagBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
	bagBtn.BackgroundTransparency = 0.3
	bagBtn.Image = ""
	bagBtn.Parent = topGui
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(1, 0)
	bc.Parent = bagBtn
	local bt = Instance.new("ImageLabel")
	bt.BackgroundTransparency = 1
	bt.AnchorPoint = Vector2.new(0.5, 0.5)
	bt.Position = UDim2.fromScale(0.5, 0.5)
	bt.Size = UDim2.fromScale(0.62, 0.62)
	bt.Image = "rbxasset://textures/ui/TopBar/inventoryOff@3x.png"
	bt.ScaleType = Enum.ScaleType.Fit
	bt.Parent = bagBtn
	ui.BagIcon = bt
	bagBtn.Activated:Connect(function()
		Backpack.ToggleInventory()
	end)
	ui.BagBtn = bagBtn

	-- กระเป๋า (เหนือแถบ): ของทั้งหมด ลากลงช่อง / แตะของแล้วแตะช่อง
	local inv = Instance.new("Frame")
	inv.Name = "Inventory"
	inv.AnchorPoint = Vector2.new(0.5, 1)
	inv.Position = UDim2.new(0.5, 0, 1, -(SLOT + 16))
	inv.Size = UDim2.fromOffset((SLOT + 5) * N + SLOT, 250)
	inv.BackgroundColor3 = BG
	inv.BackgroundTransparency = UIKit.IsTouch and 0.06 or BG_T -- จอสัมผัส: ทึบ (จอเล็ก กระเป๋าซ้อนการ์ดเลือด)
	inv.Visible = false
	inv.Parent = gui
	local ic = Instance.new("UICorner")
	ic.CornerRadius = UDim.new(0, 8)
	ic.Parent = inv
	invScale = Instance.new("UIScale")
	invScale.Parent = inv
	ui.Inv = inv
	rescale()
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -20, 0, 28)
	title.Position = UDim2.fromOffset(12, 6)
	title.Font = Enum.Font.BuilderSansBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "กระเป๋า  ·  ลากของไปวางที่ช่องด้านล่าง (สลับช่องได้)"
	title.Parent = inv
	ui.InvTitle = title
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, -16, 1, -44)
	scroll.Position = UDim2.fromOffset(8, 38)
	scroll.ScrollBarThickness = 5
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = inv
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(SLOT, SLOT)
	g.CellPadding = UDim2.fromOffset(5, 5)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = scroll
	ui.Inv, ui.InvScroll = inv, scroll

	-- ลาก: ตามเมาส์/นิ้ว แล้วปล่อยลงช่อง
	UserInputService.InputChanged:Connect(function(input)
		if not drag then
			return
		end
		if (input.UserInputType == Enum.UserInputType.MouseMovement and not drag.Input)
			or (input.UserInputType == Enum.UserInputType.Touch and sameFinger(input)) then
			local p = Vector2.new(input.Position.X, input.Position.Y)
			if not drag.Moved and (p - drag.Start).Magnitude > 8 then
				drag.Moved = true
				drag.Ghost = makeGhost(drag.Tool)
				Backpack.Refresh()
			end
			if drag.Ghost then
				drag.Ghost.Position = UDim2.fromOffset(p.X, p.Y)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not drag then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch and not sameFinger(input) then
			return -- ปล่อยนิ้วอื่น (จอยเดิน/กล้อง) ไม่ใช่การปล่อยช่องนี้
		end
		local d = drag
		drag = nil
		if d.Ghost then
			d.Ghost:Destroy()
		end
		clearGhosts()
		local p = Vector2.new(input.Position.X, input.Position.Y)
		if d.Moved then
			local i = slotAt(p)
			if i then
				assign(d.Tool, i)
			elseif d.From and ui.Inv.Visible then
				-- ลากออกจากแถบไปที่กระเป๋า = เอาออกจากช่อง
				slots[d.From] = nil
				Backpack.Refresh()
			end
		elseif d.From then
			toggle(d.Tool) -- แตะช่อง = ถือ/เก็บ
		else
			picked = (picked ~= d.Tool) and d.Tool or nil -- แตะของในกระเป๋า = เลือก แล้วแตะช่อง
		end
		Backpack.Refresh() -- ลากเสร็จ: ซ่อนช่องว่างกลับ
	end)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		local i = KEYS[input.KeyCode]
		if i and bar.Visible and slots[i] then
			toggle(slots[i])
		elseif input.KeyCode == Enum.KeyCode.Backquote then
			Backpack.ToggleInventory()
		end
	end)
	local function watch(holder)
		if holder then
			holder.ChildAdded:Connect(function()
				task.defer(Backpack.Refresh)
			end)
			holder.ChildRemoved:Connect(function()
				task.defer(Backpack.Refresh)
			end)
		end
	end
	watch(player:WaitForChild("Backpack", 30))
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(function(c)
		watch(c)
		task.defer(function()
			watch(player:WaitForChild("Backpack", 10))
			Backpack.Refresh()
		end)
	end)
	task.spawn(function()
		while gui.Parent do
			task.wait(0.5)
			-- กันรูปลากค้าง: ไม่ได้ลากอยู่ = ไม่ควรมีกล่องลากบนจอ · ลากค้างนานผิดปกติ (นิ้วหลุด) = ยกเลิก
			if drag and drag.Input and drag.Input.UserInputState == Enum.UserInputState.End then
				drag = nil
			end
			clearGhosts(drag and drag.Ghost)
			local ok, err = pcall(Backpack.Refresh) -- จำนวน/ชื่อเปลี่ยน (Count, กระสอบ 3/10) · error ห้ามทำลูปตาย (ช่องค้างของเก่า)
			if not ok then
				warn("[Backpack] refresh error: " .. tostring(err))
			end
		end
	end)
	Backpack.Refresh()
end

function Backpack.Refresh()
	if not ui.Bar then
		return
	end
	-- กันพลาด: รูปลากที่ไม่มีเจ้าของแล้ว (ไม่ได้ลากอยู่) ลบทิ้ง
	for _, c in ipairs(ui.Gui:GetChildren()) do
		if c.Name == "DragGhost" and not (drag and drag.Ghost == c) then
			c:Destroy()
		end
	end
	local list = tools()
	local present = {}
	for _, t in ipairs(list) do
		present[t] = true
	end
	-- ล้างช่อง: Tool ที่ไม่มีแล้ว / Tool เดียวกันซ้ำหลายช่อง / ไอเทมชนิดเดียวกันซ้ำ (เก็บช่องแรก)
	local used, usedKey = {}, {}
	for i = 1, N do
		local t = slots[i]
		if t then
			local key = t:GetAttribute("StructureKind") or t:GetAttribute("ItemId") or t
			if not present[t] or used[t] or usedKey[key] then
				slots[i] = nil
			else
				used[t] = true
				usedKey[key] = true
			end
		end
	end
	for _, t in ipairs(list) do
		if not slotOf(t) then
			for i = 1, N do
				if not slots[i] then
					slots[i] = t
					break
				end
			end
		end
	end
	if picked and not present[picked] then
		picked = nil
	end
	for i = 1, N do
		local s = ui.Slots[i]
		local t = slots[i]
		if s.Tool ~= t or (t and s.Tex ~= t.TextureId) then
			fillIcon(s.Holder, t)
			s.Tool = t
			s.Tex = t and t.TextureId
		end
		s.Count.Text = t and countText(t) or ""
		local on = equipped(t)
		s.Stroke.Thickness = on and 3 or (picked and 1 or 0)
		s.Stroke.Color = picked and Color3.fromRGB(120, 220, 255) or SEL
		s.Button.BackgroundTransparency = on and 0.05 or BG_T
		-- โชว์เฉพาะช่องที่มีของ (ช่องว่างโผล่ตอนเปิดกระเป๋า/กำลังลาก/เลือกของไว้ จะได้มีที่วาง)
		s.Button.Visible = t ~= nil or ui.Inv.Visible or drag ~= nil or picked ~= nil
	end
	local n = 0
	for _, s in pairs(ui.Slots) do
		if s.Button.Visible then
			n += 1
		end
	end
	if n ~= ui.Shown then
		ui.Shown = n
		if ui.Rescale then
			ui.Rescale()
		end
	end
	ui.Bar.Visible = shown and (#list > 0 or player:GetAttribute("InRun") == true)
	ui.TopGui.Enabled = ui.Bar.Visible
	if not ui.Bar.Visible then
		ui.Inv.Visible = false
	end
	if ui.Inv.Visible then
		Backpack.RefreshInventory(list)
	end
end

function Backpack.RefreshInventory(list)
	list = list or tools()
	for _, c in ipairs(ui.InvScroll:GetChildren()) do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	ui.InvTitle.Text = picked and ("เลือก " .. picked.Name .. " แล้ว — แตะช่องด้านล่างที่จะใส่") or "กระเป๋า  ·  ลากของไปวางที่ช่องด้านล่าง (สลับช่องได้)"
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	for k, t in ipairs(list) do
		local b = Instance.new("TextButton")
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundColor3 = BG
		b.BackgroundTransparency = slotOf(t) and 0.55 or 0.15
		b.LayoutOrder = k
		b.Parent = ui.InvScroll
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = b
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(120, 220, 255)
		st.Thickness = picked == t and 3 or 0
		st.Parent = b
		local h = Instance.new("Frame")
		h.BackgroundTransparency = 1
		h.Size = UDim2.new(1, -10, 1, -10)
		h.Position = UDim2.fromOffset(5, 5)
		h.Parent = b
		fillIcon(h, t)
		local cnt = Instance.new("TextLabel")
		cnt.BackgroundTransparency = 1
		cnt.Size = UDim2.new(1, -6, 0, 14)
		cnt.AnchorPoint = Vector2.new(0, 1)
		cnt.Position = UDim2.new(0, 3, 1, -1)
		cnt.Font = Enum.Font.BuilderSansBold
		cnt.TextSize = 12
		cnt.TextXAlignment = Enum.TextXAlignment.Right
		cnt.TextColor3 = Color3.new(1, 1, 1)
		cnt.TextStrokeTransparency = 0.4
		cnt.Text = countText(t)
		cnt.Parent = b
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				startPress(t, nil, input)
			end
		end)
	end
end

function Backpack.ToggleInventory(force)
	if not ui.Inv then
		return
	end
	if force == nil then
		force = not ui.Inv.Visible
	end
	ui.Inv.Visible = force and ui.Bar.Visible
	ui.Rescale() -- เปิดกระเป๋า = ใช้เต็มความกว้าง
	ui.BagIcon.Image = ui.Inv.Visible and "rbxasset://textures/ui/TopBar/inventoryOn@3x.png" or "rbxasset://textures/ui/TopBar/inventoryOff@3x.png"
	if not ui.Inv.Visible then
		picked = nil
	end
	Backpack.Refresh()
end

-- ซ่อนทั้งหมด (ตาย/ดูคนอื่น)
function Backpack.SetVisible(on)
	shown = on
	Backpack.Refresh()
end

return Backpack
