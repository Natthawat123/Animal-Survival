--[[
	Items — ไอเทมทั้งหมด
	Category: Resource / Food / Essence / Medical / Tool / Structure / Relic / Armor
	Fuel = ค่าเชื้อเพลิงเมื่อโยนเข้ากองไฟ
]]

local Items = {}

Items.Data = {
	-- ทรัพยากรพื้นฐาน
	Wood = { Name = "Wood", Thai = "Wood", Category = "Resource", Fuel = 15, Color = Color3.fromRGB(150, 104, 62) },
	Stone = { Name = "Stone", Thai = "Stone", Category = "Resource", Color = Color3.fromRGB(150, 150, 156) },
	Fiber = { Name = "Fiber", Thai = "Fiber", Category = "Resource", Color = Color3.fromRGB(170, 200, 110) },
	Iron = { Name = "Iron Ore", Thai = "Iron Ore", Category = "Resource", Color = Color3.fromRGB(196, 150, 120) },
	Coal = { Name = "Coal", Thai = "Coal", Category = "Resource", Fuel = 40, Color = Color3.fromRGB(40, 40, 44) },
	Pelt = { Name = "Pelt", Thai = "Pelt", Category = "Resource", Color = Color3.fromRGB(160, 120, 84) },
	Bone = { Name = "Bone", Thai = "Bone", Category = "Resource", Color = Color3.fromRGB(232, 226, 206) },

	-- อาหาร (Food = เติมความอิ่ม, Heal = เติมเลือด)
	Berries = { Name = "Berries", Thai = "Berries", Category = "Food", Food = 12, Heal = 2, Color = Color3.fromRGB(196, 40, 90) },
	RawMeat = { Name = "Raw Meat", Thai = "Raw Meat", Category = "Food", Food = 8, Heal = -4, CooksInto = "CookedMeat", Color = Color3.fromRGB(220, 90, 90) },
	CookedMeat = { Name = "Cooked Meat", Thai = "Cooked Meat", Category = "Food", Food = 32, Heal = 8, Color = Color3.fromRGB(150, 76, 40) },
	Stew = { Name = "Hearty Stew", Thai = "Hot Stew", Category = "Food", Food = 60, Heal = 35, Color = Color3.fromRGB(214, 130, 60) },
	-- Stamina = เติมสตามิน่าเต็มหลอด · Full = { Mult, Time } หิวช้าลงชั่วคราว
	BerryJuice = { Name = "Berry Juice", Thai = "Berry Juice", Category = "Food", Food = 20, Stamina = true, Color = Color3.fromRGB(150, 40, 110) },
	BerryPie = { Name = "Berry Pie", Thai = "Berry Pie", Category = "Food", Food = 40, Full = { Mult = 0.5, Time = 120 }, Color = Color3.fromRGB(80, 70, 190) },

	-- พลังธาตุ (ได้จากคริสตัลและสัตว์ธาตุ)
	TerraCore = { Name = "Terra Core", Thai = "Terra Core", Category = "Essence", Element = "Earth", Fuel = 60, Color = Color3.fromRGB(140, 220, 90) },
	TidePearl = { Name = "Tide Pearl", Thai = "Tide Pearl", Category = "Essence", Element = "Water", Color = Color3.fromRGB(110, 200, 255) },
	GaleFeather = { Name = "Frost Feather", Thai = "Frost Feather", Category = "Essence", Element = "Air", Color = Color3.fromRGB(226, 238, 255) },
	EmberShard = { Name = "Ember Shard", Thai = "Ember Shard", Category = "Essence", Element = "Fire", Fuel = 120, Color = Color3.fromRGB(255, 120, 40) },
	-- หัวใจอสูร 4 ธาตุ (ดรอปจากบอสธาตุนั้น ทั้งรังบอสและคืนบุก) · Model = ใช้โมเดลของไอเทมอื่น + Tint ย้อมสี
	TerraHeart = { Name = "Terra Heart", Thai = "Earth Beast Heart", Category = "Relic", Element = "Earth", Model = "BeastHeart", Tint = Color3.fromRGB(120, 235, 90), Color = Color3.fromRGB(120, 235, 90) },
	TideHeart = { Name = "Tide Heart", Thai = "Water Beast Heart", Category = "Relic", Element = "Water", Model = "BeastHeart", Tint = Color3.fromRGB(80, 190, 255), Color = Color3.fromRGB(80, 190, 255) },
	FrostHeart = { Name = "Frost Heart", Thai = "Frost Beast Heart", Category = "Relic", Element = "Air", Model = "BeastHeart", Tint = Color3.fromRGB(205, 235, 255), Color = Color3.fromRGB(205, 235, 255) },
	EmberHeart = { Name = "Ember Heart", Thai = "Fire Beast Heart", Category = "Relic", Element = "Fire", Model = "BeastHeart", Tint = Color3.fromRGB(255, 120, 40), Color = Color3.fromRGB(255, 120, 40) },

	-- ยา
	Bandage = { Name = "Bandage", Thai = "Bandage", Category = "Medical", Heal = 35, Revive = true, Color = Color3.fromRGB(240, 236, 220) },
	Medkit = { Name = "Medkit", Thai = "First Aid Kit", Category = "Medical", Heal = 100, Revive = true, Color = Color3.fromRGB(230, 60, 60) },
	HerbSalve = { Name = "Herb Salve", Thai = "Herbal Medicine", Category = "Medical", Heal = 20, Color = Color3.fromRGB(90, 190, 200) },

	-- เครื่องมือ / อาวุธ (สร้างเป็น Tool ใน Backpack)
	OldAxe = { Name = "Old Axe", Thai = "Old Axe", Category = "Tool" },
	-- กระสอบ (อยู่ในช่อง Tool ด้านล่าง) — ใส่ของได้ตามความจุ
	OldSack = { Name = "Old Sack", Thai = "Old Sack", Category = "Tool" },
	GoodSack = { Name = "Good Sack", Thai = "Good Sack", Category = "Tool" },
	GiantSack = { Name = "Giant Sack", Thai = "Giant Sack", Category = "Tool" },
	StoneAxe = { Name = "Stone Axe", Thai = "Stone Axe", Category = "Tool" },
	IronAxe = { Name = "Iron Axe", Thai = "Iron Axe", Category = "Tool" },
	Pickaxe = { Name = "Pickaxe", Thai = "Pickaxe", Category = "Tool" },
	BuildHammer = { Name = "Builder's Hammer", Thai = "Builder's Hammer", Category = "Tool" }, -- ย้าย/รื้อสิ่งก่อสร้าง
	Spear = { Name = "Bone Spear", Thai = "Bone Spear", Category = "Tool" },
	Torch = { Name = "Torch", Thai = "Torch", Category = "Tool" },
	Bow = { Name = "Hunter Bow", Thai = "Hunter's Bow", Category = "Tool" },
	TerraHammer = { Name = "Terra Hammer", Thai = "Terra Hammer", Category = "Tool", Element = "Earth" },
	TidalTrident = { Name = "Tidal Trident", Thai = "Tide Trident", Category = "Tool", Element = "Water" },
	GaleBow = { Name = "Gale Longbow", Thai = "Storm Bow", Category = "Tool", Element = "Air" },
	EmberBlade = { Name = "Ember Greatsword", Thai = "Ember Greatsword", Category = "Tool", Element = "Fire" },
	FourfoldBlade = { Name = "Fourfold Blade", Thai = "Four-Element Sword", Category = "Tool", Element = "All" },
	EmberStaff = { Name = "Ember Staff", Thai = "Fire Staff", Category = "Tool", Element = "Fire" },
	-- อาวุธทั่วไป (Creator Store) · คราฟต์ที่โต๊ะ Lv1-4 + สุ่มได้จากกล่อง 3 ระดับ
	Dagger = { Name = "Hunting Knife", Thai = "Hunting Knife", Category = "Tool" },
	SpikedClub = { Name = "Spiked Club", Thai = "Spiked Club", Category = "Tool" },
	IronSword = { Name = "Iron Sword", Thai = "Iron Sword", Category = "Tool" },
	Mace = { Name = "Morning Star", Thai = "Morning Star", Category = "Tool" },
	BattleAxe = { Name = "Battle Axe", Thai = "Battle Axe", Category = "Tool" },
	Crossbow = { Name = "Crossbow", Thai = "Crossbow", Category = "Tool" },
	Katana = { Name = "Katana", Thai = "Katana", Category = "Tool" },
	WarHammer = { Name = "War Hammer", Thai = "War Hammer", Category = "Tool" },
	Scythe = { Name = "Reaper Scythe", Thai = "Reaper Scythe", Category = "Tool" },
	-- อาวุธประจำคลาส 5 ดาว (ได้ตอนเริ่มรอบ ไม่มีสูตรคราฟต์) · โมเดล Import 3D -> assets/rbxm/Weapons/<Id>
	ArcaneStaff = { Name = "Arcane Staff", Thai = "Arcane Staff", Category = "Tool", Element = "All" },
	BloodScythe = { Name = "Blood Reaper", Thai = "Blood Reaper", Category = "Tool" },
	VerdantStaff = { Name = "Verdant Staff", Thai = "Verdant Staff", Category = "Tool", Element = "Earth" },

	-- เกราะ (คราฟต์แล้วสวมทันที ไม่กินที่กระสอบ · ArmorHP = เลือดสูงสุดเพิ่ม · Tier สูงกว่าเปลี่ยนทับได้)
	WoodArmor = { Name = "Wood Armor", Thai = "Wood Armor", Category = "Armor", ArmorHP = 30, Tier = 1, Color = Color3.fromRGB(150, 104, 62) },
	IronArmor = { Name = "Iron Armor", Thai = "Iron Armor", Category = "Armor", ArmorHP = 60, Tier = 2, Color = Color3.fromRGB(196, 200, 210) },
	GoldArmor = { Name = "Gold Armor", Thai = "Gold Armor", Category = "Armor", ArmorHP = 100, Tier = 3, Color = Color3.fromRGB(240, 196, 70) },

	-- สิ่งก่อสร้าง (เก็บเป็นชุด แล้วกด B เพื่อวาง)
	LogWall = { Name = "Log Wall", Thai = "Wood Wall", Category = "Structure" },
	StoneWall = { Name = "Stone Wall", Thai = "Stone Wall", Category = "Structure" },
	SpikeTrap = { Name = "Spike Trap", Thai = "Spike Trap", Category = "Structure" },
	Lantern = { Name = "Lantern", Thai = "Lantern", Category = "Structure" },
	Ballista = { Name = "Ballista", Thai = "Ballista", Category = "Structure" },
	Bed = { Name = "Bed", Thai = "Bed (+1 Day)", Category = "Structure" },
	Bed2 = { Name = "Royal Bed", Thai = "Royal Bed (+1 Day)", Category = "Structure" }, -- เตียง 2 (โต๊ะเลเวล 4)
	FarmPlot = { Name = "Farm Plot", Thai = "Berry Patch", Category = "Structure" },
	CookPot = { Name = "Cook Pot", Thai = "Stew Pot", Category = "Structure" },
	TerraTotem = { Name = "Terra Totem", Thai = "Earth Pillar", Category = "Structure", Element = "Earth" },
	TideTotem = { Name = "Tide Totem", Thai = "Water Pillar", Category = "Structure", Element = "Water" },
	GaleTotem = { Name = "Gale Totem", Thai = "Frost Pillar", Category = "Structure", Element = "Air" },
	EmberTotem = { Name = "Ember Totem", Thai = "Fire Pillar", Category = "Structure", Element = "Fire" },
	SunBeacon = { Name = "Sun Beacon", Thai = "Solar Beacon", Category = "Structure" },
}

