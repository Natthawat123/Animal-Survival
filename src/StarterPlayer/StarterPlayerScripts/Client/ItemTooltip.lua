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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
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

-- คืน { Title, Sub, Category, Desc, Stats = { "..." }, Color }
function ItemTooltip.Info(id)
	local d = Items.Data[id]
	if not d then
		return nil
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
	local r = Recipes.ById[id]
	if r then
		table.insert(stats, "🔨 Craft at bench Lv." .. r.Bench)
	end
	return {
		Title = d.Thai or d.Name or id,
		Sub = d.Name,
		Category = (Items.CategoryThai and Items.CategoryThai[d.Category]) or d.Category or "",
		Desc = (Items.Desc and Items.Desc[id]) or "",
		Stats = stats,
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

local function inside(obj, p)
	local a, s = obj.AbsolutePosition, obj.AbsoluteSize
	return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
end

-- ผูกการ์ดกับปุ่ม/การ์ดไอเทม
function ItemTooltip.Attach(obj, id)
	if not (obj and Items.Data[id]) then
		return
	end
	obj.MouseEnter:Connect(function()
		if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
			return
		end
		owner = obj
		ItemTooltip.Show(id, "Mouse")
	end)
	obj.MouseLeave:Connect(function()
		-- ยังอยู่ในกรอบ (เมาส์ไปชี้ปุ่มลูก) ไม่ต้องซ่อน — RenderStepped จะเช็กเอง
		local m = UserInputService:GetMouseLocation()
		if owner == obj and not inside(obj, m) then
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
				ItemTooltip.Show(id, "Top")
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
	RunService.RenderStepped:Connect(function()
		if owner then
			if not (owner.Parent and owner.Visible and inside(owner, UserInputService:GetMouseLocation())) then
				ItemTooltip.Hide()
			else
				place()
			end
		end
	end)
	-- (เลิกเด้งสเตตัสตอนสลับของขึ้นมือแล้ว — โชว์เฉพาะในเมนูคราฟต์)
end

return ItemTooltip
