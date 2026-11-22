$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$scripts = @(Get-ChildItem -LiteralPath $repoRoot -Recurse -Filter '*.ps1' -File | Where-Object { $_.FullName -notmatch '[\\/]dist[\\/]' })
foreach ($scriptFile in $scripts) {
    $tokens = $null; $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName,[ref]$tokens,[ref]$parseErrors)
    if ($parseErrors.Count -gt 0) { throw "PowerShell parse failure: $($scriptFile.Name): $($parseErrors.Message -join '; ')" }
}
$appPath = Join-Path $repoRoot 'src\Plan.ps1'
$source = [IO.File]::ReadAllText($appPath)
if ($source -match 'TomorrowPlan-2026|Local\\Vito|Ігор|Німеччин|C:\\Users\\Vito') { throw 'Personal prototype data was found in the public source.' }
foreach ($name in @('completed.json','appearance.json','notes.json')) {
    if (Test-Path -LiteralPath (Join-Path $repoRoot "src\$name")) { throw "Local state must not ship in src: $name" }
}
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testDirectory = Join-Path $tempBase ('lofi-planner-check-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDirectory | Out-Null
try {
    $isolatedApp = Join-Path $testDirectory 'Plan.ps1'
    Copy-Item -LiteralPath $appPath -Destination $isolatedApp
    & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File $isolatedApp -Verify
    if ($LASTEXITCODE -ne 0) { throw "Planner verification exited with $LASTEXITCODE" }
    'PASS: PowerShell syntax, personal-data boundary, isolated WPF behavior verification'
} finally {
    $resolved = [IO.Path]::GetFullPath($testDirectory)
    if (-not $resolved.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'lofi-planner-check-*') { throw 'Refusing cleanup outside the test directory' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