-- ค่าคราฟต์แบบ "อะไรก็ได้ในกลุ่ม" (ใช้ใน Cost เหมือนไอเทม เช่น AnyEssence = 2 -> แก่นธาตุธาตุไหนก็ได้รวม 2)
Items.AnyGroups = {
	AnyEssence = { "TerraCore", "TidePearl", "GaleFeather", "EmberShard" },
	AnyHeart = { "TerraHeart", "TideHeart", "FrostHeart", "EmberHeart" },
}
Items.AnyThai = { AnyEssence = "Element Essence (any element)", AnyHeart = "Beast Heart (any element)" }
-- ของประจำธาตุ
Items.ElementEssence = { Earth = "TerraCore", Water = "TidePearl", Air = "GaleFeather", Fire = "EmberShard" }
Items.ElementHeart = { Earth = "TerraHeart", Water = "TideHeart", Air = "FrostHeart", Fire = "EmberHeart" }

-- ความจุกระสอบ (หน่วย = ของ 1 ชิ้น) · ใช้ใบที่ดีที่สุดที่มี
Items.Sacks = { OldSack = 10, GoodSack = 20, GiantSack = 30 }
Items.SackColor = { OldSack = Color3.fromRGB(150, 120, 80), GoodSack = Color3.fromRGB(110, 140, 90), GiantSack = Color3.fromRGB(150, 90, 60) }

