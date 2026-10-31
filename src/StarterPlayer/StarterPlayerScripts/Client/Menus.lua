--[[
	Menus — เมนูคราฟต์ (C), โหมดสร้าง (B), กระเป๋า (Tab), เลือกคลาส
	โต๊ะคราฟต์ + พ่อค้าเร่ ใช้หน้าต่างธีมไม้ (WoodKit) แบบเดียวกับหน้าภารกิจ/ร้านค้า
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
local Limits = require(Shared.Limits)
local UIKit = require(script.Parent.UIKit)
local WoodKit = require(script.Parent.WoodKit)
local ClassShop = require(script.Parent.ClassShop)
local LobbyUI = require(script.Parent.LobbyUI)
local StoreUI = require(script.Parent.StoreUI)
local ItemTooltip = require(script.Parent.ItemTooltip)
local PinTracker = require(script.Parent.PinTracker)
local ItemIcon = require(script.Parent.ItemIcon)
local Backpack = require(script.Parent.Backpack)
local ClientSettings = require(script.Parent.ClientSettings)

local Menus = {}
local player = Players.LocalPlayer
local C = UIKit.Colors
local inventory = {} -- กระสอบ + คลังแคมป์ (ใช้เช็กคราฟต์)
local sack = {} -- เฉพาะในกระสอบ
local campStock = {}
local sackUsed, sackCap = 0, 0
local profile = nil

-- Art = ไอคอนภาพวาดบนแท็บ (Shared/PanelArt) · โหลดไม่ได้ใช้อีโมจิใน Thai แทน
local CATS = {
	{ Id = "Tool", Thai = "⚔ อาวุธ/เครื่องมือ", Label = "อาวุธ/เครื่องมือ", Art = "TabTool" },
	{ Id = "Structure", Thai = "🏗 สิ่งก่อสร้าง", Label = "สิ่งก่อสร้าง", Art = "TabStructure" },
	{ Id = "Medical", Thai = "🩹 ยา", Label = "ยา", Art = "TabMedical" },
	{ Id = "Armor", Thai = "🛡 เกราะ", Label = "เกราะ" },
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
			Ballista = "ยิงสัตว์อัตโนมัติ", Bed = "วางแล้วข้ามไป 1 วัน (+1 วัน)", FarmPlot = "ปลูกเบอร์รี่", CookPot = "ทำสตูว์",
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
	local group = Items.AnyGroups[id]
	if group then
		local n = 0
		for _, g in ipairs(group) do
			n += inventory[g] or 0
		end
		return n
	end
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
	-- หน้าต่างธีมไม้ (WoodKit): ป้ายชื่อ + หมาป่า/อินทรี + ธง + โคม
	local win = WoodKit.Window(gui, { Name = "CraftWindow", Size = Vector2.new(1000, 640), Title = "🔨 โต๊ะคราฟต์ Lv.1", TitleWidth = 380, OnClose = function()
		Menus.CloseCraft()
	end })
	local panel = win.Frame
	panel.Position = UDim2.fromScale(0.5, 0.52)
	UIKit.AutoScale(panel)
	local body = win.Body
	craft.Title = win.Title
	local tabs = UIKit.Frame(body, { Size = UDim2.new(0, 640, 0, 46), Position = UDim2.fromOffset(32, 42), BackgroundTransparency = 1 })
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 10)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = tabs
	craft.Tab = "Tool"
	craft.TabButtons = {}
	for i, cat in ipairs(CATS) do
		local b = WoodKit.Tab(tabs, cat.Thai, i, 146, function()
			craft.Tab = cat.Id
			if craft.Search then
				craft.Search.Text = ""
			end
			craft.Refresh()
		end)
		-- ไอคอนภาพวาด (ดาบไขว้ / ป้ายสิ่งก่อสร้าง / ขวดยา) ชิดซ้าย + ชื่อเว้นที่ให้ไอคอน
		local icon = WoodKit.Art(b, cat.Art, 34, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 2 })
		if icon then
			icon.Size = UDim2.fromOffset(36, 36)
			icon.ScaleType = Enum.ScaleType.Fit
			-- ชื่อแท็บเป็นป้ายแยกในกรอบหลังไอคอน (ข้อความบนปุ่ม + UIPadding ยังวางภาษาไทยเหลื่อมไปทับไอคอน)
			b.Text = ""
			local pad = b:FindFirstChildOfClass("UIPadding")
			if pad then
				pad:Destroy()
			end
			local label = UIKit.Text(b, { Name = "Label", Size = UDim2.new(1, -56, 1, 0), Position = UDim2.fromOffset(50, 0), Text = cat.Label,
				TextSize = 18, Font = b.Font, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = b.TextColor3, ZIndex = 2 })
			label.TextScaled = true
			local fit = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
			fit.MaxTextSize, fit.MinTextSize = 18, 10
			fit.Parent = label
			b:GetPropertyChangedSignal("TextColor3"):Connect(function()
				label.TextColor3 = b.TextColor3
			end)
		end
		craft.TabButtons[cat.Id] = b
	end
	-- ช่องค้นหา (ชื่อไทย/อังกฤษ) — พิมพ์แล้วค้นทุกหมวด
	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.Size = UDim2.fromOffset(290, 44)
	search.Position = UDim2.new(1, -322, 0, 43)
	search.BackgroundColor3 = Color3.fromRGB(32, 22, 16)
	search.BorderSizePixel = 0
	search.ClearTextOnFocus = false
	search.Text = ""
	search.PlaceholderText = "🔍 ค้นหา (ไทย/English)"
	search.PlaceholderColor3 = Color3.fromRGB(170, 150, 126)
	search.TextColor3 = Color3.fromRGB(255, 244, 224)
	search.Font = UIKit.Fonts.Bold
	search.TextSize = 18
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.Parent = body
	WoodKit.Corner(search, 8)
	WoodKit.Stroke(search, WoodKit.Colors.GoldDark, 2.5, 0)
	local sp = Instance.new("UIPadding")
	sp.PaddingLeft, sp.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	sp.Parent = search
	search:GetPropertyChangedSignal("Text"):Connect(function()
		craft.Refresh()
	end)
	craft.Search = search
	craft.Status = UIKit.Text(body, { Size = UDim2.new(1, -64, 0, 24), Position = UDim2.fromOffset(32, 96), Text = "", TextSize = 16, Font = UIKit.Fonts.Bold })
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -56, 1, -150)
	scroll.Position = UDim2.fromOffset(28, 128)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = WoodKit.Colors.Gold
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = body
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingLeft, pad.PaddingRight, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 14), UDim.new(0, 8)
	pad.Parent = scroll
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -8, 0, 172)
	grid.CellPadding = UDim2.fromOffset(14, 14)
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

