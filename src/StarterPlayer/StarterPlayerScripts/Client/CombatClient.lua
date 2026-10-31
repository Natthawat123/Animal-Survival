--[[
	CombatClient — กดตี/ยิง, วิ่ง (สตามิน่า), และเอฟเฟกต์การต่อสู้ทั้งหมดบนจอ
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Classes = require(Shared.Classes)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)

local CombatClient = {}
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- เสียงในโลก (ProSoundEffects ใช้ได้ทุกเกม) · หลายไฟล์ = สุ่มทีละครั้ง
local function ids(...)
	local t = {}
	for _, n in ipairs({ ... }) do
		table.insert(t, "rbxassetid://" .. n)
	end
	return t
end
local SOUND = {
	Boom = ids(9125404320),
	Splash = ids(9120584388),
	Hurt = ids(9113502506, 9113568548),
	Land = ids(9113225735),
	GetUp = ids(17208327798),
	Slash = ids(9120972444, 9120972457, 9120972323), -- ฟันลม
	Flesh = ids(9113502506, 9113568548), -- โดนตัวสัตว์
	Chop = ids(9120806888, 9120807060, 9120807255), -- ขวานเข้าเนื้อไม้
	Mine = ids(9114084950, 9118597103, 9118598240), -- ทุบหิน/แร่
	Crystal = ids(9116394545, 9116395089),
	Bush = ids(17208405682),
	TreeFall = ids(9113225734, 9113225979),
	Build = ids(9114753310, 9114753327),
	Craft = ids(9114753327),
	Refuel = ids(9114439997, 9114439868),
	Break = ids(9113974103),
	WoodHit = ids(9113225985),
}

function CombatClient.Sound(name, at, volume, pitch)
	local list = SOUND[name]
	if not list then
		return
	end
	local id = list[math.random(1, #list)]
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	s.RollOffMaxDistance = 300
	if typeof(at) == "Vector3" then
		local att = Instance.new("Attachment")
		att.WorldPosition = at
		att.Parent = Workspace.Terrain
		s.Parent = att
		Debris:AddItem(att, 6)
	else
		s.Parent = Workspace.CurrentCamera
		Debris:AddItem(s, 6)
	end
	s:Play()
end

---------------------------------------------------------------- จอสั่น
local shake = 0
CombatClient.ShakeEnabled = true -- ตั้งค่า: ปิดจอสั่นได้
function CombatClient.Shake(power, time)
	if not CombatClient.ShakeEnabled then
		return
	end
	shake = math.max(shake, power)
	task.delay(time or 0.3, function()
		shake = math.max(0, shake - power)
	end)
end

---------------------------------------------------------------- ตัวช่วย FX
local fxFolder = Instance.new("Folder")
fxFolder.Name = "ClientFX"
fxFolder.Parent = Workspace.CurrentCamera

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = fxFolder
	return p
end

local function ring(pos, radius, color, time, thickness)
	local r = fxPart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(thickness or 0.6, 2, 2), Color = color, Transparency = 0.1,
		CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2),
	})
	TweenService:Create(r, TweenInfo.new(time or 0.5, Enum.EasingStyle.Quad), { Size = Vector3.new(thickness or 0.6, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(r, (time or 0.5) + 0.1)
end

local function burst(pos, color, count, speed, size, texture)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = Workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture or "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.5, 1.1)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Size = NumberSequence.new(size or 0.6, 0)
	e.Color = ColorSequence.new(color)
	e.Drag = 3
	e.Acceleration = Vector3.new(0, -12, 0)
	e.Parent = a
	e:Emit(count)
	Debris:AddItem(a, 2)
end

local function smoke(pos, color, count, size)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = Workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 0
	e.Lifetime = NumberRange.new(1, 2)
	e.Speed = NumberRange.new(4, 10)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.4), NumberSequenceKeypoint.new(1, size) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(color)
	e.Drag = 2
	e.Parent = a
	e:Emit(count)
	Debris:AddItem(a, 3)
end

local function flashLight(pos, color, range, time)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = Workspace.Terrain
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 4
	l.Parent = a
	TweenService:Create(l, TweenInfo.new(time or 0.4), { Brightness = 0 }):Play()
	Debris:AddItem(a, (time or 0.4) + 0.1)
end

local function tracer(from, to, color, width, time)
	local dist = (to - from).Magnitude
	local p = fxPart({ Size = Vector3.new(width or 0.25, width or 0.25, dist), Color = color, CFrame = CFrame.lookAt((from + to) / 2, to) })
	TweenService:Create(p, TweenInfo.new(time or 0.25), { Transparency = 1, Size = Vector3.new(0.05, 0.05, dist) }):Play()
	Debris:AddItem(p, (time or 0.25) + 0.05)
end

local function floatText(pos, text, color, size, rise)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = Workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 50)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 220
	bb.Parent = a
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = color
	t.Font = Enum.Font.GothamBlack
	t.TextSize = size or 24
	t.TextStrokeTransparency = 0.2
	t.Parent = bb
	TweenService:Create(bb, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, rise or 4, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(a, 1.1)
end
CombatClient.FloatText = floatText

local function hitFlash(model)
	if not (model and model.Parent) then
		return
	end
	local h = model:FindFirstChild("HitFlash")
	if not h then
		h = Instance.new("Highlight")
		h.Name = "HitFlash"
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.OutlineTransparency = 1
		h.FillColor = Color3.new(1, 1, 1)
		h.Parent = model
	end
	h.Enabled = true
	h.FillTransparency = 0.2
	TweenService:Create(h, TweenInfo.new(0.18), { FillTransparency = 1 }):Play()
end

-- ขอบจอแดงตอนเจ็บ
local vignette
local function hurtVignette(power)
	if not vignette then
		local gui = UIKit.Screen("HurtFX", 30, true)
		vignette = Instance.new("CanvasGroup")
		vignette.Size = UDim2.fromScale(1, 1)
		vignette.BackgroundTransparency = 1
		vignette.GroupTransparency = 1
		vignette.Parent = gui
		-- ขอบแดง 2 ชั้น (แนวนอน + แนวตั้ง)
		for _, rot in ipairs({ 0, 90 }) do
			local f = Instance.new("Frame")
			f.Size = UDim2.fromScale(1, 1)
			f.BorderSizePixel = 0
			f.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
			f.Parent = vignette
			local grad = Instance.new("UIGradient")
			grad.Rotation = rot
			grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.22, 1), NumberSequenceKeypoint.new(0.78, 1), NumberSequenceKeypoint.new(1, 0.1) })
			grad.Parent = f
		end
	end
	vignette.GroupTransparency = math.clamp(1 - power, 0.25, 0.9)
	TweenService:Create(vignette, TweenInfo.new(0.7), { GroupTransparency = 1 }):Play()
