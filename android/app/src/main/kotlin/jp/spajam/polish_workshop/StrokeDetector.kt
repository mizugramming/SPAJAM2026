package jp.spajam.polish_workshop

import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.sqrt

/** One signed cycle along a measured 3D axis (positive → negative → positive). Units are m/s² and ns. */
internal class StrokeDetector {
    private val gravity = DoubleArray(3)
    private val signal = DoubleArray(3)
    private val axis = DoubleArray(3)
    private var lastTime = -1L
    private var ignoreUntil = 0L
    private var lastLobe = 0L
    private var acceptedSign = 0
    private var candidate = 0
    private var candidateSince = 0L

    fun maskMotor(startNs: Long, durationMs: Int) {
        // Use the sensor timestamp clock. Preserve the accepted half-stroke across the brief mask.
        ignoreUntil = maxOf(ignoreUntil, startNs + (durationMs + 55L) * 1_000_000)
        candidate = 0
        signal.fill(0.0)
    }

    fun update(time: Long, values: FloatArray): Boolean {
        if (lastTime != -1L && time <= lastTime) return false
        val elapsed = time - lastTime
        if (lastTime == -1L || elapsed > 250_000_000L) {
            for (i in 0..2) gravity[i] = values[i].toDouble()
            signal.fill(0.0)
            resetCycle()
            lastTime = time
            return false
        }
        lastTime = time
        if (time <= ignoreUntil) return false
        val dt = elapsed / 1_000_000_000.0
        val gravityGain = 1.0 - exp(-dt / 0.65)
        val signalGain = 1.0 - exp(-dt / 0.045)
        for (i in 0..2) {
            gravity[i] += gravityGain * (values[i] - gravity[i])
            signal[i] += signalGain * (values[i] - gravity[i] - signal[i])
        }
        if (acceptedSign != 0 && time - lastLobe > 850_000_000L) resetCycle()
        val magnitude = sqrt(signal.sumOf { it * it })
        if (magnitude < 1.05) {
            candidate = 0
            return false
        }
        if (acceptedSign == 0 && candidate == 0) {
            for (i in 0..2) axis[i] = signal[i] / magnitude
        }
        val projection = signal.indices.sumOf { signal[it] * axis[it] }
        if (abs(projection) < 1.05 || abs(projection) < magnitude * 0.60) {
            candidate = 0
            return false
        }
        val sign = if (projection > 0) 1 else -1
        if (sign == acceptedSign || (acceptedSign == 0 && sign < 0)) {
            candidate = 0
            return false
        }
        if (sign != candidate) {
            candidate = sign
            candidateSince = time
            return false
        }
        if (time - candidateSince < 35_000_000L) return false
        if (acceptedSign != 0 && time - lastLobe < 145_000_000L) return false
        val cycleComplete = sign == 1 && acceptedSign == -1
        acceptedSign = sign
        lastLobe = time
        candidate = 0
        return cycleComplete
    }

    private fun resetCycle() {
        acceptedSign = 0
        candidate = 0
    }
}
