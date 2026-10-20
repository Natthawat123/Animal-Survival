--[[
	ClipAnimator — เล่นท่าที่ดึงจากไฟล์ GLB (Shared/AnimalClips/<Id>) ให้สัตว์ผิว+กระดูก (SkinRig = "Clip")
	ตั้ง Bone.Transform ทุกเฟรม ผสมระหว่างเฟรม (ตำแหน่ง lerp + การหมุน slerp) · ความเร็วท่าตามความเร็วเดินจริง
	ท่าที่ได้จาก Meshy เป็นท่าเดิน: ยืนนิ่ง = เล่นช้ามาก (หายใจ) · วิ่ง = เล่นเร็วขึ้น
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VFXLib = require(script.Parent:WaitForChild("VFXLib"))

local ClipAnimator = {}

---------------------------------------------------------------- ท่าโจมตี (ซ้อนบนท่าเดิน)
-- หมุนกระดูกรอบแกนของตัวสัตว์ (X = ขวา, Y = ขึ้น, หน้า = -Z) · บวกที่ X = เงยขึ้น · Hips = เลื่อนทั้งตัว (หน่วยโมเดล 2 = ทั้งตัว)
-- เซิร์ฟเวอร์ลดเลือดหลังเริ่มท่า 0.3 วินาที -> จังหวะกระแทก (Hit) อยู่ที่ ~0.3
local function ease(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local R = CFrame.Angles
local ATTACK_LEN = 0.85
local DUST = "rbxasset://textures/particles/smoke_main.dds"
local DUST_COLOR = {
	Earth = { Color3.fromRGB(196, 176, 138), Color3.fromRGB(150, 132, 104) },
	Snow = { Color3.fromRGB(240, 248, 255), Color3.fromRGB(196, 220, 240) },
	Ash = { Color3.fromRGB(150, 120, 104), Color3.fromRGB(90, 70, 64) },
}
local function dustEmitter(parent, size, kind)
	local c = DUST_COLOR[kind or "Earth"] or DUST_COLOR.Earth
	local e = Instance.new("ParticleEmitter")
	e.Texture = DUST
	e.Color = ColorSequence.new(c[1], c[2])
	e.LightInfluence = 0.6
	e.Lifetime = NumberRange.new(0.5, 1.1)
	e.Speed = NumberRange.new(4 * size, 9 * size)
	e.SpreadAngle = Vector2.new(25, 35)
	e.Acceleration = Vector3.new(0, 3, 0)
	e.Drag = 3
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * size), NumberSequenceKeypoint.new(1, 2.4 * size) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Rate = 0
	e.Parent = parent
	return e
end
-- ฝุ่นฟุ้งรอบจุดกระแทก (แทนเอฟเฟกต์สีดำ/เลือด)
local function dustBurst(pos, size, kind)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	local e = dustEmitter(p, size, kind)
	e.Shape = Enum.ParticleEmitterShape.Disc
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(80, 80)
	e:Emit(26)
	game:GetService("Debris"):AddItem(p, 2)
end
-- w = ง้าง (0->1 ใน 0.25s) · k = กระแทก (0.25-0.38) · ค่อยกลับท่าเดิม
-- กระแทกแบบเด้งเกินนิดหน่อย (back-ease) แล้วค่อยคืนท่า = ดูมีน้ำหนัก ไม่แข็ง
local function backOut(x)
	x = math.clamp(x, 0, 1) - 1
	return 1 + x * x * (2.4 * x + 1.4)
end
local function phases(t)
	local w = t < 0.25 and ease(t / 0.25) or (t < 0.36 and 1 - ease((t - 0.25) / 0.11) or 0)
	local k = t < 0.25 and 0 or (t < 0.36 and backOut((t - 0.25) / 0.11) or 1 - ease((t - 0.36) / (ATTACK_LEN - 0.36)))
	return w, k
end
local ATTACKS = {
	-- กวางผลึก: ยืนสองขาหลังเงยเขา แล้วพุ่งขวิดด้วยเขาผลึกไปข้างหน้า
	MossWolf = {
		Pose = function(t)
			local w, k = phases(t)
			return {
				Hips = R(0.35 * w - 0.12 * k, 0, 0), chest = R(0.2 * w - 0.25 * k, 0, 0), head = R(0.35 * w - 0.75 * k, 0, 0),
				frontleg = R(0.6 * w - 0.3 * k, 0, 0), R_frontleg = R(0.6 * w - 0.3 * k, 0, 0),
			}, Vector3.new(0, 0.05 * w, 0.18 * w - 0.4 * k)
		end,
		Fx = { { "VFXPack/Anime/Shiny-01", 1.8, 0.25 }, { "VFXPack/Anime/Shield-Break-01", 1.4, 0.2 } }, FxAt = 1.0,
	},
	-- จระเข้ศิลา: อ้าปากเงยหัว แล้วงับพุ่ง + สะบัดหัวซ้ายขวา หางฟาดสวน
	Thornboar = {
		Pose = function(t)
			local w, k = phases(t)
			local shake = math.sin(t * 38) * k * 0.45
			return {
				chest = R(0.25 * w - 0.1 * k, shake * 0.5, 0), head = R(0.8 * w - 0.4 * k, shake, 0),
				tail = R(0, -shake * 0.8 - 0.3 * w, 0), tailstart = R(0, -shake * 0.6, 0),
			}, Vector3.new(0, 0.04 * w, 0.12 * w - 0.35 * k)
		end,
		Fx = {}, Dust = 1.1, FxAt = 1.05, Ground = true, -- ไม่มีเลือด: ฝุ่นดินฟุ้งตอนงับ
		-- ตั้งท่าพุ่ง (Windup 0.8s): ย่อตัวต่ำ หัวก้ม หางส่าย · พุ่ง (Charge): โน้มตัวไปหน้า หัวยื่น ฝุ่นกระเด็นออกสองข้าง
		States = {
			Windup = function(t)
				local wag = math.sin(t * 14)
				return { Hips = R(-0.05, 0, 0), chest = R(-0.12, wag * 0.06, 0), head = R(-0.15, -wag * 0.08, 0), tail = R(0, wag * 0.45, 0), tailstart = R(0, wag * 0.3, 0) },
					Vector3.new(0, -0.05, 0.06)
			end,
			Charge = function(t)
				local sway = math.sin(t * 18)
				return { chest = R(-0.1, sway * 0.08, 0), head = R(0.12, -sway * 0.1, 0), tail = R(0, -sway * 0.35, 0), tailstart = R(0, -sway * 0.2, 0) },
					Vector3.new(0, -0.02, -0.04)
			end,
		},
		ChargeDust = true,
	},
	-- เต่าหินภูผา: ยกตัวหน้าขึ้นสูง แล้วกระแทกลงพื้นจนพื้นแตก
	StoneBear = {
		Pose = function(t)
			local w, k = phases(t)
			return {
				Hips = R(0.3 * w - 0.06 * k, 0, 0), chest = R(0.3 * w - 0.12 * k, 0, 0), head = R(0.25 * w - 0.2 * k, 0, 0),
				frontleg = R(0.7 * w, 0, 0), R_frontleg = R(0.7 * w, 0, 0),
			}, Vector3.new(0, 0.06 * w - 0.05 * k, 0)
		end,
		Fx = {}, Dust = 2.2, FxAt = 0.7, Ground = true, -- ฝุ่นดินฟุ้งรอบตัว (เอฟเฟกต์วงหินมีรอยแตกดำบนพื้น เอาออก)
	},
}

-- เอียงตัวตามพื้น: ยิงหาพื้นใต้หัว/ท้าย/ซ้าย/ขวา -> หมุนสะโพกให้ตัวขนานพื้น + ยกขึ้นถ้าพื้นใต้ตัวสูงกว่า (ไม่จมเนินดิน)
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }
local function groundY(pos)
	local hit = workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -24, 0), groundParams)
	return hit and hit.Position.Y
