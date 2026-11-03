--[[ ASWildProbe (server) — build_rbxlx.py --medprobe · สัตว์ป่ากลางวัน: ไล่ในถิ่น -> ผู้เล่นออกนอกถิ่น = เลิกไล่ กลับถิ่น · ไล่ไม่ถึงนาน = เลิกไล่ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASMedProbe") then
	return
end
repeat
	task.wait(0.5)
until ReplicatedStorage:GetAttribute("MedDone")
task.wait(30) -- รอเทสข้อความ (client) จบก่อน
local player = Players:GetPlayers()[1]
local S = require(game:GetService("ServerScriptService").Server.RejoinService).ctx.Services
local animals, dev = S.AnimalService, S.DevService
local Config = require(ReplicatedStorage.Shared.Config)
local camp = require(game:GetService("ServerScriptService").Server.RejoinService).ctx.CampPosition
player:SetAttribute("TestGod", true)
dev:Teleport(player, camp + Vector3.new(320, 0, 0))
task.wait(2)
local root = player.Character.HumanoidRootPart
local home = root.Position + Vector3.new(0, 0, 24)
local a = animals:Spawn("MossWolf", home, { Kind = "Wild" })
local function st(tag)
	local d = (a.Root.Position - root.Position).Magnitude
	local dh = (a.Root.Position - a.Home).Magnitude
	print(string.format("[AS] WILDPROBE %s state=%s leash=%s toPlayer=%d fromHome=%d", tag, tostring(a.State), tostring(a.Leash), d, dh))
end
task.wait(3)
st("near")
-- ผู้เล่นออกห่างจากถิ่น 160 stud (นอกถิ่น 70+40)
player.Character:PivotTo(player.Character:GetPivot() + Vector3.new(160, 0, 0))
task.wait(5)
st("left_territory")
-- กลับมาในระยะ แต่หนีตลอด (ไม่ให้ถึงตัว) -> ต้องเลิกไล่หลัง WildChaseTime
player.Character:PivotTo(CFrame.new(a.Root.Position + Vector3.new(30, 3, 0)))
local t0 = os.clock()
local gaveUp
while os.clock() - t0 < Config.WildChaseTime + 6 do
	task.wait(0.5)
	local away = (root.Position - a.Root.Position) * Vector3.new(1, 0, 1)
	if away.Magnitude < 22 then
		local target = a.Home + (away.Magnitude > 0.1 and away.Unit or Vector3.xAxis) * 50
		player.Character:PivotTo(CFrame.new(target.X, root.Position.Y, target.Z))
	end
	if not gaveUp and a.Ignore and a.Ignore[player] then
		gaveUp = os.clock() - t0
	end
end
st("kited")
print("[AS] WILDPROBE gaveUpAfter=" .. tostring(gaveUp and math.floor(gaveUp) or "never"))
a.Model:Destroy()
ReplicatedStorage:SetAttribute("WildDone", true)
print("[AS] WILDPROBE done")
