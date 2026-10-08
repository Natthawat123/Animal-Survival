--[[
	InventoryService — กระเป๋าของผู้เล่น (server เป็นเจ้าของข้อมูล)
	ของประเภท Tool จะได้ Tool ใน Backpack (1 ชิ้นต่อชนิด)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local ToolFactory = require(script.Parent.ToolFactory)

local InventoryService = {}
local inv = {}
local dirty = {}

function InventoryService:Init(ctx)
	self.ctx = ctx
end

function InventoryService:Get(player)
	if not inv[player] then
		inv[player] = {}
	end
	return inv[player]
end

function InventoryService:Count(player, id)
	return self:Get(player)[id] or 0
end

local function markDirty(player)
	dirty[player] = true
end

function InventoryService:GiveTool(player, id)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return
	end
	local char = player.Character
	for _, container in ipairs({ backpack, char }) do
		if container then
			for _, t in ipairs(container:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("ItemId") == id then
					return
				end
			end
		end
	end
	local tool = ToolFactory.Build(id)
	if tool then
		tool.Parent = backpack
	end
end

function InventoryService:Add(player, id, n, silent)
	n = n or 1
	if n <= 0 or not Items.Data[id] then
		return
	end
	local bag = self:Get(player)
	bag[id] = (bag[id] or 0) + n
	if Items.Data[id].Category == "Tool" then
		bag[id] = 1
		self:GiveTool(player, id)
	end
	markDirty(player)
	if not silent then
		self.ctx.Remotes.Get("HitFx"):FireClient(player, "Pickup", { Item = id, Count = n })
	end
end

function InventoryService:Remove(player, id, n)
	n = n or 1
	local bag = self:Get(player)
	if (bag[id] or 0) < n then
		return false
	end
	bag[id] -= n
	if bag[id] <= 0 then
		bag[id] = nil
	end
	markDirty(player)
	return true
end

function InventoryService:Has(player, cost, mult)
	local bag = self:Get(player)
	for id, n in pairs(cost) do
		local need = math.max(1, math.ceil(n * (mult or 1)))
		if (bag[id] or 0) < need then
			return false
		end
	end
	return true
end

function InventoryService:Spend(player, cost, mult)
	if not self:Has(player, cost, mult) then
		return false
	end
	local bag = self:Get(player)
	for id, n in pairs(cost) do
		local need = math.max(1, math.ceil(n * (mult or 1)))
		bag[id] -= need
		if bag[id] <= 0 then
			bag[id] = nil
		end
	end
	markDirty(player)
	return true
end

function InventoryService:Reset(player)
	inv[player] = {}
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		backpack:ClearAllChildren()
	end
	if player.Character then
		for _, t in ipairs(player.Character:GetChildren()) do
			if t:IsA("Tool") then
				t:Destroy()
			end
		end
	end
	markDirty(player)
end

-- คืน Tool ทุกชิ้นหลังเกิดใหม่
function InventoryService:RestoreTools(player)
	for id, n in pairs(self:Get(player)) do
		if n > 0 and Items.Data[id] and Items.Data[id].Category == "Tool" then
			self:GiveTool(player, id)
		end
	end
	markDirty(player)
end

function InventoryService:Start(ctx)
	Players.PlayerRemoving:Connect(function(p)
		inv[p] = nil
		dirty[p] = nil
	end)
	-- ส่งข้อมูลกระเป๋าเมื่อมีการเปลี่ยน (รวมเป็นรอบละครั้ง)
	task.spawn(function()
		local remote = ctx.Remotes.Get("Inventory")
		while true do
			task.wait(0.15)
			for p in pairs(dirty) do
				dirty[p] = nil
				if p.Parent then
					remote:FireClient(p, self:Get(p))
				end
			end
		end
	end)
end

return InventoryService