-- ป้ายวัตถุดิบทีละชิ้น (ป้ายไม้เข้ม · เขียว = พอ, แดง = ขาด · มี/ต้องใช้) ชี้/กดค้างดูรายละเอียดได้
local function costChips(parent, cost, r, pos, size)
	local holder = UIKit.Frame(parent, { Size = size or UDim2.new(1, -24, 0, 64), Position = pos, BackgroundTransparency = 1 })
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Wraps = true
	l.Padding = UDim.new(0, 6)
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
		-- ป้าย = รูปวัตถุดิบ + ชื่อ มี/ต้องใช้
		local chip = WoodKit.Frame(holder, {
			Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i,
			BackgroundColor3 = ok and Color3.fromRGB(46, 62, 34) or Color3.fromRGB(78, 36, 28),
		})
		WoodKit.Corner(chip, 6)
		WoodKit.Stroke(chip, ok and Color3.fromRGB(110, 150, 70) or Color3.fromRGB(150, 70, 50), 1.5, 0.2)
		local cp = Instance.new("UIPadding")
		cp.PaddingLeft, cp.PaddingRight = UDim.new(0, 4), UDim.new(0, 6)
		cp.Parent = chip
		local cl = Instance.new("UIListLayout")
		cl.FillDirection = Enum.FillDirection.Horizontal
		cl.VerticalAlignment = Enum.VerticalAlignment.Center
		cl.SortOrder = Enum.SortOrder.LayoutOrder
		cl.Padding = UDim.new(0, 3)
		cl.Parent = chip
		ItemIcon.Make(chip, cn[1], { Size = UDim2.fromOffset(26, 26), LayoutOrder = 1 })
		UIKit.Text(chip, {
			Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, TextSize = 15, Font = UIKit.Fonts.Bold,
			BackgroundTransparency = 1, TextColor3 = ok and GOOD_C or BAD_C, Text = string.format("%s %d/%d", Items.DisplayName(cn[1]), h, cn[2]),
		})
		ItemTooltip.Attach(chip, cn[1])
	end
	return all
