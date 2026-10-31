--[[ ASShrineProbe (client) — ถ่ายภาพตามชื่อที่เซิร์ฟเวอร์ตั้ง (กล้องเป็นของฉากคัตซีน / กล้องปกติตอนขี่) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASShrineProbe") then
	return
end
local shot = ReplicatedStorage:WaitForChild("ShrineShot", 900)
shot.Changed:Connect(function(v)
	if v ~= "" then
		print("[SHOT] shrine_" .. v)
	end
end)
