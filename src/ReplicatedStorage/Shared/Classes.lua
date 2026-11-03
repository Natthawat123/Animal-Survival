--[[
	Classes — คลาสตัวละคร (ซื้อด้วย Ruby ♦️ เซฟข้ามรอบ) แบบร้านคลาสของ 99 Nights
	  - ดาว 1-5 (ความหายาก) · เลเวล 1-3 ต่อคลาส: เก็บสถิติตอนเล่นคลาสนั้นจนครบ หรือจ่าย Ruby "ข้าม"
	  - ทักษะเลเวล 1/2/3 ปลดตามเลเวล (Perks ของเลเวลหลังทับค่าของเลเวลก่อน)
	  - สต็อกร้านสุ่มใหม่ทุกวัน (UTC) ต่อผู้เล่น — คลาสที่ "ไม่มีสต๊อค" ซื้อไม่ได้จนกว่าจะรีโรล/วันใหม่

	Perks ที่ระบบอื่นอ่าน:
		ChopMult, MineMult, DamageMult, BuildDiscount, WallHealthMult, SpeedMult, StaminaMult,
		ElementDamageMult, FuelDrainMult, HungerMult, HealMult, DamageTakenMult, ExtraDrops, WildPeace,
		MaxHealthBonus (+เลือดสูงสุด), Regen (ฟื้นเลือด/วินาที)
]]

local Classes = {}

Classes.Order = {
	"Survivor", "Forager", "Lumberjack", "Medic", "Hunter", "Builder", "Scout", "Elementalist",
}

Classes.MaxLevel = 3

-- Skills[1..3] = ทักษะเลเวล 1/2/3: { Name, Text, Perks } — Perks ของเลเวลหลังทับค่าเดียวกันของเลเวลก่อน
Classes.Data = {
	Survivor = {
		Name = "Survivor", Thai = "Survivor", Role = "All-Rounder", Stars = 1, Price = 0, Icon = "🔥",
		StartItems = { OldAxe = 1, Torch = 1 },
		Skills = {
			{ Name = "Never Give Up", Text = "Max HP +15 · Hunger 10% slower", Perks = { MaxHealthBonus = 15, HungerMult = 0.9 } },
			{ Name = "Traveler", Text = "Run 5% faster · Stamina +15%", Perks = { SpeedMult = 1.05, StaminaMult = 1.15 } },
			{ Name = "Survival Instinct", Text = "Max HP +25 · Regen 0.3 HP/sec", Perks = { MaxHealthBonus = 25, Regen = 0.3 } },
		},
	},
	Forager = {
		Name = "Forager", Thai = "Forager", Role = "Supplies", Stars = 2, Price = 100, Icon = "🍓",
		StartItems = { OldAxe = 1, Berries = 6 },
		Skills = {
			{ Name = "Big Basket", Text = "Hunting drops +1 extra meat/pelt/bone/fiber", Perks = { ExtraDrops = 1 } },
			{ Name = "Food Expert", Text = "Hunger 25% slower · Food and healing 20% stronger", Perks = { HungerMult = 0.75, HealMult = 1.2 } },
			{ Name = "Full Harvest", Text = "Hunting drops +2 extra meat/pelt/bone/fiber", Perks = { ExtraDrops = 2 } },
		},
	},
	Lumberjack = {
		Name = "Lumberjack", Thai = "Lumberjack", Role = "Gathering", Stars = 2, Price = 150, Icon = "🪓",
		StartItems = { StoneAxe = 1 },
		Skills = {
			{ Name = "Log Arms", Text = "Chop wood x1.6", Perks = { ChopMult = 1.6 } },
			{ Name = "Trusty Axe", Text = "Mine rock and ore x1.4 · Stamina +20%", Perks = { MineMult = 1.4, StaminaMult = 1.2 } },
			{ Name = "Forest Feller", Text = "Chop wood x2.2 · Mine rock/ore x1.6", Perks = { ChopMult = 2.2, MineMult = 1.6 } },
		},
	},
	Medic = {
		Name = "Medic", Thai = "Field Medic", Role = "Support", Stars = 2, Price = 200, Icon = "🩹",
		StartItems = { OldAxe = 1, Bandage = 3 },
		Skills = {
			{ Name = "Healer's Hands", Text = "Bandages, medicine and reviving teammates heal x1.5", Perks = { HealMult = 1.5 } },
			{ Name = "Recovery", Text = "Regen 0.5 HP/sec at all times", Perks = { Regen = 0.5 } },
			{ Name = "Battlefield Doctor", Text = "Healing x2 · Max HP +15", Perks = { HealMult = 2, MaxHealthBonus = 15 } },
		},
	},
	Hunter = {
		Name = "Hunter", Thai = "Hunter", Role = "Combat", Stars = 3, Price = 350, Icon = "🏹",
		StartItems = { OldAxe = 1, Bow = 1 },
		Skills = {
			{ Name = "Hawk Eye", Text = "All weapon damage +15%", Perks = { DamageMult = 1.15 } },
			{ Name = "Never Miss", Text = "Damage +25% · Hunting drops +1 extra meat/pelt/bone/fiber", Perks = { DamageMult = 1.25, ExtraDrops = 1 } },
			{ Name = "Alpha Hunter", Text = "Damage +40% · Run 5% faster", Perks = { DamageMult = 1.4, SpeedMult = 1.05 } },
		},
	},
	Builder = {
		Name = "Builder", Thai = "Builder", Role = "Base Defense", Stars = 3, Price = 400, Icon = "🔨",
		StartItems = { OldAxe = 1, LogWall = 2 },
		Skills = {
			{ Name = "Thrifty Builder", Text = "Buildings cost 20% fewer materials", Perks = { BuildDiscount = 0.2 } },
			{ Name = "Hardwood", Text = "Walls and buildings are x1.5 tougher", Perks = { WallHealthMult = 1.5 } },
			{ Name = "Fortress", Text = "35% fewer materials · Buildings x2 tougher", Perks = { BuildDiscount = 0.35, WallHealthMult = 2 } },
		},
	},
	Scout = {
		Name = "Scout", Thai = "Scout", Role = "Exploration", Stars = 4, Price = 650, Icon = "🧭",
		StartItems = { OldAxe = 1, IronArmor = 1 }, -- เกราะเงิน (เกราะเหล็ก) สวมตั้งแต่เริ่ม
		Skills = {
			{ Name = "Quick Feet", Text = "Run 12% faster", Perks = { SpeedMult = 1.12 } },
			{ Name = "Iron Lungs", Text = "Stamina x1.6 · Hunger 10% slower", Perks = { StaminaMult = 1.6, HungerMult = 0.9 } },
			{ Name = "Shadow of the Wilds", Text = "Run 20% faster · Stamina x2 · Hunting drops +1 extra item", Perks = { SpeedMult = 1.2, StaminaMult = 2, ExtraDrops = 1 } },
		},
	},

	Elementalist = {
		Name = "Elementalist", Thai = "Elementalist", Role = "Elemental Magic", Stars = 5, Price = 1000, Icon = "🔮",
		StartItems = { OldAxe = 1, EmberStaff = 1 }, -- ขวาน (ทุกคลาสมี) + คทาเพลิง (ยิงลูกไฟ + ฟาดตัดไม้ได้)
		Skills = {
			{ Name = "Elemental Touch", Text = "Elemental weapons (incl. Fire Staff) 20% stronger · Frail: Max HP -10", Perks = { ElementDamageMult = 1.2, MaxHealthBonus = -10 } },
			{ Name = "Elemental Power", Text = "Elemental weapons 40% stronger · Stamina +15%", Perks = { ElementDamageMult = 1.4, StaminaMult = 1.15 } },
			{ Name = "Element Master", Text = "Elemental weapons 65% stronger · Max HP +10", Perks = { ElementDamageMult = 1.65, MaxHealthBonus = 10 } },
		},
	},

}

