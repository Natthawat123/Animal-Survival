--[[
	RejoinUI — หน้าต่าง "กลับเข้ารอบเดิม?" ในล็อบบี้ (หลุด/ออกเกมกลางรอบ ภายใน 1 ชม.)
	  server ส่ง RejoinOffer { Left = วินาที } -> โชว์เวลาที่เหลือนับถอยหลัง
	  ปุ่ม "กลับเข้ารอบ" / "ไม่ล่ะ" -> RejoinAnswer(true/false) (ปุ่มใหญ่ กดด้วยนิ้วได้)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UIKit = require(script.Parent.UIKit)

local RejoinUI = {}
local player = Players.LocalPlayer
local C = UIKit.Colors
local ui = {}
local deadline = 0
local token = 0

local function fmt(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function close()
	token += 1
	if ui.Panel then
		ui.Panel.Visible = false
	end
end

local function build()
	if ui.Panel then
		return
	end
	local gui = UIKit.Screen("Rejoin", 55)
	local panel = UIKit.Card(gui, { Size = UDim2.fromOffset(480, 250), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Visible = false })
	UIKit.Header(panel, "↩ กลับเข้ารอบเดิม?", C.Purple)
	UIKit.Text(panel, {
		Size = UDim2.new(1, -40, 0, 56), Position = UDim2.fromOffset(20, 36), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextSize = 18,
		Text = "คุณหลุดออกจากรอบที่ทีมยังเล่นอยู่ — กลับไปเล่นต่อพร้อมของเดิมได้",
	})
	ui.Time = UIKit.Text(panel, { Size = UDim2.new(1, -40, 0, 30), Position = UDim2.fromOffset(20, 96), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 22, Font = UIKit.Fonts.Title, TextColor3 = C.Gold, Text = "" })
	local row = UIKit.Frame(panel, { Size = UDim2.new(1, -40, 0, 56), Position = UDim2.new(0, 20, 1, -76), BackgroundTransparency = 1 })
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Padding = UDim.new(0, 16)
	l.Parent = row
	ui.Yes = UIKit.ColorButton(row, C.Green, { Size = UDim2.fromOffset(200, 54), Text = "✔ กลับเข้ารอบ", TextSize = 20, Font = UIKit.Fonts.Title }, function()
		close()
		Remotes.Get("RejoinAnswer"):FireServer(true)
	end)
	UIKit.ColorButton(row, C.Red, { Size = UDim2.fromOffset(160, 54), Text = "✕ ไม่ล่ะ", TextSize = 20, Font = UIKit.Fonts.Title }, function()
		close()
		Remotes.Get("RejoinAnswer"):FireServer(false)
	end)
	ui.Panel = panel
end

local function open(data)
	if type(data) ~= "table" or player:GetAttribute("InRun") then
		return
	end
	build()
	deadline = os.clock() + math.max(0, tonumber(data.Left) or 0)
	ui.Panel.Visible = true
	UIKit.Pop(ui.Panel)
	token += 1
	local my = token
	task.spawn(function()
		while my == token and ui.Panel.Visible do
			local left = deadline - os.clock()
			if left <= 0 then
				close()
				break
			end
			ui.Time.Text = "⏳ เหลือเวลา " .. fmt(left)
			task.wait(0.5)
		end
	end)
end

function RejoinUI.Init()
	Remotes.Get("RejoinOffer").OnClientEvent:Connect(open)
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		if player:GetAttribute("InRun") then
			close()
		end
	end)
end

return RejoinUI
