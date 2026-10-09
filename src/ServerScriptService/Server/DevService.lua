--[[
	DevService — เครื่องมือนักพัฒนา (เปิดด้วย F8 หรือปุ่ม DEV มุมจอ)
	ใช้ได้เฉพาะ: ใน Roblox Studio / เจ้าของเกม / UserId ใน Config.DevUserIds (เช็กฝั่ง server ทุกคำสั่ง)
	client เรียก Remotes "DevCmd" (RemoteFunction): (action, arg1, arg2) -> ข้อความผลลัพธ์
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Animals = require(Shared.Animals)
local Items = require(Shared.Items)
local Classes = require(Shared.Classes)
local Config = require(Shared.Config)
local Nights = require(Shared.Nights)
local Recipes = require(Shared.Recipes)

local DevService = {}

function DevService:Init(ctx)
	self.ctx = ctx
end

function DevService:IsDev(player)
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		if ok and rank >= 254 then
			return true
		end
	end
	return table.find(Config.DevUserIds or {}, player.UserId) ~= nil
end

local function rootOf(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

-- จุดบนพื้นด้านหน้าผู้เล่น
function DevService:FrontGround(player, dist)
	local root = rootOf(player)
	if not root then
		return nil
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local p = root.Position + look * dist
	local h = self.ctx.Layout and self.ctx.Layout:HeightAt(p.X, p.Z) or p.Y
	return Vector3.new(p.X, math.max(h, Config.WaterLevel) + 3, p.Z)
end

function DevService:Teleport(player, pos)
	local root = rootOf(player)
	if not (root and pos) then
		return "ไม่มีตัวละคร"
	end
	local y = pos.Y
	if self.ctx.Layout and pos.Y < 1000 then
		y = math.max(self.ctx.Layout:HeightAt(pos.X, pos.Z), Config.WaterLevel) + 6
	end
	pcall(function()
		player:RequestStreamAroundAsync(Vector3.new(pos.X, y, pos.Z), 5)
	end)
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(pos.X, y, pos.Z)
	return "วาร์ปแล้ว"
end

---------------------------------------------------------------- คำสั่งทั้งหมด
local C = {}

-- ผู้เล่น
function C.god(self, p)
	local on = not p:GetAttribute("TestGod")
	p:SetAttribute("TestGod", on)
	return on and "🛡 อมตะ: เปิด" or "🛡 อมตะ: ปิด"
end

function C.heal(self, p)
	local _, hum = rootOf(p)
	if hum then
		hum.Health = hum.MaxHealth
	end
	p:SetAttribute("Hunger", Config.HungerMax)
	if p:GetAttribute("Downed") then
		self.ctx.Services.SurvivalService:Revive(p, 1)
	end
	return "❤ เลือด/ความหิวเต็ม"
end

function C.speed(self, p, mult)
	mult = math.clamp(tonumber(mult) or 1, 0.5, 6)
	p:SetAttribute("DevSpeed", mult)
	return string.format("🏃 ความเร็ว x%.1f", mult)
end

function C.respawn(self, p)
	self.ctx.Services.SurvivalService:Spawn(p)
	return "เกิดใหม่แล้ว"
end

function C.depart(self, p)
	if p:GetAttribute("InRun") then
		return "อยู่ในแมพแล้ว"
	end
	if not self.ctx.State:GetAttribute("Ready") then
		return "โลกยังสร้างไม่เสร็จ"
	end
	self.ctx.Services.LobbyService:Depart(p)
	return "🧭 ลงแมพแล้ว"
end

function C.lobby(self, p)
	self.ctx.Services.SurvivalService:ResetPlayer(p)
	return "กลับล็อบบี้"
end

-- วาร์ป
function C.tp(self, p, target)
	local s = self.ctx.State
	if target == "camp" then
		local cp = self.ctx.CampPosition or s:GetAttribute("CampPos")
		return self:Teleport(p, cp + Vector3.new(10, 0, 10))
	elseif target == "front" then
		return self:Teleport(p, self:FrontGround(p, 120))
	end
	local pos = s:GetAttribute(target)
	if typeof(pos) ~= "Vector3" then
		return "ไม่พบจุดหมาย " .. tostring(target)
	end
	if not p:GetAttribute("InRun") then
		return "ลงแมพก่อน (ปุ่ม ลงแมพ)"
	end
	return self:Teleport(p, pos + Vector3.new(14, 0, 14))
end

-- ไอเทม
function C.give(self, p, id, n)
	if not Items.Data[id] then
		return "ไม่มีไอเทม " .. tostring(id)
	end
	self.ctx.Services.InventoryService:Add(p, id, tonumber(n) or 1, true)
	return "🎁 ได้ " .. Items.DisplayName(id) .. " x" .. (tonumber(n) or 1)
end

function C.giveCategory(self, p, cat, n)
	local inv = self.ctx.Services.InventoryService
	local count = 0
	for id, d in pairs(Items.Data) do
		if d.Category == cat then
			inv:Add(p, id, tonumber(n) or 1, true)
			count += 1
		end
	end
	return string.format("🎁 ได้ %s ทั้งหมด %d อย่าง", cat, count)
end

function C.clearInv(self, p)
	self.ctx.Services.InventoryService:Reset(p)
	return "🗑 ล้างกระเป๋าแล้ว"
end

-- สัตว์
function C.spawn(self, p, id, n)
	local info = Animals.Data[id]
	if not info then
		return "ไม่มีสัตว์ " .. tostring(id)
	end
	if not p:GetAttribute("InRun") then
		return "ลงแมพก่อน"
	end
	local animals = self.ctx.Services.AnimalService
	local made = 0
	local boss = info.Behaviour == "Boss"
	for i = 1, math.clamp(tonumber(n) or 1, 1, 20) do
		local pos = self:FrontGround(p, boss and 70 or (18 + i * 3))
		if pos then
			local a = animals:Spawn(id, pos + Vector3.new((i - 1) * 4, 0, 0), { Kind = boss and "Boss" or (info.Behaviour == "Spirit" and "Wild" or "Wild"), Night = self.ctx.State:GetAttribute("Night") or 1, Force = true })
			if a then
				made += 1
				if boss then
					a.Model:SetAttribute("IsBoss", true)
					local s = self.ctx.State
					s:SetAttribute("BossId", id)
					s:SetAttribute("BossHP", a.Hum.MaxHealth)
					s:SetAttribute("BossMaxHP", a.Hum.MaxHealth)
					self.ctx.Remotes.Get("Cinematic"):FireAllClients("BossIntro", { Model = a.Model, Id = id, Name = info.Name, Thai = info.Thai, Element = info.Element })
				end
			end
		end
	end
	return string.format("🐾 เสก %s x%d", info.Thai, made)
end

function C.raid(self, p)
	if not p:GetAttribute("InRun") then
		return "ลงแมพก่อน"
	end
	local dir = self.ctx.Services.DirectorService
	local night = self.ctx.State:GetAttribute("Night") or 1
	local rng = Random.new()
	local plan = Nights.Plan(night, rng, Nights.PickElement(night, rng, nil))
	local n = 0
	for _, w in ipairs(plan.Waves) do
		if not w.Boss then
			for _, id in ipairs(w.Spawns) do
				dir:SpawnRaid(id, plan, night)
				n += 1
			end
			break
		end
	end
	return string.format("⚔ ปล่อยฝูงบุก %d ตัว (คืนที่ %d)", n, night)
end

function C.killAll(self, p)
	local animals = self.ctx.Services.AnimalService
	local n = 0
	for _, a in ipairs(table.clone(animals:All())) do
		if a.Kind ~= "Spirit" and not a.Dead then
			animals:TakeDamage(a, 1e9, p, {})
			n += 1
		end
	end
	return "💀 สังหารสัตว์ " .. n .. " ตัว (ได้ของดรอป)"
end

function C.clearAnimals(self)
	local animals = self.ctx.Services.AnimalService
	local n = 0
	for _, a in ipairs(table.clone(animals:All())) do
		if a.Kind ~= "Spirit" then
			animals:Remove(a)
			n += 1
		end
	end
	self.ctx.State:SetAttribute("BossId", "")
	return "🧹 ลบสัตว์ " .. n .. " ตัว"
end

function C.freeze(self)
	self.frozen = not self.frozen
	for _, a in ipairs(self.ctx.Services.AnimalService:All()) do
		a.Root.Anchored = self.frozen
	end
	return self.frozen and "🧊 หยุดสัตว์ทั้งหมด" or "▶ สัตว์ขยับต่อ"
end

-- เวลา
function C.skip(self)
	local dir = self.ctx.Services.DirectorService
	if not dir:IsRunning() then
		return "ยังไม่เริ่มรอบ (ลงแมพก่อน)"
	end
	dir.skip = true
	return "⏭ ข้ามช่วง " .. tostring(self.ctx.State:GetAttribute("Phase"))
end

function C.pause(self)
	local dir = self.ctx.Services.DirectorService
	dir.paused = not dir.paused
	return dir.paused and "⏸ หยุดเวลา" or "▶ เดินเวลาต่อ"
end

function C.setNight(self, _, n)
	local dir = self.ctx.Services.DirectorService
	n = math.clamp(math.floor(tonumber(n) or 1), 1, Config.TotalNights)
	dir.night = n
	self.ctx.State:SetAttribute("Night", n)
	local boss = Nights.BossNights and Nights.BossNights[n]
	return string.format("🌙 ตั้งเป็นคืนที่ %d%s", n, boss and (" (คืนบอส " .. boss .. ")") or "")
end

function C.nightNow(self)
	local dir = self.ctx.Services.DirectorService
	if not dir:IsRunning() then
		return "ยังไม่เริ่มรอบ (ลงแมพก่อน)"
	end
	local phase = self.ctx.State:GetAttribute("Phase")
	if phase == "Day" then
		dir.skip = true
		task.delay(0.6, function()
			dir.skip = true
		end)
	elseif phase == "Dusk" then
		dir.skip = true
	end
	return "🌙 กำลังข้ามไปกลางคืน"
end

function C.bloodMoon(self)
	local s = self.ctx.State
	s:SetAttribute("BloodMoon", not s:GetAttribute("BloodMoon"))
	return s:GetAttribute("BloodMoon") and "🔴 จันทร์เลือด: เปิด" or "จันทร์เลือด: ปิด"
end

-- แคมป์
function C.fuel(self)
	local camp = self.ctx.Services.CampService
	camp:AddFuel(1e6)
	return "🔥 เติมเชื้อเพลิงเต็ม"
end

function C.extinguish(self)
	local camp = self.ctx.Services.CampService
	camp:AddFuel(-1e6)
	return "💨 ดับกองไฟ"
end

function C.fireLevel(self, _, d)
	local camp = self.ctx.Services.CampService
	camp.level = math.clamp(camp.level + (tonumber(d) or 1), 1, #Recipes.Campfire)
	camp.fuel = camp:Info().MaxFuel
	camp:UpdateVisual()
	camp:Publish()
	camp:RefreshPrompts()
	return "🔥 กองไฟเลเวล " .. camp.level
end

function C.benchLevel(self, _, d)
	local camp = self.ctx.Services.CampService
	local max = 1
	for k in pairs(Recipes.BenchUpgrade) do
		max = math.max(max, k)
	end
	camp.bench = math.clamp(camp.bench + (tonumber(d) or 1), 1, max)
	camp:Publish()
	camp:RefreshPrompts()
	return "🔨 โต๊ะคราฟต์เลเวล " .. camp.bench
end

-- โปรไฟล์ / ร้าน
function C.diamonds(self, p, n)
	self.ctx.Services.DataService:AddDiamonds(p, tonumber(n) or 1000, "DEV")
	return "💎 +" .. (tonumber(n) or 1000)
end

function C.unlockAll(self, p)
	local ds = self.ctx.Services.DataService
	local d = ds:Get(p)
	if not d then
		return "ไม่มีโปรไฟล์"
	end
	for _, id in ipairs(Classes.Order) do
		d.Owned[id] = true
	end
	ds:Push(p)
	return "🔓 ปลดล็อกทุกคลาส"
end

function C.maxClass(self, p)
	local ds = self.ctx.Services.DataService
	local cls = p:GetAttribute("Class") or "Survivor"
	ds:SetClassLevel(p, cls, Classes.MaxLevel)
	return "⭐ " .. Classes.Data[cls].Thai .. " เลเวลสูงสุด"
end

function C.resetDaily(self, p)
	local ds = self.ctx.Services.DataService
	local d = ds:Get(p)
	if d then
		d.LastDaily = -1
		d.StockRoll = (d.StockRoll or 0) + 1
		ds:Push(p)
	end
	return "🔄 รีเซ็ตรางวัลรายวัน + สุ่มสต็อกใหม่"
end

function C.resetProfile(self, p)
	local ds = self.ctx.Services.DataService
	local d = ds:Get(p)
	if d then
		d.Diamonds = 0
		d.Owned = { Survivor = true }
		d.Class = "Survivor"
		d.ClassLevel = {}
		d.ClassStats = {}
		d.PendingKits = {}
		p:SetAttribute("Class", "Survivor")
		p:SetAttribute("ClassLevel", 1)
		ds:Push(p)
	end
	return "♻ รีเซ็ตโปรไฟล์ (เพชร/คลาส)"
end

-- ข้อมูลสถานะ
function C.info(self, p)
	local s = self.ctx.State
	local animals = self.ctx.Services.AnimalService
	local root = rootOf(p)
	local biome = "-"
	if root and self.ctx.Layout and root.Position.Y < 1000 then
		biome = self.ctx.Layout:BiomeAt(root.Position.X, root.Position.Z)
	end
	return string.format("ช่วง %s · คืน %d · สัตว์ %d ตัว · ไบโอม %s · ตำแหน่ง %s",
		tostring(s:GetAttribute("Phase")), s:GetAttribute("Night") or 0, #animals:All(), tostring(biome),
		root and string.format("%d,%d,%d", root.Position.X, root.Position.Y, root.Position.Z) or "-")
end

function DevService:Start(ctx)
	local rf = ctx.Remotes.Get("DevCmd")
	rf.OnServerInvoke = function(player, action, a, b)
		if not self:IsDev(player) then
			return "⛔ ไม่มีสิทธิ์ใช้เครื่องมือนักพัฒนา"
		end
		local fn = C[action]
		if not fn then
			return "ไม่รู้จักคำสั่ง " .. tostring(action)
		end
		local ok, res = pcall(fn, self, player, a, b)
		if not ok then
			warn("[AS] dev", action, res)
			return "❌ " .. tostring(res)
		end
		return res
	end
	local function mark(p)
		p:SetAttribute("IsDev", self:IsDev(p))
	end
	Players.PlayerAdded:Connect(mark)
	for _, p in ipairs(Players:GetPlayers()) do
		mark(p)
	end
end

return DevService
