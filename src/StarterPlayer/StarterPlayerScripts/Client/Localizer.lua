--[[
	Localizer — แปลทุกข้อความบนจอเป็นภาษาของผู้เล่น (Shared/Lang) โดยไม่ต้องแก้โค้ดหน้าจออื่น
	  ภาษา: ตั้งค่า "Language" (ClientSettings) = "Auto" (ตามภาษาบัญชี Roblox) หรือรหัสภาษา (en/th/es/...)
	  คอยดูข้อความทุกอันใน PlayerGui + ป้ายในโลก (BillboardGui/SurfaceGui) + ปุ่มกด E (ProximityPrompt)
	    โค้ดตั้งข้อความอังกฤษเมื่อไร -> เปลี่ยนเป็นคำแปลทันที (จำต้นฉบับไว้ เปลี่ยนภาษาแล้วแปลใหม่ได้)
	  ปิดระบบแปลอัตโนมัติของ Roblox (AutoLocalize) ของข้อความที่แปลเองแล้ว ไม่ให้แปลซ้อน
]]

local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Lang = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Lang"))
local ClientSettings = require(script.Parent:WaitForChild("ClientSettings"))

local Localizer = {}
local player = Players.LocalPlayer
local code = "en"
local listeners = {}

-- ไฟล์เทส (build --lang=xx): จดข้อความที่ยังไม่มีคำแปล แล้วพิมพ์ "[AS] I18N MISS" ลง log
local misses = ReplicatedStorage:FindFirstChild("ASForceLang") and {} or nil
local missList = {}

-- [inst] = { [prop] = { Src = ต้นฉบับ, Mine = ข้อความที่เราตั้งเอง } }
local tracked = setmetatable({}, { __mode = "k" })

local PROPS = {
	TextLabel = { "Text" }, TextButton = { "Text" }, TextBox = { "PlaceholderText" },
	ProximityPrompt = { "ActionText", "ObjectText" },
}

local function apply(inst, prop)
	local rec = tracked[inst]
	if not rec then
		return
	end
	local entry = rec[prop]
	local cur = inst[prop]
	if entry and entry.Mine ~= nil and cur == entry.Mine then
		return -- เราเพิ่งตั้งเอง
	end
	entry = entry or {}
	rec[prop] = entry
	entry.Src = cur
	local tr = Lang.Translate(cur, code)
	entry.Mine = tr
	if misses and tr == cur and code ~= "en" and type(cur) == "string" and cur:find("%a%a") and not misses[cur] then
		misses[cur] = true
		table.insert(missList, cur)
	end
	if tr ~= cur then
		inst[prop] = tr
	end
end

local function watch(inst)
	local props = PROPS[inst.ClassName]
	if not props or tracked[inst] or inst:GetAttribute("NoTranslate") then
		return -- NoTranslate = ห้ามแปล (เช่น ชื่อภาษาในหน้าตั้งค่า / ชื่อผู้เล่น)
	end
	tracked[inst] = {}
	if inst:IsA("GuiObject") then
		pcall(function()
			inst.AutoLocalize = false
		end)
	end
	for _, prop in ipairs(props) do
		apply(inst, prop)
		inst:GetPropertyChangedSignal(prop):Connect(function()
			apply(inst, prop)
		end)
	end
end

local function watchTree(root)
	for _, d in ipairs(root:GetDescendants()) do
		watch(d)
	end
	root.DescendantAdded:Connect(watch)
end

function Localizer.Code()
	return code
end

-- fn(code) ทุกครั้งที่เปลี่ยนภาษา (เช่น รูปปุ่มเมนูล็อบบี้ไทย/อังกฤษ)
function Localizer.OnChanged(fn)
	table.insert(listeners, fn)
end

function Localizer.Translate(text)
	return Lang.Translate(text, code)
end

local function resolve()
	local force = ReplicatedStorage:FindFirstChild("ASForceLang") -- เฉพาะไฟล์เทส (build --lang=xx)
	if force then
		return force.Value
	end
	local pref = ClientSettings.Get("Language")
	if type(pref) == "string" and pref ~= "Auto" and pref ~= "" then
		return pref
	end
	local loc = "en"
	pcall(function()
		loc = LocalizationService.RobloxLocaleId
	end)
	if loc == "en" or loc == "" then
		pcall(function()
			loc = player.LocaleId
		end)
	end
	return Lang.Detect(loc)
end

function Localizer.Set(newCode)
	if newCode == code then
		return
	end
	code = newCode
	-- แปลข้อความที่อยู่บนจอทั้งหมดใหม่ จากต้นฉบับที่จำไว้
	for inst, rec in pairs(tracked) do
		if inst.Parent then
			for prop, entry in pairs(rec) do
				if entry.Src then
					local tr = Lang.Translate(entry.Src, code)
					entry.Mine = tr
					inst[prop] = tr
				end
			end
		end
	end
	for _, fn in ipairs(listeners) do
		task.spawn(fn, code)
	end
end

function Localizer.Init()
	code = resolve()
	if misses then
		task.spawn(function()
			while true do
				task.wait(20)
				local batch = missList
				missList = {}
				for _, m in ipairs(batch) do
					print("[AS] I18N MISS " .. (m:gsub("\n", "\\n")))
				end
			end
		end)
	end
	watchTree(player:WaitForChild("PlayerGui"))
	watchTree(Workspace)
	ClientSettings.OnChanged(function(key)
		if key == "Language" then
			Localizer.Set(resolve())
		end
	end)
end

-- เรียกตอนโหลดโมดูล (ก่อนหน้าจออื่นสร้าง) เพื่อให้ภาษาถูกตั้งแต่เฟรมแรก
code = resolve()

return Localizer
