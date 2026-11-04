--[[
	Config — ค่าตั้งต้นของทั้งเกม (แก้ตรงนี้ที่เดียว)
	ANIMAL SURVIVAL : 99 Nights of the Elements
]]

local Config = {}

Config.GameName = "ANIMAL SURVIVAL"
Config.Subtitle = "Legends of the Four Elements"

---------------------------------------------------------------- แมพ
-- ขนาดแมพ (ด้านละกี่ studs) 6144 = ~1.7 กม. ต่อด้าน / ใส่ 8192 ได้ถ้าเครื่องเซิร์ฟเวอร์ไหว
Config.MapSize = 6144
Config.VoxelRes = 4 -- ความละเอียด Terrain (ห้ามเปลี่ยน)
Config.ChunkVoxels = 48 -- ขนาดชิ้นที่สร้างทีละครั้ง (48 voxel = 192 studs)
Config.WaterLevel = 20 -- ระดับน้ำทะเล (Y)
Config.Seed = nil -- nil = สุ่มใหม่ทุกเซิร์ฟเวอร์ (ไบโอมสลับตำแหน่งทุกรอบ)
Config.PreviewSeed = 99 -- seed ที่ปลั๊กอินใช้สร้างแมพตัวอย่างตอน Edit
Config.HeartRadius = 260 -- ทุ่งกลางรอบกองไฟ (ราบเรียบ ปลอดภัยตอนกลางวัน)
Config.EdgeOcean = 420 -- ขอบแมพเป็นทะเลลึก กันคนออกนอกแมพ
Config.PropDensity = 1.0 -- ความหนาแน่นต้นไม้/หิน (ลดได้ถ้าเครื่องช้า)

---------------------------------------------------------------- เวลา
Config.TotalNights = 99 -- รอดครบ 99 คืน = "พิชิต" (จบเนื้อเรื่อง) แต่เล่นต่อได้ไม่จำกัดเพื่อทำสถิติ
Config.EndlessBossEvery = 25 -- หลังคืน 99: บอสวนกลับมาบุกทุกกี่คืน (124, 149, ...)
Config.DayLength = 150 -- วินาที (2:30 นาที รวมช่วงพลบค่ำ)
Config.DuskLength = 25 -- ช่วงพลบค่ำ (ท้ายกลางวัน) เตือนว่าฝูงกำลังมา
Config.NightLength = 90 -- 1:30 นาที
Config.BossHoldMax = 120 -- คืนบอส: บอสยังไม่ตายตอนใกล้เช้า -> หยุดนาฬิการอได้สูงสุดกี่วินาที
Config.FirstDayBonus = 0 -- วันแรกยาวเท่าวันอื่น
Config.TreeRegrowDays = 4 -- ต้นไม้ที่โค่นแล้วเริ่มงอกใหม่ได้หลังผ่านไปกี่คืน
Config.TreeRegrowChance = 0.3 -- ครบแล้ว: แต่ละคืนต้นที่ล้มอยู่มีโอกาสงอกคืนเท่านี้ (ทยอยขึ้นทีละน้อย ไม่ขึ้นพร้อมกันทั้งป่า)
Config.AnimalDropMult = 0.7 -- ของที่สัตว์/มอนดรอป (เนื้อ/หนัง/กระดูก/ฯลฯ) คูณเท่านี้ · ไม่รวมบอส

---------------------------------------------------------------- ผู้เล่น
Config.HungerMax = 100
Config.HungerDrainPerSec = 100 / 900 -- หมดใน ~15 นาที (เดิม 9 นาที)
Config.StarveDamagePerSec = 2.5
Config.BreathMax = 20 -- ดำน้ำได้นานสุด (วิ) · หัวจมน้ำ = ลมหายใจลด 1/วิ
Config.BreathRefillPerSec = 6 -- โผล่พ้นน้ำ = ลมหายใจกลับมาเต็มใน ~3 วิ
Config.DrownDamagePerSec = 10 -- ลมหายใจหมด = เสียเลือดต่อวิ
Config.ReviveTime = 3.5
Config.ReviveRange = 10
Config.BaseWalkSpeed = 18
Config.SprintSpeed = 28
Config.StaminaMax = 100
Config.InteractRange = 14
Config.BuildRange = 60