end

-- เลือดต่ำจริง (< 25%): ขอบจอแดงเต้นช้าๆ ค้างไว้จนเลือดกลับมา (ไม่ขึ้นตอนเลือดยังเยอะ)
local lowVignette
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local frac = hum and hum.Health > 0 and hum.Health / math.max(hum.MaxHealth, 1) or 1
	local low = frac < 0.25 and player:GetAttribute("InRun") == true and not player:GetAttribute("Dead")
	if not low then
		if lowVignette then
			lowVignette.GroupTransparency = 1
		end
		return
	end
	if not lowVignette then
		local gui = UIKit.Screen("LowHealthFX", 29, true)
		lowVignette = Instance.new("CanvasGroup")
		lowVignette.Size = UDim2.fromScale(1, 1)
		lowVignette.BackgroundTransparency = 1
		lowVignette.Parent = gui
		for _, rot in ipairs({ 0, 90 }) do
			local f = Instance.new("Frame")
			f.Size = UDim2.fromScale(1, 1)
			f.BorderSizePixel = 0
			f.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
			f.Parent = lowVignette
			local grad = Instance.new("UIGradient")
			grad.Rotation = rot
			grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.18, 1), NumberSequenceKeypoint.new(0.82, 1), NumberSequenceKeypoint.new(1, 0.2) })
			grad.Parent = f
		end
	end
	-- ยิ่งเลือดน้อยยิ่งเข้ม · เต้นตามจังหวะหัวใจ
	local depth = 1 - frac / 0.25
	local beat = 0.5 + 0.5 * math.sin(os.clock() * (4 + depth * 4))
	lowVignette.GroupTransparency = 0.88 - depth * 0.3 - beat * 0.12
end)

---------------------------------------------------------------- ตี / ยิง
local lastSwing = 0
local spearThrust
local function aimDirection()
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { char }
	local res = Workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	local target = res and res.Position or (ray.Origin + ray.Direction * 400)
	if head then
		return (target - head.Position).Unit
	end
	return ray.Direction
end

