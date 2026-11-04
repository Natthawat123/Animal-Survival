--[[
	MountService — ขี่ลูกสัตว์ธาตุที่ช่วยแล้ว (ตัวที่เดินเล่นอยู่ในแคมป์ SpiritService:SpawnPet)
	  กด E ที่ตัวสัตว์ = ขึ้นขี่: เชื่อมตัวสัตว์ไว้ใต้ผู้เล่น (Weld) -> ผู้เล่นบังคับเดินเองทั้งคู่ (ตัวละครผู้เล่น = ลื่น ไม่หน่วงเน็ต)
	    ยกผู้เล่นขึ้นนั่งบนหลัง (HipHeight) · client เล่นท่านั่ง + วิ่งเร็วขึ้น (attribute Riding / MountSpeed -> MountClient, CombatClient)
	  ลง = ปุ่ม/คีย์ (remote Dismount) · ตาย/ล้ม/ออกเกม/ตัวสัตว์หาย = ลงเอง
	  ลงนอกแคมป์ -> สัตว์เดินกลับแคมป์เอง (AnimalService:ThinkPet)
]]

local Players = game:GetService("Players")

local MountService = {}
MountService.SpeedMult = 1.6
local SINK = 0.25 -- ก้นจมขนหลังสัตว์นิดหน่อย (ไม่ลอยเหนือหลัง)

function MountService:Init(ctx)
	self.ctx = ctx
	self.rides = {} -- [player] = { Pet, Weld, Hip, Saved }
end

function MountService:AddPet(a)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Ride"
	prompt.ActionText = "Ride"
	prompt.ObjectText = a.Info.Thai
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = a.Root
	prompt.Triggered:Connect(function(player)
		self:Mount(player, a)
	end)
	a.RidePrompt = prompt
	a.Model.Destroying:Connect(function()
		if a.Rider then
			self:Dismount(a.Rider, true)
		end
	end)
end

function MountService:Mount(player, a)
	if a.Rider or a.Removed or self.rides[player] or player:GetAttribute("Downed") or player:GetAttribute("Dead") then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum and hum.Health > 0) or hum.SeatPart then
		return
	end
	local model = a.Model
	local bcf, size = model:GetBoundingBox()
	local rootUp = a.Root.Position.Y - (bcf.Position.Y - size.Y / 2) -- root สูงจากเท้าสัตว์เท่าไร
	-- ความสูงหลังสัตว์ (ที่นั่ง) · โมเดลเมชเดียว (ผิว+กระดูก) ตั้ง Skin.Back = สัดส่วนความสูงตัว (หูยาว/หัวโต ไม่ใช่หลัง)
	local skinSpec = a.Info.Model and a.Info.Model.Skin
	local back = size.Y * (skinSpec and skinSpec.Back or 0.72)
	local body = model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		-- นั่งบนหลังจริง (ไม่ใช่ยอดปีก/เขา): ขอบบนของลำตัว
		back = math.clamp(body.Position.Y + body.Size.Y * 0.4 - (bcf.Position.Y - size.Y / 2), size.Y * 0.35, size.Y * 0.9)
	end
	local ride = { Pet = a, Hip = hum.HipHeight, Back = back, Saved = {} }
	a.Rider = player
	a.Hum:MoveTo(a.Root.Position)
	a.Hum.EvaluateStateMachine = false -- Humanoid ของสัตว์เลิกออกแรงเอง (ผู้เล่นพาไป)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			ride.Saved[d] = { d.CanCollide, d.Massless, d.CanQuery, d.Anchored }
			d.CanCollide, d.Massless, d.CanQuery, d.Anchored = false, true, false, false
		elseif d:IsA("AlignOrientation") or d:IsA("AlignPosition") then
			ride.Saved[d] = d.Enabled
			d.Enabled = false
		end
	end
	-- ยกผู้เล่นขึ้นหลังสัตว์ แล้วเชื่อมสัตว์ไว้ใต้ตัว (เท้าสัตว์แตะพื้นพอดี)
	--   ก้น (ใต้ LowerTorso/Torso) ต้องแตะหลังสัตว์พอดี: ระยะจากกลางตัว (HRP) ลงไปถึงก้น = seat
	--   (เดิมบวกความสูงหลังเพิ่มจากความสูงขาตอนยืน -> ลอยสูงกว่าหลังเท่าความยาวขา)
	local half = hrp.Size.Y / 2
	local legs = hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0 -- R6: ขายาว 2 ไม่นับใน HipHeight
	local pelvis = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")
	local seat = pelvis and (hrp.Position.Y - (pelvis.Position.Y - pelvis.Size.Y / 2)) or half
	local hrpAbove = back + seat - SINK -- กลางตัวผู้เล่นสูงจากพื้นเท่าไร
	local oldAbove = ride.Hip + half + legs
	hum.HipHeight = math.max(0, hrpAbove - half - legs)
	-- ผู้เล่นหันทางเดียวกับหัวสัตว์ (root ของสัตว์หันหน้า -Z = ทิศหัว) แล้วย้ายไปอยู่เหนือกลางหลัง
	local look = a.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local seat = Vector3.new(bcf.Position.X, hrp.Position.Y + hrpAbove - oldAbove, bcf.Position.Z)
	local rel = hrp.CFrame:Inverse() * char:GetPivot()
	char:PivotTo(CFrame.lookAt(seat, seat + look) * rel)
	-- นั่งกลางหลัง: จุดกลางกล่องตัวสัตว์ (ไม่ใช่ root ที่มักอยู่ค่อนไปทางอก) อยู่ใต้ผู้เล่นพอดี · หันทางเดียวกับสัตว์
	local off = a.Root.CFrame:PointToObjectSpace(bcf.Position)
	local w = Instance.new("Weld")
	w.Name = "MountWeld"
	w.Part0 = hrp
	w.Part1 = a.Root
	w.C0 = CFrame.new(-off.X, -hrpAbove + rootUp, -off.Z)
	w.Parent = a.Root
	ride.Weld = w
	pcall(function()
		hrp:SetNetworkOwner(player)
	end)
	if a.RidePrompt then
		a.RidePrompt.Enabled = false
	end
	self.rides[player] = ride
	model:SetAttribute("Ridden", true)
	player:SetAttribute("MountSpeed", MountService.SpeedMult)
	player:SetAttribute("Riding", a.Info.Thai)
