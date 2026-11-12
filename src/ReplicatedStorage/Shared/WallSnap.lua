--[[
	WallSnap — กำแพง (ไม้/หิน) วางต่อกันอัตโนมัติ (แบบเกมเอาชีวิตรอดซอมบี้)
	  เล็งใกล้ปลายกำแพงที่วางอยู่ -> เงากำแพงใหม่ดูดไปต่อปลายพอดี: ต่อตรง หรือหักมุม 90° (เลือกตามจุดที่เล็ง)
	  ไม้ต่อหิน/หินต่อไม้ได้

	WallSnap.IsWall(kind) -> bool
	WallSnap.Find(kind, aim, folder, ignore) -> CFrame จุดหมุน (ที่พื้น ยังไม่ปรับความสูง) หรือ nil ถ้าไม่มีกำแพงให้ต่อใกล้ ๆ
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StructureModels = require(ReplicatedStorage.Shared.StructureModels)

local WallSnap = {}

local WALLS = { LogWall = true, StoneWall = true }
local SNAP_EXTRA = 4 -- เล็งห่างจากตำแหน่งที่จะต่อไม่เกิน (ครึ่งความยาวกำแพง + ค่านี้) ถึงดูด

function WallSnap.IsWall(kind)
	return WALLS[kind] == true
end

-- กล่องของกำแพงแต่ละชนิดในพิกัดของจุดหมุน (วัดจากโมเดลจริงครั้งเดียว): ศูนย์กลาง, ครึ่งยาว, ครึ่งหนา, แกนยาว
local boxes = {}
local function boxOf(kind)
	if boxes[kind] then
		return boxes[kind]
	end
	local m = StructureModels.Build(kind)
	local pv = m:GetPivot()
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.95 then
			local s = p.Size / 2
			for _, c in ipairs({ Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
				Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) }) do
				local w = pv:PointToObjectSpace(p.CFrame:PointToWorldSpace(s * c))
				lo, hi = lo:Min(w), hi:Max(w)
			end
		end
	end
	m:Destroy()
	local center, half = (lo + hi) / 2, (hi - lo) / 2
	local alongX = half.X >= half.Z
	local b = {
		Center = Vector3.new(center.X, 0, center.Z),
		Len = alongX and half.X or half.Z,
		Thick = alongX and half.Z or half.X,
		AlongX = alongX,
	}
	boxes[kind] = b
	return b
end

local function flat(v)
	v = Vector3.new(v.X, 0, v.Z)
	return v.Magnitude > 1e-4 and v.Unit or Vector3.xAxis
end

-- จุดหมุนของกำแพงชนิด kind ที่ให้ศูนย์กลางอยู่ที่ center และแกนยาวชี้ไปทาง dir
local function pivotFor(kind, center, dir)
	local b = boxOf(kind)
	local rot
	if b.AlongX then
		rot = CFrame.lookAt(Vector3.zero, Vector3.yAxis:Cross(dir)) -- RightVector = dir
	else
		rot = CFrame.lookAt(Vector3.zero, dir) -- LookVector = dir
	end
	local pos = center - rot:VectorToWorldSpace(b.Center)
	return CFrame.new(pos) * rot
end

function WallSnap.Find(kind, aim, folder, ignore)
	if not WALLS[kind] or not folder then
		return nil
	end
	local nb = boxOf(kind)
	local aimFlat = Vector3.new(aim.X, 0, aim.Z)
	local walls, centers = {}, {}
	for _, w in ipairs(folder:GetChildren()) do
		local k = w:GetAttribute("Kind")
		if WALLS[k] and w ~= ignore and not w:GetAttribute("Broken") and w:IsA("Model") then
			local pv = w:GetPivot()
			local b = boxOf(k)
			local c = pv:PointToWorldSpace(b.Center)
			c = Vector3.new(c.X, 0, c.Z)
			if (c - aimFlat).Magnitude < b.Len * 2 + nb.Len * 2 + SNAP_EXTRA then
				table.insert(walls, { Pivot = pv, Box = b, Center = c })
			end
			table.insert(centers, c)
		end
	end
	local best, bestD
	for _, w in ipairs(walls) do
		local A = flat(w.Box.AlongX and w.Pivot.RightVector or w.Pivot.LookVector)
		local B = Vector3.new(-A.Z, 0, A.X)
		for _, s in ipairs({ 1, -1 }) do
			local E = w.Center + A * (s * w.Box.Len)
			local cands = {
				{ E + A * (s * nb.Len), A }, -- ต่อตรง
			}
			for _, t in ipairs({ 1, -1 }) do
				-- หักมุม 90°: ปลายกำแพงใหม่ชนหน้ากำแพงเดิม มุมปิดสนิท
				table.insert(cands, { E - A * (s * nb.Thick) + B * (t * (nb.Len + w.Box.Thick)), B * t })
			end
			for _, c in ipairs(cands) do
				local d = (c[1] - aimFlat).Magnitude
				if d < nb.Len + SNAP_EXTRA and (not bestD or d < bestD) then
					-- ตรงนั้นมีกำแพงอยู่แล้ว = ข้าม
					local taken = false
					for _, oc in ipairs(centers) do
						if (oc - c[1]).Magnitude < 1.5 then
							taken = true
							break
						end
					end
					if not taken then
						best, bestD = c, d
					end
				end
			end
		end
	end
	if not best then
		return nil
	end
	local cf = pivotFor(kind, best[1], best[2])
	return CFrame.new(cf.X, aim.Y, cf.Z) * cf.Rotation -- ความสูง = จุดที่เล็ง (ฝั่ง client/server หาพื้นจริงต่อเอง)
end

-- กล่องกันวางทับของกำแพง (ตามแนวกำแพงจริง ไม่ใช่ Items.Structures.Size ที่วางแกนผิด) -> CFrame กลางกล่อง, ขนาด
function WallSnap.OverlapBox(kind, pivot, height)
	local b = boxOf(kind)
	local c = pivot:PointToWorldSpace(b.Center) + Vector3.new(0, height / 2 + 0.5, 0)
	local len, thick = b.Len * 2 * 0.85, math.max(b.Thick * 2, 0.6) * 0.85
	local size = b.AlongX and Vector3.new(len, height, thick) or Vector3.new(thick, height, len)
	return CFrame.new(c) * pivot.Rotation, size
end

return WallSnap
