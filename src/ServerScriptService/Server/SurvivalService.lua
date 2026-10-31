--[[
	SurvivalService — ความหิว, เลือด, ล้ม/ช่วยเพื่อน, ตาย/เกิดใหม่, คลาส, กินอาหาร
	ดาเมจใส่ผู้เล่นทุกชนิดต้องผ่าน SurvivalService:Damage() (ระบบล้มจะได้ทำงาน)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local ArmorModels = require(ReplicatedStorage.Shared.ArmorModels)
local medBusy -- [player] = true ระหว่างพันแผล (ตั้งค่าที่ UseMedical)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Analytics = require(script.Parent.Analytics)

local SurvivalService = {}
local state = {} -- [player] = { Downed, DownedAt, Dead, Burn, LastHit }

function SurvivalService:Init(ctx)
	self.ctx = ctx
end

-- ออร่าวิหาร (ได้จากการเคลียร์วิหารธาตุ อยู่ทั้งรอบ): ดิน = เลือดสูงสุด +15% · น้ำ = หิวช้าลง 15%
--   น้ำแข็ง = สตามิน่าลดช้าลง 15% (ฝั่ง client) · ไฟ = ดาเมจ +15%
local AURA_PERK = { HungerMult = { "Aura_Water", 0.85 }, DamageMult = { "Aura_Fire", 1.15 } }

function SurvivalService:Perk(player, name, default)
	local v = Classes.PerksFor(player:GetAttribute("Class") or "Survivor", player:GetAttribute("ClassLevel") or 1)[name]
	if v == nil then
		v = default
	end
	local aura = AURA_PERK[name]
	if aura and type(v) == "number" and player:GetAttribute(aura[1]) then
		v *= aura[2]
	end
	return v
end

-- เลือดสูงสุด = 100 + ทักษะคลาส + เกราะ (x1.15 ถ้ามีออร่าดิน)
function SurvivalService:MaxHealthFor(player)
	local hp = 100 + self:Perk(player, "MaxHealthBonus", 0) + self:ArmorHP(player)
	if player:GetAttribute("Aura_Earth") then
		hp *= 1.15
	end
	return math.floor(hp + 0.5)
end

local AURA_COLOR = {
	Earth = Color3.fromRGB(120, 245, 90), Water = Color3.fromRGB(70, 210, 255),
	Air = Color3.fromRGB(200, 235, 255), Fire = Color3.fromRGB(255, 120, 40),
}

-- ออร่าบนตัว (อ่อนๆ): ประกายสีธาตุลอยขึ้นรอบตัว + แสงจาง
local function attachAura(char, el)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or root:FindFirstChild("Aura_" .. el) then
		return
	end
	local col = AURA_COLOR[el]
	local att = Instance.new("Attachment")
	att.Name = "Aura_" .. el
	att.Parent = root
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = ColorSequence.new(col)
	p.LightEmission = 1
	p.LightInfluence = 0
	p.Rate = 12
	p.Lifetime = NumberRange.new(1, 1.6)
	p.Speed = NumberRange.new(0.6, 1.4)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Acceleration = Vector3.new(0, 1.6, 0)
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	p.Shape = Enum.ParticleEmitterShape.Cylinder
	p.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	p.Parent = att
	local l = Instance.new("PointLight")
	l.Color = col
	l.Range = 9
	l.Brightness = 0.8
	l.Shadows = false
	l.Parent = att
end

-- ให้ออร่าวิหารธาตุ el (ซ้ำ = ไม่ได้เพิ่ม)
function SurvivalService:GiveAura(player, el)
	if player:GetAttribute("Aura_" .. el) then
		return false
	end
	player:SetAttribute("Aura_" .. el, true)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if el == "Earth" and hum then
		local frac = hum.Health / math.max(hum.MaxHealth, 1)
		hum.MaxHealth = self:MaxHealthFor(player)
		hum.Health = hum.MaxHealth * frac
	end
	if char then
		attachAura(char, el)
	end
	return true
end

local function humanoidOf(player)
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid"), char
end

function SurvivalService:IsAlive(player)
	local s = state[player]
	local hum = humanoidOf(player)
	return hum and hum.Health > 0 and s and not s.Dead and not s.Downed
end

-- จำนวนผู้เล่นในรอบ (aliveOnly = เฉพาะคนที่ยังไม่ตาย) ขั้นต่ำ 1 — ใช้ปรับความยากตามจำนวนคน
function SurvivalService:RunPlayerCount(aliveOnly)
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InRun") and not (aliveOnly and p:GetAttribute("Dead")) then
			n += 1
		end
	end
	return math.max(1, n)
end

function SurvivalService:IsDowned(player)
	return state[player] and state[player].Downed
end

---------------------------------------------------------------- ดาเมจ
function SurvivalService:Damage(player, amount, source, opts)
	local s = state[player]
	local hum, char = humanoidOf(player)
	if not (s and hum and char) or s.Dead or s.Downed or hum.Health <= 0 or player:GetAttribute("TestGod") then
		return
	end
	if char:FindFirstChildOfClass("ForceField") then
		return
	end
	amount *= self:Perk(player, "DamageTakenMult", 1)
	s.LastHit = os.clock()
	s.LastSource = source
	self.ctx.Remotes.Get("HitFx"):FireClient(player, "Hurt", { Amount = amount, Source = source })
	if hum.Health - amount <= 0 then
		hum.Health = 1
		self:Down(player, source)
	else
		hum.Health -= amount
	end
	if opts and opts.Knockback and char.PrimaryPart then
		self.ctx.Remotes.Get("HitFx"):FireClient(player, "Knockback", { Velocity = opts.Knockback })
	end
	if opts and opts.Burn then
		s.Burn = math.max(s.Burn or 0, opts.Burn)
	end
end

function SurvivalService:Heal(player, amount)
	local hum = humanoidOf(player)
	if hum and hum.Health > 0 then
		hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
	end
end

---------------------------------------------------------------- ล้ม / ช่วย / ตาย
-- ล้ม = นอนราบกับพื้น ขยับ/ตี/ใช้ของไม่ได้ นอนรอจนกว่าเพื่อนจะมาช่วย (ไม่มีจับเวลา) · ล้มหมดทั้งทีม = แพ้ (CheckWipe)
-- ไม่มีใครช่วยทัน = ตาย (ดูเพื่อนเล่นต่อจนจบรอบ ไม่เกิดใหม่) · ไม่เหลือใครยืนอยู่เลย = แพ้ทั้งทีม
function SurvivalService:IsIncapacitated(player)
	local s = state[player]
	return s ~= nil and (s.Downed or s.Dead)
end

-- ตรึงตัวนอนราบบนพื้น (เซิร์ฟเวอร์ตรึงเอง ทุกเครื่องเห็นตรงกัน)
local function layDown(char)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = Workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), params)
	local groundY = hit and hit.Position.Y or (root.Position.Y - 3)
	local _, yaw = root.CFrame:ToOrientation()
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	root.CFrame = CFrame.new(root.Position.X, groundY + 1, root.Position.Z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-90), 0, 0)
end

