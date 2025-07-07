/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.domain.features.asr

import ai.nimbleedge.nimbleedge_chatbot.utils.byteArrayToFloatArray
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.SpeechRecognizer.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import java.util.Locale
import kotlin.math.log10


class GoogleASRManager(
    private val speechRecognizer: SpeechRecognizer,
) : ASRManagerInterface {

    companion object {
        fun isAvailable(context: Context) =  isRecognitionAvailable(context)
    }

    constructor(context: Context) : this(createSpeechRecognizer(context))

    override fun startListeningFlow() : Flow<ASRState> {
        val resultFlow = callbackFlow {
            val speechRecognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            speechRecognizerIntent.putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            speechRecognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
            val listener = object :RecognitionListener {
                override fun onReadyForSpeech(bundle: Bundle?) {
                    trySend(ASRState(
                        isLoading = true,
                        isSpeaking = true,
                        text = "",
                        volume = 0.0f
                    ))
                }
                override fun onBeginningOfSpeech() {
                    trySend(ASRState(
                        isLoading = true,
                        isSpeaking = true,
                        text = "",
                        volume = 0.0f
                    ))
                }
                override fun onRmsChanged(v: Float) {
                    val db = if (v > 0f) (20 * log10(v.toDouble())).toFloat() else -120f
                    trySend(ASRState(
                        isLoading = true,
                        isSpeaking = true,
                        text = "",
                        volume = db
                    ))
                }
                override fun onBufferReceived(bytes: ByteArray?) {
                    byteArrayToFloatArray(bytes)?.let {
                        val (rms, db) = calculateAudioLevels(it,it.size)
                        trySend(ASRState(
                            isLoading = true,
                            isSpeaking = true,
                            text = "",
                            volume = db
                        ))
                    }
                }
                override fun onEndOfSpeech() {}
                override fun onError(i: Int) {
                    trySend(ASRState(
                        isLoading = false,
                        isSpeaking = false,
                        text = "",
                        volume = 0.0f))
                    cancel("Error in execution $i")
                }

                override fun onResults(bundle: Bundle) {
                    val result = bundle.getStringArrayList(RESULTS_RECOGNITION)
                    if (result != null) {
                        trySend(ASRState(
                            isLoading = false,
                            isSpeaking = false,
                            text = result[0],
                            volume = 0.0f))
                    }
                    cancel()

                }
                override fun onPartialResults(bundle: Bundle) {}
                override fun onEvent(i: Int, bundle: Bundle?) {}
            }
            speechRecognizer.setRecognitionListener(listener)
            speechRecognizer.startListening(speechRecognizerIntent)
            awaitClose {
                speechRecognizer.stopListening()
            }
        }
        return resultFlow.flowOn(Dispatchers.Main)
    }

}
