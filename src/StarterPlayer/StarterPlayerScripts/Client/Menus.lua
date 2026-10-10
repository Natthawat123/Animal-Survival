--[[
	Menus — เมนูคราฟต์ (C), โหมดสร้าง (B), กระเป๋า (Tab), เลือกคลาส
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
local Classes = require(Shared.Classes)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local StructureModels = require(Shared.StructureModels)
local Shop = require(Shared.Shop)
local UIKit = require(script.Parent.UIKit)
local ClassShop = require(script.Parent.ClassShop)
local LobbyUI = require(script.Parent.LobbyUI)
local StoreUI = require(script.Parent.StoreUI)

local Menus = {}
local player = Players.LocalPlayer
local C = UIKit.Colors
local inventory = {} -- กระสอบ + คลังแคมป์ (ใช้เช็กคราฟต์)
local sack = {} -- เฉพาะในกระสอบ
local campStock = {}
local sackUsed, sackCap = 0, 0
local profile = nil

local CATS = {
	{ Id = "Tool", Thai = "⚔ อาวุธ/เครื่องมือ" },
	{ Id = "Structure", Thai = "🏗 สิ่งก่อสร้าง" },
	{ Id = "Medical", Thai = "🩹 ยา" },
}

local function itemDesc(id)
	local t = Items.Tools[id]
	if t then
		local s = string.format("ดาเมจ %d · ระยะ %d", t.Damage, t.Range)
		if t.Chop and t.Chop > 0 then
			s ..= " · ตัดไม้ " .. t.Chop
		end
		if t.Mine and t.Mine > 0 then
			s ..= " · ขุด " .. t.Mine
		end
		if t.Element then
			s ..= " · ธาตุ" .. (UIKit.ElementThai[t.Element] or t.Element)
		end
		if t.Light then
			s ..= " · ส่องแสงไล่กวางกลวง"
		end
		return s
	end
	local st = Items.Structures[id]
	if st then
		local extra = {
			LogWall = "ขวางฝูงสัตว์", StoneWall = "กำแพงถึกมาก", SpikeTrap = "แทงสัตว์ที่เหยียบ", Lantern = "แสงไล่กวางกลวง",
			Ballista = "ยิงสัตว์อัตโนมัติ", Bed = "จุดเกิดใหม่", FarmPlot = "ปลูกเบอร์รี่", CookPot = "ทำสตูว์",
			TerraTotem = "ซ่อมกำแพงรอบๆ", TideTotem = "สัตว์ในรัศมีช้าลง", GaleTotem = "ผลักสัตว์กระเด็น", EmberTotem = "เผาสัตว์รอบๆ",
			SunBeacon = "แสงสว่างมหาศาล",
		}
		return string.format("HP %d · %s", st.Health, extra[id] or "")
	end
	local it = Items.Data[id]
	if it and it.Heal then
		return "ฟื้นเลือด " .. it.Heal .. (it.Revive and " · ใช้ช่วยเพื่อนที่ล้ม" or "")
	end
	return ""
end

---------------------------------------------------------------- เมนูคราฟต์
local craft = {}

function craft.Build(gui)
	local panel = UIKit.Frame(gui, { Size = UDim2.fromOffset(760, 520), Position = UDim2.new(0.5, -380, 0.5, -260), BackgroundTransparency = 0.08, Visible = false })
	UIKit.Corner(panel, 14)
	UIKit.Stroke(panel, C.Outline, 3, 0)
	UIKit.Gradient(panel, Color3.fromRGB(52, 58, 100), Color3.fromRGB(26, 28, 50), 90)
	craft.Title = UIKit.Text(panel, { Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 10), Font = UIKit.Fonts.Title, TextSize = 30, TextColor3 = C.Gold, Text = "โต๊ะคราฟต์" })
	UIKit.CloseButton(panel, function()
		Menus.CloseCraft()
	end)
	local tabs = UIKit.Frame(panel, { Size = UDim2.new(1, -40, 0, 34), Position = UDim2.fromOffset(20, 54), BackgroundTransparency = 1 })
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 8)
	tl.Parent = tabs
	craft.Tab = "Tool"
	craft.TabButtons = {}
	for _, cat in ipairs(CATS) do
		local b = UIKit.Button(tabs, { Size = UDim2.fromOffset(170, 32), Text = cat.Thai, TextSize = 14 }, function()
			craft.Tab = cat.Id
			craft.Refresh()
		end)
		craft.TabButtons[cat.Id] = b
	end
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -40, 1, -110)
	scroll.Position = UDim2.fromOffset(20, 96)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = C.GoldDim
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(350, 112)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	craft.Panel = panel
	craft.Scroll = scroll
