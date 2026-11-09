--[[ ASBerryProbe (client) — เล็งกล้องไปที่ลูกเบอร์รี่ -> ตรวจกรอบ/ป้าย BerryPicker -> "คลิก" (ยิง PickBerry แบบเดียวกับกดจริง) + ถ่ายภาพ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASBerryProbe") then
	return
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Remotes = require(ReplicatedStorage.Shared.Remotes)
workspace:SetAttribute("ASAimCenter", true) -- BerryPicker เล็งกลางจอ (เมาส์ใน Studio อยู่ไหนก็ได้)
local cam = workspace.CurrentCamera
local aim = ReplicatedStorage:WaitForChild("BerryAim", 600)
local view -- ฟังก์ชันคืน CFrame กล้องที่ต้องการ (nil = กล้องปกติ)
RunService:BindToRenderStep("BerryProbeCam", Enum.RenderPriority.Camera.Value + 1, function()
	local cf = view and view()
	if cf then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = cf
	else
		cam.CameraType = Enum.CameraType.Custom
	end
end)
local function head()
	local c = player.Character
	return c and c:FindFirstChild("Head")
end
local function camMode()
	local mode = ReplicatedStorage:GetAttribute("BerryCam")
	if mode == "drops" then
		view = function()
			local h = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not h then
				return nil
			end
			local f = h.CFrame.LookVector * Vector3.new(1, 0, 1)
			local tgt = h.Position + f.Unit * 7 + Vector3.new(0, -2, 0)
			return CFrame.lookAt(tgt - f.Unit * 6 + Vector3.new(0, 4.5, 0), tgt)
		end
	elseif mode == "farm" then
		local fv = ReplicatedStorage:WaitForChild("BerryFarm", 30)
		view = function()
			local farm = fv and fv.Value
			if not (farm and farm.Parent) then
				return nil
			end
			local p = farm:GetPivot().Position
			return CFrame.lookAt(p + Vector3.new(0, 11, 15), p + Vector3.new(0, 1.5, 0))
		end
	end
end
aim.Changed:Connect(function(part)
	if part then
		view = function()
			local h = head()
			if not (h and part.Parent) then
				return nil
			end
			local from = h.Position + Vector3.new(0, 2.5, 0) + (h.Position - part.Position) * Vector3.new(1, 0, 1).Unit * 0
			local back = (from - part.Position) * Vector3.new(1, 0, 1)
			back = back.Magnitude > 0.1 and back.Unit or Vector3.zAxis
			return CFrame.lookAt(part.Position + back * 9 + Vector3.new(0, 3.5, 0), part.Position)
		end
		task.delay(2.5, function()
			local hl
			for _, d in ipairs(workspace:GetDescendants()) do
				if d.Name == "BerryHighlight" then
					hl = d
				end
			end
			local tip = player.PlayerGui:FindFirstChild("BerryTip")
			local title = tip and tip:FindFirstChildOfClass("TextLabel")
			print(string.format("[AS] BERRYPROBE %s hover hl=%s onAim=%s tip=%s text=%s", (hl and hl.Enabled and hl.Adornee == part) and "PASS" or "FAIL",
				tostring(hl and hl.Enabled), tostring(hl and hl.Adornee == part), tostring(tip and tip.Enabled), title and title.Text or "-"))
		end)
	else
		view = nil
		camMode()
	end
end)
ReplicatedStorage:GetAttributeChangedSignal("BerryClick"):Connect(function()
	local part = aim.Value
	if part then
		local src = part:FindFirstAncestorWhichIsA("Model")
		while src and not game:GetService("CollectionService"):HasTag(src, "BerrySource") do
			src = src.Parent and src.Parent:FindFirstAncestorWhichIsA("Model")
		end
		Remotes.Get("PickBerry"):FireServer(src, part, "Sack")
	end
end)
ReplicatedStorage:GetAttributeChangedSignal("BerryCam"):Connect(camMode)
local shot = ReplicatedStorage:WaitForChild("BerryShot", 600)
shot.Changed:Connect(function(v)
	if v ~= "" then
		task.wait(0.6)
		print("[SHOT] berry_" .. v)
	end
end)
