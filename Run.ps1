$ErrorActionPreference = 'Stop'
$appPath = Join-Path $PSScriptRoot 'src\Plan.ps1'
if (-not (Test-Path -LiteralPath $appPath)) { throw 'src\Plan.ps1 was not found. Extract the complete release first.' }
$powershellExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
Start-Process -FilePath $powershellExe -ArgumentList ('-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $appPath + '"') -WindowStyle Hidden
