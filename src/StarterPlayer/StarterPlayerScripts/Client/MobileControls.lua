--[[
	MobileControls — ปุ่มบนจอสำหรับมือถือ/แท็บเล็ต (แทนปุ่มคีย์บอร์ดทั้งหมด)
	  วางเป็นวงรอบปุ่มกระโดดของ Roblox (มุมขวาล่าง) แบบเกมมือถือทั่วไป — ไม่ลอยทับกลางจอ ไม่ทับกันเอง
	    วิ่ง (แตะ = เปิด/ปิด) · เอาของออก (เฉพาะตอนถือกระสอบ) · ล็อกกล้อง — ปุ่มตัวหนังสือล้วน ไม่มีไอคอน
	    🗺 แผนที่ = ปุ่มเล็กข้างปุ่ม ⚙ ใต้การ์ดกองไฟ (มุมขวาบน)
	  โหมดสร้าง: ↻ หมุน · ⇄ เปลี่ยน · ✔ วาง · ✕ ยกเลิก (แถวล่างกลางจอ) — เล็งด้วยเป้ากลางจอ
	  ตี/ตัด = แตะจอตอนถือเครื่องมือ (ระบบ Tool ของ Roblox) · เก็บของ = แตะปุ่ม E บนของ
	ขนาดปุ่มปรับได้ในหน้าตั้งค่า (TouchSize) — ทุกปุ่มบนจอจริงไม่เล็กกว่า MIN_TOUCH (44px) เสมอ
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UIKit = require(script.Parent.UIKit)
local ClientSettings = require(script.Parent.ClientSettings)

local MobileControls = {}
local MIN_TOUCH = 44 -- ขนาดปุ่มเล็กสุดที่นิ้วกดได้สบาย (px บนจอจริง)
local player = Players.LocalPlayer
local C = UIKit.Colors

function MobileControls.IsTouch()
	return UIKit.IsTouch
end

-- ปุ่มกลม: ไอคอนใหญ่ + ชื่อเล็กใต้ไอคอน · icon = nil -> ตัวหนังสืออย่างเดียวกลางปุ่ม (ปุ่มรอบปุ่มกระโดด)
local function roundButton(parent, icon, label, color, onClick)
	local b = UIKit.ColorButton(parent, color, { Size = UDim2.fromOffset(52, 52), Text = "", AnchorPoint = Vector2.new(0.5, 0.5) }, onClick)
	b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	local ic, lb
	if icon then
		ic = UIKit.Text(b, { Size = UDim2.fromScale(1, 0.58), Position = UDim2.fromScale(0, 0.06), Text = icon, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center })
		lb = UIKit.Text(b, { Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.62), Text = label, TextScaled = true, Font = UIKit.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Center })
	else
		lb = UIKit.Text(b, { Size = UDim2.fromScale(1, 0.42), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Text = label, TextScaled = true, Font = UIKit.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Center })
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.1, 0), UDim.new(0.1, 0)
	pad.Parent = b
	return b, ic, lb
end

