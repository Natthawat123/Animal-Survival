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

local function shakeFor(pos, radius, power)
	local cam = Workspace.CurrentCamera
	local d = (cam.CFrame.Position - pos).Magnitude
	local k = math.clamp(1 - d / (radius * 5 + 60), 0, 1)
	if k > 0 and BossFX.Shake then
		BossFX.Shake(power * k, 0.5 + 0.4 * k)
	end
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
	for _, p in ipairs({ edge, inner, fill }) do
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
local function impactFx(d)
	local s = style(d.Element)
	local pos, r = d.Pos, d.Radius
	local small = d.Style == "Small"
	local el = d.Element
	local at = CF(pos)
	-- ระเบิดแสงหลัก (ย้อมสีตามธาตุ) + วงลม
	if not small then
		play("Blast", at, { Scale = math.clamp(r / 16, 0.6, 3.5), Duration = 0.25, Tint = s.Tint })
		play("BlastWind", at, { Scale = math.clamp(r / 18, 0.6, 3.5), Duration = 0.3, Tint = s.Tint })
	end
	-- เอฟเฟกต์ประจำธาตุ
	if el == "Earth" then
		play("RockRing", at, { Scale = math.clamp(r / 6, 1, 8), Duration = 0.3 })
		play("Crack", at, { Scale = math.clamp(r / 4, 1, 10), Duration = 0.3, Tint = C(255, 200, 120) })
	elseif el == "Fire" then
		play("Explosion", at, { Scale = math.clamp(r / 3, 2, 14), Duration = 0.35 })
		play("Fire2", at, { Scale = math.clamp(r / 3, 2, 12), Duration = 0.6 })
	elseif el == "Air" then
		play("Ice", at, { Scale = math.clamp(r / 5, 1, 7), Duration = 0.35 })
	elseif el == "Water" then
		play("WaterBurst", at, { Scale = math.clamp(r / 6, 1.5, 9), Duration = 0.5, Burst = 1 })
		spray(at, { Scale = math.clamp(r / 7, 2, 6), Speed = 22 + r * 0.4, Life = 1.2, Gravity = 45, Spread = 55, Burst = 40 })
		play("WaterSwirl", at, { Scale = math.clamp(r / 3, 2, 12), Duration = 0.6 })
		if not small then
			local dome = meshFx("Dome", at, math.clamp(r * 0.5, 6, 24), 1.6)
			if dome then
				fadeModel(dome, 0.8, 0.5)
			end
		end
	end
	if d.Style == "Geyser" then
		-- พวยน้ำ: กรวยพายุน้ำหมุนพุ่งจากพื้น + เสาน้ำกระเซ็น + ระเบิดน้ำที่ฐาน
		local h = math.clamp(r * 5, 30, 70)
		-- กรวยบานด้านบนกว้างมาก (เมชใหญ่กว่ากล่องชิ้นส่วน) -> ย่อความสูงลง ไม่งั้นปากกรวยครอบกล้องจนจอเป็นสีฟ้าทั้งจอ
		local tor = meshFx("Tornado", at * CF(0, -h * 0.2, 0), h * 0.42, 2.4)
		if tor then
			spinModel(tor, 9, 2.2, h * 0.2)
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
		if kind == "StaffBolt" then
			-- ลูกไฟคทาเพลิง: Store "ExplosionCharge" ย่อเล็ก ลอยตามลูกจริง (ไม่ใส่ควันดำแบบอุกกาบาตบอส)
			play("StaffExplosion", p.CFrame, { Scale = p:GetAttribute("FxScale") or 0.09, Duration = 6, Follow = p })
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
BossFX.Handlers = {
	BossTelegraph = function(d)
		if d.Shape == "Line" then
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

function BossFX.Init(shake)
	BossFX.Shake = shake
end

return BossFX
