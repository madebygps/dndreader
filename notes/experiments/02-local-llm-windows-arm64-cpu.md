# 02: Local LLM on Windows ARM64 CPU

Status: not started. Dependencies: none.

## Question and success criteria

Can a local language model answer questions about selected article text on a Windows ARM64 CPU, with useful quality and a reproducible offline setup?

Success means:

- The model and runtime execute locally on the CPU, using native ARM64 components where available.
- Answers work without network access after model and runtime setup.
- Answers define terms in context, use passage evidence, and distinguish it from background knowledge.
- Questions whose answers are absent from the selected text are handled honestly.
- First-token latency, generation speed, memory use, and answer quality are recorded.
- The active runtime and CPU backend are confirmed; setup failures are reported rather than hidden by unsupported fallbacks.

No latency threshold has been chosen yet. Record the baseline before deciding what is acceptable.

## Current evidence

**Documented, checked 2026-10-16:**

- [Foundry Local architecture](https://learn.microsoft.com/en-us/azure/foundry-local/concepts/foundry-local-architecture) describes ONNX Runtime, hardware-specific execution providers, cached models, and Windows ML integration.
- [Foundry Local C# quickstart](https://learn.microsoft.com/en-us/azure/foundry-local/get-started) describes local inference on Windows without an Azure subscription.
- [llama.cpp build documentation](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md) describes a separate local inference path, including CPU builds.
- [Foundry Local repository](https://github.com/microsoft/Foundry-Local) discloses possible usage telemetry; review controls before adoption.

**Not established:** which runtime/model combination works natively on this Windows ARM64 machine, its exact prerequisites, offline behavior, or answer quality. A runtime that supports Windows or ARM64 in general is not proof that all of its model formats and dependencies work on this device.

This experiment establishes a CPU baseline for the current machine and application behavior. It does not measure or predict GPU/NPU performance, and its speed results should not be generalized to other ARM64 processors.

## Environment

| Item | Value |
| --- | --- |
| Processor / RAM | Snapdragon X Elite X1E80100 / approximately 63.5 GiB OS-visible RAM |
| Windows build | Windows 11 Enterprise, build 26300 |
| SDK and runtime | Not selected |
| Runtime architecture and CPU backend | Not selected |
| Model ID, version, format, quantization, hash | Not selected |
| Context length and generation settings | Not selected |
| Telemetry and offline settings | Not verified |

## Procedure

1. Record hardware, OS, runtime, and model prerequisites.
2. Select a runtime/model combination that supports local CPU inference on Windows ARM64; verify native ARM64 support for its runtime and dependencies.
3. Download and pin the runtime, model, and other required assets.
4. Run a minimal question-answering prototype using selected passage text as context.
5. Confirm that inference uses the CPU backend and record the runtime diagnostics.
6. Test a fixed set of definitions, contextual explanations, passage-grounded questions, and questions whose answers are absent.
7. Review answer quality, including unsupported claims and whether answers distinguish passage evidence from background knowledge.
8. Measure cold and warm runs, then repeat with networking disabled.
9. Record any x64 emulation or unsupported dependencies; do not describe an emulated run as a native ARM64 result.

Keep the model, prompts, context length, and generation settings fixed when comparing runtime changes. If those differ, label the result as a comparison of whole configurations rather than a controlled runtime benchmark.

## Measurements

| Run | Model / runtime | Runtime architecture | Cold/warm | Time to first token | Output tokens/s | Peak memory | Quality observations |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Not run | - | - | - | - | - | - | - |

## Run log

### 2026-10-16: Initial research

Foundry Local and llama.cpp identified as candidate local inference paths. No model or runtime has been installed or executed for this experiment.

## Conclusion

Pending. Record compatibility limits, privacy findings, and whether the CPU baseline is responsive enough for the reader.
