--[[
	BreakFX — แอนิเมชันพัง/วางของในโลก แยกตามวัสดุ (เล่นฝั่งเครื่องผู้เล่น ลื่น 60fps)
	  ต้นไม้: เอี๊ยด -> ล้มตามทิศที่ฟัน -> ใบไม้ร่วง/ฝุ่นตามแนวลำต้น -> จมดิน
	  หิน/แร่: สั่น -> แตกเป็นก้อน (สีหิน + สีแร่) · คริสตัล: พองแล้วแตกเป็นเศษเรืองแสง
	  สิ่งก่อสร้าง: ไม้ = หักล้ม+เสี้ยนไม้ · กำแพงหิน = ทรุดลงเป็นกองหิน · หม้อ = คว่ำกลิ้ง+ประกายไฟ
	    ตะเกียง = ไฟกะพริบดับ+แก้วแตก+เสาล้ม · ประภาคาร = แสงวาบแล้วถล่ม · เสาธาตุ = พลังพลุ่งแล้วระเบิดสีธาตุ
	  วาง: ไม้/ผ้า/ดิน/โลหะ = ชิ้นส่วนหล่นลงประกอบกัน · หิน/เสาธาตุ/ประภาคาร = ผุดขึ้นจากดิน · ตะเกียง = ไฟค่อยๆ ติด
	เศษที่กระเด็นจำลองการตกเอง (raycast ชนพื้น) ไม่ใช้ฟิสิกส์จริง -> ไม่ดันตัวผู้เล่น
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))

local BreakFX = {}
local env = {} -- { Sound, Shake, Burst, Smoke, Ring, Flash, ElementColors } จาก CombatClient

local C = Color3.fromRGB
local V = Vector3.new
local M = Enum.Material
local rng = Random.new()

local folder = Instance.new("Folder")
folder.Name = "BreakFX"
folder.Parent = Workspace

function BreakFX.Init(e)
	env = e
end

local function rand(a, b)
	return rng:NextNumber(a, b)
end
local function sound(name, pos, vol, pitch)
	if env.Sound then
		env.Sound(name, pos, vol, pitch)
	end
end
local function smoke(pos, color, n, size)
	if env.Smoke then
		env.Smoke(pos, color, n, size)
	end
end
local function burst(pos, color, n, speed, size, tex)
	if env.Burst then
		env.Burst(pos, color, n, speed, size, tex)
	end
end
local function flash(pos, color, range, time)
	if env.Flash then
		env.Flash(pos, color, range, time)
	end
end
local function ring(pos, radius, color, time, thick)
	if env.Ring then
		env.Ring(pos, radius, color, time, thick)
	end
end
local function shakeAt(pos, power, time)
	local cam = Workspace.CurrentCamera
	local d = cam and (cam.CFrame.Position - pos).Magnitude or 999
	if d < 90 and env.Shake then
		env.Shake(power * (1 - d / 90), time)
	end
end
local function ease(a, style)
	return TweenService:GetValue(a, style, Enum.EasingDirection.Out)
end
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"

-- เรียก fn(alpha 0..1) ทุกเฟรมจนครบเวลา (yield)
local function play(time, fn)
	local t0 = os.clock()
	while true do
		local a = math.min((os.clock() - t0) / time, 1)
		if not pcall(fn, a) or a >= 1 then
			return
		end
		RunService.RenderStepped:Wait()
	end
end

local function box(g)
	if g:IsA("Model") then
		return g:GetBoundingBox()
	end
	return g.CFrame, g.Size
end
local function getScale(g)
	local ok, s = pcall(function()
		return g:GetScale()
	end)
	return ok and s or 1
end
local function setScale(g, s)
	pcall(function()
		g:ScaleTo(math.max(s, 0.02))
	end)
end
local function pivotAround(g, p0, root, axis, ang)
	g:PivotTo(CFrame.new(root) * CFrame.fromAxisAngle(axis, ang) * CFrame.new(-root) * p0)
end
local function randomFlat()
	local a = rand(0, math.pi * 2)
	return V(math.cos(a), 0, math.sin(a))
end

---------------------------------------------------------------- เศษที่กระเด็น (จำลองตกเอง)
local live, conn = {}, nil
local rayP = RaycastParams.new()
rayP.FilterType = Enum.RaycastFilterType.Include

local function step(dt)
	dt = math.min(dt, 1 / 20)
	for i = #live, 1, -1 do
		local c = live[i]
		if not c.Part.Parent then
			table.remove(live, i)
		elseif not c.Rest then
			c.Vel = (c.Vel + V(0, -c.G * dt, 0)) * (1 - math.min(c.Drag * dt, 0.5))
			local move = c.Vel * dt
			local hit = move.Magnitude > 1e-3 and Workspace:Raycast(c.Pos, move + move.Unit * c.R, rayP)
			if hit then
				local n = hit.Normal
				c.Pos = hit.Position + n * c.R
				c.Vel = (c.Vel - 2 * c.Vel:Dot(n) * n) * c.Bounce
				c.Spin *= 0.5
				if c.Vel.Magnitude < 3 then
					c.Rest = true
				end
			else
				c.Pos += move
			end
			if c.Spin.Magnitude > 0.01 then
				c.Rot = CFrame.fromAxisAngle(c.Spin.Unit, c.Spin.Magnitude * dt) * c.Rot
			end
			c.Part.CFrame = CFrame.new(c.Pos) * c.Rot
		end
	end
	if #live == 0 and conn then
		conn:Disconnect()
		conn = nil
	end
end

