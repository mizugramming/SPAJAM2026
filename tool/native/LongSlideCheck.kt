package jp.spajam.polish_workshop

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** Very slow motion has a long interval of almost zero acceleration at maximum speed. */
internal fun checkLongSlides() {
    val down = floatArrayOf(0f, 0f, 9.81f)
    for (hz in listOf(60, 100)) for (half in listOf(1.2, 1.5, 1.8, 2.0)) {
        for (stopPhase in listOf(.25, .5, .75)) {
            val motion = DeskMotion()
            val haptics = DeskHaptics("coarse", .1, 65, 224)
            val distance = .15
            val omega = PI / half
            val cutoff = 1.0 + (4 + stopPhase) * half
            val end = cutoff + .08
            val atBrake = distance * omega * .5 * sin(PI * stopPhase)
            val starts = IntArray(5)
            var waveform = longArrayOf()
            var started = 0L
            var motorEnd = -1L
            var center = 0
            var centerOn = 0
            for (i in 0..((end + .65) * hz).toInt()) {
                val ns = i * 1_000_000_000L / hz
                val t = i.toDouble() / hz
                val leg = kotlin.math.floor((t - 1) / half + 1e-8).toInt()
                val u = (t - 1) / half - leg
                val hand = when {
                    t in 1.0..<cutoff -> {
                        val sign = if (leg % 2 == 0) 1 else -1
                        sign * distance * omega * omega * .5 * cos(PI * u)
                    }
                    t in cutoff..<end -> {
                        val v = (t - cutoff) / .08
                        -atBrake * 6 * v * (1 - v) / .08
                    }
                    else -> 0.0
                }
                // First pulse is external. Subsequent motor noise follows each issued packet.
                if (i == hz / 5) {
                    motion.motorStarted(ns, 180)
                    motorEnd = ns + 180_000_000L
                }
                val buzz = if (ns < motorEnd) .42 * sin(2 * PI * 19 * t) else 0.0
                val input = hand + buzz + .025 * sin(2 * PI * 19 * t)
                motion.gravity(ns, down)
                val sample = motion.update(ns, floatArrayOf(input.toFloat(), 0f, down[2]))
                val wave = haptics.sample(ns, sample)
                if (wave != null) {
                    started = ns
                    waveform = wave.timings
                    motorEnd = ns + wave.durationMs * 1_000_000L
                    if (wave === DeskFeedback.stop) {
                        motion.motorStopped(ns)
                    } else {
                        check(t in 1.0..<cutoff && u < .7) { "Off-phase command at $t, half=$half, u=$u" }
                        starts[leg]++
                        motion.motorStarted(ns, wave.durationMs)
                    }
                }
                var elapsed = (ns - started) / 1e6
                var on = false
                for ((index, ms) in waveform.withIndex()) {
                    if (elapsed < ms) {
                        on = index % 2 == 1
                        break
                    }
                    elapsed -= ms
                }
                if (leg in 0..3 && u in .35.. .65) {
                    center++
                    if (on) centerOn++
                }
                if (t >= end) check(!on) { "Motor still on after braking: ${t-end}s" }
                if (t < 1 || t >= end) check(!sample.stroke)
            }
            check(starts.take(4).all { it == 1 } && 2 * centerOn >= center) {
                "${hz}Hz half=$half cut=$stopPhase: starts=${starts.toList()}, motor-on at center=$centerOn/$center"
            }
        }
    }
    // Smooth 20° tilt with gravity delivered 80 ms late, no translation.
    val motion = DeskMotion()
    val haptics = DeskHaptics("coarse", .1, 65, 224)
    fun gravityAt(t: Double): FloatArray {
        val angle = if (t in 1.0..8.2) (20 * PI / 180) * (1 - cos(2 * PI * (t - 1) / 2.4)) / 2 else 0.0
        return floatArrayOf((9.81 * sin(angle)).toFloat(), 0f, (9.81 * cos(angle)).toFloat())
    }
    for (i in 0..950) {
        val ns = i * 10_000_000L
        motion.gravity(ns, gravityAt(i / 100.0 - .08))
        val sample = motion.update(ns, gravityAt(i / 100.0))
        check(!sample.stroke && haptics.sample(ns, sample) == null)
    }
}

/** A pair spans two opposite legs on the work plane, including a short endpoint dwell. */
internal fun checkSlowStrokeCounts() {
    fun verify(halves: List<Double>, expected: Int, pause: Double = 0.0, lift: Boolean = false,
               sameDirection: Boolean = false) {
        val starts = halves.runningFold(1.0) { start, half -> start + half + pause }
        val gravity = floatArrayOf(0f, 0f, 9.81f)
        for (hz in listOf(60, 100)) {
            val motion = DeskMotion()
            val haptics = DeskHaptics("coarse", .1, 65, 224)
            var count = 0
            for (i in 0..((starts.last() + .7) * hz).toInt()) {
                val ns = i * 1_000_000_000L / hz
                val t = i.toDouble() / hz
                val k = halves.indices.firstOrNull { t >= starts[it] && t < starts[it] + halves[it] }
                val acceleration = if (k == null) 0.0 else {
                    val u = (t - starts[k]) / halves[k]
                    val sign = if (sameDirection || k % 2 == 0) 1 else -1
                    sign * .15 * (60*u - 180*u*u + 120*u*u*u) / (halves[k] * halves[k])
                }
                val idle = t - (1 + halves.first())
                val up = if (lift && idle in 0.0.. .45) 3 * sin(PI * idle / .45) else 0.0
                val x = acceleration + .025 * sin(2 * PI * 19 * t)
                motion.gravity(ns, gravity)
                val state = motion.update(ns, floatArrayOf(x.toFloat(), 0f, (9.81 + up).toFloat()))
                if (state.stroke) count++
                val wave = haptics.sample(ns, state)
                if (wave != null) {
                    if (wave === DeskFeedback.stop) motion.motorStopped(ns) else motion.motorStarted(ns, wave.durationMs)
                }
            }
            check(count == expected) { "${hz}Hz halves=$halves pause=$pause lift=$lift: $count/$expected strokes" }
        }
    }
    verify(List(8) { 1.5 }, 4)
    verify(List(8) { 1.5 }, 4, pause = .12)
    verify(List(8) { if (it % 2 == 0) .65 else 1.5 }, 4)
    verify(List(8) { if (it % 2 == 0) 1.5 else .65 }, 4)
    verify(List(4) { 1.5 } + List(4) { .35 } + List(4) { 1.5 }, 6)
    verify(listOf(1.5), 0)
    verify(listOf(1.5, 1.5), 0, pause = 1.1)
    verify(listOf(1.5, 1.5), 0, pause = 1.1, lift = true)
    verify(listOf(1.5, 1.5), 0, pause = .12, sameDirection = true)
}
