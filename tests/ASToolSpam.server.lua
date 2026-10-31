--[[ ASToolSpam (server) — build_rbxlx.py --toolspam · นับ Tool ฝั่งเซิร์ฟเวอร์ + ให้ยา/ลดเลือด เพื่อเทสช่องยา ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASToolSpam") then
	return
end
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local ev = Instance.new("RemoteEvent")
ev.Name = "ToolSpam"
ev.Parent = ReplicatedStorage

local function count(player, tag)
	local n, names = 0, {}
	for _, h in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		for _, t in ipairs(h and h:GetChildren() or {}) do
			if t:IsA("Tool") then
				n += 1
				table.insert(names, t.Name)
			end
		end
	end
	table.sort(names)
	print(string.format("[AS] SPAM server@%s tools=%d : %s", tag, n, table.concat(names, ", ")))
end

ev.OnServerEvent:Connect(function(player, what, arg)
	local inv = require(Server:WaitForChild("InventoryService"))
	if what == "count" then
		count(player, arg or "?")
	elseif what == "give" then
		inv:Add(player, "Bandage", 3)
		inv:Add(player, "Medkit", 1)
		inv:Add(player, "Wood", 2)
	elseif what == "hurt" then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		hum.Health = 30
		print("[AS] SPAM hurt hp=", hum.Health)
	elseif what == "hp" then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		print(string.format("[AS] SPAM hp=%.1f bandage=%d medkit=%d used=%d cap=%d", hum.Health, inv:Count(player, "Bandage"), inv:Count(player, "Medkit"), inv:Used(player), inv:Capacity(player)))
	end
end)
