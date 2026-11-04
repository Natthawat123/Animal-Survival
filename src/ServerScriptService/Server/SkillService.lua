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
local BAT_KILL_HEAL = 0.05 -- ค้างคาวฆ่ามอนได้ 1 ตัว = เจ้าของได้เลือดคืน 5% ของเลือดสูงสุด
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
		-- ข้อต่อปีกเดิมของโมเดลเก่า (C0/C1 ไม่ตรงท่ากาง) ดึงปีกพับเข้าตัวตอนบินจริง -> สร้างใหม่ให้ท่าพัก = ปีกกางเหมือนในโมเดล
		-- บานพับอยู่ที่โคนปีก (ข้างลำตัว) หมุนรอบแกนตั้ง = กระพือ (ClassSkill ใส่ Transform)
		local body = m:FindFirstChild("Torso")
		if body then
			for _, j in ipairs(m:GetDescendants()) do
				if j:IsA("JointInstance") then
					j:Destroy()
				end
			end
			for _, w in ipairs(m:GetChildren()) do
				if w:IsA("BasePart") and w ~= body and w.Name:find("Wing") then
					local loc = body.CFrame:PointToObjectSpace(w.Position)
					local side = loc.X >= 0 and 1 or -1
					local hinge = body.CFrame * CFrame.new(side * body.Size.X * 0.4, loc.Y, loc.Z)
					local j = Instance.new("Motor6D")
					j.Name = (w.Name:find("Left") and "Left" or "Right") .. " Shoulder"
					j.Part0, j.Part1 = body, w
					j.C0 = body.CFrame:ToObjectSpace(hinge)
					j.C1 = w.CFrame:ToObjectSpace(hinge)
					j.Parent = body
				end
			end
		end
		-- ปีกเป็นแผ่นเมชหน้าเดียว (มองจากหลังแล้วหาย) -> ก๊อปกลับด้าน (Scale Z ติดลบ) เชื่อมติดปีกเดิม = เห็นทั้งสองด้าน
		for _, w in ipairs(m:GetChildren()) do
			local mesh = w:IsA("BasePart") and w.Name:find("Wing") and w:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				local back = w:Clone()
				for _, c in ipairs(back:GetChildren()) do
					if not c:IsA("SpecialMesh") then
						c:Destroy()
					end
				end
				back.Name = w.Name .. "Back"
				local bm = back:FindFirstChildOfClass("SpecialMesh")
				bm.Scale = bm.Scale * Vector3.new(1, 1, -1)
				back.Parent = m
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = w, back
				weld.Parent = back
			end
		end
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
		m:ScaleTo(m:GetScale() * 1.4) -- ตัวใหญ่ขึ้น มองเห็นชัด
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
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	for i = 1, BAT_COUNT do
		local m, torso, ap, ao, fill = batModel()
		local a = i / BAT_COUNT * math.pi * 2
		local start = root.Position + Vector3.new(math.cos(a) * 4, 5, math.sin(a) * 4)
		m:PivotTo(CFrame.lookAt(start, start + look))
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

-- จัดแถวหลังเจ้าของ: บน 3 ตัว ล่าง 2 ตัว (x = ซ้าย/ขวา, y = สูง)
local FORMATION = {
	Vector2.new(-6.6, 7.4), Vector2.new(0, 8), Vector2.new(6.6, 7.4),
	Vector2.new(-3.3, 4.4), Vector2.new(3.3, 4.4),
}
local FORM_BACK = 3

-- ทุก 0.1 วิ: บินตามเจ้าของเป็นแถว · มีมอนใกล้ = พุ่งไปกัด
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
						local deadBefore = target.Dead
						local tpos = target.Root.Position
						combat:DamageAnimal(target, BAT_DAMAGE * self.ctx.Services.SurvivalService:Perk(player, "DamageMult", 1), player, { Source = "Summon" })
						self.ctx.Remotes.Get("HitFx"):FireAllClients("BatBite", { Position = tpos, From = pos })
						if target.Dead and not deadBefore then
							local surv = self.ctx.Services.SurvivalService
							local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
							if hum then
								surv:Heal(player, hum.MaxHealth * BAT_KILL_HEAL)
							end
							self.ctx.Remotes.Get("HitFx"):FireAllClients("BatDrain", { Position = tpos, Player = player })
						end
					end
					-- มอนกัดกลับ
					if t >= b.NextHurt and target.Info.Behaviour ~= "Passive" then
						b.NextHurt = t + 1.2
						hurtBat(self, b, (target.Info.Damage or 10) * 0.6)
					end
				end
			end
			local face
			if goal then
				local dir = (goal - pos) * Vector3.new(1, 0, 1)
				face = dir.Magnitude > 0.5 and dir.Unit or nil
			else
				-- ไม่มีเป้า: เข้าแถวหลังเจ้าของ หันทางเดียวกับเจ้าของ
				local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
				look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
				local right = look:Cross(Vector3.yAxis)
				local f = FORMATION[(i - 1) % #FORMATION + 1]
				goal = root.Position - look * FORM_BACK + right * f.X + Vector3.new(0, f.Y + math.sin(t * 2.5 + i) * 0.35, 0)
				face = look
			end
			if not b.Dead then
				b.Align.Position = goal
				if face then
					-- โมเดล Store ตั้งตรง ปีกกางแกน X: บินตัวตั้ง เอนหน้าเล็กน้อย -> กล้องหลังตัวเห็นปีกกางเต็ม
					b.Orient.CFrame = CFrame.lookAt(Vector3.zero, face) * CFrame.Angles(-0.3, 0, 0)
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
local DM_RADIUS, DM_ZONE, DM_ZONE_TIME = 24, 20, 10
local DM_LOCK = 100 -- ล็อกเป้ามอนที่ใกล้ที่สุดในระยะนี้ (ไม่มี = ตกตรงที่เล็ง)
function SkillService:DarkMeteor(player, aim)
	local root = rootOf(player)
	if not root then
		return false
	end
	local surv = self.ctx.Services.SurvivalService
	local animals = self.ctx.Services.AnimalService
	local combat = self.ctx.Services.CombatService
	local function ground(p)
		local hit = Workspace:Raycast(p + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), self.groundParams)
		return hit and hit.Position or p
	end
	-- ล็อกเป้า: มอนที่ใกล้ที่สุด (ลูกอุกกาบาตตามตัวจนตก) · ไม่มีมอน = ตกตรงที่เล็ง/หน้าตัว
	local target = animals:Nearest(root.Position, DM_LOCK, true)
	local center
	if target and target.Root then
		center = target.Root.Position
	else
		center = root.Position + root.CFrame.LookVector * 30
		if typeof(aim) == "Vector3" and (aim - root.Position).Magnitude < 120 then
			center = aim
		end
	end
	center = ground(center)
	self.ctx.Remotes.Get("HitFx"):FireAllClients("SkillDarkMeteor", { Position = center, Radius = DM_RADIUS, Zone = DM_ZONE, Duration = DM_ZONE_TIME, Target = target and target.Model or nil })
	task.delay(1.1, function() -- ตรงกับลูกตกฝั่ง client (ClassFX: fall 1.1 วิ)
		if target and not target.Dead and target.Root and target.Root.Parent then
			center = ground(target.Root.Position) -- เป้าขยับระหว่างตก: ตกตรงตัวเป้า
		end
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
local TB_RADIUS = 42 -- วงกว้าง (AOE)
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
