--[[
	DataService — เซฟถาวร: Ruby ♦️, คลาสที่ซื้อแล้ว, สถิติ, การตั้งค่า, ป้าย
	ใน Studio ถ้ายังไม่เปิด API Services จะใช้ข้อมูลชั่วคราว (ไม่เซฟ)
	กระดานอันดับทั้งเกม: OrderedDataStore (Config.LeaderboardStore) เก็บ "คืนที่รอดนานสุด" ของทุกคน
]]

local BadgeService = game:GetService("BadgeService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}
local profiles = {}
local store
local storeOk = false
local board -- OrderedDataStore กระดานอันดับ

local function default()
	return {
		Diamonds = 0, Owned = { Survivor = true }, Class = "Survivor", BestNight = 0, Runs = 0, Wins = 0, Kills = 0, PendingKits = {},
		ClassLevel = {}, ClassStats = {}, StockDay = 0, StockRoll = 0, LastDaily = -1, NightsTotal = 0,
		TutorialSeen = false, Settings = {}, TrueEndings = 0, BossKills = 0, Joined = 1, BadgesAwarded = {}, Receipts = {},
		-- ภารกิจ / ล็อกอิน 7 วัน / Season Pass / โค้ด / ความสำเร็จ (QuestService, SeasonService)
		Quests = {}, LoginStreak = 0, BestStreak = 0, AchClaimed = {}, CodesUsed = {}, WeekBest = {},
		Season = {}, Titles = {}, NameColors = {}, EquipTitle = "", EquipColor = "",
		Worlds = {}, WorldCredits = 0, -- โลกที่สร้าง (WorldService)
		Revives = 0, ReviveTokens = 0, FuelAdded = 0, Crafts = 0, Gathered = 0, SpiritsSaved = 0, QuestsDone = 0,
	}
end

function DataService:Init(ctx)
	self.ctx = ctx
	local ok = pcall(function()
		store = DataStoreService:GetDataStore("AnimalSurvival_v1")
		board = DataStoreService:GetOrderedDataStore(Config.LeaderboardStore)
	end)
	storeOk = ok and store ~= nil
end

function DataService:StoreReady()
	return storeOk
end

local function key(player)
	return "u_" .. player.UserId
end

-- ล็อกเซฟต่อเซิร์ฟ (session lock): เซฟหลักเก็บ _Lock = { Job = JobId ของเซิร์ฟที่ถือข้อมูลอยู่, T = เวลาเซฟล่าสุด }
--   ย้ายเซิร์ฟ: เซิร์ฟใหม่รอให้เซิร์ฟเก่าเซฟรอบสุดท้าย (ปลดล็อก) ก่อนค่อยโหลด -> ไม่ได้ข้อมูลเก่ามาเล่นต่อ
--   เซิร์ฟเก่าที่ล็อกโดนแย่งไปแล้ว -> เซฟไม่ทับ (กันข้อมูลย้อน/ของซ้ำ)
local LOCK_STALE = 330 -- วินาที: ล็อกที่ไม่ได้ต่ออายุนานเกินนี้ = เซิร์ฟนั้นดับไปแล้ว (เซฟอัตโนมัติทุก 120 วิ)
local LOCK_WAIT = 8 -- รอเซิร์ฟเก่าปลดล็อกสูงสุดกี่รอบ (รอบละ 3 วิ) แล้วค่อยยึดล็อก
local function jobId()
	return game.JobId ~= "" and game.JobId or "studio"
end

-- โหลด + ล็อกเซฟ · คืน data(หรือ nil = ผู้เล่นใหม่), สำเร็จไหม
local function loadLocked(player)
	local tries, lastErr = 0, nil
	while tries < LOCK_WAIT + 4 do
		tries += 1
		local busy = false
		local loaded
		local ok, err = pcall(function()
			store:UpdateAsync(key(player), function(old)
				local lock = type(old) == "table" and old._Lock
				if lock and lock.Job ~= jobId() and os.time() - (tonumber(lock.T) or 0) < LOCK_STALE and tries <= LOCK_WAIT then
					busy = true
					return nil -- เซิร์ฟอื่นยังถือข้อมูลอยู่: ยังไม่เขียน รอรอบหน้า
				end
				busy = false
				loaded = type(old) == "table" and old or nil
				local out = loaded or default()
				out._Lock = { Job = jobId(), T = os.time() }
				return out
			end)
		end)
		if ok and not busy then
			return loaded, true
		end
		lastErr = err
		if not player.Parent or (not ok and RunService:IsStudio()) then
			break -- Studio ที่ไม่ได้เปิด API Services: พังทันที ไม่ต้องรอ (เทสต์ไม่ค้าง)
		end
		task.wait(ok and 3 or math.min(2 ^ tries, 8))
	end
	warn("[AS] Couldn't load save:", lastErr)
	return nil, false
end

function DataService:Load(player)
	local data
	local noSave = false
	if storeOk and player.UserId > 0 then
		local loaded, ok = loadLocked(player)
		if ok then
			data = loaded
		else
			-- โหลดไม่ได้ (DataStore ล่ม/ยังไม่เปิด API) -> ห้ามเซฟทับของจริงด้วยข้อมูลเปล่า
			noSave = true
			if not RunService:IsStudio() and player.Parent then
				player:Kick("Couldn't load your save data right now — please rejoin in a moment. Your progress is safe.")
				return nil
			end
		end
	end
	data = data or default()
	data._NoSave = noSave or nil
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
	player:SetAttribute("BestNight", data.BestNight or 0)
	player:SetAttribute("ReviveTokens", data.ReviveTokens or 0)
	data.Joined = 1
	if self.ctx.Services.QuestService then
		self.ctx.Services.QuestService:OnLoad(player, data)
	end
	self:PushWorlds(player) -- รายชื่อโลกที่สร้างไว้ -> เมนู Worlds
	task.spawn(self.SyncWorldNights, self, player)
	task.spawn(function()
		self:ClaimGifts(player)
		self:CheckBadges(player)
		-- ใส่ชื่อลงกระดานอันดับ (เผื่อเคยเล่นก่อนมีระบบนี้)
		if (data.BestNight or 0) > 0 then
			self:PushBoard(player)
		end
	end)
	-- คลาสซีซั่น (พงไพร): เดิมซื้อพาสแล้วได้ทันที -> ตอนนี้ต้องกดรับขั้น 30 ของสายพรีเมียมเอง
	--   ที่ได้มาแบบเก่า (ไม่ได้มาจากการกดรับ) = ถอดออก ให้ไปกดรับตามขั้น
	for id, c in pairs(Classes.Data) do
		if c.SeasonReward and data.Owned[id] and not (type(data.SeasonClasses) == "table" and data.SeasonClasses[id]) then
			data.Owned[id] = nil
		end
	end
	local cls = (data.Owned[data.Class] and Classes.Data[data.Class]) and data.Class or "Survivor" -- คลาสที่ถูกลบออกจากเกม -> Survivor
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
			self.ctx.Notify(player, string.format("⭐ Class %s reached level %d! New skill unlocked", Classes.Data[cls].Thai, level + 1), "Reward")
		end
	end
end

-- หม้อรางวัลประจำวันในล็อบบี้ (วันละครั้ง ตามวัน UTC)
function DataService:ClaimDaily(player)
	local data = profiles[player]
	if not data then
		return
	end
	-- หม้อรางวัล = รางวัลล็อกอิน 7 วันติด (QuestService) — รับได้วันละครั้งไม่ว่าจะกดจากหม้อหรือเมนูภารกิจ
	if self.ctx.Services.QuestService then
		return self.ctx.Services.QuestService:ClaimLogin(player)
	end
	local today = Classes.Day()
	if data.LastDaily == today then
		local s = Classes.SecondsToRestock()
		self.ctx.Notify(player, string.format("Already claimed today's reward — come back in %dh %dm", s // 3600, (s % 3600) // 60), "Info")
		return
	end
	data.LastDaily = today
	self:AddDiamonds(player, Classes.DailyReward, "Daily Reward")
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

-- คืนที่รอดนานสุด (อัปเดตทุกเช้าที่รอดได้) -> ป้ายบนหัว + กระดานอันดับทั้งเกม + ป้าย Roblox
function DataService:SetBestNight(player, night)
	local data = profiles[player]
	if not data or night <= (data.BestNight or 0) then
		return
	end
	data.BestNight = night
	player:SetAttribute("BestNight", night)
	task.spawn(function()
		self:PushBoard(player)
		self:CheckBadges(player)
	end)
end

function DataService:PushBoard(player)
	local data = profiles[player]
	if not (data and board and storeOk and player.UserId > 0) then
		return
	end
	pcall(function()
		board:SetAsync(tostring(player.UserId), math.floor(data.BestNight or 0))
	end)
end

-- อันดับ 1..n ทั้งเกม: { { UserId, Value } ... } (nil = อ่านไม่ได้ เช่นยังไม่เปิด API Services)
function DataService:GetTop(n)
	if not (board and storeOk) then
		return nil
	end
	local ok, res = pcall(function()
		local pages = board:GetSortedAsync(false, n, 1)
		local out = {}
		for _, e in ipairs(pages:GetCurrentPage()) do
			table.insert(out, { UserId = tonumber(e.key), Value = e.value })
		end
		return out
	end)
	return ok and res or nil
end

-- ป้าย Roblox (Config.Badges): ให้เมื่อสถิติถึงเกณฑ์ (ข้ามป้ายที่ยังไม่ได้ใส่ BadgeId)
function DataService:CheckBadges(player)
	local data = profiles[player]
	if not data or player.UserId <= 0 then
		return
	end
	data.BadgesAwarded = data.BadgesAwarded or {}
	for _, b in ipairs(Config.Badges) do
		if (b.BadgeId or 0) > 0 and not data.BadgesAwarded[b.Id] and (data[b.Stat] or 0) >= b.Need then
			local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, b.BadgeId)
			if ok and has then
				data.BadgesAwarded[b.Id] = true
			elseif ok then
				local awarded = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, b.BadgeId)
				if awarded then
					data.BadgesAwarded[b.Id] = true
					self.ctx.Notify(player, "🏅 Badge earned: " .. b.Name, "Reward")
				end
			end
		end
	end
end

-- เซฟ (ลองซ้ำ 3 ครั้งถ้าพลาด) · release = ออกเกมแล้ว ปลดล็อกให้เซิร์ฟถัดไปโหลดได้ทันที
--   คืน false = เซฟไม่ได้ (ล่ม / เซิร์ฟอื่นยึดล็อกไปแล้ว / โหลดไม่สำเร็จตั้งแต่แรก)
function DataService:Save(player, release)
	local data = profiles[player]
	if not (data and storeOk and player.UserId > 0) or data._NoSave then
		return false
	end
	for attempt = 1, 3 do
		local stolen = false
		local ok, err = pcall(function()
			store:UpdateAsync(key(player), function(old)
				local lock = type(old) == "table" and old._Lock
				if lock and lock.Job ~= jobId() then
					stolen = true
					return nil -- อีกเซิร์ฟถือข้อมูลอยู่ (คนนี้ย้ายไปแล้ว) -> ไม่เขียนทับของใหม่กว่า
				end
				data._Lock = (not release) and { Job = jobId(), T = os.time() } or nil
				return data
			end)
		end)
		if ok then
			if stolen then
				warn("[AS] save skipped: profile is now owned by another server", player.UserId)
				data._NoSave = true
				return false
			end
			return true
		end
		warn("[AS] save failed (try " .. attempt .. "):", err)
		if attempt < 3 then
			task.wait(attempt * 2)
		end
	end
	return false
end

---------------------------------------------------------------- เซฟรอบ (Game Pass Save Run)
-- โลกที่สร้างไว้ (World Pass): เก็บแยกคีย์ "runsave_<UserId>" (ตารางเดียวกับ RejoinService:SerializeRun) · โลกเดียว เซฟใหม่ทับของเก่า
local function runKey(userId)
	return "runsave_" .. userId
end

function DataService:SaveRun(player, run)
	if not storeOk then
		return false
	end
	local ok, err = pcall(function()
		store:SetAsync(runKey(player.UserId), run)
	end)
	if not ok then
		warn("[AS] save run:", err)
	elseif player.Parent then
		player:SetAttribute("SavedNight", run.Night)
	end
	return ok
end

function DataService:LoadRun(userId)
	if not storeOk then
		return nil
	end
	local ok, v = pcall(function()
		return store:GetAsync(runKey(userId))
	end)
	return ok and type(v) == "table" and type(v.Seed) == "number" and v or nil
end

---------------------------------------------------------------- โลกที่สร้าง (จ่ายต่อ 1 โลก · WorldService)
-- รายชื่อโลกอยู่ในโปรไฟล์ data.Worlds[id] = { Name, Night, Created } · ตัวโลก (แมพ/แคมป์/ของ) เก็บแยกคีย์ "world_<UserId>_<id>"
local function worldKey(userId, id)
	return "world_" .. userId .. "_" .. id
end

-- ส่งรายชื่อโลกให้เมนู Worlds (attribute MyWorlds = JSON)
function DataService:PushWorlds(player)
	local data = profiles[player]
	if not data then
		return
	end
	local list = {}
	for id, w in pairs(type(data.Worlds) == "table" and data.Worlds or {}) do
		table.insert(list, { Id = id, Name = w.Name, Night = w.Night or 1, Created = w.Created or 0 })
	end
	table.sort(list, function(a, b)
		return a.Created < b.Created
	end)
	player:SetAttribute("MyWorlds", game:GetService("HttpService"):JSONEncode(list))
	player:SetAttribute("WorldCredits", data.WorldCredits or 0)
end

-- เซฟตัวโลก: ไม่พึ่งโปรไฟล์ (ตอนเจ้าของออกเกม โปรไฟล์อาจถูกล้างไปก่อน -> เดิมเซฟไม่ติด กลับมาเริ่มคืน 1)
--   ลองซ้ำ 3 ครั้ง · นับงานเขียนค้าง (BindToClose รอให้เสร็จก่อนเซิร์ฟเวอร์ดับ)
local worldWrites = 0
function DataService:SaveWorld(player, id, run)
	if not (storeOk and type(id) == "string" and id ~= "" and type(run) == "table") then
		return false
	end
	worldWrites += 1
	local ok, err
	for attempt = 1, 3 do
		ok, err = pcall(function()
			store:SetAsync(worldKey(player.UserId, id), run)
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	worldWrites -= 1
	if not ok then
		warn("[AS] save world:", err)
		return false
	end
	local data = profiles[player]
	if data and type(data.Worlds) == "table" and data.Worlds[id] then
		data.Worlds[id].Night = run.Night
		data.Worlds[id].Played = true
		self:PushWorlds(player)
	end
	return true
end

function DataService:PendingWorldWrites()
	return worldWrites
end

-- เข้าเกม: คืนในรายชื่อโลก (โปรไฟล์) อาจเก่ากว่าตัวโลกที่เซฟตอนออก -> อ่านจากตัวโลกจริงมาแสดง
function DataService:SyncWorldNights(player)
	local data = profiles[player]
	if not (data and type(data.Worlds) == "table") then
		return
	end
	for id, w in pairs(data.Worlds) do
		local run = self:LoadWorld(player.UserId, id)
		if run and profiles[player] == data then
			w.Night = run.Night or w.Night
			w.Played = true
		end
	end
	if player.Parent then
		self:PushWorlds(player)
	end
end

function DataService:LoadWorld(userId, id)
	if not storeOk then
		return nil
	end
	local ok, v = pcall(function()
		return store:GetAsync(worldKey(userId, id))
	end)
	return ok and type(v) == "table" and type(v.Seed) == "number" and v or nil
end

-- ลบโลก (ทีมตายหมดในโลก / เจ้าของกดลบ)
function DataService:DeleteWorld(player, id)
	local data = profiles[player]
	if data and type(data.Worlds) == "table" then
		data.Worlds[id] = nil
	end
	if storeOk then
		pcall(function()
			store:RemoveAsync(worldKey(player.UserId, id))
		end)
	end
	self:PushWorlds(player)
	task.spawn(self.Save, self, player)
end

---------------------------------------------------------------- ของขวัญ Ruby (dev ส่งให้ tester)
-- เก็บแยกคีย์ "gift_<UserId>" (ไม่แตะเซฟหลักของคนรับ -> ไม่โดนเซฟของเซิร์ฟอื่นเขียนทับ)
-- คนรับอยู่เซิร์ฟไหนก็ได้/ออฟไลน์: รับตอนเข้าเกม · ออนไลน์อยู่ = MessagingService แจ้งให้เซิร์ฟนั้นรับทันที
local GIFT_TOPIC = "ASGift"
local function giftKey(userId)
	return "gift_" .. userId
end

function DataService:QueueGift(userId, n, from)
	if not storeOk then
		return false, "DataStore unavailable (enable API Services first)"
	end
	local ok, err = pcall(function()
		store:UpdateAsync(giftKey(userId), function(old)
			old = type(old) == "table" and old or {}
			old.Diamonds = (old.Diamonds or 0) + n
			old.From = from
			return old
		end)
	end)
	if ok then
		pcall(MessagingService.PublishAsync, MessagingService, GIFT_TOPIC, userId)
	end
	return ok, err
end

-- รับของขวัญที่ค้างอยู่ (เข้าเกม / มีข้อความแจ้งจากเซิร์ฟอื่น) แล้วเซฟทันที
function DataService:ClaimGifts(player)
	if not (storeOk and profiles[player] and player.UserId > 0) then
		return
	end
	local got, from = 0, nil
	local ok = pcall(function()
		store:UpdateAsync(giftKey(player.UserId), function(old)
			got, from = 0, nil
			if type(old) ~= "table" or (old.Diamonds or 0) <= 0 then
				return nil
			end
			got, from = old.Diamonds, old.From
			return { Diamonds = 0 }
		end)
	end)
	if ok and got > 0 and player.Parent then
		self:AddDiamonds(player, got, "Gift from " .. tostring(from or "the team"), { Flat = true })
		self:Save(player)
	end
end

-- opts.Purchased = Ruby ที่ซื้อด้วย Robux (ไม่คูณ VIP) · opts.Flat = จำนวนตายตัว เช่นโค้ด (ไม่คูณ VIP/โบนัสเพื่อน)
function DataService:AddDiamonds(player, n, reason, opts)
	local data = profiles[player]
	if not data then
		return
	end
	local shop = self.ctx.Services.MonetizationService
	if not (opts and (opts.Purchased or opts.Flat)) and n > 0 and shop and shop:HasPass(player, "VIP") then
		n *= 2
		reason = (reason or "") .. " · VIP x2"
	end
	-- เล่นกับเพื่อน Roblox ในรอบเดียวกัน: +10% (FriendService)
	local friends = self.ctx.Services.FriendService
	if not (opts and (opts.Purchased or opts.Flat)) and n > 0 and friends then
		local extra = friends:Extra(player, n)
		if extra > 0 then
			n += extra
			reason = (reason or "") .. " · Friends +10%"
		end
	end
	data.Diamonds += n
	player:SetAttribute("Diamonds", data.Diamonds)
	self.ctx.Notify(player, string.format("♦️ +%d Ruby  (%s)", n, reason or ""), "Reward")
	self.ctx.Remotes.Get("Profile"):FireClient(player, data)
end

function DataService:Start(ctx)
	local Remotes = ctx.Remotes
	-- ของขวัญจากเซิร์ฟอื่น: ถ้าคนรับอยู่เซิร์ฟนี้ -> รับเลย
	--   SubscribeAsync รอเน็ตได้นาน (Studio ค้างหลายนาที) -> ทำเบื้องหลัง ไม่ให้บล็อกการเริ่มระบบอื่น
	task.spawn(pcall, function()
		MessagingService:SubscribeAsync(GIFT_TOPIC, function(msg)
			local p = Players:GetPlayerByUserId(tonumber(msg.Data) or 0)
			if p then
				self:ClaimGifts(p)
			end
		end)
	end)
	Remotes.Get("GetProfile").OnServerInvoke = function(player)
		return profiles[player]
	end
	Remotes.Get("BuyClass").OnServerEvent:Connect(function(player, classId)
		local data = profiles[player]
		local c = Classes.Data[classId]
		if not (data and c) or data.Owned[classId] then
			return
		end
		if c.Pass or c.SeasonReward then
			return -- คลาสพาส: ปลดด้วย Game Pass (MonetizationService) · คลาสซีซั่น: กดรับขั้นสุดท้ายของ Season Pass เท่านั้น
		end
		self:EnsureStock(data)
		if not Classes.Stock(data.StockDay, data.StockRoll, player.UserId)[classId] then
			ctx.Notify(player, "This class isn't in stock today — wait for restock or reroll", "Error")
			return
		end
		if data.Diamonds < c.Price then
			ctx.Notify(player, "♦️ Not enough Ruby", "Error")
			return
		end
		data.Diamonds -= c.Price
		data.Owned[classId] = true
		player:SetAttribute("Diamonds", data.Diamonds)
		ctx.Notify(player, "Unlocked class " .. c.Thai .. "!", "Reward")
		Remotes.Get("Profile"):FireClient(player, data)
		self:Save(player)
	end)
	Remotes.Get("ChooseClass").OnServerEvent:Connect(function(player, classId)
		local data = profiles[player]
		if not (data and Classes.Data[classId] and data.Owned[classId]) then
			return
		end
		-- เปลี่ยนคลาสได้เฉพาะในล็อบบี้ (กลางรอบเปลี่ยนแล้วได้สกิลคลาสใหม่แต่ไม่ได้ของเริ่มต้น)
		if player:GetAttribute("InRun") then
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
			ctx.Notify(player, "♦️ Not enough Ruby to reroll the stock", "Error")
			return
		end
		self:EnsureStock(data)
		data.Diamonds -= Classes.RerollPrice
		data.StockRoll += 1
		ctx.Notify(player, "🎲 Class shop stock rerolled", "Info")
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
			ctx.Notify(player, "♦️ Not enough Ruby to skip a level", "Error")
			return
		end
		data.Diamonds -= price
		ctx.Notify(player, string.format("⭐ %s level %d!", c.Thai, level + 1), "Reward")
		self:SetClassLevel(player, classId, level + 1)
		self:Save(player)
	end)
	Remotes.Get("ClaimDaily").OnServerEvent:Connect(function(player)
		self:ClaimDaily(player)
	end)
	-- การตั้งค่า (เสียง/กราฟิก/ปุ่มมือถือ): เก็บเฉพาะค่าง่ายๆ ชื่อสั้นๆ
	Remotes.Get("SaveSettings").OnServerEvent:Connect(function(player, settings)
		local data = profiles[player]
		if not data or type(settings) ~= "table" then
			return
		end
		local clean, n = {}, 0
		for k, v in pairs(settings) do
			local tv = type(v)
			if type(k) == "string" and #k <= 24 and (tv == "number" or tv == "boolean" or (tv == "string" and #v <= 24)) then
				clean[k] = v
				n += 1
				if n >= 40 then
					break
				end
			end
		end
		data.Settings = clean
	end)
	Remotes.Get("TutorialDone").OnServerEvent:Connect(function(player)
		local data = profiles[player]
		if data and not data.TutorialSeen then
			data.TutorialSeen = true
			self:Save(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Save(player, true)
		profiles[player] = nil
	end)
	-- เซิร์ฟปิด: เซฟทุกคนพร้อมกัน (ไม่ทีละคน) แล้วรอให้ครบก่อนปิด (Roblox ให้เวลา ~30 วิ)
	game:BindToClose(function()
		local left = 0
		for _, p in ipairs(Players:GetPlayers()) do
			left += 1
			task.spawn(function()
				pcall(self.Save, self, p, true)
				left -= 1
			end)
		end
		local t0 = os.clock()
		while (left > 0 or worldWrites > 0) and os.clock() - t0 < 27 do -- รอเซฟโปรไฟล์ + เซฟโลกที่ค้างอยู่
			task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, p in ipairs(Players:GetPlayers()) do
				self:Save(p)
				self:CheckBadges(p)
			end
		end
	end)
end

return DataService
