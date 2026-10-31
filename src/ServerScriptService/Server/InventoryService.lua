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
local Limits = require(ReplicatedStorage.Shared.Limits)
local CollectionService = game:GetService("CollectionService")
local ItemThumbs = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ItemThumbs"))
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
	self.order = {}
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

-- คลังแคมป์ใช้ร่วมได้ทุกที่ (แบบเดิม: สร้างกำแพง/กับดักไกลแคมป์ก็หยิบของจากคลังได้) — ข้อจำกัดเรื่องระยะอยู่ที่โต๊ะคราฟต์ใน CampService
function InventoryService:InCamp(_player)
	return true
end

-- จำนวนในคลังแคมป์ที่ผู้เล่นคนนี้ใช้ได้ตอนนี้ (นอกแคมป์ = 0)
function InventoryService:CampCount(player, id, inCamp)
	if inCamp == nil then
		inCamp = self:InCamp(player)
	end
	return inCamp and (camp[id] or 0) or 0
end

-- รวมของในกระสอบ + คลังแคมป์ (คลังแคมป์นับเฉพาะตอนอยู่ในแคมป์)
function InventoryService:Available(player, id, inCamp)
	local group = Items.AnyGroups[id]
	if group then
		local n = 0
		for _, g in ipairs(group) do
			n += self:Available(player, g, inCamp)
		end
		return n
	end
	return (self:Get(player)[id] or 0) + self:CampCount(player, id, inCamp)
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

-- ที่เก็บ Tool ทั้งหมดของผู้เล่น (ทุก Backpack — ตอนเกิดใหม่ Roblox อาจมี Backpack เก่าค้างชั่วครู่ — + ตัวละคร)
function InventoryService:ToolHolders(player)
	local list = {}
	for _, c in ipairs(player:GetChildren()) do
		if c:IsA("Backpack") then
			table.insert(list, c)
		end
	end
	if player.Character then
		table.insert(list, player.Character)
	end
	return list
end

-- เครื่องมือต้องมีชนิดละ 1 อันเท่านั้น: ลบ Tool ที่ซ้ำ (เก็บอันที่ถืออยู่) และ Tool ที่ไม่มีในกระเป๋าแล้ว
function InventoryService:DedupeTools(player)
	local bag = self:Get(player)
	local keep = {}
	local removed = 0
	local holders = self:ToolHolders(player)
	-- อันที่ถือในมือมาก่อน
	table.sort(holders, function(a, b)
		return a == player.Character and b ~= player.Character
	end)
	for _, holder in ipairs(holders) do
		for _, t in ipairs(holder:GetChildren()) do
			local id = t:IsA("Tool") and not t:GetAttribute("StructureKind") and t:GetAttribute("ItemId")
			if id and Items.Data[id] and Items.Data[id].Category == "Tool" then
				if keep[id] or (bag[id] or 0) <= 0 then
					t:Destroy()
					removed += 1
				else
					keep[id] = t
				end
			end
		end
	end
	return removed
end

function InventoryService:GiveTool(player, id)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return
	end
	for _, container in ipairs(self:ToolHolders(player)) do
		for _, t in ipairs(container:GetChildren()) do
			if t:IsA("Tool") and t:GetAttribute("ItemId") == id then
				return
			end
		end
	end
	local tool = ToolFactory.Build(id)
	if tool then
		tool.Parent = backpack
	end
end

