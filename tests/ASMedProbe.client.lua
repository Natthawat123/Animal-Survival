--[[ ASMedProbe (client) — มุมกล้องถ่ายท่าถือยา/พันแผล/ก้มช่วยเพื่อน ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASMedProbe") then
	return
end
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local view
RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if view and root then
		cam.CameraType = Enum.CameraType.Scriptable
		local cf = root.CFrame
		cam.CFrame = CFrame.lookAt((cf * view).Position, cf.Position + Vector3.new(0, 0.2, 0))
	end
end)
local VIEWS = {
	front = CFrame.new(1.5, 1.5, -6.5),
	side = CFrame.new(-6.5, 1, -1.5),
	hold = CFrame.new(-3, 1.5, -5.5),
}
local shot = ReplicatedStorage:WaitForChild("MedShot", 600)
shot.Changed:Connect(function(v)
	local kind = v:match("_(%a+)$")
	view = VIEWS[kind] or VIEWS.front
	task.wait(1.1)
	local char = player.Character
	local arm = char and char:FindFirstChild("RightUpperArm")
	local j = arm and arm:FindFirstChild("RightShoulder")
	local kids = {}
	for _, c in ipairs(arm and arm:GetChildren() or {}) do
		table.insert(kids, c.Name .. ":" .. c.ClassName)
	end
	print(string.format("[AS] MEDDBG %s MedUse=%s arm=%s joint=%s kids=[%s]", v, tostring(player:GetAttribute("MedUse")), tostring(arm ~= nil), tostring(j and j.ClassName), table.concat(kids, ",")))
	if j then
		print("[AS] MEDDBG C0 rot=" .. tostring(j:IsA("Motor6D") and Vector3.new(j.C0:ToEulerAnglesXYZ()) or Vector3.new(j.Attachment0.CFrame:ToEulerAnglesXYZ())) .. " T rot=" .. tostring(Vector3.new(j.Transform:ToEulerAnglesXYZ())) .. " enabled=" .. tostring(j.Enabled) .. " a0=" .. tostring(j.Attachment0 and j.Attachment0.Parent) .. " kin=" .. tostring(j.IsKinematic))
		local ok = 0
		local conn = RunService.Stepped:Connect(function()
			ok += 1
		end)
		local c1 = j.Attachment0.CFrame
		task.wait(0.2)
		conn:Disconnect()
		print("[AS] MEDDBG steps=" .. ok .. " C0changed=" .. tostring(c1 ~= j.Attachment0.CFrame) .. " anims=" .. #(char:FindFirstChildOfClass("Humanoid"):GetPlayingAnimationTracks()))
	end
	print("[SHOT] med_" .. v)
end)
