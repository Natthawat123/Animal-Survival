--[[
	EventService — เหตุการณ์สุ่มช่วงกลางวัน (0-2 ครั้งต่อวัน · วันแรกได้อย่างมาก 1 หลังผ่านไปสักพัก)
	  Meteor    "อุกกาบาตธาตุตก"  : ลูกไฟพุ่งลงจากฟ้า (client วาด) -> หลุมอุกกาบาต + แกนผลึก มีสัตว์ธาตุเฝ้า
	                                 ขุดแกน = แก่นธาตุคนละ 2-3 + Ruby 2-5 ให้ทุกคนที่อยู่ใกล้ + ลุ้นหัวใจอสูรธาตุนั้น 22%
	  Migration "ฝูงสัตว์อพยพ"      : ฝูงกวาง/กระต่ายเดินผ่านแถวแคมป์ (ล่าได้ ได้หนังเพิ่ม)
	  Supply    "เสบียงตกจากฟ้า"    : หีบร่มชูชีพร่อนลง ควันสีแดงพวยพุ่ง -> เปิดได้อาหาร/ยา/วัตถุดิบ
	ทุกอย่างหายไปเองตอนพลบค่ำ / กลับล็อบบี้ / จบเกม · ไม่ทำงานในล็อบบี้ · client: WorldEventsClient (Remotes "WorldEvent")
	GameState: Event_Meteor / Event_Migration / Event_Supply = ตำแหน่ง (หมุดบนแผนที่) · Event_MeteorElement
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Animals = require(ReplicatedStorage.Shared.Animals)
local Items = require(ReplicatedStorage.Shared.Items)
local Nights = require(ReplicatedStorage.Shared.Nights)

local EventService = {}

local ELEMENTS = { "Earth", "Water", "Air", "Fire" }
local THAI = { Earth = "ปฐพี", Water = "วารี", Air = "วายุ", Fire = "อัคคี" }
local COLOR = {
	Earth = Color3.fromRGB(120, 245, 90), Water = Color3.fromRGB(70, 210, 255),
	Air = Color3.fromRGB(150, 210, 255), Fire = Color3.fromRGB(255, 110, 30),
}
local ESSENCE = { Earth = "TerraCore", Water = "TidePearl", Air = "GaleFeather", Fire = "EmberShard" }
local WEIGHTS = { { "Meteor", 45 }, { "Migration", 30 }, { "Supply", 25 } }
local METEOR_FALL = 13 -- วินาทีจากประกาศถึงตกกระทบ

local V = Vector3.new
local CF = CFrame.new

local function P(parent, props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in pairs(props) do
		p[k] = v
	end
	if p.Material == Enum.Material.Neon then
		p.Material = Enum.Material.SmoothPlastic -- เกมนี้ไม่ใช้นีออน
	end
	p.Parent = parent
	return p
end

-- ความสูงพื้นจริง (ยิง ray ลง Terrain) — HeightAt เป็นค่าประมาณ ผิว Terrain จริงอาจสูงกว่า ทำให้ของจมดิน
local function groundY(x, z, fallback)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, (fallback or 0) + 120, z), Vector3.new(0, -400, 0), rp)
	return hit and hit.Position.Y or fallback
end

local function light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = part
	return l
end

function EventService:Init(ctx)
	self.ctx = ctx
	self.rng = Random.new()
	self.token = 0
	self.active = {} -- [kind] = { Cleanup = fn }
end

---------------------------------------------------------------- ตัวช่วย
function EventService:RunPlayers()
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InRun") and not p:GetAttribute("Dead") then
			table.insert(out, p)
		end
	end
	return out
end

function EventService:Valid(token)
	local ctx = self.ctx
	return token == self.token
		and ctx.State:GetAttribute("Phase") == "Day"
		and ctx.Services.DirectorService:IsRunning()
		and ctx.Layout ~= nil
		and Workspace:FindFirstChild("World") ~= nil
		and #self:RunPlayers() > 0
end

function EventService:Folder()
	local world = Workspace:FindFirstChild("World")
	local f = world and world:FindFirstChild("Events")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Events"
		f.Parent = world or Workspace
	end
	return f
end

-- จุดบนบกที่ค่อนข้างราบ ห่างจุดพิเศษ/แคมป์
function EventService:FindSpot(minR, maxR, clearance)
	local layout = self.ctx.Layout
	local maxD = layout.Half - layout.EdgeOcean - 120
	for _ = 1, 50 do
		local ang = self.rng:NextNumber(0, math.pi * 2)
		local d = math.min(self.rng:NextNumber(minR, maxR), maxD)
		local x, z = math.cos(ang) * d, math.sin(ang) * d
		local h, biome, lava, main = layout:HeightAt(x, z)
		if h > layout.WaterLevel + 3 and not lava and h < 300 then
			local ok = true
			for _, o in ipairs({ { 9, 0 }, { -9, 0 }, { 0, 9 }, { 0, -9 } }) do
				local hh, _, ll = layout:HeightAt(x + o[1], z + o[2])
				if ll or math.abs(hh - h) > 6 or hh < layout.WaterLevel + 1 then
					ok = false
					break
				end
			end
			if ok then
				for _, sp in ipairs(layout.Specials) do
					local need = (sp.Radius or (sp.Kind == "Lair" and 100 or 45)) + clearance
					if (Vector3.new(sp.Position.X - x, 0, sp.Position.Z - z)).Magnitude < need then
						ok = false
						break
					end
				end
			end
			if ok then
				return Vector3.new(x, groundY(x, z, h), z), (biome ~= "Heart") and biome or main
			end
		end
	end
	return nil
end

function EventService:Register(kind, cleanup)
	self:Cleanup(kind)
	self.active[kind] = { Cleanup = cleanup }
end

function EventService:Cleanup(kind)
	local e = self.active[kind]
	if e then
		self.active[kind] = nil
		local ok, err = pcall(e.Cleanup)
		if not ok then
			warn("[AS] event cleanup " .. kind, err)
		end
	end
	self.ctx.State:SetAttribute("Event_" .. kind, nil)
end

function EventService:CleanupAll()
	for _, w in ipairs(WEIGHTS) do
		self:Cleanup(w[1])
	end
	self.ctx.State:SetAttribute("Event_MeteorElement", nil)
end

---------------------------------------------------------------- ตารางเหตุการณ์ของวัน
function EventService:PlanDay(token)
	local s = self.ctx.State
	local night = s:GetAttribute("Night") or 1
	local now = Workspace:GetServerTimeNow()
	local dayLeft = (s:GetAttribute("PhaseEnd") or now) - now
	local rng = self.rng
	local delays = {}
	if night <= 1 then
		-- วันแรก: ให้ตั้งตัวก่อน (อย่างน้อย ~2.5 นาที) แล้วค่อยมีได้ 1 เหตุการณ์
		if rng:NextNumber() < 0.75 then
			table.insert(delays, rng:NextNumber(150, 190))
		end
	else
		local r = rng:NextNumber()
		local count = (r < 0.2 and 0) or (r < 0.7 and 1) or 2
		local t = rng:NextNumber(20, 60)
		for _ = 1, count do
			table.insert(delays, t)
			t += rng:NextNumber(75, 115)
		end
	end
	local used = {}
	for _, delay in ipairs(delays) do
		if delay + 50 < dayLeft then
			local kind = self:PickKind(used)
			used[kind] = true
			task.delay(delay, function()
				if self:Valid(token) then
					local ok, err = pcall(self.Run, self, kind, token)
					if not ok then
						warn("[AS] event " .. kind, err)
					end
				end
			end)
		end
	end
end

function EventService:PickKind(used)
	local total = 0
	for _, w in ipairs(WEIGHTS) do
		if not used[w[1]] then
			total += w[2]
		end
	end
	local r = self.rng:NextNumber() * total
	for _, w in ipairs(WEIGHTS) do
		if not used[w[1]] then
			r -= w[2]
			if r <= 0 then
				return w[1]
			end
		end
	end
	return "Meteor"
end

-- คืนค่า true ถ้าเริ่มได้ (ไม่ได้ = ลองเหตุการณ์อื่นแทน)
function EventService:Run(kind, token)
	local ok = self[kind](self, token)
	if not ok and kind ~= "Supply" then
		self.Supply(self, token)
	end
end

---------------------------------------------------------------- ☄ อุกกาบาตธาตุ
function EventService:Meteor(token)
	local ctx = self.ctx
	local spot, biome = self:FindSpot(380, 1150, 40)
	if not spot then
		return false
	end
	local el = table.find(ELEMENTS, biome) and biome or ELEMENTS[self.rng:NextInteger(1, 4)]
	local col = COLOR[el]
	local impactAt = Workspace:GetServerTimeNow() + METEOR_FALL
	ctx.State:SetAttribute("Event_Meteor", spot)
	ctx.State:SetAttribute("Event_MeteorElement", el)
	local yaw = self.rng:NextNumber(0, math.pi * 2)
	ctx.FireRun("WorldEvent", "Meteor", { Position = spot, Element = el, ImpactAt = impactAt, Fall = METEOR_FALL, Yaw = yaw })
	ctx.Broadcast(string.format("☄ อุกกาบาตธาตุ%sกำลังตก! เปิดแผนที่ (M) ดูจุดตก แล้วไปขุดแกนผลึกก่อนพลบค่ำ", THAI[el]), "Reward")

	local model = Instance.new("Model")
	model.Name = "MeteorCrater"
	local guards = {}
	local claimed = false
	self:Register("Meteor", function()
		if model.Parent then
			model:Destroy()
		end
		for _, a in ipairs(guards) do
			if not a.Dead then
				ctx.Services.AnimalService:Vanish(a)
			end
		end
	end)

	task.delay(METEOR_FALL, function()
		if not self:Valid(token) or not self.active.Meteor then
			return
		end
		-- ตกกระทบ: ดาเมจ + กระเด็นคนที่อยู่ใกล้
		for _, p in ipairs(self:RunPlayers()) do
			local c = p.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if r then
				local off = (r.Position - spot)
				if off.Magnitude < 20 then
					local dir = off * V(1, 0, 1)
					dir = dir.Magnitude > 0.1 and dir.Unit or V(1, 0, 0)
					ctx.Services.SurvivalService:Damage(p, 18 * (1 - off.Magnitude / 24), "Meteor", { Knockback = dir * 90 + V(0, 55, 0), Burn = el == "Fire" and 3 or nil })
				end
			end
		end
		-- หลุม: พื้นไหม้ + ขอบหินเอียงออก + ก้อนอุกกาบาตกลางหลุม + ผลึก
		local base = CF(spot)
		P(model, { Name = "Scorch", Shape = Enum.PartType.Cylinder, Size = V(0.6, 30, 30), CFrame = base * CF(0, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(38, 32, 30), Material = Enum.Material.Slate, CanCollide = false })
		P(model, { Name = "ScorchGlow", Shape = Enum.PartType.Cylinder, Size = V(0.2, 12, 12), CFrame = base * CF(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = col, Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.35 })
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2 + self.rng:NextNumber(-0.1, 0.1)
			local s = self.rng:NextNumber(3.5, 6)
			P(model, {
				Name = "Rim", Size = V(s * 1.4, s, s * 0.9),
				CFrame = base * CFrame.Angles(0, a, 0) * CF(0, s * 0.25, -14) * CFrame.Angles(math.rad(-35 + self.rng:NextNumber(-10, 10)), self.rng:NextNumber(-0.3, 0.3), 0),
				Color = Color3.fromRGB(58, 50, 46):Lerp(Color3.fromRGB(90, 80, 70), self.rng:NextNumber()), Material = Enum.Material.Slate,
			})
		end
		P(model, { Name = "Rock", Shape = Enum.PartType.Ball, Size = V(9, 9, 9), CFrame = base * CF(0, 2.6, 0), Color = Color3.fromRGB(40, 34, 36), Material = Enum.Material.Slate })
		local core = P(model, { Name = "Core", Shape = Enum.PartType.Ball, Size = V(4.5, 4.5, 4.5), CFrame = base * CF(0, 6.4, 0), Color = col, Material = Enum.Material.Neon, CanCollide = false })
		model:SetAttribute("Element", el)
		local shards = {}
		for i = 1, 7 do
			local a = i / 7 * math.pi * 2
			local h = self.rng:NextNumber(3, 6.5)
			table.insert(shards, P(model, {
				Name = "Shard", Size = V(1.2, h, 1.2),
				CFrame = base * CF(math.cos(a) * 3.2, 4 + h / 2 * 0.6, math.sin(a) * 3.2) * CFrame.Angles(math.cos(a) * 0.6, a, math.sin(a) * 0.6),
				Color = col, Material = Enum.Material.Neon, CanCollide = false,
			}))
		end
		do
			-- ก้อนอุกกาบาตจาก Creator Store (ลูกกลม/ผลึกปั้นเดิมซ่อนไว้เป็นตัวชน/จุดอ้างอิง)
			local PropBuilder = require(game:GetService("ReplicatedStorage").Shared.PropBuilder)
			local met = PropBuilder.Imported("MeteorLP", base * CF(0, 0.5, 0), 13, model)
			if met then
				-- กล่องรวมของโมเดลรวมหางเอฟเฟกต์ด้วย -> วางก้อนหิน (ชิ้นใหญ่สุด) ให้จมหลุมนิดๆ
				local big
				for _, d in ipairs(met:GetDescendants()) do
					if d:IsA("BasePart") and (not big or d.Size.Magnitude > big.Size.Magnitude) then
						big = d
					end
				end
				if big then
					met:PivotTo(met:GetPivot() + V(0, spot.Y + 2 - (big.Position.Y - big.Size.Y / 2), 0))
				end
				for _, n in ipairs({ "Rock", "Core" }) do
					local rp = model:FindFirstChild(n)
					if rp then
						rp.Transparency = 1
					end
				end
				for _, sh in ipairs(shards) do
					sh.Transparency = 1
				end
			end
		end
		light(core, col, 46, 3.5)
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Rate = 14
		sparks.Lifetime = NumberRange.new(1.2, 2.2)
		sparks.Speed = NumberRange.new(4, 9)
		sparks.SpreadAngle = Vector2.new(60, 60)
		sparks.Color = ColorSequence.new(col)
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
		sparks.Parent = core
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Rate = 6
		smoke.Lifetime = NumberRange.new(6, 9)
		smoke.Speed = NumberRange.new(8, 13)
		smoke.SpreadAngle = Vector2.new(12, 12)
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 22) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		smoke.Color = ColorSequence.new(Color3.fromRGB(70, 62, 60))
		smoke.Parent = core
		-- ลำแสงขึ้นฟ้า (มองเห็นจากไกล)
		local top = P(model, { Name = "BeamTop", Size = V(1, 1, 1), CFrame = base * CF(0, 320, 0), Transparency = 1, CanCollide = false, CanQuery = false })
		local a0 = Instance.new("Attachment")
		a0.Parent = core
		local a1 = Instance.new("Attachment")
		a1.Parent = top
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 3
		beam.Width1 = 9
		beam.LightEmission = 1
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(col)
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
		beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		beam.TextureSpeed = 0.5
		beam.Parent = core
		pcall(function()
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		end)
		model.PrimaryPart = core
		model.Parent = self:Folder()

		-- ผู้เฝ้า (สัตว์ธาตุเดียวกัน — ถ้ายังไม่มีโมเดลจะไม่เกิด ก็ขุดได้เลย)
		local night = ctx.State:GetAttribute("Night") or 1
		local scale = Nights.Scale(night)
		local pool = Animals.RaidPool[el] or {}
		local n = math.min(4, 2 + math.floor(night / 10))
		for i = 1, (#pool > 0 and n or 0) do
			local a = i / n * math.pi * 2
			local p = spot + V(math.cos(a) * 19, 0, math.sin(a) * 19)
			local h = groundY(p.X, p.Z, ctx.Layout:HeightAt(p.X, p.Z))
			local g = ctx.Services.AnimalService:Spawn(pool[self.rng:NextInteger(1, #pool)], V(p.X, math.max(h, spot.Y) + 3, p.Z), {
				Kind = "Guardian", Home = spot, Leash = 55, HealthMult = scale.Health * 1.2, DamageMult = scale.Damage, Night = night,
			})
			if g then
				g.Model:SetAttribute("Guardian", true)
				table.insert(guards, g)
			end
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Claim"
		prompt.ActionText = "ขุดแกนอุกกาบาต"
		prompt.HoldDuration = 2.5
		prompt.MaxActivationDistance = 15
		prompt.RequiresLineOfSight = false
		prompt.Parent = core
		local function guardsLeft()
			local left = 0
			for _, g in ipairs(guards) do
				if not g.Dead and not g.Removed then
					left += 1
				end
			end
			return left
		end
		local function refresh()
			local left = guardsLeft()
			prompt.ObjectText = left > 0 and string.format("ผู้พิทักษ์เหลือ %d ตัว", left) or ("อุกกาบาตธาตุ" .. THAI[el])
			prompt.Enabled = left == 0 and not claimed
		end
		refresh()
		for _, g in ipairs(guards) do
			g.Model.AncestryChanged:Connect(refresh)
			g.Model:GetAttributeChangedSignal("Dead"):Connect(refresh)
		end
		prompt.Triggered:Connect(function(player)
			if claimed or guardsLeft() > 0 or not player:GetAttribute("InRun") then
				return
			end
			claimed = true
			prompt.Enabled = false
			local drops = ctx.Services.DropService
			local got = {}
			for _, p in ipairs(self:RunPlayers()) do
				local c = p.Character
				if c and (c:GetPivot().Position - spot).Magnitude < 80 then
					local k = self.rng:NextInteger(2, 3)
					k = drops:SpawnLoot(ESSENCE[el], k, core.Position, { Spread = 4 })
					got[ESSENCE[el]] = (got[ESSENCE[el]] or 0) + k
					ctx.Services.DataService:AddDiamonds(p, self.rng:NextInteger(2, 5), "อุกกาบาตธาตุ")
				end
			end
			if self.rng:NextNumber() < 0.22 then
				local heart = Items.ElementHeart[el]
				drops:Spawn(heart, 1, core.Position, { Spread = 3 })
				got[heart] = 1
			end
			ctx.Remotes.Get("HitFx"):FireClient(player, "Loot", { Items = got, Position = core.Position, Chest = true })
			ctx.FireRun("WorldEvent", "MeteorClaimed", { Position = core.Position, Element = el })
			ctx.Broadcast(string.format("💎 %s ขุดแกนอุกกาบาตธาตุ%sสำเร็จ!", player.DisplayName, THAI[el]), "Good")
			ctx.State:SetAttribute("Event_Meteor", nil)
			-- แกนแตก
			for _, s in ipairs(shards) do
				TweenService:Create(s, TweenInfo.new(0.6), { Transparency = 1, Size = s.Size * 0.2 }):Play()
			end
			TweenService:Create(core, TweenInfo.new(0.8), { Transparency = 1, Size = V(12, 12, 12) }):Play()
			sparks.Rate = 0
			smoke.Rate = 1
			beam.Enabled = false
		end)
	end)
	return true
end

---------------------------------------------------------------- 🦌 ฝูงสัตว์อพยพ
function EventService:Migration(token)
	local ctx = self.ctx
	local layout = ctx.Layout
	local animals = ctx.Services.AnimalService
	if not (Animals.Data.Deer and Animals.Data.Rabbit) then
		return false
	end
	-- เส้นทาง: คอร์ดตัดผ่านข้างแคมป์ (ระยะ 280-420 จากกองไฟ) ยาว ~700
	local path
	for _ = 1, 25 do
		local a = self.rng:NextNumber(0, math.pi * 2)
		local d = self.rng:NextNumber(280, 420)
		local mid = V(math.cos(a), 0, math.sin(a)) * d
		local dir = V(-math.sin(a), 0, math.cos(a)) * (self.rng:NextNumber() < 0.5 and 1 or -1)
		local pts, ok = {}, true
		for i = 0, 8 do
			local p = mid + dir * ((i / 8 - 0.5) * 700)
			local h, _, lava = layout:HeightAt(p.X, p.Z)
			if lava or h < layout.WaterLevel + 1.5 then
				ok = false
				break
			end
			table.insert(pts, V(p.X, groundY(p.X, p.Z, h) + 2, p.Z))
		end
		if ok then
			path = pts
			break
		end
	end
	if not path then
		return false
	end
	local herd = {}
	local function spawnSome(id, n, factor)
		for _ = 1, n do
			local off = V(self.rng:NextNumber(-14, 14), 0, self.rng:NextNumber(-14, 14))
			local p = path[1] + off
			local h = groundY(p.X, p.Z, layout:HeightAt(p.X, p.Z))
			local a = animals:Spawn(id, V(p.X, h + 1.5, p.Z), { Kind = "Migrant", Home = path[1] })
			if a then
				a.Wp = 2
				a.MigrateSpeed = factor * self.rng:NextNumber(0.9, 1.1)
				a.Offset = off * 0.6
				a.OnDeath = function(dead)
					-- สัตว์อพยพตัวอ้วน: ลุ้นหนัง/เนื้อเพิ่ม
					if self.rng:NextNumber() < 0.5 then
						ctx.Services.DropService:Spawn("Pelt", 1, dead.Root.Position)
					end
					if dead.Id == "Deer" and self.rng:NextNumber() < 0.5 then
						ctx.Services.DropService:Spawn("RawMeat", 1, dead.Root.Position)
					end
				end
				table.insert(herd, a)
			end
		end
	end
	spawnSome("Deer", self.rng:NextInteger(5, 8), 0.36)
	spawnSome("Rabbit", self.rng:NextInteger(4, 7), 0.42)
	if #herd == 0 then
		return false -- ยังไม่มีโมเดลกวาง/กระต่าย
	end
	local done = false
	self:Register("Migration", function()
		done = true
		for _, a in ipairs(herd) do
			if not a.Dead and not a.Removed then
				animals:Vanish(a)
			end
		end
	end)
	ctx.State:SetAttribute("Event_Migration", path[1])
	ctx.FireRun("WorldEvent", "Migration", { Position = path[1], To = path[#path] })
	ctx.Broadcast("🦌 ฝูงสัตว์อพยพกำลังเดินผ่านใกล้แคมป์! โอกาสล่าเนื้อและหนังสัตว์ (ดูแผนที่ M)", "Reward")
	task.spawn(function()
		local t0 = os.clock()
		while not done and self:Valid(token) and os.clock() - t0 < 170 do
			task.wait(1)
			local alive, sum = 0, Vector3.zero
			local now = os.clock()
			for _, a in ipairs(herd) do
				if not a.Dead and not a.Removed and a.Model.Parent then
					local wp = path[a.Wp]
					if not wp then
						animals:Vanish(a)
					else
						alive += 1
						sum += a.Root.Position
						if (a.FleeUntil or 0) < now then
							local target = wp + a.Offset
							if ((a.Root.Position - target) * V(1, 0, 1)).Magnitude < 14 then
								a.Wp += 1
							end
							animals:MoveTo(a, target, a.MigrateSpeed)
							a.WanderAt = now + 3 -- กันโหมดเดินเล่นแย่งคำสั่ง
							a.State = "Wander"
							a.Model:SetAttribute("State", "Wander")
						end
					end
				end
			end
			if alive == 0 then
				break
			end
			ctx.State:SetAttribute("Event_Migration", sum / alive)
		end
		if self.active.Migration and not done then
			self:Cleanup("Migration")
		end
	end)
	return true
end

---------------------------------------------------------------- 📦 เสบียงตกจากฟ้า
function EventService:Supply(token)
	local ctx = self.ctx
	local spot = self:FindSpot(220, 650, 25)
	if not spot then
		return false
	end
	local model = Instance.new("Model")
	model.Name = "SupplyDrop"
	local landCF = CF(spot + V(0, 1.75, 0)) * CFrame.Angles(0, self.rng:NextNumber(0, 6.28), 0)
	local wood, metal = Color3.fromRGB(122, 86, 52), Color3.fromRGB(70, 74, 80)
	local body = P(model, { Name = "Body", Size = V(4.6, 3.5, 4.6), CFrame = landCF, Color = wood, Material = Enum.Material.WoodPlanks })
	for _, y in ipairs({ -1.2, 1.2 }) do
		P(model, { Size = V(4.8, 0.35, 4.8), CFrame = landCF * CF(0, y, 0), Color = metal, Material = Enum.Material.Metal, CanCollide = false })
	end
	P(model, { Size = V(0.4, 3.6, 4.8), CFrame = landCF, Color = metal, Material = Enum.Material.Metal, CanCollide = false })
	local flare = P(model, { Name = "Flare", Size = V(0.7, 1.4, 0.7), CFrame = landCF * CF(1.6, 2.4, 1.6), Color = Color3.fromRGB(255, 60, 40), Material = Enum.Material.Neon, CanCollide = false })
	light(flare, Color3.fromRGB(255, 80, 60), 30, 3)
	local chute = Instance.new("Model")
	chute.Name = "Chute"
	local canopy = P(chute, { Name = "Canopy", Shape = Enum.PartType.Cylinder, Size = V(1.2, 16, 16), CFrame = landCF * CF(0, 11, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(230, 70, 60), Material = Enum.Material.Fabric, CanCollide = false })
	P(chute, { Shape = Enum.PartType.Cylinder, Size = V(1.3, 8, 8), CFrame = canopy.CFrame * CF(0.2, 0, 0), Color = Color3.fromRGB(245, 240, 230), Material = Enum.Material.Fabric, CanCollide = false })
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local top = landCF * CF(math.cos(a) * 7, 10.5, math.sin(a) * 7)
		local bot = landCF * CF(math.cos(a) * 2, 1.7, math.sin(a) * 2)
		local mid = top.Position:Lerp(bot.Position, 0.5)
		P(chute, { Size = V(0.15, 0.15, (top.Position - bot.Position).Magnitude), CFrame = CFrame.lookAt(mid, bot.Position), Color = Color3.fromRGB(220, 220, 210), Material = Enum.Material.Fabric, CanCollide = false })
	end
	chute.Parent = model
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 9
	smoke.Lifetime = NumberRange.new(7, 10)
	smoke.Speed = NumberRange.new(10, 16)
	smoke.SpreadAngle = Vector2.new(8, 8)
	smoke.Acceleration = V(1.5, 0, 0)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 20) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(255, 70, 50), Color3.fromRGB(200, 120, 110))
	smoke.Enabled = false
	smoke.Parent = flare
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = d == body
		end
	end
	model.PrimaryPart = body
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local fallH = 170
	model:PivotTo(landCF + V(0, fallH, 0))
	model.Parent = self:Folder()
	local done = false
	self:Register("Supply", function()
		done = true
		if model.Parent then
			model:Destroy()
		end
	end)
	ctx.State:SetAttribute("Event_Supply", spot)
	local fall = 17
	ctx.FireRun("WorldEvent", "Supply", { Position = spot, LandAt = Workspace:GetServerTimeNow() + fall })
	ctx.Broadcast("📦 หีบเสบียงกำลังร่อนลงจากฟ้า! มองหาควันสีแดง (ดูแผนที่ M)", "Reward")
	task.spawn(function()
		local t0 = os.clock()
		while not done and model.Parent do
			local t = math.min((os.clock() - t0) / fall, 1)
			model:PivotTo(landCF + V(math.sin(t * 9) * 1.5 * (1 - t), fallH * (1 - t), 0))
			if t >= 1 then
				break
			end
			task.wait(0.06)
		end
		if done or not model.Parent then
			return
		end
		smoke.Enabled = true
		local cf0 = chute:GetPivot()
		for _, d in ipairs(chute:GetDescendants()) do
			if d:IsA("BasePart") then
				TweenService:Create(d, TweenInfo.new(2), { Transparency = 1 }):Play()
			end
		end
		chute:PivotTo(cf0 * CF(4, -4, 0) * CFrame.Angles(0, 0, 0.6))
		task.delay(2.2, function()
			chute:Destroy()
		end)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "OpenSupply"
		prompt.ActionText = "เปิดหีบเสบียง"
		prompt.ObjectText = "หีบเสบียง"
		prompt.HoldDuration = 1.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = body
		prompt.Triggered:Connect(function(player)
			if not prompt.Enabled or not player:GetAttribute("InRun") then
				return
			end
			prompt.Enabled = false
			local rng = self.rng
			local got = {}
			local pos = body.Position + V(0, 2, 0)
			-- จำนวนตามที่ตั้งตรงๆ (ไม่คูณ LootMult)
			local function give(id, n)
				if n > 0 then
					ctx.Services.DropService:Spawn(id, n, pos, { Spread = 3.5 })
					got[id] = (got[id] or 0) + n
				end
			end
			give("CookedMeat", rng:NextInteger(4, 5))
			give("Bandage", 3)
			give("Medkit", rng:NextNumber() < 0.2 and 1 or 0)
			give("Wood", rng:NextInteger(6, 8))
			give("Iron", rng:NextInteger(5, 6))
			give("Coal", rng:NextInteger(4, 5))
			give(ESSENCE[ELEMENTS[rng:NextInteger(1, 4)]], 1)
			ctx.Services.DataService:AddDiamonds(player, rng:NextInteger(2, 3), "หีบเสบียง")
			ctx.Remotes.Get("HitFx"):FireClient(player, "Loot", { Items = got, Position = pos, Chest = true })
			ctx.Broadcast(string.format("📦 %s เปิดหีบเสบียงแล้ว!", player.DisplayName), "Good")
			ctx.State:SetAttribute("Event_Supply", nil)
			task.delay(6, function()
				smoke.Enabled = false
			end)
		end)
	end)
	return true
end

---------------------------------------------------------------- เริ่มระบบ
function EventService:Start(ctx)
	ctx.State:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = ctx.State:GetAttribute("Phase")
		self.token += 1
		if phase == "Day" then
			-- เผื่อมีของค้างจากวันก่อน
			self:CleanupAll()
			if ctx.Services.DirectorService:IsRunning() then
				self:PlanDay(self.token)
			end
		else
			-- พลบค่ำ / กลางคืน / ล็อบบี้ / จบเกม: เก็บทุกเหตุการณ์
			self:CleanupAll()
		end
	end)
end

return EventService
