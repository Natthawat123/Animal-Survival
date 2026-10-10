--[[
	MonetizationService — ร้านค้า Robux
	  · เติมเพชร (Developer Product): Config.DiamondPacks — กันเติมซ้ำด้วยเลขใบเสร็จ (PurchaseId) ที่เก็บไว้ในเซฟ
	  · Game Pass: Config.GamePasses — VIP (เพชร x2 + ป้ายบนหัว), ของเริ่มต้นทุกรอบ (ให้ตอนลงแมพ)
	  · ID ที่ยังเป็น 0 = ยังไม่ได้สร้างใน Creator Hub → ข้ามไป (ปุ่มในร้านขึ้นว่า "เร็วๆ นี้")
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MonetizationService = {}
local owned = {} -- [player] = { [passKey] = true }

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

local function setOwned(player, key)
	owned[player] = owned[player] or {}
	owned[player][key] = true
	player:SetAttribute("Pass_" .. key, true)
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
			self.ctx.Notify(player, "🎫 ของจาก Game Pass: " .. passByKey[key].Name, "Reward")
		end
	end
end

local function processReceipt(self, receipt)
	local pack = packByProduct[receipt.ProductId]
	if not pack then
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
	local total = pack.Diamonds + (pack.Bonus or 0)
	ds:AddDiamonds(player, total, "เติม " .. pack.Name, { Purchased = true })
	table.insert(data.Receipts, receipt.PurchaseId)
	while #data.Receipts > 100 do
		table.remove(data.Receipts, 1)
	end
	if ds:StoreReady() and not ds:Save(player) then
		-- เซฟไม่ผ่าน: คืนค่าแล้วให้ Roblox ส่งใบเสร็จมาใหม่ (กันเพชรหาย/ได้ซ้ำ)
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
			ctx.Notify(player, "🎫 ได้รับ Game Pass: " .. pass.Name .. " — ขอบคุณที่สนับสนุน!", "Reward")
			ctx.Remotes.Get("Cinematic"):FireClient(player, "Purchased", { Kind = "Pass", Name = pass.Name })
			ctx.Services.LobbyService:RefreshTag(player)
		end
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
	end)
end

return MonetizationService
