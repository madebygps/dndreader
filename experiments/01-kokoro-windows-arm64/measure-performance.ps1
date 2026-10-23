param(
    [ValidateRange(1, 128)]
    [int]$Threads = 2
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
$project = Join-Path $PSScriptRoot 'performance\KokoroPerformance.csproj'
& $dotnet build $project --configuration Release --nologo --verbosity quiet
if ($LASTEXITCODE -ne 0) { throw 'C# benchmark build failed.' }
& $dotnet (Join-Path $PSScriptRoot 'performance\bin\Release\net10.0\KokoroPerformance.dll') $assets $Threads
if ($LASTEXITCODE -ne 0) { throw 'C# performance measurement failed.' }
