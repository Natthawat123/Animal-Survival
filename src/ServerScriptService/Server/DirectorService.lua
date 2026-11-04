--[[
	DirectorService — ผู้กำกับ 99 คืน
	  กลางวัน (สำรวจ/เก็บของ) -> พลบค่ำ (เตือน) -> กลางคืน (ฝูงบุกเป็นระลอก + กวางกลวง + บอส) -> เช้า
	  รอดครบ 99 คืน = ฉากจบ (ช่วยลูกสัตว์ธาตุครบ 4 = จบแบบสมบูรณ์)
	  ข้ามวัน (เตียง 2 + ศาลเจ้า 4 = +6): บวกจริงทุกครั้ง · คืนที่ถูกข้ามนับว่ารอด · บอส/คืนบุกใหญ่ของคืนนั้นย้ายมาคืนถัดไป · คืน 99 ข้ามไม่ได้
	  ทุกคนตาย = YOU PERISHED -> เริ่มรอบใหม่
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Nights = require(ReplicatedStorage.Shared.Nights)
local Animals = require(ReplicatedStorage.Shared.Animals)
local AnimalModels = require(ReplicatedStorage.Shared.AnimalModels)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Analytics = require(script.Parent.Analytics)

local DirectorService = {}

local ELEMENT_THAI = { Earth = "Earth", Water = "Water", Air = "Frost", Fire = "Fire", All = "All Elements" }

function DirectorService:Init(ctx)
	self.ctx = ctx
	self.running = false
	self.rng = Random.new(ctx.Seed + 99)
	self.runId = 0
	self.night = 1
	self.lastElement = nil
	self.pendingSkips = 0 -- สิทธิ์ข้ามวันที่รอบวกตอนเช้า (ใช้ตอนกลางคืน / คืน 99)
	self.carry = {} -- เหตุการณ์ของคืนที่ถูกข้าม รอลงคืนถัดไปที่เล่นจริง
	self.bonus = 0 -- เวลากลางวันที่ได้เพิ่ม (เข้าศาลเจ้า/วิหาร) รอบวกในลูป Wait
	self.pendingBonus = 0 -- ได้ตอนกลางคืน -> บวกให้กลางวันถัดไป
end

-- เวลาเพิ่ม (วินาที): กลางวัน/พลบค่ำ = ยืดออกไปทันที · กลางคืน = เก็บไว้บวกให้กลางวันถัดไป
function DirectorService:AddTime(seconds)
	if not self.running then
		return false
	end
	local phase = self.ctx.State:GetAttribute("Phase")
	if phase == "Day" or phase == "Dusk" then
		self.bonus += seconds
		return "now"
	end
	self.pendingBonus += seconds
	return "nextDay"
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
			self.skipped = true
			return true
		end
		if self.bonus > 0 then -- เข้าศาลเจ้า/วิหาร: ยืดเวลาช่วงนี้ (นาฬิกาบนจอขยับตาม)
			local s = self.ctx.State
			seconds += self.bonus
			s:SetAttribute("PhaseEnd", (s:GetAttribute("PhaseEnd") or 0) + self.bonus)
			s:SetAttribute("PhaseLength", (s:GetAttribute("PhaseLength") or 0) + self.bonus)
			self.bonus = 0
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
		-- เลือดบอสเพิ่มตามจำนวนคนที่ยังรอดในรอบ (1 คน = x1.0 · +25% ต่อคนที่เพิ่ม)
		local players = self.ctx.Services.SurvivalService:RunPlayerCount(true)
		local a = animals:Spawn(id, pos, {
			Kind = "Boss", HealthMult = (1 + night * 0.004) * Nights.BossHealthMult(players), DamageMult = 1, Night = night,
		})
		if a then
			a.Model:SetAttribute("IsBoss", true)
			local s = self.ctx.State
			s:SetAttribute("BossId", id)
			s:SetAttribute("BossHP", a.Hum.MaxHealth)
			s:SetAttribute("BossMaxHP", a.Hum.MaxHealth)
			animals:BeginIntro(a) -- ฉากเปิดตัว: ตรึงไว้ ~7 วิ
			self.ctx.FireRun("Cinematic", "BossIntro", { Model = a.Model, Id = id, Name = info.Name, Thai = info.Thai, Element = info.Element })
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
	-- งบฝูงบุกคูณตามจำนวนคนที่ยังรอดในรอบ (Nights.PlayerBudgetMult) — เพดาน Config.MaxRaidAnimals เท่าเดิม
	local players = ctx.Services.SurvivalService:RunPlayerCount(true)
	local plan = Nights.Plan(night, self.rng, element, players, self.carry)
	s:SetAttribute("NightElement", plan.Element)
	s:SetAttribute("BloodMoon", plan.BloodMoon)
	self:SetPhase("Night", Config.NightLength)
	local title = Nights.Named[plan.OriginNight or night] or ((plan.BigRaid and "Big Raid Night · " or "") .. "Night of " .. (ELEMENT_THAI[plan.Element] or ""))
	if Nights.IsEndless(night) then
		title = "♾ Endless · " .. title
	end
	ctx.FireRun("Cinematic", "NightStart", {
		Night = night, Element = plan.Element, BloodMoon = plan.BloodMoon, Boss = plan.Boss, Title = title, Endless = Nights.IsEndless(night),
		Elements = plan.Elements,
	})
	-- ฝูงบุกเฉพาะคืนบุกใหญ่ (ทุก 5 คืน + คืน 99) · คืนอื่นสงบ: บอกว่าอีกกี่คืนฝูงจะมา
	if not plan.BigRaid then
		local left = Nights.NextBigRaid(night) - night
		task.delay(6, function()
			if runId == self.runId then
				ctx.Broadcast(string.format("Big raid in %d nights", left), "Info")
			end
		end)
	end
	s:SetAttribute("NextRaidNight", plan.BigRaid and night or Nights.NextBigRaid(night))
	local total = 0
	for _, w in ipairs(plan.Waves) do
		total += #w.Spawns
	end
	s:SetAttribute("RaidTotal", total)

	-- จิ้งจอกจันทราออกล่า (เตือนทุกคนในรอบล่วงหน้า 5 วินาที: ขอบจอแดง + ป้าย + เสียง)
	local stalkerAt = Config.NightLength * 0.12
	local warnAt = math.max(0.5, stalkerAt - 5)
	task.delay(warnAt, function()
		if runId ~= self.runId or s:GetAttribute("Phase") ~= "Night" or ctx.Services.AnimalService:CountKind("Stalker") > 0 or not AnimalModels.Has("Moonfang") then
			return -- (ยังไม่มีโมเดลจิ้งจอก = ไม่เตือนหลอก)
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("InRun") and not p:GetAttribute("Dead") then
				ctx.Remotes.Get("Cinematic"):FireClient(p, "StalkerWarning", { In = math.max(0, stalkerAt - warnAt) })
			end
		end
	end)
	task.delay(stalkerAt, function()
		if runId ~= self.runId or s:GetAttribute("Phase") ~= "Night" then
			return
		end
		local animals = ctx.Services.AnimalService
		if animals:CountKind("Stalker") == 0 then
			local pos = ctx.Layout:RaidSpawnPoint(self.rng, 260, 340)
			if animals:Spawn("Moonfang", pos, { Kind = "Stalker" }) then
				ctx.Broadcast("Something is watching from the darkness", "Danger")
			end
		end
	end)

	-- ปล่อยฝูงเป็นระลอก
	self.nightBoss = nil
	for wi, wave in ipairs(plan.Waves) do
		task.delay(Config.NightLength * wave.At, function()
			if runId ~= self.runId or s:GetAttribute("Phase") ~= "Night" or #wave.Spawns == 0 then
				return
			end
			if not wave.Boss then
				ctx.Broadcast(string.format("Animal wave %d has arrived", wi), "Danger")
				ctx.FireRun("Cinematic", "WaveIncoming", { Wave = wi, Element = plan.Element })
			end
			for i, id in ipairs(wave.Spawns) do
				if runId ~= self.runId or s:GetAttribute("Phase") ~= "Night" then
					return
				end
				-- (บอสไม่ต้องรอคิวเพดานฝูง)
				while not wave.Boss and ctx.Services.AnimalService.raidCount >= Nights.MaxRaid(Config.MaxRaidAnimals, ctx.Services.SurvivalService:RunPlayerCount(true)) do
					task.wait(1)
					if runId ~= self.runId or s:GetAttribute("Phase") ~= "Night" then
						return
					end
				end
				local a = self:SpawnRaid(id, plan, night)
				if wave.Boss then
					self.nightBoss = a
				end
				if i % 3 == 0 then
					task.wait(0.4)
				end
			end
		end)
	end
	if not plan.Boss then
		return self:Wait(Config.NightLength, runId)
	end
	-- คืนบอส: ใกล้เช้าแล้วบอสยังไม่ตาย -> หยุดนาฬิกาไว้ก่อน (ท้องฟ้าไม่เริ่มสว่าง) ให้มีเวลาฆ่าทัน
	local holdAt = Config.NightLength * 0.85
	self.skipped = false
	if not self:Wait(holdAt, runId) then
		return false
	end
	if self.skipped then
		return true
	end
	if not self:HoldForBoss(runId) then
		return false
	end
	if self.skipped then
		return true
	end
	return self:Wait(Config.NightLength - holdAt, runId)
end

-- หยุดนาฬิกาจนบอสตาย หรือครบ Config.BossHoldMax
function DirectorService:HoldForBoss(runId)
	local boss = self.nightBoss
	if not boss or boss.Dead or boss.Removed then
		return true
	end
	local s = self.ctx.State
	local left = Config.BossHoldMax
	s:SetAttribute("BossHoldEnd", Workspace:GetServerTimeNow() + left)
	self.ctx.Broadcast("The boss is still alive — dawn is held back!", "Danger")
	while left > 0 and not boss.Dead and not boss.Removed do
		local dt = task.wait(0.25)
		if runId ~= self.runId then
			return false
		end
		if self.skip then
			self.skip = false
			self.skipped = true
			break
		end
		s:SetAttribute("PhaseStart", (s:GetAttribute("PhaseStart") or 0) + dt)
		s:SetAttribute("PhaseEnd", (s:GetAttribute("PhaseEnd") or 0) + dt)
		if self.paused then
			s:SetAttribute("BossHoldEnd", s:GetAttribute("BossHoldEnd") + dt)
		else
			left -= dt
		end
	end
	s:SetAttribute("BossHoldEnd", 0)
	return true
end

-- รางวัลรอดคืนนี้: เฉพาะคนที่ยังรอดอยู่ในรอบ (คนที่ตายแล้วไม่ได้ และไม่ได้เกิดใหม่)
function DirectorService:RewardNight(night)
	local ctx = self.ctx
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InRun") and not p:GetAttribute("Dead") then
			local data = ctx.Services.DataService:Get(p)
			if data then
				ctx.Services.DataService:SetBestNight(p, night)
				data.NightsTotal = (data.NightsTotal or 0) + 1
				ctx.Services.DataService:AddClassStat(p, "Nights", 1)
				Analytics.NightReached(p, night)
				if ctx.Services.QuestService then
					ctx.Services.QuestService:Progress(p, "Night", 1, night)
				end
			end
			local bonus = Classes.NightRewards[night]
			if bonus then
				ctx.Services.DataService:AddDiamonds(p, bonus, "Survived to night " .. night)
			elseif night > Config.TotalNights and night % 10 == 0 then
				ctx.Services.DataService:AddDiamonds(p, 10, "Endless mode night " .. night)
			elseif night >= 3 then
				ctx.Services.DataService:AddDiamonds(p, 1, "Survived night " .. night)
			end
		end
	end
end

function DirectorService:Dawn(night)
	local ctx = self.ctx
	local animals = ctx.Services.AnimalService
	-- จิ้งจอกจันทราหายไปกับแสงเช้า · ฝูงบุก/บอสที่ยังไม่ตาย "ไม่หาย" อยู่บุกแคมป์ต่อจนกว่าจะโดนฆ่า
	-- (กันหนีออกจากแคมป์ตอนฝูงบุกแล้วรอเช้าให้หายเอง — ทิ้งแคมป์ = กองไฟ/กำแพงโดนพัง)
	animals:ClearKind("Stalker", true)
	if animals:CountKind("Boss") == 0 then
		ctx.State:SetAttribute("BossId", "")
	end
	ctx.State:SetAttribute("BloodMoon", false)
	ctx.FireRun("Cinematic", "Dawn", { Night = night })
	self:RewardNight(night)
	local left = animals.raidCount + animals:CountKind("Boss")
	if left > 0 then
		task.delay(4, function()
			ctx.Broadcast(string.format("%d animals are still attacking the camp — kill them all!", left), "Danger")
		end)
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
		self.bonus += self.pendingBonus -- ได้เวลาเพิ่มตอนกลางคืน -> กลางวันนี้ยาวขึ้น
		self.pendingBonus = 0
		ctx.FireRun("Cinematic", "DayStart", { Day = night })
		ctx.Services.TraderService:OnDay(night)
		if not self:Wait(dayLen - Config.DuskLength, runId) then
			return
		end
		self:SetPhase("Dusk", Config.DuskLength)
		ctx.FireRun("Cinematic", "Dusk", { Night = night })
		if not self:Wait(Config.DuskLength, runId) then
			return
		end
		-- กลางคืน (เตียงอาจข้ามวันระหว่างกลางวัน -> คืนนี้เป็นคืนถัดไป)
		night = self.night
		if not self:RunNight(night, runId) then
			return
		end
		self:Dawn(night)
		if night == Config.TotalNights then
			self:Complete()
		end
		-- บอสที่ย้ายมาแต่คืนนี้มีบอสของตัวเองอยู่แล้ว -> เลื่อนไปคืนถัดไป · อย่างอื่นใช้ไปแล้ว
		local carry = self.carry
		self.carry = (carry.Boss and Nights.BossFor(night)) and { Boss = carry.Boss, BossNight = carry.BossNight } or {}
		if self.night == night then -- (DEV setNight กลางคืน = ใช้เลขที่ตั้งไว้)
			self.night = night + 1
		end
		self:ApplyPendingSkips()
	end
end

-- ผ่านคืนนี้โดยไม่ต้องเล่น: นับว่ารอด + เหตุการณ์ของคืนนี้ย้ายไปคืนถัดไปที่เล่นจริง
function DirectorService:PassNight()
	local night = self.night
	self:RewardNight(night)
	local boss = Nights.BossFor(night)
	if boss then
		self.carry.Boss, self.carry.BossNight = boss, night
	end
	if Nights.IsBloodMoon(night) then
		self.carry.BloodMoonNight = night
	end
	if Nights.IsBigRaid(night) then
		self.carry.BigRaid = true
	end
	self.night = night + 1
	self.ctx.State:SetAttribute("Night", self.night)
end

-- วันโบนัส (เตียง/ช่วยลูกสัตว์) ให้ HUD โชว์ "DAY 12 +3" + เอฟเฟกต์ "+1" บินเข้าเลขวัน
-- ต้องตั้งก่อน Night เปลี่ยน (เครื่องลูกค้าค้างเลขเดิมไว้ระหว่างเล่นเอฟเฟกต์)
function DirectorService:AddBonusDays(n, source)
	local st = self.ctx.State
	st:SetAttribute("BonusSource", source or "")
	st:SetAttribute("BonusFrom", self.night)
	st:SetAttribute("BonusDays", (st:GetAttribute("BonusDays") or 0) + n)
end

-- บวกสิทธิ์ที่เก็บไว้ (ตอนเช้า) · คืนสุดท้ายต้องเล่นจริง: ที่เหลือรอหลังจบคืน 99
function DirectorService:ApplyPendingSkips()
	local n, night = 0, self.night
	for _ = 1, self.pendingSkips do
		if night == Config.TotalNights then
			break
		end
		n += 1
		night += 1
	end
	if n > 0 then
		-- HUD โชว์ยอดรวม (นับแล้ว + ค้าง) ไปตั้งแต่ตอนได้มาแล้ว: ย้ายจากค้างไปนับแล้ว (ลดค้างก่อน ยอดรวมไม่กระโดด)
		-- BonusSource = "Pending" -> HUD ไม่เล่นเอฟเฟกต์ซ้ำ แค่เลขวันเด้ง
		self.ctx.State:SetAttribute("PendingDays", self.pendingSkips - n)
		self:AddBonusDays(n, "Pending")
	end
	local applied = 0
	while self.pendingSkips > 0 and self.night ~= Config.TotalNights do
		self.pendingSkips -= 1
		applied += 1
		self:PassNight()
		self.ctx.Services.TraderService:OnDay(self.night) -- ไม่ให้พลาดรอบพ่อค้า
	end
	self.ctx.State:SetAttribute("PendingDays", self.pendingSkips)
	if applied > 0 then
		self.ctx.Broadcast(string.format("Skipped %d days · Day %d", applied, self.night), "Good")
	end
end

-- เตียง/ศาลเจ้าใช้ได้ตลอดรอบ
function DirectorService:CanSkipDay()
	return self.running and self.ctx.State:GetAttribute("Phase") ~= "Ended"
end

-- +1 วันจริงทุกครั้ง: กลางวัน/พลบค่ำมีผลทันที · กลางคืน (และวันที่ 99) เก็บไว้บวกตอนเช้า
-- fmt: ข้อความประกาศเอง (มี %d = วันที่) เช่น ช่วยลูกสัตว์ธาตุสำเร็จ · ไม่ใส่ = ข้อความเตียง
-- source: ชื่อที่ HUD โชว์ใต้ "+1" ("Bed" / "Spirit Pup")
-- n = กี่วัน (เตียง 1 · ลูกสัตว์ธาตุ Config.SpiritBonusDays) · ถึงคืน 99 แล้วหยุด ที่เหลือเก็บไว้บวกหลังเล่นคืน 99
-- fmt: string (มี %d = วันที่) หรือ function(วันที่ข้าม, วันที่) -> ข้อความ
function DirectorService:SkipDay(player, fmt, source, n)
	if not self:CanSkipDay() then
		return false
	end
	n = math.max(1, math.floor(tonumber(n) or 1))
	local phase = self.ctx.State:GetAttribute("Phase")
	local now = 0
	if phase == "Day" or phase == "Dusk" then
		local night = self.night
		for _ = 1, n do
			if night == Config.TotalNights then
				break -- คืนสุดท้ายต้องเล่นจริง
			end
			now += 1
			night += 1
		end
	end
	if now > 0 then
		self:AddBonusDays(now, source)
		for _ = 1, now do
			self:PassNight()
			if phase == "Day" then
				self.ctx.Services.TraderService:OnDay(self.night) -- ไม่ให้พลาดรอบพ่อค้า
			end
		end
		if type(fmt) == "function" then
			self.ctx.Broadcast(fmt(now, self.night), "Good")
		elseif fmt then
			self.ctx.Broadcast(string.format(fmt, self.night), "Good")
		elseif now == 1 then
			self.ctx.Broadcast(string.format("%s skipped 1 day · Day %d", player and player.DisplayName or "The team", self.night), "Good")
		else
			self.ctx.Broadcast(string.format("%s skipped %d days · Day %d", player and player.DisplayName or "The team", now, self.night), "Good")
		end
	end
	local later = n - now
	if later > 0 then
		self.pendingSkips += later
		self.ctx.State:SetAttribute("PendingSource", source or "")
		self.ctx.State:SetAttribute("PendingDays", self.pendingSkips)
		local when = self.night == Config.TotalNights and "after the final night" or "in the morning"
		if later == 1 then
			self.ctx.Broadcast(string.format("+1 Day (counted %s)", when), "Good")
		else
			self.ctx.Broadcast(string.format("x%d days (counted %s)", later, when), "Good")
		end
	end
	return true
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

-- รอดครบ 99 คืน: ฉลอง + รางวัล แล้วเล่นต่อ (โหมดไร้ขีดจำกัด)
function DirectorService:Complete()
	local ctx = self.ctx
	local spirits = self:SpiritCount()
	local kind = spirits >= 4 and "True" or "Survived"
	ctx.State:SetAttribute("Conquered", true)
	ctx.FireRun("Cinematic", "Ending", { Kind = kind, Spirits = spirits, Nights = Config.TotalNights, Continue = true })
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InRun") and not p:GetAttribute("Dead") then
			local data = ctx.Services.DataService:Get(p)
			if data then
				data.Wins = (data.Wins or 0) + 1
				if kind == "True" then
					data.TrueEndings = (data.TrueEndings or 0) + 1
				end
			end
			ctx.Services.DataService:AddDiamonds(p, kind == "True" and 300 or 100, "Conquer 99 Nights")
			ctx.Services.DataService:CheckBadges(p)
			ctx.Services.DataService:Save(p)
		end
	end
	ctx.Broadcast("Endless mode · Packs get stronger every night", "Reward")
end

function DirectorService:GameOver()
	local ctx = self.ctx
	if ctx.State:GetAttribute("Phase") == "Ended" or not self.running then
		return
	end
	self.runId += 1
	self:SetPhase("Ended", 12)
	ctx.State:SetAttribute("Ending", "Defeat")
	ctx.State:SetAttribute("BossId", "")
	local survived = self.night - 1
	local teamSize = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InRun") then
			teamSize += 1
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InRun") then
			local data = ctx.Services.DataService:Get(p)
			if data then
				data.Runs = (data.Runs or 0) + 1
			end
			ctx.Remotes.Get("Cinematic"):FireClient(p, "GameOver", {
				Night = self.night, Survived = survived, Best = data and data.BestNight or survived, Conquered = ctx.State:GetAttribute("Conquered"),
			})
			Analytics.Custom(p, "GameOverNight", self.night, { p:GetAttribute("Class") or "Survivor", tostring(teamSize) })
			Analytics.Custom(p, "TeamWipe", self.night, { tostring(teamSize) })
			Analytics.NightFailed(p, self.night)
			ctx.Services.DataService:Save(p)
		end
	end
	ctx.Services.AnimalService:ClearKind("Raid", true)
	ctx.Services.AnimalService:ClearKind("Stalker", true)
	task.delay(12, function()
		self:EndRun()
	end)
end

-- จบรอบ: เซิร์ฟเวอร์ของทีม (มาจากล็อบบี้หลัก) = ส่งทุกคนกลับล็อบบี้หลัก / ที่อื่น (Studio) = กลับล็อบบี้ในเซิร์ฟเวอร์นี้
function DirectorService:EndRun()
	local lobby = self.ctx.Services.LobbyService
	if lobby.IsTeamServer and lobby:ReturnToMainLobby(Players:GetPlayers(), { Result = "Defeat", Night = self.night }) then
		-- กันพลาด: ส่งไม่สำเร็จ (Roblox ล่ม ฯลฯ) -> กลับล็อบบี้ในเซิร์ฟเวอร์นี้แทน
		task.delay(20, function()
			if #Players:GetPlayers() > 0 and self.ctx.State:GetAttribute("Phase") == "Ended" then
				self:ResetRun()
			end
		end)
		return
	end
	self:ResetRun()
end

function DirectorService:IsRunning()
	return self.running
end

-- เริ่มรอบ (เรียกจากประตูล็อบบี้)
-- pendingSkips / carry: มาจากรอบที่เก็บไว้ (RejoinService)
function DirectorService:StartRun(night, pendingSkips, carry)
	if self.running then
		return
	end
	self.running = true
	self.runId += 1
	self.night = math.max(1, math.floor(tonumber(night) or 1))
	self.pendingSkips = math.max(0, math.floor(tonumber(pendingSkips) or 0))
	self.carry = type(carry) == "table" and carry or {}
	self.ctx.State:SetAttribute("PendingDays", self.pendingSkips)
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
	self.pendingSkips = 0
	self.carry = {}
	self.bonus, self.pendingBonus = 0, 0
	self.nightBoss = nil
	ctx.State:SetAttribute("BossHoldEnd", 0)
	ctx.State:SetAttribute("BedsUsed", 0)
	ctx.State:SetAttribute("Bed2Used", 0)
	ctx.State:SetAttribute("BonusDays", 0)
	ctx.State:SetAttribute("PendingDays", 0)
	ctx.State:SetAttribute("Ending", "")
	ctx.State:SetAttribute("Conquered", false)
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
	ctx.Broadcast("Back to the lobby", "Info")
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
