--[[
	AnimalService — เกิด/AI/ดาเมจ/ตาย ของสัตว์ทุกตัว
	Kind: "Wild" (สัตว์ป่ากลางวัน) | "Raid" (ฝูงบุกกลางคืน) | "Boss" | "Guardian" (เฝ้าศาลเจ้า/รังบอส)
	      | "Stalker" (กวางกลวง) | "Spirit" (ลูกสัตว์ธาตุ)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Animals = require(ReplicatedStorage.Shared.Animals)
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Items = require(ReplicatedStorage.Shared.Items)
local AnimalModels = require(ReplicatedStorage.Shared.AnimalModels)
local Classes = require(ReplicatedStorage.Shared.Classes)
local BossAbilities = require(script.Parent.BossAbilities)

local AnimalService = {}
local active = {} -- [model] = data
local list = {} -- array สำหรับวนลูป

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
	local model = AnimalModels.Build(id)
	if not model then
		return nil -- ยังไม่มีโมเดลของสัตว์ตัวนี้ (assets/rbxm/Animals/<Id>.rbxmx)
	end
	local root = model.PrimaryPart
	local hum = model:FindFirstChildOfClass("Humanoid")
	AnimalModels.PlaceAt(model, position, opts.Yaw or self.rng:NextNumber(0, math.pi * 2))
	local healthMult = opts.HealthMult or 1
	local maxHp = (info.Health == math.huge) and 1e9 or info.Health * healthMult
	hum.MaxHealth = maxHp
	hum.Health = maxHp
	local speedMult = opts.SpeedMult or 1
	hum.WalkSpeed = (info.Speed or 16) * speedMult
	local kind = opts.Kind or "Wild"
	model:SetAttribute("Kind", kind)
	model:SetAttribute("MaxHealth", maxHp)
	model:SetAttribute("Health", maxHp)
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
		HealthMult = healthMult, DamageMult = opts.DamageMult or 1, SpeedMult = speedMult,
		NextAttack = 0, NextThink = 0, NextAbility = os.clock() + 6, LastPos = position, StuckSince = nil,
		Leash = opts.Leash, Night = opts.Night or 0,
	}
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
	ao.MaxTorque = 1e7
	ao.Responsiveness = 12
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
	end
	if opts.Burn and opts.Burn > 0 then
		a.Burn = opts.Burn
		a.BurnUntil = os.clock() + 4
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

function AnimalService:GiveDrops(a, player)
	if not player then
		return
	end
	local extra = self.ctx.Services.SurvivalService:Perk(player, "ExtraDrops", 0)
	local got = {}
	for _, d in ipairs(a.Info.Drops or {}) do
		local n = 0
		if d.Chance then
			if self.rng:NextNumber() < d.Chance then
				n = 1
			end
		else
			n = self.rng:NextInteger(d.Min or 1, d.Max or 1)
		end
		if n > 0 and (d.Item == "Pelt" or d.Item == "RawMeat") then
			n += extra
		end
		if n > 0 then
			self.ctx.Services.DropService:Spawn(d.Item, n, a.Root.Position)
			got[d.Item] = n
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
		-- บอส: ทุกคนในระยะได้ของ + เพชร
		for _, p in ipairs(Players:GetPlayers()) do
			local c = p.Character
			if c and (c:GetPivot().Position - pos).Magnitude < 260 then
				self:GiveDrops(a, p)
				self.ctx.Services.DataService:AddDiamonds(p, Classes.BossReward, "ปราบ " .. a.Info.Thai)
				local pd = self.ctx.Services.DataService:Get(p)
				if pd then
					pd.BossKills = (pd.BossKills or 0) + 1
					self.ctx.Services.DataService:CheckBadges(p)
				end
			end
		end
		self.ctx.State:SetAttribute("BossId", "")
		self.ctx.Remotes.Get("Cinematic"):FireAllClients("BossFelled", { Name = a.Info.Name, Thai = a.Info.Thai, Element = a.Info.Element })
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
	local aggro = (info.Aggro or 60) * (night and 1.3 or 1)
	if a.Kind == "Boss" or a.Kind == "Guardian" then
		aggro = math.max(aggro, 120)
	end
	local safe = self.ctx.Services.CampService:SafeRadius()
	local best, bestD
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r and surv:IsAlive(p) then
			local d = (r.Position - a.Root.Position).Magnitude
			local ok = d <= aggro or (a.Provoked == p and os.clock() < (a.ProvokedUntil or 0) and d < aggro * 2.5)
			if ok and a.Kind == "Wild" then
				-- สัตว์ป่าไม่เข้าเขตกองไฟ / คลาสผู้คุมอสูรไม่โดนโจมตีก่อน
				if self:CampDistance(r.Position) < safe + 20 then
					ok = false
				elseif surv:Perk(p, "WildPeace", false) and a.Provoked ~= p then
					ok = false
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
function AnimalService:MoveTo(a, pos, speedFactor)
	local hum = a.Hum
	local slow = (a.SlowUntil or 0) > os.clock() and 0.5 or 1
	hum.WalkSpeed = (a.Info.Speed or 16) * a.SpeedMult * (speedFactor or 1) * slow
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
	local flat = Vector3.new(pos.X, root.Position.Y, pos.Z)
	if (flat - root.Position).Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

function AnimalService:Wander(a, now, radius)
	if not a.WanderAt or now > a.WanderAt then
		a.WanderAt = now + self.rng:NextNumber(5, 11)
		if self.rng:NextNumber() < 0.35 then
			self:Stop(a)
			a.State = "Graze"
		else
			local ang = self.rng:NextNumber(0, math.pi * 2)
			local r = self.rng:NextNumber(10, radius or 50)
			local p = a.Home + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
			local h, _, lava = self.ctx.Layout:HeightAt(p.X, p.Z)
			if h > self.ctx.Layout.WaterLevel - 2 or a.Id == "RiptideCroc" or a.Id == "Leviathan" then
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
			if (s:GetAttribute("Health") or 0) > 0 then
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

function AnimalService:AttackPlayer(a, player, now)
	if now < a.NextAttack then
		return
	end
	local info = a.Info
	a.NextAttack = now + (info.AttackCooldown or 1.5)
	self:MarkAttack(a, "Bite")
	task.delay(0.3, function()
		if a.Dead then
			return
		end
		local r = charRoot(player)
		if r and (r.Position - a.Root.Position).Magnitude <= (info.AttackRange or 6) + a.Radius + 3 then
			local dir = ((r.Position - a.Root.Position) * Vector3.new(1, 0, 1))
			dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, 1)
			local kb = info.Knockback and (dir * info.Knockback + Vector3.new(0, info.Knockback * 0.4, 0)) or nil
			self.ctx.Services.SurvivalService:Damage(player, (info.Damage or 5) * a.DamageMult, a.Id, { Burn = info.Burn, Knockback = kb })
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
	-- สกิล (วนตามลำดับ ไม่ซ้ำท่าเดิมติดกัน)
	if r and not a.Casting and now >= a.NextAbility and dist < 170 then
		local abilities = info.Abilities or {}
		if #abilities > 0 then
			a.AbilityIndex = (a.AbilityIndex or 0) % #abilities + 1
			a.NextAbility = now + self.rng:NextNumber(4.5, 6.5)
			self:Stop(a)
			BossAbilities.Run(self.ctx, a, abilities[a.AbilityIndex], target)
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

	if a.Flying then
		return self:ThinkFlyer(a, now, target, dist)
	end

	-- สายชน: ตั้งท่า -> พุ่ง -> พัก
	if a.State == "Windup" then
		if now >= a.StateUntil then
			a.State = "Charge"
			a.StateUntil = now + 1.3
			a.Model:SetAttribute("State", "Charge")
			local dir = a.ChargeDir
			self:MoveTo(a, a.Root.Position + dir * 50, 2.6)
		end
		return
	elseif a.State == "Charge" then
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
	if (b == "Boss") and target and now >= a.NextAbility and dist and dist < 110 then
		a.NextAbility = now + self.rng:NextNumber(7, 10)
		local abilities = info.Abilities or {}
		if #abilities > 0 then
			local ab = abilities[self.rng:NextInteger(1, #abilities)]
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
			self:AttackPlayer(a, target, now)
			a.State = "Attack"
		elseif b == "Charger" and dist > 10 and dist < 36 and now >= a.NextAttack then
			a.State = "Windup"
			a.StateUntil = now + 0.8
			a.ChargeHit = {}
			local d = (r.Position - a.Root.Position) * Vector3.new(1, 0, 1)
			a.ChargeDir = d.Magnitude > 0.1 and d.Unit or a.Root.CFrame.LookVector
			a.NextAttack = now + (info.AttackCooldown or 2.4) + 1.3
			self:Stop(a)
			self:Face(a, r.Position)
			a.Model:SetAttribute("State", "Windup")
			self:MarkAttack(a, "Roar")
			return
		else
			-- กระโดดตะครุบ
			if info.Leap and dist < 28 and dist > 10 and now >= (a.NextLeap or 0) then
				a.NextLeap = now + 4
				local d = (r.Position - a.Root.Position)
				a.Root.AssemblyLinearVelocity = d.Unit * 70 + Vector3.new(0, 38, 0)
				self:MarkAttack(a, "Leap")
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

-- ปีศาจกวางกลวง
function AnimalService:ThinkStalker(a, now)
	local safe = self.ctx.Services.CampService:SafeRadius()
	local lights = self.ctx.Services.BuildingService:LightSources()
	local surv = self.ctx.Services.SurvivalService
	local function lit(pos)
		if self:CampDistance(pos) < safe + 4 then
			return true
		end
		for _, l in ipairs(lights) do
			if (l[1] - pos).Magnitude < l[2] then
				return true
			end
		end
		return false
	end
	-- หาเหยื่อ: คนที่ไม่อยู่ในแสง
	local best, bestD
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r and surv:IsAlive(p) then
			local d = (r.Position - a.Root.Position).Magnitude
			if not lit(r.Position) and (not bestD or d < bestD) then
				best, bestD = p, d
			end
		end
	end
	-- คนถือคบเพลิง = กวางไม่กล้าเข้าใกล้
	local function torchRepel(pos)
		for _, p in ipairs(Players:GetPlayers()) do
			local r = charRoot(p)
			if r then
				local _, tool = self.ctx.Services.CombatService.EquippedTool(p)
				if tool and tool.Light and (r.Position - pos).Magnitude < tool.Light then
					return r.Position
				end
			end
		end
		return nil
	end
	local repel = torchRepel(a.Root.Position)
	if repel then
		local away = (a.Root.Position - repel) * Vector3.new(1, 0, 1)
		self:MoveTo(a, a.Root.Position + away.Unit * 30, 0.8)
		a.State = "Repelled"
		a.Model:SetAttribute("State", "Repelled")
		return
	end
	if best then
		local r = charRoot(best)
		if bestD < (a.Info.AttackRange or 9) + 3 then
			self:Stop(a)
			self:Face(a, r.Position)
			self:AttackPlayer(a, best, now)
			a.State = "Attack"
		elseif bestD < 70 and a.State ~= "Hunt" and a.State ~= "Attack" then
			-- จ้องนิ่ง แล้วค่อยวิ่งใส่
			if not a.StareUntil then
				a.StareUntil = now + 2.2
				self:Stop(a)
				self:Face(a, r.Position)
				self:MarkAttack(a, "Stare")
				self.ctx.Remotes.Get("HitFx"):FireClient(best, "StalkerStare", { Model = a.Model })
			elseif now > a.StareUntil then
				a.State = "Hunt"
				a.StareUntil = nil
			end
		else
			self:MoveTo(a, r.Position, a.State == "Hunt" and 1.35 or 0.75)
			if a.State ~= "Hunt" then
				a.State = "Stalk"
			end
		end
	else
		-- ทุกคนอยู่ในแสง: เดินวนที่ขอบแสงไฟ จ้องเข้ามา
		a.StareUntil = nil
		local camp = self.ctx.CampPosition
		a.OrbitAngle = (a.OrbitAngle or 0) + 0.02
		local rr = math.max(safe, 30) + 26
		local goal = camp + Vector3.new(math.cos(a.OrbitAngle) * rr, 0, math.sin(a.OrbitAngle) * rr)
		self:MoveTo(a, goal, 0.45)
		a.State = "Lurk"
	end
	a.Model:SetAttribute("State", a.State)
end

-- ลูกสัตว์ธาตุเดินตามคน
function AnimalService:ThinkSpirit(a, now)
	local p = a.FollowPlayer
	if not (p and p.Parent) then
		self:Stop(a)
		return
	end
	local r = charRoot(p)
	if not r then
		return
	end
	local d = (r.Position - a.Root.Position).Magnitude
	if d > 120 then
		a.Model:PivotTo(r.CFrame * CFrame.new(3, 0, 4))
	elseif d > 8 then
		self:MoveTo(a, r.Position - r.CFrame.LookVector * 4, d > 30 and 1.4 or 1)
	else
		self:Stop(a)
	end
	if self:CampDistance(a.Root.Position) < math.max(self.ctx.Services.CampService:SafeRadius(), 40) then
		self.ctx.Services.SpiritService:Rescue(a, p)
	end
end

function AnimalService:Think(a, now)
	if a.Dead or a.Removed or not a.Model.Parent then
		return
	end
	-- ไฟไหม้
	if a.BurnUntil and now < a.BurnUntil then
		self:TakeDamage(a, (a.Burn or 3) * Config.AnimalThinkRate, nil, { Silent = true, Source = "Burn" })
		if a.Dead then
			return
		end
	end
	-- ตกน้ำลึก/หลุดแมพ
	if a.Root.Position.Y < -120 then
		self:Remove(a)
		return
	end
	if a.Kind == "Spirit" then
		if a.FollowPlayer then
			self:ThinkSpirit(a, now)
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
			if h > layout.WaterLevel + 1 and not lava and campD > 150 then
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
							local count = info.Pack and self.rng:NextInteger(info.Pack[1], info.Pack[2]) or 1
							for i = 1, count do
								local off = Vector3.new(self.rng:NextNumber(-6, 6), 0, self.rng:NextNumber(-6, 6))
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
	local cap = Config.MaxWildAnimals * (phase == "Night" and 0.4 or 1)
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
