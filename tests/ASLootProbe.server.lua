--[[ ASLootProbe (server) — build_rbxlx.py --lootprobe · เช็กกติกาดรอปใหม่:
	ค่า AnyEssence, เกราะเริ่มต้นหน่วยลาดตระเวน, บอสรังดรอปหัวใจธาตุชุดเดียว + เกิดใหม่, วิหาร = ออร่า + ปิดประตู ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASLootProbe") then
	return
end
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local rf = Instance.new("RemoteFunction")
rf.Name = "LootProbe"
rf.Parent = ReplicatedStorage

local function svc(name)
	return require(Server:WaitForChild(name))
end

local function dropsNear(pos, radius)
	local out = {}
	for _, m in ipairs(Workspace:FindFirstChild("Drops") and Workspace.Drops:GetChildren() or {}) do
		local ok, p = pcall(function()
			return m:GetPivot().Position
		end)
		if ok and (p - pos).Magnitude < radius then
			local id = m.Name:gsub("^Drop_", "")
			out[id] = (out[id] or 0) + (m:GetAttribute("Count") or 1)
		end
	end
	local parts = {}
	for id, n in pairs(out) do
		table.insert(parts, id .. "=" .. n)
	end
	table.sort(parts)
	return table.concat(parts, " ")
end

rf.OnServerInvoke = function(player, what)
	local char = player.Character
	if what == "inv" then
		local inv = svc("InventoryService")
		inv:Add(player, "TerraCore", 1, true)
		inv:Add(player, "TidePearl", 3, true)
		local has = inv:Has(player, { AnyEssence = 4 })
		local ok = inv:Spend(player, { AnyEssence = 2 })
		return string.format("has4=%s spend2=%s Terra=%d Tide=%d avail=%d", tostring(has), tostring(ok), inv:Count(player, "TerraCore"), inv:Count(player, "TidePearl"), inv:Available(player, "AnyEssence"))
	elseif what == "scout" then
		local surv = svc("SurvivalService")
		player:SetAttribute("Class", "Scout")
		player:SetAttribute("StartItemsGiven", false)
		surv:GiveStartItems(player)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		return string.format("armor=%s maxhp=%s torch=%d", tostring(player:GetAttribute("Armor")), hum and tostring(hum.MaxHealth) or "?", svc("InventoryService"):Count(player, "Torch"))
	elseif what == "boss" then
		local spirit = svc("SpiritService")
		local animals = svc("AnimalService")
		local lair = spirit.lairs.Earth
		if not lair then
			return "no lair"
		end
		char:PivotTo(CFrame.new(lair.Pos + Vector3.new(30, 8, 30)))
		task.wait(1.5)
		if not lair.Boss then
			spirit:WakeLair(lair, player)
		end
		task.wait(1)
		local a = lair.Boss
		if not a then
			return "boss not spawned"
		end
		local pos = a.Root.Position
		animals:Kill(a, player)
		task.wait(2.5)
		local drops = dropsNear(pos, 40)
		local cleared = lair.Cleared
		local wait = lair.RespawnAt and math.floor(lair.RespawnAt - os.clock()) or -1
		lair.RespawnAt = os.clock() -- เร่งเวลาเกิดใหม่
		task.wait(2.5)
		return string.format("drops=[%s] cleared=%s respawnIn=%ds afterRespawn cleared=%s ruby=%s", drops, tostring(cleared), wait, tostring(lair.Cleared), tostring(player:GetAttribute("Diamonds"))), pos
	elseif what == "sanctum" then
		local sanct = svc("SanctumService")
		local site = sanct.sites.Earth
		if not site then
			return "no sanctum"
		end
		char:PivotTo(CFrame.new(site.Center + Vector3.new(0, 6, 20)))
		task.wait(1)
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hp0 = hum.MaxHealth
		sanct:Solve(site, player)
		task.wait(4)
		sanct:OpenChest(site, player)
		task.wait(1)
		local res = string.format("aura=%s maxhp %s->%s dmgMult=%.2f hunger=%.2f drops=[%s]", tostring(player:GetAttribute("Aura_Earth")), hp0, hum.MaxHealth,
			svc("SurvivalService"):Perk(player, "DamageMult", 1), svc("SurvivalService"):Perk(player, "HungerMult", 1), dropsNear(site.ChestBody and site.ChestBody.Position or site.Center, 30))
		return res, site.Center
	elseif what == "seal" then
		local sanct = svc("SanctumService")
		local site = sanct.sites.Earth
		task.wait(4)
		local veil, prompt = sanct:PortalVeil(site)
		return string.format("sealed=%s action=%s", tostring(veil and veil:GetAttribute("Sealed")), prompt and prompt.ActionText or "?")
	elseif what == "supply" or what == "meteor" then
		-- เรียกอีเวนต์จริง รอจนกดได้ แล้ววาร์ปผู้เล่นไปข้างๆ (client กดค้าง prompt เอง)
		local ev = svc("EventService")
		local folder = ev:Folder()
		local before = {}
		for _, m in ipairs(folder:GetChildren()) do
			before[m] = true
		end
		local ok = what == "supply" and ev:Supply(ev.token) or ev:Meteor(ev.token)
		local pname = what == "supply" and "OpenSupply" or "Claim"
		local t0 = os.clock()
		local prompt
		while os.clock() - t0 < 45 do
			task.wait(0.5)
			for _, m in ipairs(folder:GetChildren()) do
				local pr = not before[m] and m:FindFirstChild(pname, true)
				if pr then
					prompt = pr
				end
			end
			if prompt and what == "meteor" then
				-- ฆ่าผู้พิทักษ์รอบหลุม
				local animals = svc("AnimalService")
				for _, a in ipairs(animals:All()) do
					if not a.Dead and a.Model:GetAttribute("Guardian") and (a.Root.Position - prompt.Parent.Position).Magnitude < 80 then
						animals:Kill(a, player)
					end
				end
			end
			if prompt and prompt.Enabled then
				break
			end
		end
		if not (prompt and prompt.Enabled) then
			return string.format("started=%s prompt=%s enabled=%s", tostring(ok), tostring(prompt ~= nil), tostring(prompt and prompt.Enabled))
		end
		local pos = prompt.Parent.Position
		char:PivotTo(CFrame.new(pos + Vector3.new(4, 3, 0)))
		player:SetAttribute("ProbeDiamonds0", player:GetAttribute("Diamonds"))
		return "ready " .. pname, pos
	elseif what == "result" then
		task.wait(2)
		local r = char.HumanoidRootPart.Position
		return string.format("drops=[%s] ruby %s->%s", dropsNear(r, 25), tostring(player:GetAttribute("ProbeDiamonds0")), tostring(player:GetAttribute("Diamonds")))
	elseif what == "auras" then
		local surv = svc("SurvivalService")
		for _, el in ipairs({ "Water", "Air", "Fire" }) do
			surv:GiveAura(player, el)
		end
		local dmg, hunger = surv:Perk(player, "DamageMult", 1), surv:Perk(player, "HungerMult", 1)
		player:LoadCharacter()
		task.wait(2)
		local c = player.Character
		local hum = c:FindFirstChildOfClass("Humanoid")
		local names = {}
		for _, d in ipairs(c.HumanoidRootPart:GetChildren()) do
			if d.Name:sub(1, 5) == "Aura_" then
				table.insert(names, d.Name)
			end
		end
		table.sort(names)
		return string.format("dmg=%.2f hunger=%.2f respawn maxhp=%s attached=%s", dmg, hunger, tostring(hum.MaxHealth), table.concat(names, ","))
	elseif what == "resume" then
		local sanct = svc("SanctumService")
		local site = sanct.sites.Earth
		if not site then
			return "no sanctum"
		end
		local data = sanct:Serialize()
		sanct:ResetSite(site)
		local veil = sanct:PortalVeil(site)
		local afterReset = veil:GetAttribute("Sealed")
		sanct:Restore(data)
		return string.format("saved=%s afterReset=%s afterRestore=%s state=%s", tostring(data.Earth), tostring(afterReset), tostring(veil:GetAttribute("Sealed")), site.State)
	elseif what == "hearts" then
		local drops = svc("DropService")
		local root = char.HumanoidRootPart
		local base = root.Position + root.CFrame.LookVector * 10
		for i, id in ipairs({ "TerraHeart", "TideHeart", "FrostHeart", "EmberHeart" }) do
			drops:Spawn(id, 1, base + root.CFrame.RightVector * (i - 2.5) * 3)
		end
		return "ok", base
	end
end
