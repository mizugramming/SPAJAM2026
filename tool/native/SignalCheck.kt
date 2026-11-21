package jp.spajam.polish_workshop

import java.io.File
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.roundToLong
import kotlin.math.sin
import kotlin.random.Random

private fun replayCsv(file: File) {
    val detector = StrokeDetector()
    file.bufferedReader().use { reader ->
        require(reader.readLine() == "t_s,x_m_s2,y_m_s2,z_m_s2") { "Expected a REDMI acceleration CSV" }
        for (line in reader.lineSequence().filter { it.isNotBlank() }) {
            val (t, x, y, z) = line.split(',')
            val timeNs = (t.toDouble() * 1e9).roundToLong()
            if (detector.update(timeNs, floatArrayOf(x.toFloat(), y.toFloat(), z.toFloat()))) println(t)
        }
    }
}

fun main(args: Array<String>) {
    if (args.isNotEmpty()) {
        require(args.size == 1) { "Pass one acceleration CSV or no arguments for the signal checks" }
        replayCsv(File(args.single()))
        return
    }
    val random = Random(77)
    fun analyse(signal: (Double) -> Double): VoiceMeasurement {
        val pcm = ShortArray(VoiceAnalysis.sampleCount) { i ->
            signal(i / VoiceAnalysis.sampleRate.toDouble()).toInt().coerceIn(-32768, 32767).toShort()
        }
        return VoiceAnalysis.measure(pcm)
    }
    for (hz in listOf(85, 130, 190, 240, 350, 510)) {
        val voice = analyse { t -> 3500 * sin(2 * PI * hz * t) + 6800 * sin(4 * PI * hz * t) + random.nextInt(-240, 240) }
        check(voice.hz != null && abs(voice.hz - hz) < 2.0)
        println("input=$hz, result=${voice.hz}, level=${voice.level}")
    }
    fun tone(hz: Int) = analyse { t -> 8000 * sin(2 * PI * hz * t) }
    for (hz in listOf(65, 120, 190, 270, 600)) {
        val measured = tone(hz).hz
        check(measured != null && abs(measured - hz) < 0.1) { "input=$hz, result=$measured" }
    }
    // Reject the first period outside the monitor range, even when double it is inside.
    for (hz in listOf(50, 64, 601, 800, 1000)) {
        val measured = tone(hz)
        check(measured.hz == null && measured.level > 0.15) { "input=$hz, result=$measured" }
    }
    check(analyse { 0.0 } == VoiceMeasurement(null, 0.0))
    check(analyse { random.nextDouble(-7000.0, 7000.0) }.hz == null)
    check(analyse { t -> 3800 * sin(2 * PI * (120 * t + 120 * t * t)) }.hz == null)
    val low = analyse { t -> 1200 * sin(2 * PI * 180 * t) }
    val loud = analyse { t -> 14000 * sin(2 * PI * 180 * t) }
    check(low.level < loud.level && loud.level < 1.0)

    // 100 Hz accelerometer with gravity + 8 complete 3D reciprocations + short motor bursts.
    fun cycles(hand: Boolean, motor: Boolean): Int {
        val detector = StrokeDetector()
        var strokes = 0
        for (i in 0..980) {
            val timeNs = i * 10_000_000L
            val pos = i - 100
            val motion = if (hand && pos in 0..640) 3.8 * cos(2 * PI * pos / 80.0) else 0.0
            val sincePulse = i % 57
            if (motor && sincePulse == 0) detector.maskMotor(timeNs, 40)
            val buzz = if (motor && sincePulse in 0..7) 6.0 * sin(2 * PI * 73 * i / 100.0) + 2.2 else 0.0
            val sample = floatArrayOf(
                (motion * 0.8 + buzz + random.nextDouble(-0.08, 0.08)).toFloat(),
                (motion * 0.6 + random.nextDouble(-0.08, 0.08)).toFloat(), 9.81f
            )
            if (detector.update(timeNs, sample)) strokes++
        }
        println("hand=$hand, motor=$motor, measured=$strokes")
        return strokes
    }
    check(cycles(hand = false, motor = false) == 0)
    check(cycles(hand = false, motor = true) == 0)
    check(cycles(hand = true, motor = false) == 8)
    check(cycles(hand = true, motor = true) == 8)

    // Replay 12 known cycles at the REDMI monitor's 60 Hz. In the game a
    // detected stroke triggers the motor, so the next reversal may be masked.
    fun fastCycles(samplesPerCycle: Int, pulseMs: Int, adjustable: Boolean = true): Int {
        val detector = StrokeDetector()
        val lastMotionSample = 12 * samplesPerCycle
        var strokes = 0
        var lastPulseNs = -1_000_000_000L
        var playMs = 0
        for (step in -60..lastMotionSample + 60) {
            val timeNs = (step + 60) * 1_000_000_000L / 60
            val motion = if (step in 0..lastMotionSample) 12 * cos(2 * PI * step / samplesPerCycle) else 0.0
            val sincePulse = (timeNs - lastPulseNs) / 1e9
            val buzz = if (playMs > 0 && sincePulse >= 0 && sincePulse < (playMs + 25) / 1000.0) {
                8 * sin(2 * PI * 132 * sincePulse) + 2.2
            } else 0.0
            val xyz = floatArrayOf((0.8 * motion + buzz).toFloat(), (0.6 * motion).toFloat(), 9.81f)
            if (detector.update(timeNs, xyz)) {
                check(step <= lastMotionSample + 3) { "Extra stroke after stopping" }
                strokes++
                if (pulseMs > 0) {
                    // Issue the command before the next 60 Hz sensor sample.
                    lastPulseNs = timeNs + 16_000_000L
                    playMs = detector.strokePulseDuration(pulseMs, lastPulseNs, adjustable)
                    if (samplesPerCycle == 15) check(playMs < pulseMs)
                    // The signal starts at a peak, so its first half is partial.
                    if (samplesPerCycle == 48 && strokes > 1) {
                        val expected = if (adjustable) pulseMs else pulseMs + 8
                        check(playMs == expected)
                    }
                    // Game pulse requests at 10% and 90%, coarse to fine.
                    val early = listOf(65, 45, 28).map { detector.strokePulseDuration(it, lastPulseNs, adjustable) }
                    val late = listOf(37, 26, 16).map { detector.strokePulseDuration(it, lastPulseNs, adjustable) }
                    check(early.zip(late).all { (rough, polished) -> rough > polished })
                    if (!adjustable) {
                        check(early.zipWithNext().all { (a, b) -> a > b })
                        check(late.zipWithNext().all { (a, b) -> a > b })
                    }
                    if (!adjustable && pulseMs == 15) check(playMs >= 9)
                    detector.maskMotor(lastPulseNs, playMs)
                }
            }
        }
        println("60 Hz, period=${samplesPerCycle / 60.0}s, stroke-triggered pulse=${pulseMs}ms, measured=$strokes")
        return strokes
    }
    check(fastCycles(samplesPerCycle = 15, pulseMs = 0) == 12)
    check(fastCycles(samplesPerCycle = 15, pulseMs = 68) == 12)
    check(fastCycles(samplesPerCycle = 48, pulseMs = 68) == 12)
    check(fastCycles(samplesPerCycle = 15, pulseMs = 68, adjustable = false) == 12)
    check(fastCycles(samplesPerCycle = 15, pulseMs = 15, adjustable = false) == 12)
    check(fastCycles(samplesPerCycle = 48, pulseMs = 68, adjustable = false) == 12)
}
