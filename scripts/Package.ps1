param([string]$Version = 'dev')
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^(dev|v?\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?)$') { throw 'Use dev or a semantic version such as v0.1.0' }
$repoRoot = Split-Path $PSScriptRoot -Parent
$dist = Join-Path $repoRoot 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$zipPath = Join-Path $dist "Lofi-custom-planner-$Version-windows.zip"
$appPath = Join-Path $repoRoot 'src\Plan.ps1'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
$zip = [IO.Compression.ZipFile]::Open($zipPath,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($entry in @(@{Source=$appPath;Name='src/Plan.ps1'},@{Source=(Join-Path $repoRoot 'Run.ps1');Name='Run.ps1'},@{Source=(Join-Path $repoRoot 'README.md');Name='README.md'},@{Source=(Join-Path $repoRoot 'CHANGELOG.md');Name='CHANGELOG.md'})) {
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$entry.Source,$entry.Name)
    }
} finally { $zip.Dispose() }
$archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    if ($archive.Entries.Count -ne 4 -or @($archive.Entries | Where-Object { $_.FullName -match '(completed|appearance|notes)\.json' }).Count -gt 0) { throw 'Unexpected or private content in the release ZIP' }
} finally { $archive.Dispose() }
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($zipPath + '.sha256', ($hash + '  ' + [IO.Path]::GetFileName($zipPath) + [Environment]::NewLine),[Text.UTF8Encoding]::new($false))
"PASS: release package with 4 allowlisted files and SHA256: $zipPath"
