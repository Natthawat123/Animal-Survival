--[[ ASRaidProbe (server) — build_rbxlx.py --raidprobe · ตารางคืนบุกรอบ 7 คืน (3 สัตว์ · 5 พระจันทร์เลือด · 7 คนป่า) + คนป่าบุกแคมป์จริง ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASRaidProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(4)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local Nights = require(ReplicatedStorage.Shared.Nights)
local fails = 0
local function check(name, ok, info)
	if not ok then
		fails += 1
	end
	print(string.format("[AS] RAID %s %s %s", ok and "PASS" or "FAIL", name, tostring(info or "")))
end
local want = { [3] = "Animal", [5] = "Blood", [7] = "Tribe", [10] = "Animal", [12] = "Blood", [14] = "Tribe", [17] = "Animal", [19] = "Blood", [21] = "Tribe" }
local line = {}
for played = 1, 21 do
	local plan = Nights.Plan(played, Random.new(played), "Earth", 1, { Played = played })
	local kind = (plan.Tribe and "Tribe") or (plan.BloodMoon and "Blood") or (plan.BigRaid and "Animal") or "-"
	table.insert(line, played .. "=" .. kind)
	local ok = kind == (want[played] or "-")
	local tribeOnly = true
	for _, w in ipairs(plan.Waves) do
		for _, id in ipairs(w.Spawns) do
			if plan.Tribe and not string.find(id, "^Tribe") then
				tribeOnly = false
			end
			if not plan.Tribe and string.find(id, "^Tribe") then
				tribeOnly = false
			end
		end
	end
	if not ok or not tribeOnly then
		check("night" .. played, false, kind .. " tribeOnly=" .. tostring(tribeOnly))
	end
end
print("[AS] RAID schedule " .. table.concat(line, " "))
check("schedule", fails == 0)
-- คนป่าบุกจริง: เกิดเป็นฝูงบุก (Raid) แล้ววิ่งเข้าหาแคมป์
local plan = Nights.Plan(7, Random.new(7), "Earth", 1, { Played = 7 })
local camp = ctx.CampPosition
local spawned = {}
for _, id in ipairs({ "TribeWarrior", "TribeShield", "TribeArcher" }) do
	local a = ctx.Services.DirectorService:SpawnRaid(id, plan, 7)
	if a then
		table.insert(spawned, { a = a, d0 = (a.Root.Position - camp).Magnitude })
	end
end
check("tribe-spawned", #spawned == 3, #spawned)
task.wait(15)
for _, s in ipairs(spawned) do
	local d1 = s.a.Root and s.a.Root.Parent and (s.a.Root.Position - camp).Magnitude or -1
	check("tribe-advance-" .. s.a.Id, s.a.Kind == "Raid" and d1 >= 0 and d1 < s.d0 - 10, string.format("kind=%s %.0f -> %.0f", s.a.Kind, s.d0, d1))
end
-- คืนคนป่าบุกจริง: ป้ายใหญ่ + ตัวนับที่เหลือ (ลดเมื่อตาย) -> เคลียร์ -> เช้าแล้วหาย
local animals = ctx.Services.AnimalService
local dir = ctx.Services.DirectorService
local s = ctx.State
animals:ClearKind("Raid")
dir.played = 6
dir.night = 7
dir.skip = true
task.delay(0.6, function()
	dir.skip = true
end)
local t0 = os.clock()
repeat
	task.wait(0.2)
until s:GetAttribute("Phase") == "Night" or os.clock() - t0 > 20
task.wait(1.2)
print("[SHOT] raid_banner")
local L0 = s:GetAttribute("RaidLeft") or 0
check("night-kind", s:GetAttribute("RaidKind") == "Tribe", tostring(s:GetAttribute("RaidKind")) .. " total=" .. tostring(s:GetAttribute("RaidTotal")))
check("left-start", L0 > 0 and L0 == s:GetAttribute("RaidTotal"), L0)
t0 = os.clock()
repeat
	task.wait(0.5)
until animals.raidCount > 0 or os.clock() - t0 > 60
task.wait(4)
print("[SHOT] raid_counter")
local L1 = s:GetAttribute("RaidLeft") or 0
local alive = animals.raidCount
animals:ClearKind("Raid")
task.wait(1)
local L2 = s:GetAttribute("RaidLeft") or 0
check("left-drops", alive > 0 and L2 == L1 - alive, string.format("L1=%d alive=%d L2=%d", L1, alive, L2))
dir.raidPending = 0
animals:ClearKind("Raid")
task.wait(1)
check("left-zero", (s:GetAttribute("RaidLeft") or -1) == 0, s:GetAttribute("RaidLeft"))
task.wait(0.5)
print("[SHOT] raid_cleared")
dir.skip = true
t0 = os.clock()
repeat
	task.wait(0.2)
until s:GetAttribute("Phase") == "Day" or os.clock() - t0 > 20
check("dawn-clears", s:GetAttribute("RaidKind") == "" and s:GetAttribute("RaidLeft") == 0, tostring(s:GetAttribute("RaidKind")))
print("[AS] RAID fails=" .. fails)
print("[TEST] DONE raid")
