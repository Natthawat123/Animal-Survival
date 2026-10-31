--[[
	SanctumService — วิหารโบราณศักดิ์สิทธิ์ 4 ธาตุ (ธาตุละ 1 แห่ง · พรีแฟบจาก tools/world_art.py -> ServerStorage.WorldArt)
	  ตำแหน่ง: MapLayout.Sanctums (MapGenerator ปรับพื้นให้แล้ว) · client อ่าน GameState "Sanctum_<El>"
	  ปริศนา: เข้าใกล้ -> เสารูน 3 ต้นกะพริบบอกลำดับ -> ปลุกเสา (ProximityPrompt) ให้ถูกลำดับภายใน 30 วินาที
	         ผิด/หมดเวลา = เริ่มใหม่ · สำเร็จ = ประตูผนึกยุบลง + แสงพุ่ง -> หีบศักดิ์สิทธิ์ (ของหายาก) · รอบละครั้ง
	  เปิดหีบ = คนที่ช่วยกัน (ปลุกเสา/ตีผู้พิทักษ์/เปิดหีบ) ได้ออร่าธาตุติดตัวทั้งรอบ (SurvivalService:GiveAura)
	         แล้วประตูมิติข้างนอกปิดผนึก (veil attribute Sealed -> PortalService ไม่วาร์ป) เข้าวิหารนี้ไม่ได้อีกจนจบรอบ
	  กลับล็อบบี้ (Phase = Lobby) = รีเซ็ตทุกวิหาร
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Animals = require(ReplicatedStorage.Shared.Animals)
local PropBuilder = require(ReplicatedStorage.Shared.PropBuilder)
local SiteSpec = require(ReplicatedStorage.Shared.SiteSpec)

local SanctumService = {}

local ELEMENTS = { "Earth", "Water", "Air", "Fire" }
local THAI = { Earth = "ปฐพี", Water = "วารี", Air = "วายุ", Fire = "อัคคี" }
local COLOR = {
	Earth = Color3.fromRGB(120, 245, 90), Water = Color3.fromRGB(70, 210, 255),
	Air = Color3.fromRGB(110, 190, 255), Fire = Color3.fromRGB(255, 110, 30),
}
local ESSENCE = { Earth = "TerraCore", Water = "TidePearl", Air = "GaleFeather", Fire = "EmberShard" }
local HEART = { Earth = "TerraHeart", Water = "TideHeart", Air = "FrostHeart", Fire = "EmberHeart" }
local AURA_TEXT = {
	Earth = "ออร่าปฐพี: เลือดสูงสุด +15%", Water = "ออร่าวารี: หิวช้าลง 15%",
	Air = "ออร่าน้ำแข็ง: สตามิน่าลดช้าลง 15%", Fire = "ออร่าอัคคี: ดาเมจ +15%",
}
local TIME_LIMIT = 30
local SHOW_RANGE = 75 -- ผู้เล่นเข้าใกล้ลานเท่านี้ = เสากะพริบบอกลำดับ
local DIM = 0.22 -- ความสว่างตอนเสาหลับ (สัดส่วนของสีจริง)

local function dim(c, k)
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

local function sound(parent, id, volume, speed, maxDist)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 1
	s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = maxDist or 400
	s.RollOffMinDistance = 20
	s.Parent = parent
	s:Play()
	task.delay(8, function()
		s:Destroy()
	end)
end

local function light(part, color, range, brightness, enabled)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Enabled = enabled ~= false
	l.Parent = part
	return l
end

function SanctumService:Init(ctx)
	self.ctx = ctx
	self.sites = {}
	self.rng = Random.new()
end

---------------------------------------------------------------- สร้าง
function SanctumService:Build(el, sp, src, parent)
	local m = src:Clone()
	local origin = m:FindFirstChild("Origin")
	if not origin then
		m:Destroy()
		return
	end
	m.PrimaryPart = origin
	-- ระดับพื้น = ระดับที่ MapGenerator ปรับเรียบไว้ (ลานพิธีปรับดินซ้ำอีกรอบตอนสร้าง)
	local pos = sp.Position
	-- เกมนี้ไม่ใช้นีออน: ลายรูน/คริสตัล = หินแกะสีตามธาตุ (ไม่เรืองแสง)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			d.Material = Enum.Material.Slate
			local c = d.Color
			d.Color = Color3.new(c.R * 0.8, c.G * 0.8, c.B * 0.8)
		end
	end
	local camp = self.ctx.CampPosition or Vector3.zero
	local flat = Vector3.new(camp.X, pos.Y, camp.Z)
	-- หันทางเข้า (-Z ของพรีแฟบ) ไปทางแคมป์
	local cf = (flat - pos).Magnitude > 1 and CFrame.lookAt(pos, flat) or CFrame.new(pos)
	m:PivotTo(cf)
	-- ประตูมิติบนพื้น -> ห้องในปราสาทบนฟ้า: ปริศนาเสารูน + หีบ อยู่บนพื้นหินเรียบในห้อง (ไม่ลอย/ไม่จม)
	local temple = PropBuilder.BuildRealm(cf, el, m, "วิหาร" .. THAI[el], "เข้าวิหาร", "Sanctum")
	local roomTop = temple:GetAttribute("FloorTop") or PropBuilder.RealmY + 0.5
	-- กรอบในห้อง: แนวเดียวกับประตูข้างนอก (-Z = ฝั่งที่คนเข้ามา)
	cf = CFrame.new(cf.Position.X, roomTop, cf.Position.Z) * (cf - cf.Position)
	if temple then
		-- ทิ้งฉากหินปั้นเดิมทั้งหมด เหลือเฉพาะชิ้นที่ใช้เล่น (เสารูน 3 ต้น, หีบ, ช่องรูน, คริสตัล, ลำแสง)
		local KEEP = {
			Origin = true, Obelisk1 = true, Obelisk2 = true, Obelisk3 = true, VaultChest = true, ChestLid = true,
			AltarCrystal = true, Beacon = true, VaultLight = true, HintSlot1 = true, HintSlot2 = true, HintSlot3 = true,
		}
		for _, ch in ipairs(m:GetChildren()) do
			if ch ~= temple and not KEEP[ch.Name] and ch.Name ~= "PortalOut" then
				ch:Destroy()
			end
		end
		m.Parent = parent
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { workspace.Terrain, temple }
		local function bottomOf(o)
			if o:IsA("Model") then
				local bcf, size = o:GetBoundingBox()
				return bcf.Position, bcf.Position.Y - size.Y / 2
			end
			return o.Position, o.Position.Y - o.Size.Y / 2
		end
		-- ย้ายกลุ่มชิ้นทั้งหมดตาม delta เดียวกัน แล้ววางลงบนพื้นจริง (ไม่ลอย)
		local function place(group, target)
			local p0, b0 = bottomOf(group[1])
			local flatTarget = target or p0
			local dy
			if target and target.Y then
				dy = target.Y - b0 -- จุดบนลานของวิหาร (รู้ความสูงพื้นแล้ว)
			else
				local hit = workspace:Raycast(Vector3.new(flatTarget.X, b0 + 60, flatTarget.Z), Vector3.new(0, -160, 0), rp)
				dy = hit and (hit.Position.Y - b0) or 0
			end
			local delta = Vector3.new(flatTarget.X - p0.X, dy, flatTarget.Z - p0.Z)
			for _, o in ipairs(group) do
				if o:IsA("Model") then
					o:PivotTo(o:GetPivot() + delta)
				else
					o.CFrame += delta
				end
			end
		end
		-- หีบศักดิ์สิทธิ์ตั้งหน้าประตูวิหาร (ลานปริศนาอยู่ฝั่งแคมป์)
		local chestGroup = {}
		for _, n in ipairs({ "VaultChest", "ChestLid", "VaultLight", "Beacon" }) do
			local o = m:FindFirstChild(n)
			if o then
				table.insert(chestGroup, o)
			end
		end
		-- เสารูนใหญ่ขึ้น (เห็นชัดบนวิหารใหญ่)
		for i = 1, 3 do
			local o = m:FindFirstChild("Obelisk" .. i)
			if o then
				pcall(function()
					o:ScaleTo(o:GetScale() * 1.6)
				end)
			end
		end
		-- ลานพิธีหินกลมบนพื้นหน้าวิหาร: เสารูน 3 ต้นเป็นสามเหลี่ยมฝั่งแคมป์ · หีบกลางลานฝั่งวิหาร · ช่องรูนหน้าหีบ · คริสตัลหลังหีบ
		--   (เดิมวางบนหลังคา/ชั้นบนของโมเดล Store + สร้างบันไดเอง -> ลอย/ขึ้นไม่ได้)
		local plazaTop = roomTop
		local function at(x, z)
			local w = (cf * CFrame.new(x, 0, z)).Position
			return Vector3.new(w.X, plazaTop, w.Z)
		end
		if #chestGroup > 0 then
			place(chestGroup, at(0, 12))
		end
		local OB = { { -17, -8 }, { 17, -8 }, { 0, -21 } }
		for i = 1, 3 do
			local o = m:FindFirstChild("Obelisk" .. i)
			if o then
				place({ o }, at(OB[i][1], OB[i][2]))
				-- ตัวเสา = หินรูนจาก Creator Store (RuneStoneLP) ตั้งบนแท่นฐาน (Activator) ของพรีแฟบ
				--   ชิ้นปั้นเดิมซ่อนไว้ (ยังใช้เป็นจุดกด/ป้ายลำดับ) · ตอนติดสว่าง = Highlight ทั้งก้อน (SetObelisk)
				local ocf, osz = o:GetBoundingBox()
				local bottom = ocf.Position.Y - osz.Y / 2
				local foot = Vector3.new(ocf.Position.X, plazaTop + 0.9, ocf.Position.Z)
				local vis = PropBuilder.Imported("RuneStoneLP", CFrame.lookAt(foot, Vector3.new(cf.Position.X, foot.Y, cf.Position.Z)), 8, o, true) -- กว้าง 8 = สูง ~10 (กล่องรอบเสาเดิมสูงผิดปกติ เคยได้หินยักษ์บังลาน)
				if vis then
					vis.Name = "StoneVisual"
					for _, d in ipairs(o:GetDescendants()) do
						if d:IsA("BasePart") and not d:IsDescendantOf(vis) and d.Name ~= "Activator" then
							d.Transparency = 1
							d.CanCollide = false
						end
					end
				end
			end
		end
		for i, n in ipairs({ "AltarCrystal", "HintSlot1", "HintSlot2", "HintSlot3" }) do
			local o = m:FindFirstChild(n)
			if o then
				place({ o }, i == 1 and at(0, 22) or at((i - 3) * 6, 3))
			end
		end
		pos = Vector3.new(cf.Position.X, plazaTop, cf.Position.Z) -- จุดศูนย์กลางกิจกรรม = กลางลานพิธี
	end
	pcall(function()
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	m:SetAttribute("Element", el)
	local col = COLOR[el]
	local site = {
		Element = el, Model = m, Center = pos, State = "Idle", Progress = 0, NextShow = 0,
		Obelisks = {}, Hints = {}, Door = {}, Lid = {}, Helpers = {},
	}
	-- ไฟ/อนุภาคประกอบฉาก
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name == "Brazier" then
				local f = Instance.new("Fire")
				f.Size = 4
				f.Heat = 6
				f.Color = el == "Fire" and Color3.fromRGB(255, 140, 40) or col
				f.SecondaryColor = dim(col, 0.6)
				f.Parent = d
				light(d, col, 24, 1.6)
			elseif d.Name == "CaveGlow" then
				light(d, col, 32, 2.2)
			elseif d.Name == "AltarCrystal" then
				light(d, col, 26, 1.8)
				site.AltarCrystal = d
			elseif d.Name == "Mist" then
				local mist = Instance.new("ParticleEmitter")
				mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
				mist.Rate = 3
				mist.Lifetime = NumberRange.new(5, 8)
				mist.Speed = NumberRange.new(0.6, 1.4)
				mist.SpreadAngle = Vector2.new(180, 10)
				mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 16) })
				mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.82), NumberSequenceKeypoint.new(1, 1) })
				mist.Color = ColorSequence.new(col)
				mist.LightEmission = 0.3
				mist.Parent = d
			elseif d.Name == "VaultLight" then
				site.VaultLight = light(d, col, 34, 4, false)
			elseif d.Name == "Beacon" then
				site.Beacon = d
			elseif d.Name:match("^HintSlot%d$") then
				local i = tonumber(d.Name:sub(-1))
				site.Hints[i] = { Part = d, Color = col }
			end
		end
	end
	-- เสารูน
	for i = 1, 3 do
		local ob = m:FindFirstChild("Obelisk" .. i)
		if ob then
			-- ขอบเรืองสีธาตุ + ลำแสงขึ้นฟ้า: มองเห็นเสาได้จากไกล/ในหมอก
			local hl = Instance.new("Highlight")
			hl.FillTransparency = 0.85
			hl.FillColor = col
			hl.OutlineColor = col
			hl.OutlineTransparency = 0
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Parent = ob
			local base = ob:GetPivot().Position
			local _, osz = ob:GetBoundingBox()
			local a0 = Instance.new("Attachment")
			local anchorPart = ob:FindFirstChildWhichIsA("BasePart", true)
			if anchorPart then
				a0.WorldPosition = base + Vector3.new(0, osz.Y * 0.5, 0)
				a0.Parent = anchorPart
				local skyPart = Instance.new("Part")
				skyPart.Anchored, skyPart.CanCollide, skyPart.CanQuery, skyPart.Transparency = true, false, false, 1
				skyPart.Size = Vector3.one
				skyPart.CFrame = CFrame.new(base + Vector3.new(0, 140, 0))
				skyPart.Parent = ob
				local a1 = Instance.new("Attachment")
				a1.Parent = skyPart
				local beam = Instance.new("Beam")
				beam.Attachment0, beam.Attachment1 = a0, a1
				beam.Width0, beam.Width1 = 2.2, 4
				beam.LightEmission = 1
				beam.FaceCamera = true
				beam.Color = ColorSequence.new(col)
				beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
				beam.Parent = anchorPart
			end
			local o = { Index = i, Model = ob, Glow = {}, Lit = false }
			for _, d in ipairs(ob:GetDescendants()) do
				if d:IsA("BasePart") and (d.Name == "Glyph" or d.Name == "Crystal") then
					table.insert(o.Glow, { Part = d, Color = d.Color })
				elseif d.Name == "Activator" then
					o.Activator = d
				elseif d.Name == "Top" then
					o.Top = d
				end
			end
			if o.Activator then
				o.Light = light(o.Activator, col, 22, 2.5, false)
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "Wake"
				prompt.ActionText = "ปลุกเสารูน"
				prompt.ObjectText = "เสารูนโบราณ"
				prompt.HoldDuration = 0.4
				prompt.MaxActivationDistance = 13
				prompt.RequiresLineOfSight = false
				prompt.Parent = o.Activator
				prompt.Triggered:Connect(function(player)
					self:Activate(site, i, player)
				end)
				o.Prompt = prompt
			end
			if o.Top then
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.fromOffset(90, 90)
				bb.AlwaysOnTop = true
				bb.MaxDistance = 220
				bb.Enabled = false
				bb.Parent = o.Top
				local t = Instance.new("TextLabel")
				t.Size = UDim2.fromScale(1, 1)
				t.BackgroundTransparency = 1
				t.Font = Enum.Font.FredokaOne
				t.TextScaled = true
				t.TextColor3 = Color3.new(1, 1, 1)
				t.TextStrokeColor3 = dim(col, 0.4)
				t.TextStrokeTransparency = 0
				t.Text = ""
				t.Parent = bb
				o.Billboard, o.Label = bb, t
			end
			site.Obelisks[i] = o
		end
	end
	-- ประตูผนึก + หีบ
	local door = m:FindFirstChild("VaultDoor")
	if door then
		local maxY, minY = -math.huge, math.huge
		for _, d in ipairs(door:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(site.Door, { Part = d, CFrame = d.CFrame })
				maxY = math.max(maxY, d.Position.Y + d.Size.Y / 2)
				minY = math.min(minY, d.Position.Y - d.Size.Y / 2)
			end
		end
		site.DoorDrop = math.max(4, maxY - minY + 0.6)
		local slab = door:FindFirstChild("DoorSlab")
		site.DoorPos = slab and slab.Position or pos
	end
	local lid = m:FindFirstChild("ChestLid")
	if lid then
		for _, d in ipairs(lid:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(site.Lid, { Part = d, CFrame = d.CFrame })
			end
		end
		local lb = lid:FindFirstChild("LidBody")
		if lb then
			site.LidHinge = lb.CFrame * CFrame.new(0, -lb.Size.Y / 2, lb.Size.Z / 2)
		end
	end
	local chest = m:FindFirstChild("VaultChest")
	local body = chest and chest:FindFirstChild("ChestBody")
	if body then
		site.ChestBody = body
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "OpenVault"
		prompt.ActionText = "เปิดหีบศักดิ์สิทธิ์"
		prompt.ObjectText = "หีบแห่งวิหาร" .. THAI[el]
		prompt.HoldDuration = 1.2
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = body
		prompt.Triggered:Connect(function(player)
			self:OpenChest(site, player)
		end)
		site.ChestPrompt = prompt
	end
	m.Parent = parent
	self:ResetSite(site)
	self.sites[el] = site
end

---------------------------------------------------------------- สถานะเสา/ช่องรูน
function SanctumService:SetObelisk(o, mode)
	-- mode: "Dim" | "Flash" | "Lit" | "Fail"
	-- ทั้งก้อนหินรูนเรืองตามสถานะ (Highlight ที่ใส่ตอนสร้าง)
	local hl = o.Model and o.Model:FindFirstChildOfClass("Highlight")
	if hl then
		local col = o.Glow[1] and o.Glow[1].Color or hl.OutlineColor
		local fill = (mode == "Dim" and 0.92) or (mode == "Flash" and 0.25) or 0.45
		hl.FillColor = mode == "Fail" and Color3.fromRGB(255, 50, 40) or col
		hl.OutlineColor = hl.FillColor
		TweenService:Create(hl, TweenInfo.new(mode == "Flash" and 0.15 or 0.35), { FillTransparency = fill, OutlineTransparency = mode == "Dim" and 0.4 or 0 }):Play()
	end
	for _, g in ipairs(o.Glow) do
		if g.Part.Parent then
			local target = g.Color
			if mode == "Dim" then
				target = dim(g.Color, DIM)
			elseif mode == "Fail" then
				target = Color3.fromRGB(255, 50, 40)
			end
			TweenService:Create(g.Part, TweenInfo.new(mode == "Flash" and 0.15 or 0.35), { Color = target }):Play()
		end
	end
	if o.Light then
		o.Light.Enabled = mode ~= "Dim"
		o.Light.Color = mode == "Fail" and Color3.fromRGB(255, 50, 40) or o.Glow[1] and o.Glow[1].Color or o.Light.Color
		o.Light.Brightness = mode == "Flash" and 5 or 2.5
	end
end

function SanctumService:SetHints(site, n)
	for i, h in pairs(site.Hints) do
		if h.Part.Parent then
			h.Part.Color = i <= n and h.Color or dim(h.Color, 0.15)
		end
	end
end

function SanctumService:NearbyPlayers(site, radius)
	local out = {}
	local surv = self.ctx.Services.SurvivalService
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c and p:GetAttribute("InRun") and surv:IsAlive(p) and (c:GetPivot().Position - site.Center).Magnitude < radius then
			table.insert(out, p)
		end
	end
	return out
end

function SanctumService:Tell(site, text, kind, radius)
	for _, p in ipairs(self:NearbyPlayers(site, radius or 160)) do
		self.ctx.Notify(p, text, kind)
	end
end

---------------------------------------------------------------- ปริศนา
function SanctumService:ShowSequence(site)
	site.State = "Showing"
	site.ShowId = (site.ShowId or 0) + 1
	local showId = site.ShowId
	task.spawn(function()
		for _, o in pairs(site.Obelisks) do
			self:SetObelisk(o, "Dim")
		end
		task.wait(0.6)
		for step, idx in ipairs(site.Order) do
			if site.ShowId ~= showId or site.State ~= "Showing" then
				return
			end
			local o = site.Obelisks[idx]
			if o then
				self:SetObelisk(o, "Flash")
				if o.Billboard then
					o.Label.Text = tostring(step)
					o.Billboard.Enabled = true
				end
				if o.Activator then
					sound(o.Activator, "rbxasset://sounds/volume_slider.ogg", 0.8, 0.7 + step * 0.15, 180)
				end
				task.wait(1.1)
				self:SetObelisk(o, "Dim")
				if o.Billboard then
					o.Billboard.Enabled = false
				end
				task.wait(0.4)
			end
		end
		if site.ShowId == showId and site.State == "Showing" then
			site.State = "Ready"
			site.NextShow = os.clock() + 16
		end
	end)
end

function SanctumService:SpawnGuardians(site)
	if site.GuardiansSpawned then
		return
	end
	site.GuardiansSpawned = true
	local pool = Animals.RaidPool[site.Element]
	if not pool then
		return
	end
	local animals = self.ctx.Services.AnimalService
	local layout = self.ctx.Layout
	for i = 1, 2 do
		local ang = self.rng:NextNumber(0, math.pi * 2)
		local p = site.Center + Vector3.new(math.cos(ang) * 34, 0, math.sin(ang) * 34)
		local h = layout:HeightAt(p.X, p.Z)
		local g = animals:Spawn(pool[self.rng:NextInteger(1, #pool)], Vector3.new(p.X, math.max(h, site.Center.Y) + 3, p.Z), {
			Kind = "Guardian", Home = site.Center, Leash = 60, HealthMult = 1.4, DamageMult = 1.1, Yaw = ang + i,
		})
		if g then
			g.OnHurt = function(attacker)
				if typeof(attacker) == "Instance" and attacker:IsA("Player") then
					site.Helpers[attacker] = true
				end
			end
		end
	end
end

function SanctumService:Activate(site, idx, player)
	if site.State == "Solved" then
		return
	end
	if not player:GetAttribute("InRun") or self.ctx.Services.SurvivalService:IsIncapacitated(player) then
		return
	end
	local o = site.Obelisks[idx]
	if not o or o.Lit then
		return
	end
	site.Helpers[player] = true
	if site.State == "Showing" or site.State == "Failing" then
		self.ctx.Notify(player, "👁 รอให้เสารูนกะพริบบอกลำดับให้ครบก่อน", "Info")
		return
	end
	if site.State ~= "Input" then
		site.State = "Input"
		site.Progress = 0
		site.Deadline = os.clock() + TIME_LIMIT
		self.ctx.State:SetAttribute("Sanctum" .. site.Element .. "Deadline", Workspace:GetServerTimeNow() + TIME_LIMIT)
		self:Tell(site, string.format("⏳ วิหาร%sตื่นแล้ว! ปลุกเสารูนให้ครบตามลำดับภายใน %d วินาที", THAI[site.Element], TIME_LIMIT), "Warn")
		self:SpawnGuardians(site)
	end
	if site.Order[site.Progress + 1] == idx then
		site.Progress += 1
		o.Lit = true
		self:SetObelisk(o, "Lit")
		self:SetHints(site, site.Progress)
		if o.Activator then
			sound(o.Activator, "rbxasset://sounds/volume_slider.ogg", 1, 0.9 + site.Progress * 0.2, 220)
		end
		if site.Progress >= #site.Order then
			self:Solve(site, player)
		else
			self:Tell(site, string.format("✨ เสารูนต้นที่ %d/%d ตื่นแล้ว", site.Progress, #site.Order), "Good", 120)
		end
	else
		self:Fail(site, "❌ ลำดับผิด! พลังผนึกดีดกลับ — ดูแสงกะพริบอีกครั้ง")
	end
end

function SanctumService:Fail(site, text)
	site.State = "Failing"
	site.Progress = 0
	self.ctx.State:SetAttribute("Sanctum" .. site.Element .. "Deadline", nil)
	self:Tell(site, text, "Error")
	for _, o in pairs(site.Obelisks) do
		o.Lit = false
		self:SetObelisk(o, "Fail")
		if o.Activator then
			sound(o.Activator, "rbxasset://sounds/volume_slider.ogg", 0.8, 0.45, 160)
		end
	end
	self:SetHints(site, 0)
	task.delay(1.2, function()
		if site.State == "Failing" then
			for _, o in pairs(site.Obelisks) do
				self:SetObelisk(o, "Dim")
			end
			site.State = "Idle"
			site.NextShow = os.clock() + 2
		end
	end)
end

function SanctumService:Solve(site, player)
	site.State = "Solved"
	local el = site.Element
	local col = COLOR[el]
	self.ctx.State:SetAttribute("Sanctum" .. el .. "Deadline", nil)
	self.ctx.State:SetAttribute("Sanctum" .. el .. "Solved", true)
	for _, o in pairs(site.Obelisks) do
		if o.Prompt then
			o.Prompt.Enabled = false
		end
	end
	-- ประตูผนึกยุบลงพื้น
	local info = TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	for _, d in ipairs(site.Door) do
		TweenService:Create(d.Part, info, { CFrame = d.CFrame - Vector3.new(0, site.DoorDrop, 0) }):Play()
	end
	local doorPos = site.DoorPos or site.Center
	local anchor = Instance.new("Part")
	anchor.Name = "VaultFx"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = doorPos
	anchor.Parent = site.Model
	site.Fx = { anchor }
	sound(anchor, "rbxasset://sounds/impact_explosion_03.mp3", 1.2, 0.5, 600)
	sound(anchor, "rbxasset://sounds/action_jump_land.mp3", 1.5, 0.35, 300)
	-- แสงพุ่ง: ลูกแสงขยาย + ไฟในห้อง + ลำแสงจากยอดวิหารขึ้นฟ้า
	local burst = Instance.new("Part")
	burst.Shape = Enum.PartType.Ball
	burst.Material = Enum.Material.SmoothPlastic
	burst.Color = col
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.Size = Vector3.new(2, 2, 2)
	burst.Position = doorPos
	burst.Parent = site.Model
	TweenService:Create(burst, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(44, 44, 44), Transparency = 1 }):Play()
	task.delay(1.8, function()
		burst:Destroy()
	end)
	local flash = light(anchor, col, 60, 0)
	TweenService:Create(flash, TweenInfo.new(0.4), { Brightness = 10 }):Play()
	task.delay(0.5, function()
		if flash.Parent then
			TweenService:Create(flash, TweenInfo.new(3), { Brightness = 0 }):Play()
		end
	end)
	if site.VaultLight then
		site.VaultLight.Enabled = true
	end
	if site.Beacon then
		local a0 = Instance.new("Attachment")
		a0.Parent = site.Beacon
		local top = Instance.new("Part")
		top.Name = "BeamTop"
		top.Anchored = true
		top.CanCollide = false
		top.CanQuery = false
		top.Transparency = 1
		top.Size = Vector3.new(1, 1, 1)
		top.Position = site.Beacon.Position + Vector3.new(0, 420, 0)
		top.Parent = site.Model
		local a1 = Instance.new("Attachment")
		a1.Parent = top
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 6
		beam.Width1 = 16
		beam.LightEmission = 1
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(col)
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
		beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		beam.TextureSpeed = 0.6
		beam.Parent = site.Beacon
		table.insert(site.Fx, a0)
		table.insert(site.Fx, top)
		table.insert(site.Fx, beam)
	end
	self.ctx.FireRun("WorldEvent", "SanctumOpened", { Element = el, Position = doorPos, By = player and player.DisplayName })
	task.delay(3.5, function()
		if site.State == "Solved" and not site.Opened and site.ChestPrompt then
			site.ChestPrompt.Enabled = true
		end
	end)
end

function SanctumService:OpenChest(site, player)
	if site.Opened or site.State ~= "Solved" or not player:GetAttribute("InRun") then
		return
	end
	site.Opened = true
	if site.ChestPrompt then
		site.ChestPrompt.Enabled = false
	end
	local el = site.Element
	local ctx = self.ctx
	local rng = self.rng
	-- ฝาหีบพลิกเปิดรอบบานพับด้านหลัง (+Z ของหีบ)
	local hinge = site.LidHinge
	if hinge then
		local rot = hinge * CFrame.Angles(math.rad(80), 0, 0) * hinge:Inverse()
		for _, d in ipairs(site.Lid) do
			TweenService:Create(d.Part, TweenInfo.new(0.8, Enum.EasingStyle.Back), { CFrame = rot * d.CFrame }):Play()
		end
	end
	local pos = (site.ChestBody and site.ChestBody.Position or site.Center) + Vector3.new(0, 1.5, 0)
	local drops = ctx.Services.DropService
	local got = {}
	local function give(id, n)
		if n > 0 then
			n = drops:SpawnLoot(id, n, pos, { Spread = 3.5 })
			got[id] = (got[id] or 0) + n
		end
	end
	give(ESSENCE[el], rng:NextInteger(4, 6))
	for _, other in ipairs(ELEMENTS) do
		if other ~= el and rng:NextNumber() < 0.3 then
			give(ESSENCE[other], 1)
		end
	end
	give("Iron", rng:NextInteger(3, 5))
	give("Medkit", 1)
	if rng:NextNumber() < 0.2 then
		give(HEART[el], 1)
	end
	-- ออร่าธาตุ: เฉพาะคนที่ช่วยกัน (ปลุกเสา / ตีผู้พิทักษ์ / คนเปิดหีบ) ที่ยังอยู่ในรอบ
	site.Helpers[player] = true
	local surv = ctx.Services.SurvivalService
	for p in pairs(site.Helpers) do
		if p.Parent and p:GetAttribute("InRun") and surv:GiveAura(p, el) then
			ctx.Notify(p, "✨ ได้รับ" .. AURA_TEXT[el] .. " (ติดตัวทั้งรอบ)", "Reward")
		end
	end
	ctx.Broadcast(string.format("เคลียร์วิหาร%s · ได้%s", THAI[el], AURA_TEXT[el]), "Reward")
	for _, p in ipairs(self:NearbyPlayers(site, 70)) do
		ctx.Services.DataService:AddDiamonds(p, rng:NextInteger(5, 8), "วิหารโบราณ" .. THAI[el])
	end
	task.spawn(self.SealAfterClear, self, site)
	ctx.Remotes.Get("HitFx"):FireClient(player, "Loot", { Items = got, Position = pos, Chest = true })
	if site.ChestBody then
		sound(site.ChestBody, "rbxasset://sounds/volume_slider.ogg", 1, 1.6, 200)
	end
end

-- เคลียร์แล้ว: ปิดประตูมิติข้างนอก (เข้าวิหารนี้ไม่ได้อีกจนจบรอบ) · คนที่ยังอยู่ในห้องออกทางประตูกลับได้ตามปกติ
function SanctumService:PortalVeil(site)
	local out = site.Model and site.Model:FindFirstChild("PortalOut", true)
	if not out then
		return nil
	end
	for _, d in ipairs(out:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			return d.Parent, d
		end
	end
end

function SanctumService:SealPortal(site)
	local veil, prompt = self:PortalVeil(site)
	if veil then
		veil:SetAttribute("Sealed", true)
		site.PortalAction = site.PortalAction or prompt.ActionText
		prompt.ActionText = "ปิดผนึกแล้ว"
	end
end

-- เก็บ/คืนสถานะ (RejoinService): วิหารที่เปิดหีบแล้ว ต้องยังปิดผนึกในเซิร์ฟเวอร์ใหม่ของรอบเดิม
function SanctumService:Serialize()
	local out = {}
	for el, site in pairs(self.sites) do
		if site.Opened then
			out[el] = true
		end
	end
	return out
end

function SanctumService:Restore(st)
	for el in pairs(type(st) == "table" and st or {}) do
		local site = self.sites[el]
		if site then
			site.State = "Solved"
			site.Opened = true
			self.ctx.State:SetAttribute("Sanctum" .. el .. "Solved", true)
			for _, o in pairs(site.Obelisks) do
				if o.Prompt then
					o.Prompt.Enabled = false
				end
			end
			self:SealPortal(site)
		end
	end
end

function SanctumService:SealAfterClear(site)
	task.wait(3)
	if not site.Opened then
		return
	end
	self:SealPortal(site)
	self.ctx.Broadcast(string.format("วิหาร%sปิดผนึกแล้ว", THAI[site.Element]), "Info")
end

---------------------------------------------------------------- รีเซ็ต (รอบใหม่)
function SanctumService:ResetSite(site)
	site.State = "Idle"
	site.Helpers = {}
	local veil, prompt = self:PortalVeil(site)
	if veil then
		veil:SetAttribute("Sealed", nil)
		if site.PortalAction then
			prompt.ActionText = site.PortalAction
		end
	end
	site.Progress = 0
	site.Opened = false
	site.GuardiansSpawned = false
	site.NextShow = 0
	site.ShowId = (site.ShowId or 0) + 1
	local order = { 1, 2, 3 }
	for i = #order, 2, -1 do
		local j = self.rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	site.Order = order
	for _, o in pairs(site.Obelisks) do
		o.Lit = false
		self:SetObelisk(o, "Dim")
		if o.Prompt then
			o.Prompt.Enabled = true
		end
		if o.Billboard then
			o.Billboard.Enabled = false
		end
	end
	self:SetHints(site, 0)
	for _, d in ipairs(site.Door) do
		d.Part.CFrame = d.CFrame
	end
	for _, d in ipairs(site.Lid) do
		d.Part.CFrame = d.CFrame
	end
	if site.ChestPrompt then
		site.ChestPrompt.Enabled = false
	end
	if site.VaultLight then
		site.VaultLight.Enabled = false
	end
	for _, f in ipairs(site.Fx or {}) do
		if f.Parent then
			f:Destroy()
		end
	end
	site.Fx = {}
	local st = self.ctx.State
	st:SetAttribute("Sanctum" .. site.Element .. "Solved", false)
	st:SetAttribute("Sanctum" .. site.Element .. "Deadline", nil)
end

function SanctumService:Reset()
	for _, site in pairs(self.sites) do
		self:ResetSite(site)
	end
end

---------------------------------------------------------------- ลูป
function SanctumService:Tick()
	local now = os.clock()
	for _, site in pairs(self.sites) do
		if site.State == "Input" and now > (site.Deadline or 0) then
			self:Fail(site, "⌛ หมดเวลา! เสารูนกลับไปหลับ — ดูลำดับใหม่อีกครั้ง")
		elseif (site.State == "Idle" or site.State == "Ready") and now >= site.NextShow then
			if #self:NearbyPlayers(site, SHOW_RANGE) > 0 then
				if not site.Announced then
					site.Announced = true
					self:Tell(site, "👁 จดจำลำดับเสารูนที่กะพริบ แล้วปลุกให้ถูกลำดับ!", "Info", SHOW_RANGE + 20)
				end
				self:ShowSequence(site)
			end
		end
	end
end

function SanctumService:Start(ctx)
	local layout = ctx.Layout
	local sanctums = layout and layout.Sanctums
	if not sanctums then
		return
	end
	local art = ServerStorage:FindFirstChild("WorldArt")
	local world = Workspace:FindFirstChild("World")
	local folder = Instance.new("Folder")
	folder.Name = "Sanctums"
	folder.Parent = world or Workspace
	for _, el in ipairs(ELEMENTS) do
		local sp = sanctums[el]
		if sp then
			ctx.State:SetAttribute("Sanctum_" .. el, sp.Position)
			local src = art and art:FindFirstChild("Sanctum_" .. el)
			if src then
				local ok, err = pcall(self.Build, self, el, sp, src, folder)
				if not ok then
					warn("[AS] sanctum " .. el .. ":", err)
				end
			end
		end
	end
	ctx.State:GetAttributeChangedSignal("Phase"):Connect(function()
		if ctx.State:GetAttribute("Phase") == "Lobby" then
			self:Reset()
			for _, site in pairs(self.sites) do
				site.Announced = false
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(self.Tick, self)
			if not ok then
				warn("[AS] sanctum tick", err)
			end
		end
	end)
end

return SanctumService
