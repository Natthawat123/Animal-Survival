--[[
	MountClient — ตอนขี่ลูกสัตว์ธาตุ (attribute Riding จาก MountService)
	  ท่านั่งบนหลัง · ปุ่ม "ลงจากหลัง" ล่างกลางจอ + คีย์ X -> Remotes.Dismount
	  ความเร็วตอนขี่: CombatClient คูณ attribute MountSpeed
	  ขี่ลงน้ำ: ไม่ว่ายน้ำ (หัวสัตว์จม) -> แผ่นใสใต้ตัวที่ระดับผิวน้ำ ตามตัวไปทุกเฟรม = สัตว์ลอยว่ายเหนือน้ำ หัวพ้นน้ำ
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UIKit = require(script.Parent.UIKit)
local WoodKit = require(script.Parent.WoodKit)

local MountClient = {}
local player = Players.LocalPlayer
local SIT_R15 = "rbxassetid://2506281703"
local SIT_R6 = "rbxassetid://178130996"

function MountClient.Init()
	local gui = UIKit.Screen("MountUI", 31)
	local holder = UIKit.Frame(gui, { Size = UDim2.fromOffset(260, 60), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), BackgroundTransparency = 1, Visible = false })
	UIKit.AutoScale(holder)
	local function dismount()
		Remotes.Get("Dismount"):FireServer()
	end
	WoodKit.Button(holder, "Red", { Size = UDim2.fromScale(1, 1), Text = "Dismount [X]", TextSize = 24 }, dismount)

	local track
	local function stopSit()
		if track then
			track:Stop(0.2)
			track = nil
		end
	end
	local function playSit()
		stopSit()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if not animator then
			return
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = hum.RigType == Enum.HumanoidRigType.R15 and SIT_R15 or SIT_R6
		local ok, t = pcall(animator.LoadAnimation, animator, anim)
		if ok and t then
			t.Priority = Enum.AnimationPriority.Action
			t.Looped = true
			t:Play(0.2)
			track = t
		end
	end
	local function refresh()
		local riding = player:GetAttribute("Riding")
		holder.Visible = riding ~= nil
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			-- ขี่อยู่ห้ามว่ายน้ำ (ท่าว่ายดึงตัวลงน้ำ) · ยืนบนแผ่นลอยน้ำแทน
			hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, riding == nil)
		end
		if riding then
			playSit()
			ContextActionService:BindAction("ASDismount", function(_, st)
				if st == Enum.UserInputState.Begin then
					dismount()
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.KeyCode.X, Enum.KeyCode.ButtonX)
		else
			stopSit()
			ContextActionService:UnbindAction("ASDismount")
		end
	end
	-- ลอยน้ำตอนขี่: แผ่นชนได้ (ใส · มีแค่ในเครื่องผู้เล่นนี้) ใต้ตัวที่ผิวน้ำลบนิดหน่อย ให้ขาสัตว์จุ่มน้ำแต่ตัว/หัวพ้นน้ำ
	local raft = Instance.new("Part")
	raft.Name = "MountRaft"
	raft.Size = Vector3.new(14, 1, 14)
	raft.Anchored = true
	raft.CanCollide = true
	raft.CanTouch = false
	raft.Transparency = 1
	raft.CastShadow = false
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	rp.IgnoreWater = false
	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (player:GetAttribute("Riding") and hrp and hum) then
			raft.Parent = nil
			return
		end
		local hit = workspace:Raycast(hrp.Position + Vector3.new(0, 4, 0), Vector3.new(0, -80, 0), rp)
		if hit and hit.Material == Enum.Material.Water then
			local sink = math.clamp(hum.HipHeight * 0.3, 0.6, 1.8) -- ขาสัตว์จุ่มน้ำ ตัว/หัวพ้นน้ำ
			raft.CFrame = CFrame.new(hrp.Position.X, hit.Position.Y - sink - raft.Size.Y / 2, hrp.Position.Z)
			raft.Parent = workspace
		else
			raft.Parent = nil
		end
	end)
	player:GetAttributeChangedSignal("Riding"):Connect(refresh)
	player.CharacterAdded:Connect(function()
		track = nil
		task.defer(refresh)
	end)
	refresh()
end

return MountClient
