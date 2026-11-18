--[[
	SiteSigns — ข้อความป้ายหน้าประตู ศาลเจ้าลูกสัตว์ / วิหารโบราณ (PropBuilder.BuildSiteSign วาดป้าย)
	  ดึงตัวเลขจริงจาก Config / Classes -> แก้ค่าเกมแล้วป้ายเปลี่ยนตาม
	  ข้อความอังกฤษ · Localizer แปลป้ายในโลก (SurfaceGui) ให้เอง
]]

local Config = require(script.Parent.Config)
local Classes = require(script.Parent.Classes)
local Items = require(script.Parent.Items)
local Shop = require(script.Parent.Shop)

local SiteSigns = {}

local NAME = { Earth = "Earth", Water = "Water", Air = "Frost", Fire = "Fire" }
local ESSENCE = { Earth = "TerraCore", Water = "TidePearl", Air = "GaleFeather", Fire = "EmberShard" }
-- ต้องตรงกับ SpiritService.BUFF_TEXT / SanctumService.AURA_TEXT
SiteSigns.PupBuff = {
	Earth = "Buildings slowly repair themselves",
	Water = "The campfire burns fuel 25% slower",
	Air = "Everyone runs 10% faster",
	Fire = "The campfire burns enemies that enter the safe zone",
}
SiteSigns.Aura = {
	Earth = "Earth Aura: Max HP +15%", Water = "Water Aura: Hunger 15% slower",
	Air = "Frost Aura: Stamina drains 15% slower", Fire = "Fire Aura: Damage +15%",
}

local function name(id)
	return Items.DisplayName and Items.DisplayName(id) or id
end

-- คืน { Emblem, Title, Need = { Text, Ok }, Info, Rewards = { { Icon, Text } } }
function SiteSigns.Get(kind, el)
	if kind == "Shrine" then
		return {
			Emblem = "⛩", Title = string.format("%s Shrine", NAME[el]),
			Need = { Text = string.format("Campfire Lv.%d required", Config.SpiritFireLevel[el] or 1), Ok = false },
			Info = "Beat the guardian waves and free the Spirit Pup",
			Rewards = {
				{ "🐾", SiteSigns.PupBuff[el] },
				{ "📅", string.format("Days count +%d faster", Config.SpiritBonusDays[el] or 1) },
				{ "♦️", string.format("+%d Ruby each", Classes.SpiritReward or 5) },
				{ "⏳", "+1 min of daylight on first entry" },
			},
		}
	elseif kind == "Sanctum" then
		return {
			Emblem = "🏛", Title = string.format("%s Sanctum", NAME[el]),
			Need = { Text = "No campfire level needed", Ok = true },
			Info = "Wake the rune pillars in order, then beat the guardians",
			Rewards = {
				{ "✨", SiteSigns.Aura[el] .. " · whole run" },
				{ "🎁", string.format("Sacred chest: legendary weapon + %s x4-6", name(ESSENCE[el])) },
				{ "♦️", "+5-8 Ruby each" },
				{ "⏳", "+1 min of daylight on first entry" },
			},
		}
	elseif kind == "Krathong" then
		local max = Config.KrathongMax or 20
		return {
			Emblem = "🌸", Title = "Loy Krathong Festival",
			Need = { Text = "Tonight only · once per run", Ok = true },
			Info = "Villagers float krathongs down the river — collect them!",
			Rewards = {
				{ "🌸", string.format("Collect up to %d krathongs each", max) },
				{ "🏮", "Trade krathongs for gifts at the festival shop" },
				{ "🎁", string.format("All %d: +%d bonus krathongs", max, Shop.FestivalWishBonus) },
				{ "🎆", "Lanterns, fireworks and river lights" },
			},
		}
	end
	return nil
end

return SiteSigns
