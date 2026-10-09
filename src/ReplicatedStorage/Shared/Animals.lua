--[[
	Animals — สัตว์ทุกตัว: ค่าพลัง + พฤติกรรม + ดรอป + สเปกรูปร่าง (AnimalModels.lua ปั้นจากสเปกนี้)

	Behaviour:
		Passive  = กินหญ้า เดินเล่น โดนตีแล้ววิ่งหนี
		Hunter   = เห็นผู้เล่นแล้วไล่กัด
		Charger  = ถอยตั้งหลักแล้วพุ่งชน (กระเด็น)
		Brute    = ช้าแต่ถึก ตีกำแพงแรง
		Flyer    = บินวนแล้วโฉบลงมา
		Spitter  = ยิงลูกไฟ/น้ำจากระยะไกล
		Boss     = บอสธาตุ มีท่าพิเศษ
		Stalker  = ปีศาจกวางกลางคืน ฆ่าไม่ตาย กลัวแสง
		Spirit   = ลูกสัตว์ธาตุ (ต้องช่วยพากลับกองไฟ)

	ตัวเลขเป็นค่าคืนที่ 1 — ฝูงบุกจะแรงขึ้นตามคืน (Nights.lua)
]]

local Animals = {}

local C = Color3.fromRGB
local V = Vector3.new

