--[[
	DataService — เซฟถาวร: เพชร 💎, คลาสที่ซื้อแล้ว, สถิติ
	ใน Studio ถ้ายังไม่เปิด API Services จะใช้ข้อมูลชั่วคราว (ไม่เซฟ)
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Classes)

local DataService = {}
local profiles = {}
local store
local storeOk = false

local function default()
	return {
		Diamonds = 0, Owned = { Survivor = true }, Class = "Survivor", BestNight = 0, Runs = 0, Wins = 0, Kills = 0, PendingKits = {},
		ClassLevel = {}, ClassStats = {}, StockDay = 0, StockRoll = 0, LastDaily = -1, NightsTotal = 0,
	}
end

function DataService:Init(ctx)
	self.ctx = ctx
	local ok = pcall(function()
		store = DataStoreService:GetDataStore("AnimalSurvival_v1")
	end)
	storeOk = ok and store ~= nil
end

local function key(player)
	return "u_" .. player.UserId
end

function DataService:Load(player)
	local data
	if storeOk and player.UserId > 0 then
		local ok, res = pcall(function()
			return store:GetAsync(key(player))
		end)
		if ok and type(res) == "table" then
			data = res
		elseif not ok then
			warn("[AS] โหลดเซฟไม่ได้ (ยังไม่เปิด API Services?)", res)
		end
	end
	data = data or default()
	for k, v in pairs(default()) do
		if data[k] == nil then
			data[k] = v
		end
	end
	if ReplicatedStorage:FindFirstChild("ASSandbox") then
		data.Diamonds = 99999
	end
	profiles[player] = data
	self:EnsureStock(data)
	player:SetAttribute("Diamonds", data.Diamonds)
	local cls = data.Owned[data.Class] and data.Class or "Survivor"
	player:SetAttribute("Class", cls)
	player:SetAttribute("ClassLevel", data.ClassLevel[cls] or 1)
	return data
end

-- สต็อกร้านคลาส: วันใหม่ = รีเซ็ตรอบรีโรล
function DataService:EnsureStock(data)
	local today = Classes.Day()
	if data.StockDay ~= today then
		data.StockDay = today
		data.StockRoll = 0
	end
end

function DataService:Push(player)
	local data = profiles[player]
	if data then
		player:SetAttribute("Diamonds", data.Diamonds)
		self.ctx.Remotes.Get("Profile"):FireClient(player, data)
	end
end

-- สถิติของคลาสที่สวมอยู่ (ใช้ขึ้นเลเวลคลาส)
function DataService:AddClassStat(player, stat, n)
	local data = profiles[player]
	if not data then
		return
	end
	local cls = player:GetAttribute("Class") or "Survivor"
	local stats = data.ClassStats[cls] or {}
	data.ClassStats[cls] = stats
	stats[stat] = (stats[stat] or 0) + (n or 1)
	local level = data.ClassLevel[cls] or 1
	local req = Classes.Requirement(cls, level + 1)
	if req then
		local ok = true
		for k, need in pairs(req) do
			if (stats[k] or 0) < need then
				ok = false
			end
		end
		if ok then
			self:SetClassLevel(player, cls, level + 1)
			self.ctx.Notify(player, string.format("⭐ คลาส %s ขึ้นเลเวล %d! ปลดทักษะใหม่", Classes.Data[cls].Thai, level + 1), "Reward")
		end
	end
end

-- หม้อรางวัลประจำวันในล็อบบี้ (วันละครั้ง ตามวัน UTC)
function DataService:ClaimDaily(player)
	local data = profiles[player]
	if not data then
		return
	end
	local today = Classes.Day()
	if data.LastDaily == today then
		local s = Classes.SecondsToRestock()
		self.ctx.Notify(player, string.format("รับรางวัลวันนี้แล้ว — มาใหม่ใน %d ชม. %d นาที", s // 3600, (s % 3600) // 60), "Info")
		return
	end
	data.LastDaily = today
	self:AddDiamonds(player, Classes.DailyReward, "รางวัลประจำวัน")
	self:Save(player)
end

function DataService:SetClassLevel(player, cls, level)
	local data = profiles[player]
	data.ClassLevel[cls] = math.clamp(level, 1, Classes.MaxLevel)
	if (player:GetAttribute("Class") or "Survivor") == cls then
		player:SetAttribute("ClassLevel", data.ClassLevel[cls])
		self.ctx.Services.SurvivalService:OnClassChosen(player, cls)
	end
	self:Push(player)
end

function DataService:Get(player)
	return profiles[player]
end

function DataService:Save(player)
	local data = profiles[player]
	if not (data and storeOk and player.UserId > 0) then
		return
	end
	pcall(function()
		store:SetAsync(key(player), data)
	end)
end

function DataService:AddDiamonds(player, n, reason)
	local data = profiles[player]
	if not data then
		return
	end
	data.Diamonds += n
	player:SetAttribute("Diamonds", data.Diamonds)
	self.ctx.Notify(player, string.format("💎 +%d เพชร  (%s)", n, reason or ""), "Reward")
	self.ctx.Remotes.Get("Profile"):FireClient(player, data)
end

function DataService:Start(ctx)
	local Remotes = ctx.Remotes
	Remotes.Get("GetProfile").OnServerInvoke = function(player)
		return profiles[player]
	end
	Remotes.Get("BuyClass").OnServerEvent:Connect(function(player, classId)
		local data = profiles[player]
		local c = Classes.Data[classId]
		if not (data and c) or data.Owned[classId] then
			return
		end
		self:EnsureStock(data)
		if not Classes.Stock(data.StockDay, data.StockRoll, player.UserId)[classId] then
			ctx.Notify(player, "คลาสนี้ไม่มีสต๊อควันนี้ — รอรีสต็อกหรือกดรีโรล", "Error")
			return
		end
		if data.Diamonds < c.Price then
			ctx.Notify(player, "💎 เพชรไม่พอ", "Error")
			return
		end
		data.Diamonds -= c.Price
		data.Owned[classId] = true
		player:SetAttribute("Diamonds", data.Diamonds)
		ctx.Notify(player, "ปลดล็อกคลาส " .. c.Thai .. " แล้ว!", "Reward")
		Remotes.Get("Profile"):FireClient(player, data)
		self:Save(player)
	end)
	Remotes.Get("ChooseClass").OnServerEvent:Connect(function(player, classId)
		local data = profiles[player]
		if not (data and Classes.Data[classId] and data.Owned[classId]) then
			return
		end
		data.Class = classId
		player:SetAttribute("Class", classId)
		player:SetAttribute("ClassLevel", data.ClassLevel[classId] or 1)
		ctx.Services.SurvivalService:OnClassChosen(player, classId)
		Remotes.Get("Profile"):FireClient(player, data)
	end)
	Remotes.Get("RerollStock").OnServerEvent:Connect(function(player)
		local data = profiles[player]
		if not data or player:GetAttribute("InRun") then
			return
		end
		if data.Diamonds < Classes.RerollPrice then
			ctx.Notify(player, "💎 เพชรไม่พอรีโรลสต็อค", "Error")
			return
		end
		self:EnsureStock(data)
		data.Diamonds -= Classes.RerollPrice
		data.StockRoll += 1
		ctx.Notify(player, "🎲 สุ่มสต็อคร้านคลาสใหม่แล้ว", "Info")
		self:Push(player)
	end)
	Remotes.Get("SkipClassLevel").OnServerEvent:Connect(function(player, classId)
		local data = profiles[player]
		local c = Classes.Data[classId]
		if not (data and c and data.Owned[classId]) then
			return
		end
		local level = data.ClassLevel[classId] or 1
		if level >= Classes.MaxLevel then
			return
		end
		local price = Classes.SkipPrice(classId, level + 1)
		if data.Diamonds < price then
			ctx.Notify(player, "💎 เพชรไม่พอข้ามเลเวล", "Error")
			return
		end
		data.Diamonds -= price
		ctx.Notify(player, string.format("⭐ %s เลเวล %d!", c.Thai, level + 1), "Reward")
		self:SetClassLevel(player, classId, level + 1)
		self:Save(player)
	end)
	Remotes.Get("ClaimDaily").OnServerEvent:Connect(function(player)
		self:ClaimDaily(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Save(player)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		for _, p in ipairs(Players:GetPlayers()) do
			self:Save(p)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, p in ipairs(Players:GetPlayers()) do
				self:Save(p)
			end
		end
	end)
end

return DataService
