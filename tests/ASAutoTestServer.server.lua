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
	if action == "spawn" or action == "spawnRaid" then
		-- สัตว์ถูกปิดในเกม: เปิดให้เฉพาะช่วงเทสต์ต่อสู้/ฝูงบุก
		require(game:GetService("ReplicatedStorage").Shared.Config).AnimalsEnabled = true
		player:SetAttribute("TestGod", true) -- ไม่ให้ผู้เล่นเทสต์ตายจนเกมจบกลางเทสต์
	end
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
	elseif action == "galleryStage" then
		-- เวทีถ่ายภาพลอยฟ้า: พื้น + ฉากหลังโค้ง
		local old = workspace:FindFirstChild("GalleryStage")
		if old then
			old:Destroy()
		end
		local f = Instance.new("Model")
		f.Name = "GalleryStage"
		local function p(size, cf, color, mat)
			local x = Instance.new("Part")
			x.Anchored = true
			x.Size = size
			x.CFrame = cf
			x.Color = color
			x.Material = mat or Enum.Material.SmoothPlastic
			x.TopSurface = Enum.SurfaceType.Smooth
			x.Parent = f
			return x
		end
		p(Vector3.new(400, 2, 400), CFrame.new(a - Vector3.new(0, 1, 0)), Color3.fromRGB(70, 92, 62), Enum.Material.Grass)
		for i = -6, 6 do
			local ang = i * 0.13
			p(Vector3.new(30, 160, 2), CFrame.new(a) * CFrame.Angles(0, ang, 0) * CFrame.new(0, 80, 140), Color3.fromRGB(120, 150, 175), Enum.Material.SmoothPlastic)
		end
		f.Parent = workspace
		player:SetAttribute("TestGod", true)
		state:SetAttribute("TestClock", 13.5)
		return true
	elseif action == "galleryClear" then
		local g = workspace:FindFirstChild("GalleryItems")
		if g then
			g:Destroy()
		end
		local animals = svc("AnimalService")
		for _, an in ipairs(table.clone(animals:All())) do
			animals:Remove(an)
		end
		return true
	elseif action == "galleryItem" then
		-- a = { Kind = "Tool"|"Structure", Id = ..., Pos = Vector3 }
		local g = workspace:FindFirstChild("GalleryItems")
		if not g then
			g = Instance.new("Folder")
			g.Name = "GalleryItems"
			g.Parent = workspace
		end
		local model
		if a.Kind == "Tool" then
			local tool = require(Server.ToolFactory).Build(a.Id)
			if not tool then
				return nil
			end
			model = Instance.new("Model")
			model.Name = a.Id
			for _, c in ipairs(tool:GetChildren()) do
				c.Parent = model
			end
			for k, v in pairs(tool:GetAttributes()) do
				model:SetAttribute(k, v)
			end
			for _, t in ipairs(game:GetService("CollectionService"):GetTags(tool)) do
				game:GetService("CollectionService"):AddTag(model, t)
			end
			tool:Destroy()
			model.PrimaryPart = model:FindFirstChild("Handle")
		else
			model = require(ReplicatedStorage.Shared.StructureModels).Build(a.Id)
			if not model then
				return nil
			end
		end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		model.Parent = g
		local cf, size = model:GetBoundingBox()
		if a.Kind == "Tool" then
			-- เอียงโชว์ด้ามเฉียง
			model:PivotTo(CFrame.new(a.Pos + Vector3.new(0, size.Y * 0.6 + 0.5, 0)) * CFrame.Angles(0, 0.6, math.rad(-35)))
		else
			model:PivotTo(model:GetPivot() * CFrame.new(-cf.Position) + a.Pos + Vector3.new(0, size.Y / 2, 0))
		end
		local cf2, size2 = model:GetBoundingBox()
		return { cf2.Position, size2 }
	elseif action == "showcase" then
		player:SetAttribute("TestGod", true)
		state:SetAttribute("TestClock", 14)
		return true
	elseif action == "clearAnimals" then
		local animals = svc("AnimalService")
		for _, an in ipairs(table.clone(animals:All())) do
			animals:Remove(an)
		end
		return true
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
