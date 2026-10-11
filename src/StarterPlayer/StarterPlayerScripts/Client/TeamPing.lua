--[[
	TeamPing — ปิงบอกเพื่อน
	  PC: กด G = ปิงจุดที่เมาส์เล็ง (ยกเว้นตอนยืนหน้าเครื่องย่อยที่ใช้ G อยู่แล้ว) · มือถือ: ปุ่ม 📍 ข้างการ์ดกองไฟ (ปิงจุดกลางจอ)
	  ชนิด (server ตัดสิน): Enemy แดง = เล็งสัตว์ · Item เหลือง = ของบนพื้น/หีบ · Go ฟ้า = "มาที่นี่"
	  ทุกคนในทีมเห็น ~8 วิ: ป้ายลอย (ไอคอน + ชื่อคนปิง + ระยะ), จุดบนเข็มทิศ, จุดบนแผนที่ใหญ่ + เสียงเบาๆ
	  จำกัด 1 ครั้ง / 1.5 วิ (server ตรวจซ้ำ)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UIKit = require(script.Parent.UIKit)

local TeamPing = {}
local player = Players.LocalPlayer
local C = UIKit.Colors

local DURATION = 8
local COOLDOWN = 1.5
local KINDS = {
	Enemy = { Color = Color3.fromRGB(255, 80, 80), Icon = "⚠", Text = "ศัตรู!" },
	Item = { Color = Color3.fromRGB(255, 214, 70), Icon = "💰", Text = "ของตรงนี้" },
	Go = { Color = Color3.fromRGB(80, 170, 255), Icon = "📍", Text = "มาที่นี่" },
}

local active = {} -- [fromUserId] = { Billboard, Attachment, MapMarker, Target, Position, Expire, Label }
local lastSend = 0
local deps = {}

local function out()
	return not player:GetAttribute("InRun") or player:GetAttribute("Dead")
end

-- เล็ง: เมาส์ (PC) หรือกลางจอ (มือถือ)
local function aim(useCenter)
	local cam = Workspace.CurrentCamera
	local p = useCenter and (cam.ViewportSize / 2) or UserInputService:GetMouseLocation()
	local ray = cam:ViewportPointToRay(p.X, p.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, cam }
	local res = Workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
	if res then
		return res.Position, res.Instance
	end
	return nil
end

function TeamPing.Send(useCenter)
	if out() then
		return
	end
	local now = os.clock()
	if now - lastSend < COOLDOWN then
		return
	end
	local pos, inst = aim(useCenter)
	if not pos then
		return
	end
	lastSend = now
	Remotes.Get("TeamPing"):FireServer(pos, inst)
end

local function clear(uid)
	local p = active[uid]
	if not p then
		return
	end
	active[uid] = nil
	if p.Attachment then
		p.Attachment:Destroy()
	end
	if p.Billboard then
		p.Billboard:Destroy()
	end
	if p.MapMarker then
		p.MapMarker:Destroy()
	end
	if deps.HUD and deps.HUD.ExtraPOI then
		deps.HUD.ExtraPOI["ping_" .. uid] = nil
	end
end

local function targetPos(p)
	local t = p.Target
	if t and t.Parent then
		local ok, cf = pcall(t.GetPivot, t)
		if ok and cf then
			return cf.Position
		end
	end
	return p.Position
end

local function show(data)
	if type(data) ~= "table" or typeof(data.Position) ~= "Vector3" then
		return
	end
	local spec = KINDS[data.Kind] or KINDS.Go
	local uid = tonumber(data.From) or 0
	clear(uid)
	local target = typeof(data.Target) == "Instance" and data.Target:IsA("PVInstance") and data.Target or nil
	local att = Instance.new("Attachment")
	att.Name = "Ping"
	att.WorldPosition = data.Position
	att.Parent = Workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(150, 64)
	bb.StudsOffsetWorldSpace = Vector3.new(0, target and 4 or 2.5, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 3000
	bb.Adornee = att
	bb.Parent = att
	local icon = UIKit.Text(bb, { Size = UDim2.new(1, 0, 0, 34), Text = spec.Icon, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = spec.Color })
	local label = UIKit.Text(bb, {
		Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 34), TextSize = 15, Font = UIKit.Fonts.Black, TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = spec.Color, Text = "",
	})
	-- เด้งตอนขึ้น
	local sc = Instance.new("UIScale")
	sc.Scale = 0.4
	sc.Parent = icon
	UIKit.Tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	local entry = {
		Attachment = att, Billboard = bb, Label = label, Target = target, Position = data.Position, Expire = os.clock() + DURATION,
		Name = tostring(data.Name or "?"), Spec = spec,
	}
	-- แผนที่ใหญ่
	local map = deps.Map and deps.Map.MapFrame
	if map then
		entry.MapMarker = UIKit.Text(map, {
			Size = UDim2.fromOffset(24, 24), Text = spec.Icon, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = spec.Color, ZIndex = 6,
		})
	end
	active[uid] = entry
	-- เข็มทิศ
	if deps.HUD and deps.HUD.ExtraPOI then
		deps.HUD.ExtraPOI["ping_" .. uid] = { Position = data.Position, Icon = spec.Icon, Color = spec.Color, Expire = entry.Expire }
	end
	if deps.Sound then
		pcall(deps.Sound.Play, "Notify", data.Kind == "Enemy" and 0.9 or 1.35)
	end
	if uid ~= player.UserId and deps.HUD and deps.HUD.Notify then
		deps.HUD.Notify(string.format("%s %s: %s", spec.Icon, entry.Name, spec.Text), "Info")
	end
end

local function tick()
	local now = os.clock()
	local char = player.Character
	local me = char and char:GetPivot().Position
	local state = deps.State
	local size = state and state:GetAttribute("MapSize") or 6144
	for uid, p in pairs(active) do
		if now > p.Expire or not player:GetAttribute("InRun") then
			clear(uid)
		else
			local pos = targetPos(p)
			p.Attachment.WorldPosition = pos
			if deps.HUD and deps.HUD.ExtraPOI and deps.HUD.ExtraPOI["ping_" .. uid] then
				deps.HUD.ExtraPOI["ping_" .. uid].Position = pos
			end
			local dist = me and math.floor((pos - me).Magnitude * 0.28) or 0
			p.Label.Text = string.format("%s · %s %dm", p.Name, p.Spec.Text, dist)
			-- จางหายช่วง 1.5 วิสุดท้าย
			local left = p.Expire - now
			if left < 1.5 then
				for _, d in ipairs(p.Billboard:GetDescendants()) do
					if d:IsA("TextLabel") then
						d.TextTransparency = 1 - left / 1.5
					end
				end
			end
			if p.MapMarker then
				p.MapMarker.Position = UDim2.new(pos.X / size + 0.5, -12, pos.Z / size + 0.5, -12)
			end
		end
	end
end

function TeamPing.Init(state, hud, map, sound)
	deps.State, deps.HUD, deps.Map, deps.Sound = state, hud, map, sound
	Remotes.Get("TeamPing").OnClientEvent:Connect(show)
	-- ปุ่ม G ชนกับปุ่ม "โยนวัตถุดิบลงเครื่องย่อย" (ProximityPrompt) -> ตอนปุ่มนั้นขึ้นอยู่ ไม่ปิง
	local gPrompts = {}
	local PPS = game:GetService("ProximityPromptService")
	PPS.PromptShown:Connect(function(prompt)
		if prompt.KeyboardKeyCode == Enum.KeyCode.G then
			gPrompts[prompt] = true
		end
	end)
	PPS.PromptHidden:Connect(function(prompt)
		gPrompts[prompt] = nil
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.G then
			return
		end
		for prompt in pairs(gPrompts) do
			if not (prompt.Parent and prompt.Enabled) then
				gPrompts[prompt] = nil
			end
		end
		if next(gPrompts) == nil then
			TeamPing.Send(false)
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			tick()
		end
	end)
	-- มือถือ: ปุ่ม 📍 ใต้ปุ่มแผนที่ ข้างการ์ดกองไฟ (ปิงจุดกลางจอ)
	if UIKit.IsTouch and hud and hud.RightCard then
		local b = UIKit.ColorButton(hud.RightCard, C.Blue, { Size = UDim2.fromOffset(48, 48), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0, -12, 0, 116), Text = "📍", TextSize = 26 }, function()
			TeamPing.Send(true)
		end)
		b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
		local function upd()
			b.Visible = not out() and not player:GetAttribute("Downed")
		end
		for _, a in ipairs({ "InRun", "Downed", "Dead" }) do
			player:GetAttributeChangedSignal(a):Connect(upd)
		end
		upd()
	end
end

return TeamPing
