package com.allensu.grokmode.voice

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.sqrt

class AudioManager(private val context: Context) {

    companion object {
        private const val TAG = "AudioManager"
        private const val SAMPLE_RATE = 24000
        private const val CHANNEL_CONFIG_IN = AudioFormat.CHANNEL_IN_MONO
        private const val CHANNEL_CONFIG_OUT = AudioFormat.CHANNEL_OUT_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }

    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var recordingJob: Job? = null
    private val isRecording = AtomicBoolean(false)

    var onAudioData: ((ByteArray) -> Unit)? = null
    var onAudioLevel: ((Float) -> Unit)? = null

    fun hasPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun startRecording(scope: CoroutineScope) {
        if (!hasPermission()) {
            Log.e(TAG, "No recording permission")
            return
        }

        if (isRecording.get()) {
            Log.w(TAG, "Already recording")
            return
        }

        val bufferSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            CHANNEL_CONFIG_IN,
            AUDIO_FORMAT
        ).coerceAtLeast(4096)

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                SAMPLE_RATE,
                CHANNEL_CONFIG_IN,
                AUDIO_FORMAT,
                bufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord failed to initialize")
                return
            }

            audioRecord?.startRecording()
            isRecording.set(true)

            recordingJob = scope.launch(Dispatchers.IO) {
                val buffer = ByteArray(bufferSize)

                while (isActive && isRecording.get()) {
                    val bytesRead = audioRecord?.read(buffer, 0, buffer.size) ?: -1

                    if (bytesRead > 0) {
                        val audioData = buffer.copyOf(bytesRead)

                        // Calculate audio level for waveform
                        val level = calculateAudioLevel(audioData)

                        // Only send if there's actual audio (not just silence)
                        if (level > 0.01f) {
                            Log.d(TAG, "Audio captured: $bytesRead bytes, level: $level")
                        }

                        onAudioData?.invoke(audioData)

                        withContext(Dispatchers.Main) {
                            onAudioLevel?.invoke(level)
                        }
                    }
                }
            }

            Log.d(TAG, "Recording started")
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception starting recording", e)
        }
    }

    fun stopRecording() {
        isRecording.set(false)
        recordingJob?.cancel()
        recordingJob = null

        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording", e)
        }
        audioRecord = null

        // Reset audio level
        onAudioLevel?.invoke(0f)

        Log.d(TAG, "Recording stopped")
    }

    fun initPlayback() {
        val bufferSize = AudioTrack.getMinBufferSize(
            SAMPLE_RATE,
            CHANNEL_CONFIG_OUT,
            AUDIO_FORMAT
        ).coerceAtLeast(4096)

        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(CHANNEL_CONFIG_OUT)
                    .setEncoding(AUDIO_FORMAT)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()

        audioTrack?.play()
        Log.d(TAG, "Playback initialized")
    }

    fun playAudio(data: ByteArray) {
        if (audioTrack?.state != AudioTrack.STATE_INITIALIZED) {
            initPlayback()
        }

        try {
            audioTrack?.write(data, 0, data.size)
        } catch (e: Exception) {
            Log.e(TAG, "Error playing audio", e)
        }
    }

    fun stopPlayback() {
        try {
            audioTrack?.stop()
            audioTrack?.flush()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping playback", e)
        }
    }

    fun release() {
        stopRecording()
        try {
            audioTrack?.stop()
            audioTrack?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing audio track", e)
        }
        audioTrack = null
    }

    private fun calculateAudioLevel(audioData: ByteArray): Float {
        // Convert bytes to shorts (16-bit PCM)
        var sum = 0.0
        var count = 0

        for (i in 0 until audioData.size - 1 step 2) {
            val sample = (audioData[i].toInt() and 0xFF) or
                    (audioData[i + 1].toInt() shl 8)
            val normalized = sample.toShort().toDouble() / Short.MAX_VALUE
            sum += normalized * normalized
            count++
        }

        if (count == 0) return 0f

        // RMS value normalized to 0-1
        val rms = sqrt(sum / count)
        return rms.toFloat().coerceIn(0f, 1f)
    }
}
