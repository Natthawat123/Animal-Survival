--[[
	BossAbilities — ท่าพิเศษของบอส (วงเตือนบนพื้น -> ระเบิด)
	ทุกท่าใช้ Telegraph(): วงแดงขยายเต็มก่อนโดน -> หลบให้พ้นวง!
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local BossAbilities = {}

local ELEMENT_COLOR = {
	Earth = Color3.fromRGB(150, 240, 90),
	Water = Color3.fromRGB(70, 200, 255),
	Air = Color3.fromRGB(210, 230, 255),
	Fire = Color3.fromRGB(255, 100, 30),
}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }

local function ground(pos)
	local res = Workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), rayParams)
	return res and res.Position or pos
end

local function charRoot(p)
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- วงเตือน: คืนตำแหน่งพื้น
local function telegraph(ctx, pos, radius, delay, color)
	local g = ground(pos)
	local fxFolder = Workspace:FindFirstChild("FX") or Workspace
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(g + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 40, 40)
	ring.Transparency = 0.75
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Parent = fxFolder
	local fill = ring:Clone()
	fill.Size = Vector3.new(0.35, 0.5, 0.5)
	fill.Color = color
	fill.Transparency = 0.35
	fill.Parent = fxFolder
	TweenService:Create(fill, TweenInfo.new(delay, Enum.EasingStyle.Linear), { Size = Vector3.new(0.35, radius * 2, radius * 2) }):Play()
	Debris:AddItem(ring, delay + 0.1)
	Debris:AddItem(fill, delay + 0.1)
	return g
end

local function hitPlayers(ctx, center, radius, damage, source, opts)
	local surv = ctx.Services.SurvivalService
	local hit = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r then
			local d = ((r.Position - center) * Vector3.new(1, 0, 1)).Magnitude
			if d <= radius and math.abs(r.Position.Y - center.Y) < 16 then
				surv:Damage(p, damage, source, opts and opts(p, r))
				table.insert(hit, p)
			end
		end
	end
	-- ทำลายสิ่งก่อสร้างในวง
	local building = ctx.Services.BuildingService
	for _, s in ipairs(building:All()) do
		if ((s:GetPivot().Position - center) * Vector3.new(1, 0, 1)).Magnitude <= radius then
			building:Damage(s, damage * 0.8)
		end
	end
	return hit
end

local function boom(ctx, pos, radius, color, kind)
	ctx.Remotes.Get("HitFx"):FireAllClients(kind or "Explosion", { Position = pos, Radius = radius, Color = color })
end

local function announce(ctx, a, text)
	ctx.Remotes.Get("HitFx"):FireAllClients("BossCast", { Model = a.Model, Text = text })
	a.Model:SetAttribute("AttackAt", Workspace:GetServerTimeNow())
	a.Model:SetAttribute("AttackKind", "Roar")
end

local Abilities = {}

-- เทอร์ราก้อน: กระทืบแผ่นดิน
Abilities.Quake = function(ctx, a, target)
	announce(ctx, a, "แผ่นดินไหว!")
	ctx.Services.AnimalService:Stop(a)
	local color = ELEMENT_COLOR.Earth
	local center = telegraph(ctx, a.Root.Position, 36, 1.6, color)
	task.wait(1.6)
	if a.Dead then
		return
	end
	boom(ctx, center, 36, color, "Shockwave")
	hitPlayers(ctx, center, 36, a.Info.Damage * a.DamageMult, a.Id, function(p, r)
		local away = ((r.Position - center) * Vector3.new(1, 0, 1))
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
		return { Knockback = away * 70 + Vector3.new(0, 60, 0) }
	end)
end

