--[[ ASTraderProbe (server) — build_rbxlx.py --traderprobe · พ่อค้าเดินเข้าจากป่า -> ยืนนอกเขตแคมป์ -> วางของทับ = เดินหลบ -> เดินกลับเข้าป่า
	client ถ่ายภาพตาม attribute TraderStep บน ReplicatedStorage ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASTraderProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(3)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
player:SetAttribute("TestGod", true)
local Trader = ctx.Services.TraderService
local camp = ctx.CampPosition
local function step(name)
	ReplicatedStorage:SetAttribute("TraderStep", name)
	task.wait(2.6)
end
local function report(tag)
	local feet = Trader.feet
	local d = feet and ((feet - camp) * Vector3.new(1, 0, 1)).Magnitude or -1
	print(string.format("[AS] TRADER %s dist=%.1f campR=%.1f ready=%s", tag, d, ctx.Services.CampService:CampRadius(), tostring(Trader.ready)))
end

Trader:Arrive()
task.wait(2.2)
report("walking")
step("walk")
local t0 = os.clock()
repeat
	task.wait(0.2)
until Trader.ready or os.clock() - t0 > 15
report("arrived")
step("stand")

-- วางกำแพงทับจุดยืนพ่อค้า (ข้ามเช็กเขตแคมป์ เหมือนอัปเกรดกองไฟแล้วเขตกว้างขึ้น) -> ต้องเดินหลบ
local old = Trader.feet
local B = ctx.Services.BuildingService
local wall = B:Spawn("LogWall", CFrame.new(old) * CFrame.Angles(0, math.rad(90), 0), 200, 200, player.UserId)
Trader:MakeRoom(old, require(ReplicatedStorage.Shared.Items).Structures.LogWall.Size)
task.wait(0.8)
step("dodge")
t0 = os.clock()
repeat
	task.wait(0.2)
until Trader.ready or os.clock() - t0 > 15
report("moved")
print(string.format("[AS] TRADER %s moved %.1f studs from wall", (Trader.feet - old).Magnitude > 8 and "PASS" or "FAIL", (Trader.feet - old).Magnitude))
step("after")
if wall then
	wall:Destroy()
end

Trader:Leave()
task.wait(2.5)
report("leaving")
step("leave")
task.wait(6)
print("[AS] TRADER " .. (Trader.model == nil and "PASS gone" or "FAIL still here"))
print("[TEST] DONE traderprobe")
