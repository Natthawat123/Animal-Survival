--[[
	AmbientFX — อนุภาคลอยรอบตัว (เปลี่ยนตามไบโอม/เวลา) + ลมพัดขึ้นเกาะลอยฟ้า
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AmbientFX = {}

local TEX = {
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
}

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 0
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

local NS = NumberSequence.new
local NSK = NumberSequenceKeypoint.new

function AmbientFX.Init(state, atmosphereController)
	local box = Instance.new("Part")
	box.Name = "AmbientBox"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Transparency = 1
	box.Size = Vector3.new(140, 50, 140)
	box.Parent = Workspace.CurrentCamera

	local fx = {
		Pollen = emitter(box, {
			Texture = TEX.Spark, Lifetime = NumberRange.new(6, 10), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
			Size = NS(0.18), LightEmission = 0.6, Color = ColorSequence.new(Color3.fromRGB(255, 240, 170)),
			Transparency = NS({ NSK(0, 1), NSK(0.2, 0.2), NSK(0.8, 0.2), NSK(1, 1) }), Acceleration = Vector3.new(0.5, -0.1, 0.3),
		}),
		Fireflies = emitter(box, {
			Texture = TEX.Spark, Lifetime = NumberRange.new(4, 8), Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180),
			Size = NS({ NSK(0, 0.1), NSK(0.5, 0.4), NSK(1, 0.1) }), LightEmission = 1, LightInfluence = 0,
			Color = ColorSequence.new(Color3.fromRGB(180, 255, 120)), Transparency = NS({ NSK(0, 1), NSK(0.3, 0), NSK(0.7, 0.3), NSK(1, 1) }),
			RotSpeed = NumberRange.new(-30, 30),
		}),
		Mist = emitter(box, {
			Texture = TEX.Smoke, Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(30, 180),
			Size = NS({ NSK(0, 8), NSK(1, 18) }), LightEmission = 0.1, Color = ColorSequence.new(Color3.fromRGB(220, 236, 245)),
			Transparency = NS({ NSK(0, 1), NSK(0.4, 0.82), NSK(1, 1) }), Acceleration = Vector3.new(1, 0, 0),
		}),
		Wind = emitter(box, {
			Texture = TEX.Smoke, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(40, 60), SpreadAngle = Vector2.new(4, 4),
			EmissionDirection = Enum.NormalId.Right, Size = NS({ NSK(0, 0.5), NSK(1, 1.5) }), LightEmission = 0.3,
			Color = ColorSequence.new(Color3.fromRGB(240, 246, 255)), Transparency = NS({ NSK(0, 1), NSK(0.3, 0.75), NSK(1, 1) }),
			Squash = NS(-1.5),
		}),
		Snow = emitter(box, {
			Texture = TEX.Spark, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(20, 20),
			EmissionDirection = Enum.NormalId.Bottom, Size = NS(0.25), LightEmission = 0.4, Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Acceleration = Vector3.new(4, 0, 2),
		}),
		Embers = emitter(box, {
			Texture = TEX.Spark, Lifetime = NumberRange.new(3, 6), Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = Enum.NormalId.Top, Size = NS({ NSK(0, 0.35), NSK(1, 0) }), LightEmission = 1, LightInfluence = 0,
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 60, 20)), Acceleration = Vector3.new(1, 2, 0.5),
		}),
		Ash = emitter(box, {
			Texture = TEX.Smoke, Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(40, 40),
			EmissionDirection = Enum.NormalId.Bottom, Size = NS(0.3), Color = ColorSequence.new(Color3.fromRGB(80, 76, 76)),
			Transparency = NS(0.3), RotSpeed = NumberRange.new(-90, 90), Rotation = NumberRange.new(0, 360),
		}),
		BloodMist = emitter(box, {
			Texture = TEX.Smoke, Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(180, 180),
			Size = NS({ NSK(0, 10), NSK(1, 20) }), Color = ColorSequence.new(Color3.fromRGB(140, 20, 24)),
			Transparency = NS({ NSK(0, 1), NSK(0.5, 0.8), NSK(1, 1) }),
		}),
	}

	-- อัตราอนุภาคตามไบโอม (กลางวัน, กลางคืน)
	local RATES = {
		Heart = { Pollen = { 18, 2 }, Fireflies = { 0, 26 }, Mist = { 0, 4 } },
		Lobby = { Fireflies = { 8, 8 } },
		Earth = { Fireflies = { 6, 40 }, Mist = { 2, 6 }, Pollen = { 10, 0 } },
		Water = { Mist = { 4, 5 }, Wind = { 2, 2 } },
		Air = { Wind = { 10, 8 }, Snow = { 30, 40 } },
		Fire = { Embers = { 30, 40 }, Ash = { 25, 25 } },
	}

	local player = Players.LocalPlayer
	local updraftParams = OverlapParams.new()
	updraftParams.FilterType = Enum.RaycastFilterType.Include

	RunService.RenderStepped:Connect(function(dt)
		local cam = Workspace.CurrentCamera
		box.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 4, 0))
		local biome = atmosphereController.Biome or "Heart"
		local nightPhase = state:GetAttribute("Phase") == "Night" and biome ~= "Lobby"
		local rates = RATES[biome] or {}
		for name, e in pairs(fx) do
			local r = rates[name]
			local target = r and (nightPhase and r[2] or r[1]) or 0
			if name == "BloodMist" then
				target = state:GetAttribute("BloodMoon") and nightPhase and 6 or 0
			end
			e.Rate = target
		end
		-- ลมพัดขึ้น
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			for _, zone in ipairs(CollectionService:GetTagged("Updraft")) do
				if zone:IsA("BasePart") then
					local rel = zone.CFrame:PointToObjectSpace(root.Position)
					local half = zone.Size / 2
					if math.abs(rel.X) < half.X and math.abs(rel.Z) < half.Z and rel.Y > -half.Y and rel.Y < half.Y then
						local v = root.AssemblyLinearVelocity
						root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 85), v.Z)
					end
				end
			end
		end
	end)
end

return AmbientFX
