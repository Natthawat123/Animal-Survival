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
local ItemTooltip = require(script.Parent.ItemTooltip)
local PinTracker = require(script.Parent.PinTracker)
local ClientSettings = require(script.Parent.ClientSettings)

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
			Ballista = "ยิงสัตว์อัตโนมัติ", Bed = "จุดเกิดของเพื่อนที่มาสมทบ", FarmPlot = "ปลูกเบอร์รี่", CookPot = "ทำสตูว์",
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

local CRAFT_CAP = 20 -- ต้องตรงกับ CampService.CraftCap (server จำกัดซ้ำอีกที)
local GOOD_C, BAD_C = Color3.fromRGB(140, 235, 150), Color3.fromRGB(255, 128, 112)

-- ของที่ใช้คราฟต์ได้ = กระสอบ + คลังแคมป์ (คราฟต์ได้เฉพาะในแคมป์ ซึ่งใช้ทั้งสองที่)
local function have(id)
	return inventory[id] or 0
end

-- ส่วนลดสิ่งก่อสร้างจากทักษะคลาส (server คิดแบบเดียวกัน)
local function craftMult(r)
	local item = Items.Data[r.Id]
	if item and item.Category == "Structure" then
		local perks = Classes.PerksFor(player:GetAttribute("Class") or "Survivor", player:GetAttribute("ClassLevel") or 1)
		return 1 - (perks.BuildDiscount or 0)
	end
	return 1
end

local function needOf(r, n)
	return math.max(1, math.ceil(n * craftMult(r)))
end

-- คราฟต์ได้สูงสุดกี่ชิ้นตอนนี้
local function maxCraft(r)
	local m = CRAFT_CAP
	for id, n in pairs(r.Cost) do
		m = math.min(m, math.floor(have(id) / needOf(r, n)))
	end
	local item = Items.Data[r.Id]
	if item and item.Category == "Tool" then
		m = math.min(m, (have(r.Id) > 0) and 0 or 1)
	elseif m > 1 and Items.Bulk(r.Id) then
		m = math.max(1, math.min(m, math.floor(math.max(sackCap - sackUsed, 0) / (r.Amount or 1))))
	end
	return math.max(0, m)
end
Menus.MaxCraft = maxCraft

local function inCampNow()
	local char = player.Character
	local state = Menus.State
	local camp = state and state:GetAttribute("CampPos")
	if not (char and camp) then
		return false
	end
	local radius = state:GetAttribute("CampRadius") or 60
	return ((char:GetPivot().Position - camp) * Vector3.new(1, 0, 1)).Magnitude <= radius
end

local function updatePin()
	PinTracker.Update(have, function(recipeId, n)
		local r = Recipes.ById[recipeId]
		return r and needOf(r, n) or n
	end)
end

local function matches(r, q)
	if q == "" then
		return true
	end
	local item = Items.Data[r.Id]
	local lq = string.lower(q)
	return string.find(item.Thai or "", q, 1, true) ~= nil
		or string.find(string.lower(item.Name or ""), lq, 1, true) ~= nil
		or string.find(string.lower(r.Id), lq, 1, true) ~= nil
end

