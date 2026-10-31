--[[
	AnimalAnimator — อนิเมชันแบบคำนวณสด (procedural) ของสัตว์ทุกตัว บนเครื่องผู้เล่น
	ตั้งค่า Motor6D.Transform ทุกเฟรม (ไม่ต้องอัปโหลดอนิเมชัน ไม่กินเน็ต)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimalSkins = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AnimalSkins"))

local AnimalAnimator = {}

local rigs = {} -- [model] = rig
local sin, cos, abs, clamp = math.sin, math.cos, math.abs, math.clamp
local ANG = CFrame.Angles
local CF = CFrame.new

local BossAnimator = require(script.Parent:WaitForChild("BossAnimator"))
local ClipAnimator = require(script.Parent:WaitForChild("ClipAnimator"))
local SkelAnimator = require(script.Parent:WaitForChild("SkelAnimator"))

local function collect(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local motors = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	local rig = {
		Model = model, Root = root, M = motors, Phase = math.random() * 10, Seed = math.random() * 100,
		Template = model:GetAttribute("Template") or "Quadruped", Id = model:GetAttribute("AnimalId"),
		AttackT = -10, LastAttack = model:GetAttribute("AttackAt") or 0, DeadT = nil, Size = model:GetExtentsSize(),
	}
	model:GetAttributeChangedSignal("AttackAt"):Connect(function()
		rig.AttackT = os.clock()
		rig.AttackKind = model:GetAttribute("AttackKind") or "Bite"
	end)
	model:GetAttributeChangedSignal("Dead"):Connect(function()
		if model:GetAttribute("Dead") and not rig.DeadT then
			rig.DeadT = os.clock()
		end
	end)
	model:GetAttributeChangedSignal("Vanish"):Connect(function()
		rig.VanishT = os.clock()
	end)
	return rig
end

local function add(model)
	if rigs[model] or not model:IsA("Model") then
		return
	end
	task.defer(function()
		if not model.Parent then
			return
		end
		model:WaitForChild("HumanoidRootPart", 5)
		if model:GetAttribute("MeshSkin") then
			pcall(AnimalSkins.Skin, model)
		end
		local rig = collect(model)
		if rig then
			rigs[model] = rig
			-- โมเดลมีผิว+กระดูก (บอสจาก Import 3D): รอผิวโหลดแล้วผูกกระดูก
			if BossAnimator.Has(model) and model:WaitForChild("Skin", 10) then
				pcall(BossAnimator.Attach, rig)
			elseif ClipAnimator.Has(model) and model:WaitForChild("Skin", 10) then
				pcall(ClipAnimator.Attach, rig) -- ท่าจากไฟล์ (Meshy) เล่นเอง
			end
		end
	end)
end

local function setT(rig, name, cf)
	local m = rig.M[name]
	if m then
		m.Transform = cf
	end
end

-- ท่าโจมตี (0..1) ตามเวลาตั้งแต่เริ่ม
local function attackCurve(rig, now)
	local t = now - rig.AttackT
	local kind = rig.AttackKind or "Bite"
	local dur = (kind == "Roar" or kind == "Stare") and 1.1 or 0.45
	if t < 0 or t > dur then
		return 0, kind
	end
	local x = t / dur
	return sin(x * math.pi), kind
end

local function fade(model, alpha)
	local skinned = model:GetAttribute("Skinned")
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and not (skinned and d:GetAttribute("SkinPart")) then
			local base = d:GetAttribute("BaseT")
			if base == nil then
				base = d.Transparency
				d:SetAttribute("BaseT", base)
			end
			d.LocalTransparencyModifier = alpha
		elseif d:IsA("Decal") then
			d.Transparency = alpha
		elseif d:IsA("Light") or d:IsA("Fire") or d:IsA("ParticleEmitter") then
			if alpha > 0.5 then
				d.Enabled = false
			end
		end
	end
end

---------------------------------------------------------------- สัตว์น้ำ: เอฟเฟกต์ประจำตัว + ตอนโจมตี
local VFXLib = require(script.Parent:WaitForChild("VFXLib"))
local WATER_ID = { ReefCrab = true, TideOrca = true, InkOctopus = true }
local function waterFx(rig)
	if rig.WetFx or not WATER_ID[rig.Id] then
		return
	end
	rig.WetFx = true
	local size = rig.Size
	-- หยดน้ำไหลจากตัวตลอด (ตัวเปียก)
	local drip = Instance.new("ParticleEmitter")
	drip.Name = "Drip"
	drip.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	drip.Color = ColorSequence.new(Color3.fromRGB(170, 230, 255), Color3.fromRGB(90, 180, 255))
	drip.LightEmission, drip.LightInfluence = 0.6, 0.4
	drip.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.05) })
	drip.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	drip.Lifetime = NumberRange.new(0.5, 0.9)
	drip.Speed = NumberRange.new(0, 1)
	drip.Acceleration = Vector3.new(0, -30, 0)
	drip.Rate = 6 + size.X
	drip.Shape = Enum.ParticleEmitterShape.Box
	drip.Parent = rig.Root
	-- ฟองอากาศลอยขึ้นรอบตัวเบาๆ
	local bub = Instance.new("ParticleEmitter")
	bub.Name = "Bubbles"
	bub.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bub.Color = ColorSequence.new(Color3.fromRGB(220, 250, 255))
	bub.LightEmission = 0.8
	bub.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.4) })
	bub.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	bub.Lifetime = NumberRange.new(1, 1.8)
	bub.Speed = NumberRange.new(1, 2.5)
	bub.SpreadAngle = Vector2.new(25, 25)
	bub.Rate = 3
	bub.Parent = rig.Root
	if rig.Id == "TideOrca" then
		rig.NextSpray = os.clock() + math.random() * 5
	end
