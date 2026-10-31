--[[
	MedAnim — ท่าพันแผล / ก้มช่วยเพื่อน (ปรับฐานของข้อต่อทุกเฟรม ทั้ง Motor6D และ AnimationConstraint ให้ได้ท่าตามต้องการไม่ว่า Animator เล่นอะไร · ไม่ต้องอัปโหลดอนิเมชัน)
	อ่าน attribute ที่เซิร์ฟเวอร์ตั้ง (SurvivalService:SetMedPose) ของผู้เล่นทุกคน -> ทุกเครื่องเห็นท่าเดียวกัน
	  MedUse = "Self" (ยืนพันแผลแขนตัวเอง) / "Revive" (ย่อตัวก้มพันแผลให้เพื่อนที่ล้ม)
	  MedTime > 0 = หลอดรอบนจอของผู้ใช้เอง (MedStart = เวลาเริ่ม ตามนาฬิกาเซิร์ฟเวอร์)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local MedAnim = {}

local ANG = CFrame.Angles
local R = math.rad
local BLEND = 0.18 -- วินาทีที่ใช้เข้า/ออกท่า

-- ค่าฐานของข้อต่อ: Motor6D = C0 · AnimationConstraint (ตัวละครแบบใหม่) = CFrame ของ Attachment0
local function getBase(j)
	if j:IsA("Motor6D") then
		return j.C0
	end
	return j.Attachment0 and j.Attachment0.CFrame
end
local function setBase(j, cf)
	if j:IsA("Motor6D") then
		j.C0 = cf
	elseif j.Attachment0 then
		j.Attachment0.CFrame = cf
	end
end

-- ข้อต่อ R15 / R6 ของตัวละคร (แคชต่อตัว)
local function joints(char)
	local function m(partName, name)
		local p = char:FindFirstChild(partName)
		local j = p and p:FindFirstChild(name)
		return j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) and j or nil
	end
	if char:FindFirstChild("UpperTorso") then
		return {
			R15 = true,
			RS = m("RightUpperArm", "RightShoulder"),
			LS = m("LeftUpperArm", "LeftShoulder"),
			RE = m("RightLowerArm", "RightElbow"),
			LE = m("LeftLowerArm", "LeftElbow"),
			Waist = m("UpperTorso", "Waist"),
			Neck = m("Head", "Neck"),
			Root = m("LowerTorso", "Root"),
			RH = m("RightUpperLeg", "RightHip"),
			LH = m("LeftUpperLeg", "LeftHip"),
			RK = m("RightLowerLeg", "RightKnee"),
			LK = m("LeftLowerLeg", "LeftKnee"),
		}
	end
	return {
		R6 = true,
		RS = m("Torso", "Right Shoulder"),
		LS = m("Torso", "Left Shoulder"),
		Neck = m("Torso", "Neck"),
	}
end

-- ท่าเป้าหมายของแต่ละข้อต่อ (t = เวลา วินาที) -> { [key] = CFrame }
-- R15: หมุน +X = ยกแขน/ขาไปข้างหน้า · หมุน Z = แขนเข้าหากลางตัว (ขวา -, ซ้าย +)
local function poseR15(kind, t)
	local wrap = math.sin(t * 9)
	local wrap2 = math.cos(t * 9)
	if kind == "Revive" then
		local press = math.sin(t * 7)
		return {
			Root = CFrame.new(0, -1.15, 0.15),
			Waist = ANG(R(-26), 0, 0),
			Neck = ANG(R(-10), 0, 0),
			RH = ANG(R(78), 0, R(6)),
			LH = ANG(R(30), 0, R(-6)),
			RK = ANG(R(-80), 0, 0),
			LK = ANG(R(-120), 0, 0),
			RS = ANG(R(62 + press * 10), 0, R(-18 + wrap2 * 8)),
			LS = ANG(R(58 - press * 6), 0, R(18)),
			RE = ANG(R(22 + press * 8), 0, 0),
			LE = ANG(R(24), 0, 0),
		}
	end
	-- ยืนพันแผล: แขนซ้ายยื่นมาหน้าอก มือขวา (ถือผ้า) วนพันรอบแขนซ้าย
	return {
		Neck = ANG(R(-24), R(8), 0),
		Waist = ANG(R(-6), 0, 0),
		LS = ANG(R(52 + wrap * 3), 0, R(32)),
		LE = ANG(R(62), 0, 0),
		RS = ANG(R(58 + wrap * 14), 0, R(-30 + wrap2 * 12)),
		RE = ANG(R(58 - wrap * 10), 0, 0),
	}
end

-- R6: ข้อไหล่หมุนรอบแกน Z ของข้อต่อ (ขวา + = ยกไปหน้า, ซ้าย - = ยกไปหน้า)
local function poseR6(kind, t)
	local wrap = math.sin(t * 9)
	local down = kind == "Revive" and 55 or 80
	return {
		Neck = ANG(R(kind == "Revive" and 30 or 20), 0, 0),
		RS = ANG(R(wrap * 10), 0, R(down + wrap * 12)),
		LS = ANG(0, 0, R(-(down - 5))),
	}
end

-- สถานะต่อผู้เล่น: { Char, J, Kind, A (0..1 น้ำหนักท่า), T0 }
local states = {}

local function step(dt)
	for _, p in ipairs(Players:GetPlayers()) do
		local kind = p:GetAttribute("MedUse")
		local st = states[p]
		local char = p.Character
		if kind and char and (not st or st.Char ~= char) then
			st = { Char = char, J = joints(char), Kind = kind, A = 0, T0 = os.clock(), Base = {} }
			states[p] = st
		end
		if st then
			if kind then
				st.Kind = kind
				st.A = math.min(1, st.A + dt / BLEND)
			else
				st.A -= dt / BLEND
			end
			if st.A <= 0 or not st.Char.Parent then
				-- จบท่า: คืน C0 เดิมทุกข้อ
				for m, base in pairs(st.Base) do
					if m.Parent then
						setBase(m, base)
					end
				end
				states[p] = nil
			else
				local t = os.clock() - st.T0
				local pose = st.J.R15 and poseR15(st.Kind, t) or poseR6(st.Kind, t)
				-- เข้า/ออกท่าแบบนุ่ม (smoothstep) · ผสมกับท่าของ Animator ในเฟรมนี้
				local a = st.A * st.A * (3 - 2 * st.A)
				local used = {}
				for key, cf in pairs(pose) do
					local m = st.J[key]
					if m and m.Parent then
						-- Animator เขียน Transform ทับทุกเฟรม -> ปรับ C0 แทน โดยหักลบ Transform ออก
						--   (C0 * Transform = ฐาน * ท่าที่ต้องการ ไม่ว่า Animator จะเล่นท่าอะไรอยู่)
						local base = st.Base[m] or getBase(m)
						if base then
							st.Base[m] = base
							local cur = m.Transform
							setBase(m, base * cur:Lerp(cf, a) * cur:Inverse())
							used[m] = true
						end
					end
				end
				-- ข้อที่ท่าปัจจุบันไม่ใช้ (เปลี่ยนจากท่าก้มเป็นท่ายืน) -> คืนค่าเดิม
				for m, base in pairs(st.Base) do
					if not used[m] and m.Parent then
						setBase(m, base)
					end
				end
			end
		end
	end
end

-- หลอดรอใช้ยา (ของผู้เล่นเอง)
local function buildBar()
	local gui = UIKit.Screen("MedBar", 28)
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -150)
	holder.Size = UDim2.fromOffset(280, 44)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = 17
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = holder
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 24)
	back.Size = UDim2.new(1, 0, 0, 14)
	back.BackgroundColor3 = Color3.fromRGB(20, 24, 22)
	back.BackgroundTransparency = 0.25
	back.Parent = holder
	UIKit.Corner(back, 7)
	UIKit.Stroke(back, Color3.fromRGB(255, 255, 255), 1.5, 0.6)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 230, 130)
	fill.Parent = back
	UIKit.Corner(fill, 7)
	UIKit.AutoScale(holder)
	return holder, label, fill
end

function MedAnim.Init()
	RunService.Stepped:Connect(function(_, dt)
		step(dt)
	end)
	Players.PlayerRemoving:Connect(function(p)
		states[p] = nil
	end)
	local holder, label, fill = buildBar()
	RunService.RenderStepped:Connect(function()
		local time = player:GetAttribute("MedTime")
		local start = player:GetAttribute("MedStart")
		if not (player:GetAttribute("MedUse") and type(time) == "number" and time > 0 and start) then
			holder.Visible = false
			return
		end
		local item = Items.Data[player:GetAttribute("MedItem") or ""]
		local what = item and item.Thai or "ผ้าพันแผล"
		label.Text = player:GetAttribute("MedUse") == "Revive" and ("กำลังช่วยเพื่อนด้วย" .. what .. "…") or ("กำลังใช้" .. what .. "… (ยืนนิ่งๆ)")
		fill.Size = UDim2.fromScale(math.clamp((Workspace:GetServerTimeNow() - start) / time, 0, 1), 1)
		holder.Visible = true
	end)
end

return MedAnim
