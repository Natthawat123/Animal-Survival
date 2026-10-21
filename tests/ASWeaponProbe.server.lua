--[[
	ASWeaponProbe (server) — ใช้เฉพาะ build_rbxlx.py --lobbyprobe
	ให้ผู้เล่นถืออาวุธทีละชิ้น (ToolFactory) ตามคำขอจาก client -> ถ่ายภาพท่าถือ
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASLobbyProbe") then
	return
end
local ToolFactory = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("ToolFactory"))
local ev = Instance.new("RemoteFunction")
ev.Name = "ProbeEquip"
ev.Parent = ReplicatedStorage
ev.OnServerInvoke = function(player, itemId)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return false
	end
	hum:UnequipTools()
	for _, t in ipairs(player.Backpack:GetChildren()) do
		t:Destroy()
	end
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") then
			t:Destroy()
		end
	end
	local tool = ToolFactory.Build(itemId)
	if not tool then
		return false
	end
	tool.Parent = player.Backpack
	hum:EquipTool(tool)
	local h = tool:FindFirstChild("Handle")
	local _, size = tool:GetBoundingBox()
	return true, h and tostring(h.Size) or "", tostring(size)
end
