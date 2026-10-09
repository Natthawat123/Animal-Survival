--[[
	ResourceService — ของที่เก็บได้ในโลก (แท็ก ResourceNode จาก PropBuilder)
	ตี/ฟัน -> ได้ของตามดาเมจ -> หมดแล้ว (ต้นไม้ล้ม/หินแตก) -> งอกใหม่ภายหลัง
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Items = require(ReplicatedStorage.Shared.Items)

local ResourceService = {}

function ResourceService:Init(ctx)
	self.ctx = ctx
	self.overlap = OverlapParams.new()
	self.overlap.FilterType = Enum.RaycastFilterType.Include
end

-- หา node ใกล้จุดนั้นที่สุด
function ResourceService:FindNode(position, radius)
	local world = Workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	self.overlap.FilterDescendantsInstances = { world }
	local parts = Workspace:GetPartBoundsInRadius(position, radius, self.overlap)
	local best, bestD
	for _, p in ipairs(parts) do
		local node = p:FindFirstAncestorWhichIsA("Model")
		while node and not CollectionService:HasTag(node, "ResourceNode") do
			node = node.Parent and node.Parent:IsA("Model") and node.Parent or nil
		end
		if node and not node:GetAttribute("Depleted") then
			local d = (p.Position - position).Magnitude
			if not bestD or d < bestD then
				best, bestD = node, d
			end
		end
	end
	return best
end

local function setVisible(node, visible)
	for _, d in ipairs(node:GetDescendants()) do
		if d:IsA("BasePart") then
			if visible then
				d.Transparency = d:GetAttribute("OrigT") or 0
				d.CanCollide = d:GetAttribute("OrigC") ~= false
			else
				if d:GetAttribute("OrigT") == nil then
					d:SetAttribute("OrigT", d.Transparency)
					d:SetAttribute("OrigC", d.CanCollide)
				end
				d.Transparency = 1
				d.CanCollide = false
			end
			d.CanQuery = visible
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Fire") then
			d.Enabled = visible
		end
	end
end

function ResourceService:Fell(node, from)
	node:SetAttribute("Depleted", true)
	local kind = node:GetAttribute("Node")
	if kind == "Tree" then
		-- ต้นไม้ล้มไปทางตรงข้ามกับคนฟัน แล้วจางหาย
		local pivot = node:GetPivot()
		local dir = (pivot.Position - from) * Vector3.new(1, 0, 1)
		if dir.Magnitude < 0.1 then
			dir = Vector3.new(1, 0, 0)
		end
		dir = dir.Unit
		local axis = Vector3.new(0, 1, 0):Cross(dir)
		local value = Instance.new("NumberValue")
		value.Value = 0
		local conn = value.Changed:Connect(function(v)
			node:PivotTo(CFrame.fromAxisAngle(axis, math.rad(v)) * (pivot - pivot.Position) + pivot.Position)
		end)
		local tw = TweenService:Create(value, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 88 })
		tw:Play()
		self.ctx.Remotes.Get("HitFx"):FireAllClients("TreeFall", { Position = pivot.Position })
		task.delay(2.2, function()
			conn:Disconnect()
			value:Destroy()
			setVisible(node, false)
			node:PivotTo(pivot)
		end)
	else
		self.ctx.Remotes.Get("HitFx"):FireAllClients("Shatter", { Position = node:GetPivot().Position, Kind = kind })
		setVisible(node, false)
	end
	local regrow = node:GetAttribute("Regrow") or 240
	task.delay(regrow, function()
		if node.Parent then
			node:SetAttribute("HP", node:GetAttribute("MaxHP"))
			node:SetAttribute("Depleted", false)
			setVisible(node, true)
		end
	end)
end

-- ตี node: power = แรงของเครื่องมือ (Chop/Mine)
function ResourceService:Hit(player, node, tool)
	local kind = node:GetAttribute("Node")
	local surv = self.ctx.Services.SurvivalService
	local power
	if kind == "Tree" then
		power = (tool.Chop or 0) * surv:Perk(player, "ChopMult", 1)
	elseif kind == "Bush" then
		power = 1
	else
		power = (tool.Mine or 0) * surv:Perk(player, "MineMult", 1)
	end
	if power <= 0 then
		self.ctx.Notify(player, kind == "Tree" and "ต้องใช้ขวานตัดไม้" or "ต้องใช้ขวาน/อีเต้อทุบ", "Error")
		return false
	end
	local hp = node:GetAttribute("HP") or 1
	local dealt = math.min(hp, power)
	hp -= dealt
	node:SetAttribute("HP", hp)
	local yield = node:GetAttribute("Yield")
	local per = node:GetAttribute("YieldPerHP") or 1
	-- เก็บเศษไว้ (ทศนิยม) ต่อ node ต่อคน
	local key = "Frac_" .. player.UserId
	local amount = dealt * per + (node:GetAttribute(key) or 0)
	if kind == "Bush" then
		amount = (node:GetAttribute("Amount") or 2) + surv:Perk(player, "ExtraDrops", 0)
	end
	local whole = math.floor(amount)
	node:SetAttribute(key, amount - whole)
	if Items.Data[yield] and Items.Data[yield].Category == "Essence" then
		whole = math.floor(whole * surv:Perk(player, "EssenceMult", 1) + 0.5)
	end
	local drops = self.ctx.Services.DropService
	local nodePos = node:GetPivot().Position
	local toward = player.Character and player.Character:GetPivot().Position or nodePos
	local dropPos = nodePos + ((toward - nodePos) * Vector3.new(1, 0, 1)).Unit * 2.5
	if dropPos ~= dropPos then
		dropPos = nodePos
	end
	if whole > 0 then
		drops:Spawn(yield, whole, dropPos)
	end
	self.ctx.Remotes.Get("HitFx"):FireAllClients("NodeHit", { Position = node:GetPivot().Position, Kind = kind, Node = node })
	if hp <= 0 then
		local bonus = node:GetAttribute("Bonus")
		if bonus then
			drops:Spawn(bonus, kind == "Bush" and 1 or 2, dropPos)
		end
		if kind == "Tree" and yield == "Wood" then
			drops:Spawn("Wood", 2, nodePos, { Spread = 4 })
		end
		local pos = player.Character and player.Character:GetPivot().Position or node:GetPivot().Position
		self:Fell(node, pos)
	end
	return true
end

function ResourceService:Start(ctx) end

return ResourceService
