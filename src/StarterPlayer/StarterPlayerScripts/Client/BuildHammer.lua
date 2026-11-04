--[[
	BuildHammer — ค้อนช่าง: ถือแล้วชี้/แตะสิ่งก่อสร้างในแคมป์ -> เมนู ย้าย / รื้อ / ยกเลิก
	  ย้าย = ใช้โหมดวางของ Menus (เงาเขียว/แดง) กับของชิ้นเดิม -> Remotes.MoveStructure
	  รื้อ = Remotes.Demolish (เซิร์ฟเวอร์คืนวัตถุดิบครึ่งหนึ่งเป็นของบนพื้น)
	  คอม: ชี้แล้วขอบเรืองทอง · มือถือ: แตะที่สิ่งก่อสร้าง
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)

local BuildHammer = {}
local player = Players.LocalPlayer
local C = UIKit.Colors

local menus
local hammer -- Tool ที่ถืออยู่ (ค้อนช่าง) หรือ nil
local hover -- สิ่งก่อสร้างที่ชี้อยู่
local highlight
local popup, popTitle, popTarget
local lastTouch -- จุดแตะล่าสุด (มือถือ)

local function isHammer(t)
	if not (t and t:IsA("Tool")) then
		return false
	end
	local spec = Items.Tools[t:GetAttribute("ItemId")]
	return spec ~= nil and spec.Builder == true
end

-- สิ่งก่อสร้าง (ลูกตรงของโฟลเดอร์ Structures) ใต้จุดบนจอ
local function structureAt(screenPos)
	local folder = Workspace:FindFirstChild("Structures")
	if not folder then
		return nil
	end
	local cam = Workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local res = Workspace:Raycast(ray.Origin, ray.Direction * 250, params)
	local inst = res and res.Instance
	while inst and inst.Parent ~= folder do
		inst = inst.Parent
	end
	if inst and not inst:GetAttribute("Broken") and Items.Structures[inst:GetAttribute("Kind")] then
		return inst
	end
	return nil
end

local function pointer()
	if menus and menus.TouchMode then
		return lastTouch or (Workspace.CurrentCamera.ViewportSize / 2)
	end
	return UserInputService:GetMouseLocation()
end

local function closePopup()
	popup.Visible = false
	popTarget = nil
end

local function openPopup(s)
	popTarget = s
	local hp, mh = s:GetAttribute("Health") or 0, s:GetAttribute("MaxHealth") or 0
	-- ชื่อไม่เอาวงเล็บท้าย ("Bed (+1 Day)" -> "Bed") ย้าย/รื้อไม่ได้วันเพิ่ม
	local name = Items.DisplayName(s:GetAttribute("Kind")):gsub("%s*%b()$", "")
	popTitle.Text = string.format("%s  ·  HP %d/%d", name, math.ceil(hp), math.ceil(mh))
	popup.Visible = true
end

local function inRange(s)
	local char = player.Character
	return char and (char:GetPivot().Position - s:GetPivot().Position).Magnitude <= Config.BuildRange
end

local function onActivated()
	-- คลิกที่ใช้วาง/ย้าย ไม่นับ · เมนูเปิดอยู่ไม่นับ
	if menus.IsBuilding() or os.clock() - menus.BuildStoppedAt() < 0.4 or popup.Visible then
		return
	end
	local s = structureAt(pointer())
	if s then
		if inRange(s) then
			openPopup(s)
		else
			menus.Hud.Notify("Too far away", "Error")
		end
	end
end

local function hint()
	if not menus.BuildHint then
		return
	end
	if hammer and not menus.IsBuilding() then
		menus.BuildHint.Text = menus.TouchMode and "🔨 Tap a building in camp to move or remove it"
			or "🔨 Click a building in camp to move or remove it"
		menus.BuildHint.Visible = true
		if menus.RotateButton then
			menus.RotateButton.Visible = false -- ยังไม่ได้วาง/ย้าย ไม่ต้องมีปุ่มหมุน
		end
	elseif not menus.IsBuilding() and menus.BuildHint.Text:find("🔨", 1, true) then
		menus.BuildHint.Visible = false
	end
end

local function setHammer(t)
	hammer = t
	if not t then
		hover = nil
		highlight.Adornee = nil
		closePopup()
		if menus.IsMoving() then
			menus.StopBuild()
		end
	end
	hint()
end

local function buildPopup()
	local gui = UIKit.Screen("BuildHammer", 22)
	popup = UIKit.Frame(gui, {
		Name = "HammerMenu", Size = UDim2.fromOffset(380, 150), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.64),
		BackgroundColor3 = C.Panel, BackgroundTransparency = 0.08, Visible = false,
	})
	UIKit.Corner(popup, 14)
	UIKit.Stroke(popup, C.Gold, 2.5, 0.1)
	UIKit.AutoScale(popup)
	popTitle = UIKit.Text(popup, {
		Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 10), Font = UIKit.Fonts.Title, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Gold, Text = "",
	})
	local row = UIKit.Frame(popup, { Size = UDim2.new(1, -24, 0, 56), Position = UDim2.fromOffset(12, 54), BackgroundTransparency = 1 })
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 10)
	list.Parent = row
	UIKit.Button(row, { Name = "Move", Size = UDim2.fromOffset(150, 56), Text = "Move", TextSize = 22, BackgroundColor3 = Color3.fromRGB(70, 130, 220) }, function()
		local s = popTarget
		closePopup()
		if s and s.Parent then
			menus.StartBuild(s:GetAttribute("Kind"), s)
		end
	end)
	UIKit.Button(row, { Name = "Remove", Size = UDim2.fromOffset(150, 56), Text = "Remove", TextSize = 22, BackgroundColor3 = C.Red }, function()
		local s = popTarget
		closePopup()
		if s and s.Parent then
			Remotes.Get("Demolish"):FireServer(s)
		end
	end)
	UIKit.Text(popup, {
		Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 116), TextSize = 15, Font = UIKit.Fonts.Bold,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.TextDim, Text = "Remove = get half the materials back",
	})
	local close = UIKit.Button(popup, { Name = "Close", Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -10, 0, -10), AnchorPoint = Vector2.new(0.5, 0.5),
		Text = "X", TextSize = 18, BackgroundColor3 = C.Red }, closePopup)
	close:SetAttribute("NoTranslate", true)
