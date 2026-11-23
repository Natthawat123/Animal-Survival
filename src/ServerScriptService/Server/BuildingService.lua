--[[
	BuildingService — วางสิ่งก่อสร้าง + ความสามารถของแต่ละชนิด
	  กำแพง (ขวางทางฝูง) / กับดักหนาม / หน้าไม้ยักษ์ยิงเอง / ตะเกียง (ไล่กวางกลวง) / เตียง (จุดเกิด)
	  แปลงเบอร์รี่ / หม้อตุ๋น / เสาธาตุ 4 แบบ / ประภาคารสุริยะ
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local StructureModels = require(ReplicatedStorage.Shared.StructureModels)
local WallSnap = require(ReplicatedStorage.Shared.WallSnap)

local BuildingService = {}

function BuildingService:Init(ctx)
	self.ctx = ctx
	self.folder = Instance.new("Folder")
	self.folder.Name = "Structures"
	self.folder.Parent = Workspace
	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Include
	self.rayParams.FilterDescendantsInstances = { Workspace.Terrain }
end

function BuildingService:All()
	return self.folder:GetChildren()
end

-- แหล่งแสงที่ปีศาจกวางกลัว: { {Position, Radius} }
function BuildingService:LightSources()
	local out = {}
	for _, s in ipairs(self.folder:GetChildren()) do
		local kind = s:GetAttribute("Kind")
		local spec = Items.Structures[kind]
		if spec and spec.Light then
			table.insert(out, { s:GetPivot().Position, spec.Light * 0.6 })
		end
	end
	return out
end

function BuildingService:Damage(structure, amount)
	if not structure.Parent or structure:GetAttribute("Broken") then
		return
	end
	-- พังได้ทุกอย่างที่ Items.Structures[kind].Breakable (ทุกชนิด ยกเว้นเตียง)
	local spec = Items.Structures[structure:GetAttribute("Kind")]
	if not (spec and spec.Breakable) then
		return
	end
	local hp = (structure:GetAttribute("Health") or 0) - amount
	structure:SetAttribute("Health", hp)
	self.ctx.Remotes.Get("HitFx"):FireAllClients("StructureHit", { Structure = structure, Amount = amount })
	if hp <= 0 then
		if spec.Storage then
			self.ctx.Services.StorageService:Spill(structure) -- กล่องพัง = ของข้างในหล่นพื้น (ไม่หาย)
		end
		self:Vanish(structure)
	end
end

-- เอาออกจากแมพ: ท่าพังฝั่งผู้เล่น + คืนโควต้า + ซ่อนแล้วลบ (ใช้ทั้งตอนพังและตอนค้อนรื้อ)
function BuildingService:Vanish(structure)
	do
		structure:SetAttribute("Broken", true)
		-- ท่าพังตามวัสดุเล่นฝั่งเครื่องผู้เล่น (BreakFX) · เซิร์ฟเวอร์ซ่อนของจริงแล้วลบ
		self.ctx.Remotes.Get("HitFx"):FireAllClients("StructureBreak", { Structure = structure, Kind = structure:GetAttribute("Kind"), Position = structure:GetPivot().Position })
		CollectionService:RemoveTag(structure, "Structure")
		self.ctx.Services.InventoryService:MarkDirty() -- พังแล้วคืนโควต้า (Limits) -> อัปเดตตัวเลขบนหน้าคราฟต์
		task.delay(0.25, function()
			for _, d in ipairs(structure:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Transparency = 1
					d.CanCollide = false
					d.CanQuery = false
				elseif d:IsA("Light") or d:IsA("Fire") or d:IsA("ParticleEmitter") then
					d.Enabled = false
				end
			end
		end)
		task.delay(0.6, function()
			structure:Destroy()
		end)
	end
end

-- ตรวจจุดวาง (ใช้ทั้งวางใหม่และย้ายด้วยค้อนช่าง) -> CFrame ที่ติดพื้นแล้ว หรือ nil (แจ้งผู้เล่นเอง)
-- ignore = สิ่งก่อสร้างที่กำลังย้าย (ไม่นับว่าทับตัวเอง)
function BuildingService:CheckSpot(player, kind, cf, ignore)
	local spec = Items.Structures[kind]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - cf.Position).Magnitude > Config.BuildRange then
		self.ctx.Notify(player, "Too far away", "Error")
		return nil
	end
	-- หาพื้น
	local hit = Workspace:Raycast(cf.Position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), self.rayParams)
	if not hit then
		self.ctx.Notify(player, "Must be placed on the ground", "Error")
		return nil
	end
	if hit.Material == Enum.Material.Water or hit.Material == Enum.Material.CrackedLava then
		self.ctx.Notify(player, "Can't place on water/lava", "Error")
		return nil
	end
	local pos = hit.Position
	if (pos - self.ctx.CampPosition).Magnitude < 9 then
		self.ctx.Notify(player, "Too close to the campfire", "Error")
		return nil
	end
	-- วางได้เฉพาะในเขตแคมป์ (รัศมีตามเลเวลกองไฟ — อัปเกรดกองไฟ = เขตกว้างขึ้น)
	--   spec.Anywhere (หินวาร์ป) = วางนอกแคมป์ได้ทั่วแมพ
	local campR = self.ctx.Services.CampService:CampRadius()
	if not spec.Anywhere and ((pos - self.ctx.CampPosition) * Vector3.new(1, 0, 1)).Magnitude > campR then
		self.ctx.Notify(player, "Can only be placed inside the camp (upgrade the campfire to expand it)", "Error")
		return nil
	end
	-- ของฐานกว้าง (ลานหินวาร์ปบาง): วัดพื้นใต้ลาน -> วางที่ระดับดินสูงสุด (ดินไม่โผล่ทับลาน) · ฝั่งที่ดินต่ำกว่า = แท่นหิน Foundation รองไว้
	if spec.GroundRadius then
		local high = pos.Y
		for _, r in ipairs({ spec.GroundRadius * 0.5, spec.GroundRadius }) do
			for i = 0, 11 do
				local a = i / 12 * math.pi * 2
				local q = pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				local h = Workspace:Raycast(q + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), self.rayParams)
				if h and h.Material ~= Enum.Material.Water then
					high = math.max(high, h.Position.Y)
				end
			end
		end
		pos = Vector3.new(pos.X, math.min(high, pos.Y + 4) + 0.03, pos.Z)
	end
	-- ฐานแคบทรงเหลี่ยม (เสาธาตุ): วางที่ดินต่ำสุดใต้ฐาน -> บนพื้นเอียงฐานไม่ลอยเห็นช่อง (ฝั่งดินสูงจมลงแทน)
	if spec.GroundLow then
		local low = pos.Y
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local q = pos + Vector3.new(math.cos(a) * spec.GroundLow, 0, math.sin(a) * spec.GroundLow)
			local h = Workspace:Raycast(q + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), self.rayParams)
			if h and h.Material ~= Enum.Material.Water then
				low = math.min(low, h.Position.Y)
			end
		end
		pos = Vector3.new(pos.X, math.max(low, pos.Y - 1.5), pos.Z)
	end
	local _, yaw = cf:ToOrientation()
	local final = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	-- กันซ้อนทับ
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { self.folder }
	local boxCf, boxSize = final * CFrame.new(0, spec.Size.Y / 2 + 0.5, 0), spec.Size * 0.85
	if WallSnap.IsWall(kind) then
		boxCf, boxSize = WallSnap.OverlapBox(kind, final, spec.Size.Y * 0.85)
	end
	for _, p in ipairs(Workspace:GetPartBoundsInBox(boxCf, boxSize, params)) do
		if not (ignore and p:IsDescendantOf(ignore)) then
			self.ctx.Notify(player, "Overlaps another building", "Error")
			return nil
		end
	end
	return final, pos
