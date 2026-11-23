--[[
	VillageService — ทหารชนเผ่ากะโหลกแดงเฝ้าหมู่บ้านโจร (1 หมู่บ้าน/ไบโอม · PropBuilder.BuildVillage)
	  ผู้เล่นเข้าใกล้ WAKE = ทหารออกเฝ้า: นักธนูยืนบนหอคอย 4 หอ + นักรบหอก/ตัวโล่/นักธนูในลาน
	  กวาดล้างหมด = หมู่บ้านว่าง RESPAWN วินาทีแล้วชุดใหม่มา · ไม่มีใครใกล้นานๆ = เก็บทหาร (ไม่นับว่าล้าง)
	  ทหารเก่งขึ้นตามคืน (เลือด/ดาเมจ) · หีบโบราณ 3 ใบในหมู่บ้านเปิดได้ตลอด (LootService)
	  โมเดล Tribe* ยังไม่ Import = AnimalService:Spawn คืน nil -> หมู่บ้านว่าง (ไม่ error)
	ป้อมชนเผ่า (ไบโอมไฟ · Capital): ทหารชุดใหญ่ แข็งกว่า · ประตูปิดผนึก -> วางหินกะโหลก 3 ก้อนที่แท่นหน้าประตู = ประตูเปิด
	  (หินดรอปจากหีบหัวหน้าเผ่าในหมู่บ้านดิน/น้ำ/ลม · จบรอบ = ประตูปิด แท่นว่างใหม่)
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.Items)

local VillageService = {}

local WAKE = 200 -- คนเข้าใกล้กลางหมู่บ้านเท่านี้ = ทหารออกเฝ้า
local SLEEP = 330 -- ไม่มีใครใกล้เกินนี้ ...
local SLEEP_T = 60 -- ... นานเท่านี้ = เก็บทหาร
local RESPAWN = 8 * 60 -- ล้างหมู่บ้านแล้ว ทหารชุดใหม่มาหลังกี่วินาที
local GROUND_TEAM = { "TribeWarrior", "TribeShield", "TribeWarrior", "TribeArcher", "TribeWarrior", "TribeShield", "TribeWarrior", "TribeArcher" }
local LEASH = 58 -- ทหารในลานไม่ออกนอกรั้ว (รัศมีรั้ว 70)
-- ป้อมชนเผ่า: ทหารในลานชุดใหญ่ + เลือด/ดาเมจคูณเพิ่ม · ตื่นไกลกว่า (กำแพงรัศมี 130)
local CAPITAL_TEAM = { "TribeWarrior", "TribeShield", "TribeArcher", "TribeWarrior", "TribeShield", "TribeWarrior", "TribeArcher", "TribeWarrior",
	"TribeShield", "TribeWarrior", "TribeArcher", "TribeWarrior", "TribeShield", "TribeWarrior", "TribeArcher", "TribeWarrior" }
local CAPITAL_WAKE, CAPITAL_SLEEP, CAPITAL_MULT = 320, 480, 1.4
local LAND = { Earth = "Earth", Water = "Water", Air = "Frost" }

function VillageService:Init(ctx)
	self.ctx = ctx
	self.villages = {}
end

local function center(v)
	local c = v:GetAttribute("Center")
	return typeof(c) == "Vector3" and c or v:GetPivot().Position
end

function VillageService:NearestPlayer(pos)
	local surv = self.ctx.Services.SurvivalService
	local best
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if r and p:GetAttribute("InRun") and surv:IsAlive(p) then
			local d = (r.Position - pos).Magnitude
			if not best or d < best then
				best = d
			end
		end
	end
	return best or math.huge
end

function VillageService:SpawnGarrison(v, st)
	local animals = self.ctx.Services.AnimalService
	local night = self.ctx.State:GetAttribute("Night") or 1
	local cap = v:GetAttribute("Capital") and CAPITAL_MULT or 1
	local opts = { Kind = "Village", HealthMult = (1 + math.min(night, 99) * 0.025) * cap, DamageMult = (1 + math.min(night, 99) * 0.012) * cap }
	local team = v:GetAttribute("Capital") and CAPITAL_TEAM or GROUND_TEAM
	local leash = v:GetAttribute("Leash") or LEASH
	local c = center(v)
	st.Members = {}
	local spawns = v:FindFirstChild("Spawns")
	local ground = {}
	for _, s in ipairs(spawns and spawns:GetChildren() or {}) do
		if s.Name == "Archer" then
			local a = animals:Spawn("TribeArcher", s.Position, {
				Kind = opts.Kind, HealthMult = opts.HealthMult, DamageMult = opts.DamageMult,
				NoSnap = true, Perch = true, Home = s.Position, Leash = 12, Yaw = math.atan2(-(c - s.Position).X, -(c - s.Position).Z),
			})
			if a then
				table.insert(st.Members, a)
			end
		elseif s.Name == "Ground" then
			table.insert(ground, s.Position)
		end
	end
	for i, id in ipairs(team) do
		local pos = ground[(i - 1) % math.max(#ground, 1) + 1]
		if pos then
			local a = animals:Spawn(id, pos, { Kind = opts.Kind, HealthMult = opts.HealthMult, DamageMult = opts.DamageMult, Home = c, Leash = leash })
			if a then
				table.insert(st.Members, a)
			end
		end
	end
	st.Spawned = #st.Members > 0
	st.FarSince = nil
end

function VillageService:Despawn(st)
	local animals = self.ctx.Services.AnimalService
	for _, a in ipairs(st.Members or {}) do
		if not a.Dead and a.Model and a.Model.Parent then
			animals:Remove(a)
		end
	end
	st.Members = {}
	st.Spawned = false
end

-- หมุดหมู่บ้านชนเผ่าบนแผนที่ (MapUI: รูปหน้ากาก) · ReplicatedStorage.MapVillages: Vector3Value ต่อหมู่บ้าน
--   Capital = ป้อมชนเผ่า · Cleared = เพิ่งกวาดล้าง (ทหารชุดใหม่ยังไม่มา)
function VillageService:PublishPins(now)
	local folder = ReplicatedStorage:FindFirstChild("MapVillages")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MapVillages"
		folder.Parent = ReplicatedStorage
	end
	self.pins = self.pins or {}
	local keep = {}
	for _, v in ipairs(CollectionService:GetTagged("Village")) do
		if v:IsDescendantOf(workspace) then
			local pin = self.pins[v]
			if not (pin and pin.Parent) then
				pin = Instance.new("Vector3Value")
				pin.Name = "Village"
				pin.Parent = folder
				self.pins[v] = pin
			end
			pin.Value = center(v)
			pin:SetAttribute("Capital", v:GetAttribute("Capital") == true or nil)
			local st = self.villages[v]
			pin:SetAttribute("Cleared", (st and not st.Spawned and st.ClearedAt and now - st.ClearedAt <= RESPAWN) or nil)
			keep[pin] = true
		end
	end
	for v, pin in pairs(self.pins) do
		if not keep[pin] then
			pin:Destroy()
			self.pins[v] = nil
		end
	end
end

function VillageService:Tick()
	local now = os.clock()
	self:PublishPins(now)
	for _, v in ipairs(CollectionService:GetTagged("Village")) do
		if v:IsDescendantOf(workspace) then
			local st = self.villages[v]
			if not st then
				st = { Members = {}, Spawned = false }
				self.villages[v] = st
			end
			local near = self:NearestPlayer(center(v))
			local wake, sleep = WAKE, SLEEP
			if v:GetAttribute("Capital") then
				wake, sleep = CAPITAL_WAKE, CAPITAL_SLEEP
			end
			if st.Spawned then
				local alive, killed = 0, 0
				for _, a in ipairs(st.Members) do
					if a.Dead then
						killed += 1
					elseif a.Model and a.Model.Parent then
						alive += 1
					end
				end
				if alive == 0 then
					-- ทหารหมด: โดนฆ่า = หมู่บ้านถูกกวาดล้าง (รอชุดใหม่) · หายไปเฉยๆ (จบรอบ/ล้างแมพ) = ยังไม่ล้าง
					st.Spawned = false
					st.Members = {}
					if killed > 0 then
						st.ClearedAt = now
						v:SetAttribute("ClearedAt", workspace:GetServerTimeNow())
					end
				elseif near > sleep then
					st.FarSince = st.FarSince or now
					if now - st.FarSince > SLEEP_T then
						self:Despawn(st)
					end
				else
					st.FarSince = nil
				end
			elseif near < wake and (not st.ClearedAt or now - st.ClearedAt > RESPAWN) then
				self:SpawnGarrison(v, st)
			end
		end
	end
end

---------------------------------------------------------------- ป้อมชนเผ่า: แท่นวางหินกะโหลก + ประตูปิดผนึก
local function strongholdOf(inst)
	local p = inst
	while p and not (p:IsA("Model") and p:GetAttribute("Capital")) do
		p = p.Parent
	end
	return p
end

local function setSocket(sock, filled)
	sock:SetAttribute("Filled", filled or nil)
	local stone = sock:FindFirstChild("Stone")
	if stone then
		stone.Transparency = filled and 0 or 1
		local glow = stone:FindFirstChild("Glow")
		if glow then
			glow.Brightness = filled and 3 or 0
		end
	end
	local pr = sock:FindFirstChildWhichIsA("ProximityPrompt")
	if pr then
		pr.Enabled = not filled
	end
	local hold = strongholdOf(sock)
	local gate = hold and hold:FindFirstChild("StrongholdGate")
	local gem = gate and gate:FindFirstChild("Gem_" .. tostring(sock:GetAttribute("Element")))
	if gem then
		gem.Material = filled and Enum.Material.Neon or Enum.Material.Slate
		gem.Color = filled and (gem:GetAttribute("GlowColor") or gem.Color) or Color3.fromRGB(40, 36, 36)
		local l = gem:FindFirstChildWhichIsA("PointLight")
		if filled and not l then
			l = Instance.new("PointLight")
			l.Range = 24
			l.Brightness = 3
			l.Color = gem.Color
			l.Parent = gem
		elseif not filled and l then
			l:Destroy()
		end
	end
end

-- ประตู 2 บานหมุนรอบบานพับเข้าด้านใน (open) / กลับที่เดิม (ปิด)
function VillageService:SetGate(gate, open, instant)
	gate:SetAttribute("Open", open)
	for _, leaf in ipairs(gate:GetChildren()) do
		if leaf:IsA("Model") and leaf.PrimaryPart then
			local closed = leaf:GetAttribute("ClosedCF")
			if not closed then
				closed = leaf:GetPivot()
				leaf:SetAttribute("ClosedCF", closed)
			end
			local hinge = leaf.PrimaryPart.CFrame
			local hingeClosed = leaf:GetAttribute("HingeCF")
			if not hingeClosed then
				hingeClosed = hinge
				leaf:SetAttribute("HingeCF", hingeClosed)
			end
			local side = leaf:GetAttribute("Side") or 1
			local target = open and math.rad(100) * side or 0
			local function pose(a)
				local h = CFrame.new(hingeClosed.Position)
				leaf:PivotTo(h * CFrame.Angles(0, a, 0) * h:Inverse() * closed)
			end
			if instant then
				pose(target)
			else
				task.spawn(function()
					local from = open and 0 or math.rad(100) * side
					for i = 1, 60 do
						local t = i / 60
						t = t * t * (3 - 2 * t)
						pose(from + (target - from) * t)
						task.wait(1 / 20)
					end
				end)
			end
		end
	end
end

function VillageService:PlaceStone(sock, player)
	if sock:GetAttribute("Filled") or not player:GetAttribute("InRun") then
		return
	end
	local inv = self.ctx.Services.InventoryService
	local stone = sock:GetAttribute("Stone")
	local info = Items.Data[stone]
	local name = info and info.Name or tostring(stone)
	if inv:Count(player, stone) < 1 then
		self.ctx.Notify(player, string.format("You need the %s — open the chief's chest in the %s tribe village", name, LAND[sock:GetAttribute("Element")] or "?"), "Error")
		return
	end
	if not inv:Remove(player, stone, 1) then
		return
	end
	setSocket(sock, true)
	local hold = strongholdOf(sock)
	local total, filled = 0, 0
	for _, s in ipairs(CollectionService:GetTagged("StrongholdSocket")) do
		if strongholdOf(s) == hold then
			total += 1
			if s:GetAttribute("Filled") then
				filled += 1
			end
		end
	end
	self.ctx.Broadcast(string.format("%s placed the %s (%d/%d)", player.DisplayName, name, filled, total), "Good")
	local gate = hold and hold:FindFirstChild("StrongholdGate")
	if gate and filled >= total and not gate:GetAttribute("Open") then
		self:SetGate(gate, true)
		self.ctx.Broadcast("🔥 The seal is broken — the Skull Stronghold gate is open!", "Good")
	end
end

function VillageService:ResetStronghold()
	for _, s in ipairs(CollectionService:GetTagged("StrongholdSocket")) do
		setSocket(s, false)
	end
	for _, g in ipairs(CollectionService:GetTagged("StrongholdGate")) do
		if g:GetAttribute("Open") then
			self:SetGate(g, false, true)
		end
	end
end

-- จบรอบ/เริ่มรอบใหม่: ทหารทุกหมู่บ้านกลับมาเต็ม
function VillageService:Reset()
	self:ResetStronghold()
	for v, st in pairs(self.villages) do
		self:Despawn(st)
		if v.Parent then
			v:SetAttribute("ClearedAt", nil)
		end
	end
	self.villages = {}
end

function VillageService:Start()
	local function hook(sock)
		local pr = sock:FindFirstChildWhichIsA("ProximityPrompt")
		if pr and not sock:GetAttribute("Hooked") then
			sock:SetAttribute("Hooked", true)
			pr.Triggered:Connect(function(player)
				self:PlaceStone(sock, player)
			end)
		end
	end
	for _, s in ipairs(CollectionService:GetTagged("StrongholdSocket")) do
		hook(s)
	end
	CollectionService:GetInstanceAddedSignal("StrongholdSocket"):Connect(hook)
	task.spawn(function()
		while true do
			task.wait(1.5)
			local ok, err = pcall(self.Tick, self)
			if not ok then
				warn("[AS] village", err)
			end
		end
	end)
end

return VillageService
