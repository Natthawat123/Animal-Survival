--[[
	MapLayout — "สมการ" ของแมพทั้งหมด (deterministic จาก seed)
	ใช้ทั้งฝั่ง Server (สร้าง Terrain/วางพร็อพ) และ Client (รู้ว่ายืนอยู่ไบโอมไหน -> เปลี่ยนบรรยากาศ)

	  - ทุ่งกลาง Heart ที่ (0,0) = ที่ตั้งกองไฟ
	  - 4 ธาตุ (Earth/Water/Air/Fire) วางรอบๆ แบบสุ่มมุม+ระยะ แล้วบิดขอบด้วย noise (domain warp)
	  - ขอบแมพเป็นทะเลลึกวงกลม
	  - แต่ละธาตุมีจุดพิเศษ: Lair (รังบอส), Shrine (กรงลูกสัตว์ธาตุ), Ruins (ซากปรักหักพัง มีหีบ)
	  - ธาตุลมมีเกาะลอยฟ้า (FloatingIslands)
]]

local MapLayout = {}
MapLayout.__index = MapLayout

local noise = math.noise
local sqrt = math.sqrt
local abs = math.abs
local floor = math.floor
local clamp = math.clamp
local exp = math.exp

local ELEMENTS = { "Earth", "Water", "Air", "Fire" }
local BLEND = 190 -- ความกว้างช่วงผสมระหว่างไบโอม

local function smooth(t)
	t = clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

function MapLayout.new(seed, size, config)
	local self = setmetatable({}, MapLayout)
	config = config or {}
	self.Seed = seed
	self.Size = size
	self.Half = size / 2
	self.WaterLevel = config.WaterLevel or 20
	self.HeartRadius = config.HeartRadius or 260
	self.EdgeOcean = config.EdgeOcean or 420

	local rng = Random.new(seed)
	self.ox = rng:NextNumber(-5000, 5000) + 0.137
	self.oz = rng:NextNumber(-5000, 5000) + 0.291
	self.nz = rng:NextNumber(0, 100) + 0.173

	-- สุ่มลำดับธาตุ (ใครอยู่ทิศไหน)
	local order = table.clone(ELEMENTS)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local baseAngle = rng:NextNumber(0, math.pi * 2)
	self.Sites = {}
	self.SiteList = {}
	for i, el in ipairs(order) do
		local ang = baseAngle + (i - 1) * math.pi / 2 + rng:NextNumber(-0.32, 0.32)
		local dist = self.Half * rng:NextNumber(0.46, 0.6)
		local site = { Element = el, X = math.cos(ang) * dist, Z = math.sin(ang) * dist, Angle = ang, Dist = dist }
		self.Sites[el] = site
		table.insert(self.SiteList, site)
	end

	self:_placeSpecials(rng)
	return self
end

---------------------------------------------------------------- noise helpers
function MapLayout:_n(x, z, f)
	return noise(x * f + self.ox, z * f + self.oz, self.nz)
end

function MapLayout:_fbm(x, z, f, oct)
	local sum, amp, norm = 0, 1, 0
	for _ = 1, oct do
		sum += noise(x * f + self.ox, z * f + self.oz, self.nz) * amp
		norm += amp
		amp *= 0.5
		f *= 2.03
	end
	return sum / norm * 1.6 -- ~[-1,1]
end

function MapLayout:_ridged(x, z, f, oct)
	local sum, amp, norm = 0, 1, 0
	for i = 1, oct do
		local n = 1 - abs(noise(x * f + self.oz, z * f + self.ox, self.nz + i * 3.7))
		sum += n * n * amp
		norm += amp
		amp *= 0.5
		f *= 2.1
	end
	return sum / norm
end

---------------------------------------------------------------- ไบโอม
-- คืนค่า: biomeId ที่แสดง ("Heart" ถ้าอยู่ทุ่งกลาง), น้ำหนักธาตุหลัก (0.5..1), ธาตุหลัก, ธาตุรอง, น้ำหนัก heart (0..1)
function MapLayout:BiomeAt(x, z)
	local r = sqrt(x * x + z * z)
	local heartEdge = self.HeartRadius * (1 + self:_n(x, z, 1 / 260) * 0.25)
	local heartW = 1 - smooth((r - heartEdge) / 150)

	-- domain warp ให้ขอบไบโอมคดเคี้ยว
	local wx = x + self:_fbm(x, z, 1 / 900, 3) * 420
	local wz = z + self:_fbm(z + 999, x - 333, 1 / 900, 3) * 420

	local best, bestD, second, secondD = nil, math.huge, nil, math.huge
	for _, s in ipairs(self.SiteList) do
		local dx, dz = wx - s.X, wz - s.Z
		local d = dx * dx + dz * dz
		if d < bestD then
			second, secondD = best, bestD
			best, bestD = s.Element, d
		elseif d < secondD then
			second, secondD = s.Element, d
		end
	end
	bestD, secondD = sqrt(bestD), sqrt(secondD)
	local w = 0.5 + 0.5 * clamp((secondD - bestD) / BLEND, 0, 1)
	return (heartW > 0.5) and "Heart" or best, w, best, second, heartW
