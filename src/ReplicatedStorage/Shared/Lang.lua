--[[
	Lang — แปลข้อความในเกม 10 ภาษา (ต้นฉบับ = ภาษาอังกฤษในโค้ด · คำแปลอยู่ใน Shared/LangData/<code>, สร้างโดย tools/i18n_build.py)
	  Lang.Translate(text, code) -> ข้อความแปล (ไม่มีคำแปล = คืนต้นฉบับ อังกฤษ)
	    1) ตรงทั้งข้อความ  2) แม่แบบ string.format ("Night %d" -> "คืนที่ %d") ใส่ค่าที่จับได้กลับ (ค่าที่เป็นคำก็แปลต่อ)
	    3) แยกส่วน: ไอคอนนำหน้า/ท้าย · หลายบรรทัด · คั่นด้วย " · " แล้วแปลทีละส่วน
	  Lang.Detect(localeId) -> code จากภาษาบัญชี Roblox (th-th -> "th")
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lang = {}

Lang.List = {
	{ "en", "English" }, { "th", "ไทย" }, { "es", "Español" }, { "pt", "Português" }, { "id", "Bahasa Indonesia" },
	{ "vi", "Tiếng Việt" }, { "fil", "Filipino" }, { "ja", "日本語" }, { "ko", "한국어" }, { "zh", "简体中文" },
}
local PREFIX = { en = "en", th = "th", es = "es", pt = "pt", id = "id", vi = "vi", fil = "fil", tl = "fil", ja = "ja", ko = "ko", zh = "zh" }

function Lang.Detect(locale)
	local p = string.lower(tostring(locale or "")):match("^(%a+)")
	return PREFIX[p or ""] or "en"
end

function Lang.Name(code)
	for _, l in ipairs(Lang.List) do
		if l[1] == code then
			return l[2]
		end
	end
	return code
end

---------------------------------------------------------------- แม่แบบ string.format -> pattern
local MAGIC = { ["^"] = true, ["$"] = true, ["("] = true, [")"] = true, ["%"] = true, ["."] = true, ["["] = true, ["]"] = true, ["*"] = true,
	["+"] = true, ["-"] = true, ["?"] = true }

-- "Night %d · %s" -> "^Night (%-?%d+) · (.-)$" · คืน nil ถ้าไม่มีตัวแทนค่า
local function toPattern(src)
	local out, n, i = { "^" }, 0, 1
	while i <= #src do
		local c = src:sub(i, i)
		if c == "%" then
			local spec = src:match("^%%[%-%+#0]*%d*%.?%d*[sdif]", i)
			if spec then
				local t = spec:sub(-1)
				table.insert(out, (t == "s") and "(.-)" or (t == "d" or t == "i") and "(%-?%d+)" or "(%-?[%d%.]+)")
				n += 1
				i += #spec
			elseif src:sub(i + 1, i + 1) == "%" then
				table.insert(out, "%%")
				i += 2
			else
				table.insert(out, "%%")
				i += 1
			end
		else
			table.insert(out, MAGIC[c] and ("%" .. c) or c)
			i += 1
		end
	end
	if n == 0 then
		return nil
	end
	table.insert(out, "$")
	return table.concat(out), n
end

-- ใส่ค่าที่จับได้กลับในคำแปล ตามลำดับตัวแทนค่า (%s %d %.1f ...) · "%%" = "%"
local function fill(dst, caps, translate)
	local k = 0
	return (dst:gsub("%%([%-%+#0]*%d*%.?%d*)([sdif%%])", function(_, t)
		if t == "%" then
			return "%"
		end
		k += 1
		local v = caps[k]
		if v == nil then
			return ""
		end
		if t == "s" then
			return translate(v)
		end
		return v
	end))
end

---------------------------------------------------------------- ข้อมูลภาษา
local data, templates, cache = {}, {}, {}
-- alt[code][ข้อความไม่มีไอคอน/ช่องว่างหัวท้าย] = คำแปล · low[code][ตัวพิมพ์เล็ก] = คำแปล (ใช้กับข้อความตัวใหญ่ล้วน)
local alt, low = {}, {}

