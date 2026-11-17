--[[
	LootTables — ของในกล่อง/หีบ (ใช้ทั้งเซิร์ฟเวอร์ LootService/EventService และการ์ดไอเทม ItemTooltip "หาได้จากไหน")
]]

local LootTables = {}

-- กล่อง 3 ระดับทั่วแมพ: เขียว / ม่วง / ทอง
LootTables.TierName = { "Green Chest", "Purple Chest", "Gold Chest" }
-- อาวุธ/เครื่องมือ 1 ชิ้นต่อกล่อง (น้ำหนักสุ่ม)
LootTables.TierTools = {
	{ { "StoneAxe", 18 }, { "Spear", 16 }, { "Dagger", 16 }, { "SpikedClub", 14 }, { "Pickaxe", 10 }, { "Torch", 9 }, { "Bow", 6 } },
	{ { "IronSword", 18 }, { "Mace", 18 }, { "IronAxe", 16 }, { "Bow", 12 }, { "Crossbow", 7 }, { "Katana", 6 } },
	{ { "Katana", 20 }, { "BattleAxe", 21 }, { "Crossbow", 19 }, { "WarHammer", 14 }, { "Scythe", 14 } },
}
-- กระเป๋า: สุ่มแยกแต่ละใบ (โอกาสได้ต่อกล่อง · ได้ทั้ง 2 ใบในกล่องเดียวก็ได้)
LootTables.TierSacks = {
	{ { "GoodSack", 0.55 } },
	{ { "GoodSack", 0.65 }, { "GiantSack", 0.35 } },
	{ { "GoodSack", 0.45 }, { "GiantSack", 0.60 } },
}
-- ทุกกล่องได้ ใยพืช + หนังสัตว์ + กระดูก อย่างละ 1 แน่นอน
LootTables.TierFixed = { { "Fiber", 1 }, { "Pelt", 1 }, { "Bone", 1 } }
-- ของสุ่มเพิ่ม (ไม่ซ้ำกัน) · กล่องเขียวมีโอกาส 8% ได้ชุดปฐมพยาบาลเพิ่ม (LootService)
LootTables.TierExtra = {
	{ count = { 1, 1 }, pool = { { "Bandage", 1, 1 }, { "Coal", 1, 3 } } },
	{ count = { 1, 2 }, pool = { { "Bandage", 1, 2 }, { "Iron", 2, 4 }, { "Coal", 2, 4 } } },
	{ count = { 2, 3 }, pool = { { "Medkit", 1, 1 }, { "Iron", 4, 6 }, { "Coal", 3, 5 } } },
}
LootTables.GreenMedkitChance = 0.08

-- หีบโบราณตามไบโอม (ของ, ต่ำสุด, สูงสุด)
LootTables.Ancient = {
	Earth = { { "Iron", 1, 3 }, { "TerraCore", 0, 2 }, { "Bandage", 0, 1 }, { "Berries", 2, 4 } },
	Water = { { "Fiber", 3, 5 }, { "Iron", 1, 2 }, { "TidePearl", 0, 2 }, { "Bandage", 0, 1 }, { "CookedMeat", 1, 2 } },
	Air = { { "Stone", 3, 5 }, { "Iron", 1, 3 }, { "GaleFeather", 0, 2 }, { "Bandage", 0, 1 }, { "Pelt", 1, 2 } },
	Fire = { { "Coal", 2, 4 }, { "Iron", 1, 3 }, { "EmberShard", 0, 2 }, { "Bandage", 0, 1 }, { "Stone", 2, 4 } },
}

-- หีบร่อน (Airdrop): อาวุธพิเศษ 1 ชิ้น (น้ำหนัก = % รวม 100)
LootTables.Airdrop = { { "Katana", 20 }, { "BattleAxe", 20 }, { "Crossbow", 15 }, { "WarHammer", 15 }, { "Scythe", 20 }, { "GiantSack", 10 } }

return LootTables
