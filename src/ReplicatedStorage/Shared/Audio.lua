--[[
	Audio — รายการเสียงทั้งหมดของเกม (แก้ ID ที่นี่ที่เดียว) · ใช้โดย SoundController ฝั่งผู้เล่น
	  Music   : เพลงประกอบตามสถานการณ์ (ครอสเฟดอัตโนมัติ)
	  Ambient : เสียงบรรยากาศวนลูป (ป่ากลางวัน/กลางคืน, กองไฟ, ลม)
	  Sfx     : เสียงเอฟเฟกต์สั้นๆ

	⚠ เพลง/เสียงบรรยากาศ ต้องใส่ ID เอง (Id = "" = ยังไม่มี → ข้ามไปเงียบๆ ไม่พัง)
	   วิธีหา: Roblox Studio → Toolbox → Audio (หรือ Creator Store → Audio) → เลือกเพลงที่ผู้สร้างเป็น "Roblox"
	   (ใช้ฟรีทุกเกม) → คลิกขวา Copy Asset ID → ใส่เป็น "rbxassetid://ตัวเลข"
	   คำค้นแนะนำ: Lobby = "campfire acoustic", Day = "forest calm", Dusk = "tension rising",
	   Night = "horror ambient", BloodMoon = "horror intense", Boss = "epic battle drums",
	   Victory = "victory fanfare", Defeat = "sad piano", ForestDay = "forest birds ambience",
	   ForestNight = "night crickets", Campfire = "campfire crackling", Wind = "wind howling"

	Sfx ใช้เสียงที่ติดมากับ Roblox (rbxasset://sounds/...) อยู่แล้ว เล่นได้ทันที — อยากได้เสียงที่ดีกว่าก็เปลี่ยน ID ได้
]]

local Audio = {}

Audio.Music = {
	Lobby = { Id = "", Volume = 0.45 },
	Day = { Id = "", Volume = 0.35 },
	Dusk = { Id = "", Volume = 0.4 },
	Night = { Id = "", Volume = 0.45 },
	BloodMoon = { Id = "", Volume = 0.5 },
	Boss = { Id = "", Volume = 0.55 },
	Victory = { Id = "", Volume = 0.6, NoLoop = true },
	Defeat = { Id = "", Volume = 0.55, NoLoop = true },
}

Audio.Ambient = {
	ForestDay = { Id = "", Volume = 0.35 },
	ForestNight = { Id = "", Volume = 0.4 },
	Campfire = { Id = "", Volume = 0.5 }, -- ดังขึ้นเมื่ออยู่ใกล้กองไฟ
	Wind = { Id = "", Volume = 0.3 }, -- เขตวายุ / บนเกาะลอยฟ้า
}

local S = "rbxasset://sounds/"
Audio.Sfx = {
	UiClick = { Id = S .. "button.wav", Volume = 0.35 },
	UiOpen = { Id = S .. "clickfast.wav", Volume = 0.4, Pitch = 1.1 },
	Notify = { Id = S .. "electronicpingshort.wav", Volume = 0.25 },
	Reward = { Id = S .. "electronicpingshort.wav", Volume = 0.45, Pitch = 1.5 },
	Purchase = { Id = S .. "electronicpingshort.wav", Volume = 0.6, Pitch = 1.8 },
	Pickup = { Id = S .. "clickfast.wav", Volume = 0.35, Pitch = 1.35 },
	Craft = { Id = S .. "unsheath.wav", Volume = 0.5 },
	Build = { Id = S .. "collide.wav", Volume = 0.6, Pitch = 0.8 },
	Eat = { Id = S .. "splat.wav", Volume = 0.35, Pitch = 1.4 },
	Heal = { Id = S .. "action_get_up.mp3", Volume = 0.5, Pitch = 1.2 },
	Downed = { Id = S .. "uuhhh.mp3", Volume = 0.6, Pitch = 0.8 },
	Death = { Id = S .. "uuhhh.mp3", Volume = 0.7, Pitch = 0.6 },
	Revive = { Id = S .. "action_get_up.mp3", Volume = 0.7 },
	NightStart = { Id = S .. "HalloweenGhost.wav", Volume = 0.55, Pitch = 0.7 },
	WaveIncoming = { Id = S .. "Rocket whoosh.wav", Volume = 0.45, Pitch = 0.45 },
	Dusk = { Id = S .. "HalloweenGhost.wav", Volume = 0.35, Pitch = 0.55 },
	Dawn = { Id = S .. "electronicpingshort.wav", Volume = 0.4, Pitch = 0.7 },
	BossIntro = { Id = S .. "impact_explosion_03.mp3", Volume = 0.8, Pitch = 0.55 },
	BossFelled = { Id = S .. "impact_explosion_03.mp3", Volume = 0.8, Pitch = 0.9 },
	FireOut = { Id = S .. "impact_water.mp3", Volume = 0.7, Pitch = 0.7 },
	CampUpgrade = { Id = S .. "impact_explosion_03.mp3", Volume = 0.5, Pitch = 1.3 },
	Spirit = { Id = S .. "electronicpingshort.wav", Volume = 0.55, Pitch = 1.2 },
	GameOver = { Id = S .. "uuhhh.mp3", Volume = 0.5, Pitch = 0.45 },
}

return Audio
