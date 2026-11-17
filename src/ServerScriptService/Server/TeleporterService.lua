--[[
	TeleporterService — หินวาร์ป (สิ่งก่อสร้าง "Teleporter" คราฟต์ที่โต๊ะเลเวล 3 · ทั้งเซิร์ฟ 8 อัน · วางได้ทุกที่ในแมพ)
	  ยืนบนหิน กด E -> หน้าต่างเลือกหินวาร์ปอื่น (TeleportUI) -> วาร์ปไปยืนบนหินนั้น (ฉากวาร์ปเดียวกับประตูศาลเจ้า)
	  ReplicatedStorage.TeleporterPins = ตำแหน่ง/ชื่อหินทุกอัน (หินไกลๆ ไม่ถูก stream มาที่ client -> ต้องส่งแยกให้หน้าต่าง/แผนที่)
	    Vector3Value ชื่อ = TpId · attribute Num (เลขหิน 1-8) · Biome (ไบโอมที่ตั้ง)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TeleporterService = {}

local KIND = "Teleporter"
local USE_RANGE = 14 -- ต้องยืนใกล้หินต้นทาง (stud)
local COOLDOWN = 3
local WARP_COLOR = Color3.fromRGB(110, 220, 255)
local PortalService_SUCK = 0.5 -- = PortalService.SuckTime (โผล่ปลายทางตอนนี้)

function TeleporterService:Init(ctx)
	self.ctx = ctx
	self.byId = {} -- [id] = model
	self.nextId = 0
	self.last = {} -- [player] = os.clock() วาร์ปล่าสุด
	local pins = Instance.new("Folder")
	pins.Name = "TeleporterPins"
	pins.Parent = ReplicatedStorage
	self.pins = pins
end

local function usedNums(self)
	local used = {}
	for _, m in pairs(self.byId) do
		used[m:GetAttribute("TpNum") or 0] = true
	end
	return used
end

function TeleporterService:Unregister(model)
	local id = model:GetAttribute("TpId")
	if id and self.byId[id] == model then
		self.byId[id] = nil
		local pin = self.pins:FindFirstChild(tostring(id))
		if pin then
			pin:Destroy()
		end
	end
end

function TeleporterService:Register(model)
	if model:GetAttribute("Kind") ~= KIND or model:GetAttribute("TpId") then
		return
	end
	self.nextId += 1
	local id = self.nextId
	local used = usedNums(self)
	local num = 1
	while used[num] do
		num += 1
	end
	model:SetAttribute("TpId", id)
	model:SetAttribute("TpNum", num)
	self.byId[id] = model
	local pos = model:GetPivot().Position
	local _, biome = self.ctx.Layout:HeightAt(pos.X, pos.Z)
	local pin = Instance.new("Vector3Value")
	pin.Name = tostring(id)
	pin.Value = pos
	pin:SetAttribute("Num", num)
	pin:SetAttribute("Biome", biome)
	pin.Parent = self.pins
	-- ย้ายด้วยค้อนช่าง = ตำแหน่ง/ไบโอมเปลี่ยนตาม
	model:GetPropertyChangedSignal("WorldPivot"):Connect(function()
		local p = model:GetPivot().Position
		pin.Value = p
		local _, b = self.ctx.Layout:HeightAt(p.X, p.Z)
		pin:SetAttribute("Biome", b)
	end)
	model.Destroying:Connect(function()
		self:Unregister(model)
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			self:Unregister(model)
		end
	end)
	model:GetAttributeChangedSignal("Broken"):Connect(function()
		if model:GetAttribute("Broken") then
			self:Unregister(model)
		end
	end)
	local pad = model:FindFirstChild("Pad") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if pad then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TeleportPrompt"
		prompt.ActionText = "Teleport"
		prompt.ObjectText = string.format("Waystone %d", num)
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad
		prompt.Triggered:Connect(function(player)
			self:OpenMenu(player, model)
		end)
	end
end

function TeleporterService:OpenMenu(player, model)
	local id = model:GetAttribute("TpId")
	if not id or not player:GetAttribute("InRun") then
		return
	end
	local others = 0
	for oid in pairs(self.byId) do
		if oid ~= id then
			others += 1
		end
	end
	if others == 0 then
		self.ctx.Notify(player, "🌀 Build another Waystone somewhere on the map to warp between them", "Info")
		return
	end
	self.ctx.Remotes.Get("Teleporter"):FireClient(player, "Menu", id)
end

function TeleporterService:Go(player, fromId, toId)
	if type(fromId) ~= "number" or type(toId) ~= "number" or fromId == toId then
		return
	end
	local from, to = self.byId[fromId], self.byId[toId]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (from and to and root and player:GetAttribute("InRun")) then
		return
	end
	local surv = self.ctx.Services.SurvivalService
	if surv and (surv:IsIncapacitated(player) or not surv:IsAlive(player)) then
		return
	end
	if ((root.Position - from:GetPivot().Position) * Vector3.new(1, 0, 1)).Magnitude > USE_RANGE then
		self.ctx.Notify(player, "Stand on the Waystone to teleport", "Error")
		return
	end
	local now = os.clock()
	if self.last[player] and now - self.last[player] < COOLDOWN then
		return
	end
	self.last[player] = now
	-- ขี่สัตว์อยู่ = วาร์ปไปพร้อมสัตว์ (สัตว์เชื่อม Weld อยู่ใต้ตัวผู้เล่น -> ย้ายตัวผู้เล่นแล้วสัตว์ติดไปด้วย · ความสูงนั่งบนหลังคิดจาก HipHeight ตอนขี่)
	local cf = to:GetPivot()
	local dest = cf.Position + Vector3.new(0, 3, 0)
	local look = dest + cf.LookVector * 10
	self.ctx.Services.PortalService:Teleport(player, dest, look, WARP_COLOR, true)
	-- แสงวาร์ปที่หินต้นทาง/ปลายทาง (เดิมใช้เอฟเฟกต์ "สร้าง" = หินรูนแตกกระจาย/ลอยค้าง ดูเหมือนหินพัง)
	local hit = self.ctx.Remotes.Get("HitFx")
	hit:FireAllClients("WarpPad", { Position = from:GetPivot().Position, Color = WARP_COLOR })
	task.delay(PortalService_SUCK, function()
		hit:FireAllClients("WarpPad", { Position = to:GetPivot().Position, Color = WARP_COLOR, Arrive = true })
	end)
end

function TeleporterService:Start()
	for _, m in ipairs(CollectionService:GetTagged("Structure")) do
		self:Register(m)
	end
	CollectionService:GetInstanceAddedSignal("Structure"):Connect(function(m)
		-- Kind ถูกตั้งก่อนติดแท็ก (BuildingService:Spawn) แต่ Pad อาจยังไม่ถูกใส่ -> รอ 1 เฟรม
		task.defer(function()
			if m.Parent then
				self:Register(m)
			end
		end)
	end)
	self.ctx.Remotes.Get("Teleporter").OnServerEvent:Connect(function(player, action, a, b)
		if action == "Go" then
			self:Go(player, a, b)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		self.last[p] = nil
	end)
end

return TeleporterService
