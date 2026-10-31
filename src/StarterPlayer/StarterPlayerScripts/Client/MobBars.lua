--[[
	MobBars — หลอดเลือดลอยบนหัวสัตว์/มอนทุกตัว (แบบเกมเอาชีวิตรอดทั่วไป)
	  ชื่อสัตว์ (ไทย) + หลอดเลือด + ตัวเลข · โดนตีแล้วหลอดหดทันที มีแถบขาวหดตามช้าๆ
	  สีชื่อ: สัตว์ไม่ดุ = ขาว · สัตว์ดุ = แดงอ่อน · บอส/ผู้พิทักษ์ = ทอง
	อ่านจากแท็ก "Animal" + attribute Health / MaxHealth / AnimalId ที่ AnimalService ตั้งไว้ (สัตว์โชว์ในล็อบบี้ไม่มี MaxHealth = ไม่มีหลอด)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Animals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Animals"))

local MobBars = {}
local bars = {} -- [model] = { Gui, Fill, Lag, Num, Conns }
local holder

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = o
end

local function remove(model)
	local b = bars[model]
	if not b then
		return
	end
	bars[model] = nil
	for _, c in ipairs(b.Conns) do
		c:Disconnect()
	end
	b.Gui:Destroy()
end

local function update(model, instant)
	local b = bars[model]
	if not b then
		return
	end
	local maxHp = model:GetAttribute("MaxHealth") or 1
	local hp = math.max(model:GetAttribute("Health") or maxHp, 0)
	local frac = math.clamp(hp / math.max(maxHp, 1), 0, 1)
	b.Gui.Enabled = hp > 0
	b.Num.Text = maxHp >= 1e8 and "∞" or string.format("%d / %d", math.ceil(hp), math.ceil(maxHp))
	-- เขียว -> เหลือง -> แดง ตามเลือดที่เหลือ
	b.Fill.BackgroundColor3 = frac > 0.5 and rgb(90, 220, 90):Lerp(rgb(240, 210, 60), (1 - frac) * 2) or rgb(240, 210, 60):Lerp(rgb(230, 50, 50), (0.5 - frac) * 2)
	if instant then
		b.Fill.Size = UDim2.fromScale(frac, 1)
		b.Lag.Size = UDim2.fromScale(frac, 1)
		return
	end
	TweenService:Create(b.Fill, TweenInfo.new(0.12), { Size = UDim2.fromScale(frac, 1) }):Play()
	if frac < b.Lag.Size.X.Scale then
		TweenService:Create(b.Lag, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.3), { Size = UDim2.fromScale(frac, 1) }):Play()
	else
		b.Lag.Size = UDim2.fromScale(frac, 1)
	end
end

local function add(model)
	if bars[model] or not model:IsA("Model") or model:GetAttribute("MaxHealth") == nil then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
	if not root then
		return
	end
	local info = Animals.Data[model:GetAttribute("AnimalId") or ""]
	if info and info.Behaviour == "Spirit" then
		return -- ลูกสัตว์วิญญาณ (ฝ่ายเรา ตายไม่ได้) ไม่ต้องมีหลอด
	end
	local boss = model:GetAttribute("IsBoss") == true or model:GetAttribute("Kind") == "Guardian"
	-- ตายไม่ได้ (เช่น กวางกลวง): โชว์แค่ชื่อ + คำเตือน ไม่มีหลอด
	local immortal = (model:GetAttribute("MaxHealth") or 0) >= 1e8
	-- ความสูงหัว: วัดจากกล่องรอบตัวเทียบจุดกึ่งกลาง root
	local cf, size = model:GetBoundingBox()
	local top = (cf.Position.Y + size.Y / 2) - root.Position.Y
	local w = boss and 190 or 120

	local gui = Instance.new("BillboardGui")
	gui.Name = "MobBar"
	gui.Adornee = root
	gui.Size = UDim2.fromOffset(w, boss and 44 or 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top + (boss and 3 or 1.6), 0)
	gui.MaxDistance = boss and 260 or 110
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = holder

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.5, 0)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.Text = info and (info.Thai or info.Name) or (model:GetAttribute("AnimalId") or model.Name)
	name.TextColor3 = boss and rgb(255, 214, 90) or ((info and info.Behaviour == "Passive") and rgb(255, 255, 255) or rgb(255, 150, 140))
	name.TextStrokeTransparency = 0.3
	name.Parent = gui
	local nc = Instance.new("UITextSizeConstraint")
	nc.MaxTextSize = boss and 18 or 14
	nc.Parent = name

	local back = Instance.new("Frame")
	back.BorderSizePixel = 0
	back.BackgroundColor3 = rgb(20, 14, 12)
	back.Position = UDim2.fromScale(0, 0.52)
	back.Size = UDim2.fromScale(1, 0.44)
	back.ClipsDescendants = true
	back.Parent = gui
	corner(back, 4)
	local st = Instance.new("UIStroke")
	st.Color = rgb(0, 0, 0)
	st.Thickness = 1.5
	st.Parent = back
	local lag = Instance.new("Frame")
	lag.BorderSizePixel = 0
	lag.BackgroundColor3 = rgb(255, 240, 220)
	lag.BackgroundTransparency = 0.2
	lag.Size = UDim2.fromScale(1, 1)
	lag.Parent = back
	corner(lag, 4)
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	corner(fill, 4)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(rgb(255, 255, 255), rgb(170, 170, 170))
	g.Rotation = 90
	g.Parent = fill
	local num = Instance.new("TextLabel")
	num.BackgroundTransparency = 1
	num.Size = UDim2.fromScale(1, 1)
	num.Font = Enum.Font.GothamBlack
	num.TextScaled = true
	num.TextColor3 = rgb(255, 255, 255)
	num.TextStrokeTransparency = 0.2
	num.ZIndex = 3
	num.Parent = back
	local tc = Instance.new("UITextSizeConstraint")
	tc.MaxTextSize = boss and 14 or 11
	tc.Parent = num

	if immortal then
		back.Visible = false
		local warnL = Instance.new("TextLabel")
		warnL.BackgroundTransparency = 1
		warnL.Position = UDim2.fromScale(0, 0.5)
		warnL.Size = UDim2.fromScale(1, 0.45)
		warnL.Font = Enum.Font.GothamBold
		warnL.TextScaled = true
		warnL.Text = "ฆ่าไม่ได้ — หนี!"
		warnL.TextColor3 = rgb(255, 120, 110)
		warnL.TextStrokeTransparency = 0.3
		warnL.Parent = gui
	end

	local b = { Gui = gui, Fill = fill, Lag = lag, Num = num, Conns = {} }
	bars[model] = b
	table.insert(b.Conns, model:GetAttributeChangedSignal("Health"):Connect(function()
		update(model)
	end))
	table.insert(b.Conns, model:GetAttributeChangedSignal("MaxHealth"):Connect(function()
		update(model, true)
	end))
	table.insert(b.Conns, model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			remove(model)
		end
	end))
	update(model, true)
end

function MobBars.Init()
	holder = Instance.new("Folder")
	holder.Name = "MobBars"
	holder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, m in ipairs(CollectionService:GetTagged("Animal")) do
		task.spawn(add, m)
	end
	CollectionService:GetInstanceAddedSignal("Animal"):Connect(function(m)
		-- รอให้ attribute/ชิ้นส่วนมาครบก่อน (สตรีมเข้ามาทีหลังได้)
		task.delay(0.2, add, m)
	end)
	CollectionService:GetInstanceRemovedSignal("Animal"):Connect(remove)
end

return MobBars
