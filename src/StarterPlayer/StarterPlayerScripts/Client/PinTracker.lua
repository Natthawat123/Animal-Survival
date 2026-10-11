--[[
	PinTracker — แถบติดตามสูตรที่ปักหมุด 📌 (มุมซ้าย ใต้แถบเลือด)
	  แสดงวัตถุดิบ มี/ต้องใช้ ของสูตรที่ปักไว้ · ครบแล้วการ์ดเป็นสีเขียว "คราฟต์ได้!"
	  ปักหมุด/ถอนหมุดจากเมนูคราฟต์ (Menus) · จำสูตรไว้ในการตั้งค่า (PinRecipe)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
local UIKit = require(script.Parent.UIKit)
local ClientSettings = require(script.Parent.ClientSettings)
local ItemTooltip = require(script.Parent.ItemTooltip)

local PinTracker = {}
local player = Players.LocalPlayer
local C = UIKit.Colors
local ui = {}
local lastHave, lastNeed

local GOOD = Color3.fromRGB(140, 235, 150)
local BAD = Color3.fromRGB(255, 128, 112)

function PinTracker.Get()
	local id = ClientSettings.Get("PinRecipe")
	if type(id) == "string" and Recipes.ById[id] then
		return id
	end
	return nil
end

function PinTracker.Set(recipeId)
	ClientSettings.Set("PinRecipe", (recipeId and Recipes.ById[recipeId]) and recipeId or "")
	PinTracker.Refresh()
end

function PinTracker.Toggle(recipeId)
	if PinTracker.Get() == recipeId then
		PinTracker.Set(nil)
	else
		PinTracker.Set(recipeId)
	end
end

local function build()
	if ui.Card then
		return
	end
	local gui = UIKit.Screen("PinTracker", 6)
	local card = UIKit.Frame(gui, {
		Size = UDim2.fromOffset(240, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(20, 200),
		BackgroundColor3 = Color3.fromRGB(26, 28, 50), BackgroundTransparency = 0.15, Visible = false,
	})
	UIKit.Corner(card, 10)
	ui.Stroke = UIKit.Stroke(card, C.GoldDim, 2, 0.2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 6), UDim.new(0, 8)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = card
	local head = UIKit.Frame(card, { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 0 })
	ui.Title = UIKit.Text(head, { Size = UDim2.new(1, -48, 0, 22), Position = UDim2.fromOffset(0, 2), Text = "", TextSize = 16, Font = UIKit.Fonts.Black, TextColor3 = C.Gold })
	ui.Status = UIKit.Text(head, { Size = UDim2.new(1, -48, 0, 16), Position = UDim2.fromOffset(0, 25), Text = "", TextSize = 13, Font = UIKit.Fonts.Bold, TextColor3 = C.TextDim })
	-- ถอนหมุด (44px ให้นิ้วกดง่าย)
	local close = UIKit.Button(head, { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -44, 0, 0), Text = "✕", TextSize = 18, BackgroundColor3 = Color3.fromRGB(90, 60, 70) }, function()
		PinTracker.Set(nil)
	end)
	close:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	ui.Rows = UIKit.Frame(card, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1 })
	local rl = Instance.new("UIListLayout")
	rl.Padding = UDim.new(0, 1)
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	rl.Parent = ui.Rows
	ui.Card = card
	UIKit.AutoScale(card)
	-- ในแมพเท่านั้น
	player:GetAttributeChangedSignal("InRun"):Connect(PinTracker.Refresh)
	ClientSettings.OnChanged(function(key)
		if key == "PinRecipe" then
			PinTracker.Refresh()
		end
	end)
end

-- have(id) -> จำนวนที่มี · need(id, n) -> จำนวนที่ต้องใช้จริง (หลังส่วนลดทักษะ)
function PinTracker.Update(have, need)
	lastHave, lastNeed = have, need
	PinTracker.Refresh()
end

function PinTracker.Refresh()
	build()
	local id = PinTracker.Get()
	local r = id and Recipes.ById[id]
	local show = r ~= nil and player:GetAttribute("InRun") == true and lastHave ~= nil
	ui.Card.Visible = show
	if not show then
		return
	end
	for _, c in ipairs(ui.Rows:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local costs = {}
	for cid, n in pairs(r.Cost) do
		table.insert(costs, { cid, lastNeed and lastNeed(r.Id, n) or n })
	end
	table.sort(costs, function(a, b)
		return a[1] < b[1]
	end)
	local can = true
	for i, cn in ipairs(costs) do
		local have = lastHave(cn[1])
		local ok = have >= cn[2]
		can = can and ok
		local row = UIKit.Text(ui.Rows, {
			Size = UDim2.new(1, 0, 0, 20), LayoutOrder = i, TextSize = 14, Font = UIKit.Fonts.Bold, TextColor3 = ok and GOOD or BAD,
			Text = string.format("%s %s  %d/%d", ok and "✔" or "•", Items.DisplayName(cn[1]), have, cn[2]),
		})
		ItemTooltip.Attach(row, cn[1])
	end
	ui.Title.Text = "📌 " .. Items.DisplayName(r.Id)
	ui.Title.TextColor3 = can and GOOD or C.Gold
	ui.Status.Text = can and "คราฟต์ได้แล้ว! (ไปที่แคมป์ กด C)" or "ยังขาดวัตถุดิบ"
	ui.Status.TextColor3 = can and GOOD or C.TextDim
	ui.Stroke.Color = can and GOOD or C.GoldDim
	ui.Card.BackgroundColor3 = can and Color3.fromRGB(30, 70, 46) or Color3.fromRGB(26, 28, 50)
end

return PinTracker
