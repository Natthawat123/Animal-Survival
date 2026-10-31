--[[
	MountClient — ตอนขี่ลูกสัตว์ธาตุ (attribute Riding จาก MountService)
	  ท่านั่งบนหลัง · ปุ่ม "ลงจากหลัง" ล่างกลางจอ + คีย์ X -> Remotes.Dismount
	  ความเร็วตอนขี่: CombatClient คูณ attribute MountSpeed
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
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
	WoodKit.Button(holder, "Red", { Size = UDim2.fromScale(1, 1), Text = "ลงจากหลัง [X]", TextSize = 24 }, dismount)

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
	player:GetAttributeChangedSignal("Riding"):Connect(refresh)
	player.CharacterAdded:Connect(function()
		track = nil
		task.defer(refresh)
	end)
	refresh()
end

return MountClient
