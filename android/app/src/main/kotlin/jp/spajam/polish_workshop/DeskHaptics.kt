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
        val reference = maxOf(state.passPeakMps, .15)
        val slowPass = state.passPeakMps < slowPeakMps && (state.cadenceMs ?: 1200) >= 650
        val acceleration = direction * state.alongAccelerationMps2
        // Lead the motor command briefly on slow glides, including the brake.
        // Bound the lead relative to this pass so a turn cannot start a pulse by itself.
        val glideSpeed = if (slowPass) {
            speed + (acceleration * .045).coerceIn(-reference * .30, reference * .17)
        } else speed
        // Let a pass sound on the glide and release it as the hand approaches rest.
        if (direction != playedDirection && speed >= maxOf(.055, reference * .16)) {
            // An asymmetric return may be too gentle to sound but still begins a new pass.
            playedDirection = 0
            if (cancelActive(timeNs)) return DeskFeedback.stop
        }
        if (glideSpeed < maxOf(.045, reference * .43)) {
            return if (cancelActive(timeNs)) DeskFeedback.stop else null
        }
        if (timeNs < endNs && state.passPeakMps >= compactAtMps && timeNs - startedNs >= 80_000_000L) {
            return if (cancelActive(timeNs)) DeskFeedback.stop else null
        }
        // A delayed sensor event can end a command, but must not start one
        // after the hand has already moved on. The next fresh event may start it.
        if (!state.moving || direction == playedDirection || evidenceNs < quietUntilNs ||
            timeNs - evidenceNs > 40_000_000L) return null
        val minSpeed = if (slowPass) .055 else .075
        if (speed < minSpeed || glideSpeed < reference * .65 || (slowPass && acceleration < -.25)) return null
        playedDirection = direction
        val fast = compactTexture(state.cadenceMs?.coerceIn(230, 1250) ?: 370)
        val portion = ((state.passPeakMps - slowPeakMps) / (compactAtMps - slowPeakMps)).coerceIn(0.0, 1.0)
        val fastMs = fast.sum().toInt()
        val slowMs = (850 * (.25 + .75 * length / 65).coerceIn(.30, 1.0)).roundToInt()
        val width = (slowMs + portion * (fastMs - slowMs)).roundToInt()
        // Cadence only limits the command to the time available on this pass.
        val availableMs = state.cadenceMs?.let { (it * .62 / 2).roundToInt() } ?: slowMs
        val budget = minOf(width, maxOf(availableMs, fastMs))
        return play(timeNs, if (budget <= fastMs) fast else texture(budget))
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

    private fun compactTexture(periodMs: Int): LongArray {
        // Reserve motor settling time and one 60 Hz sensor frame before the next half-stroke.
        val maxMs = (periodMs / 2 - 77).coerceIn(50, 80)
        val widthMs = 50 + ((maxMs - 50) * (length / 68.0).coerceIn(0.0, 1.0)).roundToInt()
        val duty = when (grit) {
            "coarse" -> 1.0
            "medium" -> .78
            else -> .55
        }
        val onMs = (widthMs * duty * (1 - .25 * finish)).roundToInt()
        val gapMs = widthMs - onMs
        if (gapMs < 8) return longArrayOf(0, widthMs.toLong())
        val firstMs = (onMs + 1) / 2
        return longArrayOf(0, firstMs.toLong(), gapMs.toLong(), (onMs - firstMs).toLong())
    }

    private fun texture(budgetMs: Int): LongArray {
        // Coarse keeps a long rasp; finer grains subdivide each envelope into shorter contacts.
        val (roughOnMs, gapMs) = when (grit) {
            "coarse" -> 270 to 16
            "medium" -> 78 to 22
            else -> 27 to 27
        }
        val onMs = (roughOnMs * (1 - .32 * finish)).roundToInt()
        val offMs = (gapMs * (1 + .65 * finish)).roundToInt()
        var remaining = budgetMs
        val timings = mutableListOf(0L)
        while (remaining > 0) {
            val on = minOf(remaining, onMs)
            timings.add(on.toLong())
            remaining -= on
            // No trailing rest or sub-perceptible final fragment.
            if (remaining < offMs + 8) break
            timings.add(offMs.toLong())
            remaining -= offMs
        }
        return timings.toLongArray()
    }
}
