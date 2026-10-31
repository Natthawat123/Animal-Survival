--[[
	SeasonService — Season Pass 30 วัน (สายฟรี + สายพรีเมียม) + ฉายา/สีฉายา
	  · XP ได้จากภารกิจ/ล็อกอิน/รอดผ่านคืน/ล่าสัตว์/บอส/ช่วยวิญญาณ (QuestService เรียก AddXP)
	  · ขึ้นซีซั่นใหม่ (ทุก 30 วัน นับจาก Quests.SeasonEpoch) = XP และขั้นที่รับแล้วเริ่มใหม่ (ฉายา/สีที่ได้ไปแล้วอยู่ถาวร)
	  · สายพรีเมียม: Game Pass "SeasonPass" ใน Config.GamePasses (MonetizationService:HasPass)
	  · ฉายาที่ใส่อยู่ = player attribute "Title" (+ "TitleColor") -> ป้ายบนหัวในล็อบบี้ (LobbyService:RefreshTag)
	  เซฟ: Season = { Id, XP, Free = { T1 = true }, Prem = { ... } }, Titles, NameColors, EquipTitle, EquipColor
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Quests = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quests"))
local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))

local SeasonService = {}

local DEFAULT_TITLE_COLOR = Color3.fromRGB(255, 236, 170)

function SeasonService:Init(ctx)
	self.ctx = ctx
end

local function ds(self)
	return self.ctx.Services.DataService
end

function SeasonService:Ensure(_player, data)
	local changed = false
	local cur = Quests.Season()
	if type(data.Season) ~= "table" or data.Season.Id ~= cur then
		data.Season = { Id = cur, XP = 0, Free = {}, Prem = {} }
		changed = true
	end
	data.Season.Free = type(data.Season.Free) == "table" and data.Season.Free or {}
	data.Season.Prem = type(data.Season.Prem) == "table" and data.Season.Prem or {}
	data.Season.XP = tonumber(data.Season.XP) or 0
	for _, k in ipairs({ "Titles", "NameColors" }) do
		if type(data[k]) ~= "table" then
			data[k] = {}
		end
	end
	if type(data.EquipTitle) ~= "string" then
		data.EquipTitle = ""
	end
	if type(data.EquipColor) ~= "string" then
		data.EquipColor = ""
	end
	return changed
end

function SeasonService:OnLoad(player, data)
	self:Ensure(player, data)
	self:Apply(player, data)
end

function SeasonService:HasPremium(player)
	local shop = self.ctx.Services.MonetizationService
	return shop ~= nil and shop:HasPass(player, Quests.SeasonPassKey)
end

-- ฉายาที่ใส่อยู่ -> attributes บนตัวผู้เล่น -> ป้ายบนหัว/กระดานอันดับ
function SeasonService:Apply(player, data)
	data = data or ds(self):Get(player)
	if not data then
		return
	end
	local t = Quests.Titles[data.EquipTitle]
	local col = Quests.Colors[data.EquipColor]
	player:SetAttribute("Title", t and (t.Icon .. " " .. t.Text) or "")
	player:SetAttribute("TitleColor", col and col.Color or DEFAULT_TITLE_COLOR)
	player:SetAttribute("NameColor", col and col.Color or nil)
	local lobby = self.ctx.Services.LobbyService
	if lobby and lobby.RefreshTag then
		task.spawn(lobby.RefreshTag, lobby, player)
	end
end

function SeasonService:AddXP(player, n)
	local data = ds(self):Get(player)
	n = math.floor(tonumber(n) or 0)
	if not data or n <= 0 then
		return
	end
	self:Ensure(player, data)
	local before = Quests.TierOf(data.Season.XP)
	data.Season.XP += n
	local after = Quests.TierOf(data.Season.XP)
	if after > before then
		self.ctx.Notify(player, string.format("🎟 Season Pass ขึ้นขั้น %d! กดรับรางวัลได้ที่เมนู \"ภารกิจ\"", after), "Reward")
	end
	local qs = self.ctx.Services.QuestService
	if qs then
		qs:MarkDirty(player)
	end
end

-- ฉายา/สี (ไม่รวม Ruby) — ใช้กับรางวัลซีซั่นและโค้ด
function SeasonService:GrantCosmetics(player, reward)
	local data = ds(self):Get(player)
	if not data then
		return
	end
	self:Ensure(player, data)
	local equip = false
	if reward.Title and Quests.Titles[reward.Title] then
		if not data.Titles[reward.Title] then
			data.Titles[reward.Title] = true
			self.ctx.Notify(player, "🏷 ได้ฉายาใหม่: " .. Quests.Titles[reward.Title].Text, "Reward")
		end
		if data.EquipTitle == "" then
			data.EquipTitle = reward.Title
			equip = true
		end
	end
	if reward.Color and Quests.Colors[reward.Color] then
		if not data.NameColors[reward.Color] then
			data.NameColors[reward.Color] = true
			self.ctx.Notify(player, "🎨 ได้สีฉายาใหม่: " .. Quests.Colors[reward.Color].Text, "Reward")
		end
		if data.EquipColor == "" then
			data.EquipColor = reward.Color
			equip = true
		end
	end
	if equip then
		self:Apply(player, data)
	end
