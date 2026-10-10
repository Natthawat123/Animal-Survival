--[[
	Biomes — 4 ไบโอมธาตุ + ทุ่งกลาง (Heart)
	ตำแหน่งของ 4 ธาตุสุ่มใหม่ทุกเซิร์ฟเวอร์ (ดู MapLayout.lua)

	Terrain:SetMaterialColor เป็นสีทั้งโลก -> แต่ละไบโอมใช้วัสดุไม่ซ้ำกันเพื่อให้สีไม่ชนกัน
]]

local Biomes = {}

-- ลำดับ id (ใช้เป็น index ในตาราง/ข้อมูล map)
Biomes.Order = { "Heart", "Earth", "Water", "Air", "Fire" }
Biomes.Elements = { "Earth", "Water", "Air", "Fire" }

-- สี Terrain ของทั้งโลก
Biomes.MaterialColors = {
	Grass = Color3.fromRGB(80, 118, 50),
	LeafyGrass = Color3.fromRGB(54, 90, 40),
	Ground = Color3.fromRGB(92, 72, 52),
	Mud = Color3.fromRGB(66, 52, 40),
	Rock = Color3.fromRGB(98, 98, 102),
	Sand = Color3.fromRGB(204, 188, 144),
	Limestone = Color3.fromRGB(186, 210, 202),
	Salt = Color3.fromRGB(214, 224, 238), -- ชายหาดขาว + ทุนดราน้ำแข็งของธาตุลม
	Snow = Color3.fromRGB(228, 235, 246),
	Glacier = Color3.fromRGB(140, 200, 236),
	Slate = Color3.fromRGB(88, 98, 128),
	Basalt = Color3.fromRGB(34, 30, 32),
	CrackedLava = Color3.fromRGB(255, 104, 26),
	Asphalt = Color3.fromRGB(50, 46, 46),
	Sandstone = Color3.fromRGB(104, 62, 48),
	Pavement = Color3.fromRGB(160, 168, 190),
}

