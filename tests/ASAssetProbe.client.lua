--[[ ASAssetProbe (client) — เช็กว่าเมช/เท็กซ์เจอร์ของโมเดลนำเข้าโหลดได้ในบัญชีที่ล็อกอินอยู่ ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not ReplicatedStorage:FindFirstChild("ASAssetProbe") then return end
local CP = game:GetService("ContentProvider")
task.wait(8)
local G = {
	{ "EmberTotem", { 103355544810912, 103710564332602, 108631920878899, 120261417444293, 133541593001722, 81375250664826 } },
	{ "GaleTotem", { 112700031602359, 117528715070111, 136556134319001, 80452930881546, 80776137865868, 90118705316034 } },
	{ "TerraTotem", { 119573574125553, 128058314615020, 138934477950089, 85485119989345, 95090729764521, 97544916008259 } },
	{ "TideTotem", { 124056195736300, 126397615028520, 130638488618546, 136956794681522, 73185664077152, 75255344529494 } },
	{ "CampWorkbench", { 104382066155649, 109459114807885, 109951475676762, 124775386055063, 130875664752192, 91648417142515 } },
	{ "Chest1", { 103658973557049, 113255104371032, 139991710629264, 74740775651522, 92110842851781, 96365958992141 } },
	{ "MonumentAir", { 132673757183295, 98406088881612 } },
	{ "MonumentEarth", { 120525647913992, 93666644759882 } },
	{ "MonumentFire", { 124769272204981, 89877060122892 } },
	{ "MonumentWater", { 73114507534657, 79290453683145 } },
}
for _, g in ipairs(G) do
	local bad, ok = {}, 0
	for _, id in ipairs(g[2]) do
		local st
		local a = Instance.new("MeshPart")
		pcall(function() CP:PreloadAsync({ "rbxassetid://" .. id }, function(_, s) st = s end) end)
		if st == Enum.AssetFetchStatus.Success then ok += 1 else table.insert(bad, id .. "=" .. tostring(st)) end
	end
	print(string.format("[AS] ASSETPROBE %s %s ok=%d/%d %s", #bad == 0 and "PASS" or "FAIL", g[1], ok, #g[2], table.concat(bad, " ")))
end
print("[TEST] DONE assetprobe")
