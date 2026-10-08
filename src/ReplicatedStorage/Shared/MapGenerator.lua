--[[
	MapGenerator — สร้าง Terrain จาก MapLayout ด้วย WriteVoxels ทีละชิ้น (chunk)
	อยู่ใน Shared เพราะปลั๊กอินตอน Edit ใช้สร้างแมพตัวอย่างด้วย

	MapGenerator.Generate(layout, {
		Yield = true,                 -- พักทุกๆ ชิ้น (ไม่ให้เกมค้าง)
		Progress = function(done, total) end,
		Radius = nil,                 -- สร้างแค่รัศมีนี้ (nil = ทั้งแมพ)
		SkipRadius = nil,             -- ข้ามชิ้นที่อยู่ในรัศมีนี้ (สร้างไปแล้ว)
	})
]]

local Biomes = require(script.Parent.Biomes)

local MapGenerator = {}

local RES = 4
local SAMPLE = 8 -- ระยะห่างจุดคำนวณความสูง (studs)
local floor = math.floor
local ceil = math.ceil
local clamp = math.clamp
local abs = math.abs

local M = {}
for name in pairs(Biomes.MaterialColors) do
	M[name] = Enum.Material[name]
end
M.Water = Enum.Material.Water
M.Air = Enum.Material.Air
local AIR = Enum.Material.Air
local WATER = Enum.Material.Water
local LAVA = Enum.Material.CrackedLava

-- เลือกวัสดุผิวบนสุด
local function topMaterial(biome, h, slope, lava, waterLevel)
	local t = Biomes.Data[biome].Terrain
	if lava then
		return LAVA
	end
	if h < waterLevel - 3 then
		if biome == "Fire" then
			return M.Basalt
		elseif biome == "Earth" then
			return M.Mud
		elseif biome == "Air" then
			return M.Slate
		end
		return M.Sand
	end
	if slope > 1.05 then
		return M[t.Cliff]
	end
	if h < waterLevel + 2.5 then
		return M[t.Shore]
	end
	if biome == "Air" then
		if h > 300 then
			return M.Glacier
		elseif h > 128 then
			return M.Snow
		end
		return slope > 0.6 and M.Slate or M.Salt
	end
	if biome == "Earth" and h > 210 then
		return M.Rock
	end
	if slope > 0.75 then
		return M[t.Sub]
	end
	return M[t.Top]
end

function MapGenerator.ApplyColors(terrain)
	for name, color in pairs(Biomes.MaterialColors) do
		pcall(function()
			terrain:SetMaterialColor(Enum.Material[name], color)
		end)
	end
	terrain.WaterColor = Color3.fromRGB(28, 112, 140)
	terrain.WaterTransparency = 0.72
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.18
	terrain.WaterWaveSpeed = 9
	pcall(function()
		terrain.Decoration = true -- หญ้าขึ้นบน Grass/LeafyGrass
	end)
end

