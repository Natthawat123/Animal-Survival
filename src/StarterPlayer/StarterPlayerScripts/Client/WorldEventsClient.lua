--[[
	WorldEventsClient — ฝั่งผู้เล่นของ EventService / SanctumService (Remotes "WorldEvent")
	  ☄ อุกกาบาต: ลูกไฟพุ่งจากฟ้าพร้อมหางไฟ -> ระเบิด/คลื่นกระแทก/ฝุ่น/แสงวาบ/จอสั่น (วาดในเครื่องผู้เล่นเอง ลื่นทุกจอ)
	  ป้ายประกาศ (Cinematics.Banner) · หมุดบนแผนที่ (MapUI.ExtraMarkers) · หมุดลอยบอกระยะในโลก
	  วิหารโบราณ: ป้ายคำใบ้ตอนเข้าใกล้ครั้งแรก + ค้นพบบนแผนที่ + นับถอยหลังปริศนา
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UIKit = require(script.Parent.UIKit)
local Cinematics = require(script.Parent.Cinematics)

local WorldEventsClient = {}
local player = Players.LocalPlayer
local C = UIKit.Colors
local ELEMENTS = { "Earth", "Water", "Air", "Fire" }
local THAI = UIKit.ElementThai
local EVENTS = {
	{ Kind = "Meteor", Icon = "☄", Color = Color3.fromRGB(255, 170, 80), Name = "อุกกาบาต" },
	{ Kind = "Migration", Icon = "🦌", Color = Color3.fromRGB(230, 200, 140), Name = "ฝูงสัตว์อพยพ" },
	{ Kind = "Supply", Icon = "📦", Color = Color3.fromRGB(255, 90, 70), Name = "หีบเสบียง" },
}

local fxFolder
local function folder()
	if not (fxFolder and fxFolder.Parent) then
		fxFolder = Instance.new("Folder")
		fxFolder.Name = "WorldEventFX"
		fxFolder.Parent = Workspace
	end
	return fxFolder
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "Shape" then
			p[k] = v
		end
	end
	p.Parent = props.Parent or folder()
	return p
end

local function sound3d(at, id, volume, speed, maxDist)
	local holder = part({ Size = Vector3.new(1, 1, 1), Transparency = 1, Position = at })
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 1
	s.PlaybackSpeed = speed or 1
	s.RollOffMinDistance = 40
	s.RollOffMaxDistance = maxDist or 1500
	s.Parent = holder
	s:Play()
	task.delay(8, function()
		holder:Destroy()
	end)
end

local function myPos()
	local c = player.Character
	return c and c:GetPivot().Position
end

---------------------------------------------------------------- ☄ อุกกาบาต
local function impact(pos, col, combat)
	local ball = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), Position = pos + Vector3.new(0, 3, 0), Color = col, Material = Enum.Material.SmoothPlastic })
	TweenService:Create(ball, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(70, 70, 70), Transparency = 1 }):Play()
	local core = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(24, 24, 24), Position = pos + Vector3.new(0, 3, 0), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic })
	TweenService:Create(core, TweenInfo.new(0.5), { Size = Vector3.new(2, 2, 2), Transparency = 1 }):Play()
	local ring = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 8, 8), CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = col, Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	TweenService:Create(ring, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, 170, 170), Transparency = 1 }):Play()
	local l = Instance.new("PointLight")
	l.Color = col
	l.Range = 90
	l.Brightness = 12
	l.Parent = core
	TweenService:Create(l, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	-- ฝุ่น + ประกายไฟ
	local emitterHost = part({ Size = Vector3.new(6, 1, 6), Transparency = 1, Position = pos + Vector3.new(0, 2, 0) })
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Lifetime = NumberRange.new(2.5, 4)
	dust.Speed = NumberRange.new(25, 55)
	dust.SpreadAngle = Vector2.new(85, 85)
	dust.Drag = 2.5
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 26) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	dust.Color = ColorSequence.new(Color3.fromRGB(110, 96, 86))
	dust.Enabled = false
	dust.Parent = emitterHost
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Lifetime = NumberRange.new(1, 2)
	sparks.Speed = NumberRange.new(40, 90)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Acceleration = Vector3.new(0, -60, 0)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	sparks.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
	sparks.Enabled = false
	sparks.Parent = emitterHost
	dust:Emit(45)
	sparks:Emit(80)
	-- เศษหินกระเด็น
	for _ = 1, 10 do
		local s = math.random(10, 26) / 10
		local rock = part({ Size = Vector3.new(s, s, s), Position = pos + Vector3.new(math.random(-3, 3), 4, math.random(-3, 3)), Color = Color3.fromRGB(50, 44, 42), Material = Enum.Material.Slate })
		rock.Anchored = false
		rock.AssemblyLinearVelocity = Vector3.new(math.random(-60, 60), math.random(50, 95), math.random(-60, 60))
		rock.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		task.delay(2.5, function()
			TweenService:Create(rock, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		end)
		task.delay(3.2, function()
			rock:Destroy()
		end)
	end
	sound3d(pos, "rbxasset://sounds/impact_explosion_03.mp3", 3, 0.7, 2200)
	task.delay(5, function()
		ball:Destroy()
		core:Destroy()
		ring:Destroy()
		emitterHost:Destroy()
	end)
	local me = myPos()
	if me and combat and combat.Shake then
		local power = math.clamp(1 - (me - pos).Magnitude / 700, 0, 1)
		if power > 0.05 then
			combat.Shake(power * 1.3, 0.4 + power)
		end
	end
end

local function meteor(d, combat)
	local col = C.Element[d.Element] or Color3.fromRGB(255, 140, 60)
	local ground = d.Position
	local fall = d.Fall or 12
	local remaining = (d.ImpactAt or 0) - Workspace:GetServerTimeNow()
	if remaining < -2 then
		return
	end
	if remaining < 0.4 then
		impact(ground, col, combat)
		return
	end
	local yaw = d.Yaw or 0
	local start = ground + Vector3.new(math.cos(yaw) * 950, 1150, math.sin(yaw) * 950)
	local dir = (ground - start).Unit
	local rock = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(14, 14, 14), Position = start, Color = col, Material = Enum.Material.SmoothPlastic })
	local shell = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(11, 11, 11), Position = start, Color = Color3.fromRGB(40, 30, 28), Material = Enum.Material.Slate })
	local halo = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(30, 30, 30), Position = start, Color = col, Material = Enum.Material.SmoothPlastic, Transparency = 0.75 })
	local up = math.abs(dir.Y) < 0.99 and Vector3.yAxis or Vector3.xAxis
	local side = dir:Cross(up).Unit
	local a0 = Instance.new("Attachment")
	a0.Position = side * 7
	a0.Parent = rock
	local a1 = Instance.new("Attachment")
	a1.Position = -side * 7
	a1.Parent = rock
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 1.4
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), col)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
	trail.Parent = rock
	local fire = Instance.new("Fire")
	fire.Size = 25
	fire.Heat = 25
	fire.Color = col
	fire.SecondaryColor = Color3.fromRGB(255, 220, 160)
	fire.Parent = rock
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 45
	smoke.Lifetime = NumberRange.new(2, 3.5)
	smoke.Speed = NumberRange.new(2, 5)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 9), NumberSequenceKeypoint.new(1, 30) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 76, 70))
	smoke.Parent = rock
	local l = Instance.new("PointLight")
	l.Color = col
	l.Range = 70
	l.Brightness = 5
	l.Parent = rock
	local whoosh = Instance.new("Sound")
	whoosh.SoundId = "rbxasset://sounds/action_falling.ogg"
	whoosh.Volume = 2
	whoosh.PlaybackSpeed = 0.5
	whoosh.Looped = true
	whoosh.RollOffMinDistance = 60
	whoosh.RollOffMaxDistance = 1600
	whoosh.Parent = rock
	whoosh:Play()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local left = (d.ImpactAt or 0) - Workspace:GetServerTimeNow()
		local t = math.clamp(1 - left / fall, 0, 1)
		local p = start:Lerp(ground + Vector3.new(0, 4, 0), t ^ 1.35)
		local cf = CFrame.lookAt(p, p + dir) * CFrame.Angles(0, 0, t * 20)
		rock.CFrame = cf
		shell.CFrame = cf * CFrame.new(0, 0, -2)
		halo.CFrame = cf
		if t >= 1 then
			conn:Disconnect()
			rock:Destroy()
			shell:Destroy()
			halo:Destroy()
			impact(ground, col, combat)
		end
	end)
	task.delay(fall + 4, function()
		if conn.Connected then
			conn:Disconnect()
		end
		for _, x in ipairs({ rock, shell, halo }) do
			if x.Parent then
				x:Destroy()
			end
		end
	end)