-- ของที่กินที่ในกระสอบ (เครื่องมือ/สิ่งก่อสร้างไม่นับ)
function Items.Bulk(id)
	local d = Items.Data[id]
	-- ยา (ผ้าพันแผล/ชุดปฐมพยาบาล) อยู่ช่องของตัวเองในแถบเครื่องมือ ไม่กินที่กระสอบ
	return d ~= nil and d.Category ~= "Tool" and d.Category ~= "Structure" and d.Category ~= "Medical" and d.Category ~= "Armor"
end

-- ค่าของเครื่องมือ: Damage ต่อสัตว์, Chop = ตัดไม้, Mine = ขุดหิน/แร่, Range, Cooldown
Items.Tools = {
	OldAxe = { Damage = 11, Chop = 1, Mine = 0.5, Range = 9, Cooldown = 0.6, Kind = "Axe" },
	StoneAxe = { Damage = 16, Chop = 2, Mine = 1, Range = 9, Cooldown = 0.55, Kind = "Axe" },
	IronAxe = { Damage = 24, Chop = 3, Mine = 1.5, Range = 10, Cooldown = 0.5, Kind = "Axe" },
	Pickaxe = { Damage = 14, Chop = 0.5, Mine = 3, Range = 9, Cooldown = 0.6, Kind = "Pick" },
	-- ค้อนช่าง: ถือแล้วคลิกสิ่งก่อสร้าง = เมนูย้าย/รื้อ (BuildHammer.lua) · ตีสัตว์ได้นิดหน่อย
	BuildHammer = { Damage = 6, Chop = 0, Mine = 0, Range = 8, Cooldown = 0.5, Kind = "Hammer", Builder = true },
	Spear = { Damage = 28, Chop = 0.3, Mine = 0.2, Range = 13, Cooldown = 0.7, Kind = "Spear" },
	Torch = { Damage = 8, Chop = 0, Mine = 0, Range = 8, Cooldown = 0.5, Kind = "Torch", Light = 28, Burn = 4 },
	Bow = { Damage = 22, Chop = 0, Mine = 0, Range = 160, Cooldown = 0.9, Kind = "Bow", Projectile = "Arrow" },
	TerraHammer = { Damage = 46, Chop = 2, Mine = 4, Range = 11, Cooldown = 1.0, Kind = "Hammer", Aoe = 12, Element = "Earth" },
	TidalTrident = { Damage = 38, Chop = 0.5, Mine = 0.5, Range = 15, Cooldown = 0.6, Kind = "Spear", Slow = 0.5, Element = "Water" },
	GaleBow = { Damage = 34, Chop = 0, Mine = 0, Range = 220, Cooldown = 0.55, Kind = "Bow", Projectile = "GaleArrow", Pierce = 3, Element = "Air" },
	EmberBlade = { Damage = 52, Chop = 2.5, Mine = 1, Range = 12, Cooldown = 0.75, Kind = "Sword", Burn = 10, Light = 20, Element = "Fire" },
	FourfoldBlade = { Damage = 90, Chop = 4, Mine = 4, Range = 14, Cooldown = 0.6, Kind = "Sword", Aoe = 10, Burn = 12, Slow = 0.6, Light = 30, Element = "All" },
	-- คทา: ตีแล้วปล่อยลูกไฟพุ่งไปทางที่เล็ง (ระเบิดวงเล็ก + ติดไฟ) · ยืนชิดต้นไม้/หิน = ฟาดตัด/ทุบได้ (แทนขวาน)
	EmberStaff = { Damage = 20, Chop = 0, Mine = 0, Range = 9, Cooldown = 0.7, Kind = "Staff", Bolt = { Speed = 150, Range = 140, Blast = 7, Size = 1.6, FxScale = 0.08, ImpactScale = 0.22 }, Burn = 4, Light = 16, Element = "Fire" },
	Dagger = { Damage = 15, Chop = 0.3, Mine = 0.2, Range = 7, Cooldown = 0.32, Kind = "Sword" },
	SpikedClub = { Damage = 22, Chop = 0.5, Mine = 0.8, Range = 9, Cooldown = 0.75, Kind = "Hammer" },
	IronSword = { Damage = 32, Chop = 0.8, Mine = 0.3, Range = 11, Cooldown = 0.55, Kind = "Sword" },
	Mace = { Damage = 38, Chop = 0.5, Mine = 1.5, Range = 10, Cooldown = 0.85, Kind = "Hammer", Aoe = 6 },
	BattleAxe = { Damage = 44, Chop = 3.5, Mine = 1, Range = 11, Cooldown = 0.8, Kind = "Axe" },
	Crossbow = { Damage = 40, Chop = 0, Mine = 0, Range = 200, Cooldown = 1.1, Kind = "Bow", Projectile = "Arrow" },
	Katana = { Damage = 40, Chop = 1, Mine = 0.3, Range = 12, Cooldown = 0.45, Kind = "Sword" },
	WarHammer = { Damage = 62, Chop = 1.5, Mine = 4.5, Range = 12, Cooldown = 1.1, Kind = "Hammer", Aoe = 11 },
	Scythe = { Damage = 54, Chop = 2, Mine = 0.5, Range = 15, Cooldown = 0.8, Kind = "Sword", Aoe = 8 },
	ArcaneStaff = { Fx = "Arcane", Damage = 30, Chop = 0, Mine = 0, Range = 9, Cooldown = 0.6, Kind = "Staff", Bolt = { Speed = 170, Range = 150, Blast = 9, Size = 1.8, FxScale = 0.05, ImpactScale = 0.15 }, Burn = 4, Light = 16, Element = "All" },
	BloodScythe = { Fx = "Blood", Damage = 50, Chop = 1.5, Mine = 0.5, Range = 14, Cooldown = 0.72, Kind = "Sword", Aoe = 8 },
	VerdantStaff = { Fx = "Verdant", Damage = 26, Chop = 0, Mine = 0, Range = 9, Cooldown = 0.6, Kind = "Staff", Bolt = { Speed = 150, Range = 140, Blast = 8, Size = 1.6, FxScale = 0.05, ImpactScale = 0.13 }, Slow = 0.5, Light = 12, Element = "Earth" },
}

