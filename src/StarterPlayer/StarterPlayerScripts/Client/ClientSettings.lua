--[[
	ClientSettings — ค่าตั้งค่าของผู้เล่น (เซฟในเซิร์ฟเวอร์ผ่าน Remotes.SaveSettings ติดตัวข้ามเครื่อง)
	  ClientSettings.Get(key) / Set(key, value) / OnChanged(fn(key, value))
	  ApplyGraphics(): คุณภาพกราฟิก ต่ำ/กลาง/สูง (เงา, เอฟเฟกต์ภาพ, อนุภาคลอย)
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local ClientSettings = {}

local isPhone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

ClientSettings.Defaults = {
	MusicVol = 0.6,
	AmbientVol = 0.7,
	SfxVol = 0.8,
	Quality = isPhone and "Low" or "High", -- Low / Medium / High
	Shake = true,
	Hints = true,
	ShowFPS = false,
	UIScale = 1, -- 0.7 - 1.3 (คูณกับสเกลอัตโนมัติตามขนาดจอ)
	TouchSize = 1, -- ขนาดปุ่มมือถือ 0.8 - 1.4
}

local values = table.clone(ClientSettings.Defaults)
local listeners = {}
local saveQueued = false

function ClientSettings.Get(key)
	return values[key]
end

function ClientSettings.OnChanged(fn)
	table.insert(listeners, fn)
end

local function fire(key, value)
	for _, fn in ipairs(listeners) do
		task.spawn(fn, key, value)
	end
end

local function queueSave()
	if saveQueued then
		return
	end
	saveQueued = true
	task.delay(2, function()
		saveQueued = false
		Remotes.Get("SaveSettings"):FireServer(values)
	end)
end

function ClientSettings.Set(key, value, noSave)
	if values[key] == value then
		return
	end
	values[key] = value
	if key == "Quality" then
		ClientSettings.ApplyGraphics()
	end
	fire(key, value)
	if not noSave then
		queueSave()
	end
end

-- โหลดจากเซฟ (profile.Settings)
function ClientSettings.Load(saved)
	if type(saved) ~= "table" then
		return
	end
	for k, def in pairs(ClientSettings.Defaults) do
		local v = saved[k]
		if v ~= nil and type(v) == type(def) and values[k] ~= v then
			values[k] = v
			fire(k, v)
		end
	end
	ClientSettings.ApplyGraphics()
end

local QUALITY = {
	Low = { Shadows = false, Post = false, Particles = 0.25, DOF = false },
	Medium = { Shadows = true, Post = true, Particles = 0.6, DOF = false },
	High = { Shadows = true, Post = true, Particles = 1, DOF = true },
}

function ClientSettings.ApplyGraphics()
	local q = QUALITY[values.Quality] or QUALITY.High
	pcall(function()
		Lighting.GlobalShadows = q.Shadows
	end)
	for _, name in ipairs({ "ASBloom", "ASSunRays" }) do
		local e = Lighting:FindFirstChild(name)
		if e then
			e.Enabled = q.Post
		end
	end
	local dof = Lighting:FindFirstChild("ASDepth")
	if dof then
		dof.Enabled = q.DOF
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Enabled = values.Quality ~= "Low"
	end
	ClientSettings.ParticleMult = q.Particles
	fire("Graphics", values.Quality)
end

return ClientSettings
