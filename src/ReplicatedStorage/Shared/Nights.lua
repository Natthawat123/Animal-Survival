--[[
	Nights — ผู้กำกับฝูงบุก 99 คืน
	- ทุกคืนสุ่ม "ธาตุประจำคืน" (สัตว์ธาตุนั้นบุก)
	- ฝูงบุกทุก 5 "กลางคืนที่เล่นจริง" (ไม่ใช่เลขวัน — ตัวคูณ x วันไม่ทำให้บุกถี่) · คืนอื่นสงบ · ฝูงบุกไม่ดรอปของ
	- ฝูงบุกครั้งที่ 2, 4, 6 … (กลางคืนที่ 10, 20 …) = พระจันทร์เลือด (ครั้งแรก: 2-3 ธาตุ งบ x1.25 · ต่อจากนั้น: ทุกธาตุ งบ x1.5)
	- ดาเมจมอนไม่คูณตามคืน/จำนวนคน · บอสบุกแคมป์ปิดไว้ (Config.RaidBosses)
	- Monster Balance: เลือด/ดาเมจมอน "คงที่" ไม่คูณตามคืนและจำนวนคน · ความยากมาจาก "จำนวน + ชนิดมอน" ที่เพิ่มตามคืน
	- งบฝูงบุกคูณตามจำนวนคนที่ยังรอดในรอบ: x(1 + 0.15 × (คน − 1)) (1 คน = x1.0, 8 คน = x2.05) · เลือดบอส x(1 + 0.25 × (คน − 1))
	- ความเร็วมอนเพิ่มตามคืนได้สูงสุด +10%
	- คืน 25 / 50 / 75 / 99 = บอสธาตุบุกฐาน
	- หลังคืน 99 = โหมดไร้ขีดจำกัด (ฝูงแรงขึ้นเรื่อยๆ + บอสวนมาทุก 25 คืน)
]]

local Animals = require(script.Parent.Animals)
local Config = require(script.Parent.Config)

local Nights = {}

Nights.BossNights = { [25] = "Terragon", [50] = "Leviathan", [75] = "TempestRoc", [99] = "Solfang" }
local BOSS_CYCLE = { "Terragon", "Leviathan", "TempestRoc", "Solfang" }

