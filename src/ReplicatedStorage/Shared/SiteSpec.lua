--[[
	SiteSpec — ขนาด/ตำแหน่งอาคารหลักของจุดสำคัญในแมพ (ศาลเจ้า/ฐานบอส/วิหาร/ซากปรักหักพัง)
	ใช้ร่วมกันทั้ง MapLayout (กันพื้นที่) · MapGenerator (ปรับพื้นเรียบ) · PropBuilder/SanctumService (วางโมเดล)
	ผังทุกจุด: ลานกิจกรรมอยู่ฝั่งแคมป์ (-Z ของ Frame) · อาคารใหญ่ตั้งถัดไปฝั่งตรงข้ามแคมป์ (+Z) หน้าหันเข้าลาน เดินเข้าไปข้างในได้
]]

local SiteSpec = {}

--   Gap = ระยะจากกลางลานถึงขอบอาคาร · Width = ความกว้างอาคาร · Center = อาคารล้อมลานไว้ตรงกลาง (เช่นโคลอสเซียม)
--   ฐานบอส = อาคารใหญ่ล้อมลานสู้ (บอสเกิด/สู้ข้างในรัง) · ศาลเจ้า/วิหาร/ซาก = อาคารใหญ่หลังลาน เดินเข้าได้
local SPEC = {
	-- ศาลเจ้า/วิหาร = ประตูมิติบนพื้น (ห้องจริงลอยบนฟ้า PropBuilder.BuildRealm) · จุดซ่อนสมบัติ = กองของเล็กๆ
	Shrine = { Center = true, Width = 120 }, -- เผื่อระยะห่างจากรังบอส (บอสเคยว่ายมาถึงหน้าประตู) + ลานโล่งรอบซุ้ม
	Lair = { Center = true, Width = 300 }, -- เยติ: ลานเปิดบนหิมะ (เอาพระราชวังน้ำแข็งออก — บอสตกพื้น/ฐานลอย)
	Sanctum = { Center = true, Width = 120 },
	Ruins = { Center = true, Width = 60 }, -- ซากวิหาร Store กว้าง ~34-54 (ลานเรียบรัศมี 38)
}

function SiteSpec.Get(kind, el)
	local s = SPEC[kind]
	if not s then
		return nil
	end
	local o = el and s[el] or {}
	local center = o.Center or (o.Center == nil and s.Center) or false
	return { Gap = (not center) and (o.Gap or s.Gap) or nil, Width = o.Width or s.Width, Center = center == true }
end

-- ระยะไกลสุดจากกลางลานถึงขอบอาคาร (ใช้กันจุดสำคัญวางทับกัน)
function SiteSpec.Reach(kind, el)
	local s = SiteSpec.Get(kind, el)
	if not s then
		return 30
	end
	return s.Center and s.Width / 2 or (s.Gap + s.Width)
end

-- ทิศออกจากแคมป์ (แนวราบ)
function SiteSpec.Away(pos)
	local d = Vector3.new(pos.X, 0, pos.Z)
	return d.Magnitude > 1 and d.Unit or Vector3.zAxis
end

-- กรอบของจุด: -Z หันเข้าแคมป์ · +Z = ฝั่งอาคาร
function SiteSpec.Frame(pos)
	return CFrame.lookAt(pos, pos - SiteSpec.Away(pos))
end

-- ลานใต้อาคาร (กลาง, รัศมี) — อาคารที่ล้อมลานคืนค่าเป็นกลางลานเอง
function SiteSpec.Pad(kind, el, pos)
	local s = SiteSpec.Get(kind, el)
	if not s then
		return nil
	end
	if s.Center then
		return pos, s.Width / 2 + 8
	end
	return pos + SiteSpec.Away(pos) * (s.Gap + s.Width / 2), s.Width / 2 + 8
end

return SiteSpec
