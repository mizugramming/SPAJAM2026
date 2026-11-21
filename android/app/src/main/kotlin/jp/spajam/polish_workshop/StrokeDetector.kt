package jp.spajam.polish_workshop

import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** One signed cycle along a measured 3D axis (positive → negative → positive). Units are m/s² and ns. */
internal class StrokeDetector {
    private companion object {
        // The REDMI trace includes hand-like cycles about 230–250 ms apart.
        const val minHalfNs = 110_000_000L
    }

    private val gravity = DoubleArray(3)
    private val signal = DoubleArray(3)
    private val axis = DoubleArray(3)
    private var lastTime = -1L
    private var ignoreUntil = 0L
    private var fixedAmplitudeStroke = false
    private var steadyMotorFrom = Long.MAX_VALUE
    private var steadyMotorUntil = 0L
    private var longMotorPulse = false
    private var stopMotor = false
    private var lastLobe = 0L
    private var outwardHalfNs = 0L
    private var shorterHalfNs = 0L
    private var cycleNs = 0L
    private var previousCycleNs = 0L
    private var lastStrokeNs = 0L
    private var negativeLobeStrength = 0.0
    private var pendingStrokePulse = false
    private var acceptedSign = 0
    private var candidate = 0
    private var candidateSince = 0L
    private var negativeDuringMotor = false

    fun takeStrokePulse(): Boolean {
        if (!pendingStrokePulse) return false
        pendingStrokePulse = false
        return true
    }

    fun maskMotor(startNs: Long, durationMs: Int, fixedAmplitudeStroke: Boolean = false) {
        // Use the sensor timestamp clock. Preserve the accepted half-stroke across the brief mask.
        val endNs = startNs + durationMs * 1_000_000L
        // Android replaces an ongoing one-shot when the next stroke plays.
        ignoreUntil = endNs + 55_000_000L
        this.fixedAmplitudeStroke = fixedAmplitudeStroke
        longMotorPulse = fixedAmplitudeStroke && durationMs >= 500
        stopMotor = false
        // Only long feedback triggered by a proven hand cycle has a usable
        // steady interval. Blank its motor startup, shutdown and settling.
        steadyMotorFrom = if (fixedAmplitudeStroke && durationMs >= 150 && shorterHalfNs > 0) {
            startNs + 55_000_000L
        } else Long.MAX_VALUE
        steadyMotorUntil = endNs
        candidate = 0
        signal.fill(0.0)
    }

    fun takeEarlyStop(nowNs: Long): Boolean {
        if (!stopMotor) return false
        stopMotor = false
        if (nowNs >= steadyMotorUntil) return false
        steadyMotorFrom = Long.MAX_VALUE
        ignoreUntil = nowNs + 55_000_000L
        candidate = 0
        signal.fill(0.0)
        return true
    }

