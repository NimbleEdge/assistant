/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.domain.repositories

import dev.deliteai.datamodels.NimbleNetTensor
import dev.deliteai.assistant.domain.features.llm.LLMService
import dev.deliteai.assistant.domain.features.tts.TTSService
import dev.deliteai.assistant.utils.AudioQueueData
import dev.deliteai.assistant.utils.Constants
import dev.deliteai.assistant.utils.ContinuousAudioPlayer
import dev.deliteai.assistant.utils.ExceptionLogger
import dev.deliteai.assistant.utils.FillerAudioProvider
import dev.deliteai.assistant.utils.MAX_CHAR_LEN
import dev.deliteai.assistant.utils.TAG
import dev.deliteai.assistant.utils.chunkSentence
import dev.deliteai.assistant.utils.mergeChunks
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.channelFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.withContext
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.atomic.AtomicInteger

class ChatRepository {
    private var continuousAudioPlayer = ContinuousAudioPlayer()
    private val repositoryScope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private val ttsJobs = ConcurrentLinkedQueue<Job>()
    private var fillerAudioPlayJob: Deferred<Unit>? = null

    fun getAudioPlaybackSignal() = continuousAudioPlayer.isPlayingOrMightPlaySoon()

    fun resetAudioPlayer() = continuousAudioPlayer.reset()

    suspend fun stopLLM() = LLMService.stopLLM()

    suspend fun getModelName() = LLMService.getLLMName()

    fun getLLMText(textInput: String) = flow {
        repositoryScope.launch(Dispatchers.Default) {  LLMService.feedInput(textInput, false) }
        do {
            val outputMap = LLMService.getNextMap()
            val currentOutputString = (outputMap["token_stream"] as NimbleNetTensor).data.toString()
            Log.d(TAG, "token stream $currentOutputString")
            emit(GenerateResponseJobStatus.NextItem(currentOutputString))
        } while (!outputMap.containsKey("<|im_end|>"))

        emit(GenerateResponseJobStatus.Finished())
        Log.d(TAG, "startFeedbackLoop: LLM finished output")
    }.flowOn(Dispatchers.Default)
        .catch { throwable ->
            ExceptionLogger.log("getLLMText", throwable)
        }

    fun getLLMAudio(textInput: String) = channelFlow {
        val indexToQueueNext = AtomicInteger(1)
        var ttsQueue = ""
        val promptText =
            if (textInput == Constants.errorASRResponse) Constants.errorLLMInput else textInput
        LLMService.feedInput(promptText, true)
        val isFirstJobDone = MutableStateFlow(false)
        val maxJobs = Semaphore(3)
        fillerAudioPlayJob = async(Dispatchers.IO) {
            playFillerAudio(1000, isFirstJobDone, 1, 1)
            playFillerAudio(6000, isFirstJobDone, 2, 2)
        }

        do {
            val outputMap = LLMService.getNextMap()
            val currentOutputString = (outputMap["str"] as NimbleNetTensor).data.toString()
            send(GenerateResponseJobStatus.NextItem(currentOutputString))
            ttsQueue += currentOutputString
            if (ttsQueue.length < 2 * MAX_CHAR_LEN && !outputMap.containsKey("finished"))
                continue

            val cleanedText = ttsQueue.trim().trimIndent()
                .replace(Regex("[\"*#]"), "")
                .replace("\n", "…")

            val inputChunked = Regex("\\S.*?(?:[!?:]|\\.(?!\\d))(?=\\s+|$)").findAll(cleanedText)
                .map { it.value.trim() }
                .filterNot { it.isEmpty() }
                .map { chunkSentence(it).toList() }
                .toList()
                .flatten()
                .toMutableList()
                .mergeChunks()

            if (inputChunked.isEmpty() || inputChunked.all { it.isBlank() })
                inputChunked.addAll(chunkSentence(cleanedText))

            ttsQueue = if (!cleanedText.endsWith(inputChunked.last())) {
                cleanedText.split(inputChunked.last()).last()
            } else ""
            if (outputMap.containsKey("finished") && ttsQueue.isNotBlank()) {
                inputChunked.add(ttsQueue)
                ttsQueue = ""
            }
            inputChunked.filter { it.isNotBlank() }.map { input ->
                if (isFirstJobDone.value) {
                    withContext(Dispatchers.IO) {
                        maxJobs.acquire()
                    }
                    ttsJobs.add(repositoryScope.launch(Dispatchers.Default) {
                        triggerTTS(input, indexToQueueNext.getAndIncrement())
                        maxJobs.release()
                    })
                } else {
                    triggerTTS(input, indexToQueueNext.getAndIncrement())
                    send(GenerateResponseJobStatus.GenerationInProgress())
                    isFirstJobDone.value = true
                }
            }
        } while (!outputMap.containsKey("finished"))
        ttsJobs.forEach {
            if (it.isActive)
                it.join()
        }
        send(GenerateResponseJobStatus.Finished())
        Log.d(TAG, "startFeedbackLoop: LLM finished output")
        close()
    }.flowOn(Dispatchers.Default)
        .catch { e ->
            ExceptionLogger.log("getLLMAudio", e)
        }

    private suspend fun playFillerAudio(
        delay: Int,
        isFirstJobDone: MutableStateFlow<Boolean>,
        indexToQueueNext: Int,
        ttsSetIdx: Int
    ) {
        for (time in delay downTo 0 step 100) {
            if (isFirstJobDone.value) {
                Log.d(TAG, "getLLMAudio: Skipping filler sound ${indexToQueueNext}")
                return
            }
            delay(100)
        }
        if (!continuousAudioPlayer.hasNonFillers()) {
            Log.d(TAG, "playFillerAudio: playing filler audio ${indexToQueueNext}")
            continuousAudioPlayer.queueAudio(
                indexToQueueNext,
                AudioQueueData(true, FillerAudioProvider.getFillerAudioPCM(ttsSetIdx))
            )
        }
    }

    private suspend fun triggerTTS(text: String?, queueNumber: Int) {
        if (text == null) return
        Log.d(TAG, "triggerTTS (queue $queueNumber): ${text}")
        try {
            val pcm = TTSService.getPCM(text)
            Log.d(TAG, "trigger TTS generated audio data $queueNumber")
            continuousAudioPlayer.queueAudio(queueNumber, AudioQueueData(false, pcm))
        } catch (e: Exception) {
            ExceptionLogger.log("triggerTTS", e)
        }
    }

    sealed class GenerateResponseJobStatus(val message: String) {
        class Finished : GenerateResponseJobStatus("Finished generating response")
        class NextItem(val outputText: String) : GenerateResponseJobStatus(outputText)
        class GenerationInProgress :
            GenerateResponseJobStatus("Running LLM and TTS")
    }
}
