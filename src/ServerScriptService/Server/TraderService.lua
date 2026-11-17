--[[
	TraderService — พ่อค้าเร่ (แบบ Pelt Trader ใน 99 Nights)
	มาที่แคมป์ช่วงกลางวันทุก 3 วัน (วันที่ 2, 5, 8 ...) แลกหนัง/กระดูก/แก่นธาตุ เป็นยา วัตถุดิบ และอาวุธ
	เดินออกมาจากป่า -> ยืนนอกขอบเขตแคมป์ (ไม่บังที่สร้างฐาน · ตัวทะลุได้) · สร้างของมาทับ = เดินหลบไปจุดใหม่
	พลบค่ำ = เก็บร้านแล้วเดินกลับเข้าป่า
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local Shop = require(ReplicatedStorage.Shared.Shop)
local Items = require(ReplicatedStorage.Shared.Items)
local Limits = require(ReplicatedStorage.Shared.Limits)
local MeshProps = require(ReplicatedStorage.Shared.MeshProps)

local TraderService = {}

local V = Vector3.new
local CF = CFrame.new
local C = Color3.fromRGB

function TraderService:Init(ctx)
	self.ctx = ctx
	self.rng = Random.new()
end

local function part(parent, props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- ตัวพ่อค้า: ผู้ชายผ้าคลุมแบกเป้ใหญ่ + โคมไฟ (สร้างจากชิ้นส่วน)
local function buildTrader(cf)
	-- พ่อค้าเร่จาก Creator Store (คนคลุมผ้า) + ตัวชนใสไว้ติดปุ่มแลกของ
	local PropBuilder = require(game:GetService("ReplicatedStorage").Shared.PropBuilder)
	local store = Instance.new("Model")
	store.Name = "Trader"
	if PropBuilder.Imported("TraderNPC", cf, 3.8, store) then
		local body = part(store, { Name = "Body", Size = V(2.6, 6.6, 2), CFrame = cf * CF(0, 3.3, 0), Transparency = 1 })
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = C(255, 200, 120), 18, 1.5
		l.Parent = body
		return store, body
	end
	store:Destroy()
	local m = Instance.new("Model")
	m.Name = "Trader"
	local cloak = C(110, 80, 52)
	local body = part(m, { Name = "Body", Size = V(2.6, 4.4, 1.8), CFrame = cf * CF(0, 3.4, 0), Color = cloak, Material = Enum.Material.Fabric })
	part(m, { Shape = Enum.PartType.Ball, Size = V(1.9, 1.9, 1.9), CFrame = cf * CF(0, 6.4, 0), Color = C(220, 180, 150) })
	part(m, { ClassName = "WedgePart", Size = V(2.6, 1.6, 2.4), CFrame = cf * CF(0, 7.4, 0.3), Color = cloak, Material = Enum.Material.Fabric })
	part(m, { Size = V(2.8, 3.8, 2.2), CFrame = cf * CF(0, 4.2, 1.9), Color = C(130, 96, 60), Material = Enum.Material.Fabric })
	part(m, { Size = V(1, 1.2, 1), CFrame = cf * CF(0, 6.6, 2.1), Color = C(90, 70, 50), Material = Enum.Material.Wood })
	part(m, { Size = V(0.8, 2.6, 0.8), CFrame = cf * CF(-1, 1, 0), Color = C(70, 50, 36) })
	part(m, { Size = V(0.8, 2.6, 0.8), CFrame = cf * CF(1, 1, 0), Color = C(70, 50, 36) })
	local lamp = part(m, { Size = V(0.8, 1, 0.8), CFrame = cf * CF(1.8, 3.4, -0.8), Color = C(255, 210, 130), Material = Enum.Material.Neon })
	local l = Instance.new("PointLight")
	l.Color = C(255, 200, 120)
	l.Range = 18
	l.Brightness = 2
	l.Parent = lamp
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 50)
	bb.StudsOffset = V(0, 5, 0)
	bb.MaxDistance = 120
	bb.Parent = body
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "🐾 Wandering Trader"
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = C(255, 220, 150)
	t.TextStrokeTransparency = 0.3
	t.Parent = bb
	if MeshProps.Has("Barrel") then
		local b = MeshProps.Build("Barrel")
		b:PivotTo(cf * CF(-3.5, 0, 1))
		b.Parent = m
	end
	if MeshProps.Has("Chest") then
		local c = MeshProps.Build("Chest")
		c:PivotTo(cf * CF(3.5, 0, 1))
		c.Parent = m
	end
	m.PrimaryPart = body
	return m, body
end

---------------------------------------------------------------- เดินเข้า/ออก + จุดยืนนอกเขตสร้าง
-- โมเดลพ่อค้าเป็นเมชก้อนเดียว (ไม่มีกระดูก) -> เดินแบบโยกตัว: เด้งขึ้นลงตามก้าว + เอียงซ้ายขวา + โน้มตัวไปหน้า
local WALK_SPEED = 9 -- stud/วิ
local WALK_IN = 55 -- เริ่มเดินจากนอกจุดยืนเท่านี้ (ในป่า)
local STAND_OUT = 8 -- ยืนนอกขอบเขตแคมป์ (เขตวางสิ่งก่อสร้าง) เท่านี้ -> ไม่บังที่สร้างฐาน

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }

local function ground(pos)
	return workspace:Raycast(pos + V(0, 80, 0), V(0, -300, 0), groundParams)
end

-- จุดนี้ว่างไหม (ไม่มีต้นไม้/หิน/สิ่งก่อสร้างทับ)
function TraderService:Clear(pos)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { self.model }
	for _, pl in ipairs(Players:GetPlayers()) do
		table.insert(ex, pl.Character)
	end
	params.FilterDescendantsInstances = ex
	for _, p in ipairs(workspace:GetPartBoundsInBox(CF(pos + V(0, 4, 0)), V(7, 6, 7), params)) do
		if p.CanCollide and p.Transparency < 0.95 and p.Size.Magnitude > 3 then
			return false
		end
	end
	return true
end

-- จุดยืน: วงรอบนอกเขตแคมป์ เริ่มจากทิศเดิม (ตะวันตกเฉียงใต้) แล้วไล่ซ้าย/ขวาทีละ 20° หาจุดบนบก ไม่ชันเกิน ไม่มีของทับ
function TraderService:FindSpot(avoid)
	local camp = self.ctx.CampPosition
	local r = self.ctx.Services.CampService:CampRadius() + STAND_OUT
	local base = math.atan2(18, -30)
	local fallback
	for i = 0, 17 do
		local ang = base + (i % 2 == 0 and 1 or -1) * math.ceil(i / 2) * math.rad(20)
		local dir = V(math.cos(ang), 0, math.sin(ang))
		local hit = ground(camp + dir * r)
		if hit and hit.Material ~= Enum.Material.Water and hit.Material ~= Enum.Material.CrackedLava and math.abs(hit.Position.Y - camp.Y) < 14 then
			fallback = fallback or { hit.Position, dir }
			if self:Clear(hit.Position) and not (avoid and (hit.Position - avoid).Magnitude < 12) then
				return hit.Position, dir
			end
		end
	end
	if fallback then
		return fallback[1], fallback[2]
	end
	local dir = V(math.cos(base), 0, math.sin(base))
	return camp + dir * r, dir
end

-- วางโมเดลที่เท้า (pos) หันไปทาง look · bob = ระยะก้าว (0 = ยืนนิ่ง)
function TraderService:Pose(pos, look, phase)
	local m = self.model
	if not (m and m.Parent) then
		return
	end
	local flat = V(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		flat = V(0, 0, -1)
	end
	local cf = CFrame.lookAt(pos, pos + flat)
	if phase then
		local s = math.sin(phase)
		cf = cf * CF(0, math.abs(s) * 0.35, 0) * CFrame.Angles(math.rad(-4), 0, s * math.rad(4))
	end
	m:PivotTo(cf * self.rel)
	self.feet, self.look = pos, flat
end

-- เดินตามจุดบนพื้นจนถึงจุดสุดท้าย แล้วเรียก done (หยุดการเดินเดิมก่อนเสมอ)
function TraderService:WalkTo(points, done)
	if self.walk then
		self.walk:Disconnect()
		self.walk = nil
	end
	local i, phase = 1, 0
	self.walk = game:GetService("RunService").Heartbeat:Connect(function(dt)
		local target = points[i]
		local from = self.feet
		if not (target and from and self.model and self.model.Parent) then
			self.walk:Disconnect()
			self.walk = nil
			return
		end
		local d = V(target.X - from.X, 0, target.Z - from.Z)
		local step = WALK_SPEED * dt
		local pos
		if d.Magnitude <= step then
			pos = target
			i += 1
		else
			pos = from + d.Unit * step
		end
		local hit = ground(pos)
		pos = V(pos.X, hit and hit.Position.Y or pos.Y, pos.Z)
		phase += dt * 7.5
		self:Pose(pos, d.Magnitude > 0.01 and d or self.look, phase)
		if i > #points then
			self.walk:Disconnect()
			self.walk = nil
			if done then
				done()
			end
		end
	end)
end

---------------------------------------------------------------- พ่อค้าตัวจริง (R15 มีขา เดินด้วย Humanoid)
-- ตัวละคร R15 จาก HumanoidDescription (เสื้อ/กางเกงพ่อค้า + ฮู้ด + เป้พ่อค้าเร่ จากแคตตาล็อก Roblox)
-- ท่าเดิน/ยืนของ Roblox (R15 มาตรฐาน) -> ขาก้าวจริง ไม่ไถล · Humanoid หันหน้าตามทางเดินเอง
-- เข้าแคมป์แล้วเดินเล่นไปมาในเขตแคมป์ (หาทางเลี่ยงกำแพง/ของด้วย Pathfinding) · คนเข้าใกล้ = หยุดหันหน้ามาหา
local LOOK = {
	Shirt = 863762537, -- Merchant [+] (Blood Meridian)
	Pants = 863762660, -- Merchant [-] (Blood Meridian)
	Hat = "12851049791", -- Brown Hood
	Back = "7853226490", -- Traveling Merchant Backpack
	Skin = C(196, 140, 104),
}
local ANIM = { Idle = "rbxassetid://507766666", Walk = "rbxassetid://507777826" } -- ท่ามาตรฐาน R15 ของ Roblox
local RIG_SPEED = 8 -- เดินเล่นช้าๆ (ท่าเดิน R15 ความเร็ว 1 ≈ 8 stud/วิ)
local GROUP, PGROUP = "ASTrader", "ASPlayers" -- พ่อค้าชนโลก/กำแพงได้ แต่ไม่ชน/ไม่ดันผู้เล่น
local NEAR = 9 -- ผู้เล่นเข้าใกล้เท่านี้ = หยุดเดิน หันมาคุย

local template -- nil = ยังไม่สร้าง · false = สร้างไม่ได้ (ใช้โมเดลเมชเดิม)
local function rigTemplate()
	if template ~= nil then
		return template or nil
	end
	local function make(full)
		local d = Instance.new("HumanoidDescription")
		if full then
			d.Shirt, d.Pants = LOOK.Shirt, LOOK.Pants
			d.HatAccessory, d.BackAccessory = LOOK.Hat, LOOK.Back
		end
		d.HeadColor, d.TorsoColor = LOOK.Skin, LOOK.Skin
		d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor = LOOK.Skin, LOOK.Skin, LOOK.Skin, LOOK.Skin
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end
	local ok, rig = pcall(make, true)
	if not (ok and rig) then
		warn("[Trader] load outfit failed: " .. tostring(rig))
		ok, rig = pcall(make, false)
	end
	if not (ok and rig and rig:FindFirstChild("HumanoidRootPart")) then
		warn("[Trader] R15 rig failed, using mesh trader: " .. tostring(rig))
		template = false
		return nil
	end
	rig.Name = "Trader"
	template = rig
	return rig
end

local function buildRig(cf)
	local tpl = rigTemplate()
	if not tpl then
		return nil
	end
	local m = tpl:Clone()
	local hum = m:FindFirstChildOfClass("Humanoid")
	local root = m:FindFirstChild("HumanoidRootPart")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.WalkSpeed = RIG_SPEED
	hum.BreakJointsOnDeath = false
	hum.MaxHealth, hum.Health = 1e6, 1e6
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CollisionGroup = GROUP
			d.CanQuery = false -- ไม่บังการฟัน/ขุด/ชี้เก็บของของผู้เล่น
			d.CanTouch = false
		end
	end
	local torso = m:FindFirstChild("UpperTorso") or root
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = C(255, 200, 120), 16, 1.2
	l.Parent = torso
	m:PivotTo(cf * CF(0, hum.HipHeight + root.Size.Y / 2, 0))
	return m, root, hum
end

-- ผู้เล่นที่ใกล้สุดในระยะ r (ไม่นับคนล้ม/ตาย)
function TraderService:NearPlayer(r)
	local root = self.root
	if not root then
		return nil
	end
	local best, bestD
	for _, pl in ipairs(Players:GetPlayers()) do
		local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local d = ((hrp.Position - root.Position) * V(1, 0, 1)).Magnitude
			if d < r and (not bestD or d < bestD) then
				best, bestD = hrp, d
			end
		end
	end
	return best
end

-- จุดเดินเล่นสุ่มในเขตแคมป์ (ห่างกองไฟ · บนบก · ไม่ทับกำแพง/ของ)
function TraderService:WanderPoint()
	local camp = self.ctx.CampPosition
	local campR = self.ctx.Services.CampService:CampRadius()
	local rng = self.rng
	for _ = 1, 12 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(11, math.max(13, campR - 3))
		local hit = ground(camp + V(math.cos(a) * r, 0, math.sin(a) * r))
		if hit and hit.Material ~= Enum.Material.Water and hit.Material ~= Enum.Material.CrackedLava and math.abs(hit.Position.Y - camp.Y) < 12 then
			local far = not self.root or ((hit.Position - self.root.Position) * V(1, 0, 1)).Magnitude > 8
			if far and self:Clear(hit.Position) then
				return hit.Position
			end
		end
	end
	return nil
end

-- เดินไปจุด target ด้วย Humanoid (หาทางด้วย Pathfinding) · คืน true = ถึง · token เปลี่ยน = ยกเลิก
--   ติด = กระโดด · ติดนาน = ขยับข้ามไปจุดถัดไป · ระหว่างเดินเล่นในแคมป์ คนเข้าใกล้ = หยุดรอ
function TraderService:GoTo(target, token)
	local hum, root = self.hum, self.root
	if not (hum and root) then
		return false
	end
	local pts
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 6, AgentCanJump = true, WaypointSpacing = 5, Costs = { Water = math.huge } })
	local ok = pcall(path.ComputeAsync, path, root.Position, target)
	if ok and path.Status == Enum.PathStatus.Success then
		pts = {}
		for i, wp in ipairs(path:GetWaypoints()) do
			if i > 1 then
				table.insert(pts, wp)
			end
		end
	end
	if not pts or #pts == 0 then
		pts = { { Position = target, Action = Enum.PathWaypointAction.Walk } }
	end
	for _, wp in ipairs(pts) do
		if wp.Action == Enum.PathWaypointAction.Jump then
			hum.Jump = true
		end
		local last, lastT = root.Position, os.clock()
		while true do
			if self.token ~= token or not root.Parent then
				return false
			end
			-- คนเข้ามาใกล้ (ตอนเดินเล่นในแคมป์) -> หยุดรอจนคนเดินออกไป
			while self.ready and self:NearPlayer(NEAR) do
				hum:MoveTo(root.Position)
				task.wait(0.25)
				if self.token ~= token or not root.Parent then
					return false
				end
				last, lastT = root.Position, os.clock()
			end
			local flat = (wp.Position - root.Position) * V(1, 0, 1)
			if flat.Magnitude < 2.2 then
				break
			end
			hum:MoveTo(wp.Position)
			task.wait(0.1)
			if (root.Position - last).Magnitude > 0.6 then
				last, lastT = root.Position, os.clock()
			elseif os.clock() - lastT > 3.5 then
				-- ติดแน่น: ยกข้ามไปจุดนี้เลย
				root.CFrame = CFrame.lookAt(wp.Position + V(0, hum.HipHeight + root.Size.Y / 2 + 0.5, 0), wp.Position + V(0, hum.HipHeight + root.Size.Y / 2 + 0.5, 0) + (flat.Magnitude > 0.1 and flat.Unit or V(0, 0, -1)))
				break
			elseif os.clock() - lastT > 1.2 then
				hum.Jump = true
			end
		end
	end
	return self.token == token
