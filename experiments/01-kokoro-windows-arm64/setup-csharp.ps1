$ErrorActionPreference = 'Stop'
$assets = Join-Path $PSScriptRoot 'assets'
$sdkDirectory = Join-Path $assets 'dotnet'
$archive = Join-Path $assets 'dotnet-sdk-10.0.402-win-arm64.zip'
$expectedHash = 'd736fefa5c089ed5e1e854e1c07e5686e1e22638d627f6797633b92b60b1b5daddb607650be07c9f178cdbed1a944646c1a5cf3f12fb6aeef7c8cf149c9ba328'
New-Item -ItemType Directory -Path $assets -Force | Out-Null
if (-not (Test-Path -LiteralPath $archive)) {
    & curl.exe --fail --location --silent --show-error --retry 3 `
        --output "$archive.partial" `
        'https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.402/dotnet-sdk-10.0.402-win-arm64.zip'
    if ($LASTEXITCODE -ne 0) { throw 'SDK download failed.' }
    if ((Get-FileHash "$archive.partial" -Algorithm SHA512).Hash -ne $expectedHash) {
        throw 'SDK download SHA-512 mismatch.'
    }
    Move-Item -LiteralPath "$archive.partial" -Destination $archive
}
if ((Get-FileHash $archive -Algorithm SHA512).Hash -ne $expectedHash) {
    throw 'SDK archive SHA-512 mismatch.'
}
New-Item -ItemType Directory -Path $sdkDirectory -Force | Out-Null
& tar.exe -xf $archive -C $sdkDirectory
if ($LASTEXITCODE -ne 0) { throw 'SDK extraction failed.' }

$bindings = Join-Path $assets 'sherpa-csharp-v1.13.8'
New-Item -ItemType Directory -Path $bindings -Force | Out-Null
$files = @(
    'Dll.cs', 'OfflineTts.cs', 'OfflineTtsConfig.cs', 'OfflineTtsGeneratedAudio.cs',
    'OfflineTtsGenerationConfig.cs', 'OfflineTtsKittenModelConfig.cs',
    'OfflineTtsKokoroModelConfig.cs', 'OfflineTtsMatchaModelConfig.cs',
    'OfflineTtsModelConfig.cs', 'OfflineTtsPocketModelConfig.cs',
    'OfflineTtsSupertonicModelConfig.cs', 'OfflineTtsVitsModelConfig.cs',
    'OfflineTtsZipVoiceModelConfig.cs'
)
foreach ($file in $files) {
    & curl.exe --fail --location --silent --show-error --retry 3 `
        --output (Join-Path $bindings $file) `
        "https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/v1.13.8/scripts/dotnet/$file"
    if ($LASTEXITCODE -ne 0) { throw "Binding download failed: $file" }
}
& curl.exe --fail --location --silent --show-error `
    --output (Join-Path $bindings 'LICENSE') `
    'https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/v1.13.8/LICENSE'
if ($LASTEXITCODE -ne 0) { throw 'Binding license download failed.' }
Get-ChildItem $bindings -File | Get-FileHash -Algorithm SHA256 |
    Select-Object @{Name='File';Expression={Split-Path $_.Path -Leaf}},Hash |
    ConvertTo-Json | Set-Content (Join-Path $bindings 'hashes.json')
& (Join-Path $sdkDirectory 'dotnet.exe') --version
if ($LASTEXITCODE -ne 0) { throw 'Local SDK did not start.' }
