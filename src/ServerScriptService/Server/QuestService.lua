--[[
	QuestService — ภารกิจรายวัน/รายสัปดาห์ · ล็อกอิน 7 วัน · ความสำเร็จ (รับ Ruby) · โค้ดแลกรางวัล · อันดับรายสัปดาห์
	  ระบบอื่นแจ้งความคืบหน้าด้วย ctx.Services.QuestService:Progress(player, kind, n, extra)
	    kind: "Kill" "Night"(extra = คืนที่รอด) "Fuel" "Gather"(extra = itemId) "Craft" "Revive" "Spirit" "Boss" "Run"
	    นับเฉพาะตอนอยู่ในแมพ (InRun) · ภารกิจ "FriendNight" นับเองตอนรอดผ่านคืนพร้อมเพื่อน Roblox (FriendService)
	  ข้อมูลในเซฟ (DataService): Quests, LoginStreak, BestStreak, AchClaimed, CodesUsed, WeekBest
	    + สถิติ Revives, FuelAdded, Crafts, Gathered, SpiritsSaved, QuestsDone, Runs
	  หม้อรางวัลประจำวันในล็อบบี้ = รับรางวัลล็อกอินของวันนั้น (DataService:ClaimDaily ส่งต่อมาที่ ClaimLogin) ไม่ได้ซ้ำ
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Classes = require(Shared.Classes)
local Quests = require(Shared.Quests)
local Codes = require(script.Parent:WaitForChild("Codes"))

local QuestService = {}

-- kind -> ช่องสถิติในเซฟที่ต้องบวกเพิ่ม (Kills / NightsTotal / BossKills ระบบเดิมนับให้อยู่แล้ว)
local STAT = { Revive = "Revives", Fuel = "FuelAdded", Craft = "Crafts", Spirit = "SpiritsSaved", Run = "Runs" }

local dirty = {} -- [player] = true -> ส่งโปรไฟล์ใหม่ให้ client เมื่อกลับล็อบบี้
local achSeen = {} -- [player] = { [achId] = true } แจ้งเตือน "ปลดล็อกความสำเร็จ" ครั้งเดียว
local saveQueued = {}
local codeCooldown = {}
local weekStores = {}

function QuestService:Init(ctx)
	self.ctx = ctx
end

local function ds(self)
	return self.ctx.Services.DataService
end

---------------------------------------------------------------- เตรียมข้อมูล (วันใหม่/สัปดาห์ใหม่ = สุ่มภารกิจชุดใหม่)
function QuestService:Ensure(player, data)
	local changed = false
	data.Quests = type(data.Quests) == "table" and data.Quests or {}
	local q = data.Quests
	local day, week = Quests.Day(), Quests.Week()
	if q.Day ~= day or type(q.Daily) ~= "table" then
		q.Day = day
		q.Daily = Quests.Roll("Daily", day, player.UserId, Quests.PerDay)
		changed = true
	end
	if q.Week ~= week or type(q.Weekly) ~= "table" then
		q.Week = week
		q.Weekly = Quests.Roll("Weekly", week, player.UserId, Quests.PerWeek)
		changed = true
	end
	for _, k in ipairs({ "AchClaimed", "CodesUsed", "WeekBest" }) do
		if type(data[k]) ~= "table" then
			data[k] = {}
		end
	end
	data.LoginStreak = tonumber(data.LoginStreak) or 0
	data.BestStreak = tonumber(data.BestStreak) or 0
	return changed
end

-- เรียกจาก DataService:Load ทันทีหลังโหลดเซฟ
function QuestService:OnLoad(player, data)
	self:Ensure(player, data)
	local seen = {}
	for _, a in ipairs(Quests.Achievements) do
		if Quests.StatOf(data, a.Stat) >= Quests.NeedOf(a, #Classes.Order) then
			seen[a.Id] = true
		end
	end
	achSeen[player] = seen
	local season = self.ctx.Services.SeasonService
	if season then
		season:OnLoad(player, data)
	end
end

function QuestService:MarkDirty(player)
	dirty[player] = true
end

-- เซฟแบบรวบ (กดรับหลายอันติดกัน = เขียน DataStore ครั้งเดียว)
function QuestService:SaveSoon(player)
	if saveQueued[player] then
		return
	end
	saveQueued[player] = true
	task.delay(6, function()
		saveQueued[player] = nil
		if player.Parent then
			ds(self):Save(player)
		end
	end)
end

function QuestService:Push(player)
	dirty[player] = nil
	ds(self):Push(player)
end

---------------------------------------------------------------- ความคืบหน้า
function QuestService:CheckAchievements(player, data)
	local seen = achSeen[player]
	if not seen then
		return
	end
	for _, a in ipairs(Quests.Achievements) do
		if not seen[a.Id] and Quests.StatOf(data, a.Stat) >= Quests.NeedOf(a, #Classes.Order) then
			seen[a.Id] = true
			if not data.AchClaimed[a.Id] then
				self.ctx.Notify(player, "🏅 ปลดล็อกความสำเร็จ: " .. a.Text .. " — กดรับ ♦️ " .. a.Ruby .. " ที่หน้า \"ป้าย\" ในล็อบบี้", "Reward")
			end
		end
	end
end

local function bump(self, player, list, key, n)
	for _, e in ipairs(list or {}) do
		if e.Id == key and not e.Claimed and (e.Prog or 0) < e.Need then
			e.Prog = math.min(e.Need, (e.Prog or 0) + n)
			if e.Prog >= e.Need then
				local icon, text = Quests.Describe(e)
				self.ctx.Notify(player, string.format("📜 ภารกิจสำเร็จ! %s %s — กลับล็อบบี้ไปกดรับรางวัล", icon, text), "Reward")
			end
		end
	end
end

function QuestService:Progress(player, kind, n, extra)
	n = tonumber(n) or 1
	if n <= 0 or not (player and player.Parent) or not player:GetAttribute("InRun") then
		return
	end
	local data = ds(self):Get(player)
	if not data then
		return
	end
	self:Ensure(player, data)
	local keys = { kind }
	if kind == "Gather" then
		data.Gathered = (tonumber(data.Gathered) or 0) + n
		keys = { extra }
	elseif STAT[kind] then
		data[STAT[kind]] = (tonumber(data[STAT[kind]]) or 0) + n
	end
	if kind == "Night" then
		self:OnNightSurvived(player, data, tonumber(extra) or 0)
		local friends = self.ctx.Services.FriendService
		if friends and friends:Bonus(player) then
			table.insert(keys, "FriendNight")
		end
	end
	for _, key in ipairs(keys) do
		if key then
			bump(self, player, data.Quests.Daily, key, n)
			bump(self, player, data.Quests.Weekly, key, n)
		end
	end
	local xp = Quests.XP[kind]
	local season = self.ctx.Services.SeasonService
	if xp and season then
		season:AddXP(player, xp * n)
	end
	self:CheckAchievements(player, data)
	dirty[player] = true
end

---------------------------------------------------------------- กดรับภารกิจ
function QuestService:ClaimQuest(player, scope, index)
	local data = ds(self):Get(player)
	if not data or (scope ~= "Daily" and scope ~= "Weekly") or type(index) ~= "number" then
		return
	end
	if self:Ensure(player, data) then
		self:Push(player)
		return
	end
	local e = data.Quests[scope] and data.Quests[scope][math.floor(index)]
	if not e or e.Claimed or (e.Prog or 0) < e.Need then
		return
	end
	e.Claimed = true
	data.QuestsDone = (tonumber(data.QuestsDone) or 0) + 1
	local _, text = Quests.Describe(e)
	ds(self):AddDiamonds(player, e.Ruby or 0, (scope == "Daily" and "ภารกิจรายวัน: " or "ภารกิจรายสัปดาห์: ") .. text)
	local season = self.ctx.Services.SeasonService
	if season then
		season:AddXP(player, scope == "Daily" and Quests.DailyXP or Quests.WeeklyXP)
	end
	self:CheckAchievements(player, data)
	self:Push(player)
	self:SaveSoon(player)
end

---------------------------------------------------------------- ล็อกอิน 7 วัน (หม้อรางวัลประจำวัน)
function QuestService:ClaimLogin(player)
	local data = ds(self):Get(player)
	if not data then
		return
	end
	self:Ensure(player, data)
	local today = Quests.Day()
	if data.LastDaily == today then
		self.ctx.Notify(player, "รับรางวัลวันนี้แล้ว — มาใหม่ใน " .. Quests.FormatTime(Quests.SecondsToDayReset()), "Info")
		return
	end
	local streak = 1
	if data.LastDaily == today - 1 then
		streak = (data.LoginStreak % #Quests.LoginRewards) + 1
	end
	data.LastDaily = today
	data.LoginStreak = streak
	data.BestStreak = math.max(data.BestStreak or 0, streak)
	local ruby = Quests.LoginRewards[streak] or Quests.LoginRewards[1]
	ds(self):AddDiamonds(player, ruby, string.format("ล็อกอินวันที่ %d/%d", streak, #Quests.LoginRewards))
	if streak == #Quests.LoginRewards then
		self.ctx.Notify(player, "🎁 ครบ 7 วันติด! รับรางวัลใหญ่แล้ว — พรุ่งนี้เริ่มรอบใหม่", "Reward")
	end
	local season = self.ctx.Services.SeasonService
	if season then
		season:AddXP(player, Quests.LoginXP)
	end
	self:CheckAchievements(player, data)
	self:Push(player)
	ds(self):Save(player)
end

---------------------------------------------------------------- ความสำเร็จ
function QuestService:ClaimAchievement(player, id)
	local data = ds(self):Get(player)
	local a = type(id) == "string" and Quests.AchievementById[id]
	if not (data and a) then
		return
	end
	self:Ensure(player, data)
	if data.AchClaimed[a.Id] then
		return
	end
	if Quests.StatOf(data, a.Stat) < Quests.NeedOf(a, #Classes.Order) then
		self.ctx.Notify(player, "ยังทำความสำเร็จนี้ไม่ครบ", "Error")
		return
	end
	data.AchClaimed[a.Id] = true
	ds(self):AddDiamonds(player, a.Ruby, "ความสำเร็จ: " .. a.Text)
	self:Push(player)
	self:SaveSoon(player)
end

---------------------------------------------------------------- โค้ด
local function normalize(code)
	if type(code) ~= "string" or #code > 40 then
		return nil
	end
	code = string.upper((code:gsub("%s+", "")))
	if code == "" then
		return nil
	end
	return code
end

function QuestService:Redeem(player, raw)
	local now = os.clock()
	if (codeCooldown[player] or 0) > now then
		return { Ok = false, Text = "ใจเย็นๆ ลองใหม่อีกครั้งในอีกสักครู่" }
	end
	codeCooldown[player] = now + 1.5
	local data = ds(self):Get(player)
	if not data then
		return { Ok = false, Text = "ยังโหลดข้อมูลไม่เสร็จ ลองใหม่อีกครั้ง" }
	end
	self:Ensure(player, data)
	local code = normalize(raw)
	local info = code and Codes[code]
	if not info then
		return { Ok = false, Text = "❌ ไม่พบโค้ดนี้ — ตรวจตัวสะกดอีกครั้ง" }
	end
	local t = os.time()
	if info.Starts and t < info.Starts then
		return { Ok = false, Text = "⏳ โค้ดนี้ยังไม่เปิดให้ใช้" }
	end
	if info.Expires and t >= info.Expires then
		return { Ok = false, Text = "⌛ โค้ดนี้หมดอายุแล้ว" }
	end
	if data.CodesUsed[code] then
		return { Ok = false, Text = "✔ ใช้โค้ดนี้ไปแล้ว (ใช้ได้คนละครั้ง)" }
	end
	data.CodesUsed[code] = true
	local reward = { Ruby = info.Ruby, Title = info.Title, Color = info.Color }
	if (info.Ruby or 0) > 0 then
		ds(self):AddDiamonds(player, info.Ruby, "โค้ด " .. code, { Flat = true })
	end
	local season = self.ctx.Services.SeasonService
	if season and (info.Title or info.Color) then
		season:GrantCosmetics(player, reward)
	end
	self:Push(player)
	ds(self):Save(player)
	return { Ok = true, Text = "🎉 แลกโค้ดสำเร็จ! ได้รับ " .. Quests.RewardText(reward) }
end

---------------------------------------------------------------- อันดับรายสัปดาห์ (OrderedDataStore แยกต่อสัปดาห์)
local function weekStore(week)
	if weekStores[week] == nil then
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(Config.LeaderboardStore .. "_W" .. week)
		end)
		weekStores[week] = ok and store or false
	end
	return weekStores[week] or nil
end

function QuestService:OnNightSurvived(player, data, night)
	if night <= 0 then
		return
	end
	local week = Quests.Week()
	local wb = data.WeekBest
	if wb.Week ~= week then
		wb.Week = week
		wb.Night = 0
	end
	if night <= (wb.Night or 0) then
		return
	end
	wb.Night = night
	if not (ds(self):StoreReady() and player.UserId > 0) then
		return
	end
	local store = weekStore(week)
	if not store then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			store:UpdateAsync(tostring(player.UserId), function(old)
				return math.max(tonumber(old) or 0, night)
			end)
		end)
		if not ok then
			warn("[AS] weekly board", err)
		end
	end)
end

-- อันดับสัปดาห์นี้: { { UserId, Value } ... } หรือ nil ถ้าอ่านไม่ได้ (Studio ยังไม่เปิด API Services)
function QuestService:GetTopWeekly(n)
	if not ds(self):StoreReady() then
		return nil
	end
	local store = weekStore(Quests.Week())
	if not store then
		return nil
	end
	local ok, res = pcall(function()
		local pages = store:GetSortedAsync(false, n, 1)
		local out = {}
		for _, e in ipairs(pages:GetCurrentPage()) do
			table.insert(out, { UserId = tonumber(e.key), Value = e.value })
		end
		return out
	end)
	return ok and res or nil
end

-- คืนที่ดีที่สุดสัปดาห์นี้ของคนในเซิร์ฟเวอร์ (ใช้ตอนอ่าน DataStore ไม่ได้)
function QuestService:WeekBestOf(player)
	local data = ds(self):Get(player)
	local wb = data and data.WeekBest
	if type(wb) == "table" and wb.Week == Quests.Week() then
		return wb.Night or 0
	end
	return 0
end

---------------------------------------------------------------- Start
function QuestService:Start(ctx)
	local R = ctx.Remotes
	R.Get("ClaimQuest").OnServerEvent:Connect(function(player, scope, index)
		self:ClaimQuest(player, scope, index)
	end)
	R.Get("ClaimAchievement").OnServerEvent:Connect(function(player, id)
		self:ClaimAchievement(player, id)
	end)
	R.Get("RedeemCode").OnServerInvoke = function(player, code)
		local ok, res = pcall(self.Redeem, self, player, code)
		if ok then
			return res
		end
		warn("[AS] redeem", res)
		return { Ok = false, Text = "เกิดข้อผิดพลาด ลองใหม่อีกครั้ง" }
	end
	local function onPlayer(player)
		player:GetAttributeChangedSignal("InRun"):Connect(function()
			if not player:GetAttribute("InRun") and dirty[player] then
				self:Push(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		dirty[p], achSeen[p], saveQueued[p], codeCooldown[p] = nil, nil, nil, nil
	end)
	-- วันใหม่/สัปดาห์ใหม่ระหว่างออนไลน์ + ส่งความคืบหน้าให้คนที่อยู่ล็อบบี้
	task.spawn(function()
		while true do
			task.wait(5)
			for _, p in ipairs(Players:GetPlayers()) do
				local data = ds(self):Get(p)
				if data then
					if self:Ensure(p, data) then
						dirty[p] = true
						ctx.Notify(p, "📜 ภารกิจใหม่มาแล้ว! เปิดเมนู \"ภารกิจ\" ในล็อบบี้", "Info")
					end
					local season = ctx.Services.SeasonService
					if season and season:Ensure(p, data) then
						dirty[p] = true
					end
					if dirty[p] and not p:GetAttribute("InRun") then
						self:Push(p)
					end
				end
			end
		end
	end)
end

return QuestService