end

function craft.Refresh()
	if not craft.Panel then
		return
	end
	local state = Menus.State
	local bench = state:GetAttribute("BenchLevel") or 1
	craft.Title.Text = string.format("🔨 โต๊ะคราฟต์ Lv.%d", bench)
	for id, b in pairs(craft.TabButtons) do
		b.BackgroundColor3 = (id == craft.Tab) and Color3.fromRGB(70, 56, 34) or C.Panel2
	end
	for _, c in ipairs(craft.Scroll:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	-- อัปเกรดกองไฟ / โต๊ะ (อยู่บนสุดทุกแท็บ แทนปุ่มกดที่กองไฟ)
	local fireLv = state:GetAttribute("CampLevel") or 1
	for i, up in ipairs({
		{ Id = "UpgradeFire", Title = "🔥 อัปเกรดกองไฟ", Lv = fireLv, Next = Recipes.Campfire[fireLv + 1], Desc = "ไฟใหญ่ขึ้น เขตปลอดภัยกว้างขึ้น หมอกจางลง" },
		{ Id = "UpgradeBench", Title = "🔨 อัปเกรดโต๊ะคราฟต์", Lv = bench, Next = Recipes.BenchUpgrade[bench + 1] and { Cost = Recipes.BenchUpgrade[bench + 1] }, Desc = "ปลดล็อกของที่คราฟต์ได้มากขึ้น" },
	}) do
		local card = UIKit.Frame(craft.Scroll, { BackgroundColor3 = Color3.fromRGB(92, 64, 160), BackgroundTransparency = 0.05, LayoutOrder = -10 + i })
		UIKit.Corner(card, 10)
		UIKit.Stroke(card, C.Gold, 1, 0.2)
		UIKit.Text(card, { Size = UDim2.new(1, -110, 0, 22), Position = UDim2.fromOffset(12, 8), Text = string.format("%s  Lv.%d → %s", up.Title, up.Lv, up.Next and tostring(up.Lv + 1) or "MAX"), TextSize = 16 })
		UIKit.Text(card, { Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 34), Text = up.Desc, TextSize = 12, TextColor3 = Color3.fromRGB(200, 190, 170), Font = UIKit.Fonts.Body })
		local can = up.Next ~= nil
		local parts = {}
		if up.Next then
			for id, n in pairs(up.Next.Cost) do
				local have = inventory[id] or 0
				can = can and have >= n
				table.insert(parts, string.format('<font color="#%s">%s %d/%d</font>', have >= n and "8CEB96" or "FF8070", Items.DisplayName(id), have, n))
			end
		end
		local costLabel = UIKit.Text(card, { Size = UDim2.new(1, -120, 0, 36), Position = UDim2.fromOffset(12, 58), RichText = true, TextWrapped = true, Text = table.concat(parts, "  "), TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top })
		costLabel.Font = UIKit.Fonts.Bold
		local btn = UIKit.Button(card, { Size = UDim2.fromOffset(96, 34), Position = UDim2.new(1, -106, 1, -44), Text = up.Next and "อัปเกรด" or "สูงสุด", TextSize = 14 }, function()
			if up.Next then
				Remotes.Get("Craft"):FireServer(up.Id)
			end
		end)
		btn.BackgroundColor3 = can and Color3.fromRGB(110, 70, 26) or Color3.fromRGB(50, 56, 94)
		btn.TextColor3 = can and C.Text or C.TextDim
	end
	for order, r in ipairs(Recipes.List) do
		local item = Items.Data[r.Id]
		if item.Category == craft.Tab then
			local card = UIKit.Frame(craft.Scroll, { BackgroundColor3 = Color3.fromRGB(50, 56, 94), BackgroundTransparency = 0.1, LayoutOrder = order })
			UIKit.Corner(card, 10)
			local locked = r.Bench > bench
			UIKit.Stroke(card, locked and Color3.fromRGB(80, 70, 70) or (item.Element and C.Element[item.Element] or C.GoldDim), 1, 0.3)
			UIKit.Text(card, { Size = UDim2.new(1, -110, 0, 22), Position = UDim2.fromOffset(12, 8), Text = item.Thai .. "  ", TextSize = 17, TextColor3 = locked and C.TextDim or C.Text })
			UIKit.Text(card, { Size = UDim2.new(1, -110, 0, 16), Position = UDim2.fromOffset(12, 30), Text = item.Name, TextSize = 12, TextColor3 = C.TextDim, Font = UIKit.Fonts.Body })
			UIKit.Text(card, { Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 48), Text = itemDesc(r.Id), TextSize = 12, TextColor3 = Color3.fromRGB(200, 190, 170), Font = UIKit.Fonts.Body, TextTruncate = Enum.TextTruncate.AtEnd })
			-- วัตถุดิบ
			local costs = {}
			local can = not locked
			for id, n in pairs(r.Cost) do
				table.insert(costs, { id, n })
			end
			table.sort(costs, function(a, b)
				return a[1] < b[1]
			end)
			local parts = {}
			for _, cn in ipairs(costs) do
				local have = inventory[cn[1]] or 0
				local ok = have >= cn[2]
				if not ok then
					can = false
				end
				table.insert(parts, string.format('<font color="#%s">%s %d/%d</font>', ok and "8CEB96" or "FF8070", Items.DisplayName(cn[1]), have, cn[2]))
			end
			local costLabel = UIKit.Text(card, { Size = UDim2.new(1, -120, 0, 36), Position = UDim2.fromOffset(12, 68), RichText = true, TextWrapped = true, Text = table.concat(parts, "  "), TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top })
			costLabel.Font = UIKit.Fonts.Bold
			local owned = item.Category == "Tool" and (inventory[r.Id] or 0) > 0
			local btnText = locked and ("ต้องโต๊ะ Lv." .. r.Bench) or (owned and "มีแล้ว" or "คราฟต์")
			local btn = UIKit.Button(card, { Size = UDim2.fromOffset(96, 34), Position = UDim2.new(1, -106, 1, -44), Text = btnText, TextSize = 14 }, function()
				if not locked and not owned then
					Remotes.Get("Craft"):FireServer(r.Id)
				end
			end)
			if not can or owned then
				btn.TextColor3 = C.TextDim
				btn.BackgroundColor3 = Color3.fromRGB(50, 56, 94)
			else
				btn.BackgroundColor3 = Color3.fromRGB(72, 190, 96)
			end
		end
	end
