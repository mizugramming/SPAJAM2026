package jp.spajam.polish_workshop

import java.io.File
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

private const val dtNs = 10_000_000L
private val down = floatArrayOf(0f, 0f, 9.81f)

// Second derivative of a 15 cm minimum-jerk translation; each end is at rest.
private fun leg(t: Double, seconds: Double, distance: Double = 0.15): Double {
    if (t <= 0.0 || t >= seconds) return 0.0
    val u = t / seconds
    return distance * (60*u - 180*u*u + 120*u*u*u) / (seconds * seconds)
}

private fun travel(t: Double, duration: Double, cycles: Int, oneWay: Boolean = false, distance: Double = 0.15): Double {
    val part = (t / duration).toInt()
    if (t < 0 || part >= (if (oneWay) 1 else 2 * cycles)) return 0.0
    val local = t - part * duration
    val acceleration = leg(local, duration, distance)
    return if (part % 2 == 0) acceleration else -acceleration
}

private data class Trial(val starts: List<Long>, val releases: List<Long>, val strokes: Int, val cadenceMs: Int?)

private fun exercise(
    duration: Double, vertical: Boolean = false, oneWay: Boolean = false,
    cycles: Int = 6, tilted: Boolean = false, feedback: Boolean = false,
): Trial {
    val calibration = DeskCalibration()
    for (i in 0..100) calibration.add(i*dtNs, down)
    val desk = DeskMotion(calibration.finish())
    val starts = mutableListOf<Long>()
    val releases = mutableListOf<Long>()
    var strokes = 0
    var cadence: Int? = null
    val angle = if (tilted) .7 else 0.0
    val direction = if (vertical) doubleArrayOf(sin(angle), 0.0, cos(angle)) else doubleArrayOf(cos(angle), 0.0, -sin(angle))
    val g = floatArrayOf((9.81 * sin(angle)).toFloat(), 0f, (9.81 * cos(angle)).toFloat())
    val end = duration * (if (oneWay) 1 else cycles*2)
    var motorUntil = -1L
    var nextGroup = -1L
    for (i in 0..((end + 1.9)*100).toInt()) {
        val ns = i * dtNs
        val t = i * .01 - 1.0
        val motion = travel(t, duration, cycles, oneWay)
        // Axes rotate with a fixed, tilted grip. Sensor timestamp is monotonic.
        if (tilted) desk.gravity(ns, g)
        val buzz = if (feedback && ns < motorUntil) 1.8 * sin(2*PI*i*.37) else 0.0
        val xyz = FloatArray(3) { j -> (g[j] + motion * direction[j] + buzz * if (j == 1) 1 else 0).toFloat() }
        val s = desk.update(ns, xyz)
        if (s.began) starts.add(i*10L-1000)
        if (s.ended) releases.add(i*10L-1000)
        if (s.stroke) strokes++
        if (s.cadenceMs != null) cadence = s.cadenceMs
        if (feedback && (s.began || (s.contact && s.moving && ns > nextGroup))) {
            val ms = if (s.began) 27 else if (duration < .25) 140 else 295
            desk.motorStarted(ns, ms)
            motorUntil = ns + ms*1_000_000L
            nextGroup = motorUntil + 82_000_000L
        }
        if (feedback && s.ended) {
            desk.motorStopped(ns)
            motorUntil = ns
        }
    }
    return Trial(starts, releases, strokes, cadence)
}

private fun checkSpeedChanges(fusedGravity: Boolean) {
    val desk = DeskMotion()
    val haptics = DeskHaptics("coarse", 0.0, 68, 245)
    val halfMs = listOf(600, 185, 600)
    // Keep the stroke length fixed while the hand accelerates and slows down.
    val distance = 0.15
    val boundaries = halfMs.runningFold(1000) { start, half -> start + 8 * half }
    val strokes = IntArray(3)
    val envelopes = Array(3) { mutableListOf<Int>() }
    val fastPasses = IntArray(8)
    val middleOn = IntArray(3)
    val endsOn = IntArray(3)
    var waveform = longArrayOf()
    var startedMs = 0
    for (ms in 0..boundaries.last() + 500 step 10) {
        val ns = ms * 1_000_000L
        val stage = halfMs.indices.firstOrNull { ms in boundaries[it] until boundaries[it + 1] }
        val accel = stage?.let {
            travel((ms - boundaries[it]) / 1000.0, halfMs[it] / 1000.0, 4, distance = distance)
        } ?: 0.0
        if (fusedGravity) desk.gravity(ns, down)
        val state = desk.update(ns, floatArrayOf(accel.toFloat(), 0f, 9.81f))
        if (state.stroke) strokes[checkNotNull(stage)]++
        val feedback = haptics.sample(ns, state)
        if (feedback != null) {
            waveform = feedback.timings
            startedMs = ms
            if (feedback.durationMs > 0) {
                if (stage != null) envelopes[stage].add(feedback.durationMs)
                if (stage == 1) fastPasses[(ms - boundaries[1]) / halfMs[1]]++
                desk.motorStarted(ns, feedback.durationMs)
            } else desk.motorStopped(ns)
        }
        if (haptics.expire(ns)) {
            waveform = longArrayOf()
            desk.motorStopped(ns)
        }
        if (stage != null && ms - boundaries[stage] >= 2 * halfMs[stage]) {
            val phase = ((ms - boundaries[stage]) % halfMs[stage]).toDouble() / halfMs[stage]
            var elapsedMs = (ms - startedMs).toLong()
            for ((index, duration) in waveform.withIndex()) {
                if (elapsedMs < duration) {
                    if (index % 2 == 1 && phase in .375.. .625) middleOn[stage]++
                    if (index % 2 == 1 && (phase < .125 || phase > .875)) endsOn[stage]++
                    break
                }
                elapsedMs -= duration
            }
        }
    }
    // Equal-length windows. The motor must run primarily during travel, including after a speed change.
    check(halfMs.indices.all { middleOn[it] > 3 * endsOn[it] }) {
        "Motor-on samples at mid-pass and ends: ${middleOn.toList()} / ${endsOn.toList()}"
    }
    check(strokes.all { it == 4 }) { "Count at each speed: ${strokes.toList()}" }
    check(fastPasses.takeLast(4).all { it == 1 }) { "Taps per fast pass: ${fastPasses.toList()}" }
    val fast = envelopes[1].last()
    check(fast in 50..80 && fast < envelopes[0].last() && fast < envelopes[2].last()) { "Waveforms: ${envelopes.toList()}" }
}