-- สิ่งก่อสร้างที่มีอยู่ -> Tool 1 อันต่อชนิดในแถบเครื่องมือ (ชื่อ + จำนวน + รูป) · หมดแล้วลบ Tool
function InventoryService:SyncStructureTools(player)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return
	end
	local bag = self:Get(player)
	local have = {}
	for _, holder in ipairs({ backpack, player.Character }) do
		for _, t in ipairs(holder and holder:GetChildren() or {}) do
			local kind = t:IsA("Tool") and (t:GetAttribute("StructureKind") or t:GetAttribute("MedKind"))
			if kind then
				if (bag[kind] or 0) <= 0 or have[kind] then
					t:Destroy()
				else
					have[kind] = t
				end
			end
		end
	end
	for id, n in pairs(bag) do
		local item = Items.Data[id]
		local med = item and item.Category == "Medical"
		if n > 0 and item and (item.Category == "Structure" or med) then
			local t = have[id]
			if not t then
				t = Instance.new("Tool")
				t.RequiresHandle = false
				t.CanBeDropped = false
				t.TextureId = ItemThumbs.Url(id)
				t:SetAttribute(med and "MedKind" or "StructureKind", id)
				if med then
					-- ยามีช่องของตัวเองในแถบเครื่องมือ (ไม่กินที่กระสอบ) · ถือแล้วคลิก = ช่วยเพื่อนที่ล้มใกล้ๆ ก่อน ไม่มีก็พันแผลตัวเอง
					--   ถือแล้วเห็นของในมือ (โมเดลจริง) · ใช้ = ท่าพันแผล + หลอดรอ (SurvivalService:UseMedical)
					ToolFactory.DressMedical(t, id)
					t.Activated:Connect(function()
						self.ctx.Services.SurvivalService:UseMedical(player, id)
					end)
				end
				t.Parent = backpack
			end
			t.Name = string.format("%s x%d", item.Thai, n)
			t:SetAttribute("Count", n)
			t.ToolTip = med and string.format("%s x%d · คลิก = ช่วยเพื่อนที่ล้ม / ฟื้นเลือดตัวเอง", item.Thai, n)
				or string.format("%s x%d · คลิก = วาง · R = หมุน", item.Thai, n)
		end
	end
end

-- ใส่ของตรงๆ (ของเริ่มต้น/ซื้อ/คราฟต์) — ไม่สนความจุ
function InventoryService:Add(player, id, n, silent)
	n = n or 1
	if n <= 0 or not Items.Data[id] then
		return
	end
	local bag = self:Get(player)
	if Items.Sacks[id] then
		-- กระสอบมีได้ใบเดียว: ได้ใบใหญ่กว่า -> แทนใบเก่า · ได้ใบเล็กกว่า/เท่าเดิม -> ไม่รับ
		local best = self:BestSack(player)
		if best and Items.Sacks[best] >= Items.Sacks[id] then
			return
		end
		local wasHolding = false
		for sid in pairs(Items.Sacks) do
			if bag[sid] then
				bag[sid] = nil
				wasHolding = self:DestroyTool(player, sid) or wasHolding
			end
		end
		bag[id] = 1
		self:GiveTool(player, id)
		if wasHolding then
			self:EquipItem(player, id)
		end
		markDirty(player)
		if not silent then
			self.ctx.Remotes.Get("HitFx"):FireClient(player, "Pickup", { Item = id, Count = 1 })
		end
		return
	end
	if Limits.Structures[id] then
		local room = self:Room(player, id)
		if room < n then
			self.ctx.Notify(player, self:LimitText(id) .. " — ครบแล้ว", "Error")
			n = room
		end
		if n <= 0 then
			return
		end
		if Limits.Structures[id].Scope == "Server" then
			markAll()
		end
	end
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
		local order = self.order[player] or {}
		self.order[player] = order
		for _ = 1, fit do
			table.insert(order, id)
		end
	end
	return fit
end

