/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.domain.features.llm

import ai.nimbleedge.NimbleNet
import ai.nimbleedge.datamodels.NimbleNetTensor
import ai.nimbleedge.utils.DATATYPE

object LLMManager {
    suspend fun feedInput(input: String, isVoiceInitiated: Boolean) {
        val res = NimbleNet.runMethod(
            "prompt_llm",
            inputs = hashMapOf(
                "query" to NimbleNetTensor(input, DATATYPE.STRING, null),
                "is_voice_initiated" to NimbleNetTensor(
                    if (isVoiceInitiated) 1 else 0,
                    DATATYPE.INT32,
                    null
                )
            ),
        )
        check(res.status) { "NimbleNet.runMethod('prompt_llm') failed with status: ${res.status}" }
    }

    suspend fun getNextMap(): Map<String, NimbleNetTensor> {
        val res2 = NimbleNet.runMethod("get_next_str", hashMapOf())
        check(res2.status) { "NimbleNet.runMethod('get_next_str') failed with error: ${res2.error?.message}" }
        return res2.payload
            ?: throw IllegalStateException("NimbleNet.runMethod('get_next_str') returned null payload")
    }

    suspend fun stopLLM() {
        val res = NimbleNet.runMethod("llm_cancel", hashMapOf())
        check(res.status) { "NimbleNet.runMethod('llm_cancel') failed with error: ${res.error?.message}" }
    }

    suspend fun getLLMName(): String? {
        val res = NimbleNet.runMethod("get_llm_name", hashMapOf())
        return res.payload?.get("name")?.data as String?
    }
}
