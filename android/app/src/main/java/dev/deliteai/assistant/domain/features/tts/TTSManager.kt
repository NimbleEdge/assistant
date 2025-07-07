/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.domain.features.tts

import ai.nimbleedge.NimbleNet
import ai.nimbleedge.datamodels.NimbleNetTensor
import ai.nimbleedge.nimbleedge_chatbot.utils.TAG
import ai.nimbleedge.utils.DATATYPE
import android.util.Log

object TTSManager {

    //used during the app runtime
    suspend fun getPCM(input: String): ShortArray {
        Log.d(TAG, "Calling TTS run method")
        val res = NimbleNet.runMethod(
            "run_model",
            inputs = hashMapOf(
                "text" to NimbleNetTensor(
                    data = input,
                    shape = null,
                    datatype = DATATYPE.STRING
                )
            )
        )
        Log.d(TAG, "Finished TTS run method")
        check(res.status) { "NimbleNet.runMethod('run_model') failed with status: ${res.status}" }
        val payload = res.payload ?: throw IllegalStateException("NimbleNet.runMethod('run_model') returned null payload")
        val phonemeTensor = payload["audio"] ?: throw IllegalStateException("Expected 'audio' key missing in payload")
        val audioData = phonemeTensor.data as? FloatArray ?: throw IllegalStateException("Phoneme data is not of type FloatArray")
        return audioData.map{(it * Short.MAX_VALUE).toInt().toShort()}.toShortArray()
    }

}
