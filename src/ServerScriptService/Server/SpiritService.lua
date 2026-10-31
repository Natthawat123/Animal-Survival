--[[
	SpiritService — ภารกิจหลักของการผจญภัย
	ศาลเจ้า 4 ธาตุ: ลูกสัตว์ธาตุถูกขังในกรง มีสัตว์เฝ้า
	  เข้าถึงลาน = ฉากเปิด (ShrineIntro): ผู้เฝ้าเดินเข้าหากรง -> เราวิ่งเข้าไป -> ผู้เฝ้าหันมาคำราม -> สู้
	  ปราบผู้เฝ้า -> ปลดผนึก = ฉากจบ (ShrineCleared): กรงแตก -> เสาผลึกธาตุผุดขึ้นที่ไบโอม -> ลูกสัตว์ไปอยู่แคมป์
	    ลูกสัตว์โตขึ้น เดินเล่นในแคมป์เอง (ขี่ได้ MountService) + ข้ามไป 1 วัน (เหมือนเตียง) + บัฟถาวร
	  ช่วยครบ = ฉากจบสมบูรณ์
	  รังบอส 4 ธาตุ: เข้าใกล้ = บอสตื่น (สู้ได้ทุกเวลา) ชนะ = หัวใจอสูร + Ruby
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Animals = require(ReplicatedStorage.Shared.Animals)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Nights = require(ReplicatedStorage.Shared.Nights)
local PropBuilder = require(ReplicatedStorage.Shared.PropBuilder)

local SpiritService = {}

local LAIR_RESPAWN = 15 * 60 -- บอสในรังตายแล้วกลับมาใหม่หลังกี่วินาที
local INTRO_TIME, INTRO_TURN = 12, 9 -- ฉากเปิดศาลเจ้า: ผู้เฝ้าถูกปล่อย / หันมาหาผู้เล่น (ตรงกับ Cinematics.ShrineIntro)
local CLEAR_PILLAR, CLEAR_HOME = 3.6, 8.6 -- ฉากจบศาลเจ้า: เสาผุด / ลูกสัตว์ไปโผล่ที่แคมป์ (ตรงกับ Cinematics.ShrineCleared)
local PET_SIZE = 1.9 -- ลูกสัตว์ที่ช่วยแล้วโตขึ้นที่แคมป์ (ตัวใหญ่พอให้ขี่)
local CRYSTAL = { Earth = "TerraCrystal", Water = "TideCrystal", Air = "GaleCrystal", Fire = "EmberCrystal" }
local PILLAR_COLOR = {
	Earth = Color3.fromRGB(120, 245, 90), Water = Color3.fromRGB(70, 210, 255),
	Air = Color3.fromRGB(200, 235, 255), Fire = Color3.fromRGB(255, 120, 40),
}

local BUFF_TEXT = {
	Earth = "สิ่งก่อสร้างค่อยๆ ซ่อมตัวเอง",
	Water = "กองไฟกินเชื้อเพลิงช้าลง 25%",
	Air = "ทุกคนวิ่งเร็วขึ้น 10%",
	Fire = "กองไฟเผาศัตรูที่บุกเข้าเขตปลอดภัย",
}

function SpiritService:Init(ctx)
	self.ctx = ctx
	self.shrines = {} -- [element] = { Model, Pup, Guardians, Freed, Rescued, Prompt }
	self.lairs = {} -- [element] = { Model, Boss, Cleared, LastSeen }
end

local function charRoot(p)
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function nearestPlayer(pos, radius)
	local best, bestD
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r then
			local d = (r.Position - pos).Magnitude
			if d < radius and (not bestD or d < bestD) then
				best, bestD = p, d
			end
		end
	end
	return best, bestD
end

local function playersNear(pos, radius)
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r and (r.Position - pos).Magnitude < radius then
			table.insert(out, p)
		end
	end
	return out
end

---------------------------------------------------------------- ศาลเจ้า
function SpiritService:SetupShrine(model)
	local el = model:GetAttribute("Element")
	local cage = model:FindFirstChild("Cage")
	local seal = cage and cage:FindFirstChild("Seal")
	local base = model:GetPivot().Position
	local sh = { Model = model, Element = el, Base = base, SitePos = model:GetAttribute("SitePos") or base, Guardians = {}, Freed = false, Rescued = false }
	-- จุดยืนตอนวาร์ปเข้าห้อง (ประตูข้างนอก Dest) -> ทิศที่ผู้เล่นเดินมาหากรง ใช้วางผู้เฝ้าในฉากเปิด
	for _, d in ipairs(model:GetDescendants()) do
		local dest = d:GetAttribute("Dest")
		if typeof(dest) == "Vector3" and math.abs(dest.Y - base.Y) < 30 then
			sh.Entry = dest
			sh.OutVeil = d
			break
		end
	end
	self.shrines[el] = sh
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Unseal"
	prompt.ActionText = "ปลดผนึก"
	prompt.ObjectText = "กรงผนึก" .. el
	prompt.HoldDuration = 3
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = seal or model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		self:Free(el, player)
	end)
	sh.Prompt = prompt
	self:SpawnPup(sh)
end

function SpiritService:SpawnPup(sh)
	if sh.Pup and sh.Pup.Model.Parent then
		sh.Pup.Model:Destroy()
	end
	local id = Animals.Spirits[sh.Element]
	local a = self.ctx.Services.AnimalService:Spawn(id, sh.Base + Vector3.new(0, 0.3, 0), { Kind = "Spirit", NoSnap = true })
	if a then
		a.Root.Anchored = true
		a.Model:SetAttribute("State", "Caged")
		sh.Pup = a
	end
end

function SpiritService:SpawnGuardians(sh)
	local pool = Animals.RaidPool[sh.Element]
	local animals = self.ctx.Services.AnimalService
	local rng = Random.new()
	sh.Guardians = {}
	-- ครั้งแรกของรอบ = ฉากเปิด: ผู้เฝ้าเริ่มที่ข้างลาน/หลังกรง แล้วค่อยๆ เดินเข้าล้อมกรง
	local intro = not sh.IntroPlayed and sh.Entry ~= nil
	sh.IntroPlayed = true
	local frame = sh.Entry and CFrame.lookAt(sh.Base, Vector3.new(sh.Entry.X, sh.Base.Y, sh.Entry.Z)) -- -Z = ทางที่ผู้เล่นเดินมา
	local count = 3
	for i = 1, count do
		local id = pool[math.min(i, #pool)]
		local pos, stand
		if intro then
			local side = ({ -1, 1, 0 })[i]
			pos = (frame * CFrame.new(side * 36, 2, i == 3 and 28 or 8)).Position
			stand = (frame * CFrame.new(side * 11, 0, i == 3 and 11 or 2)).Position
		else
			local ang = i / count * math.pi * 2
			pos = sh.Base + Vector3.new(math.cos(ang) * 18, 2, math.sin(ang) * 18)
		end
		local h = self.ctx.Layout:HeightAt(pos.X, pos.Z)
		local a = animals:Spawn(id, Vector3.new(pos.X, math.max(h, sh.Base.Y) + 1, pos.Z), {
			Kind = "Guardian", Home = sh.Base, Leash = 70, HealthMult = 1.6, DamageMult = 1.2,
			Yaw = intro and math.atan2(pos.X - sh.Base.X, pos.Z - sh.Base.Z) or nil, -- หันหน้าเข้าหากรง
		})
		if a then
			a.Model:SetAttribute("Guardian", true)
			table.insert(sh.Guardians, a)
			if intro then
				-- เดินช้าๆ เข้าหากรงให้ถึงใน ~7 วิ (AI หยุดคิดจนจบฉาก)
				a.IntroUntil = os.clock() + INTRO_TIME
				local dist = (Vector3.new(stand.X, 0, stand.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
				local factor = math.clamp(dist / 7 / ((a.Info.Speed or 16) * a.SpeedMult), 0.12, 1)
				animals:MoveTo(a, Vector3.new(stand.X, sh.Base.Y + 2, stand.Z), factor)
			end
		end
	end
	sh.GuardiansSpawned = true
	if not intro then
		self.ctx.Broadcast(string.format("⚔ ผู้พิทักษ์ศาลเจ้า%s ตื่นขึ้นแล้ว! ปราบให้หมดเพื่อปลดผนึก", sh.Element), "Warn")
		return
	end
	local cin = self.ctx.Remotes.Get("Cinematic")
	local pupName = sh.Pup and sh.Pup.Info.Thai or ""
	for _, p in ipairs(playersNear(sh.Base, 170)) do
		cin:FireClient(p, "ShrineIntro", { Element = sh.Element, Cage = sh.Base, Entry = sh.Entry, Name = pupName, Dur = INTRO_TIME, Turn = INTRO_TURN })
	end
	-- ตัวหลังกรงขู่ใส่ลูกสัตว์ก่อน (ระหว่างช็อตผู้เฝ้าเดินเข้าหา)
	task.delay(INTRO_TURN - 2.8, function()
		local g = sh.Guardians[1]
		if g and not g.Dead and g.Model.Parent then
			animals:MarkAttack(g, "Bite")
		end
	end)
	-- ผู้เฝ้าเห็นเรา: หยุด หันมา คำราม
	task.delay(INTRO_TURN, function()
		for _, g in ipairs(sh.Guardians) do
			if not g.Dead and g.Model.Parent then
				local p = nearestPlayer(g.Root.Position, 250)
				local r = p and charRoot(p)
				animals:Stop(g)
				if r then
					animals:Face(g, r.Position)
				end
				animals:MarkAttack(g, "Roar")
			end
		end
	end)
	task.delay(INTRO_TIME, function()
		self.ctx.Broadcast(string.format("⚔ ผู้พิทักษ์ศาลเจ้า%s ตื่นขึ้นแล้ว! ปราบให้หมดเพื่อปลดผนึก", sh.Element), "Warn")
	end)
end

-- ช่วยแล้ว = ประตูข้างนอกปิดจนจบรอบ (คนที่อยู่ข้างในยังออกทางประตูกลับได้) · เริ่มรอบใหม่สร้างศาลเจ้าใหม่ ประตูเปิดเอง
function SpiritService:SealPortal(sh)
	local veil = sh.OutVeil
	if not veil then
		warn("[AS] ศาลเจ้า", sh.Element, "หาประตูข้างนอกไม่เจอ")
		return
	end
	veil:SetAttribute("Sealed", true)
	local prompt = veil:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.ActionText = "ปิดผนึกแล้ว"
	end
end

function SpiritService:Free(el, player)
	local sh = self.shrines[el]
	if not sh or sh.Freed or not sh.Pup then
		return
	end
	sh.Freed = true
	sh.Prompt.Enabled = false
	self:SealPortal(sh)
	-- กรงแตก
	local cage = sh.Model:FindFirstChild("Cage")
	if cage then
		for _, d in ipairs(cage:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.AssemblyLinearVelocity = Vector3.new(math.random(-25, 25), math.random(20, 45), math.random(-25, 25))
				TweenService:Create(d, TweenInfo.new(2), { Transparency = 1 }):Play()
			end
		end
	end
	local a = sh.Pup
	local pillarPos = self:PillarPos(sh)
	local home = self:PetSpot(el)
	-- คนในห้องศาลเจ้าดูฉากจบเต็ม (ลูกสัตว์ดีใจ -> เสาผุดที่ไบโอม -> ไปโผล่ที่แคมป์) · โหลดพื้นรอบเสา/แคมป์ล่วงหน้า
	local cin = self.ctx.Remotes.Get("Cinematic")
	for _, p in ipairs(playersNear(sh.Base, 170)) do
		cin:FireClient(p, "ShrineCleared", {
			Element = el, Name = a.Info.Thai, Cage = sh.Base, Pillar = pillarPos, Home = home, Player = player.DisplayName,
			PillarAt = CLEAR_PILLAR, HomeAt = CLEAR_HOME, Buff = BUFF_TEXT[el], PetId = Animals.Spirits[el],
		})
		task.spawn(function()
			pcall(function()
				p:RequestStreamAroundAsync(pillarPos, 4)
			end)
			pcall(function()
				p:RequestStreamAroundAsync(home, 4)
			end)
		end)
	end
	self.ctx.Broadcast(string.format("✨ %s ปลดปล่อย %s แล้ว!", player.DisplayName, a.Info.Thai), "Reward")
	task.delay(CLEAR_PILLAR, function()
		if sh.Model.Parent then
			self:RaisePillar(sh, false)
		end
	end)
	task.delay(CLEAR_HOME, function()
		if sh.Model.Parent then
			self:Rescue(a, player)
		end
	end)
end

-- ดวงไฟธาตุบนเสาธงที่แคมป์ติดสว่าง
function SpiritService:LightOrb(el, info)
	local camp = self.ctx.Services.CampService.campModel
	local orb = camp and camp:FindFirstChild("SpiritOrb_" .. el)
	if not orb then
		return
	end
	orb.Material = Enum.Material.Neon
	orb.Color = info.Model.Colors.Glow or info.Model.Colors.Main
	if not orb:FindFirstChildOfClass("PointLight") then
		local l = Instance.new("PointLight")
		l.Color = orb.Color
		l.Range = 26
		l.Brightness = 3
		l.Parent = orb
	end
end

-- จุดที่ลูกสัตว์โผล่ที่แคมป์: รอบกองไฟคนละทิศ (ห่างกองไฟพอ ไม่ยืนทับไฟ)
function SpiritService:PetSpot(el)
	local campPos = self.ctx.CampPosition
	local ang = ({ Earth = 0, Water = 1, Air = 2, Fire = 3 })[el] * math.pi / 2 + 0.6
	local p = campPos + Vector3.new(math.cos(ang) * 24, 0, math.sin(ang) * 24)
	return Vector3.new(p.X, self.ctx.Layout:HeightAt(p.X, p.Z) + 2, p.Z)
end

-- ลูกสัตว์ (โตแล้ว) ไปอยู่แคมป์: เดินเล่นเองในเขตแคมป์ ไม่ต้องตามใคร · ขี่ได้ (MountService)
function SpiritService:SpawnPet(sh)
	local animals = self.ctx.Services.AnimalService
	if sh.Pup then
		animals:Remove(sh.Pup)
		sh.Pup = nil
	end
	if sh.Pet and not sh.Pet.Removed then
		return sh.Pet
	end
	local pos = self:PetSpot(sh.Element)
	local spiritId = Animals.Spirits[sh.Element]
	local petScale = Animals.Data[spiritId].Model.Skin.PetScale or PET_SIZE -- แต่ละตัวโตไม่เท่ากัน ให้ขนาดพอดีขี่
	local a = animals:Spawn(spiritId, pos, { Kind = "Spirit", SizeMult = petScale, Yaw = math.random() * math.pi * 2 })
	if not a then
		return nil
	end
	a.Pet = true
	a.Home = self.ctx.CampPosition
	a.WanderAt = os.clock() + 5 -- ยืนดีใจให้เห็นหน้าก่อน (ฉากจบ) ค่อยเดินเล่น
	a.Model:SetAttribute("Pet", true)
	a.Model:SetAttribute("State", "Idle")
	sh.Pet = a
	self.ctx.Remotes.Get("HitFx"):FireAllClients("Vanish", { Position = pos })
	if self.ctx.Services.MountService then
		self.ctx.Services.MountService:AddPet(a)
	end
	return a
end

-- เสาผลึกธาตุยักษ์ผุดขึ้นที่ไบโอม (หลังประตูศาลเจ้า) = ศาลเจ้านี้ช่วยสำเร็จแล้ว · ลำแสงขึ้นฟ้าเห็นได้ทั้งแมพ
function SpiritService:PillarPos(sh)
	local site = sh.SitePos
	local away = (site - self.ctx.CampPosition) * Vector3.new(1, 0, 1)
	away = away.Magnitude > 1 and away.Unit or Vector3.new(0, 0, 1)
	local p = site + away * 34
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(p.X, site.Y + 200, p.Z), Vector3.new(0, -500, 0), rp)
	return Vector3.new(p.X, hit and hit.Position.Y or self.ctx.Layout:HeightAt(p.X, p.Z), p.Z)
end

function SpiritService:RaisePillar(sh, instant)
	if sh.Pillar and sh.Pillar.Parent then
		return
	end
	local el = sh.Element
	local col = PILLAR_COLOR[el] or Color3.new(1, 1, 1)
	local pos = self:PillarPos(sh)
	local m = Instance.new("Model")
	m.Name = "ClearPillar_" .. el
	local rng = Random.new()
	-- ผลึกธาตุยักษ์ตรงกลาง + ผลึกเล็กล้อมรอบ (โมเดลผลึก Creator Store ชุดเดียวกับในแมพ)
	PropBuilder.DecoCrystal(CRYSTAL[el], pos - Vector3.new(0, 1, 0), rng:NextNumber(0, 6.28), 6.5, m)
	for k = 0, 6 do
		local ang = k / 7 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local q = pos + Vector3.new(math.cos(ang) * 13, -0.5, math.sin(ang) * 13)
		PropBuilder.DecoCrystal(CRYSTAL[el], q, rng:NextNumber(0, 6.28), rng:NextNumber(1.8, 2.8), m)
	end
	local _, size = m:GetBoundingBox()
	local core = Instance.new("Part")
	core.Name = "PillarCore"
	core.Anchored, core.CanCollide, core.CanQuery, core.CanTouch, core.Transparency = true, false, false, false, 1
	core.Size = Vector3.new(1, 1, 1)
	core.CFrame = CFrame.new(pos + Vector3.new(0, size.Y * 0.5, 0))
	core.Parent = m
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = col, 60, 3, false
	l.Parent = core
	local a0 = Instance.new("Attachment")
	a0.Parent = core
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 900, 0)
	a1.Parent = core
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Width0, beam.Width1 = 16, 34
	beam.LightEmission, beam.LightInfluence = 1, 0
	beam.FaceCamera = true
	beam.Segments = 2
	beam.Color = ColorSequence.new(col)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.7, 0.75), NumberSequenceKeypoint.new(1, 1) })
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureSpeed = 0.3
	beam.Enabled = instant == true -- ลำแสงยิงขึ้นฟ้าตอนเสาโผล่สุด
	beam.Parent = core
	local up = Instance.new("ParticleEmitter")
	up.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	up.Color = ColorSequence.new(col)
	up.LightEmission = 1
	up.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	up.Lifetime = NumberRange.new(2, 3.5)
	up.Speed = NumberRange.new(10, 22)
	up.SpreadAngle = Vector2.new(12, 12)
	up.Rate = 26
	up.Parent = core
	pcall(function()
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	m:SetAttribute("Element", el)
	m.Parent = sh.Model
	sh.Pillar = m
	if instant then
		return
	end
	-- ผุดขึ้นจากดิน 3 วิ + ฝุ่นฟุ้ง + เสียงครืน
	local final = m:GetPivot()
	local depth = size.Y + 2
	m:PivotTo(final - Vector3.new(0, depth, 0))
	local dust = Instance.new("Part")
	dust.Anchored, dust.CanCollide, dust.CanQuery, dust.CanTouch, dust.Transparency = true, false, false, false, 1
	dust.Size = Vector3.new(24, 1, 24)
	dust.CFrame = CFrame.new(pos)
	dust.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(180, 160, 130), col)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 16) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Speed = NumberRange.new(12, 26)
	e.SpreadAngle = Vector2.new(80, 80)
	e.Shape = Enum.ParticleEmitterShape.Disc
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.Rate = 40
	e.Parent = dust
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local k = math.clamp((os.clock() - t0) / 3.1, 0, 1)
		local eased = 1 - (1 - k) ^ 3
		if m.Parent then
			local jit = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.6 * (1 - k)
			m:PivotTo(final - Vector3.new(0, depth * (1 - eased), 0) + jit)
		end
		if k >= 1 then
			conn:Disconnect()
			if m.Parent then
				m:PivotTo(final)
			end
			e.Enabled = false
			beam.Enabled = true
			Debris:AddItem(dust, 3)
		end
	end)