-- แทงหอก: ดันไหล่ขวาไปข้างหน้าแล้วดึงกลับ (ปรับ C0 ของข้อไหล่ ทับบนท่าถือของ)
local thrusting = false
spearThrust = function(char)
	local m = char and (char:FindFirstChild("RightShoulder", true) or char:FindFirstChild("Right Shoulder", true))
	-- ตัวละครแบบใหม่ใช้ AnimationConstraint: ฐานของข้อต่อ = CFrame ของ Attachment0 (แบบเก่า Motor6D = C0)
	local obj, prop = m, "C0"
	if m and m:IsA("AnimationConstraint") then
		obj, prop = m.Attachment0, "CFrame"
	elseif not m or not m:IsA("Motor6D") then
		obj = nil
	end
	if not obj or thrusting then
		return
	end
	thrusting = true
	local base = obj[prop]
	local back = base * CFrame.new(0, 0.1, 0.5) * CFrame.Angles(math.rad(10), 0, 0)
	local out = base * CFrame.new(0, -0.1, -1.6) * CFrame.Angles(math.rad(-8), 0, 0)
	local t1 = TweenService:Create(obj, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { [prop] = back })
	local t2 = TweenService:Create(obj, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { [prop] = out })
	local t3 = TweenService:Create(obj, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { [prop] = base })
	t1:Play()
	t1.Completed:Wait()
	t2:Play()
	t2.Completed:Wait()
	task.wait(0.06)
	t3:Play()
	t3.Completed:Wait()
	obj[prop] = base
	thrusting = false
end

local function onActivate(tool, noAuto)
	local id = tool:GetAttribute("ItemId")
	local spec = Items.Tools[id]
	if not spec then
		return
	end
	-- สลับเครื่องมืออัตโนมัติ (AutoTool): เล็งต้นไม้/หิน/สัตว์แต่ถือของไม่เหมาะ -> หยิบของที่ดีกว่าแล้วตีด้วยอันนั้น
	if not noAuto and CombatClient.AutoTool and CombatClient.AutoTool.Before(tool, function(t)
		onActivate(t, true)
	end) then
		return
	end
	local now = os.clock()
	if now - lastSwing < spec.Cooldown then
		return
	end
	lastSwing = now
	Remotes.Get("Attack"):FireServer(aimDirection())
	if spec.Kind == "Spear" then
		-- หอก/ตรีศูล: แทงไปข้างหน้า (ท่า Lunge ของ Roblox ยกขา ไม่เหมือนแทง)
		task.spawn(spearThrust, player.Character)
	elseif spec.Kind ~= "Bow" then
		-- ท่าฟันของ Roblox (Animate อ่าน toolanim) · ธนูยิงอย่างเดียว ไม่ต้องเหวี่ยง
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
	end
	CombatClient.Sound("Slash", nil, 0.35, 0.9 + math.random() * 0.2)
end

-- กดค้าง = ตีต่อเนื่อง (ตามคูลดาวน์ของอาวุธ) จนกว่าจะปล่อยปุ่ม/นิ้ว หรือเก็บของออกจากมือ
local heldTool = nil
local RELEASE = { [Enum.UserInputType.MouseButton1] = true, [Enum.UserInputType.Touch] = true }
UserInputService.InputEnded:Connect(function(input)
	if RELEASE[input.UserInputType] or input.KeyCode == Enum.KeyCode.ButtonR2 then
		heldTool = nil
	end
end)

-- ตีด้วยเครื่องมือนี้ทันที (ไม่ผ่าน AutoTool) — ใช้ตอนสลับให้อัตโนมัติ
function CombatClient.Swing(tool)
	onActivate(tool, true)
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
		heldTool = tool
	end
end

local function hookTool(c)
	c:SetAttribute("Hooked", true)
	c.Activated:Connect(function()
		heldTool = c
		onActivate(c)
	end)
	c.Deactivated:Connect(function()
		if heldTool == c then
			heldTool = nil
		end
	end)
	c.Unequipped:Connect(function()
		if heldTool == c then
			heldTool = nil
		end
	end)
end

local function hookCharacter(char)
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") and not c:GetAttribute("Hooked") then
			hookTool(c)
		end
	end)
end

---------------------------------------------------------------- วิ่ง / สตามิน่า
local stamina = 100
local sprinting = false
player:GetAttributeChangedSignal("StaminaRefill"):Connect(function()
	stamina = 100 -- ดื่มน้ำเบอร์รี่
end)
function CombatClient.SetSprint(on)
	sprinting = on == true
end
function CombatClient.IsSprinting()
	return sprinting
end
local function sprintAction(_, inputState)
	sprinting = inputState == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Pass
end

---------------------------------------------------------------- FX จาก server
local Handlers = {}