end

function Menus.OpenCraft()
	craft.Panel.Visible = true
	craft.Refresh()
end

function Menus.CloseCraft()
	craft.Panel.Visible = false
end

---------------------------------------------------------------- กระเป๋า
local bag = {}

function bag.Build(gui)
	local panel = UIKit.Frame(gui, { Size = UDim2.fromOffset(520, 440), Position = UDim2.new(0.5, -260, 0.5, -220), BackgroundTransparency = 0.08, Visible = false })
	UIKit.Corner(panel, 14)
	UIKit.Stroke(panel, C.Outline, 3, 0)
	UIKit.Gradient(panel, Color3.fromRGB(52, 58, 100), Color3.fromRGB(26, 28, 50), 90)
	UIKit.Text(panel, { Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 8), Font = UIKit.Fonts.Title, TextSize = 28, TextColor3 = C.Gold, Text = "🎒 กระสอบ" })
	bag.Title = panel:FindFirstChildWhichIsA("TextLabel")
	UIKit.CloseButton(panel, function()
		panel.Visible = false
	end)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -40, 1, -70)
	scroll.Position = UDim2.fromOffset(20, 56)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(150, 64)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	bag.Panel = panel
	bag.Scroll = scroll
end

local CAT_ORDER = { Food = 1, Medical = 2, Resource = 3, Essence = 4, Relic = 5, Structure = 6, Tool = 7 }
function bag.Refresh()
	if not (bag.Panel and bag.Panel.Visible) then
		return
	end
	for _, c in ipairs(bag.Scroll:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	if bag.Title then
		bag.Title.Text = string.format("🎒 กระสอบ  %d/%d", sackUsed, sackCap)
	end
	local ids = {}
	for id, n in pairs(sack) do
		if n > 0 and Items.Data[id] and Items.Data[id].Category ~= "Tool" then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local ca, cb = CAT_ORDER[Items.Data[a].Category] or 9, CAT_ORDER[Items.Data[b].Category] or 9
		if ca ~= cb then
			return ca < cb
		end
		return a < b
	end)
	for i, id in ipairs(ids) do
		local item = Items.Data[id]
		local card = UIKit.Frame(bag.Scroll, { BackgroundColor3 = Color3.fromRGB(50, 56, 94), BackgroundTransparency = 0.1, LayoutOrder = i })
		UIKit.Corner(card, 8)
		UIKit.Stroke(card, item.Color or C.GoldDim, 1, 0.5)
		UIKit.Text(card, { Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(8, 6), Text = item.Thai, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd })
		UIKit.Text(card, { Size = UDim2.new(0, 60, 0, 18), Position = UDim2.fromOffset(8, 36), Text = "x" .. sack[id], TextSize = 14, TextColor3 = C.Gold })
		if Items.Bulk(id) then
			UIKit.Button(card, { Size = UDim2.fromOffset(36, 22), Position = UDim2.new(1, -42, 0, 4), Text = "ทิ้ง", TextSize = 11 }, function()
				Remotes.Get("DropItem"):FireServer(id, 1)
			end)
		end
		if item.Category == "Food" or item.Category == "Medical" then
			UIKit.Button(card, { Size = UDim2.fromOffset(64, 26), Position = UDim2.new(1, -70, 1, -32), Text = item.Category == "Food" and "กิน" or "ใช้", TextSize = 13 }, function()
				Remotes.Get("UseItem"):FireServer(id)
			end)
		elseif item.Category == "Structure" then
			UIKit.Button(card, { Size = UDim2.fromOffset(64, 26), Position = UDim2.new(1, -70, 1, -32), Text = "วาง", TextSize = 13 }, function()
				bag.Panel.Visible = false
				Menus.StartBuild(id)
			end)
		end
	end

	-- คลังแคมป์ (ของที่เทไว้ ทุกคนใช้คราฟต์ร่วมกัน)
	local campIds = {}
	for id, n in pairs(campStock) do
		if n > 0 and Items.Data[id] then
			table.insert(campIds, id)
		end
	end
	table.sort(campIds)
	for i, id in ipairs(campIds) do
		local item = Items.Data[id]
		local card = UIKit.Frame(bag.Scroll, { BackgroundColor3 = Color3.fromRGB(36, 92, 76), BackgroundTransparency = 0.1, LayoutOrder = 1000 + i })
		UIKit.Corner(card, 8)
		UIKit.Stroke(card, Color3.fromRGB(120, 200, 140), 1, 0.6)
		UIKit.Text(card, { Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(8, 6), Text = "📦 " .. item.Thai, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd })
		UIKit.Text(card, { Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(8, 36), Text = "คลังแคมป์ x" .. campStock[id], TextSize = 13, TextColor3 = Color3.fromRGB(150, 230, 170) })
	end
