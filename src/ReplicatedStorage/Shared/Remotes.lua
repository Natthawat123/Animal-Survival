--[[
	Remotes — สร้าง/หา RemoteEvent ทั้งหมดของเกม
	Server: Remotes.Init() ครั้งเดียว   ทั้งสองฝั่ง: Remotes.Get("Attack")
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Events = {
	-- client -> server
	"Attack", -- (aimDirection: Vector3)
	"Craft", -- (recipeId, count?) count 1-20 (server ตรวจ/จำกัดเอง)
	"PlaceStructure", -- (kitId, cframe)
	"UseItem", -- (itemId)  กิน/ใช้ยา
	"ChooseClass", -- (classId)
	"BuyClass", -- (classId)
	"BuyKit", -- (kitId) ร้านในล็อบบี้
	"RerollStock", -- () สุ่มสต็อกร้านคลาสใหม่ (Ruby)
	"SkipClassLevel", -- (classId) จ่าย Ruby ข้ามเลเวล
	"ClaimDaily", -- () หม้อรางวัลประจำวัน
	"Trade", -- (offerId) พ่อค้าเร่
	"Ping", -- เทสต์
	"DropItem", -- (itemId, count) ทิ้งของจากกระสอบลงพื้น
	"PickupDrop", -- (dropModel) เก็บของบนพื้น (คลิกตอนถือกระสอบ)
	"ThrowFuel", -- () ถือกระสอบคลิกกองไฟ: โยนเชื้อเพลิง/เนื้อดิบเข้าไป
	"ThrowGrind", -- () ถือกระสอบคลิกเครื่องย่อย: โยนวัตถุดิบลงช่องบด
	"PadSize", -- (padIndex, n) หัวหน้าแท่นเลือกจำนวนคน 1-8
	"LeaveRun", -- () คนที่ตายแล้ว (ดูเพื่อน) กดกลับล็อบบี้
	"SaveSettings", -- (table) การตั้งค่าเสียง/กราฟิก/ปุ่ม
	"TutorialDone", -- () ดูหน้าสอนเล่นจบแล้ว
	"TeamPing", -- c->s (position, target?) ปิงจุดที่เล็ง · s->c ({ From, Name, Position, Kind, Target })
	"RejoinAnswer", -- (accept: boolean) ตอบคำถาม "กลับเข้ารอบเดิม?"
	-- server -> client
	"Notify", -- (text, kind)
	"Inventory", -- (table)
	"Cinematic", -- (kind, data)
	"HitFx", -- (kind, data)
	"Profile", -- (profile table)
	"RejoinOffer", -- ({ Left = วินาทีที่เหลือ, Local = bool }) มีรอบเดิมให้กลับเข้า
}
Remotes.Functions = {
	"GetProfile",
	"GetShopInfo", -- () -> { Passes = { [id] = true }, Packs = Config.DiamondPacks ... }
	"DevCmd", -- (action, a, b) เครื่องมือนักพัฒนา (DevService)
}

local folder

function Remotes.Init()
	assert(RunService:IsServer(), "Remotes.Init ต้องเรียกจาก server")
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(Remotes.Events) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
	for _, name in ipairs(Remotes.Functions) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
	end
	return folder
end

function Remotes.Get(name)
	if not folder then
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
	return folder:WaitForChild(name)
end

return Remotes