end
local function updateSlope(rig, C, dt)
	C.SlopeTick = (C.SlopeTick or 0) - dt
	if C.SlopeTick <= 0 then
		C.SlopeTick = 0.08
		local root = rig.Root
		local cf = root.CFrame
		local size = C.Extent or rig.Model:GetExtentsSize()
		C.Extent = size
		local half = math.max(size.Z, size.X) * 0.4
		local side = math.min(size.X, size.Z) * 0.4
		local hum = rig.Model:FindFirstChildOfClass("Humanoid")
		local feet = root.Position.Y - root.Size.Y / 2 - (hum and hum.HipHeight or 0)
		local fy, by = groundY(cf.Position + cf.LookVector * half), groundY(cf.Position - cf.LookVector * half)
		local ly, ry = groundY(cf.Position - cf.RightVector * side), groundY(cf.Position + cf.RightVector * side)
		local cy = groundY(cf.Position)
		local pitch, roll, lift = 0, 0, 0
		if fy and by then
			pitch = math.clamp(math.atan2(fy - by, half * 2), -0.6, 0.6)
		end
		if ly and ry then
			roll = math.clamp(math.atan2(ry - ly, side * 2), -0.4, 0.4)
		end
		-- ยกให้พ้นพื้นที่สูงสุดใต้ตัว (ค่าเฉลี่ยกลาง/หัว/ท้าย) ไม่ให้ส่วนใดจม
		local top = math.max(cy or feet, ((fy or feet) + (by or feet)) / 2)
		lift = math.clamp(top - feet, 0, 3)
		C.SlopeTarget = { pitch, roll, lift }
	end
	local t = C.SlopeTarget or { 0, 0, 0 }
	local k = math.min(1, dt * 8)
	C.Pitch = (C.Pitch or 0) + (t[1] - (C.Pitch or 0)) * k
	C.Roll = (C.Roll or 0) + (t[2] - (C.Roll or 0)) * k
	C.Lift = (C.Lift or 0) + (t[3] - (C.Lift or 0)) * k