function craft.Build(gui)
	local panel = UIKit.Frame(gui, { Size = UDim2.fromOffset(760, 540), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0.08, Visible = false })
	UIKit.AutoScale(panel)
	UIKit.Corner(panel, 14)
	UIKit.Stroke(panel, C.Outline, 3, 0)
	UIKit.Gradient(panel, Color3.fromRGB(52, 58, 100), Color3.fromRGB(26, 28, 50), 90)
	craft.Title = UIKit.Text(panel, { Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 10), Font = UIKit.Fonts.Title, TextSize = 30, TextColor3 = C.Gold, Text = "โต๊ะคราฟต์" })
	UIKit.CloseButton(panel, function()
		Menus.CloseCraft()
	end)
	local tabs = UIKit.Frame(panel, { Size = UDim2.new(0, 480, 0, 40), Position = UDim2.fromOffset(20, 54), BackgroundTransparency = 1 })
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 8)
	tl.Parent = tabs
	craft.Tab = "Tool"
	craft.TabButtons = {}
	for _, cat in ipairs(CATS) do
		local b = UIKit.Button(tabs, { Size = UDim2.fromOffset(150, 40), Text = cat.Thai, TextSize = 14 }, function()
			craft.Tab = cat.Id
			if craft.Search then
				craft.Search.Text = ""
			end
			craft.Refresh()
		end)
		craft.TabButtons[cat.Id] = b
	end
	-- ช่องค้นหา (ชื่อไทย/อังกฤษ) — พิมพ์แล้วค้นทุกหมวด
	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.Size = UDim2.fromOffset(230, 40)
	search.Position = UDim2.new(1, -250, 0, 54)
	search.BackgroundColor3 = Color3.fromRGB(20, 22, 40)
	search.BorderSizePixel = 0
	search.ClearTextOnFocus = false
	search.Text = ""
	search.PlaceholderText = "🔍 ค้นหา (ไทย/English)"
	search.PlaceholderColor3 = C.TextDim
	search.TextColor3 = C.Text
	search.Font = UIKit.Fonts.Bold
	search.TextSize = 15
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.Parent = panel
	UIKit.Corner(search, 8)
	UIKit.Stroke(search, C.GoldDim, 1, 0.3)
	local sp = Instance.new("UIPadding")
	sp.PaddingLeft, sp.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	sp.Parent = search
	search:GetPropertyChangedSignal("Text"):Connect(function()
		craft.Refresh()
	end)
	craft.Search = search
	craft.Status = UIKit.Text(panel, { Size = UDim2.new(1, -40, 0, 18), Position = UDim2.fromOffset(20, 98), Text = "", TextSize = 14, TextColor3 = C.TextDim })
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -40, 1, -134)
	scroll.Position = UDim2.fromOffset(20, 120)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = C.GoldDim
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(350, 150)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	craft.Panel = panel
	craft.Scroll = scroll
end

function craft.UpdateStatus()
	if not craft.Status then
		return
	end
	if inCampNow() then
		craft.Status.Text = "📦 อยู่ในแคมป์: ใช้ของในกระสอบก่อน แล้วค่อยหยิบจากคลังแคมป์"
		craft.Status.TextColor3 = GOOD_C
	else
		craft.Status.Text = "⚠ อยู่นอกแคมป์: กลับไปที่แคมป์ก่อนถึงจะคราฟต์ได้ (ตัวเลขนับรวมคลังแคมป์แล้ว)"
		craft.Status.TextColor3 = Color3.fromRGB(255, 196, 110)
	end
end

-- ป้ายวัตถุดิบทีละชิ้น (เขียว = พอ, แดง = ขาด · มี/ต้องใช้) ชี้/กดค้างดูรายละเอียดได้
local function costChips(parent, cost, r, pos)
	local holder = UIKit.Frame(parent, { Size = UDim2.new(1, -24, 0, 48), Position = pos, BackgroundTransparency = 1 })
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Wraps = true
	l.Padding = UDim.new(0, 4)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = holder
	local list = {}
	for id, n in pairs(cost) do
		table.insert(list, { id, r and needOf(r, n) or n })
	end
	table.sort(list, function(a, b)
		return a[1] < b[1]
	end)
	local all = true
	for i, cn in ipairs(list) do
		local h = have(cn[1])
		local ok = h >= cn[2]
		all = all and ok
		local chip = UIKit.Text(holder, {
			Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, TextSize = 13, Font = UIKit.Fonts.Bold,
			BackgroundTransparency = 0.35, BackgroundColor3 = ok and Color3.fromRGB(28, 70, 40) or Color3.fromRGB(80, 30, 30),
			TextColor3 = ok and GOOD_C or BAD_C, Text = string.format(" %s %d/%d ", Items.DisplayName(cn[1]), h, cn[2]),
		})
		UIKit.Corner(chip, 4)
		ItemTooltip.Attach(chip, cn[1])
	end
	return all
end

