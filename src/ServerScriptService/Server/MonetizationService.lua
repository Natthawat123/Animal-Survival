--[[
	MonetizationService — ร้านค้า Robux
	  · เติม Ruby (Developer Product): Config.DiamondPacks — กันเติมซ้ำด้วยเลขใบเสร็จ (PurchaseId) ที่เก็บไว้ในเซฟ
	  · ซื้อเป็นของขวัญ: เลือกเพื่อนในเซิร์ฟก่อน (GiftTarget) -> ซื้อแพ็ก -> Ruby เข้าเพื่อน (ออกเกมไปแล้ว = ได้ตอนเข้าเกม)
	  · คืนชีพ: Config.ReviveProductId — ล้มอยู่ = ลุกทันที เลือดเต็ม · ไม่ได้ล้ม (เพื่อนช่วยไปก่อน) = เก็บเป็นตั๋วคืนชีพ
	  · Game Pass: Config.GamePasses — Season Pass, Save Run (เซฟรอบ: RejoinService:SaveRunFor)
	  · ID ที่ยังเป็น 0 = ยังไม่ได้สร้างใน Creator Hub → ข้ามไป (ปุ่มในร้านขึ้นว่า "เร็วๆ นี้")
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Classes = require(ReplicatedStorage.Shared.Classes)

local MonetizationService = {}
local owned = {} -- [player] = { [passKey] = true }
local giftTo = {} -- [ผู้ซื้อ] = { UserId, Name, At } เพื่อนที่จะได้ Ruby จากการซื้อครั้งถัดไป
local GIFT_WINDOW = 300 -- เลือกเพื่อนแล้วต้องซื้อภายในกี่วินาที

local packByProduct = {}
for _, pack in ipairs(Config.DiamondPacks) do
	if (pack.ProductId or 0) > 0 then
		packByProduct[pack.ProductId] = pack
	end
end
local passById, passByKey = {}, {}
for _, pass in ipairs(Config.GamePasses) do
	passByKey[pass.Id] = pass
	if (pass.PassId or 0) > 0 then
		passById[pass.PassId] = pass
	end
end

-- ของเริ่มต้นจาก Game Pass (ให้ทุกครั้งที่ลงแมพ)
local RUN_ITEMS = {
	GiantSack = { GiantSack = 1 },
	Medic = { Bandage = 3, Medkit = 1 },
	Torch = { Torch = 1, Coal = 5 },
}

function MonetizationService:Init(ctx)
	self.ctx = ctx
end

function MonetizationService:HasPass(player, key)
	return owned[player] ~= nil and owned[player][key] == true
end

-- (เดิม: เสนอขาย/เลือกบันทึก Save Run หลังทีมตายหมด) -> เลิกใช้แล้ว: พาสนี้กลายเป็น World Pass (WorldService)
function MonetizationService:OfferSaveRun()
end

local function setOwned(player, key)
	owned[player] = owned[player] or {}
	owned[player][key] = true
	player:SetAttribute("Pass_" .. key, true)
	-- คลาสพาส (Classes.Data[id].Pass == key): ใส่ในคลาสที่มีของเซฟ -> ร้าน/เลือกคลาส/ภารกิจ ใช้ได้ตามปกติ
	task.spawn(function()
		local ds = MonetizationService.ctx and MonetizationService.ctx.Services.DataService
		local data
		for _ = 1, 60 do
			data = ds and ds:Get(player)
			if data or not player.Parent then
				break
			end
			task.wait(0.5)
		end
		if not (data and data.Owned) then
			return
		end
		local changed = false
		for id, c in pairs(Classes.Data) do
			if c.Pass == key and not data.Owned[id] then
				data.Owned[id] = true
				changed = true
			end
		end
		if changed then
			MonetizationService.ctx.Remotes.Get("Profile"):FireClient(player, data)
			task.spawn(ds.Save, ds, player)
		end
	end)
end

-- ให้สิทธิ์พาส (DEV/เทส) — ปกติมาจาก LoadPasses / PromptGamePassPurchaseFinished
function MonetizationService:GrantPass(player, key)
	setOwned(player, key)
end

function MonetizationService:LoadPasses(player)
	owned[player] = owned[player] or {}
	for _, pass in ipairs(Config.GamePasses) do
		if (pass.PassId or 0) > 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.PassId)
			if ok and has then
				setOwned(player, pass.Id)
			end
		end
	end
end

-- เรียกตอนลงแมพ (LobbyService:Depart)
function MonetizationService:GiveRunPerks(player)
	local inv = self.ctx.Services.InventoryService
	for key, items in pairs(RUN_ITEMS) do
		if self:HasPass(player, key) then
			for id, n in pairs(items) do
				inv:Add(player, id, n, true)
			end
			self.ctx.Notify(player, "🎫 Game Pass items: " .. passByKey[key].Name, "Reward")
		end
	end
end

local function remember(data, purchaseId)
	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > 100 do
		table.remove(data.Receipts, 1)
	end
end

-- คืนชีพ: ล้มอยู่ = ลุกเลือดเต็ม · ไม่ได้ล้ม = ตั๋วคืนชีพ 1 ใบ (ใช้ตอนล้มครั้งหน้า)
local function reviveReceipt(self, receipt, player, data)
	local ds = self.ctx.Services.DataService
	local surv = self.ctx.Services.SurvivalService
	-- ชุบ: ตัวเองก่อน (ล้ม/ตายในรอบ) · โหมดชุบทั้งทีม = ตัวเองยืนอยู่แล้วก็ชุบเพื่อนที่ล้ม/ตายคนถัดไป
	local target = surv:IsFallen(player) and player or nil
	if not target and player:GetAttribute("ReviveAll") then
		for _, p in ipairs(Players:GetPlayers()) do
			if surv:IsFallen(p) then
				target = p
				break
			end
		end
	end
	if target then
		surv:ReviveAny(target)
		if target == player then
			self.ctx.Notify(player, "Revived!", "Good")
		else
			self.ctx.Notify(target, player.DisplayName .. " revived you!", "Good")
			self.ctx.Notify(player, "Revived " .. target.DisplayName, "Good")
		end
	else
		data.ReviveTokens = (data.ReviveTokens or 0) + 1
		player:SetAttribute("ReviveTokens", data.ReviveTokens)
		self.ctx.Notify(player, "Got 1 Revive Ticket — use it next time you're down", "Reward")
	end
	remember(data, receipt.PurchaseId)
	if ds:StoreReady() then
		ds:Save(player)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ซื้อแพ็กเป็นของขวัญ: Ruby เข้าเพื่อน (อยู่เซิร์ฟนี้ = ทันที · ไม่อยู่ = เก็บไว้ให้ตอนเข้าเกม)
local function giftReceipt(self, receipt, player, data, pack, gift)
	local ds = self.ctx.Services.DataService
	local total = pack.Diamonds + (pack.Bonus or 0)
	local friend = Players:GetPlayerByUserId(gift.UserId)
	local fdata = friend and ds:Get(friend)
	if fdata then
		ds:AddDiamonds(friend, total, "Gift from " .. player.DisplayName, { Purchased = true })
		if ds:StoreReady() and not ds:Save(friend) then
			fdata.Diamonds -= total
			friend:SetAttribute("Diamonds", fdata.Diamonds)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		self.ctx.Remotes.Get("Cinematic"):FireClient(friend, "Purchased", { Kind = "Gift", Name = player.DisplayName, Diamonds = total })
	else
		local ok = ds:QueueGift(gift.UserId, total, player.DisplayName)
		if not ok then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
	giftTo[player] = nil
	player:SetAttribute("GiftTo", nil)
	remember(data, receipt.PurchaseId)
	if ds:StoreReady() then
		ds:Save(player)
	end
	self.ctx.Notify(player, string.format("Sent %d Ruby to %s!", total, gift.Name), "Reward")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- สร้างโลก (จ่ายต่อ 1 โลก): ได้ "สิทธิ์สร้างโลก" 1 ครั้ง -> WorldService สร้างโลกให้ทันที (เมนู Worlds ส่งค่าที่ตั้งไว้รอ)
local function worldReceipt(self, receipt, player, data)
	local ds = self.ctx.Services.DataService
	data.WorldCredits = (data.WorldCredits or 0) + 1
	remember(data, receipt.PurchaseId)
	if ds:StoreReady() and not ds:Save(player) then
		data.WorldCredits -= 1
		table.remove(data.Receipts, #data.Receipts)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	player:SetAttribute("WorldCredits", data.WorldCredits)
	task.spawn(self.ctx.Services.WorldService.OnCredit, self.ctx.Services.WorldService, player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ชุบทั้งทีม (จ่ายทีเดียว): ชุบทุกคนที่ล้ม/ตายในรอบ · ไม่มีใครล้มแล้ว (ชุบกันเองทัน) = ได้ตั๋วคืนชีพตามจำนวนแทน
local function reviveAllReceipt(self, receipt, player, data)
	local ds = self.ctx.Services.DataService
	local surv = self.ctx.Services.SurvivalService
	local done = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if surv:IsFallen(p) then
			surv:ReviveAny(p)
			done += 1
			if p ~= player then
				self.ctx.Notify(p, player.DisplayName .. " revived the whole team!", "Good")
			end
		end
	end
	if done == 0 then
		-- ไม่มีใครล้มแล้ว (ชุบกันเองทันก่อนจ่ายเสร็จ) -> เก็บเป็นตั๋วคืนชีพ 1 ใบ
		data.ReviveTokens = (data.ReviveTokens or 0) + 1
		player:SetAttribute("ReviveTokens", data.ReviveTokens)
		self.ctx.Notify(player, "Everyone is already up — got 1 Revive Ticket instead", "Reward")
	else
		self.ctx.Notify(player, string.format("Revived the whole team (%d)!", done), "Good")
	end
	remember(data, receipt.PurchaseId)
	if ds:StoreReady() then
		ds:Save(player)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function processReceipt(self, receipt)
	local reviveAllN = (Config.ReviveAllProductId or 0) > 0 and receipt.ProductId == Config.ReviveAllProductId
	local isRevive = (Config.ReviveProductId or 0) > 0 and receipt.ProductId == Config.ReviveProductId
	local isWorld = (Config.WorldProductId or 0) > 0 and receipt.ProductId == Config.WorldProductId
	local pack = packByProduct[receipt.ProductId]
	if not (pack or isRevive or isWorld or reviveAllN) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local ds = self.ctx.Services.DataService
	local data = player and ds:Get(player)
	if not data then
		-- ยังโหลดเซฟไม่เสร็จ/ออกเกมไปแล้ว: Roblox จะส่งใบเสร็จนี้มาใหม่ตอนเข้าเกมครั้งหน้า
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	data.Receipts = data.Receipts or {}
	if table.find(data.Receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if isRevive then
		return reviveReceipt(self, receipt, player, data)
	end
	if isWorld then
		return worldReceipt(self, receipt, player, data)
	end
	if reviveAllN then
		return reviveAllReceipt(self, receipt, player, data)
	end
	local gift = giftTo[player]
	if gift and os.clock() - gift.At < GIFT_WINDOW then
		return giftReceipt(self, receipt, player, data, pack, gift)
	end
	local total = pack.Diamonds + (pack.Bonus or 0)
	ds:AddDiamonds(player, total, "Top-up: " .. pack.Name, { Purchased = true })
	remember(data, receipt.PurchaseId)
	if ds:StoreReady() and not ds:Save(player) then
		-- เซฟไม่ผ่าน: คืนค่าแล้วให้ Roblox ส่งใบเสร็จมาใหม่ (กัน Ruby หาย/ได้ซ้ำ)
		data.Diamonds -= total
		table.remove(data.Receipts, #data.Receipts)
		player:SetAttribute("Diamonds", data.Diamonds)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	self.ctx.Remotes.Get("Cinematic"):FireClient(player, "Purchased", { Kind = "Pack", Name = pack.Name, Diamonds = total })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService:Start(ctx)
	MarketplaceService.ProcessReceipt = function(receipt)
		local ok, res = pcall(processReceipt, self, receipt)
		if ok then
			return res
		end
		warn("[AS] ProcessReceipt", res)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passById[passId]
		if purchased and pass then
			setOwned(player, pass.Id)
			ctx.Notify(player, "🎫 Game Pass received: " .. pass.Name .. " — thanks for your support!", "Reward")
			ctx.Remotes.Get("Cinematic"):FireClient(player, "Purchased", { Kind = "Pass", Name = pass.Name })
			ctx.Services.LobbyService:RefreshTag(player)
		end
	end)
	-- เลือกเพื่อนที่จะซื้อ Ruby ให้ (ต้องอยู่เซิร์ฟเดียวกัน · nil = ยกเลิก ซื้อให้ตัวเอง)
	ctx.Remotes.Get("GiftTarget").OnServerEvent:Connect(function(player, userId)
		local friend = type(userId) == "number" and Players:GetPlayerByUserId(userId)
		if friend and friend ~= player then
			giftTo[player] = { UserId = friend.UserId, Name = friend.DisplayName, At = os.clock() }
			player:SetAttribute("GiftTo", friend.DisplayName)
		else
			giftTo[player] = nil
			player:SetAttribute("GiftTo", nil)
		end
	end)
	-- ทีมล้มหมด: โหมด "ชุบทั้งทีม" (ซื้อคืนชีพแต่ละครั้ง = ชุบคนที่ล้ม/ตายคนถัดไป)
	ctx.Remotes.Get("ReviveAllMode").OnServerEvent:Connect(function(player, on)
		player:SetAttribute("ReviveAll", on == true or nil)
	end)
	-- ใช้ตั๋วคืนชีพตอนล้ม
	ctx.Remotes.Get("UseReviveToken").OnServerEvent:Connect(function(player)
		local ds, surv = ctx.Services.DataService, ctx.Services.SurvivalService
		local data = ds:Get(player)
		if not (data and (data.ReviveTokens or 0) > 0 and surv:IsDowned(player)) then
			return
		end
		data.ReviveTokens -= 1
		player:SetAttribute("ReviveTokens", data.ReviveTokens)
		surv:Revive(player, 1)
		ctx.Notify(player, "Revived!", "Good")
		task.spawn(ds.Save, ds, player)
	end)
	ctx.Remotes.Get("GetShopInfo").OnServerInvoke = function(player)
		local passes = {}
		for key in pairs(owned[player] or {}) do
			passes[key] = true
		end
		return { Passes = passes }
	end
	local function onPlayer(player)
		self:LoadPasses(player)
		ctx.Services.LobbyService:RefreshTag(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		owned[p] = nil
		giftTo[p] = nil
	end)
end

return MonetizationService
