$ErrorActionPreference = 'Stop'

$text = 'The reading group met on October 16, 2026. We reviewed 1,250 commits from 32 developers, and the test took 3.5 seconds. The monthly budget was $24.99, with 15% reserved for storage. Dr. Chen asked whether the CPU could run an ARM64 model through an API without a GPU. We compared Git repositories, concurrent workloads, neural networks, and asynchronous requests. After a brief pause, the narrator asked: "Which version should we deploy?"'

$voices = @(
    @{ Name = 'af_heart'; Id = 3 }
    @{ Name = 'af_bella'; Id = 2 }
    @{ Name = 'am_michael'; Id = 16 }
    @{ Name = 'am_fenrir'; Id = 14 }
)

foreach ($voice in $voices) {
    Write-Host "Generating $($voice.Name), speaker ID $($voice.Id)..."
    & (Join-Path $PSScriptRoot 'first-sentence.ps1') `
        -Text $text -SpeakerId $voice.Id -RunName $voice.Name
}