end

-- ท่าเดิน/ยืน + หันหน้าหาคนที่มาคุย (ทุกเฟรม)
function TraderService:Animate()
	local hum, root = self.hum, self.root
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local function load(id)
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, t = pcall(animator.LoadAnimation, animator, a)
		if ok and t then
			t.Looped = true
			return t
		end
		return nil
	end
	local idle, walk = load(ANIM.Idle), load(ANIM.Walk)
	if idle then
		idle.Priority = Enum.AnimationPriority.Idle
		idle:Play(0.2)
	end
	if walk then
		walk.Priority = Enum.AnimationPriority.Movement
	end
	local walking = false
	self.anim = RunService.Heartbeat:Connect(function(dt)
		if not root.Parent then
			return
		end
		self.feet = root.Position - V(0, hum.HipHeight + root.Size.Y / 2, 0) -- จุดเท้า (เทสต์/ระบบอื่นอ่าน)
		local v = root.AssemblyLinearVelocity
		local speed = V(v.X, 0, v.Z).Magnitude
		if walk then
			if speed > 0.8 then
				if not walking then
					walking = true
					walk:Play(0.25)
				end
				walk:AdjustSpeed(math.clamp(speed / RIG_SPEED, 0.5, 1.6))
			elseif walking then
				walking = false
				walk:Stop(0.3)
			end
		end
		-- ยืนอยู่ + มีคนใกล้ = ค่อยๆ หันหน้าไปหาคนนั้น
		local who = speed < 0.8 and self.ready and self:NearPlayer(NEAR + 3)
		if who then
			hum.AutoRotate = false
			local flat = (who.Position - root.Position) * V(1, 0, 1)
			if flat.Magnitude > 0.5 then
				local want = CFrame.lookAt(root.Position, root.Position + flat)
				root.CFrame = root.CFrame:Lerp(want, math.min(1, dt * 6))
			end
		else
			hum.AutoRotate = true
		end
	end)