end

-- gone = ตัวสัตว์ถูกลบไปแล้ว (จบรอบ) -> แค่คืนสภาพผู้เล่น
function MountService:Dismount(player, gone)
	local ride = self.rides[player]
	if not ride then
		return
	end
	self.rides[player] = nil
	local a = ride.Pet
	player:SetAttribute("Riding", nil)
	player:SetAttribute("MountSpeed", nil)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if ride.Weld then
		ride.Weld:Destroy()
	end
	if hum and hum.Parent then
		hum.HipHeight = ride.Hip
	end
	if gone or a.Removed or not a.Model.Parent then
		a.Rider = nil
		return
	end
	-- ลงข้างๆ: สัตว์ขยับไปด้านขวาของผู้เล่น (ความสูงเท้าเท่าเดิม = อยู่บนพื้นแล้ว)
	if hrp and hrp.Parent then
		a.Model:PivotTo(a.Model:GetPivot() + hrp.CFrame.RightVector * (a.Radius + 3.5))
	end
	for inst, v in pairs(ride.Saved) do
		if inst.Parent then
			if inst:IsA("BasePart") then
				inst.CanCollide, inst.Massless, inst.CanQuery, inst.Anchored = v[1], v[2], v[3], v[4]
			else
				inst.Enabled = v
			end
		end
	end
	a.Hum.EvaluateStateMachine = true
	pcall(function()
		a.Root:SetNetworkOwner(nil)
	end)
	a.Model:SetAttribute("Ridden", nil)
	if a.RidePrompt then
		a.RidePrompt.Enabled = true
	end
	a.Rider = nil
	a.WanderAt = os.clock() + 2
end

function MountService:Start(ctx)
	ctx.Remotes.Get("Dismount").OnServerEvent:Connect(function(player)
		self:Dismount(player)
	end)
	local function hook(player)
		player.CharacterRemoving:Connect(function()
			self:Dismount(player)
		end)
		player.CharacterAdded:Connect(function(char)
			local hum = char:WaitForChild("Humanoid", 10)
			if hum then
				hum.Died:Connect(function()
					self:Dismount(player)
				end)
			end
		end)
		player:GetAttributeChangedSignal("Downed"):Connect(function()
			if player:GetAttribute("Downed") then
				self:Dismount(player)
			end
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
		if p.Character then
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Died:Connect(function()
					self:Dismount(p)
				end)
			end
		end
	end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(p)
		self:Dismount(p)
	end)
end

return MountService
