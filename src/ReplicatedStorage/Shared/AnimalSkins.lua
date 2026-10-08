--[[
	AnimalSkins — "สวมผิว" สัตว์ด้วยโมเดลจริงจาก Blender (ReplicatedStorage.AnimalMeshData) ผ่าน EditableMesh
	ไม่ต้อง import / upload: ข้อมูลเมชอยู่ในเกม แล้วประกอบเป็น MeshPart บนเครื่องผู้เล่น

	- server สร้างโครงกระดูก (ชิ้นละ 1 Part ขนาด/ตำแหน่งตรงกับชิ้นเมช) ใน AnimalModels.BuildFromMesh
	- client เรียก AnimalSkins.Skin(model): สร้าง MeshPart ทับแต่ละชิ้น + เชื่อมติด แล้วซ่อน Part เดิม
	- ถ้าสร้าง EditableMesh ไม่ได้ (เกม publish แล้วไม่ได้เปิด Mesh/Image APIs) จะเห็นโครงแบบก้อนสีแทน

	รูปแบบข้อมูลเหมือน CharacterMeshes (Anime Run): mesh = u16 nV,nUV,nN,nF | i16x3 | u16x2 | i8x3 | u16x9
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetService = game:GetService("AssetService")

local AnimalSkins = {}

-- ชุดข้อมูล: AnimalMeshData (สัตว์) / PropMeshData (ไอเทม ต้นไม้ หิน ของในแคมป์)
local meshes = {} -- ["Set/Id/Part"] = EditableMesh | false
local templates = {} -- ["Set/Id/Part"] = MeshPart ต้นแบบ (โคลนใช้ซ้ำ)
local palettes = {} -- ["Set/Id"] = EditableImage | false
local decoded = {} -- ["Set/Id"] = data table
AnimalSkins.Disabled = false
AnimalSkins.Built = 0

local function folder(set)
	return ReplicatedStorage:FindFirstChild(set or "AnimalMeshData")
end

function AnimalSkins.Has(id, set)
	local f = folder(set)
	return f ~= nil and f:FindFirstChild(id) ~= nil
end

function AnimalSkins.Data(id, set)
	set = set or "AnimalMeshData"
	local key = set .. "/" .. id
	if decoded[key] == nil then
		local f = folder(set)
		local mod = f and f:FindFirstChild(id)
		decoded[key] = mod and require(mod) or false
	end
	return decoded[key] or nil
end

---------------------------------------------------------------- base64
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64L = {}
for i = 1, 64 do
	B64L[string.byte(B64, i)] = i - 1
end

local function b64decode(s)
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

local function decodeImage(str)
	local src = b64decode(str)
	local w, h = buffer.readu16(src, 0), buffer.readu16(src, 2)
	local out = buffer.create(w * h * 4)
	local off, o = 4, 0
	local len = buffer.len(src)
	while off < len do
		local count = buffer.readu16(src, off)
		local r, g, b = buffer.readu8(src, off + 2), buffer.readu8(src, off + 3), buffer.readu8(src, off + 4)
		for _ = 1, count do
			buffer.writeu8(out, o, r)
			buffer.writeu8(out, o + 1, g)
			buffer.writeu8(out, o + 2, b)
			buffer.writeu8(out, o + 3, 255)
			o += 4
		end
		off += 5
	end
	local img = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
	if not img then
		error("memory budget (image)")
	end
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), out)
	return img
end

local function decodeMesh(str)
	local buf = b64decode(str)
	local nv, nuv, nn, nf = buffer.readu16(buf, 0), buffer.readu16(buf, 2), buffer.readu16(buf, 4), buffer.readu16(buf, 6)
	local off = 8
	local em = AssetService:CreateEditableMesh()
	if not em then
		error("memory budget (mesh)")
	end
	local vids, uvids, nids = table.create(nv), table.create(nuv), table.create(nn)
	for i = 1, nv do
		vids[i] = em:AddVertex(Vector3.new(buffer.readi16(buf, off) / 1000, buffer.readi16(buf, off + 2) / 1000, buffer.readi16(buf, off + 4) / 1000))
		off += 6
	end
	for i = 1, nuv do
		uvids[i] = em:AddUV(Vector2.new(buffer.readu16(buf, off) / 65535, buffer.readu16(buf, off + 2) / 65535))
		off += 4
	end
	for i = 1, nn do
		local v = Vector3.new(buffer.readi8(buf, off), buffer.readi8(buf, off + 1), buffer.readi8(buf, off + 2))
		nids[i] = em:AddNormal(v.Magnitude > 0 and v.Unit or Vector3.yAxis)
		off += 3
	end
	for _ = 1, nf do
		local fid = em:AddTriangle(vids[buffer.readu16(buf, off) + 1], vids[buffer.readu16(buf, off + 2) + 1], vids[buffer.readu16(buf, off + 4) + 1])
		em:SetFaceUVs(fid, { uvids[buffer.readu16(buf, off + 6) + 1], uvids[buffer.readu16(buf, off + 8) + 1], uvids[buffer.readu16(buf, off + 10) + 1] })
		em:SetFaceNormals(fid, { nids[buffer.readu16(buf, off + 12) + 1], nids[buffer.readu16(buf, off + 14) + 1], nids[buffer.readu16(buf, off + 16) + 1] })
		off += 18
	end
	-- แปลงเป็น FixedSize (ใช้หน่วยความจำเท่าที่ใช้จริง)
	local ok, fixed = pcall(function()
		return AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
	end)
	if ok and fixed then
		em:Destroy()
		return fixed
	end
	return em
