--[[
	WorldUI — เมนู "Worlds" ในล็อบบี้ (ปุ่ม 🌍 Worlds มุมขวาบน ใต้แคปซูล Ruby) · 3 หน้า + หน้าต่างคำเชิญ
	  Browse : "+ Create World" · โลกของฉัน (เปิดห้อง/ลบ) · ห้องโลกทุกห้องในเซิร์ฟเวอร์นี้ (เข้า · 🔒 ต้องใส่รหัส)
	  Setup  : ตั้งชื่อโลก (สร้างใหม่) / รหัสผ่าน / จำนวนคน 1-8 -> สร้าง (ซื้อ Config.WorldProductId) หรือเปิดห้องโลกเดิม
	  Room   : ห้องรอ — ช่องผู้เล่นตามจำนวน · หัวห้องเชิญคนในเซิร์ฟเวอร์ / เตะ / "▶ Enter World" / ปิดห้อง · ลูกห้องกดออก
	  Invite : มีคนเชิญ -> หน้าต่างเล็ก Join / Decline (เข้าได้ไม่ต้องใส่รหัส)
	  ข้อมูล: ReplicatedStorage.Worlds (WorldService) · attribute ผู้เล่น WorldRoom / MyWorlds / BestNight
]]

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local WoodKit = require(script.Parent.WoodKit)

local WorldUI = {}
local player = Players.LocalPlayer
local W = WoodKit.Colors
local RS = utf8.char(0xE002) -- ไอคอน Robux
local MAX = Config.WorldMaxSize or 8
local ui = {}
local page = "Browse" -- Browse / Setup
local setup = { Mode = "Create", WorldId = nil, Name = "", Password = "", Size = 4 }
local joinTarget -- ห้องที่กำลังใส่รหัส

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local LIGHT, DIM = rgb(246, 232, 204), rgb(196, 182, 156)

local function maxNight()
	return (player:GetAttribute("BestNight") or 0) + (Config.WorldNightGate or 20)
end

local function act(...)
	Remotes.Get("WorldAction"):FireServer(...)
end

local function myWorlds()
	local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("MyWorlds") or "[]")
	return ok and type(list) == "table" and list or {}
end

local function folder()
	return ReplicatedStorage:FindFirstChild("Worlds")
end

local function priceText()
	if (Config.WorldProductId or 0) <= 0 then
		return "Free (test)"
	end
	return RS .. " " .. tostring(ui.Price or Config.WorldRobux or "?")
end

---------------------------------------------------------------- ชิ้นส่วน UI
local function label(parent, props)
	props.TextColor3 = props.TextColor3 or LIGHT
	props.ZIndex = props.ZIndex or 5
	return UIKit.Text(parent, props)
end

local function button(parent, style, props, fn)
	props.ZIndex = props.ZIndex or 6
	return WoodKit.Button(parent, style, props, fn)
end

local function textBox(parent, props)
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = rgb(30, 22, 18)
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Text = ""
	box.PlaceholderColor3 = rgb(150, 134, 116)
	box.TextColor3 = rgb(255, 244, 224)
	box.Font = UIKit.Fonts.Bold
	box.TextSize = 20
	box.ZIndex = 6
	for k, v in pairs(props) do
		box[k] = v
	end
	box.Parent = parent
	WoodKit.Corner(box, 8)
	WoodKit.Stroke(box, W.GoldDark, 2, 0)
	return box
end

local function scrollList(parent, props)
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 8
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.ZIndex = 4
	for k, v in pairs(props) do
		s[k] = v
	end
	s.Parent = parent
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = s
	return s
end