local function standUp(player, char)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local _, yaw = root.CFrame:ToOrientation()
	root.CFrame = CFrame.new(root.Position + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, yaw, 0)
	root.Anchored = false
	pcall(function()
		root:SetNetworkOwner(player)
	end)
end

function SurvivalService:Down(player, source)
	local s = state[player]
	local hum, char = humanoidOf(player)
	if not (s and hum and char) or s.Downed or s.Dead then
		return
	end
	-- ล็อบบี้ (ไม่ได้อยู่ในรอบ): ไม่มีระบบล้ม แค่ฟื้นเลือด
	if not player:GetAttribute("InRun") then
		hum.Health = hum.MaxHealth
		return
	end
	s.Downed = true
	s.DownedAt = os.clock()
	s.DownSource = source or s.LastSource
	player:SetAttribute("Downed", true)
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.AutoRotate = false
	hum:UnequipTools()
	layDown(char)
	self.ctx.Broadcast(string.format("%s ล้มลง! ไปช่วยด่วน", player.DisplayName), "Danger", player) -- คนล้มเห็นข้อความติดจอแทน
	self.ctx.Remotes.Get("Cinematic"):FireClient(player, "Downed", {})
	-- ปุ่มช่วยเพื่อน
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Revive"
		prompt.ActionText = "ช่วยชีวิต (ใช้ผ้าพันแผล)"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = Config.ReviveTime
		prompt.MaxActivationDistance = Config.ReviveRange
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		-- กดค้างช่วยเพื่อน = ท่าก้มพันแผล (MedAnim ฝั่ง client) · ไม่มีหลอดของเรา (ปุ่มมีวงรอของมันเอง)
		prompt.PromptButtonHoldBegan:Connect(function(helper)
			if helper ~= player and self:IsAlive(helper) then
				self:SetMedPose(helper, "Revive", 0, root.Position)
			end
		end)
		prompt.PromptButtonHoldEnded:Connect(function(helper)
			if not medBusy[helper] then
				self:SetMedPose(helper, nil)
			end
		end)
		prompt.Triggered:Connect(function(helper)
			if not medBusy[helper] then
				self:SetMedPose(helper, nil)
			end
			if helper == player or not self:IsAlive(helper) or not self:IsDowned(player) then
				return
			end
			local inv = self.ctx.Services.InventoryService
			local used
			if inv:Remove(helper, "Bandage", 1) then
				used = "Bandage"
			elseif inv:Remove(helper, "Medkit", 1) then
				used = "Medkit"
			end
			if not used then
				self.ctx.Notify(helper, "ต้องมีผ้าพันแผลหรือชุดปฐมพยาบาล", "Error")
				return
			end
			-- ทักษะหมอ (HealMult) แรงขึ้นทั้งผ้าพันแผลและชุดปฐมพยาบาล (เดิมวงเล็บผิด: ชุดปฐมพยาบาลไม่ได้โบนัส)
			self:Revive(player, math.min(1, (used == "Medkit" and 0.8 or 0.4) * self:Perk(helper, "HealMult", 1)))
			if self.ctx.Services.QuestService then
				self.ctx.Services.QuestService:Progress(helper, "Revive", 1)
			end
			self.ctx.Broadcast(string.format("%s ช่วย %s ได้ทัน", helper.DisplayName, player.DisplayName), "Good")
		end)
	end
	self:CheckWipe()