end

---------------------------------------------------------------- ความสูงแต่ละไบโอม
-- คืน height, lava(bool)
function MapLayout:_heightFor(biome, x, z)
	if biome == "Earth" then
		local h = 36 + self:_fbm(x, z, 1 / 700, 4) * 52
		local mask = smooth((self:_fbm(x + 4000, z, 1 / 1500, 2) + 0.1) / 0.5)
		local ridge = self:_ridged(x, z, 1 / 520, 3)
		h += ridge ^ 3 * 210 * mask
		return h, false
	elseif biome == "Water" then
		local h = -4 + self:_fbm(x, z, 1 / 520, 4) * 70
		local s = self.Sites.Water
		local dx, dz = x - s.X, z - s.Z
		local d = sqrt(dx * dx + dz * dz)
		if d < 340 then
			-- อะทอลล์: วงแหวนเกาะรอบทะเลสาบลึก มีเกาะรังบอสตรงกลาง
			local ring = exp(-((d - 230) / 42) ^ 2) * 52
			local lagoon = smooth((230 - d) / 60)
			h = lerp(h, -58, lagoon * 0.95) + ring
			if d < 52 then
				h = lerp(h, 32, smooth((52 - d) / 20))
			end
		end
		return h, false
	elseif biome == "Air" then
		local h = 74 + self:_fbm(x, z, 1 / 800, 4) * 52
		local mask = smooth((self:_fbm(x - 7000, z + 300, 1 / 900, 2) + 0.05) / 0.4)
		local spire = self:_ridged(x, z, 1 / 300, 2)
		h += spire ^ 5 * 330 * mask
		return h, false
	elseif biome == "Fire" then
		local base = 40 + self:_fbm(x, z, 1 / 650, 4) * 40
		-- ขั้นบันไดแบบเมซา
		local t = 16
		local step = floor(base / t)
		local frac = base / t - step
		local h = step * t + smooth((frac - 0.6) / 0.4) * t
		local s = self.Sites.Fire
		local dx, dz = x - s.X, z - s.Z
		local d = sqrt(dx * dx + dz * dz)
		local lava = false
		-- ภูเขาไฟ + ปล่อง
		local cone = math.max(0, 1 - d / 720) ^ 1.7 * 320
		if d < 130 then
			cone -= (1 - d / 130) ^ 1.4 * 190
			if d < 96 then
				lava = true
			end
		end
		h += cone
		-- แม่น้ำลาวา
		local river = abs(self:_n(x + 1234, z - 777, 1 / 380))
		if river < 0.05 and d > 160 then
			h -= (0.05 - river) / 0.05 * 12
			lava = true
		end
		return h, lava
	end
	-- Heart
	return 34 + self:_n(x, z, 1 / 220) * 5 + self:_n(x, z, 1 / 60) * 1.2, false
end

-- ความสูงพื้นผิวสุดท้าย + ไบโอม (ใช้ทั้ง generator, การวางพร็อพ, client)
function MapLayout:HeightAt(x, z)
	local biome, w, main, second, heartW = self:BiomeAt(x, z)
	local h, lava = self:_heightFor(main, x, z)
	if w < 0.999 and second then
		local h2 = self:_heightFor(second, x, z)
		h = h * w + h2 * (1 - w)
		lava = lava and w > 0.62
	end
	if heartW > 0 then
		local hh = self:_heightFor("Heart", x, z)
		h = lerp(h, hh, heartW)
		if heartW > 0.3 then
			lava = false
		end
	end
	-- ขอบแมพ -> ทะเลลึก (วงกลม)
	local r = sqrt(x * x + z * z)
	local edge = smooth((r - (self.Half - self.EdgeOcean)) / (self.EdgeOcean * 0.75))
	if edge > 0 then
		h = lerp(h, -70, edge)
		lava = lava and edge < 0.3
	end
	return h, biome, lava, main
end

---------------------------------------------------------------- จุดพิเศษ
function MapLayout:_randomPointIn(rng, element, minR, maxR, tries)
	local s = self.Sites[element]
	for _ = 1, tries or 60 do
		local ang = s.Angle + rng:NextNumber(-0.7, 0.7)
		local dist = rng:NextNumber(minR, maxR)
		local x, z = math.cos(ang) * dist, math.sin(ang) * dist
		local h, biome = self:HeightAt(x, z)
		if biome == element and h > self.WaterLevel + 3 then
			return x, h, z
		end
	end
	-- หาไม่เจอ: ใช้กลางไบโอม
	local h = self:HeightAt(s.X, s.Z)
	return s.X, h, s.Z
