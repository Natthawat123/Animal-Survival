--[[
	AutoTool — สลับเครื่องมืออัตโนมัติ (ตั้งค่า: "สลับเครื่องมืออัตโนมัติ" ค่าเริ่มต้น = เปิด)
	  ตี/คลิกใส่ต้นไม้   -> ขวานที่ตัดไม้แรงที่สุด (Chop)
	  ตี/คลิกใส่หิน/แร่  -> อีเต้อ/เครื่องมือที่ขุดแรงที่สุด (Mine)
	  ตี/คลิกใส่สัตว์    -> อาวุธดาเมจสูงสุดที่ถึงระยะ (ไกลเกินระยะประชิด = เลือกเฉพาะธนู)
	  สลับเฉพาะเมื่อมีของที่ "ดีกว่า" ของในมือจริงๆ · มือเปล่าคลิกใส่เป้าก็หยิบให้เลย
	  ถือกระสอบ = ไม่ยุ่ง (คลิกใช้เก็บของ)
	CombatClient เรียก AutoTool.Before(tool) ก่อนตี -> ถ้าสลับให้แล้ว คืน true (CombatClient ตีด้วยของใหม่เอง)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))
local ClientSettings = require(script.Parent.ClientSettings)

local AutoTool = {}
AutoTool.Blocked = nil -- fn() -> true = ห้ามหยิบของตอนมือเปล่า (เช่น กำลังวางสิ่งก่อสร้าง)
local player = Players.LocalPlayer
local NODE_REACH = 16

local function enabled()
	return ClientSettings.Get("AutoTool") ~= false
end

-- จุดที่เล็ง (เมาส์ / นิ้วที่แตะ / กลางจอ)
local function aimRay(screenPos)
	local cam = Workspace.CurrentCamera
	local p = screenPos or UserInputService:GetMouseLocation()
	return cam:ViewportPointToRay(p.X, p.Y)
end

-- เป้าที่เล็งโดน: "Tree" / "Rock" / "Animal" + ระยะจากตัว
function AutoTool.Target(screenPos)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local ray = aimRay(screenPos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, Workspace.CurrentCamera }
	local res = Workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if not (res and res.Instance) then
		return nil
	end
	local dist = (res.Position - root.Position).Magnitude
	local animals = Workspace:FindFirstChild("Animals")
	if animals and res.Instance:IsDescendantOf(animals) then
		local m = res.Instance
		while m.Parent and m.Parent ~= animals do
			m = m.Parent
		end
		if m:GetAttribute("Kind") == "Spirit" then
			return nil
		end
		return "Animal", dist
	end
	local node = res.Instance:FindFirstAncestorWhichIsA("Model")
	while node and not CollectionService:HasTag(node, "ResourceNode") do
		node = node.Parent and node.Parent:IsA("Model") and node.Parent or nil
	end
	if node and not node:GetAttribute("Depleted") then
		local kind = node:GetAttribute("Node")
		if kind == "Tree" or kind == "Rock" then
			return kind, dist
		end
	end
	return nil
end

-- ค่าความเหมาะสมของเครื่องมือกับเป้า (nil = ใช้ไม่ได้/ไม่ถึง)
local function score(id, kind, dist)
	local t = id and Items.Tools[id]
	if not t then
		return nil
	end
	if kind == "Tree" then
		return dist <= NODE_REACH and (t.Chop or 0) > 0 and t.Chop or nil
	elseif kind == "Rock" then
		return dist <= NODE_REACH and (t.Mine or 0) > 0 and t.Mine or nil
	elseif kind == "Animal" then
		if dist > t.Range + 6 then
			return nil
		end
		return t.Damage
	end
	return nil
end

local function bestTool(kind, dist)
	local best, bestScore
	for _, c in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		for _, t in ipairs(c and c:GetChildren() or {}) do
			if t:IsA("Tool") then
				local s = score(t:GetAttribute("ItemId"), kind, dist)
				if s and (not bestScore or s > bestScore) then
					best, bestScore = t, s
				end
			end
		end
	end
	return best, bestScore
end

-- คืนเครื่องมือที่ควรสลับไป (nil = ของในมือดีอยู่แล้ว / ไม่มีเป้า)
function AutoTool.Suggest(current, screenPos)
	if not enabled() or not player:GetAttribute("InRun") or player:GetAttribute("Downed") or player:GetAttribute("Dead") then
		return nil
	end
	if current and current:GetAttribute("Kind") == "Sack" then
		return nil
	end
	local kind, dist = AutoTool.Target(screenPos)
	if not kind then
		return nil
	end
	local best, bestScore = bestTool(kind, dist)
	if not best or best == current then
		return nil
	end
	local cur = current and score(current:GetAttribute("ItemId"), kind, dist)
	if cur and cur >= bestScore then
		return nil
	end
	return best
end

local function equip(tool)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and tool.Parent then
		hum:EquipTool(tool)
		return true
	end
	return false
end

-- เรียกจาก CombatClient ก่อนตี: สลับแล้วตีด้วยของใหม่ (swing(tool)) หลังขึ้นมือ
function AutoTool.Before(current, swing)
	local best = AutoTool.Suggest(current)
	if not best then
		return false
	end
	if not equip(best) then
		return false
	end
	task.delay(0.12, function()
		if best.Parent == player.Character then
			swing(best)
		end
	end)
	return true
end

-- มือเปล่า: คลิก/แตะใส่ต้นไม้/หิน/สัตว์ -> หยิบของที่เหมาะขึ้นมือแล้วตีเลย
function AutoTool.Init(swing)
	local function emptyHanded()
		local char = player.Character
		return char ~= nil and char:FindFirstChildOfClass("Tool") == nil
	end
	local function try(screenPos)
		if not emptyHanded() or (AutoTool.Blocked and AutoTool.Blocked()) then
			return
		end
		local best = AutoTool.Suggest(nil, screenPos)
		if best and equip(best) then
			task.delay(0.12, function()
				if best.Parent == player.Character then
					swing(best)
				end
			end)
		end
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		try(nil)
	end)
	UserInputService.TouchTapInWorld:Connect(function(pos, processed)
		if processed then
			return
		end
		try(pos)
	end)
end

return AutoTool
