--[[
	DeathClient — ฝั่งผู้เล่น: ล้ม / ตาย / ดูเพื่อน
	  ล้ม  : นอนราบ (เซิร์ฟเวอร์ตรึงตัว) ซ่อนแถบไอเทม + ปิดปุ่ม E ทั้งหมด จนกว่าจะมีคนช่วย
	  ตาย  : ไม่เกิดใหม่ในรอบนี้ — กล้องตามเพื่อนที่ยังรอด (◀ ▶ สลับคน) + ปุ่ม "กลับล็อบบี้"
	  ทีมล้ม/ตายหมด = เซิร์ฟเวอร์จบเกมเอง (ALL HAVE PERISHED -> กลับล็อบบี้หลัก)
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UIKit = require(script.Parent.UIKit)

local DeathClient = {}
local player = Players.LocalPlayer
local C = UIKit.Colors
local ui = {}
local target -- ผู้เล่นที่กำลังดูอยู่

local function setBackpack(on)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, on)
	end)
end

-- คนที่ยังอยู่ในรอบและยังไม่ตาย (ล้มอยู่ก็ดูได้)
local function candidates()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p:GetAttribute("InRun") and not p:GetAttribute("Dead") then
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				table.insert(list, p)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

local function watch(p)
	target = p
	local cam = Workspace.CurrentCamera
	local hum = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = hum
		ui.Name.Text = "👁 กำลังดู: " .. p.DisplayName .. (p:GetAttribute("Downed") and "  (ล้มอยู่!)" or "")
	else
		ui.Name.Text = "ไม่มีเพื่อนเหลือรอด... รอผลรอบนี้"
	end
end

local function cycle(dir)
	local list = candidates()
	if #list == 0 then
		watch(nil)
		return
	end
	local i = table.find(list, target) or 0
	i = (i - 1 + dir) % #list + 1
	watch(list[i])
end

function DeathClient.StartSpectate(d)
	ui.Spectate.Visible = true
	UIKit.Pop(ui.Spectate)
	ui.Sub.Text = string.format("คุณสิ้นชีพในคืนที่ %d — รอดูเพื่อนเอาชีวิตรอดต่อ หรือกลับล็อบบี้", d and d.Night or 1)
	setBackpack(false)
	ProximityPromptService.Enabled = false
	task.delay(3.5, function()
		if ui.Spectate.Visible then
			cycle(1)
		end
	end)
end

function DeathClient.StopSpectate()
	if not ui.Spectate then
		return
	end
	ui.Spectate.Visible = false
	target = nil
	local cam = Workspace.CurrentCamera
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraSubject = hum
	end
	cam.CameraType = Enum.CameraType.Custom
	setBackpack(true)
	ProximityPromptService.Enabled = true
end

local function onDowned()
	local downed = player:GetAttribute("Downed") == true
	if downed then
		setBackpack(false)
		ProximityPromptService.Enabled = false
	elseif not player:GetAttribute("Dead") then
		setBackpack(true)
		ProximityPromptService.Enabled = true
	end
end

function DeathClient.Init()
	local gui = UIKit.Screen("Spectate", 35)
	local bar = UIKit.Card(gui, {
		Size = UDim2.fromOffset(620, 128), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), BackgroundTransparency = 0.08, Visible = false,
	})
	ui.Spectate = bar
	UIKit.Header(bar, "☠ คุณเสียชีวิต", C.Blood)
	ui.Name = UIKit.Text(bar, { Size = UDim2.new(1, -150, 0, 30), Position = UDim2.new(0, 75, 0, 32), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title, TextSize = 24, Text = "" })
	ui.Sub = UIKit.Text(bar, { Size = UDim2.new(1, -40, 0, 20), Position = UDim2.new(0, 20, 0, 64), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 15, TextColor3 = C.TextDim, Text = "" })
	local prev = UIKit.ColorButton(bar, C.Blue, { Size = UDim2.fromOffset(56, 48), Position = UDim2.fromOffset(14, 26), Text = "◀", TextSize = 26 }, function()
		cycle(-1)
	end)
	local nextB = UIKit.ColorButton(bar, C.Blue, { Size = UDim2.fromOffset(56, 48), Position = UDim2.new(1, -70, 0, 26), Text = "▶", TextSize = 26 }, function()
		cycle(1)
	end)
	local leave = UIKit.ColorButton(bar, C.Orange, { Size = UDim2.fromOffset(220, 34), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 88), Text = "🏠 กลับล็อบบี้", TextSize = 18 }, function()
		Remotes.Get("LeaveRun"):FireServer()
	end)
	local _ = prev and nextB and leave

	player:GetAttributeChangedSignal("Downed"):Connect(onDowned)
	-- เกิดใหม่ (กลับล็อบบี้/เริ่มรอบใหม่) = เลิกดูเพื่อน
	player:GetAttributeChangedSignal("Dead"):Connect(function()
		if not player:GetAttribute("Dead") then
			DeathClient.StopSpectate()
		end
	end)
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		if not player:GetAttribute("InRun") then
			DeathClient.StopSpectate()
		end
	end)
	player.CharacterAdded:Connect(function()
		if not player:GetAttribute("Dead") then
			DeathClient.StopSpectate()
		end
	end)
	-- คนที่ดูอยู่ตาย/ออก -> สลับไปคนถัดไปเอง
	task.spawn(function()
		while true do
			task.wait(1)
			if ui.Spectate.Visible then
				if not target or not target.Parent or target:GetAttribute("Dead") or not target:GetAttribute("InRun") then
					cycle(1)
				elseif target then
					ui.Name.Text = "👁 กำลังดู: " .. target.DisplayName .. (target:GetAttribute("Downed") and "  (ล้มอยู่!)" or "")
				end
			end
		end
	end)
end

return DeathClient
