--[[
	StorageService — กล่องเก็บของ (StorageBox 20 ช่อง / BigStorageBox 40 ช่อง) + ประตูไม้ (WoodDoor)
	· กล่อง: กดเปิด -> หน้าต่างกล่อง (Menus) ย้ายของระหว่างกระสอบ <-> กล่อง (เก็บได้เฉพาะของที่อยู่ในกระสอบ Items.Bulk)
	  ของในกล่อง = attribute "Contents" (JSON) บนโมเดล -> ทุกเครื่องเห็นตรงกัน + RejoinService เก็บไปกับสิ่งก่อสร้าง
	  รื้อกล่อง (ค้อนช่าง) = ของในกล่องหล่นลงพื้น
	· ประตู: กดเปิด/ปิด บานหมุนรอบบานพับ 90° (เปิด = เดินผ่านได้) · สัตว์ตีพังได้เหมือนกำแพง
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.Items)

local StorageService = {}

local USE_RANGE = 16 -- ระยะใช้กล่อง (เผื่อแลคจากระยะปุ่ม 10)

function StorageService:Init(ctx)
	self.ctx = ctx
end

function StorageService.Capacity(model)
	local spec = Items.Structures[model:GetAttribute("Kind")]
	return spec and spec.Storage or 0
end

function StorageService.Contents(model)
	local raw = model:GetAttribute("Contents")
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and type(t) == "table" and t or {}
end

local function used(t)
	local n = 0
	for _, c in pairs(t) do
		n += c
	end
	return n
end
StorageService.Used = used

local function write(model, t)
	local clean = {}
	for id, c in pairs(t) do
		if c > 0 and Items.Data[id] then
			clean[id] = math.floor(c)
		end
	end
	model:SetAttribute("Contents", next(clean) and HttpService:JSONEncode(clean) or "")
	model:SetAttribute("Used", used(clean))
end

-- กล่องที่ผู้เล่นคนนี้ใช้ได้ตอนนี้ (สิ่งก่อสร้างจริง + อยู่ใกล้ + อยู่ในรอบ)
function StorageService:Usable(player, model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return false
	end
	local folder = self.ctx.Services.BuildingService.folder
	if model.Parent ~= folder or model:GetAttribute("Broken") or StorageService.Capacity(model) <= 0 then
		return false
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not player:GetAttribute("InRun") then
		return false
	end
	return (root.Position - model:GetPivot().Position).Magnitude <= USE_RANGE
end

-- กระสอบ -> กล่อง
function StorageService:Put(player, model, id, n)
	local inv = self.ctx.Services.InventoryService
	if not (Items.Data[id] and Items.Bulk(id)) then
		return 0
	end
	local t = StorageService.Contents(model)
	local room = StorageService.Capacity(model) - used(t)
	n = math.min(math.floor(tonumber(n) or 1), inv:Count(player, id), room)
	if n <= 0 then
		if room <= 0 then
			self.ctx.Notify(player, "📦 This storage box is full", "Warn")
		end
		return 0
	end
	if not inv:Remove(player, id, n) then
		return 0
	end
	for _ = 1, n do
		inv:PopOrder(player, id)
	end
	t[id] = (t[id] or 0) + n
	write(model, t)
	return n
end

-- กล่อง -> กระสอบ (ใส่ได้เท่าที่กระสอบว่าง)
function StorageService:Take(player, model, id, n)
	local inv = self.ctx.Services.InventoryService
	local t = StorageService.Contents(model)
	n = math.min(math.floor(tonumber(n) or 1), t[id] or 0)
	if n <= 0 then
		return 0
	end
	local got = inv:AddToSack(player, id, n)
	if got <= 0 then
		self.ctx.Notify(player, inv:Capacity(player) > 0 and "🎒 Sack is full" or "🎒 You need a sack to carry items", "Warn")
		return 0
	end
	t[id] -= got
	write(model, t)
	return got
end

function StorageService:PutAll(player, model)
	local inv = self.ctx.Services.InventoryService
	local moved = 0
	for id, c in pairs(table.clone(inv:Get(player))) do
		if c > 0 and Items.Bulk(id) then
			local got = self:Put(player, model, id, c)
			moved += got
			if got < c then
				break -- กล่องเต็ม
			end
		end
	end
	return moved
end

function StorageService:TakeAll(player, model)
	local moved = 0
	for id, c in pairs(StorageService.Contents(model)) do
		local got = self:Take(player, model, id, c)
		moved += got
		if got < c then
			break -- กระสอบเต็ม
		end
	end
	return moved
end

-- รื้อกล่อง: ของในกล่องหล่นพื้น
function StorageService:Spill(model)
	local pos = model:GetPivot().Position + Vector3.new(0, 2, 0)
	for id, c in pairs(StorageService.Contents(model)) do
		self.ctx.Services.DropService:Spawn(id, c, pos, { Spread = 3 })
	end
	write(model, {})
end

---------------------------------------------------------------- ประตู
local DOOR_SWING = math.rad(-95)

function StorageService:SetDoor(model, open)
	local leaf = model:FindFirstChild("Leaf")
	local hinge = leaf and leaf:FindFirstChild("Hinge")
	if not (leaf and hinge and hinge:IsA("BasePart")) then
		return
	end
	open = open == true
	model:SetAttribute("Open", open)
	-- ตำแหน่งปิดเก็บเป็น offset จากจุดหมุนของประตู (ย้ายประตูด้วยค้อนแล้วยังถูก)
	local closed = model:GetAttribute("LeafClosed")
	if not closed then
		closed = model:GetPivot():ToObjectSpace(hinge.CFrame)
		model:SetAttribute("LeafClosed", closed)
	end
	local hingeCF = model:GetPivot() * closed * (open and CFrame.Angles(0, DOOR_SWING, 0) or CFrame.identity)
	local rel = hinge.CFrame:Inverse()
	for _, p in ipairs(leaf:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CFrame = hingeCF * (rel * p.CFrame)
		end
	end
end

---------------------------------------------------------------- ปุ่มกด
function StorageService:Setup(model, kind)
	local spec = Items.Structures[kind]
	if spec and spec.Storage then
		local body = model:FindFirstChild("Body") or model:FindFirstChildWhichIsA("BasePart")
		local p = Instance.new("ProximityPrompt")
		p.Name = "StoragePrompt"
		p.ActionText = "Open"
		p.ObjectText = Items.DisplayName and Items.DisplayName(kind) or kind
		p.HoldDuration = 0
		p.MaxActivationDistance = 10
		p.RequiresLineOfSight = false
		p.Parent = body
		p.Triggered:Connect(function(player)
			if self:Usable(player, model) then
				self.ctx.Remotes.Get("Storage"):FireClient(player, "Open", model)
			end
		end)
		if model:GetAttribute("Used") == nil then
			model:SetAttribute("Used", used(StorageService.Contents(model)))
		end
	elseif kind == "WoodDoor" then
		local leaf = model:FindFirstChild("Leaf")
		local hinge = leaf and leaf:FindFirstChild("Hinge")
		if not hinge then
			return
		end
		local p = Instance.new("ProximityPrompt")
		p.Name = "DoorPrompt"
		p.ActionText = "Open"
		p.ObjectText = "Wood Door"
		p.HoldDuration = 0
		p.MaxActivationDistance = 10
		p.RequiresLineOfSight = false
		p.Parent = model:FindFirstChild("PromptAnchor") or hinge
		local function label()
			p.ActionText = model:GetAttribute("Open") and "Close" or "Open"
		end
		p.Triggered:Connect(function(player)
			if model:GetAttribute("Broken") or not player:GetAttribute("InRun") then
				return
			end
			self:SetDoor(model, not model:GetAttribute("Open"))
			label()
		end)
		self:SetDoor(model, model:GetAttribute("Open") == true)
		label()
	end
end

function StorageService:Start(ctx)
	ctx.Remotes.Get("Storage").OnServerEvent:Connect(function(player, action, model, id, n)
		if not self:Usable(player, model) then
			return
		end
		if action == "Put" and type(id) == "string" then
			self:Put(player, model, id, n)
		elseif action == "Take" and type(id) == "string" then
			self:Take(player, model, id, n)
		elseif action == "PutAll" then
			self:PutAll(player, model)
		elseif action == "TakeAll" then
			self:TakeAll(player, model)
		end
	end)
end

return StorageService
