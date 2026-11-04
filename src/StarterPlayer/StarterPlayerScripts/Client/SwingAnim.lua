--[[
	SwingAnim — ท่าตี/ยิงของอาวุธแต่ละชนิด (ปรับฐานข้อต่อทุกเฟรมเหมือน MedAnim · ไม่ต้องอัปโหลดอนิเมชัน)
	  อาวุธแต่ละอันมีชุดท่าของตัวเอง ตีต่อเนื่อง = เล่นท่าถัดไปในคอมโบ (เว้นนานเกิน = เริ่มท่าแรกใหม่)
	  ผู้ตีเล่นทันทีในเครื่องตัวเอง · เครื่องอื่นเล่นตาม HitFx "Swing" จากเซิร์ฟเวอร์ -> ทุกคนเห็นท่าเดียวกัน
	ท่า = คีย์เฟรม { เวลา 0..1, ข้อต่อ = { ก้ม/เงย, หัน, ตะแคง } (องศา) } ข้อต่อที่ไม่ใส่ในคีย์ = ค้างจากคีย์ก่อน
	  แขน (RS/LS): ก้ม/เงย = ยกแขนจากห้อยลง (90 = ชี้ไปหน้า, 180 = ชูขึ้นฟ้า) · หัน + = ไปทางซ้ายตัว (นับจากอก: ทิศจริง = หันแขน + บิดเอว)
	  ศอก (RE/LE) / ข้อมือ (RW) / ขา (RH/LH) / เข่า (RK/LK): งอรอบแกนเดียว · RW -90 = อาวุธยาวชี้ไปตามแนวแขน (ปกติถือตั้งฉากกับแขน) · เอว (W): ก้ม - / เอนหลัง + · หัน + = บิดไปซ้าย
	  Root: { y = ย่อ/กระโดด (stud), yaw = หมุนทั้งตัว (องศา) }
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))

local SwingAnim = {}
-- เทสต์ถ่ายภาพ (tests/ASSwingProbe): HoldAt = ค้างท่าไว้ที่เวลานี้ (0..1) · ForceCombo = เล่นท่าที่เท่าไรในชุด
SwingAnim.HoldAt, SwingAnim.ForceCombo = nil, nil
local player = Players.LocalPlayer

local R = math.rad
local CF = CFrame.new
local ANG = CFrame.Angles

---------------------------------------------------------------- ท่า
local HOLD = { RS = { 90, 0, 0 }, LS = { 0, 0, 0 }, RE = { 0 }, LE = { 0 }, RW = { 0 }, W = { 0, 0, 0 }, RH = { 0 }, LH = { 0 }, RK = { 0 }, LK = { 0 }, Root = { 0, 0 } }