    fun strokePulseDuration(requestedMs: Int, startNs: Long, hasAmplitudeControl: Boolean): Int {
        val delayNs = (startNs - lastStrokeNs).coerceAtLeast(0L)
        if (hasAmplitudeControl) {
            if (shorterHalfNs == 0L) return requestedMs
            val availableMs = (shorterHalfNs - delayNs) / 1_000_000.0
            val scale = ((availableMs - 95) / 125).coerceIn(0.10, 1.0)
            val floorMs = minOf(requestedMs, 6)
            return (floorMs + (requestedMs - floorMs) * scale).roundToInt()
        }
        // Leave a little more quiet time after a weak reversal close to the
        // stationary motor noise floor. Strong slow strokes get the full second.
        val fullMs = (480 + 8 * requestedMs).coerceAtMost(if (negativeLobeStrength < 2.5) 950 else 1000)
        if (shorterHalfNs == 0L) return fullMs
        val fastMs = (22.0 + requestedMs / 3.0).roundToInt().coerceAtMost(45)
        val tappingMs = (100.0 + 150.0 * requestedMs / 65).roundToInt().coerceAtMost(250)
        var periodNs = if (previousCycleNs > 0) minOf(cycleNs, previousCycleNs) else cycleNs
        // A long apparent period containing a rapid half can be a missed return.
        // Shorten just the feedback so the next reversal remains observable.
        if (periodNs > 4 * minHalfNs && shorterHalfNs < 145_000_000L) periodNs = 2 * shorterHalfNs
        val periodMs = periodNs / 1_000_000.0
        // One pulse per stroke. Blend the rapid tap, 250-on/120-off reference
        // and slow 1 s reference. Subtract dispatch delay from the quiet window.
        val quick = periodMs < 350
        val blend = if (quick) {
            ((periodMs - 275) / 75).coerceIn(0.0, 1.0)
        } else {
            ((periodMs - 500) / 550).coerceIn(0.0, 1.0)
        }
        val desiredMs = if (quick) fastMs + (tappingMs - fastMs) * blend else tappingMs + (fullMs - tappingMs) * blend
        val longestMs = if (quick) 45 + (250 - 45) * blend else 250 + (1000 - 250) * blend
        val budgetMs = (periodMs - 105 - delayNs / 1_000_000.0).coerceAtLeast(45.0)
        // Apply the budget to all surfaces proportionally so their differences remain tactile.
        return (desiredMs * (budgetMs / longestMs).coerceAtMost(1.0)).roundToInt()
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
        val steadyMotor = time >= steadyMotorFrom && time < steadyMotorUntil
        if (time <= ignoreUntil && !steadyMotor) {
            candidate = 0
            signal.fill(0.0)
            return false
        }
        val dt = elapsed / 1_000_000_000.0
        val gravityGain = 1.0 - exp(-dt / 0.65)
        val signalGain = 1.0 - exp(-dt / 0.045)
        for (i in 0..2) {
            gravity[i] += gravityGain * (values[i] - gravity[i])
            signal[i] += signalGain * (values[i] - gravity[i] - signal[i])
        }
        if (acceptedSign != 0 && time - lastLobe > 850_000_000L) resetCycle()
        val magnitude = sqrt(signal.sumOf { it * it })
        // The stationary REDMI stayed below 0.91 m/s² after smoothing during
        // the steady part of 250 ms and 1 s pulses. Demand stronger, aligned
        // hand motion in that interval and never acquire an axis from motor noise.
        val threshold = if (!steadyMotor) 1.05 else if (longMotorPulse) 1.15 else 3.0
        val alignment = if (steadyMotor) 0.75 else 0.60
        if ((steadyMotor && acceptedSign == 0) || magnitude < threshold) {
            candidate = 0
            return false
        }
        if (acceptedSign == 0 && candidate == 0) {
            for (i in 0..2) axis[i] = signal[i] / magnitude
        }
        val projection = signal.indices.sumOf { signal[it] * axis[it] }
        if (abs(projection) < threshold || abs(projection) < magnitude * alignment) {
            candidate = 0
            return false
        }
        val sign = if (projection > 0) 1 else -1
        // A motor may corroborate the negative lobe, but can never complete a
        // stroke or schedule its own next pulse. Require fresh motor-off samples.
        if (steadyMotor && sign > 0) {
            if (longMotorPulse && negativeDuringMotor && acceptedSign == -1 && projection >= 3.0 &&
                time - lastStrokeNs >= 2 * minHalfNs) {
                if (candidate != sign) {
                    candidate = sign
                    candidateSince = time
                } else if (time - candidateSince >= 25_000_000L) {
                    stopMotor = true
                }
            } else candidate = 0
            return false
        }
        if (sign == acceptedSign || (acceptedSign == 0 && sign < 0)) {
            candidate = 0
            return false
        }
        if (sign != candidate) {
            candidate = sign
            candidateSince = time
            return false
        }
        val cycleComplete = sign == 1 && acceptedSign == -1
        val maskedReturn = cycleComplete && shorterHalfNs > 0 &&
            lastStrokeNs < ignoreUntil && time > ignoreUntil &&
            (ignoreUntil < lastLobe || negativeDuringMotor) && time - lastStrokeNs >= 2 * minHalfNs
        // A negative lobe was confirmed on this axis. Two or more motor-off
        // positive samples can finish a strong return after the settling period.
        val strongReturn = !steadyMotor && fixedAmplitudeStroke && maskedReturn && projection >= 2.0
        val holdNs = when {
            strongReturn || (steadyMotor && projection <= -4.0) -> 16_000_000L
            steadyMotor && longMotorPulse -> 50_000_000L
            else -> 35_000_000L
        }
        if (time - candidateSince < holdNs) return false
        if (acceptedSign != 0 && time - lastLobe < minHalfNs && !maskedReturn) return false
        if (cycleComplete) {
            // A preceding pulse may have hidden part of either half-cycle.
            shorterHalfNs = minOf(outwardHalfNs, time - lastLobe)
            previousCycleNs = cycleNs
            cycleNs = outwardHalfNs + time - lastLobe
            lastStrokeNs = time
            pendingStrokePulse = true
        } else if (acceptedSign != 0) {
            outwardHalfNs = time - lastLobe
            negativeDuringMotor = steadyMotor
            negativeLobeStrength = -projection
        }
        acceptedSign = sign
        lastLobe = time
        candidate = 0
        return cycleComplete
    }

    private fun resetCycle() {
        acceptedSign = 0
        candidate = 0
        shorterHalfNs = 0L
        cycleNs = 0L
        previousCycleNs = 0L
        negativeDuringMotor = false
        pendingStrokePulse = false
    }
}
