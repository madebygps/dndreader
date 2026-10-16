# 02: Local LLM on Snapdragon NPU

Status: not started. Dependencies: none.

## Question and success criteria

Can a local model use the Snapdragon X NPU to answer questions about selected article text, with useful quality and reproducible setup?

Success means:

- A supported model variant runs locally with execution-provider or profiling evidence of NPU use.
- Answers work without network access after model/runtime setup.
- Answers define terms in context and distinguish passage evidence from background knowledge.
- First-token latency, generation speed, memory use, and any CPU fallback are recorded.
- Unsupported hardware or model configurations produce explicit errors rather than unreported fallback.

No latency threshold has been chosen yet. Record the baseline before deciding what is acceptable.

## Current evidence

**Documented, checked 2026-10-16:**

- [Foundry Local architecture](https://learn.microsoft.com/en-us/azure/foundry-local/concepts/foundry-local-architecture) describes ONNX Runtime, hardware-specific execution providers, cached models, and Windows ML integration.
- [C# quickstart](https://learn.microsoft.com/en-us/azure/foundry-local/get-started) provides Windows integration and local inference without an Azure subscription.
- [ONNX Runtime QNN provider](https://onnxruntime.ai/docs/execution-providers/QNN-ExecutionProvider.html) documents Windows/Qualcomm support, including Snapdragon X.
- [llama.cpp build documentation](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md) provides a separate native ARM64 CPU baseline path.
- [Foundry Local repository](https://github.com/microsoft/Foundry-Local) discloses possible usage telemetry; review controls before adoption.

**Not established:** an available NPU model variant for this machine, exact prerequisites, local execution, or answer quality. Automatic hardware selection alone is not proof of NPU execution.

Gemma is a candidate for a CPU comparison, not a required NPU model. Different model formats and runtime paths are not interchangeable.

## Environment

| Item | Value |
| --- | --- |
| Snapdragon variant / RAM | Not recorded |
| Windows build / NPU driver | Not recorded |
| SDK and runtime | Not selected |
| Execution provider and version | Not selected |
| Model ID, version, format, quantization, hash | Not selected |
| Context length and generation settings | Not selected |
| Telemetry and offline settings | Not verified |

## Procedure

1. Record hardware, OS, driver, and SDK prerequisites.
2. Inspect available model variants and select one explicitly compatible with the NPU path.
3. Download and pin the model and execution-provider assets.
4. Run a minimal selected-passage question through a console prototype.
5. Capture runtime/provider diagnostics or profiling. Use Task Manager only as supporting evidence.
6. Record which operations use NPU and whether any work falls back to CPU.
7. Test a fixed set of definitions, contextual explanations, and document-only questions whose answer is absent.
8. Repeat cold/warm runs and offline runs.
9. Compare with a native ARM64 CPU baseline where useful.

Prefer the same model/settings for hardware comparisons. If models differ, label the result as a comparison of whole configurations, not a controlled CPU-versus-NPU benchmark.

## Measurements

| Run | Model / backend | Cold/warm | Time to first token | Output tokens/s | Peak memory | Quality observations | NPU evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Not run | - | - | - | - | - | - | - |

## Run log

### 2026-10-16: Research baseline

Foundry Local and QNN identified as paths to evaluate. No models or SDKs have been installed or executed for this experiment.

## Conclusion

Pending. Record compatibility limits and privacy findings alongside performance.
