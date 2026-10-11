--[[
	Quests — ข้อมูลกลาง (ใช้ทั้ง server และ client) ของระบบ "ภารกิจ"
	  · ภารกิจรายวัน 3 อัน (สุ่มต่อคน ต่อวัน UTC) + รายสัปดาห์ 3 อัน (สัปดาห์เริ่มวันจันทร์ UTC)
	  · ล็อกอิน 7 วันติด (รวมกับหม้อรางวัลประจำวันในล็อบบี้ = รับวันละครั้งที่ไหนก็ได้)
	  · Season Pass 30 วัน: สายฟรี + สายพรีเมียม (Game Pass "SeasonPass" ใน Config.GamePasses)
	  · ความสำเร็จ (หน้า "ป้าย"): ถึงเกณฑ์แล้วกดรับ Ruby ได้ครั้งเดียว
	ความคืบหน้าทั้งหมดนับฝั่ง server (QuestService) แล้วเก็บในเซฟ — client ใช้ไฟล์นี้แค่แสดงผล
]]

local Quests = {}

---------------------------------------------------------------- เวลา (UTC)
function Quests.Day(now)
	return math.floor((now or os.time()) / 86400)
end

-- สัปดาห์ (นับจาก 1970) เริ่มวันจันทร์ 00:00 UTC — วันที่ 0 (1 ม.ค. 1970) เป็นวันพฤหัส
function Quests.Week(now)
	return math.floor((Quests.Day(now) + 3) / 7)
end

function Quests.SecondsToDayReset(now)
	now = now or os.time()
	return (Quests.Day(now) + 1) * 86400 - now
end

function Quests.SecondsToWeekReset(now)
	now = now or os.time()
	return ((Quests.Week(now) + 1) * 7 - 3) * 86400 - now
end

