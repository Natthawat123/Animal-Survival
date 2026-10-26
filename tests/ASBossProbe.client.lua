--[[ ASBossProbe (client) — ถ่ายภาพฉากเปิดตัวบอสหลายจังหวะ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASBossProbe") then
	return
end
local remote = ReplicatedStorage:WaitForChild("Remotes", 120):WaitForChild("Cinematic", 120)
local count = 0
remote.OnClientEvent:Connect(function(kind, d)
	if kind ~= "BossIntro" then
		return
	end
	count += 1
	local id = d and d.Id or "?"
	local t0 = os.clock()
	for _, t in ipairs({ 0.4, 1.3, 2.0, 2.6, 3.3, 4.0, 4.8 }) do
		while os.clock() - t0 < t do
			task.wait()
		end
		print(string.format("[SHOT] boss_%s_%02d", id, math.floor(t * 10)))
	end
	if count >= 4 then
		task.wait(3)
		print("[TEST] DONE probe")
	end
end)
