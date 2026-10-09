--[[
	InventoryService — ของของผู้เล่น (server เป็นเจ้าของข้อมูล) แบบ 99 Nights
	· เครื่องมือ/อาวุธ/กระสอบ = Tool ในช่องด้านล่างของ Roblox (1 ชิ้นต่อชนิด)
	· ของอื่น (ไม้ หิน อาหาร ...) อยู่ใน "กระสอบ" มีความจุจำกัด (Items.Sacks)
	· คลังแคมป์ (Camp) ใช้ร่วมกันทั้งเซิร์ฟเวอร์ — เทกระสอบลงที่โต๊ะคราฟต์
	· คราฟต์/สร้าง/เติมไฟ ใช้ของจากกระสอบก่อน แล้วค่อยหยิบจากคลังแคมป์
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local ToolFactory = require(script.Parent.ToolFactory)

local InventoryService = {}
local inv = {}
local dirty = {}
local camp = {}

-- ของที่เทลงคลังแคมป์ได้ (อาหาร/ยาเก็บไว้กับตัว)
local DEPOSIT = { Resource = true, Essence = true, Relic = true }

function InventoryService:Init(ctx)
	self.ctx = ctx
	self.Camp = camp
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

-- รวมของในกระสอบ + คลังแคมป์
function InventoryService:Available(player, id)
	return (self:Get(player)[id] or 0) + (camp[id] or 0)
end

local function markDirty(player)
	dirty[player] = true
end

local function markAll()
	for _, p in ipairs(Players:GetPlayers()) do
		dirty[p] = true
	end
end

function InventoryService:Capacity(player)
	local bag = self:Get(player)
	local cap = 0
	for id, c in pairs(Items.Sacks) do
		if (bag[id] or 0) > 0 then
			cap = math.max(cap, c)
		end
	end
	return cap
end

function InventoryService:Used(player)
	local n = 0
	for id, c in pairs(self:Get(player)) do
		if Items.Bulk(id) then
			n += c
		end
	end
	return n
end

function InventoryService:Space(player)
	return math.max(0, self:Capacity(player) - self:Used(player))
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

-- ใส่ของตรงๆ (ของเริ่มต้น/ซื้อ/คราฟต์) — ไม่สนความจุ
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

-- เก็บของเข้ากระสอบตามที่ว่าง -> คืนจำนวนที่ใส่ได้
function InventoryService:AddToSack(player, id, n)
	local fit = math.min(n, self:Space(player))
	if fit > 0 then
		self:Add(player, id, fit)
	end
	return fit
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
	for id, n in pairs(cost) do
		local need = math.max(1, math.ceil(n * (mult or 1)))
		if self:Available(player, id) < need then
			return false
		end
	end
	return true
end

-- ใช้ของ: กระสอบก่อน แล้วค่อยคลังแคมป์
function InventoryService:Spend(player, cost, mult)
	if not self:Has(player, cost, mult) then
		return false
	end
	local bag = self:Get(player)
	local touchedCamp = false
	for id, n in pairs(cost) do
		local need = math.max(1, math.ceil(n * (mult or 1)))
		local fromBag = math.min(need, bag[id] or 0)
		bag[id] = (bag[id] or 0) - fromBag
		if bag[id] <= 0 then
			bag[id] = nil
		end
		local rest = need - fromBag
		if rest > 0 then
			camp[id] -= rest
			if camp[id] <= 0 then
				camp[id] = nil
			end
			touchedCamp = true
		end
	end
	if touchedCamp then
		markAll()
	else
		markDirty(player)
	end
	return true
end

-- เทวัตถุดิบในกระสอบลงคลังแคมป์ -> คืนจำนวนชิ้น
function InventoryService:Deposit(player)
	local bag = self:Get(player)
	local moved = 0
	for id, n in pairs(bag) do
		local d = Items.Data[id]
		if d and DEPOSIT[d.Category] and n > 0 then
			camp[id] = (camp[id] or 0) + n
			bag[id] = nil
			moved += n
		end
	end
	if moved > 0 then
		markAll()
	end
	return moved
end

function InventoryService:ResetCamp()
	table.clear(camp)
	markAll()
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
	-- ส่งข้อมูลเมื่อมีการเปลี่ยน (รวมเป็นรอบละครั้ง): { Bag, Camp, Cap, Used }
	task.spawn(function()
		local remote = ctx.Remotes.Get("Inventory")
		while true do
			task.wait(0.15)
			for p in pairs(dirty) do
				dirty[p] = nil
				if p.Parent then
					remote:FireClient(p, { Bag = self:Get(p), Camp = camp, Cap = self:Capacity(p), Used = self:Used(p) })
				end
			end
		end
	end)
end

return InventoryService