-- "5 ชม. 12 นาที" / "2 วัน 3 ชม."
function Quests.FormatTime(s)
	s = math.max(0, math.floor(s))
	if s >= 86400 then
		return string.format("%d วัน %d ชม.", s // 86400, (s % 86400) // 3600)
	elseif s >= 3600 then
		return string.format("%d ชม. %d นาที", s // 3600, (s % 3600) // 60)
	end
	return string.format("%d นาที", math.max(1, s // 60))
end

---------------------------------------------------------------- ภารกิจ
-- Daily/Weekly = { เป้าต่ำสุด, เป้าสูงสุด, Ruby ต่ำสุด, Ruby สูงสุด } · Step = ปัดเป้าเป็นเลขกลมๆ · Weight = โอกาสถูกสุ่ม
Quests.Pool = {
	{ Id = "Kill", Icon = "🐾", Text = "ล่าสัตว์ %d ตัว", Daily = { 8, 20, 6, 12 }, Weekly = { 80, 150, 30, 45 }, Step = 1 },
	{ Id = "Night", Icon = "🌙", Text = "รอดผ่านคืน %d คืน", Daily = { 2, 4, 6, 12 }, Weekly = { 15, 25, 35, 50 }, Step = 1 },
	{ Id = "Fuel", Icon = "🔥", Text = "เติมเชื้อเพลิงกองไฟ %d หน่วย", Daily = { 120, 300, 5, 10 }, Weekly = { 1200, 2000, 30, 45 }, Step = 10 },
	{ Id = "Wood", Icon = "🪵", Text = "เก็บไม้ %d ชิ้น", Daily = { 30, 60, 5, 9 }, Weekly = { 250, 400, 30, 40 }, Step = 5 },
	{ Id = "Stone", Icon = "🪨", Text = "เก็บหิน %d ชิ้น", Daily = { 15, 35, 5, 9 }, Weekly = { 150, 250, 30, 40 }, Step = 5 },
	{ Id = "Craft", Icon = "🔨", Text = "คราฟต์ของ %d ชิ้น", Daily = { 3, 6, 5, 9 }, Weekly = { 20, 30, 30, 40 }, Step = 1 },
	{ Id = "Revive", Icon = "🩹", Text = "ช่วยชีวิตเพื่อนที่ล้ม %d ครั้ง", Daily = { 1, 2, 8, 12 }, Weekly = { 4, 6, 35, 45 }, Step = 1, Weight = 0.6 },
	{ Id = "FriendNight", Icon = "🤝", Text = "รอดผ่านคืนพร้อมเพื่อน %d คืน", Daily = { 1, 3, 8, 12 }, Weekly = { 8, 12, 35, 50 }, Step = 1, Weight = 0.6 },
	{ Id = "Run", Icon = "🚪", Text = "ออกเดินทางผจญภัย %d รอบ", Daily = { 1, 2, 4, 6 }, Step = 1 },
	{ Id = "Spirit", Icon = "✨", Text = "ช่วยวิญญาณธาตุ %d ตน", Weekly = { 1, 2, 40, 60 }, Step = 1 },
	{ Id = "Boss", Icon = "👹", Text = "ปราบบอสธาตุ %d ตัว", Weekly = { 1, 3, 40, 60 }, Step = 1 },
}
Quests.ById = {}
for _, q in ipairs(Quests.Pool) do
	Quests.ById[q.Id] = q
end
Quests.PerDay = 3
Quests.PerWeek = 3
Quests.DailyXP = 60 -- Season XP ต่อภารกิจรายวันที่กดรับ
Quests.WeeklyXP = 250

-- สุ่มภารกิจชุดใหม่ (ผลเหมือนเดิมทุกครั้งสำหรับคน/วันเดียวกัน) -> { { Id, Need, Ruby, Prog = 0 } x count }
function Quests.Roll(scope, period, userId, count)
	local rng = Random.new(period * 7919 + (userId % 1000003) * 31 + (scope == "Weekly" and 17 or 3))
	local bag = {}
	for _, q in ipairs(Quests.Pool) do
		if q[scope] then
			table.insert(bag, q)
		end
	end
	local out = {}
	while #out < count and #bag > 0 do
		local total = 0
		for _, q in ipairs(bag) do
			total += q.Weight or 1
		end
		local r = rng:NextNumber() * total
		local pick = #bag
		for i, q in ipairs(bag) do
			r -= q.Weight or 1
			if r <= 0 then
				pick = i
				break
			end
		end
		local q = table.remove(bag, pick)
		local spec = q[scope]
		local t = rng:NextNumber()
		local step = q.Step or 1
		local need = math.max(step, math.floor((spec[1] + (spec[2] - spec[1]) * t) / step + 0.5) * step)
		local ruby = math.floor(spec[3] + (spec[4] - spec[3]) * t + 0.5)
		table.insert(out, { Id = q.Id, Need = need, Ruby = ruby, Prog = 0, Claimed = false })
	end
	return out
end

function Quests.Describe(entry)
	local q = Quests.ById[entry.Id]
	if not q then
		return "❔", "ภารกิจ"
	end
	return q.Icon, string.format(q.Text, entry.Need or 0)
end

---------------------------------------------------------------- ล็อกอิน 7 วัน (วันที่ 7 = รางวัลใหญ่ แล้ววนกลับวันที่ 1)
Quests.LoginRewards = { 5, 8, 10, 12, 15, 20, 60 }
Quests.LoginXP = 40

---------------------------------------------------------------- Season Pass
Quests.SeasonEpoch = 1767225600 -- 1 ม.ค. 2026 00:00 UTC = เริ่มซีซั่น 1
Quests.SeasonLength = 30 * 86400
Quests.SeasonTiers = 30
Quests.XPPerTier = 300
Quests.SeasonPassKey = "SeasonPass" -- Config.GamePasses[].Id
Quests.XP = { Night = 25, Kill = 3, Boss = 60, Spirit = 80 } -- XP ที่ได้ระหว่างเล่น

function Quests.Season(now)
	now = now or os.time()
	return math.max(1, math.floor((now - Quests.SeasonEpoch) / Quests.SeasonLength) + 1)
end

function Quests.SecondsToSeasonEnd(now)
	now = now or os.time()
	return Quests.SeasonEpoch + Quests.Season(now) * Quests.SeasonLength - now
end

function Quests.TierOf(xp)
	return math.min(Quests.SeasonTiers, math.floor((xp or 0) / Quests.XPPerTier))
end

-- ฉายา (โชว์บนหัวในล็อบบี้) และสีฉายา
Quests.Titles = {
	Camper = { Text = "ชาวแคมป์", Icon = "⛺" },
	NightOwl = { Text = "นกฮูกราตรี", Icon = "🦉" },
	SeasonHero = { Text = "วีรชนแห่งฤดูกาล", Icon = "🏅" },
	Firekeeper = { Text = "ผู้เฝ้าเปลวไฟ", Icon = "🔥" },
	BeastSlayer = { Text = "นักล่าอสูร", Icon = "⚔" },
	ElementLord = { Text = "เจ้าแห่งสี่ธาตุ", Icon = "🔮" },
	Legend = { Text = "ตำนานแห่งพงไพร", Icon = "👑" },
	Pioneer = { Text = "ผู้บุกเบิก", Icon = "🧭" },
}
Quests.TitleOrder = { "Camper", "NightOwl", "SeasonHero", "Pioneer", "Firekeeper", "BeastSlayer", "ElementLord", "Legend" }
Quests.Colors = {
	Sky = { Text = "ฟ้าคราม", Color = Color3.fromRGB(120, 210, 255) },
	Gold = { Text = "ทองคำ", Color = Color3.fromRGB(255, 214, 90) },
	Ember = { Text = "ถ่านแดง", Color = Color3.fromRGB(255, 120, 70) },
	Frost = { Text = "น้ำแข็ง", Color = Color3.fromRGB(190, 240, 255) },
	Jade = { Text = "หยก", Color = Color3.fromRGB(110, 235, 150) },
	Violet = { Text = "ม่วงอเมทิสต์", Color = Color3.fromRGB(196, 140, 255) },
	Crimson = { Text = "เลือดจันทร์", Color = Color3.fromRGB(255, 70, 100) },
}
Quests.ColorOrder = { "Sky", "Gold", "Ember", "Frost", "Jade", "Violet", "Crimson" }

-- รางวัลแต่ละขั้น: { Ruby = n } / { Title = id } / { Color = id } (ใส่หลายอย่างในขั้นเดียวได้)
Quests.Track = { Free = {}, Prem = {} }
do
	local freeSpecial = { [10] = { Title = "Camper" }, [15] = { Color = "Sky" }, [20] = { Title = "NightOwl" }, [30] = { Title = "SeasonHero", Ruby = 40 } }
	local premSpecial = {
		[1] = { Color = "Gold", Ruby = 10 }, [5] = { Title = "Firekeeper" }, [8] = { Color = "Ember" }, [12] = { Color = "Frost" },
		[15] = { Title = "BeastSlayer" }, [18] = { Color = "Jade" }, [22] = { Color = "Violet" }, [25] = { Title = "ElementLord" },
		[28] = { Color = "Crimson" }, [30] = { Title = "Legend", Ruby = 120 },
	}
	for t = 1, Quests.SeasonTiers do
		Quests.Track.Free[t] = freeSpecial[t] or { Ruby = (t % 5 == 0) and 15 or ((t % 2 == 0) and 8 or 5) }
		Quests.Track.Prem[t] = premSpecial[t] or { Ruby = (t % 5 == 0) and 30 or (10 + math.floor(t / 6) * 3) }
	end
end

-- ข้อความสั้นของรางวัล (ใช้ใน UI / แจ้งเตือน)
function Quests.RewardText(r)
	local parts = {}
	if r.Ruby then
		table.insert(parts, "♦️ " .. r.Ruby)
	end
	if r.Title and Quests.Titles[r.Title] then
		table.insert(parts, Quests.Titles[r.Title].Icon .. " ฉายา " .. Quests.Titles[r.Title].Text)
	end
	if r.Color and Quests.Colors[r.Color] then
		table.insert(parts, "🎨 สี" .. Quests.Colors[r.Color].Text)
	end
	return table.concat(parts, " + ")
end

---------------------------------------------------------------- ความสำเร็จ (หน้า "ป้าย")
-- Stat = ช่องในเซฟ (หรือค่าคำนวณ OwnedCount / MaxClassLevel) · Need = เป้า · Ruby = รางวัลครั้งเดียว
Quests.Achievements = {
	{ Id = "Night5", Text = "🌙 รอดถึงคืนที่ 5", Stat = "BestNight", Need = 5, Ruby = 10 },
	{ Id = "Night10", Text = "🌙 รอดถึงคืนที่ 10", Stat = "BestNight", Need = 10, Ruby = 20 },
	{ Id = "Night25", Text = "🌕 รอดถึงคืนที่ 25", Stat = "BestNight", Need = 25, Ruby = 40 },
	{ Id = "Night50", Text = "🌕 รอดถึงคืนที่ 50", Stat = "BestNight", Need = 50, Ruby = 80 },
	{ Id = "Night99", Text = "👑 พิชิตคืนสุดท้าย", Stat = "BestNight", Need = 99, Ruby = 200 },
	{ Id = "Kills50", Text = "🐾 ล่าสัตว์ 50 ตัว", Stat = "Kills", Need = 50, Ruby = 10 },
	{ Id = "Kills250", Text = "🐾 ล่าสัตว์ 250 ตัว", Stat = "Kills", Need = 250, Ruby = 30 },
	{ Id = "Kills1000", Text = "🐺 ล่าสัตว์ 1000 ตัว", Stat = "Kills", Need = 1000, Ruby = 80 },
	{ Id = "Nights20", Text = "🔥 รอดรวม 20 คืน", Stat = "NightsTotal", Need = 20, Ruby = 15 },
	{ Id = "Nights100", Text = "🔥 รอดรวม 100 คืน", Stat = "NightsTotal", Need = 100, Ruby = 50 },
	{ Id = "Owned3", Text = "🎒 มีคลาส 3 คลาส", Stat = "OwnedCount", Need = 3, Ruby = 15 },
	{ Id = "Owned6", Text = "🎒 มีคลาส 6 คลาส", Stat = "OwnedCount", Need = 6, Ruby = 30 },
	{ Id = "OwnedAll", Text = "🏆 สะสมครบทุกคลาส", Stat = "OwnedCount", Need = "AllClasses", Ruby = 100 },
	{ Id = "ClassLv3", Text = "⭐ คลาสเลเวล 3", Stat = "MaxClassLevel", Need = 3, Ruby = 20 },
	{ Id = "Revive10", Text = "🩹 ช่วยชีวิตเพื่อน 10 ครั้ง", Stat = "Revives", Need = 10, Ruby = 25 },
	{ Id = "Revive50", Text = "🩹 ช่วยชีวิตเพื่อน 50 ครั้ง", Stat = "Revives", Need = 50, Ruby = 60 },
	{ Id = "Fuel1000", Text = "🔥 เติมเชื้อเพลิง 1,000 หน่วย", Stat = "FuelAdded", Need = 1000, Ruby = 15 },
	{ Id = "Fuel10000", Text = "🔥 เติมเชื้อเพลิง 10,000 หน่วย", Stat = "FuelAdded", Need = 10000, Ruby = 50 },
	{ Id = "Craft50", Text = "🔨 คราฟต์ของ 50 ชิ้น", Stat = "Crafts", Need = 50, Ruby = 25 },
	{ Id = "Craft250", Text = "🔨 คราฟต์ของ 250 ชิ้น", Stat = "Crafts", Need = 250, Ruby = 60 },
	{ Id = "Gather1000", Text = "🪵 เก็บวัตถุดิบ 1,000 ชิ้น", Stat = "Gathered", Need = 1000, Ruby = 30 },
	{ Id = "Runs20", Text = "🚪 ออกเดินทาง 20 รอบ", Stat = "Runs", Need = 20, Ruby = 25 },
	{ Id = "Runs100", Text = "🚪 ออกเดินทาง 100 รอบ", Stat = "Runs", Need = 100, Ruby = 80 },
	{ Id = "Spirits4", Text = "✨ ช่วยวิญญาณธาตุ 4 ตน", Stat = "SpiritsSaved", Need = 4, Ruby = 40 },
	{ Id = "Boss10", Text = "👹 ปราบบอส 10 ตัว", Stat = "BossKills", Need = 10, Ruby = 60 },
	{ Id = "Quest30", Text = "📜 ทำภารกิจสำเร็จ 30 อัน", Stat = "QuestsDone", Need = 30, Ruby = 40 },
	{ Id = "Streak7", Text = "📅 ล็อกอินครบ 7 วันติด", Stat = "BestStreak", Need = 7, Ruby = 30 },
}
Quests.AchievementById = {}
for _, a in ipairs(Quests.Achievements) do
	Quests.AchievementById[a.Id] = a
end

-- ค่าเป้าที่ขึ้นกับข้อมูลอื่น (จำนวนคลาสทั้งหมด) — ส่ง classCount มาจาก Classes.Order
function Quests.NeedOf(a, classCount)
	if a.Need == "AllClasses" then
		return classCount or 10
	end
	return a.Need
end

function Quests.StatOf(data, key)
	data = data or {}
	if key == "OwnedCount" then
		local n = 0
		for _, v in pairs(data.Owned or {}) do
			if v then
				n += 1
			end
		end
		return n
	elseif key == "MaxClassLevel" then
		local best = 1
		for _, lv in pairs(data.ClassLevel or {}) do
			best = math.max(best, tonumber(lv) or 1)
		end
		return best
	end
	return tonumber(data[key]) or 0
end

return Quests
