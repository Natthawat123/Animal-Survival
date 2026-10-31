--[[
	AnimalModels — สร้างโมเดลสัตว์ (ใช้ทั้ง Server และปลั๊กอิน)

	ใช้เฉพาะโมเดลที่ใส่เอง: ReplicatedStorage.Assets.Animals.<Id>  (ไฟล์ assets/rbxm/Animals/<Id>.rbxmx)
	ชิ้นชื่อ Body/Head/LegFL/LegFR/LegBL/LegBR/Tail1/WingL/WingR ... แล้วต่อกระดูกให้เองตามตำแหน่งชิ้น
	ไม่มีโมเดล = ไม่สร้างสัตว์ตัวนั้น (Build คืน nil)

	โครงกระดูก (Motor6D) -> AnimalAnimator (ฝั่ง client) ขยับตามชื่อ:
		HumanoidRootPart --Root--> Body
		Body --Neck--> Head --Jaw--> Jaw
		Body --LegFL/LegFR/LegBL/LegBR--> ขา
		Body --Tail1--> Tail1 --Tail2--> Tail2 ...
		Body --WingL/WingR--> ปีก
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Animals = require(script.Parent.Animals)

local AnimalModels = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

---------------------------------------------------------------- helpers
local function newPart(model, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif shape == "Wedge" then
		p:Destroy()
		p = Instance.new("WedgePart")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanTouch = false
		p.Massless = true
	end
	p.Parent = model
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
	return w
end

local function motor(name, p0, p1, jointWorld)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = p0.CFrame:Inverse() * jointWorld
	m.C1 = p1.CFrame:Inverse() * jointWorld
	m.Parent = p0
	return m
end

local function rigCustom(model, spec)
	local body = model:FindFirstChild("Body", true)
	if not body then
		return nil
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
			d.Parent = model
		end
	end
	-- ขนาดเพี้ยน (หน่วย cm/m ไม่ตรง) -> ปรับให้ใกล้ขนาดในสเปก
	local _, size0 = model:GetBoundingBox()
	if spec.Body then
		local expected = (spec.LegLen or 2) + spec.Body.Y + (spec.Neck or 0) * 0.6 + (spec.Head and spec.Head.Y * 0.5 or 0)
		local ratio = expected / math.max(size0.Y, 0.01)
		if ratio < 0.5 or ratio > 2 then
			pcall(function()
				model:ScaleTo(model:GetScale() * ratio)
			end)
		end
	end
	-- หันหน้าผิดทาง -> หมุนให้หัวอยู่ทาง -Z (LookVector ของ Roblox)
	local headPart = model:FindFirstChild("Head")
	if headPart then
		local dir = (headPart.Position - body.Position) * Vector3.new(1, 0, 1)
		if dir.Magnitude > 0.1 then
			local theta = math.atan2(-dir.X, -dir.Z)
			if math.abs(theta) > 0.3 then
				local pivot = CF(body.Position)
				local rot = pivot * ANG(0, -theta, 0) * pivot:Inverse()
				for _, p in ipairs(model:GetChildren()) do
					if p:IsA("BasePart") then
						p.CFrame = rot * p.CFrame
					end
				end
			end
		end
	end
	local cf, size = model:GetBoundingBox()
	local groundY = cf.Position.Y - size.Y / 2
	local root = newPart(model, "HumanoidRootPart", body.Size, body.CFrame, Color3.new(1, 1, 1))
	root.Transparency = 1
	root.CanCollide = false -- บอสยักษ์เดินทะลุต้นไม้ได้ (Humanoid ยืนด้วย HipHeight)
	root.Massless = false
	motor("Root", root, body, body.CFrame)
	local head = model:FindFirstChild("Head")
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p ~= root and p ~= body then
			local n = p.Name
			if n == "Head" then
				motor("Neck", body, p, JOINT_RULES.Head(p))
			elseif n == "Jaw" and head then
				motor("Jaw", head, p, JOINT_RULES.Jaw(p))
			elseif n:match("^Leg") or n:match("^Claw") then
				motor(n, body, p, JOINT_RULES.Leg(p))
			elseif n:match("^Tail%d") then
				local idx = tonumber(n:match("%d+"))
				local parent = idx > 1 and model:FindFirstChild("Tail" .. (idx - 1)) or body
				motor(n, parent, p, JOINT_RULES.Tail(p))
			elseif n == "WingL" or n == "WingR" then
				motor(n, body, p, JOINT_RULES[n](p))
			else
				-- ของตกแต่ง: ติดกับชิ้นที่ใกล้ที่สุด
				local nearest, best = body, math.huge
				for _, q in ipairs({ body, head }) do
					if q then
						local d = (q.Position - p.Position).Magnitude
						if d < best then
							nearest, best = q, d
						end
					end
				end
				weld(nearest, p)
			end
		end
	end
	return root, body.Position.Y - body.Size.Y / 2 - groundY
end

---------------------------------------------------------------- โครงจากโมเดลจริง (AnimalMeshData)
-- 1 ชิ้นเมช = 1 Part (ขนาด/ตำแหน่งเท่าชิ้นเมช) -> client สวมผิวเมชจริงทับ (AnimalSkins)
-- ถ้าเครื่องไหนสร้างเมชไม่ได้ จะเห็น Part เป็นก้อนทรงรีสีเฉลี่ยของชิ้นนั้นแทน
local MAIN_PARTS = { Body = true, Head = true, Jaw = true, LegFL = true, LegFR = true, LegBL = true, LegBR = true, Tail1 = true, WingL = true, WingR = true }

-- โมเดลมีผิว+กระดูก (Import 3D จาก Studio): MeshPart 1 ชิ้น + Bone -> ขยายตาม Skin.Scale
-- ต่อกับ HumanoidRootPart (กล่องชนล่องหน) · กระดูกขยับฝั่ง client (BossAnimator)
local function buildSkinned(model, custom, skin)
	local src = custom:Clone()
	-- Size = ความยาวด้านยาวสุดที่ต้องการ (stud) -> คำนวณสเกลจากขนาดตอน Import เอง
	local scale = skin.Scale or 10
	if skin.Size then
		local m0 = src:FindFirstChildWhichIsA("MeshPart", true)
		local big = m0 and math.max(m0.Size.X, m0.Size.Y, m0.Size.Z) or 1
		scale = skin.Size / math.max(big, 0.01)
	end
	pcall(function()
		src:ScaleTo(scale)
	end)
	local mesh = src:FindFirstChildWhichIsA("MeshPart", true)
	if not mesh then
		src:Destroy()
		return nil
	end
	mesh.Name = "Skin"
	mesh.Anchored = false
	mesh.CanCollide = false
	mesh.CanTouch = false
	mesh.Massless = true
	local size = mesh.Size
	local hip = size.Y * 0.2
	local rootSize = V(math.max(size.X, 2) * 0.55, size.Y * 0.5, math.max(size.Z, 2) * 0.55)
	local root = newPart(model, "HumanoidRootPart", rootSize, CF(0, hip + rootSize.Y / 2, 0), Color3.new(1, 1, 1))
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.CastShadow = false
	mesh.CFrame = CF(0, size.Y / 2, 0)
	mesh.Parent = model
	weld(root, mesh)
	src:Destroy()
	model:SetAttribute("Skinned", true)
	model:SetAttribute("SkinRig", skin.Rig or "Biped")
	model:SetAttribute("SkinScale", scale) -- ท่าจากไฟล์ (ClipAnimator) คูณตำแหน่งกระดูกตามนี้
	return root, hip
end

-- โมเดลนิ่งจาก Creator Store (ไม่มีกระดูก, กี่ชิ้นก็ได้): ด้านยาวสุด = Skin.Size · Skin.Yaw หมุนให้หน้าหัน -Z
-- ทุกชิ้นเชื่อมกับชิ้นใหญ่สุด ("Skin") ซึ่งต่อกับ root ด้วย Motor6D -> client ทำท่ากระโดดดุ๊กดิ๊ก (AnimalAnimator)
local function buildStatic(model, custom, skin, sizeMult)
	local src = custom:Clone()
	local parts = {}
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("LuaSourceContainer") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	if #parts == 0 then
		src:Destroy()
		return nil
	end
	local r = ANG(0, math.rad(skin.Yaw or 0), 0)
	for _, p in ipairs(parts) do
		p.CFrame = r * p.CFrame
	end
	local _, box = src:GetBoundingBox()
	pcall(function()
		src:ScaleTo((skin.Size or 4) * (sizeMult or 1) / math.max(box.X, box.Y, box.Z, 0.01))
	end)
	local bcf, size = src:GetBoundingBox()
	local shift = V(bcf.Position.X, bcf.Position.Y - size.Y / 2, bcf.Position.Z)
	local main = parts[1]
	for _, p in ipairs(parts) do
		p.CFrame = p.CFrame - shift
		p.Anchored, p.CanCollide, p.CanTouch, p.Massless = false, false, false, true
		if p.Size.Magnitude > main.Size.Magnitude then
			main = p
		end
	end
	local hip = size.Y * 0.2
	local rootSize = V(math.max(size.X, 2) * 0.55, size.Y * 0.5, math.max(size.Z, 2) * 0.55)
	local root = newPart(model, "HumanoidRootPart", rootSize, CF(0, hip + rootSize.Y / 2, 0), Color3.new(1, 1, 1))
	root.Transparency, root.CanCollide, root.Massless, root.CastShadow = 1, true, false, false
	for _, p in ipairs(parts) do
		p.Parent = model
		if p ~= main then
			weld(main, p)
		end
	end
	main.Name = "Skin"
	-- ข้อต่อที่ "ใต้เท้า กลางตัว" แกนตรงกับ root -> client โยก/เอียง/เด้งรอบเท้าได้ถูกแกน (เดิมใช้แกนของชิ้นเมช = เอียงผิดทิศ)
	motor("SkinJoint", root, main, CF(0, 0, 0))
	src:Destroy()
	model:SetAttribute("Skinned", true)
	model:SetAttribute("SkinRig", "Static")
	return root, hip
end

-- โมเดลแยกชิ้นจาก Creator Store (ออร์กา/หมึก): ตั้งชื่อชิ้นตามโครงไว้แล้ว (tools/import_water_mon.py) -> ต่อ Motor6D ให้ AnimalAnimator ขยับ
--   Body = ลำตัวหลัก · Jaw = ขากรรไกร (บานพับด้านหลังบน) · Tail1..n = หางต่อกันเป็นโซ่ (ข้อต่อด้านหน้าของแต่ละท่อน)
--   FinL/FinR = ครีบ (ข้อต่อขอบด้านใน) · Tent1..n = หนวด (ข้อต่อโคนหนวด หันออกจากกลางตัว)
--   "อะไรก็ได้@Target" = เชื่อมติดชิ้น Target · ชิ้นอื่น = ติดลำตัว
local function extentAlong(p, axis)
	local cf, s = p.CFrame, p.Size / 2
	return math.abs(cf.RightVector:Dot(axis)) * s.X + math.abs(cf.UpVector:Dot(axis)) * s.Y + math.abs(cf.LookVector:Dot(axis)) * s.Z
end
local function buildParts(model, custom, skin)
	local src = custom:Clone()
	local parts = {}
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("LuaSourceContainer") or d:IsA("Humanoid") then
			d:Destroy()
		end
	end
	local _, box = src:GetBoundingBox()
	pcall(function()
		src:ScaleTo((skin.Size or 8) / math.max(box.X, box.Z, 0.01))
	end)
	local bcf, size = src:GetBoundingBox()
	local shift = V(bcf.Position.X, bcf.Position.Y - size.Y / 2, bcf.Position.Z)
	local byName = {}
	for _, p in ipairs(parts) do
		p.CFrame = p.CFrame - shift
		p.Anchored, p.CanCollide, p.CanTouch, p.Massless, p.CanQuery = false, false, false, true, false
		p.Parent = model
		byName[p.Name] = byName[p.Name] or p
	end
	src:Destroy()
	local body = byName.Body
	if not body then
		return nil
	end
	local hip = size.Y * (skin.Hip or 0.2)
	local rootSize = V(math.max(size.X, 2) * 0.55, size.Y * 0.5, math.max(size.Z, 2) * 0.55)
	local root = newPart(model, "HumanoidRootPart", rootSize, CF(0, hip + rootSize.Y / 2, 0), Color3.new(1, 1, 1))
	root.Transparency, root.CanCollide, root.Massless, root.CastShadow = 1, true, false, false
	motor("Root", root, body, CF(body.Position))
	-- กลางวงหนวด (ถุงลำตัวหมึกยื่นไปข้างหลัง ไม่ใช่กลางวง)
	local center, nt = V(), 0
	for _, p in ipairs(parts) do
		if p.Name:match("^Tent%d") then
			center += p.Position
			nt += 1
		end
	end
	center = nt > 0 and center / nt or body.Position
	for _, p in ipairs(parts) do
		local n = p.Name
		local target = n:match("@(%w+)$")
		local pos = p.Position
		if target then
			weld(byName[target] or body, p)
		elseif n == "Body" then
			-- ต่อกับ root แล้ว
		elseif n == "Jaw" then
			local up, back = extentAlong(p, V(0, 1, 0)), extentAlong(p, V(0, 0, 1))
			motor("Jaw", body, p, CF(pos + V(0, up * 0.6, back * 0.85)))
		elseif n:match("^Tail%d") then
			local idx = tonumber(n:match("%d+"))
			local parent = idx > 1 and byName["Tail" .. (idx - 1)] or body
			motor(n, parent, p, CF(pos - V(0, 0, extentAlong(p, V(0, 0, 1)) * 0.85)))
		elseif n == "FinL" or n == "FinR" then
			local side = n == "FinL" and 1 or -1 -- ขอบด้านในชี้เข้าหาลำตัว
			motor(n, body, p, CF(pos + V(side * extentAlong(p, V(1, 0, 0)) * 0.8, extentAlong(p, V(0, 1, 0)) * 0.6, 0)))
		elseif n:match("^Tent%d") then
			local out = (pos - center) * V(1, 0, 1)
			out = out.Magnitude > 0.01 and out.Unit or V(0, 0, 1)
			local base = pos - out * extentAlong(p, out) * 0.9
			-- แกน X ของข้อต่อ = แนวสัมผัสวง (หมุนรอบนี้ = หนวดม้วนขึ้น/ลง) · แกน Y = ขึ้น (หมุนรอบนี้ = กวาดซ้ายขวา)
			local tangent = V(0, 1, 0):Cross(out).Unit
			motor(n, body, p, CFrame.fromMatrix(base, tangent, V(0, 1, 0)))
		else
			weld(body, p)
		end
	end
	model:SetAttribute("Skinned", true)
	model:SetAttribute("SkinRig", "Parts")
	return root, hip
end

local function boxOf(parts)
	local lo, hi = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(parts) do
		local cf, s = p.CFrame, p.Size / 2
		local ext = V(
			math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z,
			math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z,
			math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
		)
		lo = lo:Min(cf.Position - ext)
		hi = hi:Max(cf.Position + ext)
	end
	return lo, hi
end
local function largest(parts)
	local best
	for _, p in ipairs(parts) do
		if not best or p.Size.X * p.Size.Y * p.Size.Z > best.Size.X * best.Size.Y * best.Size.Z then
			best = p
		end
	end
	return best
end
-- สัตว์ที่มีโครงในไฟล์ (Motor6D/Bone จาก Creator Store): เก็บข้อต่อเดิม ขยาย/หันหน้าให้ แล้วเปลี่ยน root เป็นกล่องชนของเกม
--   Skin.Yaw = องศาที่หมุนให้หัวชี้ -Z · Skin.Auto = โมเดลแยกชิ้นไม่มีข้อต่อ -> แบ่งลำตัว/ขา/หาง/หัวจากตำแหน่ง แล้วต่อ Motor6D เอง
--   ท่าเดินอยู่ฝั่ง client (SkelAnimator) อ้างชื่อกระดูก/ชิ้นจาก Skin.Legs, Skin.Neck, Skin.Tail
local SKEL_DROP = { Humanoid = true, AnimationController = true, Animator = true, Animation = true, KeyframeSequence = true, Sound = true, Folder = true,
	ProximityPrompt = true, BillboardGui = true, Camera = true, IntValue = true, BoolValue = true, StringValue = true, NumberValue = true, CFrameValue = true, Vector3Value = true, ObjectValue = true,
	BodyColors = true, Shirt = true, Pants = true }
local function buildSkeleton(model, custom, skin, sizeMult)
	local src = custom:Clone()
	-- บางไฟล์เก็บข้อต่อไว้ใต้ Model/Folder: ย้ายไปอยู่กับชิ้นก่อน ไม่งั้นหายไปพร้อม src แล้วทั้งตัวกลายเป็นก้อนเดียว
	for _, d in ipairs(src:GetDescendants()) do
		if (d:IsA("JointInstance") or d:IsA("WeldConstraint")) and d.Part0 and d.Part0:IsDescendantOf(src) then
			d.Parent = d.Part0
		end
	end
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or SKEL_DROP[d.ClassName] then
			d:Destroy()
		end
	end
	local parts, oldRoot = {}, nil
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			if d.Name == "HumanoidRootPart" or d.Name == "RootPart" then
				oldRoot = d
			end
		end
	end
	if #parts == 0 then
		src:Destroy()
		return nil
	end
	local visible = {}
	for _, p in ipairs(parts) do
		if p.Transparency < 0.9 then
			table.insert(visible, p)
		end
	end
	local r = ANG(0, math.rad(skin.Yaw or 0), 0)
	for _, p in ipairs(parts) do
		p.CFrame = r * p.CFrame
	end
	local lo0, hi0 = boxOf(visible)
	local long0 = math.max(hi0.X - lo0.X, hi0.Y - lo0.Y, hi0.Z - lo0.Z, 0.01)
	local scale = (skin.Size or 5) * (sizeMult or 1) / long0
	pcall(function()
		src:ScaleTo(src:GetScale() * scale)
	end)
	local lo, hi = boxOf(visible)
	local shift = V((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	for _, p in ipairs(parts) do
		p.CFrame = p.CFrame - shift
		p.Anchored, p.CanCollide, p.CanTouch, p.Massless, p.CanQuery = false, false, false, true, false
	end
	local size = hi - lo
	local hip = size.Y * 0.2
	local rootSize = V(math.max(size.X, 2) * 0.55, size.Y * 0.5, math.max(size.Z, 2) * 0.55)
	local rootCF = CF(0, hip + rootSize.Y / 2, 0)
	local root
	if oldRoot then
		-- ใช้ root เดิม (ข้อต่อ/กระดูกลูกของมันอ้างอยู่) ย้ายมาที่กล่องชนใหม่ แล้วปรับค่าที่อ้างตำแหน่ง root ให้ของเดิมอยู่ที่เดิม
		local fix = rootCF:Inverse() * oldRoot.CFrame
		for _, d in ipairs(src:GetDescendants()) do
			if d:IsA("Motor6D") or d:IsA("Weld") then
				if d.Part0 == oldRoot then
					d.C0 = fix * d.C0
				elseif d.Part1 == oldRoot then
					-- ข้อต่อกลับด้าน (ชิ้นลำตัว -> root): สลับให้ root เป็นแม่ ท่าเดินจะได้เลื่อนลำตัวได้
					local p0, c0, c1 = d.Part0, d.C0, d.C1
					d.Part0, d.Part1 = oldRoot, p0
					d.C0, d.C1 = fix * c1, c0
				end
			elseif d:IsA("Bone") and d.Parent == oldRoot then
				d.CFrame = fix * d.CFrame
			end
		end
		root = oldRoot
		root.Name = "HumanoidRootPart"
		root.Size = rootSize
		root.CFrame = rootCF
	else
		root = newPart(model, "HumanoidRootPart", rootSize, rootCF, Color3.new(1, 1, 1))
	end
	root.Transparency, root.CanCollide, root.Massless, root.CastShadow = 1, true, false, false
	for _, p in ipairs(parts) do
		p.Parent = model
	end
	if skin.Auto then
		-- แบ่งชิ้นจากตำแหน่ง (หน้า = -Z): ชิ้นล่างสุด = ขา · ท้ายตัว = หาง · หน้าตัวและสูง = หัว · ที่เหลือ = ลำตัว
		local groups = { Body = {}, Leg = {}, Tail = {}, Head = {} }
		local len, tall = size.Z, size.Y
		for _, p in ipairs(visible) do
			local c = p.Position
			if c.Y < tall * 0.3 then
				table.insert(groups.Leg, p)
			elseif c.Z > len * 0.17 then
				table.insert(groups.Tail, p)
			elseif c.Z < -len * 0.2 then
				table.insert(groups.Head, p)
			else
				table.insert(groups.Body, p)
			end
		end
		local body = largest(groups.Body)
		body.Name = "Body"
		motor("BodyRoot", root, body, CF(body.Position))
		for _, p in ipairs(groups.Body) do
			if p ~= body then
				weld(body, p)
			end
		end
		local function joint(name, list, pivot)
			local main = largest(list)
			if not main then
				return
			end
			motor(name, body, main, CF(pivot))
			main.Name = name
			for _, p in ipairs(list) do
				if p ~= main then
					weld(main, p)
				end
			end
		end
		local l, h = boxOf(groups.Head)
		joint("Neck", groups.Head, V((l.X + h.X) / 2, l.Y + (h.Y - l.Y) * 0.35, h.Z - (h.Z - l.Z) * 0.2))
		l, h = boxOf(groups.Tail)
		joint("Tail1", groups.Tail, V((l.X + h.X) / 2, (l.Y + h.Y) / 2, l.Z))
		for _, p in ipairs(groups.Leg) do
			local c = p.Position
			local _, top = boxOf({ p })
			joint("Leg" .. (c.Z < 0 and "F" or "B") .. (c.X < 0 and "L" or "R"), { p }, V(c.X, top.Y, c.Z))
		end
	else
		-- ชิ้นที่ไม่ได้ต่อกับใคร (เช่น ของตกแต่ง) เชื่อมกับลำตัว ไม่ให้ร่วงหลุดจากตัว
		local linked = { [root] = true }
		local changed = true
		while changed do
			changed = false
			for _, d in ipairs(model:GetDescendants()) do
				if (d:IsA("JointInstance") or d:IsA("WeldConstraint")) and d.Part0 and d.Part1 then
					if linked[d.Part0] ~= linked[d.Part1] then
						linked[d.Part0], linked[d.Part1] = true, true
						changed = true
					end
				end
			end
		end
		local anchor = largest(visible)
		for _, p in ipairs(parts) do
			if not linked[p] and p ~= anchor then
				weld(anchor, p)
			end
		end
		if not linked[anchor] then
			weld(root, anchor)
		end
	end
	if skin.Tint then
		-- โมเดลไม่มีเท็กซ์เจอร์ (สีเทาล้วน): ย้อมสีธาตุ ไม่แตะชิ้นสีอื่น เช่น จมูก/หูชมพู
		for _, p in ipairs(visible) do
			if math.abs(p.Color.R - 0.64) < 0.02 and math.abs(p.Color.G - 0.635) < 0.02 then
				p.Color = skin.Tint
			end
		end
	end
	src:Destroy()
	model:SetAttribute("Skinned", true)
	model:SetAttribute("SkinRig", "Skeleton")
	model:SetAttribute("SkinScale", scale) -- ตำแหน่งในท่าจากไฟล์ (SkelClips) คูณตามนี้
	return root, hip
end

-- มีโมเดลของสัตว์ตัวนี้ในเกมไหม (ไม่มี = Build คืน nil) เช่น ไม่เตือนกวางกลวงถ้ายังไม่มีโมเดล
function AnimalModels.Has(id)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Animals")
	return folder ~= nil and folder:FindFirstChild(id) ~= nil
end

function AnimalModels.Build(id, opts)
	opts = opts or {}
	local info = Animals.Data[id]
	assert(info, "ไม่รู้จักสัตว์: " .. tostring(id))
	local spec = info.Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("Animals") and assets.Animals:FindFirstChild(id)
	if not custom then
		return nil -- ยังไม่มีโมเดลของสัตว์ตัวนี้
	end
	local model = Instance.new("Model")
	model.Name = id
	local root, hip
	if spec.Skin and spec.Skin.Rig == "Skeleton" then
		root, hip = buildSkeleton(model, custom, spec.Skin, opts.SizeMult)
	elseif spec.Skin and spec.Skin.Rig == "Static" then
		root, hip = buildStatic(model, custom, spec.Skin, opts.SizeMult) -- SizeMult: ลูกสัตว์ที่ช่วยแล้วโตขึ้นที่แคมป์ (ขี่ได้)
	elseif spec.Skin and spec.Skin.Rig == "Parts" then
		root, hip = buildParts(model, custom, spec.Skin)
	elseif spec.Skin and custom:FindFirstChildWhichIsA("Bone", true) then
		root, hip = buildSkinned(model, custom, spec.Skin)
	else
		for _, c in ipairs(custom:GetChildren()) do
			c:Clone().Parent = model
		end
		root, hip = rigCustom(model, spec)
	end
	if not root then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = root
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = hip
	hum.MaxHealth = (info.Health == math.huge) and 1e9 or info.Health
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = info.Speed or 16
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.MaxSlopeAngle = 70
	hum.AutoJumpEnabled = true
	hum.UseJumpPower = true
	hum.JumpPower = 40
	for _, st in ipairs({ Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.PlatformStanding }) do
		hum:SetStateEnabled(st, false)
	end
	hum.Parent = model

	model:SetAttribute("AnimalId", id)
	model:SetAttribute("Template", (model:GetAttribute("SkinRig") == "Skeleton" and "Skel") or (model:FindFirstChild("WingL") and "Bird" or spec.Template))
	model:SetAttribute("Element", info.Element or "None")
	model:SetAttribute("Behaviour", info.Behaviour)
	if opts.Tag ~= false then
		CollectionService:AddTag(model, "Animal")
	end
	return model
end

-- จุดหมุนให้วางบนพื้น: วางโมเดลให้เท้าอยู่ที่ position
function AnimalModels.PlaceAt(model, position, yaw)
	local root = model.PrimaryPart
	local cf, size = model:GetBoundingBox()
	local offset = root.Position.Y - (cf.Position.Y - size.Y / 2)
	model:PivotTo(CF(position + V(0, offset, 0)) * ANG(0, yaw or 0, 0))
end

return AnimalModels
