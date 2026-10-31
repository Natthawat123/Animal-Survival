--[[
	Recipes — สูตรคราฟต์ที่โต๊ะคราฟต์ + ค่าอัปเกรดโต๊ะ + เลเวลกองไฟ
]]

local Recipes = {}

-- Bench = ต้องมีโต๊ะเลเวลเท่าไร
Recipes.List = {
	-- เลเวล 1
	{ Id = "StoneAxe", Bench = 1, Cost = { Wood = 5, Stone = 3 } },
	{ Id = "GoodSack", Bench = 1, Cost = { Pelt = 3, Fiber = 6 } },
	{ Id = "GiantSack", Bench = 2, Cost = { Pelt = 6, Fiber = 12, Bone = 4 } },
	{ Id = "Torch", Bench = 1, Cost = { Wood = 2, Fiber = 2 } },
	{ Id = "Spear", Bench = 1, Cost = { Wood = 4, Bone = 2, Fiber = 2 } },
	{ Id = "Bandage", Bench = 1, Cost = { Fiber = 4 }, Amount = 1 },
	{ Id = "HerbSalve", Bench = 1, Cost = { Berries = 3, Fiber = 2 } },
	{ Id = "BerryJuice", Bench = 1, Cost = { Berries = 4 } },
	{ Id = "LogWall", Bench = 1, Cost = { Wood = 6 } },
	{ Id = "SpikeTrap", Bench = 1, Cost = { Wood = 4, Stone = 2 } },
	{ Id = "Lantern", Bench = 1, Cost = { Wood = 3, Fiber = 2, Stone = 1 } },
	{ Id = "WoodArmor", Bench = 1, Cost = { Wood = 12, Fiber = 6 } },
	-- เลเวล 2
	{ Id = "Pickaxe", Bench = 2, Cost = { Wood = 4, Stone = 6 } },
	{ Id = "Bow", Bench = 2, Cost = { Wood = 8, Fiber = 6 } },
	{ Id = "Bed", Bench = 2, Cost = { Wood = 10, Pelt = 3 } },
	{ Id = "FarmPlot", Bench = 2, Cost = { Wood = 6, Berries = 3 } },
	{ Id = "CookPot", Bench = 2, Cost = { Stone = 8, Iron = 2 } },
	-- เลเวล 3
	{ Id = "IronAxe", Bench = 3, Cost = { Wood = 4, Iron = 6 } },
	{ Id = "StoneWall", Bench = 3, Cost = { Stone = 12 } },
	{ Id = "Ballista", Bench = 3, Cost = { Wood = 12, Iron = 6, Fiber = 6 } },
	{ Id = "Medkit", Bench = 3, Cost = { Bandage = 2, Berries = 4 } },
	{ Id = "IronArmor", Bench = 3, Cost = { Iron = 12, Pelt = 4, Fiber = 4 } },
	-- เลเวล 4 (ของธาตุ)
	{ Id = "TerraHammer", Bench = 4, Cost = { TerraHeart = 1, TerraCore = 4 } },
	{ Id = "TidalTrident", Bench = 4, Cost = { TideHeart = 1, TidePearl = 4 } },
	{ Id = "GaleBow", Bench = 4, Cost = { FrostHeart = 1, GaleFeather = 4 } },
	{ Id = "EmberBlade", Bench = 4, Cost = { EmberHeart = 1, EmberShard = 4 } },
	{ Id = "TerraTotem", Bench = 4, Cost = { Stone = 10, TerraCore = 3 } },
	{ Id = "TideTotem", Bench = 4, Cost = { Stone = 10, TidePearl = 3 } },
	{ Id = "GaleTotem", Bench = 4, Cost = { Stone = 10, GaleFeather = 3 } },
	{ Id = "EmberTotem", Bench = 4, Cost = { Stone = 10, EmberShard = 3 } },
	{ Id = "GoldArmor", Bench = 4, Cost = { Iron = 20, Pelt = 6, EmberShard = 4, TerraCore = 4 } },
	-- เลเวล 5 (ของจากบอส) · AnyHeart / AnyEssence = ธาตุไหนก็ได้ (Items.AnyGroups)
	{ Id = "SunBeacon", Bench = 5, Cost = { Iron = 30, AnyHeart = 1, EmberShard = 5 } },
	{ Id = "FourfoldBlade", Bench = 5, Cost = { TerraHeart = 1, TideHeart = 1, FrostHeart = 1, EmberHeart = 1, TerraCore = 5, TidePearl = 5, GaleFeather = 5, EmberShard = 5 } },
}

Recipes.ById = {}
for _, r in ipairs(Recipes.List) do
	Recipes.ById[r.Id] = r
end

-- ค่าอัปเกรดโต๊ะคราฟต์ (index = เลเวลที่จะไป)
Recipes.BenchUpgrade = {
	[2] = { Wood = 20, Stone = 12 },
	[3] = { Wood = 40, Stone = 30, Iron = 10 },
	[4] = { Wood = 50, Stone = 40, Iron = 20, Pelt = 10 },
	[5] = { Wood = 60, Stone = 50, Iron = 30, Pelt = 20, AnyEssence = 2 },
}

-- เลเวลกองไฟ: MaxFuel, SafeRadius (สัตว์ป่า/สตอล์กเกอร์ไม่กล้าเข้า), Light,
--   Reveal = กำแพงหมอกอยู่ห่างแคมป์เท่าไร (สัดส่วนของครึ่งแมพ) — เลยออกไปเดินไม่ได้ อัปเกรดไฟเพื่อดันหมอกออก
Recipes.Campfire = {
	[1] = { MaxFuel = 300, SafeRadius = 42, Light = 60, Reveal = 0.22 },
	[2] = { MaxFuel = 450, SafeRadius = 56, Light = 70, Reveal = 0.36, Cost = { Wood = 30, Stone = 10 } },
	[3] = { MaxFuel = 620, SafeRadius = 70, Light = 80, Reveal = 0.52, Cost = { Wood = 40, Stone = 30, Coal = 6 } },
	[4] = { MaxFuel = 800, SafeRadius = 84, Light = 90, Reveal = 0.68, Cost = { Wood = 60, Stone = 40, Coal = 15, Iron = 15 } },
	[5] = { MaxFuel = 1000, SafeRadius = 98, Light = 100, Reveal = 0.86, Cost = { Wood = 80, Stone = 50, Coal = 30, Iron = 30, AnyEssence = 1 } },
	[6] = { MaxFuel = 1300, SafeRadius = 120, Light = 120, Reveal = 99, Cost = { Wood = 100, Stone = 60, Coal = 45, Iron = 45, AnyEssence = 2 } },
}
-- เชื้อเพลิงต่อวินาที · ไฟเต็ม Lv.1 (300) อยู่ได้ ~10 นาทีกลางวัน / ~6 นาทีกลางคืน ≈ 2 วันเต็ม (เดิม 1.0/1.7 หมดไม่ถึงวันเดียว)
Recipes.CampfireDrainDay = 0.5
Recipes.CampfireDrainNight = 0.85

return Recipes
