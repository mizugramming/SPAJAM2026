package jp.spajam.polish_workshop

import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.sqrt

internal data class DeskBaseline(val gravityMagnitude: Double, val noiseRms: Double)

/** Last continuous stationary interval while the player records a voice sample. */
internal class DeskCalibration {
    private val mean = DoubleArray(3)
    private var count = 0
    private var variation = 0.0
    private var firstNs = 0L
    private var lastNs = -1L

    fun add(timeNs: Long, xyz: FloatArray) {
        if (timeNs <= lastNs || xyz.size < 3) return
        var distance2 = 0.0
        var magnitude2 = 0.0
        for (i in 0..2) {
            val x = xyz[i].toDouble()
            distance2 += (x - mean[i]) * (x - mean[i])
            magnitude2 += x * x
        }
        val plausibleGravity = magnitude2 in 8.8 * 8.8..10.8 * 10.8
        if (timeNs - lastNs > 100_000_000L || distance2 > 0.8 * 0.8 || !plausibleGravity) {
            count = 0
            variation = 0.0
        }
        lastNs = timeNs
        if (!plausibleGravity) return
        if (count == 0) firstNs = timeNs
        count++
        for (i in 0..2) {
            val delta = xyz[i] - mean[i]
            mean[i] += delta / count
            variation += delta * (xyz[i] - mean[i])
        }
    }

    fun finish(): DeskBaseline? {
        if (count < 12 || lastNs - firstNs < 250_000_000L) return null
        val noise = sqrt(variation.coerceAtLeast(0.0) / count)
        if (noise > 0.30) return null
        return DeskBaseline(sqrt(mean.sumOf { it * it }), noise)
    }
}

internal data class DeskSample(
    val contact: Boolean,
    val began: Boolean = false,
    val ended: Boolean = false,
    val stroke: Boolean = false,
    val cadenceMs: Int? = null,
    val moving: Boolean = false,
)

/** One play round. All timestamps (including motor commands) share Android's elapsed realtime clock. */
internal class DeskMotion(baseline: DeskBaseline? = null) {
    private val gravityMagnitude = baseline?.gravityMagnitude ?: 9.81
    private val threshold = max(1.05, (baseline?.noiseRms ?: 0.0) * 4.0)
    private val normal = DoubleArray(3)
    private val smoothed = DoubleArray(3)
    private val planar = DoubleArray(3)
    private val axis = DoubleArray(3)
    private var lastNs = -1L
    private var gravityNs = -1L
    private var idlePower = 0.0
    private var candidateNs = -1L
    private var lastMotionNs = -1L
    private var contact = false
    private var liftUntilNs = -1L
    private var motorStartNs = -1_000_000_000L
    private var motorEndNs = -1_000_000_000L
    private val cycle = StrokeDetector()

    /** A gravity sensor follows changes in grip independent of the initial desk orientation. */
    fun gravity(timeNs: Long, xyz: FloatArray) {
        if (timeNs <= gravityNs || xyz.size < 3) return
        val length = sqrt((0..2).sumOf { xyz[it].toDouble() * xyz[it] })
        if (length !in 7.0..12.0) return
        for (i in 0..2) normal[i] = xyz[i] / length
        gravityNs = timeNs
    }

    fun motorStarted(timeNs: Long, durationMs: Int) {
        if (durationMs <= 0) return
        if (!contact) cycle.resetCycle()
        motorStartNs = timeNs
        motorEndNs = timeNs + durationMs * 1_000_000L
    }

    fun motorStopped(timeNs: Long) {
        motorEndNs = minOf(motorEndNs, timeNs)
    }

