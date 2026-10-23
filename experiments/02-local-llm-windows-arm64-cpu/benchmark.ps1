#Requires -Version 7.0
param(
    [ValidateRange(1, 256)]
    [int]$Threads = 6,
    [ValidateRange(2, 20)]
    [int]$Requests = 3
)

$ErrorActionPreference = 'Stop'
$assets = Join-Path $PSScriptRoot 'assets'
$executable = Join-Path $assets 'llama-b11838\llama-server.exe'
$model = Join-Path $assets 'Qwen3-4B-Q4_K_M.gguf'
$promptFile = Join-Path $PSScriptRoot 'passage-question.txt'
foreach ($path in @($executable, $model, $promptFile)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing $path. Run setup.ps1 first."
    }
}

$runDirectory = Join-Path $assets ('runs\benchmark-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
Copy-Item -LiteralPath $promptFile -Destination (Join-Path $runDirectory 'prompt.txt')
$apiKey = [guid]::NewGuid().ToString('N')
$server = [System.Diagnostics.Process]::new()
$server.StartInfo.FileName = $executable
$server.StartInfo.UseShellExecute = $false
$server.StartInfo.RedirectStandardOutput = $true
$server.StartInfo.RedirectStandardError = $true
$arguments = @(
    '--model', $model, '--gpu-layers', '0',
    '--threads', "$Threads", '--threads-batch', "$Threads",
    '--ctx-size', '4096', '--parallel', '1',
    '--predict', '256', '--seed', '42', '--temp', '0',
    '--reasoning', 'off', '--offline', '--no-cache-prompt',
    '--host', '127.0.0.1', '--port', '0',
    '--api-key', $apiKey, '--cors-origins', 'http://127.0.0.1',
    '--no-cors-credentials', '--no-webui',
    '--log-file', (Join-Path $runDirectory 'server.log'), '--log-verbosity', '3'
)
foreach ($argument in $arguments) { $server.StartInfo.ArgumentList.Add($argument) }
$handler = [System.Net.Http.HttpClientHandler]::new()
$handler.UseProxy = $false
$client = [System.Net.Http.HttpClient]::new($handler)
$client.Timeout = [TimeSpan]::FromSeconds(120)
$client.DefaultRequestHeaders.Authorization =
    [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $apiKey)
$startupTimer = [System.Diagnostics.Stopwatch]::new()
$memory = @{ PeakWorkingSet = 0L; PeakPrivateBytes = 0L }
$started = $false

function Update-Memory {
    $server.Refresh()
    if ($server.HasExited) { throw "Benchmark server exited with code $($server.ExitCode)." }
    $memory.PeakWorkingSet = [Math]::Max($memory.PeakWorkingSet, $server.PeakWorkingSet64)
    $memory.PeakPrivateBytes = [Math]::Max($memory.PeakPrivateBytes, $server.PrivateMemorySize64)
}

function Wait-Task($Task) {
    while (-not $Task.IsCompleted) {
        Update-Memory
        if ($startupTimer.Elapsed.TotalSeconds -gt 180) { throw 'Benchmark exceeded its 180-second limit.' }
        Start-Sleep -Milliseconds 10
    }
    Update-Memory
    $Task.GetAwaiter().GetResult()
}

try {
    $startupTimer.Start()
    if (-not $server.Start()) { throw 'Could not start benchmark server.' }
    $started = $true
    $stdoutTask = $server.StandardOutput.ReadToEndAsync()
    $stderrTask = $server.StandardError.ReadToEndAsync()
    $endpoint = $null
    while (-not $endpoint) {
        Update-Memory
        if ($startupTimer.Elapsed.TotalSeconds -gt 120) { throw 'Server readiness timed out.' }
        $logPath = Join-Path $runDirectory 'server.log'
        if (Test-Path -LiteralPath $logPath) {
            $log = Get-Content -LiteralPath $logPath -Raw
            $match = [regex]::Match($log, 'listening on (http://127\.0\.0\.1:\d+)')
            if ($match.Success) { $endpoint = $match.Groups[1].Value }
        }
        if (-not $endpoint) { Start-Sleep -Milliseconds 20 }
    }
    $healthResponse = Wait-Task ($client.GetAsync("$endpoint/health"))
    try {
        [void]$healthResponse.EnsureSuccessStatusCode()
    } finally { $healthResponse.Dispose() }
    $readyMs = $startupTimer.Elapsed.TotalMilliseconds
    $server.Refresh()
    $startup = [ordered]@{
        ProcessStartToHealthyMs = $readyMs
        PeakWorkingSetBytes = $memory.PeakWorkingSet
        SampledPeakPrivateBytes = $memory.PeakPrivateBytes
        ReadyWorkingSetBytes = $server.WorkingSet64
    }
    $results = @()
    for ($index = 1; $index -le $Requests; $index++) {
        $memory.PeakWorkingSet = 0L
        $memory.PeakPrivateBytes = 0L
        $payload = @{
            messages = @(
                @{ role = 'system'; content = 'Answer only from the supplied passage. If information is absent, say the passage does not provide it. Keep the answer concise.' },
                @{ role = 'user'; content = (Get-Content -LiteralPath $promptFile -Raw) }
            )
            stream = $true
            stream_options = @{ include_usage = $true }
            cache_prompt = $false
            temperature = 0
            seed = 42
            max_tokens = 256
        } | ConvertTo-Json -Depth 8
        $request = [System.Net.Http.HttpRequestMessage]::new(
            [System.Net.Http.HttpMethod]::Post, "$endpoint/v1/chat/completions")
        $request.Content = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, 'application/json')
        $response = $null
        $reader = $null
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        $firstContentMs = $null
        $answer = [System.Text.StringBuilder]::new()
        $events = [System.Collections.Generic.List[string]]::new()
        $finishReason = $null
        $timings = $null
        $usage = $null
        $done = $false
        try {
            $response = Wait-Task ($client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead))
            [void]$response.EnsureSuccessStatusCode()
            $stream = Wait-Task ($response.Content.ReadAsStreamAsync())
            $reader = [System.IO.StreamReader]::new($stream)
            while ($null -ne ($line = Wait-Task ($reader.ReadLineAsync()))) {
                $events.Add($line)
                if (-not $line.StartsWith('data: ')) { continue }
                $data = $line.Substring(6)
                if ($data -eq '[DONE]') { $done = $true; break }
                $event = $data | ConvertFrom-Json
                if ($event.error) { throw ($event.error | ConvertTo-Json -Compress) }
                foreach ($choice in $event.choices) {
                    if ($choice.delta.reasoning_content) { throw 'Unexpected reasoning output with thinking disabled.' }
                    if ($choice.delta.content) {
                        if ($null -eq $firstContentMs) { $firstContentMs = $timer.Elapsed.TotalMilliseconds }
                        [void]$answer.Append($choice.delta.content)
                    }
                    if ($choice.finish_reason) { $finishReason = $choice.finish_reason }
                }
                if ($event.timings) { $timings = $event.timings }
                if ($event.usage) { $usage = $event.usage }
            }
            $timer.Stop()
            if (-not $done -or $null -eq $firstContentMs -or $finishReason -ne 'stop' -or
                -not $timings -or -not $usage) {
                throw "Incomplete streaming response in request $index (finish reason: $finishReason)."
            }
        } finally {
            $events | Set-Content -LiteralPath (Join-Path $runDirectory "request-$index.sse") -Encoding utf8
            if ($reader) { $reader.Dispose() }
            if ($response) { $response.Dispose() }
            $request.Dispose()
        }
        $result = [ordered]@{
            Request = $index
            ModelState = $(if ($index -eq 1) { 'First request after startup' } else { 'Resident model; no prompt-cache reuse' })
            FirstContentMs = $firstContentMs
            RequestTotalMs = $timer.Elapsed.TotalMilliseconds
            ProcessLifetimePeakWorkingSetBytes = $memory.PeakWorkingSet
            SampledPeakPrivateBytes = $memory.PeakPrivateBytes
            Usage = $usage
            Timings = $timings
            Answer = $answer.ToString()
        }
        $results += $result
        $result | ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath (Join-Path $runDirectory "request-$index.json") -Encoding utf8
        Write-Host ("Request {0}: first content {1:F1} ms; total {2:F1} ms; generation {3:F2} tokens/s" -f
            $index, $firstContentMs, $timer.Elapsed.TotalMilliseconds, $timings.predicted_per_second)
    }
    [ordered]@{
        Runtime = 'llama.cpp b11838 (4231b23dc), Windows CPU ARM64'
        Model = 'Qwen3-4B-Q4_K_M.gguf'
        Threads = $Threads
        ContextTokens = 4096
        PromptCaching = $false
        Startup = $startup
        Requests = $results
        SampleIntervalMs = 10
        Limitations = 'No OS cache flush; default startup warmup enabled. First content chunk is client-observed TTFT proxy, not an exact tokenizer event. Working-set peak is process lifetime; private-byte peak is sampled. Other running processes are not controlled.'
    } | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath (Join-Path $runDirectory 'results.json') -Encoding utf8
    Write-Host ("Process start to healthy: {0:F1} ms" -f $readyMs)
    Write-Host "Saved benchmark: $runDirectory"
} finally {
    $client.Dispose()
    if ($started -and -not $server.HasExited) {
        $server.Kill($true)
        $server.WaitForExit()
    }
    if ($stdoutTask) {
        $stdoutTask.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $runDirectory 'stdout.txt')
        $stderrTask.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $runDirectory 'stderr.txt')
    }
    $server.Dispose()
}
