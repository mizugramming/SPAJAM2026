package jp.spajam.polish_workshop

/** Pure scheduler checks. DeskMotionCheck exercises recognition; these supply explicit hand evidence. */
fun main() {
    fun ns(ms: Int) = ms * 1_000_000L
    fun push(period: Int, reversalMs: Int? = null) = DeskSample(
        contact = true, moving = true, cadenceMs = period, lastReversalNs = reversalMs?.let { ns(it) }
    )
    val touch = DeskSample(contact = true, began = true, moving = true)
    fun steady(grit: String, progress: Double, baseMs: Int, period: Int): DeskFeedback {
        val haptics = DeskHaptics(grit, progress, baseMs, 160)
        val first = checkNotNull(haptics.sample(ns(5), touch))
        check(first.durationMs in 12..42 && first.timings.size == 2)
        check(haptics.sample(ns(25), push(period)) == null)
        val packet = checkNotNull(haptics.sample(ns(125), push(period, 125)))
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
    check(moderate.all { it.durationMs in 50..80 } && fast.all { it.durationMs in 50..80 })
    check(fast.first().durationMs < moderate.first().durationMs)
    for (packets in listOf(slow, moderate, fast)) {
        check(onMs(packets[0]) > onMs(packets[1]) && onMs(packets[1]) > onMs(packets[2]))
    }
    // A fixed-amplitude phone must still feel the finish change at the fastest cadence.
    for ((i, profile) in early.withIndex()) {
        val polished = steady(profile.first, .9, (profile.second * .58).toInt(), 250)
        check(onMs(polished) < onMs(fast[i]))
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
    // During fast play each new measured half-cycle can pulse once. Old, unconfirmed
    // or delayed samples cannot turn repeated sensor updates into extra taps.
    val lag = DeskHaptics("coarse", .1, 65, 230)
    lag.sample(ns(5), touch)
    check(lag.sample(ns(125), push(370, 125))?.durationMs in 50..80)
    for (t in 130..300 step 10) check(lag.sample(ns(t), push(370, 125)) == null)
    check(lag.sample(ns(310), push(370)) == null)
    check(lag.sample(ns(315), push(370, 150), ns(175)) == null)
    check(lag.sample(ns(320), push(370, 310))?.durationMs in 50..80)
    check(lag.sample(ns(470), push(370, 410)) == null)
    check(lag.sample(ns(500), push(370, 495))?.durationMs in 50..80)
    println("coarse/medium/fine, slow total/on ms: " + slow.joinToString { "${it.durationMs}/${onMs(it)}" })
    println("coarse/medium/fine, fast total/on ms: " + moderate.joinToString { "${it.durationMs}/${onMs(it)}" })
}
