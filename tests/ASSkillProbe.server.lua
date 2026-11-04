--[[ ASSkillProbe (server) — build_rbxlx.py --skillprobe
	แวมไพร์: ฆ่าแล้วฮีล 2% · ตีแรง 30% · ฝูงค้างคาว
	พ่อมดมืด: ดาเมจ +30% · ล่องหน (มอนมองไม่เห็น/วิ่งเร็ว/ตีแล้วหลุด) · อุกกาบาตมืด + วงไฟ 2%/วิ
	พงไพร: ฟื้นเลือด 3%/2วิ · วิ่ง +30% · สตั้น 4 วิ (บอส 2 วิ) + พิษ 1%/วิ 15 วิ
	ผล: "[AS] SKILLPROBE PASS/FAIL ..." · จบ "[AS] SKILLPROBE DONE" ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASSkillProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(4)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Items = require(ReplicatedStorage.Shared.Items)
local Dir = require(game:GetService("ServerScriptService").Server.DirectorService)
local ctx = Dir.ctx
local S = ctx.Services
local K = S.SkillService
local fails = 0
local function check(name, ok, detail)
	if not ok then
		fails += 1
	end
	print(string.format("[AS] SKILLPROBE %s %s %s", ok and "PASS" or "FAIL", name, detail and tostring(detail) or ""))
end
local function shot(name, delay)
	ReplicatedStorage:SetAttribute("SkillShot", name .. ":" .. delay .. ":" .. os.clock())
end
player:SetAttribute("TestGod", true)
local hum = player.Character:FindFirstChildOfClass("Humanoid")
local root = player.Character.HumanoidRootPart
-- ที่โล่งนอกแคมป์ (สัตว์ป่าเข้าเขตกองไฟไม่ได้)
local spot = ctx.CampPosition + Vector3.new(90, 0, 0)
local hit = Workspace:Raycast(spot + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0))
spot = hit and hit.Position or spot
player.Character:PivotTo(CFrame.new(spot + Vector3.new(0, 3, 0)))
task.wait(1)
local function setClass(id, lv)
	player:SetAttribute("Class", id)
	player:SetAttribute("ClassLevel", lv)
	for _, sk in ipairs(Classes.ActiveSkills(id, 3)) do
		player:SetAttribute("SkillReady_" .. sk.Id, 0)
	end
	task.wait(0.5)
end
local function wolf(offset)
	return S.AnimalService:Spawn("MossWolf", root.Position + offset, { Kind = "Wild" })
end
local function killAll()
	for _, a in ipairs(S.AnimalService:InRadius(root.Position, 80, false)) do
		if a.Kind == "Wild" then
			S.AnimalService:Kill(a, nil)
		end
	end
end

---------------------------------------------------------------- แวมไพร์
setClass("Vampire", 2)
check("vamp-lv2-no-skill", player:GetAttribute("Skills") == "", player:GetAttribute("Skills"))
check("vamp-dmg30", S.SurvivalService:Perk(player, "DamageMult", 1) == 1.3)
setClass("Vampire", 3)
check("vamp-lv3-swarm", player:GetAttribute("Skills") == "Swarm", player:GetAttribute("Skills"))
hum.Health = 50
local w0 = wolf(Vector3.new(0, 0, 30))
task.wait(0.5)
S.AnimalService:Kill(w0, player)
task.wait(0.3)
check("vamp-kill-heal", hum.Health > 50.5, string.format("%.1f", hum.Health))
hum.Health = hum.MaxHealth
check("swarm-use", K:Use(player, "Swarm") == true)
shot("swarm_summon", 0.25)
task.wait(1)
-- ค้างคาวรับดาเมจแทน 60%
player:SetAttribute("TestGod", nil)
hum.Health = 100
S.SurvivalService:Damage(player, 20, "Test")
local batHurt = false
for _, b in ipairs(K:Bats(player)) do
	if b.HP < 200 then
		batHurt = true
	end
end
check("bats-guard", math.abs(hum.Health - 92) < 0.6 and batHurt, string.format("hp=%.1f", hum.Health))
player:SetAttribute("TestGod", true)
hum.Health = hum.MaxHealth
check("swarm-5", #K:Bats(player) == 5, #K:Bats(player))
check("swarm-cooldown", K:Use(player, "Swarm") == false)
local w1 = wolf(Vector3.new(14, 0, 0))
shot("bats", 2.5)
task.wait(6)
check("bats-damage", w1.Dead or w1.Hum.Health < w1.Hum.MaxHealth)
killAll()

---------------------------------------------------------------- ตีธรรมดา: อาวุธประจำคลาส
local function basic(cls, id)
	setClass(cls, 1)
	S.InventoryService:Add(player, id, 1, true)
	task.wait(0.6)
	local tool
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t:GetAttribute("ItemId") == id then
			tool = t
		end
	end
	if not tool then
		check("basic-tool-" .. id, false)
		return
	end
	hum:EquipTool(tool)
	task.wait(0.8)
	local w = wolf(root.CFrame.LookVector * (Items.Tools[id].Kind == "Staff" and 22 or 7))
	w.Root.Anchored = true
	task.wait(0.8)
	local hp = w.Hum.Health
	local dir = (w.Root.Position - root.Position) * Vector3.new(1, 0, 1)
	S.CombatService.lastAttack[player] = 0
	S.CombatService:OnAttack(player, dir.Unit)
	shot("basic_" .. id .. "_swing", 0.08)
	task.wait(Items.Tools[id].Kind == "Staff" and 0.2 or 0.05)
	shot("basic_" .. id .. "_hit", 0.12)
	task.wait(1.5)
	check("basic-dmg-" .. id, w.Dead or w.Hum.Health < hp, w.Dead and "dead" or string.format("%.0f/%.0f", w.Hum.Health, hp))
	hum:UnequipTools()
	w.Root.Anchored = false
	killAll()
	task.wait(0.5)
end
basic("Vampire", "BloodScythe")
basic("Elementalist", "ArcaneStaff")
basic("Sage", "VerdantStaff")

---------------------------------------------------------------- พ่อมดมืด
setClass("Elementalist", 1)
check("dark-name", Classes.Data.Elementalist.Name == "Dark Sorcerer")
check("dark-dmg30", S.SurvivalService:Perk(player, "DamageMult", 1) == 1.3)
check("dark-lv1-no-skill", player:GetAttribute("Skills") == "")
check("bats-gone-on-class-change", #K:Bats(player) == 0, #K:Bats(player))
setClass("Elementalist", 2)
check("dark-lv2-veil", player:GetAttribute("Skills") == "ShadowVeil", player:GetAttribute("Skills"))
setClass("Elementalist", 3)
check("dark-lv3-two-skills", player:GetAttribute("Skills") == "ShadowVeil,DarkMeteor", player:GetAttribute("Skills"))
-- ล่องหน: มอนข้างตัวไม่เลือกเป็นเป้า
local w2 = wolf(Vector3.new(0, 0, 12))
task.wait(1)
check("veil-target-before", S.AnimalService:PickTarget(w2) == player)
check("veil-use", K:Use(player, "ShadowVeil") == true)
shot("veil_burst", 0.15)
check("veil-invisible", player:GetAttribute("Invisible") == true and player:GetAttribute("SkillSpeed") == 1.5)
check("veil-untargeted", S.AnimalService:PickTarget(w2) == nil)
local head = player.Character:FindFirstChild("Head")
check("veil-transparent", head and head.Transparency > 0.8, head and head.Transparency)
shot("veil", 0.4)
task.wait(1.2)
-- ตีแล้วหลุดล่องหน
S.CombatService:PlayerDamage(player, "ArcaneStaff", Items.Tools.ArcaneStaff, w2)
check("veil-breaks-on-damage", player:GetAttribute("Invisible") == nil and player:GetAttribute("SkillSpeed") == nil)
check("veil-visible-again", head and head.Transparency < 0.5, head and head.Transparency)
-- หมดเวลา 4 วิ เอง
player:SetAttribute("SkillReady_ShadowVeil", 0)
K:Use(player, "ShadowVeil")
task.wait(4.5)
check("veil-expires", player:GetAttribute("Invisible") == nil)
killAll()
task.wait(0.5)
-- อุกกาบาตมืด + วงไฟ
local w3 = wolf(root.CFrame.LookVector * 24)
local w4 = wolf(root.CFrame.LookVector * 24 + Vector3.new(4, 0, 0))
task.wait(1)
w4.Hum.MaxHealth = 100000 -- ตัวอึด: วัดเผาวงไฟ
w4.Hum.Health = 100000
w4.Model:SetAttribute("Health", 100000)
check("meteor-use", K:Use(player, "DarkMeteor", w3.Root.Position) == true)
shot("meteor_portal", 0.2)
task.delay(0.5, function()
	shot("meteor_fall", 0)
end)
task.delay(0.85, function()
	shot("meteor_impact", 0)
end)
task.delay(1.6, function()
	shot("meteor_zone", 0.6)
end)
task.wait(1.2)
check("meteor-impact", w3.Dead or w3.Hum.Health < w3.Hum.MaxHealth, w3.Dead and "dead" or w3.Hum.Health)
local hp4 = w4.Hum.Health
w4.Root.Anchored = true -- อยู่ในวงไฟตลอด
task.wait(3.2)
local burned = hp4 - w4.Hum.Health
check("meteor-burn-2pct", burned >= 100000 * 0.02 * 2.5, string.format("%.0f (expect ~%.0f)", burned, 100000 * 0.02 * 3))
w4.Root.Anchored = false
killAll()
task.wait(0.5)

---------------------------------------------------------------- พงไพร
setClass("Sage", 1)
check("druid-regen", S.SurvivalService:Perk(player, "RegenPct", 0) == 0.015)
hum.Health = 40
task.wait(2.1)
local gain = hum.Health - 40
check("druid-regen-3pct-2s", gain >= hum.MaxHealth * 0.025, string.format("+%.1f in 2s (max %.0f)", gain, hum.MaxHealth))
hum.Health = hum.MaxHealth
setClass("Sage", 2)
check("druid-speed30", S.SurvivalService:Perk(player, "SpeedMult", 1) == 1.3)
check("druid-lv2-no-skill", player:GetAttribute("Skills") == "")
setClass("Sage", 3)
check("druid-lv3-thorn", player:GetAttribute("Skills") == "ThornBind")
local w5 = wolf(Vector3.new(10, 0, 0))
local boss = S.AnimalService:Spawn("MossWolf", root.Position + Vector3.new(-10, 0, 0), { Kind = "Boss" })
task.wait(1)
local hp5 = w5.Hum.Health
check("thorn-use", K:Use(player, "ThornBind") == true)
shot("thorn_deity", 0.45)
task.delay(0.6, function()
	shot("thorn_slam", 0.15)
end)
task.delay(1.2, function()
	shot("thorn_bind", 0.3)
end)
local t0 = os.clock()
check("thorn-stun-4", math.abs((w5.StunUntil or 0) - t0 - 4) < 0.3, (w5.StunUntil or 0) - t0)
check("thorn-boss-stun-2", math.abs((boss.StunUntil or 0) - t0 - 2) < 0.3, (boss.StunUntil or 0) - t0)
check("thorn-poison-15", math.abs((w5.PoisonUntil or 0) - t0 - 15) < 0.3)
local p0 = w5.Root.Position
task.wait(2.5)
check("thorn-stunned-still", (w5.Root.Position - p0).Magnitude < 2, (w5.Root.Position - p0).Magnitude)
check("thorn-poison-ticks", w5.Hum.Health < hp5, string.format("%.1f -> %.1f", hp5, w5.Hum.Health))
check("thorn-cooldown", K:Use(player, "ThornBind") == false and (player:GetAttribute("SkillReady_ThornBind") or 0) > Workspace:GetServerTimeNow() + 140)
killAll()
S.AnimalService:Kill(boss, nil)
setClass("Survivor", 1)
check("survivor-no-skill", player:GetAttribute("Skills") == "")
print(string.format("[AS] SKILLPROBE RESULT fails=%d", fails))
-- ภาพเอฟเฟกต์ (client เล่นเองให้ตรงจังหวะถ่าย) · มอน 1 ตัวให้หนามพัน
killAll()
local mob = wolf(root.CFrame.LookVector * 10)
mob.Root.Anchored = true
ReplicatedStorage:SetAttribute("FxShow", true)
task.wait(75)
-- ทดสอบจริงทั้งเส้น: client กดช่องสกิล (ClassSkill.Use เดียวกับปุ่ม Q/Z/แตะ) -> remote -> เซิร์ฟเวอร์ -> เอฟเฟกต์จริง
local function waitReady(id, t)
	local t1 = os.clock() + t
	repeat
		task.wait(0.2)
	until (player:GetAttribute("SkillReady_" .. id) or 0) > Workspace:GetServerTimeNow() + 5 or os.clock() > t1
	return (player:GetAttribute("SkillReady_" .. id) or 0) > Workspace:GetServerTimeNow() + 5
end
setClass("Elementalist", 3)
ReplicatedStorage:SetAttribute("UiTest", "Elementalist")
check("client-use-DarkMeteor", waitReady("DarkMeteor", 40))
check("client-use-ShadowVeil", waitReady("ShadowVeil", 20))
task.wait(6)
setClass("Vampire", 3)
ReplicatedStorage:SetAttribute("UiTest", "Vampire")
check("client-use-Swarm", waitReady("Swarm", 30))
task.wait(1)
check("client-swarm-5-bats", #K:Bats(player) == 5, #K:Bats(player))
task.wait(6)
setClass("Sage", 3)
ReplicatedStorage:SetAttribute("UiTest", "Sage")
check("client-use-ThornBind", waitReady("ThornBind", 30))
task.wait(8)
print(string.format("[AS] SKILLPROBE E2E fails=%d", fails))
print("[AS] SKILLPROBE DONE")
