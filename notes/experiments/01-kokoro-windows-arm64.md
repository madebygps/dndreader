# 01: Kokoro on Windows ARM64

Status: not started. Dependencies: none.

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

**Not established:** local compatibility, latency, sustained speed, complete C# packaging, or acceptable voice quality. Individual evidence of ARM64 and Kokoro support is not a local end-to-end result.

## Environment

| Item | Value |
| --- | --- |
| Hardware | Snapdragon X; exact variant and RAM to record |
| Windows build | Not recorded |
| .NET / toolchain | Not selected |
| sherpa-onnx artifact and hash | Not selected |
| Kokoro export, voices, and hashes | Not selected |
| Backend / thread count | CPU; settings to record |
| Native dependency licenses | Review pending |

## Procedure

1. Select and pin an ARM64 TTS-enabled runtime artifact and compatible Kokoro model bundle.
2. Record asset URLs, hashes, licenses, and prerequisites.
3. Verify process and native library architectures.
4. Generate one sentence to a WAV file using the native executable before integrating C#.
5. Test several voices using original sample prose, dates, numbers, acronyms, and technical terms.
6. Separate cold model-load time from warm generation time. Repeat representative runs.
7. Generate a longer passage in sentence-sized chunks and measure queue headroom.
8. Repeat with network access disabled after all assets are installed.
9. Reproduce generation through the intended C# integration.

Exact commands will be added when the runtime and model bundle are selected; none have been executed yet.

## Measurements

Real-time factor is generation wall time divided by generated audio duration. Below 1 means synthesis is faster than normal-speed playback. Faster playback requires additional headroom.

| Run | Cold/warm | Text / voice | First audio latency | Generation time | Audio duration | Real-time factor | Peak memory |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Not run | - | - | - | - | - | - | - |

For file-only tests, report time to completed WAV rather than mislabeling it as first-audio latency. Track CPU load and audible defects separately.

## Run log

### 2026-10-16: Research baseline

Upstream evidence collected. No downloads, builds, or local speech generation performed.

## Conclusion

Pending. Do not treat the proposed stack as validated.
