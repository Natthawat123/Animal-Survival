--[[
	NavArrows — ป้ายนำทางบนจอ (แทนการอ่านทิศ N/E/S/W บนเข็มทิศ ซึ่งดูยากบนมือถือจอเล็ก)
	  เป้าอยู่ในจอ  = ไอคอนลอยตรงตำแหน่งจริง (มองทะลุต้นไม้) + ระยะ
	  เป้าอยู่นอกจอ = ไอคอนเกาะขอบจอฝั่งที่ต้องหันไป + ลูกศรชี้ทาง (อยู่ข้างหลัง = ขอบล่าง)
	  เลื่อนนุ่มๆ (lerp) ไม่กระตุกตอนหันกล้อง · มือถือไอคอนใหญ่ขึ้น
	เป้าตายตัว: กองไฟแคมป์ 🔥 (ซ่อนตอนอยู่ในแคมป์) · ระบบอื่นเพิ่มได้: NavArrows.Set(key, spec) / NavArrows.Remove(key)
	  spec = { Position = Vector3, Icon = "📍", Color = Color3, Label = fn(studs) -> ข้อความ, HideWithin = studs, Order = เลขเรียง }
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UIKit = require(script.Parent.UIKit)

local NavArrows = {}
local player = Players.LocalPlayer
local targets = {} -- [key] = spec
local widgets = {} -- [key] = { Root, Badge, Icon, Label, Arrow, Pos, LastText }
local gui

local CAMP_COLOR = Color3.fromRGB(255, 150, 60)

function NavArrows.Set(key, spec)
	targets[key] = spec
end

function NavArrows.Remove(key)
	targets[key] = nil
	local w = widgets[key]
	if w then
		w.Root:Destroy()
		widgets[key] = nil
	end
end

local function makeWidget(key, spec)
	local touch = UIKit.IsTouch
	local badgeSize = touch and 46 or 38
	local root = Instance.new("Frame")
	root.Name = "Nav_" .. key
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Size = UDim2.fromOffset(badgeSize, badgeSize)
	root.ZIndex = spec.Order or 1
	root.Parent = gui
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.5, 0.5)
	badge.Size = UDim2.fromScale(1, 1)
	badge.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	badge.BackgroundTransparency = 0.25
	badge.Parent = root
	UIKit.Corner(badge, badgeSize)
	local stroke = Instance.new("UIStroke")
	stroke.Color = spec.Color
	stroke.Thickness = touch and 3 or 2.5
	stroke.Parent = badge
	local icon = UIKit.Text(badge, { Size = UDim2.fromScale(1, 1), Text = spec.Icon, TextSize = touch and 26 or 21, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = spec.Color })
	icon:SetAttribute("NoTranslate", true)
	local label = UIKit.Text(root, {
		Size = UDim2.fromOffset(150, touch and 22 or 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 3),
		TextSize = touch and 17 or 14, Font = UIKit.Fonts.Black, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = spec.Color, Text = "",
	})
	UIKit.TextStroke(label, 2, 0.2)
	local arrow = UIKit.Text(root, {
		Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), Text = "▲", TextSize = touch and 22 or 18,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = spec.Color, Visible = false,
	})
	arrow:SetAttribute("NoTranslate", true)
	UIKit.TextStroke(arrow, 2, 0.2)
	local w = { Root = root, Icon = icon, Label = label, Arrow = arrow, Stroke = stroke, Radius = badgeSize / 2 }
	widgets[key] = w
	return w
end

-- จุดตัดของเส้นจากกลางจอไปทิศ dir กับกรอบ [lo, hi]
local function edgePoint(c, dir, lo, hi)
	local t = math.huge
	if dir.X > 1e-4 then
		t = math.min(t, (hi.X - c.X) / dir.X)
	elseif dir.X < -1e-4 then
		t = math.min(t, (lo.X - c.X) / dir.X)
	end
	if dir.Y > 1e-4 then
		t = math.min(t, (hi.Y - c.Y) / dir.Y)
	elseif dir.Y < -1e-4 then
		t = math.min(t, (lo.Y - c.Y) / dir.Y)
	end
	return c + dir * t
end

