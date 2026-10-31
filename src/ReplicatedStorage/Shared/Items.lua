--[[
	Items — ไอเทมทั้งหมด
	Category: Resource / Food / Essence / Medical / Tool / Structure / Relic / Armor
	Fuel = ค่าเชื้อเพลิงเมื่อโยนเข้ากองไฟ
]]

local Items = {}

Items.Data = {
	-- ทรัพยากรพื้นฐาน
	Wood = { Name = "Wood", Thai = "ไม้", Category = "Resource", Fuel = 15, Color = Color3.fromRGB(150, 104, 62) },
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
	-- Stamina = เติมสตามิน่าเต็มหลอด · Full = { Mult, Time } หิวช้าลงชั่วคราว
	BerryJuice = { Name = "Berry Juice", Thai = "น้ำเบอร์รี่", Category = "Food", Food = 20, Stamina = true, Color = Color3.fromRGB(150, 40, 110) },
	BerryPie = { Name = "Berry Pie", Thai = "พายเบอร์รี่", Category = "Food", Food = 40, Full = { Mult = 0.5, Time = 120 }, Color = Color3.fromRGB(80, 70, 190) },

	-- พลังธาตุ (ได้จากคริสตัลและสัตว์ธาตุ)
	TerraCore = { Name = "Terra Core", Thai = "แก่นปฐพี", Category = "Essence", Element = "Earth", Fuel = 60, Color = Color3.fromRGB(140, 220, 90) },
	TidePearl = { Name = "Tide Pearl", Thai = "มุกกระแสน้ำ", Category = "Essence", Element = "Water", Color = Color3.fromRGB(110, 200, 255) },
	GaleFeather = { Name = "Frost Feather", Thai = "ขนนกน้ำแข็ง", Category = "Essence", Element = "Air", Color = Color3.fromRGB(226, 238, 255) },
	EmberShard = { Name = "Ember Shard", Thai = "เศษอัคคี", Category = "Essence", Element = "Fire", Fuel = 120, Color = Color3.fromRGB(255, 120, 40) },
	-- หัวใจอสูร 4 ธาตุ (ดรอปจากบอสธาตุนั้น ทั้งรังบอสและคืนบุก) · Model = ใช้โมเดลของไอเทมอื่น + Tint ย้อมสี
	TerraHeart = { Name = "Terra Heart", Thai = "หัวใจอสูรดิน", Category = "Relic", Element = "Earth", Model = "BeastHeart", Tint = Color3.fromRGB(120, 235, 90), Color = Color3.fromRGB(120, 235, 90) },
	TideHeart = { Name = "Tide Heart", Thai = "หัวใจอสูรน้ำ", Category = "Relic", Element = "Water", Model = "BeastHeart", Tint = Color3.fromRGB(80, 190, 255), Color = Color3.fromRGB(80, 190, 255) },
	FrostHeart = { Name = "Frost Heart", Thai = "หัวใจอสูรน้ำแข็ง", Category = "Relic", Element = "Air", Model = "BeastHeart", Tint = Color3.fromRGB(205, 235, 255), Color = Color3.fromRGB(205, 235, 255) },
	EmberHeart = { Name = "Ember Heart", Thai = "หัวใจอสูรไฟ", Category = "Relic", Element = "Fire", Model = "BeastHeart", Tint = Color3.fromRGB(255, 120, 40), Color = Color3.fromRGB(255, 120, 40) },

	-- ยา
	Bandage = { Name = "Bandage", Thai = "ผ้าพันแผล", Category = "Medical", Heal = 35, Revive = true, Color = Color3.fromRGB(240, 236, 220) },
	Medkit = { Name = "Medkit", Thai = "ชุดปฐมพยาบาล", Category = "Medical", Heal = 100, Revive = true, Color = Color3.fromRGB(230, 60, 60) },
	HerbSalve = { Name = "Herb Salve", Thai = "ยาสมุนไพร", Category = "Medical", Heal = 20, Color = Color3.fromRGB(90, 190, 200) },

	-- เครื่องมือ / อาวุธ (สร้างเป็น Tool ใน Backpack)
	OldAxe = { Name = "Old Axe", Thai = "ขวานเก่า", Category = "Tool" },
	-- กระสอบ (อยู่ในช่อง Tool ด้านล่าง) — ใส่ของได้ตามความจุ
	OldSack = { Name = "Old Sack", Thai = "กระสอบเก่า", Category = "Tool" },
	GoodSack = { Name = "Good Sack", Thai = "กระสอบดี", Category = "Tool" },
	GiantSack = { Name = "Giant Sack", Thai = "กระสอบยักษ์", Category = "Tool" },
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
	EmberStaff = { Name = "Ember Staff", Thai = "คทาเพลิง", Category = "Tool", Element = "Fire" },

	-- เกราะ (คราฟต์แล้วสวมทันที ไม่กินที่กระสอบ · ArmorHP = เลือดสูงสุดเพิ่ม · Tier สูงกว่าเปลี่ยนทับได้)
	WoodArmor = { Name = "Wood Armor", Thai = "เกราะไม้", Category = "Armor", ArmorHP = 30, Tier = 1, Color = Color3.fromRGB(150, 104, 62) },
	IronArmor = { Name = "Iron Armor", Thai = "เกราะเหล็ก", Category = "Armor", ArmorHP = 60, Tier = 2, Color = Color3.fromRGB(196, 200, 210) },
	GoldArmor = { Name = "Gold Armor", Thai = "เกราะทอง", Category = "Armor", ArmorHP = 100, Tier = 3, Color = Color3.fromRGB(240, 196, 70) },

	-- สิ่งก่อสร้าง (เก็บเป็นชุด แล้วกด B เพื่อวาง)
	LogWall = { Name = "Log Wall", Thai = "กำแพงไม้", Category = "Structure" },
	StoneWall = { Name = "Stone Wall", Thai = "กำแพงหิน", Category = "Structure" },
	SpikeTrap = { Name = "Spike Trap", Thai = "กับดักหนาม", Category = "Structure" },
	Lantern = { Name = "Lantern", Thai = "ตะเกียง", Category = "Structure" },
	Ballista = { Name = "Ballista", Thai = "หน้าไม้ยักษ์", Category = "Structure" },
	Bed = { Name = "Bed", Thai = "เตียง (+1 วัน)", Category = "Structure" },
	FarmPlot = { Name = "Farm Plot", Thai = "แปลงเบอร์รี่", Category = "Structure" },
	CookPot = { Name = "Cook Pot", Thai = "หม้อตุ๋น", Category = "Structure" },
	TerraTotem = { Name = "Terra Totem", Thai = "เสาธรณี", Category = "Structure", Element = "Earth" },
	TideTotem = { Name = "Tide Totem", Thai = "เสาวารี", Category = "Structure", Element = "Water" },
	GaleTotem = { Name = "Gale Totem", Thai = "เสาวายุ", Category = "Structure", Element = "Air" },
	EmberTotem = { Name = "Ember Totem", Thai = "เสาอัคคี", Category = "Structure", Element = "Fire" },
	SunBeacon = { Name = "Sun Beacon", Thai = "ประภาคารสุริยะ", Category = "Structure" },
}

