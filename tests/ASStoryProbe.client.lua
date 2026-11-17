--[[ ASStoryProbe (client) — build_rbxlx.py --storyprobe · เล่นฉากเปิดเรื่องแล้วถ่ายภาพทุกฉาก ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASStoryProbe") then
	return
end
local player = Players.LocalPlayer
task.wait(12)
local Story = require(player.PlayerScripts:WaitForChild("Client"):WaitForChild("Story"))
local done = false
Story.Play(function()
	done = true
end)
for i = 1, Story.ShotCount do
	task.wait(i == 1 and 3.2 or 6.4)
	print("[SHOT] story_" .. i)
end
task.wait(3)
print("[AS] STORY playing=" .. tostring(Story.IsPlaying()))
Story.Stop()
task.wait(0.5)
print("[AS] STORY stopped done=" .. tostring(done))
-- หน้าสอนเล่น (หน้าเดียว 8 ช่อง)
local Tutorial = require(player.PlayerScripts.Client:WaitForChild("Tutorial"))
Tutorial.Open()
task.wait(3)
print("[SHOT] tutorial")
for _, v in ipairs(player.PlayerGui:GetDescendants()) do
	if v:IsA("WorldModel") then
		local line = {}
		for _, m in ipairs(v:GetChildren()) do
			local ok, cf, size = pcall(function()
				if m:IsA("Model") then
					return m:GetBoundingBox()
				end
				return m.CFrame, m.Size
			end)
			table.insert(line, m.Name .. (ok and string.format("[%.1f,%.1f,%.1f @%.0f,%.0f,%.0f]", size.X, size.Y, size.Z, cf.X, cf.Y, cf.Z) or "?"))
		end
		print("[AS] TUTSCENE " .. v.Parent:GetFullName():sub(-30) .. " " .. table.concat(line, " "))
	end
end
task.wait(1)
print("[AS] TUTORIAL open=" .. tostring(Tutorial.IsOpen()))
print("[TEST] DONE story")
