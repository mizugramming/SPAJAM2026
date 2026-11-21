package jp.spajam.polish_workshop

import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.sqrt

/** A short-lived summary of mono PCM, analysed locally in 64 ms frames. */
internal data class VoiceMeasurement(val hz: Double?, val level: Double)

internal object VoiceAnalysis {
    const val sampleRate = 16_000
    const val sampleCount = sampleRate * 12 / 10
    private const val frame = 1024
    private const val window = frame / 2
    private const val firstLag = sampleRate / 600
    private const val lastLag = sampleRate / 65

    fun measure(pcm: ShortArray): VoiceMeasurement {
        var energy = 0.0
        for (sample in pcm) energy += sample.toDouble() * sample
        val rms = sqrt(energy / pcm.size.coerceAtLeast(1)) / 32768.0
        val level = ((20 * ln(max(rms, 0.000001)) / ln(10.0) + 60) / 60).coerceIn(0.0, 1.0)
        val pitches = mutableListOf<Double>()
        val difference = DoubleArray(lastLag + 1)
        for (offset in 0..(pcm.size - frame) step window) {
            framePitch(pcm, offset, difference)?.let { pitches.add(it) }
        }
        // Require sustained voicing and agreement, so silence or a pitch sweep can be retried.
        if (pitches.size < 7) return VoiceMeasurement(null, level)
        pitches.sort()
        val median = pitches[pitches.size / 2]
        val stable = pitches.filter { abs(it - median) <= median * 0.09 }
        val pitch = if (stable.size * 3 >= pitches.size * 2) stable.average() else null
        return VoiceMeasurement(pitch, level)
    }

    private fun framePitch(pcm: ShortArray, offset: Int, difference: DoubleArray): Double? {
        var energy = 0.0
        var mean = 0.0
        for (i in offset until offset + window) {
            val sample = pcm[i].toDouble()
            mean += sample
            energy += sample * sample
        }
        if (energy / window - (mean / window) * (mean / window) < 100.0 * 100.0) return null

        // Cumulative mean normalized difference (YIN). Choose the first convincing
        // valley, so a multiple of the true period is not preferred for a stronger peak.
        var runningSum = 0.0
        for (lag in 1..lastLag) {
            var sum = 0.0
            for (i in offset until offset + window) {
                val delta = (pcm[i] - pcm[i + lag]).toDouble()
                sum += delta * delta
            }
            runningSum += sum
            difference[lag] = if (runningSum == 0.0) 1.0 else sum * lag / runningSum
        }
        var lag = firstLag
        while (lag <= lastLag && difference[lag] > 0.15) lag++
        if (lag > lastLag) return null
        while (lag < lastLag && difference[lag + 1] < difference[lag]) lag++
        val correction = if (lag < lastLag) {
            val before = difference[lag - 1]
            val after = difference[lag + 1]
            val curvature = before + after - 2.0 * difference[lag]
            if (curvature > 0.0) ((before - after) / (2 * curvature)).coerceIn(-0.5, 0.5) else 0.0
        } else 0.0
        return (sampleRate / (lag + correction)).takeIf { it in 65.0..600.0 }
    }
}
