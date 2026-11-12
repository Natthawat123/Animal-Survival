--[[
	AnimalService — เกิด/AI/ดาเมจ/ตาย ของสัตว์ทุกตัว
	Kind: "Wild" (สัตว์ป่ากลางวัน) | "Raid" (ฝูงบุกกลางคืน) | "Boss" | "Guardian" (เฝ้าศาลเจ้า/รังบอส)
	      | "Stalker" (จิ้งจอกจันทรา · ตัวไล่) | "Spirit" (ลูกสัตว์ธาตุ)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Animals = require(ReplicatedStorage.Shared.Animals)
local Nights = require(ReplicatedStorage.Shared.Nights)
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Items = require(ReplicatedStorage.Shared.Items)
local AnimalModels = require(ReplicatedStorage.Shared.AnimalModels)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Analytics = require(script.Parent.Analytics)
local BossAbilities = require(script.Parent.BossAbilities)

local AnimalService = {}
local active = {} -- [model] = data
local list = {} -- array สำหรับวนลูป
local CHARGE_WINDUP = 1.0 -- สายชน: ตั้งท่า + แถบเตือนบนพื้นก่อนพุ่ง (วินาที)
local LEAP_WINDUP = 0.55 -- สายตะครุบ: ย่อตัวเล็ง + แถบเตือนก่อนกระโจน

function AnimalService:Init(ctx)
	self.ctx = ctx
	self.folder = Instance.new("Folder")
	self.folder.Name = "Animals"
	self.folder.Parent = Workspace
	self.rng = Random.new(ctx.Seed + 555)
	self.wildCount = 0
	self.raidCount = 0
end

---------------------------------------------------------------- ค้นหา
function AnimalService:Get(model)
	return active[model]
end

function AnimalService:All()
	return list
end

local function hostile(a)
	return a.Kind ~= "Spirit" and a.Kind ~= "Stalker" and a.Info.Behaviour ~= "Passive"
end

function AnimalService:InRadius(pos, radius, hostileOnly)
	local out = {}
	for _, a in ipairs(list) do
		if not a.Dead and (not hostileOnly or hostile(a)) then
			if (a.Root.Position - pos).Magnitude <= radius + a.Radius then
				table.insert(out, a)
			end
		end
	end
	return out
end

function AnimalService:Nearest(pos, radius, hostileOnly)
	local best, bestD
	for _, a in ipairs(list) do
		if not a.Dead and (not hostileOnly or hostile(a)) then
			local d = (a.Root.Position - pos).Magnitude
			if d <= radius and (not bestD or d < bestD) then
				best, bestD = a, d
			end
		end
	end
	return best, bestD
end

function AnimalService:CountKind(kind)
	local n = 0
	for _, a in ipairs(list) do
		if a.Kind == kind and not a.Dead then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------- เกิด
function AnimalService:Spawn(id, position, opts)
	opts = opts or {}
	local info = Animals.Data[id]
	if not info or not Config.AnimalsEnabled then
		return nil
	end
	local model = AnimalModels.Build(id, { SizeMult = opts.SizeMult })
	if not model then
		return nil -- ยังไม่มีโมเดลของสัตว์ตัวนี้ (assets/rbxm/Animals/<Id>.rbxmx)
	end
	local root = model.PrimaryPart
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not opts.NoSnap then -- NoSnap: วางตรงจุดที่ให้มา (เช่นลูกสัตว์ในกรงบนลานศาลเจ้า)
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { workspace.Terrain }
		local hit = workspace:Raycast(position + Vector3.new(0, 120, 0), Vector3.new(0, -260, 0), rp)
		if hit and hit.Material ~= Enum.Material.Water then
			position = Vector3.new(position.X, hit.Position.Y + 0.2, position.Z)
		end
	end
	AnimalModels.PlaceAt(model, position, opts.Yaw or self.rng:NextNumber(0, math.pi * 2))
	-- (Monster Balance: PartyScale = x1 ตลอด · คนเยอะ = มอนมาเยอะขึ้นแทน) ตี้ยิ่งเยอะ มอนยิ่งโหด (Nights.PartyScale) · บอสคิดเลือดตามคนไว้แล้วใน DirectorService (BossHealthMult)
	local surv = self.ctx.Services.SurvivalService
	local partyScale = Nights.PartyScale(surv and surv:RunPlayerCount(true) or 1)
	local isBoss = opts.Kind == "Boss" or (opts.Kind == "Guardian" and info.Behaviour == "Boss")
	local healthMult = (opts.HealthMult or 1) * (isBoss and Config.BossHealthScale or partyScale.Health)
	local maxHp = (info.Health == math.huge) and 1e9 or info.Health * healthMult
	hum.MaxHealth = maxHp
	hum.Health = maxHp
	local speedMult = opts.SpeedMult or 1
	hum.WalkSpeed = (info.Speed or 16) * speedMult
	local kind = opts.Kind or "Wild"
	model:SetAttribute("Kind", kind)
	model:SetAttribute("MaxHealth", maxHp)
	model:SetAttribute("Health", maxHp)
	-- หลอดเลือด (บอส/ป้ายหัว) อ่านจาก attribute ของตัวมันเอง -> ตามเลือดจริงทุกครั้ง (โดนตี/ฟื้นตอนกลับถิ่น/ฮีล)
	hum.HealthChanged:Connect(function(h)
		if model.Parent then
			model:SetAttribute("Health", math.max(0, h))
		end
	end)
	if kind == "Boss" or kind == "Guardian" and info.Behaviour == "Boss" then
		model:SetAttribute("IsBoss", true)
	end
	model.Parent = self.folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local _, size = model:GetBoundingBox()
	local a = {
		Model = model, Id = id, Info = info, Hum = hum, Root = root, Kind = kind,
		Home = opts.Home or position, State = "Idle", Radius = math.max(size.X, size.Z) * 0.45,
		HealthMult = healthMult, SpeedMult = speedMult,
		-- ปรับความยากทั้งเกม (Config): มอนทั่วไป/บอส ตีเบาลง — ทุกท่า/สกิลบอสคูณ DamageMult ตัวนี้
		DamageMult = (opts.DamageMult or 1) * partyScale.Damage * (model:GetAttribute("IsBoss") and Config.BossDamageScale or Config.MonsterDamageScale),
		NextAttack = 0, NextThink = 0, NextAbility = os.clock() + Config.BossFirstSkill, LastPos = position, StuckSince = nil,
		Leash = opts.Leash or (kind == "Wild" and Config.WildLeash or nil), Night = opts.Night or 0,
	}
	if info.Aquatic then
		-- ลอยที่ผิวน้ำ (ครีบหลังโผล่) : ดันเฉพาะแกนตั้ง ไม่ให้ Humanoid ดำดิ่งลงก้นทะเล
		local att = Instance.new("Attachment")
		att.Name = "FloatAtt"
		att.Parent = root
		local float = Instance.new("AlignPosition")
		float.Name = "Float"
		float.Mode = Enum.PositionAlignmentMode.OneAttachment
		float.Attachment0 = att
		float.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		float.MaxAxesForce = Vector3.new(0, 1e6, 0)
		float.Responsiveness = 12
		float.Position = Vector3.new(0, self.ctx.Layout.WaterLevel + size.Y * 0.4, 0) -- ตัวจริงลอยปริ่มผิวน้ำ · ภาพจมลงครึ่งตัว (AnimalAnimator)
		float.Parent = root
	end
	if info.Behaviour == "Flyer" or info.Flying then
		self:SetupFlying(a)
	elseif info.Behaviour == "Boss" then
		-- บอสเดินพื้น: หมุนตัวเองหาผู้เล่นแบบนุ่มๆ (ไม่ใช่หันตามทางเดิน)
		hum.AutoRotate = false
		local att = Instance.new("Attachment")
		att.Name = "FaceAttachment"
		att.Parent = root
		local ao = Instance.new("AlignOrientation")
		ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
		ao.Attachment0 = att
		ao.MaxTorque = 1e9
		ao.Responsiveness = 7
		ao.CFrame = root.CFrame.Rotation
		ao.Parent = root
		a.FaceAlign = ao
	end
	active[model] = a
	table.insert(list, a)
	if kind == "Wild" then
		self.wildCount += 1
	elseif kind == "Raid" then
		self.raidCount += 1
	end
	hum.Died:Connect(function()
		if not a.Dead then
			self:Kill(a, a.LastAttacker)
		end
	end)
	return a
end

function AnimalService:SetupFlying(a)
	local hum, root = a.Hum, a.Root
	hum.PlatformStand = true
	local att = Instance.new("Attachment")
	att.Name = "FlyAttachment"
	att.Parent = root
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 1e7
	ap.MaxVelocity = (a.Info.Speed or 40) * a.SpeedMult
	ap.Responsiveness = 18
	ap.Position = root.Position + Vector3.new(0, 30, 0)
	ap.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	-- บอสบินตัวใหญ่มาก (มวลสูง): แรงหมุนต้องสูงพอ ไม่งั้นหันช้า/ไม่ทันหน้าตอนพ่นไฟ (วัดได้คลาด 80-137°)
	-- (บอสรังเกิดเป็น Kind "Guardian" -> ดูจากพฤติกรรม Boss ไม่ใช่ Kind — เคยพลาดจนมังกรในรังไม่หันหน้า)
	local isBoss = a.Info.Behaviour == "Boss"
	ao.MaxTorque = isBoss and 1e10 or 1e7
	ao.Responsiveness = isBoss and 9 or 12
	ao.CFrame = root.CFrame
	ao.Parent = root
	a.Align, a.Orient = ap, ao
	a.Flying = true
	a.OrbitAngle = self.rng:NextNumber(0, math.pi * 2)
	a.Model:SetAttribute("Flying", true)
end

function AnimalService:Remove(a)
	if a.Removed then
		return
	end
	a.Removed = true
	active[a.Model] = nil
	local idx = table.find(list, a)
	if idx then
		table.remove(list, idx)
	end
	if a.Kind == "Wild" then
		self.wildCount -= 1
	elseif a.Kind == "Raid" then
		self.raidCount -= 1
	end
	if a.Model.Parent then
		a.Model:Destroy()
	end
end

-- หายตัว (จางหาย) เช่น ตอนเช้า
function AnimalService:Vanish(a)
	if a.Dead or a.Removed then
		return
	end
	a.Dead = true
	a.Model:SetAttribute("Vanish", true)
	self.ctx.Remotes.Get("HitFx"):FireAllClients("Vanish", { Position = a.Root.Position })
	task.delay(1.2, function()
		self:Remove(a)
	end)
end

---------------------------------------------------------------- ดาเมจ / ตาย
function AnimalService:TakeDamage(a, amount, attacker, opts)
	if a.Dead or a.Kind == "Spirit" then
		return
	end
	opts = opts or {}
	if a.Kind == "Stalker" then
		if not opts.Silent then
			self.ctx.Remotes.Get("HitFx"):FireAllClients("Immune", { Position = a.Root.Position + Vector3.new(0, 4, 0) })
		end
		return
	end
	amount *= (1 - (a.Info.Armor or 0))
	local hum = a.Hum
	local hp = math.max(0, hum.Health - amount)
	if attacker then
		a.LastAttacker = attacker
		a.Provoked = attacker
		a.ProvokedUntil = os.clock() + 12
		if a.OnHurt then
			a.OnHurt(attacker)
		end
	end
	if opts.Burn and opts.Burn > 0 then
		a.Burn = opts.Burn
		a.BurnUntil = os.clock() + 4
		-- ไฟลุกบนตัวมอน (สีตามออร่าอาวุธ) · ส่งไม่เกินวิละครั้งต่อตัว (เครื่องลูกค้าต่อเวลาเอง)
		if not a.BurnFxAt or os.clock() - a.BurnFxAt > 1 then
			a.BurnFxAt = os.clock()
			self.ctx.Remotes.Get("HitFx"):FireAllClients("Burning", { Model = a.Model, Color = opts.BurnColor, Time = 4 })
		end
	end
	if opts.Slow then
		a.SlowUntil = os.clock() + 3
	end
	if a.Info.Behaviour == "Passive" then
		a.FleeUntil = os.clock() + 6
		a.FleeFrom = attacker and attacker.Character and attacker.Character:GetPivot().Position or a.Root.Position
	end
	-- กระเด็นเล็กน้อย (ตัวเล็ก)
	if opts.Knock and a.Radius < 3 and not a.Flying then
		a.Root.AssemblyLinearVelocity += opts.Knock * Vector3.new(1, 0, 1) * 22 + Vector3.new(0, 10, 0)
	end
	hum.Health = hp
	a.Model:SetAttribute("Health", hp)
	if not opts.Silent then
		self.ctx.Remotes.Get("HitFx"):FireAllClients("Hit", {
			Model = a.Model, Position = a.Root.Position, Amount = math.floor(amount + 0.5), Crit = opts.Crit, Mult = opts.Mult,
		})
	end
	if a.Kind == "Boss" or a.Model:GetAttribute("IsBoss") then
		self.ctx.State:SetAttribute("BossHP", hp)
	end
	if hp <= 0 then
		self:Kill(a, attacker)
	end
end

-- เตือนก่อนพุ่ง/ตะครุบ (ม่อนทั่วไป): client วาดแถบแนบพื้นจากตัวไปทิศ dir (BossFX "MobLine")
function AnimalService:DashTelegraph(a, dir, length, width, time)
	self.ctx.Remotes.Get("HitFx"):FireAllClients("BossTelegraph", {
		Shape = "MobLine", Pos = a.Root.Position, Dir = dir, Length = length, Width = width, Time = time, Element = a.Info.Element,
	})
end

function AnimalService:GiveDrops(a, player)
	-- ฝูงบุกแคมป์ตอนกลางคืน = ไม่ดรอปของ (กันของเฟ้อจากการตั้งรับ) · ไม่มีคนได้ของ = ไม่ดรอป
	if not player or a.Kind == "Raid" then
		return
	end
	local extra = self.ctx.Services.SurvivalService:Perk(player, "ExtraDrops", 0)
	-- ลดของเฟ้อ: สัตว์/มอนทั่วไปดรอปแค่ Config.AnimalDropMult ของตาราง (ปัดเศษแบบสุ่ม) · บอสได้ครบ (หัวใจธาตุห้ามหาย)
	local mult = a.Info.Behaviour == "Boss" and 1 or Config.AnimalDropMult
	local got = {}
	for _, d in ipairs(a.Info.Drops or {}) do
		local n = 0
		if d.Chance then
			-- Exact = โอกาส/จำนวนตามตารางเป๊ะ (ไม่คูณ AnimalDropMult และ LootMult) · Min/Max = จำนวนเมื่อดรอป (ไม่ใส่ = 1)
			if self.rng:NextNumber() < d.Chance * (d.Exact and 1 or mult) then
				n = d.Min and self.rng:NextInteger(d.Min, d.Max or d.Min) or 1
			end
		else
			local raw = self.rng:NextInteger(d.Min or 1, d.Max or 1) * mult
			n = math.floor(raw + self.rng:NextNumber())
		end
		if n > 0 and (d.Item == "Pelt" or d.Item == "RawMeat" or d.Item == "Bone" or d.Item == "Fiber") then
			n += extra
		end
		if n > 0 then
			if d.Exact then
				self.ctx.Services.DropService:Spawn(d.Item, n, a.Root.Position)
			else
				n = self.ctx.Services.DropService:SpawnLoot(d.Item, n, a.Root.Position)
			end
			if n > 0 then
				got[d.Item] = (got[d.Item] or 0) + n -- ช้างมีใย 2 แถว (ปกติ + โบนัส) -> รวมกัน
			end
		end
	end
	self.ctx.Remotes.Get("HitFx"):FireClient(player, "Loot", { Items = got, Position = a.Root.Position })
end

function AnimalService:Kill(a, attacker)
	if a.Dead then
		return
	end
	a.Dead = true
	local model = a.Model
	model:SetAttribute("Dead", true)
	model:SetAttribute("Health", 0)
	a.Hum.Health = 0
	if a.Align then
		a.Align.Enabled = false
		a.Orient.Enabled = false
	end
	local pos = a.Root.Position
	-- ผู้ได้ของ: คนตีล่าสุด หรือคนใกล้สุด
	local receiver = attacker
	if not (receiver and receiver.Parent) then
		receiver = a.LastAttacker -- ตายจากไฟ/ป้อม/กับดักหลังโดนคนตี = นับให้คนตีล่าสุด
	end
	if not (receiver and receiver.Parent) then
		local best
		for _, p in ipairs(Players:GetPlayers()) do
			local c = p.Character
			if c then
				local d = (c:GetPivot().Position - pos).Magnitude
				if d < 140 and (not best or d < best) then
					receiver, best = p, d
				end
			end
		end
	end
	local isBoss = model:GetAttribute("IsBoss")
	if isBoss then
		-- บอส: ของดรอปชุดเดียว (ตกที่ตัวบอส ใครเก็บก็ได้) · Ruby ให้ทุกคนในระยะ
		self:GiveDrops(a, receiver)
		for _, p in ipairs(Players:GetPlayers()) do
			local c = p.Character
			if c and (c:GetPivot().Position - pos).Magnitude < 260 then
				self.ctx.Services.DataService:AddDiamonds(p, Classes.BossReward[a.Info.Element] or 5, "Defeated " .. a.Info.Thai)
				local pd = self.ctx.Services.DataService:Get(p)
				if pd then
					pd.BossKills = (pd.BossKills or 0) + 1
					self.ctx.Services.DataService:CheckBadges(p)
				end
				Analytics.Custom(p, "BossDefeated", self.ctx.State:GetAttribute("Night") or 1, { a.Id, a.Kind, p:GetAttribute("Class") or "Survivor" })
				if self.ctx.Services.QuestService then
					self.ctx.Services.QuestService:Progress(p, "Boss", 1)
				end
			end
		end
		self.ctx.State:SetAttribute("BossId", "")
		self.ctx.FireRun("Cinematic", "BossFelled", { Name = a.Info.Name, Thai = a.Info.Thai, Element = a.Info.Element })
		self.ctx.Services.SpiritService:OnBossKilled(a)
	else
		self:GiveDrops(a, receiver)
	end
	if receiver then
		receiver:SetAttribute("Kills", (receiver:GetAttribute("Kills") or 0) + 1)
		local ds = self.ctx.Services.DataService
		local pd = ds:Get(receiver)
		if pd then
			pd.Kills = (pd.Kills or 0) + 1
		end
		ds:AddClassStat(receiver, "Kills", 1)
		-- แวมไพร์ (Blood Bite): ฆ่ามอนได้เลือดคืนตามสัดส่วนเลือดสูงสุด
		local surv = self.ctx.Services.SurvivalService
		local pct = surv:Perk(receiver, "KillHealPct", 0)
		local hum = pct > 0 and receiver.Character and receiver.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			surv:Heal(receiver, hum.MaxHealth * pct)
		end
		if self.ctx.Services.QuestService then
			self.ctx.Services.QuestService:Progress(receiver, "Kill", 1)
		end
	end
	self.ctx.Remotes.Get("HitFx"):FireAllClients("Death", { Model = model, Position = pos, Element = a.Info.Element, Boss = isBoss })
	task.delay(isBoss and 6 or 3, function()
		self:Remove(a)
	end)
	if a.OnDeath then
		task.spawn(a.OnDeath, a)
	end
end

---------------------------------------------------------------- เป้าหมาย
local function charRoot(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

function AnimalService:CampDistance(pos)
	local camp = self.ctx.CampPosition
	return ((pos - camp) * Vector3.new(1, 0, 1)).Magnitude
end

function AnimalService:PickTarget(a)
	local info = a.Info
	local surv = self.ctx.Services.SurvivalService
	local night = self.ctx.State:GetAttribute("Phase") == "Night"
	local aggro = (info.Aggro or 60) * ((night and a.Kind ~= "Wild") and 1.3 or 1) -- สัตว์ป่าไม่ตาไวขึ้นตอนกลางคืน
	if a.Kind == "Boss" or a.Kind == "Guardian" then
		aggro = math.max(aggro, 120)
	end
	local safe = self.ctx.Services.CampService:SafeRadius()
	local best, bestD
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r and surv:IsAlive(p) and not p:GetAttribute("Invisible") then -- ล่องหน (สกิลพ่อมดมืด) = มอนมองไม่เห็น
			local d = (r.Position - a.Root.Position).Magnitude
			local ok = d <= aggro or (a.Provoked == p and os.clock() < (a.ProvokedUntil or 0) and d < aggro * 2.5)
			if ok and a.Kind == "Wild" then
				-- สัตว์ป่าไม่เข้าเขตกองไฟ / คลาสผู้คุมอสูรไม่โดนโจมตีก่อน
				if self:CampDistance(r.Position) < safe + 20 then
					ok = false
				elseif surv:Perk(p, "WildPeace", false) and a.Provoked ~= p then
					ok = false
				elseif a.Ignore and a.Ignore[p] and os.clock() < a.Ignore[p] then
					ok = false -- เพิ่งเลิกไล่คนนี้
				end
			end
			if ok and a.Leash and (r.Position - a.Home).Magnitude > a.Leash + 40 then
				ok = false
			end
			if ok and (not bestD or d < bestD) then
				best, bestD = p, d
			end
		end
	end
	return best, bestD
end

---------------------------------------------------------------- การเคลื่อนที่
-- สัตว์น้ำ (Aquatic): จุดหมายบนบก -> ไล่จากจุดหมายกลับมาหาตัว หาจุดแรกที่ยังเป็นน้ำลึก (ว่ายวนชายฝั่ง ไม่ขึ้นบก)
function AnimalService:WaterPoint(a, pos)
	local layout = self.ctx.Layout
	local wl = layout.WaterLevel
	if layout:HeightAt(pos.X, pos.Z) < wl - 2 then
		return Vector3.new(pos.X, wl, pos.Z)
	end
	local from = a.Root.Position
	local d = (from - pos) * Vector3.new(1, 0, 1)
	local len = d.Magnitude
	if len > 1 then
		for t = 4, len, 4 do
			local q = pos + d.Unit * t
			if layout:HeightAt(q.X, q.Z) < wl - 2 then
				return Vector3.new(q.X, wl, q.Z)
			end
		end
	end
	return Vector3.new(from.X, wl, from.Z)
end

function AnimalService:MoveTo(a, pos, speedFactor)
	if a.Info.Aquatic then
		pos = self:WaterPoint(a, pos)
	end
	local hum = a.Hum
	local slow = (a.SlowUntil or 0) > os.clock() and 0.5 or 1
	hum.WalkSpeed = (a.Info.Speed or 16) * a.SpeedMult * (speedFactor or 1) * slow
	-- เดิน = ให้ Humanoid หันตามทางเดินเอง (นุ่ม) · ปิดตัวหมุนตอนยืน
	if a.Turn and a.Turn.Enabled then
		a.Turn.Enabled = false
		hum.AutoRotate = true
	end
	hum:MoveTo(pos)
	a.Moving = true
end

function AnimalService:Stop(a)
	a.Hum:MoveTo(a.Root.Position)
	a.Moving = false
end

function AnimalService:Face(a, pos)
	if a.Flying then
		return
	end
	local root = a.Root
	local flat = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
	if flat.Magnitude < 0.5 then
		return
	end
	if a.FaceAlign then
		a.FaceAlign.CFrame = CFrame.lookAt(Vector3.zero, flat)
		return
	end
	-- หันหาเป้าแบบค่อยๆ หมุน (เดิมตั้ง CFrame ทันทีทุกรอบคิด = ตัวกระตุก/วาปหันขวับ)
	if not a.Turn then
		local att = Instance.new("Attachment")
		att.Name = "TurnAttachment"
		att.Parent = root
		local ao = Instance.new("AlignOrientation")
		ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
		ao.Attachment0 = att
		ao.MaxTorque = 1e8
		ao.Responsiveness = 9
		ao.Enabled = false
		ao.Parent = root
		a.Turn = ao
	end
	a.Hum.AutoRotate = false
	a.Turn.CFrame = CFrame.lookAt(Vector3.zero, flat)
	a.Turn.Enabled = true
end

function AnimalService:Wander(a, now, radius, minRadius)
	if not a.WanderAt or now > a.WanderAt then
		a.WanderAt = now + self.rng:NextNumber(5, 11)
		if self.rng:NextNumber() < 0.35 then
			self:Stop(a)
			a.State = "Graze"
		else
			local ang = self.rng:NextNumber(0, math.pi * 2)
			local r = self.rng:NextNumber(minRadius or 10, math.max(radius or 50, (minRadius or 10) + 1))
			local p = a.Home + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
			local h, _, lava = self.ctx.Layout:HeightAt(p.X, p.Z)
			local wet = h < self.ctx.Layout.WaterLevel - 3
			if (a.Info.Aquatic and wet) or (not a.Info.Aquatic and (h > self.ctx.Layout.WaterLevel - 2 or a.Id == "Leviathan")) then
				if not lava or a.Info.Element == "Fire" then
					self:MoveTo(a, Vector3.new(p.X, h + 2, p.Z), 0.45)
					a.State = "Wander"
				end
			end
		end
	end
	a.Model:SetAttribute("State", a.State)
end

-- ติดอยู่กับที่ -> หาสิ่งก่อสร้างใกล้ๆ มาทุบ
function AnimalService:CheckStuck(a, now)
	local moved = (a.Root.Position - a.LastPos).Magnitude
	if moved > 2 then
		a.LastPos = a.Root.Position
		a.StuckSince = nil
		return nil
	end
	if not a.StuckSince then
		a.StuckSince = now
	end
	if now - a.StuckSince > 1.6 then
		a.Hum.Jump = true
		local best, bestD
		for _, s in ipairs(self.ctx.Services.BuildingService:All()) do
			local spec = Items.Structures[s:GetAttribute("Kind")]
			if spec and spec.Breakable and (s:GetAttribute("Health") or 0) > 0 then -- ตีเฉพาะกำแพง (ของอื่นพังไม่ได้ -> กระโดดข้ามแทน)
				local d = (s:GetPivot().Position - a.Root.Position).Magnitude
				if d < 18 + a.Radius and (not bestD or d < bestD) then
					best, bestD = s, d
				end
			end
		end
		return best
	end
	return nil
end

---------------------------------------------------------------- โจมตี
function AnimalService:MarkAttack(a, kind)
	a.Model:SetAttribute("AttackAt", Workspace:GetServerTimeNow())
	a.Model:SetAttribute("AttackKind", kind or "Bite")
end

-- กัด/ตะปบแบบหลบได้ (สไตล์ 99 Nights): หยุดยืน + ล็อกทิศ + แถบเตือนบนพื้น -> ง้าง BITE_WINDUP วิ -> ค่อยตัดสินโดน
--   โดนเฉพาะคนที่ยังอยู่ในระยะ (AttackRange + ตัว + BITE_SLACK) และอยู่ด้านหน้า (มุม ~70° จากทิศที่ล็อกไว้)
--   ถอยหลัง/หลบข้างตอนเห็นแถบเตือน = รอด · เดิม: ตัดสินหลัง 0.3 วิ ระยะ +3 ไม่ดูทิศ = แทบหลบไม่ได้
local BITE_SLACK = 1
local BITE_CONE = 0.35 -- dot ขั้นต่ำ (หน้า = 1)
function AnimalService:BiteWindup(a)
	if a.Info.BiteWindup then
		return a.Info.BiteWindup
	end
	if a.Kind == "Stalker" then
		return 0.45
	end
	return math.clamp(0.45 + a.Radius * 0.03, 0.45, 0.8) -- ตัวใหญ่ง้างนานกว่า
end

function AnimalService:Biting(a, now)
	return a.BiteUntil and now < a.BiteUntil
end

function AnimalService:AttackPlayer(a, player, now, trigger)
	if now < a.NextAttack or self:Biting(a, now) then
		return
	end
	local info = a.Info
	local r0 = charRoot(player)
	if not r0 then
		return
	end
	local windup = self:BiteWindup(a)
	a.NextAttack = now + windup + (info.AttackCooldown or 1.5)
	a.BiteUntil = now + windup + 0.15
	local d0 = (r0.Position - a.Root.Position) * Vector3.new(1, 0, 1)
	local dir = d0.Magnitude > 0.1 and d0.Unit or a.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
	-- ระยะโดน >= ระยะที่เริ่มง้าง + เผื่อ (กันง้างแล้ววืดทั้งที่คนยืนเฉย · ตัววิ่งเร็วไถเลยไปนิดหน่อยตอนหยุด)
	local reach = math.max((info.AttackRange or 6) + a.Radius, trigger or 0) + BITE_SLACK + 0.5
	self:Stop(a)
	self:Face(a, a.Root.Position + dir * 10)
	self:DashTelegraph(a, dir, reach, math.max(5, a.Radius * 1.6 + 3), windup)
	-- ท่ากัดฝั่งไคลเอนต์ใช้ ~0.3 วิถึงจังหวะงับ -> ส่ง AttackAt ให้ตรงจังหวะตัดสิน
	task.delay(math.max(windup - 0.3, 0), function()
		if not a.Dead then
			self:MarkAttack(a, "Bite")
		end
	end)
	task.delay(windup, function()
		if a.Dead or not a.Root.Parent then
			return
		end
		local origin = a.Root.Position
		local mult = a.Kind == "Stalker" and 1 or a.DamageMult -- จิ้งจอกจันทรา: ตีละ 15 เท่ากันทุกคืน
		for _, p in ipairs(Players:GetPlayers()) do
			local r = charRoot(p)
			if r then
				local to = (r.Position - origin) * Vector3.new(1, 0, 1)
				local dist = to.Magnitude
				local ahead = dist < 2 or to.Unit:Dot(dir) >= BITE_CONE
				if dist <= reach and ahead and math.abs(r.Position.Y - origin.Y) < 10 + a.Radius then
					local kb = info.Knockback and (dir * info.Knockback + Vector3.new(0, info.Knockback * 0.4, 0)) or nil
					self.ctx.Services.SurvivalService:Damage(p, (info.Damage or 5) * mult, a.Id, { Burn = info.Burn, Knockback = kb })
				end
			end
		end
	end)
end

function AnimalService:AttackStructure(a, s, now)
	if now < a.NextAttack then
		return
	end
	a.NextAttack = now + (a.Info.AttackCooldown or 1.5)
	self:Face(a, s:GetPivot().Position)
	self:MarkAttack(a, "Bite")
	task.delay(0.3, function()
		if not a.Dead and s.Parent then
			self.ctx.Services.BuildingService:Damage(s, (a.Info.Damage or 5) * (a.Info.StructureDamage or 1) * a.DamageMult)
		end
	end)
end

function AnimalService:AttackFire(a, now)
	if now < a.NextAttack then
		return
	end
	a.NextAttack = now + (a.Info.AttackCooldown or 1.5)
	self:Face(a, self.ctx.CampPosition)
	self:MarkAttack(a, "Bite")
	self.ctx.Services.CampService:DamageFire((a.Info.Damage or 5) * (a.Info.StructureDamage or 1) * 0.6 * a.DamageMult)
	self.ctx.Remotes.Get("HitFx"):FireAllClients("FireHit", { Position = self.ctx.CampPosition })
end

function AnimalService:Spit(a, target, now)
	if now < a.NextAttack then
		return
	end
	a.NextAttack = now + (a.Info.AttackCooldown or 2.4)
	local r = charRoot(target)
	if not r then
		return
	end
	self:Face(a, r.Position)
	self:MarkAttack(a, "Spit")
	local head = a.Model:FindFirstChild("Head") or a.Root
	local from = head.Position + Vector3.new(0, 1, 0)
	local t = math.clamp((r.Position - from).Magnitude / 60, 0.5, 1.6)
	local g = 60
	local lead = r.AssemblyLinearVelocity * Vector3.new(1, 0, 1) * t * 0.6
	local delta = (r.Position + lead) - from
	local vel = delta / t + Vector3.new(0, 0.5 * g * t, 0)
	local color = a.Info.Element == "Water" and Color3.fromRGB(80, 200, 255) or Color3.fromRGB(255, 120, 30)
	self.ctx.Services.CombatService:Projectile({
		From = from, Velocity = vel, Gravity = g, Radius = 3.5, Blast = 7, Damage = (a.Info.Damage or 10) * a.DamageMult,
		Owner = "Animal", Color = color, Size = 1.6, Burn = a.Info.Burn, Fire = a.Info.Element == "Fire", Source = a.Id,
	})
end

---------------------------------------------------------------- AI แต่ละแบบ
function AnimalService:ThinkPassive(a, now)
	if a.FleeUntil and now < a.FleeUntil then
		local away = (a.Root.Position - (a.FleeFrom or a.Root.Position)) * Vector3.new(1, 0, 1)
		if away.Magnitude < 0.1 then
			away = Vector3.new(self.rng:NextNumber(-1, 1), 0, self.rng:NextNumber(-1, 1))
		end
		self:MoveTo(a, a.Root.Position + away.Unit * 40, 1.1)
		a.State = "Flee"
		a.Model:SetAttribute("State", "Flee")
		return
	end
	-- ตกใจเมื่อคนเข้าใกล้
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r and (r.Position - a.Root.Position).Magnitude < (a.Info.Aggro or 30) * 0.45 then
			a.FleeUntil = now + 4
			a.FleeFrom = r.Position
			return
		end
	end
	self:Wander(a, now, 60)
end

function AnimalService:ThinkFlyer(a, now, target, dist)
	local layout = self.ctx.Layout
	local ap, ao = a.Align, a.Orient
	local pos = a.Root.Position
	local goal
	if a.DiveUntil and now < a.DiveUntil then
		goal = a.DivePos
		ap.MaxVelocity = (a.Info.Speed or 40) * a.SpeedMult * 1.6
		if target then
			local r = charRoot(target)
			if r and (r.Position - pos).Magnitude < (a.Info.AttackRange or 7) + a.Radius and not a.DiveHit then
				a.DiveHit = true
				self.ctx.Services.SurvivalService:Damage(target, (a.Info.Damage or 8) * a.DamageMult, a.Id)
			end
		end
	else
		ap.MaxVelocity = (a.Info.Speed or 40) * a.SpeedMult
		local center, radius, alt
		if target then
			local r = charRoot(target)
			center = r and r.Position or pos
			radius = a.Kind == "Boss" and 60 or 22
			alt = a.Kind == "Boss" and 55 or 26
			if now >= a.NextAttack and dist and dist < 120 then
				a.NextAttack = now + (a.Info.AttackCooldown or 2)
				a.DivePos = center
				a.DiveUntil = now + 1.1
				a.DiveHit = false
				self:MarkAttack(a, "Dive")
			end
		elseif a.Kind == "Raid" then
			center = self.ctx.CampPosition
			radius = 50
			alt = 30
			if self:CampDistance(pos) < 70 and now >= a.NextAttack then
				a.NextAttack = now + 3
				self.ctx.Services.CampService:DamageFire((a.Info.Damage or 8) * 0.5 * a.DamageMult)
				a.DivePos = self.ctx.CampPosition + Vector3.new(0, 4, 0)
				a.DiveUntil = now + 1
				a.DiveHit = true
				self:MarkAttack(a, "Dive")
			end
		else
			center = a.Home
			radius = 45
			alt = 40
		end
		a.OrbitAngle = (a.OrbitAngle or 0) + Config.AnimalThinkRate * (a.Info.Speed or 40) / math.max(radius, 10) * 0.6
		local ox, oz = math.cos(a.OrbitAngle) * radius, math.sin(a.OrbitAngle) * radius
		local ground = math.max(layout:HeightAt(center.X + ox, center.Z + oz), layout.WaterLevel)
		goal = Vector3.new(center.X + ox, math.max(center.Y, ground) + alt, center.Z + oz)
	end
	ap.Position = goal
	local dir = goal - pos
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude > 1 then
		-- หันตามทิศบิน แต่ไม่เชิด/ก้มเกิน ~20° (ตัวใหญ่ตั้งดิ่งแล้วดูแปลก)
		local pitch = math.clamp(math.atan2(dir.Y, flat.Magnitude), -0.35, 0.35)
		ao.CFrame = CFrame.lookAt(pos, pos + flat) * CFrame.Angles(pitch, 0, 0)
	end
end

-- บอส: ไม่เข้าตีประชิด — คุมระยะ หันหน้าหาผู้เล่นตลอด แล้วใช้สกิล (มีวงเตือนให้หลบ) วนไปทีละท่า
function AnimalService:FaceBoss(a, pos)
	local root = a.Root
	if a.CastFace then
		pos = root.Position + a.CastFace * 50 -- กำลังร่ายสกิลแนวตรง: หน้าล็อกตามทิศสกิล
	end
	local flat = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
	if flat.Magnitude < 1 then
		return
	end
	local look = CFrame.lookAt(Vector3.zero, flat)
	if a.FaceAlign then
		a.FaceAlign.CFrame = look
	elseif a.Orient then
		a.Orient.CFrame = look
	end
end

function AnimalService:ThinkBoss(a, now)
	local info = a.Info
	local target, dist = self:PickTarget(a)
	if not target then
		-- บอสไม่สนเขตปลอดภัยของกองไฟ: เล็งผู้เล่นที่ใกล้สุดในระยะ 200
		local surv = self.ctx.Services.SurvivalService
		for _, p in ipairs(Players:GetPlayers()) do
			local pr = charRoot(p)
			if pr and surv:IsAlive(p) then
				local d = (pr.Position - a.Root.Position).Magnitude
				if d < 200 and (not dist or d < dist) then
					target, dist = p, d
				end
			end
		end
	end
	local r = target and charRoot(target)
	local center = r and r.Position
	if not center then
		-- ไม่มีผู้เล่นในระยะ: เดินไปทางแคมป์แล้วยืนคุมเชิง (เฝ้าถิ่นถ้าเป็นบอสถ้ำ)
		if a.Leash then
			center = a.Home
		else
			center = self.ctx.CampPosition
		end
		dist = ((center - a.Root.Position) * Vector3.new(1, 0, 1)).Magnitude
	end
	local keep = 45 + a.Radius * 0.5
	if a.Flying then
		-- มังกร: บินวน (ต่ำ) <-> ร่อนลงสู้บนพื้น สลับกัน — ตอนลงพื้นเดินเข้าไปตีได้
		if not a.PhaseUntil then
			a.PhaseUntil = now + 11
			a.RootHeight = a.Root.Size.Y / 2 + a.Hum.HipHeight
		end
		if now >= a.PhaseUntil and not a.Casting then
			a.Grounded = not a.Grounded
			a.PhaseUntil = now + (a.Grounded and 14 or 11)
			a.Model:SetAttribute("Grounded", a.Grounded)
		end
		local ap = a.Align
		a.OrbitAngle = (a.OrbitAngle or 0) + Config.AnimalThinkRate * (a.Grounded and 0.06 or 0.22)
		local rad = a.Grounded and keep * 0.75 or keep + 10
		local gx, gz = center.X + math.cos(a.OrbitAngle) * rad, center.Z + math.sin(a.OrbitAngle) * rad
		local layout = self.ctx.Layout
		local floor = math.max(layout:HeightAt(gx, gz), layout.WaterLevel)
		local gy = a.Grounded and (floor + a.RootHeight) or (math.max(floor, center.Y) + 26)
		if ap and not a.Casting then
			ap.Position = Vector3.new(gx, gy, gz)
		end
		self:FaceBoss(a, center)
	else
		-- บอสเดินพื้น: ยืนคุมพื้นที่ หันหาผู้เล่น (ไม่ถอยหนี จะได้เข้าไปตีได้) เดินเข้าหาเมื่ออยู่ไกล
		self:FaceBoss(a, center)
		if a.Casting then
			self:Stop(a)
			a.State = "Cast"
		elseif dist > keep + 35 then
			self:MoveTo(a, center, 1)
			a.State = "Chase"
		else
			self:Stop(a)
			a.State = "Idle"
		end
	end
	-- สกิล (วนตามลำดับ · แต่ละท่าคูลดาวน์ของตัวเอง ยังไม่พร้อม = รอ)
	if r and not a.Casting and now >= a.NextAbility and dist < 170 then
		local ab = BossAbilities.Pick(a, info.Abilities or {})
		if ab then
			self:Stop(a)
			BossAbilities.Run(self.ctx, a, ab, target)
		end
	end
	a.Model:SetAttribute("State", a.State)
end

function AnimalService:ThinkHostile(a, now)
	local info = a.Info
	local b = info.Behaviour
	if b == "Boss" then
		return self:ThinkBoss(a, now)
	end
	local target, dist = self:PickTarget(a)
	local campMode = (a.Kind == "Raid") or (a.Kind == "Boss" and not a.Leash)
	-- สัตว์ป่า: ไล่ไม่ถึงตัวนานเกิน WildChaseTime = เลิกไล่คนนั้นสักพัก แล้วกลับถิ่น (ไม่ตามยาวจนถึงแคมป์)
	if target and a.Kind == "Wild" then
		local close = dist and dist <= (info.AttackRange or 6) + a.Radius + 3
		if a.ChaseTarget ~= target or close then
			a.ChaseTarget, a.ChaseSince = target, now
		elseif now - a.ChaseSince > Config.WildChaseTime then
			a.Ignore = a.Ignore or {}
			a.Ignore[target] = os.clock() + Config.WildGiveUpTime
			a.ChaseTarget = nil
			target, dist = nil, nil
		end
	end

	if a.Flying then
		return self:ThinkFlyer(a, now, target, dist)
	end

	-- กำลังง้างกัด: ยืนนิ่ง ทิศล็อก (ให้คนเห็นแถบเตือนแล้วหลบ)
	if self:Biting(a, now) then
		self:Stop(a)
		a.State = "Attack"
		a.Model:SetAttribute("State", "Attack")
		return
	end

	-- ตะครุบ: เล็งครบแล้วกระโจนไปทิศที่ล็อกไว้
	if a.LeapAt then
		if now < a.LeapAt then
			return
		end
		a.LeapAt = nil
		a.Root.AssemblyLinearVelocity = a.LeapDir * 42 + Vector3.new(0, 24, 0)
		self:MarkAttack(a, "Leap")
	end

	-- สายชน: ตั้งท่า -> พุ่ง -> พัก
	if a.State == "Windup" then
		if now >= a.StateUntil then
			a.State = "Charge"
			a.StateUntil = now + 1.3
			a.Model:SetAttribute("State", "Charge")
			local dir = a.ChargeDir
			a.ChargeStart = now
			self:MoveTo(a, a.Root.Position + dir * 50, 1.3)
		end
		return
	elseif a.State == "Charge" then
		do
			local ahead = a.Root.Position + a.ChargeDir * (a.Radius + 6)
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Include
			rp.FilterDescendantsInstances = { workspace.Terrain }
			local hit = workspace:Raycast(ahead + Vector3.new(0, 6, 0), Vector3.new(0, -18, 0), rp)
			if not hit or hit.Material == Enum.Material.Water then
				a.StateUntil = now -- จบพุ่งทันที
			end
		end
		local ramp = math.clamp((now - (a.ChargeStart or now)) / 0.5, 0, 1)
		a.Hum.WalkSpeed = (info.Speed or 16) * a.SpeedMult * (1.3 + 1.3 * ramp)
		for _, p in ipairs(Players:GetPlayers()) do
			local r = charRoot(p)
			if r and (r.Position - a.Root.Position).Magnitude < a.Radius + 4 and not a.ChargeHit[p] then
				a.ChargeHit[p] = true
				local kb = a.ChargeDir * (info.Knockback or 80) + Vector3.new(0, 40, 0)
				self.ctx.Services.SurvivalService:Damage(p, (info.Damage or 10) * a.DamageMult * 1.3, a.Id, { Knockback = kb })
			end
		end
		for _, s in ipairs(self.ctx.Services.BuildingService:All()) do
			if not a.ChargeHit[s] and (s:GetPivot().Position - a.Root.Position).Magnitude < a.Radius + 7 then
				a.ChargeHit[s] = true
				self.ctx.Services.BuildingService:Damage(s, (info.Damage or 10) * (info.StructureDamage or 1) * a.DamageMult * 1.5)
			end
		end
		if now >= a.StateUntil then
			a.State = "Recover"
			a.StateUntil = now + 1.2
			a.Model:SetAttribute("State", "Recover")
			self:Stop(a)
		end
		return
	elseif a.State == "Recover" then
		if now < a.StateUntil then
			return
		end
		a.State = "Chase"
	end

	-- บอส: ท่าพิเศษ
	if (b == "Boss") and target and not a.Casting and now >= a.NextAbility and dist and dist < 110 then
		local ab = BossAbilities.Pick(a, info.Abilities or {})
		if ab then
			BossAbilities.Run(self.ctx, a, ab, target)
			return
		end
	end

	if target then
		local r = charRoot(target)
		local reach = (info.AttackRange or 6) + a.Radius
		if b == "Spitter" then
			if dist < 22 then
				local away = (a.Root.Position - r.Position) * Vector3.new(1, 0, 1)
				self:MoveTo(a, a.Root.Position + away.Unit * 20, 1)
			elseif dist > (info.AttackRange or 60) * 0.8 then
				self:MoveTo(a, r.Position, 1)
			else
				self:Stop(a)
				self:Spit(a, target, now)
			end
			a.State = "Chase"
		elseif dist <= reach then
			self:Stop(a)
			self:Face(a, r.Position)
			self:AttackPlayer(a, target, now, reach)
			a.State = "Attack"
		elseif b == "Charger" and dist > 14 and dist < 30 and now >= a.NextAttack and now >= (a.NextCharge or 0) then
			a.NextCharge = now + (info.ChargeCooldown or 7)
			a.State = "Windup"
			a.StateUntil = now + CHARGE_WINDUP
			a.ChargeHit = {}
			local d = (r.Position - a.Root.Position) * Vector3.new(1, 0, 1)
			a.ChargeDir = d.Magnitude > 0.1 and d.Unit or a.Root.CFrame.LookVector
			a.NextAttack = now + (info.AttackCooldown or 2.4) + 1.3
			self:Stop(a)
			self:Face(a, r.Position)
			a.Model:SetAttribute("State", "Windup")
			self:MarkAttack(a, "Roar")
			-- แถบเตือนบนพื้น: ทางที่จะพุ่งผ่าน (ยาวตามความเร็วพุ่ง ไม่เกินระยะสั่งเดิน 50)
			self:DashTelegraph(a, a.ChargeDir, math.min(50, (info.Speed or 16) * a.SpeedMult * 3), a.Radius * 2 + 4, CHARGE_WINDUP)
			return
		else
			-- กระโดดตะครุบ
			if info.Leap and dist < 28 and dist > 10 and now >= (a.NextLeap or 0) then
				-- ย่อตัวเล็งก่อน LEAP_WINDUP วิ + แถบเตือน แล้วค่อยกระโจน (ทิศล็อกตอนเล็ง หลบได้)
				a.NextLeap = now + 4
				local d = (r.Position - a.Root.Position) * Vector3.new(1, 0, 1)
				a.LeapDir = d.Magnitude > 0.1 and d.Unit or a.Root.CFrame.LookVector
				a.LeapAt = now + LEAP_WINDUP
				self:Stop(a)
				self:Face(a, r.Position)
				self:DashTelegraph(a, a.LeapDir, math.clamp(d.Magnitude + 4, 10, 26), a.Radius * 2 + 3, LEAP_WINDUP)
				return
			end
			self:MoveTo(a, r.Position, 1)
			a.State = "Chase"
			local blocking = self:CheckStuck(a, now)
			if blocking then
				self:AttackStructure(a, blocking, now)
			end
		end
	elseif campMode then
		local dCamp = self:CampDistance(a.Root.Position)
		if dCamp < 13 + a.Radius then
			self:Stop(a)
			self:AttackFire(a, now)
			a.State = "Attack"
		else
			self:MoveTo(a, self.ctx.CampPosition, 1)
			a.State = "Raid"
			local blocking = self:CheckStuck(a, now)
			if blocking then
				self:AttackStructure(a, blocking, now)
			end
		end
	else
		-- เฝ้าถิ่น / เดินเล่น
		if a.Leash and (a.Root.Position - a.Home).Magnitude > a.Leash then
			self:MoveTo(a, a.Home, 1)
			a.State = "Return"
			a.Hum.Health = math.min(a.Hum.MaxHealth, a.Hum.Health + a.Hum.MaxHealth * 0.05)
			a.Model:SetAttribute("Health", a.Hum.Health)
		else
			self:Wander(a, now, a.Leash or 70)
		end
	end
	a.Model:SetAttribute("State", a.State)
end

-- ปีศาจจิ้งจอกจันทรา (ตัวไล่กลางคืน · ฆ่าไม่ตาย) — สไตล์กวางของ 99 Nights
--   ซ่อนตัว (หายไป) -> วาปโผล่ข้างหลังเหยื่อ (คนนอกแคมป์ ไกลกองไฟที่สุด) -> วิ่งไล่ + เสียงขู่คำราม -> กัด (ตีละ 15 · ง้างก่อน หลบได้)
--   เหยื่อถือไฟ / เข้าแคมป์ / ล่องหน / อยู่ใต้แสงตะเกียง = ไม่มีเหยื่อแล้ว -> เดินหนีออกไปแล้วหายตัว (ไม่ยืนเฝ้า)
--   หายแล้วพักสักครู่ -> คนออกมานอกแสงอีก = วาปไปหาแล้วไล่ใหม่ · เหยื่อไกลเกิน = หายแล้ววาปไปใหม่
local STALK_EDGE = 4 -- จิ้งจอกอยู่ห่างวงแคมป์อย่างน้อยเท่านี้
local STALK_SWITCH = 30 -- คนใหม่ต้องไกลกองไฟกว่าเป้าเดิมเท่านี้ ถึงจะเปลี่ยนเป้า
local STALK_WARP = { 34, 46 } -- ระยะโผล่จากเหยื่อ (ข้างหลังเหยื่อ ± มุมสุ่ม)
local STALK_REAPPEAR = 5 -- หายตัวแล้วอย่างน้อยกี่วิ ถึงจะวาปกลับมาได้
local STALK_RETREAT = 2.5 -- เดินหนีกี่วิก่อนหายตัว
local STALK_FAR = 150 -- เหยื่อไกลกว่านี้ = หายแล้ววาปไปหา
local STALK_FADE = 0.45 -- เวลาจางหาย (ฝั่งเครื่องผู้เล่น)
local STALK_VAULT = 800 -- ซ่อนไว้บนฟ้าสูงเท่านี้ (ใส + ยึดอยู่กับที่ · ไม่ใต้ดิน กันโดนลบตอนตกแมพ)
local CHASE_SOUND = "rbxassetid://9120788426" -- Wolf Growl 6 (ProSoundEffects) วนตอนไล่

function AnimalService:StalkerSound(a, on)
	local s = a.ChaseSound
	if not s or not s.Parent then
		s = Instance.new("Sound")
		s.Name = "ChaseGrowl"
		s.SoundId = CHASE_SOUND
		s.Looped = true
		s.Volume = 1.6
		s.PlaybackSpeed = 0.85
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 14
		s.RollOffMaxDistance = 160
		s.Parent = a.Root
		a.ChaseSound = s
	end
	if s.Playing ~= on then
		s.Playing = on
	end
end

function AnimalService:StalkerHide(a, now, wait)
	if a.Hidden then
		return
	end
	a.Hidden = true
	a.Retreating = nil
	a.ReappearAt = now + (wait or STALK_REAPPEAR)
	self:StalkerSound(a, false)
	self:Stop(a)
	a.Model:SetAttribute("Hidden", true)
	a.Model:SetAttribute("State", "Hidden")
	a.State = "Hidden"
	self.ctx.Remotes.Get("HitFx"):FireAllClients("StalkerFade", { Position = a.Root.Position })
	task.delay(STALK_FADE + 0.05, function()
		if a.Hidden and not a.Dead and a.Root.Parent then
			local p = a.Root.Position
			a.Root.AssemblyLinearVelocity = Vector3.zero
			a.Root.Anchored = true
			a.Model:PivotTo(CFrame.new(p.X, STALK_VAULT, p.Z) * a.Root.CFrame.Rotation)
		end
	end)
end

-- หาจุดโผล่: ข้างหลังเหยื่อ (ไม่เห็นตอนโผล่) บนพื้นดิน · ไม่ในน้ำ ไม่ในวงแคมป์ ไม่ใต้แสง
function AnimalService:StalkerWarpSpot(a, r, keepOut, lit)
	local look = r.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, 1)
	local base = math.atan2(-look.Z, -look.X) -- ข้างหลัง
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local camp = self.ctx.CampPosition
	for i = 1, 14 do
		local spread = i <= 6 and 1.1 or 2.6 -- ลองข้างหลังก่อน ไม่ได้ค่อยกว้างขึ้น
		local ang = base + self.rng:NextNumber(-spread, spread)
		local dist = self.rng:NextNumber(STALK_WARP[1], STALK_WARP[2])
		local x, z = r.Position.X + math.cos(ang) * dist, r.Position.Z + math.sin(ang) * dist
		local hit = workspace:Raycast(Vector3.new(x, r.Position.Y + 220, z), Vector3.new(0, -480, 0), rp)
		if hit and hit.Material ~= Enum.Material.Water then
			local pos = hit.Position
			local flat = ((pos - camp) * Vector3.new(1, 0, 1)).Magnitude
			if (keepOut <= 0 or flat > keepOut + 2) and not lit(pos) and math.abs(pos.Y - r.Position.Y) < 40 then
				return pos
			end
		end
	end
	return nil
end

function AnimalService:StalkerWarp(a, ground, prey, now)
	local r = charRoot(prey)
	local h = a.Root.Size.Y / 2 + a.Hum.HipHeight + 0.5
	local pos = ground + Vector3.new(0, h, 0)
	local face = r and Vector3.new(r.Position.X, pos.Y, r.Position.Z) or pos + Vector3.new(0, 0, 1)
	a.Model:PivotTo(CFrame.lookAt(pos, face))
	a.Root.AssemblyLinearVelocity = Vector3.zero
	a.Root.Anchored = false
	pcall(function()
		a.Root:SetNetworkOwner(nil)
	end)
	a.Hidden = nil
	a.Prey = prey
	a.LastPos, a.StuckSince, a.DetourUntil = pos, nil, nil
	a.NextAttack = math.max(a.NextAttack, now + 1) -- โผล่แล้วไม่กัดทันที
	a.Model:SetAttribute("Hidden", false)
	self.ctx.Remotes.Get("HitFx"):FireAllClients("StalkerWarp", { Position = ground, Prey = prey })
end

function AnimalService:ThinkStalker(a, now)
	local camp = self.ctx.CampPosition
	local cs = self.ctx.Services.CampService
	local zone = cs:SafeRadius() > 0 and cs:CampRadius() or 0 -- ไฟดับ = ไม่มีที่ปลอดภัย
	local lights = self.ctx.Services.BuildingService:LightSources()
	local surv = self.ctx.Services.SurvivalService
	local keepOut = zone > 0 and zone + STALK_EDGE or 0
	local function lit(pos)
		if zone > 0 and self:CampDistance(pos) < zone then
			return true
		end
		for _, l in ipairs(lights) do
			if (l[1] - pos).Magnitude < l[2] then
				return true
			end
		end
		return false
	end
	local function outside(pos)
		local flat = (pos - camp) * Vector3.new(1, 0, 1)
		if flat.Magnitude < keepOut then
			flat = flat.Magnitude > 0.5 and flat.Unit or Vector3.new(1, 0, 0)
			return Vector3.new(camp.X, pos.Y, camp.Z) + flat * keepOut
		end
		return pos
	end
	local function setState(st)
		if a.State ~= st then
			a.State = st
			a.Model:SetAttribute("State", st)
		end
	end
	-- เหยื่อที่ไล่ได้: ในรอบ · ยังรอด · ไม่ล่องหน · ไม่อยู่ใต้แสง/ในแคมป์ · ไม่ถือไฟ
	local function huntable(p)
		local r = charRoot(p)
		if not (r and p:GetAttribute("InRun") and surv:IsAlive(p) and not p:GetAttribute("Invisible") and not lit(r.Position)) then
			return nil
		end
		local _, tool = self.ctx.Services.CombatService.EquippedTool(p)
		if tool and tool.Light then
			return nil
		end
		return r
	end
	-- คนที่จิ้งจอกตัวอื่นจองไล่อยู่ (ไม่ได้กำลังเดินหนี) = ไม่แย่ง -> หลายตัวแยกกันไล่คนละคน
	local claimed = {}
	for _, o in ipairs(list) do
		if o ~= a and o.Kind == "Stalker" and not o.Dead and o.Prey and not o.Retreating then
			claimed[o.Prey] = true
		end
	end
	local function pickPrey()
		local best, bestD, preyD
		for _, p in ipairs(Players:GetPlayers()) do
			local r = not claimed[p] and huntable(p)
			if r then
				local d = self:CampDistance(r.Position)
				if p == a.Prey then
					preyD = d
				end
				if not bestD or d > bestD then
					best, bestD = p, d
				end
			end
		end
		if preyD and best ~= a.Prey and bestD - preyD < STALK_SWITCH then
			best = a.Prey -- ติดเป้าเดิมไว้ (กันสลับไปมา)
		end
		return best
	end

	-- 1) ซ่อนตัวอยู่: ครบเวลาพัก + มีเหยื่อนอกแสง = วาปไปข้างหลังเหยื่อ
	if a.Hidden then
		if now < (a.ReappearAt or 0) then
			return
		end
		local prey = pickPrey()
		local r = prey and charRoot(prey)
		if r then
			local spot = self:StalkerWarpSpot(a, r, keepOut, lit)
			if spot then
				self:StalkerWarp(a, spot, prey, now)
				setState("Hunt")
			end
		end
		return
	end
	if self:Biting(a, now) then
		self:Stop(a)
		return
	end
	-- 2) กำลังเดินหนี: ครบเวลา = หายตัว (ปล่อยเป้า ให้ตัวไหนว่างก็วาปไปหาได้)
	if a.Retreating then
		if now >= a.RetreatUntil then
			a.Prey = nil
			self:StalkerHide(a, now)
			return
		end
		local away = (a.Root.Position - a.RetreatFrom) * Vector3.new(1, 0, 1)
		away = away.Magnitude > 0.5 and away.Unit or a.Root.CFrame.LookVector * -1
		self:MoveTo(a, a.Root.Position + away * 30, 0.8)
		setState("Retreat")
		return
	end
	local function retreat(from)
		a.Retreating = true
		a.RetreatFrom = from
		a.RetreatUntil = now + STALK_RETREAT
		self:StalkerSound(a, false)
		setState("Retreat")
	end
	-- หลุดเข้าไปในวงแคมป์ (เช่น ไฟเพิ่งติดกลับ) = เดินออกแล้วหาย
	if zone > 0 and self:CampDistance(a.Root.Position) < zone then
		retreat(camp)
		return
	end

	-- 3) ไล่
	local prey = pickPrey()
	if not prey then
		-- เหยื่อเข้าแคมป์ / ถือไฟ / ทุกคนอยู่ในแสง: ไม่ยืนเฝ้า เดินหนีออกจากคนล่าสุดแล้วหายตัว
		local last = a.Prey and charRoot(a.Prey)
		retreat(last and last.Position or camp)
		return
	end
	if prey ~= a.Prey then
		a.Prey = prey
		a.StuckSince, a.DetourUntil = nil, nil
	end
	local r = charRoot(prey)
	local d = (r.Position - a.Root.Position).Magnitude
	if d > STALK_FAR then
		self:StalkerHide(a, now, 1.2) -- ไกลเกิน: หายแล้ววาปไปหาเลย
		return
	end
	setState("Hunt")
	self:StalkerSound(a, true)
	-- เลี่ยงสิ่งกีดขวางอยู่: วิ่งไปจุดข้าง ๆ ให้พ้นก่อน
	if a.DetourUntil and now < a.DetourUntil and d > 14 then
		self:MoveTo(a, a.DetourPos, 1.2)
		return
	end
	a.DetourUntil = nil
	-- ถึงระยะ + คูลดาวน์ครบ = ตี · คูลดาวน์อยู่ = วิ่งตามติดตัวต่อ
	local reach = (a.Info.AttackRange or 7) + a.Radius + 2
	if d < reach and now >= a.NextAttack then
		self:Stop(a)
		self:Face(a, r.Position)
		self:AttackPlayer(a, prey, now, reach)
		a.StuckSince = nil
		return
	end
	-- วิ่งนำหน้าเป้านิดหน่อย (ดักทางคนที่กำลังวิ่งหนี) · ไกล = เร่งตามทัน
	local lead = r.AssemblyLinearVelocity * Vector3.new(1, 0, 1) * math.clamp(d / 60, 0, 0.6)
	local mount = math.max(1, tonumber(prey:GetAttribute("MountSpeed")) or 1) -- ขี่สัตว์อยู่ = เร็วตามพาหนะ (+5%)
	self:MoveTo(a, outside(r.Position + lead), (d > 50 and 1.3 or 1.1) * (mount > 1 and mount * 1.05 or 1))
	-- ติด: ไม่ขยับเลยทั้งที่ยังไกลเป้า -> กระโดด · ติดนาน -> เลี่ยงไปข้าง ๆ 1.2 วิ
	if (a.Root.Position - (a.LastPos or a.Root.Position)).Magnitude > 2 then
		a.LastPos = a.Root.Position
		a.StuckSince = nil
	elseif d > reach * 1.8 then
		a.StuckSince = a.StuckSince or now
		if now - a.StuckSince > 0.8 then
			a.Hum.Jump = true
		end
		if now - a.StuckSince > 1.6 then
			local to = (r.Position - a.Root.Position) * Vector3.new(1, 0, 1)
			to = to.Magnitude > 0.1 and to.Unit or a.Root.CFrame.LookVector
			local side = Vector3.new(-to.Z, 0, to.X) * (self.rng:NextNumber() < 0.5 and -1 or 1)
			a.DetourPos = outside(a.Root.Position + side * 14 - to * 4)
			a.DetourUntil = now + 1.2
			a.StuckSince = nil
		end
	end
