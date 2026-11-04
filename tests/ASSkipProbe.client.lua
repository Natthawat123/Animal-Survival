--[[ ASSkipProbe (client) — ถ่ายจอวันโบนัส: "+1" เด้งกลางจอ -> บินเข้าเลขวัน -> "DAY XX +N" ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASSkipProbe") then
	return
end
-- server ตั้ง SkipShot = "ชื่อ:หน่วงวินาที" -> รอแล้วสั่งถ่าย
ReplicatedStorage:GetAttributeChangedSignal("SkipShot"):Connect(function()
	local v = ReplicatedStorage:GetAttribute("SkipShot") or ""
	local name, delay = v:match("^([%w_]+):([%d%.]+)")
	if name then
		task.delay(tonumber(delay), function()
			print("[SHOT] skip_" .. name)
			-- ข้อความเลขวันจริงบนจอ (เช็กว่าไม่มีวงเล็บ / ยอด xN ถูก)
			local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("HUD")
			for _, d in ipairs(gui and gui:GetDescendants() or {}) do
				if d:IsA("TextLabel") and d.RichText and (d.Text:match("^DAY") or d.Text:match("^NIGHT")) then
					print("[AS] SKIPPROBE LABEL " .. name .. " = " .. d.Text)
				end
			end
		end)
	end
end)
