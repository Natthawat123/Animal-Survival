--[[
	PadUI — ยืนบนแท่นเริ่มเกมในล็อบบี้ -> แผงเลือกจำนวนคน 1-8 + สถานะทีม + นับถอยหลัง
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
	local panel = UIKit.Card(gui, { Size = UDim2.fromOffset(560, 210), Position = UDim2.new(0.5, -280, 1, -260), Visible = false })
	local _, title = UIKit.Header(panel, "แท่นเริ่มเกม", C.Green)
	local status = UIKit.Text(panel, { Size = UDim2.new(1, -40, 0, 26), Position = UDim2.fromOffset(22, 34), Font = UIKit.Fonts.Title, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, Text = "" })
	local hint = UIKit.Text(panel, { Size = UDim2.new(1, -40, 0, 18), Position = UDim2.fromOffset(22, 64), TextSize = 15, TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Text = "เลือกจำนวนผู้เล่นในทีม" })
	local row = UIKit.Frame(panel, { Size = UDim2.new(1, -44, 0, 56), Position = UDim2.fromOffset(22, 94), BackgroundTransparency = 1 })
	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Horizontal
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lay.Padding = UDim.new(0, 10)
	lay.Parent = row
	local current = { Zone = nil }
	local buttons = {}
	for n = 1, 8 do
		local b = UIKit.Button(row, { Size = UDim2.fromOffset(54, 54), Text = tostring(n), TextSize = 28, Font = UIKit.Fonts.Title, LayoutOrder = n }, function()
			if current.Zone then
				Remotes.Get("PadSize"):FireServer(current.Zone:GetAttribute("PadIndex"), n)
			end
		end)
		UIKit.Corner(b, 14)
		buttons[n] = b
	end
	local people = UIKit.Text(panel, { Size = UDim2.new(1, -44, 0, 22), Position = UDim2.fromOffset(22, 166), TextSize = 16, Font = UIKit.Fonts.Black, TextColor3 = Color3.fromRGB(150, 240, 160), TextXAlignment = Enum.TextXAlignment.Center, Text = "" })
	local shownAt = 0
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
			if zone then
				panel.Visible = true
				UIKit.Pop(panel)
				shownAt = os.clock()
			else
				panel.Visible = false
			end
		end
		if not zone then
			return
		end
		local size, count, cd = zone:GetAttribute("Size") or 4, zone:GetAttribute("Count") or 0, zone:GetAttribute("Countdown") or -1
		local host = zone:GetAttribute("Host") == player.UserId
		title.Text = "แท่นเริ่มเกม " .. (zone:GetAttribute("PadIndex") or "")
		status.Text = cd >= 0 and string.format("👥 %d/%d คน  ·  ⏳ ออกเดินทางใน %d วินาที", count, size, cd) or string.format("👥 %d/%d คน", count, size)
		hint.Text = host and "คุณเป็นหัวหน้าแท่น · เลือกจำนวนผู้เล่นในทีม (คนครบ = ออกเร็วขึ้น)" or "หัวหน้าแท่นเป็นคนเลือกจำนวนผู้เล่น"
		for n, b in ipairs(buttons) do
			local on = n == size
			b.BackgroundColor3 = on and C.Green or (n <= count and C.Blue or Color3.fromRGB(66, 74, 120))
			b.TextColor3 = (on or host) and C.Text or C.TextDim
		end
		people.Text = count >= size and "ทีมครบแล้ว! เตรียมออกเดินทาง" or string.format("รอเพื่อนอีก %d คน · หรือรอหมดเวลาแล้วออกเดินทางเลย", size - count)
		local _ = shownAt
	end)
end

return PadUI
