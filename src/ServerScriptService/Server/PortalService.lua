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

-- ฉากวาร์ป: ดูดเข้าม่าน (0.5 วิ ฝั่งผู้เล่นเล่นภาพ) -> ย้ายตัว -> พุ่งออกที่ปลายทาง
PortalService.SuckTime = 0.5
function PortalService:Teleport(player, dest, look, color)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or self.busy[player] then
		return
	end
	self.busy[player] = true
	local cf = CFrame.lookAt(dest, Vector3.new(look.X, dest.Y, look.Z))
	local cin = self.ctx.Remotes.Get("Cinematic")
	cin:FireClient(player, "Warp", { Phase = "In", Color = color or Color3.fromRGB(200, 230, 255) })
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	task.wait(PortalService.SuckTime)
	if not root.Parent then
		self.busy[player] = nil
		return
	end
	char:PivotTo(cf)
	cin:FireClient(player, "Warp", { Phase = "Out", Color = color or Color3.fromRGB(200, 230, 255) })
	pcall(function()
		player:RequestStreamAroundAsync(dest, 8)
	end)
	task.delay(1.2, function()
		if root.Parent then
			root.Anchored = false
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
			self.ctx.Notify(player, "🔒 ที่นี่ถูกปิดผนึกแล้วในรอบนี้", "Info")
			return
		end
		local dest, look = veil:GetAttribute("Dest"), veil:GetAttribute("DestLook")
		if typeof(dest) == "Vector3" then
			local lt = veil:FindFirstChildWhichIsA("Light")
			self:Teleport(player, dest, typeof(look) == "Vector3" and look or dest + Vector3.new(0, 0, -10), lt and lt.Color)
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
