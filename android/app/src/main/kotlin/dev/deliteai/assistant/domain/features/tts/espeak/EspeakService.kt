/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.domain.features.tts.espeak

object EspeakService {
    fun initialize(dataPath: String): Boolean {
        return EspeakManager.initialize(dataPath)
    }

    fun getPhonemes(text: String): String? {
        return EspeakManager.textToPhonemes(text.trim(), )
    }
}