Handlers.Hit = function(d)
	hitFlash(d.Model)
	local color = d.Crit and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 255, 255)
	local text = tostring(d.Amount)
	if d.Crit then
		text = text .. "!"
	end
	floatText(d.Position + Vector3.new(0, 3, 0), text, color, d.Crit and 30 or 22)
	if d.Mult and d.Mult > 1.1 then
		floatText(d.Position + Vector3.new(0, 5, 0), "แพ้ทางธาตุ!", Color3.fromRGB(120, 255, 140), 18, 6)
	elseif d.Mult and d.Mult < 0.9 then
		floatText(d.Position + Vector3.new(0, 5, 0), "ต้านทาน", Color3.fromRGB(170, 170, 180), 16, 6)
	end
	burst(d.Position, Color3.fromRGB(255, 230, 200), 8, 18, 0.4)
	CombatClient.Sound("Flesh", d.Position, 0.5, 0.9 + math.random() * 0.2)
	local char = player.Character
	if char and (char:GetPivot().Position - d.Position).Magnitude < 30 then
		CombatClient.Shake(0.15, 0.12)
	end
end

-- ดาเมจต่อเนื่อง (หิว/ไฟไหม้/ลาวา) มาทีละนิดทุกเฟรม -> ห้ามจอแดง/สั่นทุกครั้ง (เคยกะพริบแดงทั้งที่เลือดแทบไม่ลด)
--   สะสมไว้ ลดจริงครบ 8 ค่อยกะพริบเบาๆ ทีเดียว · ดาเมจโดนตีจริง (ก้อนเดียว >= 3) = จอแดงตามแรง
local TICK_SOURCES = { Hunger = true, Burn = true, Lava = true }
local tickDamage, lastTickFlash = 0, 0
Handlers.Hurt = function(d)
	local amount = tonumber(d.Amount) or 0
	if TICK_SOURCES[d.Source] or amount < 3 then
		tickDamage += amount
		if tickDamage >= 8 and os.clock() - lastTickFlash > 1.5 then
			tickDamage = 0
			lastTickFlash = os.clock()
			hurtVignette(0.22)
		end
		return
	end
	hurtVignette(math.clamp(amount / 40, 0.2, 0.7))
	CombatClient.Shake(math.clamp(d.Amount / 60, 0.15, 0.8), 0.25)
	if d.Amount >= 8 then
		CombatClient.Sound("Hurt", nil, 0.4)
	end
end

Handlers.Knockback = function(d)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = d.Velocity
	end
end
Handlers.Launch = Handlers.Knockback

Handlers.Pull = function(d)
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or os.clock() - t0 > (d.Time or 2) then
			conn:Disconnect()
			return
		end
		local dir = (d.Center - root.Position) * Vector3.new(1, 0, 1)
		-- หยุดดูดที่ขอบตัวบอส (เดิมดูดเข้ากลางตัว -> ชนกล่องชนยักษ์ของเยติแล้วฟิสิกส์ดีดผู้เล่นกระเด็นไกลเป็นพันสตั๊ด)
		local stop = d.Stop or 3
		if dir.Magnitude > stop then
			local v = root.AssemblyLinearVelocity
			local k = math.clamp((dir.Magnitude - stop) / 10, 0.2, 1)
			root.AssemblyLinearVelocity = Vector3.new(0, math.min(v.Y, 30), 0) + dir.Unit * 34 * k + dir.Unit:Cross(Vector3.new(0, 1, 0)) * 22 * k
		end
	end)
end

Handlers.Arrow = function(d)
	local color = d.Element == "Air" and Color3.fromRGB(200, 230, 255) or Color3.fromRGB(255, 236, 190)
	tracer(d.From, d.To, color, d.Element and 0.4 or 0.18, 0.35)
	burst(d.To, color, 6, 10, 0.3)
end

Handlers.Bolt = function(d)
	tracer(d.From, d.To, Color3.fromRGB(230, 220, 200), 0.35, 0.3)
end

Handlers.Slam = function(d)
	local color = UIKit.Colors.Element[d.Element] or Color3.fromRGB(255, 255, 255)
	ring(d.Position - Vector3.new(0, 2, 0), d.Radius or 10, color, 0.45, 1)
	smoke(d.Position, Color3.fromRGB(150, 140, 120), 12, 6)
	CombatClient.Shake(0.4, 0.2)
end

local function bigImpact(d, smokeColor)
	local color = d.Color or Color3.fromRGB(255, 140, 50)
	local r = d.Radius or 8
	ring(d.Position, r, color, 0.55, 1.4)
	burst(d.Position + Vector3.new(0, 2, 0), color, 30, 40, 1.2)
	smoke(d.Position, smokeColor or Color3.fromRGB(70, 60, 60), 14, r * 0.8)
	flashLight(d.Position + Vector3.new(0, 4, 0), color, r * 4, 0.5)
	local char = player.Character
	local dist = char and (char:GetPivot().Position - d.Position).Magnitude or 999
	if dist < 120 then
		CombatClient.Shake(math.clamp((120 - dist) / 120, 0.1, 1) * 0.9, 0.35)
	end
