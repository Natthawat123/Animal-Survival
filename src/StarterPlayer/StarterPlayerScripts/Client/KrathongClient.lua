--[[
	KrathongClient — ฝั่งผู้เล่นของอีเวนต์ลอยกระทง (KrathongService)
	  ประกาศเปิดงาน (แบนเนอร์) · ตัวนับ "🌸 7/20" กลางบนจอ (เฉพาะตอนอยู่ในมิติเทศกาล)
	  เก็บกระทง: ประกาย + "+1" ลอยขึ้น + เสียง · ครบ 20: ฉากขอพรสำเร็จ (พลุ + แบนเนอร์)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UIKit = require(script.Parent.UIKit)
local Cinematics = require(script.Parent.Cinematics)
local WoodKit = require(script.Parent.WoodKit)
local ItemIcon = require(script.Parent.ItemIcon)
local ItemTooltip = require(script.Parent.ItemTooltip)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shop = require(Shared:WaitForChild("Shop"))
local Items = require(Shared:WaitForChild("Items"))

local KrathongClient = {}
local player = Players.LocalPlayer
local PINK = Color3.fromRGB(255, 160, 210)
local GOLD = Color3.fromRGB(255, 214, 120)

local function sparkle(pos, color, count, speed)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(pos)
	p.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.6, 1.3)
	e.Speed = NumberRange.new(speed or 8, (speed or 8) * 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = p
	e:Emit(count or 30)
	game:GetService("Debris"):AddItem(p, 2)
end

local function floatText(pos, text, color)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos + Vector3.new(0, 2, 0)
	a.Parent = Workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 40)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = a
	bb.Parent = a
	local t = UIKit.Text(bb, { Size = UDim2.fromScale(1, 1), Text = text, TextSize = 28, Font = UIKit.Fonts.Title, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center })
	t:SetAttribute("NoTranslate", true)
	UIKit.TextStroke(t, 2, 0.1)
	TweenService:Create(a, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { WorldPosition = a.WorldPosition + Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(a, 1.3)
end

local function sound(id, vol, pitch)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 0.5
	s.PlaybackSpeed = pitch or 1
	s.Parent = game:GetService("SoundService")
	s:Play()
	game:GetService("Debris"):AddItem(s, 4)
end

---------------------------------------------------------------- ร้านงานวัด (จ่ายด้วยกระทง)
local shop = {}

local function giveText(o)
	if o.Chest then
		return o.Name or "Chest"
	end
	local parts = {}
	for id, n in pairs(o.Give) do
		table.insert(parts, Items.DisplayName(id) .. " x" .. n)
	end
	table.sort(parts)
	return table.concat(parts, "  ")
end

function shop.Build(gui)
	local win = WoodKit.Window(gui, { Name = "FestivalShop", Size = Vector2.new(940, 600), Title = "🌸 Festival Shop", TitleWidth = 320, OnClose = function()
		shop.Panel.Visible = false
	end })
	shop.Panel = win.Frame
	shop.Panel.Position = UDim2.fromScale(0.5, 0.52)
	UIKit.AutoScale(shop.Panel)
	local quote = WoodKit.Parchment(win.Body, { Size = UDim2.new(1, -64, 0, 44), Position = UDim2.fromOffset(32, 44) })
	WoodKit.Ink(quote, { Size = UDim2.new(1, -200, 1, 0), Position = UDim2.fromOffset(12, 0), TextSize = 17, Font = UIKit.Fonts.Bold, TextColor3 = WoodKit.Colors.InkDim, Text = "\"Krathongs for festival gifts, dear! The festival ends tonight\"" })
	shop.Bank = WoodKit.Ink(quote, { Size = UDim2.fromOffset(170, 44), Position = UDim2.new(1, -182, 0, 0), TextSize = 26, TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
	shop.Bank:SetAttribute("NoTranslate", true)
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
	grid.CellSize = UDim2.new(0.5, -8, 0, 128)
	grid.CellPadding = UDim2.fromOffset(14, 14)
	grid.Parent = scroll
	shop.Grid, shop.Scroll = grid, scroll
	UIKit.RegisterWindow(shop.Panel, nil, { Backdrop = false })
	UIKit.OnResize(shop.Refresh)
end

function shop.Refresh()
	if not (shop.Panel and shop.Panel.Visible) then
		return
	end
	local bank = player:GetAttribute("KrathongBank") or 0
	shop.Bank.Text = "🌸 " .. bank
	for _, c in ipairs(shop.Scroll:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	shop.Grid.CellSize = UIKit.IsPhone() and UDim2.new(1, -4, 0, 128) or UDim2.new(0.5, -8, 0, 128)
	for i, o in ipairs(Shop.Festival) do
		local left = o.Stock - (player:GetAttribute("Fest_" .. o.Id) or 0)
		local ok = bank >= o.Price and left > 0
		local f = WoodKit.Parchment(shop.Scroll, { LayoutOrder = i }, ok and Color3.fromRGB(255, 226, 236) or nil)
		local pic = WoodKit.Board(f, { Size = UDim2.fromOffset(100, 100), Position = UDim2.fromOffset(12, 14), ZIndex = 2 }, Color3.fromRGB(34, 24, 18), WoodKit.Colors.GoldDark)
		local giveId = o.Give and next(o.Give)
		if giveId then
			ItemIcon.Make(pic, giveId, { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), ZIndex = 3 })
			ItemTooltip.Attach(f, giveId)
		else
			UIKit.Text(pic, { Size = UDim2.fromScale(1, 1), Text = "🎁", TextSize = 56, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
		end
		WoodKit.Ink(f, { Size = UDim2.new(1, -134, 0, 26), Position = UDim2.fromOffset(122, 12), Text = giveText(o), TextSize = 19, TextTruncate = Enum.TextTruncate.AtEnd })
		local price = WoodKit.Ink(f, { Size = UDim2.new(1, -262, 0, 34), Position = UDim2.fromOffset(122, 46), Text = string.format("🌸 %d", o.Price), TextSize = 28, TextColor3 = bank >= o.Price and Color3.fromRGB(40, 130, 60) or Color3.fromRGB(180, 50, 40) })
		price:SetAttribute("NoTranslate", true)
		WoodKit.Ink(f, { Size = UDim2.fromOffset(116, 18), Position = UDim2.new(1, -128, 1, -82), Text = left > 0 and string.format("%d/%d trades left", left, o.Stock) or "Sold out", TextSize = 14, Font = UIKit.Fonts.Bold, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = left > 0 and WoodKit.Colors.InkDim or Color3.fromRGB(170, 50, 40) })
		WoodKit.Button(f, ok and "Red" or "Off", { Size = UDim2.fromOffset(116, 48), Position = UDim2.new(1, -128, 1, -60), Text = "🤝 Trade", TextSize = 20, ZIndex = 4 }, function()
			Remotes.Get("KrathongTrade"):FireServer(o.Id)
		end)
	end
end

function KrathongClient.Init(state, hud)
	local gui = UIKit.Screen("Krathong", 21)
	shop.Build(gui)
	-- ตัวนับกลางบนจอ (ใต้แถบเวลา): กระทงในกระเป๋า (ไว้แลกของ) + เก็บไปแล้วกี่อันจาก 20
	local box = UIKit.Frame(gui, { Size = UDim2.fromOffset(250, 58), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118), BackgroundColor3 = Color3.fromRGB(40, 22, 44), BackgroundTransparency = 0.15, Visible = false })
	UIKit.AutoScale(box)
	UIKit.Corner(box, 25)
	UIKit.Stroke(box, PINK, 2.5, 0)
	local count = UIKit.Text(box, { Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromScale(0.04, 0), Text = "", TextSize = 30, Font = UIKit.Fonts.Title, TextColor3 = Color3.fromRGB(255, 236, 246), TextXAlignment = Enum.TextXAlignment.Center })
	count:SetAttribute("NoTranslate", true)
	UIKit.Text(box, { Size = UDim2.new(0.44, 0, 0, 20), Position = UDim2.new(0.52, 0, 0, 7), Text = "Collected", TextSize = 15, Font = UIKit.Fonts.Bold, TextColor3 = Color3.fromRGB(255, 190, 225), TextXAlignment = Enum.TextXAlignment.Center })
	local got = UIKit.Text(box, { Size = UDim2.new(0.44, 0, 0, 26), Position = UDim2.new(0.52, 0, 0, 26), Text = "", TextSize = 22, Font = UIKit.Fonts.Title, TextColor3 = Color3.fromRGB(255, 236, 246), TextXAlignment = Enum.TextXAlignment.Center })
	got:SetAttribute("NoTranslate", true)
	local scale = Instance.new("UIScale")
	scale.Parent = box
	local max = 20
	local function refresh()
		local n = player:GetAttribute("Krathongs") or 0
		count.Text = "🌸 " .. (player:GetAttribute("KrathongBank") or 0)
		got.Text = string.format("%d/%d", n, max)
		got.TextColor3 = n >= max and GOLD or Color3.fromRGB(255, 236, 246)
		shop.Refresh()
	end
	player:GetAttributeChangedSignal("Krathongs"):Connect(refresh)
	player:GetAttributeChangedSignal("KrathongBank"):Connect(refresh)
	player.AttributeChanged:Connect(function(a)
		if a:sub(1, 5) == "Fest_" then
			shop.Refresh()
		end
	end)
	refresh()
	-- โชว์เฉพาะตอนอยู่ในมิติเทศกาล (Y > 3200) · ออกจากมิติ = ปิดร้าน
	RunService.Heartbeat:Connect(function()
		local cam = Workspace.CurrentCamera
		local p = cam and cam.CFrame.Position
		local inside = p ~= nil and p.Y > 3200 and math.abs(p.X) < 6000 and math.abs(p.Z) < 6000 and player:GetAttribute("InRun") == true
		box.Visible = inside and not shop.Panel.Visible -- เปิดร้าน = ซ่อนตัวนับ (ยอดกระทงโชว์ในร้านแล้ว ไม่ทับป้ายชื่อร้าน)
		if not inside and shop.Panel.Visible then
			shop.Panel.Visible = false
		end
	end)

	Remotes.Get("WorldEvent").OnClientEvent:Connect(function(kind, d)
		d = d or {}
		if kind == "Krathong" then
			max = d.Max or max
			refresh()
			Cinematics.Banner("LOY KRATHONG FESTIVAL", "A big portal opened in the wilds · Tonight only", PINK, 4.5, { Size = 58, Y = 0.2 })
			sound("rbxassetid://9116395085", 0.5, 1.1)
		elseif kind == "KrathongGot" then
			max = d.Max or max
			if d.Position then
				sparkle(d.Position + Vector3.new(0, 1.5, 0), PINK, 34, 7)
				floatText(d.Position, "+1 🌸", PINK)
			end
			sound("rbxassetid://17208319162", 0.55, 1.15)
			scale.Scale = 1.25
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			refresh()
		elseif kind == "KrathongShop" then
			shop.Panel.Visible = true
			shop.Refresh()
		elseif kind == "KrathongBought" then
			sound("rbxassetid://17208319162", 0.6, 0.9)
			if d.Position then
				sparkle(d.Position + Vector3.new(0, 4, 0), GOLD, 40, 9)
			end
		elseif kind == "KrathongWish" then
			Cinematics.Banner("WISH GRANTED", string.format("You collected every krathong · +%d bonus krathongs for the festival shop", d.Bonus or 5), GOLD, 5, { Size = 62, Y = 0.24 })
			sound("rbxassetid://125706237686412", 0.6, 1)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				for k = 0, 5 do
					task.delay(k * 0.25, function()
						sparkle(root.Position + Vector3.new(math.random(-14, 14), 18 + math.random(0, 10), math.random(-14, 14)), k % 2 == 0 and GOLD or PINK, 60, 18)
					end)
				end
			end
		end
	end)
end

return KrathongClient
