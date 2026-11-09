--[[
	ClassFX — เอฟเฟกต์ของคลาส 5 ดาว (วาดฝั่งเครื่องผู้เล่นทั้งหมด เซิร์ฟเวอร์ส่งแค่ตำแหน่ง/ทิศ ผ่าน HitFx)
	  ตีธรรมดา (อาวุธประจำคลาส Items.Tools[].Fx):
	    Blood   (เคียวแวมไพร์) : ใบเคียวโค้งสีเลือดกวาดตามทิศฟัน + รอยฟันอนิเมะ · โดน = เลือดสาด
	    Arcane  (คทาพ่อมดมืด)  : ประกายชาร์จที่ปลายคทา + ลูกพลังม่วงมีหาง · ระเบิดม่วง + เศษคริสตัล
	    Verdant (คทาพงไพร)     : ประกายเขียว + ลูกหนามเขียวมีหาง · ระเบิดเขียว + ใบไม้ปลิว
	  สกิลกด:
	    SkillSwarm      : ประตูเลือดเปิดใต้เท้า เสาแสงแดง ค้างคาวบินออก · BatBite / BatGuard (ค้างคาวรับดาเมจแทน)
	    SkillVeil       : ควันม่วงระเบิด + เงาร่างจางทิ้งไว้
	    SkillDarkMeteor : ฟ้ามืด ประตูมิติม่วงบนฟ้า อุกกาบาตมืดพุ่งลง ระเบิดใหญ่ แผ่นดินแยก วงไฟมืด 10 วิ
	    SkillThornBind  : เทพแห่งพงไพรร่างยักษ์โปร่งแสงผุดจากดิน ฟาดพื้น คลื่นเขียว · มอนโดนหนามแทงขึ้นรอบตัว + พิษ
	ใช้อนุภาคจากคลัง VFX (VFXLib) + ชิ้นส่วนเรืองแสงประกอบเอง
]]

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local VFXLib = require(script.Parent:WaitForChild("VFXLib"))

local ClassFX = {}
local player = Players.LocalPlayer

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local C = Color3.fromRGB
local NS, NSK = NumberSequence.new, NumberSequenceKeypoint.new
local TEX = {
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
}
local FX = {
	Slashes = "VFXPack/Anime/Slashes-01",
	SlashImpact = "VFXPack/Anime/Slash-Impact-01",
	BloodPunch = "VFXPack/Anime/Blood-Punch-01",
	Blood = "VFXPack/Anime/Blood-01",
	Portal = "VFXPack/Anime/Portal-01",
	PortalEnter = "VFXPack/Anime/Portal-Enter-01",
	Charge = "VFXPack/Anime/Charge-01",
	Shiny = "VFXPack/Anime/Shiny-01",
	Smoke = "VFXPack/Anime/Smoke-01",
	Crack = "VFXPack/Anime/Crack-01",
	BigCrack = "VFXPack/Big/Big-Crack-01",
	BigExplosion = "VFXPack/Big/Explosion-01",
	Ball = "VFXPack/Big/Ball-01",
	Blast = "LightBlast/SUPER ANIME LIGHT GOLDEN BLAST/FireMegaExplosion",
	StaffExp = "StaffExplosion",
	Aura = "VFXPack/Auras/RNG-Aura-02",
}
-- สีของแต่ละชุด
local COL = {
	Blood = { Main = C(230, 30, 50), Core = C(255, 150, 160), Dark = C(90, 0, 15) },
	Arcane = { Main = C(170, 70, 255), Core = C(235, 200, 255), Dark = C(45, 10, 80) },
	Verdant = { Main = C(110, 235, 90), Core = C(220, 255, 200), Dark = C(30, 80, 25) },
}

---------------------------------------------------------------- เครื่องมือพื้นฐาน
local function folder()
	local f = Workspace:FindFirstChild("ClassFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ClassFX"
		f.Parent = Workspace
	end
	return f
end

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = folder()
	return p
end

local function tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function vfx(name, cf, opts)
	local ok, m = pcall(VFXLib.Play, FX[name] or name, typeof(cf) == "Vector3" and CF(cf) or cf, opts or {})
	return ok and m or nil
end

local function shake(pos, power, time)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local cs = ClassFX.Combat
	if cs and root and (root.Position - pos).Magnitude < 90 then
		pcall(cs.Shake, power, time or 0.3)
	end
end

local function sound(name, pos, vol, pitch)
	local cs = ClassFX.Combat
	if cs then
		pcall(cs.Sound, name, pos, vol, pitch)
	end
end

-- แสงวาบ
local function flash(pos, color, range, time, brightness)
	local p = part({ Size = V(1, 1, 1), Transparency = 1, Position = pos })
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, brightness or 6, false
	l.Parent = p
	tween(l, time, { Brightness = 0 })
	Debris:AddItem(p, time + 0.1)
end

-- คลื่นกระแทก: จานแบนขยายออก + จาง (แนบพื้น)
local function shockwave(pos, radius, color, time, height)
	local d = part({ Shape = Enum.PartType.Cylinder, Size = V(height or 0.6, 2, 2), Color = color, Transparency = 0.15, Material = Enum.Material.ForceField })
	d.CFrame = CF(pos + V(0, 0.4, 0)) * ANG(0, 0, math.pi / 2)
	tween(d, time, { Size = V(height or 0.6, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(d, time + 0.05)
	local core = part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 2, 2), Color = color, Transparency = 0.35 })
	core.CFrame = d.CFrame
	tween(core, time * 0.8, { Size = V(0.2, radius * 1.6, radius * 1.6), Transparency = 1 })
	Debris:AddItem(core, time)
end

-- เสาแสงพุ่งขึ้นฟ้า
local function pillar(pos, width, height, color, time)
	local p = part({ Shape = Enum.PartType.Cylinder, Size = V(height, width * 0.3, width * 0.3), Color = color, Transparency = 0.1 })
	p.CFrame = CF(pos + V(0, height / 2, 0)) * ANG(0, 0, math.pi / 2)
	tween(p, time * 0.25, { Size = V(height, width, width) }, Enum.EasingStyle.Back)
	task.delay(time * 0.35, function()
		tween(p, time * 0.65, { Size = V(height, 0.2, 0.2), Transparency = 1 })
	end)
	Debris:AddItem(p, time + 0.1)
end

-- อนุภาคพุ่งกระจายครั้งเดียว
local function burst(pos, props, count, life)
	local holder = part({ Size = V(1, 1, 1), Transparency = 1, Position = pos })
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.SpreadAngle = Vector2.new(180, 180)
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = holder
	e:Emit(count)
	Debris:AddItem(holder, life or 3)
	return e
end

-- เศษกระเด็น (ชิ้นจริงตกตามแรงโน้มถ่วง)
local function debris(pos, color, count, speed, size)
	for _ = 1, count do
		local s = (size or 1) * (0.5 + math.random() * 0.8)
		local p = part({ Size = V(s, s, s), Color = color, Material = Enum.Material.Basalt, Anchored = false, Transparency = 0 })
		p.CFrame = CF(pos + V(0, 1, 0)) * ANG(math.random() * 6, math.random() * 6, math.random() * 6)
		local a = math.random() * math.pi * 2
		p.AssemblyLinearVelocity = V(math.cos(a), 1.2 + math.random(), math.sin(a)) * (speed or 40) * (0.5 + math.random() * 0.6)
		p.AssemblyAngularVelocity = V(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		task.delay(1.2, function()
			if p.Parent then
				tween(p, 0.6, { Transparency = 1, Size = V(0.1, 0.1, 0.1) })
			end
		end)
		Debris:AddItem(p, 2)
	end
end

-- วงเวทแนบพื้น: วงนอก + วงใน + ซี่รูน หมุนช้าๆ
local function magicCircle(pos, radius, color, life)
	local m = Instance.new("Model")
	m.Name = "MagicCircle"
	local function ringAt(r, thick, segs, transp)
		local len = 2 * math.pi * r / segs * 1.12
		for i = 1, segs do
			local a = (i - 0.5) / segs * math.pi * 2
			local p = pos + V(math.cos(a) * r, 0.3, math.sin(a) * r)
			local s = part({ Size = V(thick, 0.2, len), Color = color, Transparency = transp })
			s.CFrame = CFrame.lookAt(p, p + V(-math.sin(a), 0, math.cos(a)))
			s.Parent = m
		end
	end
	ringAt(radius, 0.6, 48, 0.05)
	ringAt(radius * 0.72, 0.35, 36, 0.2)
	-- ซี่รูน (ดาว 6 แฉก)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local p1 = pos + V(math.cos(a) * radius * 0.72, 0.3, math.sin(a) * radius * 0.72)
		local p2 = pos + V(math.cos(a + math.pi * 2 / 3) * radius * 0.72, 0.3, math.sin(a + math.pi * 2 / 3) * radius * 0.72)
		local s = part({ Size = V(0.3, 0.2, (p2 - p1).Magnitude), Color = color, Transparency = 0.25 })
		s.CFrame = CFrame.lookAt((p1 + p2) / 2, p2)
		s.Parent = m
	end
	m.Parent = folder()
	local pivot = m:GetPivot()
	local t0 = os.clock()
	task.spawn(function()
		while m.Parent and os.clock() - t0 < life do
			m:PivotTo(CF(pos) * ANG(0, (os.clock() - t0) * 0.8, 0) * CF(-pos) * pivot)
			task.wait()
		end
	end)
	task.delay(life - 0.5, function()
		for _, d in ipairs(m:GetChildren()) do
			tween(d, 0.5, { Transparency = 1 })
		end
	end)
	Debris:AddItem(m, life + 0.1)
	return m
end

-- ฟ้ามืดชั่วครู่ (เฉพาะคนที่อยู่ใกล้)
local function darkenSky(pos, color, hold)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - pos).Magnitude > 160 then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ClassFXGrade"
	cc.Parent = Lighting
	tween(cc, 0.4, { Brightness = -0.06, Contrast = 0.12, Saturation = -0.1, TintColor = color })
	task.delay(hold, function()
		tween(cc, 0.8, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) })
		Debris:AddItem(cc, 0.9)
	end)
