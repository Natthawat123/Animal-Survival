--[[
	AtmosphereController — แสงแดด/ดวงจันทร์ตามเวลาเกม + เปลี่ยนบรรยากาศนุ่มๆ ตามไบโอมที่ยืนอยู่
	  - คืนพระจันทร์เลือด = ฟ้าแดงเข้ม
	  - เกินระยะ "หมอกเปิด" ของกองไฟ = หมอกหนา (อัปเกรดกองไฟเพื่อเปิดแมพ)
	  - กองไฟดับตอนกลางคืน = มืดลงอีก
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
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
	local inCamp = 0 -- 1 = อยู่ในเขตแคมป์, 0 = ออกนอกแคมป์ (มืดลงอีกนิด)
	AtmosphereController.Biome = "Heart"

	-- ไฟส่องพื้นที่ในแคมป์ตอนกลางคืน (ฝั่งผู้เล่น): ดวงไฟล่องหนเรียงเป็นตารางในเขตแคมป์ แสงไม่เกินขอบแคมป์มาก
	-- สร้างใหม่เมื่อรัศมีแคมป์เปลี่ยน (อัปเกรดกองไฟ) · ความสว่างตามความมืด (กลางวัน/ไฟดับ = ปิด)
	local campLights, lightsR, lightsLevel = {}, nil, -1
	local folder
	local function buildCampLights(R)
		if folder then
			folder:Destroy()
		end
		campLights = {}
		folder = Instance.new("Folder")
		folder.Name = "CampNightLights"
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { Workspace.Terrain }
		local inner = math.max(R - 22, 18) -- ดวงไฟอยู่ลึกเข้ามาจากขอบ แสงจะจางหมดราวขอบแคมป์
		local step = 30
		local lim = math.floor(inner / step) * step -- ตารางสมมาตรรอบกองไฟ (0,0)
		for x = -lim, lim, step do
			for z = -lim, lim, step do
				if x * x + z * z <= inner * inner then
					local hit = Workspace:Raycast(Vector3.new(x, 800, z), Vector3.new(0, -1600, 0), rp)
					local gy = hit and hit.Position.Y or 20
					local part = Instance.new("Part")
					part.Name = "CampLight"
					part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
					part.Transparency = 1
					part.Size = Vector3.new(1, 1, 1)
					part.Position = Vector3.new(x, gy + 14, z)
					local l = Instance.new("PointLight")
					l.Color = Color3.fromRGB(255, 208, 150)
					l.Range = 34
					l.Shadows = false
					l.Brightness = 0
					l.Parent = part
					part.Parent = folder
					table.insert(campLights, l)
				end
			end
		end
		folder.Parent = Workspace
	end
	local function updateCampLights(level)
		local R = state:GetAttribute("CampRadius")
		if level > 0 and R and (R ~= lightsR or not folder or not folder.Parent) then
			lightsR = R
			buildCampLights(R)
			lightsLevel = -1
		end
		level = math.floor(level * 20 + 0.5) / 20 -- อัปเดตเฉพาะตอนค่าเปลี่ยน
		if level ~= lightsLevel then
			lightsLevel = level
			for _, l in ipairs(campLights) do
				l.Brightness = 1.6 * level
				l.Enabled = level > 0
			end
		end
	end

	RunService.RenderStepped:Connect(function(dt)
		local now = Workspace:GetServerTimeNow()
		local clock, night = clockFor(state, now)
		local cam = Workspace.CurrentCamera
		local pos = cam.CFrame.Position
		-- ล็อบบี้: บ่ายแดดลอดป่าตลอด (ค่าแสงมาจาก Biomes.Data.Lobby)
		-- ล็อบบี้อยู่ไกลนอกแมพ (12000,1800,12000) · มิติศาลเจ้า/วิหารลอยสูง ~2400 เหนือแมพ (ห้ามนับเป็นล็อบบี้)
		local outside = math.abs(pos.X) > 6000 or math.abs(pos.Z) > 6000
		local inLobby = pos.Y > 1200 and outside
		local inRealm = pos.Y > 1900 and not outside
		if inLobby then
			clock, night = 15.4, 0
		elseif inRealm then
			clock, night = 14, 0 -- มิติ: กลางวันสว่างตลอด โทนตามไบโอมใต้เกาะ
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
			veil = (inLobby or inRealm) and 0 or math.clamp((d - (reveal - 220)) / 260, 0, 1) -- ใกล้กำแพงหมอก = ฟ้าขมุกขมัว
			-- เขตแคมป์ (แคมป์อยู่กลางแมพ 0,0): วัดจากตัวละคร ค่อยๆ จางออกช่วง 40 stud นอกขอบ
			local root = game:GetService("Players").LocalPlayer.Character
			root = root and root:FindFirstChild("HumanoidRootPart")
			local cp = root and root.Position or pos
			local cd = math.sqrt(cp.X * cp.X + cp.Z * cp.Z)
			local campR = state:GetAttribute("CampRadius") or 60
			inCamp = inLobby and 0 or math.clamp(1 - (cd - campR) / 40, 0, 1)
		end
		local mode = state:GetAttribute("BloodMoon") and "BloodMoon" or nil
		local target = Atmosphere.Values(biome, night, mode)
		if Players.LocalPlayer:GetAttribute("CineMode") then
			-- ฉากคัตซีนศาลเจ้า: หมอกจางลงให้เห็นเสาผลึก/ลำแสงชัด
			target.Density = target.Density * 0.35
			target.Haze = target.Haze * 0.25
		end
		if veil > 0 then
			target.Density = target.Density + veil * 0.3
			target.Haze = target.Haze + veil * 4
			target.AtmColor = target.AtmColor:Lerp(Color3.fromRGB(150, 150, 160), veil * 0.6)
		end
		-- กลางคืน: สว่างเฉพาะพื้นที่ในแคมป์ (ไฟดวงในเขตแคมป์ ดู updateCampLights) · ข้างนอกมืดตามปกติแม้มองจากในแคมป์
		-- (ไม่ยกค่าแสงทั้งจอ เพราะ Exposure/Ambient เป็นค่ารวม จะทำให้ป่าข้างนอกสว่างตามไปด้วย) · เดินออกนอกแคมป์ = มืดลงอีกนิด
		local campLit = not inLobby and not inRealm and night > 0 and (state:GetAttribute("CampFuel") or 1) > 0
		if campLit then
			target.Exposure = target.Exposure - (1 - inCamp) * night * 0.1
		end
		updateCampLights(campLit and night or 0)
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
