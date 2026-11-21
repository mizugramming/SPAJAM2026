package jp.spajam.polish_workshop

import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** A short-lived summary of mono PCM, analysed locally in 64 ms frames. */
internal data class VoiceMeasurement(val hz: Double?, val level: Double)

internal object VoiceAnalysis {
    const val sampleRate = 16_000
    const val sampleCount = sampleRate * 12 / 10
    private const val frame = 1024
    private const val window = frame / 2
    private const val minHz = 65
    private const val maxHz = 600
    private const val lastLag = (sampleRate + minHz - 1) / minHz + 3

    fun measure(pcm: ShortArray): VoiceMeasurement {
        var energy = 0.0
        for (sample in pcm) energy += sample.toDouble() * sample
        val rms = sqrt(energy / pcm.size.coerceAtLeast(1)) / 32768.0
        val level = ((20 * ln(max(rms, 0.000001)) / ln(10.0) + 60) / 60).coerceIn(0.0, 1.0)
        val pitches = mutableListOf<Double>()
        for (offset in 0..(pcm.size - frame) step window) {
            framePitch(pcm, offset)?.let { pitches.add(it) }
        }
        // Require sustained voicing and agreement, so silence or a pitch sweep can be retried.
        if (pitches.size < 7) return VoiceMeasurement(null, level)
        pitches.sort()
        val median = pitches[pitches.size / 2]
        val stable = pitches.filter { abs(it - median) <= median * 0.09 }
        val pitch = if (stable.size * 3 >= pitches.size * 2) stable.average() else null
        return VoiceMeasurement(pitch, level)
    }

    private fun framePitch(pcm: ShortArray, offset: Int): Double? {
        val end = offset + frame
        val start = end - window - lastLag
        var frameEnergy = 0.0
        for (i in offset until end) frameEnergy += pcm[i].toDouble() * pcm[i]
        if (frameEnergy / frame < 100.0 * 100.0) return null

        var energy = 0.0
        var mean = 0.0
        for (i in start until start + window) {
            val sample = pcm[i].toDouble()
            mean += sample
            energy += sample * sample
        }
        if (energy / window - (mean / window) * (mean / window) < 100.0 * 100.0) return null

        // Search even the short periods. Skipping them lets an 800 Hz tone match
        // two periods at 400 Hz and incorrectly select fine grit.
        var runningSum = 0.0
        var earlier = 1.0
        var previous = 1.0
        for (lag in 1..lastLag) {
            val difference = differenceAt(pcm, start, lag)
            runningSum += difference
            val normalized = if (runningSum == 0.0) 1.0 else difference * lag / runningSum
            if (lag >= 3 && previous < 0.15 && previous <= earlier && previous < normalized) {
                var period = refinedPeriod(pcm, start, lag - 1)
                // A minimum spanning three cycles gives finer resolution for high voices.
                if (period < 32) {
                    period = refinedPeriod(pcm, start, (3 * period).roundToInt()) / 3
                }
                val hz = sampleRate / period
                // Allow for interpolation at the limits, as in the phone monitor.
                if (hz < minHz - 0.25 || hz > maxHz + 0.25) return null
                return hz.coerceIn(minHz.toDouble(), maxHz.toDouble())
            }
            earlier = previous
            previous = normalized
        }
        return null
    }

    private fun differenceAt(pcm: ShortArray, start: Int, lag: Int): Double {
        var sum = 0.0
        for (i in start until start + window) {
            val delta = (pcm[i] - pcm[i + lag]).toDouble()
            sum += delta * delta
        }
        return sum
    }

    private fun refinedPeriod(pcm: ShortArray, start: Int, lag: Int): Double {
        val before = differenceAt(pcm, start, lag - 1)
        val center = differenceAt(pcm, start, lag)
        val after = differenceAt(pcm, start, lag + 1)
        val curvature = before + after - 2 * center
        val fraction = if (curvature > 0.0) (before - after) / (2 * curvature) else 0.0
        return lag + fraction.coerceIn(-0.5, 0.5)
    }
}
