/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.utils

import org.json.JSONObject

object Constants {
    const val sampleRate = 16000
    const val maxAudioLengthInSeconds = 30
    const val recordingChunkLengthInSeconds = 1
    const val bytesPerFloat = 4
    const val errorASRResponse = "Could not understand"
    const val errorLLMInput = "You did not understand what the user said. Ask him to repeat"
    val assetFilesToCopy = listOf(
        "embedding_quantized_model.onnx",
        "embedding_quantized_model.onnx.data",
        "genai_config.json",
        "tokenizer.json",
        "tokenizer_config.json"
    )
    val assetFoldersToCopy = listOf(
        "espeak-ng-data"
    )
    val defaultRemoteConfig = JSONObject(
        mapOf(
            "tier_config" to mapOf(
                "tier_1" to mapOf(
                    "min_multi_core_score" to 2500,
                    "min_ram" to 8,
                    "min_num_cores" to 8
                ),
                "tier_2" to mapOf(
                    "min_multi_core_score" to 1800,
                    "min_ram" to 4,
                    "min_num_cores" to 4
                )
            ),
            "historical_benchmarks" to emptyList<Map<String, Any>>()
        )
    )

    enum class VIEWS(val str: String) {
        HOME_VIEW("homeView"),
        HISTORY_VIEW("historyView"),
        CHAT_VIEW("chatView"),
        VOICE_VIEW("voiceOverlayView")
    }

    enum class MESSAGE_LONG_TAP_ACTIONS(){
        COPY,
        FLAG
    }
}
