--[[
	FogWall — กำแพงหมอกรอบแคมป์ตามเลเวลกองไฟ (State.CampReveal = รัศมีจากกลางแมพ)
	  · เดินเลยหมอกไม่ได้ (ดันตัวกลับนุ่มๆ ฝั่งเครื่องผู้เล่น · เซิร์ฟเวอร์กันซ้ำใน CampService)
	  · หมอกเป็นผนังไล่สีสูงลิบ 2 ชั้น + ควันลอยต่ำ วางเฉพาะช่วงโค้งใกล้ผู้เล่น (ประหยัด)
	  · อัปเกรดกองไฟ -> หมอกค่อยๆ ถอยออกไป
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FogWall = {}

local player = Players.LocalPlayer
local N = 44 -- แผ่นต่อชั้น
local SEG = 48 -- ความกว้างแผ่น (สตัด)
local HEIGHT = 1000
local SHOW = 700 -- เห็นกำแพงเมื่ออยู่ใกล้กว่านี้
local DAY = Color3.fromRGB(206, 210, 220)
local NIGHT = Color3.fromRGB(38, 42, 56)

local function panel(parent, transparency)
	local p = Instance.new("Part")
	p.Name = "Fog"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(SEG, HEIGHT, 0.5)
	local frames = {}
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 1
		sg.LightInfluence = 0
		sg.MaxDistance = 3000
		sg.Parent = p
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = DAY
		f.Parent = sg
		local g = Instance.new("UIGradient")
		g.Rotation = 90 -- บน -> ล่าง
		g.Transparency = transparency
		g.Parent = f
		table.insert(frames, f)
	end
	p.Parent = parent
	return p, frames
end

function FogWall.Init(state)
	if ReplicatedStorage:FindFirstChild("ASAutoTest") and not ReplicatedStorage:FindFirstChild("ASFogProbe") then
		return -- เทสต์อัตโนมัติวาร์ปไปทั่วแมพ
	end
	local folder = Instance.new("Folder")
	folder.Name = "ASFogWall"
	folder.Parent = nil
	-- ชั้นใน: ฐานทึบ ปลายบนจางหาย · ชั้นนอก (ลึกเข้าไป 70): ทึบกว่า = ดูหนาเป็นกำแพง
	local inner = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 0.62),
		NumberSequenceKeypoint.new(0.64, 0.22),
		NumberSequenceKeypoint.new(1, 0.08),
	})
	local outer = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.45, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	local layers = {}
	local allFrames = {}
	local mists = {}
	for li, spec in ipairs({ { 0, inner }, { 70, outer } }) do
		local parts = {}
		for i = 1, N do
			local p, frames = panel(folder, spec[2])
			parts[i] = p
			for _, f in ipairs(frames) do
				table.insert(allFrames, f)
			end
			if li == 1 and i % 2 == 0 then
				-- ควันลอยเรี่ยพื้นหน้ากำแพง
				local a = Instance.new("Attachment")
				a.Position = Vector3.new(0, -HEIGHT / 2 + 205, 6)
				a.Parent = p
				local e = Instance.new("ParticleEmitter")
				e.Texture = "rbxasset://textures/particles/smoke_main.dds"
				e.Rate = 3
				e.Lifetime = NumberRange.new(8, 12)
				e.Speed = NumberRange.new(1, 3)
				e.SpreadAngle = Vector2.new(180, 30)
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 40), NumberSequenceKeypoint.new(1, 80) })
				e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1) })
				e.RotSpeed = NumberRange.new(-10, 10)
				e.Rotation = NumberRange.new(0, 360)
				e.LightInfluence = 0.6
				e.Parent = a
				table.insert(mists, e)
			end
		end
		layers[li] = { Off = spec[1], Parts = parts }
	end

	-- ป้ายเตือนเมื่อเข้าใกล้กำแพง
	local gui = Instance.new("ScreenGui")
	gui.Name = "ASFogHint"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 0.5)
	hint.Position = UDim2.fromScale(0.5, 0.7)
	hint.Size = UDim2.new(0.9, 0, 0, 34)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamBold
	hint.TextScaled = true
	hint.TextColor3 = Color3.fromRGB(235, 238, 245)
	hint.TextStrokeColor3 = Color3.fromRGB(20, 22, 30)
	hint.TextTransparency = 1
	hint.TextStrokeTransparency = 1
	hint.Parent = gui
	local sizeC = Instance.new("UITextSizeConstraint")
	sizeC.MaxTextSize = 24
	sizeC.Parent = hint

	local cur -- รัศมีที่แสดงอยู่ (ไล่ตามค่าจริงตอนอัปเกรด)
	local shown = false
	local lastColor = 0
	RunService.Heartbeat:Connect(function(dt)
		local target = state:GetAttribute("CampReveal")
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local active = target and target < 50000 and root and player:GetAttribute("InRun") and not player:GetAttribute("FogPass")
		if not active then
			if shown then
				folder.Parent = nil
				shown = false
			end
			hint.TextTransparency = 1
			hint.TextStrokeTransparency = 1
			cur = target and math.min(target, 50000) or cur
			return
		end
		cur = cur and (cur + (target - cur) * (1 - math.exp(-dt * 0.8))) or target
		if math.abs(cur - target) < 1 then
			cur = target
		end
		local pos = root.Position
		local flat = Vector3.new(pos.X, 0, pos.Z)
		local d = flat.Magnitude
		-- กันเดินทะลุ: ดันกลับ + ตัดความเร็วขาออก
		local lim = cur - 4
		if d > lim and d > 1 then
			local dir = flat.Unit
			root.CFrame = root.CFrame + dir * (lim - d)
			local v = root.AssemblyLinearVelocity
			local out = v:Dot(dir)
			if out > 0 then
				root.AssemblyLinearVelocity = v - dir * out
			end
			d = lim
		end
		-- ป้ายเตือน
		local near = math.clamp((d - (cur - 70)) / 50, 0, 1)
		if near > 0 then
			local lv = state:GetAttribute("CampLevel") or 1
			hint.Text = string.format("หมอกหนาเกินกว่าจะผ่านได้ — อัปเกรดกองไฟ (Lv.%d → %d) เพื่อสำรวจต่อ", lv, lv + 1)
		end
		hint.TextTransparency = 1 - near
		hint.TextStrokeTransparency = 1 - near * 0.6
		-- กำแพง: แสดงเฉพาะตอนใกล้
		local visible = d > cur - SHOW
		if visible ~= shown then
			shown = visible
			folder.Parent = visible and Workspace.CurrentCamera or nil
		end
		if not visible then
			return
		end
		if os.clock() - lastColor > 0.5 then
			lastColor = os.clock()
			local c = Lighting.ClockTime
			local dayK = math.clamp(math.min(c - 5.5, 19 - c) / 1.5, 0, 1)
			local col = NIGHT:Lerp(DAY, dayK)
			if state:GetAttribute("BloodMoon") then
				col = col:Lerp(Color3.fromRGB(90, 20, 24), 0.6)
			end
			for _, f in ipairs(allFrames) do
				f.BackgroundColor3 = col
			end
			for _, e in ipairs(mists) do
				e.Color = ColorSequence.new(col)
			end
		end
		local cy = pos.Y + HEIGHT / 2 - 205 -- ระดับสายตาอยู่ช่วงทึบของไล่สี
		local a0 = math.atan2(pos.Z, pos.X)
		for _, layer in ipairs(layers) do
			local R = cur + layer.Off
			local step = math.min(SEG / R, 2 * math.pi / N)
			local base = math.floor(a0 / step + 0.5) * step -- ล็อกช่อง = แผ่นไม่ไหลตามผู้เล่น
			local w = math.floor(2 * R * math.sin(step / 2) + 1)
			local resize = layer.W ~= w
			layer.W = w
			for i, p in ipairs(layer.Parts) do
				local ang = base + (i - (N + 1) / 2) * step
				local at = Vector3.new(math.cos(ang) * R, cy, math.sin(ang) * R)
				if resize then
					p.Size = Vector3.new(w, HEIGHT, 0.5)
				end
				p.CFrame = CFrame.lookAt(at, Vector3.new(0, cy, 0))
			end
		end
	end)
end

return FogWall
