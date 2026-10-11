--[[
	PingService — ปิงบอกเพื่อนร่วมทีม (กด G / ปุ่มบนจอมือถือ)
	  client ส่งจุดที่เล็ง + ของที่เล็งโดน -> server ตรวจ (จำกัด 1 ครั้ง / 1.5 วิ) แล้วตัดสินชนิดปิงเอง:
	    Enemy (แดง)  = เล็งโดนสัตว์
	    Item  (เหลือง) = เล็งโดนของบนพื้น / หีบ
	    Go    (ฟ้า)   = "มาที่นี่"
	  ส่งต่อให้ทุกคนที่อยู่ในรอบเดียวกัน (รวมคนปิง)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PingService = {}
PingService.Cooldown = 1.5
PingService.MaxDistance = 2500

function PingService:Init(ctx)
	self.ctx = ctx
	self.last = {}
end

-- ลูกโดยตรงของ folder ที่ inst อยู่ข้างใน (เช่น โมเดลสัตว์ใน Workspace.Animals)
local function topIn(folder, inst)
	if not (folder and inst:IsDescendantOf(folder)) then
		return nil
	end
	local m = inst
	while m.Parent and m.Parent ~= folder do
		m = m.Parent
	end
	return m
end

local function classify(target)
	if typeof(target) ~= "Instance" or not target:IsDescendantOf(Workspace) then
		return "Go", nil
	end
	local animal = topIn(Workspace:FindFirstChild("Animals"), target)
	if animal and animal:IsA("Model") then
		if animal:GetAttribute("Kind") == "Spirit" then
			return "Go", nil
		end
		return "Enemy", animal
	end
	local drop = topIn(Workspace:FindFirstChild("Drops"), target)
	if drop then
		return "Item", drop
	end
	local node = target
	while node and node ~= Workspace do
		if CollectionService:HasTag(node, "Chest") then
			return "Item", node
		end
		node = node.Parent
	end
	return "Go", nil
end

local function finite(v)
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e5 and math.abs(v.Y) < 1e5 and math.abs(v.Z) < 1e5
end

function PingService:Ping(player, position, target)
	if typeof(position) ~= "Vector3" or not finite(position) then
		return
	end
	if not player:GetAttribute("InRun") or player:GetAttribute("Dead") then
		return
	end
	local now = os.clock()
	if (self.last[player] or 0) > now - self.Cooldown then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - position).Magnitude > self.MaxDistance then
		return
	end
	self.last[player] = now
	local kind, model = classify(target)
	local data = { From = player.UserId, Name = player.DisplayName, Position = position, Kind = kind, Target = model }
	local remote = self.ctx.Remotes.Get("TeamPing")
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InRun") then
			remote:FireClient(p, data)
		end
	end
end

function PingService:Start(ctx)
	ctx.Remotes.Get("TeamPing").OnServerEvent:Connect(function(player, position, target)
		self:Ping(player, position, target)
	end)
	Players.PlayerRemoving:Connect(function(p)
		self.last[p] = nil
	end)
end

return PingService
