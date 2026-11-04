--[[ ASHammerProbe (client) — ภาพค้อนช่าง: ถือค้อน · เมนูย้าย/รื้อ · เงาตอนย้าย · ท่าพังตอนรื้อ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASHammerProbe") then
	return
end
local Client = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
local Menus = require(Client:WaitForChild("Menus"))
local BuildHammer = require(Client:WaitForChild("BuildHammer"))

ReplicatedStorage:GetAttributeChangedSignal("HammerShot"):Connect(function()
	local v = ReplicatedStorage:GetAttribute("HammerShot") or ""
	local name, delay = v:match("^([%w_]+):([%d%.]+)")
	if name then
		task.delay(tonumber(delay), function()
			print("[SHOT] hammer_" .. name)
		end)
	end
end)
local function target()
	local v = ReplicatedStorage:FindFirstChild("HammerTarget")
	return v and v.Value
end
ReplicatedStorage:GetAttributeChangedSignal("HammerMenu"):Connect(function()
	local s = target()
	if typeof(s) == "Instance" then
		BuildHammer.OpenFor(s)
	end
end)
ReplicatedStorage:GetAttributeChangedSignal("HammerMove"):Connect(function()
	local s = target()
	if typeof(s) == "Instance" then
		Menus.StartBuild(s:GetAttribute("Kind"), s)
	end
end)
ReplicatedStorage:GetAttributeChangedSignal("HammerStop"):Connect(function()
	Menus.StopBuild()
end)
