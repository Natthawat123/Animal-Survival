--[[ ASShrineProbe (server) — build_rbxlx.py --shrineprobe
	วาร์ปเข้าศาลเจ้าดิน -> ฉากเปิด (ผู้เฝ้าเดินเข้าหากรง/หันมา) -> ฆ่าผู้เฝ้า -> ปลดผนึก -> ฉากจบ (เสาผุด/ลูกสัตว์ไปแคมป์ +1 วัน)
	-> ไปแคมป์ ขี่ลูกสัตว์ เดินไปมา -> ลง · client ถ่ายภาพตามชื่อใน ShrineShot ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
if not ReplicatedStorage:FindFirstChild("ASShrineProbe") then
	return
end
local shot = Instance.new("StringValue")
shot.Name = "ShrineShot"
shot.Parent = ReplicatedStorage
local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
repeat
	task.wait(1)
until player:GetAttribute("InRun") and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
task.wait(8)
player:SetAttribute("TestGod", true)
local Server = game:GetService("ServerScriptService").Server
local Spirit = require(Server.SpiritService)
local Animal = require(Server.AnimalService)
local Portal = require(Server.PortalService)
local Mount = require(Server.MountService)
local state = Spirit.ctx.State
local function step(name, wait)
	shot.Value = name
	print("[AS] SHRINEPROBE " .. name)
	task.wait(wait or 1.2)
end

local Director = require(Server.DirectorService)
local skips = 0
local realSkip = Director.SkipDay
Director.SkipDay = function(...)
	skips += 1
	return realSkip(...)
end
local fails = 0
local function check(name, ok, detail)
	if not ok then
		fails += 1
	end
	print(string.format("[AS] SHRINEPROBE %s %s %s", ok and "PASS" or "FAIL", name, detail and tostring(detail) or ""))
end
-- ทั้ง 4 ศาลเจ้า: ฉากเปิด -> ฆ่าผู้เฝ้า -> ปลดผนึก -> ฉากจบ -> ขี่ -> ลง
for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
	local sh = Spirit.shrines[el]
	print("[AS] SHRINEPROBE", el, "entry", sh and sh.Entry, "base", sh and sh.Base)
	if not (sh and sh.Entry) then
		continue
	end
	local night0 = state:GetAttribute("Night")
	Portal:Teleport(player, sh.Entry, sh.Base, Color3.new(0.5, 1, 0.4))
	local t0 = os.clock()
	repeat
		task.wait(0.2)
	until #sh.Guardians > 0 or os.clock() - t0 > 8
	print("[AS] SHRINEPROBE guardians", #sh.Guardians, "intro", sh.IntroPlayed)
	step(el .. "_1wide", 1.6)
	step(el .. "_2pup", 2.6)
	step(el .. "_3guard", 2.4)
	step(el .. "_4run", 1.6)
	step(el .. "_5turn", 1.2)
	step(el .. "_6roar", 1.8)
	task.wait(1.5)
	for _, g in ipairs(sh.Guardians) do
		print(string.format("[AS] SHRINEPROBE guardian %s dist=%.1f", g.Id, (g.Root.Position - sh.Base).Magnitude))
		Animal:Kill(g, player)
	end
	task.wait(2.5)
	print("[AS] SHRINEPROBE prompt", sh.Prompt.Enabled)
	local before = skips
	local pup = sh.Pup
	check(el .. " portal-open-before-free", sh.OutVeil and sh.OutVeil:GetAttribute("Sealed") ~= true)
	-- กดซ้ำรัวๆ พร้อมกันหลายคน ต้องนับครั้งเดียว
	Spirit:Free(el, player)
	Spirit:Free(el, player)
	Spirit:Free(el, player)
	check(el .. " portal-sealed-after-free", sh.OutVeil and sh.OutVeil:GetAttribute("Sealed") == true)
	task.wait(0.6)
	step(el .. "_c1free", 2.6)
	step(el .. "_c2rise", 2)
	step(el .. "_c3rise2", 1.6)
	step(el .. "_c4beam", 1.2)
	step(el .. "_c5beam2", 1.6)
	step(el .. "_c6home", 2.2)
	step(el .. "_c7day", 2.5)
	task.wait(1)
	check(el .. " skip-once", skips - before == 1, skips - before)
	-- เรียกซ้ำหลังช่วยแล้ว / กู้รอบจาก Rejoin ต้องไม่ได้วันเพิ่ม ไม่มีสัตว์ซ้ำ
	local pet0 = sh.Pet
	Spirit:Free(el, player)
	Spirit:Rescue(pup, player)
	Spirit:Restore(Spirit:Serialize())
	check(el .. " no-extra-skip", skips - before == 1, skips - before)
	check(el .. " same-pet", sh.Pet == pet0 and pet0 ~= nil and not pet0.Removed)
	check(el .. " still-sealed", sh.OutVeil:GetAttribute("Sealed") == true)
	check(el .. " back-portal-open", (function()
		for _, d in ipairs(sh.Model:GetDescendants()) do
			if typeof(d:GetAttribute("Dest")) == "Vector3" and d ~= sh.OutVeil and d:GetAttribute("Sealed") then
				return false
			end
		end
		return true
	end)())
	check(el .. " spirit-count", state:GetAttribute("SpiritCount") >= 1, state:GetAttribute("SpiritCount"))
	print("[AS] SHRINEPROBE night", night0, "->", state:GetAttribute("Night"), "spirit", state:GetAttribute("Spirit" .. el), "pillar", sh.Pillar and sh.Pillar.Parent ~= nil)
	local pet = sh.Pet
	print("[AS] SHRINEPROBE pet", pet and pet.Id, pet and pet.Model.Parent ~= nil)
	if pet then
		task.wait(3)
		print(string.format("[AS] SHRINEPROBE pet state=%s campDist=%.1f", tostring(pet.Model:GetAttribute("State")), (pet.Root.Position - Spirit.ctx.CampPosition).Magnitude))
		player.Character:PivotTo(pet.Root.CFrame * CFrame.new(0, 2, 8))
		task.wait(1.5)
		step(el .. "_pet", 1)
		Mount:Mount(player, pet)
		print("[AS] SHRINEPROBE riding", player:GetAttribute("Riding"), "hip", player.Character.Humanoid.HipHeight)
		task.wait(1.2)
		step(el .. "_ride", 1.2)
		Mount:Dismount(player)
		task.wait(1)
		print("[AS] SHRINEPROBE dismount", player:GetAttribute("Riding"), "hip", player.Character.Humanoid.HipHeight)
		step(el .. "_after", 1)
	end
end
check("total-skips", skips == 4, skips)
-- เริ่มรอบใหม่: ประตูต้องเปิด ศาลเจ้ากลับมาเล่นได้ ฉากเปิดเล่นได้อีก
Spirit:Reset()
for _, el in ipairs({ "Earth", "Water", "Air", "Fire" }) do
	local sh = Spirit.shrines[el]
	check(el .. " reset-open", sh.OutVeil and sh.OutVeil:GetAttribute("Sealed") ~= true and not sh.Freed and not sh.Rescued and sh.Pup ~= nil and not sh.IntroPlayed)
end
print(string.format("[AS] SHRINEPROBE FINISHED fails=%d", fails)) -- ไม่ใช้ [TEST] DONE: ตัวรันเซสชันอื่นอ่าน log รวม จะจบเทสต์เขา
