--[[
	Nights — ผู้กำกับฝูงบุก 99 คืน
	- ทุกคืนสุ่ม "ธาตุประจำคืน" (สัตว์ธาตุนั้นบุก)
	- ทุก 10 คืน = พระจันทร์เลือด (ทุกธาตุบุกพร้อมกัน งบ x1.5)
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
	[1] = "คืนแรกในป่า",
	[10] = "พระจันทร์เลือดครั้งแรก",
	[25] = "ภูผาเดินได้",
	[50] = "มารดาแห่งกระแสน้ำ",
	[75] = "มงกุฎแห่งพายุ",
	[99] = "ราตรีสุดท้าย",
}

function Nights.IsBloodMoon(night)
	return night % 10 == 0
end

-- ตัวคูณความแรงของสัตว์ตามคืน
function Nights.Scale(night)
	local n = math.max(night - 1, 0)
	return {
		Health = 1 + n * 0.032,
		Damage = 1 + n * 0.016,
		Speed = 1 + math.min(n * 0.003, 0.25),
	}
end

function Nights.Budget(night)
	local b = 3 + night * 1.35 + (night / 10) ^ 2 * 2
	if Nights.IsBloodMoon(night) then
		b *= 1.5
	end
	return b
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
		Boss = "Solfang" | nil,
		Waves = { { At = 0.05, Spawns = { "EmberFox", "EmberFox", ... } }, ... }  -- At = สัดส่วนของเวลากลางคืน
	}
]]
function Nights.Plan(night, rng, element)
	local plan = {
		Element = element,
		BloodMoon = Nights.IsBloodMoon(night),
		Boss = Nights.BossFor(night),
		Waves = {},
	}
	local pools = {}
	if plan.BloodMoon or night == 99 then
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

	local waveCount = night < 5 and 2 or 3
	local budget = Nights.Budget(night)
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
		table.insert(plan.Waves, { At = (w - 1) / waveCount * 0.75 + 0.04, Spawns = spawns })
	end
	if plan.Boss then
		table.insert(plan.Waves, { At = 0.3, Spawns = { plan.Boss }, Boss = true })
	end
	return plan
end

return Nights