end

-- กรอบรูปเข้ม (รูปของจริงจาก ItemIcon หรืออีโมจิ)
local function picBox(parent, id, glyph, size, pos)
	local pic = WoodKit.Board(parent, { Size = UDim2.fromOffset(size, size), Position = pos, ZIndex = 2 }, Color3.fromRGB(34, 24, 18), WoodKit.Colors.GoldDark)
	if id then
		ItemIcon.Make(pic, id, { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), ZIndex = 3 })
	else
		UIKit.Text(pic, { Size = UDim2.fromScale(1, 1), Text = glyph or "", TextSize = math.floor(size * 0.55), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	end
	return pic
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
		WoodKit.SetTab(b, id == craft.Tab and not searching)
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
			{ Id = "UpgradeFire", Glyph = "🔥", Art = "Campfire", Title = "🔥 อัปเกรดกองไฟ", Lv = fireLv, Next = Recipes.Campfire[fireLv + 1], Desc = "ไฟใหญ่ขึ้น เขตปลอดภัยกว้างขึ้น หมอกถอยออกไป สำรวจได้ไกลขึ้น" },
			{ Id = "UpgradeBench", Glyph = "🔨", Art = "Bench", Title = "⚒ อัปเกรดโต๊ะคราฟต์", Lv = bench, Next = Recipes.BenchUpgrade[bench + 1] and { Cost = Recipes.BenchUpgrade[bench + 1] }, Desc = "ปลดล็อกของที่คราฟต์ได้มากขึ้น" },
		}
	end
	for i, up in ipairs(upgrades) do
		-- การ์ดม่วงเข้มขอบทอง (แบบป้ายอัปเกรดในภาพอ้างอิง)
		local card = WoodKit.Board(craft.Scroll, { LayoutOrder = -10 + i }, Color3.fromRGB(64, 46, 92), WoodKit.Colors.Gold)
		-- ภาพวาดกองไฟ/โต๊ะคราฟต์วางบนการ์ดตรงๆ (แบบภาพอ้างอิง) · โหลดภาพไม่ได้ = กรอบอีโมจิ
		local art = WoodKit.Art(card, up.Art, 104, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(62, 86), ZIndex = 3 })
		if art then
			art.Size = UDim2.fromOffset(112, 140)
			art.ScaleType = Enum.ScaleType.Fit
		else
			picBox(card, nil, up.Glyph, 100, UDim2.fromOffset(12, 14))
		end
		UIKit.Text(card, { Size = UDim2.new(1, -132, 0, 28), Position = UDim2.fromOffset(122, 10), Text = string.format("%s  Lv.%d → %s", up.Title, up.Lv, up.Next and tostring(up.Lv + 1) or "MAX"), TextSize = 20, Font = UIKit.Fonts.Title })
		UIKit.Text(card, { Size = UDim2.new(1, -132, 0, 18), Position = UDim2.fromOffset(122, 40), Text = up.Desc, TextSize = 13, TextColor3 = Color3.fromRGB(226, 214, 236), Font = UIKit.Fonts.Body })
		local can = up.Next ~= nil
		if up.Next then
			can = costChips(card, up.Next.Cost, nil, UDim2.fromOffset(122, 66), UDim2.new(1, -134, 0, 66)) and can
		end
		WoodKit.Button(card, can and "Night" or "Off", { Size = UDim2.fromOffset(150, 44), Position = UDim2.new(1, -162, 1, -54), Text = up.Next and "⚒ อัปเกรด" or "สูงสุด", TextSize = 18, ZIndex = 4 }, function()
			if up.Next then
				Remotes.Get("Craft"):FireServer(up.Id)
			end
		end)
	end
	local pinned = PinTracker.Get()
	local shown = 0
	for order, r in ipairs(Recipes.List) do
		local item = Items.Data[r.Id]
		if item and ((searching and matches(r, query)) or (not searching and item.Category == craft.Tab)) then
			shown += 1
			local locked = r.Bench > bench
			local isTool = item.Category == "Tool" or item.Category == "Armor"
			local worn = Items.Data[player:GetAttribute("Armor") or ""]
			local owned = (item.Category == "Tool" and have(r.Id) > 0) or (item.Category == "Armor" and worn ~= nil and (worn.Tier or 0) >= (item.Tier or 0))
			local maxN = locked and 0 or maxCraft(r)
			-- จำนวนสูงสุด (Limits): ถือ + วางอยู่ / สูงสุด
			local lim = Limits.Structures[r.Id]
			local limN = lim and (player:GetAttribute(Limits.AttrName(r.Id)) or 0) or 0
			local full = lim ~= nil and limN >= lim.Max
			if lim then
				maxN = math.min(maxN, math.floor(math.max(0, lim.Max - limN) / (r.Amount or 1)))
			end
			local can = not locked and not owned and maxN > 0
			-- การ์ดกระดาษ: คราฟต์ได้ = กระดาษทองสว่าง · ล็อก = กระดาษหม่น
			local tint = can and Color3.fromRGB(255, 232, 160) or (locked and Color3.fromRGB(200, 186, 160) or nil)
			local card = WoodKit.Parchment(craft.Scroll, { LayoutOrder = order + (can and 0 or 100) }, tint)
			ItemTooltip.Attach(card, r.Id)
			-- รูปของที่จะคราฟต์ (โมเดลจริง)
			picBox(card, r.Id, nil, 100, UDim2.fromOffset(12, 14))
			WoodKit.Ink(card, { Size = UDim2.new(1, -192, 0, 26), Position = UDim2.fromOffset(122, 10), Text = item.Thai .. (lim and string.format("  (%d/%d%s)", limN, lim.Max, lim.Scope == "Server" and " ทั้งเซิร์ฟ" or "") or "") .. (can and "  ✔" or ""), TextSize = 21, TextColor3 = locked and WoodKit.Colors.InkDim or (can and WoodKit.Colors.Good or WoodKit.Colors.Ink) })
			WoodKit.Ink(card, { Size = UDim2.new(1, -192, 0, 18), Position = UDim2.fromOffset(122, 36), Text = item.Name, TextSize = 14, Font = UIKit.Fonts.Bold, TextColor3 = WoodKit.Colors.InkDim })
			WoodKit.Ink(card, { Size = UDim2.new(1, -134, 0, 18), Position = UDim2.fromOffset(122, 56), Text = itemDesc(r.Id), TextSize = 14, Font = UIKit.Fonts.Bold, TextColor3 = Color3.fromRGB(96, 66, 40), TextTruncate = Enum.TextTruncate.AtEnd })
			-- 📌 ปักหมุดสูตร (แถบติดตามบนจอ)
			WoodKit.Button(card, pinned == r.Id and "Red" or "Parch", { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, -58, 0, 10), Text = "📌", TextSize = 22, ZIndex = 4 }, function()
				PinTracker.Toggle(r.Id)
				craft.Refresh()
			end)
			-- วัตถุดิบ
			costChips(card, r.Cost, r, UDim2.fromOffset(122, 80), UDim2.new(1, -134, 0, 36))
			-- ปุ่มคราฟต์: x1 / x5 / สูงสุด
			local row = UIKit.Frame(card, { Size = UDim2.new(1, -134, 0, 44), Position = UDim2.new(0, 122, 1, -54), BackgroundTransparency = 1 })
			local rl = Instance.new("UIListLayout")
			rl.FillDirection = Enum.FillDirection.Horizontal
			rl.HorizontalAlignment = Enum.HorizontalAlignment.Right
			rl.Padding = UDim.new(0, 6)
			rl.SortOrder = Enum.SortOrder.LayoutOrder
			rl.Parent = row
			local function craftButton(i, text, width, enabled, count)
				return WoodKit.Button(row, enabled and "Green" or "Off", { Size = UDim2.fromOffset(width, 44), Text = text, TextSize = 17, LayoutOrder = i, ZIndex = 4 }, function()
					if enabled then
						Remotes.Get("Craft"):FireServer(r.Id, count)
					end
				end)
			end
			if locked then
				craftButton(1, "🔒 ต้องโต๊ะ Lv." .. r.Bench, 160, false, 1)
			elseif isTool then
				local done = item.Category == "Armor" and (player:GetAttribute("Armor") == r.Id and "🛡 สวมอยู่" or "✔ มีที่ดีกว่า") or "✔ มีแล้ว"
				craftButton(1, owned and done or (item.Category == "Armor" and "🛡 คราฟต์+สวม" or "⚒ คราฟต์"), 150, can, 1)
			elseif full then
				craftButton(1, string.format("✔ ครบ %d/%d", limN, lim.Max), 160, false, 1)
			else
				craftButton(1, "⚒ คราฟต์ x1", 120, can, 1)
				craftButton(2, "x5", 56, maxN >= 5, 5)
				craftButton(3, maxN > 1 and ("สูงสุด x" .. maxN) or "สูงสุด", 110, maxN > 1, CRAFT_CAP)
			end
		end
	end
	if searching and shown == 0 then
		local f = UIKit.Frame(craft.Scroll, { BackgroundTransparency = 1, LayoutOrder = 1 })
		UIKit.Text(f, { Size = UDim2.fromScale(1, 1), Text = "ไม่พบสูตรที่ค้นหา", TextSize = 18, TextColor3 = Color3.fromRGB(226, 206, 176), TextXAlignment = Enum.TextXAlignment.Center })
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
		-- ยาอยู่ช่องแยกในแถบเครื่องมือ ไม่โชว์ในกระสอบ
		if n > 0 and Items.Data[id] and Items.Data[id].Category ~= "Tool" and Items.Data[id].Category ~= "Medical" then
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

