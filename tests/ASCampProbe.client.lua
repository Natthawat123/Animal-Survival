--[[ ASCampProbe — build_rbxlx.py --campprobe · ถ่ายภาพโต๊ะคราฟต์ + เครื่องย่อยในแคมป์ (เช็กทิศ/ขนาด) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASCampProbe") then
	return
end
local bench = workspace:WaitForChild("World", 120):WaitForChild("Sites", 120):WaitForChild("Camp", 300):WaitForChild("Workbench", 60)
task.wait(6)
local fire = workspace.World.Sites.Camp:FindFirstChild("Campfire")
local c = fire and fire:GetPivot().Position or Vector3.zero
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
for i, v in ipairs({ { Vector3.new(-14, 16, 6), "camp_a" }, { Vector3.new(6, 30, 40), "camp_b" } }) do
	local wb = bench:FindFirstChild("CampWorkbench")
	local tgt = wb and wb:GetPivot().Position or c
	cam.CFrame = CFrame.lookAt(c + v[1], (tgt + c) / 2 + Vector3.new(16, 0, -10) * (i - 1) * 0)
	task.wait(3)
	print("[SHOT] " .. v[2])
	task.wait(1.5)
end
print("[TEST] DONE probe")