-- Impact = จังหวะที่ฟันโดน (สั่นกล้องของตัวเองตาม Shake) · Len = คูณความยาวท่า
local S = {}
S.ChopA = { Impact = 0.5, Keys = { -- ฟันเฉียงจากเหนือไหล่ขวาลงไปสะโพกซ้าย (ผ่าฟืน)
	{ 0.28, RS = { 165, -30, 0 }, RE = { 45 }, LS = { 70, 35, 0 }, LE = { 30 }, W = { 8, -25, 0 } },
	{ 0.5, RS = { 35, 40, 0 }, RE = { 5 }, LS = { 30, 20, 0 }, LE = { 20 }, W = { -16, 22, 0 } },
	{ 0.72, RS = { 22, 46, 0 }, RE = { 10 }, LS = { 25, 15, 0 }, W = { -18, 26, 0 } },
} }
S.ChopX = { Impact = 0.5, Keys = { -- ตวัดย้อนขึ้นจากสะโพกซ้ายไปเหนือไหล่ขวา (ไขว้กับ ChopA เป็นกากบาท)
	{ 0.28, RS = { 30, 50, 0 }, RE = { 20 }, RW = { -90 }, LS = { 40, 20, 0 }, LE = { 30 }, W = { -14, 30, 0 }, Root = { -0.2, 0 } },
	{ 0.5, RS = { 110, -35, 0 }, RE = { 0 }, RW = { -40 }, LS = { 60, 30, 0 }, LE = { 20 }, W = { 6, -25, 0 }, Root = { 0, 0 } },
	{ 0.72, RS = { 150, -45, 0 }, RE = { 15 }, RW = { -40 }, LS = { 55, 25, 0 }, W = { 8, -28, 0 } },
} }
S.Rise = { Impact = 0.48, Shake = 0.15, Keys = { -- สองมือย่อต่ำเก็บอาวุธข้างเท้า แล้วงัดขึ้นฟ้าพร้อมเด้งตัว
	{ 0.28, RS = { 10, -30, 0 }, RE = { 20 }, LS = { 20, -50, 0 }, LE = { 40 }, W = { -15, -30, 0 }, Root = { -0.5, 0 }, RH = { 35 }, LH = { 25 }, RK = { -45 }, LK = { -35 } },
	{ 0.48, RS = { 105, 10, 0 }, RE = { 0 }, LS = { 100, -10, 0 }, LE = { 20 }, W = { 14, 10, 0 }, Root = { 0.5, 0 }, RH = { 0 }, LH = { 0 }, RK = { 0 }, LK = { 0 } },
	{ 0.74, RS = { 150, 10, 0 }, RE = { 10 }, LS = { 145, -10, 0 }, W = { 16, 10, 0 }, Root = { 0.25, 0 } },
} }
S.Leap = { Impact = 0.6, Shake = 0.4, Len = 1.15, Keys = { -- ย่อตัว กระโดดสูงชูอาวุธสองมือ แล้วทุบลงพื้น
	{ 0.2, RS = { 60, 0, 0 }, RE = { 20 }, LS = { 60, 0, 0 }, LE = { 20 }, W = { -10, 0, 0 }, Root = { -0.5, 0 }, RH = { 40 }, LH = { 40 }, RK = { -60 }, LK = { -60 } },
	{ 0.42, RS = { 185, -10, 0 }, RE = { 30 }, RW = { -50 }, LS = { 185, 10, 0 }, LE = { 30 }, W = { 20, 0, 0 }, Root = { 2.0, 0 }, RH = { 30 }, LH = { 30 }, RK = { -50 }, LK = { -50 } },
	{ 0.6, RS = { 20, 10, 0 }, RE = { 0 }, RW = { 0 }, LS = { 20, -10, 0 }, LE = { 0 }, W = { -40, 0, 0 }, Root = { -1.0, 0 }, RH = { 70 }, LH = { -15 }, RK = { -90 }, LK = { -30 } },
	{ 0.85, RS = { 25, 10, 0 }, LS = { 25, -10, 0 }, W = { -34, 0, 0 }, Root = { -0.8, 0 }, RH = { 60 }, LH = { -10 }, RK = { -75 }, LK = { -25 } },
} }
S.Pick = { Impact = 0.52, Shake = 0.12, Keys = { -- สองมือชูเหนือหัว แล้วจามลงตรงๆ พร้อมย่อตัว
	{ 0.32, RS = { 195, -10, 0 }, RE = { 60 }, LS = { 195, 10, 0 }, LE = { 60 }, W = { 14, 0, 0 }, Root = { 0.15, 0 } },
	{ 0.52, RS = { 25, 8, 0 }, RE = { 0 }, LS = { 25, -8, 0 }, LE = { 0 }, W = { -32, 0, 0 }, Root = { -0.35, 0 } },
	{ 0.75, RS = { 20, 8, 0 }, RE = { 5 }, LS = { 20, -8, 0 }, LE = { 5 }, W = { -30, 0, 0 }, Root = { -0.3, 0 } },
} }
S.Tap = { Keys = { -- ค้อนช่าง: เคาะสองจังหวะ ก๊อกๆ
	{ 0.15, RS = { 125, 0, 0 }, RE = { 50 }, W = { -4, 0, 0 } },
	{ 0.3, RS = { 70, 0, 0 }, RE = { 15 } },
	{ 0.48, RS = { 125, 0, 0 }, RE = { 50 } },
	{ 0.66, RS = { 70, 0, 0 }, RE = { 15 } },
} }
S.ClubA = { Impact = 0.52, Keys = { -- หวดแบบไม้เบสบอล บิดทั้งตัว
	{ 0.32, RS = { 105, -115, 0 }, RE = { 60 }, LS = { 80, -60, 0 }, LE = { 70 }, W = { 4, -50, 0 } },
	{ 0.52, RS = { 95, 65, 0 }, RE = { 5 }, LS = { 75, 40, 0 }, LE = { 30 }, W = { -4, 50, 0 } },
	{ 0.75, RS = { 100, 70, 0 }, RE = { 25 }, LS = { 70, 40, 0 }, LE = { 40 }, W = { -2, 60, 0 } },
} }
S.ClubB = { Impact = 0.5, Shake = 0.1, Keys = { -- ทุบหัวลงมาเต็มแรง
	{ 0.3, RS = { 200, -5, 0 }, RE = { 70 }, LS = { 40, 20, 0 }, W = { 16, 0, 0 } },
	{ 0.5, RS = { 30, 10, 0 }, RE = { 0 }, LS = { 30, 10, 0 }, W = { -28, 5, 0 }, Root = { -0.3, 0 } },
	{ 0.75, RS = { 25, 12, 0 }, RE = { 5 }, W = { -26, 5, 0 }, Root = { -0.25, 0 } },
} }
S.Mace = { Impact = 0.64, Shake = 0.15, Keys = { -- เหวี่ยงลูกตุ้มวนเหนือหัว แล้วฟาดลง
	{ 0.15, RS = { 160, -60, 0 }, RE = { 20 }, LS = { 50, 30, 0 }, W = { 6, -15, 0 } },
	{ 0.27, RS = { 175, 20, 0 }, W = { 8, 0, 0 } },
	{ 0.39, RS = { 160, 60, 0 }, W = { 6, 10, 0 } },
	{ 0.5, RS = { 195, 0, 0 }, RE = { 30 }, W = { 14, 0, 0 } },
	{ 0.64, RS = { 30, 15, 0 }, RE = { 0 }, LS = { 30, 20, 0 }, W = { -24, 10, 0 }, Root = { -0.3, 0 } },
	{ 0.8, RS = { 25, 20, 0 }, RE = { 5 }, W = { -22, 12, 0 }, Root = { -0.25, 0 } },
} }
S.Slam = { Impact = 0.55, Shake = 0.45, Keys = { -- สองมือชูค้อนสุดตัว เขย่งขึ้น แล้วทุบพื้นย่อตัวต่ำ
	{ 0.35, RS = { 200, -15, 0 }, RE = { 50 }, LS = { 200, 15, 0 }, LE = { 50 }, W = { 18, 0, 0 }, Root = { 0.5, 0 }, RH = { 20 }, LH = { 20 }, RK = { -20 }, LK = { -20 } },
	{ 0.55, RS = { 20, 10, 0 }, RE = { 0 }, LS = { 20, -10, 0 }, LE = { 0 }, W = { -40, 0, 0 }, Root = { -1.0, 0 }, RH = { 70 }, LH = { -15 }, RK = { -90 }, LK = { -30 } },
	{ 0.82, RS = { 25, 10, 0 }, LS = { 25, -10, 0 }, W = { -34, 0, 0 }, Root = { -0.8, 0 }, RH = { 60 }, LH = { -10 }, RK = { -75 }, LK = { -25 } },
} }
S.SwordA = { Impact = 0.48, Keys = { -- ฟันเฉียงลงจากขวาบนไปซ้ายล่าง
	{ 0.25, RS = { 150, -50, 0 }, RE = { 35 }, LS = { 40, 0, 0 }, W = { 4, -30, 0 } },
	{ 0.48, RS = { 55, 50, 0 }, RE = { 0 }, W = { -10, 30, 0 } },
	{ 0.7, RS = { 45, 60, 0 }, RE = { 10 }, W = { -10, 34, 0 } },
} }
S.SwordB = { Impact = 0.48, Keys = { -- ตวัดย้อนขึ้นจากซ้ายล่างไปขวาบน
	{ 0.25, RS = { 50, 70, 0 }, RE = { 40 }, LS = { 35, 0, 0 }, W = { -6, 35, 0 } },
	{ 0.48, RS = { 150, -55, 0 }, RE = { 0 }, W = { 4, -30, 0 } },
	{ 0.7, RS = { 160, -60, 0 }, RE = { 10 }, W = { 4, -32, 0 } },
} }
S.SwordC = { Impact = 0.5, Keys = { -- ก้าวพุ่งแทงตรง
	{ 0.3, RS = { 80, -10, 0 }, RE = { 95 }, LS = { 60, 30, 0 }, LE = { 30 }, W = { 6, -20, 0 } },
	{ 0.5, RS = { 92, 5, 0 }, RE = { 0 }, LS = { 30, 0, 0 }, LE = { 10 }, W = { -14, 10, 0 }, Root = { -0.35, 0 }, RH = { 45 }, LH = { -25 }, RK = { -45 }, LK = { -10 } },
	{ 0.72, RS = { 90, 5, 0 }, W = { -12, 10, 0 }, Root = { -0.3, 0 }, RH = { 40 }, LH = { -20 }, RK = { -40 }, LK = { -10 } },
} }
S.KatanaA = { Impact = 0.42, Keys = { -- ชักดาบจากเอวซ้ายฟันตัดแนวนอน (อิไอ)
	{ 0.22, RS = { 45, 70, 0 }, RE = { 60 }, LS = { 45, 40, 0 }, LE = { 60 }, W = { -6, 40, 0 }, Root = { -0.3, 0 } },
	{ 0.42, RS = { 95, -50, 0 }, RE = { 0 }, LS = { 60, -20, 0 }, LE = { 30 }, W = { -4, -45, 0 } },
	{ 0.7, RS = { 100, -55, 0 }, RE = { 5 }, LS = { 55, -20, 0 }, W = { -2, -48, 0 }, Root = { -0.2, 0 } },
} }
S.KatanaB = { Impact = 0.45, Keys = { -- จับสองมือ ผ่าลงตรงๆ
	{ 0.25, RS = { 185, 0, 0 }, RE = { 40 }, LS = { 185, 10, 0 }, LE = { 40 }, W = { 10, 0, 0 } },
	{ 0.45, RS = { 45, 8, 0 }, RE = { 0 }, LS = { 45, -8, 0 }, LE = { 0 }, W = { -20, 0, 0 }, Root = { -0.25, 0 } },
	{ 0.7, RS = { 40, 8, 0 }, LS = { 40, -8, 0 }, W = { -22, 0, 0 } },
} }
S.KatanaC = { Impact = 0.42, Keys = { -- ตวัดกลับขวาไปซ้ายเร็วๆ
	{ 0.22, RS = { 100, -60, 0 }, RE = { 20 }, LS = { 40, 0, 0 }, W = { 0, -40, 0 } },
	{ 0.42, RS = { 95, 55, 0 }, RE = { 0 }, W = { -4, 45, 0 } },
	{ 0.68, RS = { 90, 60, 0 }, W = { -4, 48, 0 } },
} }
S.DaggerA = { Impact = 0.4, Keys = { -- แทงจิ้มเร็ว
	{ 0.2, RS = { 75, 0, 0 }, RE = { 110 }, W = { 0, -15, 0 } },
	{ 0.4, RS = { 95, 10, 0 }, RE = { 0 }, W = { -8, 15, 0 } },
	{ 0.65, RS = { 92, 10, 0 }, RE = { 10 }, W = { -6, 12, 0 } },
} }
S.DaggerB = { Impact = 0.42, Keys = { -- ตวัดเฉียงขึ้น
	{ 0.2, RS = { 40, 40, 0 }, RE = { 70 }, W = { 0, 25, 0 } },
	{ 0.42, RS = { 130, -55, 0 }, RE = { 10 }, W = { 0, -30, 0 } },
	{ 0.65, RS = { 135, -60, 0 }, W = { 0, -32, 0 } },
} }
S.DaggerC = { Impact = 0.42, Keys = { -- ย่อตัวแทงท้อง
	{ 0.2, RS = { 50, -10, 0 }, RE = { 90 }, LS = { 50, 30, 0 }, LE = { 40 }, W = { -10, -10, 0 }, Root = { -0.4, 0 } },
	{ 0.42, RS = { 80, 5, 0 }, RE = { 0 }, W = { -22, 10, 0 }, Root = { -0.6, 0 }, RH = { 40 }, RK = { -50 }, LH = { -10 }, LK = { -20 } },
	{ 0.66, RS = { 78, 5, 0 }, W = { -20, 10, 0 }, Root = { -0.5, 0 } },
} }
S.Cleave = { Impact = 0.55, Shake = 0.3, Keys = { -- สองมือยกดาบใหญ่ข้ามหัว ก้าวพุ่งผ่าลงพื้น
	{ 0.32, RS = { 200, -20, 0 }, RE = { 40 }, LS = { 195, 10, 0 }, LE = { 45 }, W = { 16, -10, 0 } },
	{ 0.55, RS = { 30, 15, 0 }, RE = { 0 }, LS = { 30, -5, 0 }, LE = { 0 }, W = { -36, 5, 0 }, Root = { -0.6, 0 }, RH = { 55 }, LH = { -25 }, RK = { -60 }, LK = { -15 } },
	{ 0.8, RS = { 28, 15, 0 }, LS = { 28, -5, 0 }, W = { -32, 5, 0 }, Root = { -0.5, 0 }, RH = { 50 }, LH = { -20 }, RK = { -55 }, LK = { -15 } },
} }
S.Sweep = { Impact = 0.55, Shake = 0.15, Keys = { -- สองมือกวาดดาบเป็นวงกว้าง
	{ 0.3, RS = { 100, -60, 0 }, RE = { 20 }, LS = { 95, -40, 0 }, LE = { 40 }, W = { 0, -55, 0 }, Root = { -0.2, 0 } },
	{ 0.55, RS = { 95, 50, 0 }, RE = { 0 }, LS = { 90, 30, 0 }, LE = { 20 }, W = { -4, 60, 0 }, Root = { -0.3, 0 } },
	{ 0.8, RS = { 95, 55, 0 }, LS = { 88, 35, 0 }, W = { -4, 64, 0 }, Root = { -0.2, 0 } },
} }
S.ReapA = { Impact = 0.55, Keys = { -- เคียว: ก้มตัวกวาดต่ำเป็นวงกว้าง
	{ 0.3, RS = { 70, -55, 0 }, RE = { 30 }, LS = { 60, -35, 0 }, LE = { 40 }, W = { -10, -60, 0 }, Root = { -0.4, 0 } },
	{ 0.55, RS = { 60, 45, 0 }, RE = { 10 }, LS = { 50, 30, 0 }, LE = { 30 }, W = { -20, 60, 0 }, Root = { -0.5, 0 } },
	{ 0.8, RS = { 62, 50, 0 }, LS = { 52, 35, 0 }, W = { -18, 62, 0 }, Root = { -0.4, 0 } },
} }
S.ReapB = { Impact = 0.55, Shake = 0.12, Keys = { -- เคียว: ชูขึ้นแล้วสับลงกระชากเข้าหาตัว
	{ 0.3, RS = { 190, -10, 0 }, RE = { 30 }, LS = { 170, 10, 0 }, LE = { 30 }, W = { 12, 0, 0 } },
	{ 0.55, RS = { 60, 0, 0 }, RE = { 80 }, LS = { 50, 0, 0 }, LE = { 80 }, W = { -22, 0, 0 }, Root = { -0.3, 0 } },
	{ 0.8, RS = { 55, 0, 0 }, RE = { 90 }, LS = { 48, 0, 0 }, LE = { 85 }, W = { -18, 0, 0 } },
} }
S.ReapC = { Impact = 0.5, Shake = 0.12, Keys = { -- เคียว: ย่อต่ำทางขวา แล้วตวัดขึ้นเฉียงเป็นจันทร์เสี้ยวไปบนซ้าย พร้อมเด้งตัว
	{ 0.28, RS = { 30, -40, 0 }, RE = { 20 }, LS = { 30, -20, 0 }, LE = { 40 }, W = { -20, -30, 0 }, Root = { -0.5, 0 }, RH = { 35 }, RK = { -45 }, LH = { 20 }, LK = { -30 } },
	{ 0.5, RS = { 110, 30, 0 }, RE = { 0 }, LS = { 100, 15, 0 }, LE = { 20 }, W = { 12, 25, 0 }, Root = { 0.4, 0 }, RH = { 0 }, RK = { 0 }, LH = { 0 }, LK = { 0 } },
	{ 0.75, RS = { 140, 35, 0 }, LS = { 130, 20, 0 }, W = { 14, 28, 0 }, Root = { 0.2, 0 } },
} }
-- หอก/ตรีศูล: หักข้อมือ (RW) ให้ปลายหอกชี้ไปตามแขน · ทิศหอก = ไหล่ + ศอก + ข้อมือ + 90 (90 = ชี้ตรงไปข้างหน้า)
S.ThrustA = { Impact = 0.5, Keys = { -- ดึงหอกไว้ข้างเอว แล้วก้าวพุ่งแทงยาว ปลายหอกชี้ไปหน้าตลอด
	{ 0.3, RS = { -25, -10, 0 }, RE = { 115 }, RW = { -90 }, LS = { 80, 30, 0 }, LE = { 40 }, W = { 6, -25, 0 } },
	{ 0.5, RS = { 92, 5, 0 }, RE = { 0 }, RW = { -78 }, LS = { 70, 20, 0 }, LE = { 20 }, W = { -16, 15, 0 }, Root = { -0.4, 0 }, RH = { 50 }, LH = { -25 }, RK = { -50 }, LK = { -10 } },
	{ 0.75, RS = { 90, 5, 0 }, RW = { -76 }, LS = { 65, 20, 0 }, W = { -14, 15, 0 }, Root = { -0.35, 0 }, RH = { 45 }, LH = { -20 }, RK = { -45 }, LK = { -10 } },
} }
S.ThrustB = { Impact = 0.55, Keys = { -- ยื่นหอกยาวไปตามแขน กวาดเป็นวงจากขวาไปซ้าย
	{ 0.25, RS = { 95, -50, 0 }, RE = { 10 }, RW = { -90 }, LS = { 60, -10, 0 }, LE = { 50 }, W = { 0, -45, 0 } },
	{ 0.55, RS = { 92, 45, 0 }, RE = { 0 }, RW = { -90 }, LS = { 60, 20, 0 }, W = { -6, 50, 0 } },
	{ 0.78, RS = { 90, 50, 0 }, RW = { -90 }, W = { -6, 52, 0 } },
} }
S.ThrustC = { Impact = 0.5, Shake = 0.2, Keys = { -- ตรีศูล: กระโดดชูขึ้น แล้วจ้วงปลายแทงลงพื้นข้างหน้า
	{ 0.3, RS = { 150, 0, 0 }, RE = { 20 }, RW = { -90 }, LS = { 140, 10, 0 }, LE = { 30 }, W = { 12, 0, 0 }, Root = { 0.6, 0 } },
	{ 0.5, RS = { 75, 0, 0 }, RE = { 0 }, RW = { -90 }, LS = { 70, 0, 0 }, LE = { 10 }, W = { -25, 0, 0 }, Root = { -0.6, 0 }, RH = { 50 }, RK = { -70 }, LH = { 10 }, LK = { -40 } },
	{ 0.76, RS = { 75, 0, 0 }, RW = { -90 }, W = { -22, 0, 0 }, Root = { -0.5, 0 } },
} }
S.TorchA = { Impact = 0.45, Keys = { -- คบเพลิง: ยื่นไฟจ่อไปข้างหน้า
	{ 0.25, RS = { 120, -20, 0 }, RE = { 60 } },
	{ 0.45, RS = { 85, 15, 0 }, RE = { 0 }, W = { -8, 12, 0 } },
	{ 0.7, RS = { 88, 12, 0 }, W = { -6, 10, 0 } },
} }
S.TorchB = { Impact = 0.45, Keys = { -- คบเพลิง: ปัดไฟกวาดข้าง
	{ 0.25, RS = { 100, -70, 0 }, RE = { 20 }, W = { 0, -25, 0 } },
	{ 0.45, RS = { 90, 50, 0 }, RE = { 0 }, W = { 0, 25, 0 } },
	{ 0.7, RS = { 90, 55, 0 }, W = { 0, 26, 0 } },
} }
S.CastFire = { Impact = 0.4, Keys = { -- คทาไฟ: กระแทกคทาไปข้างหน้า มือซ้ายผลักฝ่ามือตาม
	{ 0.2, RS = { 70, -10, 0 }, RE = { 60 }, LS = { 60, 30, 0 }, LE = { 50 }, W = { 6, -15, 0 } },
	{ 0.4, RS = { 100, 5, 0 }, RE = { 0 }, LS = { 95, -15, 0 }, LE = { 0 }, W = { -10, 10, 0 } },
	{ 0.7, RS = { 98, 5, 0 }, LS = { 92, -15, 0 }, W = { -8, 10, 0 } },
} }
S.CastArcane = { Impact = 0.45, Keys = { -- คทาอาคม: ชูสองมือรวมพลังเหนือหัว แล้วผลักออก
	{ 0.25, RS = { 175, -10, 0 }, RE = { 20 }, LS = { 175, 10, 0 }, LE = { 20 }, W = { 12, 0, 0 }, Root = { 0.2, 0 } },
	{ 0.45, RS = { 95, 0, 0 }, RE = { 0 }, LS = { 95, -10, 0 }, LE = { 0 }, W = { -12, 0, 0 } },
	{ 0.72, RS = { 95, 0, 0 }, LS = { 95, -10, 0 }, W = { -10, 0, 0 } },
} }
S.CastVerdant = { Impact = 0.48, Keys = { -- คทาพงไพร: ตวัดคทาจากพื้นขึ้นมาข้างหน้า (หว่านหนาม)
	{ 0.25, RS = { 20, -30, 0 }, RE = { 10 }, LS = { 50, 40, 0 }, LE = { 40 }, W = { -15, -20, 0 }, Root = { -0.3, 0 } },
	{ 0.48, RS = { 130, 10, 0 }, RE = { 0 }, LS = { 80, -10, 0 }, LE = { 10 }, W = { 4, 10, 0 } },
	{ 0.72, RS = { 125, 10, 0 }, LS = { 75, -10, 0 }, W = { 2, 10, 0 } },
} }
S.Bow = { Len = 0.9, Keys = { -- ธนู: ตั้งตัวข้าง ง้างสาย แล้วปล่อยมือดีดกลับ
	{ 0.15, LS = { 92, -10, 0 }, LE = { 0 }, RS = { 95, 25, 0 }, RE = { 140 }, W = { 0, 30, 0 } },
	{ 0.3, RS = { 98, 35, 0 }, RE = { 150 } },
	{ 0.42, RS = { 100, -15, 0 }, RE = { 120 }, W = { 0, 28, 0 } },
	{ 0.75, LS = { 90, -10, 0 }, RS = { 95, -5, 0 }, RE = { 100 }, W = { 0, 25, 0 } },
} }
S.Crossbow = { Len = 0.8, Keys = { -- หน้าไม้: ประทับบ่าสองมือ แรงสะท้อนดีดขึ้น
	{ 0.12, RS = { 95, 10, 0 }, RE = { 30 }, LS = { 95, -20, 0 }, LE = { 40 }, W = { 0, 0, 0 } },
	{ 0.25, RS = { 112, 10, 0 }, LS = { 112, -20, 0 }, W = { 10, 0, 0 } },
	{ 0.6, RS = { 95, 10, 0 }, LS = { 95, -20, 0 }, W = { 0, 0, 0 } },
} }

