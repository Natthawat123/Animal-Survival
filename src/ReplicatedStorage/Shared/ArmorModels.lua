--[[
	ArmorModels — สวมเกราะให้ตัวละคร (โมเดลจาก Creator Store: ReplicatedStorage.Assets.Armor/<ItemId> · tools/import_armor.py)
	  Attach(char, id) -> ย่อ/ขยายให้พอดีลำตัว (R15 = UpperTorso+LowerTorso / R6 = Torso) แล้วเชื่อมติดลำตัว
	  Remove(char)     -> ถอดเกราะออก
	รองรับทุกขนาดตัว (ตัวเล็ก/ใหญ่/หนา/ผอม/Rthro): วัดลำตัวจริงทั้ง 3 แกน + คอยดูลำตัวเปลี่ยนขนาด/ชิ้นลำตัวถูกเปลี่ยน
	  (avatar โหลดทีหลัง, ปรับสเกลตัว) -> ใส่เกราะใหม่ให้พอดีเอง
	FIT[id]: Ref = ขนาดโมเดล (ส่วนที่มองเห็น) ที่สเกล 1 · Cover = ขนาดเกราะเทียบลำตัว (เท่า) ต่อแกน X/Y/Z
	         สเกล = ค่ามากสุดของ (ลำตัว × Cover ÷ Ref) ทุกแกน -> ลำตัวไม่ทะลุเกราะไม่ว่าตัวทรงไหน
	         Y = เลื่อนขึ้น/ลงเป็นสัดส่วนความสูงลำตัว · Yaw = หมุนให้ด้านหน้าหัน -Z (หน้าตัวละคร)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorModels = {}

-- เกราะ = เสื้อเลเยอร์ (Layered Clothing · Jacket) จากแคตตาล็อก Roblox -> ยืด/หดตามตัวละครเองทุกขนาด/ทรง (R15)
--   ใส่ทับเสื้อผ้าเดิมของผู้เล่น (Order สูง = ชั้นนอกสุด) ผ่าน HumanoidDescription · R6 ใส่เสื้อเลเยอร์ไม่ได้ -> โมเดลแข็งแบบเดิม (FIT)
local LAYERED = {
	WoodArmor = 122923529802096, -- Medieval Brigandine Breastplate | Bronze
	IronArmor = 72463955485725, -- Medieval Gilded Churburg Breastplate
	GoldArmor = 73779488166589, -- Chestplate of the Heroic Knight | Gold White
}
ArmorModels.LAYERED = LAYERED
local LAYER_ORDER = 20
local isArmorAsset = {}
for _, aid in pairs(LAYERED) do
	isArmorAsset[aid] = true
end

local FIT = {
	-- เสื้อเกราะไม้ (ทำไว้ใส่ลำตัว R6 กว้าง 2 → ชิ้น 2.1)
	WoodArmor = { Ref = Vector3.new(2.1, 2.1, 1.1), Cover = Vector3.new(1.12, 1.17, 1.23), Y = 0, Yaw = 0 },
	-- เกราะเหล็กมีบ่า (สูง 0.8 ที่สเกล 1) → สูงเท่าลำตัว บ่าคลุมหัวไหล่
	IronArmor = { Ref = Vector3.new(1.134, 0.8, 0.532), Cover = Vector3.new(1.59, 1.12, 1.49), Y = 0.02, Yaw = 0 },
	-- เกราะทองลายสลัก (ทำไว้ใส่ลำตัวสเกล 2 = 4 กว้าง)
	GoldArmor = { Ref = Vector3.new(4, 4, 2), Cover = Vector3.new(1.12, 1.12, 1.12), Y = 0, Yaw = 0 },
}
ArmorModels.FIT = FIT

-- กล่องลำตัว: ศูนย์กลาง (CFrame) + ขนาด + ชิ้นที่จะเชื่อม
local function torsoBox(char)
	local upper = char:FindFirstChild("UpperTorso")
	local lower = char:FindFirstChild("LowerTorso")
	if upper and upper:IsA("BasePart") then
		local top = upper.CFrame * CFrame.new(0, upper.Size.Y / 2, 0)
		-- ขอบล่าง (ในแกนของ UpperTorso) = ล่างสุดของ LowerTorso
		local bottomY = -upper.Size.Y / 2
		if lower and lower:IsA("BasePart") then
			bottomY = math.min(bottomY, upper.CFrame:PointToObjectSpace(lower.Position).Y - lower.Size.Y / 2)
		end
		-- ความสูงรวมบนถึงล่าง (ในแกนของ UpperTorso)
		local h = upper.Size.Y / 2 - bottomY
		local center = top * CFrame.new(0, -h / 2, 0)
		return center, Vector3.new(upper.Size.X, h, upper.Size.Z), upper
	end
	local torso = char:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso.CFrame, torso.Size, torso
	end
	return nil
end

-- เสื้อผ้า/ของประดับที่ลำตัว (เสื้อแจ็กเก็ตแบบเลเยอร์ ฯลฯ) ใหญ่กว่าลำตัว -> บังเกราะมิด: ซ่อนไว้ระหว่างสวมเกราะ
--   (ผม/หมวก/ของที่หลัง ไม่ซ่อน) · ถอดเกราะ = คืนความโปร่งใสเดิม
local KEEP_TYPES = { Hat = true, Hair = true, Face = true, Neck = true, Back = true, Eyebrow = true, Eyelash = true }
local CLOTH_TYPES = { Shirt = true, TShirt = true, Jacket = true, Sweater = true, DressSkirt = true }
local function torsoAccessories(char)
	local out = {}
	for _, acc in ipairs(char:GetChildren()) do
		if acc:IsA("Accessory") then
			local handle = acc:FindFirstChild("Handle")
			local okType, t = pcall(function()
				return acc.AccessoryType.Name
			end)
			t = okType and t or ""
			local weld = handle and handle:FindFirstChildWhichIsA("Weld")
			local onTorso = weld and weld.Part1 and (weld.Part1.Name == "UpperTorso" or weld.Part1.Name == "Torso" or weld.Part1.Name == "LowerTorso")
			if handle and handle:IsA("BasePart") and (CLOTH_TYPES[t] or (onTorso and not KEEP_TYPES[t])) then
				table.insert(out, handle)
			end
		end
	end
	return out
end

local function hideClothes(char, hide)
	for _, h in ipairs(torsoAccessories(char)) do
		if hide then
			if h:GetAttribute("ArmorOrigT") == nil then
				h:SetAttribute("ArmorOrigT", h.Transparency)
			end
			h.Transparency = 1
		elseif h:GetAttribute("ArmorOrigT") ~= nil then
			h.Transparency = h:GetAttribute("ArmorOrigT")
			h:SetAttribute("ArmorOrigT", nil)
		end
	end
end

-- ตัวคอยดูลำตัว: [char] = { connections }
local watching = {}
local function unwatch(char)
	for _, c in ipairs(watching[char] or {}) do
		c:Disconnect()
	end
	watching[char] = nil
end

local build

-- ใส่/ถอดเสื้อเลเยอร์ (aid = nil ถอด) · ทำทีละคำสั่งต่อตัว (ApplyDescription รอโหลด)
local applying = setmetatable({}, { __mode = "k" })
local function applyLayered(hum, aid)
	applying[hum] = { Aid = aid }
	local job = applying[hum]
	task.spawn(function()
		local ok, err = pcall(function()
			local desc = hum:GetAppliedDescription()
			local list = {}
			for _, a in ipairs(desc:GetAccessories(true)) do
				if not isArmorAsset[a.AssetId] then
					table.insert(list, a)
				end
			end
			if aid then
				table.insert(list, { AssetId = aid, AccessoryType = Enum.AccessoryType.Jacket, IsLayered = true, Order = LAYER_ORDER })
			end
			desc:SetAccessories(list, true)
			if applying[hum] == job then
				hum:ApplyDescription(desc)
			end
		end)
		if not ok then
			warn("[ArmorModels] ใส่เสื้อเกราะไม่สำเร็จ: " .. tostring(err))
		end
	end)
end

local function layeredHum(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum and hum.RigType == Enum.HumanoidRigType.R15 and hum or nil
end

function ArmorModels.Remove(char)
	if not char then
		return
	end
	local hum = layeredHum(char)
	if hum and char:GetAttribute("ArmorLayered") then
		char:SetAttribute("ArmorLayered", nil)
		applyLayered(hum, nil)
	end
	unwatch(char)
	local old = char:FindFirstChild("ArmorVisual")
	if old then
		old:Destroy()
	end
	hideClothes(char, false)
end

-- ลำตัวเปลี่ยนขนาด / ชิ้นลำตัวหรือเสื้อผ้าถูกใส่ใหม่ -> ใส่เกราะใหม่ให้พอดี (รวบหลายครั้งเป็นครั้งเดียว)
local function watch(char, id)
	unwatch(char)
	local conns = {}
	watching[char] = conns
	local pending = false
	local function refit()
		if pending then
			return
		end
		pending = true
		task.delay(0.3, function()
			pending = false
			if watching[char] == conns and char.Parent then
				build(char, id)
				watch(char, id)
			end
		end)
	end
	for _, name in ipairs({ "UpperTorso", "LowerTorso", "Torso" }) do
		local p = char:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			table.insert(conns, p:GetPropertyChangedSignal("Size"):Connect(refit))
		end
	end
	table.insert(conns, char.ChildAdded:Connect(function(c)
		if c:IsA("Accessory") or (c:IsA("BasePart") and (c.Name == "UpperTorso" or c.Name == "LowerTorso" or c.Name == "Torso")) then
			refit()
		end
	end))
	table.insert(conns, char.AncestryChanged:Connect(function(_, parent)
		if not parent then
			unwatch(char)
		end
	end))
end

function ArmorModels.Attach(char, id)
	local hum = layeredHum(char)
	if hum and LAYERED[id] then
		-- เสื้อเลเยอร์: ไม่ต้องย่อ/ขยาย/ซ่อนเสื้อผ้า (Roblox จัดชั้นและขนาดให้เอง)
		local old = char:FindFirstChild("ArmorVisual")
		if old then
			old:Destroy()
		end
		unwatch(char)
		hideClothes(char, false)
		char:SetAttribute("ArmorLayered", id)
		applyLayered(hum, LAYERED[id])
		return true
	end
	local m = build(char, id)
	if m then
		watch(char, id)
	end
	return m
end

function build(char, id)
	local old = char and char:FindFirstChild("ArmorVisual")
	if old then
		old:Destroy()
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Armor")
	local src = folder and folder:FindFirstChild(id)
	local fit = FIT[id]
	if not (src and fit and char) then
		return nil
	end
	local center, size, weldTo = torsoBox(char)
	if not center then
		return nil
	end
	local m = src:Clone()
	m.Name = "ArmorVisual"
	m:SetAttribute("ArmorId", id)
	local parts = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.CastShadow = true
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		m:Destroy()
		return nil
	end
	-- ย่อ/ขยายให้พอดีลำตัว
	-- ตัวหนา = ขยายตามความหนา ไม่ให้ลำตัวทะลุเกราะ
	local k = math.max(size.X * fit.Cover.X / fit.Ref.X, size.Y * fit.Cover.Y / fit.Ref.Y, size.Z * fit.Cover.Z / fit.Ref.Z)
	if k > 0 and math.abs(k - 1) > 0.001 then
		m:ScaleTo(m:GetScale() * k)
	end
	-- วางกลางกล่องโมเดลให้ตรงกลางลำตัว (หันหน้าตามตัวละคร)
	local bcf = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(bcf.Position)
	m:PivotTo(center * CFrame.new(0, (fit.Y or 0) * size.Y, 0) * CFrame.Angles(0, math.rad(fit.Yaw or 0), 0))
	for _, p in ipairs(parts) do
		local w = Instance.new("WeldConstraint")
		w.Part0 = weldTo
		w.Part1 = p
		w.Parent = p
	end
	m.Parent = char
	hideClothes(char, true)
	return m
end

return ArmorModels