local OK_COLOR = Color3.fromRGB(90, 255, 120)
local BAD_COLOR = Color3.fromRGB(255, 70, 70)
local NO_BUILD_R = 9 -- ห้ามวางใกล้กองไฟ (ตรงกับ BuildingService)

local function previewPart(parent, size, color, transparency)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Size = size
	p.Parent = parent
	return p
end

-- เส้นวงกลมแนบพื้น (ต่อจากท่อนสั้นๆ) — ขอบเขตแคมป์สีเขียว / เขตห้ามวางรอบกองไฟสีแดง
local function groundRing(parent, center, radius, color, segments)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local len = 2 * math.pi * radius / segments * 1.08
	for i = 1, segments do
		local a = (i - 0.5) / segments * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local hit = Workspace:Raycast(p + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), params)
		p = (hit and hit.Position or p) + Vector3.new(0, 0.35, 0)
		local seg = previewPart(parent, Vector3.new(0.6, 0.35, len), color, 0.25)
		seg.CFrame = CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a)))
	end
end

-- ทำให้ทั้งอันเป็นสีเดียว (เขียว = วางได้ / แดง = วางไม่ได้)
local function tintGhost(color)
	if build.Tint == color then
		return
	end
	build.Tint = color
	for _, d in ipairs(build.GhostParts) do
		d.Color = color
	end
	for _, d in ipairs(build.Footprint:GetChildren()) do
		d.Color = color
	end
	build.Highlight.FillColor = color
	build.Highlight.OutlineColor = color