-- อาวุธ -> ชุดคอมโบ
local SETS = {
	OldAxe = { "ChopA", "ChopX" }, StoneAxe = { "ChopA", "ChopX" }, IronAxe = { "ChopA", "ChopX" },
	BattleAxe = { "Cleave", "Rise", "Leap" },
	Pickaxe = { "Pick" }, BuildHammer = { "Tap" },
	SpikedClub = { "ClubA", "ClubB" }, Mace = { "Mace" },
	WarHammer = { "Slam", "Sweep" }, TerraHammer = { "Slam", "ClubA" },
	IronSword = { "SwordA", "SwordB", "SwordC" },
	Katana = { "KatanaA", "KatanaB", "KatanaC" },
	Dagger = { "DaggerA", "DaggerB", "DaggerC" },
	EmberBlade = { "Cleave", "Sweep" }, FourfoldBlade = { "Cleave", "Sweep", "Leap" },
	Scythe = { "ReapA", "ReapB", "ReapC" }, BloodScythe = { "ReapA", "ReapB", "ReapC" },
	Spear = { "ThrustA", "ThrustB" }, TidalTrident = { "ThrustA", "ThrustB", "ThrustC" },
	Torch = { "TorchA", "TorchB" },
	EmberStaff = { "CastFire" }, ArcaneStaff = { "CastArcane" }, VerdantStaff = { "CastVerdant" },
	Bow = { "Bow" }, GaleBow = { "Bow" }, Crossbow = { "Crossbow" },
}
SwingAnim.Styles, SwingAnim.Sets = S, SETS -- เทสต์ถ่ายภาพทุกท่า (tests/ASSwingProbe)
local BY_KIND = { Axe = { "ChopA", "ChopX" }, Pick = { "Pick" }, Hammer = { "ClubA", "ClubB" }, Sword = { "SwordA", "SwordB", "SwordC" },
	Spear = { "ThrustA", "ThrustB" }, Torch = { "TorchA", "TorchB" }, Staff = { "CastFire" }, Bow = { "Bow" } }

