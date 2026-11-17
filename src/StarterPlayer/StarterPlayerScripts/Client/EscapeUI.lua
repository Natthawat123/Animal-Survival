--[[
	EscapeUI — หน้าต่างโหวต "กลับบ้านผ่านประตูมิติไหม?" (หลังรอดครบ 99 คืน · EscapeService)
	  server ส่ง EscapeVote { Id, Left, Yes, No, Total, By, Mine } ทุกครั้งที่มีคนโหวต
	    -> แสดงเวลาที่เหลือ + แถบเสียง เห็นด้วย/ไม่เห็นด้วย · ปุ่มใหญ่กดด้วยนิ้วได้ · คีย์บอร์ด Y / N
	  { Id, Done = "Yes"/"No" } -> โชว์ผล 2.5 วิ แล้วปิด
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UIKit = require(script.Parent.UIKit)

local EscapeUI = {}
local player = Players.LocalPlayer
local C = UIKit.Colors
local GOLD = Color3.fromRGB(255, 214, 130)
local ui = {}
local cur -- payload ล่าสุด
local deadline = 0
local token = 0

local function vote(yes)
	if not cur or cur.Done or cur.Mine then
		return
	end
	cur.Mine = yes and "Yes" or "No" -- กดซ้ำไม่ได้ (รอเซิร์ฟเวอร์ส่งยอดใหม่)
	Remotes.Get("EscapeVote"):FireServer(cur.Id, yes)
	EscapeUI.Refresh()
end

local function build()
	if ui.Panel then
		return
	end
	local gui = UIKit.Screen("EscapeVote", 56)
	local panel = UIKit.Card(gui, {
		Name = "EscapeVotePanel", Size = UDim2.fromOffset(520, 286), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Visible = false,
	})
	UIKit.AutoScale(panel)
	UIKit.Header(panel, "🌀 Go home?", Color3.fromRGB(214, 160, 60))
	ui.Sub = UIKit.Text(panel, {
		Size = UDim2.new(1, -40, 0, 52), Position = UDim2.fromOffset(20, 34), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextSize = 18,
		Text = "",
	})
	ui.Time = UIKit.Text(panel, {
		Size = UDim2.new(1, -40, 0, 26), Position = UDim2.fromOffset(20, 88), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 20,
		Font = UIKit.Fonts.Title, TextColor3 = GOLD, Text = "",
	})
	-- แถบเสียง: เขียว (ไป) ซ้าย · แดง (อยู่) ขวา · เส้นกลาง = ต้องเกินครึ่ง
	local bar = UIKit.Frame(panel, {
		Size = UDim2.new(1, -60, 0, 22), Position = UDim2.fromOffset(30, 122), BackgroundColor3 = Color3.fromRGB(20, 22, 36), BackgroundTransparency = 0,
	})
	UIKit.Corner(bar, 8)
	UIKit.Stroke(bar, C.Outline, 2)
	ui.YesFill = UIKit.Frame(bar, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Green, BackgroundTransparency = 0 })
	UIKit.Corner(ui.YesFill, 8)
	ui.NoFill = UIKit.Frame(bar, { Size = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), BackgroundColor3 = C.Red, BackgroundTransparency = 0 })
	UIKit.Corner(ui.NoFill, 8)
	UIKit.Frame(bar, { Size = UDim2.new(0, 3, 1, 8), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.2, ZIndex = 4 })
	ui.Tally = UIKit.Text(panel, {
		Size = UDim2.new(1, -40, 0, 24), Position = UDim2.fromOffset(20, 148), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 17, TextColor3 = C.TextDim, Text = "",
	})
	local row = UIKit.Frame(panel, { Size = UDim2.new(1, -40, 0, 60), Position = UDim2.new(0, 20, 1, -80), BackgroundTransparency = 1 })
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Padding = UDim.new(0, 16)
	l.Parent = row
	ui.Yes = UIKit.ColorButton(row, C.Green, { Size = UDim2.fromOffset(220, 58), Text = "✔ Go home (Y)", TextSize = 20, Font = UIKit.Fonts.Title }, function()
		vote(true)
	end)
	ui.No = UIKit.ColorButton(row, C.Red, { Size = UDim2.fromOffset(220, 58), Text = "✕ Keep playing (N)", TextSize = 20, Font = UIKit.Fonts.Title }, function()
		vote(false)
	end)
	ui.Result = UIKit.Text(panel, {
		Size = UDim2.new(1, -40, 0, 60), Position = UDim2.new(0, 20, 1, -80), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 24,
		Font = UIKit.Fonts.Title, Text = "", Visible = false,
	})
	ui.Row = row
	ui.Panel = panel
