using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json;
using NAudio.CoreAudioApi;
using NAudio.Wave;
using SherpaOnnx;

if (args is ["--self-test"])
{
    MeasuredAudioQueue.SelfTest();
    return;
}
if (!OperatingSystem.IsWindows() || RuntimeInformation.ProcessArchitecture != Architecture.Arm64)
    throw new PlatformNotSupportedException("Native Windows ARM64 execution is required.");
if (args.Length != 3 || !int.TryParse(args[2], out var threads) || threads is < 1 or > 128)
    throw new ArgumentException("Usage: KokoroPlayback <assets-directory> <passage.txt> <threads>");

var assets = Path.GetFullPath(args[0]);
var sentences = File.ReadAllLines(args[1]).Where(line => !string.IsNullOrWhiteSpace(line)).ToArray();
if (sentences.Length < 2)
    throw new InvalidDataException("The passage must contain at least two sentence lines.");
var output = Path.Combine(assets, $"csharp-playback-{Guid.NewGuid():N}");
Directory.CreateDirectory(output);
File.Copy(args[1], Path.Combine(output, "passage.txt"));
Console.WriteLine($"Results: {output}");
Console.WriteLine($"Playing {sentences.Length} sentence chunks through the default audio output; CPU threads: {threads}.");

// The clock starts after passage I/O, but before native and model initialization.
var clock = Stopwatch.StartNew();
var runtime = Path.Combine(assets, "sherpa-onnx-v1.13.8-win-arm64-shared-MD-Release");
NativeLibrary.Load(Path.Combine(runtime, "bin", "onnxruntime_providers_shared.dll"));
NativeLibrary.Load(Path.Combine(runtime, "bin", "onnxruntime.dll"));
var nativeApi = NativeLibrary.Load(Path.Combine(runtime, "lib", "sherpa-onnx-c-api.dll"));
NativeLibrary.SetDllImportResolver(typeof(OfflineTts).Assembly,
    (name, _, _) => name == "sherpa-onnx-c-api" ? nativeApi : IntPtr.Zero);
var model = Path.Combine(assets, "kokoro-multi-lang-v1_0");
var config = new OfflineTtsConfig();
config.Model.Kokoro.Model = Path.Combine(model, "model.onnx");
config.Model.Kokoro.Voices = Path.Combine(model, "voices.bin");
config.Model.Kokoro.Tokens = Path.Combine(model, "tokens.txt");
config.Model.Kokoro.DataDir = Path.Combine(model, "espeak-ng-data");
config.Model.Kokoro.Lexicon = Path.Combine(model, "lexicon-us-en.txt");
config.Model.NumThreads = threads;
config.Model.Provider = "cpu";
config.Model.Debug = 0;
using var tts = new OfflineTts(config);
if (tts.SampleRate != 24000 || tts.NumSpeakers <= 3)
    throw new InvalidOperationException("Unexpected model sample rate or voice inventory.");
