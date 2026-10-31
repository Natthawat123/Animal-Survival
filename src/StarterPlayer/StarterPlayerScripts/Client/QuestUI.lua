--[[
	QuestUI — หน้าต่าง "ภารกิจ & รางวัล" ในล็อบบี้ (ปุ่ม 📜 ภารกิจ ที่แถบซ้าย) · ธีมกรอบไม้ (WoodKit)
	  แท็บ 📜 ภารกิจ      : รายวัน 3 + รายสัปดาห์ 3 (ความคืบหน้านับฝั่ง server) กดรับ Ruby + Season XP
	  แท็บ 📅 ล็อกอิน 7 วัน : รับวันละครั้ง (ใช้ร่วมกับหม้อรางวัลประจำวัน) ขาดวันเดียวเริ่มใหม่ · เด้งขึ้นเองตอนเข้าเกมถ้ายังไม่รับ
	  แท็บ ✨ Season Pass  : 30 ขั้น สายฟรี + สายพรีเมียม (Game Pass "SeasonPass") + เลือกใส่ฉายา/สีฉายา
	  แท็บ 🎁 โค้ด          : กรอกโค้ดแลกรางวัล (server ตรวจ)
	จุดแดงบนปุ่มแถบซ้าย/แท็บ = มีรางวัลให้กดรับ
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Quests = require(Shared.Quests)
local Classes = require(Shared.Classes)
local UIKit = require(script.Parent.UIKit)
local WoodKit = require(script.Parent.WoodKit)
local LobbyUI = require(script.Parent.LobbyUI)
local Tutorial = require(script.Parent.Tutorial)

local QuestUI = {}
local player = Players.LocalPlayer
local C = UIKit.Colors
local W = WoodKit.Colors
local RS = utf8.char(0xE002) -- ไอคอน Robux ในฟอนต์ของ Roblox
local ui = { Tab = "Quests", Pages = {}, TabButtons = {}, TabDots = {}, Timers = {} }
local profile
local loginShown = false

local TABS = {
	{ Id = "Quests", Text = "📜 ภารกิจ" },
	{ Id = "Login", Text = "📅 ล็อกอิน 7 วัน" },
	{ Id = "Season", Text = "✨ Season Pass" },
	{ Id = "Codes", Text = "🎁 โค้ด" },
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function now()
	return Workspace:GetServerTimeNow()
end

local function clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

-- ปุ่มธีมไม้: กดไม่ได้ = สไตล์ "Off" (ไม่ทำอะไร)
local function button(parent, style, enabled, props, onClick)
	return WoodKit.Button(parent, enabled and style or "Off", props, function()
		if enabled and onClick then
			onClick()
		end
	end)
end

---------------------------------------------------------------- สถานะจากโปรไฟล์
local function seasonPass()
	for _, p in ipairs(Config.GamePasses) do
		if p.Id == Quests.SeasonPassKey then
			return p
		end
	end
	return nil
end

local function hasPremium()
	return player:GetAttribute("Pass_" .. Quests.SeasonPassKey) == true
end

local function questLists()
	local q = profile and profile.Quests
	if type(q) ~= "table" then
		return {}, {}
	end
	local t = now()
	local daily = (q.Day == Quests.Day(t) and type(q.Daily) == "table") and q.Daily or {}
	local weekly = (q.Week == Quests.Week(t) and type(q.Weekly) == "table") and q.Weekly or {}
	return daily, weekly
end

-- Count = วันที่รับไปแล้วในรอบนี้ · Today = วันที่ (1-7) ของวันนี้
local function loginState()
	local today = Quests.Day(now())
	local last = profile and tonumber(profile.LastDaily) or -1
	local streak = profile and tonumber(profile.LoginStreak) or 0
	if last == today then
		return { Claimed = true, Count = streak, Today = streak, Streak = streak }
	end
	local alive = last == today - 1
	local nextDay = alive and (streak % #Quests.LoginRewards) + 1 or 1
	return { Claimed = false, Count = nextDay - 1, Today = nextDay, Streak = alive and streak or 0 }
end

local function seasonState()
	local s = profile and profile.Season
	if type(s) ~= "table" or s.Id ~= Quests.Season(now()) then
		return { XP = 0, Free = {}, Prem = {}, Tier = 0 }
	end
	return { XP = tonumber(s.XP) or 0, Free = s.Free or {}, Prem = s.Prem or {}, Tier = Quests.TierOf(s.XP) }
end

local function counts()
	local n = { Quests = 0, Login = 0, Season = 0, Codes = 0 }
	if not profile then
		return n
	end
	local d, w = questLists()
	for _, list in ipairs({ d, w }) do
		for _, e in ipairs(list) do
			if not e.Claimed and (e.Prog or 0) >= (e.Need or 1) then
				n.Quests += 1
			end
		end
	end
	if not loginState().Claimed then
		n.Login = 1
	end
	local s = seasonState()
	local prem = hasPremium()
	for t = 1, s.Tier do
		if not s.Free["T" .. t] then
			n.Season += 1
		end
		if prem and not s.Prem["T" .. t] then
			n.Season += 1
		end
	end
	return n
end

local function updateDots()
	local n = counts()
	local total = n.Quests + n.Login + n.Season
	LobbyUI.SetQuestDot(total)
	for id, dot in pairs(ui.TabDots) do
		dot.Frame.Visible = (n[id] or 0) > 0
		dot.Label.Text = tostring(n[id] or 0)
	end
	return n
end

local function dotOn(parent)
	local dot = UIKit.Frame(parent, { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -14, 0, -8), BackgroundColor3 = C.Red, BackgroundTransparency = 0, Visible = false, ZIndex = 12 })
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(1, 0)
	dc.Parent = dot
	UIKit.Stroke(dot, rgb(255, 255, 255), 2, 0)
	local label = UIKit.Text(dot, { Size = UDim2.fromScale(1, 1), Text = "!", Font = UIKit.Fonts.Title, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13 })
	return { Frame = dot, Label = label }
end

---------------------------------------------------------------- แท็บ: ภารกิจ
local function questCard(parent, order, e, scope, index)
	local prog, need = e.Prog or 0, math.max(1, e.Need or 1)
	local done = prog >= need
	local claimed = e.Claimed == true
	local tint = claimed and rgb(206, 216, 168) or (done and rgb(255, 228, 150) or nil)
	local f = WoodKit.Parchment(parent, { Size = UDim2.new(1, 0, 0, 132), LayoutOrder = order }, tint)
	local icon, text = Quests.Describe(e)
	WoodKit.Medallion(f, icon, 74, { Position = UDim2.fromOffset(12, 14), ZIndex = 2 }, scope == "Daily" and rgb(96, 40, 22) or W.Night)
	WoodKit.Ink(f, { Position = UDim2.fromOffset(98, 10), Size = UDim2.new(1, -110, 0, 30), Text = text, TextSize = 21 })
	local bar = UIKit.Bar(f, { Size = UDim2.new(1, -112, 0, 22), Position = UDim2.fromOffset(98, 46), Color = done and rgb(110, 200, 80) or W.Gold, Label = string.format("%d / %d", math.min(prog, need), need) })
	bar.Set(math.min(prog / need, 1))
	UIKit.Icon(f, "Ruby", 36, { Position = UDim2.fromOffset(92, 84), ZIndex = 3 })
	local xp = scope == "Daily" and Quests.DailyXP or Quests.WeeklyXP
	WoodKit.Ink(f, { Position = UDim2.fromOffset(128, 88), Size = UDim2.fromOffset(84, 28), Text = (e.Ruby or 0) .. " Ruby", TextSize = 18, TextColor3 = W.Bad })
	WoodKit.Ink(f, { Position = UDim2.fromOffset(214, 88), Size = UDim2.fromOffset(100, 28), Text = "⭐ " .. xp .. " XP", TextSize = 18, TextColor3 = rgb(150, 96, 20) })
	local label = claimed and "✔ รับแล้ว" or (done and "🎁 รับรางวัล" or "กำลังทำ...")
	local style = claimed and "Green" or (done and "Red" or "Wood")
	WoodKit.Button(f, style, { Size = UDim2.fromOffset(134, 40), Position = UDim2.new(1, -146, 1, -52), Text = label, TextSize = 18, ZIndex = 4 }, function()
		if done and not claimed then
			Remotes.Get("ClaimQuest"):FireServer(scope, index)
		end
	end)
	if done and not claimed then
		WoodKit.Shine(f, order * 0.3)
	end
end

local function buildQuests(page)
	clear(page)
	local d, w = questLists()
	local cols = {
		{ "Daily", "☀️ ภารกิจรายวัน", d, W.Red },
		{ "Weekly", "📅 ภารกิจรายสัปดาห์", w, W.Night },
	}
	for i, info in ipairs(cols) do
		local col = UIKit.Frame(page, { BackgroundTransparency = 1, Size = UDim2.new(0.5, -8, 1, 0), Position = UDim2.new((i - 1) * 0.5, (i - 1) * 8, 0, 0) })
		local head = WoodKit.Ribbon(col, { Size = UDim2.new(1, 0, 0, 44) }, info[4], info[2], 22)
		ui.Timers[info[1]] = UIKit.Text(head, { Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -14, 1, 0), Text = "", Font = UIKit.Fonts.Bold, TextSize = 16, TextColor3 = rgb(255, 230, 190), TextXAlignment = Enum.TextXAlignment.Right })
		local list = UIKit.Frame(col, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54) })
		local ll = Instance.new("UIListLayout")
		ll.Padding = UDim.new(0, 10)
		ll.SortOrder = Enum.SortOrder.LayoutOrder
		ll.Parent = list
		for k, e in ipairs(info[3]) do
			questCard(list, k, e, info[1], k)
		end
		if #info[3] == 0 then
			UIKit.Text(list, { Size = UDim2.new(1, 0, 0, 60), Text = "กำลังโหลดภารกิจ...", TextSize = 20, TextColor3 = rgb(226, 206, 176), TextXAlignment = Enum.TextXAlignment.Center })
		end
	end
