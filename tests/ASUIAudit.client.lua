--[[
	ASUIAudit (client) — build_rbxlx.py --uiaudit (คอม/โน้ตบุ๊ก) · --uiaudit=touch (มือถือ/แท็บเล็ต)
	จำลองจอหลายขนาดใน Studio: ย้าย UI ทุก ScreenGui ลงกรอบ "จอจำลอง" ขนาดเท่าเครื่องจริง (พื้นที่ปลอดภัยหักติ่งกล้องแล้ว)
	+ UIKit.Sim ให้ระบบสเกลคิดเหมือนเครื่องนั้น แล้วให้เอนจินจัดวางจริง -> วัด AbsolutePosition/AbsoluteSize ตรวจ:
	  OOB     ชิ้นที่มองเห็นได้ล้นขอบจอ
	  CLIP    ตัวหนังสือไม่พอดีกรอบ (TextFits = false)
	  SMALL   ตัวหนังสือเล็กเกินอ่าน (px บนจอเครื่องนั้น)
	  TOUCH   ปุ่มเล็กเกินนิ้วกด (โหมด touch)
	  OVERLAP แผงทับกันเอง / ทับปุ่ม Roblox (แถบบน, ปุ่มกระโดด, จอยสติ๊ก) — ตรวจเฉพาะหน้าจอหลัก (ไม่เปิดหน้าต่าง)
	ผล: log "[AS] UI ..." + ภาพ build/test_screenshots/ui_<เครื่อง>_<หน้าจอ>.png
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASUIAudit") then
	return
end
local TOUCH = ReplicatedStorage:FindFirstChild("ASSimTouch") ~= nil
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local client = script.Parent:WaitForChild("Client")
local UIKit = require(client:WaitForChild("UIKit"))
local state = ReplicatedStorage:WaitForChild("GameState")
while not state:GetAttribute("Ready") do
	task.wait(0.5)
end
task.wait(5)
local function req(n)
	local ok, m = pcall(require, client:WaitForChild(n, 5))
	return ok and m or nil
end
local HUD, Menus, QuestUI, StoreUI, SettingsUI, Tutorial, ClassShop, MapUI, Backpack, LobbyUI =
	req("HUD"), req("Menus"), req("QuestUI"), req("StoreUI"), req("SettingsUI"), req("Tutorial"), req("ClassShop"), req("MapUI"), req("Backpack"), req("LobbyUI")

-- { ชื่อ, กว้าง, สูง (พื้นที่ปลอดภัยของเครื่องแนวนอน), ชนิด, ถ่ายทุกหน้าต่าง? }
local PROFILES = TOUCH and {
	{ "Phone640x360", 640, 360, "Phone", true }, -- มือถือจอเล็ก/เก่าสุด
	{ "iPhoneSE", 667, 375, "Phone" },
	{ "Galaxy740x360", 740, 360, "Phone" },
	{ "iPhone14", 750, 369, "Phone", true }, -- 844x390 หักติ่ง/แถบโฮม
	{ "iPhoneProMax", 838, 409, "Phone" },
	{ "Android885x412", 885, 412, "Phone" },
	{ "Fold882x690", 882, 690, "Tablet" },
	{ "iPadMini", 1133, 724, "Tablet", true },
	{ "AndroidTab1280x800", 1280, 800, "Tablet" },
	{ "iPad", 1180, 800, "Tablet" },
	{ "iPadPro13", 1366, 1004, "Tablet" },
} or {
	{ "Win900x560", 900, 560, "Desktop", true }, -- หน้าต่างเล็กสุด
	{ "Win1024x576", 1024, 576, "Desktop" },
	{ "Laptop1366@125", 1093, 614, "Desktop", true },
	{ "HD1280x720", 1280, 720, "Desktop" },
	{ "Laptop1366x705", 1366, 705, "Desktop" },
	{ "Laptop1536x864", 1536, 864, "Desktop" },
	{ "SXGA1280x1024", 1280, 1024, "Desktop" },
	{ "FHD1920x1017", 1920, 1017, "Desktop", true },
	{ "QHD2560x1377", 2560, 1377, "Desktop" },
	{ "Ultrawide3440", 3440, 1377, "Desktop" },
	{ "4K3840x2097", 3840, 2097, "Desktop" },
}

---------------------------------------------------------------- จอจำลอง
local overlay = Instance.new("ScreenGui")
overlay.Name = "ASUIAuditOverlay"
overlay.IgnoreGuiInset = true
overlay.DisplayOrder = 10000
overlay.ResetOnSpawn = false
overlay.Parent = pg
local SKIP = { ASUIAuditOverlay = true, BubbleChat = true, Chat = true, Freecam = true, TouchGui = true, ASDevPanel = true, DevPanel = true }
local sims = {} -- gui -> root
local cur -- { Size, K, O }

local function realVP()
	return workspace.CurrentCamera.ViewportSize
end
local function insetY()
	return GuiService:GetGuiInset().Y
end
local function adopt(gui)
	if sims[gui] or not gui:IsA("ScreenGui") or SKIP[gui.Name] then
		return
	end
	local root = Instance.new("Frame")
	root.Name = "ASSimRoot"
	root.BackgroundTransparency = 1
	root.ClipsDescendants = true
	local k = Instance.new("UIScale")
	k.Name = "ASSimK"
	k.Parent = root
	for _, c in ipairs(gui:GetChildren()) do
		if not c:IsA("LuaSourceContainer") then
			c.Parent = root
		end
	end
	root.Parent = gui
	sims[gui] = root
	gui.ChildAdded:Connect(function(c)
		if c ~= root and not c:IsA("LuaSourceContainer") then
			task.defer(function()
				if c.Parent == gui then
					c.Parent = root
				end
			end)
		end
	end)
end
local function place(gui, root)
	local vp, V, kk = realVP(), cur.Size, cur.K
	local t = gui.IgnoreGuiInset and 0 or insetY()
	root.AnchorPoint = Vector2.zero
	root.Size = UDim2.fromOffset(V.X, V.Y - t)
	root.Position = UDim2.fromOffset(cur.O.X, cur.O.Y + t * kk - t)
	root.ASSimK.Scale = kk
end

local zoneFrames = {}
local function zones(V, dev)
	local ins = GuiService.TopbarInset
	local tw = ins.Min.X > 0 and ins.Min.X or 250
	local th = ins.Height > 0 and ins.Height or 58
	local z = { { "RobloxTopbar", 0, 0, tw, th } }
	if TOUCH then
		local small = math.min(V.X, V.Y) <= 500
		if small then
			table.insert(z, { "JumpButton", V.X - 95, V.Y - 90, V.X - 25, V.Y - 20 })
			table.insert(z, { "Thumbstick", 20, V.Y - 170, 200, V.Y - 20 })
		else
			table.insert(z, { "JumpButton", V.X - 170, V.Y - 210, V.X - 50, V.Y - 90 })
			table.insert(z, { "Thumbstick", 40, V.Y - 280, 300, V.Y - 40 })
		end
	end
	return z
end

local label = Instance.new("TextLabel")
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.BackgroundTransparency = 0.2
label.TextColor3 = Color3.fromRGB(255, 255, 0)
label.Font = Enum.Font.Code
label.TextSize = 14
label.Size = UDim2.fromOffset(520, 20)
label.Position = UDim2.fromOffset(4, 4)
label.TextXAlignment = Enum.TextXAlignment.Left
label.ZIndex = 50
label.Parent = overlay
local masks = {}
for i = 1, 4 do
	local m = Instance.new("Frame")
	m.BackgroundColor3 = Color3.fromRGB(30, 0, 40)
	m.BorderSizePixel = 0
	m.ZIndex = 40
	m.Parent = overlay
	masks[i] = m
end
local outline = Instance.new("Frame")
outline.BackgroundTransparency = 1
outline.ZIndex = 41
outline.Parent = overlay
local os_ = Instance.new("UIStroke")
os_.Color = Color3.fromRGB(255, 0, 200)
os_.Thickness = 2
os_.Parent = outline

local function setSim(p)
	if not p then
		UIKit.Sim = nil
		cur = nil
		for gui, root in pairs(sims) do
			root.AnchorPoint = Vector2.zero
			root.Position = UDim2.fromOffset(0, 0)
			root.Size = UDim2.fromScale(1, 1)
			root.ASSimK.Scale = 1
		end
		for _, m in ipairs(masks) do
			m.Visible = false
		end
		outline.Visible = false
		UIKit.RefreshScale()
		return
	end
	for _, g in ipairs(pg:GetChildren()) do
		adopt(g)
	end
	local V = Vector2.new(p[2], p[3])
	-- วัดที่สเกล 1:1 เสมอ (ไม่ขึ้นกับหน้าต่าง Studio — ย่อหน้าต่างอยู่ก็วัดถูก) · ย่อให้เห็นทั้งจอเฉพาะตอนถ่ายภาพ
	cur = { Size = V, K = 1, O = Vector2.zero, Dev = p[4], Name = p[1], P = p }
	UIKit.Sim = { Size = V, Device = p[4] }
	for gui, root in pairs(sims) do
		place(gui, root)
	end
	UIKit.RefreshScale()
end
-- ย่อ/วางจอจำลองให้พอดีหน้าต่าง Studio (ภาพหน้าจอ) แล้ววาดกรอบ + โซนปุ่ม Roblox
local function fitView(on)
	local V, p = cur.Size, cur.P
	local kk, O = 1, Vector2.zero
	if on then
		local vp = realVP()
		kk = math.max(0.1, math.min(1, (vp.X - 8) / V.X, (vp.Y - 30) / V.Y))
		O = Vector2.new(math.floor((vp.X - V.X * kk) / 2), math.floor(26 + (vp.Y - 26 - V.Y * kk) / 2))
	end
	cur.K, cur.O = kk, O
	for gui, root in pairs(sims) do
		place(gui, root)
	end
	for _, m in ipairs(masks) do
		m.Visible = on
	end
	outline.Visible = on
	label.Visible = on
	local w, h = V.X * kk, V.Y * kk
	masks[1].Position, masks[1].Size = UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, O.Y)
	masks[2].Position, masks[2].Size = UDim2.fromOffset(0, O.Y + h), UDim2.new(1, 0, 1, 0)
	masks[3].Position, masks[3].Size = UDim2.fromOffset(0, O.Y), UDim2.fromOffset(O.X, h)
	masks[4].Position, masks[4].Size = UDim2.fromOffset(O.X + w, O.Y), UDim2.new(1, 0, 0, h)
	outline.Position, outline.Size = UDim2.fromOffset(O.X, O.Y), UDim2.fromOffset(w, h)
	for _, f in ipairs(zoneFrames) do
		f:Destroy()
	end
	table.clear(zoneFrames)
	for _, z in ipairs(zones(V, p[4])) do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.fromRGB(255, 0, 200)
		f.BackgroundTransparency = 0.75
		f.BorderSizePixel = 0
		f.ZIndex = 42
		f.Position = UDim2.fromOffset(O.X + z[2] * kk, O.Y + z[3] * kk)
		f.Size = UDim2.fromOffset((z[4] - z[2]) * kk, (z[5] - z[3]) * kk)
		f.Visible = on
		f.Parent = overlay
		table.insert(zoneFrames, f)
	end
	label.Text = string.format(" %s %dx%d (%s) x%.2f", p[1], V.X, V.Y, p[4], kk)
end

---------------------------------------------------------------- วัด
-- หน่วยของ TextBounds (จอจริง หรือก่อน UIScale) + สัดส่วนความสูงบรรทัดต่อ TextSize
local calib = { screen = true, ratio = 1.15 }
do
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(400, 100)
	f.BackgroundTransparency = 1
	f.Parent = overlay
	local s = Instance.new("UIScale")
	s.Scale = 0.5
	s.Parent = f
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromOffset(400, 60)
	t.TextSize = 40
	t.Font = Enum.Font.BuilderSansBold
	t.Text = "Abg ทดสอบ"
	t.TextTransparency = 1
	t.BackgroundTransparency = 1
	t.Parent = f
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	local y = t.TextBounds.Y
	calib.screen = y < 32
	calib.ratio = (calib.screen and y * 2 or y) / 40
	print(string.format("[AS] UI calib TextBounds.Y=%.1f screen=%s ratio=%.2f", y, tostring(calib.screen), calib.ratio))
	f:Destroy()
end

-- เทียบกับกรอบจอจำลองของ gui นั้นเอง (AbsolutePosition ของ Roblox นับจากใต้แถบบนเสมอ แม้ IgnoreGuiInset)
local function rectOf(o, gui)
	local root = sims[gui]
	local t = gui.IgnoreGuiInset and 0 or insetY()
	local p = (o.AbsolutePosition - root.AbsolutePosition) / cur.K + Vector2.new(0, t)
	local s = o.AbsoluteSize / cur.K
	return { p.X, p.Y, p.X + s.X, p.Y + s.Y }
end
local function inter(a, b)
	return { math.max(a[1], b[1]), math.max(a[2], b[2]), math.min(a[3], b[3]), math.min(a[4], b[4]) }
end
local function area(r)
	return math.max(0, r[3] - r[1]) * math.max(0, r[4] - r[2])
end
local function union(a, b)
	if not a then
		return b
	end
	return { math.min(a[1], b[1]), math.min(a[2], b[2]), math.max(a[3], b[3]), math.max(a[4], b[4]) }
end
local function isText(o)
	return o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")
end
local function hasImage(o)
	if not (o:IsA("ImageLabel") or o:IsA("ImageButton")) or o.ImageTransparency >= 0.9 then
		return false
	end
	if o.Image ~= "" then
		return true
	end
	local ok, v = pcall(function()
		local c = o.ImageContent
		return c ~= nil and ((c.Uri ~= nil and c.Uri ~= "") or c.Object ~= nil)
	end)
	return ok and v
end
-- สิ่งที่ "มองเห็น" ของชิ้นนี้เอง: "text" / "image" / "bg" / nil
local function content(o)
	if isText(o) and o.Text ~= "" and o.TextTransparency < 0.9 then
		return "text"
	end
	if hasImage(o) then
		return "image"
	end
	if o.BackgroundTransparency < 0.9 then
		return "bg"
	end
	local st = o:FindFirstChildOfClass("UIStroke")
	if st and st.Enabled and st.Transparency < 0.9 and st.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
		return "bg"
	end
	return nil
end
local function textRect(o, r)
	local b = o.TextBounds
	if calib.screen then
		b = b / cur.K
	else
		-- TextBounds ก่อน UIScale: คูณสเกลสะสม (ไม่รวมจอจำลอง)
		local w = r[3] - r[1]
		local s = o.AbsoluteSize.X > 0 and (w / math.max(o.AbsoluteSize.X / cur.K, 1)) or 1
		b = b * s
	end
	local w, h = math.min(b.X, r[3] - r[1]), math.min(b.Y, r[4] - r[2])
	local x = r[1]
	if o.TextXAlignment == Enum.TextXAlignment.Center then
		x = (r[1] + r[3] - w) / 2
	elseif o.TextXAlignment == Enum.TextXAlignment.Right then
		x = r[3] - w
	end
	local y = (r[2] + r[4] - h) / 2
	if o.TextYAlignment == Enum.TextYAlignment.Top then
		y = r[2]
	elseif o.TextYAlignment == Enum.TextYAlignment.Bottom then
		y = r[4] - h
	end
	return { x, y, x + w, y + h }, b
end
local function cumScale(o)
	local s = 1
	local p = o
	while p and not p:IsA("ScreenGui") do
		for _, c in ipairs(p:GetChildren()) do
			if c:IsA("UIScale") and c.Name ~= "ASSimK" then
				s *= c.Scale
			end
		end
		p = p.Parent
	end
	return s
end
local function nameOf(o, gui)
	local parts = {}
	local p = o
	while p and p ~= gui and #parts < 4 do
		if p.Name ~= "ASSimRoot" then
			local n = p.Name
			if n == p.ClassName then
				local t = (isText(p) and p.Text ~= "") and p.Text or nil
				if not t then
					local d = p:FindFirstChildWhichIsA("TextLabel", true)
					t = d and d.Text ~= "" and d.Text or nil
				end
				n = p.ClassName .. (t and ("'" .. t:gsub("%s+", " "):sub(1, 18) .. "'") or "")
			end
			table.insert(parts, 1, n)
		end
		p = p.Parent
	end
	return gui.Name .. "/" .. table.concat(parts, "/")
end

local MIN_TEXT = { Phone = 9, Tablet = 10, Desktop = 10 }
local MIN_TOUCH = 36
local agg = {} -- key -> { n, worst, where = {} }
local totals = { OOB = 0, CLIP = 0, CUT = 0, SMALL = 0, TOUCH = 0, OVERLAP = 0 }
local function report(kind, key, amount, list)
	local k = kind .. " " .. key
	local a = agg[k]
	if not a then
		a = { n = 0, worst = 0, where = {} }
		agg[k] = a
	end
	a.n += 1
	a.worst = math.max(a.worst, amount or 0)
	a.where[cur.Name] = true
	totals[kind] += 1
	table.insert(list, string.format("%s %s (%.0f)", kind, key, amount or 0))
end

local function audit(stateName, checkOverlap)
	local V = cur.Size
	local screen = { 0, 0, V.X, V.Y }
	local issues = {}
	local units = {}
	local dev = cur.Dev
	for gui, root in pairs(sims) do
		if gui.Enabled and gui.Parent then
			-- เดินทุกชิ้นที่มองเห็น (พ่อแม่ Visible ทั้งสาย) · clip = กรอบที่ตัดขอบลูก
			-- hard = ถูกตัดขอบโดยกรอบที่ไม่ใช่ ScrollingFrame (เลื่อนดูไม่ได้ = ของหายจริง)
			local function walk(o, clip, unit, hard)
				for _, c in ipairs(o:GetChildren()) do
					if c:IsA("GuiObject") and c.Visible then
						local r = rectOf(c, gui)
						local full = (r[3] - r[1]) >= V.X * 0.9 and (r[4] - r[2]) >= V.Y * 0.9
						local kind = content(c)
						local myUnit = unit
						if not unit and not (full and kind == nil) then
							myUnit = { name = nameOf(c, gui), rect = nil, full = full }
							table.insert(units, myUnit)
						end
						local vis = r
						if clip then
							vis = inter(r, clip)
						end
						if kind and hard and clip and clip[4] - clip[2] >= 40 and area(r) > 150 and area(vis) < area(r) * 0.6 and not full then
							report("CUT", nameOf(c, gui), 100 - area(vis) / area(r) * 100, issues)
						end
						if kind and area(vis) > 1 and not full then
							local cr = vis
							if kind == "text" then
								local tr, b = textRect(c, r)
								cr = clip and inter(tr, clip) or tr
								-- ตัวหนังสือเล็ก (ขนาดจริงบนจอเครื่องนั้น)
								local lines = math.max(1, select(2, c.Text:gsub("\n", "")) + 1)
								local eff = (b.Y / lines) / calib.ratio
								if not c.TextScaled then
									local sx = (c.Size.X.Scale == 0 and c.Size.X.Offset > 0) and (r[3] - r[1]) / c.Size.X.Offset or cumScale(c)
									eff = math.min(eff, c.TextSize * sx)
								end
								if eff > 1 and eff < MIN_TEXT[dev] and area(cr) > 1 then
									report("SMALL", nameOf(c, gui), eff, issues)
								end
								if not c.TextFits and c.TextTransparency < 0.5 then
									report("CLIP", nameOf(c, gui), 0, issues)
								end
							end
							if area(cr) > 1 then
								local over = math.max(screen[1] - cr[1], screen[2] - cr[2], cr[3] - screen[3], cr[4] - screen[4])
								if over > 2 then
									report("OOB", nameOf(c, gui), over, issues)
								end
								if myUnit and not myUnit.full then
									myUnit.rect = union(myUnit.rect, inter(cr, screen))
								end
							end
						end
						local dead = isText(c) and (c.Text:find("เร็วๆ", 1, true) or c.Text:find("เติม Ruby", 1, true))
						if TOUCH and not dead and c:IsA("GuiButton") and c.Active and area(vis) > 1 and c.Name ~= "TouchHit" and not full then
							local hit = c:FindFirstChild("TouchHit")
							local hr = hit and hit.Visible and rectOf(hit, gui) or r
							local m = math.min(hr[3] - hr[1], hr[4] - hr[2])
							if m < MIN_TOUCH then
								report("TOUCH", nameOf(c, gui), m, issues)
							end
						end
						local nclip, nhard = clip, hard
						if c.ClipsDescendants or c:IsA("ScrollingFrame") then
							nclip = clip and inter(clip, r) or r
							nhard = not c:IsA("ScrollingFrame")
						end
						walk(c, nclip, myUnit, nhard)
					end
				end
			end
			walk(root, nil, nil, false)
		end
	end
	if checkOverlap then
		local list = {}
		for _, u in ipairs(units) do
			if u.rect and area(u.rect) > 16 then
				table.insert(list, u)
			end
		end
		for _, z in ipairs(zones(V, dev)) do
			table.insert(list, { name = "[" .. z[1] .. "]", rect = { z[2], z[3], z[4], z[5] }, zone = true })
		end
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				if not (a.zone and b.zone) then
					local ia = area(inter(a.rect, b.rect))
					local small = math.min(area(a.rect), area(b.rect))
					if ia > 60 and ia > small * 0.02 then
						report("OVERLAP", a.name .. " x " .. b.name, ia, issues)
					end
				end
			end
		end
	end
	local c = { OOB = 0, CLIP = 0, CUT = 0, SMALL = 0, TOUCH = 0, OVERLAP = 0 }
	for _, s in ipairs(issues) do
		local k = s:match("^(%u+)")
		c[k] = (c[k] or 0) + 1
	end
	print(string.format("[AS] UI %s %s oob=%d clip=%d cut=%d small=%d touch=%d overlap=%d", cur.Name, stateName, c.OOB, c.CLIP, c.CUT, c.SMALL, c.TOUCH, c.OVERLAP))
	for i = 1, math.min(#issues, 14) do
		print("[AS] UI    " .. issues[i])
	end
end

local function settle()
	for _ = 1, 3 do
		RunService.Heartbeat:Wait()
	end
	task.wait(0.7) -- แอนิเมชันเปิดหน้าต่าง (Pop) จบก่อนวัด
end
local function shot(name)
	fitView(true)
	task.wait(0.4)
	print("[SHOT] ui_" .. cur.Name .. "_" .. name)
	task.wait(2.6)
	fitView(false)
	task.wait(0.1)
end

---------------------------------------------------------------- หน้าจอที่ตรวจ
local function closeAll()
	pcall(function()
		QuestUI.Close()
	end)
	pcall(function()
		StoreUI.Close()
	end)
	pcall(function()
		SettingsUI.Close()
	end)
	pcall(function()
		Tutorial.Close()
	end)
	pcall(function()
		ClassShop.Close()
	end)
	pcall(function()
		Menus.CloseCraft()
	end)
	pcall(function()
		MapUI.Close()
	end)
	pcall(function()
		Backpack.ToggleInventory(false)
	end)
	for _, n in ipairs({ "BadgeWindow", "TraderWindow", "PadPicker" }) do
		local w = pg:FindFirstChild(n, true)
		if w then
			w.Visible = false
		end
	end
end
local function showNamed(n)
	return function()
		local w = pg:FindFirstChild(n, true)
		if w then
			w.Visible = true
		end
	end
end
local LOBBY = {
	{ "store", function() StoreUI.Open() end },
	{ "quests", function() QuestUI.Open("Quests") end },
	{ "badges", function()
		showNamed("BadgeWindow")()
		pcall(LobbyUI.Refresh)
	end },
	{ "settings", function() SettingsUI.Open() end },
	{ "tutorial", function() Tutorial.Open() end },
	{ "padpicker", showNamed("PadPicker") },
	{ "classes", function() ClassShop.Open() end },
}
local RUN = {
	{ "craft", function() Menus.OpenCraft() end },
	{ "trader", function() Menus.OpenTrader() end },
	{ "map", function() MapUI.Toggle() end },
	{ "inventory", function() Backpack.ToggleInventory(true) end },
}

local function pass(phase, windows)
	for _, p in ipairs(PROFILES) do
		closeAll()
		setSim(p)
		settle()
		audit(phase, true)
		shot(phase)
		for _, w in ipairs(windows) do
			closeAll()
			local ok, err = pcall(w[2])
			if not ok then
				print("[AS] UI open " .. w[1] .. " failed: " .. tostring(err))
			end
			settle()
			audit(phase .. "+" .. w[1], false)
			if p[5] then
				shot(phase .. "_" .. w[1])
			end
		end
		closeAll()
	end
end

-- ล็อบบี้: แจ้งเตือนหลายอันพร้อมกัน (ทดสอบกล่องแจ้งเตือน)
local function spamFeed()
	if HUD and HUD.Notify then
		for i = 1, 3 do
			pcall(HUD.Notify, "ทดสอบแจ้งเตือนยาว ๆ บรรทัดที่ " .. i .. " — เก็บไม้ได้ 12 ชิ้น หมาป่ากำลังเข้ามาใกล้แคมป์!", "info")
		end
	end
end

spamFeed()
pass("lobby", LOBBY)

-- เข้าแมพ: ขึ้นแท่น 1 คน
setSim(nil)
closeAll()
local zone = workspace:WaitForChild("Lobby"):FindFirstChild("MatchBox1", true)
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if zone and hrp then
	hrp.CFrame = zone.CFrame
	task.wait(2)
	pcall(function()
		require(ReplicatedStorage.Shared.Remotes).Get("PadSize"):FireServer(zone:GetAttribute("PadIndex"), 1)
	end)
end
local t0 = os.clock()
while not player:GetAttribute("InRun") and os.clock() - t0 < 90 do
	task.wait(0.5)
end
print("[AS] UI inRun=" .. tostring(player:GetAttribute("InRun")))
if player:GetAttribute("InRun") then
	task.wait(12) -- ฉากเปิด/โหลดแมพ
	closeAll()
	spamFeed()
	pcall(HUD.Pickup, "Wood", 3)
	pass("run", RUN)
end

---------------------------------------------------------------- สรุป
setSim(nil)
print(string.format("[AS] UI TOTAL oob=%d clip=%d cut=%d small=%d touch=%d overlap=%d", totals.OOB, totals.CLIP, totals.CUT, totals.SMALL, totals.TOUCH, totals.OVERLAP))
local keys = {}
for k in pairs(agg) do
	table.insert(keys, k)
end
table.sort(keys, function(a, b)
	return agg[a].n > agg[b].n
end)
for _, k in ipairs(keys) do
	local a = agg[k]
	local where = {}
	for n in pairs(a.where) do
		table.insert(where, n)
	end
	table.sort(where)
	print(string.format("[AS] UI ISSUE x%d worst=%.0f %s @ %s", a.n, a.worst, k, table.concat(where, ",")))
end
print("[TEST] DONE uiaudit")
