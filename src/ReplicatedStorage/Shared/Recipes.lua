--[[
	Recipes — สูตรคราฟต์ที่โต๊ะคราฟต์ + ค่าอัปเกรดโต๊ะ + เลเวลกองไฟ
]]

local Recipes = {}

-- Bench = ต้องมีโต๊ะเลเวลเท่าไร
Recipes.List = {
	-- เลเวล 1
	{ Id = "StoneAxe", Bench = 1, Cost = { Wood = 5, Stone = 3 } },
	{ Id = "Torch", Bench = 1, Cost = { Wood = 2, Fiber = 2 } },
	{ Id = "Spear", Bench = 1, Cost = { Wood = 4, Bone = 2, Fiber = 2 } },
	{ Id = "Bandage", Bench = 1, Cost = { Fiber = 4 }, Amount = 1 },
	{ Id = "LogWall", Bench = 1, Cost = { Wood = 6 } },
	{ Id = "SpikeTrap", Bench = 1, Cost = { Wood = 4, Stone = 2 } },
	{ Id = "Lantern", Bench = 1, Cost = { Wood = 3, Fiber = 2, Stone = 1 } },
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
	-- เลเวล 4 (ของธาตุ)
	{ Id = "TerraHammer", Bench = 4, Cost = { Iron = 8, TerraCore = 4 } },
	{ Id = "TidalTrident", Bench = 4, Cost = { Iron = 8, TidePearl = 4 } },
	{ Id = "GaleBow", Bench = 4, Cost = { Wood = 10, GaleFeather = 5 } },
	{ Id = "EmberBlade", Bench = 4, Cost = { Iron = 10, EmberShard = 4 } },
	{ Id = "TerraTotem", Bench = 4, Cost = { Stone = 10, TerraCore = 3 } },
	{ Id = "TideTotem", Bench = 4, Cost = { Stone = 10, TidePearl = 3 } },
	{ Id = "GaleTotem", Bench = 4, Cost = { Stone = 10, GaleFeather = 3 } },
	{ Id = "EmberTotem", Bench = 4, Cost = { Stone = 10, EmberShard = 3 } },
	-- เลเวล 5 (ของจากบอส)
	{ Id = "SunBeacon", Bench = 5, Cost = { Iron = 30, BeastHeart = 1, EmberShard = 5 } },
	{ Id = "FourfoldBlade", Bench = 5, Cost = { BeastHeart = 2, TerraCore = 5, TidePearl = 5, GaleFeather = 5, EmberShard = 5 } },
}

Recipes.ById = {}
for _, r in ipairs(Recipes.List) do
	Recipes.ById[r.Id] = r
end

-- ค่าอัปเกรดโต๊ะคราฟต์ (index = เลเวลที่จะไป)
Recipes.BenchUpgrade = {
	[2] = { Wood = 20, Stone = 12 },
	[3] = { Wood = 40, Stone = 30, Iron = 10 },
	[4] = { Iron = 24, TerraCore = 2, TidePearl = 2, GaleFeather = 2, EmberShard = 2 },
	[5] = { Iron = 40, Pelt = 10, BeastHeart = 1 },
}

-- เลเวลกองไฟ: MaxFuel, SafeRadius (สัตว์ป่า/สตอล์กเกอร์ไม่กล้าเข้า), Light, Reveal (หมอกเปิดกว้างเท่าไร)
Recipes.Campfire = {
	[1] = { MaxFuel = 300, SafeRadius = 42, Light = 60, Reveal = 900 },
	[2] = { MaxFuel = 450, SafeRadius = 56, Light = 70, Reveal = 1400, Cost = { Wood = 30, Stone = 10 } },
	[3] = { MaxFuel = 620, SafeRadius = 70, Light = 80, Reveal = 1900, Cost = { Wood = 60, Stone = 30, Coal = 6 } },
	[4] = { MaxFuel = 800, SafeRadius = 84, Light = 90, Reveal = 2500, Cost = { Wood = 100, Coal = 18, Iron = 14, TerraCore = 1, TidePearl = 1, GaleFeather = 1, EmberShard = 1 } },
	[5] = { MaxFuel = 1000, SafeRadius = 98, Light = 100, Reveal = 3200, Cost = { Wood = 160, Coal = 40, Iron = 30, TerraCore = 3, TidePearl = 3, GaleFeather = 3, EmberShard = 3 } },
	[6] = { MaxFuel = 1300, SafeRadius = 120, Light = 120, Reveal = 99999, Cost = { Wood = 250, Coal = 80, BeastHeart = 2 } },
}
Recipes.CampfireDrainDay = 1.0 -- เชื้อเพลิงต่อวินาที
Recipes.CampfireDrainNight = 1.7

return Recipes
