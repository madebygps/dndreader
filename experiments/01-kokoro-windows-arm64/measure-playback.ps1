param(
    [ValidateRange(1, 128)]
    [int]$Threads = 3,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$assets = Join-Path $PSScriptRoot 'assets'
$dotnet = Join-Path $assets 'dotnet\dotnet.exe'
if (-not (Test-Path -LiteralPath $dotnet)) {
    throw 'Local .NET SDK was not found. Complete setup-csharp.ps1 first.'
}
$env:DOTNET_CLI_HOME = Join-Path $assets 'dotnet-home'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'
$env:NUGET_PACKAGES = Join-Path $assets 'nuget'
$project = Join-Path $PSScriptRoot 'playback\KokoroPlayback.csproj'
$program = Join-Path $PSScriptRoot 'playback\bin\Release\net10.0-windows\KokoroPlayback.dll'
if (-not $SkipBuild) {
    & $dotnet build $project --configuration Release --nologo --verbosity quiet
    if ($LASTEXITCODE -ne 0) { throw 'C# playback benchmark build failed.' }
}
if (-not (Test-Path -LiteralPath $program)) {
    throw 'Built playback program was not found. Run measure-playback.ps1 without -SkipBuild while online first.'
}
& $dotnet $program `
    $assets (Join-Path $PSScriptRoot 'playback\passage.txt') $Threads
if ($LASTEXITCODE -ne 0) { throw 'C# sustained playback measurement failed.' }