-- สร้าง 1 ชิ้น: (x0, z0) มุมของชิ้น, n = จำนวน voxel ต่อด้าน
function MapGenerator.GenerateChunk(layout, terrain, x0, z0, n)
	local waterLevel = layout.WaterLevel
	local inland2 = (layout.Half - layout.EdgeOcean) ^ 2
	local studs = n * RES
	local ns = studs // SAMPLE -- จำนวนช่องตัวอย่าง
	-- ตารางความสูง (index -1 .. ns+1 เพื่อหาความชันขอบ)
	local H, B, L = {}, {}, {}
	local minH, maxH = math.huge, -math.huge
	for i = -1, ns + 1 do
		local hx, bx, lx = {}, {}, {}
		H[i], B[i], L[i] = hx, bx, lx
		local x = x0 + i * SAMPLE
		for k = -1, ns + 1 do
			local h, biome, lava, main = layout:HeightAt(x, z0 + k * SAMPLE)
			hx[k] = h
			bx[k] = (biome == "Heart") and "Heart" or main
			lx[k] = lava
			if h < minH then
				minH = h
			end
			if h > maxH then
				maxH = h
			end
		end
	end

	local top = math.max(maxH, waterLevel) + 6
	local bottom = math.min(minH, waterLevel) - 14
	local y0 = floor(bottom / RES) * RES
	local y1 = ceil(top / RES) * RES
	local ny = (y1 - y0) // RES
	if ny <= 0 then
		return
	end

	local materials = table.create(n)
	local occupancy = table.create(n)
	for vx = 1, n do
		local matX = table.create(ny)
		local occX = table.create(ny)
		materials[vx] = matX
		occupancy[vx] = occX
		for vy = 1, ny do
			matX[vy] = table.create(n, AIR)
			occX[vy] = table.create(n, 0)
		end
	end

	for vx = 1, n do
		local wx = x0 + (vx - 0.5) * RES
		local fx = (wx - x0) / SAMPLE
		local i0 = floor(fx)
		local tx = fx - i0
		local ir = (tx < 0.5) and i0 or i0 + 1
		local matX = materials[vx]
		local occX = occupancy[vx]
		for vz = 1, n do
			local wz = z0 + (vz - 0.5) * RES
			local fz = (wz - z0) / SAMPLE
			local k0 = floor(fz)
			local tz = fz - k0
			local kr = (tz < 0.5) and k0 or k0 + 1
			-- bilinear
			local h00, h10 = H[i0][k0], H[i0 + 1][k0]
			local h01, h11 = H[i0][k0 + 1], H[i0 + 1][k0 + 1]
			local h = (h00 * (1 - tx) + h10 * tx) * (1 - tz) + (h01 * (1 - tx) + h11 * tx) * tz
			local biome = B[ir][kr]
			local lava = L[ir][kr]
			local slope = math.max(abs(H[ir + 1][kr] - H[ir - 1][kr]), abs(H[ir][kr + 1] - H[ir][kr - 1])) / (2 * SAMPLE)
			local topMat = topMaterial(biome, h, slope, lava, waterLevel)
			local t = Biomes.Data[biome].Terrain
			local subMat = M[t.Sub]
			local deepMat = M[t.Cliff]
			if lava then
				subMat = M.Basalt
			end
			-- แอ่งต่ำในเขตไฟ = ทะเลสาบลาวา (แต่ทะเลขอบแมพยังเป็นน้ำ)
			local lavaFill = (biome == "Fire") and h > waterLevel - 26 and (wx * wx + wz * wz) < inland2
			for vy = 1, ny do
				local yb = y0 + (vy - 1) * RES
				local yt = yb + RES
				if yb < h then
					local occ = clamp((h - yb) / RES, 0, 1)
					local depth = h - (yb + RES * 0.5)
					local mat
					if depth < 4.5 then
						mat = topMat
					elseif depth < 14 then
						mat = (topMat == LAVA) and M.Basalt or subMat
					else
						mat = deepMat
					end
					matX[vy][vz] = mat
					occX[vy][vz] = occ
				elseif yt <= waterLevel + 0.01 then
					if lavaFill then
						matX[vy][vz] = LAVA
					else
						matX[vy][vz] = WATER
					end
					occX[vy][vz] = 1
				end
			end
		end
	end

	local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + studs, y1, z0 + studs))
	terrain:WriteVoxels(region, RES, materials, occupancy)
end

-- เกาะลอยฟ้า (ธาตุลม)
function MapGenerator.BuildFloatingIslands(layout, terrain)
	for idx, isl in ipairs(layout.FloatingIslands) do
		local p = Vector3.new(isl.X, isl.Y, isl.Z)
		local R = isl.R
		-- ทรงกรวยกลับหัว: วางลูกบอลเป็นวงๆ แต่ละชั้นเล็กลงเรื่อยๆ
		local layers = 7
		for j = 0, layers - 1 do
			local t = j / (layers - 1)
			local layerR = R * (1 - t) ^ 1.25 + R * 0.06
			local y = p.Y - R * 0.22 - j * R * 0.24
			local ballR = math.max(layerR * 0.5, 5)
			local mat = (j == 0) and Enum.Material.Ground or ((j > layers - 3) and Enum.Material.Glacier or Enum.Material.Slate)
			terrain:FillBall(Vector3.new(p.X, y, p.Z), ballR * 1.05, mat)
			local ringCount = math.max(3, math.floor(layerR / 9))
			for k = 0, ringCount - 1 do
				local ang = k / ringCount * math.pi * 2 + idx * 0.7 + j * 0.45
				local rr = layerR - ballR * 0.75
				local wob = 1 + math.sin(k * 2.3 + j) * 0.12
				terrain:FillBall(Vector3.new(p.X + math.cos(ang) * rr * wob, y + math.sin(k * 1.7) * 3, p.Z + math.sin(ang) * rr * wob), ballR, mat)
			end
		end
		-- ตัดยอดให้แบน แล้วปูหญ้า
		terrain:FillCylinder(CFrame.new(p + Vector3.new(0, R * 0.5, 0)), R, R * 1.3, Enum.Material.Air)
		terrain:FillCylinder(CFrame.new(p - Vector3.new(0, 2, 0)), 4, R * 0.97, Enum.Material.LeafyGrass)
		if isl.Nest then
			-- ขอบรังบอส
			for a = 0, 13 do
				local ang = a / 14 * math.pi * 2
				terrain:FillBall(p + Vector3.new(math.cos(ang) * R * 0.95, R * 0.12, math.sin(ang) * R * 0.95), R * 0.15, Enum.Material.Slate)
			end
		end
	end
