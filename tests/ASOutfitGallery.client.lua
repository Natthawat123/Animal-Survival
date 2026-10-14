--[[
	ASOutfitGallery (client) — ใช้เฉพาะ build_rbxlx.py --outfits
	วางตัวละครทีละ 5 ตัวหน้าฉากพื้นเรียบ แล้วสั่งถ่ายรูป ([SHOT] outfit_<Class>_<กลุ่ม>) — สคริปต์ python ตัดเป็นรูปละตัว
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
if not ReplicatedStorage:FindFirstChild("ASOutfitGallery") then
	return
end

local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("OutfitGallery", 120)
while folder and not folder:GetAttribute("Done") do
	task.wait(1)
end
local Candidates = require(ReplicatedStorage.Shared.OutfitCandidates)

-- ซ่อน UI ทั้งหมด
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)
local function hideGui()
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") then
			g.Enabled = false
		end
	end
end
hideGui()

-- ฉากถ่ายรูป: ผนังหลัง + พื้น สีเรียบ (python ใช้สีนี้หาขอบภาพ)
local origin = Vector3.new(0, 2600, 0)
local function part(size, cf, color)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide = true, true
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = Workspace
	return p
end
part(Vector3.new(400, 200, 2), CFrame.new(origin + Vector3.new(0, 50, 12)), Color3.fromRGB(38, 44, 56))
part(Vector3.new(400, 2, 60), CFrame.new(origin + Vector3.new(0, -1, 0)), Color3.fromRGB(58, 66, 80))
local light = part(Vector3.new(1, 1, 1), CFrame.new(origin + Vector3.new(0, 14, -14)), Color3.new(1, 1, 1))
light.Transparency = 1
local pl = Instance.new("PointLight")
pl.Range, pl.Brightness = 40, 0.35
pl.Parent = light

local SPACING = 5.4
local cam = Workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 20
cam.CFrame = CFrame.lookAt(origin + Vector3.new(0, 3.4, -33.5), origin + Vector3.new(0, 3.1, 0))
task.wait(1)

local function place(src, x)
	local m = src:Clone()
	local root = m:FindFirstChild("HumanoidRootPart")
	local hum = m:FindFirstChildOfClass("Humanoid")
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = d == root
		end
	end
	local hip = hum and hum.HipHeight or 2
	local h = root and root.Size.Y / 2 or 1
	-- ตัวละครหันหน้าทาง -Z อยู่แล้ว = หันเข้ากล้อง
	m:PivotTo(CFrame.new(origin + Vector3.new(x, hip + h, 0)))
	m.Parent = Workspace
	return m
end

for _, cls in ipairs(Candidates.Order) do
	local count = #Candidates[cls]
	for g = 1, math.ceil(count / 5) do
		local row = {}
		for k = 1, 5 do
			local n = (g - 1) * 5 + k
			local src = n <= count and folder:FindFirstChild(cls .. "_" .. n)
			if src then
				table.insert(row, place(src, (k - 3) * SPACING))
			end
		end
		hideGui()
		task.wait(2.5)
		print("[SHOT] outfit_" .. cls .. "_" .. g)
		task.wait(2)
		for _, m in ipairs(row) do
			m:Destroy()
		end
	end
end
print("[TEST] DONE gallery")
