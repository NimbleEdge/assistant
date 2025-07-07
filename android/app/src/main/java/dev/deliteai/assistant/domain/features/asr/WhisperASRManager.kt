/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.domain.features.asr

import ai.nimbleedge.NimbleNet
import ai.nimbleedge.datamodels.NimbleNetTensor
import ai.nimbleedge.nimbleedge_chatbot.utils.Constants
import ai.nimbleedge.utils.DATATYPE
import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.channelFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext


class WhisperASRManager : ASRManagerInterface {

    private val minBufferSize = maxOf(
        AudioRecord.getMinBufferSize(
            Constants.sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_FLOAT
        ),
        2 * Constants.recordingChunkLengthInSeconds * Constants.sampleRate * Constants.bytesPerFloat
    )

    @SuppressLint("MissingPermission")
    private val audioRecord: AudioRecord = AudioRecord.Builder()
        .setAudioSource(MediaRecorder.AudioSource.MIC)
        .setAudioFormat(
            AudioFormat.Builder()
                .setSampleRate(Constants.sampleRate)
                .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                .build()
        )
        .setBufferSizeInBytes(minBufferSize)
        .build()

    private var isListeningPaused = false

    override fun startListeningFlow(): Flow<ASRState> = channelFlow {
        // Make sure init() was called.
        val recorder = audioRecord
        // Start recording
        recorder.startRecording()
        val chunkSize = Constants.recordingChunkLengthInSeconds * Constants.sampleRate
        val audioBuffer = FloatArray(chunkSize)

        var isSpeechActive = false
        var lastSpeechTime = System.currentTimeMillis()
        val collectedAudio = mutableListOf<Float>()
        var totalText = ""

        try {
            while (isActive) {
                if (isListeningPaused) {
                    delay(200)
                    lastSpeechTime = System.currentTimeMillis()
                    continue
                }
                val readResult = recorder.read(
                    audioBuffer, 0, audioBuffer.size, AudioRecord.READ_NON_BLOCKING
                )
                val currentTime = System.currentTimeMillis()
                if (readResult > 0) {
                    val (rms, db) = calculateAudioLevels(audioBuffer, readResult)
                    if (rms > Companion.SPEECH_THRESHOLD) {
                        if (!isSpeechActive) {
                            send(ASRState(isLoading = true, isSpeaking = true, text = totalText, volume = db))
                        }
                        collectedAudio.addAll(audioBuffer.take(readResult))
                        isSpeechActive = true
                        lastSpeechTime = currentTime
                    } else {
                        if (isSpeechActive && (currentTime - lastSpeechTime >= SILENCE_DELAY)) {
                            isListeningPaused = true
                            send(ASRState(isLoading = true, isSpeaking = true, text = totalText, volume = db))
                            if (collectedAudio.isNotEmpty()) {
                                val audioSegment = collectedAudio.toFloatArray()
                                collectedAudio.clear()
                                withContext(Dispatchers.Default) {
                                    val segmentText = getText(audioSegment)
                                    send(
                                        ASRState(
                                            isLoading = false,
                                            isSpeaking = false,
                                            text = segmentText,
                                            volume = db
                                        )
                                    )
                                }
                            } else {
                                send(ASRState(isLoading = false, isSpeaking = false, text = totalText, volume = db))
                            }
                            isListeningPaused = false
                            isSpeechActive = false
                        } else {
                            // Continuously emit state updates (e.g. for volume updates)
                            send(ASRState(isLoading = false, isSpeaking = isSpeechActive, text = totalText, volume = db))
                        }
                    }
                } else {
                    delay(10)
                }
            }
        } finally {
            recorder.apply {
                if (recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    stop()
                }
            }
        }
    }

    private suspend fun getText(floatAudioData: FloatArray): String {
        val res = NimbleNet.runMethod(
            "get_audio_out",
            inputs = hashMapOf(
                "audioTensor" to NimbleNetTensor(
                    data = floatAudioData,
                    shape = intArrayOf(1, floatAudioData.size),
                    datatype = DATATYPE.FLOAT
                )
            )
        )
        check(res.status) { "NimbleNet returned an unsuccessful status" }
        val map = res.payload ?: throw IllegalStateException("No payload returned from NimbleNet")
        val result = map["str"]?.data as? String ?: throw IllegalStateException("Expected text output missing")
        return if (!result.contains("speaking in foreign language")) result else Constants.errorASRResponse
    }

    companion object {
        private const val SPEECH_THRESHOLD = 0.05f
        private const val SILENCE_DELAY = 3000L  // milliseconds
    }
}