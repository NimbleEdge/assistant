/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.presentation.viewmodels

import android.app.Application
import android.util.Log
import android.widget.Toast
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import dev.deliteai.NimbleNet
import dev.deliteai.assistant.domain.features.asr.ASRService
import dev.deliteai.assistant.domain.models.Chat
import dev.deliteai.assistant.domain.models.ChatMessage
import dev.deliteai.assistant.domain.repositories.CacheRepository
import dev.deliteai.assistant.domain.repositories.ChatRepository
import dev.deliteai.assistant.domain.repositories.LoggingRepository
import dev.deliteai.assistant.utils.Constants
import dev.deliteai.assistant.utils.ExceptionLogger
import dev.deliteai.assistant.utils.LoaderTextProvider
import dev.deliteai.assistant.utils.TAG
import dev.deliteai.assistant.utils.copyTextToClipboard
import dev.deliteai.datamodels.NimbleNetTensor
import dev.deliteai.impl.common.DATATYPE
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.buffer
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.util.Date
import java.util.UUID
import kotlin.math.min

class ChatViewModel(private val application: Application) : AndroidViewModel(application) {
    private val chatRepository = ChatRepository()
    private val cacheRepository = CacheRepository(application)
    private val loggingRepository = LoggingRepository()

    var outputStream = mutableStateOf<String?>(null)
    var currentTPS = mutableStateOf<Float?>(null)
    var chatHistory = mutableStateOf<List<ChatMessage>>(emptyList())
    var currentMessageLoading = mutableStateOf(true)
    var isChatScreenLoading = mutableStateOf(false)
    var isHistoryLoadInProgress = mutableStateOf(false)
    var currentWaitText = mutableStateOf("Loading...")
    private var currentChatId = mutableStateOf<String?>(null)
    var longTapMenuMessage = mutableStateOf<ChatMessage?>(null)

    // Voice overlay state
    var isOverlayVisible = mutableStateOf(false)
    var isUserSpeaking = mutableStateOf(false)

    // For voice recognition text handling
    var spokenText = mutableStateOf("")
    var persistedRecognizedText = mutableStateOf("")
    var volumeState = mutableFloatStateOf(0f)
    var audioPlaybackStatus = mutableStateOf(false)

    private var chattingJob: Job? = null
    private val addToChatMessageMutex = Mutex()
    var isInterruptButtonVisible = mutableStateOf(false)

    var isFirstMessageSent = mutableStateOf(false)

    private var waitMessageRefreshJob: Job? = null
    var topBarTitle = mutableStateOf<String?>(null)

    var thinkingStream = mutableStateOf<String>("")
    var masterOutputHolder = ""

    init {
        viewModelScope.launch(Dispatchers.IO) {
            chatRepository.getAudioPlaybackSignal().collect { isAudioPlaying ->
                Log.d(
                    TAG,
                    "monitorInterruptButtonVisibility: isAudioPlaying: $isAudioPlaying isLLM not Active: ${chattingJob?.isActive == false}"
                )
                audioPlaybackStatus.value = isAudioPlaying
                if (!isAudioPlaying && chattingJob?.isCompleted == true && chattingJob?.isCancelled == false && isOverlayVisible.value) {
                    delay(1000)
                    getLLMAudioFromVoiceInput()
                    withContext(Dispatchers.Main) {
                        isInterruptButtonVisible.value = false
                    }
                }
            }
        }
    }

    fun fetchModelName() {
        viewModelScope.launch(Dispatchers.IO) {
            val name = topBarTitle.value ?: chatRepository.getModelName()

            withContext(Dispatchers.Main) {
                topBarTitle.value = name
            }
        }
    }

    fun handleMessageLongTapAction(action: Constants.MESSAGE_LONG_TAP_ACTIONS) {
        if (longTapMenuMessage.value == null) return

        when (action) {
            Constants.MESSAGE_LONG_TAP_ACTIONS.COPY -> {
                copyToClipboard(longTapMenuMessage.value!!.message)
            }

            Constants.MESSAGE_LONG_TAP_ACTIONS.FLAG -> {
                flagMessage(longTapMenuMessage.value!!.message)
            }
        }

        longTapMenuMessage.value = null
    }

