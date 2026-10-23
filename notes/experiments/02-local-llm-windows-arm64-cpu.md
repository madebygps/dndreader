# 02: Local LLM on Windows ARM64 CPU

Status: CPU baseline established; native ARM64 setup, initial quality review, startup/streaming/memory measurements, and user-reported network-disabled run complete. Broader validation remains open. Dependencies: none.

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

**Observed, 2026-10-23:** llama.cpp b11838 and Qwen3-4B Q4_K_M ran on this Windows ARM64 machine. The runtime binaries were verified as native ARM64, and a CPU-only passage question returned a correct answer.

**Observed, initial quality review:** five of six fixed questions met all review criteria. The false-premise answer avoided fabrication but did not explicitly correct the premise. Results cover one short synthetic passage, not general article-answering quality.

**Observed, initial resident-model measurements:** process startup to healthy took 2.436 seconds. Three streamed answers began after 1.119-1.268 seconds, with 27.29-28.67 output tokens/s. The server process reached a lifetime peak working set of approximately 5.30 GiB.

**User-reported, 2026-10-23:** the benchmark worked with networking disabled. Its saved results show a fresh server startup and three completed answers. Network disconnection was reported by the user, not independently instrumented.

**Not established:** broader answer quality, a controlled cold-cache baseline, performance distributions, concurrent narration behavior, or telemetry behavior. A successful disconnected run establishes offline functionality for this configuration, not an audit of network behavior when connected.

This experiment establishes a CPU baseline for the current machine and application behavior. It does not measure or predict GPU/NPU performance, and its speed results should not be generalized to other ARM64 processors.

## Environment

| Item | Value |
| --- | --- |
| Processor / RAM | Snapdragon X Elite X1E80100 / approximately 63.5 GiB OS-visible RAM |
| Windows build | Windows 11 Enterprise, build 26300 |
| Runtime | llama.cpp b11838, reported version `0.7.0-dev`, commit `4231b23dc`; built with Clang 20.1.8 |
| Runtime architecture and CPU backend | Official Windows CPU ARM64 build; all extracted EXE/DLL PE machine fields were ARM64 (`0xaa64`); 6 generation and prompt-processing threads; `--gpu-layers 0` |
| Model | Official `Qwen/Qwen3-4B-GGUF`, revision `bc640142c66e1fdd12af0bd68f40445458f3869b`, `Qwen3-4B-Q4_K_M.gguf` |
| Context length and generation settings | 4096 tokens; maximum 256 generated tokens; temperature 0; seed 42; thinking disabled with `--reasoning off`; default warmup enabled |
| Telemetry and offline settings | Local file paths and `--offline`; user reported a successful network-disabled benchmark; telemetry not independently verified |

## Procedure

Complete and record each step before starting the next.

### Step 1: Runtime and model

- [x] Selected, pinned, downloaded, and verified on 2026-10-23.

We chose llama.cpp for direct control over the CPU baseline, not because a
Foundry Local comparison established a performance winner. We chose Qwen3-4B
Q4_K_M as a starting balance of model size and expected answer quality; that
tradeoff still needs evaluation on our questions.

GGUF is the model container supported by llama.cpp. Q4_K_M is a mixed-precision
quantization preset using mostly 4-bit weights. Neither identifies a different
model family.