-- "⚔ Weapons/Tools " -> "Weapons/Tools" + ไอคอนที่ตัดออก
local function bare(src)
	local pre = src:match("^[^%w<\"%(]*") or ""
	local key = src:sub(#pre + 1):gsub("%s+$", "")
	return key, pre
end

local function load(code)
	if data[code] ~= nil then
		return data[code]
	end
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local folder = shared and shared:FindFirstChild("LangData")
	local m = folder and folder:FindFirstChild(code)
	local ok, t = false, nil
	if m then
		ok, t = pcall(require, m)
	end
	if not (ok and type(t) == "table") then
		data[code] = false
		return false
	end
	data[code] = t
	local list = {}
	for src, dst in pairs(t) do
		if src:find("%", 1, true) then
			local pat = toPattern(src)
			if pat then
				table.insert(list, { pat, dst, #src })
			end
		end
	end
	-- แม่แบบยาวกว่า (เฉพาะเจาะจงกว่า) ลองก่อน
	table.sort(list, function(a, b)
		return a[3] > b[3]
	end)
	templates[code] = list
	cache[code] = {}
	local a, l = {}, {}
	for src, dst in pairs(t) do
		local key, pre = bare(src)
		if key ~= "" and not key:find("%", 1, true) then
			local val = dst
			if pre ~= "" and dst:sub(1, #pre) == pre then
				val = dst:sub(#pre + 1)
			end
			val = val:gsub("^%s+", ""):gsub("%s+$", "")
			if key ~= src and t[key] == nil and a[key] == nil then
				a[key] = val
			end
			local lk = string.lower(key)
			if l[lk] == nil then
				l[lk] = val
			end
		end
	end
	alt[code], low[code] = a, l
	return t
end

local translate

local function core(text, code, t)
	local r = t[text] or alt[code][text]
	if r then
		return r
	end
	if text:find("%a") and string.upper(text) == text then
		r = low[code][string.lower(text)] -- "SURVIVOR" -> คำแปลของ "Survivor"
		if r then
			return r
		end
	end
	for _, tp in ipairs(templates[code]) do
		local caps = { text:match(tp[1]) }
		if #caps > 0 then
			return fill(tp[2], caps, function(v)
				return translate(v, code)
			end)
		end
	end
	return nil
end

translate = function(text, code)
	if type(text) ~= "string" or text == "" or code == "en" then
		return text
	end
	local t = load(code)
	if not t then
		return text
	end
	local c = cache[code]
	local hit = c[text]
	if hit then
		return hit
	end
	local r = core(text, code, t)
	if not r then
		-- หลายบรรทัด: แปลทีละบรรทัด
		if text:find("\n", 1, true) then
			local parts, changed = {}, false
			for line in (text .. "\n"):gmatch("(.-)\n") do
				local tr = translate(line, code)
				changed = changed or tr ~= line
				table.insert(parts, tr)
			end
			r = changed and table.concat(parts, "\n") or nil
		end
	end
	if not r then
		-- ไอคอน/สัญลักษณ์นำหน้า-ท้าย ("🎒 Sack" -> "🎒 " + "Sack")
		local pre, mid, post = text:match("^([^%w<]*)(.-)([%s%p\128-\255]*)$") -- ต้นฉบับอังกฤษ: ไบต์ >127 ท้ายข้อความ = ไอคอน
		if mid and mid ~= "" and mid ~= text then
			local tr = core(mid, code, t)
			if tr then
				r = pre .. tr .. post
			end
		end
	end
	-- ข้อความต่อกันด้วยตัวคั่น ("A · B" · "A  -  B") แปลทีละส่วน
	for _, sep in ipairs({ "  -  ", " · " }) do
		if not r and text:find(sep, 1, true) then
			local parts, changed = {}, false
			local esc = sep:gsub("%-", "%%-")
			for part in (text .. sep):gmatch("(.-)" .. esc) do
				local tr = translate(part, code)
				changed = changed or tr ~= part
				table.insert(parts, tr)
			end
			r = changed and table.concat(parts, sep) or nil
		end
	end
	if not r then
		-- ตัวเลข/เลเวลต่อท้าย: "Stone 0/10" · "Upgrade Campfire  Lv.1 → 2" · "Bandage x2"
		local head, tail = text:match("^(.-%S)(%s+Lv%.?%s*%d.*)$")
		if not head then
			head, tail = text:match("^(.-%S)(%s*[%(%[]?[x%+%-]?%d[%d%.,/%%:]*[%)%]]?)$")
		end
		if head and #head < #text then
			local tr = translate(head, code)
			if tr ~= head then
				r = tr .. tail
			end
		end
	end
	if not r then
		-- ตัวเลขนำหน้า: "+3 Wood"
		local head, rest = text:match("^([%+%-]?%d[%d,%.]*%s+)(%S.*)$")
		if head then
			local tr = translate(rest, code)
			if tr ~= rest then
				r = head .. tr
			end
		end
	end
	if not r then
		-- "Get: Hunter's Bow" -> แปลหัวข้อ ("Get: ") + ค่าหลัง ":"
		local head, rest = text:match("^([^:]-:%s*)(%S.*)$")
		if head and #head < 40 and head:find("%a") then
			local th = t[head] or alt[code][(head:gsub("%s+$", ""))] or translate((head:gsub(":%s*$", "")), code) .. ": "
			local tr = translate(rest, code)
			if type(th) == "string" and (th ~= head or tr ~= rest) then
				if th:sub(-1) ~= " " and head:sub(-1) == " " then
					th = th .. " "
				end
				r = th .. tr
			end
		end
	end
	r = r or text
	if #text < 400 then
		local n = (c.__n or 0) + 1
		if n > 4000 then
			c = {}
			cache[code] = c
			n = 1
		end
		c.__n = n
		c[text] = r
	end
	return r
end

function Lang.Translate(text, code)
	return translate(text, code)
end

function Lang.Has(code)
	return load(code) ~= false
end

return Lang