end

function SurvivalService:Revive(player, frac)
	local s = state[player]
	local hum, char = humanoidOf(player)
	if not (s and hum) or not s.Downed then
		return
	end
	s.Downed = false
	player:SetAttribute("Downed", false)
	hum.Health = hum.MaxHealth * math.clamp(frac or 0.4, 0.1, 1)
	hum.WalkSpeed = Config.BaseWalkSpeed * self:Perk(player, "SpeedMult", 1)
	hum.JumpPower = 50
	hum.AutoRotate = true
	local prompt = char and char:FindFirstChild("Revive", true)
	if prompt then
		prompt:Destroy()
	end
	standUp(player, char)
	self.ctx.Remotes.Get("Cinematic"):FireClient(player, "Revived", {})
end

function SurvivalService:Die(player)
	local s = state[player]
	local hum, char = humanoidOf(player)
	if not s or s.Dead then
		return
	end
	s.Downed = false
	s.Dead = true
	player:SetAttribute("Downed", false)
	player:SetAttribute("Dead", true)
	local prompt = char and char:FindFirstChild("Revive", true)
	if prompt then
		prompt:Destroy()
	end
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = false
	end
	if hum then
		hum.Health = 0
	end
	-- ล็อบบี้: เกิดใหม่ทันที
	if not player:GetAttribute("InRun") then
		task.delay(3, function()
			if player.Parent and s.Dead then
				self:Spawn(player)
			end
		end)
		return
	end
	-- ในรอบ: ไม่เกิดใหม่ — ดูเพื่อนเล่นต่อ (หรือกดกลับล็อบบี้เอง)
	local alive = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InRun") and self:IsAlive(p) then
			alive += 1
		end
	end
	self.ctx.Remotes.Get("Cinematic"):FireClient(player, "Died", { Night = self.ctx.State:GetAttribute("Night"), Alive = alive })
	self.ctx.Broadcast(string.format("%s สิ้นชีพ", player.DisplayName), "Danger")
	Analytics.Custom(player, "PlayerDied", self.ctx.State:GetAttribute("Night") or 1, {
		tostring(s.DownSource or s.LastSource or "Unknown"), player:GetAttribute("Class") or "Survivor",
	})
	s.DownSource = nil
	self:CheckWipe()
end