end

local function charOf(p)
	return typeof(p) == "Instance" and p:IsA("Player") and p.Character or nil
end

---------------------------------------------------------------- ตีธรรมดา
-- ใบเคียวโค้ง: ท่อนเรืองต่อเป็นจันทร์เสี้ยว กวาดจากซ้ายไปขวาตามทิศฟัน แล้วจาง
local function crescent(origin, dir, color, core, radius)
	local flat = V(dir.X, 0, dir.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or V(0, 0, -1)
	local base = CFrame.lookAt(origin, origin + flat) * ANG(math.rad(48), 0, math.rad(22)) -- ฟันโค้งขึ้นหน้าตัว หน้าใบหันหากล้องหลังตัว (เห็นใบเต็ม ไม่เป็นเส้น)
	local segs = 14
	local parts = {}
	for i = 1, segs do
		local t = (i - 1) / (segs - 1)
		local a = math.rad(-80 + 160 * t)
		local w = math.sin(t * math.pi) -- กลางหนา ปลายแหลม
		local p1 = base * CF(math.sin(a) * radius, 0, -math.cos(a) * radius)
		local a2 = math.rad(-80 + 160 * math.min(1, t + 1 / (segs - 1)))
		local p2 = base * CF(math.sin(a2) * radius, 0, -math.cos(a2) * radius)
		local len = (p2.Position - p1.Position).Magnitude * 1.15
		-- ใบกว้างตามแนวรัศมี (แบนในระนาบวงฟัน) -> มองจากหลังกล้องเห็นเป็นใบเคียวเต็มๆ
		local outer = part({ Size = V(2.4 * w + 0.2, 0.12, len), Color = color, Transparency = 1 })
		outer.CFrame = CFrame.lookAt(p1.Position, p2.Position, base.UpVector)
		local inner = part({ Size = V(0.8 * w + 0.08, 0.16, len), Color = core, Transparency = 1 })
		inner.CFrame = outer.CFrame
		table.insert(parts, { outer, inner, i })
	end
	-- กวาด: ท่อนสว่างไล่จากต้นถึงปลายใน 0.1 วิ แล้วจาง
	for _, e in ipairs(parts) do
		task.delay(e[3] / segs * 0.1, function()
			e[1].Transparency, e[2].Transparency = 0.1, 0
			tween(e[1], 0.55, { Transparency = 1, Size = e[1].Size * V(1, 0.3, 1) })
			tween(e[2], 0.45, { Transparency = 1 })
		end)
		Debris:AddItem(e[1], 0.8)
		Debris:AddItem(e[2], 0.8)
	end
end

-- หางลูกพลังคทา: เส้นแสง + ประกาย + แสงสี ติดลูกจริงที่เซิร์ฟเวอร์ยิง
local function dressBolt(p, kind)
	local col = COL[kind]
	if not col then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = V(0, 0.16, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = V(0, -0.16, 0)
	a1.Parent = p
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(col.Core, col.Main)
	tr.Transparency = NS({ NSK(0, 0), NSK(1, 1) })
	tr.Lifetime = 0.35
	tr.LightEmission = 1
	tr.WidthScale = NS({ NSK(0, 1), NSK(1, 0) })
	tr.FaceCamera = true
	tr.Parent = p
	local e = Instance.new("ParticleEmitter")
	e.Texture = kind == "Verdant" and TEX.Spark or TEX.Spark
	e.Color = ColorSequence.new(col.Core, col.Main)
	e.Rate = 18
	e.Lifetime = NumberRange.new(0.15, 0.3)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NS({ NSK(0, 0.25), NSK(1, 0) })
	e.LightEmission = 1
	e.Parent = a0
	if kind == "Verdant" then
		-- ใบไม้ร่วงตามหาง
		local leaf = Instance.new("ParticleEmitter")
		leaf.Texture = TEX.Spark
		leaf.Color = ColorSequence.new(C(90, 200, 70))
		leaf.Rate = 6
		leaf.Lifetime = NumberRange.new(0.5, 0.9)
		leaf.Speed = NumberRange.new(2, 5)
		leaf.Acceleration = V(0, -10, 0)
		leaf.Size = NS({ NSK(0, 0.5), NSK(1, 0.2) })
		leaf.Rotation = NumberRange.new(0, 360)
		leaf.RotSpeed = NumberRange.new(-200, 200)
		leaf.Parent = a1
	end
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = col.Main, 18, 3, false
	l.Parent = p
end

-- ลูกพลังคทาระเบิด (CombatClient Handlers.Explosion ส่งมา)
function ClassFX.Impact(d)
	local col = COL[d.FxKind]
	if not col then
		return false
	end
	local pos = d.Position
	vfx("StaffExp", pos, { Scale = (d.FxScale or 0.08), Duration = 0.25, Burst = 1, Tint = col.Main })
	vfx("Shiny", pos, { Scale = 0.25, Duration = 0.2, Burst = 1, Tint = col.Main })
	shockwave(pos, (d.Radius or 8) * 0.3, col.Main, 0.3)
	flash(pos + V(0, 2, 0), col.Main, 8, 0.2)
	if d.FxKind == "Arcane" then
		burst(pos, { Texture = TEX.Spark, Color = ColorSequence.new(col.Core, col.Main), Speed = NumberRange.new(5, 10), Lifetime = NumberRange.new(0.2, 0.35), Size = NS({ NSK(0, 0.45), NSK(1, 0) }), LightEmission = 1, Drag = 4 }, 8)
	else
		burst(pos, { Texture = TEX.Spark, Color = ColorSequence.new(C(130, 230, 90), C(60, 150, 40)), Speed = NumberRange.new(3, 8), Lifetime = NumberRange.new(0.5, 0.8), Size = NS({ NSK(0, 0.35), NSK(1, 0.15) }), Acceleration = V(0, -18, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300), Drag = 2 }, 7)
	end
	sound("Boom", pos, 0.22, d.FxKind == "Arcane" and 1.6 or 1.4)
	return true
end

-- ตอนเหวี่ยง/ยิง
local function onSwing(d)
	local col = COL[d.Fx]
	if not col then
		return
	end
	local char = charOf(d.Player)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local origin = root and root.Position or d.Position
	local dir = d.Dir or V(0, 0, -1)
	if d.Fx == "Blood" then
		crescent(origin + V(0, 1.2, 0) + dir * 2, dir, col.Main, col.Core, 8)
		task.delay(0.06, crescent, origin + V(0, 0.6, 0) + dir * 1.5, dir, C(120, 0, 20), col.Main, 6)
		flash(origin + dir * 4 + V(0, 1.5, 0), col.Main, 18, 0.3, 4)
		burst(origin + dir * 4 + V(0, 1.5, 0), { Texture = TEX.Spark, Color = ColorSequence.new(col.Core, col.Main), Speed = NumberRange.new(6, 14), Lifetime = NumberRange.new(0.2, 0.4), Size = NS({ NSK(0, 0.6), NSK(1, 0) }), LightEmission = 1 }, 14)
	else
		-- คทา: ประกายชาร์จที่ปลายคทา
		local tool = char and char:FindFirstChildOfClass("Tool")
		local handle = tool and tool:FindFirstChild("Handle")
		local tip = handle and (handle.CFrame * CF(0, handle.Size.Y * 0.45, 0)).Position or (origin + V(0, 3, 0) + dir * 2)
		local orb = part({ Shape = Enum.PartType.Ball, Size = V(0.6, 0.6, 0.6), Color = col.Core, Position = tip, Transparency = 0 })
		tween(orb, 0.25, { Size = V(1.3, 1.3, 1.3), Transparency = 1 })
		Debris:AddItem(orb, 0.4)
		local ring = part({ Shape = Enum.PartType.Cylinder, Size = V(0.15, 1, 1), Color = col.Main, Transparency = 0.1 })
		ring.CFrame = CFrame.lookAt(tip, tip + dir) * ANG(0, math.rad(90), 0)
		tween(ring, 0.25, { Size = V(0.05, 1.8, 1.8), Transparency = 1 })
		Debris:AddItem(ring, 0.4)
		burst(tip, { Texture = TEX.Spark, Color = ColorSequence.new(col.Core, col.Main), Speed = NumberRange.new(3, 6), Lifetime = NumberRange.new(0.15, 0.3), Size = NS({ NSK(0, 0.4), NSK(1, 0) }), LightEmission = 1 }, 6)
		flash(tip, col.Main, 7, 0.2, 3)
	end
end

-- ตีโดน (เคียว)
local function onHit(d)
	local col = COL[d.Fx]
	if not col then
		return
	end
	local pos = d.Position
	if d.Fx == "Blood" then
		vfx("BloodPunch", pos, { Scale = d.Crit and 1.1 or 0.8, Duration = 0.2, Burst = 1, Tint = col.Main })
		vfx("SlashImpact", pos, { Scale = 0.7, Duration = 0.2, Burst = 1, Tint = col.Main })
		burst(pos, { Texture = TEX.Spark, Color = ColorSequence.new(C(200, 0, 20), C(90, 0, 10)), Speed = NumberRange.new(8, 18), Lifetime = NumberRange.new(0.4, 0.8), Size = NS({ NSK(0, 0.9), NSK(1, 0.2) }), Acceleration = V(0, -40, 0) }, d.Crit and 30 or 16)
		flash(pos, col.Main, 16, 0.25)
		if d.Crit then
			shockwave(pos - V(0, 2, 0), 7, col.Main, 0.35)
		end
	end
end

---------------------------------------------------------------- แวมไพร์: ฝูงค้างคาว
-- หนามจากเมช Creator Store (Assets.Props.ThornSpike = แท่งหนามมีหนามย่อย · ThornHorns = เถาหนามโค้งคู่) สูง h · สีเขียวไล่โทน
--   ไม่มีโมเดล = ลิ่มแทน
local THORN_COLORS = { C(34, 70, 26), C(52, 105, 36), C(78, 140, 48), C(30, 58, 22) }
local function thornMesh(name, h, i)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	local src = props and props:FindFirstChild(name == "Spike" and "ThornSpike" or "ThornHorns")
	local tpl = src and (src:IsA("BasePart") and src or src:FindFirstChildWhichIsA("BasePart", true))
	local col = THORN_COLORS[(i or 1) % #THORN_COLORS + 1]
	if tpl then
		local p = tpl:Clone()
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Size = tpl.Size * (h / math.max(tpl.Size.Y, 0.01))
		p.Color = col
		p.Transparency = 0
		p.Parent = folder()
		return p, p.Size.Y
	end
	local w = part({ ClassName = "WedgePart", Size = V(0.55, h, 0.9), Color = col, Material = Enum.Material.SmoothPlastic, Transparency = 0 })
	return w, h
end

-- สายฟ้าแดงซิกแซกจากฟ้าลงพื้น
local function lightning(from, to, color, width, life)
	local n = 9
	local prev = from
	for i = 1, n do
		local t = i / n
		local p = from:Lerp(to, t)
		if i < n then
			p += V(math.random() - 0.5, 0, math.random() - 0.5) * 7
		end
		local len = (p - prev).Magnitude
		local seg = part({ Size = V(width, width, len), Color = color, Transparency = 0 })
		seg.CFrame = CFrame.lookAt((prev + p) / 2, p)
		local core = part({ Size = V(width * 0.4, width * 0.4, len), Color = C(255, 230, 235), Transparency = 0 })
		core.CFrame = seg.CFrame
		tween(seg, life, { Transparency = 1, Size = V(0, 0, len) })
		tween(core, life * 0.8, { Transparency = 1 })
		Debris:AddItem(seg, life + 0.05)
		Debris:AddItem(core, life + 0.05)
		prev = p
	end
end

-- ค้างคาวตัวหลอกสำหรับพายุ (ก๊อปโมเดลค้างคาวจริง ทาสีดำแดง ยึดอยู่กับที่ ขยับด้วยสคริปต์)
local function fakeBat(scale)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local src = assets and assets:FindFirstChild("Props") and assets.Props:FindFirstChild("VampBat")
	local m
	if src then
		m = src:Clone()
		-- ปีกสองด้าน (เมชปีกหน้าเดียว)
		for _, w in ipairs(m:GetChildren()) do
			local mesh = w:IsA("BasePart") and w.Name:find("Wing") and w:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				local back = w:Clone()
				for _, c in ipairs(back:GetChildren()) do
					if not c:IsA("SpecialMesh") then
						c:Destroy()
					end
				end
				local bm = back:FindFirstChildOfClass("SpecialMesh")
				bm.Scale = bm.Scale * V(1, 1, -1)
				back.Parent = m
			end
		end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
				-- ค้างคาวเลือดเรืองแสง (มองเห็นชัดทั้งกลางวัน/กลางคืน)
				d.Material = Enum.Material.Neon
				d.Color = math.random() < 0.5 and C(170, 0, 25) or C(90, 0, 15)
				if d:IsA("MeshPart") then
					d.TextureID = ""
				end
			elseif d:IsA("SurfaceAppearance") then
				d:Destroy()
			elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
				d:Destroy()
			end
		end
		pcall(function()
			m:ScaleTo(m:GetScale() * scale)
		end)
	else
		m = Instance.new("Model")
		local b = part({ Size = V(0.8, 0.8, 0.8) * scale, Color = C(30, 0, 8), Material = Enum.Material.SmoothPlastic })
		b.Parent = m
		for _, x in ipairs({ -1, 1 }) do
			local w = part({ ClassName = "WedgePart", Size = V(0.15, 0.9, 1.6) * scale, Color = C(60, 0, 15), Material = Enum.Material.SmoothPlastic })
			w.CFrame = b.CFrame * CF(x * 0.9 * scale, 0, 0) * ANG(0, 0, math.rad(90 * x))
			w.Parent = m
		end
		m.PrimaryPart = b
	end
	m.Parent = folder()
	return m
end

---------------------------------------------------------------- แวมไพร์: ราตรีเลือด (เรียกฝูงค้างคาว)
-- จันทร์เลือดขึ้นฟ้า -> วงเวทเลือด + สายฟ้าแดงฟาด -> พายุค้างคาวหมุนวนพุ่งขึ้นจากใต้ดิน -> ระเบิดเลือดแตกฝูงเป็นค้างคาวรับใช้ 5 ตัว
local function onSwarm(d)
	local pos = d.Position - V(0, 2.6, 0)
	local col = COL.Blood
	local cam = Workspace.CurrentCamera
	local look = cam and V(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z) or V(0, 0, -1)
	look = look.Magnitude > 0.01 and look.Unit or V(0, 0, -1)
	darkenSky(pos, C(255, 150, 160), 2.9)
	sound("Boom", pos, 0.5, 0.45)
	-- จันทร์เลือดบนฟ้าตรงหน้ากล้อง
	local moonPos = pos + look * 120 + V(0, 38, 0)
	local moon = part({ Shape = Enum.PartType.Ball, Size = V(1, 1, 1), Color = C(200, 10, 30), Position = moonPos, Transparency = 0.1 })
	local halo = part({ Shape = Enum.PartType.Ball, Size = V(1, 1, 1), Color = C(255, 40, 60), Material = Enum.Material.ForceField, Position = moonPos, Transparency = 0.2 })
	tween(moon, 0.5, { Size = V(30, 30, 30) }, Enum.EasingStyle.Back)
	tween(halo, 0.7, { Size = V(48, 48, 48) })
	task.delay(2.6, function()
		tween(moon, 0.8, { Transparency = 1 })
		tween(halo, 0.8, { Transparency = 1 })
	end)
	Debris:AddItem(moon, 3.5)
	Debris:AddItem(halo, 3.5)
	-- วงเวทเลือด 2 ชั้นหมุนสวนกัน + บ่อเลือดบนพื้น
	magicCircle(pos, 11, col.Main, 2.6)
	magicCircle(pos + V(0, 0.15, 0), 6, C(255, 90, 110), 2.4)
	local pool = part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 1, 1), Color = C(110, 0, 15), Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	pool.CFrame = CF(pos + V(0, 0.1, 0)) * ANG(0, 0, math.rad(90))
	tween(pool, 0.4, { Size = V(0.2, 16, 16) })
	task.delay(2.2, function()
		tween(pool, 0.6, { Transparency = 1 })
	end)
	Debris:AddItem(pool, 3)
	-- สายฟ้าแดงฟาดลงรอบวง 0.1-0.6 วิ
	for i = 1, 5 do
		task.delay(0.1 * i, function()
			local a = math.random() * math.pi * 2
			local hit = pos + V(math.cos(a), 0, math.sin(a)) * (4 + math.random() * 6)
			lightning(hit + V(math.random(-10, 10), 70, math.random(-10, 10)), hit, col.Main, 0.6, 0.3)
			flash(hit + V(0, 2, 0), col.Main, 24, 0.2, 6)
			burst(hit, { Texture = TEX.Spark, Color = ColorSequence.new(col.Core, col.Main), Speed = NumberRange.new(10, 20), Lifetime = NumberRange.new(0.2, 0.4), Size = NS({ NSK(0, 0.8), NSK(1, 0) }), LightEmission = 1 }, 10)
		end)
	end
	-- พายุค้างคาว: 26 ตัวหมุนเป็นเกลียวขึ้นจากบ่อเลือด 1.5 วิ (สูงไม่เกิน ~13 ให้อยู่ในจอ) แล้วแตกฝูงบินออก
	local bats = {}
	for i = 1, 26 do
		local m = fakeBat(1.3 + math.random() * 1.1)
		m:PivotTo(CF(pos))
		bats[i] = { Model = m, A = i / 26 * math.pi * 2, Speed = 7 + math.random() * 4, H = math.random() * 0.6, R = 2.5 + math.random() * 2, Out = V(math.cos(i), 0.1 + math.random() * 0.3, math.sin(i)).Unit }
	end
	local tornado = burst(pos + V(0, 2, 0), { Texture = TEX.Smoke, Color = ColorSequence.new(C(120, 0, 20), C(25, 0, 5)), Speed = NumberRange.new(4, 9), Lifetime = NumberRange.new(0.9, 1.5), Size = NS({ NSK(0, 2), NSK(1, 7) }), Transparency = NS({ NSK(0, 0.35), NSK(1, 1) }), Acceleration = V(0, 22, 0), RotSpeed = NumberRange.new(-200, 200) }, 50)
	tornado.Rate = 45 -- พ่นควันเลือดต่อเนื่องจนแตกฝูง
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < 2.4 do
			local t = os.clock() - t0
			for _, b in ipairs(bats) do
				local cf
				if t < 1.5 then
					-- เกลียวขึ้น: รัศมีกว้างขึ้นตามความสูง
					local k = math.clamp((t - b.H * 0.3) / 1.5, 0, 1)
					local a = b.A + t * b.Speed
					local r = b.R + k * 5
					local p = pos + V(math.cos(a) * r, 1 + k * 10 + b.H * 3, math.sin(a) * r)
					local tangent = V(-math.sin(a), 0.4, math.cos(a))
					cf = CFrame.lookAt(p, p + tangent) * ANG(0, 0, math.sin(t * 30 + b.A) * 0.5)
				else
					-- แตกฝูง: พุ่งออกจากศูนย์กลาง
					local k = t - 1.5
					local a = b.A + 1.5 * b.Speed
					local r = b.R + 5
					local base = pos + V(math.cos(a) * r, 11 + b.H * 3, math.sin(a) * r)
					local p = base + b.Out * (k * 45)
					cf = CFrame.lookAt(p, p + b.Out) * ANG(0, 0, math.sin(t * 30 + b.A) * 0.5)
				end
				b.Model:PivotTo(cf)
			end
			RunService.Heartbeat:Wait()
		end
		for _, b in ipairs(bats) do
			b.Model:Destroy()
		end
	end)
	-- ระเบิดเลือดตอนแตกฝูง
	task.delay(1.5, function()
		local top = pos + V(0, 9, 0)
		pillar(pos, 12, 80, col.Main, 0.9)
		vfx("Blood", top, { Scale = 2, Duration = 0.5, Burst = 1, Tint = col.Main })
		vfx("BloodPunch", pos + V(0, 3, 0), { Scale = 1.6, Duration = 0.3, Burst = 1, Tint = col.Main })
		burst(top, { Texture = TEX.Spark, Color = ColorSequence.new(col.Core, col.Main), Speed = NumberRange.new(30, 55), Lifetime = NumberRange.new(0.5, 1), Size = NS({ NSK(0, 1.5), NSK(1, 0) }), LightEmission = 1, Drag = 2 }, 80)
		burst(pos + V(0, 1, 0), { Texture = TEX.Spark, Color = ColorSequence.new(C(200, 0, 20), C(80, 0, 10)), Speed = NumberRange.new(15, 30), Lifetime = NumberRange.new(0.6, 1), Size = NS({ NSK(0, 1), NSK(1, 0.3) }), Acceleration = V(0, -50, 0) }, 50)
		flash(top, col.Main, 60, 0.9, 10)
		shockwave(pos, 22, col.Main, 0.7)
		task.delay(0.12, shockwave, pos, 14, C(255, 120, 140), 0.5)
		shake(pos, 0.5, 0.4)
		sound("Boom", pos, 0.8, 0.7)
		sound("Flesh", pos, 0.8, 0.6)
		if tornado then
			tornado.Enabled = false
		end
	end)
end

local function onBatBite(d)
	vfx("SlashImpact", d.Position, { Scale = 0.4, Duration = 0.15, Burst = 1, Tint = COL.Blood.Main })
	burst(d.Position, { Texture = TEX.Spark, Color = ColorSequence.new(C(200, 0, 20)), Speed = NumberRange.new(5, 10), Lifetime = NumberRange.new(0.3, 0.5), Size = NS({ NSK(0, 0.5), NSK(1, 0) }), Acceleration = V(0, -30, 0) }, 8)
end

-- ไฟเผาบนตัวมอน: เปลวลุกท่วมตัว สีตามออร่าอาวุธ (ส่งซ้ำ = ต่อเวลา) · มอนตาย/หาย = ดับเอง
local burning = {} -- [model] = { Until, Box, Emit }
local function onBurning(d)
	local model = d.Model
	if typeof(model) ~= "Instance" or not model.Parent then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		return
	end
	local color = typeof(d.Color) == "ColorSequence" and d.Color or ColorSequence.new(C(255, 160, 60), C(255, 50, 20))
	local b = burning[model]
	if b and b.Box.Parent then
		b.Until = os.clock() + (d.Time or 4)
		b.Emit.Color, b.Core.Color = color, color
		return
	end
	local ok, cf, size = pcall(model.GetBoundingBox, model)
	if not ok then
		cf, size = root.CFrame, root.Size
	end
	local box = part({ Size = V(math.max(size.X * 0.7, 1), math.max(size.Y * 0.5, 1), math.max(size.Z * 0.7, 1)), Transparency = 1, Anchored = false, Massless = true })
	box.CFrame = CF(cf.Position - V(0, size.Y * 0.15, 0)) * root.CFrame.Rotation
	box.Name = "BurnBox"
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = root, box
	w.Parent = box
	-- อยู่ในโฟลเดอร์เอฟเฟกต์ (เชื่อมติดตัวมอน) · ห้ามใส่ในโมเดลมอน: ระบบสกิน/อนิเมชันของมอนล้างชิ้นแปลกปลอมทิ้ง
	local s = math.clamp(math.max(size.X, size.Z) * 0.35, 1, 5)
	local emit = Instance.new("ParticleEmitter")
	emit.Texture = TEX.Fire
	emit.Shape = Enum.ParticleEmitterShape.Box
	emit.Color = color
	emit.Rate = 40
	emit.Lifetime = NumberRange.new(0.45, 0.8)
	emit.Speed = NumberRange.new(2, 5)
	emit.SpreadAngle = Vector2.new(10, 10)
	emit.EmissionDirection = Enum.NormalId.Top
	emit.Acceleration = V(0, 4, 0)
	emit.Size = NS({ NSK(0, s * 1.1), NSK(0.5, s * 0.75), NSK(1, 0) })
	emit.Transparency = NS({ NSK(0, 0.1), NSK(0.7, 0.4), NSK(1, 1) })
	emit.Rotation = NumberRange.new(-30, 30)
	emit.LightEmission = 1
	emit.Brightness = 2.5
	emit.LightInfluence = 0 -- สว่างเท่ากันทั้งกลางวัน/กลางคืน (ไฟสีเข้มอย่างม่วงดำยังเห็นชัด)
	emit.Parent = box
	local core = Instance.new("ParticleEmitter")
	core.Texture = TEX.Spark
	core.Shape = Enum.ParticleEmitterShape.Box
	core.Color = color
	core.Rate = 10
	core.Lifetime = NumberRange.new(0.5, 1)
	core.Speed = NumberRange.new(2, 5)
	core.SpreadAngle = Vector2.new(30, 30)
	core.EmissionDirection = Enum.NormalId.Top
	core.Size = NS({ NSK(0, 0.35), NSK(1, 0) })
	core.LightEmission = 1
	core.Brightness = 3
	core.LightInfluence = 0
	core.Parent = box
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color.Keypoints[1].Value, s * 4, 1.5
	l.Parent = box
	b = { Until = os.clock() + (d.Time or 4), Box = box, Emit = emit, Core = core }
	burning[model] = b
	task.spawn(function()
		while box.Parent and model.Parent and os.clock() < b.Until and (model:GetAttribute("Health") or 1) > 0 do
			task.wait(0.2)
		end
		burning[model] = nil
		emit.Enabled, core.Enabled = false, false
		if l.Parent then
			tween(l, 0.4, { Brightness = 0 })
		end
		Debris:AddItem(box, 0.9)
	end)
end

-- ค้างคาวฆ่ามอน: ลูกเลือดลอยจากศพเข้าตัวเจ้าของ + ประกายฮีลรอบตัว
local function onBatDrain(d)
	local char = charOf(d.Player)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local from = d.Position
	for i = 1, 6 do
		task.delay(i * 0.05, function()
			if not root.Parent then
				return
			end
			local orb = part({ Shape = Enum.PartType.Ball, Size = V(0.7, 0.7, 0.7), Color = C(230, 20, 45), Position = from + V(math.random() - 0.5, math.random(), math.random() - 0.5) * 2, Transparency = 0 })
			local t0 = os.clock()
			local start = orb.Position
			local side = V(math.random() - 0.5, 0.6, math.random() - 0.5) * 10
			task.spawn(function()
				while os.clock() - t0 < 0.45 and root.Parent do
					local k = (os.clock() - t0) / 0.45
					local target = root.Position
					orb.Position = start:Lerp(target, k) + side * math.sin(k * math.pi)
					RunService.Heartbeat:Wait()
				end
				orb:Destroy()
			end)
		end)
	end
	task.delay(0.5, function()
		if root.Parent then
			burst(root.Position, { Texture = TEX.Spark, Color = ColorSequence.new(C(255, 160, 170), C(230, 30, 50)), Speed = NumberRange.new(4, 9), Lifetime = NumberRange.new(0.4, 0.7), Size = NS({ NSK(0, 0.7), NSK(1, 0) }), LightEmission = 1, Acceleration = V(0, 8, 0) }, 22)
			flash(root.Position, C(230, 30, 50), 14, 0.3)
		end
	end)
end

-- ค้างคาวรับดาเมจแทน: เส้นเลือดเชื่อมค้างคาว-เจ้าของ + โล่แดงวาบที่ตัว
local function onBatGuard(d)
	local char = charOf(d.Player)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local bat = d.Bat
	if not (root and typeof(bat) == "Instance" and bat.Parent) then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Parent = bat
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Color = ColorSequence.new(COL.Blood.Core, COL.Blood.Main)
	beam.LightEmission = 1
	beam.Width0, beam.Width1 = 1, 0.3
	beam.FaceCamera = true
	beam.Parent = a0
	tween(beam, 0.35, { Width0 = 0, Width1 = 0 })
	Debris:AddItem(a0, 0.4)
	Debris:AddItem(a1, 0.4)
	local shield = part({ Shape = Enum.PartType.Ball, Size = V(7, 7, 7), Color = COL.Blood.Main, Material = Enum.Material.ForceField, Transparency = 0.1, CFrame = root.CFrame })
	tween(shield, 0.35, { Size = V(9, 9, 9), Transparency = 1 })
	Debris:AddItem(shield, 0.4)
end

---------------------------------------------------------------- พ่อมดมืด: ม่านเงา
local function onVeil(d)
	local col = COL.Arcane
	local char = charOf(d.Player)
	vfx("Smoke", d.Position, { Scale = 1.2, Duration = 0.3, Burst = 1, Tint = col.Dark })
	vfx("PortalEnter", d.Position, { Scale = 0.8, Duration = 0.5, Burst = 1, Tint = col.Main })
	burst(d.Position, { Texture = TEX.Smoke, Color = ColorSequence.new(C(90, 40, 150), C(20, 5, 40)), Speed = NumberRange.new(8, 16), Lifetime = NumberRange.new(0.6, 1.1), Size = NS({ NSK(0, 3), NSK(1, 8) }), Transparency = NS({ NSK(0, 0.25), NSK(1, 1) }), Drag = 3 }, 45)
	burst(d.Position, { Texture = TEX.Spark, Color = ColorSequence.new(col.Core, col.Main), Speed = NumberRange.new(12, 24), Lifetime = NumberRange.new(0.3, 0.6), Size = NS({ NSK(0, 0.8), NSK(1, 0) }), LightEmission = 1 }, 40)
	flash(d.Position, col.Main, 24, 0.5)
	-- เงาร่าง: ก๊อปชิ้นที่มองเห็นเป็นร่างม่วงโปร่ง ค่อยๆ ลอยถอยหลังและจาง
	if char then
		local ghost = Instance.new("Model")
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 0.9 then
				local g = part({ Size = p.Size, CFrame = p.CFrame, Color = col.Main, Material = Enum.Material.ForceField, Transparency = 0.1 })
				g.Parent = ghost
			end
		end
		ghost.Parent = folder()
		local back = char:GetPivot().LookVector * -3
		for _, g in ipairs(ghost:GetChildren()) do
			tween(g, 0.9, { CFrame = g.CFrame + back + V(0, 0.6, 0), Transparency = 1 })
		end
		Debris:AddItem(ghost, 1)
	end
end

---------------------------------------------------------------- พ่อมดมืด: อุกกาบาตมืด
local function onDarkMeteor(d)
	local col = COL.Arcane
	local pos = d.Position
	local fall = 1.1
	darkenSky(pos, C(225, 210, 255), fall + 1.2)
	-- วงเวทบนพื้น + ประตูมิติบนฟ้า (ฝั่งขวาบนของจอคนดู -> เห็นลูกพุ่งลงทั้งเส้นทาง)
	magicCircle(pos, d.Radius, col.Main, fall + 0.4)
	local cam = Workspace.CurrentCamera
	local right = cam and V(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z) or V(1, 0, 0)
	right = right.Magnitude > 0.01 and right.Unit or V(1, 0, 0)
	local sky = pos + right * 45 + V(0, 70, 0)
	vfx("Portal", CFrame.lookAt(sky, pos), { Scale = 2.2, Duration = fall + 0.3, Burst = 1, Tint = col.Main })
	vfx("Aura", sky, { Scale = 3, Duration = fall, Tint = col.Main })
	flash(sky, col.Main, 80, fall + 0.3, 5)
	-- ลูกอุกกาบาต: แกนดำ + เปลือกไฟม่วง + หางควัน
	local core = part({ Shape = Enum.PartType.Ball, Size = V(13, 13, 13), Color = C(25, 5, 40), Material = Enum.Material.Basalt, CFrame = CF(sky) })
	local shell = part({ Shape = Enum.PartType.Ball, Size = V(19, 19, 19), Color = col.Main, Material = Enum.Material.ForceField, Transparency = 0.1, CFrame = CF(sky) })
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 25, 25, col.Main, C(20, 0, 30)
	fire.Parent = core
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = TEX.Smoke
	smoke.Color = ColorSequence.new(C(70, 20, 110), C(15, 0, 25))
	smoke.Rate = 120
	smoke.Lifetime = NumberRange.new(0.8, 1.4)
	smoke.Speed = NumberRange.new(2, 6)
	smoke.Size = NS({ NSK(0, 10), NSK(1, 22) })
	smoke.Transparency = NS({ NSK(0, 0.3), NSK(1, 1) })
	smoke.Parent = core
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = col.Main, 60, 6
	l.Parent = core
	local ball = vfx("Ball", CFrame.lookAt(sky, pos), { Scale = 5, Duration = fall + 0.2, Tint = col.Main, Follow = core })
	-- ล็อกเป้า: ลูกพุ่งตามตัวมอน (Target) ทุกเฟรมจนตก · จุดกระแทก = ตำแหน่งเป้าตอนตก
	local target = typeof(d.Target) == "Instance" and d.Target or nil
	local function dest()
		local tr = target and target.Parent and (target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart"))
		if tr then
			return V(tr.Position.X, pos.Y + (tr.Position.Y - pos.Y) * 0.3, tr.Position.Z)
		end
		return pos
	end
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < fall and core.Parent do
			local k = (os.clock() - t0) / fall
			local p = sky:Lerp(dest(), k * k)
			core.CFrame, shell.CFrame = CF(p), CF(p)
			RunService.Heartbeat:Wait()
		end
	end)
	sound("Slash", pos, 0.9, 0.45)
	task.delay(fall, function()
		pos = dest()
		core:Destroy()
		shell:Destroy()
		if ball then
			ball:Destroy()
		end
		-- กระแทก: แสงวาบ ระเบิดใหญ่ แผ่นดินแยก คลื่นกระแทกซ้อน เศษหิน เสาแสง
		flash(pos + V(0, 6, 0), col.Main, 120, 1.2, 12)
		vfx("Blast", CF(pos), { Scale = 1.8, Duration = 0.5, Burst = 1, Tint = col.Main })
		vfx("BigExplosion", CF(pos), { Scale = 3, Duration = 0.5, Burst = 1, Tint = col.Main })
		vfx("BigCrack", CF(pos), { Scale = 2.8, Duration = 0.4, Burst = 1, Tint = col.Main })
		pillar(pos, d.Radius * 0.9, 140, col.Core, 1)
		shockwave(pos, d.Radius * 2.2, col.Main, 0.7, 1.2)
		task.delay(0.15, function()
			shockwave(pos, d.Radius * 3, col.Core, 0.9, 0.5)
		end)
		debris(pos, C(40, 20, 60), 26, 65, 1.9)
		burst(pos + V(0, 2, 0), { Texture = TEX.Spark, Color = ColorSequence.new(col.Core, col.Main), Speed = NumberRange.new(40, 80), Lifetime = NumberRange.new(0.5, 1), Size = NS({ NSK(0, 2), NSK(1, 0) }), LightEmission = 1, Drag = 3, Acceleration = V(0, -20, 0) }, 90)
		shake(pos, 1.1, 0.6)
		sound("Boom", pos, 1, 0.5)
		-- วงไฟมืด 10 วิ: พื้นวงม่วง ขอบเรือง เปลวไฟมืดรอบวง ประกายลอยขึ้น
		local zone = d.Zone
		local disc = part({ Shape = Enum.PartType.Cylinder, Size = V(0.3, zone * 2, zone * 2), Color = C(60, 15, 100), Transparency = 0.55 })
		disc.CFrame = CF(pos + V(0, 0.2, 0)) * ANG(0, 0, math.pi / 2)
		local ring = magicCircle(pos, zone, col.Main, d.Duration)
		local flames = {}
		for i = 1, 14 do
			local a = i / 14 * math.pi * 2
			local fp = part({ Size = V(1, 1, 1), Transparency = 1, Position = pos + V(math.cos(a) * zone * 0.85, 0.5, math.sin(a) * zone * 0.85) })
			local f = Instance.new("ParticleEmitter")
			f.Texture = TEX.Fire
			f.Color = ColorSequence.new(col.Main, C(30, 0, 50))
			f.Rate = 35
			f.Lifetime = NumberRange.new(0.6, 1.1)
			f.Speed = NumberRange.new(4, 9)
			f.SpreadAngle = Vector2.new(12, 12)
			f.Size = NS({ NSK(0, 3), NSK(1, 0.5) })
			f.LightEmission = 0.9
			f.Parent = fp
			table.insert(flames, fp)
		end
		local embers = Instance.new("ParticleEmitter")
		embers.Texture = TEX.Spark
		embers.Shape = Enum.ParticleEmitterShape.Cylinder
		embers.Color = ColorSequence.new(col.Core, col.Main)
		embers.Rate = 60
		embers.Lifetime = NumberRange.new(1, 2)
		embers.Speed = NumberRange.new(3, 8)
		embers.Size = NS({ NSK(0, 0.7), NSK(1, 0) })
		embers.LightEmission = 1
		embers.Acceleration = V(0, 6, 0)
		embers.Parent = disc
		local zl = Instance.new("PointLight")
		zl.Color, zl.Range, zl.Brightness = col.Main, zone * 1.6, 2.5
		zl.Parent = disc
		task.delay(d.Duration - 0.8, function()
			embers.Enabled = false
			for _, fp in ipairs(flames) do
				local f = fp:FindFirstChildOfClass("ParticleEmitter")
				if f then
					f.Enabled = false
				end
			end
			tween(disc, 0.8, { Transparency = 1 })
			tween(zl, 0.8, { Brightness = 0 })
		end)
		Debris:AddItem(disc, d.Duration + 0.2)
		for _, fp in ipairs(flames) do
			Debris:AddItem(fp, d.Duration + 1.5)
		end
		local _ = ring
	end)
end

---------------------------------------------------------------- พงไพร: เทพแห่งพงไพร + หนามพันธนาการ
local function onThornBind(d)
	local col = COL.Verdant
	local char = charOf(d.Player)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local pos = d.Position - V(0, 2.6, 0)
	local look = root and root.CFrame.LookVector or V(0, 0, -1)
	look = V(look.X, 0, look.Z).Unit
	magicCircle(pos, (d.Radius or 26) * 0.95, col.Main, 2.8) -- วงเวทเท่าขอบเขตสกิลจริง
	magicCircle(pos + V(0, 0.15, 0), 10, col.Core, 2.4)
	darkenSky(pos, C(215, 255, 215), 1.8)
	-- เทพ: ร่างยักษ์โปร่งแสงของพงไพร ผุดจากดินด้านหลังผู้ใช้
	local ok, ClassAvatars = pcall(require, script.Parent:WaitForChild("ClassAvatars"))
	local deity = ok and ClassAvatars.Build("Sage")
	if deity then
		for _, p in ipairs(deity:GetDescendants()) do
			if p:IsA("SurfaceAppearance") or p:IsA("Decal") or p:IsA("Texture") then
				p:Destroy()
			elseif p:IsA("BasePart") then
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
				p.Material = Enum.Material.SmoothPlastic
				p.Color = C(120, 255, 140)
				p.Transparency = 0.55
				if p:IsA("MeshPart") then
					p.TextureID = ""
				end
			end
		end
		pcall(function()
			deity:ScaleTo(deity:GetScale() * 4.6)
		end)
		local hl = Instance.new("Highlight")
		hl.FillColor = col.Main
		hl.FillTransparency = 0.55
		hl.OutlineColor = col.Core
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = deity
		local spot = pos + look * 13
		local face = CFrame.lookAt(spot, spot - look) -- หันหน้ามาหาผู้ใช้/กล้อง
		deity:PivotTo(face * CF(0, -30, 0))
		deity.Parent = folder()
		local glow = part({ Size = V(1, 1, 1), Transparency = 1, Position = spot + V(0, 16, 0) })
		local gl = Instance.new("PointLight")
		gl.Color, gl.Range, gl.Brightness = col.Main, 60, 5
		gl.Parent = glow
		local leaves = Instance.new("ParticleEmitter")
		leaves.Texture = TEX.Spark
		leaves.Shape = Enum.ParticleEmitterShape.Sphere
		leaves.Color = ColorSequence.new(col.Core, col.Main)
		leaves.Rate = 35
		leaves.Lifetime = NumberRange.new(1, 1.8)
		leaves.Speed = NumberRange.new(3, 8)
		leaves.Size = NS({ NSK(0, 1.2), NSK(1, 0) })
		leaves.LightEmission = 1
		leaves.Parent = glow
		-- ผุดขึ้น 0.6 วิ
		local t0 = os.clock()
		task.spawn(function()
			while deity.Parent and os.clock() - t0 < 2.4 do
				local t = os.clock() - t0
				local rise = math.min(1, t / 0.6)
				local y = -30 * (1 - rise) ^ 2 + math.sin(t * 3) * 0.8
				deity:PivotTo(face * CF(0, y, 0))
				task.wait()
			end
		end)
		pillar(spot + look * 4, 7, 110, col.Main, 0.8) -- ลำแสงบางด้านหลังเทพ (ไม่บังตัวเทพ)
		burst(spot, { Texture = TEX.Smoke, Color = ColorSequence.new(C(90, 70, 50)), Speed = NumberRange.new(10, 20), Lifetime = NumberRange.new(0.8, 1.3), Size = NS({ NSK(0, 4), NSK(1, 9) }), Transparency = NS({ NSK(0, 0.3), NSK(1, 1) }) }, 30)
		task.delay(2, function()
			for _, p in ipairs(deity:GetDescendants()) do
				if p:IsA("BasePart") then
					tween(p, 0.5, { Transparency = 1 })
				end
			end
			tween(hl, 0.5, { FillTransparency = 1, OutlineTransparency = 1 })
			leaves.Enabled = false
			tween(gl, 0.5, { Brightness = 0 })
		end)
		Debris:AddItem(deity, 2.6)
		Debris:AddItem(glow, 3.5)
	end
	-- ฟาดพื้น (0.6 วิ): แผ่นดินแยกสีเขียว คลื่นสองชั้น เศษดิน
	task.delay(0.6, function()
		local R = d.Radius or 26
		vfx("BigCrack", CF(pos), { Scale = 1.8 * R / 26, Duration = 0.4, Burst = 1, Tint = col.Main })
		shockwave(pos, R, col.Main, 0.7, 1)
		-- คลื่นหนามแทงขึ้นจากดิน ไล่จากกลางออกไปถึงขอบวง (เห็นชัดว่าโดนทั้งวง)
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { Workspace.Terrain }
		for k = 1, 6 do
			task.delay(k * 0.07, function()
				local r = R * k / 6
				local n = math.floor(r * 0.55) + 4
				for i = 1, n do
					local a = (i + math.random() * 0.6) / n * math.pi * 2
					local p = pos + V(math.cos(a) * r, 0, math.sin(a) * r)
					local hit = Workspace:Raycast(p + V(0, 30, 0), V(0, -60, 0), rp)
					local gy = hit and hit.Position.Y or pos.Y
					local spike, h = thornMesh("Spike", 3.5 + math.random() * 4, i + k)
					local up = CFrame.lookAt(V(p.X, gy, p.Z), V(pos.X, gy, pos.Z)) * ANG(math.rad(math.random(-15, 15)), 0, 0)
					spike.CFrame = up * CF(0, -h / 2 - 0.5, 0)
					tween(spike, 0.12, { CFrame = up * CF(0, h / 2 - 0.3, 0) }, Enum.EasingStyle.Back)
					task.delay(1.1 + math.random() * 0.3, function()
						tween(spike, 0.4, { CFrame = up * CF(0, -h / 2 - 0.5, 0), Transparency = 1 })
					end)
					Debris:AddItem(spike, 2)
				end
			end)
		end
		task.delay(0.12, function()
			shockwave(pos, d.Radius * 1.2, col.Core, 0.8, 0.4)
		end)
		debris(pos, C(90, 70, 45), 20, 55, 1.3)
		burst(pos + V(0, 1, 0), { Texture = TEX.Spark, Color = ColorSequence.new(C(140, 240, 100), C(60, 150, 40)), Speed = NumberRange.new(35, 75), Lifetime = NumberRange.new(0.8, 1.4), Size = NS({ NSK(0, 1.4), NSK(1, 0.3) }), Acceleration = V(0, -25, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300) }, 110)
		flash(pos + V(0, 4, 0), col.Main, 70, 0.8, 8)
		shake(pos, 0.7, 0.45)
		sound("Boom", pos, 0.9, 0.7)
	end)
end

-- มอนที่โดน: หนามแทงขึ้นรอบตัว (ค้างจนหมดสตั้น) + หมอกพิษ/ฟองพิษจนพิษหมด
local function onThornMark(d)
	local model = d.Model
	local root = typeof(model) == "Instance" and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true))
	if not root then
		return
	end
	task.wait(0.6) -- ให้ตรงจังหวะเทพฟาดพื้น
	if not root.Parent then
		return
	end
	local size = model:GetExtentsSize()
	local r = math.max(size.X, size.Z) * 0.55 + 1
	local ground = root.Position - V(0, size.Y / 2, 0)
	local thorns = {}
	-- เถาหนามโค้ง (เมชเขาหนามคู่) 4 ชุดรอบตัว โค้งเข้าหาตัวมอน = ถูกรัด
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + math.random() * 0.3
		local t, h = thornMesh("Horns", math.clamp(size.Y * 0.9 + 2, 4, 14), i)
		local base = CFrame.lookAt(ground + V(math.cos(a) * r * 0.7, 0, math.sin(a) * r * 0.7), ground) * ANG(0, math.rad(90), 0)
		t.CFrame = base * CF(0, -h / 2 - 1, 0)
		tween(t, 0.22, { CFrame = base * CF(0, h / 2 - 0.6, 0) }, Enum.EasingStyle.Back)
		table.insert(thorns, { t, base, h })
	end
	-- หนามแทงขึ้นรอบตัว (เมชแท่งหนาม)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local t, h = thornMesh("Spike", math.min(3 + math.random() * 2 + size.Y * 0.3, 10), i)
		local base = CFrame.lookAt(ground + V(math.cos(a) * r, 0, math.sin(a) * r), ground) * ANG(math.rad(-22), 0, 0)
		t.CFrame = base * CF(0, -h / 2 - 1, 0)
		tween(t, 0.18, { CFrame = base * CF(0, h / 2 - 0.5, 0) }, Enum.EasingStyle.Back)
		table.insert(thorns, { t, base, h })
	end
	vfx("Crack", ground, { Scale = 0.6 + r * 0.05, Duration = 0.3, Burst = 1, Tint = COL.Verdant.Main })
	burst(ground + V(0, 1, 0), { Texture = TEX.Spark, Color = ColorSequence.new(COL.Verdant.Core, COL.Verdant.Main), Speed = NumberRange.new(8, 16), Lifetime = NumberRange.new(0.3, 0.6), Size = NS({ NSK(0, 1), NSK(1, 0) }), LightEmission = 1 }, 20)
	task.delay(math.max(0.3, (d.Stun or 4) - 0.6), function()
		for _, e in ipairs(thorns) do
			if e[1].Parent then
				tween(e[1], 0.35, { CFrame = e[2] * CF(0, -e[3] / 2 - 1, 0), Transparency = 1 })
			end
		end
	end)
	for _, e in ipairs(thorns) do
		Debris:AddItem(e[1], (d.Stun or 4) + 0.2)
	end
	-- พิษ: หมอกเขียว + ฟองลอยขึ้นจากตัวจนหมดพิษ
	local att = Instance.new("Attachment")
	att.Parent = root
	local fog = Instance.new("ParticleEmitter")
	fog.Texture = TEX.Smoke
	fog.Color = ColorSequence.new(C(130, 230, 70), C(60, 120, 30))
	fog.Rate = 10
	fog.Lifetime = NumberRange.new(0.9, 1.4)
	fog.Speed = NumberRange.new(1, 2.5)
	fog.Size = NS({ NSK(0, size.Y * 0.3), NSK(1, size.Y * 0.6) })
	fog.Transparency = NS({ NSK(0, 0.5), NSK(1, 1) })
	fog.Parent = att
	local bub = Instance.new("ParticleEmitter")
	bub.Texture = TEX.Spark
	bub.Color = ColorSequence.new(C(170, 255, 90))
	bub.Rate = 14
	bub.Lifetime = NumberRange.new(0.6, 1)
	bub.Speed = NumberRange.new(2, 5)
	bub.Size = NS({ NSK(0, 0.5), NSK(1, 0.1) })
	bub.LightEmission = 0.8
	bub.Acceleration = V(0, 5, 0)
	bub.Parent = att
	Debris:AddItem(att, d.Poison or 15)
