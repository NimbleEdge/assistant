/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.domain.features.tts.espeak

import android.util.Log
import dev.deliteai.assistant.utils.TAG

object EspeakManager {
    private const val VOICE = "en"
    const val OK = 0

    @Volatile
    private var init = false

    private external fun nativeInitialize(
        output: Int,
        bufLength: Int,
        path: String?,
        options: Int
    ): Int

    private external fun nativeSetVoiceByName(voiceName: String): Int
    private external fun nativeTextToPhonemes(
        text: String,
        textMode: Int,
        phonemeMode: Int
    ): String?

    @Synchronized
    fun initialize(path: String, options: Int = 0x0001) =
        if (init) true else {
            init = nativeInitialize(2, 0, path, options) > 0 &&
                    nativeSetVoiceByName(VOICE) == OK
            if (!init) Log.e(TAG, "Init failed")
            init
        }

    fun textToPhonemes(text: String) =
        if (!init) {
            Log.e(TAG, "Not initialized")
            null
        } else runCatching {
            nativeTextToPhonemes(text, 0, 0x01)
        }.getOrNull()
}
