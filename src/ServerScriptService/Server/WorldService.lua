--[[
	WorldService — โหมด "สร้างโลก" (จ่ายต่อ 1 โลก: Developer Product Config.WorldProductId)
	  เมนู Worlds: เห็นห้องโลกทุกห้องในเซิร์ฟเวอร์นี้ · กด "+" = ซื้อ 1 ครั้ง ได้โลกใหม่ 1 โลก (สร้างอีกก็ซื้ออีก)
	    ตั้งรหัสผ่าน/จำนวนคนตอนสร้าง · โลกที่สร้างไว้เก็บได้ Config.WorldMaxSlots โลก (DataService data.Worlds) เปิดเล่นต่อเมื่อไรก็ได้
	    เข้าห้องคนอื่นได้เมื่อ คืนของโลก <= คืนที่ตัวเองเคยรอดไกลสุด + Config.WorldNightGate (ยังไม่เคยเล่น = ถึงคืน 20)
	    หัวห้องออกจากห้อง/ออกเกม = ปิดห้อง ทุกคนเด้งออก · หัวห้องกดเริ่ม = ไปเซิร์ฟเวอร์ของทีม (LobbyService:DepartTeam)
	  ในโลก (State.WorldOwner/WorldId): เซฟโลกทุกเช้า (RejoinService:SaveRunFor -> DataService:SaveWorld)
	    เจ้าของออกเกม = เซฟแล้วส่งทุกคนกลับล็อบบี้ · ทีมตายหมด (ไม่ชุบ) = โลกหาย (DataService:DeleteWorld)
	  ห้องโชว์ใน ReplicatedStorage.Worlds (Configuration ต่อห้อง: HostId/HostName/WorldName/Night/Count/Size/Locked/Members/New)
	  remote WorldAction(action, a, b, c): "Create"(password, size) / "Open"(worldId, password, size) / "Delete"(worldId)
	    / "Join"(hostId, password) / "Leave" / "Start"
]]

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldService = {}

function WorldService:Init(ctx)
	self.ctx = ctx
	self.rooms = {} -- [host] = { Host, Password, Night, Size, Members = { player... }, New, Inst }
	self.roomOf = {} -- [player] = room
	self.pending = {} -- [player] = { Password, Size } ค่าที่ตั้งไว้ระหว่างรอซื้อสร้างโลก
	local f = Instance.new("Folder")
	f.Name = "Worlds"
	f.Parent = ReplicatedStorage
	self.folder = f
end

local function notify(self, p, text, kind)
	self.ctx.Notify(p, text, kind or "Info")
end

-- คืนที่เข้าห้องได้สูงสุดของคนนี้
function WorldService:MaxNight(player)
	local data = self.ctx.Services.DataService:Get(player)
	return math.floor(tonumber(data and data.BestNight) or 0) + (Config.WorldNightGate or 20)
end

