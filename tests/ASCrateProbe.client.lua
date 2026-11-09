--[[ ASCrateProbe (client) — ถ่ายภาพกล่องจากมุมผู้เล่น + เปิดแผนที่ถ่ายเทียบหมุดกล่องกับ ▲ ตัวเรา ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
if not ReplicatedStorage:FindFirstChild("ASCrateProbe") then
	return
end
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local MapUI = require(player:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("MapUI"))
local look
RunService.RenderStepped:Connect(function()
	if look then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = look
	end
end)
ReplicatedStorage:GetAttributeChangedSignal("CrateShotSeq"):Connect(function()
	local seq = ReplicatedStorage:GetAttribute("CrateShotSeq")
	if seq == -1 then
		look = nil
		cam.CameraType = Enum.CameraType.Custom
		return
	end
	local target = ReplicatedStorage:GetAttribute("CrateShotTarget")
	local name = ReplicatedStorage:GetAttribute("CrateShotName")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (target and root) then
		return
	end
	task.wait(0.8)
	-- มุมตาผู้เล่น ยืนห่าง ~16 สตั๊ด
	local from = root.Position + ((root.Position - target) * Vector3.new(1, 0, 1)).Unit * 6 + Vector3.new(0, 4, 0)
	look = CFrame.lookAt(from, target + Vector3.new(0, 1.5, 0))
	task.wait(1.2)
	local streamed = false
	for _, c in ipairs(workspace.World:FindFirstChild("SupplyCrates") and workspace.World.SupplyCrates:GetChildren() or {}) do
		if (c:GetPivot().Position - target).Magnitude < 1 then
			streamed = true
		end
	end
	print("[AS] CRATESHOT " .. name .. " streamed=" .. tostring(streamed))
	print("[SHOT] " .. name)
	task.wait(3)
	look = nil
	cam.CameraType = Enum.CameraType.Custom
	if MapUI.Toggle then
		MapUI.Toggle()
		task.wait(1.2)
		-- คลิกบนแผนที่ตรงหมุดกล่อง (เยื้อง 5px) -> ต้องปักหมุดตรงกล่องเป๊ะ (snap)
		local mf = MapUI.MapFrame
		local size = MapUI.State:GetAttribute("MapSize") or 6144
		if seq == 1 then
			-- ระบบพิกัด: GetGuiObjectsAtPosition เทียบกับ AbsolutePosition (มี/ไม่มีแถบบน)
			local inset = game:GetService("GuiService"):GetGuiInset()
			local c = mf.AbsolutePosition + mf.AbsoluteSize * Vector2.new(0.3, 0.7)
			local function cellAt(q)
				for _, o in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(q.X, q.Y)) do
					if o.Name == "Cell" then
						local a, s = o.AbsolutePosition, o.AbsoluteSize
						return a.X <= c.X and c.X <= a.X + s.X and a.Y <= c.Y and c.Y <= a.Y + s.Y
					end
				end
				return "none"
			end
			print(string.format("[AS] MAPCAL inset=(%d,%d) mapAbs=(%d,%d) objsAt(abs)=%s objsAt(abs-inset)=%s", inset.X, inset.Y, mf.AbsolutePosition.X, mf.AbsolutePosition.Y, tostring(cellAt(c)), tostring(cellAt(c - inset))))
			for _, guess in ipairs({ c, c - inset }) do
				local q = MapUI.InputToAbs(guess)
				print(string.format("[AS] MAPCAL inputToAbs(%d,%d)->(%d,%d) errToAbs=%.1f", guess.X, guess.Y, q.X, q.Y, (q - c).Magnitude))
			end
			-- ปักที่ว่าง: ปลายหมุดต้องตรงจุดที่กด
			MapUI.MapClick(c)
			task.wait(0.5)
			print(string.format("[AS] MAPCAL pin tip err=%.1fpx", (MapUI.WpPin.AbsolutePosition - c).Magnitude))
			print("[SHOT] mapcal_freeclick")
			task.wait(2.5)
			MapUI.ClearWaypoint()
		end
		local pt = mf.AbsolutePosition + mf.AbsoluteSize * Vector2.new(target.X / size + 0.5, target.Z / size + 0.5) + Vector2.new(5, -4)
		MapUI.MapClick(pt)
		task.wait(0.4)
		local wp = MapUI.Waypoint
		print(string.format("[AS] WAYPOINT %s snapD=%.1f", name, wp and ((wp - target) * Vector3.new(1, 0, 1)).Magnitude or -1))
		print("[SHOT] " .. name .. "_map")
		task.wait(3)
		MapUI.Close()
		-- มองจากไกล 70 สตั๊ด: เสาแสง + ป้ายระยะต้องเห็นทะลุต้นไม้
		if wp then
			local away = ((root.Position - target) * Vector3.new(1, 0, 1)).Unit
			look = CFrame.lookAt(target + away * 70 + Vector3.new(0, 14, 0), target + Vector3.new(0, 6, 0))
			task.wait(1.5)
			print("[SHOT] " .. name .. "_beam")
			task.wait(3)
			look = nil
			cam.CameraType = Enum.CameraType.Custom
		end
	end
end)