-- ไม่เหลือใครยืนอยู่ในรอบเลย (ล้ม/ตายหมด) = แพ้ทั้งทีม (ทุกช่วงเวลา ไม่ใช่แค่กลางคืน)
function SurvivalService:CheckWipe()
	local director = self.ctx.Services.DirectorService
	if not (director and director:IsRunning()) or self.ctx.State:GetAttribute("Phase") == "Ended" then
		return
	end
	local function standing()
		local count, alive = 0, 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("InRun") then
				count += 1
				if self:IsAlive(p) then
					alive += 1
				end
			end
		end
		return count, alive
	end
	local count, alive = standing()
	if alive > 0 then
		return
	end
	if count == 0 then
		-- ทุกคนออกจากรอบไปแล้ว · ออกเกมกลางรอบ (ไม่ได้ตาย) = เก็บรอบไว้ให้กลับมาเล่นต่อ (RejoinService) ไม่นับว่าแพ้
		local rejoin = self.ctx.Services.RejoinService
		if rejoin and rejoin.held then
			return
		end
		director:GameOver()
		return
	end
	task.delay(2, function()
		local c2, a2 = standing()
		if a2 == 0 and (c2 > 0 or count > 0) then
			director:GameOver()
		end
	end)
end

---------------------------------------------------------------- เกิด
function SurvivalService:Spawn(player)
	local s = state[player] or {}
	state[player] = s
	s.Dead = false
	s.Downed = false
	s.Burn = 0
	player:SetAttribute("Dead", false)
	player:SetAttribute("Downed", false)
	player:LoadCharacter()
end

function SurvivalService:SpawnPoint(player)
	if not player:GetAttribute("InRun") then
		return self.ctx.Services.LobbyService:SpawnPoint()
	end
	local camp = self.ctx.CampPosition
	local a = math.random() * math.pi * 2
	return camp + Vector3.new(math.cos(a) * 14, 4, math.sin(a) * 14)
end

function SurvivalService:OnCharacter(player, char)
	local hum = char:WaitForChild("Humanoid")
	local root = char:WaitForChild("HumanoidRootPart")
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = self:MaxHealthFor(player)
	hum.Health = hum.MaxHealth
	task.delay(0.5, function()
		for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
			if char.Parent and player:GetAttribute("Aura_" .. el) then
				attachAura(char, el)
			end
		end
	end)
	-- เกราะที่สวมอยู่ (คราฟต์ในรอบนี้) -> ใส่โมเดลกลับหลังเกิดใหม่
	local armor = player:GetAttribute("Armor")
	if armor and player:GetAttribute("InRun") then
		task.delay(0.5, function()
			if char.Parent and player:GetAttribute("Armor") == armor then
				ArmorModels.Attach(char, armor)
			end
		end)
	end
	hum.WalkSpeed = Config.BaseWalkSpeed * self:Perk(player, "SpeedMult", 1)
	local pos = self:SpawnPoint(player)
	-- ล็อบบี้อยู่ไกลจากแมพมาก (StreamingEnabled): ตรึงตัวไว้จนพื้นตรงจุดเกิดโหลดถึงเครื่องผู้เล่น ไม่งั้นตกทะลุโลก
	root.Anchored = true
	task.defer(function()
		local look = player:GetAttribute("InRun") and self.ctx.CampPosition + Vector3.new(0, 4, 0) or pos + Vector3.new(0, 0, -10)
		root.CFrame = CFrame.new(pos, Vector3.new(look.X, pos.Y, look.Z))
		pcall(function()
			player:RequestStreamAroundAsync(pos, 12)
		end)
		task.wait(1.5)
		if root.Parent then
			root.Anchored = false
		end
	end)
	-- กันตกทะลุโลก (พื้นยังโหลดไม่ทัน): ร่วงต่ำเกินไป -> ดึงกลับจุดเกิดแล้วตรึงรอโหลด
	task.spawn(function()
		while char.Parent and root.Parent do
			task.wait(1)
			if player:GetAttribute("InRun") and root.Position.Y < Config.WaterLevel - 150 then
				local back = self:SpawnPoint(player)
				root.Anchored = true
				root.AssemblyLinearVelocity = Vector3.zero
				root.CFrame = CFrame.new(back)
				pcall(function()
					player:RequestStreamAroundAsync(back, 12)
				end)
				task.wait(1.5)
				root.Anchored = false
			end
		end
	end)
	local ff = Instance.new("ForceField")
	ff.Visible = true
	ff.Parent = char
	task.delay(4, function()
		ff:Destroy()
	end)
	hum.Died:Connect(function()
		local s = state[player]
		if s and not s.Dead then
			self:Die(player)
		end
	end)
	if not player:GetAttribute("Hunger") then
		player:SetAttribute("Hunger", Config.HungerMax)
	end
	player:SetAttribute("Hunger", math.max(player:GetAttribute("Hunger"), Config.HungerMax * 0.6))
	self.ctx.Services.InventoryService:RestoreTools(player)
