--[[
	ItemModels — โมเดลไอเทมจาก Creator Store (ReplicatedStorage.Assets.Items.<ItemId>)
	ItemModels.Has(id)
	ItemModels.Clone(id, size, opts) -> Model (ด้านยาวสุด = size stud) · opts.Ground = จุดหมุนที่พื้นตรงกลาง (ไม่งั้นกึ่งกลางกล่อง) · opts.Yaw = หมุน (องศา)
	คืนค่า model, ขนาดกล่องหลังย่อขยาย
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(script.Parent.Items)

local ItemModels = {}

-- Items.Data[id].Model = ใช้โมเดลของไอเทมอื่น (เช่น หัวใจอสูร 4 ธาตุใช้โมเดล BeastHeart แล้วย้อมสี)
local function source(id)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Items")
	local d = Items.Data[id]
	return folder and (folder:FindFirstChild(id) or (d and d.Model and folder:FindFirstChild(d.Model)))
end

-- ย้อมสีโมเดล (Items.Data[id].Tint): ถอดเท็กซ์เจอร์เดิม (สีแดงทับสีใหม่หมด) แล้วใช้สีชิ้นแทน
function ItemModels.Tint(m, id)
	local d = Items.Data[id]
	local c = d and d.Tint
	if not c then
		return
	end
	for _, x in ipairs(m:GetDescendants()) do
		if x:IsA("SpecialMesh") then
			x.TextureId = ""
			x.VertexColor = Vector3.one
		elseif x:IsA("BasePart") then
			x.Material = Enum.Material.SmoothPlastic
			x.Color = c
			if x:IsA("MeshPart") then
				x.TextureID = ""
			end
		end
	end
end

function ItemModels.Has(id)
	return source(id) ~= nil
end

function ItemModels.Clone(id, size, opts)
	opts = opts or {}
	local src = source(id)
	if not src then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = id
	for _, c in ipairs(src:GetChildren()) do
		c:Clone().Parent = m
	end
	ItemModels.Tint(m, id)
	-- ตัดของที่ไม่ใช่หน้าตา (สคริปต์/เสียง/GUI ที่ติดมากับโมเดล)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("GuiBase") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then
			d:Destroy()
		end
	end
	if opts.Yaw then
		-- หมุนรอบแกนตั้งก่อนจัดตำแหน่ง (ให้ด้านหน้าของโมเดลตรงกับทิศที่เกมใช้)
		local r = CFrame.Angles(0, math.rad(opts.Yaw), 0)
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CFrame = r * p.CFrame
			end
		end
	end
	local _, box = m:GetBoundingBox()
	local k = size / math.max(box.X, box.Y, box.Z, 0.01)
	pcall(function()
		m:ScaleTo(k)
	end)
	-- จัดตำแหน่ง: กล่องรวมอยู่กลางจุดกำเนิด (หรือฐานกล่องอยู่ที่พื้น)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			local h = p.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local c = p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
						lo, hi = lo:Min(c), hi:Max(c)
					end
				end
			end
		end
	end
	local mid = (lo + hi) / 2
	local target = opts.Ground and Vector3.new(mid.X, lo.Y, mid.Z) or mid
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CFrame = p.CFrame - target
		end
	end
	m.WorldPivot = CFrame.new()
	return m, hi - lo
end

return ItemModels
