--[[
	MeshProps — โครงของไอเทม/พร็อพที่มีโมเดลจริง (ReplicatedStorage.PropMeshData จาก blender/props_export.py)
	Server สร้าง Part ตามกล่องของแต่ละชิ้น (attribute SkinPart) -> client สวมเมชจริงทับ (AnimalSkins.Skin)
	เครื่องที่สร้างเมชไม่ได้จะเห็น Part สีเฉลี่ยแทน

	MeshProps.Has(kind)
	MeshProps.Build(kind, opts) -> Model (pivot อยู่ที่พื้นตรงกลาง)  opts.Collide = "trunk" | "box" | "none"
	MeshProps.BuildTool(kind) -> (handle, extraParts) สำหรับ Tool
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local AnimalSkins = require(script.Parent.AnimalSkins)

local MeshProps = {}
local SET = "PropMeshData"

local TREES = { Oak = true, GiantPine = true, AncientOak = true, Palm = true, FrostPine = true, CharredTree = true }
local NO_COLLIDE = { Bush = true, BerryBush = true, Flowers = true, GlowShroom = true, Campfire = true }
MeshProps.Trees = TREES

function MeshProps.Has(kind)
	return AnimalSkins.Has(kind, SET)
end

local function vec(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function basePart(p, name)
	local part = Instance.new("Part")
	part.Name = name or p.Name
	part.Size = vec(p.Size)
	part.CFrame = CFrame.new(vec(p.Center))
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if p.Glow then
		part.Material = Enum.Material.Neon
		part.Color = Color3.new(p.Glow[1], p.Glow[2], p.Glow[3])
	else
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.new(p.Color[1], p.Color[2], p.Color[3])
	end
	part:SetAttribute("SkinPart", true)
	part:SetAttribute("SkinName", p.Name)
	return part
end

local prototypes = {}

function MeshProps.Build(kind, opts)
	opts = opts or {}
	local proto = prototypes[kind]
	if not proto then
		local data = AnimalSkins.Data(kind, SET)
		if not data then
			return nil
		end
		proto = Instance.new("Model")
		proto.Name = kind
		local main
		for _, p in ipairs(data.Parts) do
			local part = basePart(p)
			part.CanCollide = false
			part.Parent = proto
			if p.Name == "Main" then
				main = part
			end
		end
		main = main or proto:FindFirstChildWhichIsA("BasePart")
		local collide = opts.Collide or (TREES[kind] and "trunk") or (NO_COLLIDE[kind] and "none") or "box"
		if collide == "trunk" and main then
			-- ต้นไม้: ชนเฉพาะลำต้นช่วงล่าง
			local s = main.Size
			local c = Instance.new("Part")
			c.Name = "Collider"
			c.Shape = Enum.PartType.Cylinder
			local h = s.Y * 0.55
			local d = math.max(math.min(s.X, s.Z) * 0.16, 1.2)
			c.Size = Vector3.new(h, d, d)
			c.CFrame = CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
			c.Anchored = true
			c.Transparency = 1
			c.Parent = proto
		elseif collide == "box" and main then
			main.CanCollide = true
		end
		proto.PrimaryPart = main
		proto.WorldPivot = CFrame.new(0, 0, 0)
		proto:SetAttribute("SkinSet", SET)
		proto:SetAttribute("SkinId", kind)
		prototypes[kind] = proto
	end
	local m = proto:Clone()
	CollectionService:AddTag(m, "MeshSkin")
	return m
end

-- Tool: Handle = ชิ้นหลัก (ด้ามตั้งตามแกน Y) + ชิ้นเรืองแสงติดกับ Handle
function MeshProps.BuildTool(kind, tool)
	local data = AnimalSkins.Data(kind, SET)
	if not data then
		return nil
	end
	local mainData
	for _, p in ipairs(data.Parts) do
		if p.Name == "Main" then
			mainData = p
		end
	end
	mainData = mainData or data.Parts[1]
	local handle = basePart(mainData, "Handle")
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = tool
	local origin = vec(mainData.Center)
	for _, p in ipairs(data.Parts) do
		if p ~= mainData then
			local part = basePart(p)
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			part.CFrame = CFrame.new(vec(p.Center) - origin)
			part.Parent = tool
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = part
			w.Parent = part
		end
	end
	tool:SetAttribute("SkinSet", SET)
	tool:SetAttribute("SkinId", kind)
	CollectionService:AddTag(tool, "MeshSkin")
	return handle
end

return MeshProps
