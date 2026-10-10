--[[
	StoreUI — ร้านค้าในล็อบบี้ (ปุ่ม 💎 ร้านค้า / ปุ่ม + ข้างเพชร)
	  แท็บ 💎 เติมเพชร  : Developer Product (Robux -> เพชร) — Config.DiamondPacks
	  แท็บ 🎫 Game Pass : ซื้อครั้งเดียวได้ถาวร — Config.GamePasses
	  ID ที่ยังเป็น 0 = ยังไม่ได้สร้างใน Creator Hub -> ปุ่มเป็น "เร็วๆ นี้" (กดแล้วไม่พัง)
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)

local StoreUI = {}
local player = Players.LocalPlayer
local C = UIKit.Colors
local RS = utf8.char(0xE002) -- ไอคอน Robux ในฟอนต์ของ Roblox
local ui = { Tab = "Diamonds" }
local profile
local passes = {}

local TABS = {
	{ Id = "Diamonds", Text = "💎 เติมเพชร", Color = C.Cyan },
	{ Id = "Passes", Text = "🎫 Game Pass", Color = C.Gold },
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- แสงวิ้งวิ่งผ่านการ์ด (UIGradient เลื่อนซ้าย->ขวา วนไปเรื่อยๆ)
local function shine(frame, delayT)
	local g = Instance.new("UIGradient")
	g.Rotation = 20
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1),
	})
	g.Offset = Vector2.new(-1, 0)
	local sheen = UIKit.Frame(frame, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 9 })
	UIKit.Corner(sheen, 14)
	g.Parent = sheen
	task.spawn(function()
		task.wait(delayT or 0)
		while sheen.Parent do
			g.Offset = Vector2.new(-1, 0)
			TweenService:Create(g, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Offset = Vector2.new(1, 0) }):Play()
			task.wait(3.2)
		end
	end)
	return sheen
end

-- วงแสงหมุนหลังไอคอน
local function rays(parent, color, size, pos)
	local f = UIKit.Frame(parent, { Size = UDim2.fromOffset(size, size), Position = pos, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color, BackgroundTransparency = 0.35, ZIndex = 2 })
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.15, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(0.45, 1),
		NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 0.2),
	})
	g.Parent = f
	task.spawn(function()
		while f.Parent do
			g.Rotation = (os.clock() * 40) % 360
			task.wait(1 / 30)
		end
	end)
	return f
end

local function ribbon(card, text, color)
	local r = UIKit.Frame(card, { Size = UDim2.fromOffset(110, 26), Position = UDim2.new(1, -96, 0, -10), BackgroundColor3 = color, BackgroundTransparency = 0, ZIndex = 12, Rotation = 8 })
	UIKit.Corner(r, 8)
	UIKit.Stroke(r, C.Outline, 2, 0)
	UIKit.Text(r, { Size = UDim2.fromScale(1, 1), Text = text, Font = UIKit.Fonts.Title, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13 })
end