end

function BuildingService:Place(player, kind, cf)
	local spec = Items.Structures[kind]
	if not spec or typeof(cf) ~= "CFrame" then
		return false
	end
	local inv = self.ctx.Services.InventoryService
	if inv:Count(player, kind) <= 0 then
		self.ctx.Notify(player, "You have no " .. Items.DisplayName(kind) .. " in your bag (craft it at the bench first)", "Error")
		return false
	end
	-- เตียง: วางแล้วตัวคูณวัน +1 (ทั้งเซิร์ฟได้ 2 ครั้งต่อเกม)
	if (kind == "Bed" or kind == "Bed2") and not self.ctx.Services.DirectorService:CanSkipDay() then
		self.ctx.Notify(player, "Can't use a bed to skip a day right now", "Error")
		return false
	end
	local final, pos = self:CheckSpot(player, kind, cf)
	if not final then
		return false
	end
	inv:Remove(player, kind, 1)
	-- ช่างสร้าง: กำแพงและสิ่งก่อสร้างทุกชนิดถึกขึ้นตามทักษะ
	local hp = spec.Health * self.ctx.Services.SurvivalService:Perk(player, "WallHealthMult", 1)
	local model = self:Spawn(kind, final, hp, hp, player.UserId)
	self.ctx.Remotes.Get("HitFx"):FireAllClients("Build", { Position = pos, Kind = kind, Structure = model })
	self.ctx.Services.TraderService:MakeRoom(pos, spec.Size) -- พ่อค้ายืนตรงนั้น = เดินหลบให้
	if kind == "Bed" or kind == "Bed2" then
		-- เตียง 1 / เตียง 2 = ตัวคูณวัน +1 (โควต้านับแยกชนิด)
		local st, used = self.ctx.State, kind == "Bed" and "BedsUsed" or "Bed2Used"
		st:SetAttribute(used, (st:GetAttribute(used) or 0) + 1)
		self.ctx.Services.DirectorService:AddBedMultiplier(player) -- เตียง = ตัวคูณวัน +1
		self.ctx.Services.InventoryService:MarkDirty()
	end
	return true
