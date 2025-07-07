/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.domain.features.llm

import ai.nimbleedge.datamodels.NimbleNetTensor

object LLMService {
    suspend fun feedInput(input:String, isVoiceInitiated:Boolean) = LLMManager.feedInput(input, isVoiceInitiated)
    suspend fun getNextMap(): Map<String, NimbleNetTensor> = LLMManager.getNextMap()
    suspend fun stopLLM() = LLMManager.stopLLM()
    suspend fun getLLMName() = LLMManager.getLLMName()
}
