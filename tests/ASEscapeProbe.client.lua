--[[ ASEscapeProbe (client) — ถ่ายภาพตามจังหวะที่เซิร์ฟเวอร์สั่ง + ตรวจหน้าต่างโหวต ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASEscapeProbe") then
	return
end
local Players = game:GetService("Players")
local shot = ReplicatedStorage:WaitForChild("EscShot", 900)
shot.Changed:Connect(function(v)
	if v == "" then
		return
	end
	if v == "esc_3vote" then
		local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local p = pg and pg:FindFirstChild("EscapeVotePanel", true)
		print("[AS] ESCPROBE " .. ((p and p.Visible) and "PASS" or "FAIL") .. " vote_panel_shown")
	end
	task.wait(0.3)
	print("[SHOT] " .. v)
end)