end

---------------------------------------------------------------- ค้อนช่าง: ย้าย / รื้อ
-- ชื่อไม่เอาวงเล็บท้าย ("Bed (+1 Day)" -> "Bed")
local function shortName(kind)
	return (Items.DisplayName(kind):gsub("%s*%b()$", ""))
end

-- ต้องถือค้อนช่างอยู่ + สิ่งก่อสร้างยังอยู่ในแคมป์นี้ + อยู่ในระยะ
function BuildingService:HammerTarget(player, structure)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local spec = tool and Items.Tools[tool:GetAttribute("ItemId")]
	if not (spec and spec.Builder) then
		self.ctx.Notify(player, "Hold the Builder's Hammer first", "Error")
		return nil
	end
	if typeof(structure) ~= "Instance" or structure.Parent ~= self.folder or structure:GetAttribute("Broken") then
		return nil
	end
	local kind = structure:GetAttribute("Kind")
	if not Items.Structures[kind] then
		return nil
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - structure:GetPivot().Position).Magnitude > Config.BuildRange then
		self.ctx.Notify(player, "Too far away", "Error")
		return nil
	end
	return kind
end

-- ย้าย: ของเดิมทั้งชิ้น (เลือดเท่าเดิม) ไปจุดใหม่ · เตียงย้ายแล้วไม่ข้ามวันซ้ำ
function BuildingService:Move(player, structure, cf)
	local kind = self:HammerTarget(player, structure)
	if not kind or typeof(cf) ~= "CFrame" then
		return false
	end
	local final, pos = self:CheckSpot(player, kind, cf, structure)
	if not final then
		return false
	end
	structure:PivotTo(final)
	self.ctx.Remotes.Get("HitFx"):FireAllClients("Build", { Position = pos, Kind = kind, Structure = structure })
	self.ctx.Services.TraderService:MakeRoom(pos, Items.Structures[kind].Size)
	self.ctx.Notify(player, string.format("Moved %s", shortName(kind)), "Good")
	return true
end

