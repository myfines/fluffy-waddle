$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$godot = Join-Path (Split-Path $root -Parent) 'GodotPortable_4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$output = Join-Path $root 'builds\VietnamWar1965-governance.exe'
if (-not (Test-Path $godot)) { throw "找不到 Godot：$godot" }
New-Item -ItemType Directory -Force -Path (Split-Path $output) | Out-Null
& $godot --headless --path $root --export-release 'Windows Desktop' $output
if ($LASTEXITCODE -ne 0) { throw "Windows 导出失败，退出码 $LASTEXITCODE" }
$file = Get-Item $output
Write-Output "Build complete: $($file.FullName) ($($file.Length) bytes)"
