--[[
	ClassOutfits — ชุดตัวละครประจำคลาส (ไอเทมจริงจากแคตตาล็อก Roblox, เสื้อผ้าแบบ Layered 3D)
	LobbyService สร้างเป็นโมเดล R15 ผ่าน HumanoidDescription -> ReplicatedStorage.ClassModels/<Class>
	  Accessories: ช่องของ HumanoidDescription (HatAccessory / HairAccessory / BackAccessory / FaceAccessory / WaistAccessory)
	  Layered: เสื้อผ้า 3D { AssetId, AccessoryType } เรียงจากชั้นในไปชั้นนอก
	  Head: หัวแบบใหม่ (Dynamic Head มีหน้าตาในตัว) · ตัว = ชุด "Man" ของ Roblox (BODY ใช้ทุกคลาส)
]]

local C = Color3.fromRGB

local HAIR_BLACK = 14266995104
local HAIR_BROWN = 17069924171
local JEANS_DARK = 82935835255895
local JEANS_BLACK = 107103479373772 -- คาร์โก้สีเข้มเรียบ
local TEE_WHITE = 131253627662264
local LONG_BLACK = 13896847155 -- เสื้อแขนยาวดำ (ใส่ใต้ผ้าคลุมที่เปิดหน้า)

-- ตัว "Man" ของ Roblox (bundle 238: สัดส่วนคน แขนแนบลำตัวตามธรรมชาติ) + อารมณ์หน้าเคลื่อนไหว
local BODY = {
	Torso = 86500008, RightArm = 86500036, LeftArm = 86500054, LeftLeg = 86500064, RightLeg = 86500078, MoodAnimation = 10725833199,
}

local Outfits = {
	Survivor = {
		Head = 91384666833513, -- หน้า: ยิ้มมุมปากมั่นใจ
		Skin = C(201, 158, 125),
		Accessories = { HairAccessory = { HAIR_BLACK }, BackAccessory = { 116254001917065 } }, -- เป้เดินป่า
		Layered = { { TEE_WHITE, "TShirt" }, { 7192547628, "Jacket" }, { JEANS_DARK, "Pants" } }, -- เสื้อยืดขาว + แจ็กเก็ตหนังน้ำตาล
	},
	Forager = {
		Head = 92647797373152, -- หน้า: ยิ้มหวาน
		Skin = C(184, 137, 103),
		Accessories = { HairAccessory = { HAIR_BROWN }, HatAccessory = { 18358376553 }, BackAccessory = { 88005410322847 } }, -- หมวกฟาง + ตะกร้า
		Layered = { { 16830278983, "Jacket" }, { 100508742541378, "Pants" } },
	},
	Lumberjack = {
		Head = 99853004279773, -- หน้า: หน้าบึ้ง
		Skin = C(194, 146, 113),
		Accessories = { HairAccessory = { HAIR_BLACK }, HatAccessory = { 98861485098664 }, FaceAccessory = { 89370353397971 }, BackAccessory = { 130656996132014 } },
		Layered = { { 11088670701, "Shirt" }, { JEANS_DARK, "Pants" } }, -- เชิ้ตลายสก็อตแดง + ขวานบนหลัง
	},
	Medic = {
		Head = 70898154007602, -- หน้า: ยิ้มใจดี
		Skin = C(206, 172, 144),
		Accessories = { HairAccessory = { HAIR_BLACK }, HatAccessory = { 119297101208751 }, NeckAccessory = { 30844997 } }, -- หมวกผ่าตัด + หูฟังแพทย์
		Layered = { { 13897136871, "Shirt" }, { 13897131421, "Pants" } }, -- ชุดสครับฟ้าเข้าชุด
	},

	Hunter = {
		Head = 128816512108604, -- หน้า: หน้านิ่งเท่
		Skin = C(168, 123, 89),
		Accessories = { HatAccessory = { 109499117957024 }, BackAccessory = { 7245475159 } }, -- ฮู้ดเขียว + ซองธนู
		Layered = { { 13325479500, "Jacket" }, { 127861471979970, "Pants" } },
	},
	Builder = {
		Head = 93234226896210, -- หน้า: ยิ้มขยิบตา
		Skin = C(194, 146, 113),
		Accessories = { HairAccessory = { HAIR_BLACK }, HatAccessory = { 16713265880 }, WaistAccessory = { 11698644534 } }, -- หมวกนิรภัย + เข็มขัดเครื่องมือ
		Layered = { { TEE_WHITE, "TShirt" }, { 18863614932, "Jacket" }, { JEANS_DARK, "Pants" } },
	},
	Scout = {
		Head = 131948713746239, -- หน้า: ยิ้มเท่
		Skin = C(184, 137, 103),
		Accessories = { HairAccessory = { HAIR_BLACK }, HatAccessory = { 17352607202 }, BackAccessory = { 116254001917065 } }, -- หมวกเรนเจอร์
		Layered = { { 106908836102750, "Shirt" }, { 18522156233, "Pants" } },
	},
	Firekeeper = {
		Head = 73010531111202, -- หน้า: ตาแดง
		Skin = C(168, 123, 89),
		Accessories = { HatAccessory = { 7491687596 } }, -- ฮู้ดดำ
		Layered = { { LONG_BLACK, "Shirt" }, { 10552660662, "Jacket" }, { JEANS_BLACK, "Pants" } },
	},
	Elementalist = {
		Head = 112272507010149, -- หน้า: ตาเรืองแสงฟ้า
		Skin = C(206, 172, 144),
		Accessories = { HairAccessory = { HAIR_BROWN }, HatAccessory = { 18860962628 } }, -- หมวกพ่อมดลายดาว
		Layered = { { LONG_BLACK, "Shirt" }, { 133414701520389, "Jacket" }, { JEANS_BLACK, "Pants" } },
	},
	Beastwarden = {
		Head = 91384666833513, -- หน้า: อยู่ใต้หัวหมาป่า
		Skin = C(151, 110, 79),
		Accessories = { HatAccessory = { 98011373061597 }, BackAccessory = { 74068435514595 } }, -- หัวหมาป่า + ผ้าคลุมขนอสูร
		Layered = { { LONG_BLACK, "Shirt" }, { 104546427844508, "Jacket" }, { JEANS_BLACK, "Pants" } },
	},
}

for _, o in pairs(Outfits) do
	o.Body = BODY
end

return Outfits
