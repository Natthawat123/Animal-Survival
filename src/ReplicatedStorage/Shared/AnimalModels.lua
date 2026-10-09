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
	pcall(function()
		src:ScaleTo(skin.Scale or 10)
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
	return root, hip
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
	if spec.Skin and custom:FindFirstChildWhichIsA("Bone", true) then
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
	hum.Parent = model

	model:SetAttribute("AnimalId", id)
	model:SetAttribute("Template", model:FindFirstChild("WingL") and "Bird" or spec.Template)
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
