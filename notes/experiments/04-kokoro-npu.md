# 04: Kokoro on NPU

Status: optional; not started.

Dependency: [experiment 01](01-kokoro-windows-arm64.md). This experiment must not block the reader.

## Question and success criteria

Can a Kokoro export execute useful work on the Snapdragon X NPU, and does it improve the complete speech experience relative to CPU?

Success means:

- The exact export and execution provider are reproducible.
- Profiling identifies which operations run on the NPU and which remain on CPU.
- Audio remains intelligible and acceptable using the same evaluation passages.
- End-to-end timing is compared against the CPU baseline, including preprocessing and data transfers.

A well-documented incompatibility or a finding that CPU performs better is also a useful research outcome.

## Current evidence

**Documented:** [ONNX Runtime QNN](https://onnxruntime.ai/docs/execution-providers/QNN-ExecutionProvider.html) supports Qualcomm acceleration on Windows.

**Not established:** a ready-to-use Kokoro-on-Snapdragon-X-NPU pipeline. ONNX Runtime platform support does not establish model compatibility.

Possible obstacles to inspect, not confirmed diagnoses:

- Unsupported operators.
- Variable-length tensors or dynamic shapes.
- Precision and quantization requirements.
- Graph partitioning and CPU/NPU transfer overhead.
- CPU-only normalization and pronunciation stages.

## Environment

Record the CPU baseline, Kokoro export/hash, ONNX Runtime and QNN versions, NPU driver, precision, input-shape constraints, and all graph modifications.

## Procedure

1. Reproduce the CPU baseline with the chosen model export.
2. Inspect the model graph and current provider support before attempting conversion.
3. Attempt a QNN session and preserve diagnostic output.
4. In compatibility tests, disable CPU fallback where supported to expose unsupported graph regions; separately profile any intentional hybrid configuration.
5. If needed, investigate fixed input-size buckets or alternative exports. Record the consequences for sentence length and output quality.
6. Evaluate any quantized export against the original on identical text and voices.
7. Compare cold setup, warm generation, first-audio latency, memory, and complete pipeline timing.
8. Stop if progress requires model surgery beyond the current learning scope; document the blocker rather than disguising CPU fallback as NPU success.

## Measurements

| Run | Export / precision | Shape constraints | NPU coverage / CPU fallback | Generation time | Audio duration | Quality changes |
| --- | --- | --- | --- | --- | --- | --- |
| Not run | - | - | - | - | - | - |

Power efficiency requires a separate measurement method. Lower CPU utilization alone does not prove energy savings.

## Run log

### 2026-10-16: Research question defined

No Kokoro NPU execution has been verified. No conversion or quantization attempted.

## Conclusion

Pending. Keep CPU Kokoro as the reference path unless measured evidence justifies a change.
