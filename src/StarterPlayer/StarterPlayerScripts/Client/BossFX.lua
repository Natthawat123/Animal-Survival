--[[
	BossFX — เอฟเฟกต์สกิลบอส + ออร่าประจำตัว (วาดฝั่ง client ทั้งหมด เซิร์ฟเวอร์ส่งแค่ตำแหน่ง/เวลา)
	ใช้อนุภาคจริงจากคลัง VFX (VFXLib: แพ็กจาก Creator Store) + โมเดลก้อนหินจริง แทนรูปทรงพื้นฐาน
	  BossTelegraph · BossImpact · BossSpikes · BossWave · BossBreath · BossBlizzard
	  BossFX.Aura(model, element) · BossFX.Footstep(pos, scale, element)
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local VFXLib = require(script.Parent:WaitForChild("VFXLib"))

local BossFX = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local C = Color3.fromRGB
local NS, NSK = NumberSequence.new, NumberSequenceKeypoint.new

local TEX = {
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}

-- เอฟเฟกต์ในคลัง (ทดสอบแล้วว่าแสดงผลได้)
local FX = {
	Blast = "LightBlast/SUPER ANIME LIGHT GOLDEN BLAST/FireMegaExplosion",
	BlastWind = "LightBlast/SUPER ANIME LIGHT GOLDEN BLAST/WindBig",
	RockRing = "VFXPack/vfx pack/f",
	Explosion = "VFXPack/Anime/Realistic-Explosion-01",
	Fire1 = "VFXPack/Anime/Fire-01",
	Fire2 = "VFXPack/Anime/Fire-02",
	Fire3 = "VFXPack/Anime/Fire-03",
	Flamethrower = "VFXPack/Anime/Flamethrower-01",
	FireBall = "VFXPack/Big/Ball-01",
	Tornado = "VFXPack/Big/Tornado-01",
	Ice = "IceStomp",
	WaterSwirl = "VFXPack/Auras/Water-Aura-01",
	Crack = "VFXPack/Anime/Crack-01",
	RealFire = "RealFire/particles/the beutiful fire",
	-- น้ำของจริงจาก Creator Store (อนุภาค)
	Splash = "WaterSplash", -- น้ำกระเซ็นพุ่งสมจริง
	WaterBurst = "WaterBurst", -- ระเบิดน้ำ: วงคลื่น + เสาน้ำ
}
-- เมชเอฟเฟกต์น้ำ (ต้องเห็นชิ้นส่วนจริง ไม่ผ่าน VFXLib ที่ซ่อนชิ้นส่วน)
local MESH = {
	Tornado = "WaterTornado", -- กรวยพายุน้ำหมุน
	SplashMesh = "WaterMeshPack/Hybrid's Water VFX Pack/WaterSplash",
	SplashMesh2 = "WaterMeshPack/Hybrid's Water VFX Pack/WaterSplash2",
	Dome = "WaterMeshPack/Hybrid's Water VFX Pack/WaterExplosion1",
	Twist = "WaterMeshPack/Hybrid's Water VFX Pack/TwistY1",
}

-- สีย้อมเอฟเฟกต์ / สีเศษ / วัสดุเศษ ตามธาตุ
local STYLE = {
	Earth = { Tint = C(230, 170, 80), Main = C(170, 230, 90), Debris = C(112, 98, 82), Mat = Enum.Material.Slate, Dust = C(150, 130, 100) },
	Water = { Tint = C(80, 190, 255), Main = C(80, 200, 255), Debris = C(150, 215, 245), Mat = Enum.Material.Glass, Dust = C(210, 240, 255) },
	Air = { Tint = C(150, 220, 255), Main = C(160, 220, 255), Debris = C(190, 230, 255), Mat = Enum.Material.Ice, Dust = C(235, 245, 255) },
	Fire = { Main = C(255, 110, 30), Debris = C(58, 40, 36), Mat = Enum.Material.Basalt, Dust = C(90, 70, 60) },
}

local function style(el)
	return STYLE[el] or STYLE.Earth
end

local function folder()
	local f = Workspace:FindFirstChild("BossFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "BossFX"
		f.Parent = Workspace
	end
	return f
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = folder()
	return p
end

local function tween(obj, t, goal, s, d)
	local tw = TweenService:Create(obj, TweenInfo.new(t, s or Enum.EasingStyle.Quad, d or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function emitAt(pos, props, count, life)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = Workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = a
	e:Emit(count)
	Debris:AddItem(a, life or 4)
	return e
end

-- สั่นเฉพาะคนที่ยืนอยู่ในเขตที่บอสทุบ (วงรัศมี + ขอบ 3 studs) · นอกเขต = ไม่สั่น (เดิมสั่นไกลเกือบทั้งแมพ)
local function shakeFor(pos, radius, power)
	local char = game:GetService("Players").LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not BossFX.ZoneShake then
		return
	end
	local flat = (root.Position - pos) * Vector3.new(1, 0, 1)
	if flat.Magnitude > radius + 3 or math.abs(root.Position.Y - pos.Y) > radius + 12 then
		return
	end
	BossFX.ZoneShake(power * 0.5, 0.35)
end

local function play(name, cf, opts)
	return VFXLib.Play(FX[name] or name, cf, opts)
end

-- เมช VFX ของจริง (Assets.VFX/<path>) วางเท้าที่ cf สูง height · คืน model (ผู้เรียกสั่งหมุน/จางเอง) · หายเองหลัง life วินาที
local function meshFx(name, cf, height, life)
	local src = VFXLib.Find(MESH[name] or name)
	if not src then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "MeshFX_" .. name
	local c = src:Clone()
	c.Parent = m
	-- พายุน้ำ: ตัดกล่องเมฆ/ท้องฟ้าน้ำขนาดใหญ่ ("Storm") ออก (เคยย้อมทั้งจอเป็นสีฟ้า) เหลือแค่กรวยน้ำ
	for _, d in ipairs(c:GetDescendants()) do
		if d.Name == "Storm" then
			d:Destroy()
		end
	end
	-- กันเมชยักษ์: ชิ้นที่ SpecialMesh สเกลเกิน 5000 (เช่น "Tornado part" ของพายุน้ำ = จานน้ำวน Scale 100000)
	--   พอย่อ/ขยายโมเดลแล้วกว้างเป็นหลายพัน stud -> น้ำวนบังทั้งแมพ · ตัดทิ้ง เหลือกรวยหลัก (Car1)
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("SpecialMesh") and d.Parent and d.Parent ~= c and math.max(math.abs(d.Scale.X), math.abs(d.Scale.Y), math.abs(d.Scale.Z)) > 5000 then
			d.Parent:Destroy()
		end
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			-- (ชิ้น "Car1" ของพายุน้ำ = กรวยหลัก ทุกชิ้นอยู่ข้างใต้ ห้ามลบ)
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		elseif d:IsA("LuaSourceContainer") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	if name == "Twist" then
		-- เกลียวน้ำ: ในแพ็กชิ้นเมชถูกบีบเป็นลูกบาศก์ (5x5x5) ทั้งที่เมชจริงสูงกว่ากว้าง (13x22x14)
		--   -> เกลียวแบนเป็นก้อนหนามนอนราบ · คืนสัดส่วนเดิมของเมช ให้ตั้งเป็นเกลียวสูง
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("MeshPart") then
				local ok, ms = pcall(function()
					return d.MeshSize
				end)
				if ok and ms and ms.Magnitude > 0 then
					local k = math.max(d.Size.X, d.Size.Z) / math.max(ms.X, ms.Z, 0.01)
					local center = d.CFrame
					d.Size = ms * k
					d.CFrame = center
				end
			end
		end
	end
	local bcf, size = m:GetBoundingBox()
	-- กรวยพายุ/เกลียวน้ำ: โมเดลบางชิ้นเก็บแบบนอน -> หมุนให้แกนยาวสุดตั้งขึ้น (เคยเห็นพายุนอนราบบนพื้น)
	if (name == "Tornado" or name == "Twist") and size.Y < math.max(size.X, size.Z) then
		local rot = size.X >= size.Z and ANG(0, 0, math.pi / 2) or ANG(math.pi / 2, 0, 0)
		local c = CF(bcf.Position)
		m:PivotTo(c * rot * c:ToObjectSpace(m:GetPivot())) -- หมุนรอบจุดกลางกล่อง
		bcf, size = m:GetBoundingBox()
	end
	m.WorldPivot = CF(bcf.Position - V(0, size.Y / 2, 0))
	pcall(function()
		m:ScaleTo(m:GetScale() * height / math.max(size.Y, 0.1))
	end)
	m:PivotTo(cf)
	m.Parent = folder()
	Debris:AddItem(m, life or 3)
	return m
end

-- จางเมชทั้งชิ้นลงในเวลา t (โปร่งใสขึ้นจากค่าเดิม)
local function fadeModel(m, t, delayT)
	task.delay(delayT or 0, function()
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				tween(d, t, { Transparency = 1 })
			elseif d:IsA("Decal") then
				tween(d, t, { Transparency = 1 })
			elseif d:IsA("ParticleEmitter") then
				d.Enabled = false
			end
		end
	end)
end

-- หมุนรอบแกนตั้งต่อเนื่อง (พายุน้ำ)
local function spinModel(m, speed, dur, rise)
	local base = m:GetPivot()
	local t0 = os.clock()
	task.spawn(function()
		while m.Parent and os.clock() - t0 < dur do
			local t = os.clock() - t0
			m:PivotTo(base * CF(0, (rise or 0) * math.min(t / 0.35, 1), 0) * ANG(0, t * speed, 0))
			task.wait()
		end
	end)
end

-- น้ำกระเซ็นจริง (อนุภาคจาก Store "WaterSplash") คุมเอง: ทิศพุ่ง = แกน +Y ของ cf · speed/life/ขนาด/แรงโน้มถ่วง
--   (ผ่าน VFXLib + ScaleTo แล้วความเร็วโดนขยายตาม -> ละอองพุ่งขึ้นฟ้าไกลเกิน)
local splashTpl
local function spray(cf, o)
	if splashTpl == nil then
		local src = VFXLib.Find("WaterSplash")
		splashTpl = src and src:FindFirstChildWhichIsA("ParticleEmitter", true) or false
	end
	local a = Instance.new("Attachment")
	a.Parent = Workspace.Terrain
	a.WorldCFrame = cf
	local e
	if splashTpl then
		e = splashTpl:Clone()
		local ks = {}
		for _, k in ipairs(splashTpl.Size.Keypoints) do
			table.insert(ks, NSK(k.Time, k.Value * (o.Scale or 3), k.Envelope * (o.Scale or 3)))
		end
		e.Size = NS(ks)
	else
		e = Instance.new("ParticleEmitter")
		e.Texture = TEX.Smoke
		e.Color = ColorSequence.new(C(200, 235, 255))
		e.Size = NS({ NSK(0, 1.5 * (o.Scale or 3)), NSK(1, 3 * (o.Scale or 3)) })
		e.Transparency = NS({ NSK(0, 0.3), NSK(1, 1) })
	end
	e.EmissionDirection = Enum.NormalId.Top
	e.Speed = NumberRange.new((o.Speed or 20) * 0.8, o.Speed or 20)
	e.Lifetime = NumberRange.new((o.Life or 1) * 0.7, o.Life or 1)
	e.Acceleration = V(0, -(o.Gravity or 40), 0)
	e.SpreadAngle = Vector2.new(o.Spread or 20, o.Spread or 20)
	e.Rate = o.Rate or 0
	e.Enabled = (o.Rate or 0) > 0
	e.Parent = a
	if o.Burst then
		e:Emit(o.Burst)
	end
	Debris:AddItem(a, (o.Time or 0) + (o.Life or 1) + 0.5)
	if o.Time then
		task.delay(o.Time, function()
			e.Enabled = false
		end)
	end
	return a, e
end

-- ก้อนหิน/ผลึกจริง (โมเดล RockLP)
local rockList
local function rock(size, el)
	if not rockList then
		rockList = {}
		local a = ReplicatedStorage:FindFirstChild("Assets")
		local pack = a and a:FindFirstChild("Props") and a.Props:FindFirstChild("RockLP")
		for _, d in ipairs(pack and pack:GetDescendants() or {}) do
			if d:IsA("MeshPart") then
				table.insert(rockList, d)
			end
		end
	end
	local src = rockList[math.random(1, math.max(#rockList, 1))]
	local s = style(el)
	local r
	if src then
		r = src:Clone()
		r:ClearAllChildren()
		r.Size = size
	else
		r = Instance.new("Part")
		r.Size = size
	end
	r.Color = s.Debris
	r.Material = s.Mat
	if el == "Air" then
		r.Transparency = 0.15
		r.Reflectance = 0.2
	elseif el == "Water" then
		r.Transparency = 0.35
	end
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.CanTouch = false
	r.CastShadow = true
	return r
end

---------------------------------------------------------------- วงเตือน (บางๆ พอให้รู้ว่าต้องหลบ)
local function circleTele(d)
	local s = style(d.Element)
	local r, t = d.Radius, d.Time
	local base = CF(d.Pos + V(0, 0.12, 0)) * ANG(0, 0, math.pi / 2)
	local edge = part({ Shape = Enum.PartType.Cylinder, Size = V(0.15, r * 2, r * 2), CFrame = base, Color = C(255, 70, 50), Transparency = 0.7 })
	local inner = part({ Shape = Enum.PartType.Cylinder, Size = V(0.17, r * 2 - 1, r * 2 - 1), CFrame = base, Color = C(10, 6, 6), Transparency = 0.7 })
	local fill = part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 0.5, 0.5), CFrame = base, Color = s.Main, Transparency = 0.55 })
	tween(fill, t, { Size = V(0.2, r * 2 - 1, r * 2 - 1) }, Enum.EasingStyle.Linear)
	tween(edge, t, { Transparency = 0.35 }, Enum.EasingStyle.Linear)
	local parts = { edge, inner, fill }
	if d.Inner and d.Inner > 1 then
		-- วงแหวน: ข้างในปลอดภัย (แผ่นเข้มทับตรงกลาง + ขอบในสีขาว)
		local ri = d.Inner
		table.insert(parts, part({ Shape = Enum.PartType.Cylinder, Size = V(0.3, ri * 2, ri * 2), CFrame = base * CF(0.12, 0, 0), Color = C(12, 10, 14), Transparency = 0.25 }))
		table.insert(parts, part({ Shape = Enum.PartType.Cylinder, Size = V(0.26, ri * 2 + 1.2, ri * 2 + 1.2), CFrame = base * CF(0.1, 0, 0), Color = C(255, 240, 220), Transparency = 0.45 }))
	end
	for _, p in ipairs(parts) do
		Debris:AddItem(p, t + 0.1)
	end
end

local function lineTele(d)
	local s = style(d.Element)
	local look = CF(d.Pos, d.Pos + d.Dir)
	local mid = look * CF(0, 0.12, -d.Length / 2)
	local edge = part({ Size = V(d.Width, 0.15, d.Length), CFrame = mid, Color = C(255, 70, 50), Transparency = 0.7 })
	local fill = part({ Size = V(d.Width - 1, 0.2, 0.5), CFrame = look * CF(0, 0.15, -0.25), Color = s.Main, Transparency = 0.55 })
	tween(fill, d.Time, { Size = V(d.Width - 1, 0.2, d.Length), CFrame = mid * CF(0, 0.03, 0) }, Enum.EasingStyle.Linear)
	tween(edge, d.Time, { Transparency = 0.35 }, Enum.EasingStyle.Linear)
	Debris:AddItem(edge, d.Time + 0.1)
	Debris:AddItem(fill, d.Time + 0.1)
end

-- ม่อนเล็กพุ่งชน/ตะครุบ: แถบเตือนแนบพื้นตามเนิน (ท่อนละ ~4 stud) สีธาตุไล่จากตัวม่อนไปปลายทาง + หัวลูกศรปลายทาง
local mobRay = RaycastParams.new()
mobRay.FilterType = Enum.RaycastFilterType.Include
mobRay.FilterDescendantsInstances = { Workspace.Terrain }
local function mobLineTele(d)
	local s = style(d.Element)
	local dir = (d.Dir * V(1, 0, 1)).Unit
	local n = math.max(2, math.ceil(d.Length / 4))
	local seg = d.Length / n
	local function onGround(dist, lift)
		local c = d.Pos + dir * dist
		local hit = Workspace:Raycast(c + V(0, 12, 0), V(0, -40, 0), mobRay)
		local up = hit and hit.Normal or V(0, 1, 0)
		local fwd = (dir - up * dir:Dot(up)).Unit
		return CFrame.fromMatrix(V(c.X, (hit and hit.Position.Y or d.Pos.Y) + lift, c.Z), fwd:Cross(up), up)
	end
	local made = {}
	for i = 1, n do
		local cf = onGround(seg * (i - 0.5), 0.15)
		table.insert(made, part({ Size = V(d.Width, 0.12, seg + 0.4), CFrame = cf, Color = C(255, 60, 45), Transparency = 0.6 }))
		local fill = part({ Size = V(d.Width - 0.8, 0.16, seg + 0.4), CFrame = cf * CF(0, 0.02, 0), Color = s.Main, Transparency = 1 })
		table.insert(made, fill)
		task.delay(d.Time * (i - 1) / n, function()
			tween(fill, d.Time / n, { Transparency = 0.35 }, Enum.EasingStyle.Linear)
		end)
	end
	-- หัวลูกศร (สองขาเฉียง) ที่ปลาย
	local tip = onGround(d.Length, 0.25)
	local arm = d.Width * 0.9
	for _, sgn in ipairs({ -1, 1 }) do
		local cf = tip * ANG(0, sgn * math.rad(45), 0) * CF(0, 0, arm / 2)
		table.insert(made, part({ Size = V(0.9, 0.14, arm), CFrame = cf, Color = C(255, 60, 45), Transparency = 0.3 }))
	end
	for _, p in ipairs(made) do
		Debris:AddItem(p, d.Time + 0.15)
	end
end

---------------------------------------------------------------- เศษหินกระเด็น (โมเดลหินจริง)
local function debris(pos, r, el, n)
	if el == "Water" then
		return
	end
	local rng = Random.new()
	for _ = 1, n do
		local sz = rng:NextNumber(1.2, 3.2) * math.clamp(r / 25, 0.6, 2)
		local c = rock(V(sz, sz * rng:NextNumber(0.6, 1), sz), el)
		c.Anchored = false
		c.CanCollide = true
		c.CFrame = CF(pos + V(rng:NextNumber(-r, r) * 0.3, 2, rng:NextNumber(-r, r) * 0.3)) * ANG(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		if el == "Fire" then
			c.Material = Enum.Material.CrackedLava
			c.Color = C(255, 110, 40)
		end
		c.Parent = folder()
		local a = rng:NextNumber(0, math.pi * 2)
		c.AssemblyLinearVelocity = V(math.cos(a) * rng:NextNumber(20, 50), rng:NextNumber(45, 85), math.sin(a) * rng:NextNumber(20, 50))
		c.AssemblyAngularVelocity = V(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
		task.delay(1.8, function()
			if c.Parent then
				c.Anchored = true
				tween(c, 0.6, { Size = c.Size * 0.1, Transparency = 1 })
			end
		end)
		Debris:AddItem(c, 2.6)
	end
end

local function dust(pos, r, el, count)
	local s = style(el)
	emitAt(pos + V(0, 1.5, 0), {
		Texture = TEX.Smoke, Lifetime = NumberRange.new(1.6, 2.8), Speed = NumberRange.new(r * 0.5, r * 1.1), SpreadAngle = Vector2.new(85, 8),
		Size = NS({ NSK(0, r * 0.15), NSK(1, r * 0.45) }), Transparency = NS({ NSK(0, 0.35), NSK(1, 1) }), Color = ColorSequence.new(s.Dust),
		Drag = 3, Acceleration = V(0, 3, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30),
	}, count or 24, 4)
end

---------------------------------------------------------------- กระแทก
local ringFx
local function impactFx(d)
	if d.Style == "Ring" then
		return ringFx(d)
	end
	local s = style(d.Element)
	local pos, r = d.Pos, d.Radius
	local small = d.Style == "Small"
	local el = d.Element
	local at = CF(pos)
	-- ระเบิดแสงหลัก (ย้อมสีตามธาตุ) + วงลม
	if not small then
		play("Blast", at, { Scale = math.clamp(r / 16, 0.6, 6), Duration = 0.25, Tint = s.Tint })
		play("BlastWind", at, { Scale = math.clamp(r / 18, 0.6, 6), Duration = 0.3, Tint = s.Tint })
	end
	-- เอฟเฟกต์ประจำธาตุ
	if el == "Earth" then
		play("RockRing", at, { Scale = math.clamp(r / 6, 1, 14), Duration = 0.3 })
		play("Crack", at, { Scale = math.clamp(r / 4, 1, 16), Duration = 0.3, Tint = C(255, 200, 120) })
	elseif el == "Fire" then
		play("Explosion", at, { Scale = math.clamp(r / 3, 2, 22), Duration = 0.35 })
		play("Fire2", at, { Scale = math.clamp(r / 3, 2, 20), Duration = 0.6 })
	elseif el == "Air" then
		play("Ice", at, { Scale = math.clamp(r / 5, 1, 12), Duration = 0.35 })
	elseif el == "Water" then
		play("WaterBurst", at, { Scale = math.clamp(r / 6, 1.5, 14), Duration = 0.5, Burst = 1 })
		spray(at, { Scale = math.clamp(r / 7, 2, 6), Speed = 22 + r * 0.4, Life = 1.2, Gravity = 45, Spread = 55, Burst = 40 })
		play("WaterSwirl", at, { Scale = math.clamp(r / 3, 2, 12), Duration = 0.6 })
		if not small then
			local dome = meshFx("Dome", at, math.clamp(r * 0.5, 6, 34), 1.6)
			if dome then
				fadeModel(dome, 0.8, 0.5)
			end
		end
	end
	if d.Style == "Geyser" then
		-- พวยน้ำ: กรวยพายุน้ำหมุนพุ่งจากพื้น + เสาน้ำกระเซ็น + ระเบิดน้ำที่ฐาน
		local h = math.clamp(r * 5, 30, 70)
		-- เกลียวน้ำ (MeshPart · ขนาดเท่ากล่องจริง) แทนกรวยพายุ WaterTornado เดิม:
		--   เมชเก่าเป็น SpecialMesh ปากกรวยบานกว้างเกินกล่องชิ้นส่วนหลายเท่า -> กล้องอยู่สูง/ไกลก็อยู่ในปากกรวย จอเป็นสีฟ้าทั้งแมพ
		local tor = meshFx("Twist", at * CF(0, -h * 0.1, 0), h * 0.8, 2.4)
		if tor then
			spinModel(tor, 9, 2.2, h * 0.1)
			fadeModel(tor, 0.7, 1.4)
		end
		-- เสาน้ำพุ่งขึ้นตรง สูงราวยอดพายุ แล้วตกโปรยรอบๆ
		spray(at, { Scale = math.clamp(r / 3, 3, 7), Speed = math.sqrt(2 * 40 * h) * 0.9, Life = 1.6, Gravity = 40, Spread = 9, Rate = 90, Time = 0.9 })
		spray(at, { Scale = 3, Speed = 18, Life = 1.1, Gravity = 35, Spread = 70, Burst = 30 })
		play("WaterBurst", at, { Scale = math.clamp(r / 4, 2, 9), Duration = 0.6, Burst = 1 })
	end
	local holder = Instance.new("Attachment")
	holder.WorldPosition = pos + V(0, 4, 0)
	holder.Parent = Workspace.Terrain
	local l = Instance.new("PointLight")
	l.Color = s.Main
	l.Range = math.min(r * 1.6, 60)
	l.Brightness = 5
	l.Parent = holder
	tween(l, 0.7, { Brightness = 0 })
	Debris:AddItem(holder, 0.8)
	dust(pos, r, el, small and 10 or 26)
	if not small then
		debris(pos, r, el, 10)
	end
	shakeFor(pos, r, small and 0.35 or 1.1)
end


-- คลื่นกระแทกวงแหวน (สกิลหลายชั้น): แผ่นคลื่นโปร่งแสงขยายถึงขอบ + ระเบิดธาตุเล็กๆ เรียงรอบขอบวง + ฝุ่น
ringFx = function(d)
	local s = style(d.Element)
	local pos, r, el = d.Pos, d.Radius, d.Element
	local base = CF(pos + V(0, 0.6, 0)) * ANG(0, 0, math.pi / 2)
	local wave = part({ Shape = Enum.PartType.Cylinder, Size = V(1.2, r * 0.6, r * 0.6), CFrame = base, Color = s.Main, Transparency = 0.35 })
	tween(wave, 0.45, { Size = V(0.4, r * 2, r * 2), Transparency = 1 }, Enum.EasingStyle.Quad)
	Debris:AddItem(wave, 0.5)
	local n = math.clamp(math.floor(r / 6), 10, 28)
	for i = 1, n do
		local a = i / n * math.pi * 2
		local at = CF(pos + V(math.cos(a) * r, 0, math.sin(a) * r))
		if i % 2 == 0 then
			if el == "Fire" then
				play("Fire2", at, { Scale = 2.2, Duration = 0.4 })
			elseif el == "Air" then
				play("Ice", at, { Scale = 1.6, Duration = 0.3 })
			elseif el == "Water" then
				play("WaterBurst", at, { Scale = 1.8, Duration = 0.4, Burst = 1 })
			else
				play("RockRing", at, { Scale = 1.6, Duration = 0.3 })
			end
		end
	end
	dust(pos, r, el, 30)
	shakeFor(pos, r, 0.8)
end

---------------------------------------------------------------- หนาม: หินจริงผุดจากดิน / ผลึกน้ำแข็ง / เปลวไฟ
local function spikesFx(d)
	local rng = Random.new()
	local n = d.Count or 8
	local el = d.Element
	for i = 1, n do
		local pos
		if d.Ring then
			local a = i / n * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
			pos = d.Pos + V(math.cos(a) * d.Radius, 0, math.sin(a) * d.Radius)
		else
			pos = d.Pos + V(rng:NextNumber(-d.Radius, d.Radius), 0, rng:NextNumber(-d.Radius, d.Radius))
		end
		if el == "Fire" then
			play(i % 2 == 0 and "Fire1" or "Fire3", CF(pos), { Scale = rng:NextNumber(3.5, 5), Duration = 1.2 })
			if i % 3 == 0 then
				play("RealFire", CF(pos), { Scale = 8, Duration = 1.5 })
			end
		else
			local h = rng:NextNumber(9, 18)
			local w = rng:NextNumber(3, 5.5)
			local tilt = ANG(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4))
			local sp = rock(V(w, h, w * rng:NextNumber(0.7, 1)), el)
			sp.CFrame = CF(pos - V(0, h * 0.6, 0)) * tilt
			sp.Parent = folder()
			tween(sp, 0.14, { CFrame = CF(pos + V(0, h * 0.3, 0)) * tilt }, Enum.EasingStyle.Back)
			if el == "Air" then
				local l = Instance.new("PointLight")
				l.Color = C(150, 220, 255)
				l.Range = 12
				l.Brightness = 1
				l.Parent = sp
				if i % 3 == 0 then
					play("Ice", CF(pos), { Scale = 2, Duration = 0.3 })
				end
			end
			task.delay(1.5 + rng:NextNumber(0, 0.3), function()
				if sp.Parent then
					tween(sp, 0.5, { CFrame = sp.CFrame - V(0, h, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				end
			end)
			Debris:AddItem(sp, 2.4)
		end
	end
	dust(d.Pos, math.max(d.Radius, 8), el, 12)
end

---------------------------------------------------------------- กำแพงน้ำ
local function waveFx(d)
	-- คลื่นยักษ์: กำแพงเมชน้ำกระเซ็นเรียงเต็มความกว้าง + ละอองน้ำจริงพุ่งตลอดแนว วิ่งไปข้างหน้า แล้วซัดแตกที่ปลายทาง
	local look = CF(d.Pos, d.Pos + d.Dir)
	local cols = 6
	local crest = {}
	for k = 1, cols do
		local x = (k - (cols + 1) / 2) * d.Width / cols
		local mesh = meshFx(k % 2 == 0 and "SplashMesh" or "SplashMesh2", look * CF(x, -2, 0) * ANG(0, math.pi, 0), 24 + (k % 3) * 4, d.Time + 1.6)
		-- ยอดคลื่น: น้ำพุ่งเฉียงไปข้างหน้า (แกน +Y เอียงไปทาง -Z) ม้วนตกลงหน้าคลื่น + น้ำดันขึ้นด้านหลัง
		local front = spray(look * CF(x, 1, 0) * ANG(-0.85, 0, 0), { Scale = 4, Speed = 30, Life = 1.1, Gravity = 48, Spread = 14, Rate = 70, Time = d.Time + 0.3 })
		local back = spray(look * CF(x, 0, 4) * ANG(-0.25, 0, 0), { Scale = 4.5, Speed = 20, Life = 1.0, Gravity = 40, Spread = 18, Rate = 45, Time = d.Time + 0.3 })
		table.insert(crest, { mesh, front, x, back })
	end
	local swirls = {}
	for k = -2, 2 do
		local m = play("WaterSwirl", look * CF(k * d.Width / 5, 6, 0), { Scale = 7, Duration = d.Time + 0.4 })
		if m then
			table.insert(swirls, { m, k })
		end
	end
	play("WaterBurst", look, { Scale = 5, Duration = 0.5, Burst = 1 })
	task.delay(0.25, function()
		local t0 = os.clock()
		while os.clock() - t0 < d.Time do
			local u = (os.clock() - t0) / d.Time
			local z = -d.Length * u
			local rise = math.sin(math.min(u * 3, 1) * math.pi / 2) -- ยกตัวขึ้นเร็วตอนแรก
			for i, c in ipairs(crest) do
				local bob = math.sin(os.clock() * 6 + i) * 1.2
				if c[1] and c[1].Parent then
					c[1]:PivotTo(look * CF(c[3], -2 - 10 * (1 - rise) + bob, z) * ANG(0, math.pi, 0))
				end
				if c[2] and c[2].Parent then
					c[2].WorldCFrame = look * CF(c[3], 1 + bob * 0.3, z) * ANG(-0.85, 0, 0)
				end
				if c[4] and c[4].Parent then
					c[4].WorldCFrame = look * CF(c[3], 0, z + 4) * ANG(-0.25, 0, 0)
				end
			end
			for _, sw in ipairs(swirls) do
				if sw[1].Parent then
					sw[1]:PivotTo(look * CF(sw[2] * d.Width / 5, 6, z))
				end
			end
			if math.random() < 0.35 then
				dust((look * CF(math.random(-1, 1) * d.Width * 0.4, 0, z)).Position, 14, "Water", 8)
			end
			task.wait()
		end
		-- ซัดแตกที่ปลายทาง
		local endCf = look * CF(0, 0, -d.Length)
		play("WaterBurst", endCf, { Scale = 7, Duration = 0.6, Burst = 1 })
		for k = -1, 1 do
			spray(endCf * CF(k * d.Width / 3, 1, 0) * ANG(-0.5, 0, 0), { Scale = 5, Speed = 32, Life = 1.3, Gravity = 45, Spread = 40, Burst = 35 })
		end
		for _, c in ipairs(crest) do
			if c[1] and c[1].Parent then
				fadeModel(c[1], 0.6, 0)
			end
		end
	end)
	shakeFor(d.Pos, 30, 0.9)
end

---------------------------------------------------------------- พ่นไฟ (จากปากมังกรจริง)
local function breathFx(d)
	local model = d.Model
	local skin = model and model:FindFirstChild("Skin")
	-- ปากมังกร = ปลายขากรรไกร (Bone_025 HeadEnd) · ไม่มีใช้ข้อต่อขากรรไกร (Bone_026 อยู่ลึกในหัว ไฟเคยออกจากกลางหัว)
	local head, hinge
	if skin then
		for _, b in ipairs(skin:GetDescendants()) do
			if b:IsA("Bone") and b.Name == "Bone_025" then
				head = b
			elseif b:IsA("Bone") and b.Name == "Bone_026" then
				hinge = b
			end
		end
	end
	head = head or hinge
	local target = d.To
	if head then
		for k = 0, 2 do
			play("Flamethrower", head.WorldCFrame, { Scale = 7 + k * 1.5, Duration = d.Time, Follow = head, Aim = target, Rate = 2 })
		end
	else
		play("Flamethrower", CF(d.Pos + V(0, 20, 0), target), { Scale = 8, Duration = d.Time })
	end
	-- ไฟลุกตามแนวพื้น
	for i = 1, 6 do
		local p = d.Pos + d.Dir * (d.Length * i / 7)
		task.delay(0.1 * i, function()
			play(i % 2 == 0 and "Fire1" or "Fire2", CF(p), { Scale = 4, Duration = d.Time })
			if i % 2 == 1 then
				play("RealFire", CF(p), { Scale = 10, Duration = d.Time + 0.8 })
			end
		end)
	end
	shakeFor(d.Pos, 40, 0.5)
end

---------------------------------------------------------------- พายุหิมะ
local function blizzardFx(d)
	play("Tornado", CF(d.Pos), { Scale = math.clamp(d.Radius / 12, 2, 6), Duration = d.Time, Tint = C(200, 235, 255) })
	local hold = part({ Shape = Enum.PartType.Cylinder, Size = V(60, d.Radius * 2, d.Radius * 2), CFrame = CF(d.Pos + V(0, 30, 0)) * ANG(0, 0, math.pi / 2), Transparency = 1 })
	local snow = Instance.new("ParticleEmitter")
	snow.Texture = TEX.Spark
	snow.Shape = Enum.ParticleEmitterShape.Cylinder
	snow.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	snow.Rate = 220
	snow.Lifetime = NumberRange.new(1, 1.8)
	snow.Speed = NumberRange.new(10, 22)
	snow.Size = NS({ NSK(0, 0.8), NSK(1, 0.2) })
	snow.Color = ColorSequence.new(C(235, 248, 255))
	snow.LightEmission = 0.6
	snow.Acceleration = V(0, -6, 0)
	snow.Parent = hold
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = TEX.Smoke
	mist.Shape = Enum.ParticleEmitterShape.Cylinder
	mist.Rate = 24
	mist.Lifetime = NumberRange.new(1.5, 2.5)
	mist.Speed = NumberRange.new(3, 8)
	mist.Size = NS({ NSK(0, 10), NSK(1, 22) })
	mist.Transparency = NS({ NSK(0, 0.55), NSK(1, 1) })
	mist.Color = ColorSequence.new(C(220, 238, 255))
	mist.RotSpeed = NumberRange.new(-80, 80)
	mist.Parent = hold
	tween(hold, d.Time, { CFrame = hold.CFrame * ANG(math.pi * 4, 0, 0) }, Enum.EasingStyle.Linear)
	task.delay(d.Time, function()
		snow.Enabled = false
		mist.Enabled = false
	end)
	Debris:AddItem(hold, d.Time + 3)
end

---------------------------------------------------------------- หินถล่ม / อุกกาบาต (ก้อนหินจริงจากเซิร์ฟเวอร์ + ลูกไฟ/ควันฝั่งนี้)
local function watchProjectiles()
	local fx = Workspace:WaitForChild("FX", 30)
	if not fx then
		return
	end
	fx.ChildAdded:Connect(function(p)
		local kind = p:GetAttribute("VFX")
		if not (kind and p:IsA("BasePart")) then
			return
		end
		if kind == "WaterBall" then
			-- มิสไซล์บอลน้ำ: แสงฟ้า + น้ำวนรอบลูก + ละอองน้ำเป็นหาง
			play("WaterSwirl", p.CFrame, { Scale = 1.4, Duration = 5, Follow = p })
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = C(90, 200, 255), 14, 3
			l.Parent = p
			local a0 = Instance.new("Attachment")
			a0.Parent = p
			local tr = Instance.new("ParticleEmitter")
			tr.Texture = "rbxasset://textures/particles/smoke_main.dds"
			tr.Rate = 70
			tr.Lifetime = NumberRange.new(0.35, 0.6)
			tr.Speed = NumberRange.new(0, 1)
			tr.Size = NS({ NSK(0, 2.6), NSK(1, 0.4) })
			tr.Transparency = NS({ NSK(0, 0.25), NSK(1, 1) })
			tr.Color = ColorSequence.new(C(140, 220, 255), C(40, 140, 255))
			tr.LightEmission = 0.6
			tr.Parent = a0
			return
		end
		if kind == "StaffBolt" then
			-- ลูกไฟคทาเพลิง: Store "ExplosionCharge" ย่อเล็ก ลอยตามลูกจริง (ไม่ใส่ควันดำแบบอุกกาบาตบอส)
			play("StaffExplosion", p.CFrame, { Scale = p:GetAttribute("FxScale") or 0.09, Duration = 6, Follow = p, Tint = p:GetAttribute("FxTint") })
			return
		end
		if kind == "Meteor" then
			-- จุดไฟของแพ็กอยู่หน้าชิ้นส่วน ~4 สตัด (ทาง -Z) -> ถอยกลับให้ลูกไฟครอบลูกจริงพอดี (server หัน -Z ตามทิศพุ่ง)
			local sc = p:GetAttribute("FxScale") or math.max(p.Size.X / 2.5, 2)
			play("FireBall", p.CFrame, { Scale = sc, Duration = 6, Follow = p, FollowOffset = CF(0, 0, 4 * sc) })
		end
		local a = Instance.new("Attachment")
		a.Parent = p
		local trail = Instance.new("ParticleEmitter")
		trail.Texture = TEX.Smoke
		trail.Rate = 40
		trail.Lifetime = NumberRange.new(0.8, 1.4)
		trail.Speed = NumberRange.new(0, 2)
		trail.Size = NS({ NSK(0, p.Size.X * 0.5), NSK(1, p.Size.X * 1.4) })
		trail.Transparency = NS({ NSK(0, 0.35), NSK(1, 1) })
		trail.Color = ColorSequence.new(kind == "Meteor" and C(70, 50, 45) or C(140, 125, 105))
		trail.Parent = a
	end)
end
task.spawn(watchProjectiles)

---------------------------------------------------------------- ออร่าติดตัว
function BossFX.Aura(model, element)
	local skin = model:FindFirstChild("Skin")
	if not skin or skin:FindFirstChild("BossAura") then
		return
	end
	local s = style(element)
	local size = skin.Size
	local att = Instance.new("Attachment")
	att.Name = "BossAura"
	att.Parent = skin
	local l = Instance.new("PointLight")
	l.Color = s.Main
	l.Range = math.min(math.max(size.X, size.Y, size.Z) * 0.5, 32)
	l.Brightness = 0.45
	l.Shadows = false
	l.Parent = att
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 22
	e.Parent = att
	if element == "Fire" then
		e.Texture = TEX.Spark
		e.Lifetime = NumberRange.new(1, 2)
		e.Speed = NumberRange.new(2, 6)
		e.Size = NS({ NSK(0, 0.8), NSK(1, 0) })
		e.Color = ColorSequence.new(C(255, 200, 90), C(255, 70, 20))
		e.LightEmission = 1
		e.Acceleration = V(0, 8, 0)
	elseif element == "Air" then
		e.Texture = TEX.Spark
		e.Lifetime = NumberRange.new(2, 3)
		e.Speed = NumberRange.new(1, 3)
		e.Size = NS(0.6)
		e.Color = ColorSequence.new(C(230, 245, 255))
		e.LightEmission = 0.5
		e.Acceleration = V(0, -4, 0)
	elseif element == "Water" then
		e.Texture = TEX.Spark
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(0, 2)
		e.Size = NS({ NSK(0, 0.7), NSK(1, 0.2) })
		e.Color = ColorSequence.new(C(160, 225, 255))
		e.LightEmission = 0.4
		e.Acceleration = V(0, -25, 0)
	else
		e.Texture = TEX.Smoke
		e.Lifetime = NumberRange.new(2, 3.5)
		e.Speed = NumberRange.new(1, 3)
		e.Size = NS({ NSK(0, 1.5), NSK(1, 4) })
		e.Transparency = NS({ NSK(0, 0.6), NSK(1, 1) })
		e.Color = ColorSequence.new(C(150, 130, 100))
		e.Acceleration = V(0, 2, 0)
	end
	local feet = Instance.new("Attachment")
	feet.Name = "BossFeetFx"
	feet.Position = V(0, -size.Y * 0.48, 0)
	feet.Parent = skin
	local m = Instance.new("ParticleEmitter")
	m.Texture = TEX.Smoke
	m.Rate = 6
	m.Lifetime = NumberRange.new(2, 3)
	m.Speed = NumberRange.new(2, 5)
	m.SpreadAngle = Vector2.new(180, 10)
	m.Size = NS({ NSK(0, size.X * 0.15), NSK(1, size.X * 0.4) })
	m.Transparency = NS({ NSK(0, 0.75), NSK(1, 1) })
	m.Color = ColorSequence.new(s.Dust)
	m.Parent = feet
end

---------------------------------------------------------------- เท้ายักษ์เหยียบพื้น: ฝุ่นฟุ้ง + จอสั่นเบาๆ
function BossFX.Footstep(pos, scale, element)
	local s = style(element)
	emitAt(pos + V(0, 0.5, 0), {
		Texture = TEX.Smoke, Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(5 * scale, 13 * scale), SpreadAngle = Vector2.new(85, 5),
		Size = NS({ NSK(0, 1.6 * scale), NSK(1, 5 * scale) }), Transparency = NS({ NSK(0, 0.45), NSK(1, 1) }), Color = ColorSequence.new(s.Dust),
		Drag = 4, Acceleration = V(0, 2, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30),
	}, 12, 3)
	shakeFor(pos, 18 * scale, 0.3)
end

---------------------------------------------------------------- ตัวรับจาก HitFx

---------------------------------------------------------------- เอฟเฟกต์เฉพาะสกิล (BossSkillFx) — แต่ละท่ามีหน้าตาของตัวเอง
-- ดีคอลจากแพ็ก (vortex / light ring / ...) วางบนแผ่นแบนกลางพื้น หมุน/ขยาย/จาง
local function decalTex(path)
	local dcl = VFXLib.Find(path)
	if dcl and dcl:IsA("Decal") then
		return dcl.Texture
	end
	local inner = dcl and dcl:FindFirstChildWhichIsA("Decal", true)
	return inner and inner.Texture or nil
end
local function decalDisc(path, pos, size, color, o)
	-- ลายเรืองแสงแบนบนพื้น: อนุภาคชิ้นเดียวนอนราบ (LightEmission = บวกแสง -> พื้นดำของภาพหายไป)
	--   (เดิมแปะเป็น Decal = พื้นหลังดำโผล่เป็นสามเหลี่ยม/สี่เหลี่ยมดำ)
	o = o or {}
	local tex = decalTex(path)
	if not tex then
		return nil
	end
	local life = o.Life or 1.2
	local att = Instance.new("Attachment")
	att.WorldPosition = pos + V(0, o.Y or 0.4, 0)
	att.Parent = Workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = tex
	e.Rate = 0
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	e.EmissionDirection = Enum.NormalId.Top
	e.Speed = NumberRange.new(0.01)
	e.Lifetime = NumberRange.new(life)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(math.deg(o.Spin or 0))
	e.Color = ColorSequence.new(color)
	local fade = math.clamp(o.FadeAt or 0.6, 0.05, 0.95)
	local start = o.Start or 0.15
	e.Transparency = NumberSequence.new({ NSK(0, 1), NSK(0.08, start), NSK(fade, start), NSK(1, 1) })
	e.Size = NumberSequence.new({ NSK(0, size / 2), NSK(1, size / 2 * (o.Grow or 1)) })
	e.ZOffset = 1
	e.Parent = att
	e:Emit(1)
	Debris:AddItem(att, life + 0.2)
	return att
end
-- แท่งแสงพาดพื้น (รอยแยก/เส้นพลัง)
local function glowLine(from, dir, length, width, color, life)
	local look = CF(from, from + dir)
	local mid = look * CF(0, 0.3, -length / 2)
	-- แกนสว่างบาง + ขอบเรืองจางๆ (เดิมแผ่นทึบกว้าง = ดูเป็นแท่งสี่เหลี่ยม)
	local core = part({ Size = V(width * 0.25, 0.3, length), CFrame = mid, Color = color:Lerp(Color3.new(1, 1, 1), 0.5), Transparency = 0.2 })
	local p = part({ Size = V(width, 0.25, length), CFrame = mid * CF(0, -0.05, 0), Color = color, Transparency = 0.6 })
	tween(core, (life or 1.2) * 0.7, { Transparency = 1, Size = V(0.2, 0.2, length) })
	Debris:AddItem(core, (life or 1.2) + 0.1)
	tween(p, life or 1.2, { Transparency = 1, Size = V(width * 1.4, 0.2, length) })
	Debris:AddItem(p, (life or 1.2) + 0.1)
end
local function flash(pos, color, range, life)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos + V(0, 6, 0)
	a.Parent = Workspace.Terrain
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range, 8
	l.Parent = a
	tween(l, life or 0.6, { Brightness = 0 })
	Debris:AddItem(a, (life or 0.6) + 0.1)
end

local ELEMENT_AURA = { Earth = C(140, 240, 90), Water = C(70, 200, 255), Air = C(170, 230, 255), Fire = C(255, 110, 30) }
local SIG = {}

-- ชาร์จพลังตอนร่าย (ทุกบอส แต่สี/ของประจำธาตุต่างกัน): วงเวทหมุนใต้เท้า + ออร่า + แสง
SIG.Charge = function(d)
	local m = d.Model
	local root = m and m.PrimaryPart
	if not root then
		return
	end
	local col = ELEMENT_AURA[d.Element] or C(255, 255, 255)
	local _, size = m:GetBoundingBox()
	local r = math.max(size.X, size.Z) * 0.6
	local g = root.Position - V(0, size.Y * 0.45, 0)
	decalDisc("VFXPack/spinny thing", g, r * 2.2, col, { Spin = 2.5, Life = d.Time or 1.5, Grow = 1.25, FadeAt = 0.75 })
	decalDisc("VFXPack/light ring", g, r * 1.4, col, { Spin = -3, Life = d.Time or 1.5, Grow = 1.6, FadeAt = 0.8, Y = 0.5 })
	play("VFXPack/Anime/Charge-01", CF(g), { Scale = math.clamp(r / 8, 1.5, 8), Duration = d.Time or 1.5, Tint = col })
	play("VFXPack/Auras/RNG-Aura-01", root.CFrame, { Scale = math.clamp(r / 10, 1.2, 6), Duration = d.Time or 1.5, Tint = col, Follow = root })
	flash(root.Position, col, math.min(r * 3, 60), d.Time or 1.5)
end

---------------------------------------------------------------- โกเลม
SIG.Quake = function(d)
	local pos, r = d.Pos, d.Radius
	if d.Wave == 1 then
		play("VFXPack/Big/Big-Crack-01", CF(pos), { Scale = math.clamp(r / 10, 2, 12), Duration = 1.2, Tint = C(255, 190, 110) })
		play("Blast", CF(pos), { Scale = math.clamp(r / 14, 1, 7), Duration = 0.3, Tint = C(230, 170, 80) })
		decalDisc("VFXPack/lightning ring", pos, r * 0.6, C(255, 200, 120), { Life = 0.7, Grow = 3.4, FadeAt = 0.3 })
		debris(pos, r * 0.6, d.Element, 18)
	end
	-- เสาฝุ่นพวยขึ้นรอบวง
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2 + d.Wave
		emitAt(pos + V(math.cos(a) * r, 1, math.sin(a) * r), {
			Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C(150, 128, 98)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 14) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Speed = NumberRange.new(18, 30), Lifetime = NumberRange.new(0.9, 1.4), SpreadAngle = Vector2.new(12, 12),
			EmissionDirection = Enum.NormalId.Top, Acceleration = V(0, -8, 0),
		}, 6, 2)
	end
end
SIG.Fissure = function(d)
	-- รอยแยกเรืองแสงเขียวพาดพื้น + รอยร้าวตามแนว
	glowLine(d.Pos, d.Dir, d.Length, 5, C(150, 255, 110), 1.6)
	for i = 1, 6 do
		local p = d.Pos + d.Dir * (d.Length * i / 7)
		play("VFXPack/Anime/Crack-01", CF(p), { Scale = 3, Duration = 0.6, Tint = C(170, 255, 120) })
	end
	flash(d.Pos + d.Dir * d.Length * 0.5, C(150, 255, 110), 50, 0.8)
end
SIG.Boulder = function(d)
	-- ฝุ่น + รอยร้าวไล่ตามหินกลิ้ง
	local t0 = os.clock()
	task.spawn(function()
		local last = -10
		while os.clock() - t0 < d.Length / d.Speed do
			local dist = (os.clock() - t0) * d.Speed
			if dist - last > 9 then
				last = dist
				local p = d.Pos + d.Dir * dist
				dust(p, 6, "Earth", 5)
				play("VFXPack/Anime/Crack-01", CF(p), { Scale = 1.6, Duration = 0.4 })
			end
			task.wait(0.05)
		end
	end)
end

---------------------------------------------------------------- โมซาซอรัส
SIG.Maelstrom = function(d)
	-- น้ำวนยักษ์หมุนบนผิวน้ำระหว่างดูด -> ระเบิดเป็นเสาน้ำ
	decalDisc("VFXPack/vortex", d.Pos, d.Radius * 3.2, C(90, 200, 255), { Spin = 4, Life = d.Time or 2, Grow = 0.55, FadeAt = 0.8, Start = 0.05 })
	decalDisc("VFXPack/Black Swirl", d.Pos, d.Radius * 2.2, C(40, 120, 220), { Spin = -5, Life = d.Time or 2, Grow = 0.5, FadeAt = 0.8, Y = 0.5 })
	play("VFXPack/Auras/Water-Aura-01", CF(d.Pos), { Scale = math.clamp(d.Radius / 6, 2, 10), Duration = d.Time or 2 })
end
SIG.Tidal = function(d)
	play("VFXPack/Anime/Water-02", CF(d.Pos, d.Pos + d.Dir), { Scale = math.clamp(d.Width / 10, 2, 7), Duration = 0.8 })
	play("VFXPack/Anime/Splash-01", CF(d.Pos + d.Dir * d.Length), { Scale = math.clamp(d.Width / 8, 2, 8), Duration = 0.6 })
end
SIG.Splash = function(d)
	play("VFXPack/Anime/Splash-01", CF(d.Pos), { Scale = 2.4, Duration = 0.5 })
	spray(CF(d.Pos), { Scale = 2.5, Speed = 30, Life = 0.9, Gravity = 50, Spread = 40, Burst = 18 })
end
SIG.Charge2 = function(d)
	-- พุ่งชาร์จ: สายน้ำตามหลังตัว + น้ำแตกกระจายที่จุดจบ
	local m = d.Model
	local root = m and m.PrimaryPart
	if root then
		play("VFXPack/Anime/Water-01", root.CFrame, { Scale = math.clamp((d.Width or 20) / 8, 2, 8), Duration = 0.7, Follow = root })
		play("VFXPack/Beams/Waterfall-01", root.CFrame, { Scale = 3, Duration = 0.7, Follow = root })
	end
	glowLine(d.Pos, d.Dir, d.Length, (d.Width or 20) * 0.7, C(120, 210, 255), 1.4)
end

---------------------------------------------------------------- เยติ
SIG.Frost = function(d)
	-- วงน้ำแข็งแผ่ + หมอกเย็น + แสงฟ้า
	decalDisc("VFXPack/lightning ring 2", d.Pos, d.Radius * 0.5, C(180, 235, 255), { Life = 0.8, Grow = 4.2, FadeAt = 0.35 })
	decalDisc("VFXPack/star thing", d.Pos, d.Radius * 1.4, C(210, 245, 255), { Spin = 1.5, Life = 1.6, Grow = 1.2, FadeAt = 0.5 })
	play("Ice", CF(d.Pos), { Scale = math.clamp(d.Radius / 4, 2, 14), Duration = 0.5 })
	play("VFXPack/Anime/Wind-02", CF(d.Pos), { Scale = math.clamp(d.Radius / 8, 2, 8), Duration = 0.6, Tint = C(200, 240, 255) })
	flash(d.Pos, C(150, 220, 255), 70, 0.9)
end
-- หอกน้ำแข็ง: แต่ละจุด = วงน้ำแข็งสว่างวาบ + ประกายผลึกพุ่งขึ้น + หมอกเย็น
SIG.Lances = function(d)
	decalDisc("VFXPack/lightning ring", d.Pos, d.Radius * 0.6, C(190, 240, 255), { Life = 0.5, Grow = 2.6, FadeAt = 0.3 })
	play("VFXPack/Anime/Shiny-01", CF(d.Pos + V(0, 3, 0)), { Scale = 2.2, Duration = 0.4, Tint = C(190, 240, 255) })
	emitAt(d.Pos + V(0, 1, 0), {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(C(200, 245, 255)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }),
		Speed = NumberRange.new(25, 45), Lifetime = NumberRange.new(0.5, 0.9), SpreadAngle = Vector2.new(20, 20),
		EmissionDirection = Enum.NormalId.Top, LightEmission = 1,
	}, 25, 1.5)
end
SIG.Leap = function(d)
	if d.Phase == "Up" then
		play("VFXPack/Anime/Wind-02", CF(d.Pos), { Scale = 5, Duration = 0.5, Tint = C(220, 240, 255) })
		dust(d.Pos, 18, "Air", 20)
		return
	end
	play("VFXPack/Big/Big-Crack-01", CF(d.Pos), { Scale = math.clamp(d.Radius / 9, 2, 10), Duration = 1.2, Tint = C(170, 220, 255) })
	play("VFXPack/Anime/ForceField-Break-01", CF(d.Pos + V(0, 4, 0)), { Scale = math.clamp(d.Radius / 8, 2, 8), Duration = 0.5, Tint = C(190, 235, 255) })
	SIG.Frost(d)
end

---------------------------------------------------------------- มังกร
SIG.Inferno = function(d)
	-- วงแหวนเพลิงแต่ละชั้น: วงแสงส้มขยาย + เปลวไฟพวยขึ้นรอบวง (ชั้นแรก = ระเบิดใหญ่กลาง)
	if d.Wave == 1 then
		play("VFXPack/Big/Explosion-01", CF(d.Pos), { Scale = math.clamp(d.Radius / 8, 2, 9), Duration = 0.6 })
		play("VFXPack/Auras/Fire-Aura-01", CF(d.Pos), { Scale = math.clamp(d.Radius / 5, 3, 10), Duration = 1 })
	end
	decalDisc("VFXPack/lightning ring 3", d.Pos, d.Radius * 0.6, C(255, 140, 50), { Life = 0.6, Grow = 3.6, FadeAt = 0.3 })
	flash(d.Pos, C(255, 120, 40), 80, 0.8)
end
SIG.LavaPool = function(d)
	local base = CF(d.Pos + V(0, 0.15, 0)) * ANG(0, 0, math.pi / 2)
	-- ขอบหินดำไหม้ + ลาวาเรืองข้างใน + แกนร้อนสว่าง + ควันไฟ (เดิมแผ่นแดงเรียบ)
	local pool = part({ Shape = Enum.PartType.Cylinder, Size = V(0.3, d.Radius * 2, d.Radius * 2), CFrame = base, Color = C(46, 24, 18), Material = Enum.Material.Basalt, Transparency = 0 })
	local crust = part({ Shape = Enum.PartType.Cylinder, Size = V(0.34, d.Radius * 1.6, d.Radius * 1.6), CFrame = base, Color = C(255, 80, 10), Transparency = 0.25 })
	local hot = part({ Shape = Enum.PartType.Cylinder, Size = V(0.38, d.Radius * 0.8, d.Radius * 0.8), CFrame = base, Color = C(255, 210, 90), Transparency = 0.35 })
	tween(hot, (d.Time or 4) * 0.5, { Size = V(0.38, d.Radius * 1.2, d.Radius * 1.2) }, Enum.EasingStyle.Sine)
	Debris:AddItem(hot, (d.Time or 4) + 0.1)
	decalDisc("VFXPack/fire flipbook", d.Pos, d.Radius * 2, C(255, 140, 40), { Spin = 0.6, Life = d.Time or 4, FadeAt = 0.8, Y = 0.6 })
	emitAt(d.Pos + V(0, 1, 0), {
		Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(C(70, 50, 45)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		Speed = NumberRange.new(6, 12), Lifetime = NumberRange.new(1.5, 2.5), SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
	}, 14, (d.Time or 4) + 2)
	play("Fire1", CF(d.Pos), { Scale = math.clamp(d.Radius / 3, 2, 6), Duration = d.Time or 4 })
	task.delay((d.Time or 4) - 0.6, function()
		tween(pool, 0.6, { Transparency = 1 })
		tween(crust, 0.6, { Transparency = 1 })
		tween(hot, 0.6, { Transparency = 1 })
	end)
	Debris:AddItem(pool, (d.Time or 4) + 0.1)
	Debris:AddItem(crust, (d.Time or 4) + 0.1)
end
SIG.Breath = function(d)
	play("VFXPack/Anime/Fire-Slash-01", CF(d.Pos, d.Pos + d.Dir) * CF(0, 4, -d.Length * 0.5), { Scale = math.clamp(d.Length / 30, 2, 6), Duration = 0.6 })
	glowLine(d.Pos, d.Dir, d.Length, 10, C(255, 120, 40), 1.2)
end

local function skillFx(d)
	local f = SIG[d.Skill]
	if f then
		local ok, err = pcall(f, d)
		if not ok then
			warn("[AS] BossSkillFx", d.Skill, err)
		end
	end
end

BossFX.Handlers = {
	BossSkillFx = skillFx,
	BossTelegraph = function(d)
		if d.Shape == "MobLine" then
			mobLineTele(d)
		elseif d.Shape == "Line" then
			lineTele(d)
		else
			circleTele(d)
		end
	end,
	BossImpact = impactFx,
	BossSpikes = spikesFx,
	BossWave = waveFx,
	BossBreath = breathFx,
	BossBlizzard = blizzardFx,
}

BossFX.Play = function(name, cf, opts)
	return play(name, cf, opts)
end
BossFX.Dust = function(pos, r, el, count)
	dust(pos, r, el, count)
end
BossFX.Debris = function(pos, r, el, n)
	debris(pos, r, el, n)
end
BossFX.Emit = emitAt
BossFX.Part = part
BossFX.TweenObj = tween

-- ฉากเปิดตัวบอส: ระเบิดกระแทกประจำธาตุที่ตีนบอส (น้ำ = น้ำพุ่งเป็นเสา)
function BossFX.IntroBurst(pos, radius, element)
	impactFx({ Pos = pos, Radius = radius, Element = element, Style = element == "Water" and "Geyser" or nil })
end

function BossFX.Init(shake, zoneShake)
	BossFX.Shake = shake
	BossFX.ZoneShake = zoneShake
end

return BossFX