end

---------------------------------------------------------------- หมุดลอยในโลก (ไอคอน + ระยะ)
local pins = {}
local function updatePins(state)
	local me = myPos()
	local inRun = player:GetAttribute("InRun")
	for _, ev in ipairs(EVENTS) do
		local pos = state:GetAttribute("Event_" .. ev.Kind)
		local pin = pins[ev.Kind]
		if pos and inRun and me then
			if not pin then
				local holder = part({ Size = Vector3.new(1, 1, 1), Transparency = 1, Position = pos })
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.fromOffset(120, 54)
				bb.AlwaysOnTop = true
				bb.LightInfluence = 0
				bb.StudsOffsetWorldSpace = Vector3.new(0, 14, 0)
				bb.Parent = holder
				local t = Instance.new("TextLabel")
				t.Size = UDim2.fromScale(1, 1)
				t.BackgroundTransparency = 1
				t.Font = Enum.Font.BuilderSansBold
				t.TextSize = 20
				t.TextStrokeTransparency = 0.3
				t.TextColor3 = ev.Color
				t.Parent = bb
				pin = { Holder = holder, Label = t }
				pins[ev.Kind] = pin
			end
			if ev.Kind == "Meteor" then
				pin.Label.TextColor3 = C.Element[state:GetAttribute("Event_MeteorElement")] or ev.Color
			end
			pin.Holder.Position = pos
			local dist = (me - pos).Magnitude
			pin.Label.Text = string.format("%s %s\n%d ม.", ev.Icon, ev.Name, math.floor(dist / 3.5))
			pin.Holder.Parent = dist > 45 and folder() or nil
		elseif pin then
			pin.Holder:Destroy()
			pins[ev.Kind] = nil
		end
	end
