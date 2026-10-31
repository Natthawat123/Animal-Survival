--[[ ASToolSpam (client) — กดสลับของในแถบเครื่องมือรัวๆ แล้วนับว่า Tool งอกไหม (ฝั่งเครื่อง + เซิร์ฟเวอร์) + เทสช่องยา ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASToolSpam") then
	return
end
local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("GameState")
while not state:GetAttribute("Ready") do
	task.wait(0.5)
end
local lobby = Workspace:WaitForChild("Lobby", 30)
local zone = lobby and lobby:FindFirstChild("MatchBox1", true)
local t0 = os.clock()
while not player:GetAttribute("InRun") and os.clock() - t0 < 60 do
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if zone and r then
		r.CFrame = zone.CFrame
		if player:GetAttribute("Pad") then
			-- หัวหน้าแท่นต้องเลือกจำนวนก่อนถึงจะนับถอยหลัง -> เลือกเดี่ยว
			pcall(function()
				require(ReplicatedStorage.Shared.Remotes).Get("PadSize"):FireServer(zone:GetAttribute("PadIndex") or 1, 1)
			end)
		end
	end
	task.wait(0.5)
end
print("[AS] SPAM inRun", player:GetAttribute("InRun"))
task.wait(8)
local ev = ReplicatedStorage:WaitForChild("ToolSpam")
ev:FireServer("give")
task.wait(1.5)

local function list()
	local out = {}
	for _, h in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
		for _, t in ipairs(h and h:GetChildren() or {}) do
			if t:IsA("Tool") then
				table.insert(out, t)
			end
		end
	end
	return out
end
local function count(tag)
	local names = {}
	for _, t in ipairs(list()) do
		table.insert(names, t.Name)
	end
	table.sort(names)
	local gui = player.PlayerGui:FindFirstChild("ASBackpack")
	local shown = 0
	for _, s in ipairs(gui and gui.Hotbar:GetChildren() or {}) do
		if s:IsA("TextButton") and s.Visible then
			shown += 1
		end
	end
	print(string.format("[AS] SPAM client@%s tools=%d slotsShown=%d : %s", tag, #names, shown, table.concat(names, ", ")))
	ev:FireServer("count", tag)
end
count("before")
print("[SHOT] spam_before")
task.wait(1)

-- กดสลับรัวๆ (แบบแตะช่องเร็วๆ): ถือ/เก็บ/สลับชิ้น ทุก 1-3 เฟรม 6 วินาที
local hum = player.Character:FindFirstChildOfClass("Humanoid")
local rng = Random.new(3)
local s0 = os.clock()
while os.clock() - s0 < 6 do
	local l = list()
	local t = l[rng:NextInteger(1, #l)]
	if rng:NextNumber() < 0.3 then
		hum:UnequipTools()
	elseif t then
		hum:EquipTool(t)
		if rng:NextNumber() < 0.3 then
			pcall(t.Activate, t)
		end
	end
	task.wait(rng:NextNumber() < 0.5 and 0 or 0.03)
end
hum:UnequipTools()
task.wait(0.5)
count("spam+0.5")
task.wait(3)
count("spam+3.5")
print("[SHOT] spam_after")
task.wait(1)

-- ช่องยา: ลดเลือด -> ถือผ้าพันแผล -> คลิก
ev:FireServer("hurt")
task.wait(0.8)
ev:FireServer("hp")
local band
for _, t in ipairs(list()) do
	if t:GetAttribute("MedKind") == "Bandage" then
		band = t
	end
end
print("[AS] SPAM bandageTool=", band and band.Name)
if band then
	hum:EquipTool(band)
	task.wait(0.5)
	band:Activate()
	task.wait(1)
end
ev:FireServer("hp")
task.wait(1)
count("end")
print("[SHOT] spam_med")
task.wait(1.5)
print("[AS] SPAM DONE")