end

function Menus.ToggleBag(force)
	if force == nil then
		bag.Panel.Visible = not bag.Panel.Visible
	else
		bag.Panel.Visible = force
	end
	bag.Refresh()
end

---------------------------------------------------------------- โหมดสร้าง
local build = { Active = false, Yaw = 0 }

function Menus.StartBuild(kind)
	Menus.StopBuild()
	if (inventory[kind] or 0) <= 0 then
		return
	end
	build.Kind = kind
	build.Active = true
	local ghost = StructureModels.Build(kind)
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.45)
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
		elseif d:IsA("Light") or d:IsA("Fire") then
			d:Destroy()
		end
	end
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.6
	hl.OutlineTransparency = 0.1
	hl.Parent = ghost
	ghost.Parent = Workspace.CurrentCamera
	build.Ghost = ghost
	build.Highlight = hl
	Menus.BuildHint.Text = string.format("🏗 วาง %s (เหลือ %d)  ·  คลิก = วาง  ·  R = หมุน  ·  B/Esc = ยกเลิก", Items.DisplayName(kind), inventory[kind] or 0)
	Menus.BuildHint.Visible = true
end

function Menus.StopBuild()
	build.Active = false
	if build.Ghost then
		build.Ghost:Destroy()
		build.Ghost = nil
	end
	if Menus.BuildHint then
		Menus.BuildHint.Visible = false
	end
