--[[ ASTribeProbe (server) — build_rbxlx.py --tribeprobe
	หมู่บ้าน/ป้อมชนเผ่า: หีบ + แท่นหินกะโหลกล็อกจนกว่าทหารตายหมด · ป้อมไบโอมไฟมีบันไดปีนขึ้นหอ/เสาประตู (ปีนถึงยอดจริง) ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
if not ReplicatedStorage:FindFirstChild("ASTribeProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(3)
local ctx = require(game:GetService("ServerScriptService").Server.RejoinService).ctx
local S = ctx.Services
player:SetAttribute("TestGod", true)
local fails = 0
local function check(name, ok, info)
	if not ok then
		fails += 1
	end
	print(string.format("[AS] TRIBEPROBE %s %s %s", ok and "PASS" or "FAIL", name, info or ""))
end
local notes = {}
local n0 = ctx.Notify
ctx.Notify = function(p, t, k)
	table.insert(notes, tostring(t))
	return n0(p, t, k)
end
local function center(v)
	local c = v:GetAttribute("Center")
	return typeof(c) == "Vector3" and c or v:GetPivot().Position
end
local village, capital
for _, v in ipairs(CollectionService:GetTagged("Village")) do
	if v:IsDescendantOf(workspace) then
		if v:GetAttribute("Capital") then
			capital = v
		elseif not village then
			village = v
		end
	end
end
check("found", village ~= nil and capital ~= nil)
local key = "Opened_" .. player.UserId

-- 1) หมู่บ้านทั่วไป: เข้าใกล้ -> ทหารออก -> หีบ/แท่นต้องล็อก
if village then
	S.DevService:Teleport(player, center(village) + Vector3.new(0, 6, 0))
	local t0 = os.clock()
	repeat
		task.wait(0.5)
	until (village:GetAttribute("GuardsLeft") or 0) > 0 or os.clock() - t0 > 15
	check("guards_spawned", (village:GetAttribute("GuardsLeft") or 0) > 0, "left=" .. tostring(village:GetAttribute("GuardsLeft")))
	local chest, altar
	for _, d in ipairs(village:GetDescendants()) do
		if d:IsA("Model") and CollectionService:HasTag(d, "Chest") and not chest then
			chest = d
		elseif d:IsA("Model") and CollectionService:HasTag(d, "SkullAltar") then
			altar = d
		end
	end
	table.clear(notes)
	if chest then
		S.LootService:Open(chest, player)
		check("chest_locked", chest:GetAttribute(key) ~= true, table.concat(notes, " | "))
	end
	if altar then
		S.LootService:TakeAltar(altar, player)
		check("altar_locked", altar:GetAttribute(key) ~= true)
	end
	-- กวาดล้าง: ฆ่าทหารทุกตัวในหมู่บ้าน
	local st = S.VillageService.villages[village]
	for _, a in ipairs(st and st.Members or {}) do
		if not a.Dead and a.Hum then
			S.CombatService:DamageAnimal(a, 1e7, player, {})
		end
	end
	t0 = os.clock()
	repeat
		task.wait(0.5)
	until village:GetAttribute("ClearedAt") or os.clock() - t0 > 10
	check("cleared", village:GetAttribute("ClearedAt") ~= nil and (village:GetAttribute("GuardsLeft") or 0) == 0, "left=" .. tostring(village:GetAttribute("GuardsLeft")))
	if chest then
		S.LootService:Open(chest, player)
		check("chest_opens_after_clear", chest:GetAttribute(key) == true)
	end
	if altar then
		S.LootService:TakeAltar(altar, player)
		check("altar_after_clear", altar:GetAttribute(key) == true)
	end
end

-- 2) ป้อมไบโอมไฟ: ปีนบันไดขึ้นหอ/เสาประตูถึงยอดจริง (เดินชนบันได Humanoid ปีนเอง)
if capital then
	local ladders = {}
	for _, d in ipairs(capital:GetDescendants()) do
		if d:IsA("TrussPart") and d.Name == "Ladder" then
			table.insert(ladders, d)
		end
	end
	check("ladders", #ladders == 10, "count=" .. #ladders)
	local c = center(capital)
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	local root = player.Character.HumanoidRootPart
	local tried = 0
	for i, lad in ipairs(ladders) do
		if i == 1 or i == 9 then -- หอคอย 1 หอ + เสาประตู 1 ต้น
			tried += 1
			local top = lad.Position.Y + lad.Size.Y / 2
			local out = (lad.Position - (lad.CFrame * CFrame.new(0, 0, -1)).Position) -- ทิศออกจากผนัง (หน้าบันได -Z หันเข้าหอ)
			out = Vector3.new(out.X, 0, out.Z).Unit
			local foot = Vector3.new(lad.Position.X, lad.Position.Y - lad.Size.Y / 2 + 4, lad.Position.Z) + out * 4
			player.Character:PivotTo(CFrame.lookAt(foot, Vector3.new(lad.Position.X, foot.Y, lad.Position.Z)))
			task.wait(0.6)
			local best = -math.huge
			local t0 = os.clock()
			while os.clock() - t0 < 14 do
				hum:Move(-out, false)
				best = math.max(best, root.Position.Y)
				if root.Position.Y > top + 1.5 then
					break
				end
				task.wait(0.1)
			end
			-- ถึงยอดแล้วเดินเข้าไปบนพื้นยอดหอ
			for _ = 1, 10 do
				hum:Move(-out, false)
				task.wait(0.1)
			end
			hum:Move(Vector3.zero, false)
			task.wait(0.5)
			best = math.max(best, root.Position.Y)
			check("climb_" .. i, best > top + 1, string.format("reach=%.1f top=%.1f stand=%.1f", best, top, root.Position.Y))
			local sh = Instance.new("Vector3Value")
			sh.Name = "TribeShot"
			sh.Value = root.Position
			sh:SetAttribute("Look", lad.Position)
			sh:SetAttribute("N", i)
			sh.Parent = ReplicatedStorage
			task.wait(2.5)
			sh:Destroy()
		end
	end
end
print(string.format("[AS] TRIBEPROBE TOTAL fails=%d", fails))
print("[TEST] DONE tribeprobe")
