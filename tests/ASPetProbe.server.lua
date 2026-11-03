--[[ ASPetProbe (server) — build_rbxlx.py --chestprobe · โมเดลใหม่: กล่อง 3 ระดับ (ภาพ + ชนไม่ทะลุ) · แอร์ดรอป · ลูกสัตว์ 4 ตัว ยืน/เดิน/ขี่ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASChestProbe") then
	return
end
repeat
	task.wait(1)
until ReplicatedStorage:GetAttribute("ChestWeaponsDone")
local player = Players:GetPlayers()[1]
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local S = ctx.Services
local step = Instance.new("StringValue")
step.Name = "PetStep"
step.Parent = ReplicatedStorage
local follow = Instance.new("ObjectValue")
follow.Name = "PetFollow"
follow.Parent = ReplicatedStorage
-- target = Vector3 (จุดนิ่ง) หรือ Instance (กล้องตามตลอด)
local function show(kind, target, wait)
	if typeof(target) == "Instance" then
		follow.Value = target
		ReplicatedStorage:SetAttribute("PetTarget", nil)
	else
		follow.Value = nil
		ReplicatedStorage:SetAttribute("PetTarget", target)
	end
	step.Value = kind
	task.wait(wait or 4)
end
-- กล่อง 3 ระดับ: ภาพ + เดินชน
local folder = Workspace.World:FindFirstChild("SupplyCrates")
for t = 1, 3 do
	local c
	for _, x in ipairs(folder:GetChildren()) do
		if x:GetAttribute("Tier") == t and not x:GetAttribute("Opened") then
			c = x
			break
		end
	end
	if c then
		local cp = c:GetPivot().Position
		local mesh = c:FindFirstChildWhichIsA("MeshPart", true)
		local _, sz = c:GetBoundingBox()
		S.DevService:Teleport(player, cp + Vector3.new(12, 0, 0))
		task.wait(1.2)
		show("crate" .. t, cp, 3)
		-- เดินทะลุกล่อง: สั่งเดินไปอีกฝั่ง แล้วดูว่าผ่านไปได้ไหม
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		local root = player.Character.HumanoidRootPart
		hum.AutoJumpEnabled = false
		hum.JumpPower = 0
		root.CFrame = CFrame.new(cp + Vector3.new(7, 3, 0))
		task.wait(0.6)
		hum:MoveTo(cp + Vector3.new(-9, 0, 0))
		local maxY = -math.huge
		for _ = 1, 25 do
			task.wait(0.1)
			maxY = math.max(maxY, root.Position.Y - cp.Y)
		end
		hum.JumpPower = 50
		local px = root.Position.X - cp.X
		print(string.format("[AS] PETPROBE crate%d maxRootAboveGround=%.1f crateTop=%.1f", t, maxY, sz.Y))
		print(string.format("[AS] PETPROBE crate%d mesh=%s size=%s collide=%s passedThrough=%s (x=%.1f)", t, tostring(mesh ~= nil),
			tostring(Vector3.new(math.floor(sz.X * 10) / 10, math.floor(sz.Y * 10) / 10, math.floor(sz.Z * 10) / 10)), tostring(mesh and mesh.CanCollide), tostring(px < -3), px))
	end
end
-- แอร์ดรอป
local okS, errS = pcall(S.EventService.Supply, S.EventService, S.EventService.token)
print("[AS] PETPROBE supply ok=" .. tostring(okS) .. " " .. tostring(errS))
task.wait(19)
local drop
for _, d in ipairs(Workspace:GetDescendants()) do
	if d.Name == "SupplyDrop" and d:IsA("Model") then
		drop = d
	end
end
if drop then
	print("[AS] PETPROBE airdrop model=" .. tostring(drop:FindFirstChild("AirdropCrate") ~= nil))
	S.DevService:Teleport(player, drop:GetPivot().Position + Vector3.new(14, 0, 0))
	task.wait(1.5)
	show("airdrop", drop:GetPivot().Position, 3)
end
-- ลูกสัตว์ 4 ตัว (ขนาดโตแล้วที่แคมป์ ขี่ได้)
local Animals = require(ReplicatedStorage.Shared.Animals)
local camp = ctx.CampPosition
for i, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
	local id = Animals.Spirits[el]
	local pos = camp + Vector3.new(30 + i * 14, 4, 30)
	local okP, a = pcall(S.AnimalService.Spawn, S.AnimalService, id, pos, { Kind = "Spirit", SizeMult = Animals.Data[id].Model.Skin.PetScale or 1.9, Yaw = 0 })
	if okP and a then
		a.Pet = true
		a.Home = pos
		a.Model:SetAttribute("Pet", true)
		S.MountService:AddPet(a)
		local _, sz = a.Model:GetBoundingBox()
		print(string.format("[AS] PETPROBE pet %s rig=%s bones=%d size=%.1f,%.1f,%.1f", id, tostring(a.Model:GetAttribute("SkinRig")), #a.Model:GetDescendants() > 0 and (function()
			local n = 0
			for _, d in ipairs(a.Model:GetDescendants()) do
				n += d:IsA("Bone") and 1 or 0
			end
			return n
		end)() or 0, sz.X, sz.Y, sz.Z))
		S.DevService:Teleport(player, pos + Vector3.new(14, 0, 0))
		task.wait(1.5)
		a.Hum.WalkSpeed = 0
		show("pet_" .. id .. "_idle", a.Model, 4)
		-- เดิน (ช้าๆ ให้เห็นขาก้าว) แล้ววิ่ง
		a.Hum.WalkSpeed = 10
		a.Hum:MoveTo(pos + Vector3.new(0, 0, -200))
		show("pet_" .. id .. "_walk", a.Model, 4)
		a.Hum.WalkSpeed = 26
		show("pet_" .. id .. "_run", a.Model, 4)
		a.Hum:MoveTo(a.Root.Position)
		-- ขี่
		player.Character.HumanoidRootPart.CFrame = CFrame.new(a.Root.Position + Vector3.new(4, 2, 0))
		task.wait(0.5)
		S.MountService:Mount(player, a)
		task.wait(0.8)
		print(string.format("[AS] PETPROBE ride %s riding=%s", id, tostring(player:GetAttribute("Riding"))))
		ReplicatedStorage:SetAttribute("RideWalk", true)
		show("pet_" .. id .. "_ride", a.Model, 4)
		ReplicatedStorage:SetAttribute("RideWalk", nil)
		S.MountService:Dismount(player)
		task.wait(0.5)
		S.AnimalService:Remove(a)
	else
		print("[AS] PETPROBE pet " .. id .. " spawn failed " .. tostring(a))
	end
end
print("[AS] PETPROBE done")