var engineReady = clock.Elapsed.TotalSeconds;
var queue = new MeasuredAudioQueue(clock);
using var devices = new MMDeviceEnumerator();
using var device = devices.GetDefaultAudioEndpoint(DataFlow.Render, Role.Multimedia);
using var player = new WasapiOut(device, AudioClientShareMode.Shared, true, 100);
var stopped = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
player.PlaybackStopped += (_, e) =>
{
    if (e.Exception is not null)
        stopped.TrySetException(e.Exception);
    else
        stopped.TrySetResult();
};
player.Init(queue);
var chunks = new List<ChunkResult>();
double? playbackRequested = null;
try
{
    for (var index = 0; index < sentences.Length; index++)
    {
        if (stopped.Task.IsCompleted)
        {
            await stopped.Task;
            throw new InvalidOperationException("Audio playback stopped before generation finished.");
        }
        var timer = Stopwatch.StartNew();
        var audio = tts.Generate(sentences[index], speed: 1, speakerId: 3);
        timer.Stop();
        float[] samples;
        double duration;
        try
        {
            if (audio.Handle == IntPtr.Zero || audio.NumSamples <= 0 || audio.SampleRate != 24000)
                throw new InvalidOperationException($"Chunk {index + 1} returned invalid audio.");
            duration = (double)audio.NumSamples / audio.SampleRate;
            samples = audio.Samples;
        }
        finally
        {
            audio.Dispose();
        }
        var headroom = queue.Enqueue(samples, index == sentences.Length - 1);
        chunks.Add(new ChunkResult(index + 1, sentences[index], timer.Elapsed.TotalSeconds,
            duration, timer.Elapsed.TotalSeconds / duration, clock.Elapsed.TotalSeconds,
            headroom.Before, headroom.After));
        if (index == 0)
        {
            playbackRequested = clock.Elapsed.TotalSeconds;
            player.Play();
        }
        Console.WriteLine($"Chunk {index + 1}/{sentences.Length}: generation {timer.Elapsed.TotalSeconds:F3}s, " +
            $"audio {duration:F3}s, queued {headroom.After:F3}s");
    }
    var productionFinished = clock.Elapsed.TotalSeconds;
    var totalAudio = chunks.Sum(chunk => chunk.AudioSeconds);
    await stopped.Task.WaitAsync(TimeSpan.FromSeconds(totalAudio + 30));
    var playbackFinished = clock.Elapsed.TotalSeconds;
    var measurements = queue.Snapshot();
    if (!measurements.ProducerCompleted || measurements.RemainingSeconds != 0 ||
        Math.Abs(measurements.ConsumedAudioSeconds - totalAudio) > 1.0 / 24000)
        throw new InvalidOperationException("Playback did not consume all generated samples.");
    using var current = Process.GetCurrentProcess();
    var summary = new
    {
        StartedUtc = DateTimeOffset.UtcNow - clock.Elapsed,
        Architecture = RuntimeInformation.ProcessArchitecture.ToString(),
        Framework = RuntimeInformation.FrameworkDescription,
        Threads = threads, Provider = "cpu", Voice = "af_heart", SpeakerId = 3, Speed = 1,
        MaxNumSentences = 1, SilenceScale = 0.2,
        Device = device.FriendlyName, PlaybackApi = "WASAPI shared, event-driven",
        RequestedLatencyMilliseconds = 100, InitialBufferChunks = 1,
        EngineReadySeconds = engineReady, PlaybackRequestedSeconds = playbackRequested,
        ProductionFinishedSeconds = productionFinished, PlaybackFinishedSeconds = playbackFinished,
        TotalAudioSeconds = totalAudio,
        TotalGenerationSeconds = chunks.Sum(chunk => chunk.GenerationSeconds),
        AggregateRtf = chunks.Sum(chunk => chunk.GenerationSeconds) / totalAudio,
        ProducerWallRtf = (productionFinished - engineReady) / totalAudio,
        PeakWorkingSetBytes = current.PeakWorkingSet64,
        Queue = measurements, Chunks = chunks
    };
    File.WriteAllText(Path.Combine(output, "summary.json"),
        JsonSerializer.Serialize(summary, new JsonSerializerOptions { WriteIndented = true }));
    Console.WriteLine($"Audio: {totalAudio:F3}s; aggregate generation RTF: {summary.AggregateRtf:F3}");
    Console.WriteLine($"Queue underruns: {measurements.Underruns}; inserted silence: {measurements.InsertedSilenceSeconds:F3}s");
    Console.WriteLine($"Minimum headroom while producing: {measurements.MinimumHeadroomWhileProducingSeconds:F3}s");
}
finally
{
    player.Stop();
}

record ChunkResult(int Index, string Text, double GenerationSeconds, double AudioSeconds,
    double Rtf, double EnqueuedSeconds, double HeadroomBeforeSeconds, double HeadroomAfterSeconds);
