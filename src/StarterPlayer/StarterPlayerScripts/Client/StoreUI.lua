--[[
	StoreUI — ร้านค้าในล็อบบี้ (ปุ่ม ♦️ ร้านค้า / ปุ่ม + ข้าง Ruby) · ธีมกรอบไม้ (WoodKit)
	  เติม Ruby : Developer Product (Robux -> Ruby) — Config.DiamondPacks (ภาพถุง/หีบจาก Shared/PanelArt)
	  ID ที่ยังเป็น 0 = ยังไม่ได้สร้างใน Creator Hub -> ปุ่มเป็น "เร็วๆ นี้" (กดแล้วไม่พัง)
	  (Game Pass ไม่ขายในหน้านี้แล้ว · พรีเมียม Season Pass ซื้อได้ที่หน้า ภารกิจ > Season Pass)
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UIKit = require(script.Parent.UIKit)
local WoodKit = require(script.Parent.WoodKit)

local StoreUI = {}
local player = Players.LocalPlayer
local W = WoodKit.Colors
local RS = utf8.char(0xE002) -- ไอคอน Robux ในฟอนต์ของ Roblox
local ui = {}
local profile

local CARD_W, CARD_H, GAP = 236, 248, 24
-- ภาพของแต่ละแพ็ก: { ชื่อภาพ, ความกว้าง, x, y } (แพ็กสุดท้าย = หีบใหญ่ + ถุงข้างหน้า)
local PACK_ART = {
	{ { "Pack1", 120, 0, 0 } },
	{ { "Pack2", 166, 0, 0 } },
	{ { "Pack3", 132, 0, 0 } },
	{ { "Pack4", 178, 0, 0 } },
	{ { "Pack4", 182, 10, -6 }, { "Pack1", 76, -62, 16 } },
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function packArt(card, i)
	local shown = false
	for k, a in ipairs(PACK_ART[i] or PACK_ART[#PACK_ART]) do
		if WoodKit.Art(card, a[1], a[2], { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, a[3], 0, 96 + a[4]), ZIndex = 3 + k }) then
			shown = true
		end
	end
	if not shown then
		-- โหลดภาพไม่ได้: กองทับทิมวาดจาก Frame แทน
		local heaps = ({ { { 0, 0, 84 } }, { { -26, 6, 70 }, { 22, -2, 78 } } })[i] or { { -34, 10, 64 }, { 34, 10, 64 }, { 0, -6, 84 } }
		for k, h in ipairs(heaps) do
			UIKit.Icon(card, "Ruby", h[3], { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, h[1], 0, 102 + h[2]), ZIndex = 3 + k })
		end
	end
end

local function tag(card, text)
	local r = WoodKit.Board(card, { Size = UDim2.fromOffset(96, 28), Position = UDim2.new(1, -78, 0, -12), Rotation = 10, ZIndex = 12 }, rgb(150, 22, 46), W.Gold)
	UIKit.Text(r, { Size = UDim2.fromScale(1, 1), Text = text, Font = UIKit.Fonts.Title, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13 })
end

local function packCard(i, pack)
	local col, row = (i - 1) % 4, (i - 1) // 4
	local card = WoodKit.Board(ui.List, { Size = UDim2.fromOffset(CARD_W, CARD_H), Position = UDim2.fromOffset(col * (CARD_W + GAP), row * (CARD_H + 18)) }, rgb(74, 46, 28))
	-- ป้ายชื่อกระดาษ
	local title = WoodKit.Parchment(card, { Size = UDim2.new(1, -28, 0, 38), Position = UDim2.fromOffset(14, 10), ZIndex = 2 })
	WoodKit.Ink(title, { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0), Text = pack.Name, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	packArt(card, i)
	-- ริบบิ้นแดงจำนวน Ruby
	local ribbon = WoodKit.Board(card, { Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 138), ZIndex = 8 }, W.Red, W.Gold)
	UIKit.Text(ribbon, { Size = UDim2.fromScale(1, 1), Text = pack.Diamonds .. " Ruby", Font = UIKit.Fonts.Title, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
	if (pack.Bonus or 0) > 0 then
		UIKit.Text(card, {
			Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 180), Text = "+" .. pack.Bonus .. " โบนัส!", Font = UIKit.Fonts.Title, TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = W.Gold, ZIndex = 9,
		})
	end
	if pack.Tag then
		tag(card, pack.Tag)
	end
	local ready = (pack.ProductId or 0) > 0
	WoodKit.Button(card, ready and "Wood" or "Dark", {
		Size = UDim2.new(1, -40, 0, 34), Position = UDim2.new(0, 20, 1, -40), Text = ready and (RS .. " " .. pack.Robux) or "เร็วๆ นี้", TextSize = 19, ZIndex = 10,
	}, function()
		if ready then
			MarketplaceService:PromptProductPurchase(player, pack.ProductId)
		end
	end)
	if ready then
		WoodKit.Shine(card, i * 0.35)
	end
end

function StoreUI.Refresh()
	if not ui.Panel then
		return
	end
	ui.Gems.Text = tostring(player:GetAttribute("Diamonds") or (profile and profile.Diamonds) or 0)
	for _, c in ipairs(ui.List:GetChildren()) do
		if c:IsA("GuiObject") and c ~= ui.Hint then
			c:Destroy()
		end
	end
	for i, pack in ipairs(Config.DiamondPacks) do
		packCard(i, pack)
	end
end

function StoreUI.Open()
	ui.Panel.Visible = true
	UIKit.Pop(ui.Panel)
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
	local win = WoodKit.Window(gui, { Name = "StoreWindow", Size = Vector2.new(1080, 640), Title = "🛒 ร้านค้า", TitleWidth = 320, Shrink = false, OnClose = StoreUI.Close })
	ui.Panel = win.Frame
	UIKit.RegisterWindow(ui.Panel, StoreUI.Close, { Dim = 0.55 })
	local body = win.Body
	ui.Gems = WoodKit.RubyPill(body, { Position = UDim2.new(1, -206, 0, 42) })
	-- แท็บเดียว (เติม Ruby) — ไว้บอกว่าอยู่หน้าไหน
	local tab = WoodKit.Tab(body, "      เติม Ruby", 1, 190)
	tab.Position = UDim2.fromOffset(32, 44)
	WoodKit.SetTab(tab, true)
	UIKit.Icon(tab, "Ruby", 38, { Position = UDim2.fromOffset(22, 3), ZIndex = 2 })
	-- รายการแพ็ก (วางเอง 4 ต่อแถว) + กระดาษคำอธิบายมุมขวาล่าง
	local list = UIKit.Frame(body, { BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 104), Size = UDim2.new(1, -64, 1, -124) })
	ui.List = list
	local hint = WoodKit.Parchment(list, { Size = UDim2.new(1, -(CARD_W + GAP), 0, 84), Position = UDim2.new(0, CARD_W + GAP, 0, 2 * CARD_H + 18 - 84) })
	WoodKit.Ink(hint, {
		Size = UDim2.new(1, -40, 1, -12), Position = UDim2.fromOffset(20, 6), TextSize = 18, Font = UIKit.Fonts.Bold, TextColor3 = W.InkDim, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center, Text = "Ruby ใช้ซื้อคลาส ข้ามเลเวลคลาส รีโรลสต็อค และชุดเริ่มต้น — ได้ฟรีจากการเล่น/หม้อรางวัลรายวันด้วยนะ!",
	})
	ui.Hint = hint
	player:GetAttributeChangedSignal("Diamonds"):Connect(function()
		if StoreUI.IsOpen() then
			ui.Gems.Text = tostring(player:GetAttribute("Diamonds") or 0)
		end
	end)
end

return StoreUI