end

-- ท่าแบบใช้ซ้ำ ----------------------------------------------------------------
-- ตะครุบกัด: ย่อตัว ยกขาหน้า แล้วพุ่งงับ
local function pounce(t)
	local w, k = phases(t)
	return {
		Hips = R(0.25 * w - 0.1 * k, 0, 0), chest = R(0.15 * w - 0.2 * k, 0, 0), head = R(0.3 * w - 0.55 * k, 0, 0),
		frontleg = R(0.55 * w - 0.25 * k, 0, 0), R_frontleg = R(0.55 * w - 0.25 * k, 0, 0), tail = R(0.3 * w, 0, 0),
	}, Vector3.new(0, 0.06 * w, 0.15 * w - 0.38 * k)
end
-- ขวิด/โขกหัว: เงยหัว แล้วโขกลงแรงๆ
local function headbutt(t)
	local w, k = phases(t)
	return {
		chest = R(0.2 * w - 0.15 * k, 0, 0), head = R(0.45 * w - 0.6 * k, 0, 0),
		frontleg = R(0.35 * w, 0, 0), R_frontleg = R(0.15 * w, 0, 0),
	}, Vector3.new(0, 0.05 * w, 0.12 * w - 0.32 * k)
end
-- ยืนสองขาแล้วตบลงพื้น
local function slam(t)
	local w, k = phases(t)
	return {
		Hips = R(0.4 * w - 0.08 * k, 0, 0), chest = R(0.3 * w - 0.15 * k, 0, 0), head = R(0.2 * w - 0.25 * k, 0, 0),
		frontleg = R(0.9 * w - 0.1 * k, 0, 0), R_frontleg = R(0.9 * w - 0.1 * k, 0, 0),
	}, Vector3.new(0, 0.08 * w - 0.05 * k, 0)
