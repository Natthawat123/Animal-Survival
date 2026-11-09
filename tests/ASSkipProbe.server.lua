--[[ ASSkipProbe (server) — build_rbxlx.py --skipprobe
	เช็กระบบนับคืน + ข้ามวัน (เตียง/ศาลเจ้า +1 รวม +6) + ฝูงบุกทุกคืน + คืนบอส ด้วย DirectorService ตัวจริง
	ผล: "[AS] SKIPPROBE PASS/FAIL ..." ทีละข้อ · จบด้วย "[AS] SKIPPROBE DONE" ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASSkipProbe") then
	return
end
local Nights = require(ReplicatedStorage.Shared.Nights)
local Config = require(ReplicatedStorage.Shared.Config)
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(3)

local Dir = require(game:GetService("ServerScriptService").Server.DirectorService)
local S = Dir.ctx.Services
local st = Dir.ctx.State
local fails = 0
local function check(name, ok, detail)
	if not ok then
		fails += 1
	end
	print(string.format("[AS] SKIPPROBE %s %s %s", ok and "PASS" or "FAIL", name, detail and tostring(detail) or ""))
end
-- รอจนเงื่อนไขจริง (คืน false ถ้าเกินเวลา)
local function waitFor(fn, timeout)
	local t0 = os.clock()
	while not fn() do
		if os.clock() - t0 > timeout then
			return false
		end
		task.wait(0.2)
	end
	return true
end
local function phaseIs(p)
	return function()
		return st:GetAttribute("Phase") == p
	end
end
-- ผู้เล่นไม่ตายระหว่างเทสต์
task.spawn(function()
	while true do
		task.wait(0.2)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Health = hum.MaxHealth
		end
	end
end)
-- ไปหน้าถัดไปจนถึงช่วงที่ต้องการ
local function goto_(phase)
	while st:GetAttribute("Phase") ~= phase do
		Dir.skip = true
		task.wait(0.6)
	end
end

---------------------------------------------------------------- จำนวนมอนตามคืน (1 คน)
local rng = Random.new(7)
local last = 0
for _, n in ipairs({ 1, 2, 4, 5, 9, 10, 20, 24, 25, 30, 50, 75, 98, 99, 100 }) do
	local lo, hi = math.huge, 0
	for _ = 1, 30 do
		local el = Nights.PickElement(n, rng, nil)
		local plan = Nights.Plan(n, rng, el, 1)
		local c = 0
		for _, w in ipairs(plan.Waves) do
			if not w.Boss then
				c += #w.Spawns
			end
		end
		lo, hi = math.min(lo, c), math.max(hi, c)
		if (c > 0) ~= Nights.IsBigRaid(n) then
			check("plan-count night " .. n, false, c)
		end
	end
	print(string.format("[AS] SKIPPROBE count night=%d big=%s min=%d max=%d cap=%d", n, tostring(Nights.IsBigRaid(n)), lo, hi, Nights.MaxCount(n, 1)))
	last = hi
end
check("plan-99-has-swarm", last > 0)
do
	local p = Nights.Plan(99, rng, "Fire", 1)
	local swarm = 0
	for _, w in ipairs(p.Waves) do
		if not w.Boss then
			swarm += #w.Spawns
		end
	end
	check("night99-swarm+boss", swarm > 0 and p.Boss == "Solfang", swarm)
	local cb = Nights.Plan(26, rng, "Earth", 1, { Boss = "Terragon", BossNight = 25, BigRaid = true })
	check("carry-boss", cb.Boss == "Terragon" and cb.BigRaid and cb.OriginNight == 25)
	local cm = Nights.Plan(11, rng, "Earth", 1, { BloodMoonNight = 10, BigRaid = true })
	check("carry-bloodmoon", cm.BloodMoon and cm.Element == "All" and cm.Elements ~= nil)
end

---------------------------------------------------------------- ข้ามตอนกลางวัน = มีผลทันที + นับรอด
goto_("Day")
Dir.night = 4
st:SetAttribute("Night", 4)
-- เครื่องย่อย: ถืออาวุธแล้วย่อย -> ได้วัตถุดิบตามสูตรคืน (IronSword = Iron 8 · Wood 4 · Pelt 1)
do
	local Camp = S.CampService
	local inv = S.InventoryService
	local hop = Camp.hopper
	check("salvage-prompt", hop ~= nil and hop:FindFirstChild("Salvage") ~= nil)
	check("salvage-list", Camp.SalvageCost("Katana") ~= nil and Camp.SalvageCost("FourfoldBlade") ~= nil and Camp.SalvageCost("EmberStaff") == nil and Camp.SalvageCost("OldSack") == nil)
	if hop then
		player.Character:PivotTo(CFrame.new(hop.Position + Vector3.new(0, 3, 9)))
		task.wait(0.5)
		inv:Add(player, "IronSword", 1, true)
		task.wait(0.4)
		inv:EquipItem(player, "IronSword")
		task.wait(0.6)
		local c = inv.Camp
		local i0, w0, p0 = c.Iron or 0, c.Wood or 0, c.Pelt or 0
		Camp:SalvageHeld(player)
		local ok = waitFor(function()
			return (inv.Camp.Iron or 0) >= i0 + 8
		end, 6)
		c = inv.Camp
		check("salvage-held", ok and (c.Wood or 0) - w0 == 4 and (c.Pelt or 0) - p0 == 1 and inv:Count(player, "IronSword") == 0,
			string.format("iron +%d wood +%d pelt +%d sword %d", (c.Iron or 0) - i0, (c.Wood or 0) - w0, (c.Pelt or 0) - p0, inv:Count(player, "IronSword")))
		-- ของธาตุ "ไหนก็ได้": อาวุธไม่มีธาตุ -> สุ่มแก่นธาตุ 2 ชิ้น
		local got = {}
		Camp:SalvageInto("Scythe", 1, got)
		local ess = (got.TerraCore or 0) + (got.TidePearl or 0) + (got.GaleFeather or 0) + (got.EmberShard or 0)
		check("salvage-any-essence", got.Iron == 20 and got.Bone == 8 and ess == 2 and got.AnyEssence == nil, string.format("iron %s bone %s ess %d", tostring(got.Iron), tostring(got.Bone), ess))
		-- อาวุธที่ตกเฉย ๆ (ไม่มีใครทิ้ง) ไม่ถูกดูดเข้าเครื่อง
		S.DropService:Spawn("Katana", 1, hop.Position + Vector3.new(3, 2, 3), {})
		task.wait(1.5)
		local loose = 0
		for _, d in ipairs(S.DropService:Near(hop.Position, 20, 30)) do
			if d.Id == "Katana" then
				loose += 1
				S.DropService:Remove(d.Model)
			end
		end
		check("salvage-ignores-loose", loose == 1, loose)
	end
end
-- อาวุธซ้ำได้: แยกช่องทีละชิ้น · ทิ้ง/เก็บ/กลับเข้าเกม ไม่งอก
do
	local inv = S.InventoryService
	local drops = S.DropService
	local hop = S.CampService.hopper
	local away = (hop and hop.Position or player.Character:GetPivot().Position) + Vector3.new(70, 4, 0)
	player.Character:PivotTo(CFrame.new(away)) -- ห่างเครื่องย่อย (ทิ้งข้างเครื่อง = โดนย่อย)
	task.wait(0.6)
	local function tools(id)
		local n, multi = 0, true
		for _, h in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
			for _, x in ipairs(h and h:GetChildren() or {}) do
				if x:IsA("Tool") and x:GetAttribute("ItemId") == id then
					n += 1
					multi = multi and x:GetAttribute("Multi") == true
				end
			end
		end
		return n, multi
	end
	local c0 = inv:Count(player, "Katana")
	inv:Add(player, "Katana", 1, true)
	inv:Add(player, "Katana", 1, true)
	task.wait(2.6) -- ผ่านรอบกวาด Tool ซ้ำ (ทุก 2 วิ)
	local n1, m1 = tools("Katana")
	check("multi-two-slots", inv:Count(player, "Katana") == c0 + 2 and n1 == c0 + 2 and m1, string.format("count %d tools %d multi %s", inv:Count(player, "Katana"), n1, tostring(m1)))
	inv:Add(player, "StoneAxe", 1, true)
	inv:Add(player, "StoneAxe", 1, true)
	task.wait(0.4)
	check("single-tool-stays-1", inv:Count(player, "StoneAxe") == 1 and tools("StoneAxe") == 1, inv:Count(player, "StoneAxe"))
	-- ทิ้งอันในมือ 1 อัน -> เหลือ 1 · ของบนพื้น 1
	inv:EquipItem(player, "Katana")
	task.wait(0.4)
	drops:DropHeld(player)
	task.wait(0.6)
	local n2 = tools("Katana")
	local onGround
	for _, d in ipairs(drops:Near(player.Character:GetPivot().Position, 14, 12)) do
		if d.Id == "Katana" then
			onGround = d.Model
		end
	end
	check("multi-drop-one", inv:Count(player, "Katana") == c0 + 1 and n2 == c0 + 1 and onGround ~= nil, string.format("count %d tools %d ground %s", inv:Count(player, "Katana"), n2, tostring(onGround ~= nil)))
	-- กดเก็บรัว 3 ครั้งพร้อมกัน = ได้คืนแค่ 1
	if onGround then
		for _ = 1, 3 do
			task.spawn(function()
				drops:Pickup(player, onGround)
			end)
		end
	end
	task.wait(1)
	check("multi-pickup-no-dupe", inv:Count(player, "Katana") == c0 + 2 and tools("Katana") == c0 + 2, inv:Count(player, "Katana"))
	-- ลากช่องออกจากแถบไปปล่อยข้างนอก (มือถือ) = ทิ้งชิ้นนั้น แม้ไม่ได้ถืออยู่
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	hum:UnequipTools()
	task.wait(0.3)
	local pickT
	for _, x in ipairs(player.Backpack:GetChildren()) do
		if x:IsA("Tool") and x:GetAttribute("ItemId") == "Katana" then
			pickT = x
		end
	end
	local k0 = inv:Count(player, "Katana")
	drops:DropHeld(player, pickT)
	task.wait(0.5)
	check("drag-drop-tool", pickT ~= nil and pickT.Parent == nil and inv:Count(player, "Katana") == k0 - 1 and tools("Katana") == k0 - 1,
		string.format("count %d -> %d", k0, inv:Count(player, "Katana")))
	inv:Add(player, "Katana", 1, true)
	task.wait(0.3)
	-- กลับเข้าเกม: มีของเริ่มต้นอยู่แล้ว + คืนจากเซฟ = เท่าที่เซฟไว้พอดี (ไม่บวกซ้อน)
	local saved = {}
	for id, n in pairs(inv:Get(player)) do
		saved[id] = n
	end
	saved.Bow = 2
	inv:Add(player, "Bow", 1, true) -- (เหมือนอาชีพนักล่าได้ธนูเริ่มต้น)
	inv:RestoreBag(player, saved)
	inv:RestoreBag(player, saved)
	task.wait(0.4)
	check("rejoin-no-dupe", inv:Count(player, "Bow") == 2 and tools("Bow") == 2 and inv:Count(player, "Katana") == c0 + 2, string.format("bow %d tools %d katana %d", inv:Count(player, "Bow"), tools("Bow"), inv:Count(player, "Katana")))
end
local ruby0 = S.DataService:Get(player).Diamonds or 0
local best0 = S.DataService:Get(player).BestNight or 0
local function shot(name, delay)
	ReplicatedStorage:SetAttribute("SkipShot", name .. ":" .. delay .. ":" .. os.clock())
end
local bonus0 = st:GetAttribute("BonusDays") or 0
check("day-skip-returns", Dir:SkipDay(player, nil, "Bed") == true)
shot("bed_fly", 0.35)
check("day-skip-night", Dir.night == 5 and st:GetAttribute("Night") == 5, Dir.night)
check("bonus-bed", (st:GetAttribute("BonusDays") or 0) == bonus0 + 1 and st:GetAttribute("BonusSource") == "Bed", st:GetAttribute("BonusDays"))
task.wait(2.6)
shot("bed_after", 0)
task.wait(1.5)
Dir:SkipDay(player, "🌟 Rescued pup — skipped 1 day! Now day %d", "Spirit Pup")
shot("pup_fly", 0.35)
check("bonus-pup", (st:GetAttribute("BonusDays") or 0) == bonus0 + 2 and st:GetAttribute("BonusSource") == "Spirit Pup" and Dir.night == 6, st:GetAttribute("BonusDays"))
task.wait(2.6)
shot("pup_after", 0)
task.wait(1.5)
-- ลูกสัตว์ธาตุไฟ = ข้าม 4 วันในครั้งเดียว (Config.SpiritBonusDays)
check("spirit-days-config", Config.SpiritBonusDays.Earth == 1 and Config.SpiritBonusDays.Water == 2 and Config.SpiritBonusDays.Air == 3 and Config.SpiritBonusDays.Fire == 4 and Config.ShrineGuardianMult == 1.5)
local msg
Dir:SkipDay(player, function(k, day)
	msg = string.format("🌟 Rescued %s — skipped %d days! Now day %d", "Ember Pup", k, day)
	return msg
end, "Spirit Pup", Config.SpiritBonusDays.Fire)
shot("fire_pup_fly", 0.35)
check("multi-skip-night", Dir.night == 10 and st:GetAttribute("Night") == 10, Dir.night)
check("multi-skip-bonus", (st:GetAttribute("BonusDays") or 0) == bonus0 + 6, st:GetAttribute("BonusDays"))
check("multi-skip-msg", msg ~= nil and msg:find("skipped 4 days") ~= nil and msg:find("day 10") ~= nil, msg)
task.wait(2.6)
shot("fire_pup_after", 0)
task.wait(1.5)
check("day-skip-best", (S.DataService:Get(player).BestNight or 0) >= math.max(best0, 4), S.DataService:Get(player).BestNight)
check("day-skip-ruby", (S.DataService:Get(player).Diamonds or 0) > ruby0, (S.DataService:Get(player).Diamonds or 0) - ruby0)

---------------------------------------------------------------- ข้ามคืนบอส: บอสย้ายมาคืนถัดไป
Dir.night = 25
st:SetAttribute("Night", 25)
Dir:SkipDay(player)
check("boss-skip-night", Dir.night == 26)
check("boss-skip-carry", Dir.carry.Boss == "Terragon" and Dir.carry.BossNight == 25 and Dir.carry.BigRaid == true)
goto_("Night")
check("boss-night-is-26", st:GetAttribute("Night") == 26)
check("boss-carried-spawned", waitFor(function()
	return st:GetAttribute("BossId") == "Terragon"
end, Config.NightLength * 0.3), st:GetAttribute("BossId"))
check("raid-spawned", waitFor(function()
	return S.AnimalService.raidCount > 0
end, Config.NightLength * 0.3), S.AnimalService.raidCount)

---------------------------------------------------------------- ข้ามตอนกลางคืน: เลขไม่เปลี่ยนจนถึงเช้า
Dir:SkipDay(player)
check("night-skip-queued", Dir.pendingSkips == 1 and Dir.night == 26 and st:GetAttribute("Night") == 26, Dir.pendingSkips)
check("pending-attr", st:GetAttribute("PendingDays") == 1, st:GetAttribute("PendingDays"))
shot("night_pending_fly", 0.35)
task.delay(2.6, function()
	shot("night_pending_after", 0)
end)
local bonusBeforeDawn = st:GetAttribute("BonusDays") or 0

---------------------------------------------------------------- บอสไม่ตาย = ยังไม่เช้า · ฆ่าแล้วเช้าตามปกติ
check("boss-hold-started", waitFor(function()
	return (st:GetAttribute("BossHoldEnd") or 0) > 0
end, Config.NightLength + 5))
local holdStart = os.clock()
task.wait(Config.NightLength * 0.3 + 3) -- เลยเวลาที่ควรจะเช้าไปแล้ว
check("boss-hold-keeps-night", st:GetAttribute("Phase") == "Night", st:GetAttribute("Phase"))
local boss = Dir.nightBoss
check("boss-ref", boss ~= nil and not boss.Dead)
S.AnimalService:TakeDamage(boss, 1e9, player, {})
check("boss-dead-hold-ends", waitFor(function()
	return (st:GetAttribute("BossHoldEnd") or 0) == 0
end, 3), os.clock() - holdStart)
check("dawn-after-boss", waitFor(phaseIs("Day"), Config.NightLength * 0.15 + 5))
check("pending-applied", Dir.night == 28 and st:GetAttribute("Night") == 28 and Dir.pendingSkips == 0, Dir.night)
check("pending-bonus", (st:GetAttribute("BonusDays") or 0) == bonusBeforeDawn + 1 and st:GetAttribute("PendingDays") == 0, st:GetAttribute("BonusDays"))
shot("dawn_applied", 2.8)
task.wait(3.5)
check("carry-cleared", next(Dir.carry) == nil)

---------------------------------------------------------------- ใกล้คืน 99: ถึง 99 ได้ เลยไม่ได้ · สิทธิ์เหลือไปต่อหลังจบ
Dir.night = 97
st:SetAttribute("Night", 97)
Dir:SkipDay(player)
Dir:SkipDay(player)
check("land-on-99", Dir.night == 99, Dir.night)
check("99-skip-still-ok", Dir:SkipDay(player) == true)
check("99-skip-queued", Dir.night == 99 and Dir.pendingSkips == 1, Dir.pendingSkips)
goto_("Night")
check("night-99-played", st:GetAttribute("Night") == 99 and st:GetAttribute("NightElement") == "All")
check("99-swarm", waitFor(function()
	return S.AnimalService.raidCount > 0
end, Config.NightLength * 0.3), S.AnimalService.raidCount)
check("99-boss", waitFor(function()
	return st:GetAttribute("BossId") == "Solfang"
end, Config.NightLength * 0.3), st:GetAttribute("BossId"))
goto_("Day")
check("99-conquered", st:GetAttribute("Conquered") == true)
check("after-99-pending-applied", Dir.night == 101 and Dir.pendingSkips == 0, Dir.night)

---------------------------------------------------------------- ข้ามหลายวันใกล้คืน 99: ไปถึง 99 แล้วหยุด ที่เหลือเก็บไว้
goto_("Day")
Dir.night = 97
st:SetAttribute("Night", 97)
Dir.pendingSkips = 0
Dir:SkipDay(player, nil, "Spirit Pup", 5)
check("multi-near-99", Dir.night == 99 and Dir.pendingSkips == 3 and st:GetAttribute("PendingDays") == 3, string.format("night=%d pending=%d", Dir.night, Dir.pendingSkips))
Dir.pendingSkips = 0

---------------------------------------------------------------- กลับเข้ารอบเดิม: สิทธิ์ที่เก็บไว้/บอสที่ย้ายไม่หาย
local R = S.RejoinService
Dir.pendingSkips = 2
Dir.carry = { Boss = "Leviathan", BossNight = 50, BigRaid = true }
local run = game:GetService("HttpService"):JSONDecode(game:GetService("HttpService"):JSONEncode(R:SerializeRun()))
check("rejoin-saved", run.PendingSkips == 2 and run.Carry.Boss == "Leviathan" and run.Carry.BossNight == 50)

print(string.format("[AS] SKIPPROBE RESULT fails=%d", fails))
print("[AS] SKIPPROBE DONE")