-- รื้อ: เก็บสิ่งก่อสร้างคืน "ทั้งชิ้น" เข้ากระเป๋า (ไปวางใหม่ได้) — ไม่ใช่วัตถุดิบ
--   รื้อได้ทุกชนิด (เดิมใช้ Damage -> ของที่พังไม่ได้ เช่นหน้าไม้/กับดัก ไม่หายไปแต่ได้วัตถุดิบ = ปั๊มของได้)
--   เตียง: ได้โบนัสข้ามวันไปแล้วตอนวาง -> รื้อได้แต่ไม่คืนเตียง (กันวางซ้ำปั๊มวัน)
function BuildingService:Demolish(player, structure)
	local kind = self:HammerTarget(player, structure)
	if not kind then
		return false
	end
	if Items.Structures[kind] and Items.Structures[kind].Storage then
		self.ctx.Services.StorageService:Spill(structure) -- ของในกล่องหล่นพื้น
	end
	self:Vanish(structure)
	if kind == "Bed" or kind == "Bed2" then
		self.ctx.Notify(player, string.format("Removed %s (its day bonus was already used, so it isn't returned)", shortName(kind)), "Info")
		return true
	end
	self.ctx.Services.InventoryService:Add(player, kind, 1)
	self.ctx.Services.InventoryService:MarkDirty()
	self.ctx.Notify(player, string.format("Picked up %s — it's back in your hotbar", shortName(kind)), "Good")
	return true
end

function BuildingService:Spawn(kind, cf, hp, maxHp, owner, contents, level)
	local model = StructureModels.Build(kind)
	model:PivotTo(cf)
	model:SetAttribute("Level", math.clamp(math.floor(tonumber(level) or 1), 1, Items.MaxStructLevel))
	if type(contents) == "string" and contents ~= "" then
		model:SetAttribute("Contents", contents)
	end
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Health", hp)
	model:SetAttribute("MaxHealth", maxHp)
	model:SetAttribute("Owner", owner)
	CollectionService:AddTag(model, "Structure")
	model.Parent = self.folder
	self:Setup(model, kind)
	return model
end

-- เก็บ/คืนสิ่งก่อสร้างทั้งหมด (RejoinService) : { Kind, x, y, z, yaw, Health, MaxHealth, Owner }
function BuildingService:Serialize()
	local out = {}
	for _, m in ipairs(self.folder:GetChildren()) do
		local kind = m:GetAttribute("Kind")
		if kind and Items.Structures[kind] and (m:GetAttribute("Health") or 0) > 0 and #out < 300 then
			local cf = m:GetPivot()
			local _, yaw = cf:ToOrientation()
			table.insert(out, { kind, math.floor(cf.X * 10) / 10, math.floor(cf.Y * 10) / 10, math.floor(cf.Z * 10) / 10, math.floor(yaw * 1000) / 1000,
				math.floor(m:GetAttribute("Health")), math.floor(m:GetAttribute("MaxHealth") or 0), m:GetAttribute("Owner") or 0,
				m:GetAttribute("Contents") or "", m:GetAttribute("Level") or 1 }) -- [9] ของในกล่องเก็บของ (JSON) · [10] เลเวลอัปเกรด
		end
	end
	return out
end

function BuildingService:Restore(list)
	local beds, beds2 = 0, 0
	for _, r in ipairs(list or {}) do
		if r[1] == "Bed" then
			beds += 1
		elseif r[1] == "Bed2" then
			beds2 += 1
		end
		local kind = r[1]
		if Items.Structures[kind] then
			local ok, err = pcall(self.Spawn, self, kind, CFrame.new(r[2], r[3], r[4]) * CFrame.Angles(0, r[5], 0), r[6], math.max(r[7], r[6]), r[8], r[9], r[10])
			if not ok then
				warn("[AS] restore structure", kind, err)
			end
		end
	end
	-- เตียงที่วางไว้ = ใช้โควต้าข้ามวันไปแล้ว (คืนรอบไม่ได้วันเพิ่มซ้ำ)
	self.ctx.State:SetAttribute("BedsUsed", math.max(self.ctx.State:GetAttribute("BedsUsed") or 0, beds))
	self.ctx.State:SetAttribute("Bed2Used", math.max(self.ctx.State:GetAttribute("Bed2Used") or 0, beds2))
end

-- แปลงเบอร์รี่: ปลูกแล้วต้นค่อย ๆ โต (ต้นกล้า -> ต้นเล็ก -> ต้นใหญ่) -> โตเต็มที่ลูกออก (Yield ลูกทั้งแปลง)
--   ผู้เล่นชี้ลูกบนต้นแล้วคลิก/แตะเก็บทีละลูก (ResourceService:OnPickRequest -> PickCrop) · เก็บหมดแปลง = ต้นหดเป็นต้นกล้า ปลูกรอบใหม่
local FARM_STAGES = { 0.3, 0.55, 0.8 } -- ขนาดต้นช่วงโต (สัดส่วนของต้นโตเต็มที่)