end

-- เปิดเมนูของสิ่งก่อสร้างนี้ (ใช้ในเทส)
function BuildHammer.OpenFor(structure)
	openPopup(structure)
end

function BuildHammer.Init(menusModule)
	menus = menusModule
	highlight = Instance.new("Highlight")
	highlight.Name = "HammerHover"
	highlight.FillColor = C.Gold
	highlight.FillTransparency = 0.75
	highlight.OutlineColor = C.Gold
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = Workspace.CurrentCamera
	buildPopup()

	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			lastTouch = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			closePopup()
		end
	end)

	local function hookChar(char)
		for _, t in ipairs(char:GetChildren()) do
			if isHammer(t) then
				setHammer(t)
			end
		end
		char.ChildAdded:Connect(function(t)
			if isHammer(t) then
				setHammer(t)
				if not t:GetAttribute("HammerHooked") then
					t:SetAttribute("HammerHooked", true)
					t.Activated:Connect(onActivated)
				end
			end
		end)
		char.ChildRemoved:Connect(function(t)
			if t == hammer then
				task.defer(function()
					if t.Parent ~= char then
						setHammer(nil)
					end
				end)
			end
		end)
	end
	if player.Character then
		hookChar(player.Character)
	end
	player.CharacterAdded:Connect(hookChar)

	RunService.RenderStepped:Connect(function()
		if not hammer then
			return
		end
		-- ชี้ค้าง (คอม) = ขอบเรืองบอกว่าคลิกได้ · ระหว่างย้าย/เมนูเปิด = เรืองตัวที่เลือก
		local target = popTarget
		if not target and not menus.IsBuilding() and not menus.TouchMode then
			target = structureAt(UserInputService:GetMouseLocation())
			if target and not inRange(target) then
				target = nil
			end
		end
		if target ~= hover then
			hover = target
			highlight.Adornee = target
		end
		if popTarget and (not popTarget.Parent or menus.IsBuilding()) then
			closePopup() -- ของถูกทำลาย / เข้าโหมดวางแล้ว
		end
		if not menus.BuildHint.Visible and not menus.IsBuilding() then
			hint()
		end
	end)
end

return BuildHammer