-- เติมข้อต่อที่คีย์ไม่ได้ใส่ (ค้างจากคีย์ก่อน · คีย์แรก = ท่าถือของปกติ) -> ทุกคีย์มีข้อต่อครบชุดที่ท่านี้ใช้
for _, style in pairs(S) do
	local used = {}
	for _, k in ipairs(style.Keys) do
		for j in pairs(k) do
			if j ~= 1 then
				used[j] = true
			end
		end
	end
	local prev = {}
	for j in pairs(used) do
		prev[j] = HOLD[j]
	end
	for _, k in ipairs(style.Keys) do
		for j in pairs(used) do
			k[j] = k[j] or prev[j]
			prev[j] = k[j]
		end
	end
	style.Used = used
end

---------------------------------------------------------------- ข้อต่อ
local function getBase(j)
	if j:IsA("Motor6D") then
		return j.C0
	end
	return j.Attachment0 and j.Attachment0.CFrame
end
local function setBase(j, cf)
	if j:IsA("Motor6D") then
		j.C0 = cf
	elseif j.Attachment0 then
		j.Attachment0.CFrame = cf
	end
end

local function joints(char)
	if not char:FindFirstChild("UpperTorso") then
		return nil -- R6: ไม่รองรับ (ใช้ท่าฟันของ Roblox แทน)
	end
	local function m(partName, name)
		local p = char:FindFirstChild(partName)
		local j = p and p:FindFirstChild(name)
		return j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) and j or nil
	end
	return {
		RS = m("RightUpperArm", "RightShoulder"), LS = m("LeftUpperArm", "LeftShoulder"),
		RE = m("RightLowerArm", "RightElbow"), LE = m("LeftLowerArm", "LeftElbow"), RW = m("RightHand", "RightWrist"),
		W = m("UpperTorso", "Waist"), Root = m("LowerTorso", "Root"),
		RH = m("RightUpperLeg", "RightHip"), LH = m("LeftUpperLeg", "LeftHip"),
		RK = m("RightLowerLeg", "RightKnee"), LK = m("LeftLowerLeg", "LeftKnee"),
	}