end

---------------------------------------------------------------- เริ่ม
function WorldEventsClient.Init(state, hud, mapUI, combat)
	local gui = UIKit.Screen("WorldEvents", 22)
	local timerFrame = UIKit.Frame(gui, { Size = UDim2.fromOffset(420, 44), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.13, 0), BackgroundTransparency = 1 })
	UIKit.AutoScale(timerFrame)
	local timer = UIKit.Text(timerFrame, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Bold, TextSize = 28, TextStrokeTransparency = 0.3, Text = "", Visible = false })

	Remotes.Get("WorldEvent").OnClientEvent:Connect(function(kind, d)
		d = d or {}
		local ok, err = pcall(function()
			if kind == "Meteor" then
				local col = C.Element[d.Element] or C.Fire
				Cinematics.Banner("METEOR STRIKE", string.format("☄ อุกกาบาตธาตุ%sกำลังพุ่งลงสู่ผืนป่า — ไปขุดแกนผลึกก่อนพลบค่ำ!", THAI[d.Element] or ""), col, 3.5, { Size = 58, Y = 0.2 })
				meteor(d, combat)
			elseif kind == "MeteorClaimed" then
				local col = C.Element[d.Element] or C.Gold
				local b = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), Position = d.Position, Color = col, Material = Enum.Material.SmoothPlastic })
				TweenService:Create(b, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(26, 26, 26), Transparency = 1 }):Play()
				task.delay(1, function()
					b:Destroy()
				end)
				sound3d(d.Position, "rbxasset://sounds/volume_slider.ogg", 1.5, 1.4, 300)
			elseif kind == "Migration" then
				Cinematics.Banner("THE GREAT MIGRATION", "🦌 ฝูงกวางและกระต่ายกำลังเดินผ่านใกล้แคมป์ — โอกาสล่าเนื้อและหนังสัตว์!", Color3.fromRGB(230, 200, 140), 3.5, { Size = 54, Y = 0.2 })
			elseif kind == "Supply" then
				Cinematics.Banner("SUPPLY DROP", "📦 หีบเสบียงร่อนลงจากฟ้า — มองหาควันสีแดง แล้วไปเปิดก่อนพลบค่ำ", Color3.fromRGB(255, 110, 80), 3.5, { Size = 58, Y = 0.2 })
			elseif kind == "SanctumOpened" then
				local col = C.Element[d.Element] or C.Gold
				Cinematics.Banner("SEAL BROKEN", string.format("🏛 ผนึกวิหาร%sคลายแล้ว — ห้องผนึกเปิดออก หีบศักดิ์สิทธิ์รออยู่ข้างใน", THAI[d.Element] or ""), col, 4, { Size = 64 })
				local me = myPos()
				if me and d.Position and (me - d.Position).Magnitude < 250 and combat and combat.Shake then
					combat.Shake(0.6, 2.5)
				end
			end
		end)
		if not ok then
			warn("[AS] world event", kind, err)
		end
	end)

	-- หมุดบนแผนที่
	if mapUI then
		mapUI.ExtraMarkers = mapUI.ExtraMarkers or {}
		table.insert(mapUI.ExtraMarkers, function(marker, place, discovered)
			for _, ev in ipairs(EVENTS) do
				local pos = state:GetAttribute("Event_" .. ev.Kind)
				local m = marker("ev_" .. ev.Kind, ev.Icon, ev.Color, 22)
				m.Visible = pos ~= nil
				if pos then
					if ev.Kind == "Meteor" then
						m.TextColor3 = C.Element[state:GetAttribute("Event_MeteorElement")] or ev.Color
					end
					place(m, pos)
				end
			end
			for _, el in ipairs(ELEMENTS) do
				local pos = state:GetAttribute("Sanctum_" .. el)
				local key = "Sanctum_" .. el
				if pos and discovered[key] then
					local m = marker(key, "🏛", C.Element[el], 20)
					m.Text = state:GetAttribute("Sanctum" .. el .. "Solved") and "✓" or "🏛"
					place(m, pos)
				end
			end
		end)
	end

	-- ค้นพบวิหาร / ป้ายคำใบ้ / นับถอยหลัง / หมุดลอย
	local hinted = {}
	state:GetAttributeChangedSignal("Phase"):Connect(function()
		if state:GetAttribute("Phase") == "Lobby" then
			table.clear(hinted)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(function()
				updatePins(state)
				local me = myPos()
				local showTimer = false
				if me and player:GetAttribute("InRun") then
					for _, el in ipairs(ELEMENTS) do
						local pos = state:GetAttribute("Sanctum_" .. el)
						if pos then
							local dist = ((me - pos) * Vector3.new(1, 0, 1)).Magnitude
							local key = "Sanctum_" .. el
							local discovered = hud and hud.Discovered
							if discovered and not discovered[key] and dist < 320 then
								discovered[key] = true
								if hud.Notify then
									hud.Notify("🗺 ค้นพบ: วิหารโบราณแห่ง" .. (THAI[el] or ""), "Reward")
								end
							end
							if dist < 140 and not hinted[el] then
								hinted[el] = true
								local solved = state:GetAttribute("Sanctum" .. el .. "Solved")
								Cinematics.Banner("ANCIENT SANCTUM", solved and ("วิหารโบราณแห่ง" .. THAI[el] .. " · ผนึกถูกคลายไปแล้วในรอบนี้")
									or ("วิหารโบราณแห่ง" .. THAI[el] .. " · จำลำดับแสงบนเสารูน 3 ต้น แล้วปลุกให้ถูกลำดับภายใน 30 วินาที"), C.Element[el], 4.5, { Size = 60, Y = 0.2 })
							end
							local deadline = state:GetAttribute("Sanctum" .. el .. "Deadline")
							if deadline and dist < 160 then
								local left = math.max(0, deadline - Workspace:GetServerTimeNow())
								timer.Text = string.format("⏳ ปลุกเสารูนให้ครบ: %d วินาที", math.ceil(left))
								timer.TextColor3 = left < 8 and Color3.fromRGB(255, 90, 80) or (C.Element[el] or C.Gold)
								showTimer = true
							end
						end
					end
				end
				timer.Visible = showTimer
			end)
			if not ok then
				warn("[AS] world events loop", err)
			end
		end
	end)
end

return WorldEventsClient
