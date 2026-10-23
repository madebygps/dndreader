# dndreader

A learning project for a local-first article reader on Windows ARM64.

The goal is a useful personal tool and an open-source demo, not a commercial product:

- Import public article/blog URLs or pasted text.
- Preserve static figures and captions for offline viewing where possible.
- Read the original text aloud with natural, offline voices and sentence highlighting.
- Ask local AI models about selected passages.
- Build and validate local question answering on the CPU first; treat GPU/NPU acceleration as optional, hardware-specific follow-up work.

PDF support is out of scope. Image-based graph explanations are a later possibility, not an initial requirement.

## Current stage

Research and experiments. Local Kokoro generation and playback results are recorded below; no application exists yet.

Start with the [notes index](notes/README.md) and [provisional architecture](notes/architecture.md).

## Experiments

| Experiment | Status | Purpose |
| --- | --- | --- |
| [01: Kokoro on Windows ARM64](notes/experiments/01-kokoro-windows-arm64.md) | Complete; offline playback verified | Prove native offline speech and measure playback headroom |
| [02: Local LLM on Windows ARM64 CPU](notes/experiments/02-local-llm-windows-arm64-cpu.md) | Not started | Establish useful, offline local answers and a CPU performance baseline |
| [03: Concurrent reading and questions](notes/experiments/03-concurrent-reading-and-questions.md) | Not started | Keep narration uninterrupted while answering questions |
| [04: Kokoro on NPU](notes/experiments/04-kokoro-npu.md) | Optional; not started | Investigate compatibility and compare against CPU speech |

Runnable prototypes live under `experiments/`. Research and run notes live under `notes/`.

## Offline and licensing boundaries

Fetching a new article and downloading models or runtime components requires internet access. Saved content and installed models should work offline, without cloud inference fallbacks.

Application code, runtime dependencies, model weights, and voice assets can have different licenses. An application license has not yet been selected. Do not assume this repository grants redistribution rights to third-party assets.

Do not commit downloaded model weights, private articles, credentials, or machine-identifying diagnostics.