end

-- องศา -> CFrame ของข้อต่อ (ยกก่อน แล้วค่อยหันรอบแกนตั้ง)
local function toCF(j, v)
	if j == "Root" then
		return CF(0, v[1], 0) * ANG(0, R(v[2]), 0)
	elseif #v == 1 then
		return ANG(R(v[1]), 0, 0)
	end
	return ANG(0, R(v[2]), 0) * ANG(R(v[1]), 0, 0) * ANG(0, 0, R(v[3]))
end

local function smooth(x)
	return x * x * (3 - 2 * x)
end

-- ท่า ณ เวลา t (0..1) + น้ำหนัก (เข้าท่าช่วงก่อนคีย์แรก · ออกท่าหลังคีย์สุดท้าย)
local function sample(style, t)
	local keys = style.Keys
	local first, last = keys[1], keys[#keys]
	local a
	if t < first[1] then
		a = smooth(t / first[1])
	elseif t > last[1] then
		a = smooth(1 - (t - last[1]) / (1 - last[1]))
	else
		a = 1
	end
	local k0, k1, f = first, first, 0
	if t >= last[1] then
		k0, k1 = last, last
	elseif t > first[1] then
		for i = 1, #keys - 1 do
			if t <= keys[i + 1][1] then
				k0, k1 = keys[i], keys[i + 1]
				f = smooth((t - k0[1]) / (k1[1] - k0[1]))
				break
			end
		end
	end
	local pose = {}
	for j in pairs(style.Used) do
		local v0, v1 = k0[j], k1[j]
		local v = {}
		for i = 1, #v0 do
			v[i] = v0[i] + (v1[i] - v0[i]) * f
		end
		pose[j] = toCF(j, v)
	end
	return pose, a
end

---------------------------------------------------------------- สถานะต่อผู้เล่น
local states = {} -- [player] = { Char, J, Base, Style, T0, Dur, Hit, Combo, Last, SetId }

function SwingAnim.Play(p, id)
	local tool = Items.Tools[id]
	local set = SETS[id] or (tool and BY_KIND[tool.Kind])
	local char = p and p.Character
	if not set or not char then
		return false
	end
	local st = states[p]
	if not st or st.Char ~= char then
		local J = joints(char)
		if not J then
			return false
		end
		st = { Char = char, J = J, Base = {}, Combo = 0, Last = 0 }
		states[p] = st
	elseif not st.Style then
		st.Base = {} -- ท่าก่อนจบไปแล้ว (คืนฐานแล้ว): จดฐานใหม่ เผื่อระบบอื่นปรับข้อต่อไประหว่างนั้น
	end
	local now = os.clock()
	-- ตีต่อเนื่อง (เว้นไม่เกิน 0.6 วิหลังจบท่า) = ท่าถัดไปในคอมโบ
	if st.SetId == id and now - st.Last < (st.Dur or 0) + 0.6 then
		st.Combo = st.Combo % #set + 1
	else
		st.Combo = 1
	end
	st.Combo = SwingAnim.ForceCombo or st.Combo
	local style = S[set[math.min(st.Combo, #set)]]
	st.SetId, st.Last = id, now
	st.Style, st.T0, st.Hit = style, now, false
	st.Dur = math.clamp((tool and tool.Cooldown or 0.6) * 0.95, 0.3, 1.05) * (style.Len or 1)
	return true
end

local function restore(st)
	for m, base in pairs(st.Base) do
		if m.Parent then
			setBase(m, base)
		end
	end
end

local function step()
	for p, st in pairs(states) do
		if not st.Char.Parent or not p.Parent then
			restore(st)
			states[p] = nil
		elseif st.Style then
			local t = SwingAnim.HoldAt or (os.clock() - st.T0) / st.Dur
			if t >= 1 then
				restore(st)
				st.Style = nil
			else
				if not st.Hit and st.Style.Impact and t >= st.Style.Impact then
					st.Hit = true
					if p == player and st.Style.Shake and SwingAnim.Shake then
						SwingAnim.Shake(st.Style.Shake, 0.18) -- ท่าหนัก: กล้องสั่นตอนฟาดโดน
					end
				end
				local pose, a = sample(st.Style, t)
				local used = {}
				for key, cf in pairs(pose) do
					local m = st.J[key]
					if m and m.Parent then
						local base = st.Base[m] or getBase(m)
						if base then
							st.Base[m] = base
							-- Animator เขียน Transform ทุกเฟรม -> ปรับฐานโดยหักท่าของ Animator ออก (ได้ท่าตามคีย์ไม่ว่าเล่นท่าอะไรอยู่)
							local cur = m.Transform
							setBase(m, base * cur:Lerp(cf, a) * cur:Inverse())
							used[m] = true
						end
					end
				end
				for m, base in pairs(st.Base) do
					if not used[m] and m.Parent then
						setBase(m, base)
					end
				end
			end
		end
	end
end

function SwingAnim.Init(shake)
	SwingAnim.Shake = shake
	RunService.Stepped:Connect(step)
	Players.PlayerRemoving:Connect(function(p)
		local st = states[p]
		if st then
			restore(st)
			states[p] = nil
		end
	end)
end

return SwingAnim
