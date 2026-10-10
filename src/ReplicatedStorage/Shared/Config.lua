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
Config.DayLength = 300 -- วินาที
Config.DuskLength = 25 -- ช่วงพลบค่ำ (ท้ายกลางวัน) เตือนว่าฝูงกำลังมา
Config.NightLength = 180
Config.FirstDayBonus = 60 -- วันแรกยาวขึ้นให้ตั้งตัว

---------------------------------------------------------------- ผู้เล่น
Config.HungerMax = 100
Config.HungerDrainPerSec = 100 / 540 -- หมดใน ~9 นาที
Config.StarveDamagePerSec = 2.5
Config.DownedTime = 30 -- ล้มแล้วรอเพื่อนช่วยกี่วินาที
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
Config.MaxWildAnimals = 70 -- สัตว์ป่ากลางวันทั้งแมพ
Config.WildSpawnRadius = { Min = 140, Max = 420 } -- เกิดรอบตัวผู้เล่น
Config.WildDespawnRadius = 900
Config.RaidSpawnRadius = { Min = 330, Max = 470 } -- ฝูงบุกเกิดรอบกองไฟ
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
	{ Id = "Pack1", ProductId = 0, Diamonds = 60, Bonus = 0, Robux = 25, Icon = "💎", Name = "ถุงเพชรเล็ก" },
	{ Id = "Pack2", ProductId = 0, Diamonds = 150, Bonus = 15, Robux = 59, Icon = "💎", Name = "ถุงเพชร" },
	{ Id = "Pack3", ProductId = 0, Diamonds = 320, Bonus = 50, Robux = 119, Icon = "💰", Name = "หีบเพชร", Tag = "ยอดนิยม" },
	{ Id = "Pack4", ProductId = 0, Diamonds = 700, Bonus = 150, Robux = 239, Icon = "👑", Name = "กองเพชรมหึมา" },
	{ Id = "Pack5", ProductId = 0, Diamonds = 1500, Bonus = 400, Robux = 479, Icon = "🏆", Name = "ขุมทรัพย์ราชา", Tag = "คุ้มสุด" },
}
Config.GamePasses = {
	{ Id = "VIP", PassId = 0, Robux = 199, Icon = "👑", Name = "VIP", Desc = "เพชรที่ได้จากการเล่น x2 · ป้าย VIP บนหัว · ชื่อสีทองในกระดานอันดับ" },
	{ Id = "GiantSack", PassId = 0, Robux = 149, Icon = "🎒", Name = "กระสอบยักษ์", Desc = "เริ่มทุกรอบด้วยกระสอบยักษ์ (ใส่ของได้มากสุด) แทนกระสอบเก่า" },
	{ Id = "Medic", PassId = 0, Robux = 99, Icon = "🩹", Name = "หน่วยแพทย์", Desc = "เริ่มทุกรอบด้วยผ้าพันแผล 3 + ชุดปฐมพยาบาล 1 (ช่วยเพื่อนที่ล้มได้ทันที)" },
	{ Id = "Torch", PassId = 0, Robux = 79, Icon = "🔥", Name = "คบเพลิงนิรันดร์", Desc = "เริ่มทุกรอบพร้อมคบเพลิง (ไล่กวางกลวง) + ถ่านหิน 5" },
}
-- ป้าย Roblox: Stat = ค่าในเซฟที่ใช้เช็ก, Need = ต้องถึงเท่าไร
Config.Badges = {
	{ Id = "Welcome", BadgeId = 0, Name = "ยินดีต้อนรับสู่ป่า", Stat = "Joined", Need = 1 },
	{ Id = "Night5", BadgeId = 0, Name = "รอดถึงคืนที่ 5", Stat = "BestNight", Need = 5 },
	{ Id = "Night10", BadgeId = 0, Name = "รอดถึงคืนที่ 10", Stat = "BestNight", Need = 10 },
	{ Id = "Night25", BadgeId = 0, Name = "รอดถึงคืนที่ 25", Stat = "BestNight", Need = 25 },
	{ Id = "Night50", BadgeId = 0, Name = "รอดถึงคืนที่ 50", Stat = "BestNight", Need = 50 },
	{ Id = "Night99", BadgeId = 0, Name = "พิชิต 99 คืน", Stat = "BestNight", Need = 99 },
	{ Id = "Night150", BadgeId = 0, Name = "ตำนานแห่งป่า (150 คืน)", Stat = "BestNight", Need = 150 },
	{ Id = "Boss1", BadgeId = 0, Name = "ผู้ปราบอสูร", Stat = "BossKills", Need = 1 },
	{ Id = "Spirits4", BadgeId = 0, Name = "ผู้พิทักษ์สี่ธาตุ", Stat = "TrueEndings", Need = 1 },
	{ Id = "Kills250", BadgeId = 0, Name = "นายพรานผู้ยิ่งใหญ่ (250 ตัว)", Stat = "Kills", Need = 250 },
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