end

local function getMesh(set, id, part)
	local key = set .. "/" .. id .. "/" .. part.Name
	if meshes[key] == nil then
		local ok, em = pcall(decodeMesh, part.Mesh)
		meshes[key] = ok and em or false
		if not ok then
			warn("[AnimalSkins] mesh", key, em)
			AnimalSkins.Disabled = true
		end
		AnimalSkins.Built += 1
	end
	return meshes[key] or nil
end

local function getPalette(set, id, data)
	local key = set .. "/" .. id
	if palettes[key] == nil then
		local ok, img = pcall(decodeImage, data.Palette)
		palettes[key] = ok and img or false
	end
	return palettes[key] or nil
end

-- สร้าง MeshPart ของชิ้นหนึ่ง (วางที่ cf) — สร้างต้นแบบครั้งเดียวแล้วโคลน
function AnimalSkins.MakePart(id, partData, cf, set)
	set = set or "AnimalMeshData"
	local tkey = set .. "/" .. id .. "/" .. partData.Name
	local tpl = templates[tkey]
	if tpl then
		local c = tpl:Clone()
		c.CFrame = cf
		return c
	end
	local data = AnimalSkins.Data(id, set)
	local em = getMesh(set, id, partData)
	if not em then
		return nil
	end
	local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
	mp.Name = "Skin_" .. partData.Name
	if partData.Glow then
		mp.Material = Enum.Material.Neon
		mp.Color = Color3.new(partData.Glow[1], partData.Glow[2], partData.Glow[3])
	else
		local tex = getPalette(set, id, data)
		if tex then
			mp.TextureContent = Content.fromObject(tex)
		end
		mp.Material = Enum.Material.SmoothPlastic
	end
	mp.Anchored = false
	mp.Massless = true
	mp.CanCollide = false
	mp.CanTouch = false
	mp.CanQuery = false
	mp.CastShadow = true
	local s = partData.Size
	mp.Size = Vector3.new(s[1], s[2], s[3])
	templates[tkey] = mp:Clone()
	mp.CFrame = cf
	return mp
end

-- สวมผิว: model/tool ที่มีชิ้น attribute SkinPart (ชื่อชิ้นข้อมูล = attribute SkinName หรือชื่อ Part)
-- ชุดข้อมูล/ไอดี: attribute SkinSet (ค่าเริ่ม AnimalMeshData) + SkinId (ค่าเริ่ม AnimalId)
function AnimalSkins.Skin(model)
	if AnimalSkins.Disabled or model:GetAttribute("Skinned") then
		return false
	end
	local set = model:GetAttribute("SkinSet") or "AnimalMeshData"
	local id = model:GetAttribute("SkinId") or model:GetAttribute("AnimalId")
	local data = id and AnimalSkins.Data(id, set)
	if not data then
		return false
	end
	model:SetAttribute("Skinned", true)
	local byName = {}
	for _, p in ipairs(data.Parts) do
		byName[p.Name] = p
	end
	local made = 0
	for _, rigPart in ipairs(model:GetDescendants()) do
		if rigPart:IsA("BasePart") and rigPart:GetAttribute("SkinPart") then
			local pd = byName[rigPart:GetAttribute("SkinName") or rigPart.Name]
			if pd then
				local ok, mp = pcall(AnimalSkins.MakePart, id, pd, rigPart.CFrame, set)
				if ok and mp then
					mp.Size = rigPart.Size -- โมเดลถูกย่อ/ขยาย (ScaleTo) -> ผิวตามขนาดจริง
					mp.CFrame = rigPart.CFrame
					mp.Anchored = false
					local w = Instance.new("WeldConstraint")
					w.Part0 = rigPart
					w.Part1 = mp
					w.Parent = mp
					mp.Parent = rigPart
					rigPart.LocalTransparencyModifier = 1
					for _, d in ipairs(rigPart:GetChildren()) do
						if d:IsA("SpecialMesh") then
							d.Scale = Vector3.zero
						end
					end
					-- server ซ่อนชิ้น (ต้นไม้ถูกโค่น/หินแตก) -> ซ่อนผิวตาม
					local function sync()
						mp.Transparency = (rigPart.Transparency > 0.98) and 1 or 0
					end
					sync()
					rigPart:GetPropertyChangedSignal("Transparency"):Connect(sync)
					made += 1
				end
			end
		end
	end
	return made > 0
end

return AnimalSkins
