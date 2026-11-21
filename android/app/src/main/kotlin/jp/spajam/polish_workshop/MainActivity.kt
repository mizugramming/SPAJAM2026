package jp.spajam.polish_workshop

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity(), SensorEventListener {
    private val sensors by lazy { getSystemService(Context.SENSOR_SERVICE) as SensorManager }
    @Suppress("DEPRECATION")
    private val motor: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }
    private var detector: StrokeDetector? = null
    private var lastPulseFollowedStroke = false
    private var baseline: DeskBaseline? = null
    private class DeskSession(
        val motion: DeskMotion,
        val haptics: DeskHaptics?,
        val id: Int?,
        var outputEnabled: Boolean,
        val adjustable: Boolean,
        val deadlineNs: Long
    )
    private var desk: DeskSession? = null
    private val handler = Handler(Looper.getMainLooper())
    private val roundTimeout = Runnable { stopMotion() }
    private val motorWatch = object : Runnable {
        override fun run() {
            val session = desk ?: return
            val now = SystemClock.elapsedRealtimeNanos()
            if (session.haptics?.expire(now) == true) cancelDeskMotor(session, now)
            if (session.outputEnabled) handler.postDelayed(this, 25)
        }
    }
    private var sensorStarted = 0L
    private var events: EventChannel.EventSink? = null
    private var methods: MethodChannel? = null
    private var strokes: EventChannel? = null

    private class Capture(val reply: MethodChannel.Result, val calibrateDesk: Boolean) {
        var calibration: DeskCalibration? = null
        var calibrationListener: SensorEventListener? = null
        @Volatile var cancelled = false
    }

    private val recorderThread = Executors.newSingleThreadExecutor()
    private var capturing: Capture? = null
    private var pendingPermission = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        strokes = EventChannel(messenger, "polish/strokes").also {
            it.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    events = sink
                }
                override fun onCancel(arguments: Any?) {
                    events = null
                    stopMotion()
                }
            })
        }
        methods = MethodChannel(messenger, "polish/device").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "capture" -> capture(result, call.argument<Boolean>("desk") == true)
                    "cancelCapture" -> { cancelCapture(); result.success(null) }
                    "startMotion" -> startMotion(call, result)
                    "stopMotion" -> { stopMotion(); result.success(null) }
                    "hasAmplitudeControl" -> result.success(hasAmplitudeControl())
                    "pulse" -> pulse(
                        call.argument<Int>("durationMs"), call.argument<Int>("amplitude"),
                        call.argument<Boolean>("followStroke") == true, call.argument<Double>("progress"),
                        call.argument<Int>("sessionId"), result
                    )
                    "stopPulse" -> {
                        motor.cancel()
                        desk?.motion?.motorStopped(SystemClock.elapsedRealtimeNanos())
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun capture(result: MethodChannel.Result, calibrateDesk: Boolean) {
        if (capturing != null) {
            result.error("busy", "採音中です。", null)
            return
        }
        val request = Capture(result, calibrateDesk)
        if (calibrateDesk) baseline = null
        capturing = request
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            beginRecording(request)
        } else if (!pendingPermission) {
            pendingPermission = true
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), microphonePermission)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != microphonePermission) return
        pendingPermission = false
        val request = capturing ?: return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            beginRecording(request)
        } else {
            capturing = null
            request.reply.error("permission", "マイクを許可し、もう一度声を出してください。", null)
        }
    }

    private fun cancelCapture() {
        val request = capturing ?: return
        request.cancelled = true
        capturing = null
        finishCalibration(request, false)
        request.reply.error("cancelled", "採音を中断しました。", null)
    }

    private fun startCalibration(request: Capture) {
        val accelerometer = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: return
        val calibration = DeskCalibration()
        val startNs = SystemClock.elapsedRealtimeNanos()
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (capturing === request && event.timestamp >= startNs) {
                    calibration.add(event.timestamp, event.values)
                }
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        if (sensors.registerListener(listener, accelerometer, 10_000)) {
            request.calibrationListener = listener
            request.calibration = calibration
        }
    }

    private fun finishCalibration(request: Capture, save: Boolean) {
        request.calibrationListener?.let { sensors.unregisterListener(it) }
        if (save && request.calibrateDesk) baseline = request.calibration?.finish()
        request.calibrationListener = null
        request.calibration = null
    }

    private fun beginRecording(request: Capture) {
        if (request.calibrateDesk) startCalibration(request)
        recorderThread.execute {
            val pcm = ShortArray(VoiceAnalysis.sampleCount)
            try {
                readPcm(request, pcm)
                if (!request.cancelled) {
                    val summary = VoiceAnalysis.measure(pcm)
                    runOnUiThread {
                        if (capturing === request) {
                            finishCalibration(request, true)
                            capturing = null
                            request.reply.success(mapOf("hz" to summary.hz, "level" to summary.level))
                        }
                    }
                }
            } catch (error: RuntimeException) {
                runOnUiThread {
                    if (capturing === request) {
                        finishCalibration(request, false)
                        capturing = null
                        val code = if (error is SecurityException) "permission" else "microphone"
                        request.reply.error(code, "マイクを確認し、もう一度声を出してください。", null)
                    }
                }
            } finally {
                pcm.fill(0)
            }
        }
    }

    private fun readPcm(request: Capture, pcm: ShortArray) {
        if (request.cancelled) return
        val rate = VoiceAnalysis.sampleRate
        val mono = AudioFormat.CHANNEL_IN_MONO
        val pcm16 = AudioFormat.ENCODING_PCM_16BIT
        val minimum = AudioRecord.getMinBufferSize(rate, mono, pcm16)
        check(minimum > 0)
        val recorder = AudioRecord(
            MediaRecorder.AudioSource.MIC, rate, mono, pcm16, maxOf(minimum, 4096)
        )
        try {
            check(recorder.state == AudioRecord.STATE_INITIALIZED)
            recorder.startRecording()
            check(recorder.recordingState == AudioRecord.RECORDSTATE_RECORDING)
            var count = 0
            val timeout = SystemClock.elapsedRealtime() + 4000L
            while (!request.cancelled && count < pcm.size) {
                check(SystemClock.elapsedRealtime() < timeout)
                val n = recorder.read(pcm, count, pcm.size - count, AudioRecord.READ_NON_BLOCKING)
                check(n >= 0)
                if (n == 0) SystemClock.sleep(8) else count += n
            }
        } finally {
            try {
                if (recorder.recordingState == AudioRecord.RECORDSTATE_RECORDING) recorder.stop()
            } finally {
                recorder.release()
            }
        }
    }

    private fun startMotion(call: MethodCall, result: MethodChannel.Result) {
        stopMotion()
        val accelerometer = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        sensorStarted = SystemClock.elapsedRealtimeNanos()
        val grit = call.argument<String>("grit")
        val trial = call.argument<Boolean>("deskTrial") == true
        if (grit != null || trial) {
            val haptics = if (grit != null) {
                val duration = call.argument<Int>("durationMs")
                val strength = call.argument<Int>("amplitude")
                val progress = call.argument<Double>("progress")
                if (grit !in listOf("coarse", "medium", "fine") ||
                    duration == null || duration !in 1..300 || strength == null || strength !in 1..255 ||
                    progress == null || !progress.isFinite() || progress !in 0.0..1.0) {
                    result.error("pulse", "振動の設定を確認してください。", null)
                    return
                }
                DeskHaptics(grit, progress, duration, strength)
            } else null
            // Flutter owns the round clock. Bound the local actuator as well if its stop command is delayed.
            val limitMs = if (trial) Long.MAX_VALUE else
                (call.argument<Int>("remainingMs") ?: 10_000).coerceIn(0, 10_000).toLong()
            desk = DeskSession(
                DeskMotion(baseline), haptics, call.argument<Int>("sessionId"),
                haptics != null && call.argument<Boolean>("vibrationEnabled") == true && motor.hasVibrator(),
                hasAmplitudeControl(), if (trial) Long.MAX_VALUE else sensorStarted + limitMs * 1_000_000L
            )
            if (!trial) handler.postDelayed(roundTimeout, limitMs)
        } else detector = StrokeDetector()
        if (accelerometer == null || !sensors.registerListener(this, accelerometer, 10_000)) {
            stopMotion()
            result.error("sensor", "加速度センサーを開始できません。", null)
            return
        }
        if (desk != null) {
            sensors.getDefaultSensor(Sensor.TYPE_GRAVITY)?.let { sensors.registerListener(this, it, 10_000) }
            if (desk?.outputEnabled == true) handler.postDelayed(motorWatch, 25)
        }
        result.success(null)
    }

    private fun stopMotion() {
        val activeDesk = desk
        if (detector != null || activeDesk != null) sensors.unregisterListener(this)
        detector = null
        desk = null
        handler.removeCallbacks(roundTimeout)
        handler.removeCallbacks(motorWatch)
        if (lastPulseFollowedStroke || activeDesk != null) {
            motor.cancel()
            lastPulseFollowedStroke = false
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.timestamp < sensorStarted) return
        val session = desk
        if (session != null) {
            val now = SystemClock.elapsedRealtimeNanos()
            if (now >= session.deadlineNs) {
                stopMotion()
                return
            }
            if (now - event.timestamp > 100_000_000L) return
            if (event.sensor.type == Sensor.TYPE_GRAVITY) {
                session.motion.gravity(event.timestamp, event.values)
                return
            }
            val state = session.motion.update(event.timestamp, event.values)
            if (session.outputEnabled) {
                session.haptics?.sample(now, state, event.timestamp)?.let { feedback ->
                    if (feedback.timings.isEmpty()) cancelDeskMotor(session, now)
                    else feedback.within((session.deadlineNs - now) / 1_000_000L)?.let {
                        playDeskMotor(session, it, now)
                    }
                }
            }
            if (state.ended) events?.success(-1)
            if (state.began) events?.success(2)
            if (state.stroke) events?.success(1)
            return
        }
        if (event.sensor.type != Sensor.TYPE_ACCELEROMETER) return
        val activeDetector = detector ?: return
        if (activeDetector.update(event.timestamp, event.values)) events?.success(1)
        if (activeDetector.takeEarlyStop(SystemClock.elapsedRealtimeNanos())) motor.cancel()
    }

    private fun cancelDeskMotor(session: DeskSession, timeNs: Long) {
        motor.cancel()
        session.motion.motorStopped(timeNs)
    }

    @Suppress("DEPRECATION")
    private fun playDeskMotor(session: DeskSession, feedback: DeskFeedback, now: Long) {
        val times = feedback.timings
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val pattern = if (session.adjustable) {
                    val amplitudes = IntArray(times.size) { if (it % 2 == 1) feedback.amplitude else 0 }
                    VibrationEffect.createWaveform(times, amplitudes, -1)
                } else VibrationEffect.createWaveform(times, -1)
                motor.vibrate(pattern)
            } else motor.vibrate(times, -1)
            session.motion.motorStarted(now, feedback.durationMs)
        } catch (e: SecurityException) {
            session.outputEnabled = false
            android.util.Log.w("Iromigaki", "Haptics unavailable", e)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun hasAmplitudeControl(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && motor.hasAmplitudeControl()

    @Suppress("DEPRECATION")
    private fun pulse(
        requestedMs: Int?, amplitude: Int?, followStroke: Boolean,
        progress: Double?, sessionId: Int?, result: MethodChannel.Result
    ) {
        val maxDurationMs = if (followStroke) 1000 else 300
        if (requestedMs == null || requestedMs !in 1..maxDurationMs || amplitude == null || amplitude !in 1..255) {
            result.error("pulse", "振動の長さまたは強さを確認してください。", null)
            return
        }
        val session = desk
        if (followStroke && (session != null || sessionId != null)) {
            if (session != null && session.id == sessionId && progress != null &&
                progress.isFinite() && progress in 0.0..1.0) {
                session.haptics?.update(progress, requestedMs, amplitude)
            }
            result.success(null)
            return
        }
        if (!motor.hasVibrator()) {
            result.error("vibrator", "振動を利用できません。", null)
            return
        }
        val startNs = SystemClock.elapsedRealtimeNanos()
        val adjustable = hasAmplitudeControl()
        val activeDetector = detector
        val duration = if (followStroke) {
            if (activeDetector == null || !activeDetector.takeStrokePulse()) {
                // A late or duplicate Flutter reply has no stroke in this session.
                result.success(null)
                return
            }
            activeDetector.strokePulseDuration(requestedMs, startNs, adjustable)
        } else requestedMs
        lastPulseFollowedStroke = followStroke
        session?.motion?.motorStarted(startNs, duration)
        activeDetector?.maskMotor(startNs, duration, fixedAmplitudeStroke = followStroke && !adjustable)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val strength = if (adjustable) amplitude else VibrationEffect.DEFAULT_AMPLITUDE
            motor.vibrate(VibrationEffect.createOneShot(duration.toLong(), strength))
        } else {
            motor.vibrate(duration.toLong())
        }
        result.success(null)
    }

    private fun stopInputs() {
        cancelCapture()
        stopMotion()
        motor.cancel()
    }

    override fun onStop() {
        stopInputs()
        super.onStop()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        stopInputs()
        methods?.setMethodCallHandler(null)
        strokes?.setStreamHandler(null)
        events = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        recorderThread.shutdown()
        super.onDestroy()
    }

    private companion object {
        const val microphonePermission = 6281
    }
}
