--[[
	Atmosphere — ตั้งค่าแสง/หมอก/สี แบบภาพยนตร์ ผสมตามไบโอม + เวลากลางคืน
	  Install(Lighting)                         สร้างเอฟเฟกต์ทั้งหมด (ครั้งเดียว)
	  Values(biome, night, mode)                คืนตารางค่าเป้าหมาย
	  Blend(a, b, t)                            ผสม 2 ตาราง
	  Apply(Lighting, values)                   ใส่ค่าลงจริง
	  ApplyBiome(Lighting, biome, night, mode)  ทางลัด (ใช้ในปลั๊กอิน)
	mode: nil | "BloodMoon"
]]

local Biomes = require(script.Parent.Biomes)

local Atmosphere = {}

local function get(parent, className, name)
	local inst = parent:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = parent
	end
	return inst
end

function Atmosphere.Install(lighting)
	for _, child in ipairs(lighting:GetChildren()) do
		if child:IsA("Sky") and child.Name ~= "ASSky" then
			child:Destroy()
		end
	end
	local atm = lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Name = "Atmosphere"
	atm.Parent = lighting
	local sky = get(lighting, "Sky", "ASSky")
	sky.StarCount = 6000
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 16
	sky.CelestialBodiesShown = true
	get(lighting, "BloomEffect", "ASBloom")
	get(lighting, "ColorCorrectionEffect", "ASGrade")
	local rays = get(lighting, "SunRaysEffect", "ASSunRays")
	rays.Intensity = 0.07
	rays.Spread = 0.75
	local dof = get(lighting, "DepthOfFieldEffect", "ASDepth")
	dof.FarIntensity = 0.12
	dof.FocusDistance = 60
	dof.InFocusRadius = 90
	dof.NearIntensity = 0
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Parent = workspace.Terrain
	end
	clouds.Cover = 0.58
	clouds.Density = 0.55
	lighting.EnvironmentDiffuseScale = 1
	lighting.EnvironmentSpecularScale = 1
	lighting.GlobalShadows = true
	pcall(function()
		lighting.ShadowSoftness = 0.15
	end)
end

-- ค่าเป้าหมายของ (ไบโอม, ความมืด 0..1)
function Atmosphere.Values(biome, night, mode)
	local b = Biomes.Data[biome] or Biomes.Data.Heart
	local a, g = b.Atmosphere, b.Grade
	local day = {
		Density = a.Density, Offset = a.Offset, Haze = a.Haze, Glare = a.Glare,
		AtmColor = a.Color, Decay = a.Decay,
		Tint = g.Tint, Saturation = g.Saturation, Contrast = g.Contrast, Brightness = g.Brightness,
		Ambient = Color3.fromRGB(76, 72, 80), Outdoor = Color3.fromRGB(132, 128, 140),
		LightBrightness = 2.4, Exposure = 0,
		BloomIntensity = 0.55, BloomSize = 26, BloomThreshold = 1.55,
		CloudColor = Color3.fromRGB(255, 255, 255), CloudCover = 0.58, SunRays = 0.07,
	}
	for k, v in pairs(b.Lighting or {}) do
		day[k] = v
	end
	if night <= 0 then
		return day
	end
	local n = Biomes.Night[mode == "BloodMoon" and "BloodMoon" or "Normal"]
	local nightV = {
		Density = a.Density + n.DensityAdd, Offset = a.Offset * 0.5, Haze = a.Haze + 1.2, Glare = 0,
		AtmColor = n.Color, Decay = n.Decay,
		Tint = n.Tint, Saturation = n.Saturation, Contrast = n.Contrast, Brightness = -0.02,
		Ambient = mode == "BloodMoon" and Color3.fromRGB(70, 26, 28) or Color3.fromRGB(54, 64, 98),
		Outdoor = mode == "BloodMoon" and Color3.fromRGB(124, 46, 44) or Color3.fromRGB(100, 116, 166),
		LightBrightness = 1.8, Exposure = 0.25, -- แสงจันทร์สีน้ำเงิน: มืดแต่ยังเห็นเงาต้นไม้ (แบบ 99 Nights)
		BloomIntensity = 0.9, BloomSize = 30, BloomThreshold = 1.1,
		CloudColor = mode == "BloodMoon" and Color3.fromRGB(120, 40, 40) or Color3.fromRGB(70, 80, 110), CloudCover = 0.62,
	}
	return Atmosphere.Blend(day, nightV, night)
end

local function lerpAny(x, y, t)
	if typeof(x) == "Color3" then
		return x:Lerp(y, t)
	end
	return x + (y - x) * t
end

function Atmosphere.Blend(a, b, t)
	local out = {}
	for k, v in pairs(a) do
		local w = b[k]
		out[k] = (w ~= nil) and lerpAny(v, w, t) or v
	end
	return out
end

function Atmosphere.Apply(lighting, v)
	local atm = lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		atm.Density = v.Density
		atm.Offset = v.Offset
		atm.Haze = v.Haze
		atm.Glare = v.Glare
		atm.Color = v.AtmColor
		atm.Decay = v.Decay
	end
	local grade = lighting:FindFirstChild("ASGrade")
	if grade then
		grade.TintColor = v.Tint
		grade.Saturation = v.Saturation
		grade.Contrast = v.Contrast
		grade.Brightness = v.Brightness
	end
	local bloom = lighting:FindFirstChild("ASBloom")
	if bloom then
		bloom.Intensity = v.BloomIntensity
		bloom.Size = v.BloomSize
		bloom.Threshold = v.BloomThreshold
	end
	local rays = lighting:FindFirstChild("ASSunRays")
	if rays and v.SunRays then
		rays.Intensity = v.SunRays
	end
	lighting.Ambient = v.Ambient
	lighting.OutdoorAmbient = v.Outdoor
	lighting.Brightness = v.LightBrightness
	lighting.ExposureCompensation = v.Exposure
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Color = v.CloudColor
		clouds.Cover = v.CloudCover
	end
end

function Atmosphere.ApplyBiome(lighting, biome, night, mode)
	Atmosphere.Install(lighting)
	Atmosphere.Apply(lighting, Atmosphere.Values(biome, night or 0, mode))
end

return Atmosphere