-- ของชิ้นล่าสุดที่ยังอยู่ในกระสอบ (กด F ทิ้งตามลำดับ เข้าหลังออกก่อน)
function InventoryService:LastItem(player)
	local bag = self:Get(player)
	local order = self.order[player] or {}
	while #order > 0 do
		local id = order[#order]
		if (bag[id] or 0) > 0 and Items.Bulk(id) then
			return id
		end
		table.remove(order)
	end
	-- ของที่ได้มาทางอื่น (ของเริ่มต้น/คราฟต์)
	for id, n in pairs(bag) do
		if n > 0 and Items.Bulk(id) then
			return id
		end
	end
	return nil
end

function InventoryService:PopOrder(player, id)
	local order = self.order[player]
	if not order then
		return
	end
	for i = #order, 1, -1 do
		if order[i] == id then
			table.remove(order, i)
			return
		end
	end
end

-- ถือกระสอบอยู่ไหม
function InventoryService:HoldingSack(player)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("Kind") == "Sack"
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

function InventoryService:Has(player, cost, mult, inCamp)
	if inCamp == nil then
		inCamp = self:InCamp(player)
	end
	for id, n in pairs(cost) do
		local need = math.max(1, math.ceil(n * (mult or 1)))
		if self:Available(player, id, inCamp) < need then
			return false
		end
	end
	return true
end

-- ใช้ของ: กระสอบก่อน แล้วค่อยคลังแคมป์
function InventoryService:Spend(player, cost, mult)
	local inCamp = self:InCamp(player)
	if not self:Has(player, cost, mult, inCamp) then
		return false
	end
	local bag = self:Get(player)
	local touchedCamp = false
	local function take(id, need)
		local fromBag = math.min(need, bag[id] or 0)
		bag[id] = (bag[id] or 0) - fromBag
		if bag[id] <= 0 then
			bag[id] = nil
		end
		local rest = need - fromBag
		if rest > 0 and inCamp then
			camp[id] = (camp[id] or 0) - rest
			if camp[id] <= 0 then
				camp[id] = nil
			end
			touchedCamp = true
		end
	end
	for id, n in pairs(cost) do
		local need = math.max(1, math.ceil(n * (mult or 1)))
		local group = Items.AnyGroups[id]
		if group then
			-- "ธาตุไหนก็ได้": หยิบจากชนิดที่มีเยอะสุดก่อนทีละชิ้น
			for _ = 1, need do
				local best, bestN = nil, 0
				for _, g in ipairs(group) do
					local a = self:Available(player, g, inCamp)
					if a > bestN then
						best, bestN = g, a
					end
				end
				if best then
					take(best, 1)
				end
			end
		else
			take(id, need)
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

function InventoryService:MarkAll()
	markAll()
end

function InventoryService:ResetCamp()
	table.clear(camp)
	markAll()
end

-- คืนคลังแคมป์ (รอบที่ทีมออกไปหมดแล้วกลับมาเล่นต่อ — RejoinService)
function InventoryService:SetCamp(t)
	table.clear(camp)
	for id, n in pairs(t or {}) do
		if type(n) == "number" and n > 0 and Items.Data[id] then
			camp[id] = n
		end
	end
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

-- ---------------------------------------------------------------- จำนวนสูงสุด (Limits)
-- จำนวนที่ "มี" ตาม scope: ถือในกระเป๋า + วางอยู่ในแมพ
function InventoryService:LimitCount(player, id)
	local lim = Limits.Structures[id]
	if not lim then
		return 0
	end
	local n = 0
	if lim.Scope == "Server" then
		for p, bag in pairs(inv) do
			if p.Parent then
				n += bag[id] or 0
			end
		end
	else
		n = self:Count(player, id)
	end
	if id == "Bed" then
		-- เตียง = โควต้าข้ามวัน: นับที่ใช้ไปแล้ว (เตียงพังก็ไม่คืน)
		return n + (self.ctx.State:GetAttribute("BedsUsed") or 0)
	end
	for _, m in ipairs(CollectionService:GetTagged("Structure")) do
		if m:GetAttribute("Kind") == id and (lim.Scope == "Server" or m:GetAttribute("Owner") == player.UserId) then
			n += 1
		end
	end
	return n
end

-- ได้เพิ่มอีกกี่ชิ้น (math.huge = ไม่จำกัด)
function InventoryService:Room(player, id)
	local lim = Limits.Structures[id]
	if not lim then
		return math.huge
	end
	return math.max(0, lim.Max - self:LimitCount(player, id))
end

function InventoryService:LimitText(id)
	local lim = Limits.Structures[id]
	return lim and string.format("%s ได้สูงสุด %d %s", Items.DisplayName(id), lim.Max, lim.Scope == "Server" and "ต่อเกม (ทั้งเซิร์ฟ)" or "ต่อคน") or ""
end

-- ตั้ง attribute จำนวนปัจจุบันให้ client (หน้าคราฟต์โชว์ 3/8)
function InventoryService:SyncLimits(player)
	for id in pairs(Limits.Structures) do
		player:SetAttribute(Limits.AttrName(id), self:LimitCount(player, id))
	end
end

function InventoryService:MarkDirty(player)
	if player then
		markDirty(player)
	else
		markAll()
	end
end

-- กระสอบใบที่ใหญ่สุดที่มี (nil = ไม่มีกระสอบ)
function InventoryService:BestSack(player)
	local bag = self:Get(player)
	local best
	for id, c in pairs(Items.Sacks) do
		if (bag[id] or 0) > 0 and (not best or c > Items.Sacks[best]) then
			best = id
		end
	end
	return best
end

-- ลบ Tool ของไอเทมนี้ออกจากเป้/มือ -> คืน true ถ้าถืออยู่ในมือ
function InventoryService:DestroyTool(player, id)
	local holding = false
	for _, holder in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		for _, t in ipairs(holder and holder:GetChildren() or {}) do
			if t:IsA("Tool") and t:GetAttribute("ItemId") == id then
				holding = holding or holder == player.Character
				t:Destroy()
			end
		end
	end
	return holding
end

function InventoryService:EquipItem(player, id)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChild("Backpack")
	if not (hum and backpack and hum.Health > 0) then
		return false
	end
	for _, t in ipairs(backpack:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("ItemId") == id then
			hum:EquipTool(t)
			return true
		end
	end
	return false
end

-- อาวุธหลักที่ให้ถือตอนเกิด: ขวานที่ดีที่สุด (หรือคทา/อาวุธคลาส ถ้าไม่มีขวาน)
function InventoryService:BestAxe(player)
	local bag = self:Get(player)
	local best, bestChop
	for id, n in pairs(bag) do
		local t = n > 0 and Items.Tools[id]
		if t and (t.Kind == "Axe" or t.Kind == "Staff") then
			local chop = (t.Chop or 0) + (t.Kind == "Axe" and 0.01 or 0) -- เท่ากัน -> เลือกขวาน
			if not best or chop > bestChop then
				best, bestChop = id, chop
			end
		end
	end
	return best
end

-- ลำดับช่องในแถบเครื่องมือ: ขวาน -> กระสอบ -> อื่นๆ
local function toolOrder(id)
	local t = Items.Tools[id]
	if t and t.Kind == "Axe" then
		return 1
	elseif Items.Sacks[id] then
		return 2
	elseif t and t.Kind == "Staff" then
		return 3
	end
	return 4
end
InventoryService.ToolOrder = toolOrder

-- คืน Tool ทุกชิ้นหลังเกิดใหม่
function InventoryService:RestoreTools(player)
	local ids = {}
	for id, n in pairs(self:Get(player)) do
		if n > 0 and Items.Data[id] and Items.Data[id].Category == "Tool" then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local oa, ob = toolOrder(a), toolOrder(b)
		if oa ~= ob then
			return oa < ob
		end
		return a < b
	end)
	self:DedupeTools(player)
	for _, id in ipairs(ids) do
		self:GiveTool(player, id)
	end
	markDirty(player)
end

function InventoryService:Start(ctx)
	Players.PlayerRemoving:Connect(function(p)
		dirty[p] = nil
		-- ล้างทีหลัง: ให้ระบบอื่น (RejoinService) อ่านของในกระสอบตอนออกเกมได้ก่อน
		task.defer(function()
			inv[p] = nil
			dirty[p] = nil
			self.order[p] = nil
		end)
	end)
	-- ส่งข้อมูลเมื่อมีการเปลี่ยน (รวมเป็นรอบละครั้ง): { Bag, Camp, Cap, Used }
	task.spawn(function()
		local remote = ctx.Remotes.Get("Inventory")
		task.spawn(function()
			-- กวาดเครื่องมือซ้ำเป็นระยะ (กันกรณีที่ไม่ผ่าน markDirty)
			while true do
				task.wait(2)
				for _, p in ipairs(Players:GetPlayers()) do
					if inv[p] and self:DedupeTools(p) > 0 then
						warn("[Inventory] removed duplicate tools for " .. p.Name)
					end
				end
			end
		end)
		while true do
			task.wait(0.15)
			for p in pairs(dirty) do
				dirty[p] = nil
				if p.Parent then
					self:SyncStructureTools(p)
					self:DedupeTools(p)
					self:SyncLimits(p)
					local cap, used = self:Capacity(p), self:Used(p)
					remote:FireClient(p, { Bag = self:Get(p), Camp = camp, Cap = cap, Used = used })
					-- โชว์จำนวนในกระสอบบนช่องเครื่องมือ เช่น "กระสอบเก่า 3/10"
					for _, c in ipairs({ p:FindFirstChild("Backpack"), p.Character }) do
						for _, t in ipairs(c and c:GetChildren() or {}) do
							local id = t:IsA("Tool") and t:GetAttribute("ItemId")
							if id and Items.Sacks[id] then
								t.Name = string.format("%s %d/%d", Items.DisplayName(id), used, Items.Sacks[id])
								t:SetAttribute("Fill", string.format("%d/%d", used, Items.Sacks[id]))
							end
						end
					end
				end
			end
		end
	end)
end

return InventoryService