local function clear(f)
	for _, c in ipairs(f:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function row(parent, order, h)
	return WoodKit.Board(parent, { Size = UDim2.new(1, -12, 0, h or 52), LayoutOrder = order, ZIndex = 4 })
end

---------------------------------------------------------------- หน้า Browse
local function drawBrowse()
	local p = ui.Browse
	-- โลกของฉัน
	clear(ui.MineList)
	local worlds = myWorlds()
	local full = #worlds >= (Config.WorldMaxSlots or 5)
	ui.CreateBtn.Text = full and string.format("Max %d worlds", Config.WorldMaxSlots or 5) or ("+ Create World   " .. priceText())
	WoodKit.Style(ui.CreateBtn, full and "Dark" or "Green")
	ui.MineEmpty.Visible = #worlds == 0
	for i, w in ipairs(worlds) do
		local r = row(ui.MineList, i, 50)
		label(r, { Size = UDim2.new(1, -300, 1, 0), Position = UDim2.fromOffset(14, 0), TextSize = 19, Font = UIKit.Fonts.Bold,
			Text = string.format("🌍 %s  ·  Night %d", w.Name or "World", w.Night or 1) })
		button(r, "Green", { Size = UDim2.fromOffset(170, 38), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -112, 0.5, 0), Text = "Open Room", TextSize = 18 }, function()
			setup = { Mode = "Open", WorldId = w.Id, Name = w.Name or "World", Password = "", Size = setup.Size or 4 }
			page = "Setup"
			WorldUI.Refresh()
		end)
		button(r, "Red", { Size = UDim2.fromOffset(92, 38), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
			Text = ui.ConfirmDelete == w.Id and "Sure?" or "Delete", TextSize = 16 }, function()
			if ui.ConfirmDelete == w.Id then
				ui.ConfirmDelete = nil
				act("Delete", w.Id)
			else
				ui.ConfirmDelete = w.Id
				WorldUI.Refresh()
			end
		end)
	end
	-- ห้องโลกในเซิร์ฟเวอร์นี้
	clear(ui.RoomList)
	local n = 0
	for _, room in ipairs(folder() and folder():GetChildren() or {}) do
		local hostId = room:GetAttribute("HostId")
		if hostId then
			n += 1
			local night = room:GetAttribute("Night") or 1
			local count, size = room:GetAttribute("Count") or 0, room:GetAttribute("Size") or 0
			local locked = room:GetAttribute("Locked")
			local r = row(ui.RoomList, n, 58)
			label(r, { Size = UDim2.new(1, -230, 0, 28), Position = UDim2.fromOffset(14, 4), TextSize = 20, Font = UIKit.Fonts.Title,
				Text = (locked and "🔒 " or "🌍 ") .. (room:GetAttribute("WorldName") or "World") })
			label(r, { Size = UDim2.new(1, -230, 0, 22), Position = UDim2.fromOffset(14, 31), TextSize = 15, Font = UIKit.Fonts.Bold, TextColor3 = DIM,
				Text = string.format("Host %s  ·  %s  ·  %d/%d players", room:GetAttribute("HostName") or "?", room:GetAttribute("New") and "New world" or ("Night " .. night), count, size) })
			local mine = hostId == player.UserId
			local txt, style, can
			if mine then
				txt, style = "Your Room", "Dark"
			elseif count >= size then
				txt, style = "Full", "Dark"
			elseif night > maxNight() then
				txt, style = "Need best Night " .. (night - (Config.WorldNightGate or 20)), "Dark"
			else
				txt, style, can = locked and "🔒 Join" or "Join", "Green", true
			end
			button(r, style, { Size = UDim2.fromOffset(200, 42), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Text = txt, TextSize = can and 21 or 15 }, function()
				if mine then
					WorldUI.Refresh()
				elseif can then
					if locked then
						joinTarget = { HostId = hostId, Name = room:GetAttribute("WorldName") or "World" }
						ui.PwTitle.Text = "🔒 Password for " .. joinTarget.Name
						ui.PwBox.Text = ""
						ui.PwPopup.Visible = true
					else
						act("Join", hostId, "")
					end
				end
			end)
		end
	end
	ui.RoomEmpty.Visible = n == 0
	ui.Gate.Text = string.format("You can join worlds up to Night %d (your best night + %d)", maxNight(), Config.WorldNightGate or 20)
	p.Visible = true
end

---------------------------------------------------------------- หน้า Setup (สร้างโลกใหม่ / เปิดห้องโลกเดิม)
local function drawSetup()
	local creating = setup.Mode == "Create"
	ui.SetupTitle.Text = creating and "Create a New World" or ("Open " .. (setup.Name or "World"))
	ui.NameRow.Visible = creating
	ui.NameBox.Text = setup.Name or ""
	ui.PwSet.Text = setup.Password or ""
	for i, b in ipairs(ui.SizeBtns) do
		WoodKit.Style(b, i == setup.Size and "Green" or "Dark")
	end
	ui.SetupGo.Text = creating and ("Create World   " .. priceText()) or "Open Room"
	ui.Setup.Visible = true
end

