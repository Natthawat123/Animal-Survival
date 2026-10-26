--[[
	ASPropProbe (server) — ใช้เฉพาะ build_rbxlx.py --propprobe
	วัดขนาดจริงของของประดับ/ของเก็บในแมพ (พุ่มเบอร์รี่ เห็ด พุ่มไม้ ดอกไม้ ต้นไม้ หิน) แล้วพาผู้เล่นไปยืนดูพุ่มเบอร์รี่/เห็ด
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASPropProbe") then
	return
end
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
player.CharacterAdded:Wait()
local KINDS = { "BerryBush", "Mushrooms", "GlowShroom", "Bush", "Flowers", "Fern", "GiantPine", "Oak", "Boulder" }
local function collect()
	local found = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("Kind") then
			local k = d:GetAttribute("Kind")
			found[k] = found[k] or {}
			table.insert(found[k], d)
		end
	end
	return found
end
local found
local t0 = os.clock()
repeat
	task.wait(3)
	found = collect()
until (found.BerryBush and #found.BerryBush > 0) or os.clock() - t0 > 900
task.wait(3)
found = collect()
for _, k in ipairs(KINDS) do
	local list = found[k] or {}
	local hs, n = {}, 0
	for i, m in ipairs(list) do
		if i > 6 then
			break
		end
		local _, sz = m:GetBoundingBox()
		local parts, visible = 0, 0
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				parts += 1
				if p.Transparency < 0.95 then
					visible += 1
				end
			end
		end
		table.insert(hs, string.format("h%.1f w%.1f sc%.2f parts%d/%d", sz.Y, math.max(sz.X, sz.Z), m:GetScale(), visible, parts))
		n += 1
	end
	print(string.format("[PROP] %s count=%d | %s", k, #list, table.concat(hs, " ; ")))
end
-- ยืนดูของทีละชนิด
local char = player.Character
for _, k in ipairs({ "BerryBush", "Mushrooms", "Bush" }) do
	local m = found[k] and found[k][1]
	if m and char and char.PrimaryPart then
		local p = m:GetPivot().Position
		char:PivotTo(CFrame.lookAt(p + Vector3.new(0, 4, 9), p + Vector3.new(0, 1, 0)))
		task.wait(4)
		print("[SHOT] prop_" .. k)
		task.wait(2)
	else
		print("[PROP] no " .. k)
	end
end
print("[TEST] DONE probe")
