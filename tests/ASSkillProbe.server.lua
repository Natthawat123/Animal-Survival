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
-- ล็อกเป้า: เล็งไปทางตรงข้าม แต่ลูกต้องตกใส่มอนที่ใกล้ที่สุด
player:SetAttribute("SkillReady_DarkMeteor", 0)
local side = root.CFrame.RightVector * 45
local w5m = wolf(side)
task.wait(0.8)
w5m.Root.Anchored = true
local hpL = w5m.Hum.Health
check("meteor-lock-use", K:Use(player, "DarkMeteor", root.Position - side) == true)
task.wait(1.5)
check("meteor-lock-hit", w5m.Dead or w5m.Hum.Health < hpL, w5m.Dead and "dead" or string.format("%.0f -> %.0f", hpL, w5m.Hum.Health))
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
-- ป้ายบนหัว (ล็อบบี้): คลาส + เลเวล
local tag = root:FindFirstChild("ASTag")
local classL = tag and tag:FindFirstChild("Class")
check("lobby-tag-class", classL ~= nil and classL.Text:find("Lv%.") ~= nil, classL and classL.Text)
-- ค้างคาวฆ่ามอน = เจ้าของได้เลือด (5% + Blood Bite 2%)
killAll()
setClass("Vampire", 3)
check("drain-swarm", K:Use(player, "Swarm") == true)
task.wait(1.5)
hum.Health = hum.MaxHealth * 0.5
local h0 = hum.Health
local weak = wolf(Vector3.new(8, 0, 0))
weak.Hum.Health = 4
local tEnd = os.clock() + 10
repeat
	task.wait(0.2)
until weak.Dead or os.clock() > tEnd
task.wait(0.3)
check("bat-kill-heal", weak.Dead and hum.Health >= h0 + hum.MaxHealth * 0.05 - 0.5, string.format("%.1f -> %.1f", h0, hum.Health))
hum.Health = hum.MaxHealth
setClass("Survivor", 1)
-- ตัวคูณวัน: ดิน x2 + น้ำ x3 = x5 · เช้านี้เลขวันเดิน 5 (ปกติ +1 แล้วเพิ่มอีก 4)
local D = Dir
local st = ctx.State
st:SetAttribute("BonusDays", 0)
D:AddDayMultiplier(2, "Test")
D:AddDayMultiplier(3, "Test")
check("mult-x5", D:DayMultiplier() == 5, D:DayMultiplier())
local n0 = D.night
D.pendingSkips += D:DayMultiplier() - 1
D:ApplyPendingSkips()
check("mult-dawn-extra4", D.night == n0 + 4, D.night - n0)
-- เตียง: ยังไม่มีตัวคูณ = x2 · มีแล้ว = +1
st:SetAttribute("BonusDays", 0)
D:AddBedMultiplier(player)
check("bed-first-x2", D:DayMultiplier() == 2, D:DayMultiplier())
D:AddDayMultiplier(2, "Test")
D:AddBedMultiplier(player)
check("bed-plus1", D:DayMultiplier() == 5, D:DayMultiplier())
-- ไม่หยุดที่ 99: คืน 97 · x5 -> เช้าเดินไปถึง 102 + พิชิต 99 คืน (ปิดฉากจบไว้ ไม่ให้บังภาพเทส)
local realComplete, completed = D.Complete, 0
D.Complete = function(self)
	completed += 1
	self.ctx.State:SetAttribute("Conquered", true)