end

-- เดินเล่นวนในแคมป์: ยืนพัก 3-7 วิ -> เดินไปจุดใหม่ (ทำจนกว่า token เปลี่ยน)
function TraderService:Wander(token, now)
	task.spawn(function()
		while self.token == token and self.root and self.root.Parent do
			if not now then
				local untilT = os.clock() + self.rng:NextNumber(3, 7)
				while os.clock() < untilT or self:NearPlayer(NEAR) do
					task.wait(0.25)
					if self.token ~= token then
						return
					end
				end
			end
			now = false
			local p = self:WanderPoint()
			if p then
				self:GoTo(p, token)
			end
		end
	end)
end

function TraderService:ArriveRig(instant, m, root, hum)
	local camp = self.ctx.CampPosition
	local campR = self.ctx.Services.CampService:CampRadius()
	local _, dir = self:FindSpot()
	self.model, self.root, self.hum, self.leaving, self.ready = m, root, hum, false, false
	self.token = (self.token or 0) + 1
	local token = self.token
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Trade"
	p.ObjectText = "Wandering Trader"
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.Enabled = false
	p.Parent = root
	p.Triggered:Connect(function(player)
		self.ctx.Remotes.Get("Cinematic"):FireClient(player, "OpenTrader", {})
	end)
	self.prompt = p
	local inside = ground(camp + dir * math.max(12, campR * 0.6))
	local inPos = inside and inside.Position or camp + dir * math.max(12, campR * 0.6)
	local function arrived()
		self.ready = true
		p.Enabled = true
		self.ctx.State:SetAttribute("TraderHere", true)
		self.ctx.Broadcast("The wandering trader has arrived at camp", "Reward")
		self:Wander(token)
	end
	local startPos = inPos
	if not instant then
		local hit = ground(camp + dir * (campR + WALK_IN))
		startPos = hit and hit.Position or camp + dir * (campR + WALK_IN)
	end
	m:PivotTo(CFrame.lookAt(startPos, startPos + (camp - startPos) * V(1, 0, 1)) * CF(0, hum.HipHeight + root.Size.Y / 2, 0))
	m.Parent = workspace
	pcall(root.SetNetworkOwner, root, nil) -- เซิร์ฟเวอร์คุมการเดินเอง (ไม่สั่นตามเน็ตผู้เล่น)
	self:Animate()
	if instant then
		arrived()
		return
	end
	task.spawn(function()
		self:GoTo(inPos, token)
		if self.token == token then
			arrived()
		end
	end)
