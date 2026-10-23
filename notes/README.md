# Project notes

This folder is the project's lab notebook: what we think, what we tried, and what the evidence shows.

## Reading order

1. [Provisional architecture](architecture.md)
2. [Kokoro on Windows ARM64](experiments/01-kokoro-windows-arm64.md)
3. [Local LLM on Windows ARM64 CPU](experiments/02-local-llm-windows-arm64-cpu.md)
4. [Concurrent reading and questions](experiments/03-concurrent-reading-and-questions.md)
5. [Optional: Kokoro on NPU](experiments/04-kokoro-npu.md)

Experiments 01 and 02 are independent. Experiment 03 requires both baselines. Experiment 04 requires the CPU speech baseline, but is not required for the reader.

## Evidence conventions

- **Documented:** supported by a linked upstream source, not necessarily tried here.
- **Hypothesis:** an expectation we still need to test.
- **Observed:** reproduced locally, with the procedure and environment recorded.
- **Decision:** a choice made from evidence, including its limitations.

Research captured on 2026-10-16 is a starting point, not a promise that current upstream versions will behave identically.

## Keeping notes

Keep dated run entries in the relevant experiment page. Record failures and attempted fixes as well as successes. Link runnable code and commits once they exist.

For each run, record the relevant hardware, Windows build, drivers, runtime, model/export/quantization, configuration, and measurements. Omit serial numbers, usernames, tokens, and other identifying information.

Prefer redistributable sample text and images. Do not commit full third-party articles without permission.

## Experiment page template

Each experiment contains:

- Question and success criteria.
- Current evidence and unresolved assumptions.
- Environment.
- Reproducible procedure.
- Dated run log.
- Conclusion, limitations, and resulting decision.