end
local saveNight = D.night
D.night = 98 -- (เช้าหลังคืน 97: Loop ตั้ง night+1 แล้ว)
D.pendingSkips += D:DayMultiplier() - 1
D:ApplyPendingSkips()
check("mult-past-99", D.night == 102 and completed == 1, string.format("night %d · complete %d", D.night, completed))
D.Complete = realComplete
st:SetAttribute("Conquered", false)
D.night = saveNight
st:SetAttribute("Night", saveNight)
st:SetAttribute("BonusDays", 0)
-- จิ้งจอกจันทรา: ไล่ · ตีละ 15 · คูลดาวน์ 4 วิ (ระหว่างนั้นยังตามติด) · ไม่เข้าแคมป์
hum:UnequipTools()
player:SetAttribute("TestGod", nil)
hum.Health = hum.MaxHealth
-- จิ้งจอกของคืนจริงที่เกมปล่อยเอง (ถ้ามี) จะจองเหยื่อคนเดียวกัน -> เคลียร์ก่อนเทสต์
print("[AS] SKILLPROBE INFO stalkers-before " .. S.AnimalService:CountKind("Stalker"))
S.AnimalService:ClearKind("Stalker", true)
local fox = S.AnimalService:Spawn("Moonfang", root.Position + Vector3.new(35, 0, 0), { Kind = "Stalker" })
check("fox-spawn", fox ~= nil)
if fox then
	check("fox-stats", fox.Info.Damage == 15 and fox.Info.AttackCooldown == 4)
	local hp0 = hum.Health
	local t2 = os.clock() + 15
	repeat
		task.wait(0.1)
		S.SkillService:BreakVeil(player) -- เทสฝั่งไคลเอนต์กดล่องหนพร้อมกัน = จิ้งจอกมองไม่เห็น
	until hum.Health < hp0 - 1 or os.clock() > t2
	local firstAt = os.clock()
	local dmg1 = hp0 - hum.Health
	check("fox-hit-15", math.abs(dmg1 - 15) < 1.5, string.format("%.1f", dmg1))
	local hp1 = hum.Health
	local maxGap = 0
	repeat
		task.wait(0.1)
		maxGap = math.max(maxGap, (fox.Root.Position - root.Position).Magnitude)
		S.SkillService:BreakVeil(player)
	until hum.Health < hp1 - 1 or os.clock() > firstAt + 8
	local gap = os.clock() - firstAt
	check("fox-cooldown-4", gap > 3.6 and gap < 5, string.format("%.2f", gap))
	check("fox-stays-close", maxGap < 20, string.format("%.1f", maxGap))
	check("fox-chase-sound", fox.ChaseSound ~= nil and fox.ChaseSound.Playing, fox.State)
	player:SetAttribute("TestGod", true)
	hum.Health = hum.MaxHealth
	local AS = S.AnimalService
	local function waitFor(fn, t)
		local untilT = os.clock() + t
		repeat
			task.wait(0.1)
			S.SkillService:BreakVeil(player)
		until fn() or os.clock() > untilT
		return fn()
	end
	-- ถือไฟ: เดินหนีออก แล้วหายตัว (ไม่วนเฝ้า)
	local CS = S.CombatService
	local origEq = CS.EquippedTool
	CS.EquippedTool = function(p)
		if p == player then
			return "Torch", { Light = 20 }
		end
		return origEq(p)
	end
	local sawRetreat = waitFor(function() return fox.State == "Retreat" end, 2)
	local hid = waitFor(function() return fox.Hidden == true end, 5)
	check("fox-torch-vanish", sawRetreat and hid, string.format("retreat=%s hidden=%s st=%s", tostring(sawRetreat), tostring(hid), tostring(fox.State)))
	task.wait(1)
	check("fox-hidden-in-sky", fox.Root.Position.Y > 500 and fox.Model:GetAttribute("Hidden") == true, string.format("y %.0f", fox.Root.Position.Y))
	-- เลิกถือไฟ: พักครบแล้ววาปโผล่ใกล้ ๆ แล้วไล่ต่อ
	CS.EquippedTool = origEq
	local back = waitFor(function() return not fox.Hidden and fox.State == "Hunt" end, 9)
	local wd = (fox.Root.Position - root.Position).Magnitude
	check("fox-warp-back", back and wd < 60, string.format("back=%s d=%.1f stalkers=%d", tostring(back), wd, AS:CountKind("Stalker")))
	-- เข้าแคมป์: เดินออกแล้วหายตัว · ไม่ยืนเฝ้า
	local safe = S.CampService:SafeRadius()
	player.Character:PivotTo(CFrame.new(ctx.CampPosition + Vector3.new(0, 4, 0)))
	local gone = waitFor(function() return fox.Hidden == true end, 6)
	task.wait(0.8)
	local fd = AS:CampDistance(fox.Root.Position)
	check("fox-camp-vanish", gone and fd >= safe, string.format("hidden=%s fd=%.1f (safe %.1f)", tostring(gone), fd, safe))
	-- ออกจากแคมป์: วาปไปหาแล้วไล่
	player.Character:PivotTo(CFrame.new(spot + Vector3.new(0, 3, 0)))
	local again = waitFor(function() return not fox.Hidden and fox.State == "Hunt" end, 9)
	local ad = (fox.Root.Position - root.Position).Magnitude
	check("fox-warp-after-camp", again and ad < 60, string.format("back=%s d=%.1f", tostring(again), ad))
	-- ขี่สัตว์ = จิ้งจอกเร่งตาม (WalkSpeed สูงกว่าตอนเดิน)
	local ws0 = 0
	waitFor(function()
		ws0 = math.max(ws0, fox.Hum.WalkSpeed)
		return false
	end, 1.2)
	player:SetAttribute("MountSpeed", 1.6)
	local ws1 = 0
	waitFor(function()
		ws1 = math.max(ws1, fox.Hum.WalkSpeed)
		return false
	end, 1.2)
	player:SetAttribute("MountSpeed", nil)
	check("fox-mount-faster", ws1 > ws0 * 1.4, string.format("walk %.1f ride %.1f", ws0, ws1))
	-- ตัวที่ 2: คนเดียวในห้อง = ไม่แย่งเหยื่อตัวแรก (ซ่อน/เดินหนี ไม่ไล่ซ้อน)
	local fox2 = AS:Spawn("Moonfang", root.Position + Vector3.new(-35, 0, 0), { Kind = "Stalker" })
	local both = false
	waitFor(function()
		both = both or (fox2 and fox2.State == "Hunt" and fox.State == "Hunt")
		return false
	end, 4)
	check("fox-no-double-chase", fox2 ~= nil and not both and fox2.Prey ~= player, string.format("fox1=%s fox2=%s", tostring(fox.State), tostring(fox2 and fox2.State)))
	AS:ClearKind("Stalker", true)
	player.Character:PivotTo(CFrame.new(spot + Vector3.new(0, 3, 0)))
	task.wait(1)