local function chunk(o)
	if #live > 180 then
		return
	end
	local p = o.Shape == "Wedge" and Instance.new("WedgePart") or Instance.new("Part")
	if o.Shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = o.Size.Magnitude > 1.5
	p.Size = o.Size
	p.Color = o.Color
	p.Material = o.Material or M.SmoothPlastic
	local rot = CFrame.Angles(rand(0, 6.28), rand(0, 6.28), rand(0, 6.28))
	p.CFrame = CFrame.new(o.Pos) * rot
	p.Parent = folder
	if #live == 0 then
		local list = { Workspace.Terrain }
		for _, n in ipairs({ "World", "Structures", "Lobby" }) do
			local f = Workspace:FindFirstChild(n)
			if f then
				table.insert(list, f)
			end
		end
		rayP.FilterDescendantsInstances = list
	end
	table.insert(live, {
		Part = p, Pos = o.Pos, Vel = o.Vel, Rot = rot, Spin = V(rand(-1, 1), rand(-1, 1), rand(-1, 1)) * rand(4, 12),
		G = o.G or 90, Drag = o.Drag or 0.2, Bounce = o.Bounce or 0.35, R = math.min(o.Size.X, o.Size.Y, o.Size.Z) / 2,
	})
	if not conn then
		conn = RunService.Heartbeat:Connect(step)
	end
	task.delay(o.Life or rand(2.2, 3.4), function()
		if p.Parent then
			TweenService:Create(p, TweenInfo.new(0.6), { Transparency = 1, Size = p.Size * 0.4 }):Play()
			Debris:AddItem(p, 0.65)
		end
	end)
end

