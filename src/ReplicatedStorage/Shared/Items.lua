--[[
	Items — ไอเทมทั้งหมด
	Category: Resource / Food / Essence / Medical / Tool / Structure / Relic
	Fuel = ค่าเชื้อเพลิงเมื่อโยนเข้ากองไฟ
]]

local Items = {}

Items.Data = {
	-- ทรัพยากรพื้นฐาน
	Wood = { Name = "Wood", Thai = "ไม้", Category = "Resource", Fuel = 12, Color = Color3.fromRGB(150, 104, 62) },
	Stone = { Name = "Stone", Thai = "หิน", Category = "Resource", Color = Color3.fromRGB(150, 150, 156) },
	Fiber = { Name = "Fiber", Thai = "เส้นใย", Category = "Resource", Color = Color3.fromRGB(170, 200, 110) },
	Iron = { Name = "Iron Ore", Thai = "แร่เหล็ก", Category = "Resource", Color = Color3.fromRGB(196, 150, 120) },
	Coal = { Name = "Coal", Thai = "ถ่านหิน", Category = "Resource", Fuel = 40, Color = Color3.fromRGB(40, 40, 44) },
	Pelt = { Name = "Pelt", Thai = "หนังสัตว์", Category = "Resource", Color = Color3.fromRGB(160, 120, 84) },
	Bone = { Name = "Bone", Thai = "กระดูก", Category = "Resource", Color = Color3.fromRGB(232, 226, 206) },

	-- อาหาร (Food = เติมความอิ่ม, Heal = เติมเลือด)
	Berries = { Name = "Berries", Thai = "เบอร์รี่", Category = "Food", Food = 12, Heal = 2, Color = Color3.fromRGB(196, 40, 90) },
	RawMeat = { Name = "Raw Meat", Thai = "เนื้อดิบ", Category = "Food", Food = 8, Heal = -4, CooksInto = "CookedMeat", Color = Color3.fromRGB(220, 90, 90) },
	CookedMeat = { Name = "Cooked Meat", Thai = "เนื้อย่าง", Category = "Food", Food = 32, Heal = 8, Color = Color3.fromRGB(150, 76, 40) },
	Stew = { Name = "Hearty Stew", Thai = "สตูว์ร้อน", Category = "Food", Food = 60, Heal = 35, Color = Color3.fromRGB(214, 130, 60) },

	-- พลังธาตุ (ได้จากคริสตัลและสัตว์ธาตุ)
	TerraCore = { Name = "Terra Core", Thai = "แก่นปฐพี", Category = "Essence", Element = "Earth", Fuel = 60, Color = Color3.fromRGB(140, 220, 90) },
	TidePearl = { Name = "Tide Pearl", Thai = "มุกกระแสน้ำ", Category = "Essence", Element = "Water", Color = Color3.fromRGB(110, 200, 255) },
	GaleFeather = { Name = "Gale Feather", Thai = "ขนนกวายุ", Category = "Essence", Element = "Air", Color = Color3.fromRGB(226, 238, 255) },
	EmberShard = { Name = "Ember Shard", Thai = "เศษอัคคี", Category = "Essence", Element = "Fire", Fuel = 120, Color = Color3.fromRGB(255, 120, 40) },
	BeastHeart = { Name = "Beast Heart", Thai = "หัวใจอสูร", Category = "Relic", Fuel = 400, Color = Color3.fromRGB(255, 60, 110) },

	-- ยา
	Bandage = { Name = "Bandage", Thai = "ผ้าพันแผล", Category = "Medical", Heal = 35, Revive = true, Color = Color3.fromRGB(240, 236, 220) },
	Medkit = { Name = "Medkit", Thai = "ชุดปฐมพยาบาล", Category = "Medical", Heal = 100, Revive = true, Color = Color3.fromRGB(230, 60, 60) },

	-- เครื่องมือ / อาวุธ (สร้างเป็น Tool ใน Backpack)
	OldAxe = { Name = "Old Axe", Thai = "ขวานเก่า", Category = "Tool" },
	StoneAxe = { Name = "Stone Axe", Thai = "ขวานหิน", Category = "Tool" },
	IronAxe = { Name = "Iron Axe", Thai = "ขวานเหล็ก", Category = "Tool" },
	Pickaxe = { Name = "Pickaxe", Thai = "อีเต้อ", Category = "Tool" },
	Spear = { Name = "Bone Spear", Thai = "หอกกระดูก", Category = "Tool" },
	Torch = { Name = "Torch", Thai = "คบเพลิง", Category = "Tool" },
	Bow = { Name = "Hunter Bow", Thai = "ธนูนายพราน", Category = "Tool" },
	TerraHammer = { Name = "Terra Hammer", Thai = "ค้อนธรณี", Category = "Tool", Element = "Earth" },
	TidalTrident = { Name = "Tidal Trident", Thai = "ตรีศูลวารี", Category = "Tool", Element = "Water" },
	GaleBow = { Name = "Gale Longbow", Thai = "ธนูพายุ", Category = "Tool", Element = "Air" },
	EmberBlade = { Name = "Ember Greatsword", Thai = "ดาบใหญ่อัคคี", Category = "Tool", Element = "Fire" },
	FourfoldBlade = { Name = "Fourfold Blade", Thai = "ดาบสี่ธาตุ", Category = "Tool", Element = "All" },

	-- สิ่งก่อสร้าง (เก็บเป็นชุด แล้วกด B เพื่อวาง)
	LogWall = { Name = "Log Wall", Thai = "กำแพงไม้", Category = "Structure" },
	StoneWall = { Name = "Stone Wall", Thai = "กำแพงหิน", Category = "Structure" },
	SpikeTrap = { Name = "Spike Trap", Thai = "กับดักหนาม", Category = "Structure" },
	Lantern = { Name = "Lantern", Thai = "ตะเกียง", Category = "Structure" },
	Ballista = { Name = "Ballista", Thai = "หน้าไม้ยักษ์", Category = "Structure" },
	Bed = { Name = "Bed", Thai = "เตียง (จุดเกิด)", Category = "Structure" },
	FarmPlot = { Name = "Farm Plot", Thai = "แปลงเบอร์รี่", Category = "Structure" },
	CookPot = { Name = "Cook Pot", Thai = "หม้อตุ๋น", Category = "Structure" },
	TerraTotem = { Name = "Terra Totem", Thai = "เสาธรณี", Category = "Structure", Element = "Earth" },
	TideTotem = { Name = "Tide Totem", Thai = "เสาวารี", Category = "Structure", Element = "Water" },
	GaleTotem = { Name = "Gale Totem", Thai = "เสาวายุ", Category = "Structure", Element = "Air" },
	EmberTotem = { Name = "Ember Totem", Thai = "เสาอัคคี", Category = "Structure", Element = "Fire" },
	SunBeacon = { Name = "Sun Beacon", Thai = "ประภาคารสุริยะ", Category = "Structure" },
}

