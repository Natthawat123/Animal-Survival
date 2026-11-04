--[[ ASSkillProbe (client) — ภาพเอฟเฟกต์คลาส 5 ดาว
	ตัวถ่ายภาพช้า/ไม่แน่นอน (~0.5-1.3 วิ) -> เอฟเฟกต์สั้นเล่นซ้ำซ้อนกันหลายรอบช่วงที่จะถ่าย ภาพไหนก็ติดจังหวะสวย
	เอฟเฟกต์ยาว (อุกกาบาต/เทพ) เล่นรอบเดียว ถ่ายหลายเฟรม · กล้องล็อกมุมเฉียงหลังขวา
	เริ่มเมื่อเซิร์ฟเวอร์ตั้ง ReplicatedStorage.FxShow · จบ "[AS] SKILLPROBE FXSHOW DONE" ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASSkillProbe") then
	return
end
local player = Players.LocalPlayer

repeat
	task.wait(0.5)
until ReplicatedStorage:GetAttribute("FxShow")
local ClassFX = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("ClassFX"))
local char = player.Character
local root = char:WaitForChild("HumanoidRootPart")
for _, g in ipairs(player.PlayerGui:GetChildren()) do
	if g:IsA("ScreenGui") then
		g.Enabled = false
	end
end
local L = root.CFrame.LookVector
local look = Vector3.new(L.X, 0, L.Z).Unit
local right = look:Cross(Vector3.yAxis)
local cam = workspace.CurrentCamera
local camFar = false
-- ภาพชัด: กลางวัน + ซ่อนต้นไม้/ของที่บังรอบตัว (เฉพาะเครื่องนี้)
local Lighting = game:GetService("Lighting")
RunService.RenderStepped:Connect(function()
	Lighting.ClockTime = 13
end)
local function hideAround()
	for _, p in ipairs(workspace:GetDescendants()) do
		if p:IsA("BasePart") and not p:IsDescendantOf(char) and not p:IsDescendantOf(cam) and (p.Position - root.Position).Magnitude < 70 then
			local m = p:FindFirstAncestorOfClass("Model")
			local fx = workspace:FindFirstChild("ClassFX")
			local sm = workspace:FindFirstChild("Summons")
			if not (m and m:GetAttribute("Health")) and not (fx and p:IsDescendantOf(fx)) and not (sm and p:IsDescendantOf(sm)) and p.Position.Y > root.Position.Y - 2 then
				p.LocalTransparencyModifier = 1
				p.Transparency = 1
			end
		end
	end
end
hideAround()
RunService.RenderStepped:Connect(function()
	cam.CameraType = Enum.CameraType.Scriptable
	local back = camFar and 30 or 16
	cam.CFrame = CFrame.lookAt(root.Position - look * back + right * (camFar and 14 or 7) + Vector3.new(0, camFar and 16 or 7, 0), root.Position + look * (camFar and 18 or 5) + Vector3.new(0, 2, 0))
end)
task.wait(1)

local function ahead(n)
	return root.Position + look * n - Vector3.new(0, 2.6, 0)
end
local function nearestMob()
	local best, bd
	for _, m in ipairs(workspace:GetDescendants()) do
		if m:IsA("Model") and m:GetAttribute("Health") and m ~= char then
			local d = (m:GetPivot().Position - root.Position).Magnitude
			if d < 40 and (not bd or d < bd) then
				best, bd = m, d
			end
		end
	end
	return best
end

-- สั้น: เล่นซ้ำทุก 0.3 วิ นาน 2.4 วิ · ถ่าย 2 เฟรม
local SHORT = {
	{ "scythe_swing", "ClassSwing", function() return { Fx = "Blood", Player = player, Position = root.Position, Dir = look, Kind = "Sword" } end },
	{ "scythe_hit", "ClassHit", function() return { Fx = "Blood", Position = root.Position + look * 6, Dir = look, Crit = true } end },
	{ "arcane_cast", "ClassSwing", function() return { Fx = "Arcane", Player = player, Position = root.Position, Dir = look, Kind = "Staff" } end },
	{ "arcane_impact", "__Impact", function() return { FxKind = "Arcane", Position = ahead(14) + Vector3.new(0, 2, 0), Radius = 9, FxScale = 0.26 } end },
	{ "verdant_impact", "__Impact", function() return { FxKind = "Verdant", Position = ahead(14) + Vector3.new(0, 2, 0), Radius = 8, FxScale = 0.22 } end },
	{ "swarmloop", "SkillSwarm", function() return { Position = root.Position, Player = player } end, 1.0 },
	{ "veil", "SkillVeil", function() return { Position = root.Position, Player = player } end },
}
for _, s in ipairs(SHORT) do
	task.spawn(function()
		local period = s[4] or 0.3
		for _ = 1, math.floor(2.4 / period) do
			local d = s[3]()
			if s[2] == "__Impact" then
				ClassFX.Impact(d)
			else
				ClassFX.Play(s[2], d)
			end
			task.wait(period)
		end
	end)
	task.wait(0.3)
	print("[SHOT] fx_" .. s[1] .. "_a")
	task.wait(1.4)
	print("[SHOT] fx_" .. s[1] .. "_b")
	task.wait(2.2)
end

-- ยาว: เล่นรอบเดียว ถ่ายตามเวลา (เลขต่อท้าย = วินาทีหลังเริ่ม โดยประมาณ)
camFar = true
task.wait(0.5)
local LONG = {
	{ "swarm", "SkillSwarm", function() return { Position = root.Position, Player = player } end, { 0, 0.4 }, 3 },
	{ "meteor", "SkillDarkMeteor", function() return { Position = ahead(22), Radius = 16, Zone = 14, Duration = 10 } end, { 0, 0.5, 0.9, 1.6, 3 }, 6 },
	{ "thorn", "SkillThornBind", function() return { Position = root.Position, Radius = 42, Player = player } end, { 0, 0.4, 1.2 }, 4 },
}
for _, s in ipairs(LONG) do
	if s[1] == "swarm" then
		-- ภาพช่วงพายุค้างคาว (~0.6 วิ): สั่งถ่ายก่อน แล้วค่อยเล่น (ตัวถ่ายช้า ~1.1 วิ)
		print("[SHOT] fx_swarm_0")
		task.wait(0.5)
	end
	ClassFX.Play(s[2], s[3]())
	if s[2] == "SkillThornBind" then
		local mob = nearestMob()
		if mob then
			ClassFX.Play("SkillThornMark", { Model = mob, Stun = 4, Poison = 6 })
		end
	end
	local t0 = os.clock()
	for i, at in ipairs(s[4]) do
		task.wait(math.max(0, at - (os.clock() - t0)))
		print("[SHOT] fx_" .. s[1] .. "_" .. i)
		task.wait(1.4) -- ตัวถ่ายต้องเสร็จก่อนสั่งเฟรมถัดไป
		t0 -= 1.4
	end
	task.wait(s[5])
end
-- ทดสอบจริงทั้งเส้น: ช่องสกิลในแถบของ -> ClassSkill.Use (ตัวเดียวกับปุ่ม Q/Z และการแตะบนมือถือ) -> เซิร์ฟเวอร์
local ClassSkill = require(player.PlayerScripts.Client:WaitForChild("ClassSkill"))
local cfails = 0
local function check(name, ok, detail)
	if not ok then
		cfails += 1
	end
	print(string.format("[AS] SKILLPROBE %s %s %s", ok and "PASS" or "FAIL", name, detail and tostring(detail) or ""))
end
local gui = player.PlayerGui:FindFirstChild("ASBackpack")
if gui then
	gui.Enabled = true
end
local bar = gui and gui:FindFirstChild("Hotbar")
local function slot(i)
	return bar and bar:FindFirstChild("SkillSlot" .. i)
end
local function waitClass(cls, n)
	local t1 = os.clock() + 40
	repeat
		task.wait(0.2)
	until (ReplicatedStorage:GetAttribute("UiTest") == cls and select(2, (player:GetAttribute("Skills") or ""):gsub("[^,]+", "")) == n) or os.clock() > t1
	hideAround()
	task.wait(0.6)
end
local function now()
	return workspace:GetServerTimeNow()
end
-- กดคีย์บอร์ด/คลิกปุ่มจริงผ่าน VirtualInputManager (ถ้าสคริปต์เทสมีสิทธิ์) ไม่งั้นคืน false
local VIM = game:GetService("VirtualInputManager")
local function pressKey(code)
	return pcall(function()
		VIM:SendKeyEvent(true, code, false, game)
		task.wait(0.05)
		VIM:SendKeyEvent(false, code, false, game)
	end)
end
local GuiService = game:GetService("GuiService")
local function clickGui(b)
	return pcall(function()
		local inset = GuiService:GetGuiInset()
		local c = b.AbsolutePosition + b.AbsoluteSize / 2 + inset
		VIM:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 0)
		task.wait(0.05)
		VIM:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 0)
	end)
