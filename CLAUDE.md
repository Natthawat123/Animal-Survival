# Animal Survival (Roblox)

- เกมเอาชีวิตรอดสไตล์ 99 Nights in the Forest: แมพใหญ่, 4 ไบโอมธาตุ (น้ำ/ดิน/ลม/ไฟ) สุ่มตำแหน่ง, สัตว์บุกแคมป์ตอนกลางคืน, นับคืนถึง 99
- อ้างอิงลุคจริงของ 99 Nights (ล็อบบี้แคมป์ฟาร์มกลางคืน, เต็นท์ Classes, หม้อรางวัล, พื้นเรืองแสง) — **อย่าคิดฉากแฟนตาซีเอง** ให้ก๊อปลุคของเกมต้นแบบ
- โมเดลสัตว์/ตัวละคร/บอส: ดึงจาก Roblox Creator Store จริง (ไม่ใช่โมเดล procedural/metaball) ผ่าน tools/fetch_models.py + tools/store_to_rbxmx.py

## คำสั่ง build
- `python tools/build_rbxlx.py` → สร้าง `build/AnimalSurvival.rbxlx` (ไฟล์หลักที่ผู้เล่นเปิดเล่นจริง) **ต้องรันคำสั่งนี้แบบไม่ใส่ flag หลังแก้โค้ดทุกครั้ง** เพื่ออัปเดตไฟล์นี้
- flag อื่น ๆ ที่มี: `--test` (build เป็น `AnimalSurvival_TEST.rbxlx`), `--probe`, `--creatures`/`--gallery` (โชว์เคสโมเดล/ถ่ายชีท), `--fetch=id,id` (ดึงโมเดลจาก Creator Store), `--seed=`, `--sandbox`, `--mapshot`, `--animalshot`, `--shots`, `--vfxshow[=ชื่อแพ็ก]`

## คำสั่งเทส
- `powershell -File tools/run_studio_test.ps1` → เปิด Roblox Studio ด้วย `build/AnimalSurvival_TEST.rbxlx` (ต้อง build `--test` ก่อน), รันออโต้เทสต์ในเกม แล้วถ่ายภาพหน้าจอเก็บไว้ที่ `build/test_screenshots/`
- ดูผลผ่าน log ที่ terminal พิมพ์ออกมา และภาพใน `build/test_screenshots/`

## Blender pipeline
- Blender 5.2 ที่ `C:\Program Files\Blender Foundation\Blender 5.2`
- รันแบบ headless: `blender -b --factory-startup --python blender/<script>.py` (เปิด Blender GUI/MCP แล้วแครชมาก่อน ให้ใช้ headless เป็นหลัก)

## กฎการทำงาน
- ตอบเป็นภาษาไทยเสมอ
- ก่อนแก้ไฟล์ซ้ำไปซ้ำมา ให้รวบรวมแก้ทีเดียวแล้วโชว์ผลเร็ว ๆ (ประหยัด token)
- หลังแก้โค้ดเสร็จ ให้ build `AnimalSurvival.rbxlx` (ไม่ใส่ flag) เสมอ เพราะผู้เล่นเปิดไฟล์นี้เล่น
- `build/` ไม่ถูก track ใน git (อยู่ใน .gitignore) — เป็นไฟล์ที่ build ขึ้นมาใหม่ได้ตลอด ไม่ต้อง commit
