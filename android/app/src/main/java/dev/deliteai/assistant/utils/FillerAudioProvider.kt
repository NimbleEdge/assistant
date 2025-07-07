/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.utils

import ai.nimbleedge.nimbleedge_chatbot.domain.models.FillerAudio
import android.app.Application
import org.json.JSONArray

object FillerAudioProvider {
    private var fillerSet1 = listOf<FillerAudio>()
    private var fillerSet2 = listOf<FillerAudio>()

    fun loadAudioFillersInMemory(application: Application) {
        if (fillerSet1.isNotEmpty() && fillerSet2.isNotEmpty()) return

        fillerSet1 = readFillersFromStorage(application, "filler-audios/tts_filler_1.json")
        fillerSet2 = readFillersFromStorage(application, "filler-audios/tts_filler_2.json")
    }

    fun getFillerAudioPCM(set: Int): ShortArray {
        val fillers = if (set == 1) fillerSet1 else fillerSet2

        if(fillers.isEmpty()){
            ExceptionLogger.log("readFillerAudio", Throwable("getFillerAudioPCM: Audio fillers for set $set is empty"))
        }

        fillers.forEach {
            if (!it.hasPlayed) {
                it.hasPlayed = true
                return it.data
            }
        }

        rejuvenateFillerAudios(set)
        return getFillerAudioPCM(set)
    }

    private fun rejuvenateFillerAudios(set: Int) {
        val fillers = if (set == 1) fillerSet1 else fillerSet2

        fillers.forEach {
            it.hasPlayed = false
        }
    }

    private fun readFillersFromStorage(
        application: Application,
        filePath: String
    ): List<FillerAudio> {
        val output = mutableListOf<FillerAudio>()
        val jsonText = application.assets
            .open(filePath)
            .bufferedReader()
            .use { it.readText() }

        val array = JSONArray(jsonText)
        for (i in 0 until array.length()) {
            val pcmArray = ShortArray(array.getJSONArray(i).length())
            for (j in 0 until array.getJSONArray(i).length()) {
                pcmArray[j] = array.getJSONArray(i).getInt(j).toShort()
            }

            output.add(FillerAudio(data = pcmArray, hasPlayed = false))
        }

        return output
    }
}