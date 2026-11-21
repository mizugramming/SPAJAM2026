package jp.spajam.polish_workshop

/** Pure scheduler checks. DeskMotionCheck exercises recognition; these supply explicit hand evidence. */
fun main() {
    fun ns(ms: Int) = ms * 1_000_000L
    fun push(period: Int) = DeskSample(contact = true, moving = true, cadenceMs = period)
    val touch = DeskSample(contact = true, began = true, moving = true)
    fun steady(grit: String, progress: Double, baseMs: Int, period: Int): DeskFeedback {
        val haptics = DeskHaptics(grit, progress, baseMs, 160)
        val first = checkNotNull(haptics.sample(ns(5), touch))
        check(first.durationMs in 12..42 && first.timings.size == 2)
        check(haptics.sample(ns(25), push(period)) == null)
        val packet = checkNotNull(haptics.sample(ns(125), push(period)))
        check(packet.amplitude == 160 && packet.timings[0] == 0L)
        check(packet.timings.size % 2 == 0 && packet.timings.drop(1).all { it > 0 })
        return packet
    }
    val early = listOf("coarse" to 65, "medium" to 45, "fine" to 28)
    fun onMs(wave: DeskFeedback) = wave.timings.filterIndexed { i, _ -> i % 2 == 1 }.sum()
    val slow = early.map { (grit, len) -> steady(grit, .10, len, 1200) }
    val moderate = early.map { (grit, len) -> steady(grit, .10, len, 370) }
    val fast = early.map { (grit, len) -> steady(grit, .10, len, 250) }
    check(slow.first().durationMs == 1000)
    check(moderate.first().durationMs == 250)
    check(fast.first().durationMs == 44)
    for (packets in listOf(slow, moderate, fast)) {
        check(onMs(packets[0]) > onMs(packets[1]) && onMs(packets[1]) > onMs(packets[2]))
    }
    check(slow[0].timings[1] > slow[1].timings[1] && slow[1].timings[1] > slow[2].timings[1])
    val deadline = DeskFeedback(longArrayOf(0, 20, 10, 20), 130)
    check(deadline.within(0) == null && deadline.within(50) === deadline)
    check(deadline.within(29)?.timings?.contentEquals(longArrayOf(0, 20)) == true)
    check(deadline.within(35)?.timings?.contentEquals(longArrayOf(0, 20, 10, 5)) == true)
    val late = DeskHaptics("coarse", 0.0, 68, 245)
    late.sample(ns(5), touch)
    late.update(.90, 37, 113)
    val polished = checkNotNull(late.sample(ns(125), push(1200)))
    check(polished.amplitude == 113 && onMs(polished) < onMs(slow[0]))
    // The watchdog has no path to vibrating. Cancel once after missing proof.
    check(!late.expire(ns(244)) && late.expire(ns(245)) && !late.expire(ns(270)))
    check(late.sample(ns(1350), DeskSample(contact = true)) == null)
    // A lift cancels a long envelope immediately.
    val lift = DeskHaptics("coarse", .1, 65, 230)
    lift.sample(ns(5), touch)
    lift.sample(ns(125), push(1200))
    check(lift.sample(ns(150), DeskSample(contact = false, ended = true)) === DeskFeedback.stop)
    check(lift.sample(ns(160), DeskSample(false)) == null)
    // A sample collected during the motor tail cannot schedule the next packet, even if delivered late.
    val lag = DeskHaptics("coarse", .1, 65, 230)
    lag.sample(ns(5), touch)
    lag.sample(ns(125), push(370))
    for (t in 130..420 step 10) lag.sample(ns(t), push(370))
    check(lag.sample(ns(496), push(370), ns(424)) == null)
    check(lag.sample(ns(504), push(370), ns(496))?.durationMs == 250)
    println("coarse/medium/fine, slow total/on ms: " + slow.joinToString { "${it.durationMs}/${onMs(it)}" })
    println("coarse/medium/fine, fast total/on ms: " + moderate.joinToString { "${it.durationMs}/${onMs(it)}" })
}
