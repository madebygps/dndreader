using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text.Json;
using SherpaOnnx;

// verify we are executing on windows arm64
if (!OperatingSystem.IsWindows() || RuntimeInformation.ProcessArchitecture != Architecture.Arm64)
    throw new PlatformNotSupportedException("Native Windows ARM64 execution is required.");
// verify length of passed in arguments from .ps1
if (args.Length is < 1 or > 3)
    throw new ArgumentException("Usage: KokoroPerformance <assets-directory> [threads] [worker-result.json]");

var assets = Path.GetFullPath(args[0]);
var threads = 2;
if (args.Length >= 2 && (!int.TryParse(args[1], out threads) || threads is < 1 or > 128))
    throw new ArgumentException("Thread count must be an integer between 1 and 128.");
var jsonOptions = new JsonSerializerOptions { WriteIndented = true };
const string text = """
    The reading group met on October 16, 2026. We reviewed 1,250 commits from 32 developers, and the test took 3.5 seconds. The monthly budget was $24.99, with 15% reserved for storage. Dr. Chen asked whether the CPU could run an ARM64 model through an API without a GPU. We compared Git repositories, concurrent workloads, neural networks, and asynchronous requests. After a brief pause, the narrator asked: "Which version should we deploy?"
    """;

      // if we get all the args we need
if (args.Length == 3)
{
  
    var started = DateTimeOffset.UtcNow;
    var runtime = Path.Combine(assets, "sherpa-onnx-v1.13.8-win-arm64-shared-MD-Release");
    var model = Path.Combine(assets, "kokoro-multi-lang-v1_0");

  // start timing how long to load dll
    var dllTimer = Stopwatch.StartNew();
    // Bind to the exact downloaded runtime rather than another DLL on PATH.
    NativeLibrary.Load(Path.Combine(runtime, "bin", "onnxruntime_providers_shared.dll"));
    NativeLibrary.Load(Path.Combine(runtime, "bin", "onnxruntime.dll"));
    var nativeApi = NativeLibrary.Load(Path.Combine(runtime, "lib", "sherpa-onnx-c-api.dll"));
    NativeLibrary.SetDllImportResolver(typeof(OfflineTts).Assembly,
        (name, _, _) => name == "sherpa-onnx-c-api" ? nativeApi : IntPtr.Zero);
    dllTimer.Stop();
  // stop timer of dll load

    var config = new OfflineTtsConfig();
    config.Model.Kokoro.Model = Path.Combine(model, "model.onnx");
    config.Model.Kokoro.Voices = Path.Combine(model, "voices.bin");
    config.Model.Kokoro.Tokens = Path.Combine(model, "tokens.txt");
    config.Model.Kokoro.DataDir = Path.Combine(model, "espeak-ng-data");
    config.Model.Kokoro.Lexicon = Path.Combine(model, "lexicon-us-en.txt");
    config.Model.NumThreads = threads;
    config.Model.Debug = 0;
    config.Model.Provider = "cpu";
// timer for creating speech engine and loading its model/resources
    var loadTimer = Stopwatch.StartNew();
    using var tts = new OfflineTts(config);
    loadTimer.Stop();
  // stop speech engine timer
    var loadSeconds = loadTimer.Elapsed.TotalSeconds;
    if (tts.SampleRate != 24000 || tts.NumSpeakers <= 3)
        throw new InvalidOperationException("Unexpected model sample rate or voice inventory.");

    var generations = new List<GenerationResult>();
    var generationTimer = new Stopwatch();
  // generate 3 trials per process
    for (var index = 0; index < 3; index++)
    {
      // timer for each generation
        generationTimer.Restart();
        var audio = tts.Generate(text, speed: 1, speakerId: 3);
        generationTimer.Stop();
      // stop generation timer
        try
        {
            if (audio.Handle == IntPtr.Zero || audio.NumSamples <= 0 || audio.SampleRate <= 0)
                throw new InvalidOperationException("Generation returned no valid audio.");
            var duration = (double)audio.NumSamples / audio.SampleRate;
            generations.Add(new GenerationResult(
                index == 0 ? "first" : "warm", generationTimer.Elapsed.TotalSeconds,
                duration, generationTimer.Elapsed.TotalSeconds / duration));
            if (index == 0)
            {
                var wav = Path.ChangeExtension(args[2], ".wav");
                if (!audio.SaveToWaveFile(wav))
                    throw new IOException($"Could not save C# generation: {wav}");
            }
        }
        finally
        {
          // release each generation's audio
            audio.Dispose();
        }
    }

  //
    using var current = Process.GetCurrentProcess();
    current.Refresh();
    var result = new TrialResult(Environment.ProcessId, current.StartTime.ToUniversalTime(),
        started, RuntimeInformation.ProcessArchitecture.ToString(),
        RuntimeInformation.FrameworkDescription, dllTimer.Elapsed.TotalSeconds,
        loadSeconds, current.PeakWorkingSet64, generations);
    File.WriteAllText(args[2], JsonSerializer.Serialize(result, jsonOptions));
    return;
}