end

function SurvivalService:OnClassChosen(player, classId)
	local c = Classes.Data[classId]
	if not c then
		return
	end
	local hum = humanoidOf(player)
	if hum then
		hum.WalkSpeed = Config.BaseWalkSpeed * self:Perk(player, "SpeedMult", 1)
		-- เลือดสูงสุดตามทักษะ (คงสัดส่วนเลือดเดิม)
		local frac = hum.Health / math.max(hum.MaxHealth, 1)
		hum.MaxHealth = self:MaxHealthFor(player)
		hum.Health = hum.MaxHealth * frac
	end
	player:SetAttribute("StaminaMult", self:Perk(player, "StaminaMult", 1))
end

-- ของเริ่มต้นของคลาส (ให้ตอนออกเดินทางจากล็อบบี้)
function SurvivalService:GiveStartItems(player)
	if player:GetAttribute("StartItemsGiven") then
		return
	end
	local c = Classes.Data[player:GetAttribute("Class") or "Survivor"]
	if not c then
		return
	end
	player:SetAttribute("StartItemsGiven", true)
	Analytics.Custom(player, "ClassUsed", player:GetAttribute("ClassLevel") or 1, { player:GetAttribute("Class") or "Survivor" })
	player:SetAttribute("Hunger", Config.HungerMax)
	local inv = self.ctx.Services.InventoryService
	-- ทุกคลาส: ขวาน + กระสอบเริ่มต้นเสมอ (ช่อง 1 = ขวาน, ช่อง 2 = กระสอบ) แล้วถือขวานในมือทันที
	local ids = {}
	for id in pairs(c.StartItems) do
		table.insert(ids, id)
	end
	local hasAxe = false
	for _, id in ipairs(ids) do
		local t = Items.Tools[id]
		hasAxe = hasAxe or (t ~= nil and t.Kind == "Axe")
	end
	if not hasAxe then
		table.insert(ids, "OldAxe")
	end
	table.insert(ids, "OldSack")
	table.sort(ids, function(a, b)
		local oa, ob = inv.ToolOrder(a), inv.ToolOrder(b)
		if oa ~= ob then
			return oa < ob
		end
		return a < b
	end)
	for _, id in ipairs(ids) do
		local item = Items.Data[id]
		if item and item.Category == "Armor" then
			self:EquipArmor(player, id) -- เกราะเริ่มต้น: สวมเลย (ไม่เข้ากระเป๋า)
		else
			inv:Add(player, id, c.StartItems[id] or 1, true)
		end
	end
end

-- ถือขวาน (อาวุธหลัก) ในมือตอนเกิด/ออกเดินทาง
function SurvivalService:EquipStartWeapon(player)
	if not player:GetAttribute("InRun") then
		return
	end
	local inv = self.ctx.Services.InventoryService
	local char = player.Character
	if char and char:FindFirstChildOfClass("Tool") then
		return
	end
	local id = inv:BestAxe(player)
	if id then
		inv:EquipItem(player, id)
	end
end

-- เริ่มรอบใหม่ (หลังจบเกม) -> กลับล็อบบี้
-- เลือดที่เกราะเพิ่มให้
function SurvivalService:ArmorHP(player)
	local item = Items.Data[player:GetAttribute("Armor") or ""]
	return item and item.ArmorHP or 0
end