end

---------------------------------------------------------------- แท็บ: ล็อกอิน 7 วัน
local function buildLogin(page)
	clear(page)
	local st = loginState()
	local total = #Quests.LoginRewards
	local head = WoodKit.Parchment(page, { Size = UDim2.new(1, 0, 0, 74) })
	WoodKit.Ink(head, { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 6), Text = "ล็อกอินทุกวัน รับ Ruby เพิ่มขึ้นเรื่อยๆ — วันที่ 7 รับรางวัลใหญ่!", TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center })
	WoodKit.Ink(head, {
		Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 44), TextSize = 15, Font = UIKit.Fonts.Bold, TextColor3 = W.InkDim, TextXAlignment = Enum.TextXAlignment.Center,
		Text = "ขาดวันเดียวเริ่มนับวันที่ 1 ใหม่ · รับที่นี่หรือที่หม้อรางวัลประจำวันในล็อบบี้ก็ได้ (วันละครั้ง)",
	})
	local row = UIKit.Frame(page, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 86), Size = UDim2.new(1, 0, 0, 258) })
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rl.VerticalAlignment = Enum.VerticalAlignment.Center
	rl.Padding = UDim.new(0, 12)
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	rl.Parent = row
	for i, ruby in ipairs(Quests.LoginRewards) do
		local big = i == total
		local claimed = i <= st.Count
		local isToday = i == st.Today and not st.Claimed
		local status, scol = "🔒", W.InkDim
		if claimed then
			status, scol = "✔ รับแล้ว", W.Good
		elseif isToday then
			status, scol = "วันนี้!", W.Bad
		elseif st.Claimed and i == st.Today + 1 then
			status, scol = "พรุ่งนี้", W.InkDim
		end
		local f
		if big then
			-- วันที่ 7: ป้ายไม้แดงเข้มขอบทอง + หีบสมบัติ
			f = WoodKit.Board(row, { Size = UDim2.fromOffset(180, 256), LayoutOrder = i }, claimed and rgb(52, 92, 50) or rgb(92, 22, 36), W.Gold)
			UIKit.Text(f, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 8), Text = "วันที่ " .. i, Font = UIKit.Fonts.Title, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = W.Gold })
			if not WoodKit.Art(f, "Pack3", 150, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 112), ZIndex = 3 }) then
				UIKit.Icon(f, "Ruby", 80, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 112), ZIndex = 3 })
			end
			UIKit.Text(f, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 1, -84), Text = ruby .. " Ruby", Font = UIKit.Fonts.Title, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
			UIKit.Text(f, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 1, -44), Text = status, Font = UIKit.Fonts.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = isToday and rgb(255, 236, 140) or rgb(240, 224, 200), ZIndex = 5 })
		else
			local tint = claimed and rgb(200, 220, 160) or (isToday and rgb(255, 226, 140) or nil)
			f = WoodKit.Parchment(row, { Size = UDim2.fromOffset(118, 220), LayoutOrder = i }, tint)
			WoodKit.Ink(f, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 10), Text = "วันที่ " .. i, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center })
			UIKit.Icon(f, "Ruby", 70, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 90), ZIndex = 3 })
			WoodKit.Ink(f, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 1, -80), Text = ruby .. " Ruby", TextSize = 21, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
			WoodKit.Ink(f, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 1, -44), Text = status, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = scol, ZIndex = 5 })
		end
		if isToday then
			WoodKit.Shine(f, 0.2)
		end
	end
	local foot = WoodKit.Parchment(page, { Size = UDim2.fromOffset(620, 128), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 356) })
	local streakText = string.format("🔥 ต่อเนื่อง %d วัน   ·   สถิติสูงสุด %d วัน", st.Streak, profile and tonumber(profile.BestStreak) or 0)
	WoodKit.Ink(foot, { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 10), Text = streakText, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center })
	local text
	if st.Claimed then
		text = "✔ รับแล้ว — มาใหม่ใน " .. Quests.FormatTime(Quests.SecondsToDayReset(now()))
	else
		text = string.format("🎁 รับรางวัลวันที่ %d  (%d Ruby)", st.Today, Quests.LoginRewards[st.Today] or 0)
	end
	local b = button(foot, "Red", not st.Claimed, {
		Size = UDim2.fromOffset(460, 56), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Text = text, TextSize = 22,
	}, function()
		Remotes.Get("ClaimDaily"):FireServer()
	end)
	if st.Claimed then
		WoodKit.Style(b, "Green")
	end
	ui.LoginButton = st.Claimed and b or nil
