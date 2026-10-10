--[[
	CampService — กองไฟกลางแคมป์ + โต๊ะคราฟต์ + การคราฟต์
	  - กองไฟกินเชื้อเพลิงตลอด (กลางคืนเร็วขึ้น) ไฟดับ = เขตปลอดภัยหาย ปีศาจกวางเข้าได้
	  - สัตว์บุกที่ถึงกองไฟจะกัดกินเชื้อเพลิง (DamageFire)
	  - อัปเกรดกองไฟ = เขตปลอดภัยกว้างขึ้น + หมอกเปิดกว้างขึ้น
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Recipes = require(ReplicatedStorage.Shared.Recipes)

local CampService = {}

local FUEL_ORDER = { "Wood", "Coal", "EmberShard", "TerraCore", "BeastHeart" }

function CampService:Init(ctx)
	self.lastThrow = {}
	self.ctx = ctx
	self.level = 1
	self.bench = 1
	self.fuel = Recipes.Campfire[1].MaxFuel * 0.75
end

function CampService:Info()
	return Recipes.Campfire[self.level]
end

function CampService:SafeRadius()
	if self.fuel <= 0 then
		return 0
	end
	return self:Info().SafeRadius
end

function CampService:IsLit()
	return self.fuel > 0
end

function CampService:Publish()
	local s = self.ctx.State
	local info = self:Info()
	s:SetAttribute("CampLevel", self.level)
	s:SetAttribute("CampFuel", math.floor(self.fuel))
	s:SetAttribute("CampMaxFuel", info.MaxFuel)
	s:SetAttribute("CampSafeRadius", self:SafeRadius())
	s:SetAttribute("CampReveal", info.Reveal)
	s:SetAttribute("BenchLevel", self.bench)
end

-- หน้าตาไฟตามเชื้อเพลิง/เลเวล
function CampService:UpdateVisual()
	local core = self.fireCore
	if not core then
		return
	end
	local info = self:Info()
	local f = core:FindFirstChildOfClass("Fire")
	local l = core:FindFirstChildOfClass("PointLight")
	local frac = math.clamp(self.fuel / info.MaxFuel, 0, 1)
	local lit = self.fuel > 0
	if f then
		f.Enabled = lit
		f.Size = 2 + (2 + self.level) * frac
		f.Heat = 8 + self.level * 2
	end
	if l then
		l.Enabled = lit
		l.Range = math.max(12, info.Light * (0.4 + 0.6 * frac))
		l.Brightness = 1.5 + frac * 2
	end
	for _, e in ipairs(core:GetChildren()) do
		if e:IsA("ParticleEmitter") and e:GetAttribute("RealFire") then
			e.Enabled = lit
			e.TimeScale = 0.7 + 0.3 * frac
		end
	end
	-- เปลวไฟโตตามเชื้อเพลิง/เลเวล แต่ไม่ใหญ่เกินกองฟืน (0.55x - 1.35x)
	local mul = 0.55 + 0.45 * frac + 0.08 * self.level
	for _, name in ipairs({ "FlameCore", "Flames" }) do
		local e = core:FindFirstChild(name)
		local base = e and e:GetAttribute("BaseSize")
		if e then
			e.Enabled = lit
			e.Rate = (name == "Flames" and 14 or 18) + 16 * frac + self.level * 3
			if typeof(base) == "NumberSequence" then
				local ks = {}
				for _, k in ipairs(base.Keypoints) do
					table.insert(ks, NumberSequenceKeypoint.new(k.Time, k.Value * mul))
				end
				e.Size = NumberSequence.new(ks)
			end
		end
	end
	local sparks = core:FindFirstChild("Sparks")
	if sparks then
		sparks.Enabled = lit
		sparks.Rate = 4 + self.level * 3
	end
	local embers = self.campfire and self.campfire:FindFirstChild("Embers")
	if embers then
		embers.Color = lit and Color3.fromRGB(255, 120, 30) or Color3.fromRGB(60, 50, 46)
	end
end

function CampService:AddFuel(amount)
	local max = self:Info().MaxFuel
	local wasOut = self.fuel <= 0
	self.fuel = math.clamp(self.fuel + amount, 0, max)
	if wasOut and self.fuel > 0 then
		self.ctx.Broadcast("🔥 กองไฟลุกโชนอีกครั้ง!", "Good")
	end
	self:UpdateVisual()
	self:Publish()
end

-- สัตว์ที่บุกถึงกองไฟ
function CampService:DamageFire(amount)
	local before = self.fuel
	self.fuel = math.max(0, self.fuel - amount)
	if before > 0 and self.fuel <= 0 then
		self.ctx.Broadcast("⚠ กองไฟดับแล้ว!! เติมไฟด่วน ก่อนกวางกลวงจะมา", "Danger")
		self.ctx.Remotes.Get("Cinematic"):FireAllClients("FireOut", {})
	end
	self:UpdateVisual()
	self:Publish()
end

-- ผู้เล่นโยนเชื้อเพลิง: ใส่ทีละไอเทมจนเต็ม
function CampService:Refuel(player)
	local inv = self.ctx.Services.InventoryService
	local max = self:Info().MaxFuel
	local used = {}
	for _, id in ipairs(FUEL_ORDER) do
		local fuel = Items.Data[id].Fuel
		while self.fuel < max - fuel * 0.5 and inv:Available(player, id) > 0 and (id ~= "BeastHeart") do
			inv:Spend(player, { [id] = 1 })
			self.fuel = math.min(max, self.fuel + fuel)
			used[id] = (used[id] or 0) + 1
		end
	end
	if next(used) == nil then
		if self.fuel >= max - 6 then
			self.ctx.Notify(player, "กองไฟเต็มแล้ว", "Info")
		else
			self.ctx.Notify(player, "ไม่มีเชื้อเพลิง (ไม้ / ถ่านหิน / เศษอัคคี)", "Error")
		end
		return
	end
	local parts = {}
	for id, n in pairs(used) do
		table.insert(parts, Items.DisplayName(id) .. " x" .. n)
	end
	self.ctx.Notify(player, "🔥 เติมไฟ: " .. table.concat(parts, ", "), "Good")
	self.ctx.Remotes.Get("HitFx"):FireAllClients("Refuel", { Position = self.ctx.CampPosition })
	self:UpdateVisual()
	self:Publish()
end

function CampService:UpgradeFire(player)
	local nextInfo = Recipes.Campfire[self.level + 1]
	if not nextInfo then
		self.ctx.Notify(player, "กองไฟเลเวลสูงสุดแล้ว", "Info")
		return
	end
	local inv = self.ctx.Services.InventoryService
	if not inv:Spend(player, nextInfo.Cost) then
		self.ctx.Notify(player, "ของไม่พอสำหรับอัปเกรดกองไฟ", "Error")
		return
	end
	self.level += 1
	self.fuel = math.max(self.fuel, nextInfo.MaxFuel * 0.6)
	self.ctx.Broadcast(string.format("🔥 กองไฟอัปเกรดเป็นเลเวล %d! เขตปลอดภัยกว้างขึ้น หมอกจางลง", self.level), "Reward")
	self.ctx.Remotes.Get("Cinematic"):FireAllClients("CampUpgrade", { Level = self.level })
	self:UpdateVisual()
	self:Publish()
	self:RefreshPrompts()
end

function CampService:UpgradeBench(player)
	local cost = Recipes.BenchUpgrade[self.bench + 1]
	if not cost then
		self.ctx.Notify(player, "โต๊ะคราฟต์เลเวลสูงสุดแล้ว", "Info")
		return
	end
	if not self.ctx.Services.InventoryService:Spend(player, cost) then
		self.ctx.Notify(player, "ของไม่พอสำหรับอัปเกรดโต๊ะ", "Error")
		return
	end
	self.bench += 1
	self.ctx.Broadcast(string.format("🔨 โต๊ะคราฟต์เลเวล %d! ปลดล็อกสูตรใหม่", self.bench), "Reward")
	self:Publish()
	self:RefreshPrompts()
end

function CampService:Craft(player, recipeId)
	local r = Recipes.ById[recipeId]
	if not r then
		return
	end
	local char = player.Character
	if not char or (char:GetPivot().Position - self.benchPos).Magnitude > 40 then
		self.ctx.Notify(player, "ต้องอยู่ใกล้โต๊ะคราฟต์ที่แคมป์", "Error")
		return
	end
	if r.Bench > self.bench then
		self.ctx.Notify(player, string.format("ต้องอัปเกรดโต๊ะเป็นเลเวล %d ก่อน", r.Bench), "Error")
		return
	end
	local inv = self.ctx.Services.InventoryService
	local item = Items.Data[r.Id]
	if item.Category == "Tool" and inv:Count(player, r.Id) > 0 then
		self.ctx.Notify(player, "มี " .. Items.DisplayName(r.Id) .. " อยู่แล้ว", "Info")
		return
	end
	local mult = 1
	if item.Category == "Structure" then
		mult = 1 - self.ctx.Services.SurvivalService:Perk(player, "BuildDiscount", 0)
	end
	if not inv:Spend(player, r.Cost, mult) then
		self.ctx.Notify(player, "วัตถุดิบไม่พอ", "Error")
		return
	end
	inv:Add(player, r.Id, r.Amount or 1)
	self.ctx.Notify(player, "🔨 คราฟต์สำเร็จ: " .. Items.DisplayName(r.Id) .. (item.Category == "Structure" and "  (กด B เพื่อวาง)" or ""), "Good")
	self.ctx.Remotes.Get("HitFx"):FireAllClients("Craft", { Position = self.benchPos })
end

-- ย่างเนื้อที่กองไฟ
function CampService:FirePosition()
	return self.fireCore and self.fireCore.Position
end

function CampService:ThrowFrom(player)
	local inv = self.ctx.Services.InventoryService
	local char = player.Character
	local fire = self:FirePosition()
	if not (char and fire) or (char:GetPivot().Position - fire).Magnitude > 30 then
		return
	end
	local now = os.clock()
	if (self.lastThrow[player] or 0) > now - 0.35 then
		return
	end
	self.lastThrow[player] = now
	local pick
	for _, id in ipairs(FUEL_ORDER) do
		if id ~= "BeastHeart" and inv:Count(player, id) > 0 then
			pick = id
			break
		end
	end
	if not pick and inv:Count(player, "RawMeat") > 0 then
		pick = "RawMeat"
	end
	if not pick then
		self.ctx.Notify(player, "ในกระสอบไม่มีไม้/ถ่าน/เนื้อดิบ ให้โยนเข้ากองไฟ", "Info")
		return
	end
	inv:Remove(player, pick, 1)
	self.ctx.Services.DropService:Throw(player, pick, 1, fire + Vector3.new(0, 1, 0))
end

-- เครื่องย่อย: ของที่บดได้ (วัตถุดิบ/แก่นธาตุ/ของหายาก)
local GRINDABLE = { Resource = true, Essence = true, Relic = true }

function CampService:FeedGrinder(player, all)
	local hopper = self.hopper
	if not hopper then
		local n = self.ctx.Services.InventoryService:Deposit(player)
		if n > 0 then
			self.ctx.Notify(player, string.format("📦 เทของลงคลังแคมป์ %d ชิ้น", n), "Good")
		end
		return
	end
	local char = player.Character
	if not char or (char:GetPivot().Position - hopper.Position).Magnitude > 34 then
		return
	end
	local now = os.clock()
	if (self.lastThrow[player] or 0) > now - 0.3 then
		return
	end
	self.lastThrow[player] = now
	local inv = self.ctx.Services.InventoryService
	local list = {}
	for id, n in pairs(inv:Get(player)) do
		local d = Items.Data[id]
		if d and GRINDABLE[d.Category] and n > 0 then
			table.insert(list, { id, n })
		end
	end
	if #list == 0 then
		self.ctx.Notify(player, "ในกระสอบไม่มีวัตถุดิบให้ย่อย (ไม้ หิน แร่ หนัง กระดูก ...)", "Info")
		return
	end
	local target = hopper.Position + Vector3.new(0, hopper.Size.Y * 0.2, 0)
	if not all then
		local id = list[1][1]
		inv:Remove(player, id, 1)
		self.ctx.Services.DropService:Throw(player, id, 1, target)
		return
	end
	-- โยนทั้งกระสอบทีละกอง (เห็นของลอยเข้าเครื่อง)
	task.spawn(function()
		for _, e in ipairs(list) do
			local left = e[2]
			while left > 0 do
				local k = math.min(left, 5)
				if inv:Remove(player, e[1], k) then
					self.ctx.Services.DropService:Throw(player, e[1], k, target)
				end
				left -= k
				task.wait(0.18)
			end
		end
	end)
end

-- ป้ายบนเครื่องบด: จำนวนไม้/เหล็กในคลังแคมป์
function CampService:UpdateStockSign()
	local bench = self.campModel and self.campModel:FindFirstChild("Workbench")
	if not bench then
		return
	end
	local camp = self.ctx.Services.InventoryService.Camp
	for name, id in pairs({ StockWood = "Wood", StockIron = "Iron" }) do
		local part = bench:FindFirstChild(name)
		local gui = part and part:FindFirstChildOfClass("SurfaceGui")
		if gui then
			gui.Label.Text = tostring(camp[id] or 0)
		end
	end
end

function CampService:GrindDrops()
	local hopper = self.hopper
	if not hopper then
		return
	end
	local drops = self.ctx.Services.DropService
	local got = {}
	for _, d in ipairs(drops:Near(hopper.Position, math.max(hopper.Size.X, hopper.Size.Z) * 0.6, hopper.Size.Y * 1.6)) do
		local item = Items.Data[d.Id]
		if item and GRINDABLE[item.Category] then
			drops:Remove(d.Model)
			local camp = self.ctx.Services.InventoryService.Camp
			camp[d.Id] = (camp[d.Id] or 0) + d.Count
			got[d.Id] = (got[d.Id] or 0) + d.Count
		end
	end
	if next(got) then
		self:UpdateStockSign()
		self.ctx.Services.InventoryService:MarkAll()
		self.ctx.Remotes.Get("HitFx"):FireAllClients("Grind", { Bench = self.campModel:FindFirstChild("Workbench"), Items = got })
	end
end

local COOK = { RawMeat = "CookedMeat" }
function CampService:BurnDrops()
	local fire = self:FirePosition()
	if not fire then
		return
	end
	local drops = self.ctx.Services.DropService
	for _, d in ipairs(drops:Near(fire - Vector3.new(0, 1.5, 0), 5.5, 6)) do
		local item = Items.Data[d.Id]
		if COOK[d.Id] then
			if self:IsLit() then
				drops:Remove(d.Model)
				-- สุกแล้วเด้งออกนอกกองไฟ
				task.delay(1.2, function()
					drops:Spawn(COOK[d.Id], d.Count, fire, { Spread = 0.5 })
				end)
				self.ctx.Remotes.Get("HitFx"):FireAllClients("Refuel", { Position = fire })
			end
		elseif item and item.Fuel then
			drops:Remove(d.Model)
			self:AddFuel(item.Fuel * d.Count)
			self.ctx.Remotes.Get("HitFx"):FireAllClients("Refuel", { Position = fire })
		end
	end
end

function CampService:Cook(player)
	if not self:IsLit() then
		self.ctx.Notify(player, "ไฟดับอยู่ ย่างไม่ได้", "Error")
		return
	end
	local inv = self.ctx.Services.InventoryService
	local n = inv:Count(player, "RawMeat")
	if n <= 0 then
		self.ctx.Notify(player, "ไม่มีเนื้อดิบ", "Error")
		return
	end
	inv:Remove(player, "RawMeat", n)
	inv:Add(player, "CookedMeat", n)
	self.ctx.Notify(player, "🍖 ย่างเนื้อ x" .. n, "Good")
end

local function costText(cost)
	local parts = {}
	for id, n in pairs(cost) do
		table.insert(parts, Items.DisplayName(id) .. " " .. n)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

function CampService:RefreshPrompts()
	if self.upgradePrompt then
		local nextInfo = Recipes.Campfire[self.level + 1]
		self.upgradePrompt.ObjectText = "กองไฟ Lv." .. self.level
		self.upgradePrompt.ActionText = nextInfo and ("อัปเกรด: " .. costText(nextInfo.Cost)) or "เลเวลสูงสุด"
	end
	if self.benchUpgradePrompt then
		local cost = Recipes.BenchUpgrade[self.bench + 1]
		self.benchUpgradePrompt.ObjectText = "โต๊ะคราฟต์ Lv." .. self.bench
		self.benchUpgradePrompt.ActionText = cost and ("อัปเกรด: " .. costText(cost)) or "เลเวลสูงสุด"
	end
end

local function prompt(parent, name, action, object, key, hold, dist)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = key
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = dist or 14
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

function CampService:Start(ctx)
	local camp = workspace.World.Sites:WaitForChild("Camp")
	self.campModel = camp
	self.campfire = camp:WaitForChild("Campfire")
	self.fireCore = self.campfire:WaitForChild("FireCore")
	local bench = camp:WaitForChild("Workbench")
	self.benchPos = bench:GetPivot().Position

	local benchTop = bench.PrimaryPart
	local craft = prompt(benchTop, "Craft", "เปิดเมนูคราฟต์", "โต๊ะคราฟต์", Enum.KeyCode.E, 0, 14)
	craft.Triggered:Connect(function(p)
		ctx.Remotes.Get("Cinematic"):FireClient(p, "OpenCraft", {})
	end)
	-- เครื่องย่อย (ซ้าย): โยนวัตถุดิบลงช่อง -> บด -> เข้าคลังแคมป์ (ทุกคนใช้ร่วมกัน)
	self.hopper = bench:FindFirstChild("Hopper")
	local depositHost = self.hopper or benchTop
	local deposit = prompt(depositHost, "Deposit", "โยนวัตถุดิบลงเครื่องย่อย", "เครื่องย่อย", Enum.KeyCode.G, 0, 20)
	if not self.hopper then
		deposit.UIOffset = Vector2.new(0, 70)
	end
	deposit.Triggered:Connect(function(p)
		self:FeedGrinder(p, true)
	end)
	self:RefreshPrompts()

	ctx.Remotes.Get("Craft").OnServerEvent:Connect(function(player, recipeId)
		if ctx.Services.SurvivalService:IsIncapacitated(player) then
			return
		end
		if recipeId == "UpgradeFire" or recipeId == "UpgradeBench" then
			-- อัปเกรดจากเมนูคราฟต์ (ต้องอยู่ในแคมป์)
			local char = player.Character
			if not char or (char:GetPivot().Position - self.benchPos).Magnitude > 60 then
				self.ctx.Notify(player, "ต้องอยู่ในแคมป์", "Error")
			elseif recipeId == "UpgradeFire" then
				self:UpgradeFire(player)
			else
				self:UpgradeBench(player)
			end
		elseif type(recipeId) == "string" then
			self:Craft(player, recipeId)
		end
	end)
	-- ถือกระสอบแล้วคลิกกองไฟ = โยนเชื้อเพลิงจากกระสอบเข้าไป (ไม่มีก็โยนเนื้อดิบไปย่าง)
	ctx.Remotes.Get("ThrowFuel").OnServerEvent:Connect(function(player)
		if ctx.Services.SurvivalService:IsIncapacitated(player) then
			return
		end
		self:ThrowFrom(player)
	end)
	task.spawn(function()
		while true do
			self:UpdateStockSign()
			task.wait(1)
		end
	end)
	ctx.Remotes.Get("ThrowGrind").OnServerEvent:Connect(function(player)
		if ctx.Services.SurvivalService:IsIncapacitated(player) then
			return
		end
		self:FeedGrinder(player, false)
	end)
	-- ของที่ตกลงในกองไฟ: เชื้อเพลิงไหม้ / เนื้อดิบสุกเด้งออกมา · ของที่ตกลงช่องเครื่องย่อย: บดเข้าคลัง
	task.spawn(function()
		while true do
			task.wait(0.25)
			self:BurnDrops()
			self:GrindDrops()
		end
	end)

	self:UpdateVisual()
	self:Publish()
	-- เชื้อเพลิงลดลงตามเวลา
	task.spawn(function()
		local dt = 1
		while true do
			task.wait(dt)
			if ctx.Services.DirectorService:IsRunning() and ctx.State:GetAttribute("Phase") ~= "Ended" then
				local night = ctx.State:GetAttribute("Phase") == "Night"
				local drain = (night and Recipes.CampfireDrainNight or Recipes.CampfireDrainDay) * (1 + (self.level - 1) * 0.15)
				-- ผู้พิทักษ์เปลวไฟ / วิญญาณน้ำ ลดการกินเชื้อเพลิง
				for _, p in ipairs(Players:GetPlayers()) do
					local m = ctx.Services.SurvivalService:Perk(p, "FuelDrainMult", 1)
					if m < 1 then
						drain *= m
						break
					end
				end
				if ctx.State:GetAttribute("SpiritWater") then
					drain *= 0.75
				end
				local before = self.fuel
				self.fuel = math.max(0, self.fuel - drain * dt)
				if before > 0 and self.fuel <= 0 then
					ctx.Broadcast("⚠ กองไฟมอดดับ! เติมไม้ด่วน", "Danger")
					ctx.Remotes.Get("Cinematic"):FireAllClients("FireOut", {})
				elseif before > self:Info().MaxFuel * 0.2 and self.fuel <= self:Info().MaxFuel * 0.2 then
					ctx.Broadcast("🔥 เชื้อเพลิงกองไฟเหลือน้อย!", "Warn")
				end
				self:UpdateVisual()
				self:Publish()
			end
		end
	end)
end

function CampService:Reset()
	self.level = 1
	self.bench = 1
	self.fuel = Recipes.Campfire[1].MaxFuel * 0.75
	self:UpdateVisual()
	self:Publish()
	self:RefreshPrompts()
end

return CampService
