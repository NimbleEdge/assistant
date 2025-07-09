/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.utils

import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock


data class AudioQueueData(
    val isFiller: Boolean,
    val audioArray: ShortArray
)

class ContinuousAudioPlayer(
    private val sampleRate: Int = 24000
) {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val _isVoicePlaying = MutableStateFlow(false)
    private var playbackJob: Job? = null

    init {
        continuousPlaybackLoop()
    }

    fun isPlayingOrMightPlaySoon() = ObservableAudioQueue
        .getPendingAudioPlaybackStatus()
        .combine(_isVoicePlaying) { a, b ->  a || b }

    suspend fun hasNonFillers() = ObservableAudioQueue.hasValidAudio() > 0

    suspend fun queueAudio(queueNumber: Int, pcmData: AudioQueueData) {
        ObservableAudioQueue.add(queueNumber, pcmData)
    }

    private fun continuousPlaybackLoop() {
        scope.launch {
            while (true) {
                val nextSegment = ObservableAudioQueue.popForPlay({
                    _isVoicePlaying.value = true
                })
                playAudioSegment(nextSegment?.audioArray) {_isVoicePlaying.value = false}
                if (nextSegment == null)
                    delay(100)
            }
        }
    }

    private suspend fun playAudioSegment(shortData: ShortArray?, listener: () -> Unit) {
        if (shortData == null) return
        val channelConfig = AudioFormat.CHANNEL_OUT_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val minBufferSize = AudioTrack.getMinBufferSize(sampleRate, channelConfig, audioFormat)
        val currentAudioTrack = AudioTrack(
            AudioManager.STREAM_MUSIC,
            sampleRate,
            channelConfig,
            audioFormat,
            minBufferSize,
            AudioTrack.MODE_STREAM
        )

        val job = scope.launch {
            currentAudioTrack.play()
            currentAudioTrack.write(shortData, 0, shortData.size)
            val totalFrames = shortData.size
            var playedFrames = currentAudioTrack.playbackHeadPosition
            delay(50)
            while (playedFrames < totalFrames) {
                playedFrames = currentAudioTrack.playbackHeadPosition
                delay(50)
            }
            currentAudioTrack.stop()
            currentAudioTrack.release()
        }
        job.invokeOnCompletion { cause: Throwable? ->
            cause?.let {
                when(it){
                    is CancellationException->{
                        currentAudioTrack.setVolume(0f)
                        currentAudioTrack.pause()
                        currentAudioTrack.flush()
                        currentAudioTrack.release()
                    }
                    else->
                        ExceptionLogger.log("continuous_audio_player",it)
                }
            }
        }
        playbackJob = job
        job.join()
        listener.invoke()
    }

    fun reset() {
        scope.launch {
            playbackJob?.cancelAndJoin()
            ObservableAudioQueue.clear()
        }
    }
}



object ObservableAudioQueue {
    private val audioQueue = mutableMapOf<Int, AudioQueueData>()
    private val fillerQueue = mutableMapOf<Int, AudioQueueData>()
    private var expectedQueueIdx = 1
    private var expectedFillerQueueIdx = 1
    private val queueMutex = Mutex()
    private val _hasAudioForAudioPlayer = MutableStateFlow(false)


    fun getPendingAudioPlaybackStatus() : StateFlow<Boolean> = _hasAudioForAudioPlayer

    suspend fun add(queueNumber: Int, pcmData: AudioQueueData){
        queueMutex.withLock {
            if (pcmData.isFiller && !fillerQueue.containsKey(queueNumber))
                fillerQueue[queueNumber] = pcmData
            else if (!pcmData.isFiller && !audioQueue.containsKey(queueNumber)) {
                audioQueue[queueNumber] = pcmData
            }
            triggerObservable()
        }
    }

    suspend fun popForPlay(listener: ()->Unit) : AudioQueueData?{
        val audioData = queueMutex.withLock {
            audioQueue.remove(expectedQueueIdx) ?: fillerQueue.remove(
                expectedFillerQueueIdx
            )
        }
        if (audioData == null) return null
        listener.invoke()
        if (!audioData.isFiller){
            expectedQueueIdx++
            queueMutex.withLock {
                fillerQueue.clear()
                expectedFillerQueueIdx = 1
            }
        } else
            expectedFillerQueueIdx++
        triggerObservable()
        return audioData
    }

    suspend fun clear() {
        queueMutex.withLock {
            audioQueue.clear()
            fillerQueue.clear()
            expectedFillerQueueIdx = 1
            expectedQueueIdx = 1
            triggerObservable()
        }
    }

    suspend fun hasValidAudio() = queueMutex.withLock { audioQueue.size }

    private fun triggerObservable(){
        _hasAudioForAudioPlayer.value = audioQueue.isNotEmpty() || fillerQueue.isNotEmpty()
    }
}
