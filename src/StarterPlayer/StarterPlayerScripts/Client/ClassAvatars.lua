--[[
	ClassAvatars — ตัวละครของแต่ละคลาส: โมเดลจริงจาก Blender (Char_<Class>) / หุ่นบล็อกสำรองถ้าไม่มีข้อมูลเมช
	ใช้ทั้งรูปโปรไฟล์วงกลมในร้านคลาส (ViewportFrame) และหุ่นโชว์บนเวทีในเต็นท์ Classes
	Build(classId) -> Model (เท้าอยู่ที่ y = 0, หันหน้า -Z)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MeshProps = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MeshProps"))

local ClassAvatars = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local C = Color3.fromRGB

local SKIN = C(206, 164, 126)

-- ชุดของแต่ละคลาส
local OUTFIT = {
	Survivor = { Shirt = C(64, 92, 140), Pants = C(52, 52, 62), Hat = "None", Extra = "Scarf", Accent = C(90, 150, 80) },
	Forager = { Shirt = C(112, 146, 72), Pants = C(96, 74, 52), Hat = "Straw", HatColor = C(222, 192, 112), Extra = "Basket", Accent = C(200, 60, 80) },
	Lumberjack = { Shirt = C(176, 42, 42), Pants = C(58, 70, 110), Hat = "Beanie", HatColor = C(40, 40, 44), Extra = "Beard", Accent = C(96, 62, 40), Plaid = true },
	Medic = { Shirt = C(236, 236, 240), Pants = C(196, 200, 212), Hat = "Cap", HatColor = C(240, 240, 244), Extra = "Cross", Accent = C(220, 40, 40) },
	Hunter = { Shirt = C(86, 108, 58), Pants = C(70, 60, 42), Hat = "Hood", HatColor = C(70, 92, 48), Extra = "Quiver", Accent = C(120, 84, 50) },
	Builder = { Shirt = C(242, 140, 40), Pants = C(58, 70, 110), Hat = "HardHat", HatColor = C(250, 210, 40), Extra = "Belt", Accent = C(90, 70, 40) },
	Scout = { Shirt = C(182, 162, 112), Pants = C(92, 82, 60), Hat = "Ranger", HatColor = C(120, 86, 52), Extra = "Bag", Accent = C(70, 110, 70) },
	Firekeeper = { Shirt = C(70, 34, 30), Pants = C(44, 32, 30), Hat = "Hood", HatColor = C(200, 82, 32), Extra = "Ember", Accent = C(255, 140, 40) },
	Elementalist = { Shirt = C(86, 50, 140), Pants = C(70, 40, 116), Hat = "Wizard", HatColor = C(96, 56, 156), Extra = "Orbs", Accent = C(120, 230, 255) },
	Beastwarden = { Shirt = C(84, 70, 60), Pants = C(54, 46, 42), Hat = "Wolf", HatColor = C(124, 124, 134), Extra = "Fur", Accent = C(220, 220, 228) },
}

local function part(m, props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = m
	return p
end

local function cylY(m, h, d, cf, color, mat)
	return part(m, { Shape = Enum.PartType.Cylinder, Size = V(h, d, d), CFrame = cf * ANG(0, 0, math.pi / 2), Color = color, Material = mat or Enum.Material.SmoothPlastic })
end

local function hat(m, kind, color, head)
	local top = head * CF(0, 0.62, 0)
	if kind == "Straw" then
		cylY(m, 0.15, 3.4, top * CF(0, -0.05, 0), color, Enum.Material.Fabric)
		cylY(m, 0.7, 1.7, top * CF(0, 0.3, 0), color, Enum.Material.Fabric)
		cylY(m, 0.2, 1.75, top * CF(0, 0.05, 0), C(170, 50, 60))
	elseif kind == "Beanie" then
		part(m, { Shape = Enum.PartType.Ball, Size = V(1.75, 1.3, 1.75), CFrame = top * CF(0, 0.05, 0), Color = color, Material = Enum.Material.Fabric })
		cylY(m, 0.35, 1.8, top * CF(0, -0.15, 0), color:Lerp(C(0, 0, 0), 0.2), Enum.Material.Fabric)
	elseif kind == "Cap" then
		cylY(m, 0.55, 1.65, top * CF(0, 0.05, 0), color)
		part(m, { Size = V(1.4, 0.12, 0.9), CFrame = top * CF(0, -0.15, -0.95), Color = color })
		part(m, { Size = V(0.5, 0.15, 0.06), CFrame = top * CF(0, 0.1, -0.84), Color = C(220, 40, 40) })
		part(m, { Size = V(0.15, 0.5, 0.06), CFrame = top * CF(0, 0.1, -0.84), Color = C(220, 40, 40) })
	elseif kind == "Hood" then
		part(m, { Size = V(1.9, 1.5, 1.6), CFrame = head * CF(0, 0.25, 0.25), Color = color, Material = Enum.Material.Fabric })
		part(m, { ClassName = "WedgePart", Size = V(1.9, 0.8, 0.9), CFrame = head * CF(0, 1.15, 0.45) * ANG(0, math.pi, 0), Color = color, Material = Enum.Material.Fabric })
		part(m, { Size = V(1.95, 0.3, 0.3), CFrame = head * CF(0, 0.85, -0.5), Color = color:Lerp(C(0, 0, 0), 0.25), Material = Enum.Material.Fabric })
	elseif kind == "HardHat" then
		part(m, { Shape = Enum.PartType.Ball, Size = V(1.8, 1.2, 1.8), CFrame = top * CF(0, 0.1, 0), Color = color })
		cylY(m, 0.12, 2.3, top * CF(0, -0.15, 0), color)
	elseif kind == "Ranger" then
		cylY(m, 0.12, 3, top * CF(0, -0.05, 0), color, Enum.Material.Fabric)
		cylY(m, 0.75, 1.6, top * CF(0, 0.35, 0), color, Enum.Material.Fabric)
		part(m, { Size = V(1.65, 0.2, 1.65), CFrame = top * CF(0, 0.1, 0), Color = C(60, 44, 30), Material = Enum.Material.Fabric })
	elseif kind == "Wizard" then
		cylY(m, 0.15, 3, top * CF(0, -0.05, 0), color, Enum.Material.Fabric)
		for i, d in ipairs({ 1.7, 1.35, 1.0, 0.68, 0.38 }) do
			cylY(m, 0.55, d, top * CF(0, 0.2 + i * 0.5, 0.06 * i * i) * ANG(-0.06 * i, 0, 0), color, Enum.Material.Fabric)
		end
		part(m, { Shape = Enum.PartType.Ball, Size = V(0.4, 0.4, 0.4), CFrame = top * CF(0, 3.05, 1.6), Color = C(120, 230, 255), Material = Enum.Material.Neon })
		cylY(m, 0.22, 1.75, top * CF(0, 0.12, 0), C(120, 230, 255), Enum.Material.Neon)
	elseif kind == "Wolf" then
		part(m, { Size = V(1.95, 1.4, 1.7), CFrame = head * CF(0, 0.35, 0.2), Color = color, Material = Enum.Material.Fabric })
		part(m, { Size = V(1.2, 0.6, 1.1), CFrame = head * CF(0, 0.95, -0.75) * ANG(-0.15, 0, 0), Color = color, Material = Enum.Material.Fabric })
		part(m, { Size = V(0.5, 0.25, 0.3), CFrame = head * CF(0, 0.85, -1.35), Color = C(30, 30, 34) })
		for _, x in ipairs({ -0.6, 0.6 }) do
			part(m, { ClassName = "WedgePart", Size = V(0.3, 0.6, 0.5), CFrame = head * CF(x, 1.35, 0.1), Color = color, Material = Enum.Material.Fabric })
		end
		part(m, { Size = V(2.2, 0.5, 1.4), CFrame = head * CF(0, -0.75, 0.2), Color = C(220, 220, 228), Material = Enum.Material.Fabric })
	end
end

-- ตัวละครโมเดลจริง (Quaternius CC0 -> blender/characters_export.py -> PropMeshData/Char_<Class>)
local function meshCharacter(classId)
	local kind = "Char_" .. tostring(classId)
	if not MeshProps.Has(kind) then
		return nil
	end
	local m = MeshProps.Build(kind, { Collide = "none" })
	-- มี PrimaryPart แล้ว pivot = กลางชิ้น -> ย้าย pivot ไปที่เท้า (จุดกำเนิดของโมเดล)
	local pp = m.PrimaryPart
	if pp then
		pp.PivotOffset = pp.CFrame:Inverse()
	end
	return m
end

-- (ตัวละครเป็นเมชนิ่งท่า idle — การขยับทำในร้านคลาส)
function ClassAvatars.PlayIdle(_model) end

function ClassAvatars.Build(classId, _waitSec)
	local real = meshCharacter(classId)
	if real then
		return real, true
	end
	local o = OUTFIT[classId] or OUTFIT.Survivor
	local m = Instance.new("Model")
	m.Name = "ClassAvatar_" .. tostring(classId)
	local root = CF(0, 0, 0)
	-- ขา
	for _, x in ipairs({ -0.5, 0.5 }) do
		part(m, { Size = V(1, 2, 1), CFrame = root * CF(x, 1, 0), Color = o.Pants })
		part(m, { Size = V(1.02, 0.4, 1.06), CFrame = root * CF(x, 0.2, -0.02), Color = C(52, 40, 32) })
	end
	-- ลำตัว
	local torso = part(m, { Name = "Torso", Size = V(2, 2, 1), CFrame = root * CF(0, 3, 0), Color = o.Shirt })
	if o.Plaid then
		for i = -1, 1 do
			part(m, { Size = V(2.02, 0.18, 1.02), CFrame = torso.CFrame * CF(0, i * 0.6, 0), Color = C(40, 30, 30) })
			part(m, { Size = V(0.18, 2.02, 1.02), CFrame = torso.CFrame * CF(i * 0.6, 0, 0), Color = C(40, 30, 30) })
		end
	end
	-- แขน
	for _, x in ipairs({ -1.5, 1.5 }) do
		part(m, { Size = V(1, 2, 1), CFrame = root * CF(x, 3, 0), Color = o.Shirt })
		part(m, { Size = V(1.02, 0.5, 1.02), CFrame = root * CF(x, 2.2, 0), Color = SKIN })
	end
	-- หัว + หน้า
	local headCf = root * CF(0, 4.6, 0)
	local head = part(m, { Name = "Head", Size = V(2, 1, 1), CFrame = headCf, Color = SKIN })
	local hm = Instance.new("SpecialMesh")
	hm.MeshType = Enum.MeshType.Head
	hm.Scale = V(1.25, 1.25, 1.25)
	hm.Parent = head
	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	hat(m, o.Hat, o.HatColor or o.Shirt, headCf)
	-- ของประกอบ
	local e = o.Extra
	if e == "Scarf" then
		part(m, { Size = V(2.1, 0.45, 1.15), CFrame = root * CF(0, 3.85, 0), Color = o.Accent, Material = Enum.Material.Fabric })
		part(m, { Size = V(0.5, 1.1, 0.2), CFrame = root * CF(0.5, 3.2, -0.6), Color = o.Accent, Material = Enum.Material.Fabric })
	elseif e == "Beard" then
		part(m, { Size = V(1.4, 0.8, 0.4), CFrame = headCf * CF(0, -0.45, -0.5), Color = o.Accent })
	elseif e == "Cross" then
		part(m, { Size = V(0.9, 0.28, 0.06), CFrame = torso.CFrame * CF(0, 0.3, -0.52), Color = o.Accent })
		part(m, { Size = V(0.28, 0.9, 0.06), CFrame = torso.CFrame * CF(0, 0.3, -0.52), Color = o.Accent })
	elseif e == "Quiver" then
		part(m, { Size = V(0.6, 2, 0.6), CFrame = torso.CFrame * CF(0.4, 0.3, 0.75) * ANG(0, 0, 0.35), Color = o.Accent })
		for i = -1, 1 do
			part(m, { Size = V(0.1, 0.6, 0.1), CFrame = torso.CFrame * CF(0.75 + i * 0.12, 1.5, 0.75) * ANG(0, 0, 0.35), Color = C(230, 230, 230) })
		end
		part(m, { Size = V(2.05, 0.2, 1.05), CFrame = torso.CFrame * ANG(0, 0, -0.7), Color = o.Accent })
	elseif e == "Belt" then
		part(m, { Size = V(2.05, 0.4, 1.05), CFrame = torso.CFrame * CF(0, -0.8, 0), Color = o.Accent })
		part(m, { Size = V(0.3, 0.9, 0.3), CFrame = torso.CFrame * CF(0.7, -1.1, -0.55), Color = C(150, 150, 156), Material = Enum.Material.Metal })
		part(m, { Size = V(2.05, 1.4, 1.05), CFrame = torso.CFrame * CF(0, 0.2, 0), Color = C(250, 220, 60), Transparency = 0.6 })
	elseif e == "Bag" then
		part(m, { Size = V(1.6, 1.6, 0.8), CFrame = torso.CFrame * CF(0, 0, 0.9), Color = o.Accent, Material = Enum.Material.Fabric })
		part(m, { Size = V(2.05, 0.2, 1.05), CFrame = torso.CFrame * ANG(0, 0, 0.7), Color = C(80, 60, 40) })
	elseif e == "Basket" then
		part(m, { Size = V(1.2, 0.8, 1), CFrame = root * CF(-1.6, 2, -0.4), Color = C(170, 120, 60), Material = Enum.Material.Fabric })
		part(m, { Shape = Enum.PartType.Ball, Size = V(0.5, 0.5, 0.5), CFrame = root * CF(-1.5, 2.5, -0.5), Color = o.Accent })
	elseif e == "Ember" then
		local fire = part(m, { Shape = Enum.PartType.Ball, Size = V(0.7, 0.7, 0.7), CFrame = root * CF(1.5, 1.7, -0.6), Color = o.Accent, Material = Enum.Material.Neon })
		local l = Instance.new("PointLight")
		l.Color = o.Accent
		l.Range = 8
		l.Brightness = 2
		l.Parent = fire
		part(m, { Size = V(2.05, 0.3, 1.05), CFrame = torso.CFrame * CF(0, -0.85, 0), Color = o.Accent, Material = Enum.Material.Neon })
	elseif e == "Orbs" then
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2
			local cols = { C(120, 230, 255), C(255, 120, 40), C(130, 240, 100) }
			part(m, { Shape = Enum.PartType.Ball, Size = V(0.55, 0.55, 0.55), CFrame = root * CF(math.cos(a) * 2.2, 3.4 + i * 0.3, math.sin(a) * 1.4), Color = cols[i + 1], Material = Enum.Material.Neon })
		end
		part(m, { Size = V(2.1, 2.6, 1.1), CFrame = root * CF(0, 1.9, 0.02), Color = o.Shirt, Material = Enum.Material.Fabric })
	elseif e == "Fur" then
		part(m, { Size = V(2.6, 0.7, 1.4), CFrame = root * CF(0, 3.85, 0), Color = o.Accent, Material = Enum.Material.Fabric })
	end
	torso.PivotOffset = CF(0, -3, 0) -- จุดหมุนอยู่ที่เท้า
	m.PrimaryPart = torso
	return m
end

-- ใส่หุ่นใน ViewportFrame แบบรูปครึ่งตัว (portrait) หรือเต็มตัว
function ClassAvatars.Viewport(frame, classId, portrait, waitSec)
	local model = ClassAvatars.Build(classId, waitSec)
	if not frame.Parent then
		return nil
	end
	frame:ClearAllChildren()
	local world = Instance.new("WorldModel")
	world.Parent = frame
	model.Parent = world
	model:PivotTo(CF(0, 0, 0) * ANG(0, math.pi + 0.35, 0))
	local cam = Instance.new("Camera")
	cam.FieldOfView = portrait and 28 or 35
	if portrait then
		cam.CFrame = CFrame.lookAt(V(0.9, 5.0, 8.6), V(0, 4.25, 0))
	else
		cam.CFrame = CFrame.lookAt(V(1.5, 3.6, 13), V(0, 2.9, 0))
	end
	cam.Parent = frame
	frame.CurrentCamera = cam
	frame.Ambient = C(215, 210, 205)
	frame.LightColor = C(255, 250, 240)
	frame.LightDirection = V(-0.4, -1, -0.6)
	return model
end

return ClassAvatars