Animals.Data = {
	------------------------------------------------------------ สัตว์ทั่วไป
	Rabbit = {
		Name = "Meadow Hare", Thai = "กระต่ายทุ่ง", Element = nil, Behaviour = "Passive",
		Health = 15, Damage = 0, Speed = 22, Aggro = 30,
		Drops = { { Item = "RawMeat", Min = 1, Max = 1 }, { Item = "Fiber", Min = 0, Max = 2 } },
		Model = {
			Template = "Rabbit", Body = V(1.6, 1.4, 2.0), Head = V(1.2, 1.1, 1.2), LegLen = 0.7, LegThick = 0.45,
			Colors = { Main = C(196, 178, 156), Belly = C(244, 236, 224), Dark = C(120, 100, 84), Eye = C(25, 20, 20) },
			Ears = "Long", Tail = "Puff",
		},
	},
	Deer = {
		Name = "Dawn Deer", Thai = "กวางรุ่งอรุณ", Element = nil, Behaviour = "Passive",
		Health = 45, Damage = 0, Speed = 26, Aggro = 50,
		Drops = { { Item = "RawMeat", Min = 2, Max = 3 }, { Item = "Pelt", Min = 1, Max = 1 }, { Item = "Bone", Min = 1, Max = 2 } },
		Model = {
			Template = "Quadruped", Body = V(2.2, 2.2, 4.4), Head = V(1.3, 1.4, 1.6), Snout = V(0.8, 0.7, 1.0), LegLen = 3.2, LegThick = 0.5,
			Neck = 1.6, Colors = { Main = C(160, 104, 62), Belly = C(236, 216, 186), Dark = C(90, 60, 40), Eye = C(25, 18, 14), Horn = C(214, 196, 160) },
			Ears = "Pointy", Tail = "Short", Extras = { "Antlers", "Spots" },
		},
	},

	------------------------------------------------------------ ธาตุดิน
	MossWolf = {
		Name = "Mossback Wolf", Thai = "หมาป่าหลังตะไคร่", Element = "Earth", Behaviour = "Hunter",
		Health = 70, Damage = 10, Speed = 25, AttackRange = 6, AttackCooldown = 1.1, Aggro = 80, StructureDamage = 1,
		RaidCost = 2, MinNight = 1, Pack = { 2, 4 },
		Drops = { { Item = "RawMeat", Min = 1, Max = 2 }, { Item = "Pelt", Min = 1, Max = 1 }, { Item = "Bone", Min = 1, Max = 1 }, { Item = "TerraCore", Chance = 0.08 } },
		Model = {
			Template = "Quadruped", Body = V(2.4, 2.4, 5.2), Head = V(1.7, 1.6, 1.8), Snout = V(1.0, 0.8, 1.4), LegLen = 2.6, LegThick = 0.7,
			Neck = 1.0, Colors = { Main = C(70, 80, 66), Belly = C(132, 140, 112), Dark = C(38, 44, 36), Eye = C(170, 255, 110), Glow = C(120, 220, 80), Moss = C(84, 150, 56) },
			Ears = "Pointy", Tail = "Bushy", Extras = { "Moss", "Ruff" },
		},
	},
	Thornboar = {
		Name = "Thornback Boar", Thai = "หมูป่าหนามพฤกษ์", Element = "Earth", Behaviour = "Charger",
		Health = 110, Damage = 16, Speed = 22, AttackRange = 6, AttackCooldown = 2.2, Aggro = 60, StructureDamage = 2,
		RaidCost = 3, MinNight = 3,
		Drops = { { Item = "RawMeat", Min = 2, Max = 3 }, { Item = "Pelt", Min = 1, Max = 2 }, { Item = "Fiber", Min = 1, Max = 3 }, { Item = "TerraCore", Chance = 0.12 } },
		Model = {
			Template = "Quadruped", Body = V(3.0, 2.8, 4.8), Head = V(2.0, 1.9, 2.0), Snout = V(1.2, 1.0, 1.0), LegLen = 1.6, LegThick = 0.8,
			Neck = 0.3, Colors = { Main = C(92, 62, 48), Belly = C(124, 92, 70), Dark = C(54, 36, 28), Eye = C(255, 140, 60), Horn = C(238, 228, 204), Glow = C(130, 220, 70), Spike = C(66, 104, 44) },
			Ears = "Round", Tail = "Thin", Extras = { "Tusks", "BackThorns" },
		},
	},
	StoneBear = {
		Name = "Granite Bear", Thai = "หมีศิลาหยก", Element = "Earth", Behaviour = "Brute",
		Health = 260, Damage = 26, Speed = 19, AttackRange = 8, AttackCooldown = 1.8, Aggro = 70, StructureDamage = 4,
		RaidCost = 7, MinNight = 8,
		Drops = { { Item = "RawMeat", Min = 3, Max = 5 }, { Item = "Pelt", Min = 2, Max = 3 }, { Item = "Stone", Min = 3, Max = 6 }, { Item = "TerraCore", Min = 1, Max = 2 } },
		Model = {
			Template = "Quadruped", Body = V(4.6, 4.4, 7.6), Head = V(2.8, 2.6, 2.6), Snout = V(1.4, 1.2, 1.2), LegLen = 3.0, LegThick = 1.5,
			Neck = 0.6, Colors = { Main = C(98, 94, 92), Belly = C(70, 66, 64), Dark = C(48, 46, 46), Eye = C(150, 255, 110), Glow = C(110, 230, 90), Crystal = C(120, 230, 110) },
			Ears = "Round", Tail = "Stub", Extras = { "Crystals", "Hump" }, Material = "Slate",
		},
	},

	------------------------------------------------------------ ธาตุน้ำ
	ReefCrab = {
		Name = "Coralshell Crab", Thai = "ปูกระดองปะการัง", Element = "Water", Behaviour = "Brute",
		Health = 150, Damage = 14, Speed = 15, AttackRange = 7, AttackCooldown = 1.5, Aggro = 50, StructureDamage = 3, Armor = 0.3,
		RaidCost = 4, MinNight = 4,
		Drops = { { Item = "RawMeat", Min = 2, Max = 3 }, { Item = "Stone", Min = 1, Max = 3 }, { Item = "TidePearl", Chance = 0.25 } },
		Model = {
			Template = "Crab", Body = V(5.0, 2.2, 3.8), LegLen = 2.6, LegThick = 0.45,
			Colors = { Main = C(214, 82, 64), Belly = C(244, 190, 150), Dark = C(130, 40, 36), Eye = C(20, 20, 24), Glow = C(80, 230, 255), Coral = C(255, 120, 170) },
			Extras = { "Coral", "Barnacles" },
		},
	},
	RiptideCroc = {
		Name = "Riptide Crocodile", Thai = "จระเข้คลื่นคลั่ง", Element = "Water", Behaviour = "Hunter",
		Health = 140, Damage = 20, Speed = 20, AttackRange = 8, AttackCooldown = 1.6, Aggro = 70, StructureDamage = 2,
		RaidCost = 5, MinNight = 6,
		Drops = { { Item = "RawMeat", Min = 2, Max = 4 }, { Item = "Pelt", Min = 1, Max = 2 }, { Item = "TidePearl", Min = 0, Max = 1 } },
		Model = {
			Template = "Reptile", Body = V(3.0, 1.8, 7.0), Head = V(2.0, 1.2, 1.8), Snout = V(1.4, 0.8, 3.2), LegLen = 1.2, LegThick = 0.7,
			TailLen = 7, Colors = { Main = C(36, 86, 88), Belly = C(176, 200, 168), Dark = C(22, 52, 60), Eye = C(255, 220, 60), Glow = C(80, 220, 255) },
			Extras = { "BackPlates", "GlowStripes" },
		},
	},

	------------------------------------------------------------ ธาตุลม
	GaleHawk = {
		Name = "Gale Hawk", Thai = "เหยี่ยววายุ", Element = "Air", Behaviour = "Flyer",
		Health = 45, Damage = 9, Speed = 46, AttackRange = 7, AttackCooldown = 2.0, Aggro = 120, StructureDamage = 0.5,
		RaidCost = 2, MinNight = 2, Pack = { 2, 3 },
		Drops = { { Item = "RawMeat", Min = 1, Max = 1 }, { Item = "GaleFeather", Min = 1, Max = 2 } },
		Model = {
			Template = "Bird", Body = V(1.8, 1.8, 3.2), Head = V(1.2, 1.2, 1.3), Wing = V(5.5, 0.3, 2.4),
			Colors = { Main = C(226, 232, 244), Belly = C(250, 250, 255), Dark = C(72, 102, 160), Eye = C(130, 225, 255), Beak = C(250, 196, 70), Glow = C(150, 220, 255) },
		},
	},
	SkyLynx = {
		Name = "Cirrus Lynx", Thai = "แมวป่าเมฆา", Element = "Air", Behaviour = "Hunter",
		Health = 85, Damage = 14, Speed = 30, AttackRange = 7, AttackCooldown = 1.0, Aggro = 90, StructureDamage = 1,
		RaidCost = 3, MinNight = 5, Leap = true,
		Drops = { { Item = "RawMeat", Min = 1, Max = 2 }, { Item = "Pelt", Min = 1, Max = 2 }, { Item = "GaleFeather", Chance = 0.3 } },
		Model = {
			Template = "Quadruped", Body = V(2.2, 2.2, 5.0), Head = V(1.7, 1.6, 1.6), Snout = V(0.9, 0.7, 0.6), LegLen = 2.8, LegThick = 0.65,
			Neck = 0.8, Colors = { Main = C(212, 218, 234), Belly = C(250, 250, 255), Dark = C(110, 122, 168), Eye = C(150, 235, 255), Glow = C(170, 230, 255) },
			Ears = "Tufted", Tail = "Long", Extras = { "Spots", "WindRibbons" },
		},
	},
	StormRam = {
		Name = "Thunderwool Ram", Thai = "แกะขนเมฆอัสนี", Element = "Air", Behaviour = "Charger",
		Health = 130, Damage = 18, Speed = 23, AttackRange = 6, AttackCooldown = 2.4, Aggro = 60, StructureDamage = 3, Knockback = 90,
		RaidCost = 4, MinNight = 7,
		Drops = { { Item = "RawMeat", Min = 2, Max = 3 }, { Item = "Fiber", Min = 3, Max = 6 }, { Item = "GaleFeather", Min = 0, Max = 2 } },
		Model = {
			Template = "Quadruped", Body = V(3.2, 3.0, 4.6), Head = V(1.6, 1.8, 1.8), Snout = V(1.0, 1.0, 0.8), LegLen = 2.2, LegThick = 0.6,
			Neck = 0.6, Colors = { Main = C(236, 240, 250), Belly = C(210, 216, 232), Dark = C(54, 60, 80), Eye = C(140, 220, 255), Horn = C(214, 190, 130), Glow = C(160, 220, 255) },
			Ears = "Floppy", Tail = "Puff", Extras = { "Wool", "CurledHorns", "Sparks" },
		},
	},

	------------------------------------------------------------ ธาตุไฟ
	EmberFox = {
		Name = "Ember Fox", Thai = "จิ้งจอกถ่านเพลิง", Element = "Fire", Behaviour = "Hunter",
		Health = 55, Damage = 9, Speed = 31, AttackRange = 6, AttackCooldown = 0.9, Aggro = 90, StructureDamage = 1, Burn = 3,
		RaidCost = 2, MinNight = 3, Pack = { 2, 5 },
		Drops = { { Item = "RawMeat", Min = 1, Max = 1 }, { Item = "Pelt", Min = 1, Max = 1 }, { Item = "EmberShard", Chance = 0.2 }, { Item = "Coal", Min = 0, Max = 1 } },
		Model = {
			Template = "Quadruped", Body = V(1.8, 1.8, 4.0), Head = V(1.5, 1.3, 1.5), Snout = V(0.8, 0.6, 1.2), LegLen = 2.0, LegThick = 0.45,
			Neck = 0.8, Colors = { Main = C(236, 92, 30), Belly = C(255, 226, 180), Dark = C(60, 30, 24), Eye = C(255, 236, 90), Glow = C(255, 150, 40) },
			Ears = "Big", Tail = "FlameBushy", Extras = { "FlameTips" },
		},
	},
	MagmaRhino = {
		Name = "Magma Rhino", Thai = "แรดลาวาหลอมเหลว", Element = "Fire", Behaviour = "Charger",
		Health = 320, Damage = 30, Speed = 20, AttackRange = 8, AttackCooldown = 2.6, Aggro = 60, StructureDamage = 6, Knockback = 120,
		RaidCost = 9, MinNight = 12,
		Drops = { { Item = "RawMeat", Min = 4, Max = 6 }, { Item = "Pelt", Min = 2, Max = 3 }, { Item = "Coal", Min = 2, Max = 5 }, { Item = "EmberShard", Min = 1, Max = 2 } },
		Model = {
			Template = "Quadruped", Body = V(5.0, 4.4, 8.4), Head = V(2.6, 2.4, 3.0), Snout = V(1.8, 1.4, 1.4), LegLen = 2.6, LegThick = 1.6,
			Neck = 0.3, Colors = { Main = C(52, 42, 42), Belly = C(84, 60, 52), Dark = C(26, 20, 20), Eye = C(255, 210, 80), Horn = C(28, 24, 30), Glow = C(255, 104, 20) },
			Ears = "Round", Tail = "Thin", Extras = { "NoseHorn", "LavaCracks", "BackSpikes" }, Material = "Basalt",
		},
	},
	LavaSalamander = {
		Name = "Lava Salamander", Thai = "ซาลาแมนเดอร์ลาวา", Element = "Fire", Behaviour = "Spitter",
		Health = 80, Damage = 12, Speed = 17, AttackRange = 70, AttackCooldown = 2.4, Aggro = 90, StructureDamage = 2, Burn = 5,
		RaidCost = 3, MinNight = 5,
		Drops = { { Item = "RawMeat", Min = 1, Max = 2 }, { Item = "EmberShard", Chance = 0.35 }, { Item = "Coal", Min = 1, Max = 2 } },
		Model = {
			Template = "Reptile", Body = V(2.2, 1.4, 4.6), Head = V(1.7, 1.0, 1.6), Snout = V(1.2, 0.6, 1.0), LegLen = 1.0, LegThick = 0.55,
			TailLen = 4.5, Colors = { Main = C(38, 28, 30), Belly = C(255, 140, 40), Dark = C(18, 12, 14), Eye = C(255, 240, 120), Glow = C(255, 110, 20) },
			Extras = { "GlowSpots", "Frills" },
		},
	},

	------------------------------------------------------------ บอสธาตุ
	Terragon = {
		Name = "GOLGRAN, the Living Mountain", Thai = "โกลแกรน โกเลมขุนเขา", Element = "Earth", Behaviour = "Boss",
		Health = 4200, Damage = 42, Speed = 12, AttackRange = 26, AttackCooldown = 3.0, Aggro = 160, StructureDamage = 10, Armor = 0.2,
		BossNight = 25, Scale = 1,
		Abilities = { "Quake", "Fissure", "BoulderRain" },
		Drops = { { Item = "BeastHeart", Min = 1, Max = 1 }, { Item = "TerraCore", Min = 8, Max = 12 }, { Item = "Stone", Min = 20, Max = 30 } },
		Model = {
			Template = "Tortoise", Body = V(22, 12, 26), Head = V(6, 5, 7), LegLen = 6, LegThick = 5,
			Skin = { Scale = 32, Rig = "Biped" }, -- โมเดลโกเลม (assets/rbxm/Animals/Terragon.rbxmx)
			Colors = { Main = C(108, 98, 78), Belly = C(160, 146, 110), Dark = C(60, 56, 48), Eye = C(170, 255, 120), Glow = C(120, 240, 90), Shell = C(90, 96, 84), Moss = C(76, 140, 52), Crystal = C(130, 240, 110) },
			Extras = { "ShellForest", "Crystals" },
		},
	},
	Leviathan = {
		Name = "TYRANNOMOSA, Terror of the Deep", Thai = "ไทรันโนโมซา โมซาซอรัสแห่งห้วงลึก", Element = "Water", Behaviour = "Boss",
		Health = 4600, Damage = 38, Speed = 18, AttackRange = 30, AttackCooldown = 2.6, Aggro = 180, StructureDamage = 8,
		BossNight = 50,
		Abilities = { "TidalWave", "WaterSpout", "Quake" },
		Drops = { { Item = "BeastHeart", Min = 1, Max = 1 }, { Item = "TidePearl", Min = 8, Max = 12 } },
		Model = {
			Template = "Reptile", Body = V(10, 7, 26), Head = V(7, 4.6, 6), Snout = V(5, 3, 9), LegLen = 4, LegThick = 2.6,
			Skin = { Scale = 13, Rig = "Mosasaur" }, -- โมเดลโมซาซอรัส
			TailLen = 34, Colors = { Main = C(22, 52, 96), Belly = C(120, 190, 210), Dark = C(10, 24, 50), Eye = C(120, 255, 255), Glow = C(70, 230, 255) },
			Extras = { "BackPlates", "GlowStripes", "Fins", "Frills" },
		},
	},
	TempestRoc = {
		Name = "FROSTMAW, the Glacier Yeti", Thai = "ฟรอสต์มอว์ เยติธารน้ำแข็ง", Element = "Air", Behaviour = "Boss",
		Health = 4000, Damage = 40, Speed = 20, AttackRange = 22, AttackCooldown = 2.4, Aggro = 220, StructureDamage = 8,
		BossNight = 75,
		Abilities = { "Blizzard", "IceSpikes", "Quake" },
		Drops = { { Item = "BeastHeart", Min = 1, Max = 1 }, { Item = "GaleFeather", Min = 10, Max = 14 } },
		Model = {
			Template = "Bird", Body = V(9, 9, 16), Head = V(5.4, 5, 5.6), Wing = V(30, 1.2, 12),
			Skin = { Scale = 30, Rig = "Biped" }, -- โมเดลเยติ
			Colors = { Main = C(70, 84, 120), Belly = C(214, 222, 240), Dark = C(30, 34, 54), Eye = C(200, 245, 255), Beak = C(230, 200, 110), Glow = C(150, 210, 255) },
			Extras = { "Crest", "Sparks" },
		},
	},
	Solfang = {
		Name = "IGNARAX, the Molten Dragon", Thai = "อิกนาแรกซ์ มังกรเพลิงลาวา", Element = "Fire", Behaviour = "Boss",
		Health = 5200, Damage = 52, Speed = 34, AttackRange = 26, AttackCooldown = 2.2, Aggro = 200, StructureDamage = 10, Burn = 8, Flying = true,
		BossNight = 99,
		Abilities = { "FireBreath", "FlameNova", "MeteorRoar" },
		Drops = { { Item = "BeastHeart", Min = 2, Max = 2 }, { Item = "EmberShard", Min = 10, Max = 14 } },
		Model = {
			Template = "Quadruped", Body = V(9, 8.5, 17), Head = V(6, 5.6, 5.6), Snout = V(3.2, 2.4, 2.4), LegLen = 7.5, LegThick = 2.6,
			Skin = { Scale = 18, Rig = "Dragon" }, -- โมเดลมังกรไฟ
			Neck = 2.2, Colors = { Main = C(120, 44, 24), Belly = C(176, 82, 40), Dark = C(40, 14, 10), Eye = C(255, 255, 210), Glow = C(255, 120, 20), Horn = C(30, 22, 24) },
			Ears = "Round", Tail = "FlameTuft", Extras = { "FlameMane", "LavaCracks" },
		},
	},

	------------------------------------------------------------ ปีศาจกลางคืน
	HollowStag = {
		Name = "THE HOLLOW STAG", Thai = "กวางกลวงแห่งราตรี", Element = nil, Behaviour = "Stalker",
		Health = math.huge, Damage = 55, Speed = 27, AttackRange = 9, AttackCooldown = 2.5, Aggro = 260,
		Model = {
			Template = "Quadruped", Body = V(2.6, 3.2, 6.0), Head = V(1.6, 2.2, 1.6), Snout = V(1.0, 0.9, 1.6), LegLen = 6.4, LegThick = 0.5,
			Neck = 3.2, Colors = { Main = C(18, 16, 20), Belly = C(30, 26, 32), Dark = C(8, 8, 10), Eye = C(255, 250, 240), Horn = C(226, 220, 204), Glow = C(255, 250, 235), Skull = C(232, 226, 212) },
			Ears = "None", Tail = "Short", Extras = { "GiantAntlers", "SkullFace", "Ribs" },
		},
	},

	------------------------------------------------------------ ลูกสัตว์ธาตุ (ภารกิจช่วยเหลือ)
	TerraPup = {
		Name = "Terra Pup", Thai = "ลูกจิ้งจอกปฐพี", Element = "Earth", Behaviour = "Spirit", Health = math.huge, Speed = 26,
		Model = {
			Template = "Quadruped", Body = V(1.4, 1.4, 2.2), Head = V(1.5, 1.4, 1.4), Snout = V(0.6, 0.5, 0.6), LegLen = 1.0, LegThick = 0.4, Neck = 0.3,
			Colors = { Main = C(140, 210, 100), Belly = C(230, 250, 210), Dark = C(60, 110, 50), Eye = C(255, 255, 255), Glow = C(150, 255, 110) },
			Ears = "Big", Tail = "Bushy", Extras = { "SpiritGlow", "Sprout" },
		},
	},
	TidePup = {
		Name = "Tide Pup", Thai = "ลูกจิ้งจอกวารี", Element = "Water", Behaviour = "Spirit", Health = math.huge, Speed = 26,
		Model = {
			Template = "Quadruped", Body = V(1.4, 1.4, 2.2), Head = V(1.5, 1.4, 1.4), Snout = V(0.6, 0.5, 0.6), LegLen = 1.0, LegThick = 0.4, Neck = 0.3,
			Colors = { Main = C(90, 180, 255), Belly = C(220, 244, 255), Dark = C(40, 90, 160), Eye = C(255, 255, 255), Glow = C(110, 230, 255) },
			Ears = "Big", Tail = "Bushy", Extras = { "SpiritGlow", "Fins" },
		},
	},
	GalePup = {
		Name = "Gale Pup", Thai = "ลูกจิ้งจอกวายุ", Element = "Air", Behaviour = "Spirit", Health = math.huge, Speed = 26,
		Model = {
			Template = "Quadruped", Body = V(1.4, 1.4, 2.2), Head = V(1.5, 1.4, 1.4), Snout = V(0.6, 0.5, 0.6), LegLen = 1.0, LegThick = 0.4, Neck = 0.3,
			Colors = { Main = C(236, 242, 255), Belly = C(255, 255, 255), Dark = C(140, 160, 210), Eye = C(90, 140, 255), Glow = C(200, 230, 255) },
			Ears = "Big", Tail = "Bushy", Extras = { "SpiritGlow", "WindRibbons" },
		},
	},
	EmberPup = {
		Name = "Ember Pup", Thai = "ลูกจิ้งจอกอัคคี", Element = "Fire", Behaviour = "Spirit", Health = math.huge, Speed = 26,
		Model = {
			Template = "Quadruped", Body = V(1.4, 1.4, 2.2), Head = V(1.5, 1.4, 1.4), Snout = V(0.6, 0.5, 0.6), LegLen = 1.0, LegThick = 0.4, Neck = 0.3,
			Colors = { Main = C(255, 120, 50), Belly = C(255, 230, 190), Dark = C(150, 50, 20), Eye = C(255, 255, 255), Glow = C(255, 170, 60) },
			Ears = "Big", Tail = "FlameBushy", Extras = { "SpiritGlow", "FlameTips" },
		},
	},
}

-- สัตว์ที่ใช้บุกฐานแยกตามธาตุ
Animals.RaidPool = {
	Earth = { "MossWolf", "Thornboar", "StoneBear" },
	Water = { "ReefCrab", "RiptideCroc" },
	Air = { "GaleHawk", "SkyLynx", "StormRam" },
	Fire = { "EmberFox", "LavaSalamander", "MagmaRhino" },
}

Animals.Bosses = { "Terragon", "Leviathan", "TempestRoc", "Solfang" }
Animals.Spirits = { Earth = "TerraPup", Water = "TidePup", Air = "GalePup", Fire = "EmberPup" }

function Animals.Get(id)
	return Animals.Data[id]
end

return Animals
