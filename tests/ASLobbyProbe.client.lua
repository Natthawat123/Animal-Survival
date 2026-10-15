--[[
	ASLobbyProbe — ใช้เฉพาะ build_rbxlx.py --lobbyprobe
	วัดความสูงพื้นจริง (ยิงลง Terrain) ใต้ของทุกชิ้นในล็อบบี้ เทียบกับฐานของชิ้นนั้น -> พิมพ์ชิ้นที่จม/ลอย + ถ่ายรูประดับสายตา
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASLobbyProbe") then
	return
end
local lobby = Workspace:WaitForChild("Lobby", 60)
task.wait(6)
local lp = lobby:GetPivot().Position
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { Workspace.Terrain }
local function groundAt(x, z)
	local hit = Workspace:Raycast(Vector3.new(x, lp.Y + 60, z), Vector3.new(0, -120, 0), rp)
	return hit and hit.Position.Y
end
-- ความสูงผิวพื้นจริงหลายจุด
local samples = {}
for _, p in ipairs({ { 0, 0 }, { 0, 88 }, { -60, 0 }, { 60, -60 }, { 52, 8 }, { -100, 90 } }) do
	local y = groundAt(lp.X + p[1], lp.Z + p[2])
	table.insert(samples, string.format("(%d,%d)=%s", p[1], p[2], y and string.format("%.2f", y - lp.Y) or "none"))
end
print("[PROBE] terrain surface rel lobby pivot:", table.concat(samples, " "))
do
	local c = Vector3.new(lp.X + 30, 0, lp.Z + 30)
	local region = Region3.new(Vector3.new(c.X - 2, lp.Y - 11, c.Z - 2), Vector3.new(c.X + 2, lp.Y + 13, c.Z + 2)):ExpandToGrid(4)
	local mats, occ = Workspace.Terrain:ReadVoxels(region, 4)
	local out = {}
	for y = 1, occ.Size.Y do
		table.insert(out, string.format("y%.0f:%s %.2f", region.CFrame.Position.Y - region.Size.Y / 2 + (y - 0.5) * 4 - lp.Y, mats[1][y][1].Name, occ[1][y][1]))
	end
	print("[PROBE] voxels (center rel pivot):", table.concat(out, " | "), "pivotY", lp.Y)
end

local function lowest(model)
	local y
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local cf, s = p.CFrame, p.Size
			local half = 0.5 * (math.abs(cf.XVector.Y) * s.X + math.abs(cf.YVector.Y) * s.Y + math.abs(cf.ZVector.Y) * s.Z)
			y = math.min(y or math.huge, p.Position.Y - half)
		end
	end
	return y
end
local n = 0
for _, d in ipairs(lobby:GetDescendants()) do
	if d:IsA("Model") and d.Parent and (d.Parent.Name == "Decor" or d.Parent.Name == "Vegetation" or d.Parent == lobby) then
		local low = lowest(d)
		local _, size = d:GetBoundingBox()
		local pos = d:GetPivot().Position
		local g = groundAt(pos.X, pos.Z)
		if low and g then
			local gap = low - g
			if math.abs(gap) > 0.6 then
				n += 1
				print(string.format("[PROBE] %s/%s gap=%.2f h=%.1f at %.0f,%.0f", d.Parent.Name, d.Name, gap, size.Y, pos.X - lp.X, pos.Z - lp.Z))
			end
		end
	end
end
-- ชิ้น Part ใหญ่ใน Decor (กำแพง/กระดาน) ที่ฐานไม่แตะพื้น
for _, w in ipairs(lobby:GetDescendants()) do
	if w:IsA("BasePart") and (w.Name == "Wall") then
		local g = groundAt(w.Position.X, w.Position.Z)
		print(string.format("[PROBE] wall bottom gap=%.2f", (w.Position.Y - w.Size.Y / 2) - (g or 0)))
		break
	end
end
print("[PROBE] off count", n)
local cam = Workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
for _, v in ipairs({ { "probe_well", Vector3.new(-42, 0, -16), Vector3.new(-30, 7, -2) }, { "probe_sign", Vector3.new(46, 0, 8), Vector3.new(30, 6, 14) } }) do
	cam.CFrame = CFrame.lookAt(lp + v[3], lp + v[2] + Vector3.new(0, 3, 0))
	task.wait(2)
	print("[SHOT] " .. v[1])
	task.wait(2)
end
for _, n in ipairs({ "RubyWell", "LobbySign" }) do
	local mm = lobby:FindFirstChild(n, true)
	if mm then
		local cf, sz = mm:GetBoundingBox()
		print("[PROBE]", n, "bbox center rel", tostring(cf.Position - lp), "size", tostring(sz))
	else
		print("[PROBE]", n, "missing")
	end
end
do
	local okC, Cin = pcall(require, game:GetService("Players").LocalPlayer.PlayerScripts:FindFirstChild("Cinematics", true))
	if okC and Cin.PreviewLoading then
		local ui = Cin.PreviewLoading("Animal Survival", "")
		ui.Set(0.62, "กำลังโหลดโมเดลและพื้นผิว...")
		task.wait(3)
		print("[SHOT] probe_loading")
		task.wait(2)
		ui.Root:Destroy()
	else
		print("[PROBE] no Cinematics", Cin)
	end
end
do
	local okA, ClassAvatars = pcall(require, game:GetService("Players").LocalPlayer.PlayerScripts:FindFirstChild("ClassAvatars", true))
	if okA then
		local Classes = require(game:GetService("ReplicatedStorage").Shared.Classes)
		local at = lp + Vector3.new(0, 300, 0)
		local row = {}
		for i, id in ipairs(Classes.Order) do
			local okB, m = pcall(ClassAvatars.Build, id, 15)
			if okB and m then
				m:PivotTo(CFrame.new(at + Vector3.new((i - 5.5) * 4.4, 0, 0)))
				m.Parent = workspace
				table.insert(row, m)
			else
				print("[PROBE] class fail", id, m)
			end
		end
		cam.CFrame = CFrame.lookAt(at + Vector3.new(0, 3.5, -30), at + Vector3.new(0, 3, 0))
		for _, g in ipairs(game:GetService("Players").LocalPlayer.PlayerGui:GetChildren()) do
			if g:IsA("ScreenGui") then
				g.Enabled = false
			end
		end
		cam.CFrame = CFrame.lookAt(at + Vector3.new(0, 3.2, -22), at + Vector3.new(0, 2.8, 0))
		local rigs = {}
		for i, m in ipairs(row) do
			rigs[i] = ClassAvatars.RigInfo(m)
			print("[PROBE] rig", Classes.Order[i], rigs[i] ~= nil)
		end
		-- จังหวะท่าพิเศษของแต่ละคลาส (โบกมือ/ง้างขวาน/เล็งธนู/ป้องตา/ร่ายเวท)
		for _, shotT in ipairs({ { "probe_anim_a", { 0.4, 1.1, 2.8, 2.2, 1.3, 0.3, 1.8, 2.5 } }, { "probe_anim_b", { 3.0, 2.0, 3.35, 0.5, 4.5, 1.0, 3.0, 0.2 } } }) do
			for i, id in ipairs(Classes.Order) do
				ClassAvatars.Animate(rigs[i], id, shotT[2][i])
			end
			local m1 = row[1]
			local mp = m1:FindFirstChildWhichIsA("MeshPart", true)
			local b = m1:FindFirstChild("LeftUpperArm", true)
			local okS, sk = pcall(function() return mp.HasSkinnedMesh end)
			print("[PROBE] dbg", Classes.Order[1], "skinned", okS and sk, "anchored", mp and mp.Anchored, "bone parent", b and b.Parent and b.Parent.ClassName,
				"T", b and tostring(b.Transform.Rotation:ToEulerAnglesYXZ()), "ctrl", m1:FindFirstChildWhichIsA("AnimationController", true) ~= nil)
			task.wait(1.5)
			print("[SHOT] " .. shotT[1])
			task.wait(1.5)
		end
		for _, m in ipairs(row) do
			m:Destroy()
		end
	end
end
print("[TEST] DONE probe")
