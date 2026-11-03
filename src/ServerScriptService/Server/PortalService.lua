--[[
	PortalService — ประตูมิติของศาลเจ้า/วิหาร (แท็ก "RealmPortal" จาก PropBuilder.BuildPortal)
	  กด E ที่ม่านประตู -> วาร์ปไป attribute Dest (หันหน้าไป DestLook)
	  วาร์ปแบบกันตกทะลุ: ตรึงตัว -> ย้าย -> โหลดพื้นรอบปลายทาง (StreamingEnabled) -> ปล่อย
]]

local CollectionService = game:GetService("CollectionService")

local PortalService = {}

function PortalService:Init(ctx)
	self.ctx = ctx
	self.busy = {}
end

-- ความสูงกลางลำตัว (HumanoidRootPart) เหนือพื้นตอนยืน
local function standHeight(char, root)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.RigType == Enum.HumanoidRigType.R15 then
		return hum.HipHeight + root.Size.Y / 2
	end
	return 3
end

-- ผิวพื้นที่ยืนได้ใต้จุด pos (ดิน + ของแข็งที่ชนได้ เช่น ฐานซุ้ม/หิน) ไม่นับตัวละคร
local function groundAt(pos)
	local skip = {}
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = skip
	rp.RespectCanCollide = true
	local hit = workspace:Raycast(pos + Vector3.new(0, 14, 0), Vector3.new(0, -70, 0), rp)
	return hit and hit.Position.Y
end

-- ฉากวาร์ป: ดูดเข้าม่าน (0.5 วิ ฝั่งผู้เล่นเล่นภาพ) -> ย้ายตัว -> พุ่งออกที่ปลายทาง
--   onGround: ปลายทางบนพื้นโลก (ประตูกลับ) -> วางเท้าบนผิวพื้นจริง ณ ตอนวาร์ป
--   (Dest ที่คำนวณตอนสร้างแมพอาจต่ำกว่าผิวดินบนทางลาด -> ตัวจมดินติด)
PortalService.SuckTime = 0.5
function PortalService:Teleport(player, dest, look, color, onGround)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or self.busy[player] then
		return
	end
	self.busy[player] = true
	local cin = self.ctx.Remotes.Get("Cinematic")
	cin:FireClient(player, "Warp", { Phase = "In", Color = color or Color3.fromRGB(200, 230, 255) })
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	local t0 = os.clock()
	pcall(function()
		player:RequestStreamAroundAsync(dest, 8)
	end)
	task.wait(math.max(0, PortalService.SuckTime - (os.clock() - t0)))
	if not root.Parent then
		self.busy[player] = nil
		return
	end
	local lift = standHeight(char, root) + 0.3
	local gy = onGround and groundAt(dest)
	if gy then
		dest = Vector3.new(dest.X, gy + lift, dest.Z)
	end
	char:PivotTo(CFrame.lookAt(dest, Vector3.new(look.X, dest.Y, look.Z)))
	cin:FireClient(player, "Warp", { Phase = "Out", Color = color or Color3.fromRGB(200, 230, 255) })
	task.delay(1.2, function()
		if not root.Parent then
			self.busy[player] = nil
			return
		end
		root.Anchored = false
		-- กันพลาดรอบสอง: ปล่อยตัวแล้วยังจมใต้ผิวพื้น -> ยกขึ้นมายืนบนพื้น
		task.wait(0.6)
		local now = onGround and root.Parent and groundAt(root.Position)
		if now and root.Position.Y < now + lift - 1.5 then
			root.AssemblyLinearVelocity = Vector3.zero
			char:PivotTo(root.CFrame + Vector3.new(0, now + lift - root.Position.Y, 0))
		end
		self.busy[player] = nil
	end)
end

local function hook(self, veil)
	local prompt = veil:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		if veil:GetAttribute("Sealed") then
			self.ctx.Notify(player, "🔒 This place is sealed for the rest of this run", "Info")
			return
		end
		local dest, look = veil:GetAttribute("Dest"), veil:GetAttribute("DestLook")
		if typeof(dest) == "Vector3" then
			local lt = veil:FindFirstChildWhichIsA("Light")
			self:Teleport(player, dest, typeof(look) == "Vector3" and look or dest + Vector3.new(0, 0, -10), lt and lt.Color, veil:GetAttribute("DestGround"))
		end
	end)
end

function PortalService:Start()
	for _, v in ipairs(CollectionService:GetTagged("RealmPortal")) do
		hook(self, v)
	end
	-- ศาลเจ้าถูกสร้างใหม่ตอนเริ่มรอบ (SpiritService.Reset) -> ประตูใหม่ต้องต่อด้วย
	CollectionService:GetInstanceAddedSignal("RealmPortal"):Connect(function(v)
		hook(self, v)
	end)
end

return PortalService
