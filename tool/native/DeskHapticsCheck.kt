package jp.spajam.polish_workshop

import java.io.File
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/** Known reversals let us distinguish a vibration on the slide from a late tap at its end. */
private fun shortSlides(hz: Int, distanceCm: Double, halfMs: Int) {
    val desk = DeskMotion()
    val silent = DeskMotion()
    val haptics = DeskHaptics("coarse", .1, 65, 224)
    val gravity = floatArrayOf(0f, 0f, 9.81f)
    val passes = 16
    val starts = List(passes) { mutableListOf<Int>() }
    var motorEnd = 0L
    var scores = 0
    var silentScores = 0
    for (i in 0..(2000 + halfMs * passes) * hz / 1000) {
        val ns = i * 1_000_000_000L / hz
        val ms = (ns / 1e6).roundToInt() - 1000
        val leg = Math.floorDiv(ms, halfMs)
        val phase = Math.floorMod(ms, halfMs)
        val omega = PI / (halfMs / 1000.0)
        val sign = if (leg % 2 == 0) 1 else -1
        val x = if (leg in starts.indices) {
            sign * distanceCm / 200 * omega * omega * cos(PI * phase / halfMs)
        } else 0.0
        // Known short motor impulses before the slides and closed-loop noise during them.
        if (i == hz / 5) {
            desk.motorStarted(ns, 180)
            motorEnd = ns + 180_000_000L
        }
        val buzz = if (ns < motorEnd) .22 * sin(2 * PI * 19 * ns / 1e9) else 0.0
        desk.gravity(ns, gravity)
        silent.gravity(ns, gravity)
        val hand = desk.update(ns, floatArrayOf((x + buzz).toFloat(), 0f, gravity[2]))
        if (silent.update(ns, floatArrayOf(x.toFloat(), 0f, gravity[2])).stroke) silentScores++
        if (hand.stroke) scores++
        val wave = haptics.sample(ns, hand) ?: continue
        if (wave === DeskFeedback.stop) {
            desk.motorStopped(ns)
            motorEnd = ns
        } else {
            check(leg in starts.indices) { "${hz}Hz: motor command during rest at ${ms}ms" }
            starts[leg].add(phase)
            desk.motorStarted(ns, wave.durationMs)
            motorEnd = ns + wave.durationMs * 1_000_000L
        }
    }
    check(scores == silentScores) { "Unequal stroke counts $scores/$silentScores" }
    for (times in starts.drop(2)) {
        check(times.size == 1 && times.single() in 0..(halfMs * .67).toInt()) {
            "${hz}Hz ${distanceCm}cm/${halfMs}ms: $starts"
        }
    }
}

/** Print commanded Android waveforms against the original sensor clock for a REDMI take. */
private fun replayHaptics(file: File) {
    val desk = DeskMotion()
    val haptics = DeskHaptics("coarse", 0.0, 68, 245)
    println("t_s,velocity_m_s,round_trip,motor_ms,timings_ms,source")
    val tickNs = 25_000_000L
    var nextTick = -1L
    var lastNs = -1L
    fun advanceWatchdog(untilNs: Long) {
        while (nextTick in 0..untilNs) {
            if (haptics.expire(nextTick)) {
                desk.motorStopped(nextTick)
                println("${nextTick / 1e9},,false,0,,watchdog")
            }
            nextTick += tickNs
        }
    }
    replayCsv(file) { ns, xyz ->
        if (nextTick < 0) nextTick = ns + tickNs
        advanceWatchdog(ns)
        lastNs = ns
        val state = desk.update(ns, xyz)
        val wave = haptics.sample(ns, state)
        if (wave != null) {
            if (wave === DeskFeedback.stop) desk.motorStopped(ns) else desk.motorStarted(ns, wave.durationMs)
        }
        if (wave != null || state.stroke) {
            val timings = wave?.timings?.joinToString(":") ?: ""
            println("${ns / 1e9},${state.signedSpeedMps},${state.stroke},${wave?.durationMs ?: ""},$timings,sensor")
        }
        false
    }
    // A recording can end mid-pass, in which case only the independent timer remains.
    advanceWatchdog(lastNs + 120_000_000L + tickNs)
}

