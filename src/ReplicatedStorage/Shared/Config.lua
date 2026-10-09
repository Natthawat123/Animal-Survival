--[[
	Config — ค่าตั้งต้นของทั้งเกม (แก้ตรงนี้ที่เดียว)
	ANIMAL SURVIVAL : 99 Nights of the Elements
]]

local Config = {}

Config.GameName = "ANIMAL SURVIVAL"
Config.Subtitle = "99 Nights of the Elements"

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
Config.TotalNights = 99
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
