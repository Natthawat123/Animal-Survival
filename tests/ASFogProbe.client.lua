--[[ ASFogProbe (client) — ถ่ายภาพตามที่เซิร์ฟเวอร์สั่ง ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASFogProbe") then
	return
end
local shot = ReplicatedStorage:WaitForChild("ProbeShot", 600)
shot.Changed:Connect(function(v)
	if v ~= "" then
		print("[SHOT] " .. v)
	end
end)
