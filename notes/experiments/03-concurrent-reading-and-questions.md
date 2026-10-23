# 03: Concurrent reading and questions

Status: not started.

Dependencies: working baselines from [experiment 01](01-kokoro-windows-arm64.md) and [experiment 02](02-local-llm-windows-arm64-cpu.md).

## Question and success criteria

Can the app keep narrating smoothly while generating a local answer?

Success means:

- Zero playback buffer underruns during a proposed ten-minute representative run.
- Pause, resume, sentence navigation, and cancellation remain responsive.
- Sentence highlighting follows audio playback, not synthesis completion.
- Speech and answer latency, memory pressure, and backend placement are recorded.
- No networking is required after setup.

The ten-minute duration is a proposed test target, not an observed result.

## Current evidence

**Hypothesis:** CPU speech and CPU question generation may contend for CPU time and memory bandwidth.

**Unknown:** memory bandwidth, CPU preprocessing, and runtime scheduling may affect playback. Results on the current Snapdragon CPU do not predict performance on other Windows ARM64 processors.

## Environment

Record the pinned configurations from experiments 01 and 02, playback speed, audio buffer settings, speech lookahead, and whether the device is plugged in or on battery.

## Procedure

1. Measure speech-only and question-only baselines.
2. Play a representative long passage with a small configurable speech lookahead.
3. Submit repeated short and long questions while reading continues.
4. Exercise pause/resume, navigation, and cancellation during inference.
5. Record underruns and queue depth, not only subjective listening impressions.
6. Compare latency and memory with the independent baselines.
7. Repeat offline. Record thermal or power-related changes without claiming battery savings from utilization alone.

## Measurements

| Run | Duration | Playback speed | Lookahead | Underruns | Question first-token latency | Peak memory | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Not run | - | - | - | - | - | - | - |

## Run log

### 2026-10-16: Experiment defined

Waiting for independent speech and CPU question-answering baselines. No concurrency tests performed.

## Conclusion

Pending. Use results to choose buffering and scheduling, rather than optimizing speculatively.
