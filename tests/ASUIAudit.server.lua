--[[ ASUIAudit (server) — build_rbxlx.py --uiaudit · อมตะระหว่างตรวจ UI (สัตว์ไม่ขัดจังหวะ) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASUIAudit") then
	return
end
local function god(p)
	p:SetAttribute("TestGod", true)
end
Players.PlayerAdded:Connect(god)
for _, p in ipairs(Players:GetPlayers()) do
	god(p)
end