end

-- instant = เกิดที่จุดยืนเลย ไม่ต้องเดินเข้า (เทสต์)
function TraderService:Arrive(instant)
	if self.model then
		if not self.leaving then
			return
		end
		self:Remove() -- กำลังเดินออกอยู่แล้วถูกเรียกมาใหม่ -> ลบตัวเก่าทิ้ง
	end
	-- มาเยือนรอบใหม่ = รีเซ็ตโควต้าแลกของของทุกคน
	for _, pl in ipairs(Players:GetPlayers()) do
		for _, o in ipairs(Shop.Trader) do
			pl:SetAttribute("Trade_" .. o.Id, nil)
		end
	end
	local rm, rroot, rhum = buildRig(CF(self.ctx.CampPosition))
	if rm then
		if self.model then -- ระหว่างรอโหลดชุด มีอีกคำสั่งสร้างไปแล้ว
			rm:Destroy()
			return
		end
		return self:ArriveRig(instant, rm, rroot, rhum)
	end
	local camp = self.ctx.CampPosition
	local spot, dir = self:FindSpot()
	-- มาเยือนรอบใหม่ = รีเซ็ตโควต้าแลกของของทุกคน
	for _, pl in ipairs(Players:GetPlayers()) do
		for _, o in ipairs(Shop.Trader) do
			pl:SetAttribute("Trade_" .. o.Id, nil)
		end
	end
	local cf0 = CF(spot)
	local m, body = buildTrader(cf0)
	self.model, self.leaving, self.ready = m, false, false
	self.rel = cf0:ToObjectSpace(m:GetPivot())
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false -- เดินทะลุได้ ไม่ขวางทาง
		end
	end
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Trade"
	p.ObjectText = "Wandering Trader"
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.Enabled = false
	p.Parent = body
	p.Triggered:Connect(function(player)
		self.ctx.Remotes.Get("Cinematic"):FireClient(player, "OpenTrader", {})
	end)
	self.prompt = p
	local function arrived()
		self:Pose(spot, camp - spot)
		self.ready = true
		p.Enabled = true
		self.ctx.State:SetAttribute("TraderHere", true)
		self.ctx.Broadcast("The wandering trader has arrived at camp", "Reward")
	end
	if instant then
		self.feet = spot
		m.Parent = workspace
		arrived()
		return
	end
	-- เดินออกมาจากป่า มุ่งตรงเข้าหาแคมป์ แล้วหยุดที่จุดยืน
	local start = spot + dir * WALK_IN
	local hit = ground(start)
	start = hit and hit.Position or start
	self.feet = start
	self:Pose(start, -dir, 0)
	m.Parent = workspace
	self:WalkTo({ spot }, arrived)