end

function SpiritService:Rescue(a, player)
	local el = a.Info.Element
	local sh = self.shrines[el]
	if not sh or sh.Rescued then
		return
	end
	sh.Rescued = true
	local s = self.ctx.State
	s:SetAttribute("Spirit" .. el, true)
	self:LightOrb(el, a.Info)
	self:SpawnPet(sh)
	if not (sh.Pillar and sh.Pillar.Parent) then
		self:RaisePillar(sh, true)
	end
	local count = 0
	for _, e in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		if s:GetAttribute("Spirit" .. e) then
			count += 1
		end
	end
	s:SetAttribute("SpiritCount", count)
	-- +1 วัน เหมือนวางเตียง
	local skipped = self.ctx.Services.DirectorService:SkipDay(player, "🌟 ช่วย " .. a.Info.Thai .. " สำเร็จ — ข้ามไป 1 วัน! ตอนนี้วันที่ %d")
	self.ctx.FireRun("Cinematic", "SpiritRescued", { Element = el, Name = a.Info.Thai, Buff = BUFF_TEXT[el], Count = count, Day = skipped })
	for _, p in ipairs(Players:GetPlayers()) do
		self.ctx.Services.DataService:AddDiamonds(p, Classes.SpiritReward, "ช่วย " .. a.Info.Thai)
		if self.ctx.Services.QuestService then
			self.ctx.Services.QuestService:Progress(p, "Spirit", 1)
		end
	end
