--[[ ASBerryProbe (client) — ถ่ายปุ่มพุ่มเบอร์รี่ + ปุ่ม "กิน" บน HUD ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASBerryProbe") then
	return
end
game:GetService("ProximityPromptService").PromptShown:Connect(function(pr)
	print("[AS] BERRYPROBE shown " .. pr.Name .. " " .. pr.ActionText)
end)
local shot = ReplicatedStorage:WaitForChild("BerryShot", 600)
shot.Changed:Connect(function(v)
	if v ~= "" then
		task.wait(0.8)
		print("[SHOT] berry_" .. v)
	end
end)
