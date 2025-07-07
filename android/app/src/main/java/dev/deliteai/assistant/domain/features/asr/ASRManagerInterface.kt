/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.domain.features.asr

import android.content.Context
import kotlinx.coroutines.flow.Flow
import kotlin.math.log10
import kotlin.math.sqrt


// Data class representing the ASR state.
data class ASRState(
    val isLoading: Boolean = false,
    val isSpeaking: Boolean = false,
    val text: String = "",
    val volume: Float = 0f
)

interface ASRManagerInterface{
    fun startListeningFlow() : Flow<ASRState>

    fun calculateAudioLevels(audioBuffer: FloatArray, readResult: Int): Pair<Float, Float> {
        var sum = 0f
        for (i in 0 until readResult) {
            sum += audioBuffer[i] * audioBuffer[i]
        }
        val rms = sqrt(sum / readResult)
        // If RMS is zero, return a low dB value.
        val db = if (rms > 0f) (20 * log10(rms.toDouble())).toFloat() else -120f
        return Pair(rms, db)
    }
}