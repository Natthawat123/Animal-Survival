--[[
	Limits — จำนวนสูงสุดของสิ่งก่อสร้าง + โควต้าแลกของพ่อค้า
	  นับ = ที่ถืออยู่ในกระเป๋า + ที่วางอยู่ในแมพ (พังแล้ว = คืนโควต้า วางใหม่ได้)
	  Scope "Player" = ต่อคน · "Server" = ทั้งเซิร์ฟรวมกัน (ต่อเกม)
	  ไม่อยู่ในตาราง = ไม่จำกัด (กำแพงไม้/หิน) · เครื่องมือ/อาวุธ = ชนิดละ 1 (InventoryService)
]]

local Limits = {}

Limits.Structures = {
	SpikeTrap = { Max = 8, Scope = "Player" },
	Lantern = { Max = 6, Scope = "Player" },
	Ballista = { Max = 2, Scope = "Player" },
	Bed = { Max = 2, Scope = "Server" }, -- วางแล้วข้าม 1 วัน (นับที่ใช้ไปแล้ว ไม่ใช่ที่ตั้งอยู่)
	FarmPlot = { Max = 10, Scope = "Player" },
	CookPot = { Max = 1, Scope = "Player" },
	TerraTotem = { Max = 1, Scope = "Server" },
	TideTotem = { Max = 1, Scope = "Server" },
	GaleTotem = { Max = 1, Scope = "Server" },
	EmberTotem = { Max = 1, Scope = "Server" },
	SunBeacon = { Max = 2, Scope = "Server" },
}

-- พ่อค้าเร่: แต่ละรายการแลกได้กี่ครั้งต่อคนต่อการมาเยือน 1 ครั้ง (มาตอนกลางวัน กลับตอนพลบค่ำ)
Limits.TradesPerVisit = 3

-- ชื่อ attribute ที่ server ตั้งให้ client อ่านจำนวนปัจจุบัน
function Limits.AttrName(id)
	return "Lim_" .. id
end

return Limits
