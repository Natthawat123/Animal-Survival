--[[
	MobileControls — ปุ่มบนจอสำหรับมือถือ/แท็บเล็ต (แทนปุ่มคีย์บอร์ดทั้งหมด)
	  ในแมพ  : 🔨 คราฟต์ (C) · 🏗 สร้าง (B) · 🎒 กระสอบ (Tab) · 🗺 แผนที่ (M) · 📤 เอาของออก (F)
	  โหมดสร้าง: ↻ หมุน (R) · ⇄ เปลี่ยนชนิด (Q) · ✔ วาง (คลิก) · ✕ ยกเลิก — เล็งด้วยกลางจอ (มีเป้าเล็ง)
	  ตี/ตัด = แตะจอตอนถือเครื่องมือ (ระบบ Tool ของ Roblox) · วิ่ง = ปุ่ม "วิ่ง" (ContextActionService) · เก็บของ = ปุ่ม E บนของ (แตะได้)
	  ล็อบบี้ใช้ปุ่มเมนูซ้ายมือ (คลาส/ป้าย/ร้านค้า/ตั้งค่า) ที่แตะได้อยู่แล้ว
	ขนาดปุ่มปรับได้ในหน้าตั้งค่า (TouchSize)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UIKit = require(script.Parent.UIKit)
local ClientSettings = require(script.Parent.ClientSettings)

local MobileControls = {}
local player = Players.LocalPlayer
local C = UIKit.Colors

function MobileControls.IsTouch()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function roundButton(parent, icon, label, color, size, onClick)
	local b = UIKit.ColorButton(parent, color, { Size = UDim2.fromOffset(size, size), Text = "", AutoButtonColor = false }, onClick)
	b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	UIKit.Text(b, { Size = UDim2.new(1, 0, 0.62, 0), Position = UDim2.fromScale(0, 0.06), Text = icon, TextSize = math.floor(size * 0.42), TextXAlignment = Enum.TextXAlignment.Center })
	UIKit.Text(b, { Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.62), Text = label, TextSize = math.floor(size * 0.2), Font = UIKit.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Center })
	return b
end

function MobileControls.Init(deps)
	local menus, map = deps.Menus, deps.Map
	if not MobileControls.IsTouch() then
		return
	end
	menus.TouchMode = true
	local gui = UIKit.Screen("MobileControls", 18)

	-- กลุ่มปุ่มหลัก: เหนือปุ่มกระโดดของ Roblox (มุมขวาล่าง)
	local main = UIKit.Frame(gui, { Size = UDim2.fromOffset(250, 250), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -150), BackgroundTransparency = 1 })
	local scale = Instance.new("UIScale")
	scale.Parent = main
	local S = 68
	local function at(b, x, y)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.new(1, -x, 1, -y)
	end
	at(roundButton(main, "🔨", "คราฟต์", C.Orange, S, menus.ToggleCraft), 40, 210)
	at(roundButton(main, "🏗", "สร้าง", C.Blue, S, menus.ToggleBuildPicker), 120, 180)
	at(roundButton(main, "🎒", "กระสอบ", C.Green, S, function()
		menus.ToggleBag()
	end), 190, 120)
	at(roundButton(main, "🗺", "แผนที่", C.Purple, S, function()
		if map and map.Toggle then
			map.Toggle()
		end
	end), 215, 40)
	local drop = roundButton(main, "📤", "เอาออก", C.Pink, S - 8, function()
		Remotes.Get("DropItem"):FireServer(nil, 1)
	end)
	at(drop, 40, 120)

	-- โหมดสร้าง: เป้าเล็งกลางจอ + แถบปุ่ม
	local cross = UIKit.Text(gui, { Size = UDim2.fromOffset(40, 40), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Text = "⊕", TextSize = 38, TextXAlignment = Enum.TextXAlignment.Center, Visible = false })
	local buildBar = UIKit.Frame(gui, { Size = UDim2.fromOffset(360, 84), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -170), BackgroundTransparency = 1, Visible = false })
	local bl = Instance.new("UIListLayout")
	bl.FillDirection = Enum.FillDirection.Horizontal
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bl.VerticalAlignment = Enum.VerticalAlignment.Center
	bl.Padding = UDim.new(0, 12)
	bl.Parent = buildBar
	local bscale = Instance.new("UIScale")
	bscale.Parent = buildBar
	roundButton(buildBar, "↻", "หมุน", C.Blue, 72, menus.RotateBuild).LayoutOrder = 1
	roundButton(buildBar, "⇄", "เปลี่ยน", C.Purple, 72, menus.CycleBuild).LayoutOrder = 2
	roundButton(buildBar, "✔", "วาง", C.Green, 80, menus.PlaceBuild).LayoutOrder = 3
	roundButton(buildBar, "✕", "ยกเลิก", C.Red, 72, menus.StopBuild).LayoutOrder = 4

	local function applySize()
		local k = ClientSettings.Get("TouchSize") or 1
		local vp = workspace.CurrentCamera.ViewportSize
		local auto = math.clamp(vp.Y / 500, 0.7, 1.1)
		scale.Scale = k * auto
		bscale.Scale = k * auto
	end
	applySize()
	ClientSettings.OnChanged(function(key)
		if key == "TouchSize" then
			applySize()
		end
	end)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applySize)

	-- โชว์/ซ่อนตามสถานะ (ในแมพ / ล้ม / ตาย / กำลังสร้าง)
	local holding = false
	local function refresh()
		local inRun = player:GetAttribute("InRun") == true
		local out = player:GetAttribute("Downed") or player:GetAttribute("Dead")
		local building = menus.IsBuilding()
		main.Visible = inRun and not out and not building
		drop.Visible = holding
		buildBar.Visible = inRun and not out and building
		cross.Visible = buildBar.Visible
	end
	-- ปุ่ม "เอาออก" เฉพาะตอนถือกระสอบ
	local function watchTools(container)
		container.ChildAdded:Connect(function(t)
			if t:IsA("Tool") and t:GetAttribute("Kind") == "Sack" and container == player.Character then
				holding = true
				refresh()
			end
		end)
		container.ChildRemoved:Connect(function(t)
			if t:IsA("Tool") and t:GetAttribute("Kind") == "Sack" and container == player.Character then
				holding = false
				refresh()
			end
		end)
	end
	player.CharacterAdded:Connect(function(c)
		holding = false
		watchTools(c)
		refresh()
	end)
	if player.Character then
		watchTools(player.Character)
	end
	for _, a in ipairs({ "InRun", "Downed", "Dead" }) do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	task.spawn(function()
		while gui.Parent do
			task.wait(0.25)
			refresh()
		end
	end)
	refresh()
end

return MobileControls