end
-- จอเปื้อนหมึก (โดนหมึกยักษ์ฟาดใกล้ๆ)
local function inkScreen()
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "ASInk"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	gui.Parent = pg
	for i = 1, 7 do
		local blob = Instance.new("Frame")
		local s = math.random(160, 380)
		blob.Size = UDim2.fromOffset(s, s * math.random(70, 110) / 100)
		blob.AnchorPoint = Vector2.new(0.5, 0.5)
		blob.Position = UDim2.fromScale(math.random(15, 85) / 100, math.random(15, 85) / 100)
		blob.BackgroundColor3 = Color3.fromRGB(12, 8, 24)
		blob.BackgroundTransparency = 0.08
		blob.Rotation = math.random(0, 360)
		blob.Parent = gui
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = blob
		game:GetService("TweenService"):Create(blob, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.6 + i * 0.08),
			{ BackgroundTransparency = 1, Position = blob.Position + UDim2.fromScale(0, 0.06) }):Play()
	end
	game:GetService("Debris"):AddItem(gui, 3.6)
end
local function inkCloud(pos, size, look)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.one
	p.CFrame = CFrame.lookAt(pos, pos + (look or Vector3.new(0, 0, -1)))
	p.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(70, 40, 110), Color3.fromRGB(24, 14, 40))
	e.LightInfluence = 0.5
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.25), NumberSequenceKeypoint.new(0.4, size * 0.7), NumberSequenceKeypoint.new(1, size * 1.1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.9, 1.6)
	e.Speed = NumberRange.new(size * 2, size * 4)
	e.SpreadAngle = Vector2.new(35, 35)
	e.EmissionDirection = Enum.NormalId.Front
	e.Drag = 4
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Rate = 0
	e.Parent = p
	e:Emit(16)
	game:GetService("Debris"):AddItem(p, 2.5)