| Asset | Pinned source | SHA-256 |
| --- | --- | --- |
| CPU ARM64 runtime | [llama-b11838-bin-win-cpu-arm64.zip](https://github.com/ggml-org/llama.cpp/releases/download/b11838/llama-b11838-bin-win-cpu-arm64.zip) | `0318fc8e07fb1345015d23287e0b6ffcde7d1638d092449ac2795fd4a4614bb5` |
| Model, 2,497,280,256 bytes | [Qwen3-4B-Q4_K_M.gguf at the pinned revision](https://huggingface.co/Qwen/Qwen3-4B-GGUF/blob/bc640142c66e1fdd12af0bd68f40445458f3869b/Qwen3-4B-Q4_K_M.gguf) | `7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5` |

From the repository root in PowerShell, we ran the
[setup script](../../experiments/02-local-llm-windows-arm64-cpu/setup.ps1):

```powershell
.\experiments\02-local-llm-windows-arm64-cpu\setup.ps1
```

The script requires Windows ARM64, PowerShell, and `curl.exe`. It verifies both
downloads against the pinned hashes, extracts the runtime, checks the PE
architecture of its EXE/DLL files, and invokes `llama-cli.exe --version`.
No additional runtime dependency was needed on this machine.

Downloads, extracted binaries, and generated run files remain inside the
gitignored `experiments\02-local-llm-windows-arm64-cpu\assets\` directory.

### Step 2: First passage question

- [x] Ran a bounded CPU-only question on 2026-10-23.

We used an [original sample passage and question](../../experiments/02-local-llm-windows-arm64-cpu/passage-question.txt),
supplied directly as context. No retrieval system, embeddings, or RAG was needed.
The system prompt instructed the model to answer only from the passage and
acknowledge missing information.

```powershell
.\experiments\02-local-llm-windows-arm64-cpu\smoke-test.ps1
```

The [smoke-test script](../../experiments/02-local-llm-windows-arm64-cpu/smoke-test.ps1)
uses the settings in the environment table and exits after one answer. Each run
saves CLI output, a runtime log, and stderr in its own `assets\runs\` subdirectory.
The CLI output also includes its banner and prompt, not only the model's answer.

The answer was:

> A buffer underrun occurs when playback needs more audio but the buffer is empty. The tradeoff with preparing more speech ahead of time is increased memory consumption. Offline operation has not been verified.

All three statements matched the passage. This was one smoke-test question, not
a quality evaluation.

We confirmed CPU-only placement using the CPU-only distribution, zero requested
GPU layers, the runtime's six-thread initialization, and `--list-devices`, which
reported no accelerator devices:

```powershell
.\experiments\02-local-llm-windows-arm64-cpu\assets\llama-b11838\llama-cli.exe --list-devices
```

The runtime log also showed that this version of `llama-cli` started an internal
HTTP service bound to `127.0.0.1` on a dynamic port. It reported no API key and
permissive CORS. The process exited after the answer; we did not leave a server
running. This behavior needs review before application integration.

### Step 3: Fixed answer-quality questions

- [x] Ran six questions and manually reviewed their answers on 2026-10-23.

We kept the model, CPU settings, system prompt, and generation settings unchanged
from step 2. Each question ran in a fresh CLI process with no conversation
history. The [fixed fixture](../../experiments/02-local-llm-windows-arm64-cpu/quality-cases.json)
contains the original passage, questions, and review criteria defined before
execution. Criteria were not sent to the model.

```powershell
.\experiments\02-local-llm-windows-arm64-cpu\quality-test.ps1
```

The [quality runner](../../experiments/02-local-llm-windows-arm64-cpu/quality-test.ps1)
reuses the smoke-test script. It saves a fixture snapshot, each complete prompt,
CLI output, runtime diagnostics, and stderr under
`assets\runs\quality-dad653a5f69a418186a1333ef81ec326\`.
Successful script execution only means the cases ran; judgments below were
made by reading the answers against the fixture criteria.

| Case / question | Model answer | Review |
| --- | --- | --- |
| Definition: What does 'buffer underrun' mean in this passage? | Buffer underrun occurs when playback needs more audio but the buffer is empty. | Pass: accurate definition, no invented cause. |
| Contextual explanation: Why might preparing more speech ahead of playback help, and what is the tradeoff? | Preparing more speech ahead of playback helps reduce buffer underruns, which occur when playback needs more audio but the buffer is empty. The tradeoff is that it consumes additional memory. | Pass: identified both benefit and memory cost without promising elimination. |
| Passage evidence: Which processor runs narration and question answering? Quote the sentence that supports your answer. | The CPU runs narration and question answering. Quote: "In this prototype, narration and question answering both run on the CPU." | Pass: correct processor and exact supporting quotation. |
| Missing number: How many seconds of generated audio does this prototype keep in its buffer? | The passage does not provide the specific number of seconds of generated audio kept in the buffer. | Pass: no invented buffer duration. |
| False premise: What did the successful network-disabled test prove about this prototype? | The passage does not provide information about a successful network-disabled test or what it proved about the prototype. | Partial: did not invent a result, but did not explicitly state that the passage says the test has not happened. |
| Background boundary: What does the passage say a GPU is, and why was a CPU chosen instead? | The passage does not provide information about what a GPU is or why a CPU was chosen instead. | Pass: neither background knowledge nor an invented design rationale was presented as passage evidence. |

Five answers fully met the criteria; one was partial. No unsupported factual
claims were observed in these six answers. The false-premise case distinguishes
safe abstention from a complete answer: the model had explicit contradictory
evidence available but did not use it to correct the question.

We retained the baseline prompt rather than tuning it after this small set.
These results do not establish behavior on longer articles, varied wording,
multiple passages, passage instructions, or requests for explicitly labeled
background knowledge. The passage describes a fictional prototype; its
statements are test input, not measurements of this application.

### Step 4: Startup, streamed answer latency, and process memory

- [x] Measured one startup and three consecutive resident-model requests on 2026-10-23.

```powershell
.\experiments\02-local-llm-windows-arm64-cpu\benchmark.ps1
```

The [benchmark script](../../experiments/02-local-llm-windows-arm64-cpu/benchmark.ps1)
requires PowerShell 7 or later. We used PowerShell 7.6.7 and the pinned
`llama-server.exe` from the same CPU ARM64 distribution. The script starts its
own server on a dynamically allocated loopback port with an ephemeral API key,
restricted CORS, and the web UI disabled. It leaves existing interactive
consoles untouched and stops only its own server when it finishes or fails.

We retained the same model, passage/question, system prompt, context size,
six threads, temperature, seed, output limit, and disabled thinking.
Default model warmup remained enabled. Each request sent a fresh two-message
conversation through `/v1/chat/completions`, rather than continuing a chat.
Prompt caching was disabled for every request so that the later requests
measured resident-model behavior without skipping repeated prompt evaluation.
The response usage records confirmed zero cached tokens in all three requests.

Startup was timed from process launch until a successful `/health` response.
That includes initialization, model loading, default warmup, and client readiness
checks; it is not isolated model-loading time. The OS file cache was not flushed,
so this was a new process, not a controlled cold-cache run.

For each streamed response, we timed submission to the first nonempty content
chunk and to completion. First content is a user-visible time-to-first-token
proxy, not an exact tokenizer event; role-only chunks were excluded. HTTP,
PowerShell, and approximately 10 ms task-polling overhead are included.
Generation speed came from the server's internal timing counters, not from
dividing total request time by token count.

We sampled process private bytes while waiting for readiness and stream events.
Working-set peaks used the OS process-lifetime high-water mark; they do not
reset between requests. Private-byte peaks were sampled, so brief peaks could
be missed. These are distinct, overlapping memory views and must not be added
together. Neither measures total system memory or GPU/NPU memory.

The script saved the input snapshot, raw SSE streams, extracted answers,
per-request usage/timings, process memory, stdout/stderr, and server log in
`assets\runs\benchmark-75a71c5bf10c4ba388e54e89f4df535a\`.
All requests completed normally without context truncation or reasoning output.
Their answers were identical and passage-correct, but had a minor grammatical
error: "The tradeoff comes with preparing more speech ahead of time is increased
memory consumption." This wording differed from the earlier CLI answer; the
server entry point should not be assumed to produce byte-identical output to
the CLI even with the listed settings matched.

Other running applications, power/thermal state, and OS caches were not
controlled. In particular, any existing interactive model remained separate
and was not counted in the benchmark server's process memory. One startup and
three short requests are initial observations, not a performance distribution
or a promise for longer passages.

### Step 5: Network-disabled operation

- [x] User reported successful execution with networking disabled on 2026-10-23.

We asked the user to disconnect Wi-Fi/Ethernet and run the same benchmark:

```powershell
.\experiments\02-local-llm-windows-arm64-cpu\benchmark.ps1
```

The user reported that it worked well. The saved run,
`assets\runs\benchmark-2a1f5b0bcdeb4d48974ae9817b640fef\results.json`,
recorded a fresh server startup and three complete answers with zero cached
prompt tokens. The network-disabled condition is based on the user's report;
the benchmark does not inspect network adapters or capture traffic.

Startup took 2.545 seconds, first content arrived after 1.187-1.232 seconds,
and complete answers took 2.607-2.618 seconds. Generation was
28.06-28.50 tokens/s, with a lifetime peak working set of approximately 5.30 GiB.
The answers matched the preceding server run, including the minor grammatical
error. Their statement "Offline operation has not been verified" referred to
the fictional passage, not the actual state of this experiment.

This established user-observed offline startup and inference for the installed
configuration. It did not establish connected-mode privacy or remove the need
for a runtime privacy review.

### Remaining steps

- [ ] Establish a controlled cold-cache baseline and repeatable power/background-load conditions if broader benchmarking is needed.
- [ ] Review runtime privacy behavior and record any additional compatibility limits.

Keep the model, prompts, context length, and generation settings fixed when comparing runtime changes. If those differ, label the result as a comparison of whole configurations rather than a controlled runtime benchmark.

## Measurements

The two smoke-test runs below used the pinned configuration above. OS file-cache state was not
controlled, so neither is labeled a cold-start benchmark.

### Process and loading

| Run | Whole CLI process elapsed | Model-loading duration |
| --- | --- | --- |
| Initial smoke test | 6.472 s | Not separately measured |
| Repeat with runtime logging | 5.982 s | Not separately measured |

Whole-process time includes initialization, loading, prompt processing,
generation, and shutdown. It is not model-loading time or first-token latency.

### Generation

| Run | Prompt tokens/s | Output tokens/s | Time to first token | Peak memory |
| --- | --- | --- | --- | --- |
| Initial smoke test | 134.6 | 25.1 | Not measured | Not measured |
| Repeat with runtime logging | 135.86 | 26.30 | Not measured | Not measured |

The repeat's runtime log reported 156 prompt tokens processed in 1,148.27 ms
and 40 generation evaluation tokens in 1,482.85 ms. These are internal runtime
timings, not end-to-end latency. Six threads were an initial setting, not a
measured optimum.

### Resident-server startup and memory

| Run | Process start to healthy | Startup lifetime peak working set | Startup sampled peak private bytes |
| --- | --- | --- | --- |
| Initial server benchmark | 2.436 s | 5,406.13 MiB | 3,175.66 MiB |
| User-reported network-disabled benchmark | 2.545 s | 5,406.25 MiB | 3,175.77 MiB |

### Resident-server generation and memory

All requests contained 156 prompt tokens and reported 41 completion tokens.
No prompt tokens were cached.

| Request | Model state | First content | Total request time | Output tokens/s | Process lifetime peak working set | Request sampled peak private bytes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | First after startup/default warmup | 1.268 s | 2.702 s | 27.29 | 5,430.13 MiB | 3,175.84 MiB |
| 2 | Resident, prompt re-evaluated | 1.119 s | 2.502 s | 28.64 | 5,430.13 MiB | 3,173.20 MiB |
| 3 | Resident, prompt re-evaluated | 1.131 s | 2.506 s | 28.67 | 5,430.13 MiB | 3,173.20 MiB |
| Offline 1 | First after startup/default warmup | 1.232 s | 2.618 s | 28.36 | 5,430.21 MiB | 3,175.91 MiB |
| Offline 2 | Resident, prompt re-evaluated | 1.187 s | 2.607 s | 28.06 | 5,430.21 MiB | 3,173.18 MiB |
| Offline 3 | Resident, prompt re-evaluated | 1.207 s | 2.613 s | 28.50 | 5,430.21 MiB | 3,173.23 MiB |

The approximately 5.30 GiB lifetime peak working set includes mapped model pages
and runtime allocations. The approximately 3.10 GiB sampled private-byte peak is
not an additional allocation to add on top. A request's time already includes
its wait for first content; those columns must not be added together.

## Run log

### 2026-10-16: Initial research

Foundry Local and llama.cpp identified as candidate local inference paths. No model or runtime has been installed or executed for this experiment.

### 2026-10-23: Setup and first CPU answer

We completed steps 1 and 2 above. The first invocation returned the correct
answer but did not save runtime diagnostics to stderr. We added explicit
file logging and repeated the same question to retain the runtime timings.
The initial and repeat run directories were respectively
`e7fcc23d7dd848abbdc1d77d89fc84cf` and `9346973e50fe4ecba9d660994cfc1587`
under `assets\runs\`.

### 2026-10-23: Initial answer-quality review

We completed step 3 above using the unchanged baseline settings. The review
identified incomplete correction of a false premise; no prompt tuning or
latency/memory instrumentation was performed during this step.

### 2026-10-23: Initial startup and resident-model measurements

We completed step 4 above. The owned benchmark server was stopped after saving
the three streaming responses and measurements; the user's interactive console
was not stopped or modified. Network-disabled operation was not tested.

### 2026-10-23: User-reported offline run

We completed step 5 above by reviewing the saved benchmark after the user
reported successful network-disabled execution. The disconnected condition was
not independently instrumented. No system network settings were changed by
the agent.

## Conclusion

Native ARM64 CPU passage answering worked for the smoke test and the initial
six-case quality set. Five answers fully met the criteria; the false-premise
answer safely abstained but incompletely corrected the question. The initial
resident-server run began short answers in approximately 1.1-1.3 seconds and
finished them in approximately 2.5-2.7 seconds, with a process lifetime peak
working set of approximately 5.30 GiB. A user-reported network-disabled run
also completed startup and inference at similar observed speeds. Broader
quality, privacy, and responsiveness under concurrent narration remain pending.