function MobileControls.Init(deps)
	local menus, map, hud, combat = deps.Menus, deps.Map, deps.HUD, deps.Combat
	if not MobileControls.IsTouch() then
		return
	end
	menus.TouchMode = true
	local gui = UIKit.Screen("MobileControls", 18)

	-- ปุ่มรอบปุ่มกระโดด (ตำแหน่งคำนวณใหม่ทุกครั้งที่จอเปลี่ยนขนาด)
	local ring = UIKit.Frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local sprint, _, sprintLabel = roundButton(ring, nil, "วิ่ง", C.Cyan, function()
		if combat then
			combat.SetSprint(not combat.IsSprinting())
		end
	end)
	-- คราฟต์ = กด E ที่โต๊ะ · สร้าง = เลือกของในแถบไอเทม · กระสอบ = ปุ่มกระเป๋ามุมขวาบน -> ไม่ต้องมีปุ่มซ้ำ
	local dropB = roundButton(ring, nil, "เอาออก", C.Pink, function()
		Remotes.Get("DropItem"):FireServer(nil, 1)
	end)
	-- 🔒 ล็อกกล้อง (Shift Lock แบบมือถือ): ตัวละครหันตามกล้องตลอด + กล้องเยื้องข้างไหล่ · ปัดจอหมุนกล้อง = หมุนตัว
	local RunService = game:GetService("RunService")
	local locked = false
	local lockB, _, lockLabel
	local function hum()
		local c = player.Character
		return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
	end
	local function setLock(on)
		locked = on
		local h = hum()
		if h then
			h.CameraOffset = on and Vector3.new(1.75, 0, 0) or Vector3.zero
			if not on and not (player:GetAttribute("Downed") or player:GetAttribute("Dead")) then
				h.AutoRotate = true
			end
		end
		if lockB then
			lockB.BackgroundColor3 = on and C.Gold or C.Blue
			lockLabel.Text = on and "ล็อกอยู่" or "ล็อก"
		end
	end
	lockB, _, lockLabel = roundButton(ring, nil, "ล็อก", C.Blue, function()
		setLock(not locked)
	end)
	RunService:BindToRenderStep("ASMobileLock", Enum.RenderPriority.Camera.Value + 1, function()
		if not locked then
			return
		end
		local h, root = hum()
		if not (h and root) or h.Health <= 0 or root.Anchored or player:GetAttribute("Downed") or player:GetAttribute("Dead") then
			return
		end
		h.AutoRotate = false
		h.CameraOffset = Vector3.new(1.75, 0, 0)
		local look = Workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + look.Unit)
		end
	end)
	player.CharacterAdded:Connect(function()
		task.defer(setLock, locked)
	end)
	-- φ = 0 (ซ้ายของปุ่มกระโดด) .. 90 (เหนือปุ่มกระโดด)
	local slots = {
		{ sprint, 1, 0 }, { dropB, 1, 60 }, { lockB, 2, 30 },
	}

	-- แผนที่: ปุ่มเล็กใต้ปุ่ม ⚙ ข้างการ์ดกองไฟ (มุมขวาบน ไม่กินพื้นที่ปุ่มหลัก)
	local mapB
	if hud and hud.RightCard then
		local function toggleMap()
			if map and map.Toggle then
				map.Toggle()
			end
		end
		mapB = UIKit.ColorButton(hud.RightCard, C.Purple, { Size = UDim2.fromOffset(48, 48), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0, -12, 0, 60), Text = "🗺", TextSize = 26 }, toggleMap)
		mapB:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
		-- การ์ดกองไฟถูกย่อตามจอ -> ขยายพื้นที่แตะให้ยังกดได้ ≥ 44px
		UIKit.EnsureTouchSize(mapB, MIN_TOUCH, toggleMap)
	end

	-- โหมดสร้าง: เป้าเล็งกลางจอ + แถบปุ่มล่างกลางจอ
	local cross = UIKit.Text(gui, { Size = UDim2.fromOffset(40, 40), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Text = "⊕", TextSize = 38, TextXAlignment = Enum.TextXAlignment.Center, Visible = false })
	local buildBar = UIKit.Frame(gui, { Size = UDim2.fromOffset(300, 66), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), BackgroundTransparency = 1, Visible = false }) -- เหนือแถบไอเทม 10 ช่อง
	local bl = Instance.new("UIListLayout")
	bl.FillDirection = Enum.FillDirection.Horizontal
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bl.VerticalAlignment = Enum.VerticalAlignment.Center
	bl.Padding = UDim.new(0, 10)
	bl.Parent = buildBar
	local bscale = Instance.new("UIScale")
	bscale.Parent = buildBar
	for i, spec in ipairs({ { "↻", "หมุน", C.Blue, menus.RotateBuild }, { "⇄", "เปลี่ยน", C.Purple, menus.CycleBuild }, { "✔", "วาง", C.Green, menus.PlaceBuild }, { "✕", "ยกเลิก", C.Red, menus.StopBuild } }) do
		local b = roundButton(buildBar, spec[1], spec[2], spec[3], spec[4])
		b.AnchorPoint = Vector2.new(0, 0)
		b.Size = UDim2.fromOffset(i == 3 and 64 or 56, i == 3 and 64 or 56)
		b.LayoutOrder = i
	end

	local function layout()
		local vp = UIKit.Viewport()
		local k = ClientSettings.Get("TouchSize") or 1
		local small = math.min(vp.X, vp.Y) <= 500
		-- ตำแหน่ง/ขนาดปุ่มกระโดดของ Roblox (TouchJump) นับจากมุมขวาล่าง
		local jx, jy, jr = 60, 55, 35
		if not small then
			jx, jy, jr = 110, 150, 60
		end
		local size = math.max(MIN_TOUCH, (small and 50 or 64) * k)
		local r1 = jr + size * 0.5 + 18 * k
		local r2 = r1 + size + 12 * k
		for _, sl in ipairs(slots) do
			local b, ringNo, phi = sl[1], sl[2], math.rad(sl[3])
			local r = ringNo == 1 and r1 or r2
			b.Size = UDim2.fromOffset(size, size)
			b.Position = UDim2.new(1, -(jx + r * math.cos(phi)), 1, -(jy + r * math.sin(phi)))
		end
		-- ปุ่มโหมดสร้างเล็กสุด 56px x สเกล -> ไม่ให้ต่ำกว่า 44px
		bscale.Scale = math.max(math.clamp(vp.Y / 420, 0.75, 1.15) * k, MIN_TOUCH / 56)
	end
	layout()
	ClientSettings.OnChanged(function(key)
		if key == "TouchSize" then
			layout()
		end
	end)
	UIKit.OnResize(layout)

	-- โชว์/ซ่อนตามสถานะ (ในแมพ / ล้ม / ตาย / กำลังสร้าง / ถือกระสอบ)
	local holding = false
	local function refresh()
		local inRun = player:GetAttribute("InRun") == true
		local out = player:GetAttribute("Downed") or player:GetAttribute("Dead")
		local building = menus.IsBuilding()
		ring.Visible = inRun and not out and not building
		dropB.Visible = holding
		buildBar.Visible = inRun and not out and building
		cross.Visible = buildBar.Visible
		if mapB then
			mapB.Visible = inRun and not out
		end
		local on = combat and combat.IsSprinting()
		sprint.BackgroundColor3 = on and C.Gold or C.Cyan
		sprintLabel.Text = on and "วิ่งอยู่" or "วิ่ง"
	end
	local function watchTools(container)
		container.ChildAdded:Connect(function(t)
			if t:IsA("Tool") and t:GetAttribute("Kind") == "Sack" then
				holding = true
				refresh()
			end
		end)
		container.ChildRemoved:Connect(function(t)
			if t:IsA("Tool") and t:GetAttribute("Kind") == "Sack" then
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
