# Provisional architecture

Status: proposal, not an implemented design.

## Purpose and scope

Build a personal, educational, openly shared Windows ARM64 article reader. Prioritize understanding and reproducible experiments over broad platform support.

Confirmed scope:

- Article/blog URLs and pasted text; no PDFs.
- Offline narration and local questions after setup/import.
- Sentence-based playback and highlighting as the initial proposed reading unit.
- Preserve supported static figures, alt text, and captions.
- Build and validate a CPU-first question-answering path on Windows ARM64.

Not yet decided: final UI design, inference runtime and model, optional accelerator support, application license, and distribution method.

## Proposed components

| Component | Candidate | Reason / uncertainty |
| --- | --- | --- |
| Native shell | C# + WinUI 3, ARM64 | Native Windows UI; not yet prototyped |
| Article surface | ARM64 WebView2 | Article formatting, selection, figures, highlighting |
| Extraction | Mozilla Readability | Main-content extraction; site coverage needs testing |
| Speech | Kokoro through sherpa-onnx | Documented Kokoro support and Windows ARM64 releases |
| Questions | Local LLM through a Windows ARM64 CPU runtime | Runtime and model are not selected; keep the app independent of the inference backend |
| Persistence | SQLite plus local files | Articles, images, progress, preferences, optional audio cache |

```text
URL or pasted text
  -> fetch / parse / extract / sanitize
  -> structured local article
       -> sentences -> Kokoro -> audio queue -> playback + highlighting
       -> selected text + surrounding passage -> local LLM -> answer
```

The LLM must not rewrite the article before narration. Preserve source text and map any speech normalization back to its original offsets.

## Article representation

Maintain ordered headings, paragraphs, lists, tables, and figures with stable IDs. Store sentence/selection offsets, source metadata, local image paths, and author-provided captions separately from generated explanations.

Readability output is not automatically safe HTML. Strip active content and prevent saved articles from silently fetching remote resources.

Public URL import will not work universally. Login-protected, blocked, or JavaScript-only pages may need a later browser capture workflow. Pasted text remains a fallback.

## Hardware principles

Start with native ARM64 CPU inference as the baseline. Optional GPU/NPU acceleration is a separate, hardware-specific path: runtime, driver, model operations, and device support must be verified for each backend. A GGUF model usable in llama.cpp is not automatically usable in an ONNX runtime or accelerator backend.

Validate CPU question answering and concurrent reading on the current device before committing to optional accelerator support. Kokoro NPU work is optional.

## Offline, sharing, and licensing

Model/runtime acquisition and article import can require network access. Normal use after setup must not require cloud inference. Inspect telemetry controls and verify offline behavior.

Keep model weights outside Git. Record their exact source, version, hash, and license when adopted. Review native dependency and pronunciation-data licenses, including eSpeak NG obligations, before distribution.

## Decision log

| Date | Decision / proposal | Basis |
| --- | --- | --- |
| 2026-10-16 | Exclude PDFs | User-selected scope |
| 2026-10-16 | Target Windows ARM64 and investigate Snapdragon X NPU | User hardware and learning goals |
| 2026-10-16 | Run small speech and NPU proofs before building the UI | Unverified integration and performance risks |
| 2026-10-23 | Prioritize CPU-only local question answering; defer accelerator-specific work until a target device is available | User is changing hardware and wants to build the feature on the current laptop |

## Starting sources

- [WinUI 3](https://learn.microsoft.com/en-us/windows/apps/winui/winui3/)
- [Mozilla Readability](https://github.com/mozilla/readability)
- [llama.cpp build documentation](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md)
- [Foundry Local architecture](https://learn.microsoft.com/en-us/azure/foundry-local/concepts/foundry-local-architecture)