-- ค่าคราฟต์แบบ "อะไรก็ได้ในกลุ่ม" (ใช้ใน Cost เหมือนไอเทม เช่น AnyEssence = 2 -> แก่นธาตุธาตุไหนก็ได้รวม 2)
Items.AnyGroups = {
	AnyEssence = { "TerraCore", "TidePearl", "GaleFeather", "EmberShard" },
	AnyHeart = { "TerraHeart", "TideHeart", "FrostHeart", "EmberHeart" },
}
Items.AnyThai = { AnyEssence = "แก่นธาตุ (ธาตุไหนก็ได้)", AnyHeart = "หัวใจอสูร (ธาตุไหนก็ได้)" }
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
	Spear = { Damage = 28, Chop = 0.3, Mine = 0.2, Range = 13, Cooldown = 0.7, Kind = "Spear" },
	Torch = { Damage = 8, Chop = 0, Mine = 0, Range = 8, Cooldown = 0.5, Kind = "Torch", Light = 28, Burn = 4 },
	Bow = { Damage = 22, Chop = 0, Mine = 0, Range = 160, Cooldown = 0.9, Kind = "Bow", Projectile = "Arrow" },
	TerraHammer = { Damage = 46, Chop = 2, Mine = 4, Range = 11, Cooldown = 1.0, Kind = "Hammer", Aoe = 12, Element = "Earth" },
	TidalTrident = { Damage = 38, Chop = 0.5, Mine = 0.5, Range = 15, Cooldown = 0.6, Kind = "Spear", Slow = 0.5, Element = "Water" },
	GaleBow = { Damage = 34, Chop = 0, Mine = 0, Range = 220, Cooldown = 0.55, Kind = "Bow", Projectile = "GaleArrow", Pierce = 3, Element = "Air" },
	EmberBlade = { Damage = 52, Chop = 2.5, Mine = 1, Range = 12, Cooldown = 0.75, Kind = "Sword", Burn = 10, Light = 20, Element = "Fire" },
	FourfoldBlade = { Damage = 90, Chop = 4, Mine = 4, Range = 14, Cooldown = 0.6, Kind = "Sword", Aoe = 10, Burn = 12, Slow = 0.6, Light = 30, Element = "All" },
	-- คทา: ตีแล้วปล่อยลูกไฟพุ่งไปทางที่เล็ง (ระเบิดวงเล็ก + ติดไฟ) · ยืนชิดต้นไม้/หิน = ฟาดตัด/ทุบได้ (แทนขวาน)
	EmberStaff = { Damage = 20, Chop = 1, Mine = 0.5, Range = 9, Cooldown = 0.7, Kind = "Staff", Bolt = { Speed = 150, Range = 140, Blast = 7, Size = 1.6, FxScale = 0.08, ImpactScale = 0.22 }, Burn = 4, Light = 16, Element = "Fire" },
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