end
-- แมงป่อง: งอหางขึ้นแล้วตวัดแทงไปข้างหน้า ก้ามยกขึ้น
local function tailStrike(t)
	local w, k = phases(t)
	return {
		tail = R(0.35 * w - 0.25 * k, 0, 0), tailstart = R(0.3 * w - 0.35 * k, 0, 0), tail1 = R(0.25 * w - 0.4 * k, 0, 0),
		tail2 = R(0.2 * w - 0.35 * k, 0, 0), frontleg = R(0.4 * w, 0, 0), R_frontleg = R(0.4 * w, 0, 0), chest = R(0.1 * w - 0.1 * k, 0, 0),
	}, Vector3.new(0, 0.03 * w, 0.05 * w - 0.12 * k)
end
-- สายพุ่งชน: ตั้งท่า (ก้มหัว ตะกุยพื้น) -> พุ่ง (โน้มตัว ฝุ่นกระเด็นสองข้าง)
local CHARGE_STATES = {
	Windup = function(t)
		local paw = math.max(0, math.sin(t * 12))
		return { Hips = R(-0.04, 0, 0), chest = R(-0.12, 0, 0), head = R(-0.3, 0, 0), frontleg = R(0.5 * paw, 0, 0), tail = R(0, math.sin(t * 10) * 0.3, 0) },
			Vector3.new(0, -0.04, 0.05)
	end,
	Charge = function(t)
		local sway = math.sin(t * 16)
		return { chest = R(-0.12, sway * 0.06, 0), head = R(-0.25, -sway * 0.06, 0), tail = R(0.2, -sway * 0.3, 0) }, Vector3.new(0, -0.02, -0.04)
	end,
}
ATTACKS.EmberFox = { Pose = pounce, Fx = { { "VFXPack/Anime/Fire-01", 0.9, 0.2 } }, Dust = 0.8, DustKind = "Ash", FxAt = 1.0 }
ATTACKS.MagmaRhino = { Pose = headbutt, Fx = { { "VFXPack/Anime/Fire-02", 1.0, 0.25 } }, Dust = 1.4, DustKind = "Ash", FxAt = 1.0, Ground = true,
	States = CHARGE_STATES, ChargeDust = true }
ATTACKS.LavaSalamander = { Pose = tailStrike, Fx = { { "VFXPack/Anime/Fire-01", 0.8, 0.2 } }, FxAt = 0.9 }
ATTACKS.GaleHawk = { Pose = slam, Fx = { { "IceStomp", 1.6, 0.3 } }, Dust = 1.8, DustKind = "Snow", FxAt = 0.75, Ground = true }
ATTACKS.SkyLynx = { Pose = pounce, Fx = { { "VFXPack/Anime/Shiny-01", 1.4, 0.2 } }, Dust = 0.9, DustKind = "Snow", FxAt = 1.0 }
ATTACKS.StormRam = { Pose = headbutt, Fx = { { "IceStomp", 1.1, 0.25 } }, Dust = 1.4, DustKind = "Snow", FxAt = 1.0, Ground = true,
	States = CHARGE_STATES, ChargeDust = true }

local clips = {}
local function clipFor(id)
	if clips[id] == nil then
		clips[id] = false
		local folder = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("AnimalClips")
		local mod = folder and folder:FindFirstChild(id)
		if mod then
			local ok, data = pcall(require, mod)
			if ok and data and data.Bones then
				-- แปลงเป็น CFrame ล่วงหน้า (ไม่ต้องสร้างใหม่ทุกเฟรม)
				local bones = {}
				for name, frames in pairs(data.Bones) do
					local list = {}
					for i, f in ipairs(frames) do
						list[i] = CFrame.new(f[1], f[2], f[3], f[4], f[5], f[6], f[7])
					end
					bones[name] = list
				end
				clips[id] = { Fps = data.Fps, Frames = data.Frames, Bones = bones }
			end
		end
	end
	return clips[id] or nil
end

function ClipAnimator.Has(model)
	return model:GetAttribute("SkinRig") == "Clip" and clipFor(model:GetAttribute("AnimalId") or "") ~= nil
end

