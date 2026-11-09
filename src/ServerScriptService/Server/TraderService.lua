--[[
	TraderService — พ่อค้าเร่ (แบบ Pelt Trader ใน 99 Nights)
	มาที่แคมป์ช่วงกลางวันทุก 3 วัน (วันที่ 2, 5, 8 ...) แลกหนัง/กระดูก/แก่นธาตุ เป็นยา วัตถุดิบ และอาวุธ
	เดินออกมาจากป่า -> ยืนนอกขอบเขตแคมป์ (ไม่บังที่สร้างฐาน · ตัวทะลุได้) · สร้างของมาทับ = เดินหลบไปจุดใหม่
	พลบค่ำ = เก็บร้านแล้วเดินกลับเข้าป่า
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- instant = เกิดที่จุดยืนเลย ไม่ต้องเดินเข้า (เทสต์)
function TraderService:Arrive(instant)
	if self.model then
		if not self.leaving then
			return
		end
		self:Remove() -- กำลังเดินออกอยู่แล้วถูกเรียกมาใหม่ -> ลบตัวเก่าทิ้ง
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
	if self.model then
		self.model:Destroy()
	end
	self.model, self.prompt, self.feet, self.ready, self.leaving = nil, nil, nil, false, false
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
	if instant or not self.feet then
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
		self:Arrive()
	end
end

function TraderService:Start(ctx)
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
