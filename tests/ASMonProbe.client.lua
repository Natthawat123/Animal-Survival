--[[ ASMonProbe (client) — กล้องมองสัตว์จากเฉียงหน้า แล้วถ่ายภาพตามที่เซิร์ฟเวอร์สั่ง ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASMonProbe") then
	return
end
local shot = ReplicatedStorage:WaitForChild("MonShot", 900)
local target = ReplicatedStorage:WaitForChild("MonTarget", 60)
local cam = workspace.CurrentCamera
RunService.RenderStepped:Connect(function()
	local m = target.Value
	local root = m and m.Parent and m:FindFirstChild("HumanoidRootPart")
	if root then
		cam.CameraType = Enum.CameraType.Scriptable
		local size = m:GetExtentsSize()
		local d = math.max(size.X, size.Y, size.Z) * 1.5 + 6
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
		local right = look:Cross(Vector3.new(0, 1, 0))
		local from = root.Position + look * d * 0.8 + right * d * 0.6 + Vector3.new(0, size.Y * 0.6 + 2, 0)
		if shot.Value:match("_side%d*$") then
			from = root.Position + right * d * 1.2 + Vector3.new(0, size.Y * 0.3, 0)
		elseif shot.Value:match("_front$") then
			from = root.Position + look * d * 1.2 + Vector3.new(0, size.Y * 0.3, 0)
		end
		cam.CFrame = CFrame.lookAt(from, root.Position)
	end
end)
shot.Changed:Connect(function(v)
	if v ~= "" then
		print("[SHOT] mon_" .. v)
		-- วัดว่าขาขยับจริง: มุมข้อต่อขาหน้าซ้าย (องศา) ตัวอย่าง 6 จุดใน 0.6 วิ
		local m = target.Value
		local j = m and m:FindFirstChild("LegFL", true)
		local leg = m and m.PrimaryPart and m.PrimaryPart.Parent and nil
		for _, d in ipairs(m and m:GetDescendants() or {}) do
			if d:IsA("Motor6D") and d.Name == "LegFL" then
				leg = d
			end
		end
		local _ = j
		if not leg then
			for _, d in ipairs(m and m:GetDescendants() or {}) do
				if d:IsA("Motor6D") and d.Part1 and (d.Part1.Name == "LeftUpperLeg" or d.Part1.Name == "LFleg1") then
					leg = d
				end
			end
		end
		if leg then
			task.spawn(function()
				local out = {}
				for _ = 1, 6 do
					local rx = leg.Transform:ToEulerAnglesXYZ()
					table.insert(out, string.format("%.0f", math.deg(rx)))
					task.wait(0.1)
				end
				print("[AS] MONPROBE leg " .. v .. " " .. table.concat(out, ","))
			end)
		end
	end
end)