-- โปรย n ชิ้นจากในกล่อง (cf,size) ออกด้านข้าง/ขึ้นบน
-- o: Looks={{Color,Material}}, SizeFn, Shape, Speed={a,b}, Up={a,b}, YMin/YMax (สัดส่วนความสูงจากกลางกล่อง), G, Drag, Bounce, Life={a,b}, Material
local function spray(cf, size, n, o)
	for _ = 1, n do
		local off = V(rand(-0.5, 0.5) * size.X, rand(o.YMin or -0.3, o.YMax or 0.5) * size.Y, rand(-0.5, 0.5) * size.Z)
		local pos = cf:PointToWorldSpace(off)
		local out = (pos - cf.Position) * V(1, 0, 1)
		out = out.Magnitude > 0.05 and out.Unit or randomFlat()
		local look = o.Looks[rng:NextInteger(1, #o.Looks)]
		chunk({
			Size = o.SizeFn(), Shape = o.Shape, Color = look[1], Material = o.Material or look[2], Pos = pos,
			Vel = out * rand(o.Speed[1], o.Speed[2]) + V(0, rand(o.Up[1], o.Up[2]), 0),
			G = o.G, Drag = o.Drag, Bounce = o.Bounce, Life = o.Life and rand(o.Life[1], o.Life[2]),
		})
	end
end
local function cube(s)
	return function()
		local k = s * rand(0.6, 1.2)
		return V(k * rand(0.7, 1.3), k * rand(0.6, 1.1), k * rand(0.7, 1.3))
	end
end
local function splinter(len)
	return function()
		local w = rand(0.22, 0.4)
		return V(w, w, len * rand(0.6, 1.3))
	end
end
local function flake(s)
	return function()
		local k = s * rand(0.6, 1.2)
		return V(k, 0.12, k * rand(0.6, 1))
	end
end

---------------------------------------------------------------- สี/วัสดุ
local WOOD = { { C(118, 84, 54), M.Wood }, { C(96, 68, 44), M.Wood }, { C(140, 104, 68), M.WoodPlanks } }
local STONE = { { C(130, 128, 124), M.Slate }, { C(108, 106, 102), M.Slate }, { C(150, 146, 140), M.Rock } }
local LEAF = { { C(82, 140, 62), M.LeafyGrass }, { C(64, 118, 50), M.Grass }, { C(108, 160, 70), M.LeafyGrass } }
local METAL = { { C(70, 66, 64), M.Metal }, { C(96, 92, 88), M.DiamondPlate }, { C(54, 50, 50), M.Metal } }
local FABRIC = { { C(180, 140, 100), M.Fabric }, { C(236, 226, 206), M.Fabric }, { C(160, 60, 50), M.Fabric } }
local SOIL = { { C(92, 66, 44), M.Ground }, { C(70, 52, 36), M.Ground }, { C(110, 80, 52), M.Mud } }
local MARBLE = { { C(214, 196, 150), M.Marble }, { C(190, 176, 140), M.Marble }, { C(120, 116, 110), M.Slate } }

local function isGreen(c)
	return c.G > c.R * 1.08 and c.G > c.B * 1.08
end
local function isBrown(c)
	return c.R > c.B * 1.2 and c.R >= c.G and c.R < 0.8
end
-- สีจริงของชิ้นใหญ่ๆ ในโมเดล (ข้ามชิ้นที่ใช้เท็กซ์เจอร์ เพราะสี Part ไม่ตรงกับที่เห็น)
local function sample(g, filter)
	local out, list = {}, {}
	if not g then
		return out
	end
	for _, p in ipairs(g:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.9 then
			local textured = (p:IsA("MeshPart") and p.TextureID ~= "") or p:FindFirstChildOfClass("SurfaceAppearance")
			if not textured and (not filter or filter(p.Color)) then
				table.insert(list, { p.Size.X * p.Size.Y * p.Size.Z, p.Color })
			end
		end
	end
	table.sort(list, function(a, b)
		return a[1] > b[1]
	end)
	for i = 1, math.min(4, #list) do
		table.insert(out, list[i][2])
	end
	return out
end
local function mix(colors, defaults)
	local out = table.clone(defaults)
	for _, c in ipairs(colors) do
		table.insert(out, { c, defaults[1][2] })
	end
	return out
end

---------------------------------------------------------------- โคลนของจริงมาเล่นท่า
local STRIP = { ProximityPrompt = true, BillboardGui = true, SurfaceGui = true, Script = true, LocalScript = true, ModuleScript = true, Sound = true, ClickDetector = true }

local function ghost(model)
	if not (model and model.Parent) then
		return nil
	end
	local ok, g = pcall(function()
		local was = model.Archivable
		model.Archivable = true
		local c = model:Clone()
		model.Archivable = was
		return c
	end)
	if not (ok and g) then
		return nil
	end
	for _, d in ipairs(g:GetDescendants()) do
		if STRIP[d.ClassName] then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			-- เซิร์ฟเวอร์ซ่อนไปก่อนแล้ว -> ใช้ค่าความโปร่งเดิมที่จำไว้
			local o = d:GetAttribute("OrigT")
			if d.Transparency >= 0.999 and o and o < 0.999 then
				d.Transparency = o
			end
		end
	end
	if g:IsA("BasePart") then
		g.Anchored, g.CanCollide, g.CanQuery = true, false, false
	end
	g.Parent = folder
	-- ซ่อนของจริงทันทีฝั่งเรา (เซิร์ฟเวอร์จะซ่อนตามมาเอง)
	local list = model:GetDescendants()
	table.insert(list, model)
	for _, d in ipairs(list) do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("Light") or d:IsA("Fire") or d:IsA("ParticleEmitter") or d:IsA("Smoke") then
			d.Enabled = false
		end
	end
	return g
end

local function fadeOut(g, time, sink)
	if not (g and g.Parent) then
		return
	end
	local info = TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, d in ipairs(g:GetDescendants()) do
		if d:IsA("BasePart") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		elseif d:IsA("Light") then
			TweenService:Create(d, info, { Brightness = 0 }):Play()
		end
	end
	if sink then
		local p0 = g:GetPivot()
		task.spawn(play, time, function(a)
			g:PivotTo(p0 - V(0, sink * a * a, 0))
		end)
	end
	Debris:AddItem(g, time + 0.1)
end

local function squash(g, k, sink, time)
	if not g then
		return
	end
	local s0, p0 = getScale(g), g:GetPivot()
	play(time, function(a)
		local e = a * a
		setScale(g, s0 * (1 - k * e))
		g:PivotTo(p0 - V(0, sink * e, 0))
	end)
	fadeOut(g, 0.5, 0.6)
end

local function jitter(g, time, amt)
	if not g then
		return
	end
	local p0 = g:GetPivot()
	play(time, function(a)
		local k = amt * (1 - a)
		g:PivotTo(p0 * CFrame.new(rand(-k, k), 0, rand(-k, k)))
	end)
	g:PivotTo(p0)
end

-- ล้มจากขอบล่างไปทาง dir (บานพับที่โคน) · ตกเร่งขึ้นเหมือนแรงโน้มถ่วง แล้วเด้งนิดนึง
local function topple(g, root, dir, angle, time)
	local axis = V(0, 1, 0):Cross(dir)
	local p0 = g:GetPivot()
	play(time, function(a)
		pivotAround(g, p0, root, axis, angle * a * a)
	end)
	return function(bounceDeg)
		play(0.28, function(a)
			pivotAround(g, p0, root, axis, angle - math.rad(bounceDeg or 5) * math.sin(a * math.pi))
		end)
	end
end

---------------------------------------------------------------- ของในแมพ (ResourceService)
function BreakFX.Tree(d)
	local g = ghost(d.Node)
	local pos = d.Position
	if not g then
		task.delay(1.2, function()
			smoke(pos, C(160, 140, 110), 16, 10)
			sound("TreeFall", pos, 0.8, 0.7)
		end)
		return
	end
	local cf, size = box(g)
	local h = math.max(size.Y, 4)
	local p0 = g:GetPivot()
	local root = V(p0.X, cf.Y - size.Y / 2, p0.Z)
	local dir = (root - (d.From or root - V(1, 0, 0))) * V(1, 0, 1)
	dir = dir.Magnitude > 0.1 and dir.Unit or V(1, 0, 0)
	local axis = V(0, 1, 0):Cross(dir)
	local leaves = mix(sample(g, isGreen), LEAF)
	local bark = mix(sample(g, isBrown), WOOD)
	-- เอนนิดนึงก่อน (เสียงไม้เอี๊ยด) -> ล้มเร่งขึ้นเรื่อยๆ
	sound("WoodHit", root, 0.8, 0.55)
	spray(CFrame.new(root + V(0, 1.5, 0)), V(2, 1, 2), 5, { Looks = bark, SizeFn = splinter(1.2), Speed = { 4, 10 }, Up = { 8, 14 } })
	local lean = math.rad(5)
	play(0.4, function(a)
		pivotAround(g, p0, root, axis, lean * ease(a, Enum.EasingStyle.Sine))
	end)
	local A = math.rad(84)
	play(1.05, function(a)
		pivotAround(g, p0, root, axis, lean + (A - lean) * a * a)
	end)
	-- กระแทกพื้น: ใบไม้ร่วงตรงยอด + ฝุ่นตามแนวลำต้น
	local crown = root + dir * h * 0.72 + V(0, 1.5, 0)
	sound("TreeFall", crown, 0.9, rand(0.65, 0.8))
	sound("Land", crown, 0.7, 0.6)
	shakeAt(crown, 0.5, 0.3)
	for i = 1, 4 do
		smoke(root + dir * h * (i / 4.5) + V(0, 0.5, 0), C(150, 132, 104), 6, 5 + i)
	end
	spray(CFrame.new(crown), V(h * 0.45, 2, h * 0.45), 22, { Looks = leaves, SizeFn = flake(0.9), Speed = { 5, 15 }, Up = { 10, 22 }, G = 20, Drag = 1.6, Bounce = 0.1, YMin = 0, YMax = 1, Life = { 2.5, 4 } })
	play(0.32, function(a)
		pivotAround(g, p0, root, axis, A - math.rad(5) * math.sin(a * math.pi))
	end)
	task.wait(1.3)
	-- นอนนิ่งแล้วจมดินหายไป ทิ้งเศษไม้
	spray(CFrame.new(root + dir * h * 0.35 + V(0, 1, 0)), V(h * 0.5, 1, 2), 6, { Looks = bark, SizeFn = cube(0.9), Speed = { 2, 6 }, Up = { 6, 12 } })
	smoke(root + dir * h * 0.4, C(150, 132, 104), 8, 6)
	fadeOut(g, 1.1, 2.5)
end

function BreakFX.Rock(d)
	local g = ghost(d.Node)
	local cf, size
	if g then
		cf, size = box(g)
	else
		cf, size = CFrame.new(d.Position + V(0, 2, 0)), V(6, 4, 6)
	end
	local stone = mix(sample(g), STONE)
	local ore = (d.Yield == "Iron" and { C(196, 124, 84), M.Metal }) or (d.Yield == "Coal" and { C(34, 32, 34), M.Slate }) or nil
	local s = math.clamp(math.max(size.X, size.Z) * 0.2, 0.7, 2.6)
	-- ร้าวก่อน (สั่น) แล้วแตกเป็นก้อน
	sound("Mine", cf.Position, 0.9, 0.75)
	jitter(g, 0.16, 0.3)
	sound("Break", cf.Position, 0.8, 0.8)
	shakeAt(cf.Position, 0.3, 0.2)
	local n = math.clamp(math.floor(size.Magnitude * 1.3), 8, 22)
	spray(cf, size * 0.8, n, { Looks = stone, SizeFn = cube(s), Speed = { 8, 22 }, Up = { 14, 30 }, YMin = -0.3, YMax = 0.4 })
	if ore then
		spray(cf, size * 0.6, math.ceil(n / 3), { Looks = { ore }, SizeFn = cube(s * 0.7), Speed = { 8, 20 }, Up = { 16, 30 } })
		if d.Yield == "Iron" then
			burst(cf.Position, C(255, 200, 120), 14, 22, 0.3)
		end
	end
	smoke(cf.Position - V(0, size.Y * 0.3, 0), C(150, 144, 136), 16, math.max(size.X, size.Z) * 0.9)
	if g then
		local s0, p1 = getScale(g), g:GetPivot()
		play(0.3, function(a)
			setScale(g, s0 * (1 - 0.75 * a))
			g:PivotTo(p1 - V(0, size.Y * 0.4 * a, 0))
		end)
		g:Destroy()
	end
end

function BreakFX.Crystal(d)
	local g = ghost(d.Node)
	local cf, size
	if g then
		cf, size = box(g)
	else
		cf, size = CFrame.new(d.Position + V(0, 3, 0)), V(4, 6, 4)
	end
	local col = (env.ElementColors or {})[d.Yield] or sample(g)[1] or C(200, 240, 255)
	local looks = { { col, M.Neon }, { col:Lerp(Color3.new(1, 1, 1), 0.45), M.Glass }, { col:Lerp(Color3.new(1, 1, 1), 0.2), M.Glass } }
	sound("Crystal", cf.Position, 0.9, 1.25)
	flash(cf.Position, col, 40, 0.5)
	-- พองเรืองแสงแล้วแตกเป็นเศษ
	if g then
		local s0 = getScale(g)
		play(0.14, function(a)
			setScale(g, s0 * (1 + 0.15 * a))
		end)
	end
	sound("Break", cf.Position, 0.7, 1.5)
	burst(cf.Position, col, 40, 30, 0.5)
	ring(cf.Position - V(0, size.Y * 0.45, 0), math.max(size.X, size.Z) * 1.6, col, 0.5, 0.4)
	spray(cf, size * 0.7, 14, { Looks = looks, Shape = "Wedge", SizeFn = cube(math.clamp(size.Y * 0.12, 0.4, 1.2)), Speed = { 12, 26 }, Up = { 12, 28 }, Bounce = 0.45 })
	if g then
		local s1 = getScale(g)
		play(0.16, function(a)
			setScale(g, s1 * (1 - 0.95 * a))
		end)
		g:Destroy()
	end
end

function BreakFX.Bush(d)
	local g = ghost(d.Node)
	local cf, size
	if g then
		cf, size = box(g)
	else
		cf, size = CFrame.new(d.Position + V(0, 1.5, 0)), V(4, 3, 4)
	end
	sound("Bush", cf.Position, 0.8, 0.9)
	spray(cf, size, 16, { Looks = mix(sample(g, isGreen), LEAF), SizeFn = flake(0.6), Speed = { 4, 10 }, Up = { 8, 16 }, G = 20, Drag = 1.6, Bounce = 0.1 })
	squash(g, 0.8, size.Y * 0.4, 0.3)
end

function BreakFX.NodeBreak(d)
	if d.Kind == "Tree" then
		BreakFX.Tree(d)
	elseif d.Kind == "Crystal" then
		BreakFX.Crystal(d)
	elseif d.Kind == "Bush" then
		BreakFX.Bush(d)
	else
		BreakFX.Rock(d)
	end
end

---------------------------------------------------------------- สิ่งก่อสร้าง
local PROFILE = {
	LogWall = "Wood", Ballista = "Wood", SpikeTrap = "Spikes", Bed = "Bed", FarmPlot = "Soil",
	StoneWall = "Stone", CookPot = "Metal", Lantern = "Lamp", SunBeacon = "Beacon",
	TerraTotem = "Totem", TideTotem = "Totem", GaleTotem = "Totem", EmberTotem = "Totem",
}

local function elementColor(kind)
	local spec = Items.Structures[kind]
	return (env.ElementColors or {})[spec and spec.Element] or C(255, 230, 160)
end
local function lightsOf(m)
	local out = {}
	for _, l in ipairs(m and m:GetDescendants() or {}) do
		if l:IsA("Light") then
			table.insert(out, { l, l.Brightness })
		end
	end
	return out
end

local BREAK = {}

BREAK.Wood = function(g, cf, size, floor)
	local wood = mix(sample(g, isBrown), WOOD)
	sound("WoodHit", floor, 0.9, 0.7)
	sound("Break", floor, 0.8, 0.75)
	shakeAt(floor, 0.25, 0.2)
	-- ไม้หัก: เสี้ยนไม้กระเด็น + ท่อนไม้
	spray(cf, size, math.clamp(math.floor(size.Magnitude), 8, 18), { Looks = wood, SizeFn = splinter(math.clamp(size.Y * 0.25, 1.2, 3)), Speed = { 8, 20 }, Up = { 12, 26 } })
	spray(cf, size, 5, { Looks = wood, SizeFn = cube(0.8), Speed = { 4, 12 }, Up = { 8, 16 } })
	smoke(floor + V(0, 1, 0), C(160, 136, 104), 12, math.max(size.X, size.Z) * 0.6)
	if not g then
		return
	end
	jitter(g, 0.15, 0.25)
	-- ล้มคว่ำไปด้านหน้า/หลัง (ด้านบางของกำแพง)
	local dir = (size.X < size.Z and cf.RightVector or cf.LookVector) * (rng:NextNumber() < 0.5 and -1 or 1) * V(1, 0, 1)
	dir = dir.Magnitude > 0.1 and dir.Unit or randomFlat()
	local root = floor + dir * math.min(size.X, size.Z) / 2
	local tall = size.Y > math.max(size.X, size.Z) * 0.5
	local bounce = topple(g, root, dir, math.rad(tall and 86 or 30), tall and 0.75 or 0.4)
	local land = root + dir * size.Y * 0.55
	sound("WoodHit", land, 0.8, 0.55)
	smoke(land, C(150, 130, 100), 10, math.max(size.Y * 0.5, 4))
	spray(CFrame.new(land + V(0, 1, 0)), V(size.Y * 0.6, 1, math.max(size.X, size.Z)), 8, { Looks = wood, SizeFn = splinter(1.5), Speed = { 4, 10 }, Up = { 8, 14 } })
	shakeAt(root, 0.25, 0.2)
	bounce(4)
	task.wait(0.5)
	fadeOut(g, 0.8, 1.5)
end

BREAK.Spikes = function(g, cf, size, floor)
	local wood = mix(sample(g, isBrown), WOOD)
	sound("WoodHit", floor, 0.8, 1.1)
	sound("Break", floor, 0.7, 1)
	-- หนามหักกระเด็นขึ้นฟ้า
	spray(cf, size, 14, { Looks = wood, SizeFn = splinter(1.8), Speed = { 4, 12 }, Up = { 18, 32 }, YMin = 0, YMax = 0.5 })
	smoke(floor + V(0, 0.8, 0), C(160, 136, 104), 10, size.X * 0.6)
	squash(g, 0.55, size.Y * 0.8, 0.35)
end

BREAK.Bed = function(g, cf, size, floor)
	sound("Bush", floor, 0.8, 0.7)
	sound("WoodHit", floor, 0.7, 1.2)
	-- ผ้าปลิว + โครงไม้หัก
	spray(cf, size, 10, { Looks = mix(sample(g), FABRIC), SizeFn = flake(1.1), Speed = { 4, 10 }, Up = { 10, 18 }, G = 26, Drag = 1.4, Bounce = 0.1 })
	spray(cf, size, 6, { Looks = WOOD, SizeFn = splinter(1.6), Speed = { 6, 14 }, Up = { 10, 18 } })
	smoke(floor + V(0, 1, 0), C(200, 190, 170), 8, size.Z * 0.5)
	squash(g, 0.5, size.Y * 0.6, 0.35)
end

BREAK.Soil = function(g, cf, size, floor)
	sound("Bush", floor, 0.9, 0.8)
	sound("Mine", floor, 0.5, 0.6)
	-- ดินกระจุย + ต้นผักปลิว + ขอบไม้หัก
	spray(cf, size, 12, { Looks = SOIL, SizeFn = cube(0.7), Speed = { 6, 14 }, Up = { 10, 20 } })
	spray(cf, size, 10, { Looks = mix(sample(g, isGreen), LEAF), SizeFn = flake(0.7), Speed = { 4, 10 }, Up = { 10, 18 }, G = 20, Drag = 1.6, Bounce = 0.1 })
	spray(cf, size, 6, { Looks = WOOD, SizeFn = splinter(2), Speed = { 6, 12 }, Up = { 8, 14 } })
	smoke(floor + V(0, 0.8, 0), C(120, 96, 70), 14, size.X * 0.6)
	squash(g, 0.3, size.Y, 0.35)
end

BREAK.Stone = function(g, cf, size, floor, _, palette)
	local stone = mix(sample(g), palette or STONE)
	sound("Mine", floor, 0.9, 0.6)
	sound("Break", floor, 0.9, 0.55)
	sound("Land", floor, 0.8, 0.6)
	shakeAt(floor, 0.45, 0.6)
	local s = math.clamp(size.Y * 0.14, 0.8, 2.2)
	-- ทรุดจากบนลงล่าง: ก้อนหินร่วงเป็นระลอก + ฝุ่นตลบ
	for wave = 0, 2 do
		task.delay(wave * 0.2, function()
			spray(cf, size, 7, { Looks = stone, SizeFn = cube(s), Speed = { 3, 10 }, Up = { 2, 10 }, YMin = 0.2 - wave * 0.3, YMax = 0.5 - wave * 0.3 })
		end)
	end
	smoke(floor + V(0, 1, 0), C(140, 134, 126), 20, math.max(size.X, size.Z) * 0.8)
	task.delay(0.35, function()
		smoke(floor + V(0, size.Y * 0.3, 0), C(150, 144, 136), 14, size.Y * 0.7)
	end)
	if g then
		local p0 = g:GetPivot()
		play(0.9, function(a)
			local k = 0.2 * (1 - a)
			g:PivotTo(p0 * CFrame.new(rand(-k, k), 0, rand(-k, k)) - V(0, size.Y * 0.95 * a * a, 0))
		end)
		g:Destroy()
	end
	-- กองหินที่เหลือ ค่อยๆ จางหาย
	spray(CFrame.new(floor + V(0, 0.6, 0)), V(size.X, 0.4, size.Z), 8, { Looks = stone, SizeFn = cube(s * 1.2), Speed = { 0, 3 }, Up = { 0, 4 }, Life = { 3, 4.5 } })
end

BREAK.Metal = function(g, cf, size, floor)
	sound("Mine", floor, 0.9, 1.35)
	sound("Break", floor, 0.6, 1.1)
	-- เสียงโลหะ + ประกายไฟ + สตูว์หก
	burst(cf.Position, C(255, 190, 90), 26, 26, 0.35)
	burst(cf.Position + V(0, size.Y * 0.3, 0), C(230, 140, 60), 14, 14, 0.8, SMOKE_TEX)
	smoke(floor + V(0, 1, 0), C(90, 86, 84), 10, size.X * 0.7)
	spray(cf, size, 8, { Looks = METAL, SizeFn = cube(0.7), Speed = { 8, 18 }, Up = { 14, 24 }, Bounce = 0.5 })
	if not g then
		return
	end
	-- หม้อคว่ำกลิ้ง
	local dir = randomFlat()
	topple(g, floor + dir * size.X * 0.45, dir, math.rad(95), 0.45)(10)
	sound("Mine", floor + dir * size.X, 0.6, 1.6)
	task.wait(0.4)
	fadeOut(g, 0.7, 1)
end

BREAK.Lamp = function(g, cf, size, floor)
	local glowPos = cf.Position + V(0, size.Y * 0.15, 0)
	local gl = g and g:FindFirstChild("Glow", true)
	if gl and gl:IsA("BasePart") then
		glowPos = gl.Position
	end
	-- ไฟกะพริบก่อนดับ
	local lights = lightsOf(g)
	for _, e in ipairs(lights) do
		e[1].Enabled = true
	end
	for i = 1, 6 do
		for _, e in ipairs(lights) do
			e[1].Brightness = i % 2 == 0 and e[2] or e[2] * 0.12
		end
		task.wait(0.07)
	end
	for _, e in ipairs(lights) do
		e[1].Enabled = false
	end
	-- แก้วแตก
	sound("Crystal", glowPos, 0.8, 1.6)
	sound("Break", glowPos, 0.6, 1.4)
	flash(glowPos, C(255, 200, 120), 26, 0.35)
	burst(glowPos, C(255, 210, 140), 30, 22, 0.3)
	spray(CFrame.new(glowPos), V(1.5, 1.5, 1.5), 10, { Looks = { { C(255, 226, 170), M.Glass }, { C(255, 200, 120), M.Neon } }, Shape = "Wedge", SizeFn = flake(0.45), Speed = { 8, 18 }, Up = { 8, 18 }, Bounce = 0.3 })
	smoke(glowPos, C(70, 66, 64), 6, 3)
	if not g then
		return
	end
	-- เสาล้ม
	local dir = randomFlat()
	topple(g, floor, dir, math.rad(85), 0.7)(4)
	sound("Mine", floor + dir * size.Y * 0.8, 0.6, 1.4)
	smoke(floor + dir * size.Y * 0.6, C(150, 130, 100), 6, 4)
	task.wait(0.4)
	fadeOut(g, 0.7, 1)
end

BREAK.Beacon = function(g, cf, size, floor, d)
	local top = cf.Position + V(0, size.Y * 0.38, 0)
	-- แสงสุริยะวาบแรงแล้วดับ -> หอถล่ม
	flash(top, C(255, 236, 160), 120, 1)
	burst(top, C(255, 236, 160), 60, 40, 1.2)
	ring(top, 30, C(255, 230, 150), 0.8, 1)
	sound("Boom", top, 0.8, 0.8)
	for _, e in ipairs(lightsOf(g)) do
		e[1].Enabled = false
	end
	task.wait(0.3)
	BREAK.Stone(g, cf, size, floor, d, MARBLE)
end

BREAK.Totem = function(g, cf, size, floor, d)
	local col = elementColor(d.Kind)
	local top = cf.Position + V(0, size.Y * 0.4, 0)
	-- พลังธาตุพลุ่ง (เต้นตุบๆ) แล้วระเบิดเป็นสีธาตุ
	flash(top, col, 40, 0.6)
	sound("Crystal", top, 0.9, 0.7)
	if g then
		local s0 = getScale(g)
		play(0.3, function(a)
			setScale(g, s0 * (1 + 0.08 * math.abs(math.sin(a * math.pi * 3))))
		end)
	end
	ring(floor, 16, col, 0.6, 0.8)
	burst(top, col, 40, 30, 0.8)
	spray(CFrame.new(top), V(2, 3, 2), 10, { Looks = { { col, M.Neon }, { col:Lerp(Color3.new(1, 1, 1), 0.4), M.Glass } }, Shape = "Wedge", SizeFn = cube(0.7), Speed = { 10, 24 }, Up = { 10, 26 } })
	spray(cf, size, 10, { Looks = mix(sample(g), { { C(110, 90, 70), M.Wood }, { C(80, 76, 72), M.Slate } }), SizeFn = cube(0.9), Speed = { 6, 14 }, Up = { 8, 18 } })
	sound("Break", top, 0.8, 0.9)
	sound("Boom", top, 0.4, 1.4)
	shakeAt(floor, 0.35, 0.3)
	if g then
		local s1, p0 = getScale(g), g:GetPivot()
		play(0.4, function(a)
			setScale(g, s1 * (1 - 0.8 * a * a))
			g:PivotTo(p0 - V(0, size.Y * 0.3 * a, 0))
		end)
		g:Destroy()
	end
end

function BreakFX.StructureBreak(d)
	local g = ghost(d.Structure)
	local cf, size
	if g then
		cf, size = box(g)
	else
		cf, size = CFrame.new((d.Position or Vector3.zero) + V(0, 3, 0)), V(6, 6, 6)
	end
	local floor = cf.Position - V(0, size.Y / 2, 0)
	local fn = BREAK[PROFILE[d.Kind] or "Wood"] or BREAK.Wood
	local ok, err = pcall(fn, g, cf, size, floor, d)
	if not ok then
		warn("[AS] BreakFX", d.Kind, err)
	end
	if g and g.Parent and not ok then
		g:Destroy()
	end
end

---------------------------------------------------------------- วางสิ่งก่อสร้าง
local BUILD = {}

-- ชิ้นส่วนหล่นลงมาประกอบกันจากล่างขึ้นบน (โมเดลชิ้นเดียว = หล่นทั้งก้อนแล้วเด้ง)
local function assemble(parts, size, snd, pitch, dust)
	table.sort(parts, function(a, b)
		return a.CF.Y < b.CF.Y
	end)
	local n = #parts
	local single = n < 4
	local H = math.clamp(size.Y * 0.8, 4, 10)
	local spread = single and 0 or 0.5
	for i, e in ipairs(parts) do
		e.Delay = single and 0 or (i - 1) / n * spread
		e.Off = single and V(0, H, 0) or V(rand(-1.5, 1.5), H + rand(0, 2), rand(-1.5, 1.5))
		e.Tilt = single and CFrame.identity or CFrame.Angles(rand(-0.5, 0.5), rand(-0.8, 0.8), rand(-0.5, 0.5))
		e.P.CFrame = (e.CF + e.Off) * e.Tilt
		e.P.Transparency = 1
	end
	local T = 0.45
	local every = math.max(1, math.ceil(n / 4))
	local landed = 0
	play(spread + T, function(a)
		local t = a * (spread + T)
		for _, e in ipairs(parts) do
			local k = math.clamp((t - e.Delay) / T, 0, 1)
			if k > 0 and e.P.Parent then
				local y = ease(k, Enum.EasingStyle.Bounce)
				e.P.CFrame = (e.CF + e.Off * (1 - y)) * e.Tilt:Lerp(CFrame.identity, ease(k, Enum.EasingStyle.Quad))
				e.P.Transparency = e.T + (1 - e.T) * math.max(0, 1 - k * 3)
				if k >= 0.36 and not e.Landed then -- Bounce Out แตะพื้นครั้งแรกที่ ~0.36
					e.Landed = true
					landed += 1
					if e.T < 0.9 and (landed % every == 0 or single) then
						sound(snd, e.CF.Position, 0.45, (pitch or 1) * rand(0.9, 1.15))
						smoke(e.CF.Position - V(0, e.P.Size.Y * 0.4, 0), dust, 3, 3)
					end
				end
			end
		end
	end)
end

-- ผุดขึ้นจากดิน (เลยขึ้นมานิดแล้วยุบลงที่)
local function rise(parts, size, time)
	local depth = size.Y + 0.5
	play(time, function(a)
		local y = ease(a, Enum.EasingStyle.Back)
		local k = (1 - a) * 0.15
		local j = V(rand(-k, k), 0, rand(-k, k))
		for _, e in ipairs(parts) do
			if e.P.Parent then
				e.P.CFrame = e.CF - V(0, depth * (1 - y), 0) + j
			end
		end
	end)
end

BUILD.Wood = function(m, parts, cf, size, floor)
	assemble(parts, size, "WoodHit", 1, C(170, 150, 120))
	smoke(floor + V(0, 0.8, 0), C(170, 150, 120), 10, math.max(size.X, size.Z) * 0.5)
	ring(floor, math.max(size.X, size.Z) * 0.7, C(255, 220, 140), 0.4, 0.3)
end
BUILD.Spikes = BUILD.Wood
BUILD.Bed = function(m, parts, cf, size, floor)
	assemble(parts, size, "Bush", 0.8, C(210, 200, 180))
	smoke(floor + V(0, 0.8, 0), C(210, 200, 180), 8, size.Z * 0.5)
end
BUILD.Soil = function(m, parts, cf, size, floor)
	assemble(parts, size, "Bush", 1, C(120, 96, 70))
	spray(CFrame.new(floor + V(0, 0.6, 0)), V(size.X, 0.3, size.Z), 10, { Looks = SOIL, SizeFn = cube(0.5), Speed = { 3, 8 }, Up = { 6, 12 } })
	smoke(floor + V(0, 0.8, 0), C(120, 96, 70), 12, size.X * 0.6)
end
BUILD.Metal = function(m, parts, cf, size, floor)
	assemble(parts, size, "Mine", 1.4, C(110, 104, 98))
	burst(floor + V(0, 1, 0), C(255, 190, 90), 14, 16, 0.3)
	smoke(floor + V(0, 0.8, 0), C(150, 140, 126), 8, size.X * 0.6)
end
BUILD.Lamp = function(m, parts, cf, size, floor)
	local lights = lightsOf(m)
	for _, e in ipairs(lights) do
		e[1].Brightness = 0
	end
	assemble(parts, size, "Mine", 1.5, C(150, 140, 126))
	-- ไฟติดแบบกะพริบแล้วค่อยๆ สว่าง
	local glow = m:FindFirstChild("Glow", true)
	local at = glow and glow:IsA("BasePart") and glow.Position or (floor + V(0, size.Y * 0.65, 0))
	sound("Refuel", at, 0.4, 1.4)
	for i = 1, 5 do
		for _, e in ipairs(lights) do
			e[1].Brightness = e[2] * (i % 2 == 1 and 0.6 or 0.1)
		end
		task.wait(0.08)
	end
	for _, e in ipairs(lights) do
		e[1].Brightness = e[2]
	end
	flash(at, C(255, 200, 120), 24, 0.5)
	burst(at, C(255, 210, 140), 14, 8, 0.3)
end
BUILD.Stone = function(m, parts, cf, size, floor)
	local stone = mix(sample(m), STONE)
	sound("Mine", floor, 0.7, 0.6)
	sound("Land", floor, 0.6, 0.7)
	shakeAt(floor, 0.25, 0.7)
	spray(CFrame.new(floor + V(0, 0.5, 0)), V(size.X, 0.5, size.Z), 10, { Looks = stone, SizeFn = cube(0.7), Speed = { 4, 10 }, Up = { 10, 18 } })
	smoke(floor + V(0, 1, 0), C(150, 140, 126), 14, math.max(size.X, size.Z) * 0.7)
	rise(parts, size, 0.8)
	smoke(floor + V(0, 0.8, 0), C(150, 140, 126), 8, math.max(size.X, size.Z) * 0.5)
	sound("Mine", floor, 0.6, 0.8)
end
BUILD.Totem = function(m, parts, cf, size, floor, d)
	local col = elementColor(d.Kind)
	sound("Crystal", floor, 0.7, 0.8)
	shakeAt(floor, 0.2, 0.8)
	smoke(floor + V(0, 1, 0), C(150, 140, 126), 10, 6)
	-- ประกายสีธาตุหมุนวนขึ้นตอนเสาผุด
	task.spawn(function()
		for i = 0, 7 do
			local a = i * 0.9
			burst(floor + V(math.cos(a) * 3, i * size.Y / 8, math.sin(a) * 3), col, 6, 6, 0.4)
			task.wait(0.12)
		end
	end)
	rise(parts, size, 1)
	flash(cf.Position + V(0, size.Y * 0.4, 0), col, 36, 0.6)
	ring(floor, 14, col, 0.6, 0.6)
	burst(cf.Position + V(0, size.Y * 0.4, 0), col, 30, 18, 0.6)
	sound("Crystal", floor, 0.8, 1.2)
end
BUILD.Beacon = function(m, parts, cf, size, floor)
	sound("Land", floor, 0.8, 0.5)
	shakeAt(floor, 0.35, 1.8)
	for i = 0, 3 do
		task.delay(i * 0.4, function()
			smoke(floor + V(0, 1, 0), C(160, 150, 130), 12, 10)
		end)
	end
	rise(parts, size, 1.8)
	local top = cf.Position + V(0, size.Y * 0.38, 0)
	flash(top, C(255, 236, 160), 120, 1.2)
	burst(top, C(255, 236, 160), 50, 30, 1)
	ring(floor, 30, C(255, 230, 150), 0.8, 0.8)
	sound("Refuel", top, 0.7, 0.8)
end

local function findPlaced(d)
	local f = Workspace:FindFirstChild("Structures")
	if not (f and d.Position) then
		return nil
	end
	local best, bestD
	for _, s in ipairs(f:GetChildren()) do
		if s:GetAttribute("Kind") == d.Kind then
			local dist = (s:GetPivot().Position - d.Position).Magnitude
			if dist < 4 and (not bestD or dist < bestD) then
				best, bestD = s, dist
			end
		end
	end
	return best
end

function BreakFX.Build(d)
	local m = d.Structure
	if not (m and m.Parent) then
		-- ยังสตรีมมาไม่ถึง: รอแป๊บแล้วหาเองแถวจุดที่วาง
		for _ = 1, 8 do
			m = findPlaced(d)
			if m then
				break
			end
			task.wait(0.1)
		end
	end
	sound("Build", d.Position, 0.55)
	if not (m and m:IsA("Model")) then
		smoke(d.Position, C(180, 160, 130), 10, 5)
		return
	end
	local cf, size = m:GetBoundingBox()
	local floor = cf.Position - V(0, size.Y / 2, 0)
	local parts = {}
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			table.insert(parts, { P = p, CF = p.CFrame, T = p.Transparency })
		end
	end
	if #parts == 0 then
		return
	end
	local fn = BUILD[PROFILE[d.Kind] or "Wood"] or BUILD.Wood
	local ok, err = pcall(fn, m, parts, cf, size, floor, d)
	if not ok then
		warn("[AS] BuildFX", d.Kind, err)
	end
	-- คืนตำแหน่ง/ความโปร่งจริงทุกชิ้น (กันค้างครึ่งทาง)
	for _, e in ipairs(parts) do
		if e.P.Parent then
			e.P.CFrame = e.CF
			e.P.Transparency = e.T
		end
	end
end

return BreakFX
