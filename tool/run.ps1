# Builds the example on Windows and runs it once in the interactive desktop
# session (GUI apps started from SSH's session 0 die). Copy the repository
# first (without build directories), then from its root:
#   powershell -ExecutionPolicy Bypass -File tool\run.ps1 [-ModelDir <whisper model folder>] [-NoAsr] [-Config <json>]
# Pass -Config from the same PowerShell (& .\tool\run.ps1 -Config '{"exit":true}'): through another
# powershell.exe the JSON loses its double quotes.
param(
  [string]$ModelDir = '',
  [switch]$NoAsr,
  [switch]$SkipBuild,
  [string]$Config = ''
)
$ErrorActionPreference = 'Stop'
$lab = Split-Path -Parent $PSScriptRoot
$app = Join-Path $lab 'example'
$log = Join-Path $lab 'build\windows.log'
New-Item -ItemType Directory -Force -Path (Join-Path $lab 'build') | Out-Null

if (-not $SkipBuild) {
  $vk = Get-ChildItem C:\VulkanSDK -Directory -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
  if ($vk) { $env:VULKAN_SDK = $vk.FullName; $env:PATH = "$($vk.FullName)\Bin;$env:PATH" }
  Push-Location $app
  cmd /c "flutter pub get > ..\build\pub.log 2>&1"
  cmd /c "flutter build windows --release > ..\build\build-windows.log 2>&1"
  $code = $LASTEXITCODE
  Pop-Location
  if ($code -ne 0) { Get-Content (Join-Path $lab 'build\build-windows.log') -Tail 40; throw "build failed ($code)" }
}

$exe = Join-Path $app 'build\windows\x64\runner\Release\tts_pcm_example.exe'
$result = Join-Path $env:TEMP 'tts_result.json'
Remove-Item $result -ErrorAction SilentlyContinue
$config = if ($Config) { $Config } elseif ($NoAsr) { '{"exit":true,"asr":false}' } else { '{"exit":true}' }
$cmd = Join-Path $lab 'build\run-tts.cmd'
@"
@echo off
set TTS_CONFIG=$config
set TTS_ASR_MODEL_DIR=$ModelDir
"$exe"
"@ | Set-Content -Encoding ascii $cmd

schtasks /create /tn tts_pcm_example /tr $cmd /sc once /st 23:59 /it /f | Out-Null
schtasks /run /tn tts_pcm_example | Out-Null
$deadline = (Get-Date).AddMinutes(10)
while ((Get-Date) -lt $deadline -and -not (Test-Path $result)) { Start-Sleep 3 }
Start-Sleep 2
schtasks /delete /tn tts_pcm_example /f | Out-Null
if (-not (Test-Path $result)) { taskkill /im tts_pcm_example.exe /f 2>$null; throw 'no result' }
Copy-Item $result (Join-Path $lab 'build\windows-result.json') -Force
Write-Host "result=$(Join-Path $lab 'build\windows-result.json')"