private fun checkGradualStart() {
    val desk = DeskMotion()
    val strokes = mutableListOf<Int>()
    for (ms in 0..7500 step 10) {
        val seconds = ms / 1000.0
        val strength = minOf(seconds / 2.0, 1.0) * 1.8
        val lateral = strength * sin(2 * PI * seconds / 0.95)
        val state = desk.update(ms * 1_000_000L, floatArrayOf(lateral.toFloat(), 0f, 9.81f))
        if (state.stroke) strokes.add(ms)
    }
    // Without a distinct initial shove, sustained motion must still register once per period.
    check(strokes.count { it >= 2800 } == 5) { "Gradually established strokes: $strokes" }
}

private fun checkSeparatedPushes() {
    val desk = DeskMotion(DeskBaseline(9.81, .08))
    val gravity = floatArrayOf(0f, 0f, 9.81f)
    val starts = mutableListOf<Int>()
    val releases = mutableListOf<Int>()
    val strokes = mutableListOf<Int>()
    val resumeMs = 1130
    for (ms in 0..2000 step 10) {
        // Both translations are forward and end at rest. The hand never returns.
        val x = leg((ms - 400) / 1000.0, .18, .06) + leg((ms - resumeMs) / 1000.0, .4, .04)
        val ns = ms * 1_000_000L
        desk.gravity(ns, gravity)
        val sample = desk.update(ns, floatArrayOf(x.toFloat(), 0f, 9.81f))
        if (sample.began) starts.add(ms)
        if (sample.ended) releases.add(ms)
        if (sample.stroke) strokes.add(ms)
    }
    check(starts.size == 2 && starts[0] in 400..580 && starts[1] in resumeMs..(resumeMs + 400))
    check(releases.size == 2 && resumeMs - releases.first() >= 350)
    check(strokes.isEmpty()) { "Same-direction pushes across an expired contact counted at $strokes" }
}

