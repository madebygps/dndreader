param(
    [ValidateRange(1, 256)]
    [int]$Threads = 6
)

$ErrorActionPreference = 'Stop'

$fixturePath = Join-Path $PSScriptRoot 'quality-cases.json'
$fixture = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
$suiteDirectory = Join-Path $PSScriptRoot ('assets\runs\quality-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $suiteDirectory | Out-Null
Copy-Item -LiteralPath $fixturePath -Destination (Join-Path $suiteDirectory 'quality-cases.json')

foreach ($case in $fixture.cases) {
    $promptFile = Join-Path $suiteDirectory "$($case.id)-prompt.txt"
    "Passage:`n$($fixture.passage)`n`nQuestion:`n$($case.question)" |
        Set-Content -LiteralPath $promptFile -Encoding utf8
    Write-Host "`nCase: $($case.id)"
    Write-Host "Review criteria: $($case.criteria)"
    & (Join-Path $PSScriptRoot 'smoke-test.ps1') -Threads $Threads -PromptFile $promptFile `
        -RunDirectory (Join-Path $suiteDirectory $case.id)
}

Write-Host "`nCompleted $($fixture.cases.Count) cases. Manual quality review is required; successful execution is not a quality pass."
Write-Host "Suite files: $suiteDirectory"
