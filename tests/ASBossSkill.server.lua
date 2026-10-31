--[[
	ASBossSkill (server) — build_rbxlx.py --bossskill[=Id,Id]
	เรียกบอสทีละตัว -> ใช้ทุกสกิล (ย้ายผู้เล่นไปอีกฝั่งก่อนทุกสกิล = ทดสอบการหันตัวก่อนปล่อยสกิล)
	ถ่ายภาพจังหวะง้าง / ปล่อย / หลังปล่อย (มุมข้าง) + ซูมหน้าตอนคำราม (ดูปาก/คอ) · พิมพ์ค่าทิศหน้าบอสเทียบทิศสกิล [BOSSDIR]
	มุมกล้องสั่งผ่าน attribute "ProbeCam" ของผู้เล่น (ASBossSkill.client.lua)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASBossSkill") then
	return
end
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local char = player.Character or player.CharacterAdded:Wait()
local camp
repeat
	task.wait(1)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == "Camp" then
			camp = d
			break
		end
	end
until camp
task.wait(8)
local Animals = require(ReplicatedStorage.Shared.Animals)
local AnimalService = require(Server:WaitForChild("AnimalService"))
local BossAbilities = require(Server:WaitForChild("BossAbilities"))
local ctx = AnimalService.ctx
local cp = camp:GetPivot().Position
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), rp)
	return hit and hit.Position.Y or cp.Y
end
-- ผู้เล่นอมตะระหว่างเทสต์ (โดนสกิลแล้วไม่ตาย ไม่ต้องเกิดใหม่)
local GOD = true -- เทสคลาสปิด (ต้องวัดเลือดจริง)
task.spawn(function()
	while true do
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if h and GOD then
			h.Health = h.MaxHealth
		end
		task.wait(0.2)
	end
end)
local function shot(name)
	print("[SHOT] bs_" .. name)
	task.wait(0.05)
end
local function standAt(pos, look)
	local c = player.Character
	if c then
		c:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 4, 0), Vector3.new(look.X, pos.Y + 4, look.Z)))
	end
