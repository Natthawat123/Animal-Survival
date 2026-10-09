--[[
	AtmosphereController — แสงแดด/ดวงจันทร์ตามเวลาเกม + เปลี่ยนบรรยากาศนุ่มๆ ตามไบโอมที่ยืนอยู่
	  - คืนพระจันทร์เลือด = ฟ้าแดงเข้ม
	  - เกินระยะ "หมอกเปิด" ของกองไฟ = หมอกหนา (อัปเกรดกองไฟเพื่อเปิดแมพ)
	  - กองไฟดับตอนกลางคืน = มืดลงอีก
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Atmosphere = require(Shared.Atmosphere)
local MapLayout = require(Shared.MapLayout)

local AtmosphereController = {}

local function clockFor(state, now)
	local phase = state:GetAttribute("Phase") or "Day"
	local s, e = state:GetAttribute("PhaseStart") or now, state:GetAttribute("PhaseEnd") or now
	local f = math.clamp((now - s) / math.max(e - s, 0.01), 0, 1)
	if phase == "Day" then
		return 6.4 + f * 11.0, 0
	elseif phase == "Dusk" then
		return 17.4 + f * 1.7, f * 0.65
	elseif phase == "Night" then
		local t = 19.1 + f * 10.6
		local n = 1
		if f < 0.08 then
			n = 0.65 + f / 0.08 * 0.35
		elseif f > 0.9 then
			n = 1 - (f - 0.9) / 0.1 * 0.7
		end
		return t % 24, n
	end
	return 14, 0
end

function AtmosphereController.Init(state)
	AtmosphereController.State = state
	Atmosphere.Install(Lighting)
	local layout
	local function ensureLayout()
		if not layout and state:GetAttribute("Seed") then
			layout = MapLayout.new(state:GetAttribute("Seed"), state:GetAttribute("MapSize") or Config.MapSize, Config)
			AtmosphereController.Layout = layout
		end
		return layout
	end
	ensureLayout()
	state:GetAttributeChangedSignal("Seed"):Connect(ensureLayout)

	local current = Atmosphere.Values("Heart", 0)
	local biome = "Heart"
	local lastBiomeCheck = 0
	local veil = 0
	AtmosphereController.Biome = "Heart"

	RunService.RenderStepped:Connect(function(dt)
		local now = Workspace:GetServerTimeNow()
		local clock, night = clockFor(state, now)
		local cam = Workspace.CurrentCamera
		local pos = cam.CFrame.Position
		-- ล็อบบี้: เที่ยงคืนพระจันทร์เต็มดวงตลอด (ค่าแสงมาจาก Biomes.Data.Lobby)
		local inLobby = pos.Y > 1200
		if inLobby then
			clock, night = 0.2, 0
		elseif state:GetAttribute("TestClock") then
			clock, night = state:GetAttribute("TestClock"), 0 -- ภาพทดสอบ: ตรึงเวลากลางวัน
		end
		Lighting.ClockTime = clock
		if os.clock() - lastBiomeCheck > 0.3 and (inLobby or ensureLayout()) then
			lastBiomeCheck = os.clock()
			biome = inLobby and "Lobby" or layout:BiomeAt(pos.X, pos.Z)
			AtmosphereController.Biome = biome
			-- หมอกนอกเขตที่กองไฟเปิดไว้
			local reveal = state:GetAttribute("CampReveal") or 99999
			local d = math.sqrt(pos.X * pos.X + pos.Z * pos.Z)
			veil = inLobby and 0 or math.clamp((d - reveal) / 300, 0, 1)
		end
		local mode = state:GetAttribute("BloodMoon") and "BloodMoon" or nil
		local target = Atmosphere.Values(biome, night, mode)
		if veil > 0 then
			target.Density = target.Density + veil * 0.3
			target.Haze = target.Haze + veil * 4
			target.AtmColor = target.AtmColor:Lerp(Color3.fromRGB(150, 150, 160), veil * 0.6)
		end
		if not inLobby and night > 0.5 and (state:GetAttribute("CampFuel") or 1) <= 0 then
			target.Exposure = target.Exposure - 0.35
			target.Tint = target.Tint:Lerp(Color3.fromRGB(150, 160, 200), 0.4)
		end
		-- ผู้เล่นล้ม = ภาพจาง
		local lp = game:GetService("Players").LocalPlayer
		if lp:GetAttribute("Downed") then
			target.Saturation = -0.7
			target.Contrast = 0.3
		end
		local alpha = 1 - math.exp(-dt * 1.6)
		current = Atmosphere.Blend(current, target, alpha)
		Atmosphere.Apply(Lighting, current)
		-- ใต้น้ำ
		local grade = Lighting:FindFirstChild("ASGrade")
		if grade and pos.Y < (state:GetAttribute("WaterLevel") or 20) - 0.5 then
			local mat = Workspace.Terrain:ReadVoxels(Region3.new(pos - Vector3.new(2, 2, 2), pos + Vector3.new(2, 2, 2)):ExpandToGrid(4), 4)
			if mat[1] and mat[1][1] and mat[1][1][1] == Enum.Material.Water then
				grade.TintColor = Color3.fromRGB(120, 200, 255)
				local atm = Lighting:FindFirstChildOfClass("Atmosphere")
				if atm then
					atm.Density = 0.6
					atm.Color = Color3.fromRGB(40, 120, 160)
				end
			end
		end
	end)
end

return AtmosphereController
