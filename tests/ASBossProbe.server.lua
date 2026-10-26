--[[ ASBossProbe (server) — build_rbxlx.py --bossprobe · เรียกบอสทั้ง 4 ทีละตัวหน้าผู้เล่น (มีฉากเปิดตัว) ให้ client ถ่ายภาพ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASBossProbe") then
	return
end
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local char = player.Character or player.CharacterAdded:Wait()
local camp
repeat
	task.wait(1)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == "Camp" then
			camp = d
			break
		end
	end
until camp
task.wait(10)
local Animals = require(ReplicatedStorage.Shared.Animals)
local AnimalService = require(Server:WaitForChild("AnimalService"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Cinematic")
local cp = camp:GetPivot().Position
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), rp)
	return hit and hit.Position.Y or cp.Y
end
char:PivotTo(CFrame.new(cp + Vector3.new(0, 4, 40)))
for _, id in ipairs({ "Terragon", "Leviathan", "TempestRoc", "Solfang" }) do
	local info = Animals.Data[id]
	local x, z = cp.X, cp.Z - 40
	local a = AnimalService:Spawn(id, Vector3.new(x, ground(x, z) + 2, z), { Kind = "Boss" })
	if a then
		a.Model:SetAttribute("IsBoss", true)
		-- หันหน้าเข้าหาผู้เล่น
		a.Model:PivotTo(CFrame.lookAt(a.Model:GetPivot().Position, Vector3.new(cp.X, a.Model:GetPivot().Position.Y, cp.Z + 40)))
		AnimalService:BeginIntro(a)
		print("[AS] BOSSPROBE start " .. id)
		remote:FireClient(player, "BossIntro", { Model = a.Model, Id = id, Name = info.Name, Thai = info.Thai, Element = info.Element })
		task.wait(8.5)
		AnimalService:Remove(a)
		task.wait(1.5)
	else
		print("[AS] BOSSPROBE missing " .. id)
	end
end
print("[AS] BOSSPROBE done")