---------------------------------------------------------------- หน้าห้องรอ
local function drawRoom(roomId)
	local room = folder() and folder():FindFirstChild(tostring(roomId))
	local host = roomId == player.UserId
	if not room then
		return
	end
	local night = room:GetAttribute("Night") or 1
	ui.RoomTitle.Text = "🌍 " .. (room:GetAttribute("WorldName") or "World")
	ui.RoomSub.Text = string.format("Host %s  ·  %s  ·  %s", room:GetAttribute("HostName") or "?", room:GetAttribute("New") and "New world" or ("Night " .. night),
		room:GetAttribute("Locked") and "🔒 Password" or "Open to everyone")
	-- ช่องผู้เล่น
	clear(ui.Slots)
	local ids = {}
	for id in string.gmatch(room:GetAttribute("Members") or "", "[^,]+") do
		table.insert(ids, tonumber(id))
	end
	local size = room:GetAttribute("Size") or 1
	for i = 1, size do
		local uid = ids[i]
		local p = uid and Players:GetPlayerByUserId(uid)
		local card = WoodKit.Board(ui.Slots, { LayoutOrder = i, ZIndex = 4 }, uid and rgb(70, 52, 34) or rgb(36, 28, 22))
		label(card, { Size = UDim2.new(1, -10, 0, 30), Position = UDim2.fromOffset(5, 10), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center,
			Text = uid and (uid == roomId and "👑" or "🙂") or "·", TextColor3 = uid and LIGHT or DIM })
		label(card, { Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(5, 44), TextSize = 16, Font = UIKit.Fonts.Bold, TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd, Text = uid and (p and p.DisplayName or "?") or "Empty", TextColor3 = uid and LIGHT or DIM })
		if host and uid and uid ~= roomId then
			button(card, "Red", { Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Text = "✖", TextSize = 14 }, function()
				act("Kick", uid)
			end)
		end
	end
	ui.Waiting.Text = string.format("%d / %d players", #ids, size) .. (host and "" or "  ·  waiting for the host to enter the world")
	ui.StartBtn.Visible = host
	ui.InviteBtn.Visible = host
	ui.LeaveBtn.Text = host and "Close Room" or "Leave Room"
	ui.StartBtn.Text = "▶ Enter World (" .. #ids .. ")"
	-- รายชื่อเชิญ (เฉพาะหัวห้อง)
	ui.InvitePanel.Visible = host and ui.InviteOpen == true
	if ui.InvitePanel.Visible then
		clear(ui.InviteList)
		local invited = {}
		for id in string.gmatch(room:GetAttribute("Invited") or "", "[^,]+") do
			invited[tonumber(id)] = true
		end
		local n = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and not table.find(ids, p.UserId) then
				n += 1
				local busy = p:GetAttribute("InRun") or p:GetAttribute("WorldRoom")
				local r = row(ui.InviteList, n, 44)
				label(r, { Size = UDim2.new(1, -150, 1, 0), Position = UDim2.fromOffset(12, 0), TextSize = 17, Font = UIKit.Fonts.Bold,
					TextTruncate = Enum.TextTruncate.AtEnd, Text = p.DisplayName .. (busy and "  (busy)" or "") })
				local done = invited[p.UserId]
				button(r, (done or busy) and "Dark" or "Green", { Size = UDim2.fromOffset(120, 34), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
					Text = done and "Invited ✓" or "Invite", TextSize = 16 }, function()
					if not done and not busy then
						act("Invite", p.UserId)
					end
				end)
			end
		end
		ui.InviteEmpty.Visible = n == 0
	end
	ui.Room.Visible = true
end

---------------------------------------------------------------- วาดหน้าตามสถานะ
function WorldUI.Refresh()
	if not (ui.Win and ui.Win.Visible) then
		return
	end
	ui.Browse.Visible, ui.Setup.Visible, ui.Room.Visible = false, false, false
	local roomId = player:GetAttribute("WorldRoom")
	if roomId then
		ui.PwPopup.Visible = false
		drawRoom(roomId)
	elseif page == "Setup" then
		drawSetup()
	else
		drawBrowse()
	end
end

function WorldUI.Open()
	if player:GetAttribute("InRun") then
		return
	end
	ui.Win.Visible = true
	UIKit.Pop(ui.Win)
	WorldUI.Refresh()
end

-- เปิดตรงหน้าสร้างโลก (ปุ่ม + / เทสต์)
function WorldUI.OpenCreate()
	setup = { Mode = "Create", Name = "", Password = "", Size = setup.Size or 4 }
	page = "Setup"
	WorldUI.Open()
end

function WorldUI.Close()
	ui.Win.Visible = false
	ui.PwPopup.Visible = false
	page = "Browse"
end

---------------------------------------------------------------- สร้างหน้าต่าง
local function buildBrowse(body)
	local p = UIKit.Frame(body, { Size = UDim2.new(1, -60, 1, -60), Position = UDim2.fromOffset(30, 44), BackgroundTransparency = 1, ZIndex = 3, Visible = false })
	ui.Browse = p
	ui.CreateBtn = button(p, "Green", { Size = UDim2.fromOffset(300, 50), Position = UDim2.fromOffset(0, 0), Text = "+ Create World", TextSize = 21 }, function()
		if #myWorlds() >= (Config.WorldMaxSlots or 5) then
			return
		end
		setup = { Mode = "Create", Name = "", Password = "", Size = setup.Size or 4 }
		page = "Setup"
		WorldUI.Refresh()
	end)
	-- บรรทัดเต็มความกว้างใต้ปุ่มสร้าง (เดิมอัดในช่องแคบข้างปุ่ม ตัว 14 -> มือถือเหลือ ~7 px อ่านไม่ออก)
	ui.Gate = label(p, { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 56), TextSize = UIKit.IsTouch and 20 or 16, Font = UIKit.Fonts.Bold, TextColor3 = DIM,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
	label(p, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 86), Text = "My Worlds", Font = UIKit.Fonts.Title, TextSize = 22, TextColor3 = W.Gold })
	ui.MineList = scrollList(p, { Size = UDim2.new(1, 0, 0, 128), Position = UDim2.fromOffset(0, 116) })
	ui.MineEmpty = label(p, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 122), TextSize = 17, Font = UIKit.Fonts.Bold, TextColor3 = DIM,
		TextXAlignment = Enum.TextXAlignment.Center, Text = "No worlds yet — press + Create World" })
	label(p, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 250), Text = "Worlds in this server", Font = UIKit.Fonts.Title, TextSize = 22, TextColor3 = W.Gold })
	ui.RoomList = scrollList(p, { Size = UDim2.new(1, 0, 1, -282), Position = UDim2.fromOffset(0, 282) })
	ui.RoomEmpty = label(p, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 290), TextSize = 17, Font = UIKit.Fonts.Bold, TextColor3 = DIM,
		TextXAlignment = Enum.TextXAlignment.Center, Text = "No world rooms open right now" })
	-- หน้าต่างใส่รหัส (ห้อง 🔒)
	local pop = WoodKit.Board(body, { Size = UDim2.fromOffset(440, 200), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), ZIndex = 20, Visible = false },
		rgb(46, 32, 22))
	ui.PwPopup = pop
	ui.PwTitle = label(pop, { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 14), TextSize = 21, Font = UIKit.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21, Text = "" })
	ui.PwBox = textBox(pop, { Size = UDim2.new(1, -60, 0, 44), Position = UDim2.fromOffset(30, 62), PlaceholderText = "Password", ZIndex = 22 })
	button(pop, "Green", { Size = UDim2.fromOffset(180, 46), Position = UDim2.new(0.5, -190, 1, -64), Text = "Join", TextSize = 21, ZIndex = 22 }, function()
		if joinTarget then
			act("Join", joinTarget.HostId, ui.PwBox.Text)
		end
		pop.Visible = false
	end)
	button(pop, "Red", { Size = UDim2.fromOffset(180, 46), Position = UDim2.new(0.5, 10, 1, -64), Text = "Cancel", TextSize = 20, ZIndex = 22 }, function()
		pop.Visible = false
	end)