-- สวมเกราะ: เพิ่มเลือดสูงสุด (เลือดปัจจุบันเพิ่มเท่ากัน) + ใส่โมเดลบนตัว · id = nil ถอด
function SurvivalService:EquipArmor(player, id)
	local hum, char = humanoidOf(player)
	local before = self:MaxHealthFor(player)
	player:SetAttribute("Armor", id)
	local diff = self:MaxHealthFor(player) - before
	if hum then
		hum.MaxHealth = math.max(1, hum.MaxHealth + diff)
		if hum.Health > 0 then
			hum.Health = math.clamp(hum.Health + math.max(diff, 0), 1, hum.MaxHealth)
		end
	end
	if char then
		if id then
			ArmorModels.Attach(char, id)
		else
			ArmorModels.Remove(char)
		end
	end
end

function SurvivalService:ResetPlayer(player)
	player:SetAttribute("Armor", nil)
	for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		player:SetAttribute("Aura_" .. el, nil)
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for _, d in ipairs(root and root:GetChildren() or {}) do
		if d.Name:sub(1, 5) == "Aura_" then
			d:Destroy()
		end
	end
	player:SetAttribute("InRun", false)
	player:SetAttribute("StartItemsGiven", false)
	player:SetAttribute("Hunger", Config.HungerMax)
	player:SetAttribute("FullUntil", nil)
	self.ctx.Services.InventoryService:Reset(player)
	self:OnClassChosen(player, player:GetAttribute("Class") or "Survivor")
	self:Spawn(player)
end

---------------------------------------------------------------- กิน / ใช้ยา
function SurvivalService:UseItem(player, id)
	local item = Items.Data[id]
	if not item or not self:IsAlive(player) then
		return
	end
	local inv = self.ctx.Services.InventoryService
	if item.Category == "Food" then
		if not inv:Remove(player, id, 1) then
			return
		end
		local h = player:GetAttribute("Hunger") or 0
		player:SetAttribute("Hunger", math.min(Config.HungerMax, h + item.Food))
		if item.Heal and item.Heal > 0 then
			self:Heal(player, item.Heal * self:Perk(player, "HealMult", 1)) -- นักหาของป่า: อาหารฟื้นเลือดแรงขึ้นด้วย
		elseif item.Heal and item.Heal < 0 then
			self:Damage(player, -item.Heal, "Food")
		end
		if item.Stamina then
			player:SetAttribute("StaminaRefill", (player:GetAttribute("StaminaRefill") or 0) + 1) -- client เติมหลอดเต็ม
		end
		if item.Full then
			player:SetAttribute("FullUntil", Workspace:GetServerTimeNow() + item.Full.Time)
			player:SetAttribute("FullMult", item.Full.Mult)
		end
		self.ctx.Remotes.Get("HitFx"):FireClient(player, "Eat", { Item = id })
	elseif item.Category == "Medical" then
		local hum = humanoidOf(player)
		if hum and hum.Health < hum.MaxHealth and inv:Remove(player, id, 1) then
			self:Heal(player, item.Heal * self:Perk(player, "HealMult", 1))
			self.ctx.Remotes.Get("HitFx"):FireClient(player, "Heal", { Item = id })
		end
	end
end

local medCool = setmetatable({}, { __mode = "k" })
-- เวลาใช้ยา (วินาที): ตัวเอง / ช่วยเพื่อนที่ล้ม
local MED_TIME = { Bandage = 1.6, Medkit = 2.4, HerbSalve = 1.2 }
local MED_REVIVE_TIME = { Bandage = 2.2, Medkit = 2.6 }
-- [player] = true ระหว่างกำลังพันแผล (กดซ้ำไม่เริ่มใหม่)
medBusy = setmetatable({}, { __mode = "k" })

-- ท่าใช้ยา (MedAnim ฝั่ง client อ่าน attribute): pose = "Self" / "Revive" / nil (เลิก)
--   time > 0 = แสดงหลอดรอบนจอผู้ใช้ · at = จุดที่ก้มไปหา (หันตัวเข้าหาเพื่อน)
function SurvivalService:SetMedPose(player, pose, time, at, item)
	player:SetAttribute("MedUse", pose)
	player:SetAttribute("MedItem", pose and item or nil)
	player:SetAttribute("MedTime", pose and time or nil)
	player:SetAttribute("MedStart", pose and Workspace:GetServerTimeNow() or nil)
	local _, char = humanoidOf(player)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if pose and at and root then
		local flat = Vector3.new(at.X, root.Position.Y, at.Z)
		if (flat - root.Position).Magnitude > 0.5 then
			char:PivotTo(CFrame.lookAt(root.Position, flat))
		end
	end