-- คำอธิบายสั้น (ภาษาไทย) ใช้ในกล่องรายละเอียดไอเทม (ItemTooltip)
Items.Desc = {
	Wood = "ไม้จากต้นไม้ ใช้สร้างของเกือบทุกอย่าง และโยนเข้ากองไฟได้",
	Stone = "ทุบจากก้อนหิน ใช้ทำเครื่องมือและกำแพง",
	Fiber = "เส้นใย ได้จากการล่าสัตว์ (กระต่าย จระเข้ ปู หมึก กระทิงหิมะ แกะเพลิง) / หีบ / กล่องเสบียง · ใช้ทำผ้าพันแผล ธนู และกระสอบ",
	Iron = "แร่เหล็กจากหินแร่ ใช้ทำอาวุธ/ของเลเวลสูง",
	Coal = "ถ่านหิน เชื้อเพลิงชั้นดี กองไฟติดนาน",
	Pelt = "หนังสัตว์ ใช้ทำกระสอบ/เตียง และแลกของกับพ่อค้าเร่",
	Bone = "กระดูกสัตว์ ใช้ทำหอกและกระสอบยักษ์",
	Berries = "เบอร์รี่สด กินแก้หิว · ทำน้ำเบอร์รี่/ยาสมุนไพร (โต๊ะ Lv.1) · ปลูกแปลง · พายและสตูว์ที่หม้อตุ๋น",
	BerryJuice = "น้ำเบอร์รี่คั้นสด แก้หิว และเติมสตามิน่าเต็มหลอด",
	BerryPie = "พายเบอร์รี่จากหม้อตุ๋น อิ่มมาก หิวช้าลงครึ่งหนึ่ง 2 นาที",
	RawMeat = "เนื้อดิบ กินได้แต่เสียเลือด — ย่างที่กองไฟก่อนดีกว่า",
	CookedMeat = "เนื้อย่างหอมกรุ่น แก้หิวได้มาก",
	Stew = "สตูว์ร้อนจากหม้อตุ๋น อิ่มนานและฟื้นเลือดเยอะ",
	TerraCore = "แก่นธาตุดิน · ทุบคริสตัลสีเขียวในป่าปฐพี / หีบ / อุกกาบาต / วิหาร / บอสดิน · ใช้ทำค้อนธรณี เสาธรณี อัปเกรดโต๊ะ-กองไฟ",
	TidePearl = "มุกธาตุน้ำ · ทุบคริสตัลสีฟ้าในทะเลสาบกระแสน้ำวน / หีบ / อุกกาบาต / วิหาร / บอสน้ำ · ใช้ทำตรีศูล เสาวารี อัปเกรดโต๊ะ-กองไฟ",
	GaleFeather = "ขนนกธาตุน้ำแข็ง · ทุบคริสตัลสีขาวบนที่ราบสูงเหนือเมฆ / หีบ / อุกกาบาต / วิหาร / บอสน้ำแข็ง · ใช้ทำธนูพายุ เสาวายุ อัปเกรดโต๊ะ-กองไฟ",
	EmberShard = "เศษธาตุไฟ · ทุบคริสตัลสีส้มในปล่องภูเขาไฟ / หีบ / อุกกาบาต / วิหาร / บอสไฟ · ใช้ทำดาบอัคคี เสาอัคคี ประภาคาร · เป็นเชื้อเพลิงแรง",
	TerraHeart = "หัวใจบอสดิน (โกลแกรน) · ใช้ทำค้อนธรณี และดาบสี่ธาตุ",
	TideHeart = "หัวใจบอสน้ำ (ไทรันโนโมซา) · ใช้ทำตรีศูลวารี และดาบสี่ธาตุ",
	FrostHeart = "หัวใจบอสน้ำแข็ง (ฟรอสต์มอว์) · ใช้ทำธนูพายุ และดาบสี่ธาตุ",
	EmberHeart = "หัวใจบอสไฟ (อิกนาแรกซ์) · ใช้ทำดาบอัคคี และดาบสี่ธาตุ",
	Bandage = "พันแผลฟื้นเลือด และใช้ช่วยเพื่อนที่ล้มลง",
	Medkit = "ฟื้นเลือดเต็มหลอด และใช้ช่วยเพื่อนที่ล้มลง",
	HerbSalve = "ยาสมุนไพรจากเบอร์รี่ ฟื้นเลือดเล็กน้อย (ช่วยเพื่อนที่ล้มไม่ได้)",
	OldAxe = "ขวานติดตัว ตัดไม้ได้ช้า ๆ",
	OldSack = "กระสอบใส่ของได้ 10 ชิ้น — ถือแล้วคลิกของเพื่อเก็บ",
	GoodSack = "กระสอบใส่ของได้ 20 ชิ้น",
	GiantSack = "กระสอบใส่ของได้ 30 ชิ้น",
	StoneAxe = "ขวานหิน ตัดไม้เร็วขึ้นเท่าตัว",
	IronAxe = "ขวานเหล็ก ตัดไม้เร็วที่สุดในบรรดาขวาน",
	Pickaxe = "อีเต้อ ทุบหิน/แร่ได้เร็ว",
	Spear = "หอกกระดูก แทงไกล ดาเมจสูง",
	Torch = "คบเพลิงให้แสงสว่าง ไล่กวางกลวง",
	Bow = "ธนูยิงไกล ใช้ล่าสัตว์จากระยะปลอดภัย",
	TerraHammer = "ค้อนธาตุดิน ทุบเป็นวงกว้าง",
	TidalTrident = "ตรีศูลธาตุน้ำ ทำให้สัตว์ช้าลง",
	GaleBow = "ธนูธาตุลม ลูกธนูทะลุหลายตัว",
	EmberBlade = "ดาบธาตุไฟ เผาศัตรูและให้แสง",
	FourfoldBlade = "ดาบสี่ธาตุ อาวุธสุดยอดของเกม",
	EmberStaff = "คทาเพลิงของจอมเวท ตีแล้วปล่อยลูกไฟระเบิดใส่ศัตรู · ฟาดต้นไม้/หินได้",
	LogWall = "กำแพงไม้ ขวางฝูงสัตว์",
	StoneWall = "กำแพงหิน ทนทานมาก",
	SpikeTrap = "กับดักหนาม แทงสัตว์ที่เหยียบ",
	Lantern = "ตะเกียง ส่องสว่างไล่กวางกลวง",
	Ballista = "หน้าไม้ยักษ์ ยิงสัตว์อัตโนมัติ",
	WoodArmor = "เสื้อเกราะไม้ สวมทันทีที่คราฟต์ เพิ่มเลือดสูงสุด",
	IronArmor = "เกราะเหล็กมีบ่า แข็งแรง เพิ่มเลือดสูงสุดมาก",
	GoldArmor = "เกราะทองลายสลักของนักรบ เพิ่มเลือดสูงสุดมากที่สุด",
	Bed = "วางแล้วนอนพัก ข้ามไป 1 วัน (นับวันรอด +1 · วางตอนกลางคืนนับให้ตอนเช้า) · ทั้งเซิร์ฟได้ 2 เตียงต่อเกม",
	FarmPlot = "ปลูกเบอร์รี่ เก็บได้เรื่อย ๆ",
	CookPot = "หม้อตุ๋น ทำสตูว์ (เนื้อ+เบอร์รี่) และพายเบอร์รี่ (เบอร์รี่+ไม้)",
	TerraTotem = "เสาธาตุดิน ซ่อมกำแพงรอบ ๆ",
	TideTotem = "เสาธาตุน้ำ สัตว์ในรัศมีเดินช้า",
	GaleTotem = "เสาธาตุลม ผลักสัตว์ออกไป",
	EmberTotem = "เสาธาตุไฟ เผาสัตว์รอบ ๆ",
	SunBeacon = "ประภาคารสุริยะ แสงสว่างมหาศาล",
}

-- ชื่อหมวดภาษาไทย
Items.CategoryThai = {
	Resource = "วัตถุดิบ", Food = "อาหาร", Essence = "พลังธาตุ", Medical = "ยา", Tool = "เครื่องมือ/อาวุธ", Structure = "สิ่งก่อสร้าง", Relic = "ของหายาก",
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
