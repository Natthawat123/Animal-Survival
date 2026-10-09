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
		runFetch(ids)
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
