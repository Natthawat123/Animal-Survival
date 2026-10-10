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
local player = Players.LocalPlayer
local C = UIKit.Colors
local N = 56

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
	UIKit.Text(panel, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 6), TextXAlignment = Enum.TextXAlignment.Center, Font = UIKit.Fonts.Title, TextSize = 30, TextColor3 = C.Gold, Text = "แผนที่ดินแดนทั้งสี่" })
	local mapFrame = UIKit.Frame(panel, { Size = UDim2.fromOffset(560, 560), Position = UDim2.fromOffset(30, 50), BackgroundColor3 = Color3.fromRGB(28, 70, 96), BackgroundTransparency = 0 })
	UIKit.Corner(mapFrame, 8)
	mapFrame.ClipsDescendants = true
	local legend = UIKit.Text(panel, {
		Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 10, 1, -46), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 13, TextWrapped = true,
		TextColor3 = C.TextDim, Text = "🔥 แคมป์   ⛩ ศาลเจ้าลูกสัตว์ธาตุ   💀 รังบอส   ▲ คุณ   ● เพื่อน   (สถานที่จะปรากฏเมื่อค้นพบ · หมอกเปิดเมื่ออัปเกรดกองไฟ/เดินสำรวจ)",
	})
	local _ = legend
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
	local function marker(key, text, color, size)
		local m = markers[key]
		if not m then
			m = UIKit.Text(mapFrame, { Size = UDim2.fromOffset(size or 22, size or 22), TextXAlignment = Enum.TextXAlignment.Center, TextSize = size or 18, Text = text, TextColor3 = color or C.Text, ZIndex = 5, TextStrokeTransparency = 0.3 })
			markers[key] = m
		end
		return m
	end

	local function refreshMap()
		buildGrid()
		if not built then
			return
		end
		local reveal = state:GetAttribute("CampReveal") or 900
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
			m.Position = UDim2.new(u, -m.AbsoluteSize.X / 2, v, -m.AbsoluteSize.Y / 2)
		end
		local camp = state:GetAttribute("CampPos")
		if camp then
			place(marker("camp", "🔥", C.Fire, 20), camp)
		end
		for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
			local shrine = state:GetAttribute("Shrine_" .. el)
			if shrine and discovered["Shrine_" .. el] then
				local done = state:GetAttribute("Spirit" .. el)
				place(marker("Shrine_" .. el, done and "✓" or "⛩", C.Element[el], 18), shrine)
			end
			local lair = state:GetAttribute("Lair_" .. el)
			if lair and discovered["Lair_" .. el] then
				local cleared = state:GetAttribute("Lair" .. el .. "Cleared")
				place(marker("Lair_" .. el, cleared and "☠" or "💀", C.Element[el], 20), lair)
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
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			toggle()
		end
	end)

	-- ป้ายชื่อเขต
	local areaFrame = UIKit.Frame(gui, { Size = UDim2.new(1, 0, 0, 120), Position = UDim2.new(0, 0, 0.16, 0), BackgroundTransparency = 1 })
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
		Shrine = "ศาลเจ้าผนึก", Lair = "รังอสูร",
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
							hud.Notify(string.format("🗺 ค้นพบ: %s%s", SITE_NAMES[kind], UIKit.ElementThai[el]), "Reward")
						end
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