-- ลูกที่ใช้ในแปลง: ต้นละ per ลูกแรก (ลูกส่วนเกินในโมเดลซ่อนถาวร)
local function cropBerries(model)
	local crops = model:FindFirstChild("Crops")
	local out = {}
	if not crops then
		return out
	end
	local bushes = crops:GetChildren()
	local per = math.max(1, math.ceil(Items.Structures.FarmPlot.Yield / math.max(1, #bushes)))
	for _, bush in ipairs(bushes) do
		local n = 0
		for _, p in ipairs(bush:GetDescendants()) do
			if p:IsA("BasePart") and p.Name == "Berry" then
				n += 1
				if n <= per then
					table.insert(out, p)
				else
					p.Transparency = 1
					p.Name = "BerryUnused"
				end
			end
		end
	end
	return out
end

local function showCrops(model, ready)
	local n = 0
	for _, p in ipairs(cropBerries(model)) do
		if p:GetAttribute("OrigT") == nil then
			p:SetAttribute("OrigT", p.Transparency)
		end
		p.Transparency = ready and p:GetAttribute("OrigT") or 1
		p:SetAttribute("Picked", not ready)
		if ready then
			n += 1
		end
	end
	model:SetAttribute("Berries", n)
	model:SetAttribute("MaxBerries", #cropBerries(model))
end

-- ย่อ/ขยายต้นในแปลงตามช่วงโต (ย่อรอบโคนต้น ต้นไม่ลอย/จม)
local function sizeCrops(model, f)
	if model:GetAttribute("CropScale") == f then
		return
	end
	model:SetAttribute("CropScale", f)
	local crops = model:FindFirstChild("Crops")
	for _, bush in ipairs(crops and crops:GetChildren() or {}) do
		if bush:IsA("Model") then
			local full = bush:GetAttribute("FullScale")
			if not full then
				full = bush:GetScale()
				bush:SetAttribute("FullScale", full)
			end
			local cf, sz = bush:GetBoundingBox()
			bush.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, sz.Y / 2, 0))
			pcall(function()
				bush:ScaleTo(full * f)
			end)
		end
	end
end

local function growStage(model, now)
	local grow = Items.Structures.FarmPlot.GrowTime
	local left = (model:GetAttribute("GrowAt") or now) - now
	if left <= 0 then
		return 1
	end
	local p = 1 - left / grow
	return FARM_STAGES[math.clamp(math.floor(p * #FARM_STAGES) + 1, 1, #FARM_STAGES)]
end

function BuildingService:UpdateFarm(model, now)
	local f = growStage(model, now)
	sizeCrops(model, f)
	local ready = f >= 1
	if ready and not model:GetAttribute("Ripe") then
		model:SetAttribute("Ripe", true)
		showCrops(model, true)
	end
end

-- เก็บลูก 1 ลูกจากแปลง (ลูกที่ชี้) · หมดแปลง = เริ่มปลูกรอบใหม่
function BuildingService:PickCrop(player, model, part, how)
	if not model:GetAttribute("Ripe") or part.Name ~= "Berry" or part:GetAttribute("Picked") or not part:IsDescendantOf(model) then
		return false
	end
	local from = part.Position
	part.Transparency = 1
	part:SetAttribute("Picked", true)
	local left = math.max(0, (model:GetAttribute("Berries") or 1) - 1)
	model:SetAttribute("Berries", left)
	self.ctx.Services.ResourceService:GiveBerry(player, from, how)
	if left <= 0 then
		model:SetAttribute("Ripe", false)
		model:SetAttribute("GrowAt", os.clock() + Items.Structures.FarmPlot.GrowTime)
		showCrops(model, false)
		sizeCrops(model, FARM_STAGES[1])
	end
	return true
end

-- หม้อตุ๋น: Stew = เนื้อ 2 + เบอร์รี่ 2 (ใช้เนื้อย่างก่อน) · BerryPie = เบอร์รี่ 5 + ไม้ 1
function BuildingService:Cook(player, dish)
	local inv = self.ctx.Services.InventoryService
	local cost, need
	if dish == "Stew" then
		local meat = inv:Count(player, "CookedMeat") >= 2 and "CookedMeat" or "RawMeat"
		cost, need = { [meat] = 2, Berries = 2 }, "Needs 2 meat and 2 berries"
	elseif dish == "BerryPie" then
		cost, need = { Berries = 5, Wood = 1 }, "Needs 5 berries and 1 wood"
	else
		return false
	end
	if not inv:Spend(player, cost) then
		self.ctx.Notify(player, need, "Error")
		return false
	end
	inv:Add(player, dish, 1)
	return true
end

-- ปุ่มกดของแปลงผัก/หม้อ/กล่องเก็บของ/ประตู
---------------------------------------------------------------- อัปเกรด (หอธนู + เสาธาตุ 3 เลเวล)
local function costText(cost)
	local parts = {}
	for id, n in pairs(cost) do
		table.insert(parts, { id, n })
	end
	table.sort(parts, function(a, b)
		return a[1] < b[1]
	end)
	for i, x in ipairs(parts) do
		parts[i] = string.format("%d %s", x[2], Items.DisplayName(x[1]))
	end
	return table.concat(parts, " · ")
end

-- ดาวเลเวลลอยเหนือสิ่งก่อสร้าง (★☆☆) + ข้อความปุ่มอัปเกรด (ของที่ต้องใช้)
function BuildingService:RefreshUpgrade(model)
	local kind = model:GetAttribute("Kind")
	local ups = Items.StructUpgrades[kind]
	if not ups then
		return
	end
	local lv = model:GetAttribute("Level") or 1
	local host = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not host then
		return
	end
	local tag = model:FindFirstChild("LevelTag")
	if not tag then
		tag = Instance.new("BillboardGui")
		tag.Name = "LevelTag"
		tag.Size = UDim2.fromOffset(110, 26)
		tag.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y + 0.6, 0)
		tag.MaxDistance = 70
		tag.LightInfluence = 0
		tag.Adornee = host
		tag.Parent = model
		local t = Instance.new("TextLabel")
		t.Name = "Stars"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextSize = 22
		t.TextColor3 = Color3.fromRGB(255, 214, 80)
		t.TextStrokeTransparency = 0.1
		t:SetAttribute("NoTranslate", true)
		t.Parent = tag
	end
	tag.Stars.Text = string.rep("★", lv) .. string.rep("☆", Items.MaxStructLevel - lv)
	local p = model:FindFirstChild("UpgradePrompt", true)
	if not p then
		p = Instance.new("ProximityPrompt")
		p.Name = "UpgradePrompt"
		p.HoldDuration = 1
		p.MaxActivationDistance = 14
		p.RequiresLineOfSight = false
		p.KeyboardKeyCode = Enum.KeyCode.E
		p.Parent = host
		p.Triggered:Connect(function(player)
			self:Upgrade(player, model)
		end)
	end
	local nxt = ups[lv + 1]
	p.Enabled = nxt ~= nil
	if nxt then
		p.ActionText = string.format("Upgrade to Lv.%d", lv + 1)
		p.ObjectText = costText(nxt.Cost)
	end
end

function BuildingService:Upgrade(player, model)
	if not (model.Parent == self.folder and not model:GetAttribute("Broken") and (model:GetAttribute("Health") or 0) > 0) then
		return
	end
	if not player:GetAttribute("InRun") or self.ctx.Services.SurvivalService:IsIncapacitated(player) then
		return
	end
	local kind = model:GetAttribute("Kind")
	local ups = Items.StructUpgrades[kind]
	local lv = model:GetAttribute("Level") or 1
	local nxt = ups and ups[lv + 1]
	if not nxt then
		self.ctx.Notify(player, "Already at max level", "Info")
		return
	end
	local inv = self.ctx.Services.InventoryService
	if not inv:Spend(player, nxt.Cost) then
		self.ctx.Notify(player, "Not enough materials: " .. costText(nxt.Cost), "Error")
		return
	end
	-- เลือดเต็มเพิ่มตามสัดส่วนเลเวล (คงโบนัสช่างสร้างเดิม) + เติมเลือดเท่าส่วนที่เพิ่ม
	local before, after = Items.StructSpec(kind, lv), Items.StructSpec(kind, lv + 1)
	local oldMax = model:GetAttribute("MaxHealth") or before.Health
	local newMax = math.floor(oldMax * after.Health / math.max(before.Health, 1) + 0.5)
	model:SetAttribute("Level", lv + 1)
	model:SetAttribute("MaxHealth", newMax)
	model:SetAttribute("Health", math.min(newMax, (model:GetAttribute("Health") or 0) + (newMax - oldMax)))
	self.ctx.Remotes.Get("HitFx"):FireAllClients("Build", { Position = model:GetPivot().Position, Kind = kind, Structure = model })
	self.ctx.Notify(player, string.format("⬆ %s upgraded to Lv.%d!", Items.DisplayName(kind), lv + 1), "Good")
	inv:MarkDirty()
	self:RefreshUpgrade(model)
end

function BuildingService:Setup(model, kind)
	self:RefreshUpgrade(model)
	local storage = self.ctx.Services.StorageService
	if storage then
		storage:Setup(model, kind)
	end
	if kind == "FarmPlot" then
		-- ปลูกใหม่: ต้นกล้าเล็ก ๆ ค่อยโตจนลูกออก · ชี้ลูกบนต้นแล้วเก็บ (แท็ก BerrySource)
		model:SetAttribute("GrowAt", os.clock() + Items.Structures.FarmPlot.GrowTime)
		model:SetAttribute("Ripe", false)
		showCrops(model, false)
		self:UpdateFarm(model, os.clock())
		CollectionService:AddTag(model, "BerrySource")
	elseif kind == "CookPot" then
		local p = Instance.new("ProximityPrompt")
		p.ActionText = "Make Stew (2 meat + 2 berries)"
		p.ObjectText = "Stew Pot"
		p.HoldDuration = 1.2
		p.MaxActivationDistance = 12
		p.Parent = model:FindFirstChild("Pot")
		p.Triggered:Connect(function(player)
			self:Cook(player, "Stew")
		end)
		p.UIOffset = Vector2.new(0, -40)
		local pie = Instance.new("ProximityPrompt")
		pie.Name = "PiePrompt"
		pie.ActionText = "Bake Berry Pie (5 berries + 1 wood)"
		pie.ObjectText = "Stew Pot"
		pie.KeyboardKeyCode = Enum.KeyCode.F
		pie.HoldDuration = 1.2
		pie.MaxActivationDistance = 12
		pie.UIOffset = Vector2.new(0, 40)
		pie.Parent = p.Parent
		pie.Triggered:Connect(function(player)
			self:Cook(player, "BerryPie")
		end)
	end
end

-- ความสามารถทำงานทุก 0.5 วิ
function BuildingService:Tick(dt)
	local animals = self.ctx.Services.AnimalService
	local combat = self.ctx.Services.CombatService
	local now = os.clock()
	local earthBuff = self.ctx.State:GetAttribute("SpiritEarth")
	for _, s in ipairs(self.folder:GetChildren()) do
		local kind = s:GetAttribute("Kind")
		local spec = Items.StructSpec(kind, s:GetAttribute("Level")) -- ค่าตามเลเวลอัปเกรด (หอธนู/เสาธาตุ)
		if spec and (s:GetAttribute("Health") or 0) > 0 then
			local pos = s:GetPivot().Position
			if earthBuff then
				s:SetAttribute("Health", math.min(s:GetAttribute("MaxHealth"), s:GetAttribute("Health") + s:GetAttribute("MaxHealth") * 0.01 * dt))
			end
			if kind == "SpikeTrap" then
				if now >= (s:GetAttribute("NextTick") or 0) then
					s:SetAttribute("NextTick", now + spec.Tick)
					for _, a in ipairs(animals:InRadius(pos, 5.5, true)) do
						combat:DamageAnimal(a, spec.Damage, nil, { Source = "Trap" })
					end
				end
			elseif kind == "Ballista" then
				if now >= (s:GetAttribute("NextShot") or 0) then
					local target = animals:Nearest(pos, spec.Range, true)
					if target then
						s:SetAttribute("NextShot", now + spec.Cooldown)
						local turret = s:FindFirstChild("Turret")
						local tpos = target.Root.Position
						if turret then
							turret:PivotTo(CFrame.lookAt(turret:GetPivot().Position, Vector3.new(tpos.X, turret:GetPivot().Position.Y, tpos.Z)))
						end
						local from = pos + Vector3.new(0, spec.Size.Y * 0.6, 0) -- ยิงจากหน้าไม้บนชั้นยอดหอธนู
						self.ctx.Remotes.Get("HitFx"):FireAllClients("Bolt", { From = from, To = tpos })
						task.delay((tpos - from).Magnitude / 260, function()
							if target.Model.Parent then
								combat:DamageAnimal(target, spec.Damage, nil, { Source = "Ballista" })
							end
						end)
					end
				end
			elseif kind == "TerraTotem" then
				-- ซ่อมสิ่งก่อสร้างรอบๆ ทุก HealEvery วิ ครั้งละ Heal หน่วย
				if now >= (s:GetAttribute("NextHeal") or 0) then
					s:SetAttribute("NextHeal", now + (spec.HealEvery or 2))
					for _, other in ipairs(self.folder:GetChildren()) do
						if other ~= s and (other:GetPivot().Position - pos).Magnitude < spec.Radius then
							local mh = other:GetAttribute("MaxHealth") or 0
							other:SetAttribute("Health", math.min(mh, (other:GetAttribute("Health") or 0) + (spec.Heal or 20)))
						end
					end
				end
			elseif kind == "TideTotem" then
				for _, a in ipairs(animals:InRadius(pos, spec.Radius, true)) do
					a.TotemSlowUntil, a.TotemSlow = now + 1, spec.Slow or 0.15 -- ช้าลง 15% (AnimalService)
				end
			elseif kind == "GaleTotem" then
				if now >= (s:GetAttribute("NextGust") or 0) then
					s:SetAttribute("NextGust", now + (spec.GustEvery or 5))
					local hitAny = false
					for _, a in ipairs(animals:InRadius(pos, spec.Radius, true)) do
						if a.Info.Behaviour ~= "Boss" then
							local dir = (a.Root.Position - pos) * Vector3.new(1, 0, 1)
							if dir.Magnitude > 0.1 then
								a.Root.AssemblyLinearVelocity = dir.Unit * 90 + Vector3.new(0, 45, 0)
								hitAny = true
							end
						end
					end
					if hitAny then
						self.ctx.Remotes.Get("HitFx"):FireAllClients("Gust", { Position = pos, Radius = spec.Radius })
					end
				end
			elseif kind == "EmberTotem" then
				-- เผาทุก Tick วิ ครั้งละ Damage (มีเลขเด้ง)
				if now >= (s:GetAttribute("NextTick") or 0) then
					s:SetAttribute("NextTick", now + (spec.Tick or 1))
					for _, a in ipairs(animals:InRadius(pos, spec.Radius, true)) do
						combat:DamageAnimal(a, spec.Damage, nil, { Source = "Totem" })
					end
				end
			elseif kind == "FarmPlot" then
				self:UpdateFarm(s, now)
			end
		end
	end
end

function BuildingService:Clear()
	self.folder:ClearAllChildren()
end

function BuildingService:Start(ctx)
	ctx.Remotes.Get("PlaceStructure").OnServerEvent:Connect(function(player, kind, cf)
		if ctx.Services.SurvivalService:IsIncapacitated(player) then
			return
		end
		if type(kind) == "string" then
			self:Place(player, kind, cf)
		end
	end)
	ctx.Remotes.Get("MoveStructure").OnServerEvent:Connect(function(player, structure, cf)
		if not ctx.Services.SurvivalService:IsIncapacitated(player) then
			self:Move(player, structure, cf)
		end
	end)
	ctx.Remotes.Get("Demolish").OnServerEvent:Connect(function(player, structure)
		if not ctx.Services.SurvivalService:IsIncapacitated(player) then
			self:Demolish(player, structure)
		end
	end)
	task.spawn(function()
		while true do
			local dt = task.wait(0.5)
			local ok, err = pcall(self.Tick, self, dt)
			if not ok then
				warn("[AS] Building tick:", err)
			end
		end
	end)
end

return BuildingService
