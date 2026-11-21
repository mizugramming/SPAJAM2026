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
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
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
    private var sensorStarted = 0L
    private var events: EventChannel.EventSink? = null
    private var methods: MethodChannel? = null
    private var strokes: EventChannel? = null

    private class Capture(val reply: MethodChannel.Result) {
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
                    "capture" -> capture(result)
                    "cancelCapture" -> { cancelCapture(); result.success(null) }
                    "startMotion" -> startMotion(result)
                    "stopMotion" -> { stopMotion(); result.success(null) }
                    "hasAmplitudeControl" -> result.success(hasAmplitudeControl())
                    "pulse" -> pulse(
                        call.argument<Int>("durationMs"), call.argument<Int>("amplitude"),
                        call.argument<Boolean>("followStroke") == true, result
                    )
                    "stopPulse" -> { motor.cancel(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun capture(result: MethodChannel.Result) {
        if (capturing != null) {
            result.error("busy", "採音中です。", null)
            return
        }
        val request = Capture(result)
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
        request.reply.error("cancelled", "採音を中断しました。", null)
    }

    private fun beginRecording(request: Capture) {
        recorderThread.execute {
            val pcm = ShortArray(VoiceAnalysis.sampleCount)
            try {
                readPcm(request, pcm)
                if (!request.cancelled) {
                    val summary = VoiceAnalysis.measure(pcm)
                    runOnUiThread {
                        if (capturing === request) {
                            capturing = null
                            request.reply.success(mapOf("hz" to summary.hz, "level" to summary.level))
                        }
                    }
                }
            } catch (error: RuntimeException) {
                runOnUiThread {
                    if (capturing === request) {
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

    private fun startMotion(result: MethodChannel.Result) {
        stopMotion()
        val accelerometer = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        detector = StrokeDetector()
        sensorStarted = SystemClock.elapsedRealtimeNanos()
        if (accelerometer == null || !sensors.registerListener(this, accelerometer, 10_000)) {
            detector = null
            result.error("sensor", "加速度センサーを開始できません。", null)
            return
        }
        result.success(null)
    }

    private fun stopMotion() {
        if (detector != null) sensors.unregisterListener(this)
        detector = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.timestamp >= sensorStarted && detector?.update(event.timestamp, event.values) == true) {
            events?.success(1)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun hasAmplitudeControl(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && motor.hasAmplitudeControl()

    @Suppress("DEPRECATION")
    private fun pulse(requestedMs: Int?, amplitude: Int?, followStroke: Boolean, result: MethodChannel.Result) {
        if (requestedMs == null || requestedMs !in 1..300 || amplitude == null || amplitude !in 1..255) {
            result.error("pulse", "振動の長さまたは強さを確認してください。", null)
            return
        }
        if (!motor.hasVibrator()) {
            result.error("vibrator", "振動を利用できません。", null)
            return
        }
        val startNs = SystemClock.elapsedRealtimeNanos()
        val duration = if (followStroke) detector?.strokePulseDuration(requestedMs, startNs) ?: requestedMs else requestedMs
        detector?.maskMotor(startNs, duration)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val strength = if (hasAmplitudeControl()) amplitude else VibrationEffect.DEFAULT_AMPLITUDE
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