/** Six 9 cm slides from rest, with an explicit 200 ms dwell at each end. */
private fun checkSlowSlidesWithStops(hz: Int, smoothStart: Boolean) {
    val desk = DeskMotion()
    val silentDesk = DeskMotion()
    val haptics = DeskHaptics("coarse", .1, 65, 180)
    val travelMs = 600
    val dwellMs = 200
    val passMs = travelMs + dwellMs
    val starts = List(6) { mutableListOf<Int>() }
    var envelopeEndNs = 0L
    var strokes = 0
    var silentStrokes = 0
    for (i in 0..((1000 + starts.size * passMs + 300) * hz / 1000)) {
        val ns = i * 1_000_000_000L / hz
        val ms = (ns / 1e6).roundToInt() - 1000
        val pass = Math.floorDiv(ms, passMs)
        val phaseMs = Math.floorMod(ms, passMs)
        val sliding = pass in starts.indices && phaseMs < travelMs
        // Both trajectories come to rest at the ends and reach peak speed halfway through.
        val direction = if (pass % 2 == 0) 1 else -1
        val acceleration = if (sliding) {
            val seconds = phaseMs / 1000.0
            val duration = travelMs / 1000.0
            val omega = PI / duration
            if (smoothStart) direction * leg(seconds, duration, .09)
            else direction * .09 / 2 * omega * omega * cos(omega * seconds)
        } else 0.0
        // Start with a stationary grip, an independent motor pulse, then rest.
        if (ms == -800) desk.motorStarted(ns, 300)
        val motorOnly = if (ms in -800 until -500) 1.2 * sin(2 * PI * 19 * ns / 1e9) else 0.0
        desk.gravity(ns, down)
        val hand = desk.update(ns, floatArrayOf((acceleration + motorOnly).toFloat(), 0f, down[2]))
        silentDesk.gravity(ns, down)
        if (silentDesk.update(ns, floatArrayOf(acceleration.toFloat(), 0f, down[2])).stroke) silentStrokes++
        if (hand.stroke) strokes++
        if (ms < 0) check(!hand.contact && !hand.stroke) { "${hz}Hz false contact at ${ms}ms" }
        val command = haptics.sample(ns, hand)
        if (command === DeskFeedback.stop) {
            desk.motorStopped(ns)
            envelopeEndNs = ns
        } else if (command != null) {
            check(sliding) { "${hz}Hz issued a vibration during rest at ${ms}ms" }
            starts[pass].add(phaseMs)
            desk.motorStarted(ns, command.durationMs)
            envelopeEndNs = ns + command.durationMs * 1_000_000L
        }
        // Check the command envelope, independent of short gaps in its texture.
        if (!sliding && phaseMs >= travelMs + 1000.0 / hz) {
            check(ns >= envelopeEndNs) { "${hz}Hz pass $pass: active vibration command at ${phaseMs}ms" }
        }
    }
    for ((pass, times) in starts.withIndex()) {
        check(times.isNotEmpty() && times.first() < travelMs / 2 &&
                times.last() < 3 * travelMs / 4) {
            "${hz}Hz pass $pass started at ${times}ms, turnaround at ${travelMs}ms"
        }
    }
    val roundTrips = starts.size / 2
    check(strokes == roundTrips && silentStrokes == roundTrips) {
        "${hz}Hz 3 round trips, smoothStart=$smoothStart: motor on $strokes, off $silentStrokes"
    }
    println("${hz}Hz 9 cm slides, smoothStart=$smoothStart: first commands (ms) ${starts.map { it.first() }}, " +
            "turn at ${travelMs}ms, strokes on/off $strokes/$silentStrokes")
}

fun main(args: Array<String>) {
    if (args.isNotEmpty()) {
        require(args.size == 1) { "Pass one acceleration CSV or no arguments for the desk motion checks" }
        val desk = DeskMotion()
        replayCsv(File(args.single())) { timeNs, xyz -> desk.update(timeNs, xyz).stroke }
        return
    }
    val desk = DeskCalibration()
    for (i in 0..120) desk.add(i*dtNs,floatArrayOf((0.04*cos(i*.27)).toFloat(),0f,9.81f))
    val b = checkNotNull(desk.finish())
    check(b.noiseRms in 0.01..0.10 && abs(b.gravityMagnitude-9.81) < .02)
    for (i in 121..240) desk.add(i*dtNs,floatArrayOf((3.0*cos(i*.7)).toFloat(),0f,9.81f))
    check(desk.finish() == null)

    for (duration in listOf(.125,.185,.35,.60)) {
        for (tilted in listOf(false,true)) {
            for (haptic in listOf(false,true)) {
                val test = exercise(duration, tilted=tilted, feedback=haptic)
                val end = (duration*12*1000).toLong()
                println("half=$duration tilt=$tilted motor=$haptic: $test")
                check(test.strokes == 6)
                check(test.starts.size == 1 && test.starts.single() in 20..145)
                check(test.releases.single() in end-200 .. end+230)
                check(test.cadenceMs != null && abs(test.cadenceMs-duration*2000) < 100)
            }
            val lift = exercise(duration, vertical=true, tilted=tilted)
            check(lift.strokes == 0 && lift.starts.isEmpty())
        }
    }
    val oneWay = exercise(.4, oneWay=true, feedback=true)
    check(oneWay.starts.size == 1 && oneWay.strokes == 0)
    check(exercise(.4, vertical=true, oneWay=true).starts.isEmpty())

    // A lift partway through a horizontal cycle must stop the touch and discard
    // the partial cycle; a later push should start another contact.
    val lift = DeskMotion()
    var releasedAt = -1
    var after = 0
    var starts = 0
    for (i in 0..290) {
        val t = i*.01
        val x = leg(t-.5,.4) + leg(t-1.8,.4)
        val z = leg(t-.9,.3)
        val sample = lift.update(i*dtNs,floatArrayOf(x.toFloat(),0f,(9.81+z).toFloat()))
        if (sample.began) starts++
        if (sample.ended && releasedAt < 0) releasedAt = i
        if (sample.stroke) after++
    }
    check(starts == 2 && releasedAt in 90..97 && after == 0)
    checkSpeedChanges(fusedGravity = false)
    checkSpeedChanges(fusedGravity = true)
    for (hz in listOf(60, 100)) {
        checkSlowSlidesWithStops(hz, smoothStart = false)
        checkSlowSlidesWithStops(hz, smoothStart = true)
    }
    checkGradualStart()
    checkSeparatedPushes()
    println("vertical lifts, pickup, stationary calibration, one-way start, release and recontact passed")
}
