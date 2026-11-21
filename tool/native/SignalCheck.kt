package jp.spajam.polish_workshop

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

fun main() {
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
}