end
local function waterAttackFx(rig, kind)
	local root = rig.Root
	local size = math.max(rig.Size.X, rig.Size.Z)
	task.delay(0.3, function()
		if not root.Parent then
			return
		end
		local front = root.Position + root.CFrame.LookVector * size * 0.45
		if rig.Template == "Whale" then
			pcall(VFXLib.Play, "WaterBurst", CFrame.new(front), { Scale = size / 10, Duration = 0.4 })
			pcall(VFXLib.Play, "WaterSplash", CFrame.new(front), { Scale = size / 12, Duration = 0.4 })
		elseif rig.Template == "Octopus" then
			inkCloud(front, size * 0.3, root.CFrame.LookVector)
			pcall(VFXLib.Play, "WaterSplash", CFrame.new(front), { Scale = size / 12, Duration = 0.3 })
			local char = Players.LocalPlayer.Character
			if char and (char:GetPivot().Position - front).Magnitude < size * 0.9 + 4 then
				inkScreen()
			end
		end
	end)
	local _ = kind
end

-- ปลาวาฬ: ว่ายเป็นคลื่น (หางขึ้นลง) ครีบพาย · โจมตี = พุ่งเงยหัวอ้าปากงับ
local function animateWhale(rig, now, walk, att)
	local ph = now * (1.6 + walk * 2.6) + rig.Seed
	local size = math.max(rig.Size.Z, rig.Size.X)
	setT(rig, "Tail1", ANG(sin(ph) * 0.16 - att * 0.15, sin(ph * 0.5) * 0.05, 0))
	setT(rig, "Tail2", ANG(sin(ph - 1.1) * 0.38 - att * 0.3, 0, 0))
	local paddle = 0.22 + sin(ph * 0.8) * 0.2
	setT(rig, "FinL", ANG(sin(ph * 0.8) * 0.15, 0, paddle))
	setT(rig, "FinR", ANG(sin(ph * 0.8) * 0.15, 0, -paddle))
	setT(rig, "Jaw", ANG(-att * 0.75 + (sin(now * 0.7 + rig.Seed) + 1) * 0.03, 0, 0))
	-- จมลงครึ่งตัว: เห็นหลัง + ครีบหลังโผล่พ้นน้ำ · ตอนงับพุ่งขึ้นเหนือน้ำ
	local sink = -rig.Size.Y * 0.42 * (1 - att * 0.8)
	setT(rig, "Root", CF(0, sink + sin(ph) * size * 0.012 + att * size * 0.08, -att * size * 0.15) * ANG(sin(ph + 0.6) * 0.035 + att * 0.32, 0, sin(ph * 0.5) * 0.03))
	-- พ่นน้ำจากรูหายใจเป็นระยะ
	if rig.NextSpray and now > rig.NextSpray then
		rig.NextSpray = now + 6 + math.random() * 5
		local top = rig.Root.Position + Vector3.new(0, rig.Size.Y * 0.45, 0) + rig.Root.CFrame.LookVector * size * 0.12
		pcall(VFXLib.Play, "WaterSplash", CFrame.new(top), { Scale = size / 20, Duration = 0.5 })
	end
end

-- หมึก: หนวดม้วนเป็นคลื่นรอบตัว · เดิน = หนวดสลับยกเป็นจังหวะ · โจมตี = หนวดหน้าเงื้อขึ้นแล้วฟาดลง
local function animateOctopus(rig, now, p, walk, att)
	if not rig.TentFront then
		rig.TentFront = {}
		for i = 1, 8 do
			local m = rig.M["Tent" .. i]
			if m and m.Part1 then
				local d = rig.Root.CFrame:VectorToObjectSpace(m.Part1.Position - rig.Root.Position)
				rig.TentFront[i] = math.max(0, -d.Unit.Z)
			end
		end
	end
	local t = (now - rig.AttackT)
	local windup = t < 0.25 and t / 0.25 or 0
	local strike = (t >= 0.25 and t < 0.6) and sin((t - 0.25) / 0.35 * math.pi) or 0
	for i = 1, 8 do
		local off = i * 0.785 + rig.Seed
		local curl = sin(now * 2.4 + off) * 0.16 - 0.05
		local lift = sin(p * 2 + i * 1.57) * 0.4 * walk
		local sweep = sin(p * 2 + i * 1.57 + 1.57) * 0.22 * walk + sin(now * 1.3 + off) * 0.06
		local f = rig.TentFront[i] or 0
		curl += f * (-1.2 * windup + 0.7 * strike)
		setT(rig, "Tent" .. i, ANG(curl - math.max(lift, 0), sweep, 0))
	end
	local size = rig.Size.Y
	setT(rig, "Root", CF(0, abs(sin(p * 2)) * size * 0.06 * walk + sin(now * 2 + rig.Seed) * size * 0.02 + windup * size * 0.12, -strike * size * 0.2)
		* ANG(windup * 0.2 - strike * 0.15, sin(p) * 0.08 * walk, 0))
	local _ = att