end

-- มีคนสร้าง/ย้ายของมาทับใกล้พ่อค้า (เช่น อัปเกรดกองไฟแล้วเขตแคมป์กว้างขึ้น) -> พ่อค้าเดินหลบไปจุดว่างใหม่
function TraderService:MakeRoom(pos, size)
	if self.root then
		-- ตัวจริง: สร้างของทับตรงที่ยืน -> เลิกทางเดิม เดินไปจุดใหม่ทันที
		if not (self.ready and self.root.Parent) then
			return
		end
		local reach = (size and math.max(size.X, size.Z) / 2 or 3) + 4
		if ((self.root.Position - pos) * V(1, 0, 1)).Magnitude <= reach then
			self.token += 1
			self:Wander(self.token, true)
		end
		return
	end
	if not (self.model and self.ready and not self.leaving and self.feet) then
		return
	end
	local reach = (size and math.max(size.X, size.Z) / 2 or 3) + 5
	if ((self.feet - pos) * V(1, 0, 1)).Magnitude > reach then
		return
	end
	local spot = self:FindSpot(pos)
	local camp = self.ctx.CampPosition
	self.ready = false
	self:WalkTo({ spot }, function()
		self:Pose(spot, camp - spot)
		self.ready = true
	end)
end

function TraderService:Remove()
	if self.walk then
		self.walk:Disconnect()
		self.walk = nil
	end
	self.token = (self.token or 0) + 1
	if self.anim then
		self.anim:Disconnect()
		self.anim = nil
	end
	if self.model then
		self.model:Destroy()
	end
	self.model, self.prompt, self.feet, self.ready, self.leaving = nil, nil, nil, false, false
	self.root, self.hum = nil, nil