end

local function buildTarget()
	local mouse = UserInputService:GetMouseLocation()
	local ray = Workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local res = Workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	return res
end

function Menus.ToggleBuildPicker()
	if build.Active then
		Menus.StopBuild()
		return
	end
	-- เลือกชุดสิ่งก่อสร้างที่มี
	for _, r in ipairs(Recipes.List) do
		if Items.Data[r.Id].Category == "Structure" and (inventory[r.Id] or 0) > 0 then
			Menus.StartBuild(r.Id)
			return
		end
	end
	if inventory.LogWall and inventory.LogWall > 0 then
		Menus.StartBuild("LogWall")
		return
	end
	Menus.Hud.Notify("ยังไม่มีสิ่งก่อสร้างในกระเป๋า — ไปคราฟต์ที่โต๊ะคราฟต์ก่อน", "Error")
end

-- เลื่อนชนิดถัดไป
function Menus.CycleBuild()
	local kinds = {}
	for _, r in ipairs(Recipes.List) do
		if Items.Data[r.Id].Category == "Structure" and (inventory[r.Id] or 0) > 0 then
			table.insert(kinds, r.Id)
		end
	end
	if #kinds == 0 then
		return
	end
	local idx = table.find(kinds, build.Kind) or 0
	Menus.StartBuild(kinds[idx % #kinds + 1])
end

---------------------------------------------------------------- ร้านค้า (ล็อบบี้)
-- ร้านคลาส = ClassShop · ร้านค้า (เติมเพชร/Game Pass/ชุดเริ่มต้น) = StoreUI
function Menus.OpenShop(tab)
	if tab == nil or tab == "Classes" then
		StoreUI.Close()
		ClassShop.Open()
		return
	end
	ClassShop.Close()
	StoreUI.Open(tab == "Shop" and "Diamonds" or tab)
end

function Menus.OpenClasses()
	Menus.OpenShop("Classes")
end

---------------------------------------------------------------- พ่อค้าเร่ (ในแมพ)
local trader = {}

function trader.Build(gui)
	local panel = UIKit.Frame(gui, { Size = UDim2.fromOffset(760, 520), Position = UDim2.new(0.5, -380, 0.5, -260), BackgroundTransparency = 0.05, Visible = false })
	UIKit.Corner(panel, 16)
	UIKit.Stroke(panel, C.Outline, 3, 0)
	UIKit.Gradient(panel, Color3.fromRGB(52, 58, 100), Color3.fromRGB(26, 28, 50), 90)
	UIKit.Text(panel, { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 10), Font = UIKit.Fonts.Title, TextSize = 34, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Center, Text = "🐾 พ่อค้าเร่" })
	UIKit.Text(panel, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 52), TextSize = 13, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Text = "\"หนังสัตว์ดีๆ แลกของจำเป็นได้นะสหาย... รีบหน่อย ข้าจะไปก่อนพระอาทิตย์ตก\"" })
	UIKit.CloseButton(panel, function()
		panel.Visible = false
	end)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -40, 1, -100)
	scroll.Position = UDim2.fromOffset(20, 84)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(350, 80)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.Parent = scroll
	trader.Panel = panel
	trader.Scroll = scroll