end

local function animate(rig, now, dt, camPos, playerPos)
	local root = rig.Root
	local vel = root.AssemblyLinearVelocity
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local size = math.max(rig.Size.Z, rig.Size.X, 2)
	local stride = clamp(speed / (size * 1.1), 0, 3.2)
	rig.Phase += dt * (1.5 + stride * 4.5)
	local p = rig.Phase
	local walk = clamp(speed / 6, 0, 1)
	local att, kind = attackCurve(rig, now)
	local state = rig.Model:GetAttribute("State")
	local tmpl = rig.Template

	-- ตาย: ล้มตะแคง แล้วจาง
	if rig.DeadT then
		local t = now - rig.DeadT
		local k = clamp(t / 0.55, 0, 1)
		setT(rig, "Root", CF(0, -rig.Size.Y * 0.18 * k, 0) * ANG(0, 0, 1.45 * k * k))
		for _, n in ipairs({ "LegFL", "LegFR", "LegBL", "LegBR" }) do
			setT(rig, n, ANG(0.5 * k, 0, 0))
		end
		setT(rig, "Neck", ANG(0.4 * k, 0, 0))
		if t > 1.4 then
			fade(rig.Model, clamp((t - 1.4) / 1.4, 0, 1))
		end
		return
	end
	if rig.VanishT then
		fade(rig.Model, clamp((now - rig.VanishT) / 1, 0, 1))
	end

	local breathe = sin(now * 2.2 + rig.Seed) * 0.025
	waterFx(rig)
	if WATER_ID[rig.Id] and rig.AttackT ~= rig.FxAttackT then
		rig.FxAttackT = rig.AttackT
		if rig.AttackT > 0 then
			waterAttackFx(rig, kind)
		end
	end
	if tmpl == "Whale" then
		animateWhale(rig, now, walk, att)
		return
	elseif tmpl == "Octopus" then
		animateOctopus(rig, now, p, walk, att)
		return
	end
	if tmpl == "Skel" then
		SkelAnimator.Animate(rig, now, dt, speed, playerPos) -- สัตว์ที่ช่วยจากศาลเจ้า: ขางอจริง + ท่าจากไฟล์
		return
	end
	if tmpl == "Bird" then
		local flying = rig.Model:GetAttribute("Flying")
		local dive = kind == "Dive" and att > 0
		local flapSpeed = dive and 4 or (flying and 9 or 2)
		local amp = dive and 0.25 or (flying and 0.85 or 0.1)
		local f = sin(now * flapSpeed + rig.Seed) * amp
		local sweep = dive and -0.9 or 0
		setT(rig, "WingL", ANG(0, sweep, -f))
		setT(rig, "WingR", ANG(0, -sweep, f))
		setT(rig, "Root", CF(0, -f * 0.5, 0) * ANG(dive and -0.5 or 0, 0, 0))
		setT(rig, "Neck", ANG(sin(now * 1.3 + rig.Seed) * 0.1 - att * 0.4, sin(now * 0.7) * 0.3, 0))
		setT(rig, "Jaw", ANG(att * 0.5, 0, 0))
		return
	end

	if tmpl == "Crab" then
		for i = 1, 6 do
			local side = i <= 3 and 1 or -1
			local off = (i % 2 == 0) and 0 or math.pi
			setT(rig, "Leg" .. i, ANG(sin(p * 2 + off) * 0.35 * walk, 0, side * (abs(sin(p * 2 + off)) * 0.25 * walk + breathe)))
		end
		local snap = sin(now * 3 + rig.Seed) * 0.08
		setT(rig, "ClawL", ANG(-att * 0.9 + snap, att * 0.4, 0))
		setT(rig, "ClawR", ANG(-att * 0.9 - snap, -att * 0.4, 0))
		setT(rig, "Root", CF(0, abs(sin(p * 2)) * 0.15 * walk, 0) * ANG(0, sin(p) * 0.06 * walk, 0))
		return
	end

	-- สี่ขา / เลื้อยคลาน / เต่า
	local legAmp = (tmpl == "Reptile") and 0.5 or (tmpl == "Tortoise" and 0.35 or 0.75)
	local swing = sin(p * 2) * legAmp * walk
	local rabbit = rig.Id == "Rabbit"
	if rabbit then
		local hop = abs(sin(p * 1.5)) * walk
		setT(rig, "LegFL", ANG(-hop * 0.9, 0, 0))
		setT(rig, "LegFR", ANG(-hop * 0.9, 0, 0))
		setT(rig, "LegBL", ANG(hop * 1.1, 0, 0))
		setT(rig, "LegBR", ANG(hop * 1.1, 0, 0))
		setT(rig, "Root", CF(0, hop * 0.9, 0) * ANG(hop * 0.25, 0, 0))
	else
		local diag = (tmpl == "Reptile") and 0 or 0.15
		setT(rig, "LegFL", ANG(swing, 0, 0))
		setT(rig, "LegBR", ANG(swing * (1 - diag), 0, 0))
		setT(rig, "LegFR", ANG(-swing, 0, 0))
		setT(rig, "LegBL", ANG(-swing * (1 - diag), 0, 0))
		local bob = abs(sin(p * 2)) * 0.12 * size * 0.08 * walk
		local sway = (tmpl == "Reptile") and sin(p * 2) * 0.12 * walk or 0
		local lean = 0
		if state == "Windup" then
			lean = 0.15
			setT(rig, "LegFL", ANG(-0.4, 0, 0))
			setT(rig, "LegFR", ANG(-0.4, 0, 0))
		elseif state == "Charge" then
			lean = -0.12
		end
		setT(rig, "Root", CF(0, bob + breathe * 0.4, 0) * ANG(lean, sway, 0))
	end

	-- หัว: มองผู้เล่นที่ใกล้ + กัด/คำราม
	local neckPitch, neckYaw = sin(p * 2) * 0.05 * walk + breathe, 0
	if state == "Graze" then
		neckPitch = 0.55 + sin(now * 1.5) * 0.05
	end
	if playerPos then
		local toP = playerPos - root.Position
		if toP.Magnitude < 45 then
			local localDir = root.CFrame:VectorToObjectSpace(toP)
			neckYaw = clamp(math.atan2(-localDir.X, -localDir.Z), -0.7, 0.7)
		end
	end
	local jaw = 0
	if kind == "Bite" or kind == "Spit" or kind == "Leap" then
		neckPitch += att * 0.35
		jaw = att * 0.7
	elseif kind == "Roar" then
		neckPitch -= att * 0.55
		jaw = att * 0.9
	elseif kind == "Stare" then
		neckPitch = -0.1
		neckYaw += sin(now * 0.8) * 0.05 + att * 0.35 -- เอียงคอช้าๆ น่ากลัว
	end
	setT(rig, "Neck", ANG(neckPitch, neckYaw, kind == "Stare" and att * 0.5 or 0))
	setT(rig, "Jaw", ANG(jaw, 0, 0))

	-- หาง
	local wag = sin(now * (state == "Chase" and 9 or 3) + rig.Seed) * (0.25 + 0.2 * walk)
	if tmpl == "Reptile" then
		for i = 1, 3 do
			setT(rig, "Tail" .. i, ANG(0, sin(now * 2.4 - i * 0.9 + p) * (0.18 + 0.12 * walk), 0))
		end
	else
		setT(rig, "Tail1", ANG(-0.15 + sin(now * 2) * 0.08, wag, 0))
	end