function craft.Refresh()
	if not craft.Panel then
		return
	end
	updatePin()
	if not craft.Panel.Visible then
		return
	end
	local state = Menus.State
	local bench = state:GetAttribute("BenchLevel") or 1
	craft.Title.Text = string.format("🔨 โต๊ะคราฟต์ Lv.%d", bench)
	craft.UpdateStatus()
	local query = craft.Search and craft.Search.Text or ""
	query = string.match(query, "^%s*(.-)%s*$") or ""
	local searching = query ~= ""
	for id, b in pairs(craft.TabButtons) do
		b.BackgroundColor3 = (id == craft.Tab and not searching) and Color3.fromRGB(70, 56, 34) or C.Panel2
	end
	for _, c in ipairs(craft.Scroll:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	-- อัปเกรดกองไฟ / โต๊ะ (อยู่บนสุดทุกแท็บ แทนปุ่มกดที่กองไฟ) — ซ่อนตอนค้นหา
	local fireLv = state:GetAttribute("CampLevel") or 1
	local upgrades = {}
	if not searching then
		upgrades = {
			{ Id = "UpgradeFire", Title = "🔥 อัปเกรดกองไฟ", Lv = fireLv, Next = Recipes.Campfire[fireLv + 1], Desc = "ไฟใหญ่ขึ้น เขตปลอดภัยกว้างขึ้น หมอกจางลง" },
			{ Id = "UpgradeBench", Title = "🔨 อัปเกรดโต๊ะคราฟต์", Lv = bench, Next = Recipes.BenchUpgrade[bench + 1] and { Cost = Recipes.BenchUpgrade[bench + 1] }, Desc = "ปลดล็อกของที่คราฟต์ได้มากขึ้น" },
		}
	end
	for i, up in ipairs(upgrades) do
		local card = UIKit.Frame(craft.Scroll, { BackgroundColor3 = Color3.fromRGB(92, 64, 160), BackgroundTransparency = 0.05, LayoutOrder = -10 + i })
		UIKit.Corner(card, 10)
		UIKit.Stroke(card, C.Gold, 1, 0.2)
		UIKit.Text(card, { Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 8), Text = string.format("%s  Lv.%d → %s", up.Title, up.Lv, up.Next and tostring(up.Lv + 1) or "MAX"), TextSize = 16 })
		UIKit.Text(card, { Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 34), Text = up.Desc, TextSize = 12, TextColor3 = Color3.fromRGB(200, 190, 170), Font = UIKit.Fonts.Body })
		local can = up.Next ~= nil
		if up.Next then
			can = costChips(card, up.Next.Cost, nil, UDim2.fromOffset(12, 54)) and can
		end
		local btn = UIKit.Button(card, { Size = UDim2.fromOffset(110, 40), Position = UDim2.new(1, -120, 1, -48), Text = up.Next and "อัปเกรด" or "สูงสุด", TextSize = 15 }, function()
			if up.Next then
				Remotes.Get("Craft"):FireServer(up.Id)
			end
		end)
		btn.BackgroundColor3 = can and Color3.fromRGB(72, 190, 96) or Color3.fromRGB(50, 56, 94)
		btn.TextColor3 = can and C.Text or C.TextDim
	end
	local pinned = PinTracker.Get()
	local shown = 0
	for order, r in ipairs(Recipes.List) do
		local item = Items.Data[r.Id]
		if item and ((searching and matches(r, query)) or (not searching and item.Category == craft.Tab)) then
			shown += 1
			local locked = r.Bench > bench
			local isTool = item.Category == "Tool"
			local owned = isTool and have(r.Id) > 0
			local maxN = locked and 0 or maxCraft(r)
			local can = not locked and not owned and maxN > 0
			local card = UIKit.Frame(craft.Scroll, {
				BackgroundColor3 = can and Color3.fromRGB(38, 84, 62) or Color3.fromRGB(50, 56, 94), BackgroundTransparency = 0.1,
				LayoutOrder = order + (can and 0 or 100),
			})
			UIKit.Corner(card, 10)
			UIKit.Stroke(card, can and GOOD_C or (locked and Color3.fromRGB(80, 70, 70) or (item.Element and C.Element[item.Element] or C.GoldDim)), can and 2 or 1, can and 0 or 0.3)
			ItemTooltip.Attach(card, r.Id)
			UIKit.Text(card, { Size = UDim2.new(1, -70, 0, 22), Position = UDim2.fromOffset(12, 8), Text = item.Thai .. (can and "  ✔" or ""), TextSize = 17, TextColor3 = locked and C.TextDim or (can and GOOD_C or C.Text) })
			UIKit.Text(card, { Size = UDim2.new(1, -70, 0, 16), Position = UDim2.fromOffset(12, 30), Text = item.Name, TextSize = 12, TextColor3 = C.TextDim, Font = UIKit.Fonts.Body })
			UIKit.Text(card, { Size = UDim2.new(1, -70, 0, 16), Position = UDim2.fromOffset(12, 46), Text = itemDesc(r.Id), TextSize = 12, TextColor3 = Color3.fromRGB(200, 190, 170), Font = UIKit.Fonts.Body, TextTruncate = Enum.TextTruncate.AtEnd })
			-- 📌 ปักหมุดสูตร (แถบติดตามบนจอ)
			local pin = UIKit.Button(card, { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -52, 0, 6), Text = "📌", TextSize = 20 }, function()
				PinTracker.Toggle(r.Id)
				craft.Refresh()
			end)
			pin.BackgroundColor3 = (pinned == r.Id) and C.Gold or Color3.fromRGB(58, 66, 104)
			-- วัตถุดิบ
			costChips(card, r.Cost, r, UDim2.fromOffset(12, 64))
			-- ปุ่มคราฟต์: x1 / x5 / สูงสุด
			local row = UIKit.Frame(card, { Size = UDim2.new(1, -20, 0, 44), Position = UDim2.new(0, 10, 1, -50), BackgroundTransparency = 1 })
			local rl = Instance.new("UIListLayout")
			rl.FillDirection = Enum.FillDirection.Horizontal
			rl.HorizontalAlignment = Enum.HorizontalAlignment.Right
			rl.Padding = UDim.new(0, 6)
			rl.SortOrder = Enum.SortOrder.LayoutOrder
			rl.Parent = row
			local function craftButton(i, text, width, enabled, count)
				local b = UIKit.Button(row, { Size = UDim2.fromOffset(width, 44), Text = text, TextSize = 14, LayoutOrder = i }, function()
					if enabled then
						Remotes.Get("Craft"):FireServer(r.Id, count)
					end
				end)
				b.BackgroundColor3 = enabled and Color3.fromRGB(72, 190, 96) or Color3.fromRGB(50, 56, 94)
				b.TextColor3 = enabled and C.Text or C.TextDim
				return b
			end
			if locked then
				craftButton(1, "ต้องโต๊ะ Lv." .. r.Bench, 130, false, 1)
			elseif isTool then
				craftButton(1, owned and "มีแล้ว" or "คราฟต์", 110, can, 1)
			else
				craftButton(1, "คราฟต์ x1", 100, can, 1)
				craftButton(2, "x5", 56, maxN >= 5, 5)
				craftButton(3, maxN > 1 and ("สูงสุด x" .. maxN) or "สูงสุด", 110, maxN > 1, CRAFT_CAP)
			end
		end
	end
	if searching and shown == 0 then
		local f = UIKit.Frame(craft.Scroll, { BackgroundTransparency = 1, LayoutOrder = 1 })
		UIKit.Text(f, { Size = UDim2.fromScale(1, 1), Text = "ไม่พบสูตรที่ค้นหา", TextSize = 16, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center })
	end