end

local function buildSetup(body)
	local p = WoodKit.Parchment(body, { Size = UDim2.new(1, -60, 1, -70), Position = UDim2.fromOffset(30, 44), ZIndex = 3, Visible = false })
	ui.Setup = p
	local function ink(props)
		props.ZIndex = 5
		return WoodKit.Ink(p, props)
	end
	ui.SetupTitle = ink({ Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 16), TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Text = "" })
	-- ชื่อโลก
	ui.NameRow = UIKit.Frame(p, { Size = UDim2.new(1, -60, 0, 50), Position = UDim2.fromOffset(30, 76), BackgroundTransparency = 1, ZIndex = 4 })
	WoodKit.Ink(ui.NameRow, { Size = UDim2.fromOffset(170, 50), TextSize = 21, Font = UIKit.Fonts.Bold, Text = "World name", ZIndex = 5 })
	ui.NameBox = textBox(ui.NameRow, { Size = UDim2.new(1, -180, 1, 0), Position = UDim2.fromOffset(180, 0), PlaceholderText = "e.g. Wolf Den", MaxVisibleGraphemes = 24 })
	ui.NameBox:GetPropertyChangedSignal("Text"):Connect(function()
		if #ui.NameBox.Text > 24 then
			ui.NameBox.Text = ui.NameBox.Text:sub(1, 24)
		end
		setup.Name = ui.NameBox.Text
	end)
	-- รหัสผ่าน
	ink({ Size = UDim2.fromOffset(170, 50), Position = UDim2.fromOffset(30, 140), TextSize = 21, Font = UIKit.Fonts.Bold, Text = "Password" })
	ui.PwSet = textBox(p, { Size = UDim2.new(1, -240, 0, 50), Position = UDim2.fromOffset(210, 140), PlaceholderText = "(empty = anyone can join)" })
	ui.PwSet:GetPropertyChangedSignal("Text"):Connect(function()
		if #ui.PwSet.Text > 12 then
			ui.PwSet.Text = ui.PwSet.Text:sub(1, 12)
		end
		setup.Password = ui.PwSet.Text
	end)
	-- จำนวนคน 1-8 (ปุ่มเลขเลือกได้ทุกค่า)
	ink({ Size = UDim2.fromOffset(170, 50), Position = UDim2.fromOffset(30, 206), TextSize = 21, Font = UIKit.Fonts.Bold, Text = "Players" })
	local sizes = UIKit.Frame(p, { Size = UDim2.new(1, -240, 0, 50), Position = UDim2.fromOffset(210, 206), BackgroundTransparency = 1, ZIndex = 4 })
	local sl = Instance.new("UIListLayout")
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.Padding = UDim.new(0, 6)
	sl.Parent = sizes
	ui.SizeBtns = {}
	for i = 1, MAX do
		ui.SizeBtns[i] = button(sizes, "Dark", { Size = UDim2.fromOffset(50, 50), Text = tostring(i), TextSize = 22, LayoutOrder = i }, function()
			setup.Size = i
			drawSetup()
		end)
	end
	ink({ Size = UDim2.new(1, -60, 0, 44), Position = UDim2.fromOffset(30, 266), TextSize = 16, Font = UIKit.Fonts.Bold, TextColor3 = W.InkDim, TextWrapped = true,
		Text = "Your world saves every dawn until the whole team falls. Friends with the password (or your invite) can join your room." })
	ui.SetupGo = button(p, "Green", { Size = UDim2.fromOffset(300, 56), Position = UDim2.new(0.5, -310, 1, -80), Text = "", TextSize = 22 }, function()
		if setup.Mode == "Create" then
			act("Create", setup.Name or "", setup.Password or "", setup.Size)
		else
			act("Open", setup.WorldId, setup.Password or "", setup.Size)
		end
		page = "Browse"
	end)
	button(p, "Red", { Size = UDim2.fromOffset(200, 56), Position = UDim2.new(0.5, 10, 1, -80), Text = "Back", TextSize = 22 }, function()
		page = "Browse"
		WorldUI.Refresh()
	end)