end

-- เก็บ/คืนสถานะ (RejoinService)
function SpiritService:Serialize()
	local s = self.ctx.State
	local out = { Spirits = {}, Lairs = {} }
	for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		out.Spirits[el] = s:GetAttribute("Spirit" .. el) == true or nil
		out.Lairs[el] = s:GetAttribute("Lair" .. el .. "Cleared") == true or nil
	end
	return out
end

function SpiritService:Restore(st)
	if type(st) ~= "table" then
		return
	end
	local s = self.ctx.State
	local count = 0
	for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		local sh = self.shrines[el]
		if type(st.Spirits) == "table" and st.Spirits[el] and sh then
			count += 1
			sh.Freed, sh.Rescued = true, true
			self:SealPortal(sh)
			if sh.Prompt then
				sh.Prompt.Enabled = false
			end
			local cage = sh.Model:FindFirstChild("Cage")
			if cage then
				cage:Destroy()
			end
			for _, g in ipairs(sh.Guardians or {}) do
				if g.Model and g.Model.Parent then
					g.Model:Destroy()
				end
			end
			sh.Guardians = {}
			sh.GuardiansSpawned = true
			s:SetAttribute("Spirit" .. el, true)
			local info = Animals.Data[Animals.Spirits[el]]
			if info then
				self:LightOrb(el, info)
			end
			self:SpawnPet(sh)
			self:RaisePillar(sh, true)
		end
		local lair = self.lairs[el]
		if type(st.Lairs) == "table" and st.Lairs[el] and lair then
			lair.Cleared = true
			lair.RespawnAt = os.clock() + LAIR_RESPAWN -- เวลาที่เหลือไม่ได้เก็บไว้ -> นับใหม่เต็ม 15 นาที
			s:SetAttribute("Lair" .. el .. "Cleared", true)
			local sigil = lair.Model:FindFirstChild("Sigil")
			if sigil then
				sigil.Color = Color3.fromRGB(255, 220, 120)
				sigil.Transparency = 0.3
			end
		end
	end
	s:SetAttribute("SpiritCount", count)
