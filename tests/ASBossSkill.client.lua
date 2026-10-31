--[[ ASBossSkill (client) — กล้องตามคำสั่ง attribute "ProbeCam": side = มุมข้างเห็นทั้งบอส+ผู้เล่น · face = ซูมหัวบอส (จากกระดูกหัวจริง) · "" = กล้องปกติ
	บังคับกลางวัน ปิดหมอก/ฟิลเตอร์กลางคืน/UI ระหว่างถ่าย ให้เห็นท่าทาง/เอฟเฟกต์ชัด ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
if not ReplicatedStorage:FindFirstChild("ASBossSkill") then
	return
end
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local HEAD = { Terragon = "Bone_031", TempestRoc = "Bone_015", Solfang = "Bone_027", Leviathan = "Bone_003" }

local function boss()
	local folder = workspace:FindFirstChild("Animals")
	for _, m in ipairs(folder and folder:GetChildren() or {}) do
		if m:GetAttribute("IsBoss") then
			return m
		end
	end
end

local headCache = {}
local function headBone(m)
	if headCache[m] ~= nil then
		return headCache[m] or nil
	end
	local name = HEAD[m:GetAttribute("AnimalId") or ""]
	local found = false
	local skin = m:FindFirstChild("Skin")
	for _, d in ipairs(skin and skin:GetDescendants() or {}) do
		if d:IsA("Bone") and d.Name == name then
			found = d
		end
	end
	headCache[m] = found
	return found or nil
end

-- เทสคทา: กล้องเล็งให้ "ตำแหน่งเมาส์" ชี้โดนเป้าพอดี แล้วกดใช้ Tool จริง (ทางเดียวกับผู้เล่นคลิก)
player:GetAttributeChangedSignal("ProbeClick"):Connect(function()
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	print("[STAFF] client click", tool and tool:GetAttribute("ItemId"))
	if tool then
		tool:Activate()
	end
end)
RunService:BindToRenderStep("ASStaffAim", Enum.RenderPriority.Last.Value + 20, function()
	if player:GetAttribute("ProbeCam") ~= "aimwolf" then
		return
	end
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local t = player:GetAttribute("ProbeTarget")
	if not r or typeof(t) ~= "Vector3" then
		return
	end
	local m = game:GetService("UserInputService"):GetMouseLocation()
	local ray = cam:ViewportPointToRay(m.X, m.Y)
	local rel = cam.CFrame:VectorToObjectSpace(ray.Direction)
	local flat = (t - r.Position) * Vector3.new(1, 0, 1)
	local camPos = r.Position - flat.Unit * 10 + Vector3.new(0, 5, 0)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(camPos, t) * CFrame.fromRotationBetweenVectors(rel, Vector3.new(0, 0, -1))
end)
player:GetAttributeChangedSignal("ProbeScan"):Connect(function()
	local c = player:GetAttribute("ProbeScan")
	local seen = {}
	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local d = (part.Position - c) * Vector3.new(1, 0, 1)
			if d.Magnitude < 7 and math.abs(part.Position.Y - c.Y) < 12 then
				local top = part
				while top.Parent and top.Parent ~= workspace and top.Parent.Parent ~= workspace do
					top = top.Parent
				end
				local key = part:GetFullName() .. " <" .. part.ClassName .. ">"
				if not seen[key] and not part:GetFullName():find("Campfire") then
					seen[key] = true
					print("[CAMP] client near", key)
				end
			end
		end
	end
end)
player:GetAttributeChangedSignal("ProbeHotbar"):Connect(function()
	task.wait(0.8)
	local pg = player:WaitForChild("PlayerGui")
	local guis, shown = 0, {}
	for _, g in ipairs(pg:GetChildren()) do
		if g.Name == "ASBackpack" then
			guis += 1
			local bar = g:FindFirstChild("Hotbar")
			for _, b in ipairs(bar and bar:GetChildren() or {}) do
				if b:IsA("GuiButton") and b.Visible then
					local h = b:FindFirstChildOfClass("Frame")
					local has = h and #h:GetChildren() > 0
					if has then
						table.insert(shown, b.Name)
					end
				end
			end
		end
	end
	local real = 0
	for _, holder in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		for _, t in ipairs(holder and holder:GetChildren() or {}) do
			if t:IsA("Tool") then
				real += 1
			end
		end
	end
	print(string.format("[DUP] %s %s client: guis=%d slotsShown=%d realTools=%d (%s)", (guis == 1 and #shown == real) and "PASS" or "FAIL", player:GetAttribute("ProbeHotbar"), guis, #shown, real, table.concat(shown, ",")))
end)
do
	-- วัดความเข้มจอแดง (GroupTransparency ต่ำสุด) ระหว่างแต่ละช่วงทดสอบ
	local cur, minHurt, minLow, flashes, wasOn = nil, 1, 1, 0, false
	RunService.Heartbeat:Connect(function()
		if not cur then
			return
		end
		local pg = player:FindFirstChild("PlayerGui")
		local h = pg and pg:FindFirstChild("HurtFX")
		local l = pg and pg:FindFirstChild("LowHealthFX")
		local hg = h and h:FindFirstChildOfClass("CanvasGroup")
		local lg = l and l:FindFirstChildOfClass("CanvasGroup")
		local ht = hg and hg.GroupTransparency or 1
		minHurt = math.min(minHurt, ht)
		minLow = math.min(minLow, lg and lg.GroupTransparency or 1)
		local on = ht < 0.95
		if on and not wasOn then
			flashes += 1
		end
		wasOn = on
	end)
	player:GetAttributeChangedSignal("ProbeFx"):Connect(function()
		local v = player:GetAttribute("ProbeFx") or ""
		if v:sub(-4) == "_end" then
			print(string.format("[HURT] %s flashes=%d minHurt=%.2f minLow=%.2f coreHealth=%s", v:sub(1, -5), flashes, minHurt, minLow, tostring(game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.Health))))
			cur = nil
		else
			cur, minHurt, minLow, flashes, wasOn = v, 1, 1, 0, false
		end
	end)
end
player:GetAttributeChangedSignal("ProbeMusic"):Connect(function()
	local SS = game:GetService("SoundService")
	local list = {}
	for _, snd in ipairs(SS:GetChildren()) do
		if snd:IsA("Sound") and snd.Name:sub(1, 6) == "Music_" and snd.Volume > 0.02 then
			table.insert(list, string.format("%s=%.2f", snd.Name:sub(7), snd.Volume))
		end
	end
	local boss = SS:FindFirstChild("Music_Boss")
	print(string.format("[MUSIC] %s bossVol=%.2f playing: %s", player:GetAttribute("ProbeMusic"), boss and boss.Volume or -1, table.concat(list, " ")))
end)
RunService:BindToRenderStep("ASBossSkillCam", Enum.RenderPriority.Last.Value + 10, function()
	local mode = player:GetAttribute("ProbeCam") or ""
	if mode ~= "" then
		Lighting.ClockTime = 13
		Lighting.FogEnd = 100000
		Lighting.FogStart = 100000
		Lighting.Brightness = 2.5
		Lighting.ExposureCompensation = 0.2
		Lighting.Ambient = Color3.fromRGB(150, 150, 150)
		Lighting.OutdoorAmbient = Color3.fromRGB(170, 170, 170)
		for _, e in ipairs(Lighting:GetChildren()) do
			if e:IsA("Atmosphere") then
				e.Density = 0.25
				e.Haze = 0
			elseif e:IsA("ColorCorrectionEffect") or e:IsA("BlurEffect") then
				e.Enabled = false
			end
		end
		for _, g in ipairs(player.PlayerGui:GetChildren()) do
			if g:IsA("ScreenGui") then
				g.Enabled = false
			end
		end
	end
	if mode == "look" then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(player:GetAttribute("ProbeFrom") or Vector3.zero, player:GetAttribute("ProbeAt") or Vector3.zAxis)
		return
	end
	local m = mode ~= "" and boss()
	local root = m and (m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true))
	if not root then
		if cam.CameraType ~= Enum.CameraType.Custom then
			cam.CameraType = Enum.CameraType.Custom
		end
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	local bcf, size = m:GetBoundingBox()
	local big = math.clamp(math.max(size.X, size.Y, size.Z), 8, 160)
	local rc = root.CFrame
	local center = bcf.Position
	if mode == "face" then
		local hb = headBone(m)
		local head = hb and hb.WorldPosition or (center + rc.LookVector * size.Z * 0.42 + Vector3.new(0, size.Y * 0.2, 0))
		-- มองจากด้านหน้า-ข้างของหัว ห่างพอเห็นทั้งหัว+คอ
		local d = 14 + math.min(size.Y, 60) * 0.35 -- ระยะตามความสูงตัว (กรอบรวมปีก/หางใหญ่เกินไป)
		local from = head + rc.LookVector * d + rc.RightVector * d * 0.6 + Vector3.new(0, d * 0.15, 0)
		cam.CFrame = CFrame.lookAt(from, head)
	else
		local char = player.Character
		local pr = char and char:FindFirstChild("HumanoidRootPart")
		local mid = pr and (center + pr.Position) / 2 or center
		local dir = pr and ((pr.Position - center) * Vector3.new(1, 0, 1)) or rc.LookVector
		dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.zAxis
		local side = dir:Cross(Vector3.yAxis)
		-- มุมข้างเฉียงสูง (มองข้ามต้นไม้รอบลาน)
		cam.CFrame = CFrame.lookAt(mid + side * (math.min(big, 70) * 0.9 + 38) + Vector3.new(0, math.min(big, 70) * 0.6 + 26, 0) - dir * 10, mid)
	end
end)
