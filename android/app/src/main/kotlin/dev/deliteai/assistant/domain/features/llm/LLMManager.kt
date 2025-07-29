/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.domain.features.llm

import android.util.Log
import dev.deliteai.NimbleNet
import dev.deliteai.assistant.utils.TAG

import dev.deliteai.datamodels.NimbleNetTensor
import dev.deliteai.impl.common.DATATYPE

typealias NimbleNetTensorMap = HashMap<String, NimbleNetTensor>
typealias DelitePyForeignFunction = (NimbleNetTensorMap?) -> NimbleNetTensorMap?

object LLMManager {

    private fun createNimbleNetTensorFromForeignFunction(fn: (String?) -> Unit) : NimbleNetTensor {
        val callbackDelitePy : DelitePyForeignFunction =  fun(input: NimbleNetTensorMap?): NimbleNetTensorMap? {
            val outputStream = input?.get("token_stream")?.data as String?
            fn(outputStream)
            return hashMapOf("result" to NimbleNetTensor(data = true, datatype = DATATYPE.BOOL, shape = intArrayOf()))
        }
        return NimbleNetTensor(data = callbackDelitePy, datatype = DATATYPE.FUNCTION, shape = intArrayOf())
    }

    suspend fun feedInput(input: String, isVoiceInitiated: Boolean, callback: (String?)->Unit) : String? {
        val res = NimbleNet.runMethod(
            "prompt_for_tool_calling",
            inputs = hashMapOf(
                "prompt" to NimbleNetTensor(input, DATATYPE.STRING, null),
                "output_stream_callback" to  createNimbleNetTensorFromForeignFunction(callback)
            ),
        )
        assert(res.status) { "NimbleNet.runMethod('prompt_for_tool_calling') failed with status: ${res.status}" }
        return res.payload?.get("results")?.data as String?
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
