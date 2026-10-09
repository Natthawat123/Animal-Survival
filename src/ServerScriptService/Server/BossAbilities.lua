--[[
	BossAbilities — สกิลบอส (บอสไม่ตีประชิด ใช้สกิลอย่างเดียว)
	ทุกท่า: บอสเล่นท่าร่าย (attribute Cast/CastAt/CastTime -> BossAnimator) + วงเตือนบนพื้น (BossFX) -> หลบให้พ้น!
	เอฟเฟกต์ทั้งหมดวาดฝั่ง client ผ่าน HitFx (BossTelegraph / BossImpact / BossSpikes / BossWave / BossBreath / BossBlizzard)
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BossAbilities = {}

local ELEMENT_COLOR = {
	Earth = Color3.fromRGB(150, 240, 90),
	Water = Color3.fromRGB(70, 200, 255),
	Air = Color3.fromRGB(170, 225, 255),
	Fire = Color3.fromRGB(255, 100, 30),
}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }

local function ground(pos)
	local res = Workspace:Raycast(pos + Vector3.new(0, 80, 0), Vector3.new(0, -300, 0), rayParams)
	return res and res.Position or pos
end

local function charRoot(p)
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function fx(ctx, kind, data)
	ctx.Remotes.Get("HitFx"):FireAllClients(kind, data)
end

-- ท่าร่าย: บอสง้าง (windup วินาที) ก่อนสกิลออก + ป้ายชื่อสกิล
local function cast(ctx, a, anim, windup, text)
	local m = a.Model
	m:SetAttribute("Cast", anim)
	m:SetAttribute("CastTime", windup)
	m:SetAttribute("CastAt", Workspace:GetServerTimeNow())
	fx(ctx, "BossCast", { Model = m, Text = text })
end

-- วงเตือนกลม (client วาด) -> คืนตำแหน่งพื้น
local function tele(ctx, a, pos, radius, time)
	local g = ground(pos)
	fx(ctx, "BossTelegraph", { Pos = g, Radius = radius, Time = time, Element = a.Info.Element })
	return g
end

local function impact(ctx, a, pos, radius, style)
	fx(ctx, "BossImpact", { Pos = pos, Radius = radius, Element = a.Info.Element, Style = style })
end

local function hitPlayers(ctx, center, radius, damage, source, opts)
	local surv = ctx.Services.SurvivalService
	local hit = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r then
			local d = ((r.Position - center) * Vector3.new(1, 0, 1)).Magnitude
			if d <= radius and math.abs(r.Position.Y - center.Y) < 18 then
				surv:Damage(p, damage, source, opts and opts(p, r))
				table.insert(hit, p)
			end
		end
	end
	local building = ctx.Services.BuildingService
	for _, s in ipairs(building:All()) do
		if ((s:GetPivot().Position - center) * Vector3.new(1, 0, 1)).Magnitude <= radius then
			building:Damage(s, damage * 0.8)
		end
	end
	return hit
end

-- ผู้เล่นที่อยู่ในแถบเส้นตรง (from -> dir ยาว length กว้าง width)
local function inLine(r, from, dir, length, width)
	local rel = (r.Position - from) * Vector3.new(1, 0, 1)
	local along = rel:Dot(dir)
	local side = (rel - dir * along).Magnitude
	return along > -4 and along < length and side < width / 2, along
end

local function flatDir(a, target)
	local r = target and charRoot(target)
	local d = r and ((r.Position - a.Root.Position) * Vector3.new(1, 0, 1)) or Vector3.zero
	return d.Magnitude > 0.1 and d.Unit or a.Root.CFrame.LookVector
end

local function playersNear(a, range)
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r and (r.Position - a.Root.Position).Magnitude < range then
			table.insert(out, r)
		end
	end
	return out
end

local Abilities = {}

-- ทุบพื้น (ทุกธาตุ): ยกแขน/ตัวขึ้น -> กระแทก -> คลื่นกระแทก + หนาม/เสารอบตัว
Abilities.Quake = function(ctx, a)
	local radius = 34 + a.Radius * 0.5
	local windup = 1.5
	cast(ctx, a, "Slam", windup, ({ Earth = "ทุบแผ่นดิน!", Air = "ทุบธารน้ำแข็ง!", Water = "ฟาดคลื่น!", Fire = "ทุบลาวา!" })[a.Info.Element] or "ทุบพื้น!")
	local center = tele(ctx, a, a.Root.Position, radius, windup)
	task.wait(windup)
	if a.Dead then
		return
	end
	impact(ctx, a, center, radius, "Slam")
	fx(ctx, "BossSpikes", { Pos = center, Radius = radius * 0.85, Count = 14, Element = a.Info.Element, Ring = true })
	hitPlayers(ctx, center, radius, a.Info.Damage * a.DamageMult, a.Id, function(_, r)
		local away = (r.Position - center) * Vector3.new(1, 0, 1)
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
		return { Knockback = away * 75 + Vector3.new(0, 55, 0) }
	end)
end

-- โกเลม: รอยแยกพื้นพุ่งเป็นแนวตรง หนามหินผุดตามแนว
Abilities.Fissure = function(ctx, a, target)
	local dir = flatDir(a, target)
	local from = ground(a.Root.Position + dir * (a.Radius * 0.6))
	local length, width, windup = 130, 16, 1.2
	cast(ctx, a, "Slam", windup, "รอยแยกปฐพี!")
	fx(ctx, "BossTelegraph", { Pos = from, Dir = dir, Length = length, Width = width, Time = windup, Element = a.Info.Element, Shape = "Line" })
	task.wait(windup)
	if a.Dead then
		return
	end
	impact(ctx, a, from, 18, "Slam")
	local hitSet = {}
	for i = 0, 12 do
		local p = ground(from + dir * (i * length / 12))
		fx(ctx, "BossSpikes", { Pos = p, Radius = width * 0.45, Count = 4, Element = a.Info.Element })
		for _, pl in ipairs(Players:GetPlayers()) do
			local r = charRoot(pl)
			if r and not hitSet[pl] and ((r.Position - p) * Vector3.new(1, 0, 1)).Magnitude < width * 0.6 then
				hitSet[pl] = true
				ctx.Services.SurvivalService:Damage(pl, a.Info.Damage * a.DamageMult * 0.9, a.Id, { Knockback = Vector3.new(0, 85, 0) + dir * 20 })
			end
		end
		task.wait(0.06)
	end
end

-- ฝนหิน/อุกกาบาต: ของหล่นจากฟ้าใส่ผู้เล่น (วงเตือนก่อนตก)
local function rain(ctx, a, count, radius, damage, color, fire, size)
	local combat = ctx.Services.CombatService
	local targets = playersNear(a, 170)
	if #targets == 0 then
		return
	end
	local rng = Random.new()
	for i = 1, count do
		local base = targets[(i - 1) % #targets + 1].Position
		local pos = base + Vector3.new(rng:NextNumber(-26, 26), 0, rng:NextNumber(-26, 26))
		if i <= #targets then
			pos = base
		end
		local delay = 1.5 + i * 0.14
		local g = tele(ctx, a, pos, radius, delay)
		local from = g + Vector3.new(rng:NextNumber(-40, 40), 170, rng:NextNumber(-40, 40))
		local grav = 80
		local vel = (g - from) / delay + Vector3.new(0, 0.5 * grav * delay, 0)
		combat:Projectile({
			From = from, Velocity = vel, Gravity = grav, Radius = 0.1, Blast = radius, Damage = damage,
			Owner = "Animal", Color = color, Size = size or 6, Fire = fire, Source = a.Id, Life = delay + 1,
			Model = "Rock", VFX = fire and "Meteor" or "Boulder",
		})
		task.delay(delay, function()
			impact(ctx, a, g, radius, "Small")
		end)
	end
end

Abilities.BoulderRain = function(ctx, a)
	cast(ctx, a, "Summon", 1.6, "หินถล่ม!")
	task.wait(0.4)
	rain(ctx, a, 9, 11, a.Info.Damage * a.DamageMult * 0.75, Color3.fromRGB(112, 98, 82), false, 9)
end

Abilities.MeteorRoar = function(ctx, a)
	cast(ctx, a, "Roar", 1.5, "อุกกาบาตเพลิง!")
	ctx.Remotes.Get("Cinematic"):FireAllClients("Shake", { Power = 0.7, Time = 1.6 })
	task.wait(0.4)
	rain(ctx, a, 11, 12, a.Info.Damage * a.DamageMult * 0.7, Color3.fromRGB(60, 40, 36), true, 8)
end

-- โมซาซอรัส: คลื่นยักษ์เป็นกำแพงน้ำวิ่งเข้าหาผู้เล่น
Abilities.TidalWave = function(ctx, a, target)
	local dir = flatDir(a, target)
	local from = ground(a.Root.Position + dir * (a.Radius * 0.5))
	local length, width, windup, travel = 140, 34, 1.3, 1.5
	cast(ctx, a, "Rear", windup, "คลื่นยักษ์!")
	fx(ctx, "BossTelegraph", { Pos = from, Dir = dir, Length = length, Width = width, Time = windup, Element = a.Info.Element, Shape = "Line" })
	task.wait(windup)
	if a.Dead then
		return
	end
	impact(ctx, a, from, 20, "Slam")
	fx(ctx, "BossWave", { Pos = from, Dir = dir, Length = length, Width = width, Time = travel, Element = a.Info.Element })
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r then
			local inside, along = inLine(r, from, dir, length, width)
			if inside then
				task.delay(math.max(0, along / length * travel), function()
					local r2 = charRoot(p)
					if r2 and inLine(r2, from, dir, length, width) and not a.Dead then
						ctx.Services.SurvivalService:Damage(p, a.Info.Damage * a.DamageMult * 0.85, a.Id, { Knockback = dir * 95 + Vector3.new(0, 40, 0) })
					end
				end)
			end
		end
	end
end

-- โมซาซอรัส: พวยน้ำพุ่งใต้เท้าผู้เล่น
Abilities.WaterSpout = function(ctx, a)
	cast(ctx, a, "Roar", 1.4, "พวยน้ำ!")
	for _, r in ipairs(playersNear(a, 160)) do
		local spots = { r.Position }
		for k = 1, 2 do
			table.insert(spots, r.Position + Vector3.new(math.cos(k * 2.4) * 18, 0, math.sin(k * 2.4) * 18))
		end
		for _, pos in ipairs(spots) do
			local g = tele(ctx, a, pos, 10, 1.5)
			task.delay(1.5, function()
				if a.Dead then
					return
				end
				impact(ctx, a, g, 10, "Geyser")
				local hit = hitPlayers(ctx, g, 10, a.Info.Damage * a.DamageMult * 0.6, a.Id)
				for _, hp in ipairs(hit) do
					ctx.Remotes.Get("HitFx"):FireClient(hp, "Launch", { Velocity = Vector3.new(0, 120, 0) })
				end
			end)
		end
	end
end

-- เยติ: พายุหิมะหมุนรอบตัว ดูดเข้า แล้วระเบิดน้ำแข็ง
Abilities.Blizzard = function(ctx, a)
	local windup = 2.2
	cast(ctx, a, "Roar", windup, "พายุหิมะ!")
	local center = ground(a.Root.Position)
	fx(ctx, "BossBlizzard", { Pos = center, Radius = 55, Time = windup + 0.6, Element = a.Info.Element })
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r and (r.Position - center).Magnitude < 95 then
			ctx.Remotes.Get("HitFx"):FireClient(p, "Pull", { Center = center, Time = windup })
		end
	end
	local radius = 26 + a.Radius * 0.4
	local g = tele(ctx, a, center, radius, windup)
	task.wait(windup)
	if a.Dead then
		return
	end
	impact(ctx, a, g, radius, "Slam")
	fx(ctx, "BossSpikes", { Pos = g, Radius = radius * 0.8, Count = 16, Element = a.Info.Element, Ring = true })
	hitPlayers(ctx, g, radius, a.Info.Damage * a.DamageMult, a.Id, function()
		return { Knockback = Vector3.new(0, 90, 0) }
	end)
end

-- เยติ: หนามน้ำแข็งผุดใต้เท้าผู้เล่น
Abilities.IceSpikes = function(ctx, a)
	cast(ctx, a, "Slam", 1.2, "หนามน้ำแข็ง!")
	for _, r in ipairs(playersNear(a, 160)) do
		local spots = { r.Position }
		for k = 1, 3 do
			table.insert(spots, r.Position + Vector3.new(math.cos(k * 2.1) * 16, 0, math.sin(k * 2.1) * 16))
		end
		for i, pos in ipairs(spots) do
			local delay = 1.2 + i * 0.12
			local g = tele(ctx, a, pos, 9, delay)
			task.delay(delay, function()
				if a.Dead then
					return
				end
				fx(ctx, "BossSpikes", { Pos = g, Radius = 6, Count = 7, Element = a.Info.Element })
				impact(ctx, a, g, 9, "Small")
				hitPlayers(ctx, g, 9, a.Info.Damage * a.DamageMult * 0.7, a.Id, function()
					return { Knockback = Vector3.new(0, 100, 0) }
				end)
			end)
		end
	end
end

-- มังกร: พ่นไฟเป็นแนวยาว (โดนต่อเนื่อง + ติดไฟ)
Abilities.FireBreath = function(ctx, a, target)
	local dir = flatDir(a, target)
	local from = ground(a.Root.Position)
	local length, width, windup, dur = 110, 22, 1.1, 1.8
	cast(ctx, a, "Breath", windup, "ลมหายใจเพลิง!")
	fx(ctx, "BossTelegraph", { Pos = from, Dir = dir, Length = length, Width = width, Time = windup, Element = a.Info.Element, Shape = "Line" })
	task.wait(windup)
	if a.Dead then
		return
	end
	fx(ctx, "BossBreath", { Model = a.Model, To = ground(from + dir * length * 0.8), Pos = from, Dir = dir, Length = length, Time = dur })
	for _ = 1, 5 do
		for _, p in ipairs(Players:GetPlayers()) do
			local r = charRoot(p)
			if r and inLine(r, from, dir, length, width) then
				ctx.Services.SurvivalService:Damage(p, a.Info.Damage * a.DamageMult * 0.28, a.Id, { Burn = 6 })
			end
		end
		task.wait(dur / 5)
	end
end

-- มังกร: วงแหวนเพลิง 2 ชั้น + เสาไฟ
Abilities.FlameNova = function(ctx, a)
	cast(ctx, a, "Nova", 1.4, "วงแหวนเพลิง!")
	local base = ground(a.Root.Position)
	local center = tele(ctx, a, base, 24, 1.4)
	task.wait(1.4)
	if a.Dead then
		return
	end
	impact(ctx, a, center, 24, "Slam")
	fx(ctx, "BossSpikes", { Pos = center, Radius = 20, Count = 12, Element = "Fire", Ring = true })
	hitPlayers(ctx, center, 24, a.Info.Damage * a.DamageMult, a.Id, function()
		return { Burn = 8 }
	end)
	local g2 = tele(ctx, a, center, 48, 1.1)
	task.wait(1.1)
	if a.Dead then
		return
	end
	impact(ctx, a, g2, 48, "Slam")
	fx(ctx, "BossSpikes", { Pos = g2, Radius = 42, Count = 20, Element = "Fire", Ring = true })
	hitPlayers(ctx, g2, 48, a.Info.Damage * a.DamageMult * 0.6, a.Id, function()
		return { Burn = 6 }
	end)
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
		task.wait(0.6)
		a.Casting = false
		if a.Model and a.Model.Parent then
			a.Model:SetAttribute("Cast", nil)
		end
	end)
end

BossAbilities.ElementColor = ELEMENT_COLOR
return BossAbilities