end

-- ถือผ้าพันแผล/ชุดปฐมพยาบาลแล้วคลิก: มีเพื่อนล้มอยู่ใกล้ -> ช่วยชีวิตเพื่อน · ไม่มี -> ฟื้นเลือดตัวเอง
--   ต้องยืนพันแผลจนหลอดเต็ม (ท่าพันแผล) · ขยับตัว/โดนตี/เก็บของลง/เพื่อนหาย = ยกเลิก ไม่เสียของ
function SurvivalService:UseMedical(player, id)
	local item = Items.Data[id]
	local hum, char = humanoidOf(player)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (item and item.Category == "Medical" and hum and root) or not self:IsAlive(player) or medBusy[player] then
		return
	end
	local inv = self.ctx.Services.InventoryService
	if inv:Count(player, id) <= 0 then
		return
	end
	if os.clock() - (medCool[player] or 0) < 0.6 then
		return
	end
	medCool[player] = os.clock()
	local pos = root.Position
	local best, bestD
	for _, p in ipairs(Players:GetPlayers()) do
		local _, pc = humanoidOf(p)
		if item.Revive and p ~= player and pc and self:IsDowned(p) then
			local d = (pc:GetPivot().Position - pos).Magnitude
			if d <= Config.ReviveRange + 4 and (not bestD or d < bestD) then
				best, bestD = p, d
			end
		end
	end
	if not best and hum.Health >= hum.MaxHealth - 0.5 then
		self.ctx.Notify(player, "❤ เลือดเต็มแล้ว — เก็บ" .. item.Thai .. "ไว้ช่วยเพื่อนที่ล้ม", "Info")
		return
	end
	local dur = (best and MED_REVIVE_TIME[id] or MED_TIME[id]) or 2
	local bc = best and select(2, humanoidOf(best)) -- รักษาตัวเอง (ไม่มีเพื่อนล้ม) = best เป็น nil
	medBusy[player] = true
	self:SetMedPose(player, best and "Revive" or "Self", dur, bc and bc:GetPivot().Position, id)
	local startPos = root.Position
	local lastHp = hum.Health
	local function stop(reason)
		medBusy[player] = nil
		if player:GetAttribute("MedUse") then
			self:SetMedPose(player, nil)
		end
		if reason then
			self.ctx.Notify(player, "✖ หยุดพันแผล — " .. reason, "Warn")
		end
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < dur do
			task.wait(0.1)
			if not (char.Parent and player.Parent) or not self:IsAlive(player) or self:IsIncapacitated(player) then
				return stop()
			end
			local tool = char:FindFirstChildOfClass("Tool")
			if not (tool and tool:GetAttribute("MedKind") == id) then
				return stop("เก็บ" .. item.Thai .. "ลง")
			end
			if hum.Health < lastHp - 0.5 then
				return stop("โดนโจมตี")
			end
			lastHp = math.max(lastHp, hum.Health)
			if ((root.Position - startPos) * Vector3.new(1, 0, 1)).Magnitude > 2.5 then
				return stop("ขยับตัว (ต้องยืนนิ่งตอนพันแผล)")
			end
			if best then
				local _, pc = humanoidOf(best)
				if not (pc and self:IsDowned(best)) or (pc:GetPivot().Position - root.Position).Magnitude > Config.ReviveRange + 6 then
					return stop(self:IsDowned(best) and "ห่างเพื่อนเกินไป" or nil)
				end
			end
		end
		stop()
		if best then
			if not self:IsDowned(best) or not inv:Remove(player, id, 1) then
				return
			end
			self:Revive(best, math.min(1, (id == "Medkit" and 0.8 or 0.4) * self:Perk(player, "HealMult", 1)))
			if self.ctx.Services.QuestService then
				self.ctx.Services.QuestService:Progress(player, "Revive", 1)
			end
			self.ctx.Remotes.Get("HitFx"):FireClient(player, "Heal", { Item = id })
			self.ctx.Broadcast(string.format("%s ช่วย %s ได้ทัน", player.DisplayName, best.DisplayName), "Good")
			return
		end
		if inv:Remove(player, id, 1) then
			self:Heal(player, item.Heal * self:Perk(player, "HealMult", 1))
			self.ctx.Remotes.Get("HitFx"):FireClient(player, "Heal", { Item = id })
		end
	end)
