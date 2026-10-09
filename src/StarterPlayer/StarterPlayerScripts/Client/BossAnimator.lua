--[[
	BossAnimator — ขยับกระดูกบอสที่มีผิว (Import 3D) ฝั่ง client ทุกเฟรม (ไม่ต้องอัปแอนิเมชัน)
	  BossAnimator.Attach(rig)          เรียกครั้งเดียวตอนบอสโผล่ (rig จาก AnimalAnimator)
	  BossAnimator.Animate(rig, ctx)    ทุกเฟรม: ctx = { Now, Dt, Speed, Flying, DeadT }

	- ท่าทุกท่าคำนวณเป็น "เป้าหมาย" แล้วไหลเข้าหาแบบนุ่ม (ไม่กระตุกตอนเปลี่ยนท่า)
	- หัว/คอหันมองผู้เล่นตลอด
	- ท่าร่ายสกิลอ่านจาก attribute Cast / CastAt / CastTime (เซิร์ฟเวอร์ตั้งใน BossAbilities) -> ง้าง -> กระแทก -> คืนตัว
	หมุนด้วยแกนของตัวบอส (หน้า = -Z, ขึ้น = +Y, ขวา = +X) แล้วแปลงเป็นแกนของแต่ละกระดูก
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BossFX = require(script.Parent:WaitForChild("BossFX"))

local BossAnimator = {}

local sin, cos, max, abs, clamp, atan2, exp = math.sin, math.cos, math.max, math.abs, math.clamp, math.atan2, math.exp
local ANG = CFrame.Angles
local V = Vector3.new

-- บทบาท -> ชื่อกระดูกในไฟล์ (ตรงกับ blender/prep_boss.py)
local ROLES = {
	Terragon = {
		Hips = "Bone_000", Spine1 = "Bone_014", Spine2 = "Bone_013", Chest = "Bone_011", Neck = "Bone_032", Head = "Bone_031",
		UpperArmR = "Bone_036", ForeArmR = "Bone_035", UpperArmL = "Bone_041", ForeArmL = "Bone_040",
		ThighR = "Bone_006", ShinR = "Bone_005", ThighL = "Bone_010", ShinL = "Bone_009", FootR = "Bone_004", FootL = "Bone_008",
	},
	TempestRoc = {
		Hips = "Bone_000", Spine1 = "Bone_002", Spine2 = "Bone_001", Chest = "Bone_004", Neck = "Bone_003", Head = "Bone_015",
		UpperArmR = "Bone_019", ForeArmR = "Bone_018", UpperArmL = "Bone_024", ForeArmL = "Bone_023",
		ThighR = "Bone_013", ShinR = "Bone_012", ThighL = "Bone_009", ShinL = "Bone_008", FootR = "Bone_011", FootL = "Bone_007",
	},
	Solfang = {
		Hips = "Bone_000", Spine1 = "Bone_005", Spine2 = "Bone_004", Chest = "Bone_002",
		Neck1 = "Bone_032", Neck2 = "Bone_031", Neck3 = "Bone_030", Neck4 = "Bone_029", Head = "Bone_027", Jaw = "Bone_026",
		ArmR1 = "Bone_042", ArmR2 = "Bone_040", ArmL1 = "Bone_037", ArmL2 = "Bone_035",
		WingR1 = "Bone_046", WingR2 = "Bone_045", WingR3 = "Bone_044", WingL1 = "Bone_050", WingL2 = "Bone_049", WingL3 = "Bone_048",
		ThighR = "Bone_015", ShinR = "Bone_014", ThighL = "Bone_010", ShinL = "Bone_009",
		Tail1 = "Bone_024", Tail2 = "Bone_023", Tail3 = "Bone_022", Tail4 = "Bone_021", Tail5 = "Bone_020", Tail6 = "Bone_019", Tail7 = "Bone_018",
	},
	Leviathan = {
		Root = "Bone_000", Neck = "Bone_001", Head = "Bone_003", Jaw = "Bone_007",
		Body1 = "Bone_005", Body2 = "Bone_004", Body3 = "Bone_011", Body4 = "Bone_010", Body5 = "Bone_023", Body6 = "Bone_022",
		Tail1 = "Bone_038", Tail2 = "Bone_037", Tail3 = "Bone_036",
		FlipperFR = "Bone_016", FlipperFL = "Bone_021", FlipperBR = "Bone_031", FlipperBL = "Bone_035",
	},
}

local function smooth(x)
	x = clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function BossAnimator.Has(model)
	return model:GetAttribute("Skinned") == true and ROLES[model:GetAttribute("AnimalId")] ~= nil
end

function BossAnimator.Attach(rig)
	local model = rig.Model
	local mesh = model:FindFirstChild("Skin")
	local map = ROLES[rig.Id]
	if not (mesh and map) then
		return false
	end
	local byName = {}
	for _, d in ipairs(mesh:GetDescendants()) do
		if d:IsA("Bone") then
			byName[d.Name] = d
		end
	end
	local root = rig.Root
	local bones = {}
	for role, name in pairs(map) do
		local b = byName[name]
		if b then
			local rest = root.CFrame:ToObjectSpace(b.WorldCFrame).Rotation
			bones[role] = { Bone = b, Rest = rest, RestInv = rest:Inverse(), Cur = { 0, 0, 0, 0, 0, 0 } }
		end
	end
	rig.Boss = {
		Bones = bones, Kind = model:GetAttribute("SkinRig") or "Biped", Phase = 0,
		H = mesh.Size.Y, L = math.max(mesh.Size.X, mesh.Size.Z), Look = { 0, 0 }, Element = model:GetAttribute("Element"),
	}
	pcall(BossFX.Aura, model, model:GetAttribute("Element"))
	return true
end

---------------------------------------------------------------- ท่า (เป้าหมาย)
-- P[role] = { pitch, yaw, roll, dx, dy, dz }  (หน่วยมุม = เรเดียน, ระยะ = studs ในแกนตัวบอส)
local function add(P, role, x, y, z, dx, dy, dz)
	local e = P[role]
	if not e then
		e = { 0, 0, 0, 0, 0, 0 }
		P[role] = e
	end
	e[1] += x or 0
	e[2] += y or 0
	e[3] += z or 0
	e[4] += dx or 0
	e[5] += dy or 0
	e[6] += dz or 0
end

-- น้ำหนักท่าร่าย: A = ช่วงง้าง, Hh = ช่วงกระแทก (หายไปเองหลังคืนตัว)
local function castWeights(age, w)
	local A = smooth(age / (w * 0.75)) * (1 - smooth((age - w) / 0.15))
	local Hh = smooth((age - w) / 0.12) * (1 - smooth((age - w - 0.35) / 0.6))
	return A, Hh
end

local function biped(P, B, t, w, ph, cast, age, cw)
	local H = B.H
	local sw = sin(ph)
	-- หายใจ + ถ่ายน้ำหนัก (ยืนนิ่งก็ยังมีชีวิต)
	local breathe = sin(t * 1.3)
	local shift = sin(t * 0.45)
	add(P, "Chest", breathe * 0.05, 0, 0)
	add(P, "Spine2", breathe * 0.02, 0, 0)
	add(P, "Hips", 0, 0, shift * 0.035 * (1 - w), shift * 0.012 * H * (1 - w), breathe * 0.004 * H)
	add(P, "UpperArmL", sin(t * 0.9) * 0.05, 0, -0.14 + breathe * 0.03)
	add(P, "UpperArmR", sin(t * 0.9 + 1) * 0.05, 0, 0.14 - breathe * 0.03)
	add(P, "ForeArmL", 0.3, 0, 0)
	add(P, "ForeArmR", 0.3, 0, 0)
	-- เดิน: ก้าวยาว ย่อตัว แกว่งแขนสวน บิดลำตัว
	if w > 0.02 then
		add(P, "ThighL", sw * 0.6 * w, 0, 0)
		add(P, "ThighR", -sw * 0.6 * w, 0, 0)
		add(P, "ShinL", -max(0, cos(ph)) * 0.95 * w, 0, 0)
		add(P, "ShinR", -max(0, -cos(ph)) * 0.95 * w, 0, 0)
		add(P, "UpperArmL", -sw * 0.5 * w, 0, 0)
		add(P, "UpperArmR", sw * 0.5 * w, 0, 0)
		add(P, "ForeArmL", max(0, -sw) * 0.4 * w, 0, 0)
		add(P, "ForeArmR", max(0, sw) * 0.4 * w, 0, 0)
		add(P, "Hips", 0, sw * 0.08 * w, sin(ph) * 0.05 * w, 0, (abs(cos(ph)) - 0.6) * 0.035 * H * w)
		add(P, "Spine1", -0.06 * w, -sw * 0.06 * w, 0)
		add(P, "Chest", 0, -sw * 0.08 * w, 0)
		-- เท้าลงพื้นทุกครึ่งรอบ: ฝุ่น + จอสั่น
		local step = math.floor(ph / math.pi)
		if B.LastStep ~= step then
			B.LastStep = step
			if w > 0.25 then
				local foot = B.Bones[(step % 2 == 0) and "FootL" or "FootR"]
				if foot then
					pcall(BossFX.Footstep, foot.Bone.WorldPosition, H / 50, B.Element)
				end
			end
		end
	end
	if not cast then
		return
	end
	local A, Hh = castWeights(age, cw)
	if cast == "Slam" then
		-- ง้างแขนเหนือหัว เอนหลัง -> ทุบลงพื้น ย่อตัว
		add(P, "UpperArmL", 2.7 * A + 0.7 * Hh, 0, 0.25 * A)
		add(P, "UpperArmR", 2.7 * A + 0.7 * Hh, 0, -0.25 * A)
		add(P, "ForeArmL", 0.5 * A, 0, 0)
		add(P, "ForeArmR", 0.5 * A, 0, 0)
		add(P, "Spine1", 0.15 * A - 0.35 * Hh, 0, 0)
		add(P, "Spine2", 0.15 * A - 0.3 * Hh, 0, 0)
		add(P, "Chest", 0.12 * A - 0.2 * Hh, 0, 0)
		add(P, "Head", 0.2 * A - 0.25 * Hh, 0, 0)
		add(P, "Hips", 0, 0, 0, 0, 0.03 * H * A - 0.09 * H * Hh)
		add(P, "ThighL", 0.45 * Hh, 0, -0.1 * Hh)
		add(P, "ThighR", 0.45 * Hh, 0, 0.1 * Hh)
		add(P, "ShinL", -0.8 * Hh, 0, 0)
		add(P, "ShinR", -0.8 * Hh, 0, 0)
	elseif cast == "Roar" or cast == "Summon" then
		local k = max(A, Hh)
		local shake = sin(t * 34) * 0.03 * k
		local up = cast == "Summon" and 1 or 0
		add(P, "Chest", 0.3 * k, 0, shake)
		add(P, "Spine2", 0.12 * k, 0, 0)
		add(P, "Head", 0.35 * k + shake, 0, 0)
		add(P, "UpperArmL", (0.6 + 2.0 * up) * k, 0, -(1.0 - 0.5 * up) * k)
		add(P, "UpperArmR", (0.6 + 2.0 * up) * k, 0, (1.0 - 0.5 * up) * k)
		add(P, "ForeArmL", 0.7 * k, 0, 0)
		add(P, "ForeArmR", 0.7 * k, 0, 0)
		add(P, "Hips", 0, 0, 0, 0, -0.02 * H * k)
	end
end

local function dragon(P, B, t, w, ph, cast, age, cw, flying)
	local H = B.H
	local flap = flying and sin(t * 3.6) or sin(t * 1.1) * 0.12
	local amp = flying and 0.8 or 1
	add(P, "WingL1", 0, 0, flap * amp + (flying and 0 or 0.35))
	add(P, "WingR1", 0, 0, -flap * amp - (flying and 0 or 0.35))
	local f2 = flying and sin(t * 3.6 - 0.8) * 0.5 or 0.25
	add(P, "WingL2", 0, 0, f2)
	add(P, "WingR2", 0, 0, -f2)
	add(P, "WingL3", 0, 0, f2 * 0.6)
	add(P, "WingR3", 0, 0, -f2 * 0.6)
	for i = 1, 7 do
		add(P, "Tail" .. i, 0.03, sin(t * 1.8 - i * 0.55) * (0.07 + i * 0.022), 0)
	end
	local breathe = sin(t * 1.2)
	for i, role in ipairs({ "Neck1", "Neck2", "Neck3", "Neck4" }) do
		add(P, role, breathe * 0.03, sin(t * 0.7 + i * 0.5) * 0.05, 0)
	end
	add(P, "Chest", breathe * 0.04, 0, 0)
	add(P, "Jaw", -0.05 - max(0, sin(t * 0.9)) * 0.08, 0, 0)
	if flying then
		add(P, "ThighL", -0.8, 0, 0)
		add(P, "ThighR", -0.8, 0, 0)
		add(P, "ShinL", 0.6, 0, 0)
		add(P, "ShinR", 0.6, 0, 0)
		add(P, "ArmL1", -0.6, 0, 0)
		add(P, "ArmR1", -0.6, 0, 0)
		add(P, "Hips", -0.06 + flap * 0.04, 0, 0, 0, -flap * 0.03 * H)
	else
		local sw = sin(ph) * 0.5 * w
		add(P, "ArmL1", sw, 0, 0)
		add(P, "ThighR", sw, 0, 0)
		add(P, "ArmR1", -sw, 0, 0)
		add(P, "ThighL", -sw, 0, 0)
		add(P, "Hips", 0, sin(ph) * 0.05 * w, 0, 0, abs(cos(ph)) * 0.02 * H * w)
	end
	if not cast then
		return
	end
	local A, Hh = castWeights(age, cw)
	local k = max(A, Hh)
	if cast == "Roar" then
		local shake = sin(t * 30) * 0.04 * k
		for _, role in ipairs({ "Neck1", "Neck2", "Neck3", "Neck4" }) do
			add(P, role, 0.16 * k, shake, 0)
		end
		add(P, "Head", 0.25 * k, 0, 0)
		add(P, "Jaw", -0.85 * k, 0, 0)
		add(P, "WingL1", 0, 0, -0.7 * k)
		add(P, "WingR1", 0, 0, 0.7 * k)
		add(P, "Hips", 0.15 * k, 0, 0)
	elseif cast == "Breath" then
		local shake = sin(t * 22) * 0.03 * Hh
		for _, role in ipairs({ "Neck1", "Neck2", "Neck3", "Neck4" }) do
			add(P, role, 0.12 * A - 0.12 * Hh, shake, 0)
		end
		add(P, "Head", -0.1 * Hh, 0, 0)
		add(P, "Jaw", -0.3 * A - 0.8 * Hh, 0, 0)
		add(P, "WingL1", 0, 0, -0.4 * k)
		add(P, "WingR1", 0, 0, 0.4 * k)
		add(P, "Chest", 0.12 * A - 0.08 * Hh, 0, 0)
	elseif cast == "Nova" then
		add(P, "WingL1", 0, 0, -1.1 * A + 0.9 * Hh)
		add(P, "WingR1", 0, 0, 1.1 * A - 0.9 * Hh)
		add(P, "WingL2", 0, 0, -0.4 * A)
		add(P, "WingR2", 0, 0, 0.4 * A)
		for _, role in ipairs({ "Neck1", "Neck2", "Neck3", "Neck4" }) do
			add(P, role, 0.14 * A - 0.12 * Hh, 0, 0)
		end
		add(P, "Jaw", -0.7 * k, 0, 0)
	end
end

local function mosasaur(P, B, t, w, cast, age, cw)
	local speed = 1.2 + w * 2.2
	local amp = 0.07 + w * 0.06
	local chain = { "Body1", "Body2", "Body3", "Body4", "Body5", "Body6", "Tail1", "Tail2", "Tail3" }
	for i, role in ipairs(chain) do
		add(P, role, sin(t * speed * 0.5 - i * 0.4) * 0.015, sin(t * speed - i * 0.6) * amp * (0.4 + i * 0.13), 0)
	end
	local pad = sin(t * speed) * 0.35
	add(P, "FlipperFL", 0, 0, -0.2 - pad)
	add(P, "FlipperFR", 0, 0, 0.2 + pad)
	add(P, "FlipperBL", 0, 0, -0.15 + pad * 0.6)
	add(P, "FlipperBR", 0, 0, 0.15 - pad * 0.6)
	add(P, "Jaw", -0.04 - max(0, sin(t * 0.8)) * 0.1, 0, 0)
	add(P, "Root", 0, 0, 0, 0, sin(t * speed * 0.5) * 0.02 * B.H)
	if not cast then
		return
	end
	local A, Hh = castWeights(age, cw)
	local k = max(A, Hh)
	if cast == "Rear" or cast == "Slam" then
		-- ยกหัวขึ้นสูง -> ฟาดลง
		add(P, "Neck", 0.35 * A - 0.25 * Hh, 0, 0)
		add(P, "Head", 0.3 * A - 0.2 * Hh, 0, 0)
		add(P, "Body1", 0.25 * A - 0.15 * Hh, 0, 0)
		add(P, "Body2", 0.15 * A, 0, 0)
		add(P, "Jaw", -0.6 * A - 0.2 * Hh, 0, 0)
		add(P, "Root", 0, 0, 0, 0, 0.06 * B.H * A)
	elseif cast == "Roar" then
		local shake = sin(t * 28) * 0.04 * k
		add(P, "Neck", 0.2 * k, shake, 0)
		add(P, "Head", 0.25 * k, 0, 0)
		add(P, "Jaw", -0.9 * k, 0, 0)
	end
end

---------------------------------------------------------------- ใส่ท่าลงกระดูก (นุ่ม)
local function apply(B, P, dt)
	local a = 1 - exp(-dt * 9)
	for role, e in pairs(B.Bones) do
		local p = P[role]
		local cur = e.Cur
		for i = 1, 6 do
			cur[i] += ((p and p[i] or 0) - cur[i]) * a
		end
		local rot = e.RestInv * ANG(cur[1], cur[2], cur[3]) * e.Rest
		if cur[4] ~= 0 or cur[5] ~= 0 or cur[6] ~= 0 then
			e.Bone.Transform = CFrame.new(e.RestInv * V(cur[4], cur[5], cur[6])) * rot
		else
			e.Bone.Transform = rot
		end
	end
end

-- หัว/คอหันมองผู้เล่น (เครื่องเรา)
local function lookAt(P, B, rig, dt)
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local yaw, pitch = 0, 0
	if hrp then
		local rel = rig.Root.CFrame:PointToObjectSpace(hrp.Position)
		yaw = clamp(atan2(-rel.X, -rel.Z), -1.0, 1.0)
		pitch = clamp(atan2(rel.Y - B.H * 0.4, V(rel.X, 0, rel.Z).Magnitude), -0.45, 0.3)
	end
	local a = 1 - exp(-dt * 4)
	B.Look[1] += (yaw - B.Look[1]) * a
	B.Look[2] += (pitch - B.Look[2]) * a
	yaw, pitch = B.Look[1], B.Look[2]
	if B.Kind == "Dragon" then
		for _, role in ipairs({ "Neck1", "Neck2", "Neck3", "Neck4" }) do
			add(P, role, pitch * 0.15, yaw * 0.18, 0)
		end
		add(P, "Head", pitch * 0.4, yaw * 0.28, 0)
	elseif B.Kind == "Mosasaur" then
		add(P, "Neck", pitch * 0.4, yaw * 0.45, 0)
		add(P, "Head", pitch * 0.4, yaw * 0.45, 0)
	else
		add(P, "Neck", pitch * 0.4, yaw * 0.4, 0)
		add(P, "Head", pitch * 0.6, yaw * 0.6, 0)
		add(P, "Chest", 0, yaw * 0.15, 0)
	end
end

function BossAnimator.Animate(rig, ctx)
	local B = rig.Boss
	if not B then
		return
	end
	local model = rig.Model
	local P = {}
	local dt = ctx.Dt
	-- ตาย: ล้มลง
	if ctx.DeadT then
		local d = smooth((ctx.Now - ctx.DeadT) / 1.4)
		if B.Kind == "Dragon" then
			add(P, "Hips", 0, 0, 1.5 * d)
			add(P, "WingL1", 0, 0, 0.9 * d)
			add(P, "WingR1", 0, 0, -0.9 * d)
		elseif B.Kind == "Mosasaur" then
			add(P, "Root", 0, 0, 2.6 * d)
		else
			add(P, "Hips", 1.35 * d, 0, 0.25 * d, 0, -0.2 * B.H * d)
			add(P, "UpperArmL", 0.5 * d, 0, -1.0 * d)
			add(P, "UpperArmR", 0.5 * d, 0, 1.0 * d)
		end
		apply(B, P, dt)
		return
	end
	local w = clamp(ctx.Speed / 12, 0, 1)
	B.Phase += dt * (ctx.Speed / math.max(B.H * 0.5, 4)) * math.pi * 2 * 0.5
	local cast = model:GetAttribute("Cast")
	local age, cw = 0, 1
	if cast then
		age = Workspace:GetServerTimeNow() - (model:GetAttribute("CastAt") or 0)
		cw = model:GetAttribute("CastTime") or 1
		if age > cw + 1.2 then
			cast = nil
		end
	end
	if B.Kind == "Dragon" then
		dragon(P, B, ctx.Now, w, B.Phase, cast, age, cw, ctx.Flying)
	elseif B.Kind == "Mosasaur" then
		mosasaur(P, B, ctx.Now, w, cast, age, cw)
	else
		biped(P, B, ctx.Now, w, B.Phase, cast, age, cw)
	end
	lookAt(P, B, rig, dt)
	apply(B, P, dt)
end

return BossAnimator
