--[[
	RigPlayer — สัตว์ที่มีโครงกระดูก + แอนิเมชันจริง (ReplicatedStorage.AnimRigs จาก blender/rigged_export.py)
	ประกอบโมเดลบนเครื่องผู้เล่น: กระดูกละ 1 Part + Motor6D (C0 = ท่า rest เทียบกระดูกแม่), MeshPart ของแต่ละกระดูกเชื่อมติด
	เล่นท่า: Motor6D.Transform = คีย์เฟรมที่สุ่มไว้ (ประมาณค่าระหว่างเฟรม + ผสมข้ามท่านุ่มๆ)

	RigPlayer.Has(animalId) · RigPlayer.Attach(rig) · RigPlayer.Animate(rig, ctx)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimalSkins = require(Shared.AnimalSkins)
local RigConfig = require(Shared.RigConfig)

local RigPlayer = {}
local SET = "AnimRigs"
local clamp = math.clamp

---------------------------------------------------------------- ถอดรหัสท่า (แคชต่อชนิด)
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64L = {}
for i = 1, 64 do
	B64L[string.byte(B64, i)] = i - 1
end

local function b64(s)
	local n = #s
	local pad = (s:sub(-2) == "==") and 2 or ((s:sub(-1) == "=") and 1 or 0)
	local outLen = (n // 4) * 3 - pad
	local buf = buffer.create(outLen)
	local o = 0
	for i = 1, n, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local t = B64L[a] * 262144 + B64L[b] * 4096 + (B64L[c] or 0) * 64 + (B64L[d] or 0)
		if o < outLen then
			buffer.writeu8(buf, o, t // 65536)
			o += 1
		end
		if o < outLen then
			buffer.writeu8(buf, o, (t // 256) % 256)
			o += 1
		end
		if o < outLen then
			buffer.writeu8(buf, o, t % 256)
			o += 1
		end
	end
	return buf
end

local cache = {} -- [rigId] = { Data, Clips = { name = { N, Dur, Rot = {[f][b] = CFrame}, Pos = {[f][b] = Vector3} } } }

local function decoded(rid)
	local c = cache[rid]
	if c ~= nil then
		return c or nil
	end
	local data = AnimalSkins.Data(rid, SET)
	if not (data and data.Rig) then
		cache[rid] = false
		return nil
	end
	local nb = #data.Rig.Bones
	local clips = {}
	for name, clip in pairs(data.Clips or {}) do
		local q = b64(clip.Q)
		local t = b64(clip.T)
		local rot, pos = table.create(clip.N), table.create(clip.N)
		for f = 1, clip.N do
			local rf, pf = table.create(nb), table.create(nb)
			for b = 1, nb do
				local i = ((f - 1) * nb + (b - 1))
				local qx, qy, qz, qw = buffer.readi16(q, i * 8) / 32767, buffer.readi16(q, i * 8 + 2) / 32767, buffer.readi16(q, i * 8 + 4) / 32767, buffer.readi16(q, i * 8 + 6) / 32767
				rf[b] = CFrame.new(0, 0, 0, qx, qy, qz, qw)
				local ts = clip.TS / 32767
				pf[b] = Vector3.new(buffer.readi16(t, i * 6) * ts, buffer.readi16(t, i * 6 + 2) * ts, buffer.readi16(t, i * 6 + 4) * ts)
			end
			rot[f], pos[f] = rf, pf
		end
		clips[name] = { N = clip.N, Dur = clip.Dur, Rot = rot, Pos = pos }
	end
	c = { Data = data, Clips = clips }
	cache[rid] = c
	return c
end

function RigPlayer.Has(animalId)
	local cfg = RigConfig.Animals[animalId]
	return cfg ~= nil and AnimalSkins.Has(cfg.Rig, SET)
end

---------------------------------------------------------------- ประกอบโมเดล
local function cfOf(t, k)
	return CFrame.new(t[1] * k, t[2] * k, t[3] * k, t[4], t[5], t[6], t[7], t[8], t[9], t[10], t[11], t[12])
end

function RigPlayer.Attach(rig)
	local cfg = RigConfig.Animals[rig.Id]
	local dc = cfg and decoded(cfg.Rig)
	if not dc then
		return false
	end
	local data = dc.Data
	local root = rig.Root
	local rcf, rsize = rig.Model:GetBoundingBox()
	-- ขนาด: ยาวเท่า rig x Fit (หรือสูงตาม FitHeight)
	local k
	if cfg.FitHeight then
		k = rsize.Y * cfg.FitHeight / data.Rig.Height
	else
		k = math.max(rsize.Z, rsize.X) * (cfg.Fit or 1) / data.Rig.Length
	end
	k *= (cfg.Scale or 1)
	local model = Instance.new("Model")
	model.Name = "RigVisual"
	-- พื้นจริง = ที่ Humanoid ยืน (ก้น root - HipHeight) ไม่ใช่ขอบล่างของ rig เดิม (ชิ้นส่วนบางตัวลอยจากพื้น)
	local hum = rig.Model:FindFirstChildOfClass("Humanoid")
	local bottom = rcf.Position.Y - rsize.Y / 2
	if hum and hum.RigType == Enum.HumanoidRigType.R15 and hum.HipHeight > 0 then
		bottom = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
	end
	bottom += (cfg.Lift or 0) * rsize.Y
	local base = CFrame.new(root.Position.X, bottom, root.Position.Z) * root.CFrame.Rotation
	local anchor = Instance.new("Part")
	anchor.Name = "RigRoot"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.Massless = false, false, false, true
	anchor.CFrame = base
	anchor.Anchored = true
	anchor.Parent = model
	local bones = data.Rig.Bones
	local bparts, motors, rest = {}, {}, {}
	for i, b in ipairs(bones) do
		local pr = b.Parent > 0 and rest[b.Parent] or base
		rest[i] = pr * cfOf(b.C0, k)
		local p = Instance.new("Part")
		p.Name = "Bone" .. i
		p.Size = Vector3.new(0.1, 0.1, 0.1)
		p.Transparency = 1
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.Anchored = true
		p.CFrame = rest[i]
		p.Parent = model
		bparts[i] = p
	end
	-- ชิ้นเมช
	for _, pd in ipairs(data.Parts) do
		local bi = tonumber(pd.Name:match("_B(%d+)$") or pd.Name:match("^B(%d+)$"))
		local bp = bi and bparts[bi]
		if bp then
			local cf = base * CFrame.new(pd.Center[1] * k, pd.Center[2] * k, pd.Center[3] * k)
			local ok, mp = pcall(AnimalSkins.MakePart, cfg.Rig, pd, cf, SET)
			if ok and mp then
				mp.Size = Vector3.new(pd.Size[1] * k, pd.Size[2] * k, pd.Size[3] * k)
				mp.CFrame = cf
				mp.Anchored = true
				if pd.Glow then
					mp.Material = Enum.Material.Neon
				end
				mp.Parent = model
				local w = Instance.new("WeldConstraint")
				w.Part0 = bp
				w.Part1 = mp
				w.Parent = mp
			end
		end
	end
	-- ข้อต่อ
	for i, b in ipairs(bones) do
		local m = Instance.new("Motor6D")
		m.Name = "M" .. i
		m.Part0 = b.Parent > 0 and bparts[b.Parent] or anchor
		m.Part1 = bparts[i]
		m.C0 = cfOf(b.C0, k)
		m.Parent = bparts[i]
		motors[i] = m
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
	local vroot = Instance.new("Motor6D")
	vroot.Name = "RigRootMotor"
	vroot.Part0 = root
	vroot.Part1 = anchor
	vroot.C0 = root.CFrame:ToObjectSpace(base)
	vroot.Parent = anchor
	-- เอฟเฟกต์ตามชนิด
	if cfg.Effects then
		local byName = {}
		for i, b in ipairs(bones) do
			byName[b.Name] = bparts[i]
		end
		local okE, errE = pcall(cfg.Effects, model, byName, k, bparts)
		if not okE then
			warn("[AS] rig fx", rig.Id, errE)
		end
	end
	model.Parent = rig.Model
	-- ซ่อน rig เดิม (รวมถึงผิวเก่าที่อาจถูกสวมทีหลัง)
	rig.Model:SetAttribute("Skinned", true)
	local function hide(d)
		if d:IsDescendantOf(model) then
			return
		end
		do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 1
			elseif (d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Fire") or d:IsA("Beam") or d:IsA("Trail")) and not cfg.KeepFx then
				d.Enabled = false
			end
		end
	end
	for _, d in ipairs(rig.Model:GetDescendants()) do
		hide(d)
	end
	rig.Model.DescendantAdded:Connect(hide)
	rig.Anim = {
		Model = model, Motors = motors, K = k, Cfg = cfg, Clips = dc.Clips, Root = vroot, RootC0 = vroot.C0,
		Cur = { Name = nil, T = 0 }, Prev = nil, Blend = 1, OneShot = nil, Length = data.Rig.Length * k,
		Hum = (hum and hum.RigType == Enum.HumanoidRigType.R15) and hum or nil, Lift = (cfg.Lift or 0) * rsize.Y,
	}
	return true
end

---------------------------------------------------------------- เล่นท่า
local function sample(clip, t, loop)
	local n = clip.N
	local x
	if loop then
		x = (t / clip.Dur) % 1 * (n - 1)
	else
		x = clamp(t / clip.Dur, 0, 1) * (n - 1)
	end
	local f0 = math.floor(x)
	local a = x - f0
	local f1 = math.min(f0 + 1, n - 1)
	return clip.Rot[f0 + 1], clip.Rot[f1 + 1], clip.Pos[f0 + 1], clip.Pos[f1 + 1], a
end

local function pick(A, list)
	for _, n in ipairs(list) do
		if A.Clips[n] then
			return n
		end
	end
	return nil
end

-- ctx: { Now, Dt, Speed, Att, AttackT, Kind, State, Flying, DeadT }
function RigPlayer.Animate(rig, ctx)
	local A = rig.Anim
	local cfg = A.Cfg
	local dt = ctx.Dt
	-- เลือกท่าหลัก
	local want, rate, loop = nil, 1, true
	if ctx.DeadT then
		want, loop = pick(A, { "Death" }), false
	elseif ctx.Flying and A.Clips.Fly then
		want = (ctx.Speed > (cfg.FastFly or 30) and A.Clips.FlyFast) and "FlyFast" or "Fly"
	else
		local walkSpeed = A.Length * (cfg.WalkStride or 0.55) / ((A.Clips.Walk and A.Clips.Walk.Dur) or 1)
		local runSpeed = A.Length * (cfg.RunStride or 1.4) / ((A.Clips.Run and A.Clips.Run.Dur) or 0.6)
		if ctx.Speed < 0.6 then
			want = (ctx.State == "Graze" and A.Clips.Eat) and "Eat" or "Idle"
		elseif ctx.Speed < walkSpeed * 1.35 or not A.Clips.Run then
			want = pick(A, { "Walk", "Run", "Idle" })
			rate = clamp(ctx.Speed / math.max(walkSpeed, 0.1), 0.5, 2.2)
		else
			want = "Run"
			rate = clamp(ctx.Speed / math.max(runSpeed, 0.1), 0.6, 2)
		end
	end
	want = want or pick(A, { "Idle", "Walk" })
	if want ~= A.Cur.Name then
		A.Prev = { Name = A.Cur.Name, T = A.Cur.T, Loop = A.Cur.Loop }
		A.Cur = { Name = want, T = 0, Loop = loop }
		A.Blend = 0
	end
	A.Cur.T += dt * rate
	A.Blend = math.min(1, A.Blend + dt / (cfg.BlendTime or 0.22))
	-- ท่าโจมตี (เล่นทับครั้งเดียว)
	if ctx.AttackT and ctx.AttackT ~= A.LastAttack and not ctx.DeadT then
		A.LastAttack = ctx.AttackT
		local an = pick(A, ctx.Kind == "Roar" and { "Roar", "Attack" } or { "Attack" })
		if an then
			A.OneShot = { Name = an, T = 0 }
		end
	end
	local shot, shotW = nil, 0
	if A.OneShot then
		local c = A.Clips[A.OneShot.Name]
		A.OneShot.T += dt * (cfg.AttackRate or 1.2)
		local u = A.OneShot.T / c.Dur
		if u >= 1 then
			A.OneShot = nil
		else
			shot = c
			shotW = math.min(1, u / 0.12, (1 - u) / 0.18)
		end
	end
	-- ยึดเท้ากับพื้นที่ Humanoid ยืนจริง (HipHeight/ขนาด root อาจเปลี่ยนหลังสร้าง)
	if A.Hum then
		local root = A.Root.Part0
		local y = -root.Size.Y / 2 - A.Hum.HipHeight + A.Lift
		if math.abs(y - A.RootC0.Y) > 0.02 then
			A.RootC0 = CFrame.new(0, y, 0) * A.RootC0.Rotation
			A.Root.C0 = A.RootC0
		end
	end
	-- ท่าที่เล่นอยู่ (ให้ dev tool / เทสต์อ่าน)
	local tag = A.Cur.Name .. (A.OneShot and ("+" .. A.OneShot.Name) or "")
	if rig.Model and A.Tag ~= tag then
		A.Tag = tag
		rig.Model:SetAttribute("RigClip", tag)
	end
	-- ประกอบท่า
	local cur = A.Clips[A.Cur.Name]
	local prev = A.Prev and A.Prev.Name and A.Clips[A.Prev.Name]
	if A.Prev then
		A.Prev.T += dt
	end
	local w = A.Blend
	local k = A.K
	local r0a, r0b, p0a, p0b, a0 = sample(cur, A.Cur.T, A.Cur.Loop ~= false)
	local r1a, r1b, p1a, p1b, a1
	if prev and w < 1 then
		r1a, r1b, p1a, p1b, a1 = sample(prev, A.Prev.T, A.Prev.Loop ~= false)
	end
	local r2a, r2b, p2a, p2b, a2
	if shot then
		r2a, r2b, p2a, p2b, a2 = sample(shot, A.OneShot.T, false)
	end
	for i, m in ipairs(A.Motors) do
		local rot = r0a[i]:Lerp(r0b[i], a0)
		local pos = p0a[i]:Lerp(p0b[i], a0)
		if r1a then
			rot = r1a[i]:Lerp(r1b[i], a1):Lerp(rot, w)
			pos = p1a[i]:Lerp(p1b[i], a1):Lerp(pos, w)
		end
		if r2a then
			rot = rot:Lerp(r2a[i]:Lerp(r2b[i], a2), shotW)
			pos = pos:Lerp(p2a[i]:Lerp(p2b[i], a2), shotW)
		end
		m.Transform = rot + pos * k
	end
	-- ตายแล้ว: จางหายหลังท่าจบ
	if ctx.DeadT then
		local t = ctx.Now - ctx.DeadT
		if t > 1.8 then
			local fade = clamp((t - 1.8) / 1.2, 0, 1)
			for _, d in ipairs(A.Model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = fade
				end
			end
		end
	end
end

return RigPlayer