end

-- คลาส (สูงสุด 4 ดาว) · มีอยู่แล้ว -> Ruby ชดเชยครึ่งราคา
function SeasonService:GrantClass(player, classId, reason)
	local data = ds(self):Get(player)
	local c = Classes.Data[classId]
	if not (data and c) then
		return
	end
	data.Owned = type(data.Owned) == "table" and data.Owned or {}
	if data.Owned[classId] then
		local refund = Quests.ClassRefund(classId)
		self.ctx.Notify(player, string.format("มีคลาส %s แล้ว — ได้ %d Ruby แทน", c.Thai, refund), "Reward")
		ds(self):AddDiamonds(player, refund, reason)
		return
	end
	data.Owned[classId] = true
	self.ctx.Notify(player, c.Icon .. " ปลดล็อกคลาส " .. c.Thai .. " จาก Season Pass!", "Reward")
	ds(self):Push(player)
end

local function grant(self, player, reward, reason)
	if (reward.Ruby or 0) > 0 then
		ds(self):AddDiamonds(player, reward.Ruby, reason)
	end
	if reward.Class then
		self:GrantClass(player, reward.Class, reason)
	end
	if reward.Title or reward.Color then
		self:GrantCosmetics(player, reward)
	end
end

-- track = "Free" / "Prem" / "All" (รับทุกขั้นที่ถึงแล้ว) · tier = 1..30
function SeasonService:Claim(player, track, tier)
	local data = ds(self):Get(player)
	if not data then
		return
	end
	self:Ensure(player, data)
	local reached = Quests.TierOf(data.Season.XP)
	local prem = self:HasPremium(player)
	local list = {}
	if track == "All" then
		for t = 1, reached do
			table.insert(list, { "Free", t })
			if prem then
				table.insert(list, { "Prem", t })
			end
		end
	elseif (track == "Free" or track == "Prem") and type(tier) == "number" then
		table.insert(list, { track, math.floor(tier) })
	else
		return
	end
	local got = 0
	for _, e in ipairs(list) do
		local tr, t = e[1], e[2]
		local reward = Quests.Track[tr][t]
		local key = "T" .. t
		if reward and t >= 1 and t <= reached and not data.Season[tr][key] then
			if tr == "Prem" and not prem then
				self.ctx.Notify(player, "🔒 สายพรีเมียมต้องมี Season Pass (ร้านค้า → Game Pass)", "Info")
			else
				data.Season[tr][key] = true
				grant(self, player, reward, string.format("Season Pass ขั้น %d%s", t, tr == "Prem" and " (พรีเมียม)" or ""))
				got += 1
			end
		end
	end
	if got > 0 then
		local qs = self.ctx.Services.QuestService
		if qs then
			qs:Push(player)
			qs:SaveSoon(player)
		end
	elseif track == "All" then
		self.ctx.Notify(player, "ยังไม่มีรางวัลให้รับ — สะสม XP เพิ่มอีกนิด!", "Info")
	end
end

-- kind = "Title" / "Color" · id = "" = ถอด
function SeasonService:Equip(player, kind, id)
	local data = ds(self):Get(player)
	if not data or type(id) ~= "string" then
		return
	end
	self:Ensure(player, data)
	if kind == "Title" and (id == "" or data.Titles[id]) then
		data.EquipTitle = id
	elseif kind == "Color" and (id == "" or data.NameColors[id]) then
		data.EquipColor = id
	else
		return
	end
	self:Apply(player, data)
	local qs = self.ctx.Services.QuestService
	if qs then
		qs:Push(player)
	end
end

function SeasonService:Start(ctx)
	ctx.Remotes.Get("ClaimSeason").OnServerEvent:Connect(function(player, track, tier)
		self:Claim(player, track, tier)
	end)
	ctx.Remotes.Get("EquipCosmetic").OnServerEvent:Connect(function(player, kind, id)
		self:Equip(player, kind, id)
	end)
	-- ซื้อ Season Pass ระหว่างเล่น -> ให้ client วาดสายพรีเมียมใหม่
	local function hook(player)
		player:GetAttributeChangedSignal("Pass_" .. Quests.SeasonPassKey):Connect(function()
			local qs = ctx.Services.QuestService
			if qs then
				qs:Push(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
end

return SeasonService
