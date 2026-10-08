--[[
	AnimalSurvivalStudio — ปลั๊กอิน Roblox Studio ของเกม ANIMAL SURVIVAL
	ติดตั้ง: python tools/install_plugin.py  (หรือคัดลอกไฟล์นี้ไปที่ %LOCALAPPDATA%\Roblox\Plugins\AnimalSurvivalStudio.lua)

	แท็บ Plugins -> กลุ่ม "Animal Survival"
	  [Build Map]   สร้างแมพตัวอย่างตอน Edit (seed จาก Config.PreviewSeed) — ดูแมพได้โดยไม่ต้องกด Play
	  [Clear Map]   ลบแมพตัวอย่าง (ตอนกด Play เซิร์ฟเวอร์สร้างแมพใหม่แบบสุ่มเองอยู่แล้ว)
	  [Cinematic]   ตั้งแสง/บรรยากาศสวยๆ ในหน้า Edit

	อัตโนมัติ (ใช้กับ tools/run_studio_test.ps1):
	  ReplicatedStorage.ASAutoTest  -> เริ่ม playtest เอง
	  ServerStorage.ASMapShot       -> สร้างแมพทั้งหมด แล้วถ่ายภาพมุมสูง/ไบโอม ([SHOT] ชื่อภาพ)
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

if RunService:IsRunning() then
	return
end

pcall(function()
	game:GetService("ScriptContext"):SetTimeout(600)
end)

local function isOurGame()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	return shared and shared:FindFirstChild("MapLayout") and shared:FindFirstChild("Animals") and true or false
end

-- require แบบสดใหม่ (โคลนโฟลเดอร์ Shared กันแคช)
local function freshShared()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if not shared then
		return nil
	end
	local clone = shared:Clone()
	clone.Name = "ASPreviewShared"
	clone.Parent = ServerStorage
	local ok, mods = pcall(function()
		local m = {}
		for _, name in ipairs({ "Config", "Biomes", "MapLayout", "MapGenerator", "PropBuilder", "AnimalModels", "Animals", "Atmosphere", "AnimalSkins", "MeshProps" }) do
			local ms = clone:FindFirstChild(name)
			if ms then
				m[name] = require(ms)
			end
		end
		return m
	end)
	task.delay(1, function()
		clone:Destroy()
	end)
	if not ok then
		warn("[AS] โหลดโมดูลไม่สำเร็จ:", mods)
		return nil
	end
	return mods
end

local function banner(text, color)
	local gui = game:GetService("CoreGui"):FindFirstChild("ASBanner")
	if not text then
		if gui then
			gui:Destroy()
		end
		return
	end
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "ASBanner"
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(0, 560, 0, 46)
		label.Position = UDim2.new(0.5, -280, 0, 12)
		label.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
		label.BackgroundTransparency = 0.15
		label.Font = Enum.Font.GothamBold
		label.TextSize = 18
		label.Parent = gui
		Instance.new("UICorner", label).CornerRadius = UDim.new(0, 10)
		gui.Parent = game:GetService("CoreGui")
	end
	gui.Label.Text = text
	gui.Label.TextColor3 = color or Color3.fromRGB(255, 214, 120)
end

local function setupLighting(mods)
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	if mods and mods.Atmosphere then
		mods.Atmosphere.Install(Lighting)
		mods.Atmosphere.ApplyBiome(Lighting, "Heart", 0)
	end
	Lighting.ClockTime = 16.2
end

local function clearMap()
	workspace.Terrain:Clear()
	local w = workspace:FindFirstChild("World")
	if w then
		w:Destroy()
	end
end

local function buildMap(opts)
	opts = opts or {}
	local mods = freshShared()
	if not mods then
		return nil
	end
	local Config = mods.Config
	local seed = opts.Seed or Config.PreviewSeed
	local size = opts.Size or Config.MapSize
	local layout = mods.MapLayout.new(seed, size, Config)
	clearMap()
	local t0 = os.clock()
	mods.MapGenerator.Generate(layout, {
		Yield = true,
		Budget = 0.2,
		Progress = function(done, total)
			if done % 20 == 0 or done == total then
				banner(string.format("⏳ กำลังสร้างแมพ %d/%d ชิ้น (seed %d)", done, total, seed))
			end
		end,
	})
	print(string.format("[AS] terrain %.1fs size=%d seed=%d", os.clock() - t0, size, seed))
	if mods.PropBuilder and not opts.NoProps then
		local t1 = os.clock()
		local world = mods.PropBuilder.BuildWorld(layout, { Preview = true, Density = Config.PropDensity, Yield = true })
		print(string.format("[AS] props %.1fs parts=%d", os.clock() - t1, #world:GetDescendants()))
		-- สวมโมเดลจริงให้เห็นใน Edit (ไม่เซฟติดไฟล์: เกมสร้างใหม่ตอนเล่น)
		if mods.AnimalSkins then
			local n = 0
			for _, inst in ipairs(game:GetService("CollectionService"):GetTagged("MeshSkin")) do
				if pcall(mods.AnimalSkins.Skin, inst) then
					n += 1
				end
				if n % 200 == 0 then
					task.wait()
				end
			end
			print("[AS] skinned", n)
		end
	end
	setupLighting(mods)
	banner("✅ สร้างแมพเสร็จ — กด Play เพื่อเล่น (แมพจริงจะสุ่มใหม่ทุกเซิร์ฟเวอร์)", Color3.fromRGB(120, 240, 140))
	task.delay(6, function()
		banner(nil)
	end)
	return layout, mods
end

---------------------------------------------------------------- toolbar
local toolbar = plugin:CreateToolbar("Animal Survival")
local bBuild = toolbar:CreateButton("Build Map", "สร้างแมพตัวอย่าง (ดูตอน Edit)", "rbxasset://textures/TerrainTools/mt_generate.png")
local bClear = toolbar:CreateButton("Clear Map", "ลบแมพตัวอย่าง", "rbxasset://textures/TerrainTools/mt_clear.png")
local bLight = toolbar:CreateButton("Cinematic", "ตั้งแสงสวยๆ", "rbxasset://textures/TerrainTools/mt_sea_level.png")
bBuild.ClickableWhenViewportHidden = true

bBuild.Click:Connect(function()
	if not isOurGame() then
		warn("[AS] ไฟล์นี้ไม่ใช่เกม Animal Survival")
		return
	end
	local rec = ChangeHistoryService:TryBeginRecording("AS Build Map")
	buildMap()
	if rec then
		ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end
end)
bClear.Click:Connect(function()
	clearMap()
end)
bLight.Click:Connect(function()
	setupLighting(freshShared())
end)

---------------------------------------------------------------- ถ่ายภาพแมพ (อัตโนมัติ)
local function shot(name, cf, fov)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = fov or 60
	cam.CFrame = cf
	task.wait(3)
	print("[SHOT] " .. name)
	task.wait(2.5)
end

local function runMapShot()
	banner("📸 MapShot: กำลังสร้างแมพ...")
	local layout, mods = buildMap({ Seed = ReplicatedStorage:FindFirstChild("ASSeed") and ReplicatedStorage.ASSeed.Value or nil })
	if not layout then
		print("[AS] MAPSHOT DONE (failed)")
		return
	end
	banner(nil)
	task.wait(3)
	local half = layout.Half
	-- มุมสูงทั้งแมพ (ปิดหมอกชั่วคราว)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local dens = atm and atm.Density
	if atm then
		atm.Density = 0
	end
	Lighting.ClockTime = 13
	shot("overview", CFrame.lookAt(Vector3.new(0, half * 1.55, half * 0.35), Vector3.new(0, 0, 0)), 70)
	if atm then
		atm.Density = dens
	end
	-- แคมป์
	local campY = layout:HeightAt(0, 0)
	Lighting.ClockTime = 16.5
	shot("camp", CFrame.lookAt(Vector3.new(70, campY + 40, 90), Vector3.new(0, campY + 4, 0)), 60)
	-- แต่ละไบโอม
	for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		local s = layout.Sites[el]
		if mods.Atmosphere then
			mods.Atmosphere.ApplyBiome(Lighting, el, 0)
		end
		local dir = Vector3.new(s.X, 0, s.Z).Unit
		local from = Vector3.new(s.X, 0, s.Z) - dir * 520
		local fy = layout:HeightAt(from.X, from.Z)
		local cam = Vector3.new(from.X, math.max(fy, layout.WaterLevel) + 140, from.Z)
		local ty = layout:HeightAt(s.X, s.Z)
		shot("biome_" .. el, CFrame.lookAt(cam, Vector3.new(s.X, ty + 40, s.Z)), 65)
		-- มุมพื้นดิน (ระดับสายตา)
		local gx, gz = s.X - dir.X * 300, s.Z - dir.Z * 300
		local gy = math.max(layout:HeightAt(gx, gz), layout.WaterLevel)
		local tx, tz = gx + dir.X * 160, gz + dir.Z * 160
		local ty = math.max(layout:HeightAt(tx, tz), layout.WaterLevel)
		shot("ground_" .. el, CFrame.lookAt(Vector3.new(gx, gy + 16, gz), Vector3.new(tx, ty + 14, tz)), 70)
	end
	-- แกลเลอรีพร็อพทุกชนิด (ลอยบนฟ้า)
	if mods.PropBuilder then
		local gallery = Instance.new("Folder")
		gallery.Name = "Gallery"
		gallery.Parent = workspace
		local kinds = {}
		for k in pairs(mods.PropBuilder.Kinds) do
			table.insert(kinds, k)
		end
		table.sort(kinds)
		local gy = 900
		local floorPart = Instance.new("Part")
		floorPart.Anchored = true
		floorPart.Size = Vector3.new(280, 2, 120)
		floorPart.CFrame = CFrame.new(100, gy - 1, 20)
		floorPart.Color = Color3.fromRGB(90, 120, 70)
		floorPart.Material = Enum.Material.Grass
		floorPart.Parent = gallery
		for i, k in ipairs(kinds) do
			local col = (i - 1) % 10
			local row = (i - 1) // 10
			local inst = mods.PropBuilder.Place(k, Vector3.new(col * 24 - 4, gy, row * 34), 0.4, 1, gallery, Random.new(i))
			if inst and mods.AnimalSkins then
				pcall(mods.AnimalSkins.Skin, inst)
			end
		end
		if mods.Atmosphere then
			mods.Atmosphere.ApplyBiome(Lighting, "Heart", 0)
		end
		local atm2 = Lighting:FindFirstChildOfClass("Atmosphere")
		local d2 = atm2 and atm2.Density
		if atm2 then
			atm2.Density = 0
		end
		Lighting.ClockTime = 14
		shot("props_gallery", CFrame.lookAt(Vector3.new(100, gy + 70, -90), Vector3.new(100, gy + 6, 34)), 60)
		shot("props_gallery_close", CFrame.lookAt(Vector3.new(40, gy + 22, -36), Vector3.new(60, gy + 8, 20)), 60)
		if atm2 then
			atm2.Density = d2
		end
		mods.PropBuilder.ClearTemplates()
		gallery:Destroy()
	end
	-- ภาพกลางคืน
	if mods.Atmosphere then
		mods.Atmosphere.ApplyBiome(Lighting, "Heart", 1)
	end
	Lighting.ClockTime = 0.5
	shot("camp_night", CFrame.lookAt(Vector3.new(60, campY + 26, 70), Vector3.new(0, campY + 4, 0)), 60)
	print("[AS] MAPSHOT DONE")
end

---------------------------------------------------------------- ถ่ายภาพสัตว์ทุกตัว (อัตโนมัติ)
local function runAnimalShot()
	local mods = freshShared()
	if not (mods and mods.AnimalModels and mods.Animals) then
		print("[AS] ANIMALSHOT DONE (failed)")
		return
	end
	workspace.Terrain:Clear()
	local stage = Instance.new("Folder")
	stage.Name = "AnimalStage"
	stage.Parent = workspace
	local floorPart = Instance.new("Part")
	floorPart.Anchored = true
	floorPart.Size = Vector3.new(600, 2, 300)
	floorPart.CFrame = CFrame.new(0, -1, 0)
	floorPart.Color = Color3.fromRGB(86, 110, 70)
	floorPart.Material = Enum.Material.Grass
	floorPart.Parent = stage
	setupLighting(mods)
	if mods.Atmosphere then
		mods.Atmosphere.ApplyBiome(Lighting, "Heart", 0)
	end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		atm.Density = 0.05
	end
	Lighting.ClockTime = 15
	-- กลุ่มที่ 1: สัตว์ทั่วไป
	local groups = {
		{ "normal", { "Rabbit", "Deer", "MossWolf", "Thornboar", "StoneBear", "ReefCrab", "RiptideCroc" } },
		{ "elemental", { "GaleHawk", "SkyLynx", "StormRam", "EmberFox", "MagmaRhino", "LavaSalamander", "HollowStag" } },
		{ "spirits", { "TerraPup", "TidePup", "GalePup", "EmberPup" } },
		{ "bosses", { "Terragon", "Leviathan", "TempestRoc", "Solfang" } },
	}
	for _, g in ipairs(groups) do
		local name, ids = g[1], g[2]
		local models = {}
		local x = 0
		local maxH = 0
		for _, id in ipairs(ids) do
			local ok, m = pcall(mods.AnimalModels.Build, id, { Tag = false })
			if ok and m then
				m.Parent = stage
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
					end
				end
				if mods.AnimalSkins and m:GetAttribute("MeshSkin") then
					local okSkin, err = pcall(mods.AnimalSkins.Skin, m)
					if not okSkin then
						warn("[AS] skin", id, err)
					end
					for _, d in ipairs(m:GetDescendants()) do
						if d:IsA("BasePart") then
							d.Anchored = true
						end
					end
				end
				local _, size = m:GetBoundingBox()
				x += size.X / 2 + 4
				mods.AnimalModels.PlaceAt(m, Vector3.new(x, 0, 0), math.rad(-35))
				x += size.X / 2 + 4
				maxH = math.max(maxH, size.Y)
				table.insert(models, m)
			else
				warn("[AS] build fail", id, m)
			end
		end
		local cx = x / 2
		local dist = math.max(x * 0.75, maxH * 2.2)
		shot("animals_" .. name, CFrame.lookAt(Vector3.new(cx, maxH * 0.9, -dist), Vector3.new(cx, maxH * 0.35, 0)), 45)
		shot("animals_" .. name .. "_side", CFrame.lookAt(Vector3.new(cx - x * 0.15, maxH * 0.6, -dist * 0.55), Vector3.new(cx - x * 0.15 + dist * 0.2, maxH * 0.3, 0)), 50)
		for _, m in ipairs(models) do
			m:Destroy()
		end
	end
	stage:Destroy()
	print("[AS] ANIMALSHOT DONE")
end

---------------------------------------------------------------- เริ่มอัตโนมัติ
task.defer(function()
	task.wait(2)
	if not isOurGame() then
		return
	end
	setupLighting(nil)
	if ServerStorage:FindFirstChild("ASMapShot") then
		runMapShot()
		return
	end
	if ServerStorage:FindFirstChild("ASAnimalShot") then
		runAnimalShot()
		return
	end
	if ReplicatedStorage:FindFirstChild("ASAutoTest") then
		task.wait(3)
		print("[AS] เริ่มเทสต์อัตโนมัติ...")
		local ok, result = pcall(function()
			return game:GetService("StudioTestService"):ExecutePlayModeAsync({ Mode = "ASAutoTest" })
		end)
		print("[AS] เทสต์จบ:", ok, result)
	end
end)