end

-- instant = หายไปเลย (จบเกม/กลับล็อบบี้) · ปกติ = เก็บร้านแล้วเดินกลับเข้าป่า
function TraderService:Leave(instant)
	if not self.model or self.leaving then
		if instant and self.model then
			self:Remove()
		end
		return
	end
	self.leaving, self.ready = true, false
	if self.prompt then
		self.prompt.Enabled = false
	end
	self.ctx.State:SetAttribute("TraderHere", false)
	self.ctx.Broadcast("The wandering trader has left", "Info")
	if instant then
		self:Remove()
		return
	end
	if self.root then
		-- ตัวจริง: เดินออกจากแคมป์กลับเข้าป่า แล้วหายไป (กันค้าง: 45 วิ ลบทิ้ง)
		self.token += 1
		local token = self.token
		local camp = self.ctx.CampPosition
		local out = (self.root.Position - camp) * V(1, 0, 1)
		out = out.Magnitude > 0.1 and out.Unit or V(1, 0, 0)
		local far = camp + out * (self.ctx.Services.CampService:CampRadius() + WALK_IN + 15)
		local hit = ground(far)
		task.spawn(function()
			self:GoTo(hit and hit.Position or far, token)
			if self.token == token then
				self:Remove()
			end
		end)
		task.delay(45, function()
			if self.token == token then
				self:Remove()
			end
		end)
		return
	end
	if not self.feet then
		self:Remove()
		return
	end
	local out = self.feet - self.ctx.CampPosition
	out = V(out.X, 0, out.Z)
	out = out.Magnitude > 0.1 and out.Unit or V(1, 0, 0)
	self:WalkTo({ self.feet + out * (WALK_IN + 15) }, function()
		self:Remove()
	end)