end

local function fmt(sec)
	return string.format("%d", math.max(0, math.ceil(sec)))
end

function EscapeUI.Refresh()
	if not (cur and ui.Panel) then
		return
	end
	local total = math.max(1, cur.Total or 1)
	ui.YesFill.Size = UDim2.fromScale(math.clamp((cur.Yes or 0) / total, 0, 1), 1)
	ui.NoFill.Size = UDim2.fromScale(math.clamp((cur.No or 0) / total, 0, 1), 1)
	ui.Tally.Text = string.format("Go home %d · Stay %d · Team %d (majority wins)", cur.Yes or 0, cur.No or 0, cur.Total or 0)
	if cur.Done then
		ui.Row.Visible = false
		ui.Result.Visible = true
		ui.Time.Text = ""
		if cur.Done == "Yes" then
			ui.Result.Text = "🏠 The team is going home!"
			ui.Result.TextColor3 = C.Good
		else
			ui.Result.Text = "🌲 The team stays — endless mode continues"
			ui.Result.TextColor3 = C.TextDim
		end
		return
	end
	ui.Row.Visible = cur.Mine == nil
	ui.Result.Visible = cur.Mine ~= nil
	if cur.Mine then
		ui.Result.Text = cur.Mine == "Yes" and "You voted: Go home ✔" or "You voted: Keep playing ✕"
		ui.Result.TextColor3 = cur.Mine == "Yes" and C.Good or C.Bad
	end
end

local function close()
	token += 1
	cur = nil
	if ui.Panel then
		ui.Panel.Visible = false
	end
end

local function onVote(d)
	if type(d) ~= "table" then
		return
	end
	build()
	if d.Done then
		if not cur or cur.Id ~= d.Id then
			cur = { Id = d.Id }
		end
		cur.Done, cur.Yes, cur.No = d.Done, d.Yes or cur.Yes, d.No or cur.No
		EscapeUI.Refresh()
		local my = token
		task.delay(2.5, function()
			if my == token then
				close()
			end
		end)
		return
	end
	local fresh = not (cur and cur.Id == d.Id and ui.Panel.Visible)
	cur = d
	deadline = os.clock() + (tonumber(d.Left) or 0)
	ui.Sub.Text = string.format("%s opened the portal vote · If most of the team agrees, the run ends with a cutscene and everyone returns to the lobby", d.By or "Someone")
	EscapeUI.Refresh()
	if fresh then
		ui.Panel.Visible = true
		UIKit.Pop(ui.Panel)
		token += 1
		local my = token
		task.spawn(function()
			while my == token and ui.Panel.Visible do
				if cur and not cur.Done then
					ui.Time.Text = "⏳ " .. fmt(deadline - os.clock()) .. "s"
				end
				task.wait(0.25)
			end
		end)
	end
end

function EscapeUI.Init()
	Remotes.Get("EscapeVote").OnClientEvent:Connect(onVote)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not (ui.Panel and ui.Panel.Visible) then
			return
		end
		if input.KeyCode == Enum.KeyCode.Y then
			vote(true)
		elseif input.KeyCode == Enum.KeyCode.N then
			vote(false)
		end
	end)
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		if not player:GetAttribute("InRun") then
			close()
		end
	end)
end

return EscapeUI
