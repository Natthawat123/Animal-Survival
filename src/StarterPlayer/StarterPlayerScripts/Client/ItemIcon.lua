--[[
	ItemIcon — รูปไอเทมจากโมเดลจริง (Assets.Items / Assets.Weapons) ใน ViewportFrame
	Make(parent, id, props) -> ViewportFrame (ไม่มีโมเดล = ไอคอนตัวหนังสือตามหมวด)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))

local ItemIcon = {}

local GLYPH = { Resource = "🪵", Food = "🍖", Essence = "✦", Relic = "❤", Medical = "✚", Tool = "⚒", Structure = "🏠" }
local cache = {}

-- โมเดลต้นแบบ (ทำครั้งเดียวต่อไอเทม): ตัดสคริปต์/แสง/อนุภาค ตรึงทุกชิ้น
local function template(id)
	if cache[id] ~= nil then
		return cache[id] or nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local src
	for _, folder in ipairs({ "Items", "Weapons" }) do
		local f = assets and assets:FindFirstChild(folder)
		src = src or (f and f:FindFirstChild(id))
	end
	local m
	if src then
		m = Instance.new("Model")
		m.Name = id
		local c = src:Clone()
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Sound") or d:IsA("Trail") or d:IsA("Beam") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		if c:IsA("BasePart") then
			c.Anchored = true
		end
		c.Parent = m
	end
	cache[id] = m or false
	return m
end

function ItemIcon.Make(parent, id, props)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromOffset(40, 40)
	for k, v in pairs(props or {}) do
		vp[k] = v
	end
	local t = template(id)
	if t then
		local m = t:Clone()
		m.Parent = vp
		local cf, size = m:GetBoundingBox()
		local r = math.max(size.Magnitude / 2, 0.1)
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		local dist = r / math.tan(math.rad(15)) * 1.02
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0.75, 0.55, -1).Unit * dist, cf.Position)
		cam.Parent = vp
		vp.CurrentCamera = cam
		vp.Ambient = Color3.fromRGB(205, 200, 195)
		vp.LightColor = Color3.fromRGB(255, 250, 240)
		vp.LightDirection = Vector3.new(-0.5, -1, 0.4)
	else
		local info = Items.Data[id]
		local t2 = Instance.new("TextLabel")
		t2.Size = UDim2.fromScale(1, 1)
		t2.BackgroundTransparency = 1
		t2.TextScaled = true
		t2.Text = GLYPH[info and info.Category or ""] or "•"
		t2.TextColor3 = info and info.Color or Color3.new(1, 1, 1)
		t2.Parent = vp
	end
	vp.Parent = parent
	return vp
end

return ItemIcon
