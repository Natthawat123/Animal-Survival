--[[
	FriendService — โบนัสเล่นกับเพื่อน
	  · มีเพื่อน Roblox อยู่ในรอบเดียวกัน (ทั้งคู่อยู่ในแมพ เซิร์ฟเวอร์เดียวกัน) = Ruby ที่ได้ระหว่างรอบ +10%
	    (DataService:AddDiamonds เรียก Extra) · เศษทศนิยมสะสมไว้ ไม่ปัดทิ้ง
	  · เช็กเพื่อนด้วย player:IsFriendsWith (pcall + จำผลไว้) · player attribute "FriendsHere" = จำนวนเพื่อนในเซิร์ฟเวอร์
	  · ปุ่มชวนเพื่อน (SocialService:PromptGameInvite) อยู่ฝั่ง client (QuestUI)
]]

local Players = game:GetService("Players")

local FriendService = {}

FriendService.BonusRate = 0.10

local cache = {} -- cache[userIdA][userIdB] = true/false
local carry = {} -- [player] = เศษโบนัสที่ยังไม่ครบ 1 Ruby

function FriendService:Init(ctx)
	self.ctx = ctx
end

local function known(a, b)
	local row = cache[a.UserId]
	return row and row[b.UserId]
end

function FriendService:IsFriend(a, b)
	return a ~= b and known(a, b) == true
end

local function countHere(player)
	local n = 0
	for _, q in ipairs(Players:GetPlayers()) do
		if FriendService:IsFriend(player, q) then
			n += 1
		end
	end
	player:SetAttribute("FriendsHere", n)
end

local function check(a, b)
	if a == b or a.UserId <= 0 or b.UserId <= 0 or known(a, b) ~= nil then
		return
	end
	local ok, res = pcall(a.IsFriendsWith, a, b.UserId)
	if not ok then
		return -- ลองใหม่รอบหน้า (ตอนมีคนเข้า/ออก)
	end
	cache[a.UserId] = cache[a.UserId] or {}
	cache[b.UserId] = cache[b.UserId] or {}
	cache[a.UserId][b.UserId] = res == true
	cache[b.UserId][a.UserId] = res == true
	if a.Parent then
		countHere(a)
	end
	if b.Parent then
		countHere(b)
	end
end

-- จำนวนเพื่อนที่อยู่ในแมพรอบเดียวกันตอนนี้
function FriendService:FriendsInRun(player)
	if not player:GetAttribute("InRun") then
		return 0
	end
	local n = 0
	for _, q in ipairs(Players:GetPlayers()) do
		if q:GetAttribute("InRun") and self:IsFriend(player, q) then
			n += 1
		end
	end
	return n
end

function FriendService:Bonus(player)
	return self:FriendsInRun(player) > 0
end

-- Ruby โบนัสที่ต้องบวกเพิ่มจาก n (0 ถ้าไม่มีเพื่อนในรอบ)
function FriendService:Extra(player, n)
	if n <= 0 or not self:Bonus(player) then
		return 0
	end
	local v = n * self.BonusRate + (carry[player] or 0)
	local whole = math.floor(v)
	carry[player] = v - whole
	return whole
end

function FriendService:Start()
	local function onPlayer(p)
		p:SetAttribute("FriendsHere", 0)
		for _, q in ipairs(Players:GetPlayers()) do
			if q ~= p then
				task.spawn(check, p, q)
			end
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		carry[p] = nil
		cache[p.UserId] = nil
		for _, row in pairs(cache) do
			row[p.UserId] = nil
		end
		for _, q in ipairs(Players:GetPlayers()) do
			if q ~= p then
				countHere(q)
			end
		end
	end)
end

return FriendService