end

function Menus.StartBuild(kind)
	Menus.StopBuild()
	if (inventory[kind] or 0) <= 0 then
		return
	end
	build.Kind = kind
	build.Active = true
	build.Tint = nil
	local parts = {}
	local ghost = StructureModels.Build(kind)
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = d.Transparency >= 0.95 and 1 or 0.45
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
			d.Material = Enum.Material.SmoothPlastic
			if d:IsA("MeshPart") then
				d.TextureID = ""
			elseif d:IsA("UnionOperation") then
				d.UsePartColor = true -- ไม่งั้นยูเนียนจากโมเดล Store ไม่เปลี่ยนสีตาม
			end
			table.insert(parts, d)
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		elseif d:IsA("Light") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")
			or d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("LayerCollector") or d:IsA("Sound") or d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	build.GhostParts = parts
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.6
	hl.OutlineTransparency = 0.1
	hl.Parent = ghost
	ghost.Parent = Workspace.CurrentCamera
	build.Ghost = ghost
	build.Highlight = hl
	-- แผ่นรองพื้นตามขนาดจริงของสิ่งก่อสร้าง (พื้นจาง + ขอบเข้ม)
	local spec = Items.Structures[kind]
	local sz = spec and spec.Size or ghost:GetExtentsSize()
	local fx, fz = sz.X + 1, sz.Z + 1
	local fp = Instance.new("Model")
	fp.Name = "BuildFootprint"
	previewPart(fp, Vector3.new(fx, 0.12, fz), OK_COLOR, 0.6)
	for _, e in ipairs({ { 0, fz / 2, fx, 0.4 }, { 0, -fz / 2, fx, 0.4 }, { fx / 2, 0, 0.4, fz }, { -fx / 2, 0, 0.4, fz } }) do
		local bar = previewPart(fp, Vector3.new(e[3], 0.25, e[4]), OK_COLOR, 0.1)
		bar:SetAttribute("Offset", Vector3.new(e[1], 0.08, e[2]))
	end
	fp.Parent = Workspace.CurrentCamera
	build.Footprint = fp
	Menus.BuildHint.Text = Menus.TouchMode and string.format("🏗 วาง %s (เหลือ %d) — เล็งกลางจอแล้วกด ✔", Items.DisplayName(kind), inventory[kind] or 0)
		or string.format("🏗 วาง %s (เหลือ %d)  ·  คลิก = วาง  ·  R = หมุน  ·  B/Esc = ยกเลิก", Items.DisplayName(kind), inventory[kind] or 0)
	Menus.BuildHint.Visible = true
