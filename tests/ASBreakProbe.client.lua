--[[ ASBreakProbe (client) — ถ่ายท่าวาง/พังของสิ่งก่อสร้างทุกแบบ + ต้นไม้/หิน/คริสตัล ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASBreakProbe") then
	return
end
local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("GameState")
while not state:GetAttribute("Ready") do
	task.wait(0.5)
end
local lobby = Workspace:WaitForChild("Lobby", 30)
local zone = lobby and lobby:FindFirstChild("MatchBox1", true)
local t0 = os.clock()
while not player:GetAttribute("InRun") and os.clock() - t0 < 60 do
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if zone and r then
		r.CFrame = zone.CFrame
		if player:GetAttribute("Pad") then
			pcall(function()
				require(ReplicatedStorage.Shared.Remotes).Get("PadSize"):FireServer(zone:GetAttribute("PadIndex") or 1, 1)
			end)
		end
	end
	task.wait(0.5)
end
print("[AS] BREAK inRun", player:GetAttribute("InRun"))
task.wait(8)
local rf = ReplicatedStorage:WaitForChild("BreakProbe")
local cam = Workspace.CurrentCamera
local fx = Workspace:WaitForChild("BreakFX", 10)

local function look(at, dist, up)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(at + Vector3.new(dist * 0.55, up, dist), at + Vector3.new(0, up * 0.35, 0))
end
local function count()
	local ghosts, chunks = 0, 0
	for _, c in ipairs(fx and fx:GetChildren() or {}) do
		if c:IsA("Model") then
			ghosts += 1
		else
			chunks += 1
		end
	end
	return ghosts, chunks
end

for _, kind in ipairs({ "Tree", "Rock", "Crystal" }) do
	local pos = rf:InvokeServer("findnode", kind)
	if pos then
		task.wait(2.5)
		local tree = kind == "Tree"
		look(pos, tree and 46 or 16, tree and 14 or 7)
		task.wait(1)
		-- ให้ล้มไปทางขวาของกล้อง (เห็นชัด)
		local right = cam.CFrame.RightVector * Vector3.new(1, 0, 1)
		rf:InvokeServer("fell", kind, pos - right.Unit * 10)
		task.wait(tree and 0.5 or 0.2)
		print("[SHOT] fell_" .. kind)
		task.wait(tree and 0.7 or 0.6)
		print("[SHOT] fell2_" .. kind)
		if tree then
			task.wait(0.6)
			print("[SHOT] fell3_" .. kind)
		end
		local g, c = count()
		print(string.format("[AS] BREAK node %s ghosts=%d chunks=%d", kind, g, c))
		task.wait(3)
	else
		print("[AS] BREAK no node", kind)
	end
end
local KINDS = { "LogWall", "StoneWall", "SpikeTrap", "Lantern", "Ballista", "Bed", "FarmPlot", "CookPot", "TerraTotem", "EmberTotem", "TideTotem", "SunBeacon" }
for i, kind in ipairs(KINDS) do
	local big = kind == "SunBeacon"
	local p = rf:InvokeServer("spot", i - 1)
	look(p, big and 60 or 20, big and 30 or 9)
	task.wait(1.2)
	local ok = rf:InvokeServer("place", kind, i - 1)
	task.wait(big and 0.7 or 0.25)
	print("[SHOT] build_" .. kind)
	task.wait(big and 2.4 or 1.6)
	print("[SHOT] built_" .. kind)
	task.wait(0.6)
	local s0 = os.clock()
	rf:InvokeServer("break", kind)
	task.wait(big and 0.6 or 0.35)
	print("[SHOT] break_" .. kind)
	task.wait(0.9)
	local g, c = count()
	print(string.format("[AS] BREAK %s placed=%s ghosts=%d chunks=%d t=%.2f", kind, tostring(ok), g, c, os.clock() - s0))
	task.wait(1.5)
end

print("[TEST] DONE")
