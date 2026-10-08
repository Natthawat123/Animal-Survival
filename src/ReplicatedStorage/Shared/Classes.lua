--[[
	Classes — คลาสตัวละคร (ซื้อด้วยเพชร 💎 เซฟข้ามรอบ) แบบร้านคลาสของ 99 Nights
	  - ดาว 1-5 (ความหายาก) · เลเวล 1-3 ต่อคลาส: เก็บสถิติตอนเล่นคลาสนั้นจนครบ หรือจ่ายเพชร "ข้าม"
	  - ทักษะเลเวล 1/2/3 ปลดตามเลเวล (Perks ของเลเวลหลังทับค่าของเลเวลก่อน)
	  - สต็อกร้านสุ่มใหม่ทุกวัน (UTC) ต่อผู้เล่น — คลาสที่ "ไม่มีสต๊อค" ซื้อไม่ได้จนกว่าจะรีโรล/วันใหม่

	Perks ที่ระบบอื่นอ่าน:
		ChopMult, MineMult, DamageMult, BuildDiscount, WallHealthMult, SpeedMult, StaminaMult, EssenceMult,
		ElementDamageMult, FuelDrainMult, HungerMult, HealMult, DamageTakenMult, ExtraDrops, WildPeace
]]

local Classes = {}

Classes.Order = {
	"Survivor", "Forager", "Lumberjack", "Medic", "Hunter", "Builder", "Scout", "Firekeeper", "Elementalist", "Beastwarden",
}

Classes.MaxLevel = 3

