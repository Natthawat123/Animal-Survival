--[[
	SkillService — สกิลกดของคลาส 5 ดาว (Classes.ActiveSkills · ปลดตามเลเวล · คลาสหนึ่งมีได้หลายสกิล)
	  Swarm (แวมไพร์ Lv3)       : ค้างคาว 5 ตัว (เลือด 200) ตามเจ้าของ ไล่กัดมอน · อยู่จนโดนตีตาย หรือกดใหม่ = ฝูงใหม่มาแทน
	  ShadowVeil (พ่อมดมืด Lv2) : ล่องหน + วิ่งเร็วขึ้น 50% 4 วิ · มอนมองไม่เห็น · ทำดาเมจ = หลุดล่องหน
	  DarkMeteor (พ่อมดมืด Lv3) : อุกกาบาตมืดตกตรงจุดที่เล็ง ดาเมจแรงวงกว้าง + วงไฟมืด 10 วิ เผา 2% เลือด/วิ
	  ThornBind (พงไพร Lv3)     : สตั้นมอนรอบตัว 4 วิ (บอส 2 วิ) + พิษ 1% เลือด/วิ 15 วิ
	ผู้เล่น: attribute "Skills" = รหัสสกิลที่ใช้ได้คั่นด้วย "," · "SkillReady_<Id>" = เวลาเซิร์ฟเวอร์ที่คูลดาวน์หมด
	ฝั่งเครื่องผู้เล่น: ClassSkill.lua (ช่องสกิลหน้าแถบของ · ปุ่ม Q / Z)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Classes)

local SkillService = {}

local BAT_COUNT, BAT_HP, BAT_DAMAGE, BAT_RANGE = 5, 200, 14, 48
local hurtBatRef -- = hurtBat (ประกาศด้านล่าง)
local swarms = {} -- [player] = { bats... }

local function now()
	return Workspace:GetServerTimeNow()
end

function SkillService:Init(ctx)
	self.ctx = ctx
	self.folder = Instance.new("Folder")
	self.folder.Name = "Summons"
	self.folder.Parent = Workspace
	self.groundParams = RaycastParams.new()
	self.groundParams.FilterType = Enum.RaycastFilterType.Include
	self.groundParams.FilterDescendantsInstances = { Workspace.Terrain }
end

-- สกิลที่ผู้เล่นคนนี้ใช้ได้ตอนนี้ (ต้องอยู่ในรอบ) -> { {Id, Cooldown, Icon}, ... }
function SkillService:SkillsOf(player)
	if not player:GetAttribute("InRun") then
		return {}
	end
	return Classes.ActiveSkills(player:GetAttribute("Class") or "Survivor", player:GetAttribute("ClassLevel") or 1)
end

function SkillService:SkillOf(player, id)
	for _, sk in ipairs(self:SkillsOf(player)) do
		if sk.Id == id then
			return sk
		end
	end
	return nil
end

function SkillService:Refresh(player)
	local ids = {}
	for _, sk in ipairs(self:SkillsOf(player)) do
		table.insert(ids, sk.Id)
	end
	player:SetAttribute("Skills", table.concat(ids, ","))
	if not self:SkillOf(player, "Swarm") then
		self:Dismiss(player) -- ไม่ใช่แวมไพร์เลเวล 3 แล้ว (เปลี่ยนคลาส/ออกจากรอบ) = ค้างคาวหาย
	end
	if not self:SkillOf(player, "ShadowVeil") then
		self:BreakVeil(player)
	end
end

local function rootOf(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

---------------------------------------------------------------- ค้างคาว (Swarm)
local function batModel()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	local src = props and props:FindFirstChild("VampBat")
	local m
	if src then
		m = src:Clone()
	else
		-- สำรอง: ตัวดำปีกแดงจากชิ้นพื้นฐาน (ถ้ายังไม่มีโมเดล Store)
		m = Instance.new("Model")
		local body = Instance.new("Part")
		body.Name = "Torso"
		body.Size = Vector3.new(0.6, 1.4, 0.6)
		body.Color = Color3.fromRGB(30, 26, 32)
		body.Parent = m
	end
	m.Name = "VampBat"
	pcall(function()
		m:ScaleTo(m:GetScale() * 1.6) -- ตัวใหญ่ขึ้น มองเห็นชัดตอนบินรอบตัว
	end)
	local torso = m:FindFirstChild("Torso") or m:FindFirstChildWhichIsA("BasePart", true)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = d ~= torso
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	m.PrimaryPart = torso
	-- ลอยด้วยแรง (เคลื่อนไหวลื่นบนเครื่องผู้เล่น ไม่กระตุกแบบย้ายตำแหน่งตรงๆ)
	local att = Instance.new("Attachment")
	att.Parent = torso
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 1e6
	ap.MaxVelocity = 70
	ap.Responsiveness = 30
	ap.Parent = torso
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e6
	ao.Responsiveness = 25
	ao.Parent = torso
	-- หลอดเลือดเล็กบนหัว
	local bb = Instance.new("BillboardGui")
	bb.Name = "HP"
	bb.Size = UDim2.fromOffset(46, 6)
	bb.StudsOffset = Vector3.new(0, 1.8, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 90
	bb.Parent = torso
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 10, 14)
	back.BorderSizePixel = 0
	back.Parent = bb
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(220, 40, 60)
	fill.BorderSizePixel = 0
	fill.Parent = back
	return m, torso, ap, ao, fill
end

-- ค้างคาวรับดาเมจแทนเจ้าของ: ตัวที่เลือดเหลือมากสุดรับ BAT_GUARD ของดาเมจ -> คืนดาเมจที่เหลือให้ผู้เล่น
local BAT_GUARD = 0.6
function SkillService:Absorb(player, amount)
	local best
	for _, b in ipairs(swarms[player] or {}) do
		if not b.Dead and b.Model.Parent and (not best or b.HP > best.HP) then
			best = b
		end
	end
	if not best then
		return amount
	end
	local take = amount * BAT_GUARD
	self.ctx.Remotes.Get("HitFx"):FireAllClients("BatGuard", { Bat = best.Torso, Player = player })
	hurtBatRef(self, best, take)
	return amount - take
end

-- ค้างคาวที่ยังอยู่ของผู้เล่นคนนี้ (ใช้ในเทส)
function SkillService:Bats(player)
	return swarms[player] or {}
end

function SkillService:Dismiss(player)
	local list = swarms[player]
	swarms[player] = nil
	for _, b in ipairs(list or {}) do
		b.Dead = true
		if b.Model.Parent then
			self.ctx.Remotes.Get("HitFx"):FireAllClients("Gust", { Position = b.Torso.Position, Radius = 4 })
			b.Model:Destroy()
		end
	end
end

-- ค้างคาวโดนมอนกัด: มอนที่ดุ (ไม่ใช่สัตว์เชื่อง) อยู่ชิด = เสียเลือดตามแรงของมอน
local function hurtBat(self, b, amount)
	b.HP -= amount
	b.Fill.Size = UDim2.fromScale(math.clamp(b.HP / BAT_HP, 0, 1), 1)
	if b.HP <= 0 and not b.Dead then
		b.Dead = true
		self.ctx.Remotes.Get("HitFx"):FireAllClients("Gust", { Position = b.Torso.Position, Radius = 4 })
		b.Model:Destroy()
	end
end
hurtBatRef = hurtBat

function SkillService:Swarm(player)
	self:Dismiss(player) -- กดใหม่ = ฝูงเดิมหาย
	local root = rootOf(player)
	if not root then
		return false
	end
	local list = {}
	for i = 1, BAT_COUNT do
		local m, torso, ap, ao, fill = batModel()
		local a = i / BAT_COUNT * math.pi * 2
		local start = root.Position + Vector3.new(math.cos(a) * 4, 5, math.sin(a) * 4)
		m:PivotTo(CFrame.new(start))
		ap.Position = start
		m:SetAttribute("Owner", player.UserId)
		m.Parent = self.folder
		pcall(function()
			torso:SetNetworkOwner(nil) -- เซิร์ฟเวอร์คุมทิศทาง (ทุกคนเห็นเหมือนกัน)
		end)
		table.insert(list, { Model = m, Torso = torso, Align = ap, Orient = ao, Fill = fill, HP = BAT_HP, Slot = a, NextBite = 0, NextHurt = 0 })
	end
	swarms[player] = list
	self.ctx.Remotes.Get("HitFx"):FireAllClients("SkillSwarm", { Position = root.Position, Player = player })
	return true
end

-- ทุก 0.1 วิ: บินตามเจ้าของ · มีมอนใกล้ = พุ่งไปกัด
function SkillService:TickBats()
	local animals = self.ctx.Services.AnimalService
	local combat = self.ctx.Services.CombatService
	local t = now()
	for player, list in pairs(swarms) do
		local root = rootOf(player)
		if not root or not player.Parent or not player:GetAttribute("InRun") then
			self:Dismiss(player)
			continue
		end
		local alive = {}
		for _, b in ipairs(list) do
			if not b.Dead and b.Model.Parent then
				table.insert(alive, b)
			end
		end
		if #alive == 0 then
			swarms[player] = nil
			continue
		end
		swarms[player] = alive
		for i, b in ipairs(alive) do
			local pos = b.Torso.Position
			local target = animals:Nearest(root.Position, BAT_RANGE, true)
			local goal
			if target and target.Root and not target.Dead then
				-- วนรอบเป้าแต่ละตัวคนละมุม
				local ang = b.Slot + t * 3
				goal = target.Root.Position + Vector3.new(math.cos(ang) * 3, 2.5, math.sin(ang) * 3)
				if (pos - target.Root.Position).Magnitude < 8 then
					if t >= b.NextBite then
						b.NextBite = t + 0.9
						combat:DamageAnimal(target, BAT_DAMAGE * self.ctx.Services.SurvivalService:Perk(player, "DamageMult", 1), player, { Source = "Summon" })
						self.ctx.Remotes.Get("HitFx"):FireAllClients("BatBite", { Position = target.Root.Position, From = pos })
					end
					-- มอนกัดกลับ
					if t >= b.NextHurt and target.Info.Behaviour ~= "Passive" then
						b.NextHurt = t + 1.2
						hurtBat(self, b, (target.Info.Damage or 10) * 0.6)
					end
				end
			else
				local ang = b.Slot + t * 1.2
				goal = root.Position + Vector3.new(math.cos(ang) * 5, 4 + math.sin(t * 2 + i) * 0.6, math.sin(ang) * 5)
			end
			if not b.Dead then
				b.Align.Position = goal
				local dir = (goal - pos) * Vector3.new(1, 0, 1)
				if dir.Magnitude > 0.5 then
					-- โมเดล Store ตั้งตรง (ห้อยหัว ปีกกางแกน X) -> เอนนอน หัว (+Y) ชี้ทางที่บิน ปีกกางราบ เห็นเต็มปีกจากกล้องด้านบน
					b.Orient.CFrame = CFrame.lookAt(Vector3.zero, dir.Unit) * CFrame.Angles(-math.pi / 2, 0, 0)
				end
			end
		end
	end
end

---------------------------------------------------------------- ล่องหน (ShadowVeil)
local VEIL_TIME = 4
local veils = {} -- [player] = { Token, Parts = { [part] = transparency เดิม } }

function SkillService:BreakVeil(player)
	local v = veils[player]
	if not v then
		return
	end
	veils[player] = nil
	for part, t in pairs(v.Parts) do
		if part.Parent then
			part.Transparency = t
		end
	end
	player:SetAttribute("Invisible", nil)
	player:SetAttribute("SkillSpeed", nil)
end

function SkillService:ShadowVeil(player)
	self:BreakVeil(player)
	local char = player.Character
	if not char then
		return false
	end
	local v = { Token = {}, Parts = {} }
	veils[player] = v
	for _, d in ipairs(char:GetDescendants()) do
		if (d:IsA("BasePart") or d:IsA("Decal")) and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
			v.Parts[d] = d.Transparency
			d.Transparency = 0.85 + d.Transparency * 0.15 -- เกือบใส (เพื่อนยังพอเห็นเงาจางๆ)
		end
	end
	player:SetAttribute("Invisible", true)
	player:SetAttribute("SkillSpeed", 1.5)
	self.ctx.Remotes.Get("HitFx"):FireAllClients("SkillVeil", { Position = char:GetPivot().Position, Player = player })
	local token = v.Token
	task.delay(VEIL_TIME, function()
		if veils[player] and veils[player].Token == token then
			self:BreakVeil(player)
		end
	end)
	return true
end

---------------------------------------------------------------- อุกกาบาตมืด (DarkMeteor)
local DM_RADIUS, DM_ZONE, DM_ZONE_TIME = 16, 14, 10
function SkillService:DarkMeteor(player, aim)
	local root = rootOf(player)
	if not root then
		return false
	end
	local center = root.Position + root.CFrame.LookVector * 30
	if typeof(aim) == "Vector3" and (aim - root.Position).Magnitude < 120 then
		center = aim
	end
	local hit = Workspace:Raycast(center + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), self.groundParams)
	if hit then
		center = hit.Position
	end
	local surv = self.ctx.Services.SurvivalService
	local animals = self.ctx.Services.AnimalService
	local combat = self.ctx.Services.CombatService
	self.ctx.Remotes.Get("HitFx"):FireAllClients("SkillDarkMeteor", { Position = center, Radius = DM_RADIUS, Zone = DM_ZONE, Duration = DM_ZONE_TIME })
	task.delay(1.1, function() -- ตรงกับลูกตกฝั่ง client (ClassFX: fall 1.1 วิ)
		-- ตกกระแทก: ดาเมจแรงวงกว้าง
		local dmg = 160 * surv:Perk(player, "DamageMult", 1)
		for _, a in ipairs(animals:InRadius(center, DM_RADIUS, false)) do
			if a.Kind ~= "Spirit" then
				combat:DamageAnimal(a, dmg, player, { Source = "Skill" })
			end
		end
		-- วงไฟมืด: เผา 2% เลือดสูงสุด/วิ
		local stop = os.clock() + DM_ZONE_TIME
		while os.clock() < stop do
			for _, a in ipairs(animals:InRadius(center, DM_ZONE, true)) do
				combat:DamageAnimal(a, a.Hum.MaxHealth * 0.02, player, { Source = "Skill", Silent = true })
			end
			task.wait(1)
		end
	end)
	return true
end

---------------------------------------------------------------- พันธนาการหนาม (ThornBind)
local TB_RADIUS = 26
function SkillService:ThornBind(player)
	local root = rootOf(player)
	if not root then
		return false
	end
	local t = os.clock()
	for _, a in ipairs(self.ctx.Services.AnimalService:InRadius(root.Position, TB_RADIUS, true)) do
		local boss = a.Kind == "Boss" or a.Info.Behaviour == "Boss"
		local stun = boss and 2 or 4
		a.StunUntil = t + stun
		a.PoisonUntil = t + 15
		a.PoisonPct = 0.01
		a.PoisonBy = player
		self.ctx.Remotes.Get("HitFx"):FireAllClients("SkillThornMark", { Model = a.Model, Stun = stun, Poison = 15 })
	end
	self.ctx.Remotes.Get("HitFx"):FireAllClients("SkillThornBind", { Position = root.Position, Radius = TB_RADIUS, Player = player })
	return true
end

---------------------------------------------------------------- ใช้สกิล
function SkillService:Use(player, id, aim)
	local sk = type(id) == "string" and self:SkillOf(player, id)
	if not sk or self.ctx.Services.SurvivalService:IsIncapacitated(player) then
		return false
	end
	local key = "SkillReady_" .. sk.Id
	if now() < (player:GetAttribute(key) or 0) then
		return false
	end
	local ok = false
	if sk.Id == "Swarm" then
		ok = self:Swarm(player)
	elseif sk.Id == "ShadowVeil" then
		ok = self:ShadowVeil(player)
	elseif sk.Id == "DarkMeteor" then
		ok = self:DarkMeteor(player, aim)
	elseif sk.Id == "ThornBind" then
		ok = self:ThornBind(player)
	end
	if ok then
		player:SetAttribute(key, now() + sk.Cooldown)
	end
	return ok
end

function SkillService:Start(ctx)
	ctx.Remotes.Get("UseSkill").OnServerEvent:Connect(function(player, id, aim)
		self:Use(player, id, aim)
	end)
	local function hook(player)
		for _, a in ipairs({ "Class", "ClassLevel", "InRun" }) do
			player:GetAttributeChangedSignal(a):Connect(function()
				self:Refresh(player)
			end)
		end
		self:Refresh(player)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(hook, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		self:Dismiss(p)
		veils[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(self.TickBats, self)
			if not ok then
				warn("[AS] Skill bats:", err)
			end
		end
	end)
end

return SkillService
