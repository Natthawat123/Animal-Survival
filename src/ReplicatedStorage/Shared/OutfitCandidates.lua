-- OutfitCandidates — ชุดตัวบล็อกคลาสสิกให้เลือก (สร้างโดย outfit_gen_classic.py, ใช้กับ build_rbxlx.py --outfits)
local C = Color3.fromRGB
local M = { Order = { "Survivor", "Forager", "Lumberjack", "Medic", "Hunter", "Builder", "Scout", "Firekeeper", "Elementalist", "Beastwarden" } }
M.Survivor = {
	{ Face = 0, Skin = C(234, 184, 146), Shirt = 115382067033056, Pants = 133062402990026, Accessories = { HatAccessory = { 134280662220378 }, BackAccessory = { 113689229530781 } } }, -- Survivor
	{ Face = 7074786, Skin = C(204, 158, 125), Shirt = 15509633700, Pants = 102890589378334, Accessories = { HatAccessory = { 116857151310669 } } }, -- Jacket +
	{ Face = 7074764, Skin = C(184, 137, 103), Shirt = 1476610564, Pants = 14346861499, Accessories = { HairAccessory = { 76930005586224 }, BackAccessory = { 18166289334 } } }, -- Survivor +
	{ Face = 209995366, Skin = C(245, 205, 48), Shirt = 4643837725, Pants = 78798088326036, Accessories = { HatAccessory = { 18213003897 } } }, -- Jacket 
	{ Face = 7699174, Skin = C(168, 123, 89), Shirt = 4917225150, Pants = 10748260596, Accessories = { HatAccessory = { 94950750251346 }, BackAccessory = { 90536160996799 } } }, -- Survivor [+]
	{ Face = 12145366, Skin = C(226, 186, 152), Shirt = 72970088966897, Pants = 116731657257683, Accessories = { HairAccessory = { 15948577306 } } }, -- jacket
	{ Face = 7317793, Skin = C(234, 184, 146), Shirt = 14346851219, Pants = 2799628604, Accessories = { HatAccessory = { 76395967556758 }, BackAccessory = { 16355086383 } } }, -- Survivor [+]
	{ Face = 8560971, Skin = C(204, 158, 125), Shirt = 13744135921, Pants = 75448803695760, Accessories = { HatAccessory = { 18664738315 } } }, -- jacket
	{ Face = 7076076, Skin = C(184, 137, 103), Shirt = 6721127873, Pants = 16267229158, Accessories = { HairAccessory = { 14808657533 }, BackAccessory = { 16214901994 } } }, -- Survivor 🖤
	{ Face = 7131886, Skin = C(245, 205, 48), Shirt = 13752378127, Pants = 117071752089758, Accessories = { HatAccessory = { 135850044775726 } } }, -- jacket
	{ Face = 25166274, Skin = C(168, 123, 89), Shirt = 2799627517, Pants = 139044980585004, Accessories = { HatAccessory = { 80053590012996 }, BackAccessory = { 17440879425 } } }, -- Survivor +
	{ Face = 0, Skin = C(226, 186, 152), Shirt = 14252428954, Pants = 18201542206, Accessories = { HairAccessory = { 124421416222436 } } }, -- jacket
	{ Face = 7074786, Skin = C(234, 184, 146), Shirt = 110033935812874, Pants = 139677868495148, Accessories = { HatAccessory = { 112685965124335 }, BackAccessory = { 132808046037949 } } }, -- Survivor
	{ Face = 7074764, Skin = C(204, 158, 125), Shirt = 5001379987, Pants = 1476611334, Accessories = { HatAccessory = { 13354632892 } } }, -- jacket
	{ Face = 209995366, Skin = C(184, 137, 103), Shirt = 622583708, Pants = 15316814283, Accessories = { HairAccessory = { 14390235242 }, BackAccessory = { 16747039762 } } }, -- Survivor [+]
}
M.Forager = {
	{ Face = 0, Skin = C(204, 158, 125), Shirt = 15555892695, Pants = 6340921958, Accessories = { HatAccessory = { 18853523552 } } }, -- Farmer [+]
	{ Face = 7074786, Skin = C(184, 137, 103), Shirt = 5183224958, Pants = 3495318044, Accessories = { HatAccessory = { 14052959892 } } }, -- OVERALLS
	{ Face = 7074764, Skin = C(245, 205, 48), Shirt = 18613837870, Pants = 92509908045639, Accessories = { HairAccessory = { 128262647966382 } } }, -- farmer👨‍🌾
	{ Face = 209995366, Skin = C(168, 123, 89), Shirt = 9255642683, Pants = 504597434, Accessories = { HatAccessory = { 102801020640137 } } }, -- Overalls +
	{ Face = 7699174, Skin = C(226, 186, 152), Shirt = 887208841, Pants = 15555895110, Accessories = { HatAccessory = { 135778857451639 } } }, -- [!] Farmer +
	{ Face = 12145366, Skin = C(234, 184, 146), Shirt = 10067177320, Pants = 102602637071644, Accessories = { HairAccessory = { 132114860739345 } } }, -- overalls
	{ Face = 7317793, Skin = C(204, 158, 125), Shirt = 6537438588, Pants = 4500312196, Accessories = { HatAccessory = { 85318263208066 } } }, -- Farmer
	{ Face = 8560971, Skin = C(184, 137, 103), Shirt = 13226902227, Pants = 95137153616428, Accessories = { HatAccessory = { 131721213154579 } } }, -- OVERALLS
	{ Face = 7076076, Skin = C(245, 205, 48), Shirt = 97055502283367, Pants = 93657981337274, Accessories = { HairAccessory = { 15594362123 } } }, -- farmer
	{ Face = 7131886, Skin = C(168, 123, 89), Shirt = 6473622329, Pants = 82604993869607, Accessories = { HatAccessory = { 118656670729954 } } }, -- Overalls
	{ Face = 25166274, Skin = C(226, 186, 152), Shirt = 76078272695950, Pants = 118260723754676, Accessories = { HatAccessory = { 111227660004476 } } }, -- Farmer
	{ Face = 0, Skin = C(234, 184, 146), Shirt = 119157027058863, Pants = 15388790886, Accessories = { HairAccessory = { 128303338866094 } } }, -- overalls
	{ Face = 7074786, Skin = C(204, 158, 125), Shirt = 112601090958008, Pants = 85555094361788, Accessories = { HatAccessory = { 82499218280026 } } }, -- Farmer +
	{ Face = 7074764, Skin = C(184, 137, 103), Shirt = 111032844258091, Pants = 103890509547091, Accessories = { HatAccessory = { 15208956211 } } }, -- overalls
	{ Face = 209995366, Skin = C(245, 205, 48), Shirt = 101785635729322, Pants = 121005396173801, Accessories = { HairAccessory = { 17069924171 } } }, -- farmer
}
M.Lumberjack = {
	{ Face = 0, Skin = C(184, 137, 103), Shirt = 975765812, Pants = 75795284095299, Accessories = { HatAccessory = { 13959224986 } } }, -- Lumberjack +
	{ Face = 7074786, Skin = C(245, 205, 48), Shirt = 9332432068, Pants = 975767586, Accessories = { HatAccessory = { 15091010571 } } }, -- flannel
	{ Face = 7074764, Skin = C(168, 123, 89), Shirt = 16345956771, Pants = 14083155111, Accessories = { HairAccessory = { 125365438167720 } } }, -- Lumberjack [+]
	{ Face = 209995366, Skin = C(226, 186, 152), Shirt = 127771236980236, Pants = 11642457136, Accessories = { HatAccessory = { 11576615088 } } }, -- Flannel
	{ Face = 7699174, Skin = C(234, 184, 146), Shirt = 5781654992, Pants = 15389382285, Accessories = { HatAccessory = { 93999898622273 } } }, -- Lumberjack
	{ Face = 12145366, Skin = C(204, 158, 125), Shirt = 7951150715, Pants = 11642456004, Accessories = { HairAccessory = { 16932178606 } } }, -- flannel
	{ Face = 7317793, Skin = C(184, 137, 103), Shirt = 98970389111150, Pants = 11325736410, Accessories = { HatAccessory = { 13959255715 } } }, -- lumberjack+
	{ Face = 8560971, Skin = C(245, 205, 48), Shirt = 17460162387, Pants = 6493492455, Accessories = { HatAccessory = { 13989202923 } } }, -- Flannel
	{ Face = 7076076, Skin = C(168, 123, 89), Shirt = 105863370368356, Pants = 2418560350, Accessories = { HairAccessory = { 108162247366251 } } }, -- Lumberjack
	{ Face = 7131886, Skin = C(226, 186, 152), Shirt = 9406697934, Pants = 8532711758, Accessories = { HatAccessory = { 79055365070199 } } }, -- flannel
	{ Face = 25166274, Skin = C(234, 184, 146), Shirt = 11941623344, Pants = 10721888240, Accessories = { HatAccessory = { 98387276041666 } } }, -- Кофта Бэкста с Жилетом - Lumberjack
	{ Face = 0, Skin = C(204, 158, 125), Shirt = 6201766727, Pants = 15389390424, Accessories = { HairAccessory = { 116294341223183 } } }, -- flannel
	{ Face = 7074786, Skin = C(184, 137, 103), Shirt = 6541078002, Pants = 81401533402618, Accessories = { HatAccessory = { 16793010009 } } }, -- LumberJack
	{ Face = 7074764, Skin = C(245, 205, 48), Shirt = 103103553649825, Pants = 9993572657, Accessories = { HatAccessory = { 85549182668981 } } }, -- Flannel [+]
	{ Face = 209995366, Skin = C(168, 123, 89), Shirt = 86005712490325, Pants = 12945604156, Accessories = { HairAccessory = { 132773349736723 } } }, -- Lumberjack +
}
M.Medic = {
	{ Face = 0, Skin = C(245, 205, 48), Shirt = 87777528178307, Pants = 136229329178677, Accessories = { HatAccessory = { 70444448960498 }, NeckAccessory = { 30844997 } } }, -- doctor
	{ Face = 7074786, Skin = C(168, 123, 89), Shirt = 6351494751, Pants = 78391995772799, Accessories = { HatAccessory = { 101881466420638 } } }, -- Medic +
	{ Face = 7074764, Skin = C(226, 186, 152), Shirt = 90929575853950, Pants = 6135918564, Accessories = { HairAccessory = { 15948577306 }, NeckAccessory = { 137261604876000 } } }, -- doctor
	{ Face = 209995366, Skin = C(234, 184, 146), Shirt = 94534861665412, Pants = 7450825454, Accessories = { HatAccessory = { 76322817537256 } } }, -- ( ゝ ‸ ╹)ノ medic 
	{ Face = 7699174, Skin = C(204, 158, 125), Shirt = 1013931715, Pants = 5692765832, Accessories = { HatAccessory = { 109789023364220 }, NeckAccessory = { 9061711441 } } }, -- Doctor +
	{ Face = 12145366, Skin = C(184, 137, 103), Shirt = 16573683250, Pants = 10434420700, Accessories = { HairAccessory = { 14808657533 } } }, -- [+] Medic
	{ Face = 7317793, Skin = C(245, 205, 48), Shirt = 75552257407351, Pants = 1013934469, Accessories = { HatAccessory = { 119297101208751 }, NeckAccessory = { 122507690141100 } } }, -- Doctor +
	{ Face = 8560971, Skin = C(168, 123, 89), Shirt = 6301329406, Pants = 8754219581, Accessories = { HatAccessory = { 135348135733432 } } }, -- Medic
	{ Face = 7076076, Skin = C(226, 186, 152), Shirt = 1386093106, Pants = 125054241881211, Accessories = { HairAccessory = { 124421416222436 }, NeckAccessory = { 106972039890297 } } }, -- Doctor
	{ Face = 7131886, Skin = C(234, 184, 146), Shirt = 11179305529, Pants = 88949966190297, Accessories = { HatAccessory = { 84079273431867 } } }, -- [+] Medic
	{ Face = 25166274, Skin = C(204, 158, 125), Shirt = 5351788811, Pants = 10298208805, Accessories = { HatAccessory = { 140166115416330 }, NeckAccessory = { 110225308341606 } } }, -- doctor
	{ Face = 0, Skin = C(184, 137, 103), Shirt = 5193963972, Pants = 123362748335431, Accessories = { HairAccessory = { 14390235242 } } }, -- Medic.
	{ Face = 7074786, Skin = C(245, 205, 48), Shirt = 8263614497, Pants = 133273917258127, Accessories = { HatAccessory = { 76520800914474 }, NeckAccessory = { 87141476164607 } } }, -- doctor 
	{ Face = 7074764, Skin = C(168, 123, 89), Shirt = 7869996927, Pants = 135044546729707, Accessories = { HatAccessory = { 94296504350177 } } }, -- Medic [+]
	{ Face = 209995366, Skin = C(226, 186, 152), Shirt = 7450819731, Pants = 2574284524, Accessories = { HairAccessory = { 134270005179578 }, NeckAccessory = { 107981275102901 } } }, -- Doctor 
}
M.Hunter = {
	{ Face = 0, Skin = C(168, 123, 89), Shirt = 13894732451, Pants = 1208508184, Accessories = { HatAccessory = { 87611037489249 } } }, -- Hunter
	{ Face = 7074786, Skin = C(226, 186, 152), Shirt = 125375434138903, Pants = 12133655304, Accessories = { HatAccessory = { 137992110649122 } } }, -- Archer - Shirt | HSR x Fate
	{ Face = 7074764, Skin = C(234, 184, 146), Shirt = 1208507973, Pants = 15114603942, Accessories = { HairAccessory = { 132114860739345 } } }, -- Hunter +
	{ Face = 209995366, Skin = C(204, 158, 125), Shirt = 95459903231148, Pants = 16284027057, Accessories = { HatAccessory = { 82541542368069 } } }, -- [+] Archer
	{ Face = 7699174, Skin = C(184, 137, 103), Shirt = 9289294699, Pants = 11363805123, Accessories = { HatAccessory = { 134937612688480 } } }, -- hunter 
	{ Face = 12145366, Skin = C(245, 205, 48), Shirt = 246903244, Pants = 4117149723, Accessories = { HairAccessory = { 15594362123 } } }, -- Fate/Stay Night - Archer Top
	{ Face = 7317793, Skin = C(168, 123, 89), Shirt = 14001068294, Pants = 5785061494, Accessories = { HatAccessory = { 125543010089470 } } }, -- Hunter+
	{ Face = 8560971, Skin = C(226, 186, 152), Shirt = 6951317914, Pants = 14216927448, Accessories = { HatAccessory = { 71215842435806 } } }, -- Militia Archer + Bracers [+]
	{ Face = 7076076, Skin = C(234, 184, 146), Shirt = 13164139920, Pants = 5485545278, Accessories = { HairAccessory = { 128303338866094 } } }, -- Hunter [+]
	{ Face = 7131886, Skin = C(204, 158, 125), Shirt = 11647527458, Pants = 11372575134, Accessories = { HatAccessory = { 14545213182 } } }, -- Archer Shirt Cloak
	{ Face = 25166274, Skin = C(184, 137, 103), Shirt = 17504326928, Pants = 6020992061, Accessories = { HatAccessory = { 13159651925 } } }, -- hunter
	{ Face = 0, Skin = C(245, 205, 48), Shirt = 9840721121, Pants = 112785558852928, Accessories = { HairAccessory = { 17069924171 } } }, -- Fate/Stay Night - Archer *ORIGINAL* V2
	{ Face = 7074786, Skin = C(168, 123, 89), Shirt = 14579701390, Pants = 10388133669, Accessories = { HatAccessory = { 103571653205147 } } }, -- hunter 
	{ Face = 7074764, Skin = C(226, 186, 152), Shirt = 7004006704, Pants = 17872182243, Accessories = { HatAccessory = { 15545691990 } } }, -- Archer [+]
	{ Face = 209995366, Skin = C(234, 184, 146), Shirt = 11829915555, Pants = 17073146367, Accessories = { HairAccessory = { 89091934147152 } } }, -- Hunter +
}
M.Builder = {
	{ Face = 0, Skin = C(226, 186, 152), Shirt = 108314476232121, Pants = 73015621048966, Accessories = { HatAccessory = { 16713265880 } } }, -- Construction 
	{ Face = 7074786, Skin = C(234, 184, 146), Shirt = 6109068730, Pants = 6090847138, Accessories = { HatAccessory = { 83545717666765 } } }, -- Builder
	{ Face = 7074764, Skin = C(204, 158, 125), Shirt = 6281367702, Pants = 9638650394, Accessories = { HairAccessory = { 16932178606 } } }, -- construction vest shirt
	{ Face = 209995366, Skin = C(184, 137, 103), Shirt = 14716911006, Pants = 135554525905587, Accessories = { HatAccessory = { 14617436112 } } }, -- [TBC] Turbo Builders Club Overalls [+]
	{ Face = 7699174, Skin = C(245, 205, 48), Shirt = 99037022229406, Pants = 119858355105092, Accessories = { HatAccessory = { 4036753255 } } }, -- Construction 
	{ Face = 12145366, Skin = C(168, 123, 89), Shirt = 2626326216, Pants = 12945623627, Accessories = { HairAccessory = { 108162247366251 } } }, -- Builder
	{ Face = 7317793, Skin = C(226, 186, 152), Shirt = 6445665914, Pants = 2460361905, Accessories = { HatAccessory = { 118972275534546 } } }, -- construction
	{ Face = 8560971, Skin = C(234, 184, 146), Shirt = 70672641059776, Pants = 1744022729, Accessories = { HatAccessory = { 13839788585 } } }, -- Builder
	{ Face = 7076076, Skin = C(204, 158, 125), Shirt = 18596008899, Pants = 14977221649, Accessories = { HairAccessory = { 116294341223183 } } }, -- Construction
	{ Face = 7131886, Skin = C(184, 137, 103), Shirt = 16068965490, Pants = 9551658528, Accessories = { HatAccessory = { 13243695867 } } }, -- BC-Builders-Club-Overalls-
	{ Face = 25166274, Skin = C(245, 205, 48), Shirt = 89982529050917, Pants = 111016015591987, Accessories = { HatAccessory = { 17189954947 } } }, -- Construction
	{ Face = 0, Skin = C(168, 123, 89), Shirt = 3975709466, Pants = 7505254237, Accessories = { HairAccessory = { 132773349736723 } } }, -- 🛠 Outrageous Builders Club (OBC) Hoodie 
	{ Face = 7074786, Skin = C(226, 186, 152), Shirt = 9896680269, Pants = 1059498050, Accessories = { HatAccessory = { 81124270730272 } } }, -- construction
	{ Face = 7074764, Skin = C(234, 184, 146), Shirt = 55485514, Pants = 5522393245, Accessories = { HatAccessory = { 15921374774 } } }, -- Outrageous Builder's Club Construction S
	{ Face = 209995366, Skin = C(204, 158, 125), Shirt = 113633498277838, Pants = 11981078835, Accessories = { HairAccessory = { 13366425462 } } }, -- Construction
}
M.Scout = {
	{ Face = 0, Skin = C(234, 184, 146), Shirt = 9900169489, Pants = 10139200003, Accessories = { HatAccessory = { 13335289 } } }, -- Ranger [+]
	{ Face = 7074786, Skin = C(204, 158, 125), Shirt = 6357180699, Pants = 11193968084, Accessories = { HatAccessory = { 13625389628 } } }, -- "Explorer" [+]
	{ Face = 7074764, Skin = C(184, 137, 103), Shirt = 7479019476, Pants = 87438134121784, Accessories = { HairAccessory = { 14808657533 } } }, -- 'Ranger' +
	{ Face = 209995366, Skin = C(245, 205, 48), Shirt = 10623003521, Pants = 11828209643, Accessories = { HatAccessory = { 18241382741 } } }, -- Explorer suit
	{ Face = 7699174, Skin = C(168, 123, 89), Shirt = 10365136076, Pants = 6582760336, Accessories = { HatAccessory = { 17352607202 } } }, -- Ranger [+]
	{ Face = 12145366, Skin = C(226, 186, 152), Shirt = 15055890605, Pants = 83280874949327, Accessories = { HairAccessory = { 124421416222436 } } }, -- Explorer [+]
	{ Face = 7317793, Skin = C(234, 184, 146), Shirt = 12696379800, Pants = 12696385673, Accessories = { HatAccessory = { 18490932903 } } }, -- Ranger [+]
	{ Face = 8560971, Skin = C(204, 158, 125), Shirt = 2555242959, Pants = 14684893229, Accessories = { HatAccessory = { 130184155980662 } } }, -- Explorer 
	{ Face = 7076076, Skin = C(184, 137, 103), Shirt = 11828207129, Pants = 7181668862, Accessories = { HairAccessory = { 14390235242 } } }, -- Ranger +
	{ Face = 7131886, Skin = C(245, 205, 48), Shirt = 6125115907, Pants = 17207973516, Accessories = { HatAccessory = { 118370135460727 } } }, -- Explorer Explorer Explorer Explorer Expl
	{ Face = 25166274, Skin = C(168, 123, 89), Shirt = 10435231047, Pants = 5186948716, Accessories = { HatAccessory = { 126633616947396 } } }, -- ranger
	{ Face = 0, Skin = C(226, 186, 152), Shirt = 6195249331, Pants = 8677910638, Accessories = { HairAccessory = { 134270005179578 } } }, -- Veteran Explorer +
	{ Face = 7074786, Skin = C(234, 184, 146), Shirt = 10163387409, Pants = 6578450133, Accessories = { HatAccessory = { 83194006757824 } } }, -- ranger
	{ Face = 7074764, Skin = C(204, 158, 125), Shirt = 15325639028, Pants = 12254675130, Accessories = { HatAccessory = { 125864738171355 } } }, -- 🐍Jungle Explorer Jacket🐍
	{ Face = 209995366, Skin = C(184, 137, 103), Shirt = 17207958332, Pants = 6035852576, Accessories = { HairAccessory = { 133663523197400 } } }, -- Ranger +
}
M.Firekeeper = {
	{ Face = 7074836, Skin = C(204, 158, 125), Shirt = 6722202687, Pants = 6722183770, Accessories = { HatAccessory = { 87611037489249 } } }, -- FIRE
	{ Face = 7131886, Skin = C(184, 137, 103), Shirt = 17873984136, Pants = 541696684, Accessories = { HatAccessory = { 137992110649122 } } }, -- flame!
	{ Face = 8560971, Skin = C(245, 205, 48), Shirt = 541695482, Pants = 15886325262, Accessories = { HairAccessory = { 15594362123 } } }, -- Fire
	{ Face = 0, Skin = C(168, 123, 89), Shirt = 2714912566, Pants = 3870155243, Accessories = { HatAccessory = { 82541542368069 } } }, -- Flame
	{ Face = 7074786, Skin = C(226, 186, 152), Shirt = 1460544108, Pants = 6405587719, Accessories = { HatAccessory = { 134937612688480 } } }, -- fire
	{ Face = 7074764, Skin = C(234, 184, 146), Shirt = 5711838454, Pants = 4949263315, Accessories = { HairAccessory = { 128303338866094 } } }, -- flame
	{ Face = 209995366, Skin = C(204, 158, 125), Shirt = 7188583930, Pants = 6238257900, Accessories = { HatAccessory = { 125543010089470 } } }, -- FIRE
	{ Face = 7699174, Skin = C(184, 137, 103), Shirt = 90120713539908, Pants = 114948252152108, Accessories = { HatAccessory = { 71215842435806 } } }, -- FLAME
	{ Face = 12145366, Skin = C(245, 205, 48), Shirt = 113044972934604, Pants = 7055438831, Accessories = { HairAccessory = { 17069924171 } } }, -- FIRE
	{ Face = 7317793, Skin = C(168, 123, 89), Shirt = 5774294693, Pants = 5700149537, Accessories = { HatAccessory = { 14545213182 } } }, -- flame
	{ Face = 8560971, Skin = C(226, 186, 152), Shirt = 5275941506, Pants = 5114962012, Accessories = { HatAccessory = { 13159651925 } } }, -- Fire
	{ Face = 7076076, Skin = C(234, 184, 146), Shirt = 139139964437558, Pants = 5151058477, Accessories = { HairAccessory = { 89091934147152 } } }, -- flame
	{ Face = 7131886, Skin = C(204, 158, 125), Shirt = 5003670475, Pants = 5177361224, Accessories = { HatAccessory = { 103571653205147 } } }, -- Fire
	{ Face = 25166274, Skin = C(184, 137, 103), Shirt = 81130525759252, Pants = 114852485695041, Accessories = { HatAccessory = { 15545691990 } } }, -- Flame
	{ Face = 7074836, Skin = C(245, 205, 48), Shirt = 5177346405, Pants = 2702383011, Accessories = { HairAccessory = { 105475650123218 } } }, -- fire
}
M.Elementalist = {
	{ Face = 7317793, Skin = C(184, 137, 103), Shirt = 82453406334245, Pants = 135874552531932, Accessories = { HatAccessory = { 93295021954019 } } }, -- Wizard
	{ Face = 8560971, Skin = C(245, 205, 48), Shirt = 12333255293, Pants = 94114543415414, Accessories = { HatAccessory = { 15491030848 } } }, -- MAGE  +
	{ Face = 0, Skin = C(168, 123, 89), Shirt = 127669591992790, Pants = 92018735217502, Accessories = { HairAccessory = { 108162247366251 } } }, -- Wizard
	{ Face = 7074786, Skin = C(226, 186, 152), Shirt = 1042915015, Pants = 490940555, Accessories = { HatAccessory = { 18860962628 } } }, -- Mage
	{ Face = 7074764, Skin = C(234, 184, 146), Shirt = 104626353791777, Pants = 5700443051, Accessories = { HatAccessory = { 15491018658 } } }, -- Wizard [ + ]
	{ Face = 209995366, Skin = C(204, 158, 125), Shirt = 2715706068, Pants = 17658499375, Accessories = { HairAccessory = { 116294341223183 } } }, -- Black Mage Shirt
	{ Face = 7699174, Skin = C(184, 137, 103), Shirt = 86027333976550, Pants = 16159927221, Accessories = { HatAccessory = { 80542497269844 } } }, -- Wizard [ + ]
	{ Face = 12145366, Skin = C(245, 205, 48), Shirt = 71027679289334, Pants = 5995257976, Accessories = { HatAccessory = { 86266785217216 } } }, -- Mage+
	{ Face = 7317793, Skin = C(168, 123, 89), Shirt = 102899150237164, Pants = 127125642452045, Accessories = { HairAccessory = { 132773349736723 } } }, -- Wizard
	{ Face = 8560971, Skin = C(226, 186, 152), Shirt = 2715706272, Pants = 108733996546754, Accessories = { HatAccessory = { 15491035174 } } }, -- Battle Mage Shirt
	{ Face = 7076076, Skin = C(234, 184, 146), Shirt = 112621039394329, Pants = 93940968457755, Accessories = { HatAccessory = { 14760083714 } } }, -- Wizard
	{ Face = 7131886, Skin = C(204, 158, 125), Shirt = 122766500085591, Pants = 80238315323556, Accessories = { HairAccessory = { 13366425462 } } }, -- Mage [+]
	{ Face = 25166274, Skin = C(184, 137, 103), Shirt = 504981971, Pants = 137004222553440, Accessories = { HatAccessory = { 14087217216 } } }, -- Wizard
	{ Face = 7317793, Skin = C(245, 205, 48), Shirt = 7151081646, Pants = 92399277093254, Accessories = { HatAccessory = { 14760085169 } } }, -- the mage sleeves
	{ Face = 8560971, Skin = C(168, 123, 89), Shirt = 17658506963, Pants = 92342563212855, Accessories = { HairAccessory = { 17725600471 } } }, -- Wizard
}
M.Beastwarden = {
	{ Face = 7075142, Skin = C(245, 205, 48), Shirt = 17030361425, Pants = 133675694679570, Accessories = { HatAccessory = { 127742995585933 } } }, -- Werewolf
	{ Face = 7076224, Skin = C(168, 123, 89), Shirt = 5282128892, Pants = 139972713772660, Accessories = { HatAccessory = { 127776547077691 } } }, -- Beast
	{ Face = 7131886, Skin = C(226, 186, 152), Shirt = 106604002386752, Pants = 14986223921, Accessories = { HairAccessory = { 124421416222436 } } }, -- werewolf red shirt
	{ Face = 0, Skin = C(234, 184, 146), Shirt = 137644273326178, Pants = 17006400132, Accessories = { HatAccessory = { 127292256142654 } } }, -- beast
	{ Face = 7074786, Skin = C(204, 158, 125), Shirt = 14986199747, Pants = 6417512204, Accessories = { HatAccessory = { 128039712802530 } } }, -- Comical Werewolf [+]
	{ Face = 7074764, Skin = C(184, 137, 103), Shirt = 14043907767, Pants = 295106135, Accessories = { HairAccessory = { 14390235242 } } }, -- beast
	{ Face = 209995366, Skin = C(245, 205, 48), Shirt = 5118173557, Pants = 6417514797, Accessories = { HatAccessory = { 110607633779546 } } }, -- Stereotypical werewolf
	{ Face = 7699174, Skin = C(168, 123, 89), Shirt = 5037871840, Pants = 127875173796070, Accessories = { HatAccessory = { 135674515960413 } } }, -- beast
	{ Face = 12145366, Skin = C(226, 186, 152), Shirt = 138196220028040, Pants = 118148759118847, Accessories = { HairAccessory = { 134270005179578 } } }, -- Werewolf (+)
	{ Face = 7317793, Skin = C(234, 184, 146), Shirt = 2866201061, Pants = 3752427452, Accessories = { HatAccessory = { 127742995585933 } } }, -- BEAST
	{ Face = 8560971, Skin = C(204, 158, 125), Shirt = 11298934359, Pants = 8041374542, Accessories = { HatAccessory = { 127776547077691 } } }, -- Werewolf (Torn Flannel)
	{ Face = 7076076, Skin = C(184, 137, 103), Shirt = 448530310, Pants = 5834080963, Accessories = { HairAccessory = { 133663523197400 } } }, -- Beast
	{ Face = 7131886, Skin = C(245, 205, 48), Shirt = 11624718846, Pants = 2118207225, Accessories = { HatAccessory = { 127292256142654 } } }, -- Werewolf
	{ Face = 25166274, Skin = C(168, 123, 89), Shirt = 4960410168, Pants = 1120720488, Accessories = { HatAccessory = { 128039712802530 } } }, -- Beast
	{ Face = 7075142, Skin = C(226, 186, 152), Shirt = 6909892604, Pants = 90621186358701, Accessories = { HairAccessory = { 15246241877 } } }, -- Werewolf [+]
}
return M