    private fun flagMessage(message: String?) {
        Toast.makeText(application, "Thanks for providing feedback", Toast.LENGTH_SHORT).show()

        viewModelScope.launch(Dispatchers.IO) {
            runCatching {
                loggingRepository.flagLLMMessage(application, message)
            }.onFailure { e ->
                Log.e(TAG, "Failed to flag message", e)
            }
        }
    }

    private fun copyToClipboard(message: String?) {
        application.copyTextToClipboard(message)
        Toast.makeText(application, "Copied to clipboard", Toast.LENGTH_SHORT).show()
    }

    fun isChattingJobActive() = chattingJob?.isActive == true

    fun cancelLLMAndClearAudioQueue() {
        chattingJob?.cancel()
        chatRepository.resetAudioPlayer()
    }

    fun handleBack() {
        cancelLLMAndClearAudioQueue()
        isOverlayVisible.value = false
    }

    fun handleTextViewButtonClick(userInput: String) {
        if (isOverlayVisible.value) return

        if (chattingJob?.isActive == true) {
            cancelLLMAndClearAudioQueue()
        } else {
            if (userInput.any { it.isLetterOrDigit() }) {
                addNewMessageToChatHistory(userInput, true)
                getLLMTextFromTextInput(userInput)

            } else {
                Toast.makeText(
                    application,
                    "Please enter a message to continue",
                    Toast.LENGTH_SHORT
                )
                    .show()
            }
        }
    }

    private fun keepUpdatingWaitMessage() {
        val loaderTextProvider = LoaderTextProvider()
        val initialDelay = 1200L
        var delayOffset = 0L

        waitMessageRefreshJob = viewModelScope.launch(Dispatchers.Default) {
            while (true) {
                withContext(Dispatchers.Main) {
                    currentWaitText.value = loaderTextProvider.getLoaderText()
                }

                delay(initialDelay + delayOffset)
                delayOffset += initialDelay
            }
        }
    }

    fun shouldRestartListening() {
        if (!audioPlaybackStatus.value && chattingJob?.isCompleted != false) {
            getLLMAudioFromVoiceInput()
        }
    }

    fun getLLMAudioFromVoiceInput() {
        cancelLLMAndClearAudioQueue()
        if (!isFirstMessageSent.value) {
            isFirstMessageSent.value = true
        }
        spokenText.value = ""
        isInterruptButtonVisible.value = false
        persistedRecognizedText.value = ""
        val chatJob = viewModelScope.launch(
            Dispatchers.Default + CoroutineExceptionHandler { _, e ->
                handleException(e)
            }) {
            chatRepository.resetAudioPlayer()
            val response = ASRService.startAndroidListener()
                .onEach { response ->
                    volumeState.floatValue = response.volume
                    isUserSpeaking.value = response.isSpeaking
                }.filter { it.text.isNotBlank() }
                .onEach { spokenText.value = it.text }
                .filter { !it.isSpeaking && !it.isLoading }
                .onEach { persistedRecognizedText.value = it.text }
                .flowOn(Dispatchers.Main)
                .onEach { res ->
                    addToChatMessageMutex.withLock {
                        addNewMessageToChatHistory(res.text, true)
                    }
                }
                .firstOrNull()

            response?.text?.let {
                withContext(Dispatchers.Main) {
                    isInterruptButtonVisible.value = true
                }
                getLLMAudioResponse(it)
            }
        }
        chatJob.invokeOnCompletion { cause ->
            cause?.let { handleException(cause) }
            isInterruptButtonVisible.value = false
        }
        chattingJob = chatJob
    }

