param(
    [ValidateRange(1, 256)]
    [int]$Threads = 6,
    [string]$PromptFile = (Join-Path $PSScriptRoot 'passage-question.txt'),
    [string]$RunDirectory
)

$ErrorActionPreference = 'Stop'

$assetsDirectory = Join-Path $PSScriptRoot 'assets'
$executable = Join-Path $assetsDirectory 'llama-b11838\llama-cli.exe'
$model = Join-Path $assetsDirectory 'Qwen3-4B-Q4_K_M.gguf'
foreach ($path in @($executable, $model, $PromptFile)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing $path. Run setup.ps1 first."
    }
}

if (-not $RunDirectory) {
    $RunDirectory = Join-Path $assetsDirectory ('runs\' + [guid]::NewGuid().ToString('N'))
}
New-Item -ItemType Directory -Path $RunDirectory | Out-Null
$answerPath = Join-Path $runDirectory 'answer.txt'
$diagnosticsPath = Join-Path $runDirectory 'diagnostics.txt'
$stderrPath = Join-Path $runDirectory 'stderr.txt'
$arguments = @(
    '--model', $model,
    '--file', $PromptFile,
    '--system-prompt', 'Answer only from the supplied passage. If information is absent, say the passage does not provide it. Keep the answer concise.',
    '--gpu-layers', '0',
    '--threads', "$Threads",
    '--threads-batch', "$Threads",
    '--ctx-size', '4096',
    '--predict', '256',
    '--seed', '42',
    '--temp', '0',
    '--reasoning', 'off',
    '--offline',
    '--single-turn',
    '--simple-io',
    '--color', 'off',
    '--no-display-prompt',
    '--log-file', $diagnosticsPath,
    '--log-verbosity', '3',
    '--perf'
)

$timer = [System.Diagnostics.Stopwatch]::StartNew()
& $executable @arguments 1> $answerPath 2> $stderrPath
$exitCode = $LASTEXITCODE
$timer.Stop()
if ($exitCode -ne 0) {
    Get-Content -LiteralPath $stderrPath
    throw "llama-cli exited with code $exitCode. Run files: $runDirectory"
}

Get-Content -LiteralPath $answerPath
Write-Host "Process elapsed seconds: $($timer.Elapsed.TotalSeconds.ToString('F3'))"
Write-Host "Answer and runtime diagnostics: $runDirectory"
