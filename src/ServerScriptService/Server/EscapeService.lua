--[[
	EscapeService — ประตูกลับบ้าน หลังรอดครบ 99 คืน
	  พิชิต 99 คืน (State "Conquered") -> ประตูมิติโผล่ที่ขอบแคมป์ (ฉากเปิดประตูสั้น ๆ)
	  ใครก็ได้ไปกด E ที่ประตู = เปิดโหวต "ออกจากป่ากลับล็อบบี้ไหม?" ให้ทั้งทีม (เสียงส่วนใหญ่ชนะ)
	    ผ่าน  -> ฉากจบ (สตอรี่ + ทุกคนเดินเข้าประตู) -> กลับล็อบบี้ (Result "Escape")
	    ไม่ผ่าน -> เล่นต่อโหมดไม่รู้จบ · ประตูยังอยู่ โหวตใหม่ได้หลังพักประตู
	  Remote "EscapeVote": c->s (voteId, yes:boolean) · s->c (payload ของโหวต / { Id, Done = "Yes"/"No" })
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PropBuilder = require(Shared.PropBuilder)

local EscapeService = {}

EscapeService.VoteTime = 25 -- วินาทีที่เปิดให้โหวต
EscapeService.VoteCooldown = 45 -- โหวตไม่ผ่าน -> พักประตูกี่วินาทีก่อนโหวตใหม่
EscapeService.RevealDelay = 13 -- หลังฉาก "99 NIGHTS CONQUERED" จบ ค่อยเปิดประตู
EscapeService.EndingTime = 38 -- ความยาวฉากจบฝั่ง client (สตอรี่ + เดินเข้าประตู + จอสรุป) ก่อนส่งกลับล็อบบี้
EscapeService.GateColor = Color3.fromRGB(255, 214, 130)

local HOSTILE = { "Raid", "Stalker", "Boss", "Wild" }

function EscapeService:Init(ctx)
	self.ctx = ctx
	self.gate = nil
	self.vote = nil
	self.voteId = 0
	self.cool = 0
	self.leaving = false
end

local function voters()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InRun") then
			table.insert(list, p)
		end
	end
	return list
end

---------------------------------------------------------------- ตัวประตู
-- จุดวางประตู: วงรอบกองไฟ (ในเขตปลอดภัย) ที่พื้นโล่ง ไม่ทับสิ่งก่อสร้าง/ของในแคมป์
function EscapeService:FindSpot()
	local camp = self.ctx.CampPosition
	local skip = { Workspace.Terrain }
	for _, name in ipairs({ "Drops", "Animals" }) do
		local f = Workspace:FindFirstChild(name)
		if f then
			table.insert(skip, f)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = skip
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = skip
	local best, bestScore
	for _, r in ipairs({ 32, 38, 27, 44 }) do
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2 + 0.2
			local p = camp + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local hit = Workspace:Raycast(p + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), rp)
			if hit and hit.Instance == Workspace.Terrain then
				local g = hit.Position
				local face = CFrame.lookAt(g, Vector3.new(camp.X, g.Y, camp.Z))
				-- ตัวซุ้ม + ทางเดินหน้าซุ้ม (ฝั่งแคมป์) ต้องโล่ง
				local parts = Workspace:GetPartBoundsInBox(face * CFrame.new(0, 12, -6), Vector3.new(30, 20, 26), op)
				local n = 0
				for _, q in ipairs(parts) do
					if q.CanCollide and q.Transparency < 0.9 then
						n += 1
					end
				end
				local slope = math.abs(g.Y - camp.Y)
				local score = n * 10 + slope
				if not bestScore or score < bestScore then
					best, bestScore = g, score
				end
				if n == 0 and slope < 6 then
					return g
				end
			end
		end
	end
	return best or (camp + Vector3.new(0, 0, 32))
end

function EscapeService:Remove()
	if self.gate then
		self.gate:Destroy()
	end
	self.gate = nil
	self.ctx.State:SetAttribute("EscapeGate", nil)
end

function EscapeService:Spawn(reveal)
	if self.gate and self.gate.Parent then
		return self.gate
	end
	local ctx = self.ctx
	local camp = ctx.CampPosition
	local pos = self:FindSpot()
	local frame = CFrame.lookAt(pos, Vector3.new(camp.X, pos.Y, camp.Z))
	local parent = Workspace:FindFirstChild("World") or Workspace
	local m, veil = PropBuilder.BuildPortal(frame, nil, parent, {
		Name = "EscapeGate", Model = "GateStargate", Width = 26, Color = self.GateColor, NoTag = true,
		Action = "Vote to go home", Label = "Portal Home", Floor = pos.Y,
	})
	if not (m and veil) then
		warn("[AS] escape gate build failed")
		return nil
	end
	-- แกนบางของม่าน = ทิศเดินทะลุ · หันฝั่งหน้าเข้าหาแคมป์
	local s = veil.Size
	local axis = veil.CFrame.LookVector
	if s.X <= s.Y and s.X <= s.Z then
		axis = veil.CFrame.RightVector
	elseif s.Y <= s.X and s.Y <= s.Z then
		axis = veil.CFrame.UpVector
	end
	axis = Vector3.new(axis.X, 0, axis.Z)
	axis = axis.Magnitude > 0.1 and axis.Unit or frame.LookVector
	local toCamp = (camp - veil.Position) * Vector3.new(1, 0, 1)
	if toCamp.Magnitude > 0.1 and axis:Dot(toCamp) < 0 then
		axis = -axis
	end
	local center = veil.Position
	-- ม่านประตูกลับบ้าน = แสงทองสว่าง (ม่านมิติปกติมีชั้นมืดด้านใน ดูเป็นหลุมดำ)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "VeilDeep" then
			d.Color = self.GateColor:Lerp(Color3.new(1, 1, 1), 0.1)
			d.Material = Enum.Material.SmoothPlastic
			d.Transparency = 0.35
		elseif d:IsA("ParticleEmitter") and d.Name == "Portal" then
			d.Enabled = false -- หลุมดำกลางวังวน (ประตูมิติปกติ) -> ประตูกลับบ้านเป็นแสงทองล้วน
		end
	end
	local _, gsize = m:GetBoundingBox()
	local top = pos.Y + gsize.Y + 2
	m:SetAttribute("Center", center)
	m:SetAttribute("Normal", axis)
	m:SetAttribute("Ground", pos.Y)
	-- ลำแสงทองพุ่งขึ้นฟ้า (เห็นจากไกล = รู้ว่าประตูกลับบ้านเปิดแล้ว)
	local beam = Instance.new("Part")
	beam.Name = "SkyBeam"
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch = true, false, false, false
	beam.Material = Enum.Material.Neon
	beam.Color = self.GateColor
	beam.Transparency = 0.55
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(400, 5, 5) -- เริ่มเหนือยอดซุ้ม (ไม่ทะลุกลางม่าน)
	beam.CFrame = CFrame.new(Vector3.new(center.X, top + 200, center.Z)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.CastShadow = false
	beam.Parent = m
	-- ผลึกธาตุ 4 ก้อนลอยรอบซุ้ม: ติดสว่างเมื่อช่วยลูกสัตว์ธาตุนั้นแล้ว (เล่าเรื่องว่าพลังลูกสัตว์เปิดทาง)
	local side = Vector3.new(0, 1, 0):Cross(axis).Unit
	for i, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
		local col = PropBuilder.ElementColor[el]
		local lit = ctx.State:GetAttribute("Spirit" .. el) == true
		local cr = Instance.new("Part")
		cr.Name = "Crystal" .. el
		cr.Anchored, cr.CanCollide, cr.CanQuery, cr.CanTouch = true, false, false, false
		cr.Material = Enum.Material.Neon
		cr.Color = lit and col or col:Lerp(Color3.fromRGB(60, 60, 70), 0.75)
		cr.Transparency = lit and 0.05 or 0.35
		cr.Size = Vector3.new(1.8, 3.6, 1.8)
		local off = side * ((i <= 2) and -1 or 1) * 15 + Vector3.new(0, (i % 2 == 1) and 6 or 15, 0)
		cr.CFrame = CFrame.new(Vector3.new(center.X, pos.Y, center.Z) + off) * CFrame.Angles(0, math.rad(i * 37), math.rad(45))
		cr:SetAttribute("Element", el)
		cr:SetAttribute("Lit", lit)
		cr.Parent = m
		if lit then
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = col, 14, 1.6
			l.Parent = cr
		end
	end
	local prompt = veil:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.HoldDuration = 0.8
		prompt.MaxActivationDistance = 16
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Triggered:Connect(function(player)
			self:StartVote(player)
		end)
	end
	self.gate = m
	ctx.State:SetAttribute("EscapeGate", center)
	if reveal then
		ctx.FireRun("Cinematic", "EscapeGateOpen", { Gate = m, Center = center, Normal = axis, Ground = pos.Y })
		ctx.Broadcast("🌀 A portal home has opened at the edge of camp! Go there and vote to leave — or stay and keep surviving", "Reward")
	end
	return m
end

---------------------------------------------------------------- โหวต
function EscapeService:Counts()
	local v = self.vote
	local list = voters()
	local yes, no = 0, 0
	for _, p in ipairs(list) do
		local c = v and v.Cast[p.UserId]
		if c == true then
			yes += 1
		elseif c == false then
			no += 1
		end
	end
	return yes, no, #list
end

function EscapeService:Payload(p)
	local v = self.vote
	local yes, no, total = self:Counts()
	local mine = v.Cast[p.UserId]
	return {
		Id = v.Id, Left = math.max(0, v.Ends - os.clock()), Yes = yes, No = no, Total = total,
		By = v.ByName, Mine = mine == true and "Yes" or mine == false and "No" or nil,
	}
end

function EscapeService:Push()
	local remote = self.ctx.Remotes.Get("EscapeVote")
	for _, p in ipairs(voters()) do
		remote:FireClient(p, self:Payload(p))
	end
end

function EscapeService:StartVote(player)
	local ctx = self.ctx
	if self.leaving or not player:GetAttribute("InRun") or not ctx.State:GetAttribute("Conquered") then
		return
	end
	if ctx.State:GetAttribute("Phase") == "Ended" then
		return
	end
	if self.vote then
		ctx.Remotes.Get("EscapeVote"):FireClient(player, self:Payload(player)) -- โหวตเปิดอยู่แล้ว: เปิดหน้าต่างให้คนนี้อีกรอบ
		return
	end
	local now = os.clock()
	if now < self.cool then
		ctx.Notify(player, string.format("The portal is recharging — you can vote again in %d seconds", math.ceil(self.cool - now)), "Info")
		return
	end
	self.voteId += 1
	self.vote = { Id = self.voteId, Ends = now + self.VoteTime, Cast = {}, ByName = player.DisplayName }
	ctx.Broadcast(string.format("🌀 %s wants to go home through the portal — vote now!", player.DisplayName), "Reward")
	self:Push()
	local id = self.voteId
	task.spawn(function()
		while self.vote and self.vote.Id == id do
			if os.clock() >= self.vote.Ends then
				local yes, no = self:Counts()
				self:Resolve(yes > no)
				return
			end
			task.wait(0.25)
		end
	end)
end

function EscapeService:Cast(player, id, yes)
	local v = self.vote
	if not v or v.Id ~= id or not player:GetAttribute("InRun") or type(yes) ~= "boolean" then
		return
	end
	v.Cast[player.UserId] = yes
	local y, n, total = self:Counts()
	if y * 2 > total then
		self:Resolve(true) -- เกินครึ่งทีมเห็นด้วยแล้ว
	elseif n * 2 >= total then
		self:Resolve(false) -- ไม่มีทางได้เสียงส่วนใหญ่แล้ว
	else
		self:Push()
	end
end

function EscapeService:Resolve(pass)
	local v = self.vote
	if not v then
		return
	end
	local yes, no = self:Counts()
	self.vote = nil
	local remote = self.ctx.Remotes.Get("EscapeVote")
	for _, p in ipairs(voters()) do
		remote:FireClient(p, { Id = v.Id, Done = pass and "Yes" or "No", Yes = yes, No = no })
	end
	if pass then
		self.ctx.Broadcast(string.format("🌀 The team voted to go home! (Yes %d · No %d)", yes, no), "Reward")
		task.delay(1.2, function()
			self:Leave()
		end)
	else
		self.cool = os.clock() + self.VoteCooldown
		self.ctx.Broadcast(string.format("🌲 The team chose to stay — endless mode continues (Yes %d · No %d)", yes, no), "Info")
	end
end

---------------------------------------------------------------- ฉากจบ -> กลับล็อบบี้
function EscapeService:Leave()
	local ctx = self.ctx
	local S = ctx.Services
	local dir = S.DirectorService
	if self.leaving or not (self.gate and self.gate.Parent) or not dir:IsRunning() then
		return
	end
	self.leaving = true
	dir.runId += 1 -- หยุดวงวันคืน
	dir:SetPhase("Ended", self.EndingTime)
	ctx.State:SetAttribute("Ending", "Escape")
	ctx.State:SetAttribute("BossId", "")
	for _, k in ipairs(HOSTILE) do
		S.AnimalService:ClearKind(k, true)
	end
	local center, normal = self.gate:GetAttribute("Center"), self.gate:GetAttribute("Normal")
	local gy = self.gate:GetAttribute("Ground") or center.Y
	local side = Vector3.new(0, 1, 0):Cross(normal).Unit
	local nights = math.max(0, (dir.night or 1) - 1)
	local spirits = dir:SpiritCount()
	-- ทุกคนที่ยังยืนอยู่: ลุกขึ้น (ล้ม = ช่วยให้ฟื้น) ลงจากหลังสัตว์ แล้วยืนเรียงหน้าประตู หันเข้าหาม่าน
	local alive = {}
	for _, p in ipairs(voters()) do
		local data = S.DataService:Get(p)
		if data then
			data.Escapes = (data.Escapes or 0) + 1
		end
		if not p:GetAttribute("Dead") then
			if p:GetAttribute("Downed") then
				pcall(S.SurvivalService.Revive, S.SurvivalService, p, 1)
			end
			if S.MountService then
				pcall(S.MountService.Dismount, S.MountService, p)
			end
			table.insert(alive, p)
		end
	end
	for i, p in ipairs(alive) do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local row = math.floor((i - 1) / 4)
			local col = (i - 1) % 4 - (math.min(#alive - row * 4, 4) - 1) / 2
			local at = Vector3.new(center.X, gy, center.Z) + normal * (22 + row * 4) + side * col * 4
			root.AssemblyLinearVelocity = Vector3.zero
			char:PivotTo(CFrame.lookAt(at + Vector3.new(0, 3.5, 0), Vector3.new(center.X, gy + 3.5, center.Z)))
		end
		pcall(S.DataService.Save, S.DataService, p)
	end
	ctx.FireRun("Cinematic", "Escape", {
		Gate = self.gate, Center = center, Normal = normal, Ground = gy, Nights = nights, Spirits = spirits,
		Time = self.EndingTime, Camp = ctx.CampPosition,
	})
	task.delay(self.EndingTime, function()
		dir:EndRun({ Result = "Escape", Night = nights })
	end)
end

function EscapeService:Start(ctx)
	local st = ctx.State
	ctx.Remotes.Get("EscapeVote").OnServerEvent:Connect(function(player, id, yes)
		if type(id) == "number" then
			self:Cast(player, id, yes)
		end
	end)
	-- พิชิต 99 คืน (หรือกลับเข้ารอบที่พิชิตแล้ว) -> เปิดประตู · รีเซ็ตรอบ -> เก็บประตู
	st:GetAttributeChangedSignal("Conquered"):Connect(function()
		if st:GetAttribute("Conquered") then
			task.delay(self.RevealDelay, function()
				if st:GetAttribute("Conquered") and ctx.Services.DirectorService:IsRunning() and st:GetAttribute("Phase") ~= "Ended" then
					self:Spawn(true)
				end
			end)
		else
			self:Remove()
		end
	end)
	st:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = st:GetAttribute("Phase")
		if phase == "Lobby" then
			self.leaving = false
			self.vote = nil
			self.cool = 0
			self:Remove()
		elseif phase == "Night" and self.gate and not self.leaving then
			-- ประตูกลับบ้านอยู่แค่ช่วงกลางวันที่พิชิต 99 คืน -> คืนถัดไปเริ่ม = ประตูหาย (เดิมค้างตลอด เกะกะแคมป์)
			--   กำลังโหวตอยู่ = ปล่อยให้โหวตจบก่อน (ผ่าน = กลับบ้าน · ไม่ผ่าน = หาย)
			local function fade()
				if self.leaving or not self.gate then
					return
				end
				self:Remove()
				self.ctx.Broadcast("🌀 The portal home has faded — keep surviving in endless mode", "Info")
			end
			if self.vote then
				task.delay(self.VoteTime + 1, fade)
			else
				fade()
			end
		end
	end)
	-- คนออกกลางโหวต: นับเสียงใหม่ (ทีมเล็กลง อาจได้เสียงส่วนใหญ่แล้ว)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			if self.vote then
				local y, n, total = self:Counts()
				if total == 0 then
					self.vote = nil
				elseif y * 2 > total then
					self:Resolve(true)
				elseif n * 2 >= total then
					self:Resolve(false)
				else
					self:Push()
				end
			end
		end)
	end)
end

return EscapeService
