--[[
	Classes — คลาสตัวละคร (ซื้อด้วยเพชร 💎 เซฟข้ามรอบ) แบบร้านคลาสของ 99 Nights
	  - ดาว 1-5 (ความหายาก) · เลเวล 1-3 ต่อคลาส: เก็บสถิติตอนเล่นคลาสนั้นจนครบ หรือจ่ายเพชร "ข้าม"
	  - ทักษะเลเวล 1/2/3 ปลดตามเลเวล (Perks ของเลเวลหลังทับค่าของเลเวลก่อน)
	  - สต็อกร้านสุ่มใหม่ทุกวัน (UTC) ต่อผู้เล่น — คลาสที่ "ไม่มีสต๊อค" ซื้อไม่ได้จนกว่าจะรีโรล/วันใหม่

	Perks ที่ระบบอื่นอ่าน:
		ChopMult, MineMult, DamageMult, BuildDiscount, WallHealthMult, SpeedMult, StaminaMult, EssenceMult,
		ElementDamageMult, FuelDrainMult, HungerMult, HealMult, DamageTakenMult, ExtraDrops, WildPeace,
		MaxHealthBonus (+เลือดสูงสุด), Regen (ฟื้นเลือด/วินาที)
]]

local Classes = {}

Classes.Order = {
	"Survivor", "Forager", "Lumberjack", "Medic", "Hunter", "Builder", "Scout", "Firekeeper", "Elementalist", "Beastwarden",
}

Classes.MaxLevel = 3

