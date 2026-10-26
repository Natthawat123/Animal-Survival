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

---------------------------------------------------------------- ดึงโมเดลฟรีจาก Creator Store (ใช้สิทธิ์ของ Studio ที่ล็อกอินอยู่)
-- ServerStorage.ASFetch (StringValue "id,id,...") -> โหลดแต่ละโมเดล ถ่ายภาพ ([SHOT] fetch_<id>) แล้วพิมพ์โครงสร้างเป็น JSON
--   [FETCH] <id> <ลำดับ>/<ทั้งหมด> <ข้อความ JSON ทีละท่อน>   (tools/fetch_models.py ประกอบกลับเป็นไฟล์ข้อมูล)
local HttpService = game:GetService("HttpService")
local visibleBounds

local function num(x, k)
	if x ~= x or x == math.huge or x == -math.huge then
		return 0
	end
	return math.floor(x * k + 0.5) / k
end

local function v3(v)
	return { num(v.X, 1000), num(v.Y, 1000), num(v.Z, 1000) }
end

local function cfr(cf)
	local t = { cf:GetComponents() }
	for i, x in ipairs(t) do
		t[i] = num(x, 10000)
	end
	return t
end

local function serialize(model)
	local pivot = model:IsA("Model") and model:GetPivot() or CFrame.new()
	local inv = pivot:Inverse()
	local list, index = {}, {}
	local items = { model }
	for _, d in ipairs(model:GetDescendants()) do
		table.insert(items, d)
	end
	for _, d in ipairs(items) do
		index[d] = #list + 1
		local e = { C = d.ClassName, N = d.Name }
		table.insert(list, e)
	end
	for i, d in ipairs(items) do
		local e = list[i]
		e.P = d.Parent and index[d.Parent] or 0
		pcall(function()
			if d:IsA("BasePart") then
				e.Size = v3(d.Size)
				e.CF = cfr(inv * d.CFrame)
				e.Color = v3(Vector3.new(d.Color.R, d.Color.G, d.Color.B))
				e.Mat = d.Material.Name
				e.Tr = d.Transparency
				e.Refl = d.Reflectance
				e.Collide = d.CanCollide
				if d:IsA("Part") then
					e.Shape = d.Shape.Name
				end
			end
			if d:IsA("MeshPart") then
				e.MeshId = d.MeshId
				e.TextureID = d.TextureID
				pcall(function()
					e.MeshSize = v3(d.MeshSize)
				end)
				e.DoubleSided = d.DoubleSided
			elseif d:IsA("SpecialMesh") then
				e.MeshId = d.MeshId
				e.TextureId = d.TextureId
				e.Scale = v3(d.Scale)
				e.Offset = v3(d.Offset)
				e.MeshType = d.MeshType.Name
				e.VertexColor = v3(d.VertexColor)
			elseif d:IsA("SurfaceAppearance") then
				e.ColorMap = d.ColorMap
				e.NormalMap = d.NormalMap
				e.Alpha = d.AlphaMode.Name
			elseif d:IsA("Decal") then
				e.Texture = d.Texture
				e.Face = d.Face.Name
			elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
				-- เก็บค่าเอฟเฟกต์ทั้งหมด (เอาไปทำ VFX ของบอส)
				local function ns(x)
					local out = {}
					for _, k in ipairs(x.Keypoints) do
						table.insert(out, { num(k.Time, 1000), num(k.Value, 1000), num(k.Envelope, 1000) })
					end
					return out
				end
				local function cs(x)
					local out = {}
					for _, k in ipairs(x.Keypoints) do
						table.insert(out, { num(k.Time, 1000), num(k.Value.R, 1000), num(k.Value.G, 1000), num(k.Value.B, 1000) })
					end
					return out
				end
				local function nr(x)
					return { num(x.Min, 1000), num(x.Max, 1000) }
				end
				e.Texture = d.Texture
				e.ColorSeq = cs(d.Color)
				e.TransparencySeq = ns(d.Transparency)
				e.LightEmission = d.LightEmission
				e.LightInfluence = d.LightInfluence
				pcall(function()
					e.Brightness = d.Brightness
				end)
				e.ZOffset = d.ZOffset
				e.Enabled = d.Enabled
				if d:IsA("ParticleEmitter") then
					e.SizeSeq = ns(d.Size)
					e.Lifetime = nr(d.Lifetime)
					e.Speed = nr(d.Speed)
					e.Rate = d.Rate
					e.Spread = { d.SpreadAngle.X, d.SpreadAngle.Y }
					e.Rotation = nr(d.Rotation)
					e.RotSpeed = nr(d.RotSpeed)
					e.Accel = v3(d.Acceleration)
					e.Drag = d.Drag
					e.EmissionDirection = d.EmissionDirection.Name
					e.Shape = d.Shape.Name
					e.ShapeStyle = d.ShapeStyle.Name
					e.ShapeInOut = d.ShapeInOut.Name
					e.ShapePartial = d.ShapePartial
					e.SquashSeq = ns(d.Squash)
					e.Orientation = d.Orientation.Name
					e.LockedToPart = d.LockedToPart
					e.VelocityInheritance = d.VelocityInheritance
					e.TimeScale = d.TimeScale
					e.FlipbookLayout = d.FlipbookLayout.Name
					e.FlipbookMode = d.FlipbookMode.Name
					e.FlipbookFramerate = nr(d.FlipbookFramerate)
					e.FlipbookStartRandom = d.FlipbookStartRandom
					pcall(function()
						e.EmitCount = d:GetAttribute("EmitCount")
					end)
				elseif d:IsA("Beam") then
					e.A0 = d.Attachment0 and index[d.Attachment0] or 0
					e.A1 = d.Attachment1 and index[d.Attachment1] or 0
					e.TextureMode = d.TextureMode.Name
					e.TextureLength = d.TextureLength
					e.TextureSpeed = d.TextureSpeed
					e.Width0, e.Width1 = d.Width0, d.Width1
					e.Curve0, e.Curve1 = d.CurveSize0, d.CurveSize1
					e.Segments = d.Segments
					e.FaceCamera = d.FaceCamera
				else
					e.TrailLifetime = d.Lifetime
					e.WidthScale = ns(d.WidthScale)
					e.FaceCamera = d.FaceCamera
				end
			elseif d:IsA("Bone") or d:IsA("Attachment") then
				e.CF = cfr(d.CFrame)
			elseif d:IsA("JointInstance") then
				e.P0 = d.Part0 and index[d.Part0] or 0
				e.P1 = d.Part1 and index[d.Part1] or 0
				e.C0 = cfr(d.C0)
				e.C1 = cfr(d.C1)
			elseif d:IsA("WeldConstraint") then
				e.P0 = d.Part0 and index[d.Part0] or 0
				e.P1 = d.Part1 and index[d.Part1] or 0
			elseif d:IsA("Animation") then
				e.AnimationId = d.AnimationId
			elseif d:IsA("Shirt") then
				e.Template = d.ShirtTemplate
			elseif d:IsA("Pants") then
				e.Template = d.PantsTemplate
			elseif d:IsA("ShirtGraphic") then
				e.Template = d.Graphic
			elseif d:IsA("BodyColors") then
				e.Colors = {
					v3(Vector3.new(d.HeadColor3.R, d.HeadColor3.G, d.HeadColor3.B)), v3(Vector3.new(d.TorsoColor3.R, d.TorsoColor3.G, d.TorsoColor3.B)),
					v3(Vector3.new(d.LeftArmColor3.R, d.LeftArmColor3.G, d.LeftArmColor3.B)), v3(Vector3.new(d.RightArmColor3.R, d.RightArmColor3.G, d.RightArmColor3.B)),
					v3(Vector3.new(d.LeftLegColor3.R, d.LeftLegColor3.G, d.LeftLegColor3.B)), v3(Vector3.new(d.RightLegColor3.R, d.RightLegColor3.G, d.RightLegColor3.B)),
				}
			elseif d:IsA("CharacterMesh") then
				e.MeshId = d.MeshId
				e.BaseTextureId = d.BaseTextureId
				e.OverlayTextureId = d.OverlayTextureId
				e.BodyPart = d.BodyPart.Name
			end
		end)
	end
	return list