end

function Menus.OpenCraft()
	craft.Panel.Visible = true
	craft.Refresh()
end

function Menus.CloseCraft()
	craft.Panel.Visible = false
	if craft.Search then
		craft.Search:ReleaseFocus()
	end
	ItemTooltip.Hide()
end

---------------------------------------------------------------- กระเป๋า
local bag = {}

function bag.Build(gui)
	local panel = UIKit.Frame(gui, { Size = UDim2.fromOffset(520, 440), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0.08, Visible = false })
	UIKit.AutoScale(panel)
	UIKit.Corner(panel, 14)
	UIKit.Stroke(panel, C.Outline, 3, 0)
	UIKit.Gradient(panel, Color3.fromRGB(52, 58, 100), Color3.fromRGB(26, 28, 50), 90)
	UIKit.Text(panel, { Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 8), Font = UIKit.Fonts.Title, TextSize = 28, TextColor3 = C.Gold, Text = "🎒 กระสอบ" })
	bag.Title = panel:FindFirstChildWhichIsA("TextLabel")
	UIKit.CloseButton(panel, function()
		panel.Visible = false
		ItemTooltip.Hide()
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
		ItemTooltip.Attach(card, id)
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
		ItemTooltip.Attach(card, id)
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
	Menus.BuildHint.Text = Menus.TouchMode and string.format("🏗 วาง %s (เหลือ %d) — เล็งกลางจอแล้วกด ✔", Items.DisplayName(kind), inventory[kind] or 0)
		or string.format("🏗 วาง %s (เหลือ %d)  ·  คลิก = วาง  ·  R = หมุน  ·  B/Esc = ยกเลิก", Items.DisplayName(kind), inventory[kind] or 0)
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

-- มือถือ (Menus.TouchMode): เล็งด้วยกลางจอ (มีปุ่มวาง/หมุน/เปลี่ยน/ยกเลิก ใน MobileControls)
Menus.TouchMode = false
local function buildTarget()
	local cam = Workspace.CurrentCamera
	local mouse = Menus.TouchMode and (cam.ViewportSize / 2) or UserInputService:GetMouseLocation()
	local ray = cam:ViewportPointToRay(mouse.X, mouse.Y)
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

function Menus.IsBuilding()
	return build.Active
end

function Menus.RotateBuild()
	if build.Active then
		build.Yaw += math.rad(45)
	end
end

function Menus.PlaceBuild()
	if not build.Active then
		return
	end
	local res = buildTarget()
	if res and build.Valid then
		Remotes.Get("PlaceStructure"):FireServer(build.Kind, CFrame.new(res.Position) * CFrame.Angles(0, build.Yaw, 0))
	end
end

function Menus.ToggleCraft()
	if craft.Panel.Visible then
		Menus.CloseCraft()
	else
		Menus.OpenCraft()
	end
end

---------------------------------------------------------------- ร้านค้า (ล็อบบี้)
-- ร้านคลาส = ClassShop · ร้านค้า (เติม Ruby/Game Pass/ชุดเริ่มต้น) = StoreUI
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
	local panel = UIKit.Frame(gui, { Size = UDim2.fromOffset(760, 520), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0.05, Visible = false })
	UIKit.AutoScale(panel)
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
	-- craft.Refresh อัปเดตแถบติดตามสูตรที่ปักหมุดด้วย (แม้เมนูปิดอยู่)
	craft.Refresh()
	bag.Refresh()
	trader.Refresh()
	if build.Active and (inventory[build.Kind] or 0) <= 0 then
		Menus.StopBuild()
	elseif build.Active then
		Menus.BuildHint.Text = Menus.TouchMode and string.format("🏗 วาง %s (เหลือ %d) — เล็งกลางจอแล้วกด ✔", Items.DisplayName(build.Kind), inventory[build.Kind] or 0)
			or string.format("🏗 วาง %s (เหลือ %d)  ·  คลิก = วาง  ·  R = หมุน  ·  Q = เปลี่ยนชนิด  ·  B = ยกเลิก", Items.DisplayName(build.Kind), inventory[build.Kind] or 0)
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
		Settings = function()
			if Menus.OnSettings then
				Menus.OnSettings()
			end
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
		Size = UDim2.new(0, 700, 0, 30), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -120), TextXAlignment = Enum.TextXAlignment.Center,
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
	-- สถานะ "อยู่ในแคมป์ไหม" บนเมนูคราฟต์ + แถบปักหมุดตามคลาส (ส่วนลดสิ่งก่อสร้าง)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if craft.Panel.Visible then
				craft.UpdateStatus()
			end
		end
	end)
	player:GetAttributeChangedSignal("ClassLevel"):Connect(craft.Refresh)
	player:GetAttributeChangedSignal("Class"):Connect(craft.Refresh)
	ClientSettings.OnChanged(function(key)
		if key == "PinRecipe" and craft.Panel.Visible then
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
			ItemTooltip.Hide()
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
		elseif k == Enum.KeyCode.Tab and player:GetAttribute("InRun") then
			Menus.ToggleBag()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and build.Active and not Menus.TouchMode then
			Menus.PlaceBuild()
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