-- ค่าของสิ่งก่อสร้าง
Items.Structures = {
	LogWall = { Health = 300, Size = Vector3.new(12, 10, 2.5) },
	StoneWall = { Health = 900, Size = Vector3.new(12, 12, 3.5) },
	SpikeTrap = { Health = 200, Size = Vector3.new(8, 2, 8), Damage = 18, Tick = 0.8 },
	Lantern = { Health = 120, Size = Vector3.new(2, 9, 2), Light = 45 },
	Ballista = { Health = 400, Size = Vector3.new(6, 7, 6), Damage = 30, Range = 120, Cooldown = 1.6 },
	Bed = { Health = 150, Size = Vector3.new(6.8, 5.2, 8) }, -- เตียงไม้ (3D Model/bad · Cozy Wooden Bed)
	Bed2 = { Health = 250, Size = Vector3.new(7.6, 6, 8) }, -- เตียงม่านม่วง (3D Model/bad · Royal Violet Canopy)
	FarmPlot = { Health = 150, Size = Vector3.new(10, 1.5, 10), GrowTime = 90, Yield = 4 },
	CookPot = { Health = 200, Size = Vector3.new(5, 5, 5) },
	TerraTotem = { Health = 600, Size = Vector3.new(4, 14, 4), Radius = 70, Element = "Earth" }, -- ซ่อมกำแพงรอบๆ
	TideTotem = { Health = 600, Size = Vector3.new(4, 14, 4), Radius = 70, Element = "Water" }, -- สัตว์ในรัศมีเดินช้า
	GaleTotem = { Health = 600, Size = Vector3.new(4, 14, 4), Radius = 60, Element = "Air" }, -- ผลักสัตว์ออก
	EmberTotem = { Health = 600, Size = Vector3.new(4, 14, 4), Radius = 55, Element = "Fire", Damage = 12 }, -- เผาสัตว์รอบๆ
	SunBeacon = { Health = 2000, Size = Vector3.new(10, 40, 10), Light = 160 },
}

