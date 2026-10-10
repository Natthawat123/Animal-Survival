--[[
	SoundController — ระบบเสียงทั้งเกม (ฝั่งผู้เล่น)
	  เพลง     : เปลี่ยนตามสถานการณ์อัตโนมัติ (ล็อบบี้ / กลางวัน / พลบค่ำ / กลางคืน / พระจันทร์เลือด / บอส / ชนะ / แพ้) + ครอสเฟด
	  บรรยากาศ : ป่ากลางวัน-กลางคืน, กองไฟ (ดังขึ้นเมื่อเข้าใกล้), ลม (เขตวายุ)
	  เอฟเฟกต์ : SoundController.Play("Reward") — รายชื่อใน Shared/Audio.lua
	  ระดับเสียงแยก 3 กลุ่ม (เพลง/บรรยากาศ/เอฟเฟกต์) ปรับในหน้าตั้งค่า
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Audio = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Audio"))
local ClientSettings = require(script.Parent.ClientSettings)

local SoundController = {}
local player = Players.LocalPlayer
local groups = {}
local music = {} -- [name] = Sound
local ambient = {} -- [name] = Sound
local currentMusic
local oneShot -- เพลงชนะ/แพ้ (เล่นทับเพลงปกติชั่วคราว)

local function group(name, vol)
	local g = SoundService:FindFirstChild(name)
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
	end
	g.Volume = vol
	return g
end

local function makeLoop(def, g, name)
	if not def or def.Id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = def.Id
	s.Looped = not def.NoLoop
	s.Volume = 0
	s.SoundGroup = g
	s:SetAttribute("Base", def.Volume or 0.5)
	s.Parent = SoundService
	return s
end

local function fadeTo(s, vol, time)
	if not s then
		return
	end
	if vol > 0 and not s.IsPlaying then
		s:Play()
	end
	local t = TweenService:Create(s, TweenInfo.new(time or 2), { Volume = vol })
	t:Play()
	if vol <= 0 then
		t.Completed:Once(function()
			if s.Volume <= 0.001 then
				s:Pause()
			end
		end)
	end
end

-- เอฟเฟกต์สั้นๆ (2D)
function SoundController.Play(name, pitch)
	local def = Audio.Sfx[name]
	if not def or def.Id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = def.Volume or 0.5
	s.PlaybackSpeed = (def.Pitch or 1) * (pitch or 1)
	s.SoundGroup = groups.Sfx
	s.Parent = SoundService
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(10, function()
		if s.Parent then
			s:Destroy()
		end
	end)
	s:Play()
end

-- เพลงชนะ/แพ้: หรี่เพลงปกติ เล่นจบแล้วคืน
function SoundController.Sting(name)
	local s = music[name]
	if not s then
		return
	end
	oneShot = s
	s.TimePosition = 0
	fadeTo(currentMusic and music[currentMusic], 0, 0.8)
	s.Volume = s:GetAttribute("Base")
	s:Play()
	task.delay(math.max(s.TimeLength, 8), function()
		if oneShot == s then
			oneShot = nil
			fadeTo(s, 0, 2)
			currentMusic = nil -- ให้ลูปเลือกเพลงใหม่
		end
	end)
end

local function wantedMusic(state)
	if not player:GetAttribute("InRun") then
		return "Lobby"
	end
	local boss = state:GetAttribute("BossId")
	if boss and boss ~= "" then
		return "Boss"
	end
	local phase = state:GetAttribute("Phase")
	if phase == "Night" then
		return state:GetAttribute("BloodMoon") and "BloodMoon" or "Night"
	elseif phase == "Dusk" then
		return "Dusk"
	elseif phase == "Ended" then
		return nil
	end
	return "Day"
end

local function applyVolumes()
	groups.Music.Volume = ClientSettings.Get("MusicVol")
	groups.Ambient.Volume = ClientSettings.Get("AmbientVol")
	groups.Sfx.Volume = ClientSettings.Get("SfxVol")
end

function SoundController.Init(state)
	groups.Music = group("ASMusic", 0.6)
	groups.Ambient = group("ASAmbient", 0.7)
	groups.Sfx = group("ASSfx", 0.8)
	applyVolumes()
	ClientSettings.OnChanged(function(key)
		if key == "MusicVol" or key == "AmbientVol" or key == "SfxVol" then
			applyVolumes()
		end
	end)
	-- เสียงอื่นๆ ทั้งเกม (ตี/เดิน/กองไฟ/เอฟเฟกต์ในโลก/ของ Roblox) ที่ยังไม่มีกลุ่ม -> เข้ากลุ่มให้แถบปรับเสียงคุมได้จริง
	local function adopt(d)
		if d:IsA("Sound") and d.SoundGroup == nil then
			d.SoundGroup = d.Looped and groups.Ambient or groups.Sfx
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		adopt(d)
	end
	workspace.DescendantAdded:Connect(adopt)
	SoundService.DescendantAdded:Connect(adopt)
	for name, def in pairs(Audio.Music) do
		music[name] = makeLoop(def, groups.Music, "Music_" .. name)
	end
	for name, def in pairs(Audio.Ambient) do
		ambient[name] = makeLoop(def, groups.Ambient, "Amb_" .. name)
	end

	-- เลือกเพลง/บรรยากาศทุกครึ่งวินาที
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		if not oneShot then
			local want = wantedMusic(state)
			if want ~= currentMusic then
				if currentMusic then
					fadeTo(music[currentMusic], 0, 2.5)
				end
				currentMusic = want
				local s = want and music[want]
				if s then
					fadeTo(s, s:GetAttribute("Base"), 2.5)
				end
			end
		end
		-- บรรยากาศ
		local inRun = player:GetAttribute("InRun")
		local phase = state:GetAttribute("Phase")
		local night = phase == "Night" or phase == "Dusk"
		local char = player.Character
		local pos = char and char:GetPivot().Position
		local camp = state:GetAttribute("CampPos")
		local campK = 0
		if inRun and pos and camp then
			campK = math.clamp(1 - ((pos - camp) * Vector3.new(1, 0, 1)).Magnitude / 90, 0, 1)
		end
		local function set(name, k)
			local s = ambient[name]
			if s then
				local target = s:GetAttribute("Base") * k
				if math.abs(s.Volume - target) > 0.02 then
					fadeTo(s, target, 1.2)
				end
			end
		end
		set("ForestDay", inRun and not night and 1 or 0)
		set("ForestNight", (inRun and night or not inRun) and 1 or 0)
		set("Campfire", campK)
		local biome = SoundController.Biome and SoundController.Biome() or ""
		set("Wind", inRun and biome == "Air" and 1 or 0)
	end)
end

-- เสียงตามเหตุการณ์ (เรียกจาก Main ตอนได้ Cinematic)
local EVENT_SFX = {
	NightStart = "NightStart", Dusk = "Dusk", Dawn = "Dawn", WaveIncoming = "WaveIncoming", BossIntro = "BossIntro",
	BossFelled = "BossFelled", Downed = "Downed", Revived = "Revive", Died = "Death", FireOut = "FireOut",
	CampUpgrade = "CampUpgrade", SpiritFreed = "Spirit", SpiritRescued = "Spirit", Purchased = "Purchase", GameOver = "GameOver",
}
function SoundController.OnCinematic(kind, d)
	local sfx = EVENT_SFX[kind]
	if sfx then
		SoundController.Play(sfx)
	end
	if kind == "GameOver" then
		SoundController.Sting("Defeat")
	elseif kind == "Ending" or kind == "BossFelled" then
		SoundController.Sting("Victory")
	end
	local _ = d
end

return SoundController
