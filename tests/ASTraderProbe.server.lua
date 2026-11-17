--[[ ASTraderProbe (server) — build_rbxlx.py --traderprobe · พ่อค้า R15 เดินเข้าจากป่า -> เดินเล่นในแคมป์ (ขาก้าว)
	-> คนเข้าใกล้ = หยุด หันหน้าหา -> วางของทับ = เดินหลบ -> เดินกลับเข้าป่า
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
local V = Vector3.new
local function step(name)
	ReplicatedStorage:SetAttribute("TraderStep", name)
	task.wait(1.4)
end
local function anims()
	local hum = Trader.hum
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local out = {}
	for _, t in ipairs(animator and animator:GetPlayingAnimationTracks() or {}) do
		table.insert(out, string.format("%s(%.2f)", t.Animation.AnimationId:match("%d+") or "?", t.Speed))
	end
	return table.concat(out, ",")
end
local function report(tag)
	local feet = Trader.feet
	local d = feet and ((feet - camp) * V(1, 0, 1)).Magnitude or -1
	local root = Trader.root
	local v = root and root.AssemblyLinearVelocity or V()
	local look = root and root.CFrame.LookVector or V()
	local face = (V(v.X, 0, v.Z).Magnitude > 0.5) and look:Dot(V(v.X, 0, v.Z).Unit) or 0
	print(string.format("[AS] TRADER %s dist=%.1f campR=%.1f ready=%s speed=%.1f faceDot=%.2f anims=%s", tag, d, ctx.Services.CampService:CampRadius(), tostring(Trader.ready), V(v.X, 0, v.Z).Magnitude, face, anims()))
end
-- ผู้เล่นไปยืนไกลๆ (ไม่ให้พ่อค้าหยุดคุยระหว่างเทสต์เดิน)
player.Character:PivotTo(CFrame.new(camp + V(0, 4, 0)) * CFrame.new(0, 0, 0))
Trader:Arrive()
task.wait(3)
local m = Trader.model
print(string.format("[AS] TRADER rig=%s r15=%s shirt=%s acc=%d", tostring(Trader.root ~= nil), tostring(m and m:FindFirstChild("UpperTorso") ~= nil), tostring(m and m:FindFirstChildOfClass("Shirt") ~= nil), m and #m:GetChildren() or 0))
for _, c in ipairs(m and m:GetChildren() or {}) do
	if c:IsA("Accessory") then
		print("[AS] TRADER accessory " .. c.Name)
	end
end
report("walking")
step("walk")
step("walk2")
local t0 = os.clock()
repeat
	task.wait(0.2)
until Trader.ready or os.clock() - t0 > 25
report("arrived")
step("arrived")
-- เดินเล่นในแคมป์ (ไกลจากผู้เล่น)
player.Character:PivotTo(CFrame.new(camp + V(0, 60, 0)))
player.Character.HumanoidRootPart.Anchored = true
local before = Trader.feet
local maxSpeed, faceSum, faceN = 0, 0, 0
t0 = os.clock()
while os.clock() - t0 < 14 do
	task.wait(0.2)
	local r = Trader.root
	if r then
		local v = r.AssemblyLinearVelocity * V(1, 0, 1)
		maxSpeed = math.max(maxSpeed, v.Magnitude)
		if v.Magnitude > 2 then
			faceSum += r.CFrame.LookVector:Dot(v.Unit)
			faceN += 1
		end
	end
	if os.clock() - t0 > 6 and os.clock() - t0 < 6.3 then
		report("wander")
		step("wander")
	end
end
local insideR = ((Trader.feet - camp) * V(1, 0, 1)).Magnitude
print(string.format("[AS] TRADER %s wander maxSpeed=%.1f faceAvg=%.2f moved=%.1f inside=%.1f/%.1f", (maxSpeed > 3 and faceN > 0 and faceSum / faceN > 0.8) and "PASS" or "FAIL", maxSpeed, faceN > 0 and faceSum / faceN or 0, (Trader.feet - before).Magnitude, insideR, ctx.Services.CampService:CampRadius() + 2))
-- คนเข้าใกล้ -> หยุด + หันหน้าหา
player.Character.HumanoidRootPart.Anchored = false
local tr = Trader.root
local side = tr.CFrame.RightVector
player.Character:PivotTo(CFrame.new(tr.Position + side * 6 + V(0, 1, 0)))
task.wait(3)
local toP = (player.Character.HumanoidRootPart.Position - tr.Position) * V(1, 0, 1)
local dot = tr.CFrame.LookVector:Dot(toP.Unit)
local sp = (tr.AssemblyLinearVelocity * V(1, 0, 1)).Magnitude
print(string.format("[AS] TRADER %s faces player dot=%.2f speed=%.1f", (dot > 0.85 and sp < 1) and "PASS" or "FAIL", dot, sp))
step("talk")
-- วางกำแพงทับ -> เดินหลบ
player.Character:PivotTo(CFrame.new(camp + V(0, 60, 0)))
player.Character.HumanoidRootPart.Anchored = true
task.wait(0.5)
local old = Trader.feet
local B = ctx.Services.BuildingService
local wall = B:Spawn("LogWall", CFrame.new(old) * CFrame.Angles(0, math.rad(90), 0), 200, 200, player.UserId)
Trader:MakeRoom(old, require(ReplicatedStorage.Shared.Items).Structures.LogWall.Size)
task.wait(4)
print(string.format("[AS] TRADER %s moved %.1f studs from wall", (Trader.feet - old).Magnitude > 6 and "PASS" or "FAIL", (Trader.feet - old).Magnitude))
step("dodge")
if wall then
	wall:Destroy()
end
Trader:Leave()
task.wait(3)
report("leaving")
step("leave")
t0 = os.clock()
repeat
	task.wait(0.5)
until Trader.model == nil or os.clock() - t0 > 50
print("[AS] TRADER " .. (Trader.model == nil and "PASS gone" or "FAIL still here") .. string.format(" after %.0fs", os.clock() - t0))
player.Character.HumanoidRootPart.Anchored = false
print("[TEST] DONE traderprobe")