function ClipAnimator.Attach(rig)
	local clip = clipFor(rig.Id or "")
	local mesh = rig.Model:FindFirstChild("Skin")
	if not (clip and mesh) then
		return false
	end
	local scale = rig.Model:GetAttribute("SkinScale") or 1
	local tracks = {}
	for _, b in ipairs(mesh:GetDescendants()) do
		if b:IsA("Bone") and clip.Bones[b.Name] then
			table.insert(tracks, { Bone = b, Frames = clip.Bones[b.Name] })
		end
	end
	-- ทิศท่ายืนของกระดูก (เทียบตัวสัตว์) ไว้แปลงท่าโจมตีจากแกนตัวสัตว์ -> แกนกระดูก
	local root = rig.Root
	local rest = {}
	for _, b in ipairs(mesh:GetDescendants()) do
		if b:IsA("Bone") then
			b.Transform = CFrame.identity
		end
	end
	for _, b in ipairs(mesh:GetDescendants()) do
		if b:IsA("Bone") then
			local q = root.CFrame:ToObjectSpace(b.WorldCFrame).Rotation
			rest[b.Name] = { Q = q, Qi = q:Inverse() }
		end
	end
	for _, tr in ipairs(tracks) do
		tr.Rest = rest[tr.Bone.Name]
	end
	rig.Clip = { Data = clip, Tracks = tracks, T = math.random() * 2, Scale = scale, Rate = 0, Attack = ATTACKS[rig.Id], LastAttack = rig.AttackT, StateW = 0 }
	local A = ATTACKS[rig.Id]
	if A and A.ChargeDust then
		-- ฝุ่นพุ่งออกด้านซ้าย/ขวาจากเท้าตอนวิ่งพุ่ง
		local size = rig.Model:GetExtentsSize()
		local low = -(root.Size.Y / 2) - (rig.Model:FindFirstChildOfClass("Humanoid") and rig.Model:FindFirstChildOfClass("Humanoid").HipHeight or 0) + 0.3
		rig.Clip.Dust = {}
		for _, side in ipairs({ -1, 1 }) do
			local att = Instance.new("Attachment")
			att.CFrame = CFrame.new(side * size.X * 0.45, low, 0) * CFrame.Angles(0, 0, -side * math.rad(70)) -- เอียงพ่นออกด้านข้าง + ขึ้นนิดหน่อย
			att.Parent = root
			local e = dustEmitter(att, math.max(size.X, 2) / 4, A.DustKind)
			e.EmissionDirection = Enum.NormalId.Top
			table.insert(rig.Clip.Dust, e)
		end
	end
	return true
end

