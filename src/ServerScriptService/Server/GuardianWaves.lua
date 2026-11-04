--[[
	GuardianWaves — ผู้เฝ้า 3 เวฟ ใช้ร่วมกันที่ศาลเจ้า (ช่วยลูกสัตว์) และวิหาร
	  เวฟ 1 = 3 ตัว -> เวฟ 2 = 5 ตัว -> เวฟ 3 = 7 ตัว · ปราบหมดเวฟแล้วพัก 5 วิ ค่อยมาเวฟถัดไป
	  w = ตารางสถานะของศาลเจ้า/วิหาร (ใช้ช่อง Wave, NextWaveAt, Guardians)
	  spawn(wave, count) -> รายชื่อสัตว์ที่เกิด · announce(text, kind) = บอกผู้เล่นแถวนั้น
]]

local GuardianWaves = {}

GuardianWaves.Counts = { 3, 5, 7 }
GuardianWaves.Cooldown = 5

function GuardianWaves.Alive(list)
	local n = 0
	for _, a in ipairs(list or {}) do
		if not a.Dead and a.Model and a.Model.Parent then
			n += 1
		end
	end
	return n
end

-- เริ่มเวฟ 1
function GuardianWaves.Begin(w, spawn)
	w.Wave = 1
	w.NextWaveAt = nil
	w.Guardians = spawn(1, GuardianWaves.Counts[1]) or {}
end

-- เรียกทุก tick หลังเริ่มแล้ว -> "fighting" (ยังมีผู้เฝ้า) / "cooldown" (พักก่อนเวฟถัดไป) / "done" (ครบ 3 เวฟ)
function GuardianWaves.Step(w, spawn, announce)
	if GuardianWaves.Alive(w.Guardians) > 0 then
		return "fighting"
	end
	local counts = GuardianWaves.Counts
	local total = #counts
	if (w.Wave or 0) >= total then
		return "done"
	end
	local now = os.clock()
	if not w.NextWaveAt then
		w.NextWaveAt = now + GuardianWaves.Cooldown
		announce(string.format("✔ Wave %d/%d cleared! Next wave (%d guardians) in %d seconds", w.Wave, total, counts[w.Wave + 1], GuardianWaves.Cooldown), "Good")
		return "cooldown"
	end
	if now < w.NextWaveAt then
		return "cooldown"
	end
	w.NextWaveAt = nil
	w.Wave += 1
	w.Guardians = spawn(w.Wave, counts[w.Wave]) or {}
	announce(string.format("⚔ Wave %d/%d — %d guardians!", w.Wave, total, counts[w.Wave]), "Warn")
	return "fighting"
end

return GuardianWaves