end

---------------------------------------------------------------- รังบอส
function SpiritService:SetupLair(model)
	local el = model:GetAttribute("Element")
	local spawnPart = model:FindFirstChild("BossSpawn")
	self.lairs[el] = { Model = model, Element = el, Pos = spawnPart and spawnPart.Position or model:GetPivot().Position, Cleared = false }
end

function SpiritService:WakeLair(lair, player)
	local info = Animals.Data[({ Earth = "Terragon", Water = "Leviathan", Air = "TempestRoc", Fire = "Solfang" })[lair.Element]]
	local id = ({ Earth = "Terragon", Water = "Leviathan", Air = "TempestRoc", Fire = "Solfang" })[lair.Element]
	local a = self.ctx.Services.AnimalService:Spawn(id, lair.Pos + Vector3.new(0, 2, 0), {
		Kind = "Guardian", Home = lair.Pos, Leash = 60, HealthMult = 0.7 * Nights.BossHealthMult(self.ctx.Services.SurvivalService:RunPlayerCount(true)),
	})
	if not a then
		return
	end
	a.Model:SetAttribute("IsBoss", true)
	a.Model:SetAttribute("Lair", lair.Element)
	self.ctx.Services.AnimalService:BeginIntro(a) -- ฉากเปิดตัว: ตรึงไว้ ~7 วิ
	lair.Boss = a
	lair.LastSeen = os.clock()
	local s = self.ctx.State
	s:SetAttribute("BossId", id)
	s:SetAttribute("BossHP", a.Hum.MaxHealth)
	s:SetAttribute("BossMaxHP", a.Hum.MaxHealth)
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r and (r.Position - lair.Pos).Magnitude < 300 then
			self.ctx.Remotes.Get("Cinematic"):FireClient(p, "BossIntro", { Model = a.Model, Id = id, Name = info.Name, Thai = info.Thai, Element = info.Element })
		end
	end