Biomes.Data = {
	-- ล็อบบี้บนฟ้า: แสงพระอาทิตย์ตกสีทองตลอดเวลา (ไม่ใช่ไบโอมในแมพ)
	-- ล็อบบี้: ลานจอดรถหน้าอุทยานยามค่ำคืน (โทนม่วง-น้ำเงินแบบ 99 Nights) ไม่ใช่ไบโอมในแมพ
	-- ล็อบบี้: ค่ายฟาร์มยามค่ำคืน โทนน้ำเงินสว่าง (แบบ 99 Nights) ไม่ใช่ไบโอมในแมพ
	Lobby = {
		Name = "Wildheart Camp",
		Thai = "ค่ายผู้รอดชีวิต",
		Color = Color3.fromRGB(150, 200, 255),
		Element = nil,
		Terrain = { Top = "Grass", Sub = "Ground", Cliff = "Rock", Shore = "Sand" },
		-- สนธยาฟ้าม่วงชมพู สว่างสดใส (โทนเดียวกับ UI ร้านค้า) — ไม่มืดทึบ
		Atmosphere = {
			Density = 0.2, Offset = 0.12, Haze = 0.8, Glare = 0.25,
			Color = Color3.fromRGB(200, 150, 220), Decay = Color3.fromRGB(110, 90, 190),
		},
		Grade = { Tint = Color3.fromRGB(255, 240, 250), Saturation = 0.28, Contrast = 0.1, Brightness = 0.06 },
		Lighting = {
			Ambient = Color3.fromRGB(150, 140, 190), Outdoor = Color3.fromRGB(190, 170, 220), Exposure = 0.55,
			LightBrightness = 3.0, BloomIntensity = 0.6, BloomSize = 26, BloomThreshold = 1.3,
			CloudColor = Color3.fromRGB(255, 190, 210), CloudCover = 0.42, SunRays = 0.05,
		},
		Ambient = "Fireflies",
		Props = {},
		Wild = {},
	},

	Heart = {
		Name = "Whispering Pines",
		Thai = "ป่าสนรอบแคมป์",
		Color = Color3.fromRGB(255, 196, 92),
		Element = nil,
		Terrain = { Top = "Grass", Sub = "Ground", Cliff = "Rock", Shore = "Sand" },
		Atmosphere = {
			Density = 0.36, Offset = 0.14, Haze = 2.2, Glare = 0.2,
			Color = Color3.fromRGB(184, 196, 190), Decay = Color3.fromRGB(92, 104, 98),
		},
		Grade = { Tint = Color3.fromRGB(244, 250, 244), Saturation = 0.06, Contrast = 0.12, Brightness = 0 },
		Ambient = "Pollen",
		PropDensity = 2.6, -- ความถี่ของต้นไม้/ของ (ป่าทึบ)
		Props = {
			{ Kind = "GiantPine", Weight = 7 },
			{ Kind = "Oak", Weight = 3 },
			{ Kind = "Bush", Weight = 3 },
			{ Kind = "Fern", Weight = 4 },
			{ Kind = "Mushrooms", Weight = 1 },
			{ Kind = "BerryBush", Weight = 2 },
			{ Kind = "Flowers", Weight = 1 },
			{ Kind = "Boulder", Weight = 1 },
		},
		Wild = { Rabbit = 4, Deer = 3 },
	},

	Earth = {
		Name = "Verdant Wilds",
		Thai = "ป่าดึกดำบรรพ์แห่งปฐพี",
		Color = Color3.fromRGB(120, 200, 90),
		Element = "Earth",
		Terrain = { Top = "LeafyGrass", Sub = "Mud", Cliff = "Rock", Shore = "Mud" },
		Atmosphere = {
			Density = 0.36, Offset = 0.12, Haze = 2.0, Glare = 0.15,
			Color = Color3.fromRGB(192, 204, 180), Decay = Color3.fromRGB(96, 110, 86),
		},
		Grade = { Tint = Color3.fromRGB(240, 255, 236), Saturation = 0.16, Contrast = 0.12, Brightness = -0.01 },
		Ambient = "Fireflies",
		PropDensity = 2.4, -- ความถี่ของต้นไม้/ของ (ป่าทึบ)
		Props = {
			{ Kind = "GiantPine", Weight = 6 },
			{ Kind = "AncientOak", Weight = 3 },
			{ Kind = "Fern", Weight = 5 },
			{ Kind = "Mushrooms", Weight = 2 },
			{ Kind = "Bush", Weight = 2 },
			{ Kind = "MossRock", Weight = 3 },
			{ Kind = "GlowShroom", Weight = 2 },
			{ Kind = "BerryBush", Weight = 1 },
			{ Kind = "IronRock", Weight = 1 },
			{ Kind = "TerraCrystal", Weight = 0.5 },
		},
		Wild = { MossWolf = 4, Thornboar = 3, StoneBear = 1, Deer = 2 },
		Boss = "Terragon",
		Spirit = "TerraPup",
	},

	Water = {
		Name = "Tidal Expanse",
		Thai = "ทะเลสาบกระแสน้ำวน",
		Color = Color3.fromRGB(70, 170, 255),
		Element = "Water",
		Terrain = { Top = "Sand", Sub = "Sand", Cliff = "Limestone", Shore = "Salt" },
		Atmosphere = {
			Density = 0.32, Offset = 0.3, Haze = 1.8, Glare = 0.7,
			Color = Color3.fromRGB(160, 214, 236), Decay = Color3.fromRGB(70, 140, 186),
		},
		Grade = { Tint = Color3.fromRGB(228, 244, 255), Saturation = 0.22, Contrast = 0.08, Brightness = 0.03 },
		Ambient = "Mist",
		PropDensity = 1.3, -- ความถี่ของต้นไม้/ของ (ป่าทึบ)
		Props = {
			{ Kind = "Palm", Weight = 4 },
			{ Kind = "Coral", Weight = 4 },
			{ Kind = "SeaRock", Weight = 3 },
			{ Kind = "Kelp", Weight = 3 },
			{ Kind = "TideCrystal", Weight = 0.6 },
			{ Kind = "BerryBush", Weight = 0.6 },
		},
		Wild = { ReefCrab = 3, RiptideCroc = 3, Rabbit = 1 },
		Boss = "Leviathan",
		Spirit = "TidePup",
	},

	Air = {
		Name = "Skyreach Highlands",
		Thai = "ที่ราบสูงเหนือเมฆ",
		Color = Color3.fromRGB(200, 225, 255),
		Element = "Air",
		Terrain = { Top = "Snow", Sub = "Slate", Cliff = "Slate", Shore = "Pavement", Peak = "Glacier" },
		Atmosphere = {
			Density = 0.24, Offset = 0.45, Haze = 0.7, Glare = 1.1,
			Color = Color3.fromRGB(222, 232, 255), Decay = Color3.fromRGB(160, 180, 236),
		},
		Grade = { Tint = Color3.fromRGB(240, 246, 255), Saturation = 0.05, Contrast = 0.1, Brightness = 0.05 },
		Ambient = "Wind",
		PropDensity = 1.4, -- ความถี่ของต้นไม้/ของ (ป่าทึบ)
		Props = {
			{ Kind = "FrostPine", Weight = 5 },
			{ Kind = "IceSpire", Weight = 2 },
			{ Kind = "SkyStone", Weight = 3 },
			{ Kind = "GaleCrystal", Weight = 0.6 },
			{ Kind = "IronRock", Weight = 1 },
		},
		Wild = { GaleHawk = 3, SkyLynx = 3, StormRam = 2 },
		Boss = "TempestRoc",
		Spirit = "GalePup",
	},

	Fire = {
		Name = "Ember Caldera",
		Thai = "ปล่องภูเขาไฟเพลิงกัลป์",
		Color = Color3.fromRGB(255, 96, 40),
		Element = "Fire",
		Terrain = { Top = "Asphalt", Sub = "Basalt", Cliff = "Sandstone", Shore = "Basalt", Lava = "CrackedLava" },
		Atmosphere = {
			Density = 0.38, Offset = 0.08, Haze = 2.3, Glare = 0.25,
			Color = Color3.fromRGB(150, 96, 84), Decay = Color3.fromRGB(84, 30, 18),
		},
		Grade = { Tint = Color3.fromRGB(255, 222, 200), Saturation = 0.1, Contrast = 0.16, Brightness = -0.02 },
		Ambient = "Embers",
		PropDensity = 1.3, -- ความถี่ของต้นไม้/ของ (ป่าทึบ)
		Props = {
			{ Kind = "CharredTree", Weight = 4 },
			{ Kind = "ObsidianSpire", Weight = 3 },
			{ Kind = "LavaVent", Weight = 2 },
			{ Kind = "CoalRock", Weight = 2 },
			{ Kind = "EmberCrystal", Weight = 0.6 },
		},
		Wild = { EmberFox = 4, MagmaRhino = 2, LavaSalamander = 3 },
		Boss = "Solfang",
		Spirit = "EmberPup",
	},
}

-- บรรยากาศตอนกลางคืน (ผสมทับสีของไบโอม)
Biomes.Night = {
	Normal = {
		Color = Color3.fromRGB(58, 72, 112), Decay = Color3.fromRGB(22, 26, 48), DensityAdd = 0.08,
		Tint = Color3.fromRGB(186, 204, 255), Saturation = -0.1, Contrast = 0.14,
	},
	BloodMoon = {
		Color = Color3.fromRGB(130, 30, 30), Decay = Color3.fromRGB(50, 8, 10), DensityAdd = 0.12,
		Tint = Color3.fromRGB(255, 160, 150), Saturation = -0.05, Contrast = 0.2,
	},
}

function Biomes.Get(id)
	return Biomes.Data[id]
end

return Biomes
