param([switch]$ShowMinimized, [int]$TimeoutSec = 480, [string]$PlaceName = "AnimalSurvival_TEST.rbxlx", [string]$DonePattern = "\[AS\] (MAP|ANIMAL)SHOT DONE|\[AS\] FETCH DONE|\[TEST\] DONE|\[AS\] เทสต์จบ")
$ErrorActionPreference = "Continue"
# รันเทสต์อัตโนมัติใน Studio + ถ่ายภาพ -> build/test_screenshots
# ไม่ปิด Studio ที่เปิดอยู่ก่อน: เปิดหน้าต่างใหม่ของตัวเอง แล้วปิดเฉพาะหน้าต่างที่เปิดเอง
# ถ่ายภาพด้วย PrintWindow เฉพาะหน้าต่าง Studio ของเทสต์ (ไม่ติดหน้าต่างอื่นของผู้ใช้)
$root = Split-Path -Parent $PSScriptRoot
$shots = Join-Path $root "build\test_screenshots"
New-Item -ItemType Directory -Force $shots | Out-Null
Get-ChildItem $shots -Filter *.png -ErrorAction SilentlyContinue | Remove-Item -Force
$exe = (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Recurse -Filter RobloxStudioBeta.exe | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$place = Join-Path $root ("build\" + $PlaceName)

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class PW {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h, int cmd);
  public static IntPtr Biggest(uint[] pids) {
    IntPtr best = IntPtr.Zero; long bestArea = 0;
    EnumWindows((h, l) => {
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (Array.IndexOf(pids, pid) >= 0 && IsWindowVisible(h)) {
        RECT r; GetWindowRect(h, out r);
        long a = (long)(r.R - r.L) * (r.B - r.T);
        if (a > bestArea) { bestArea = a; best = h; }
      }
      return true;
    }, IntPtr.Zero);
    return best;
  }
}
"@

$before = @(Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
# เฉพาะ Studio ที่เปิดไฟล์เทสต์ของเรา (ผู้ใช้เปิด Studio อื่นระหว่างเทสต์ = ไม่ถ่าย/ไม่ปิดของเขา)
function NewPids() {
  [uint32[]]@(Get-CimInstance Win32_Process -Filter "Name='RobloxStudioBeta.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $before -notcontains $_.ProcessId -and $_.CommandLine -like "*$PlaceName*" } | ForEach-Object { [uint32]$_.ProcessId })
}

function Capture($name) {
  $pids = NewPids
  if ($pids.Count -eq 0) { "skip $name"; return }
  $h = [PW]::Biggest($pids)
  if ($h -eq [IntPtr]::Zero) { "skip $name"; return }
  # หน้าต่างเทสต์ของเราถูกย่อ: เปิดคืนแบบไม่แย่งโฟกัส (SW_SHOWNOACTIVATE) ถ่าย แล้วย่อกลับ (SW_SHOWMINNOACTIVE)
  # หน้าต่างเทสต์ถูกย่อ = ผู้ใช้ไม่อยากให้เด้ง: ไม่เปิดคืน (ข้ามภาพนี้) — ใส่ -ShowMinimized เพื่อเปิดคืนชั่วครู่
  $wasMin = [PW]::IsIconic($h)
  if ($wasMin -and -not $ShowMinimized) { "skip $name (minimized)"; return }
  if ($wasMin) { [PW]::ShowWindowAsync($h, 4) | Out-Null; Start-Sleep -Milliseconds 900 }
  $r = New-Object PW+RECT
  [PW]::GetWindowRect($h, [ref]$r) | Out-Null
  $w = $r.R - $r.L; $ht = $r.B - $r.T
  if ($w -le 200 -or $ht -le 200) { if ($wasMin) { [PW]::ShowWindowAsync($h, 7) | Out-Null }; "skip $name (minimized)"; return }
  $bmp = New-Object System.Drawing.Bitmap $w, $ht
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $hdc = $g.GetHdc()
  [PW]::PrintWindow($h, $hdc, 2) | Out-Null
  $g.ReleaseHdc($hdc)
  $bmp.Save((Join-Path $shots "$name.png"))
  $g.Dispose(); $bmp.Dispose()
  if ($wasMin) { [PW]::ShowWindowAsync($h, 7) | Out-Null }
}

$start = Get-Date
Start-Process $exe -ArgumentList "`"$place`""
$seen = @{}
$done = $false
while (-not $done -and ((Get-Date) - $start).TotalSeconds -lt $TimeoutSec) {
  Start-Sleep -Milliseconds 400
  # เฉพาะ log ที่สร้างหลังเริ่มเทสต์ (ไม่อ่าน log ของ Studio ที่ผู้ใช้เปิดอยู่)
  $logs = Get-ChildItem "$env:LOCALAPPDATA\Roblox\logs" -Filter "*Studio*" | Where-Object { $_.CreationTime -gt $start }
  foreach ($log in $logs) {
    $lines = Get-Content $log.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $from = [int]$seen[$log.Name]
    for ($i = $from; $i -lt $lines.Count; $i++) {
      $l = $lines[$i]
      if ($l -match "\[SHOT\] (\S+)") { Capture $Matches[1]; "shot $($Matches[1])" }
      elseif ($l -match "\[TEST\]|\[AS\]|\[DIAG\]") { $l.Substring([Math]::Min(60, $l.Length)) }
      elseif ($l -match "CreatorError|Stack Begin|Script '|attempt to|is not a valid member|nil value" -and $l -notmatch "HttpError|HttpTrace|Ribbon|StyleRule|ChatScript|CoreGuiChatConnections") { "ERR: " + $l.Substring([Math]::Min(60, $l.Length)) }
      if ($l -match $DonePattern) { $done = $true }
    }
    $seen[$log.Name] = $lines.Count
  }
}
Start-Sleep -Seconds 2
# ปิดเฉพาะ Studio ที่เปิดไฟล์เทสต์ของเราเอง (ไม่แตะ Studio ที่ผู้ใช้เปิดระหว่างเทสต์)
foreach ($testPid in (NewPids)) { Stop-Process -Id $testPid -Force -ErrorAction SilentlyContinue }
"finished in $([int]((Get-Date) - $start).TotalSeconds)s  done=$done"
