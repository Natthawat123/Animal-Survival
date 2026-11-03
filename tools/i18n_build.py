"""
i18n_build.py — สร้างตารางคำแปลในเกม: assets/i18n/<code>.txt -> src/ReplicatedStorage/Shared/LangData/<code>.lua

  assets/i18n/source.txt  : เลข<TAB>ต้นฉบับอังกฤษ   (สร้างโดย tools/i18n_extract.py)
  assets/i18n/<code>.txt  : เลข<TAB>คำแปล          (บรรทัดว่าง/ไม่มีเลข = ข้าม · \\n = ขึ้นบรรทัด)
  ตรวจตัวแทนค่า (%s %d %.1f ...) ต้องครบและเรียงเหมือนต้นฉบับ ไม่งั้นทิ้งคำแปลนั้น (เกมใช้ภาษาอังกฤษแทน)

    python tools/i18n_build.py            ทุกภาษา
    python tools/i18n_build.py th es      เฉพาะที่ระบุ
"""
import glob
import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "assets", "i18n")
OUT = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "LangData")
SPEC = re.compile(r"%[-+#0]*\d*(?:\.\d+)?[sdif]")


def read(path):
    out = {}
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        m = re.match(r"^(\d+)\t(.*)$", line)
        if m and m.group(2).strip():
            out[int(m.group(1))] = m.group(2).replace("\\n", "\n")
    return out


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "") + '"'


def build(code, src):
    tr = read(os.path.join(DIR, code + ".txt"))
    rows, bad = [], []
    for i, en in src.items():
        t = tr.get(i)
        if t is None or t == en:
            continue
        if [m.group(0)[-1] for m in SPEC.finditer(en)] != [m.group(0)[-1] for m in SPEC.finditer(t)]:
            bad.append(i)
            continue
        # ช่องว่างหัว/ท้ายต้องเหมือนต้นฉบับ (โค้ดเอาไปต่อสตริง เช่น "Night of " .. ชื่อ)
        lead = en[: len(en) - len(en.lstrip(" "))]
        trail = en[len(en.rstrip(" ")):]
        t = lead + t.strip(" ") + trail
        rows.append(f"\t[{lua_str(en)}] = {lua_str(t)},")
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, code + ".lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(f"-- คำแปลภาษา {code} (สร้างโดย tools/i18n_build.py จาก assets/i18n/{code}.txt — อย่าแก้มือ)\nreturn {{\n")
        f.write("\n".join(rows))
        f.write("\n}\n")
    print(f"{code}: {len(rows)}/{len(src)} แปลแล้ว" + (f" · ตัวแทนค่าไม่ตรง {len(bad)}: {bad[:12]}" if bad else ""))


def main():
    src = read(os.path.join(DIR, "source.txt"))
    codes = sys.argv[1:] or [os.path.basename(p)[:-4] for p in glob.glob(os.path.join(DIR, "*.txt")) if not p.endswith("source.txt")]
    for code in sorted(codes):
        build(code, src)


main()