end

function TraderService:OnDay(day)
	if day >= 2 and (day - 2) % Shop.TraderEvery == 0 then
		task.spawn(self.Arrive, self) -- โหลดชุดพ่อค้าอาจรอเน็ต -> ไม่ให้นาฬิกาวันค้าง
	end
end

function TraderService:Start(ctx)
	-- พ่อค้าไม่ชน/ไม่ดันผู้เล่น (ยังชนพื้น/กำแพง/ของในโลกตามปกติ)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP)
		PhysicsService:RegisterCollisionGroup(PGROUP)
		PhysicsService:CollisionGroupSetCollidable(GROUP, PGROUP, false)
	end)
	local function tagChar(char)
		local function set(d)
			if d:IsA("BasePart") then
				d.CollisionGroup = PGROUP
			end
		end
		for _, d in ipairs(char:GetDescendants()) do
			set(d)
		end
		char.DescendantAdded:Connect(set)
	end
	local function onPlayer(pl)
		if pl.Character then
			tagChar(pl.Character)
		end
		pl.CharacterAdded:Connect(tagChar)
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		onPlayer(pl)
	end
	Players.PlayerAdded:Connect(onPlayer)
	task.spawn(rigTemplate) -- โหลดชุดพ่อค้ารอไว้ก่อน (มาถึงแล้วโผล่ทันที)

	local function trade(player, offerId)
		if ctx.Services.SurvivalService:IsIncapacitated(player) then
			return
		end
		local offer = Shop.TraderById[offerId]
		if not (offer and self.model and self.ready) then
			return
		end
		local char = player.Character
		if not char or (char:GetPivot().Position - self.model:GetPivot().Position).Magnitude > 30 then
			ctx.Notify(player, "You must be near the trader", "Error")
			return
		end
		local inv = ctx.Services.InventoryService
		-- โควต้าต่อการมาเยือน + ของที่มีแล้ว/ครบจำนวน -> ไม่ให้แลก (ไม่เสียของ)
		local key = "Trade_" .. offerId
		local used = player:GetAttribute(key) or 0
		if used >= Limits.TradesPerVisit then
			ctx.Notify(player, string.format("You've traded this %d times already — wait for the trader's next visit", Limits.TradesPerVisit), "Error")
			return
		end
		for id, n in pairs(offer.Give) do
			if Items.Data[id] and Items.Data[id].Category == "Tool" and not Items.IsMulti(id) and inv:Count(player, id) > 0 then
				ctx.Notify(player, "You already have " .. Items.DisplayName(id) .. "", "Info")
				return
			end
			if inv:Room(player, id) < n then
				ctx.Notify(player, inv:LimitText(id) .. " — maxed out", "Error")
				return
			end
		end
		if not inv:Spend(player, offer.Cost) then
			ctx.Notify(player, "Not enough items to trade", "Error")
			return
		end
		for id, n in pairs(offer.Give) do
			inv:Add(player, id, n)
		end
		player:SetAttribute(key, used + 1)
		ctx.Notify(player, string.format("🐾 Trade complete! (%d more trades left for this item)", Limits.TradesPerVisit - used - 1), "Good")
	end
	TraderService.TestTrade = trade
	ctx.Remotes.Get("Trade").OnServerEvent:Connect(trade)
	ctx.State:GetAttributeChangedSignal("Phase"):Connect(function()
		local ph = ctx.State:GetAttribute("Phase")
		if ph == "Dusk" or ph == "Night" then
			self:Leave()
		elseif ph == "Ended" or ph == "Lobby" then
			self:Leave(true)
		end
	end)
end

return TraderService
