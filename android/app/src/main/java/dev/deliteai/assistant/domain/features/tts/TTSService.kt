/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.domain.features.tts

object TTSService {
    suspend fun getPCM(input: String): ShortArray = TTSManager.getPCM(input)
}