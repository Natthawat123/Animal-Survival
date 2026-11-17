--[[ ASKrProbe (client) — ถ่ายภาพประตู/มิติลอยกระทง/ตัวนับ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASKrProbe") then
	return
end
local cam = workspace.CurrentCamera
local look
RunService.RenderStepped:Connect(function()
	if look then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = look
	end
end)
ReplicatedStorage:GetAttributeChangedSignal("KrShot"):Connect(function()
	local s = ReplicatedStorage:GetAttribute("KrShot")
	local cf = ReplicatedStorage:GetAttribute("KrCam")
	if typeof(cf) == "CFrame" then
		look = cf
	else
		look = nil
		cam.CameraType = Enum.CameraType.Custom
	end
	task.wait(1.6)
	print("[SHOT] " .. s)
	if s == "kr_river" then
		-- วัดความลื่น: ตำแหน่งกระทงที่ใกล้กล้องที่สุดทุกเฟรม 4 วิ -> ความเร็วรายเฟรมแกว่งแค่ไหน (กระตุก = แกว่งมาก/มีเฟรมหยุดนิ่ง)
		local best, bd
		for _, m in ipairs(workspace:GetDescendants()) do
			if m:IsA("Model") and m.Name == "Krathong" and m.PrimaryPart then
				local d = (m.PrimaryPart.Position - cam.CFrame.Position).Magnitude
				if not bd or d < bd then
					best, bd = m, d
				end
			end
		end
		if best then
			local last, speeds, stalls = best.PrimaryPart.Position, {}, 0
			local t0 = os.clock()
			while os.clock() - t0 < 4 and best.Parent do
				local dt = RunService.RenderStepped:Wait()
				local p = best.PrimaryPart.Position
				local v = (p - last).Magnitude / dt
				table.insert(speeds, v)
				if v < 0.05 then
					stalls += 1
				end
				last = p
			end
			local sum, sq = 0, 0
			for _, v in ipairs(speeds) do
				sum += v
			end
			local mean = sum / math.max(#speeds, 1)
			for _, v in ipairs(speeds) do
				sq += (v - mean) ^ 2
			end
			print(string.format("[AS] KRSMOOTH frames=%d meanSpeed=%.2f jitter=%.2f stalledFrames=%d", #speeds, mean, math.sqrt(sq / math.max(#speeds, 1)) / math.max(mean, 0.01), stalls))
		end
	end
end)
