--[[
	Analytics — ส่งสถิติเข้า Roblox AnalyticsService (Creator Dashboard → Analytics)
	  ทุกคำสั่งห่อด้วย pcall: ใน Studio / API ปิด / ผู้เล่นออกไปแล้ว = เงียบ ไม่พังเกม
	  Analytics.Custom(player, "BossDefeated", 25, { "Terragon" })        -- ค่าตัวเลข + ช่องข้อความ (สูงสุด 3 ช่อง)
	  Analytics.NightReached(player, night)                               -- ความคืบหน้า (Progression) ตามคืนสำคัญ
	  Analytics.NightFailed(player, night)
]]

local Players = game:GetService("Players")

local Analytics = {}

local service
do
	local ok, s = pcall(function()
		return game:GetService("AnalyticsService")
	end)
	service = ok and s or nil
end

local FIELD_KEYS = { "CustomField01", "CustomField02", "CustomField03" }

local function fields(list)
	if not list then
		return nil
	end
	local out = {}
	local any = false
	for i, v in ipairs(list) do
		local keyName = FIELD_KEYS[i]
		if keyName and v ~= nil then
			local ok, key = pcall(function()
				return Enum.AnalyticsCustomFieldKeys[keyName].Name
			end)
			out[ok and key or keyName] = tostring(v)
			any = true
		end
	end
	return any and out or nil
end

local function valid(player)
	return service ~= nil and typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players and player.UserId > 0
end

-- เหตุการณ์ทั่วไป (ค่า = ตัวเลข, extra = รายการข้อความ 1-3 ช่อง)
function Analytics.Custom(player, eventName, value, extra)
	if not valid(player) then
		return
	end
	pcall(function()
		service:LogCustomEvent(player, eventName, value or 1, fields(extra))
	end)
end

-- คืนสำคัญ (บันทึกเป็น Progression: เห็นกราฟคนหลุดกลางทางใน Funnel)
Analytics.Milestones = { [1] = true, [2] = true, [3] = true, [5] = true, [7] = true }
function Analytics.IsMilestone(night)
	return Analytics.Milestones[night] == true or night % 5 == 0
end

function Analytics.NightReached(player, night)
	if not valid(player) or not Analytics.IsMilestone(night) then
		return
	end
	pcall(function()
		service:LogProgressionCompleteEvent(player, "Nights", night, "Night " .. night)
	end)
end

function Analytics.NightFailed(player, night)
	if not valid(player) then
		return
	end
	pcall(function()
		service:LogProgressionFailEvent(player, "Nights", math.max(1, night), "Night " .. night)
	end)
end

return Analytics