local function clear()
	for _, c in ipairs(ui.Scroll:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function priceButton(card, text, color, enabled, onClick)
	local b = UIKit.ColorButton(card, enabled and color or rgb(90, 94, 120), {
		Size = UDim2.new(1, -24, 0, 42), Position = UDim2.new(0, 12, 1, -54), Text = text, TextSize = 22, Font = UIKit.Fonts.Title, ZIndex = 11,
	}, function()
		if enabled and onClick then
			onClick()
		end
	end)
	if not enabled then
		b.TextColor3 = rgb(210, 210, 225)
	end
	return b
end

local function baseCard(order, top, bottom)
	local card = UIKit.Card(ui.Scroll, { LayoutOrder = order })
	card.BackgroundColor3 = Color3.new(1, 1, 1) -- สีจริงมาจาก UIGradient (คูณกับพื้นขาว)
	card:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(top, bottom)
	card.ClipsDescendants = false
	return card
end

function StoreUI.RefreshDiamonds()
	ui.Grid.CellSize = UDim2.fromOffset(196, 268)
	ui.Hint.Text = "เพชรใช้ซื้อคลาส ข้ามเลเวลคลาส รีโรลสต็อค และชุดเริ่มต้น · ได้ฟรีจากการเล่น/หม้อรางวัลรายวันด้วยนะ!"
	for i, pack in ipairs(Config.DiamondPacks) do
		local card = baseCard(i, rgb(40, 96, 150), rgb(22, 36, 80))
		rays(card, rgb(120, 220, 255), 120, UDim2.new(0.5, 0, 0, 74))
		UIKit.Text(card, { Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 34), Text = pack.Icon, TextSize = 64, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
		local amt = UIKit.Text(card, {
			Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 128), Text = "💎 " .. pack.Diamonds, Font = UIKit.Fonts.Title, TextSize = 34,
			TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = rgb(170, 240, 255), ZIndex = 5,
		})
		UIKit.Gradient(amt, rgb(255, 255, 255), rgb(120, 220, 255), 90)
		UIKit.Text(card, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 10), Text = pack.Name, Font = UIKit.Fonts.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
		if (pack.Bonus or 0) > 0 then
			UIKit.Text(card, {
				Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 168), Text = "+" .. pack.Bonus .. " โบนัส!", Font = UIKit.Fonts.Title, TextSize = 19,
				TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = rgb(140, 255, 120), ZIndex = 5,
			})
		end
		if pack.Tag then
			ribbon(card, pack.Tag, pack.Tag == "คุ้มสุด" and C.Pink or C.Orange)
		end
		local ready = (pack.ProductId or 0) > 0
		priceButton(card, ready and (RS .. " " .. pack.Robux) or "เร็วๆ นี้", C.Green, ready, function()
			MarketplaceService:PromptProductPurchase(player, pack.ProductId)
		end)
		shine(card, i * 0.35)
	end
end