-- ใช้กับโค้ดเก่า: Perks / Desc = ทักษะเลเวล 1
for _, c in pairs(Classes.Data) do
	c.Perks = c.Skills[1].Perks
	c.Desc = c.Skills[1].Name .. ": " .. c.Skills[1].Text
end

-- Perks รวมถึงเลเวลที่ปลดแล้ว
function Classes.PerksFor(id, level)
	local c = Classes.Data[id] or Classes.Data.Survivor
	local out = {}
	for lv = 1, math.clamp(level or 1, 1, Classes.MaxLevel) do
		for k, v in pairs(c.Skills[lv].Perks) do
			out[k] = v
		end
	end
	return out
end

---------------------------------------------------------------- เลเวล
-- ข้อกำหนดเพื่อขึ้นเลเวล (สถิติที่เก็บตอนสวมใส่คลาสนั้น)
Classes.StatNames = { Kills = "Hunt", Nights = "Survive nights" }
Classes.StatOrder = { "Kills", "Nights" }

function Classes.Requirement(id, level)
	local s = (Classes.Data[id] or Classes.Data.Survivor).Stars
	if level == 2 then
		return { Kills = 40 + 20 * s, Nights = 3 + s }
	elseif level == 3 then
		return { Kills = 200 + 100 * s, Nights = 10 + 4 * s }
	end
	return nil
end

-- จ่าย Ruby ข้ามไปเลเวลถัดไป
function Classes.SkipPrice(id, level)
	local s = (Classes.Data[id] or Classes.Data.Survivor).Stars
	return level == 2 and 60 * s or 180 * s
end

---------------------------------------------------------------- สต็อกร้าน
Classes.RerollPrice = 25
Classes.StockOdds = { [1] = 0.9, [2] = 0.75, [3] = 0.55, [4] = 0.35, [5] = 0.2 } -- โอกาสมีของต่อดาว
Classes.StarColor = {
	[1] = Color3.fromRGB(170, 176, 186), [2] = Color3.fromRGB(110, 210, 90), [3] = Color3.fromRGB(70, 160, 255),
	[4] = Color3.fromRGB(190, 100, 255), [5] = Color3.fromRGB(255, 160, 40),
}

function Classes.Day(now)
	return math.floor((now or os.time()) / 86400)
end

-- วินาทีที่เหลือก่อนสต็อกรีเซ็ต
function Classes.SecondsToRestock(now)
	now = now or os.time()
	return (Classes.Day(now) + 1) * 86400 - now
end

-- ชุดคลาสที่มีของในวัน/รอบรีโรลนี้ (ผลเหมือนกันทั้ง server และ client)
function Classes.Stock(day, roll, userId)
	local rng = Random.new(day * 7919 + (roll or 0) * 104729 + ((userId or 0) % 100000))
	local stock = {}
	local count = 0
	for _, id in ipairs(Classes.Order) do
		local c = Classes.Data[id]
		if c.Price > 0 and rng:NextNumber() < Classes.StockOdds[c.Stars] then
			stock[id] = true
			count += 1
		end
	end
	if count == 0 then
		stock.Forager = true
	end
	return stock
end

---------------------------------------------------------------- Ruby
-- Ruby ที่ได้ตอนรอดถึงคืน
Classes.NightRewards = { [5] = 5, [10] = 10, [25] = 20, [50] = 40, [75] = 60, [99] = 150 }
Classes.BossReward = 20
Classes.SpiritReward = 5
Classes.DailyReward = 5 -- หม้อรางวัลประจำวันในล็อบบี้

return Classes
