--[[
	PadUI — ยืนบนแท่นเริ่มเกมในล็อบบี้
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

local PadUI = {}
local player = Players.LocalPlayer
local C = UIKit.Colors

local function inside(zone, pos)
	local rel = zone.CFrame:PointToObjectSpace(pos)
	return math.abs(rel.X) < zone.Size.X / 2 and math.abs(rel.Y) < zone.Size.Y / 2 and math.abs(rel.Z) < zone.Size.Z / 2
end

function PadUI.Init()
	local gui = UIKit.Screen("PadUI", 30)

	-------------------------------------------------- หน้าต่างเลือกจำนวน (กลางจอ)
	local picker = UIKit.Card(gui, { Size = UDim2.fromOffset(560, 250), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Visible = false })
	UIKit.AutoScale(picker)
	local _, pickTitle = UIKit.Header(picker, "👥 เลือกจำนวนผู้เล่น", C.Green)
	UIKit.Text(picker, { Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 36), TextSize = 17, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Text = "ทีมจะออกเดินทางเมื่อคนครบ หรือเมื่อหมดเวลา" })
	local grid = UIKit.Frame(picker, { Size = UDim2.new(1, -40, 0, 140), Position = UDim2.fromOffset(20, 70), BackgroundTransparency = 1 })
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(112, 60)
	gl.CellPadding = UDim2.fromOffset(14, 14)
	gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	local current = { Zone = nil, Picked = {} }
	local function close()
		picker.Visible = false
	end
	UIKit.CloseButton(picker, close)
	local pickButtons = {}
	for n = 1, 8 do
		local b = UIKit.ColorButton(grid, Color3.fromRGB(58, 66, 104), { Text = n == 1 and "1 (เดี่ยว)" or (n .. " คน"), TextSize = 22, Font = UIKit.Fonts.Title, LayoutOrder = n }, function()
			if current.Zone then
				Remotes.Get("PadSize"):FireServer(current.Zone:GetAttribute("PadIndex"), n)
				current.Picked[current.Zone] = true
			end
			close() -- เลือกแล้วปิดทันที ไปรอคน/รอเวลาที่แถบด้านบน
		end)
		pickButtons[n] = b
	end

	-------------------------------------------------- แถบสถานะ (ด้านบนจอ ใต้ชื่อค่าย)
	local bar = UIKit.Card(gui, { Size = UDim2.fromOffset(440, 64), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 92), Visible = false })
	UIKit.AutoScale(bar)
	local status = UIKit.Text(bar, { Size = UDim2.new(1, -140, 0, 30), Position = UDim2.fromOffset(18, 6), Font = UIKit.Fonts.Title, TextSize = 24, Text = "" })
	local sub = UIKit.Text(bar, { Size = UDim2.new(1, -140, 0, 20), Position = UDim2.fromOffset(18, 36), TextSize = 15, TextColor3 = C.TextDim, Text = "" })
	local change = UIKit.ColorButton(bar, C.Blue, { Size = UDim2.fromOffset(104, 42), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Text = "เปลี่ยน", TextSize = 19, Font = UIKit.Fonts.Title }, function()
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
		status.Text = cd >= 0 and string.format("👥 %d/%d คน  ·  ⏳ %d วิ", count, size, cd) or string.format("👥 %d/%d คน", count, size)
		sub.Text = count >= size and "ทีมครบแล้ว! กำลังออกเดินทาง" or (host and "คุณเป็นหัวหน้าแท่น · รอเพื่อนหรือรอหมดเวลา" or "รอหัวหน้าแท่น / รอเพื่อน")
		change.Visible = host
		for n, b in ipairs(pickButtons) do
			b.BackgroundColor3 = n == size and C.Green or Color3.fromRGB(58, 66, 104)
		end
	end)
end

return PadUI
