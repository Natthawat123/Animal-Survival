--[[
	Creatures — โมเดลสัตว์คุณภาพสูงจาก Roblox Creator Store (ของฟรี) ที่ใช้แทนรูปร่างเดิมบนเครื่องผู้เล่น
	โมเดลอยู่ที่ ReplicatedStorage.Assets.Creatures/<Model> (tools/fetch_models.py -> tools/store_to_rbxmx.py)

	Visual[animalId] = {
		Model   = ชื่อโมเดลใน Assets.Creatures
		Head    = ชื่อชิ้น/กระดูกที่เป็นหัว (หาทิศหน้า) · Yaw = หมุนเพิ่ม (เรเดียน) ถ้ายังหันผิด
		Fit     = ความยาวโมเดล / ความยาว rig   · Lift = ยกขึ้น (สัดส่วนความสูง rig)
		Mode    = "Quad" | "Flyer" | "Swim" | "Serpent"
		Spine/Tail/Neck/Jaw/WingL/WingR/LegFL/LegFR/LegBL/LegBR = ชื่อข้อต่อ (Motor6D ตามชื่อชิ้นที่ขยับ / Bone ตามชื่อกระดูก)
		Segments = { 0.2, 0.4, ... } -> โมเดลนิ่ง: ตัดปล้องตามแนวหัว-หาง ให้ลำตัวสะบัดได้
		Recolor(part) -> Color3|nil · Effects(model, primary, head)
	}
]]

local Creatures = {}

local C = Color3.fromRGB

-- ตัวช่วยแต่งสี: ปรับทุกชิ้นให้เข้าใกล้โทนธาตุ (คงลายผิวเดิม)
local function tint(color, k)
	return function(p)
		return p.Color:Lerp(color, k or 0.6)
	end
end

local function glowEyes(color)
	return function(model, _, head)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Name:lower():find("eye") then
				d.Material = Enum.Material.Neon
				d.Color = color
			end
		end
		if head and head:IsA("BasePart") then
			local l = Instance.new("PointLight")
			l.Color = color
			l.Range = 10
			l.Brightness = 1.5
			l.Parent = head
		end
	end
end

local function fireAura(color, size)
	return function(model, primary)
		local f = Instance.new("Fire")
		f.Size = size or 6
		f.Heat = (size or 6) * 1.5
		f.Color = color
		f.SecondaryColor = C(255, 220, 120)
		f.Parent = primary
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = (size or 6) * 4
		l.Brightness = 2
		l.Parent = primary
	end
end

-- ลูกสัตว์วิญญาณ: ตัวใสเรืองแสงสีธาตุ
local function spirit(color)
	return function(p)
		p.Transparency = math.max(p.Transparency, 0.25)
		return color
	end
end

local function spiritGlow(color)
	return function(model, primary)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = 14
		l.Brightness = 2.5
		l.Parent = primary
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = 12
		e.Lifetime = NumberRange.new(0.6, 1.2)
		e.Speed = NumberRange.new(0.5, 2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.4, 0)
		e.Color = ColorSequence.new(color)
		e.Parent = primary
	end
end

local QUAD_FOX = {
	Head = "HeadBeginning", Neck = { "Neck" }, Jaw = { "Jaw" }, Tail = { "TailStart", "Tail1", "Tail2", "Tail3" },
	LegFL = { "LeftShoulder", "LeftLowerLeg" }, LegFR = { "RightShoulder", "RightLowerLeg" },
	LegBL = { "LeftUpperThigh", "LeftHindLeg" }, LegBR = { "RightUpperThigh", "RightHindLeg" },
}

local function fox(extra)
	local t = { Model = "RedFox", Mode = "Quad", Fit = 1.1, LegAmp = 0.6 }
	for k, v in pairs(QUAD_FOX) do
		t[k] = v
	end
	for k, v in pairs(extra or {}) do
		t[k] = v
	end
	return t
end

local CROC = {
	Model = "Crocodile", Mode = "Quad", Head = "crocodile_v01:Head_M", Fit = 1.05, LegAmp = 0.45,
	Neck = { "crocodile_v01:Neck_M" }, Jaw = { "crocodile_v01:Jaw_M" },
	Spine = { "crocodile_v01:Spine1_M", "crocodile_v01:Chest_M" },
	Tail = { "crocodile_v01:Tail0_M", "crocodile_v01:Tail1_M", "crocodile_v01:Tail2_M", "crocodile_v01:Tail3_M", "crocodile_v01:Tail4_M" },
	LegFL = { "crocodile_v01:frontHip_L" }, LegFR = { "crocodile_v01:frontHip_R" },
	LegBL = { "crocodile_v01:backHip_L" }, LegBR = { "crocodile_v01:backHip_R" },
}