    fun getLLMTextFromTextInput(textInput: String) {
        thinkingStream.value = ""

        cancelLLMAndClearAudioQueue()
        if (!isFirstMessageSent.value) {
            isFirstMessageSent.value = true
        }

        currentMessageLoading.value = true
        if (chattingJob?.isActive != true) {
            keepUpdatingWaitMessage()
        }
        if (chattingJob?.isActive == true) {
            addNewMessageToChatHistory(outputStream.value.toString(), false)
            chattingJob?.cancel()
        }
        outputStream.value = ""
        val chatJob = viewModelScope.launch(
            Dispatchers.Default + CoroutineExceptionHandler { _, e ->
                handleException(e)
            }) {
            chatRepository.getLLMText(textInput)
                .onEach { result ->
                    handleLLMResult(result, false)
                }
                .flowOn(Dispatchers.Main)
                .filterIsInstance<ChatRepository.GenerateResponseJobStatus.Finished>()
                .first()
        }
        chatJob.invokeOnCompletion { cause ->
            cause?.let { handleException(cause) }
            isInterruptButtonVisible.value = false
        }
        chattingJob = chatJob
    }

    private suspend fun getLLMAudioResponse(textInput: String) = withContext(Dispatchers.Main) {
        Log.d(TAG, "LLM Triggered by $textInput")
        currentMessageLoading.value = true
        outputStream.value = ""
        chatRepository.getLLMAudio(textInput)
            .buffer()
            .onEach { result ->
                handleLLMResult(result, true)
            }
            .filterIsInstance<ChatRepository.GenerateResponseJobStatus.Finished>()
            .first()
    }

    fun addNewMessageToChatHistory(message: String, isUserInput: Boolean) {
        if (message == "null") return
        val newMessage = ChatMessage(
            message = message,
            isUserMessage = isUserInput,
            tps = currentTPS.value,
            timestamp = Date()
        )
        chatHistory.value += newMessage
        currentTPS.value = null
        saveChatToRepository()
    }

    private  val THINK_SENTINEL = "/think"

    // Fast non-overlapping counter
    private fun String.countOccurrences(needle: String): Int {
        if (needle.isEmpty()) return 0
        var count = 0
        var from = 0
        while (true) {
            val i = indexOf(needle, startIndex = from)
            if (i == -1) break
            count++
            from = i + needle.length
        }
        return count
    }

    private fun cleanForUi(s: String): String {
        return s.replace("<think>", "")
            .replace("</think>", "")
            .replace("<tool_call>", "-> EXECUTING TOOL CALL")
            .replace("</tool_call>", "")
            .replace("<|im_end|>", "")
            // optional: hide the sentinel from the UI as well
            .replace(THINK_SENTINEL, "")
    }

    private var thinkSeen = 0
    private var cutAfterThirdThink = -1


    private fun handleLLMResult(
        result: ChatRepository.GenerateResponseJobStatus,
        isAudioExpected: Boolean
    ) {
        when (result) {
            is ChatRepository.GenerateResponseJobStatus.GenerationInProgress -> {
                if (isAudioExpected)
                    currentMessageLoading.value = false
            }

            is ChatRepository.GenerateResponseJobStatus.Finished -> {
//                val finalOutput = outputStream.value.toString()
//                addNewMessageToChatHistory(finalOutput, false)
//                outputStream.value = null
//                isInterruptButtonVisible.value = false
            }

            is ChatRepository.GenerateResponseJobStatus.NextItem -> {
                val newChunk = result.outputText

                masterOutputHolder += newChunk

                val totalThinks = masterOutputHolder.countOccurrences(THINK_SENTINEL)

                if (totalThinks > thinkSeen) {
                    if (thinkSeen < 3 && totalThinks >= 3 && cutAfterThirdThink < 0) {
                        val thirdStart = masterOutputHolder.lastIndexOf(THINK_SENTINEL)
                        if (thirdStart != -1) {
                            cutAfterThirdThink = thirdStart + THINK_SENTINEL.length
                        }
                    }
                    thinkSeen = totalThinks
                    thinkingStream.value = "" // reset the "thinking" buffer at sentinel boundaries
                }

                if (cutAfterThirdThink >= 0) {
                    val visible = masterOutputHolder.substring(cutAfterThirdThink)
                    val cleaned = cleanForUi(visible)
                    outputStream.value = cleaned.substring(0,min(cleaned.length, 147))
                } else {
                    thinkingStream.value = cleanForUi(thinkingStream.value + newChunk)
                }

                if (!isAudioExpected && newChunk.contains(Regex("[A-Za-z0-9]"))) {
                    currentMessageLoading.value = false
                    waitMessageRefreshJob?.cancel()
                }

            }
        }
    }

