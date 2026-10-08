--[[
	SurvivalService — ความหิว, เลือด, ล้ม/ช่วยเพื่อน, ตาย/เกิดใหม่, คลาส, กินอาหาร
	ดาเมจใส่ผู้เล่นทุกชนิดต้องผ่าน SurvivalService:Damage() (ระบบล้มจะได้ทำงาน)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Classes = require(ReplicatedStorage.Shared.Classes)

local SurvivalService = {}
local state = {} -- [player] = { Downed, DownedAt, Dead, Burn, LastHit }

function SurvivalService:Init(ctx)
	self.ctx = ctx
end

function SurvivalService:Perk(player, name, default)
	local v = Classes.PerksFor(player:GetAttribute("Class") or "Survivor", player:GetAttribute("ClassLevel") or 1)[name]
	if v == nil then
		return default
	end
	return v
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

function SurvivalService:IsDowned(player)
	return state[player] and state[player].Downed
end

---------------------------------------------------------------- ดาเมจ
function SurvivalService:Damage(player, amount, source, opts)
	local s = state[player]
	local hum, char = humanoidOf(player)
	if not (s and hum and char) or s.Dead or s.Downed or hum.Health <= 0 then
		return
	end
	if char:FindFirstChildOfClass("ForceField") then
		return
	end
	amount *= self:Perk(player, "DamageTakenMult", 1)
	s.LastHit = os.clock()
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
function SurvivalService:Down(player, source)
	local s = state[player]
	local hum, char = humanoidOf(player)
	if not (s and hum and char) then
		return
	end
	s.Downed = true
	s.DownedAt = os.clock()
	player:SetAttribute("Downed", true)
	player:SetAttribute("DownedUntil", Workspace:GetServerTimeNow() + Config.DownedTime)
	hum.WalkSpeed = 3
	hum.JumpPower = 0
	self.ctx.Broadcast(string.format("💀 %s ล้มลงแล้ว! ใช้ผ้าพันแผลช่วยด่วน", player.DisplayName), "Danger")
	self.ctx.Remotes.Get("Cinematic"):FireClient(player, "Downed", { Time = Config.DownedTime })
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
		prompt.Triggered:Connect(function(helper)
			if helper == player or not self:IsAlive(helper) then
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
			self:Revive(player, used == "Medkit" and 0.8 or 0.4 * self:Perk(helper, "HealMult", 1))
			self.ctx.Broadcast(string.format("✨ %s ช่วยชีวิต %s ได้ทัน!", helper.DisplayName, player.DisplayName), "Good")
		end)
	end
	self:CheckWipe()
end

function SurvivalService:Revive(player, frac)
	local s = state[player]
	local hum, char = humanoidOf(player)
	if not (s and hum) then
		return
	end
	s.Downed = false
	player:SetAttribute("Downed", false)
	hum.Health = hum.MaxHealth * math.clamp(frac or 0.4, 0.1, 1)
	hum.WalkSpeed = Config.BaseWalkSpeed * self:Perk(player, "SpeedMult", 1)
	hum.JumpPower = 50
	local prompt = char and char:FindFirstChild("Revive", true)
	if prompt then
		prompt:Destroy()
	end
	self.ctx.Remotes.Get("Cinematic"):FireClient(player, "Revived", {})
end

function SurvivalService:Die(player)
	local s = state[player]
	local hum = humanoidOf(player)
	if not s then
		return
	end
	s.Downed = false
	s.Dead = true
	player:SetAttribute("Downed", false)
	player:SetAttribute("Dead", true)
	if hum then
		hum.Health = 0
	end
	self.ctx.Remotes.Get("Cinematic"):FireClient(player, "Died", {})
	self.ctx.Broadcast(string.format("☠ %s สิ้นชีพแล้ว...", player.DisplayName), "Danger")
	self:CheckWipe()
	-- เกิดใหม่: กลางวันเกิดเร็ว / กลางคืนรอเช้า หรือมีเตียง
	task.spawn(function()
		local waited = 0
		while player.Parent do
			task.wait(1)
			waited += 1
			local phase = self.ctx.State:GetAttribute("Phase")
			local hasBed = self.ctx.Services.BuildingService and self.ctx.Services.BuildingService:FindBed()
			if self.ctx.State:GetAttribute("Phase") == "Ended" then
				return
			end
			if not player:GetAttribute("InRun") or (phase ~= "Night" and waited >= 6) or (hasBed and waited >= 20) then
				break
			end
		end
		if player.Parent and s.Dead then
			self:Spawn(player)
		end
	end)
end

-- ทุกคนล้ม/ตายพร้อมกัน "ตอนกลางคืน" = จบเกม (กลางวันตายแล้วเกิดใหม่ที่แคมป์)
function SurvivalService:CheckWipe()
	if self.ctx.State:GetAttribute("Phase") ~= "Night" then
		return
	end
	local anyAlive = false
	local count = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InRun") then
			count += 1
			if self:IsAlive(p) then
				anyAlive = true
			end
		end
	end
	if count > 0 and not anyAlive then
		task.delay(1.5, function()
			-- เช็กซ้ำ (เผื่อมีคนลุกทัน)
			for _, p in ipairs(Players:GetPlayers()) do
				if p:GetAttribute("InRun") and self:IsAlive(p) then
					return
				end
			end
			local downedOnly = false
			for _, p in ipairs(Players:GetPlayers()) do
				if self:IsDowned(p) then
					downedOnly = true
				end
			end
			-- ถ้ายังมีคนล้มรอช่วยอยู่ ให้รอจนหมดเวลา
			if downedOnly then
				return
			end
			self.ctx.Services.DirectorService:GameOver()
		end)
	end
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
	local bed = self.ctx.Services.BuildingService and self.ctx.Services.BuildingService:FindBed()
	if bed then
		return bed:GetPivot().Position + Vector3.new(0, 4, 0)
	end
	local camp = self.ctx.CampPosition
	local a = math.random() * math.pi * 2
	return camp + Vector3.new(math.cos(a) * 14, 4, math.sin(a) * 14)
end

function SurvivalService:OnCharacter(player, char)
	local hum = char:WaitForChild("Humanoid")
	local root = char:WaitForChild("HumanoidRootPart")
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = 100
	hum.Health = 100
	hum.WalkSpeed = Config.BaseWalkSpeed * self:Perk(player, "SpeedMult", 1)
	local pos = self:SpawnPoint(player)
	-- ล็อบบี้อยู่ไกลจากแมพมาก (StreamingEnabled): ตรึงตัวไว้จนพื้นตรงจุดเกิดโหลดถึงเครื่องผู้เล่น ไม่งั้นตกทะลุโลก
	root.Anchored = true
	task.defer(function()
		local look = player:GetAttribute("InRun") and self.ctx.CampPosition + Vector3.new(0, 4, 0) or pos + Vector3.new(0, 0, -10)
		root.CFrame = CFrame.new(pos, Vector3.new(look.X, pos.Y, look.Z))
		pcall(function()
			player:RequestStreamAroundAsync(pos, 8)
		end)
		task.wait(0.6)
		if root.Parent then
			root.Anchored = false
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
	player:SetAttribute("Hunger", Config.HungerMax)
	for id, n in pairs(c.StartItems) do
		self.ctx.Services.InventoryService:Add(player, id, n, true)
	end
end

-- เริ่มรอบใหม่ (หลังจบเกม) -> กลับล็อบบี้
function SurvivalService:ResetPlayer(player)
	player:SetAttribute("InRun", false)
	player:SetAttribute("StartItemsGiven", false)
	player:SetAttribute("Hunger", Config.HungerMax)
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
			self:Heal(player, item.Heal)
		elseif item.Heal and item.Heal < 0 then
			self:Damage(player, -item.Heal, "Food")
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
	end)

	-- ความหิว / ไฟไหม้ / หมดเวลาล้ม
	task.spawn(function()
		local dt = 0.5
		while true do
			task.wait(dt)
			for _, player in ipairs(Players:GetPlayers()) do
				local s = state[player]
				local hum, char = humanoidOf(player)
				if s and hum and char and hum.Health > 0 and not s.Dead and player:GetAttribute("InRun") then
					if s.Downed then
						if os.clock() - s.DownedAt > Config.DownedTime then
							self:Die(player)
						end
					else
						-- หิว (นอกเขตกองไฟที่มองไม่เห็น = หิวเร็วขึ้น)
						local mult = self:Perk(player, "HungerMult", 1)
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
					end
				end
			end
		end
	end)
end

return SurvivalService