    fun update(timeNs: Long, xyz: FloatArray): DeskSample {
        if (timeNs <= lastNs || xyz.size < 3 || (0..2).any { !xyz[it].isFinite() }) return DeskSample(contact)
        val gap = timeNs - lastNs
        val first = lastNs < 0 || gap > 200_000_000L
        lastNs = timeNs
        val hasGravity = gravityNs >= 0 && timeNs - gravityNs in -20_000_000L..250_000_000L
        if (first) {
            val ended = contact
            endContact()
            idlePower = 0.0
            for (i in 0..2) smoothed[i] = xyz[i].toDouble()
            if (!hasGravity) {
                val length = sqrt(smoothed.sumOf { it * it })
                if (length < 1) {
                    lastNs = -1
                    return DeskSample(false, ended = ended)
                }
                for (i in 0..2) normal[i] = smoothed[i] / length
            }
            return DeskSample(false, ended = ended)
        }
        val motorNoise = timeNs >= motorStartNs && timeNs < motorEndNs + 55_000_000L
        val motorEdge = motorNoise && (timeNs < motorStartNs + 22_000_000L || timeNs >= motorEndNs)
        val dt = gap / 1e9
        val gain = 1.0 - exp(-dt / 0.032)
        for (i in 0..2) smoothed[i] += gain * (xyz[i] - smoothed[i])
        val alongGravity = (0..2).sumOf { smoothed[it] * normal[it] }
        val vertical = abs(alongGravity - gravityMagnitude)
        for (i in 0..2) planar[i] = smoothed[i] - normal[i] * alongGravity
        val horizontal = sqrt(planar.sumOf { it * it })

        if (!hasGravity) {
            // Slow fallback for phones without a fused gravity sensor. During a
            // horizontal stroke keep the work plane from following the hand.
            val rotate = 1 - exp(-dt / if (contact || candidateNs >= 0) 2.0 else 0.45)
            val length = sqrt(smoothed.sumOf { it * it }).coerceAtLeast(1.0)
            for (i in 0..2) normal[i] += rotate * (smoothed[i] / length - normal[i])
            val n = sqrt(normal.sumOf { it * it }).coerceAtLeast(0.001)
            for (i in 0..2) normal[i] /= n
        }

        if (!motorEdge && vertical > max(if (motorNoise) 1.65 else 1.05, 1.28 * horizontal)) {
            liftUntilNs = timeNs + 80_000_000L
        }
        if (timeNs < liftUntilNs) {
            val ended = contact
            endContact()
            return DeskSample(false, ended = ended)
        }
        val opening = !contact
        // Recent hand tremor or motor settling raises the evidence needed for a
        // first touch. A push from a quiet resting grip keeps the low threshold.
        val onsetThreshold = max(threshold, minOf(2.5, 3.0 * sqrt(idlePower)))
        if (opening) {
            val bounded = minOf(horizontal, 2.5)
            idlePower += (1 - exp(-dt / 0.32)) * (bounded * bounded - idlePower)
            // A round may begin mid-motion. Consecutive lobes in the same plane
            // can prove a full cycle even if tremor masks an isolated first push.
            if (!motorNoise && horizontal >= 1.1 * vertical && cycle.updatePlanar(timeNs, planar)) {
                cycle.copyPlanarAxis(axis)
                contact = true
                lastMotionNs = timeNs
                return DeskSample(true, began = true, stroke = true, cadenceMs = cycle.estimatedPeriodMs, moving = true)
            }
        }
        if (opening && (motorNoise || horizontal < onsetThreshold || horizontal < 1.1 * vertical)) {
            candidateNs = -1
            return DeskSample(false)
        }
        if (opening && candidateNs < 0) {
            for (i in 0..2) axis[i] = planar[i] / horizontal
            candidateNs = timeNs
        }
        val projection = (0..2).sumOf { planar[it] * axis[it] }
        if (opening) {
            if (projection < 0.72 * horizontal) {
                candidateNs = -1
                return DeskSample(false)
            }
            if (timeNs - candidateNs < 20_000_000L) return DeskSample(false)
            // The early touch may shortly mask this lobe. Seed the same
            // direction the hand actually sustained before the motor turned on.
            cycle.beginPlanar(candidateNs, axis)
            contact = true
            lastMotionNs = timeNs
            return DeskSample(true, began = true, moving = true)
        }

        // A motor edge needs stronger evidence. Requiring the current sample
        // to agree with the filtered direction also limits ringing after a stop.
        val minimum = when {
            motorEdge -> max(1.55, threshold)
            motorNoise -> max(1.20, threshold)
            else -> threshold * 0.58
        }
        val rawGravity = (0..2).sumOf { xyz[it] * normal[it] }
        val direct = (0..2).sumOf { (xyz[it] - rawGravity * normal[it]) * axis[it] }
        val moving = abs(projection) >= max(minimum, horizontal * 0.62) && direct * projection > 0 &&
            abs(direct) >= threshold * 0.58
        if (moving) lastMotionNs = timeNs
        // A slower return can pass through a longer acceleration minimum. Keep
        // this window independent of the previous rhythm; the motor has its own watchdog.
        if (timeNs - lastMotionNs >= 185_000_000L) {
            endContact()
            return DeskSample(false, ended = true)
        }
        val stroke = cycle.updatePlanar(timeNs, planar)
        return DeskSample(true, stroke = stroke, cadenceMs = cycle.estimatedPeriodMs, moving = moving)
    }

    private fun endContact() {
        cycle.resetCycle()
        candidateNs = -1
        lastMotionNs = -1
        contact = false
    }
}
