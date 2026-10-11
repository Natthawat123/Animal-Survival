--[[
	RejoinService — หลุด/ออกเกมกลางรอบ กลับเข้ารอบเดิมได้ภายใน 1 ชั่วโมง
	  เซิร์ฟเวอร์ของรอบ (ปกติ = เซิร์ฟเวอร์ของทีม):
	    · คนในรอบออกเกม (ยังไม่ตาย / รอบยังไม่จบ) -> เก็บสถานะไว้ในเซิร์ฟเวอร์นี้ 1 ชม.
	      (ของในกระสอบ + เครื่องมือ, เครื่องมือที่ถือ, คลาส, เลือด, ความหิว, ล้มอยู่ไหม)
	    · บันทึกลง MemoryStore: u_<UserId> = { PlaceId, Code (รหัสเซิร์ฟเวอร์ส่วนตัว), ServerId, Expire }
	    · กลับมาถึง -> คืนสถานะเดิมแทนการเริ่มใหม่ · รอบจบ/เซิร์ฟเวอร์ปิด -> ล้างทั้งหมด
	  ล็อบบี้หลัก:
	    · เข้าเกมแล้วมีบันทึก -> ถาม "กลับเข้ารอบเดิม?" (บอกเวลาที่เหลือ) -> ตกลง = เทเลพอร์ตกลับเซิร์ฟเวอร์เดิม
	  รหัสเซิร์ฟเวอร์ส่วนตัว: ล็อบบี้เก็บไว้ตอนจอง (RegisterServer) เซิร์ฟเวอร์ของทีมอ่านด้วย PrivateServerId ของตัวเอง
	  Studio / ไม่มี MemoryStore: ไม่เทเลพอร์ต แต่ยังกลับเข้ารอบในเซิร์ฟเวอร์เดียวกันได้ (ไม่ error)
]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Items = require(game:GetService("ReplicatedStorage").Shared.Items)

local RejoinService = {}
RejoinService.TTL = 3600
local SERVER_TTL = 86400
local MAP_NAME = "ASRejoin_v1"

function RejoinService:Init(ctx)
	self.ctx = ctx
	self.saved = {} -- [userId] = snapshot
	self.offers = {} -- [player] = { Local = bool, Record = table }
	self.lastAnswer = {}
	self.enabled = not RunService:IsStudio() and game.PlaceId ~= 0
	if self.enabled then
		local ok, map = pcall(function()
			return MemoryStoreService:GetSortedMap(MAP_NAME)
		end)
		self.map = ok and map or nil
	end
end

---------------------------------------------------------------- MemoryStore (ทุกคำสั่งห่อ pcall)
function RejoinService:MGet(key)
	if not self.map then
		return nil
	end
	local ok, v = pcall(function()
		return self.map:GetAsync(key)
	end)
	return ok and v or nil
end

function RejoinService:MSet(key, value, ttl)
	if not self.map then
		return false
	end
	local ok, err = pcall(function()
		self.map:SetAsync(key, value, ttl)
	end)
	if not ok then
		warn("[AS] rejoin memorystore set:", err)
	end
	return ok
end

function RejoinService:MRemove(key)
	if not self.map then
		return
	end
	pcall(function()
		self.map:RemoveAsync(key)
	end)
end

local function isTeamServer(self)
	local lobby = self.ctx.Services.LobbyService
	return lobby ~= nil and lobby.IsTeamServer == true
end

-- ล็อบบี้: จองเซิร์ฟเวอร์ของทีมแล้ว เก็บรหัสไว้ให้เซิร์ฟเวอร์นั้นอ่าน (ใช้ส่งคนกลับเข้ามา)
function RejoinService:RegisterServer(privateServerId, code)
	if not (self.map and type(privateServerId) == "string" and privateServerId ~= "" and type(code) == "string") then
		return
	end
	task.spawn(function()
		self:MSet("ps_" .. privateServerId, code, SERVER_TTL)
	end)
end

-- เซิร์ฟเวอร์ของทีม: รหัสของตัวเอง (อ่านครั้งเดียวแล้วจำไว้)
function RejoinService:ServerCode()
	if self.code then
		return self.code
	end
	if not (self.map and game.PrivateServerId ~= "") then
		return nil
	end
	local v = self:MGet("ps_" .. game.PrivateServerId)
	if type(v) == "string" then
		self.code = v
	end
	return self.code
end

---------------------------------------------------------------- เก็บ / คืนสถานะ
local function runActive(self)
	local director = self.ctx.Services.DirectorService
	return director ~= nil and director:IsRunning() and self.ctx.State:GetAttribute("Phase") ~= "Ended"
end

function RejoinService:Snapshot(player)
	local inv = self.ctx.Services.InventoryService
	local bag = {}
	for id, n in pairs(inv:Get(player)) do
		if type(n) == "number" and n > 0 and Items.Data[id] then
			bag[id] = n
		end
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local tool = char and char:FindFirstChildOfClass("Tool")
	return {
		Bag = bag,
		Class = player:GetAttribute("Class"),
		Health = hum and hum.Health or nil,
		Hunger = player:GetAttribute("Hunger"),
		Downed = player:GetAttribute("Downed") == true,
		Equipped = tool and tool:GetAttribute("ItemId") or nil,
		Expire = os.time() + self.TTL,
	}
end

function RejoinService:OnRemoving(player)
	local uid = player.UserId
	-- ออกจากรอบตามปกติ (ตาย/รอบจบ/กลับล็อบบี้) ไม่ต้องเก็บ
	if not player:GetAttribute("InRun") or player:GetAttribute("Dead") or not runActive(self) then
		return
	end
	local ok, snap = pcall(self.Snapshot, self, player)
	if not ok or not snap then
		return
	end
	self.saved[uid] = snap
	if isTeamServer(self) and self.map then
		task.spawn(function()
			local code = self:ServerCode()
			if not code then
				return
			end
			self:MSet("u_" .. uid, { PlaceId = game.PlaceId, Code = code, ServerId = game.PrivateServerId, Expire = snap.Expire }, self.TTL)
			-- ระหว่างรอเขียน รอบอาจจบ/ถูกคืนสถานะไปแล้ว -> ลบทิ้ง
			if self.saved[uid] ~= snap then
				self:MRemove("u_" .. uid)
			end
		end)
	end
end

-- ล้างทุกอย่าง (รอบจบ / เซิร์ฟเวอร์กำลังปิด)
function RejoinService:ClearAll()
	local ids = {}
	for uid in pairs(self.saved) do
		table.insert(ids, uid)
	end
	table.clear(self.saved)
	if isTeamServer(self) and self.map then
		for _, uid in ipairs(ids) do
			task.spawn(self.MRemove, self, "u_" .. uid)
		end
	end
end

-- คืนสถานะที่เก็บไว้ -> true ถ้าคืนได้
function RejoinService:TryRestore(player)
	local uid = player.UserId
	local snap = self.saved[uid]
	if not snap then
		return false
	end
	if snap.Expire < os.time() or not runActive(self) or player:GetAttribute("InRun") then
		self.saved[uid] = nil
		return false
	end
	self.saved[uid] = nil
	if isTeamServer(self) then
		task.spawn(self.MRemove, self, "u_" .. uid)
	end
	local ctx = self.ctx
	local surv = ctx.Services.SurvivalService
	local inv = ctx.Services.InventoryService
	player:SetAttribute("InRun", true)
	player:SetAttribute("StartItemsGiven", true)
	-- คลาสเดิม (ถ้ายังเป็นเจ้าของ)
	local data = ctx.Services.DataService:Get(player)
	local cls = snap.Class
	if data and cls and data.Owned and data.Owned[cls] then
		data.Class = cls
		player:SetAttribute("Class", cls)
		player:SetAttribute("ClassLevel", (data.ClassLevel and data.ClassLevel[cls]) or 1)
	end
	surv:OnClassChosen(player, player:GetAttribute("Class") or "Survivor")
	for id, n in pairs(snap.Bag) do
		inv:Add(player, id, n, true)
	end
	ctx.Remotes.Get("Cinematic"):FireClient(player, "Depart", {})
	-- เกิดใหม่ที่แคมป์/เตียง แล้วใส่เลือด/ความหิว/ของในมือ/สถานะล้มกลับ (หลัง OnCharacter ตั้งค่าเริ่มต้นเสร็จ)
	local conn
	conn = player.CharacterAdded:Connect(function(char)
		conn:Disconnect()
		task.delay(2, function()
			if not (player.Parent and char.Parent) then
				return
			end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and type(snap.Health) == "number" and snap.Health == snap.Health then
				hum.Health = math.clamp(snap.Health, 1, hum.MaxHealth)
			end
			if type(snap.Hunger) == "number" then
				player:SetAttribute("Hunger", snap.Hunger)
			end
			if hum and snap.Equipped then
				local backpack = player:FindFirstChild("Backpack")
				for _, t in ipairs(backpack and backpack:GetChildren() or {}) do
					if t:IsA("Tool") and t:GetAttribute("ItemId") == snap.Equipped then
						hum:EquipTool(t)
						break
					end
				end
			end
			if snap.Downed then
				surv:Down(player, "Rejoin")
			end
		end)
	end)
	surv:Spawn(player)
	ctx.Notify(player, "↩ กลับเข้ารอบเดิมแล้ว — ของในกระสอบ/เครื่องมือยังอยู่ครบ", "Good")
	ctx.Broadcast(string.format("↩ %s กลับเข้ามาในรอบแล้ว", player.DisplayName), "Info")
	return true
end

-- เซิร์ฟเวอร์ของทีม: คนมาถึง -> คืนสถานะเดิม (true) หรือให้ LobbyService ลงแมพตามปกติ (false)
function RejoinService:OnTeamArrive(player)
	if self:TryRestore(player) then
		return true
	end
	local ok, join = pcall(function()
		return player:GetJoinData()
	end)
	local td = ok and type(join) == "table" and join.TeleportData
	if type(td) == "table" and td.Rejoin then
		-- ตั้งใจกลับเข้ารอบเดิม แต่ไม่มีสถานะแล้ว (รอบจบ/เซิร์ฟเวอร์เดิมปิดไปแล้ว) -> ล้างบันทึก แล้วส่งกลับล็อบบี้หลัก
		task.spawn(self.MRemove, self, "u_" .. player.UserId)
		local lobby = self.ctx.Services.LobbyService
		if lobby and lobby:ReturnToMainLobby({ player }, { Result = "RunGone" }) then
			return true
		end
		self.ctx.Notify(player, "รอบเดิมจบไปแล้ว — เริ่มรอบใหม่แทน", "Info")
	end
	return false
end

---------------------------------------------------------------- ล็อบบี้: ถาม "กลับเข้ารอบเดิม?"
function RejoinService:CheckOffer(player)
	if not player.Parent or player:GetAttribute("InRun") then
		return
	end
	local uid = player.UserId
	local now = os.time()
	local snap = self.saved[uid]
	if snap and snap.Expire > now and runActive(self) then
		-- รอบยังเล่นอยู่ในเซิร์ฟเวอร์นี้ (Studio / เล่นในเซิร์ฟเวอร์ล็อบบี้)
		self.offers[player] = { Local = true }
		self.ctx.Remotes.Get("RejoinOffer"):FireClient(player, { Left = snap.Expire - now, Local = true })
		return
	end
	if isTeamServer(self) or not self.map then
		return
	end
	local rec = self:MGet("u_" .. uid)
	if type(rec) ~= "table" or type(rec.Code) ~= "string" or type(rec.Expire) ~= "number" then
		return
	end
	if rec.Expire <= os.time() or (rec.PlaceId and rec.PlaceId ~= game.PlaceId) then
		self:MRemove("u_" .. uid)
		return
	end
	if not player.Parent or player:GetAttribute("InRun") then
		return
	end
	self.offers[player] = { Local = false, Record = rec }
	self.ctx.Remotes.Get("RejoinOffer"):FireClient(player, { Left = rec.Expire - os.time(), Local = false })
end

function RejoinService:Answer(player, accept)
	local offer = self.offers[player]
	if not offer then
		return
	end
	local now = os.clock()
	if (self.lastAnswer[player] or 0) > now - 2 then
		return
	end
	self.lastAnswer[player] = now
	local uid = player.UserId
	if accept ~= true then
		self.offers[player] = nil
		self.saved[uid] = nil
		if not offer.Local then
			task.spawn(self.MRemove, self, "u_" .. uid)
		end
		return
	end
	if player:GetAttribute("InRun") then
		self.offers[player] = nil
		return
	end
	if offer.Local then
		self.offers[player] = nil
		if not self:TryRestore(player) then
			self.ctx.Notify(player, "รอบเดิมจบไปแล้ว", "Error")
		end
		return
	end
	local rec = offer.Record
	if not (rec and rec.Expire > os.time()) then
		self.offers[player] = nil
		self.ctx.Notify(player, "หมดเวลากลับเข้ารอบเดิมแล้ว", "Error")
		task.spawn(self.MRemove, self, "u_" .. uid)
		return
	end
	self.ctx.Services.DataService:Save(player)
	self.ctx.Remotes.Get("Cinematic"):FireClient(player, "Teleporting", {})
	local ok, err = pcall(function()
		local opts = Instance.new("TeleportOptions")
		opts.ReservedServerAccessCode = rec.Code
		opts:SetTeleportData({ Rejoin = true })
		TeleportService:TeleportAsync(game.PlaceId, { player }, opts)
	end)
	if not ok then
		warn("[AS] rejoin teleport failed:", err)
		self.ctx.Notify(player, "กลับเข้ารอบเดิมไม่สำเร็จ ลองใหม่อีกครั้ง", "Error")
		-- ให้กดใหม่ได้
		self.ctx.Remotes.Get("RejoinOffer"):FireClient(player, { Left = rec.Expire - os.time(), Local = false })
	end
end

function RejoinService:Start(ctx)
	Players.PlayerRemoving:Connect(function(p)
		self.offers[p] = nil
		self.lastAnswer[p] = nil
		self:OnRemoving(p)
	end)
	ctx.Remotes.Get("RejoinAnswer").OnServerEvent:Connect(function(player, accept)
		self:Answer(player, accept)
	end)
	-- เทเลพอร์ตล้มเหลว (เซิร์ฟเวอร์เต็ม/ปิด ฯลฯ) -> แจ้งผู้เล่น
	pcall(function()
		TeleportService.TeleportInitFailed:Connect(function(player, _, msg)
			if self.offers[player] and not self.offers[player].Local then
				ctx.Notify(player, "กลับเข้ารอบเดิมไม่สำเร็จ: " .. tostring(msg or ""), "Error")
				local rec = self.offers[player].Record
				if rec and rec.Expire > os.time() then
					ctx.Remotes.Get("RejoinOffer"):FireClient(player, { Left = rec.Expire - os.time(), Local = false })
				end
			end
		end)
	end)
	-- รอบจบ -> ไม่มีรอบให้กลับแล้ว
	ctx.State:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = ctx.State:GetAttribute("Phase")
		if phase == "Ended" or phase == "Lobby" then
			self:ClearAll()
		end
	end)
	game:BindToClose(function()
		if next(self.saved) then
			local ids = {}
			for uid in pairs(self.saved) do
				table.insert(ids, uid)
			end
			table.clear(self.saved)
			if isTeamServer(self) then
				for _, uid in ipairs(ids) do
					self:MRemove("u_" .. uid)
				end
			end
		end
	end)
	-- ล็อบบี้หลัก: คนเข้ามา -> เช็กว่ามีรอบค้างไหม
	local function onPlayer(player)
		local ok, join = pcall(function()
			return player:GetJoinData()
		end)
		local td = ok and type(join) == "table" and join.TeleportData
		local runGone = type(td) == "table" and td.Back and td.Result == "RunGone"
		task.delay(6, function()
			if not player.Parent then
				return
			end
			if runGone then
				ctx.Notify(player, "รอบเดิมจบไปแล้ว — เริ่มรอบใหม่ได้ที่แท่นเริ่มเกม", "Info")
				return
			end
			if not isTeamServer(self) then
				self:CheckOffer(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayer, p)
	end
	-- สถานะหมดอายุ
	task.spawn(function()
		while true do
			task.wait(60)
			local now = os.time()
			for uid, snap in pairs(self.saved) do
				if snap.Expire < now then
					self.saved[uid] = nil
				end
			end
		end
	end)
end

return RejoinService