-- คำอธิบายสั้น (ภาษาไทย) ใช้ในกล่องรายละเอียดไอเทม (ItemTooltip)
Items.Desc = {
	Wood = "Wood from trees. Used for almost everything and can be thrown into the campfire",
	Stone = "Mined from rocks. Used for tools and walls",
	Fiber = "Fiber from hunting (hare, crocodile, crab, octopus, snow bull, fire ram) / chests / supply crates · Used for bandages, bows and sacks",
	Iron = "Iron ore from ore rocks. Used for weapons and high-level items",
	Coal = "Coal. Premium fuel that keeps the campfire burning long",
	Pelt = "Animal pelt. Used for sacks/beds and trading with the wandering trader",
	Bone = "Animal bone. Used for spears and the Giant Sack",
	Berries = "Fresh berries. Eat to ease hunger · Make berry juice/herbal medicine (Bench Lv.1) · Plant patches · Pies and stew at the Stew Pot",
	BerryJuice = "Fresh-squeezed berry juice. Eases hunger and fully refills stamina",
	BerryPie = "Berry pie from the Stew Pot. Very filling, hunger drops half as fast for 2 minutes",
	RawMeat = "Raw meat. Edible but costs HP — cook it at the campfire first",
	CookedMeat = "Juicy cooked meat. Eases a lot of hunger",
	Stew = "Hot stew from the Stew Pot. Keeps you full for long and heals a lot",
	TerraCore = "Earth essence · Break green crystals in the Earth forest / chests / meteors / sanctums / Earth boss · Used for the Terra Hammer, Earth Pillar, bench and campfire upgrades",
	TidePearl = "Water essence · Break blue crystals in Whirlpool Lake / chests / meteors / sanctums / Water boss · Used for the Trident, Water Pillar, bench and campfire upgrades",
	GaleFeather = "Frost essence · Break white crystals in Skyreach Highlands / chests / meteors / sanctums / Frost boss · Used for the Storm Bow, Frost Pillar, bench and campfire upgrades",
	EmberShard = "Fire essence · Break orange crystals in the volcano / chests / meteors / sanctums / Fire boss · Used for the Ember Greatsword, Fire Pillar, Beacon · Strong fuel",
	TerraHeart = "Heart of the Earth boss (Golgran) · Used for the Terra Hammer and the Four-Element Sword",
	TideHeart = "Heart of the Water boss (Tyrannomosa) · Used for the Tide Trident and the Four-Element Sword",
	FrostHeart = "Heart of the Frost boss (Frostmaw) · Used for the Storm Bow and the Four-Element Sword",
	EmberHeart = "Heart of the Fire boss (Ignarax) · Used for the Ember Greatsword and the Four-Element Sword",
	Bandage = "Bandage up to heal, and revive downed teammates",
	Medkit = "Fully heals HP, and revives downed teammates",
	HerbSalve = "Herbal medicine from berries. Heals a little (cannot revive teammates)",
	OldAxe = "Starter axe. Chops wood slowly",
	OldSack = "Sack that holds 10 items — hold it and click items to collect",
	GoodSack = "Sack that holds 20 items",
	GiantSack = "Sack that holds 30 items",
	StoneAxe = "Stone axe. Chops wood twice as fast",
	IronAxe = "Iron axe. The fastest axe for chopping wood",
	Pickaxe = "Pickaxe. Mines rock and ore fast",
	BuildHammer = "Builder's hammer. Hold it and click a building to move it or remove it (get half the materials back)",
	Spear = "Bone spear. Long reach, high damage",
	Torch = "Torch for light. Scares off the Moonfang",
	Bow = "Long-range bow for hunting from a safe distance",
	TerraHammer = "Earth hammer. Smashes in a wide area",
	TidalTrident = "Water trident. Slows animals down",
	GaleBow = "Wind bow. Arrows pierce through several enemies",
	EmberBlade = "Fire sword. Burns enemies and gives light",
	FourfoldBlade = "Four-Element Sword. The ultimate weapon in the game",
	Dagger = "Light, fast hunting knife · Very quick strikes",
	SpikedClub = "Heavy wooden club with iron spikes · Cracks rocks too",
	IronSword = "Balanced iron sword · Fast, solid damage",
	Mace = "Spiked morning star · Hits everything around the target",
	BattleAxe = "Double-bladed battle axe · Hits hard and fells trees fastest",
	Crossbow = "Heavy crossbow · Slow to reload, powerful long-range bolts",
	Katana = "Sharp katana · Very fast, high-damage slashes",
	WarHammer = "Huge war hammer · Crushing area damage, smashes ore rocks",
	Scythe = "Reaper scythe · Widest reach, sweeps groups of enemies",
	ArcaneStaff = "Elementalist's signature staff · Fires exploding arcane bolts (strong against every element)",
	BloodScythe = "Vampire's signature scythe · Huge reach, sweeps groups of enemies",
	VerdantStaff = "Wildwood Druid's signature staff · Fires thorn bolts that slow monsters · Can't chop trees or mine rocks",
	EmberStaff = "The Elementalist's fire staff. Hits launch exploding fireballs at enemies · Can't chop trees or mine rocks",
	LogWall = "Wood wall. Blocks animal packs",
	StoneWall = "Stone wall. Very sturdy",
	SpikeTrap = "Spike trap. Stabs animals that step on it",
	Lantern = "Lantern. Lights the area and scares off the Moonfang",
	Ballista = "Ballista. Shoots animals automatically",
	WoodArmor = "Wood armor. Equips right after crafting, raises Max HP",
	IronArmor = "Iron armor with shoulder plates. Sturdy, raises Max HP a lot",
	GoldArmor = "Engraved gold warrior armor. Raises Max HP the most",
	Bed = "Place it to rest: day multiplier +1 (no bonus yet = x2) · every morning the day counter moves by the multiplier · Max 1 bed per server per run",
	Bed2 = "Place it to rest: day multiplier +1 (no bonus yet = x2) · every morning the day counter moves by the multiplier · Max 1 bed per server per run",
	FarmPlot = "Grows berries you can keep picking",
	CookPot = "Stew pot. Makes stew (meat + berries) and berry pie (berries + wood)",
	TerraTotem = "Earth pillar. Repairs nearby walls",
	TideTotem = "Water pillar. Slows animals in range",
	GaleTotem = "Frost pillar. Pushes animals away",
	EmberTotem = "Fire pillar. Burns nearby animals",
	SunBeacon = "Solar beacon. Gives off massive light",
}

-- ชื่อหมวดภาษาไทย
Items.CategoryThai = {
	Resource = "Materials", Food = "Food", Essence = "Elemental Power", Medical = "Medicine", Tool = "Tools/Weapons", Structure = "Buildings", Relic = "Rare Items",
}

function Items.Get(id)
	return Items.Data[id]
end

function Items.DisplayName(id)
	if Items.AnyThai[id] then
		return Items.AnyThai[id]
	end
	local d = Items.Data[id]
	return d and (d.Thai or d.Name) or id
end

return Items