end

Handlers.Explosion = function(d)
	bigImpact(d)
	CombatClient.Sound("Boom", d.Position, 0.7)
end
Handlers.Shockwave = function(d)
	bigImpact(d, Color3.fromRGB(110, 100, 90))
	ring(d.Position, (d.Radius or 10) * 1.3, Color3.fromRGB(255, 255, 255), 0.8, 0.4)
	CombatClient.Sound("Boom", d.Position, 0.9, 0.7)
end
Handlers.Splash = function(d)
	bigImpact(d, Color3.fromRGB(200, 230, 255))
	CombatClient.Sound("Splash", d.Position, 0.9)
end
Handlers.Geyser = function(d)
	local col = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 8, 8), Color = Color3.fromRGB(120, 220, 255), Transparency = 0.3, Material = Enum.Material.Glass, CFrame = CFrame.new(d.Position) * CFrame.Angles(0, 0, math.pi / 2) })
	TweenService:Create(col, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = Vector3.new(50, 12, 12), CFrame = CFrame.new(d.Position + Vector3.new(0, 25, 0)) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 1 }):Play()
	Debris:AddItem(col, 0.6)
	Handlers.Splash(d)
end
Handlers.Lightning = function(d)
	local from = d.Position + Vector3.new(math.random(-10, 10), 160, math.random(-10, 10))
	local prev = from
	for i = 1, 8 do
		local t = i / 8
		local p = from:Lerp(d.Position, t) + (i < 8 and Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)) or Vector3.zero)
		tracer(prev, p, Color3.fromRGB(200, 225, 255), 1.2, 0.35)
		prev = p
	end
	flashLight(d.Position + Vector3.new(0, 10, 0), Color3.fromRGB(190, 220, 255), 120, 0.4)
	local cc = Lighting:FindFirstChild("ASGrade")
	if cc then
		local b = cc.Brightness
		cc.Brightness = b + 0.4
		task.delay(0.08, function()
			cc.Brightness = b
		end)
	end
	bigImpact(d, Color3.fromRGB(120, 130, 160))
	CombatClient.Sound("Boom", d.Position, 1, 1.3)
end
Handlers.Cyclone = function(d)
	for i = 1, 4 do
		task.delay(i * 0.25, function()
			ring(d.Position, (d.Radius or 40) * (1 - i * 0.18), Color3.fromRGB(220, 235, 255), 0.6, 0.5)
		end)
	end
	smoke(d.Position, Color3.fromRGB(220, 230, 240), 30, 14)
end
Handlers.Gust = function(d)
	ring(d.Position, d.Radius or 40, Color3.fromRGB(220, 235, 255), 0.6, 0.6)
end

Handlers.Death = function(d)
	local color = UIKit.Colors.Element[d.Element] or Color3.fromRGB(230, 220, 200)
	burst(d.Position, color, d.Boss and 80 or 20, d.Boss and 60 or 20, d.Boss and 2 or 0.7)
	if d.Boss then
		smoke(d.Position, Color3.fromRGB(40, 36, 40), 40, 30)
		CombatClient.Shake(1, 0.8)
		CombatClient.Sound("Boom", d.Position, 1, 0.5)
	end
end
Handlers.Vanish = function(d)
	smoke(d.Position, Color3.fromRGB(30, 30, 36), 14, 6)
end
Handlers.Immune = function(d)
	floatText(d.Position, "ฆ่าไม่ตาย... ใช้แสงไฟไล่!", Color3.fromRGB(200, 200, 220), 20, 5)
end
-- ขอบจอมืดแวบ (ความหลอน ไม่ใช่เจ็บ — สีแดงสงวนไว้ให้ดาเมจ/เลือดต่ำ)
local dread
local function dreadVignette(power)
	if not dread then
		local gui = UIKit.Screen("DreadFX", 28, true)
		dread = Instance.new("CanvasGroup")
		dread.Size = UDim2.fromScale(1, 1)
		dread.BackgroundTransparency = 1
		dread.GroupTransparency = 1
		dread.Parent = gui
		for _, rot in ipairs({ 0, 90 }) do
			local f = Instance.new("Frame")
			f.Size = UDim2.fromScale(1, 1)
			f.BorderSizePixel = 0
			f.BackgroundColor3 = Color3.fromRGB(6, 2, 14)
			f.Parent = dread
			local grad = Instance.new("UIGradient")
			grad.Rotation = rot
			grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.25, 1), NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 0) })
			grad.Parent = f
		end
	end
	dread.GroupTransparency = 1 - power
	TweenService:Create(dread, TweenInfo.new(1.6), { GroupTransparency = 1 }):Play()
end