end

-- ลูกสัตว์ที่ช่วยแล้ว: เดินเล่นในเขตแคมป์เอง (ไม่ตามใคร) · หลุดไปไกล (ลงจากหลังนอกแคมป์) = เดินกลับบ้าน
function AnimalService:ThinkPet(a, now)
	if a.Rider then
		return
	end
	-- ลงจากหลังที่ไหน = รอตรงนั้น (เดินเล่นวงแคบรอบจุดเดิม ไม่กลับบ้านเอง)
	if a.StayAt then
		a.Home = a.StayAt
		if ((a.Root.Position - a.StayAt) * Vector3.new(1, 0, 1)).Magnitude > 14 then
			self:MoveTo(a, a.StayAt, 0.6)
			a.State = "Return"
		else
			self:Wander(a, now, 6, 2)
		end
		a.Model:SetAttribute("State", a.State)
		return
	end
	local camp = self.ctx.CampPosition
	local radius = math.max(self.ctx.Services.CampService:CampRadius() - 12, 24)
	local d = ((a.Root.Position - camp) * Vector3.new(1, 0, 1)).Magnitude
	if d > 400 then
		a.Model:PivotTo(CFrame.new(camp + Vector3.new(radius * 0.5, self.ctx.Layout:HeightAt(camp.X + radius * 0.5, camp.Z) - camp.Y + 4, 0)))
		return
	elseif d > radius + 6 then
		self:MoveTo(a, Vector3.new(camp.X, a.Root.Position.Y, camp.Z), 0.7)
		a.State = "Return"
		a.WanderAt = now + 3
	else
		a.Home = camp
		self:Wander(a, now, radius, 18) -- ไม่เข้าใกล้กองไฟเกิน 18 stud
	end
	a.Model:SetAttribute("State", a.State)