/** Exercise the actuator separately from the velocity estimator with known glide and turn speeds. */
fun main(args: Array<String>) {
    if (args.isNotEmpty()) {
        require(args.size == 1) { "Pass one acceleration CSV or no arguments" }
        replayHaptics(File(args.single()))
        return
    }
    for (hz in listOf(60, 100)) {
        shortSlides(hz, 1.0, 185)
        shortSlides(hz, 2.0, 350)
        shortSlides(hz, 3.5, 500)
    }
    fun ns(ms: Int) = ms * 1_000_000L
    fun motion(speed: Double, peak: Double, period: Int, began: Boolean = false) = DeskSample(
        contact = true, began = began, moving = true, cadenceMs = period,
        signedSpeedMps = speed, passPeakMps = peak
    )
    fun packet(grit: String, progress: Double, baseMs: Int, period: Int, peak: Double): DeskFeedback {
        val haptics = DeskHaptics(grit, progress, baseMs, 160)
        check(haptics.sample(ns(5), motion(0.0, peak, period, began = true)) == null)
        val wave = checkNotNull(haptics.sample(ns(125), motion(peak, peak, period)))
        check(wave.amplitude == 160 && wave.timings[0] == 0L)
        check(wave.timings.size % 2 == 0 && wave.timings.drop(1).all { it > 0 })
        return wave
    }
    fun onMs(wave: DeskFeedback) = wave.timings.filterIndexed { i, _ -> i % 2 == 1 }.sum()
    val profiles = listOf("coarse" to 65, "medium" to 45, "fine" to 28)
    val slow = profiles.map { (grit, length) -> packet(grit, .1, length, 1200, .6) }
    val fast = profiles.map { (grit, length) -> packet(grit, .1, length, 370, 1.9) }
    for (wave in fast) check(wave.durationMs in 50..80)
    for (waves in listOf(slow, fast)) check(onMs(waves[0]) > onMs(waves[1]) && onMs(waves[1]) > onMs(waves[2]))
    check(slow[0].timings[1] > slow[1].timings[1] && slow[1].timings[1] > slow[2].timings[1])
    // At an identical cadence, greater linear speed gives a shorter command.
    check(packet("coarse", .1, 65, 700, .6).durationMs > packet("coarse", .1, 65, 700, 1.9).durationMs)
    val midSpeeds = (0..20).map { i -> packet("coarse", .1, 65, 700, .42 + .04 * i).durationMs }
    check(midSpeeds.distinct().size >= 14 && midSpeeds.zipWithNext().all { (a, b) -> a - b in 0..15 }) {
        "Abrupt waveform duration as speed increases at constant cadence: $midSpeeds"
    }
    for ((index, profile) in profiles.withIndex()) {
        val polished = packet(profile.first, .9, (profile.second * .58).toInt(), 370, 1.9)
        check(onMs(polished) < onMs(fast[index]))
    }

    val h = DeskHaptics("coarse", .1, 65, 230)
    check(h.sample(ns(5), motion(0.0, .6, 1200, began = true)) == null)
    check(h.sample(ns(90), motion(.5, .6, 1200)) != null)
    check(h.sample(ns(140), motion(.5, .6, 1200)) == null)
    check(h.sample(ns(230), motion(.05, .6, 1200)) === DeskFeedback.stop)
    check(h.sample(ns(270), motion(-.02, .6, 1200)) == null)
    h.update(.9, 37, 113)
    check(h.sample(ns(320), motion(-.55, .6, 1200))?.amplitude == 113)
    check(h.sample(ns(340), DeskSample(false, ended = true)) === DeskFeedback.stop)
    check(h.sample(ns(350), DeskSample(false)) == null)

    val interrupted = DeskHaptics("coarse", .1, 65, 230)
    interrupted.sample(ns(5), motion(.6, .6, 1200, began = true))
    check(!interrupted.expire(ns(124)) && interrupted.expire(ns(125)) && !interrupted.expire(ns(130)))
    check(interrupted.sample(ns(400), motion(-.5, .6, 1200), ns(70)) == null)

    // A backlog may contain a valid first push but the hand can already have turned.
    val backlogged = DeskHaptics("coarse", .1, 65, 230)
    check(backlogged.sample(ns(100), motion(.5, .6, 1200, began = true), ns(20)) == null)
    check(checkNotNull(backlogged.sample(ns(110), motion(.5, .6, 1200), ns(108))).durationMs > 0)
    check(backlogged.sample(ns(210), DeskSample(false, ended = true), ns(130)) === DeskFeedback.stop)
    val deadline = DeskFeedback(longArrayOf(0, 20, 10, 20), 130)
    check(deadline.within(0) == null && deadline.within(50) === deadline)
    check(deadline.within(29)?.timings?.contentEquals(longArrayOf(0, 20)) == true)
    check(deadline.within(35)?.timings?.contentEquals(longArrayOf(0, 20, 10, 5)) == true)
    println("coarse/medium/fine slow total/on ms: " + slow.joinToString { "${it.durationMs}/${onMs(it)}" })
    println("coarse/medium/fine fast total/on ms: " + fast.joinToString { "${it.durationMs}/${onMs(it)}" })
}