---------------------------------------------------------------- สัตว์
-- สัตว์เกิดได้เฉพาะตัวที่มีโมเดลแล้ว (assets/rbxm/Animals/<Id>.rbxmx) — ตอนนี้มีแค่บอส 4 ไบโอม
Config.AnimalsEnabled = true
Config.LootMult = 0.7 -- ตัวคูณของดรอปทั้งเกม (วัตถุดิบ/แก่นธาตุ เท่านั้น — อาหาร/ยาไม่ลด)
Config.MonsterDamageScale = 0.5 -- ดาเมจมอนทั่วไป (สัตว์ป่า/บุกแคมป์/ผู้พิทักษ์) ที่ตีผู้เล่น — ลดความยาก (เดิม 0.75)
Config.BossDamageScale = 0.75 -- ดาเมจบอส (ตีธรรมดา + สกิลทุกท่า)
Config.BossSkillCooldown = { Min = 3, Max = 4.5 } -- บอสบุกแคมป์ร่ายสกิลทุกกี่วินาที (สุ่มในช่วงนี้ · เดิม 7-10)
Config.LairBossSkillCooldown = { Min = 2, Max = 3 } -- บอสในรัง/ผู้พิทักษ์บอส ร่ายสกิลทุกกี่วินาที (เดิม 4.5-6.5)
Config.BossCastMult = 2.6 -- ท่าร่ายบอสช้าลงกี่เท่า (คูณเวลาง้าง/วงเตือนทุกสกิล · บอสตั้งเองได้ด้วย Info.CastMult)
Config.StalkerStare = 3 -- จิ้งจอกจันทรา (ตัวไล่): จ้องกี่วินาทีก่อนพุ่งตี (เหยื่อไม่ได้ถือคบเพลิง)
Config.BossFirstSkill = 2 -- วินาทีหลังเกิดก่อนร่ายสกิลแรก (เดิม 6)
Config.MaxWildAnimals = 70 -- สัตว์ป่ากลางวันทั้งแมพ
Config.WildSpawnRadius = { Min = 140, Max = 420 } -- เกิดรอบตัวผู้เล่น
Config.WildDespawnRadius = 900
-- กล่องทั่วแมพ: จำนวนทั้งหมด + จำนวนแต่ละระดับ (ธรรมดา / หายาก / ตำนาน) · วิหาร = ระดับ 3 เสมอ
Config.CrateCount = 40
Config.CrateTierWeight = { 24, 12, 4 }
-- สัตว์ป่ากลางวันมีถิ่นของตัวเอง (ไม่ใช่ฝูงบุกกลางคืน): ไม่ไล่ตามข้ามแมพจนถึงแคมป์
-- ช่วยลูกสัตว์ธาตุสำเร็จ = ข้ามวันตามธาตุ (Air = ไบโอมน้ำแข็ง) · เตียง = 1 วัน
Config.SpiritBonusDays = { Earth = 2, Water = 3, Air = 4, Fire = 5 }
Config.WildLeash = 70 -- รัศมีถิ่นจากจุดเกิด (stud) · ผู้เล่นออกนอกถิ่น +40 = เลิกไล่ แล้วเดินกลับถิ่น
Config.WildChaseTime = 14 -- ไล่ไม่ถึงตัวนานเกินนี้ (วินาที) = เลิกไล่
Config.WildGiveUpTime = 10 -- เลิกไล่แล้ว ไม่สนใจคนนั้นอีกกี่วินาที
Config.RaidSpawnRadius = { Min = 220, Max = 320 } -- ฝูงบุกเกิดรอบกองไฟ
Config.MaxRaidAnimals = 55
Config.AnimalThinkRate = 0.25 -- วินาทีต่อรอบคิดของ AI

---------------------------------------------------------------- นักพัฒนา
-- UserId ที่ใช้เครื่องมือ DEV (F8) ในเกมจริงได้ (ใน Studio และเจ้าของเกมใช้ได้เสมอ)
Config.DevUserIds = {}

---------------------------------------------------------------- อันดับ (ทั้งเกม ทุกเซิร์ฟเวอร์)
Config.LeaderboardStore = "BestNight_v1" -- OrderedDataStore ของ "คืนที่รอดนานสุด"
Config.LeaderboardSize = 10

