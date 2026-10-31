--[[ ASBreakProbe (server) — build_rbxlx.py --breakprobe · วางสิ่งก่อสร้างทุกแบบ -> พังทีละอัน + โค่นต้นไม้/ทุบหิน/คริสตัล เพื่อดูท่าพัง/วาง ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASBreakProbe") then
	return
end
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local rf = Instance.new("RemoteFunction")
rf.Name = "BreakProbe"
rf.Parent = ReplicatedStorage

local placed = {}
local nodes = {}
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances = { Workspace.Terrain }

local function spot(i)
	local bs = require(Server:WaitForChild("BuildingService"))
	local camp = bs.ctx.CampPosition
	local p = camp + Vector3.new(-30 + (i % 6) * 12, 0, 22 + math.floor(i / 6) * 18)
	local hit = Workspace:Raycast(p + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), ray)
	return hit and hit.Position or p
end

rf.OnServerInvoke = function(player, what, a, b)
	local bs = require(Server:WaitForChild("BuildingService"))
	if what == "spot" then
		return spot(a)
	elseif what == "place" then
		local pos = spot(b)
		local m = bs:Spawn(a, CFrame.new(pos) * CFrame.Angles(0, math.rad(20), 0), 100, 100, player.UserId)
		bs.ctx.Remotes.Get("HitFx"):FireAllClients("Build", { Position = pos, Kind = a, Structure = m })
		placed[a] = m
		return m ~= nil
	elseif what == "break" then
		local m = placed[a]
		if m and m.Parent then
			bs:Damage(m, 1e6)
			return true
		end
		return false
	elseif what == "findnode" then
		local camp = bs.ctx.CampPosition
		local best, bestD
		for _, n in ipairs(CollectionService:GetTagged("ResourceNode")) do
			if n:GetAttribute("Node") == a and not n:GetAttribute("Depleted") and n:IsDescendantOf(Workspace) then
				local d = (n:GetPivot().Position - camp).Magnitude
				if d > 25 and not n.Name:find("Giant") and (not bestD or d < bestD) then
					best, bestD = n, d
				end
			end
		end
		nodes[a] = best
		if not best then
			return nil
		end
		local pos = best:GetPivot().Position
		if player.Character then
			player.Character:PivotTo(CFrame.new(pos + Vector3.new(14, 4, 14)))
		end
		print(string.format("[AS] BREAK node %s %s dist=%.0f", a, best.Name, bestD))
		return pos
	elseif what == "fell" then
		local n = nodes[a]
		if n then
			require(Server:WaitForChild("ResourceService")):Fell(n, b)
			return true
		end
		return false
	end
end
