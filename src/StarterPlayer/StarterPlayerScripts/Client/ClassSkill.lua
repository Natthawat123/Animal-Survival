--[[
	ClassSkill — ช่องสกิลกดของคลาส 5 ดาว (หน้าแถบของ · ช่องแรก ปุ่ม Q · ช่องสอง ปุ่ม Z · มือถือแตะช่อง) (เอฟเฟกต์อยู่ใน ClassFX.lua)
	  เซิร์ฟเวอร์: SkillService · attribute "Skills" = รหัสสกิลคั่นด้วย "," · "SkillReady_<Id>" = เวลาเซิร์ฟเวอร์ที่คูลดาวน์หมด
	  Swarm = ค้างคาว (Workspace.Summons) — กระพือปีกที่เครื่องนี้
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared.Classes)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)

local ClassSkill = {}
local player = Players.LocalPlayer
local SLOT = 60
local KEYS = { Enum.KeyCode.Q, Enum.KeyCode.Z }
local KEY_TEXT = { "Q", "Z" }
local slots = {} -- [1..2] = { Button, Icon, Fill, Text }
local barRef

-- สกิลที่ใช้ได้ตอนนี้ (ตามลำดับเลเวล)
local function skills()
	if (player:GetAttribute("Skills") or "") == "" then
		return {}
	end
	return Classes.ActiveSkills(player:GetAttribute("Class") or "Survivor", player:GetAttribute("ClassLevel") or 1)
end

-- จุดที่เล็ง: คอม = ตำแหน่งเมาส์ · มือถือ = กลางจอ
local function aimPoint()
	local cam = Workspace.CurrentCamera
	local p = UIKit.IsTouch and (cam.ViewportSize / 2) or UserInputService:GetMouseLocation()
	local ray = cam:ViewportPointToRay(p.X, p.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, Workspace:FindFirstChild("Summons") }
	local res = Workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	return res and res.Position or (ray.Origin + ray.Direction * 60)
end

function ClassSkill.Use(index)
	local sk = skills()[index or 1]
	if not sk or Workspace:GetServerTimeNow() < (player:GetAttribute("SkillReady_" .. sk.Id) or 0) then
		return
	end
	Remotes.Get("UseSkill"):FireServer(sk.Id, aimPoint())
end

local function buildSlot(bar, i)
	local b = Instance.new("TextButton")
	b.Name = "SkillSlot" .. i
	b.LayoutOrder = -100 + i -- หน้าสุดของแถบ
	b.Size = UDim2.fromOffset(SLOT, SLOT)
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.fromRGB(70, 20, 40)
	b.BackgroundTransparency = 0.15
	b.Visible = false
	b.Parent = bar
	UIKit.Corner(b, 10)
	UIKit.Stroke(b, Color3.fromRGB(255, 200, 80), 2.5, 0)
	local icon = UIKit.Text(b, { Size = UDim2.fromScale(1, 1), TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, Text = "" })
	icon:SetAttribute("NoTranslate", true)
	local key = UIKit.Text(b, { Size = UDim2.fromOffset(20, 18), Position = UDim2.fromOffset(4, 2), TextSize = 14, Font = UIKit.Fonts.Black, Text = UIKit.IsTouch and "" or KEY_TEXT[i], TextColor3 = Color3.fromRGB(255, 220, 120) })
	key:SetAttribute("NoTranslate", true)
	-- คูลดาวน์: ม่านมืดลดลงจากบน + เลขวินาที
	local fill = Instance.new("Frame")
	fill.Name = "Cooldown"
	fill.BackgroundColor3 = Color3.new(0, 0, 0)
	fill.BackgroundTransparency = 0.35
	fill.BorderSizePixel = 0
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.ZIndex = 3
	fill.Parent = b
	UIKit.Corner(fill, 10)
	local cd = UIKit.Text(b, { Size = UDim2.fromScale(1, 1), TextSize = 22, Font = UIKit.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Center, Text = "", ZIndex = 4 })
	cd:SetAttribute("NoTranslate", true)
	b.Activated:Connect(function()
		ClassSkill.Use(i)
	end)
	slots[i] = { Button = b, Icon = icon, Fill = fill, Text = cd }
end

local function update()
	if not barRef then
		return
	end
	local list = skills()
	local inRun = player:GetAttribute("InRun") == true
	for i = 1, #KEYS do
		local s, sk = slots[i], list[i]
		s.Button.Visible = sk ~= nil and inRun
		if s.Button.Visible then
			s.Icon.Text = sk.Icon or "✦"
			local left = (player:GetAttribute("SkillReady_" .. sk.Id) or 0) - Workspace:GetServerTimeNow()
			if left > 0 then
				s.Fill.Size = UDim2.fromScale(1, math.clamp(left / sk.Cooldown, 0, 1))
				s.Text.Text = tostring(math.ceil(left))
			else
				s.Fill.Size = UDim2.fromScale(1, 0)
				s.Text.Text = ""
			end
		end
	end
end

-- เอฟเฟกต์สกิลทั้งหมดอยู่ใน ClassFX.lua

function ClassSkill.Init(combat)
	ClassSkill.Combat = combat
	-- ช่องสกิลในแถบของ (Backpack สร้าง ASBackpack.Hotbar)
	task.spawn(function()
		local gui = player:WaitForChild("PlayerGui"):WaitForChild("ASBackpack", 60)
		local bar = gui and gui:WaitForChild("Hotbar", 30)
		if bar then
			for i = 1, #KEYS do
				buildSlot(bar, i)
			end
			barRef = bar
			update()
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if name == "Skills" or name == "InRun" or name == "Class" or name == "ClassLevel" or name:sub(1, 11) == "SkillReady_" then
			update()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for i, k in ipairs(KEYS) do
			if input.KeyCode == k then
				local menus = ClassSkill.Menus
				if i == 1 and menus and menus.IsBuilding() then
					return -- โหมดวางของ: Q = เปลี่ยนชนิดสิ่งก่อสร้าง
				end
				ClassSkill.Use(i)
			end
		end
	end)
	-- คูลดาวน์ลดทุก 0.2 วิ + ค้างคาวกระพือปีก
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			acc = 0
			update()
		end
		local folder = Workspace:FindFirstChild("Summons")
		if folder then
			local t = os.clock()
			for i, m in ipairs(folder:GetChildren()) do
				local flap = math.sin(t * 16 + i) * 0.7
				for _, j in ipairs(m:GetDescendants()) do
					if j:IsA("Motor6D") then
						local side = j.Name:find("Left") and 1 or -1
						j.Transform = CFrame.Angles(0, flap * side, 0)
					end
				end
			end
		end
	end)
end

return ClassSkill
