--[[ ASArenaProbe (server) — build_rbxlx.py --arenaprobe
	ทุกธาตุ: ถ่ายลานรังบอสมุมสูง -> ปลุกบอสในรังจริง -> สั่งใช้สกิลทีละท่า (3 ท่า) + ถ่ายภาพตอนวงเตือน/ตอนระเบิด
	บันทึกระยะบอสจากกลางรัง + บอสขยับได้ไหม (ติด) · client: ASArenaProbe.client.lua (กล้องตาม attribute) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASArenaProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(4)
local Server = game:GetService("ServerScriptService").Server
local ctx = require(Server.RejoinService).ctx
local BossAbilities = require(Server.BossAbilities)
local Animals = require(ReplicatedStorage.Shared.Animals)
player:SetAttribute("TestGod", true)
local spirit = ctx.Services.SpiritService
local animals = ctx.Services.AnimalService
local only = ReplicatedStorage:FindFirstChild("ASArenaOnly") and ReplicatedStorage.ASArenaOnly.Value or nil

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local function ground(p)
	local hit = workspace:Raycast(p + Vector3.new(0, 200, 0), Vector3.new(0, -500, 0), rp)
	return hit and hit.Position or p
end
local function shot(name, center, h)
	if center then
		player:SetAttribute("ArenaCenter", center)
		player:SetAttribute("ArenaH", h or 120)
	end
	task.wait(0.3)
	player:SetAttribute("ArenaShot", name)
	task.wait(1.4)
end

local IDS = { Earth = "Terragon", Water = "Leviathan", Air = "TempestRoc", Fire = "Solfang" }
for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
	if only and not only:find(el) then
		continue
	end
	local lair = spirit.lairs[el]
	if not lair then
		print("[AS] ARENA " .. el .. " no lair")
		continue
	end
	local c = lair.Pos
	-- ผู้เล่นยืนห่างกลางรัง 55 ฝั่งแคมป์
	local toCamp = (ctx.CampPosition - c) * Vector3.new(1, 0, 1)
	toCamp = toCamp.Magnitude > 1 and toCamp.Unit or Vector3.new(1, 0, 0)
	local stand = ground(c + toCamp * 55) + Vector3.new(0, 4, 0)
	player.Character:PivotTo(CFrame.new(stand, c))
	task.wait(3)
	shot("arena_" .. el .. "_wide", c, 120)
	shot("arena_" .. el .. "_close", c, 75)
	if lair.Boss and not lair.Boss.Dead then
		animals:Remove(lair.Boss)
		lair.Boss = nil
	end
	lair.Cleared = false
	spirit:WakeLair(lair, player)
	local a = lair.Boss
	if not a then
		print("[AS] ARENA " .. el .. " boss did not spawn")
		continue
	end
	task.wait(9) -- ฉากเปิดตัว
	print(string.format("[AS] ARENA %s boss=%s radius=%.1f leash=%s hp=%d", el, a.Id, a.Radius, tostring(a.Leash), a.Hum.MaxHealth))
	shot("arena_" .. el .. "_boss", c, 85)
	for _, name in ipairs(Animals.Data[IDS[el]].Abilities or {}) do
		local t0 = os.clock()
		while a.Casting and os.clock() - t0 < 12 do
			task.wait(0.2)
		end
		a.NextAbility = math.huge -- ปิดสกิลอัตโนมัติ (สั่งเองทีละท่า)
		a.SkillReady = {}
		local p0 = a.Root.Position
		BossAbilities.Run(ctx, a, name, player)
		task.spawn(function()
			for k = 1, 30 do
				task.wait(0.2)
				local q = a.Root.Position
				if k % 3 == 0 then
					local balls, far = 0, 0
					for _, b in ipairs((workspace:FindFirstChild("FX") or workspace):GetChildren()) do
						if b:GetAttribute("VFX") == "WaterBall" then
							balls += 1
							far = math.max(far, (b.Position - q).Magnitude)
						end
					end
					print(string.format("[AS] ARENA trace %s %s t=%.1f pos=%.0f,%.0f,%.0f balls=%d far=%.0f", el, name, k * 0.2, q.X, q.Y, q.Z, balls, far))
				end
			end
		end)
		local tag = "arena_" .. el .. "_" .. name
		task.wait(1.0)
		shot(tag .. "_1", a.Root.Position, 70)
		task.wait(1.3)
		shot(tag .. "_2", nil)
		task.wait(0.6)
		shot(tag .. "_3", nil)
		shot(tag .. "_4", nil)
		t0 = os.clock()
		while a.Casting and os.clock() - t0 < 12 do
			task.wait(0.2)
		end
		print(string.format("[AS] ARENA %s %s done fromHome=%.1f moved=%.1f", el, name, ((a.Root.Position - c) * Vector3.new(1, 0, 1)).Magnitude, (a.Root.Position - p0).Magnitude))
		-- ให้บอสไล่ผู้เล่นสักพัก: ดูว่าเดินได้/ติดไหม
		a.NextAbility = math.huge
		local s0 = a.Root.Position
		player.Character:PivotTo(CFrame.new(ground(c - toCamp * 60) + Vector3.new(0, 4, 0)))
		task.wait(3)
		print(string.format("[AS] ARENA %s chase moved=%.1f fromHome=%.1f", el, (a.Root.Position - s0).Magnitude, ((a.Root.Position - c) * Vector3.new(1, 0, 1)).Magnitude))
		player.Character:PivotTo(CFrame.new(stand, c))
		task.wait(1)
	end
	animals:Remove(a)
	lair.Boss = nil
	task.wait(1)
end
print("[TEST] DONE arenaprobe")