-- ค่าของเครื่องมือ: Damage ต่อสัตว์, Chop = ตัดไม้, Mine = ขุดหิน/แร่, Range, Cooldown
Items.Tools = {
	OldAxe = { Damage = 11, Chop = 1, Mine = 0.5, Range = 9, Cooldown = 0.6, Kind = "Axe" },
	StoneAxe = { Damage = 16, Chop = 2, Mine = 1, Range = 9, Cooldown = 0.55, Kind = "Axe" },
	IronAxe = { Damage = 24, Chop = 3, Mine = 1.5, Range = 10, Cooldown = 0.5, Kind = "Axe" },
	Pickaxe = { Damage = 14, Chop = 0.5, Mine = 3, Range = 9, Cooldown = 0.6, Kind = "Pick" },
	Spear = { Damage = 28, Chop = 0.3, Mine = 0.2, Range = 13, Cooldown = 0.7, Kind = "Spear" },
	Torch = { Damage = 8, Chop = 0, Mine = 0, Range = 8, Cooldown = 0.5, Kind = "Torch", Light = 28, Burn = 4 },
	Bow = { Damage = 22, Chop = 0, Mine = 0, Range = 160, Cooldown = 0.9, Kind = "Bow", Projectile = "Arrow" },
	TerraHammer = { Damage = 46, Chop = 2, Mine = 4, Range = 11, Cooldown = 1.0, Kind = "Hammer", Aoe = 12, Element = "Earth" },
	TidalTrident = { Damage = 38, Chop = 0.5, Mine = 0.5, Range = 15, Cooldown = 0.6, Kind = "Spear", Slow = 0.5, Element = "Water" },
	GaleBow = { Damage = 34, Chop = 0, Mine = 0, Range = 220, Cooldown = 0.55, Kind = "Bow", Projectile = "GaleArrow", Pierce = 3, Element = "Air" },
	EmberBlade = { Damage = 52, Chop = 2.5, Mine = 1, Range = 12, Cooldown = 0.75, Kind = "Sword", Burn = 10, Light = 20, Element = "Fire" },
	FourfoldBlade = { Damage = 90, Chop = 4, Mine = 4, Range = 14, Cooldown = 0.6, Kind = "Sword", Aoe = 10, Burn = 12, Slow = 0.6, Light = 30, Element = "All" },
}

-- ค่าของสิ่งก่อสร้าง
Items.Structures = {
	LogWall = { Health = 300, Size = Vector3.new(12, 10, 2.5) },
	StoneWall = { Health = 900, Size = Vector3.new(12, 12, 3.5) },
	SpikeTrap = { Health = 200, Size = Vector3.new(8, 2, 8), Damage = 18, Tick = 0.8 },
	Lantern = { Health = 120, Size = Vector3.new(2, 9, 2), Light = 45 },
	Ballista = { Health = 400, Size = Vector3.new(6, 7, 6), Damage = 30, Range = 120, Cooldown = 1.6 },
	Bed = { Health = 150, Size = Vector3.new(5, 2.5, 8) },
	FarmPlot = { Health = 150, Size = Vector3.new(10, 1.5, 10), GrowTime = 90, Yield = 4 },
	CookPot = { Health = 200, Size = Vector3.new(5, 5, 5) },
	TerraTotem = { Health = 600, Size = Vector3.new(4, 14, 4), Radius = 70, Element = "Earth" }, -- ซ่อมกำแพงรอบๆ
	TideTotem = { Health = 600, Size = Vector3.new(4, 14, 4), Radius = 70, Element = "Water" }, -- สัตว์ในรัศมีเดินช้า
	GaleTotem = { Health = 600, Size = Vector3.new(4, 14, 4), Radius = 60, Element = "Air" }, -- ผลักสัตว์ออก
	EmberTotem = { Health = 600, Size = Vector3.new(4, 14, 4), Radius = 55, Element = "Fire", Damage = 12 }, -- เผาสัตว์รอบๆ
	SunBeacon = { Health = 2000, Size = Vector3.new(10, 40, 10), Light = 160 },
}

function Items.Get(id)
	return Items.Data[id]
end

function Items.DisplayName(id)
	local d = Items.Data[id]
	return d and (d.Thai or d.Name) or id
end

return Items
