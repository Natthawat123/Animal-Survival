--[[
	CreatureVisuals — ใส่โมเดลสัตว์คุณภาพสูง (จาก Roblox Creator Store: ReplicatedStorage.Assets.Creatures) ทับ rig ของสัตว์
	ตั้งค่าใน Shared/Creatures.lua — ทำงานบนเครื่องผู้เล่นเท่านั้น (server ยังใช้ rig เดิมเป็น hitbox/ฟิสิกส์)

	ขั้นตอนตอนติดตั้ง:
	  1) โคลนโมเดล -> หันหัวไป -Z ของ rig (หาจากชิ้น/กระดูกชื่อ Head ใน config) -> ย่อ/ขยายให้ยาวเท่า rig -> วางเท้าที่พื้น rig
	  2) ข้อต่อ: Motor6D/Bone เดิมของโมเดลใช้ทำท่า / โมเดลนิ่งหลายชิ้นถูกแบ่งเป็น "ปล้อง" ต่อด้วย Motor6D ให้หางสะบัดได้
	  3) ซ่อน rig เดิม (LocalTransparencyModifier) แล้วเชื่อมโมเดลกับ HumanoidRootPart ด้วย Weld
	ท่าทาง (ทุกเฟรม): หมุนข้อต่อรอบแกน "โลก" ของตัวสัตว์ (ขึ้น/ขวา/หน้า) ที่แปลงเป็นแกนของข้อต่อแต่ละอันไว้ล่วงหน้า
	  -> ใช้ได้กับโมเดลทุกแบบโดยไม่ต้องรู้ว่าแกนข้อต่อของคนทำหันทางไหน
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Creatures = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Creatures"))

local CreatureVisuals = {}

local sin, abs, clamp = math.sin, math.abs, math.clamp
local CF = CFrame.new

local function assetFolder()
	local a = ReplicatedStorage:FindFirstChild("Assets")
	return a and a:FindFirstChild("Creatures")
end

function CreatureVisuals.Has(animalId)
	local cfg = Creatures.Visual[animalId]
	local folder = assetFolder()
	return cfg ~= nil and folder ~= nil and folder:FindFirstChild(cfg.Model) ~= nil
end

local function parts(model)
	local out = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function bounds(list)
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, p in ipairs(list) do
		if p.Transparency < 1 then
			local h = p.Size / 2
			local c = p.Position
			local r = p.CFrame
			-- กล่องหมุนแล้ว -> ขอบเขตแกนโลก
			local ex = abs(r.RightVector.X) * h.X + abs(r.UpVector.X) * h.Y + abs(r.LookVector.X) * h.Z
			local ey = abs(r.RightVector.Y) * h.X + abs(r.UpVector.Y) * h.Y + abs(r.LookVector.Y) * h.Z
			local ez = abs(r.RightVector.Z) * h.X + abs(r.UpVector.Z) * h.Y + abs(r.LookVector.Z) * h.Z
			mn = Vector3.new(math.min(mn.X, c.X - ex), math.min(mn.Y, c.Y - ey), math.min(mn.Z, c.Z - ez))
			mx = Vector3.new(math.max(mx.X, c.X + ex), math.max(mx.Y, c.Y + ey), math.max(mx.Z, c.Z + ez))
		end
	end
	return mn, mx
end

local function findNamed(model, name)
	if not name then
		return nil
	end
	local lname = name:lower()
	for _, d in ipairs(model:GetDescendants()) do
		if (d:IsA("BasePart") or d:IsA("Bone")) and d.Name:lower() == lname then
			return d
		end
	end
	return nil
end

local function posOf(x)
	return x:IsA("Bone") and x.WorldPosition or x.Position
end