-- เรียกทุกเฟรม: speed = ความเร็วเดินแนวราบ (studs/วินาที)
function ClipAnimator.Animate(rig, dt, speed)
	local C = rig.Clip
	if not C then
		return
	end
	local data = C.Data
	-- ยืน = 0.15 เท่า (ขยับเบาๆ ไม่แข็ง) · เดิน/วิ่ง = ตามความเร็ว (ขาไม่ไถลพื้น)
	local target = speed < 0.6 and 0.15 or math.clamp(speed / (5 * C.Scale), 0.5, 2.2)
	C.Rate += (target - C.Rate) * math.min(1, dt * 6)
	C.T = (C.T + dt * C.Rate) % ((data.Frames - 1) / data.Fps)
	local f = C.T * data.Fps
	local i0 = math.floor(f)
	local u = f - i0
	local n = data.Frames
	-- ท่าโจมตี: เริ่มเมื่อเซิร์ฟเวอร์ส่ง AttackAt (rig.AttackT) · ซ้อนบนท่าเดิน
	local pose, shift
	local A = C.Attack
	local state = rig.Model:GetAttribute("State")
	local statePose = A and A.States and A.States[state]
	if A and rig.AttackT and rig.AttackT > 0 and not (statePose and rig.AttackKind == "Roar") then
		if rig.AttackT ~= C.LastAttack then
			C.LastAttack = rig.AttackT
			task.delay(0.28, function()
				local root = rig.Root
				if not (root and root.Parent) then
					return
				end
				local size = rig.Model:GetExtentsSize()
				local reach = root.CFrame.LookVector * (math.max(size.X, size.Z) * 0.5 * (A.FxAt or 1))
				local pos = root.Position + reach
				if A.Ground then
					pos -= Vector3.new(0, root.Size.Y / 2 + (rig.Model:FindFirstChildOfClass("Humanoid") and rig.Model:FindFirstChildOfClass("Humanoid").HipHeight or 0), 0)
				end
				for _, fx in ipairs(A.Fx) do
					pcall(VFXLib.Play, fx[1], CFrame.new(pos), { Scale = fx[2] * C.Scale / 3, Duration = fx[3] })
				end
				if A.Dust then
					dustBurst(pos, A.Dust * C.Scale / 3, A.DustKind)
				end
			end)
		end
		local at = os.clock() - rig.AttackT
		if at < ATTACK_LEN then
			pose, shift = A.Pose(at)
		end
	end
	-- ท่าตามสถานะ (ตั้งท่า/พุ่ง) ผสมเข้า-ออกนุ่มๆ
	C.StateW += ((statePose and 1 or 0) - C.StateW) * math.min(1, dt * 8)
	if statePose then
		C.StateT = (C.StateName == state) and (C.StateT + dt) or 0
		C.StateName = state
	end
	if C.StateW > 0.01 and not pose and C.StateName then
		local f2 = A.States[C.StateName]
		local sp, ss = f2(C.StateT or 0)
		local wgt = C.StateW
		pose = {}
		for k, v in pairs(sp) do
			pose[k] = CFrame.identity:Lerp(v, wgt)
		end
		shift = ss * wgt
	end
	if C.Dust then
		local on = state == "Charge" and speed > 4
		for _, e in ipairs(C.Dust) do
			e.Rate = on and 45 or 0
		end
	end
	updateSlope(rig, C, dt)
	-- หันตัวนุ่ม: ตัวจริงหันขวับได้ แต่ภาพค่อยๆ หมุนตาม (หน่วงไม่เกิน ~45°)
	local look = rig.Root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	C.VisYaw = C.VisYaw or yaw
	local diff = (yaw - C.VisYaw + math.pi) % (2 * math.pi) - math.pi
	C.VisYaw += diff * math.min(1, dt * 10)
	local lag = math.clamp(((C.VisYaw - yaw + math.pi) % (2 * math.pi)) - math.pi, -0.8, 0.8)
	C.VisYaw = yaw + lag
	local slopeRot = R(0, lag, 0) * R(C.Pitch, 0, C.Roll)
	local slopeLift = Vector3.new(0, C.Lift, 0)
	for _, tr in ipairs(C.Tracks) do
		local a = tr.Frames[i0 + 1] or tr.Frames[n]
		local b = tr.Frames[i0 + 2] or tr.Frames[1]
		local cf = a:Lerp(b, u)
		-- ตำแหน่งในท่าเป็นค่าที่ขนาดตอน Import -> คูณตามที่เกมขยายโมเดล
		local tf = cf.Rotation + cf.Position * C.Scale
		local rs = tr.Rest
		if pose and rs then
			local extra = pose[tr.Bone.Name]
			if extra then
				tf = rs.Qi * extra * rs.Q * tf
			end
			if shift and tr.Bone.Name == "Hips" then
				tf = CFrame.new(rs.Qi:VectorToWorldSpace(shift * C.Scale)) * tf
			end
		end
		if rs and tr.Bone.Name == "Hips" then
			-- เอียงทั้งตัวตามพื้น + ยกพ้นเนิน (ซ้อนทับท่าเดิน/โจมตี)
			tf = CFrame.new(rs.Qi:VectorToWorldSpace(slopeLift)) * (rs.Qi * slopeRot * rs.Q) * tf
		end
		tr.Bone.Transform = tf
	end
end

return ClipAnimator
