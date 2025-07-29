/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.domain.features.llm

import dev.deliteai.NimbleNet
import dev.deliteai.datamodels.NimbleNetTensor
import dev.deliteai.impl.common.DATATYPE
import org.json.JSONObject

object LLMManager {
    suspend fun feedInput(input: String, isVoiceInitiated: Boolean) {
        val res = NimbleNet.runMethod(
            "prompt_for_tool_calling",
            inputs = hashMapOf(
                "prompt" to NimbleNetTensor(input, DATATYPE.STRING, null),
            ),
        )
        check(res.status) { "NimbleNet.runMethod('prompt_for_tool_calling') failed with status: ${res.status}" }
    }

    suspend fun getNextMap(): Map<String, NimbleNetTensor> {
        val res2 = NimbleNet.runMethod("get_token_stream", hashMapOf())
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
