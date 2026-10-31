--[[
	SkelAnimator — ท่าของสัตว์ที่ช่วยจากศาลเจ้า (โครงจาก AnimalModels.buildSkeleton)
	  มีท่าจากไฟล์ (Shared/SkelClips/<Id>): เล่นท่ายืน/เดิน/เหยาะ/วิ่ง ผสมตามความเร็วจริง
	  ไม่มี: คำนวณสดจาก Skin.Legs/Neck/Tail ขาแกว่งเป็นโซ่ งอเข่าตอนยกขา เท้าเหยียบตามจังหวะก้าว
	  ทุกตัว: ลำตัวเด้ง/โน้ม หางเลื้อยเป็นข้อ คอหันมองคน + ท่าเศร้าในกรง (State = Caged) + ท่าดีใจ (Cheer)
	หมุนรอบแกนของตัวสัตว์ (X = ขวา, Y = ขึ้น) แล้วแปลงเป็นแกนของแต่ละข้อต่อ ใช้ได้ทั้ง Bone และ Motor6D
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Animals = require(Shared:WaitForChild("Animals"))

local SkelAnimator = {}

local sin, cos, abs, clamp, tau = math.sin, math.cos, math.abs, math.clamp, math.pi * 2
local X_AXIS, Y_AXIS, Z_AXIS = Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)
local ZERO_POSE = CFrame.identity

function SkelAnimator.Has(model)
	return model:GetAttribute("SkinRig") == "Skeleton"
end

local function collect(model)
	local byName = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 then
			byName[d.Part1.Name] = byName[d.Part1.Name] or d
			byName[d.Name] = byName[d.Name] or d
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Bone") then
			byName[d.Name] = d
		end
	end
	return byName
end

-- แกนท่าทาง -> แกนของข้อต่อ (จดตอนยังไม่ขยับ)
local function makeJoint(inst, root)
	if not inst then
		return nil
	end
	local world
	if inst:IsA("Bone") then
		world = inst.WorldCFrame
	else
		world = inst.Part0.CFrame * inst.C0
	end
	local rest = root.CFrame:ToObjectSpace(world).Rotation
	return {
		Inst = inst,
		X = rest:VectorToObjectSpace(X_AXIS),
		Y = rest:VectorToObjectSpace(Y_AXIS),
		Z = rest:VectorToObjectSpace(Z_AXIS),
		Up = rest:VectorToObjectSpace(Y_AXIS),
	}
end

local function pose(j, x, y, z, lift)
	if not j then
		return
	end
	local cf = CFrame.fromAxisAngle(j.X, x or 0)
	if y and y ~= 0 then
		cf = CFrame.fromAxisAngle(j.Y, y) * cf
	end
	if z and z ~= 0 then
		cf = CFrame.fromAxisAngle(j.Z, z) * cf
	end
	if lift and lift ~= 0 then
		cf = CFrame.new(j.Up * lift) * cf
	end
	j.Inst.Transform = cf
end

local function chain(list, byName, root)
	local out = {}
	for _, n in ipairs(list or {}) do
		local j = makeJoint(byName[n], root)
		if j then
			table.insert(out, j)
		end
	end
	return out
end

local function attach(rig)
	local info = Animals.Data[rig.Id]
	local spec = info and info.Model and info.Model.Skin
	if not spec then
		return nil
	end
	local root = rig.Root
	local byName = collect(rig.Model)
	local S = { Spec = spec, Phase = 0, W = 0, NeckYaw = 0, HopT = 0 }
	S.Body = makeJoint(byName[spec.Body], root)
	S.Neck = chain(spec.Neck, byName, root)
	S.Tail = chain(spec.Tail, byName, root)
	S.Spine = chain(spec.Spine, byName, root)
	S.Jaw = makeJoint(byName[spec.Jaw], root)
	S.Legs = {}
	for key, off in pairs({ FL = 0, BR = 0.02, FR = 0.5, BL = 0.52 }) do
		local names = spec.Legs and spec.Legs[key]
		if names then
			local c = chain(names, byName, root)
			if #c > 0 then
				table.insert(S.Legs, { Chain = c, Off = off, Side = key:sub(2, 2) == "L" and -1 or 1 })
			end
		end
	end
	local clipModule = Shared:FindFirstChild("SkelClips") and Shared.SkelClips:FindFirstChild(rig.Id)
	if clipModule then
		local data = require(clipModule)
		local scale = rig.Model:GetAttribute("SkinScale") or 1
		S.Clips = data.Clips
		S.Fps = data.Fps
		S.Tracks = {}
		local seen = {}
		for _, clip in pairs(data.Clips) do
			for name in pairs(clip.Joints) do
				if not seen[name] and byName[name] then
					seen[name] = true
					table.insert(S.Tracks, { Name = name, Inst = byName[name] })
				end
			end
		end
		S.Scale = scale
		S.T = { Idle = 0, Walk = 0, Trot = 0, Run = 0 }
	end
	if #S.Legs == 0 and not S.Clips then
		return nil
	end
	return S
end

local function sample(clip, name, t, fps, scale)
	local fr = clip and clip.Joints[name]
	if not fr then
		return ZERO_POSE
	end
	local n = clip.Frames
	local f = (t * fps) % n
	local i0 = math.floor(f)
	local u = f - i0
	local a, b = fr[i0 + 1] or fr[1], fr[(i0 + 1) % n + 1] or fr[1]
	local ca = CFrame.new(a[1] * scale, a[2] * scale, a[3] * scale, a[4], a[5], a[6], a[7])
	local cb = CFrame.new(b[1] * scale, b[2] * scale, b[3] * scale, b[4], b[5], b[6], b[7])
	return ca:Lerp(cb, u)
end

local function animateClips(S, rig, now, dt, speed, playerPos, state, cheer)
	local spec = S.Spec
	local refs = spec.ClipSpeed or { Walk = 6, Trot = 12, Run = 26 }
	local slots = { { "Idle", 0 }, { "Walk", refs.Walk }, { "Trot", refs.Trot }, { "Run", refs.Run } }
	local s = cheer and refs.Walk or speed
	local a, b, u = "Idle", "Walk", 0
	for i = 1, #slots - 1 do
		if s >= slots[i][2] then
			a, b = slots[i][1], slots[i + 1][1]
			u = clamp((s - slots[i][2]) / (slots[i + 1][2] - slots[i][2]), 0, 1)
		end
	end
	if s >= refs.Run then
		a, b, u = "Run", "Run", 0
	end
	-- เดินเร็วขึ้น = เล่นท่าเร็วขึ้น เท้าไม่ไถลบนพื้น
	local pace = s < 1 and 1 or clamp(s / math.max(slots[({ Walk = 2, Trot = 3, Run = 4 })[b] or 2][2], 1), 0.75, 1.6)
	for k in pairs(S.T) do
		S.T[k] += dt * pace
	end
	local ca, cb = S.Clips[a], S.Clips[b]
	local neckName = spec.Neck and spec.Neck[#spec.Neck]
	S.Blend = (S.Blend or 0) + (u - (S.Blend or 0)) * math.min(1, dt * 8)
	for _, tr in ipairs(S.Tracks) do
		local cf = sample(ca, tr.Name, S.T[a], S.Fps, S.Scale):Lerp(sample(cb, tr.Name, S.T[b], S.Fps, S.Scale), S.Blend)
		if tr.Name == neckName and tr.Inst then
			if state == "Caged" then
				cf = CFrame.Angles(0, 0, 0.5 + sin(now * 10) * 0.03) * cf
			end
		end
		if tr.Name == spec.Body and cheer then
			cf = CFrame.new(0, abs(sin(now * 5)) * rig.Size.Y * 0.14, 0) * cf
		end
		tr.Inst.Transform = cf
	end
end

function SkelAnimator.Animate(rig, now, dt, speed, playerPos)
	local S = rig.Skel
	if not S then
		if now < (rig.SkelRetry or 0) then
			return
		end
		rig.SkelRetry = now + 0.5
		S = attach(rig)
		if not S then
			return
		end
		rig.Skel = S
	end
	local model, root = rig.Model, rig.Root
	local state = model:GetAttribute("State")
	local cheer = model:GetAttribute("Cheer")
	if S.Clips then
		animateClips(S, rig, now, dt, speed, playerPos, state, cheer)
		return
	end
	local spec = S.Spec
	local g = spec.Gait or {}
	local h = math.max(rig.Size.Y, 1)
	local len = math.max(rig.Size.Z, rig.Size.X, 1)
	-- น้ำหนักการเดิน ผสมนุ่ม (ไม่สลับท่าขวับ) · ความถี่ก้าวตามระยะก้าวจริง เท้าจะได้ไม่ไถล
	local want = cheer and 0.75 or clamp((speed - 0.5) / 5, 0, 1)
	S.W += (want - S.W) * math.min(1, dt * 7)
	local w = S.W
	local rate = cheer and 2.4 or speed / math.max(len * (g.Stride or 0.55), 0.5)
	S.Phase = (S.Phase + dt * rate) % 1
	local p = S.Phase
	local A, K, F = g.Hip or 0.6, g.Knee or 0.8, g.Foot or 0.5
	for _, leg in ipairs(S.Legs) do
		local ph = (p + leg.Off) * tau
		local swing = sin(ph)
		local lift = math.max(0, cos(ph)) -- ช่วงขาเหวี่ยงไปข้างหน้า = ยกขา
		local c = leg.Chain
		if g.Sprawl then
			-- สัตว์เลื้อยคลาน: ขาเหวี่ยงแนวนอน ยกขึ้นด้านข้าง
			pose(c[1], 0, leg.Side * A * swing * w, leg.Side * lift * 0.3 * w)
		elseif #c == 1 then
			pose(c[1], A * swing * w, 0, 0, lift * h * 0.035 * w)
		else
			pose(c[1], A * swing * w)
		end
		if c[2] then
			pose(c[2], -K * lift * w - (g.Bend or 0) * w)
		end
		if c[3] then
			pose(c[3], F * lift * w)
		end
	end
	-- ลำตัว: เด้ง 2 ครั้งต่อรอบก้าว + โน้มหน้า · สัตว์เลื้อยคลานส่ายลำตัว
	local bob = abs(sin(p * tau)) * h * (g.Bob or 0.035) * w
	local breathe = sin(now * 2.1 + rig.Seed) * 0.012
	local hop = cheer and abs(sin(now * 5)) * h * 0.22 or 0
	if S.Body then
		local cf = CFrame.fromAxisAngle(S.Body.X, -0.05 * w + breathe)
		cf = CFrame.fromAxisAngle(S.Body.Y, sin(p * tau) * (g.Sway or 0.04) * w) * cf
		S.Body.Inst.Transform = CFrame.new(S.Body.Up * (bob + hop)) * cf
	end
	for i, j in ipairs(S.Spine) do
		pose(j, breathe * 0.5, sin(p * tau - i * 0.8) * (g.Sway or 0.04) * 1.6 * w)
	end
	-- หางเลื้อยเป็นคลื่นจากโคนไปปลาย
	local n = #S.Tail
	for i, j in ipairs(S.Tail) do
		local k = i / math.max(n, 1)
		local freq = g.Sprawl and p * tau or now * (2.2 + 5 * w)
		pose(j, (g.TailLift or -0.04) + sin(now * 1.7 + i) * 0.03, sin(freq - i * 0.75) * (g.Tail or 0.22) * (0.5 + k) * (0.45 + 0.55 * w) * (cheer and 1.8 or 1))
	end
	-- คอ/หัว: พยักตามก้าว หันมองคนใกล้ ก้มเศร้าเมื่ออยู่ในกรง
	local neckPitch = sin(p * tau * 2) * 0.05 * w + breathe
	local neckYaw = 0
	if state == "Caged" then
		neckPitch = -0.42 + sin(now * 10) * 0.025
	elseif playerPos then
		local toP = playerPos - root.Position
		if toP.Magnitude < 40 then
			local ld = root.CFrame:VectorToObjectSpace(toP)
			neckYaw = clamp(math.atan2(-ld.X, -ld.Z), -0.8, 0.8)
			neckPitch += 0.08
		end
	end
	if cheer then
		neckPitch += 0.25 + sin(now * 10) * 0.08
	end
	S.NeckYaw += (neckYaw - S.NeckYaw) * math.min(1, dt * 5)
	local nn = #S.Neck
	for _, j in ipairs(S.Neck) do
		pose(j, neckPitch / math.max(nn, 1), S.NeckYaw / math.max(nn, 1))
	end
	if S.Jaw then
		pose(S.Jaw, (cheer and 0.25 or 0.03) * (1 + sin(now * 7)) * -1)
	end
end

return SkelAnimator