end
-- กัดหลบได้: ยืนเฉย = โดน · ถอยออกตอนเห็นแถบเตือน = ไม่โดน
do
	player:SetAttribute("TestGod", false)
	hum.Health = hum.MaxHealth
	local here = root.Position
	local wolf = S.AnimalService:Spawn("MossWolf", here + root.CFrame.LookVector * 6, { Kind = "Wild" })
	check("bite-spawn", wolf ~= nil)
	if wolf then
		task.wait(0.5)
		local AS = S.AnimalService
		local w = AS:BiteWindup(wolf)
		wolf.IntroUntil = math.huge -- แช่ AI ตัวทดสอบ (ไม่กัดเอง/ไม่เดินตาม) ทดสอบเฉพาะจังหวะกัด
		local function bite()
			wolf.BiteUntil, wolf.NextAttack = nil, 0
			player.Character:PivotTo(CFrame.new(wolf.Root.Position + ((root.Position - wolf.Root.Position) * Vector3.new(1, 0, 1)).Unit * 4, wolf.Root.Position))
			task.wait()
			AS:AttackPlayer(wolf, player, os.clock())
		end
		hum.Health = hum.MaxHealth
		local h0 = hum.Health
		bite()
		task.wait(w + 0.25)
		check("bite-stand-hit", hum.Health < h0 - 0.5, string.format("windup %.2f dmg %.1f", w, h0 - hum.Health))
		task.wait((wolf.Info.AttackCooldown or 1.5) + 0.2)
		hum.Health = hum.MaxHealth
		h0 = hum.Health
		bite()
		task.wait(0.2) -- เห็นแถบเตือนแล้วถอยหลัง 14 สตั๊ด
		local back = (root.Position - wolf.Root.Position) * Vector3.new(1, 0, 1)
		player.Character:PivotTo(CFrame.new(root.Position + back.Unit * 14))
		task.wait(w)
		check("bite-dodge-back", hum.Health >= h0 - 0.5, string.format("dmg %.1f", h0 - hum.Health))
		wolf.Model:Destroy()
	end
	hum.Health = hum.MaxHealth
	player.Character:PivotTo(CFrame.new(spot + Vector3.new(0, 3, 0)))
	task.wait(0.5)
