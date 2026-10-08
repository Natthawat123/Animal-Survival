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
				end
			end
		end
	end)
end

return AnimalAnimator