end

-- ปรับพื้นที่ลานพิเศษ (แคมป์ / รังบอส / ศาลเจ้า)
function MapGenerator.FlattenPad(terrain, position, radius, material, clearHeight)
	local top = position.Y
	terrain:FillCylinder(CFrame.new(position.X, top + (clearHeight or 60) / 2 + 0.5, position.Z), clearHeight or 60, radius, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(position.X, top - 10, position.Z), 20, radius, material)
	-- ฐานลาดลงกันลอย
	terrain:FillCylinder(CFrame.new(position.X, top - 34, position.Z), 30, radius * 1.15, Enum.Material.Rock)
end

function MapGenerator.BuildSpecialPads(layout, terrain)
	-- แคมป์กลาง
	local campY = layout:HeightAt(0, 0)
	MapGenerator.FlattenPad(terrain, Vector3.new(0, campY, 0), 48, Enum.Material.Grass, 40)
	terrain:FillCylinder(CFrame.new(0, campY - 0.5, 0), 1.2, 10, Enum.Material.Cobblestone)
	for _, sp in ipairs(layout.Specials) do
		if sp.Kind == "Lair" and not sp.Floating then
			local pos = sp.Position
			local y = math.max(pos.Y, layout.WaterLevel + 6)
			local mat = ({ Earth = Enum.Material.Mud, Water = Enum.Material.Sand, Fire = Enum.Material.Basalt })[sp.Element] or Enum.Material.Rock
			MapGenerator.FlattenPad(terrain, Vector3.new(pos.X, y, pos.Z), sp.Element == "Water" and 50 or 75, mat, 120)
			sp.Position = Vector3.new(pos.X, y, pos.Z)
		elseif sp.Kind == "Shrine" then
			local pos = sp.Position
			MapGenerator.FlattenPad(terrain, pos, 26, Enum.Material.Cobblestone, 50)
		end
	end
end

-- รายการชิ้นทั้งหมด เรียงจากกลางออกไป
function MapGenerator.ChunkList(layout, n, radius, skipRadius)
	local studs = n * RES
	local half = layout.Half
	local start = -floor(half / studs) * studs
	local list = {}
	for x0 = start, half - 1, studs do
		for z0 = start, half - 1, studs do
			local cx, cz = x0 + studs / 2, z0 + studs / 2
			local d = math.sqrt(cx * cx + cz * cz)
			local inside = true
			local inRadius = not radius or d - studs * 0.71 <= radius
			local skipped = skipRadius and d + studs * 0.71 <= skipRadius
			if inside and inRadius and not skipped then
				table.insert(list, { x0, z0, d })
			end
		end
	end
	table.sort(list, function(a, b)
		return a[3] < b[3]
	end)
	return list
end

function MapGenerator.Generate(layout, opts)
	opts = opts or {}
	local terrain = workspace.Terrain
	local n = opts.ChunkVoxels or 48
	MapGenerator.ApplyColors(terrain)
	local list = MapGenerator.ChunkList(layout, n, opts.Radius, opts.SkipRadius)
	local t0 = os.clock()
	for idx, c in ipairs(list) do
		MapGenerator.GenerateChunk(layout, terrain, c[1], c[2], n)
		if opts.Progress then
			opts.Progress(idx, #list)
		end
		if opts.Yield and os.clock() - t0 > (opts.Budget or 0.05) then
			task.wait()
			t0 = os.clock()
		end
	end
	if not opts.SkipExtras then
		MapGenerator.BuildFloatingIslands(layout, terrain)
		MapGenerator.BuildSpecialPads(layout, terrain)
	end
end

return MapGenerator