end

function SpiritService:OnBossKilled(a)
	local el = a.Model:GetAttribute("Lair")
	if not el then
		return
	end
	local lair = self.lairs[el]
	if not lair then
		return
	end
	lair.Cleared = true
	lair.Boss = nil
	lair.RespawnAt = os.clock() + LAIR_RESPAWN
	self.ctx.State:SetAttribute("Lair" .. el .. "Cleared", true)
	self.ctx.State:SetAttribute("Lair" .. el .. "RespawnAt", workspace:GetServerTimeNow() + LAIR_RESPAWN)
	local sigil = lair.Model:FindFirstChild("Sigil")
	if sigil then
		sigil.Color = Color3.fromRGB(255, 220, 120)
		sigil.Transparency = 0.3
	end
	self.ctx.Broadcast(string.format("💀 ปราบ %s แล้ว! บอสจะกลับมาเกิดใหม่ที่รังในอีก %d นาที", a.Info.Thai, LAIR_RESPAWN / 60), "Reward")
end

-- บอสในรังกลับมาเกิด (ครบเวลา): รังพร้อมปลุกอีกครั้งเมื่อมีคนเข้าใกล้
function SpiritService:RespawnLair(lair)
	lair.Cleared = false
	lair.RespawnAt = nil
	local el = lair.Element
	self.ctx.State:SetAttribute("Lair" .. el .. "Cleared", false)
	self.ctx.State:SetAttribute("Lair" .. el .. "RespawnAt", nil)
	local sigil = lair.Model:FindFirstChild("Sigil")
	if sigil then
		sigil.Color = require(ReplicatedStorage.Shared.PropBuilder).ElementColor[el]
		sigil.Transparency = 0.6
	end
	local id = ({ Earth = "Terragon", Water = "Leviathan", Air = "TempestRoc", Fire = "Solfang" })[el]
	local info = Animals.Data[id]
	self.ctx.Broadcast(string.format("⚠ %s ฟื้นคืนชีพที่รังแล้ว! (ดูแผนที่ M)", info and info.Thai or "บอส"), "Warn")