local function step(dt)
	local cam = Workspace.CurrentCamera
	local char = player.Character
	local inRun = player:GetAttribute("InRun") and not player:GetAttribute("Dead")
	if not (cam and char and inRun) then
		for _, w in pairs(widgets) do
			w.Root.Visible = false
		end
		return
	end
	local me = char:GetPivot().Position
	local vp = cam.ViewportSize
	local touch = UIKit.IsTouch
	-- ขอบที่ไอคอนเกาะได้ (เว้นแถบบน/ฮอตบาร์ล่าง/ปุ่มมือถือ)
	local lo = Vector2.new(touch and 70 or 56, touch and 96 or 84)
	local hi = Vector2.new(vp.X - (touch and 70 or 56), vp.Y - (touch and 150 or 130))
	local center = (lo + hi) / 2
	local alpha = 1 - math.exp(-dt * 16)
	for key, spec in pairs(targets) do
		local w = widgets[key] or makeWidget(key, spec)
		local pos = spec.Position
		local flat = pos and ((pos - me) * Vector3.new(1, 0, 1)).Magnitude or 0
		if not pos or (spec.HideWithin and flat < spec.HideWithin) then
			w.Root.Visible = false
			w.Pos = nil
		else
			local world = pos + Vector3.new(0, spec.Lift or 6, 0)
			local sp, onScreen = cam:WorldToViewportPoint(world)
			local target, dir
			local p = Vector2.new(sp.X, sp.Y)
			if onScreen and sp.Z > 0 and p.X >= lo.X and p.X <= hi.X and p.Y >= lo.Y and p.Y <= hi.Y then
				target = p
			else
				-- ทิศในมุมกล้อง (ใช้ได้ทั้งข้างหน้า/ข้างหลัง) -> ทิศบนจอ
				local rel = cam.CFrame:PointToObjectSpace(world)
				dir = Vector2.new(rel.X, -rel.Y)
				if rel.Z > 0 then
					-- อยู่ข้างหลัง: ดันลงขอบล่างให้รู้ว่าต้องหันกลับ
					dir = Vector2.new(rel.X, math.max(math.abs(rel.X) * 0.6, 1) + math.max(-rel.Y, 0))
				end
				if dir.Magnitude < 1e-3 then
					dir = Vector2.new(0, 1)
				end
				dir = dir.Unit
				target = edgePoint(center, dir, lo, hi)
			end
			w.Pos = w.Pos and w.Pos:Lerp(target, alpha) or target
			w.Root.Visible = true
			w.Root.Position = UDim2.fromOffset(w.Pos.X, w.Pos.Y)
			if dir then
				w.Arrow.Visible = true
				local off = dir * (w.Radius + 12)
				w.Arrow.Position = UDim2.new(0.5, off.X, 0.5, off.Y)
				w.Arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
			else
				w.Arrow.Visible = false
			end
			local text = spec.Label and spec.Label(flat) or string.format("%dm", math.floor(flat * 0.28))
			if text ~= w.LastText then
				w.LastText = text
				w.Label.Text = text
			end
			local col = spec.LabelColor and spec.LabelColor(flat) or spec.Color
			w.Label.TextColor3 = col
		end
	end
	for key, w in pairs(widgets) do
		if not targets[key] then
			w.Root:Destroy()
			widgets[key] = nil
		end
	end
end

function NavArrows.Init(state)
	gui = UIKit.Screen("NavArrows", 4, true) -- เต็มจอ (ตำแหน่งตรงกับ WorldToViewportPoint)
	-- กองไฟแคมป์: ไอคอน 🔥 + ระยะ · เข้ามาในลานแคมป์แล้วซ่อน
	local function updCamp()
		local camp = state:GetAttribute("CampPos")
		if camp then
			NavArrows.Set("camp", {
				Position = camp, Icon = "🔥", Color = CAMP_COLOR, HideWithin = 110, Order = 1, Lift = 8,
				Label = function(studs)
					return string.format("Camp %dm", math.floor(studs * 0.28))
				end,
			})
		else
			NavArrows.Remove("camp")
		end
	end
	state:GetAttributeChangedSignal("CampPos"):Connect(updCamp)
	updCamp()
	-- เสาแสงส้มเหนือกองไฟ: เห็นจากไกลทะลุป่า (ใกล้แคมป์ = ซ่อน ไม่บังฉากแคมป์)
	local beam = Instance.new("Part")
	beam.Name = "CampBeacon"
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch, beam.CastShadow = true, false, false, false, false
	beam.Material = Enum.Material.Neon
	beam.Color = CAMP_COLOR
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(220, 2.2, 2.2)
	beam.Transparency = 1
	beam.Parent = Workspace.CurrentCamera
	RunService.RenderStepped:Connect(function(dt)
		step(dt)
		local camp = state:GetAttribute("CampPos")
		local char = player.Character
		local show = camp and char and player:GetAttribute("InRun") and ((char:GetPivot().Position - camp) * Vector3.new(1, 0, 1)).Magnitude > 220
		if beam.Parent ~= Workspace.CurrentCamera then
			beam.Parent = Workspace.CurrentCamera
		end
		if camp then
			beam.CFrame = CFrame.new(camp + Vector3.new(0, 125, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		end
		local goal = show and 0.55 or 1
		beam.Transparency += (goal - beam.Transparency) * math.min(1, dt * 4)
	end)
end

return NavArrows