-- ต่อทุกชิ้นที่ลอยอยู่ (ไม่มีข้อต่อถึงชิ้นหลัก) เข้ากับชิ้นหลัก
local function connectAll(model, primary)
	local adj = {}
	local function link(a, b)
		if a and b then
			adj[a] = adj[a] or {}
			adj[b] = adj[b] or {}
			table.insert(adj[a], b)
			table.insert(adj[b], a)
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			link(d.Part0, d.Part1)
		end
	end
	local seen = { [primary] = true }
	local queue = { primary }
	while #queue > 0 do
		local p = table.remove(queue)
		for _, q in ipairs(adj[p] or {}) do
			if not seen[q] then
				seen[q] = true
				table.insert(queue, q)
			end
		end
	end
	for _, p in ipairs(parts(model)) do
		if not seen[p] then
			local w = Instance.new("WeldConstraint")
			w.Part0 = primary
			w.Part1 = p
			w.Parent = p
		end
	end
end

-- โมเดลนิ่งหลายชิ้น: ตัดเป็นปล้องตามแนวลำตัว (หัว -> หาง) แล้วต่อเป็นโซ่ Motor6D
local function segmentize(model, primary, fwd, cuts)
	local list = parts(model)
	-- ลบข้อต่อเดิมทั้งหมด (จะต่อใหม่ตามปล้อง)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	local headT, tailT = math.huge, -math.huge
	for _, p in ipairs(list) do
		local t = -p.Position:Dot(fwd) -- ยิ่งมากยิ่งไปทางหาง
		headT, tailT = math.min(headT, t), math.max(tailT, t)
	end
	local span = math.max(tailT - headT, 0.01)
	local mn, mx = bounds(list)
	local mid = (mn + mx) / 2
	local anchors = {}
	local prev = primary
	for k, c in ipairs(cuts) do
		local t = headT + span * c
		local pos = Vector3.new(mid.X, mid.Y, mid.Z) + (-fwd) * (t - (-mid:Dot(fwd)))
		local a = Instance.new("Part")
		a.Name = "Seg" .. k
		a.Size = Vector3.new(0.2, 0.2, 0.2)
		a.Transparency = 1
		a.CanCollide, a.CanQuery, a.CanTouch, a.Massless = false, false, false, true
		a.CFrame = CFrame.lookAt(pos, pos + fwd)
		a.Parent = model
		local m = Instance.new("Motor6D")
		m.Name = "Seg" .. k
		m.Part0 = prev
		m.Part1 = a
		m.C0 = prev.CFrame:ToObjectSpace(a.CFrame)
		m.Parent = a
		anchors[k] = { Part = a, T = c }
		prev = a
	end
	for _, p in ipairs(list) do
		if p ~= primary then
			local f = (-p.Position:Dot(fwd) - headT) / span
			local target = primary
			for _, a in ipairs(anchors) do
				if f >= a.T then
					target = a.Part
				end
			end
			local w = Instance.new("WeldConstraint")
			w.Part0 = target
			w.Part1 = p
			w.Parent = p
		end
	end
	local chain = {}
	for k = 1, #anchors do
		table.insert(chain, "Seg" .. k)
	end
	return chain
end

-- ข้อต่อที่ใช้ทำท่า: Motor6D หรือ Bone (คืน {Obj, IsBone, Base, Up, Right, Fwd})
local function jointInfo(model, name, rootCF)
	local lname = name:lower()
	for _, d in ipairs(model:GetDescendants()) do
		-- Motor6D: จับคู่จากชื่อชิ้นที่มันขยับ (Part1) / Bone: จากชื่อกระดูก
		local key = (d:IsA("Motor6D") and d.Part1 and d.Part1.Name or d.Name):lower()
		if key == lname and (d:IsA("Motor6D") or d:IsA("Bone")) then
			local frame
			if d:IsA("Bone") then
				frame = d.WorldCFrame
			elseif d.Part0 then
				frame = d.Part0.CFrame * d.C0
			end
			if frame then
				local function axis(v)
					return frame:VectorToObjectSpace(v).Unit
				end
				return {
					Obj = d, Up = axis(rootCF.UpVector), Right = axis(rootCF.RightVector), Fwd = axis(rootCF.LookVector),
				}
			end
		end
	end
	return nil
end

