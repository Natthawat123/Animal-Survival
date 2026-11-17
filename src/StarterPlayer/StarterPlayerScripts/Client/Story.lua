--[[
	Story — ฉากเปิดเรื่องตอนเข้าเกมครั้งแรก (แอนิเมชันเต็มจอ ใช้โมเดลจริงในเกมใน ViewportFrame)
	  เนื้อเรื่อง: ทีมนักสำรวจทดลองเครื่องข้ามเวลา -> ประตูมิติพัง พาย้อนไปยุคโบราณ
	    -> ต้องรอดจากจิ้งจอกเงา (Moonfang) · ช่วยลูกสัตว์วิญญาณ 4 ธาตุ · ผจญภัย 4 ไบโอม ศาลเจ้า วิหาร บอส
	    -> รอด 99 คืน ประตูกลับบ้านเปิด (ตรงกับฉากจบ EscapeService / Cinematics.Escape)
	  7 ฉาก ฉากละ ~5 วิ: กล้องเคลื่อน + คำบรรยายพิมพ์ทีละตัว · ข้ามได้ (ปุ่ม Skip / Esc) · ดูซ้ำได้จากหน้าตั้งค่า
	Story.Play(onDone) · Story.IsPlaying()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent.UIKit)
local ClassAvatars = require(script.Parent.ClassAvatars)

local Story = {}
local C = UIKit.Colors
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

---------------------------------------------------------------- ของในฉาก
local world -- WorldModel ของฉากปัจจุบัน

local function asset(folder, name)
	local a = ReplicatedStorage:FindFirstChild("Assets")
	local f = a and a:FindFirstChild(folder)
	local src = f and f:FindFirstChild(name)
	if not src then
		return nil
	end
	local m = src:Clone()
	if m:IsA("BasePart") then
		local wrap = Instance.new("Model")
		m.Parent = wrap
		wrap.PrimaryPart = m
		m = wrap
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("Light") then
			d:Destroy()
		end
	end
	return m
end

-- ย่อ/ขยายให้สูงตามต้องการ แล้ววางเท้าที่ cf
local function place(m, height, cf)
	if not m then
		return nil
	end
	m.Parent = world
	local _, size = m:GetBoundingBox()
	if size.Y > 0.05 and height then
		pcall(function()
			m:ScaleTo(m:GetScale() * height / size.Y)
		end)
	end
	local bcf, bsize = m:GetBoundingBox()
	local pivot = m:GetPivot()
	local footOffset = pivot.Position.Y - (bcf.Position.Y - bsize.Y / 2)
	local centerOffset = pivot.Position - bcf.Position
	m:PivotTo(cf * CF(centerOffset.X, footOffset, centerOffset.Z) * (pivot - pivot.Position))
	return m
end

local function hero(classId, cf)
	local ok, m = pcall(ClassAvatars.Build, classId)
	if ok and m then
		m.Parent = world
		m:PivotTo(cf) -- จุดหมุนอยู่ที่เท้า (ClassAvatars)
		return m
	end
	return nil
end

local function part(size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = world
	return p
end

local function ground(color, material)
	return part(V(240, 1, 240), CF(0, -0.5, 0), color, material or Enum.Material.Grass)
end

-- กองไฟ (โมเดลจริง + เปลวไฟ Neon เพราะ ViewportFrame ไม่วาดแสงไฟ/อนุภาค)
local function campfire(cf)
	place(asset("Props", "CampfireLogs"), 3.4, cf)
	local flames = {}
	for i = 1, 3 do
		local f = part(V(1.4, 2.6, 1.4) * (1 - i * 0.18), cf * CF(0, 1.6 + i * 0.5, 0) * ANG(0, i, 0.15), i == 1 and rgb(255, 150, 40) or rgb(255, 210, 90), Enum.Material.Neon)
		f.Shape = Enum.PartType.Ball
		table.insert(flames, f)
	end
	return flames
end

-- แผ่นวงวนของประตูมิติ (หมุน/เปลี่ยนสีได้)
local function portalDisc(cf, radius, color)
	local disc = part(V(0.4, radius * 2, radius * 2), cf * ANG(0, math.pi / 2, 0), color, Enum.Material.Neon, Enum.PartType.Cylinder)
	disc.Transparency = 0.15
	local ring = part(V(0.5, radius * 1.3, radius * 1.3), cf * ANG(0, math.pi / 2, 0) * CF(-0.1, 0, 0), rgb(255, 255, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.45
	return disc, ring
end

---------------------------------------------------------------- ฉาก
-- แต่ละฉาก: สร้างของใน world -> { Text, Chapter, Sky, Light, Ambient, Cam = { from, to }, Fov, Tick(t, dt), Flash }
local SHOTS = {
	-- 1 ห้องทดลอง: ทีมยืนหน้าประตูมิติ
	function()
		part(V(240, 1, 240), CF(0, -0.5, 0), rgb(60, 66, 80), Enum.Material.DiamondPlate)
		part(V(80, 40, 2), CF(0, 20, -22), rgb(40, 46, 62), Enum.Material.Metal)
		for _, x in ipairs({ -16, 16 }) do
			part(V(2, 30, 2), CF(x, 15, -18), rgb(90, 200, 255), Enum.Material.Neon).Transparency = 0.4
		end
		local gate = place(asset("Props", "GateStargate"), 16, CF(0, 0, -10))
		local center = gate and gate:GetBoundingBox().Position or V(0, 8, -10)
		local disc, ring = portalDisc(CF(center), 5.6, rgb(90, 220, 255))
		local team = {}
		for i, cid in ipairs({ "Scout", "Survivor", "Builder", "Elementalist" }) do
			table.insert(team, hero(cid, CF(-6 + (i - 1) * 4, 0, 6) * ANG(0, math.pi + (i - 2.5) * 0.12, 0)))
		end
		local _ = team
		return {
			Chapter = "THE EXPERIMENT",
			Text = "A team of young explorers built a machine that could travel through time.",
			Sky = { rgb(20, 30, 60), rgb(8, 10, 24) }, Light = rgb(170, 220, 255), Ambient = rgb(120, 130, 160),
			Cam = { CFrame.lookAt(V(4, 7, 26), V(0, 7, -6)), CFrame.lookAt(V(1, 6, 17), V(0, 7.5, -8)) },
			Tick = function(t)
				disc.CFrame = disc.CFrame * ANG(0.02, 0, 0)
				disc.Transparency = 0.15 + math.sin(t * 6) * 0.08
				ring.Size = V(0.5, 7 + math.sin(t * 4) * 1.2, 7 + math.sin(t * 4) * 1.2)
			end,
		}
	end,
	-- 2 ทดลองพัง: วงวนสีเปลี่ยน ดูดทีมเข้าไป
	function()
		part(V(240, 1, 240), CF(0, -0.5, 0), rgb(50, 40, 70), Enum.Material.DiamondPlate)
		local gate = place(asset("Props", "GateStargate"), 16, CF(0, 0, -6))
		local center = gate and gate:GetBoundingBox().Position or V(0, 8, -6)
		local disc, ring = portalDisc(CF(center), 5.6, rgb(190, 90, 255))
		local team = {}
		for i, cid in ipairs({ "Scout", "Survivor", "Builder", "Elementalist" }) do
			local m = hero(cid, CF(-5 + (i - 1) * 3.3, 0, 5) * ANG(0, math.pi, 0))
			if m then
				table.insert(team, { M = m, Base = m:GetPivot() })
			end
		end
		return {
			Chapter = "SOMETHING WENT WRONG",
			Text = "But the first test went wrong — the portal pulled them deep into the ancient past!",
			Sky = { rgb(60, 20, 90), rgb(10, 4, 20) }, Light = rgb(220, 160, 255), Ambient = rgb(130, 100, 160),
			Cam = { CFrame.lookAt(V(-14, 5, 18), V(0, 7, -4)), CFrame.lookAt(V(-6, 9, 13), V(0, 8, -6)) },
			Flash = rgb(235, 220, 255),
			Tick = function(t)
				local k = math.clamp(t / 4.2, 0, 1)
				disc.CFrame = disc.CFrame * ANG(0.08 + k * 0.2, 0, 0)
				disc.Color = rgb(190, 90, 255):Lerp(rgb(255, 255, 255), k * 0.6)
				ring.Size = V(0.5, 7 + k * 6, 7 + k * 6)
				for i, h in ipairs(team) do
					local pull = center - h.Base.Position
					local cf = h.Base + pull * (k ^ 2) * 0.85 + V(0, math.sin(t * 7 + i) * 0.4 * k + k * 3, 0)
					h.M:PivotTo(cf * ANG(math.sin(t * 9 + i) * 0.5 * k, t * k * 3, math.cos(t * 8 + i) * 0.5 * k))
				end
			end,
		}
	end,
	-- 3 ตื่นในป่ายุคโบราณ กลางคืน รอบกองไฟ
	function()
		ground(rgb(52, 84, 46))
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			local r = 22 + (i % 3) * 5
			place(asset("Props", i % 2 == 0 and "Fir1" or "OakPack"), 18 + (i % 3) * 4, CF(math.cos(a) * r, 0, math.sin(a) * r) * ANG(0, a, 0))
		end
		local flames = campfire(CF(0, 0, 0))
		hero("Survivor", CF(-4, 0, 2) * ANG(0, -math.pi / 2 - 0.5, 0))
		hero("Scout", CF(4, 0, 1.5) * ANG(0, math.pi / 2 + 0.4, 0))
		hero("Builder", CF(0, 0, -4.5) * ANG(0, 0, 0))
		hero("Elementalist", CF(2.5, 0, 4) * ANG(0, math.pi + 0.4, 0))
		return {
			Chapter = "A WILD, ANCIENT LAND",
			Text = "They woke up in a wild, ancient forest. The portal was gone — and night was falling.",
			Sky = { rgb(16, 22, 56), rgb(40, 24, 50) }, Light = rgb(255, 180, 110), Ambient = rgb(90, 90, 130),
			Cam = { CFrame.lookAt(V(-16, 9, 14), V(0, 2, 0)), CFrame.lookAt(V(14, 7, 14), V(0, 2, 0)) },
			Tick = function(t)
				for i, f in ipairs(flames) do
					f.Size = V(1.4, 2.6, 1.4) * (1 - i * 0.18) * (1 + math.sin(t * 12 + i * 2) * 0.12)
				end
			end,
		}
	end,
	-- 4 จิ้งจอกเงา Moonfang ซุ่มนอกแสงไฟ
	function()
		ground(rgb(28, 36, 34))
		for i = 0, 6 do
			place(asset("Props", "Fir1"), 20 + (i % 3) * 3, CF(-24 + i * 8, 0, -14 - (i % 2) * 6))
		end
		local fox = place(asset("Animals", "Moonfang"), 9, CF(2, 0, -6) * ANG(0, 0.3, 0))
		local eyes = {}
		if fox then
			local cf, size = fox:GetBoundingBox()
			for _, x in ipairs({ -0.5, 0.5 }) do
				table.insert(eyes, part(V(0.45, 0.3, 0.3), cf * CF(x, size.Y * 0.22, size.Z * 0.45), rgb(255, 60, 60), Enum.Material.Neon))
			end
		end
		local flames = campfire(CF(-6, 0, 12))
		hero("Scout", CF(-10, 0, 6) * ANG(0, math.pi + 0.9, 0))
		return {
			Chapter = "THE MOONFANG",
			Text = "When darkness falls, the Moonfang — a shadow fox — hunts anyone outside the firelight.",
			Sky = { rgb(30, 10, 40), rgb(4, 2, 10) }, Light = rgb(150, 120, 255), Ambient = rgb(60, 50, 90),
			Cam = { CFrame.lookAt(V(-4, 4, 24), V(0, 4, -6)), CFrame.lookAt(V(1, 4.5, 13), V(2, 4.5, -6)) },
			Tick = function(t)
				for _, e in ipairs(eyes) do
					e.Transparency = (math.sin(t * 3) > 0.92) and 1 or 0 -- กะพริบ
				end
				for i, f in ipairs(flames) do
					f.Size = V(1.4, 2.6, 1.4) * (1 - i * 0.18) * (1 + math.sin(t * 12 + i * 2) * 0.12)
				end
			end,
		}
	end,
	-- 5 ลูกสัตว์วิญญาณ 4 ธาตุ
	function()
		ground(rgb(60, 70, 60), Enum.Material.Ground)
		local list = {
			{ "TerraPup", "CrystalGreen", rgb(120, 230, 90) }, { "TidePup", "CrystalBlue", rgb(80, 190, 255) },
			{ "GalePup", "CrystalWhite", rgb(210, 235, 255) }, { "EmberPup", "CrystalRed", rgb(255, 120, 40) },
		}
		local pups = {}
		for i, e in ipairs(list) do
			local x = -12 + (i - 1) * 8
			place(asset("Props", e[2]), 9, CF(x, 0, -5))
			part(V(0.4, 6, 6), CF(x, 0.25, 0) * ANG(0, 0, math.pi / 2), e[3], Enum.Material.Neon, Enum.PartType.Cylinder).Transparency = 0.5
			local m = place(asset("Animals", e[1]), 3.6, CF(x, 0, 0) * ANG(0, math.pi + 0.2, 0))
			if m then
				table.insert(pups, { M = m, Base = m:GetPivot(), I = i })
			end
		end
		return {
			Chapter = "THE SPIRIT PUPS",
			Text = "Spirit pups of the four lands are lost here too. Rescue them all and take them home with you.",
			Sky = { rgb(70, 110, 160), rgb(30, 30, 70) }, Light = rgb(255, 245, 230), Ambient = rgb(150, 150, 170),
			Cam = { CFrame.lookAt(V(-16, 5, 14), V(-6, 2.5, 0)), CFrame.lookAt(V(14, 5, 14), V(6, 2.5, 0)) },
			Tick = function(t)
				for _, p in ipairs(pups) do
					p.M:PivotTo(p.Base + V(0, math.abs(math.sin(t * 3 + p.I)) * 0.8, 0))
				end
			end,
		}
	end,
	-- 6 ผจญภัย: ศาลเจ้า/วิหาร + บอสของแต่ละไบโอม
	function()
		ground(rgb(70, 50, 40), Enum.Material.Ground)
		place(asset("Props", "RuinTemple"), 18, CF(-34, 0, -30) * ANG(0, 0.6, 0))
		place(asset("Props", "ShrineFire"), 12, CF(24, 0, -22) * ANG(0, -0.5, 0))
		local boss = place(asset("Animals", "Terragon"), 18, CF(0, 0, -8) * ANG(0, math.pi + 0.15, 0))
		hero("Survivor", CF(-4, 0, 6) * ANG(0, 0.1, 0))
		hero("Scout", CF(4, 0, 7) * ANG(0, -0.1, 0))
		local base = boss and boss:GetPivot()
		return {
			Chapter = "THE FOUR LANDS",
			Text = "Brave Earth, Water, Frost and Fire — clear the shrines and sanctums, and defeat each land's boss.",
			Sky = { rgb(120, 40, 30), rgb(30, 8, 8) }, Light = rgb(255, 170, 130), Ambient = rgb(130, 100, 100),
			Cam = { CFrame.lookAt(V(0, 4, 30), V(0, 8, -8)), CFrame.lookAt(V(-8, 11, 26), V(0, 9, -8)) },
			Tick = function(t)
				if boss and base then
					boss:PivotTo(base * CF(0, math.abs(math.sin(t * 1.6)) * 0.6, 0))
				end
			end,
		}
	end,
	-- 7 รอด 99 คืน ประตูกลับบ้านเปิด
	function()
		ground(rgb(58, 86, 50))
		local gate = place(asset("Props", "GateStargate"), 16, CF(0, 0, -12))
		local center = gate and gate:GetBoundingBox().Position or V(0, 8, -12)
		local disc, ring = portalDisc(CF(center), 5.6, rgb(255, 214, 110))
		campfire(CF(0, 0, 2))
		for i, cid in ipairs({ "Scout", "Survivor", "Builder", "Elementalist" }) do
			hero(cid, CF(-6 + (i - 1) * 4, 0, 6) * ANG(0, math.pi + (i - 2.5) * 0.1, 0))
		end
		for i, pid in ipairs({ "TerraPup", "TidePup", "GalePup", "EmberPup" }) do
			place(asset("Animals", pid), 2.6, CF(-4.5 + (i - 1) * 3, 0, 9.5) * ANG(0, math.pi, 0))
		end
		return {
			Chapter = "99 NIGHTS",
			Text = "Survive 99 nights until the portal opens again — and bring everyone home!",
			Sky = { rgb(255, 170, 90), rgb(60, 30, 70) }, Light = rgb(255, 225, 170), Ambient = rgb(160, 140, 130),
			Cam = { CFrame.lookAt(V(0, 5, 26), V(0, 6, -6)), CFrame.lookAt(V(0, 8, 19), V(0, 7.5, -8)) },
			Title = true,
			Tick = function(t)
				disc.CFrame = disc.CFrame * ANG(0.03, 0, 0)
				ring.Size = V(0.5, 7 + math.sin(t * 3) * 1.4, 7 + math.sin(t * 3) * 1.4)
			end,
		}
	end,
}
local SHOT_TIME = 5.6

---------------------------------------------------------------- จอ
local ui = {}
local playing = false
local token = 0

local function build()
	if ui.Root then
		return
	end
	local gui = UIKit.Screen("Story", 85, true)
	gui.IgnoreGuiInset = true
	ui.Gui = gui
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.BorderSizePixel = 0
	root.Active = true
	root.Visible = false
	root.Parent = gui
	ui.Root = root
	local sky = Instance.new("Frame")
	sky.Size = UDim2.fromScale(1, 1)
	sky.BackgroundColor3 = Color3.new(1, 1, 1)
	sky.BorderSizePixel = 0
	sky.Parent = root
	ui.SkyGrad = Instance.new("UIGradient")
	ui.SkyGrad.Rotation = 90
	ui.SkyGrad.Parent = sky
	local vpf = Instance.new("ViewportFrame")
	vpf.Size = UDim2.fromScale(1, 1)
	vpf.BackgroundTransparency = 1
	vpf.LightDirection = V(-0.4, -1, -0.5)
	vpf.Parent = root
	ui.Vpf = vpf
	-- แถบดำบน-ล่าง (โรงหนัง)
	for _, top in ipairs({ true, false }) do
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, 0, 0.11, 0)
		bar.AnchorPoint = Vector2.new(0, top and 0 or 1)
		bar.Position = UDim2.fromScale(0, top and 0 or 1)
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.ZIndex = 5
		bar.Parent = root
	end
	ui.Chapter = UIKit.Text(root, {
		Size = UDim2.new(0.8, 0, 0.06, 0), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.025), Text = "", TextScaled = true,
		Font = UIKit.Fonts.Title, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6,
	})
	ui.Caption = UIKit.Text(root, {
		Size = UDim2.new(0.86, 0, 0.16, 0), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Text = "", TextScaled = true,
		Font = UIKit.Fonts.Black, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, ZIndex = 6,
	})
	local cs = Instance.new("UITextSizeConstraint")
	cs.MaxTextSize = 40
	cs.Parent = ui.Caption
	UIKit.TextStroke(ui.Caption, 2, 0.2)
	ui.Title = UIKit.Text(root, {
		Size = UDim2.new(0.8, 0, 0.16, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Text = "99 NIGHTS IN THE WILDS", TextScaled = true,
		Font = UIKit.Fonts.Title, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Visible = false,
	})
	UIKit.TextStroke(ui.Title, 4, 0)
	ui.Fade = Instance.new("Frame")
	ui.Fade.Size = UDim2.fromScale(1, 1)
	ui.Fade.BackgroundColor3 = Color3.new(0, 0, 0)
	ui.Fade.BorderSizePixel = 0
	ui.Fade.ZIndex = 8
	ui.Fade.Parent = root
	ui.Skip = UIKit.Button(root, { Size = UDim2.fromOffset(130, 40), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14), Text = "Skip ⏭", TextSize = 18, ZIndex = 9 }, function()
		Story.Stop()
	end)
	UIKit.EnsureTouchSize(ui.Skip, 48, Story.Stop)
	ui.Start = UIKit.ColorButton(root, C.Green, { Size = UDim2.fromOffset(300, 64), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Text = "Begin ▶", TextSize = 32, Font = UIKit.Fonts.Title, ZIndex = 9, Visible = false }, function()
		Story.Stop()
	end)
end

local function typeText(label, text, time, my)
	label.Text = text
	label.MaxVisibleGraphemes = 0
	RunService.RenderStepped:Wait() -- ให้ Localizer แปลก่อน แล้วนับความยาวของข้อความที่แปลแล้ว
	local n = utf8.len(label.Text) or #label.Text
	local t0 = os.clock()
	while token == my and label.MaxVisibleGraphemes < n do
		label.MaxVisibleGraphemes = math.floor((os.clock() - t0) / time * n)
		RunService.RenderStepped:Wait()
	end
	label.MaxVisibleGraphemes = -1
end

local function fade(to, time)
	local tw = TweenService:Create(ui.Fade, TweenInfo.new(time, Enum.EasingStyle.Quad), { BackgroundTransparency = to })
	tw:Play()
	tw.Completed:Wait()
end

local function flash(color)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = 7
	f.Parent = ui.Root
	TweenService:Create(f, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(f, 1)
end

local function ease(x)
	return x < 0.5 and 2 * x * x or 1 - (-2 * x + 2) ^ 2 / 2
end

local function runShot(i, my)
	ui.Vpf:ClearAllChildren()
	world = Instance.new("WorldModel")
	world.Parent = ui.Vpf
	local ok, opts = pcall(SHOTS[i])
	if not ok then
		warn("[AS] story shot", i, opts)
		opts = { Text = "", Cam = { CFrame.lookAt(V(0, 5, 20), V(0, 3, 0)), CFrame.lookAt(V(0, 5, 18), V(0, 3, 0)) } }
	end
	local sky = opts.Sky or { rgb(30, 30, 50), rgb(10, 10, 20) }
	ui.SkyGrad.Color = ColorSequence.new(sky[1], sky[2])
	ui.Vpf.Ambient = opts.Ambient or rgb(140, 140, 160)
	ui.Vpf.LightColor = opts.Light or rgb(255, 245, 230)
	local cam = Instance.new("Camera")
	cam.FieldOfView = opts.Fov or 50
	cam.CFrame = opts.Cam[1]
	cam.Parent = ui.Vpf
	ui.Vpf.CurrentCamera = cam
	ui.Chapter.Text = opts.Chapter or ""
	ui.Caption.Text = ""
	ui.Title.Visible = false
	fade(1, 0.45)
	local t0 = os.clock()
	local textDone = false
	task.spawn(function()
		typeText(ui.Caption, opts.Text or "", 2.2, my)
		textDone = true
	end)
	local dur = opts.Title and SHOT_TIME + 0.6 or SHOT_TIME
	local flashed = false
	while token == my do
		local t = os.clock() - t0
		local k = math.clamp(t / dur, 0, 1)
		cam.CFrame = opts.Cam[1]:Lerp(opts.Cam[2], ease(k))
		if opts.Tick then
			pcall(opts.Tick, t)
		end
		if opts.Flash and not flashed and t > dur - 1 then
			flashed = true
			flash(opts.Flash)
		end
		if t >= dur and textDone then
			break
		end
		RunService.RenderStepped:Wait()
	end
	if token ~= my then
		return false
	end
	if opts.Title then
		ui.Title.Visible = true
		UIKit.Pop(ui.Title)
		ui.Start.Visible = true
		ui.Skip.Visible = false
		-- รอกด "เริ่ม" (กล้องค้างภาพสุดท้าย ของในฉากยังขยับ)
		while token == my do
			if opts.Tick then
				pcall(opts.Tick, os.clock() - t0)
			end
			RunService.RenderStepped:Wait()
		end
		return false
	end
	fade(0, 0.35)
	return true
end

function Story.Play(onDone)
	build()
	token += 1
	local my = token
	playing = true
	ui.OnDone = onDone
	ui.Root.Visible = true
	ui.Fade.BackgroundTransparency = 0
	ui.Start.Visible = false
	ui.Skip.Visible = true
	task.spawn(function()
		for i = 1, #SHOTS do
			if token ~= my or not runShot(i, my) then
				break
			end
		end
	end)
end

function Story.Stop()
	if not playing then
		return
	end
	playing = false
	token += 1
	if ui.Root then
		ui.Root.Visible = false
		ui.Vpf:ClearAllChildren()
	end
	world = nil
	local cb = ui.OnDone
	ui.OnDone = nil
	if cb then
		task.defer(cb)
	end
end

function Story.IsPlaying()
	return playing
end

function Story.Init()
	build()
	UserInputService.InputBegan:Connect(function(input)
		if playing and input.KeyCode == Enum.KeyCode.Escape then
			Story.Stop()
		end
	end)
end

-- ให้เทสเรียกถ่ายภาพทีละฉากได้
Story.ShotCount = #SHOTS

return Story
