--[[ ASEscapeProbe (server) — build_rbxlx.py --escapeprobe
	ประตูกลับบ้านหลัง 99 คืน: พิชิต -> ประตูโผล่ (ฉากเปิด) -> โหวตไม่ผ่าน = เล่นต่อ -> โหวตผ่าน = ฉากจบ -> กลับล็อบบี้
	ผล: "[AS] ESCPROBE PASS/FAIL ..." · จบด้วย "[TEST] DONE escapeprobe" ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASEscapeProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(4)
player:SetAttribute("TestGod", true)
local Server = game:GetService("ServerScriptService").Server
local ctx = require(Server.RejoinService).ctx
local S, st = ctx.Services, ctx.State
local Esc, Dir = S.EscapeService, S.DirectorService
local fails = 0
local function check(name, ok, info)
	if not ok then
		fails += 1
	end
	print(string.format("[AS] ESCPROBE %s %s %s", ok and "PASS" or "FAIL", name, info or ""))
end
local shot = Instance.new("StringValue")
shot.Name = "EscShot"
shot.Parent = ReplicatedStorage
local function snap(name)
	shot.Value = ""
	task.wait(0.05)
	shot.Value = name
end
Esc.RevealDelay = 1
-- กลางวัน + ยืนในแคมป์ (กันฉากเปิดถูกข้ามเพราะมีสัตว์ใกล้)
S.AnimalService:ClearKind(nil, true)
player.Character:PivotTo(CFrame.new(ctx.CampPosition + Vector3.new(8, 4, 8)))
check("no_gate_before", st:GetAttribute("EscapeGate") == nil, "")
Dir:Complete()
local t0 = os.clock()
repeat
	task.wait(0.2)
until (Esc.gate and Esc.gate.Parent) or os.clock() - t0 > 20
local gate = Esc.gate
check("gate_spawned", gate ~= nil and gate.Parent ~= nil, gate and gate:GetFullName() or "nil")
if not gate then
	print("[TEST] DONE escapeprobe")
	return
end
local center, normal = gate:GetAttribute("Center"), gate:GetAttribute("Normal")
local veil = gate:FindFirstChildWhichIsA("ProximityPrompt", true)
check("gate_prompt", veil ~= nil and veil.ActionText == "Vote to go home", veil and veil.ActionText or "")
check("gate_in_camp", ((center - ctx.CampPosition) * Vector3.new(1, 0, 1)).Magnitude < 50, string.format("dist=%.1f", ((center - ctx.CampPosition) * Vector3.new(1, 0, 1)).Magnitude))
check("not_realmportal", not game:GetService("CollectionService"):HasTag(veil.Parent, "RealmPortal"), "")
task.wait(2.2)
snap("esc_1reveal")
task.wait(5)
-- มองประตูจากหน้าแคมป์ (ภาพนิ่ง)
player.Character:PivotTo(CFrame.lookAt(center + normal * 30 + Vector3.new(0, -4, 0), center))
task.wait(1.5)
snap("esc_2gate")
task.wait(1.5)
-- โหวตรอบ 1: ไม่ผ่าน -> เล่นต่อ ประตูยังอยู่
Esc:StartVote(player)
task.wait(1.2)
snap("esc_3vote")
task.wait(1)
check("vote_open", Esc.vote ~= nil, "")
local id = Esc.vote and Esc.vote.Id
Esc:Cast(player, id, false)
task.wait(0.5)
check("vote_no_stays", Esc.vote == nil and st:GetAttribute("Phase") ~= "Ended" and Esc.gate == gate and Dir:IsRunning(), "phase=" .. tostring(st:GetAttribute("Phase")))
Esc:StartVote(player)
check("cooldown", Esc.vote == nil, "")
task.wait(3)
-- โหวตรอบ 2: ผ่าน -> ฉากจบ -> กลับล็อบบี้
Esc.cool = 0
Esc:StartVote(player)
task.wait(0.5)
Esc:Cast(player, Esc.vote and Esc.vote.Id, true)
local tL = os.clock()
repeat
	task.wait(0.1)
until st:GetAttribute("Phase") == "Ended" or os.clock() - tL > 5
check("leave_started", st:GetAttribute("Phase") == "Ended" and st:GetAttribute("Ending") == "Escape", "")
local tc = os.clock()
local marks = { { 3, "esc_e1camp" }, { 9, "esc_e2fire" }, { 14.5, "esc_e3pets" }, { 19.5, "esc_e4gate" }, { 23.5, "esc_e5walk" }, { 27.5, "esc_e6walk2" }, { 30.4, "esc_e7light" }, { 35, "esc_e8end" } }
local through
for _, mk in ipairs(marks) do
	repeat
		task.wait(0.05)
	until os.clock() - tc >= mk[1]
	snap(mk[2])
	if mk[2] == "esc_e7light" then
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		through = r and (r.Position - center):Dot(normal)
	end
end
check("walked_through", through ~= nil and through < 1, "side=" .. tostring(through))
repeat
	task.wait(0.3)
until st:GetAttribute("Phase") == "Lobby" or os.clock() - tc > 70
check("back_to_lobby", st:GetAttribute("Phase") == "Lobby" and not player:GetAttribute("InRun"), "phase=" .. tostring(st:GetAttribute("Phase")))
task.wait(1)
check("gate_removed", Esc.gate == nil and not gate.Parent and st:GetAttribute("Conquered") == false, "")
task.wait(2)
snap("esc_9lobby")
task.wait(2)
print(string.format("[AS] ESCPROBE TOTAL fails=%d", fails))
print("[TEST] DONE escapeprobe")