local function rot(j, up, right, fwd)
	local cf = CFrame.identity
	if up ~= 0 then
		cf = cf * CFrame.fromAxisAngle(j.Up, up)
	end
	if right ~= 0 then
		cf = cf * CFrame.fromAxisAngle(j.Right, right)
	end
	if fwd ~= 0 then
		cf = cf * CFrame.fromAxisAngle(j.Fwd, fwd)
	end
	j.Obj.Transform = cf
end

---------------------------------------------------------------- ติดตั้งโมเดลให้สัตว์หนึ่งตัว
function CreatureVisuals.Attach(rig)
	local cfg = Creatures.Visual[rig.Id]
	local folder = assetFolder()
	local src = cfg and folder and folder:FindFirstChild(cfg.Model)
	if not src then
		return false
	end
	local model = src:Clone()
	model.Name = "Visual"
	local list = parts(model)
	if #list == 0 then
		return false
	end
	for _, p in ipairs(list) do
		p.Anchored = true -- ระหว่างจัดวาง
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
	end
	-- ลอกลายผิวเดิมออก (สีของ MeshPart ไม่แสดงถ้ามี TextureID) แล้วใช้วัสดุ/สีของธาตุแทน
	if cfg.Strip then
		for _, p in ipairs(list) do
			if p:IsA("MeshPart") then
				p.TextureID = ""
			end
			for _, sm in ipairs(p:GetChildren()) do
				if sm:IsA("SpecialMesh") then
					sm.TextureId = ""
				elseif sm:IsA("Decal") or sm:IsA("Texture") then
					sm:Destroy()
				end
			end
		end
	end
	-- สีใหม่ (เช่น มังกรไฟ)
	if cfg.Recolor then
		for _, p in ipairs(list) do
			local c = cfg.Recolor(p)
			if c then
				p.Color = c
			end
		end
	end
	if cfg.Material then
		for _, p in ipairs(list) do
			if p.Material ~= Enum.Material.Neon then
				p.Material = cfg.Material
			end
		end
	end
	-- ชิ้นหลัก
	local primary = findNamed(model, cfg.Primary)
	if not (primary and primary:IsA("BasePart")) then
		local best, vol = nil, -1
		for _, p in ipairs(list) do
			local v = p.Size.X * p.Size.Y * p.Size.Z
			if v > vol and p.Transparency < 1 then
				best, vol = p, v
			end
		end
		primary = best
	end
	model.PrimaryPart = primary
	-- ทิศหัว (แนวราบ) จากจุดกลางไปหัว
	local mn, mx = bounds(list)
	local center = (mn + mx) / 2
	local head = findNamed(model, cfg.Head)
	local dir
	local FRONT = { X = Vector3.xAxis, ["-X"] = -Vector3.xAxis, Z = Vector3.zAxis, ["-Z"] = -Vector3.zAxis }
	if cfg.Front then
		dir = FRONT[cfg.Front]
	elseif head then
		dir = posOf(head) - center
		dir = Vector3.new(dir.X, 0, dir.Z)
	end
	if not dir or dir.Magnitude < 0.01 then
		dir = Vector3.new(0, 0, -1)
	end
	dir = dir.Unit
	if cfg.Yaw then
		dir = (CFrame.Angles(0, cfg.Yaw, 0) * CFrame.lookAt(Vector3.zero, dir)).LookVector
	end
	-- ย่อ/ขยาย: ความยาวตามแนวหัว-หาง = ความยาว rig x Fit
	local horiz = math.abs((mx - mn):Dot(Vector3.new(abs(dir.X), 0, abs(dir.Z))))
	local length = 0
	for _, p in ipairs(list) do
		length = math.max(length, abs((p.Position - center):Dot(dir)) + p.Size.Magnitude * 0.25)
	end
	length = math.max(length * 2, horiz * 0.5, 0.1)
	local rigCF, rigSize = rig.Model:GetBoundingBox()
	local rigLen = math.max(rigSize.Z, rigSize.X)
	local scale = (rigLen * (cfg.Fit or 1)) / length
	if cfg.FitHeight then
		scale = (rigSize.Y * cfg.FitHeight) / math.max(mx.Y - mn.Y, 0.1)
	end
	-- ตั้งจุดหมุนที่กลาง-ล่าง หันไปทางหัว แล้วขยาย
	local pivot = CFrame.lookAt(Vector3.new(center.X, mn.Y, center.Z), Vector3.new(center.X, mn.Y, center.Z) + dir)
	primary.PivotOffset = primary.CFrame:ToObjectSpace(pivot) -- มี PrimaryPart แล้ว pivot ของโมเดล = pivot ของชิ้นหลัก
	model:ScaleTo(model:GetScale() * scale)
	-- หมุนให้หัวชี้ -Z ของ HumanoidRootPart และวางเท้าที่พื้นของ rig
	local root = rig.Root
	local bottomY = rigCF.Position.Y - rigSize.Y / 2
	local base = CFrame.new(root.Position.X, bottomY + (cfg.Lift or 0) * rigSize.Y, root.Position.Z) * (root.CFrame - root.CFrame.Position)
	model:PivotTo(base)
	-- ข้อต่อ: แบ่งปล้องสำหรับโมเดลนิ่ง
	local spine = cfg.Spine or {}
	if cfg.Segments then
		spine = segmentize(model, primary, root.CFrame.LookVector, cfg.Segments)
	else
		connectAll(model, primary)
	end
	local rootCF = root.CFrame
	local function collect(names)
		local out = {}
		for _, n in ipairs(names or {}) do
			local j = jointInfo(model, n, rootCF)
			if j then
				table.insert(out, j)
			end
		end
		return out
	end
	local V = {
		Model = model, Cfg = cfg, Primary = primary, Mode = cfg.Mode or "Quad",
		Spine = collect(spine), Tail = collect(cfg.Tail), Neck = collect(cfg.Neck), Jaw = collect(cfg.Jaw),
		Wings = { L = collect(cfg.WingL), R = collect(cfg.WingR) },
		Legs = { FL = collect(cfg.LegFL), FR = collect(cfg.LegFR), BL = collect(cfg.LegBL), BR = collect(cfg.LegBR) },
		Scale = scale,
	}
	-- ปลดล็อกแล้วเชื่อมกับ rig
	for _, p in ipairs(parts(model)) do
		p.Anchored = false
	end
	local weld = Instance.new("Motor6D")
	weld.Name = "VisualRoot"
	weld.Part0 = root
	weld.Part1 = primary
	weld.C0 = root.CFrame:ToObjectSpace(primary.CFrame)
	weld.Parent = primary
	V.Weld = weld
	V.BaseC0 = weld.C0
	-- เอฟเฟกต์ (ไฟลุก/ตาเรืองแสง)
	if cfg.Effects then
		pcall(cfg.Effects, model, primary, findNamed(model, cfg.Head))
	end
	model.Parent = rig.Model
	-- ซ่อน rig เดิมบนเครื่องเรา
	local mine = {}
	for _, p in ipairs(parts(model)) do
		mine[p] = true
	end
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("BasePart") and not mine[d] then
			d.LocalTransparencyModifier = 1
		elseif (d:IsA("Decal") or d:IsA("Texture")) and not d:IsDescendantOf(model) then
			d.Transparency = 1
		elseif (d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Fire") or d:IsA("Beam") or d:IsA("Trail")) and not d:IsDescendantOf(model) then
			d.Enabled = false
		end
	end
	rig.Visual = V
	return true
end

---------------------------------------------------------------- ท่าทางทุกเฟรม
-- ctx: { Now, Speed, Walk, Phase, Att, Kind, State, Flying, DeadT }
function CreatureVisuals.Animate(rig, ctx)
	local V = rig.Visual
	local now, walk, p, att = ctx.Now, ctx.Walk, ctx.Phase, ctx.Att
	local mode = V.Mode
	local seed = rig.Seed
	-- ตาย: ล้มตะแคงแล้วจาง
	if ctx.DeadT then
		local t = now - ctx.DeadT
		local k = clamp(t / 0.8, 0, 1)
		V.Weld.C0 = V.BaseC0 * CFrame.Angles(0, 0, 1.3 * k * k)
		if t > 1.4 then
			local a = clamp((t - 1.4) / 1.4, 0, 1)
			for _, d in ipairs(V.Model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = a
				end
			end
		end
		return
	end
	local swim = mode == "Swim" or mode == "Serpent"
	-- ลำตัว: ขึ้นลง/เอียง/ส่าย
	local bob, pitch, yaw, roll = 0, 0, 0, 0
	if mode == "Flyer" then
		local flap = sin(now * (ctx.Flying and 6 or 2.2) + seed)
		bob = flap * 0.04 * (V.Scale * 10)
		pitch = ctx.Flying and -0.08 or 0
	elseif swim then
		yaw = sin(now * 1.6 + seed) * 0.06 * (0.4 + walk)
		roll = sin(now * 1.6 + seed + 1) * 0.05
		bob = sin(now * 1.1 + seed) * 0.15
	else
		bob = abs(sin(p * 2)) * 0.08 * walk
		pitch = sin(now * 2 + seed) * 0.01
	end
	if ctx.Kind == "Roar" then
		pitch -= att * 0.12
	elseif ctx.Kind == "Bite" or ctx.Kind == "Leap" then
		pitch += att * 0.1
	end
	V.Weld.C0 = V.BaseC0 * CF(0, bob, 0) * CFrame.Angles(pitch, yaw, roll)
	-- กระดูกสันหลัง/หาง: คลื่นสะบัด
	local n = #V.Spine
	local freq = swim and (2 + walk * 2.5) or (2 + walk * 3)
	local amp = swim and (0.12 + walk * 0.1) or (0.04 + walk * 0.04)
	for i, j in ipairs(V.Spine) do
		local f = i / math.max(n, 1)
		rot(j, sin(now * freq - i * 0.7 + seed) * amp * (0.35 + f), 0, 0)
	end
	for i, j in ipairs(V.Tail) do
		rot(j, sin(now * (freq + 1) - i * 0.8 + seed) * (0.15 + walk * 0.12), 0, 0)
	end
	-- ขา
	local legAmp = (V.Cfg.LegAmp or 0.55) * walk
	local s = sin(p * 2) * legAmp
	local function legs(list, a)
		for k, j in ipairs(list) do
			rot(j, 0, a * (k == 1 and 1 or -0.6), 0)
		end
	end
	if mode == "Flyer" and ctx.Flying then
		legs(V.Legs.FL, 0.5)
		legs(V.Legs.FR, 0.5)
		legs(V.Legs.BL, -0.4)
		legs(V.Legs.BR, -0.4)
	else
		legs(V.Legs.FL, s)
		legs(V.Legs.BR, s)
		legs(V.Legs.FR, -s)
		legs(V.Legs.BL, -s)
	end
	-- ปีก
	local wf = sin(now * (ctx.Flying and 7 or 2.5) + seed) * (ctx.Flying and 0.6 or 0.12) + (ctx.Flying and 0 or 0.1)
	local wSign = V.Cfg.WingSign or 1
	for _, j in ipairs(V.Wings.L) do
		rot(j, 0, 0, wf * wSign)
	end
	for _, j in ipairs(V.Wings.R) do
		rot(j, 0, 0, -wf * wSign)
	end
	-- คอ/หัว + กราม
	for _, j in ipairs(V.Neck) do
		local look = sin(now * 0.7 + seed) * 0.15
		rot(j, look, (ctx.Kind == "Roar" and -att * 0.35 or att * 0.2) + sin(now * 1.3) * 0.04, 0)
	end
	for _, j in ipairs(V.Jaw) do
		rot(j, 0, att * (V.Cfg.JawOpen or 0.6) * (V.Cfg.JawSign or 1), 0)
	end
end

return CreatureVisuals
