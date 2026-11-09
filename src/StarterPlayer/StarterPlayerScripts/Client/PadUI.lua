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

function PadUI.Init()
	local gui = UIKit.Screen("PadUI", 30)

	-------------------------------------------------- หน้าต่างเลือกจำนวน (กลางจอ) · ธีมกรอบไม้
	local current = { Zone = nil, PickedAt = nil, Dismissed = false }
	local leaveGroup -- ตั้งค่าด้านล่าง (ปุ่มออกจากกลุ่ม)
	local function close()
		current.PickerFrame.Visible = false
		-- ปิดหน้าต่างเองโดยยังไม่เลือก = ไม่เด้งซ้ำ (เลือกได้จากปุ่ม "เลือก" บนแถบ หรือกด "ออกจากกลุ่ม")
		if not current.PickedAt then
			current.Dismissed = true
		end
	end
	local win = WoodKit.Window(gui, { Name = "PadPicker", Size = Vector2.new(780, 330), Title = "Choose Team Size", TitleWidth = 470, BannerHeight = 120, OnClose = close })
	local picker = win.Frame
	current.PickerFrame = picker
	picker.Position = UDim2.fromScale(0.5, 0.52)
	UIKit.AutoScale(picker)
	local pickTitle = win.Title
	UIKit.Text(win.Body, { Size = UDim2.new(1, -60, 0, 24), Position = UDim2.fromOffset(30, 46), TextSize = 18, TextColor3 = WoodKit.Colors.Gold, TextXAlignment = Enum.TextXAlignment.Center, Text = "—  The team departs when full, or when time runs out  —" })
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
		local b = WoodKit.Button(grid, "Parch", { Text = n == 1 and "1 (Solo)" or (n .. " players"), TextSize = 26, LayoutOrder = n }, function()
			if current.Zone then
				Remotes.Get("PadSize"):FireServer(current.Zone:GetAttribute("PadIndex"), n)
				current.PickedAt = os.clock()
			end
			close() -- เลือกแล้วปิดทันที ไปรอคน/รอเวลาที่แถบด้านบน
		end)
		-- หมุดทองกลางขอบบน (แบบป้ายไม้ในภาพอ้างอิง)
		local stud = WoodKit.Frame(b, { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Rotation = 45, BackgroundColor3 = WoodKit.Colors.Gold, ZIndex = 3 })
		WoodKit.Stroke(stud, WoodKit.Colors.WoodDark, 1.5, 0)
		pickButtons[n] = b
	end

	-------------------------------------------------- ปุ่มออกจากกลุ่ม (ขึ้นแท่นแล้วเดินออกเองไม่ได้ ต้องกดปุ่มนี้)
	local leave -- สร้างหลังแถบสถานะ (เป็นลูกของแถบ โชว์/ซ่อนตามกัน)

	-------------------------------------------------- แถบสถานะ (ด้านบนจอ ใต้ชื่อค่าย) · ป้ายไม้ + หมาป่า/อินทรี + ตราอุ้งเท้า
	local barWin = WoodKit.Window(gui, { Name = "PadBar", Size = Vector2.new(640, 104), Plaque = false, Lanterns = false, TitleWidth = 436, BannerHeight = 72 })
	local bar = barWin.Frame
	bar.AnchorPoint = Vector2.new(0.5, 0)
	local function placeBar()
		bar.Position = UDim2.new(0.5, 0, 0, 104 * UIKit.BigScale())
	end
	placeBar()
	UIKit.OnResize(placeBar)
	UIKit.AutoScale(bar)
	WoodKit.Medallion(bar, "🐾", 52, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), ZIndex = 12 }, Color3.fromRGB(110, 70, 34))
	local info = WoodKit.Board(barWin.Body, { Size = UDim2.new(1, -206, 1, -30), Position = UDim2.fromOffset(18, 15), ZIndex = 2 }, Color3.fromRGB(96, 30, 22), WoodKit.Colors.GoldDark)
	local status = UIKit.Text(info, { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(12, 4), Font = UIKit.Fonts.Title, TextSize = 28, Text = "", TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	local sub = UIKit.Text(info, { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(12, 40), TextSize = 16, TextColor3 = Color3.fromRGB(245, 226, 196), Text = "", TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	local change = WoodKit.Button(barWin.Body, "Green", { Size = UDim2.fromOffset(160, 64), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Text = "Switch", TextSize = 28, ZIndex = 3 }, function()
		if current.Zone then
			picker.Visible = true
			UIKit.Pop(picker)
		end
	end)

	-- กดออก: หยุดคุมวงทันที (ไม่งั้นระหว่างรอ attribute Pad ถูกลบ วงจะดึงตัวกลับเข้าแท่น แล้วถูกจับเข้ากลุ่มใหม่)
	local leftAt = -10
	leaveGroup = function()
		leftAt = os.clock()
		bar.Visible = false
		picker.Visible = false
		Remotes.Get("LeavePad"):FireServer()
	end
	leave = WoodKit.Button(bar, "Red", { Size = UDim2.fromOffset(230, 56), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 10), Text = "Leave Group", TextSize = 26, ZIndex = 3 }, leaveGroup)

	-- เล่นต่อจากเซฟ (หัวหน้าแท่นที่มี Save Run และมีรอบที่เซฟไว้)
	local resumeBtn = WoodKit.Button(bar, "Green", { Size = UDim2.fromOffset(230, 56), AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0.5, 125, 1, 10), Text = "", TextSize = 22, ZIndex = 3, Visible = false }, function()
		if current.Zone then
			Remotes.Get("PadResume"):FireServer(current.Zone:GetAttribute("PadIndex"), current.Zone:GetAttribute("ResumeNight") == nil)
		end
	end)

	-- อยู่ในกลุ่มแท่น (เซิร์ฟเวอร์ตั้ง attribute Pad) = คุมตัวละครไว้ในวง เดินชนขอบวงแล้วออกไม่ได้
	local PAD_R = 8.6
	RunService.PreSimulation:Connect(function()
		if os.clock() - leftAt < 2 then
			return
		end
		local pad = player:GetAttribute("Pad")
		local root = pad and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local lobby = root and Workspace:FindFirstChild("Lobby")
		local z = lobby and lobby:FindFirstChild("MatchBox" .. pad, true)
		if not z then
			return
		end
		local c = z.Position
		local off = (root.Position - c) * Vector3.new(1, 0, 1)
		local d = off.Magnitude
		if d > PAD_R then
			local dir = off / d
			local p = c + dir * PAD_R
			root.CFrame = CFrame.new(p.X, root.Position.Y, p.Z) * root.CFrame.Rotation
			local v = root.AssemblyLinearVelocity
			local out = v:Dot(dir)
			if out > 0 then
				root.AssemblyLinearVelocity = v - dir * out
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		local lobby = Workspace:FindFirstChild("Lobby")
		local pad = not player:GetAttribute("InRun") and player:GetAttribute("Pad")
		local zone = pad and lobby and lobby:FindFirstChild("MatchBox" .. pad, true) or nil
		if zone ~= current.Zone then
			current.Zone = zone
			current.PickedAt = nil
			current.Dismissed = false
			bar.Visible = zone ~= nil
			picker.Visible = false
			if zone then
				UIKit.Pop(bar)
			end
		end
		if not zone then
			return
		end
		-- หัวหน้าแท่นที่ยังไม่เลือกจำนวน (เช็กจากเซิร์ฟเวอร์ทุกเฟรม ไม่จำค่าเก่าของรอบก่อน): เปิดหน้าต่างเลือกเสมอ
		--   เพิ่งกดเลือก = รอเซิร์ฟเวอร์ตอบ 2 วิ ไม่เด้งซ้ำ
		if current.PickedAt and zone:GetAttribute("Picked") == true then
			current.PickedAt = nil
		end
		if not picker.Visible and not current.Dismissed and zone:GetAttribute("Host") == player.UserId and zone:GetAttribute("Picked") ~= true
			and os.clock() - (current.PickedAt or -99) > 2 and os.clock() - leftAt > 2 then
			current.PickedAt = nil
			picker.Visible = true
			UIKit.Pop(picker)
		end
		-- เปิดหน้าต่างเลือกจำนวนอยู่ = ซ่อนแถบสถานะ+ปุ่มออก (จอมือถือเตี้ย สองอันซ้อนทับกันจนอ่านไม่ออก)
		local showBar = not picker.Visible and os.clock() - leftAt > 1.5
		if bar.Visible ~= showBar then
			bar.Visible = showBar
		end
		local size, count, cd = zone:GetAttribute("Size") or 4, zone:GetAttribute("Count") or 0, zone:GetAttribute("Countdown") or -1
		local host = zone:GetAttribute("Host") == player.UserId
		local picked = zone:GetAttribute("Picked") == true
		pickTitle.Text = "Pad " .. (zone:GetAttribute("PadIndex") or "") .. " · Choose team size"
		if not picked then
			-- ยังไม่เลือกจำนวน = ยังไม่นับเวลา
			status.Text = string.format("%d players on the pad", count)
			sub.Text = host and "Choose the team size first, then the countdown starts" or "Waiting for the pad leader to choose the team size..."
		else
			status.Text = cd >= 0 and string.format("%d/%d players   •   ⏳ %ds", count, size, cd) or string.format("%d/%d players", count, size)
			sub.Text = count >= size and "Team is full! Departing" or (host and "You're the pad leader · Wait for friends or for time to run out" or "Waiting for the pad leader / friends")
		end
		change.Visible = host
		-- เล่นต่อจากเซฟ
		local resumeNight = zone:GetAttribute("ResumeNight")
		local canResume = false -- แท่นธรรมดาไม่มีเล่นต่อจากเซฟแล้ว (โลกที่เซฟไว้เปิดจากเมนู Worlds)
		resumeBtn.Visible = canResume
		if canResume then
			local t = resumeNight and ("✔ Continue · Night " .. resumeNight) or ("Continue · Night " .. tostring(player:GetAttribute("SavedNight")))
			if resumeBtn.Text ~= t then
				resumeBtn.Text = t
			end
		end
		if resumeNight and picked then
			sub.Text = "Continuing the saved run from Night " .. resumeNight
		end
		if change.Text ~= (picked and "Switch" or "Choose") then
			change.Text = picked and "Switch" or "Choose"
		end
		for n, b in ipairs(pickButtons) do
			local style = (picked and n == size) and "Green" or "Parch" -- ยังไม่เลือก = ไม่ไฮไลต์ค่าเริ่มต้น
			if b:GetAttribute("Style") ~= style then
				WoodKit.Style(b, style)
			end
		end
	end)
end

return PadUI
