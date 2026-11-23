--[[
	ItemTooltip — การ์ดรายละเอียดไอเทม
	  PC: ชี้เมาส์ค้างบนไอเทม (กระสอบ/เมนูคราฟต์) -> การ์ดขึ้นข้างเมาส์
	  มือถือ: กดค้าง ~0.45 วิ -> การ์ดขึ้นด้านบนกลางจอ (ปล่อยนิ้วแล้วหายเอง)
	  แถบเครื่องมือ (Backpack ของ Roblox): หยิบเครื่องมือขึ้นมือ -> การ์ดสั้นๆ เหนือแถบ 2.5 วิ
	  ข้อมูลมาจาก Items (Desc/Tools/Structures/Fuel/Food/Heal) + Recipes
	ItemTooltip.Attach(guiObject, itemId) · ItemTooltip.Show(id) · ItemTooltip.Hide()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
local Animals = require(Shared.Animals)
local LootTables = require(Shared.LootTables)
local Shop = require(Shared.Shop)
local Classes = require(Shared.Classes)
local UIKit = require(script.Parent.UIKit)

local ItemTooltip = {}
local player = Players.LocalPlayer
local C = UIKit.Colors

local LONG_PRESS = 0.45

---------------------------------------------------------------- ข้อความ
local function num(v)
	if math.floor(v) == v then
		return tostring(v)
	end
	return string.format("%.1f", v)
end

---------------------------------------------------------------- หาได้จากไหน
-- ทรัพยากรในแมพ (ต้นไม้/หิน/คริสตัล/พุ่ม) — ตรงกับ PropBuilder Kinds.*.Node
local NODE = {
	SkullStoneEarth = { "⛺ Chief's chest · Earth tribe village" },
	SkullStoneWater = { "⛺ Chief's chest · Water tribe village" },
	SkullStoneAir = { "⛺ Chief's chest · Frost tribe village" },
	Wood = { "🪓 Chop trees", "🪓 Charred trees in the Fire land (bonus)" },
	Stone = { "⛏ Mine rocks", "⛏ Coal rocks (bonus)" },
	Iron = { "⛏ Mine iron ore rocks (sparkly)" },
	Coal = { "⛏ Mine coal rocks", "🪓 Chop charred trees (Fire land)" },
	Berries = { "🫐 Pick berry bushes", "🌱 Grow them in a Berry Patch" },
	Fiber = { "🫐 Berry bushes (bonus)" },
	TerraCore = { "💎 Break green crystals (Earth land)", "☄ Earth meteors", "🏛 Earth Sanctum reward" },
	TidePearl = { "💎 Break blue crystals (Water land)", "☄ Water meteors", "🏛 Water Sanctum reward" },
	GaleFeather = { "💎 Break white crystals (Frost land)", "☄ Frost meteors", "🏛 Frost Sanctum reward" },
	EmberShard = { "💎 Break red crystals (Fire land)", "☄ Fire meteors", "🏛 Fire Sanctum reward" },
	TerraHeart = { "🏛 Earth Sanctum reward (sometimes)" },
	TideHeart = { "🏛 Water Sanctum reward (sometimes)" },
	FrostHeart = { "🏛 Frost Sanctum reward (sometimes)" },
	EmberHeart = { "🏛 Fire Sanctum reward (sometimes)" },
	Stew = { "🍲 Stew Pot: 2 meat + 2 berries" },
	BerryPie = { "🍲 Stew Pot: 5 berries + 1 wood" },
	OldSack = { "🎒 Everyone starts with one" },
	OldAxe = { "🎒 Everyone starts with one (if the class has no axe)" },
}
local ELEMENT_NAME = { Earth = "Earth", Water = "Water", Air = "Frost", Fire = "Fire" }
local MAX_ANIMALS = 4

local function hasItem(list, id, key)
	for _, e in ipairs(list or {}) do
		if e[key or 1] == id then
			return true
		end
	end
	return false
end

-- รายการแหล่งที่หาได้ (ข้อความอังกฤษ · ระบบแปล Lang แปลทีละส่วนที่คั่นด้วย " · ")
function ItemTooltip.Where(id)
	local out = {}
	for _, s in ipairs(NODE[id] or {}) do
		table.insert(out, s)
	end
	-- ล่าสัตว์ / บอส
	local hunt, boss = {}, {}
	for _, key in ipairs((function()
		local ks = {}
		for k in pairs(Animals.Data) do
			table.insert(ks, k)
		end
		table.sort(ks, function(a, b)
			return (Animals.Data[a].Tier or 9) < (Animals.Data[b].Tier or 9) or ((Animals.Data[a].Tier or 9) == (Animals.Data[b].Tier or 9) and a < b)
		end)
		return ks
	end)()) do
		local a = Animals.Data[key]
		if a.Behaviour ~= "Spirit" and a.Behaviour ~= "Stalker" then
			for _, d in ipairs(a.Drops or {}) do
				if d.Item == id then
					table.insert(a.Behaviour == "Boss" and boss or hunt, a.Thai or a.Name)
					break
				end
			end
		end
	end
	if #hunt > 0 then
		local shown = { table.unpack(hunt, 1, math.min(#hunt, MAX_ANIMALS)) }
		local more = #hunt > MAX_ANIMALS and string.format(" · +%d more", #hunt - MAX_ANIMALS) or ""
		table.insert(out, string.format("🐾 Hunt: %s", table.concat(shown, " · ")) .. more)
	end
	if #boss > 0 then
		table.insert(out, string.format("👑 Boss: %s", table.concat(boss, " · ")))
	end
	-- ทำอาหาร
	for src, d in pairs(Items.Data) do
		if d.CooksInto == id then
			table.insert(out, string.format("🔥 Cook %s at the campfire", Items.DisplayName(src)))
		end
	end
	-- คราฟต์
	local r = Recipes.ById[id]
	if r then
		table.insert(out, string.format("🔨 Craft at bench Lv.%d", r.Bench))
	end
	-- กล่อง 3 สีทั่วแมพ
	if hasItem(LootTables.TierFixed, id) then
		table.insert(out, "📦 Every chest (1 each)")
	else
		local tiers = {}
		for t = 1, 3 do
			local ex = LootTables.TierExtra[t]
			if hasItem(LootTables.TierTools[t], id) or hasItem(LootTables.TierSacks[t], id) or hasItem(ex and ex.pool, id)
				or (t == 1 and id == "Medkit") then
				table.insert(tiers, LootTables.TierName[t])
			end
		end
		if #tiers > 0 then
			table.insert(out, string.format("📦 Chests: %s", table.concat(tiers, " · ")))
		end
	end
	-- หีบโบราณตามไบโอม
	local ancient = {}
	for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		if hasItem(LootTables.Ancient[el], id) then
			table.insert(ancient, ELEMENT_NAME[el])
		end
	end
	if #ancient == 4 then
		table.insert(out, "🗝 Ancient chests (every land)")
	elseif #ancient > 0 then
		table.insert(out, string.format("🗝 Ancient chests: %s", table.concat(ancient, " · ")))
	end
	if hasItem(LootTables.Airdrop, id) then
		table.insert(out, "🪂 Airdrop crates")
	end
	for _, t in ipairs(Shop.Trader) do
		if t.Give[id] then
			table.insert(out, "🧳 Wandering trader")
			break
		end
	end
	for _, k in ipairs(Shop.Kits) do
		if k.Items[id] then
			table.insert(out, "🛒 Lobby shop kits")
			break
		end
	end
	for _, cid in ipairs(Classes.Order) do
		local c = Classes.Data[cid]
		if c and c.StartItems and c.StartItems[id] then
			table.insert(out, "🎒 Starting item for some classes")
			break
		end
	end
	return out
end

-- คืน { Title, Sub, Category, Desc, Stats = { "..." }, Where = { "..." }, Color }
-- ของแบบ "อะไรก็ได้ในกลุ่ม" (AnyEssence / AnyHeart): รวมแหล่งที่หาได้ของทุกชิ้นในกลุ่ม
local function groupInfo(id)
	local members = Items.AnyGroups and Items.AnyGroups[id]
	if not members then
		return nil
	end
	local names, where, seen = {}, {}, {}
	for _, m in ipairs(members) do
		table.insert(names, Items.DisplayName(m))
		for _, w in ipairs(ItemTooltip.Where(m)) do
			if not seen[w] then
				seen[w] = true
				table.insert(where, w)
			end
		end
	end
	return {
		Title = (Items.AnyThai and Items.AnyThai[id]) or id,
		Sub = nil,
		Category = "Any one of these",
		Desc = "Use any one: " .. table.concat(names, " · "),
		Stats = {},
		Where = where,
		Color = C.Gold,
	}
end

function ItemTooltip.Info(id)
	local d = Items.Data[id]
	if not d then
		return groupInfo(id)
	end
	local stats = {}
	local t = Items.Tools[id]
	if t then
		table.insert(stats, "⚔ Damage " .. num(t.Damage))
		table.insert(stats, string.format("⏱ Speed %.1f hits/sec", 1 / math.max(t.Cooldown, 0.05)))
		table.insert(stats, "📏 Range " .. num(t.Range))
		if (t.Chop or 0) > 0 then
			table.insert(stats, "🪓 Chop wood x" .. num(t.Chop))
		end
		if (t.Mine or 0) > 0 then
			table.insert(stats, "⛏ Mine rock/ore x" .. num(t.Mine))
		end
		if t.Aoe then
			table.insert(stats, "💥 Area attack " .. num(t.Aoe))
		end
		if t.Burn then
			table.insert(stats, "🔥 Burn " .. num(t.Burn) .. "/s")
		end
		if t.Slow then
			table.insert(stats, "🧊 Slows enemies")
		end
		if t.Pierce then
			table.insert(stats, "➶ Pierces " .. num(t.Pierce) .. " enemies")
		end
		if t.Light then
			table.insert(stats, "💡 Light scares off the Moonfang")
		end
	end
	local sack = Items.Sacks[id]
	if sack then
		table.insert(stats, "🎒 Capacity " .. sack .. " items")
	end
	if d.ArmorHP then
		table.insert(stats, "🛡 Max HP +" .. num(d.ArmorHP))
	end
	if d.Food then
		table.insert(stats, "🍖 Food +" .. num(d.Food))
	end
	if d.Heal then
		table.insert(stats, (d.Heal >= 0 and "❤ Heal +" or "💔 HP loss ") .. num(math.abs(d.Heal)))
	end
	if d.Revive then
		table.insert(stats, "✨ Can revive downed teammates")
	end
	if d.CooksInto then
		table.insert(stats, "♨ Can be cooked at the campfire " .. Items.DisplayName(d.CooksInto))
	end
	if d.Fuel then
		table.insert(stats, "🔥 Fuel +" .. num(d.Fuel))
	end
	local st = Items.Structures[id]
	if st then
		table.insert(stats, "🛡 HP " .. num(st.Health))
		if st.Damage then
			table.insert(stats, "⚔ Damage " .. num(st.Damage))
		end
		if st.Range or st.Radius then
			table.insert(stats, "📏 Radius " .. num(st.Range or st.Radius))
		end
		if st.Light then
			table.insert(stats, "💡 Light " .. num(st.Light))
		end
	end
	local el = d.Element
	if el then
		table.insert(stats, (UIKit.ElementIcon[el] or "") .. " Element: " .. (UIKit.ElementThai[el] or el))
	end
	return {
		Title = d.Thai or d.Name or id,
		Sub = d.Name,
		Category = (Items.CategoryThai and Items.CategoryThai[d.Category]) or d.Category or "",
		Desc = (Items.Desc and Items.Desc[id]) or "",
		Stats = stats,
		Where = ItemTooltip.Where(id),
		Color = (el and C.Element[el]) or d.Color or C.Gold,
	}
end

---------------------------------------------------------------- การ์ด
local ui = {}
local current -- itemId ที่โชว์อยู่
local owner -- GuiObject ที่เมาส์ชี้อยู่ (PC)
local hideToken = 0

local function build()
	if ui.Card then
		return
	end
	local gui = UIKit.Screen("ItemTooltip", 70, true)
	ui.Gui = gui
	local card = UIKit.Frame(gui, {
		Size = UDim2.fromOffset(270, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(26, 28, 50),
		BackgroundTransparency = 0.04, Visible = false, ZIndex = 50,
	})
	UIKit.Corner(card, 12)
	ui.Stroke = UIKit.Stroke(card, C.Gold, 2, 0.1)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 8), UDim.new(0, 10)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 3)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = card
	local function line(order, size, font, color)
		return UIKit.Text(card, {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = size, Font = font, TextColor3 = color,
			LayoutOrder = order, ZIndex = 51, Text = "",
		})
	end
	ui.Title = line(1, 19, UIKit.Fonts.Black, C.Gold)
	ui.Sub = line(2, 12, UIKit.Fonts.Body, C.TextDim)
	ui.Cat = line(3, 13, UIKit.Fonts.Bold, Color3.fromRGB(150, 210, 255))
	ui.Desc = line(4, 14, UIKit.Fonts.Body, C.Text)
	ui.Stats = line(5, 14, UIKit.Fonts.Bold, Color3.fromRGB(255, 226, 170))
	ui.WhereHead = line(6, 14, UIKit.Fonts.Black, Color3.fromRGB(140, 235, 160))
	ui.WhereHead.Text = "📍 Where to find"
	ui.Where = line(7, 14, UIKit.Fonts.Body, Color3.fromRGB(205, 245, 210))
	ui.Card = card
	UIKit.AutoScale(card)
end

local function place()
	local card = ui.Card
	if not (card and card.Visible) then
		return
	end
	local vp = UIKit.Viewport()
	local sc = card:FindFirstChild("AutoScale")
	local k = sc and sc.Scale or 1
	local w, h = card.AbsoluteSize.X, card.AbsoluteSize.Y
	if w < 1 then
		w, h = 270 * k, 160 * k
	end
	if ui.Mode == "Mouse" then
		local m = UserInputService:GetMouseLocation()
		local x, y = m.X + 18, m.Y + 18
		if x + w > vp.X - 8 then
			x = m.X - w - 12
		end
		if y + h > vp.Y - 8 then
			y = vp.Y - h - 8
		end
		card.Position = UDim2.fromOffset(math.max(8, x), math.max(8, y))
	elseif ui.Mode == "Hotbar" then
		card.Position = UDim2.fromOffset(math.floor((vp.X - w) / 2), math.max(8, vp.Y - h - 100))
	else
		-- มือถือ: ด้านบนกลางจอ (ไม่ทับนิ้ว)
		card.Position = UDim2.fromOffset(math.floor((vp.X - w) / 2), math.floor(vp.Y * 0.2))
	end
end

-- mode: "Mouse" | "Top" | "Hotbar"
function ItemTooltip.Show(id, mode)
	local info = ItemTooltip.Info(id)
	if not info then
		return
	end
	build()
	hideToken += 1
	current = id
	ui.Mode = mode or (UIKit.IsTouch and "Top" or "Mouse")
	ui.Title.Text = info.Title
	ui.Title.TextColor3 = info.Color
	ui.Stroke.Color = info.Color
	ui.Sub.Text = info.Sub or ""
	ui.Sub.Visible = info.Sub ~= nil and info.Sub ~= info.Title
	ui.Cat.Text = "Category: " .. info.Category
	ui.Desc.Text = info.Desc
	ui.Desc.Visible = info.Desc ~= ""
	ui.Stats.Text = table.concat(info.Stats, "\n")
	ui.Stats.Visible = #info.Stats > 0
	ui.Where.Text = table.concat(info.Where, "\n")
	ui.Where.Visible = #info.Where > 0
	ui.WhereHead.Visible = #info.Where > 0
	ui.Card.Visible = true
	place()
	task.defer(place)
end

function ItemTooltip.Hide(id)
	if id and id ~= current then
		return
	end
	current = nil
	owner = nil
	if ui.Card then
		ui.Card.Visible = false
	end
end

-- ซ่อนหลังเวลาผ่านไป (ถ้าไม่มีอะไรมาโชว์ทับ)
local function hideLater(delay)
	hideToken += 1
	local token = hideToken
	task.delay(delay, function()
		if token == hideToken then
			ItemTooltip.Hide()
		end
	end)
end

-- ตำแหน่งเมาส์ในพิกัดเดียวกับ AbsolutePosition / GetGuiObjectsAtPosition
--   GetMouseLocation นับจากขอบจอบนสุด แต่ AbsolutePosition นับจากใต้แถบบนของ Roblox (แม้ IgnoreGuiInset)
--   เดิมเทียบตรงๆ -> คลาด 58 px: ป้ายวัตถุดิบในโต๊ะคราฟต์ (สูง 30 px) ถูกมองว่า "เมาส์ออกแล้ว" -> การ์ดหายทันทีทุกเฟรม
local function mouseGui()
	return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
end

local attached = setmetatable({}, { __mode = "k" }) -- GuiObject -> ฟังก์ชันคืนรหัสไอเทม

local function inside(obj, p)
	local a, s = obj.AbsolutePosition, obj.AbsoluteSize
	return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
end

-- ผูกการ์ดกับปุ่ม/การ์ดไอเทม
--   id = รหัสไอเทม หรือฟังก์ชันคืนรหัส (ช่องที่ของเปลี่ยนได้ เช่น แถบเครื่องมือ)
function ItemTooltip.Attach(obj, idOrFn)
	local getId = type(idOrFn) == "function" and idOrFn or function()
		return idOrFn
	end
	if not (obj and (type(idOrFn) == "function" or Items.Data[idOrFn] or (Items.AnyGroups and Items.AnyGroups[idOrFn]))) then
		return
	end
	local id -- รหัสที่โชว์อยู่ของปุ่มนี้
	attached[obj] = getId
	obj.MouseEnter:Connect(function()
		if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
			return
		end
		id = getId()
		if not (id and (Items.Data[id] or Items.AnyGroups[id])) then
			return
		end
		owner = obj
		ItemTooltip.Show(id, "Mouse")
	end)
	obj.MouseLeave:Connect(function()
		-- ยังอยู่ในกรอบ (เมาส์ไปชี้ปุ่มลูก) ไม่ต้องซ่อน — RenderStepped จะเช็กเอง
		if owner == obj and not inside(obj, mouseGui()) then
			ItemTooltip.Hide(id)
		end
	end)
	-- กดค้าง (มือถือ)
	obj.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local start = input.Position
		local alive = true
		local moved, ended
		moved = input.Changed:Connect(function(prop)
			if prop == "Position" and (input.Position - start).Magnitude > 14 then
				alive = false
			elseif prop == "UserInputState" and input.UserInputState ~= Enum.UserInputState.Begin and input.UserInputState ~= Enum.UserInputState.Change then
				alive = false
				if current == id and ui.Mode == "Top" then
					hideLater(1.2)
				end
			end
		end)
		ended = obj.InputEnded:Connect(function(i)
			if i == input then
				alive = false
				if current == id and ui.Mode == "Top" then
					hideLater(1.2)
				end
			end
		end)
		task.delay(LONG_PRESS, function()
			if alive and obj.Parent and obj.Visible then
				id = getId()
				if id and (Items.Data[id] or Items.AnyGroups[id]) then
					ItemTooltip.Show(id, "Top")
				end
			end
		end)
		task.delay(6, function()
			moved:Disconnect()
			ended:Disconnect()
		end)
	end)
end

---------------------------------------------------------------- แถบเครื่องมือ: หยิบของขึ้นมือ -> การ์ดสั้นๆ
function ItemTooltip.Init()
	build()
	-- PC: ไล่หาไอเทมใต้เมาส์ทุก 0.08 วิ (ไม่พึ่ง MouseEnter อย่างเดียว: เมนูคราฟต์สร้างการ์ดใหม่ตอนของในกระสอบเปลี่ยน
	--   เมาส์ค้างอยู่ที่เดิมจะไม่มี MouseEnter ใหม่ -> การ์ดเคยหายแล้วไม่ขึ้นอีก) · ชิ้นบนสุดที่ผูกไว้ชนะ (ป้ายวัตถุดิบ > การ์ดสูตร)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local touch = UserInputService:GetLastInputType() == Enum.UserInputType.Touch
		acc += dt
		if not touch and acc >= 0.08 then
			acc = 0
			local m = mouseGui()
			local hit
			for _, g in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(m.X, m.Y)) do
				if attached[g] then
					hit = g
					break
				end
			end
			if hit and hit ~= owner then
				local id = attached[hit]()
				if id and (Items.Data[id] or (Items.AnyGroups and Items.AnyGroups[id])) then
					owner = hit
					ItemTooltip.Show(id, "Mouse")
				end
			elseif not hit and owner then
				ItemTooltip.Hide()
			end
		end
		if owner then
			if not (owner.Parent and owner.Visible and inside(owner, mouseGui())) then
				ItemTooltip.Hide()
			else
				place()
			end
		end
	end)
	-- (เลิกเด้งสเตตัสตอนสลับของขึ้นมือแล้ว — โชว์เฉพาะในเมนูคราฟต์)
end

return ItemTooltip
