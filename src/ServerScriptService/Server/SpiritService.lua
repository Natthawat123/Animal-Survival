--[[
	SpiritService — ภารกิจหลักของการผจญภัย
	  ศาลเจ้า 4 ธาตุ: ลูกสัตว์ธาตุถูกขังในกรง มีสัตว์เฝ้า -> ปราบผู้เฝ้า -> ปลดผนึก -> พาเดินกลับกองไฟ
	  ช่วยครบ = บัฟถาวร + ฉากจบสมบูรณ์
	  รังบอส 4 ธาตุ: เข้าใกล้ = บอสตื่น (สู้ได้ทุกเวลา) ชนะ = หัวใจอสูร + เพชร
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Animals = require(ReplicatedStorage.Shared.Animals)
local Classes = require(ReplicatedStorage.Shared.Classes)

local SpiritService = {}

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

---------------------------------------------------------------- ศาลเจ้า
function SpiritService:SetupShrine(model)
	local el = model:GetAttribute("Element")
	local cage = model:FindFirstChild("Cage")
	local seal = cage and cage:FindFirstChild("Seal")
	local base = model:GetPivot().Position
	local sh = { Model = model, Element = el, Base = base, Guardians = {}, Freed = false, Rescued = false }
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
	local a = self.ctx.Services.AnimalService:Spawn(id, sh.Base + Vector3.new(0, 1.5, 0), { Kind = "Spirit" })
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
	local count = 3
	for i = 1, count do
		local id = pool[math.min(i, #pool)]
		local ang = i / count * math.pi * 2
		local pos = sh.Base + Vector3.new(math.cos(ang) * 18, 2, math.sin(ang) * 18)
		local h = self.ctx.Layout:HeightAt(pos.X, pos.Z)
		local a = animals:Spawn(id, Vector3.new(pos.X, math.max(h, sh.Base.Y) + 1, pos.Z), {
			Kind = "Guardian", Home = sh.Base, Leash = 70, HealthMult = 1.6, DamageMult = 1.2,
		})
		if a then
			a.Model:SetAttribute("Guardian", true)
			table.insert(sh.Guardians, a)
		end
	end
	sh.GuardiansSpawned = true
	self.ctx.Broadcast(string.format("⚔ ผู้พิทักษ์ศาลเจ้า%s ตื่นขึ้นแล้ว! ปราบให้หมดเพื่อปลดผนึก", sh.Element), "Warn")
end

function SpiritService:Free(el, player)
	local sh = self.shrines[el]
	if not sh or sh.Freed or not sh.Pup then
		return
	end
	sh.Freed = true
	sh.Prompt.Enabled = false
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
	a.Root.Anchored = false
	pcall(function()
		a.Root:SetNetworkOwner(nil)
	end)
	a.FollowPlayer = player
	a.Model:SetAttribute("State", "Follow")
	self.ctx.Remotes.Get("Cinematic"):FireAllClients("SpiritFreed", { Element = el, Name = a.Info.Thai, Player = player.DisplayName })
	self.ctx.Broadcast(string.format("✨ %s ปลดปล่อย %s แล้ว! พามันกลับไปที่กองไฟ", player.DisplayName, a.Info.Thai), "Reward")
end

function SpiritService:Rescue(a, player)
	local el = a.Info.Element
	local sh = self.shrines[el]
	if not sh or sh.Rescued then
		return
	end
	sh.Rescued = true
	a.FollowPlayer = nil
	local s = self.ctx.State
	s:SetAttribute("Spirit" .. el, true)
	-- ไปนั่งข้างเสาธงธาตุ
	local camp = self.ctx.Services.CampService.campModel
	local orb = camp and camp:FindFirstChild("SpiritOrb_" .. el)
	if orb then
		orb.Material = Enum.Material.Neon
		orb.Color = a.Info.Model.Colors.Glow or a.Info.Model.Colors.Main
		local l = Instance.new("PointLight")
		l.Color = orb.Color
		l.Range = 26
		l.Brightness = 3
		l.Parent = orb
		a.Model:PivotTo(CFrame.new(orb.Position - Vector3.new(0, 11, 0) + (self.ctx.CampPosition - orb.Position).Unit * Vector3.new(4, 0, 4)))
	end
	a.Root.Anchored = true
	a.Model:SetAttribute("State", "Rescued")
	local count = 0
	for _, e in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		if s:GetAttribute("Spirit" .. e) then
			count += 1
		end
	end
	s:SetAttribute("SpiritCount", count)
	self.ctx.Remotes.Get("Cinematic"):FireAllClients("SpiritRescued", { Element = el, Name = a.Info.Thai, Buff = BUFF_TEXT[el], Count = count })
	for _, p in ipairs(Players:GetPlayers()) do
		self.ctx.Services.DataService:AddDiamonds(p, Classes.SpiritReward, "ช่วย " .. a.Info.Thai)
	end
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
		Kind = "Guardian", Home = lair.Pos, Leash = 120, HealthMult = 0.7,
	})
	if not a then
		return
	end
	a.Model:SetAttribute("IsBoss", true)
	a.Model:SetAttribute("Lair", lair.Element)
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
	self.ctx.State:SetAttribute("Lair" .. el .. "Cleared", true)
	local sigil = lair.Model:FindFirstChild("Sigil")
	if sigil then
		sigil.Color = Color3.fromRGB(255, 220, 120)
		sigil.Transparency = 0.3
	end
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
		elseif not sh.Rescued and sh.Pup and sh.Pup.FollowPlayer == nil then
			-- คนพาตาย/ออก: ให้คนใกล้สุดพาต่อ
			local p = nearestPlayer(sh.Pup.Root.Position, 30)
			if p then
				sh.Pup.FollowPlayer = p
			end
		elseif not sh.Rescued and sh.Pup and sh.Pup.FollowPlayer and not sh.Pup.FollowPlayer.Parent then
			sh.Pup.FollowPlayer = nil
		end
	end
	for _, lair in pairs(self.lairs) do
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
		local sp = { Kind = "Shrine", Element = el, Position = sh.Base }
		sh.Model:Destroy()
		local m = PropBuilder.BuildShrine(sp, sites)
		self:SetupShrine(m)
	end
	for _, lair in pairs(self.lairs) do
		lair.Cleared = false
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