end
-- --bossskill=Classes : เทสทักษะทั้ง 8 คลาส (เลเวล 1 และ 3) ในรอบเล่นจริง — วัดผลจริงจากระบบเกม
local onlyClasses = ReplicatedStorage:FindFirstChild("ASBossOnly") and ReplicatedStorage.ASBossOnly.Value == "Classes"
if onlyClasses then
	local Classes = require(ReplicatedStorage.Shared.Classes)
	local Items = require(ReplicatedStorage.Shared.Items)
	local Config = require(ReplicatedStorage.Shared.Config)
	local Recipes = require(ReplicatedStorage.Shared.Recipes)
	local CS = game:GetService("CollectionService")
	local Surv = require(Server:WaitForChild("SurvivalService"))
	local Inv = require(Server:WaitForChild("InventoryService"))
	local Res = require(Server:WaitForChild("ResourceService"))
	local Combat = require(Server:WaitForChild("CombatService"))
	local Camp = require(Server:WaitForChild("CampService"))
	local Build = require(Server:WaitForChild("BuildingService"))
	local Drops = require(Server:WaitForChild("DropService"))
	require(Server:WaitForChild("LobbyService")):Depart(player)
	require(Server:WaitForChild("DirectorService")):StartRun()
	local tw = os.clock()
	repeat
		task.wait(0.5)
	until player:GetAttribute("InRun") or os.clock() - tw > 30
	task.wait(4)
	GOD = false
	local pass, fail = 0, 0
	local function check(cls, lv, what, ok, detail)
		if ok then
			pass += 1
		else
			fail += 1
		end
		print(string.format("[CLS] %s %s L%d %s  %s", ok and "PASS" or "FAIL", cls, lv, what, detail or ""))
	end
	local function near(a, b, tol)
		return math.abs(a - b) <= (tol or 0.01)
	end
	-- จับยอดของที่ดรอป (ไม่วางของจริงลงพื้น)
	local rec = {}
	local oldSpawn, oldLoot = Drops.Spawn, Drops.SpawnLoot
	Drops.Spawn = function(_, id, n)
		rec[id] = (rec[id] or 0) + n
		return n
	end
	Drops.SpawnLoot = Drops.Spawn
	-- node ตัวอย่าง
	local trees, rocks, bushes, crystals = {}, {}, {}, {}
	for _, m in ipairs(CS:GetTagged("ResourceNode")) do
		local k, y = m:GetAttribute("Node"), m:GetAttribute("Yield")
		if not m:GetAttribute("Depleted") then
			if k == "Tree" then
				table.insert(trees, m)
			elseif k == "Bush" then
				table.insert(bushes, m)
			elseif Items.Data[y] and Items.Data[y].Category == "Essence" then
				table.insert(crystals, m)
			elseif k == "Rock" then
				table.insert(rocks, m)
			end
		end
	end
	print(string.format("[CLS] nodes tree=%d rock=%d bush=%d crystal=%d", #trees, #rocks, #bushes, #crystals))
	local wolf = AnimalService:Spawn("MossWolf", Vector3.new(cp.X, ground(cp.X, cp.Z + 90) + 3, cp.Z + 90), {})
	wolf.Root.Anchored = true
	local oldRng = AnimalService.rng
	local function nodeDelta(node, tool)
		node:SetAttribute("HP", 100)
		node:SetAttribute("Frac_" .. player.UserId, 0)
		rec = {}
		Res:Hit(player, node, tool)
		return 100 - node:GetAttribute("HP")
	end
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	local bushI = 0
	for _, id in ipairs(Classes.Order) do
		local c = Classes.Data[id]
		for _, lv in ipairs({ 1, 3 }) do
			local P = Classes.PerksFor(id, lv)
			player:SetAttribute("Class", id)
			player:SetAttribute("ClassLevel", lv)
			Surv:OnClassChosen(player, id)
			hum = player.Character:FindFirstChildOfClass("Humanoid")
			-- เลือด/ความเร็ว/สตามิน่า
			check(id, lv, "MaxHealth", near(hum.MaxHealth, 100 + (P.MaxHealthBonus or 0)), string.format("%.0f (exp %.0f)", hum.MaxHealth, 100 + (P.MaxHealthBonus or 0)))
			check(id, lv, "WalkSpeed", near(hum.WalkSpeed, Config.BaseWalkSpeed * (P.SpeedMult or 1)), string.format("%.2f", hum.WalkSpeed))
			check(id, lv, "Stamina", near(player:GetAttribute("StaminaMult") or 1, P.StaminaMult or 1), tostring(player:GetAttribute("StaminaMult")))
			-- ดาเมจ (ไม่นับคริ: เอาค่าต่ำสุดจากหลายครั้ง)
			local wid = c.StartItems.EmberStaff and "EmberStaff" or "OldAxe"
			local wt = Items.Tools[wid]
			local lo = math.huge
			for _ = 1, 25 do
				lo = math.min(lo, (Combat:PlayerDamage(player, wid, wt, wolf)))
			end
			local expD = wt.Damage * (P.DamageMult or 1) * (wt.Element and (P.ElementDamageMult or 1) or 1) * Combat.ElementMult(wt.Element, wolf.Info.Element)
			check(id, lv, "Damage(" .. wid .. ")", near(lo, expD, 0.05), string.format("%.2f (exp %.2f)", lo, expD))
			-- ตัดไม้ / ทุบหิน
			if trees[1] then
				local d = nodeDelta(trees[1], Items.Tools.OldAxe)
				check(id, lv, "Chop", near(d, 1 * (P.ChopMult or 1)), string.format("%.2f", d))
			end
			if rocks[1] then
				local d = nodeDelta(rocks[1], Items.Tools.OldAxe)
				check(id, lv, "Mine", near(d, 0.5 * (P.MineMult or 1)), string.format("%.2f", d))
			end
			-- พุ่มไม้ (ของเพิ่ม)
			bushI += 1
			local b = bushes[bushI]
			if b then
				local y = b:GetAttribute("Yield")
				b:SetAttribute("HP", 1)
				rec = {}
				Res:Hit(player, b, Items.Tools.OldAxe)
				local exp = (b:GetAttribute("Amount") or 2) + (P.ExtraDrops or 0)
				check(id, lv, "BushDrops", (rec[y] or 0) == exp, string.format("%s=%d (exp %d)", tostring(y), rec[y] or 0, exp))
			end
			-- ดรอปจากสัตว์ (สุ่มคงที่: ได้ขั้นต่ำเสมอ)
			AnimalService.rng = { NextNumber = function() return 0 end, NextInteger = function(_, a) return a end }
			rec = {}
			AnimalService:GiveDrops(wolf, player)
			AnimalService.rng = oldRng
			local expP
			for _, dd in ipairs(wolf.Info.Drops or {}) do
				if dd.Item == "Pelt" then
					expP = (dd.Chance and 1 or (dd.Min or 1)) + (P.ExtraDrops or 0)
				end
			end
			if expP then
				check(id, lv, "AnimalDrops", (rec.Pelt or 0) == expP, string.format("Pelt=%d (exp %d)", rec.Pelt or 0, expP))
			end
			-- แก่นธาตุ
			if crystals[1] then
				local cr = crystals[1]
				local d = nodeDelta(cr, Items.Tools.Pickaxe)
				local y = cr:GetAttribute("Yield")
				local base = math.floor(d * (cr:GetAttribute("YieldPerHP") or 1) * Config.LootMult)
				local exp = math.floor(base * (P.EssenceMult or 1) + 0.5)
				check(id, lv, "Essence", (rec[y] or 0) == exp, string.format("%s=%d (exp %d)", tostring(y), rec[y] or 0, exp))
			end
			-- ฮีล: ผ้าพันแผล + เบอร์รี่
			hum.Health = 40
			Inv:Add(player, "Bandage", 1, true)
			Surv:UseItem(player, "Bandage")
			local hb = hum.Health - 40
			local expB = math.min(Items.Data.Bandage.Heal * (P.HealMult or 1), hum.MaxHealth - 40)
			check(id, lv, "HealBandage", near(hb, expB, 0.6), string.format("+%.1f (exp %.1f)", hb, expB))
			hum.Health = 40
			player:SetAttribute("Hunger", 50)
			Inv:Add(player, "Berries", 1, true)
			Surv:UseItem(player, "Berries")
			local hf = hum.Health - 40
			local expF = Items.Data.Berries.Heal * (P.HealMult or 1)
			check(id, lv, "HealFood", near(hf, expF, 0.6), string.format("+%.1f (exp %.1f)", hf, expF))
			-- คราฟต์กำแพง (ส่วนลดวัตถุดิบ) + วางกำแพง (ความถึก)
			standAt(Vector3.new(cp.X + 16, ground(cp.X + 16, cp.Z + 16), cp.Z + 16), cp)
			Camp.bench = 5
			task.wait(0.2)
			Inv:Add(player, "Wood", 30, true)
			local w0 = Inv:Available(player, "Wood", true)
			local l0 = Inv:Count(player, "LogWall")
			Camp:Craft(player, "LogWall", 1)
			local used = w0 - Inv:Available(player, "Wood", true)
			local expW = math.max(1, math.ceil(6 * (1 - (P.BuildDiscount or 0))))
			check(id, lv, "CraftDiscount", used == expW and Inv:Count(player, "LogWall") == l0 + 1, string.format("wood %d (exp %d)", used, expW))
			local root = player.Character.HumanoidRootPart
			local spot = root.Position + Vector3.new(12, 0, 0)
			local before = {}
			for _, s in ipairs(Build:All()) do
				before[s] = true
			end
			Build:Place(player, "LogWall", CFrame.new(spot))
			local placed
			for _, s in ipairs(Build:All()) do
				if not before[s] then
					placed = s
				end
			end
			local expH = Items.Structures.LogWall.Health * (P.WallHealthMult or 1)
			check(id, lv, "WallHealth", placed ~= nil and near(placed:GetAttribute("MaxHealth") or 0, expH), placed and string.format("%.0f (exp %.0f)", placed:GetAttribute("MaxHealth"), expH) or "place failed")
			if placed then
				placed:Destroy()
			end
			-- ฟื้นเลือด + ความหิว (เฉพาะเลเวล 3): นับตามรอบของเกมเอง (ทุก 0.5 วินาที) 10 รอบ
			-- ความหิว 50% = ไม่เข้าเงื่อนไขฟื้นเลือดตอนอิ่ม (>60%) -> เหลือแต่ทักษะ Regen
			if lv == 3 then
				hum.Health = 50
				player:SetAttribute("Hunger", 50)
				local n = 0
				local conn = player:GetAttributeChangedSignal("Hunger"):Connect(function()
					n += 1
				end)
				repeat
					task.wait()
				until n >= 1
				local h0, g0, n0 = hum.Health, player:GetAttribute("Hunger"), n
				repeat
					task.wait()
				until n >= n0 + 10
				conn:Disconnect()
				local sec = (n - n0) * 0.5
				local regen = (hum.Health - h0) / sec
				local hunger = (g0 - player:GetAttribute("Hunger")) / sec / Config.HungerDrainPerSec
				check(id, lv, "Regen", near(regen, P.Regen or 0, 0.02), string.format("%.2f/s (exp %.2f)", regen, P.Regen or 0))
				check(id, lv, "Hunger", near(hunger, P.HungerMult or 1, 0.02), string.format("x%.2f (exp x%.2f)", hunger, P.HungerMult or 1))
			end
			-- ของเริ่มต้นของคลาส
			if lv == 1 then
				Inv:Reset(player)
				player:SetAttribute("StartItemsGiven", false)
				Surv:GiveStartItems(player)
				local ok, got = true, {}
				for itemId, n in pairs(c.StartItems) do
					local have = Inv:Count(player, itemId)
					table.insert(got, itemId .. "=" .. have)
					ok = ok and have >= n
				end
				check(id, lv, "StartItems", ok, table.concat(got, " "))
			end
		end
	end
	Drops.Spawn, Drops.SpawnLoot = oldSpawn, oldLoot
	print(string.format("[CLS] SUMMARY pass=%d fail=%d", pass, fail))
	print("[TEST] DONE probe")
	return
end
-- --bossskill=StartAll : ทุกคลาสออกเดินทางจริง (กลับล็อบบี้ -> เลือกคลาส -> Depart) แล้วเช็กของเริ่มต้นในเป้
if ReplicatedStorage:FindFirstChild("ASBossOnly") and ReplicatedStorage.ASBossOnly.Value == "StartAll" then
	local Classes = require(ReplicatedStorage.Shared.Classes)
	local Items = require(ReplicatedStorage.Shared.Items)
	local Surv = require(Server:WaitForChild("SurvivalService"))
	local Inv = require(Server:WaitForChild("InventoryService"))
	local Lobby = require(Server:WaitForChild("LobbyService"))
	local pass, fail = 0, 0
	for _, id in ipairs(Classes.Order) do
		if player:GetAttribute("InRun") then
			Surv:ResetPlayer(player) -- กลับล็อบบี้ (ล้างเป้ + รีเซ็ตสถานะแจกของ)
			task.wait(3)
		end
		player:SetAttribute("Class", id)
		player:SetAttribute("ClassLevel", 1)
		Lobby:Depart(player)
		task.wait(4)
		local tools = {}
		for _, t in ipairs(player.Backpack:GetChildren()) do
			tools[t:GetAttribute("ItemId") or t.Name] = true
		end
		for _, t in ipairs(player.Character and player.Character:GetChildren() or {}) do
			if t:IsA("Tool") then
				tools[t:GetAttribute("ItemId") or t.Name] = true
			end
		end
		local ok, got = player:GetAttribute("InRun") == true, {}
		-- ทุกคลาส: กระสอบเก่า + ขวานถืออยู่ในมือ
		local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
		local heldId = held and held:GetAttribute("ItemId")
		local axeInHand = heldId ~= nil and Items.Tools[heldId] ~= nil and Items.Tools[heldId].Kind == "Axe"
		ok = ok and tools.OldSack == true and axeInHand
		table.insert(got, string.format("OldSack=%s inHand=%s", tostring(tools.OldSack == true), tostring(heldId)))
		for itemId, n in pairs(Classes.Data[id].StartItems) do
			local have = Inv:Count(player, itemId)
			local isTool = Items.Data[itemId].Category == "Tool"
			table.insert(got, string.format("%s=%d%s", itemId, have, isTool and (tools[itemId] and "(มือ)" or "(ไม่มีTool!)") or ""))
			ok = ok and have >= n and (not isTool or tools[itemId] == true)
		end
		if ok then
			pass += 1
		else
			fail += 1
		end
		print(string.format("[START] %s %s inRun=%s %s", ok and "PASS" or "FAIL", id, tostring(player:GetAttribute("InRun")), table.concat(got, " ")))
	end
	-- เปลี่ยนกระสอบ: ได้ใบใหญ่กว่า -> แทนใบเก่า (เหลือ Tool กระสอบใบเดียว) · ใบเล็กกว่า -> ไม่รับ
	local function sackState()
		local list = {}
		for _, holder in ipairs({ player.Backpack, player.Character }) do
			for _, t in ipairs(holder and holder:GetChildren() or {}) do
				local tid = t:IsA("Tool") and t:GetAttribute("ItemId")
				if tid and Items.Sacks[tid] then
					table.insert(list, tid)
				end
			end
		end
		return list
	end
	local function check(label, want)
		task.wait(0.5)
		local list = sackState()
		local good = #list == 1 and list[1] == want and Inv:Capacity(player) == Items.Sacks[want]
			and Inv:Count(player, "OldSack") + Inv:Count(player, "GoodSack") + Inv:Count(player, "GiantSack") == 1
		if good then
			pass += 1
		else
			fail += 1
		end
		print(string.format("[START] %s sack %s -> tools={%s} cap=%d", good and "PASS" or "FAIL", label, table.concat(list, ","), Inv:Capacity(player)))
	end
	check("start", "OldSack")
	Inv:Add(player, "GoodSack", 1)
	check("+Good", "GoodSack")
	Inv:Add(player, "OldSack", 1)
	check("+Old(เล็กกว่า)", "GoodSack")
	Inv:Add(player, "GiantSack", 1)
	check("+Giant", "GiantSack")
	Inv:Add(player, "GoodSack", 1)
	check("+Good(เล็กกว่า)", "GiantSack")
	-- Tool ซ้ำ: แอบ clone ขวาน/คบไฟ 2 อันใส่เป้ -> server ต้องลบเหลืออันเดียว
	do
		local axe
		for _, holder in ipairs({ player.Backpack, player.Character }) do
			for _, t in ipairs(holder:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("ItemId") == "OldAxe" then
					axe = t
				end
			end
		end
		if axe then
			axe:Clone().Parent = player.Backpack
			axe:Clone().Parent = player.Backpack
		end
		task.wait(2.6)
		local n = 0
		for _, holder in ipairs({ player.Backpack, player.Character }) do
			for _, t in ipairs(holder:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("ItemId") == "OldAxe" then
					n += 1
				end
			end
		end
		local good = axe ~= nil and n == 1
		if good then pass += 1 else fail += 1 end
		print(string.format("[START] %s dedupe OldAxe count=%d", good and "PASS" or "FAIL", n))
	end
	-- จำนวนสูงสุดสิ่งก่อสร้าง: เสกวัตถุดิบ -> คราฟต์กับดักหนามเกิน 8 / เสาธาตุเกิน 1 / หม้อตุ๋นเกิน 1
	do
		local Camp = require(Server:WaitForChild("CampService"))
		local Limits = require(ReplicatedStorage.Shared.Limits)
		Camp.bench = 5
		local bag = Inv:Get(player)
		for _, id in ipairs({ "Wood", "Stone", "Iron", "TerraCore", "Fiber", "Pelt", "Bone", "Berries" }) do
			bag[id] = 500
		end
		local char = player.Character
		local bench = Camp.benchPos
		if bench and char then
			char:PivotTo(CFrame.new(bench + Vector3.new(4, 3, 0)))
			task.wait(0.5)
		end
		for _, case in ipairs({ { "SpikeTrap", 12 }, { "TerraTotem", 3 }, { "CookPot", 3 }, { "LogWall", 25 } }) do
			local id, tries = case[1], case[2]
			for _ = 1, tries do
				Camp:Craft(player, id, 1)
			end
			local got = Inv:Count(player, id)
			local lim = Limits.Structures[id]
			local want = lim and lim.Max or tries
			local good = got == want
			if good then pass += 1 else fail += 1 end
			print(string.format("[START] %s limit %s crafted=%d want=%d", good and "PASS" or "FAIL", id, got, want))
		end
		-- วาง 1 อัน แล้วให้พัง -> คืนโควต้า คราฟต์เพิ่มได้ 1
		local Build = require(Server:WaitForChild("BuildingService"))
		local r = player.Character.HumanoidRootPart
		local placed = Build:Place(player, "SpikeTrap", CFrame.new(r.Position + r.CFrame.LookVector * 14))
		local before = Inv:LimitCount(player, "SpikeTrap")
		Camp:Craft(player, "SpikeTrap", 1)
		local blocked = Inv:Count(player, "SpikeTrap") == 7
		local CS = game:GetService("CollectionService")
		for _, m in ipairs(CS:GetTagged("Structure")) do
			if m:GetAttribute("Kind") == "SpikeTrap" and m:GetAttribute("Owner") == player.UserId then
				Build:Damage(m, 1e6)
			end
		end
		task.wait(0.3)
		Camp:Craft(player, "SpikeTrap", 1)
		local good = placed and before == 8 and blocked and Inv:Count(player, "SpikeTrap") == 8
		if good then pass += 1 else fail += 1 end
		print(string.format("[START] %s limit refund placed=%s count=%d blocked=%s after=%d", good and "PASS" or "FAIL", tostring(placed), before, tostring(blocked), Inv:Count(player, "SpikeTrap")))
		print("[START] attr Lim_SpikeTrap", player:GetAttribute("Lim_SpikeTrap"))
	end
	-- พ่อค้า: แลกได้ 3 ครั้ง/รายการ/การมาเยือน
	do
		local Trader = require(Server:WaitForChild("TraderService"))
		Trader:Arrive()
		task.wait(0.5)
		local bag = Inv:Get(player)
		bag.Pelt, bag.Bone = 200, 200
		player.Character:PivotTo(Trader.model:GetPivot() + Vector3.new(4, 2, 0))
		task.wait(0.5)
		local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Trade")
		local before = Inv:Count(player, "Iron")
		for _ = 1, 5 do
			Trader.TestTrade(player, "T_Iron")
		end
		local gotIron = Inv:Count(player, "Iron") - before
		local good = gotIron == 18
		if good then pass += 1 else fail += 1 end
		print(string.format("[START] %s trader T_Iron x5 -> got %d (want 18 = 3 ครั้ง)", good and "PASS" or "FAIL", gotIron))
		Trader:Leave()
	end
	-- ตายแล้วเกิดใหม่: ได้ขวานในมือ + กระสอบใบเดียวกลับมา
	player.Character:FindFirstChildOfClass("Humanoid").Health = 0
	local t0 = os.clock()
	repeat
		task.wait(0.5)
	until (player.Character and player.Character:FindFirstChildOfClass("Humanoid") and player.Character.Humanoid.Health > 0 and player.Character:FindFirstChildOfClass("Tool")) or os.clock() - t0 > 25
	task.wait(1)
	local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
	print(string.format("[START] respawn inHand=%s", tostring(held and held:GetAttribute("ItemId"))))
	check("respawn", "GiantSack")
	print(string.format("[START] SUMMARY pass=%d fail=%d", pass, fail))
	print("[TEST] DONE probe")
	return
end
-- --bossskill=Drops : ตีต้นไม้/หินจนล้ม -> ของที่ดรอปต้องไม่กระเด็น (อยู่ใกล้จุดตี + ไม่ขยับเมื่อตีต่อ)
if ReplicatedStorage:FindFirstChild("ASBossOnly") and ReplicatedStorage.ASBossOnly.Value == "Drops" then
	local Combat = require(Server:WaitForChild("CombatService"))
	local Res = require(Server:WaitForChild("ResourceService"))
	player:SetAttribute("Class", "Lumberjack")
	require(Server:WaitForChild("LobbyService")):Depart(player)
	require(Server:WaitForChild("DirectorService")):StartRun()
	task.wait(8)
	local folder = workspace:FindFirstChild("Drops")
	local r = player.Character.HumanoidRootPart
	local pass, fail = 0, 0
	local CS = game:GetService("CollectionService")
	local function nearest(kind)
		local best, bd
		for _, n in ipairs(CS:GetTagged("ResourceNode")) do
			if n:GetAttribute("Node") == kind and (n:GetAttribute("HP") or 0) > 0 and n.Parent then
				local dd = (n:GetPivot().Position - r.Position).Magnitude
				if not bd or dd < bd then
					best, bd = n, dd
				end
			end
		end
		return best
	end
	for round, kind in ipairs({ "Tree", "Tree", "Rock", "Rock" }) do
		local node = nearest(kind)
		if not node then
			print("[DROPS] no node", kind)
			continue
		end
		local foot = Res:Footprint(node)
		local np = node:GetPivot().Position
		local d = ((r.Position - np) * Vector3.new(1, 0, 1))
		d = d.Magnitude > 0.1 and d.Unit or Vector3.xAxis
		standAt(np + d * 4.5, np)
		task.wait(1)
		local before = {}
		for _, m in ipairs(folder and folder:GetChildren() or {}) do
			before[m] = true
		end
		for _ = 1, 40 do
			if not node.Parent or (node:GetAttribute("HP") or 0) <= 0 then
				break
			end
			Combat.lastAttack[player] = 0
			Combat:OnAttack(player, -d)
			task.wait(0.35)
		end
		task.wait(2.5)
		local new, far, maxD, inside, minD = {}, 0, 0, 0, 99
		for _, m in ipairs(folder and folder:GetChildren() or {}) do
			if not before[m] and m.PrimaryPart then
				local dist = ((m.PrimaryPart.Position - np) * Vector3.new(1, 0, 1)).Magnitude
				maxD = math.max(maxD, dist)
				minD = math.min(minD, dist)
				if dist > foot + 12 then
					far += 1
				end
				if dist < foot + 0.4 then
					inside += 1
				end
				new[m] = m.PrimaryPart.Position
			end
		end
		-- ตีต่อ/เดินชน: ของที่ตกแล้วต้องไม่ขยับ
		standAt(np + d * 1.5, np)
		for _ = 1, 4 do
			Combat.lastAttack[player] = 0
			Combat:OnAttack(player, -d)
			task.wait(0.35)
		end
		task.wait(1)
		local moved, n = 0, 0
		for m, p0 in pairs(new) do
			n += 1
			if m.Parent and m.PrimaryPart and (m.PrimaryPart.Position - p0).Magnitude > 0.5 then
				moved += 1
			end
		end
		local good = n > 0 and far == 0 and moved == 0 and inside == 0
		if good then pass += 1 else fail += 1 end
		print(string.format("[DROPS] %s round %d %s=%s footprint=%.1f drops=%d minDist=%.1f maxDist=%.1f inside=%d far=%d moved=%d", good and "PASS" or "FAIL", round, kind, node.Name, foot, n, minD, maxD, inside, far, moved))
		shot("drops_" .. round)
	end
	print(string.format("[DROPS] SUMMARY pass=%d fail=%d", pass, fail))
	print("[TEST] DONE probe")
	return
end
-- --bossskill=Night : ถ่ายภาพคำเตือนกวางกลวง + กวางจ้อง (ต้องไม่เป็นขอบแดงแบบเลือดลด)
if ReplicatedStorage:FindFirstChild("ASBossOnly") and ReplicatedStorage.ASBossOnly.Value == "Night" then
	player:SetAttribute("Class", "Survivor")
	require(Server:WaitForChild("LobbyService")):Depart(player)
	require(Server:WaitForChild("DirectorService")):StartRun()
	task.wait(8)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	shot("night_before")
	task.wait(1)
	require(ReplicatedStorage.Shared.Remotes).Get("Cinematic"):FireClient(player, "StalkerWarning", { In = 5 })
	task.wait(0.5)
	shot("night_warn")
	task.wait(0.6)
	shot("night_warn2")
	task.wait(5)
	require(ReplicatedStorage.Shared.Remotes).Get("HitFx"):FireClient(player, "StalkerStare", {})
	task.wait(0.15)
	shot("night_stare")
	print("[TEST] DONE probe")
	return
end
-- --bossskill=Hurt : อดอาหาร (ดาเมจทีละนิด) ต้องไม่กะพริบจอแดงรัวๆ · โดนตีแรง = แดง · เลือด < 25% = ขอบแดงค้าง
if ReplicatedStorage:FindFirstChild("ASBossOnly") and ReplicatedStorage.ASBossOnly.Value == "Hurt" then
	local Surv = require(Server:WaitForChild("SurvivalService"))
	GOD = false
	player:SetAttribute("TestGod", nil)
	player:SetAttribute("Class", "Survivor")
	require(Server:WaitForChild("LobbyService")):Depart(player)
	require(Server:WaitForChild("DirectorService")):StartRun()
	task.wait(6)
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	hum.Health = hum.MaxHealth
	local function phase(name, secs, fn)
		player:SetAttribute("ProbeFx", name)
		local t0 = os.clock()
		while os.clock() - t0 < secs do
			fn()
			task.wait(0.2)
		end
		player:SetAttribute("ProbeFx", name .. "_end")
		task.wait(0.6)
	end
	task.wait(4) -- ForceField ตอนเกิด 4 วิ (กันดาเมจ)
	phase("starve", 6, function()
		player:SetAttribute("Hunger", 0)
	end)
	print(string.format("[HURT] after starve hp=%.1f", hum.Health))
	hum.Health = hum.MaxHealth
	player:SetAttribute("Hunger", 100)
	player:SetAttribute("ProbeFx", "hit")
	task.wait(0.3)
	Surv:Damage(player, 20, "Test")
	task.wait(1.5)
	player:SetAttribute("ProbeFx", "hit_end")
	task.wait(0.6)
	hum.Health = hum.MaxHealth * 0.15
	phase("low", 3, function() end)
	hum.Health = hum.MaxHealth
	phase("full", 2, function() end)
	print("[TEST] DONE probe")
	return
end
-- --bossskill=Struct : หม้อตุ๋นตั้งตรง · หน้าไม้ยักษ์หันแนวนอน/ไม่จม · แปลงมีพุ่มเบอร์รี่ (ลูกโผล่ตอนโต) · เตียง = +1 วัน (2 ต่อเกม)
if ReplicatedStorage:FindFirstChild("ASBossOnly") and ReplicatedStorage.ASBossOnly.Value == "Struct" then
	local Inv = require(Server:WaitForChild("InventoryService"))
	local Build = require(Server:WaitForChild("BuildingService"))
	local Dir = require(Server:WaitForChild("DirectorService"))
	player:SetAttribute("Class", "Survivor")
	require(Server:WaitForChild("LobbyService")):Depart(player)
	require(Server:WaitForChild("DirectorService")):StartRun()
	task.wait(8)
	local function check(name, ok, info)
		print(string.format("[STRUCT] %s %s %s", ok and "PASS" or "FAIL", name, info or ""))
	end
	local cp = camp:GetPivot().Position
	local function spot(dx, dz)
		local x, z = cp.X + dx, cp.Z + dz
		return Vector3.new(x, ground(x, z), z)
	end
	-- เตียง: วางจริงผ่าน Place
	local st = ReplicatedStorage.GameState
	local n0 = st:GetAttribute("Night")
	local got = 0
	for _ = 1, 3 do
		got += (Inv:Add(player, "Bed", 1) and 1 or 0)
	end
	check("bed_hold_limit", Inv:Count(player, "Bed") == 2, "held=" .. Inv:Count(player, "Bed"))
	local b1 = spot(18, 0)
	standAt(b1 + Vector3.new(0, 0, 8), b1)
	task.wait(0.5)
	Build:Place(player, "Bed", CFrame.new(b1))
	task.wait(0.5)
	check("bed1_day", st:GetAttribute("Night") == n0 + 1, string.format("night %d->%d", n0, st:GetAttribute("Night")))
	local b2 = spot(18, 12)
	standAt(b2 + Vector3.new(0, 0, 8), b2)
	task.wait(0.5)
	Build:Place(player, "Bed", CFrame.new(b2))
	task.wait(0.5)
	check("bed2_day", st:GetAttribute("Night") == n0 + 2, string.format("night=%d used=%s", st:GetAttribute("Night"), tostring(st:GetAttribute("BedsUsed"))))
	Inv:Add(player, "Bed", 1)
	check("bed_no_third", Inv:Count(player, "Bed") == 0 and Inv:Room(player, "Bed") == 0, "room=" .. Inv:Room(player, "Bed"))
	-- ทำลายเตียงแล้วต้องไม่คืนโควต้า
	for _, m in ipairs(Build:All()) do
		if m:GetAttribute("Kind") == "Bed" then
			m:SetAttribute("Health", 0)
			m:Destroy()
			break
		end
	end
	task.wait(0.3)
	check("bed_no_refund", Inv:Room(player, "Bed") == 0, "room=" .. Inv:Room(player, "Bed"))
	-- ไม่มีจุดเกิดที่เตียง
	local sp = require(Server:WaitForChild("SurvivalService")):SpawnPoint(player)
	check("bed_not_spawn", (sp - b2).Magnitude > 6, string.format("spawn dist from bed %.1f", (sp - b2).Magnitude))
	-- วางโชว์
	local pot = Build:Spawn("CookPot", CFrame.new(spot(-18, 0)), 200, 200, player.UserId)
	local bal = Build:Spawn("Ballista", CFrame.new(spot(-18, 16)), 200, 200, player.UserId)
	local farm = Build:Spawn("FarmPlot", CFrame.new(spot(0, -22)), 150, 150, player.UserId)
	-- หม้อ: ชิ้นส่วนส่วนใหญ่ไม่เอียงทั้งก้อน -> กล่องรวมต้องสูงกว่ากว้าง (ขาตั้ง) และมี Pot
	local _, psz = pot:GetBoundingBox()
	check("pot_upright", psz.Y > 5 and pot:FindFirstChild("Pot") ~= nil, string.format("size=%.1f,%.1f,%.1f", psz.X, psz.Y, psz.Z))
	-- หน้าไม้: ลูกศรแนวนอนชี้ -Z ของโมเดล · ก้นป้อมอยู่เหนือหัวเสา
	local tur = bal:FindFirstChild("Turret")
	local arrow = tur and tur:FindFirstChild("Arrow", true)
	if arrow then
		local sz = arrow.Size
		local axis = (sz.X >= sz.Y and sz.X >= sz.Z) and arrow.CFrame.RightVector or (sz.Y >= sz.Z and arrow.CFrame.UpVector or arrow.CFrame.LookVector)
		local tcf, tsz = tur:GetBoundingBox()
		local base = bal:GetPivot().Position.Y
		check("ballista_flat", math.abs(axis.Y) < 0.1, string.format("arrowAxis=(%.2f,%.2f,%.2f) turretBottom=%.2f size=%.1f,%.1f,%.1f",
			axis.X, axis.Y, axis.Z, tcf.Y - tsz.Y / 2 - base, tsz.X, tsz.Y, tsz.Z))
		check("ballista_not_sunk", tcf.Y - tsz.Y / 2 - base >= 3.7, "")
	else
		check("ballista_arrow", false, "no arrow")
	end
	-- แปลง: มีพุ่ม 6 · ลูกซ่อนตอนยังไม่โต
	local crops = farm:FindFirstChild("Crops")
	local berries, shown = 0, 0
	for _, d in ipairs(crops and crops:GetDescendants() or {}) do
		if d:IsA("BasePart") and d.Name == "Berry" then
			berries += 1
			if d.Transparency < 0.5 then shown += 1 end
		end
	end
	check("farm_bushes", crops and #crops:GetChildren() == 6 and berries > 0 and shown == 0, string.format("bushes=%d berries=%d shown=%d", crops and #crops:GetChildren() or 0, berries, shown))
	local function look(target, off, name)
		player:SetAttribute("ProbeFrom", target + off)
		player:SetAttribute("ProbeAt", target + Vector3.new(0, 2, 0))
		player:SetAttribute("ProbeCam", "look")
		task.wait(2)
		shot(name)
		task.wait(1)
	end
	look(farm:GetPivot().Position, Vector3.new(0, 9, 14), "struct_farm_growing")
	farm:SetAttribute("GrowAt", os.clock() - 1)
	task.wait(1.5)
	shown = 0
	for _, d in ipairs(crops and crops:GetDescendants() or {}) do
		if d:IsA("BasePart") and d.Name == "Berry" and d.Transparency < 0.5 then shown += 1 end
	end
	local prompt = farm:FindFirstChildWhichIsA("ProximityPrompt", true)
	check("farm_ready", shown == berries and prompt and prompt.Enabled, string.format("shown=%d/%d prompt=%s", shown, berries, tostring(prompt and prompt.Enabled)))
	look(farm:GetPivot().Position, Vector3.new(0, 9, 14), "struct_farm_ready")
	look(pot:GetPivot().Position, Vector3.new(10, 6, 10), "struct_pot")
	look(bal:GetPivot().Position, Vector3.new(12, 6, 4), "struct_ballista_side")
	look(bal:GetPivot().Position, Vector3.new(0, 5, -12), "struct_ballista_front")
	player:SetAttribute("ProbeCam", "")
	print("[TEST] DONE probe")
	return
end
-- --bossskill=Berry : พุ่มเบอร์รี่ E=กิน F=เก็บใส่กระสอบ (เต็ม=หล่นพื้น) · คราฟต์ยาสมุนไพร/น้ำเบอร์รี่ (Lv.1) · พายเบอร์รี่ที่หม้อตุ๋น
if ReplicatedStorage:FindFirstChild("ASBossOnly") and ReplicatedStorage.ASBossOnly.Value == "Berry" then
	local Inv = require(Server:WaitForChild("InventoryService"))
	local Res = require(Server:WaitForChild("ResourceService"))
	local Camp = require(Server:WaitForChild("CampService"))
	local Build = require(Server:WaitForChild("BuildingService"))
	local Surv = require(Server:WaitForChild("SurvivalService"))
	player:SetAttribute("Class", "Survivor")
	require(Server:WaitForChild("LobbyService")):Depart(player)
	require(Server:WaitForChild("DirectorService")):StartRun()
	task.wait(8)
	local r = player.Character.HumanoidRootPart
	local function check(name, ok, info)
		print(string.format("[BERRY] %s %s %s", ok and "PASS" or "FAIL", name, info or ""))
	end
	-- พุ่มที่ใกล้สุด
	local bush, bd
	for _, d in ipairs(workspace.World:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Name == "BushPick" then
			local n = d.Parent:FindFirstAncestorWhichIsA("Model")
			while n and n:GetAttribute("Node") ~= "Bush" do
				n = n.Parent and n.Parent:IsA("Model") and n.Parent or nil
			end
			if n then
				local dd = (n:GetPivot().Position - r.Position).Magnitude
				if not bd or dd < bd then
					bush, bd = n, dd
				end
			end
		end
	end
	check("bush_found", bush ~= nil, bush and string.format("dist=%.0f", bd) or "")
	if bush then
		local pick, eat
		for _, d in ipairs(bush:GetDescendants()) do
			if d.Name == "BushPick" then pick = d elseif d.Name == "BushEat" then eat = d end
		end
		check("prompts", pick and eat and pick.KeyboardKeyCode == Enum.KeyCode.F and eat.KeyboardKeyCode == Enum.KeyCode.E,
			string.format("eat=%s pick=%s", eat and eat.ActionText or "-", pick and pick.ActionText or "-"))
		local np = bush:GetPivot().Position
		local d = ((r.Position - np) * Vector3.new(1, 0, 1))
		d = d.Magnitude > 0.1 and d.Unit or Vector3.xAxis
		standAt(np + d * 6, np)
		task.wait(2)
		shot("berry_prompts")
		local b0 = Inv:Count(player, "Berries")
		local c0 = bush:GetAttribute("Berries")
		Res:PickBerry(player, bush, "Sack")
		task.wait(0.3)
		check("pick_to_sack", Inv:Count(player, "Berries") == b0 + 1 and bush:GetAttribute("Berries") == c0 - 1,
			string.format("bag %d->%d bush %d->%d", b0, Inv:Count(player, "Berries"), c0, bush:GetAttribute("Berries")))
		-- กระสอบเต็ม -> หล่นพื้นข้างพุ่ม
		local space = Inv:Space(player)
		Inv:AddToSack(player, "Stone", space)
		local drops = workspace:FindFirstChild("Drops")
		local before = drops and #drops:GetChildren() or 0
		local b1 = Inv:Count(player, "Berries")
		Res:PickBerry(player, bush, "Sack")
		task.wait(1)
		local after = drops and #drops:GetChildren() or 0
		check("full_sack_drops", Inv:Count(player, "Berries") == b1 and after == before + 1,
			string.format("space=%d bag=%d drops %d->%d", Inv:Space(player), Inv:Count(player, "Berries"), before, after))
		Inv:Remove(player, "Stone", space)
	end
	-- คราฟต์ Lv.1
	standAt(camp:GetPivot().Position + Vector3.new(8, 0, 8), camp:GetPivot().Position)
	task.wait(1)
	Inv:Add(player, "Berries", 20)
	Inv:Add(player, "Fiber", 4)
	local b = Inv:Count(player, "Berries")
	Camp:Craft(player, "HerbSalve", 1)
	task.wait(0.3)
	check("craft_salve", Inv:Count(player, "HerbSalve") == 1 and Inv:Count(player, "Berries") == b - 3,
		string.format("salve=%d berries %d->%d", Inv:Count(player, "HerbSalve"), b, Inv:Count(player, "Berries")))
	b = Inv:Count(player, "Berries")
	Camp:Craft(player, "BerryJuice", 1)
	task.wait(0.3)
	check("craft_juice", Inv:Count(player, "BerryJuice") == 1 and Inv:Count(player, "Berries") == b - 4,
		string.format("juice=%d berries %d->%d", Inv:Count(player, "BerryJuice"), b, Inv:Count(player, "Berries")))
	-- น้ำเบอร์รี่: หิว +20 + เติมสตามิน่า
	player:SetAttribute("Hunger", 50)
	local sr = player:GetAttribute("StaminaRefill") or 0
	Surv:UseItem(player, "BerryJuice")
	task.wait(0.3)
	check("drink_juice", math.abs((player:GetAttribute("Hunger") or 0) - 70) < 1 and (player:GetAttribute("StaminaRefill") or 0) == sr + 1,
		string.format("hunger=%.1f refill=%s", player:GetAttribute("Hunger") or 0, tostring(player:GetAttribute("StaminaRefill"))))
	-- ยาสมุนไพร: ฟื้นเลือด ~20 (ถือแล้วคลิก)
	GOD = false
	task.wait(0.5)
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	hum.Health = 40
	local hasTool = false
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t:GetAttribute("MedKind") == "HerbSalve" then
			hasTool = true
			hum:EquipTool(t)
		end
	end
	task.wait(0.5)
	shot("berry_salve_hand")
	local hp0 = hum.Health
	Surv:UseMedical(player, "HerbSalve")
	task.wait(1.8)
	check("use_salve", hasTool and hum.Health >= hp0 + 19 and Inv:Count(player, "HerbSalve") == 0,
		string.format("tool=%s hp %.1f->%.1f left=%d", tostring(hasTool), hp0, hum.Health, Inv:Count(player, "HerbSalve")))
	GOD = true
	-- พายเบอร์รี่ที่หม้อตุ๋น
	Inv:Add(player, "Wood", 2)
	b = Inv:Count(player, "Berries")
	local w = Inv:Count(player, "Wood")
	Build:Cook(player, "BerryPie")
	task.wait(0.3)
	check("cook_pie", Inv:Count(player, "BerryPie") == 1 and Inv:Count(player, "Berries") == b - 5 and Inv:Count(player, "Wood") == w - 1,
		string.format("pie=%d berries %d->%d wood %d->%d", Inv:Count(player, "BerryPie"), b, Inv:Count(player, "Berries"), w, Inv:Count(player, "Wood")))
	Inv:Remove(player, "Berries", Inv:Count(player, "Berries"))
	local okNo = not Build:Cook(player, "BerryPie")
	check("cook_pie_no_berries", okNo and Inv:Count(player, "BerryPie") == 1, "")
	-- กินพาย: หิว +40 · หิวช้าลงครึ่งหนึ่ง (เทียบอัตราก่อน/หลัง 6 วิ)
	player:SetAttribute("Hunger", 50)
	local h0 = player:GetAttribute("Hunger")
	task.wait(6)
	local normal = h0 - player:GetAttribute("Hunger")
	player:SetAttribute("Hunger", 50)
	Surv:UseItem(player, "BerryPie")
	task.wait(0.2)
	local h1 = player:GetAttribute("Hunger")
	task.wait(6)
	local slowed = h1 - player:GetAttribute("Hunger")
	check("eat_pie", math.abs(h1 - 90) < 1 and slowed < normal * 0.65 and slowed > 0,
		string.format("hunger=%.1f drain6s normal=%.2f pie=%.2f", h1, normal, slowed))
	-- โชว์ของใหม่ในมือ/แถบ
	Inv:Add(player, "HerbSalve", 2)
	Inv:Add(player, "BerryJuice", 1)
	task.wait(1.5)
	shot("berry_items")
	print("[TEST] DONE probe")
	return
end
-- --bossskill=Music : เพลงบอสต้องดังเฉพาะตอนอยู่ใกล้บอส (<= 90) และเงียบเมื่อหนีออกไปเกิน 100
if ReplicatedStorage:FindFirstChild("ASBossOnly") and ReplicatedStorage.ASBossOnly.Value == "Music" then
	local AnimalService = require(Server:WaitForChild("AnimalService"))
	player:SetAttribute("Class", "Survivor")
	require(Server:WaitForChild("LobbyService")):Depart(player)
	require(Server:WaitForChild("DirectorService")):StartRun()
	task.wait(8)
	local r = player.Character.HumanoidRootPart
	local o = r.Position
	local a = AnimalService:Spawn("GolemBoss", o + Vector3.new(0, 3, -40), { Kind = "Boss" })
	if not a then
		for id, info in pairs(require(ReplicatedStorage.Shared.Animals).Data) do
			if info.Behaviour == "Boss" then
				a = AnimalService:Spawn(id, o + Vector3.new(0, 3, -40), { Kind = "Boss" })
				if a then break end
			end
		end
	end
	a.Root.Anchored = true
	a.Model:SetAttribute("IsBoss", true)
	ReplicatedStorage.GameState:SetAttribute("BossId", a.Id)
	local function at(tag, offset)
		standAt(Vector3.new(o.X + offset.X, o.Y, o.Z + offset.Z), a.Root.Position)
		task.wait(6)
		player:SetAttribute("ProbeMusic", tag)
		task.wait(1)
	end
	at("near_40", Vector3.new(0, 0, 0))
	at("far_160", Vector3.new(0, 0, 120))
	at("edge_95", Vector3.new(0, 0, 55))
	at("back_30", Vector3.new(0, 0, -10))
	ReplicatedStorage.GameState:SetAttribute("BossId", "")
	at("boss_dead_flag", Vector3.new(0, 0, -10))
	print("[TEST] DONE probe")
	return
end
-- --bossskill=Hotbar : ทำช่อง 1 ว่าง (ขวานหาย) แล้วรอ -> แถบเครื่องมือต้องไม่งอกไอเทมซ้ำ · ใส่ของกลับ/ถือ/สลับ ต้องตรงจำนวนจริงเสมอ
if ReplicatedStorage:FindFirstChild("ASBossOnly") and ReplicatedStorage.ASBossOnly.Value == "Hotbar" then
	local Inv = require(Server:WaitForChild("InventoryService"))
	player:SetAttribute("Class", "Survivor")
	require(Server:WaitForChild("LobbyService")):Depart(player)
	require(Server:WaitForChild("DirectorService")):StartRun()
	task.wait(8)
	local function check(tag, wait)
		task.wait(wait or 3)
		player:SetAttribute("ProbeHotbar", tag)
		task.wait(1.5)
	end
	check("start")
	-- ช่อง 1 (ขวาน) หาย -> ช่องว่างหน้าแถว
	Inv:Remove(player, "OldAxe", 1)
	Inv:DestroyTool(player, "OldAxe")
	check("slot1_empty", 4)
	check("slot1_empty_later", 4)
	-- ได้ของใหม่ + ถือ/เก็บสลับไปมา
	Inv:Add(player, "Spear", 1)
	Inv:Add(player, "Pickaxe", 1)
	check("add_tools")
	for _, id in ipairs({ "Spear", "Torch", "Pickaxe", "Spear" }) do
		Inv:EquipItem(player, id)
		task.wait(0.4)
	end
	check("equip_cycle")
	-- เปลี่ยนกระสอบ (ช่องกลางหาย/เกิดใหม่)
	Inv:Add(player, "GoodSack", 1)
	check("sack_swap")
	Inv:Remove(player, "Torch", 1)
	Inv:DestroyTool(player, "Torch")
	check("torch_gone", 4)
	print("[TEST] DONE probe")
	return
end
-- --bossskill=Dup : ตาย/เกิดใหม่/กลับล็อบบี้หลายรอบ -> เช็ก Tool ซ้ำ (server) + ช่องแถบเครื่องมือ (client)
if ReplicatedStorage:FindFirstChild("ASBossOnly") and ReplicatedStorage.ASBossOnly.Value == "Dup" then
	local Surv = require(Server:WaitForChild("SurvivalService"))
	local Lobby = require(Server:WaitForChild("LobbyService"))
	local function report(tag)
		local n, list = {}, {}
		for _, holder in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
			for _, t in ipairs(holder and holder:GetChildren() or {}) do
				if t:IsA("Tool") then
					local id = t:GetAttribute("ItemId") or t:GetAttribute("StructureKind") or t.Name
					n[id] = (n[id] or 0) + 1
				end
			end
		end
		local dup = false
		for id, c in pairs(n) do
			table.insert(list, id .. "=" .. c)
			dup = dup or c > 1
		end
		table.sort(list)
		print(string.format("[DUP] %s %s server: %s", dup and "FAIL" or "PASS", tag, table.concat(list, " ")))
		player:SetAttribute("ProbeHotbar", tag)
		task.wait(1.2)
	end
	local function die()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = 0
		end
		local old = player.Character
		local t0 = os.clock()
		repeat
			task.wait(0.5)
		until (player.Character ~= old and player.Character and player.Character:FindFirstChild("HumanoidRootPart")) or os.clock() - t0 > 30
		task.wait(3)
	end
	player:SetAttribute("Class", "Survivor")
	Lobby:Depart(player)
	require(Server:WaitForChild("DirectorService")):StartRun()
	task.wait(5)
	report("depart")
	for i = 1, 3 do
		die()
		report("respawn" .. i)
	end
	for i = 1, 2 do
		Surv:ResetPlayer(player)
		task.wait(4)
		report("lobby" .. i)
		Lobby:Depart(player)
		task.wait(5)
		report("redepart" .. i)
		die()
		report("redepart" .. i .. "_respawn")
	end
	print("[TEST] DONE probe")
	return
end
-- --bossskill=Camp : ถ่ายภาพกองไฟล็อบบี้ + กองไฟแคมป์ในรอบจริง (เช็กหน้าตาไฟ)
if ReplicatedStorage:FindFirstChild("ASBossOnly") and ReplicatedStorage.ASBossOnly.Value == "Camp" then
	local function lookShot(target, offsets, prefix)
		for i, o in ipairs(offsets) do
			player:SetAttribute("ProbeFrom", target + o)
			player:SetAttribute("ProbeAt", target + Vector3.new(0, 1.5, 0))
			player:SetAttribute("ProbeCam", "look")
			task.wait(2)
			shot(prefix .. i)
			task.wait(0.6)
		end
	end
	local offsets = { Vector3.new(9, 5, 9), Vector3.new(-12, 3, 4), Vector3.new(0, 14, -10) }
	local lf = workspace:FindFirstChild("LobbyFire", true)
	print("[CAMP] lobby fire", lf and lf:GetFullName())
	if lf then
		lookShot(lf.Position, offsets, "lobbyfire_")
	end
	player:SetAttribute("ProbeCam", "")
	require(Server:WaitForChild("LobbyService")):Depart(player)
	require(Server:WaitForChild("DirectorService")):StartRun()
	local tw = os.clock()
	repeat
		task.wait(0.5)
	until player:GetAttribute("InRun") or os.clock() - tw > 30
	task.wait(6)
	local camp = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Sites") and workspace.World.Sites:FindFirstChild("Camp")
	local core = camp and camp:FindFirstChild("FireCore", true)
	print("[CAMP] camp fire core", core and core:GetFullName())
	if core then
		for _, d in ipairs(core.Parent:GetDescendants()) do
			if d:IsA("ParticleEmitter") or d:IsA("Fire") then
				print("[CAMP] fx", d:GetFullName(), d.ClassName, d.Enabled)
			end
		end
		local function scan(tag)
			local seen = {}
			for _, part in ipairs(workspace:GetDescendants()) do
				if part:IsA("BasePart") and not part:IsDescendantOf(core.Parent) and part.Transparency < 1 then
					local d = (part.Position - core.Position) * Vector3.new(1, 0, 1)
					if d.Magnitude < 7 and math.abs(part.Position.Y - core.Position.Y) < 12 then
						local top = part
						while top.Parent and top.Parent ~= workspace and top.Parent.Parent ~= workspace.World and top.Parent.Parent ~= workspace.World.Sites do
							top = top.Parent
						end
						local key = top:GetFullName() .. " <" .. part.Name .. " " .. part.ClassName .. ">"
						if not seen[key] then
							seen[key] = true
							print("[CAMP] " .. tag .. " near", key)
						end
					end
				end
			end
		end
		scan("server")
		player:SetAttribute("ProbeScan", core.Position)
		task.wait(1)
		print("[CAMP] fire core at", core.Position, "camp pivot", camp:GetPivot().Position)
		lookShot(core.Position, offsets, "campfire_")
	end
	player:SetAttribute("ProbeCam", "")
	print("[TEST] DONE probe")
	return
end
-- --bossskill=Staff : ทดสอบคทาเพลิง (ยิงลูกไฟใส่หมาป่า + ฟาดต้นไม้) แล้วจบ
local onlyStaff = ReplicatedStorage:FindFirstChild("ASBossOnly") and ReplicatedStorage.ASBossOnly.Value == "Staff"
if onlyStaff then
	local Combat = require(Server:WaitForChild("CombatService"))
	local Inv = require(Server:WaitForChild("InventoryService"))
	local Res = require(Server:WaitForChild("ResourceService"))
	-- เลือกคลาสจอมเวท (ต้องได้คทาเองตอนออกเดินทาง) -> ออกจากล็อบบี้ + เริ่มรอบจริง (ในล็อบบี้ถือของไม่ได้)
	player:SetAttribute("Class", "Elementalist")
	require(Server:WaitForChild("SurvivalService")):OnClassChosen(player, "Elementalist")
	require(Server:WaitForChild("LobbyService")):Depart(player)
	require(Server:WaitForChild("DirectorService")):StartRun()
	local tw = os.clock()
	repeat
		task.wait(0.5)
	until player:GetAttribute("InRun") or os.clock() - tw > 30
	task.wait(3)
	print("[STAFF] inRun", player:GetAttribute("InRun"))
	task.wait(1.5)
	local tool
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t:GetAttribute("ItemId") == "EmberStaff" then
			tool = t
		end
	end
	local names = {}
	for _, t in ipairs(player.Backpack:GetChildren()) do
		table.insert(names, tostring(t:GetAttribute("ItemId")))
	end
	print("[STAFF] class", player:GetAttribute("Class"), "start tools:", table.concat(names, ","), "staff", tool ~= nil)
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	if tool then
		hum:EquipTool(tool)
	end
	local o = cp + Vector3.new(0, 0, -60)
	local gy = ground(o.X, o.Z)
	standAt(Vector3.new(o.X, gy, o.Z), Vector3.new(o.X, gy, o.Z - 40))
	local w = AnimalService:Spawn("MossWolf", Vector3.new(o.X, gy + 3, o.Z - 36), {})
	if w then
		w.Model:SetAttribute("IsBoss", true) -- ให้กล้องมุมข้างจับทั้งคู่
		w.Root.Anchored = true -- ยืนนิ่งเป็นเป้า
	end
	task.wait(1.5)
	player:SetAttribute("ProbeCam", "side")
	task.wait(0.5)
	shot("staff_hold")
	local r = player.Character.HumanoidRootPart
	for i = 1, 4 do
		local hp0 = w and w.Hum.Health or -1
		local aim = w and (w.Root.Position - (r.Position + Vector3.new(0, 1.5, 0))).Unit or r.CFrame.LookVector
		-- คลิกจริงฝั่งผู้เล่น (Tool:Activate -> CombatClient -> Remote Attack -> server)
		player:SetAttribute("ProbeTarget", w and w.Root.Position or r.Position + r.CFrame.LookVector * 30)
		player:SetAttribute("ProbeCam", "aimwolf")
		task.wait(0.3)
		local fx0 = #workspace.FX:GetChildren()
		player:SetAttribute("ProbeClick", i)
		task.wait(0.1)
		print("[STAFF] equipped", player.Character:FindFirstChildOfClass("Tool"), "fireball spawned", #workspace.FX:GetChildren() > fx0)
		player:SetAttribute("ProbeCam", "side") -- ถ่ายจากด้านข้าง (เห็นทั้งผู้เล่น ลูกไฟ และเป้า)
		task.wait(0.06)
		shot("staff_fly_" .. i)
		task.wait(0.3)
		shot("staff_hit_" .. i)
		print(string.format("[STAFF] shot %d wolf hp %.0f -> %.0f dead=%s", i, hp0, w and w.Hum.Health or -1, tostring(w and w.Dead)))
		task.wait(0.5)
	end
	-- ฟาดต้นไม้ (ไม่มีสัตว์ใกล้)
	if w and not w.Dead then
		AnimalService:Remove(w)
	end
	local node = Res:FindNode(r.Position, 400)
	print("[STAFF] tree node", node ~= nil)
	if node then
		local np = node:GetPivot().Position
		if np then
			local d = ((r.Position - np) * Vector3.new(1, 0, 1)).Unit
			standAt(np + d * 4.5, np)
			task.wait(1)
			local before = node:GetAttribute("HP")
			Combat.lastAttack[player] = 0
			Combat:OnAttack(player, -d)
			task.wait(0.4)
			print(string.format("[STAFF] chop node hp %s -> %s", tostring(before), tostring(node:GetAttribute("HP"))))
		end
	end
	player:SetAttribute("ProbeCam", "")
	print("[TEST] DONE probe")
	return
end
local list = { "Terragon", "Leviathan", "TempestRoc", "Solfang" }
local only = ReplicatedStorage:FindFirstChild("ASBossOnly")
if only and only.Value ~= "" then
	list = string.split(only.Value, ",")
end
-- "Id:Skill" = เทสเฉพาะสกิลเดียว (เช่น Solfang:MeteorRoar)
local onlySkill = {}
for i, v in ipairs(list) do
	local id, ab = string.match(v, "^(%w+):(%w+)$")
	if id then
		list[i], onlySkill[id] = id, ab
	end
end
local origin = cp + Vector3.new(0, 0, -50) -- ลานโล่งหน้าแคมป์
-- ถางต้นไม้/ของประดับรอบลานทดสอบ (กล้องมุมข้างไม่โดนบัง) — เฉพาะในเทสต์
do
	local world = workspace:FindFirstChild("World")
	local n = 0
	for _, d in ipairs(world and world:GetDescendants() or {}) do
		if d:IsA("Model") and d:GetAttribute("Kind") and d.Parent and not d:FindFirstAncestor("Camp") then
			local p = d:GetPivot().Position
			if ((p - origin) * Vector3.new(1, 0, 1)).Magnitude < 210 then
				d:Destroy()
				n += 1
			end
		end
	end
	print("[AS] BOSSSKILL cleared props " .. n)
end
for _, id in ipairs(list) do
	local info = Animals.Data[id]
	local a = info and AnimalService:Spawn(id, Vector3.new(origin.X, ground(origin.X, origin.Z) + 2, origin.Z), { Kind = "Boss" })
	if not a then
		print("[AS] BOSSSKILL missing " .. id)
		continue
	end
	a.Model:SetAttribute("IsBoss", true)
	a.NextAbility = math.huge -- ห้ามสุ่มใช้สกิลเอง (เทสต์สั่งทีละท่า)
	local bp = a.Root.Position
	standAt(bp + Vector3.new(0, 0, 55), bp)
	task.wait(5)
	player:SetAttribute("ProbeCam", "side")
	task.wait(0.6)
	shot(id .. "_idle")
	-- ซูมหน้าตอนคำราม (ดูปาก/คอ/หัว)
	player:SetAttribute("ProbeCam", "face")
	a.Model:SetAttribute("Cast", "Roar")
	a.Model:SetAttribute("CastTime", 1)
	a.Model:SetAttribute("CastAt", workspace:GetServerTimeNow())
	task.wait(1.15)
	shot(id .. "_roarface")
	task.wait(1.2)
	a.Model:SetAttribute("Cast", nil)
	for i, ab in ipairs(info.Abilities or {}) do
		if onlySkill[id] and onlySkill[id] ~= ab then
			continue
		end
		-- ย้ายผู้เล่นไปอีกทิศ (90° ต่อสกิล) -> บอสต้องหันก่อนปล่อย
		local ang = i * math.pi / 2
		bp = a.Root.Position
		local stand = bp + Vector3.new(math.sin(ang) * 52, 0, math.cos(ang) * 52)
		standAt(Vector3.new(stand.X, ground(stand.X, stand.Z), stand.Z), bp)
		player:SetAttribute("ProbeCam", "side")
		task.wait(0.4)
		print(string.format("[AS] BOSSSKILL %s %s", id, ab))
		BossAbilities.Run(ctx, a, ab, player)
		local t0 = os.clock()
		for _, t in ipairs({ 0.6, 1.3, 1.9, 2.8 }) do
			while os.clock() - t0 < t do
				task.wait()
			end
			-- ทิศหน้าบอสเทียบทิศไปหาผู้เล่น (องศา) — สกิลแนวตรงต้องเกือบ 0 ตอนปล่อย
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if r then
				local to = ((r.Position - a.Root.Position) * Vector3.new(1, 0, 1)).Unit
				local fw = (a.Root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
				print(string.format("[BOSSDIR] %s %s t=%.1f off=%.0f", id, ab, t, math.deg(math.acos(math.clamp(fw:Dot(to), -1, 1)))))
			end
			shot(string.format("%s_%s_%02d", id, ab, math.floor(t * 10)))
		end
		while a.Casting and os.clock() - t0 < 12 do
			task.wait(0.2)
		end
		task.wait(1.2)
	end
	player:SetAttribute("ProbeCam", "")
	AnimalService:Remove(a)
	task.wait(2)
end
print("[TEST] DONE probe")