end

function Menus.StopBuild()
	build.Active = false
	for _, k in ipairs({ "Ghost", "Footprint", "Zone" }) do
		if build[k] then
			build[k]:Destroy()
			build[k] = nil
		end
	end
	build.ZoneKey = nil
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

function Menus.BuildKind()
	return build.Active and build.Kind or nil
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
-- ร้านคลาส = ClassShop · ร้านค้า (เติม Ruby) = StoreUI
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
	-- หน้าต่างธีมไม้เดียวกับโต๊ะคราฟต์
	local panel
	local win = WoodKit.Window(gui, { Name = "TraderWindow", Size = Vector2.new(960, 600), Title = "🐾 พ่อค้าเร่", TitleWidth = 320, OnClose = function()
		panel.Visible = false
	end })
	panel = win.Frame
	panel.Position = UDim2.fromScale(0.5, 0.52)
	UIKit.AutoScale(panel)
	local quote = WoodKit.Parchment(win.Body, { Size = UDim2.new(1, -64, 0, 44), Position = UDim2.fromOffset(32, 44) })
	WoodKit.Ink(quote, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), TextSize = 17, Font = UIKit.Fonts.Bold, TextColor3 = WoodKit.Colors.InkDim, TextXAlignment = Enum.TextXAlignment.Center, Text = "\"หนังสัตว์ดีๆ แลกของจำเป็นได้นะสหาย... รีบหน่อย ข้าจะไปก่อนพระอาทิตย์ตก\"" })
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -56, 1, -128)
	scroll.Position = UDim2.fromOffset(28, 104)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = WoodKit.Colors.Gold
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = win.Body
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingLeft, pad.PaddingRight, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 14), UDim.new(0, 8)
	pad.Parent = scroll
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -8, 0, 132)
	grid.CellPadding = UDim2.fromOffset(14, 14)
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
		local okAll = true
		for id, n in pairs(o.Cost) do
			okAll = okAll and (inventory[id] or 0) >= n
		end
		local left = Limits.TradesPerVisit - (player:GetAttribute("Trade_" .. o.Id) or 0)
		okAll = okAll and left > 0
		-- การ์ดกระดาษ (แลกได้ = กระดาษทองสว่าง)
		local f = WoodKit.Parchment(trader.Scroll, { LayoutOrder = i }, okAll and Color3.fromRGB(255, 232, 160) or nil)
		-- รูปของที่ได้ (ชิ้นแรก) + ชื่อ
		local giveId = next(o.Give)
		picBox(f, giveId, "🎁", 100, UDim2.fromOffset(12, 16))
		WoodKit.Ink(f, { Size = UDim2.new(1, -134, 0, 26), Position = UDim2.fromOffset(122, 12), Text = "ได้: " .. listText(o.Give), TextSize = 19, TextTruncate = Enum.TextTruncate.AtEnd })
		WoodKit.Ink(f, { Size = UDim2.new(1, -134, 0, 16), Position = UDim2.fromOffset(122, 40), Text = "จ่าย:", TextSize = 14, Font = UIKit.Fonts.Bold, TextColor3 = WoodKit.Colors.InkDim })
		-- ป้ายของที่ต้องจ่าย (รูป + มี/ต้องใช้ จากกระสอบ)
		costChips(f, o.Cost, nil, UDim2.fromOffset(122, 58), UDim2.new(1, -262, 0, 66))
		WoodKit.Ink(f, { Size = UDim2.fromOffset(116, 18), Position = UDim2.new(1, -128, 1, -82), Text = left > 0 and string.format("แลกได้อีก %d/%d", left, Limits.TradesPerVisit) or "ครบแล้ว", TextSize = 14, Font = UIKit.Fonts.Bold, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = left > 0 and WoodKit.Colors.InkDim or Color3.fromRGB(170, 50, 40) })
		WoodKit.Button(f, okAll and "Red" or "Off", { Size = UDim2.fromOffset(116, 48), Position = UDim2.new(1, -128, 1, -60), Text = "🤝 แลก", TextSize = 20, ZIndex = 4 }, function()
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
	task.spawn(Backpack.Build) -- แถบเครื่องมือ + กระเป๋า (แบบ Roblox ปุ่มกระเป๋าโชว์ตลอด จัดลำดับได้)
	craft.Build(gui)
	player:GetAttributeChangedSignal("Armor"):Connect(craft.Refresh) -- สวมเกราะแล้ว ปุ่มเปลี่ยนเป็น "สวมอยู่"
	bag.Build(gui)
	trader.Build(gui)
	-- Esc = ปิด (หน้าต่างระหว่างเล่น: ไม่ใส่พื้นหลังรับแตะ เพื่อให้ยังเดิน/โจมตี/ใช้จอยมือถือได้ตอนเปิดอยู่)
	UIKit.RegisterWindow(craft.Panel, Menus.CloseCraft, { Backdrop = false })
	UIKit.RegisterWindow(bag.Panel, function()
		Menus.ToggleBag(false)
	end, { Backdrop = false })
	UIKit.RegisterWindow(trader.Panel, nil, { Backdrop = false })
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
	LobbyUI.Closers.Classes = ClassShop.Close
	LobbyUI.Closers.Shop = StoreUI.Close
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
	-- ปุ่มหมุนสิ่งก่อสร้าง (คอม: นอกจากปุ่ม R) — มือถือมีปุ่มหมุนในแถบโหมดสร้างอยู่แล้ว
	local rot = UIKit.Button(Menus.BuildHint, { Size = UDim2.fromOffset(120, 36), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6), Text = "⟳ หมุน (R)", TextSize = 16, BackgroundColor3 = Color3.fromRGB(72, 120, 200) }, function()
		Menus.RotateBuild()
	end)
	rot.Visible = not UIKit.IsTouch
	UIKit.AutoScale(Menus.BuildHint, { maxW = 0.8 })
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

	-- Tool สิ่งก่อสร้างในแถบเครื่องมือ Roblox: ถือ = เข้าโหมดวาง, คลิก/แตะ = วาง, เก็บ = ออก
	local function hookChar(char)
		char.ChildAdded:Connect(function(t)
			local kind = t:IsA("Tool") and t:GetAttribute("StructureKind")
			if kind then
				Menus.StartBuild(kind)
				if not t:GetAttribute("BuildHooked") then
					t:SetAttribute("BuildHooked", true)
					t.Activated:Connect(function()
						Menus.PlaceBuild()
					end)
				end
			end
		end)
		char.ChildRemoved:Connect(function(t)
			local kind = t:IsA("Tool") and t:GetAttribute("StructureKind")
			if kind and build.Active and build.Kind == kind then
				-- เปลี่ยนชื่อ (จำนวนลด) ไม่นับ: ยังถืออยู่ = ยังไม่ออก
				task.defer(function()
					if t.Parent ~= char then
						Menus.StopBuild()
					end
				end)
			end
		end)
	end
	if player.Character then
		hookChar(player.Character)
	end
	player.CharacterAdded:Connect(hookChar)
	RunService.RenderStepped:Connect(function()
		if not build.Active or not build.Ghost then
			return
		end
		local res = buildTarget()
		local char = player.Character
		if res and char then
			local d = (res.Position - char:GetPivot().Position).Magnitude
			local camp = state:GetAttribute("CampPos") or Vector3.zero
			local fromCamp = (res.Position - camp) * Vector3.new(1, 0, 1)
			local campR = state:GetAttribute("CampRadius") or 60
			-- เส้นขอบเขตแคมป์ (สร้างใหม่เมื่อกองไฟย้าย/อัปเกรด)
			local key = string.format("%d,%d,%d", math.floor(camp.X), math.floor(camp.Z), math.floor(campR))
			if build.ZoneKey ~= key then
				if build.Zone then
					build.Zone:Destroy()
				end
				local zone = Instance.new("Model")
				zone.Name = "BuildZone"
				groundRing(zone, camp, campR, OK_COLOR, math.clamp(math.floor(campR * 1.2), 48, 160))
				groundRing(zone, camp, NO_BUILD_R, BAD_COLOR, 24)
				zone.Parent = Workspace.CurrentCamera
				build.Zone = zone
				build.ZoneKey = key
			end
			local cf = CFrame.new(res.Position) * CFrame.Angles(0, build.Yaw, 0)
			local ok = d <= Config.BuildRange and res.Material ~= Enum.Material.Water and res.Material ~= Enum.Material.CrackedLava and (res.Position - camp).Magnitude > NO_BUILD_R
				and fromCamp.Magnitude <= campR -- นอกเขตแคมป์ = วางไม่ได้ (แดง)
				-- เตียงข้ามวันไม่ได้ช่วงคืนสุดท้าย (ตรงกับ DirectorService:CanSkipDay)
				and (build.Kind ~= "Bed" or (state:GetAttribute("Night") or 0) + 1 < Config.TotalNights)
			-- ทับกับสิ่งก่อสร้างอื่น (เช็กเหมือนฝั่ง server)
			local spec = Items.Structures[build.Kind]
			local folder = Workspace:FindFirstChild("Structures")
			if ok and spec and folder then
				local params = OverlapParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.FilterDescendantsInstances = { folder }
				ok = #Workspace:GetPartBoundsInBox(cf * CFrame.new(0, spec.Size.Y / 2 + 0.5, 0), spec.Size * 0.85, params) == 0
			end
			build.Valid = ok
			build.Ghost:PivotTo(cf)
			-- แผ่นรองพื้นเอียงตามพื้น
			local up = res.Normal
			local look = cf.LookVector - up * cf.LookVector:Dot(up)
			look = look.Magnitude > 0.01 and look.Unit or cf.LookVector
			local base = CFrame.lookAt(res.Position, res.Position + look, up)
			for _, part in ipairs(build.Footprint:GetChildren()) do
				part.CFrame = base * CFrame.new(part:GetAttribute("Offset") or Vector3.new(0, 0.06, 0))
			end
			tintGhost(ok and OK_COLOR or BAD_COLOR)
		end
	end)
end

return Menus
