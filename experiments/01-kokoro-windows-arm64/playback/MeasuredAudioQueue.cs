using System.Diagnostics;
using NAudio.Wave;

sealed class MeasuredAudioQueue : IWaveProvider
{
    private readonly object gate = new();
    private readonly Queue<byte[]> chunks = new();
    private readonly Stopwatch clock;
    private int offset;
    private long queuedBytes;
    private bool complete;
    private bool starving;
    private double minimumHeadroom = double.PositiveInfinity;
    private double maximumHeadroom;
    private long missingBytes;
    private long consumedBytes;
    private int underruns;
    private double? firstReadSeconds;

    public MeasuredAudioQueue(Stopwatch clock)
    {
        this.clock = clock;
    }

    public WaveFormat WaveFormat { get; } = WaveFormat.CreateIeeeFloatWaveFormat(24000, 1);

    public (double Before, double After) Enqueue(float[] samples, bool last)
    {
        if (samples.Length == 0)
            throw new ArgumentException("An audio chunk cannot be empty.", nameof(samples));
        var bytes = new byte[checked(samples.Length * sizeof(float))];
        Buffer.BlockCopy(samples, 0, bytes, 0, bytes.Length);
        lock (gate)
        {
            if (complete)
                throw new InvalidOperationException("Cannot enqueue after the final chunk.");
            var before = Seconds(queuedBytes);
            chunks.Enqueue(bytes);
            queuedBytes += bytes.Length;
            complete = last;
            var after = Seconds(queuedBytes);
            maximumHeadroom = Math.Max(maximumHeadroom, after);
            return (before, after);
        }
    }

    public int Read(byte[] buffer, int destinationOffset, int count)
    {
        if (count <= 0 || count % WaveFormat.BlockAlign != 0)
            throw new ArgumentOutOfRangeException(nameof(count), "Reads must request complete audio frames.");
        lock (gate)
        {
            var written = 0;
            while (written < count && chunks.TryPeek(out var chunk))
            {
                var take = Math.Min(count - written, chunk.Length - offset);
                Buffer.BlockCopy(chunk, offset, buffer, destinationOffset + written, take);
                written += take;
                offset += take;
                queuedBytes -= take;
                if (offset == chunk.Length)
                {
                    chunks.Dequeue();
                    offset = 0;
                }
            }
            if (written > 0)
            {
                firstReadSeconds ??= clock.Elapsed.TotalSeconds;
                consumedBytes += written;
                starving = false;
            }
            if (!complete)
            {
                minimumHeadroom = Math.Min(minimumHeadroom, Seconds(queuedBytes));
                if (written < count)
                {
                    // Keep the device running, but count every inserted silence frame.
                    Array.Clear(buffer, destinationOffset + written, count - written);
                    missingBytes += count - written;
                    if (!starving)
                        underruns++;
                    starving = true;
                    return count;
                }
            }
            return written;
        }
    }

    public QueueMeasurements Snapshot()
    {
        lock (gate)
            return new QueueMeasurements(firstReadSeconds, underruns, Seconds(missingBytes),
                double.IsPositiveInfinity(minimumHeadroom) ? null : minimumHeadroom,
                maximumHeadroom, Seconds(consumedBytes), Seconds(queuedBytes), complete);
    }

    private double Seconds(long bytes) => (double)bytes / WaveFormat.AverageBytesPerSecond;

    public static void SelfTest()
    {
        var queue = new MeasuredAudioQueue(Stopwatch.StartNew());
        var buffer = new byte[960];
        queue.Enqueue(new float[240], false);
        if (queue.Read(buffer, 0, buffer.Length) != 960)
            throw new InvalidOperationException("Initial audio was not read.");
        queue.Read(buffer, 0, buffer.Length);
        queue.Read(buffer, 0, buffer.Length);
        var gap = queue.Snapshot();
        if (gap.Underruns != 1 || Math.Abs(gap.InsertedSilenceSeconds - 0.02) > 1e-9)
            throw new InvalidOperationException("Starvation duration or episode count was wrong.");
        queue.Enqueue(new float[120], true);
        if (queue.Read(buffer, 0, buffer.Length) != 480 || queue.Read(buffer, 0, buffer.Length) != 0)
            throw new InvalidOperationException("Final partial buffer did not terminate correctly.");
        var final = queue.Snapshot();
        if (final.Underruns != 1 || final.RemainingSeconds != 0 ||
            Math.Abs(final.ConsumedAudioSeconds - 0.015) > 1e-9)
            throw new InvalidOperationException("Final drain was counted as starvation.");
        var uninterrupted = new MeasuredAudioQueue(Stopwatch.StartNew());
        uninterrupted.Enqueue(new float[480], false);
        uninterrupted.Read(buffer, 0, buffer.Length);
        uninterrupted.Enqueue(new float[240], true);
        while (uninterrupted.Read(buffer, 0, buffer.Length) > 0) { }
        if (uninterrupted.Snapshot().Underruns != 0)
            throw new InvalidOperationException("Continuous playback was counted as starvation.");
        Console.WriteLine("Audio queue checks passed: continuous playback, starvation, recovery, and final drain.");
    }
}

record QueueMeasurements(double? FirstPcmReadSeconds, int Underruns, double InsertedSilenceSeconds,
    double? MinimumHeadroomWhileProducingSeconds, double MaximumHeadroomSeconds,
    double ConsumedAudioSeconds, double RemainingSeconds, bool ProducerCompleted);
