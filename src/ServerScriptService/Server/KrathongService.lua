--[[
	KrathongService — อีเวนต์ "เทศกาลลอยกระทง" (คืนที่ Config.KrathongNight · รอบละครั้ง)
	  ถึงคืนที่ 20 -> ประตูมิติใหญ่โผล่สุ่มในแมพ (หมุดบนแผนที่ 🌸 + ประกาศ) · อยู่ถึงคืนถัดไปเริ่มแล้วหายไป
	  เข้าประตู -> มิติแม่น้ำยามค่ำบนฟ้า: ไฟประดับ โคมกระดาษ โคมลอย พลุ พระจันทร์ · ชาวบ้าน (NPC) ยืนบนท่าน้ำลอยกระทงลงแม่น้ำเรื่อยๆ
	  กระทงลอยตามน้ำ -> กด E เก็บ: คนละ Config.KrathongMax (20) อัน · กระทงเข้ากระเป๋ากระทง (KrathongBank) ไม่ใช่ Ruby
  ร้านงานวัดบนลานท่าน้ำ (Shop.Festival): เอากระทงแลกของ · ครบ 20 = แถมกระทงโบนัส
  ประตูใหญ่: ปุ่มกดย้ายลงมาระดับพื้น + เดินทะลุม่านเข้าได้เลย (ม่านกว้าง 44 -> จุดกลางม่านสูงเกินระยะกด)
	  โมเดลกระทง: Creator Store (Assets.Props.KrathongA/B/C) สุ่มแบบ · ไม่มีโมเดล = กระทงปั้นจากชิ้นส่วน
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PropBuilder = require(ReplicatedStorage.Shared.PropBuilder)
local Shop = require(ReplicatedStorage.Shared.Shop)
local Items = require(ReplicatedStorage.Shared.Items)

local KrathongService = {}

local NIGHT = Config.KrathongNight or 20
local MAX = Config.KrathongMax or 20
local REALM_Y = 3400 -- สูงกว่ามิติศาลเจ้า (2400) · AtmosphereController: Y > 3200 = แสงกลางคืนเทศกาล
local RIVER_W, LEN = 44, 330 -- ความกว้างแม่น้ำ / ความยาวมิติ (แกน Z)
local PINK = Color3.fromRGB(255, 160, 210)
local GOLD = Color3.fromRGB(255, 214, 120)
local BULBS = { Color3.fromRGB(255, 214, 120), Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 170, 90), Color3.fromRGB(170, 230, 255) }
local MODELS = { "KrathongA", "KrathongB", "KrathongC" }
local V, CF = Vector3.new, CFrame.new

function KrathongService:Init(ctx)
	self.ctx = ctx
	self.done = false -- รอบนี้เกิดไปแล้ว
	self.active = false
	self.floating = {}
end

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

---------------------------------------------------------------- จุดเกิดประตู
function KrathongService:FindSpot()
	local layout = self.ctx.Layout
	local camp = self.ctx.CampPosition or Vector3.zero
	local rng = Random.new()
	for _ = 1, 400 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(280, math.min(950, layout.Half - layout.EdgeOcean - 150))
		local x, z = camp.X + math.cos(a) * r, camp.Z + math.sin(a) * r
		local h, _, lava = layout:HeightAt(x, z)
		local ok = not lava and h > layout.WaterLevel + 3
		if ok then
			for _, o in ipairs({ { 14, 0 }, { -14, 0 }, { 0, 14 }, { 0, -14 } }) do
				if math.abs(layout:HeightAt(x + o[1], z + o[2]) - h) > 3 then
					ok = false
					break
				end
			end
		end
		if ok then
			for _, sp in ipairs(layout.Specials) do
				if (Vector3.new(x, 0, z) - Vector3.new(sp.Position.X, 0, sp.Position.Z)).Magnitude < (sp.Radius or 120) + 60 then
					ok = false
					break
				end
			end
		end
		if ok then
			return Vector3.new(x, h, z)
		end
	end
	return camp + Vector3.new(320, 0, 0)
end

---------------------------------------------------------------- กระทง
function KrathongService:MakeKrathong(cf)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	local name = MODELS[math.random(#MODELS)]
	local m
	local root = part(nil, { Name = "Float", Size = V(3.2, 1, 3.2), Transparency = 1, CanCollide = false, CanTouch = false, CFrame = cf })
	if props and props:FindFirstChild(name) then
		m = PropBuilder.Imported(name, cf * CF(0, -0.35, 0), 3.4, nil, false)
	end
	if not m then
		-- กระทงปั้น: ฐานใบตอง + กลีบบัว + เทียน
		m = Instance.new("Model")
		part(m, { Shape = Enum.PartType.Cylinder, Size = V(0.9, 3, 3), CFrame = cf * CF(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(70, 140, 60), Material = Enum.Material.Grass })
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			part(m, { Size = V(0.7, 1.1, 0.25), CFrame = cf * CF(math.cos(a) * 1.1, 0.9, math.sin(a) * 1.1) * CFrame.Angles(0, -a, 0.35), Color = Color3.fromRGB(255, 190, 220), Material = Enum.Material.SmoothPlastic })
		end
		part(m, { Size = V(0.25, 1.2, 0.25), CFrame = cf * CF(0, 1.4, 0), Color = Color3.fromRGB(250, 240, 210) })
	end
	m.Name = "Krathong"
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = root, d
			w.Parent = root
		end
	end
	-- เปลวเทียนเล็ก + แสงอุ่น
	local flame = part(m, { Name = "Flame", Shape = Enum.PartType.Ball, Size = V(0.35, 0.5, 0.35), CFrame = cf * CF(0, 2.1, 0), Color = Color3.fromRGB(255, 200, 90), Material = Enum.Material.Neon, CanCollide = false, CanTouch = false, Anchored = false, Massless = true })
	local fw = Instance.new("WeldConstraint")
	fw.Part0, fw.Part1 = root, flame
	fw.Parent = root
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = Color3.fromRGB(255, 190, 110), 9, 1.1
	l.Parent = flame
	root.Parent = m
	m.PrimaryPart = root
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Collect"
	prompt.ObjectText = "Krathong"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(p)
		self:Collect(p, m)
	end)
	return m, root
end

-- ลอยตามน้ำ: จากท่าน้ำ -> ปลายแม่น้ำ (ส่ายซ้ายขวาเบาๆ) แล้วหาย
function KrathongService:Launch(fromCF, laneX)
	if not self.active or #self.floating >= 26 then
		return
	end
	local F = self.frame
	local m, root = self:MakeKrathong(fromCF)
	m.Parent = self.realm
	table.insert(self.floating, m)
	task.spawn(function()
		local startZ = (F:PointToObjectSpace(fromCF.Position)).Z
		local z, x = startZ, laneX
		-- วางลงน้ำจากมือ NPC
		local wy = self.waterY - F.Position.Y + 0.25 -- ระดับผิวน้ำในกรอบมิติ (F อยู่ที่ REALM_Y แล้ว)
		local water = F * CF(laneX, wy, startZ)
		local t = TweenService:Create(root, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = water })
		t:Play()
		t.Completed:Wait()
		-- ลอยด้วยฟิสิกส์บนน้ำจริง (แรงพยุงของ Terrain + กระแสน้ำ) -> เครื่องผู้เล่นเห็นลื่น (ฟิสิกส์ถูก interpolate)
		--   เดิม tween ทีละช่วง 2.2 วิ ฝั่งเซิร์ฟ = ภาพกระตุก + หักทิศทุกช่วง
		root.Anchored = false
		root.CanCollide = true -- ชนกันเองเบาๆ ตอนลอยเบียดกัน
		root.Massless = false
		root.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.3, 0, 1, 1) -- เบากว่าน้ำ = ลอย
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		local att = Instance.new("Attachment")
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane -- คุมแค่แนวราบ แนวดิ่งปล่อยให้น้ำพยุง (โยกขึ้นลงเอง)
		lv.PrimaryTangentAxis = F.RightVector
		lv.SecondaryTangentAxis = F.LookVector * -1 -- ปลายน้ำ = +Z ของกรอบมิติ
		lv.MaxForce = 600
		lv.PlaneVelocity = Vector2.new(0, 4)
		lv.Parent = root
		local ao = Instance.new("AlignOrientation")
		ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
		ao.Attachment0 = att
		ao.Responsiveness = 6
		ao.MaxTorque = 2000
		ao.CFrame = CFrame.Angles(0, math.random() * math.pi * 2, 0)
		ao.Parent = root
		local t0 = os.clock()
		local spin = (math.random() - 0.5) * 0.5
		local phase = math.random() * 6
		while m.Parent and self.active and os.clock() - t0 < 150 do
			task.wait(0.4)
			local lp = F:PointToObjectSpace(root.Position)
			if lp.Z > LEN / 2 - 6 or root.Position.Y < self.waterY - 30 then
				break
			end
			local t = os.clock() - t0
			-- ส่ายไปมาตามสายน้ำ + ดึงกลับเข้าเลนของตัวเอง (ไม่ลอยไปติดฝั่ง)
			local sway = math.sin(t * 0.35 + phase) * 1.2 + (laneX - lp.X) * 0.25
			lv.PlaneVelocity = Vector2.new(math.clamp(sway, -2.5, 2.5), 3.6 + math.sin(t * 0.2 + phase) * 0.6)
			ao.CFrame = CFrame.Angles(0, phase + t * spin, 0)
		end
		if m.Parent then
			m:Destroy()
		end
	end)
	m.Destroying:Connect(function()
		local i = table.find(self.floating, m)
		if i then
			table.remove(self.floating, i)
		end
	end)
end

function KrathongService:Collect(player, m)
	if not (m.Parent and self.active and player:GetAttribute("InRun")) then
		return
	end
	local n = player:GetAttribute("Krathongs") or 0
	if n >= MAX then
		self.ctx.Notify(player, string.format("🌸 You already collected all %d krathongs", MAX), "Info")
		return
	end
	local pos = m:GetPivot().Position
	m:Destroy()
	n += 1
	player:SetAttribute("Krathongs", n)
	-- กระทงเข้ากระเป๋ากระทง (ใช้แลกของที่ร้านงานวัด) · ครบ 20 = แถมโบนัส
	local bank = (player:GetAttribute("KrathongBank") or 0) + 1
	if n >= MAX then
		bank += Shop.FestivalWishBonus
	end
	player:SetAttribute("KrathongBank", bank)
	self.ctx.Remotes.Get("WorldEvent"):FireClient(player, "KrathongGot", { Position = pos, Count = n, Max = MAX })
	if n >= MAX then
		self.ctx.Remotes.Get("WorldEvent"):FireClient(player, "KrathongWish", { Position = self.plaza, Bonus = Shop.FestivalWishBonus })
		self.ctx.Broadcast(string.format("🌸 %s collected all %d krathongs — wish granted!", player.DisplayName, MAX), "Reward")
	end
end

-- ร้านงานวัด: จ่ายกระทงแลกของ (ต้องยืนใกล้ร้าน · แลกได้ตาม Stock ต่อคน)
function KrathongService:Trade(player, offerId)
	local ctx = self.ctx
	local o = Shop.FestivalById[offerId]
	if not (o and self.active and self.stallPos and player:GetAttribute("InRun")) then
		return
	end
	if ctx.Services.SurvivalService:IsIncapacitated(player) then
		return
	end
	local char = player.Character
	if not char or (char:GetPivot().Position - self.stallPos).Magnitude > 30 then
		ctx.Notify(player, "You must be at the festival shop", "Error")
		return
	end
	local key = "Fest_" .. o.Id
	local used = player:GetAttribute(key) or 0
	if used >= o.Stock then
		ctx.Notify(player, "Sold out", "Error")
		return
	end
	local bank = player:GetAttribute("KrathongBank") or 0
	if bank < o.Price then
		ctx.Notify(player, "🌸 Not enough krathongs", "Error")
		return
	end
	local inv = ctx.Services.InventoryService
	for id, n in pairs(o.Give or {}) do
		if Items.Data[id] and Items.Data[id].Category == "Tool" and not Items.IsMulti(id) and inv:Count(player, id) > 0 then
			ctx.Notify(player, "You already have " .. Items.DisplayName(id) .. "", "Info")
			return
		end
		if inv:Room(player, id) < n then
			ctx.Notify(player, inv:LimitText(id) .. " — maxed out", "Error")
			return
		end
	end
	player:SetAttribute("KrathongBank", bank - o.Price)
	player:SetAttribute(key, used + 1)
	for id, n in pairs(o.Give or {}) do
		inv:Add(player, id, n)
	end
	if o.Chest then
		local at = self.stallPos + self.frame.LookVector * -6 + V(0, 3, 0)
		local got = ctx.Services.LootService:GiveTierLoot(o.Chest, at)
		ctx.Remotes.Get("HitFx"):FireClient(player, "Loot", { Items = got, Position = at, Chest = true })
	end
	ctx.Remotes.Get("WorldEvent"):FireClient(player, "KrathongBought", { Id = o.Id, Position = self.stallPos })
	ctx.Notify(player, "🌸 Exchange complete!", "Good")
end

-- ซุ้มใหญ่: ปุ่มกดอยู่กลางม่าน (สูงเกินระยะกด) -> ย้ายลงมาระดับพื้น + แผ่นล่องหนในช่องประตู เดินทะลุ = เข้าเลย
function KrathongService:HookGate(veil, groundY, onEnter)
	local last = {}
	local function go(p)
		if last[p] and os.clock() - last[p] < 3 then
			return
		end
		last[p] = os.clock()
		onEnter(p)
	end
	local att = Instance.new("Attachment")
	att.Name = "PromptPoint"
	att.Parent = veil
	att.WorldPosition = V(veil.Position.X, groundY + 3.5, veil.Position.Z)
	local prompt = veil:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Parent = att
		prompt.MaxActivationDistance = 16
		prompt.Triggered:Connect(go)
	end
	local rot = veil.CFrame - veil.Position
	local pad = part(veil.Parent, {
		Name = "GateTouch", Size = V(math.max(6, veil.Size.X * 0.8), 9, 3),
		CFrame = CF(veil.Position.X, groundY + 4.5, veil.Position.Z) * rot,
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = true,
	})
	pad.Touched:Connect(function(hit)
		local p = Players:GetPlayerFromCharacter(hit.Parent)
		if p and hit.Name == "HumanoidRootPart" then
			go(p)
		end
	end)
	return pad
end

---------------------------------------------------------------- มิติแม่น้ำ
function KrathongService:BuildRealm(xz)
	local rx, rz = math.floor(xz.X / 4 + 0.5) * 4, math.floor(xz.Z / 4 + 0.5) * 4
	local F = CF(rx, REALM_Y, rz)
	self.frame = F
	local m = Instance.new("Model")
	m.Name = "KrathongRealm"
	self.realm = m
	local terrain = Workspace.Terrain
	local W = 172
	-- พื้นดินริมฝั่ง (หญ้า) + ร่องแม่น้ำ + น้ำ (Terrain: น้ำจริง ว่ายได้ สะท้อนแสงไฟ)
	terrain:FillBlock(F * CF(0, -8, 0), V(W, 16, LEN + 24), Enum.Material.Grass)
	terrain:FillBlock(F * CF(0, -6, 0), V(RIVER_W, 12.2, LEN + 30), Enum.Material.Air)
	terrain:FillBlock(F * CF(0, -10, 0), V(RIVER_W, 4, LEN + 30), Enum.Material.Mud)
	terrain:FillBlock(F * CF(0, -4.5, 0), V(RIVER_W, 7, LEN + 30), Enum.Material.Water)
	self.waterY = REALM_Y - 1.2
	self.region = { F, V(W + 8, 40, LEN + 40) }
	-- กำแพงล่องหนกันตกขอบ
	for _, e in ipairs({ { W / 2, 0, 2, LEN + 24 }, { -W / 2, 0, 2, LEN + 24 }, { 0, LEN / 2 + 12, W, 2 }, { 0, -LEN / 2 - 12, W, 2 } }) do
		part(m, { Name = "Bound", Size = V(e[3], 120, e[4]), CFrame = F * CF(e[1], 50, e[2]), Transparency = 1, CanQuery = false })
	end
	-- ลานท่าน้ำ (จุดเกิด) ฝั่งตะวันตก ต้นน้ำ
	local plazaCF = F * CF(-RIVER_W / 2 - 22, 0, -LEN / 2 + 30)
	self.plaza = plazaCF.Position
	local deck = part(m, { Name = "Plaza", Size = V(34, 1, 30), CFrame = plazaCF * CF(0, 0.5, 0), Color = Color3.fromRGB(122, 86, 56), Material = Enum.Material.WoodPlanks })
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local post = part(m, { Size = V(1, 9, 1), CFrame = deck.CFrame * CF(sx * 16, 4.5, sz * 14), Color = Color3.fromRGB(90, 60, 38), Material = Enum.Material.Wood })
			local lan = part(m, { Shape = Enum.PartType.Ball, Size = V(2.2, 2.6, 2.2), CFrame = post.CFrame * CF(0, 5.4, 0), Color = Color3.fromRGB(255, 120, 70), Material = Enum.Material.Neon })
			local pl = Instance.new("PointLight")
			pl.Color, pl.Range, pl.Brightness = Color3.fromRGB(255, 160, 90), 22, 1.2
			pl.Parent = lan
		end
	end
	-- ประตูกลับ (ลานท่าน้ำ)
	local backFrame = plazaCF * CF(-10, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	local _, backVeil = PropBuilder.BuildPortal(backFrame, "Earth", m, { Name = "KrathongBack", Floor = REALM_Y + 1, Label = "Loy Krathong Festival", Action = "Go Back Outside", Model = "GateMystic", Width = 22, Color = PINK, NoTag = true })
	self.backVeil = backVeil
	self:BuildStall(plazaCF * CF(6, 1, -10), m)
	-- ท่าน้ำ + ชาวบ้านลอยกระทง (ฝั่งละ 3)
	self.docks = {}
	for i, z in ipairs({ -LEN / 2 + 40, -LEN / 2 + 95, -LEN / 2 + 150 }) do
		for _, side in ipairs({ -1, 1 }) do
			local zz = z + (side == 1 and 26 or 0)
			local dockCF = F * CF(side * (RIVER_W / 2 - 3), 0.2, zz)
			part(m, { Name = "Dock", Size = V(12, 0.8, 8), CFrame = dockCF * CF(-side * 1, 0, 0), Color = Color3.fromRGB(130, 92, 60), Material = Enum.Material.WoodPlanks })
			for _, pz in ipairs({ -3.4, 3.4 }) do
				part(m, { Size = V(0.8, 6, 0.8), CFrame = dockCF * CF(-side * 6, -2.4, pz), Color = Color3.fromRGB(88, 60, 40), Material = Enum.Material.Wood })
			end
			local npcCF = CFrame.lookAt((dockCF * CF(-side * 3.5, 3.4, 0)).Position, (F * CF(0, 3.4, zz)).Position)
			self:SpawnVillager(npcCF, i * 2 + side)
			table.insert(self.docks, { CF = dockCF * CF(-side * 6.2, 1.6, 0), Lane = side * (RIVER_W / 2 - 9) + (math.random() - 0.5) * 4 })
		end
	end
	-- ไฟประดับริมฝั่ง: เสา + เชือกหย่อน + หลอดไฟหลากสี · โคมกระดาษแขวนสลับ
	for _, side in ipairs({ -1, 1 }) do
		local prev
		for z = -LEN / 2 + 8, LEN / 2 - 8, 26 do
			local top = (F * CF(side * (RIVER_W / 2 + 4), 10, z)).Position
			part(m, { Name = "LightPole", Size = V(0.9, 11, 0.9), CFrame = CF(top - V(0, 5.5, 0)), Color = Color3.fromRGB(96, 66, 44), Material = Enum.Material.Wood })
			if prev then
				local n = 8
				for k = 0, n - 1 do
					local t0, t1 = k / n, (k + 1) / n
					local a = prev:Lerp(top, t0) - V(0, math.sin(t0 * math.pi) * 2.2, 0)
					local b = prev:Lerp(top, t1) - V(0, math.sin(t1 * math.pi) * 2.2, 0)
					part(m, { Size = V(0.12, 0.12, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = Color3.fromRGB(40, 34, 30), CanCollide = false, CanQuery = false })
					local bulb = part(m, { Shape = Enum.PartType.Ball, Size = V(0.55, 0.55, 0.55), CFrame = CF(b - V(0, 0.4, 0)), Color = BULBS[(k % #BULBS) + 1], Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
					if k == 3 then
						local pl = Instance.new("PointLight")
						pl.Color, pl.Range, pl.Brightness = bulb.Color, 16, 0.9
						pl.Parent = bulb
					end
				end
				-- โคมกระดาษกลางสาย
				local mid = prev:Lerp(top, 0.5) - V(0, 3.4, 0)
				part(m, { Size = V(0.1, 1.2, 0.1), CFrame = CF(mid + V(0, 1.3, 0)), Color = Color3.fromRGB(40, 34, 30), CanCollide = false })
				local lan = part(m, { Shape = Enum.PartType.Ball, Size = V(1.8, 2.2, 1.8), CFrame = CF(mid), Color = (z // 26) % 2 == 0 and Color3.fromRGB(255, 90, 80) or Color3.fromRGB(255, 190, 90), Material = Enum.Material.Neon, CanCollide = false })
				local pl = Instance.new("PointLight")
				pl.Color, pl.Range, pl.Brightness = lan.Color, 14, 0.8
				pl.Parent = lan
			end
			prev = top
		end
	end
	-- ต้นไม้ริมฝั่งด้านนอก (ไม่ใช่ของตัดได้)
	local rng = Random.new(rx + rz)
	for k = 1, 34 do
		local side = k % 2 == 0 and 1 or -1
		local p = (F * CF(side * rng:NextNumber(RIVER_W / 2 + 14, W / 2 - 8), 0, rng:NextNumber(-LEN / 2 + 10, LEN / 2 - 10))).Position
		if (p - self.plaza).Magnitude > 30 then
			local inst = PropBuilder.Place(rng:NextNumber() < 0.55 and "Palm" or "Oak", p - V(0, 0.4, 0), rng:NextNumber(0, 6.28), rng:NextNumber(0.8, 1.1), m, rng)
			if inst then
				game:GetService("CollectionService"):RemoveTag(inst, "ResourceNode")
			end
		end
	end
	-- พระจันทร์เต็มดวง + แสงจันทร์
	local moon = part(m, { Name = "Moon", Shape = Enum.PartType.Ball, Size = V(60, 60, 60), CFrame = F * CF(-120, 170, LEN / 2 + 180), Color = Color3.fromRGB(255, 244, 214), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false })
	local ml = Instance.new("PointLight")
	ml.Color, ml.Range, ml.Brightness = Color3.fromRGB(200, 214, 255), 60, 1
	ml.Parent = moon
	-- โคมลอย (ลอยขึ้นฟ้าช้าๆ ทั่วแม่น้ำ)
	local sky = part(m, { Name = "SkyLanterns", Size = V(W, 1, LEN), CFrame = F * CF(0, 6, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 170, 80), Color3.fromRGB(255, 120, 60))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 1.1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.85, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(24, 32)
	e.Speed = NumberRange.new(2, 3.5)
	e.Rate = 3
	e.SpreadAngle = Vector2.new(12, 12)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = V(0.4, 0, 0.6)
	e.Parent = sky
	-- หิ่งห้อย/ประกายเหนือน้ำ
	local glim = part(m, { Name = "Glimmer", Size = V(RIVER_W, 1, LEN), CFrame = F * CF(0, 1, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	local g = Instance.new("ParticleEmitter")
	g.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	g.Color = ColorSequence.new(Color3.fromRGB(255, 230, 170))
	g.LightEmission = 1
	g.Size = NumberSequence.new(0.35)
	g.Lifetime = NumberRange.new(2, 4)
	g.Speed = NumberRange.new(0.3, 1)
	g.Rate = 18
	g.Parent = glim
	-- พลุ (เซิร์ฟเวอร์เปิดเป็นจังหวะ)
	self.fireworks = {}
	for k = 1, 4 do
		local fp = part(m, { Name = "Firework", Size = V(1, 1, 1), CFrame = F * CF((k % 2 == 0 and 1 or -1) * rng:NextNumber(30, 70), rng:NextNumber(70, 100), -LEN / 2 + k * 70), Transparency = 1, CanCollide = false, CanQuery = false })
		local fe = Instance.new("ParticleEmitter")
		fe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fe.LightEmission = 1
		fe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 0) })
		fe.Lifetime = NumberRange.new(1.4, 2.2)
		fe.Speed = NumberRange.new(26, 34)
		fe.SpreadAngle = Vector2.new(180, 180)
		fe.Acceleration = V(0, -14, 0)
		fe.Drag = 1.5
		fe.Rate = 600
		fe.Enabled = false
		fe.Parent = fp
		local fl = Instance.new("PointLight")
		fl.Range, fl.Brightness, fl.Enabled = 60, 3, false
		fl.Parent = fp
		table.insert(self.fireworks, fp)
	end
	m.Parent = Workspace
	return F
end

-- ร้านงานวัด (ซุ้มไม้ หลังคาผ้าลายชมพู-ขาว + ไฟประดับ + แม่ค้า) หน้าร้าน = +Z ของ cf (หันหาจุดเกิด)
function KrathongService:BuildStall(cf, parent)
	local WOOD, DARK = Color3.fromRGB(150, 104, 66), Color3.fromRGB(96, 64, 40)
	local counter = part(parent, { Name = "FestivalCounter", Size = V(12, 3.2, 3), CFrame = cf * CF(0, 1.6, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
	part(parent, { Size = V(12.8, 0.4, 3.6), CFrame = cf * CF(0, 3.4, 0.1), Color = Color3.fromRGB(196, 150, 100), Material = Enum.Material.Wood })
	part(parent, { Size = V(12.2, 1.2, 0.2), CFrame = cf * CF(0, 2.2, 1.55), Color = PINK, Material = Enum.Material.Fabric, CanCollide = false })
	for _, px in ipairs({ -6, 6 }) do
		for _, pz in ipairs({ -3.2, 1.6 }) do
			part(parent, { Size = V(0.6, 9.4, 0.6), CFrame = cf * CF(px, 4.7, pz), Color = DARK, Material = Enum.Material.Wood })
		end
	end
	-- หลังคาผ้าลาย (เอียงลงด้านหน้า)
	for k = 0, 6 do
		part(parent, { Size = V(2, 0.3, 6.6), CFrame = cf * CF(-6 + k * 2, 9.6, -0.8) * CFrame.Angles(math.rad(-10), 0, 0), Color = k % 2 == 0 and PINK or Color3.fromRGB(255, 246, 240), Material = Enum.Material.Fabric })
	end
	-- ชายผ้าหยักหน้าหลังคา + ไฟประดับ
	for k = 0, 11 do
		local x = -5.5 + k
		part(parent, { Size = V(0.9, 0.9, 0.12), CFrame = cf * CF(x, 8.7, 2.4) * CFrame.Angles(0, 0, math.rad(45)), Color = k % 2 == 0 and Color3.fromRGB(255, 246, 240) or PINK, Material = Enum.Material.Fabric, CanCollide = false })
		local bulb = part(parent, { Shape = Enum.PartType.Ball, Size = V(0.45, 0.45, 0.45), CFrame = cf * CF(x + 0.5, 8.1, 2.5), Color = BULBS[(k % #BULBS) + 1], Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
		if k == 3 or k == 8 then
			local pl = Instance.new("PointLight")
			pl.Color, pl.Range, pl.Brightness = bulb.Color, 14, 1
			pl.Parent = bulb
		end
	end
	-- ป้ายร้าน
	local sign = part(parent, { Name = "ShopSign", Size = V(9, 2, 0.3), CFrame = cf * CF(0, 11.2, 2.3), Color = Color3.fromRGB(110, 40, 70), Material = Enum.Material.Wood })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = sign
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "🌸 Festival Shop"
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.fromRGB(255, 230, 160)
	t.Parent = sg
	-- ของบนโต๊ะ: กระทงจิ๋ว + โคม
	for k, x in ipairs({ -4, -1.5, 1.5, 4 }) do
		part(parent, { Shape = Enum.PartType.Cylinder, Size = V(0.5, 1.6, 1.6), CFrame = cf * CF(x, 3.85, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(70, 140, 60), Material = Enum.Material.Grass, CanCollide = false })
		part(parent, { Shape = Enum.PartType.Ball, Size = V(0.9, 0.9, 0.9), CFrame = cf * CF(x, 4.4, 0), Color = k % 2 == 0 and PINK or GOLD, Material = Enum.Material.Neon, CanCollide = false })
	end
	-- แม่ค้า (ยืนหลังโต๊ะ หันหน้าออกหน้าร้าน)
	self:SpawnVillager(CFrame.lookAt((cf * CF(0, 2.9, -2)).Position, (cf * CF(0, 2.9, 6)).Position), 5)
	-- ป้ายลอยเหนือร้าน + ปุ่มแลกของ
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 46)
	bb.StudsOffset = V(0, 11.5, 0)
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	bb.Parent = counter
	local bt = Instance.new("TextLabel")
	bt.Size = UDim2.fromScale(1, 1)
	bt.BackgroundTransparency = 1
	bt.Text = "🌸 Trade krathongs here"
	bt.TextScaled = true
	bt.Font = Enum.Font.FredokaOne
	bt.TextColor3 = Color3.fromRGB(255, 214, 236)
	bt.TextStrokeTransparency = 0.3
	bt.Parent = bb
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Trade"
	prompt.ObjectText = "Festival Shop"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	prompt.Triggered:Connect(function(p)
		if self.active then
			self.ctx.Remotes.Get("WorldEvent"):FireClient(p, "KrathongShop", {})
		end
	end)
	self.stallPos = counter.Position
end

-- ชาวบ้าน (NPC): ตัว Roblox มาตรฐาน สีชุดสุ่มโทนงานวัด · ยืนนิ่งบนท่าน้ำ
function KrathongService:SpawnVillager(cf, seed)
	local SHIRTS = { Color3.fromRGB(230, 120, 160), Color3.fromRGB(250, 200, 90), Color3.fromRGB(120, 180, 230), Color3.fromRGB(150, 210, 140), Color3.fromRGB(240, 150, 90), Color3.fromRGB(200, 150, 230) }
	local SKIN = { Color3.fromRGB(234, 192, 160), Color3.fromRGB(214, 170, 130), Color3.fromRGB(190, 140, 104) }
	local ok, model = pcall(function()
		local d = Instance.new("HumanoidDescription")
		local shirt = SHIRTS[(seed % #SHIRTS) + 1]
		local skin = SKIN[(seed % #SKIN) + 1]
		d.HeadColor, d.LeftArmColor, d.RightArmColor = skin, skin, skin
		d.TorsoColor = shirt
		d.LeftLegColor, d.RightLegColor = Color3.fromRGB(70, 50, 90), Color3.fromRGB(70, 50, 90)
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return
	end
	model.Name = "Villager"
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	model:PivotTo(cf)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Parent = self.realm
end

---------------------------------------------------------------- เริ่ม / จบ
function KrathongService:StartEvent()
	if self.done or self.active then
		return
	end
	self.done, self.active = true, true
	local ctx = self.ctx
	local spot = self:FindSpot()
	local camp = ctx.CampPosition or Vector3.zero
	local face = CFrame.lookAt(spot, Vector3.new(camp.X, spot.Y, camp.Z))
	local root = Instance.new("Model")
	root.Name = "KrathongEvent"
	-- ประตูใหญ่ (หน้าหันไปทางแคมป์) + ป้ายเงื่อนไข/รางวัล
	local _, veil, gateBase = PropBuilder.BuildPortal(face, "Earth", root, { Name = "KrathongGate", Label = "Loy Krathong Festival", Action = "Enter Festival", Model = "GateMystic", Width = 44, Color = PINK, NoTag = true })
	-- จุดยืนหน้าประตู (ตอนกลับออกมา) = ผิวดินจริง (HeightAt ของเลย์เอาต์บางจุดต่ำกว่าพื้นจริง -> เคยวาร์ปกลับจมดิน)
	local front = (face * CF(0, 0, -16)).Position
	self.gateFront = V(front.X, PropBuilder.TerrainY(front, 0), front.Z)
	pcall(PropBuilder.BuildSiteSign, face * CF(-34, 0, -14) * CFrame.Angles(0, math.rad(-20), 0), "Krathong", "Krathong", root)
	-- โคมกระดาษแขวนรอบซุ้ม
	for k = -3, 3 do
		local p = (face * CF(k * 5.5, 30 - math.abs(k) * 1.8, -3)).Position
		local lan = part(root, { Shape = Enum.PartType.Ball, Size = V(2.4, 3, 2.4), CFrame = CF(p), Color = k % 2 == 0 and Color3.fromRGB(255, 110, 90) or Color3.fromRGB(255, 196, 100), Material = Enum.Material.Neon, CanCollide = false })
		local pl = Instance.new("PointLight")
		pl.Color, pl.Range, pl.Brightness = lan.Color, 18, 1
		pl.Parent = lan
	end
	root.Parent = Workspace
	self.gate = root
	self:BuildRealm(spot)
	-- เข้า: กด E ที่ระดับพื้น หรือเดินทะลุม่านเลย
	self.enterPad = self:HookGate(veil, gateBase.Position.Y + 1.5, function(p)
		if self.active and p:GetAttribute("InRun") and not ctx.Services.SurvivalService:IsIncapacitated(p) then
			local dest = self.plaza + V(6, 4, 0)
			ctx.Services.PortalService:Teleport(p, dest, dest + (self.frame.LookVector * 20), PINK, false)
		end
	end)
	if self.backVeil then
		self:HookGate(self.backVeil, REALM_Y + 1, function(p)
			ctx.Services.PortalService:Teleport(p, self.gateFront + V(0, 3, 0), spot, PINK, true)
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("Krathongs", 0)
		p:SetAttribute("KrathongBank", 0)
		for _, o in ipairs(Shop.Festival) do
			p:SetAttribute("Fest_" .. o.Id, nil)
		end
	end
	ctx.State:SetAttribute("Event_Krathong", spot)
	ctx.FireRun("WorldEvent", "Krathong", { Position = spot, Max = MAX })
	ctx.Broadcast("🌸 Loy Krathong Festival! A big portal opened in the wilds — tonight only", "Good")
	-- ชาวบ้านลอยกระทงเรื่อยๆ + พลุเป็นจังหวะ
	task.spawn(function()
		while self.active do
			for _, d in ipairs(self.docks) do
				if self.active and math.random() < 0.55 then
					self:Launch(d.CF, d.Lane)
				end
			end
			task.wait(math.random(28, 40) / 10)
		end
	end)
	task.spawn(function()
		while self.active do
			task.wait(math.random(30, 70) / 10)
			local fp = self.fireworks[math.random(#self.fireworks)]
			if fp and fp.Parent then
				local col = BULBS[math.random(#BULBS)]
				local fe, fl = fp:FindFirstChildOfClass("ParticleEmitter"), fp:FindFirstChildOfClass("PointLight")
				fe.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
				fl.Color = col
				fe.Enabled, fl.Enabled = true, true
				task.wait(0.12)
				fe.Enabled = false
				task.wait(0.5)
				fl.Enabled = false
			end
		end
	end)
end

function KrathongService:EndEvent(silent)
	if not (self.active or self.gate) then
		return
	end
	self.active = false
	local ctx = self.ctx
	-- คนที่ยังอยู่ในมิติ -> ส่งกลับหน้าประตู
	if self.frame then
		for _, p in ipairs(Players:GetPlayers()) do
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if r and r.Position.Y > REALM_Y - 80 and (r.Position - self.frame.Position).Magnitude < 400 and self.gateFront then
				ctx.Services.PortalService:Teleport(p, self.gateFront + V(0, 3, 0), self.gateFront + V(0, 0, 10), PINK, true)
			end
		end
	end
	task.delay(2, function()
		if self.gate then
			self.gate:Destroy()
			self.gate = nil
		end
		if self.realm then
			self.realm:Destroy()
			self.realm = nil
		end
		if self.region then
			pcall(function()
				Workspace.Terrain:FillBlock(self.region[1] * CF(0, -6, 0), self.region[2], Enum.Material.Air)
			end)
			self.region = nil
		end
		self.floating = {}
	end)
	ctx.State:SetAttribute("Event_Krathong", nil)
	if not silent then
		ctx.Broadcast("🌸 The Loy Krathong Festival has ended", "Info")
	end
end

function KrathongService:Start(ctx)
	local st = ctx.State
	ctx.Remotes.Get("KrathongTrade").OnServerEvent:Connect(function(p, id)
		if type(id) == "string" then
			self:Trade(p, id)
		end
	end)
	st:GetAttributeChangedSignal("Night"):Connect(function()
		local night = st:GetAttribute("Night") or 0
		if not self.done and night >= NIGHT and ctx.Services.DirectorService:IsRunning() then
			self.startNight = night
			self:StartEvent()
		elseif self.active and night > (self.startNight or NIGHT) and st:GetAttribute("Phase") == "Night" then
			self:EndEvent() -- คืนถัดไปมาถึง (ลำดับตั้งค่า Night/Phase สลับกันได้)
		end
	end)
	-- อยู่แค่คืนนั้น + เช้านั้น: คืนถัดไปเริ่ม = ปิดงาน
	st:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = st:GetAttribute("Phase")
		if phase == "Lobby" then
			self:EndEvent(true)
			self.done = false
			for _, p in ipairs(Players:GetPlayers()) do
				p:SetAttribute("Krathongs", nil)
				p:SetAttribute("KrathongBank", nil)
				for _, o in ipairs(Shop.Festival) do
					p:SetAttribute("Fest_" .. o.Id, nil)
				end
			end
		elseif phase == "Night" and self.active and (st:GetAttribute("Night") or 0) > (self.startNight or NIGHT) then
			self:EndEvent()
		end
	end)
end

return KrathongService
