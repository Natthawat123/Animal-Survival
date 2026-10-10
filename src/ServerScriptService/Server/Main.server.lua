--[[
	ANIMAL SURVIVAL — 99 Nights of the Elements
	Main (server): สุ่ม seed -> สร้างแมพยักษ์ 4 ธาตุ -> วางพร็อพ/สถานที่ -> เปิดทุกระบบ -> ให้ผู้เล่นเกิด
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
if ReplicatedStorage:FindFirstChild("ASAutoTest") then
	Config.ApplyTestOverrides()
end
local Remotes = require(Shared.Remotes)
local MapLayout = require(Shared.MapLayout)
local MapGenerator = require(Shared.MapGenerator)
local PropBuilder = require(Shared.PropBuilder)
local Atmosphere = require(Shared.Atmosphere)
local Items = require(Shared.Items)

Players.CharacterAutoLoads = false
Remotes.Init()

---------------------------------------------------------------- สถานะเกม (client อ่านจาก attributes)
local State = Instance.new("Folder")
State.Name = "GameState"
State:SetAttribute("Ready", false)
State:SetAttribute("Phase", "Loading")
State:SetAttribute("LoadProgress", 0)
State:SetAttribute("Night", 1)
State.Parent = ReplicatedStorage

local seedValue = ReplicatedStorage:FindFirstChild("ASSeed")
local seed = (seedValue and seedValue.Value) or Config.Seed or Random.new():NextInteger(1, 2 ^ 30)
State:SetAttribute("Seed", seed)
State:SetAttribute("MapSize", Config.MapSize)
State:SetAttribute("WaterLevel", Config.WaterLevel)
print(string.format("[AS] seed=%d map=%d", seed, Config.MapSize))

local layout = MapLayout.new(seed, Config.MapSize, Config)

-- ลบแมพตัวอย่างจากปลั๊กอิน (ถ้าเซฟติดมา)
Workspace.Terrain:Clear()
local old = Workspace:FindFirstChild("World")
if old then
	old:Destroy()
end
Atmosphere.Install(Lighting)
Atmosphere.Apply(Lighting, Atmosphere.Values("Heart", 0))

---------------------------------------------------------------- บริการทั้งหมด
local Server = script.Parent
local ctx = {
	Config = Config,
	Layout = layout,
	Seed = seed,
	State = State,
	Remotes = Remotes,
	Services = {},
	CampPosition = Vector3.new(0, layout:HeightAt(0, 0) + 0.5, 0),
}
State:SetAttribute("CampPos", ctx.CampPosition)
function ctx.Notify(player, text, kind)
	Remotes.Get("Notify"):FireClient(player, text, kind or "Info")
end
function ctx.Broadcast(text, kind)
	Remotes.Get("Notify"):FireAllClients(text, kind or "Info")
end

local order = {
	"DataService", "DevService", "InventoryService", "DropService", "SurvivalService", "LobbyService", "MonetizationService", "ResourceService", "CampService", "BuildingService",
	"CombatService", "AnimalService", "SpiritService", "LootService", "TraderService", "DirectorService",
}
for _, name in ipairs(order) do
	ctx.Services[name] = require(Server:WaitForChild(name))
end
for _, name in ipairs(order) do
	ctx.Services[name]:Init(ctx)
end
local function start(names)
	for _, name in ipairs(names) do
		local ok, err = pcall(function()
			ctx.Services[name]:Start(ctx)
		end)
		if not ok then
			warn("[AS] start " .. name .. " failed:", err)
		end
	end
end

-- ช่วงที่ 1: ล็อบบี้พร้อมทันที (ผู้เล่นเกิดในล็อบบี้ระหว่างรอสร้างแมพ)
ctx.Services.LobbyService:Build()
start({ "DataService", "DevService", "InventoryService", "SurvivalService", "LobbyService", "MonetizationService" })

---------------------------------------------------------------- สร้างโลก
local t0 = os.clock()
MapGenerator.Generate(layout, {
	Yield = true,
	Budget = 0.04,
	Progress = function(done, total)
		State:SetAttribute("LoadProgress", done / total * 0.8)
	end,
})
State:SetAttribute("LoadProgress", 0.85)
print(string.format("[AS] terrain %.1fs", os.clock() - t0))
local world = PropBuilder.BuildWorld(layout, { Density = Config.PropDensity, Yield = true })
-- แคมป์วางบนพื้นจริง (สูงกว่า HeightAt ได้) -> อัปเดตตำแหน่งแคมป์ให้ตรง
local campModel = world:FindFirstChild("Sites") and world.Sites:FindFirstChild("Camp")
if campModel and campModel:GetAttribute("GroundY") then
	ctx.CampPosition = Vector3.new(0, campModel:GetAttribute("GroundY") + 0.5, 0)
	State:SetAttribute("CampPos", ctx.CampPosition)
end
State:SetAttribute("LoadProgress", 1)
print(string.format("[AS] world ready %.1fs props=%d", os.clock() - t0, world:GetAttribute("PropCount") or 0))
for _, sp in ipairs(layout.Specials) do
	if sp.Kind == "Shrine" or sp.Kind == "Lair" then
		State:SetAttribute(sp.Kind .. "_" .. sp.Element, sp.Position)
	end
end
for _, site in ipairs(layout.SiteList) do
	State:SetAttribute("Site_" .. site.Element, Vector3.new(site.X, 0, site.Z))
end

-- ช่วงที่ 2: ระบบในแมพ
start({ "DropService", "ResourceService", "CampService", "BuildingService", "CombatService", "AnimalService", "SpiritService", "LootService", "TraderService", "DirectorService" })

-- โหมดลองเล่น: ของเต็มกระเป๋า
if ReplicatedStorage:FindFirstChild("ASSandbox") then
	local function stock(p)
		task.wait(3)
		for id, item in pairs(Items.Data) do
			ctx.Services.InventoryService:Add(p, id, item.Category == "Tool" and 1 or 50, true)
		end
	end
	Players.PlayerAdded:Connect(stock)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(stock, p)
	end
end

Remotes.Get("Ping").OnServerEvent:Connect(function(player, msg)
	print("[AS] ping from", player.Name, msg)
end)

State:SetAttribute("Ready", true)
print("[AS] READY")