function StoreUI.RefreshPasses()
	ui.Grid.CellSize = UDim2.fromOffset(242, 268)
	ui.Hint.Text = "Game Pass ซื้อครั้งเดียว ได้ถาวรทุกรอบ · ขอบคุณที่ช่วยสนับสนุนเกม 🙏"
	for i, pass in ipairs(Config.GamePasses) do
		local have = passes[pass.Id] or player:GetAttribute("Pass_" .. pass.Id) == true
		local card = baseCard(i, have and rgb(60, 120, 60) or rgb(120, 82, 30), have and rgb(24, 52, 30) or rgb(52, 30, 16))
		rays(card, rgb(255, 214, 90), 110, UDim2.new(0.5, 0, 0, 66))
		UIKit.Text(card, { Size = UDim2.new(1, 0, 0, 72), Position = UDim2.fromOffset(0, 30), Text = pass.Icon, TextSize = 58, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
		local name = UIKit.Text(card, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 106), Text = pass.Name, Font = UIKit.Fonts.Title, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
		UIKit.Gradient(name, rgb(255, 250, 200), rgb(255, 190, 60), 90)
		UIKit.Text(card, {
			Size = UDim2.new(1, -24, 0, 66), Position = UDim2.fromOffset(12, 138), Text = pass.Desc, TextSize = 14, TextWrapped = true, Font = UIKit.Fonts.Bold,
			TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = rgb(240, 230, 210), ZIndex = 5,
		})
		local ready = (pass.PassId or 0) > 0
		if have then
			priceButton(card, "✔ มีแล้ว", C.Blue, false)
		else
			priceButton(card, ready and (RS .. " " .. pass.Robux) or "เร็วๆ นี้", C.Green, ready, function()
				MarketplaceService:PromptGamePassPurchase(player, pass.PassId)
			end)
			shine(card, i * 0.4)
		end
		if pass.Id == "VIP" then
			ribbon(card, "แนะนำ", C.Pink)
		end
	end
end

function StoreUI.Refresh()
	if not ui.Panel then
		return
	end
	ui.Gems.Text = tostring(player:GetAttribute("Diamonds") or (profile and profile.Diamonds) or 0)
	for id, b in pairs(ui.TabButtons) do
		local on = id == ui.Tab
		b.BackgroundColor3 = on and b:GetAttribute("OnColor") or rgb(58, 66, 104)
		b.Size = on and UDim2.fromOffset(196, 46) or UDim2.fromOffset(186, 40)
	end
	clear()
	if ui.Tab == "Passes" then
		StoreUI.RefreshPasses()
	else
		ui.Tab = "Diamonds"
		StoreUI.RefreshDiamonds()
	end
end

function StoreUI.Open(tab)
	ui.Tab = tab or ui.Tab or "Diamonds"
	ui.Panel.Visible = true
	UIKit.Pop(ui.Panel)
	task.spawn(function()
		local ok, info = pcall(function()
			return Remotes.Get("GetShopInfo"):InvokeServer()
		end)
		if ok and info and info.Passes then
			passes = info.Passes
			if ui.Panel.Visible then
				StoreUI.Refresh()
			end
		end
	end)
	StoreUI.Refresh()
end

function StoreUI.Close()
	if ui.Panel then
		ui.Panel.Visible = false
	end
end

function StoreUI.IsOpen()
	return ui.Panel ~= nil and ui.Panel.Visible
end

function StoreUI.SetProfile(p)
	profile = p
	if StoreUI.IsOpen() then
		StoreUI.Refresh()
	end
end

function StoreUI.Init(gui)
	local panel = UIKit.Card(gui, {
		Size = UDim2.fromOffset(1080, 620), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), BackgroundColor3 = rgb(36, 40, 70), Visible = false,
	})
	ui.Panel = panel
	UIKit.Header(panel, "🛒 ร้านค้า", C.Green)
	UIKit.CloseButton(panel, StoreUI.Close)
	-- เพชรของเรา
	local pill = UIKit.Frame(panel, { Size = UDim2.fromOffset(170, 42), Position = UDim2.new(1, -206, 0, 34), BackgroundColor3 = rgb(20, 24, 44), BackgroundTransparency = 0 })
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(1, 0)
	pc.Parent = pill
	UIKit.Stroke(pill, C.Outline, 2, 0)
	UIKit.IconBadge(pill, "💎", C.Cyan, 48, { Position = UDim2.fromOffset(-20, -3) })
	ui.Gems = UIKit.Text(pill, { Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(34, 0), Text = "0", Font = UIKit.Fonts.Title, TextSize = 26 })
	-- แท็บ
	local tabs = UIKit.Frame(panel, { Size = UDim2.new(1, -260, 0, 50), Position = UDim2.fromOffset(24, 30), BackgroundTransparency = 1 })
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.VerticalAlignment = Enum.VerticalAlignment.Center
	tl.Padding = UDim.new(0, 10)
	tl.Parent = tabs
	ui.TabButtons = {}
	for _, t in ipairs(TABS) do
		local b = UIKit.ColorButton(tabs, t.Color, { Size = UDim2.fromOffset(186, 40), Text = t.Text, TextSize = 19, Font = UIKit.Fonts.Title }, function()
			ui.Tab = t.Id
			StoreUI.Refresh()
		end)
		b:SetAttribute("OnColor", t.Color)
		ui.TabButtons[t.Id] = b
	end
	-- รายการ
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -40, 1, -150)
	scroll.Position = UDim2.fromOffset(20, 96)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = C.GoldDim
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = scroll
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(196, 268)
	grid.CellPadding = UDim2.fromOffset(14, 18)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	ui.Scroll, ui.Grid = scroll, grid
	ui.Hint = UIKit.Text(panel, { Size = UDim2.new(1, -40, 0, 22), Position = UDim2.new(0, 20, 1, -40), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 15, TextColor3 = C.TextDim, Text = "" })
	player:GetAttributeChangedSignal("Diamonds"):Connect(function()
		if StoreUI.IsOpen() then
			ui.Gems.Text = tostring(player:GetAttribute("Diamonds") or 0)
		end
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p, _, purchased)
		if p == player and purchased then
			task.wait(1)
			StoreUI.Open("Passes")
		end
	end)
end

return StoreUI
