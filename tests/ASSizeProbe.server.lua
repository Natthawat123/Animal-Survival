--[[ ASSizeProbe (server) — build_rbxlx.py --sizeprobe
	วัดขนาดม่อนป่าทุกตัว (สูง/ยาว ของชิ้นที่มองเห็น) + เรียงแถวตามธาตุ ทั่วไป -> กลาง -> โหด ให้ client ถ่ายภาพเทียบกับตัวผู้เล่น ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASSizeProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(3)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local S = ctx.Services
local Animals = require(ReplicatedStorage.Shared.Animals)
local AnimalModels = require(ReplicatedStorage.Shared.AnimalModels)
player:SetAttribute("TestGod", true)

local function visibleBox(model)
	local lo, hi
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.95 and p.Name ~= "HumanoidRootPart" then
			local cf, sz = p.CFrame, p.Size
			for _, sx in ipairs({ -0.5, 0.5 }) do
				for _, sy in ipairs({ -0.5, 0.5 }) do
					for _, sz2 in ipairs({ -0.5, 0.5 }) do
						local w = cf:PointToWorldSpace(Vector3.new(sx * sz.X, sy * sz.Y, sz2 * sz.Z))
						lo = lo and lo:Min(w) or w
						hi = hi and hi:Max(w) or w
					end
				end
			end
		end
	end
	return lo and (hi - lo) or Vector3.zero
end

local ROWS = {
	{ "Earth", { "MossWolf", "Thornboar", "StoneBear" } },
	{ "Water", { "ReefCrab", "TideOrca", "InkOctopus" } },
	{ "Air", { "SkyLynx", "StormRam", "GaleHawk" } },
	{ "Fire", { "EmberFox", "LavaSalamander", "MagmaRhino" } },
}
local base = ctx.CampPosition + Vector3.new(-70, 0, 75) -- ลานโล่งรอบแคมป์ (ไม่มีต้นไม้บัง)
task.wait(4)
S.DevService:Teleport(player, base + Vector3.new(0, 3, 40))
task.wait(2)
local folder = Instance.new("Folder")
folder.Name = "SizeProbe"
folder.Parent = workspace
for r, row in ipairs(ROWS) do
	local spawned = {}
	for i, id in ipairs(row[2]) do
		local info = Animals.Data[id]
		local model = AnimalModels.Build(id, {})
		if model then
			local pos = base + Vector3.new((i - 2) * 24, 0, 0)
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Include
			rp.FilterDescendantsInstances = { workspace.Terrain }
			local hit = workspace:Raycast(pos + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), rp)
			if hit then
				pos = Vector3.new(pos.X, hit.Position.Y, pos.Z)
			end
			AnimalModels.PlaceAt(model, pos, math.pi / 2)
			model.Parent = folder
			model.PrimaryPart.Anchored = true
			table.insert(spawned, model)
			task.wait(0.3)
			local b = visibleBox(model)
			local skin = info.Model.Skin or {}
			print(string.format("[AS] SIZE %s id=%s hp=%d night=%s rig=%s skinSize=%s skinScale=%s height=%.2f long=%.2f wide=%.2f",
				row[1], id, info.Health, tostring(info.MinNight), tostring(skin.Rig), tostring(skin.Size), tostring(skin.Scale), b.Y, math.max(b.X, b.Z), math.min(b.X, b.Z)))
		else
			print("[AS] SIZE " .. row[1] .. " id=" .. id .. " NOMODEL")
		end
	end
	ReplicatedStorage:SetAttribute("SizeShot", row[1])
	ReplicatedStorage:SetAttribute("SizeBase", base)
	task.wait(6)
	for _, m in ipairs(spawned) do
		m:Destroy()
	end
end
ReplicatedStorage:SetAttribute("SizeShot", "done")
task.wait(1)
print("[TEST] DONE sizeprobe")