end

-- ฉากเปิดตัวบอส: ตรึงไว้ที่จุดเกิด ~7 วิ (เครื่องผู้เล่นขยับตัวบอสเล่นฉากเอง) แล้วปล่อยสู้
--   โมเดลส่งถึงทุกเครื่องเสมอ (Persistent) -> ฉากไม่หลุดเพราะบอสยังโหลดมาไม่ถึง
AnimalService.IntroTime = 7.2
function AnimalService:BeginIntro(a)
	pcall(function()
		a.Model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	a.IntroUntil = os.clock() + AnimalService.IntroTime
	a.Root.Anchored = true
	a.Root.AssemblyLinearVelocity = Vector3.zero
	a.Model:SetAttribute("Intro", true)
	task.delay(AnimalService.IntroTime, function()
		if a.Root.Parent and not a.Dead then
			a.Root.Anchored = false
			a.Model:SetAttribute("Intro", false)
		end
	end)
end

function AnimalService:Think(a, now)
	if a.Dead or a.Removed or not a.Model.Parent then
		return
	end
	if a.IntroUntil and os.clock() < a.IntroUntil then
		return -- ฉากเปิดตัวบอส / ผู้เฝ้าศาลเจ้าเดินตามบท: ไม่คิดเอง
	end
	if a.Rider then
		return -- มีคนขี่อยู่ (ตัวติดกับผู้ขี่ ห้ามย้าย/ดึงลงพื้นเอง)
	end
	if a.Hidden then
		return self:ThinkStalker(a, now) -- จิ้งจอกซ่อนตัวบนฟ้า: ข้ามเช็กพื้น/ตกแมพ
	end
	-- ไฟไหม้
	if a.BurnUntil and now < a.BurnUntil then
		self:TakeDamage(a, (a.Burn or 3) * Config.AnimalThinkRate, nil, { Silent = true, Source = "Burn" })
		if a.Dead then
			return
		end
	end
	-- พิษ (สกิลพงไพร): เสียเลือดเป็นสัดส่วนของเลือดสูงสุด
	if a.PoisonUntil and now < a.PoisonUntil then
		self:TakeDamage(a, a.Hum.MaxHealth * (a.PoisonPct or 0.01) * Config.AnimalThinkRate, a.PoisonBy, { Silent = true, Source = "Poison" })
		if a.Dead then
			return
		end
	end
	-- สตั้น (สกิลพงไพร): ยืนนิ่ง ไม่โจมตี
	if a.StunUntil and now < a.StunUntil then
		self:Stop(a)
		return
	end
	-- ตกน้ำลึก/หลุดแมพ
	if a.Root.Position.Y < -120 then
		self:Remove(a)
		return
	end
	-- (บอสในรังเกิดเป็น Guardian: ห้ามดึงขึ้นผิวดิน — เคยดึงเยติจากพื้นวังน้ำแข็งขึ้นไปค้างบนหลังคา/ตกฐาน)
	if not a.Flying and a.Info.Behaviour ~= "Boss" and now >= (a.NextGroundCheck or 0) then
		a.NextGroundCheck = now + 1
		local p = a.Root.Position
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { workspace.Terrain }
		local below = workspace:Raycast(p, Vector3.new(0, -40, 0), rp)
		local surface = not below and workspace:Raycast(p + Vector3.new(0, 150, 0), Vector3.new(0, -150, 0), rp)
		if surface and surface.Material ~= Enum.Material.Water and surface.Position.Y > p.Y + 1 then
			a.Root.AssemblyLinearVelocity = Vector3.zero
			a.Model:PivotTo(CFrame.new(p.X, surface.Position.Y + a.Root.Size.Y / 2 + a.Hum.HipHeight + 0.5, p.Z) * a.Root.CFrame.Rotation)
		end
	end
	if a.Kind == "Spirit" then
		if a.Pet then
			self:ThinkPet(a, now)
		end
		return
	elseif a.Kind == "Stalker" then
		return self:ThinkStalker(a, now)
	elseif a.Info.Behaviour == "Passive" then
		return self:ThinkPassive(a, now)
	end
	self:ThinkHostile(a, now)
end

---------------------------------------------------------------- สัตว์ป่า (กลางวัน)
local WILD_GAP = 55 -- สัตว์ป่าตัวใหม่เกิดห่างจากตัวอื่นอย่างน้อยเท่านี้ (stud)
function AnimalService:SpawnWildNear(player)
	local r = charRoot(player)
	if not r then
		return
	end
	local layout = self.ctx.Layout
	for _ = 1, 6 do
		local ang = self.rng:NextNumber(0, math.pi * 2)
		local d = self.rng:NextNumber(Config.WildSpawnRadius.Min, Config.WildSpawnRadius.Max)
		local x, z = r.Position.X + math.cos(ang) * d, r.Position.Z + math.sin(ang) * d
		if math.abs(x) < layout.Half - layout.EdgeOcean and math.abs(z) < layout.Half - layout.EdgeOcean then
			local h, biome, lava = layout:HeightAt(x, z)
			local campD = math.sqrt(x * x + z * z)
			-- กระจายตัว: ไม่เกิดซ้อนใกล้สัตว์ป่าตัวอื่น (เดิมเกิดกระจุกเป็นก้อน)
			local crowded = false
			for _, o in ipairs(list) do
				if o.Kind == "Wild" and not o.Dead and o.Root and ((o.Root.Position - Vector3.new(x, o.Root.Position.Y, z)).Magnitude < WILD_GAP) then
					crowded = true
					break
				end
			end
			if h > layout.WaterLevel + 1 and not lava and campD > 150 and not crowded then
				local weights = Biomes.Data[biome].Wild
				if weights then
					local total = 0
					for _, w in pairs(weights) do
						total += w
					end
					local pick = self.rng:NextNumber() * total
					for id, w in pairs(weights) do
						pick -= w
						if pick <= 0 then
							local info = Animals.Data[id]
							if info.Aquatic then
								-- สัตว์น้ำ: หาน้ำลึกใกล้จุดนี้ (ชายฝั่ง) แล้วเกิดที่ผิวน้ำ
								for _ = 1, 14 do
									local a2 = self.rng:NextNumber(0, math.pi * 2)
									local d2 = self.rng:NextNumber(20, 110)
									local wx, wz = x + math.cos(a2) * d2, z + math.sin(a2) * d2
									if layout:HeightAt(wx, wz) < layout.WaterLevel - 5 then
										self:Spawn(id, Vector3.new(wx, layout.WaterLevel + 1, wz), { Kind = "Wild" })
										break
									end
								end
								return
							end
							local count = info.Pack and self.rng:NextInteger(info.Pack[1], info.Pack[2]) or 1
							local base = self.rng:NextNumber(0, math.pi * 2)
							for i = 1, count do
								-- ฝูง: ยืนห่างกันเป็นวง 8-18 stud (ไม่เบียดกันเป็นก้อนเดียว)
								local pa = base + (i / count) * math.pi * 2 + self.rng:NextNumber(-0.4, 0.4)
								local pr = count > 1 and self.rng:NextNumber(8, 18) or 0
								local off = Vector3.new(math.cos(pa) * pr, 0, math.sin(pa) * pr)
								local pos = Vector3.new(x, h, z) + off
								local hh = layout:HeightAt(pos.X, pos.Z)
								self:Spawn(id, Vector3.new(pos.X, hh + 1, pos.Z), { Kind = "Wild" })
							end
							return
						end
					end
				end
			end
		end
	end
end

function AnimalService:WildTick()
	local players = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InRun") then
			table.insert(players, p)
		end
	end
	if #players == 0 then
		return
	end
	-- ลบสัตว์ป่าที่ไกลจากทุกคน
	for i = #list, 1, -1 do
		local a = list[i]
		if a and a.Kind == "Wild" and not a.Dead then
			local near = false
			for _, p in ipairs(players) do
				local r = charRoot(p)
				if r and (r.Position - a.Root.Position).Magnitude < Config.WildDespawnRadius then
					near = true
					break
				end
			end
			if not near then
				self:Remove(a)
			end
		end
	end
	local phase = self.ctx.State:GetAttribute("Phase")
	-- เพดานสัตว์ป่าเพิ่มเล็กน้อยตามจำนวนคนในรอบ (1 คน = x1.0 · +10% ต่อคน สูงสุด x1.6)
	local cap = Config.MaxWildAnimals * (phase == "Night" and 0.4 or 1) * math.min(1 + 0.1 * (#players - 1), 1.6)
	if self.wildCount < cap then
		local p = players[self.rng:NextInteger(1, #players)]
		local r = charRoot(p)
		if r and self:CampDistance(r.Position) > 60 then
			self:SpawnWildNear(p)
		elseif r and self.wildCount < cap * 0.3 then
			self:SpawnWildNear(p)
		end
	end
end

---------------------------------------------------------------- ลูป
function AnimalService:ClearKind(kind, vanish)
	for i = #list, 1, -1 do
		local a = list[i]
		if a and (not kind or a.Kind == kind) then
			if vanish then
				self:Vanish(a)
			else
				self:Remove(a)
			end
		end
	end
end

function AnimalService:Start(ctx)
	local rate = Config.AnimalThinkRate
	local idx = 1
	-- กระจายการคิดให้แต่ละเฟรมทำบางตัว
	RunService.Heartbeat:Connect(function(dt)
		local n = #list
		if n == 0 then
			return
		end
		local perFrame = math.max(1, math.ceil(n * dt / rate))
		local now = os.clock()
		for _ = 1, perFrame do
			if idx > #list then
				idx = 1
			end
			local a = list[idx]
			idx += 1
			if a then
				local ok, err = pcall(self.Think, self, a, now)
				if not ok then
					warn("[AS] AI error", a.Id, err)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(2.5)
			local ok, err = pcall(self.WildTick, self)
			if not ok then
				warn("[AS] wild tick", err)
			end
		end
	end)
end

return AnimalService
