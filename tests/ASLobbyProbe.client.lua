--[[
	ASLobbyProbe — ใช้เฉพาะ build_rbxlx.py --lobbyprobe
	ตรวจสัตว์ไบโอมดินจาก Meshy: สร้าง 3 ตัวลอยกลางฟ้า เล่นท่าเดิน 2 จังหวะ แล้วถ่ายภาพ (ด้านข้าง)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASLobbyProbe") then
	return
end
local lobby = Workspace:WaitForChild("Lobby", 60)
task.wait(6)
for _, g in ipairs(Players.LocalPlayer.PlayerGui:GetChildren()) do
	if g:IsA("ScreenGui") then
		g.Enabled = false
	end
end
local AnimalModels = require(ReplicatedStorage.Shared.AnimalModels)
local ClipAnimator = require(Players.LocalPlayer.PlayerScripts:FindFirstChild("ClipAnimator", true))
local at = lobby:GetPivot().Position + Vector3.new(0, 300, 0)
local floor = Instance.new("Part")
floor.Anchored, floor.Size, floor.CFrame = true, Vector3.new(110, 1, 30), CFrame.new(at - Vector3.new(0, 0.5, 0))
floor.Color = Color3.fromRGB(90, 120, 70)
floor.Parent = Workspace
local rigs = {}
for i, id in ipairs({ "EmberFox", "MagmaRhino", "LavaSalamander", "GaleHawk", "SkyLynx", "StormRam" }) do
	local ok, m = pcall(AnimalModels.Build, id, { Tag = false })
	if ok and m then
		local x = (i - 3.5) * 11
		-- หันหัวไปทาง +X (มองจากด้านข้าง)
		m:PivotTo(CFrame.new(at + Vector3.new(x, m.PrimaryPart.Size.Y / 2 + (m:FindFirstChildOfClass("Humanoid").HipHeight), 0)) * CFrame.Angles(0, -math.pi / 2, 0))
		m.PrimaryPart.Anchored = true
		m.Parent = Workspace
		local rig = { Model = m, Id = id, Root = m.PrimaryPart }
		local att = ClipAnimator.Attach(rig)
		local _, size = m:GetBoundingBox()
		print("[PROBE] animal", id, "clip", att, "size", tostring(size), "tracks", rig.Clip and #rig.Clip.Tracks)
		table.insert(rigs, rig)
	else
		print("[PROBE] build fail", id, m)
	end
end
local cam = Workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.CFrame = CFrame.lookAt(at + Vector3.new(0, 8, -52), at + Vector3.new(0, 3, 0))
for _ = 1, 30 do
	for _, r in ipairs(rigs) do
		ClipAnimator.Animate(r, 0.03, 10)
	end
	task.wait()
end
task.wait(1)
print("[SHOT] probe_mon_walk")
task.wait(1.5)
-- ท่าโจมตี: หยุดภาพที่จังหวะง้าง (0.22s) และกระแทก (0.34s)
for _, ph in ipairs({ { "probe_mon_windup", 0.22 }, { "probe_mon_strike", 0.34 } }) do
	local now = os.clock()
	for _, r in ipairs(rigs) do
		r.AttackT = now - ph[2]
		r.Clip.LastAttack = r.AttackT -- ไม่ต้องเล่น VFX ในภาพนิ่ง
		ClipAnimator.Animate(r, 0, 0)
	end
	-- ค้างท่า: ตั้งเวลาเริ่มใหม่ทุกเฟรม
	local t0 = os.clock()
	while os.clock() - t0 < 2.6 do
		for _, r in ipairs(rigs) do
			r.AttackT = os.clock() - ph[2]
			r.Clip.LastAttack = r.AttackT
			ClipAnimator.Animate(r, 0, 0)
		end
		if os.clock() - t0 > 1.2 and not ph.done then
			ph.done = true
			for _, r in ipairs(rigs) do
				local hb = r.Model:FindFirstChild("head", true)
				local mp = r.Model:FindFirstChildWhichIsA("MeshPart", true)
				print(string.format("[PROBE] %s head T angle %.3f  pos %s  skinned %s  attack %s  tracks %d", r.Id, select(2, hb.Transform:ToAxisAngle()), tostring(hb.Transform.Position), tostring(mp.HasSkinnedMesh), tostring(r.Clip.Attack ~= nil), #r.Clip.Tracks))
			end
			print("[SHOT] " .. ph[1])
		end
		task.wait()
	end
end
print("[TEST] DONE probe")
