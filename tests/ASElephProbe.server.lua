--[[ ASElephProbe (server) — build_rbxlx.py --elephprobe · ช้างวารี (InkOctopus) เกิดจริงในเกม: ยืน -> เดินผ่านกล้อง (ดูทิศหัว/ท่าเดิน/ขนาด) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASElephProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(4)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local S = ctx.Services
player:SetAttribute("TestGod", true)
S.AnimalService:ClearKind("Wild", false)
local base = ctx.CampPosition + Vector3.new(70, 0, 70)
local a = S.AnimalService:Spawn("InkOctopus", base, { Kind = "Wild", Yaw = 0 })
print("[AS] ELEPHPROBE spawn ok=" .. tostring(a ~= nil) .. (a and string.format(" size=%s hp=%d", tostring(select(2, a.Model:GetBoundingBox())), a.Hum.MaxHealth) or ""))
if not a then
	print("[TEST] DONE elephprobe")
	return
end
a.Root.Anchored = true -- ยืนนิ่งให้ถ่าย (ไม่ให้ AI พาเดินหนี)
S.DevService:Teleport(player, base + Vector3.new(0, 0, -40))
ReplicatedStorage:SetAttribute("ElephFocus", a.Model)
task.wait(3)
print("[SHOT] eleph_stand")
task.wait(3)
-- เดินไปทาง +X ผ่านกล้อง (หัวต้องนำ)
a.Root.Anchored = false
a.IntroUntil = os.clock() + 999 -- ปิด AI ระหว่างเทสต์
local goal = base + Vector3.new(60, 0, 0)
a.Hum.WalkSpeed = 12
a.Hum:MoveTo(goal)
task.wait(1.2)
print("[SHOT] eleph_walk1")
task.wait(2.5)
local look = a.Root.CFrame.LookVector
print(string.format("[AS] ELEPHPROBE walking look=(%.2f,%.2f) moveDir=(1,0) speed=%.1f", look.X, look.Z, a.Root.AssemblyLinearVelocity.Magnitude))
print("[SHOT] eleph_walk2")
task.wait(3)
print("[TEST] DONE elephprobe")
