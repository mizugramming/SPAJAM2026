package jp.spajam.polish_workshop

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.roundToLong
import kotlin.math.sin

/** Known position profile with zero speed at either end of each pass. */
private fun velocityTrial(hz: Int, halfSeconds: Double, distanceM: Double, fused: Boolean): Double {
    val desk = DeskMotion()
    val pitch = .45
    val gravity = floatArrayOf(0f, (9.81 * sin(pitch)).toFloat(), (9.81 * cos(pitch)).toFloat())
    val peak = 1.875 * distanceM / halfSeconds
    val passes = 16
    val end = passes * halfSeconds
    val reported = mutableListOf<Double>()
    val endSpeeds = mutableListOf<Double>()
    val middleSpeeds = mutableListOf<Double>()
    for (i in 0..((1.5 + end) * hz).toInt()) {
        val seconds = i.toDouble() / hz
        val ns = (seconds * 1e9).roundToLong()
        val t = seconds - 1.0
        val pass = floor(t / halfSeconds).toInt()
        val u = t / halfSeconds - pass
        val sign = if (pass % 2 == 0) 1 else -1
        val accel = if (pass in 0 until passes) {
            sign * distanceM * (60 * u - 180 * u * u + 120 * u * u * u) / (halfSeconds * halfSeconds)
        } else 0.0
        if (fused) desk.gravity(ns, gravity)
        val x = accel + .14 * sin(2 * PI * 19 * seconds)
        val frame = desk.update(ns, floatArrayOf(x.toFloat(), gravity[1], gravity[2]))
        if (pass in 4 until passes) {
            if (u < .045 || u > .955) endSpeeds.add(abs(frame.signedSpeedMps) / peak)
            if (abs(u - .5) < .075) middleSpeeds.add(sign * frame.signedSpeedMps / peak)
            frame.completedPassPeakMps?.let { reported.add(it) }
        }
        if (t < 0 || t > end + .21) {
            check(!frame.contact && frame.signedSpeedMps == 0.0 && frame.passPeakMps == 0.0)
            check(frame.completedPassPeakMps == null)
        }
    }
    check(endSpeeds.isNotEmpty() && endSpeeds.max() < .33) { "Turnaround speed: ${endSpeeds.maxOrNull()}" }
    check(middleSpeeds.isNotEmpty() && middleSpeeds.min() > .72) { "Mid-pass speed: ${middleSpeeds.minOrNull()}" }
    check(reported.size in 11..13) { "Fully observed passes: ${reported.size}" }
    val median = reported.sorted()[reported.size / 2]
    check(median / peak in .80..1.20) { "Estimated / true peak: ${median / peak}" }
    return median
}

fun main() {
    for (hz in listOf(60, 100)) for (fused in listOf(false, true)) {
        val slow = velocityTrial(hz, .60, .15, fused)
        val fast = velocityTrial(hz, .185, .15, fused)
        check(fast > 2.5 * slow)
        velocityTrial(hz, .125, .045, fused)
        println("${hz}Hz fused=$fused, 15cm pass estimated peaks: slow=%.3f fast=%.3f m/s".format(slow, fast))
    }
    // Paused sensor delivery must not integrate the missing time.
    val desk = DeskMotion()
    val gravity = floatArrayOf(0f, 0f, 9.81f)
    desk.gravity(0L, gravity)
    desk.update(0L, gravity)
    val moving = floatArrayOf(4f, 0f, 9.81f)
    var last = DeskSample(false)
    for (i in 1..15) last = desk.update(i * 10_000_000L, moving)
    check(last.contact && last.signedSpeedMps > .25)
    val reset = desk.update(500_000_000L, gravity)
    check(reset.ended && reset.signedSpeedMps == 0.0 && reset.completedPassPeakMps == null)
}