end

local function listText(t, have)
	local parts = {}
	for id, n in pairs(t) do
		if have then
			local ok = (inventory[id] or 0) >= n
			table.insert(parts, string.format('<font color="#%s">%s %d/%d</font>', ok and "8CEB96" or "FF8070", Items.DisplayName(id), inventory[id] or 0, n))
		else
			table.insert(parts, Items.DisplayName(id) .. " x" .. n)
		end
	end
	table.sort(parts)
	return table.concat(parts, "  ")
end

function trader.Refresh()
	if not (trader.Panel and trader.Panel.Visible) then
		return
	end
	for _, c in ipairs(trader.Scroll:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, o in ipairs(Shop.Trader) do
		local f = UIKit.Frame(trader.Scroll, { BackgroundColor3 = Color3.fromRGB(50, 56, 94), BackgroundTransparency = 0.05, LayoutOrder = i })
		UIKit.Corner(f, 10)
		UIKit.Stroke(f, C.GoldDim, 1, 0.3)
		UIKit.Text(f, { Size = UDim2.new(1, -120, 0, 24), Position = UDim2.fromOffset(12, 8), Text = "ได้: " .. listText(o.Give), TextSize = 15, TextColor3 = C.Gold, TextTruncate = Enum.TextTruncate.AtEnd })
		local cost = UIKit.Text(f, { Size = UDim2.new(1, -120, 0, 36), Position = UDim2.fromOffset(12, 34), RichText = true, TextWrapped = true, Text = "จ่าย: " .. listText(o.Cost, true), TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top })
		local _ = cost
		UIKit.Button(f, { Size = UDim2.fromOffset(96, 36), Position = UDim2.new(1, -106, 0.5, -18), Text = "แลก", TextSize = 15, BackgroundColor3 = Color3.fromRGB(72, 190, 96) }, function()
			Remotes.Get("Trade"):FireServer(o.Id)
		end)
	end
end

function Menus.OpenTrader()
	trader.Panel.Visible = true
	trader.Refresh()
end

---------------------------------------------------------------- Init
function Menus.SetInventory(inv, bagOnly, camp, used, cap)
	inventory = inv
	sack = bagOnly or inv
	campStock = camp or {}
	sackUsed, sackCap = used or 0, cap or 0
	if craft.Panel and craft.Panel.Visible then
		craft.Refresh()
	end
	bag.Refresh()
	trader.Refresh()
	if build.Active and (inventory[build.Kind] or 0) <= 0 then
		Menus.StopBuild()
	elseif build.Active then
		Menus.BuildHint.Text = string.format("🏗 วาง %s (เหลือ %d)  ·  คลิก = วาง  ·  R = หมุน  ·  Q = เปลี่ยนชนิด  ·  B = ยกเลิก", Items.DisplayName(build.Kind), inventory[build.Kind] or 0)
	end
end

function Menus.SetProfile(p)
	profile = p
	StoreUI.SetProfile(p)
	ClassShop.SetProfile(p)
	LobbyUI.SetProfile(p)
end

local function updateLobbyUI()
	LobbyUI.SetVisible(not player:GetAttribute("InRun") and not ClassShop.IsOpen())
end

function Menus.Init(state, hud)
	Menus.State = state
	Menus.Hud = hud
	local gui = UIKit.Screen("Menus", 20)
	craft.Build(gui)
	bag.Build(gui)
	trader.Build(gui)
	StoreUI.Init(UIKit.Screen("Store", 32))
	-- ร้านคลาส (เต็มจอ) + ปุ่มล็อบบี้ด้านซ้าย
	local shopGui = UIKit.Screen("ClassShop", 30)
	ClassShop.Init(shopGui)
	local lobbyGui = UIKit.Screen("LobbyUI", 15)
	LobbyUI.Init(lobbyGui, {
		Classes = function()
			Menus.OpenShop("Classes")
		end,
		Shop = function()
			Menus.OpenShop("Diamonds")
		end,
	})
	ClassShop.OnVisibility = function(open)
		if hud and hud.Gui then
			hud.Gui.Enabled = not open
		end
		updateLobbyUI()
	end
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		updateLobbyUI()
		if player:GetAttribute("InRun") then
			StoreUI.Close()
		end
	end)
	updateLobbyUI()
	Menus.BuildHint = UIKit.Text(gui, {
		Size = UDim2.new(0, 700, 0, 30), Position = UDim2.new(0.5, -350, 1, -150), TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 16, TextColor3 = C.Gold, Visible = false, BackgroundTransparency = 0.4, BackgroundColor3 = C.Panel,
	})
	UIKit.Corner(Menus.BuildHint, 8)
	state:GetAttributeChangedSignal("CampLevel"):Connect(function()
		if craft.Panel and craft.Panel.Visible then
			craft.Refresh()
		end
	end)
	state:GetAttributeChangedSignal("BenchLevel"):Connect(function()
		if craft.Panel.Visible then
			craft.Refresh()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.C then
			if craft.Panel.Visible then
				Menus.CloseCraft()
			else
				Menus.OpenCraft()
			end
		elseif false then
		elseif k == Enum.KeyCode.B then
			Menus.ToggleBuildPicker()
		elseif k == Enum.KeyCode.R and build.Active then
			build.Yaw += math.rad(45)
		elseif k == Enum.KeyCode.Q and build.Active then
			Menus.CycleBuild()
		elseif k == Enum.KeyCode.Escape then
			Menus.StopBuild()
			Menus.CloseCraft()
			bag.Panel.Visible = false
			ClassShop.Close()
			StoreUI.Close()
		elseif k == Enum.KeyCode.K then
			if not player:GetAttribute("InRun") then
				if ClassShop.IsOpen() then
					ClassShop.Close()
				else
					Menus.OpenShop("Classes")
				end
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and build.Active then
			local res = buildTarget()
			if res and build.Valid then
				Remotes.Get("PlaceStructure"):FireServer(build.Kind, CFrame.new(res.Position) * CFrame.Angles(0, build.Yaw, 0))
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not build.Active or not build.Ghost then
			return
		end
		local res = buildTarget()
		local char = player.Character
		if res and char then
			local d = (res.Position - char:GetPivot().Position).Magnitude
			local camp = state:GetAttribute("CampPos") or Vector3.zero
			local ok = d <= Config.BuildRange and res.Material ~= Enum.Material.Water and res.Material ~= Enum.Material.CrackedLava and (res.Position - camp).Magnitude > 9
			build.Valid = ok
			build.Ghost:PivotTo(CFrame.new(res.Position) * CFrame.Angles(0, build.Yaw, 0))
			build.Highlight.FillColor = ok and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(255, 70, 70)
			build.Highlight.OutlineColor = build.Highlight.FillColor
		end
	end)
end

return Menus
