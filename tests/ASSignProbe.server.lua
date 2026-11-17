--[[ ASSignProbe (server) — build_rbxlx.py --signprobe · ป้ายหน้าศาลเจ้า/รังบอส/วิหาร + กันสัตว์ตีตอนดูฉาก + ฉากทั้งทีมได้บัพ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASSignProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(3)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local S = ctx.Services
-- แมพใหญ่: วิหารสร้างทีหลังโลก -> รอจนมีป้ายวิหาร (สูงสุด 3 นาที)
local function countSanctum()
	local n = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == "SiteSign" and d.Parent and d.Parent.Name:match("^Sanctum") then
			n += 1
		end
	end
	return n
end
local tw = os.clock()
repeat
	task.wait(3)
until countSanctum() > 0 or os.clock() - tw > 180
local signs = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and d.Name == "SiteSign" then
		local site = d.Parent and d.Parent.Name or "?"
		table.insert(signs, { Model = d, Site = site })
	end
end
print("[AS] SIGNPROBE signs=" .. #signs)
local want = { Shrine_Earth = true, Shrine_Fire = true, Sanctum_Water = true, Sanctum_Air = true }
for _, s in ipairs(signs) do
	local board = s.Model:FindFirstChild("Board")
	local cf = board and board.CFrame
	local gui = board and board:FindFirstChild("SignGui")
	local lines = 0
	for _, t in ipairs(gui and gui:GetDescendants() or {}) do
		if t:IsA("TextLabel") then
			lines += 1
		end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local g = cf and workspace:Raycast(cf.Position + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0), rp)
	print(string.format("[AS] SIGNPROBE %s lines=%d boardY=%.1f groundY=%s", s.Site, lines, cf and cf.Y or -1, g and string.format("%.1f", g.Position.Y) or "none"))
	if want[s.Site] and cf then
		want[s.Site] = false
		S.DevService:Teleport(player, (cf * CFrame.new(0, 0, -16)).Position)
		task.wait(3)
		ReplicatedStorage:SetAttribute("SignCF", cf)
		ReplicatedStorage:SetAttribute("SignShot", s.Site)
		task.wait(4)
	end
end
do return print("[TEST] DONE signprobe") end
-- กันสัตว์ตีตอนดูฉาก: ป้องกัน 6 วิ แล้วเสกหมาป่าข้างตัว
S.DevService:Teleport(player, ctx.CampPosition + Vector3.new(200, 3, 200))
task.wait(2)
local hum = player.Character:FindFirstChildOfClass("Humanoid")
S.SurvivalService:Protect(player, 6)
local root = player.Character.HumanoidRootPart
local wolf = S.AnimalService:Spawn("MossWolf", root.Position + Vector3.new(6, 0, 0), { Kind = "Guardian", Home = root.Position, Leash = 80 })
local hp0 = hum.Health
task.wait(5.5)
local hp1 = hum.Health
print(string.format("[AS] SIGNPROBE protected hp %d -> %d (expect same)", hp0, hp1))
task.wait(6)
print(string.format("[AS] SIGNPROBE unprotected hp %d -> %d (expect lower)", hp1, hum.Health))
if wolf and wolf.Model then
	wolf.Model:Destroy()
end
hum.Health = hum.MaxHealth
-- ฉากทั้งทีมได้บัพ
ctx.FireRun("Cinematic", "TeamBuff", { Element = "Fire", Title = "SANCTUM CLEARED", Text = "✨ Fire Aura: Damage +15% · whole team, whole run" })
ReplicatedStorage:SetAttribute("SignShot", "buff")
task.wait(4)
ReplicatedStorage:SetAttribute("SignShot", "done")
print("[TEST] DONE signprobe")