end

-- ขอบเขตเฉพาะชิ้นที่มองเห็น (ไม่นับ HumanoidRootPart/hitbox ล่องหน)
visibleBounds = function(model)
	local mn, mx
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "HumanoidRootPart" then
			local c, h = d.Position, d.Size / 2
			local r = d.CFrame
			local e = Vector3.new(
				math.abs(r.RightVector.X) * h.X + math.abs(r.UpVector.X) * h.Y + math.abs(r.LookVector.X) * h.Z,
				math.abs(r.RightVector.Y) * h.X + math.abs(r.UpVector.Y) * h.Y + math.abs(r.LookVector.Y) * h.Z,
				math.abs(r.RightVector.Z) * h.X + math.abs(r.UpVector.Z) * h.Y + math.abs(r.LookVector.Z) * h.Z)
			mn = mn and mn:Min(c - e) or c - e
			mx = mx and mx:Max(c + e) or c + e
		end
	end
	if not mn then
		return model:GetBoundingBox()
	end
	return CFrame.new((mn + mx) / 2), mx - mn
end

local function runFetch(ids)
	local stage = Instance.new("Folder")
	stage.Name = "FetchStage"
	stage.Parent = workspace
	local floorPart = Instance.new("Part")
	floorPart.Anchored = true
	floorPart.Size = Vector3.new(400, 1, 400)
	floorPart.CFrame = CFrame.new(0, -0.5, 0)
	floorPart.Color = Color3.fromRGB(70, 74, 80)
	floorPart.Parent = stage
	Lighting.ClockTime = 14
	for _, id in ipairs(ids) do
		local ok, objs = pcall(function()
			return game:GetObjects("rbxassetid://" .. id)
		end)
		if not ok or not objs or #objs == 0 then
			print("[FETCH] " .. id .. " ERROR " .. tostring(objs))
			continue
		end
		local root = objs[1]
		if #objs > 1 or not root:IsA("Model") then
			local m = Instance.new("Model")
			m.Name = "Fetched"
			for _, o in ipairs(objs) do
				o.Parent = m
			end
			root = m
		end
		-- ลบสคริปต์ทั้งหมด (ไม่รันของคนอื่น)
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		root.Parent = stage
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local cf, size = visibleBounds(root)
		root:PivotTo(CFrame.new(-cf.Position + Vector3.new(0, size.Y / 2, 0)) * root:GetPivot())
		local data = serialize(root)
		for _, e in ipairs(data) do
			for k, v in pairs(e) do
				if type(v) == "number" then
					e[k] = num(v, 10000)
				end
			end
		end
		local okJ, json = pcall(HttpService.JSONEncode, HttpService, { Id = id, Name = root.Name, Size = v3(size), Items = data })
		if not okJ then
			print("[FETCH] " .. id .. " ERROR json " .. tostring(json))
			json = "{}"
		end
		local n = math.ceil(#json / 800)
		for k = 1, n do
			print(string.format("[FETCH] %s %d/%d %s", id, k, n, json:sub((k - 1) * 800 + 1, k * 800)))
		end
		local r = math.max(size.X, size.Y, size.Z)
		shot("fetch_" .. id, CFrame.lookAt(Vector3.new(r * 0.9, size.Y * 0.75 + r * 0.25, -r * 1.25), Vector3.new(0, size.Y * 0.45, 0)), 45)
		root:Destroy()
	end
	stage:Destroy()
	print("[AS] FETCH DONE")
end

-- ASFetch = "check:id,id" -> เช็กอย่างเดียว (ไม่ถ่ายภาพ): ดึงได้ไหม + นับชิ้น/Union/สัตว์เลี้ยง
--   [CHECK] <id> OK <parts> <meshparts> <unions> <humanoids> <x> <y> <z>   หรือ   [CHECK] <id> ERROR
local function runCheck(ids)
	for _, id in ipairs(ids) do
		-- บางโมเดลโหลดค้างไม่จบ -> รอสูงสุด 15 วินาทีแล้วข้าม
		local ok, objs, done = false, nil, false
		task.spawn(function()
			ok, objs = pcall(function()
				return game:GetObjects("rbxassetid://" .. id)
			end)
			done = true
		end)
		local t0 = os.clock()
		while not done and os.clock() - t0 < 15 do
			task.wait(0.1)
		end
		if not done then
			ok, objs = false, "timeout"
		end
		if not ok or not objs or #objs == 0 then
			print("[CHECK] " .. id .. " ERROR")
			continue
		end
		local m = Instance.new("Model")
		for _, o in ipairs(objs) do
			o.Parent = m
		end
		local parts, meshes, unions, hums = 0, 0, 0, 0
		for i, d in ipairs(m:GetDescendants()) do
			if i % 2000 == 0 then
				task.wait() -- โมเดลยักษ์ (ปราสาทหลายหมื่นชิ้น) -> พักกัน Script timeout
			end
			if d:IsA("UnionOperation") then
				unions += 1
			elseif d:IsA("MeshPart") then
				meshes += 1
			elseif d:IsA("BasePart") then
				parts += 1
			elseif d:IsA("Humanoid") or d:IsA("AnimationController") then
				hums += 1
			end
		end
		local size = Vector3.zero
		pcall(function()
			local _, sz = m:GetBoundingBox()
			size = sz
		end)
		print(string.format("[CHECK] %s OK %d %d %d %d %.2f %.2f %.2f", id, parts, meshes, unions, hums, size.X, size.Y, size.Z))
		m:Destroy()
	end
	print("[AS] FETCH DONE")
end

-- ถ่ายภาพโมเดลทุกตัวใน ReplicatedStorage.Assets.Creatures / Characters (เช็กว่าแปลงมาแล้วแสดงผลถูก)
local function runProbe()
	local stage = Instance.new("Folder")
	stage.Name = "ProbeStage"
	stage.Parent = workspace
	local floorPart = Instance.new("Part")
	floorPart.Anchored = true
	floorPart.Size = Vector3.new(2000, 1, 2000)
	floorPart.CFrame = CFrame.new(0, -0.5, 0)
	floorPart.Color = Color3.fromRGB(70, 90, 64)
	floorPart.Material = Enum.Material.Grass
	floorPart.Parent = stage
	Lighting.ClockTime = 14
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	for _, folderName in ipairs({ "Creatures", "Characters" }) do
		local folder = assets and assets:FindFirstChild(folderName)
		for _, src in ipairs(folder and folder:GetChildren() or {}) do
			local m = src:Clone()
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			m.Parent = stage
			local cf, size = visibleBounds(m)
			m:PivotTo(CFrame.new(-cf.Position + Vector3.new(0, size.Y / 2, 0)) * m:GetPivot())
			local r = math.max(size.X, size.Y, size.Z)
			print(string.format("[PROBE] %s size=%.1f,%.1f,%.1f parts=%d", src.Name, size.X, size.Y, size.Z, #m:GetDescendants()))
			shot("probe_" .. src.Name, CFrame.lookAt(Vector3.new(r * 0.75, size.Y * 0.6 + r * 0.2, -r * 0.95), Vector3.new(0, size.Y * 0.45, 0)), 40)
			m:Destroy()
		end
	end
	stage:Destroy()
	print("[AS] FETCH DONE")
end

-- อ่านลายพื้นผิว (TextureID) ทีละรูปแล้วพิมพ์ออก log แบบย่อ 256x256 (hex RGB) -> tools ประกอบเป็น PNG ไว้ตรวจ
function runTexDump(ids)
	local AssetService = game:GetService("AssetService")
	local N = 256
	for _, id in ipairs(ids) do
		local ok, img = pcall(function()
			return AssetService:CreateEditableImageAsync(Content.fromUri("rbxassetid://" .. id))
		end)
		if not ok or not img then
			print("[TEX] " .. id .. " ERROR " .. tostring(img))
			continue
		end
		local w, h = img.Size.X, img.Size.Y
		local buf = img:ReadPixelsBuffer(Vector2.zero, img.Size)
		local hex = table.create(N * N)
		for y = 0, N - 1 do
			local sy = math.floor((y + 0.5) * h / N)
			for x = 0, N - 1 do
				local sx = math.floor((x + 0.5) * w / N)
				local o = (sy * w + sx) * 4
				hex[y * N + x + 1] = string.format("%02x%02x%02x", buffer.readu8(buf, o), buffer.readu8(buf, o + 1), buffer.readu8(buf, o + 2))
			end
			if y % 32 == 0 then
				task.wait()
			end
		end
		local all = table.concat(hex)
		local CH = 900 -- log ตัดบรรทัดที่ ~1000 ตัวอักษร
		local n = math.ceil(#all / CH)
		print(string.format("[TEX] %s SIZE %d %d", id, w, h))
		for k = 1, n do
			print(string.format("[TEXD] %s %d/%d %s", id, k, n, string.sub(all, (k - 1) * CH + 1, k * CH)))
			if k % 20 == 0 then
				task.wait()
			end
		end
		img:Destroy()
	end
	print("[AS] FETCH DONE")
end

-- ซ่อมลายพื้นผิวโมเดลตัวละคร AI (ทำใน Studio ผ่าน EditableMesh/EditableImage)
--   1) จุดด่าง: กลุ่มหน้าโมเดลสีเดียวกันที่เล็กและสีต่างจากผิวรอบข้างมาก (เช่นด่างขาวบนกางเกงดำ) -> ทาสีรอบข้างทับ (เว้นหัว)
--   2) รอยต่อ UV: เติมสีเกาะ UV ออกไปในช่องว่างรอบเกาะ กันสีเกาะข้างๆ ซึมตอนย่อภาพ
--   entries = { { Name, MeshId, TexId } } · upload = true -> อัปโหลดรูปที่ซ่อมแล้วขึ้นบัญชี (พิมพ์ [TEXNEW] Name texId newId)
function runTexClean(entries, upload)
	local AssetService = game:GetService("AssetService")
	local stage = Instance.new("Folder")
	stage.Name = "TexCleanStage"
	stage.Parent = workspace
	local floorPart = Instance.new("Part")
	floorPart.Anchored = true
	floorPart.Size = Vector3.new(400, 1, 400)
	floorPart.CFrame = CFrame.new(0, -0.5, 0)
	floorPart.Color = Color3.fromRGB(90, 110, 90)
	floorPart.Parent = stage
	Lighting.ClockTime = 14
	for _, e in ipairs(entries) do
		local name, meshId, texId = e[1], e[2], e[3]
		local okM, mesh = pcall(function()
			return AssetService:CreateEditableMeshAsync(Content.fromUri("rbxassetid://" .. meshId))
		end)
		local okI, img = pcall(function()
			return AssetService:CreateEditableImageAsync(Content.fromUri("rbxassetid://" .. texId))
		end)
		if not okM or not okI or not mesh or not img then
			print("[TEXC] " .. name .. " ERROR " .. tostring(mesh) .. " | " .. tostring(img))
			continue
		end
		local W, H = img.Size.X, img.Size.Y
		local buf = img:ReadPixelsBuffer(Vector2.zero, img.Size)
		-- ---- อ่านหน้าโมเดล
		local faces = mesh:GetFaces()
		local F = #faces
		local fv, fuv = table.create(F), table.create(F)
		local keyOf, nKey = {}, 0
		local vkey = {}
		local minY, maxY = math.huge, -math.huge
		local fy = table.create(F)
		local farea = table.create(F)
		for i, f in ipairs(faces) do
			local vs = mesh:GetFaceVertices(f)
			local us = mesh:GetFaceUVs(f)
			local ks, ps = {}, {}
			for j = 1, 3 do
				local vid = vs[j]
				local k = vkey[vid]
				local p = mesh:GetPosition(vid)
				if not k then
					local s = string.format("%.4f,%.4f,%.4f", p.X, p.Y, p.Z) -- เชื่อมจุดซ้ำตรงรอยต่อ UV ด้วยตำแหน่ง
					k = keyOf[s]
					if not k then
						nKey += 1
						k = nKey
						keyOf[s] = k
					end
					vkey[vid] = k
				end
				ks[j] = k
				ps[j] = p
			end
			fv[i] = ks
			fuv[i] = { mesh:GetUV(us[1]), mesh:GetUV(us[2]), mesh:GetUV(us[3]) }
			local cy = (ps[1].Y + ps[2].Y + ps[3].Y) / 3
			fy[i] = cy
			minY, maxY = math.min(minY, cy), math.max(maxY, cy)
			farea[i] = (ps[2] - ps[1]):Cross(ps[3] - ps[1]).Magnitude / 2
			if i % 4000 == 0 then
				task.wait()
			end
		end
		local vf = {}
		for i = 1, F do
			for j = 1, 3 do
				local k = fv[i][j]
				local t = vf[k]
				if not t then
					t = {}
					vf[k] = t
				end
				table.insert(t, i)
			end
		end
		local function neighbors(i)
			local out, seen = {}, { [i] = true }
			for j = 1, 3 do
				for _, n in ipairs(vf[fv[i][j]]) do
					if not seen[n] then
						seen[n] = true
						table.insert(out, n)
					end
				end
			end
			return out
		end
		local nb = table.create(F)
		for i = 1, F do
			nb[i] = neighbors(i)
			if i % 4000 == 0 then
				task.wait()
			end
		end
		-- ---- สีของแต่ละหน้า (ลองทั้ง UV แบบกลับแกน V/ไม่กลับ เลือกแบบที่สีหน้าข้างเคียงเข้ากันกว่า)
		local function readPx(x, y)
			local o = (y * W + x) * 4
			return buffer.readu8(buf, o), buffer.readu8(buf, o + 1), buffer.readu8(buf, o + 2)
		end
		local function faceColors(flip)
			local cols = table.create(F)
			for i = 1, F do
				local u = fuv[i]
				local r, g, b = 0, 0, 0
				local c = (u[1] + u[2] + u[3]) / 3
				for _, q in ipairs({ c, c:Lerp(u[1], 0.5), c:Lerp(u[2], 0.5), c:Lerp(u[3], 0.5) }) do
					local x = math.clamp(math.floor(q.X * W), 0, W - 1)
					local y = math.clamp(math.floor((flip and (1 - q.Y) or q.Y) * H), 0, H - 1)
					local rr, gg, bb = readPx(x, y)
					r, g, b = r + rr, g + gg, b + bb
				end
				cols[i] = { r / 4, g / 4, b / 4 }
			end
			return cols
		end
		local function dist(a, b)
			return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
		end
		local function smooth(cols)
			local s, n = 0, 0
			for i = 1, F, 7 do
				for _, j in ipairs(nb[i]) do
					s += dist(cols[i], cols[j])
					n += 1
				end
			end
			return s / math.max(n, 1)
		end
		local cA, cB = faceColors(false), faceColors(true)
		local sA, sB = smooth(cA), smooth(cB)
		local flip = sB < sA
		local col = flip and cB or cA
		print(string.format("[TEXC] %s faces=%d verts=%d flip=%s smooth %.1f/%.1f", name, F, nKey, tostring(flip), sA, sB))
		task.wait()
		-- ---- กลุ่มสีเดียวกัน (ต่อกันบนผิวโมเดล)
		local comp = table.create(F, 0)
		local comps = {}
		for i = 1, F do
			if comp[i] == 0 then
				local id = #comps + 1
				local list, area = { i }, 0
				comp[i] = id
				local qi = 1
				while qi <= #list do
					local a = list[qi]
					qi += 1
					area += farea[a]
					for _, n in ipairs(nb[a]) do
						if comp[n] == 0 and dist(col[a], col[n]) < 38 then
							comp[n] = id
							table.insert(list, n)
						end
					end
				end
				comps[id] = { Faces = list, Area = area }
			end
			if i % 4000 == 0 then
				task.wait()
			end
		end
		local total = 0
		for i = 1, F do
			total += farea[i]
		end
		local headY = minY + (maxY - minY) * 0.80 -- หัว/หน้า (บนสุด 20%) ไม่แตะ
		-- ---- ทาสีทับจุดด่าง
		local fixColor = {}
		local nFix = 0
		for id, c in ipairs(comps) do
			if c.Area < total * 0.012 then
				local inHead = false
				local mean = { 0, 0, 0 }
				for _, f in ipairs(c.Faces) do
					if fy[f] > headY then
						inHead = true
					end
					mean = { mean[1] + col[f][1], mean[2] + col[f][2], mean[3] + col[f][3] }
				end
				if not inHead then
					local k = #c.Faces
					mean = { mean[1] / k, mean[2] / k, mean[3] / k }
					-- สีขอบรอบกลุ่ม (ถ่วงด้วยพื้นที่)
					local br, bg, bb, bw = 0, 0, 0, 0
					for _, f in ipairs(c.Faces) do
						for _, n in ipairs(nb[f]) do
							if comp[n] ~= id then
								local w = farea[n]
								br, bg, bb, bw = br + col[n][1] * w, bg + col[n][2] * w, bb + col[n][3] * w, bw + w
							end
						end
					end
					if bw > 0 then
						local edge = { br / bw, bg / bw, bb / bw }
						if dist(mean, edge) > 70 then
							for _, f in ipairs(c.Faces) do
								fixColor[f] = edge
							end
							nFix += k
						end
					end
				end
			end
		end
		-- ---- วาดลงรูป: หน้าที่ซ่อม = ทาสีขอบ · แผนที่ว่าพิกเซลไหนมีหน้าโมเดลทับ (ไว้เติมรอยต่อ)
		local cover = buffer.create(W * H)
		local function raster(i, fill)
			local u = fuv[i]
			local p = table.create(3)
			for j = 1, 3 do
				p[j] = Vector2.new(u[j].X * W, (flip and (1 - u[j].Y) or u[j].Y) * H)
			end
			local x0 = math.max(0, math.floor(math.min(p[1].X, p[2].X, p[3].X) - 1))
			local x1 = math.min(W - 1, math.ceil(math.max(p[1].X, p[2].X, p[3].X) + 1))
			local y0 = math.max(0, math.floor(math.min(p[1].Y, p[2].Y, p[3].Y) - 1))
			local y1 = math.min(H - 1, math.ceil(math.max(p[1].Y, p[2].Y, p[3].Y) + 1))
			local d = (p[2].Y - p[3].Y) * (p[1].X - p[3].X) + (p[3].X - p[2].X) * (p[1].Y - p[3].Y)
			if math.abs(d) < 1e-9 then
				return
			end
			for y = y0, y1 do
				for x = x0, x1 do
					local px, py = x + 0.5, y + 0.5
					local a = ((p[2].Y - p[3].Y) * (px - p[3].X) + (p[3].X - p[2].X) * (py - p[3].Y)) / d
					local b = ((p[3].Y - p[1].Y) * (px - p[3].X) + (p[1].X - p[3].X) * (py - p[3].Y)) / d
					local g = 1 - a - b
					if a > -0.08 and b > -0.08 and g > -0.08 then
						buffer.writeu8(cover, y * W + x, 1)
						if fill then
							local o = (y * W + x) * 4
							buffer.writeu8(buf, o, math.floor(fill[1]))
							buffer.writeu8(buf, o + 1, math.floor(fill[2]))
							buffer.writeu8(buf, o + 2, math.floor(fill[3]))
						end
					end
				end
			end
		end
		for i = 1, F do
			raster(i, fixColor[i])
			if i % 1500 == 0 then
				task.wait()
			end
		end
		-- ---- เติมรอยต่อ: พิกเซลว่าง (ไม่มีหน้าโมเดล) รับสีจากพิกเซลข้างๆ ที่มีแล้ว 6 รอบ
		local filled = 0
		for _ = 1, 6 do
			local add = {}
			for y = 0, H - 1 do
				for x = 0, W - 1 do
					if buffer.readu8(cover, y * W + x) == 0 then
						for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
							local nx, ny = x + o[1], y + o[2]
							if nx >= 0 and nx < W and ny >= 0 and ny < H and buffer.readu8(cover, ny * W + nx) == 1 then
								table.insert(add, { y * W + x, ny * W + nx })
								break
							end
						end
					end
				end
				if y % 64 == 0 then
					task.wait()
				end
			end
			for _, a in ipairs(add) do
				local o, s = a[1] * 4, a[2] * 4
				buffer.writeu8(buf, o, buffer.readu8(buf, s))
				buffer.writeu8(buf, o + 1, buffer.readu8(buf, s + 1))
				buffer.writeu8(buf, o + 2, buffer.readu8(buf, s + 2))
				buffer.writeu8(cover, a[1], 1)
			end
			filled += #add
		end
		img:WritePixelsBuffer(Vector2.zero, img.Size, buf)
		print(string.format("[TEXC] %s fixed faces=%d (%.1f%%) seam px=%d", name, nFix, nFix / F * 100, filled))
		-- ---- ภาพเทียบ ก่อน (ซ้าย) / หลัง (ขวา)
		local chars = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Characters")
		local src = chars and chars:FindFirstChild(name)
		if src then
			local models = {}
			-- ซ้าย = ของเดิม · กลาง = ลายเดิมผ่าน EditableImage (ไม่แก้) · ขวา = ซ่อมแล้ว
			local raw = AssetService:CreateEditableImageAsync(Content.fromUri("rbxassetid://" .. texId))
			for side = -1, 1 do
				local m = src:Clone()
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
						if d:IsA("MeshPart") and side ~= -1 then
							d.TextureContent = Content.fromObject(side == 1 and img or raw)
						end
					end
				end
				local bcf, size = m:GetBoundingBox()
				m:PivotTo(m:GetPivot() + (Vector3.new(side * size.X * 1.3, size.Y / 2, 0) - bcf.Position))
				m.Parent = stage
				table.insert(models, { m, size })
			end
			local size = models[1][2]
			shot("texclean_" .. name, CFrame.lookAt(Vector3.new(0, size.Y * 0.6, -size.Y * 2.6), Vector3.new(0, size.Y * 0.5, 0)), 40)
			shot("texcleanfar_" .. name, CFrame.lookAt(Vector3.new(0, size.Y * 0.6, -size.Y * 14), Vector3.new(0, size.Y * 0.5, 0)), 40) -- ไกล = ตัวเล็กแบบรูปวงกลมในร้าน
			for _, mm in ipairs(models) do
				mm[1]:Destroy()
			end
		end
		if upload then
			local ok, res, newId = pcall(function()
				return AssetService:CreateAssetAsync(img, Enum.AssetType.Image, { Name = "AS_" .. name .. "_skin", Description = "Animal Survival class skin (cleaned)" })
			end)
			print(string.format("[TEXNEW] %s %s %s %s %s", name, texId, tostring(ok), tostring(res), tostring(newId)))
		end
	end
	stage:Destroy()
	print("[AS] FETCH DONE")
end

-- เมชจาก Creator Store ที่แปลงผ่านไฟล์ไม่มีข้อมูลรูปทรงชน (ชนเป็นกล่อง/ทะลุ) -> สั่ง Studio คำนวณใหม่ตามรูปจริง
-- (อาคารใหญ่ = ละเอียดเดินเข้าข้างในได้) ค่าที่คำนวณแล้วติดไปกับไฟล์ตอนเซฟ/Publish
local function rebuildMeshCollisions()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	if not props then
		return
	end
	local n = 0
	for _, d in ipairs(props:GetDescendants()) do
		if d:IsA("MeshPart") then
			-- ชิ้นเล็กในไฟล์ก็อาจถูกขยายเป็นร้อยเท่าในเกม (เช่น FireThrone ชิ้นละ ~2 stud) -> ใช้แบบละเอียดทุกชิ้น
			-- (Hull = กล่องนูนครอบทั้งชิ้น -> เดินลอย/ชนกำแพงล่องหน)
			local want = Enum.CollisionFidelity.PreciseConvexDecomposition
			pcall(function()
				d.CollisionFidelity = Enum.CollisionFidelity.Box
				d.CollisionFidelity = want
			end)
			n += 1
			if n % 40 == 0 then
				task.wait()
			end
		end
	end
	print("[AS] rebuilt mesh collisions: " .. n)
end

---------------------------------------------------------------- เริ่มอัตโนมัติ
task.defer(function()
	task.wait(2)
	if not isOurGame() then
		return
	end
	rebuildMeshCollisions()
	setupLighting(nil)
	if ServerStorage:FindFirstChild("ASMapShot") then
		runMapShot()
		return
	end
	if ServerStorage:FindFirstChild("ASAnimalShot") then
		runAnimalShot()
		return
	end
	if ServerStorage:FindFirstChild("ASProbe") then
		runProbe()
		return
	end
	local fetch = ServerStorage:FindFirstChild("ASFetch")
	if fetch then
		local ids = {}
		for id in string.gmatch(fetch.Value, "%d+") do
			table.insert(ids, id)
		end
		if string.sub(fetch.Value, 1, 5) == "clean" then
			-- clean:Name:mesh:tex,... (ซ่อมแล้วถ่ายภาพเทียบ) · cleanup:... (ซ่อม + อัปโหลด)
			local entries = {}
			for n, mid, tid in string.gmatch(fetch.Value, "(%a+):(%d+):(%d+)") do
				table.insert(entries, { n, mid, tid })
			end
			runTexClean(entries, string.sub(fetch.Value, 1, 8) == "cleanup:")
		elseif string.sub(fetch.Value, 1, 4) == "tex:" then
			runTexDump(ids)
		elseif string.sub(fetch.Value, 1, 6) == "check:" then
			runCheck(ids)
		else
			runFetch(ids)
		end
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
