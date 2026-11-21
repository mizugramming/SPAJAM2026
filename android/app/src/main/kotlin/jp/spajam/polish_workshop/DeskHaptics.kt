package jp.spajam.polish_workshop

import kotlin.math.abs
import kotlin.math.roundToInt

/** A finite Android waveform. Index zero is the initial wait; odd indices are motor-on time. */
internal data class DeskFeedback(val timings: LongArray, val amplitude: Int) {
    val durationMs: Int = timings.sum().toInt()

    /** Clip the Android command itself to the round end even if the UI thread later stalls. */
    fun within(remainingMs: Long): DeskFeedback? {
        if (remainingMs <= 0) return null
        if (durationMs <= remainingMs) return this
        var rest = remainingMs
        val clipped = mutableListOf<Long>()
        for ((index, ms) in timings.withIndex()) {
            if (rest <= 0 || (index % 2 == 0 && ms >= rest)) break
            val part = minOf(ms, rest)
            clipped.add(part)
            rest -= part
        }
        return if (clipped.size >= 2) DeskFeedback(clipped.toLongArray(), amplitude) else null
    }

    companion object {
        val stop = DeskFeedback(longArrayOf(), 0)
    }
}

/** Texture follows fresh horizontal hand motion. A timer may cancel output, never renew it. */
internal class DeskHaptics(
    private val grit: String,
    progress: Double,
    durationMs: Int,
    amplitude: Int
) {
    private var finish = progress
    private var length = durationMs
    private var strength = amplitude
    private var lastEvidenceNs = 0L
    private var startedNs = 0L
    private var endNs = 0L
    private var quietUntilNs = 0L
    private var playedDirection = 0
    private var activePeak = 0.0
    private var inContact = false

    fun update(progress: Double, durationMs: Int, amplitude: Int) {
        finish = progress
        length = durationMs
        strength = amplitude
    }

    fun sample(timeNs: Long, state: DeskSample, evidenceNs: Long = timeNs): DeskFeedback? {
        if (state.ended || !state.contact) {
            inContact = false
            playedDirection = 0
            return if (cancelActive(timeNs)) DeskFeedback.stop else null
        }
        if (state.began) {
            inContact = true
            playedDirection = 0
        }
        if (!inContact) return null
        if (state.moving) lastEvidenceNs = evidenceNs
        if (expire(timeNs)) return DeskFeedback.stop
        if (timeNs - lastEvidenceNs >= 120_000_000L) return null

        val speed = abs(state.signedSpeedMps)
        val direction = if (state.signedSpeedMps >= 0.0) 1 else -1
        val reference = maxOf(state.passPeakMps, .065)
        val period = state.cadenceMs ?: 1200
        val fast = ((state.passPeakMps - slowPeakMps) / (compactAtMps - slowPeakMps)).coerceIn(0.0, 1.0)
        // A fast peak from the previous, longer push can survive into a gentle return.
        // Use the observed reversal spacing to recognize that return independently.
        val slowRhythm = ((period - 690) / 410.0).coerceIn(0.0, 1.0)
        val slow = if (state.cadenceMs == null) slowRhythm * (1 - fast) else slowRhythm
        val lead = maxOf((1 - fast) * ((period - 370) / 280.0).coerceIn(0.0, 1.0), slow)
        val startReference = reference - slow * (reference - .45).coerceAtLeast(0.0)
        val acceleration = direction * state.alongAccelerationMps2
        // Lead the motor command briefly on slow glides, including the brake.
        // Bound the lead relative to this pass so a turn cannot start a pulse by itself.
        val accelerating = acceleration > .12
        val active = direction == playedDirection && timeNs < endNs
        if (active) activePeak = maxOf(activePeak, speed)
        val glideReference = when {
            active -> reference + slow * (activePeak.coerceAtMost(reference) - reference)
            accelerating -> startReference
            else -> reference
        }
        val glideSpeed = speed + lead * (acceleration * (.045 + .015 * slow))
            .coerceIn(-reference * .30, glideReference * (.17 + .02 * slow))
        // Let a pass sound on the glide and release it as the hand approaches rest.
        if (direction != playedDirection && speed >= maxOf(.028, reference * .16)) {
            // An asymmetric return may be too gentle to sound but still begins a new pass.
            playedDirection = 0
            if (cancelActive(timeNs)) return DeskFeedback.stop
        }
        if (glideSpeed < maxOf(.024, glideReference * (.34 + .09 * lead))) {
            return if (cancelActive(timeNs)) DeskFeedback.stop else null
        }
        // Until the first full pass is known, preserve the long initial rasp.
        // A clearly fast glide, braking, lost contact and the watchdog can still end it.
        val trim = if (state.cadenceMs == null) {
            ((state.passPeakMps - 1.20) / (compactAtMps - 1.20)).coerceIn(0.0, 1.0)
        } else fast * (1 - .85 * slow)
        val maximumMs = 850 + trim * (80 - 850)
        if (timeNs < endNs && timeNs - startedNs >= maximumMs * 1_000_000) {
            return if (cancelActive(timeNs)) DeskFeedback.stop else null
        }
        // A delayed sensor event can end a command, but must not start one
        // after the hand has already moved on. The next fresh event may start it.
        if (!state.moving || direction == playedDirection || evidenceNs < quietUntilNs ||
            timeNs - evidenceNs > 40_000_000L) return null
        val fraction = .43 + .22 * lead - .03 * slow
        // Reject a late trigger when braking would bring the hand to rest within motor latency.
        if (speed < .034 || glideSpeed < glideReference * fraction ||
            lead * acceleration < -.25 || speed < -acceleration * .030) return null
        playedDirection = direction
        activePeak = speed
        return play(timeNs, waveform(state, period, fast, slow))
    }

    private fun waveform(state: DeskSample, period: Int, fast: Double, slow: Double): LongArray {
        // Keep the 60 ms motor settling window plus most of a sensor frame before the return.
        val availableMs = (period / 2 - 72).coerceAtLeast(24)
        val compactMax = minOf(availableMs, 80)
        val compactMin = minOf(50, compactMax)
        val shortMs = compactMin + ((compactMax - compactMin) * (length / 68.0).coerceIn(0.0, 1.0)).roundToInt()
        val longMs = (850 * (.25 + .75 * length / 65).coerceIn(.30, 1.0)).roundToInt()
        val longBudget = state.cadenceMs?.let {
            val travelMs = (it * (.37 + .10 * slow)).roundToInt()
            minOf(longMs, travelMs, availableMs).coerceAtLeast(shortMs)
        } ?: longMs
        val tempo = ((1200 - period) / 830.0).coerceIn(0.0, 1.0)
        val speedBlend = .18 * (state.passPeakMps / slowPeakMps).coerceIn(0.0, 1.0) + .82 * fast
        val blend = (1 - (1 - speedBlend) * (1 - .32 * tempo)) * (1 - .88 * slow)
        val width = (longBudget + blend * (shortMs - longBudget)).roundToInt()
        return texture(width, blend, slow)
    }

    private companion object {
        // Median peak speeds from the labelled REDMI training take (SpeedFitKt).
        const val slowPeakMps = .7937
        const val fastPeakMps = 1.7663
        const val compactAtMps = (slowPeakMps + fastPeakMps) / 2
    }

    /** Same elapsed-realtime clock as SensorEvent.timestamp. Handles missing sensor events as well. */
    fun expire(timeNs: Long): Boolean =
        inContact && timeNs - lastEvidenceNs >= 120_000_000L && cancelActive(timeNs)

    private fun cancelActive(timeNs: Long): Boolean {
        if (timeNs >= endNs) return false
        endNs = timeNs
        quietUntilNs = timeNs + 60_000_000L
        return true
    }

    private fun play(timeNs: Long, timings: LongArray): DeskFeedback {
        val feedback = DeskFeedback(timings, strength)
        startedNs = timeNs
        endNs = timeNs + feedback.durationMs * 1_000_000L
        quietUntilNs = endNs + 60_000_000L
        return feedback
    }

    private fun texture(width: Int, blend: Double, slow: Double): LongArray {
        val (roughOn, gap, fastDuty) = when (grit) {
            "coarse" -> Triple(270, 16, 1.0)
            "medium" -> Triple(78, 22, .78)
            else -> Triple(27, 27, .55)
        }
        val slowOn = roughOn * (1 - .32 * finish)
        val slowGap = gap * (1 + .65 * finish)
        val duty = slowOn / (slowOn + slowGap)
        val fastOn = fastDuty * (1 - .25 * finish)
        val onFraction = duty + blend * (fastOn - duty)
        val pulsePeriod = slowOn + slowGap + blend * (width - slowOn - slowGap)
        val offMs = (pulsePeriod * (1 - onFraction)).roundToInt()
        if (offMs < 5) return longArrayOf(0, width.toLong())
        val onMs = (pulsePeriod * onFraction).roundToInt().coerceAtLeast(1)
        // Split the compact packet around one gap. Longer passes carry repeating grit.
        // A slow first contact gives the motor time to spin up before fine grains pulse.
        var nextOn = maxOf(1, (onMs * (1 - .5 * blend)).roundToInt(), (52 * slow).roundToInt())
        var left = width
        val timings = mutableListOf(0L)
        while (left > nextOn + offMs + 3) {
            timings.add(nextOn.toLong())
            timings.add(offMs.toLong())
            left -= nextOn + offMs
            nextOn = onMs
        }
        timings.add(left.toLong())
        return timings.toLongArray()
    }
}