end
player:SetAttribute("TestGod", true)
-- ไฟเผา: สีตามออร่าอาวุธ (คทาพ่อมดมืด = ม่วงดำ · ดาบไฟ = ส้มแดง)
local TF = require(game:GetService("ServerScriptService").Server.ToolFactory)
local sc = TF.BurnColor("ArcaneStaff", Items.Tools.ArcaneStaff)
local k0 = sc and sc.Keypoints[1].Value
check("burn-color-shadow", k0 ~= nil and k0.B > k0.G and k0.R > k0.G, k0 and tostring(k0))
local fc = TF.BurnColor("EmberBlade", Items.Tools.EmberBlade)
local f0 = fc and fc.Keypoints[1].Value
check("burn-color-fire", f0 ~= nil and f0.R > f0.B, f0 and tostring(f0))
-- ของตก: ตัดไม้ 6 ท่อนไม่ทับกัน
local dropPos = root.Position + root.CFrame.LookVector * 12
for _ = 1, 6 do
	S.DropService:Spawn("Wood", 1, dropPos, { Dir = -root.CFrame.LookVector, Spread = 2 })
end
task.wait(1.2)
local logs = {}
for _, m in ipairs(Workspace.Drops:GetChildren()) do
	if m:GetAttribute("ItemId") == "Wood" and m.PrimaryPart and (m.PrimaryPart.Position - dropPos).Magnitude < 25 then
		table.insert(logs, m.PrimaryPart.Position)
	end
end
local minGap = math.huge
for i = 1, #logs do
	for j = i + 1, #logs do
		minGap = math.min(minGap, ((logs[i] - logs[j]) * Vector3.new(1, 0, 1)).Magnitude)
	end
end
check("drops-no-overlap", #logs >= 6 and minGap > 1.6, string.format("%d logs · min gap %.2f", #logs, minGap))
print(string.format("[AS] SKILLPROBE RESULT fails=%d", fails))
-- ภาพเอฟเฟกต์ (client เล่นเองให้ตรงจังหวะถ่าย) · มอน 1 ตัวให้หนามพัน
killAll()
local mob = wolf(root.CFrame.LookVector * 10)
mob.Root.Anchored = true
-- ระหว่างถ่ายภาพ: ไม่มีจิ้งจอกจันทรามาบังกล้อง + กลางวัน
task.spawn(function()
	while true do
		S.AnimalService:ClearKind("Stalker", true)
		game:GetService("Lighting").ClockTime = 13
		-- สัตว์ป่าตัวอื่นเดินมารุมจุดถ่าย -> เอาออก (เหลือมอนทดสอบตัวเดียว)
		for _, o in ipairs(S.AnimalService:InRadius(root.Position, 90, false)) do
			if o ~= mob and o.Kind == "Wild" and not o.Dead then
				S.AnimalService:Remove(o)
			end
		end
		task.wait(1)
	end
end)
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
killAll() -- ไม่มีมอนใกล้: ค้างคาวต้องเข้าแถวหลังเจ้าของ
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