local function rain(ctx, a, target, count, radius, damage, color, fire)
	local combat = ctx.Services.CombatService
	local targets = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r and (r.Position - a.Root.Position).Magnitude < 140 then
			table.insert(targets, r.Position)
		end
	end
	if #targets == 0 then
		return
	end
	local rng = Random.new()
	for i = 1, count do
		local base = targets[(i - 1) % #targets + 1]
		local pos = base + Vector3.new(rng:NextNumber(-22, 22), 0, rng:NextNumber(-22, 22))
		if i <= #targets then
			pos = base
		end
		local delay = 1.6 + i * 0.12
		local g = telegraph(ctx, pos, radius, delay, color)
		local from = g + Vector3.new(rng:NextNumber(-30, 30), 140, rng:NextNumber(-30, 30))
		local grav = 80
		local vel = (g - from) / delay + Vector3.new(0, 0.5 * grav * delay, 0)
		combat:Projectile({
			From = from, Velocity = vel, Gravity = grav, Radius = 0.1, Blast = radius, Damage = damage,
			Owner = "Animal", Color = color, Size = 4.5, Fire = fire, Source = a.Id, Life = delay + 1,
		})
	end
end

Abilities.BoulderRain = function(ctx, a, target)
	announce(ctx, a, "หินถล่ม!")
	rain(ctx, a, target, 7, 10, a.Info.Damage * a.DamageMult * 0.8, Color3.fromRGB(120, 110, 96), false)
end

-- เลวีอาธาน: คลื่นยักษ์เป็นแนว
Abilities.TidalWave = function(ctx, a, target)
	announce(ctx, a, "คลื่นยักษ์!")
	local r = charRoot(target)
	if not r then
		return
	end
	local dir = ((r.Position - a.Root.Position) * Vector3.new(1, 0, 1))
	dir = dir.Magnitude > 0.1 and dir.Unit or a.Root.CFrame.LookVector
	local color = ELEMENT_COLOR.Water
	for i = 1, 5 do
		local pos = a.Root.Position + dir * (14 + i * 14)
		local delay = 1.0 + i * 0.25
		local g = telegraph(ctx, pos, 13, delay, color)
		task.delay(delay, function()
			if a.Dead then
				return
			end
			boom(ctx, g, 13, color, "Splash")
			hitPlayers(ctx, g, 13, a.Info.Damage * a.DamageMult * 0.7, a.Id, function()
				return { Knockback = dir * 80 + Vector3.new(0, 30, 0) }
			end)
		end)
	end
end

-- เลวีอาธาน: พวยน้ำใต้เท้า
Abilities.WaterSpout = function(ctx, a, target)
	announce(ctx, a, "พวยน้ำ!")
	local color = ELEMENT_COLOR.Water
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r and (r.Position - a.Root.Position).Magnitude < 120 then
			local g = telegraph(ctx, r.Position, 9, 1.5, color)
			task.delay(1.5, function()
				if a.Dead then
					return
				end
				boom(ctx, g, 9, color, "Geyser")
				local hit = hitPlayers(ctx, g, 9, a.Info.Damage * a.DamageMult * 0.6, a.Id)
				for _, hp in ipairs(hit) do
					ctx.Remotes.Get("HitFx"):FireClient(hp, "Launch", { Velocity = Vector3.new(0, 130, 0) })
				end
			end)
		end
	end
end

-- เทมเพสต์ร็อก: พายุหมุนดูด
Abilities.Cyclone = function(ctx, a, target)
	announce(ctx, a, "พายุหมุน!")
	local color = ELEMENT_COLOR.Air
	local center = ground(a.Root.Position)
	boom(ctx, center, 60, color, "Cyclone")
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r and (r.Position - center).Magnitude < 90 then
			ctx.Remotes.Get("HitFx"):FireClient(p, "Pull", { Center = center, Time = 2 })
		end
	end
	local g = telegraph(ctx, center, 22, 2.2, color)
	task.wait(2.2)
	if a.Dead then
		return
	end
	boom(ctx, g, 22, color, "Shockwave")
	hitPlayers(ctx, g, 22, a.Info.Damage * a.DamageMult, a.Id, function()
		return { Knockback = Vector3.new(0, 90, 0) }
	end)
end

-- เทมเพสต์ร็อก: โฉบสายฟ้า
Abilities.LightningDive = function(ctx, a, target)
	announce(ctx, a, "สายฟ้าฟาด!")
	local color = Color3.fromRGB(170, 210, 255)
	local r = charRoot(target)
	if not r then
		return
	end
	local g = telegraph(ctx, r.Position, 14, 1.3, color)
	a.DivePos = g + Vector3.new(0, 6, 0)
	a.DiveUntil = os.clock() + 1.6
	a.DiveHit = true
	task.wait(1.3)
	if a.Dead then
		return
	end
	boom(ctx, g, 14, color, "Lightning")
	hitPlayers(ctx, g, 14, a.Info.Damage * a.DamageMult * 1.2, a.Id)
	for i = 1, 3 do
		local off = Vector3.new(math.cos(i * 2.1) * 20, 0, math.sin(i * 2.1) * 20)
		local g2 = telegraph(ctx, g + off, 9, 0.9, color)
		task.delay(0.9, function()
			boom(ctx, g2, 9, color, "Lightning")
			hitPlayers(ctx, g2, 9, a.Info.Damage * a.DamageMult * 0.6, a.Id)
		end)
	end
end

-- โซลแฟง: วงแหวนเพลิง 2 ชั้น
Abilities.FlameNova = function(ctx, a, target)
	announce(ctx, a, "วงแหวนเพลิง!")
	ctx.Services.AnimalService:Stop(a)
	local color = ELEMENT_COLOR.Fire
	local center = telegraph(ctx, a.Root.Position, 20, 1.3, color)
	task.wait(1.3)
	if a.Dead then
		return
	end
	boom(ctx, center, 20, color, "Shockwave")
	hitPlayers(ctx, center, 20, a.Info.Damage * a.DamageMult, a.Id, function()
		return { Burn = 8 }
	end)
	local g2 = telegraph(ctx, center, 40, 1.1, color)
	task.wait(1.1)
	if a.Dead then
		return
	end
	boom(ctx, g2, 40, color, "Shockwave")
	hitPlayers(ctx, g2, 40, a.Info.Damage * a.DamageMult * 0.6, a.Id, function()
		return { Burn = 6 }
	end)
end

-- โซลแฟง: คำรามเรียกอุกกาบาต
Abilities.MeteorRoar = function(ctx, a, target)
	announce(ctx, a, "อุกกาบาตเพลิง!")
	ctx.Remotes.Get("Cinematic"):FireAllClients("Shake", { Power = 0.8, Time = 1.5 })
	rain(ctx, a, target, 10, 11, a.Info.Damage * a.DamageMult * 0.7, ELEMENT_COLOR.Fire, true)
end

function BossAbilities.Run(ctx, a, name, target)
	local fn = Abilities[name]
	if not fn then
		return
	end
	a.Casting = true
	task.spawn(function()
		local ok, err = pcall(fn, ctx, a, target)
		if not ok then
			warn("[AS] boss ability", name, err)
		end
		a.Casting = false
	end)
end

BossAbilities.Telegraph = telegraph
return BossAbilities