end

local function buildRoom(body)
	local p = UIKit.Frame(body, { Size = UDim2.new(1, -60, 1, -60), Position = UDim2.fromOffset(30, 44), BackgroundTransparency = 1, ZIndex = 3, Visible = false })
	ui.Room = p
	ui.RoomTitle = label(p, { Size = UDim2.new(1, 0, 0, 40), TextSize = 32, Font = UIKit.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = W.Gold, Text = "" })
	ui.RoomSub = label(p, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 42), TextSize = 17, Font = UIKit.Fonts.Bold, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = DIM, Text = "" })
	-- ช่องผู้เล่น 4 ต่อแถว (สูงสุด 8 = 2 แถว)
	ui.Slots = UIKit.Frame(p, { Size = UDim2.new(1, 0, 0, 176), Position = UDim2.fromOffset(0, 76), BackgroundTransparency = 1, ZIndex = 4 })
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.25, -9, 0, 82)
	g.CellPadding = UDim2.fromOffset(12, 12)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.Parent = ui.Slots
	ui.Waiting = label(p, { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 258), TextSize = 18, Font = UIKit.Fonts.Bold, TextXAlignment = Enum.TextXAlignment.Center, Text = "" })
	ui.StartBtn = button(p, "Green", { Size = UDim2.fromOffset(300, 60), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 292), Text = "▶ Enter World", TextSize = 26 }, function()
		act("Start")
		WorldUI.Close()
	end)
	ui.InviteBtn = button(p, "Dark", { Size = UDim2.fromOffset(220, 46), Position = UDim2.new(0, 0, 1, -50), Text = "📨 Invite Players", TextSize = 19 }, function()
		ui.InviteOpen = not ui.InviteOpen
		WorldUI.Refresh()
	end)
	ui.LeaveBtn = button(p, "Red", { Size = UDim2.fromOffset(200, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 1, -50), Text = "Leave Room", TextSize = 19 }, function()
		ui.InviteOpen = false
		act("Leave")
	end)
	-- รายชื่อคนในเซิร์ฟเวอร์สำหรับเชิญ (ซ้อนบนหน้าห้อง)
	local inv = WoodKit.Board(p, { Size = UDim2.new(0, 420, 0, 250), Position = UDim2.new(0, 0, 1, -308), ZIndex = 12, Visible = false }, rgb(40, 28, 20))
	ui.InvitePanel = inv
	label(inv, { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 6), TextSize = 20, Font = UIKit.Fonts.Title, ZIndex = 13, Text = "Invite players in this server" })
	ui.InviteList = scrollList(inv, { Size = UDim2.new(1, -16, 1, -46), Position = UDim2.fromOffset(8, 40), ZIndex = 13 })
	ui.InviteEmpty = label(inv, { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 50), TextSize = 16, Font = UIKit.Fonts.Bold, TextColor3 = DIM, ZIndex = 13,
		TextXAlignment = Enum.TextXAlignment.Center, Text = "No one else in this server yet" })
