--[[
	ASOutfitGallery (server) — ใช้เฉพาะ build_rbxlx.py --outfits
	สร้างตัวละครทุกชุดใน Shared.OutfitCandidates -> ReplicatedStorage.OutfitGallery/<Class>_<n> ให้ client ถ่ายรูปทำหน้าเลือก
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASOutfitGallery") then
	return
end

local Candidates = require(ReplicatedStorage.Shared.OutfitCandidates)
local folder = Instance.new("Folder")
folder.Name = "OutfitGallery"
folder.Parent = ReplicatedStorage

local function build(o)
	local desc = Instance.new("HumanoidDescription")
	for field, ids in pairs(o.Accessories or {}) do
		desc[field] = table.concat(ids, ",")
	end
	desc.Shirt, desc.Pants, desc.Face = o.Shirt or 0, o.Pants or 0, o.Face or 0
	for field, assetId in pairs(o.Body or {}) do
		desc[field] = assetId
	end
	if o.Head then
		desc.Head = o.Head
	end
	local list = {}
	for i, l in ipairs(o.Layered or {}) do
		table.insert(list, { Order = i, AssetId = l[1], AccessoryType = Enum.AccessoryType[l[2]], IsLayered = true })
	end
	pcall(function()
		desc:SetAccessories(list, false)
	end)
	local skin = o.Skin or Color3.fromRGB(204, 158, 125)
	desc.HeadColor, desc.TorsoColor = skin, skin
	desc.LeftArmColor, desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor = skin, skin, skin, skin
	for _ = 1, 3 do
		local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
		if ok and model then
			return model
		end
		task.wait(2)
	end
	return nil
end

local total = 0
for _, cls in ipairs(Candidates.Order) do
	for n, o in ipairs(Candidates[cls]) do
		local model = build(o)
		if model then
			model.Name = cls .. "_" .. n
			model.Archivable = true
			for _, d in ipairs(model:GetDescendants()) do
				d.Archivable = true
				if d:IsA("BasePart") then
					d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
				elseif d:IsA("Script") or d:IsA("LocalScript") then
					d:Destroy()
				end
			end
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
			model.Parent = folder
			total += 1
		else
			warn("[GALLERY] failed", cls, n)
		end
	end
	print("[GALLERY] built", cls, total)
end
folder:SetAttribute("Done", true)
print("[GALLERY] all built", total)
