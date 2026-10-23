$ErrorActionPreference = 'Stop'

if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'Arm64' -or
    [System.Environment]::OSVersion.Platform -ne 'Win32NT') {
    throw 'This experiment requires Windows ARM64.'
}

$assetsDirectory = Join-Path $PSScriptRoot 'assets'
New-Item -ItemType Directory -Path $assetsDirectory -Force | Out-Null

$assets = @(
    @{
        Name = 'llama-b11838-bin-win-cpu-arm64.zip'
        Url = 'https://github.com/ggml-org/llama.cpp/releases/download/b11838/llama-b11838-bin-win-cpu-arm64.zip'
        Sha256 = '0318fc8e07fb1345015d23287e0b6ffcde7d1638d092449ac2795fd4a4614bb5'
    },
    @{
        Name = 'Qwen3-4B-Q4_K_M.gguf'
        Url = 'https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/bc640142c66e1fdd12af0bd68f40445458f3869b/Qwen3-4B-Q4_K_M.gguf'
        Sha256 = '7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5'
    }
)

foreach ($asset in $assets) {
    $destination = Join-Path $assetsDirectory $asset.Name
    if (-not (Test-Path -LiteralPath $destination)) {
        $partial = "$destination.partial"
        Write-Host "Downloading $($asset.Name)..."
        & curl.exe --fail --location --silent --show-error --retry 3 --output $partial $asset.Url
        if ($LASTEXITCODE -ne 0) {
            throw "Download failed: $($asset.Url). Any partial download remains at $partial."
        }
        $actualHash = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash
        if ($actualHash -ne $asset.Sha256) {
            throw "SHA-256 mismatch for $partial. Expected $($asset.Sha256); got $actualHash."
        }
        Move-Item -LiteralPath $partial -Destination $destination
    }

    $actualHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    if ($actualHash -ne $asset.Sha256) {
        throw "SHA-256 mismatch for $destination. Expected $($asset.Sha256); got $actualHash."
    }
    Write-Host "Ready: $($asset.Name) (SHA-256 verified)"
}

$runtimeDirectory = Join-Path $assetsDirectory 'llama-b11838'
Expand-Archive -LiteralPath (Join-Path $assetsDirectory $assets[0].Name) -DestinationPath $runtimeDirectory -Force
$executables = @(Get-ChildItem -LiteralPath $runtimeDirectory -Filter 'llama-cli.exe' -Recurse)
if ($executables.Count -ne 1) {
    throw "Expected one llama-cli.exe in $runtimeDirectory; found $($executables.Count)."
}

$binaries = Get-ChildItem -LiteralPath $executables[0].DirectoryName -File |
    Where-Object { $_.Extension -in '.exe', '.dll' }
foreach ($binary in $binaries) {
    $bytes = [System.IO.File]::ReadAllBytes($binary.FullName)
    $peOffset = [System.BitConverter]::ToInt32($bytes, 0x3c)
    $machine = [System.BitConverter]::ToUInt16($bytes, $peOffset + 4)
    if ($machine -ne 0xaa64) {
        throw "Not a native ARM64 binary: $($binary.Name) (PE machine 0x$($machine.ToString('x4')))."
    }
}

& $executables[0].FullName --version
if ($LASTEXITCODE -ne 0) {
    throw 'llama-cli failed to start. Check its diagnostics for missing runtime dependencies.'
}
Write-Host "Verified native ARM64 binaries in $($executables[0].DirectoryName)."
