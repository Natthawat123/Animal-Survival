--[[
	ASAutoTestServer — ใช้เฉพาะไฟล์ทดสอบ (build_rbxlx.py --test)
	ช่วย client เทสต์: แจกของ, เรียกสัตว์, วาร์ป, จบเทสต์
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASAutoTest") then
	return
end

local state = ReplicatedStorage:WaitForChild("GameState")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local cmd = Instance.new("RemoteFunction")
cmd.Name = "TestCmd"
cmd.Parent = remotes

while not state:GetAttribute("Ready") do
	task.wait(0.5)
end
print("[TEST] server ready, seed", state:GetAttribute("Seed"))

local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
-- เข้าถึงบริการผ่าน require (โมดูลเดียวกับที่ Main ใช้)
local function svc(name)
	return require(Server:WaitForChild(name))
end

local errors = 0
game:GetService("LogService").MessageOut:Connect(function(msg, t)
	if t == Enum.MessageType.MessageError and not msg:find("TestService") then
		errors += 1
	end
end)

cmd.OnServerInvoke = function(player, action, a, b)
	if action == "give" then
		local inv = svc("InventoryService")
		for id, n in pairs(a) do
			inv:Add(player, id, n, true)
		end
		return true
	elseif action == "spawn" then
		local animals = svc("AnimalService")
		local made = animals:Spawn(a, b, { Kind = "Wild" })
		if made then
			made.Model:SetAttribute("TestSpawn", true)
		end
		return made ~= nil
	elseif action == "spawnRaid" then
		local director = svc("DirectorService")
		local made = director:SpawnRaid(a, {}, state:GetAttribute("Night") or 1)
		return made ~= nil
	elseif action == "layout" then
		return {
			Sites = state:GetAttributes(),
		}
	elseif action == "height" then
		local h = require(ReplicatedStorage.Shared.MapLayout).new(state:GetAttribute("Seed"), state:GetAttribute("MapSize"), require(ReplicatedStorage.Shared.Config)):HeightAt(a, b)
		return h
	elseif action == "safe" then
		-- หาจุดบนบกที่ไม่ใช่ลาวาใกล้ๆ (x,z)
		local L = require(ReplicatedStorage.Shared.MapLayout).new(state:GetAttribute("Seed"), state:GetAttribute("MapSize"), require(ReplicatedStorage.Shared.Config))
		for r = 0, 300, 15 do
			for k = 0, 7 do
				local x, z = a + math.cos(k * 0.785) * r, b + math.sin(k * 0.785) * r
				local h, _, lava = L:HeightAt(x, z)
				if not lava and h > L.WaterLevel + 2 then
					return Vector3.new(x, h, z)
				end
			end
		end
		return Vector3.new(a, L:HeightAt(a, b), b)
	elseif action == "freeze" then
		-- หยุดสัตว์ทุกตัว (ถ่ายรูป)
		for _, an in ipairs(svc("AnimalService"):All()) do
			an.Root.Anchored = a and true or false
		end
		return true
	elseif action == "errors" then
		return errors
	elseif action == "done" then
		print("[TEST] DONE " .. tostring(a) .. " errors=" .. errors)
		task.wait(1)
		pcall(function()
			game:GetService("StudioTestService"):EndTest(a)
		end)
		return true
	end
	return nil
end
