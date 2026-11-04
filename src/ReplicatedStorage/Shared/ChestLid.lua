--[[
	ChestLid — ฝาหีบที่เปิดได้จริง (โมเดล Props/Chest1Open-3Open: MeshPart "Body" + "Lid")
	  ฝามี Attachment "Hinge" = บานพับขอบบนด้านหลัง (+Z ของชิ้น) · เปิด = หมุนรอบแกน X ของบานพับ
	  ใช้ทั้งเซิร์ฟเวอร์ (ตั้งค่าฝาเปิดค้าง) และเครื่องผู้เล่น (เล่นแอนิเมชันเปิดนุ่มๆ) -> คิดมุมเหมือนกัน
]]

local ChestLid = {}

ChestLid.OpenDeg = 105

-- ฝา + บานพับในโมเดล (ไม่มี = หีบรุ่นเก่า เปิดฝาไม่ได้)
function ChestLid.Find(model)
	if not model then
		return nil
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d.Name == "Hinge" and d:IsA("Attachment") and d.Parent:IsA("BasePart") then
			return d.Parent, d
		end
	end
	return nil
end

-- ตำแหน่งฝาเมื่อเปิดไป frac (0 = ปิด, 1 = เปิดสุด · เกิน 1 ได้ตอนเด้ง)
function ChestLid.CFrameAt(closedCF, hinge, frac)
	local h = closedCF * hinge.CFrame
	return h * CFrame.Angles(math.rad(ChestLid.OpenDeg * frac), 0, 0) * h:Inverse() * closedCF
end

-- ตำแหน่งปิดเดิมของฝา (จำไว้ครั้งแรกที่เห็น)
function ChestLid.Closed(lid)
	local cf = lid:GetAttribute("ClosedCF")
	if typeof(cf) ~= "CFrame" then
		cf = lid.CFrame
		lid:SetAttribute("ClosedCF", cf)
	end
	return cf
end

return ChestLid
