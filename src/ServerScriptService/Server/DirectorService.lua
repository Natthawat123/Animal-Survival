--[[
	DirectorService — ผู้กำกับ 99 คืน
	  กลางวัน (สำรวจ/เก็บของ) -> พลบค่ำ (เตือน) -> กลางคืน (ฝูงบุกเป็นระลอก + กวางกลวง + บอส) -> เช้า
	  รอดครบ 99 คืน = ฉากจบ (ช่วยลูกสัตว์ธาตุครบ 4 = จบแบบสมบูรณ์)
	  ทุกคนตาย = YOU PERISHED -> เริ่มรอบใหม่
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Nights = require(ReplicatedStorage.Shared.Nights)
local Animals = require(ReplicatedStorage.Shared.Animals)
local Classes = require(ReplicatedStorage.Shared.Classes)

local DirectorService = {}

local ELEMENT_THAI = { Earth = "ปฐพี", Water = "วารี", Air = "วายุ", Fire = "อัคคี", All = "ทุกธาตุ" }

function DirectorService:Init(ctx)
	self.ctx = ctx
	self.running = false
	self.rng = Random.new(ctx.Seed + 99)
	self.runId = 0
	self.night = 1
	self.lastElement = nil
end

function DirectorService:SetPhase(phase, length)
	local s = self.ctx.State
	local now = Workspace:GetServerTimeNow()
	s:SetAttribute("Phase", phase)
	s:SetAttribute("PhaseStart", now)
	s:SetAttribute("PhaseEnd", now + (length or 0))
	s:SetAttribute("PhaseLength", length or 0)
end

-- รอแบบยกเลิกได้ (ถ้าเริ่มรอบใหม่)
function DirectorService:Wait(seconds, runId)
	local t = 0
	while t < seconds do
		local dt = task.wait(0.25)
		if runId ~= self.runId then
			return false
		end
		if self.skip then -- DEV: ข้ามช่วงนี้
			self.skip = false
			return true
		end
		if self.paused then -- DEV: หยุดเวลา (เลื่อนเวลาสิ้นสุดช่วงออกไปด้วย ให้นาฬิกาบนจอหยุด)
			local s = self.ctx.State
			s:SetAttribute("PhaseStart", (s:GetAttribute("PhaseStart") or 0) + dt)
			s:SetAttribute("PhaseEnd", (s:GetAttribute("PhaseEnd") or 0) + dt)
		else
			t += dt
		end
	end
	return true
end

function DirectorService:SpawnRaid(id, plan, night)
	local layout = self.ctx.Layout
	local animals = self.ctx.Services.AnimalService
	local info = Animals.Data[id]
	local element = info.Element
	local pos = layout:RaidSpawnPoint(self.rng, Config.RaidSpawnRadius.Min, Config.RaidSpawnRadius.Max, element)
	local scale = Nights.Scale(night)
	if info.Behaviour == "Boss" then
		local a = animals:Spawn(id, pos, {
			Kind = "Boss", HealthMult = 1 + night * 0.004, DamageMult = 1, Night = night,
		})
		if a then
			a.Model:SetAttribute("IsBoss", true)
			local s = self.ctx.State
			s:SetAttribute("BossId", id)
			s:SetAttribute("BossHP", a.Hum.MaxHealth)
			s:SetAttribute("BossMaxHP", a.Hum.MaxHealth)
			self.ctx.Remotes.Get("Cinematic"):FireAllClients("BossIntro", { Model = a.Model, Id = id, Name = info.Name, Thai = info.Thai, Element = info.Element })
		end
		return a
	end
	return animals:Spawn(id, pos, {
		Kind = "Raid", HealthMult = scale.Health, DamageMult = scale.Damage, SpeedMult = scale.Speed, Night = night,
	})
end

function DirectorService:RunNight(night, runId)
	local ctx = self.ctx
	local s = ctx.State
	local element = Nights.PickElement(night, self.rng, self.lastElement)
	self.lastElement = element
	local plan = Nights.Plan(night, self.rng, element)
	s:SetAttribute("NightElement", plan.Element)
	s:SetAttribute("BloodMoon", plan.BloodMoon)
	self:SetPhase("Night", Config.NightLength)
	local title = Nights.Named[night] or ("คืนแห่ง" .. (ELEMENT_THAI[plan.Element] or ""))
	ctx.Remotes.Get("Cinematic"):FireAllClients("NightStart", {
		Night = night, Element = plan.Element, BloodMoon = plan.BloodMoon, Boss = plan.Boss, Title = title,
	})
	local total = 0
	for _, w in ipairs(plan.Waves) do
		total += #w.Spawns
	end
	s:SetAttribute("RaidTotal", total)

	-- กวางกลวงออกล่า
	task.delay(Config.NightLength * 0.12, function()
		if runId ~= self.runId or s:GetAttribute("Phase") ~= "Night" then
			return
		end
		local animals = ctx.Services.AnimalService
		if animals:CountKind("Stalker") == 0 then
			local pos = ctx.Layout:RaidSpawnPoint(self.rng, 260, 340)
			animals:Spawn("HollowStag", pos, { Kind = "Stalker" })
			ctx.Broadcast("🦌 ...มีบางอย่างจ้องมองมาจากความมืด อยู่ใกล้แสงไฟไว้", "Danger")
		end
	end)

	-- ปล่อยฝูงเป็นระลอก
	for wi, wave in ipairs(plan.Waves) do
		task.delay(Config.NightLength * wave.At, function()
			if runId ~= self.runId or s:GetAttribute("Phase") ~= "Night" then
				return
			end
			if not wave.Boss then
				ctx.Broadcast(string.format("🐾 ฝูงสัตว์ระลอกที่ %d กำลังมุ่งหน้ามาที่กองไฟ!", wi), "Danger")
				ctx.Remotes.Get("Cinematic"):FireAllClients("WaveIncoming", { Wave = wi, Element = plan.Element })
			end
			for i, id in ipairs(wave.Spawns) do
				if runId ~= self.runId or s:GetAttribute("Phase") ~= "Night" then
					return
				end
				while ctx.Services.AnimalService.raidCount >= Config.MaxRaidAnimals do
					task.wait(1)
					if runId ~= self.runId or s:GetAttribute("Phase") ~= "Night" then
						return
					end
				end
				self:SpawnRaid(id, plan, night)
				if i % 3 == 0 then
					task.wait(0.4)
				end
			end
		end)
	end
	return self:Wait(Config.NightLength, runId)
end

function DirectorService:Dawn(night)
	local ctx = self.ctx
	local animals = ctx.Services.AnimalService
	-- ฝูงบุกและกวางกลวงหายไปกับแสงเช้า (บอสที่ยังไม่ตายจะหนีกลับ)
	animals:ClearKind("Raid", true)
	animals:ClearKind("Stalker", true)
	animals:ClearKind("Boss", true)
	ctx.State:SetAttribute("BossId", "")
	ctx.State:SetAttribute("BloodMoon", false)
	ctx.Remotes.Get("Cinematic"):FireAllClients("Dawn", { Night = night })
	-- รางวัล
	for _, p in ipairs(Players:GetPlayers()) do
		local data = ctx.Services.DataService:Get(p)
		if data then
			data.BestNight = math.max(data.BestNight or 0, night)
			if p:GetAttribute("InRun") then
				data.NightsTotal = (data.NightsTotal or 0) + 1
				ctx.Services.DataService:AddClassStat(p, "Nights", 1)
			end
		end
		local bonus = Classes.NightRewards[night]
		if bonus then
			ctx.Services.DataService:AddDiamonds(p, bonus, "รอดถึงคืนที่ " .. night)
		elseif night >= 3 then
			ctx.Services.DataService:AddDiamonds(p, 1, "รอดคืนที่ " .. night)
		end
		-- ช่วยเพื่อนที่ตายไปตอนกลางคืน
		if p:GetAttribute("Dead") and p:GetAttribute("InRun") then
			ctx.Services.SurvivalService:Spawn(p)
		end
	end
end

function DirectorService:Loop(runId)
	local ctx = self.ctx
	local s = ctx.State
	while runId == self.runId do
		local night = self.night
		s:SetAttribute("Night", night)
		-- กลางวัน
		local dayLen = Config.DayLength + (night == 1 and Config.FirstDayBonus or 0)
		self:SetPhase("Day", dayLen - Config.DuskLength)
		ctx.Remotes.Get("Cinematic"):FireAllClients("DayStart", { Day = night })
		ctx.Services.TraderService:OnDay(night)
		if not self:Wait(dayLen - Config.DuskLength, runId) then
			return
		end
		self:SetPhase("Dusk", Config.DuskLength)
		ctx.Broadcast("🌅 พระอาทิตย์กำลังตก... กลับไปที่กองไฟ!", "Warn")
		ctx.Remotes.Get("Cinematic"):FireAllClients("Dusk", { Night = night })
		if not self:Wait(Config.DuskLength, runId) then
			return
		end
		-- กลางคืน
		if not self:RunNight(night, runId) then
			return
		end
		self:Dawn(night)
		if night >= Config.TotalNights then
			self:Ending()
			return
		end
		self.night = night + 1
	end
end

function DirectorService:SpiritCount()
	local n = 0
	for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		if self.ctx.State:GetAttribute("Spirit" .. el) then
			n += 1
		end
	end
	return n
end

function DirectorService:Ending()
	local ctx = self.ctx
	local spirits = self:SpiritCount()
	local kind = spirits >= 4 and "True" or "Survived"
	self:SetPhase("Ended", 30)
	ctx.State:SetAttribute("Ending", kind)
	ctx.Services.AnimalService:ClearKind(nil, true)
	ctx.Remotes.Get("Cinematic"):FireAllClients("Ending", { Kind = kind, Spirits = spirits, Nights = Config.TotalNights })
	for _, p in ipairs(Players:GetPlayers()) do
		local data = ctx.Services.DataService:Get(p)
		if data then
			data.Wins = (data.Wins or 0) + 1
		end
		ctx.Services.DataService:AddDiamonds(p, kind == "True" and 300 or 100, "รอดชีวิตครบ 99 คืน")
	end
	task.delay(30, function()
		self:ResetRun()
	end)
end

function DirectorService:GameOver()
	local ctx = self.ctx
	if ctx.State:GetAttribute("Phase") == "Ended" then
		return
	end
	self.runId += 1
	self:SetPhase("Ended", 12)
	ctx.State:SetAttribute("Ending", "Defeat")
	ctx.Remotes.Get("Cinematic"):FireAllClients("GameOver", { Night = self.night })
	for _, p in ipairs(Players:GetPlayers()) do
		local data = ctx.Services.DataService:Get(p)
		if data then
			data.Runs = (data.Runs or 0) + 1
			data.BestNight = math.max(data.BestNight or 0, self.night - 1)
		end
	end
	task.delay(12, function()
		self:ResetRun()
	end)
end

function DirectorService:IsRunning()
	return self.running
end

-- เริ่มรอบ (เรียกจากประตูล็อบบี้)
function DirectorService:StartRun()
	if self.running then
		return
	end
	self.running = true
	self.runId += 1
	self.night = 1
	local runId = self.runId
	task.spawn(function()
		self:Loop(runId)
	end)
end

function DirectorService:ResetRun()
	local ctx = self.ctx
	self.running = false
	self.runId += 1
	self.night = 1
	self.lastElement = nil
	ctx.State:SetAttribute("Ending", "")
	ctx.State:SetAttribute("BossId", "")
	ctx.Services.AnimalService:ClearKind(nil, false)
	ctx.Services.BuildingService:Clear()
	ctx.Services.CampService:Reset()
	ctx.Services.SpiritService:Reset()
	ctx.Services.LootService:Reset()
	for _, p in ipairs(Players:GetPlayers()) do
		ctx.Services.SurvivalService:ResetPlayer(p)
	end
	ctx.Services.LobbyService:ReturnAll()
	self:SetPhase("Lobby", 0)
	ctx.Broadcast("🔥 ทุกคนกลับสู่ล็อบบี้ — เข้าประตูเพื่อเริ่มรอบใหม่", "Info")
end

function DirectorService:Start(ctx)
	ctx.State:SetAttribute("TotalNights", Config.TotalNights)
	self:SetPhase("Lobby", 0)
	-- ทดสอบอัตโนมัติ: ข้ามล็อบบี้ เริ่มรอบเลย
	if ReplicatedStorage:FindFirstChild("ASAutoTest") and not ReplicatedStorage:FindFirstChild("ASLobbyTest") then
		task.delay(2, function()
			for _, p in ipairs(Players:GetPlayers()) do
				ctx.Services.LobbyService:Depart(p)
			end
			self:StartRun()
		end)
	end
end

return DirectorService