-- บอสของคืนนี้ (หลังคืน 99 = โหมดไร้ขีดจำกัด: บอสวนกลับมาทุก Config.EndlessBossEvery คืน)
function Nights.BossFor(night)
	if not Config.RaidBosses then
		return nil -- ปิดบอสบุกแคมป์ (บอสยังสู้ได้ในรังของแต่ละไบโอม)
	end
	if Nights.BossNights[night] then
		return Nights.BossNights[night]
	end
	local total = Config.TotalNights
	local every = Config.EndlessBossEvery or 25
	if night > total and (night - total) % every == 0 then
		local i = ((night - total) // every - 1) % #BOSS_CYCLE + 1
		return BOSS_CYCLE[i]
	end
	return nil
end

function Nights.IsEndless(night)
	return night > Config.TotalNights
end

-- คืนพิเศษที่มีชื่อ
Nights.Named = {
	[1] = "First Night in the Woods",
	[10] = "First Blood Moon",
	[99] = "The Final Night",
}

-- ฝูงบุก/พระจันทร์เลือดนับจาก "กลางคืนที่เล่นจริง" (played) ไม่ใช่เลขวัน
Nights.RaidEvery = 5 -- ฝูงบุกทุก 5 กลางคืนที่เล่นจริง
function Nights.IsBloodMoon(played)
	return played % (Nights.RaidEvery * 2) == 0
end

-- ตัวคูณความแรงของสัตว์ตามคืน (ดาเมจไม่คูณตามคืนแล้ว — ตีเท่าเดิมทุกคืน)
function Nights.Scale(night)
	local n = math.max(night - 1, 0)
	return {
		Health = 1, -- Monster Balance: เลือดคงที่ทุกคืน
		Damage = 1,
		Speed = 1 + math.min(n * 0.003, 0.10), -- เร็วขึ้นได้สูงสุด +10%
	}
end

-- พระจันทร์เลือดครั้งแรก (คืน 10) เบากว่า: งบ x1.25 และมาแค่ 2-3 ธาตุ
Nights.FirstBloodMoon = 10
Nights.FirstBloodMoonMult = 1.25
Nights.BloodMoonMult = 1.5
-- คืนพระจันทร์เลือด: ม่อนบุกแคมป์ เลือด + ดาเมจ x1.5 (เฉพาะฝูงบุก · ไม่รวมสัตว์ป่า/ผู้เฝ้า/บอส)
Nights.BloodMoonPower = 1.5

-- จำนวนคนในตี้ที่ใช้คิดความยาก (รองรับสูงสุด 8)
Nights.MaxParty = 8
local function party(players)
	return math.clamp(players or 1, 1, Nights.MaxParty)
end

-- ตัวคูณจำนวนมอนบุก (งบ + เพดานต่อคืน) ตามจำนวนผู้เล่น: +15%/คน (1 = 1.0, 2 = 1.15, 4 = 1.45, 8 = 2.05)
function Nights.PlayerBudgetMult(players)
	return 1 + 0.15 * (party(players) - 1)
end

-- บอสแรงขึ้นตามจำนวนคนในรอบ: เลือด + ดาเมจ (ตีธรรมดา + ทุกสกิล) +25% ต่อคนที่เพิ่ม
--   1 คน = x1.0, 2 = x1.25, 3 = x1.5, 4 = x1.75, 5 = x2.0, 6 = x2.25, 7 = x2.5, 8 = x2.75
Nights.BossPartyStep = 0.25
function Nights.BossHealthMult(players)
	return 1 + Nights.BossPartyStep * (party(players) - 1)
end
function Nights.BossDamageMult(players)
	return 1 + Nights.BossPartyStep * (party(players) - 1)
end

-- (เดิม: มอนโหดขึ้นตามจำนวนคน · ตอนนี้คงที่ x1 — บอสใช้ BossHealthMult แทน)
function Nights.PartyScale(_players)
	return { Health = 1, Damage = 1 } -- Monster Balance: เลือด/ดาเมจไม่คูณตามจำนวนคน (คนเยอะ = มอนมาเยอะขึ้นแทน)
end

-- เพดานจำนวนมอนบุกพร้อมกันตามจำนวนคน (1 คน = base, 8 คน = base + 42)
function Nights.MaxRaid(base, players)
	return base + 3 * (party(players) - 1)
end

-- คืนบุก: ทุก Nights.RaidEvery กลางคืนที่เล่นจริง
function Nights.IsBigRaid(played)
	return played % Nights.RaidEvery == 0
end

-- กลางคืนที่บุกครั้งถัดไป (นับคืนนี้ด้วย) เป็นเลข played
function Nights.NextBigRaid(played)
	while not Nights.IsBigRaid(played) do
		played += 1
	end
	return played
end

-- bloodMoonNight = เลขคืนต้นทางของพระจันทร์เลือด (nil = ไม่ใช่คืนพระจันทร์เลือด)
function Nights.Budget(night, players, bloodMoonNight)
	local b = 1.5 + night * 0.5 + (night / 10) ^ 2 * 0.6 -- (เดิม 3 + n×1.35 + (n/10)²×2)
	if bloodMoonNight then
		b *= (bloodMoonNight == Nights.FirstBloodMoon) and Nights.FirstBloodMoonMult or Nights.BloodMoonMult
	end
	return b * Nights.PlayerBudgetMult(players)
end

-- เพดานจำนวนมอนทั้งคืน (กันยากเกินช่วงต้น · ปรับความยากรวมที่นี่): คืนยิ่งสูง มอนยิ่งเยอะ
function Nights.MaxCount(night, players)
	local n = 3 + night * 0.12 -- (เดิม 5 + n×0.4)
	return math.max(1, math.floor(n * Nights.PlayerBudgetMult(players)))
end

-- ธาตุประจำคืน (ไม่ซ้ำกับคืนก่อน) — rng = Random object
function Nights.PickElement(night, rng, previous)
	if night <= 2 then
		return "Earth"
	end
	local options = {}
	for _, e in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		if e ~= previous then
			table.insert(options, e)
		end
	end
	return options[rng:NextInteger(1, #options)]
end

--[[
	วางแผนคืน: คืนค่า
	{
		Element = "Fire" | "All",
		BloodMoon = bool,
		Elements = { "Earth", "Fire" } | nil,  -- เฉพาะพระจันทร์เลือดครั้งแรก (ธาตุที่บุกจริง)
		Boss = "Solfang" | nil,
		BigRaid = bool,
		OriginNight = 25,  -- คืนต้นทางของเหตุการณ์ที่ถูกย้ายมา (ไม่มี = night)
		Waves = { { At = 0.05, Spawns = { "EmberFox", "EmberFox", ... } }, ... }  -- At = สัดส่วนของเวลากลางคืน
	}
	carry = เหตุการณ์ของคืนที่ถูกข้าม (เตียง/ศาลเจ้า) ที่ย้ายมาคืนนี้: { Boss, BossNight, BloodMoonNight, BigRaid }
]]
function Nights.Plan(night, rng, element, players, carry)
	carry = carry or {}
	local ownBoss = Nights.BossFor(night)
	local played = carry.Played or night -- กลางคืนที่เล่นจริงครั้งที่เท่าไหร่ (ไม่มี = ใช้เลขวัน)
	local bloodMoonNight = Nights.IsBloodMoon(played) and played or nil -- (played 10 = พระจันทร์เลือดครั้งแรก แบบเบา)
	local plan = {
		Element = element,
		BloodMoon = bloodMoonNight ~= nil,
		Boss = ownBoss,
		BigRaid = Nights.IsBigRaid(played) or ownBoss ~= nil,
		OriginNight = nil,
		Waves = {},
	}
	local pools = {}
	if plan.BloodMoon and bloodMoonNight == Nights.FirstBloodMoon then
		-- พระจันทร์เลือดครั้งแรก: ธาตุประจำคืน + อีก 1-2 ธาตุ (ไม่ใช่ทุกธาตุ)
		plan.Element = "All"
		local picked = { element or "Earth" }
		local others = {}
		for _, e in ipairs({ "Earth", "Water", "Air", "Fire" }) do
			if e ~= picked[1] then
				table.insert(others, e)
			end
		end
		for _ = 1, rng:NextInteger(1, 2) do
			table.insert(picked, table.remove(others, rng:NextInteger(1, #others)))
		end
		plan.Elements = picked
		for _, e in ipairs(picked) do
			for _, id in ipairs(Animals.RaidPool[e] or {}) do
				table.insert(pools, id)
			end
		end
	elseif plan.BloodMoon or night == 99 then
		plan.Element = "All"
		for _, list in pairs(Animals.RaidPool) do
			for _, id in ipairs(list) do
				table.insert(pools, id)
			end
		end
	else
		for _, id in ipairs(Animals.RaidPool[element] or Animals.RaidPool.Earth) do
			table.insert(pools, id)
		end
	end
	-- กรองเฉพาะตัวที่ปลดล็อกแล้ว (MinNight)
	local available = {}
	for _, id in ipairs(pools) do
		local d = Animals.Data[id]
		if d and (d.MinNight or 1) <= night then
			table.insert(available, id)
		end
	end
	if #available == 0 then
		available = { "MossWolf" }
	end

	-- ระลอกต้องมาเร็วพอให้วิ่งถึงแคมป์ก่อนเช้า (ตัวช้าสุดใช้ ~25 วิ) · คืนที่ไม่ใช่คืนบุกใหญ่ = ไม่มีฝูง (บอสที่ย้ายมายังมา)
	local waveTimes = plan.BigRaid and { 0.03, 0.2, 0.4 } or {}
	local waveCount = #waveTimes
	local budget = Nights.Budget(night, players, bloodMoonNight)
	for w = 1, waveCount do
		local waveBudget = budget * (w == waveCount and 0.45 or (0.55 / (waveCount - 1)))
		local spawns = {}
		local guard = 0
		while waveBudget > 0.5 and guard < 200 do
			guard += 1
			local id = available[rng:NextInteger(1, #available)]
			local d = Animals.Data[id]
			local cost = d.RaidCost or 2
			if cost <= waveBudget + 1 then
				local count = 1
				if d.Pack then
					count = rng:NextInteger(d.Pack[1], d.Pack[2])
				end
				for _ = 1, count do
					table.insert(spawns, id)
				end
				waveBudget -= cost * (d.Pack and 0.7 * count or 1)
			elseif cost > budget then
				-- ตัวนี้แพงเกินคืนนี้ ตัดออก
				waveBudget -= 0.5
			end
		end
		-- งบไม่พอซื้อตัวไหนเลย (ตัวที่ปลดล็อกแพงกว่างบ) -> ได้ตัวถูกสุด 1 ตัว กันคืนว่าง
		if #spawns == 0 then
			local cheapest = available[1]
			for _, id in ipairs(available) do
				if (Animals.Data[id].RaidCost or 2) < (Animals.Data[cheapest].RaidCost or 2) then
					cheapest = id
				end
			end
			table.insert(spawns, cheapest)
		end
		table.insert(plan.Waves, { At = waveTimes[w], Spawns = spawns })
	end
	-- ไม่เกินเพดานของคืนนี้: ตัดจากระลอกที่ใหญ่สุดก่อน
	local total = 0
	for _, wave in ipairs(plan.Waves) do
		total += #wave.Spawns
	end
	for _ = 1, total - Nights.MaxCount(night, players) do
		local biggest = plan.Waves[1]
		for _, wave in ipairs(plan.Waves) do
			if #wave.Spawns > #biggest.Spawns then
				biggest = wave
			end
		end
		table.remove(biggest.Spawns)
	end
	if plan.Boss then
		table.insert(plan.Waves, { At = 0.1, Spawns = { plan.Boss }, Boss = true })
	end
	return plan
end

return Nights
