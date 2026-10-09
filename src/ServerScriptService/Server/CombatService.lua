--[[
	CombatService — การโจมตีของผู้เล่น + ดาเมจใส่สัตว์ + กระสุน (ลูกไฟ/ลูกธนู/หินถล่ม)
	ธาตุแพ้ทาง: น้ำ > ไฟ > ลม > ดิน > น้ำ  (ชนะทาง x1.5 / แพ้ทาง x0.75)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Items = require(ReplicatedStorage.Shared.Items)

local CombatService = {}

local BEATS = { Water = "Fire", Fire = "Air", Air = "Earth", Earth = "Water" }
local projectiles = {}

function CombatService:Init(ctx)
	self.ctx = ctx
	self.lastAttack = {}
	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Exclude
end

function CombatService.ElementMult(weaponElement, targetElement)
	if not weaponElement or not targetElement or targetElement == "None" then
		return 1
	end
	if weaponElement == "All" then
		return 1.25
	end
	if BEATS[weaponElement] == targetElement then
		return 1.5
	elseif BEATS[targetElement] == weaponElement then
		return 0.75
	end
	return 1
end

local function equippedTool(player)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if tool then
		local id = tool:GetAttribute("ItemId")
		return id, Items.Tools[id], tool
	end
	return nil
end
CombatService.EquippedTool = equippedTool

-- ดาเมจใส่สัตว์ (a = ข้อมูลสัตว์จาก AnimalService)
function CombatService:DamageAnimal(a, amount, attacker, opts)
	opts = opts or {}
	self.ctx.Services.AnimalService:TakeDamage(a, amount, attacker, opts)
end

function CombatService:PlayerDamage(player, toolId, tool, target)
	local surv = self.ctx.Services.SurvivalService
	local dmg = tool.Damage * surv:Perk(player, "DamageMult", 1)
	local mult = CombatService.ElementMult(tool.Element, target.Info.Element)
	if tool.Element then
		dmg *= surv:Perk(player, "ElementDamageMult", 1)
	end
	local crit = math.random() < 0.1
	if crit then
		dmg *= 1.6
	end
	return dmg * mult, crit, mult
end

function CombatService:Melee(player, toolId, tool, root, aim)
	local animals = self.ctx.Services.AnimalService
	-- ทิศฟัน = ทิศที่ผู้เล่นเล็ง (กล้อง/เมาส์) ถ้าส่งมาถูกต้อง ไม่งั้นใช้ทิศที่ตัวหัน
	local look = root.CFrame.LookVector
	if typeof(aim) == "Vector3" and aim.Magnitude > 0.5 then
		local flat = Vector3.new(aim.X, 0, aim.Z)
		if flat.Magnitude > 0.2 then
			look = flat.Unit
		end
	end
	local origin = root.Position
	local best, bestScore
	local hits = {}
	for _, a in ipairs(animals:InRadius(origin, tool.Range + 10, false)) do
		if a.Kind ~= "Spirit" and not a.Dead then
			local offset = a.Root.Position - origin
			local reach = tool.Range + a.Radius
			local flat = offset * Vector3.new(1, 0.4, 1)
			local d = flat.Magnitude
			if d <= reach then
				local dot = d > 0.1 and look:Dot(flat.Unit) or 1
				if dot > 0.15 or d < a.Radius + 3 then
					local score = d - dot * 4
					if not bestScore or score < bestScore then
						best, bestScore = a, score
					end
					table.insert(hits, a)
				end
			end
		end
	end
	if best then
		local targets = tool.Aoe and hits or { best }
		for _, a in ipairs(targets) do
			local dmg, crit, mult = self:PlayerDamage(player, toolId, tool, a)
			self:DamageAnimal(a, dmg, player, { Burn = tool.Burn, Slow = tool.Slow, Crit = crit, Mult = mult, Knock = look })
		end
		if tool.Aoe then
			self.ctx.Remotes.Get("HitFx"):FireAllClients("Slam", { Position = best.Root.Position, Radius = tool.Aoe, Element = tool.Element })
		end
		return true
	end
	-- ไม่โดนสัตว์ -> ตัดไม้/ทุบหิน
	local node = self.ctx.Services.ResourceService:FindNode(origin + look * 3.5, math.max(tool.Range * 0.75, 7))
	if node then
		return self.ctx.Services.ResourceService:Hit(player, node, tool)
	end
	return false
end

function CombatService:Shoot(player, toolId, tool, aim, char)
	local head = char:FindFirstChild("Head")
	if not head then
		return
	end
	local origin = head.Position + aim * 2
	local exclude = { char }
	local pierce = tool.Pierce or 1
	local hitPos = origin + aim * tool.Range
	local hitCount = 0
	local from = origin
	for _ = 1, pierce + 2 do
		self.rayParams.FilterDescendantsInstances = exclude
		local res = Workspace:Raycast(from, aim * tool.Range, self.rayParams)
		if not res then
			break
		end
		hitPos = res.Position
		local model = res.Instance:FindFirstAncestorWhichIsA("Model")
		local a = model and self.ctx.Services.AnimalService:Get(model)
		if a and a.Kind ~= "Spirit" then
			local dmg, crit, mult = self:PlayerDamage(player, toolId, tool, a)
			self:DamageAnimal(a, dmg, player, { Crit = crit, Mult = mult, Knock = aim })
			hitCount += 1
			table.insert(exclude, model)
			from = res.Position
			if hitCount >= pierce then
				break
			end
		else
			break
		end
	end
	self.ctx.Remotes.Get("HitFx"):FireAllClients("Arrow", { From = origin, To = hitPos, Element = tool.Element, Player = player })
end

function CombatService:OnAttack(player, aim)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local surv = self.ctx.Services.SurvivalService
	if not root or not surv:IsAlive(player) then
		return
	end
	local toolId, tool = equippedTool(player)
	if not tool then
		return
	end
	local now = os.clock()
	if now - (self.lastAttack[player] or 0) < tool.Cooldown * 0.85 then
		return
	end
	self.lastAttack[player] = now
	if tool.Kind == "Bow" then
		if typeof(aim) ~= "Vector3" or aim.Magnitude < 0.5 then
			return
		end
		self:Shoot(player, toolId, tool, aim.Unit, char)
	else
		self:Melee(player, toolId, tool, root, aim)
	end
end

---------------------------------------------------------------- กระสุนฝั่ง server
--[[
	Projectile({
		From, Velocity (Vector3), Gravity (number), Radius (ชน), Damage, Owner ("Animal"/"Player"),
		Color, Size, Burn, OnImpact(position), Life
	})
]]
-- ก้อนหินจริง (โมเดล RockLP) สำหรับหินถล่ม/อุกกาบาต
local function rockPart(size)
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local pack = assets and assets:FindFirstChild("Props") and assets.Props:FindFirstChild("RockLP")
	local list = {}
	for _, d in ipairs(pack and pack:GetDescendants() or {}) do
		if d:IsA("MeshPart") then
			table.insert(list, d)
		end
	end
	if #list == 0 then
		return nil
	end
	local r = list[math.random(1, #list)]:Clone()
	r:ClearAllChildren()
	local k = size / math.max(r.Size.X, r.Size.Y, r.Size.Z)
	r.Size *= k
	return r
end

function CombatService:Projectile(spec)
	local p = spec.Model == "Rock" and rockPart(spec.Size or 2)
	if p then
		p.Color = spec.Color or Color3.fromRGB(110, 100, 90)
		p.Material = spec.Fire and Enum.Material.Basalt or Enum.Material.Slate
		if spec.VFX then
			p:SetAttribute("VFX", spec.VFX)
		end
	else
		p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(spec.Size or 2, spec.Size or 2, spec.Size or 2)
		p.Material = Enum.Material.Neon
	end
	p.Color = spec.Model == "Rock" and p.Color or (spec.Color or Color3.fromRGB(255, 120, 30))
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CFrame = CFrame.new(spec.From)
	local l = Instance.new("PointLight")
	l.Color = p.Color
	l.Range = 14
	l.Brightness = 2
	l.Parent = p
	if spec.Fire and spec.Model ~= "Rock" then
		local f = Instance.new("Fire")
		f.Size = (spec.Size or 2) * 1.5
		f.Heat = 4
		f.Parent = p
	end
	local trail = Instance.new("ParticleEmitter")
	trail.Enabled = spec.Model ~= "Rock" -- ก้อนหินใช้เอฟเฟกต์ฝั่ง client แทน
	trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	trail.Rate = 40
	trail.Lifetime = NumberRange.new(0.4, 0.7)
	trail.Speed = NumberRange.new(0, 1)
	trail.LightEmission = 1
	trail.Size = NumberSequence.new((spec.Size or 2) * 0.6, 0)
	trail.Color = ColorSequence.new(p.Color)
	trail.Parent = p
	p.Parent = Workspace:FindFirstChild("FX") or Workspace
	table.insert(projectiles, {
		Part = p, Pos = spec.From, Vel = spec.Velocity, Gravity = spec.Gravity or 0, Spec = spec,
		Die = os.clock() + (spec.Life or 5),
	})
end

function CombatService:StepProjectiles(dt)
	local surv = self.ctx.Services.SurvivalService
	local terrainParams = RaycastParams.new()
	terrainParams.FilterType = Enum.RaycastFilterType.Include
	terrainParams.FilterDescendantsInstances = { Workspace.Terrain, self.ctx.Services.BuildingService.folder }
	for i = #projectiles, 1, -1 do
		local pr = projectiles[i]
		local spec = pr.Spec
		pr.Vel += Vector3.new(0, -pr.Gravity * dt, 0)
		local step = pr.Vel * dt
		local res = Workspace:Raycast(pr.Pos, step, terrainParams)
		local newPos = res and res.Position or pr.Pos + step
		local impact = res ~= nil or os.clock() > pr.Die
		-- ชนผู้เล่น
		if not impact and spec.Owner == "Animal" then
			for _, player in ipairs(Players:GetPlayers()) do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - newPos).Magnitude < (spec.Radius or 3) then
					impact = true
					break
				end
			end
		end
		pr.Pos = newPos
		pr.Part.CFrame = CFrame.new(newPos)
		if impact then
			table.remove(projectiles, i)
			pr.Part:Destroy()
			local blast = spec.Blast or 6
			if spec.Owner == "Animal" then
				for _, player in ipairs(Players:GetPlayers()) do
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root and (root.Position - newPos).Magnitude < blast then
						surv:Damage(player, spec.Damage, spec.Source or "Projectile", { Burn = spec.Burn })
					end
				end
				local building = self.ctx.Services.BuildingService
				for _, s in ipairs(building:All()) do
					if (s:GetPivot().Position - newPos).Magnitude < blast + 3 then
						building:Damage(s, spec.Damage * 0.5)
					end
				end
			end
			self.ctx.Remotes.Get("HitFx"):FireAllClients("Explosion", { Position = newPos, Radius = blast, Color = pr.Part.Color })
			if spec.OnImpact then
				task.spawn(spec.OnImpact, newPos)
			end
		end
	end
end

function CombatService:Start(ctx)
	local fx = Instance.new("Folder")
	fx.Name = "FX"
	fx.Parent = Workspace
	ctx.Remotes.Get("Attack").OnServerEvent:Connect(function(player, aim)
		self:OnAttack(player, aim)
	end)
	RunService.Heartbeat:Connect(function(dt)
		if #projectiles > 0 then
			self:StepProjectiles(dt)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		self.lastAttack[p] = nil
	end)
end

return CombatService