-- Skills[1..3] = ทักษะเลเวล 1/2/3: { Name, Text, Perks } — Perks ของเลเวลหลังทับค่าเดียวกันของเลเวลก่อน
Classes.Data = {
	Survivor = {
		Name = "Survivor", Thai = "ผู้รอดชีวิต", Role = "รอบด้าน", Stars = 1, Price = 0, Icon = "🔥",
		StartItems = { OldAxe = 1, Torch = 1 },
		Skills = {
			{ Name = "ใจไม่ยอมแพ้", Text = "เลือดสูงสุด +15", Perks = { MaxHealthBonus = 15 } },
			{ Name = "ฝีเท้าเบา", Text = "วิ่งเร็วขึ้น 8%", Perks = { SpeedMult = 1.08 } },
			{ Name = "สัญชาตญาณรอด", Text = "ฟื้นเลือด 0.5 ต่อวินาทีตลอดเวลา", Perks = { Regen = 0.5 } },
		},
	},
	Forager = {
		Name = "Forager", Thai = "นักหาของป่า", Role = "เสบียง", Stars = 2, Price = 20, Icon = "🍓",
		StartItems = { OldAxe = 1, Berries = 6 },
		Skills = {
			{ Name = "ตะกร้าใหญ่", Text = "เก็บของ/ล่าสัตว์ ได้ของเพิ่ม +1 ชิ้น", Perks = { ExtraDrops = 1 } },
			{ Name = "ท้องอิ่มนาน", Text = "หิวช้าลง 30%", Perks = { HungerMult = 0.7 } },
			{ Name = "เก็บเกี่ยวเต็มมือ", Text = "ได้ของเพิ่มเป็น +2 ชิ้น", Perks = { ExtraDrops = 2 } },
		},
	},
	Lumberjack = {
		Name = "Lumberjack", Thai = "คนตัดไม้", Role = "เก็บทรัพยากร", Stars = 2, Price = 35, Icon = "🪓",
		StartItems = { StoneAxe = 1 },
		Skills = {
			{ Name = "แขนท่อนซุง", Text = "ตัดไม้แรง x1.75", Perks = { ChopMult = 1.75 } },
			{ Name = "สิ่วทุบหิน", Text = "ทุบหินและแร่แรง x1.5", Perks = { MineMult = 1.5 } },
			{ Name = "ล้มป่าในพริบตา", Text = "ตัดไม้แรง x2.5", Perks = { ChopMult = 2.5 } },
		},
	},
	Medic = {
		Name = "Medic", Thai = "หมอสนาม", Role = "สนับสนุน", Stars = 2, Price = 40, Icon = "🩹",
		StartItems = { OldAxe = 1, Bandage = 3 },
		Skills = {
			{ Name = "มือหมอ", Text = "ผ้าพันแผล ยา และการชุบชีวิตเพื่อน ฮีลแรง x1.5", Perks = { HealMult = 1.5 } },
			{ Name = "ร่างกายฟื้นตัว", Text = "ฟื้นเลือด 1 ต่อวินาทีตลอดเวลา", Perks = { Regen = 1 } },
			{ Name = "แพทย์สนามรบ", Text = "ฮีลแรง x2 · เลือดสูงสุด +20", Perks = { HealMult = 2, MaxHealthBonus = 20 } },
		},
	},
	Hunter = {
		Name = "Hunter", Thai = "นายพราน", Role = "ต่อสู้", Stars = 3, Price = 60, Icon = "🏹",
		StartItems = { OldAxe = 1, Bow = 1 },
		Skills = {
			{ Name = "ตาเหยี่ยว", Text = "ดาเมจทุกอาวุธ +15%", Perks = { DamageMult = 1.15 } },
			{ Name = "มือถลกหนัง", Text = "ล่าสัตว์ได้หนัง/เนื้อเพิ่ม +1 ชิ้น", Perks = { ExtraDrops = 1 } },
			{ Name = "นักล่าจ่าฝูง", Text = "ดาเมจทุกอาวุธ +30%", Perks = { DamageMult = 1.3 } },
		},
	},
	Builder = {
		Name = "Builder", Thai = "ช่างสร้าง", Role = "ป้องกันฐาน", Stars = 3, Price = 75, Icon = "🔨",
		StartItems = { OldAxe = 1, LogWall = 2 },
		Skills = {
			{ Name = "ช่างประหยัด", Text = "สร้างสิ่งก่อสร้างใช้วัตถุดิบน้อยลง 20%", Perks = { BuildDiscount = 0.2 } },
			{ Name = "ไม้เนื้อแข็ง", Text = "กำแพงและสิ่งก่อสร้างถึกขึ้น x1.5", Perks = { WallHealthMult = 1.5 } },
			{ Name = "ป้อมปราการ", Text = "วัตถุดิบน้อยลง 35% · สิ่งก่อสร้างถึก x2", Perks = { BuildDiscount = 0.35, WallHealthMult = 2 } },
		},
	},
	Scout = {
		Name = "Scout", Thai = "หน่วยลาดตระเวน", Role = "สำรวจ", Stars = 3, Price = 90, Icon = "🧭",
		StartItems = { OldAxe = 1, Torch = 1 },
		Skills = {
			{ Name = "ขาไว", Text = "วิ่งเร็วขึ้น 12%", Perks = { SpeedMult = 1.12 } },
			{ Name = "ปอดเหล็ก", Text = "สตามิน่ามากขึ้น x1.6", Perks = { StaminaMult = 1.6 } },
			{ Name = "เงาแห่งพงไพร", Text = "วิ่งเร็วขึ้น 20% · สตามิน่า x2", Perks = { SpeedMult = 1.2, StaminaMult = 2 } },
		},
	},
	Firekeeper = {
		Name = "Firekeeper", Thai = "ผู้พิทักษ์เปลวไฟ", Role = "รักษากองไฟ", Stars = 4, Price = 120, Icon = "🏮",
		StartItems = { OldAxe = 1, Coal = 4 },
		Skills = {
			{ Name = "ถนอมไฟ", Text = "กองไฟกินเชื้อเพลิงช้าลง 20% (ช่วยทั้งทีม)", Perks = { FuelDrainMult = 0.8 } },
			{ Name = "ไออุ่นในกาย", Text = "ฟื้นเลือด 0.75 ต่อวินาทีตลอดเวลา", Perks = { Regen = 0.75 } },
			{ Name = "หัวใจเปลวเพลิง", Text = "เชื้อเพลิงช้าลง 35% · โดนดาเมจน้อยลง 10%", Perks = { FuelDrainMult = 0.65, DamageTakenMult = 0.9 } },
		},
	},
	Elementalist = {
		Name = "Elementalist", Thai = "จอมเวทธาตุ", Role = "เวทธาตุ", Stars = 5, Price = 180, Icon = "🔮",
		StartItems = { OldAxe = 1 },
		Skills = {
			{ Name = "สัมผัสธาตุ", Text = "เก็บแก่นธาตุได้ x2 · แต่ร่างบาง เลือดสูงสุด -10", Perks = { EssenceMult = 2, MaxHealthBonus = -10 } },
			{ Name = "พลังธาตุ", Text = "อาวุธธาตุแรงขึ้น 25%", Perks = { ElementDamageMult = 1.25 } },
			{ Name = "ผู้ควบคุมธาตุ", Text = "แก่นธาตุ x3 · อาวุธธาตุแรงขึ้น 45%", Perks = { EssenceMult = 3, ElementDamageMult = 1.45 } },
		},
	},
	Beastwarden = {
		Name = "Beastwarden", Thai = "ผู้คุมอสูร", Role = "แท็งก์", Stars = 5, Price = 300, Icon = "🐺",
		StartItems = { StoneAxe = 1 },
		Skills = {
			{ Name = "กลิ่นอสูร", Text = "สัตว์ป่าไม่โจมตีก่อน (ฝูงบุกกลางคืนยังโจมตี) · ดาเมจเรา -10%", Perks = { WildPeace = true, DamageMult = 0.9 } },
			{ Name = "หนังหนาดั่งหมี", Text = "โดนดาเมจน้อยลง 20%", Perks = { DamageTakenMult = 0.8 } },
			{ Name = "ราชันย์อสูร", Text = "โดนดาเมจน้อยลง 30% · ดาเมจเรา +15%", Perks = { DamageTakenMult = 0.7, DamageMult = 1.15 } },
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
Classes.StatNames = { Kills = "ล่าสัตว์", Nights = "รอดคืน" }
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

-- จ่ายเพชรข้ามไปเลเวลถัดไป
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

---------------------------------------------------------------- เพชร
-- เพชรที่ได้ตอนรอดถึงคืน
Classes.NightRewards = { [5] = 5, [10] = 10, [25] = 20, [50] = 40, [75] = 60, [99] = 150 }
Classes.BossReward = 25
Classes.SpiritReward = 15
Classes.DailyReward = 5 -- หม้อรางวัลประจำวันในล็อบบี้

return Classes