var output = Path.Combine(assets, $"csharp-performance-{Guid.NewGuid():N}");
Directory.CreateDirectory(output);
var trials = new List<TrialResult>();
// 3 total processes, 3 generations in each one
for (var index = 1; index <= 3; index++)
{
    var resultPath = Path.Combine(output, $"trial-{index}.json");
    var start = new ProcessStartInfo(Environment.ProcessPath!)
    {
        UseShellExecute = false,
        RedirectStandardOutput = true,
        RedirectStandardError = true
    };
    start.ArgumentList.Add(Assembly.GetExecutingAssembly().Location);
    start.ArgumentList.Add(assets);
    start.ArgumentList.Add(threads.ToString());
    start.ArgumentList.Add(resultPath);
    using var child = Process.Start(start) ?? throw new InvalidOperationException("Worker did not start.");
    Console.WriteLine($"Trial {index}: fresh PID {child.Id}");
    var stdout = child.StandardOutput.ReadToEndAsync();
    var stderr = child.StandardError.ReadToEndAsync();
    using var timeout = new CancellationTokenSource(TimeSpan.FromMinutes(10));
    try
    {
        await child.WaitForExitAsync(timeout.Token);
    }
    catch (OperationCanceledException)
    {
        child.Kill(entireProcessTree: true);
        await child.WaitForExitAsync();
        throw new TimeoutException($"Trial {index} exceeded ten minutes.");
    }
    await File.WriteAllTextAsync(Path.Combine(output, $"trial-{index}.log"),
        await stdout + await stderr);
    if (child.ExitCode != 0)
        throw new InvalidOperationException($"Trial {index} failed ({child.ExitCode}); see {output}.");
    var trial = JsonSerializer.Deserialize<TrialResult>(await File.ReadAllTextAsync(resultPath))
        ?? throw new InvalidDataException($"Empty result: {resultPath}");
    if (trial.Pid != child.Id || trial.Generations.Count != 3)
        throw new InvalidDataException($"Unexpected worker result: {resultPath}");
    trials.Add(trial);
}
var warm = trials.SelectMany(t => t.Generations).Where(g => g.Kind == "warm")
    .Select(g => g.Rtf).Order().ToArray();
var median = (warm[2] + warm[3]) / 2;
var summary = new
{
    Text = text, Voice = "af_heart", SpeakerId = 3, Provider = "cpu", Threads = threads,
    Speed = 1, MaxNumSentences = 1, SilenceScale = 0.2,
    Trials = trials, WarmRtfMin = warm[0], WarmRtfMedian = median,
    WarmRtfMax = warm[^1], AllWarmRunsAtOrBelowTarget = warm.All(r => r <= 0.5)
};
await File.WriteAllTextAsync(Path.Combine(output, "summary.json"),
    JsonSerializer.Serialize(summary, jsonOptions));
Console.WriteLine($"Results: {output}");
Console.WriteLine($"Warm RTF min/median/max: {warm[0]:F3} / {median:F3} / {warm[^1]:F3}");
Console.WriteLine($"All warm runs <= 0.5: {summary.AllWarmRunsAtOrBelowTarget}");

record GenerationResult(string Kind, double GenerationSeconds, double AudioSeconds, double Rtf);
record TrialResult(int Pid, DateTime ProcessStartUtc, DateTimeOffset WorkerStartedUtc,
    string Architecture, string Framework, double DllLoadSeconds, double EngineLoadSeconds,
    long PeakWorkingSetBytes, List<GenerationResult> Generations);
