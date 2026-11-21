package jp.spajam.polish_workshop

/** Exercise the actuator separately from the velocity estimator with known glide and turn speeds. */
fun main() {
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