end

---------------------------------------------------------------- เริ่มต้น
local HANDLERS = {
	ClassSwing = onSwing, ClassHit = onHit,
	SkillSwarm = onSwarm, BatBite = onBatBite, BatGuard = onBatGuard,
	SkillVeil = onVeil, SkillDarkMeteor = onDarkMeteor,
	SkillThornBind = onThornBind, SkillThornMark = onThornMark, BatDrain = onBatDrain, Burning = onBurning,
}

-- เล่นเอฟเฟกต์ตรงๆ (ใช้ในเทส: ยิงเอฟเฟกต์ให้ตรงจังหวะถ่ายภาพ)
function ClassFX.Play(kind, d)
	local h = HANDLERS[kind]
	if h then
		task.spawn(h, d)
	end
end

function ClassFX.Init(combat)
	ClassFX.Combat = combat
	Remotes.Get("HitFx").OnClientEvent:Connect(function(kind, d)
		local h = HANDLERS[kind]
		if h and type(d) == "table" then
			task.spawn(h, d)
		end
	end)
	-- ค้างคาวแวมไพร์: ขอบเรืองแดง + หางแสง + แสงแดง (มองเห็นชัดตอนบินวน)
	local function dressBat(m)
		task.wait(0.1)
		local torso = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
		if not torso then
			return
		end
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = V(0, 0.4, 0), V(0, -0.4, 0)
		a0.Parent, a1.Parent = torso, torso
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = ColorSequence.new(C(255, 60, 80), C(120, 0, 20))
		tr.Transparency = NS({ NSK(0, 0.2), NSK(1, 1) })
		tr.Lifetime = 0.35
		tr.LightEmission = 1
		tr.Parent = torso
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = C(255, 40, 60), 10, 2
		l.Parent = torso
		-- ขอบเรืองแดง (ไม่ทาทับตัว)
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.OutlineColor = C(255, 40, 70)
		hl.OutlineTransparency = 0.15
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = m
		-- ออร่าควันเลือดรอบตัว + ประกายถ่านแดงร่วง
		local aura = Instance.new("ParticleEmitter")
		aura.Texture = TEX.Smoke
		aura.Color = ColorSequence.new(C(140, 0, 25), C(30, 0, 8))
		aura.Rate = 14
		aura.Lifetime = NumberRange.new(0.5, 0.9)
		aura.Speed = NumberRange.new(0.5, 1.5)
		aura.Size = NS({ NSK(0, 1.2), NSK(1, 2.6) })
		aura.Transparency = NS({ NSK(0, 0.55), NSK(1, 1) })
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Parent = torso
		local ember = Instance.new("ParticleEmitter")
		ember.Texture = TEX.Spark
		ember.Color = ColorSequence.new(C(255, 120, 130), C(200, 0, 30))
		ember.Rate = 10
		ember.Lifetime = NumberRange.new(0.5, 1)
		ember.Speed = NumberRange.new(1, 3)
		ember.Acceleration = V(0, -6, 0)
		ember.Size = NS({ NSK(0, 0.35), NSK(1, 0) })
		ember.LightEmission = 1
		ember.SpreadAngle = Vector2.new(180, 180)
		ember.Parent = torso
		-- ตาแดงเรืองทั้งสองด้านของหัว
		local sz = torso.Size
		for _, zs in ipairs({ -1, 1 }) do
			for _, xs in ipairs({ -1, 1 }) do
				local eye = Instance.new("Part")
				eye.Shape = Enum.PartType.Ball
				eye.Size = V(0.2, 0.2, 0.2) * math.max(sz.X / 0.52, 1)
				eye.Material = Enum.Material.Neon
				eye.Color = C(255, 30, 40)
				eye.CanCollide, eye.CanQuery, eye.CanTouch, eye.Massless, eye.CastShadow = false, false, false, true, false
				eye.CFrame = torso.CFrame * CF(xs * sz.X * 0.2, sz.Y * 0.36, zs * sz.Z * 0.48)
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = torso, eye
				w.Parent = eye
				eye.Parent = m
			end
		end
		-- หางแสงที่ปลายปีก (กระพือแล้วเป็นเส้นแดงโค้ง)
		for _, wing in ipairs(m:GetChildren()) do
			if wing:IsA("BasePart") and wing.Name:find("Wing") and not wing.Name:find("Back") then
				local tipX = (torso.CFrame:PointToObjectSpace(wing.Position).X >= 0 and 1 or -1)
				local outward = wing.CFrame:VectorToObjectSpace(torso.CFrame.RightVector * tipX)
				local t0, t1 = Instance.new("Attachment"), Instance.new("Attachment")
				t0.Position = outward * wing.Size.X * 0.45 + V(0, wing.Size.Y * 0.2, 0)
				t1.Position = outward * wing.Size.X * 0.45 - V(0, wing.Size.Y * 0.2, 0)
				t0.Parent, t1.Parent = wing, wing
				local wt = Instance.new("Trail")
				wt.Attachment0, wt.Attachment1 = t0, t1
				wt.Color = ColorSequence.new(C(255, 80, 100), C(150, 0, 25))
				wt.Transparency = NS({ NSK(0, 0.3), NSK(1, 1) })
				wt.Lifetime = 0.25
				wt.LightEmission = 1
				wt.Parent = wing
			end
		end
	end
	task.spawn(function()
		local sm = Workspace:WaitForChild("Summons", 120)
		if not sm then
			return
		end
		for _, m in ipairs(sm:GetChildren()) do
			task.spawn(dressBat, m)
		end
		sm.ChildAdded:Connect(function(m)
			task.spawn(dressBat, m)
		end)
	end)
	-- ลูกพลังคทาของคลาส: แต่งหาง/แสงตามสี
	task.spawn(function()
		local fx = Workspace:WaitForChild("FX", 60)
		if not fx then
			return
		end
		fx.ChildAdded:Connect(function(p)
			local kind = p:IsA("BasePart") and p:GetAttribute("FxKind")
			if kind then
				dressBolt(p, kind)
			end
		end)
	end)
end

return ClassFX
