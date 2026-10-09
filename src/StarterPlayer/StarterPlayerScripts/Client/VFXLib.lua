--[[
	VFXLib — เล่นเอฟเฟกต์อนุภาคจากคลัง ReplicatedStorage.Assets.VFX (แพ็ก VFX จาก Creator Store)
	  VFXLib.Play(path, cframe, opts) -> model
	    path  = "VFXPack/Big/Explosion-01" (ไล่ชื่อลูกทีละชั้น)
	    opts  = { Scale = 1, Duration = 1.5, Tint = Color3?, Follow = BasePart?/Attachment? }
	  VFXLib.List() -> รายชื่อเอฟเฟกต์ทั้งหมด (ใช้ในโหมดเทสต์โชว์ VFX)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VFXLib = {}

local function root()
	local a = ReplicatedStorage:FindFirstChild("Assets")
	return a and a:FindFirstChild("VFX")
end

function VFXLib.Find(path)
	local node = root()
	for seg in string.gmatch(path, "[^/]+") do
		node = node and node:FindFirstChild(seg)
	end
	return node
end

local function folder()
	local f = Workspace:FindFirstChild("VFXPlay")
	if not f then
		f = Instance.new("Folder")
		f.Name = "VFXPlay"
		f.Parent = Workspace
	end
	return f
end

local function tintSeq(seq, color)
	local ks = {}
	for _, k in ipairs(seq.Keypoints) do
		local h, s, v = k.Value:ToHSV()
		local th, ts = color:ToHSV()
		table.insert(ks, ColorSequenceKeypoint.new(k.Time, Color3.fromHSV(th, math.max(ts, s * 0.5), v)))
	end
	return ColorSequence.new(ks)
end

function VFXLib.Play(path, cf, opts)
	opts = opts or {}
	local tpl = VFXLib.Find(path)
	if not tpl then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "VFX_" .. tpl.Name
	local inst = tpl:Clone()
	inst.Parent = m
	local maxLife = 0
	local emitters = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Transparency = 1
		elseif d:IsA("ParticleEmitter") then
			maxLife = math.max(maxLife, d.Lifetime.Max)
			if opts.Tint then
				d.Color = tintSeq(d.Color, opts.Tint)
			end
			if opts.Rate then
				d.Rate *= opts.Rate
			end
			d.Enabled = false
			table.insert(emitters, d)
		elseif d:IsA("Beam") or d:IsA("Trail") then
			if opts.Tint then
				d.Color = tintSeq(d.Color, opts.Tint)
			end
			d.Enabled = false
			table.insert(emitters, d)
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceGui")
			or d:IsA("BillboardGui") or d:IsA("Humanoid") or d:IsA("Sound") then
			-- แพ็กเดโมบางตัวมีหัว/หน้ายิ้ม/ป้ายติดมา -> เอาเฉพาะอนุภาค
			d:Destroy()
		end
	end
	local cf0 = m:GetBoundingBox()
	m.WorldPivot = cf0
	if (opts.Scale or 1) ~= 1 then
		pcall(function()
			m:ScaleTo(opts.Scale)
		end)
	end
	m:PivotTo(cf)
	m.Parent = folder()
	for _, e in ipairs(emitters) do
		e.Enabled = true
		if e:IsA("ParticleEmitter") and opts.Burst then
			e:Emit(math.max(1, math.floor(e.Rate * opts.Burst)))
		end
	end
	-- ติดตามชิ้นส่วน (เช่น ปากมังกร)
	local conn
	if opts.Follow then
		local offset = opts.FollowOffset or CFrame.new()
		conn = RunService.RenderStepped:Connect(function()
			if not (m.Parent and opts.Follow.Parent) then
				conn:Disconnect()
				return
			end
			local base = opts.Follow:IsA("Attachment") and opts.Follow.WorldCFrame or opts.Follow.CFrame
			if opts.Aim then
				base = CFrame.lookAt(base.Position, opts.Aim)
			end
			m:PivotTo(base * offset)
		end)
	end
	local dur = opts.Duration or 1.2
	task.delay(dur, function()
		for _, e in ipairs(emitters) do
			if e.Parent then
				e.Enabled = false
			end
		end
	end)
	task.delay(dur + maxLife * (opts.Scale or 1) + 0.5, function()
		if conn then
			conn:Disconnect()
		end
		m:Destroy()
	end)
	return m
end

-- รายชื่อเอฟเฟกต์ทั้งหมด: ลูกของหมวด (Big/Anime/Beams/...) หรือทั้งแพ็กถ้าไม่มีหมวด
function VFXLib.List()
	local out = {}
	local r = root()
	for _, pack in ipairs(r and r:GetChildren() or {}) do
		local cats = {}
		for _, c in ipairs(pack:GetChildren()) do
			if c:IsA("Model") or c:IsA("Folder") then
				table.insert(cats, c)
			end
		end
		if #cats == 0 then
			table.insert(out, pack.Name)
		else
			for _, c in ipairs(cats) do
				local fx = 0
				for _, e in ipairs(c:GetChildren()) do
					if e:FindFirstChildWhichIsA("ParticleEmitter", true) or e:FindFirstChildWhichIsA("Beam", true) then
						table.insert(out, pack.Name .. "/" .. c.Name .. "/" .. e.Name)
						fx += 1
					end
				end
				if fx == 0 and (c:FindFirstChildWhichIsA("ParticleEmitter", true)) then
					table.insert(out, pack.Name .. "/" .. c.Name)
				end
			end
		end
	end
	table.sort(out)
	return out
end

return VFXLib
