--[[
	PadUI — ยืนบนแท่นเริ่มเกมในล็อบบี้ · ธีมกรอบไม้ (WoodKit)
	  หัวหน้าแท่น (คนแรกที่ขึ้น): หน้าต่างกลางจอให้เลือกจำนวนผู้เล่น 1-8 → กดแล้วปิดเองทันที
	  ทุกคนบนแท่น: แถบสถานะเล็กๆ ด้านบนจอ (จำนวนคน + นับถอยหลัง) · หัวหน้ากด "เปลี่ยน" เพื่อเลือกใหม่ได้
	อ่านสถานะจาก attribute ของ Lobby/MatchBox<i> (Size, Count, Countdown, Host) · เลือกจำนวน -> Remotes.PadSize
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UIKit = require(script.Parent.UIKit)
local WoodKit = require(script.Parent.WoodKit)

local PadUI = {}
local player = Players.LocalPlayer

local function inside(zone, pos)
	local rel = zone.CFrame:PointToObjectSpace(pos)
	return math.abs(rel.X) < zone.Size.X / 2 and math.abs(rel.Y) < zone.Size.Y / 2 and math.abs(rel.Z) < zone.Size.Z / 2
end

function PadUI.Init()
	local gui = UIKit.Screen("PadUI", 30)

	-------------------------------------------------- หน้าต่างเลือกจำนวน (กลางจอ) · ธีมกรอบไม้
	local current = { Zone = nil, Picked = {} }
	local function close()
		current.PickerFrame.Visible = false
	end
	local win = WoodKit.Window(gui, { Name = "PadPicker", Size = Vector2.new(780, 330), Title = "👥 เลือกจำนวนผู้เล่น", TitleWidth = 470, BannerHeight = 120, OnClose = close })
	local picker = win.Frame
	current.PickerFrame = picker
	picker.Position = UDim2.fromScale(0.5, 0.52)
	UIKit.AutoScale(picker)
	local pickTitle = win.Title
	UIKit.Text(win.Body, { Size = UDim2.new(1, -60, 0, 24), Position = UDim2.fromOffset(30, 46), TextSize = 18, TextColor3 = WoodKit.Colors.Gold, TextXAlignment = Enum.TextXAlignment.Center, Text = "—  ทีมจะออกเดินทางเมื่อคนครบ หรือเมื่อหมดเวลา  —" })
	local grid = UIKit.Frame(win.Body, { Size = UDim2.new(1, -60, 0, 190), Position = UDim2.fromOffset(30, 86), BackgroundTransparency = 1 })
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(164, 84)
	gl.CellPadding = UDim2.fromOffset(16, 18)
	gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	UIKit.RegisterWindow(picker, close) -- Esc / แตะนอกหน้าต่าง = ปิด (กด "เปลี่ยน" เพื่อเปิดใหม่)
	local pickButtons = {}
	for n = 1, 8 do
		local icon = n == 1 and "👤" or "👥"
		local b = WoodKit.Button(grid, "Parch", { Text = icon .. "  " .. (n == 1 and "1 (เดี่ยว)" or (n .. " คน")), TextSize = 26, LayoutOrder = n }, function()
			if current.Zone then
				Remotes.Get("PadSize"):FireServer(current.Zone:GetAttribute("PadIndex"), n)
				current.Picked[current.Zone] = true
			end
			close() -- เลือกแล้วปิดทันที ไปรอคน/รอเวลาที่แถบด้านบน
		end)
		-- หมุดทองกลางขอบบน (แบบป้ายไม้ในภาพอ้างอิง)
		local stud = WoodKit.Frame(b, { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Rotation = 45, BackgroundColor3 = WoodKit.Colors.Gold, ZIndex = 3 })
		WoodKit.Stroke(stud, WoodKit.Colors.WoodDark, 1.5, 0)
		pickButtons[n] = b
	end

	-------------------------------------------------- แถบสถานะ (ด้านบนจอ ใต้ชื่อค่าย) · ป้ายไม้ + หมาป่า/อินทรี + ตราอุ้งเท้า
	local barWin = WoodKit.Window(gui, { Name = "PadBar", Size = Vector2.new(640, 104), Plaque = false, Lanterns = false, TitleWidth = 436, BannerHeight = 72 })
	local bar = barWin.Frame
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 104)
	UIKit.AutoScale(bar)
	WoodKit.Medallion(bar, "🐾", 52, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), ZIndex = 12 }, Color3.fromRGB(110, 70, 34))
	local info = WoodKit.Board(barWin.Body, { Size = UDim2.new(1, -206, 1, -30), Position = UDim2.fromOffset(18, 15), ZIndex = 2 }, Color3.fromRGB(96, 30, 22), WoodKit.Colors.GoldDark)
	local status = UIKit.Text(info, { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(12, 4), Font = UIKit.Fonts.Title, TextSize = 28, Text = "", TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	local sub = UIKit.Text(info, { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(12, 40), TextSize = 16, TextColor3 = Color3.fromRGB(245, 226, 196), Text = "", TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	local change = WoodKit.Button(barWin.Body, "Green", { Size = UDim2.fromOffset(160, 64), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Text = "เปลี่ยน", TextSize = 28, ZIndex = 3 }, function()
		if current.Zone then
			picker.Visible = true
			UIKit.Pop(picker)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local lobby = Workspace:FindFirstChild("Lobby")
		local zone
		if root and lobby and not player:GetAttribute("InRun") then
			for i = 1, 8 do
				local z = lobby:FindFirstChild("MatchBox" .. i, true)
				if not z then
					break
				end
				if inside(z, root.Position) then
					zone = z
					break
				end
			end
		end
		if zone ~= current.Zone then
			current.Zone = zone
			bar.Visible = zone ~= nil
			picker.Visible = false
			if zone then
				UIKit.Pop(bar)
				-- หัวหน้าแท่นที่ยังไม่เคยเลือก: เปิดหน้าต่างเลือกให้เลย
				task.delay(0.25, function()
					if current.Zone == zone and zone:GetAttribute("Host") == player.UserId and not current.Picked[zone] then
						picker.Visible = true
						UIKit.Pop(picker)
					end
				end)
			end
		end
		if not zone then
			return
		end
		local size, count, cd = zone:GetAttribute("Size") or 4, zone:GetAttribute("Count") or 0, zone:GetAttribute("Countdown") or -1
		local host = zone:GetAttribute("Host") == player.UserId
		pickTitle.Text = "👥 แท่น " .. (zone:GetAttribute("PadIndex") or "") .. " · เลือกจำนวนผู้เล่น"
		status.Text = cd >= 0 and string.format("👥 %d/%d คน   •   ⏳ %d วิ", count, size, cd) or string.format("👥 %d/%d คน", count, size)
		sub.Text = count >= size and "ทีมครบแล้ว! กำลังออกเดินทาง" or (host and "คุณเป็นหัวหน้าแท่น · รอเพื่อนหรือรอหมดเวลา" or "รอหัวหน้าแท่น / รอเพื่อน")
		change.Visible = host
		for n, b in ipairs(pickButtons) do
			local style = n == size and "Green" or "Parch"
			if b:GetAttribute("Style") ~= style then
				WoodKit.Style(b, style)
			end
		end
	end)
end

return PadUI