end

---------------------------------------------------------------- loop
function SpiritService:Tick()
	local animals = self.ctx.Services.AnimalService
	for el, sh in pairs(self.shrines) do
		if not sh.Freed then
			local p = nearestPlayer(sh.Base, 140)
			if p and not sh.GuardiansSpawned then
				self:SpawnGuardians(sh)
			end
			if sh.GuardiansSpawned and not sh.Prompt.Enabled then
				local alive = 0
				for _, g in ipairs(sh.Guardians) do
					if not g.Dead and g.Model.Parent then
						alive += 1
					end
				end
				if alive == 0 then
					sh.Prompt.Enabled = true
					self.ctx.Broadcast(string.format("🔓 ผนึกศาลเจ้า%s อ่อนลงแล้ว — กด E ค้างเพื่อปลดปล่อย", el), "Good")
				end
			end
			-- ไม่มีคนอยู่ใกล้นาน -> ผู้เฝ้ากลับไป (เกิดใหม่รอบหน้า)
			if sh.GuardiansSpawned and not p and not sh.Prompt.Enabled then
				sh.Away = (sh.Away or 0) + 1
				if sh.Away > 30 then
					for _, g in ipairs(sh.Guardians) do
						animals:Remove(g)
					end
					sh.GuardiansSpawned = false
					sh.Away = 0
				end
			else
				sh.Away = 0
			end
		end
	end
	for _, lair in pairs(self.lairs) do
		if lair.Cleared and lair.RespawnAt and os.clock() >= lair.RespawnAt then
			self:RespawnLair(lair)
		end
		if not lair.Cleared then
			local p = nearestPlayer(lair.Pos, 130)
			if p and not lair.Boss then
				self:WakeLair(lair, p)
			elseif lair.Boss then
				if lair.Boss.Dead then
					lair.Boss = nil
				elseif nearestPlayer(lair.Pos, 320) then
					lair.LastSeen = os.clock()
				elseif os.clock() - (lair.LastSeen or 0) > 40 then
					animals:Vanish(lair.Boss)
					lair.Boss = nil
					self.ctx.State:SetAttribute("BossId", "")
				end
			end
		end
	end
	-- บัฟวิญญาณไฟ: เผาศัตรูในเขตกองไฟ
	if self.ctx.State:GetAttribute("SpiritFire") then
		local safe = self.ctx.Services.CampService:SafeRadius()
		if safe > 0 then
			for _, a in ipairs(animals:InRadius(self.ctx.CampPosition, safe, true)) do
				self.ctx.Services.CombatService:DamageAnimal(a, 6, nil, { Silent = true, Burn = 4 })
			end
		end
	end