    private fun saveChatToRepository() {
        currentChatId.value?.let { chatId ->
            viewModelScope.launch(Dispatchers.IO) {
                cacheRepository.cacheChat(Chat(id = chatId, messages = chatHistory.value))
            }
        }
    }

    fun clearContextAndStartNewChat() {
        isChatScreenLoading.value = true
        cancelLLMAndClearAudioQueue()

        viewModelScope.launch(
            Dispatchers.Default + CoroutineExceptionHandler { _, e ->
                ExceptionLogger.log("clear_context_start_new_chat", e)
            }) {
            val res = NimbleNet.runMethod("clear_prompt", inputs = hashMapOf())
            if (!res.status) {
                ExceptionLogger.log("clear_prompt", Throwable("clear prompt method failed"))
                return@launch
            }

            withContext(Dispatchers.Main) {
                chatHistory.value = emptyList()
                isFirstMessageSent.value = false
                createNewUUID()
            }
        }.invokeOnCompletion {
            outputStream.value = null
            isChatScreenLoading.value = false
        }
    }

    fun loadChatFromId(chatId: String) {
        isHistoryLoadInProgress.value = true
        chatHistory.value = mutableListOf()
        outputStream.value = null
        isFirstMessageSent.value = false

        viewModelScope.launch(
            Dispatchers.Default + CoroutineExceptionHandler { _, e ->
                clearContextAndStartNewChat()
            }) {
            val chat = cacheRepository.retrieveChat(chatId)
            currentChatId.value = chat.id
            chatHistory.value = chat.messages

            val historicalContext = JSONArray()
            chat.messages.forEach {
                historicalContext.put(
                    JSONObject(
                        mapOf(
                            "type" to (if (it.isUserMessage) "user" else "assistant"),
                            "message" to it.message
                        )
                    )
                )
            }

            val res = NimbleNet.runMethod(
                "set_context", hashMapOf(
                    "context" to NimbleNetTensor(
                        data = historicalContext,
                        datatype = DATATYPE.JSON_ARRAY,
                        shape = intArrayOf(historicalContext.length())
                    )
                )
            )
            check(res.status)
            if (chat.messages.isNotEmpty())
                isFirstMessageSent.value = true
        }.invokeOnCompletion {
            isHistoryLoadInProgress.value = false
        }
    }

    private fun createNewUUID() {
        currentChatId.value = UUID.randomUUID().toString()
    }

    override fun onCleared() {
        super.onCleared()
        cancelLLMAndClearAudioQueue()
    }

    private fun handleException(exception: Throwable) {
        when (exception) {
            is CancellationException ->
                viewModelScope.launch(Dispatchers.IO) {
                    try {
                        chatRepository.stopLLM()
                    } catch (e: Exception) {
                        ExceptionLogger.log("handleException", e)
                    }

                    currentMessageLoading.value = false
                    if (outputStream.value != null) {
                        val output = outputStream.value.toString()
                        if (output.isNotBlank())
                            addNewMessageToChatHistory(output, false)
                    }
                    outputStream.value = null
                }

            is SecurityException ->
                viewModelScope.launch(Dispatchers.Main) {
                    Toast.makeText(application, exception.message, Toast.LENGTH_SHORT)
                        .show()
                }

            else ->
                ExceptionLogger.log("handleException", exception)
        }
    }
}