end

-- หน้าต่างคำเชิญ (ลอยกลางบน · หายเองใน 30 วิ)
local function buildInvite(gui)
	local f = WoodKit.Board(gui, { Size = UDim2.fromOffset(520, 150), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Visible = false, ZIndex = 50 }, rgb(46, 32, 22))
	UIKit.AutoScale(f, { maxW = 0.9 })
	ui.Inv = f
	ui.InvText = label(f, { Size = UDim2.new(1, -24, 0, 60), Position = UDim2.fromOffset(12, 10), TextSize = 20, Font = UIKit.Fonts.Title, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 51, Text = "" })
	button(f, "Green", { Size = UDim2.fromOffset(200, 50), Position = UDim2.new(0.5, -210, 1, -64), Text = "Join", TextSize = 22, ZIndex = 52 }, function()
		if ui.InvFrom then
			act("Join", ui.InvFrom, "", true)
		end
		f.Visible = false
	end)
	button(f, "Red", { Size = UDim2.fromOffset(200, 50), Position = UDim2.new(0.5, 10, 1, -64), Text = "Decline", TextSize = 20, ZIndex = 52 }, function()
		f.Visible = false
	end)
end

function WorldUI.Init()
	local gui = UIKit.Screen("WorldUI", 33)
	local win = WoodKit.Window(gui, {
		Name = "WorldsWindow", Size = Vector2.new(800, 640), Title = "🌍 Worlds", TitleWidth = 260, Beasts = false, Lanterns = false, OnClose = WorldUI.Close,
	})
	ui.Win = win.Frame
	UIKit.RegisterWindow(ui.Win, WorldUI.Close, { Dim = 0.55 })
	local body = win.Body
	buildBrowse(body)
	buildSetup(body)
	buildRoom(body)
	buildInvite(gui)
	-- ปุ่มเปิดเมนู (มุมขวาบน ใต้แคปซูล Ruby) · เฉพาะในล็อบบี้
	local btn = WoodKit.Button(gui, "Green", { Size = UDim2.fromOffset(190, 50), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 78), Text = "🌍 Worlds", TextSize = 24 }, function()
		if ui.Win.Visible then
			WorldUI.Close()
		else
			WorldUI.Open()
		end
	end)
	UIKit.AutoScale(btn, { w = 230, maxW = 0.25 })
	-- อยู่ใต้แคปซูล Ruby เสมอ: แคปซูลขยายตามจอ (2K/4K) -> เลื่อนลงตามสเกลเดียวกัน (เดิม y ตายตัว 78 -> 4K ทับกัน)
	local function placeBtn()
		local s = UIKit.GetScale(btn)
		btn.Position = UDim2.new(1, -24, 0, math.floor(20 + 58 * s))
	end
	placeBtn()
	UIKit.OnResize(placeBtn)
	local function vis()
		btn.Visible = not player:GetAttribute("InRun") and not player:GetAttribute("Departing")
		if not btn.Visible then
			WorldUI.Close()
			ui.Inv.Visible = false
		end
	end
	for _, a in ipairs({ "InRun", "Departing" }) do
		player:GetAttributeChangedSignal(a):Connect(vis)
	end
	vis()
	-- หน้าต่างอื่นเปิดอยู่ (ร้านค้า/คลาส/ภารกิจ/เลือกจำนวนคน ฯลฯ) -> ซ่อนปุ่ม Worlds (ScreenGui นี้อยู่ชั้นบน เคยลอยทับเนื้อหาหน้าต่าง)
	local lastCheck = 0
	game:GetService("RunService").Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastCheck < 0.15 then
			return
		end
		lastCheck = now
		local lobby = not player:GetAttribute("InRun") and not player:GetAttribute("Departing")
		local top = UIKit.TopWindow()
		local want = lobby and not top -- รวมหน้าต่าง Worlds เอง: มือถือ ปุ่มนี้เคยทับปุ่มปิด X + ข้อความมุมขวาบนของหน้าต่าง (ปิดด้วย X แทน)
		if btn.Visible ~= want then
			btn.Visible = want
		end
	end)
	-- เข้าห้องได้ (สร้าง/เปิด/รับเชิญ/ใส่รหัสถูก) -> เปิดหน้าห้องรอให้เลย
	player:GetAttributeChangedSignal("WorldRoom"):Connect(function()
		ui.InviteOpen = false
		if player:GetAttribute("WorldRoom") and not player:GetAttribute("InRun") then
			ui.Inv.Visible = false
			WorldUI.Open()
		else
			WorldUI.Refresh()
		end
	end)
	for _, a in ipairs({ "MyWorlds", "BestNight" }) do
		player:GetAttributeChangedSignal(a):Connect(WorldUI.Refresh)
	end
	Players.PlayerAdded:Connect(WorldUI.Refresh)
	Players.PlayerRemoving:Connect(function()
		task.defer(WorldUI.Refresh)
	end)
	local f = ReplicatedStorage:WaitForChild("Worlds", 30)
	if f then
		local function hook(c)
			c.AttributeChanged:Connect(WorldUI.Refresh)
		end
		for _, c in ipairs(f:GetChildren()) do
			hook(c)
		end
		f.ChildAdded:Connect(function(c)
			hook(c)
			WorldUI.Refresh()
		end)
		f.ChildRemoved:Connect(WorldUI.Refresh)
	end
	Remotes.Get("Cinematic").OnClientEvent:Connect(function(kind, d)
		if kind == "BuyWorld" and (Config.WorldProductId or 0) > 0 then
			-- กดสร้างแต่ยังไม่มีสิทธิ์ -> เด้งซื้อ · ซื้อเสร็จเซิร์ฟเวอร์สร้างโลก + เปิดห้องรอให้เอง
			MarketplaceService:PromptProductPurchase(player, Config.WorldProductId)
		elseif kind == "WorldInvite" and type(d) == "table" and not player:GetAttribute("InRun") and not player:GetAttribute("WorldRoom") then
			ui.InvFrom = d.HostId
			ui.InvText.Text = string.format("📨 %s invited you to %s (%s)", tostring(d.HostName), tostring(d.WorldName), d.New and "new world" or ("Night " .. tostring(d.Night)))
			ui.Inv.Visible = true
			UIKit.Pop(ui.Inv)
			local token = {}
			ui.InvToken = token
			task.delay(30, function()
				if ui.InvToken == token then
					ui.Inv.Visible = false
				end
			end)
		end
	end)
	task.spawn(function()
		if (Config.WorldProductId or 0) > 0 then
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, Config.WorldProductId, Enum.InfoType.Product)
			ui.Price = ok and info and info.PriceInRobux or nil
			WorldUI.Refresh()
		end
	end)
end

return WorldUI
