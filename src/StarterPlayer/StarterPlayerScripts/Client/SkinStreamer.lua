--[[
	SkinStreamer — สวมโมเดลจริง (EditableMesh) ให้ของที่มีแท็ก MeshSkin เมื่อโหลดเข้ามาในระยะ (streaming)
	ทำทีละไม่กี่ชิ้นต่อเฟรม กันเกมกระตุก
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimalSkins = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimalSkins"))

local SkinStreamer = {}
local queue = {}
local queued = {}

local function push(inst)
	if queued[inst] or inst:GetAttribute("Skinned") then
		return
	end
	queued[inst] = true
	table.insert(queue, inst)
end

function SkinStreamer.Init()
	for _, inst in ipairs(CollectionService:GetTagged("MeshSkin")) do
		push(inst)
	end
	CollectionService:GetInstanceAddedSignal("MeshSkin"):Connect(push)
	RunService.Heartbeat:Connect(function()
		local budget = os.clock() + 0.004
		while #queue > 0 and os.clock() < budget do
			local inst = table.remove(queue, 1)
			queued[inst] = nil
			if inst.Parent then
				-- รอชิ้นส่วนโหลดครบ (streaming อาจมาไม่พร้อมกัน)
				if not inst:FindFirstChildWhichIsA("BasePart", true) then
					task.delay(0.5, push, inst)
				else
					local ok, err = pcall(AnimalSkins.Skin, inst)
					if not ok then
						warn("[AS] skin", inst:GetFullName(), err)
					end
				end
			end
		end
	end)
end

return SkinStreamer
