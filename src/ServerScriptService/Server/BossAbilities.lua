--[[
	BossAbilities — สกิลบอส (บอสไม่ตีประชิด ใช้สกิลอย่างเดียว)
	ทุกท่า: บอสเล่นท่าร่าย (attribute Cast/CastAt/CastTime -> BossAnimator) + วงเตือนบนพื้น (BossFX) -> หลบให้พ้น!
	เอฟเฟกต์ทั้งหมดวาดฝั่ง client ผ่าน HitFx (BossTelegraph / BossImpact / BossSpikes / BossWave / BossBreath / BossBlizzard)
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local BossAbilities = {}

-- ตัวคูณเวลาร่าย (ง้าง/วงเตือน) ของบอสตัวนี้
local function slow(a)
	return a.Info.CastMult or Config.BossCastMult
end

-- ดาเมจสกิลบอส = ตัวเลขตามระดับ (Animals.SkillDamage: Light/Medium/Heavy) x a.DamageMult (= Nights.BossDamageMult ตามจำนวนคน)
--   ระดับตั้งต้นของแต่ละท่า (บอสเปลี่ยนเองได้ด้วย Animals.SkillTier)
local TIER = {
	Quake = "Heavy", Fissure = "Medium", BoulderRain = "Light",
	TidalWave = "Medium", WaterSpout = "Light",
	Blizzard = "Heavy", IceSpikes = "Medium",
	FlameNova = "Heavy", FireBreath = "Medium", MeteorRoar = "Light",
	AbyssCharge = "Heavy", AvalancheLeap = "Heavy", WaterMissiles = "Light",
}
local function skillDamage(a, name, tier)
	local info = a.Info
	tier = tier or (info.SkillTier and info.SkillTier[name]) or TIER[name] or "Medium"
	local t = info.SkillDamage
	return (t and t[tier] or info.Damage) * (a.DamageMult or 1)
end

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
	fx(ctx, "BossSkillFx", { Skill = "Charge", Model = m, Element = a.Info.Element, Time = windup })
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

-- สกิลแนวตรง: หันเข้าหาเป้าก่อน (รอสูงสุด maxWait วินาทีจนหน้าตรง) แล้วล็อกทิศไว้จนจบสกิล
--   (เดิมทิศสกิลล็อกตั้งแต่เริ่ม แต่ตัวบอสหมุนตามผู้เล่นต่อ -> ปากพ่นไฟ/คลื่นไม่ตรงแนวที่เตือน)
local function aim(a, target, maxWait)
	local dir = flatDir(a, target)
	a.CastFace = dir
	local t0 = os.clock()
	while os.clock() - t0 < (maxWait or 0.6) and not a.Dead do
		local fw = a.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if fw.Magnitude > 0.1 and fw.Unit:Dot(dir) > 0.966 then -- ~15°
			break
		end
		task.wait(0.05)
	end
	return dir
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
local chillRef -- (ตั้งค่าด้านล่าง: chill)
local lavaPoolRef

-- ผู้เล่นในวงแหวน (rIn < ระยะ <= rOut) — คลื่นกระแทกหลายชั้น
local function hitRing(ctx, center, rIn, rOut, damage, source, opts)
	local surv = ctx.Services.SurvivalService
	local hit = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r then
			local d = ((r.Position - center) * Vector3.new(1, 0, 1)).Magnitude
			if d <= rOut and d > rIn and math.abs(r.Position.Y - center.Y) < 22 then
				surv:Damage(p, damage, source, opts and opts(p, r))
				table.insert(hit, p)
			end
		end
	end
	return hit
end

-- วงเตือนแบบวงแหวน (ข้างในปลอดภัย) · Inner = 0 -> วงเต็ม
local function teleRing(ctx, a, pos, rIn, rOut, time)
	local g = ground(pos)
	fx(ctx, "BossTelegraph", { Pos = g, Radius = rOut, Inner = rIn > 0 and rIn or nil, Time = time, Element = a.Info.Element })
	return g
end

local function knockAway(center, power, up)
	return function(_, r)
		local away = (r.Position - center) * Vector3.new(1, 0, 1)
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
		return { Knockback = away * power + Vector3.new(0, up, 0) }
	end
end

-- หมุนทิศแนวราบ (องศา)
local function turn(dir, deg)
	local r = math.rad(deg)
	local c, s = math.cos(r), math.sin(r)
	return Vector3.new(dir.X * c - dir.Z * s, 0, dir.X * s + dir.Z * c)
end

---------------------------------------------------------------- ทุกธาตุ
-- ทุบพื้นสะเทือนแผ่นดิน: คลื่นกระแทก 3 ชั้นแผ่ออกเป็นระลอก (ชั้นในสุดแรงสุด) — หนีออกนอกวง หรือรอระลอกผ่านแล้ววิ่งสวนเข้าไป
Abilities.Quake = function(ctx, a)
	local r1 = 44 + a.Radius * 0.6
	local radii = { r1, r1 * 1.75, r1 * 2.5 }
	local windup = 1.5 * slow(a)
	cast(ctx, a, "Slam", windup, ({ Earth = "Tectonic Slam!", Air = "Glacier Quake!", Water = "Tsunami Slam!", Fire = "Magma Quake!" })[a.Info.Element] or "Ground Smash!")
	local center = ground(a.Root.Position)
	for k, rr in ipairs(radii) do
		teleRing(ctx, a, center, k == 1 and 0 or radii[k - 1], rr, windup + (k - 1) * 0.5)
	end
	task.wait(windup)
	for k, rr in ipairs(radii) do
		if a.Dead then
			return
		end
		local rIn = k == 1 and -1 or radii[k - 1]
		impact(ctx, a, center, rr, k == 1 and "Slam" or "Ring")
		fx(ctx, "BossSkillFx", { Skill = "Quake", Pos = center, Radius = rr, Wave = k, Element = a.Info.Element })
		fx(ctx, "BossSpikes", { Pos = center, Radius = rr * 0.92, Count = 12 + k * 6, Element = a.Info.Element, Ring = true })
		hitRing(ctx, center, rIn, rr, skillDamage(a, "Quake", k == 1 and "Heavy" or "Medium"), a.Id, knockAway(center, 80 - k * 10, 55))
		if k == 1 then
			ctx.FireRun("Cinematic", "Shake", { Power = 1.2, Time = 1.4 })
		end
		task.wait(0.5)
	end
end

---------------------------------------------------------------- โกเลม (ดิน)
-- รอยแยกสามแฉก: แผ่นดินแยกพุ่ง 3 แนว (แฉกกลางเล็งเป้า) หนามหินผุดตามแนว
Abilities.Fissure = function(ctx, a, target)
	local dir = aim(a, target, 0.7)
	local length, width, windup = 175, 22, 1.2 * slow(a)
	cast(ctx, a, "Slam", windup, "Triple Earth Rift!")
	local lines = {}
	for _, deg in ipairs({ -28, 0, 28 }) do
		local d = turn(dir, deg)
		local from = ground(a.Root.Position + d * (a.Radius * 0.6))
		table.insert(lines, { from, d })
		fx(ctx, "BossTelegraph", { Pos = from, Dir = d, Length = length, Width = width, Time = windup, Element = a.Info.Element, Shape = "Line" })
	end
	task.wait(windup)
	if a.Dead then
		return
	end
	impact(ctx, a, ground(a.Root.Position), 26, "Slam")
	ctx.FireRun("Cinematic", "Shake", { Power = 0.9, Time = 1.2 })
	for _, ln in ipairs(lines) do
		fx(ctx, "BossSkillFx", { Skill = "Fissure", Pos = ln[1], Dir = ln[2], Length = length })
	end
	local hitSet = {}
	for i = 0, 14 do
		for _, ln in ipairs(lines) do
			local p = ground(ln[1] + ln[2] * (i * length / 14))
			fx(ctx, "BossSpikes", { Pos = p, Radius = width * 0.5, Count = 5, Element = a.Info.Element })
			for _, pl in ipairs(Players:GetPlayers()) do
				local r = charRoot(pl)
				if r and not hitSet[pl] and ((r.Position - p) * Vector3.new(1, 0, 1)).Magnitude < width * 0.6 then
					hitSet[pl] = true
					ctx.Services.SurvivalService:Damage(pl, skillDamage(a, "Fissure"), a.Id, { Knockback = Vector3.new(0, 90, 0) + ln[2] * 25 })
				end
			end
		end
		task.wait(0.05)
	end
end

-- ฝนหิน/อุกกาบาต: ของหล่นจากฟ้าใส่ผู้เล่น + กระจายทั่วลาน (วงเตือนก่อนตก)
local function rain(ctx, a, count, radius, damage, color, fire, size, spread)
	local combat = ctx.Services.CombatService
	local targets = playersNear(a, 200)
	if #targets == 0 then
		return
	end
	local rng = Random.new()
	spread = spread or 40
	for i = 1, count do
		local base = targets[(i - 1) % #targets + 1].Position
		local pos
		if i <= #targets then
			pos = base -- ลูกแรกของแต่ละคน = ตรงตัว
		elseif i % 3 == 0 then
			-- บางลูกตกรอบตัวบอสทั่วลาน (หลบเข้าใกล้บอสก็ไม่รอด)
			local ang = rng:NextNumber(0, math.pi * 2)
			pos = a.Root.Position + Vector3.new(math.cos(ang), 0, math.sin(ang)) * rng:NextNumber(20, 95)
		else
			pos = base + Vector3.new(rng:NextNumber(-spread, spread), 0, rng:NextNumber(-spread, spread))
		end
		local delay = 1.5 * slow(a) + i * 0.12
		local g = tele(ctx, a, pos, radius, delay)
		local from = g + Vector3.new(rng:NextNumber(-50, 50), 190, rng:NextNumber(-50, 50))
		local grav = 80
		local vel = (g - from) / delay + Vector3.new(0, 0.5 * grav * delay, 0)
		combat:Projectile({
			From = from, Velocity = vel, Gravity = grav, Radius = 0.1, Blast = radius, Damage = damage,
			Owner = "Animal", Color = color, Size = size or 6, Fire = fire, Source = a.Id, Life = delay + 1,
			Model = (not fire) and "Rock" or nil, VFX = fire and "Meteor" or "Boulder", -- อุกกาบาตไฟ = ลูกไฟ (ไม่ใช่ก้อนหิน)
			OnImpact = fire and function(pos)
				lavaPoolRef(ctx, a, pos, radius * 0.7, 4, damage * 0.2) -- มังกร: ตกแล้วทิ้งบ่อลาวาไหม้พื้น 4 วิ
			end or nil,
		})
		task.delay(delay, function()
			impact(ctx, a, g, radius, "Small")
		end)
	end
end

---------------------------------------------------------------- มังกร (ไฟ)
-- ฝนอุกกาบาต: 20 ลูกทั่วลาน
Abilities.MeteorRoar = function(ctx, a)
	cast(ctx, a, "Roar", 1.5 * slow(a), "Meteor Storm!")
	ctx.FireRun("Cinematic", "Shake", { Power = 0.8, Time = 2.2 * slow(a) })
	task.wait(0.4 * slow(a))
	rain(ctx, a, 20, 16, skillDamage(a, "MeteorRoar"), Color3.fromRGB(255, 120, 40), true, 9, 46)
end

---------------------------------------------------------------- โมซาซอรัส (น้ำ)
-- คลื่นยักษ์สามสาย: กำแพงน้ำ 3 สายแผ่เป็นพัด (สายกลางเล็งเป้า)
Abilities.TidalWave = function(ctx, a, target)
	local dir = aim(a, target, 0.7)
	local length, width, windup, travel = 200, 46, 1.3 * slow(a), 1.7
	cast(ctx, a, "Rear", windup, "Triple Tidal Wave!")
	local lines = {}
	for _, deg in ipairs({ -34, 0, 34 }) do
		local d = turn(dir, deg)
		local from = ground(a.Root.Position + d * (a.Radius * 0.5))
		table.insert(lines, { from, d })
		fx(ctx, "BossTelegraph", { Pos = from, Dir = d, Length = length, Width = width, Time = windup, Element = a.Info.Element, Shape = "Line" })
	end
	task.wait(windup)
	if a.Dead then
		return
	end
	impact(ctx, a, ground(a.Root.Position), 30, "Slam")
	ctx.FireRun("Cinematic", "Shake", { Power = 0.9, Time = 1.6 })
	local hitSet = {}
	for _, ln in ipairs(lines) do
		local from, d = ln[1], ln[2]
		fx(ctx, "BossWave", { Pos = from, Dir = d, Length = length, Width = width, Time = travel, Element = a.Info.Element })
		fx(ctx, "BossSkillFx", { Skill = "Tidal", Pos = from, Dir = d, Length = length, Width = width })
		for _, p in ipairs(Players:GetPlayers()) do
			local r = charRoot(p)
			if r and not hitSet[p] then
				local inside, along = inLine(r, from, d, length, width)
				if inside then
					hitSet[p] = true
					task.delay(math.max(0, along / length * travel), function()
						local r2 = charRoot(p)
						if r2 and inLine(r2, from, d, length, width) and not a.Dead then
							ctx.Services.SurvivalService:Damage(p, skillDamage(a, "TidalWave"), a.Id, { Knockback = d * 110 + Vector3.new(0, 45, 0) })
						end
					end)
				end
			end
		end
	end
end

-- น้ำวนมหาสมุทร: ดูดทุกคนเข้าหาบอส -> พวยน้ำยักษ์ระเบิดรอบตัว + พวยน้ำผุดใต้เท้าทุกคน 5 จุด
Abilities.WaterSpout = function(ctx, a)
	local t = 1.6 * slow(a)
	cast(ctx, a, "Roar", t, "Maelstrom!")
	local center = ground(a.Root.Position)
	local core = 30 + a.Radius * 0.4
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r and (r.Position - center).Magnitude < 120 then
			ctx.Remotes.Get("HitFx"):FireClient(p, "Pull", { Center = center, Time = t * 0.7, Stop = core + 8 })
		end
	end
	local g0 = tele(ctx, a, center, core, t)
	fx(ctx, "BossSkillFx", { Skill = "Maelstrom", Pos = g0, Radius = core, Time = t })
	for _, r in ipairs(playersNear(a, 200)) do
		local spots = { r.Position }
		for k = 1, 4 do
			table.insert(spots, r.Position + Vector3.new(math.cos(k * 1.57 + 0.4) * 22, 0, math.sin(k * 1.57 + 0.4) * 22))
		end
		for i, pos in ipairs(spots) do
			local delay = t + i * 0.18
			local g = tele(ctx, a, pos, 14, delay)
			task.delay(delay, function()
				if a.Dead then
					return
				end
				impact(ctx, a, g, 14, "Geyser")
				local hit = hitPlayers(ctx, g, 14, skillDamage(a, "WaterSpout"), a.Id)
				for _, hp in ipairs(hit) do
					ctx.Remotes.Get("HitFx"):FireClient(hp, "Launch", { Velocity = Vector3.new(0, 130, 0) })
				end
			end)
		end
	end
	task.wait(t)
	if a.Dead then
		return
	end
	impact(ctx, a, g0, core, "Geyser")
	impact(ctx, a, g0, core * 1.4, "Ring")
	hitPlayers(ctx, g0, core, skillDamage(a, "WaterSpout", "Medium"), a.Id, knockAway(g0, 90, 70))
end

---------------------------------------------------------------- เยติ (น้ำแข็ง)
-- พายุหิมะ: ดูดเข้าหาตัว -> ระเบิดน้ำแข็งวงใหญ่ -> เศษน้ำแข็งระลอกสองแผ่ออกไปไกล
Abilities.Blizzard = function(ctx, a)
	local windup = 2.2 * slow(a)
	cast(ctx, a, "Roar", windup, "Absolute Blizzard!")
	local center = ground(a.Root.Position)
	fx(ctx, "BossBlizzard", { Pos = center, Radius = 80, Time = windup + 0.6, Element = a.Info.Element })
	for _, p in ipairs(Players:GetPlayers()) do
		local r = charRoot(p)
		if r and (r.Position - center).Magnitude < 130 then
			ctx.Remotes.Get("HitFx"):FireClient(p, "Pull", { Center = center, Time = windup, Stop = a.Radius + 10 })
		end
	end
	local radius = 40 + a.Radius * 0.5
	local outer = radius * 2.1
	local g = tele(ctx, a, center, radius, windup)
	teleRing(ctx, a, center, radius, outer, windup + 0.7)
	task.wait(windup)
	if a.Dead then
		return
	end
	impact(ctx, a, g, radius, "Slam")
	fx(ctx, "BossSkillFx", { Skill = "Frost", Pos = g, Radius = radius })
	fx(ctx, "BossSpikes", { Pos = g, Radius = radius * 0.85, Count = 20, Element = a.Info.Element, Ring = true })
	ctx.FireRun("Cinematic", "Shake", { Power = 1.1, Time = 1.2 })
	for _, p in ipairs(hitPlayers(ctx, g, radius, skillDamage(a, "Blizzard"), a.Id, function()
		return { Knockback = Vector3.new(0, 95, 0) }
	end)) do
		chillRef(p, 0.5, 3)
	end
	task.wait(0.7)
	if a.Dead then
		return
	end
	impact(ctx, a, g, outer, "Ring")
	fx(ctx, "BossSkillFx", { Skill = "Frost", Pos = g, Radius = outer })
	fx(ctx, "BossSpikes", { Pos = g, Radius = outer * 0.9, Count = 28, Element = a.Info.Element, Ring = true })
	hitRing(ctx, g, radius, outer, skillDamage(a, "Blizzard", "Light"), a.Id, knockAway(g, 70, 40))
end

-- ทุ่งหอกน้ำแข็ง: หนามผุดใต้เท้า 3 วงซ้อน (กลาง -> 5 จุด -> 7 จุด) ไล่ระเบิดออกไป
Abilities.IceSpikes = function(ctx, a)
	local base = 1.2 * slow(a)
	cast(ctx, a, "Slam", base, "Glacial Lances!")
	for _, r in ipairs(playersNear(a, 200)) do
		local spots = { { r.Position, 0 } }
		for k = 1, 5 do
			table.insert(spots, { r.Position + Vector3.new(math.cos(k / 5 * math.pi * 2) * 16, 0, math.sin(k / 5 * math.pi * 2) * 16), 1 })
		end
		for k = 1, 7 do
			table.insert(spots, { r.Position + Vector3.new(math.cos(k / 7 * math.pi * 2 + 0.3) * 31, 0, math.sin(k / 7 * math.pi * 2 + 0.3) * 31), 2 })
		end
		for _, sp in ipairs(spots) do
			local delay = base + sp[2] * 0.35
			local g = tele(ctx, a, sp[1], 11, delay)
			task.delay(delay, function()
				if a.Dead then
					return
				end
				fx(ctx, "BossSpikes", { Pos = g, Radius = 7, Count = 8, Element = a.Info.Element })
				fx(ctx, "BossSkillFx", { Skill = "Lances", Pos = g, Radius = 11 })
				impact(ctx, a, g, 11, "Small")
				for _, p in ipairs(hitPlayers(ctx, g, 11, skillDamage(a, "IceSpikes"), a.Id, function()
					return { Knockback = Vector3.new(0, 105, 0) }
				end)) do
					chillRef(p, 0.6, 2)
				end
			end)
		end
	end
end

---------------------------------------------------------------- มังกร (ไฟ)
-- พ่นไฟกวาด 3 ทิศ (ซ้าย -> กลาง -> ขวา) เป็นแนวยาว · โดนต่อเนื่อง + ติดไฟ
Abilities.FireBreath = function(ctx, a, target)
	local dir = aim(a, target, 0.7)
	local from = ground(a.Root.Position)
	local length, width, windup = 165, 32, 1.1 * slow(a)
	cast(ctx, a, "Breath", windup, "Inferno Sweep!")
	local sweeps = { turn(dir, -30), dir, turn(dir, 30) }
	for i, d in ipairs(sweeps) do
		fx(ctx, "BossTelegraph", { Pos = from, Dir = d, Length = length, Width = width, Time = windup + (i - 1) * 0.75, Element = a.Info.Element, Shape = "Line" })
	end
	task.wait(windup)
	for _, d in ipairs(sweeps) do
		if a.Dead then
			return
		end
		a.CastFace = d
		fx(ctx, "BossBreath", { Model = a.Model, To = ground(from + d * length * 0.8), Pos = from, Dir = d, Length = length, Time = 0.75 })
		fx(ctx, "BossSkillFx", { Skill = "Breath", Pos = from, Dir = d, Length = length })
		for _ = 1, 3 do
			for _, p in ipairs(Players:GetPlayers()) do
				local r = charRoot(p)
				if r and inLine(r, from, d, length, width) then
					ctx.Services.SurvivalService:Damage(p, skillDamage(a, "FireBreath") / 3, a.Id, { Burn = 6 })
				end
			end
			task.wait(0.25)
		end
	end
end

-- วงแหวนนรก 3 ชั้น: ระเบิดไฟใกล้ตัว -> กลาง -> ไกล สลับกันไป (ยืนถูกจังหวะ = รอด)
Abilities.FlameNova = function(ctx, a)
	local w1 = 1.4 * slow(a)
	cast(ctx, a, "Nova", w1, "Ring of Inferno!")
	local center = ground(a.Root.Position)
	local radii = { 32, 64, 98 }
	local tiers = { "Heavy", "Medium", "Light" }
	for k, rr in ipairs(radii) do
		teleRing(ctx, a, center, k == 1 and 0 or radii[k - 1], rr, w1 + (k - 1) * 0.7)
	end
	task.wait(w1)
	for k, rr in ipairs(radii) do
		if a.Dead then
			return
		end
		local rIn = k == 1 and -1 or radii[k - 1]
		impact(ctx, a, center, rr, k == 1 and "Slam" or "Ring")
		fx(ctx, "BossSkillFx", { Skill = "Inferno", Pos = center, Radius = rr, Wave = k })
		fx(ctx, "BossSpikes", { Pos = center, Radius = rr * 0.9, Count = 12 + k * 8, Element = "Fire", Ring = true })
		hitRing(ctx, center, rIn, rr, skillDamage(a, "FlameNova", tiers[k]), a.Id, function()
			return { Burn = 8 }
		end)
		if k == 1 then
			ctx.FireRun("Cinematic", "Shake", { Power = 1.1, Time = 1.2 })
		end
		task.wait(0.7)
	end
end


---------------------------------------------------------------- กลไกเฉพาะตัวบอส (ไม่ใช่วงเตือนบนพื้นอย่างเดียว)
local RunService = game:GetService("RunService")

-- ทำให้ตัวเย็น (น้ำแข็ง): เดินช้าลงชั่วคราว (CombatClient อ่าน attribute "Chill")
local function chill(p, mult, dur)
	p:SetAttribute("Chill", mult)
	local token = os.clock()
	p:SetAttribute("ChillAt", token)
	task.delay(dur, function()
		if p.Parent and p:GetAttribute("ChillAt") == token then
			p:SetAttribute("Chill", nil)
		end
	end)
end

chillRef = function(p, m, d)
	chill(p, m, d)
end

-- ย้ายตัวบอสตามเส้นทาง (พุ่ง/กระโดด) · onStep(pos) ทุกเฟรม · arc = ความสูงโค้ง
local function moveBoss(a, dest, time, arc, onStep)
	local p0 = a.Root.Position
	local hOff = p0.Y - ground(p0).Y
	local to = ground(dest) + Vector3.new(0, hOff, 0)
	local flat = (to - p0) * Vector3.new(1, 0, 1)
	local rot = flat.Magnitude > 0.5 and CFrame.lookAt(Vector3.zero, flat.Unit) or (a.Root.CFrame - a.Root.Position)
	local pivotOff = a.Model:GetPivot().Position - p0
	local t0 = os.clock()
	while not a.Dead and a.Model.Parent do
		local u = math.min((os.clock() - t0) / time, 1)
		local pos = p0:Lerp(to, u) + Vector3.new(0, (arc or 0) * 4 * u * (1 - u), 0)
		a.Model:PivotTo(CFrame.new(pos + pivotOff) * rot)
		a.Root.AssemblyLinearVelocity = Vector3.zero
		if onStep then
			onStep(pos, u)
		end
		if u >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
end

-- จุดหมายไม่ให้หลุดลานรัง (บอสในรังมี Home + Leash)
local function inArena(a, pos)
	if not (a.Home and a.Leash) then
		return pos
	end
	local rel = (pos - a.Home) * Vector3.new(1, 0, 1)
	local maxR = a.Leash * 0.9
	if rel.Magnitude > maxR then
		return a.Home + rel.Unit * maxR + Vector3.new(0, pos.Y - a.Home.Y, 0)
	end
	return pos
end

-- บ่อลาวา (มังกร): พื้นไหม้อยู่ dur วินาที ยืนทับ = โดนไฟทุก 0.5 วิ
local function lavaPool(ctx, a, pos, r, dur, dmg)
	local g = ground(pos)
	fx(ctx, "BossSkillFx", { Skill = "LavaPool", Pos = g, Radius = r, Time = dur })
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < dur and not a.Dead do
			for _, p in ipairs(Players:GetPlayers()) do
				local rr = charRoot(p)
				if rr and ((rr.Position - g) * Vector3.new(1, 0, 1)).Magnitude < r and math.abs(rr.Position.Y - g.Y) < 8 then
					ctx.Services.SurvivalService:Damage(p, dmg, a.Id, { Burn = 4 })
				end
			end
			task.wait(0.5)
		end
	end)
end

lavaPoolRef = lavaPool

---------------------------------------------------------------- โกเลม: หินยักษ์กลิ้ง
-- หินยักษ์กลิ้งเป็นแนว 3 ลูกต่อคน (ตรงตัว + เฉียงซ้ายขวา) ทับใครกระเด็น · ตามด้วยฝนหินเล็ก
Abilities.BoulderRain = function(ctx, a, target)
	local w = 1.4 * slow(a)
	cast(ctx, a, "Summon", w, "Rolling Avalanche!")
	local lanes = {}
	for _, r in ipairs(playersNear(a, 200)) do
		local d0 = (r.Position - a.Root.Position) * Vector3.new(1, 0, 1)
		d0 = d0.Magnitude > 0.5 and d0.Unit or a.Root.CFrame.LookVector
		for _, deg in ipairs({ -22, 0, 22 }) do
			local d = turn(d0, deg)
			local from = ground(a.Root.Position + d * (a.Radius + 6))
			table.insert(lanes, { from, d })
			fx(ctx, "BossTelegraph", { Pos = from, Dir = d, Length = 160, Width = 18, Time = w, Element = a.Info.Element, Shape = "Line" })
		end
	end
	task.wait(w)
	if a.Dead then
		return
	end
	ctx.FireRun("Cinematic", "Shake", { Power = 0.8, Time = 2.2 })
	local dmg = skillDamage(a, "BoulderRain", "Medium")
	local folder = Workspace:FindFirstChild("FX") or Workspace
	for _, ln in ipairs(lanes) do
		fx(ctx, "BossSkillFx", { Skill = "Boulder", Pos = ln[1], Dir = ln[2], Length = 160, Speed = 58 })
		task.spawn(function()
			local rock = Instance.new("Part")
			rock.Shape = Enum.PartType.Ball
			rock.Size = Vector3.new(15, 15, 15)
			rock.Material = Enum.Material.Slate
			rock.Color = Color3.fromRGB(104, 92, 78)
			rock.Anchored, rock.CanCollide, rock.CanQuery, rock.CanTouch = true, false, false, false
			rock.Parent = folder
			local hitSet = {}
			local t0, speed, len = os.clock(), 58, 160
			local spin = 0
			while not a.Dead do
				local dist = math.min((os.clock() - t0) * speed, len)
				local pos = ground(ln[1] + ln[2] * dist) + Vector3.new(0, 7.5, 0)
				spin += 0.35
				rock.CFrame = CFrame.lookAt(pos, pos + ln[2]) * CFrame.Angles(-spin, 0, 0)
				for _, p in ipairs(Players:GetPlayers()) do
					local rr = charRoot(p)
					if rr and not hitSet[p] and (rr.Position - pos).Magnitude < 10 then
						hitSet[p] = true
						ctx.Services.SurvivalService:Damage(p, dmg, a.Id, { Knockback = ln[2] * 90 + Vector3.new(0, 45, 0) })
					end
				end
				if dist >= len then
					break
				end
				RunService.Heartbeat:Wait()
			end
			impact(ctx, a, rock.Position, 12, "Small")
			rock:Destroy()
		end)
	end
	task.wait(1.0)
	if not a.Dead then
		rain(ctx, a, 8, 12, skillDamage(a, "BoulderRain"), Color3.fromRGB(112, 98, 82), false, 8, 36)
	end
end

---------------------------------------------------------------- โมซาซอรัส: พุ่งชาร์จ 2 รอบ
-- เล็งแล้วพุ่งทั้งตัวข้ามลาน (แถบเตือนกว้างเท่าตัว) ทับใคร = เจ็บหนัก + กระเด็น · รอบสองเล็งใหม่เร็วกว่า
Abilities.AbyssCharge = function(ctx, a, target)
	cast(ctx, a, "Rear", 1.1 * slow(a), "Abyssal Charge!")
	for n = 1, 2 do
		if a.Dead then
			return
		end
		local dir = aim(a, target, 0.5)
		local start = a.Root.Position
		local dest = inArena(a, start + dir * 120)
		local len = ((dest - start) * Vector3.new(1, 0, 1)).Magnitude
		if len < 30 then
			dest = start + dir * 30
			len = 30
		end
		local width = math.max(18, a.Radius * 1.6)
		local w = (n == 1 and 1.1 or 0.75) * slow(a)
		fx(ctx, "BossTelegraph", { Pos = ground(start), Dir = dir, Length = len, Width = width, Time = w, Element = a.Info.Element, Shape = "Line" })
		task.wait(w)
		if a.Dead then
			return
		end
		impact(ctx, a, ground(start), 22, "Slam")
		fx(ctx, "BossWave", { Pos = ground(start), Dir = dir, Length = len, Width = width, Time = 0.6, Element = a.Info.Element })
		fx(ctx, "BossSkillFx", { Skill = "Charge2", Model = a.Model, Pos = ground(start), Dir = dir, Length = len, Width = width })
		local hitSet = {}
		moveBoss(a, dest, 0.6, 0, function(pos)
			for _, p in ipairs(Players:GetPlayers()) do
				local rr = charRoot(p)
				if rr and not hitSet[p] and ((rr.Position - pos) * Vector3.new(1, 0, 1)).Magnitude < width / 2 + 4 then
					hitSet[p] = true
					ctx.Services.SurvivalService:Damage(p, skillDamage(a, "AbyssCharge"), a.Id, { Knockback = dir * 120 + Vector3.new(0, 55, 0) })
				end
			end
		end)
		impact(ctx, a, ground(a.Root.Position), 26, "Geyser")
		ctx.FireRun("Cinematic", "Shake", { Power = 0.9, Time = 0.8 })
		task.wait(0.35)
	end
end


---------------------------------------------------------------- โมซาซอรัส: มิสไซล์บอลน้ำ
-- พ่นลูกบอลน้ำ 3 ชุด (คนละ 4 ลูก) พุ่งออกเป็นพัดแล้ว "เลี้ยวไล่" เป้า (เลี้ยวได้จำกัด -> วิ่ง/หักหลบทัน)
--   โดนตัว = เจ็บ + กระเด็น · ตกพื้น = น้ำระเบิดรอบจุดตก
Abilities.WaterMissiles = function(ctx, a, target)
	local w = 1.0 * slow(a)
	cast(ctx, a, "Roar", w, "Hydro Missiles!")
	task.wait(w)
	local dmg = skillDamage(a, "WaterMissiles") * 0.6
	local folder = Workspace:FindFirstChild("FX") or Workspace
	local surv = ctx.Services.SurvivalService
	for volley = 1, 3 do
		if a.Dead then
			return
		end
		fx(ctx, "BossImpact", { Pos = ground(a.Root.Position), Radius = 18, Element = "Water", Style = "Small" })
		for _, tr in ipairs(playersNear(a, 220)) do
			local victim = Players:GetPlayerFromCharacter(tr.Parent)
			for k = 1, 4 do
				task.spawn(function()
					local mouth = a.Root.Position + a.Root.CFrame.LookVector * (a.Radius * 0.6) + Vector3.new(0, a.Radius * 0.35 + 4, 0)
					local to = (tr.Position - mouth) * Vector3.new(1, 0, 1)
					to = to.Magnitude > 0.5 and to.Unit or a.Root.CFrame.LookVector
					local side = Vector3.new(-to.Z, 0, to.X) * ((k - 2.5) * 0.55)
					local vel = (to * 0.6 + side + Vector3.new(0, 0.75, 0)).Unit * 45
					local ball = Instance.new("Part")
					ball.Shape = Enum.PartType.Ball
					ball.Size = Vector3.new(5, 5, 5)
					ball.Material = Enum.Material.Glass
					ball.Color = Color3.fromRGB(80, 190, 255)
					ball.Transparency = 0.25
					ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
					ball:SetAttribute("VFX", "WaterBall")
					ball.CFrame = CFrame.new(mouth)
					ball.Parent = folder
					local pos, t0, speed = mouth, os.clock(), 45
					local hit = false
					while os.clock() - t0 < 4 and not a.Dead do
						local dt = RunService.Heartbeat:Wait()
						local goal = (victim and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")) or tr
						-- 0.3 วิแรกพุ่งออกเป็นพัด -> เลี้ยวไล่เป้า 4 rad/วิ ถึงวิที่ 1.1 แล้วพุ่งตรง
						--   (ยืนนิ่ง = โดน · วิ่งหนีด้านข้างทัน = หลบได้ — จำลองแล้ว)
						local age = os.clock() - t0
						if age > 0.3 and age < 1.1 and goal and goal.Parent then
							local want = (goal.Position - pos).Unit
							local cur = vel.Unit
							local ang = math.acos(math.clamp(cur:Dot(want), -1, 1))
							local maxTurn = 4 * dt
							local u = ang > 1e-3 and math.min(1, maxTurn / ang) or 1
							vel = cur:Lerp(want, u).Unit * speed
						end
						speed = math.min(speed + 25 * dt, 70)
						pos += vel * dt
						ball.CFrame = CFrame.lookAt(pos, pos + vel)
						for _, p in ipairs(Players:GetPlayers()) do
							local r = charRoot(p)
							if r and (r.Position - pos).Magnitude < 6 then
								surv:Damage(p, dmg, a.Id, { Knockback = vel.Unit * 60 + Vector3.new(0, 30, 0) })
								hit = true
							end
						end
						if hit or pos.Y < ground(pos).Y + 1 then
							break
						end
					end
					local at = ground(pos)
					if not hit then
						hitPlayers(ctx, at, 9, dmg, a.Id, knockAway(at, 50, 30))
					end
					fx(ctx, "BossImpact", { Pos = at, Radius = 9, Element = "Water", Style = "Small" })
					fx(ctx, "BossSkillFx", { Skill = "Splash", Pos = at })
					ball:Destroy()
				end)
				task.wait(0.08)
			end
		end
		task.wait(0.9)
	end
	task.wait(1.2)
end

---------------------------------------------------------------- เยติ: กระโดดทับ 2 รอบ
-- วงเตือนใต้เท้าเป้า -> กระโดดลอยข้ามมาทับ -> ระเบิดน้ำแข็ง (โดน = ตัวเย็นเดินช้า) -> เศษน้ำแข็งแผ่ระลอกสอง
Abilities.AvalancheLeap = function(ctx, a, target)
	for n = 1, 2 do
		if a.Dead then
			return
		end
		local tr = target and charRoot(target)
		local list = playersNear(a, 200)
		tr = tr or list[1]
		if not tr then
			return
		end
		local land = inArena(a, tr.Position)
		local r = 30 + a.Radius * 0.3
		local w = (n == 1 and 1.3 or 1.0) * slow(a)
		cast(ctx, a, "Slam", w, n == 1 and "Avalanche Leap!" or "Again!")
		local g = tele(ctx, a, land, r, w)
		teleRing(ctx, a, g, r, r * 1.9, w + 0.45)
		task.wait(w * 0.3)
		if a.Dead then
			return
		end
		fx(ctx, "BossSkillFx", { Skill = "Leap", Phase = "Up", Pos = ground(a.Root.Position) })
		moveBoss(a, g, w * 0.7, 55)
		if a.Dead then
			return
		end
		impact(ctx, a, g, r, "Slam")
		fx(ctx, "BossSkillFx", { Skill = "Leap", Pos = g, Radius = r })
		fx(ctx, "BossSpikes", { Pos = g, Radius = r * 0.85, Count = 18, Element = a.Info.Element, Ring = true })
		ctx.FireRun("Cinematic", "Shake", { Power = 1.2, Time = 1 })
		for _, p in ipairs(hitPlayers(ctx, g, r, skillDamage(a, "AvalancheLeap"), a.Id, knockAway(g, 70, 60))) do
			chill(p, 0.5, 3)
		end
		task.wait(0.45)
		if a.Dead then
			return
		end
		impact(ctx, a, g, r * 1.9, "Ring")
		for _, p in ipairs(hitRing(ctx, g, r, r * 1.9, skillDamage(a, "AvalancheLeap", "Light"), a.Id, knockAway(g, 55, 35))) do
			chill(p, 0.6, 2)
		end
		task.wait(0.3)
	end
end

-- ท่าถัดไปที่คูลดาวน์ครบแล้ว (วนตามลำดับ) · ไม่มีท่าพร้อม -> nil (รอ)
function BossAbilities.Pick(a, abilities)
	local now = os.clock()
	for k = 1, #abilities do
		local i = ((a.AbilityIndex or 0) + k - 1) % #abilities + 1
		if now >= ((a.SkillReady or {})[abilities[i]] or 0) then
			a.AbilityIndex = i
			return abilities[i]
		end
	end
	return nil
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
		-- นับหลังร่ายจบ: ท่านี้ติดคูลดาวน์ของตัวเอง + เว้นก่อนร่ายท่าถัดไป
		local now = os.clock()
		a.SkillReady = a.SkillReady or {}
		a.SkillReady[name] = now + Config.BossSkillCooldown
		a.NextAbility = math.max(a.NextAbility or 0, now + Config.BossSkillGap)
		a.Casting = false
		a.CastFace = nil
		if a.Model and a.Model.Parent then
			a.Model:SetAttribute("Cast", nil)
		end
	end)
end

BossAbilities.ElementColor = ELEMENT_COLOR
return BossAbilities
