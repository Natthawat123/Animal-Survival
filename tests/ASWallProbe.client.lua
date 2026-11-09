--[[ ASWallProbe (client) — ถ่ายแนวกำแพงที่ต่อกัน (มุมบน + มุมข้าง) + ตรวจว่า WallSnap ฝั่ง client คำนวณได้ตรงกับเซิร์ฟเวอร์ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASWallProbe") then
	return
end
local RunService = game:GetService("RunService")
local cam = workspace.CurrentCamera
local view
RunService:BindToRenderStep("WallProbeCam", Enum.RenderPriority.Camera.Value + 1, function()
	if view then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = view
	end
end)
local shot = ReplicatedStorage:WaitForChild("WallShot", 900)
shot.Changed:Connect(function(v)
	local c = shot:GetAttribute("Center")
	if not c or v == "" then
		return
	end
	if v == "top" then
		view = CFrame.lookAt(c + Vector3.new(0, 46, 8), c)
		-- client เล็งที่จุดเดียวกับเซิร์ฟเวอร์ -> ต้องได้จุดดูดเหมือนกัน (WallSnap ใช้โมเดลชุดเดียวกันทั้งสองฝั่ง)
		local ok, res = pcall(function()
			local WallSnap = require(ReplicatedStorage.Shared.WallSnap)
			return WallSnap.Find("LogWall", c + Vector3.new(60, 0, 0), workspace:FindFirstChild("Structures"))
		end)
		print("[AS] WALLPROBE client_snap_ok=" .. tostring(ok) .. " " .. tostring(res ~= nil))
	else
		view = CFrame.lookAt(c + Vector3.new(-22, 10, 26), c + Vector3.new(0, 3, 0))
	end
	task.wait(0.8)
	print("[SHOT] wall_" .. v)
end)
