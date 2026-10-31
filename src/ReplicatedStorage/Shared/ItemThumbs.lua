--[[
	ItemThumbs — เลขโมเดลต้นฉบับใน Creator Store ของแต่ละไอเทม (สร้างจาก referent ใน assets/rbxm/Items + Weapons)
	ใช้ทำรูปไอคอน rbxthumb:// (เช่น ไอคอนช่องเครื่องมือของ Roblox)
]]

local ItemThumbs = {
	Bandage = 12857564167,
	BeastHeart = 108474997,
	TerraHeart = 108474997,
	TideHeart = 108474997,
	FrostHeart = 108474997,
	EmberHeart = 108474997,
	Bed = 13450150185,
	Berries = 107227111280509,
	BerryJuice = 5382162941,
	BerryPie = 59913763,
	Bow = 222117411,
	Coal = 277453200,
	CookPot = 8695621949,
	CookedMeat = 342730254,
	EmberBlade = 244648837,
	EmberStaff = 52093942,
	EmberShard = 80654769388421,
	EmberTotem = 4638108969,
	FarmPlot = 93660859808046,
	Fiber = 11814511082,
	FourfoldBlade = 8300795842,
	GaleBow = 55918184,
	GaleFeather = 11667163117,
	GaleTotem = 80994968560699,
	GiantSack = 77231308653953,
	GoodSack = 8846237519,
	HerbSalve = 5536963715,
	Iron = 17134887215,
	IronAxe = 114164136130143,
	Lantern = 87570116399197,
	LogWall = 119453325119661,
	Medkit = 6712879750,
	OldAxe = 122042211239954,
	OldSack = 18523642844,
	Pelt = 9482961833,
	Pickaxe = 101775581284008,
	RawMeat = 17251885494,
	Spear = 4239209497,
	Stew = 8807056485,
	Stone = 118694975427907,
	StoneAxe = 88566817567680,
	StoneWall = 8988297469,
	SunBeacon = 9216601077,
	TerraCore = 7820798627,
	TerraHammer = 13106821277,
	TerraTotem = 4124162583,
	TidalTrident = 129333375158140,
	TidePearl = 76238014304806,
	Torch = 118933541,
	WoodArmor = 122923529802096,
	IronArmor = 72463955485725,
	GoldArmor = 73779488166589,
	Wood = 248338900,
}

function ItemThumbs.Url(id)
	local aid = ItemThumbs[id]
	return aid and string.format("rbxthumb://type=Asset&id=%d&w=150&h=150", aid) or ""
end

return ItemThumbs