end

function SpiritService:Reset()
	local s = self.ctx.State
	for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		s:SetAttribute("Spirit" .. el, false)
		s:SetAttribute("Lair" .. el .. "Cleared", false)
	end
	s:SetAttribute("SpiritCount", 0)
	-- สร้างศาลเจ้าใหม่ (กรงกลับมา)
	local PropBuilder = require(ReplicatedStorage.Shared.PropBuilder)
	local sites = workspace.World.Sites
	for el, sh in pairs(self.shrines) do
		if sh.Pet then
			self.ctx.Services.AnimalService:Remove(sh.Pet) -- ลูกสัตว์ที่แคมป์ (มีคนขี่อยู่ = MountService คืนสภาพผู้ขี่เอง)
		end
		local sp = { Kind = "Shrine", Element = el, Position = sh.SitePos or sh.Base }
		sh.Model:Destroy()
		local m = PropBuilder.BuildShrine(sp, sites)
		self:SetupShrine(m)
	end
	for _, lair in pairs(self.lairs) do
		lair.Cleared = false
		lair.RespawnAt = nil
		s:SetAttribute("Lair" .. lair.Element .. "RespawnAt", nil)
		lair.Boss = nil
		local sigil = lair.Model:FindFirstChild("Sigil")
		if sigil then
			sigil.Color = require(ReplicatedStorage.Shared.PropBuilder).ElementColor[lair.Element]
			sigil.Transparency = 0.6
		end
	end
	-- ลบดวงวิญญาณที่เสาธง
	local camp = self.ctx.Services.CampService.campModel
	if camp then
		for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
			local orb = camp:FindFirstChild("SpiritOrb_" .. el)
			if orb then
				orb.Material = Enum.Material.Glass
				orb.Color = Color3.fromRGB(60, 60, 66)
				local l = orb:FindFirstChildOfClass("PointLight")
				if l then
					l:Destroy()
				end
			end
		end
	end
end

function SpiritService:Start(ctx)
	local s = ctx.State
	for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		s:SetAttribute("Spirit" .. el, false)
	end
	s:SetAttribute("SpiritCount", 0)
	for _, m in ipairs(CollectionService:GetTagged("Shrine")) do
		self:SetupShrine(m)
	end
	for _, m in ipairs(CollectionService:GetTagged("Lair")) do
		self:SetupLair(m)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(self.Tick, self)
			if not ok then
				warn("[AS] spirit tick", err)
			end
		end
	end)
end

return SpiritService
