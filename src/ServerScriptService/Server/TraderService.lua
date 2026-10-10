--[[
	TraderService — พ่อค้าเร่ (แบบ Pelt Trader ใน 99 Nights)
	มาที่แคมป์ช่วงกลางวันทุก 3 วัน (วันที่ 2, 5, 8 ...) แลกหนัง/กระดูก/แก่นธาตุ เป็นยา วัตถุดิบ และอาวุธ
	พลบค่ำ = เก็บร้านกลับ
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Shared.Shop)
local MeshProps = require(ReplicatedStorage.Shared.MeshProps)

local TraderService = {}

local V = Vector3.new
local CF = CFrame.new
local C = Color3.fromRGB

function TraderService:Init(ctx)
	self.ctx = ctx
end

local function part(parent, props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- ตัวพ่อค้า: ผู้ชายผ้าคลุมแบกเป้ใหญ่ + โคมไฟ (สร้างจากชิ้นส่วน)
local function buildTrader(cf)
	local m = Instance.new("Model")
	m.Name = "Trader"
	local cloak = C(110, 80, 52)
	local body = part(m, { Name = "Body", Size = V(2.6, 4.4, 1.8), CFrame = cf * CF(0, 3.4, 0), Color = cloak, Material = Enum.Material.Fabric })
	part(m, { Shape = Enum.PartType.Ball, Size = V(1.9, 1.9, 1.9), CFrame = cf * CF(0, 6.4, 0), Color = C(220, 180, 150) })
	part(m, { ClassName = "WedgePart", Size = V(2.6, 1.6, 2.4), CFrame = cf * CF(0, 7.4, 0.3), Color = cloak, Material = Enum.Material.Fabric })
	part(m, { Size = V(2.8, 3.8, 2.2), CFrame = cf * CF(0, 4.2, 1.9), Color = C(130, 96, 60), Material = Enum.Material.Fabric })
	part(m, { Size = V(1, 1.2, 1), CFrame = cf * CF(0, 6.6, 2.1), Color = C(90, 70, 50), Material = Enum.Material.Wood })
	part(m, { Size = V(0.8, 2.6, 0.8), CFrame = cf * CF(-1, 1, 0), Color = C(70, 50, 36) })
	part(m, { Size = V(0.8, 2.6, 0.8), CFrame = cf * CF(1, 1, 0), Color = C(70, 50, 36) })
	local lamp = part(m, { Size = V(0.8, 1, 0.8), CFrame = cf * CF(1.8, 3.4, -0.8), Color = C(255, 210, 130), Material = Enum.Material.Neon })
	local l = Instance.new("PointLight")
	l.Color = C(255, 200, 120)
	l.Range = 18
	l.Brightness = 2
	l.Parent = lamp
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 50)
	bb.StudsOffset = V(0, 5, 0)
	bb.MaxDistance = 120
	bb.Parent = body
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "🐾 พ่อค้าเร่"
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = C(255, 220, 150)
	t.TextStrokeTransparency = 0.3
	t.Parent = bb
	if MeshProps.Has("Barrel") then
		local b = MeshProps.Build("Barrel")
		b:PivotTo(cf * CF(-3.5, 0, 1))
		b.Parent = m
	end
	if MeshProps.Has("Chest") then
		local c = MeshProps.Build("Chest")
		c:PivotTo(cf * CF(3.5, 0, 1))
		c.Parent = m
	end
	m.PrimaryPart = body
	return m, body
end

function TraderService:Arrive()
	if self.model then
		return
	end
	local camp = self.ctx.CampPosition
	local cf = CF(camp + V(-30, 0, 18), camp)
	local m, body = buildTrader(cf)
	m.Parent = workspace
	self.model = m
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "แลกของ"
	p.ObjectText = "พ่อค้าเร่"
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.Parent = body
	p.Triggered:Connect(function(player)
		self.ctx.Remotes.Get("Cinematic"):FireClient(player, "OpenTrader", {})
	end)
	self.ctx.State:SetAttribute("TraderHere", true)
	self.ctx.Broadcast("🐾 พ่อค้าเร่มาถึงแคมป์แล้ว! เอาหนังสัตว์/กระดูกมาแลกของได้จนถึงพลบค่ำ", "Reward")
end

function TraderService:Leave()
	if self.model then
		self.model:Destroy()
		self.model = nil
		self.ctx.State:SetAttribute("TraderHere", false)
		self.ctx.Broadcast("🐾 พ่อค้าเร่ออกเดินทางต่อแล้ว", "Info")
	end
end

function TraderService:OnDay(day)
	if day >= 2 and (day - 2) % Shop.TraderEvery == 0 then
		self:Arrive()
	end
end

function TraderService:Start(ctx)
	ctx.Remotes.Get("Trade").OnServerEvent:Connect(function(player, offerId)
		if ctx.Services.SurvivalService:IsIncapacitated(player) then
			return
		end
		local offer = Shop.TraderById[offerId]
		if not (offer and self.model) then
			return
		end
		local char = player.Character
		if not char or (char:GetPivot().Position - self.model:GetPivot().Position).Magnitude > 30 then
			ctx.Notify(player, "ต้องอยู่ใกล้พ่อค้า", "Error")
			return
		end
		local inv = ctx.Services.InventoryService
		if not inv:Spend(player, offer.Cost) then
			ctx.Notify(player, "ของแลกไม่พอ", "Error")
			return
		end
		for id, n in pairs(offer.Give) do
			inv:Add(player, id, n)
		end
		ctx.Notify(player, "🐾 แลกของสำเร็จ!", "Good")
	end)
	ctx.State:GetAttributeChangedSignal("Phase"):Connect(function()
		local ph = ctx.State:GetAttribute("Phase")
		if ph == "Dusk" or ph == "Night" or ph == "Ended" or ph == "Lobby" then
			self:Leave()
		end
	end)
end

return TraderService
