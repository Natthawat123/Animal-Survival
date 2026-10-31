--[[
	TraderService — พ่อค้าเร่ (แบบ Pelt Trader ใน 99 Nights)
	มาที่แคมป์ช่วงกลางวันทุก 3 วัน (วันที่ 2, 5, 8 ...) แลกหนัง/กระดูก/แก่นธาตุ เป็นยา วัตถุดิบ และอาวุธ
	พลบค่ำ = เก็บร้านกลับ
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Shared.Shop)
local Items = require(ReplicatedStorage.Shared.Items)
local Limits = require(ReplicatedStorage.Shared.Limits)
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
	-- พ่อค้าเร่จาก Creator Store (คนคลุมผ้า) + ตัวชนใสไว้ติดปุ่มแลกของ
	local PropBuilder = require(game:GetService("ReplicatedStorage").Shared.PropBuilder)
	local store = Instance.new("Model")
	store.Name = "Trader"
	if PropBuilder.Imported("TraderNPC", cf, 3.8, store) then
		local body = part(store, { Name = "Body", Size = V(2.6, 6.6, 2), CFrame = cf * CF(0, 3.3, 0), Transparency = 1 })
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = C(255, 200, 120), 18, 1.5
		l.Parent = body
		return store, body
	end
	store:Destroy()
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
	-- มาเยือนรอบใหม่ = รีเซ็ตโควต้าแลกของของทุกคน
	for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
		for _, o in ipairs(Shop.Trader) do
			pl:SetAttribute("Trade_" .. o.Id, nil)
		end
	end
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
	self.ctx.Broadcast("พ่อค้าเร่มาถึงแคมป์", "Reward")
end

function TraderService:Leave()
	if self.model then
		self.model:Destroy()
		self.model = nil
		self.ctx.State:SetAttribute("TraderHere", false)
		self.ctx.Broadcast("พ่อค้าเร่ไปแล้ว", "Info")
	end
end

function TraderService:OnDay(day)
	if day >= 2 and (day - 2) % Shop.TraderEvery == 0 then
		self:Arrive()
	end
end

function TraderService:Start(ctx)
	local function trade(player, offerId)
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
		-- โควต้าต่อการมาเยือน + ของที่มีแล้ว/ครบจำนวน -> ไม่ให้แลก (ไม่เสียของ)
		local key = "Trade_" .. offerId
		local used = player:GetAttribute(key) or 0
		if used >= Limits.TradesPerVisit then
			ctx.Notify(player, string.format("แลกรายการนี้ครบ %d ครั้งแล้ว — รอพ่อค้ามาครั้งหน้า", Limits.TradesPerVisit), "Error")
			return
		end
		for id, n in pairs(offer.Give) do
			if Items.Data[id] and Items.Data[id].Category == "Tool" and inv:Count(player, id) > 0 then
				ctx.Notify(player, "มี " .. Items.DisplayName(id) .. " อยู่แล้ว", "Info")
				return
			end
			if inv:Room(player, id) < n then
				ctx.Notify(player, inv:LimitText(id) .. " — ครบแล้ว", "Error")
				return
			end
		end
		if not inv:Spend(player, offer.Cost) then
			ctx.Notify(player, "ของแลกไม่พอ", "Error")
			return
		end
		for id, n in pairs(offer.Give) do
			inv:Add(player, id, n)
		end
		player:SetAttribute(key, used + 1)
		ctx.Notify(player, string.format("🐾 แลกของสำเร็จ! (รายการนี้แลกได้อีก %d ครั้ง)", Limits.TradesPerVisit - used - 1), "Good")
	end
	TraderService.TestTrade = trade
	ctx.Remotes.Get("Trade").OnServerEvent:Connect(trade)
	ctx.State:GetAttributeChangedSignal("Phase"):Connect(function()
		local ph = ctx.State:GetAttribute("Phase")
		if ph == "Dusk" or ph == "Night" or ph == "Ended" or ph == "Lobby" then
			self:Leave()
		end
	end)
end

return TraderService