end

---------------------------------------------------------------- แท็บ: Season Pass
local TIER_W = 98

local function rewardVisual(cell, reward)
	if reward.Title and Quests.Titles[reward.Title] then
		local t = Quests.Titles[reward.Title]
		UIKit.Text(cell, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 6), Text = t.Icon, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
		UIKit.Text(cell, { Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 48), Text = "ฉายา", TextSize = 13, TextColor3 = rgb(226, 210, 186), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
		UIKit.Text(cell, { Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 64), Text = t.Text, Font = UIKit.Fonts.Title, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
	elseif reward.Class and Classes.Data[reward.Class] then
		local c = Classes.Data[reward.Class]
		local sc = Classes.StarColor[c.Stars]
		UIKit.Text(cell, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 6), Text = c.Icon, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
		UIKit.Text(cell, { Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 48), Text = "คลาส " .. string.rep("★", c.Stars), TextSize = 13, TextColor3 = sc, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
		UIKit.Text(cell, { Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 64), Text = c.Thai, Font = UIKit.Fonts.Title, TextSize = 15, TextColor3 = sc, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
	elseif reward.Color and Quests.Colors[reward.Color] then
		local col = Quests.Colors[reward.Color]
		local sw = UIKit.Frame(cell, { Size = UDim2.fromOffset(36, 36), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), BackgroundColor3 = col.Color, BackgroundTransparency = 0, ZIndex = 4 })
		WoodKit.Corner(sw, "round")
		WoodKit.Stroke(sw, W.WoodDark, 2, 0)
		UIKit.Text(cell, { Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 48), Text = "สีฉายา", TextSize = 13, TextColor3 = rgb(226, 210, 186), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
		UIKit.Text(cell, { Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 64), Text = col.Text, Font = UIKit.Fonts.Title, TextSize = 15, TextColor3 = col.Color, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
	else
		UIKit.Icon(cell, "Ruby", 48, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), ZIndex = 4 })
		UIKit.Text(cell, { Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 58), Text = (reward.Ruby or 0) .. " Ruby", Font = UIKit.Fonts.Title, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
	end
	if reward.Ruby and (reward.Title or reward.Color or reward.Class) then
		UIKit.Text(cell, { Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 86), Text = "+ " .. reward.Ruby .. " Ruby", TextSize = 13, TextColor3 = rgb(255, 200, 200), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
	end
end

local function promptPremium()
	local pass = seasonPass()
	if pass and (pass.PassId or 0) > 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.PassId)
	end
end

local function tierCell(parent, y, track, t, reward, s, prem)
	local key = "T" .. t
	local claimed = s[track][key] == true
	local reached = t <= s.Tier
	local locked = track == "Prem" and not prem
	local ready = reached and not claimed and not locked
	local base = track == "Prem" and rgb(120, 76, 30) or rgb(40, 44, 78)
	if claimed then
		base = rgb(46, 96, 52)
	elseif ready then
		base = rgb(186, 136, 40)
	end
	local cell = Instance.new("TextButton")
	cell.Text = ""
	cell.AutoButtonColor = false
	cell.BorderSizePixel = 0
	cell.BackgroundColor3 = base
	cell.Size = UDim2.fromOffset(TIER_W - 8, 108)
	cell.Position = UDim2.fromOffset(0, y)
	cell.Parent = parent
	WoodKit.Corner(cell, 8)
	local st = WoodKit.Stroke(cell, ready and rgb(255, 236, 140) or (track == "Prem" and W.Gold or rgb(120, 110, 160)), ready and 3 or 2, 0)
	UIKit.Gradient(cell, Color3.new(1, 1, 1), rgb(160, 150, 150), 90)
	rewardVisual(cell, reward)
	if claimed or locked or not reached then
		local veil = UIKit.Frame(cell, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(14, 8, 6), BackgroundTransparency = claimed and 0.45 or 0.55, ZIndex = 6 })
		WoodKit.Corner(veil, 8)
		local mark = claimed and "✔" or (locked and "🔒" or "")
		if mark ~= "" then
			UIKit.Text(veil, { Size = UDim2.fromScale(1, 1), Text = mark, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7, TextColor3 = claimed and rgb(150, 255, 150) or rgb(255, 230, 160) })
		end
	end
	if ready then
		UIKit.Text(cell, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -4), Text = "กดรับ!", Font = UIKit.Fonts.Title, TextSize = 16, TextColor3 = rgb(255, 240, 150), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8 })
		task.spawn(function()
			while cell.Parent do
				TweenService:Create(st, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { Transparency = 0.6 }):Play()
				task.wait(0.6)
				TweenService:Create(st, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { Transparency = 0 }):Play()
				task.wait(0.6)
			end
		end)
	end
	cell.Activated:Connect(function()
		if UIKit.OnAnyClick then
			UIKit.OnAnyClick()
		end
		if ready then
			Remotes.Get("ClaimSeason"):FireServer(track, t)
		elseif locked then
			promptPremium()
		end
	end)
end

-- ตัวเลือกฉายา/สี: [◀ ก่อนหน้า] ชื่อ [ถัดไป ▶] วนเฉพาะที่มี (+ "ไม่ใส่")
local function selector(parent, x, label, kind, order, defs, owned, equipped)
	local list = { "" }
	for _, id in ipairs(order) do
		if owned[id] then
			table.insert(list, id)
		end
	end
	local idx = table.find(list, equipped) or 1
	local box = WoodKit.Board(parent, { Size = UDim2.new(0.5, -6, 1, 0), Position = UDim2.new(x, x > 0 and 6 or 0, 0, 0) }, rgb(40, 28, 20))
	UIKit.Text(box, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0, 96, 1, 0), Text = label, Font = UIKit.Fonts.Title, TextSize = 18, TextColor3 = W.Gold })
	local id = list[idx]
	local def = id ~= "" and defs[id] or nil
	local name = def and ((def.Icon and (def.Icon .. " ") or "") .. def.Text) or (#list > 1 and "ไม่ใส่" or "ยังไม่ปลดล็อก — ได้จาก Season Pass/โค้ด")
	local nameL = UIKit.Text(box, { Position = UDim2.new(0, 160, 0, 0), Size = UDim2.new(1, -218, 1, 0), Text = name, Font = UIKit.Fonts.Title, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center })
	if kind == "Color" and def then
		nameL.TextColor3 = def.Color
	elseif kind == "Title" and def then
		local col = profile and Quests.Colors[profile.EquipColor]
		nameL.TextColor3 = col and col.Color or rgb(255, 236, 170)
	end
	local function go(step)
		if #list <= 1 then
			return
		end
		local n = ((idx - 1 + step) % #list) + 1
		Remotes.Get("EquipCosmetic"):FireServer(kind, list[n])
	end
	button(box, "Wood", #list > 1, { Size = UDim2.fromOffset(48, 42), Position = UDim2.new(0, 106, 0.5, -21), Text = "◀", TextSize = 20 }, function()
		go(-1)
	end)
	button(box, "Wood", #list > 1, { Size = UDim2.fromOffset(48, 42), Position = UDim2.new(1, -56, 0.5, -21), Text = "▶", TextSize = 20 }, function()
		go(1)
	end)
end

local function buildSeason(page)
	local oldScroll = ui.SeasonScroll and ui.SeasonScroll.CanvasPosition
	clear(page)
	local s = seasonState()
	local prem = hasPremium()
	local season = Quests.Season(now())
	-- ธงซีซั่นด้านซ้าย: ผ้าแดงขอบทอง + หัวหมาป่า
	local flag = WoodKit.Board(page, { Size = UDim2.new(0, 180, 1, -20) }, rgb(120, 24, 28), W.Gold)
	local sname = UIKit.Text(flag, { Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 44), Text = "ซีซั่น " .. season, Font = UIKit.Fonts.Title, TextSize = 36, TextXAlignment = Enum.TextXAlignment.Center })
	UIKit.Gradient(sname, rgb(255, 250, 210), rgb(240, 180, 70), 90)
	if not WoodKit.Art(flag, "Wolf", 168, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), ZIndex = 3 }) then
		UIKit.Text(flag, { Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromScale(0, 0.32), Text = "🐺", TextSize = 72, TextXAlignment = Enum.TextXAlignment.Center })
	end
	ui.Timers.Season = UIKit.Text(flag, { Position = UDim2.new(0, 8, 1, -64), Size = UDim2.new(1, -16, 0, 50), Text = "", TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = rgb(255, 226, 190) })
	local right = UIKit.Frame(page, { BackgroundTransparency = 1, Position = UDim2.fromOffset(194, 0), Size = UDim2.new(1, -194, 1, 0) })
	-- แถบบน: ขั้น + XP / พรีเมียม / รับทั้งหมด
	local top = WoodKit.Board(right, { Size = UDim2.new(1, 0, 0, 80) }, rgb(46, 36, 70), rgb(150, 130, 210))
	UIKit.Text(top, {
		Position = UDim2.fromOffset(16, 6), Size = UDim2.fromOffset(330, 32), Font = UIKit.Fonts.Title, TextSize = 26,
		Text = s.Tier >= Quests.SeasonTiers and ("ขั้น " .. s.Tier .. " / " .. Quests.SeasonTiers .. "  ·  ครบแล้ว! 🎉") or ("ขั้น " .. s.Tier .. " / " .. Quests.SeasonTiers),
	})
	local within = s.Tier >= Quests.SeasonTiers and Quests.XPPerTier or (s.XP % Quests.XPPerTier)
	local bar = UIKit.Bar(top, { Size = UDim2.fromOffset(330, 24), Position = UDim2.fromOffset(16, 44), Color = W.Gold, Label = string.format("⭐ %d / %d XP", within, Quests.XPPerTier) })
	bar.Set(within / Quests.XPPerTier)
	local pass = seasonPass()
	if prem then
		UIKit.Text(top, { Position = UDim2.new(1, -404, 0, 0), Size = UDim2.fromOffset(210, 80), Text = "👑 พรีเมียม ✔", Font = UIKit.Fonts.Title, TextSize = 24, TextColor3 = rgb(255, 214, 90), TextXAlignment = Enum.TextXAlignment.Center })
	else
		local ready = pass ~= nil and (pass.PassId or 0) > 0
		WoodKit.Button(top, "Wood", {
			Size = UDim2.fromOffset(200, 52), Position = UDim2.new(1, -400, 0.5, -26), TextSize = 18,
			Text = ready and ("👑 พรีเมียม  " .. RS .. " " .. pass.Robux) or "👑 พรีเมียม (เร็วๆ นี้)",
		}, promptPremium)
	end
	local claimable = counts().Season
	button(top, "Red", claimable > 0, {
		Size = UDim2.fromOffset(180, 52), Position = UDim2.new(1, -192, 0.5, -26), TextSize = 19,
		Text = claimable > 0 and ("🎁 รับทั้งหมด (" .. claimable .. ")") or "🎁 รับทั้งหมด",
	}, function()
		Remotes.Get("ClaimSeason"):FireServer("All")
	end)
	-- ป้ายแถว
	for i, info in ipairs({ { "🎟\nฟรี", rgb(40, 44, 78), rgb(120, 110, 160) }, { "👑\nพรีเมียม", rgb(120, 76, 30), W.Gold } }) do
		local l = WoodKit.Board(right, { Size = UDim2.fromOffset(84, 108), Position = UDim2.fromOffset(0, 132 + (i - 1) * 116) }, info[2], info[3])
		UIKit.Text(l, { Size = UDim2.fromScale(1, 1), Text = info[1], Font = UIKit.Fonts.Title, TextSize = 17, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center })
	end
	-- รางวัล 30 ขั้น (เลื่อนแนวนอน)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(92, 90)
	scroll.Size = UDim2.new(1, -92, 0, 286)
	scroll.ScrollingDirection = Enum.ScrollingDirection.X
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = W.Gold
	scroll.Parent = right
	ui.SeasonScroll = scroll
	local hl = Instance.new("UIListLayout")
	hl.FillDirection = Enum.FillDirection.Horizontal
	hl.SortOrder = Enum.SortOrder.LayoutOrder
	hl.Padding = UDim.new(0, 0)
	hl.Parent = scroll
	for t = 1, Quests.SeasonTiers do
		local col = UIKit.Frame(scroll, { BackgroundTransparency = 1, Size = UDim2.fromOffset(TIER_W, 274), LayoutOrder = t })
		local reached = t <= s.Tier
		local num = WoodKit.Frame(col, { Size = UDim2.fromOffset(34, 34), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, -4, 0, 2), BackgroundColor3 = reached and W.Gold or rgb(70, 50, 34) })
		WoodKit.Corner(num, "round")
		WoodKit.Stroke(num, W.WoodDark, 2, 0)
		UIKit.Text(num, { Size = UDim2.fromScale(1, 1), Text = tostring(t), Font = UIKit.Fonts.Title, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center })
		tierCell(col, 42, "Free", t, Quests.Track.Free[t], s, prem)
		tierCell(col, 158, "Prem", t, Quests.Track.Prem[t], s, prem)
	end
	task.defer(function()
		if scroll.Parent then
			scroll.CanvasPosition = oldScroll or Vector2.new(math.max(0, (s.Tier - 2) * TIER_W), 0)
		end
	end)
	-- ฉายา / สีฉายา ที่ใส่อยู่ (โชว์บนหัวในล็อบบี้)
	local strip = UIKit.Frame(right, { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -64), Size = UDim2.new(1, 0, 0, 60) })
	selector(strip, 0, "🏷 ฉายา", "Title", Quests.TitleOrder, Quests.Titles, (profile and profile.Titles) or {}, profile and profile.EquipTitle or "")
	selector(strip, 0.5, "🎨 สีฉายา", "Color", Quests.ColorOrder, Quests.Colors, (profile and profile.NameColors) or {}, profile and profile.EquipColor or "")
