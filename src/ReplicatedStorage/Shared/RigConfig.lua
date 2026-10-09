--[[
	RigConfig — สัตว์ตัวไหนใช้โมเดลมีกระดูก+ท่าจริง (ReplicatedStorage.AnimRigs/<Rig>) บนเครื่องผู้เล่น
	Animals[animalId] = {
		Rig        = ชื่อข้อมูลใน AnimRigs
		Fit        = ความยาวโมเดล / ความยาว rig ของ server (ค่าเริ่ม 1) · FitHeight = ใช้ความสูงแทน · Scale = คูณเพิ่ม
		WalkStride / RunStride = ระยะก้าวต่อรอบท่า (สัดส่วนความยาวตัว) -> ปรับความเร็วท่าให้เท้าไม่ไถล
		Effects(model, boneParts, k) = เพิ่มไฟ/แสง/อนุภาค
	}
]]

local RigConfig = {}

local C = Color3.fromRGB

local function light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = part
	return l
end

local function sparkles(part, color, rate, size)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = rate or 10
	e.Lifetime = NumberRange.new(0.6, 1.3)
	e.Speed = NumberRange.new(0.5, 2.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Size = NumberSequence.new(size or 0.4, 0)
	e.Color = ColorSequence.new(color)
	e.Parent = part
	return e
end

local function fire(part, size, color)
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = size * 1.4
	if color then
		f.Color = color
		f.SecondaryColor = C(255, 220, 120)
	end
	f.Parent = part
	return f
end

-- กระดูกลำตัว (ชิ้นแรกที่ไม่ใช่ราก) สำหรับติดเอฟเฟกต์
local function body(parts)
	return parts[3] or parts[2] or parts[1]
end

-- หากระดูกตามชื่อ (ไม่สนตัวพิมพ์) เช่น "head" -> ชิ้นแรกที่ชื่อมีคำนี้
local function bone(byName, bparts, ...)
	for _, key in ipairs({ ... }) do
		if byName[key] then
			return byName[key]
		end
		for n, p in pairs(byName) do
			if n:lower():find(key:lower(), 1, true) then
				return p
			end
		end
	end
	return body(bparts)
end

local function smoke(part, color, rate)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = rate or 6
	e.Lifetime = NumberRange.new(1.2, 2.2)
	e.Speed = NumberRange.new(0.3, 1)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.5) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(color)
	e.Parent = part
	return e
end

RigConfig.Fx = { light = light, sparkles = sparkles, fire = fire, body = body, bone = bone, smoke = smoke }

-- ลูกสัตว์วิญญาณ: แสงสีธาตุ + ประกายเล็กๆ
local function spirit(color)
	return function(_, byName, k, bparts)
		local b = body(bparts)
		light(b, color, 10 * k, 1.4)
		sparkles(b, color, 6, 0.35 * k)
		light(bone(byName, bparts, "Head"), color, 4 * k, 0.8)
	end
end

local function fireAura(color, size, glowRange)
	return function(_, byName, k, bparts)
		local b = body(bparts)
		fire(b, size * k, color)
		light(b, color, (glowRange or 12) * k, 1.6)
	end
end

RigConfig.Animals = {
	---------------------------------------------------------------- สัตว์ทั่วไป (Quaternius CC0 / Poly by Google CC-BY)
	Rabbit = { Rig = "Rabbit", Fit = 1.0, WalkStride = 0.7, RunStride = 1.6 },
	Deer = { Rig = "Deer", Fit = 1.0 },
	MossWolf = { Rig = "Wolf", Fit = 1.1 },
	Thornboar = { Rig = "Boar", Fit = 1.0 },
	StoneBear = { Rig = "Bear", Fit = 1.0, WalkStride = 0.5, RunStride = 1.2 },
	ReefCrab = { Rig = "Crab", Fit = 0.75, WalkStride = 0.35, RunStride = 0.7 },
	RiptideCroc = { Rig = "Caiman", Fit = 1.0, WalkStride = 0.35, RunStride = 0.8 },
	SkyLynx = {
		Rig = "Lynx", Fit = 1.0,
		Effects = function(_, byName, k, bparts)
			sparkles(body(bparts), C(160, 220, 255), 3, 0.3 * k)
		end,
	},
	StormRam = {
		Rig = "Ram", Fit = 1.0,
		Effects = function(_, byName, k, bparts)
			local h = bone(byName, bparts, "Head")
			light(h, C(140, 220, 255), 8 * k, 1.2)
			sparkles(h, C(170, 230, 255), 4, 0.3 * k)
		end,
	},
	EmberFox = { Rig = "Fox", Fit = 1.0, Effects = fireAura(C(255, 120, 40), 1.6, 10) },
	MagmaRhino = {
		Rig = "Bull", Fit = 1.0, WalkStride = 0.5, RunStride = 1.2,
		Effects = function(_, byName, k, bparts)
			local b = body(bparts)
			fire(b, 2.5 * k, C(255, 100, 30))
			light(b, C(255, 110, 40), 16 * k, 1.8)
			smoke(b, C(60, 50, 50), 4)
		end,
	},
	LavaSalamander = { Rig = "Salamander", Fit = 1.0, WalkStride = 0.35, RunStride = 0.8, Effects = fireAura(C(255, 90, 20), 1.4, 10) },
	HollowStag = {
		Rig = "Stag", Fit = 1.0,
		Effects = function(_, byName, k, bparts)
			local h = bone(byName, bparts, "Head")
			light(h, C(255, 30, 30), 10 * k, 2)
			smoke(body(bparts), C(20, 16, 24), 8)
		end,
	},
	---------------------------------------------------------------- ลูกสัตว์วิญญาณ
	TerraPup = { Rig = "PupTerra", Fit = 1.0, Effects = spirit(C(130, 255, 110)) },
	TidePup = { Rig = "PupTide", Fit = 1.0, Effects = spirit(C(110, 220, 255)) },
	GalePup = { Rig = "PupGale", Fit = 1.0, Effects = spirit(C(220, 240, 255)) },
	EmberPup = { Rig = "PupEmber", Fit = 1.0, Effects = spirit(C(255, 140, 50)) },
}

return RigConfig