Handlers.StalkerStare = function(d)
	dreadVignette(0.6)
	CombatClient.Shake(0.2, 2)
	local hb = Instance.new("Sound")
	hb.SoundId = SOUND.Land
	hb.Volume = 1
	hb.PlaybackSpeed = 0.4
	hb.Parent = Workspace.CurrentCamera
	for i = 0, 3 do
		task.delay(i * 0.55, function()
			hb:Play()
		end)
	end
	Debris:AddItem(hb, 3)
end
Handlers.BossCast = function(d)
	local model = d.Model
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if root then
		floatText(root.Position + Vector3.new(0, model:GetExtentsSize().Y * 0.6, 0), d.Text, Color3.fromRGB(255, 120, 100), 34, 6)
	end
end
Handlers.NodeHit = function(d)
	local colors = { Tree = Color3.fromRGB(150, 110, 70), Rock = Color3.fromRGB(170, 170, 170), Crystal = Color3.fromRGB(200, 240, 255), Bush = Color3.fromRGB(110, 200, 90) }
	burst(d.Position + Vector3.new(0, 3, 0), colors[d.Kind] or Color3.new(1, 1, 1), 8, 14, 0.5, "rbxasset://textures/particles/smoke_main.dds")
	local snd = ({ Tree = "Chop", Rock = "Mine", Crystal = "Crystal", Bush = "Bush" })[d.Kind]
	if snd then
		CombatClient.Sound(snd, d.Position, 0.55, 0.92 + math.random() * 0.16)
	end
	local node = d.Node
	if node and node.Parent then
		local cf = node:GetPivot()
		node:PivotTo(cf * CFrame.Angles(0, 0, math.rad(2)))
		task.delay(0.06, function()
			if node.Parent then
				node:PivotTo(cf)
			end
		end)
	end
end
-- พัง/วางของ: ท่าแยกตามวัสดุ (BreakFX)
local BreakFX = require(script.Parent:WaitForChild("BreakFX"))
BreakFX.Init({
	Sound = CombatClient.Sound, Shake = CombatClient.Shake, Burst = burst, Smoke = smoke, Ring = ring, Flash = flashLight,
	ElementColors = UIKit.Colors.Element,
})
for _, name in ipairs({ "NodeBreak", "StructureBreak", "Build" }) do
	Handlers[name] = function(d)
		task.spawn(BreakFX[name], d)
	end
end
Handlers.Craft = function(d)
	burst(d.Position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 220, 140), 16, 12, 0.4)
	CombatClient.Sound("Craft", d.Position, 0.55)
end
Handlers.Refuel = function(d)
	burst(d.Position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 160, 60), 30, 22, 0.6)
	flashLight(d.Position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 170, 80), 50, 0.8)
	CombatClient.Sound("Refuel", d.Position, 0.6)
end
Handlers.FireHit = function(d)
	burst(d.Position + Vector3.new(0, 3, 0), Color3.fromRGB(255, 120, 40), 6, 10, 0.4)
