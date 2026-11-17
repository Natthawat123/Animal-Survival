--[[
	KrathongClient — ฝั่งผู้เล่นของอีเวนต์ลอยกระทง (KrathongService)
	  ประกาศเปิดงาน (แบนเนอร์) · ตัวนับ "🪷 7/20" กลางบนจอ (เฉพาะตอนอยู่ในมิติเทศกาล)
	  เก็บกระทง: ประกาย + "+1" ลอยขึ้น + เสียง · ครบ 20: ฉากขอพรสำเร็จ (พลุ + แบนเนอร์)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UIKit = require(script.Parent.UIKit)
local Cinematics = require(script.Parent.Cinematics)

local KrathongClient = {}
local player = Players.LocalPlayer
local PINK = Color3.fromRGB(255, 160, 210)
local GOLD = Color3.fromRGB(255, 214, 120)

local function sparkle(pos, color, count, speed)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(pos)
	p.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.6, 1.3)
	e.Speed = NumberRange.new(speed or 8, (speed or 8) * 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = p
	e:Emit(count or 30)
	game:GetService("Debris"):AddItem(p, 2)
end

local function floatText(pos, text, color)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos + Vector3.new(0, 2, 0)
	a.Parent = Workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 40)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = a
	bb.Parent = a
	local t = UIKit.Text(bb, { Size = UDim2.fromScale(1, 1), Text = text, TextSize = 28, Font = UIKit.Fonts.Title, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center })
	t:SetAttribute("NoTranslate", true)
	UIKit.TextStroke(t, 2, 0.1)
	TweenService:Create(a, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { WorldPosition = a.WorldPosition + Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(a, 1.3)
end

local function sound(id, vol, pitch)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 0.5
	s.PlaybackSpeed = pitch or 1
	s.Parent = game:GetService("SoundService")
	s:Play()
	game:GetService("Debris"):AddItem(s, 4)
end

function KrathongClient.Init(state, hud)
	local gui = UIKit.Screen("Krathong", 21)
	-- ตัวนับกลางบนจอ (ใต้แถบเวลา)
	local box = UIKit.Frame(gui, { Size = UDim2.fromOffset(220, 50), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118), BackgroundColor3 = Color3.fromRGB(40, 22, 44), BackgroundTransparency = 0.15, Visible = false })
	UIKit.AutoScale(box)
	UIKit.Corner(box, 25)
	UIKit.Stroke(box, PINK, 2.5, 0)
	local count = UIKit.Text(box, { Size = UDim2.fromScale(1, 1), Text = "", TextSize = 26, Font = UIKit.Fonts.Title, TextColor3 = Color3.fromRGB(255, 236, 246), TextXAlignment = Enum.TextXAlignment.Center })
	count:SetAttribute("NoTranslate", true)
	local scale = Instance.new("UIScale")
	scale.Parent = box
	local max = 20
	local function refresh()
		local n = player:GetAttribute("Krathongs") or 0
		count.Text = string.format("🪷 %d / %d", n, max)
		count.TextColor3 = n >= max and GOLD or Color3.fromRGB(255, 236, 246)
	end
	player:GetAttributeChangedSignal("Krathongs"):Connect(refresh)
	refresh()
	-- โชว์เฉพาะตอนอยู่ในมิติเทศกาล (Y > 3200)
	RunService.Heartbeat:Connect(function()
		local cam = Workspace.CurrentCamera
		local p = cam and cam.CFrame.Position
		box.Visible = p ~= nil and p.Y > 3200 and math.abs(p.X) < 6000 and math.abs(p.Z) < 6000 and player:GetAttribute("InRun") == true
	end)

	Remotes.Get("WorldEvent").OnClientEvent:Connect(function(kind, d)
		d = d or {}
		if kind == "Krathong" then
			max = d.Max or max
			refresh()
			Cinematics.Banner("LOY KRATHONG FESTIVAL", "A big portal opened in the wilds · Tonight only", PINK, 4.5, { Size = 58, Y = 0.2 })
			sound("rbxassetid://9116395085", 0.5, 1.1)
		elseif kind == "KrathongGot" then
			max = d.Max or max
			if d.Position then
				sparkle(d.Position + Vector3.new(0, 1.5, 0), PINK, 34, 7)
				floatText(d.Position, "+1 🪷", PINK)
			end
			sound("rbxassetid://17208319162", 0.55, 1.15)
			scale.Scale = 1.25
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			refresh()
		elseif kind == "KrathongWish" then
			Cinematics.Banner("WISH GRANTED", "You collected every krathong · Legendary chest + 10 Ruby", GOLD, 5, { Size = 62, Y = 0.24 })
			sound("rbxassetid://125706237686412", 0.6, 1)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				for k = 0, 5 do
					task.delay(k * 0.25, function()
						sparkle(root.Position + Vector3.new(math.random(-14, 14), 18 + math.random(0, 10), math.random(-14, 14)), k % 2 == 0 and GOLD or PINK, 60, 18)
					end)
				end
			end
		end
	end)
end

return KrathongClient
