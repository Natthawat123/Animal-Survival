--[[
	Shop — รายการของในร้าน
	  Kits  : ชุดเริ่มต้น (ซื้อด้วย Ruby ในล็อบบี้ ใช้ 1 ครั้งต่อรอบ ได้ของตอนวาร์ปลงแมพ)
	  Trader: พ่อค้าเร่ในแมพ (มาที่แคมป์ทุก 3 วัน) แลกของด้วยหนัง/กระดูก/แก่นธาตุ
]]

local Shop = {}

Shop.Kits = {
	{ Id = "Medic", Name = "First Aid Kit", Icon = "🩹", Price = 8, Items = { Bandage = 3, Medkit = 1 }, Desc = "3 Bandages + 1 First Aid Kit" },
	{ Id = "Builder", Name = "Carpenter Kit", Icon = "🔨", Price = 10, Items = { Wood = 40, Stone = 20, LogWall = 2 }, Desc = "40 Wood, 20 Stone, 2 Wood Walls" },
	{ Id = "Hunter", Name = "Hunter Kit", Icon = "🏹", Price = 15, Items = { Bow = 1, CookedMeat = 4 }, Desc = "Hunter's Bow + 4 Cooked Meat" },
	{ Id = "Fire", Name = "Flamekeeper Kit", Icon = "🔥", Price = 12, Items = { Coal = 8, Torch = 1, Lantern = 1 }, Desc = "8 Coal, Torch, Lantern" },
	{ Id = "Warrior", Name = "Warrior Kit", Icon = "⚔", Price = 25, Items = { Spear = 1, IronAxe = 1 }, Desc = "Bone Spear + Iron Axe" },
	{ Id = "Elemental", Name = "Awakened Element Kit", Icon = "🔮", Price = 40, Items = { TerraCore = 2, TidePearl = 2, GaleFeather = 2, EmberShard = 2 }, Desc = "2 of each element essence" },
}
Shop.KitById = {}
for _, k in ipairs(Shop.Kits) do
	Shop.KitById[k.Id] = k
end

-- พ่อค้าเร่: Give = ได้อะไร, Cost = จ่ายอะไร
Shop.Trader = {
	{ Id = "T_Bandage", Give = { Bandage = 2 }, Cost = { Pelt = 2 } },
	{ Id = "T_Medkit", Give = { Medkit = 1 }, Cost = { Pelt = 4, Bone = 2 } },
	{ Id = "T_Iron", Give = { Iron = 6 }, Cost = { Pelt = 3 } },
	{ Id = "T_Coal", Give = { Coal = 6 }, Cost = { Bone = 3 } },
	{ Id = "T_Stew", Give = { Stew = 2 }, Cost = { Pelt = 2, Berries = 4 } },
	{ Id = "T_Bow", Give = { Bow = 1 }, Cost = { Pelt = 6, Bone = 4 } },
	{ Id = "T_IronAxe", Give = { IronAxe = 1 }, Cost = { Pelt = 8, Iron = 4 } },
	{ Id = "T_Ballista", Give = { Ballista = 1 }, Cost = { Pelt = 10, Bone = 6 } },
}
Shop.TraderById = {}
for _, t in ipairs(Shop.Trader) do
	Shop.TraderById[t.Id] = t
end
Shop.TraderEvery = 3 -- มาทุกกี่วัน (วันที่ 2, 5, 8, ...)

return Shop
