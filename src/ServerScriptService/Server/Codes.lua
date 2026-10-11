--[[
	Codes — โค้ดแลกรางวัล (อยู่ฝั่ง server เท่านั้น ผู้เล่นเปิดดูไฟล์นี้ไม่ได้)
	  คีย์ = ตัวโค้ด (ตัวพิมพ์ใหญ่ ไม่มีเว้นวรรค) · ผู้เล่นพิมพ์เล็ก/ใหญ่ก็ได้
	  Ruby = จำนวน Ruby · Title / Color = ฉายา/สีฉายา (id จาก Shared/Quests.lua)
	  Expires = os.time() ที่หมดอายุ (ไม่ใส่ = ไม่หมดอายุ) · Starts = เริ่มใช้ได้เมื่อ (ไม่ใส่ = ใช้ได้เลย)
	  ใช้ได้คนละครั้งต่อโค้ด (เก็บในเซฟ CodesUsed)
]]

return {
	WELCOME = { Ruby = 50 },
	ANIMAL99 = { Ruby = 30 },
	FOURELEMENTS = { Ruby = 25, Title = "Pioneer" },
	CAMPFIRE = { Ruby = 20, Expires = 1798761600 }, -- หมดอายุ 1 ม.ค. 2027 00:00 UTC
}