---------------------------------------------------------------- ร้านค้า Robux / Game Pass / Badge
-- ⚠ ต้องสร้างของจริงใน Creator Hub ก่อน แล้วเอาเลข ID มาใส่ตรงนี้ (0 = ยังไม่ตั้ง → ปุ่มขึ้นว่า "เร็วๆ นี้" ไม่พัง)
--   Developer Product: Creator Hub → เกม → การสร้างรายได้ → ผลิตภัณฑ์สำหรับนักพัฒนา
--   Game Pass       : Creator Hub → เกม → การสร้างรายได้ → บัตรผ่าน
--   Badge           : Creator Hub → เกม → การมีส่วนร่วม → ป้าย
Config.DiamondPacks = {
	{ Id = "Pack1", ProductId = 3726330739, Diamonds = 60, Bonus = 0, Robux = 25, Icon = "♦️", Name = "Small Ruby Pouch" },
	{ Id = "Pack2", ProductId = 3726331233, Diamonds = 150, Bonus = 15, Robux = 59, Icon = "♦️", Name = "Ruby Pouch" },
	{ Id = "Pack3", ProductId = 3726331718, Diamonds = 320, Bonus = 50, Robux = 119, Icon = "💰", Name = "Ruby Chest", Tag = "Popular" },
	{ Id = "Pack4", ProductId = 3726332457, Diamonds = 700, Bonus = 150, Robux = 239, Icon = "👑", Name = "Huge Ruby Pile" },
	{ Id = "Pack5", ProductId = 3726332759, Diamonds = 1500, Bonus = 400, Robux = 479, Icon = "🏆", Name = "King's Treasure", Tag = "Best Value" },
}
-- Game Pass (ซื้อครั้งเดียว) · PassId 0 = ยังไม่ได้สร้างใน Creator Hub
Config.GamePasses = {
	{ Id = "SeasonPass", PassId = 2063569631, Robux = 499, Icon = "🎟", Name = "Season Pass", Desc = "Unlocks the Season Pass premium track every season · More Ruby + special titles/title colors · Wildwood Druid class" },
	{ Id = "SaveRun", PassId = 2064000575, Robux = 799, Icon = "💾", Name = "Save Run", Desc = "Your run is saved every dawn and when you leave · Continue from the saved night at the start pad" },
}
-- คืนชีพทันที (Developer Product ซื้อซ้ำได้) · 0 = ยังไม่ได้สร้าง -> ไม่มีปุ่มซื้อ
Config.ReviveProductId = 3726412294
-- ล้มหมดทั้งทีม: รอให้กดคืนชีพก่อนแพ้กี่วินาที (มีสินค้าคืนชีพ/ตั๋วคืนชีพ) · ไม่มี = 2 วินาทีเหมือนเดิม
Config.WipeGrace = 15
-- ป้าย Roblox: Stat = ค่าในเซฟที่ใช้เช็ก, Need = ต้องถึงเท่าไร
Config.Badges = {
	{ Id = "Welcome", BadgeId = 0, Name = "Welcome to the Wilds", Stat = "Joined", Need = 1 },
	{ Id = "Night5", BadgeId = 0, Name = "Survive to Night 5", Stat = "BestNight", Need = 5 },
	{ Id = "Night10", BadgeId = 0, Name = "Survive to Night 10", Stat = "BestNight", Need = 10 },
	{ Id = "Night25", BadgeId = 0, Name = "Survive to Night 25", Stat = "BestNight", Need = 25 },
	{ Id = "Night50", BadgeId = 0, Name = "Survive to Night 50", Stat = "BestNight", Need = 50 },
	{ Id = "Night99", BadgeId = 0, Name = "Conquer 99 Nights", Stat = "BestNight", Need = 99 },
	{ Id = "Night150", BadgeId = 0, Name = "Legend of the Wilds (150 Nights)", Stat = "BestNight", Need = 150 },
	{ Id = "Boss1", BadgeId = 0, Name = "Beast Slayer", Stat = "BossKills", Need = 1 },
	{ Id = "Spirits4", BadgeId = 0, Name = "Guardian of Four Elements", Stat = "TrueEndings", Need = 1 },
	{ Id = "Kills250", BadgeId = 0, Name = "Master Hunter (250 kills)", Stat = "Kills", Need = 250 },
}

---------------------------------------------------------------- การทดสอบ
-- ReplicatedStorage.ASAutoTest มีอยู่ = โหมดทดสอบ: แมพเล็ก เวลาเร็ว
function Config.ApplyTestOverrides()
	Config.MapSize = 2048
	Config.DayLength = 80
	Config.FirstDayBonus = 0
	Config.NightLength = 35
	Config.DuskLength = 8
	Config.PropDensity = 0.5
end

return Config
