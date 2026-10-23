param(
    [string]$Text = 'With developers and agents working concurrently in repositories that receive millions of commits a day, these workloads demand a different Git architecture.',
    [ValidateRange(0, 53)]
    [int]$SpeakerId = 3,
    [ValidatePattern('^[a-z0-9_-]+$')]
    [string]$RunName = 'first-sentence'
)

$ErrorActionPreference = 'Stop'

$assetsDirectory = Join-Path $PSScriptRoot 'assets'
$runtimeDirectory = Join-Path $assetsDirectory 'sherpa-onnx-v1.13.8-win-arm64-shared-MD-Release'
$modelDirectory = Join-Path $assetsDirectory 'kokoro-multi-lang-v1_0'
$executable = Join-Path $runtimeDirectory 'bin\sherpa-onnx-offline-tts.exe'

foreach ($path in @(
    $executable
    (Join-Path $runtimeDirectory 'bin\onnxruntime.dll')
    (Join-Path $modelDirectory 'model.onnx')
    (Join-Path $modelDirectory 'voices.bin')
    (Join-Path $modelDirectory 'tokens.txt')
    (Join-Path $modelDirectory 'espeak-ng-data')
    (Join-Path $modelDirectory 'lexicon-us-en.txt')
)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required asset was not found: $path"
    }
}

if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
        [System.Runtime.InteropServices.OSPlatform]::Windows
    ) -or [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'Arm64') {
    throw 'This smoke test requires a Windows ARM64 host.'
}

function Assert-Arm64Binary {
    param([string]$Path)

    $reader = [System.IO.BinaryReader]::new([System.IO.File]::OpenRead($Path))
    try {
    # Compare if first 2 bytes are equal to 0x5A4D
        if ($reader.ReadUInt16() -ne 0x5A4D) {
            throw "Missing DOS header: $Path"
        }
        # PE offset is 32 bits at 0x3C
        $reader.BaseStream.Position = 0x3C
        $peOffset = $reader.ReadInt32()
        # value less than 0x40 would overlap with DOS headers, greater than stream-6 would not have
        # enough space since 32 bits total
        if ($peOffset -lt 0x40 -or $peOffset -gt ($reader.BaseStream.Length - 6)) {
            throw "Invalid PE header offset: $Path"
        }
        # Compare if value is PE00
        $reader.BaseStream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) {
            throw "Missing PE signature: $Path"
        }
        # Next 16 bits contain machine architecture
        $machine = $reader.ReadUInt16()
        if ($machine -ne 0xAA64) {
            throw ('Expected ARM64 (0xAA64), found 0x{0:X4}: {1}' -f $machine, $Path)
        }
        Write-Output "ARM64 (0xAA64): $Path"
    }
    finally {
        $reader.Dispose()
    }
}

$outputDirectory = Join-Path $assetsDirectory ($RunName + '-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $outputDirectory | Out-Null
$audioFilePath = Join-Path $outputDirectory "$RunName.wav"
$generationLogPath = Join-Path $outputDirectory 'generation.log'
$architectureLogPath = Join-Path $outputDirectory 'architecture.log'

& {
    Assert-Arm64Binary -Path $executable
    Get-ChildItem -LiteralPath $runtimeDirectory -Recurse -Filter '*.dll' -File |
        ForEach-Object { Assert-Arm64Binary -Path $_.FullName }
} | Tee-Object -FilePath $architectureLogPath

$arguments = @(
    '--debug=0'
    '--provider=cpu'
    '--num-threads=2'
    "--sid=$SpeakerId"
    '--speed=1'
    "--kokoro-model=$(Join-Path $modelDirectory 'model.onnx')"
    "--kokoro-voices=$(Join-Path $modelDirectory 'voices.bin')"
    "--kokoro-tokens=$(Join-Path $modelDirectory 'tokens.txt')"
    "--kokoro-data-dir=$(Join-Path $modelDirectory 'espeak-ng-data')"
    "--kokoro-lexicon=$(Join-Path $modelDirectory 'lexicon-us-en.txt')"
    "--output-filename=$audioFilePath"
    $text
)
# run executable
& $executable @arguments 2>&1 | Tee-Object -FilePath $generationLogPath
if ($LASTEXITCODE -ne 0) {
    throw "Speech generation failed with exit code $LASTEXITCODE. See $generationLogPath"
}
if (-not (Test-Path -LiteralPath $audioFilePath -PathType Leaf)) {
    throw "No WAV was generated. See $generationLogPath"
}
$wave = [System.IO.File]::ReadAllBytes($audioFilePath)
# A basic PCM WAV header is 44 bytes, so a file containing only that header has no audio data.
if ($wave.Length -le 44 -or
    [System.Text.Encoding]::ASCII.GetString($wave, 0, 4) -ne 'RIFF' -or
    [System.Text.Encoding]::ASCII.GetString($wave, 8, 4) -ne 'WAVE') {
    throw "Output was not a nonempty RIFF/WAVE file: $audioFilePath"
}

Write-Host "WAV saved: $audioFilePath"
Write-Host 'Listening review is still required to confirm intelligible speech.'
