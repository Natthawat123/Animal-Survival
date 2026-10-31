--[[
	Audio — รายการเสียงทั้งหมดของเกม (แก้ ID ที่นี่ที่เดียว) · ใช้โดย SoundController ฝั่งผู้เล่น
	  Music   : เพลงประกอบตามสถานการณ์ (ครอสเฟดอัตโนมัติ)
	  Ambient : เสียงบรรยากาศวนลูป (ป่ากลางวัน/กลางคืน, กองไฟ, ลม)
	  Sfx     : เสียงเอฟเฟกต์สั้นๆ

	ทุกเสียงมาจากคลังที่ Roblox อนุญาตให้ทุกเกมใช้ (ผู้สร้าง Roblox / ProSoundEffects / APMOfficial) · Id = "" = เงียบ ไม่พัง
	   วิธีหา: Roblox Studio → Toolbox → Audio (หรือ Creator Store → Audio) → เลือกเพลงที่ผู้สร้างเป็น "Roblox"
	   (ใช้ฟรีทุกเกม) → คลิกขวา Copy Asset ID → ใส่เป็น "rbxassetid://ตัวเลข"
	   คำค้นแนะนำ: Lobby = "campfire acoustic", Day = "forest calm", Dusk = "tension rising",
	   Night = "horror ambient", BloodMoon = "horror intense", Boss = "epic battle drums",
	   Victory = "victory fanfare", Defeat = "sad piano", ForestDay = "forest birds ambience",
	   ForestNight = "night crickets", Campfire = "campfire crackling", Wind = "wind howling"

]]

local Audio = {}
local function id(n)
	return "rbxassetid://" .. n
end

-- เพลง: APM Music (ลิขสิทธิ์ Roblox ใช้ได้ทุกเกม)
Audio.Music = {
	Lobby = { Id = id(1837699768), Volume = 0.35 }, -- Campfire (โฟล์กกีตาร์รอบกองไฟ)
	Day = { Id = id(1839412393), Volume = 0.25 }, -- Peaceful Nature
	Dusk = { Id = id(1837463124), Volume = 0.35 }, -- Tension Bed for One
	Night = { Id = id(140033496825661), Volume = 0.4 }, -- Chilling Fog (สยองเบาๆ)
	BloodMoon = { Id = id(1846862303), Volume = 0.45 }, -- Horror Race
	Boss = { Id = id(1837301451), Volume = 0.45 }, -- Epic Battle Simulator
	Victory = { Id = id(1836473422), Volume = 0.55, NoLoop = true }, -- Victory Fanfare Sting
	Defeat = { Id = id(1838635121), Volume = 0.5, NoLoop = true }, -- Sad End (Solo Piano)
}

-- บรรยากาศวนลูป: ProSoundEffects
Audio.Ambient = {
	ForestDay = { Id = id(9112749076), Volume = 0.3 }, -- นกร้องในป่า
	ForestNight = { Id = id(9112763735), Volume = 0.35 }, -- จิ้งหรีดกลางคืน
	Campfire = { Id = id(9112780193), Volume = 0.55 }, -- ไฟปะทุ (ดังขึ้นเมื่อเข้าใกล้กองไฟ)
	Wind = { Id = id(9114057104), Volume = 0.3 }, -- ลมหวีด (เขตวายุ)
}

-- เอฟเฟกต์สั้นๆ: เสียง GUI ของ Roblox + ProSoundEffects + APM
Audio.Sfx = {
	UiClick = { Id = id(17208396156), Volume = 0.35 },
	UiOpen = { Id = id(17208408337), Volume = 0.4 },
	Notify = { Id = id(17208372272), Volume = 0.3 },
	Reward = { Id = id(17208361335), Volume = 0.45 },
	Purchase = { Id = id(17208380755), Volume = 0.55 },
	Pickup = { Id = id(17208319162), Volume = 0.35 },
	Craft = { Id = id(9114753327), Volume = 0.5 }, -- ค้อนตอกไม้
	Build = { Id = id(9114753310), Volume = 0.55 },
	Eat = { Id = id(9113138343), Volume = 0.5 }, -- เคี้ยว
	Heal = { Id = id(17208327798), Volume = 0.45 },
	Downed = { Id = id(9116455473), Volume = 0.45 },
	Death = { Id = id(9116455473), Volume = 0.55, Pitch = 0.85 },
	Revive = { Id = id(17208327798), Volume = 0.6, Pitch = 1.1 },
	NightStart = { Id = id(1836376248), Volume = 0.5 }, -- ฆ้องต่ำ
	WaveIncoming = { Id = id(9120789309), Volume = 0.5 }, -- หมาป่าหอน
	Dusk = { Id = id(9114352428), Volume = 0.35 }, -- ระฆังโบสถ์บิดเบี้ยว
	Dawn = { Id = id(9119447936), Volume = 0.4 }, -- กระดิ่งลม
	BossIntro = { Id = id(9113980319), Volume = 0.8, Pitch = 0.8 }, -- คำรามสัตว์ยักษ์
	BossFelled = { Id = id(134785366676981), Volume = 0.7 },
	FireOut = { Id = id(9114439216), Volume = 0.6, Pitch = 0.6 },
	CampUpgrade = { Id = id(9114440283), Volume = 0.55 },
	Spirit = { Id = id(9116395085), Volume = 0.5 },
	GameOver = { Id = id(1836376248), Volume = 0.5, Pitch = 0.8 },
	FireLow = { Id = id(17208353912), Volume = 0.5 }, -- เชื้อเพลิงกองไฟต่ำกว่า 20%
	StalkerWarn = { Id = id(9113972051), Volume = 0.6, Pitch = 0.6 }, -- กวางกลวงกำลังจะออกล่า (เตือนก่อน 5 วินาที)
}

return Audio