end

---------------------------------------------------------------- แท็บ: โค้ด (สร้างครั้งเดียว ไม่ล้างข้อความที่พิมพ์ค้างไว้)
local function buildCodes(page)
	-- ของประดับสองข้าง (หีบ Ruby / ถุง Ruby)
	WoodKit.Art(page, "Pack3", 170, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -40), ZIndex = 1 })
	WoodKit.Art(page, "Pack1", 140, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, -40), ZIndex = 1 })
	local f = WoodKit.Parchment(page, { Size = UDim2.fromOffset(640, 380), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), ZIndex = 2 })
	WoodKit.Ink(f, { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 22), Text = "🎁 แลกโค้ดรับของรางวัล", TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	WoodKit.Ink(f, { Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 70), Text = "ใส่โค้ดแล้วกด \"แลกโค้ด\" · แต่ละโค้ดใช้ได้คนละครั้ง", TextSize = 17, Font = UIKit.Fonts.Bold, TextColor3 = W.InkDim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -80, 0, 66)
	box.Position = UDim2.fromOffset(40, 110)
	box.BackgroundColor3 = rgb(32, 24, 20)
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Text = ""
	box.PlaceholderText = "พิมพ์โค้ดที่นี่..."
	box.PlaceholderColor3 = rgb(150, 134, 116)
	box.TextColor3 = rgb(255, 244, 224)
	box.Font = UIKit.Fonts.Title
	box.TextSize = 30
	box.ZIndex = 3
	box.Parent = f
	WoodKit.Corner(box, 8)
	WoodKit.Stroke(box, W.GoldDark, 3, 0)
	local result = WoodKit.Ink(f, { Size = UDim2.new(1, -40, 0, 28), Position = UDim2.fromOffset(20, 272), Text = "", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	local busy = false
	local function redeem()
		local code = box.Text
		if busy or code:gsub("%s", "") == "" then
			return
		end
		busy = true
		result.Text = "⏳ กำลังตรวจสอบ..."
		result.TextColor3 = W.InkDim
		task.spawn(function()
			local ok, res = pcall(function()
				return Remotes.Get("RedeemCode"):InvokeServer(code)
			end)
			busy = false
			if ok and type(res) == "table" then
				result.Text = tostring(res.Text or "")
				result.TextColor3 = res.Ok and W.Good or W.Bad
				if res.Ok then
					box.Text = ""
				end
			else
				result.Text = "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ลองใหม่อีกครั้ง"
				result.TextColor3 = W.Bad
			end
		end)
	end
	WoodKit.Button(f, "Red", { Size = UDim2.fromOffset(300, 60), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 196), Text = "🐾 แลกโค้ด", TextSize = 26, ZIndex = 4 }, redeem)
	box.FocusLost:Connect(function(enter)
		if enter then
			redeem()
		end
	end)
	ui.CodesUsed = WoodKit.Ink(f, { Size = UDim2.new(1, -40, 0, 22), Position = UDim2.new(0, 20, 1, -40), Text = "", TextSize = 16, Font = UIKit.Fonts.Bold, TextColor3 = W.InkDim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	UIKit.Text(page, {
		Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 408), TextSize = 16, TextColor3 = rgb(226, 206, 176), TextXAlignment = Enum.TextXAlignment.Center,
		Text = "ติดตามโค้ดใหม่ๆ ได้จากหน้าเกมและกลุ่มของเกม · ลองโค้ด WELCOME ดูสิ!",
	})
end

local function refreshStatic()
	if ui.CodesUsed then
		local n = 0
		for _ in pairs((profile and profile.CodesUsed) or {}) do
			n += 1
		end
		ui.CodesUsed.Text = n > 0 and string.format("ใช้โค้ดไปแล้ว %d โค้ด", n) or ""
	end
end

local function updateTimers()
	local t = now()
	if ui.Timers.Daily and ui.Timers.Daily.Parent then
		ui.Timers.Daily.Text = "⏳ รีเซ็ตใน " .. Quests.FormatTime(Quests.SecondsToDayReset(t))
	end
	if ui.Timers.Weekly and ui.Timers.Weekly.Parent then
		ui.Timers.Weekly.Text = "⏳ รีเซ็ตใน " .. Quests.FormatTime(Quests.SecondsToWeekReset(t))
	end
	if ui.Timers.Season and ui.Timers.Season.Parent then
		ui.Timers.Season.Text = "⏳ จบซีซั่นใน " .. Quests.FormatTime(Quests.SecondsToSeasonEnd(t))
	end
	if ui.LoginButton and ui.LoginButton.Parent then
		ui.LoginButton.Text = "✔ รับแล้ว — มาใหม่ใน " .. Quests.FormatTime(Quests.SecondsToDayReset(t))
	end
end

---------------------------------------------------------------- เปิด/ปิด/รีเฟรช
local BUILDERS = { Quests = buildQuests, Login = buildLogin, Season = buildSeason }

function QuestUI.Refresh()
	if not ui.Panel then
		return
	end
	updateDots()
	refreshStatic()
	if not ui.Panel.Visible then
		return
	end
	ui.Gems.Text = tostring(player:GetAttribute("Diamonds") or (profile and profile.Diamonds) or 0)
	for id, b in pairs(ui.TabButtons) do
		local on = id == ui.Tab
		WoodKit.SetTab(b, on)
		ui.Pages[id].Visible = on
	end
	local build = BUILDERS[ui.Tab]
	if build then
		local ok, err = pcall(build, ui.Pages[ui.Tab])
		if not ok then
			warn("[AS] QuestUI", ui.Tab, err)
		end
	end
	updateTimers()
end

function QuestUI.Open(tab)
	if not ui.Panel or player:GetAttribute("InRun") then
		return
	end
	if tab and ui.Pages[tab] then
		ui.Tab = tab
	end
	ui.Panel.Visible = true
	UIKit.Pop(ui.Panel)
	QuestUI.Refresh()
end

function QuestUI.Close()
	if ui.Panel then
		ui.Panel.Visible = false
	end
end

function QuestUI.IsOpen()
	return ui.Panel ~= nil and ui.Panel.Visible
end

function QuestUI.Toggle()
	if QuestUI.IsOpen() then
		QuestUI.Close()
	else
		QuestUI.Open()
	end
end

function QuestUI.SetProfile(p)
	if type(p) ~= "table" then
		return
	end
	profile = p
	QuestUI.Refresh()
end

-- หลังโหลดเสร็จ: ดึงโปรไฟล์ แล้วเด้งหน้าล็อกอิน 7 วันถ้าวันนี้ยังไม่ได้รับ (รอหน้าสอนเล่นปิดก่อน)
function QuestUI.OnLoaded()
	task.spawn(function()
		if not profile then
			local ok, p = pcall(function()
				return Remotes.Get("GetProfile"):InvokeServer()
			end)
			if ok and type(p) == "table" then
				QuestUI.SetProfile(p)
			end
		end
		if loginShown then
			return
		end
		task.wait(2.5)
		local t0 = os.clock()
		while Tutorial.IsOpen() and os.clock() - t0 < 600 do
			task.wait(0.5)
		end
		task.wait(0.6)
		if profile and not loginState().Claimed and not player:GetAttribute("InRun") and not QuestUI.IsOpen() then
			loginShown = true
			QuestUI.Open("Login")
		end
	end)
end

function QuestUI.Init(gui)
	local win = WoodKit.Window(gui, { Name = "QuestWindow", Size = Vector2.new(1080, 620), Title = "ภารกิจ & รางวัล", Shrink = false, OnClose = QuestUI.Close })
	ui.Panel = win.Frame
	local body = win.Body
	-- Ruby ของเรา
	ui.Gems = WoodKit.RubyPill(body, { Position = UDim2.new(1, -206, 0, 42) })
	-- แท็บ
	local tabs = UIKit.Frame(body, { Size = UDim2.new(1, -260, 0, 52), Position = UDim2.fromOffset(32, 40), BackgroundTransparency = 1 })
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.VerticalAlignment = Enum.VerticalAlignment.Center
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Padding = UDim.new(0, 10)
	tl.Parent = tabs
	local content = UIKit.Frame(body, { BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 104), Size = UDim2.new(1, -64, 1, -126) })
	for i, t in ipairs(TABS) do
		local b = WoodKit.Tab(tabs, t.Text, i, 180, function()
			ui.Tab = t.Id
			QuestUI.Refresh()
		end)
		ui.TabButtons[t.Id] = b
		ui.TabDots[t.Id] = dotOn(b)
		local page = UIKit.Frame(content, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
		ui.Pages[t.Id] = page
	end
	buildCodes(ui.Pages.Codes)

	LobbyUI.OnQuests = QuestUI.Toggle
	LobbyUI.Closers.Quests = QuestUI.Close
	LobbyUI.OnHidden = QuestUI.Close
	Remotes.Get("Profile").OnClientEvent:Connect(QuestUI.SetProfile)
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		if player:GetAttribute("InRun") then
			QuestUI.Close()
		end
	end)
	player:GetAttributeChangedSignal("Pass_" .. Quests.SeasonPassKey):Connect(QuestUI.Refresh)
	player:GetAttributeChangedSignal("Diamonds"):Connect(function()
		if QuestUI.IsOpen() then
			ui.Gems.Text = tostring(player:GetAttribute("Diamonds") or 0)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			QuestUI.Close()
		end
	end)
	-- นาฬิกานับถอยหลัง + เช็กจุดแดงตอนข้ามวัน
	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(1)
			ticks += 1
			if QuestUI.IsOpen() then
				updateTimers()
			end
			if ticks % 10 == 0 then
				updateDots()
			end
		end
	end)
	updateDots()
	refreshStatic()
end

return QuestUI