local function clone(t, extra)
	local o = {}
	for k, v in pairs(t) do
		o[k] = v
	end
	for k, v in pairs(extra or {}) do
		o[k] = v
	end
	return o
end

local DEER = {
	Model = "Deer", Mode = "Quad", Head = "Fakehead", Fit = 1.0, LegAmp = 0.5,
	Neck = { "Neck1" }, Jaw = { "Jaw" }, Tail = { "Tail" },
	LegFL = { "LShoulder", "LLowerforearm" }, LegFR = { "RShoulder", "RLowerforearm" },
	LegBL = { "LThigh", "LCalf" }, LegBR = { "RThigh", "RCalf" },
}

Creatures.Visual = {
	---------------------------------------------------------------- สัตว์ทั่วไป
	Rabbit = { Model = "Hare", Mode = "Quad", Front = "-Z", Fit = 1.25, LegAmp = 0.4 },
	Deer = DEER,
	MossWolf = { Model = "Wolf", Mode = "Quad", Front = "X", Fit = 1.05 },
	Thornboar = { Model = "Boar", Mode = "Quad", Front = "-X", Fit = 0.42 },
	StoneBear = { Model = "Grizzly", Mode = "Quad", Front = "X", Fit = 1.05 },
	ReefCrab = {
		Model = "Crab", Mode = "Quad", Head = "Arm.R", Fit = 1.0, Yaw = math.pi / 2, LegAmp = 0.3,
		LegFL = { "Leg.L", "Leg.L.003" }, LegFR = { "Leg.R", "Leg.R.003" }, LegBL = { "Leg.L.006" }, LegBR = { "Leg.R.006" },
		Jaw = { "Arm.R", "Arm.L" }, JawOpen = 0.8,
	},
	RiptideCroc = CROC,
	GaleHawk = {
		Model = "Hawk", Mode = "Flyer", Head = "Head", Fit = 0.75,
		Neck = { "Neck" }, Tail = { "Tail" }, WingL = { "LeftArm1_LoResUpperArm" }, WingR = { "RightArm1_LoResUpperArm" },
		LegBL = { "LeftLeg1_LoResUpperLeg" }, LegBR = { "RightLeg1_LoResUpperLeg" },
		Recolor = tint(C(210, 222, 245), 0.25),
	},
	SkyLynx = { Model = "Lynx", Mode = "Quad", Front = "-X", Fit = 1.05 },
	StormRam = {
		Model = "Goat", Mode = "Quad", Head = "Head", Fit = 1.1, Neck = { "Head" },
		Recolor = tint(C(170, 180, 210), 0.3), Effects = glowEyes(C(140, 220, 255)),
	},
	EmberFox = fox({ Effects = fireAura(C(255, 120, 40), 2.5) }),
	MagmaRhino = {
		Model = "Rhino", Mode = "Quad", Head = "head", Fit = 1.0, LegAmp = 0.4, Neck = { "head" }, Strip = true, Material = Enum.Material.Basalt,
		LegFL = { "L Front Leg  Top" }, LegFR = { "R Front Leg  Top" }, LegBL = { "L Back Leg Top" }, LegBR = { " R Back Leg Top" },
		Recolor = function(p)
			return p.Color:Lerp(C(46, 36, 34), 0.7)
		end,
		Effects = function(model, primary)
			fireAura(C(255, 100, 30), 5)(model, primary)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") and d.Name:lower():find("foot") then
					d.Material = Enum.Material.Neon
					d.Color = C(255, 110, 30)
				end
			end
		end,
	},
	LavaSalamander = clone(CROC, {
		Fit = 1.15, Strip = true, Material = Enum.Material.CrackedLava,
		Recolor = function()
			return C(255, 120, 40)
		end,
		Effects = fireAura(C(255, 90, 20), 4),
	}),
	HollowStag = clone(DEER, {
		Fit = 1.25, Strip = true,
		Recolor = function(p)
			return p.Color:Lerp(C(18, 16, 20), 0.85)
		end,
		Effects = glowEyes(C(255, 40, 40)),
	}),
	---------------------------------------------------------------- ลูกสัตว์วิญญาณ (จิ้งจอกตัวเล็กสีธาตุ)
	TerraPup = fox({ Fit = 1.2, Strip = true, Material = Enum.Material.Glass, Recolor = spirit(C(110, 230, 90)), Effects = spiritGlow(C(130, 255, 110)) }),
	TidePup = fox({ Fit = 1.2, Strip = true, Material = Enum.Material.Glass, Recolor = spirit(C(70, 190, 255)), Effects = spiritGlow(C(110, 220, 255)) }),
	GalePup = fox({ Fit = 1.2, Strip = true, Material = Enum.Material.Glass, Recolor = spirit(C(225, 235, 255)), Effects = spiritGlow(C(220, 240, 255)) }),
	EmberPup = fox({ Fit = 1.2, Strip = true, Material = Enum.Material.Glass, Recolor = spirit(C(255, 120, 40)), Effects = spiritGlow(C(255, 140, 50)) }),
	---------------------------------------------------------------- บอส 4 ไบโอม
	-- ไฟ: มังกรไฟลาวา
	Solfang = {
		Model = "FireDragon", Mode = "Quad", Head = "HeadTemple", Fit = 3.0, LegAmp = 0.35,
		Spine = { "Scale3", "Scale4", "Scale5", "Scale6", "Scale7", "Scale8" },
		LegFL = { "UpperLeftArm" }, LegFR = { "UpperRightArm" }, LegBL = { "UpperLeftLeg" }, LegBR = { "UpperRightLeg" },
		Recolor = function(p)
			local n = p.Name:lower()
			if n:find("skin") or n:find("fire") then
				return C(255, 110, 25) -- ผิวใต้เกล็ด = ลาวาเรืองแสง
			elseif n:find("hair") or n:find("beard") then
				return C(255, 170, 40)
			elseif n:find("eye") then
				return C(255, 240, 120)
			elseif n:find("horn") or n:find("teeth") then
				return C(40, 30, 30)
			elseif n:find("bottom") then
				return C(150, 40, 20)
			end
			return C(54, 22, 20) -- เกล็ดดำแดง
		end,
		Effects = function(model, primary, head)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					local n = d.Name:lower()
					if n:find("skin") or n:find("fire") or n:find("eye") then
						d.Material = Enum.Material.Neon
					elseif n:find("hair") then
						d.Material = Enum.Material.Neon
						d.Transparency = math.max(d.Transparency, 0.15)
					else
						d.Material = Enum.Material.Basalt
					end
				end
			end
			fireAura(C(255, 110, 30), 6)(model, primary)
			if head then
				local f = Instance.new("Fire")
				f.Size = 8
				f.Heat = 12
				f.Parent = head
			end
		end,
	},
	-- น้ำ: โมซาซอรัส
	Leviathan = {
		Model = "Mosasaurus", Mode = "Swim", Front = "X", Fit = 1.25, Segments = { 0.3, 0.45, 0.6, 0.75, 0.88 },
		Effects = glowEyes(C(120, 230, 255)),
	},
	-- ฟ้า: กริฟฟิน
	TempestRoc = {
		Model = "Griffin", Mode = "Flyer", Head = "Head", Fit = 0.95, WingSign = -1,
		WingL = { "LeftWing" }, WingR = { "RightWing" },
		LegFL = { "LeftFrontLeg" }, LegFR = { "RightFrontLeg" }, LegBL = { "LeftBackLeg" }, LegBR = { "RightBackLeg" },
		Effects = function(model, primary)
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Rate = 30
			e.Lifetime = NumberRange.new(0.6, 1.4)
			e.Speed = NumberRange.new(2, 6)
			e.SpreadAngle = Vector2.new(180, 180)
			e.LightEmission = 1
			e.Size = NumberSequence.new(1.2, 0)
			e.Color = ColorSequence.new(C(170, 230, 255))
			e.Parent = primary
		end,
	},
	-- ดิน: งูยักษ์มังกรหยก
	Terragon = {
		Model = "EarthSerpent", Mode = "Serpent", FitHeight = 3.4, Segments = { 0.3, 0.5, 0.7, 0.85 },
		Recolor = function(p)
			local n = p.Name:lower()
			if n:find("eye") then
				return C(255, 220, 80)
			end
			return p.Color:Lerp(C(70, 110, 60), 0.35)
		end,
		Effects = glowEyes(C(255, 220, 80)),
	},
}

-- ชื่อ/ตำแหน่งบอสใหม่ (ใช้ทับข้อมูลใน Animals.lua)
Creatures.BossNames = {
	Solfang = { Name = "IGNARAX, the Molten Dragon", Thai = "อิกนาแรกซ์ มังกรเพลิงลาวา" },
	Leviathan = { Name = "TYRANNOMOSA, Terror of the Deep", Thai = "ไทรันโนโมซา โมซาซอรัสแห่งห้วงลึก" },
	TempestRoc = { Name = "AERION, the Storm Griffin", Thai = "แอริออน กริฟฟินแห่งพายุ" },
	Terragon = { Name = "JORMUNGAIA, the Jade Serpent", Thai = "ยอร์มุงไกอา งูมังกรหยกแห่งปฐพี" },
}

return Creatures
