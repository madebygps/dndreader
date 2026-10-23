$ErrorActionPreference = 'Stop'

$assetsDirectory = Join-Path $PSScriptRoot 'assets'
New-Item -ItemType Directory -Path $assetsDirectory -Force | Out-Null

$assets = @(
    @{
        Name = 'sherpa-onnx-v1.13.8-win-arm64-shared-MD-Release'
        Url = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.13.8/sherpa-onnx-v1.13.8-win-arm64-shared-MD-Release.tar.bz2'
        Sha256 = '40fd749779c41e357c4a1382b071970999d4828ceb50b133b1643878ca08ead8'
    },
    @{
        Name = 'kokoro-multi-lang-v1_0'
        Url = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_0.tar.bz2'
        Sha256 = 'c5f7e2d2caf082bc1d20fb70334a61d99d20b484500aad32e7cf84c128ea3298'
    }
)

foreach ($asset in $assets) {
    $archive = Join-Path $assetsDirectory "$($asset.Name).tar.bz2"
    if (-not (Test-Path -LiteralPath $archive)) {
        $partial = "$archive.partial"
        Write-Host "Downloading $($asset.Name)..."
        & curl.exe --fail --location --silent --show-error --retry 3 --output $partial $asset.Url
        if ($LASTEXITCODE -ne 0) {
            throw "Download failed: $($asset.Url). Any partial download remains at $partial."
        }
        $actualHash = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash
        if ($actualHash -ne $asset.Sha256) {
            throw "SHA-256 mismatch for $partial. Expected $($asset.Sha256); got $actualHash."
        }
        Move-Item -LiteralPath $partial -Destination $archive
    }

    $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    if ($actualHash -ne $asset.Sha256) {
        throw "SHA-256 mismatch for $archive. Expected $($asset.Sha256); got $actualHash."
    }

    Write-Host "Extracting $($asset.Name)..."
    & tar.exe -xf $archive -C $assetsDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Extraction failed: $archive."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $assetsDirectory $asset.Name) -PathType Container)) {
        throw "Expected extracted directory not found: $($asset.Name)."
    }
    Write-Host "Ready: $($asset.Name) (SHA-256 verified)"
}
