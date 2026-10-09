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

local SOUND = {
	Boom = "rbxasset://sounds/impact_explosion_03.mp3",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Hurt = "rbxasset://sounds/ouch.ogg",
	Land = "rbxasset://sounds/action_jump_land.mp3",
	GetUp = "rbxasset://sounds/action_get_up.mp3",
	Slash = "rbxasset://sounds/swordslash.wav",
}

function CombatClient.Sound(name, at, volume, pitch)
	local id = SOUND[name]
	if not id then
		return
	end
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
function CombatClient.Shake(power, time)
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
		local gui = UIKit.Screen("HurtFX", 30)
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

---------------------------------------------------------------- ตี / ยิง
local lastSwing = 0
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

local function onActivate(tool)
	local id = tool:GetAttribute("ItemId")
	local spec = Items.Tools[id]
	if not spec then
		return
	end
	local now = os.clock()
	if now - lastSwing < spec.Cooldown then
		return
	end
	lastSwing = now
	Remotes.Get("Attack"):FireServer(aimDirection())
	-- ท่าฟันของ Roblox (Animate อ่าน toolanim)
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = (spec.Kind == "Spear") and "Lunge" or "Slash"
	anim.Parent = tool
	CombatClient.Sound("Slash", nil, 0.35, 0.9 + math.random() * 0.2)
end

local function hookCharacter(char)
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") and not c:GetAttribute("Hooked") then
			c:SetAttribute("Hooked", true)
			c.Activated:Connect(function()
				onActivate(c)
			end)
		end
	end)
end

---------------------------------------------------------------- วิ่ง / สตามิน่า
local stamina = 100
local sprinting = false
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
	local char = player.Character
	if char and (char:GetPivot().Position - d.Position).Magnitude < 30 then
		CombatClient.Shake(0.15, 0.12)
	end
end

Handlers.Hurt = function(d)
	hurtVignette(math.clamp(d.Amount / 40, 0.2, 0.7))
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
		if dir.Magnitude > 3 then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0) + dir.Unit * 34 + dir.Unit:Cross(Vector3.new(0, 1, 0)) * 22
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
Handlers.StalkerStare = function(d)
	hurtVignette(0.45)
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
Handlers.TreeFall = function(d)
	task.delay(1.3, function()
		smoke(d.Position, Color3.fromRGB(160, 140, 110), 20, 10)
		CombatClient.Shake(0.25, 0.25)
	end)
end
Handlers.Shatter = function(d)
	burst(d.Position + Vector3.new(0, 2, 0), Color3.fromRGB(200, 200, 200), 18, 24, 0.7, "rbxasset://textures/particles/smoke_main.dds")
end
Handlers.Build = function(d)
	smoke(d.Position, Color3.fromRGB(180, 160, 130), 12, 5)
	ring(d.Position, 8, Color3.fromRGB(255, 220, 140), 0.4, 0.4)
end
Handlers.Craft = function(d)
	burst(d.Position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 220, 140), 16, 12, 0.4)
end
Handlers.Refuel = function(d)
	burst(d.Position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 160, 60), 30, 22, 0.6)
	flashLight(d.Position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 170, 80), 50, 0.8)
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
			if c:IsA("Tool") then
				c:SetAttribute("Hooked", true)
				c.Activated:Connect(function()
					onActivate(c)
				end)
			end
		end
	end
	player.CharacterAdded:Connect(hookCharacter)
	ContextActionService:BindAction("ASSprint", sprintAction, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("ASSprint", "วิ่ง")
	ContextActionService:SetPosition("ASSprint", UDim2.new(1, -170, 1, -170))

	RunService.RenderStepped:Connect(function(dt)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and not player:GetAttribute("Downed") then
			local perks = Classes.PerksFor(player:GetAttribute("Class") or "Survivor", player:GetAttribute("ClassLevel") or 1)
			local speedMult = (perks.SpeedMult or 1) * (state:GetAttribute("SpiritAir") and 1.1 or 1) * (player:GetAttribute("DevSpeed") or 1)
			local staminaMult = perks.StaminaMult or 1
			local moving = hum.MoveDirection.Magnitude > 0.1
			if sprinting and moving and stamina > 0 then
				stamina = math.max(0, stamina - 20 / staminaMult * dt)
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