end
local function readyAt(id)
	return (player:GetAttribute("SkillReady_" .. id) or 0) > now() + 5
end
local function waitUsed(id, t)
	local t1 = os.clock() + t
	repeat
		task.wait(0.1)
	until readyAt(id) or os.clock() > t1
	return readyAt(id)
end
local ICON = { DarkMeteor = "☄", ShadowVeil = "👻", Swarm = "🦇", ThornBind = "🌿" }
local function slotOk(i, id)
	local b = slot(i)
	local icon
	if b then
		for _, t in ipairs(b:GetChildren()) do
			if t:IsA("TextLabel") and t.Text == ICON[id] then
				icon = t
			end
		end
	end
	check("slot" .. i .. "-" .. id, b ~= nil and b.Visible and icon ~= nil, b and tostring(b.Visible) or "missing")
end
-- พ่อมดมืด: 2 ช่อง (Q ล่องหน / Z อุกกาบาต)
waitClass("Elementalist", 2)
slotOk(1, "ShadowVeil")
slotOk(2, "DarkMeteor")
print("[SHOT] fx_e2e_slots")
task.wait(1.4)
-- กดปุ่ม Z จริง
local okKey, keyErr = pressKey(Enum.KeyCode.Z)
local keyWorked = okKey and waitUsed("DarkMeteor", 1.5)
print("[AS] SKILLPROBE INFO real-key-Z " .. (keyWorked and "WORKED" or ("unavailable " .. tostring(keyErr))))
if not keyWorked then
	ClassSkill.Use(2)