end

function MapLayout:_placeSpecials(rng)
	self.Specials = {}
	self.FloatingIslands = {}
	self.Updrafts = {}
	for _, el in ipairs(ELEMENTS) do
		local s = self.Sites[el]
		local lairH = self:HeightAt(s.X, s.Z)
		local lair = { Kind = "Lair", Element = el, Position = Vector3.new(s.X, lairH, s.Z) }
		local sx, sh, sz = self:_randomPointIn(rng, el, s.Dist * 0.5, s.Dist * 0.85)
		local shrine = { Kind = "Shrine", Element = el, Position = Vector3.new(sx, sh, sz) }
		table.insert(self.Specials, lair)
		table.insert(self.Specials, shrine)
		for _ = 1, 3 do
			local rx, rh, rz = self:_randomPointIn(rng, el, s.Dist * 0.45, s.Dist * 1.35)
			table.insert(self.Specials, { Kind = "Ruins", Element = el, Position = Vector3.new(rx, rh, rz) })
		end
		for _ = 1, 4 do
			local cx, ch, cz = self:_randomPointIn(rng, el, s.Dist * 0.4, s.Dist * 1.4)
			table.insert(self.Specials, { Kind = "Rift", Element = el, Position = Vector3.new(cx, ch, cz) })
		end
	end

	-- เกาะลอยฟ้าในเขตธาตุลม
	local air = self.Sites.Air
	local nest = { X = air.X, Y = 430, Z = air.Z, R = 70, Nest = true }
	table.insert(self.FloatingIslands, nest)
	-- รังบอสธาตุลมอยู่บนเกาะสูงสุด
	for _, sp in ipairs(self.Specials) do
		if sp.Kind == "Lair" and sp.Element == "Air" then
			sp.Position = Vector3.new(nest.X, nest.Y + nest.R * 0.18, nest.Z)
			sp.Floating = true
		end
	end
	local count = 0
	for _ = 1, 200 do
		if count >= 22 then
			break
		end
		local ang = air.Angle + rng:NextNumber(-0.9, 0.9)
		local dist = air.Dist * rng:NextNumber(0.35, 1.45)
		local x, z = math.cos(ang) * dist, math.sin(ang) * dist
		local h, biome = self:HeightAt(x, z)
		if biome == "Air" then
			local ok = true
			for _, isl in ipairs(self.FloatingIslands) do
				if (isl.X - x) ^ 2 + (isl.Z - z) ^ 2 < (isl.R + 80) ^ 2 then
					ok = false
					break
				end
			end
			if ok then
				local R = rng:NextNumber(28, 62)
				local y = math.max(h + rng:NextNumber(110, 200), 230 + rng:NextNumber(0, 140))
				table.insert(self.FloatingIslands, { X = x, Y = y, Z = z, R = R })
				count += 1
				-- ลมพัดขึ้น (ส่งผู้เล่นขึ้นเกาะ)
				if rng:NextNumber() < 0.6 then
					table.insert(self.Updrafts, { Position = Vector3.new(x + R * 1.2, h, z), Height = y - h + 30 })
				end
			end
		end
	end
	-- ลมพัดขึ้นสู่รังบอส (ต้องผ่านเกาะ)
	local nh = self:HeightAt(air.X + 120, air.Z)
	table.insert(self.Updrafts, { Position = Vector3.new(air.X + 120, nh, air.Z), Height = nest.Y - nh + 40 })
end

function MapLayout:GetSpecials(kind, element)
	local out = {}
	for _, sp in ipairs(self.Specials) do
		if (not kind or sp.Kind == kind) and (not element or sp.Element == element) then
			table.insert(out, sp)
		end
	end
	return out
end

-- จุดเกิดของฝูงบุก (รอบกองไฟ, บนบก)
function MapLayout:RaidSpawnPoint(rng, minR, maxR, preferElement)
	for _ = 1, 40 do
		local ang
		if preferElement and self.Sites[preferElement] then
			ang = self.Sites[preferElement].Angle + rng:NextNumber(-0.8, 0.8)
		else
			ang = rng:NextNumber(0, math.pi * 2)
		end
		local d = rng:NextNumber(minR, maxR)
		local x, z = math.cos(ang) * d, math.sin(ang) * d
		local h, _, lava = self:HeightAt(x, z)
		if h > self.WaterLevel + 1 and not lava then
			return Vector3.new(x, h + 4, z)
		end
	end
	return Vector3.new(minR, self:HeightAt(minR, 0) + 6, 0)
end

return MapLayout
