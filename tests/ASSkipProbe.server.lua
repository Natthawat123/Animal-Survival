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
		if c == 0 then
			check("plan-empty night " .. n, false)
		end
	end
	print(string.format("[AS] SKIPPROBE count night=%d big=%s min=%d max=%d cap=%d", n, tostring(Nights.IsBigRaid(n)), lo, hi, Nights.MaxCount(n, 1, Nights.IsBigRaid(n))))
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
local ruby0 = S.DataService:Get(player).Diamonds or 0
local best0 = S.DataService:Get(player).BestNight or 0
check("day-skip-returns", Dir:SkipDay(player) == true)
check("day-skip-night", Dir.night == 5 and st:GetAttribute("Night") == 5, Dir.night)
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

---------------------------------------------------------------- กลับเข้ารอบเดิม: สิทธิ์ที่เก็บไว้/บอสที่ย้ายไม่หาย
local R = S.RejoinService
Dir.pendingSkips = 2
Dir.carry = { Boss = "Leviathan", BossNight = 50, BigRaid = true }
local run = game:GetService("HttpService"):JSONDecode(game:GetService("HttpService"):JSONEncode(R:SerializeRun()))
check("rejoin-saved", run.PendingSkips == 2 and run.Carry.Boss == "Leviathan" and run.Carry.BossNight == 50)

print(string.format("[AS] SKIPPROBE RESULT fails=%d", fails))
print("[AS] SKIPPROBE DONE")