function WorldService:Publish(room)
	local inst = room.Inst
	if not inst then
		inst = Instance.new("Configuration")
		inst.Name = tostring(room.Host.UserId)
		inst.Parent = self.folder
		room.Inst = inst
	end
	local ids = {}
	for _, m in ipairs(room.Members) do
		table.insert(ids, tostring(m.UserId))
	end
	inst:SetAttribute("HostId", room.Host.UserId)
	inst:SetAttribute("HostName", room.Host.DisplayName)
	inst:SetAttribute("WorldName", room.WorldName)
	inst:SetAttribute("Night", room.Night)
	inst:SetAttribute("New", room.New)
	inst:SetAttribute("Count", #room.Members)
	inst:SetAttribute("Size", room.Size)
	inst:SetAttribute("Locked", room.Password ~= "")
	inst:SetAttribute("Members", table.concat(ids, ","))
	inst:SetAttribute("Invited", table.concat(room.InviteList or {}, ","))
end

function WorldService:RemoveMember(room, p, why)
	local i = table.find(room.Members, p)
	if i then
		table.remove(room.Members, i)
	end
	self.roomOf[p] = nil
	if p.Parent then
		p:SetAttribute("WorldRoom", nil)
		if why then
			notify(self, p, why, "Info")
		end
	end
end

-- ปิดห้อง: ทุกคนเด้งออก
function WorldService:Close(room, why)
	for _, m in ipairs(table.clone(room.Members)) do
		self:RemoveMember(room, m, m ~= room.Host and why or nil)
	end
	self.rooms[room.Host] = nil
	if room.Inst then
		room.Inst:Destroy()
	end
end

function WorldService:Leave(player)
	local room = self.roomOf[player]
	if not room then
		return
	end
	if room.Host == player then
		self:Close(room, "🌍 The host closed the world room")
	else
		self:RemoveMember(room, player)
		self:Publish(room)
		notify(self, room.Host, player.DisplayName .. " left your world room")
	end
end

local function cleanPassword(pw)
	pw = type(pw) == "string" and pw or ""
	pw = pw:gsub("[%c]", ""):sub(1, 12)
	return pw
end

-- ชื่อโลก (คนอื่นเห็น) ต้องผ่านตัวกรองข้อความของ Roblox · กรองไม่ได้/ว่าง = ชื่อสำรอง
local function cleanName(player, name, fallback)
	name = type(name) == "string" and name:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 24) or ""
	if name == "" then
		return fallback
	end
	local ok, res = pcall(function()
		return TextService:FilterStringAsync(name, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	return ok and type(res) == "string" and res ~= "" and res or fallback
end

-- เปิดห้องของโลกที่สร้างไว้ (โลกใหม่ = คืน 1 · โลกที่เคยเล่น = คืนที่เซฟล่าสุด)
function WorldService:Open(player, worldId, password, size)
	local data = self.ctx.Services.DataService:Get(player)
	local w = data and type(data.Worlds) == "table" and data.Worlds[worldId]
	if not w or player:GetAttribute("InRun") or player:GetAttribute("Departing") then
		return
	end
	self:Leave(player)
	self.ctx.Services.LobbyService:LeavePad(player, true)
	local room = {
		Host = player,
		WorldId = worldId,
		WorldName = w.Name or "World",
		Password = cleanPassword(password),
		Night = w.Night or 1,
		New = w.Played ~= true,
		Size = math.clamp(math.floor(tonumber(size) or 4), 1, Config.WorldMaxSize or 8),
		Members = { player },
		Invited = {}, -- [UserId] = true คนที่หัวห้องเชิญ (เข้าได้ไม่ต้องใส่รหัส)
		InviteList = {},
	}
	self.rooms[player] = room
	self.roomOf[player] = room
	player:SetAttribute("WorldRoom", player.UserId)
	self:Publish(room)
	notify(self, player, string.format("🌍 %s is open%s — invite friends or wait for them to join", room.WorldName, room.New and "" or (" · Night " .. room.Night)), "Good")
end

-- สร้างโลกใหม่ (ใช้สิทธิ์ที่ซื้อแล้ว 1 ครั้ง) แล้วเปิดห้องทันที
function WorldService:Create(player, name, password, size)
	local ds = self.ctx.Services.DataService
	local data = ds:Get(player)
	if not data or player:GetAttribute("InRun") then
		return
	end
	data.Worlds = type(data.Worlds) == "table" and data.Worlds or {}
	local count = 0
	for _ in pairs(data.Worlds) do
		count += 1
	end
	if count >= (Config.WorldMaxSlots or 5) then
		notify(self, player, string.format("You can keep up to %d worlds — delete one first", Config.WorldMaxSlots or 5), "Error")
		return
	end
	-- ฟรี: Studio ที่ยังไม่ตั้งสินค้า / โหมด dev (DevPanel: Free Create World) -> ไม่เสีย Robux ไม่หักสิทธิ์
	local free = ((Config.WorldProductId or 0) == 0 and RunService:IsStudio())
		or (player:GetAttribute("DevFreeWorlds") == true and self.ctx.Services.DevService:IsDev(player))
	if not free then
		if (data.WorldCredits or 0) <= 0 then
			-- ยังไม่ได้ซื้อ: จำค่าที่ตั้งไว้ แล้วให้เครื่องผู้เล่นเด้งหน้าซื้อ (ซื้อเสร็จ -> OnCredit สร้างต่อเอง)
			self.pending[player] = { Name = name, Password = password, Size = size }
			if (Config.WorldProductId or 0) > 0 then
				self.ctx.Remotes.Get("Cinematic"):FireClient(player, "BuyWorld", {})
			else
				notify(self, player, "Creating worlds is coming soon", "Info")
			end
			return
		end
		data.WorldCredits -= 1
	end
	local n = (data.WorldsMade or 0) + 1
	data.WorldsMade = n
	local id = tostring(os.time()) .. "_" .. n
	local worldName = cleanName(player, name, "World " .. n)
	data.Worlds[id] = { Name = worldName, Night = 1, Created = os.time() }
	self.pending[player] = nil
	ds:PushWorlds(player)
	task.spawn(ds.Save, ds, player)
	notify(self, player, "🌍 Created " .. worldName .. "!", "Reward")
	self:Open(player, id, password, size)
end

-- ซื้อสำเร็จ (MonetizationService worldReceipt): มีค่าที่รออยู่ = สร้างโลกเลย
function WorldService:OnCredit(player)
	local p = self.pending[player]
	if p and player.Parent then
		self:Create(player, p.Name, p.Password, p.Size)
	else
		notify(self, player, "🌍 World purchased — press + Create to make it", "Reward")
	end
end

function WorldService:Delete(player, worldId)
	local room = self.rooms[player]
	if room and room.WorldId == worldId then
		self:Close(room, "🌍 The host deleted the world")
	end
	self.ctx.Services.DataService:DeleteWorld(player, worldId)
	notify(self, player, "🗑 World deleted", "Info")
end

function WorldService:Join(player, hostId, password, viaInvite)
	if player:GetAttribute("InRun") or player:GetAttribute("Departing") then
		return
	end
	local host = Players:GetPlayerByUserId(tonumber(hostId) or 0)
	local room = host and self.rooms[host]
	if not room then
		notify(self, player, "That world room is gone", "Error")
		return
	end
	if self.roomOf[player] == room then
		return
	end
	if #room.Members >= room.Size then
		notify(self, player, "That world room is full", "Error")
		return
	end
	local invited = viaInvite and room.Invited[player.UserId]
	if room.Password ~= "" and not invited and cleanPassword(password) ~= room.Password then
		notify(self, player, "🔒 Wrong password", "Error")
		return
	end
	local max = self:MaxNight(player)
	if room.Night > max then
		notify(self, player, string.format("This world is on Night %d — you can join worlds up to Night %d (your best night + %d)", room.Night, max, Config.WorldNightGate or 20), "Error")
		return
	end
	self:Leave(player)
	self.ctx.Services.LobbyService:LeavePad(player, true)
	table.insert(room.Members, player)
	self.roomOf[player] = room
	player:SetAttribute("WorldRoom", host.UserId)
	self:Publish(room)
	room.Invited[player.UserId] = nil
	local i = table.find(room.InviteList, tostring(player.UserId))
	if i then
		table.remove(room.InviteList, i)
	end
	self:Publish(room)
	notify(self, player, "🌍 Joined " .. room.WorldName .. " — wait for the host to enter the world", "Good")
	notify(self, host, player.DisplayName .. " joined your world room")
end

-- หัวห้องเชิญคนในเซิร์ฟเวอร์นี้ (คนที่ยังไม่อยู่ห้องไหน) -> คนนั้นเห็นหน้าต่างเชิญ กดรับ = เข้าเลยไม่ต้องใส่รหัส
function WorldService:Invite(player, userId)
	local room = self.rooms[player]
	local target = Players:GetPlayerByUserId(tonumber(userId) or 0)
	if not (room and target) or target == player then
		return
	end
	if target:GetAttribute("InRun") or self.roomOf[target] then
		notify(self, player, target.DisplayName .. " is busy right now", "Info")
		return
	end
	if #room.Members >= room.Size then
		notify(self, player, "Your room is full", "Error")
		return
	end
	if room.Night > self:MaxNight(target) then
		notify(self, player, string.format("%s can't join yet — Night %d is too far for them", target.DisplayName, room.Night), "Error")
		return
	end
	room.Invited[target.UserId] = true
	if not table.find(room.InviteList, tostring(target.UserId)) then
		table.insert(room.InviteList, tostring(target.UserId))
	end
	self:Publish(room)
	self.ctx.Remotes.Get("Cinematic"):FireClient(target, "WorldInvite", {
		HostId = player.UserId, HostName = player.DisplayName, WorldName = room.WorldName, Night = room.Night, New = room.New,
	})
	notify(self, player, "📨 Invited " .. target.DisplayName, "Good")
end

-- หัวห้องเชิญคนออกจากห้อง
function WorldService:Kick(player, userId)
	local room = self.rooms[player]
	local target = Players:GetPlayerByUserId(tonumber(userId) or 0)
	if room and target and target ~= player and self.roomOf[target] == room then
		self:RemoveMember(room, target, "The host removed you from the world room")
		self:Publish(room)
	end
end

function WorldService:StartRoom(player)
	local room = self.rooms[player]
	if not room then
		return
	end
	local list = {}
	for _, m in ipairs(room.Members) do
		if m.Parent and not m:GetAttribute("InRun") then
			table.insert(list, m)
		end
	end
	local resume = not room.New and player or nil
	local worldId = room.WorldId
	self.rooms[player] = nil
	for _, m in ipairs(room.Members) do
		self.roomOf[m] = nil
		if m.Parent then
			m:SetAttribute("WorldRoom", nil)
		end
	end
	if room.Inst then
		room.Inst:Destroy()
	end
	local lobby = self.ctx.Services.LobbyService
	local canTeleport = not RunService:IsStudio() and game.PlaceId ~= 0 and not lobby.IsTeamServer
	if not canTeleport then
		-- Studio: เล่นในเซิร์ฟเวอร์นี้ (โลกเดิมโหลดได้เฉพาะเกมที่ publish แล้ว -> ที่นี่เริ่มคืน 1)
		self.ctx.State:SetAttribute("WorldOwner", player.UserId)
		self.ctx.State:SetAttribute("WorldId", worldId)
	end
	-- เริ่มเล่นแล้ว = ไม่ใช่โลกใหม่ (ห้องครั้งหน้าโชว์คืนที่เซฟ)
	local data = self.ctx.Services.DataService:Get(player)
	if data and type(data.Worlds) == "table" and data.Worlds[worldId] then
		data.Worlds[worldId].Played = true
	end
	lobby:DepartTeam(list, resume, player.UserId, worldId)
end

---------------------------------------------------------------- ในโลก (เซิร์ฟเวอร์ของทีม)
function WorldService:IsWorldOwner(player)
	return self.ctx.State:GetAttribute("WorldOwner") == player.UserId
end

-- เจ้าของโลกออกเกม: เซฟแล้วส่งทุกคนกลับล็อบบี้
function WorldService:OnOwnerLeft(owner)
	local ctx = self.ctx
	local director = ctx.Services.DirectorService
	if not director:IsRunning() or ctx.State:GetAttribute("Phase") == "Ended" then
		return
	end
	-- เซฟโลกก่อน (ยังเป็นเจ้าของโลกอยู่) แล้วค่อยล้างสถานะ/ส่งคนกลับ
	local saved = select(2, pcall(ctx.Services.RejoinService.SaveRunFor, ctx.Services.RejoinService, owner, true))
	print("[AS] world owner left · saved=" .. tostring(saved))
	local others = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= owner then
			table.insert(others, p)
			notify(self, p, "🌍 The world owner left — the world is saved, back to the lobby", "Warn")
		end
	end
	ctx.State:SetAttribute("WorldOwner", nil)
	task.delay(3, function()
		local lobby = ctx.Services.LobbyService
		if not (lobby.IsTeamServer and lobby:ReturnToMainLobby(others, { Result = "HostLeft" })) then
			director:ResetRun()
		end
	end)
end

function WorldService:Start(ctx)
	ctx.Remotes.Get("WorldAction").OnServerEvent:Connect(function(player, action, a, b, c)
		if action == "Create" then
			self:Create(player, a, b, c)
		elseif action == "Open" and type(a) == "string" then
			self:Open(player, a, b, c)
		elseif action == "Delete" and type(a) == "string" then
			self:Delete(player, a)
		elseif action == "Join" then
			self:Join(player, a, b, c == true)
		elseif action == "Invite" then
			self:Invite(player, a)
		elseif action == "Kick" then
			self:Kick(player, a)
		elseif action == "Leave" then
			self:Leave(player)
		elseif action == "Start" then
			self:StartRoom(player)
		end
	end)
	-- เซฟโลกอัตโนมัติทุก 60 วิ (นอกจากเซฟตอนเช้า/ตอนออก) -> หลุด/เกมค้าง/ไฟดับ ก็เสียแค่ไม่เกิน 1 นาที
	task.spawn(function()
		while true do
			task.wait(60)
			local owner = ctx.State:GetAttribute("WorldOwner")
			local p = owner and Players:GetPlayerByUserId(owner)
			if p and ctx.Services.DirectorService:IsRunning() and ctx.State:GetAttribute("Phase") ~= "Ended" then
				pcall(ctx.Services.RejoinService.SaveRunFor, ctx.Services.RejoinService, p)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		self.pending[p] = nil
		self:Leave(p)
		if self:IsWorldOwner(p) then
			self:OnOwnerLeft(p)
		end
	end)
	-- เซิร์ฟเวอร์ของทีมที่มาจากห้องโลก: จำว่าเป็นโลกของใคร (TeleportData.World)
	local function onPlayer(p)
		-- คนที่เคยซื้อ Game Pass Save Run (เลิกขายแล้ว) -> ได้สิทธิ์สร้างโลกฟรี 1 โลก (ครั้งเดียว)
		local function oldPass()
			local ds = ctx.Services.DataService
			local data = ds:Get(p)
			if p:GetAttribute("Pass_SaveRun") and data and not data.SaveRunCredit then
				data.SaveRunCredit = true
				data.WorldCredits = (data.WorldCredits or 0) + 1
				ds:PushWorlds(p)
				task.spawn(ds.Save, ds, p)
				notify(self, p, "🌍 Thanks for buying Save Run — you got 1 free world (press + Create World)", "Reward")
			end
		end
		p:GetAttributeChangedSignal("Pass_SaveRun"):Connect(oldPass)
		task.spawn(function()
			-- พาสเช็กเสร็จก่อนเซฟโหลดได้ -> รอเซฟแล้วเช็กอีกรอบ
			local t0 = os.clock()
			while p.Parent and not ctx.Services.DataService:Get(p) and os.clock() - t0 < 30 do
				task.wait(0.5)
			end
			oldPass()
		end)
		local ok, join = pcall(function()
			return p:GetJoinData()
		end)
		local td = ok and type(join) == "table" and join.TeleportData
		if type(td) == "table" and tonumber(td.World) and ctx.State:GetAttribute("WorldOwner") == nil then
			ctx.State:SetAttribute("WorldOwner", tonumber(td.World))
			ctx.State:SetAttribute("WorldId", tostring(td.WorldId or ""))
		end
		if type(td) == "table" and td.Back and td.Result == "HostLeft" then
			task.delay(6, function()
				if p.Parent then
					notify(self, p, "🌍 The world owner left — their world is saved", "Info")
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayer, p)
	end
	-- ทีมตายหมด (ไม่มีใครชุบ) ในโลก = โลกหาย · กลับล็อบบี้ (Studio) = ไม่ใช่โลกแล้ว
	ctx.State:GetAttributeChangedSignal("Ending"):Connect(function()
		local owner = ctx.State:GetAttribute("WorldOwner")
		local p = owner and Players:GetPlayerByUserId(owner)
		if ctx.State:GetAttribute("Ending") == "Defeat" and p then
			task.spawn(ctx.Services.DataService.DeleteWorld, ctx.Services.DataService, p, ctx.State:GetAttribute("WorldId"))
			ctx.Broadcast("💀 The whole team fell — this world is lost", "Danger")
		end
	end)
	ctx.State:GetAttributeChangedSignal("Phase"):Connect(function()
		if ctx.State:GetAttribute("Phase") == "Lobby" and not ctx.Services.LobbyService.IsTeamServer then
			ctx.State:SetAttribute("WorldOwner", nil)
			ctx.State:SetAttribute("WorldId", nil)
		end
	end)
end

return WorldService
