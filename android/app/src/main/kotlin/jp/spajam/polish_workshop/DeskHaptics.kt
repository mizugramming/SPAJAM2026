package jp.spajam.polish_workshop

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
    private var intervalMs = 0
    private var inContact = false

    fun update(progress: Double, durationMs: Int, amplitude: Int) {
        finish = progress
        length = durationMs
        strength = amplitude
    }

    fun sample(timeNs: Long, state: DeskSample, evidenceNs: Long = timeNs): DeskFeedback? {
        if (state.ended || !state.contact) {
            inContact = false
            return if (cancelActive(timeNs)) DeskFeedback.stop else null
        }
        if (state.began) {
            inContact = true
            lastEvidenceNs = evidenceNs
            // Leave an interval to observe the very first reversal.
            val touchMs = (10 + length * .45).roundToInt().coerceIn(12, 42)
            if (evidenceNs < quietUntilNs) return null
            return play(timeNs, touchMs + 75, longArrayOf(0, touchMs.toLong()))
        }
        if (!inContact) return null
        if (expire(timeNs)) return DeskFeedback.stop
        if (!state.moving) return null
        lastEvidenceNs = evidenceNs
        val periodMs = state.cadenceMs?.coerceIn(230, 1250) ?: 230
        if (timeNs < endNs && periodMs * 4 < intervalMs * 3) {
            // A quick new rhythm can cut a long, slow envelope short.
            return if (cancelActive(timeNs)) DeskFeedback.stop else null
        }
        // Require hand evidence after all motor-on slots and their settling time.
        if (evidenceNs < quietUntilNs) return null
        if (state.cadenceMs != null && periodMs <= 500) {
            // One short rasp on each verified push or pull. Its two directions still score one stroke.
            val reversalNs = state.lastReversalNs ?: return null
            if (reversalNs <= startedNs || evidenceNs - reversalNs !in 0L..45_000_000L) return null
            return play(timeNs, periodMs / 2, compactTexture(periodMs))
        }
        val nextNs = startedNs + minOf(intervalMs, periodMs) * 1_000_000L
        if (timeNs < nextNs) return null
        val envelopeMs = if (state.cadenceMs == null) 80 else
            (80 + (periodMs - 500) * 920 / 700).coerceAtMost(1000)
        val scaled = (envelopeMs * (.25 + .75 * length / 65).coerceIn(.30, 1.0)).roundToInt()
        val budget = minOf(scaled, periodMs - 90).coerceAtLeast(1)
        return play(timeNs, periodMs, texture(budget))
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

    private fun play(timeNs: Long, periodMs: Int, timings: LongArray): DeskFeedback {
        val feedback = DeskFeedback(timings, strength)
        startedNs = timeNs
        endNs = timeNs + feedback.durationMs * 1_000_000L
        quietUntilNs = endNs + 60_000_000L
        intervalMs = periodMs
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
