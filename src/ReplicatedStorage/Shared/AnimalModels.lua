--[[
	AnimalModels — ปั้นโมเดลสัตว์จากสเปกใน Animals.lua (ใช้ทั้ง Server และปลั๊กอิน)

	โครงกระดูก (Motor6D) ที่ทุกตัวใช้ร่วมกัน -> AnimalAnimator (ฝั่ง client) ขยับตามชื่อ:
		HumanoidRootPart --Root--> Body
		Body --Neck--> Head --Jaw--> Jaw
		Body --LegFL/LegFR/LegBL/LegBR--> ขา  (ปู: Leg1..Leg6 + ClawL/ClawR)
		Body --Tail1--> Tail1 --Tail2--> Tail2 ...
		Body --WingL/WingR--> ปีก (นก)

	ถ้ามี ReplicatedStorage.Assets.Animals.<Id> (โมเดลจาก Blender ที่ชิ้นชื่อ Body/Head/LegFL/...) จะใช้โมเดลนั้นแทน
	แล้วต่อกระดูกให้เองตามตำแหน่งชิ้น
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Animals = require(script.Parent.Animals)

local AnimalModels = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

---------------------------------------------------------------- helpers
local function newPart(model, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif shape == "Wedge" then
		p:Destroy()
		p = Instance.new("WedgePart")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanTouch = false
		p.Massless = true
	end
	p.Parent = model
	return p
end

local function ellip(model, name, size, cf, color, material)
	local p = newPart(model, name, size, cf, color, material)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
	return w
end

local function motor(name, p0, p1, jointWorld)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = p0.CFrame:Inverse() * jointWorld
	m.C1 = p1.CFrame:Inverse() * jointWorld
	m.Parent = p0
	return m
end

local function neonGlow(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = part
	return l
end

local function sparkle(part, color, rate, size)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Sparkle"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = rate or 6
	pe.Lifetime = NumberRange.new(0.8, 1.6)
	pe.Speed = NumberRange.new(1, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new(size or 0.4, 0)
	pe.Color = ColorSequence.new(color)
	pe.Parent = part
	return pe
end

local function flame(part, size, color)
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = size * 1.5
	f.Color = color or Color3.fromRGB(255, 140, 40)
	f.SecondaryColor = Color3.fromRGB(255, 60, 10)
	f.Parent = part
	return f
end

local function has(list, name)
	if not list then
		return false
	end
	for _, v in ipairs(list) do
		if v == name then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- ส่วนหัว (ใช้ร่วม)
local function buildEyes(model, head, H, colors, menacing, passive)
	local s = math.max(H.X * 0.17, 0.22)
	for _, side in ipairs({ -1, 1 }) do
		local pos = head.CFrame * CF(side * H.X * 0.3, H.Y * 0.12, -H.Z * 0.36)
		local eye
		if passive then
			eye = newPart(model, "Eye", V(s, s, s), pos, Color3.fromRGB(20, 18, 20), Enum.Material.Glass, "Ball")
			local hl = newPart(model, "EyeShine", V(s * 0.35, s * 0.35, s * 0.35), pos * CF(side * s * 0.12, s * 0.2, -s * 0.38), Color3.new(1, 1, 1), Enum.Material.Neon, "Ball")
			weld(head, hl)
		else
			eye = newPart(model, "Eye", V(s, s * 0.8, s), pos, colors.Eye, Enum.Material.Neon, "Ball")
		end
		weld(head, eye)
		if menacing then
			-- คิ้วขมวด
			local brow = newPart(model, "Brow", V(s * 1.8, s * 0.45, s * 1.2), pos * CF(side * -s * 0.1, s * 0.62, -s * 0.1) * ANG(0, 0, rad(side * -20)), colors.Dark or colors.Main, Enum.Material.SmoothPlastic)
			weld(head, brow)
		end
	end
end

local function buildEars(model, head, H, colors, kind)
	if not kind or kind == "None" then
		return
	end
	for _, side in ipairs({ -1, 1 }) do
		local base = head.CFrame * CF(side * H.X * 0.3, H.Y * 0.42, H.Z * 0.05)
		local ear
		if kind == "Pointy" or kind == "Big" or kind == "Tufted" then
			local s = (kind == "Big") and 1.5 or 1
			local size = V(H.X * 0.12, H.Y * 0.55 * s, H.Z * 0.32 * s)
			ear = newPart(model, "Ear", size, base * CF(0, size.Y * 0.4, 0) * ANG(rad(-10), 0, rad(side * -12)) * ANG(0, math.pi, 0), colors.Main, Enum.Material.SmoothPlastic, "Wedge")
			local inner = newPart(model, "EarInner", size * V(0.6, 0.7, 0.6), ear.CFrame * CF(0, -size.Y * 0.05, size.Z * 0.12), colors.Belly, Enum.Material.SmoothPlastic, "Wedge")
			weld(head, inner)
			if kind == "Tufted" then
				local tuft = newPart(model, "Tuft", V(0.15, H.Y * 0.35, 0.15), base * CF(side * 0.05, size.Y * 1.0, 0), colors.Dark, Enum.Material.SmoothPlastic)
				weld(head, tuft)
			end
		elseif kind == "Round" then
			ear = ellip(model, "Ear", V(H.X * 0.14, H.Y * 0.3, H.Z * 0.26), base * CF(side * H.X * 0.05, H.Y * 0.08, 0), colors.Main)
		elseif kind == "Long" then
			ear = ellip(model, "Ear", V(H.X * 0.2, H.Y * 1.3, H.Z * 0.32), base * CF(0, H.Y * 0.55, H.Z * 0.1) * ANG(rad(-12), 0, rad(side * -8)), colors.Main)
			local inner = ellip(model, "EarInner", V(H.X * 0.1, H.Y * 1.0, H.Z * 0.2), ear.CFrame * CF(0, 0, -H.Z * 0.07), colors.Belly)
			weld(head, inner)
		elseif kind == "Floppy" then
			ear = ellip(model, "Ear", V(H.X * 0.14, H.Y * 0.55, H.Z * 0.32), base * CF(side * H.X * 0.22, -H.Y * 0.2, 0) * ANG(0, 0, rad(side * 55)), colors.Dark)
		end
		if ear then
			weld(head, ear)
		end
	end
end

-- ปาก/จมูก/ขากรรไกร (หัวทรงสี่ขา)
local function buildSnout(model, head, H, S, colors, extras)
	local snoutCf = head.CFrame * CF(0, -H.Y * 0.14, -H.Z * 0.42 - S.Z * 0.3)
	local snout = ellip(model, "Snout", S, snoutCf, colors.Main)
	weld(head, snout)
	local muzzle = ellip(model, "Muzzle", S * V(0.8, 0.55, 0.85), snoutCf * CF(0, -S.Y * 0.18, -S.Z * 0.06), colors.Belly)
	weld(head, muzzle)
	local nose = newPart(model, "Nose", V(S.X * 0.42, S.X * 0.32, S.X * 0.3), snoutCf * CF(0, S.Y * 0.18, -S.Z * 0.47), colors.Dark or Color3.new(0.1, 0.1, 0.1), Enum.Material.SmoothPlastic, "Ball")
	weld(head, nose)
	local jaw = ellip(model, "Jaw", V(S.X * 0.78, S.Y * 0.42, S.Z * 0.9), snoutCf * CF(0, -S.Y * 0.42, S.Z * 0.04), colors.Belly)
	motor("Jaw", head, jaw, snoutCf * CF(0, -S.Y * 0.3, S.Z * 0.42))
	-- ฟัน
	for _, side in ipairs({ -1, 1 }) do
		local fang = newPart(model, "Fang", V(S.X * 0.1, S.Y * 0.32, S.X * 0.1), snoutCf * CF(side * S.X * 0.24, -S.Y * 0.36, -S.Z * 0.3) * ANG(math.pi, 0, 0), Color3.fromRGB(245, 240, 225), Enum.Material.SmoothPlastic, "Wedge")
		weld(head, fang)
	end
	if has(extras, "Tusks") then
		for _, side in ipairs({ -1, 1 }) do
			local tusk = newPart(model, "Tusk", V(S.X * 0.16, S.Y * 0.9, S.X * 0.16), snoutCf * CF(side * S.X * 0.42, S.Y * 0.1, -S.Z * 0.2) * ANG(rad(-25), 0, rad(side * -25)), colors.Horn, Enum.Material.SmoothPlastic, "Wedge")
			weld(head, tusk)
		end
	end
	if has(extras, "NoseHorn") then
		local horn = newPart(model, "Horn", V(S.X * 0.5, S.Y * 1.9, S.X * 0.6), snoutCf * CF(0, S.Y * 0.95, -S.Z * 0.25) * ANG(rad(-18), math.pi, 0), colors.Horn, Enum.Material.Basalt, "Wedge")
		weld(head, horn)
		local horn2 = newPart(model, "Horn2", V(S.X * 0.35, S.Y * 1.0, S.X * 0.4), snoutCf * CF(0, S.Y * 0.75, S.Z * 0.25) * ANG(rad(-10), math.pi, 0), colors.Horn, Enum.Material.Basalt, "Wedge")
		weld(head, horn2)
	end
	return snout, jaw
end

---------------------------------------------------------------- ของตกแต่งพิเศษ
local function decorate(model, parts, spec, B)
	local colors = spec.Colors
	local extras = spec.Extras or {}
	local body, head, tail = parts.Body, parts.Head, parts.Tail1
	local H = spec.Head or V(1, 1, 1)
	local glow = colors.Glow or colors.Eye

	if has(extras, "Moss") then
		for i = 1, 5 do
			local m = ellip(model, "Moss", V(B.X * 0.45, B.Y * 0.25, B.Z * 0.28), body.CFrame * CF(math.sin(i * 2.4) * B.X * 0.2, B.Y * 0.42, (i - 3) * B.Z * 0.16) * ANG(0, i, 0), colors.Moss, Enum.Material.Grass)
			weld(body, m)
		end
	end
	if has(extras, "Ruff") then
		local r = ellip(model, "Ruff", V(B.X * 1.15, B.Y * 1.1, B.Z * 0.35), body.CFrame * CF(0, B.Y * 0.1, -B.Z * 0.38), colors.Belly, Enum.Material.Fabric)
		weld(body, r)
	end
	if has(extras, "Spots") then
		for i = 1, 6 do
			local s = ellip(model, "Spot", V(B.X * 0.2, B.Y * 0.1, B.Z * 0.12), body.CFrame * CF((i % 2 == 0 and 1 or -1) * B.X * 0.36, B.Y * (0.15 + (i % 3) * 0.08), (i - 3.5) * B.Z * 0.12) * ANG(0, 0, (i % 2 == 0 and -1 or 1) * 0.9), colors.Dark)
			weld(body, s)
		end
	end
	if has(extras, "Antlers") or has(extras, "GiantAntlers") then
		local giant = has(extras, "GiantAntlers")
		local scale = giant and 2.6 or 1
		for _, side in ipairs({ -1, 1 }) do
			local root = head.CFrame * CF(side * H.X * 0.25, H.Y * 0.45, H.Z * 0.1)
			local main = newPart(model, "Antler", V(0.22 * scale, 2.2 * scale, 0.22 * scale), root * ANG(rad(-15), 0, rad(side * -28)) * CF(0, 1.1 * scale, 0), colors.Horn, Enum.Material.SmoothPlastic)
			weld(head, main)
			for k = 1, giant and 4 or 2 do
				local branch = newPart(model, "Antler", V(0.16 * scale, (1.0 + k * 0.15) * scale, 0.16 * scale),
					main.CFrame * CF(0, (-0.6 + k * 0.45) * scale, 0) * ANG(rad(-30 - k * 8), 0, rad(side * (35 + k * 6))) * CF(0, 0.5 * scale, 0), colors.Horn, Enum.Material.SmoothPlastic)
				weld(head, branch)
				if giant then
					local twig = newPart(model, "Antler", V(0.12 * scale, 0.7 * scale, 0.12 * scale), branch.CFrame * CF(0, 0.4 * scale, 0) * ANG(rad(40), 0, rad(side * -30)) * CF(0, 0.3 * scale, 0), colors.Horn, Enum.Material.SmoothPlastic)
					weld(head, twig)
				end
			end
		end
	end
	if has(extras, "SkullFace") then
		local skull = ellip(model, "Skull", H * V(1.04, 0.9, 1.05), head.CFrame * CF(0, H.Y * 0.08, -H.Z * 0.04), colors.Skull, Enum.Material.SmoothPlastic)
		weld(head, skull)
		local snout = parts.Snout
		if snout then
			local bone = ellip(model, "SkullSnout", snout.Size * V(1.05, 1.0, 1.04), snout.CFrame, colors.Skull, Enum.Material.SmoothPlastic)
			weld(head, bone)
		end
		for _, side in ipairs({ -1, 1 }) do
			local socket = newPart(model, "Socket", V(H.X * 0.26, H.X * 0.22, 0.2), head.CFrame * CF(side * H.X * 0.28, H.Y * 0.14, -H.Z * 0.46), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, "Ball")
			weld(head, socket)
			local pupil = newPart(model, "Pupil", V(0.18, 0.18, 0.18), socket.CFrame * CF(0, 0, -0.08), colors.Eye, Enum.Material.Neon, "Ball")
			weld(head, pupil)
		end
	end
	if has(extras, "Ribs") then
		for i = 1, 5 do
			for _, side in ipairs({ -1, 1 }) do
				local rib = newPart(model, "Rib", V(0.18, B.Y * 0.75, 0.18), body.CFrame * CF(side * B.X * 0.46, -B.Y * 0.05, (i - 3) * B.Z * 0.11) * ANG(0, 0, rad(side * 12)), colors.Skull or colors.Horn, Enum.Material.SmoothPlastic)
				weld(body, rib)
			end
		end
	end
	if has(extras, "BackThorns") or has(extras, "BackSpikes") or has(extras, "BackPlates") then
		local n = 6
		local color = colors.Spike or colors.Dark
		local mat = has(extras, "BackSpikes") and Enum.Material.Basalt or Enum.Material.SmoothPlastic
		for i = 1, n do
			local t = (i - 1) / (n - 1)
			local h = B.Y * (has(extras, "BackPlates") and 0.32 or 0.55) * (1 - math.abs(t - 0.4))
			local spike = newPart(model, "Spike", V(B.X * 0.12, h, h * 0.8), body.CFrame * CF(0, B.Y * 0.44 + h * 0.3, -B.Z * 0.38 + t * B.Z * 0.8) * ANG(0, math.pi, 0), color, mat, "Wedge")
			weld(body, spike)
		end
	end
	if has(extras, "Crystals") then
		for i = 1, 7 do
			local h = B.Y * (0.35 + (i % 3) * 0.18)
			local c = newPart(model, "Crystal", V(h * 0.28, h, h * 0.28),
				body.CFrame * CF(math.sin(i * 1.9) * B.X * 0.25, B.Y * 0.4 + h * 0.3, (i - 4) * B.Z * 0.1) * ANG(math.sin(i) * 0.5, i, math.cos(i) * 0.5), colors.Crystal or glow, Enum.Material.Neon)
			weld(body, c)
		end
		neonGlow(body, colors.Crystal or glow, 14, 1.2)
	end
	if has(extras, "Hump") then
		local hump = ellip(model, "Hump", V(B.X * 0.8, B.Y * 0.5, B.Z * 0.4), body.CFrame * CF(0, B.Y * 0.38, -B.Z * 0.2), colors.Main, spec.Material and Enum.Material[spec.Material] or Enum.Material.SmoothPlastic)
		weld(body, hump)
	end
	if has(extras, "Wool") then
		for i = 1, 14 do
			local a = i / 14 * math.pi * 2
			local s = B.Y * 0.62
			local puff = newPart(model, "Wool", V(s, s, s), body.CFrame * CF(math.cos(a) * B.X * 0.32, B.Y * 0.18 + math.sin(i * 1.3) * B.Y * 0.18, math.sin(a) * B.Z * 0.34), colors.Main, Enum.Material.Fabric, "Ball")
			weld(body, puff)
		end
	end
	if has(extras, "CurledHorns") then
		for _, side in ipairs({ -1, 1 }) do
			-- เขาม้วน: ท่อนกระบอกต่อกันเป็นวง
			local prev = head.CFrame * CF(side * H.X * 0.38, H.Y * 0.3, H.Z * 0.1)
			for k = 1, 5 do
				local thick = H.X * (0.32 - k * 0.04)
				local segLen = H.X * 0.42
				local step = prev * ANG(rad(-55), rad(side * 18), 0)
				local seg = newPart(model, "Horn", V(segLen, thick, thick), step * CF(0, 0, -segLen * 0.5) * ANG(0, math.pi / 2, 0), colors.Horn, Enum.Material.SmoothPlastic, "Cylinder")
				weld(head, seg)
				prev = step * CF(0, 0, -segLen * 0.85)
			end
		end
	end
	if has(extras, "Sparks") then
		sparkle(body, glow, 8, 0.6)
		for _, side in ipairs({ -1, 1 }) do
			local bolt = newPart(model, "Bolt", V(0.12, B.Y * 0.6, 0.12), body.CFrame * CF(side * B.X * 0.5, B.Y * 0.2, 0) * ANG(0.4, 0, side * 0.5), glow, Enum.Material.Neon)
			weld(body, bolt)
		end
	end
	if has(extras, "LavaCracks") then
		-- รอยแตกซิกแซก: เส้นบางๆ ต่อกันบนผิว
		for side = -1, 1, 2 do
			for line = 1, 3 do
				local z0 = (line - 2) * B.Z * 0.26
				local y0 = B.Y * (0.25 - line * 0.08)
				for k = 1, 4 do
					local len = B.Y * 0.28
					local angle = ((k % 2 == 0) and 0.7 or -0.7) + line * 0.2
					local crack = newPart(model, "Crack", V(0.14, len, 0.32),
						body.CFrame * CF(side * B.X * 0.485, y0 - k * len * 0.42, z0 + (k - 2.5) * len * 0.3) * ANG(angle, 0, side * 0.25), glow, Enum.Material.Neon)
					weld(body, crack)
				end
			end
		end
		neonGlow(body, glow, 16, 1.6)
	end
	if has(extras, "GlowStripes") then
		for _, side in ipairs({ -1, 1 }) do
			local stripe = newPart(model, "Stripe", V(0.15, B.Y * 0.18, B.Z * 0.85), body.CFrame * CF(side * B.X * 0.46, B.Y * 0.05, 0), glow, Enum.Material.Neon)
			weld(body, stripe)
		end
	end
	if has(extras, "GlowSpots") then
		for i = 1, 10 do
			local s = B.Y * 0.22
			local spot = newPart(model, "GlowSpot", V(s, s * 0.5, s), body.CFrame * CF(math.sin(i * 2.7) * B.X * 0.3, B.Y * 0.42, (i - 5.5) * B.Z * 0.08), glow, Enum.Material.Neon, "Ball")
			weld(body, spot)
		end
		neonGlow(body, glow, 12, 1.2)
	end
	if has(extras, "Frills") then
		for _, side in ipairs({ -1, 1 }) do
			local frill = newPart(model, "Frill", V(0.15, H.Y * 1.2, H.Z * 0.9), head.CFrame * CF(side * H.X * 0.55, H.Y * 0.1, H.Z * 0.25) * ANG(0, 0, rad(side * 35)), glow, Enum.Material.Neon, "Wedge")
			frill.Transparency = 0.15
			weld(head, frill)
		end
	end
	if has(extras, "Fins") then
		local fin = newPart(model, "Fin", V(0.2, B.Y * 0.8, B.Z * 0.45), body.CFrame * CF(0, B.Y * 0.6, 0) * ANG(0, math.pi, 0), glow, Enum.Material.Neon, "Wedge")
		fin.Transparency = 0.2
		weld(body, fin)
	end
	if has(extras, "FlameMane") then
		for i = 1, 12 do
			local a = i / 12 * math.pi * 2
			local s = H.Y * 0.75
			local tuft = ellip(model, "Mane", V(s * 0.8, s * 1.5, s * 0.8), head.CFrame * CF(math.cos(a) * H.X * 0.55, math.sin(a) * H.Y * 0.55, H.Z * 0.2) * ANG(0, 0, a - math.pi / 2) * CF(0, s * 0.35, 0), (i % 2 == 0) and glow or Color3.fromRGB(255, 200, 80), Enum.Material.Neon)
			weld(head, tuft)
		end
		flame(head, H.X * 2.2)
		neonGlow(head, glow, 40, 3)
	end
	if has(extras, "FlameTips") then
		for _, ear in ipairs(model:GetChildren()) do
			if ear.Name == "Ear" then
				local tip = ellip(model, "FlameTip", ear.Size * V(1.1, 0.4, 0.9), ear.CFrame * CF(0, ear.Size.Y * 0.35, 0), glow, Enum.Material.Neon)
				weld(head, tip)
			end
		end
	end
	if has(extras, "WindRibbons") then
		for _, side in ipairs({ -1, 1 }) do
			local rib = newPart(model, "Ribbon", V(0.1, B.Y * 0.25, B.Z * 1.1), body.CFrame * CF(side * B.X * 0.55, B.Y * 0.35, B.Z * 0.45) * ANG(rad(10), rad(side * 8), 0), glow, Enum.Material.Neon)
			rib.Transparency = 0.35
			weld(body, rib)
		end
	end
	if has(extras, "SpiritGlow") then
		neonGlow(body, glow, 18, 2.4)
		sparkle(body, glow, 10, 0.5)
		local aura = Instance.new("Highlight")
		aura.FillColor = glow
		aura.FillTransparency = 0.75
		aura.OutlineColor = glow
		aura.OutlineTransparency = 0.2
		aura.DepthMode = Enum.HighlightDepthMode.Occluded
		aura.Parent = model
	end
	if has(extras, "Sprout") then
		for _, side in ipairs({ -1, 1 }) do
			local leaf = ellip(model, "Leaf", V(0.6, 0.15, 0.9), head.CFrame * CF(side * 0.25, H.Y * 0.6, 0) * ANG(rad(20), 0, rad(side * 35)), Color3.fromRGB(110, 220, 80), Enum.Material.Neon)
			weld(head, leaf)
		end
	end
	if has(extras, "Coral") or has(extras, "Barnacles") then
		for i = 1, 9 do
			local s = B.Y * (0.18 + (i % 3) * 0.08)
			local c = newPart(model, "Coral", V(s, s * 1.4, s), body.CFrame * CF(math.sin(i * 2.1) * B.X * 0.35, B.Y * 0.38, math.cos(i * 1.7) * B.Z * 0.3), (i % 3 == 0) and colors.Coral or ((i % 3 == 1) and glow or Color3.fromRGB(236, 226, 206)), (i % 3 == 1) and Enum.Material.Neon or Enum.Material.SmoothPlastic, "Ball")
			weld(body, c)
		end
	end
	if has(extras, "Crest") then
		for i = 1, 4 do
			local f = newPart(model, "Crest", V(0.3, H.Y * (0.8 + i * 0.15), H.Z * 0.5), head.CFrame * CF(0, H.Y * 0.4, H.Z * (0.1 + i * 0.12)) * ANG(rad(-40 - i * 8), math.pi, 0), (i % 2 == 0) and glow or colors.Dark, Enum.Material.Neon, "Wedge")
			weld(head, f)
		end
	end
	if has(extras, "ShellForest") then
		local shell = parts.Shell
		local S = shell.Size
		for i = 1, 9 do
			local a = i / 9 * math.pi * 2
			local r = (i % 3 == 0) and 0.15 or 0.32
			local pos = shell.CFrame * CF(math.cos(a) * S.X * r, S.Y * 0.42 - r * S.Y * 0.4, math.sin(a) * S.Z * r)
			local trunk = newPart(model, "TreeTrunk", V(1.2, 5, 1.2), pos * CF(0, 2.5, 0), Color3.fromRGB(90, 66, 48), Enum.Material.Wood)
			weld(shell, trunk)
			local crown = ellip(model, "TreeCrown", V(6, 7, 6), pos * CF(0, 7, 0), colors.Moss, Enum.Material.LeafyGrass)
			weld(shell, crown)
		end
		for i = 1, 6 do
			local h = 4 + (i % 3) * 2.5
			local c = newPart(model, "Crystal", V(1.4, h, 1.4), shell.CFrame * CF(math.sin(i * 2) * S.X * 0.25, S.Y * 0.45, math.cos(i * 2) * S.Z * 0.25) * ANG(math.sin(i) * 0.4, i, math.cos(i) * 0.4), colors.Crystal, Enum.Material.Neon)
			weld(shell, c)
		end
		for i = 1, 5 do
			local r = ellip(model, "ShellRock", V(5, 3.4, 4.6), shell.CFrame * CF(math.cos(i * 1.3) * S.X * 0.38, S.Y * 0.28, math.sin(i * 1.3) * S.Z * 0.38) * ANG(0, i, 0.3), colors.Dark, Enum.Material.Slate)
			weld(shell, r)
		end
		neonGlow(shell, colors.Crystal, 40, 2)
	end
end

---------------------------------------------------------------- หาง
local function buildTail(model, body, B, spec)
	local colors = spec.Colors
	local kind = spec.Tail or "Short"
	local root = body.CFrame * CF(0, B.Y * 0.18, B.Z * 0.47)
	local size, color, mat = nil, colors.Main, Enum.Material.SmoothPlastic
	if kind == "Bushy" or kind == "FlameBushy" then
		size = V(B.X * 0.42, B.Y * 0.42, B.Z * 0.6)
	elseif kind == "Long" then
		size = V(B.X * 0.18, B.Y * 0.18, B.Z * 0.75)
	elseif kind == "Thin" then
		size = V(0.25, 0.25, B.Z * 0.35)
		color = colors.Dark
	elseif kind == "Puff" then
		size = V(B.X * 0.38, B.X * 0.38, B.X * 0.38)
		color = colors.Belly
	elseif kind == "Stub" then
		size = V(B.X * 0.2, B.Y * 0.2, B.Z * 0.12)
	elseif kind == "FlameTuft" then
		size = V(B.X * 0.12, B.Y * 0.12, B.Z * 0.7)
	else -- Short
		size = V(B.X * 0.2, B.Y * 0.25, B.Z * 0.2)
	end
	local tilt = (kind == "Bushy" or kind == "FlameBushy") and rad(-25) or rad(-35)
	local cf = root * ANG(tilt, 0, 0) * CF(0, 0, size.Z * 0.42)
	local tail = ellip(model, "Tail1", size, cf, color, mat)
	motor("Tail1", body, tail, root)
	if kind == "Bushy" or kind == "FlameBushy" then
		local tip = ellip(model, "TailTip", size * V(0.7, 0.7, 0.45), cf * CF(0, 0, size.Z * 0.42), kind == "FlameBushy" and (colors.Glow or colors.Belly) or colors.Belly, kind == "FlameBushy" and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		weld(tail, tip)
		if kind == "FlameBushy" then
			flame(tip, math.max(size.X * 1.6, 1.5))
		end
	elseif kind == "FlameTuft" or kind == "Long" then
		local tipColor = kind == "FlameTuft" and colors.Glow or colors.Dark
		local tip = ellip(model, "TailTip", V(size.X * 2.6, size.X * 2.6, size.X * 3.6), cf * CF(0, 0, size.Z * 0.5), tipColor, kind == "FlameTuft" and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		weld(tail, tip)
		if kind == "FlameTuft" then
			flame(tip, size.X * 6)
		end
	end
	return tail
end

---------------------------------------------------------------- แม่แบบรูปร่าง
local Templates = {}

-- สี่ขา (หมาป่า หมี จิ้งจอก กวาง สิงโต ฯลฯ) + กระต่าย
function Templates.Quadruped(model, spec, info)
	local colors = spec.Colors
	local B, H = spec.Body, spec.Head
	local S = spec.Snout or V(H.X * 0.5, H.Y * 0.4, H.Z * 0.5)
	local legLen = spec.LegLen
	local T = spec.LegThick
	local neck = spec.Neck or 0.6
	local mat = spec.Material and Enum.Material[spec.Material] or Enum.Material.SmoothPlastic
	local rabbit = spec.Template == "Rabbit"
	local bodyY = legLen + B.Y / 2

	local root = newPart(model, "HumanoidRootPart", V(B.X, B.Y, B.Z * 0.9), CF(0, bodyY, 0), colors.Main)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	local body = ellip(model, "Body", B, CF(0, bodyY, 0) * ANG(rabbit and rad(-12) or 0, 0, 0), colors.Main, mat)
	motor("Root", root, body, CF(0, bodyY, 0))
	local chest = ellip(model, "Chest", B * V(1.04, 1.02, 0.55), CF(0, bodyY + B.Y * 0.06, -B.Z * 0.26), colors.Main, mat)
	weld(body, chest)
	local belly = ellip(model, "Belly", B * V(0.78, 0.55, 0.78), CF(0, bodyY - B.Y * 0.2, -B.Z * 0.02), colors.Belly, mat)
	weld(body, belly)
	local haunch = ellip(model, "Haunch", B * V(1.02, 0.95, 0.5), CF(0, bodyY + B.Y * 0.02, B.Z * 0.28), colors.Main, mat)
	weld(body, haunch)

	-- คอ + หัว
	local J = CF(0, bodyY + B.Y * 0.28, -B.Z * 0.42)
	local headPos = J * CF(0, neck * 0.55 + H.Y * 0.12, -(neck * 0.42 + H.Z * 0.32))
	local head = ellip(model, "Head", H, headPos, colors.Main, mat)
	motor("Neck", body, head, J)
	if neck > 0.2 then
		local neckPiece = ellip(model, "NeckFur", V(H.X * 0.72, neck + H.Y * 0.7, H.Z * 0.72), J * CF(0, neck * 0.3, -neck * 0.22) * ANG(rad(-35), 0, 0), colors.Main, mat)
		weld(head, neckPiece)
	end
	local cheek = ellip(model, "Cheeks", H * V(0.9, 0.55, 0.7), headPos * CF(0, -H.Y * 0.2, -H.Z * 0.05), colors.Belly, mat)
	weld(head, cheek)
	local snout = buildSnout(model, head, H, S, colors, spec.Extras)
	buildEyes(model, head, H, colors, info.Behaviour ~= "Passive" and info.Behaviour ~= "Spirit", info.Behaviour == "Passive" or info.Behaviour == "Spirit")
	buildEars(model, head, H, colors, spec.Ears)

	-- ขา
	local parts = { Body = body, Head = head, Snout = snout }
	local hipY = bodyY - B.Y * 0.12
	local Lp = hipY
	for _, leg in ipairs({ { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } }) do
		local name, sx, sz = leg[1], leg[2], leg[3]
		local len = Lp
		local hip = CF(sx * B.X * 0.3, hipY, sz * B.Z * 0.3)
		if rabbit and sz > 0 then
			len = Lp * 1.0
		end
		local L = ellip(model, name, V(T, len, T * 1.15), hip * CF(0, -len / 2, 0), colors.Main, mat)
		motor(name, body, L, hip)
		local thigh = ellip(model, "Thigh", V(T * 1.55, len * 0.6, T * 1.9), hip * CF(0, -len * 0.2, sz * T * 0.15), colors.Main, mat)
		weld(L, thigh)
		local paw = ellip(model, "Paw", V(T * 1.3, T * 0.62, T * 1.7), hip * CF(0, -len + T * 0.3, -T * 0.25), colors.Dark or colors.Main, mat)
		weld(L, paw)
		parts[name] = L
	end
	parts.Tail1 = buildTail(model, body, B, spec)
	decorate(model, parts, spec, B)
	return root, legLen, parts
end
Templates.Rabbit = Templates.Quadruped

-- เลื้อยคลาน (จระเข้ ซาลาแมนเดอร์ เลวีอาธาน)
function Templates.Reptile(model, spec, info)
	local colors = spec.Colors
	local B, H, S = spec.Body, spec.Head, spec.Snout
	local legLen, T = spec.LegLen, spec.LegThick
	local bodyY = legLen * 0.85 + B.Y / 2
	local root = newPart(model, "HumanoidRootPart", V(B.X, B.Y, B.Z * 0.9), CF(0, bodyY, 0), colors.Main)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	local body = ellip(model, "Body", B, CF(0, bodyY, 0), colors.Main, Enum.Material.SmoothPlastic)
	motor("Root", root, body, CF(0, bodyY, 0))
	local belly = ellip(model, "Belly", B * V(0.85, 0.5, 0.9), CF(0, bodyY - B.Y * 0.22, 0), colors.Belly)
	weld(body, belly)
	-- หัว + ปากยาว
	local J = CF(0, bodyY + B.Y * 0.05, -B.Z * 0.46)
	local headCf = J * CF(0, H.Y * 0.05, -H.Z * 0.38)
	local head = ellip(model, "Head", H, headCf, colors.Main)
	motor("Neck", body, head, J)
	local snoutCf = headCf * CF(0, -H.Y * 0.08, -H.Z * 0.4 - S.Z * 0.42)
	local snout = ellip(model, "Snout", S, snoutCf, colors.Main)
	weld(head, snout)
	local jaw = ellip(model, "Jaw", S * V(0.92, 0.55, 1.0), snoutCf * CF(0, -S.Y * 0.4, S.Z * 0.05), colors.Belly)
	motor("Jaw", head, jaw, headCf * CF(0, -H.Y * 0.3, -H.Z * 0.3))
	for i = 1, 6 do
		for _, side in ipairs({ -1, 1 }) do
			local tooth = newPart(model, "Tooth", V(S.X * 0.07, S.Y * 0.3, S.X * 0.07), snoutCf * CF(side * S.X * 0.4, -S.Y * 0.25, -S.Z * 0.45 + i * S.Z * 0.13) * ANG(math.pi, 0, 0), Color3.fromRGB(245, 240, 225), Enum.Material.SmoothPlastic, "Wedge")
			weld(head, tooth)
		end
	end
	local nostril = newPart(model, "Nose", V(S.X * 0.5, S.Y * 0.3, S.X * 0.3), snoutCf * CF(0, S.Y * 0.32, -S.Z * 0.44), colors.Dark, Enum.Material.SmoothPlastic, "Ball")
	weld(head, nostril)
	buildEyes(model, head, H * V(1, 1.4, 1), colors, true, false)
	-- ขากาง
	local parts = { Body = body, Head = head, Snout = snout }
	for _, leg in ipairs({ { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } }) do
		local name, sx, sz = leg[1], leg[2], leg[3]
		local hip = CF(sx * B.X * 0.42, bodyY - B.Y * 0.1, sz * B.Z * 0.28)
		local len = bodyY - B.Y * 0.1 + T * 0.3
		local L = ellip(model, name, V(T, len, T * 1.1), hip * ANG(0, 0, sx * rad(28)) * CF(0, -len / 2, 0), colors.Main)
		motor(name, body, L, hip)
		local foot = ellip(model, "Foot", V(T * 1.8, T * 0.5, T * 2.2), L.CFrame * CF(0, -len / 2 + T * 0.2, -T * 0.4) * ANG(0, 0, -sx * rad(28)), colors.Dark)
		weld(L, foot)
		parts[name] = L
	end
	-- หางเป็นข้อๆ
	local tailLen = spec.TailLen or B.Z
	local segs = 3
	local prevPart, prevJoint = body, CF(0, bodyY + B.Y * 0.05, B.Z * 0.46)
	local width = B.X * 0.62
	for i = 1, segs do
		local segLen = tailLen / segs * 1.12
		local cf = prevJoint * ANG(rad(-4), 0, 0) * CF(0, 0, segLen * 0.45)
		local seg = ellip(model, "Tail" .. i, V(width, width * 0.7, segLen), cf, colors.Main)
		motor("Tail" .. i, prevPart, seg, prevJoint)
		prevPart = seg
		prevJoint = prevJoint * ANG(rad(-4), 0, 0) * CF(0, 0, segLen * 0.86)
		width *= 0.62
		if i == 1 then
			parts.Tail1 = seg
		end
		if spec.Extras and has(spec.Extras, "BackPlates") then
			for k = 1, 2 do
				local plate = newPart(model, "Spike", V(0.15, width * 0.8, width * 0.8), cf * CF(0, width * 0.5, -segLen * 0.3 + k * segLen * 0.25) * ANG(0, math.pi, 0), colors.Dark, Enum.Material.SmoothPlastic, "Wedge")
				weld(seg, plate)
			end
		end
	end
	decorate(model, parts, spec, B)
	return root, legLen * 0.85, parts
end

-- ปู
function Templates.Crab(model, spec, info)
	local colors = spec.Colors
	local B = spec.Body
	local legLen, T = spec.LegLen, spec.LegThick
	local bodyY = legLen * 0.8 + B.Y / 2
	local root = newPart(model, "HumanoidRootPart", V(B.X, B.Y, B.Z), CF(0, bodyY, 0), colors.Main)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	local body = ellip(model, "Body", B, CF(0, bodyY, 0), colors.Main)
	motor("Root", root, body, CF(0, bodyY, 0))
	local under = ellip(model, "Belly", B * V(0.9, 0.5, 0.9), CF(0, bodyY - B.Y * 0.2, 0), colors.Belly)
	weld(body, under)
	local rim = ellip(model, "Rim", B * V(1.05, 0.35, 1.05), CF(0, bodyY - B.Y * 0.05, 0), colors.Dark)
	weld(body, rim)
	-- ตาบนก้าน (ใช้เป็น Head)
	local head = newPart(model, "Head", V(B.X * 0.4, 0.4, 0.4), CF(0, bodyY + B.Y * 0.3, -B.Z * 0.4), colors.Main)
	head.Transparency = 1
	motor("Neck", body, head, CF(0, bodyY + B.Y * 0.3, -B.Z * 0.4))
	for _, side in ipairs({ -1, 1 }) do
		local stalk = newPart(model, "Stalk", V(0.25, B.Y * 0.5, 0.25), head.CFrame * CF(side * B.X * 0.12, B.Y * 0.22, 0), colors.Main)
		weld(head, stalk)
		local eye = newPart(model, "Eye", V(0.6, 0.6, 0.6), head.CFrame * CF(side * B.X * 0.12, B.Y * 0.5, 0), colors.Eye, Enum.Material.Glass, "Ball")
		weld(head, eye)
	end
	local parts = { Body = body, Head = head }
	-- ขา 6 ข้าง
	local idx = 0
	for _, side in ipairs({ -1, 1 }) do
		for k = 1, 3 do
			idx += 1
			local z = (k - 2) * B.Z * 0.3
			local hip = CF(side * B.X * 0.42, bodyY - B.Y * 0.05, z)
			local len = legLen * 1.5
			local L = newPart(model, "Leg" .. idx, V(T, len, T), hip * ANG(0, (k - 2) * side * rad(-20), 0) * ANG(0, 0, side * rad(62)) * CF(0, -len / 2, 0), colors.Main)
			motor("Leg" .. idx, body, L, hip)
			local tip = newPart(model, "LegTip", V(T * 0.8, legLen * 1.3, T * 0.8), L.CFrame * CF(0, -len / 2, 0) * ANG(0, 0, -side * rad(48)) * CF(0, -legLen * 0.65, 0), colors.Dark)
			weld(L, tip)
			parts["Leg" .. idx] = L
		end
	end
	-- ก้ามใหญ่
	for _, info2 in ipairs({ { "ClawL", -1 }, { "ClawR", 1 } }) do
		local name, side = info2[1], info2[2]
		local shoulder = CF(side * B.X * 0.38, bodyY, -B.Z * 0.4)
		local arm = ellip(model, name, V(B.X * 0.18, B.Y * 0.35, B.Z * 0.5), shoulder * ANG(0, side * rad(-25), 0) * CF(0, 0, -B.Z * 0.22), colors.Main)
		motor(name, body, arm, shoulder)
		local claw = ellip(model, "Pincer", V(B.X * 0.32, B.Y * 0.55, B.Z * 0.5), arm.CFrame * CF(0, B.Y * 0.05, -B.Z * 0.38), colors.Main)
		weld(arm, claw)
		local tip = newPart(model, "PincerTip", V(B.X * 0.1, B.Y * 0.2, B.Z * 0.3), claw.CFrame * CF(0, B.Y * 0.12, -B.Z * 0.28) * ANG(0, math.pi, 0), colors.Dark, Enum.Material.SmoothPlastic, "Wedge")
		weld(arm, tip)
		parts[name] = arm
	end
	decorate(model, parts, spec, B)
	return root, legLen * 0.8, parts
end

-- นก (เหยี่ยว ร็อก)
function Templates.Bird(model, spec, info)
	local colors = spec.Colors
	local B, H, W = spec.Body, spec.Head, spec.Wing
	local bodyY = B.Y * 0.9
	local root = newPart(model, "HumanoidRootPart", B * V(0.9, 0.9, 0.9), CF(0, bodyY, 0), colors.Main)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	local body = ellip(model, "Body", B, CF(0, bodyY, 0) * ANG(rad(-8), 0, 0), colors.Main)
	motor("Root", root, body, CF(0, bodyY, 0))
	local chest = ellip(model, "Chest", B * V(0.85, 0.75, 0.6), CF(0, bodyY - B.Y * 0.1, -B.Z * 0.2), colors.Belly)
	weld(body, chest)
	local J = CF(0, bodyY + B.Y * 0.3, -B.Z * 0.42)
	local headCf = J * CF(0, H.Y * 0.25, -H.Z * 0.25)
	local head = ellip(model, "Head", H, headCf, colors.Main)
	motor("Neck", body, head, J)
	local beak = newPart(model, "Beak", V(H.X * 0.35, H.Y * 0.32, H.Z * 0.7), headCf * CF(0, -H.Y * 0.05, -H.Z * 0.62), colors.Beak, Enum.Material.SmoothPlastic, "Wedge")
	weld(head, beak)
	local hook = newPart(model, "Jaw", V(H.X * 0.28, H.Y * 0.16, H.Z * 0.4), headCf * CF(0, -H.Y * 0.22, -H.Z * 0.5), colors.Beak)
	motor("Jaw", head, hook, headCf * CF(0, -H.Y * 0.15, -H.Z * 0.35))
	buildEyes(model, head, H, colors, true, false)
	local parts = { Body = body, Head = head }
	-- ปีก
	for _, wi in ipairs({ { "WingL", -1 }, { "WingR", 1 } }) do
		local name, side = wi[1], wi[2]
		local shoulder = CF(side * B.X * 0.42, bodyY + B.Y * 0.25, -B.Z * 0.12)
		local span = W.X / 2
		local wing = ellip(model, name, V(span, W.Y, W.Z), shoulder * CF(side * span * 0.48, 0, W.Z * 0.15), colors.Main)
		motor(name, body, wing, shoulder)
		local tip = ellip(model, "WingTip", V(span * 0.6, W.Y * 0.8, W.Z * 0.7), wing.CFrame * CF(side * span * 0.36, 0, W.Z * 0.12), colors.Dark)
		weld(wing, tip)
		for f = 1, 4 do
			local feather = newPart(model, "Feather", V(span * 0.14, W.Y * 0.6, W.Z * 0.7), wing.CFrame * CF(side * span * (0.05 + f * 0.1), 0, W.Z * 0.42) * ANG(0, side * rad(f * 4), 0), (f % 2 == 0) and colors.Dark or colors.Main)
			weld(wing, feather)
		end
		if colors.Glow then
			local edge = newPart(model, "WingGlow", V(span * 0.9, W.Y * 0.4, 0.15), wing.CFrame * CF(side * span * 0.05, 0, -W.Z * 0.45), colors.Glow, Enum.Material.Neon)
			weld(wing, edge)
		end
		parts[name] = wing
	end
	-- หางขนนก
	for i = -2, 2 do
		local f = newPart(model, "TailFeather", V(B.X * 0.18, 0.2, B.Z * 0.55), body.CFrame * CF(i * B.X * 0.1, B.Y * 0.05, B.Z * 0.62) * ANG(0, rad(i * 12), 0), (i % 2 == 0) and colors.Dark or colors.Main)
		weld(body, f)
	end
	-- ขา (หุบ)
	for _, side in ipairs({ -1, 1 }) do
		local leg = newPart(model, "Talon", V(0.3, B.Y * 0.5, 0.3), CF(side * B.X * 0.2, bodyY - B.Y * 0.6, B.Z * 0.05), colors.Beak)
		weld(body, leg)
	end
	decorate(model, parts, spec, B)
	return root, B.Y * 0.45, parts
end

-- เต่ายักษ์ (เทอร์ราก้อน)
function Templates.Tortoise(model, spec, info)
	local colors = spec.Colors
	local B, H = spec.Body, spec.Head
	local legLen, T = spec.LegLen, spec.LegThick
	local bodyY = legLen + B.Y * 0.25
	local root = newPart(model, "HumanoidRootPart", V(B.X * 0.8, B.Y * 0.5, B.Z * 0.8), CF(0, bodyY, 0), colors.Main)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	local body = ellip(model, "Body", B * V(0.9, 0.45, 0.92), CF(0, bodyY, 0), colors.Main)
	motor("Root", root, body, CF(0, bodyY, 0))
	local shell = ellip(model, "Shell", B, CF(0, bodyY + B.Y * 0.2, 0), colors.Shell, Enum.Material.Slate)
	weld(body, shell)
	local rimShell = ellip(model, "ShellRim", B * V(1.06, 0.3, 1.06), CF(0, bodyY - B.Y * 0.02, 0), colors.Dark, Enum.Material.Slate)
	weld(body, rimShell)
	-- ลายกระดอง
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local plate = ellip(model, "Plate", V(B.X * 0.28, B.Y * 0.2, B.Z * 0.26), shell.CFrame * CF(math.cos(a) * B.X * 0.3, B.Y * 0.32, math.sin(a) * B.Z * 0.3), colors.Moss, Enum.Material.Grass)
		weld(shell, plate)
	end
	local J = CF(0, bodyY + B.Y * 0.05, -B.Z * 0.46)
	local headCf = J * CF(0, H.Y * 0.4, -H.Z * 0.6)
	local head = ellip(model, "Head", H, headCf, colors.Main)
	motor("Neck", body, head, J)
	local neckPiece = ellip(model, "NeckFur", V(H.X * 0.7, H.Y * 0.9, H.Z * 1.2), J * CF(0, H.Y * 0.15, -H.Z * 0.25) * ANG(rad(-20), 0, 0), colors.Main)
	weld(head, neckPiece)
	local beak = ellip(model, "Snout", V(H.X * 0.7, H.Y * 0.5, H.Z * 0.5), headCf * CF(0, -H.Y * 0.12, -H.Z * 0.42), colors.Dark)
	weld(head, beak)
	local jaw = ellip(model, "Jaw", V(H.X * 0.65, H.Y * 0.3, H.Z * 0.5), headCf * CF(0, -H.Y * 0.35, -H.Z * 0.25), colors.Belly)
	motor("Jaw", head, jaw, headCf * CF(0, -H.Y * 0.25, H.Z * 0.1))
	buildEyes(model, head, H, colors, true, false)
	local parts = { Body = body, Head = head, Shell = shell }
	for _, leg in ipairs({ { "LegFL", -1, -1 }, { "LegFR", 1, -1 }, { "LegBL", -1, 1 }, { "LegBR", 1, 1 } }) do
		local name, sx, sz = leg[1], leg[2], leg[3]
		local hip = CF(sx * B.X * 0.36, bodyY, sz * B.Z * 0.32)
		local L = ellip(model, name, V(T, bodyY + T * 0.2, T * 1.1), hip * CF(0, -bodyY / 2, 0), colors.Main)
		motor(name, body, L, hip)
		for c = -1, 1 do
			local claw = newPart(model, "Claw", V(T * 0.18, T * 0.3, T * 0.4), hip * CF(c * T * 0.28, -bodyY + T * 0.1, -T * 0.55), colors.Horn or Color3.fromRGB(230, 220, 200), Enum.Material.SmoothPlastic, "Wedge")
			weld(L, claw)
		end
		parts[name] = L
	end
	local tail = ellip(model, "Tail1", V(T * 0.6, T * 0.5, T * 1.2), CF(0, bodyY, B.Z * 0.52), colors.Main)
	motor("Tail1", body, tail, CF(0, bodyY, B.Z * 0.45))
	parts.Tail1 = tail
	decorate(model, parts, spec, B)
	return root, legLen, parts
end

---------------------------------------------------------------- โมเดลจาก Blender
-- ชิ้นชื่อ Body/Head/Jaw/LegFL.../Tail1/WingL... -> ต่อกระดูกจากกล่องขอบของแต่ละชิ้น
local JOINT_RULES = {
	Head = function(p)
		return p.CFrame * CF(0, -p.Size.Y * 0.2, p.Size.Z * 0.35)
	end,
	Jaw = function(p)
		return p.CFrame * CF(0, 0, p.Size.Z * 0.4)
	end,
	Leg = function(p)
		return p.CFrame * CF(0, p.Size.Y * 0.45, 0)
	end,
	Tail = function(p)
		return p.CFrame * CF(0, 0, -p.Size.Z * 0.45)
	end,
	WingL = function(p)
		return p.CFrame * CF(p.Size.X * 0.45, 0, 0)
	end,
	WingR = function(p)
		return p.CFrame * CF(-p.Size.X * 0.45, 0, 0)
	end,
}

local function rigCustom(model, spec)
	local body = model:FindFirstChild("Body", true)
	if not body then
		return nil
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
			d.Parent = model
		end
	end
	-- ขนาดเพี้ยน (หน่วย cm/m ไม่ตรง) -> ปรับให้ใกล้ขนาดในสเปก
	local _, size0 = model:GetBoundingBox()
	if spec.Body then
		local expected = (spec.LegLen or 2) + spec.Body.Y + (spec.Neck or 0) * 0.6 + (spec.Head and spec.Head.Y * 0.5 or 0)
		local ratio = expected / math.max(size0.Y, 0.01)
		if ratio < 0.5 or ratio > 2 then
			pcall(function()
				model:ScaleTo(model:GetScale() * ratio)
			end)
		end
	end
	-- หันหน้าผิดทาง -> หมุนให้หัวอยู่ทาง -Z (LookVector ของ Roblox)
	local headPart = model:FindFirstChild("Head")
	if headPart then
		local dir = (headPart.Position - body.Position) * Vector3.new(1, 0, 1)
		if dir.Magnitude > 0.1 then
			local theta = math.atan2(-dir.X, -dir.Z)
			if math.abs(theta) > 0.3 then
				local pivot = CF(body.Position)
				local rot = pivot * ANG(0, -theta, 0) * pivot:Inverse()
				for _, p in ipairs(model:GetChildren()) do
					if p:IsA("BasePart") then
						p.CFrame = rot * p.CFrame
					end
				end
			end
		end
	end
	local cf, size = model:GetBoundingBox()
	local groundY = cf.Position.Y - size.Y / 2
	local root = newPart(model, "HumanoidRootPart", body.Size, body.CFrame, Color3.new(1, 1, 1))
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	motor("Root", root, body, body.CFrame)
	local head = model:FindFirstChild("Head")
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p ~= root and p ~= body then
			local n = p.Name
			if n == "Head" then
				motor("Neck", body, p, JOINT_RULES.Head(p))
			elseif n == "Jaw" and head then
				motor("Jaw", head, p, JOINT_RULES.Jaw(p))
			elseif n:match("^Leg") or n:match("^Claw") then
				motor(n, body, p, JOINT_RULES.Leg(p))
			elseif n:match("^Tail%d") then
				local idx = tonumber(n:match("%d+"))
				local parent = idx > 1 and model:FindFirstChild("Tail" .. (idx - 1)) or body
				motor(n, parent, p, JOINT_RULES.Tail(p))
			elseif n == "WingL" or n == "WingR" then
				motor(n, body, p, JOINT_RULES[n](p))
			else
				-- ของตกแต่ง: ติดกับชิ้นที่ใกล้ที่สุด
				local nearest, best = body, math.huge
				for _, q in ipairs({ body, head }) do
					if q then
						local d = (q.Position - p.Position).Magnitude
						if d < best then
							nearest, best = q, d
						end
					end
				end
				weld(nearest, p)
			end
		end
	end
	return root, body.Position.Y - body.Size.Y / 2 - groundY
end

---------------------------------------------------------------- โครงจากโมเดลจริง (AnimalMeshData)
-- 1 ชิ้นเมช = 1 Part (ขนาด/ตำแหน่งเท่าชิ้นเมช) -> client สวมผิวเมชจริงทับ (AnimalSkins)
-- ถ้าเครื่องไหนสร้างเมชไม่ได้ จะเห็น Part เป็นก้อนทรงรีสีเฉลี่ยของชิ้นนั้นแทน
local MAIN_PARTS = { Body = true, Head = true, Jaw = true, LegFL = true, LegFR = true, LegBL = true, LegBR = true, Tail1 = true, WingL = true, WingR = true }

local function buildFromMesh(model, data, spec)
	local parts = {}
	for _, p in ipairs(data.Parts) do
		local size = V(p.Size[1], p.Size[2], p.Size[3])
		local cf = CF(p.Center[1], p.Center[2], p.Center[3])
		local color = Color3.new(p.Color[1], p.Color[2], p.Color[3])
		local part
		if p.Glow then
			part = newPart(model, p.Name, size, cf, Color3.new(p.Glow[1], p.Glow[2], p.Glow[3]), Enum.Material.Neon)
		else
			part = ellip(model, p.Name, size, cf, color, Enum.Material.SmoothPlastic)
		end
		part:SetAttribute("SkinPart", true)
		parts[p.Name] = { Part = part, Data = p }
	end
	local body = parts.Body and parts.Body.Part
	if not body then
		return nil
	end
	local root = newPart(model, "HumanoidRootPart", body.Size * V(0.8, 0.8, 0.9), body.CFrame, Color3.new(1, 1, 1))
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	motor("Root", root, body, body.CFrame)
	local head = parts.Head and parts.Head.Part
	for name, entry in pairs(parts) do
		local p = entry.Part
		if name ~= "Body" then
			if MAIN_PARTS[name] then
				if name == "Head" then
					motor("Neck", body, p, JOINT_RULES.Head(p))
				elseif name == "Jaw" and head then
					motor("Jaw", head, p, JOINT_RULES.Jaw(p))
				elseif name:match("^Leg") then
					motor(name, body, p, JOINT_RULES.Leg(p))
				elseif name == "Tail1" then
					motor(name, body, p, JOINT_RULES.Tail(p))
				elseif name == "WingL" or name == "WingR" then
					-- ปีก: หมุนที่โคนปีก (ด้านที่ใกล้ลำตัว)
					local side = (p.Position.X < body.Position.X) and 1 or -1
					motor(name, body, p, p.CFrame * CF(side * p.Size.X * 0.45, 0, 0))
				end
			else
				local attach = parts[entry.Data.Attach]
				weld(attach and attach.Part or body, p)
			end
		end
	end
	-- พื้นอยู่ที่ y = 0 ในข้อมูล -> HipHeight = ก้นของ root
	local hip = root.Position.Y - root.Size.Y / 2
	return root, math.max(hip, 0.2)
end

---------------------------------------------------------------- สร้างโมเดลสุดท้าย
function AnimalModels.Build(id, opts)
	opts = opts or {}
	local info = Animals.Data[id]
	assert(info, "ไม่รู้จักสัตว์: " .. tostring(id))
	local spec = info.Model
	local model = Instance.new("Model")
	model.Name = id

	local root, hip
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("Animals") and assets.Animals:FindFirstChild(id)
	local meshFolder = ReplicatedStorage:FindFirstChild("AnimalMeshData")
	local meshModule = meshFolder and meshFolder:FindFirstChild(id)
	if meshModule and not opts.ForceProcedural then
		local ok, data = pcall(require, meshModule)
		if ok and data then
			root, hip = buildFromMesh(model, data, spec)
			if root then
				model:SetAttribute("MeshSkin", true)
			end
		end
	end
	if not root and custom and not opts.ForceProcedural then
		for _, c in ipairs(custom:GetChildren()) do
			c:Clone().Parent = model
		end
		root, hip = rigCustom(model, spec)
	end
	if not root then
		model:ClearAllChildren()
		local builder = Templates[spec.Template] or Templates.Quadruped
		root, hip = builder(model, spec, info)
	end

	model.PrimaryPart = root
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = hip
	hum.MaxHealth = (info.Health == math.huge) and 1e9 or info.Health
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = info.Speed or 16
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.MaxSlopeAngle = 70
	hum.AutoJumpEnabled = true
	hum.UseJumpPower = true
	hum.JumpPower = 40
	hum.Parent = model

	model:SetAttribute("AnimalId", id)
	local template = spec.Template
	if model:GetAttribute("MeshSkin") then
		-- โครงจากโมเดลจริงใช้ชื่อชิ้นมาตรฐาน: นกมีปีก / ที่เหลือเดินสี่ขา (ปู/เต่าก็ใช้ขาหน้า-หลัง)
		if model:FindFirstChild("WingL") then
			template = "Bird"
		elseif template == "Crab" or template == "Tortoise" then
			template = "Quadruped"
		end
	end
	model:SetAttribute("Template", template)
	model:SetAttribute("Element", info.Element or "None")
	model:SetAttribute("Behaviour", info.Behaviour)
	if opts.Tag ~= false then
		CollectionService:AddTag(model, "Animal")
	end
	return model
end

-- จุดหมุนให้วางบนพื้น: วางโมเดลให้เท้าอยู่ที่ position
function AnimalModels.PlaceAt(model, position, yaw)
	local root = model.PrimaryPart
	local cf, size = model:GetBoundingBox()
	local offset = root.Position.Y - (cf.Position.Y - size.Y / 2)
	model:PivotTo(CF(position + V(0, offset, 0)) * ANG(0, yaw or 0, 0))
end

return AnimalModels
