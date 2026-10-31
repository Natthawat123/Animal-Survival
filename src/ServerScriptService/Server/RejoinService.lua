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
	  ทุกคนออกเกมหมด (เล่นคนเดียวแล้วหลุด ฯลฯ) -> เซิร์ฟเวอร์ปิดแน่ ๆ:
	    · ไม่นับว่าแพ้ เก็บทั้งรอบลง MemoryStore run_<PrivateServerId> (seed, คืนที่, กองไฟ/โต๊ะ/เชื้อเพลิง, คลังแคมป์,
	      สิ่งก่อสร้าง, สัตว์วิญญาณ/รังบอส, สถานะผู้เล่นแต่ละคน)
	    · กดกลับเข้ารอบ -> รหัสเดิมเปิดเซิร์ฟเวอร์ใหม่ (PrivateServerId เดิม) -> Main อ่าน seed เดิม (แมพเดียวกัน)
	      -> คนแรกมาถึงคืนรอบ (เริ่มกลางวันของคืนที่ค้างไว้) แล้วคืนของให้แต่ละคน
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

local function isTeamServerId()
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

-- Main เรียกก่อนสุ่ม seed: เซิร์ฟเวอร์ทีมที่เปิดใหม่จากรอบที่ทุกคนหลุดออกไป -> ข้อมูลรอบเดิม (nil = เริ่มใหม่)
function RejoinService.LoadHeldRun()
	if RunService:IsStudio() or game.PlaceId == 0 or not isTeamServerId() then
		return nil
	end
	for _ = 1, 3 do
		local ok, v = pcall(function()
			return MemoryStoreService:GetSortedMap(MAP_NAME):GetAsync("run_" .. game.PrivateServerId)
		end)
		if ok then
			if type(v) == "table" and type(v.Seed) == "number" and (v.Expire or 0) > os.time() then
				return v
			end
			return nil
		end
		task.wait(1)
	end
	return nil
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
	local auras = {}
	for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		if player:GetAttribute("Aura_" .. el) then
			table.insert(auras, el)
		end
	end
	return {
		Bag = bag,
		Auras = auras,
		Class = player:GetAttribute("Class"),
		Armor = player:GetAttribute("Armor"),
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
	-- ไม่เหลือใครในรอบแล้ว -> เซิร์ฟเวอร์จะปิด: เก็บทั้งรอบไว้ให้กลับมาเล่นต่อ
	local others = false
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p:GetAttribute("InRun") then
			others = true
		end
	end
	if not others then
		self:HoldRun()
	end
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

-- ทั้งรอบ -> ตาราง (MemoryStore เก็บได้ ≤ 32KB)
function RejoinService:SerializeRun()
	local S = self.ctx.Services
	local players = {}
	for uid, snap in pairs(self.saved) do
		players[tostring(uid)] = snap
	end
	return {
		Seed = self.ctx.Seed,
		Night = S.DirectorService.night,
		PendingSkips = S.DirectorService.pendingSkips,
		Carry = S.DirectorService.carry,
		Conquered = self.ctx.State:GetAttribute("Conquered") == true,
		Camp = { S.CampService.level, S.CampService.bench, math.floor(S.CampService.fuel) },
		Stock = table.clone(S.InventoryService.Camp),
		Structures = S.BuildingService:Serialize(),
		Spirit = S.SpiritService:Serialize(),
		Sanctums = S.SanctumService:Serialize(),
		Players = players,
		Expire = os.time() + self.TTL,
	}
end

function RejoinService:WriteRun()
	if not self.held then
		return
	end
	local ok, run = pcall(self.SerializeRun, self)
	if not ok then
		warn("[AS] rejoin serialize:", run)
		return
	end
	self:MSet("run_" .. game.PrivateServerId, run, self.TTL)
end

-- คนสุดท้ายออกจากรอบ (ไม่ได้ตาย): เก็บรอบไว้ แทนการจบรอบ (เซิร์ฟเวอร์ทีมที่มี MemoryStore เท่านั้น)
function RejoinService:HoldRun()
	if self.held or not (isTeamServer(self) and self.map and runActive(self)) then
		return
	end
	self.held = true
	task.spawn(self.WriteRun, self)
end

-- ล้างทุกอย่าง (รอบจบ / เซิร์ฟเวอร์กำลังปิด)
function RejoinService:ClearAll()
	local ids = {}
	for uid in pairs(self.saved) do
		table.insert(ids, uid)
	end
	table.clear(self.saved)
	self.held = false
	if isTeamServer(self) and self.map then
		for _, uid in ipairs(ids) do
			task.spawn(self.MRemove, self, "u_" .. uid)
		end
		task.spawn(self.MRemove, self, "run_" .. game.PrivateServerId)
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
	self.held = false
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
	if type(snap.Armor) == "string" and Items.Data[snap.Armor] then
		player:SetAttribute("Armor", snap.Armor) -- ใส่เกราะ/เลือดเพิ่มตอนเกิด (OnCharacter)
	end
	for _, el in ipairs(type(snap.Auras) == "table" and snap.Auras or {}) do
		player:SetAttribute("Aura_" .. el, true) -- ออร่าวิหาร: ใส่เอฟเฟกต์/เลือดเพิ่มตอนเกิด (OnCharacter)
	end
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
-- เซิร์ฟเวอร์ใหม่ของรอบที่เก็บไว้: คืนโลก (ครั้งเดียว) แล้วเริ่มนับคืนต่อจากเดิม
function RejoinService:ApplyResume()
	local run = self.ctx.Resume
	if self.resumed or type(run) ~= "table" then
		return
	end
	self.resumed = true
	local S = self.ctx.Services
	local steps = {
		function()
			S.CampService:Restore(run.Camp and run.Camp[1], run.Camp and run.Camp[2], run.Camp and run.Camp[3])
		end,
		function()
			S.InventoryService:SetCamp(run.Stock)
			S.CampService:UpdateStockSign()
		end,
		function()
			S.BuildingService:Restore(run.Structures)
		end,
		function()
			S.SpiritService:Restore(run.Spirit)
		end,
		function()
			S.SanctumService:Restore(run.Sanctums)
		end,
	}
	for _, fn in ipairs(steps) do
		local ok, err = pcall(fn)
		if not ok then
			warn("[AS] resume:", err)
		end
	end
	self.ctx.State:SetAttribute("Conquered", run.Conquered == true)
	S.DirectorService:StartRun(run.Night, run.PendingSkips, run.Carry)
	for uid, snap in pairs(type(run.Players) == "table" and run.Players or {}) do
		if type(snap) == "table" and type(snap.Bag) == "table" then
			snap.Expire = os.time() + self.TTL
			self.saved[tonumber(uid)] = snap
		end
	end
	task.spawn(self.MRemove, self, "run_" .. game.PrivateServerId)
	print(string.format("[AS] resumed held run: night %s, %d structures", tostring(run.Night), #(run.Structures or {})))
end

function RejoinService:OnTeamArrive(player)
	if self.ctx.Resume and not self.resumed then
		self:ApplyResume()
	end
	if self.saved[player.UserId] then
		-- รอโหลดเซฟ (คลาส) ให้เสร็จก่อนคืนสถานะ
		local t0 = os.clock()
		while player.Parent and not self.ctx.Services.DataService:Get(player) and os.clock() - t0 < 20 do
			task.wait(0.25)
		end
	end
	if self:TryRestore(player) then
		return true
	end
	local ok, join = pcall(function()
		return player:GetJoinData()
	end)
	local td = ok and type(join) == "table" and join.TeleportData
	if type(td) == "table" and td.Rejoin and not runActive(self) then
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
		if self.held then
			self:WriteRun()
			return
		end
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
