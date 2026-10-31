--[[ ASCampProbe — build_rbxlx.py --campprobe · ถ่ายภาพกองไฟล็อบบี้ + กองไฟ/โต๊ะคราฟต์ในแคมป์ (เช็กทิศ/ขนาด/หน้าตาไฟ) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASCampProbe") then
	return
end
local cam = workspace.CurrentCamera
local function shot(name)
	task.wait(3)
	print("[SHOT] " .. name)
	task.wait(1.5)
end
local lobbyFire
for _ = 1, 40 do
	lobbyFire = workspace:FindFirstChild("LobbyFire", true)
	if lobbyFire then
		break
	end
	task.wait(0.5)
end
if lobbyFire then
	cam.CameraType = Enum.CameraType.Scriptable
	local c = lobbyFire.Position
	cam.CFrame = CFrame.lookAt(c + Vector3.new(10, 5, 10), c)
	shot("lobbyfire")
end
local bench = workspace:WaitForChild("World", 120):WaitForChild("Sites", 120):WaitForChild("Camp", 300):WaitForChild("Workbench", 60)
task.wait(6)
cam.CameraType = Enum.CameraType.Scriptable
local fire = workspace.World.Sites.Camp:FindFirstChild("Campfire")
local c = fire and fire:GetPivot().Position or Vector3.zero
for _, v in ipairs({ { Vector3.new(9, 5, 9), "campfire_close" }, { Vector3.new(-12, 3, 4), "campfire_side" }, { Vector3.new(-14, 16, 6), "camp_a" } }) do
	cam.CFrame = CFrame.lookAt(c + v[1], c + Vector3.new(0, 2, 0))
	shot(v[2])
end
print("[TEST] DONE probe")