Classes.Data = {
	Survivor = {
		Name = "Survivor", Thai = "ผู้รอดชีวิต", Stars = 1, Price = 0, Icon = "🔥",
		StartItems = { OldAxe = 1, Torch = 1 },
		Skills = {
			{ Text = "สมดุลทุกด้าน\nเริ่มด้วยขวานเก่าและคบเพลิง", Perks = {} },
			{ Text = "+10% ความเร็ววิ่ง", Perks = { SpeedMult = 1.1 } },
			{ Text = "+15% ดาเมจทุกอาวุธ", Perks = { SpeedMult = 1.1, DamageMult = 1.15 } },
		},
	},
	Forager = {
		Name = "Forager", Thai = "นักหาของป่า", Stars = 2, Price = 20, Icon = "🍓",
		StartItems = { OldAxe = 1, Berries = 6 },
		Skills = {
			{ Text = "เก็บของได้ +1 ชิ้น\nหิวช้าลง 25%", Perks = { ExtraDrops = 1, HungerMult = 0.75 } },
			{ Text = "หิวช้าลง 40%", Perks = { ExtraDrops = 1, HungerMult = 0.6 } },
			{ Text = "เก็บของได้ +2 ชิ้น\nหิวช้าลง 50%", Perks = { ExtraDrops = 2, HungerMult = 0.5 } },
		},
	},
	Lumberjack = {
		Name = "Lumberjack", Thai = "คนตัดไม้", Stars = 2, Price = 35, Icon = "🪓",
		StartItems = { StoneAxe = 1 },
		Skills = {
			{ Text = "ตัดไม้แรง x2\nเริ่มด้วยขวานหิน", Perks = { ChopMult = 2 } },
			{ Text = "ตัดไม้แรง x2.5", Perks = { ChopMult = 2.5 } },
			{ Text = "ตัดไม้แรง x3\nทุบหิน/แร่แรง x1.5", Perks = { ChopMult = 3, MineMult = 1.5 } },
		},
	},
	Medic = {
		Name = "Medic", Thai = "หมอสนาม", Stars = 2, Price = 40, Icon = "🩹",
		StartItems = { OldAxe = 1, Bandage = 3 },
		Skills = {
			{ Text = "ยาและผ้าพันแผลฮีลแรง x1.5\nเริ่มด้วยผ้าพันแผล 3", Perks = { HealMult = 1.5 } },
			{ Text = "ฮีลแรง x2", Perks = { HealMult = 2 } },
			{ Text = "ฮีลแรง x2 · โดนดาเมจ -10%", Perks = { HealMult = 2, DamageTakenMult = 0.9 } },
		},
	},
	Hunter = {
		Name = "Hunter", Thai = "นายพราน", Stars = 3, Price = 60, Icon = "🏹",
		StartItems = { OldAxe = 1, Bow = 1 },
		Skills = {
			{ Text = "ดาเมจใส่สัตว์ +25%\nได้หนัง/เนื้อเพิ่ม", Perks = { DamageMult = 1.25, ExtraDrops = 1 } },
			{ Text = "ดาเมจใส่สัตว์ +35%", Perks = { DamageMult = 1.35, ExtraDrops = 1 } },
			{ Text = "ดาเมจ +50% · ของดรอป +2", Perks = { DamageMult = 1.5, ExtraDrops = 2 } },
		},
	},
	Builder = {
		Name = "Builder", Thai = "ช่างสร้าง", Stars = 3, Price = 75, Icon = "🔨",
		StartItems = { OldAxe = 1, LogWall = 2 },
		Skills = {
			{ Text = "สร้างของถูกลง 25%\nกำแพงถึก +50%", Perks = { BuildDiscount = 0.25, WallHealthMult = 1.5 } },
			{ Text = "กำแพงถึก x2", Perks = { BuildDiscount = 0.25, WallHealthMult = 2 } },
			{ Text = "สร้างถูกลง 40% · กำแพงถึก x2.5", Perks = { BuildDiscount = 0.4, WallHealthMult = 2.5 } },
		},
	},
	Scout = {
		Name = "Scout", Thai = "หน่วยลาดตระเวน", Stars = 3, Price = 90, Icon = "🧭",
		StartItems = { OldAxe = 1, Torch = 1 },
		Skills = {
			{ Text = "วิ่งเร็ว +15%\nสตามิน่า x1.5", Perks = { SpeedMult = 1.15, StaminaMult = 1.5 } },
			{ Text = "วิ่งเร็ว +22%", Perks = { SpeedMult = 1.22, StaminaMult = 1.5 } },
			{ Text = "วิ่งเร็ว +25% · สตามิน่า x2.2", Perks = { SpeedMult = 1.25, StaminaMult = 2.2 } },
		},
	},
	Firekeeper = {
		Name = "Firekeeper", Thai = "ผู้พิทักษ์เปลวไฟ", Stars = 4, Price = 120, Icon = "🏮",
		StartItems = { OldAxe = 1, Coal = 4 },
		Skills = {
			{ Text = "กองไฟกินเชื้อเพลิงช้าลง 30%\n(ทั้งเซิร์ฟ) เริ่มด้วยถ่าน 4", Perks = { FuelDrainMult = 0.7 } },
			{ Text = "กองไฟกินเชื้อเพลิงช้าลง 40%", Perks = { FuelDrainMult = 0.6 } },
			{ Text = "เชื้อเพลิงช้าลง 50% · โดนดาเมจ -10%", Perks = { FuelDrainMult = 0.5, DamageTakenMult = 0.9 } },
		},
	},
	Elementalist = {
		Name = "Elementalist", Thai = "จอมเวทธาตุ", Stars = 5, Price = 180, Icon = "🔮",
		StartItems = { OldAxe = 1 },
		Skills = {
			{ Text = "เก็บแก่นธาตุได้ x2\nอาวุธธาตุแรง +20%", Perks = { EssenceMult = 2, ElementDamageMult = 1.2 } },
			{ Text = "อาวุธธาตุแรง +35%", Perks = { EssenceMult = 2, ElementDamageMult = 1.35 } },
			{ Text = "แก่นธาตุ x3 · อาวุธธาตุแรง +50%", Perks = { EssenceMult = 3, ElementDamageMult = 1.5 } },
		},
	},
	Beastwarden = {
		Name = "Beastwarden", Thai = "ผู้คุมอสูร", Stars = 5, Price = 300, Icon = "🐺",
		StartItems = { StoneAxe = 1 },
		Skills = {
			{ Text = "สัตว์ทำดาเมจใส่เรา -25%\nสัตว์ป่าไม่โจมตีก่อน (ยกเว้นฝูงบุก)", Perks = { DamageTakenMult = 0.75, WildPeace = true } },
			{ Text = "สัตว์ทำดาเมจ -35%", Perks = { DamageTakenMult = 0.65, WildPeace = true } },
			{ Text = "สัตว์ทำดาเมจ -45% · ดาเมจเรา +20%", Perks = { DamageTakenMult = 0.55, WildPeace = true, DamageMult = 1.2 } },
		},
	},
}

-- ใช้กับโค้ดเก่า: Perks / Desc = ทักษะเลเวล 1
for _, c in pairs(Classes.Data) do
	c.Perks = c.Skills[1].Perks
	c.Desc = c.Skills[1].Text:gsub("\n", " ")
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