end

---------------------------------------------------------------- loop
function SurvivalService:Start(ctx)
	Players.CharacterAutoLoads = false
	ctx.Remotes.Get("UseItem").OnServerEvent:Connect(function(player, id)
		if type(id) == "string" then
			self:UseItem(player, id)
		end
	end)
	local function onPlayer(player)
		state[player] = { Dead = false, Downed = false, Burn = 0 }
		ctx.Services.DataService:Load(player)
		player:SetAttribute("Hunger", Config.HungerMax)
		player.CharacterAdded:Connect(function(char)
			self:OnCharacter(player, char)
		end)
		-- เกิดในล็อบบี้ทันที (แมพสร้างเสร็จเมื่อไรค่อยเข้าประตู)
		player:SetAttribute("InRun", false)
		task.spawn(function()
			self:OnClassChosen(player, player:GetAttribute("Class") or "Survivor")
			self:Spawn(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		state[p] = nil
		-- คนในรอบออกจากเกม: เช็กว่ายังเหลือคนยืนอยู่ไหม
		if p:GetAttribute("InRun") then
			task.defer(function()
				self:CheckWipe()
			end)
		end
	end)

	-- ความหิว / ไฟไหม้ / หมดเวลาล้ม
	task.spawn(function()
		local dt = 0.5
		local loops = 0
		while true do
			task.wait(dt)
			loops += 1
			for _, player in ipairs(Players:GetPlayers()) do
				local s = state[player]
				local hum, char = humanoidOf(player)
				-- ตำแหน่งคร่าวๆ ให้เพื่อนร่วมทีมเห็นบนเข็มทิศ (ตัวละครไกลๆ อาจไม่ได้โหลดถึงเครื่องเพื่อน)
				if loops % 2 == 0 and char and player:GetAttribute("InRun") then
					local pv = char:GetPivot().Position
					player:SetAttribute("RunPos", Vector3.new(math.floor(pv.X), math.floor(pv.Y), math.floor(pv.Z)))
				end
				if s and hum and char and hum.Health > 0 and not s.Dead and player:GetAttribute("InRun") then
					if not s.Downed then
						-- หิว (นอกเขตกองไฟที่มองไม่เห็น = หิวเร็วขึ้น)
						local mult = self:Perk(player, "HungerMult", 1)
						if (player:GetAttribute("FullUntil") or 0) > Workspace:GetServerTimeNow() then
							mult *= player:GetAttribute("FullMult") or 1 -- พายเบอร์รี่: หิวช้าลงชั่วคราว
						end
						local h = (player:GetAttribute("Hunger") or 0) - Config.HungerDrainPerSec * dt * mult
						player:SetAttribute("Hunger", math.max(0, h))
						if h <= 0 then
							self:Damage(player, Config.StarveDamagePerSec * dt, "Hunger")
						end
						if (s.Burn or 0) > 0 then
							self:Damage(player, s.Burn * dt, "Burn")
							s.Burn = math.max(0, s.Burn - 2 * dt)
						end
						-- ฟื้นเลือดช้าๆ ตอนอิ่ม
						if h > Config.HungerMax * 0.6 and os.clock() - (s.LastHit or 0) > 8 then
							self:Heal(player, 0.6 * dt)
						end
						-- ทักษะฟื้นเลือด (ทำงานตลอด ถ้าไม่อดอาหาร)
						local regen = self:Perk(player, "Regen", 0)
						if regen > 0 and h > 0 then
							self:Heal(player, regen * dt)
						end
						-- กลับมานั่งข้างกองไฟ (ในเขตไฟที่ติดอยู่) = ฟื้นเลือดเร็ว ~3/วิ (เต็มหลอดใน ~30 วิ) · โดนตีอยู่ไม่ฟื้น
						local camp = self.ctx.Services.CampService
						local fire = camp and camp:FirePosition()
						if fire and camp:IsLit() and os.clock() - (s.LastHit or 0) > 3 and hum.Health < hum.MaxHealth
							and ((char:GetPivot().Position - fire) * Vector3.new(1, 0, 1)).Magnitude <= camp:SafeRadius() then
							self:Heal(player, 3 * dt)
						end
					end
				end
			end
		end
	end)
end

return SurvivalService
