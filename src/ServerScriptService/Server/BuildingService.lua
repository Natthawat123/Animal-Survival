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
	local hp = (structure:GetAttribute("Health") or 0) - amount
	structure:SetAttribute("Health", hp)
	self.ctx.Remotes.Get("HitFx"):FireAllClients("StructureHit", { Structure = structure, Amount = amount })
	if hp <= 0 then
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
	local campR = self.ctx.Services.CampService:CampRadius()
	if ((pos - self.ctx.CampPosition) * Vector3.new(1, 0, 1)).Magnitude > campR then
		self.ctx.Notify(player, "Can only be placed inside the camp (upgrade the campfire to expand it)", "Error")
		return nil
	end
	local _, yaw = cf:ToOrientation()
	local final = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	-- กันซ้อนทับ
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { self.folder }
	for _, p in ipairs(Workspace:GetPartBoundsInBox(final * CFrame.new(0, spec.Size.Y / 2 + 0.5, 0), spec.Size * 0.85, params)) do
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
	-- เตียง: วางแล้วข้ามไป 1 วัน (ทั้งเซิร์ฟได้ 2 ครั้งต่อเกม)
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
	if kind == "Bed" or kind == "Bed2" then
		-- เตียง 1 / เตียง 2 = +1 วัน (โควต้านับแยกชนิด)
		local st, used = self.ctx.State, kind == "Bed" and "BedsUsed" or "Bed2Used"
		st:SetAttribute(used, (st:GetAttribute(used) or 0) + 1)
		self.ctx.Services.DirectorService:SkipDay(player, nil, "Bed")
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
	self.ctx.Notify(player, string.format("Moved %s", shortName(kind)), "Good")
	return true
end

-- รื้อ: พังทิ้ง (เล่นท่าพังเหมือนโดนตีแตก) + คืนวัตถุดิบครึ่งหนึ่ง (ปัดลง) วางเป็นของบนพื้นตรงนั้น
function BuildingService:Demolish(player, structure)
	local kind = self:HammerTarget(player, structure)
	if not kind then
		return false
	end
	local pos = structure:GetPivot().Position + Vector3.new(0, 1.5, 0)
	local recipe = Recipes.ById[kind]
	local drops = self.ctx.Services.DropService
	for id, n in pairs(recipe and recipe.Cost or {}) do
		local back = math.floor(n / 2)
		if back > 0 and Items.Data[id] then -- AnyEssence/AnyHeart ไม่คืน (ไม่รู้ว่าใช้ธาตุไหน)
			drops:Spawn(id, back, pos)
		end
	end
	self:Damage(structure, math.huge)
	self.ctx.Notify(player, string.format("Removed %s — half the materials dropped on the ground", shortName(kind)), "Good")
	return true
end

function BuildingService:Spawn(kind, cf, hp, maxHp, owner)
	local model = StructureModels.Build(kind)
	model:PivotTo(cf)
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
				math.floor(m:GetAttribute("Health")), math.floor(m:GetAttribute("MaxHealth") or 0), m:GetAttribute("Owner") or 0 })
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
			local ok, err = pcall(self.Spawn, self, kind, CFrame.new(r[2], r[3], r[4]) * CFrame.Angles(0, r[5], 0), r[6], math.max(r[7], r[6]), r[8])
			if not ok then
				warn("[AS] restore structure", kind, err)
			end
		end
	end
	-- เตียงที่วางไว้ = ใช้โควต้าข้ามวันไปแล้ว (คืนรอบไม่ได้วันเพิ่มซ้ำ)
	self.ctx.State:SetAttribute("BedsUsed", math.max(self.ctx.State:GetAttribute("BedsUsed") or 0, beds))
	self.ctx.State:SetAttribute("Bed2Used", math.max(self.ctx.State:GetAttribute("Bed2Used") or 0, beds2))
end

-- แปลงเบอร์รี่: ลูกบนพุ่มโผล่เมื่อโตเต็มที่ (เก็บได้) · ยังไม่โต = เห็นแต่ใบ
local function showCrops(model, ready)
	local crops = model:FindFirstChild("Crops")
	if not crops then
		return
	end
	for _, p in ipairs(crops:GetDescendants()) do
		if p:IsA("BasePart") and p.Name == "Berry" then
			p.Transparency = ready and 0 or 1
		end
	end
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

-- ปุ่มกดของแปลงผัก/หม้อ
function BuildingService:Setup(model, kind)
	if kind == "FarmPlot" then
		model:SetAttribute("GrowAt", os.clock() + Items.Structures.FarmPlot.GrowTime)
		showCrops(model, false)
		local p = Instance.new("ProximityPrompt")
		p.ActionText = "Pick Berries"
		p.ObjectText = "Berry Patch"
		p.MaxActivationDistance = 12
		p.Enabled = false
		-- โมเดล Store มีแต่ Model ซ้อนกัน (ไม่มี BasePart ชั้นบน) -> ทำจุดกดใสไว้กลางแปลงเอง
		local spot = Instance.new("Part")
		spot.Name = "Harvest"
		spot.Size = Vector3.new(1, 1, 1)
		spot.Transparency = 1
		spot.Anchored, spot.CanCollide, spot.CanTouch, spot.CanQuery = true, false, false, false
		spot.CFrame = model:GetPivot() * CFrame.new(0, 1.5, 0)
		spot.Parent = model
		p.Parent = spot
		p.Triggered:Connect(function(player)
			if os.clock() >= (model:GetAttribute("GrowAt") or math.huge) then
				self.ctx.Services.DropService:Spawn("Berries", Items.Structures.FarmPlot.Yield, model:GetPivot().Position + Vector3.new(0, 1, 0))
				model:SetAttribute("GrowAt", os.clock() + Items.Structures.FarmPlot.GrowTime)
				p.Enabled = false
				showCrops(model, false)
			end
		end)
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
		local spec = Items.Structures[kind]
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
						local from = pos + Vector3.new(0, 5, 0)
						self.ctx.Remotes.Get("HitFx"):FireAllClients("Bolt", { From = from, To = tpos })
						task.delay((tpos - from).Magnitude / 260, function()
							if target.Model.Parent then
								combat:DamageAnimal(target, spec.Damage, nil, { Source = "Ballista" })
							end
						end)
					end
				end
			elseif kind == "TerraTotem" then
				for _, other in ipairs(self.folder:GetChildren()) do
					if other ~= s and (other:GetPivot().Position - pos).Magnitude < spec.Radius then
						local mh = other:GetAttribute("MaxHealth") or 0
						other:SetAttribute("Health", math.min(mh, (other:GetAttribute("Health") or 0) + mh * 0.02 * dt))
					end
				end
			elseif kind == "TideTotem" then
				for _, a in ipairs(animals:InRadius(pos, spec.Radius, true)) do
					a.SlowUntil = now + 1
				end
			elseif kind == "GaleTotem" then
				if now >= (s:GetAttribute("NextGust") or 0) then
					s:SetAttribute("NextGust", now + 4)
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
				for _, a in ipairs(animals:InRadius(pos, spec.Radius, true)) do
					combat:DamageAnimal(a, spec.Damage * dt, nil, { Source = "Totem", Silent = true })
				end
			elseif kind == "FarmPlot" then
				local ready = now >= (s:GetAttribute("GrowAt") or math.huge)
				local prompt = s:FindFirstChildWhichIsA("ProximityPrompt", true)
				if ready and prompt and not prompt.Enabled then
					prompt.Enabled = true
					showCrops(s, true)
				end
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