end

function AnimalAnimator.Init()
	for _, m in ipairs(CollectionService:GetTagged("Animal")) do
		add(m)
	end
	CollectionService:GetInstanceAddedSignal("Animal"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("Animal"):Connect(function(m)
		rigs[m] = nil
	end)
	local player = Players.LocalPlayer
	RunService.Stepped:Connect(function(_, dt)
		local now = os.clock()
		local cam = Workspace.CurrentCamera.CFrame.Position
		local char = player.Character
		local playerPos = char and char:GetPivot().Position
		for model, rig in pairs(rigs) do
			if not model.Parent then
				rigs[model] = nil
			elseif (rig.Root.Position - cam).Magnitude < 420 then
				local ok, err = pcall(animate, rig, now, dt, cam, playerPos)
				if not ok then
					rigs[model] = nil
					warn("[AS] anim", err)
				elseif rig.Clip and (not rig.DeadT or ClipAnimator.HasDeath(rig)) then
					local vel = rig.Root.AssemblyLinearVelocity
					ClipAnimator.Animate(rig, dt, Vector3.new(vel.X, 0, vel.Z).Magnitude)
				elseif model:GetAttribute("SkinRig") == "Static" then
					-- โมเดลนิ่งจาก Store (ไม่มีกระดูก): เดิน = เด้งตามก้าว + โยกซ้ายขวา + โน้มตัวไปข้างหน้า · ยืน = หายใจ
					--   ผสมนุ่มตามความเร็วจริง (ไม่สลับท่าขวับ) + หันตัวนุ่ม (ภาพหมุนตามตัวจริงแบบหน่วง ไม่หันขวับ)
					local j = rig.Root:FindFirstChild("SkinJoint")
					if j then
						local vel = rig.Root.AssemblyLinearVelocity
						local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
						local h = math.max(rig.Size.Y, 1)
						rig.MoveW = (rig.MoveW or 0) + (math.clamp((speed - 0.8) / 6, 0, 1) - (rig.MoveW or 0)) * math.min(1, dt * 6)
						local w = rig.MoveW
						rig.HopT = (rig.HopT or 0) + dt * (1.6 + math.clamp(speed / h, 0, 5) * 2.4)
						local ph = rig.HopT
						local bounce = math.abs(math.sin(ph)) * h * 0.08 * w
						local breathe = (math.sin(ph * 0.8) + 1) * h * 0.008 * (1 - w)
						local look = rig.Root.CFrame.LookVector
						local yaw = math.atan2(-look.X, -look.Z)
						rig.VisYaw = rig.VisYaw or yaw
						rig.VisYaw += ((yaw - rig.VisYaw + math.pi) % (2 * math.pi) - math.pi) * math.min(1, dt * 8)
						local lag = math.clamp(((rig.VisYaw - yaw + math.pi) % (2 * math.pi)) - math.pi, -0.7, 0.7)
						rig.VisYaw = yaw + lag
						j.Transform = CFrame.new(0, bounce + breathe, 0)
							* CFrame.Angles(-0.07 * w + math.sin(ph * 2) * 0.04 * w, lag + math.sin(ph) * 0.06 * w, math.sin(ph) * 0.1 * w - lag * 0.25)
					end
				elseif rig.Boss then
					local vel = rig.Root.AssemblyLinearVelocity
					local okB, errB = pcall(BossAnimator.Animate, rig, {
						Now = now, Dt = dt, Speed = Vector3.new(vel.X, 0, vel.Z).Magnitude,
						Flying = model:GetAttribute("Flying") and not model:GetAttribute("Grounded"), DeadT = rig.DeadT,
					})
					if not okB then
						warn("[AS] boss anim", rig.Id, errB)
						rig.Boss = nil
					end
				end
			end
		end
	end)
end

return AnimalAnimator
