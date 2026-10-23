# 01: Kokoro on Windows ARM64

Status: complete; steps 1 through 7 complete. Three-thread CPU generation and playback worked during the user's offline test without application-buffer starvation. Dependencies: none.

## Question and success criteria

Can the complete Kokoro speech pipeline run natively on Windows ARM64 and produce natural offline narration fast enough for continuous reading?

Success means:

- The test process and native inference dependencies are ARM64, not x64 under emulation.
- Speech generation works with networking disabled after setup.
- Generation stays ahead of playback over a sustained passage at the selected playback speed.
- Voice quality is acceptable on ordinary prose, numbers, abbreviations, and technical vocabulary.
- Setup and invocation are reproducible.

Proposed performance target: real-time factor at or below 0.5 for a representative passage at normal playback speed. This is a project target, not an upstream performance claim.

## Current evidence

**Documented, checked 2026-10-16:**

- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) lists Windows ARM64 and C# support.
- [Release v1.13.8](https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.13.8) includes Windows ARM64 artifacts with TTS, including `sherpa-onnx-v1.13.8-win-arm64-shared-MD-Release.tar.bz2`. Avoid assets marked `no-tts`.
- [Kokoro integration documentation](https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html) describes model weights, voices, tokens, pronunciation resources, and speech generation.
- [Original Kokoro model card](https://huggingface.co/hexgrad/Kokoro-82M) describes Apache-licensed weights.

**Measured:** step 6 completed 191.912 seconds of actual playback with no
application-buffer starvation. Acoustic first-audio latency and audio-device
glitches were not instrumented; the user completed the offline test in step 7.
Local CLI listening feedback is recorded in steps 3 and 4, and C# generation
measurements in step 5.

## Environment

| Item | Value |
| --- | --- |
| Hardware | Snapdragon X Elite X1E80100, 12 logical processors; approximately 63.5 GiB OS-visible RAM |
| Windows build | Windows 11 Enterprise, build 26300 |
| .NET / toolchain | Repo-local .NET SDK 10.0.402, Windows ARM64; benchmark targeted net10.0 |
| Backend / thread count | CPU; baseline 2 threads, sustained playback 3 threads |

## Procedure

Complete and record each step before starting the next.

### Step 1: Runtime and model

- [x] Selected, pinned, and downloaded on 2026-10-16.

#### Selection and rationale

| Choice | Why |
| --- | --- |
| [sherpa-onnx v1.13.8 Windows ARM64 shared MD Release, with TTS](https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.13.8/sherpa-onnx-v1.13.8-win-arm64-shared-MD-Release.tar.bz2) | Provides a prebuilt native ARM64 CLI for the first smoke test and shared C API libraries for the later C# integration. Pinning the release and archive hash makes setup reproducible; local compatibility still needs testing. |
| [Kokoro v1.0](https://huggingface.co/hexgrad/Kokoro-82M) | Our baseline is English narration, and v1.0 offers a broader [English voice selection](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md). The newer release is [v1.1-zh](https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh): its model card describes 100 Chinese voices and three English voices, and explicitly says it is not a strict upgrade because it drops many previous voices. The official release listings do not identify a separate English-focused v1.1. |
| [Full-precision v1.0 bundle](https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_0.tar.bz2) on CPU | Chosen to establish voice quality and performance before introducing quantization as another variable. |

**Deferred:** we identified
[the int8 v1.0 bundle](https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-multi-lang-v1_0.tar.bz2) as a later comparison using the same text, voices, and settings.
The proposed measurements were model size, peak memory, generation time,
real-time factor, and audible quality.
Quantization reduces weight storage; speed and quality effects remain untested.

#### Setup performed

From the repository root in PowerShell, we ran the [setup script](../../experiments/01-kokoro-windows-arm64/setup.ps1):

```powershell
.\experiments\01-kokoro-windows-arm64\setup.ps1
```

The script used `curl.exe` and `tar.exe` to download and extract the official
release assets. It verified their SHA-256 hashes against the values recorded
from GitHub's release API. URLs and hashes were recorded under step 2.

We kept archives and extracted files under the gitignored
`experiments\01-kokoro-windows-arm64\assets\` directory, leaving only the setup
script and notes eligible for Git. 

### Step 2: Asset records and environment

- [x] Recorded asset URLs, hashes, a license caveat, and environment checks on 2026-10-16.

#### Asset records

| Asset | Source | Archive SHA-256 |
| --- | --- | --- |
| ARM64 runtime | [sherpa-onnx-v1.13.8-win-arm64-shared-MD-Release.tar.bz2](https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.13.8/sherpa-onnx-v1.13.8-win-arm64-shared-MD-Release.tar.bz2) | `40fd749779c41e357c4a1382b071970999d4828ceb50b133b1643878ca08ead8` |
| Kokoro model bundle | [kokoro-multi-lang-v1_0.tar.bz2](https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_0.tar.bz2) | `c5f7e2d2caf082bc1d20fb70334a61d99d20b484500aad32e7cf84c128ea3298` |

#### Licenses

We noted that the pipeline included
[GPL-3.0-or-later eSpeak NG](https://github.com/csukuangfj/espeak-ng/blob/ed530aa113046142eb5115cf2fc9157854d0ffe1/README.md#license-information),
so the stack was not Apache-only. A redistribution review covering compatible
licensing, required notices, and corresponding source was deferred to release
planning, before sharing app binaries.

#### Environment checked

| Item | Observed on 2026-10-16 |
| --- | --- |
| PowerShell | Version `7.6.7`. |
| Microsoft Visual C++ v14 ARM64 runtime | Registry entry showed `Installed=1`, version `v14.50.35719.00`. No installation or system change was needed. |
| ONNX Runtime | The bundled `bin\onnxruntime.dll` file version was `1.28.2`. |

### Step 3: Generate the first sentence

- [x] Generated one sentence to a WAV file using the native executable before integrating C#.
- [x] Confirmed an ARM64 host and ARM64 PE headers for the executable and all six bundled DLL files.
- [x] Listening review: the user confirmed intelligible speech and described the WAV as sounding "fantastic."

On 2026-10-16, we ran [first-sentence.ps1](../../experiments/01-kokoro-windows-arm64/first-sentence.ps1)
from the repository root:

```powershell
.\experiments\01-kokoro-windows-arm64\first-sentence.ps1
```

The script checked the binaries' machine type (`0xAA64`) before launching the
executable. Generation exited successfully using CPU, two threads, speaker ID 3
([`af_heart`](https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html)),
speed 1, and the US English lexicon.

We used this text:

> With developers and agents working concurrently in repositories that receive millions of commits a day, these workloads demand a different Git architecture.

The [generated WAV](../../experiments/01-kokoro-windows-arm64/assets/first-sentence-5a5485402b0e4edbae109eddfc191c0c/first-sentence.wav)
contained 8.772 seconds of mono, 24 kHz, 16-bit PCM audio (421,082 bytes), with
nonzero audio samples. The script saved `architecture.log` and `generation.log`
beside it in the ignored output directory. 

### Step 4: Evaluate voices and pronunciation

- [x] Generated the same passage with four US English voices.
- [x] User listened to all four samples and reported that they all sounded great; no preferred voice or specific pronunciation issues were reported.

On 2026-10-16, we ran [compare-voices.ps1](../../experiments/01-kokoro-windows-arm64/compare-voices.ps1).
It reused the first-sentence script, which we extended with optional text,
speaker ID, and output-name parameters; its original defaults were unchanged.
All four generations succeeded using CPU, two threads, speed 1, and the US
English lexicon.

We used this original passage for each voice:

> The reading group met on October 16, 2026. We reviewed 1,250 commits from 32 developers, and the test took 3.5 seconds. The monthly budget was $24.99, with 15% reserved for storage. Dr. Chen asked whether the CPU could run an ARM64 model through an API without a GPU. We compared Git repositories, concurrent workloads, neural networks, and asynchronous requests. After a brief pause, the narrator asked: "Which version should we deploy?"

| Voice | Speaker ID | Local WAV | Duration | Listening feedback |
| --- | --- | --- | --- | --- |
| `af_heart` | 3 | [Listen](../../experiments/01-kokoro-windows-arm64/assets/af_heart-5fa4a0c5e2464a10896ee5183f292119/af_heart.wav) | 31.298 s | Sounded great to the user |
| `af_bella` | 2 | [Listen](../../experiments/01-kokoro-windows-arm64/assets/af_bella-59f188f924204e18b4578393f051feb2/af_bella.wav) | 32.608 s | Sounded great to the user |
| `am_michael` | 16 | [Listen](../../experiments/01-kokoro-windows-arm64/assets/am_michael-a94c2e1b951a4e958fefa3116218f6e5/am_michael.wav) | 34.629 s | Sounded great to the user |
| `am_fenrir` | 14 | [Listen](../../experiments/01-kokoro-windows-arm64/assets/am_fenrir-420df670f65045cc91834442d0c891c6/am_fenrir.wav) | 34.477 s | Sounded great to the user |

Each ignored output folder contained its WAV, architecture log, and generation
log. Listening feedback was an overall subjective assessment, not a
word-by-word pronunciation audit.

The downloaded bundle's README described 54
voices, while the [sherpa-onnx documentation](https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html)
listed 53. The four speaker IDs above generated audio successfully; we did not
test the complete voice inventory.

### Step 5: Integrate with C# and measure generation performance

- [x] Set up the Windows ARM64 .NET SDK and sherpa-onnx C# integration.
- [x] Generated speech through C# using the selected runtime and model.
- [x] Measured fresh-process model loading separately from first and repeated warm generations, keeping the same model loaded within each process.
- [x] Recorded generation time, audio duration, real-time factor, and peak process memory across repeated trials.

#### Measurements

We started by running [setup-csharp.ps1](../../experiments/01-kokoro-windows-arm64/setup-csharp.ps1):

This downloaded .NET SDK 10.0.402 for Windows ARM64, verified its SHA-512 against
[Microsoft's release metadata](https://builds.dotnet.microsoft.com/dotnet/release-metadata/10.0/releases.json),
and downloaded the unmodified sherpa-onnx
[v1.13.8 C# TTS bindings](https://github.com/k2-fsa/sherpa-onnx/tree/v1.13.8/scripts/dotnet)
with their license and locally recorded SHA-256 hashes.

Then, because the sherpa CLI exits after each generation, we ran
[measure-performance.ps1](../../experiments/01-kokoro-windows-arm64/measure-performance.ps1)
to build and launch the C# benchmark in Release mode for ARM64:

The build succeeded with 14 nullable-analysis warnings from the upstream bindings.
Settings were CPU, two threads, `af_heart` (speaker ID 3), speed 1, full precision,
and the US English lexicon, with upstream defaults of one sentence per chunk and
silence scale 0.2.

[Program.cs](../../experiments/01-kokoro-windows-arm64/performance/Program.cs):

1. Launched three worker processes sequentially, recording their IDs, start times,
   and ARM64 architecture. Each worker separately timed loading the pinned native
   DLLs and creating an `OfflineTts` engine with the model.
2. Timed three `Generate` calls per worker using the step 4 passage: first, warm,
   and warm, keeping the same engine loaded. It calculated audio duration as
   sample count divided by sample rate, and RTF as generation time divided by
   audio duration. WAV saving and audio disposal were outside the generation
   timer; each worker saved the first audio result and freed each result before
   the next call.
3. Recorded each worker's peak process working set, including .NET, native
   libraries, model, and buffers, then saved the measurements and disposed the
   engine. The parent saved logs, combined results into
   [summary.json](../../experiments/01-kokoro-windows-arm64/assets/csharp-performance-69a7c86bdeee4c13b3f72e193c60b065/summary.json),
   and calculated the warm RTF minimum, median, maximum, and target check.

Here are the results:

| Fresh-process trial | DLL load | Engine load | Peak process working set |
| --- | --- | --- | --- |
| 1 | 0.114 s | 1.223 s | 695.0 MiB |
| 2 | 0.004 s | 1.302 s | 694.7 MiB |
| 3 | 0.006 s | 1.474 s | 694.7 MiB |

| Trial / generation | Generation time | Audio duration | RTF |
| --- | --- | --- | --- |
| 1 / first | 17.574 s | 31.298 s | 0.562 |
| 1 / warm 1 | 16.641 s | 31.299 s | 0.532 |
| 1 / warm 2 | 16.463 s | 31.295 s | 0.526 |
| 2 / first | 16.739 s | 31.289 s | 0.535 |
| 2 / warm 1 | 17.106 s | 31.296 s | 0.547 |
| 2 / warm 2 | 18.171 s | 31.295 s | 0.581 |
| 3 / first | 17.490 s | 31.294 s | 0.559 |
| 3 / warm 1 | 17.742 s | 31.296 s | 0.567 |
| 3 / warm 2 | 17.686 s | 31.295 s | 0.565 |

**Result:** six warm calls had median RTF 0.556, range 0.526-0.581.
None met the proposed 0.5 target. All were below 1, so generation was faster than
normal-speed playback for this passage, without proving sustained playback.

All three WAVs passed basic RIFF/WAVE checks at 24 kHz. The first
[C# WAV](../../experiments/01-kokoro-windows-arm64/assets/csharp-performance-69a7c86bdeee4c13b3f72e193c60b065/trial-1.wav)
was reviewed by the user, who said it sounded good.

#### CPU thread-count comparison

We repeated the measurement with 1, 2, 4, and 6 CPU threads, in that order,
keeping the passage and other settings unchanged. Each setting used three fresh
processes with one first generation and two warm generations per process, as
above; no additional warm-up calls were added. We reran two threads rather than
reusing the earlier baseline.

```powershell
foreach ($threads in 1, 2, 4, 6) {
    .\experiments\01-kokoro-windows-arm64\measure-performance.ps1 -Threads $threads
}
```

We then tested three threads using the same trial structure:

```powershell
.\experiments\01-kokoro-windows-arm64\measure-performance.ps1 -Threads 3
```

The user confirmed Windows power mode was set to Best performance.
`powercfg /getactivescheme` reported the underlying Balanced power plan, which is
distinct from power mode; external power was reported at the start and end.
Background load and temperature were not controlled, so this remained an
exploratory comparison rather than a controlled benchmark.

| CPU threads / results | Warm RTF minimum | Warm RTF median | Warm RTF maximum | Warm calls at or below 0.5 |
| --- | --- | --- | --- | --- |
| [1](../../experiments/01-kokoro-windows-arm64/assets/csharp-performance-48e7a3f97fb44deab154aea07ff6ea4c/summary.json) | 0.776 | 0.790 | 0.818 | 0 / 6 |
| [2](../../experiments/01-kokoro-windows-arm64/assets/csharp-performance-d5ca1cb462b64b6bbb8da867bcbf812b/summary.json) | 0.520 | 0.526 | 0.531 | 0 / 6 |
| [3](../../experiments/01-kokoro-windows-arm64/assets/csharp-performance-cf8099e78ef24f95a75bd4ba9b187cd4/summary.json) | 0.407 | 0.441 | 0.471 | 6 / 6 |
| [4](../../experiments/01-kokoro-windows-arm64/assets/csharp-performance-d615e65332ad4082b9f2e1211c8423e0/summary.json) | 0.396 | 0.403 | 0.410 | 6 / 6 |
| [6](../../experiments/01-kokoro-windows-arm64/assets/csharp-performance-24a6a237904848068fc5015669fc0b19/summary.json) | 0.366 | 0.379 | 0.391 | 6 / 6 |

Three, four, and six threads met the target in every measured warm call.
Three was the lowest tested count to do so. Six had the
lowest median RTF of the settings tested. We used three threads for step 6.

### Step 6: Measure sustained playback headroom

- [x] Generated a longer passage in sentence-sized chunks and measured queue headroom during actual audio playback.

#### Measurements

We ran [measure-playback.ps1](../../experiments/01-kokoro-windows-arm64/measure-playback.ps1):

```powershell
.\experiments\01-kokoro-windows-arm64\measure-playback.ps1 -Threads 3
```

It built and launched a separate [C# playback prototype](../../experiments/01-kokoro-windows-arm64/playback/Program.cs),
using [NAudio 2.2.1](https://www.nuget.org/packages/NAudio/2.2.1)
for Windows WASAPI shared-mode playback through the default speakers.
Packages stayed in the ignored local NuGet cache.

Settings were CPU, three threads, `af_heart`, speed 1, and the same full-precision
model and US lexicon as step 5. The original
[passage](../../experiments/01-kokoro-windows-arm64/playback/passage.txt)
contained 35 sentence lines, each used as one generation chunk.

1. Loaded one engine and generated the first sentence before starting playback,
   with no warm-up or additional prebuffering.
2. Generated the remaining sentences while the audio thread consumed the
   [queue](../../experiments/01-kokoro-windows-arm64/playback/MeasuredAudioQueue.cs).
   Headroom was the duration of samples still in that application queue, excluding
   samples already handed to Windows. Reads that needed unavailable samples
   would insert silence and record its duration and starvation episode count.
3. Let the final audio drain, verified every generated sample was consumed, and
   saved per-chunk timing, headroom, and totals to the ignored
   [summary.json](../../experiments/01-kokoro-windows-arm64/assets/csharp-playback-4d50cc7448aa494abb5eec31aabdd2fe/summary.json).
   Normal final draining was not counted as starvation or minimum production headroom.

| Measurement | Result |
| --- | --- |
| Generated and consumed audio | 191.912 s (3 min 11.9 s) |
| Total generation time | 78.135 s |
| Aggregate generation RTF | 0.407 |
| First PCM read by playback, from initialization start | 4.866 s |
| Minimum queued headroom while producing | 3.328 s |
| Maximum queued headroom | 116.931 s |
| Application-buffer starvation episodes | 0 |
| Silence inserted for starvation | 0.000 s |
| Peak process working set | 755.7 MiB |

Generation stayed ahead of playback throughout this run. The queue was uncapped,
so production finished after 79.752 seconds from initialization and the remaining
audio drained afterward; this was not continuous synthesis for the full playback
duration. The startup clock excluded build and process launch, and the first PCM
read measured software delivery, not the instant sound reached the listener.
No acoustic recording or device-glitch trace was taken.

### Step 7: Verify offline operation

- [x] Repeated with network access disabled after all assets were installed.

#### Procedure

1. While online, open PowerShell in this worktree and confirm the existing build
   is ready:

   ```powershell
   Set-Location 'C:\Users\gwynethp\.copilot\repos\copilot-worktrees\dndreader\madebygps-stunning-umbrella'
   .\experiments\01-kokoro-windows-arm64\assets\dotnet\dotnet.exe .\experiments\01-kokoro-windows-arm64\playback\bin\Release\net10.0-windows\KokoroPlayback.dll --self-test
   ```

   Expected: `Audio queue checks passed`. This checks the built program without
   playing audio. If the build is missing, run `measure-playback.ps1` without
   `-SkipBuild` while online to build it and restore dependencies.

2. Enable airplane mode, keep Wi-Fi off, and disconnect Ethernet, USB tethering,
   or any other internet connection. Use the laptop speakers or wired headphones,
   since airplane mode can also disable Bluetooth.

3. In the same PowerShell window, run:

   ```powershell
   $log = Join-Path $PWD ("experiments\01-kokoro-windows-arm64\assets\offline-test-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
   Start-Transcript -Path $log
   try {
       .\experiments\01-kokoro-windows-arm64\measure-playback.ps1 -Threads 3 -SkipBuild
   }
   finally {
       Stop-Transcript
   }
   Write-Host "Saved console log: $log"
   ```

   `-SkipBuild` launches the already-built program directly: no build, package
   restore, or download. It generates new audio from the passage and local model;
   it does not replay a saved recording. Allow about three minutes for playback
   to finish, even after all 35 chunks have been generated.

4. Confirm the full passage was audible and note any gaps or errors. A completed
   run prints `Audio:`, `Queue underruns:`, and `Minimum headroom while producing:`.
   Zero underruns and zero inserted silence mean the application queue did not
   starve. A nonzero count is a playback finding, not by itself evidence of a
   network dependency.

5. Note the `Results:` folder printed near the start; its `summary.json` contains
   the measurements. Keep the transcript even if the run fails. Restore internet
   access afterward and report the result folder, any error, and whether you
   heard the whole passage without unexpected gaps.

#### Results

On 2026-10-17, the user completed the offline procedure and returned online,
reporting no audible problems. The
[summary](../../experiments/01-kokoro-windows-arm64/assets/csharp-playback-6bd20807f01f4fcc94a478e4a241c9e0/summary.json)
and [transcript](../../experiments/01-kokoro-windows-arm64/assets/offline-test-20261017-101223.log)
recorded all 35 chunks generated and consumed:

| Measurement | Result |
| --- | --- |
| Audio duration | 191.904 s |
| Aggregate generation RTF | 0.400 |
| Minimum queued headroom while producing | 3.329 s |
| Application-buffer starvation episodes | 0 |
| Silence inserted for starvation | 0.000 s |

This verified offline generation and playback for the installed configuration,
with network disconnection performed by the user rather than independently
logged by the prototype. No network-traffic audit was performed.

## Conclusion

The local ARM64 CPU CLI generated speech accepted by the user, and C# integration
successfully generated audio. The two-thread baseline missed the proposed 0.5
target; three, four, and six threads met it in the subsequent comparison.
Three threads then sustained 191.912 seconds of actual playback without
application-buffer starvation. The user then completed the offline repeat with
no audible problems and no recorded application-buffer starvation.