end
Handlers.StructureHit = function(d)
	local s = d.Structure
	if not (s and s.Parent) then
		return
	end
	local bb = s:FindFirstChild("HPBar")
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "HPBar"
		bb.Size = UDim2.fromOffset(90, 8)
		bb.StudsOffsetWorldSpace = Vector3.new(0, s:GetExtentsSize().Y + 2, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 140
		bb.Adornee = s.PrimaryPart or s:FindFirstChildWhichIsA("BasePart")
		bb.Parent = s
		local back = Instance.new("Frame")
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		back.BorderSizePixel = 0
		back.Parent = bb
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(230, 170, 60)
		fill.BorderSizePixel = 0
		fill.Parent = back
	end
	local frac = math.clamp((s:GetAttribute("Health") or 0) / math.max(s:GetAttribute("MaxHealth") or 1, 1), 0, 1)
	bb.Frame.Fill.Size = UDim2.fromScale(frac, 1)
	bb.Enabled = true
	task.delay(4, function()
		if bb.Parent then
			bb.Enabled = false
		end
	end)
end

-- เครื่องย่อย: ลูกกลิ้งหมุน เครื่องสั่น ขี้เลื่อย/ประกายไฟ/ฝุ่นหินพุ่ง + ตัวเลขของที่ได้
local grindState = {}
Handlers.Grind = function(d)
	local bench = d.Bench
	local hopper = bench and bench:FindFirstChild("Hopper")
	if not hopper then
		return
	end
	local st = grindState[bench]
	if not st then
		st = { Until = 0 }
		grindState[bench] = st
	end
	local already = os.clock() < st.Until
	st.Until = os.clock() + 1.6
	-- อนุภาคตามชนิดของ
	local hasWood, hasHard = false, false
	local lines = {}
	for id, n in pairs(d.Items or {}) do
		if id == "Wood" or id == "Fiber" then
			hasWood = true
		else
			hasHard = true
		end
		table.insert(lines, "+" .. n .. " " .. Items.DisplayName(id))
	end
	local outPart = bench:FindFirstChild("GrindOut")
	local top = outPart and outPart.Position or (hopper.Position + Vector3.new(0, hopper.Size.Y * 0.4, 0))
	if hasWood then
		burst(top, Color3.fromRGB(214, 170, 110), 30, 18, 0.5, "rbxasset://textures/particles/smoke_main.dds")
		burst(top, Color3.fromRGB(170, 120, 70), 20, 22, 0.35)
	end
	if hasHard then
		burst(top, Color3.fromRGB(255, 200, 110), 28, 26, 0.3)
		smoke(top, Color3.fromRGB(150, 145, 140), 10, 4)
	end
	-- ป้ายตัวเลขลอยขึ้น
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 60)
	bb.StudsOffsetWorldSpace = Vector3.new(0, hopper.Size.Y * 0.9, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = hopper
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(150, 255, 160)
	t.TextStrokeTransparency = 0.3
	t.Text = "📦 " .. table.concat(lines, "  ")
	t.Parent = bb
	bb.Parent = hopper
	TweenService:Create(bb, TweenInfo.new(1.6), { StudsOffsetWorldSpace = Vector3.new(0, hopper.Size.Y + 6, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(bb, 1.7)
	if already then
		return
	end
	-- ลูกกลิ้งหมุน + เครื่องสั่น (ฝั่งนี้เท่านั้น)
	local rollers = {}
	for _, r in ipairs(bench:GetChildren()) do
		if r:IsA("BasePart") and r:GetAttribute("Spin") then
			table.insert(rollers, { r, r.CFrame, r:GetAttribute("Spin") })
		end
	end
	local model = bench:FindFirstChild("CrafterModel")
	local base = model and model:GetPivot()
	task.spawn(function()
		local a = 0
		while os.clock() < st.Until and bench.Parent do
			local dt = RunService.RenderStepped:Wait()
			a += dt * 14
			for _, e in ipairs(rollers) do
				e[1].CFrame = e[2] * CFrame.Angles(a * e[3], 0, 0)
			end
			if model and base then
				model:PivotTo(base * CFrame.new(math.sin(a * 3.1) * 0.06, math.abs(math.sin(a * 2.3)) * 0.05, math.cos(a * 2.7) * 0.06))
			end
		end
		for _, e in ipairs(rollers) do
			e[1].CFrame = e[2]
		end
		if model and base then
			model:PivotTo(base)
		end
	end)
	CombatClient.Sound("Land", hopper.Position, 0.6, 0.8)
end

-- เอฟเฟกต์จากคลัง VFX (แพ็ก Creator Store) สำหรับตี/ตัด/ทุบ/คราฟต์
local VFXLib = require(script.Parent:WaitForChild("VFXLib"))
local function vfx(name, pos, opts)
	pcall(VFXLib.Play, name, CFrame.new(pos), opts or {})
end
local VFX_NAMES = {
	RockRing = "VFXPack/vfx pack/f", Crack = "VFXPack/Anime/Crack-01", Shiny = "VFXPack/Anime/Shiny-01", Charge = "VFXPack/Anime/Charge-01",
	ShieldBreak = "VFXPack/Anime/Shield-Break-01", Fire = "VFXPack/Anime/Fire-02", Punch = "VFXPack/Anime/Blood-Punch-01", Ice = "IceStomp",
}

-- ระเบิดของกระสุนที่มีเอฟเฟกต์เฉพาะ (คทาเพลิง: Store "ExplosionCharge") แทนลูกระเบิดพื้นฐาน
local baseExplosion = Handlers.Explosion
Handlers.Explosion = function(d)
	if d.Fx then
		vfx(d.Fx, d.Position, { Scale = d.FxScale or 0.3, Duration = 0.35, Burst = 1 })
		CombatClient.Sound("Boom", d.Position, 0.6, 1.15)
		return
	end
	baseExplosion(d)
end

-- เอฟเฟกต์สกิลบอส (BossFX)
local BossFX = require(script.Parent:WaitForChild("BossFX"))
BossFX.Init(function(power, time)
	CombatClient.Shake(power, time)
end)
for k, fn in pairs(BossFX.Handlers) do
	Handlers[k] = fn
end
local function wrap(name, extra)
	local base = Handlers[name]
	Handlers[name] = function(d)
		if base then
			base(d)
		end
		pcall(extra, d)
	end
end
wrap("Hit", function(d)
	vfx(VFX_NAMES.Punch, d.Position, { Scale = d.Crit and 1.6 or 1, Duration = 0.15 })
end)
wrap("NodeHit", function(d)
	local p = d.Position + Vector3.new(0, 3, 0)
	if d.Kind == "Rock" then
		vfx(VFX_NAMES.Crack, p, { Scale = 1.2, Duration = 0.15 })
	elseif d.Kind == "Crystal" then
		vfx(VFX_NAMES.Shiny, p, { Scale = 1.4, Duration = 0.2 })
	elseif d.Kind == "Tree" then
		burst(p + Vector3.new(0, 3, 0), Color3.fromRGB(90, 150, 70), 10, 12, 0.5)
	end
end)
wrap("Craft", function(d)
	vfx(VFX_NAMES.Shiny, d.Position + Vector3.new(0, 4, 0), { Scale = 2, Duration = 0.25 })
end)
wrap("Refuel", function(d)
	vfx(VFX_NAMES.Fire, d.Position + Vector3.new(0, 2, 0), { Scale = 3.5, Duration = 0.4 })
end)

function CombatClient.HandleFx(kind, data, hud)
	if kind == "Pickup" then
		hud.Pickup(data.Item, data.Count)
		return
	elseif kind == "Loot" then
		for id, n in pairs(data.Items or {}) do
			hud.Pickup(id, n)
		end
		return
	elseif kind == "Eat" or kind == "Heal" then
		local char = player.Character
		if char then
			burst(char:GetPivot().Position, kind == "Heal" and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(255, 200, 120), 12, 8, 0.4)
		end
		return
	end
	local h = Handlers[kind]
	if h then
		local ok, err = pcall(h, data)
		if not ok then
			warn("[AS] fx", kind, err)
		end
	end
end

---------------------------------------------------------------- Init
function CombatClient.Init(state, hud)
	if player.Character then
		hookCharacter(player.Character)
		for _, c in ipairs(player.Character:GetChildren()) do
			if c:IsA("Tool") and not c:GetAttribute("Hooked") then
				hookTool(c)
			end
		end
	end
	player.CharacterAdded:Connect(hookCharacter)
	-- กดค้าง: ตีซ้ำทุกครั้งที่คูลดาวน์หมด (onActivate กันตีถี่เอง)
	RunService.Heartbeat:Connect(function()
		local t = heldTool
		if not t then
			return
		end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if t.Parent ~= char or not hum or hum.Health <= 0 or player:GetAttribute("Downed") then
			heldTool = nil
			return
		end
		onActivate(t, true)
	end)
	-- มือถือใช้ปุ่ม "วิ่ง" ของ MobileControls (จัดวางรอบปุ่มกระโดด ไม่ซ้อนกัน) แทนปุ่มอัตโนมัติของ ContextActionService
	local touchOnly = UIKit.IsTouch
	ContextActionService:BindAction("ASSprint", sprintAction, not touchOnly, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	if not touchOnly then
		ContextActionService:SetTitle("ASSprint", "วิ่ง")
		ContextActionService:SetPosition("ASSprint", UDim2.new(1, -170, 1, -170))
	end

	RunService.RenderStepped:Connect(function(dt)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and not player:GetAttribute("Downed") then
			local perks = Classes.PerksFor(player:GetAttribute("Class") or "Survivor", player:GetAttribute("ClassLevel") or 1)
			local speedMult = (perks.SpeedMult or 1) * (state:GetAttribute("SpiritAir") and 1.1 or 1) * (player:GetAttribute("DevSpeed") or 1) * (player:GetAttribute("MountSpeed") or 1) * (player:GetAttribute("CineRun") or 1)
			local staminaMult = (perks.StaminaMult or 1) / (player:GetAttribute("Aura_Air") and 0.85 or 1) -- ออร่าวิหารน้ำแข็ง
			local moving = hum.MoveDirection.Magnitude > 0.1
			if sprinting and moving and stamina > 0 then
				stamina = math.max(0, stamina - 10 / staminaMult * dt) -- วิ่งได้ ~10 วิ ต่อหลอด (เดิม 20/วิ = 5 วิ)
				hum.WalkSpeed = Config.SprintSpeed * speedMult
				if stamina <= 0 then
					sprinting = false
				end
			else
				stamina = math.min(100, stamina + 14 * dt)
				hum.WalkSpeed = Config.BaseWalkSpeed * speedMult
			end
		end
		hud.Stamina = stamina
		-- จอสั่น
		if shake > 0 then
			local s = shake * 0.35
			camera.CFrame = camera.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * s * 4), math.rad((math.random() - 0.5) * s * 4), 0)
		end
	end)
end

return CombatClient