end
print("[SHOT] fx_e2e_meteor_1")
task.wait(1.4)
print("[SHOT] fx_e2e_meteor_2")
task.wait(1.4)
local b2 = slot(2)
check("meteor-cooldown-ui", b2 and b2.Cooldown.Size.Y.Scale > 0.8, b2 and b2.Cooldown.Size.Y.Scale)
check("meteor-cooldown-120", math.abs((player:GetAttribute("SkillReady_DarkMeteor") or 0) - now() - 120) < 8, (player:GetAttribute("SkillReady_DarkMeteor") or 0) - now())
ClassSkill.Use(2) -- ติดคูลดาวน์: ต้องไม่ยิงซ้ำ
-- คลิก/แตะช่องสกิล 1 จริง
local okClick, clickErr = clickGui(slot(1))
local clickWorked = okClick and waitUsed("ShadowVeil", 1.5)
print("[AS] SKILLPROBE INFO real-click-slot1 " .. (clickWorked and "WORKED" or ("unavailable " .. tostring(clickErr))))
if not clickWorked then
	ClassSkill.Use(1)
end
task.wait(0.6)
check("veil-invisible", player:GetAttribute("Invisible") == true)
print("[SHOT] fx_e2e_veil")
task.wait(1.4)
-- แวมไพร์: 1 ช่อง (ฝูงค้างคาว)
waitClass("Vampire", 1)
slotOk(1, "Swarm")
check("vamp-slot2-hidden", not (slot(2) and slot(2).Visible))
local okQ = pressKey(Enum.KeyCode.Q)
local qWorked = okQ and waitUsed("Swarm", 1.5)
print("[AS] SKILLPROBE INFO real-key-Q " .. (qWorked and "WORKED" or "unavailable"))
if not qWorked then
	ClassSkill.Use(1)
end
task.wait(0.4)
print("[SHOT] fx_e2e_swarm_1")
task.wait(1.4)
print("[SHOT] fx_e2e_swarm_2")
task.wait(1.4)
camFar = false
task.wait(1.5)
print("[SHOT] fx_e2e_formation")
task.wait(1.4)
camFar = true
local sm = workspace:FindFirstChild("Summons")
check("bats-visible-client", sm and #sm:GetChildren() == 5, sm and #sm:GetChildren())
-- พงไพร: 1 ช่อง (เทพสตั้น)
waitClass("Sage", 1)
slotOk(1, "ThornBind")
ClassSkill.Use(1)
print("[SHOT] fx_e2e_thorn_1")
task.wait(1.4)
print("[SHOT] fx_e2e_thorn_2")
task.wait(1.4)
print(string.format("[AS] SKILLPROBE CLIENT fails=%d", cfails))
print("[AS] SKILLPROBE FXSHOW DONE")
