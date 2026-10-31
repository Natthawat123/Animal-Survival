--[[ ASCookProbe (client) — ถ่ายปุ่มที่กองไฟ / เนื้อในไฟ / เนื้อสุก ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASCookProbe") then
	return
end
game:GetService("ProximityPromptService").PromptShown:Connect(function(pr)
	print("[AS] COOKPROBE shown " .. pr.Name .. " " .. pr.ActionText)
end)
local shot = ReplicatedStorage:WaitForChild("CookShot", 600)
shot.Changed:Connect(function(v)
	if v ~= "" then
		task.wait(0.6)
		print("[SHOT] cook_" .. v)
	end
end)
