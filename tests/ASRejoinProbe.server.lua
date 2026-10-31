--[[ ASRejoinProbe (server) — build_rbxlx.py --rejoinprobe
	จำลอง "ทุกคนหลุดออก -> เปิดเซิร์ฟเวอร์ใหม่ -> กลับเข้ารอบเดิม": เซฟรอบ (SerializeRun) -> ผ่าน JSON (แทน MemoryStore)
	-> ล้างรอบ (ResetRun) -> คืนรอบ (OnTeamArrive) แล้วเช็กคืน/กองไฟ/คลัง/สิ่งก่อสร้าง/วิญญาณ/ของในกระสอบ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
if not ReplicatedStorage:FindFirstChild("ASRejoinProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(5)
local R = require(game:GetService("ServerScriptService").Server.RejoinService)
local S = R.ctx.Services
local st = R.ctx.State
local function report(tag)
	print(string.format("[AS] REJOINPROBE %s night=%s phase=%s camp=%s bench=%s fuel=%s wood=%s structs=%d spiritEarth=%s lairFire=%s inRun=%s bagStone=%s",
		tag, tostring(st:GetAttribute("Night")), tostring(st:GetAttribute("Phase")), tostring(st:GetAttribute("CampLevel")), tostring(st:GetAttribute("BenchLevel")),
		tostring(st:GetAttribute("CampFuel")), tostring(S.InventoryService.Camp.Wood), #S.BuildingService:All(), tostring(st:GetAttribute("SpiritEarth")),
		tostring(st:GetAttribute("LairFireCleared")), tostring(player:GetAttribute("InRun")), tostring(S.InventoryService:Get(player).Stone)))
end
-- สร้างความคืบหน้า
S.DirectorService.night = 5
S.CampService:Restore(3, 2, 77)
S.InventoryService:SetCamp({ Wood = 33, Iron = 4 })
local root = player.Character.HumanoidRootPart.Position
S.BuildingService:Spawn("LogWall", CFrame.new(root + Vector3.new(20, 0, 0)), 250, 300, player.UserId)
S.BuildingService:Spawn("SpikeTrap", CFrame.new(root + Vector3.new(-20, 0, 0)) * CFrame.Angles(0, 1, 0), 200, 200, player.UserId)
S.SpiritService:Restore({ Spirits = { Earth = true }, Lairs = { Fire = true } })
S.InventoryService:Add(player, "Stone", 7, true)
report("before")
-- ผู้เล่นหลุด (เก็บสถานะ) -> เซฟทั้งรอบ
R.saved[player.UserId] = R:Snapshot(player)
R.held = true
local run = R:SerializeRun()
local json = HttpService:JSONEncode(run)
print("[AS] REJOINPROBE size=" .. #json)
-- เซิร์ฟเวอร์ใหม่: ล้างรอบเหมือนเปิดใหม่
R.held = false
S.DirectorService:ResetRun()
task.wait(2)
report("reset")
R.ctx.Resume = HttpService:JSONDecode(json)
R.resumed = false
print("[AS] REJOINPROBE arrive=" .. tostring(R:OnTeamArrive(player)))
task.wait(5)
report("after")
print("[AS] REJOINPROBE done")
