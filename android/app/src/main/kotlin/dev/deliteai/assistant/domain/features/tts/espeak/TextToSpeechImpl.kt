/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.domain.features.tts.espeak

import android.app.Application
import dev.deliteai.assistant.utils.AssetDataCopier
import dev.deliteai.assistant.utils.Constants.assetFoldersToCopy
import dev.deliteai.client.TextToSpeech
import kotlinx.coroutines.runBlocking
import java.io.File

class TextToSpeechImpl(private val application: Application) : TextToSpeech {

    init {
            assetFoldersToCopy.forEach {
                AssetDataCopier.copyEspeakDataIfNeeded(application, it)
            }
            val res = EspeakService.initialize(File(application.filesDir, "nimbleSDK").absolutePath)
            println(res)
    }

    override fun getPhonemes(text: String): String? {
        return EspeakService.getPhonemes(text)
    }
}
