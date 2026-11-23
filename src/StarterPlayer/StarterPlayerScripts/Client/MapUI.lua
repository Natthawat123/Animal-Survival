--[[
	MapUI — แผนที่ใหญ่ (M) + การค้นพบสถานที่ + ชื่อเขตตอนเดินเข้าไบโอม (แบบ Souls)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Biomes = require(Shared.Biomes)
local UIKit = require(script.Parent.UIKit)

local MapUI = {}
MapUI.ExtraMarkers = {} -- ระบบอื่นเพิ่มหมุดได้: fn(marker, place, discovered, seen) (WorldEventsClient)
local player = Players.LocalPlayer
local C = UIKit.Colors
local N = 56

local CRATE_COLOR = { Color3.fromRGB(230, 190, 130), Color3.fromRGB(110, 190, 255), Color3.fromRGB(255, 210, 60) } -- ระดับ 1-3

local BIOME_MAP_COLOR = {
	Heart = Color3.fromRGB(120, 170, 70),
	Earth = Color3.fromRGB(50, 110, 46),
	Water = Color3.fromRGB(226, 210, 160),
	Air = Color3.fromRGB(205, 214, 230),
	Fire = Color3.fromRGB(70, 50, 48),
}

function MapUI.Init(state, hud, atmosphere)
	MapUI.State = state
	local gui = UIKit.Screen("MapUI", 25)
	local panel = UIKit.Frame(gui, { Size = UDim2.fromOffset(620, 660), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0.05, Visible = false })
	UIKit.AutoScale(panel)
	UIKit.Corner(panel, 14)
	UIKit.Stroke(panel, C.Outline, 3, 0)
	UIKit.Text(panel, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 6), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title, TextSize = 30, TextColor3 = C.Gold, Text = "Map of the Four Lands" })
	local mapFrame = UIKit.Frame(panel, { Size = UDim2.fromOffset(560, 560), Position = UDim2.fromOffset(30, 50), BackgroundColor3 = Color3.fromRGB(28, 70, 96), BackgroundTransparency = 0 })
	UIKit.Corner(mapFrame, 8)
	mapFrame.ClipsDescendants = true
	mapFrame.Active = true -- คลิกบนแผนที่ (ปักหมุด) ไม่ทะลุไปฟันอาวุธในโลก
	local legend = UIKit.Text(panel, {
		Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 10, 1, -46), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 13, TextWrapped = true,
		TextColor3 = C.TextDim, Text = "🔥 Camp   ⛩ Spirit Pup Shrine   💀 Boss Lair   🏛 Ancient Sanctum   👹 Tribe Village   ▣ Chest   ☄ Events   ▲ You   ● Teammates   (places show up once the campfire light reaches them or you visit) · 📍 Click the map to place a marker",
	})
	local legendText = legend.Text
	local function layoutMap()
		local phone = UIKit.IsPhone()
		panel.Size = UDim2.fromOffset(phone and 830 or 620, phone and 620 or 674)
		mapFrame.Position = UDim2.fromOffset(phone and 20 or 30, 50)
		legend.Size = phone and UDim2.fromOffset(220, 560) or UDim2.new(1, -20, 0, 54) -- สูงพอ 3 บรรทัด (ตัวใหญ่ขึ้นแล้วไม่ล้น)
		legend.Position = phone and UDim2.fromOffset(594, 50) or UDim2.new(0, 10, 1, -58)
		legend.TextSize = phone and 24 or 15
		legend.TextXAlignment = phone and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
		legend.TextYAlignment = phone and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
		legend.Text = phone and legendText:gsub("%s%s+", "\n\n") or legendText
		UIKit.AutoScale(panel)
	end
	layoutMap()
	UIKit.OnResize(layoutMap)
	MapUI.Panel = panel
	MapUI.MapFrame = mapFrame

	local cells = {}
	local visited = {}
	local discovered = {}
	hud.Discovered = discovered
	local built = false
	local layout

	local function toMap(pos)
		local size = state:GetAttribute("MapSize") or 6144
		return (pos.X / size + 0.5), (pos.Z / size + 0.5)
	end

	local function buildGrid()
		layout = atmosphere.Layout
		if built or not layout then
			return
		end
		built = true
		local water = layout.WaterLevel
		local cs = 560 / N
		for i = 0, N - 1 do
			cells[i] = {}
			for k = 0, N - 1 do
				local x = ((i + 0.5) / N - 0.5) * layout.Size
				local z = ((k + 0.5) / N - 0.5) * layout.Size
				local h, biome, lava = layout:HeightAt(x, z)
				local color
				if lava then
					color = Color3.fromRGB(230, 90, 30)
				elseif h < water then
					local depth = math.clamp((water - h) / 60, 0, 1)
					color = Color3.fromRGB(70, 160, 200):Lerp(Color3.fromRGB(20, 60, 100), depth)
				else
					color = BIOME_MAP_COLOR[biome] or Color3.fromRGB(100, 100, 100)
					local shade = math.clamp((h - water) / 300, 0, 1)
					color = color:Lerp(Color3.new(1, 1, 1), shade * 0.35)
				end
				local f = Instance.new("Frame")
				f.Name = "Cell" -- ใช้เทียบตำแหน่งคลิก/แตะ (ดู inputToAbs)
				f.BorderSizePixel = 0
				f.Size = UDim2.fromOffset(math.ceil(cs), math.ceil(cs))
				f.Position = UDim2.fromOffset(i * cs, k * cs)
				f.BackgroundColor3 = color
				f.Parent = mapFrame
				local fog = Instance.new("Frame")
				fog.BorderSizePixel = 0
				fog.Size = UDim2.fromScale(1, 1)
				fog.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
				fog.BackgroundTransparency = 0.1
				fog.ZIndex = 2
				fog.Parent = f
				cells[i][k] = { Frame = f, Fog = fog, X = x, Z = z }
			end
		end
	end

	local markers = {}
	local markerWorld = {} -- [key] = ตำแหน่งในโลกล่าสุดของหมุด (ไว้ให้คลิกหมุดแล้วปักตรงของจริง)
	local function marker(key, text, color, size)
		local m = markers[key]
		if not m then
			size = (size or 22) * (UIKit.IsPhone() and 1.45 or 1.2) -- มือถือ: แผนที่ถูกย่อพอดีจอ -> หมุดใหญ่ขึ้นให้มองเห็น/กดโดน
			-- AnchorPoint กลาง: หมุดตรงจุดจริงทุกขนาดจอ (เดิมลบครึ่ง AbsoluteSize ซึ่งรวม UIScale -> เพี้ยนตามขนาดจอ)
			m = UIKit.Text(mapFrame, { Size = UDim2.fromOffset(size or 22, size or 22), AnchorPoint = Vector2.new(0.5, 0.5), TextXAlignment = Enum.TextXAlignment.Center, TextSize = size or 18, Text = text, TextColor3 = color or C.Text, ZIndex = 5, TextStrokeTransparency = 0.3 })
			m.TextScaled = true -- ไอคอนอีโมจิย่อให้พอดีกรอบหมุดเสมอ (จอเล็กเคยล้นกรอบ)
			local fit = m:FindFirstChildOfClass("UITextSizeConstraint")
			if fit then
				fit.MinTextSize = 4 -- (FitText ตั้งขั้นต่ำครึ่งของขนาด -> กรอบเล็กย่อไม่ลง เลยล้น)
			end
			m:SetAttribute("Key", key)
			markers[key] = m
		end
		return m
	end

	-- หมุดกล่องสมบัติ: รูปหีบ 3D จริงในเกม (หีบไม้ / หีบฟ้า / หีบทอง ตามระดับ) บนวงกลมพื้นเข้ม ขอบสีระดับ
	--   เปิดแล้ว = หีบฝาเปิด + จาง · ไม่มีโมเดล = ตัวอักษร ▣ แบบเดิม
	local ItemIcon = require(script.Parent.ItemIcon)
	local function chestMarker(key, tier, opened)
		local m = markers[key]
		local color = CRATE_COLOR[tier] or CRATE_COLOR[1]
		if not m then
			local size = 15 * (UIKit.IsPhone() and 1.35 or 1.15) -- เล็กลง (เดิม 24 x 1.2-1.45 ใหญ่บังแมพ)
			m = Instance.new("Frame")
			m.Name = "ChestPin"
			m.Size = UDim2.fromOffset(size, size)
			m.AnchorPoint = Vector2.new(0.5, 0.5)
			m.BackgroundColor3 = Color3.fromRGB(18, 16, 24)
			m.BackgroundTransparency = 0.2
			m.BorderSizePixel = 0
			m.ZIndex = 5
			m.Parent = mapFrame
			UIKit.Corner(m, 999)
			local st = Instance.new("UIStroke")
			st.Name = "Ring"
			st.Thickness = 1.5
			st.Parent = m
			m:SetAttribute("Key", key)
			markers[key] = m
		end
		local look = tier .. (opened and "o" or "c")
		if m:GetAttribute("Look") ~= look then
			m:SetAttribute("Look", look)
			for _, c in ipairs(m:GetChildren()) do
				if c:IsA("ViewportFrame") or c:IsA("TextLabel") then
					c:Destroy()
				end
			end
			local name = "Chest" .. tier .. (opened and "Open" or "")
			local assets = ReplicatedStorage:FindFirstChild("Assets")
			local props = assets and assets:FindFirstChild("Props")
			if props and not props:FindFirstChild(name) then
				name = "Chest" .. tier
			end
			local vp = props and props:FindFirstChild(name) and ItemIcon.Prop(m, name, {
				Size = UDim2.fromScale(1.25, 1.25), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), ZIndex = 6,
			})
			if vp then
				vp.ImageTransparency = opened and 0.55 or 0
			else
				UIKit.Text(m, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Text = "▣", TextScaled = true, TextColor3 = color, ZIndex = 6 })
			end
			m.Ring.Color = color
			m.Ring.Transparency = opened and 0.6 or 0
			m.BackgroundTransparency = opened and 0.6 or 0.2
		end
		return m
	end

	-- หมุดหมู่บ้านชนเผ่า: หน้ากากชนเผ่าบนวงกลมพื้นเข้ม ขอบแดง · ป้อมชนเผ่า (Capital) ใหญ่กว่า ขอบทอง · เพิ่งกวาดล้าง = จาง
	local function villageMarker(key, capital, cleared)
		local m = markers[key]
		if not m then
			local size = (capital and 21 or 17) * (UIKit.IsPhone() and 1.35 or 1.15)
			m = Instance.new("Frame")
			m.Name = "VillagePin"
			m.Size = UDim2.fromOffset(size, size)
			m.AnchorPoint = Vector2.new(0.5, 0.5)
			m.BackgroundColor3 = Color3.fromRGB(28, 12, 12)
			m.BorderSizePixel = 0
			m.ZIndex = 5
			m.Parent = mapFrame
			UIKit.Corner(m, 999)
			local st = Instance.new("UIStroke")
			st.Name = "Ring"
			st.Thickness = capital and 2 or 1.5
			st.Color = capital and Color3.fromRGB(255, 200, 70) or Color3.fromRGB(220, 60, 50)
			st.Parent = m
			local t = UIKit.Text(m, { Size = UDim2.fromScale(0.86, 0.86), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), TextXAlignment = Enum.TextXAlignment.Center, Text = "👹", ZIndex = 6 })
			t.Name = "Mask"
			t.TextScaled = true
			local fit = t:FindFirstChildOfClass("UITextSizeConstraint")
			if fit then
				fit.MinTextSize = 4
			end
			m:SetAttribute("Key", key)
			markers[key] = m
		end
		m.BackgroundTransparency = cleared and 0.6 or 0.15
		m.Ring.Transparency = cleared and 0.6 or 0
		m.Mask.TextTransparency = cleared and 0.55 or 0
		return m
	end

	local function refreshMap()
		buildGrid()
		if not built then
			return
		end
		local reveal = state:GetAttribute("CampReveal") or 900
		-- เห็นบนแผนที่ = อยู่ในเขตที่แสงกองไฟเปิดถึง (หมอกเปิด) / เคยเดินไป / ค้นพบแล้ว
		local size = state:GetAttribute("MapSize") or 6144
		local function seen(pos, key)
			if key and discovered[key] then
				return true
			end
			if math.sqrt(pos.X * pos.X + pos.Z * pos.Z) < reveal then
				return true
			end
			local ci = math.floor((pos.X / size + 0.5) * N)
			local ck = math.floor((pos.Z / size + 0.5) * N)
			return visited[ci * 1000 + ck] == true
		end
		for i = 0, N - 1 do
			for k = 0, N - 1 do
				local c = cells[i][k]
				local d = math.sqrt(c.X * c.X + c.Z * c.Z)
				local open = d < reveal or visited[i * 1000 + k]
				c.Fog.BackgroundTransparency = open and 1 or 0.12
			end
		end
		local function place(m, pos)
			local u, v = toMap(pos)
			m.AnchorPoint = Vector2.new(0.5, 0.5)
			m.Position = UDim2.fromScale(u, v)
			local key = m:GetAttribute("Key")
			if key then
				markerWorld[key] = pos
			end
		end
		-- หมุดที่ผู้เล่นปักเอง (ปลายหมุด = จุดที่กดพอดี)
		local wp = MapUI.Waypoint
		if MapUI.WpPin then
			MapUI.WpPin.Visible = wp ~= nil
			if wp then
				local u, v = toMap(wp)
				MapUI.WpPin.Position = UDim2.fromScale(u, v)
			end
		end
		local camp = state:GetAttribute("CampPos")
		if camp then
			place(marker("camp", "🔥", C.Fire, 20), camp)
		end
		for _, fn in ipairs(MapUI.ExtraMarkers) do
			local ok, err = pcall(fn, marker, place, discovered, seen)
			if not ok then
				warn("[AS] map marker", err)
			end
		end
		for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
			local shrine = state:GetAttribute("Shrine_" .. el)
			local sm = marker("Shrine_" .. el, "⛩", C.Element[el], 18)
			sm.Visible = shrine ~= nil and seen(shrine, "Shrine_" .. el)
			if sm.Visible then
				sm.Text = state:GetAttribute("Spirit" .. el) and "✓" or "⛩"
				place(sm, shrine)
			end
			local lair = state:GetAttribute("Lair_" .. el)
			local lm = marker("Lair_" .. el, "💀", C.Element[el], 20)
			lm.Visible = lair ~= nil and seen(lair, "Lair_" .. el)
			if lm.Visible then
				lm.Text = state:GetAttribute("Lair" .. el .. "Cleared") and "☠" or "💀"
				place(lm, lair)
			end
		end
		-- หมู่บ้านชนเผ่า (หน้ากาก) · เห็นเมื่ออยู่ในเขตที่เปิดหมอกแล้ว เหมือนศาลเจ้า/รัง
		local vfolder = ReplicatedStorage:FindFirstChild("MapVillages")
		local vcount = 0
		for i, pin in ipairs(vfolder and vfolder:GetChildren() or {}) do
			vcount = i
			local capital = pin:GetAttribute("Capital") == true
			local m = villageMarker("village_" .. i, capital, pin:GetAttribute("Cleared") == true)
			m.Visible = seen(pin.Value, "Village_" .. i)
			if m.Visible then
				m.ZIndex = capital and 6 or 5
				place(m, pin.Value)
			end
		end
		for key, m in pairs(markers) do
			if key:sub(1, 8) == "village_" and tonumber(key:sub(9)) > vcount then
				m.Visible = false
			end
		end
		-- กล่องสมบัติ (เปิดแล้ว = จาง) · สีตามระดับ
		local pins = ReplicatedStorage:FindFirstChild("MapPins")
		local count = 0
		for i, pin in ipairs(pins and pins:GetChildren() or {}) do
			count = i
			local tier = math.clamp(pin:GetAttribute("Tier") or 1, 1, 3)
			local opened = pin:GetAttribute("Opened_" .. Players.LocalPlayer.UserId) == true
			local m = chestMarker("crate_" .. i, tier, opened)
			m.Visible = seen(pin.Value)
			if m.Visible then
				m.ZIndex = opened and 4 or 5 -- หีบที่ยังไม่เปิดอยู่บนสุด
				place(m, pin.Value)
			end
		end
		for key, m in pairs(markers) do
			if key:sub(1, 6) == "crate_" and tonumber(key:sub(7)) > count then
				m.Visible = false
			end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			if char then
				local m = marker("p_" .. p.UserId, p == player and "▲" or "●", p == player and Color3.fromRGB(255, 255, 120) or Color3.fromRGB(120, 220, 255), p == player and 20 or 14)
				place(m, char:GetPivot().Position)
				if p == player then
					local look = workspace.CurrentCamera.CFrame.LookVector
					m.Rotation = math.deg(math.atan2(look.X, -look.Z))
				end
			end
		end
	end

	local function toggle()
		panel.Visible = not panel.Visible
		if panel.Visible then
			refreshMap()
		end
	end
	MapUI.Toggle = toggle
	local function close()
		panel.Visible = false
	end
	MapUI.Close = close
	-- กลับล็อบบี้ตอนแผนที่เปิดค้าง = ปิด
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		if not player:GetAttribute("InRun") then
			close()
		end
	end)
	UIKit.CloseButton(panel, close)
	UIKit.RegisterWindow(panel, close)
	UserInputService.InputBegan:Connect(function(input, processed)
		-- ล็อบบี้ (นอกรอบ) กด M ไม่เปิดแผนที่ (แผนที่เป็นของในเกม)
		if not processed and input.KeyCode == Enum.KeyCode.M and player:GetAttribute("InRun") then
			toggle()
		end
	end)

	---------------------------------------------------------------- ปักหมุดเอง (คลิก/แตะบนแผนที่)
	-- คลิก/แตะที่ว่าง = ปักหมุดตรงนั้น · ใกล้หมุดกล่อง/ศาล/รัง = ปักตรงของจริงเป๊ะ · กดหมุดเดิม = เอาออก
	-- ในโลก: เสาแสง + ป้ายนำทางบนจอ (NavArrows: เกาะขอบจอ + ลูกศร) + จุดบนเข็มทิศ · ถึงที่ = หมุดหายเอง
	local NavArrows = require(script.Parent.NavArrows)
	local GuiService = game:GetService("GuiService")
	local TweenService = game:GetService("TweenService")
	local WP_COLOR = Color3.fromRGB(255, 220, 90)
	local wpParts = {}
	local wpNear = false

	-- หมุดบนแผนที่: จุดกลม = ตำแหน่งจริง · 📍 ปลายแหลมชี้ลงจุดนั้นพอดี (เดิมจัดกลางตัวอักษร -> ดูเหมือนปักเลยขึ้นไปข้างบน)
	local wpPin = Instance.new("Frame")
	wpPin.Name = "WaypointPin"
	wpPin.BackgroundTransparency = 1
	wpPin.Size = UDim2.fromOffset(0, 0)
	wpPin.AnchorPoint = Vector2.new(0.5, 0.5)
	wpPin.ZIndex = 8
	wpPin.Visible = false
	wpPin.Parent = mapFrame
	local wpScale = Instance.new("UIScale")
	wpScale.Parent = wpPin
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(9, 9)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = WP_COLOR
	dot.ZIndex = 8
	dot.Parent = wpPin
	UIKit.Corner(dot, 9)
	local dotStroke = Instance.new("UIStroke")
	dotStroke.Thickness = 1.5
	dotStroke.Color = Color3.fromRGB(30, 20, 10)
	dotStroke.Parent = dot
	local pinGlyph = UIKit.Text(wpPin, { Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(1, 3), Text = "📍", TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
	pinGlyph:SetAttribute("NoTranslate", true)
	local function thumb(uid)
		return "rbxthumb://type=AvatarHeadShot&id=" .. uid .. "&w=48&h=48"
	end
	-- รูปโปรไฟล์คนปัก (ลอยเหนือหัวหมุด) -> ทั้งทีมรู้ว่าหมุดใคร
	local function avatarBadge(parent, uid, color, z)
		local av = Instance.new("ImageLabel")
		av.Name = "Avatar"
		av.Size = UDim2.fromOffset(22, 22)
		av.AnchorPoint = Vector2.new(0.5, 1)
		av.Position = UDim2.fromOffset(1, -24)
		av.BackgroundColor3 = Color3.fromRGB(24, 22, 30)
		av.Image = thumb(uid)
		av.ZIndex = z
		av.Parent = parent
		UIKit.Corner(av, 11)
		local s = Instance.new("UIStroke")
		s.Color, s.Thickness = color, 2
		s.Parent = av
		return av
	end
	avatarBadge(wpPin, player.UserId, WP_COLOR, 10)
	MapUI.WpPin = wpPin

	local function ripple(u, v)
		local r = Instance.new("Frame")
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = UDim2.fromScale(u, v)
		r.Size = UDim2.fromOffset(6, 6)
		r.BackgroundTransparency = 1
		r.ZIndex = 7
		r.Parent = mapFrame
		UIKit.Corner(r, 40)
		local st = Instance.new("UIStroke")
		st.Color = WP_COLOR
		st.Thickness = 2.5
		st.Parent = r
		TweenService:Create(r, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(46, 46) }):Play()
		TweenService:Create(st, TweenInfo.new(0.45), { Transparency = 1 }):Play()
		task.delay(0.5, function()
			r:Destroy()
		end)
	end

	local Remotes = require(ReplicatedStorage.Shared.Remotes)
	local wpRemote = Remotes.Get("Waypoint")
	-- silent = ไม่ต้องบอกเพื่อน (กำลังจะปักจุดใหม่แทนอยู่แล้ว)
	local function clearWaypoint(silent)
		if MapUI.Waypoint and not silent then
			wpRemote:FireServer("Clear") -- ลบหมุดเราบนจอเพื่อนด้วย
		end
		MapUI.Waypoint = nil
		for _, inst in ipairs(wpParts) do
			inst:Destroy()
		end
		wpParts = {}
		hud.ExtraPOI.waypoint = nil
		NavArrows.Remove("waypoint")
		wpPin.Visible = false
	end
	local function setWaypoint(pos)
		clearWaypoint(true)
		MapUI.Waypoint = pos
		wpRemote:FireServer("Set", pos) -- เพื่อนทั้งทีมเห็นหมุดเรา (PingService)
		wpNear = false
		local holder = workspace.CurrentCamera -- ของเฉพาะเครื่องเรา (ไม่โดน streaming ลบ)
		local beam = Instance.new("Part")
		beam.Name = "WaypointBeam"
		beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch, beam.CastShadow = true, false, false, false, false
		beam.Material = Enum.Material.Neon
		beam.Color = WP_COLOR
		beam.Transparency = 1
		beam.Shape = Enum.PartType.Cylinder
		beam.Size = Vector3.new(160, 1.6, 1.6)
		beam.CFrame = CFrame.new(pos + Vector3.new(0, 80, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		beam.Parent = holder
		TweenService:Create(beam, TweenInfo.new(0.6), { Transparency = 0.45 }):Play()
		local ring = Instance.new("Part")
		ring.Name = "WaypointRing"
		ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
		ring.Material = Enum.Material.Neon
		ring.Color = WP_COLOR
		ring.Transparency = 0.6
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.3, 14, 14)
		ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Parent = holder
		wpParts = { beam, ring }
		hud.ExtraPOI.waypoint = { Position = pos, Icon = "📍", Color = WP_COLOR }
		NavArrows.Set("waypoint", {
			Position = pos, Icon = "📍", Color = WP_COLOR, Order = 2, Lift = 5,
			Label = function(studs)
				local m = math.floor(studs * 0.28)
				return studs < 60 and string.format("Very close! %dm", m) or string.format("Marker %dm", m)
			end,
			LabelColor = function(studs)
				return studs < 60 and Color3.fromRGB(140, 255, 140) or WP_COLOR
			end,
		})
		-- หมุดบนแผนที่เด้งลง + วงคลื่น
		local size = state:GetAttribute("MapSize") or 6144
		local u, v = pos.X / size + 0.5, pos.Z / size + 0.5
		wpPin.Position = UDim2.fromScale(u, v)
		wpPin.Visible = true
		wpScale.Scale = 0.3
		TweenService:Create(wpScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if panel.Visible then
			ripple(u, v)
		end
	end
	MapUI.SetWaypoint = setWaypoint
	MapUI.ClearWaypoint = clearWaypoint

	---------------------------------------------------------------- หมุดของเพื่อน (แชร์ทั้งทีม)
	-- แผนที่: หมุด + รูปโปรไฟล์คนปัก · ในโลก: เสาแสงสีประจำคน + ป้ายนำทาง (รูปโปรไฟล์ + ชื่อ + ระยะ) + จุดบนเข็มทิศ
	local MATE_COLORS = { Color3.fromRGB(120, 210, 255), Color3.fromRGB(255, 140, 200), Color3.fromRGB(150, 255, 140), Color3.fromRGB(255, 170, 90), Color3.fromRGB(200, 160, 255), Color3.fromRGB(255, 240, 120) }
	local mates = {} -- [userId] = { Parts, Pin }
	local function removeMate(uid)
		local e = mates[uid]
		if not e then
			return
		end
		mates[uid] = nil
		for _, inst in ipairs(e.Parts) do
			inst:Destroy()
		end
		NavArrows.Remove("wp_" .. uid)
		hud.ExtraPOI["wp_" .. uid] = nil
	end
	local function showMate(uid, name, pos)
		removeMate(uid)
		local color = MATE_COLORS[(uid % #MATE_COLORS) + 1]
		local beam = Instance.new("Part")
		beam.Name = "MateBeam"
		beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch, beam.CastShadow = true, false, false, false, false
		beam.Material = Enum.Material.Neon
		beam.Color = color
		beam.Transparency = 0.55
		beam.Shape = Enum.PartType.Cylinder
		beam.Size = Vector3.new(140, 1.1, 1.1)
		beam.CFrame = CFrame.new(pos + Vector3.new(0, 70, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		beam.Parent = workspace.CurrentCamera
		-- หมุดบนแผนที่
		local size = state:GetAttribute("MapSize") or 6144
		local pin = Instance.new("Frame")
		pin.Name = "MatePin"
		pin.BackgroundTransparency = 1
		pin.Size = UDim2.fromOffset(0, 0)
		pin.AnchorPoint = Vector2.new(0.5, 0.5)
		pin.Position = UDim2.fromScale(pos.X / size + 0.5, pos.Z / size + 0.5)
		pin.ZIndex = 8
		pin.Parent = mapFrame
		local d = Instance.new("Frame")
		d.Size = UDim2.fromOffset(8, 8)
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.BackgroundColor3 = color
		d.ZIndex = 8
		d.Parent = pin
		UIKit.Corner(d, 8)
		local g = UIKit.Text(pin, { Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(1, 3), Text = "📍", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
		g:SetAttribute("NoTranslate", true)
		avatarBadge(pin, uid, color, 10)
		mates[uid] = { Parts = { beam, pin } }
		NavArrows.Set("wp_" .. uid, {
			Position = pos, Icon = "📍", Image = thumb(uid), Color = color, Order = 2, Lift = 5,
			Label = function(studs)
				return string.format("%s · %dm", name, math.floor(studs * 0.28))
			end,
		})
		hud.ExtraPOI["wp_" .. uid] = { Position = pos, Icon = "📍", Color = color }
		hud.Notify(string.format("📍 %s placed a marker", name), "Info")
	end
	wpRemote.OnClientEvent:Connect(function(action, uid, name, pos)
		if action == "Set" and type(uid) == "number" and typeof(pos) == "Vector3" then
			showMate(uid, tostring(name or "?"), pos)
		elseif action == "Clear" and type(uid) == "number" then
			removeMate(uid)
		end
	end)
	player:GetAttributeChangedSignal("InRun"):Connect(function()
		if not player:GetAttribute("InRun") then
			for uid in pairs(mates) do
				removeMate(uid)
			end
		end
	end)

	-- ตำแหน่งแตะ/คลิก (InputObject) -> พิกัดเดียวกับ AbsolutePosition
	--   แถบบนของ Roblox (GuiInset) ทำให้สองระบบพิกัดต่างกันได้ ไม่เท่ากันแต่ละเครื่อง (คอม/มือถือ/แถบบนรุ่นใหม่)
	--   -> ให้ Roblox บอกเองว่าช่องแผนที่ช่องไหนอยู่ใต้นิ้ว แล้วเลือกค่าชดเชยที่ทำให้จุดตกในช่องนั้นจริง
	local function inputToAbs(p)
		local inset = GuiService:GetGuiInset()
		local ok, objs = pcall(function()
			return player.PlayerGui:GetGuiObjectsAtPosition(p.X, p.Y)
		end)
		if ok then
			for _, o in ipairs(objs) do
				if o.Name == "Cell" and o:IsDescendantOf(mapFrame) then
					local a, s = o.AbsolutePosition, o.AbsoluteSize
					for _, off in ipairs({ Vector2.zero, inset, -inset }) do
						local q = p + off
						if q.X >= a.X - 1 and q.Y >= a.Y - 1 and q.X <= a.X + s.X + 1 and q.Y <= a.Y + s.Y + 1 then
							return q, off
						end
					end
					return a + s / 2, nil
				end
			end
		end
		return p, Vector2.zero
	end
	MapUI.InputToAbs = inputToAbs

	local function mapClick(screenPos)
		buildGrid()
		if not built then
			return
		end
		local ap, as = mapFrame.AbsolutePosition, mapFrame.AbsoluteSize
		local rel = screenPos - ap
		if rel.X < 0 or rel.Y < 0 or rel.X > as.X or rel.Y > as.Y then
			return
		end
		local hit = 14 * as.X / 560 -- รัศมีกดโดนหมุด (ตามขนาดแผนที่บนจอ)
		-- กดหมุดเดิม (จุดหรือตัว 📍) = เอาออก
		if MapUI.Waypoint and wpPin.Visible then
			local tip = wpPin.AbsolutePosition
			local head = tip - Vector2.new(0, 18 * as.X / 560)
			if (tip - screenPos).Magnitude < hit or (head - screenPos).Magnitude < hit then
				clearWaypoint()
				return
			end
		end
		-- ใกล้หมุดสถานที่/กล่อง = ปักตรงของจริง
		local best, bestD
		for key, m in pairs(markers) do
			local w = markerWorld[key]
			if w and m.Visible and key:sub(1, 2) ~= "p_" then
				local d = (m.AbsolutePosition + m.AbsoluteSize / 2 - screenPos).Magnitude
				if d < hit and (not bestD or d < bestD) then
					best, bestD = w, d
				end
			end
		end
		if not best then
			local size = state:GetAttribute("MapSize") or 6144
			local x, z = (rel.X / as.X - 0.5) * size, (rel.Y / as.Y - 0.5) * size
			local h = layout:HeightAt(x, z)
			best = Vector3.new(x, math.max(h, layout.WaterLevel), z)
		end
		setWaypoint(best)
	end
	MapUI.MapClick = mapClick
	-- แตะ = กดแล้วปล่อยโดยนิ้วไม่ลาก (กันปักพลาดตอนเลื่อนนิ้ว)
	local downAt, downType
	UserInputService.InputBegan:Connect(function(input)
		if panel.Visible and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			downAt, downType = Vector2.new(input.Position.X, input.Position.Y), input.UserInputType
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not (downAt and panel.Visible and input.UserInputType == downType) then
			return
		end
		local p = Vector2.new(input.Position.X, input.Position.Y)
		local moved = (p - downAt).Magnitude
		downAt = nil
		if moved < 14 then
			mapClick((inputToAbs(p)))
		end
	end)
	-- เตือนใกล้ถึง + ถึงแล้วหมุดหายเอง (ป้ายระยะอยู่ที่ NavArrows)
	task.spawn(function()
		while true do
			task.wait(0.15)
			local wp = MapUI.Waypoint
			if wp and not player:GetAttribute("InRun") then
				clearWaypoint()
			elseif wp then
				local char = player.Character
				if char then
					local flat = ((wp - char:GetPivot().Position) * Vector3.new(1, 0, 1)).Magnitude
					if flat < 9 then
						clearWaypoint()
						hud.Notify("📍 Reached your marker", "Reward")
					elseif flat < 60 then
						if not wpNear then
							wpNear = true
							hud.Notify("📍 Your marker is close by", "Info")
						end
					elseif flat > 90 then
						wpNear = false
					end
				end
			end
		end
	end)

	-- ป้ายชื่อเขต
	local areaFrame = UIKit.Frame(gui, { Size = UDim2.new(1, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.16, 0), BackgroundTransparency = 1 })
	UIKit.AutoScale(areaFrame)
	local areaTitle = UIKit.Text(areaFrame, { Size = UDim2.new(1, 0, 0, 60), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title, TextSize = 52, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })
	local areaLine = UIKit.Frame(areaFrame, { Size = UDim2.new(0, 460, 0, 1), Position = UDim2.new(0.5, -230, 0, 62), BackgroundColor3 = C.Gold, BackgroundTransparency = 1 })
	local areaSub = UIKit.Text(areaFrame, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 68), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 20, TextTransparency = 1, Text = "" })
	local lastBiome, lastShown = nil, {}
	local function showArea(biome)
		local b = Biomes.Data[biome]
		if not b then
			return
		end
		if lastShown[biome] and os.clock() - lastShown[biome] < 25 then
			return
		end
		lastShown[biome] = os.clock()
		areaTitle.Text = b.Name
		areaTitle.TextColor3 = b.Color
		areaSub.Text = b.Thai
		areaLine.BackgroundColor3 = b.Color
		UIKit.Tween(areaTitle, 1, { TextTransparency = 0, TextStrokeTransparency = 0.5 })
		UIKit.Tween(areaSub, 1, { TextTransparency = 0 })
		UIKit.Tween(areaLine, 1, { BackgroundTransparency = 0.2 })
		task.delay(3.2, function()
			UIKit.Tween(areaTitle, 1.2, { TextTransparency = 1, TextStrokeTransparency = 1 })
			UIKit.Tween(areaSub, 1.2, { TextTransparency = 1 })
			UIKit.Tween(areaLine, 1.2, { BackgroundTransparency = 1 })
		end)
	end

	local SITE_NAMES = {
		Shrine = "Sealed Shrine", Lair = "Beast Lair",
	}
	task.spawn(function()
		while true do
			task.wait(1)
			local char = player.Character
			if char and state:GetAttribute("Ready") then
				local pos = char:GetPivot().Position
				-- บันทึกจุดที่เคยไป
				local size = state:GetAttribute("MapSize") or 6144
				local ci = math.floor((pos.X / size + 0.5) * N)
				local ck = math.floor((pos.Z / size + 0.5) * N)
				for di = -2, 2 do
					for dk = -2, 2 do
						visited[(ci + di) * 1000 + (ck + dk)] = true
					end
				end
				-- ค้นพบสถานที่
				for _, kind in ipairs({ "Shrine", "Lair" }) do
					for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
						local key = kind .. "_" .. el
						local p = state:GetAttribute(key)
						if p and not discovered[key] and ((p - pos) * Vector3.new(1, 0, 1)).Magnitude < 280 then
							discovered[key] = true
							hud.Notify(string.format("🗺 Discovered: %s%s", SITE_NAMES[kind], UIKit.ElementThai[el]), "Reward")
						end
					end
				end
				-- หมู่บ้านชนเผ่าที่เดินเข้าใกล้ = ค้นพบ (หมุดหน้ากากค้างบนแผนที่)
				local vfolder = ReplicatedStorage:FindFirstChild("MapVillages")
				for i, pin in ipairs(vfolder and vfolder:GetChildren() or {}) do
					local key = "Village_" .. i
					if not discovered[key] and ((pin.Value - pos) * Vector3.new(1, 0, 1)).Magnitude < 280 then
						discovered[key] = true
					end
				end
				-- ชื่อเขต
				local biome = atmosphere.Biome
				if biome and biome ~= lastBiome then
					lastBiome = biome
					showArea(biome)
				end
				if panel.Visible then
					refreshMap()
				end
			end
		end
	end)
end

return MapUI
